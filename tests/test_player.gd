class_name TestPlayer
extends GdUnitTestSuite

# プレイヤーの移動・ステータス・技スロットをテストする

const PS = preload("res://scripts/entities/player.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _player: Node
var _grid: Array


func before_test() -> void:
	_player = PS.new()
	add_child(_player)
	# テスト用の小さなグリッド（10x10、中央が床）を生成
	_grid = _create_test_grid()
	_player.setup(_grid, Vector2i(5, 5))


func after_test() -> void:
	if is_instance_valid(_player):
		_player.queue_free()


# --- 初期ステータス ---

# AC-PLR-001: 初期位置が設定されること
func test_initial_position() -> void:
	assert_int(_player.grid_pos.x).is_equal(5)
	assert_int(_player.grid_pos.y).is_equal(5)


# 初期HP
func test_initial_hp() -> void:
	assert_int(_player.hp).is_equal(30)
	assert_int(_player.max_hp).is_equal(30)


# 初期MP
func test_initial_mp() -> void:
	assert_int(_player.mp).is_equal(10)
	assert_int(_player.max_mp).is_equal(10)


# 初期レベル
func test_initial_level() -> void:
	assert_int(_player.level).is_equal(1)


# --- 移動 ---

# AC-PLR-001: 上に移動できること
func test_move_up() -> void:
	var result: bool = _player.try_move(Vector2i.UP, _grid)
	assert_bool(result).is_true()
	assert_int(_player.grid_pos.y).is_equal(4)


# AC-PLR-001: 下に移動できること
func test_move_down() -> void:
	var result: bool = _player.try_move(Vector2i.DOWN, _grid)
	assert_bool(result).is_true()
	assert_int(_player.grid_pos.y).is_equal(6)


# AC-PLR-001: 左に移動できること
func test_move_left() -> void:
	var result: bool = _player.try_move(Vector2i.LEFT, _grid)
	assert_bool(result).is_true()
	assert_int(_player.grid_pos.x).is_equal(4)


# AC-PLR-001: 右に移動できること
func test_move_right() -> void:
	var result: bool = _player.try_move(Vector2i.RIGHT, _grid)
	assert_bool(result).is_true()
	assert_int(_player.grid_pos.x).is_equal(6)


# AC-PLR-002: 壁に移動できないこと
func test_cannot_move_into_wall() -> void:
	# (5,1)から上に移動すると壁(y=0)にぶつかる
	_player.setup(_grid, Vector2i(5, 1))
	var result: bool = _player.try_move(Vector2i.UP, _grid)
	assert_bool(result).is_false()
	assert_int(_player.grid_pos.y).is_equal(1)


# AC-PLR-003: 移動成功時にシグナルが発火すること
func test_move_emits_moved_signal() -> void:
	var received: Array = []
	_player.moved.connect(func(old_pos: Vector2i, new_pos: Vector2i) -> void: received.append([old_pos, new_pos]))
	_player.try_move(Vector2i.RIGHT, _grid)
	assert_array(received).contains_exactly([[Vector2i(5, 5), Vector2i(6, 5)]])


# 移動失敗時にシグナルが発火しないこと
func test_failed_move_does_not_emit_signal() -> void:
	_player.setup(_grid, Vector2i(5, 1))
	var counter := [0]
	_player.moved.connect(func(_o: Vector2i, _n: Vector2i) -> void: counter[0] += 1)
	_player.try_move(Vector2i.UP, _grid)
	assert_int(counter[0]).is_equal(0)


# --- ダメージ・HP ---

# AC-PLR-010: ダメージを受けてHPが減ること
func test_take_damage() -> void:
	_player.take_damage(5)
	assert_int(_player.hp).is_equal(25)


# AC-PLR-010: HPが0以下になったらdeadシグナル
func test_dead_signal_on_zero_hp() -> void:
	var counter := [0]
	_player.dead.connect(func() -> void: counter[0] += 1)
	_player.take_damage(30)
	assert_int(_player.hp).is_equal(0)
	assert_int(counter[0]).is_equal(1)


# HPは0未満にならない
func test_hp_does_not_go_below_zero() -> void:
	_player.take_damage(999)
	assert_int(_player.hp).is_equal(0)


# AC-PLR-011: HP回復
func test_heal_hp() -> void:
	_player.take_damage(10)
	_player.heal_hp(5)
	assert_int(_player.hp).is_equal(25)


# HP回復は最大値を超えない
func test_heal_hp_does_not_exceed_max() -> void:
	_player.heal_hp(100)
	assert_int(_player.hp).is_equal(30)


# --- MP ---

# AC-PLR-006: MP消費
func test_consume_mp() -> void:
	var result: bool = _player.consume_mp(3)
	assert_bool(result).is_true()
	assert_int(_player.mp).is_equal(7)


# AC-PLR-007: MP不足時は消費失敗
func test_consume_mp_fails_when_insufficient() -> void:
	var result: bool = _player.consume_mp(99)
	assert_bool(result).is_false()
	assert_int(_player.mp).is_equal(10)


# --- 技スロット ---

# AC-INV-001: 初期は技なし
func test_initial_skills() -> void:
	var slots: Array = _player.skill_slots
	assert_int(slots.size()).is_equal(6)
	for i in slots.size():
		assert_that(slots[i]).is_null()


# AC-PLR-004: 技を装備できること
func test_equip_skill() -> void:
	_player.equip_skill(2, "plus_3")
	assert_str(_player.skill_slots[2]).is_equal("plus_3")


# 技を解除できること
func test_unequip_skill() -> void:
	_player.unequip_skill(0)
	assert_that(_player.skill_slots[0]).is_null()


# --- レベルアップ ---

# AC-PLR-008: 経験値を獲得してレベルアップ
func test_gain_exp_and_level_up() -> void:
	# レベル1→2: 10exp必要
	var counter := [0]
	_player.leveled_up.connect(func(new_level: int) -> void: counter[0] = new_level)
	_player.gain_exp(10)
	assert_int(_player.level).is_equal(2)
	assert_int(counter[0]).is_equal(2)


# レベルアップでHP/MP最大値が上昇
func test_level_up_increases_max_stats() -> void:
	_player.gain_exp(10)
	assert_int(_player.max_hp).is_equal(35)  # +5
	assert_int(_player.max_mp).is_equal(13)  # +3


# レベルアップでHP/MP全回復
func test_level_up_fully_heals() -> void:
	_player.take_damage(10)
	_player.consume_mp(5)
	_player.gain_exp(10)
	assert_int(_player.hp).is_equal(35)
	assert_int(_player.mp).is_equal(13)


# --- アイテム所持 ---

# AC-PLR-009: アイテムを追加できること
func test_add_item() -> void:
	var result: bool = _player.add_item("herb")
	assert_bool(result).is_true()
	assert_int(_player.items.size()).is_equal(1)


# AC-PLR-009: 最大10個まで
func test_item_limit() -> void:
	for i in 10:
		_player.add_item("herb")
	var result: bool = _player.add_item("herb")
	assert_bool(result).is_false()
	assert_int(_player.items.size()).is_equal(10)


# --- ヘルパー ---

func _create_test_grid() -> Array:
	# 10x10のグリッド: 外周が壁(0)、内部が床(1)
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
