extends Node

## セーブデータの保存・読み込み・削除を担当する。

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const SAVE_VERSION: int = 1
var SAVE_PATH: String = "user://savegame.json"


## セーブデータが存在するか
func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## セーブデータを削除する
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)


## ゲーム状態をシリアライズする（Dictionary化）
func serialize(session: Node) -> Dictionary:
	var data: Dictionary = {}
	data["version"] = SAVE_VERSION

	# セッション
	data["session"] = {
		"seed_value": session.seed_value,
		"current_stage": session.current_stage,
		"current_floor": session.current_floor,
	}

	# プレイヤー
	var p: Node = session.player
	var slots: Array = []
	for s in p.skill_slots:
		if s == null:
			slots.append("")
		else:
			slots.append(s)
	data["player"] = {
		"hp": p.hp,
		"max_hp": p.max_hp,
		"mp": p.mp,
		"max_mp": p.max_mp,
		"level": p.level,
		"exp": p.exp,
		"grid_pos": [p.grid_pos.x, p.grid_pos.y],
		"skill_slots": slots,
		"items": p.items.duplicate(),
	}

	# ターン
	data["turn"] = {
		"turn_count": session.turn_manager.turn_count,
	}

	# スコア
	var sc: Node = session.score_system
	data["score"] = {
		"total_kills": sc.total_kills,
		"kill_score": sc.kill_score,
		"combo_count": sc.combo_count,
		"max_combo": sc.max_combo,
		"total_turns": sc.total_turns,
		"ghost_count": sc.ghost_count,
		"floors_cleared": sc.floors_cleared,
		"bosses_killed": sc.bosses_killed,
		"knowledge_count": sc.knowledge_count,
		"combo_bonus_banked": sc._combo_bonus_banked,
	}

	# 知識
	var acquired: Array[String] = []
	for id in session.knowledge_system._acquired:
		acquired.append(id)
	data["knowledge"] = {"acquired": acquired}

	# マップ
	var grid_data: Array = []
	for row in session.grid:
		var r: Array = []
		for cell in row:
			r.append(cell)
		grid_data.append(r)
	data["map"] = {"grid": grid_data}

	# 敵
	var enemies_data: Array = []
	for enemy in session.enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		enemies_data.append({
			"name": enemy.enemy_name,
			"value": enemy.value,
			"attack_power": enemy.attack_power,
			"exp_reward": enemy.exp_reward,
			"ai_pattern": enemy.ai_pattern,
			"grid_pos": [enemy.grid_pos.x, enemy.grid_pos.y],
			"state": enemy.state,
			"turn_counter": enemy._turn_counter,
		})
	data["enemies"] = enemies_data

	# 宝箱
	var chests_data: Array = []
	for pos in session.chest_positions:
		chests_data.append([pos.x, pos.y])
	data["chests"] = chests_data

	# ギミック
	var gimmicks_data: Array = []
	for pos in session.gimmick_system._gimmicks:
		var g: Dictionary = session.gimmick_system._gimmicks[pos]
		gimmicks_data.append({
			"pos": [pos.x, pos.y],
			"type": g["type"],
			"required_knowledge": g["required_knowledge"],
		})
	data["gimmicks"] = gimmicks_data

	return data


## セーブデータをファイルに書き出す
func save_game(session: Node) -> bool:
	var data: Dictionary = serialize(session)
	var json_text: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Failed to open file for writing: %s" % SAVE_PATH)
		return false
	file.store_string(json_text)
	file.close()
	return true


## セーブデータを読み込んでセッションに復元する
func load_game(session: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		push_warning("SaveManager: Failed to parse JSON")
		return false

	var data: Dictionary = json.data
	if not data.has("version") or int(data["version"]) != SAVE_VERSION:
		push_warning("SaveManager: Version mismatch")
		return false

	_deserialize(session, data)
	return true


## データからセッションを復元する
func _deserialize(session: Node, data: Dictionary) -> void:
	# システム初期化
	session._init_systems()
	session._init_player()

	# セッション
	var sd: Dictionary = data["session"]
	session.seed_value = int(sd["seed_value"])
	session.current_stage = int(sd["current_stage"])
	session.current_floor = int(sd["current_floor"])
	session._is_game_over = false

	# マップ復元
	var grid_data: Array = data["map"]["grid"]
	session.grid = []
	for row_data in grid_data:
		var row: Array[int] = []
		for cell in row_data:
			row.append(int(cell))
		session.grid.append(row)

	# プレイヤー復元
	var pd: Dictionary = data["player"]
	var p: Node = session.player
	p.grid_pos = Vector2i(int(pd["grid_pos"][0]), int(pd["grid_pos"][1]))
	p.hp = int(pd["hp"])
	p.max_hp = int(pd["max_hp"])
	p.mp = int(pd["mp"])
	p.max_mp = int(pd["max_mp"])
	p.level = int(pd["level"])
	p.exp = int(pd["exp"])
	# 技スロット
	p.skill_slots.clear()
	for s in pd["skill_slots"]:
		if s == "" or s == null:
			p.skill_slots.append(null)
		else:
			p.skill_slots.append(str(s))
	while p.skill_slots.size() < 6:
		p.skill_slots.append(null)
	# アイテム
	p.items.clear()
	for item in pd["items"]:
		p.items.append(str(item))

	# ターン復元
	session.turn_manager.turn_count = int(data["turn"]["turn_count"])

	# スコア復元
	var scd: Dictionary = data["score"]
	var sc: Node = session.score_system
	sc.total_kills = int(scd["total_kills"])
	sc.kill_score = int(scd["kill_score"])
	sc.combo_count = int(scd["combo_count"])
	sc.max_combo = int(scd["max_combo"])
	sc.total_turns = int(scd["total_turns"])
	sc.ghost_count = int(scd["ghost_count"])
	sc.floors_cleared = int(scd["floors_cleared"])
	sc.bosses_killed = int(scd["bosses_killed"])
	sc.knowledge_count = int(scd["knowledge_count"])
	sc._combo_bonus_banked = int(scd["combo_bonus_banked"])

	# 知識復元
	for id in data["knowledge"]["acquired"]:
		session.knowledge_system.acquire(str(id))

	# 敵復元
	for e in session.enemies:
		if is_instance_valid(e):
			e.queue_free()
	session.enemies.clear()
	for ed in data["enemies"]:
		var enemy: Node = EnemyScript.new()
		session.add_child(enemy)
		var pos: Vector2i = Vector2i(int(ed["grid_pos"][0]), int(ed["grid_pos"][1]))
		enemy.setup(str(ed["name"]), int(ed["value"]), int(ed["attack_power"]),
			int(ed["exp_reward"]), int(ed["ai_pattern"]), pos)
		enemy.state = int(ed["state"])
		enemy._turn_counter = int(ed["turn_counter"])
		enemy.defeated.connect(session._on_enemy_defeated.bind(enemy))
		enemy.ghostified.connect(session._on_enemy_ghostified)
		session.enemies.append(enemy)

	# 宝箱復元
	session.chest_positions.clear()
	for cd in data["chests"]:
		session.chest_positions.append(Vector2i(int(cd[0]), int(cd[1])))

	# ギミック復元
	session.gimmick_system.clear_gimmicks()
	for gd_item in data["gimmicks"]:
		var pos: Vector2i = Vector2i(int(gd_item["pos"][0]), int(gd_item["pos"][1]))
		session.gimmick_system.place_gimmick(pos, int(gd_item["type"]), str(gd_item["required_knowledge"]))

	# フロア変更シグナル
	session.floor_changed.emit(session.current_floor, session.current_stage)
