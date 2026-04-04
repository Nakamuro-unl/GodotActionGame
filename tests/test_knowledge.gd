class_name TestKnowledge
extends GdUnitTestSuite

# 知識システムのテスト: 獲得、図鑑管理、技装備連携

const KS = preload("res://scripts/systems/knowledge_system.gd")

var _ks: Node


func before_test() -> void:
	_ks = KS.new()
	add_child(_ks)


func after_test() -> void:
	if is_instance_valid(_ks):
		_ks.queue_free()


# --- 初期状態 ---

func test_initial_no_knowledge() -> void:
	assert_int(_ks.get_acquired_count()).is_equal(0)


func test_all_knowledge_defined() -> void:
	# 全35知識が定義されている
	assert_int(_ks.get_total_count()).is_equal(35)


# --- 獲得 ---

# AC-KNW-001: 知識を獲得できる
func test_acquire_knowledge() -> void:
	var result: bool = _ks.acquire("K-101")
	assert_bool(result).is_true()
	assert_int(_ks.get_acquired_count()).is_equal(1)


# AC-KNW-002: 獲得した知識が図鑑に記録される
func test_acquired_knowledge_in_collection() -> void:
	_ks.acquire("K-101")
	assert_bool(_ks.is_acquired("K-101")).is_true()
	assert_bool(_ks.is_acquired("K-102")).is_false()


# AC-KNW-008: 既獲得の知識は重複獲得できない
func test_cannot_acquire_duplicate() -> void:
	_ks.acquire("K-101")
	var result: bool = _ks.acquire("K-101")
	assert_bool(result).is_false()
	assert_int(_ks.get_acquired_count()).is_equal(1)


# 存在しない知識IDは獲得できない
func test_cannot_acquire_invalid_id() -> void:
	var result: bool = _ks.acquire("K-999")
	assert_bool(result).is_false()


# 獲得シグナル
func test_acquire_emits_signal() -> void:
	var received: Array = []
	_ks.knowledge_acquired.connect(func(id: String) -> void: received.append(id))
	_ks.acquire("K-102")
	assert_array(received).contains_exactly(["K-102"])


# --- 知識情報 ---

# 知識の詳細情報を取得できる
func test_get_knowledge_info() -> void:
	var info: Dictionary = _ks.get_info("K-101")
	assert_str(info["name"]).is_equal("自然数の定義")
	assert_str(info["category"]).is_equal("definition")
	assert_int(info["stage"]).is_equal(1)


# ステージ別の知識一覧
func test_get_knowledge_by_stage() -> void:
	var stage1: Array = _ks.get_by_stage(1)
	assert_int(stage1.size()).is_equal(10)  # 基本6 + 追加4(繰り上がり/繰り下がり/十進法/補数)
	var stage5: Array = _ks.get_by_stage(5)
	assert_int(stage5.size()).is_equal(6)


# --- 技との連携 ---

# AC-KNW-003: 公式・定理はスキルIDを持つ
func test_formula_has_skill_id() -> void:
	var info: Dictionary = _ks.get_info("K-102")  # 加法
	assert_str(info["skill_id"]).is_not_empty()


# 定義はスキルIDを持たない（パッシブ）
func test_definition_has_no_skill_id() -> void:
	var info: Dictionary = _ks.get_info("K-101")  # 自然数の定義
	assert_str(info.get("skill_id", "")).is_empty()


# AC-KNW-003: 獲得した公式の技を装備可能リストに含む
func test_acquired_formula_available_as_skill() -> void:
	_ks.acquire("K-102")  # 加法 → plus系
	var skills: Array = _ks.get_equippable_skills()
	assert_bool(skills.size() > 0).is_true()


# 未獲得の知識の技は装備可能リストに含まない
func test_unacquired_not_in_equippable() -> void:
	var skills: Array = _ks.get_equippable_skills()
	assert_int(skills.size()).is_equal(0)


# --- フィールド効果 ---

# AC-KNW-005: 獲得時にフィールド効果が有効になる
func test_field_effects_active_after_acquire() -> void:
	_ks.acquire("K-104")  # 零の発見 → "void_wall_pass"
	var effects: Array = _ks.get_active_field_effects()
	assert_bool("void_wall_pass" in effects).is_true()


# 未獲得ではフィールド効果が無効
func test_field_effects_inactive_before_acquire() -> void:
	var effects: Array = _ks.get_active_field_effects()
	assert_bool("void_wall_pass" in effects).is_false()


# --- パッシブ効果 ---

# AC-KNW-006: 定義獲得でパッシブが有効になる
func test_passive_effects_active() -> void:
	_ks.acquire("K-101")  # 自然数の定義 → "show_enemy_values"
	var passives: Array = _ks.get_active_passives()
	assert_bool("show_enemy_values" in passives).is_true()


# --- 宝箱ドロップ ---

# AC-KNW-007: ステージ範囲内からランダムに未獲得知識を返す
func test_get_random_unobtained_for_stage() -> void:
	var id: String = _ks.get_random_unobtained(1)
	assert_str(id).is_not_empty()
	var info: Dictionary = _ks.get_info(id)
	assert_int(info["stage"]).is_less_equal(1)


# 全獲得済みだと空文字を返す
func test_random_unobtained_empty_when_all_acquired() -> void:
	var stage1: Array = _ks.get_by_stage(1)
	for k in stage1:
		_ks.acquire(k["id"])
	var id: String = _ks.get_random_unobtained(1)
	assert_str(id).is_empty()


# 収集率
func test_collection_rate() -> void:
	_ks.acquire("K-101")
	_ks.acquire("K-102")
	var rate: float = _ks.get_collection_rate()
	var expected: float = 2.0 / float(_ks.get_total_count()) * 100.0
	assert_float(rate).is_equal_approx(expected, 0.1)
