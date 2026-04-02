extends Control

## InGameシーン: GameSessionのビジュアル層。
## マップ描画、HUD表示、入力処理を担当する。

const GameSessionScript = preload("res://scripts/systems/game_session.gd")
const GMS = preload("res://scripts/autoload/game_manager.gd")
const MapGen = preload("res://scripts/systems/map_generator.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const TILE_SIZE: int = 16
const VIEW_TILES_X: int = 20
const VIEW_TILES_Y: int = 15

var session: Node
var _awaiting_skill_direction: bool = false
var _skill_slot_index: int = -1


func _ready() -> void:
	session = GameSessionScript.new()
	add_child(session)

	session.game_over.connect(_on_game_over)
	session.game_clear.connect(_on_game_clear)
	session.floor_changed.connect(_on_floor_changed)
	session.message.connect(_on_message)

	var seed_val: int = randi()
	session.start_new_game(seed_val)

	_update_hud()
	_update_map()
	_add_message("ステージ1 - 石器時代 1F")


func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return

	if _awaiting_skill_direction:
		_handle_skill_direction(event)
		return

	# 移動
	if event.is_action_pressed("ui_up"):
		_do_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_do_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		_do_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_do_move(Vector2i.RIGHT)
	# 技スロット (キー1-6)
	elif event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_6:
			_start_skill(key - KEY_1)
		elif key == KEY_SPACE or key == KEY_PERIOD:
			_do_wait()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_do_interact()


func _do_move(direction: Vector2i) -> void:
	if session.try_player_move(direction):
		_after_turn()


func _do_wait() -> void:
	session.score_system.register_turn()
	session.turn_manager.execute_player_action()
	_after_turn()


func _do_interact() -> void:
	var mg: Node = session.map_generator
	var stairs_pos: Vector2i = mg.get_stairs_position()
	if session.player.grid_pos == stairs_pos:
		session.interact_stairs()
		_update_map()
		_update_hud()
	# TODO: 宝箱チェック


func _start_skill(slot_index: int) -> void:
	if slot_index >= session.player.skill_slots.size():
		return
	var skill_id = session.player.skill_slots[slot_index]
	if skill_id == null or skill_id == "":
		return
	_awaiting_skill_direction = true
	_skill_slot_index = slot_index
	_add_message("方向を選択... (矢印キー / Escでキャンセル)")


func _handle_skill_direction(event: InputEvent) -> void:
	var direction: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_cancel"):
		_awaiting_skill_direction = false
		_add_message("キャンセル")
		return
	else:
		return

	_awaiting_skill_direction = false
	var result: Dictionary = session.try_use_skill(_skill_slot_index, direction)
	if result["success"]:
		var info: Dictionary = session.combat_system.get_skill_info(session.player.skill_slots[_skill_slot_index])
		_add_message("%s を使った! %d → %d" % [info["name"], result["old_value"], result["new_value"]])
		_after_turn()
	else:
		_add_message("そこに敵はいない")


func _after_turn() -> void:
	# 撃破済み敵を除去
	session.enemies = session.enemies.filter(
		func(e: Node) -> bool: return e.state != EnemyScript.EnemyState.DEFEATED
	)
	_update_hud()
	_update_map()


# --- HUD更新 ---

func _update_hud() -> void:
	var hud: Label = get_node_or_null("HUD")
	if hud == null:
		return
	var p: Node = session.player
	var combo_text: String = ""
	if session.score_system.combo_count > 0:
		combo_text = "  Combo: %d" % session.score_system.combo_count
	hud.text = "HP:%d/%d  MP:%d/%d  Lv:%d  F:%dF  Turn:%d%s" % [
		p.hp, p.max_hp, p.mp, p.max_mp, p.level,
		session.current_floor, session.turn_manager.turn_count, combo_text
	]

	# 技スロット
	var slot_label: Label = get_node_or_null("SkillSlots")
	if slot_label:
		var parts: Array[String] = []
		for i in p.skill_slots.size():
			var sid = p.skill_slots[i]
			if sid == null or sid == "":
				parts.append("[%d]---" % (i + 1))
			else:
				var info: Dictionary = session.combat_system.get_skill_info(sid)
				var name_str: String = info.get("name", sid)
				parts.append("[%d]%s" % [i + 1, name_str])
		slot_label.text = "  ".join(parts)


# --- マップ描画（テキストベース簡易版） ---

func _update_map() -> void:
	var map_label: Label = get_node_or_null("MapDisplay")
	if map_label == null:
		return

	var p_pos: Vector2i = session.player.grid_pos
	var half_x: int = VIEW_TILES_X / 2
	var half_y: int = VIEW_TILES_Y / 2
	var cam_x: int = clampi(p_pos.x - half_x, 0, MapGen.GRID_WIDTH - VIEW_TILES_X)
	var cam_y: int = clampi(p_pos.y - half_y, 0, MapGen.GRID_HEIGHT - VIEW_TILES_Y)

	var lines: Array[String] = []
	for y in VIEW_TILES_Y:
		var gy: int = cam_y + y
		var line: String = ""
		for x in VIEW_TILES_X:
			var gx: int = cam_x + x
			var pos: Vector2i = Vector2i(gx, gy)

			if pos == p_pos:
				line += "@"
			elif _is_enemy_at(pos):
				line += _get_enemy_char(pos)
			elif pos == session.map_generator.get_stairs_position():
				line += ">"
			else:
				var tile: int = session.grid[gy][gx]
				match tile:
					MapGen.Tile.WALL:
						line += "#"
					MapGen.Tile.FLOOR:
						line += "."
					MapGen.Tile.CORRIDOR:
						line += "."
					MapGen.Tile.STAIRS:
						line += ">"
					MapGen.Tile.CHEST:
						line += "!"
					_:
						line += " "
		lines.append(line)
	map_label.text = "\n".join(lines)


func _is_enemy_at(pos: Vector2i) -> bool:
	for e in session.enemies:
		if e.grid_pos == pos and e.state != EnemyScript.EnemyState.DEFEATED:
			return true
	return false


func _get_enemy_char(pos: Vector2i) -> String:
	for e in session.enemies:
		if e.grid_pos == pos and e.state != EnemyScript.EnemyState.DEFEATED:
			if e.state == EnemyScript.EnemyState.GHOST:
				return "g"
			return "E"
	return "."


# --- メッセージログ ---

var _messages: Array[String] = []

func _add_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 3:
		_messages.pop_front()
	var msg_label: Label = get_node_or_null("MessageLog")
	if msg_label:
		msg_label.text = "\n".join(_messages)


func _on_message(text: String) -> void:
	_add_message(text)


# --- イベント ---

func _on_game_over() -> void:
	_add_message("GAME OVER")
	var result: Dictionary = session.score_system.calculate_final(false, 0, 0)
	# リザルトへ遷移
	await get_tree().create_timer(1.5).timeout
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)


func _on_game_clear() -> void:
	_add_message("GAME CLEAR!")
	var result: Dictionary = session.score_system.calculate_final(true, session.player.hp, session.player.mp)
	await get_tree().create_timer(1.5).timeout
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.RESULT)


func _on_floor_changed(floor_number: int, stage: int) -> void:
	var stage_names: Array[String] = ["", "石器時代", "古代文明", "中世", "近代", "宇宙"]
	var stage_name: String = stage_names[stage] if stage < stage_names.size() else "???"
	_add_message("ステージ%d - %s %dF" % [stage, stage_name, floor_number])
