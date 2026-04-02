class_name TestGimmick
extends GdUnitTestSuite

# フィールドギミックのテスト

const GK = preload("res://scripts/systems/gimmick_system.gd")
const KS = preload("res://scripts/systems/knowledge_system.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _gimmick: Node
var _knowledge: Node
var _grid: Array


func before_test() -> void:
	_gimmick = GK.new()
	_knowledge = KS.new()
	add_child(_gimmick)
	add_child(_knowledge)
	_grid = _create_test_grid()


func after_test() -> void:
	for node in [_gimmick, _knowledge]:
		if is_instance_valid(node):
			node.queue_free()


# --- ギミック配置 ---

# AC-GIM-001: ギミックタイルを配置できる
func test_place_gimmick() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.VOID_WALL, "K-104")
	assert_bool(_gimmick.has_gimmick_at(Vector2i(5, 3))).is_true()


# 配置されていない場所にはギミックがない
func test_no_gimmick_at_empty() -> void:
	assert_bool(_gimmick.has_gimmick_at(Vector2i(5, 5))).is_false()


# AC-GIM-006: ギミック情報を取得できる
func test_get_gimmick_info() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.ICE_WALL, "K-105")
	var info: Dictionary = _gimmick.get_gimmick_at(Vector2i(5, 3))
	assert_int(info["type"]).is_equal(GK.GimmickType.ICE_WALL)
	assert_str(info["required_knowledge"]).is_equal("K-105")


# --- ギミック解除 ---

# AC-GIM-002: 対応知識があれば解除できる
func test_resolve_with_knowledge() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.VOID_WALL, "K-104")
	_knowledge.acquire("K-104")
	var result: Dictionary = _gimmick.try_resolve(Vector2i(5, 3), _knowledge, _grid)
	assert_bool(result["success"]).is_true()
	assert_str(result["message"]).is_not_empty()


# AC-GIM-003: 知識がなければ解除できない
func test_resolve_without_knowledge_fails() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.VOID_WALL, "K-104")
	var result: Dictionary = _gimmick.try_resolve(Vector2i(5, 3), _knowledge, _grid)
	assert_bool(result["success"]).is_false()
	assert_str(result["message"]).contains("理解できない")


# AC-GIM-004: 解除後にギミックが消える
func test_gimmick_removed_after_resolve() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.VOID_WALL, "K-104")
	_knowledge.acquire("K-104")
	_gimmick.try_resolve(Vector2i(5, 3), _knowledge, _grid)
	assert_bool(_gimmick.has_gimmick_at(Vector2i(5, 3))).is_false()


# AC-GIM-004: 解除後にグリッドが床に変化
func test_grid_becomes_floor_after_resolve() -> void:
	_grid[3][5] = MG.Tile.WALL
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.VOID_WALL, "K-104")
	_knowledge.acquire("K-104")
	_gimmick.try_resolve(Vector2i(5, 3), _knowledge, _grid)
	assert_int(_grid[3][5]).is_equal(MG.Tile.FLOOR)


# ギミックがない場所を解除しようとしても何もしない
func test_resolve_empty_does_nothing() -> void:
	var result: Dictionary = _gimmick.try_resolve(Vector2i(5, 5), _knowledge, _grid)
	assert_bool(result["success"]).is_false()


# --- 解除シグナル ---

func test_resolve_emits_signal() -> void:
	_gimmick.place_gimmick(Vector2i(5, 3), GK.GimmickType.ICE_WALL, "K-105")
	_knowledge.acquire("K-105")
	var received: Array = []
	_gimmick.gimmick_resolved.connect(func(pos: Vector2i, type: int) -> void: received.append([pos, type]))
	_gimmick.try_resolve(Vector2i(5, 3), _knowledge, _grid)
	assert_array(received).contains_exactly([[Vector2i(5, 3), GK.GimmickType.ICE_WALL]])


# --- ステージ別ギミック取得 ---

func test_get_gimmicks_for_stage1() -> void:
	var types: Array = GK.get_gimmick_types_for_stage(1)
	assert_bool(GK.GimmickType.VOID_WALL in types).is_true()
	assert_bool(GK.GimmickType.ICE_WALL in types).is_true()
	assert_bool(GK.GimmickType.LOCKED_DOOR in types).is_false()


func test_get_gimmicks_for_stage3() -> void:
	var types: Array = GK.get_gimmick_types_for_stage(3)
	assert_bool(GK.GimmickType.LOCKED_DOOR in types).is_true()
	assert_bool(GK.GimmickType.GRAVITY_SW in types).is_true()


func test_get_gimmicks_for_stage5() -> void:
	var types: Array = GK.get_gimmick_types_for_stage(5)
	assert_bool(GK.GimmickType.FINAL_DOOR in types).is_true()


# --- ヘルパー ---

func _create_test_grid() -> Array:
	var grid: Array = []
	for y in 10:
		var row: Array[int] = []
		for x in 10:
			if x == 0 or x == 9 or y == 0 or y == 9:
				row.append(MG.Tile.WALL)
			else:
				row.append(MG.Tile.FLOOR)
		grid.append(row)
	return grid
