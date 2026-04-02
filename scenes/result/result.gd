extends Control

## リザルト画面（プレースホルダ）
## 決定キーでタイトルへ戻る。

const GMS = preload("res://scripts/autoload/game_manager.gd")


func _ready() -> void:
	var label := get_node_or_null("ResultLabel") as Label
	if label:
		label.text = "RESULT\n\nスコア: 0\n\n(決定キーでタイトルへ)"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.change_state(GMS.State.TITLE)
