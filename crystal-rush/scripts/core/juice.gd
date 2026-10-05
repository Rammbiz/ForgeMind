class_name Juice
extends Node
## Game feel for one run (child of Run): trauma camera shake, hit-stop, haptic patterns,
## floating "+12" numbers and the rolling/pulsing army counter.
##
## Everything here runs on real time (Time.get_ticks_usec), not on the scaled game delta, so
## a hit-stop can never freeze its own timer and the feedback stays snappy during slow motion.
## The node processes while the tree is paused (so a hit-stop always ends and restores
## Engine.time_scale), but popups and counters hold still during pause.

## Emitted for every haptic pulse, on every platform (debug overlays and tests listen to it;
## the device only vibrates on mobile with Save.vibration on).
signal haptic_pulse(kind: String, ms: int, amplitude: float)

## Normal game speed. The autotest sets e.g. 4.0; hit-stop always returns to this value.
static var base_time_scale := 1.0
## The autotest turns hit-stop off.
static var hitstop_enabled := true

## Trauma lost per second (Eiserloh: shake = trauma², trauma decays linearly).
const TRAUMA_DECAY := 1.2
## Max camera offset (world units) and roll (radians, 2°) at trauma 1.
const SHAKE_MAX := 0.35
const ROLL_MAX := 0.0349066
## Noise scroll speed (noise units per second) at trauma 0 and the extra at trauma 1
## (≈4–6 shake cycles per second: weighty, never buzzy).
const SHAKE_SPEED := 3.5
const SHAKE_SPEED_TRAUMA := 1.5
## "clash" trauma refills at this rate (per second) up to the same cap: clashes rumble, never rattle.
const CLASH_RATE := 0.25
## Time scale while frozen (relative to base_time_scale).
const FREEZE_SCALE := 0.03
## Slow motion eases back to normal over this tail of the slow window (seconds).
const SLOW_EASE := 0.12

## Haptic patterns: [start_ms, duration_ms, amplitude] per pulse.
const HAPTICS := {
	"tile": [[0, 6, 0.25]],
	"gate_good": [[0, 12, 0.5]],
	"gate_bad": [[0, 15, 0.7], [75, 15, 0.7]],
	"barricade": [[0, 20, 1.0]],
	"hit_big": [[0, 25, 0.8]],
	"weapon": [[0, 12, 0.6], [100, 12, 0.6]],
	"ult": [[0, 18, 0.5], [70, 18, 0.7], [140, 24, 1.0]],
	"win": [[0, 30, 0.6], [140, 30, 0.8], [280, 60, 1.0]],
}
## A pattern only interrupts one of lower priority. >= HAPTIC_BIG waits out the 90 ms gap instead of dropping.
const HAPTIC_PRIORITY := {"tile": 0, "gate_good": 1, "weapon": 2, "gate_bad": 2, "hit_big": 3,
		"barricade": 3, "ult": 4, "win": 5}
const HAPTIC_BIG := 3
## Minimum gap between pulses of separate events, and the extra throttle for tile ticks.
const HAPTIC_GAP_MS := 90
const TILE_GAP_MS := 250

## Popups.
const POPUP_POOL := 10
const POPUP_TIME := 0.6
const POPUP_RISE := 0.8
const POPUP_PX := 120
const POPUP_HALO_A := 0.6
const POPUP_SHADOW_A := 0.45
## Counter roll time and pulse.
const COUNTER_TIME := 0.3
const COUNTER_PULSE := 0.35
const COUNTER_FLASH_TIME := 0.45
const GAIN_COLOR := Color(0.25, 1.0, 0.4)
const LOSS_COLOR := Color(1.0, 0.22, 0.18)

## Current trauma 0..1 (read-only for callers; use add_trauma).
var trauma := 0.0
## World velocity added to popups while they float (Run sets (0, 0, -speed) so numbers ride
## along with the army instead of sliding off the bottom of the screen).
var popup_velocity := Vector3.ZERO
## Text format for counter(); "%d" by default.
var counter_format := "%d"

var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var _clash_budget := CLASH_RATE
var _last_us := 0

var _freeze_until := 0
var _slow_until := 0
var _slow_scale := 1.0
var _hitstop_active := false

var _hap_queue: Array = []        # [[at_us, ms, amp]] for the pattern in flight
var _hap_kind := ""
var _hap_prio := -1
var _last_pulse_us := -10000000
var _last_tile_us := -10000000

var _popups: Array[Label3D] = []
var _popup_state: Array[Dictionary] = []   # parallel to _popups: {age, pos, size, color, active}
var _next_popup := 0

var _counters := {}   # label instance id -> state Dictionary


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	# One smooth octave: a big, rolling shake rather than a buzzy one.
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.seed = 1337


func _ready() -> void:
	_last_us = Time.get_ticks_usec()
	for i in POPUP_POOL:
		var l := _make_popup_label()
		add_child(l)
		_popups.append(l)
		_popup_state.append({"active": false, "age": 0.0, "pos": Vector3.ZERO, "size": 1.0})


func _exit_tree() -> void:
	# A run that ends mid hit-stop must not leave the game in slow motion.
	if _hitstop_active:
		Engine.time_scale = base_time_scale
		_hitstop_active = false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := clampf(float(now - _last_us) / 1e6, 0.0, 0.1)
	_last_us = now
	_update_hitstop(now)
	_update_haptics(now)
	# Trauma and the clash budget follow real time (shake keeps living through a freeze frame).
	trauma = maxf(trauma - TRAUMA_DECAY * rdt, 0.0)
	_clash_budget = minf(_clash_budget + CLASH_RATE * rdt, CLASH_RATE)
	_noise_t += rdt * (SHAKE_SPEED + SHAKE_SPEED_TRAUMA * trauma)
	if is_inside_tree() and get_tree().paused:
		return
	_update_popups(rdt)
	_update_counters(now)


# ---------------------------------------------------------------------------
# Trauma shake
# ---------------------------------------------------------------------------

## Adds camera trauma (clamped to 0..1). Sources named "clash" share a budget of +0.25/s.
func add_trauma(amount: float, source := "") -> void:
	if amount <= 0.0:
		return
	if source == "clash":
		amount = minf(amount, _clash_budget)
		_clash_budget -= amount
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Camera position offset: trauma² × 0.35 u, smooth FastNoiseLite motion (z at 40%).
func shake_offset() -> Vector3:
	var k := trauma * trauma * SHAKE_MAX
	if k <= 0.0:
		return Vector3.ZERO
	return Vector3(_n(0), _n(1), _n(2) * 0.4).limit_length(1.0) * k


## Camera roll in radians: trauma² × 2°.
func shake_roll() -> float:
	return _n(3) * trauma * trauma * ROLL_MAX


func _n(axis: int) -> float:
	# simplex along a line peaks near ±0.6; tanh keeps the peaks round instead of clipped flat
	return tanh(_noise.get_noise_2d(float(axis) * 71.3, _noise_t) * 2.0)


# ---------------------------------------------------------------------------
# Hit-stop
# ---------------------------------------------------------------------------

## Freezes the game for `freeze` s (time scale base × 0.03), then plays `slow` s of slow motion at
## base × `slow_scale` easing back to base. Real-time timers; overlapping calls extend the windows.
func hitstop(freeze: float, slow := 0.0, slow_scale := 0.3) -> void:
	if not hitstop_enabled or (freeze <= 0.0 and slow <= 0.0):
		return
	var now := Time.get_ticks_usec()
	var f_end := now + int(maxf(freeze, 0.0) * 1e6)
	_freeze_until = maxi(_freeze_until, f_end)
	if slow > 0.0:
		var s_end := maxi(_freeze_until, f_end) + int(slow * 1e6)
		if s_end > _slow_until:
			_slow_until = s_end
			_slow_scale = clampf(slow_scale, FREEZE_SCALE, 1.0)
	_hitstop_active = true
	_update_hitstop(now)


## True while a freeze or slow-motion window is running.
func is_hitstopping() -> bool:
	return _hitstop_active


func _update_hitstop(now: int) -> void:
	if not _hitstop_active:
		return
	if now < _freeze_until:
		Engine.time_scale = base_time_scale * FREEZE_SCALE
	elif now < _slow_until:
		var left := float(_slow_until - now) / 1e6
		var k := clampf(left / SLOW_EASE, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		Engine.time_scale = base_time_scale * lerpf(1.0, _slow_scale, k)
	else:
		Engine.time_scale = base_time_scale
		_hitstop_active = false
		_freeze_until = 0
		_slow_until = 0


## Cancels hit-stop and trauma (run restart / result screen).
func reset() -> void:
	trauma = 0.0
	if _hitstop_active:
		Engine.time_scale = base_time_scale
	_hitstop_active = false
	_freeze_until = 0
	_slow_until = 0
	_hap_queue.clear()
	_hap_prio = -1


# ---------------------------------------------------------------------------
# Haptics
# ---------------------------------------------------------------------------

## Plays a haptic pattern: tile, gate_good, gate_bad, barricade, hit_big, weapon, ult, win.
## Never more often than one pulse per 90 ms across events; tiles are throttled to 4/s; a
## pattern only interrupts a weaker one. Vibrates only on mobile with Save.vibration on.
func haptic(kind: String) -> void:
	if not HAPTICS.has(kind):
		push_warning("Juice.haptic: unknown kind '%s'" % kind)
		return
	var now := Time.get_ticks_usec()
	var prio: int = HAPTIC_PRIORITY.get(kind, 0)
	if not _hap_queue.is_empty() and prio <= _hap_prio:
		return
	if kind == "tile":
		if now - _last_tile_us < TILE_GAP_MS * 1000:
			return
		_last_tile_us = now
	var start := now
	var earliest := _last_pulse_us + HAPTIC_GAP_MS * 1000
	if now < earliest:
		if prio < HAPTIC_BIG:
			return
		start = earliest
	_hap_queue.clear()
	for p in HAPTICS[kind]:
		_hap_queue.append([start + int(p[0]) * 1000, int(p[1]), float(p[2])])
	_hap_kind = kind
	_hap_prio = prio
	_update_haptics(now)


func _update_haptics(now: int) -> void:
	while not _hap_queue.is_empty() and now >= int(_hap_queue[0][0]):
		var p: Array = _hap_queue.pop_front()
		_pulse(int(p[1]), float(p[2]))
	if _hap_queue.is_empty():
		_hap_prio = -1


func _pulse(ms: int, amp: float) -> void:
	_last_pulse_us = Time.get_ticks_usec()
	haptic_pulse.emit(_hap_kind, ms, amp)
	if Save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amp)


# ---------------------------------------------------------------------------
# Floating numbers
# ---------------------------------------------------------------------------

func _make_popup_label() -> Label3D:
	var l := _popup_layer(20)
	# Layers behind the number: a soft-coloured halo rim and an offset drop shadow give the
	# sticker-like depth of premium mobile numbers.
	var halo := _popup_layer(16)
	halo.name = "Halo"
	halo.outline_size = 62
	halo.modulate = Color(1, 1, 1, 0)
	l.add_child(halo)
	var shadow := _popup_layer(18)
	shadow.name = "Shadow"
	shadow.position = Vector3(0.03, -0.055, -0.01)
	shadow.modulate = Color(0.0, 0.0, 0.05, POPUP_SHADOW_A)
	shadow.outline_modulate = Color(0.0, 0.0, 0.05, POPUP_SHADOW_A)
	l.add_child(shadow)
	l.visible = false
	return l


func _popup_layer(priority: int) -> Label3D:
	var l := Label3D.new()
	l.font = UIKit.font(true)
	l.font_size = POPUP_PX
	l.pixel_size = 0.0055
	l.outline_size = 26
	l.outline_modulate = Color(0.03, 0.04, 0.12, 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.double_sided = true
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.render_priority = priority
	l.outline_render_priority = priority - 1
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## Floating text ("+12", "-5", "×2") at world `pos`: pops 0.6 → 1.15 → 1, rises 0.8 u in
## 0.6 s and fades. Pool of 10 Label3D; the oldest one is reused when all are busy.
func popup(text: String, pos: Vector3, color: Color, size := 1.0) -> void:
	if _popups.is_empty():
		return
	var i := _next_popup
	_next_popup = (_next_popup + 1) % _popups.size()
	var l := _popups[i]
	# Saturated fill with a little white lift, deep tinted stroke, light tinted halo rim:
	# reads on the bright crystal road, on gates and against space alike.
	# (the road's filmic tonemap washes unshaded colours out, so the fill is pre-saturated)
	var fill := color
	if color.s > 0.15:
		fill = Color.from_hsv(color.h, minf(color.s * 1.3 + 0.08, 1.0), color.v * 0.97)
	fill.a = 1.0
	var stroke := color.darkened(0.8)
	stroke.a = 1.0
	var rim := color.lerp(Color.WHITE, 0.25)
	rim.a = POPUP_HALO_A
	l.text = text
	l.modulate = fill
	l.outline_modulate = stroke
	var halo := l.get_child(0) as Label3D
	halo.text = text
	halo.outline_modulate = rim
	var shadow := l.get_child(1) as Label3D
	shadow.text = text
	l.global_position = pos
	l.scale = Vector3.ONE * 0.6 * size
	l.visible = true
	_popup_state[i] = {"active": true, "age": 0.0, "pos": pos, "size": size, "drift": Vector3.ZERO}


func _update_popups(rdt: float) -> void:
	var gdt := rdt * Engine.time_scale
	for i in _popups.size():
		var st: Dictionary = _popup_state[i]
		if not st["active"]:
			continue
		var l := _popups[i]
		var age: float = st["age"] + rdt
		st["age"] = age
		st["drift"] = (st["drift"] as Vector3) + popup_velocity * gdt
		if age >= POPUP_TIME:
			st["active"] = false
			l.visible = false
			continue
		var u := age / POPUP_TIME
		var rise := 1.0 - pow(1.0 - u, 3.0)
		l.global_position = (st["pos"] as Vector3) + Vector3.UP * POPUP_RISE * rise + (st["drift"] as Vector3)
		var sc := _pop_curve(age)
		l.scale = Vector3.ONE * sc * float(st["size"])
		var a := 1.0 - clampf((u - 0.55) / 0.45, 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		l.modulate.a = a
		l.outline_modulate.a = a
		var halo := l.get_child(0) as Label3D
		halo.outline_modulate.a = a * POPUP_HALO_A
		var shadow := l.get_child(1) as Label3D
		shadow.modulate.a = a * POPUP_SHADOW_A
		shadow.outline_modulate.a = a * POPUP_SHADOW_A


## 0.6 → 1.15 over 0.09 s (ease out), → 1.0 by 0.2 s (ease in-out), then holds.
static func _pop_curve(age: float) -> float:
	if age < 0.09:
		var u := age / 0.09
		return lerpf(0.6, 1.15, 1.0 - (1.0 - u) * (1.0 - u))
	var v := clampf((age - 0.09) / 0.11, 0.0, 1.0)
	v = v * v * (3.0 - 2.0 * v)
	return lerpf(1.15, 1.0, v)


# ---------------------------------------------------------------------------
# Army counter
# ---------------------------------------------------------------------------

## Rolls `label` from the number it shows to `value` in 0.3 s, pulses its scale 1 → 1.35 → 1
## and flashes it green on a gain / red on a loss, then back to its base colour (white).
## The label's scale and modulate at the first call are taken as its rest state.
func counter(label: Label3D, value: int) -> void:
	if label == null or not is_instance_valid(label):
		return
	var id := label.get_instance_id()
	var now := Time.get_ticks_usec()
	var st: Dictionary = _counters.get(id, {})
	if st.is_empty():
		var shown := value
		if label.text.is_valid_int():
			shown = label.text.to_int()
		st = {"label": label, "from": shown, "to": shown, "shown": shown, "t0": now,
				"pulse_t0": -10000000, "flash_t0": -10000000, "flash": Color.WHITE,
				"base_scale": label.scale, "base_color": label.modulate}
		_counters[id] = st
	var cur: int = st["shown"]
	if value == int(st["to"]):
		if label.text.is_empty() or not label.text.is_valid_int():
			label.text = counter_format % value
		return
	var gain := value > int(st["to"])
	st["from"] = cur
	st["to"] = value
	st["t0"] = now
	# Re-trigger the pulse once the previous one has passed its peak (no jitter on rapid streaks).
	if now - int(st["pulse_t0"]) > 70000:
		st["pulse_t0"] = now
	st["flash_t0"] = now
	st["flash"] = GAIN_COLOR if gain else LOSS_COLOR
	_update_counter(st, now)


## The value a counter label currently displays (mid-roll aware); -1 when unknown.
func counter_shown(label: Label3D) -> int:
	if label == null:
		return -1
	var st: Dictionary = _counters.get(label.get_instance_id(), {})
	return int(st.get("shown", -1))


func _update_counters(now: int) -> void:
	var dead: Array = []
	for id in _counters:
		var st: Dictionary = _counters[id]
		if not is_instance_valid(st["label"]):
			dead.append(id)
			continue
		_update_counter(st, now)
	for id in dead:
		_counters.erase(id)


func _update_counter(st: Dictionary, now: int) -> void:
	var label: Label3D = st["label"]
	var u := clampf(float(now - int(st["t0"])) / (COUNTER_TIME * 1e6), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var shown := int(round(lerpf(float(st["from"]), float(st["to"]), e)))
	if shown != int(st["shown"]) or label.text.is_empty():
		st["shown"] = shown
		label.text = counter_format % shown
	# pulse: up in 70 ms (ease out), back down over 200 ms (ease in-out)
	var pt := float(now - int(st["pulse_t0"])) / 1e6
	var p := 0.0
	if pt < 0.07:
		var a := pt / 0.07
		p = 1.0 - (1.0 - a) * (1.0 - a)
	elif pt < 0.27:
		var b := (pt - 0.07) / 0.2
		p = 1.0 - b * b * (3.0 - 2.0 * b)
	label.scale = (st["base_scale"] as Vector3) * (1.0 + COUNTER_PULSE * p)
	var ft := clampf(float(now - int(st["flash_t0"])) / (COUNTER_FLASH_TIME * 1e6), 0.0, 1.0)
	var base: Color = st["base_color"]
	var fc: Color = st["flash"]
	label.modulate = fc.lerp(base, ft * ft)
