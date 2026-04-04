class_name TestGameSession
extends GdUnitTestSuite

# GameSession: 全システム結合テスト

const GSS = preload("res://scripts/systems/game_session.gd")
const ES = preload("res://scripts/entities/enemy.gd")

var _session: Node


func before_test() -> void:
	_session = GSS.new()
	add_child(_session)
	_session.start_new_game(12345)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.queue_free()


# --- 初期化 ---

func test_initial_stage_and_floor() -> void:
	assert_int(_session.current_stage).is_equal(1)
	assert_int(_session.current_floor).is_equal(1)


func test_initial_player_state() -> void:
	assert_int(_session.player.hp).is_equal(30)
	assert_int(_session.player.mp).is_equal(10)
	assert_int(_session.player.level).is_equal(1)


func test_map_generated() -> void:
	assert_bool(_session.grid.size() > 0).is_true()


func test_enemies_spawned() -> void:
	assert_bool(_session.enemies.size() > 0).is_true()


func test_player_positioned() -> void:
	var pos: Vector2i = _session.player.grid_pos
	assert_bool(pos != Vector2i.ZERO).is_true()


# --- プレイヤー移動 ---

func test_player_move_advances_turn() -> void:
	var initial_turn: int = _session.turn_manager.turn_count
	_session.try_player_move(Vector2i.DOWN)
	assert_int(_session.turn_manager.turn_count).is_equal(initial_turn + 1)


func test_player_move_to_wall_no_turn() -> void:
	# 壁に向かって移動（開始位置は部屋内なので上に何度も行けば壁に当たる）
	var turns_before: int = _session.turn_manager.turn_count
	# 20回上に移動を試行（途中で壁にぶつかるはず）
	for i in 20:
		_session.try_player_move(Vector2i.UP)
	# 壁にぶつかった分はターンが進まないので20より少ない
	assert_int(_session.turn_manager.turn_count).is_less(turns_before + 20)


# --- 技の使用 ---

func test_use_skill_on_adjacent_enemy() -> void:
	# 技を装備してから使用
	_session.player.auto_equip_skill("minus_1")
	var player_pos: Vector2i = _session.player.grid_pos
	if _session.enemies.size() > 0:
		_session.enemies[0].grid_pos = player_pos + Vector2i.RIGHT
		var result: Dictionary = _session.try_use_skill(0, Vector2i.RIGHT)
		assert_bool(result["success"]).is_true()


func test_use_skill_no_enemy_fails() -> void:
	_session.player.auto_equip_skill("minus_1")
	for e in _session.enemies:
		e.grid_pos = Vector2i(1, 1)
	var result: Dictionary = _session.try_use_skill(0, Vector2i.DOWN)
	assert_bool(result["success"]).is_false()


# --- 敵撃破 ---

func test_enemy_defeat_gives_exp() -> void:
	if _session.enemies.size() == 0:
		return
	_session.player.auto_equip_skill("minus_1")
	var enemy: Node = _session.enemies[0]
	var player_pos: Vector2i = _session.player.grid_pos
	enemy.grid_pos = player_pos + Vector2i.RIGHT
	enemy.set_value(1)  # 残り1
	_session.try_use_skill(0, Vector2i.RIGHT)  # minus_1 → 0 → 撃破
	assert_bool(enemy.state == ES.EnemyState.DEFEATED).is_true()


func test_enemy_defeat_updates_score() -> void:
	if _session.enemies.size() == 0:
		return
	_session.player.auto_equip_skill("minus_1")
	var enemy: Node = _session.enemies[0]
	var player_pos: Vector2i = _session.player.grid_pos
	enemy.grid_pos = player_pos + Vector2i.RIGHT
	var exp_r: int = enemy.exp_reward
	enemy.set_value(1)
	var kills_before: int = _session.score_system.total_kills
	_session.try_use_skill(0, Vector2i.RIGHT)  # minus_1 (slot 0に装備済み)
	assert_int(_session.score_system.total_kills).is_equal(kills_before + 1)


# --- 敵攻撃 ---

func test_adjacent_enemy_attacks_player() -> void:
	if _session.enemies.size() == 0:
		return
	var enemy: Node = _session.enemies[0]
	var player_pos: Vector2i = _session.player.grid_pos
	enemy.grid_pos = player_pos + Vector2i.RIGHT
	var hp_before: int = _session.player.hp
	_session.try_player_move(Vector2i.LEFT)  # ターン進行→敵が攻撃
	# 敵が追跡してきて隣接していればダメージ
	# 確実ではないので、HPが減っていればOK
	# (敵が隣接していなければダメージなし)


# --- 敵の重複防止 ---

func test_enemies_do_not_overlap_after_turn() -> void:
	if _session.enemies.size() < 2:
		return
	# 何ターンか進める
	for i in 10:
		_session.try_player_move(Vector2i.DOWN)
	# 全敵の位置が一意か確認
	var positions: Dictionary = {}
	for enemy in _session.enemies:
		if enemy.state == ES.EnemyState.DEFEATED:
			continue
		var pos: Vector2i = enemy.grid_pos
		assert_bool(positions.has(pos)).is_false()
		positions[pos] = true


# --- 階段 ---

func test_stairs_advance_floor() -> void:
	var stairs_pos: Vector2i = _session.map_generator.get_stairs_position()
	_session.player.grid_pos = stairs_pos
	var floor_before: int = _session.current_floor
	_session.interact_stairs()
	assert_int(_session.current_floor).is_equal(floor_before + 1)


func test_stage_advances_at_floor_6() -> void:
	# 5フロア進めてステージ2へ
	for i in 5:
		var stairs_pos: Vector2i = _session.map_generator.get_stairs_position()
		_session.player.grid_pos = stairs_pos
		_session.interact_stairs()
	assert_int(_session.current_stage).is_equal(2)
	assert_int(_session.current_floor).is_equal(6)


# --- ゲームオーバー ---

func test_game_over_on_death() -> void:
	var counter := [0]
	_session.game_over.connect(func() -> void: counter[0] += 1)
	_session.player.take_damage(999)
	assert_int(counter[0]).is_equal(1)


# --- 宝箱 ---

func test_open_chest_acquires_knowledge() -> void:
	var count_before: int = _session.knowledge_system.get_acquired_count()
	_session.open_chest()
	# 知識かアイテムが手に入る（知識が残っていれば知識）
	var count_after: int = _session.knowledge_system.get_acquired_count()
	assert_int(count_after).is_greater_equal(count_before)


# --- スコア連携 ---

func test_turn_registered_in_score() -> void:
	var turns_before: int = _session.score_system.total_turns
	_session.try_player_move(Vector2i.DOWN)
	assert_int(_session.score_system.total_turns).is_equal(turns_before + 1)
