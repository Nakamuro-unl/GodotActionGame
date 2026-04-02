extends Node

## 1回のゲームプレイ全体を管理する。
## 全システム（マップ生成、ターン、戦闘、スコア、知識）を結合し、
## InGameシーンが参照するロジック層。

signal game_over()
signal game_clear()
signal floor_changed(floor_number: int, stage: int)
signal message(text: String)

const MapGen = preload("res://scripts/systems/map_generator.gd")
const TurnMgr = preload("res://scripts/systems/turn_manager.gd")
const CombatSys = preload("res://scripts/systems/combat_system.gd")
const ScoreSys = preload("res://scripts/systems/score_system.gd")
const KnowledgeSys = preload("res://scripts/systems/knowledge_system.gd")
const PlayerScript = preload("res://scripts/entities/player.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const FLOORS_PER_STAGE: int = 5
const TOTAL_FLOORS: int = 25

## ステージ別敵テーブル: [[name, value_min, value_max, attack, exp, ai], ...]
const STAGE_ENEMIES: Dictionary = {
	1: [
		["子狼", 1, 3, 2, 2, EnemyScript.AIPattern.CHASE],
		["猪",   3, 6, 3, 4, EnemyScript.AIPattern.CHARGE],
		["熊",   5, 10, 5, 8, EnemyScript.AIPattern.CHASE],
	],
	2: [
		["サソリ",   5, 12, 4, 6, EnemyScript.AIPattern.CHASE],
		["砂蛇",     8, 15, 5, 8, EnemyScript.AIPattern.RANDOM],
		["下級悪魔", 12, 24, 7, 12, EnemyScript.AIPattern.CHASE],
	],
	3: [
		["ゴブリン", 10, 20, 6, 10, EnemyScript.AIPattern.CHASE],
		["ゴーレム", 20, 36, 10, 18, EnemyScript.AIPattern.SLOW_CHASE],
		["上位悪魔", 25, 50, 12, 25, EnemyScript.AIPattern.SMART_CHASE],
	],
	4: [
		["機械兵",             20, 50, 10, 20, EnemyScript.AIPattern.PATROL],
		["キメラ",             30, 64, 14, 30, EnemyScript.AIPattern.RANDOM],
		["マッドサイエンティスト", 50, 100, 16, 40, EnemyScript.AIPattern.FLEE],
	],
	5: [
		["エイリアン",   50, 128, 15, 40, EnemyScript.AIPattern.SMART_CHASE],
		["ブラックホール", 100, 200, 20, 60, EnemyScript.AIPattern.STATIONARY],
		["次元虫",       64, 150, 18, 50, EnemyScript.AIPattern.WARP],
	],
}

## ステージ別敵数範囲
const STAGE_ENEMY_COUNT: Dictionary = {
	1: Vector2i(3, 5),
	2: Vector2i(4, 6),
	3: Vector2i(5, 7),
	4: Vector2i(6, 8),
	5: Vector2i(7, 8),
}

var map_generator: Node
var turn_manager: Node
var combat_system: Node
var score_system: Node
var knowledge_system: Node
var player: Node
var enemies: Array = []
var grid: Array = []
var current_stage: int = 1
var current_floor: int = 1
var seed_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_game_over: bool = false


func start_new_game(p_seed: int) -> void:
	seed_value = p_seed
	_rng.seed = p_seed
	current_stage = 1
	current_floor = 1
	_is_game_over = false

	_init_systems()
	_init_player()
	_generate_floor()


func _init_systems() -> void:
	map_generator = MapGen.new()
	turn_manager = TurnMgr.new()
	combat_system = CombatSys.new()
	score_system = ScoreSys.new()
	knowledge_system = KnowledgeSys.new()
	add_child(map_generator)
	add_child(turn_manager)
	add_child(combat_system)
	add_child(score_system)
	add_child(knowledge_system)

	turn_manager.enemy_phase_started.connect(_on_enemy_phase)
	turn_manager.environment_phase_started.connect(_on_environment_phase)
	turn_manager.hp_regen_triggered.connect(_on_hp_regen)


func _init_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.dead.connect(_on_player_dead)


# --- フロア生成 ---

func _generate_floor() -> void:
	var floor_seed: int = seed_value + current_floor * 1000
	grid = map_generator.generate_floor(current_stage, floor_seed)

	var start_pos: Vector2i = map_generator.get_player_start()
	player.setup(grid, start_pos)

	_spawn_enemies()
	floor_changed.emit(current_floor, current_stage)


func _spawn_enemies() -> void:
	# 前のフロアの敵をクリーンアップ
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	var stage_data: Array = STAGE_ENEMIES.get(current_stage, STAGE_ENEMIES[1])
	var count_range: Vector2i = STAGE_ENEMY_COUNT.get(current_stage, Vector2i(3, 5))
	var count: int = _rng.randi_range(count_range.x, count_range.y)
	var rooms: Array = map_generator.get_rooms()

	for i in count:
		var template: Array = stage_data[_rng.randi_range(0, stage_data.size() - 1)]
		var value: int = _rng.randi_range(template[1], template[2])
		var pos: Vector2i = _get_random_floor_pos(rooms)

		var enemy: Node = EnemyScript.new()
		add_child(enemy)
		enemy.setup(template[0], value, template[3], template[4], template[5], pos)
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
		enemy.ghostified.connect(_on_enemy_ghostified)
		enemies.append(enemy)


func _get_random_floor_pos(rooms: Array) -> Vector2i:
	for attempt in 50:
		var room_idx: int = _rng.randi_range(1, rooms.size() - 1)
		var room: Rect2i = rooms[room_idx]
		var x: int = _rng.randi_range(room.position.x, room.position.x + room.size.x - 1)
		var y: int = _rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
		var pos: Vector2i = Vector2i(x, y)
		if pos != player.grid_pos and not _is_occupied(pos):
			return pos
	return Vector2i(1, 1)


func _is_occupied(pos: Vector2i) -> bool:
	for e in enemies:
		if e.grid_pos == pos and e.state != EnemyScript.EnemyState.DEFEATED:
			return true
	return false


# --- プレイヤーアクション ---

func try_player_move(direction: Vector2i) -> bool:
	if _is_game_over:
		return false
	# 敵がいる場所には移動不可
	var target: Vector2i = player.grid_pos + direction
	if _is_occupied(target):
		return false

	var moved: bool = player.try_move(direction, grid)
	if moved:
		score_system.register_turn()
		turn_manager.execute_player_action()
		return true
	return false


func try_use_skill(slot_index: int, direction: Vector2i) -> Dictionary:
	if _is_game_over:
		return {"success": false}

	var skill_id: String = ""
	if slot_index >= 0 and slot_index < player.skill_slots.size():
		skill_id = player.skill_slots[slot_index]
	if skill_id == "" or skill_id == "null":
		return {"success": false}

	# 指定方向の隣接敵を探す
	var target_pos: Vector2i = player.grid_pos + direction
	var target_enemy: Node = _get_enemy_at(target_pos)
	if target_enemy == null:
		return {"success": false}

	var result: Dictionary = combat_system.use_skill(skill_id, player, target_enemy)
	if result["success"]:
		score_system.register_turn()
		turn_manager.execute_player_action()
	return result


func interact_stairs() -> void:
	if _is_game_over:
		return
	var stairs_pos: Vector2i = map_generator.get_stairs_position()
	if player.grid_pos != stairs_pos:
		return

	score_system.register_floor_cleared()
	current_floor += 1

	if current_floor > TOTAL_FLOORS:
		game_clear.emit()
		return

	current_stage = ((current_floor - 1) / FLOORS_PER_STAGE) + 1
	_generate_floor()


func open_chest() -> void:
	var knowledge_id: String = knowledge_system.get_random_unobtained(current_stage)
	if knowledge_id != "":
		knowledge_system.acquire(knowledge_id)
		score_system.register_knowledge()
		var info: Dictionary = knowledge_system.get_info(knowledge_id)
		message.emit("「%s」を手に入れた!" % info["name"])
	else:
		# 全知識獲得済みの場合はアイテム（仮）
		player.add_item("herb")
		message.emit("薬草を手に入れた!")


# --- 敵フェーズ ---

func _on_enemy_phase() -> void:
	var occupied: Array[Vector2i] = [player.grid_pos]
	for e in enemies:
		if e.state != EnemyScript.EnemyState.DEFEATED:
			occupied.append(e.grid_pos)

	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		enemy.decide_move(player.grid_pos, grid, occupied)

		# 隣接していたら攻撃
		if _is_adjacent(enemy.grid_pos, player.grid_pos):
			var dmg: int = combat_system.calculate_damage(enemy, player)
			if dmg > 0:
				player.take_damage(dmg)
				message.emit("%s の攻撃! %d ダメージ!" % [enemy.enemy_name, dmg])


func _on_environment_phase() -> void:
	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.GHOST:
			enemy.process_ghost_recovery()


func _on_hp_regen() -> void:
	if player.hp < player.max_hp:
		player.heal_hp(1)


# --- イベントハンドラ ---

func _on_player_dead() -> void:
	_is_game_over = true
	game_over.emit()


func _on_enemy_defeated(enemy: Node) -> void:
	score_system.register_kill(enemy.exp_reward)
	player.gain_exp(enemy.exp_reward)

	# ぴったり0で倒したか（幽霊化していなければぴったり）
	if enemy.value == 0:
		score_system.register_perfect_kill()
		message.emit("%s を倒した! コンボ x%d!" % [enemy.enemy_name, score_system.combo_count])
	else:
		message.emit("%s を倒した!" % enemy.enemy_name)


func _on_enemy_ghostified() -> void:
	score_system.register_ghost()


# --- ヘルパー ---

func _get_enemy_at(pos: Vector2i) -> Node:
	for enemy in enemies:
		if enemy.grid_pos == pos and enemy.state != EnemyScript.EnemyState.DEFEATED:
			return enemy
	return null


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff: Vector2i = a - b
	return (absi(diff.x) + absi(diff.y)) == 1
