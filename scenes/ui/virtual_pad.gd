extends CanvasLayer

## バーチャルパッド。モバイル向けタッチ操作。
## 十字キー（左側）とアクションボタン（右側）を提供する。

signal direction_pressed(direction: Vector2i)
signal face_pressed(direction: Vector2i)
signal skill_pressed(slot_index: int)
signal wait_pressed()
signal interact_pressed()
signal menu_pressed()
signal item_pressed()

var _face_mode: bool = false


func _ready() -> void:
	_connect_dpad("DPad/Up", Vector2i.UP)
	_connect_dpad("DPad/Down", Vector2i.DOWN)
	_connect_dpad("DPad/Left", Vector2i.LEFT)
	_connect_dpad("DPad/Right", Vector2i.RIGHT)

	$ModeButton.pressed.connect(_on_mode_toggle)
	_update_mode_label()

	for i in 6:
		var btn: Button = get_node_or_null("Skills/Skill%d" % (i + 1))
		if btn:
			btn.pressed.connect(_on_skill_pressed.bind(i))

	$Actions/WaitButton.pressed.connect(func() -> void: wait_pressed.emit())
	$Actions/InteractButton.pressed.connect(func() -> void: interact_pressed.emit())
	$Actions/ItemButton.pressed.connect(func() -> void: item_pressed.emit())
	$Actions/MenuButton.pressed.connect(func() -> void: menu_pressed.emit())


func _connect_dpad(path: String, direction: Vector2i) -> void:
	var btn: Button = get_node_or_null(path)
	if btn:
		btn.pressed.connect(_on_dpad_pressed.bind(direction))


func _on_dpad_pressed(direction: Vector2i) -> void:
	if _face_mode:
		face_pressed.emit(direction)
	else:
		direction_pressed.emit(direction)


func _on_mode_toggle() -> void:
	_face_mode = not _face_mode
	_update_mode_label()


func _update_mode_label() -> void:
	if _face_mode:
		$ModeButton.text = "転換"
	else:
		$ModeButton.text = "移動"


func _on_skill_pressed(slot_index: int) -> void:
	skill_pressed.emit(slot_index)


## 技スロットの表示名とアイコンを更新する
func update_skill_labels(names: Array[String], icon_paths: Array[String] = []) -> void:
	for i in mini(names.size(), 6):
		var btn: Button = get_node_or_null("Skills/Skill%d" % (i + 1))
		if btn:
			btn.text = names[i]
			# アイコン設定
			if i < icon_paths.size() and icon_paths[i] != "":
				if ResourceLoader.exists(icon_paths[i]):
					btn.icon = load(icon_paths[i])
				else:
					btn.icon = null
			else:
				btn.icon = null
