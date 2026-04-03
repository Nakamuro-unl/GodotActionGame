extends RefCounted

## InGameシーンで使用する定数データ（アイコンマップ、アイテム定義）。

## 知識IDからアイコンスプライト名（各知識に専用アイコン）
const KNOWLEDGE_ICON_MAP: Dictionary = {
	# ステージ1: 石器時代
	"K-101": "math_natural_num",  # 自然数の定義
	"K-102": "math_addition",     # 加法
	"K-103": "math_subtraction",  # 減法
	"K-104": "math_zero",         # 零の発見
	"K-105": "math_negative",     # 負の数
	"K-106": "math_number_line",  # 数直線
	# ステージ2: 古代文明
	"K-201": "math_multiply",     # 乗法
	"K-202": "math_division",     # 除法
	"K-203": "math_modulo",       # 剰余
	"K-204": "math_fraction",     # 分数の定義
	"K-205": "math_multiple",     # 倍数の定理
	"K-206": "math_divisor",      # 約数
	# ステージ3: 中世
	"K-301": "math_absolute",     # 絶対値
	"K-302": "math_negate",       # 符号反転
	"K-303": "math_square",       # 平方
	"K-304": "math_sqrt",         # 平方根
	"K-305": "math_pythagorean",  # ピタゴラスの定理
	"K-306": "math_equation",     # 一次方程式
	# ステージ4: 近代
	"K-401": "math_derivative",   # 微分
	"K-402": "math_integral",     # 積分
	"K-403": "math_probability",  # 確率
	"K-404": "math_log",          # 対数
	"K-405": "math_expected",     # 期待値の定理
	"K-406": "math_limit",        # 極限
	# ステージ5: 宇宙
	"K-501": "math_vector",       # ベクトル
	"K-502": "math_matrix",       # 行列
	"K-503": "math_identity",     # 恒等写像
	"K-504": "math_zero_vector",  # ゼロベクトル
	"K-505": "math_topology",     # 位相変換
	"K-506": "math_infinity",     # 無限の定義
}

const ITEM_ICON_MAP: Dictionary = {
	"herb": "item_herb",
	"upper_herb": "item_upper_herb",
	"panacea": "item_panacea",
	"wisdom_water": "item_wisdom_water",
	"awakening_water": "item_awakening_water",
	"elixir": "item_elixir",
	"even_powder": "item_even_powder",
	"odd_powder": "item_odd_powder",
	"zero_scroll": "item_zero_scroll",
	"reverse_mirror": "item_reverse_mirror",
	"halving_sand": "item_halving_sand",
	"map_piece": "item_map_piece",
	"clairvoyance": "item_clairvoyance",
	"return_wing": "item_return_wing",
	"warp_stone": "item_warp_stone",
	"exp_book": "item_exp_book",
	"skill_book": "item_skill_book",
	"slot_expansion": "item_slot_expansion",
}

const ITEM_NAMES: Dictionary = {
	"herb": "薬草",
	"upper_herb": "上薬草",
	"panacea": "万能薬",
	"wisdom_water": "知恵の水",
	"awakening_water": "覚醒の水",
	"elixir": "エリクサー",
	"even_powder": "偶数の粉",
	"odd_powder": "奇数の粉",
	"zero_scroll": "零の巻物",
	"reverse_mirror": "反転の鏡",
	"halving_sand": "半減の砂",
	"map_piece": "マップの欠片",
	"clairvoyance": "千里眼の水晶",
	"return_wing": "帰還の翼",
	"warp_stone": "ワープの石",
	"exp_book": "経験の書",
	"skill_book": "技の書",
	"slot_expansion": "スロット拡張",
}

const ITEM_DESCS: Dictionary = {
	"herb": "HPを10回復する",
	"upper_herb": "HPを30回復する",
	"panacea": "HPを全回復する",
	"wisdom_water": "MPを5回復する",
	"awakening_water": "MPを全回復する",
	"elixir": "HP/MPを全回復する",
	"even_powder": "敵の数値を最寄りの偶数にする",
	"odd_powder": "敵の数値を最寄りの奇数にする",
	"zero_scroll": "敵の数値を0にする",
	"reverse_mirror": "敵の数値の符号を反転する",
	"halving_sand": "敵の数値を半分にする",
	"map_piece": "現在フロアの地図を表示する",
	"clairvoyance": "敵と宝箱の位置を表示する",
	"return_wing": "フロアの入口に戻る",
	"warp_stone": "ランダムな部屋に移動する",
	"exp_book": "経験値を50獲得する",
	"skill_book": "未獲得の知識を1つ獲得する",
	"slot_expansion": "技スロットを1つ追加する",
}


static func get_icon_path(sprite_name: String) -> String:
	if sprite_name == "":
		return ""
	return "res://assets/sprites/%s.png" % sprite_name
