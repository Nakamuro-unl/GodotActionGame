# 10 メインフロー仕様書

## 概要

起動からタイトル、インゲーム、リザルトを経てタイトルに戻るまでのゲーム全体の画面遷移を定義する。

---

## 画面遷移図

```
起動 → Title → InGame → Result → Title
                                    ↑
         Title → Ranking ──────────┘
         Title → HowToPlay ────────┘
         Title → Settings ──────────┘
```

---

## ゲーム状態（State）

| State | 画面 | 遷移先 | トリガー |
|-------|------|--------|---------|
| TITLE | タイトル画面 | INGAME, RANKING, HOWTOPLAY, SETTINGS | メニュー選択 |
| INGAME | ダンジョン探索 | RESULT | HP=0 or 25Fクリア |
| RESULT | スコア表示 | TITLE | 決定キー |
| RANKING | ランキング表示 | TITLE | 戻るキー |
| HOWTOPLAY | 遊び方表示 | TITLE | 戻るキー |
| SETTINGS | 設定画面 | TITLE | 戻るキー |

---

## シーン構成

| State | シーンファイル | 説明 |
|-------|--------------|------|
| TITLE | `scenes/title/title.tscn` | タイトル画面 |
| INGAME | `scenes/ingame/ingame.tscn` | ダンジョン探索メイン |
| RESULT | `scenes/result/result.tscn` | スコア表示 |
| RANKING | `scenes/ranking/ranking.tscn` | ランキング一覧 |
| HOWTOPLAY | `scenes/howtoplay/howtoplay.tscn` | 遊び方説明 |
| SETTINGS | `scenes/settings/settings.tscn` | 設定 |

---

## 状態管理

- `GameManager` (AutoLoad) がゲーム全体の状態を管理する
- 状態遷移は `GameManager.change_state(new_state)` で行う
- シーン切り替えは `SceneTree.change_scene_to_packed()` を使用
- 遷移時にシグナル `state_changed(old_state, new_state)` を発火する

---

## 遷移の詳細

### 起動 → TITLE
- Godotのメインシーンとして `title.tscn` を設定
- GameManager が TITLE 状態で初期化される

### TITLE → INGAME
- 「はじめから」選択時
- シード値をランダム生成
- ゲームデータを初期化（HP, MP, 技スロット, アイテム等）

### INGAME → RESULT
- HP=0（ゲームオーバー）または 25Fクリア時
- ゲーム結果データ（スコア、撃破数等）をResultシーンに渡す
- クリアかゲームオーバーかの情報も渡す

### RESULT → TITLE
- 決定キー押下時
- スコアをランキングに保存（上位10件に入る場合）

### TITLE → RANKING / HOWTOPLAY / SETTINGS
- 各メニュー選択時に遷移
- 戻るキー（Esc）でTITLEに戻る

---

## 受け入れ条件

| ID | 条件 |
|----|------|
| AC-FLOW-001 | 起動時にタイトル画面が表示される |
| AC-FLOW-002 | 「はじめから」でインゲームに遷移する |
| AC-FLOW-003 | ゲームオーバー/クリアでリザルト画面に遷移する |
| AC-FLOW-004 | リザルト画面から決定キーでタイトルに戻る |
| AC-FLOW-005 | 各サブ画面（ランキング等）からタイトルに戻れる |
| AC-FLOW-006 | 画面遷移時にエラーが発生しない |
