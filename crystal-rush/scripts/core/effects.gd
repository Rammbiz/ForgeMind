class_name Effects
extends Node3D
## Visual effects for the run: projectiles, laser beams, muzzle flashes, shockwaves, sparks,
## smoke, flashes, rings, lightning and coins.
##
## The busy effects are pooled in four MultiMeshes (one draw call and one buffer upload per
## frame each): additive streaks (projectile trails, volley lines, velocity-stretched sparks),
## additive glow sprites (flashes, flares, projectile heads), alpha smoke puffs and lit rocket
## bodies. Shockwave rings and beams are a few reused nodes. Everything else (burst(),
## ring(), lightning(), crystal_spikes()...) is kept from the first version.

const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const STREAK_SHADER := preload("res://shaders/fx_streak.gdshader")
const GLOW_SHADER := preload("res://shaders/fx_glow.gdshader")
const SMOKE_SHADER := preload("res://shaders/fx_smoke.gdshader")
const BEAM_SHADER := preload("res://shaders/fx_beam.gdshader")
const RING_SHADER := preload("res://shaders/fx_ring.gdshader")
const MAX_STREAKS := 1400
const MAX_GLOWS := 320
const MAX_SMOKE := 360
const MAX_ROCKETS := 48
const MAX_RINGS := 10
## Projectile looks: colour of the trail, head glow size, trail length and width, arc height
## per unit of distance, impact style.
const KINDS := {
	"bolt": {"color": Color(1.0, 0.78, 0.38), "glow": 0.9, "len": 2.3, "width": 0.24, "arc": 0.0, "head": Color(0.8, 0.95, 1.0)},
	"plasma": {"color": Color(0.82, 0.42, 1.0), "glow": 1.7, "len": 1.5, "width": 0.55, "arc": 0.0, "head": Color(0.75, 0.92, 1.0)},
	"rocket": {"color": Color(1.0, 0.62, 0.25), "glow": 0.95, "len": 1.2, "width": 0.24, "arc": 0.24, "head": Color(1.0, 0.75, 0.35)},
	"drone": {"color": Color(0.35, 1.0, 0.75), "glow": 0.6, "len": 1.4, "width": 0.14, "arc": 0.0, "head": Color(0.6, 1.0, 0.85)},
	"volley": {"color": Color(1.0, 0.9, 0.62), "glow": 0.0, "len": 1.25, "width": 0.11, "arc": 0.07, "head": Color(1.0, 1.0, 1.0)},
	"turret": {"color": Color(1.0, 0.42, 0.15), "glow": 0.85, "len": 1.6, "width": 0.22, "arc": 0.0, "head": Color(1.0, 0.6, 0.3)},
}

var quality_high := true
var _lightning: Array = []   # [{mesh: MeshInstance3D, t: float, life: float}]
var _rings: Array = []       # [{node, t, life, from, to}]
var _flashes: Array = []     # [{node, t, life, from, to}]
var _coins: Array = []       # [{node, t, vel}]
var _spikes: Array = []      # [{node, rot, t, life}]

var _ready_pools := false
var _streak_mm: MultiMesh
var _glow_mm: MultiMesh
var _smoke_mm: MultiMesh
var _rocket_mm: MultiMesh
var _streak_buf := PackedFloat32Array()
var _glow_buf := PackedFloat32Array()
var _smoke_buf := PackedFloat32Array()
var _rocket_buf := PackedFloat32Array()
var _sparks := _Parts.new()          # free streak particles
var _glows := _Parts.new()           # timed glow sprites
var _smoke := _Parts.new()           # smoke puffs
var _frame_streaks: Array = []       # [pos, dir, len, width, color] this frame only
var _frame_glows: Array = []         # [pos, size, color, flare, rot, core] this frame only
var _projectiles: Array[Dictionary] = []
var _beams := {}                     # id -> {node, mat, from, to, color, k, on, seen, spark}
var _ring_pool: Array[Dictionary] = []   # {node, mat, t, life, active}
var _time := 0.0


## A set of simple particles in packed arrays (removal swaps with the last one).
class _Parts:
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var col := PackedColorArray()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var size := PackedFloat32Array()
	var size_end := PackedFloat32Array()
	var grav := PackedFloat32Array()
	var drag := PackedFloat32Array()
	var extra := PackedFloat32Array()     # sparks: length factor; glows: flare; smoke: noise seed
	var n := 0
	var cap := 0

	func init(p_cap: int) -> void:
		cap = p_cap
		for arr: String in ["pos", "vel"]:
			var a := PackedVector3Array()
			a.resize(cap)
			set(arr, a)
		col.resize(cap)
		for arr: String in ["age", "life", "size", "size_end", "grav", "drag", "extra"]:
			var f := PackedFloat32Array()
			f.resize(cap)
			set(arr, f)

	func add(p: Vector3, v: Vector3, c: Color, p_life: float, s0: float, s1: float, g: float, d: float, x: float) -> void:
		var i := n
		if n >= cap:
			# Full: recycle the oldest-looking slot (the first one).
			i = 0
		else:
			n += 1
		pos[i] = p
		vel[i] = v
		col[i] = c
		age[i] = 0.0
		life[i] = maxf(p_life, 0.01)
		size[i] = s0
		size_end[i] = s1
		grav[i] = g
		drag[i] = d
		extra[i] = x

	func step(delta: float) -> void:
		var i := 0
		while i < n:
			age[i] += delta
			if age[i] >= life[i]:
				n -= 1
				pos[i] = pos[n]
				vel[i] = vel[n]
				col[i] = col[n]
				age[i] = age[n]
				life[i] = life[n]
				size[i] = size[n]
				size_end[i] = size_end[n]
				grav[i] = grav[n]
				drag[i] = drag[n]
				extra[i] = extra[n]
				continue
			var v := vel[i]
			v.y += grav[i] * delta
			v *= maxf(0.0, 1.0 - drag[i] * delta)
			vel[i] = v
			pos[i] += v * delta
			i += 1


func _ready() -> void:
	_ensure_pools()


func _ensure_pools() -> void:
	if _ready_pools:
		return
	_ready_pools = true
	_sparks.init(MAX_STREAKS)
	_glows.init(MAX_GLOWS)
	_smoke.init(MAX_SMOKE)
	_streak_mm = _pool_mm("Streaks", _streak_mesh(), STREAK_SHADER, MAX_STREAKS, false)
	_glow_mm = _pool_mm("Glows", Mats.quad(Vector2(1, 1), false), GLOW_SHADER, MAX_GLOWS, true)
	_smoke_mm = _pool_mm("Smoke", Mats.quad(Vector2(1, 1), false), SMOKE_SHADER, MAX_SMOKE, true)
	_rocket_mm = MultiMesh.new()
	_rocket_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rocket_mm.mesh = _rocket_mesh()
	_rocket_mm.instance_count = MAX_ROCKETS
	_rocket_mm.visible_instance_count = 0
	var rmi := MultiMeshInstance3D.new()
	rmi.name = "Rockets"
	rmi.multimesh = _rocket_mm
	rmi.material_override = Mats.vertex_colored(0.4)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rmi.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(rmi)
	_streak_buf.resize(MAX_STREAKS * 16)
	_glow_buf.resize(MAX_GLOWS * 20)
	_smoke_buf.resize(MAX_SMOKE * 20)
	_rocket_buf.resize(MAX_ROCKETS * 12)


func _pool_mm(n: String, mesh: Mesh, shader: Shader, count: int, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if shader == SMOKE_SHADER:
		mat.set_shader_parameter("noise_tex", NOISE_TEX)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(mmi)
	return mm


# ------------------------------------------------------------------ frame update

func _process(delta: float) -> void:
	_ensure_pools()
	_time += delta
	_frame_streaks.clear()
	_frame_glows.clear()
	_step_projectiles(delta)
	_step_beams(delta)
	_step_rings(delta)
	_sparks.step(delta)
	_glows.step(delta)
	_smoke.step(delta)
	_upload()
	_process_legacy(delta)


func _upload() -> void:
	# Streaks: frame streaks first, then free sparks.
	var i := 0
	var b := _streak_buf
	for e: Array in _frame_streaks:
		if i >= MAX_STREAKS:
			break
		_put_streak(b, i, e[0], e[1], e[2], e[3], e[4])
		i += 1
	for k in _sparks.n:
		if i >= MAX_STREAKS:
			break
		var v := _sparks.vel[k]
		var sp := v.length()
		var dir := v / sp if sp > 0.001 else Vector3.DOWN
		var f := 1.0 - _sparks.age[k] / _sparks.life[k]
		var c := _sparks.col[k]
		c.a *= f
		var w := lerpf(_sparks.size_end[k], _sparks.size[k], f)
		_put_streak(b, i, _sparks.pos[k], dir, maxf(sp * _sparks.extra[k], w * 1.5), w, c)
		i += 1
	_streak_mm.buffer = b
	_streak_mm.visible_instance_count = i
	# Glows: frame glows, then timed ones (they swell and fade).
	i = 0
	var g := _glow_buf
	for e: Array in _frame_glows:
		if i >= MAX_GLOWS:
			break
		_put_sprite(g, i, e[0], e[1], e[2], e[3], e[4], e[5])
		i += 1
	for k in _glows.n:
		if i >= MAX_GLOWS:
			break
		var u := _glows.age[k] / _glows.life[k]
		var e2 := 1.0 - pow(1.0 - u, 3.0)
		var c := _glows.col[k]
		c.a *= (1.0 - u) * (1.0 - u)
		_put_sprite(g, i, _glows.pos[k], lerpf(_glows.size[k], _glows.size_end[k], e2), c, _glows.extra[k], _glows.drag[k], 1.0 - u)
		i += 1
	_glow_mm.buffer = g
	_glow_mm.visible_instance_count = i
	# Smoke.
	i = 0
	var sm := _smoke_buf
	for k in _smoke.n:
		var u := _smoke.age[k] / _smoke.life[k]
		var c := _smoke.col[k]
		c.a *= smoothstep(0.0, 0.12, u) * (1.0 - u)
		var e3 := 1.0 - pow(1.0 - u, 2.0)
		_put_sprite(sm, i, _smoke.pos[k], lerpf(_smoke.size[k], _smoke.size_end[k], e3), c, _smoke.extra[k], _smoke.extra[k] * 3.0 + u * 1.2, 0.0)
		i += 1
	_smoke_mm.buffer = sm
	_smoke_mm.visible_instance_count = i


static func _put_streak(b: PackedFloat32Array, i: int, head: Vector3, dir: Vector3, len: float, w: float, c: Color) -> void:
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized() * w
	var z := -dir * len
	var y := dir.cross(side).normalized() * w
	var o := head - dir * len * 0.5
	var k := i * 16
	b[k] = side.x
	b[k + 1] = y.x
	b[k + 2] = z.x
	b[k + 3] = o.x
	b[k + 4] = side.y
	b[k + 5] = y.y
	b[k + 6] = z.y
	b[k + 7] = o.y
	b[k + 8] = side.z
	b[k + 9] = y.z
	b[k + 10] = z.z
	b[k + 11] = o.z
	b[k + 12] = c.r
	b[k + 13] = c.g
	b[k + 14] = c.b
	b[k + 15] = c.a


static func _put_sprite(b: PackedFloat32Array, i: int, p: Vector3, s: float, c: Color, x: float, y: float, z: float) -> void:
	var k := i * 20
	b[k] = s
	b[k + 1] = 0.0
	b[k + 2] = 0.0
	b[k + 3] = p.x
	b[k + 4] = 0.0
	b[k + 5] = s
	b[k + 6] = 0.0
	b[k + 7] = p.y
	b[k + 8] = 0.0
	b[k + 9] = 0.0
	b[k + 10] = s
	b[k + 11] = p.z
	b[k + 12] = c.r
	b[k + 13] = c.g
	b[k + 14] = c.b
	b[k + 15] = c.a
	b[k + 16] = x
	b[k + 17] = y
	b[k + 18] = z
	b[k + 19] = 0.0


# ------------------------------------------------------------------ projectiles

## Fires a projectile from `from` to `to` that arrives after `time` seconds, then plays its
## impact and calls `on_hit` (may be an empty Callable). Kinds: "bolt" (ballista), "plasma",
## "rocket" (arcs, smoke trail), "drone", "volley" (crossbow/blaster: a spread of thin
## streaks), "turret" (enemy, orange).
func projectile(from: Vector3, to: Vector3, kind: String, time: float, on_hit: Callable) -> void:
	_ensure_pools()
	time = maxf(time, 0.05)
	if kind == "volley":
		var n := 6 if quality_high else 4
		for i in n:
			var off := Vector3(randf_range(-0.45, 0.45), randf_range(-0.05, 0.1), randf_range(-0.3, 0.3))
			var hit_off := Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.35), randf_range(-0.4, 0.4))
			_projectiles.append({"kind": kind, "from": from + off, "to": to + hit_off, "t": -randf_range(0.0, 0.09) * float(i > 0),
				"time": time * randf_range(0.9, 1.1), "on_hit": on_hit if i == 0 else Callable(), "seed": randf()})
		return
	_projectiles.append({"kind": kind, "from": from, "to": to, "t": 0.0, "time": time, "on_hit": on_hit, "seed": randf(), "puff": 0.0})


func _step_projectiles(delta: float) -> void:
	var rockets := 0
	var i := 0
	while i < _projectiles.size():
		var p: Dictionary = _projectiles[i]
		p["t"] = float(p["t"]) + delta
		var t := float(p["t"])
		if t < 0.0:
			i += 1
			continue
		var kind := str(p["kind"])
		var look: Dictionary = KINDS.get(kind, KINDS["bolt"])
		var u := clampf(t / float(p["time"]), 0.0, 1.0)
		var from: Vector3 = p["from"]
		var to: Vector3 = p["to"]
		var arc := from.distance_to(to) * float(look["arc"]) + (0.5 if kind == "rocket" else 0.0)
		var pos := from.lerp(to, u) + Vector3.UP * arc * 4.0 * u * (1.0 - u)
		var vel := (to - from) + Vector3.UP * arc * 4.0 * (1.0 - 2.0 * u)
		var dir := vel.normalized() if vel.length_squared() > 1e-6 else Vector3.FORWARD
		if u >= 1.0:
			impact(to, kind)
			var cb: Callable = p["on_hit"]
			if cb.is_valid():
				cb.call()
			_projectiles.remove_at(i)
			continue
		var c: Color = look["color"]
		var grow := smoothstep(0.0, 0.12, u)
		_frame_streaks.append([pos, dir, float(look["len"]) * (0.3 + 0.7 * grow), float(look["width"]), c])
		var gs := float(look["glow"])
		match kind:
			"plasma":
				var pulse := 1.0 + 0.12 * sin(_time * 40.0 + float(p["seed"]) * 9.0)
				_frame_glows.append([pos, gs * pulse, c, 0.35, _time * 6.0, 1.0])
				_frame_glows.append([pos, gs * 0.45, look["head"], 0.0, 0.0, 1.0])
				if randf() < 0.6:
					_sparks.add(pos, -dir * randf_range(1.0, 3.0) + _rand_dir() * 1.2, c, 0.25, 0.05, 0.01, 0.0, 2.0, 0.05)
			"rocket":
				if rockets < MAX_ROCKETS:
					_put_rocket(rockets, pos, dir, float(p["seed"]) * TAU + t * 14.0)
					rockets += 1
				var tail := pos - dir * 0.24
				# The motor lights up once the rocket has cleared the army it flies over (a full
				# glow at launch read as an explosion inside our own blob).
				var lit := 0.35 + 0.65 * smoothstep(0.05, 0.3, u)
				_frame_glows.append([tail, gs * lit * (0.75 + 0.25 * randf()), Color(1.0, 0.6, 0.22), 0.6, randf() * TAU, 1.0])
				p["puff"] = float(p["puff"]) + delta
				var every := 0.018 if quality_high else 0.035
				while float(p["puff"]) > every:
					p["puff"] = float(p["puff"]) - every
					var sc := randf_range(0.18, 0.28)
					_smoke.add(tail + _rand_dir() * 0.04, -dir * 0.6 + Vector3(0, 0.25, 0) + _rand_dir() * 0.25, Color(0.78, 0.76, 0.86, 0.75 * lit),
						randf_range(0.45, 0.7), sc, sc * 2.4, 0.3, 1.5, randf())
				if randf() < 0.5:
					_sparks.add(tail, -dir * randf_range(2.0, 4.0) + _rand_dir() * 1.5, Color(1.0, 0.7, 0.3), 0.18, 0.04, 0.01, 0.0, 3.0, 0.04)
			"volley":
				pass
			_:
				if gs > 0.0:
					_frame_glows.append([pos, gs, c, 0.25, _time * 4.0, 0.8])
		i += 1
	_rocket_mm.visible_instance_count = rockets
	if rockets > 0:
		_rocket_mm.buffer = _rocket_buf


func _put_rocket(i: int, pos: Vector3, dir: Vector3, spin: float) -> void:
	var b := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.BACK, spin)
	var k := i * 12
	var r := _rocket_buf
	r[k] = b.x.x
	r[k + 1] = b.y.x
	r[k + 2] = b.z.x
	r[k + 3] = pos.x
	r[k + 4] = b.x.y
	r[k + 5] = b.y.y
	r[k + 6] = b.z.y
	r[k + 7] = pos.y
	r[k + 8] = b.x.z
	r[k + 9] = b.y.z
	r[k + 10] = b.z.z
	r[k + 11] = pos.z


## The hit of a projectile of `kind` at `pos` (also usable on its own).
func impact(pos: Vector3, kind: String) -> void:
	_ensure_pools()
	var look: Dictionary = KINDS.get(kind, KINDS["bolt"])
	var c: Color = look["color"]
	match kind:
		"rocket":
			explosion(pos, 1.3)
		"plasma":
			_glow(pos, 0.5, 1.9, c, 0.3, 1.0)
			_glow(pos, 0.3, 0.8, Color(0.8, 0.95, 1.0), 0.0, 0.25)
			shockwave(Vector3(pos.x, 0.0, pos.z), c, 1.2)
			_spark_burst(pos, c, 16, 5.0, 0.06, 0.35)
		"bolt":
			_glow(pos, 0.3, 1.1, c, 0.8, 0.2)
			_spark_burst(pos, Color(1.0, 0.85, 0.5), 12, 6.0, 0.05, 0.3)
		"drone":
			_glow(pos, 0.15, 0.55, c, 0.4, 0.15)
			_spark_burst(pos, c, 5, 4.0, 0.035, 0.22)
		"volley":
			_glow(pos, 0.1, 0.35, c, 0.0, 0.12)
			_spark_burst(pos, c, 3, 3.5, 0.03, 0.2)
		"turret":
			_glow(pos, 0.25, 0.8, c, 0.6, 0.16)
			_spark_burst(pos, c, 8, 4.5, 0.045, 0.3)
		_:
			_glow(pos, 0.25, 0.8, c, 0.3, 0.16)
			_spark_burst(pos, c, 6, 4.0, 0.04, 0.25)


# ------------------------------------------------------------------ beams

## A persistent laser beam identified by `id`: call every frame with fresh ends while it is
## on, and with `on` false to fade it out. A beam not refreshed for 0.25 s fades by itself.
func beam(id: int, from: Vector3, to: Vector3, color: Color, on: bool) -> void:
	_ensure_pools()
	var b: Dictionary = _beams.get(id, {})
	if b.is_empty():
		if not on:
			return
		var mi := MeshInstance3D.new()
		mi.name = "Beam%d" % id
		mi.mesh = _streak_mesh()
		var m := ShaderMaterial.new()
		m.shader = BEAM_SHADER
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
		add_child(mi)
		b = {"node": mi, "mat": m, "k": 0.0, "spark": 0.0}
		_beams[id] = b
	b["from"] = from
	b["to"] = to
	b["color"] = color
	b["on"] = on
	b["seen"] = _time


func _step_beams(delta: float) -> void:
	for id: int in _beams.keys():
		var b: Dictionary = _beams[id]
		var on: bool = b["on"] and _time - float(b["seen"]) < 0.25
		var k := move_toward(float(b["k"]), 1.0 if on else 0.0, delta * (9.0 if on else 6.0))
		b["k"] = k
		var mi: MeshInstance3D = b["node"]
		mi.visible = k > 0.002
		if not mi.visible:
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = b["to"]
		var c: Color = b["color"]
		var v := to - from
		var len := maxf(v.length(), 0.01)
		var dir := v / len
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 1e-4:
			side = dir.cross(Vector3.RIGHT)
		var w := 0.26 * (0.6 + 0.4 * k)
		side = side.normalized() * w
		mi.transform = Transform3D(Basis(side, dir.cross(side).normalized(), -v), (from + to) * 0.5)
		var m: ShaderMaterial = b["mat"]
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("intensity", k)
		m.set_shader_parameter("beam_length", len)
		var flick := 0.85 + 0.15 * sin(_time * 50.0)
		_frame_glows.append([from, 0.5 * k * flick, c, 0.7, _time * 3.0, 1.0])
		_frame_glows.append([to, 0.85 * k * flick, c, 0.5, -_time * 2.0, 1.0])
		b["spark"] = float(b["spark"]) + delta * k
		var every := 0.025 if quality_high else 0.05
		while float(b["spark"]) > every:
			b["spark"] = float(b["spark"]) - every
			_sparks.add(to, (-dir + _rand_dir() * 1.1 + Vector3.UP * 0.6) * randf_range(2.0, 4.5), c.lerp(Color.WHITE, 0.3), randf_range(0.2, 0.35), 0.04, 0.01, -6.0, 1.5, 0.05)


# ------------------------------------------------------------------ muzzle, shockwave, glows

## Muzzle flash at `pos`: a star flare with a hot core and a few sparks. `dir` (optional)
## throws the sparks forward.
func muzzle(pos: Vector3, color: Color, dir := Vector3.ZERO) -> void:
	_ensure_pools()
	_glow(pos, 0.35, 0.75, color, 1.0, 0.1, randf() * TAU)
	_glow(pos, 0.2, 0.3, Color(1, 1, 1), 0.0, 0.07)
	for i in (5 if quality_high else 3):
		var v := (dir.normalized() * randf_range(2.5, 5.0) if dir != Vector3.ZERO else Vector3.ZERO) + _rand_dir() * 1.6
		_sparks.add(pos, v, color.lerp(Color.WHITE, 0.4), randf_range(0.12, 0.2), 0.035, 0.01, -3.0, 2.0, 0.04)


## Expanding ground ring at `pos` (on the road) with a flash and a ring of dust sparks.
func shockwave(pos: Vector3, color: Color, radius: float) -> void:
	_ensure_pools()
	var r := _take_ring()
	var mi: MeshInstance3D = r["node"]
	mi.position = Vector3(pos.x, pos.y + 0.05, pos.z)
	mi.scale = Vector3.ONE * radius * 2.0
	(r["mat"] as ShaderMaterial).set_shader_parameter("color", color)
	r["t"] = 0.0
	r["life"] = 0.42 + radius * 0.05
	r["active"] = true
	mi.visible = true
	_glow(pos + Vector3(0, 0.3, 0), radius * 0.5, radius * 1.4, color, 0.25, 0.25)
	var n := int(clampf(radius * 10.0, 8.0, 28.0)) if quality_high else 8
	for i in n:
		var a := TAU * i / n + randf() * 0.3
		var d := Vector3(cos(a), 0, sin(a))
		_sparks.add(pos + d * 0.15 + Vector3(0, 0.08, 0), d * radius * randf_range(3.5, 5.0) + Vector3.UP * randf_range(0.3, 1.5), color.lerp(Color.WHITE, 0.25),
			randf_range(0.25, 0.4), 0.05, 0.015, -4.0, 3.0, 0.035)


func _take_ring() -> Dictionary:
	for r: Dictionary in _ring_pool:
		if not r["active"]:
			return r
	if _ring_pool.size() >= MAX_RINGS:
		return _ring_pool[0]
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.quad(Vector2(1, 1))
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var r2 := {"node": mi, "mat": m, "t": 0.0, "life": 0.5, "active": false}
	_ring_pool.append(r2)
	return r2


func _step_rings(delta: float) -> void:
	for r: Dictionary in _ring_pool:
		if not r["active"]:
			continue
		r["t"] = float(r["t"]) + delta
		var p := float(r["t"]) / float(r["life"])
		(r["mat"] as ShaderMaterial).set_shader_parameter("progress", p)
		if p >= 1.0:
			r["active"] = false
			(r["node"] as Node3D).visible = false


## A timed glow sprite growing from `s0` to `s1` and fading over `life`.
func _glow(pos: Vector3, s0: float, s1: float, color: Color, flare: float, life: float, rot := 0.0) -> void:
	_glows.add(pos, Vector3.ZERO, color, life, s0, s1, 0.0, rot, flare)


func _spark_burst(pos: Vector3, color: Color, n: int, speed: float, width: float, life: float) -> void:
	if not quality_high:
		n = maxi(2, n / 2)
	for i in n:
		_sparks.add(pos, (_rand_dir() + Vector3.UP * 0.35) * speed * randf_range(0.4, 1.0), color, life * randf_range(0.6, 1.2), width, width * 0.3, -7.0, 2.5, 0.045)


static func _rand_dir() -> Vector3:
	var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length_squared() > 1e-4 else Vector3.UP


## A bright flash: a glow sprite swelling to `radius` (kept from the first version's API).
func flash(pos: Vector3, color: Color, radius := 0.5, life := 0.25) -> void:
	_ensure_pools()
	_glow(pos, radius * 0.35, radius * 1.6, color, 0.2, life)
	_glow(pos, radius * 0.2, radius * 0.6, Color(1, 1, 1), 0.0, life * 0.6)


func hit_spark(pos: Vector3, color: Color) -> void:
	_ensure_pools()
	_glow(pos, 0.12, 0.45, color, 0.6, 0.12, randf() * TAU)
	_spark_burst(pos, color, 7, 4.0, 0.04, 0.28)


## Big fiery blast: flash, fireball, embers, smoke and a ground shockwave.
func explosion(pos: Vector3, radius: float) -> void:
	_ensure_pools()
	var fire := Color(1.0, 0.62, 0.25)
	_glow(pos + Vector3(0, 0.25, 0), radius * 0.4, radius * 1.8, fire, 0.4, 0.38, randf() * TAU)
	_glow(pos + Vector3(0, 0.25, 0), radius * 0.3, radius * 0.9, Color(1.0, 0.95, 0.8), 0.0, 0.2)
	shockwave(Vector3(pos.x, 0.0, pos.z), Color(1.0, 0.68, 0.3), radius * 1.2)
	_spark_burst(pos + Vector3(0, 0.2, 0), Color(1.0, 0.75, 0.35), 26, 7.0 * sqrt(radius), 0.06, 0.6)
	for i in (10 if quality_high else 5):
		var sc := randf_range(0.3, 0.5) * radius
		_smoke.add(pos + _rand_dir() * 0.25 * radius + Vector3(0, 0.3, 0), (_rand_dir() + Vector3.UP * 0.8) * randf_range(0.6, 1.6) * radius,
			Color(0.62, 0.56, 0.7, 0.55), randf_range(0.6, 0.95), sc, sc * 2.6, 0.5, 2.2, randf())
	for i in 4:
		var sc2 := randf_range(0.35, 0.55) * radius
		_smoke.add(pos + _rand_dir() * 0.2 * radius + Vector3(0, 0.35, 0), _rand_dir() * 0.8 * radius, Color(1.0, 0.6, 0.25, 0.9),
			randf_range(0.25, 0.4), sc2, sc2 * 2.0, 0.6, 3.0, randf())


## Opening a weapon crate: a burst of light in the weapon colour, a shockwave and shards.
func loot_burst(pos: Vector3, color: Color) -> void:
	_ensure_pools()
	_glow(pos + Vector3(0, 0.6, 0), 0.5, 2.6, color, 1.0, 0.45, randf() * TAU)
	_glow(pos + Vector3(0, 0.6, 0), 0.4, 1.2, Color(1, 1, 1), 0.0, 0.25)
	shockwave(pos, color, 2.2)
	_spark_burst(pos + Vector3(0, 0.6, 0), color.lerp(Color.WHITE, 0.3), 30, 7.0, 0.06, 0.7)
	_spark_burst(pos + Vector3(0, 0.6, 0), Color(0.6, 0.9, 1.0), 16, 5.0, 0.08, 0.6)


# ------------------------------------------------------------------ meshes

static var _streak_mesh_cache: ArrayMesh
static var _rocket_mesh_cache: ArrayMesh


## Unit quad along Z (x -0.5..0.5, z -0.5..0.5), UV.y = 0 at the head (-Z).
static func _streak_mesh() -> ArrayMesh:
	if _streak_mesh_cache:
		return _streak_mesh_cache
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_streak_mesh_cache = m
	return m


## Small white rocket with gold fins and a gold nose band, pointing -Z.
static func _rocket_mesh() -> ArrayMesh:
	if _rocket_mesh_cache:
		return _rocket_mesh_cache
	var r := Node3D.new()
	var white := Mats.solid(Color(0.95, 0.96, 1.0))
	var gold := Mats.solid(Color(1.0, 0.78, 0.32))
	var navy := Mats.solid(Color(0.16, 0.2, 0.34))
	Mats.part(r, Mats.cyl(0.055, 0.055, 0.32, 10, false), white, Vector3.ZERO, Vector3(90, 0, 0))
	Mats.part(r, Mats.cyl(0.0, 0.055, 0.14, 10, false), white, Vector3(0, 0, -0.23), Vector3(-90, 0, 0))
	Mats.part(r, Mats.cyl(0.058, 0.058, 0.035, 10, false), gold, Vector3(0, 0, -0.14), Vector3(90, 0, 0))
	Mats.part(r, Mats.cyl(0.045, 0.06, 0.05, 10, false), navy, Vector3(0, 0, 0.18), Vector3(90, 0, 0))
	for k in 4:
		Mats.part(r, Mats.box(Vector3(0.012, 0.09, 0.1)), gold, Vector3(0, 0, 0.12), Vector3(0, 0, 45 + 90 * k))
		var fin := r.get_child(r.get_child_count() - 1) as Node3D
		fin.position = fin.basis * Vector3(0, 0.07, 0) + Vector3(0, 0, 0.12)
	_rocket_mesh_cache = WeaponModels.merge(r)
	return _rocket_mesh_cache


# ------------------------------------------------------------------ first-version effects

## Nodes of the first version (rings, spikes, coins, lightning).
func _process_legacy(delta: float) -> void:
	for i in range(_lightning.size() - 1, -1, -1):
		var l: Dictionary = _lightning[i]
		l["t"] += delta
		var k: float = 1.0 - l["t"] / l["life"]
		var mi: MeshInstance3D = l["mesh"]
		if k <= 0.0:
			mi.queue_free()
			_lightning.remove_at(i)
		else:
			(mi.material_override as StandardMaterial3D).albedo_color.a = k
	for arr in [_rings, _flashes]:
		for i in range(arr.size() - 1, -1, -1):
			var r: Dictionary = arr[i]
			r["t"] += delta
			var k: float = clampf(r["t"] / r["life"], 0.0, 1.0)
			var n: Node3D = r["node"]
			var e := 1.0 - pow(1.0 - k, 3.0)
			n.scale = Vector3.ONE * lerpf(r["from"], r["to"], e)
			# GeometryInstance3D.transparency is ignored by gl_compatibility: fade the material.
			var m := (n as GeometryInstance3D).material_override as StandardMaterial3D
			m.albedo_color.a = float(r["alpha"]) * (1.0 - k)
			if k >= 1.0:
				n.queue_free()
				arr.remove_at(i)
	for i in range(_spikes.size() - 1, -1, -1):
		var sp: Dictionary = _spikes[i]
		sp["t"] += delta
		var k: float = sp["t"] / sp["life"]
		var n: Node3D = sp["node"]
		var up := smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.6, 1.0, k))
		var thin := 1.0 - 0.4 * smoothstep(0.6, 1.0, k)
		n.basis = (sp["rot"] as Basis) * Basis.from_scale(Vector3(thin, maxf(up, 0.01), thin))
		if k >= 1.0:
			n.queue_free()
			_spikes.remove_at(i)
	for i in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[i]
		c["t"] += delta
		var n: Node3D = c["node"]
		var v: Vector3 = c["vel"]
		v.y -= 9.0 * delta
		c["vel"] = v
		n.position += v * delta
		n.rotation.y += delta * 12.0
		if c["t"] > 0.7:
			n.scale = Vector3.ONE * maxf(0.0, 1.0 - (c["t"] - 0.7) / 0.2)
		if c["t"] > 0.9:
			n.queue_free()
			_coins.remove_at(i)


## Generic particle burst.
func burst(pos: Vector3, color: Color, amount := 16, speed := 2.5, size := 0.08, life := 0.6, gravity := -4.0, additive := true, spread := 180.0) -> void:
	if not quality_high:
		amount = maxi(4, amount / 2)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.mesh = Mats.quad(Vector2(size, size), false)
	p.material_override = Mats.particle(additive)
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)


func ring(pos: Vector3, color: Color, radius := 1.0, life := 0.45) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.torus(0.88, 1.0, 32, 3)
	mi.material_override = Mats.flat_color(Color(color.r, color.g, color.b, 0.9), true).duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3.ONE * 0.1
	add_child(mi)
	_rings.append({"node": mi, "t": 0.0, "life": life, "from": 0.1, "to": radius, "alpha": 0.9})


## Glowing crystal spikes bursting out of the ground at `points` (leaning away from
## `center`), then sinking back.
func crystal_spikes(points: Array[Vector3], center: Vector3, color: Color) -> void:
	var mat := Mats.glow(color, 0.55)
	for i in points.size():
		var p := points[i]
		var out := Vector3(p.x - center.x, 0.0, p.z - center.z)
		out = out.normalized() if out.length_squared() > 1e-6 else Vector3.FORWARD
		var tilt := Basis(Vector3.UP.cross(out).normalized(), 0.45)
		# A big spike with a smaller one beside it.
		for k in 2:
			var h := (1.0 + 0.12 * float((i * 7) % 4)) * (1.0 if k == 0 else 0.6)
			var mi := MeshInstance3D.new()
			mi.mesh = Mats.crystal(0.17 if k == 0 else 0.11, h)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var side := out.cross(Vector3.UP) * (0.0 if k == 0 else 0.18 * (1.0 if i % 2 == 0 else -1.0))
			mi.position = p + side + Vector3(0, 0.05, 0)
			var rot := tilt * Basis(Vector3.UP, float(i * 37 % 6)) * Basis(Vector3.RIGHT, 0.25 * k)
			mi.basis = rot * Basis.from_scale(Vector3(1.0, 0.01, 1.0))
			add_child(mi)
			_spikes.append({"node": mi, "rot": rot, "t": -0.04 * k, "life": 1.0})
		if i % 3 == 0:
			burst(p + Vector3(0, 0.1, 0), Color(0.5, 0.44, 0.38), 6, 2.2, 0.1, 0.5, -6.0, false)


func frost_nova(pos: Vector3, radius: float) -> void:
	flash(pos + Vector3(0, 0.1, 0), Color(0.5, 0.9, 1.0), radius * 0.6, 0.25)
	ring(pos, Color(0.6, 0.95, 1.0), radius, 0.4)
	burst(pos + Vector3(0, 0.15, 0), Color(0.75, 0.95, 1.0), 14, 2.0, 0.08, 0.6, -2.0)


func death(pos: Vector3, color: Color, size: float) -> void:
	burst(pos + Vector3(0, size * 0.6, 0), color, 18 + int(size * 20), 2.4 + size * 2.0, 0.09 + size * 0.15, 0.6, -5.0, false)
	burst(pos + Vector3(0, size * 0.6, 0), Color(1, 1, 1), 8, 1.8, 0.07, 0.35, -1.0)
	flash(pos + Vector3(0, size * 0.6, 0), color.lightened(0.2), size * 1.1, 0.16)


func coin_pop(pos: Vector3) -> void:
	var c := Models.coin()
	c.position = pos + Vector3(0, 0.3, 0)
	add_child(c)
	_coins.append({"node": c, "t": 0.0, "vel": Vector3(randf_range(-0.6, 0.6), 3.2, randf_range(-0.6, 0.6))})


func build_puff(pos: Vector3) -> void:
	ring(pos, Color(1.0, 0.95, 0.8), 0.8, 0.4)
	burst(pos + Vector3(0, 0.1, 0), Color(0.85, 0.8, 0.7), 14, 1.6, 0.18, 0.7, -1.0, false, 80.0)


func upgrade_fx(pos: Vector3, color: Color) -> void:
	ring(pos, color, 0.9, 0.5)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 24 if quality_high else 12
	p.lifetime = 0.9
	p.mesh = Mats.quad(Vector2(0.08, 0.08), false)
	p.material_override = Mats.particle(true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.45
	p.emission_ring_inner_radius = 0.35
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 5
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_color(0, color.lightened(0.4))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.position = pos + Vector3(0, 0.1, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3, false).timeout.connect(p.queue_free)


## Jagged lightning through the given points (with a spark at each unless `sparks` is off).
func lightning(points: Array[Vector3], color: Color, life := 0.18, width := 0.05, sparks := true) -> void:
	if points.size() < 2:
		return
	var im := ImmediateMesh.new()
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3(0, 10, 10)
	for pass_i in 2:
		var w := width * (2.2 if pass_i == 0 else 0.7)
		var col := Color(color.r, color.g, color.b, 0.35) if pass_i == 0 else Color(1, 1, 1, 1)
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var segs := maxi(3, int(a.distance_to(b) / 0.18))
			var prev := a
			for s in segs:
				var t := float(s + 1) / segs
				var nxt := a.lerp(b, t)
				if s < segs - 1:
					nxt += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.09
				_ribbon(im, prev, nxt, w, cam_pos, col)
				prev = nxt
		im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _lightning_mat().duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_lightning.append({"mesh": mi, "t": 0.0, "life": life})
	if sparks:
		for p in points:
			burst(p, color, 5, 1.4, 0.06, 0.25, -2.0)


func _ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, w: float, cam_pos: Vector3, col: Color) -> void:
	var dir := (b - a).normalized()
	var to_cam := (cam_pos - (a + b) * 0.5).normalized()
	var side := dir.cross(to_cam).normalized() * w
	var verts := [a - side, a + side, b + side, a - side, b + side, b - side]
	for v in verts:
		im.surface_set_color(col)
		im.surface_add_vertex(v)


var _lmat: StandardMaterial3D
func _lightning_mat() -> StandardMaterial3D:
	if _lmat:
		return _lmat
	_lmat = StandardMaterial3D.new()
	_lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lmat.vertex_color_use_as_albedo = true
	_lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lmat.albedo_color = Color(1.6, 1.6, 2.0)
	return _lmat
