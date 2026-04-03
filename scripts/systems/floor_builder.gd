extends RefCounted

## フロアの生成（敵・宝箱・ギミック配置）を担当する。

const MapGen = preload("res://scripts/systems/map_generator.gd")
const GimmickSys = preload("res://scripts/systems/gimmick_system.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const SessionData = preload("res://scripts/systems/game_session_data.gd")

var _rng: RandomNumberGenerator


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng


func spawn_enemies(session: Node, stage: int) -> void:
	for e in session.enemies:
		if is_instance_valid(e):
			e.queue_free()
	session.enemies.clear()

	var stage_data: Array = SessionData.STAGE_ENEMIES.get(stage, SessionData.STAGE_ENEMIES[1])
	var count_range: Vector2i = SessionData.STAGE_ENEMY_COUNT.get(stage, Vector2i(3, 5))
	var count: int = _rng.randi_range(count_range.x, count_range.y)
	var rooms: Array = session.map_generator.get_rooms()

	for i in count:
		var template: Array = stage_data[_rng.randi_range(0, stage_data.size() - 1)]
		var value: int = _rng.randi_range(template[1], template[2])
		var pos: Vector2i = _get_random_floor_pos(rooms, session)

		var enemy: Node = EnemyScript.new()
		session.add_child(enemy)
		enemy.setup(template[0], value, template[3], template[4], template[5], pos)
		enemy.defeated.connect(session._on_enemy_defeated.bind(enemy))
		enemy.ghostified.connect(session._on_enemy_ghostified)
		session.enemies.append(enemy)


func place_chests(session: Node, stage: int) -> void:
	session.chest_positions.clear()
	var count_range: Vector2i = SessionData.STAGE_CHEST_COUNT.get(stage, Vector2i(1, 2))
	var count: int = _rng.randi_range(count_range.x, count_range.y)
	var rooms: Array = session.map_generator.get_rooms()

	for i in count:
		var pos: Vector2i = _get_random_floor_pos(rooms, session)
		if pos != Vector2i(1, 1):
			session.chest_positions.append(pos)
			session.grid[pos.y][pos.x] = MapGen.Tile.CHEST


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
