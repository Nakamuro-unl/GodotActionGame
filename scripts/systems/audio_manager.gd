extends Node

## サウンドの再生管理。プリロードした音源をIDで再生する。

var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _bgm_tracks: Dictionary = {}
const MAX_POLYPHONY: int = 4


func _ready() -> void:
	for i in MAX_POLYPHONY:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_load_sounds()
	_load_bgm()


func _load_sounds() -> void:
	var sound_files: Dictionary = {
		"hit": "res://assets/sounds/hit.wav",
		"defeat": "res://assets/sounds/defeat.wav",
		"ghost": "res://assets/sounds/ghost.wav",
		"damage": "res://assets/sounds/damage.wav",
		"levelup": "res://assets/sounds/levelup.wav",
		"chest": "res://assets/sounds/chest.wav",
		"step": "res://assets/sounds/step.wav",
		"gameover": "res://assets/sounds/gameover.wav",
		"menu": "res://assets/sounds/menu.wav",
		"miss": "res://assets/sounds/miss.wav",
	}
	for id in sound_files:
		var path: String = sound_files[id]
		if ResourceLoader.exists(path):
			_sounds[id] = load(path)


func _load_bgm() -> void:
	var bgm_files: Dictionary = {
		"title": "res://assets/sounds/bgm_title.wav",
		"stage1": "res://assets/sounds/bgm_stage1.wav",
		"stage2": "res://assets/sounds/bgm_stage2.wav",
		"stage3": "res://assets/sounds/bgm_stage3.wav",
		"stage4": "res://assets/sounds/bgm_stage4.wav",
		"stage5": "res://assets/sounds/bgm_stage5.wav",
		"boss": "res://assets/sounds/bgm_boss.wav",
	}
	for id in bgm_files:
		var path: String = bgm_files[id]
		if ResourceLoader.exists(path):
			_bgm_tracks[id] = load(path)


## BGMを再生（ループ）
func play_bgm(id: String) -> void:
	if not _bgm_tracks.has(id):
		return
	_bgm_player.stream = _bgm_tracks[id]
	_bgm_player.play()


## BGMを停止
func stop_bgm() -> void:
	_bgm_player.stop()


## サウンドを再生
func play(id: String) -> void:
	if not _sounds.has(id):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sounds[id]
			p.play()
			return
	# 全チャンネル使用中なら最初のを上書き
	_players[0].stream = _sounds[id]
	_players[0].play()
