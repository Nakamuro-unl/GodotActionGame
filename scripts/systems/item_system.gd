extends Node

## アイテムの効果定義と使用ロジック。

const ES = preload("res://scripts/entities/enemy.gd")

## type: "heal_hp", "heal_mp", "heal_both", "combat", "explore", "special"
const ITEM_DB: Dictionary = {
	# 回復系
	"herb":             {"name": "薬草",         "type": "heal_hp",   "value": 10,  "description": "HPを10回復する"},
	"upper_herb":       {"name": "上薬草",       "type": "heal_hp",   "value": 30,  "description": "HPを30回復する"},
	"panacea":          {"name": "万能薬",       "type": "heal_hp",   "value": 999, "description": "HPを全回復する"},
	"wisdom_water":     {"name": "知恵の水",     "type": "heal_mp",   "value": 5,   "description": "MPを5回復する"},
	"awakening_water":  {"name": "覚醒の水",     "type": "heal_mp",   "value": 999, "description": "MPを全回復する"},
	"elixir":           {"name": "エリクサー",   "type": "heal_both", "value": 999, "description": "HP/MPを全回復する"},
	# 戦闘補助系
	"even_powder":      {"name": "偶数の粉",     "type": "combat", "effect": "even",    "description": "敵の数値を最寄りの偶数にする"},
	"odd_powder":       {"name": "奇数の粉",     "type": "combat", "effect": "odd",     "description": "敵の数値を最寄りの奇数にする"},
	"zero_scroll":      {"name": "零の巻物",     "type": "combat", "effect": "zero",    "description": "敵の数値を0にする"},
	"reverse_mirror":   {"name": "反転の鏡",     "type": "combat", "effect": "reverse", "description": "敵の数値の符号を反転する"},
	"halving_sand":     {"name": "半減の砂",     "type": "combat", "effect": "halve",   "description": "敵の数値を半分にする"},
	# 探索系
	"map_piece":        {"name": "マップの欠片",   "type": "explore", "effect": "reveal_map",  "description": "現在フロアの地図を表示する"},
	"clairvoyance":     {"name": "千里眼の水晶",   "type": "explore", "effect": "reveal_all",  "description": "敵と宝箱の位置を表示する"},
	"return_wing":      {"name": "帰還の翼",       "type": "explore", "effect": "return",      "description": "フロアの入口に戻る"},
	"warp_stone":       {"name": "ワープの石",     "type": "explore", "effect": "warp",        "description": "ランダムな部屋に移動する"},
	# 特殊系
	"exp_book":         {"name": "経験の書",       "type": "special", "effect": "exp",          "description": "経験値を50獲得する"},
	"skill_book":       {"name": "技の書",         "type": "special", "effect": "skill",        "description": "未獲得の知識を1つ獲得する"},
	"slot_expansion":   {"name": "スロット拡張",   "type": "special", "effect": "slot",         "description": "技スロットを1つ追加する"},
	# 偽アイテム（使用するまで本物と区別できない）
	"fake_herb":        {"name": "薬草",           "type": "fake", "real_effect": "poison",     "description": "HPを10回復する", "fake_desc": "毒薬草だった! HP -10"},
	"fake_water":       {"name": "知恵の水",       "type": "fake", "real_effect": "confuse",    "description": "MPを5回復する",  "fake_desc": "混乱の水だった! 3ターン操作反転"},
	"fake_scroll":      {"name": "零の巻物",       "type": "fake", "real_effect": "curse",      "description": "敵の数値を0にする", "fake_desc": "呪いの巻物だった! MPが0に"},
}


## アイテムを使用する
## player: プレイヤーノード
## item_index: items配列のインデックス
## target_enemy: 戦闘補助系の対象敵（なければnull）
## 戻り値: {"success": bool, "message": String, "item_id": String}
## session: 探索系アイテムでセッションにアクセスするため（nullならスキップ）
func use_item(player: Node, item_index: int, target_enemy: Node, session: Node = null) -> Dictionary:
	if item_index < 0 or item_index >= player.items.size():
		return {"success": false, "message": "", "item_id": ""}

	var item_id: String = player.items[item_index]
	if not ITEM_DB.has(item_id):
		return {"success": false, "message": "不明なアイテム", "item_id": item_id}

	var info: Dictionary = ITEM_DB[item_id]
	var item_type: String = info["type"]

	if item_type == "combat" and target_enemy == null:
		return {"success": false, "message": "対象の敵がいない", "item_id": item_id}

	var msg: String = _apply_effect(player, target_enemy, item_id, info, session)

	player.remove_item(item_index)

	return {"success": true, "message": msg, "item_id": item_id}


func _apply_effect(player: Node, enemy: Node, item_id: String, info: Dictionary, session: Node = null) -> String:
	var item_type: String = info["type"]

	match item_type:
		"heal_hp":
			player.heal_hp(int(info["value"]))
			return "%s を使った! HPが回復した" % info["name"]
		"heal_mp":
			player.heal_mp(int(info["value"]))
			return "%s を使った! MPが回復した" % info["name"]
		"heal_both":
			player.heal_hp(int(info["value"]))
			player.heal_mp(int(info["value"]))
			return "%s を使った! HP/MPが全回復した" % info["name"]
		"combat":
			return _apply_combat_effect(enemy, info)
		"special":
			return _apply_special_effect(player, info)
		"explore":
			return _apply_explore_effect(player, info, session)
		"fake":
			return _apply_fake_effect(player, info)

	return ""


func _apply_combat_effect(enemy: Node, info: Dictionary) -> String:
	var effect: String = info["effect"]
	match effect:
		"even":
			var v: int = enemy.value
			if v % 2 != 0:
				enemy.set_value(v + 1 if v > 0 else v - 1)
			return "偶数の粉! 数値: %d -> %d" % [v, enemy.value]
		"odd":
			var v: int = enemy.value
			if v % 2 == 0:
				enemy.set_value(v + 1 if v >= 0 else v - 1)
			return "奇数の粉! 数値: %d -> %d" % [v, enemy.value]
		"zero":
			var v: int = enemy.value
			enemy.set_value(0)
			return "零の巻物! 数値: %d -> 0" % v
		"reverse":
			var v: int = enemy.value
			enemy.set_value(-v)
			return "反転の鏡! 数値: %d -> %d" % [v, enemy.value]
		"halve":
			var v: int = enemy.value
			enemy.set_value(v / 2)
			return "半減の砂! 数値: %d -> %d" % [v, enemy.value]
	return ""


func _apply_fake_effect(player: Node, info: Dictionary) -> String:
	var effect: String = info["real_effect"]
	match effect:
		"poison":
			player.take_damage(10)
			return info["fake_desc"]
		"confuse":
			# 混乱状態（将来的にステータス異常として実装）
			return info["fake_desc"]
		"curse":
			player.mp = 0
			return info["fake_desc"]
	return "偽物だった!"


## 鑑定: 偽アイテムかどうか判定
static func is_fake_item(item_id: String) -> bool:
	if not ITEM_DB.has(item_id):
		return false
	return ITEM_DB[item_id]["type"] == "fake"


## 鑑定済みの名前を返す
static func get_identified_name(item_id: String) -> String:
	if not ITEM_DB.has(item_id):
		return item_id
	var info: Dictionary = ITEM_DB[item_id]
	if info["type"] == "fake":
		match info["real_effect"]:
			"poison": return "毒薬草"
			"confuse": return "混乱の水"
			"curse": return "呪いの巻物"
	return info["name"]


func _apply_explore_effect(player: Node, info: Dictionary, session: Node) -> String:
	var effect: String = info["effect"]
	match effect:
		"reveal_map":
			if session and session.minimap:
				session.minimap.reveal_all()
			return "マップの欠片! フロア全体が見えるようになった"
		"reveal_all":
			if session and session.minimap:
				session.minimap.reveal_all()
			return "千里眼! 全ての位置が見えるようになった"
		"return":
			if session:
				var start: Vector2i = session.map_generator.get_player_start()
				player.grid_pos = start
			return "帰還の翼! 入口に戻った"
		"warp":
			if session:
				var rooms: Array = session.map_generator.get_rooms()
				if rooms.size() > 1:
					var room: Rect2i = rooms[randi() % rooms.size()]
					var x: int = room.position.x + room.size.x / 2
					var y: int = room.position.y + room.size.y / 2
					player.grid_pos = Vector2i(x, y)
			return "ワープの石! 別の部屋に移動した"
	return "%s を使った!" % info["name"]


func _apply_special_effect(player: Node, info: Dictionary) -> String:
	var effect: String = info["effect"]
	match effect:
		"exp":
			player.gain_exp(50)
			return "経験の書! 経験値+50"
		"skill":
			return "技の書を使った!"
		"slot":
			return "スロット拡張を使った!"
	return ""
