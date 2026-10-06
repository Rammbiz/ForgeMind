class_name VatClip
extends RefCounted
## Plays baked skeletal clips (tools/bake_vat.gd) on a crowd: one VatClip per CrowdView, all of
## its units playing the same clip, each at its own phase (INSTANCE_CUSTOM.x), drawn by
## shaders/crowd_vat.gdshader.
##
##   var anim := VatClip.create()     # res://assets/units/knight/knight
##   view.setup(anim.mesh, 220)       # CrowdView: the baked mesh is 0.75 tall, feet at 0, facing +Z
##   anim.attach(view)                # swaps in the VAT material; set_tint() & co. keep working
##   anim.set_unit_scale(VatClip.crowd_scale(220))
##   anim.play("run", 0.2, false, VatClip.run_rate(Balance.RUN_SPEED))
##   # every frame, next to view.draw(...):
##   anim.tick(delta)
##   # state changes (0.2 s cross-fade; play() of the clip already playing with restart = false
##   # only updates the rate):
##   anim.play("attack", 0.2, false)
##   anim.play("victory", 0.25, true, 1.0, 0)   # once, units staggered by up to 0.25 s
##
## Clips of the knight bake: run, walk, attack (spear stab), idle, victory (jump with the spear
## thrust up, loops), spin (the 360 power spin jump).
## Clips of the Emberhorn bake (enemy squads, VatClip.create(EMBER)): run, attack, idle (guard),
## death (one-shot). A bake may ship its own shader as <base>_vat.gdshader (the Emberhorn's adds a
## zone clip and per-unit clocks, see set_zone() and play_per_unit()).
##
## The clip clock runs here in double precision and reaches the shader as `clip_time`; without
## tick() the shader falls back to TIME wrapped to whole loops (fine for a looping clip).

const SHADER := preload("res://shaders/crowd_vat.gdshader")
## Run clip playback rate at Balance.RUN_SPEED. The chibi stride covers only ground_speed("run")
## (1.15 u/s at rate 1) while the army moves at 6.5 u/s; a foot-locked rate (5.6) is a blur, so
## the cadence is stylised (≈ 4.3 steps a second) and scales with the march speed (run_rate()).
const RUN_RATE := 1.35
## Bake prefix of the owner's Emberhorn Sentinel (enemy squads).
const EMBER := "res://assets/units/emberhorn/emberhorn"
# The script itself, so create() works before the editor has registered the class_name.
const _SELF := preload("res://scripts/run/vat_clip.gd")

var mesh: ArrayMesh
var albedo: Texture2D
## Clip table from the bake: name -> {frame, frames, fps, length, loop, ground_speed, ...}.
var clips: Dictionary = {}
var material: ShaderMaterial
var clip := ""
## Playback rate of the current clip (1 = as baked).
var speed := 1.0
## How far out of step the units of a looping clip are, per clip: the share of one loop their
## phases cover (1 = every unit somewhere else in its stride, 0.3 = a ragged wave). Clips not
## listed use 1. Takes effect on the next play().
var spread := {"victory": 0.55, "spin": 0.3, "attack": 0.8}
## Bake prefix this clip set was loaded from.
var base := ""
## Zone clip (shaders with zone support): the clip units past `zone_z` play (see set_zone()).
var zone := ""
var zone_speed := 1.0

var _t := 0.0
var _loop := true
var _prev := ""
var _prev_t := 0.0
var _prev_speed := 1.0
var _prev_loop := true
var _fade := 1.0
var _fade_len := 0.0
var _zone_t := 0.0


## Loads `<base>_vat_mesh.res` and its textures (cached by the resource loader) and builds a
## material for one crowd. `base` is the bake output prefix, e.g. "res://assets/units/knight/knight".
static func create(base := "res://assets/units/knight/knight") -> _SELF:
	var v: _SELF = _SELF.new()
	v.base = base
	v.mesh = load(base + "_vat_mesh.res") as ArrayMesh
	if v.mesh == null or not v.mesh.has_meta("vat"):
		push_error("VatClip: no baked mesh at %s_vat_mesh.res (run tools/bake_vat.gd)" % base)
		return null
	var meta: Dictionary = v.mesh.get_meta("vat")
	var dir := base.get_base_dir()
	var tex: Dictionary = meta["textures"]
	v.clips = meta["clips"]
	v.albedo = load(dir.path_join(tex["albedo"])) as Texture2D
	var m := ShaderMaterial.new()
	m.shader = SHADER
	# A bake-specific look (same VAT decode and uniforms) when one sits next to the bake.
	if ResourceLoader.exists(base + "_vat.gdshader"):
		m.shader = load(base + "_vat.gdshader") as Shader
	m.set_shader_parameter("vat_pos", load(dir.path_join(tex["pos"])))
	m.set_shader_parameter("vat_nrm", load(dir.path_join(tex["nrm"])))
	m.set_shader_parameter("vat_width", int(meta["width"]))
	m.set_shader_parameter("vat_rows_per_frame", int(meta["rows_per_frame"]))
	if v.albedo:
		m.set_shader_parameter("albedo_tex", v.albedo)
	v.material = m
	return v


## Puts this material on a CrowdView (its `mat`, so set_tint/set_overlay/... act on it) or on any
## GeometryInstance3D. The look uniforms both crowd shaders share (tint, saturation, overlay,
## edge, gait, foot occlusion...) are carried over from the material it replaces, so calls made
## on the CrowdView before attach() still show.
func attach(view: GeometryInstance3D) -> void:
	var old: Material = view.get("mat") if "mat" in view else view.material_override
	if old is ShaderMaterial and old != material:
		var mine := {}
		for u: Dictionary in material.shader.get_shader_uniform_list():
			mine[u["name"]] = true
		for u: Dictionary in (old as ShaderMaterial).shader.get_shader_uniform_list():
			var n: String = u["name"]
			if mine.has(n) and not n.begins_with("vat_") and n != "albedo_tex":
				var v: Variant = (old as ShaderMaterial).get_shader_parameter(n)
				if v != null:
					material.set_shader_parameter(n, v)
	if "mat" in view:
		view.set("mat", material)
	view.material_override = material


func has_clip(clip_name: String) -> bool:
	return clips.has(clip_name)


## Seconds one pass of the clip takes at playback rate 1.
func length(clip_name: String) -> float:
	return float(clips[clip_name]["length"]) if clips.has(clip_name) else 0.0


## How fast the feet push the ground back at playback rate 1 (world units per second at the baked
## size; 0 for clips that do not travel). Playback rate for a march speed = speed / ground_speed.
func ground_speed(clip_name: String) -> float:
	return float(clips[clip_name].get("ground_speed", 0.0)) if clips.has(clip_name) else 0.0


## Switches every unit to `clip_name`, cross-fading from the current clip over `fade` seconds.
## `restart` = false keeps the clock when the clip is already playing. `playback_speed` < 0 keeps
## the current rate. `loop` -1 = as baked, 0 = play once and hold the last frame, 1 = loop.
func play(clip_name: String, fade := 0.2, restart := true, playback_speed := -1.0, loop := -1) -> void:
	if not clips.has(clip_name):
		push_warning("VatClip: no clip '%s' (have %s)" % [clip_name, ", ".join(clips.keys())])
		return
	var new_loop: bool = bool(clips[clip_name]["loop"]) if loop < 0 else loop == 1
	if clip_name == clip and not restart and new_loop == _loop:
		if playback_speed >= 0.0:
			speed = playback_speed
		return
	if clip != "" and fade > 0.0:
		_prev = clip
		_prev_t = _t
		_prev_speed = speed
		_prev_loop = _loop
		_fade = 0.0
		_fade_len = fade
		material.set_shader_parameter("prev_clip", _clip_vec(_prev, _prev_loop))
	else:
		_fade = 1.0
	if playback_speed >= 0.0:
		speed = playback_speed
	clip = clip_name
	_loop = new_loop
	_t = 0.0
	material.set_shader_parameter("clip", _clip_vec(clip, _loop))
	material.set_shader_parameter("speed", 1.0)
	_push()


## Run clip playback rate for a march at `world_speed` (world units per second).
static func run_rate(world_speed: float) -> float:
	return RUN_RATE * world_speed / Balance.RUN_SPEED


## Size of every unit of this crowd (1 = as baked, 0.75 tall).
func set_unit_scale(s: float) -> void:
	material.set_shader_parameter("unit_scale", s)


## Suggested unit size for a crowd of `shown` drawn units: full size for small armies, 0.86 at
## 220, so the knights' wide helmets stay apart in the dense blob (slot spacing ≈ 0.27).
static func crowd_scale(shown: int) -> float:
	return lerpf(1.0, 0.86, clampf((shown - 40.0) / 180.0, 0.0, 1.0))


## Zone clip (shaders with a `zone_on` uniform, e.g. the Emberhorn's): units standing beyond world
## z = `z` (towards +Z) play `clip_name` on its own clock, blended in over `band`; the others keep
## the main clip. Squads: the front rank stabs while the ranks behind run up. Calling it again
## with the same clip only moves the line.
func set_zone(clip_name: String, z: float, band := 0.3, playback_speed := 1.0) -> void:
	if not clips.has(clip_name):
		return
	if clip_name != zone:
		zone = clip_name
		_zone_t = 0.0
		material.set_shader_parameter("zone_clip", _clip_vec(clip_name, bool(clips[clip_name]["loop"])))
	zone_speed = playback_speed
	material.set_shader_parameter("zone_on", true)
	material.set_shader_parameter("zone_z", z)
	material.set_shader_parameter("zone_band", band)


func clear_zone() -> void:
	if zone == "":
		return
	zone = ""
	material.set_shader_parameter("zone_on", false)


## Per-unit clocks (shaders with an `instance_time` uniform): every instance plays `clip_name` at
## its own time in seconds, written by the owner into INSTANCE_CUSTOM.x (UnitFx's dying enemies).
func play_per_unit(clip_name: String, playback_speed := 1.0) -> void:
	if not clips.has(clip_name):
		push_warning("VatClip: no clip '%s'" % clip_name)
		return
	clip = clip_name
	_loop = bool(clips[clip_name]["loop"])
	speed = playback_speed
	_fade = 1.0
	material.set_shader_parameter("instance_time", true)
	material.set_shader_parameter("clip", _clip_vec(clip_name, _loop))
	material.set_shader_parameter("speed", playback_speed)
	material.set_shader_parameter("clip_blend", 1.0)


## True when this material's shader has the uniform `uniform_name` (bake-specific features).
func has_uniform(uniform_name: String) -> bool:
	for u: Dictionary in material.shader.get_shader_uniform_list():
		if u["name"] == uniform_name:
			return true
	return false


## Advances the clock (call once per frame with the frame's delta).
func tick(delta: float) -> void:
	if clip == "":
		return
	if zone != "":
		_zone_t += delta * zone_speed
		material.set_shader_parameter("zone_time", _wrapped(zone, _zone_t, bool(clips[zone]["loop"])))
	_t += delta * speed
	if _fade < 1.0:
		_prev_t += delta * _prev_speed
		_fade = minf(1.0, _fade + delta / maxf(_fade_len, 1e-4))
	_push()


## Sets the clock directly (seconds into the clip at rate 1), e.g. to freeze a pose.
func seek(t: float) -> void:
	_t = t
	_fade = 1.0
	_push()


## True once a clip played with loop = 0 has reached its last frame on every unit.
func is_finished() -> bool:
	if clip == "" or _loop:
		return false
	var j: Variant = material.get_shader_parameter("oneshot_jitter")
	return _t >= length(clip) + (float(j) if j != null else 0.25)


func _clip_vec(clip_name: String, looping: bool) -> Vector4:
	var c: Dictionary = clips[clip_name]
	var w := clampf(float(spread.get(clip_name, 1.0)), 0.002, 1.0) if looping else 0.0
	return Vector4(float(c["frame"]), float(c["frames"]), float(c["fps"]), w)


## Wraps a looping clock to a whole number of loops (about a minute) so the shader's float time
## never loses precision; one-shots just stop growing.
func _wrapped(clip_name: String, t: float, looping: bool) -> float:
	var l := length(clip_name)
	if l <= 0.0:
		return 0.0
	if not looping:
		return minf(t, l + 10.0)
	var period := l * ceilf(60.0 / l)
	return fposmod(t, period)


func _push() -> void:
	material.set_shader_parameter("clip_time", _wrapped(clip, _t, _loop))
	material.set_shader_parameter("clip_blend", _fade)
	if _fade < 1.0:
		material.set_shader_parameter("prev_time", _wrapped(_prev, _prev_t, _prev_loop))
