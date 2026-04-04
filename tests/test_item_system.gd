class_name TestItemSystem
extends GdUnitTestSuite

# アイテム使用システムのテスト

const IS = preload("res://scripts/systems/item_system.gd")
const PS = preload("res://scripts/entities/player.gd")
const ES = preload("res://scripts/entities/enemy.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _item_sys: Node
var _player: Node
var _enemy: Node
var _grid: Array


func before_test() -> void:
	_item_sys = IS.new()
	_player = PS.new()
	_enemy = ES.new()
	add_child(_item_sys)
	add_child(_player)
	add_child(_enemy)
	_grid = _create_test_grid()
	_player.setup(_grid, Vector2i(5, 5))
	_enemy.setup("子狼", 7, 2, 2, ES.AIPattern.CHASE, Vector2i(5, 4))


func after_test() -> void:
	for node in [_item_sys, _player, _enemy]:
		if is_instance_valid(node):
			node.queue_free()


# --- アイテム定義 ---

func test_all_items_defined() -> void:
	var db: Dictionary = IS.ITEM_DB
	assert_int(db.size()).is_greater_equal(16)


func test_item_has_required_fields() -> void:
	var info: Dictionary = IS.ITEM_DB["herb"]
	assert_str(info["name"]).is_equal("薬草")
	assert_str(info["type"]).is_not_empty()
	assert_bool(info.has("description")).is_true()


# --- 回復系 ---

# AC-ITM-003: 薬草 HP+10
func test_use_herb() -> void:
	_player.take_damage(15)
	_player.add_item("herb")
	var result: Dictionary = _item_sys.use_item(_player, 0, _enemy)
	assert_bool(result["success"]).is_true()
	assert_int(_player.hp).is_equal(25)


# AC-ITM-003: 上薬草 HP+30
func test_use_upper_herb() -> void:
	_player.take_damage(20)
	_player.add_item("upper_herb")
	var result: Dictionary = _item_sys.use_item(_player, 0, _enemy)
	assert_bool(result["success"]).is_true()
	assert_int(_player.hp).is_equal(30)  # max_hpが30なのでキャップ


# AC-ITM-003: 万能薬 HP全回復
func test_use_panacea() -> void:
	_player.take_damage(25)
	_player.add_item("panacea")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_player.hp).is_equal(30)


# AC-ITM-003: 知恵の水 MP+5
func test_use_wisdom_water() -> void:
	_player.consume_mp(8)
	_player.add_item("wisdom_water")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_player.mp).is_equal(7)


# AC-ITM-003: 覚醒の水 MP全回復
func test_use_awakening_water() -> void:
	_player.consume_mp(8)
	_player.add_item("awakening_water")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_player.mp).is_equal(10)


# AC-ITM-003: エリクサー HP/MP全回復
func test_use_elixir() -> void:
	_player.take_damage(20)
	_player.consume_mp(8)
	_player.add_item("elixir")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_player.hp).is_equal(30)
	assert_int(_player.mp).is_equal(10)


# --- 戦闘補助系 ---

# AC-ITM-003: 偶数の粉
func test_use_even_powder() -> void:
	_enemy.set_value(7)
	_player.add_item("even_powder")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_enemy.value % 2).is_equal(0)


# AC-ITM-003: 奇数の粉
func test_use_odd_powder() -> void:
	_enemy.set_value(8)
	_player.add_item("odd_powder")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_enemy.value % 2).is_equal(1)


# AC-ITM-003: 零の巻物（即死）
func test_use_zero_scroll() -> void:
	_player.add_item("zero_scroll")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_enemy.value).is_equal(0)
	assert_int(_enemy.state).is_equal(ES.EnemyState.DEFEATED)


# AC-ITM-003: 反転の鏡
func test_use_reverse_mirror() -> void:
	_enemy.set_value(5)
	_player.add_item("reverse_mirror")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_enemy.value).is_equal(-5)


# AC-ITM-003: 半減の砂
func test_use_halving_sand() -> void:
	_enemy.set_value(10)
	_player.add_item("halving_sand")
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_enemy.value).is_equal(5)


# --- 探索系 ---

# AC-ITM-003: 経験の書
func test_use_exp_book() -> void:
	_player.add_item("exp_book")
	var exp_before: int = _player.exp
	_item_sys.use_item(_player, 0, null)
	assert_int(_player.exp).is_greater(exp_before)


# --- 使用ルール ---

# AC-ITM-002: アイテム使用後に所持から消える
func test_item_consumed_after_use() -> void:
	_player.add_item("herb")
	assert_int(_player.items.size()).is_equal(1)
	_item_sys.use_item(_player, 0, _enemy)
	assert_int(_player.items.size()).is_equal(0)


# 空インベントリでは使用失敗
func test_use_empty_fails() -> void:
	var result: Dictionary = _item_sys.use_item(_player, 0, _enemy)
	assert_bool(result["success"]).is_false()


# 範囲外インデックスは使用失敗
func test_use_invalid_index_fails() -> void:
	_player.add_item("herb")
	var result: Dictionary = _item_sys.use_item(_player, 99, _enemy)
	assert_bool(result["success"]).is_false()


# 戦闘補助系はターゲットなしで失敗
func test_combat_item_needs_target() -> void:
	_player.add_item("zero_scroll")
	var result: Dictionary = _item_sys.use_item(_player, 0, null)
	assert_bool(result["success"]).is_false()
	assert_int(_player.items.size()).is_equal(1)  # 消費されない


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
