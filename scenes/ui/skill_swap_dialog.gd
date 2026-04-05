extends CanvasLayer

## 技スロット満杯時の入れ替えダイアログ。
## 新しい技と入れ替えるスロットを選ぶ、または「入れ替えない」を選べる。

signal slot_selected(slot_index: int)
signal cancelled()

const CS = preload("res://scripts/systems/combat_system.gd")

var _is_showing: bool = false
var _cursor: int = 0  # 0-5: スロット, 6: キャンセル
var _new_skill_id: String = ""
var _new_skill_name: String = ""
var _player: Node = null


func _ready() -> void:
	visible = false
	$Panel/VBox/Buttons/BtnUp.pressed.connect(func() -> void:
		_cursor = maxi(_cursor - 1, 0); _update_display())
	$Panel/VBox/Buttons/BtnDown.pressed.connect(func() -> void:
		_cursor = mini(_cursor + 1, 6); _update_display())
	$Panel/VBox/Buttons/BtnSelect.pressed.connect(_on_accept)
	$Panel/VBox/Buttons/BtnCancel.pressed.connect(func() -> void:
		hide_dialog(); cancelled.emit())


func is_showing() -> bool:
	return _is_showing


func show_dialog(player: Node, new_skill_id: String, new_skill_name: String) -> void:
	_player = player
	_new_skill_id = new_skill_id
	_new_skill_name = new_skill_name
	_cursor = 0
	visible = true
	_is_showing = true
	_update_display()


func hide_dialog() -> void:
	visible = false
	_is_showing = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return

	if event.is_action_pressed("ui_up"):
		_cursor = maxi(_cursor - 1, 0)
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_cursor = mini(_cursor + 1, 6)
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_accept()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		hide_dialog()
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _on_accept() -> void:
	if _cursor < 6:
		# スロットに入れ替え
		_player.equip_skill(_cursor, _new_skill_id)
		hide_dialog()
		slot_selected.emit(_cursor)
	else:
		# キャンセル
		hide_dialog()
		cancelled.emit()


func _update_display() -> void:
	var label: Label = $Panel/VBox/Content
	if label == null:
		return
	var text: String = "-- 技スロットがいっぱい --\n\n"
	text += "新しい技: %s\n" % _new_skill_name
	text += "入れ替えるスロットを選んでください\n\n"

	for i in 6:
		var prefix: String = "> " if i == _cursor else "  "
		var sid = _player.skill_slots[i]
		if sid == null or sid == "":
			text += "%s[%d] ---\n" % [prefix, i + 1]
		else:
			var info: Dictionary = CS.SKILLS.get(sid, {})
			text += "%s[%d] %s\n" % [prefix, i + 1, info.get("name", sid)]

	var cancel_prefix: String = "> " if _cursor == 6 else "  "
	text += "\n%s入れ替えない\n" % cancel_prefix
	label.text = text
