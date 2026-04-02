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

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_name: String, p_value: int, p_attack: int, p_exp: int, p_ai: AIPattern, p_pos: Vector2i) -> void:
	enemy_name = p_name
	value = p_value
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


## 幽霊の自然回復（毎ターン+1）
func process_ghost_recovery() -> void:
	if state != EnemyState.GHOST:
		return
	value += 1
	if value == 0:
		state = EnemyState.DEFEATED
		defeated.emit()
	elif value > 0:
		state = EnemyState.NORMAL


# --- 攻撃 ---

func get_attack_damage() -> int:
	if state == EnemyState.GHOST or state == EnemyState.DEFEATED:
		return 0
	return attack_power


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
			_move_chase(player_pos, grid, occupied)
		AIPattern.SMART_CHASE:
			_move_chase(player_pos, grid, occupied)
		AIPattern.PATROL:
			_move_chase(player_pos, grid, occupied)
		AIPattern.FLEE:
			_move_flee(player_pos, grid, occupied)
		AIPattern.WARP:
			_move_warp(grid, occupied)
		AIPattern.STATIONARY:
			pass  # 動かない
		AIPattern.BOSS:
			_move_chase(player_pos, grid, occupied)

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
