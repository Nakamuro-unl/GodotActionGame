extends Control

## せってい画面。BGM/SE音量の調整。

const GMS = preload("res://scripts/autoload/game_manager.gd")

var _cursor: int = 0
var _se_volume: int = 80
var _bgm_volume: int = 80

const ITEMS: Array[String] = ["SE音量", "BGM音量", "戻る"]


func _ready() -> void:
	_load_settings()
	_update_display()
	$BackButton.pressed.connect(_go_back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cursor = (_cursor - 1 + ITEMS.size()) % ITEMS.size()
		_update_display()
	elif event.is_action_pressed("ui_down"):
		_cursor = (_cursor + 1) % ITEMS.size()
		_update_display()
	elif event.is_action_pressed("ui_left"):
		_adjust_value(-10)
	elif event.is_action_pressed("ui_right"):
		_adjust_value(10)
	elif event.is_action_pressed("ui_accept"):
		if _cursor == 2:
			_go_back()
	elif event.is_action_pressed("ui_cancel"):
		_go_back()


func _adjust_value(delta: int) -> void:
	match _cursor:
		0:
			_se_volume = clampi(_se_volume + delta, 0, 100)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_se_volume / 100.0))
		1:
			_bgm_volume = clampi(_bgm_volume + delta, 0, 100)
	_update_display()


func _update_display() -> void:
	var label: Label = get_node_or_null("SettingsLabel")
	if label == null:
		return
	var text: String = "=== せってい ===\n\n"
	for i in ITEMS.size():
		var prefix: String = "> " if i == _cursor else "  "
		match i:
			0:
				text += "%sSE音量:  %d%%  [<- ->で調整]\n" % [prefix, _se_volume]
			1:
				text += "%sBGM音量: %d%%  [<- ->で調整]\n" % [prefix, _bgm_volume]
			2:
				text += "\n%s戻る\n" % prefix
	text += "\n(Esc: 保存して戻る)"
	label.text = text


func _go_back() -> void:
	_save_settings()
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)


func _save_settings() -> void:
	var data: Dictionary = {"se_volume": _se_volume, "bgm_volume": _bgm_volume}
	var file: FileAccess = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var file: FileAccess = FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data
		_se_volume = int(data.get("se_volume", 80))
		_bgm_volume = int(data.get("bgm_volume", 80))
	file.close()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_se_volume / 100.0))
