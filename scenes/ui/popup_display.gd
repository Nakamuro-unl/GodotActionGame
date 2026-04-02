extends CanvasLayer

## アイテム・知識獲得時のポップアップ表示。
## 表示中は入力をブロックし、決定キーで閉じる。

signal closed()

var _is_showing: bool = false


func _ready() -> void:
	visible = false
	$Panel/CloseButton.pressed.connect(hide_popup)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		hide_popup()
		get_viewport().set_input_as_handled()


func is_showing() -> bool:
	return _is_showing


## 知識獲得ポップアップ
func show_knowledge(knowledge_name: String, category: String, skill_desc: String, field_desc: String) -> void:
	var cat_name: String = ""
	match category:
		"definition": cat_name = "定義"
		"theorem": cat_name = "定理"
		"formula": cat_name = "公式"

	var text: String = "-- 知識を獲得 --\n\n"
	text += "「%s」\n" % knowledge_name
	text += "[%s]\n\n" % cat_name
	if skill_desc != "":
		text += "戦闘技: %s\n" % skill_desc
	if field_desc != "":
		text += "フィールド: %s\n" % field_desc
	text += "\n(決定キーで閉じる)"

	$Panel/ContentLabel.text = text
	_show()


## アイテム獲得ポップアップ
func show_item(item_name: String, item_desc: String) -> void:
	var text: String = "-- アイテムを獲得 --\n\n"
	text += "「%s」\n\n" % item_name
	if item_desc != "":
		text += "%s\n" % item_desc
	text += "\n(決定キーで閉じる)"

	$Panel/ContentLabel.text = text
	_show()


func _show() -> void:
	visible = true
	_is_showing = true


func hide_popup() -> void:
	visible = false
	_is_showing = false
	closed.emit()
