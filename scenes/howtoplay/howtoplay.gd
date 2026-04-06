extends Control

## あそびかた画面。操作説明とゲームルール。

const GMS = preload("res://scripts/autoload/game_manager.gd")

var _page: int = 0
var _pages: Array[String] = []


func _ready() -> void:
	_build_pages()
	_display_page()
	$HBox/BtnPrev.pressed.connect(_prev_page)
	$HBox/BtnNext.pressed.connect(_next_page)
	$HBox/BtnBack.pressed.connect(_go_back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_next_page()
	elif event.is_action_pressed("ui_left"):
		_prev_page()


func _next_page() -> void:
	_page = mini(_page + 1, _pages.size() - 1)
	_display_page()


func _prev_page() -> void:
	_page = maxi(_page - 1, 0)
	_display_page()


func _go_back() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.change_state(GMS.State.TITLE)


func _display_page() -> void:
	var label: Label = get_node_or_null("HowToPlayLabel")
	if label:
		label.text = _pages[_page]


func _build_pages() -> void:
	_pages.append(
		"=== あそびかた (1/4) ===\n\n" +
		"[ゲームの目的]\n\n" +
		"数学の知識を武器に戦う魔道士となり、\n" +
		"全25フロアのダンジョンを踏破せよ!\n\n" +
		"敵の頭上に表示された数値を\n" +
		"ぴったり「0」にして倒そう。\n\n" +
		"宝箱から数学の知識を集めて\n" +
		"新しい技を覚えていこう。\n\n" +
		"(右キー: 次へ / Esc: 戻る)"
	)
	_pages.append(
		"=== 操作方法 (2/4) ===\n\n" +
		"[PC]\n" +
		"  矢印キー : 移動\n" +
		"  Shift+矢印 : 方向転換(ターン消費なし)\n" +
		"  1-6キー : 技を使用(向いている方向)\n" +
		"  Iキー : アイテムメニュー\n" +
		"  Enter : 調べる(階段/宝箱/ギミック)\n" +
		"  Esc : インベントリ(技の装備変更)\n" +
		"  Space : 待機\n\n" +
		"[モバイル]\n" +
		"  十字キー + 移動/転換切替ボタン\n" +
		"  技ボタン / 待機 / 調べる / menu\n\n" +
		"(右キー: 次へ / 左キー: 前へ)"
	)
	_pages.append(
		"=== 戦闘のコツ (3/4) ===\n\n" +
		"[基本] -1で地道に削る\n" +
		"[応用] /2で大きい数を半分に\n" +
		"[上級] %4で4の倍数を即0化\n" +
		"[最強] x0 で一撃!(3回限定)\n\n" +
		"数値が負になると幽霊化!\n" +
		"  -> 壁を通過してくる\n" +
		"  -> abs()や+系で0に戻そう\n\n" +
		"ぴったり0で倒すとコンボ加算!\n" +
		"幽霊化させるとコンボリセット...\n\n" +
		"(右キー: 次へ / 左キー: 前へ)"
	)
	_pages.append(
		"=== スコアについて (4/4) ===\n\n" +
		"[加点]\n" +
		"  撃破: 敵の経験値 x10\n" +
		"  フロア: 到達フロア x1000\n" +
		"  ボス: 撃破 x5000\n" +
		"  知識: 獲得数 x300\n" +
		"  コンボ: 連続0撃破で累積加算\n\n" +
		"[減点]\n" +
		"  ターン: 総ターン x1\n" +
		"  幽霊化: 回数 x30\n\n" +
		"ゲームオーバーでもスコアは残る!\n" +
		"ランキングTOP10に挑戦しよう!\n\n" +
		"[攻略ガイド]\n" +
		"nakamuro-unl.github.io/mathmage-web/guide/\n\n" +
		"(Esc: タイトルへ)"
	)
