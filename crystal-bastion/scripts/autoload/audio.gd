extends Node
## Sound effects pool + music player with crossfade.
## Streams are loaded from res://assets/audio/{sfx,music}; missing files are ignored.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_NAMES: Array[String] = [
	"arrow", "cannon", "explosion", "frost", "tesla", "laser", "hit", "death", "coin",
	"build", "upgrade", "sell", "wave", "boss", "leak", "victory", "defeat", "click", "error",
]
const MIN_INTERVAL := 0.045

var _sfx := {}
var _last_play := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _laser_player: AudioStreamPlayer
var _laser_users := 0
var _fades := {}   # AudioStreamPlayer -> Tween currently fading it


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX_NAMES:
		var stream := _load_stream(SFX_DIR + n)
		if stream:
			_sfx[n] = stream
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_laser_player = AudioStreamPlayer.new()
	# Beam hum belongs to the gameplay: it must stop while the game is paused.
	_laser_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_laser_player.bus = "SFX"
	_laser_player.volume_db = -9.0
	add_child(_laser_player)
	if _sfx.has("laser"):
		var ls: AudioStream = _sfx["laser"]
		if ls is AudioStreamOggVorbis:
			(ls as AudioStreamOggVorbis).loop = true
		elif ls is AudioStreamWAV:
			var wav := ls as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_laser_player.stream = ls
	Save.settings_changed.connect(apply_volumes)
	apply_volumes()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _load_stream(base: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext)
	return null


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _vol_db(Save.music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _vol_db(Save.sfx_volume))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), Save.music_volume <= 0.001)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), Save.sfx_volume <= 0.001)


func _vol_db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


## Plays a one-shot sound. `pitch_var` randomizes pitch for variety.
func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	if not _sfx.has(sfx_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sfx_name, -1.0)) < MIN_INTERVAL:
		return
	_last_play[sfx_name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Laser hum is shared by every active beam tower.
func laser_on() -> void:
	_laser_users += 1
	if _laser_users == 1 and _laser_player.stream and not _laser_player.playing:
		_laser_player.play()


func laser_off() -> void:
	_laser_users = maxi(_laser_users - 1, 0)
	if _laser_users == 0:
		_laser_player.stop()


func reset_laser() -> void:
	_laser_users = 0
	_laser_player.stop()


func play_music(track: String, fade := 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	var stream := _load_stream(MUSIC_DIR + track)
	var old := _music_a
	var fresh := _music_b
	_music_a = fresh
	_music_b = old
	_fade_out(old, fade)
	_kill_fade(fresh)
	if stream == null:
		fresh.stop()
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	fresh.stream = stream
	fresh.volume_db = -40.0
	fresh.play()
	var tw2 := create_tween()
	tw2.tween_property(fresh, "volume_db", 0.0, fade)
	_fades[fresh] = tw2


func stop_music(fade := 1.0) -> void:
	_music_name = ""
	_fade_out(_music_a, fade)


## Fades a player out and stops it. Any earlier fade on the same player is cancelled first,
## so a quick track change can never stop the track that just started.
func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	_kill_fade(p)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.stop)
	_fades[p] = tw


func _kill_fade(p: AudioStreamPlayer) -> void:
	var old_tw: Tween = _fades.get(p, null)
	if old_tw and old_tw.is_valid():
		old_tw.kill()
	_fades.erase(p)
