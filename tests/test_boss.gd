class_name TestBoss
extends GdUnitTestSuite

# ボス敵のテスト: 特殊行動、撃破時ドロップ、ボス部屋配置

const ES = preload("res://scripts/entities/enemy.gd")
const GSS = preload("res://scripts/systems/game_session.gd")

var _session: Node


func before_test() -> void:
	_session = GSS.new()
	add_child(_session)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.queue_free()


# --- ボス配置 ---

# ボスフロア(5F)にボスがいる
func test_boss_spawns_on_boss_floor() -> void:
	_session.start_new_game(12345)
	# 5Fまで進める
	for i in 4:
		var stairs: Vector2i = _session.map_generator.get_stairs_position()
		_session.player.grid_pos = stairs
		_session.interact_stairs()
	# 5Fにボスがいるか
	var has_boss: bool = false
	for enemy in _session.enemies:
		if enemy.ai_pattern == ES.AIPattern.BOSS:
			has_boss = true
			break
	assert_bool(has_boss).is_true()


# 通常フロアにはボスがいない
func test_no_boss_on_normal_floor() -> void:
	_session.start_new_game(12345)
	for enemy in _session.enemies:
		assert_int(enemy.ai_pattern).is_not_equal(ES.AIPattern.BOSS)


# ボスフロアのボスは数値が固定
func test_boss_has_fixed_value() -> void:
	_session.start_new_game(12345)
	for i in 4:
		var stairs: Vector2i = _session.map_generator.get_stairs_position()
		_session.player.grid_pos = stairs
		_session.interact_stairs()
	for enemy in _session.enemies:
		if enemy.ai_pattern == ES.AIPattern.BOSS:
			assert_int(enemy.value).is_equal(20)  # 原始の王: 固定20
			break


# --- ボス特殊行動 ---

# 数値が初期値の半分以下で攻撃力1.5倍
func test_boss_enraged_attack() -> void:
	var boss: Node = ES.new()
	add_child(boss)
	boss.setup("原始の王", 10, 8, 30, ES.AIPattern.BOSS, Vector2i(5, 5))
	boss._initial_value = 10

	# 数値を半分以下にする
	boss.apply_value_change(-6)  # value = 4 (< 10/2 = 5)
	var dmg: int = boss.get_attack_damage()
	assert_int(dmg).is_equal(12)  # 8 * 1.5 = 12

	boss.queue_free()


# 数値が半分より大きいときは通常攻撃力
func test_boss_normal_attack() -> void:
	var boss: Node = ES.new()
	add_child(boss)
	boss.setup("原始の王", 10, 8, 30, ES.AIPattern.BOSS, Vector2i(5, 5))
	boss._initial_value = 10

	var dmg: int = boss.get_attack_damage()
	assert_int(dmg).is_equal(8)

	boss.queue_free()


# --- ボス撃破時の知識ドロップ ---

# AC-KNW-007: ボス撃破時に定理が確定ドロップ
func test_boss_drops_theorem_on_defeat() -> void:
	_session.start_new_game(12345)
	for i in 4:
		var stairs: Vector2i = _session.map_generator.get_stairs_position()
		_session.player.grid_pos = stairs
		_session.interact_stairs()

	# ボスを探す
	var boss: Node = null
	for enemy in _session.enemies:
		if enemy.ai_pattern == ES.AIPattern.BOSS:
			boss = enemy
			break
	if boss == null:
		return

	var knowledge_before: int = _session.knowledge_system.get_acquired_count()
	_session.player.auto_equip_skill("minus_1")
	boss.grid_pos = _session.player.grid_pos + Vector2i.RIGHT
	boss.set_value(1)
	_session.try_use_skill(0, Vector2i.RIGHT)  # 撃破

	# 知識が増えている
	assert_int(_session.knowledge_system.get_acquired_count()).is_greater(knowledge_before)


# --- ボスデータ ---

# 全5ステージのボスが定義されている
func test_all_stage_bosses_defined() -> void:
	var bosses: Dictionary = ES.BOSS_DATA
	assert_bool(bosses.has(1)).is_true()
	assert_bool(bosses.has(2)).is_true()
	assert_bool(bosses.has(3)).is_true()
	assert_bool(bosses.has(4)).is_true()
	assert_bool(bosses.has(5)).is_true()


# ボスデータに必要な情報がある
func test_boss_data_has_fields() -> void:
	var data: Dictionary = ES.BOSS_DATA[1]
	assert_str(data["name"]).is_equal("原始の王")
	assert_int(data["value"]).is_equal(20)
	assert_bool(data.has("attack")).is_true()
	assert_bool(data.has("exp")).is_true()
	assert_bool(data.has("theorem_id")).is_true()
