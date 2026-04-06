extends Node

## 敵キャラクターのデータと行動ロジック。
## 数値を持ち、0にされると撃破。負で幽霊化。

signal defeated()
signal ghostified()
signal value_changed(old_value: int, new_value: int)

const MG = preload("res://scripts/systems/map_generator.gd")

enum EnemyState {
	NORMAL,
	GHOST,
	DEFEATED,
}

enum AIPattern {
	CHASE,         # 通常追跡
	CHARGE,        # 直線突進
	RANDOM,        # ランダム移動
	SLOW_CHASE,    # 鈍足追跡
	SMART_CHASE,   # 賢い追跡（A*）
	PATROL,        # 巡回型
	FLEE,          # 逃走型
	WARP,          # ワープ型
	STATIONARY,    # 静止型（吸引）
	BOSS,          # ボスAI
}

## ボスデータ: ステージ -> {name, value, attack, exp, theorem_id}
const BOSS_DATA: Dictionary = {
	1: {"name": "原始の王",   "value": 20,  "attack": 8,  "exp": 30,  "theorem_id": "K-104"},
	2: {"name": "スフィンクス", "value": 24,  "attack": 12, "exp": 60,  "theorem_id": "K-205"},
	3: {"name": "魔王",       "value": 49,  "attack": 18, "exp": 120, "theorem_id": "K-305"},
	4: {"name": "計算機械",   "value": 100, "attack": 22, "exp": 200, "theorem_id": "K-405"},
	5: {"name": "宇宙神",     "value": 256, "attack": 30, "exp": 500, "theorem_id": "K-504"},
}

## ステージ別数値範囲: [min, max]
const VALUE_RANGES: Dictionary = {
	1: Vector2i(1, 10),
	2: Vector2i(5, 30),
	3: Vector2i(10, 50),
	4: Vector2i(20, 100),
	5: Vector2i(50, 256),
}

var enemy_name: String = ""
var value: int = 0
var attack_power: int = 0
var exp_reward: int = 0
var ai_pattern: AIPattern = AIPattern.CHASE
var state: EnemyState = EnemyState.NORMAL
var grid_pos: Vector2i = Vector2i.ZERO
var _turn_counter: int = 0
var _initial_value: int = 0
var was_adjacent: bool = false  # 前ターンで隣接していたか（初回接触は攻撃しない）

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_name: String, p_value: int, p_attack: int, p_exp: int, p_ai: AIPattern, p_pos: Vector2i) -> void:
	enemy_name = p_name
	value = p_value
	_initial_value = p_value
	attack_power = p_attack
	exp_reward = p_exp
	ai_pattern = p_ai
	grid_pos = p_pos
	state = EnemyState.NORMAL
	_turn_counter = 0


# --- 数値操作 ---

## 数値に加算（技の効果）
func apply_value_change(delta: int) -> void:
	var old := value
	value += delta
	value_changed.emit(old, value)
	_check_state_after_value_change()


## 数値を直接セット（乗除・関数技など）
func set_value(new_value: int) -> void:
	var old := value
	value = new_value
	value_changed.emit(old, value)
	_check_state_after_value_change()


func _check_state_after_value_change() -> void:
	if state == EnemyState.DEFEATED:
		return
	if value == 0:
		state = EnemyState.DEFEATED
		defeated.emit()
	elif value < 0 and state != EnemyState.GHOST:
		state = EnemyState.GHOST
		ghostified.emit()


## 幽霊の自然回復は行わない（攻撃でのみ数値変動）
func process_ghost_recovery() -> void:
	pass


# --- 攻撃 ---

## ボスの3ターン毎特殊技の結果（GameSessionが参照）
var boss_special_text: String = ""

func get_attack_damage() -> int:
	if state == EnemyState.GHOST or state == EnemyState.DEFEATED:
		return 0
	var base: int = attack_power
	# ボス: 数値が初期値の半分以下で攻撃力1.5倍
	if ai_pattern == AIPattern.BOSS and _initial_value > 0:
		if value <= _initial_value / 2:
			base = int(attack_power * 1.5)
	# ボス: 3ターン毎に特殊技（追加ダメージ）
	if ai_pattern == AIPattern.BOSS and _turn_counter > 0 and _turn_counter % 3 == 0:
		boss_special_text = _get_boss_special_name()
		return base + attack_power / 2  # 通常の1.5倍ダメージ
	boss_special_text = ""
	return base


func _get_boss_special_name() -> String:
	match enemy_name:
		"原始の王": return "原始の咆哮!"
		"スフィンクス": return "謎かけの呪い!"
		"魔王": return "暗黒の波動!"
		"計算機械": return "電磁パルス!"
		"宇宙神": return "次元崩壊!"
	return "特殊攻撃!"


# --- 移動判定 ---

func can_walk_to(pos: Vector2i, grid: Array) -> bool:
	if pos.y < 0 or pos.y >= grid.size():
		return false
	if pos.x < 0 or pos.x >= grid[0].size():
		return false
	if state == EnemyState.GHOST:
		return true  # 幽霊は壁を通過可能
	return grid[pos.y][pos.x] != MG.Tile.WALL


# --- AI行動 ---

func decide_move(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	if state == EnemyState.DEFEATED:
		return

	# 既にプレイヤーと隣接していたら移動しない（攻撃フェーズでダメージ）
	if _is_adjacent_to(player_pos):
		_turn_counter += 1
		return

	match ai_pattern:
		AIPattern.CHASE:
			_move_chase(player_pos, grid, occupied)
		AIPattern.RANDOM:
			_move_random(player_pos, grid, occupied)
		AIPattern.SLOW_CHASE:
			_move_slow_chase(player_pos, grid, occupied)
		AIPattern.CHARGE:
			_move_charge(player_pos, grid, occupied)
		AIPattern.SMART_CHASE:
			_move_smart_chase(player_pos, grid, occupied)
		AIPattern.PATROL:
			_move_patrol(player_pos, grid, occupied)
		AIPattern.FLEE:
			_move_flee(player_pos, grid, occupied)
		AIPattern.WARP:
			_move_warp(grid, occupied)
		AIPattern.STATIONARY:
			_move_stationary(player_pos, grid, occupied)
		AIPattern.BOSS:
			_move_smart_chase(player_pos, grid, occupied)

	_turn_counter += 1


func _move_chase(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	var best_dir: Vector2i = _get_direction_toward(player_pos)
	var dirs := [best_dir, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in dirs:
		var target: Vector2i = grid_pos + dir
		if can_walk_to(target, grid) and not target in occupied and target != player_pos:
			grid_pos = target
			return


func _move_random(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	if _rng.randf() > 0.5:
		_move_chase(player_pos, grid, occupied)
	else:
		var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		dirs.shuffle()
		for dir in dirs:
			var target: Vector2i = grid_pos + dir
			if can_walk_to(target, grid) and not target in occupied and target != player_pos:
				grid_pos = target
				return


func _move_slow_chase(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	if _turn_counter % 2 == 1:
		_move_chase(player_pos, grid, occupied)


func _move_flee(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	var away: Vector2i = _get_direction_away(player_pos)
	var dirs := [away, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in dirs:
		var target: Vector2i = grid_pos + dir
		if can_walk_to(target, grid) and not target in occupied and target != player_pos:
			grid_pos = target
			return


func _move_warp(grid: Array, occupied: Array[Vector2i]) -> void:
	if _turn_counter % 3 != 0:
		return
	# ランダムな床タイルにワープ
	for attempt in 50:
		var x: int = _rng.randi_range(1, grid[0].size() - 2)
		var y: int = _rng.randi_range(1, grid.size() - 2)
		var pos: Vector2i = Vector2i(x, y)
		if grid[y][x] == MG.Tile.FLOOR and not pos in occupied:
			grid_pos = pos
			return


## 突進: プレイヤーと同じ行or列なら直線突進、それ以外は通常追跡
func _move_charge(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	var diff: Vector2i = player_pos - grid_pos
	# 同じ行 or 列にいるか
	if diff.x == 0 or diff.y == 0:
		var dir: Vector2i
		if diff.x == 0:
			dir = Vector2i(0, signi(diff.y))
		else:
			dir = Vector2i(signi(diff.x), 0)
		# 直線上に障害物がないか確認
		var check: Vector2i = grid_pos + dir
		if can_walk_to(check, grid) and not check in occupied and check != player_pos:
			grid_pos = check
			return
	_move_chase(player_pos, grid, occupied)


## A*風の賢い追跡: BFSで最短経路の最初の1歩を進む
func _move_smart_chase(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var visited: Dictionary = {}
	var parent: Dictionary = {}  # pos -> prev_pos
	var queue: Array[Vector2i] = [grid_pos]
	visited[grid_pos] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == player_pos:
			# 経路を逆追跡して最初の1歩を見つける
			var step: Vector2i = current
			while parent.has(step) and parent[step] != grid_pos:
				step = parent[step]
			if step != grid_pos and not step in occupied and step != player_pos:
				grid_pos = step
			return
		for dir in directions:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if next.x < 0 or next.x >= grid[0].size() or next.y < 0 or next.y >= grid.size():
				continue
			if next != player_pos and not can_walk_to(next, grid):
				continue
			visited[next] = true
			parent[next] = current
			queue.append(next)
	# BFS失敗時は通常追跡にフォールバック
	_move_chase(player_pos, grid, occupied)


## 巡回: プレイヤーが5タイル以内なら追跡、それ以外はランダム移動
func _move_patrol(player_pos: Vector2i, grid: Array, occupied: Array[Vector2i]) -> void:
	var dist: int = absi(player_pos.x - grid_pos.x) + absi(player_pos.y - grid_pos.y)
	if dist <= 5:
		_move_chase(player_pos, grid, occupied)
	else:
		_move_random(player_pos, grid, occupied)


## 静止+吸引: 動かないが半径3タイル内のプレイヤーに影響（シグナルで通知）
## 実際の引き寄せはGameSession側で処理する
var pull_target: Vector2i = Vector2i(-1, -1)  # 吸引先（GameSessionが参照）

func _move_stationary(player_pos: Vector2i, _grid: Array, _occupied: Array[Vector2i]) -> void:
	var dist: int = absi(player_pos.x - grid_pos.x) + absi(player_pos.y - grid_pos.y)
	if dist <= 3 and dist > 0:
		# プレイヤーを1マス引き寄せる方向を記録
		var dir: Vector2i = _get_direction_toward(player_pos)
		pull_target = player_pos - dir  # プレイヤーが1歩こちらに近づく位置
	else:
		pull_target = Vector2i(-1, -1)


func _is_adjacent_to(pos: Vector2i) -> bool:
	var diff: Vector2i = grid_pos - pos
	return (absi(diff.x) + absi(diff.y)) == 1


func _get_direction_toward(target: Vector2i) -> Vector2i:
	var diff: Vector2i = target - grid_pos
	if absi(diff.x) > absi(diff.y):
		return Vector2i(signi(diff.x), 0)
	elif diff.y != 0:
		return Vector2i(0, signi(diff.y))
	else:
		return Vector2i(signi(diff.x), 0)


func _get_direction_away(target: Vector2i) -> Vector2i:
	var toward: Vector2i = _get_direction_toward(target)
	return -toward


# --- 数値生成 ---

static func generate_value_for_stage(stage: int) -> int:
	var range_val: Vector2i = VALUE_RANGES.get(stage, VALUE_RANGES[1])
	return _rng.randi_range(range_val.x, range_val.y)
