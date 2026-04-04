extends Node

## サウンドの再生管理。プリロードした音源をIDで再生する。

var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}  # id -> AudioStream
const MAX_POLYPHONY: int = 4


func _ready() -> void:
	for i in MAX_POLYPHONY:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_load_sounds()


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
