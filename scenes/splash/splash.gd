extends Control

## 起動スプラッシュ。FAMULITE LAB. → MATH MAGE タイトル → メニュー画面。
## タップ/キー入力でスキップ可能。

const GMS = preload("res://scripts/autoload/game_manager.gd")

enum Phase { LOGO, TITLE, DONE }

var _phase: Phase = Phase.LOGO
var _skippable: bool = false


func _ready() -> void:
	$LogoLabel.modulate = Color(1, 1, 1, 0)
	$TitleLabel.modulate = Color(1, 1, 1, 0)
	$TitleLabel.visible = false
	$SkipHint.modulate = Color(1, 1, 1, 0.4)
	_play_logo()


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip()
	elif event is InputEventScreenTouch and event.pressed:
		_skip()
	elif event is InputEventKey and event.pressed:
		_skip()


func _skip() -> void:
	match _phase:
		Phase.LOGO:
			_phase = Phase.TITLE
			_play_title()
		Phase.TITLE:
			_phase = Phase.DONE
			_go_to_menu()


func _play_logo() -> void:
	_phase = Phase.LOGO
	_skippable = false

	var tween: Tween = create_tween()
	tween.tween_property($LogoLabel, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func() -> void: _skippable = true)
	tween.tween_interval(1.5)
	tween.tween_property($LogoLabel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_play_title)


func _play_title() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.TITLE
	_skippable = false

	$LogoLabel.visible = false
	$TitleLabel.visible = true
	$TitleLabel.modulate = Color(1, 1, 1, 0)

	var tween: Tween = create_tween()
	tween.tween_property($TitleLabel, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func() -> void: _skippable = true)
	tween.tween_interval(2.0)
	tween.tween_property($TitleLabel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)
