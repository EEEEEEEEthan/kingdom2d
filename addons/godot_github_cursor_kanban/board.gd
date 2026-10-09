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
	var status := str(item.get("status", ""))
	return {
		"id": agent_id,
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"working": status == "ACTIVE",
		# 列表接口即使带了 includeArchived=false，仍按状态再挡一层。
		"archived": status == "ARCHIVED",
		"branch": branch,
		"pr_url": pr_url,
	}


static func list_merged_prs(repo_slug: String) -> Array[Dictionary]:
	var prs: Array[Dictionary] = []
	if repo_slug.is_empty():
		return prs
	var output: Array = []
	var code := OS.execute("gh", [
		"pr", "list", "--repo", repo_slug, "--state", "merged", "--limit", "200",
		"--json", "number,title,headRefName,url",
	], output, true)
	if code != 0:
		push_warning("看板：拉取已合并 PR 失败。")
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


static func merge_cards(sessions: Array[Dictionary], prs: Array[Dictionary], merged_prs: Array[Dictionary] = []) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var index_by_key := {}
	for session in sessions:
		if bool(session.get("archived", false)):
			continue
		if _session_pr_merged(session, merged_prs):
			continue
		var pr := _match_pr(session, prs)
		var card := _make_card(session, pr)
		if _is_empty_card(card):
			continue
		_upsert_card(cards, index_by_key, card)
	for pr in prs:
		if _pr_in_list(pr, merged_prs):
			continue
		var card := _make_card({}, pr)
		if _is_empty_card(card):
			continue
		_upsert_card(cards, index_by_key, card)
	return cards


static func _session_pr_merged(session: Dictionary, merged_prs: Array[Dictionary]) -> bool:
	var pr_url := str(session.get("pr_url", "")).trim_suffix("/")
	var branch := str(session.get("branch", ""))
	if pr_url.is_empty() and branch.is_empty():
		return false
	for pr in merged_prs:
		if not pr_url.is_empty() and str(pr.get("url", "")).trim_suffix("/") == pr_url:
			return true
		if not branch.is_empty() and str(pr.get("branch", "")) == branch:
			return true
	return false


static func _pr_in_list(pr: Dictionary, prs: Array[Dictionary]) -> bool:
	var number := int(pr.get("number", 0))
	var url := str(pr.get("url", "")).trim_suffix("/")
	for item in prs:
		if number > 0 and int(item.get("number", 0)) == number:
			return true
		if not url.is_empty() and str(item.get("url", "")).trim_suffix("/") == url:
			return true
	return false


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
	var number := int(card.get("pr_number", 0))
	if number > 0:
		return "pr:%d" % number
	var branch := str(card.get("branch", ""))
	if not branch.is_empty():
		return "branch:" + branch
	var session_id := str(card.get("session_id", ""))
	if not session_id.is_empty():
		return "session:" + session_id
	return ""


static func _prefer_card(left: Dictionary, right: Dictionary) -> Dictionary:
	var card := left.duplicate()
	var other := right
	if str(card.get("session_id", "")).is_empty() and not str(other.get("session_id", "")).is_empty():
		card["session_id"] = other["session_id"]
		card["session_url"] = other["session_url"]
		card["working"] = other["working"]
	elif bool(other.get("working", false)) and not bool(card.get("working", false)):
		card["session_id"] = other.get("session_id", card.get("session_id", ""))
		card["session_url"] = other.get("session_url", card.get("session_url", ""))
		card["working"] = true
	if int(card.get("pr_number", 0)) == 0 and int(other.get("pr_number", 0)) > 0:
		card["pr_number"] = other["pr_number"]
		card["pr_url"] = other["pr_url"]
		card["title"] = other["title"]
	if str(card.get("branch", "")).is_empty():
		card["branch"] = other.get("branch", "")
	if str(card.get("title", "")).is_empty():
		card["title"] = other.get("title", "")
	return card


static func _is_empty_card(card: Dictionary) -> bool:
	return str(card.get("session_id", "")).is_empty() and int(card.get("pr_number", 0)) == 0 and str(card.get("pr_url", "")).is_empty()


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
	var args := PackedStringArray(["-C", path, "checkout", branch])
	if OS.execute("git", ["-C", path, "show-ref", "--verify", "--quiet", "refs/heads/" + branch], [], true) != 0:
		var fetched := OS.execute("git", ["-C", path, "fetch", "origin", branch], [], true)
		if fetched != 0:
			push_warning("看板：拉取远程分支失败。")
			return false
		args = PackedStringArray(["-C", path, "checkout", "-B", branch, "--track", "origin/" + branch])
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
			return {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
