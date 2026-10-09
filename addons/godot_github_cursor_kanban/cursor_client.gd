@tool
extends RefCounted

const _HOST := "api.cursor.com"
const _PAGE_SIZE := 20
const _REPO_CACHE_PATH := "user://kanban_agent_repos.json"
const _LIST_CACHE_PATH := "user://kanban_session_list.json"

static var _repo_cache: Dictionary = {}
static var _repo_cache_loaded := false
static var _repo_cache_lock := Mutex.new()
static var _list_cache: Dictionary = {}
static var _list_cache_loaded := false
static var _list_cache_lock := Mutex.new()


static func list_unarchived_sessions(token: String, repo_slug: String, cursor: String = "") -> Dictionary:
	var sessions: Array[Dictionary] = []
	if token.is_empty():
		push_warning("看板：未配置 Cursor token。")
		return {"sessions": sessions, "notice": "未配置 Cursor Token，点右上角设置填写。", "next_cursor": ""}
	if repo_slug.is_empty():
		return {"sessions": sessions, "notice": "读不到当前仓库的 origin。", "next_cursor": ""}
	var path := "/v1/agents?limit=%d&includeArchived=false" % _PAGE_SIZE
	if not cursor.is_empty():
		path += "&cursor=" + cursor.uri_encode()
	var payload := request(token, HTTPClient.METHOD_GET, path)
	var saw_error := false
	var next_cursor := ""
	if payload.is_empty():
		saw_error = true
	else:
		var items: Variant = payload.get("items", [])
		if typeof(items) != TYPE_ARRAY:
			saw_error = true
		else:
			for item in items:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var session := _session_from_list_item(item)
				if session.is_empty():
					continue
				sessions.append(session)
			var next := payload.get("nextCursor", "")
			next_cursor = "" if next == null else str(next)
			if next_cursor == "<null>":
				next_cursor = ""
	var notice := ""
	if sessions.is_empty() and next_cursor.is_empty():
		notice = "读取 Cursor 会话失败。" if saw_error else "当前仓库没有未归档的云端会话。"
	elif saw_error and sessions.is_empty():
		notice = "读取 Cursor 会话失败。"
	return {"sessions": sessions, "notice": notice, "next_cursor": next_cursor}


static func list_messages(token: String, agent_id: String) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	if token.is_empty() or agent_id.is_empty():
		return messages
	var payload := request(token, HTTPClient.METHOD_GET, "/v0/agents/%s/conversation" % agent_id.uri_encode())
	var items: Variant = payload.get("messages", [])
	if typeof(items) != TYPE_ARRAY:
		return messages
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		messages.append({
			"id": str(item.get("id", "")),
			"type": str(item.get("type", "")),
			"text": str(item.get("text", "")),
			"time": format_message_time(_raw_message_time(item)),
		})
	return messages


static func format_now() -> String:
	return Time.get_datetime_string_from_datetime_dict(Time.get_datetime_dict_from_system(), true)


static func format_message_time(raw: String) -> String:
	var text := raw.strip_edges()
	if text.is_empty():
		return ""
	if text.is_valid_int():
		return _clock_from_unix(int(text))
	var unix := int(Time.get_unix_time_from_datetime_string(text))
	if unix <= 0:
		return ""
	if text.ends_with("Z") or text.contains("+") or _has_negative_offset(text):
		unix += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return _clock_from_unix(unix)


static func _raw_message_time(item: Dictionary) -> String:
	for key in ["createdAt", "created_at", "timestamp", "time"]:
		var raw := item.get(key, "")
		if raw == null:
			continue
		var text := str(raw).strip_edges()
		if not text.is_empty() and text != "<null>":
			return text
	return ""


static func _has_negative_offset(text: String) -> bool:
	var tail := text.split("T")[-1]
	return tail.contains("-")


static func _clock_from_unix(unix: int) -> String:
	return Time.get_datetime_string_from_datetime_dict(Time.get_datetime_dict_from_unix_time(unix), true)


static func create_agent(token: String, text: String, repository: String, ref: String) -> Dictionary:
	if token.is_empty() or text.strip_edges().is_empty() or repository.is_empty():
		return {}
	var payload := request(
		token,
		HTTPClient.METHOD_POST,
		"/v0/agents",
		JSON.stringify(create_agent_body(text, repository, ref))
	)
	return agent_from_create(payload)


static func create_agent_body(text: String, repository: String, ref: String) -> Dictionary:
	var source := {"repository": repository}
	if not ref.strip_edges().is_empty():
		source["ref"] = ref.strip_edges()
	return {
		"prompt": {"text": text},
		"source": source,
	}


static func agent_from_create(payload: Dictionary) -> Dictionary:
	var agent_id := str(payload.get("id", "")).strip_edges()
	if agent_id.is_empty() or agent_id == "<null>":
		return {}
	return {
		"id": agent_id,
		"name": str(payload.get("name", "")),
	}


static func send_message(token: String, agent_id: String, text: String) -> bool:
	if token.is_empty() or agent_id.is_empty() or text.strip_edges().is_empty():
		return false
	var body := JSON.stringify({"prompt": {"text": text}})
	var payload := request(
		token,
		HTTPClient.METHOD_POST,
		"/v0/agents/%s/followup" % agent_id.uri_encode(),
		body
	)
	return not payload.is_empty()


static func request(token: String, method: int, path: String, body: String = "") -> Dictionary:
	var started := Time.get_ticks_msec()
	var parsed := _request(token, method, path, body)
	print("看板请求 %s %s %d ms" % [_method_name(method), path, Time.get_ticks_msec() - started])
	return parsed


static func _request(token: String, method: int, path: String, body: String = "") -> Dictionary:
	var client := HTTPClient.new()
	var err := client.connect_to_host(_HOST, 443, TLSOptions.client())
	if err != OK:
		push_warning("看板：连不上 Cursor API。")
		return {}
	if not _wait_status(client, [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]):
		push_warning("看板：连接 Cursor API 超时。")
		return {}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_warning("看板：连接 Cursor API 失败。")
		return {}
	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(token + ":"),
		"Accept: application/json",
	])
	if not body.is_empty():
		headers.append("Content-Type: application/json")
	err = client.request(method, path, headers, body)
	if err != OK:
		push_warning("看板：请求 Cursor API 失败。")
		return {}
	if not _wait_status(client, [HTTPClient.STATUS_REQUESTING]):
		return {}
	if client.get_response_code() < 200 or client.get_response_code() >= 300:
		push_warning("看板：Cursor API 返回 %d。" % client.get_response_code())
		return {}
	var bytes := PackedByteArray()
	var ticks := 0
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			bytes.append_array(chunk)
		ticks += 1
		if ticks > 500:
			push_warning("看板：读取 Cursor API 超时。")
			return {}
	if bytes.is_empty():
		return {"ok": true}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _method_name(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		_:
			return str(method)


static func detail_patch(detail: Dictionary, repo_slug: String) -> Dictionary:
	if detail.is_empty():
		return {"_error": true}
	if str(detail.get("status", "")) == "ARCHIVED":
		return {}
	if not _repos_include(detail.get("repos", []), repo_slug):
		return {}
	var git := _git_fields(detail)
	return {
		"name": str(detail.get("name", "")),
		"url": str(detail.get("url", "")),
		"working": str(detail.get("status", "")) == "ACTIVE",
		"branch": git["branch"],
		"pr_url": git["pr_url"],
	}


static func _repos_include(repos: Variant, repo_slug: String) -> bool:
	if typeof(repos) != TYPE_ARRAY:
		return false
	for repo in repos:
		if typeof(repo) != TYPE_DICTIONARY:
			continue
		if _same_repo(str(repo.get("url", "")), repo_slug):
			return true
	return false


static func _same_repo(url: String, repo_slug: String) -> bool:
	return _slug_from_url(url) == repo_slug.strip_edges().trim_prefix("/").to_lower()


static func _slug_from_url(url: String) -> String:
	var text := url.strip_edges().trim_suffix(".git")
	var tail := text
	if text.contains("github.com"):
		tail = text.split("github.com")[-1].trim_prefix(":").trim_prefix("/")
	return tail.strip_edges().trim_prefix("/").to_lower()


## 返回 1 显示、0 隐藏、-1 还没缓存。仓库在创建后不变，命中就不再请求详情。
static func cached_repo_match(agent_id: String, repo_slug: String) -> int:
	if agent_id.is_empty():
		return -1
	var slugs: Variant = _cached_slugs(agent_id)
	if slugs == null:
		return -1
	var wanted := repo_slug.strip_edges().trim_prefix("/").to_lower()
	for slug in slugs:
		if str(slug) == wanted:
			return 1
	return 0


static func load_session_list(repo_slug: String) -> Array:
	var key := _repo_key(repo_slug)
	if key.is_empty():
		return []
	_load_list_cache()
	_list_cache_lock.lock()
	var raw: Variant = _list_cache.get(key, [])
	_list_cache_lock.unlock()
	if typeof(raw) != TYPE_ARRAY:
		return []
	var sessions: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")).is_empty():
			continue
		sessions.append((item as Dictionary).duplicate())
	return sessions


static func save_session_list(repo_slug: String, sessions: Array) -> void:
	var key := _repo_key(repo_slug)
	if key.is_empty():
		return
	var clean: Array = []
	for item in sessions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var agent_id := str(item.get("id", ""))
		if agent_id.is_empty():
			continue
		clean.append({
			"id": agent_id,
			"name": str(item.get("name", "")),
			"url": str(item.get("url", "")),
			"working": bool(item.get("working", false)),
			"archived": false,
			"branch": str(item.get("branch", "")),
			"pr_url": str(item.get("pr_url", "")),
		})
	_load_list_cache()
	_list_cache_lock.lock()
	_list_cache[key] = clean
	_write_list_cache(_list_cache)
	_list_cache_lock.unlock()


static func _repo_key(repo_slug: String) -> String:
	return repo_slug.strip_edges().trim_prefix("/").to_lower()


## 返回 1 已归档、0 未归档、-1 还没缓存。归档状态会变，不能拿这个结果跳过刷新。
static func cached_archived(agent_id: String) -> int:
	if agent_id.is_empty():
		return -1
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if typeof(entry) != TYPE_DICTIONARY or not entry.has("archived"):
		return -1
	return 1 if bool(entry.get("archived", false)) else 0


## 返回 1 已合并、0 未合并、-1 还没缓存。合并状态会变，不能拿这个结果跳过刷新。
static func cached_merged(agent_id: String) -> int:
	if agent_id.is_empty():
		return -1
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if typeof(entry) != TYPE_DICTIONARY or not entry.has("merged"):
		return -1
	return 1 if bool(entry.get("merged", false)) else 0


static func remember_merged(agent_id: String, merged: bool) -> void:
	if agent_id.is_empty():
		return
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry := _entry_for(agent_id)
	entry["merged"] = merged
	_repo_cache[agent_id] = entry
	_write_repo_cache(_repo_cache)
	_repo_cache_lock.unlock()


## 已知时返回那个 PR（没有就是空字符串）。还没缓存返回 null。
static func cached_pr_url(agent_id: String) -> Variant:
	if agent_id.is_empty():
		return null
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if typeof(entry) != TYPE_DICTIONARY or not entry.has("pr_url"):
		return null
	return str(entry.get("pr_url", ""))


static func cached_branch(agent_id: String) -> String:
	if agent_id.is_empty():
		return ""
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return str(entry.get("branch", ""))


## 1 已合并进 base，0 没有，-1 本地对不上。
static func branch_merged(repo_path: String, branch: String, base: String = "master") -> int:
	var head := branch.strip_edges()
	if head.is_empty() or head == base:
		return 0
	if head.contains(" ") or head.begins_with("-") or head.contains(".."):
		return -1
	var code := OS.execute(
		"git",
		["-C", repo_path, "merge-base", "--is-ancestor", "origin/" + head, "origin/" + base],
		[],
		true
	)
	if code == 0:
		return 1
	if code == 1:
		return 0
	return -1


static func _cached_slugs(agent_id: String) -> Variant:
	if agent_id.is_empty():
		return null
	_load_repo_cache()
	_repo_cache_lock.lock()
	var known := _repo_cache.has(agent_id)
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if not known:
		return null
	if typeof(entry) == TYPE_ARRAY:
		return entry
	if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("repos", null)) == TYPE_ARRAY:
		return entry.get("repos")
	return null


static func remember_repos(agent_id: String, detail: Dictionary) -> void:
	if agent_id.is_empty() or detail.is_empty() or not detail.has("repos"):
		return
	var repos: Variant = detail.get("repos")
	if typeof(repos) != TYPE_ARRAY:
		return
	var slugs: Array = []
	for repo in repos:
		if typeof(repo) != TYPE_DICTIONARY:
			continue
		var slug := _slug_from_url(str(repo.get("url", "")))
		if slug.is_empty() or slugs.has(slug):
			continue
		slugs.append(slug)
	var git := _git_fields(detail)
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry := _entry_for(agent_id)
	entry["repos"] = slugs
	entry["archived"] = str(detail.get("status", "")) == "ARCHIVED"
	if not str(git.get("branch", "")).is_empty():
		entry["branch"] = git["branch"]
	if entry.has("pr_url") and str(git.get("pr_url", "")).is_empty():
		pass
	else:
		entry["pr_url"] = str(git.get("pr_url", ""))
	_repo_cache[agent_id] = entry
	_write_repo_cache(_repo_cache)
	_repo_cache_lock.unlock()


static func _entry_for(agent_id: String) -> Dictionary:
	var previous: Variant = _repo_cache.get(agent_id, {})
	if typeof(previous) == TYPE_DICTIONARY:
		return (previous as Dictionary).duplicate()
	if typeof(previous) == TYPE_ARRAY:
		return {"repos": previous}
	return {}


static func _load_repo_cache() -> void:
	_repo_cache_lock.lock()
	var loaded := _repo_cache_loaded
	_repo_cache_lock.unlock()
	if loaded:
		return
	var parsed: Dictionary = {}
	if FileAccess.file_exists(_REPO_CACHE_PATH):
		var file := FileAccess.open(_REPO_CACHE_PATH, FileAccess.READ)
		if file:
			var raw: Variant = JSON.parse_string(file.get_as_text())
			if typeof(raw) == TYPE_DICTIONARY:
				parsed = raw
	_repo_cache_lock.lock()
	if not _repo_cache_loaded:
		_repo_cache = parsed
		_repo_cache_loaded = true
	_repo_cache_lock.unlock()


static func _write_repo_cache(snapshot: Dictionary) -> void:
	var file := FileAccess.open(_REPO_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("看板：写仓库缓存失败。")
		return
	file.store_string(JSON.stringify(snapshot))


static func _load_list_cache() -> void:
	_list_cache_lock.lock()
	var loaded := _list_cache_loaded
	_list_cache_lock.unlock()
	if loaded:
		return
	var parsed: Dictionary = {}
	if FileAccess.file_exists(_LIST_CACHE_PATH):
		var file := FileAccess.open(_LIST_CACHE_PATH, FileAccess.READ)
		if file:
			var raw: Variant = JSON.parse_string(file.get_as_text())
			if typeof(raw) == TYPE_DICTIONARY:
				parsed = raw
	_list_cache_lock.lock()
	if not _list_cache_loaded:
		_list_cache = parsed
		_list_cache_loaded = true
	_list_cache_lock.unlock()


static func _write_list_cache(snapshot: Dictionary) -> void:
	var file := FileAccess.open(_LIST_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("看板：写会话列表缓存失败。")
		return
	file.store_string(JSON.stringify(snapshot))


static func _session_from_list_item(item: Dictionary) -> Dictionary:
	var agent_id := str(item.get("id", ""))
	if agent_id.is_empty():
		return {}
	var status := str(item.get("status", ""))
	if status == "ARCHIVED":
		return {}
	var git := _git_fields(item)
	return {
		"id": agent_id,
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"working": status == "ACTIVE",
		"archived": false,
		"branch": git["branch"],
		"pr_url": git["pr_url"],
	}


static func _git_fields(item: Dictionary) -> Dictionary:
	var target: Variant = item.get("target", {})
	if typeof(target) != TYPE_DICTIONARY:
		target = {}
	var branch := str(target.get("branchName", target.get("branch_name", item.get("branch", "")))).strip_edges()
	var pr_url := str(target.get("prUrl", target.get("pr_url", item.get("pr_url", item.get("prUrl", ""))))).strip_edges()
	if branch == "<null>":
		branch = ""
	if pr_url == "<null>":
		pr_url = ""
	return {"branch": branch, "pr_url": pr_url}


static func _wait_status(client: HTTPClient, pending: Array) -> bool:
	var ticks := 0
	while client.get_status() in pending:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			return false
	return true
