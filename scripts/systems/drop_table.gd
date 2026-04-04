extends Node

## 重み付き抽選とレベルデザイン設定。
## 敵出現、アイテムドロップ、宝箱配分をデータ駆動で管理する。

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const CONFIG_PATH: String = "res://data/level_config.json"

var _config: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_config = _build_default_config()
	_try_load_json()


## 現在の設定を返す
func get_config() -> Dictionary:
	if _config.is_empty():
		_config = _build_default_config()
	return _config


# --- 重み付き抽選 ---

## 重み付きリストから1つ選ぶ。各要素は {"id": ..., "weight": int, ...}
func weighted_pick(items: Array) -> String:
	if items.is_empty():
		return ""
	var total: int = 0
	for item in items:
		total += int(item["weight"])
	if total <= 0:
		return ""
	var roll: int = _rng.randi_range(0, total - 1)
	var cumulative: int = 0
	for item in items:
		cumulative += int(item["weight"])
		if roll < cumulative:
			return str(item["id"])
	return str(items[-1]["id"])


## min_stageでフィルタリング
func filter_by_stage(items: Array, current_stage: int) -> Array:
	var result: Array = []
	for item in items:
		if int(item["min_stage"]) <= current_stage:
			result.append(item)
	return result


# --- 敵テーブル ---

## ステージに対応する敵テンプレートを重み付きで1つ選ぶ
func pick_enemy_template(stage: int) -> Dictionary:
	var config: Dictionary = get_config()
	var tables: Dictionary = config["enemy_tables"]
	var key: String = str(stage)
	if not tables.has(key):
		key = "1"
	var entries: Array = tables[key]
	var picked_id: String = weighted_pick(entries)
	for entry in entries:
		if str(entry["id"]) == picked_id:
			return entry
	return entries[0]


# --- アイテムテーブル ---

## ステージに対応するアイテムを重み付きで1つ選ぶ
func pick_item(stage: int) -> Dictionary:
	var config: Dictionary = get_config()
	var all_items: Array = config["item_table"]
	var available: Array = filter_by_stage(all_items, stage)
	if available.is_empty():
		return all_items[0]
	var picked_id: String = weighted_pick(available)
	for item in available:
		if str(item["id"]) == picked_id:
			return item
	return available[0]


# --- 宝箱配分 ---

## 宝箱の中身が知識かアイテムかを抽選
func roll_chest_type(has_unobtained_knowledge: bool) -> String:
	if not has_unobtained_knowledge:
		return "item"
	var config: Dictionary = get_config()
	var rate: float = float(config["chest_knowledge_rate"])
	if _rng.randf() < rate:
		return "knowledge"
	return "item"


# --- JSON読み込み ---

func _try_load_json() -> void:
	if not ResourceLoader.exists(CONFIG_PATH) and not FileAccess.file_exists(CONFIG_PATH):
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var loaded: Dictionary = json.data
		_merge_config(loaded)
	file.close()


func _merge_config(loaded: Dictionary) -> void:
	for key in loaded:
		_config[key] = loaded[key]


# --- デフォルト設定 ---

func _build_default_config() -> Dictionary:
	return {
		"chest_knowledge_rate": 0.6,
		"enemy_tables": _default_enemy_tables(),
		"item_table": _default_item_table(),
	}


func _default_enemy_tables() -> Dictionary:
	return {
		"1": [
			{"id": "wolf",  "name": "子狼", "value_min": 1, "value_max": 3, "attack": 2, "exp": 2, "ai": EnemyScript.AIPattern.CHASE, "weight": 50, "min_stage": 1},
			{"id": "boar",  "name": "猪",   "value_min": 3, "value_max": 6, "attack": 3, "exp": 4, "ai": EnemyScript.AIPattern.CHARGE, "weight": 30, "min_stage": 1},
			{"id": "bear",  "name": "熊",   "value_min": 5, "value_max": 10, "attack": 5, "exp": 8, "ai": EnemyScript.AIPattern.CHASE, "weight": 20, "min_stage": 1},
		],
		"2": [
			{"id": "scorpion", "name": "サソリ",   "value_min": 5,  "value_max": 12, "attack": 4,  "exp": 6,  "ai": EnemyScript.AIPattern.CHASE,  "weight": 40, "min_stage": 2},
			{"id": "snake",    "name": "砂蛇",     "value_min": 8,  "value_max": 15, "attack": 5,  "exp": 8,  "ai": EnemyScript.AIPattern.RANDOM, "weight": 35, "min_stage": 2},
			{"id": "demon_l",  "name": "下級悪魔", "value_min": 12, "value_max": 24, "attack": 7,  "exp": 12, "ai": EnemyScript.AIPattern.CHASE,  "weight": 25, "min_stage": 2},
		],
		"3": [
			{"id": "goblin",  "name": "ゴブリン", "value_min": 10, "value_max": 20, "attack": 6,  "exp": 10, "ai": EnemyScript.AIPattern.CHASE,       "weight": 40, "min_stage": 3},
			{"id": "golem",   "name": "ゴーレム", "value_min": 20, "value_max": 36, "attack": 10, "exp": 18, "ai": EnemyScript.AIPattern.SLOW_CHASE,  "weight": 30, "min_stage": 3},
			{"id": "demon_h", "name": "上位悪魔", "value_min": 25, "value_max": 50, "attack": 12, "exp": 25, "ai": EnemyScript.AIPattern.SMART_CHASE, "weight": 30, "min_stage": 3},
		],
		"4": [
			{"id": "soldier",   "name": "機械兵",             "value_min": 20, "value_max": 50,  "attack": 10, "exp": 20, "ai": EnemyScript.AIPattern.PATROL, "weight": 35, "min_stage": 4},
			{"id": "chimera",   "name": "キメラ",             "value_min": 30, "value_max": 64,  "attack": 14, "exp": 30, "ai": EnemyScript.AIPattern.RANDOM, "weight": 35, "min_stage": 4},
			{"id": "scientist", "name": "マッドサイエンティスト", "value_min": 50, "value_max": 100, "attack": 16, "exp": 40, "ai": EnemyScript.AIPattern.FLEE,   "weight": 30, "min_stage": 4},
		],
		"5": [
			{"id": "alien",     "name": "エイリアン",   "value_min": 50,  "value_max": 128, "attack": 15, "exp": 40, "ai": EnemyScript.AIPattern.SMART_CHASE, "weight": 40, "min_stage": 5},
			{"id": "blackhole", "name": "ブラックホール", "value_min": 100, "value_max": 200, "attack": 20, "exp": 60, "ai": EnemyScript.AIPattern.STATIONARY, "weight": 25, "min_stage": 5},
			{"id": "worm",      "name": "次元虫",       "value_min": 64,  "value_max": 150, "attack": 18, "exp": 50, "ai": EnemyScript.AIPattern.WARP,        "weight": 35, "min_stage": 5},
		],
	}


func _default_item_table() -> Array:
	return [
		# 回復系
		{"id": "herb",             "rarity": "common",    "weight": 40, "min_stage": 1},
		{"id": "upper_herb",       "rarity": "uncommon",  "weight": 25, "min_stage": 2},
		{"id": "panacea",          "rarity": "rare",      "weight": 10, "min_stage": 3},
		{"id": "wisdom_water",     "rarity": "common",    "weight": 40, "min_stage": 1},
		{"id": "awakening_water",  "rarity": "rare",      "weight": 10, "min_stage": 3},
		{"id": "elixir",           "rarity": "legendary", "weight": 3,  "min_stage": 4},
		# 戦闘補助系
		{"id": "even_powder",      "rarity": "common",    "weight": 30, "min_stage": 1},
		{"id": "odd_powder",       "rarity": "common",    "weight": 30, "min_stage": 1},
		{"id": "zero_scroll",      "rarity": "legendary", "weight": 3,  "min_stage": 3},
		{"id": "reverse_mirror",   "rarity": "uncommon",  "weight": 20, "min_stage": 2},
		{"id": "halving_sand",     "rarity": "uncommon",  "weight": 20, "min_stage": 2},
		# 探索系
		{"id": "map_piece",        "rarity": "common",    "weight": 35, "min_stage": 1},
		{"id": "clairvoyance",     "rarity": "uncommon",  "weight": 15, "min_stage": 2},
		{"id": "return_wing",      "rarity": "uncommon",  "weight": 20, "min_stage": 1},
		{"id": "warp_stone",       "rarity": "common",    "weight": 25, "min_stage": 2},
		# 特殊系
		{"id": "exp_book",         "rarity": "uncommon",  "weight": 15, "min_stage": 2},
		{"id": "skill_book",       "rarity": "rare",      "weight": 8,  "min_stage": 3},
		{"id": "slot_expansion",   "rarity": "rare",      "weight": 5,  "min_stage": 2},
	]
