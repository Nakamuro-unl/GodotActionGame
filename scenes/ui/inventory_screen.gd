extends CanvasLayer

## インベントリ画面。知識の装備/解除とアイテム確認。
## 表示中はゲームが一時停止（ターン消費なし）。

signal closed()

const KS = preload("res://scripts/systems/knowledge_system.gd")
const CS = preload("res://scripts/systems/combat_system.gd")
const ItemSys = preload("res://scripts/systems/item_system.gd")

enum Tab { SKILLS, KNOWLEDGE, ITEMS }

var _is_showing: bool = false
var _tab: Tab = Tab.SKILLS
var _cursor: int = 0
var _player: Node = null
var _knowledge_sys: Node = null
var _equippable: Array = []  # 装備可能な知識リスト


func _ready() -> void:
	visible = false
	$Panel/VBox/Buttons/BtnPrevTab.pressed.connect(func() -> void:
		_tab = (_tab - 1 + 3) % 3 as Tab; _cursor = 0; _update_display())
	$Panel/VBox/Buttons/BtnNextTab.pressed.connect(func() -> void:
		_tab = (_tab + 1) % 3 as Tab; _cursor = 0; _update_display())
	$Panel/VBox/Buttons/BtnUp.pressed.connect(func() -> void:
		_cursor = maxi(_cursor - 1, 0); _update_display())
	$Panel/VBox/Buttons/BtnDown.pressed.connect(func() -> void:
		_cursor += 1; _update_display())
	$Panel/VBox/Buttons/BtnAction.pressed.connect(_on_accept)
	$Panel/VBox/Buttons/BtnClose.pressed.connect(hide_inventory)


func is_showing() -> bool:
	return _is_showing


func show_inventory(player: Node, knowledge_sys: Node) -> void:
	_player = player
	_knowledge_sys = knowledge_sys
	_tab = Tab.SKILLS
	_cursor = 0
	_refresh_equippable()
	visible = true
	_is_showing = true
	_update_display()


func hide_inventory() -> void:
	visible = false
	_is_showing = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_tab = (_tab - 1 + 3) % 3 as Tab
		_cursor = 0
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_tab = (_tab + 1) % 3 as Tab
		_cursor = 0
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_cursor = maxi(_cursor - 1, 0)
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_cursor += 1
		_update_display()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_accept()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_equip_to_slot(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _on_accept() -> void:
	match _tab:
		Tab.SKILLS:
			_unequip_selected_slot()
		Tab.KNOWLEDGE:
			_equip_selected_knowledge()


func _unequip_selected_slot() -> void:
	if _player == null:
		return
	if _cursor < 0 or _cursor >= _player.skill_slots.size():
		return
	_player.unequip_skill(_cursor)
	_refresh_equippable()
	_update_display()


func _equip_selected_knowledge() -> void:
	if _player == null or _equippable.is_empty():
		return
	if _cursor < 0 or _cursor >= _equippable.size():
		return
	var skill_id: String = _equippable[_cursor]["skill_id"]
	# 既に装備済みか確認
	for s in _player.skill_slots:
		if s == skill_id:
			return
	_player.auto_equip_skill(skill_id)
	_refresh_equippable()
	_update_display()


func _equip_to_slot(slot_index: int) -> void:
	if _tab != Tab.KNOWLEDGE:
		return
	if _player == null or _equippable.is_empty():
		return
	if _cursor < 0 or _cursor >= _equippable.size():
		return
	if slot_index < 0 or slot_index >= _player.skill_slots.size():
		return
	var skill_id: String = _equippable[_cursor]["skill_id"]
	# 既に別スロットにあれば削除
	for i in _player.skill_slots.size():
		if _player.skill_slots[i] == skill_id:
			_player.skill_slots[i] = null
	_player.equip_skill(slot_index, skill_id)
	_refresh_equippable()
	_update_display()


func _refresh_equippable() -> void:
	if _knowledge_sys:
		_equippable = _knowledge_sys.get_equippable_skills()
	else:
		_equippable = []


func _update_display() -> void:
	var label: Label = $Panel/VBox/Content
	if label == null:
		return

	# タブヘッダ
	var tabs: Array[String] = ["技スロット", "知識", "アイテム"]
	var header: String = ""
	for i in tabs.size():
		if i == _tab:
			header += "[%s]  " % tabs[i]
		else:
			header += " %s   " % tabs[i]
	var text: String = header + "\n\n"

	match _tab:
		Tab.SKILLS:
			text += _render_skills_tab()
		Tab.KNOWLEDGE:
			text += _render_knowledge_tab()
		Tab.ITEMS:
			text += _render_items_tab()

	label.text = text


func _render_skills_tab() -> String:
	var text: String = ""
	for i in _player.skill_slots.size():
		var sid = _player.skill_slots[i]
		var prefix: String = "> " if i == _cursor else "  "
		if sid == null or sid == "":
			text += "%s[%d] ---\n" % [prefix, i + 1]
		else:
			var info: Dictionary = CS.SKILLS.get(sid, {})
			var name_str: String = info.get("name", sid)
			var mp: int = int(info.get("mp_cost", 0))
			text += "%s[%d] %s (MP:%d)\n" % [prefix, i + 1, name_str, mp]
	text += "\n(決定: 解除 / Esc: 閉じる)"
	_cursor = clampi(_cursor, 0, _player.skill_slots.size() - 1)
	return text


func _render_knowledge_tab() -> String:
	if _equippable.is_empty():
		return "装備可能な知識がありません\n"
	var text: String = ""
	for i in _equippable.size():
		var entry: Dictionary = _equippable[i]
		var prefix: String = "> " if i == _cursor else "  "
		var equipped: String = ""
		for s in _player.skill_slots:
			if s == entry["skill_id"]:
				equipped = " [装備中]"
				break
		var skill_info: Dictionary = CS.SKILLS.get(entry["skill_id"], {})
		var mp: int = int(skill_info.get("mp_cost", 0))
		text += "%s%s (MP:%d)%s\n" % [prefix, entry["name"], mp, equipped]
	text += "\n(決定/1-6: 装備 / Esc: 閉じる)"
	_cursor = clampi(_cursor, 0, _equippable.size() - 1)
	return text


func _render_items_tab() -> String:
	if _player.items.is_empty():
		return "アイテムなし\n"
	var text: String = "所持 (%d/%d)\n" % [_player.items.size(), 10]
	# アイテムをグループ化
	var counts: Dictionary = {}
	for item_id in _player.items:
		counts[item_id] = counts.get(item_id, 0) + 1
	var idx: int = 0
	for item_id in counts:
		var info: Dictionary = ItemSys.ITEM_DB.get(item_id, {})
		var name_str: String = info.get("name", item_id)
		var prefix: String = "> " if idx == _cursor else "  "
		text += "%s%s x%d\n" % [prefix, name_str, counts[item_id]]
		idx += 1
	_cursor = clampi(_cursor, 0, maxi(idx - 1, 0))
	return text
