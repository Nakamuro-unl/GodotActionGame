extends Control

## 起動スプラッシュ。FAMULITE LAB. → MATH MAGE タイトル → メニュー画面。
## 画面どこでもタップ/クリック/キー入力で即スキップ。

const GMS = preload("res://scripts/autoload/game_manager.gd")

enum Phase { LOGO, TITLE, DONE }

var _phase: Phase = Phase.LOGO
var _tween: Tween = null


func _ready() -> void:
	$LogoLabel.modulate = Color(1, 1, 1, 0)
	$TitleLabel.modulate = Color(1, 1, 1, 0)
	$TitleLabel.visible = false
	$SkipHint.modulate = Color(1, 1, 1, 0.4)
	_play_logo()


func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.DONE:
		return
	var is_press: bool = false
	if event is InputEventMouseButton and event.pressed:
		is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
	elif event is InputEventKey and event.pressed:
		is_press = true
	if is_press:
		_skip()
		get_viewport().set_input_as_handled()


func _skip() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	match _phase:
		Phase.LOGO:
			_play_title()
		Phase.TITLE:
			_go_to_menu()


func _play_logo() -> void:
	_phase = Phase.LOGO

	_tween = create_tween()
	_tween.tween_property($LogoLabel, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(0.8)
	_tween.tween_property($LogoLabel, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(_play_title)


func _play_title() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.TITLE

	$LogoLabel.visible = false
	$TitleLabel.visible = true
	$TitleLabel.modulate = Color(1, 1, 1, 0)

	_tween = create_tween()
	_tween.tween_property($TitleLabel, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(1.0)
	_tween.tween_property($TitleLabel, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	if _tween:
		_tween.kill()
		_tween = null
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)
