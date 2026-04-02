extends Control

## あそびかた画面（プレースホルダ）
## Escキーでタイトルへ戻る。

const GMS = preload("res://scripts/autoload/game_manager.gd")


func _ready() -> void:
	var label := get_node_or_null("HowToPlayLabel") as Label
	if label:
		label.text = "あそびかた\n\n(準備中)\n\n(Escキーでタイトルへ)"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.change_state(GMS.State.TITLE)
