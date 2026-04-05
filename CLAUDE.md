# CLAUDE.md - Math Mage 開発ルール

## プロジェクト概要

- タイトル: Math Mage（マスメイジ）
- ジャンル: 2D 数学ローグライクRPG
- エンジン: Godot 4.6 / GDScript
- テスト: GdUnit4

## 開発方針

### テスト駆動開発（TDD）

- 新機能は必ずテストを先に書き、その後実装する（Red -> Green -> Refactor）
- テストファイルは `tests/` に配置、命名は `test_<対象>.gd`
- テスト実行: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/`
- コミット前に全テストPASSを確認する

### 仕様駆動開発

- 実装前に `docs/specs/` に仕様書を作成する
- 受け入れ条件（AC-XXX-NNN）を定義し、テストと対応させる
- 仕様変更時は仕様書を先に更新してから実装に反映する

## コードルール

### ファイルサイズ上限

- 1ファイル300行以下を目安とする
- 超える場合は機能分割する:
  - 定数/データ定義 -> `*_data.gd` (RefCounted)
  - 描画処理 -> `*_renderer.gd` (RefCounted)
  - 生成処理 -> `*_builder.gd` (RefCounted)
- GDScriptにpartialはないため、preloadで参照する分割方式を使う

### GDScript規約

- 全変数・関数に型ヒントを付ける
- `:=` による型推論は避け、明示的な型宣言 `var x: Type = ...` を使う
- ラムダでのintキャプチャは `var counter := [0]` パターンを使う
- AutoLoadに `class_name` を付けない（名前衝突を回避）

### コミット

- 機能ごとに小さくコミットする
- メッセージは日本語で、prefixは feat/fix/refactor/perf/docs
- 末尾に `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`

## プロジェクト構成

```
scripts/
  autoload/       -- GameManager等のAutoLoad
  systems/        -- ゲームシステム（ターン、戦闘、スコア等）
  entities/       -- プレイヤー、敵
scenes/
  ingame/         -- InGameシーン + renderer/data分割
  title/          -- タイトル画面
  ui/             -- バーチャルパッド、ポップアップ等
  result/ranking/howtoplay/settings/
tests/            -- GdUnit4テスト
docs/
  specs/          -- 仕様書（150行以下に分割）
  gdscript_performance_guide.md
assets/
  sprites/        -- 128x128スプライト、1024x1280アトラス(69タイル)
  sounds/         -- SE(10種) + BGM(7トラック) WAV
  fonts/          -- NotoSansCJKjp-Medium + デフォルトテーマ
  web/            -- カスタムHTMLシェル
reports/          -- 操作ログ
docs/guide/       -- 攻略サイト(HTML)
scripts/build/    -- ビルド/デプロイスクリプト
.github/workflows/ -- CI/CD(テスト→Webビルド→GitHub Pagesデプロイ)
```

## ビルド

```bash
# テストのみ
./scripts/build/build.sh test

# iOS
./scripts/build/build.sh ios

# Android
./scripts/build/build.sh android

# Web + GitHub Pagesデプロイ
./scripts/build/deploy_web.sh

# CI: masterにpushすると自動でテスト→Webビルド→デプロイ
```

## 操作ルール（CLAUDE.mdより継承）

1. 実行前確認: 操作前にユーザーの承認を得る
2. 自律的代替案の禁止: 失敗時は新計画を提示して承認を得る
3. 全操作のログ記録: /reports/に記録を保存
4. ルールの最優先遵守
5. セッション開始時のルール表示
6. 絵文字の禁止
