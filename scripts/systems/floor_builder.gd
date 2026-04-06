extends RefCounted

## フロアの生成（敵・宝箱・ギミック配置）を担当する。
## 敵の出現はDropTableの重み付き抽選を使用する。

const MapGen = preload("res://scripts/systems/map_generator.gd")
const GimmickSys = preload("res://scripts/systems/gimmick_system.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const SessionData = preload("res://scripts/systems/game_session_data.gd")

var _rng: RandomNumberGenerator
var _drop_table: Node


func setup(rng: RandomNumberGenerator, drop_table: Node) -> void:
	_rng = rng
	_drop_table = drop_table


func spawn_enemies(session: Node, stage: int, is_boss_floor: bool = false) -> void:
	for e in session.enemies:
		if is_instance_valid(e):
			e.queue_free()
	session.enemies.clear()

	var rooms: Array = session.map_generator.get_rooms()

	# ボスフロア: ボスを配置
	if is_boss_floor and EnemyScript.BOSS_DATA.has(stage):
		_spawn_boss(session, stage, rooms)

	# 通常敵を配置
	var count_range: Vector2i = SessionData.STAGE_ENEMY_COUNT.get(stage, Vector2i(3, 5))
	var count: int = _rng.randi_range(count_range.x, count_range.y)
	if is_boss_floor:
		count = maxi(count - 2, 1)  # ボスフロアは通常敵を減らす

	for i in count:
		var template: Dictionary = _drop_table.pick_enemy_template(stage)
		var value: int = _rng.randi_range(int(template["value_min"]), int(template["value_max"]))
		var pos: Vector2i = _get_random_floor_pos(rooms, session)

		var enemy: Node = EnemyScript.new()
		session.add_child(enemy)
		enemy.setup(str(template["name"]), value, int(template["attack"]), int(template["exp"]), int(template["ai"]), pos)
		enemy.defeated.connect(session._on_enemy_defeated.bind(enemy))
		enemy.ghostified.connect(session._on_enemy_ghostified)
		session.enemies.append(enemy)


## ボス封印に必要な知識（ステージ別）
const BOSS_SEAL_KNOWLEDGE: Dictionary = {
	1: {"gimmick": GimmickSys.GimmickType.VOID_WALL, "knowledge": "K-104"},
	2: {"gimmick": GimmickSys.GimmickType.CIPHER_DOOR, "knowledge": "K-206"},
	3: {"gimmick": GimmickSys.GimmickType.LOCKED_DOOR, "knowledge": "K-306"},
	4: {"gimmick": GimmickSys.GimmickType.INF_CORRIDOR, "knowledge": "K-406"},
	5: {"gimmick": GimmickSys.GimmickType.FINAL_DOOR, "knowledge": "K-506"},
}


func _spawn_boss(session: Node, stage: int, rooms: Array) -> void:
	var data: Dictionary = EnemyScript.BOSS_DATA[stage]
	var stairs_pos: Vector2i = session.map_generator.get_stairs_position()
	var boss_pos: Vector2i = Vector2i(stairs_pos.x + 1, stairs_pos.y)
	if boss_pos.x >= MapGen.GRID_WIDTH - 1 or session.grid[boss_pos.y][boss_pos.x] == MapGen.Tile.WALL:
		boss_pos = _get_random_floor_pos(rooms, session)

	var boss: Node = EnemyScript.new()
	session.add_child(boss)
	boss.setup(str(data["name"]), int(data["value"]), int(data["attack"]), int(data["exp"]), EnemyScript.AIPattern.BOSS, boss_pos)
	boss.defeated.connect(session._on_enemy_defeated.bind(boss))
	boss.ghostified.connect(session._on_enemy_ghostified)
	session.enemies.append(boss)

	# ボス部屋の封印ギミックを配置
	_place_boss_seal(session, stage, rooms, boss_pos)


func _place_boss_seal(session: Node, stage: int, rooms: Array, boss_pos: Vector2i) -> void:
	if not BOSS_SEAL_KNOWLEDGE.has(stage):
		return
	var seal: Dictionary = BOSS_SEAL_KNOWLEDGE[stage]
	# ボスの部屋の入口付近に封印壁を配置
	# ボス位置から最も近い壁タイルを探す
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		for dist in range(1, 5):
			var wall_pos: Vector2i = boss_pos + dir * dist
			if wall_pos.x > 0 and wall_pos.x < MapGen.GRID_WIDTH - 1 and wall_pos.y > 0 and wall_pos.y < MapGen.GRID_HEIGHT - 1:
				if session.grid[wall_pos.y][wall_pos.x] == MapGen.Tile.WALL:
					session.gimmick_system.place_gimmick(wall_pos, seal["gimmick"], seal["knowledge"])
					return


func place_boss_floor_chest(session: Node, stage: int) -> void:
	## ボスフロアに封印解除用の知識を含む宝箱を確定配置
	if not BOSS_SEAL_KNOWLEDGE.has(stage):
		return
	var seal_knowledge_id: String = BOSS_SEAL_KNOWLEDGE[stage]["knowledge"]
	# 既に持っていたら不要
	if session.knowledge_system.is_acquired(seal_knowledge_id):
		return
	# プレイヤーの部屋に宝箱を配置
	var rooms: Array = session.map_generator.get_rooms()
	if rooms.is_empty():
		return
	var room: Rect2i = rooms[0]
	var cx: int = room.position.x + room.size.x / 2 + 1
	var cy: int = room.position.y + room.size.y / 2
	var pos: Vector2i = Vector2i(cx, cy)
	session.chest_positions.append(pos)
	session.grid[pos.y][pos.x] = MapGen.Tile.CHEST
	# この宝箱は封印解除知識を確定で出す
	session._boss_seal_chest_pos = pos
	session._boss_seal_knowledge_id = seal_knowledge_id


func place_chests(session: Node, stage: int, is_first_floor: bool = false) -> void:
	session.chest_positions.clear()

	# 開始部屋に宝箱を確定配置（1Fのみ）
	if is_first_floor:
		_place_start_room_chest(session)

	var count_range: Vector2i = SessionData.STAGE_CHEST_COUNT.get(stage, Vector2i(1, 2))
	var count: int = _rng.randi_range(count_range.x, count_range.y)
	var rooms: Array = session.map_generator.get_rooms()

	var stairs_pos: Vector2i = session.map_generator.get_stairs_position()
	for i in count:
		var pos: Vector2i = _get_random_floor_pos(rooms, session)
		if pos != Vector2i(1, 1) and pos != stairs_pos:
			session.chest_positions.append(pos)
			session.grid[pos.y][pos.x] = MapGen.Tile.CHEST


func _place_start_room_chest(session: Node) -> void:
	## 開始部屋（プレイヤーの部屋）に宝箱を1個配置
	var rooms: Array = session.map_generator.get_rooms()
	if rooms.is_empty():
		return
	var start_room: Rect2i = rooms[0]
	# プレイヤー位置から少しずらした位置に配置
	var cx: int = start_room.position.x + start_room.size.x / 2
	var cy: int = start_room.position.y + start_room.size.y / 2 + 1
	if cy >= start_room.position.y + start_room.size.y:
		cy = start_room.position.y + start_room.size.y - 1
	var pos: Vector2i = Vector2i(cx, cy)
	session.chest_positions.append(pos)
	session.grid[pos.y][pos.x] = MapGen.Tile.CHEST
	# 開始部屋の宝箱は固定知識を設定
	session._start_chest_pos = pos


func place_gimmicks(session: Node, stage: int) -> void:
	session.gimmick_system.clear_gimmicks()
	var types: Array = GimmickSys.get_gimmick_types_for_stage(stage)
	if types.is_empty():
		return

	var rooms: Array = session.map_generator.get_rooms()
	var count: int = _rng.randi_range(0, mini(2, types.size()))

	for i in count:
		var gtype: int = types[_rng.randi_range(0, types.size() - 1)]
		var required: String = GimmickSys.GIMMICK_KNOWLEDGE.get(gtype, "")
		if required == "":
			continue
		var pos: Vector2i = _find_gimmick_wall_pos(rooms, session.grid)
		if pos != Vector2i.ZERO:
			session.gimmick_system.place_gimmick(pos, gtype, required)


func _get_random_floor_pos(rooms: Array, session: Node) -> Vector2i:
	for attempt in 50:
		var room_idx: int = _rng.randi_range(1, rooms.size() - 1)
		var room: Rect2i = rooms[room_idx]
		var x: int = _rng.randi_range(room.position.x, room.position.x + room.size.x - 1)
		var y: int = _rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
		var pos: Vector2i = Vector2i(x, y)
		if pos != session.player.grid_pos and not _is_occupied(pos, session):
			return pos
	return Vector2i(1, 1)


func _is_occupied(pos: Vector2i, session: Node) -> bool:
	for e in session.enemies:
		if e.grid_pos == pos and e.state != EnemyScript.EnemyState.DEFEATED:
			return true
	return false


func _find_gimmick_wall_pos(rooms: Array, grid: Array) -> Vector2i:
	for attempt in 30:
		var room_idx: int = _rng.randi_range(0, rooms.size() - 1)
		var room: Rect2i = rooms[room_idx]
		var side: int = _rng.randi_range(0, 3)
		var wall_pos: Vector2i
		match side:
			0:
				wall_pos = Vector2i(_rng.randi_range(room.position.x, room.position.x + room.size.x - 1), room.position.y - 1)
			1:
				wall_pos = Vector2i(_rng.randi_range(room.position.x, room.position.x + room.size.x - 1), room.position.y + room.size.y)
			2:
				wall_pos = Vector2i(room.position.x - 1, _rng.randi_range(room.position.y, room.position.y + room.size.y - 1))
			3:
				wall_pos = Vector2i(room.position.x + room.size.x, _rng.randi_range(room.position.y, room.position.y + room.size.y - 1))

		if wall_pos.x > 0 and wall_pos.x < MapGen.GRID_WIDTH - 1 and wall_pos.y > 0 and wall_pos.y < MapGen.GRID_HEIGHT - 1:
			if grid[wall_pos.y][wall_pos.x] == MapGen.Tile.WALL:
				return wall_pos
	return Vector2i.ZERO
