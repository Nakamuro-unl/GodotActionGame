extends Control

## ランキング画面。ローカル+オンライン(Supabase)ランキング表示。

const GMS = preload("res://scripts/autoload/game_manager.gd")
const SupabaseRanking = preload("res://scripts/systems/supabase_ranking.gd")

var _supabase: Node
var _tab: int = 0  # 0=オンライン, 1=ローカル


func _ready() -> void:
	_display_loading()
	$BackButton.pressed.connect(_go_back)
	# オンラインランキングを取得
	_supabase = SupabaseRanking.new()
	add_child(_supabase)
	_supabase.rankings_loaded.connect(_on_rankings_loaded)
	_supabase.fetch_rankings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_go_back()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_tab = 1 - _tab
		if _tab == 0:
			_display_loading()
			_supabase.fetch_rankings()
		else:
			_display_local_ranking()


func _go_back() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)


func _display_loading() -> void:
	var label: Label = get_node_or_null("RankingLabel")
	if label:
		label.text = "============================\n"
		label.text += "   ONLINE RANKING  TOP 20\n"
		label.text += "============================\n\n"
		label.text += "  読み込み中...\n\n"
		label.text += "  (左右: ローカル/オンライン切替)"


func _on_rankings_loaded(rankings: Array) -> void:
	var label: Label = get_node_or_null("RankingLabel")
	if label == null:
		return

	var text: String = "============================\n"
	text += "   ONLINE RANKING  TOP 20\n"
	text += "============================\n\n"

	if rankings.is_empty():
		text += "  まだ記録がありません\n"
	else:
		text += " #   スコア     フロア  撃破  名前\n"
		text += "--------------------------------------\n"
		for i in mini(rankings.size(), 20):
			var entry: Dictionary = rankings[i]
			var cleared_mark: String = "*" if entry.get("cleared", false) else ""
			text += "%2d  %7d    %2dF   %3d体  %s%s\n" % [
				i + 1,
				int(entry.get("score", 0)),
				int(entry.get("floor_reached", 0)),
				int(entry.get("enemies_defeated", 0)),
				str(entry.get("player_name", "---")),
				cleared_mark,
			]

	text += "\n(左右: ローカル/オンライン切替)\n"
	text += "(決定キーでタイトルへ)"
	label.text = text


func _display_local_ranking() -> void:
	var label: Label = get_node_or_null("RankingLabel")
	if label == null:
		return

	var ranking: Array = _load_local_ranking()
	var text: String = "============================\n"
	text += "    LOCAL RANKING  TOP 10\n"
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

	text += "\n(左右: ローカル/オンライン切替)\n"
	text += "(決定キーでタイトルへ)"
	label.text = text


func _load_local_ranking() -> Array:
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
