class_name TestLimitedSkill
extends GdUnitTestSuite

# 回数制限付き技のテスト

const CS = preload("res://scripts/systems/combat_system.gd")
const PS = preload("res://scripts/entities/player.gd")
const ES = preload("res://scripts/entities/enemy.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _combat: Node
var _player: Node
var _enemy: Node


func before_test() -> void:
	_combat = CS.new()
	_player = PS.new()
	_enemy = ES.new()
	add_child(_combat)
	add_child(_player)
	add_child(_enemy)
	var grid: Array = _create_test_grid()
	_player.setup(grid, Vector2i(5, 5))
	_enemy.setup("機械兵", 100, 10, 20, ES.AIPattern.CHASE, Vector2i(5, 4))
	_player.auto_equip_skill("zero_mul")


func after_test() -> void:
	for node in [_combat, _player, _enemy]:
		if is_instance_valid(node):
			node.queue_free()


# --- ゼロ乗算 ---

# x0で敵の数値が0になる
func test_zero_mul_sets_value_to_zero() -> void:
	var result: Dictionary = _combat.use_skill("zero_mul", _player, _enemy)
	assert_bool(result["success"]).is_true()
	assert_int(_enemy.value).is_equal(0)


# 使用回数が減る
func test_zero_mul_decrements_uses() -> void:
	var before: int = _player.get_skill_remaining("zero_mul")
	assert_int(before).is_equal(3)
	_combat.use_skill("zero_mul", _player, _enemy)
	assert_int(_player.get_skill_remaining("zero_mul")).is_equal(2)


# 残り0回で使用不可
func test_zero_mul_fails_when_exhausted() -> void:
	for i in 3:
		_enemy.setup("敵%d" % i, 10, 1, 1, ES.AIPattern.CHASE, Vector2i(5, 4))
		_combat.use_skill("zero_mul", _player, _enemy)
	# 4回目は失敗
	_enemy.setup("敵3", 10, 1, 1, ES.AIPattern.CHASE, Vector2i(5, 4))
	var result: Dictionary = _combat.use_skill("zero_mul", _player, _enemy)
	assert_bool(result["success"]).is_false()
	assert_int(_enemy.value).is_equal(10)  # 変化なし


# 回数制限のない技は何回でも使える
func test_normal_skill_no_limit() -> void:
	_player.auto_equip_skill("minus_1")
	for i in 10:
		_enemy.setup("敵", 5, 1, 1, ES.AIPattern.CHASE, Vector2i(5, 4))
		var result: Dictionary = _combat.use_skill("minus_1", _player, _enemy)
		assert_bool(result["success"]).is_true()


# 回数制限の確認
func test_has_limited_uses() -> void:
	assert_bool(_combat.is_limited_skill("zero_mul")).is_true()
	assert_bool(_combat.is_limited_skill("minus_1")).is_false()


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
