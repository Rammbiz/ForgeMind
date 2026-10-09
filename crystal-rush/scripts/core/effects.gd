class_name Effects
extends Node3D
## Visual effects for the run: projectiles, beams, the gatling tracer stream, the railgun rail,
## telegraphs, squad status rings, muzzle flashes, shockwaves, sparks, smoke, flashes, rings,
## lightning and coins.
##
## The busy effects are pooled in four MultiMeshes (one draw call and one buffer upload per
## frame each): additive streaks (projectile trails, volley lines, tracer streams,
## velocity-stretched sparks), additive glow sprites (flashes, flares, projectile heads),
## alpha smoke puffs and lit rocket / shell bodies. Shockwave rings, beams, telegraphs and
## status rings are a few reused nodes. Everything else (burst(), ring(), lightning(),
## crystal_spikes()...) is kept from the first version.
##
## Colours follow the family accents (arsenal_design.md §2.1, WeaponModels.FAMILY_GLOW): the
## Kinetic bolt is copper with a white tracer, Plasma orbs and beams rose, Tech rockets and
## drone darts lime, Volt rails orchid. Enemy shots stay orange-red. Telegraph grammar (§2.8):
## friendly = hollow dashed ring in the family accent with four inward chevrons (lines: two
## dashed rails); enemy = filled red disc with a solid rim (lines: a solid red band).

const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const STREAK_SHADER := preload("res://shaders/fx_streak.gdshader")
const GLOW_SHADER := preload("res://shaders/fx_glow.gdshader")
const SMOKE_SHADER := preload("res://shaders/fx_smoke.gdshader")
const BEAM_SHADER := preload("res://shaders/fx_beam.gdshader")
const RING_SHADER := preload("res://shaders/fx_ring.gdshader")
const TELEGRAPH_SHADER := preload("res://shaders/telegraph_ring.gdshader")
const STATUS_SHADER := preload("res://shaders/status_ring.gdshader")
const MAX_STREAKS := 1400
const MAX_GLOWS := 320
const MAX_SMOKE := 360
const MAX_ROCKETS := 48
const MAX_RINGS := 10
## Friendly ground telegraphs alive at once (§2.8 budget; the oldest dims and is reused).
const MAX_TELEGRAPHS := 4
const MAX_ENEMY_TELEGRAPHS := 6
const ENEMY_RED := Color(1.0, 0.16, 0.1)
## Squad status colours (§2.1) and the int kind of status_ring.gdshader.
const STATUS_LOOK := {
	"stagger": {"color": Color(1.0, 0.8, 0.62), "kind": 0},
	"jolt": {"color": Color(1.0, 0.52, 1.0), "kind": 1},
	"chill": {"color": Color(0.78, 0.95, 1.0), "kind": 2},
	"burn": {"color": Color(1.0, 0.36, 0.42), "kind": 3},
	"mark": {"color": Color(0.45, 1.0, 0.18), "kind": 4},
	"seal": {"color": Color(0.56, 0.6, 1.0), "kind": 5},
}
## Projectile looks: colour of the trail, head glow size, trail length and width, arc height
## per unit of distance, head colour. Machine vfx kinds (ArsenalData.MACHINES[id].vfx.kind)
## map onto these through ALIAS.
const KINDS := {
	"bolt": {"color": Color(1.0, 0.8, 0.64), "glow": 0.9, "len": 2.3, "width": 0.24, "arc": 0.0, "head": Color(1.0, 1.0, 1.0)},
	"plasma": {"color": Color(1.0, 0.24, 0.6), "glow": 1.7, "len": 1.5, "width": 0.55, "arc": 0.0, "head": Color(1.0, 0.86, 0.95)},
	"rocket": {"color": Color(0.5, 1.0, 0.28), "glow": 0.95, "len": 1.2, "width": 0.24, "arc": 0.24, "head": Color(0.85, 1.0, 0.7)},
	"drone": {"color": Color(0.45, 1.0, 0.2), "glow": 0.6, "len": 0.8, "width": 0.1, "arc": 0.0, "head": Color(0.85, 1.0, 0.75)},
	"shell": {"color": Color(1.0, 0.82, 0.66), "glow": 0.7, "len": 0.7, "width": 0.3, "arc": 0.32, "head": Color(1.0, 0.95, 0.85)},
	"tracer": {"color": Color(1.0, 0.82, 0.62), "glow": 0.25, "len": 0.9, "width": 0.07, "arc": 0.0, "head": Color(1.0, 1.0, 0.9)},
	"volley": {"color": Color(1.0, 0.9, 0.62), "glow": 0.0, "len": 1.25, "width": 0.11, "arc": 0.07, "head": Color(1.0, 1.0, 1.0)},
	"turret": {"color": Color(1.0, 0.42, 0.15), "glow": 0.85, "len": 1.6, "width": 0.22, "arc": 0.0, "head": Color(1.0, 0.6, 0.3)},
	"arcane": {"color": Color(0.62, 0.3, 1.0), "glow": 1.05, "len": 1.3, "width": 0.3, "arc": 0.12, "head": Color(0.9, 0.75, 1.0)},
}
## The Seer's violet (orbs, rift).
const ARCANE := Color(0.66, 0.32, 1.0)
const RIFT_SHADER := preload("res://shaders/fx_rift.gdshader")
## Machine vfx kinds (design §2.8 table) -> projectile looks above.
const ALIAS := {"orb": "plasma", "missile_trail": "rocket", "tracer_dot": "drone", "shell_arc": "shell", "tracer_stream": "tracer"}
## Gate labels v2 (Models.gate_labels_v2, dev only): an additive ult layer over a gate panel draws at alpha <= this
## (heroes design §10.2 rule 3; see _gate_hold).
const GATE_CAP := 0.35

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
var _streams := {}                   # id -> {from, to, color, on, seen, k, phase, hit}
var _telegraphs: Array[Dictionary] = []  # {node, mat, t, life, enemy, mode}
var _status := {}                    # id -> {node, mat, seen, k, kind}
var _rail_id := -1000000
var _time := 0.0
var _rifts: Array[Dictionary] = []     # {node, mats, k, t, closing}
## Gate labels v2 (Models.gate_labels_v2, dev only): the gate panels on screen this frame (Rect2 px) while an ult
## runs, and whether that holds the ult layers back (see _gate_hold).
var _panels: Array[Rect2] = []
var _panels_frame := -1
var _hold := false


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
	_step_streams(delta)
	_step_rings(delta)
	_step_telegraphs(delta)
	_step_status(delta)
	_step_rifts(delta)
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
	if Models.gate_labels_v2 and _gate_hold():
		_hold_back(b, i, 16)
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
	if Models.gate_labels_v2 and _gate_hold():
		_hold_back(g, i, 20)
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


# ------------------------------------------------------------------ gate labels v2: ult layers held back over gates

## Gate labels v2 (Models.gate_labels_v2, dev only; owner decision 10.10 "hold the ult flashes back over the gates"):
## while the run's ult clock runs, every additive layer whose screen footprint touches a gate panel draws at alpha
## <= GATE_CAP (heroes design §10.2 rule 3): the pooled streaks and glow sprites each frame (sparks, flashes,
## flares, projectile trails), and lightning, shockwave rings, rings and particle bursts when they are made; the
## Seer's rift eases down to it while a panel stands over it. The gate labels draw above all of it (Models, §10.2
## rule 2). Under v1 none of this runs. Returns whether this frame holds anything back (panels cached per frame).
func _gate_hold() -> bool:
	var f := Engine.get_process_frames()
	if f == _panels_frame:
		return _hold
	_panels_frame = f
	_panels.clear()
	_hold = false
	var run := get_parent()
	var clock: Variant = run.get("ult_clock") if run else null
	var cam := get_viewport().get_camera_3d()
	if not (clock is Object and bool((clock as Object).call("active"))) or cam == null:
		return false
	var vp := get_viewport().get_visible_rect()
	for n: Node in get_tree().get_nodes_in_group(Models.GATE_PANEL_GROUP):
		var g := n as Node3D
		if g == null or not g.is_visible_in_tree():
			continue
		var hw := float(g.get_meta("width", 2.0)) * 0.5
		var top := float(g.get_meta("field_h", Models.GATE_H)) + 0.3
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var seen := true
		for c: Vector3 in [Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0), Vector3(-hw, top, 0.0), Vector3(hw, top, 0.0)]:
			var p := g.global_transform * c
			if cam.is_position_behind(p):
				seen = false
				break
			var s := cam.unproject_position(p)
			lo = lo.min(s)
			hi = hi.max(s)
		var r := Rect2(lo, hi - lo).intersection(vp) if seen else Rect2()
		if r.has_area():
			_panels.append(r)
	_hold = not _panels.is_empty()
	return _hold


## Gate labels v2: true when a layer at `p` reaching `rad` metres around it touches a gate panel on screen (call
## after _gate_hold() returned true this frame).
func _over_gate(p: Vector3, rad: float) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	var depth := maxf((p - cam.global_position).dot(-cam.global_basis.z), 0.1)
	var px := rad * get_viewport().get_visible_rect().size.y / (2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5))
	for r: Rect2 in _panels:
		if r.grow(px).has_point(s):
			return true
	return false


## Gate labels v2: the alpha factor for a layer made now at `p` reaching `rad` m (GATE_CAP over a panel during an
## ult, else 1). v1 callers never ask.
func _gate_cap(p: Vector3, rad: float) -> float:
	return GATE_CAP if _gate_hold() and _over_gate(p, rad) else 1.0


## Gate labels v2: caps the first `n` instances of a streak (stride 16, length in the Z column) or glow sprite
## (stride 20, size first) buffer that touch a gate panel at alpha (intensity) <= GATE_CAP.
func _hold_back(b: PackedFloat32Array, n: int, stride: int) -> void:
	for i in n:
		var k := i * stride
		var rad := 0.5 * (Vector3(b[k + 2], b[k + 6], b[k + 10]).length() if stride == 16 else b[k])
		if _over_gate(Vector3(b[k + 3], b[k + 7], b[k + 11]), rad):
			b[k + 15] = minf(b[k + 15], 1.0) * GATE_CAP


# ------------------------------------------------------------------ projectiles

## Projectile kind for a machine id (its ArsenalData vfx kind; beams and rails are not
## projectiles: "beam", "rail_beam", "refract_flash" come back as they are).
static func shot_kind(machine_id: String) -> String:
	var m: Dictionary = ArsenalData.MACHINES.get(machine_id, {})
	return str((m.get("vfx", {}) as Dictionary).get("kind", "bolt"))


## Fires a projectile from `from` to `to` that arrives after `time` seconds, then plays its
## impact and calls `on_hit` (may be an empty Callable). Kinds: "bolt" (ballista: copper with
## a white tracer), "plasma" / "orb" (rose orb), "rocket" / "missile_trail" (lime motor, smoke
## trail, arcs), "drone" / "tracer_dot" (lime dart), "shell" / "shell_arc" (mortar: a finned
## shell on a high arc, use with telegraph_ring() at the landing point; impact =
## shell_impact()), "tracer" (one gatling bullet; prefer stream()), "volley" (crossbow /
## blaster: a spread of thin streaks), "turret" (enemy, orange).
func projectile(from: Vector3, to: Vector3, kind: String, time: float, on_hit: Callable) -> void:
	_ensure_pools()
	time = maxf(time, 0.05)
	kind = ALIAS.get(kind, kind)
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
		if kind == "arcane":
			# Homing orb: swings out to one side and curls onto the target.
			var side := (to - from).cross(Vector3.UP).normalized() * (1.0 if float(p["seed"]) > 0.5 else -1.0)
			var bend := from.distance_to(to) * 0.16
			pos += side * bend * sin(PI * u) * (1.0 - u * 0.35)
			vel += side * bend * PI * cos(PI * u)
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
				_frame_glows.append([pos, gs * pulse, c, 0.35, fposmod(_time * 6.0, TAU), 1.0])
				_frame_glows.append([pos, gs * 0.45, look["head"], 0.0, 0.0, 1.0])
				if randf() < 0.6:
					_sparks.add(pos, -dir * randf_range(1.0, 3.0) + _rand_dir() * 1.2, c, 0.25, 0.05, 0.01, 0.0, 2.0, 0.05)
			"shell":
				if rockets < MAX_ROCKETS:
					_put_rocket(rockets, pos, dir, float(p["seed"]) * TAU + t * 9.0)
					rockets += 1
				_frame_glows.append([pos - dir * 0.18, gs, c, 0.3, fposmod(_time * 5.0, TAU), 0.7])
				p["puff"] = float(p["puff"]) + delta
				var every2 := 0.03 if quality_high else 0.06
				while float(p["puff"]) > every2:
					p["puff"] = float(p["puff"]) - every2
					var sc2 := randf_range(0.12, 0.2)
					_smoke.add(pos - dir * 0.2, _rand_dir() * 0.15 + Vector3(0, 0.1, 0), Color(0.86, 0.84, 0.9, 0.55),
						randf_range(0.35, 0.55), sc2, sc2 * 2.2, 0.1, 1.5, randf())
			"rocket":
				if rockets < MAX_ROCKETS:
					_put_rocket(rockets, pos, dir, float(p["seed"]) * TAU + t * 14.0)
					rockets += 1
				var tail := pos - dir * 0.24
				# The motor lights up once the rocket has cleared the army it flies over (a full
				# glow at launch read as an explosion inside our own blob).
				var lit := 0.35 + 0.65 * smoothstep(0.05, 0.3, u)
				_frame_glows.append([tail, gs * lit * (0.75 + 0.25 * randf()), Color(0.7, 1.0, 0.45), 0.6, randf() * TAU, 1.0])
				p["puff"] = float(p["puff"]) + delta
				var every := 0.018 if quality_high else 0.035
				while float(p["puff"]) > every:
					p["puff"] = float(p["puff"]) - every
					var sc := randf_range(0.18, 0.28)
					_smoke.add(tail + _rand_dir() * 0.04, -dir * 0.6 + Vector3(0, 0.25, 0) + _rand_dir() * 0.25, Color(0.78, 0.76, 0.86, 0.75 * lit),
						randf_range(0.45, 0.7), sc, sc * 2.4, 0.3, 1.5, randf())
				if randf() < 0.5:
					_sparks.add(tail, -dir * randf_range(2.0, 4.0) + _rand_dir() * 1.5, Color(0.75, 1.0, 0.45), 0.18, 0.04, 0.01, 0.0, 3.0, 0.04)
			"arcane":
				var pulse2 := 1.0 + 0.15 * sin(fmod(_time, 100.0) * 30.0 + float(p["seed"]) * 9.0)
				_frame_glows.append([pos, gs * pulse2, c, 0.5, fposmod(_time * 5.0, TAU), 0.45])
				_frame_glows.append([pos, gs * 0.32, look["head"], 0.0, 0.0, 1.0])
				if randf() < 0.7:
					var tw := c.lerp(Color(1.0, 0.85, 0.5), randf() * 0.5)
					_sparks.add(pos + _rand_dir() * 0.08, -dir * randf_range(0.4, 1.4) + _rand_dir() * 0.6, tw, 0.35, 0.04, 0.01, 0.6, 2.5, 0.04)
			"volley", "tracer":
				pass
			"bolt":
				# Kinetic: a white-hot tracer core rides the copper streak.
				_frame_streaks.append([pos, dir, float(look["len"]) * 0.45 * grow, 0.07, Color(1.0, 1.0, 1.0, 0.9)])
				_frame_glows.append([pos, gs, c, 0.25, fposmod(_time * 4.0, TAU), 0.8])
			_:
				if gs > 0.0:
					_frame_glows.append([pos, gs, c, 0.25, fposmod(_time * 4.0, TAU), 0.8])
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
	kind = ALIAS.get(kind, kind)
	var look: Dictionary = KINDS.get(kind, KINDS["bolt"])
	var c: Color = look["color"]
	match kind:
		"rocket":
			tech_blast(pos, 1.0)
		"shell":
			shell_impact(Vector3(pos.x, 0.0, pos.z), 1.6, c)
		"tracer":
			_glow(pos, 0.08, 0.3, c, 0.5, 0.08)
			_sparks.add(pos, (_rand_dir() + Vector3.UP * 0.6) * randf_range(3.0, 6.0), Color(1.0, 0.85, 0.55), 0.22, 0.035, 0.01, -9.0, 1.5, 0.05)
		"plasma":
			_glow(pos, 0.5, 1.9, c, 0.3, 1.0)
			_glow(pos, 0.3, 0.8, Color(1.0, 0.85, 0.95), 0.0, 0.25)
			shockwave(Vector3(pos.x, 0.0, pos.z), c, 1.2)
			_spark_burst(pos, c, 16, 5.0, 0.06, 0.35)
		"bolt":
			_glow(pos, 0.3, 1.1, c, 0.8, 0.2)
			_glow(pos, 0.15, 0.45, Color(1, 1, 1), 0.0, 0.1)
			_spark_burst(pos, Color(1.0, 0.88, 0.72), 12, 6.0, 0.05, 0.3)
		"drone":
			_glow(pos, 0.15, 0.55, c, 0.4, 0.15)
			_spark_burst(pos, c, 5, 4.0, 0.035, 0.22)
		"volley":
			_glow(pos, 0.1, 0.35, c, 0.0, 0.12)
			_spark_burst(pos, c, 3, 3.5, 0.03, 0.2)
		"turret":
			_glow(pos, 0.25, 0.8, c, 0.6, 0.16)
			_spark_burst(pos, c, 8, 4.5, 0.045, 0.3)
		"arcane":
			_glow(pos, 0.3, 1.2, c * 0.8, 0.6, 0.28, randf() * TAU)
			_glow(pos, 0.12, 0.4, c.lerp(Color.WHITE, 0.45), 0.0, 0.14)
			_spark_burst(pos, c.lerp(Color.WHITE, 0.3), 10, 4.5, 0.05, 0.32)
			_spark_burst(pos, Color(1.0, 0.82, 0.45), 4, 3.0, 0.035, 0.4)
		_:
			_glow(pos, 0.25, 0.8, c, 0.3, 0.16)
			_spark_burst(pos, c, 6, 4.0, 0.04, 0.25)


# ------------------------------------------------------------------ beams

## A persistent laser beam identified by `id`: call every frame with fresh ends while it is
## on, and with `on` false to fade it out. A beam not refreshed for 0.25 s fades by itself.
## `ramp` 0..1 (the Laser's damage ramp) thickens and brightens it; `width` is the base width.
func beam(id: int, from: Vector3, to: Vector3, color: Color, on: bool, ramp := 0.0, width := 0.26) -> void:
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
	b["width"] = width * (1.0 + 0.6 * clampf(ramp, 0.0, 1.0))
	b["boost"] = 1.0 + 0.5 * clampf(ramp, 0.0, 1.0)
	b["life"] = 0.0


func _step_beams(delta: float) -> void:
	for id: int in _beams.keys():
		var b: Dictionary = _beams[id]
		var life := float(b.get("life", 0.0))
		var on: bool = b["on"] and _time - float(b["seen"]) < (life if life > 0.0 else 0.25)
		var k := move_toward(float(b["k"]), 1.0 if on else 0.0, delta * (9.0 if on else (1.0 / 0.12 if life > 0.0 else 6.0)))
		if life > 0.0 and on:
			k = 1.0
		b["k"] = k
		var mi: MeshInstance3D = b["node"]
		mi.visible = k > 0.002
		if not mi.visible:
			if life > 0.0:
				mi.queue_free()
				_beams.erase(id)
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
		var w := float(b.get("width", 0.26)) * (0.6 + 0.4 * k)
		side = side.normalized() * w
		mi.transform = Transform3D(Basis(side, dir.cross(side).normalized(), -v), (from + to) * 0.5)
		var m: ShaderMaterial = b["mat"]
		m.set_shader_parameter("color", c)
		var boost := float(b.get("boost", 1.0))
		m.set_shader_parameter("intensity", k * boost)
		m.set_shader_parameter("beam_length", len)
		var flick := 0.85 + 0.15 * sin(_time * 50.0)
		_frame_glows.append([from, 0.5 * k * flick * boost, c, 0.7, fposmod(_time * 3.0, TAU), 1.0])
		_frame_glows.append([to, 0.85 * k * flick * boost, c, 0.5, fposmod(-_time * 2.0, TAU), 1.0])
		if life > 0.0:
			continue
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
	if Models.gate_labels_v2:
		# Gate labels v2: an ult's ring over a gate panel at <= GATE_CAP (fx_ring's default energy is 2).
		(r["mat"] as ShaderMaterial).set_shader_parameter("energy", 2.0 * _gate_cap(pos, radius))
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


# ------------------------------------------------------------------ Meta-1 machine VFX

## Gatling tracer stream (§2.8: ONE stream, not 6 bullets): call every frame while firing
## with `on` true; `spin` 0..1 is the spin-up (rate and brightness). Tracers race from `from`
## to `to`, the muzzle flickers and ricochet sparks fly off the target. Fades when not
## refreshed for 0.2 s. Ascended Vulcan Drum: pass gold as `color`.
func stream(id: int, from: Vector3, to: Vector3, color: Color, on: bool, spin := 1.0) -> void:
	_ensure_pools()
	var s: Dictionary = _streams.get(id, {})
	if s.is_empty():
		if not on:
			return
		s = {"k": 0.0, "phase": randf(), "hit": 0.0}
		_streams[id] = s
	s["from"] = from
	s["to"] = to
	s["color"] = color
	s["on"] = on
	s["seen"] = _time
	s["spin"] = clampf(spin, 0.0, 1.0)


func _step_streams(delta: float) -> void:
	for id: int in _streams.keys():
		var s: Dictionary = _streams[id]
		var on: bool = s["on"] and _time - float(s["seen"]) < 0.2
		var k := move_toward(float(s["k"]), (0.5 + 0.5 * float(s["spin"])) if on else 0.0, delta * (6.0 if on else 8.0))
		s["k"] = k
		if k <= 0.001:
			_streams.erase(id)
			continue
		var from: Vector3 = s["from"]
		var to: Vector3 = s["to"]
		var c: Color = s["color"]
		var v := to - from
		var l := maxf(v.length(), 0.01)
		var dir := v / l
		var speed := 46.0
		s["phase"] = fposmod(float(s["phase"]) + delta * speed / l, 1.0)
		var n := int(clampf(l / 1.3, 3.0, 9.0))
		for i in n:
			var u := fposmod(float(s["phase"]) + float(i) / n, 1.0)
			var head := from + v * u
			var tl := minf(0.9, l * u)
			_frame_streaks.append([head, dir, tl, 0.075, Color(c.r, c.g, c.b, k)])
			_frame_streaks.append([head, dir, tl * 0.45, 0.03, Color(1, 1, 1, 0.8 * k)])
		var flick := 0.6 + 0.4 * absf(sin(_time * 61.0))
		_frame_glows.append([from, 0.32 * k * flick, c, 0.8, fposmod(_time * 17.0, TAU), 1.0])
		_frame_glows.append([to, 0.3 * k, c, 0.4, fposmod(_time * 11.0, TAU), 0.6])
		s["hit"] = float(s["hit"]) + delta * k
		var every := 0.045 if quality_high else 0.09
		while float(s["hit"]) > every:
			s["hit"] = float(s["hit"]) - every
			# Ricochet: a gold spark glancing off, sometimes a long one.
			var out := (-dir + _rand_dir() * 1.4 + Vector3.UP * 0.8).normalized()
			_sparks.add(to, out * randf_range(4.0, 8.0), Color(1.0, 0.86, 0.5), randf_range(0.15, 0.3), 0.04, 0.01, -10.0, 1.2, 0.06)


## Railgun charge glow at the muzzle (call every frame while charging, `k` 0..1): a growing
## orchid core with a crackle flare. The model's own rails glow via WeaponModels.set_charge().
func rail_charge(pos: Vector3, color: Color, k: float) -> void:
	_ensure_pools()
	k = clampf(k, 0.0, 1.0)
	var flick := 0.8 + 0.2 * sin(_time * 47.0)
	_frame_glows.append([pos, (0.15 + 0.5 * k) * flick, color, 0.9 * k, fposmod(_time * 9.0, TAU), 0.6 + 0.4 * k])
	if k > 0.5 and randf() < k * 0.6:
		_sparks.add(pos + _rand_dir() * 0.35, -_rand_dir() * 2.0, color.lerp(Color.WHITE, 0.4), 0.12, 0.03, 0.01, 0.0, 4.0, 0.06)


## The rail shot (§2.8 rail_beam: width 0.3, 0.25 s): an instant thick orchid beam with a
## white core from `from` to `to`, a muzzle blast, pierce rings along the line and a spray of
## sparks at the end. `hits` (optional) are the points it pierced (a ring at each).
func rail_fire(from: Vector3, to: Vector3, color: Color, hits: Array[Vector3] = []) -> void:
	_ensure_pools()
	_rail_id -= 1
	beam(_rail_id, from, to, color, true, 1.0, 0.34)
	(_beams[_rail_id] as Dictionary)["life"] = 0.25
	(_beams[_rail_id] as Dictionary)["boost"] = 2.2
	var dir := (to - from).normalized()
	_glow(from, 0.4, 1.4, color, 1.0, 0.22, randf() * TAU)
	_glow(from, 0.3, 0.6, Color(1, 1, 1), 0.0, 0.12)
	_spark_burst(from, color.lerp(Color.WHITE, 0.3), 14, 6.0, 0.05, 0.3)
	var l := from.distance_to(to)
	var pts := hits.duplicate()
	if pts.is_empty():
		var step := 3.5
		var d := step
		while d < l:
			pts.append(from + dir * d)
			d += step
	for p: Vector3 in pts:
		pierce_ring(p, dir, color)
	for i in (18 if quality_high else 8):
		_sparks.add(to, (dir + _rand_dir() * 0.9) * randf_range(4.0, 9.0), color.lerp(Color.WHITE, 0.4), randf_range(0.2, 0.4), 0.05, 0.01, -5.0, 1.5, 0.06)


## A ring flashing across a rail / pierce line at `pos` (facing along `dir`).
func pierce_ring(pos: Vector3, dir: Vector3, color: Color) -> void:
	_ensure_pools()
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	for k in 10:
		var a := TAU * k / 10.0
		var o := (side * cos(a) + up * sin(a))
		_sparks.add(pos + o * 0.12, o * randf_range(2.6, 3.4), color.lerp(Color.WHITE, 0.3), 0.2, 0.045, 0.015, 0.0, 3.0, 0.03)
	_glow(pos, 0.2, 0.7, color, 0.6, 0.18, randf() * TAU)


## Prism refraction flash (§2.8 refract_flash, 0.2 s): a white-rose flare at the prism and
## `split` short rays fanning out along `dir` (a shot crossing the prism; amp +20%).
func prism_flash(pos: Vector3, color: Color, dir := Vector3(0, 0, -1), split := 1) -> void:
	_ensure_pools()
	_glow(pos, 0.3, 1.1, color, 1.0, 0.2, randf() * TAU)
	_glow(pos, 0.25, 0.55, Color(1, 1, 1), 0.0, 0.14)
	var side := dir.cross(Vector3.UP).normalized()
	for i in split:
		var a := 0.0 if split <= 1 else lerpf(-0.35, 0.35, float(i) / (split - 1))
		var d := (dir + side * a).normalized()
		_sparks.add(pos + d * 0.3, d * 14.0, color.lerp(Color.WHITE, 0.25), 0.18, 0.08, 0.03, 0.0, 0.5, 0.06)
	for i in 6:
		var o := _rand_dir()
		_sparks.add(pos + o * 0.2, o * 2.5, Color(1.0, 0.85, 0.95), 0.22, 0.03, 0.01, 0.0, 3.0, 0.04)


## A beam bent by the Prism (§2.5: a beam that crosses it splits into 3 at 60%): `from` to the
## prism, then one thinner beam per target. Call every frame like beam(); ids `id` ..
## `id + targets.size()` are used. The prism itself flares while a beam passes.
func refract_beam(id: int, from: Vector3, prism_pos: Vector3, targets: Array[Vector3], color: Color, on: bool, ramp := 0.0) -> void:
	_ensure_pools()
	beam(id, from, prism_pos, color, on, ramp)
	for i in targets.size():
		beam(id + 1 + i, prism_pos, targets[i], color.lerp(Color.WHITE, 0.15), on, ramp, 0.16)
	if on:
		var flick := 0.9 + 0.1 * sin(_time * 31.0)
		_frame_glows.append([prism_pos, 0.7 * flick, color, 1.0, fposmod(_time * 2.0, TAU), 1.0])


## Mortar shell landing (§2.8 shell_arc impact): white flash, a copper dust shockwave of
## `radius`, flying debris, a grey smoke column and a quick ring of Stagger chevron sparks.
func shell_impact(pos: Vector3, radius: float, color := Color(1.0, 0.8, 0.62)) -> void:
	_ensure_pools()
	var p := Vector3(pos.x, 0.0, pos.z)
	_glow(p + Vector3(0, 0.35, 0), radius * 0.3, radius * 1.3, color, 0.5, 0.3, randf() * TAU)
	_glow(p + Vector3(0, 0.3, 0), radius * 0.25, radius * 0.7, Color(1, 1, 1), 0.0, 0.14)
	shockwave(p, color, radius)
	for i in (16 if quality_high else 8):
		var a := randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		_sparks.add(p + o * 0.2 + Vector3(0, 0.1, 0), (o * randf_range(1.5, 3.5) + Vector3.UP * randf_range(3.0, 6.5)), Color(0.62, 0.55, 0.62),
			randf_range(0.5, 0.8), 0.08, 0.04, -16.0, 0.5, 0.02)
	for i in (8 if quality_high else 4):
		var sc := randf_range(0.3, 0.5) * radius * 0.6
		_smoke.add(p + _rand_dir() * 0.3 * radius + Vector3(0, 0.25, 0), (_rand_dir() * 0.6 + Vector3.UP * 1.2) * radius * 0.6,
			Color(0.8, 0.78, 0.86, 0.6), randf_range(0.6, 1.0), sc, sc * 2.6, 0.4, 2.0, randf())


## Tech rocket blast: a compact lime-white burst instead of the enemy-orange fireball.
func tech_blast(pos: Vector3, radius: float) -> void:
	_ensure_pools()
	var lime := Color(0.55, 1.0, 0.3)
	_glow(pos + Vector3(0, 0.25, 0), radius * 0.4, radius * 1.6, lime, 0.5, 0.32, randf() * TAU)
	_glow(pos + Vector3(0, 0.25, 0), radius * 0.3, radius * 0.8, Color(1.0, 1.0, 0.95), 0.0, 0.18)
	shockwave(Vector3(pos.x, 0.0, pos.z), lime, radius * 1.1)
	_spark_burst(pos + Vector3(0, 0.2, 0), Color(0.8, 1.0, 0.6), 20, 6.5 * sqrt(radius), 0.055, 0.5)
	for i in (7 if quality_high else 3):
		var sc := randf_range(0.28, 0.45) * radius
		_smoke.add(pos + _rand_dir() * 0.25 * radius + Vector3(0, 0.3, 0), (_rand_dir() + Vector3.UP * 0.8) * randf_range(0.6, 1.4) * radius,
			Color(0.76, 0.8, 0.86, 0.5), randf_range(0.5, 0.85), sc, sc * 2.4, 0.5, 2.2, randf())


## Rank-up forge moment (§2.8, 0.5 s): gold sparks fountain, a clang ring and a flash. The
## caller pops the model scale and plays the clang + haptic CLICK 0.7.
func rank_up(pos: Vector3, color: Color) -> void:
	_ensure_pools()
	_glow(pos + Vector3(0, 0.6, 0), 0.4, 2.0, Color(1.0, 0.8, 0.35), 1.0, 0.4, randf() * TAU)
	_glow(pos + Vector3(0, 0.6, 0), 0.3, 0.9, Color(1, 1, 1), 0.0, 0.2)
	shockwave(pos, color, 1.4)
	for i in (30 if quality_high else 14):
		var a := randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		_sparks.add(pos + o * 0.3 + Vector3(0, 0.3, 0), o * randf_range(1.0, 3.0) + Vector3.UP * randf_range(4.0, 7.0), Color(1.0, 0.82, 0.4),
			randf_range(0.5, 0.8), 0.05, 0.015, -14.0, 0.6, 0.05)


## Cache burst (§5.6 Burst beat): shockwave in the rarity colour, shards and sparks; particle
## count by tier 0..4 (Common..Mythic: 40/70/120/200/250, halved on low quality).
func cache_burst(pos: Vector3, color: Color, tier: int) -> void:
	_ensure_pools()
	var counts: Array[int] = [40, 70, 120, 200, 250]
	var n: int = counts[clampi(tier, 0, 4)]
	if not quality_high:
		n /= 2
	_glow(pos, 0.6, 2.6 + tier * 0.5, color, 1.0, 0.5, randf() * TAU)
	_glow(pos, 0.5, 1.4, Color(1, 1, 1), 0.0, 0.25)
	shockwave(Vector3(pos.x, pos.y - 0.6, pos.z), color, 2.2 + tier * 0.4)
	for i in n:
		var d := (_rand_dir() + Vector3.UP * 0.5).normalized()
		var c := color.lerp(Color.WHITE, randf() * 0.5)
		_sparks.add(pos + d * 0.2, d * randf_range(3.0, 9.0), c, randf_range(0.4, 0.9), 0.06, 0.015, -6.0, 1.6, 0.05)


# ------------------------------------------------------------------ telegraphs

## Friendly PLACE telegraph (§2.8): a hollow dashed ring of `radius` in the family accent with
## four inward chevrons that close in as the `life` (s) runs out; then it fades. At most
## MAX_TELEGRAPHS friendly ones live at once (the oldest is reused).
func telegraph_ring(pos: Vector3, radius: float, color: Color, life := 0.8) -> void:
	_telegraph(0, Vector3(pos.x, pos.y + 0.04, pos.z), Vector2(radius * 2.0, radius * 2.0), 0.0, color, life, false)


## Friendly line telegraph (Railgun, §2.8): two dashed rails `width` apart from `from` along
## `dir` for `length` (on the road), chevrons racing forward; fades after `life`.
func telegraph_rails(from: Vector3, dir: Vector3, length: float, color: Color, life := 0.4, width := 0.9) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var c := Vector3(from.x, 0.05, from.z) + d * length * 0.5
	_telegraph(1, c, Vector2(width, length), atan2(-d.x, -d.z), color, life, false)


## Enemy telegraph (plan2 meteors, lava jets, boss markers): a filled red disc with a solid
## rim; the fill grows to the rim over `life`.
func telegraph_enemy(pos: Vector3, radius: float, life := 1.0) -> void:
	_telegraph(2, Vector3(pos.x, pos.y + 0.045, pos.z), Vector2(radius * 2.0, radius * 2.0), 0.0, ENEMY_RED, life, true)


## Enemy line telegraph: a solid red band.
func telegraph_enemy_band(from: Vector3, dir: Vector3, length: float, width: float, life := 1.0) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	_telegraph(3, Vector3(from.x, 0.05, from.z) + d * length * 0.5, Vector2(width, length), atan2(-d.x, -d.z), ENEMY_RED, life, true)


## Kept for the railgun gallery: rail_telegraph(id, ...) = telegraph_rails with a 0.4 s life.
func rail_telegraph(_id: int, from: Vector3, dir: Vector3, length: float, color: Color, on: bool) -> void:
	if on:
		telegraph_rails(from, dir, length, color, 0.4)


func _telegraph(mode: int, pos: Vector3, size: Vector2, yaw: float, color: Color, life: float, enemy: bool) -> void:
	_ensure_pools()
	var cap := MAX_ENEMY_TELEGRAPHS if enemy else MAX_TELEGRAPHS
	var mine: Array[Dictionary] = []
	var tg: Dictionary = {}
	for e: Dictionary in _telegraphs:
		if bool(e["enemy"]) == enemy:
			mine.append(e)
			if tg.is_empty() and not bool(e["active"]):
				tg = e
	if tg.is_empty():
		var live := 0
		for e: Dictionary in mine:
			if bool(e["active"]):
				live += 1
		if mine.size() < cap:
			var mi := MeshInstance3D.new()
			mi.name = "Telegraph"
			mi.mesh = Mats.quad(Vector2(1, 1))
			var m := ShaderMaterial.new()
			m.shader = TELEGRAPH_SHADER
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Enemy telegraphs draw over friendly ones (threats win the priority ladder).
			m.render_priority = 2 if enemy else 1
			add_child(mi)
			tg = {"node": mi, "mat": m, "t": 0.0, "life": 1.0, "enemy": enemy, "active": false, "born": 0.0}
			_telegraphs.append(tg)
		else:
			# Budget: reuse the oldest one.
			tg = mine[0]
			for e: Dictionary in mine:
				if float(e["born"]) < float(tg["born"]):
					tg = e
	var node: MeshInstance3D = tg["node"]
	node.position = pos
	node.rotation = Vector3(0, yaw, 0)
	node.scale = Vector3(size.x, 1.0, size.y)
	node.visible = true
	var mat: ShaderMaterial = tg["mat"]
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("alpha", 1.0)
	tg["t"] = 0.0
	tg["life"] = maxf(life, 0.05)
	tg["active"] = true
	tg["born"] = _time


func _step_telegraphs(delta: float) -> void:
	var friendly_live := 0
	for e: Dictionary in _telegraphs:
		if bool(e["active"]) and not bool(e["enemy"]):
			friendly_live += 1
	for e: Dictionary in _telegraphs:
		if not bool(e["active"]):
			continue
		e["t"] = float(e["t"]) + delta
		var life := float(e["life"])
		var p := float(e["t"]) / life
		var mat: ShaderMaterial = e["mat"]
		mat.set_shader_parameter("progress", clampf(p, 0.0, 1.0))
		# Fade in 0.08 s, hold, fade out 0.15 s after the life ends.
		var a := smoothstep(0.0, 0.08, float(e["t"])) * (1.0 - clampf((float(e["t"]) - life) / 0.15, 0.0, 1.0))
		mat.set_shader_parameter("alpha", a)
		if float(e["t"]) > life + 0.15:
			e["active"] = false
			(e["node"] as Node3D).visible = false


# ------------------------------------------------------------------ squad statuses

## A squad's status ring (§2.1, §2.8 priority 6): call every frame per squad `id` while the
## status is on; fades when not refreshed for 0.2 s. `status` = stagger | jolt | chill | burn
## | mark | seal; `stacks` lights the stack segments (Jolt and Chill 1..3; Chill at max =
## frozen disc). Burn adds rising embers, Jolt a crackle. The overlay on the units themselves
## is CrowdView.set_overlay (the colour is STATUS_LOOK[status].color).
func status(id: int, center: Vector3, radius: float, st: String, stacks := 1, on := true) -> void:
	_ensure_pools()
	var key := "%d|%s" % [id, st]
	var e: Dictionary = _status.get(key, {})
	if e.is_empty():
		if not on:
			return
		var mi := MeshInstance3D.new()
		mi.name = "Status"
		mi.mesh = Mats.quad(Vector2(1, 1))
		var m := ShaderMaterial.new()
		m.shader = STATUS_SHADER
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var look: Dictionary = STATUS_LOOK.get(st, STATUS_LOOK["mark"])
		m.set_shader_parameter("kind", int(look["kind"]))
		m.set_shader_parameter("color", look["color"])
		e = {"node": mi, "mat": m, "k": 0.0, "st": st, "ember": 0.0}
		_status[key] = e
	e["pos"] = center
	e["r"] = radius
	e["stacks"] = stacks
	e["on"] = on
	e["seen"] = _time


func _step_status(delta: float) -> void:
	for key: String in _status.keys():
		var e: Dictionary = _status[key]
		var on: bool = e["on"] and _time - float(e["seen"]) < 0.2
		var k := move_toward(float(e["k"]), 1.0 if on else 0.0, delta * (8.0 if on else 5.0))
		e["k"] = k
		var mi: MeshInstance3D = e["node"]
		if k <= 0.001 and not on:
			mi.queue_free()
			_status.erase(key)
			continue
		var pos: Vector3 = e["pos"]
		var r := float(e["r"])
		mi.position = Vector3(pos.x, pos.y + 0.06, pos.z)
		# The ring sits just outside the squad's edge so the units never hide it.
		mi.scale = Vector3.ONE * r * 2.6 * 1.14
		var m: ShaderMaterial = e["mat"]
		m.set_shader_parameter("alpha", k)
		m.set_shader_parameter("stacks", float(e["stacks"]))
		var st := str(e["st"])
		var c: Color = (STATUS_LOOK.get(st, STATUS_LOOK["mark"]) as Dictionary)["color"]
		e["ember"] = float(e["ember"]) + delta * k
		var every := 0.06 if quality_high else 0.12
		while float(e["ember"]) > every:
			e["ember"] = float(e["ember"]) - every
			var a := randf() * TAU
			var o := Vector3(cos(a), 0, sin(a)) * r * randf_range(0.5, 1.1)
			match st:
				"burn":
					_sparks.add(pos + o + Vector3(0, 0.15, 0), Vector3(0, randf_range(1.2, 2.4), 0) + _rand_dir() * 0.3, c.lerp(Color(1.0, 0.75, 0.4), randf() * 0.6), 0.45, 0.05, 0.01, 1.0, 0.5, 0.05)
				"jolt":
					if randf() < 0.35:
						_sparks.add(pos + o + Vector3(0, 0.3, 0), _rand_dir() * 3.0, c.lerp(Color.WHITE, 0.4), 0.1, 0.03, 0.01, 0.0, 4.0, 0.08)
				"chill":
					if randf() < 0.3:
						_sparks.add(pos + o + Vector3(0, 0.5, 0), Vector3(0, -0.4, 0) + _rand_dir() * 0.2, Color(0.9, 0.97, 1.0), 0.6, 0.035, 0.03, 0.0, 1.0, 0.01)
				_:
					pass


## The moment a status lands on a squad (one shot): a flare and a burst in its colour.
func status_pop(pos: Vector3, st: String) -> void:
	_ensure_pools()
	var c: Color = (STATUS_LOOK.get(st, STATUS_LOOK["mark"]) as Dictionary)["color"]
	_glow(pos, 0.2, 0.9, c, 0.8, 0.25, randf() * TAU)
	_spark_burst(pos, c.lerp(Color.WHITE, 0.3), 10, 3.5, 0.045, 0.3)


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
		elif l.has("cap"):
			(mi.material_override as StandardMaterial3D).albedo_color.a = k * float(l["cap"])
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
	# Gate labels v2: an additive burst over a gate panel during an ult starts at <= GATE_CAP.
	var a0 := _gate_cap(pos, speed * life * 0.5) if additive and Models.gate_labels_v2 else 1.0
	g.set_color(0, Color(color.r, color.g, color.b, a0))
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
	var a := 0.9
	if Models.gate_labels_v2:
		# Gate labels v2: an ult's ring over a gate panel at <= GATE_CAP.
		a *= _gate_cap(pos, radius)
		(mi.material_override as StandardMaterial3D).albedo_color.a = a
	_rings.append({"node": mi, "t": 0.0, "life": life, "from": 0.1, "to": radius, "alpha": a})


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
	var e := {"mesh": mi, "t": 0.0, "life": life}
	if Models.gate_labels_v2 and _bolt_over_gate(points, width):
		# Gate labels v2: a bolt over a gate panel during an ult at alpha <= GATE_CAP, without the 1.6x overdrive.
		e["cap"] = GATE_CAP
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, GATE_CAP)
	_lightning.append(e)
	if sparks:
		for p in points:
			burst(p, color, 5, 1.4, 0.06, 0.25, -2.0)


## Gate labels v2: true when a bolt through `points` (sampled along each segment) crosses a gate panel during an ult.
func _bolt_over_gate(points: Array[Vector3], width: float) -> bool:
	if not _gate_hold():
		return false
	for i in points.size() - 1:
		for s in 5:
			if _over_gate(points[i].lerp(points[i + 1], float(s) / 4.0), width * 2.2):
				return true
	return false


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


# ------------------------------------------------------------------ Seer rift (additive, WS2b)

## Opens the Seer's Star Rift: a glowing tear across the road `width` wide with a slow-time
## curtain over it, at `pos` (road level). Returns the node; move it with the run, then call
## rift_close(). The tear opens over 0.35 s.
func rift_open(pos: Vector3, width := 6.6) -> Node3D:
	_ensure_pools()
	var root := Node3D.new()
	root.name = "Rift"
	root.position = pos
	add_child(root)
	var mats: Array[ShaderMaterial] = []
	for mode in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = Mats.quad(Vector2(width, 4.0 if mode == 0 else 3.4), mode == 0)
		var m := ShaderMaterial.new()
		m.shader = RIFT_SHADER
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("k", 0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mode == 0:
			mi.position.y = 0.06
		else:
			mi.position.y = 1.7
		root.add_child(mi)
		mats.append(m)
	_rifts.append({"node": root, "mats": mats, "k": 0.0, "t": 0.0, "closing": false, "w": width, "spark": 0.0})
	shockwave(pos, ARCANE, 3.4)
	flash(pos + Vector3(0, 0.6, 0), ARCANE, 2.6, 0.4)
	return root


## Fades the rift `node` out (0.4 s) and frees it.
func rift_close(node: Node3D) -> void:
	for r: Dictionary in _rifts:
		if r["node"] == node:
			r["closing"] = true


func _step_rifts(delta: float) -> void:
	var i := 0
	while i < _rifts.size():
		var r: Dictionary = _rifts[i]
		var node: Node3D = r["node"]
		if not is_instance_valid(node):
			_rifts.remove_at(i)
			continue
		r["t"] = fmod(float(r["t"]) + delta, 1000.0)
		r["k"] = move_toward(float(r["k"]), 0.0 if r["closing"] else 1.0, delta * (2.5 if r["closing"] else 3.0))
		var k_draw := float(r["k"])
		if Models.gate_labels_v2:
			# Gate labels v2: the tear and its curtain ease down to GATE_CAP while a gate panel stands over them.
			var want := _gate_cap(node.global_position + Vector3(0.0, 1.7, 0.0), float(r["w"]) * 0.5)
			r["cap"] = move_toward(float(r.get("cap", 1.0)), want, delta * 4.0)
			k_draw = minf(k_draw, float(r["cap"]))
		for m: ShaderMaterial in r["mats"]:
			m.set_shader_parameter("k", k_draw)
			m.set_shader_parameter("t", float(r["t"]))
		# Star dust drifting up out of the tear.
		r["spark"] = float(r["spark"]) + delta * (40.0 if quality_high else 18.0) * float(r["k"])
		var w := float(r["w"])
		while float(r["spark"]) >= 1.0:
			r["spark"] = float(r["spark"]) - 1.0
			var p := node.global_position + Vector3(randf_range(-w * 0.45, w * 0.45), 0.1, randf_range(-0.3, 0.3))
			var c := ARCANE.lerp(Color(1.0, 0.85, 0.5), randf() * randf())
			_sparks.add(p, Vector3(randf_range(-0.2, 0.2), randf_range(1.2, 3.2), randf_range(-0.2, 0.2)), c, randf_range(0.5, 0.9), 0.045, 0.012, 0.4, 1.2, 0.05)
		# Flares riding the rim of the tear.
		var kk := float(r["k"])
		if kk > 0.05:
			for j in 5:
				var fx := (float(j) - 2.0) / 2.0 * w * 0.36
				var pul := 0.75 + 0.25 * sin(float(r["t"]) * 5.0 + float(j) * 1.7)
				_frame_glows.append([node.global_position + Vector3(fx, 0.25, 0.0), (1.0 - absf(fx) / w) * 1.3 * kk * pul, ARCANE, 0.5, fposmod(float(r["t"]) * 0.7 + j, TAU), 0.8])
		if r["closing"] and float(r["k"]) <= 0.0:
			node.queue_free()
			_rifts.remove_at(i)
			continue
		i += 1
