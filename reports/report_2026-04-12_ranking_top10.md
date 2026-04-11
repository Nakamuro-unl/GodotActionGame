# ランキング表示をTOP10+自分の順位に変更 -- 2026-04-12

## 入力パラメータ
- 目的: ランキング件数が多くなり画面に収まらない問題を修正
- 要件: 上位10位まで表示 + 自分が何位か表示

## 実行されたコマンド
- GdUnit4テスト実行: 290テスト全PASS

## ファイル変更

### scripts/systems/supabase_ranking.gd
- TOP_LIMIT を 20 から 10 に変更
- `rank_loaded(rank: int)` シグナル追加
- `_http_rank: HTTPRequest` 追加（順位取得用の独立HTTPクライアント）
- `fetch_my_rank(score: int)` メソッド追加
  - Supabase PostgREST の `Prefer: count=exact` ヘッダを使用
  - `score=gt.{score}&limit=0` で自分より高スコアの件数を取得
  - Content-Range ヘッダからカウントを抽出し rank = count + 1
- `_on_rank_completed()` コールバック追加

### scenes/ranking/ranking.gd
- `_cached_rankings`, `_my_rank`, `_my_score` 変数追加
- `_ready()`: GameManager.last_result からスコアを取得し、fetch_my_rank() を並行呼び出し
- `_on_rankings_loaded()`: キャッシュに保存して表示（タブ切替時の再取得を回避）
- `_on_rank_loaded()`: 順位をキャッシュし、オンラインタブ表示中なら再描画
- `_display_online_ranking()`: TOP 10表示 + 自分の順位を区切り線の下に表示
- ヘッダ表示を "TOP 20" から "TOP 10" に変更

## 動作仕様
- オンラインタブ: TOP 10 + 自分の順位（直近プレイがある場合のみ）
- ローカルタブ: TOP 10（変更なし）
- タイトルから直接ランキングを見た場合: last_resultが空なので順位表示はスキップ
