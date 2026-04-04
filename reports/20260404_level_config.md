# レベルデザイン設定ツール実装ログ

- 日付: 2026-04-04
- 担当: AI (Claude)

## 入力パラメータ

- 敵出現確率の重み付け
- アイテムドロップのレアリティ・ステージ制限
- 宝箱の知識/アイテム配分

## ファイル変更

### 作成
- `docs/specs/14_level_config.md` - レベルデザイン設定仕様書
- `scripts/systems/drop_table.gd` - 重み付き抽選・レベル設定管理
- `tests/test_drop_table.gd` - 14件のテスト

### 変更
- `scripts/systems/floor_builder.gd` - DropTable連携（敵生成を重み付きに）
- `scripts/systems/game_session.gd` - DropTable組み込み、宝箱のアイテム抽選
- `docs/specs/README.md` - 14番追加

## テスト結果

全216テストPASS（新規14件追加）

## コンソール出力/エラー

なし
