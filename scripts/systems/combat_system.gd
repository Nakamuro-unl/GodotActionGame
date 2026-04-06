extends Node

## 戦闘システム。技の適用とダメージ計算を担当する。

const ES = preload("res://scripts/entities/enemy.gd")

## 技定義テーブル
## name: 表示名, mp_cost: MP消費, type: 計算タイプ, param: パラメータ
const SKILLS: Dictionary = {
	# 算術技（ステージ1）
	"plus_1":    {"name": "プラス1",       "mp_cost": 0, "type": "add",     "param": 1},
	"minus_1":   {"name": "マイナス1",     "mp_cost": 0, "type": "add",     "param": -1},
	"plus_3":    {"name": "プラス3",       "mp_cost": 1, "type": "add",     "param": 3},
	"minus_5":   {"name": "マイナス5",     "mp_cost": 2, "type": "add",     "param": -5},
	"plus_10":   {"name": "プラス10",      "mp_cost": 3, "type": "add",     "param": 10},
	"minus_10":  {"name": "マイナス10",    "mp_cost": 3, "type": "add",     "param": -10},
	# 乗除技（ステージ2）
	"double":    {"name": "ダブル",        "mp_cost": 3, "type": "mul",     "param": 2},
	"half":      {"name": "ハーフ",        "mp_cost": 3, "type": "div",     "param": 2},
	"triple":    {"name": "トリプル",      "mp_cost": 4, "type": "mul",     "param": 3},
	"third":     {"name": "サード",        "mp_cost": 4, "type": "div",     "param": 3},
	"mod4":      {"name": "モジュロ4",     "mp_cost": 3, "type": "mod",     "param": 4},
	# 関数技（ステージ3）
	"abs":       {"name": "アブソリュート", "mp_cost": 4, "type": "func",   "param": "abs"},
	"negate":    {"name": "ネゲート",      "mp_cost": 3, "type": "func",    "param": "negate"},
	"square":    {"name": "スクエア",      "mp_cost": 5, "type": "func",    "param": "square"},
	"sqrt":      {"name": "ルート",        "mp_cost": 5, "type": "func",    "param": "sqrt"},
	# 高等技（ステージ4）
	"derivative":  {"name": "デリバティブ",   "mp_cost": 6, "type": "func", "param": "derivative"},
	"integral":    {"name": "インテグラル",   "mp_cost": 6, "type": "func", "param": "integral"},
	"probability": {"name": "プロバビリティ", "mp_cost": 5, "type": "func", "param": "probability"},
	"log2":        {"name": "ログ",           "mp_cost": 6, "type": "func", "param": "log2"},
	# 究極技（ステージ5）
	"zero_vector": {"name": "ゼロベクトル",   "mp_cost": 15, "type": "func", "param": "zero_vector"},
	"topology":    {"name": "トポロジー",     "mp_cost": 10, "type": "func", "param": "topology"},
	"identity":    {"name": "アイデンティティ", "mp_cost": 8, "type": "func", "param": "identity"},
	"limit":       {"name": "リミット",       "mp_cost": 12, "type": "func", "param": "limit"},
	# 回数制限付き（ステージ4以降）
	"zero_mul":    {"name": "ゼロ乗算",     "mp_cost": 0, "type": "mul", "param": 0, "max_uses": 3},
	# 範囲攻撃（ステージ3以降）
	"linear_strike":  {"name": "一次関数",   "mp_cost": 4,  "type": "range", "range_func": "linear",      "range_damage": 5, "range_length": 8},
	"parabola_shot":  {"name": "二次関数",   "mp_cost": 6,  "type": "range", "range_func": "quadratic",   "range_damage": 3, "range_length": 6},
	"wave_attack":    {"name": "三角関数",   "mp_cost": 7,  "type": "range", "range_func": "sine",        "range_damage": 4, "range_length": 8},
	"circle_burst":   {"name": "円の方程式", "mp_cost": 8,  "type": "range", "range_func": "circle",      "range_damage": 3, "range_length": 2},
	"exponential_atk":{"name": "指数関数",   "mp_cost": 10, "type": "range", "range_func": "exponential", "range_damage": 0, "range_length": 5},
}


## 技を使用する
## 戻り値: {"success": bool, "mp_cost": int, "old_value": int, "new_value": int}
func use_skill(skill_id: String, player: Node, enemy: Node) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {"success": false, "mp_cost": 0, "old_value": 0, "new_value": 0}

	var skill: Dictionary = SKILLS[skill_id]
	var mp_cost: int = skill["mp_cost"]

	# 回数制限チェック
	if skill.has("max_uses"):
		if player.get_skill_remaining(skill_id) <= 0:
			return {"success": false, "mp_cost": 0, "old_value": enemy.value, "new_value": enemy.value}

	if not player.consume_mp(mp_cost):
		return {"success": false, "mp_cost": mp_cost, "old_value": enemy.value, "new_value": enemy.value}

	var old_value: int = enemy.value
	var new_value: int = _calculate_skill_effect(skill, enemy.value)
	enemy.set_value(new_value)

	# 回数制限の消費
	if skill.has("max_uses"):
		player.consume_skill_use(skill_id)

	return {"success": true, "mp_cost": mp_cost, "old_value": old_value, "new_value": new_value}


## 範囲攻撃を使用する
## enemies: フロア上の全敵リスト
## 戻り値: {success, hit_enemies: [{enemy, old_value, new_value}], cells: [Vector2i]}
func use_range_skill(skill_id: String, player: Node, enemies: Array, facing: Vector2i) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {"success": false, "hit_enemies": [], "cells": []}

	var skill: Dictionary = SKILLS[skill_id]
	if skill["type"] != "range":
		return {"success": false, "hit_enemies": [], "cells": []}

	var mp_cost: int = skill["mp_cost"]
	if not player.consume_mp(mp_cost):
		return {"success": false, "hit_enemies": [], "cells": []}

	var GC: GDScript = load("res://scripts/systems/graph_calculator.gd")
	var origin: Vector2i = player.grid_pos
	var length: int = int(skill["range_length"])
	var func_name: String = skill["range_func"]

	# 座標計算
	var cells: Array = []
	match func_name:
		"linear":
			cells = GC.linear(origin, facing, length)
		"quadratic":
			cells = GC.quadratic(origin, facing, length)
		"sine":
			cells = GC.sine(origin, facing, length, 1)
		"circle":
			cells = GC.circle(origin, length)
		"exponential":
			cells = GC.exponential(origin, facing, length)

	# ダメージ配列（指数関数は距離で変化）
	var dmg_list: Array = []
	if func_name == "exponential":
		dmg_list = GC.exponential_damage(length)
	else:
		for i in cells.size():
			dmg_list.append(int(skill["range_damage"]))

	# 各セルの敵に効果適用
	var hit_enemies: Array = []
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var dmg: int = dmg_list[i] if i < dmg_list.size() else int(skill["range_damage"])
		for enemy in enemies:
			if enemy.grid_pos == cell and enemy.state != 2:  # DEFEATED=2
				var old_val: int = enemy.value
				enemy.apply_value_change(-dmg)
				hit_enemies.append({"enemy": enemy, "old_value": old_val, "new_value": enemy.value})

	return {"success": true, "hit_enemies": hit_enemies, "cells": cells}


## 範囲攻撃の座標プレビューを取得（発動前の表示用）
func get_range_preview(skill_id: String, origin: Vector2i, facing: Vector2i) -> Array:
	if not SKILLS.has(skill_id):
		return []
	var skill: Dictionary = SKILLS[skill_id]
	if skill["type"] != "range":
		return []

	var GC: GDScript = load("res://scripts/systems/graph_calculator.gd")
	var length: int = int(skill["range_length"])
	match skill["range_func"]:
		"linear": return GC.linear(origin, facing, length)
		"quadratic": return GC.quadratic(origin, facing, length)
		"sine": return GC.sine(origin, facing, length, 1)
		"circle": return GC.circle(origin, length)
		"exponential": return GC.exponential(origin, facing, length)
	return []


## 技情報を取得
func get_skill_info(skill_id: String) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {}
	var skill: Dictionary = SKILLS[skill_id]
	return {
		"id": skill_id,
		"name": skill["name"],
		"mp_cost": skill["mp_cost"],
	}


## 回数制限付き技か判定
func is_limited_skill(skill_id: String) -> bool:
	if not SKILLS.has(skill_id):
		return false
	return SKILLS[skill_id].has("max_uses")


## 回数制限付き技の最大使用回数
func get_max_uses(skill_id: String) -> int:
	if not SKILLS.has(skill_id):
		return 0
	return int(SKILLS[skill_id].get("max_uses", 0))


## ダメージ計算（敵→プレイヤー）
func calculate_damage(enemy: Node, _player: Node) -> int:
	var raw: int = enemy.get_attack_damage()
	# TODO: プレイヤーの防御力を引く（現在は未実装）
	return maxi(raw, 1)


# --- Private ---

func _calculate_skill_effect(skill: Dictionary, current_value: int) -> int:
	var skill_type: String = skill["type"]
	var param = skill["param"]

	match skill_type:
		"add":
			return current_value + int(param)
		"mul":
			return current_value * int(param)
		"div":
			if int(param) == 0:
				return current_value
			# 整数除算（0方向への切捨て）
			return int(current_value) / int(param)
		"mod":
			if int(param) == 0:
				return current_value
			return int(current_value) % int(param)
		"func":
			return _apply_func(String(param), current_value)
	return current_value


func _apply_func(func_name: String, val: int) -> int:
	match func_name:
		"abs":
			return absi(val)
		"negate":
			return -val
		"square":
			return val * val
		"sqrt":
			if val < 0:
				return val  # 負の数にはsqrt適用不可
			return int(sqrt(float(val)))
		"derivative":
			# 桁数に変換
			if val == 0:
				return 1
			return _digit_count(absi(val))
		"integral":
			# 各桁の合計
			return _digit_sum(absi(val))
		"probability":
			# 50%で0化（テスト困難なため別途テスト）
			if randf() < 0.5:
				return 0
			return val
		"log2":
			if val <= 0:
				return val
			return int(log(float(val)) / log(2.0))
		"zero_vector":
			return 0
		"topology":
			return _nearest_prime(absi(val))
		"identity":
			if val == 0:
				return 0
			return 1  # val / val = 1
		"limit":
			# 半減（即時効果として1回分）
			return val / 2
	return val


func _digit_count(n: int) -> int:
	if n == 0:
		return 1
	var count: int = 0
	var v: int = n
	while v > 0:
		count += 1
		v /= 10
	return count


func _digit_sum(n: int) -> int:
	var total: int = 0
	var v: int = n
	while v > 0:
		total += v % 10
		v /= 10
	return total


func _nearest_prime(n: int) -> int:
	if n <= 2:
		return 2
	if _is_prime(n):
		return n
	var lower: int = n - 1
	var upper: int = n + 1
	while true:
		if lower >= 2 and _is_prime(lower):
			if _is_prime(upper):
				# 距離が同じなら小さい方
				if n - lower <= upper - n:
					return lower
				return upper
			return lower
		if _is_prime(upper):
			return upper
		lower -= 1
		upper += 1
	return n


func _is_prime(n: int) -> bool:
	if n < 2:
		return false
	if n < 4:
		return true
	if n % 2 == 0 or n % 3 == 0:
		return false
	var i: int = 5
	while i * i <= n:
		if n % i == 0 or n % (i + 2) == 0:
			return false
		i += 6
	return true
