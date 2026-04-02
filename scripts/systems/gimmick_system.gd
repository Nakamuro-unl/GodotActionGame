extends Node

## フィールドギミックの管理。
## マップ上の特殊タイルと数学知識の連携を担当する。

signal gimmick_resolved(pos: Vector2i, type: GimmickType)

const MG = preload("res://scripts/systems/map_generator.gd")

enum GimmickType {
	VOID_WALL,      # 「無」の壁（ステージ1）
	ICE_WALL,       # 氷壁（ステージ1）
	HIDDEN_PATH,    # 隠し通路（ステージ2）
	CIPHER_DOOR,    # 暗号扉（ステージ2）
	LOCKED_DOOR,    # 鍵付き扉（ステージ3）
	GRAVITY_SW,     # 重力反転スイッチ（ステージ3）
	WARP_ZONE,      # ワープゾーン（ステージ4）
	INF_CORRIDOR,   # 無限回廊（ステージ4）
	SPACE_WARP,     # 空間歪み（ステージ5）
	FINAL_DOOR,     # 最終扉（ステージ5）
}

## ギミック→必要知識のマッピング
const GIMMICK_KNOWLEDGE: Dictionary = {
	GimmickType.VOID_WALL:    "K-104",
	GimmickType.ICE_WALL:     "K-105",
	GimmickType.HIDDEN_PATH:  "K-106",
	GimmickType.CIPHER_DOOR:  "K-206",
	GimmickType.LOCKED_DOOR:  "K-306",
	GimmickType.GRAVITY_SW:   "K-302",
	GimmickType.WARP_ZONE:    "K-404",
	GimmickType.INF_CORRIDOR: "K-406",
	GimmickType.SPACE_WARP:   "K-505",
	GimmickType.FINAL_DOOR:   "K-506",
}

## ギミック→解除時メッセージ
const GIMMICK_MESSAGES: Dictionary = {
	GimmickType.VOID_WALL:    "零の力で「無」の壁が消えた!",
	GimmickType.ICE_WALL:     "負の数で温度を反転! 氷壁が溶けた!",
	GimmickType.HIDDEN_PATH:  "数直線の知識で隠し通路を発見した!",
	GimmickType.CIPHER_DOOR:  "約数で暗号を解読! 扉が開いた!",
	GimmickType.LOCKED_DOOR:  "一次方程式を解いて開錠した!",
	GimmickType.GRAVITY_SW:   "符号反転で重力を操作した!",
	GimmickType.WARP_ZONE:    "対数でワープを制御した!",
	GimmickType.INF_CORRIDOR: "極限の知識で無限回廊を有限化した!",
	GimmickType.SPACE_WARP:   "位相変換で空間の歪みを整理した!",
	GimmickType.FINAL_DOOR:   "無限の概念を理解し、最終扉が開いた!",
}

## ステージ別出現ギミック
const STAGE_GIMMICKS: Dictionary = {
	1: [GimmickType.VOID_WALL, GimmickType.ICE_WALL],
	2: [GimmickType.HIDDEN_PATH, GimmickType.CIPHER_DOOR],
	3: [GimmickType.LOCKED_DOOR, GimmickType.GRAVITY_SW],
	4: [GimmickType.WARP_ZONE, GimmickType.INF_CORRIDOR],
	5: [GimmickType.SPACE_WARP, GimmickType.FINAL_DOOR],
}

## 配置されたギミック: { Vector2i -> { type, required_knowledge } }
var _gimmicks: Dictionary = {}


## ギミックを配置する
func place_gimmick(pos: Vector2i, type: GimmickType, required_knowledge: String) -> void:
	_gimmicks[pos] = {
		"type": type,
		"required_knowledge": required_knowledge,
	}


## 全ギミックをクリア（フロア遷移時）
func clear_gimmicks() -> void:
	_gimmicks.clear()


## 指定位置にギミックがあるか
func has_gimmick_at(pos: Vector2i) -> bool:
	return _gimmicks.has(pos)


## 指定位置のギミック情報
func get_gimmick_at(pos: Vector2i) -> Dictionary:
	if not _gimmicks.has(pos):
		return {}
	return _gimmicks[pos]


## ギミック解除を試みる
func try_resolve(pos: Vector2i, knowledge_system: Node, grid: Array) -> Dictionary:
	if not _gimmicks.has(pos):
		return {"success": false, "message": ""}

	var gimmick: Dictionary = _gimmicks[pos]
	var required: String = gimmick["required_knowledge"]

	if not knowledge_system.is_acquired(required):
		var knowledge_name: String = ""
		var info: Dictionary = knowledge_system.get_info(required)
		if not info.is_empty():
			knowledge_name = info["name"]
		return {"success": false, "message": "何かがあるが、理解できない..."}

	var gtype: int = gimmick["type"]

	# グリッドを床に変更
	if pos.y >= 0 and pos.y < grid.size() and pos.x >= 0 and pos.x < grid[0].size():
		grid[pos.y][pos.x] = MG.Tile.FLOOR

	var msg: String = GIMMICK_MESSAGES.get(gtype, "ギミックを解除した!")
	_gimmicks.erase(pos)
	gimmick_resolved.emit(pos, gtype)

	return {"success": true, "message": msg}


## ステージに対応するギミックタイプ一覧
static func get_gimmick_types_for_stage(stage: int) -> Array:
	var result: Array = []
	for s in STAGE_GIMMICKS:
		if s <= stage:
			for g in STAGE_GIMMICKS[s]:
				result.append(g)
	return result
