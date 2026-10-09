@tool
extends RefCounted

const _HOST := "api.cursor.com"


const _PAGE_SIZE := 20


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
	if str(detail.get("status", "")) == "ARCHIVED":
		return {}
	if not _repos_include(detail.get("repos", []), repo_slug):
		return {}
	return {
		"name": str(detail.get("name", "")),
		"url": str(detail.get("url", "")),
		"working": str(detail.get("status", "")) == "ACTIVE",
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
	var text := url.strip_edges().trim_suffix(".git")
	var tail := text
	if text.contains("github.com"):
		tail = text.split("github.com")[-1].trim_prefix(":").trim_prefix("/")
	tail = tail.strip_edges().trim_prefix("/")
	return tail.to_lower() == repo_slug.strip_edges().trim_prefix("/").to_lower()


static func _session_from_list_item(item: Dictionary) -> Dictionary:
	var agent_id := str(item.get("id", ""))
	if agent_id.is_empty():
		return {}
	var status := str(item.get("status", ""))
	if status == "ARCHIVED":
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
