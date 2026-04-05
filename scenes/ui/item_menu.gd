extends CanvasLayer

## アイテム選択メニュー。タッチボタン+キーボード両対応。

signal item_selected(index: int)
signal closed()

const ItemSys = preload("res://scripts/systems/item_system.gd")

var _is_showing: bool = false
var _items: Array[String] = []
var _cursor: int = 0


func _ready() -> void:
	visible = false
	$Panel/VBox/Buttons/BtnUp.pressed.connect(_cursor_up)
	$Panel/VBox/Buttons/BtnDown.pressed.connect(_cursor_down)
	$Panel/VBox/Buttons/BtnUse.pressed.connect(_use_item)
	$Panel/VBox/Buttons/BtnClose.pressed.connect(hide_menu)


func is_showing() -> bool:
	return _is_showing


func show_menu(items: Array[String]) -> void:
	_items = items
	_cursor = 0
	if _items.is_empty():
		return
	visible = true
	_is_showing = true
	_update_display()


func hide_menu() -> void:
	visible = false
	_is_showing = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_up"):
		_cursor_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_cursor_down()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_use_item()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()


func _cursor_up() -> void:
	_cursor = (_cursor - 1 + _items.size()) % _items.size()
	_update_display()


func _cursor_down() -> void:
	_cursor = (_cursor + 1) % _items.size()
	_update_display()


func _use_item() -> void:
	item_selected.emit(_cursor)
	hide_menu()


func _update_display() -> void:
	var label: Label = $Panel/VBox/ItemList
	if label == null:
		return
	var text: String = "-- アイテム (%d/%d) --\n\n" % [_items.size(), 10]
	for i in _items.size():
		var item_id: String = _items[i]
		var info: Dictionary = ItemSys.ITEM_DB.get(item_id, {})
		var name_str: String = info.get("name", item_id) if not info.is_empty() else item_id
		var desc: String = info.get("description", "") if not info.is_empty() else ""
		if i == _cursor:
			text += "> %s\n  %s\n" % [name_str, desc]
		else:
			text += "  %s\n" % name_str
	label.text = text
