extends RefCounted

## InGameシーンのマップ・エンティティ描画を担当する。

const MapGen = preload("res://scripts/systems/map_generator.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const TILE_SIZE: int = 16
const SPRITE_SCALE: float = 16.0 / 128.0
const MOVE_DURATION: float = 0.12
const ATLAS_TILE_SIZE: int = 128
const ATLAS_COLS: int = 8
const ATLAS_TILE_COUNT: int = 61
const TILESET_SOURCE_ID: int = 0

var tex_player_down: Texture2D
var tex_player_up: Texture2D
var tex_player_left: Texture2D
var tex_player_right: Texture2D
var tex_enemy_normal: Texture2D
var tex_enemy_ghost: Texture2D
var tex_bosses: Dictionary = {}  # stage -> Texture2D

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

func rebuild_map(grid: Array) -> void:
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
	match tile:
		MapGen.Tile.WALL: return 0
		MapGen.Tile.FLOOR: return 1
		MapGen.Tile.CORRIDOR: return 2
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


func _get_boss_texture(enemy: Node) -> Texture2D:
	for stage in EnemyScript.BOSS_DATA:
		if EnemyScript.BOSS_DATA[stage]["name"] == enemy.enemy_name:
			if tex_bosses.has(stage):
				return tex_bosses[stage]
	return tex_enemy_normal


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
