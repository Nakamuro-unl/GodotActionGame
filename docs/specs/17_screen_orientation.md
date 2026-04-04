# 17 画面向き・解像度対応仕様書

## 概要

PCでは横画面（Landscape）、モバイルでは縦画面（Portrait）で動作する。基本解像度を設定し、Godotのストレッチ機能で自動スケーリングする。

---

## 解像度設定

| | PC (Landscape) | モバイル (Portrait) |
|---|---|---|
| 基本解像度 | 640x480 | 360x640 |
| アスペクト比 | 4:3 | 9:16 |
| ストレッチモード | viewport | viewport |
| カメラzoom | 2.0 | 2.5 |

---

## 画面向き制御

```gdscript
# モバイルの場合
DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
# PCの場合
DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
```

---

## HUDレイアウト

### PC（横画面）

```
[HP/MP/Lv/Floor/Turn/向き]                [Minimap]  [FPS]
+----------------------------------------------+
|                                              |
|              ダンジョンマップ                  |
|                                              |
+----------------------------------------------+
[icon][1]技  [icon][2]技  [3]---  ...
メッセージログ
キーボードヒント
```

### モバイル（縦画面）

```
[HP/MP/Lv/Floor/Turn]
[Minimap]
+----------------------+
|                      |
|   ダンジョンマップ    |
|                      |
+----------------------+
メッセージログ
[icon]技1 [icon]技2 [icon]技3
[icon]技4 [icon]技5 [icon]技6
[待機] [調べる] [menu]
   [^]
 [< >]
   [v]
[移動/転換]
```

---

## 実装方式

1. `PlatformUI` でプラットフォーム判定
2. 起動時に `DisplayServer` で画面向きを設定
3. `project.godot` の基本解像度はPC用（640x480）
4. モバイル時は `get_viewport().size` を動的に変更し、カメラzoomを調整
5. HUDノードの位置をスクリプトで再配置

---

## 受け入れ条件

| ID | 条件 |
|----|------|
| AC-SCR-001 | PCで横画面（640x480）で表示される |
| AC-SCR-002 | モバイルで縦画面（360x640）で表示される |
| AC-SCR-003 | HUDが各画面向きに適切に配置される |
| AC-SCR-004 | マップの表示範囲が画面サイズに応じて調整される |
