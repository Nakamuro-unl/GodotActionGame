extends CanvasLayer

## 汎用画面エフェクト。フェード/フラッシュ/テキストポップアップ。

signal fade_completed()

var _is_playing: bool = false


func _ready() -> void:
	visible = false


func is_playing() -> bool:
	return _is_playing


## フェードアウト→フェードイン（階段遷移等）
func fade_transition(duration: float = 0.6) -> void:
	visible = true
	_is_playing = true
	$ColorRect.color = Color(0, 0, 0, 0)
	$Label.text = ""

	var tween: Tween = create_tween()
	tween.tween_property($ColorRect, "color", Color(0, 0, 0, 1), duration * 0.4)
	tween.tween_interval(duration * 0.2)
	tween.tween_property($ColorRect, "color", Color(0, 0, 0, 0), duration * 0.4)
	tween.tween_callback(func() -> void:
		_is_playing = false
		visible = false
		fade_completed.emit()
	)


## レベルアップ演出（白フラッシュ+テキスト）
func level_up_effect(new_level: int) -> void:
	visible = true
	_is_playing = true
	$ColorRect.color = Color(0, 0, 0, 0)
	$Label.text = ""

	var tween: Tween = create_tween()
	tween.tween_property($ColorRect, "color", Color(1, 1, 1, 0.6), 0.08)
	tween.tween_property($ColorRect, "color", Color(1, 1, 0.8, 0.3), 0.08)
	tween.tween_callback(func() -> void: $Label.text = "LEVEL UP! Lv.%d" % new_level)
	tween.tween_property($ColorRect, "color", Color(0, 0, 0, 0), 0.4)
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		$Label.text = ""
		_is_playing = false
		visible = false
	)


## コンボ表示（画面中央にポップアップ）
func combo_popup(combo_count: int) -> void:
	visible = true
	$ColorRect.color = Color(0, 0, 0, 0)
	$Label.text = "COMBO x%d!" % combo_count
	$Label.modulate = Color(1, 0.9, 0.2, 1)

	var tween: Tween = create_tween()
	tween.tween_property($Label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		$Label.text = ""
		$Label.modulate = Color.WHITE
		visible = false
	)
