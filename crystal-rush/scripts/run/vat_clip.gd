class_name VatClip
extends RefCounted
## Plays baked skeletal clips (tools/bake_vat.gd) on a crowd: one VatClip per CrowdView, all of
## its units playing the same clip, each at its own phase (INSTANCE_CUSTOM.x), drawn by
## shaders/crowd_vat.gdshader.
##
##   var anim := VatClip.create("res://assets/units/knight/knight")
##   army.setup(anim.mesh, 220)      # CrowdView: the baked mesh is 0.75 tall, feet at 0, facing +Z
##   anim.attach(army)               # swaps in the VAT material; set_tint() & co. keep working
##   anim.play("run")
##   # every frame, next to army.draw(...):
##   anim.tick(delta)
##   # state changes:
##   anim.play("attack")             # 0.2 s cross-fade
##   anim.play("victory", 0.25, true, 1.0, false)   # once, units staggered by up to 0.25 s
##
## The clip clock runs here in double precision and reaches the shader as `clip_time`; without
## tick() the shader falls back to TIME wrapped to whole loops (fine for a looping clip).

const SHADER := preload("res://shaders/crowd_vat.gdshader")
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

var _t := 0.0
var _loop := true
var _prev := ""
var _prev_t := 0.0
var _prev_speed := 1.0
var _prev_loop := true
var _fade := 1.0
var _fade_len := 0.0


## Loads `<base>_vat_mesh.res` and its textures (cached by the resource loader) and builds a
## material for one crowd. `base` is the bake output prefix, e.g. "res://assets/units/knight/knight".
static func create(base := "res://assets/units/knight/knight") -> _SELF:
	var v: _SELF = _SELF.new()
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
	m.set_shader_parameter("vat_pos", load(dir.path_join(tex["pos"])))
	m.set_shader_parameter("vat_nrm", load(dir.path_join(tex["nrm"])))
	m.set_shader_parameter("vat_width", int(meta["width"]))
	m.set_shader_parameter("vat_rows_per_frame", int(meta["rows_per_frame"]))
	if v.albedo:
		m.set_shader_parameter("albedo_tex", v.albedo)
	v.material = m
	return v


## Puts this material on a CrowdView (its `mat`, so set_tint/set_overlay/... act on it) or on any
## GeometryInstance3D.
func attach(view: GeometryInstance3D) -> void:
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


## Advances the clock (call once per frame with the frame's delta).
func tick(delta: float) -> void:
	if clip == "":
		return
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
	return _t >= length(clip) + float(material.get_shader_parameter("oneshot_jitter"))


func _clip_vec(clip_name: String, looping: bool) -> Vector4:
	var c: Dictionary = clips[clip_name]
	return Vector4(float(c["frame"]), float(c["frames"]), float(c["fps"]), 1.0 if looping else 0.0)


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
