extends Node

## BSP法によるダンジョンマップ生成。
## 部屋+通路型のランダムマップを生成する。

enum Tile {
	WALL = 0,
	FLOOR = 1,
	CORRIDOR = 2,
	STAIRS = 3,
	CHEST = 4,
	TRAP = 5,
}

const GRID_WIDTH: int = 48
const GRID_HEIGHT: int = 48
const ROOM_MIN_SIZE: int = 4
const ROOM_MAX_SIZE: int = 10
const BSP_MIN_LEAF: int = 12

## ステージ別パラメータ: [min_rooms, max_rooms]
const STAGE_PARAMS: Dictionary = {
	1: {"rooms": Vector2i(4, 6)},
	2: {"rooms": Vector2i(5, 7)},
	3: {"rooms": Vector2i(5, 8)},
	4: {"rooms": Vector2i(6, 9)},
	5: {"rooms": Vector2i(6, 9)},
}

var _rooms: Array[Rect2i] = []
var _player_start: Vector2i = Vector2i.ZERO
var _stairs_pos: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_rooms() -> Array[Rect2i]:
	return _rooms


func get_player_start() -> Vector2i:
	return _player_start


func get_stairs_position() -> Vector2i:
	return _stairs_pos


## 指定座標がどの部屋に属するかを返す（-1 = どの部屋にも属さない）
func get_room_index_at(pos: Vector2i) -> int:
	for i in _rooms.size():
		if _rooms[i].has_point(pos):
			return i
	return -1


## フロアを生成する
## stage: ステージ番号（1-5）
## seed_value: シード値
func generate_floor(stage: int, seed_value: int) -> Array:
	_rng.seed = seed_value
	_rooms.clear()

	var params: Dictionary = STAGE_PARAMS.get(stage, STAGE_PARAMS[1])
	var target_rooms: Vector2i = params["rooms"]

	# グリッド初期化（全て壁）
	var grid: Array = _create_empty_grid()

	# BSPで領域分割
	var leaves: Array[Rect2i] = []
	_bsp_split(Rect2i(1, 1, GRID_WIDTH - 2, GRID_HEIGHT - 2), leaves)

	# 各リーフに部屋を配置
	for leaf in leaves:
		var room := _create_room_in_leaf(leaf)
		if room.size.x >= ROOM_MIN_SIZE and room.size.y >= ROOM_MIN_SIZE:
			_rooms.append(room)

	# 部屋数をターゲット範囲に調整
	_adjust_room_count(target_rooms)

	# 部屋をグリッドに描画
	for room in _rooms:
		_carve_room(grid, room)

	# 通路を生成
	for i in _rooms.size() - 1:
		_carve_corridor(grid, _rooms[i], _rooms[i + 1])

	# 到達可能性を保証（追加の通路）
	_ensure_connectivity(grid)

	# プレイヤー開始位置（最初の部屋の中央）
	_player_start = _get_room_center(_rooms[0])

	# 階段配置（開始位置から最も遠い部屋）
	var farthest_idx: int = _find_farthest_room(_player_start)
	_stairs_pos = _get_room_center(_rooms[farthest_idx])
	grid[_stairs_pos.y][_stairs_pos.x] = Tile.STAIRS

	return grid


## 全ての部屋が到達可能かチェック（BFS）
func are_all_rooms_reachable(grid: Array, rooms: Array) -> bool:
	if rooms.is_empty():
		return false

	var start: Vector2i = _get_room_center(rooms[0])
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true

	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in directions:
			var next: Vector2i = current + dir
			if next.x < 0 or next.x >= GRID_WIDTH or next.y < 0 or next.y >= GRID_HEIGHT:
				continue
			if visited.has(next):
				continue
			if grid[next.y][next.x] == Tile.WALL:
				continue
			visited[next] = true
			queue.append(next)

	# 全部屋の中央が到達可能か確認
	for room in rooms:
		var center: Vector2i = _get_room_center(room)
		if not visited.has(center):
			return false
	return true


# --- Private ---

func _create_empty_grid() -> Array:
	var grid: Array = []
	for y in GRID_HEIGHT:
		var row: Array[int] = []
		row.resize(GRID_WIDTH)
		row.fill(Tile.WALL)
		grid.append(row)
	return grid


func _bsp_split(area: Rect2i, leaves: Array[Rect2i]) -> void:
	if area.size.x < BSP_MIN_LEAF * 2 and area.size.y < BSP_MIN_LEAF * 2:
		leaves.append(area)
		return

	var split_h: bool
	if area.size.x < BSP_MIN_LEAF * 2:
		split_h = true
	elif area.size.y < BSP_MIN_LEAF * 2:
		split_h = false
	else:
		split_h = _rng.randf() > 0.5

	if split_h:
		if area.size.y < BSP_MIN_LEAF * 2:
			leaves.append(area)
			return
		var split_y: int = _rng.randi_range(area.position.y + BSP_MIN_LEAF, area.position.y + area.size.y - BSP_MIN_LEAF)
		_bsp_split(Rect2i(area.position.x, area.position.y, area.size.x, split_y - area.position.y), leaves)
		_bsp_split(Rect2i(area.position.x, split_y, area.size.x, area.position.y + area.size.y - split_y), leaves)
	else:
		if area.size.x < BSP_MIN_LEAF * 2:
			leaves.append(area)
			return
		var split_x: int = _rng.randi_range(area.position.x + BSP_MIN_LEAF, area.position.x + area.size.x - BSP_MIN_LEAF)
		_bsp_split(Rect2i(area.position.x, area.position.y, split_x - area.position.x, area.size.y), leaves)
		_bsp_split(Rect2i(split_x, area.position.y, area.position.x + area.size.x - split_x, area.size.y), leaves)


func _create_room_in_leaf(leaf: Rect2i) -> Rect2i:
	var max_w: int = mini(leaf.size.x - 2, ROOM_MAX_SIZE)
	var max_h: int = mini(leaf.size.y - 2, ROOM_MAX_SIZE)
	if max_w < ROOM_MIN_SIZE or max_h < ROOM_MIN_SIZE:
		return Rect2i(0, 0, 0, 0)

	var w: int = _rng.randi_range(ROOM_MIN_SIZE, max_w)
	var h: int = _rng.randi_range(ROOM_MIN_SIZE, max_h)
	var x: int = _rng.randi_range(leaf.position.x + 1, leaf.position.x + leaf.size.x - w - 1)
	var y: int = _rng.randi_range(leaf.position.y + 1, leaf.position.y + leaf.size.y - h - 1)

	return Rect2i(x, y, w, h)


func _adjust_room_count(target: Vector2i) -> void:
	# 部屋が多すぎる場合は末尾から削除
	while _rooms.size() > target.y:
		_rooms.pop_back()
	# 少なすぎる場合はそのまま（BSPの制約上、最低限は生成される）


func _carve_room(grid: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
				grid[y][x] = Tile.FLOOR


func _carve_corridor(grid: Array, room_a: Rect2i, room_b: Rect2i) -> void:
	var a: Vector2i = _get_room_center(room_a)
	var b: Vector2i = _get_room_center(room_b)

	# L字型の通路（先に水平、次に垂直）
	if _rng.randf() > 0.5:
		_carve_h_corridor(grid, a.x, b.x, a.y)
		_carve_v_corridor(grid, a.y, b.y, b.x)
	else:
		_carve_v_corridor(grid, a.y, b.y, a.x)
		_carve_h_corridor(grid, a.x, b.x, b.y)


func _carve_h_corridor(grid: Array, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
			if grid[y][x] == Tile.WALL:
				grid[y][x] = Tile.CORRIDOR


func _carve_v_corridor(grid: Array, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		if y > 0 and y < GRID_HEIGHT - 1 and x > 0 and x < GRID_WIDTH - 1:
			if grid[y][x] == Tile.WALL:
				grid[y][x] = Tile.CORRIDOR


func _ensure_connectivity(grid: Array) -> void:
	# 到達不能な部屋があれば前の部屋と通路を追加
	for i in range(1, _rooms.size()):
		if not _is_reachable_from(grid, _rooms[0], _rooms[i]):
			_carve_corridor(grid, _rooms[i - 1], _rooms[i])


func _is_reachable_from(grid: Array, from_room: Rect2i, to_room: Rect2i) -> bool:
	var start: Vector2i = _get_room_center(from_room)
	var goal: Vector2i = _get_room_center(to_room)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			return true
		for dir in directions:
			var next: Vector2i = current + dir
			if next.x < 0 or next.x >= GRID_WIDTH or next.y < 0 or next.y >= GRID_HEIGHT:
				continue
			if visited.has(next):
				continue
			if grid[next.y][next.x] == Tile.WALL:
				continue
			visited[next] = true
			queue.append(next)
	return false


func _get_room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)


func _find_farthest_room(from: Vector2i) -> int:
	var max_dist: int = -1
	var farthest: int = 0
	for i in _rooms.size():
		var center: Vector2i = _get_room_center(_rooms[i])
		var dist: int = absi(center.x - from.x) + absi(center.y - from.y)
		if dist > max_dist:
			max_dist = dist
			farthest = i
	return farthest
