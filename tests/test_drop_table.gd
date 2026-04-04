class_name TestDropTable
extends GdUnitTestSuite

# 重み付き抽選とレベルデザイン設定のテスト

const DT = preload("res://scripts/systems/drop_table.gd")

var _dt: Node


func before_test() -> void:
	_dt = DT.new()
	add_child(_dt)


func after_test() -> void:
	if is_instance_valid(_dt):
		_dt.queue_free()


# --- 重み付き抽選 ---

# AC-LVL-001: 重み付きで1つ選択される
func test_weighted_pick_returns_valid_item() -> void:
	var items: Array = [
		{"id": "a", "weight": 50},
		{"id": "b", "weight": 30},
		{"id": "c", "weight": 20},
	]
	var result: String = _dt.weighted_pick(items)
	assert_bool(result in ["a", "b", "c"]).is_true()


# AC-LVL-002: 重みが高い敵ほど出現頻度が高い（統計的テスト）
func test_weighted_pick_respects_weight() -> void:
	var items: Array = [
		{"id": "heavy", "weight": 90},
		{"id": "light", "weight": 10},
	]
	var counts: Dictionary = {"heavy": 0, "light": 0}
	for i in 1000:
		var result: String = _dt.weighted_pick(items)
		counts[result] += 1
	# heavyが70%以上出るはず（90%期待、マージン込み）
	assert_int(counts["heavy"]).is_greater(700)


# 重み0のアイテムは選ばれない
func test_zero_weight_not_picked() -> void:
	var items: Array = [
		{"id": "a", "weight": 100},
		{"id": "b", "weight": 0},
	]
	for i in 100:
		var result: String = _dt.weighted_pick(items)
		assert_str(result).is_equal("a")


# 空リストはデフォルト値を返す
func test_empty_list_returns_empty() -> void:
	var result: String = _dt.weighted_pick([])
	assert_str(result).is_empty()


# --- ステージフィルタリング ---

# AC-LVL-004: min_stageでフィルタリング
func test_filter_by_stage() -> void:
	var items: Array = [
		{"id": "a", "weight": 10, "min_stage": 1},
		{"id": "b", "weight": 10, "min_stage": 3},
		{"id": "c", "weight": 10, "min_stage": 5},
	]
	var filtered: Array = _dt.filter_by_stage(items, 2)
	assert_int(filtered.size()).is_equal(1)
	assert_str(filtered[0]["id"]).is_equal("a")


func test_filter_by_stage_includes_current() -> void:
	var items: Array = [
		{"id": "a", "weight": 10, "min_stage": 1},
		{"id": "b", "weight": 10, "min_stage": 3},
	]
	var filtered: Array = _dt.filter_by_stage(items, 3)
	assert_int(filtered.size()).is_equal(2)


# --- 敵テーブル ---

# AC-LVL-001: ステージ別敵を重み付きで取得
func test_get_enemy_template_for_stage() -> void:
	var template: Dictionary = _dt.pick_enemy_template(1)
	assert_str(template["name"]).is_not_empty()
	assert_bool(template.has("weight")).is_true()


# 全ステージで敵が取得できる
func test_enemy_template_for_all_stages() -> void:
	for stage in range(1, 6):
		var template: Dictionary = _dt.pick_enemy_template(stage)
		assert_str(template["name"]).is_not_empty()


# --- アイテムテーブル ---

# AC-LVL-003: レアリティに基づいてアイテム抽選
func test_pick_item_returns_valid() -> void:
	var item: Dictionary = _dt.pick_item(1)
	assert_str(item["id"]).is_not_empty()
	assert_bool(item.has("rarity")).is_true()


# AC-LVL-004: ステージ1ではステージ2以降のアイテムは出ない
func test_pick_item_respects_stage() -> void:
	for i in 100:
		var item: Dictionary = _dt.pick_item(1)
		assert_int(item["min_stage"]).is_less_equal(1)


# ステージ3以降のアイテムが出る
func test_pick_item_higher_stage() -> void:
	var found_stage3: bool = false
	for i in 200:
		var item: Dictionary = _dt.pick_item(3)
		if item["min_stage"] == 3:
			found_stage3 = true
			break
	assert_bool(found_stage3).is_true()


# --- 宝箱配分 ---

# AC-LVL-005: 宝箱の知識/アイテム配分
func test_chest_roll_knowledge_vs_item() -> void:
	var knowledge_count: int = 0
	var item_count: int = 0
	for i in 1000:
		var result: String = _dt.roll_chest_type(true)
		if result == "knowledge":
			knowledge_count += 1
		else:
			item_count += 1
	# 知識60%期待、マージン込みで45%以上
	assert_int(knowledge_count).is_greater(450)
	assert_int(item_count).is_greater(300)


# 知識なしなら100%アイテム
func test_chest_roll_no_knowledge_available() -> void:
	for i in 100:
		var result: String = _dt.roll_chest_type(false)
		assert_str(result).is_equal("item")


# --- JSON設定 ---

# AC-LVL-007: デフォルト設定が存在
func test_default_config_exists() -> void:
	var config: Dictionary = _dt.get_config()
	assert_bool(config.has("chest_knowledge_rate")).is_true()
	assert_bool(config.has("enemy_tables")).is_true()
	assert_bool(config.has("item_table")).is_true()
