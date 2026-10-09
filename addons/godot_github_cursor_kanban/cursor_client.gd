@tool
extends RefCounted

const _HOST := "api.cursor.com"


static func list_unarchived_sessions(token: String, repo_slug: String) -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	if token.is_empty():
		push_warning("看板：未配置 Cursor token。")
		return sessions
	var cursor := ""
	for _page in 5:
		var path := "/v1/agents?limit=100&includeArchived=false"
		if not cursor.is_empty():
			path += "&cursor=" + cursor.uri_encode()
		var payload := request(token, HTTPClient.METHOD_GET, path)
		if payload.is_empty():
			break
		var items: Variant = payload.get("items", [])
		if typeof(items) != TYPE_ARRAY:
			break
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var session := _session_from_agent(token, item, repo_slug)
			if session.is_empty():
				continue
			if bool(session.get("archived", false)):
				continue
			sessions.append(session)
		cursor = str(payload.get("nextCursor", ""))
		if cursor.is_empty():
			break
	return sessions


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


static func _session_from_agent(token: String, item: Dictionary, repo_slug: String) -> Dictionary:
	var status := str(item.get("status", ""))
	if status == "ARCHIVED":
		return {}
	var agent_id := str(item.get("id", ""))
	var run_id := str(item.get("latestRunId", ""))
	var branch := ""
	var pr_url := ""
	var matches_repo := repo_slug.is_empty()
	if not run_id.is_empty():
		var run := request(token, HTTPClient.METHOD_GET, "/v1/agents/%s/runs/%s" % [agent_id, run_id])
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
		"working": status == "ACTIVE",
		"archived": false,
		"branch": branch,
		"pr_url": pr_url,
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
