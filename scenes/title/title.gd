extends Control

## タイトル画面
## メニュー選択で各画面に遷移する。

const GMS = preload("res://scripts/autoload/game_manager.gd")

@onready var menu_items: Array[String] = ["はじめから", "ランキング", "あそびかた", "せってい"]
var selected_index: int = 0


func _ready() -> void:
	_update_menu_display()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		selected_index = (selected_index - 1 + menu_items.size()) % menu_items.size()
		_update_menu_display()
	elif event.is_action_pressed("ui_down"):
		selected_index = (selected_index + 1) % menu_items.size()
		_update_menu_display()
	elif event.is_action_pressed("ui_accept"):
		_on_menu_selected()


func _on_menu_selected() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	match selected_index:
		0:
			gm.change_state(GMS.State.INGAME)
		1:
			gm.change_state(GMS.State.RANKING)
		2:
			gm.change_state(GMS.State.HOWTOPLAY)
		3:
			gm.change_state(GMS.State.SETTINGS)


func _update_menu_display() -> void:
	var label := get_node_or_null("MenuLabel") as Label
	if label == null:
		return
	var text := "MATH MAGE\n\n"
	for i in menu_items.size():
		if i == selected_index:
			text += "> %s\n" % menu_items[i]
		else:
			text += "  %s\n" % menu_items[i]
	label.text = text
