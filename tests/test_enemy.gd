class_name TestEnemy
extends GdUnitTestSuite

# 敵キャラクターの属性・AI・幽霊化をテストする

const ES = preload("res://scripts/entities/enemy.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _enemy: Node
var _grid: Array


func before_test() -> void:
	_enemy = ES.new()
	add_child(_enemy)
	_grid = _create_test_grid()


func after_test() -> void:
	if is_instance_valid(_enemy):
		_enemy.queue_free()


# --- 初期化 ---

# AC-ENM-001: 数値を持って初期化される
func test_setup_with_value() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	assert_int(_enemy.value).is_equal(5)
	assert_str(_enemy.enemy_name).is_equal("子狼")
	assert_int(_enemy.attack_power).is_equal(2)
	assert_int(_enemy.exp_reward).is_equal(2)


# 初期状態は通常
func test_initial_state_is_normal() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	assert_int(_enemy.state).is_equal(ES.EnemyState.NORMAL)


# グリッド位置が設定される
func test_initial_position() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	assert_int(_enemy.grid_pos.x).is_equal(3)
	assert_int(_enemy.grid_pos.y).is_equal(3)


# --- 数値操作 ---

# AC-CMB-002: 数値に加算できる
func test_apply_value_add() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(3)
	assert_int(_enemy.value).is_equal(8)


# AC-CMB-002: 数値に減算できる
func test_apply_value_subtract() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-3)
	assert_int(_enemy.value).is_equal(2)


# AC-CMB-003: 数値が0になると撃破
func test_defeated_when_value_zero() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	var counter := [0]
	_enemy.defeated.connect(func() -> void: counter[0] += 1)
	_enemy.apply_value_change(-5)
	assert_int(_enemy.value).is_equal(0)
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)
	assert_int(counter[0]).is_equal(1)


# AC-CMB-004: 数値が負になると幽霊化
func test_ghost_when_value_negative() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	var counter := [0]
	_enemy.ghostified.connect(func() -> void: counter[0] += 1)
	_enemy.apply_value_change(-5)
	assert_int(_enemy.value).is_equal(-2)
	assert_int(_enemy.state).is_equal(ES.EnemyState.GHOST)
	assert_int(counter[0]).is_equal(1)


# AC-ENM-005: 幽霊は毎ターン数値+1
func test_ghost_recovery() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-5)  # value = -2, ghost
	_enemy.process_ghost_recovery()
	assert_int(_enemy.value).is_equal(-1)


# 幽霊が回復して0になったら撃破
func test_ghost_recovery_to_zero_defeats() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-4)  # value = -1, ghost
	var counter := [0]
	_enemy.defeated.connect(func() -> void: counter[0] += 1)
	_enemy.process_ghost_recovery()  # value = 0
	assert_int(_enemy.value).is_equal(0)
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)
	assert_int(counter[0]).is_equal(1)


# 幽霊が回復して正になったら通常に戻る
func test_ghost_recovery_to_positive_restores() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-3)  # value = 0 → defeated
	# 別のケース: value = -1 からスタート
	_enemy.setup("子狼", 1, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-2)  # value = -1, ghost
	_enemy.process_ghost_recovery()  # value = 0 → defeated
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)


# 通常状態では回復処理は何もしない
func test_ghost_recovery_does_nothing_for_normal() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.process_ghost_recovery()
	assert_int(_enemy.value).is_equal(5)


# 数値を直接セットできる（乗除技など）
func test_set_value() -> void:
	_enemy.setup("子狼", 12, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.set_value(6)
	assert_int(_enemy.value).is_equal(6)


# set_valueで0にすると撃破
func test_set_value_zero_defeats() -> void:
	_enemy.setup("子狼", 12, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	var counter := [0]
	_enemy.defeated.connect(func() -> void: counter[0] += 1)
	_enemy.set_value(0)
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)
	assert_int(counter[0]).is_equal(1)


# --- AI移動 ---

# AC-ENM-002: 通常追跡 - プレイヤーに近づく
func test_chase_moves_toward_player() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(5, 5))
	var player_pos := Vector2i(5, 2)
	var occupied: Array[Vector2i] = []
	_enemy.decide_move(player_pos, _grid, occupied)
	# 上に移動（プレイヤーに近づく）
	assert_int(_enemy.grid_pos.y).is_less(5)


# AC-ENM-002: ランダム移動は移動するか留まる
func test_random_move_changes_or_stays() -> void:
	_enemy.setup("砂蛇", 8, 5, 8, ES.AIPattern.RANDOM, Vector2i(5, 5))
	var player_pos := Vector2i(5, 2)
	var occupied: Array[Vector2i] = []
	var original: Vector2i = _enemy.grid_pos
	# 複数回試行して少なくとも1回は移動する
	var moved := false
	for i in 20:
		_enemy.setup("砂蛇", 8, 5, 8, ES.AIPattern.RANDOM, Vector2i(5, 5))
		_enemy.decide_move(player_pos, _grid, occupied)
		if _enemy.grid_pos != original:
			moved = true
			break
	assert_bool(moved).is_true()


# AC-ENM-002: 鈍足追跡 - 2ターンに1回行動
func test_slow_chase_moves_every_other_turn() -> void:
	_enemy.setup("ゴーレム", 20, 10, 18, ES.AIPattern.SLOW_CHASE, Vector2i(5, 5))
	var player_pos := Vector2i(5, 2)
	var occupied: Array[Vector2i] = []
	# ターン1: 動かない
	_enemy.decide_move(player_pos, _grid, occupied)
	var pos_after_1: Vector2i = _enemy.grid_pos
	# ターン2: 動く
	_enemy.decide_move(player_pos, _grid, occupied)
	var pos_after_2: Vector2i = _enemy.grid_pos
	assert_bool(pos_after_1 == Vector2i(5, 5)).is_true()
	assert_bool(pos_after_2 != Vector2i(5, 5)).is_true()


# AC-ENM-004: 幽霊は壁を通過できる
func test_ghost_can_move_through_walls() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(1, 5))
	_enemy.apply_value_change(-5)  # ghost化
	var player_pos := Vector2i(0, 5)  # 壁の向こう
	var occupied: Array[Vector2i] = []
	# 幽霊なので壁(x=0)方向に進める
	var can_walk: bool = _enemy.can_walk_to(Vector2i(0, 5), _grid)
	assert_bool(can_walk).is_true()


# 通常状態では壁を通過できない
func test_normal_cannot_move_through_walls() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(1, 5))
	var can_walk: bool = _enemy.can_walk_to(Vector2i(0, 5), _grid)
	assert_bool(can_walk).is_false()


# AC-ENM-003: 隣接時にダメージ値を返す
func test_get_attack_damage() -> void:
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	assert_int(_enemy.get_attack_damage()).is_equal(2)


# 幽霊状態ではダメージ0
func test_ghost_deals_no_damage() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(3, 3))
	_enemy.apply_value_change(-5)
	assert_int(_enemy.get_attack_damage()).is_equal(0)


# --- 数値設定ルール ---

# AC-ENM-008: ステージ範囲内で数値生成
func test_generate_value_for_stage1() -> void:
	for i in 20:
		var val: int = ES.generate_value_for_stage(1)
		assert_int(val).is_greater_equal(1)
		assert_int(val).is_less_equal(10)


func test_generate_value_for_stage3() -> void:
	for i in 20:
		var val: int = ES.generate_value_for_stage(3)
		assert_int(val).is_greater_equal(10)
		assert_int(val).is_less_equal(50)


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
