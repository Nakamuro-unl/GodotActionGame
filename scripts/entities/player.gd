extends Node

## プレイヤーキャラクター（数学魔道士）のデータと操作。
## グリッド上の位置、ステータス、技スロット、アイテムを管理する。

signal moved(old_pos: Vector2i, new_pos: Vector2i)
signal dead()
signal leveled_up(new_level: int)

const MG = preload("res://scripts/systems/map_generator.gd")

const MAX_SKILL_SLOTS: int = 6
const MAX_ITEMS: int = 10
const HP_PER_LEVEL: int = 5
const MP_PER_LEVEL: int = 3

var grid_pos: Vector2i = Vector2i.ZERO
var hp: int = 30
var max_hp: int = 30
var mp: int = 10
var max_mp: int = 10
var level: int = 1
var exp: int = 0
var skill_slots: Array = []
var items: Array[String] = []


func setup(grid: Array, start_pos: Vector2i) -> void:
	grid_pos = start_pos
	hp = max_hp
	mp = max_mp
	_init_skill_slots()


func _init_skill_slots() -> void:
	skill_slots.clear()
	skill_slots.resize(MAX_SKILL_SLOTS)
	skill_slots[0] = "plus_1"
	skill_slots[1] = "minus_1"
	for i in range(2, MAX_SKILL_SLOTS):
		skill_slots[i] = null


# --- 移動 ---

func try_move(direction: Vector2i, grid: Array) -> bool:
	var new_pos: Vector2i = grid_pos + direction
	if not _is_walkable(new_pos, grid):
		return false
	var old_pos := grid_pos
	grid_pos = new_pos
	moved.emit(old_pos, new_pos)
	return true


func _is_walkable(pos: Vector2i, grid: Array) -> bool:
	if pos.y < 0 or pos.y >= grid.size():
		return false
	if pos.x < 0 or pos.x >= grid[0].size():
		return false
	var tile: int = grid[pos.y][pos.x]
	return tile != MG.Tile.WALL


# --- HP ---

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	if hp == 0:
		dead.emit()


func heal_hp(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


# --- MP ---

func consume_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true


func heal_mp(amount: int) -> void:
	mp = mini(mp + amount, max_mp)


# --- 技スロット ---

func equip_skill(slot_index: int, skill_id: String) -> void:
	if slot_index < 0 or slot_index >= MAX_SKILL_SLOTS:
		return
	skill_slots[slot_index] = skill_id


func unequip_skill(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_SKILL_SLOTS:
		return
	skill_slots[slot_index] = null


# --- 経験値・レベルアップ ---

func gain_exp(amount: int) -> void:
	exp += amount
	var required: int = _exp_to_next_level()
	while exp >= required and required > 0:
		exp -= required
		_level_up()
		required = _exp_to_next_level()


func _exp_to_next_level() -> int:
	return level * 10


func _level_up() -> void:
	level += 1
	max_hp += HP_PER_LEVEL
	max_mp += MP_PER_LEVEL
	hp = max_hp
	mp = max_mp
	leveled_up.emit(level)


# --- アイテム ---

func add_item(item_id: String) -> bool:
	if items.size() >= MAX_ITEMS:
		return false
	items.append(item_id)
	return true


func remove_item(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	return items.pop_at(index)
