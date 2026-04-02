extends Node2D

## InGameシーン: スプライトベースのダンジョン描画。
## GameSessionのビジュアル層。マップ・エンティティ・HUDを管理する。

const GameSessionScript = preload("res://scripts/systems/game_session.gd")
const GMS = preload("res://scripts/autoload/game_manager.gd")
const MapGen = preload("res://scripts/systems/map_generator.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const TILE_SIZE: int = 16
const SPRITE_SCALE: float = 16.0 / 128.0  # 0.125

# テクスチャ
var tex_wall: Texture2D
var tex_floor: Texture2D
var tex_corridor: Texture2D
var tex_stairs: Texture2D
var tex_chest: Texture2D
var tex_trap: Texture2D
var tex_player: Texture2D
var tex_enemy_normal: Texture2D
var tex_enemy_ghost: Texture2D

var session: Node
var _awaiting_skill_direction: bool = false
var _skill_slot_index: int = -1

# スプライトプール
var _map_sprites: Array[Sprite2D] = []
var _player_sprite: Sprite2D
var _enemy_sprites: Dictionary = {}  # enemy Node -> Sprite2D
var _enemy_labels: Dictionary = {}   # enemy Node -> Label
var _view_w: int = 40
var _view_h: int = 30


func _ready() -> void:
	_load_textures()

	session = GameSessionScript.new()
	add_child(session)

	session.game_over.connect(_on_game_over)
	session.game_clear.connect(_on_game_clear)
	session.floor_changed.connect(_on_floor_changed)
	session.message.connect(_on_message)

	var seed_val: int = randi()
	session.start_new_game(seed_val)

	_create_player_sprite()
	_rebuild_map()
	_update_entities()
	_update_hud()
	_add_message("ステージ1 - 石器時代 1F")


func _load_textures() -> void:
	tex_wall = load("res://assets/sprites/wall.png")
	tex_floor = load("res://assets/sprites/floor.png")
	tex_corridor = load("res://assets/sprites/corridor.png")
	tex_stairs = load("res://assets/sprites/stairs.png")
	tex_chest = load("res://assets/sprites/chest.png")
	tex_trap = load("res://assets/sprites/trap.png")
	tex_player = load("res://assets/sprites/player.png")
	tex_enemy_normal = load("res://assets/sprites/enemy_normal.png")
	tex_enemy_ghost = load("res://assets/sprites/enemy_ghost.png")


# --- 入力処理 ---

func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return

	if _awaiting_skill_direction:
		_handle_skill_direction(event)
		return

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
	var stairs_pos: Vector2i = session.map_generator.get_stairs_position()
	if session.player.grid_pos == stairs_pos:
		session.interact_stairs()
		_rebuild_map()
		_update_entities()
		_update_hud()


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
		_add_message("%s を使った! %d -> %d" % [info["name"], result["old_value"], result["new_value"]])
		_after_turn()
	else:
		_add_message("そこに敵はいない")


func _after_turn() -> void:
	session.enemies = session.enemies.filter(
		func(e: Node) -> bool: return e.state != EnemyScript.EnemyState.DEFEATED
	)
	_update_entities()
	_update_hud()
	_update_camera()


# --- マップ描画 ---

func _rebuild_map() -> void:
	var map_layer: Node2D = $MapLayer
	# 既存スプライトをクリア
	for s in _map_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_map_sprites.clear()

	var g: Array = session.grid
	for y in MapGen.GRID_HEIGHT:
		for x in MapGen.GRID_WIDTH:
			var tile: int = g[y][x]
			var tex: Texture2D = _tile_to_texture(tile)
			if tex == null:
				continue
			var spr: Sprite2D = Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
			spr.position = Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			map_layer.add_child(spr)
			_map_sprites.append(spr)


func _tile_to_texture(tile: int) -> Texture2D:
	match tile:
		MapGen.Tile.WALL:
			return tex_wall
		MapGen.Tile.FLOOR:
			return tex_floor
		MapGen.Tile.CORRIDOR:
			return tex_corridor
		MapGen.Tile.STAIRS:
			return tex_stairs
		MapGen.Tile.CHEST:
			return tex_chest
		MapGen.Tile.TRAP:
			return tex_trap
	return null


# --- エンティティ描画 ---

func _create_player_sprite() -> void:
	_player_sprite = Sprite2D.new()
	_player_sprite.texture = tex_player
	_player_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_player_sprite.z_index = 10
	$EntityLayer.add_child(_player_sprite)


func _update_entities() -> void:
	# プレイヤー
	var p_pos: Vector2i = session.player.grid_pos
	_player_sprite.position = Vector2(p_pos.x * TILE_SIZE + TILE_SIZE * 0.5, p_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

	# 敵: 不要なスプライトを削除
	var active_enemies: Array = session.enemies
	var to_remove: Array = []
	for e in _enemy_sprites:
		if not is_instance_valid(e) or e.state == EnemyScript.EnemyState.DEFEATED or not (e in active_enemies):
			to_remove.append(e)
	for e in to_remove:
		if _enemy_sprites.has(e) and is_instance_valid(_enemy_sprites[e]):
			_enemy_sprites[e].queue_free()
		_enemy_sprites.erase(e)
		if _enemy_labels.has(e) and is_instance_valid(_enemy_labels[e]):
			_enemy_labels[e].queue_free()
		_enemy_labels.erase(e)

	# 敵: 新規追加・位置更新
	for enemy in active_enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue

		if not _enemy_sprites.has(enemy):
			_create_enemy_sprite(enemy)

		var spr: Sprite2D = _enemy_sprites[enemy]
		var e_pos: Vector2i = enemy.grid_pos
		spr.position = Vector2(e_pos.x * TILE_SIZE + TILE_SIZE * 0.5, e_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

		# テクスチャ切り替え
		if enemy.state == EnemyScript.EnemyState.GHOST:
			spr.texture = tex_enemy_ghost
		else:
			spr.texture = tex_enemy_normal

		# 数値ラベル更新（EntityLayer上で独立配置）
		if _enemy_labels.has(enemy):
			var lbl: Label = _enemy_labels[enemy]
			lbl.text = str(enemy.value)
			lbl.position = Vector2(e_pos.x * TILE_SIZE - 12, e_pos.y * TILE_SIZE - 14)
			if enemy.value < 0:
				lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
			else:
				lbl.add_theme_color_override("font_color", Color.WHITE)

	_update_camera()


func _create_enemy_sprite(enemy: Node) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex_enemy_normal
	spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	spr.z_index = 5
	$EntityLayer.add_child(spr)
	_enemy_sprites[enemy] = spr

	# 数値ラベル（EntityLayerに直接追加。スプライトのscaleの影響を受けない）
	var lbl: Label = Label.new()
	lbl.text = str(enemy.value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.z_index = 20
	lbl.size = Vector2(40, 16)
	$EntityLayer.add_child(lbl)
	_enemy_labels[enemy] = lbl


# --- カメラ ---

func _update_camera() -> void:
	var p_pos: Vector2i = session.player.grid_pos
	$Camera2D.position = Vector2(p_pos.x * TILE_SIZE + TILE_SIZE * 0.5, p_pos.y * TILE_SIZE + TILE_SIZE * 0.5)


# --- HUD ---

func _update_hud() -> void:
	var hud: Label = $UILayer/HUD
	var p: Node = session.player
	var combo_text: String = ""
	if session.score_system.combo_count > 0:
		combo_text = "  Combo: %d" % session.score_system.combo_count
	hud.text = "HP:%d/%d  MP:%d/%d  Lv:%d  F:%dF  Turn:%d%s" % [
		p.hp, p.max_hp, p.mp, p.max_mp, p.level,
		session.current_floor, session.turn_manager.turn_count, combo_text
	]

	var slot_label: Label = $UILayer/SkillSlots
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


# --- メッセージログ ---

var _messages: Array[String] = []

func _add_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 3:
		_messages.pop_front()
	var msg_label: Label = $UILayer/MessageLog
	if msg_label:
		msg_label.text = "\n".join(_messages)


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
