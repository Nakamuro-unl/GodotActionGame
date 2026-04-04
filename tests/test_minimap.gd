class_name TestMinimap
extends GdUnitTestSuite

# ミニマップのテスト: 探索済み管理、マップの欠片効果

const MM = preload("res://scripts/systems/minimap_data.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _minimap: Node


func before_test() -> void:
	_minimap = MM.new()
	add_child(_minimap)


func after_test() -> void:
	if is_instance_valid(_minimap):
		_minimap.queue_free()


# --- 初期状態 ---

func test_initial_no_explored() -> void:
	_minimap.init_floor(48, 48)
	assert_bool(_minimap.is_explored(Vector2i(10, 10))).is_false()


# --- 探索 ---

# AC-UI-008: プレイヤー周辺が探索済みになる
func test_explore_around_player() -> void:
	_minimap.init_floor(48, 48)
	_minimap.explore_around(Vector2i(10, 10), 3)
	assert_bool(_minimap.is_explored(Vector2i(10, 10))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(11, 10))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(10, 11))).is_true()


# 探索範囲外はまだ未探索
func test_unexplored_outside_range() -> void:
	_minimap.init_floor(48, 48)
	_minimap.explore_around(Vector2i(10, 10), 3)
	assert_bool(_minimap.is_explored(Vector2i(20, 20))).is_false()


# 複数回の探索が蓄積される
func test_exploration_accumulates() -> void:
	_minimap.init_floor(48, 48)
	_minimap.explore_around(Vector2i(5, 5), 2)
	_minimap.explore_around(Vector2i(10, 10), 2)
	assert_bool(_minimap.is_explored(Vector2i(5, 5))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(10, 10))).is_true()


# --- マップの欠片 ---

# マップ全体を探索済みにする
func test_reveal_all() -> void:
	_minimap.init_floor(48, 48)
	_minimap.reveal_all()
	assert_bool(_minimap.is_explored(Vector2i(0, 0))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(47, 47))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(24, 24))).is_true()


# --- フロア遷移 ---

# フロア遷移でリセットされる
func test_reset_on_new_floor() -> void:
	_minimap.init_floor(48, 48)
	_minimap.explore_around(Vector2i(10, 10), 5)
	_minimap.init_floor(48, 48)
	assert_bool(_minimap.is_explored(Vector2i(10, 10))).is_false()


# --- ミニマップデータ取得 ---

# 探索済みタイルの一覧を取得
func test_get_explored_tiles() -> void:
	_minimap.init_floor(10, 10)
	_minimap.explore_around(Vector2i(5, 5), 1)
	var explored: Array = _minimap.get_explored_positions()
	assert_bool(explored.size() > 0).is_true()
	assert_bool(Vector2i(5, 5) in explored).is_true()


# 境界外は探索しない
func test_explore_clamps_to_bounds() -> void:
	_minimap.init_floor(10, 10)
	_minimap.explore_around(Vector2i(0, 0), 3)
	# エラーにならない、境界内のみ探索
	assert_bool(_minimap.is_explored(Vector2i(0, 0))).is_true()
	assert_bool(_minimap.is_explored(Vector2i(2, 2))).is_true()
