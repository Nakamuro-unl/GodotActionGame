class_name TestCombat
extends GdUnitTestSuite

# 戦闘システムのテスト: 技の適用、撃破、幽霊化、ダメージ計算

const CS = preload("res://scripts/systems/combat_system.gd")
const ES = preload("res://scripts/entities/enemy.gd")
const PS = preload("res://scripts/entities/player.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _combat: Node
var _player: Node
var _enemy: Node
var _grid: Array


func before_test() -> void:
	_combat = CS.new()
	_player = PS.new()
	_enemy = ES.new()
	add_child(_combat)
	add_child(_player)
	add_child(_enemy)
	_grid = _create_test_grid()
	_player.setup(_grid, Vector2i(5, 5))
	_enemy.setup("子狼", 5, 2, 2, ES.AIPattern.CHASE, Vector2i(5, 4))


func after_test() -> void:
	for node in [_combat, _player, _enemy]:
		if is_instance_valid(node):
			node.queue_free()


# --- 算術技 ---

# AC-CMB-011: プラス1
func test_skill_plus_1() -> void:
	var result: Dictionary = _combat.use_skill("plus_1", _player, _enemy)
	assert_bool(result["success"]).is_true()
	assert_int(_enemy.value).is_equal(6)
	assert_int(result["mp_cost"]).is_equal(0)


# AC-CMB-011: マイナス1
func test_skill_minus_1() -> void:
	_combat.use_skill("minus_1", _player, _enemy)
	assert_int(_enemy.value).is_equal(4)


# AC-CMB-011: プラス3
func test_skill_plus_3() -> void:
	_combat.use_skill("plus_3", _player, _enemy)
	assert_int(_enemy.value).is_equal(8)


# AC-CMB-011: マイナス5
func test_skill_minus_5() -> void:
	_combat.use_skill("minus_5", _player, _enemy)
	assert_int(_enemy.value).is_equal(0)


# AC-CMB-011: プラス10
func test_skill_plus_10() -> void:
	_combat.use_skill("plus_10", _player, _enemy)
	assert_int(_enemy.value).is_equal(15)


# AC-CMB-011: マイナス10
func test_skill_minus_10() -> void:
	_combat.use_skill("minus_10", _player, _enemy)
	assert_int(_enemy.value).is_equal(-5)


# --- 乗除技 ---

# AC-CMB-011: ダブル (x2)
func test_skill_double() -> void:
	_enemy.setup("サソリ", 6, 4, 6, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("double", _player, _enemy)
	assert_int(_enemy.value).is_equal(12)


# AC-CMB-011: ハーフ (/2 切捨)
func test_skill_half() -> void:
	_enemy.setup("サソリ", 7, 4, 6, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("half", _player, _enemy)
	assert_int(_enemy.value).is_equal(3)


# AC-CMB-011: トリプル (x3)
func test_skill_triple() -> void:
	_enemy.setup("サソリ", 4, 4, 6, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("triple", _player, _enemy)
	assert_int(_enemy.value).is_equal(12)


# AC-CMB-011: サード (/3 切捨)
func test_skill_third() -> void:
	_enemy.setup("サソリ", 10, 4, 6, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("third", _player, _enemy)
	assert_int(_enemy.value).is_equal(3)


# AC-CMB-011: モジュロ4 (%4)
func test_skill_mod4() -> void:
	_enemy.setup("サソリ", 10, 4, 6, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("mod4", _player, _enemy)
	assert_int(_enemy.value).is_equal(2)


# --- 関数技 ---

# AC-CMB-011: アブソリュート (abs)
func test_skill_abs() -> void:
	_enemy.setup("子狼", 3, 2, 2, ES.AIPattern.CHASE, Vector2i(5, 4))
	_enemy.apply_value_change(-5)  # value = -2, ghost
	_combat.use_skill("abs", _player, _enemy)
	assert_int(_enemy.value).is_equal(2)


# AC-CMB-011: ネゲート (x-1)
func test_skill_negate() -> void:
	_enemy.setup("ゴブリン", 7, 6, 10, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("negate", _player, _enemy)
	assert_int(_enemy.value).is_equal(-7)


# AC-CMB-011: スクエア (x^2)
func test_skill_square() -> void:
	_enemy.setup("ゴブリン", 3, 6, 10, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("square", _player, _enemy)
	assert_int(_enemy.value).is_equal(9)


# AC-CMB-011: ルート (floor(sqrt))
func test_skill_sqrt() -> void:
	_enemy.setup("ゴブリン", 10, 6, 10, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("sqrt", _player, _enemy)
	assert_int(_enemy.value).is_equal(3)


# --- 高等技 ---

# AC-CMB-011: デリバティブ（桁数）
func test_skill_derivative() -> void:
	_enemy.setup("機械兵", 125, 10, 20, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("derivative", _player, _enemy)
	assert_int(_enemy.value).is_equal(3)


# AC-CMB-011: インテグラル（各桁合計）
func test_skill_integral() -> void:
	_enemy.setup("機械兵", 125, 10, 20, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("integral", _player, _enemy)
	assert_int(_enemy.value).is_equal(8)


# AC-CMB-011: ログ (floor(log2))
func test_skill_log2() -> void:
	_enemy.setup("機械兵", 32, 10, 20, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("log2", _player, _enemy)
	assert_int(_enemy.value).is_equal(5)


# AC-CMB-011: アイデンティティ (value/value = 1)
func test_skill_identity() -> void:
	_enemy.setup("エイリアン", 50, 15, 40, ES.AIPattern.CHASE, Vector2i(5, 4))
	_combat.use_skill("identity", _player, _enemy)
	assert_int(_enemy.value).is_equal(1)


# --- 撃破・幽霊化の連携 ---

# AC-CMB-003: 技で数値を0にして撃破
func test_defeat_enemy_with_skill() -> void:
	var counter := [0]
	_enemy.defeated.connect(func() -> void: counter[0] += 1)
	_combat.use_skill("minus_5", _player, _enemy)  # 5 - 5 = 0
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)
	assert_int(counter[0]).is_equal(1)


# AC-CMB-004: 技で負にして幽霊化
func test_ghostify_enemy_with_skill() -> void:
	var counter := [0]
	_enemy.ghostified.connect(func() -> void: counter[0] += 1)
	_combat.use_skill("minus_10", _player, _enemy)  # 5 - 10 = -5
	assert_int(_enemy.state).is_equal(ES.EnemyState.GHOST)
	assert_int(counter[0]).is_equal(1)


# --- MP消費 ---

# AC-CMB-008: MP消費が正しい
func test_mp_cost_deducted() -> void:
	_combat.use_skill("minus_5", _player, _enemy)  # cost: 2
	assert_int(_player.mp).is_equal(8)


# AC-CMB-008: MP不足時は技を使えない
func test_skill_fails_when_mp_insufficient() -> void:
	# MPを0にする
	_player.consume_mp(10)
	var result: Dictionary = _combat.use_skill("minus_5", _player, _enemy)
	assert_bool(result["success"]).is_false()
	assert_int(_enemy.value).is_equal(5)  # 変化なし


# MP消費0の技はMP0でも使える
func test_free_skill_works_with_zero_mp() -> void:
	_player.consume_mp(10)
	var result: Dictionary = _combat.use_skill("plus_1", _player, _enemy)
	assert_bool(result["success"]).is_true()
	assert_int(_enemy.value).is_equal(6)


# --- ダメージ計算（敵→プレイヤー） ---

# AC-CMB-009: 敵の攻撃ダメージ
func test_enemy_attacks_player() -> void:
	var dmg: int = _combat.calculate_damage(_enemy, _player)
	# attack_power(2) - defense(0) = 2, 最低1
	assert_int(dmg).is_equal(2)


# ダメージは最低1
func test_minimum_damage_is_one() -> void:
	# 防御力を高くする想定だが現在は0なのでattack=1でテスト
	_enemy.setup("弱い敵", 1, 1, 1, ES.AIPattern.CHASE, Vector2i(5, 4))
	var dmg: int = _combat.calculate_damage(_enemy, _player)
	assert_int(dmg).is_greater_equal(1)


# --- 技一覧取得 ---

# 存在しない技はエラー
func test_invalid_skill_returns_failure() -> void:
	var result: Dictionary = _combat.use_skill("nonexistent", _player, _enemy)
	assert_bool(result["success"]).is_false()


# 技の情報を取得できる
func test_get_skill_info() -> void:
	var info: Dictionary = _combat.get_skill_info("minus_5")
	assert_str(info["name"]).is_equal("マイナス5")
	assert_int(info["mp_cost"]).is_equal(2)


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
