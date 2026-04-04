class_name TestInventory
extends GdUnitTestSuite

# インベントリ・初期状態・開始部屋の宝箱テスト

const GSS = preload("res://scripts/systems/game_session.gd")
const PS = preload("res://scripts/entities/player.gd")
const KS = preload("res://scripts/systems/knowledge_system.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _session: Node


func before_test() -> void:
	_session = GSS.new()
	add_child(_session)
	_session.start_new_game(12345)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.queue_free()


# --- 初期状態 ---

# AC-INV-001: 技なしでスタート
func test_player_starts_with_no_skills() -> void:
	for i in _session.player.skill_slots.size():
		assert_that(_session.player.skill_slots[i]).is_null()


# --- 開始部屋の宝箱 ---

# AC-INV-002: 開始部屋に宝箱がある
func test_start_room_has_chest() -> void:
	var start_pos: Vector2i = _session.player.grid_pos
	var has_chest: bool = false
	# 開始部屋（プレイヤー位置の周辺）に宝箱タイルがあるか
	for chest_pos in _session.chest_positions:
		# 同じ部屋内かチェック（マンハッタン距離10以内を同一部屋とみなす）
		var dist: int = absi(chest_pos.x - start_pos.x) + absi(chest_pos.y - start_pos.y)
		if dist < 10:
			has_chest = true
			break
	assert_bool(has_chest).is_true()


# AC-INV-003: 開始部屋の宝箱から減法を獲得できる
func test_start_chest_contains_subtraction() -> void:
	# 開始部屋の宝箱位置を探す
	var start_pos: Vector2i = _session.player.grid_pos
	var chest_pos: Vector2i = Vector2i.ZERO
	for cp in _session.chest_positions:
		var dist: int = absi(cp.x - start_pos.x) + absi(cp.y - start_pos.y)
		if dist < 10:
			chest_pos = cp
			break
	# 宝箱の位置に移動して開ける
	_session.player.grid_pos = chest_pos
	var result: Dictionary = _session.interact(Vector2i.ZERO)
	assert_str(result["type"]).is_equal("chest_knowledge")
	assert_str(result["knowledge_id"]).is_equal("K-103")


# AC-INV-003: 減法獲得後に-1技が使用可能
func test_subtraction_unlocks_minus1() -> void:
	_session.knowledge_system.acquire("K-103")
	_session.player.auto_equip_skill("minus_5")
	var has_skill: bool = false
	for s in _session.player.skill_slots:
		if s == "minus_5":
			has_skill = true
	assert_bool(has_skill).is_true()


# --- 自動装備 ---

# AC-INV-004: 知識獲得時に空きスロットへ自動装備
func test_auto_equip_on_acquire() -> void:
	_session.knowledge_system.acquire("K-103")
	_session.player.auto_equip_skill("minus_5")
	assert_str(_session.player.skill_slots[0]).is_equal("minus_5")


# 全スロット埋まっている場合は自動装備しない
func test_auto_equip_skipped_when_full() -> void:
	for i in 6:
		_session.player.skill_slots[i] = "dummy_%d" % i
	_session.player.auto_equip_skill("minus_5")
	# どのスロットにもminus_5がない
	var found: bool = false
	for s in _session.player.skill_slots:
		if s == "minus_5":
			found = true
	assert_bool(found).is_false()


# AC-INV-006: 定義カテゴリは装備不可
func test_definition_not_equippable() -> void:
	_session.knowledge_system.acquire("K-101")  # 自然数の定義
	var info: Dictionary = _session.knowledge_system.get_info("K-101")
	assert_str(info.get("skill_id", "")).is_empty()


# --- 知識と技の連携 ---

# 獲得していない知識の技は装備できない
func test_cannot_equip_unacquired_skill() -> void:
	var skills: Array = _session.knowledge_system.get_equippable_skills()
	assert_int(skills.size()).is_equal(0)


# 獲得後に装備可能リストに含まれる
func test_acquired_knowledge_appears_in_equippable() -> void:
	_session.knowledge_system.acquire("K-102")  # 加法
	var skills: Array = _session.knowledge_system.get_equippable_skills()
	assert_bool(skills.size() > 0).is_true()
	assert_str(skills[0]["skill_id"]).is_equal("plus_3")


# 複数知識獲得で複数技が使用可能
func test_multiple_knowledge_multiple_skills() -> void:
	_session.knowledge_system.acquire("K-102")  # 加法
	_session.knowledge_system.acquire("K-103")  # 減法
	_session.knowledge_system.acquire("K-201")  # 乗法
	var skills: Array = _session.knowledge_system.get_equippable_skills()
	assert_int(skills.size()).is_equal(3)
