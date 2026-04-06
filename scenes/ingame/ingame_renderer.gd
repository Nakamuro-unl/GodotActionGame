extends RefCounted

## InGameシーンのマップ・エンティティ描画を担当する。

const MapGen = preload("res://scripts/systems/map_generator.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const TILE_SIZE: int = 16
const SPRITE_SCALE: float = 16.0 / 128.0
const MOVE_DURATION: float = 0.12
const ATLAS_TILE_SIZE: int = 128
const ATLAS_COLS: int = 8
const ATLAS_TILE_COUNT: int = 69
const TILESET_SOURCE_ID: int = 0

const STAGE_TILE_INDEX: Dictionary = {
	1: {"wall": 0, "floor": 1},
	2: {"wall": 61, "floor": 62},
	3: {"wall": 63, "floor": 64},
	4: {"wall": 65, "floor": 66},
	5: {"wall": 67, "floor": 68},
}
var _current_stage: int = 1

var tex_player_down: Texture2D
var tex_player_up: Texture2D
var tex_player_left: Texture2D
var tex_player_right: Texture2D
var _preview_sprites: Array[Sprite2D] = []

var tex_enemy_normal: Texture2D
var tex_enemy_ghost: Texture2D
var tex_bosses: Dictionary = {}       # stage -> Texture2D
var tex_enemies: Dictionary = {}      # enemy_name -> Texture2D

var player_sprite: Sprite2D
var enemy_sprites: Dictionary = {}
var enemy_labels: Dictionary = {}
var tile_map: TileMapLayer

var _entity_layer: Node2D
var _map_layer: Node2D


func setup(map_layer: Node2D, entity_layer: Node2D) -> void:
	_map_layer = map_layer
	_entity_layer = entity_layer
	_load_textures()
	_setup_tile_map()
	_create_player_sprite()


func _load_textures() -> void:
	tex_player_down = load("res://assets/sprites/player_down.png")
	tex_player_up = load("res://assets/sprites/player_up.png")
	tex_player_left = load("res://assets/sprites/player_left.png")
	tex_player_right = load("res://assets/sprites/player_right.png")
	tex_enemy_normal = load("res://assets/sprites/enemy_normal.png")
	tex_enemy_ghost = load("res://assets/sprites/enemy_ghost.png")
	for i in range(1, 6):
		var path: String = "res://assets/sprites/boss_stage%d.png" % i
		if ResourceLoader.exists(path):
			tex_bosses[i] = load(path)
	# 敵別スプライト
	var enemy_sprite_map: Dictionary = {
		"子狼": "enemy_wolf", "猪": "enemy_boar", "熊": "enemy_bear",
		"サソリ": "enemy_scorpion", "砂蛇": "enemy_snake", "下級悪魔": "enemy_demon_low",
		"ゴブリン": "enemy_goblin", "ゴーレム": "enemy_golem", "上位悪魔": "enemy_demon_high",
		"機械兵": "enemy_soldier", "キメラ": "enemy_chimera", "マッドサイエンティスト": "enemy_scientist",
		"エイリアン": "enemy_alien", "ブラックホール": "enemy_blackhole", "次元虫": "enemy_worm",
	}
	for enemy_name in enemy_sprite_map:
		var path: String = "res://assets/sprites/%s.png" % enemy_sprite_map[enemy_name]
		if ResourceLoader.exists(path):
			tex_enemies[enemy_name] = load(path)


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

	tile_map = TileMapLayer.new()
	tile_map.tile_set = tileset
	tile_map.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_map_layer.add_child(tile_map)


func _create_player_sprite() -> void:
	player_sprite = Sprite2D.new()
	player_sprite.texture = tex_player_down
	player_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	player_sprite.z_index = 10
	_entity_layer.add_child(player_sprite)


# --- 座標変換 ---

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE * 0.5, grid_pos.y * TILE_SIZE + TILE_SIZE * 0.5)


# --- マップ描画 ---

func rebuild_map(grid: Array, stage: int = 1) -> void:
	_current_stage = stage
	tile_map.clear()
	for y in MapGen.GRID_HEIGHT:
		for x in MapGen.GRID_WIDTH:
			var tile: int = grid[y][x]
			var idx: int = _tile_to_atlas_index(tile)
			if idx < 0:
				continue
			var coords: Vector2i = Vector2i(idx % ATLAS_COLS, idx / ATLAS_COLS)
			tile_map.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, coords)


func _tile_to_atlas_index(tile: int) -> int:
	var stage_tiles: Dictionary = STAGE_TILE_INDEX.get(_current_stage, STAGE_TILE_INDEX[1])
	match tile:
		MapGen.Tile.WALL: return stage_tiles["wall"]
		MapGen.Tile.FLOOR: return stage_tiles["floor"]
		MapGen.Tile.CORRIDOR: return stage_tiles["floor"]  # 通路もステージ床色
		MapGen.Tile.STAIRS: return 3
		MapGen.Tile.CHEST: return 4
		MapGen.Tile.TRAP: return 5
	return -1


# --- プレイヤー向き ---

func update_player_facing(facing: Vector2i) -> void:
	match facing:
		Vector2i.UP:
			player_sprite.texture = tex_player_up
		Vector2i.DOWN:
			player_sprite.texture = tex_player_down
		Vector2i.LEFT:
			player_sprite.texture = tex_player_left
		Vector2i.RIGHT:
			player_sprite.texture = tex_player_right


# --- エンティティ描画 ---

func update_entities_immediate(player_pos: Vector2i, enemies: Array, camera: Camera2D) -> void:
	player_sprite.position = grid_to_world(player_pos)
	camera.position = grid_to_world(player_pos)
	cleanup_dead_sprites(enemies)
	ensure_enemy_sprites(enemies)
	update_enemy_visuals(enemies)


func cleanup_dead_sprites(enemies: Array) -> void:
	var to_remove: Array = []
	for e in enemy_sprites:
		if not is_instance_valid(e) or e.state == EnemyScript.EnemyState.DEFEATED or not (e in enemies):
			to_remove.append(e)
	for e in to_remove:
		if enemy_sprites.has(e) and is_instance_valid(enemy_sprites[e]):
			enemy_sprites[e].queue_free()
		enemy_sprites.erase(e)
		if enemy_labels.has(e) and is_instance_valid(enemy_labels[e]):
			enemy_labels[e].queue_free()
		enemy_labels.erase(e)


func ensure_enemy_sprites(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		if not enemy_sprites.has(enemy):
			_create_enemy_sprite(enemy)


func update_enemy_visuals(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		if not enemy_sprites.has(enemy):
			continue

		var spr: Sprite2D = enemy_sprites[enemy]
		var e_pos: Vector2i = enemy.grid_pos
		spr.position = grid_to_world(e_pos)

		if enemy.state == EnemyScript.EnemyState.GHOST:
			spr.texture = tex_enemy_ghost
		elif enemy.ai_pattern == EnemyScript.AIPattern.BOSS:
			spr.texture = _get_boss_texture(enemy)
		elif tex_enemies.has(enemy.enemy_name):
			spr.texture = tex_enemies[enemy.enemy_name]
		else:
			spr.texture = tex_enemy_normal

		if enemy_labels.has(enemy):
			var lbl: Label = enemy_labels[enemy]
			lbl.text = str(enemy.value)
			lbl.position = Vector2(e_pos.x * TILE_SIZE - 12, e_pos.y * TILE_SIZE - 14)
			if enemy.value < 0:
				lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
			else:
				lbl.add_theme_color_override("font_color", Color.WHITE)


## ミニマップをColorRectとして描画し、Imageテクスチャに書き込む
func render_minimap(grid: Array, minimap_data: Node, player_pos: Vector2i, enemies: Array, texture_rect: TextureRect) -> void:
	var w: int = grid[0].size()
	var h: int = grid.size()
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.8))

	for y in h:
		for x in w:
			var pos: Vector2i = Vector2i(x, y)
			if not minimap_data.is_explored(pos):
				continue
			var tile: int = grid[y][x]
			match tile:
				0:  # WALL
					img.set_pixel(x, y, Color(0.35, 0.35, 0.4, 1.0))
				1, 2:  # FLOOR, CORRIDOR
					img.set_pixel(x, y, Color(0.55, 0.47, 0.37, 1.0))
				3:  # STAIRS
					img.set_pixel(x, y, Color(1.0, 1.0, 0.4, 1.0))
				4:  # CHEST
					img.set_pixel(x, y, Color(0.9, 0.7, 0.2, 1.0))

	# 敵の位置
	for enemy in enemies:
		if enemy.state != EnemyScript.EnemyState.DEFEATED:
			if minimap_data.is_explored(enemy.grid_pos):
				var ep: Vector2i = enemy.grid_pos
				if ep.x >= 0 and ep.x < w and ep.y >= 0 and ep.y < h:
					img.set_pixel(ep.x, ep.y, Color(0.9, 0.2, 0.2, 1.0))

	# プレイヤーの位置
	if player_pos.x >= 0 and player_pos.x < w and player_pos.y >= 0 and player_pos.y < h:
		img.set_pixel(player_pos.x, player_pos.y, Color(0.2, 0.5, 1.0, 1.0))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	texture_rect.texture = tex


func _get_boss_texture(enemy: Node) -> Texture2D:
	for stage in EnemyScript.BOSS_DATA:
		if EnemyScript.BOSS_DATA[stage]["name"] == enemy.enemy_name:
			if tex_bosses.has(stage):
				return tex_bosses[stage]
	return tex_enemy_normal


## 範囲攻撃プレビュー: 対象セルをハイライト表示
func show_range_preview(cells: Array, enemies: Array) -> void:
	hide_range_preview()
	for cell in cells:
		var spr: Sprite2D = Sprite2D.new()
		# 敵がいるマスは赤、空マスは青
		var has_enemy: bool = false
		for enemy in enemies:
			if enemy.grid_pos == cell and enemy.state != EnemyScript.EnemyState.DEFEATED:
				has_enemy = true
				break
		var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		if has_enemy:
			img.fill(Color(1.0, 0.3, 0.3, 0.45))
		else:
			img.fill(Color(0.3, 0.5, 1.0, 0.3))
		spr.texture = ImageTexture.create_from_image(img)
		spr.scale = Vector2(TILE_SIZE / 4.0, TILE_SIZE / 4.0)
		spr.position = grid_to_world(cell)
		spr.z_index = 3
		_entity_layer.add_child(spr)
		_preview_sprites.append(spr)


## プレビューを非表示
func hide_range_preview() -> void:
	for spr in _preview_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	_preview_sprites.clear()


## 範囲攻撃エフェクト: セルを順番にフラッシュ
func animate_range_attack(cells: Array, owner_node: Node) -> Tween:
	var tween: Tween = owner_node.create_tween()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		tween.tween_callback(func() -> void:
			var spr: Sprite2D = Sprite2D.new()
			var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(1.0, 1.0, 0.5, 0.7))
			spr.texture = ImageTexture.create_from_image(img)
			spr.scale = Vector2(TILE_SIZE / 4.0, TILE_SIZE / 4.0)
			spr.position = grid_to_world(cell)
			spr.z_index = 15
			_entity_layer.add_child(spr)
			# 0.2秒後に自動削除
			var t: Tween = owner_node.create_tween()
			t.tween_property(spr, "modulate:a", 0.0, 0.2)
			t.tween_callback(spr.queue_free)
		)
		tween.tween_interval(0.03)
	return tween


## プレイヤーの攻撃アニメーション（向き方向に突進→戻る）
func animate_attack(facing: Vector2i, owner_node: Node) -> Tween:
	var origin: Vector2 = player_sprite.position
	var lunge: Vector2 = origin + Vector2(facing.x * TILE_SIZE * 0.4, facing.y * TILE_SIZE * 0.4)
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(player_sprite, "position", lunge, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(player_sprite, "position", origin, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return tween


## 敵の攻撃アニメーション（プレイヤー方向に突進→戻る）
func animate_enemy_attack(enemy: Node, player_pos: Vector2i, owner_node: Node) -> void:
	if not enemy_sprites.has(enemy):
		return
	var spr: Sprite2D = enemy_sprites[enemy]
	var origin: Vector2 = spr.position
	var dir: Vector2i = player_pos - enemy.grid_pos
	var lunge: Vector2 = origin + Vector2(dir.x * TILE_SIZE * 0.3, dir.y * TILE_SIZE * 0.3)
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(spr, "position", lunge, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(spr, "position", origin, 0.05).set_ease(Tween.EASE_IN)


## 敵撃破アニメーション（縮小→消滅）
func animate_defeat(enemy: Node, owner_node: Node) -> void:
	if not enemy_sprites.has(enemy):
		return
	var spr: Sprite2D = enemy_sprites[enemy]
	var tween: Tween = owner_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spr, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(spr, "modulate:a", 0.0, 0.25)


## プレイヤー被ダメフラッシュ
func animate_player_damage(owner_node: Node) -> void:
	var tween: Tween = owner_node.create_tween()
	tween.tween_property(player_sprite, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(player_sprite, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.05)


## Tweenアニメーションでエンティティを滑らかに移動
func animate_turn(enemies: Array, player_pos: Vector2i, camera: Camera2D, owner_node: Node) -> Tween:
	var tween: Tween = owner_node.create_tween()
	tween.set_parallel(true)

	var p_target: Vector2 = grid_to_world(player_pos)
	tween.tween_property(player_sprite, "position", p_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(camera, "position", p_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		var e_target: Vector2 = grid_to_world(enemy.grid_pos)
		var lbl_target: Vector2 = Vector2(enemy.grid_pos.x * TILE_SIZE - 12, enemy.grid_pos.y * TILE_SIZE - 14)
		if enemy_sprites.has(enemy):
			tween.tween_property(enemy_sprites[enemy], "position", e_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if enemy_labels.has(enemy):
			enemy_labels[enemy].text = str(enemy.value)
			tween.tween_property(enemy_labels[enemy], "position", lbl_target, MOVE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	return tween


func _create_enemy_sprite(enemy: Node) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex_enemy_normal
	spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	spr.z_index = 5
	_entity_layer.add_child(spr)
	enemy_sprites[enemy] = spr

	var lbl: Label = Label.new()
	lbl.text = str(enemy.value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.z_index = 20
	lbl.size = Vector2(40, 16)
	_entity_layer.add_child(lbl)
	enemy_labels[enemy] = lbl
