extends Node

## ゲーム全体の状態を管理するAutoLoadシングルトン。
## 画面遷移の制御と状態管理を担当する。

signal state_changed(old_state: State, new_state: State)

enum State {
	TITLE,
	INGAME,
	RESULT,
	RANKING,
	HOWTOPLAY,
	SETTINGS,
}

## 許可された遷移テーブル
const VALID_TRANSITIONS: Dictionary = {
	State.TITLE: [State.INGAME, State.RANKING, State.HOWTOPLAY, State.SETTINGS],
	State.INGAME: [State.RESULT],
	State.RESULT: [State.TITLE],
	State.RANKING: [State.TITLE],
	State.HOWTOPLAY: [State.TITLE],
	State.SETTINGS: [State.TITLE],
}

## シーンパステーブル
const SCENE_PATHS: Dictionary = {
	State.TITLE: "res://scenes/title/title.tscn",
	State.INGAME: "res://scenes/ingame/ingame.tscn",
	State.RESULT: "res://scenes/result/result.tscn",
	State.RANKING: "res://scenes/ranking/ranking.tscn",
	State.HOWTOPLAY: "res://scenes/howtoplay/howtoplay.tscn",
	State.SETTINGS: "res://scenes/settings/settings.tscn",
}

var current_state: State = State.TITLE
var should_load_save: bool = false
var last_result: Dictionary = {}  # リザルト画面に渡すスコアデータ


func change_state(new_state: State) -> bool:
	if not _is_valid_transition(new_state):
		push_warning("GameManager: Invalid transition from %s to %s" % [
			State.keys()[current_state], State.keys()[new_state]
		])
		return false

	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	_load_scene(new_state)
	return true


func _is_valid_transition(new_state: State) -> bool:
	if not VALID_TRANSITIONS.has(current_state):
		return false
	var allowed: Array = VALID_TRANSITIONS[current_state]
	return new_state in allowed


func _load_scene(state: State) -> void:
	if not SCENE_PATHS.has(state):
		return
	var tree := get_tree()
	if tree == null:
		return
	var path: String = SCENE_PATHS[state]
	if not ResourceLoader.exists(path):
		push_warning("GameManager: Scene not found: %s" % path)
		return
	tree.change_scene_to_file(path)
