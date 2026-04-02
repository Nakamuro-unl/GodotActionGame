# メインフロー実装ログ

- 日付: 2026-04-02
- 担当: AI (Claude)

## 入力パラメータ

- 仕様: docs/specs/10_main_flow.md
- 方針: TDD（テスト先行）
- テストフレームワーク: GdUnit4 v6.1.3

## 実行されたコマンド

- mkdir: プロジェクトフォルダ構成作成
- git clone: GdUnit4をtmpにクローン
- cp: addons/gdUnit4 にコピー

## ファイル変更

### 作成

- `docs/specs/10_main_flow.md` - メインフロー仕様書
- `scripts/autoload/game_manager.gd` - 状態管理AutoLoad
- `tests/test_game_manager.gd` - GameManagerのユニットテスト（12テスト）
- `scenes/title/title.tscn` + `title.gd` - タイトル画面
- `scenes/ingame/ingame.tscn` + `ingame.gd` - インゲーム画面（プレースホルダ）
- `scenes/result/result.tscn` + `result.gd` - リザルト画面（プレースホルダ）
- `scenes/ranking/ranking.tscn` + `ranking.gd` - ランキング画面（プレースホルダ）
- `scenes/howtoplay/howtoplay.tscn` + `howtoplay.gd` - あそびかた画面（プレースホルダ）
- `scenes/settings/settings.tscn` + `settings.gd` - せってい画面（プレースホルダ）
- `addons/gdUnit4/` - テストフレームワーク

### 変更

- `project.godot` - メインシーン、AutoLoad、画面サイズ、プラグイン設定
- `.gitignore` - GdUnit4レポート除外追加
- `docs/specs/README.md` に10_main_flowの追記が必要（次回）

## テスト一覧

| テスト名 | 対応AC | 内容 |
|---------|--------|------|
| test_initial_state_is_title | AC-FLOW-001 | 初期状態がTITLE |
| test_change_state_title_to_ingame | AC-FLOW-002 | TITLE→INGAME遷移 |
| test_change_state_ingame_to_result | AC-FLOW-003 | INGAME→RESULT遷移 |
| test_change_state_result_to_title | AC-FLOW-004 | RESULT→TITLE遷移 |
| test_change_state_title_to_ranking | AC-FLOW-005 | TITLE→RANKING遷移 |
| test_change_state_title_to_howtoplay | AC-FLOW-005 | TITLE→HOWTOPLAY遷移 |
| test_change_state_title_to_settings | AC-FLOW-005 | TITLE→SETTINGS遷移 |
| test_change_state_ranking_to_title | AC-FLOW-005 | RANKING→TITLE遷移 |
| test_invalid_transition_ingame_to_title | - | 不正遷移の拒否 |
| test_invalid_transition_result_to_ingame | - | 不正遷移の拒否 |
| test_state_changed_signal_emitted | AC-FLOW-006 | シグナル発火確認 |
| test_full_main_flow | 全体 | メインフロー一周 |

## コンソール出力/エラー

テストはGodotエディタからGdUnit4で実行する必要がある（CLIでの実行にはGodotバイナリが必要）
