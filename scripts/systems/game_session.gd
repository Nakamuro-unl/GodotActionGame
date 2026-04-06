extends Node

## 1回のゲームプレイ全体を管理する。
## 全システムを結合し、InGameシーンが参照するロジック層。
## 定数データは game_session_data.gd、フロア生成は floor_builder.gd に分離。

signal game_over()
signal game_clear()
signal floor_changed(floor_number: int, stage: int)
signal message(text: String)
signal skill_slot_full(skill_id: String, skill_name: String)
signal enemy_defeated_visual(enemy: Node)  # 撃破アニメーション用
signal enemy_ghostified_visual()
signal player_damaged_visual(amount: int)
signal player_leveled_up_visual(new_level: int)
signal combo_visual(combo_count: int)
signal boss_appeared(boss_name: String)
signal boss_defeated_stairs(stairs_pos: Vector2i)

const MapGen = preload("res://scripts/systems/map_generator.gd")
const TurnMgr = preload("res://scripts/systems/turn_manager.gd")
const CombatSys = preload("res://scripts/systems/combat_system.gd")
const ScoreSys = preload("res://scripts/systems/score_system.gd")
const KnowledgeSys = preload("res://scripts/systems/knowledge_system.gd")
const GimmickSys = preload("res://scripts/systems/gimmick_system.gd")
const MinimapData = preload("res://scripts/systems/minimap_data.gd")
const PlayerScript = preload("res://scripts/entities/player.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const FloorBuilder = preload("res://scripts/systems/floor_builder.gd")
const BossMapGen = preload("res://scripts/systems/boss_map_generator.gd")
const DropTableScript = preload("res://scripts/systems/drop_table.gd")
const SaveMgr = preload("res://scripts/systems/save_manager.gd")

const FLOORS_PER_STAGE: int = 5
const TOTAL_FLOORS: int = 25

var map_generator: Node
var turn_manager: Node
var combat_system: Node
var score_system: Node
var knowledge_system: Node
var gimmick_system: Node
var drop_table: Node
var minimap: Node
var player: Node
var enemies: Array = []
var grid: Array = []
var chest_positions: Array[Vector2i] = []
var _start_chest_pos: Vector2i = Vector2i(-1, -1)  # 開始部屋の固定宝箱位置
var current_stage: int = 1
var current_floor: int = 1
var seed_value: int = 0
var _is_boss_floor: bool = false
var _boss_seal_chest_pos: Vector2i = Vector2i(-1, -1)
var _boss_seal_knowledge_id: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_game_over: bool = false
var _floor_builder: FloorBuilder


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
	gimmick_system = GimmickSys.new()
	add_child(map_generator)
	add_child(turn_manager)
	add_child(combat_system)
	add_child(score_system)
	add_child(knowledge_system)
	drop_table = DropTableScript.new()
	minimap = MinimapData.new()
	add_child(gimmick_system)
	add_child(drop_table)
	add_child(minimap)

	turn_manager.enemy_phase_started.connect(_on_enemy_phase)
	turn_manager.environment_phase_started.connect(_on_environment_phase)
	turn_manager.hp_regen_triggered.connect(_on_hp_regen)

	_floor_builder = FloorBuilder.new()
	_floor_builder.setup(_rng, drop_table)


func _init_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.dead.connect(_on_player_dead)
	player.setup([], Vector2i.ZERO)  # 初回: ステータスとスロットを初期化


# --- フロア生成 ---

func _generate_floor() -> void:
	var floor_seed: int = seed_value + current_floor * 1000
	var is_boss_floor: bool = current_floor % FLOORS_PER_STAGE == 0
	_is_boss_floor = is_boss_floor
	_start_chest_pos = Vector2i(-1, -1)
	_boss_seal_chest_pos = Vector2i(-1, -1)
	_boss_seal_knowledge_id = ""

	if is_boss_floor:
		_generate_boss_floor(floor_seed)
	else:
		_generate_normal_floor(floor_seed, is_boss_floor)

	minimap.init_floor(MapGen.GRID_WIDTH, MapGen.GRID_HEIGHT)
	minimap.explore_around(player.grid_pos, 4)
	floor_changed.emit(current_floor, current_stage)


func _generate_normal_floor(floor_seed: int, is_boss_floor: bool) -> void:
	grid = map_generator.generate_floor(current_stage, floor_seed)
	player.setup_floor(map_generator.get_player_start())
	_floor_builder.spawn_enemies(self, current_stage, false)
	_floor_builder.place_chests(self, current_stage, current_floor == 1)
	_floor_builder.place_gimmicks(self, current_stage)


func _generate_boss_floor(floor_seed: int) -> void:
	var bmg: BossMapGen = BossMapGen.new()
	bmg.setup(_rng)
	grid = bmg.generate(floor_seed)
	player.setup_floor(bmg.get_player_start())

	# ボスを配置
	var boss_data: Dictionary = EnemyScript.BOSS_DATA.get(current_stage, {})
	if boss_data.is_empty():
		return
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	var boss: Node = EnemyScript.new()
	add_child(boss)
	boss.setup(str(boss_data["name"]), int(boss_data["value"]), int(boss_data["attack"]),
		int(boss_data["exp"]), EnemyScript.AIPattern.BOSS, bmg.get_boss_position())
	boss.defeated.connect(_on_enemy_defeated.bind(boss))
	boss.ghostified.connect(_on_enemy_ghostified)
	enemies.append(boss)

	# 通常敵を少数配置
	var count: int = _rng.randi_range(1, 3)
	var rooms: Array = bmg.get_rooms()
	for i in count:
		var template: Dictionary = drop_table.pick_enemy_template(current_stage)
		var value: int = _rng.randi_range(int(template["value_min"]), int(template["value_max"]))
		# 開始部屋か中間部屋に配置
		var room: Rect2i = rooms[_rng.randi_range(0, mini(rooms.size() - 2, 1))]
		var x: int = _rng.randi_range(room.position.x, room.position.x + room.size.x - 1)
		var y: int = _rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
		var enemy: Node = EnemyScript.new()
		add_child(enemy)
		enemy.setup(str(template["name"]), value, int(template["attack"]),
			int(template["exp"]), int(template["ai"]), Vector2i(x, y))
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
		enemy.ghostified.connect(_on_enemy_ghostified)
		enemies.append(enemy)

	# 宝箱（封印解除知識）
	chest_positions.clear()
	var cp: Vector2i = bmg.get_chest_position()
	chest_positions.append(cp)
	grid[cp.y][cp.x] = MapGen.Tile.CHEST

	# 封印ギミック
	gimmick_system.clear_gimmicks()
	var seal_pos: Vector2i = bmg.get_seal_position()
	var seal_data: Dictionary = _floor_builder.BOSS_SEAL_KNOWLEDGE.get(current_stage, {})
	if not seal_data.is_empty():
		gimmick_system.place_gimmick(seal_pos, seal_data["gimmick"], seal_data["knowledge"])
		if not knowledge_system.is_acquired(seal_data["knowledge"]):
			_boss_seal_chest_pos = cp
			_boss_seal_knowledge_id = seal_data["knowledge"]

	# 階段を隠す
	var sp: Vector2i = bmg.get_stairs_position()
	grid[sp.y][sp.x] = MapGen.Tile.FLOOR

	# map_generatorの位置情報をボスマップの値で上書き（interact等で参照するため）
	# _stairs_posとget_player_startを参照するため一時保存
	map_generator._stairs_pos = sp
	map_generator._player_start = bmg.get_player_start()
	map_generator._rooms = bmg.get_rooms()

	# ボス登場演出
	boss_appeared.emit(str(boss_data["name"]))


# --- プレイヤーアクション ---

func try_player_move(direction: Vector2i) -> bool:
	if _is_game_over:
		return false
	var target: Vector2i = player.grid_pos + direction
	if _is_occupied(target):
		return false
	var moved: bool = player.try_move(direction, grid)
	if moved:
		minimap.explore_around(player.grid_pos, 4)
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

	var target_pos: Vector2i = player.grid_pos + direction
	var target_enemy: Node = _get_enemy_at(target_pos)
	if target_enemy == null:
		return {"success": false}

	var result: Dictionary = combat_system.use_skill(skill_id, player, target_enemy)
	if result["success"]:
		score_system.register_turn()
		turn_manager.execute_player_action()
	return result


## 「調べる」統合アクション
func interact(facing: Vector2i) -> Dictionary:
	if _is_game_over:
		return {"type": "none"}

	var stairs_pos: Vector2i = map_generator.get_stairs_position()
	if player.grid_pos == stairs_pos:
		_advance_floor()
		return {"type": "stairs"}

	if player.grid_pos in chest_positions:
		return _open_chest_at(player.grid_pos)

	var gimmick_pos: Vector2i = player.grid_pos + facing
	if gimmick_system.has_gimmick_at(gimmick_pos):
		return _try_resolve_gimmick(gimmick_pos)

	return {"type": "none", "message": ""}


func interact_stairs() -> void:
	interact(Vector2i.ZERO)


func _advance_floor() -> void:
	score_system.register_floor_cleared()
	current_floor += 1
	if current_floor > TOTAL_FLOORS:
		_delete_save()
		game_clear.emit()
		return
	current_stage = ((current_floor - 1) / FLOORS_PER_STAGE) + 1
	_generate_floor()
	_auto_save()


func _open_chest_at(pos: Vector2i) -> Dictionary:
	chest_positions.erase(pos)
	grid[pos.y][pos.x] = MapGen.Tile.FLOOR

	# 開始部屋の固定宝箱: 減法 (K-103)
	if pos == _start_chest_pos:
		_start_chest_pos = Vector2i(-1, -1)
		return _acquire_knowledge("K-103")

	# ボス封印解除用の宝箱
	if pos == _boss_seal_chest_pos and _boss_seal_knowledge_id != "":
		_boss_seal_chest_pos = Vector2i(-1, -1)
		var kid: String = _boss_seal_knowledge_id
		_boss_seal_knowledge_id = ""
		return _acquire_knowledge(kid)

	var has_unobtained: bool = knowledge_system.get_random_unobtained(current_stage) != ""
	var roll: String = drop_table.roll_chest_type(has_unobtained)

	if roll == "knowledge":
		var knowledge_id: String = knowledge_system.get_random_unobtained(current_stage)
		if knowledge_id != "":
			return _acquire_knowledge(knowledge_id)

	# アイテム抽選
	var item: Dictionary = drop_table.pick_item(current_stage)
	var item_id: String = str(item["id"])
	player.add_item(item_id)
	message.emit("宝箱からアイテムを手に入れた!")
	return {"type": "chest_item", "item_id": item_id}


func _acquire_knowledge(knowledge_id: String) -> Dictionary:
	knowledge_system.acquire(knowledge_id)
	score_system.register_knowledge()
	var info: Dictionary = knowledge_system.get_info(knowledge_id)
	# 技がある知識なら自動装備を試みる
	if info.has("skill_id") and info["skill_id"] != "":
		var equipped: bool = player.auto_equip_skill(info["skill_id"])
		if not equipped:
			# スロット満杯: 入れ替え選択を要求
			var skill_info: Dictionary = combat_system.get_skill_info(info["skill_id"])
			var skill_name: String = skill_info.get("name", info["skill_id"])
			skill_slot_full.emit(info["skill_id"], skill_name)
	message.emit("宝箱から「%s」を手に入れた!" % info["name"])
	return {"type": "chest_knowledge", "knowledge_id": knowledge_id, "name": info["name"]}


func _try_resolve_gimmick(pos: Vector2i) -> Dictionary:
	var result: Dictionary = gimmick_system.try_resolve(pos, knowledge_system, grid)
	message.emit(result["message"])
	if result["success"]:
		# 隠し部屋の宝箱を登録
		var chest_pos: Vector2i = result.get("chest_pos", Vector2i.ZERO)
		if chest_pos != Vector2i.ZERO:
			chest_positions.append(chest_pos)
		return {"type": "gimmick_resolved", "message": result["message"]}
	return {"type": "gimmick_failed", "message": result["message"]}


func open_chest() -> void:
	_open_chest_at(player.grid_pos)


# --- 敵フェーズ ---

func _on_enemy_phase() -> void:
	for enemy in enemies:
		if enemy.state == EnemyScript.EnemyState.DEFEATED:
			continue
		# 移動のたびにoccupiedを再構築（移動済みの敵の新位置を反映）
		var occupied: Array[Vector2i] = [player.grid_pos]
		for other in enemies:
			if other != enemy and other.state != EnemyScript.EnemyState.DEFEATED:
				occupied.append(other.grid_pos)
		enemy.decide_move(player.grid_pos, grid, occupied)

		# 吸引処理（ブラックホール等）
		if enemy.pull_target != Vector2i(-1, -1):
			var pt: Vector2i = enemy.pull_target
			if pt.x >= 0 and pt.x < grid[0].size() and pt.y >= 0 and pt.y < grid.size():
				if grid[pt.y][pt.x] != MapGen.Tile.WALL and not _is_occupied(pt):
					player.grid_pos = pt
					minimap.explore_around(player.grid_pos, 4)
					message.emit("%s に引き寄せられた!" % enemy.enemy_name)

		var is_adj: bool = _is_adjacent(enemy.grid_pos, player.grid_pos)
		if is_adj and enemy.was_adjacent:
			# 前ターンも隣接していた場合のみ攻撃（初回接触は攻撃しない）
			var dmg: int = combat_system.calculate_damage(enemy, player)
			if dmg > 0:
				player.take_damage(dmg)
				player_damaged_visual.emit(dmg)
				if enemy.boss_special_text != "":
					message.emit("%s %s %dダメージ!" % [enemy.enemy_name, enemy.boss_special_text, dmg])
				else:
					message.emit("%s の攻撃! %dダメージ!" % [enemy.enemy_name, dmg])
		enemy.was_adjacent = is_adj


func _on_environment_phase() -> void:
	pass  # 幽霊の自然回復は廃止。将来的に状態異常処理等を追加


func _on_hp_regen() -> void:
	if player.hp < player.max_hp:
		player.heal_hp(1)


# --- イベントハンドラ ---

func _on_player_dead() -> void:
	_is_game_over = true
	_delete_save()
	game_over.emit()


func _on_enemy_defeated(enemy: Node) -> void:
	var level_before: int = player.level
	score_system.register_kill(enemy.exp_reward)
	player.gain_exp(enemy.exp_reward)

	# レベルアップ検知
	if player.level > level_before:
		player_leveled_up_visual.emit(player.level)

	# ボス撃破: 定理を確定ドロップ + MP回復 + 階段出現
	if enemy.ai_pattern == EnemyScript.AIPattern.BOSS:
		score_system.register_boss_kill(0)
		_drop_boss_theorem()
		# MP回復アイテム付与
		player.add_item("wisdom_water")
		message.emit("知恵の水を手に入れた!")
		# 階段を出現させる
		if _is_boss_floor:
			var sp: Vector2i = map_generator.get_stairs_position()
			grid[sp.y][sp.x] = MapGen.Tile.STAIRS
			boss_defeated_stairs.emit(sp)
			message.emit("階段が現れた!")

	enemy_defeated_visual.emit(enemy)
	if enemy.value == 0:
		score_system.register_perfect_kill()
		if score_system.combo_count >= 2:
			combo_visual.emit(score_system.combo_count)
		message.emit("%s を倒した! コンボ x%d!" % [enemy.enemy_name, score_system.combo_count])
	else:
		message.emit("%s を倒した!" % enemy.enemy_name)


func _drop_boss_theorem() -> void:
	if not EnemyScript.BOSS_DATA.has(current_stage):
		return
	var theorem_id: String = str(EnemyScript.BOSS_DATA[current_stage]["theorem_id"])
	if theorem_id != "" and not knowledge_system.is_acquired(theorem_id):
		_acquire_knowledge(theorem_id)
		message.emit("ボスから定理を手に入れた!")


func _on_enemy_ghostified() -> void:
	score_system.register_ghost()
	enemy_ghostified_visual.emit()


# --- ヘルパー ---

func _get_enemy_at(pos: Vector2i) -> Node:
	for enemy in enemies:
		if enemy.grid_pos == pos and enemy.state != EnemyScript.EnemyState.DEFEATED:
			return enemy
	return null


func _is_occupied(pos: Vector2i) -> bool:
	for e in enemies:
		if e.grid_pos == pos and e.state != EnemyScript.EnemyState.DEFEATED:
			return true
	return false


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff: Vector2i = a - b
	return (absi(diff.x) + absi(diff.y)) == 1


# --- セーブ ---

func _auto_save() -> void:
	var sm: Node = SaveMgr.new()
	sm.save_game(self)
	sm.free()
	message.emit("セーブしました")


func _delete_save() -> void:
	var sm: Node = SaveMgr.new()
	sm.delete_save()
	sm.free()
