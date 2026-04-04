extends Node

## スコアの記録・算出・ランキング管理を担当する。

const KILL_MULTIPLIER: int = 10
const FLOOR_SCORE: int = 1000
const BOSS_BONUS: int = 5000
const KNOWLEDGE_BONUS: int = 300
const COMBO_BASE: int = 150
const HP_BONUS_MULTIPLIER: int = 50
const MP_BONUS_MULTIPLIER: int = 30
const TURN_PENALTY_RATE: int = 1
const GHOST_PENALTY: int = 30
const MAX_RANKING: int = 10

var total_kills: int = 0
var kill_score: int = 0
var combo_count: int = 0
var max_combo: int = 0
var total_turns: int = 0
var ghost_count: int = 0
var floors_cleared: int = 0
var bosses_killed: int = 0
var knowledge_count: int = 0

# コンボボーナスの累計（リセットされた過去コンボ分を含む）
var _combo_bonus_banked: int = 0


## 通常敵の撃破を記録
func register_kill(exp_reward: int) -> void:
	total_kills += 1
	kill_score += exp_reward * KILL_MULTIPLIER


## ボス撃破を記録
func register_boss_kill(exp_reward: int) -> void:
	bosses_killed += 1
	total_kills += 1
	kill_score += exp_reward * KILL_MULTIPLIER


## ぴったり撃破（コンボ加算）
func register_perfect_kill() -> void:
	combo_count += 1
	if combo_count > max_combo:
		max_combo = combo_count


## 幽霊化（コンボリセット + ペナルティ加算）
func register_ghost() -> void:
	ghost_count += 1
	_bank_current_combo()
	combo_count = 0


## フロアクリア
func register_floor_cleared() -> void:
	floors_cleared += 1


## ターン経過
func register_turn() -> void:
	total_turns += 1


## 知識獲得
func register_knowledge() -> void:
	knowledge_count += 1


## コンボボーナスを取得（過去の確定分 + 現在のコンボ分）
func get_combo_bonus() -> int:
	return _combo_bonus_banked + _calc_combo_value(combo_count)


## 最終スコアを算出する
## cleared: クリアしたか, remaining_hp: 残HP, remaining_mp: 残MP
func calculate_final(cleared: bool, remaining_hp: int, remaining_mp: int) -> Dictionary:
	var floor_s: int = floors_cleared * FLOOR_SCORE
	var boss_s: int = bosses_killed * BOSS_BONUS
	var knowledge_s: int = knowledge_count * KNOWLEDGE_BONUS
	var combo_s: int = get_combo_bonus()
	var hp_s: int = remaining_hp * HP_BONUS_MULTIPLIER if cleared else 0
	var mp_s: int = remaining_mp * MP_BONUS_MULTIPLIER if cleared else 0
	var turn_p: int = -(total_turns * TURN_PENALTY_RATE)
	var ghost_p: int = -(ghost_count * GHOST_PENALTY)

	var total: int = kill_score + floor_s + boss_s + knowledge_s + combo_s + hp_s + mp_s + turn_p + ghost_p
	total = maxi(total, 0)

	return {
		"kill_score": kill_score,
		"floor_score": floor_s,
		"boss_bonus": boss_s,
		"knowledge_bonus": knowledge_s,
		"combo_bonus": combo_s,
		"hp_bonus": hp_s,
		"mp_bonus": mp_s,
		"turn_penalty": turn_p,
		"ghost_penalty": ghost_p,
		"total": total,
	}


## ランキングエントリを生成
func create_ranking_entry(result: Dictionary, seed_value: int, cleared: bool = false) -> Dictionary:
	return {
		"score": result["total"],
		"floor_reached": floors_cleared,
		"enemies_defeated": total_kills,
		"max_combo": max_combo,
		"knowledge_count": knowledge_count,
		"total_turns": total_turns,
		"cleared": cleared,
		"seed": seed_value,
		"date": Time.get_datetime_string_from_system(),
	}


## ランキングにエントリを追加（ソート済み、最大10件）
func add_to_ranking(ranking: Array, entry: Dictionary) -> void:
	ranking.append(entry)
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	while ranking.size() > MAX_RANKING:
		ranking.pop_back()


# --- Private ---

func _bank_current_combo() -> void:
	_combo_bonus_banked += _calc_combo_value(combo_count)


func _calc_combo_value(n: int) -> int:
	# 100 * (1 + 2 + ... + n) = 100 * n * (n+1) / 2
	return COMBO_BASE * n * (n + 1) / 2
