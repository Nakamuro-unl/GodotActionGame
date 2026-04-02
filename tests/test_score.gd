class_name TestScore
extends GdUnitTestSuite

# スコアシステムのテスト: 算出、コンボ、ランキング

const SS = preload("res://scripts/systems/score_system.gd")

var _score: Node


func before_test() -> void:
	_score = SS.new()
	add_child(_score)


func after_test() -> void:
	if is_instance_valid(_score):
		_score.queue_free()


# --- 初期状態 ---

func test_initial_state() -> void:
	assert_int(_score.total_kills).is_equal(0)
	assert_int(_score.combo_count).is_equal(0)
	assert_int(_score.max_combo).is_equal(0)
	assert_int(_score.total_turns).is_equal(0)
	assert_int(_score.ghost_count).is_equal(0)
	assert_int(_score.floors_cleared).is_equal(0)
	assert_int(_score.bosses_killed).is_equal(0)
	assert_int(_score.knowledge_count).is_equal(0)


# --- 撃破スコア ---

# AC-SCR-001: 敵撃破でスコア加算
func test_register_kill() -> void:
	_score.register_kill(8)  # exp_reward = 8
	assert_int(_score.total_kills).is_equal(1)
	assert_int(_score.kill_score).is_equal(80)  # 8 * 10


# 複数撃破
func test_multiple_kills() -> void:
	_score.register_kill(2)
	_score.register_kill(4)
	_score.register_kill(8)
	assert_int(_score.total_kills).is_equal(3)
	assert_int(_score.kill_score).is_equal(140)  # (2+4+8) * 10


# ボス撃破
func test_register_boss_kill() -> void:
	_score.register_boss_kill(30)
	assert_int(_score.bosses_killed).is_equal(1)
	assert_int(_score.kill_score).is_equal(300)  # 30 * 10


# --- コンボ ---

# AC-SCR-002: ぴったり撃破でコンボ+1
func test_combo_increments_on_perfect_kill() -> void:
	_score.register_perfect_kill()
	assert_int(_score.combo_count).is_equal(1)
	_score.register_perfect_kill()
	assert_int(_score.combo_count).is_equal(2)


# AC-SCR-002: 幽霊化でコンボリセット
func test_combo_resets_on_ghost() -> void:
	_score.register_perfect_kill()
	_score.register_perfect_kill()
	_score.register_ghost()
	assert_int(_score.combo_count).is_equal(0)
	assert_int(_score.max_combo).is_equal(2)


# max_comboは最大値を記録
func test_max_combo_tracks_highest() -> void:
	_score.register_perfect_kill()
	_score.register_perfect_kill()
	_score.register_perfect_kill()
	_score.register_ghost()
	_score.register_perfect_kill()
	assert_int(_score.max_combo).is_equal(3)
	assert_int(_score.combo_count).is_equal(1)


# コンボボーナス計算: 100 * (1+2+...+n)
func test_combo_bonus_calculation() -> void:
	for i in 5:
		_score.register_perfect_kill()
	# 100 * (1+2+3+4+5) = 1500
	assert_int(_score.get_combo_bonus()).is_equal(1500)


# リセット後のコンボボーナスは現在のコンボのみ
func test_combo_bonus_after_reset() -> void:
	for i in 3:
		_score.register_perfect_kill()
	_score.register_ghost()
	_score.register_perfect_kill()
	_score.register_perfect_kill()
	# 現在コンボ2: 100 * (1+2) = 300、過去コンボ3: 100 * (1+2+3) = 600
	# 累計 = 900
	assert_int(_score.get_combo_bonus()).is_equal(900)


# --- 幽霊化ペナルティ ---

func test_ghost_penalty() -> void:
	_score.register_ghost()
	_score.register_ghost()
	assert_int(_score.ghost_count).is_equal(2)


# --- フロア・ターン ---

func test_register_floor_cleared() -> void:
	_score.register_floor_cleared()
	_score.register_floor_cleared()
	assert_int(_score.floors_cleared).is_equal(2)


func test_register_turn() -> void:
	_score.register_turn()
	_score.register_turn()
	_score.register_turn()
	assert_int(_score.total_turns).is_equal(3)


# --- 知識 ---

func test_register_knowledge() -> void:
	_score.register_knowledge()
	_score.register_knowledge()
	assert_int(_score.knowledge_count).is_equal(2)


# --- 最終スコア算出 ---

# AC-SCR-003: 全項目のスコアが正しく算出される
func test_calculate_final_score() -> void:
	# 撃破: exp=10 x2体 = 200
	_score.register_kill(10)
	_score.register_kill(10)
	# ボス: 1体 = 3000
	_score.register_boss_kill(30)
	# フロア: 5 = 2500
	for i in 5:
		_score.register_floor_cleared()
	# 知識: 3個 = 600
	for i in 3:
		_score.register_knowledge()
	# コンボ: 3連続 = 100*(1+2+3) = 600
	for i in 3:
		_score.register_perfect_kill()
	# ターン: 100 = -200
	for i in 100:
		_score.register_turn()
	# 幽霊化: 1回 = -50
	_score.register_ghost()

	var result: Dictionary = _score.calculate_final(true, 20, 8)

	assert_int(result["kill_score"]).is_equal(500)       # (10+10+30)*10
	assert_int(result["floor_score"]).is_equal(2500)     # 5*500
	assert_int(result["boss_bonus"]).is_equal(3000)      # 1*3000
	assert_int(result["knowledge_bonus"]).is_equal(600)  # 3*200
	assert_int(result["combo_bonus"]).is_equal(600)      # 100*(1+2+3)
	assert_int(result["hp_bonus"]).is_equal(1000)        # 20*50
	assert_int(result["mp_bonus"]).is_equal(240)         # 8*30
	assert_int(result["turn_penalty"]).is_equal(-200)    # -100*2
	assert_int(result["ghost_penalty"]).is_equal(-50)    # -1*50


# AC-SCR-006: スコアは0を下回らない
func test_score_minimum_zero() -> void:
	for i in 10000:
		_score.register_turn()
	var result: Dictionary = _score.calculate_final(false, 0, 0)
	assert_int(result["total"]).is_greater_equal(0)


# クリア時のみHP/MPボーナス
func test_no_hp_mp_bonus_on_game_over() -> void:
	var result: Dictionary = _score.calculate_final(false, 30, 10)
	assert_int(result["hp_bonus"]).is_equal(0)
	assert_int(result["mp_bonus"]).is_equal(0)


# --- ランキング ---

# AC-SCR-004: スコアデータを生成できる
func test_create_ranking_entry() -> void:
	_score.register_kill(10)
	for i in 5:
		_score.register_floor_cleared()
	var result: Dictionary = _score.calculate_final(true, 30, 10)
	var entry: Dictionary = _score.create_ranking_entry(result, 12345, true)
	assert_int(entry["score"]).is_equal(result["total"])
	assert_int(entry["floor_reached"]).is_equal(5)
	assert_int(entry["enemies_defeated"]).is_equal(1)
	assert_int(entry["seed"]).is_equal(12345)
	assert_bool(entry["cleared"]).is_true()


# AC-SCR-005: ランキングに追加・ソートできる
func test_ranking_sorted_by_score() -> void:
	var ranking: Array = []
	_score.add_to_ranking(ranking, {"score": 100, "date": "a"})
	_score.add_to_ranking(ranking, {"score": 300, "date": "b"})
	_score.add_to_ranking(ranking, {"score": 200, "date": "c"})
	assert_int(ranking[0]["score"]).is_equal(300)
	assert_int(ranking[1]["score"]).is_equal(200)
	assert_int(ranking[2]["score"]).is_equal(100)


# AC-SCR-005: ランキングは最大10件
func test_ranking_max_10() -> void:
	var ranking: Array = []
	for i in 12:
		_score.add_to_ranking(ranking, {"score": i * 10, "date": str(i)})
	assert_int(ranking.size()).is_equal(10)
	# 最高スコアが先頭
	assert_int(ranking[0]["score"]).is_equal(110)
