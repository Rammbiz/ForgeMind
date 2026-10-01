extends SceneTree
## Headless audio asset check (dev tool, not used by the game).
## Run: godot --headless --path crystal-bastion -s res://tools/check_audio.gd
## Verifies that every SFX in Audio.SFX_NAMES and every music track loads as an
## AudioStream with a sensible length, that looping streams are imported with
## loop enabled, and that the Audio autoload keeps the laser hum looping.
## Prints "AUDIO_CHECK OK" (exit code 0) or "AUDIO_CHECK FAILED" (exit code 1).

const MUSIC: Array[String] = ["menu", "meadow", "canyon", "frost"]
const LONG_SFX := {"victory": 3.5, "defeat": 3.5, "boss": 2.0}

var _failures := 0
var _frames := 0
var _t0 := 0
var _stage := 0


func _initialize() -> void:
	var consts := (load("res://scripts/autoload/audio.gd") as GDScript).get_script_constant_map()
	var sfx_dir: String = consts["SFX_DIR"]
	var music_dir: String = consts["MUSIC_DIR"]
	for n: String in consts["SFX_NAMES"]:
		var max_len: float = LONG_SFX.get(n, 1.5)
		if n == "laser":
			_check(sfx_dir + n, 0.99, 1.01, true)
		else:
			_check(sfx_dir + n, 0.03, max_len, false)
	for n in MUSIC:
		_check(music_dir + n, 40.0, 64.5, true)


func _check(base: String, min_len: float, max_len: float, must_loop: bool) -> void:
	var path := ""
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			path = base + ext
			break
	if path.is_empty():
		_fail("%s: missing" % base)
		return
	# fresh copy so we see the import settings, not runtime tweaks from the Audio autoload
	var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
	if stream == null:
		_fail("%s: not an AudioStream" % path)
		return
	var length := stream.get_length()
	var loops := false
	if stream is AudioStreamOggVorbis:
		loops = (stream as AudioStreamOggVorbis).loop
	elif stream is AudioStreamWAV:
		loops = (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	var ok := length >= min_len and length <= max_len and (loops if must_loop else true)
	print("  %-44s %-22s %7.3fs loop=%s %s" % [path, stream.get_class(), length, loops, "ok" if ok else "BAD"])
	if not ok:
		_fail("%s: length %.3f (want %.2f..%.2f), loop=%s (want %s)" % [path, length, min_len, max_len, loops, must_loop])


func _process(_delta: float) -> bool:
	_frames += 1
	var audio := root.get_node_or_null("Audio")
	if audio == null:
		if _frames > 5:
			_fail("Audio autoload not found")
			return _finish()
		return false
	match _stage:
		0:
			var sfx: Dictionary = audio.get("_sfx")
			var names: Array = audio.get("SFX_NAMES")
			if sfx.size() != names.size():
				_fail("Audio autoload loaded %d of %d SFX" % [sfx.size(), names.size()])
			var lp: AudioStreamPlayer = audio.get("_laser_player")
			if lp.stream == null or not (lp.stream is AudioStreamOggVorbis and (lp.stream as AudioStreamOggVorbis).loop):
				_fail("laser player stream missing or not looping")
			audio.call("laser_on")
			audio.call("play_music", "menu", 0.1)
			audio.call("play", "victory")
			_t0 = Time.get_ticks_msec()
			_stage = 1
		1:
			if Time.get_ticks_msec() - _t0 < 1600:
				return false
			var lp: AudioStreamPlayer = audio.get("_laser_player")
			var pos := lp.get_playback_position()
			print("  laser after 1.6 s: playing=%s position=%.3f" % [lp.playing, pos])
			if not lp.playing or pos >= 1.0:
				_fail("laser hum did not loop (playing=%s, position=%.3f)" % [lp.playing, pos])
			var music: AudioStreamPlayer = audio.get("_music_a")
			print("  music: playing=%s stream=%s position=%.3f" % [music.playing, music.stream.resource_path if music.stream else "null", music.get_playback_position()])
			if not music.playing or music.stream == null:
				_fail("menu music is not playing")
			# stop everything and let the audio server release playbacks before quitting
			audio.call("reset_laser")
			audio.call("stop_music", 0.1)
			for p: AudioStreamPlayer in audio.get("_players"):
				p.stop()
			_t0 = Time.get_ticks_msec()
			_stage = 2
		2:
			if Time.get_ticks_msec() - _t0 >= 400:
				return _finish()
	return false


func _fail(msg: String) -> void:
	_failures += 1
	printerr("AUDIO_CHECK error: " + msg)


func _finish() -> bool:
	print("AUDIO_CHECK %s" % ("OK" if _failures == 0 else "FAILED (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
	return true
