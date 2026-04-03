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
var tex_player_down: Texture2D
var tex_player_up: Texture2D
var tex_player_left: Texture2D
var tex_player_right: Texture2D
var tex_enemy_normal: Texture2D
var tex_enemy_ghost: Texture2D

const VirtualPadScene = preload("res://scenes/ui/virtual_pad.tscn")
const SaveMgrScript = preload("res://scripts/systems/save_manager.gd")
const PopupScene = preload("res://scenes/ui/popup_display.tscn")

var session: Node
var _facing: Vector2i = Vector2i.DOWN  # プレイヤーの向き（最後の移動方向）
var _is_animating: bool = false  # 移動アニメーション中
var _vpad: Node = null
var _tile_map: TileMapLayer = null
var _popup: Node = null

# スプライト
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

	_setup_tile_map()
	_setup_virtual_pad()
	_setup_popup()
	_create_player_sprite()

	# セーブデータのロード or 新規ゲーム
	var gm: Node = get_node_or_null("/root/GameManager")
	var loaded: bool = false
	if gm and gm.should_load_save:
		var sm: Node = SaveMgrScript.new()
		loaded = sm.load_game(session)
		sm.free()
		gm.should_load_save = false

	if not loaded:
		var seed_val: int = randi()
		session.start_new_game(seed_val)

	_rebuild_map()
	_update_entities_immediate()
	_update_hud()
	if loaded:
		_add_message("セーブデータをロードしました (%dF)" % session.current_floor)
	else:
		_add_message("ステージ1 - 石器時代 1F")


func _setup_virtual_pad() -> void:
	_vpad = VirtualPadScene.instantiate()
	add_child(_vpad)
	_vpad.direction_pressed.connect(_do_move)
	_vpad.face_pressed.connect(_turn_facing)
	_vpad.skill_pressed.connect(_do_skill)
	_vpad.wait_pressed.connect(_do_wait)
	_vpad.interact_pressed.connect(_do_interact)


func _process(_delta: float) -> void:
	var debug_label: Label = $UILayer/DebugInfo
	if debug_label:
		var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
		var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var draw: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		debug_label.text = "FPS:%d  Nodes:%d  Draw:%d" % [fps, nodes, draw]


func _setup_popup() -> void:
	_popup = PopupScene.instantiate()
	add_child(_popup)


func _load_textures() -> void:
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
	if _popup and _popup.is_showing():
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
		"chest_knowledge":
			_rebuild_map()
			_update_hud()
			_show_knowledge_popup(result.get("knowledge_id", ""))
		"chest_item":
			_rebuild_map()
			_update_hud()
			_show_item_popup(result.get("item_id", ""))
		"gimmick_resolved":
			_rebuild_map()
			_update_hud()
		"gimmick_failed":
			pass  # メッセージのみ（session.messageで通知済み）


## 知識IDからアイコンパスを推定
const KNOWLEDGE_ICON_MAP: Dictionary = {
	"K-101": "math_infinity",    # 自然数の定義（汎用）
	"K-102": "math_sqrt",        # 加法
	"K-103": "math_sqrt",        # 減法
	"K-104": "math_zero_vector", # 零の発見
	"K-105": "math_infinity",    # 負の数
	"K-106": "math_vector",      # 数直線
	"K-201": "math_matrix",      # 乗法
	"K-202": "math_matrix",      # 除法
	"K-203": "math_probability", # 剰余
	"K-204": "math_sqrt",        # 分数の定義
	"K-205": "math_matrix",      # 倍数の定理
	"K-206": "math_log",         # 約数
	"K-301": "math_sqrt",        # 絶対値
	"K-302": "math_vector",      # 符号反転
	"K-303": "math_sqrt",        # 平方
	"K-304": "math_sqrt",        # 平方根
	"K-305": "math_topology",    # ピタゴラスの定理
	"K-306": "math_matrix",      # 一次方程式
	"K-401": "math_derivative",  # 微分
	"K-402": "math_integral",    # 積分
	"K-403": "math_probability", # 確率
	"K-404": "math_log",         # 対数
	"K-405": "math_probability", # 期待値の定理
	"K-406": "math_infinity",    # 極限
	"K-501": "math_vector",      # ベクトル
	"K-502": "math_matrix",      # 行列
	"K-503": "math_topology",    # 恒等写像
	"K-504": "math_zero_vector", # ゼロベクトル
	"K-505": "math_topology",    # 位相変換
	"K-506": "math_infinity",    # 無限の定義
}

const ITEM_ICON_MAP: Dictionary = {
	"herb": "item_herb",
	"upper_herb": "item_upper_herb",
	"panacea": "item_panacea",
	"wisdom_water": "item_wisdom_water",
	"awakening_water": "item_awakening_water",
	"elixir": "item_elixir",
	"even_powder": "item_even_powder",
	"odd_powder": "item_odd_powder",
	"zero_scroll": "item_zero_scroll",
	"reverse_mirror": "item_reverse_mirror",
	"halving_sand": "item_halving_sand",
	"map_piece": "item_map_piece",
	"clairvoyance": "item_clairvoyance",
	"return_wing": "item_return_wing",
	"warp_stone": "item_warp_stone",
	"exp_book": "item_exp_book",
	"skill_book": "item_skill_book",
	"slot_expansion": "item_slot_expansion",
}

const ITEM_NAMES: Dictionary = {
	"herb": "薬草",
	"upper_herb": "上薬草",
	"panacea": "万能薬",
	"wisdom_water": "知恵の水",
	"awakening_water": "覚醒の水",
	"elixir": "エリクサー",
	"even_powder": "偶数の粉",
	"odd_powder": "奇数の粉",
	"zero_scroll": "零の巻物",
	"reverse_mirror": "反転の鏡",
	"halving_sand": "半減の砂",
	"map_piece": "マップの欠片",
	"clairvoyance": "千里眼の水晶",
	"return_wing": "帰還の翼",
	"warp_stone": "ワープの石",
	"exp_book": "経験の書",
	"skill_book": "技の書",
	"slot_expansion": "スロット拡張",
}

const ITEM_DESCS: Dictionary = {
	"herb": "HPを10回復する",
	"upper_herb": "HPを30回復する",
	"panacea": "HPを全回復する",
	"wisdom_water": "MPを5回復する",
	"awakening_water": "MPを全回復する",
	"elixir": "HP/MPを全回復する",
	"even_powder": "敵の数値を最寄りの偶数にする",
	"odd_powder": "敵の数値を最寄りの奇数にする",
	"zero_scroll": "敵の数値を0にする",
	"reverse_mirror": "敵の数値の符号を反転する",
	"halving_sand": "敵の数値を半分にする",
	"map_piece": "現在フロアの地図を表示する",
	"clairvoyance": "敵と宝箱の位置を表示する",
	"return_wing": "フロアの入口に戻る",
	"warp_stone": "ランダムな部屋に移動する",
	"exp_book": "経験値を50獲得する",
	"skill_book": "未獲得の知識を1つ獲得する",
	"slot_expansion": "技スロットを1つ追加する",
}


func _get_icon_path(sprite_name: String) -> String:
	if sprite_name == "":
		return ""
	return "res://assets/sprites/%s.png" % sprite_name


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
	var icon_name: String = KNOWLEDGE_ICON_MAP.get(knowledge_id, "")
	_popup.show_knowledge(info["name"], info["category"], skill_desc, field_desc, _get_icon_path(icon_name))


func _show_item_popup(item_id: String) -> void:
	if _popup == null or item_id == "":
		return
	var name_str: String = ITEM_NAMES.get(item_id, item_id)
	var desc_str: String = ITEM_DESCS.get(item_id, "")
	var icon_name: String = ITEM_ICON_MAP.get(item_id, "")
	_popup.show_item(name_str, desc_str, _get_icon_path(icon_name))


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


## アトラス: 1024x1024, 8x8グリッド(128px/tile), 41タイル使用
## 0-5: マップ, 6-12: ギミック, 13-30: アイテム, 31-40: 数学記号
const ATLAS_TILE_SIZE: int = 128
const ATLAS_COLS: int = 8
const ATLAS_TILE_COUNT: int = 41
const TILESET_SOURCE_ID: int = 0

func _setup_tile_map() -> void:
	var atlas_tex: Texture2D = load("res://assets/sprites/tileset_atlas.png")

	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)

	for i in ATLAS_TILE_COUNT:
		var col: int = i % ATLAS_COLS
		var row: int = i / ATLAS_COLS
		source.create_tile(Vector2i(col, row))

	tileset.add_source(source, TILESET_SOURCE_ID)

	_tile_map = TileMapLayer.new()
	_tile_map.tile_set = tileset
	_tile_map.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)  # 128 -> 16px
	$MapLayer.add_child(_tile_map)


# --- マップ描画 ---

func _rebuild_map() -> void:
	_tile_map.clear()

	var g: Array = session.grid
	for y in MapGen.GRID_HEIGHT:
		for x in MapGen.GRID_WIDTH:
			var tile: int = g[y][x]
			var idx: int = _tile_to_atlas_index(tile)
			if idx < 0:
				continue
			var coords: Vector2i = Vector2i(idx % ATLAS_COLS, idx / ATLAS_COLS)
			_tile_map.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, coords)


func _tile_to_atlas_index(tile: int) -> int:
	match tile:
		MapGen.Tile.WALL: return 0
		MapGen.Tile.FLOOR: return 1
		MapGen.Tile.CORRIDOR: return 2
		MapGen.Tile.STAIRS: return 3
		MapGen.Tile.CHEST: return 4
		MapGen.Tile.TRAP: return 5
	return -1


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
