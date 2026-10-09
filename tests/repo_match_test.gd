extends SceneTree

const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")


func _init() -> void:
	var slug := "EEEEEEEEthan/kingdom2d"
	if not _Client._same_repo("https://github.com/EEEEEEEEthan/kingdom2d", slug):
		_fail("https 仓库地址应对上 slug")
	if not _Client._same_repo("github.com/EEEEEEEEthan/kingdom2d", slug):
		_fail("无协议仓库地址应对上 slug")
	if not _Client._same_repo("git@github.com:EEEEEEEEthan/kingdom2d.git", slug):
		_fail("ssh 仓库地址应对上 slug")
	if _Client._same_repo("https://github.com/EEEEEEEEthan/kingdom2d-extra", slug):
		_fail("不能把别的仓库当成当前仓库")
	var repos: Array = [{"url": "https://github.com/EEEEEEEEthan/kingdom2d", "startingRef": "master"}]
	if not _Client._repos_include(repos, slug):
		_fail("agent.repos 应能匹配当前仓库")
	var git := {
		"branches": [
			{"repoUrl": "github.com/other/repo", "branch": "cursor/other"},
			{"repoUrl": "github.com/EEEEEEEEthan/kingdom2d", "branch": "cursor/fix", "prUrl": "https://github.com/EEEEEEEEthan/kingdom2d/pull/1"},
		]
	}
	var picked: Dictionary = _Client._branch_for_repo(git, slug)
	if picked.get("branch", "") != "cursor/fix":
		_fail("应取当前仓库的分支")
	if _Client._branch_for_repo({}, slug).is_empty() == false:
		_fail("没有 git 时不应伪造分支")
	print("repo_match_test ok")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
