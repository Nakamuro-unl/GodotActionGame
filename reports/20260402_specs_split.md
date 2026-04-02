# 仕様書分割ログ

- 日付: 2026-04-02
- 担当: AI (Claude)

## 入力パラメータ

- 目安: 150行以上のファイルを分割
- 親ファイルはインデックス化

## 実行されたコマンド

- wc -l で各ファイルの行数確認
- mkdir で各サブディレクトリ作成

## ファイル変更

### 分割対象と結果

| 元ファイル | 元行数 | 分割先 |
|-----------|--------|--------|
| 04_combat.md | 134行 | 04a_combat_rules.md + 04b_skill_list.md |
| 05_enemy.md | 163行 | 05a_enemy_list.md + 05b_enemy_ai.md |
| 08_score.md | 137行 | 08a_score_calc.md + 08b_ranking.md |
| 09_ui.md | 219行 | 09a_screens.md + 09b_hud_effects.md |

### インデックス化

- 04_combat.md → インデックス（サブ仕様書リンク + 受け入れ条件一覧）
- 05_enemy.md → インデックス
- 08_score.md → インデックス
- 09_ui.md → インデックス

## コンソール出力/エラー

なし
