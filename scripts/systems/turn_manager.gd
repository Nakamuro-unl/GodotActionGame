extends Node

## ターン制の進行を管理する。
## プレイヤーアクション → 敵フェーズ → 環境フェーズ → ターン終了 のサイクルを制御。

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal phase_changed(phase: Phase)
signal player_phase_started()
signal enemy_phase_started()
signal environment_phase_started()
signal hp_regen_triggered()

enum Phase {
	PLAYER_INPUT,
	PLAYER_ACTION,
	ENEMY_ACTION,
	ENVIRONMENT,
	TURN_END,
}

const HP_REGEN_INTERVAL: int = 10

var turn_count: int = 0
var current_phase: Phase = Phase.PLAYER_INPUT


## プレイヤーがターン消費するアクションを実行した時に呼ぶ
func execute_player_action() -> void:
	if current_phase != Phase.PLAYER_INPUT:
		return

	turn_count += 1

	# プレイヤーアクションフェーズ
	_set_phase(Phase.PLAYER_ACTION)
	turn_started.emit(turn_count)

	# 敵フェーズ
	_set_phase(Phase.ENEMY_ACTION)
	enemy_phase_started.emit()

	# 環境フェーズ
	_set_phase(Phase.ENVIRONMENT)
	environment_phase_started.emit()
	_process_environment()

	# ターン終了
	_set_phase(Phase.TURN_END)
	turn_ended.emit(turn_count)

	# 次のプレイヤー入力待ちへ
	_set_phase(Phase.PLAYER_INPUT)
	player_phase_started.emit()


## ターン消費しないアクション（メニュー、足元確認等）
func execute_non_consuming_action() -> void:
	pass


func _set_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(phase)


func _process_environment() -> void:
	if turn_count % HP_REGEN_INTERVAL == 0:
		hp_regen_triggered.emit()
