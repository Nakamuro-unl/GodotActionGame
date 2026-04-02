# Godot アクションゲーム - 言語選定調査

- 日付: 2026-04-02
- 担当: AI (Claude)

## 入力パラメータ

- 目的: Godotでアクションゲームを開発するにあたり、AI支援に最適なスクリプト言語を選定する
- 対象エンジン: Godot Engine (最新安定版)

## 実行されたコマンド

- Web検索: "Godot Engine latest stable version 2026"
- Web検索: "Godot Engine best scripting language AI code generation 2026"
- Web検索: "GDScript performance optimization tips action game Godot 4 2025 2026"
- Web検索: "Godot 4 GDScript best practices performance physics action game"
- WebFetch: GDQuest - Optimizing GDScript code
- WebFetch: GDQuest - Making the most of Godot's speed

## 調査結果

### Godot最新バージョン

Godot 4.6.2（2026年4月1日リリース）

### 言語比較

| 言語 | AI適性 | パフォーマンス | Godot統合 | 推薦度 |
|------|--------|---------------|-----------|--------|
| GDScript | 最高 | 十分 | 最深 | 最推薦 |
| C# | 高 | 良好 | やや複雑 | 次点 |
| C++ (GDExtension) | 低 | 最高 | ビルド複雑 | 部分利用 |

### 決定

**GDScript** を採用。理由:
- AI生成コードの正確性が最も高い（約850クラスの限定的なAPI）
- ゲーム専用設計で他ドメインのパターンが混入しない
- テキストベースで可読性が高くAI支援との相性が良い
- パフォーマンスが問題になる箇所のみGDExtensionで補完可能

## ファイル変更

- 作成: `docs/gdscript_performance_guide.md` - パフォーマンスガイド

## 参考ソース

- https://github.com/godotengine/godot/releases
- https://dev.to/ziva/why-godots-architecture-makes-it-the-best-engine-for-ai-assisted-development-5e8f
- https://dev.to/mistyhx/why-ai-writes-better-game-code-in-godot-than-in-unity-10hf
- https://docs.godotengine.org/en/stable/tutorials/performance/index.html
- https://www.gdquest.com/tutorial/godot/gdscript/optimization-code/
- https://www.gdquest.com/tutorial/godot/gdscript/optimization-engine/
