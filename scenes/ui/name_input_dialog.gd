extends Control

## ユーザー名入力ダイアログ。Controlベースで確実にボタンイベントを受ける。

signal name_submitted(player_name: String)

var _is_showing: bool = false


func _ready() -> void:
	visible = false
	$Panel/VBox/Buttons/BtnOK.pressed.connect(_on_submit)
	$Panel/VBox/Buttons/BtnSkip.pressed.connect(_on_skip)
	$Panel/VBox/NameInput.text_submitted.connect(func(_t: String) -> void: _on_submit())


func is_showing() -> bool:
	return _is_showing


func show_dialog() -> void:
	visible = true
	_is_showing = true
	$Panel/VBox/NameInput.text = ""
	$Panel/VBox/NameInput.grab_focus()


func _on_submit() -> void:
	var name_text: String = $Panel/VBox/NameInput.text.strip_edges()
	if name_text == "":
		name_text = "Anonymous"
	if name_text.length() > 12:
		name_text = name_text.substr(0, 12)
	visible = false
	_is_showing = false
	name_submitted.emit(name_text)


func _on_skip() -> void:
	visible = false
	_is_showing = false
	name_submitted.emit("Anonymous")


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_skip()
		get_viewport().set_input_as_handled()
