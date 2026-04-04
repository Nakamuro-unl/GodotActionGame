extends Node2D

## InGameシーン: 入力処理・HUD・イベント管理。
## 描画は IngameRenderer、定数データは IngameData に分離。

const GameSessionScript = preload("res://scripts/systems/game_session.gd")
const GMS = preload("res://scripts/autoload/game_manager.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const VirtualPadScene = preload("res://scenes/ui/virtual_pad.tscn")
const SaveMgrScript = preload("res://scripts/systems/save_manager.gd")
const PopupScene = preload("res://scenes/ui/popup_display.tscn")
const Renderer = preload("res://scenes/ingame/ingame_renderer.gd")
const Data = preload("res://scenes/ingame/ingame_data.gd")
const ItemMenuScene = preload("res://scenes/ui/item_menu.tscn")
const ItemSysScript = preload("res://scripts/systems/item_system.gd")

var session: Node
var _facing: Vector2i = Vector2i.DOWN
var _is_animating: bool = false
var _vpad: Node = null
var _popup: Node = null
var _item_menu: Node = null
var _item_sys: Node = null
var _renderer: Renderer


func _ready() -> void:
	_renderer = Renderer.new()
	_renderer.setup($MapLayer, $EntityLayer)

	session = GameSessionScript.new()
	add_child(session)
	session.game_over.connect(_on_game_over)
	session.game_clear.connect(_on_game_clear)
	session.floor_changed.connect(_on_floor_changed)
	session.message.connect(_on_message)

	_vpad = VirtualPadScene.instantiate()
	add_child(_vpad)
	_vpad.direction_pressed.connect(_do_move)
	_vpad.face_pressed.connect(_turn_facing)
	_vpad.skill_pressed.connect(_do_skill)
	_vpad.wait_pressed.connect(_do_wait)
	_vpad.interact_pressed.connect(_do_interact)

	_popup = PopupScene.instantiate()
	add_child(_popup)

	_item_menu = ItemMenuScene.instantiate()
	add_child(_item_menu)
	_item_menu.item_selected.connect(_on_item_selected)

	_item_sys = ItemSysScript.new()
	add_child(_item_sys)

	# セーブデータのロード or 新規ゲーム
	var gm: Node = get_node_or_null("/root/GameManager")
	var loaded: bool = false
	if gm and gm.should_load_save:
		var sm: Node = SaveMgrScript.new()
		loaded = sm.load_game(session)
		sm.free()
		gm.should_load_save = false

	if not loaded:
		session.start_new_game(randi())

	_renderer.rebuild_map(session.grid)
	_renderer.update_entities_immediate(session.player.grid_pos, session.enemies, $Camera2D)
	_update_hud()
	if loaded:
		_add_message("セーブデータをロードしました (%dF)" % session.current_floor)
	else:
		_add_message("ステージ1 - 石器時代 1F")


func _process(_delta: float) -> void:
	var debug_label: Label = $UILayer/DebugInfo
	if debug_label:
		var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
		var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var draw: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		debug_label.text = "FPS:%d  Nodes:%d  Draw:%d" % [fps, nodes, draw]


# --- 入力処理 ---

func _unhandled_input(event: InputEvent) -> void:
	if session == null or _is_animating:
		return
	if _popup and _popup.is_showing():
		return
	if _item_menu and _item_menu.is_showing():
		return

	if event is InputEventKey and event.pressed and event.shift_pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_turn_facing(Vector2i.UP); return
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_turn_facing(Vector2i.DOWN); return
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_turn_facing(Vector2i.LEFT); return
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_turn_facing(Vector2i.RIGHT); return

	if event.is_action_pressed("ui_up"):
		_do_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_do_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		_do_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_do_move(Vector2i.RIGHT)
	elif event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_6:
			_do_skill(key - KEY_1)
		elif key == KEY_SPACE or key == KEY_PERIOD:
			_do_wait()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_do_interact()
		elif key == KEY_I:
			_open_item_menu()


func _turn_facing(direction: Vector2i) -> void:
	_facing = direction
	_renderer.update_player_facing(_facing)
	_update_hud()
	_add_message("向きを変えた [%s]" % _direction_name(direction))


func _do_move(direction: Vector2i) -> void:
	_facing = direction
	_renderer.update_player_facing(_facing)
	if session.try_player_move(direction):
		_after_turn_animated()


func _do_skill(slot_index: int) -> void:
	if slot_index >= session.player.skill_slots.size():
		return
	var skill_id = session.player.skill_slots[slot_index]
	if skill_id == null or skill_id == "":
		_add_message("技がセットされていない")
		return
	var result: Dictionary = session.try_use_skill(slot_index, _facing)
	if result["success"]:
		var info: Dictionary = session.combat_system.get_skill_info(skill_id)
		_add_message("%s を使った! %d -> %d" % [info["name"], result["old_value"], result["new_value"]])
		_after_turn_animated()
	else:
		_add_message("正面に敵がいない（向き: %s）" % _direction_name(_facing))


func _do_wait() -> void:
	session.score_system.register_turn()
	session.turn_manager.execute_player_action()
	_after_turn_animated()


func _do_interact() -> void:
	var result: Dictionary = session.interact(_facing)
	match result["type"]:
		"stairs":
			_renderer.rebuild_map(session.grid)
			_renderer.update_entities_immediate(session.player.grid_pos, session.enemies, $Camera2D)
			_update_hud()
		"chest_knowledge":
			_renderer.rebuild_map(session.grid)
			_update_hud()
			_show_knowledge_popup(result.get("knowledge_id", ""))
		"chest_item":
			_renderer.rebuild_map(session.grid)
			_update_hud()
			_show_item_popup(result.get("item_id", ""))
		"gimmick_resolved":
			_renderer.rebuild_map(session.grid)
			_update_hud()


func _direction_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP: return "上"
	if dir == Vector2i.DOWN: return "下"
	if dir == Vector2i.LEFT: return "左"
	if dir == Vector2i.RIGHT: return "右"
	return "?"


# --- ターン後の更新（アニメーション付き） ---

func _after_turn_animated() -> void:
	session.enemies = session.enemies.filter(
		func(e: Node) -> bool: return e.state != EnemyScript.EnemyState.DEFEATED
	)
	_renderer.cleanup_dead_sprites(session.enemies)
	_renderer.ensure_enemy_sprites(session.enemies)
	_update_hud()

	_is_animating = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	var p_target: Vector2 = _renderer.grid_to_world(session.player.grid_pos)
	tween.tween_property(_renderer.player_sprite, "position", p_target, Renderer.MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property($Camera2D, "position", p_target, Renderer.MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	for enemy in session.enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		var e_target: Vector2 = _renderer.grid_to_world(enemy.grid_pos)
		var lbl_target: Vector2 = Vector2(enemy.grid_pos.x * Renderer.TILE_SIZE - 12, enemy.grid_pos.y * Renderer.TILE_SIZE - 14)
		if _renderer.enemy_sprites.has(enemy):
			tween.tween_property(_renderer.enemy_sprites[enemy], "position", e_target, Renderer.MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if _renderer.enemy_labels.has(enemy):
			_renderer.enemy_labels[enemy].text = str(enemy.value)
			tween.tween_property(_renderer.enemy_labels[enemy], "position", lbl_target, Renderer.MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_is_animating = false
		_renderer.update_enemy_visuals(session.enemies)
	)


# --- ポップアップ ---

func _show_knowledge_popup(knowledge_id: String) -> void:
	if _popup == null or knowledge_id == "":
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
	_popup.show_knowledge(info["name"], info["category"], skill_desc, field_desc, Data.get_icon_path(icon_name))


func _show_item_popup(item_id: String) -> void:
	if _popup == null or item_id == "":
		return
	var name_str: String = Data.ITEM_NAMES.get(item_id, item_id)
	var desc_str: String = Data.ITEM_DESCS.get(item_id, "")
	var icon_name: String = Data.ITEM_ICON_MAP.get(item_id, "")
	_popup.show_item(name_str, desc_str, Data.get_icon_path(icon_name))


# --- アイテムメニュー ---

func _open_item_menu() -> void:
	if session.player.items.is_empty():
		_add_message("アイテムを持っていない")
		return
	_item_menu.show_menu(session.player.items)


func _on_item_selected(index: int) -> void:
	# 向き方向の隣接敵を探す（戦闘補助用）
	var target_pos: Vector2i = session.player.grid_pos + _facing
	var target_enemy: Node = session._get_enemy_at(target_pos)

	var result: Dictionary = _item_sys.use_item(session.player, index, target_enemy)
	if result["success"]:
		_add_message(result["message"])
		session.score_system.register_turn()
		session.turn_manager.execute_player_action()
		_after_turn_animated()
	else:
		_add_message(result.get("message", "使用できない"))


# --- HUD ---

func _update_hud() -> void:
	var p: Node = session.player
	var combo_text: String = ""
	if session.score_system.combo_count > 0:
		combo_text = "  Combo: %d" % session.score_system.combo_count
	$UILayer/HUD.text = "HP:%d/%d  MP:%d/%d  Lv:%d  F:%dF  Turn:%d  [%s]%s" % [
		p.hp, p.max_hp, p.mp, p.max_mp, p.level,
		session.current_floor, session.turn_manager.turn_count, _direction_name(_facing), combo_text
	]

	var parts: Array[String] = []
	for i in p.skill_slots.size():
		var sid = p.skill_slots[i]
		if sid == null or sid == "":
			parts.append("[%d]---" % (i + 1))
		else:
			var info: Dictionary = session.combat_system.get_skill_info(sid)
			parts.append("[%d]%s" % [i + 1, info.get("name", sid)])
	$UILayer/SkillSlots.text = "  ".join(parts)

	if _vpad:
		var vpad_names: Array[String] = []
		for i in p.skill_slots.size():
			var sid = p.skill_slots[i]
			if sid == null or sid == "":
				vpad_names.append("---")
			else:
				vpad_names.append(session.combat_system.get_skill_info(sid).get("name", sid))
		_vpad.update_skill_labels(vpad_names)


# --- メッセージログ ---

var _messages: Array[String] = []

func _add_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 3:
		_messages.pop_front()
	$UILayer/MessageLog.text = "\n".join(_messages)

func _on_message(text: String) -> void:
	_add_message(text)


# --- イベント ---

func _on_game_over() -> void:
	_add_message("GAME OVER")
	await get_tree().create_timer(1.5).timeout
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)

func _on_game_clear() -> void:
	_add_message("GAME CLEAR!")
	await get_tree().create_timer(1.5).timeout
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)

func _on_floor_changed(floor_number: int, stage: int) -> void:
	var stage_names: Array[String] = ["", "石器時代", "古代文明", "中世", "近代", "宇宙"]
	var stage_name: String = stage_names[stage] if stage < stage_names.size() else "???"
	_add_message("ステージ%d - %s %dF" % [stage, stage_name, floor_number])
