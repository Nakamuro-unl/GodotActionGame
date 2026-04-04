extends RefCounted

## プラットフォーム判定とUI設定。

enum Platform {
	PC,
	MOBILE,
}


## 現在のプラットフォームを判定
static func detect_platform() -> Platform:
	if DisplayServer.is_touchscreen_available():
		return Platform.MOBILE
	return Platform.PC


## プラットフォーム別のUI設定を返す
static func get_ui_config(platform: Platform) -> Dictionary:
	match platform:
		Platform.PC:
			return {
				"show_virtual_pad": false,
				"show_keyboard_hints": true,
				"show_skill_slots_hud": true,
				"show_minimap": true,
				"show_message_log": true,
				"show_hud_top": true,
			}
		Platform.MOBILE:
			return {
				"show_virtual_pad": true,
				"show_keyboard_hints": false,
				"show_skill_slots_hud": false,
				"show_minimap": true,
				"show_message_log": true,
				"show_hud_top": true,
			}
	return {}


## キーボード操作ヒントテキスト
static func get_keyboard_hints() -> String:
	return "矢印:移動  Shift+矢印:転換  1-6:技  I:アイテム  Enter:調べる  Esc:メニュー  Space:待機"
