extends Control

## リザルト画面。スコア内訳を表示し、ランキングに保存する。

const GMS = preload("res://scripts/autoload/game_manager.gd")
const ScoreSys = preload("res://scripts/systems/score_system.gd")
const SupabaseRanking = preload("res://scripts/systems/supabase_ranking.gd")

var _result: Dictionary = {}
var _supabase: Node


func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.last_result.is_empty():
		_result = gm.last_result
	_display_result()
	_save_ranking()
	_submit_online()
	$BackButton.pressed.connect(_go_back)


func _submit_online() -> void:
	if _result.is_empty():
		return
	_supabase = SupabaseRanking.new()
	add_child(_supabase)
	_supabase.score_submitted.connect(_on_score_submitted)
	_supabase.submit_score(_result)


func _on_score_submitted(success: bool) -> void:
	if success:
		var label: Label = get_node_or_null("ResultLabel")
		if label:
			label.text += "\n(オンラインランキングに登録しました)"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_go_back()


func _go_back() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)


func _display_result() -> void:
	var label: Label = get_node_or_null("ResultLabel")
	if label == null:
		return

	if _result.is_empty():
		label.text = "RESULT\n\nデータなし\n\n(決定キーでタイトルへ)"
		return

	var cleared: bool = _result.get("cleared", false)
	var header: String = "GAME CLEAR!" if cleared else "GAME OVER"

	var text: String = ""
	text += "============================\n"
	text += "  %s\n" % header
	text += "============================\n\n"
	text += "到達フロア:    %dF\n" % _result.get("floor_reached", 0)
	text += "撃破数:        %d体\n" % _result.get("enemies_defeated", 0)
	text += "最大コンボ:    %d\n" % _result.get("max_combo", 0)
	text += "知識収集:      %d個\n" % _result.get("knowledge_count", 0)
	text += "総ターン:      %d\n\n" % _result.get("total_turns", 0)
	text += "--- スコア内訳 ---\n"
	text += "撃破スコア:    +%d\n" % _result.get("kill_score", 0)
	text += "フロアスコア:  +%d\n" % _result.get("floor_score", 0)
	text += "ボスボーナス:  +%d\n" % _result.get("boss_bonus", 0)
	text += "知識ボーナス:  +%d\n" % _result.get("knowledge_bonus", 0)
	text += "コンボボーナス:+%d\n" % _result.get("combo_bonus", 0)
	if cleared:
		text += "残HPボーナス:  +%d\n" % _result.get("hp_bonus", 0)
		text += "残MPボーナス:  +%d\n" % _result.get("mp_bonus", 0)
	text += "ターンペナルティ: %d\n" % _result.get("turn_penalty", 0)
	text += "幽霊化ペナルティ: %d\n\n" % _result.get("ghost_penalty", 0)
	text += "============================\n"
	text += "  総合スコア:  %d\n" % _result.get("total", 0)
	text += "============================\n\n"
	text += "(決定キーでタイトルへ)"

	label.text = text


func _save_ranking() -> void:
	if _result.is_empty():
		return
	# ランキングファイルの読み込み
	var ranking: Array = _load_ranking()
	var entry: Dictionary = {
		"score": _result.get("total", 0),
		"floor_reached": _result.get("floor_reached", 0),
		"enemies_defeated": _result.get("enemies_defeated", 0),
		"max_combo": _result.get("max_combo", 0),
		"knowledge_count": _result.get("knowledge_count", 0),
		"total_turns": _result.get("total_turns", 0),
		"cleared": _result.get("cleared", false),
		"seed": _result.get("seed", 0),
		"date": Time.get_datetime_string_from_system(),
	}
	# ソートして追加
	ranking.append(entry)
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	while ranking.size() > 10:
		ranking.pop_back()
	_save_ranking_file(ranking)


func _load_ranking() -> Array:
	var path: String = "user://ranking.json"
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	file.close()
	if json.data is Array:
		return json.data
	return []


func _save_ranking_file(ranking: Array) -> void:
	var path: String = "user://ranking.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(ranking))
		file.close()
