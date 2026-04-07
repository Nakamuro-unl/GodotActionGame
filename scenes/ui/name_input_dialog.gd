extends CanvasLayer

## ユーザー名入力ダイアログ。PC: LineEdit、モバイル/Web: キーボード起動対応。

signal name_submitted(player_name: String)
signal cancelled()

var _is_showing: bool = false


func _ready() -> void:
	visible = false
	$Panel/VBox/BtnOK.pressed.connect(_on_submit)
	$Panel/VBox/BtnSkip.pressed.connect(_on_skip)
	$Panel/VBox/NameInput.text_submitted.connect(func(_t: String) -> void: _on_submit())


func is_showing() -> bool:
	return _is_showing


func show_dialog() -> void:
	visible = true
	_is_showing = true
	$Panel/VBox/NameInput.text = ""
	$Panel/VBox/NameInput.grab_focus()


func hide_dialog() -> void:
	visible = false
	_is_showing = false


func _on_submit() -> void:
	var name_text: String = $Panel/VBox/NameInput.text.strip_edges()
	if name_text == "":
		name_text = "Anonymous"
	# 最大12文字
	if name_text.length() > 12:
		name_text = name_text.substr(0, 12)
	hide_dialog()
	name_submitted.emit(name_text)


func _on_skip() -> void:
	hide_dialog()
	name_submitted.emit("Anonymous")


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_skip()
		get_viewport().set_input_as_handled()
