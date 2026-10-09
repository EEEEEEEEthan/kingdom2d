@tool
extends RefCounted

const _API := "https://api.cursor.com"


static func project_path() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


static func origin_slug(path: String) -> String:
	var output: Array = []
	var code := OS.execute("git", ["-C", path, "remote", "get-url", "origin"], output, true)
	if code != 0 or output.is_empty():
		return ""
	return _slug_from_remote(str(output[0]).strip_edges())


static func _slug_from_remote(remote: String) -> String:
	var text := remote.trim_suffix(".git")
	if text.contains("github.com"):
		var tail := text.split("github.com")[-1].trim_prefix(":").trim_prefix("/")
		return tail.strip_edges()
	return text


static func list_open_prs(repo_slug: String) -> Array[Dictionary]:
	var prs: Array[Dictionary] = []
	if repo_slug.is_empty():
		return prs
	var output: Array = []
	var code := OS.execute("gh", [
		"pr", "list", "--repo", repo_slug, "--state", "open",
		"--json", "number,title,headRefName,url",
	], output, true)
	if code != 0:
		push_warning("看板：拉取未合并 PR 失败。")
		return prs
	var parsed: Variant = JSON.parse_string("".join(output))
	if typeof(parsed) != TYPE_ARRAY:
		return prs
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		prs.append({
			"number": int(item.get("number", 0)),
			"title": str(item.get("title", "")),
			"branch": str(item.get("headRefName", "")),
			"url": str(item.get("url", "")),
		})
	return prs


static func list_sessions(token: String, repo_slug: String) -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	if token.is_empty():
		push_warning("看板：未配置 Cursor token，只列出 PR。")
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
	var agent_id := str(item.get("id", ""))
	var run_id := str(item.get("latestRunId", ""))
	var branch := ""
	var pr_url := ""
	var matches_repo := repo_slug.is_empty()
	if not run_id.is_empty():
		var run := _api_get(token, "/v1/agents/%s/runs/%s" % [agent_id, run_id])
		var git: Variant = run.get("git", {})
		if typeof(git) == TYPE_DICTIONARY:
			var branches: Variant = git.get("branches", [])
			if typeof(branches) == TYPE_ARRAY:
				for entry in branches:
					if typeof(entry) != TYPE_DICTIONARY:
						continue
					var repo_url := str(entry.get("repoUrl", ""))
					if not repo_slug.is_empty() and not repo_url.contains(repo_slug):
						continue
					matches_repo = true
					branch = str(entry.get("branch", ""))
					pr_url = str(entry.get("prUrl", ""))
					break
	if not matches_repo:
		return {}
	return {
		"id": agent_id,
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"working": str(item.get("status", "")) == "ACTIVE",
		"branch": branch,
		"pr_url": pr_url,
	}


static func merge_cards(sessions: Array[Dictionary], prs: Array[Dictionary]) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var used := {}
	for session in sessions:
		var pr := _match_pr(session, prs)
		if not pr.is_empty():
			used[str(pr["url"])] = true
		cards.append(_make_card(session, pr))
	for pr in prs:
		if used.has(str(pr["url"])):
			continue
		cards.append(_make_card({}, pr))
	return cards


static func _match_pr(session: Dictionary, prs: Array[Dictionary]) -> Dictionary:
	var pr_url := str(session.get("pr_url", "")).trim_suffix("/")
	var branch := str(session.get("branch", ""))
	for pr in prs:
		if not pr_url.is_empty() and str(pr["url"]).trim_suffix("/") == pr_url:
			return pr
	for pr in prs:
		if not branch.is_empty() and str(pr["branch"]) == branch:
			return pr
	return {}


static func _make_card(session: Dictionary, pr: Dictionary) -> Dictionary:
	var branch := ""
	if not pr.is_empty():
		branch = str(pr.get("branch", ""))
	elif not session.is_empty():
		branch = str(session.get("branch", ""))
	# 有 PR 就用 PR 名，没有 PR 才用聊天名。
	var title := ""
	if not pr.is_empty():
		title = str(pr.get("title", "")).strip_edges()
	else:
		title = str(session.get("name", "")).strip_edges()
	return {
		"title": title,
		"session_id": str(session.get("id", "")),
		"session_url": str(session.get("url", "")),
		"working": bool(session.get("working", false)),
		"pr_url": str(pr.get("url", "")),
		"pr_number": int(pr.get("number", 0)),
		"branch": branch,
	}


static func checkout_branch(path: String, branch: String) -> bool:
	if branch.is_empty() or branch.contains(" ") or branch.begins_with("-"):
		push_warning("看板：没有可检出的分支。")
		return false
	# -f 丢掉工作区和暂存区里的本地修改，未跟踪文件不动。
	var args := PackedStringArray(["-C", path, "checkout", "-f", branch])
	if OS.execute("git", ["-C", path, "show-ref", "--verify", "--quiet", "refs/heads/" + branch], [], true) != 0:
		var fetched := OS.execute("git", ["-C", path, "fetch", "origin", branch], [], true)
		if fetched != 0:
			push_warning("看板：拉取远程分支失败。")
			return false
		args = PackedStringArray(["-C", path, "checkout", "-f", "-B", branch, "--track", "origin/" + branch])
	var output: Array = []
	var code := OS.execute("git", args, output, true)
	if code != 0:
		push_warning("看板：检出分支失败。")
		return false
	return true


static func _api_get(token: String, path: String) -> Dictionary:
	var client := HTTPClient.new()
	var err := client.connect_to_host("api.cursor.com", 443, TLSOptions.client())
	if err != OK:
		push_warning("看板：连不上 Cursor API。")
		return {}
	var ticks := 0
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			push_warning("看板：连接 Cursor API 超时。")
			return {}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_warning("看板：连接 Cursor API 失败。")
		return {}
	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(token + ":"),
		"Accept: application/json",
	])
	err = client.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		push_warning("看板：请求 Cursor API 失败。")
		return {}
	ticks = 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		ticks += 1
		if ticks > 500:
			return {}
	if client.get_response_code() != 200:
		push_warning("看板：Cursor API 返回 %d。" % client.get_response_code())
		return {}
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			body.append_array(chunk)
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
