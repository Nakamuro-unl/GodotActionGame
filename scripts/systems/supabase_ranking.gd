extends Node

## Supabaseオンラインランキング。HTTPRequestでREST API通信。

signal rankings_loaded(rankings: Array)
signal score_submitted(success: bool)

const SUPABASE_URL: String = "https://eyhxvjvudgfepcywxcvw.supabase.co"
const SUPABASE_KEY: String = "sb_publishable_iWof67ZoMWsL8Ii5zTtGMg_aTxRF5xv"
const TABLE: String = "rankings"
const TOP_LIMIT: int = 20

var _http_get: HTTPRequest
var _http_post: HTTPRequest


func _ready() -> void:
	_http_get = HTTPRequest.new()
	_http_post = HTTPRequest.new()
	add_child(_http_get)
	add_child(_http_post)
	_http_get.request_completed.connect(_on_get_completed)
	_http_post.request_completed.connect(_on_post_completed)


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % SUPABASE_KEY,
		"Content-Type: application/json",
		"Prefer: return=minimal",
	])


## TOP20ランキングを取得
func fetch_rankings() -> void:
	var url: String = "%s/rest/v1/%s?select=*&order=score.desc&limit=%d" % [SUPABASE_URL, TABLE, TOP_LIMIT]
	_http_get.request(url, _headers(), HTTPClient.METHOD_GET)


## スコアを送信
func submit_score(data: Dictionary, player_name: String = "Anonymous") -> void:
	var url: String = "%s/rest/v1/%s" % [SUPABASE_URL, TABLE]
	var body: Dictionary = {
		"score": int(data.get("total", 0)),
		"floor_reached": int(data.get("floor_reached", 0)),
		"enemies_defeated": int(data.get("enemies_defeated", 0)),
		"max_combo": int(data.get("max_combo", 0)),
		"knowledge_count": int(data.get("knowledge_count", 0)),
		"total_turns": int(data.get("total_turns", 0)),
		"cleared": data.get("cleared", false),
		"seed": int(data.get("seed", 0)),
		"player_name": player_name,
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
