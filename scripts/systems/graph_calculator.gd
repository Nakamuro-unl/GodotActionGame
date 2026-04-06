extends RefCounted

## 範囲攻撃のグラフ座標を計算する。
## 各関数はプレイヤー位置と向きから、効果範囲のグリッド座標リストを返す。

const GRID_MAX: int = 48


## 一次関数: 向き方向にまっすぐ length マス
static func linear(origin: Vector2i, facing: Vector2i, length: int) -> Array:
	var cells: Array = []
	for i in range(1, length + 1):
		var pos: Vector2i = origin + facing * i
		if _in_bounds(pos):
			cells.append(pos)
	return cells


## 二次関数: 前方に放物線を描く
static func quadratic(origin: Vector2i, facing: Vector2i, length: int) -> Array:
	var cells: Dictionary = {}
	var right: Vector2i = _perpendicular(facing)
	for x in range(1, length + 1):
		# y = (x/2)^2 / length を整数化して左右にオフセット
		var y_offset: int = int((float(x) * float(x)) / (float(length) * 1.5))
		# 中央
		var center: Vector2i = origin + facing * x
		if _in_bounds(center):
			cells[center] = true
		# 左右の弧
		if y_offset > 0:
			var left_pos: Vector2i = center - right * y_offset
			var right_pos: Vector2i = center + right * y_offset
			if _in_bounds(left_pos):
				cells[left_pos] = true
			if _in_bounds(right_pos):
				cells[right_pos] = true
	return cells.keys()


## sin関数: 前方に波形を描く
static func sine(origin: Vector2i, facing: Vector2i, length: int, amplitude: int) -> Array:
	var cells: Dictionary = {}
	var right: Vector2i = _perpendicular(facing)
	for x in range(1, length + 1):
		var y_offset: int = int(sin(float(x) * 0.8) * float(amplitude + 1))
		var pos: Vector2i = origin + facing * x + right * y_offset
		if _in_bounds(pos):
			cells[pos] = true
	return cells.keys()


## 円: 原点中心に半径 radius の円周上のセル
static func circle(origin: Vector2i, radius: int) -> Array:
	if radius <= 0:
		return []
	var cells: Dictionary = {}
	# ブレゼンハムの円描画アルゴリズム風
	for angle in range(0, 360, 5):
		var rad: float = deg_to_rad(float(angle))
		var x: int = int(round(cos(rad) * float(radius)))
		var y: int = int(round(sin(rad) * float(radius)))
		var pos: Vector2i = Vector2i(origin.x + x, origin.y + y)
		if _in_bounds(pos) and pos != origin:
			cells[pos] = true
	return cells.keys()


## 指数関数: 向き方向に length マス（直線だがダメージが距離で変化）
static func exponential(origin: Vector2i, facing: Vector2i, length: int) -> Array:
	return linear(origin, facing, length)


## 指数関数のダメージ配列: 距離 1,2,...,length に対する 2^0, 2^1, ... 2^(n-1)
static func exponential_damage(length: int) -> Array:
	var dmg: Array = []
	for i in range(length):
		dmg.append(int(pow(2, i)))
	return dmg


# --- ヘルパー ---

static func _perpendicular(facing: Vector2i) -> Vector2i:
	## 向きに対する右方向ベクトル
	if facing == Vector2i.UP: return Vector2i.RIGHT
	if facing == Vector2i.DOWN: return Vector2i.LEFT
	if facing == Vector2i.LEFT: return Vector2i.UP
	if facing == Vector2i.RIGHT: return Vector2i.DOWN
	return Vector2i.RIGHT


static func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_MAX and pos.y >= 0 and pos.y < GRID_MAX
