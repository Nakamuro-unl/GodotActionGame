class_name TestSaveLoad
extends GdUnitTestSuite

# セーブ/ロードのテスト

const SM = preload("res://scripts/systems/save_manager.gd")
const GSS = preload("res://scripts/systems/game_session.gd")
const ES = preload("res://scripts/entities/enemy.gd")
const MG = preload("res://scripts/systems/map_generator.gd")

var _save_mgr: Node
var _session: Node

const TEST_SAVE_PATH: String = "user://test_savegame.json"


func before_test() -> void:
	_save_mgr = SM.new()
	_save_mgr.SAVE_PATH = TEST_SAVE_PATH
	add_child(_save_mgr)
	_session = GSS.new()
	add_child(_session)
	_session.start_new_game(12345)
	# テスト前にファイルを削除
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH.replace("user://", OS.get_user_data_dir() + "/"))


func after_test() -> void:
	if is_instance_valid(_session):
		_session.queue_free()
	if is_instance_valid(_save_mgr):
		_save_mgr.queue_free()
	# テスト後にファイルを削除
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH.replace("user://", OS.get_user_data_dir() + "/"))


# --- シリアライズ ---

# AC-SAVE-001: セッション情報がシリアライズされる
func test_serialize_session() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_int(data["session"]["seed_value"]).is_equal(12345)
	assert_int(data["session"]["current_stage"]).is_equal(1)
	assert_int(data["session"]["current_floor"]).is_equal(1)


# AC-SAVE-003: プレイヤー情報がシリアライズされる
func test_serialize_player() -> void:
	_session.player.take_damage(5)
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_int(data["player"]["hp"]).is_equal(25)
	assert_int(data["player"]["max_hp"]).is_equal(30)
	assert_int(data["player"]["level"]).is_equal(1)
	assert_array(data["player"]["skill_slots"]).contains(["plus_1", "minus_1"])


# AC-SAVE-004: 敵情報がシリアライズされる
func test_serialize_enemies() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_bool(data["enemies"].size() > 0).is_true()
	var enemy_data: Dictionary = data["enemies"][0]
	assert_str(enemy_data["name"]).is_not_empty()
	assert_bool(enemy_data.has("value")).is_true()
	assert_bool(enemy_data.has("grid_pos")).is_true()


# AC-SAVE-005: マップがシリアライズされる
func test_serialize_map() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_int(data["map"]["grid"].size()).is_equal(MG.GRID_HEIGHT)
	assert_int(data["map"]["grid"][0].size()).is_equal(MG.GRID_WIDTH)


# AC-SAVE-006: スコア・知識・ターンがシリアライズされる
func test_serialize_score_knowledge_turn() -> void:
	_session.score_system.register_kill(10)
	_session.knowledge_system.acquire("K-101")
	_session.turn_manager.execute_player_action()
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_int(data["score"]["total_kills"]).is_equal(1)
	assert_int(data["turn"]["turn_count"]).is_equal(1)
	assert_array(data["knowledge"]["acquired"]).contains(["K-101"])


# 宝箱がシリアライズされる
func test_serialize_chests() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_bool(data.has("chests")).is_true()


# ギミックがシリアライズされる
func test_serialize_gimmicks() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_bool(data.has("gimmicks")).is_true()


# バージョン番号が含まれる
func test_serialize_version() -> void:
	var data: Dictionary = _save_mgr.serialize(_session)
	assert_int(data["version"]).is_equal(SM.SAVE_VERSION)


# --- ファイル操作 ---

# AC-SAVE-001: セーブファイルが書き出される
func test_save_creates_file() -> void:
	var result: bool = _save_mgr.save_game(_session)
	assert_bool(result).is_true()
	assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_true()


# AC-SAVE-007: セーブデータの存在チェック
func test_has_save_data() -> void:
	assert_bool(_save_mgr.has_save_data()).is_false()
	_save_mgr.save_game(_session)
	assert_bool(_save_mgr.has_save_data()).is_true()


# AC-SAVE-008: セーブデータの削除
func test_delete_save() -> void:
	_save_mgr.save_game(_session)
	_save_mgr.delete_save()
	assert_bool(_save_mgr.has_save_data()).is_false()


# --- デシリアライズ（復元） ---

# AC-SAVE-002: セーブ→ロードでセッション情報が復元される
func test_load_restores_session() -> void:
	_session.try_player_move(Vector2i.DOWN)
	_session.try_player_move(Vector2i.DOWN)
	_save_mgr.save_game(_session)

	# 新しいセッションに復元
	var new_session: Node = GSS.new()
	add_child(new_session)
	var result: bool = _save_mgr.load_game(new_session)
	assert_bool(result).is_true()
	assert_int(new_session.seed_value).is_equal(12345)
	assert_int(new_session.current_stage).is_equal(1)
	assert_int(new_session.current_floor).is_equal(1)
	new_session.queue_free()


# AC-SAVE-003: プレイヤーステータスが復元される
func test_load_restores_player() -> void:
	_session.player.take_damage(10)
	_session.player.consume_mp(3)
	_session.player.gain_exp(5)
	_save_mgr.save_game(_session)

	var new_session: Node = GSS.new()
	add_child(new_session)
	_save_mgr.load_game(new_session)
	assert_int(new_session.player.hp).is_equal(20)
	assert_int(new_session.player.mp).is_equal(7)
	assert_int(new_session.player.exp).is_equal(5)
	new_session.queue_free()


# AC-SAVE-004: 敵が復元される
func test_load_restores_enemies() -> void:
	var enemy_count: int = _session.enemies.size()
	var first_enemy_name: String = _session.enemies[0].enemy_name if enemy_count > 0 else ""
	_save_mgr.save_game(_session)

	var new_session: Node = GSS.new()
	add_child(new_session)
	_save_mgr.load_game(new_session)
	assert_int(new_session.enemies.size()).is_equal(enemy_count)
	if enemy_count > 0:
		assert_str(new_session.enemies[0].enemy_name).is_equal(first_enemy_name)
	new_session.queue_free()


# AC-SAVE-005: マップグリッドが復元される
func test_load_restores_map() -> void:
	_save_mgr.save_game(_session)

	var new_session: Node = GSS.new()
	add_child(new_session)
	_save_mgr.load_game(new_session)
	assert_int(new_session.grid.size()).is_equal(MG.GRID_HEIGHT)
	# 元のグリッドと一致
	for y in 5:
		for x in 5:
			assert_int(new_session.grid[y][x]).is_equal(_session.grid[y][x])
	new_session.queue_free()


# AC-SAVE-006: 知識が復元される
func test_load_restores_knowledge() -> void:
	_session.knowledge_system.acquire("K-101")
	_session.knowledge_system.acquire("K-102")
	_save_mgr.save_game(_session)

	var new_session: Node = GSS.new()
	add_child(new_session)
	_save_mgr.load_game(new_session)
	assert_bool(new_session.knowledge_system.is_acquired("K-101")).is_true()
	assert_bool(new_session.knowledge_system.is_acquired("K-102")).is_true()
	assert_bool(new_session.knowledge_system.is_acquired("K-103")).is_false()
	new_session.queue_free()


# AC-SAVE-006: スコアが復元される
func test_load_restores_score() -> void:
	_session.score_system.register_kill(10)
	_session.score_system.register_kill(5)
	_session.score_system.register_perfect_kill()
	_save_mgr.save_game(_session)

	var new_session: Node = GSS.new()
	add_child(new_session)
	_save_mgr.load_game(new_session)
	assert_int(new_session.score_system.total_kills).is_equal(2)
	assert_int(new_session.score_system.kill_score).is_equal(150)
	assert_int(new_session.score_system.combo_count).is_equal(1)
	new_session.queue_free()


# AC-SAVE-009: バージョン不一致でロード拒否
func test_load_rejects_wrong_version() -> void:
	_save_mgr.save_game(_session)
	# ファイルを書き換えてバージョンを変える
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()
	json_text = json_text.replace('"version":1', '"version":999')
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(json_text)
	file.close()

	var new_session: Node = GSS.new()
	add_child(new_session)
	var result: bool = _save_mgr.load_game(new_session)
	assert_bool(result).is_false()
	new_session.queue_free()
