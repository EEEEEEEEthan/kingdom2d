extends SceneTree

const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")


func _init() -> void:
	var active: Dictionary = _Client._session_from_list_item({
		"id": "bc-1",
		"name": "做地图",
		"status": "ACTIVE",
		"url": "https://cursor.com/agents/bc-1",
	})
	if active.get("id", "") != "bc-1" or active.get("working", false) != true:
		_fail("ACTIVE 会话应显示为工作中")
	var idle: Dictionary = _Client._session_from_list_item({
		"id": "bc-2",
		"name": "空闲",
		"status": "IDLE",
	})
	if idle.is_empty() or idle.get("working", true) != false:
		_fail("IDLE 未归档会话也要显示")
	if not _Client._session_from_list_item({"id": "bc-3", "status": "ARCHIVED"}).is_empty():
		_fail("已归档会话不显示")
	if not _Client._session_from_list_item({"name": "没 id", "status": "ACTIVE"}).is_empty():
		_fail("没有 id 的项不显示")
	var slug := "EEEEEEEEthan/kingdom2d"
	if not _Client._same_repo("https://github.com/EEEEEEEEthan/kingdom2d", slug):
		_fail("https 仓库地址应对上 slug")
	if not _Client._same_repo("github.com/EEEEEEEEthan/kingdom2d", slug):
		_fail("无协议仓库地址应对上 slug")
	if not _Client._same_repo("git@github.com:EEEEEEEEthan/kingdom2d.git", slug):
		_fail("ssh 仓库地址应对上 slug")
	if _Client._same_repo("https://github.com/EEEEEEEEthan/kingdom2d-extra", slug):
		_fail("不能把别的仓库当成当前仓库")
	var repos: Array = [{"url": "https://github.com/EEEEEEEEthan/kingdom2d"}]
	if not _Client._repos_include(repos, slug):
		_fail("当前仓库的会话应留下")
	if _Client._repos_include([{"url": "https://github.com/other/repo"}], slug):
		_fail("别的仓库不显示")
	var kept: Dictionary = _Client.detail_patch({
		"name": "做地图",
		"url": "https://cursor.com/agents/bc-1",
		"status": "ACTIVE",
		"repos": [{"url": "https://github.com/EEEEEEEEthan/kingdom2d"}],
	}, slug)
	if kept.get("name", "") != "做地图" or kept.get("working", false) != true:
		_fail("当前仓库的详情应留下")
	if kept.get("pr_url", "x") != "" or kept.get("branch", "x") != "":
		_fail("没有 PR 时分支和链接应为空")
	var with_pr: Dictionary = _Client.detail_patch({
		"name": "做地图",
		"status": "FINISHED",
		"repos": repos,
		"target": {
			"branchName": "cursor/map-0007",
			"prUrl": "https://github.com/EEEEEEEEthan/kingdom2d/pull/9",
		},
	}, slug)
	if with_pr.get("branch", "") != "cursor/map-0007" or with_pr.get("pr_url", "") != "https://github.com/EEEEEEEEthan/kingdom2d/pull/9":
		_fail("详情里的 PR 和远程分支应留下")
	var listed: Dictionary = _Client._session_from_list_item({
		"id": "bc-pr",
		"name": "有 PR",
		"status": "FINISHED",
		"target": {"branchName": "cursor/map-0007", "prUrl": "https://github.com/EEEEEEEEthan/kingdom2d/pull/9"},
	})
	if listed.get("pr_url", "") == "" or listed.get("branch", "") != "cursor/map-0007":
		_fail("列表里的 PR 和远程分支应留下")
	if not _Client.detail_patch({
		"status": "IDLE",
		"repos": [{"url": "https://github.com/other/repo"}],
	}, slug).is_empty():
		_fail("别的仓库的详情应丢掉")
	if not _Client.detail_patch({"status": "ARCHIVED", "repos": repos}, slug).is_empty():
		_fail("已归档详情应丢掉")
	if not bool(_Client.detail_patch({}, slug).get("_error", false)):
		_fail("空详情应记为错误")
	_Client._repo_cache = {}
	_Client._repo_cache_loaded = true
	if _Client.cached_repo_match("bc-cache", slug) != -1:
		_fail("未查询过的会话不应命中缓存")
	_Client.remember_repos("bc-cache", {
		"repos": [{"url": "https://github.com/EEEEEEEEthan/kingdom2d"}],
	})
	if _Client.cached_repo_match("bc-cache", slug) != 1:
		_fail("缓存命中当前仓库应显示")
	if _Client.cached_repo_match("bc-cache", "other/repo") != 0:
		_fail("缓存命中别的仓库应隐藏")
	_Client.remember_repos("bc-empty", {})
	if _Client.cached_repo_match("bc-empty", slug) != -1:
		_fail("查询失败不能写入缓存")
	if _Client.format_message_time("2026-10-10T19:20:05") != "2026-10-10 19:20:05":
		_fail("无时区时间应格式化为 2026-10-10 19:20:05")
	if not _Client.format_message_time("").is_empty():
		_fail("空时间应留空")
	var now := _Client.format_now()
	if now.length() != 19 or now[10] != " ":
		_fail("当前时间格式应为 YYYY-MM-DD HH:MM:SS")
	if _Client.cached_archived("bc-cache") != 0:
		_fail("未归档的详情应记下未归档")
	_Client.remember_repos("bc-arch", {
		"status": "ARCHIVED",
		"repos": [{"url": "https://github.com/EEEEEEEEthan/kingdom2d"}],
	})
	if _Client.cached_archived("bc-arch") != 1:
		_fail("已归档的详情应记下归档")
	if _Client.cached_repo_match("bc-arch", slug) != 1:
		_fail("归档后仓库归属还在")
	_Client._repo_cache["bc-old"] = [slug.to_lower()]
	if _Client.cached_repo_match("bc-old", slug) != 1:
		_fail("旧的仓库缓存还能对上")
	if _Client.cached_archived("bc-old") != -1:
		_fail("旧缓存没有归档状态")
	print("repo_match_test ok")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
