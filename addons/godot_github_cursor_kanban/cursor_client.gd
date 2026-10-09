@tool
extends RefCounted

const _HOST := "api.cursor.com"
const _PAGE_SIZE := 20
const _REPO_CACHE_PATH := "user://kanban_agent_repos.json"

static var _repo_cache: Dictionary = {}
static var _repo_cache_loaded := false
static var _repo_cache_lock := Mutex.new()


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
		})
	return messages


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
	if str(detail.get("status", "")).to_upper() == "ARCHIVED":
		return {}
	if not _repos_include(detail.get("repos", []), repo_slug):
		return {}
	return {
		"name": str(detail.get("name", "")),
		"url": str(detail.get("url", "")),
		"working": str(detail.get("status", "")) == "ACTIVE",
	}


## 当前仓库推上去的分支。没有 PR 的分支也留下，检出要用。
static func branches_for_repo(run: Dictionary, repo_slug: String) -> Array:
	var found: Array = []
	var git: Variant = run.get("git", {})
	if typeof(git) != TYPE_DICTIONARY:
		return found
	var branches: Variant = git.get("branches", [])
	if typeof(branches) != TYPE_ARRAY:
		return found
	for entry in branches:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var repo_url := str(entry.get("repoUrl", ""))
		if not repo_url.is_empty() and not _same_repo(repo_url, repo_slug):
			continue
		var branch := str(entry.get("branch", ""))
		var pr_url := _normalize_pr_url(str(entry.get("prUrl", "")))
		if branch.is_empty() and pr_url.is_empty():
			continue
		found.append({"branch": branch, "pr_url": pr_url})
	return found


## 有 PR 且全部已合并才隐藏。没推 PR 的分支留下来，并作为检出目标。
static func checkout_target(branches: Array, merged_by_url: Dictionary) -> Dictionary:
	var branch := ""
	var pr_url := ""
	var bare := ""
	var saw_pr := false
	var saw_open := false
	for entry in branches:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var url := _normalize_pr_url(str(entry.get("pr_url", "")))
		var name := str(entry.get("branch", ""))
		if url.is_empty():
			if name.is_empty():
				continue
			saw_open = true
			if bare.is_empty():
				bare = name
			continue
		saw_pr = true
		if bool(merged_by_url.get(url, false)):
			continue
		saw_open = true
		if branch.is_empty():
			branch = name
			pr_url = url
	if branch.is_empty():
		branch = bare
	return {
		"hide": saw_pr and not saw_open,
		"branch": branch,
		"pr_url": pr_url,
	}


static func apply_git(patch: Dictionary, branches: Array, merged_by_url: Dictionary) -> Dictionary:
	var target := checkout_target(branches, merged_by_url)
	patch["hide_merged"] = bool(target.get("hide", false))
	patch["branch"] = str(target.get("branch", ""))
	patch["pr_url"] = str(target.get("pr_url", ""))
	return patch


static func annotate_git(patch: Dictionary, run: Dictionary, repo_slug: String) -> Dictionary:
	var branches := branches_for_repo(run, repo_slug)
	var merged := {}
	for entry in branches:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pr_url := str(entry.get("pr_url", ""))
		if pr_url.is_empty():
			continue
		if pr_is_merged(pr_url):
			merged[pr_url] = true
	return apply_git(patch, branches, merged)


static func pr_is_merged(pr_url: String) -> bool:
	var url := _normalize_pr_url(pr_url)
	if url.is_empty():
		return false
	var output: Array = []
	var code := OS.execute("gh", ["pr", "view", url, "--json", "state"], output, true)
	if code != 0 or output.is_empty():
		return false
	var text := ""
	for line in output:
		text += str(line)
	return _pr_state_is_merged(text)


static func _pr_state_is_merged(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text.strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return str(parsed.get("state", "")) == "MERGED"


static func _normalize_pr_url(pr_url: String) -> String:
	return pr_url.strip_edges().trim_suffix("/")


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


## 返回 1 显示、0 隐藏、-1 还没缓存。只表示仓库归属，归档和合并每次刷新仍要再查。
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


static func cached_branch(agent_id: String) -> String:
	var entry := _cache_entry(agent_id)
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return str(entry.get("branch", ""))


static func _cached_slugs(agent_id: String) -> Variant:
	var entry := _cache_entry(agent_id)
	if entry == null:
		return null
	if typeof(entry) == TYPE_ARRAY:
		return entry
	if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("repos", null)) == TYPE_ARRAY:
		return entry.get("repos")
	return null


static func _cache_entry(agent_id: String) -> Variant:
	if agent_id.is_empty():
		return null
	_load_repo_cache()
	_repo_cache_lock.lock()
	var known := _repo_cache.has(agent_id)
	var entry: Variant = _repo_cache.get(agent_id, null)
	_repo_cache_lock.unlock()
	if not known:
		return null
	return entry


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
	_load_repo_cache()
	_repo_cache_lock.lock()
	var previous: Variant = _repo_cache.get(agent_id, {})
	var branch := ""
	if typeof(previous) == TYPE_DICTIONARY:
		branch = str(previous.get("branch", ""))
	_repo_cache[agent_id] = {"repos": slugs, "branch": branch}
	var snapshot: Dictionary = _repo_cache.duplicate(true)
	_repo_cache_lock.unlock()
	_write_repo_cache(snapshot)


static func remember_branch(agent_id: String, branch: String) -> void:
	if agent_id.is_empty():
		return
	_load_repo_cache()
	_repo_cache_lock.lock()
	var entry: Variant = _repo_cache.get(agent_id, null)
	var record := {}
	if typeof(entry) == TYPE_ARRAY:
		record = {"repos": entry, "branch": branch}
	elif typeof(entry) == TYPE_DICTIONARY:
		record = entry.duplicate(true)
		record["branch"] = branch
	else:
		_repo_cache_lock.unlock()
		return
	_repo_cache[agent_id] = record
	var snapshot: Dictionary = _repo_cache.duplicate(true)
	_repo_cache_lock.unlock()
	_write_repo_cache(snapshot)


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


static func _session_from_list_item(item: Dictionary) -> Dictionary:
	var agent_id := str(item.get("id", ""))
	if agent_id.is_empty():
		return {}
	var status := str(item.get("status", ""))
	if status.to_upper() == "ARCHIVED":
		return {}
	return {
		"id": agent_id,
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"working": status == "ACTIVE",
		"archived": false,
		"branch": "",
		"pr_url": "",
	}


static func _wait_status(client: HTTPClient, pending: Array) -> bool:
	var ticks := 0
	while client.get_status() in pending:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			return false
	return true
