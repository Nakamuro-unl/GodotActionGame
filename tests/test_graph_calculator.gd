class_name TestGraphCalculator
extends GdUnitTestSuite

# グラフ座標計算エンジンのテスト

const GC = preload("res://scripts/systems/graph_calculator.gd")


# --- 一次関数（直線） ---

# 右向き直線
func test_linear_right() -> void:
	var cells: Array = GC.linear(Vector2i(5, 5), Vector2i.RIGHT, 4)
	assert_int(cells.size()).is_equal(4)
	assert_bool(Vector2i(6, 5) in cells).is_true()
	assert_bool(Vector2i(9, 5) in cells).is_true()

# 上向き直線
func test_linear_up() -> void:
	var cells: Array = GC.linear(Vector2i(5, 5), Vector2i.UP, 4)
	assert_int(cells.size()).is_equal(4)
	assert_bool(Vector2i(5, 4) in cells).is_true()
	assert_bool(Vector2i(5, 1) in cells).is_true()

# 左向き直線
func test_linear_left() -> void:
	var cells: Array = GC.linear(Vector2i(5, 5), Vector2i.LEFT, 3)
	assert_bool(Vector2i(4, 5) in cells).is_true()
	assert_bool(Vector2i(2, 5) in cells).is_true()

# 射程0は空
func test_linear_zero_length() -> void:
	var cells: Array = GC.linear(Vector2i(5, 5), Vector2i.RIGHT, 0)
	assert_int(cells.size()).is_equal(0)


# --- 二次関数（放物線） ---

# 右向き放物線は前方+左右に広がる
func test_quadratic_right() -> void:
	var cells: Array = GC.quadratic(Vector2i(5, 5), Vector2i.RIGHT, 4)
	assert_bool(cells.size() > 4).is_true()
	# 前方にセルがある
	var has_forward: bool = false
	for c in cells:
		if c.x > 5:
			has_forward = true
			break
	assert_bool(has_forward).is_true()

# 上向き放物線
func test_quadratic_up() -> void:
	var cells: Array = GC.quadratic(Vector2i(5, 5), Vector2i.UP, 4)
	var has_forward: bool = false
	for c in cells:
		if c.y < 5:
			has_forward = true
			break
	assert_bool(has_forward).is_true()

# 原点を含まない
func test_quadratic_excludes_origin() -> void:
	var cells: Array = GC.quadratic(Vector2i(5, 5), Vector2i.RIGHT, 4)
	assert_bool(Vector2i(5, 5) in cells).is_false()


# --- sin関数（波形） ---

# 右向きsin波は前方に進みつつ上下に振れる
func test_sine_right() -> void:
	var cells: Array = GC.sine(Vector2i(5, 5), Vector2i.RIGHT, 8, 1)
	assert_bool(cells.size() > 0).is_true()
	# 上下に振れるセルがある
	var has_above: bool = false
	var has_below: bool = false
	for c in cells:
		if c.y < 5: has_above = true
		if c.y > 5: has_below = true
	assert_bool(has_above or has_below).is_true()

# 上向きsin波
func test_sine_up() -> void:
	var cells: Array = GC.sine(Vector2i(5, 5), Vector2i.UP, 6, 1)
	assert_bool(cells.size() > 0).is_true()


# --- 円 ---

# 半径2の円は原点を含まない
func test_circle_excludes_origin() -> void:
	var cells: Array = GC.circle(Vector2i(5, 5), 2)
	assert_bool(Vector2i(5, 5) in cells).is_false()

# 半径2の円は周囲のセルを含む
func test_circle_radius2() -> void:
	var cells: Array = GC.circle(Vector2i(5, 5), 2)
	assert_bool(cells.size() > 0).is_true()
	# 上下左右の距離2のセルを含む
	assert_bool(Vector2i(5, 3) in cells).is_true()
	assert_bool(Vector2i(5, 7) in cells).is_true()
	assert_bool(Vector2i(3, 5) in cells).is_true()
	assert_bool(Vector2i(7, 5) in cells).is_true()

# 半径0は空
func test_circle_zero_radius() -> void:
	var cells: Array = GC.circle(Vector2i(5, 5), 0)
	assert_int(cells.size()).is_equal(0)


# --- 指数関数 ---

# 右向き指数は前方にセルがある
func test_exponential_right() -> void:
	var cells: Array = GC.exponential(Vector2i(5, 5), Vector2i.RIGHT, 5)
	assert_int(cells.size()).is_equal(5)
	assert_bool(Vector2i(6, 5) in cells).is_true()
	assert_bool(Vector2i(10, 5) in cells).is_true()

# ダメージが距離で増加
func test_exponential_damage() -> void:
	var dmg: Array = GC.exponential_damage(5)
	assert_int(dmg[0]).is_equal(1)
	assert_int(dmg[1]).is_equal(2)
	assert_int(dmg[2]).is_equal(4)
	assert_int(dmg[3]).is_equal(8)
	assert_int(dmg[4]).is_equal(16)


# --- 共通 ---

# 重複座標がない
func test_no_duplicates() -> void:
	var cells: Array = GC.sine(Vector2i(5, 5), Vector2i.RIGHT, 8, 1)
	var unique: Dictionary = {}
	for c in cells:
		assert_bool(unique.has(c)).is_false()
		unique[c] = true

# 負の座標はクリップ
func test_clipping() -> void:
	var cells: Array = GC.linear(Vector2i(1, 1), Vector2i.LEFT, 5)
	for c in cells:
		assert_bool(c.x >= 0).is_true()
