class_name CrowdView
extends MultiMeshInstance3D
## Draws a crowd (the army, an enemy squad, a group of grey recruits) with one MultiMesh and
## one buffer upload per frame. The owner (Army, squads) keeps the unit positions; this node only
## turns them into instances. The march itself (hop, squash, side roll, lean) is animated per
## instance in `shaders/crowd.gdshader` from INSTANCE_CUSTOM = (phase, hop, sway, flash).
## Each unit also gets a small fixed variation in size, heading, hop and sway, so a dense blob
## reads as a living crowd instead of a stamped grid.

const SHADER := preload("res://shaders/crowd.gdshader")
const STRIDE := 20              # 12 transform + 4 colour + 4 custom floats per instance
const FLASH_TIME := 0.16        # seconds a hit flash takes to fade

var max_count := 0
var count := 0
var mat: ShaderMaterial
var _buf := PackedFloat32Array()
var _phase := PackedFloat32Array()  # per-unit march phase
var _var := PackedFloat32Array()    # per unit: scale, yaw offset, hop mult, sway mult, shade
var _flash := PackedFloat32Array()
var _flashing := false
var _last_ms := 0


## Builds the MultiMesh for up to `max_count` units of `mesh`. `texture` is the albedo map of a
## textured (Meshy) mesh; without it the mesh's vertex colours show as they are.
func setup(mesh: Mesh, p_max_count: int, texture: Texture2D = null) -> void:
	max_count = maxi(1, p_max_count)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Per-instance colour is on: the gl_compatibility renderer reads garbage vertex colours from
	# a MultiMesh with custom data but no instance colours. It also gives each unit a slight shade.
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = max_count
	multimesh.visible_instance_count = 0
	mat = make_material(texture)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The shader lifts and leans units beyond their transforms; keep them from being culled.
	extra_cull_margin = 1.0
	_buf.resize(max_count * STRIDE)
	_buf.fill(0.0)
	_phase.resize(max_count)
	_var.resize(max_count * 5)
	_flash.resize(max_count)
	_flash.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in max_count:
		_phase[i] = fmod(i * 2.39996, TAU)
		_var[i * 5] = rng.randf_range(0.93, 1.07)
		_var[i * 5 + 1] = rng.randf_range(-0.12, 0.12)
		_var[i * 5 + 2] = rng.randf_range(0.75, 1.25)
		_var[i * 5 + 3] = rng.randf_range(0.7, 1.3)
		_var[i * 5 + 4] = rng.randf_range(0.9, 1.04)
		var o := i * STRIDE
		_buf[o + 12] = _var[i * 5 + 4]
		_buf[o + 13] = _var[i * 5 + 4]
		_buf[o + 14] = _var[i * 5 + 4]
		_buf[o + 15] = 1.0
	count = 0
	_last_ms = Time.get_ticks_msec()


## A crowd material with the crowd shader (shared look for CrowdView and UnitFx).
static func make_material(texture: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if texture:
		m.set_shader_parameter("albedo_tex", texture)
	return m


## Draws the first `count` units at `positions` (feet, world space), all facing `facing_yaw`
## (radians about Y; 0 = facing +Z, PI = facing the run direction −Z).
## `hop` is the bounce height in world units (≈0.08 marching, ≈0.015 idle), `sway` the side-roll
## amplitude in radians (≈0.08). One buffer upload.
func draw(positions: PackedVector3Array, p_count: int, facing_yaw: float, hop: float, sway: float) -> void:
	if multimesh == null:
		return
	var n := clampi(mini(p_count, positions.size()), 0, max_count)
	count = n
	var now := Time.get_ticks_msec()
	var fade := float(now - _last_ms) * 0.001 / FLASH_TIME
	_last_ms = now
	var flashing := false
	var buf := _buf
	for i in n:
		var p := positions[i]
		var vi := i * 5
		var s: float = _var[vi]
		var yaw := facing_yaw + _var[vi + 1]
		var c := cos(yaw) * s
		var sn := sin(yaw) * s
		var o := i * STRIDE
		buf[o] = c
		buf[o + 1] = 0.0
		buf[o + 2] = sn
		buf[o + 3] = p.x
		buf[o + 4] = 0.0
		buf[o + 5] = s
		buf[o + 6] = 0.0
		buf[o + 7] = p.y
		buf[o + 8] = -sn
		buf[o + 9] = 0.0
		buf[o + 10] = c
		buf[o + 11] = p.z
		buf[o + 16] = _phase[i]
		buf[o + 17] = hop * _var[vi + 2]
		buf[o + 18] = sway * _var[vi + 3]
		var f: float = _flash[i]
		if f > 0.0:
			f = maxf(0.0, f - fade)
			_flash[i] = f
			flashing = true
		buf[o + 19] = f
	_flashing = flashing
	multimesh.buffer = buf
	multimesh.visible_instance_count = n


## Multiplies the albedo (army: Color.WHITE; enemies keep their vertex colours).
func set_tint(c: Color) -> void:
	mat.set_shader_parameter("tint", c)


## 1 = as painted, 0 = grey (recruits that have not joined yet).
func set_saturation(s: float) -> void:
	mat.set_shader_parameter("saturation", s)


## Glowing armour over the whole crowd (e.g. the emerald ult armour); amount 0 = off.
func set_overlay(c: Color, amount: float) -> void:
	mat.set_shader_parameter("overlay_color", c)
	mat.set_shader_parameter("overlay_amount", clampf(amount, 0.0, 1.0))


## Brief white flash on the given units (hits). Shows on the next draw().
func flash_units(idxs: PackedInt32Array) -> void:
	for i in idxs:
		if i >= 0 and i < max_count:
			_flash[i] = 1.0


## Extra (not in the spec): a coloured fresnel edge that helps a team read against the road
## (e.g. ice blue on the army, hot orange on enemies); amount 0 = off.
func set_edge(c: Color, amount: float) -> void:
	mat.set_shader_parameter("edge_color", c)
	mat.set_shader_parameter("edge_amount", maxf(amount, 0.0))


## Extra (not in the spec): march cadence in steps per 2π seconds and sway cycles. Rounded to
## integers so the wrapped shader time stays seamless.
func set_gait(hop_rate: float, sway_rate := -1.0) -> void:
	mat.set_shader_parameter("hop_rate", roundf(maxf(hop_rate, 1.0)))
	if sway_rate > 0.0:
		mat.set_shader_parameter("sway_rate", roundf(sway_rate))


## Extra (not in the spec): true while some unit is still fading a hit flash.
func is_flashing() -> bool:
	return _flashing
