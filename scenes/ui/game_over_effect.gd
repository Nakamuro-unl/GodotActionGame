extends CanvasLayer

## ゲームオーバー演出。ゼルダ風の赤フラッシュ→暗転→テキスト表示。

signal finished()

var _is_playing: bool = false


func _ready() -> void:
	visible = false


func is_playing() -> bool:
	return _is_playing


func play() -> void:
	visible = true
	_is_playing = true
	$Label.text = ""
	$ColorRect.color = Color(0, 0, 0, 0)

	var tween: Tween = create_tween()

	# 赤フラッシュ x6回（ファミコンゼルダ風チカチカ）
	for i in 6:
		tween.tween_property($ColorRect, "color", Color(0.8, 0.0, 0.0, 0.7), 0.08)
		tween.tween_property($ColorRect, "color", Color(0, 0, 0, 0), 0.08)

	# 白フラッシュ x3
	for i in 3:
		tween.tween_property($ColorRect, "color", Color(1, 1, 1, 0.8), 0.06)
		tween.tween_property($ColorRect, "color", Color(0, 0, 0, 0), 0.06)

	# 暗転
	tween.tween_property($ColorRect, "color", Color(0, 0, 0, 1.0), 0.5)

	# GAME OVER テキスト表示
	tween.tween_callback(func() -> void: $Label.text = "GAME OVER")
	tween.tween_interval(2.0)

	tween.tween_callback(func() -> void:
		_is_playing = false
		finished.emit()
	)
