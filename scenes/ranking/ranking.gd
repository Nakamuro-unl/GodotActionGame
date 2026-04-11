extends Control

## ランキング画面。ローカル+オンライン(Supabase)ランキング表示。

const GMS = preload("res://scripts/autoload/game_manager.gd")
const SupabaseRanking = preload("res://scripts/systems/supabase_ranking.gd")

var _supabase: Node
var _tab: int = 0  # 0=オンライン, 1=ローカル
var _cached_rankings: Array = []
var _my_rank: int = -1
var _my_score: int = -1


func _ready() -> void:
	_display_loading()
	$BackButton.pressed.connect(_go_back)
	# 直近のプレイ結果からスコアを取得
	var gm := get_node_or_null("/root/GameManager")
	if gm and not gm.last_result.is_empty():
		_my_score = int(gm.last_result.get("total", 0))
	# オンラインランキングを取得
	_supabase = SupabaseRanking.new()
	add_child(_supabase)
	_supabase.rankings_loaded.connect(_on_rankings_loaded)
	_supabase.rank_loaded.connect(_on_rank_loaded)
	# 1フレーム待ってからfetch（HTTPRequest初期化完了を保証）
	_supabase.call_deferred("fetch_rankings")
	if _my_score > 0:
		_supabase.call_deferred("fetch_my_rank", _my_score)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_go_back()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_tab = 1 - _tab
		if _tab == 0:
			if _cached_rankings.is_empty():
				_display_loading()
				_supabase.fetch_rankings()
			else:
				_display_online_ranking()
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
		label.text += "   ONLINE RANKING  TOP 10\n"
		label.text += "============================\n\n"
		label.text += "  読み込み中...\n\n"
		label.text += "  (左右: ローカル/オンライン切替)"


func _on_rankings_loaded(rankings: Array) -> void:
	_cached_rankings = rankings
	_display_online_ranking()


func _on_rank_loaded(rank: int) -> void:
	_my_rank = rank
	# オンラインタブ表示中なら再描画
	if _tab == 0:
		_display_online_ranking()


func _display_online_ranking() -> void:
	var label: Label = get_node_or_null("RankingLabel")
	if label == null:
		return

	var text: String = "============================\n"
	text += "   ONLINE RANKING  TOP 10\n"
	text += "============================\n\n"

	if _cached_rankings.is_empty():
		text += "  まだ記録がありません\n"
	else:
		for i in mini(_cached_rankings.size(), 10):
			var e: Dictionary = _cached_rankings[i]
			var cleared_mark: String = " CLEAR" if e.get("cleared", false) else ""
			text += "%d. %s - %d pt\n" % [i + 1, str(e.get("player_name", "---")), int(e.get("score", 0))]
			text += "   %dF / %d体撃破%s\n" % [int(e.get("floor_reached", 0)), int(e.get("enemies_defeated", 0)), cleared_mark]

	# 自分の順位を表示
	if _my_rank > 0 and _my_score > 0:
		text += "\n----------------------------\n"
		text += "  あなたの順位: %d位 (%d pt)\n" % [_my_rank, _my_score]

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
		for i in ranking.size():
			var e: Dictionary = ranking[i]
			var cleared_mark: String = " CLEAR" if e.get("cleared", false) else ""
			text += "%d. %d pt\n" % [i + 1, int(e.get("score", 0))]
			text += "   %dF / %d体撃破 / x%dコンボ%s\n" % [
				int(e.get("floor_reached", 0)),
				int(e.get("enemies_defeated", 0)),
				int(e.get("max_combo", 0)),
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
