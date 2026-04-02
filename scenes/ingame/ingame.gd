extends Node2D

## InGameシーン: スプライトベースのダンジョン描画。
## GameSessionのビジュアル層。マップ・エンティティ・HUDを管理する。

const GameSessionScript = preload("res://scripts/systems/game_session.gd")
const GMS = preload("res://scripts/autoload/game_manager.gd")
const MapGen = preload("res://scripts/systems/map_generator.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const TILE_SIZE: int = 16
const SPRITE_SCALE: float = 16.0 / 128.0  # 0.125
const MOVE_DURATION: float = 0.12  # 移動補間の秒数

# テクスチャ
var tex_wall: Texture2D
var tex_floor: Texture2D
var tex_corridor: Texture2D
var tex_stairs: Texture2D
var tex_chest: Texture2D
var tex_trap: Texture2D
var tex_player_down: Texture2D
var tex_player_up: Texture2D
var tex_player_left: Texture2D
var tex_player_right: Texture2D
var tex_enemy_normal: Texture2D
var tex_enemy_ghost: Texture2D

const VirtualPadScene = preload("res://scenes/ui/virtual_pad.tscn")

var session: Node
var _facing: Vector2i = Vector2i.DOWN  # プレイヤーの向き（最後の移動方向）
var _is_animating: bool = false  # 移動アニメーション中
var _vpad: Node = null

# スプライトプール
var _map_sprites: Array[Sprite2D] = []
var _player_sprite: Sprite2D
var _enemy_sprites: Dictionary = {}  # enemy Node -> Sprite2D
var _enemy_labels: Dictionary = {}   # enemy Node -> Label


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

	_setup_virtual_pad()
	_create_player_sprite()
	_rebuild_map()
	_update_entities_immediate()
	_update_hud()
	_add_message("ステージ1 - 石器時代 1F")


func _setup_virtual_pad() -> void:
	_vpad = VirtualPadScene.instantiate()
	add_child(_vpad)
	_vpad.direction_pressed.connect(_do_move)
	_vpad.face_pressed.connect(_turn_facing)
	_vpad.skill_pressed.connect(_do_skill)
	_vpad.wait_pressed.connect(_do_wait)
	_vpad.interact_pressed.connect(_do_interact)


func _load_textures() -> void:
	tex_wall = load("res://assets/sprites/wall.png")
	tex_floor = load("res://assets/sprites/floor.png")
	tex_corridor = load("res://assets/sprites/corridor.png")
	tex_stairs = load("res://assets/sprites/stairs.png")
	tex_chest = load("res://assets/sprites/chest.png")
	tex_trap = load("res://assets/sprites/trap.png")
	tex_player_down = load("res://assets/sprites/player_down.png")
	tex_player_up = load("res://assets/sprites/player_up.png")
	tex_player_left = load("res://assets/sprites/player_left.png")
	tex_player_right = load("res://assets/sprites/player_right.png")
	tex_enemy_normal = load("res://assets/sprites/enemy_normal.png")
	tex_enemy_ghost = load("res://assets/sprites/enemy_ghost.png")


# --- 入力処理 ---

func _unhandled_input(event: InputEvent) -> void:
	if session == null or _is_animating:
		return

	# Shift+方向: その場で方向転換（ターン消費なし）
	if event is InputEventKey and event.pressed and event.shift_pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_turn_facing(Vector2i.UP)
			return
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_turn_facing(Vector2i.DOWN)
			return
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_turn_facing(Vector2i.LEFT)
			return
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_turn_facing(Vector2i.RIGHT)
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
			_do_skill(key - KEY_1)
		elif key == KEY_SPACE or key == KEY_PERIOD:
			_do_wait()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_do_interact()


func _turn_facing(direction: Vector2i) -> void:
	_facing = direction
	_update_player_facing()
	_update_hud()
	_add_message("向きを変えた [%s]" % _direction_name(direction))


func _do_move(direction: Vector2i) -> void:
	_facing = direction
	_update_player_facing()
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
			_rebuild_map()
			_update_entities_immediate()
			_update_hud()
		"chest_knowledge", "chest_item":
			_rebuild_map()
			_update_hud()
		"gimmick_resolved":
			_rebuild_map()
			_update_hud()
		"gimmick_failed":
			pass  # メッセージのみ（session.messageで通知済み）


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
	_cleanup_dead_sprites()
	_ensure_enemy_sprites()
	_update_hud()

	# アニメーション開始
	_is_animating = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# プレイヤーの移動補間
	var p_target: Vector2 = _grid_to_world(session.player.grid_pos)
	tween.tween_property(_player_sprite, "position", p_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# カメラの移動補間
	tween.tween_property($Camera2D, "position", p_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 敵の移動補間（スプライト + ラベル）
	for enemy in session.enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		var e_target: Vector2 = _grid_to_world(enemy.grid_pos)
		var lbl_target: Vector2 = Vector2(enemy.grid_pos.x * TILE_SIZE - 12, enemy.grid_pos.y * TILE_SIZE - 14)
		if _enemy_sprites.has(enemy):
			var spr: Sprite2D = _enemy_sprites[enemy]
			tween.tween_property(spr, "position", e_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if _enemy_labels.has(enemy):
			var lbl: Label = _enemy_labels[enemy]
			lbl.text = str(enemy.value)
			tween.tween_property(lbl, "position", lbl_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.set_parallel(false)
	tween.tween_callback(_on_animation_done)


func _on_animation_done() -> void:
	_is_animating = false
	_update_enemy_visuals()


# --- 座標変換 ---

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE * 0.5, grid_pos.y * TILE_SIZE + TILE_SIZE * 0.5)


# --- マップ描画 ---

func _rebuild_map() -> void:
	var map_layer: Node2D = $MapLayer
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
			spr.position = _grid_to_world(Vector2i(x, y))
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
	_player_sprite.texture = tex_player_down
	_player_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_player_sprite.z_index = 10
	$EntityLayer.add_child(_player_sprite)


func _update_player_facing() -> void:
	match _facing:
		Vector2i.UP:
			_player_sprite.texture = tex_player_up
		Vector2i.DOWN:
			_player_sprite.texture = tex_player_down
		Vector2i.LEFT:
			_player_sprite.texture = tex_player_left
		Vector2i.RIGHT:
			_player_sprite.texture = tex_player_right


func _update_entities_immediate() -> void:
	## フロア遷移時など、アニメーションなしで全エンティティを即座に配置
	var p_pos: Vector2i = session.player.grid_pos
	_player_sprite.position = _grid_to_world(p_pos)
	$Camera2D.position = _grid_to_world(p_pos)

	_cleanup_dead_sprites()
	_ensure_enemy_sprites()
	_update_enemy_visuals()


func _cleanup_dead_sprites() -> void:
	var active: Array = session.enemies
	var to_remove: Array = []
	for e in _enemy_sprites:
		if not is_instance_valid(e) or e.state == EnemyScript.EnemyState.DEFEATED or not (e in active):
			to_remove.append(e)
	for e in to_remove:
		if _enemy_sprites.has(e) and is_instance_valid(_enemy_sprites[e]):
			_enemy_sprites[e].queue_free()
		_enemy_sprites.erase(e)
		if _enemy_labels.has(e) and is_instance_valid(_enemy_labels[e]):
			_enemy_labels[e].queue_free()
		_enemy_labels.erase(e)


func _ensure_enemy_sprites() -> void:
	for enemy in session.enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		if not _enemy_sprites.has(enemy):
			_create_enemy_sprite(enemy)


func _update_enemy_visuals() -> void:
	for enemy in session.enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		if not _enemy_sprites.has(enemy):
			continue

		var spr: Sprite2D = _enemy_sprites[enemy]
		var e_pos: Vector2i = enemy.grid_pos
		spr.position = _grid_to_world(e_pos)

		if enemy.state == EnemyScript.EnemyState.GHOST:
			spr.texture = tex_enemy_ghost
		else:
			spr.texture = tex_enemy_normal

		if _enemy_labels.has(enemy):
			var lbl: Label = _enemy_labels[enemy]
			lbl.text = str(enemy.value)
			lbl.position = Vector2(e_pos.x * TILE_SIZE - 12, e_pos.y * TILE_SIZE - 14)
			if enemy.value < 0:
				lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
			else:
				lbl.add_theme_color_override("font_color", Color.WHITE)


func _create_enemy_sprite(enemy: Node) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex_enemy_normal
	spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	spr.z_index = 5
	$EntityLayer.add_child(spr)
	_enemy_sprites[enemy] = spr

	var lbl: Label = Label.new()
	lbl.text = str(enemy.value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.z_index = 20
	lbl.size = Vector2(40, 16)
	$EntityLayer.add_child(lbl)
	_enemy_labels[enemy] = lbl


# --- HUD ---

func _update_hud() -> void:
	var hud: Label = $UILayer/HUD
	var p: Node = session.player
	var combo_text: String = ""
	if session.score_system.combo_count > 0:
		combo_text = "  Combo: %d" % session.score_system.combo_count
	var facing_text: String = _direction_name(_facing)
	hud.text = "HP:%d/%d  MP:%d/%d  Lv:%d  F:%dF  Turn:%d  [%s]%s" % [
		p.hp, p.max_hp, p.mp, p.max_mp, p.level,
		session.current_floor, session.turn_manager.turn_count, facing_text, combo_text
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

	# バーチャルパッドの技名も更新
	if _vpad:
		var vpad_names: Array[String] = []
		for i in p.skill_slots.size():
			var sid = p.skill_slots[i]
			if sid == null or sid == "":
				vpad_names.append("---")
			else:
				var info: Dictionary = session.combat_system.get_skill_info(sid)
				vpad_names.append(info.get("name", sid))
		_vpad.update_skill_labels(vpad_names)


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
