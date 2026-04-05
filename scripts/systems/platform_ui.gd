extends RefCounted

## プラットフォーム判定、UI設定、画面向き・解像度設定。

enum Platform {
	PC,
	MOBILE,
}


## 現在のプラットフォームを判定
static func detect_platform() -> Platform:
	if DisplayServer.is_touchscreen_available():
		return Platform.MOBILE
	return Platform.PC


## プラットフォーム別のUI表示設定
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


## プラットフォーム別の画面解像度設定
static func get_screen_config(platform: Platform) -> Dictionary:
	match platform:
		Platform.PC:
			return {
				"width": 960,
				"height": 720,
				"camera_zoom": 3.0,
				"orientation": DisplayServer.SCREEN_LANDSCAPE,
			}
		Platform.MOBILE:
			return {
				"width": 360,
				"height": 640,
				"camera_zoom": 2.5,
				"orientation": DisplayServer.SCREEN_PORTRAIT,
			}
	return {}


## プラットフォーム別のHUDレイアウト（各要素のY座標等）
static func get_hud_layout(platform: Platform) -> Dictionary:
	match platform:
		Platform.PC:
			return {
				"hud_top_y": 4,
				"skill_slots_y": 660,
				"message_log_y": 690,
				"key_hints_y": 706,
				"minimap_x": -118,
				"minimap_y": 24,
				"minimap_size": 110,
			}
		Platform.MOBILE:
			return {
				"hud_top_y": 2,
				"skill_slots_y": 350,
				"message_log_y": 285,
				"key_hints_y": -1,  # 非表示
				"minimap_x": -68,
				"minimap_y": 18,
				"minimap_size": 60,
			}
	return {}


## 画面向きと解像度を適用する
static func apply_screen_config(platform: Platform) -> void:
	var config: Dictionary = get_screen_config(platform)
	DisplayServer.screen_set_orientation(config["orientation"])


## キーボード操作ヒントテキスト
static func get_keyboard_hints() -> String:
	return "矢印:移動  Shift+矢印:転換  1-6:技  I:アイテム  Enter:調べる  Esc:メニュー  Space:待機"
