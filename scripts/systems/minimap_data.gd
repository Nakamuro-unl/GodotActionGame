extends Node

## ミニマップの探索済みデータを管理する。
## 描画はInGameシーン側で行う。

var _explored: Dictionary = {}  # Vector2i -> true
var _width: int = 0
var _height: int = 0


## フロア初期化（探索データをリセット）
func init_floor(width: int, height: int) -> void:
	_explored.clear()
	_width = width
	_height = height


## プレイヤー周辺を探索済みにする
func explore_around(center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if pos.x >= 0 and pos.x < _width and pos.y >= 0 and pos.y < _height:
				_explored[pos] = true


## 全マップを探索済みにする（マップの欠片使用時）
func reveal_all() -> void:
	for y in _height:
		for x in _width:
			_explored[Vector2i(x, y)] = true


## 指定位置が探索済みか
func is_explored(pos: Vector2i) -> bool:
	return _explored.has(pos)


## 探索済み位置の一覧を返す
func get_explored_positions() -> Array:
	return _explored.keys()
