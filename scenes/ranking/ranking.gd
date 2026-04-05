extends Control

## ランキング画面。TOP10のスコアを一覧表示。

const GMS = preload("res://scripts/autoload/game_manager.gd")


func _ready() -> void:
	_display_ranking()
	$BackButton.pressed.connect(_go_back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_go_back()


func _go_back() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)


func _display_ranking() -> void:
	var label: Label = get_node_or_null("RankingLabel")
	if label == null:
		return

	var ranking: Array = _load_ranking()

	var text: String = "============================\n"
	text += "      RANKING  TOP 10\n"
	text += "============================\n\n"

	if ranking.is_empty():
		text += "  まだ記録がありません\n"
	else:
		text += " #   スコア     フロア  撃破  コンボ  結果\n"
		text += "--------------------------------------------\n"
		for i in ranking.size():
			var entry: Dictionary = ranking[i]
			var cleared_mark: String = "CLEAR" if entry.get("cleared", false) else "OVER"
			text += "%2d  %7d    %2dF   %3d体   x%d    %s\n" % [
				i + 1,
				int(entry.get("score", 0)),
				int(entry.get("floor_reached", 0)),
				int(entry.get("enemies_defeated", 0)),
				int(entry.get("max_combo", 0)),
				cleared_mark,
			]

	text += "\n============================\n"
	text += "  (決定キーでタイトルへ)\n"
	label.text = text


func _load_ranking() -> Array:
	var path: String = "user://ranking.json"
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []
	file.close()
	if json.data is Array:
		return json.data
	return []
