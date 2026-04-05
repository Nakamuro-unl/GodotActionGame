extends Control

## タイトル画面
## メニュー選択で各画面に遷移する。

const GMS = preload("res://scripts/autoload/game_manager.gd")
const SaveMgr = preload("res://scripts/systems/save_manager.gd")

@onready var menu_items: Array[String] = ["はじめから", "つづきから", "ランキング", "あそびかた", "せってい"]
var selected_index: int = 0
var _has_save: bool = false


func _ready() -> void:
	var sm: Node = SaveMgr.new()
	_has_save = sm.has_save_data()
	sm.free()
	_update_menu_display()
	_play_title_animation()


func _play_title_animation() -> void:
	var label: Label = get_node_or_null("MenuLabel")
	if label == null:
		return
	label.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


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
		0:  # はじめから
			gm.should_load_save = false
			gm.change_state(GMS.State.INGAME)
		1:  # つづきから
			if _has_save:
				gm.should_load_save = true
				gm.change_state(GMS.State.INGAME)
		2:  # ランキング
			gm.change_state(GMS.State.RANKING)
		3:  # あそびかた
			gm.change_state(GMS.State.HOWTOPLAY)
		4:  # せってい
			gm.change_state(GMS.State.SETTINGS)


func _update_menu_display() -> void:
	var label := get_node_or_null("MenuLabel") as Label
	if label == null:
		return
	var text := "MATH MAGE\n\n"
	for i in menu_items.size():
		var item_text: String = menu_items[i]
		# つづきからがセーブなしならグレー表示
		if i == 1 and not _has_save:
			item_text += " (データなし)"
		if i == selected_index:
			text += "> %s\n" % item_text
		else:
			text += "  %s\n" % item_text
	label.text = text
