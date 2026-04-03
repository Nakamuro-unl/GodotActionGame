extends RefCounted

## GameSessionで使用する定数データ（敵テーブル、配置パラメータ）。

const EnemyScript = preload("res://scripts/entities/enemy.gd")

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

## 宝箱配置テーブル: [min, max]
const STAGE_CHEST_COUNT: Dictionary = {
	1: Vector2i(2, 3),
	2: Vector2i(2, 3),
	3: Vector2i(1, 3),
	4: Vector2i(1, 2),
	5: Vector2i(1, 2),
}
