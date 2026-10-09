class_name ChampionView
extends Node3D
## The champions on the bridge (heroes design §4.2, §10.1, §10.5, §10.6): a RunChampion per member
## (its animation state; batched, no mesh of its own), the crowd solids (soldiers part around each
## living champion), the hop over hazards, and everything they show, in at most three draws:
## - Bodies: every champion in ONE MeshInstance3D (RunChampion.merged_mesh + BATCH_SHADER, the poses
##   in one uniform array); it casts the sun's shadow (+1 shadow draw; the low preset has no sun
##   shadow at all, Track.quality_high).
## - Marks: ONE MultiMesh (ChampionFx.SHADER) with each champion's contact shadow, white-gold foot
##   ring (under the drawn model, so it reads inside a crowd of knights), aura ring and class glyph,
##   then the ChampionFx pool: arrow tracers, leap dust, spell and mend sparkles, spell rings, the
##   ring shatter, every twist's placeholder (§6.11-6.27), Дара's tethers and the stamp plate.
## - The stamp text: one Label3D without outline (+1 draw only while a «БЛОК» / «ЧИСТО!» shows).
## ChampionHud puts the medallions and the start banner on the HUD. Run builds this only while
## Champions.active(); it never changes the rules (ChampionKinds) and reads the members as the rules
## left them.
##
## Run palette (§10.3): white-gold #FFE7A3 marks (ring alpha 0.25), the glyph and the twists in the
## element accent (ArsenalData.FAMILIES) lifted toward white-gold; never a gem hue. Nothing additive,
## no glow, nothing taller than a knight between the camera and the next gate row (§10.2): the motes
## are small and matte, the stamp sits under the gate labels' render priority.

const MARK := Color("#FFE7A3")
const RING_ALPHA := 0.25
const GLYPH_ALPHA := 0.85
const GLYPH_SIZE := 0.36
## Ring radius when a member has none (the class aura radius, ChampionKinds.member "radius").
const RING_R := 1.1
## Under the drawn model: a soft ink contact shadow and a thin white-gold foot ring inside the gap the
## crowd leaves around a champion (SOLID_R), so a crowd of knights never covers it (§10.5 legibility); the
## class glyph sits on the ring toward the camera like a medallion on its chain.
const FOOT_R := 0.32
const FOOT_W := 0.035
const FOOT_A := 0.62
const SHADOW_R := 0.44
const SHADOW_A := 0.3
const INK := Color(0.05, 0.06, 0.12)
## Crowd: each living champion is a solid circle of this radius (§4.2).
const SOLID_R := 0.32
const MEND := Color(0.86, 1.0, 0.9)
const DUST := Color(0.86, 0.82, 0.74)
## Довбуш's thrown axe: dark steel. Борко's ridge: turned earth. Тарас's pages: paper.
const BLADE_INK := Color(0.24, 0.26, 0.36, 0.95)
const DIRT := Color(0.53, 0.46, 0.37, 0.55)
const PAGE_TINT := Color(1.0, 0.98, 0.93, 0.95)
const CLASS_INDEX := {"warrior": 0, "ranger": 1, "mage": 2, "guardian": 3, "healer": 4}
const NO_ARMY := {}
## Marks instances: four per member (shadow, foot ring, aura ring, glyph), the FX pool, the tethers, the plate.
const PER_MEMBER := 4
const TETHERS := 6
## The stamp («БЛОК» / «ЧИСТО!»): one Label3D on a porcelain plate (ChampionFx PLATE), above the hazard.
const STAMP_LIFE := 0.95
const STAMP_PX := 64
const STAMP_PIXEL := 0.0056
const STAMP_H := 0.5
const STAMP_PAD := 0.3
const STAMP_RISE := 0.3
const STAMP_INK := Color("#2C3158")
## Under the gate labels (3+), over the marks (1): §10.2.
const STAMP_PRIORITY := 2
const STAMPS := {&"block": "CHAMP_BLOCK_POP", &"clear": "CHAMP_CLEAR_POP", &"catch": "CHAMP_BLOCK_POP"}

static var _marks_sh: Shader

var run: Run
var members: Array = []
var models: Array[RunChampion] = []
var hud: ChampionHud
## The pooled VFX written into the marks (ChampionFx).
var fx := ChampionFx.new()
var _by_id := {}
var _bodies: MeshInstance3D
var _bmat: ShaderMaterial
var _pose := PackedVector4Array()
var _marks: MultiMeshInstance3D
var _buf := PackedFloat32Array()
var _cap := 0
var _shown := -1
var _solids: Array = []
var _vk := PackedInt32Array()
var _marks_on := PackedByteArray()
var _ring_r := PackedFloat32Array()
var _cls_idx := PackedFloat32Array()
var _ring_col: Array[Color] = []
var _glyph_col: Array[Color] = []
## Last spell centre per member (Тарас's pages fly on from it).
var _spell_at: Array[Vector3] = []
## Дара's tethers: [squad a, squad b, seconds left, colour, age].
var _tethers: Array = []
var _stamp: Label3D
var _stamp_t := -1.0
var _stamp_at := Vector3.ZERO
var _stamp_w := 1.0


## Builds a batched model per member of `p_run.champions` at its slot around the start blob, the
## bodies' draw, the marks' draw and the stamp.
func setup(p_run: Run) -> void:
	run = p_run
	members = run.champions.members
	var classes: Array = []
	for m: Dictionary in members.slice(0, RunChampion.BATCH_MAX):
		var c := RunChampion.new()
		c.name = "Champion_%s" % str(m["id"])
		add_child(c)
		c.setup(str(m["class"]), str(m["element"]), true)
		models.append(c)
		classes.append(c.cls)
		_by_id[str(m["id"])] = models.size() - 1
		_solids.append([Vector3.ZERO, SOLID_R])
		_vk.append(0)
		_marks_on.append(1)
		_ring_r.append(clampf(float(m.get("radius", RING_R)), 0.6, 1.6))
		_cls_idx.append(float(CLASS_INDEX.get(str(m["class"]), 0)))
		_ring_col.append(Color(MARK.r, MARK.g, MARK.b, RING_ALPHA))
		var fam: Dictionary = ArsenalData.FAMILIES.get(str(m["element"]), {})
		var acc: Color = (fam.get("accent", MARK) as Color).lerp(MARK, 0.45)
		_glyph_col.append(Color(acc.r, acc.g, acc.b, GLYPH_ALPHA))
		_spell_at.append(Vector3.INF)
	_build_bodies(classes)
	_build_marks()
	_build_stamp()
	hud = ChampionHud.new()
	hud.name = "ChampionHud"
	add_child(hud)
	hud.setup(run)
	_place(0.0, true)
	draw(0.0)


## The model of member `id` (null when unknown).
func model(id: String) -> RunChampion:
	var i := int(_by_id.get(id, -1))
	return models[i] if i >= 0 else null


## Per frame (Run._visuals): places, animates, vaults, ticks the VFX, then fills the two draws.
func draw(dt: float) -> void:
	_place(dt, false)
	var st := run.state
	var running := st == Run.State.RUNNING
	var fighting := st == Run.State.CLASH or st == Run.State.SIEGE
	var cheering := st == Run.State.STAIRS or st == Run.State.WON
	for c in models:
		c.animate(dt, running, fighting, cheering)
	_vault_check()
	fx.tick(dt)
	_draw_bodies()
	_draw_marks(dt)


## Adds the living champions' solid circles to the army's obstacles (Run._army_step; merged with
## the hazards', machines' and gate pylons', never replacing them).
func add_solids(out: Array) -> void:
	for i in models.size():
		var c := models[i]
		if not c.alive:
			continue
		var s: Array = _solids[i]
		s[0] = Vector3(c.root.x, 0.0, c.root.z)
		out.append(s)


## Triangles of the champions' draw and the draws this view adds (perf, §10.6): the bodies (one draw,
## +1 in the sun's shadow pass while it casts) and the marks with every VFX (one draw); the stamp's
## text is the one transient draw.
func budget() -> Dictionary:
	var tris := RunChampion.tri_count(_bodies.mesh as ArrayMesh) if _bodies else 0
	return {"models": models.size(), "tris": tris, "surfaces": 1, "multimeshes": 1, "draws_steady": 2,
			"draws_shadow": 1, "draws_transient": 1, "fx_pool": ChampionFx.POOL}


## One VFX mote (kept for dev tools: ChampionFx.mote).
func mote(at: Vector3, vel: Vector3, life: float, size: float, col: Color, delay := 0.0, grav := 0.0) -> void:
	fx.mote(at, vel, life, size, col, delay, grav)


# ------------------------------------------------------------------ placing

## Where each member stands: the rules' x / d while the run steps them (they include the slot
## offset), the slot around the blob before the start; at the stairs and the end they stay at the
## fortress line where they are.
func _place(dt: float, snap: bool) -> void:
	var st := run.state
	var stepped := st == Run.State.RUNNING or st == Run.State.CLASH or st == Run.State.SIEGE
	var a: Dictionary = run.kind_view.army() if st == Run.State.READY else NO_ARMY
	for i in models.size():
		var c := models[i]
		var m: Dictionary = members[i]
		if not c.alive:
			continue
		var goal := c.pos
		if stepped:
			goal = Vector3(float(m["x"]), 0.0, -float(m["d"]))
		elif st == Run.State.READY:
			var off := ChampionKinds.slot_offset(m["slot"], float(a["radius"]))
			goal = Vector3(float(a["x"]) + off.x, 0.0, -(float(a["d"]) - off.y))
		c.follow(goal, dt, snap)


## Champions hop over the hazards they cross, as the hero does (Run._vault_check).
func _vault_check() -> void:
	var vaults := run.vault_items()
	for i in models.size():
		var c := models[i]
		var k := _vk[i]
		var cd := -c.pos.z
		while k < vaults.size() and float(vaults[k]["d"]) - 0.35 <= cd:
			var it := vaults[k]
			k += 1
			if not c.alive:
				continue
			var x := float(it.get("x0", it["x"]))
			if (it["alive"] or str(it["kind"]) == "blade") and absf(c.pos.x - x) < run.vault_reach(it):
				c.vault()
		_vk[i] = k


# ------------------------------------------------------------------ the bodies (one draw)

func _build_bodies(classes: Array) -> void:
	_pose.resize(RunChampion.POSE_ROWS * RunChampion.BATCH_MAX)
	_bmat = RunChampion.batch_material()
	_bodies = MeshInstance3D.new()
	_bodies.name = "Bodies"
	_bodies.mesh = RunChampion.merged_mesh(classes)
	_bodies.material_override = _bmat
	_bodies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The node follows the champions' centre; the members stand, leap and burrow within this of it.
	_bodies.extra_cull_margin = 8.0
	add_child(_bodies)


## The poses of every member into the one uniform array; the node sits at their centre (culling).
func _draw_bodies() -> void:
	var anchor := Vector3.ZERO
	var n := 0
	for c in models:
		if c.visible:
			anchor += c.position
			n += 1
	_bodies.visible = n > 0
	if n == 0:
		return
	anchor /= float(n)
	anchor.y = 0.0
	_bodies.position = anchor
	for i in models.size():
		models[i].pose_into(_pose, i * RunChampion.POSE_ROWS, anchor)
	_bmat.set_shader_parameter(&"pose", _pose)


# ------------------------------------------------------------------ the marks and the VFX (one draw)

func _build_marks() -> void:
	if _marks_sh == null:
		_marks_sh = Shader.new()
		_marks_sh.code = ChampionFx.SHADER
	_cap = models.size() * PER_MEMBER + ChampionFx.POOL + TETHERS + 1
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	_marks = MultiMeshInstance3D.new()
	_marks.name = "Marks"
	_marks.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = _marks_sh
	m.render_priority = 1
	_marks.material_override = m
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.extra_cull_margin = 2.0
	add_child(_marks)
	_buf.resize(_cap * ChampionFx.STRIDE)


## Under every standing champion (at the drawn model, so a leap or a hop carries them): the contact
## shadow and the foot ring; the aura ring and the class glyph (on the foot ring, toward the camera)
## while it lives; a fallen one keeps only its shadow (its ring shattered). Then the ground
## VFX, the tethers, the VFX above the road and the stamp plate.
func _draw_marks(dt: float) -> void:
	var n := 0
	var o := 0
	for i in models.size():
		var c := models[i]
		if not c.visible:
			continue
		var g := Vector3(c.root.x, 0.0, c.root.z)
		# Burrowing (Борко): the marks under him fade while he is under the road.
		var up := clampf(1.0 - c.buried() / 0.35, 0.0, 1.0)
		var lift := clampf(1.0 - (c.root.y - c.pos.y) / 1.2, 0.35, 1.0)
		o = n * ChampionFx.STRIDE
		ChampionFx.put_flat(_buf, o, g + Vector3(0.0, 0.02, 0.0), SHADOW_R * 2.0, 0.0)
		ChampionFx.put_tail(_buf, o, Color(INK.r, INK.g, INK.b, SHADOW_A * up * lift), ChampionFx.DISC, 0.2)
		n += 1
		if not c.alive or _marks_on[i] == 0:
			continue
		o = n * ChampionFx.STRIDE
		ChampionFx.put_flat(_buf, o, g + Vector3(0.0, 0.032, 0.0), FOOT_R * 2.0, 0.0)
		ChampionFx.put_tail(_buf, o, Color(MARK.r, MARK.g, MARK.b, FOOT_A * up), ChampionFx.RING, 0.5 * FOOT_W / FOOT_R)
		n += 1
		var r := _ring_r[i]
		o = n * ChampionFx.STRIDE
		ChampionFx.put_flat(_buf, o, g + Vector3(0.0, 0.03, 0.0), r * 2.0, 0.0)
		ChampionFx.put_tail(_buf, o, _ring_col[i], ChampionFx.RING, 0.03)
		n += 1
		o = n * ChampionFx.STRIDE
		ChampionFx.put_flat(_buf, o, g + Vector3(0.0, 0.036, FOOT_R), GLYPH_SIZE, 0.0)
		var gc := _glyph_col[i]
		ChampionFx.put_tail(_buf, o, Color(gc.r, gc.g, gc.b, gc.a * up), ChampionFx.SIGN, _cls_idx[i], 1.0)
		n += 1
	n = fx.write(_buf, n, _cap, true)
	n = _draw_tethers(dt, n)
	n = fx.write(_buf, n, _cap, false)
	n = _draw_stamp(dt, n)
	var mm := _marks.multimesh
	if n == 0 and _shown == 0:
		return
	_shown = n
	_marks.visible = n > 0
	if n > 0:
		mm.custom_aabb = _bounds(n)
		mm.buffer = _buf
	mm.visible_instance_count = n


## The box around the first `n` instances (their centres + the widest quad): set as the MultiMesh's
## own AABB, so the slots past `n` (stale) never stretch its culling and its depth sort.
func _bounds(n: int) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var big := 0.0
	for k in n:
		var o := k * ChampionFx.STRIDE
		var p := Vector3(_buf[o + 3], _buf[o + 7], _buf[o + 11])
		lo = lo.min(p)
		hi = hi.max(p)
		big = maxf(big, maxf(absf(_buf[o]) + absf(_buf[o + 4]) + absf(_buf[o + 8]),
				absf(_buf[o + 1]) + absf(_buf[o + 5]) + absf(_buf[o + 9])))
	var pad := Vector3.ONE * (big * 0.5 + 0.2)
	return AABB(lo - pad, hi - lo + pad * 2.0)


# ------------------------------------------------------------------ the stamp («БЛОК», «ЧИСТО!»)

func _build_stamp() -> void:
	_stamp = Label3D.new()
	_stamp.name = "Stamp"
	_stamp.font = UIKit.font(true)
	_stamp.font_size = STAMP_PX
	_stamp.pixel_size = STAMP_PIXEL
	_stamp.outline_size = 0
	_stamp.modulate = STAMP_INK
	_stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stamp.no_depth_test = true
	_stamp.fixed_size = false
	_stamp.double_sided = true
	_stamp.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	_stamp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stamp.render_priority = STAMP_PRIORITY
	_stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stamp.visible = false
	add_child(_stamp)


## Shows `text` on the porcelain plate at `at` (a new stamp replaces the one showing).
func stamp(text: String, at: Vector3) -> void:
	_stamp.text = text
	var w := _stamp.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_PX).x * STAMP_PIXEL
	_stamp_w = w + STAMP_PAD
	_stamp_at = at
	_stamp_t = 0.0
	_stamp.visible = true


## The stamp's pop (0.14 s), rise and fade; its plate goes into the marks at `n`.
func _draw_stamp(dt: float, n: int) -> int:
	if _stamp_t < 0.0:
		return n
	_stamp_t += dt
	var k := _stamp_t / STAMP_LIFE
	if k >= 1.0 or n >= _cap:
		_stamp_t = -1.0
		_stamp.visible = false
		return n
	var pop := 0.82 + 0.24 * smoothstep(0.0, 0.09, _stamp_t) - 0.06 * smoothstep(0.09, 0.14, _stamp_t)
	var a := 1.0 - smoothstep(0.72, 1.0, k)
	var at := _stamp_at + Vector3(0.0, STAMP_RISE * (1.0 - (1.0 - k) * (1.0 - k)), 0.0)
	_stamp.position = at
	_stamp.scale = Vector3.ONE * pop
	_stamp.modulate = Color(STAMP_INK.r, STAMP_INK.g, STAMP_INK.b, a)
	var o := n * ChampionFx.STRIDE
	ChampionFx.put_face(_buf, o, at, _stamp_w * pop, STAMP_H * pop)
	ChampionFx.put_tail(_buf, o, Color(1.0, 1.0, 1.0, 0.94 * a), ChampionFx.PLATE)
	return n + 1


# ------------------------------------------------------------------ tethers (Дара)

## Each live tether as a thin band between its two squads' current places (they move), fading in and out.
func _draw_tethers(dt: float, n: int) -> int:
	var i := 0
	while i < _tethers.size():
		var t: Array = _tethers[i]
		t[2] = float(t[2]) - dt
		t[4] = float(t[4]) + dt
		var pa := _item_at(int(t[0]), 0.5)
		var pb := _item_at(int(t[1]), 0.5)
		if float(t[2]) <= 0.0 or pa == Vector3.INF or pb == Vector3.INF:
			_tethers.remove_at(i)
			continue
		i += 1
		if n >= _cap:
			continue
		var col: Color = t[3]
		col.a *= smoothstep(0.0, 0.12, float(t[4])) * clampf(float(t[2]) / 0.3, 0.0, 1.0)
		var o := n * ChampionFx.STRIDE
		ChampionFx.put_band(_buf, o, pa, pb, 0.08)
		ChampionFx.put_tail(_buf, o, col, ChampionFx.BAND, 0.04)
		n += 1
	return n


## World point of KindView target `id` (a squad or a structure) at height `y`; INF when it is gone.
func _item_at(id: int, y := 0.0) -> Vector3:
	var it := run.kind_item(id)
	if it.is_empty() or not it.get("alive", false):
		return Vector3.INF
	return Vector3(float(it.get("x0", it["x"])), y, -float(it["d"]))


# ------------------------------------------------------------------ VFX helpers (all into the pool)

## `n` motes bursting from `at` (radial, slightly up), after `delay`.
func _burst(at: Vector3, n: int, speed: float, col: Color, size := 0.09, delay := 0.0, up := 1.0, grav := 4.0,
		shape := ChampionFx.DIAMOND) -> void:
	for k in n:
		var a := TAU * (float(k) + randf() * 0.5) / float(n)
		var v := Vector3(cos(a), 0.0, sin(a)) * speed * randf_range(0.6, 1.0)
		v.y = up * randf_range(0.6, 1.2)
		fx.mote(at, v, randf_range(0.35, 0.55), size, col, delay, grav, shape)


## `n` sparkles rising from a disc of radius `r` around `at`.
func _rise(at: Vector3, n: int, r: float, col: Color, delay := 0.0, shape := ChampionFx.DIAMOND) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + randf() * 0.6
		var k2 := r * randf_range(0.3, 1.0)
		var p := at + Vector3(cos(a) * k2, randf_range(0.1, 0.5), sin(a) * k2)
		fx.mote(p, Vector3(0.0, randf_range(0.8, 1.5), 0.0), randf_range(0.45, 0.7), 0.1, col, delay + randf() * 0.12,
				0.0, shape)


## A tracer of three motes flying from `from` to `to` (one arrow; matte, not a beam). `homing` bends it
## in from the side the way Тео's star shots curve onto their target.
func _tracer(from: Vector3, to: Vector3, col: Color, homing := false) -> float:
	var time := clampf(from.distance_to(to) / 30.0, 0.1, 0.45)
	if homing:
		time = clampf(from.distance_to(to) / 22.0, 0.15, 0.6)
		var side := signf(to.x - from.x + 0.01) * -1.4
		var ctrl := (from + to) * 0.5 + Vector3(side, 1.1, 0.0)
		for k in 3:
			fx.curve(from, ctrl, to, time, 0.15 - 0.03 * k, col, 0.022 * k, ChampionFx.STAR if k == 0 else ChampionFx.DIAMOND)
		return time
	var v := (to - from) / time
	for k in 3:
		fx.mote(from, v, time, 0.13 - 0.025 * k, col, 0.022 * k)
	return time


## Matte embers drifting up from `at` (Іво's brazier, Брант's blades), in the element accent.
func _embers(at: Vector3, n: int, col: Color, r := 0.4, delay := 0.0) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + randf() * 0.7
		var p := at + Vector3(cos(a) * r * randf(), randf_range(0.1, 0.45), sin(a) * r * randf())
		fx.mote(p, Vector3(randf_range(-0.2, 0.2), randf_range(0.7, 1.3), randf_range(-0.2, 0.2)),
				randf_range(0.5, 0.8), 0.11, col, delay + randf() * 0.25, -0.3, ChampionFx.ROUND, 0.8)


## A jagged chain from `a` to `b` (three bands with a sideways kink each), after `delay`.
func _chain(a: Vector3, b: Vector3, col: Color, delay: float) -> void:
	var prev := a
	for k in 3:
		var kink := Vector3(randf_range(-0.22, 0.22), randf_range(-0.12, 0.18), randf_range(-0.12, 0.12))
		var nxt := b if k == 2 else a.lerp(b, float(k + 1) / 3.0) + kink
		fx.band(prev, nxt, 0.05, 0.3, col, delay)
		prev = nxt


# ------------------------------------------------------------------ rules' fx (ChampionKinds.FX)

## A champ_* event from the rules (Run._champ_fx): the model's pose, its VFX and the HUD.
func on_fx(event: StringName, data: Dictionary) -> void:
	var i := int(_by_id.get(str(data.get("id", "")), -1))
	var c: RunChampion = models[i] if i >= 0 else null
	match event:
		&"champ_leap":
			if c:
				_leap(c, data)
		&"champ_shot":
			if c:
				var to := Vector3(float(data.get("x", c.pos.x)), 0.55, -float(data.get("d", -c.pos.z + 6.0)))
				c.act(&"shot", to)
				var from := c.root + Vector3(-0.12, 0.85, -0.3)
				var homing := bool(data.get("homing", false))
				for k in maxi(int(data.get("arrows", 1)), 1):
					_tracer(from + Vector3(0.06 * k, 0.04 * k, 0.0), to + Vector3(0.12 * k, 0.0, 0.0), MARK, homing)
				Audio.play("volley", -16.0, 0.2)
		&"champ_spell":
			if c:
				var sp := Vector3(float(data.get("x", 0.0)), 0.0, -float(data.get("d", 0.0)))
				var r := float(data.get("r", 1.5))
				c.act(&"spell", sp)
				_spell_at[i] = sp
				var col: Color = _glyph_col[i]
				var at := sp + Vector3(0.0, 0.045, 0.0)
				fx.ring(at, r * 0.86, r, 0.06, 0.75, Color(col.r, col.g, col.b, 0.95), 0.0, 0.7)
				fx.disc(at, r * 0.8, r, 0.6, Color(col.r, col.g, col.b, 0.14), 0.0, 0.55)
				_rise(sp, 8, r * 0.8, MARK, RunChampion.impact_delay(&"spell"))
				Audio.play("tesla", -15.0, 0.2)
		&"champ_block":
			if c:
				var it := run.kind_item(int(data.get("hazard", -1)))
				var hp := Vector3(c.pos.x, 0.0, c.pos.z - 1.0)
				if not it.is_empty():
					hp = Vector3(float(it.get("x0", it["x"])), 0.0, -float(it["d"]))
				c.act(&"block", hp)
				var key := str(STAMPS.get(StringName(str(data.get("stamp", "block"))), STAMPS[&"block"]))
				stamp(Loc.t(key), hp + Vector3(0.0, 1.55, 0.0))
				_burst(c.root + Vector3(-0.15, 0.6, -0.35), 6, 1.6, MARK, 0.08, 0.05, 1.0, 3.0)
				Audio.play("upgrade", -12.0, 0.15)
		&"champ_mend":
			if c:
				c.act(&"mend")
				_rise(c.pos, 6, 0.35, MEND, RunChampion.impact_delay(&"mend"))
				_rise(run.army_view.front_point(), 6, 0.5, MEND, 0.15)
				Audio.play("recruit", -14.0, 0.15)
		&"champ_heal":
			var tc := model(str(data.get("target", "")))
			if tc:
				_rise(tc.pos, 8, 0.3, MEND)
		&"champ_hit":
			if c:
				c.flinch()
		&"champ_down":
			if c:
				_shatter(i)
				c.fall()
				run.juice.hitstop(0.2)
				Audio.play("death", -6.0, 0.1)
		&"champ_revive":
			if c:
				c.revive()
				_marks_on[i] = 1
				_rise(c.pos, 10, 0.4, MEND)
		&"champ_twist":
			if c:
				_twist(c, i, data)
	if hud:
		hud.on_fx(event, data)


## The Warrior's strike by verb: the leap (an arc out and back, dust at the impact), Борко's burrow
## (the twist draws the ridge and the eruption) or Довбуш's axe throw (the twist draws the axe).
func _leap(c: RunChampion, data: Dictionary) -> void:
	var at := Vector3(float(data.get("x", c.pos.x)), 0.0, -float(data.get("d", -c.pos.z)) + 0.4)
	match StringName(str(data.get("verb", "leap"))):
		&"undermine":
			c.act(&"burrow", at)
		&"bartka":
			c.act(&"throw", at)
		_:
			c.act(&"leap", at)
			_burst(at + Vector3(0.0, 0.08, 0.0), 8, 2.2, DUST, 0.1, RunChampion.impact_delay(&"leap"), 0.8, 5.0)
	Audio.play("brawl", -12.0, 0.15)


## The ring of champion `i` breaks: a quick wider flash of the ring, then white-gold slivers fly out,
## spin and drop, all matte and gone in 0.7 s.
func _shatter(i: int) -> void:
	_marks_on[i] = 0
	var c := models[i]
	var r := _ring_r[i]
	var g := Vector3(c.root.x, 0.04, c.root.z)
	fx.ring(g, r, r * 1.12, 0.04, 0.25, Color(MARK.r, MARK.g, MARK.b, 0.5), 0.0, 0.2)
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		fx.mote(g + dir * r + Vector3(0.0, 0.08, 0.0), dir * randf_range(1.0, 1.8) + Vector3(0.0, randf_range(1.8, 2.6), 0.0),
				randf_range(0.55, 0.75), 0.16, MARK, 0.0, 7.0, ChampionFx.BLADE, 0.0, randf_range(-12.0, 12.0))


# ------------------------------------------------------------------ twists (ChampionKinds.TWIST_FX)

## One twist moment (§6.11-6.27, ChampionKinds.TWIST_FX lists the keys): a cheap placeholder in the pool,
## in the champion's element accent unless it is earth (dust) or the stamp's white-gold.
func _twist(c: RunChampion, i: int, data: Dictionary) -> void:
	var acc: Color = _glyph_col[i]
	acc.a = 0.9
	var tgt := Vector3(float(data.get("x", c.pos.x)), 0.0, -float(data.get("d", -c.pos.z)))
	match StringName(str(data.get("twist", ""))):
		&"undermine":
			_undermine(c, tgt, maxf(float(data.get("burrow_s", 0.0)), 0.2), acc)
		&"bartka":
			_bartka(c, tgt, acc)
		&"cross":
			var r := maxf(float(data.get("r", 1.5)), 0.6)
			fx.sign(tgt + Vector3(0.0, 0.05, 0.0), r * 2.0, ChampionFx.CROSS, 0.9, acc, 0.0, 0.0, 0.0, 0.55)
			_embers(tgt, 6, acc, r * 0.6)
		&"blades":
			var sq := _item_at(int(data.get("target", -1)))
			_burst(c.root + Vector3(0.18, 0.62, -0.35), 4, 1.2, acc, 0.07, 0.0, 0.8, 2.0)
			if sq != Vector3.INF:
				_embers(sq, 4, acc, 0.5)
		&"brazier":
			var at := _item_at(int(data.get("hazard", data.get("target", -1))))
			if at != Vector3.INF:
				fx.disc(at + Vector3(0.0, 0.04, 0.0), 0.5, 0.75, 0.8, Color(acc.r, acc.g, acc.b, 0.22), 0.0, 0.3)
				_embers(at, 8, acc, 0.5)
		&"probe":
			var dl := clampf(c.root.distance_to(tgt) / 22.0, 0.15, 0.6)
			fx.vring(tgt + Vector3(0.0, 0.6, 0.0), 0.2, 0.55, 0.04, 0.45, acc, dl)
			fx.ring(tgt + Vector3(0.0, 0.05, 0.0), 0.4, 1.6, 0.05, 0.6, Color(acc.r, acc.g, acc.b, 0.6), dl)
			var reveal: Variant = data.get("reveal", [])
			if reveal is Array:
				for id: Variant in reveal:
					var p := _item_at(int(id), 0.7)
					if p != Vector3.INF:
						fx.vring(p, 0.25, 0.7, 0.04, 0.6, acc, dl + 0.1)
						_rise(p - Vector3(0.0, 0.7, 0.0), 4, 0.4, acc, dl + 0.1, ChampionFx.STAR)
		&"harpoon":
			if _tethers.size() >= TETHERS:
				_tethers.pop_front()
			_tethers.append([int(data.get("target", -1)), int(data.get("partner", -1)), maxf(float(data.get("s", 3.0)), 0.3),
					acc, 0.0])
			var pp := _item_at(int(data.get("partner", -1)), 0.5)
			if pp != Vector3.INF:
				fx.vring(pp, 0.2, 0.5, 0.04, 0.4, acc, 0.1)
		&"lull":
			var sq2 := _item_at(int(data.get("target", -1)))
			if sq2 != Vector3.INF:
				var s := clampf(float(data.get("s", 1.5)), 0.4, 3.0)
				for k in 6:
					var p2 := sq2 + Vector3(randf_range(-0.6, 0.6), randf_range(0.9, 1.15), randf_range(-0.4, 0.4))
					fx.mote(p2, Vector3(randf_range(-0.15, 0.15), 0.35, 0.0), 0.9, 0.13, Color(acc.r, acc.g, acc.b, 0.8),
							s * float(k) / 6.0, 0.0, ChampionFx.ROUND, 0.0)
		&"circle":
			var r2 := maxf(float(data.get("r", 1.5)), 0.6)
			var life := maxf(float(data.get("s", 3.0)), 0.5) + 0.3
			fx.sign(tgt + Vector3(0.0, 0.05, 0.0), r2 * 2.0, ChampionFx.RUNES, life, Color(acc.r, acc.g, acc.b, 0.55), 0.0,
					0.0, 0.35, 0.9)
			fx.ring(tgt + Vector3(0.0, 0.05, 0.0), r2 * 0.5, r2, 0.05, 0.5, Color(acc.r, acc.g, acc.b, 0.7))
		&"pages":
			var from: Vector3 = _spell_at[i] if _spell_at[i] != Vector3.INF else c.root
			from.y = 0.6
			var to := tgt + Vector3(0.0, 0.55, 0.0)
			for k in 4:
				var ctrl := (from + to) * 0.5 + Vector3(randf_range(-0.6, 0.6), 1.0 + 0.2 * k, 0.0)
				fx.curve(from, ctrl, to, 0.42, 0.13, PAGE_TINT, 0.05 * k, ChampionFx.PAGE, randf_range(6.0, 10.0))
		&"plant":
			c.act(&"block", c.pos + Vector3(0.0, 0.0, -2.0))
			var g := Vector3(c.root.x, 0.05, c.root.z)
			fx.ring(g, 0.3, 1.1, 0.06, 0.55, Color(MARK.r, MARK.g, MARK.b, 0.8))
			_burst(g, 8, 1.8, DUST, 0.1, 0.0, 0.6, 5.0)
		&"rod":
			var prev := c.root + Vector3(0.0, 0.95, 0.0)
			var targets: Variant = data.get("targets", [])
			var dl2 := 0.0
			if targets is Array:
				for id2: Variant in targets:
					var p3 := _item_at(int(id2), 0.55)
					if p3 == Vector3.INF:
						continue
					_chain(prev, p3, acc, dl2)
					fx.vring(p3, 0.15, 0.45, 0.04, 0.3, acc, dl2)
					prev = p3
					dl2 += 0.06
		&"charge":
			var from2 := Vector3(c.root.x, 0.06, c.root.z)
			for k in 5:
				fx.mote(from2.lerp(tgt, float(k + 1) / 6.0) + Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.5, 0.0), 0.4, 0.08, DUST,
						0.025 * k, 0.0, ChampionFx.ROUND)
			fx.ring(tgt + Vector3(0.0, 0.05, 0.0), 0.3, 1.4, 0.07, 0.5, Color(acc.r, acc.g, acc.b, 0.8), 0.15)
			_burst(tgt + Vector3(0.0, 0.2, 0.0), 10, 2.4, DUST, 0.12, 0.15, 1.0, 5.0)
			_burst(tgt + Vector3(0.0, 0.3, 0.0), 5, 1.6, acc, 0.08, 0.15, 1.2, 4.0)
		&"catch":
			var aegis := c.root + Vector3(0.0, 0.75, -0.15)
			fx.vring(aegis, 0.3, 0.55, 0.05, 0.4, MARK)
			var tp := _item_at(int(data.get("hazard", -1)), 1.0)
			if tp != Vector3.INF:
				fx.band(tp, aegis, 0.05, 0.22, Color(MARK.r, MARK.g, MARK.b, 0.8))
		&"tonic":
			var from3 := c.root + Vector3(-0.15, 0.7, -0.2)
			var to3 := tgt + Vector3(0.0, 0.5, 0.0)
			fx.curve(from3, (from3 + to3) * 0.5 + Vector3(0.0, 1.6, 0.0), to3, 0.45, 0.13, acc, 0.0, ChampionFx.ROUND)
			fx.ring(tgt + Vector3(0.0, 0.05, 0.0), 0.3, 1.0, 0.05, 0.5, Color(acc.r, acc.g, acc.b, 0.75), 0.45)
			_rise(tgt, 5, 0.5, acc, 0.45, ChampionFx.ROUND)
		&"balm":
			var front := run.army_view.front_point()
			fx.ring(Vector3(front.x, 0.05, front.z), 0.5, 2.0, 0.05, 0.55, Color(acc.r, acc.g, acc.b, 0.55))
			_rise(front, 10, 1.2, acc, 0.0, ChampionFx.STAR)
		&"rime":
			var hz := _item_at(int(data.get("hazard", -1)))
			if hz != Vector3.INF:
				fx.ring(hz + Vector3(0.0, 0.05, 0.0), 0.3, 0.9, 0.05, 0.45, Color(acc.r, acc.g, acc.b, 0.7))
				_rise(hz, 6, 0.5, acc, 0.0, ChampionFx.STAR)


## Борко's burrow (§6.13): a splash where he dives, a ridge of dirt racing under the road to the target
## while he travels (RunChampion burrow), the eruption at the impact.
func _undermine(c: RunChampion, tgt: Vector3, burrow_s: float, acc: Color) -> void:
	var alen := float(RunChampion.ACTION_LEN[&"burrow"])
	var t_in := RunChampion.BURROW_DOWN * alen
	var t_up := RunChampion.BURROW_UP * alen
	var t_hit := RunChampion.impact_delay(&"burrow")
	var from := Vector3(c.pos.x, 0.0, c.pos.z)
	_burst(from + Vector3(0.0, 0.08, 0.0), 6, 1.4, DUST, 0.1, t_in * 0.7, 0.7, 5.0)
	var steps := 7
	var span := maxf(t_up - t_in, burrow_s * 0.5)
	for k in steps:
		var u := float(k + 1) / float(steps + 1)
		var p := from.lerp(tgt, u)
		var dl := t_in + span * u
		fx.disc(p + Vector3(0.0, 0.03, 0.0), 0.22, 0.32, 0.6, DIRT, dl, 0.35)
		fx.mote(p + Vector3(0.0, 0.08, 0.0), Vector3(randf_range(-0.3, 0.3), 1.0, 0.0), 0.4, 0.14, DUST, dl, 3.0)
	fx.ring(tgt + Vector3(0.0, 0.05, 0.0), 0.25, 1.05, 0.06, 0.45, Color(DUST.r, DUST.g, DUST.b, 0.75), t_hit)
	_burst(tgt + Vector3(0.0, 0.1, 0.0), 10, 2.4, DUST, 0.12, t_hit, 1.1, 5.0)
	_burst(tgt + Vector3(0.0, 0.2, 0.0), 4, 1.8, acc, 0.12, t_hit, 1.4, 6.0, ChampionFx.BLADE)


## Довбуш's bartka (§6.27): the axe leaves his hand at the release, spins out to the first squad and back
## into his hand at the catch (RunChampion throw), with a strike at the far end.
func _bartka(c: RunChampion, tgt: Vector3, acc: Color) -> void:
	var t_out := RunChampion.impact_delay(&"throw")
	var t_back := RunChampion.catch_delay()
	var mid := (t_out + t_back) * 0.5
	var hand := c.pos + Vector3(0.2, 1.05, -0.15)
	var far := tgt + Vector3(0.0, 0.6, 0.0)
	var side := Vector3(0.7 if far.x >= hand.x else -0.7, 0.0, 0.0)
	var ctrl_out := (hand + far) * 0.5 + Vector3(0.0, 0.7, 0.0) - side
	var ctrl_back := (hand + far) * 0.5 + Vector3(0.0, 0.4, 0.0) + side
	# The axe in dark steel (it reads on the bright road and on space alike), a lighter echo behind it.
	for k in 2:
		var col := BLADE_INK if k == 0 else Color(acc.r, acc.g, acc.b, 0.5)
		fx.curve(hand, ctrl_out, far, mid - t_out, 0.44 - 0.12 * k, col, t_out + 0.035 * k, ChampionFx.BLADE, 20.0)
		fx.curve(far, ctrl_back, hand, t_back - mid, 0.44 - 0.12 * k, col, mid + 0.035 * k, ChampionFx.BLADE, 20.0)
	fx.ring(tgt + Vector3(0.0, 0.05, 0.0), 0.2, 0.75, 0.05, 0.4, Color(acc.r, acc.g, acc.b, 0.75), mid)
	_burst(far, 6, 1.6, acc, 0.08, mid, 0.8, 3.0)
