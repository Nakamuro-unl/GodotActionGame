extends RefCounted

## InGameのポップアップ表示・アイテム使用のヘルパー。

const Data = preload("res://scenes/ingame/ingame_data.gd")
const ItemSysScript = preload("res://scripts/systems/item_system.gd")


## 知識獲得ポップアップを表示
static func show_knowledge_popup(popup: Node, session: Node, knowledge_id: String) -> void:
	if popup == null or knowledge_id == "":
		return
	var info: Dictionary = session.knowledge_system.get_info(knowledge_id)
	if info.is_empty():
		return
	var skill_desc: String = ""
	if info.has("skill_id") and info["skill_id"] != "":
		var skill_info: Dictionary = session.combat_system.get_skill_info(info["skill_id"])
		if not skill_info.is_empty():
			skill_desc = skill_info["name"]
	var field_desc: String = info.get("field_effect", "")
	var icon_name: String = Data.KNOWLEDGE_ICON_MAP.get(knowledge_id, "")
	popup.show_knowledge(info["name"], info["category"], skill_desc, field_desc, Data.get_icon_path(icon_name))


## アイテム獲得ポップアップを表示
static func show_item_popup(popup: Node, item_id: String) -> void:
	if popup == null or item_id == "":
		return
	var name_str: String = Data.ITEM_NAMES.get(item_id, item_id)
	var desc_str: String = Data.ITEM_DESCS.get(item_id, "")
	var icon_name: String = Data.ITEM_ICON_MAP.get(item_id, "")
	popup.show_item(name_str, desc_str, Data.get_icon_path(icon_name))


## アイテム使用処理
static func use_item(item_sys: Node, session: Node, item_index: int, facing: Vector2i) -> Dictionary:
	var target_pos: Vector2i = session.player.grid_pos + facing
	var target_enemy: Node = session._get_enemy_at(target_pos)
	return item_sys.use_item(session.player, item_index, target_enemy, session)


# --- 範囲攻撃 ---

static func enter_range_preview(session: Node, renderer: RefCounted, slot_index: int, facing: Vector2i) -> Array:
	var skill_id: String = session.player.skill_slots[slot_index]
	var cells: Array = session.combat_system.get_range_preview(skill_id, session.player.grid_pos, facing)
	renderer.show_range_preview(cells, session.enemies)
	return cells


static func fire_range_skill(session: Node, renderer: RefCounted, audio: Node, slot_index: int, facing: Vector2i) -> Dictionary:
	renderer.hide_range_preview()
	var skill_id: String = session.player.skill_slots[slot_index]
	var result: Dictionary = session.combat_system.use_range_skill(skill_id, session.player, session.enemies, facing)
	if result["success"]:
		renderer.animate_range_attack(result["cells"], renderer._entity_layer)
		audio.play("hit")
		session.score_system.register_turn()
		session.turn_manager.execute_player_action()
		for hit in result["hit_enemies"]:
			var enemy: Node = hit["enemy"]
			if enemy.state == 2:
				session._on_enemy_defeated(enemy)
	return result


static func cancel_range_preview(renderer: RefCounted) -> void:
	renderer.hide_range_preview()
