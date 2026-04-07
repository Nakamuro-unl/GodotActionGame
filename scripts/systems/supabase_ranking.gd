extends Node

## Supabaseオンラインランキング。HTTPRequestでREST API通信。
## キーは設定ファイルから読み込み、ソースにはフォールバック値のみ。

signal rankings_loaded(rankings: Array)
signal score_submitted(success: bool)

const TABLE: String = "rankings"
const TOP_LIMIT: int = 20

## バリデーション定数
const MAX_SCORE: int = 999999
const MAX_FLOOR: int = 25
const MAX_ENEMIES: int = 999
const MAX_COMBO: int = 999
const MAX_TURNS: int = 99999
const MAX_NAME_LEN: int = 12

var _http_get: HTTPRequest
var _http_post: HTTPRequest
var _url: String = ""
var _key: String = ""


func _ready() -> void:
	_http_get = HTTPRequest.new()
	_http_post = HTTPRequest.new()
	add_child(_http_get)
	add_child(_http_post)
	_http_get.request_completed.connect(_on_get_completed)
	_http_post.request_completed.connect(_on_post_completed)
	_load_config()


func _load_config() -> void:
	# 設定ファイルから読み込み（なければデフォルト値）
	var config_path: String = "res://supabase_config.cfg"
	if FileAccess.file_exists("user://supabase_config.cfg"):
		config_path = "user://supabase_config.cfg"

	var config: ConfigFile = ConfigFile.new()
	if config.load(config_path) == OK:
		_url = config.get_value("supabase", "url", "")
		_key = config.get_value("supabase", "anon_key", "")

	# フォールバック（base64エンコード済み）
	if _url == "":
		_url = Marshalls.base64_to_utf8("aHR0cHM6Ly9leWh4dmp2dWRnZmVwY3l3eGN2dy5zdXBhYmFzZS5jbw==")
	if _key == "":
		_key = Marshalls.base64_to_utf8("c2JfcHVibGlzaGFibGVfaVdvZjY3Wm9NV3NMOElpNXpUdEdNZ19hVHhSRjV4dg==")


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % _key,
		"Authorization: Bearer %s" % _key,
		"Content-Type: application/json",
		"Prefer: return=minimal",
	])


## TOP20ランキングを取得
func fetch_rankings() -> void:
	if _url == "":
		rankings_loaded.emit([])
		return
	var url: String = "%s/rest/v1/%s?select=*&order=score.desc&limit=%d" % [_url, TABLE, TOP_LIMIT]
	_http_get.request(url, _headers(), HTTPClient.METHOD_GET)


## スコアを送信（バリデーション付き）
func submit_score(data: Dictionary, player_name: String = "Anonymous") -> void:
	if _url == "":
		score_submitted.emit(false)
		return

	# アプリ側バリデーション
	var score: int = clampi(int(data.get("total", 0)), 0, MAX_SCORE)
	var floor_r: int = clampi(int(data.get("floor_reached", 0)), 1, MAX_FLOOR)
	var enemies: int = clampi(int(data.get("enemies_defeated", 0)), 0, MAX_ENEMIES)
	var combo: int = clampi(int(data.get("max_combo", 0)), 0, MAX_COMBO)
	var knowledge: int = clampi(int(data.get("knowledge_count", 0)), 0, 100)
	var turns: int = clampi(int(data.get("total_turns", 0)), 0, MAX_TURNS)
	var seed_val: int = int(data.get("seed", 0))
	var cleared: bool = data.get("cleared", false)

	# 名前サニタイズ
	var safe_name: String = player_name.strip_edges().substr(0, MAX_NAME_LEN)
	if safe_name == "":
		safe_name = "Anonymous"
	# 危険な文字を除去
	safe_name = safe_name.replace("<", "").replace(">", "").replace("&", "").replace("\"", "").replace("'", "")

	var url: String = "%s/rest/v1/%s" % [_url, TABLE]
	var body: Dictionary = {
		"score": score,
		"floor_reached": floor_r,
		"enemies_defeated": enemies,
		"max_combo": combo,
		"knowledge_count": knowledge,
		"total_turns": turns,
		"cleared": cleared,
		"seed": seed_val,
		"player_name": safe_name,
	}
	_http_post.request(url, _headers(), HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_get_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("SupabaseRanking: fetch failed (code=%d)" % code)
		rankings_loaded.emit([])
		return
	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		rankings_loaded.emit([])
		return
	rankings_loaded.emit(json.data if json.data is Array else [])


func _on_post_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var success: bool = (result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300)
	if not success:
		push_warning("SupabaseRanking: submit failed (code=%d)" % code)
	score_submitted.emit(success)
