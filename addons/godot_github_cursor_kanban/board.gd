@tool
extends RefCounted

const _API := "https://api.cursor.com"
const _CACHE_PATH := "user://kanban_agents.json"


static func project_path() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


static func origin_slug(path: String, job: Dictionary = {}) -> String:
	var from_file := _slug_from_git_config(path)
	if not from_file.is_empty():
		return from_file
	var result := _run("git", PackedStringArray(["-C", path, "remote", "get-url", "origin"]), _ensure_job(job))
	if not bool(result["ok"]):
		return ""
	return _repo_key(str(result["text"]))


static func _slug_from_git_config(start: String) -> String:
	var dir := start
	for _i in 8:
		var config_path := _git_config_path(dir)
		if not config_path.is_empty() and FileAccess.file_exists(config_path):
			var slug := _origin_from_config(FileAccess.get_file_as_string(config_path))
			if not slug.is_empty():
				return slug
		var parent := dir.get_base_dir()
		if parent == dir or parent.is_empty():
			break
		dir = parent
	return ""


static func _git_config_path(dir: String) -> String:
	var git_path := dir.path_join(".git")
	if DirAccess.dir_exists_absolute(git_path):
		return git_path.path_join("config")
	if not FileAccess.file_exists(git_path):
		return ""
	var text := FileAccess.get_file_as_string(git_path).strip_edges()
	if not text.begins_with("gitdir:"):
		return ""
	var gitdir := text.trim_prefix("gitdir:").strip_edges()
	if not gitdir.is_absolute_path():
		gitdir = dir.path_join(gitdir)
	return gitdir.path_join("config")


static func _origin_from_config(text: String) -> String:
	var in_origin := false
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			in_origin = line == '[remote "origin"]'
			continue
		if in_origin and line.begins_with("url"):
			return _repo_key(line.substr(line.find("=") + 1))
	return ""


static func _repo_key(remote: String) -> String:
	var text := remote.strip_edges().trim_suffix(".git").trim_suffix("/")
	text = text.replace("git@github.com:", "github.com/")
	if text.contains("://"):
		text = text.split("://")[-1]
	if text.contains("@"):
		text = text.split("@")[-1]
	var parts: PackedStringArray = []
	for part in text.split("/"):
		if not part.is_empty():
			parts.append(part)
	if parts.size() >= 3 and (parts[0].contains(".") or parts[0] == "github.com"):
		parts = parts.slice(1)
	if parts.size() >= 2:
		return (parts[0] + "/" + parts[1]).to_lower()
	return "/".join(parts).to_lower()


static func _same_repo(repo_url: String, repo_slug: String) -> bool:
	var left := _repo_key(repo_url)
	var right := _repo_key(repo_slug)
	return not left.is_empty() and left == right


static func load_agent_cache() -> Dictionary:
	if not FileAccess.file_exists(_CACHE_PATH):
		return {}
	var raw := FileAccess.get_file_as_string(_CACHE_PATH).strip_edges()
	if not raw.begins_with("{"):
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"agents": {}}
	if not parsed.has("agents"):
		return {"agents": parsed}
	return parsed


static func save_agent_cache(cache: Dictionary) -> void:
	var file := FileAccess.open(_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(cache))


static func list_sessions(token: String, repo_slug: String) -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	if token.is_empty():
		push_warning("看板：未配置 Cursor token。")
		return sessions
	var cursor := ""
	for _page in 5:
		var path := "/v1/agents?limit=100&includeArchived=false"
		if not cursor.is_empty():
			path += "&cursor=" + cursor.uri_encode()
		var payload := _api_get(token, path)
		if payload.is_empty():
			break
		var items: Variant = payload.get("items", [])
		if typeof(items) != TYPE_ARRAY:
			break
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var session := _session_from_agent(token, item, repo_slug)
			if not session.is_empty():
				sessions.append(session)
		cursor = str(payload.get("nextCursor", ""))
		if cursor.is_empty():
			break
	return sessions


static func _session_from_agent(token: String, item: Dictionary, repo_slug: String) -> Dictionary:
	var run_id := str(item.get("latestRunId", ""))
	var run := {}
	if not run_id.is_empty():
		run = _api_get(token, "/v1/agents/%s/runs/%s" % [str(item.get("id", "")), run_id])
	return session_from_agent(item, run, repo_slug)


static func merged_pr_index(repo_slug: String, job: Dictionary = {}) -> Dictionary:
	# 只用来丢掉已合并的会话，不把 PR 本身做成卡片。
	var index := {"urls": {}}
	if repo_slug.is_empty():
		return index
	var result := _run("gh", PackedStringArray([
		"pr", "list", "--repo", repo_slug, "--state", "merged", "--limit", "40",
		"--json", "url",
	]), _ensure_job(job))
	var text := str(result.get("text", "")).strip_edges()
	if not bool(result.get("ok", false)) or not text.begins_with("["):
		var detail := str(result.get("err", "")).strip_edges()
		if detail.is_empty():
			push_warning("看板：查已合并 PR 失败。")
		else:
			push_warning("看板：查已合并 PR 失败。 %s" % detail)
		return index
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("看板：查已合并 PR 失败。")
		return index
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var url := str(item.get("url", "")).trim_suffix("/")
		if not url.is_empty():
			index["urls"][url] = true
	return index


static func session_pr_merged(session: Dictionary, index: Dictionary) -> bool:
	var pr_url := str(session.get("pr_url", "")).trim_suffix("/")
	if pr_url.is_empty():
		return false
	var urls: Dictionary = index.get("urls", {})
	return bool(urls.get(pr_url, false))


static func merge_cards(sessions: Array[Dictionary], merged_index: Dictionary = {}) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var index_by_key := {}
	for session in sessions:
		if bool(session.get("archived", false)):
			continue
		if session_pr_merged(session, merged_index):
			continue
		var card := _make_card(session)
		if _is_empty_card(card):
			continue
		_upsert_card(cards, index_by_key, card)
	return cards


static func _upsert_card(cards: Array[Dictionary], index_by_key: Dictionary, card: Dictionary) -> void:
	var key := _dedup_key(card)
	if key.is_empty():
		return
	if index_by_key.has(key):
		var existing: int = index_by_key[key]
		cards[existing] = _prefer_card(cards[existing], card)
		return
	index_by_key[key] = cards.size()
	cards.append(card)


static func _dedup_key(card: Dictionary) -> String:
	var session_id := str(card.get("session_id", ""))
	if not session_id.is_empty():
		return "session:" + session_id
	var branch := str(card.get("branch", ""))
	if not branch.is_empty():
		return "branch:" + branch
	return ""


static func _prefer_card(left: Dictionary, right: Dictionary) -> Dictionary:
	var card := left.duplicate()
	var other := right
	if bool(other.get("working", false)) and not bool(card.get("working", false)):
		card["working"] = true
	if str(card.get("pr_url", "")).is_empty():
		card["pr_url"] = other.get("pr_url", "")
	if str(card.get("branch", "")).is_empty():
		card["branch"] = other.get("branch", "")
	if str(card.get("title", "")).is_empty():
		card["title"] = other.get("title", "")
	return card


static func _is_empty_card(card: Dictionary) -> bool:
	return str(card.get("session_id", "")).is_empty()


static func _make_card(session: Dictionary) -> Dictionary:
	var pr_url := str(session.get("pr_url", "")).strip_edges()
	return {
		"title": str(session.get("name", "")).strip_edges(),
		"session_id": str(session.get("id", "")),
		"session_url": str(session.get("url", "")),
		"working": bool(session.get("working", false)),
		"pr_url": pr_url,
		"pr_number": _pr_number_from_url(pr_url),
		"branch": str(session.get("branch", "")),
	}


static func _pr_number_from_url(pr_url: String) -> int:
	var parts := pr_url.trim_suffix("/").split("/")
	if parts.size() < 2 or parts[-2] != "pull":
		return 0
	return int(parts[-1])


static func reset_to_remote_default(path: String) -> bool:
	if OS.execute("git", ["-C", path, "fetch", "origin"], [], true) != 0:
		push_warning("看板：拉取远程失败。")
		return false
	var branch := remote_default_branch(path)
	if branch.is_empty() or branch.contains(" ") or branch.begins_with("-"):
		push_warning("看板：找不到远程主分支。")
		return false
	var output: Array = []
	var code := OS.execute("git", ["-C", path, "checkout", "-f", "-B", branch, "origin/" + branch], output, true)
	if code != 0:
		push_warning("看板：切回主分支失败。")
		return false
	return true


static func remote_default_branch(path: String) -> String:
	var output: Array = []
	if OS.execute("git", ["-C", path, "rev-parse", "--abbrev-ref", "origin/HEAD"], output, true) == 0:
		var name := "\n".join(PackedStringArray(output)).strip_edges()
		if name.begins_with("origin/"):
			return name.trim_prefix("origin/")
	for candidate in ["main", "master"]:
		if OS.execute("git", ["-C", path, "show-ref", "--verify", "--quiet", "refs/remotes/origin/" + candidate], [], true) == 0:
			return candidate
	return ""


static func list_messages(token: String, agent_id: String) -> Array[Dictionary]:
	if token.is_empty() or agent_id.is_empty():
		push_warning("看板：没有可刷新的对话。")
		return []
	var payload := _api_get(token, "/v0/agents/%s/conversation" % agent_id.uri_encode())
	return messages_from_payload(payload)


static func checkout_branch(path: String, branch: String) -> bool:
	if branch.is_empty() or branch.contains(" ") or branch.begins_with("-"):
		push_warning("看板：没有可检出的分支。")
		return false
	var job := _ensure_job({})
	if not bool(_run("git", PackedStringArray(["-C", path, "fetch", "origin", branch]), job)["ok"]):
		push_warning("看板：拉取远程分支失败。")
		return false
	# 丢掉已跟踪文件上的本地修改，再切到远程最新提交。
	if not bool(_run("git", PackedStringArray(["-C", path, "reset", "--hard"]), job)["ok"]):
		push_warning("看板：丢弃本地修改失败。")
		return false
	# -fd 只删未跟踪且未被 ignore 的文件和目录。
	if not bool(_run("git", PackedStringArray(["-C", path, "clean", "-fd"]), job)["ok"]):
		push_warning("看板：清理未跟踪文件失败。")
		return false
	if not bool(_run("git", PackedStringArray(["-C", path, "checkout", "-B", branch, "--track", "origin/" + branch]), job)["ok"]):
		push_warning("看板：检出分支失败。")
		return false
	return true


static func api_url(path: String) -> String:
	return _API + path


static func api_headers(token: String) -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(token + ":"),
		"Accept: application/json",
	])


static func agents_path(cursor: String) -> String:
	var path := "/v1/agents?limit=40&includeArchived=false"
	if not cursor.is_empty():
		path += "&cursor=" + cursor.uri_encode()
	return path


static func parse_object(body: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func messages_from_payload(payload: Dictionary) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
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


static func agent_repo_key(item: Dictionary) -> String:
	var repos: Variant = item.get("repos", [])
	if typeof(repos) != TYPE_ARRAY:
		return ""
	for entry in repos:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var key := _repo_key(str(entry.get("url", "")))
		if not key.is_empty():
			return key
	return ""


static func session_from_agent(item: Dictionary, run: Dictionary, repo_slug: String) -> Dictionary:
	var branch := ""
	var pr_url := ""
	if repo_slug.is_empty():
		return {}
	var matched := _same_repo(agent_repo_key(item), repo_slug)
	var git: Variant = run.get("git", {})
	if typeof(git) == TYPE_DICTIONARY:
		var branches: Variant = git.get("branches", [])
		if typeof(branches) == TYPE_ARRAY:
			for entry in branches:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				if not _same_repo(str(entry.get("repoUrl", "")), repo_slug):
					continue
				matched = true
				branch = str(entry.get("branch", ""))
				pr_url = str(entry.get("prUrl", ""))
				break
	if not matched:
		return {}
	return _session_dict(item, branch, pr_url)


static func session_from_cache(item: Dictionary, cached: Dictionary, repo_slug: String) -> Dictionary:
	if not _same_repo(str(cached.get("repo", "")), repo_slug):
		return {}
	return _session_dict(item, str(cached.get("branch", "")), str(cached.get("pr_url", "")))


static func _session_dict(item: Dictionary, branch: String, pr_url: String) -> Dictionary:
	var status := str(item.get("status", ""))
	return {
		"id": str(item.get("id", "")),
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"working": status == "ACTIVE",
		# 列表接口即使带了 includeArchived=false，仍按状态再挡一层。
		"archived": status == "ARCHIVED",
		"branch": branch,
		"pr_url": pr_url,
	}


static func _ensure_job(job: Dictionary) -> Dictionary:
	if job.get("mutex") is Mutex:
		return job
	return {"cancel": false, "pids": [], "mutex": Mutex.new()}


static func _cancelled(job: Dictionary) -> bool:
	var mutex: Mutex = job.get("mutex")
	if mutex == null:
		return bool(job.get("cancel", false))
	mutex.lock()
	var cancel := bool(job.get("cancel", false))
	mutex.unlock()
	return cancel


static func _run(program: String, args: PackedStringArray, job: Dictionary) -> Dictionary:
	if _cancelled(job):
		return {"ok": false, "text": ""}
	var launched := OS.execute_with_pipe(program, args, false)
	if typeof(launched) != TYPE_DICTIONARY or not launched.has("pid"):
		return {"ok": false, "text": "", "err": "拉不起 %s" % program}
	var pid := int(launched["pid"])
	var mutex: Mutex = job["mutex"]
	mutex.lock()
	(job["pids"] as Array).append(pid)
	mutex.unlock()
	var state := {"killed": false}
	var killer := Thread.new()
	killer.start(_watch_pid.bind(pid, job, 20000, state))
	var text := _read_pipe(launched.get("stdio"), pid)
	var err_text := _read_pipe(launched.get("stderr"), pid)
	if killer.is_started():
		killer.wait_to_finish()
	if OS.is_process_running(pid):
		OS.kill(pid)
	var code := OS.get_process_exit_code(pid)
	mutex.lock()
	(job["pids"] as Array).erase(pid)
	mutex.unlock()
	var body := text.strip_edges()
	var ok := not bool(state["killed"]) and not _cancelled(job) and (code == 0 or body.begins_with("["))
	return {"ok": ok, "text": text, "err": err_text.strip_edges()}


static func _read_pipe(file: Variant, pid: int) -> String:
	if not file is FileAccess:
		return ""
	var pipe := file as FileAccess
	var chunks := PackedByteArray()
	while true:
		var part := pipe.get_buffer(4096)
		if not part.is_empty():
			chunks.append_array(part)
			continue
		if pipe.eof_reached() or not OS.is_process_running(pid):
			break
		OS.delay_msec(10)
	return chunks.get_string_from_utf8()


static func _watch_pid(pid: int, job: Dictionary, timeout_ms: int, state: Dictionary) -> void:
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if _cancelled(job) or Time.get_ticks_msec() - start >= timeout_ms:
			state["killed"] = true
			OS.kill(pid)
			return
		OS.delay_msec(50)


static func _api_get(token: String, path: String) -> Dictionary:
	var client := HTTPClient.new()
	var err := client.connect_to_host("api.cursor.com", 443, TLSOptions.client())
	if err != OK:
		push_warning("看板：连不上 Cursor API。")
		client.close()
		return {}
	var ticks := 0
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			push_warning("看板：连接 Cursor API 超时。")
			client.close()
			return {}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_warning("看板：连接 Cursor API 失败。")
		client.close()
		return {}
	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(token + ":"),
		"Accept: application/json",
	])
	err = client.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		push_warning("看板：请求 Cursor API 失败。")
		client.close()
		return {}
	ticks = 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			client.close()
			return {}
	if client.get_response_code() != 200:
		push_warning("看板：Cursor API 返回 %d。" % client.get_response_code())
		client.close()
		return {}
	var body := PackedByteArray()
	ticks = 0
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			body.append_array(chunk)
		ticks += 1
		if ticks > 500:
			push_warning("看板：读取 Cursor API 超时。")
			client.close()
			return {}
	client.close()
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
