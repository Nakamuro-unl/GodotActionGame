class_name TestScreenOrientation
extends GdUnitTestSuite

# 画面向き・解像度対応のテスト

const PU = preload("res://scripts/systems/platform_ui.gd")


# PC用の設定値
func test_pc_screen_config() -> void:
	var config: Dictionary = PU.get_screen_config(PU.Platform.PC)
	assert_int(config["width"]).is_equal(960)
	assert_int(config["height"]).is_equal(720)
	assert_float(config["camera_zoom"]).is_equal(3.0)


# モバイル用の設定値
func test_mobile_screen_config() -> void:
	var config: Dictionary = PU.get_screen_config(PU.Platform.MOBILE)
	assert_int(config["width"]).is_equal(360)
	assert_int(config["height"]).is_equal(640)
	assert_float(config["camera_zoom"]).is_equal(2.5)


# PCは横画面
func test_pc_is_landscape() -> void:
	var config: Dictionary = PU.get_screen_config(PU.Platform.PC)
	assert_bool(config["width"] > config["height"]).is_true()


# モバイルは縦画面
func test_mobile_is_portrait() -> void:
	var config: Dictionary = PU.get_screen_config(PU.Platform.MOBILE)
	assert_bool(config["height"] > config["width"]).is_true()


# HUDレイアウト設定
func test_pc_hud_layout() -> void:
	var layout: Dictionary = PU.get_hud_layout(PU.Platform.PC)
	assert_bool(layout.has("skill_slots_y")).is_true()
	assert_bool(layout.has("message_log_y")).is_true()
	assert_bool(layout.has("minimap_x")).is_true()


func test_mobile_hud_layout() -> void:
	var layout: Dictionary = PU.get_hud_layout(PU.Platform.MOBILE)
	assert_bool(layout.has("skill_slots_y")).is_true()
	assert_bool(layout.has("message_log_y")).is_true()
	assert_bool(layout.has("minimap_x")).is_true()
	# モバイルではスキルスロットがパッドの上に来るのでy値がPC版と違う
	var pc_layout: Dictionary = PU.get_hud_layout(PU.Platform.PC)
	assert_bool(layout["skill_slots_y"] != pc_layout["skill_slots_y"]).is_true()
