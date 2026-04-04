extends Node

## 数学知識の獲得・管理・技連携を担当する。
## 宝箱から獲得した知識は図鑑に記録され、技やフィールド効果として使用可能になる。

signal knowledge_acquired(id: String)

## 知識データベース
## category: definition(定義), theorem(定理), formula(公式)
## skill_id: 装備可能な技ID（公式・定理のみ）
## field_effect: フィールド効果ID
## passive: パッシブ効果ID
const KNOWLEDGE_DB: Dictionary = {
	# ステージ1: 石器時代
	"K-101": {"name": "自然数の定義",  "category": "definition", "stage": 1, "passive": "show_enemy_values"},
	"K-102": {"name": "加法",         "category": "formula",    "stage": 1, "skill_id": "plus_1",   "field_effect": "add_weight"},
	"K-103": {"name": "減法",         "category": "formula",    "stage": 1, "skill_id": "minus_1",  "field_effect": "sub_weight"},
	"K-104": {"name": "零の発見",     "category": "theorem",    "stage": 1, "field_effect": "void_wall_pass"},
	"K-105": {"name": "負の数",       "category": "definition", "stage": 1, "passive": "ghost_skill_enable", "field_effect": "ice_melt"},
	"K-106": {"name": "数直線",       "category": "definition", "stage": 1, "passive": "show_value_color",   "field_effect": "show_hidden_path"},
	"K-107": {"name": "繰り上がり",   "category": "formula",    "stage": 1, "skill_id": "plus_3"},
	"K-108": {"name": "繰り下がり",   "category": "formula",    "stage": 1, "skill_id": "minus_5"},
	"K-109": {"name": "十進法",       "category": "formula",    "stage": 1, "skill_id": "plus_10"},
	"K-110": {"name": "補数",         "category": "formula",    "stage": 1, "skill_id": "minus_10"},
	# ステージ2: 古代文明
	"K-201": {"name": "乗法",         "category": "formula",    "stage": 2, "skill_id": "double",   "field_effect": "multiply_object"},
	"K-202": {"name": "除法",         "category": "formula",    "stage": 2, "skill_id": "half",     "field_effect": "divide_object"},
	"K-203": {"name": "剰余",         "category": "formula",    "stage": 2, "skill_id": "mod4",     "field_effect": "remainder_key"},
	"K-204": {"name": "分数の定義",   "category": "definition", "stage": 2, "passive": "show_fraction"},
	"K-205": {"name": "倍数の定理",   "category": "theorem",    "stage": 2, "skill_id": "double"},
	"K-206": {"name": "約数",         "category": "definition", "stage": 2, "passive": "show_divisors",     "field_effect": "decode_door"},
	# ステージ3: 中世
	"K-301": {"name": "絶対値",       "category": "formula",    "stage": 3, "skill_id": "abs",      "field_effect": "negate_trap"},
	"K-302": {"name": "符号反転",     "category": "formula",    "stage": 3, "skill_id": "negate",   "field_effect": "gravity_flip"},
	"K-303": {"name": "平方",         "category": "formula",    "stage": 3, "skill_id": "square",   "field_effect": "enlarge_stone"},
	"K-304": {"name": "平方根",       "category": "formula",    "stage": 3, "skill_id": "sqrt",     "field_effect": "shrink_obstacle"},
	"K-305": {"name": "ピタゴラスの定理", "category": "theorem", "stage": 3, "skill_id": "sqrt",    "field_effect": "diagonal_shortcut"},
	"K-306": {"name": "一次方程式",   "category": "theorem",    "stage": 3,                          "field_effect": "equation_door"},
	# ステージ4: 近代
	"K-401": {"name": "微分",         "category": "formula",    "stage": 4, "skill_id": "derivative", "field_effect": "detect_speed"},
	"K-402": {"name": "積分",         "category": "formula",    "stage": 4, "skill_id": "integral",   "field_effect": "connect_platforms"},
	"K-403": {"name": "確率",         "category": "formula",    "stage": 4, "skill_id": "probability", "field_effect": "random_door"},
	"K-404": {"name": "対数",         "category": "formula",    "stage": 4, "skill_id": "log2",       "field_effect": "control_exponential"},
	"K-405": {"name": "期待値の定理", "category": "theorem",    "stage": 4,                            "field_effect": "show_optimal_path"},
	"K-406": {"name": "極限",         "category": "theorem",    "stage": 4, "skill_id": "limit",      "field_effect": "finite_corridor"},
	"K-407": {"name": "零化写像",     "category": "theorem",    "stage": 4, "skill_id": "zero_mul"},
	# ステージ5: 宇宙
	"K-501": {"name": "ベクトル",     "category": "definition", "stage": 5, "passive": "ranged_attack"},
	"K-502": {"name": "行列",         "category": "formula",    "stage": 5, "skill_id": "zero_vector", "field_effect": "transform_room"},
	"K-503": {"name": "恒等写像",     "category": "theorem",    "stage": 5, "skill_id": "identity"},
	"K-504": {"name": "ゼロベクトル", "category": "theorem",    "stage": 5, "skill_id": "zero_vector", "field_effect": "clear_all_obstacles"},
	"K-505": {"name": "位相変換",     "category": "formula",    "stage": 5, "skill_id": "topology",    "field_effect": "warp_space"},
	"K-506": {"name": "無限の定義",   "category": "definition", "stage": 5, "passive": "mp_half_cost",  "field_effect": "final_door"},
}

var _acquired: Dictionary = {}


# --- 獲得 ---

func acquire(id: String) -> bool:
	if not KNOWLEDGE_DB.has(id):
		return false
	if _acquired.has(id):
		return false
	_acquired[id] = true
	knowledge_acquired.emit(id)
	return true


func is_acquired(id: String) -> bool:
	return _acquired.has(id)


# --- カウント ---

func get_acquired_count() -> int:
	return _acquired.size()


func get_total_count() -> int:
	return KNOWLEDGE_DB.size()


func get_collection_rate() -> float:
	if KNOWLEDGE_DB.size() == 0:
		return 0.0
	return float(_acquired.size()) / float(KNOWLEDGE_DB.size()) * 100.0


# --- 情報取得 ---

func get_info(id: String) -> Dictionary:
	if not KNOWLEDGE_DB.has(id):
		return {}
	var data: Dictionary = KNOWLEDGE_DB[id].duplicate()
	data["id"] = id
	return data


func get_by_stage(stage: int) -> Array:
	var result: Array = []
	for id in KNOWLEDGE_DB:
		var data: Dictionary = KNOWLEDGE_DB[id]
		if data["stage"] == stage:
			var entry: Dictionary = data.duplicate()
			entry["id"] = id
			result.append(entry)
	return result


# --- 技連携 ---

func get_equippable_skills() -> Array:
	var result: Array = []
	for id in _acquired:
		var data: Dictionary = KNOWLEDGE_DB[id]
		if data.has("skill_id") and data["skill_id"] != "":
			result.append({"knowledge_id": id, "skill_id": data["skill_id"], "name": data["name"]})
	return result


# --- フィールド効果 ---

func get_active_field_effects() -> Array:
	var result: Array = []
	for id in _acquired:
		var data: Dictionary = KNOWLEDGE_DB[id]
		if data.has("field_effect") and data["field_effect"] != "":
			result.append(data["field_effect"])
	return result


# --- パッシブ効果 ---

func get_active_passives() -> Array:
	var result: Array = []
	for id in _acquired:
		var data: Dictionary = KNOWLEDGE_DB[id]
		if data.has("passive") and data["passive"] != "":
			result.append(data["passive"])
	return result


# --- 宝箱ドロップ ---

func get_random_unobtained(current_stage: int) -> String:
	var candidates: Array = []
	for id in KNOWLEDGE_DB:
		if _acquired.has(id):
			continue
		var data: Dictionary = KNOWLEDGE_DB[id]
		if data["stage"] <= current_stage:
			candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]
