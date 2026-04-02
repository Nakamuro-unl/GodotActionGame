extends Control

## インゲーム画面（プレースホルダ）
## 仮実装: Escキーでリザルトへ遷移する。

const GMS = preload("res://scripts/autoload/game_manager.gd")


func _ready() -> void:
	var label := get_node_or_null("StatusLabel") as Label
	if label:
		label.text = "IN GAME\n\n(Escキーでリザルトへ)"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.change_state(GMS.State.RESULT)
