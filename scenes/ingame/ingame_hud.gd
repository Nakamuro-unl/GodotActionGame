extends RefCounted

## HUD表示の更新（ステータスバー、技スロットアイコン、バーチャルパッド連携）

const CS = preload("res://scripts/systems/combat_system.gd")
const Data = preload("res://scenes/ingame/ingame_data.gd")


static func update_status_bar(hud_label: Label, player: Node, session: Node, facing_name: String) -> void:
	var combo_text: String = ""
	if session.score_system.combo_count > 0:
		combo_text = "  Combo:%d" % session.score_system.combo_count
	hud_label.text = "Lv:%d  F:%dF  Turn:%d  [%s]%s" % [
		player.level,
		session.current_floor, session.turn_manager.turn_count, facing_name, combo_text
	]


static func update_gauges(ui_layer: Node, player: Node) -> void:
	var hp_bar: ProgressBar = ui_layer.get_node_or_null("HPBar")
	var hp_label: Label = ui_layer.get_node_or_null("HPLabel")
	var mp_bar: ProgressBar = ui_layer.get_node_or_null("MPBar")
	var mp_label: Label = ui_layer.get_node_or_null("MPLabel")
	if hp_bar:
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp
	if hp_label:
		hp_label.text = "HP %d/%d" % [player.hp, player.max_hp]
	if mp_bar:
		mp_bar.max_value = player.max_mp
		mp_bar.value = player.mp
	if mp_label:
		mp_label.text = "MP %d/%d" % [player.mp, player.max_mp]


static func update_skill_slots(container: HBoxContainer, player: Node, session: Node) -> void:
	for child in container.get_children():
		child.queue_free()

	for i in player.skill_slots.size():
		var sid = player.skill_slots[i]
		var slot_box: HBoxContainer = HBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 1)

		if sid == null or sid == "":
			var lbl: Label = Label.new()
			lbl.text = "[%d]---" % (i + 1)
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			slot_box.add_child(lbl)
		else:
			var icon_name: String = _find_skill_icon(sid, session)
			if icon_name != "":
				var icon_path: String = Data.get_icon_path(icon_name)
				if ResourceLoader.exists(icon_path):
					var tex_rect: TextureRect = TextureRect.new()
					tex_rect.texture = load(icon_path)
					tex_rect.custom_minimum_size = Vector2(16, 16)
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					slot_box.add_child(tex_rect)

			var info: Dictionary = session.combat_system.get_skill_info(sid)
			var lbl: Label = Label.new()
			var mp_cost: int = int(info.get("mp_cost", 0))
			if mp_cost > 0:
				lbl.text = "[%d]%s(%d)" % [i + 1, info.get("name", sid), mp_cost]
			else:
				lbl.text = "[%d]%s" % [i + 1, info.get("name", sid)]
			lbl.add_theme_font_size_override("font_size", 10)
			if player.mp < mp_cost:
				lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			slot_box.add_child(lbl)

		container.add_child(slot_box)


static func update_vpad(vpad: Node, player: Node, session: Node) -> void:
	if vpad == null or not vpad.visible:
		return
	var names: Array[String] = []
	var icons: Array[String] = []
	for i in player.skill_slots.size():
		var sid = player.skill_slots[i]
		if sid == null or sid == "":
			names.append("---")
			icons.append("")
		else:
			var info: Dictionary = session.combat_system.get_skill_info(sid)
			var mp_cost: int = int(info.get("mp_cost", 0))
			var display_name: String = info.get("name", sid)
			if mp_cost > 0:
				display_name += "\nMP%d" % mp_cost
			names.append(display_name)
			var icon_name: String = _find_skill_icon(sid, session)
			icons.append(Data.get_icon_path(icon_name))
	vpad.update_skill_labels(names, icons)


static func _find_skill_icon(skill_id: String, _session: Node) -> String:
	return Data.SKILL_ICON_MAP.get(skill_id, "")
