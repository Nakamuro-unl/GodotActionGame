class_name TestMapGenerator
extends GdUnitTestSuite

# マップ生成（BSP法）のテスト

const MG = preload("res://scripts/systems/map_generator.gd")

var _gen: Node


func before_test() -> void:
	_gen = MG.new()
	add_child(_gen)


func after_test() -> void:
	if is_instance_valid(_gen):
		_gen.queue_free()


# --- 基本生成 ---

# AC-MAP-001: フロアが生成されること
func test_generate_floor_returns_grid() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	assert_bool(grid.size() > 0).is_true()


# グリッドサイズが正しいこと（48x48）
func test_grid_size_is_correct() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	assert_int(grid.size()).is_equal(MG.GRID_HEIGHT)
	assert_int(grid[0].size()).is_equal(MG.GRID_WIDTH)


# 初期状態で外周が全て壁であること
func test_grid_border_is_wall() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	for x in MG.GRID_WIDTH:
		assert_int(grid[0][x]).is_equal(MG.Tile.WALL)
		assert_int(grid[MG.GRID_HEIGHT - 1][x]).is_equal(MG.Tile.WALL)
	for y in MG.GRID_HEIGHT:
		assert_int(grid[y][0]).is_equal(MG.Tile.WALL)
		assert_int(grid[y][MG.GRID_WIDTH - 1]).is_equal(MG.Tile.WALL)


# --- 部屋生成 ---

# AC-MAP-001: 部屋が生成されていること（床タイルが存在する）
func test_floor_has_rooms() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var floor_count: int = 0
	for y in MG.GRID_HEIGHT:
		for x in MG.GRID_WIDTH:
			if grid[y][x] == MG.Tile.FLOOR:
				floor_count += 1
	assert_int(floor_count).is_greater(0)


# 部屋数がステージパラメータの範囲内であること
func test_room_count_within_range() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var rooms: Array = _gen.get_rooms()
	# ステージ1: 4-6部屋
	assert_int(rooms.size()).is_greater_equal(4)
	assert_int(rooms.size()).is_less_equal(6)


# 部屋のサイズが最小値以上であること
func test_room_size_minimum() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var rooms: Array = _gen.get_rooms()
	for room in rooms:
		assert_int(room.size.x).is_greater_equal(MG.ROOM_MIN_SIZE)
		assert_int(room.size.y).is_greater_equal(MG.ROOM_MIN_SIZE)


# 部屋のサイズが最大値以下であること
func test_room_size_maximum() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var rooms: Array = _gen.get_rooms()
	for room in rooms:
		assert_int(room.size.x).is_less_equal(MG.ROOM_MAX_SIZE)
		assert_int(room.size.y).is_less_equal(MG.ROOM_MAX_SIZE)


# --- 通路・接続性 ---

# AC-MAP-002: 全ての部屋が到達可能であること
func test_all_rooms_reachable() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var rooms: Array = _gen.get_rooms()
	assert_bool(_gen.are_all_rooms_reachable(grid, rooms)).is_true()


# 通路タイルが存在すること
func test_corridors_exist() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var corridor_count: int = 0
	for y in MG.GRID_HEIGHT:
		for x in MG.GRID_WIDTH:
			if grid[y][x] == MG.Tile.CORRIDOR:
				corridor_count += 1
	assert_int(corridor_count).is_greater(0)


# --- オブジェクト配置 ---

# AC-MAP-003: 階段が1つ配置されること
func test_stairs_placed() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var stair_count: int = 0
	for y in MG.GRID_HEIGHT:
		for x in MG.GRID_WIDTH:
			if grid[y][x] == MG.Tile.STAIRS:
				stair_count += 1
	assert_int(stair_count).is_equal(1)


# AC-MAP-008: プレイヤー開始位置と階段が異なる部屋にあること
func test_player_start_and_stairs_in_different_rooms() -> void:
	var grid: Array = _gen.generate_floor(1, 1)
	var start_pos: Vector2i = _gen.get_player_start()
	var stairs_pos: Vector2i = _gen.get_stairs_position()
	# 同じ座標でないことを確認
	assert_bool(start_pos != stairs_pos).is_true()
	# 異なる部屋にあることを確認
	var start_room: int = _gen.get_room_index_at(start_pos)
	var stairs_room: int = _gen.get_room_index_at(stairs_pos)
	assert_int(start_room).is_not_equal(stairs_room)


# --- シード値 ---

# AC-MAP-007: 同じシードで同じマップが生成されること
func test_same_seed_generates_same_map() -> void:
	var grid1: Array = _gen.generate_floor(1, 12345)
	var rooms1: Array = _gen.get_rooms().duplicate(true)
	var grid2: Array = _gen.generate_floor(1, 12345)
	var rooms2: Array = _gen.get_rooms().duplicate(true)
	# グリッドが一致
	for y in MG.GRID_HEIGHT:
		for x in MG.GRID_WIDTH:
			assert_int(grid1[y][x]).is_equal(grid2[y][x])


# 異なるシードで異なるマップが生成されること
func test_different_seed_generates_different_map() -> void:
	var grid1: Array = _gen.generate_floor(1, 11111)
	var rooms1: Array = _gen.get_rooms().duplicate(true)
	var grid2: Array = _gen.generate_floor(1, 99999)
	var rooms2: Array = _gen.get_rooms().duplicate(true)
	# 少なくとも部屋配置が異なる（部屋数 or 位置）
	var different := false
	if rooms1.size() != rooms2.size():
		different = true
	else:
		for i in rooms1.size():
			if rooms1[i].position != rooms2[i].position:
				different = true
				break
	assert_bool(different).is_true()


# --- ステージ別パラメータ ---

# AC-MAP-005: ステージ2は部屋数5-7
func test_stage2_room_count() -> void:
	var grid: Array = _gen.generate_floor(2, 1)
	var rooms: Array = _gen.get_rooms()
	assert_int(rooms.size()).is_greater_equal(5)
	assert_int(rooms.size()).is_less_equal(7)


# AC-MAP-005: ステージ5は部屋数6-9
func test_stage5_room_count() -> void:
	var grid: Array = _gen.generate_floor(5, 1)
	var rooms: Array = _gen.get_rooms()
	assert_int(rooms.size()).is_greater_equal(6)
	assert_int(rooms.size()).is_less_equal(9)
