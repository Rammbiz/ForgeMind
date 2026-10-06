class_name UnitFx
extends Node3D
## Soldier deaths and what they leave behind, all drawn with pooled MultiMeshes (one buffer
## upload per pool per frame, only while something moves):
## - dying units: flash white, pop, hop up, tumble and shrink to nothing in 0.35 s;
## - a puff in the team colour (soft noisy quads) plus a few glowing sparks;
## - debris shards (crystal splinters and armour chips) that fall and stay on the road
##   (pool of 64, the oldest is recycled);
## - one soft contact shadow under the army blob.
## Teams: 0 army (white/gold/ice blue), 1 enemy (red/steel), 2 recruit (grey).
## Enemies baked to VAT (set_enemy_vat(), the Emberhorn Sentinel) die differently: the hit pop
## and burst, then each body plays the baked death on its own clock (recoil, topple onto its
## back, a dust puff on impact), lies a moment and sinks away in a puff of rising embers.

const DIE_LIFE := 0.35
const DIE_POP := 0.07           # the white pop before the shrink
const DIE_POOL := 96            # per team
const PUFF_POOL := 256
const SPARK_POOL := 192
const DEBRIS_POOL := 64
const GRAVITY := 15.0
const MOTE_STRIDE := 20         # 12 transform + 4 colour + 4 custom floats
const SHADOW_ALPHA := 0.42
const ENEMY_DIE_LIFE := 1.15     # VAT enemies: death clip (0.75 s), a short rest, sink
const ENEMY_SINK_AT := 0.86      # age the body starts to sink and burn away
const ENEMY_LAND_AT := 0.5       # age the falling body hits the road (dust)
const EMBER_COLORS: Array[Color] = [Color(1.0, 0.55, 0.15), Color(1.0, 0.75, 0.3), Color(1.0, 0.35, 0.1)]
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

const PUFF_COLORS: Array[Color] = [Color(0.4, 0.66, 1.0), Color(1.0, 0.4, 0.2), Color(0.8, 0.81, 0.85)]
const SPARK_COLORS: Array[Color] = [Color(0.55, 0.85, 1.0), Color(1.0, 0.55, 0.2), Color(0.9, 0.92, 1.0)]
const DEBRIS_COLORS := [
	[Color(0.93, 0.95, 1.0), Color(1.0, 0.78, 0.3), Color(0.42, 0.72, 1.0), Color(0.6, 0.86, 1.0)],
	[Color(0.86, 0.16, 0.14), Color(0.32, 0.33, 0.38), Color(1.0, 0.45, 0.18), Color(0.55, 0.08, 0.08)],
	[Color(0.78, 0.79, 0.82), Color(0.55, 0.56, 0.6), Color(0.9, 0.9, 0.92)],
]


class Dying:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var axis := Vector3.RIGHT
	var spin := 0.0
	var yaw := 0.0
	var age := 0.0
	var landed := false
	var burnt := false


class Mote:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var age := 0.0
	var life := 0.5
	var size0 := 0.2
	var size1 := 0.5
	var drag := 3.0
	var grav := 0.0
	var color := Color.WHITE
	var seed := Vector2.ZERO


class Shard:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var axis := Vector3.RIGHT
	var spin := 0.0
	var basis := Basis.IDENTITY
	var scale := Vector3.ONE
	var color := Color.WHITE
	var resting := false
	var alive := false


var _die_mmi: Array[MultiMeshInstance3D] = []
## Per team: the live crowd's unit size (VatClip.crowd_scale), so a dying unit starts at the
## size it was drawn at (the death pools draw the mesh with the plain crowd shader).
var unit_scale := PackedFloat32Array([1.0, 1.0, 1.0])
var _dying: Array = [[], [], []]            # per team: Array of Dying
var _die_buf: Array[PackedFloat32Array] = []
var _puff_mmi: MultiMeshInstance3D
var _spark_mmi: MultiMeshInstance3D
var _puffs: Array = []                      # Array of Mote
var _sparks: Array = []
var _puff_buf := PackedFloat32Array()
var _spark_buf := PackedFloat32Array()
var _debris_mmi: MultiMeshInstance3D
var _shards: Array = []                     # DEBRIS_POOL Shard slots
var _shard_next := 0
var _debris_dirty := false
var _debris_buf := PackedFloat32Array()
var _shadow: MeshInstance3D
var _rng := RandomNumberGenerator.new()
## The enemies' baked crowd (Emberhorn) playing "death" per dying unit; null = tumbling pool.
var _enemy_vat: VatClip


## Builds the pools. `soldier_mesh` is used for the army and the recruits (greyed),
## `raider_mesh` for enemies. Optional textures for Meshy meshes.
func setup(soldier_mesh: Mesh, raider_mesh: Mesh, soldier_tex: Texture2D = null, raider_tex: Texture2D = null) -> void:
	_rng.randomize()
	for team in 3:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Dying%d" % team
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true          # see CrowdView.setup: needed for sane vertex colours
		mm.use_custom_data = true
		mm.mesh = raider_mesh if team == 1 else soldier_mesh
		mm.instance_count = DIE_POOL
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		var m := CrowdView.make_material(raider_tex if team == 1 else soldier_tex)
		if team == 2:
			m.set_shader_parameter("saturation", 0.0)
			m.set_shader_parameter("tint", Color(1.05, 1.07, 1.12))
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.extra_cull_margin = 2.0
		add_child(mmi)
		_die_mmi.append(mmi)
		var b := PackedFloat32Array()
		b.resize(DIE_POOL * 20)
		_die_buf.append(b)
	_puff_mmi = _mote_instance("Puffs", PUFF_POOL, false)
	_spark_mmi = _mote_instance("Sparks", SPARK_POOL, true)
	_puff_buf.resize(PUFF_POOL * MOTE_STRIDE)
	_spark_buf.resize(SPARK_POOL * MOTE_STRIDE)
	_build_debris()
	_build_shadow()


## Extra (not in the spec): swaps the mesh dying army/recruit units use (army weapon tiers).
func set_soldier_mesh(mesh: Mesh) -> void:
	if _die_mmi.size() == 3:
		_die_mmi[0].multimesh.mesh = mesh
		_die_mmi[2].multimesh.mesh = mesh


## Extra: dying enemies use a baked VAT crowd with a "death" clip (the Emberhorn: VatClip.create(
## VatClip.EMBER)) instead of tumbling: the team-1 pool takes its mesh and a material of its own
## that plays the clip on every dying unit's own clock. Ignored for bakes without per-unit clocks.
func set_enemy_vat(clip: VatClip) -> void:
	if clip == null or _die_mmi.size() < 2 or not clip.has_clip("death") or not clip.has_uniform("instance_time"):
		return
	_enemy_vat = clip
	clip.play_per_unit("death")
	clip.material.set_shader_parameter("edge_color", Color(1.0, 0.4, 0.15))
	clip.material.set_shader_parameter("edge_amount", 0.4)
	clip.material.set_shader_parameter("sway_scale", 0.0)
	_die_mmi[1].multimesh.mesh = clip.mesh
	_die_mmi[1].material_override = clip.material
	_die_mmi[1].extra_cull_margin = 2.5


## A unit dies at `pos` (feet): pop, hop up 3–5 u/s, tumble, shrink to nothing in 0.35 s,
## a puff in the team colour and 1–2 debris shards. `push` adds a sideways shove (world u/s).
## VAT enemies (set_enemy_vat) play their death instead, sliding a little with the push.
func die(pos: Vector3, team: int, push: Vector3) -> void:
	team = clampi(team, 0, 2)
	var list: Array = _dying[team]
	if list.size() >= DIE_POOL:
		list.pop_front()
	var d := Dying.new()
	d.pos = pos
	if team == 1 and _enemy_vat:
		var shove := Vector3(push.x, 0.0, push.z)
		d.vel = shove * 0.45 + Vector3(_rng.randf_range(-0.25, 0.25), 0.0, 0.0)
		d.yaw = _rng.randf_range(-0.35, 0.35) + push.x * 0.12
		d.age = _rng.randf_range(0.0, 0.04)
		list.append(d)
		var hit := pos + Vector3(0, 0.42, 0)
		_puff(hit, PUFF_COLORS[1], shove * 0.5)
		_burst_sparks(hit, SPARK_COLORS[1], shove)
		for i in (1 if _rng.randf() < 0.6 else 2):
			_spawn_shard(hit, DEBRIS_COLORS[1][_rng.randi() % DEBRIS_COLORS[1].size()], shove * 0.5)
		return
	var flat := Vector3(push.x, 0.0, push.z)
	d.vel = flat * 0.8 + Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(3.0, 5.0), _rng.randf_range(-0.7, 0.7))
	# Tumble away from the push (or a random side), with some yaw mixed in.
	var away := flat.normalized() if flat.length() > 0.05 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	d.axis = (Vector3.UP.cross(away) + Vector3(0, _rng.randf_range(-0.6, 0.6), 0)).normalized()
	if d.axis.length() < 0.5:
		d.axis = Vector3.RIGHT
	d.spin = _rng.randf_range(9.0, 15.0) * (1.0 if _rng.randf() < 0.75 else -1.0)
	d.yaw = (PI if team == 0 else 0.0) + _rng.randf_range(-0.3, 0.3)
	list.append(d)
	var mid := pos + Vector3(0, 0.38, 0)
	_puff(mid, PUFF_COLORS[team], flat)
	_burst_sparks(mid, SPARK_COLORS[team], flat)
	var pal: Array = DEBRIS_COLORS[team]
	var n := 1 if _rng.randf() < 0.5 else 2
	for i in n:
		_spawn_shard(mid, pal[_rng.randi() % pal.size()], flat * 0.6)


## Throws `n` debris shards of `color` from `pos`; they fall and stay on the road until recycled
## (oldest first) or culled.
func debris(pos: Vector3, color: Color, n := 2) -> void:
	for i in n:
		var c := color.lightened(_rng.randf_range(-0.12, 0.15)) if _rng.randf() < 0.6 else color
		_spawn_shard(pos, c, Vector3.ZERO)


## Frees debris lying behind world z (the run heads to −Z, so behind means z > `z`).
func cull_behind(z: float) -> void:
	for s: Shard in _shards:
		if s.alive and s.pos.z > z:
			s.alive = false
			_debris_dirty = true


## Places the soft contact shadow under the army blob; radius <= 0 hides it.
func set_blob(center: Vector3, radius: float) -> void:
	if _shadow == null:
		return
	_shadow.visible = radius > 0.01
	if not _shadow.visible:
		return
	var r := radius * 1.3 + 0.45
	_shadow.position = Vector3(center.x, center.y + 0.018, center.z)
	_shadow.scale = Vector3(r * 2.0, 1.0, r * 2.0 * 1.15)


## Extra (not in the spec): number of units currently dying (tests, budgets).
func dying_count() -> int:
	var n := 0
	for list: Array in _dying:
		n += list.size()
	return n


## Extra (not in the spec): number of debris shards on the road or in the air.
func debris_count() -> int:
	var n := 0
	for s: Shard in _shards:
		if s.alive:
			n += 1
	return n


func _process(delta: float) -> void:
	if _die_mmi.is_empty():
		return
	delta = minf(delta, 0.05)
	for team in 3:
		_tick_dying(team, delta)
	_tick_motes(_puffs, _puff_mmi, _puff_buf, delta)
	_tick_motes(_sparks, _spark_mmi, _spark_buf, delta)
	_tick_debris(delta)


# ------------------------------------------------------------------ dying units

func _tick_dying(team: int, delta: float) -> void:
	var list: Array = _dying[team]
	var mm := _die_mmi[team].multimesh
	if list.is_empty():
		if mm.visible_instance_count != 0:
			mm.visible_instance_count = 0
		return
	if team == 1 and _enemy_vat:
		_tick_enemy_vat(list, mm, delta)
		return
	var keep: Array = []
	for d: Dying in list:
		d.age += delta
		if d.age < DIE_LIFE:
			d.vel.y -= GRAVITY * delta
			d.pos += d.vel * delta
			if d.pos.y < 0.0:
				d.pos.y = 0.0
				d.vel.y = absf(d.vel.y) * 0.25
			keep.append(d)
	_dying[team] = keep
	var buf := _die_buf[team]
	var i := 0
	for d: Dying in keep:
		var t := d.age
		var pop := 1.0 + 0.22 * sin(clampf(t / DIE_POP, 0.0, 1.0) * PI)
		var shrink := 1.0 - pow(clampf(t / DIE_LIFE, 0.0, 1.0), 2.2)
		var s := maxf(pop * shrink * unit_scale[team], 0.001)
		var b := Basis(d.axis, d.spin * t) * Basis(Vector3.UP, d.yaw)
		b = b.scaled(Vector3(s, s, s))
		# Rotate about the unit's middle, not its feet, so the tumble reads as a flip.
		var origin := d.pos + Vector3(0, 0.38, 0) - b * Vector3(0, 0.38, 0)
		var o := i * 20
		_write_xf(buf, o, Transform3D(b, origin))
		buf[o + 12] = 1.0
		buf[o + 13] = 1.0
		buf[o + 14] = 1.0
		buf[o + 15] = 1.0
		buf[o + 16] = 0.0
		buf[o + 17] = 0.0
		buf[o + 18] = 0.0
		buf[o + 19] = clampf(1.0 - t / 0.14, 0.0, 1.0)
		i += 1
	mm.buffer = buf
	mm.visible_instance_count = i


## VAT enemies: each body plays the death clip at its own age (INSTANCE_CUSTOM.x), slides out
## with the push, raises dust where it lands, then sinks into the road and burns away in embers.
func _tick_enemy_vat(list: Array, mm: MultiMesh, delta: float) -> void:
	var keep: Array = []
	for d: Dying in list:
		d.age += delta
		if d.age >= ENEMY_DIE_LIFE:
			continue
		d.pos += d.vel * delta
		d.vel *= maxf(0.0, 1.0 - 5.0 * delta)
		if not d.landed and d.age >= ENEMY_LAND_AT:
			d.landed = true
			_dust(d.pos + Basis(Vector3.UP, d.yaw) * Vector3(0, 0.05, -0.3))
		if not d.burnt and d.age >= ENEMY_SINK_AT:
			d.burnt = true
			_embers(d.pos + Basis(Vector3.UP, d.yaw) * Vector3(0, 0.12, -0.28))
		keep.append(d)
	_dying[1] = keep
	var buf := _die_buf[1]
	var i := 0
	for d: Dying in keep:
		var k := clampf((d.age - ENEMY_SINK_AT) / (ENEMY_DIE_LIFE - ENEMY_SINK_AT), 0.0, 1.0)
		var e := k * k
		var s := maxf(unit_scale[1] * (1.0 - 0.75 * e), 0.001)
		var b := Basis(Vector3.UP, d.yaw).scaled(Vector3(s, s, s))
		var o := i * 20
		_write_xf(buf, o, Transform3D(b, d.pos + Vector3(0, -0.22 * e, 0)))
		buf[o + 12] = 1.0 - 0.6 * e
		buf[o + 13] = 1.0 - 0.75 * e
		buf[o + 14] = 1.0 - 0.8 * e
		buf[o + 15] = 1.0
		buf[o + 16] = d.age
		buf[o + 17] = 0.0
		buf[o + 18] = 0.0
		buf[o + 19] = clampf(1.0 - d.age / 0.14, 0.0, 1.0)
		i += 1
	mm.buffer = buf
	mm.visible_instance_count = i


## A low dust puff where a falling body hits the road.
func _dust(pos: Vector3) -> void:
	for i in 4:
		var m := Mote.new()
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0.15, sin(a))
		m.pos = pos + dir * 0.1
		m.vel = dir * _rng.randf_range(0.8, 1.4)
		m.life = _rng.randf_range(0.4, 0.55)
		m.size0 = _rng.randf_range(0.16, 0.22)
		m.size1 = _rng.randf_range(0.36, 0.5)
		m.drag = 5.0
		m.grav = -0.3
		m.color = Color(0.42, 0.36, 0.38, 0.45)
		m.seed = Vector2(_rng.randf(), _rng.randf())
		_add_mote(_puffs, PUFF_POOL, m)


## The body burns away: glowing embers drift up with a little dark smoke.
func _embers(pos: Vector3) -> void:
	for i in 5:
		var m := Mote.new()
		var a := _rng.randf() * TAU
		m.pos = pos + Vector3(cos(a) * 0.18, _rng.randf_range(0.0, 0.12), sin(a) * 0.25)
		m.vel = Vector3(cos(a) * 0.3, _rng.randf_range(1.0, 1.9), sin(a) * 0.3)
		m.life = _rng.randf_range(0.5, 0.8)
		m.size0 = _rng.randf_range(0.07, 0.11)
		m.size1 = 0.02
		m.drag = 1.5
		m.grav = -0.8
		m.color = EMBER_COLORS[i % EMBER_COLORS.size()]
		m.color.a = 1.0
		_add_mote(_sparks, SPARK_POOL, m)
	var smoke := Mote.new()
	smoke.pos = pos + Vector3(0, 0.1, 0)
	smoke.vel = Vector3(0, 0.6, 0)
	smoke.life = 0.6
	smoke.size0 = 0.3
	smoke.size1 = 0.6
	smoke.drag = 2.0
	smoke.color = Color(0.18, 0.12, 0.12, 0.4)
	smoke.seed = Vector2(_rng.randf(), _rng.randf())
	_add_mote(_puffs, PUFF_POOL, smoke)


# ------------------------------------------------------------------ puffs and sparks

func _mote_instance(node_name: String, pool: int, additive: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = pool
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	var sh := Shader.new()
	sh.code = _mote_shader(additive)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 4.0
	add_child(mmi)
	return mmi


func _mote_shader(additive: bool) -> String:
	var blend := "blend_add" if additive else "blend_mix"
	return """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;
// Camera-facing soft puff / spark. INSTANCE_CUSTOM = (noise u, noise v, age 0..1, core glow).
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float wisp = %s;
varying vec4 v_cd;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_cd = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = clamp(1.0 - dot(d, d), 0.0, 1.0);
	float n = texture(noise_tex, UV * 0.55 + v_cd.xy).r;
	// Wispy edge that eats into the puff as it ages.
	float shape = r * mix(1.0, smoothstep(v_cd.z * 0.7, v_cd.z * 0.7 + 0.45, n * (0.35 + r)), wisp);
	float core = r * r * r * v_cd.w;
	ALBEDO = to_linear(COLOR.rgb) * (1.0 + core * 2.0);
	ALPHA = clamp(COLOR.a * shape * 1.4, 0.0, 1.0);
}
""" % [blend, "0.0" if additive else "1.0"]


func _puff(pos: Vector3, color: Color, push: Vector3) -> void:
	# A white core blink, then 6 team-coloured balls that billow out and up.
	var core := Mote.new()
	core.pos = pos
	core.life = 0.14
	core.size0 = 0.6
	core.size1 = 0.95
	core.color = Color(1, 1, 1, 0.6)
	core.seed = Vector2(_rng.randf(), _rng.randf())
	_add_mote(_puffs, PUFF_POOL, core)
	for i in 6:
		var m := Mote.new()
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), _rng.randf_range(0.1, 0.8), sin(a))
		m.pos = pos + dir * 0.08
		m.vel = dir * _rng.randf_range(1.0, 2.0) + push * 0.3 + Vector3(0, 0.4, 0)
		m.life = _rng.randf_range(0.42, 0.6)
		m.size0 = _rng.randf_range(0.22, 0.32)
		m.size1 = _rng.randf_range(0.48, 0.68)
		m.drag = 4.5
		m.grav = -0.6
		# Crystal-tinted, not white: a mass death reads as shattering knights, not a snow cloud.
		m.color = color.lerp(Color.WHITE, _rng.randf_range(0.0, 0.18))
		m.color.a = 0.72
		m.seed = Vector2(_rng.randf(), _rng.randf())
		_add_mote(_puffs, PUFF_POOL, m)


func _burst_sparks(pos: Vector3, color: Color, push: Vector3) -> void:
	for i in 5:
		var m := Mote.new()
		var a := _rng.randf() * TAU
		m.pos = pos
		m.vel = Vector3(cos(a) * _rng.randf_range(1.5, 3.2), _rng.randf_range(2.0, 4.0), sin(a) * _rng.randf_range(1.5, 3.2)) + push * 0.4
		m.life = _rng.randf_range(0.35, 0.55)
		m.size0 = _rng.randf_range(0.13, 0.18)
		m.size1 = 0.03
		m.drag = 1.2
		m.grav = 9.0
		m.color = color
		m.color.a = 1.0
		_add_mote(_sparks, SPARK_POOL, m)


func _add_mote(list: Array, pool: int, m: Mote) -> void:
	if list.size() >= pool:
		list.pop_front()
	list.append(m)


func _tick_motes(list: Array, mmi: MultiMeshInstance3D, buf: PackedFloat32Array, delta: float) -> void:
	var mm := mmi.multimesh
	if list.is_empty():
		if mm.visible_instance_count != 0:
			mm.visible_instance_count = 0
		return
	var keep: Array = []
	for m: Mote in list:
		m.age += delta
		if m.age < m.life:
			m.vel *= maxf(0.0, 1.0 - m.drag * delta)
			m.vel.y -= m.grav * delta
			m.pos += m.vel * delta
			keep.append(m)
	list.assign(keep)
	var stride := MOTE_STRIDE
	var i := 0
	for m: Mote in keep:
		var k := m.age / m.life
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		var s := lerpf(m.size0, m.size1, e)
		var o := i * stride
		buf[o] = s
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = m.pos.x
		buf[o + 4] = 0.0
		buf[o + 5] = s
		buf[o + 6] = 0.0
		buf[o + 7] = m.pos.y
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = s
		buf[o + 11] = m.pos.z
		var fade := 1.0 - smoothstep(0.55, 1.0, k)
		buf[o + 12] = m.color.r
		buf[o + 13] = m.color.g
		buf[o + 14] = m.color.b
		buf[o + 15] = m.color.a * fade
		buf[o + 16] = m.seed.x
		buf[o + 17] = m.seed.y
		buf[o + 18] = k
		buf[o + 19] = 1.0 - k
		i += 1
	mm.buffer = buf
	mm.visible_instance_count = i


# ------------------------------------------------------------------ debris

func _build_debris() -> void:
	_debris_mmi = MultiMeshInstance3D.new()
	_debris_mmi.name = "Debris"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _shard_mesh()
	mm.instance_count = DEBRIS_POOL
	mm.visible_instance_count = 0
	_debris_mmi.multimesh = mm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Crystal splinters and armour chips: glossy, a faint inner glow so they glint on the road.
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = c;
	ROUGHNESS = 0.28;
	METALLIC = 0.2;
	SPECULAR = 0.75;
	EMISSION = c * (0.18 + 0.6 * fres);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_debris_mmi.material_override = m
	_debris_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_debris_mmi.extra_cull_margin = 1.0
	add_child(_debris_mmi)
	_shards.clear()
	for i in DEBRIS_POOL:
		_shards.append(Shard.new())
	_debris_buf.resize(DEBRIS_POOL * 16)


## An irregular faceted splinter (a skewed bipyramid), about 0.17 long. Non-uniform instance
## scales turn it into long crystal needles or flat armour chips.
func _shard_mesh() -> ArrayMesh:
	var ring: Array[Vector3] = []
	var sides := 5
	for i in sides:
		var a := TAU * i / sides + (0.25 if i % 2 == 0 else -0.1)
		var r := 0.055 * (1.0 if i % 2 == 0 else 0.75)
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var top := Vector3(0.012, 0.11, -0.008)
	var bot := Vector3(-0.01, -0.055, 0.006)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in sides:
		var a := ring[i]
		var b := ring[(i + 1) % sides]
		for tri in [[a, top, b], [b, bot, a]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			var n := (p1 - p0).cross(p2 - p0).normalized()
			if n.dot((p0 + p1 + p2) / 3.0) < 0.0:
				n = -n
				var tmp := p1
				p1 = p2
				p2 = tmp
			# Godot front faces are clockwise seen from outside.
			verts.append_array(PackedVector3Array([p0, p2, p1]))
			norms.append_array(PackedVector3Array([n, n, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _spawn_shard(pos: Vector3, color: Color, push: Vector3) -> void:
	var s: Shard = _shards[_shard_next]
	_shard_next = (_shard_next + 1) % DEBRIS_POOL
	s.alive = true
	s.resting = false
	s.pos = pos
	var a := _rng.randf() * TAU
	var sp := _rng.randf_range(0.8, 2.2)
	s.vel = Vector3(cos(a) * sp, _rng.randf_range(2.2, 3.8), sin(a) * sp) + push
	s.axis = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	if s.axis.length() < 0.5:
		s.axis = Vector3.RIGHT
	s.spin = _rng.randf_range(10.0, 20.0)
	s.basis = Basis(s.axis, _rng.randf() * TAU)
	var kind := _rng.randf()
	if kind < 0.55:
		s.scale = Vector3.ONE * _rng.randf_range(0.9, 1.5) * Vector3(0.8, 1.6, 0.8)    # crystal needle
	else:
		s.scale = Vector3.ONE * _rng.randf_range(1.0, 1.6) * Vector3(1.6, 0.45, 1.3)   # armour chip
	s.color = color
	_debris_dirty = true


func _tick_debris(delta: float) -> void:
	var moving := false
	for s: Shard in _shards:
		if not s.alive or s.resting:
			continue
		moving = true
		s.vel.y -= GRAVITY * delta
		s.pos += s.vel * delta
		s.basis = Basis(s.axis, s.spin * delta) * s.basis
		var floor_y := 0.012 * s.scale.y
		if s.pos.y <= floor_y and s.vel.y < 0.0:
			s.pos.y = floor_y
			if s.vel.y < -2.0:
				# One small bounce, then it settles flat on the road.
				s.vel = Vector3(s.vel.x * 0.45, -s.vel.y * 0.28, s.vel.z * 0.45)
				s.spin *= 0.4
			else:
				s.resting = true
				var lie := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5 + _rng.randf_range(-0.25, 0.25))
				s.basis = lie if s.scale.y > s.scale.x else Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2))
	if not (moving or _debris_dirty):
		return
	_debris_dirty = false
	var buf := _debris_buf
	var n := 0
	for s: Shard in _shards:
		var o := n * 16
		if not s.alive:
			continue
		_write_xf(buf, o, Transform3D(s.basis * Basis.from_scale(s.scale), s.pos))
		buf[o + 12] = s.color.r
		buf[o + 13] = s.color.g
		buf[o + 14] = s.color.b
		buf[o + 15] = 1.0
		n += 1
	var mm := _debris_mmi.multimesh
	mm.buffer = buf
	mm.visible_instance_count = n


# ------------------------------------------------------------------ contact shadow

func _build_shadow() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = tex
	m.albedo_color = Color(0.01, 0.02, 0.07, SHADOW_ALPHA)
	m.render_priority = -1
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	_shadow = MeshInstance3D.new()
	_shadow.name = "ContactShadow"
	_shadow.mesh = q
	_shadow.material_override = m
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.visible = false
	add_child(_shadow)


# ------------------------------------------------------------------ helpers

## Writes a transform into a MultiMesh buffer at `o` (3 rows of basis + origin).
static func _write_xf(buf: PackedFloat32Array, o: int, xf: Transform3D) -> void:
	var b := xf.basis
	buf[o] = b.x.x
	buf[o + 1] = b.y.x
	buf[o + 2] = b.z.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = b.x.y
	buf[o + 5] = b.y.y
	buf[o + 6] = b.z.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = b.x.z
	buf[o + 9] = b.y.z
	buf[o + 10] = b.z.z
	buf[o + 11] = xf.origin.z
