extends RefCounted

## ボスフロア専用のマップ生成。3パターンからランダム選択。

const MG = preload("res://scripts/systems/map_generator.gd")

const GRID_WIDTH: int = MG.GRID_WIDTH
const GRID_HEIGHT: int = MG.GRID_HEIGHT

enum Pattern { LINEAR, FORK, L_SHAPE }

var _rng: RandomNumberGenerator
var _rooms: Array[Rect2i] = []
var _player_start: Vector2i = Vector2i.ZERO
var _stairs_pos: Vector2i = Vector2i.ZERO
var _boss_pos: Vector2i = Vector2i.ZERO
var _chest_pos: Vector2i = Vector2i.ZERO
var _seal_pos: Vector2i = Vector2i.ZERO


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


func get_rooms() -> Array[Rect2i]:
	return _rooms


func get_player_start() -> Vector2i:
	return _player_start


func get_stairs_position() -> Vector2i:
	return _stairs_pos


func get_boss_position() -> Vector2i:
	return _boss_pos


func get_chest_position() -> Vector2i:
	return _chest_pos


func get_seal_position() -> Vector2i:
	return _seal_pos


func generate(seed_value: int) -> Array:
	_rng.seed = seed_value
	_rooms.clear()

	var grid: Array = _create_empty_grid()
	var pattern: Pattern = _rng.randi_range(0, 2) as Pattern

	match pattern:
		Pattern.LINEAR:
			_generate_linear(grid)
		Pattern.FORK:
			_generate_fork(grid)
		Pattern.L_SHAPE:
			_generate_l_shape(grid)

	return grid


func _create_empty_grid() -> Array:
	var grid: Array = []
	for y in GRID_HEIGHT:
		var row: Array[int] = []
		row.resize(GRID_WIDTH)
		row.fill(MG.Tile.WALL)
		grid.append(row)
	return grid


# --- パターンA: 一本道 ---

func _generate_linear(grid: Array) -> void:
	var start_room: Rect2i = Rect2i(4, 18, 6, 6)
	var chest_room: Rect2i = Rect2i(16, 18, 5, 5)
	var boss_room: Rect2i = Rect2i(30, 15, 10, 10)

	_carve_room(grid, start_room)
	_carve_room(grid, chest_room)
	_carve_room(grid, boss_room)
	_carve_corridor_h(grid, 10, 16, 21)
	_carve_corridor_h(grid, 21, 29, 21)  # 通路はボス部屋の手前まで

	_rooms = [start_room, chest_room, boss_room]
	_player_start = _room_center(start_room)
	_chest_pos = _room_center(chest_room)
	_boss_pos = Vector2i(boss_room.position.x + 5, boss_room.position.y + 5)
	_stairs_pos = Vector2i(boss_room.position.x + 8, boss_room.position.y + 5)
	_seal_pos = Vector2i(30, 21)  # ボス部屋入口（部屋の壁位置）


# --- パターンB: 二股 ---

func _generate_fork(grid: Array) -> void:
	var start_room: Rect2i = Rect2i(4, 19, 6, 6)
	var fork_room: Rect2i = Rect2i(16, 19, 4, 4)
	var chest_room: Rect2i = Rect2i(16, 10, 5, 5)
	var boss_room: Rect2i = Rect2i(28, 16, 10, 10)

	_carve_room(grid, start_room)
	_carve_room(grid, fork_room)
	_carve_room(grid, chest_room)
	_carve_room(grid, boss_room)
	_carve_corridor_h(grid, 10, 16, 21)  # 開始→分岐 (y=21は両部屋の範囲内)
	_carve_corridor_v(grid, 10, 19, 18)  # 分岐→宝箱 (x=18は分岐と宝箱のx範囲内)
	_carve_corridor_h(grid, 20, 27, 21)  # 分岐→ボス手前まで

	_rooms = [start_room, fork_room, chest_room, boss_room]
	_player_start = _room_center(start_room)
	_chest_pos = _room_center(chest_room)
	_boss_pos = Vector2i(boss_room.position.x + 5, boss_room.position.y + 5)
	_stairs_pos = Vector2i(boss_room.position.x + 8, boss_room.position.y + 5)
	_seal_pos = Vector2i(28, 21)  # ボス部屋入口


# --- パターンC: L字 ---

func _generate_l_shape(grid: Array) -> void:
	var start_room: Rect2i = Rect2i(4, 8, 6, 6)
	var chest_room: Rect2i = Rect2i(16, 8, 5, 5)
	var corner_room: Rect2i = Rect2i(16, 20, 4, 4)
	var boss_room: Rect2i = Rect2i(28, 17, 10, 10)

	_carve_room(grid, start_room)
	_carve_room(grid, chest_room)
	_carve_room(grid, corner_room)
	_carve_room(grid, boss_room)
	_carve_corridor_h(grid, 10, 16, 11)  # 開始→宝箱
	_carve_corridor_v(grid, 13, 20, 18)  # 宝箱→角
	_carve_corridor_h(grid, 20, 27, 22)  # 角→ボス手前まで

	_rooms = [start_room, chest_room, corner_room, boss_room]
	_player_start = _room_center(start_room)
	_chest_pos = _room_center(chest_room)
	_boss_pos = Vector2i(boss_room.position.x + 5, boss_room.position.y + 5)
	_stairs_pos = Vector2i(boss_room.position.x + 8, boss_room.position.y + 5)
	_seal_pos = Vector2i(28, 22)  # ボス部屋入口


# --- 描画ヘルパー ---

func _carve_room(grid: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
				grid[y][x] = MG.Tile.FLOOR


func _carve_corridor_h(grid: Array, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
			if grid[y][x] == MG.Tile.WALL:
				grid[y][x] = MG.Tile.CORRIDOR


func _carve_corridor_v(grid: Array, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
			if grid[y][x] == MG.Tile.WALL:
				grid[y][x] = MG.Tile.CORRIDOR


func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)
