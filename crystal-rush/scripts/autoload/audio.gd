extends Node
## Sound effects pool + music player with crossfade, plus procedural musical feedback:
## pentatonic bell/marimba notes for pickups and gate chords (sparkling major triad for a good
## gate, a soft descending "wah" for a bad one).
## Streams are loaded from res://assets/audio/{sfx,music}; missing files are ignored.
## The note/chord tones are synthesised at startup on a worker thread (see `_build_tones`).

signal tones_ready

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_NAMES: Array[String] = [
	"arrow", "cannon", "explosion", "frost", "tesla", "laser", "hit", "death", "coin",
	"build", "upgrade", "sell", "wave", "boss", "leak", "victory", "defeat", "click", "error",
	# Etap 1 (tools/gen_sfx.py)
	"crate_hit", "crate_open", "weapon_get", "ballista", "plasma", "laser_loop", "rocket", "drone",
	"blade", "spikes", "recruit", "stairs_step", "stairs_top", "geode_break", "turret_shot", "volley",
	"brawl", "whoosh_gate",
]
const MIN_INTERVAL := 0.045
## Same-name retrigger guard for play_pitched (pickup streaks fire fast on purpose).
const PITCHED_MIN_INTERVAL := 0.03

## Note synthesis.
const TONE_RATE := 44100
const NOTE_LEN := 0.95
const NOTE_VOICES := 6
## Major pentatonic (C D E G A) laid out from G4: steps 0..14 = G4 A4 C5 D5 E5 | G5 .. E6 | G6 .. E7.
const NOTE_BASE_MIDI := 67
const PENTA := [0, 2, 5, 7, 9]   # semitones above G within one octave of the step table: G A C D E
const NOTE_STEPS := 15
## Strum spacing of chord voices (seconds, real time).
const STRUM := 0.032

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

var _notes: Array[AudioStreamWAV] = []
var _sparkle: AudioStreamWAV
var _wah: AudioStreamWAV
var _tones_ok := false
var _tone_task := -1
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## Delayed voices of a strummed chord: [{at_us, stream, pitch, db}], played in _process (real time).
var _pending: Array[Dictionary] = []


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
	for i in NOTE_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_laser_player = AudioStreamPlayer.new()
	# Beam hum belongs to the gameplay: it must stop while the game is paused.
	_laser_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_laser_player.bus = "SFX"
	_laser_player.volume_db = -9.0
	add_child(_laser_player)
	# The Etap 1 crystal beam loop replaces the old tower hum when it is present.
	var beam_name := "laser_loop" if _sfx.has("laser_loop") else "laser"
	if _sfx.has(beam_name):
		var ls: AudioStream = _sfx[beam_name]
		_make_loop(ls)
		_laser_player.stream = ls
	Save.settings_changed.connect(apply_volumes)
	apply_volumes()
	_tone_task = WorkerThreadPool.add_task(_build_tones, false, "Audio tones")


func _exit_tree() -> void:
	if _tone_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_tone_task)
		_tone_task = -1


func _process(_delta: float) -> void:
	if _tone_task >= 0 and WorkerThreadPool.is_task_completed(_tone_task):
		WorkerThreadPool.wait_for_task_completion(_tone_task)
		_tone_task = -1
		_tones_ok = _notes.size() == NOTE_STEPS
		tones_ready.emit()
	if _pending.is_empty():
		return
	var now := Time.get_ticks_usec()
	var i := 0
	while i < _pending.size():
		var p: Dictionary = _pending[i]
		if now >= int(p["at"]):
			_voice(p["stream"], float(p["pitch"]), float(p["db"]))
			_pending.remove_at(i)
		else:
			i += 1


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))


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


## True when `sfx_name` was found on disk at startup.
func has_sfx(sfx_name: String) -> bool:
	return _sfx.has(sfx_name)


## The loaded stream for `sfx_name` (null when missing). Used by tests and tools.
func get_sfx(sfx_name: String) -> AudioStream:
	return _sfx.get(sfx_name, null)


## Plays a one-shot sound. `pitch_var` randomizes pitch for variety.
func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	if not _sfx.has(sfx_name):
		return
	if not _gate(sfx_name, MIN_INTERVAL):
		return
	_one_shot(_sfx[sfx_name], volume_db, 1.0 + randf_range(-pitch_var, pitch_var))


## Plays a one-shot at an exact pitch (e.g. stairs steps climbing, streak pickups).
func play_pitched(sfx_name: String, volume_db: float, pitch: float) -> void:
	if not _sfx.has(sfx_name):
		return
	if not _gate(sfx_name, PITCHED_MIN_INTERVAL):
		return
	_one_shot(_sfx[sfx_name], volume_db, clampf(pitch, 0.25, 4.0))


func _gate(sfx_name: String, interval: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sfx_name, -1.0)) < interval:
		return false
	_last_play[sfx_name] = now
	return true


func _one_shot(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


# ---------------------------------------------------------------------------
# Musical feedback: notes and chords
# ---------------------------------------------------------------------------

## True once the note/chord tones are synthesised (a fraction of a second after boot).
func tones_are_ready() -> bool:
	return _tones_ok


## One bell/marimba note of the major pentatonic, `step` 0..14 (3 octaves from G4, clamped).
## Pickup streaks call it with a rising step. Uses a dedicated pool of 6 voices.
func note(step: int, volume_db := -8.0) -> void:
	if not _tones_ok:
		return
	var s := clampi(step, 0, NOTE_STEPS - 1)
	_voice(_notes[s], 1.0, volume_db)


## Gate chord rooted on pentatonic `root_step`. good: strummed major triad + octave with a
## crystal sparkle on top; bad: a soft, low descending "wah" (pitch follows the root a little).
func chord(root_step: int, good: bool, volume_db := -6.0) -> void:
	if not _tones_ok:
		return
	var s := clampi(root_step, 0, NOTE_STEPS - 1)
	var now := Time.get_ticks_usec()
	if good:
		var root: AudioStreamWAV = _notes[s]
		# Root, major third, fifth (pitched from the root tone), then the exact octave tone.
		_voice(root, 1.0, volume_db)
		_queue(now + int(STRUM * 1e6), root, pow(2.0, 4.0 / 12.0), volume_db - 1.5)
		_queue(now + int(STRUM * 2e6), root, pow(2.0, 7.0 / 12.0), volume_db - 2.0)
		var top: AudioStreamWAV = _notes[mini(s + 5, NOTE_STEPS - 1)]
		var top_pitch := 1.0 if s + 5 < NOTE_STEPS else pow(2.0, float(_midi(s) + 12 - _midi(NOTE_STEPS - 1)) / 12.0)
		_queue(now + int(STRUM * 3e6), top, top_pitch, volume_db - 4.0)
		_queue(now + int(STRUM * 3.5e6), _sparkle, pow(2.0, float(_midi(s) - NOTE_BASE_MIDI) / 12.0 * 0.5), volume_db - 5.0)
	else:
		# The wah is centred near the bottom of the scale; follow the root only a little so it stays low.
		var pitch := pow(2.0, float(_midi(s) - NOTE_BASE_MIDI) / 12.0 * 0.25)
		_voice(_wah, pitch, volume_db + 1.0)


func _queue(at_us: int, stream: AudioStream, pitch: float, db: float) -> void:
	_pending.append({"at": at_us, "stream": stream, "pitch": pitch, "db": db})


func _voice(stream: AudioStream, pitch: float, db: float) -> void:
	if stream == null:
		return
	# Prefer a free voice; otherwise steal the oldest (round robin).
	var v: AudioStreamPlayer = null
	for i in NOTE_VOICES:
		var cand := _voices[(_next_voice + i) % NOTE_VOICES]
		if not cand.playing:
			v = cand
			_next_voice = (_next_voice + i + 1) % NOTE_VOICES
			break
	if v == null:
		v = _voices[_next_voice]
		_next_voice = (_next_voice + 1) % NOTE_VOICES
	v.stream = stream
	v.pitch_scale = pitch
	v.volume_db = db
	v.play()


## MIDI note number of pentatonic step `s`.
static func _midi(s: int) -> int:
	return NOTE_BASE_MIDI + 12 * floori(s / 5.0) + int(PENTA[s % 5])


static func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Worker thread: synthesises the 15 notes, the chord sparkle and the bad-gate wah.
func _build_tones() -> void:
	var notes: Array[AudioStreamWAV] = []
	for s in NOTE_STEPS:
		notes.append(_synth_note(_mtof(float(_midi(s)))))
	var sparkle := _synth_sparkle(_mtof(float(NOTE_BASE_MIDI + 12)))
	var wah := _synth_wah()
	_notes = notes
	_sparkle = sparkle
	_wah = wah


## Bell/marimba hybrid: sine fundamental + a slowly beating twin (shimmer), soft 2nd/3rd harmonics
## and the tuned ~3.93x marimba overtone that gives the mallet "tock". Exponential decays, 2 ms
## raised-cosine attack and a cosine fade at the end, so it never clicks.
static func _synth_note(f: float) -> AudioStreamWAV:
	var n := int(NOTE_LEN * TONE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# Higher notes ring a little shorter, as on real bars.
	var tau := 0.35 * pow(523.25 / f, 0.22)
	# [ratio, amp, decay multiplier]; the twin sits a fixed 3 Hz above (an even, slow shimmer)
	var partials := [
		[1.0, 1.0, 1.0],
		[1.0 + 3.0 / f, 0.28, 0.92],
		[2.0, 0.17, 0.45],
		[3.0, 0.05, 0.3],
		[3.93, 0.2, 0.13],
		[6.27, 0.035, 0.07],
	]
	var tilt := pow(392.0 / f, 0.18)
	for j in partials.size():
		var p: Array = partials[j]
		var fr: float = f * float(p[0])
		if fr > TONE_RATE * 0.42:
			continue
		# fixed, spread start phases: deterministic and no big summed onset spike
		_add_partial(buf, fr, float(p[1]) * tilt, tau * float(p[2]), 0.0, 1.7 * j)
	_envelope(buf, 0.002, 0.08)
	return _to_wav(buf, 0.85)


## Short glitter: four tiny high bell pings, staggered, for the top of a good chord.
static func _synth_sparkle(f: float) -> AudioStreamWAV:
	var n := int(0.6 * TONE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ratios := [2.0, 2.5198, 2.9966, 4.0]   # octave, +maj third, +fifth, 2 octaves (of f)
	for i in ratios.size():
		var fr: float = f * float(ratios[i])
		var start := 0.022 * i
		_add_partial(buf, fr, 0.5 - 0.06 * i, 0.12, start, 0.9 * i)
		_add_partial(buf, fr * 2.76, 0.1, 0.05, start, 2.1 + i)
		_add_partial(buf, fr * 1.004, 0.25, 0.1, start, 4.0 + 0.5 * i)
	_envelope(buf, 0.001, 0.05)
	return _to_wav(buf, 0.8)


## Bad gate: a round, slightly nasal "wah-wahh" that slides down a minor third, with a closing
## formant (bright -> dark) on each syllable. Soft attack, no buzz above ~2.5 kHz.
static func _synth_wah() -> AudioStreamWAV:
	var dur := 0.62
	var n := int(dur * TONE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var syl := [[0.0, 0.2, 196.0, 185.0], [0.21, 0.41, 174.6, 146.8]]   # start, end, f_from, f_to
	for i in n:
		var t := float(i) / TONE_RATE
		var si := 0 if t < 0.21 else 1
		var sy: Array = syl[si]
		var t0: float = sy[0]
		var t1: float = sy[1]
		var u := clampf((t - t0) / (t1 - t0), 0.0, 1.0)
		var f: float = lerpf(float(sy[2]), float(sy[3]), u * u * (3.0 - 2.0 * u))
		phase += f / TONE_RATE
		# formant centre closes from ~1400 Hz to ~420 Hz within each syllable
		var fc := lerpf(1400.0, 420.0, sqrt(u)) * (1.0 if si == 0 else 0.9)
		var s := 0.0
		for k in range(1, 12):
			var fk := f * k
			if fk > 2600.0:
				break
			var q := 1.4 * (fk / fc - fc / fk)
			var g := (0.3 + 1.0 / sqrt(1.0 + q * q)) / pow(float(k), 0.9)
			s += g * sin(TAU * k * phase)
		# syllable envelope: soft 25 ms attack, gentle release; second syllable longer and quieter
		var ts := t - t0
		var a := clampf(ts / 0.025, 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		var e := a * exp(-maxf(ts - 0.06, 0.0) / (0.09 if si == 0 else 0.16))
		if si == 0:
			e *= clampf((0.21 - t) / 0.02, 0.0, 1.0)
		else:
			e *= 0.85
		buf[i] = s * e
	_envelope(buf, 0.002, 0.1)
	return _to_wav(buf, 0.7)


## Adds an exponentially decaying sine (recurrence oscillator: no per-sample sin()).
static func _add_partial(buf: PackedFloat32Array, f: float, amp: float, tau: float, start: float, phase: float) -> void:
	var n := buf.size()
	var i0 := int(start * TONE_RATE)
	if i0 >= n:
		return
	var w := TAU * f / TONE_RATE
	var c2 := 2.0 * cos(w)
	var y1 := sin(phase - w)   # y[-1]
	var y0 := sin(phase)       # y[0]
	var g := amp
	var decay := exp(-1.0 / (tau * TONE_RATE))
	# a 1.5 ms raised-cosine onset per partial (keeps staggered pings click-free)
	var att := maxi(1, int(0.0015 * TONE_RATE))
	for i in range(i0, n):
		var k := i - i0
		var e := g
		if k < att:
			e *= 0.5 - 0.5 * cos(PI * float(k) / att)
		buf[i] += y0 * e
		var y2 := c2 * y0 - y1
		y1 = y0
		y0 = y2
		g *= decay
		if g < 1e-5:
			break


## Raised-cosine fade in / out on the whole buffer.
static func _envelope(buf: PackedFloat32Array, fade_in: float, fade_out: float) -> void:
	var n := buf.size()
	var a := mini(int(fade_in * TONE_RATE), n)
	for i in a:
		buf[i] *= 0.5 - 0.5 * cos(PI * float(i) / a)
	var b := mini(int(fade_out * TONE_RATE), n)
	for i in b:
		buf[n - 1 - i] *= 0.5 - 0.5 * cos(PI * float(i) / b)


## Peak-normalises to `peak` and packs 16-bit mono PCM.
static func _to_wav(buf: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	var k := peak / maxf(m, 1e-6) * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, clampi(int(round(buf[i] * k)), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = TONE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# ---------------------------------------------------------------------------
# Loops and music
# ---------------------------------------------------------------------------

## Laser hum is shared by every active beam (crystal beam loop "laser_loop", legacy "laser").
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
