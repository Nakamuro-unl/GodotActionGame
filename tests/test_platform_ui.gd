class_name TestPlatformUI
extends GdUnitTestSuite

# プラットフォーム別UI判定のテスト

const PU = preload("res://scripts/systems/platform_ui.gd")


# PC判定: タッチなし
func test_pc_mode_detected() -> void:
	# テスト環境はheadlessなので常にPC扱い
	var mode: int = PU.detect_platform()
	assert_int(mode).is_equal(PU.Platform.PC)


# PCでの表示要素
func test_pc_show_elements() -> void:
	var config: Dictionary = PU.get_ui_config(PU.Platform.PC)
	assert_bool(config["show_virtual_pad"]).is_false()
	assert_bool(config["show_keyboard_hints"]).is_true()
	assert_bool(config["show_skill_slots_hud"]).is_true()


# モバイルでの表示要素
func test_mobile_show_elements() -> void:
	var config: Dictionary = PU.get_ui_config(PU.Platform.MOBILE)
	assert_bool(config["show_virtual_pad"]).is_true()
	assert_bool(config["show_keyboard_hints"]).is_false()
	assert_bool(config["show_skill_slots_hud"]).is_false()


# 共通表示要素
func test_common_elements() -> void:
	for platform in [PU.Platform.PC, PU.Platform.MOBILE]:
		var config: Dictionary = PU.get_ui_config(platform)
		assert_bool(config["show_minimap"]).is_true()
		assert_bool(config["show_message_log"]).is_true()
		assert_bool(config["show_hud_top"]).is_true()


# キーボードヒントテキスト
func test_keyboard_hints_text() -> void:
	var hints: String = PU.get_keyboard_hints()
	assert_str(hints).contains("矢印")
	assert_str(hints).contains("Esc")
	assert_str(hints).contains("Enter")
