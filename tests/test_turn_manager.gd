class_name TestTurnManager
extends GdUnitTestSuite

# TurnManager の状態遷移とターン進行をテストする

const TMS = preload("res://scripts/systems/turn_manager.gd")

var _tm: Node


func before_test() -> void:
	_tm = TMS.new()
	add_child(_tm)


func after_test() -> void:
	if is_instance_valid(_tm):
		_tm.queue_free()


# --- 初期状態 ---

# AC-TURN-004: 初期ターンは0
func test_initial_turn_count_is_zero() -> void:
	assert_int(_tm.turn_count).is_equal(0)


# 初期フェーズは PLAYER_INPUT
func test_initial_phase_is_player_input() -> void:
	assert_int(_tm.current_phase).is_equal(TMS.Phase.PLAYER_INPUT)


# --- ターン進行 ---

# AC-TURN-001: プレイヤーアクション後にターンが1進む
func test_turn_advances_after_player_action() -> void:
	_tm.execute_player_action()
	assert_int(_tm.turn_count).is_equal(1)


# AC-TURN-001: 複数ターン進行
func test_multiple_turns_advance() -> void:
	_tm.execute_player_action()
	_tm.execute_player_action()
	_tm.execute_player_action()
	assert_int(_tm.turn_count).is_equal(3)


# AC-TURN-002: ターン消費0のアクションではターンが進まない
func test_non_consuming_action_does_not_advance_turn() -> void:
	_tm.execute_non_consuming_action()
	assert_int(_tm.turn_count).is_equal(0)
	assert_int(_tm.current_phase).is_equal(TMS.Phase.PLAYER_INPUT)


# --- フェーズ遷移 ---

# AC-TURN-003: プレイヤー→敵→環境→ターン終了の順で処理
func test_phase_order_after_player_action() -> void:
	var phases: Array[int] = []
	_tm.phase_changed.connect(func(phase: int) -> void: phases.append(phase))

	_tm.execute_player_action()

	assert_array(phases).contains_exactly([
		TMS.Phase.PLAYER_ACTION,
		TMS.Phase.ENEMY_ACTION,
		TMS.Phase.ENVIRONMENT,
		TMS.Phase.TURN_END,
		TMS.Phase.PLAYER_INPUT,
	])


# フェーズ遷移後は PLAYER_INPUT に戻る
func test_phase_returns_to_player_input_after_turn() -> void:
	_tm.execute_player_action()
	assert_int(_tm.current_phase).is_equal(TMS.Phase.PLAYER_INPUT)


# --- シグナル ---

# AC-TURN-005: turn_started シグナル
func test_turn_started_signal() -> void:
	var received: Array = []
	_tm.turn_started.connect(func(n: int) -> void: received.append(n))
	_tm.execute_player_action()
	assert_array(received).contains_exactly([1])


# AC-TURN-005: turn_ended シグナル
func test_turn_ended_signal() -> void:
	var received: Array = []
	_tm.turn_ended.connect(func(n: int) -> void: received.append(n))
	_tm.execute_player_action()
	assert_array(received).contains_exactly([1])


# AC-TURN-005: player_phase_started シグナル（ターン終了後に発火）
func test_player_phase_started_signal() -> void:
	var counter := [0]
	_tm.player_phase_started.connect(func() -> void: counter[0] += 1)
	_tm.execute_player_action()
	assert_int(counter[0]).is_equal(1)


# AC-TURN-005: enemy_phase_started シグナル
func test_enemy_phase_started_signal() -> void:
	var counter := [0]
	_tm.enemy_phase_started.connect(func() -> void: counter[0] += 1)
	_tm.execute_player_action()
	assert_int(counter[0]).is_equal(1)


# AC-TURN-005: environment_phase_started シグナル
func test_environment_phase_started_signal() -> void:
	var counter := [0]
	_tm.environment_phase_started.connect(func() -> void: counter[0] += 1)
	_tm.execute_player_action()
	assert_int(counter[0]).is_equal(1)


# --- 環境フェーズ ---

# AC-TURN-007: 10ターンごとのHP自然回復チェック
func test_hp_regen_check_every_10_turns() -> void:
	var counter := [0]
	_tm.hp_regen_triggered.connect(func() -> void: counter[0] += 1)

	for i in 20:
		_tm.execute_player_action()

	# 10ターン目と20ターン目で発火 = 2回
	assert_int(counter[0]).is_equal(2)


# 幽霊の自然回復は廃止（攻撃でのみ数値変動）
