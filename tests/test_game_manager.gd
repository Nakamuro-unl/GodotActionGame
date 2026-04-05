class_name TestGameManager
extends GdUnitTestSuite

# GameManager の状態遷移をテストする

const GMS = preload("res://scripts/autoload/game_manager.gd")

var _manager: Node


func before_test() -> void:
	_manager = GMS.new()
	add_child(_manager)


func after_test() -> void:
	_manager.queue_free()


# AC-FLOW-001: 起動時の初期状態がSPLASHであること
func test_initial_state_is_splash() -> void:
	assert_int(_manager.current_state).is_equal(GMS.State.SPLASH)


# SPLASH → TITLE に遷移できること
func test_change_state_splash_to_title() -> void:
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.TITLE)


# AC-FLOW-002: TITLE → INGAME に遷移できること
func test_change_state_title_to_ingame() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	assert_int(_manager.current_state).is_equal(GMS.State.INGAME)


# AC-FLOW-003: INGAME → RESULT に遷移できること
func test_change_state_ingame_to_result() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	_manager.change_state(GMS.State.RESULT)
	assert_int(_manager.current_state).is_equal(GMS.State.RESULT)


# AC-FLOW-004: RESULT → TITLE に遷移できること
func test_change_state_result_to_title() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	_manager.change_state(GMS.State.RESULT)
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.TITLE)


# AC-FLOW-005: TITLE → RANKING に遷移できること
func test_change_state_title_to_ranking() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.RANKING)
	assert_int(_manager.current_state).is_equal(GMS.State.RANKING)


# AC-FLOW-005: TITLE → HOWTOPLAY に遷移できること
func test_change_state_title_to_howtoplay() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.HOWTOPLAY)
	assert_int(_manager.current_state).is_equal(GMS.State.HOWTOPLAY)


# AC-FLOW-005: TITLE → SETTINGS に遷移できること
func test_change_state_title_to_settings() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.SETTINGS)
	assert_int(_manager.current_state).is_equal(GMS.State.SETTINGS)


# AC-FLOW-005: RANKING → TITLE に遷移できること
func test_change_state_ranking_to_title() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.RANKING)
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.TITLE)


# 不正な遷移: INGAME から直接 TITLE には戻れない
func test_invalid_transition_ingame_to_title() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.INGAME)


# 不正な遷移: RESULT から INGAME には戻れない
func test_invalid_transition_result_to_ingame() -> void:
	_manager.change_state(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	_manager.change_state(GMS.State.RESULT)
	_manager.change_state(GMS.State.INGAME)
	assert_int(_manager.current_state).is_equal(GMS.State.RESULT)


# state_changed シグナルが発火すること
func test_state_changed_signal_emitted() -> void:
	var received: Array = []
	_manager.state_changed.connect(func(old_s: int, new_s: int) -> void: received.append([old_s, new_s]))
	_manager.change_state(GMS.State.TITLE)
	assert_array(received).contains_exactly([[GMS.State.SPLASH, GMS.State.TITLE]])


# メインフロー全体: SPLASH → TITLE → INGAME → RESULT → TITLE
func test_full_main_flow() -> void:
	assert_int(_manager.current_state).is_equal(GMS.State.SPLASH)
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.TITLE)
	_manager.change_state(GMS.State.INGAME)
	assert_int(_manager.current_state).is_equal(GMS.State.INGAME)
	_manager.change_state(GMS.State.RESULT)
	assert_int(_manager.current_state).is_equal(GMS.State.RESULT)
	_manager.change_state(GMS.State.TITLE)
	assert_int(_manager.current_state).is_equal(GMS.State.TITLE)
