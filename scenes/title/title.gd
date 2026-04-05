extends Control

## タイトル画面。ボタンタップ/キーボード両対応。

const GMS = preload("res://scripts/autoload/game_manager.gd")
const SaveMgr = preload("res://scripts/systems/save_manager.gd")

var _has_save: bool = false


func _ready() -> void:
	var sm: Node = SaveMgr.new()
	_has_save = sm.has_save_data()
	sm.free()

	$VBox/BtnStart.pressed.connect(_on_start)
	$VBox/BtnContinue.pressed.connect(_on_continue)
	$VBox/BtnRanking.pressed.connect(_on_ranking)
	$VBox/BtnHowTo.pressed.connect(_on_howto)
	$VBox/BtnSettings.pressed.connect(_on_settings)

	if not _has_save:
		$VBox/BtnContinue.disabled = true
		$VBox/BtnContinue.text = "つづきから (データなし)"

	$VBox.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.tween_property($VBox, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


func _on_start() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.should_load_save = false
		gm.change_state(GMS.State.INGAME)


func _on_continue() -> void:
	if not _has_save:
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.should_load_save = true
		gm.change_state(GMS.State.INGAME)


func _on_ranking() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RANKING)


func _on_howto() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.HOWTOPLAY)


func _on_settings() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.SETTINGS)
