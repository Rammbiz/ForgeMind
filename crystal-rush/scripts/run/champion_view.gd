class_name ChampionView
extends Node3D
## The champions on the bridge (heroes design §4.2, §10.1, §10.5): one RunChampion grey-box per
## member, their aura rings and class glyphs (two MultiMeshes for all champions, one draw each),
## the crowd solids (soldiers part around each living champion), the hop over hazards, and the
## action VFX: a pooled MultiMesh of matte motes (arrow tracers, leap dust, spell and mend
## sparkles), the mage's area ring on the Effects telegraph pool, the «БЛОК» popup on the Juice
## popup pool and the ring shatter on the UnitFx debris pool. ChampionHud puts the medallions and
## the start banner on the HUD. Run builds this only while Champions.active(); it never changes
## the rules (ChampionKinds) and reads the members as the rules left them.
##
## Run palette (§10.3): white-gold #FFE7A3 marks (ring alpha 0.25), the glyph in the element accent
## (ArsenalData.FAMILIES) lifted toward white-gold; never a gem hue. Nothing additive, nothing taller
## than a knight between the camera and the next gate row (§10.2): the motes are small and matte.

const MARK := Color("#FFE7A3")
const RING_ALPHA := 0.25
const GLYPH_ALPHA := 0.85
const GLYPH_SIZE := 0.36
## Ring radius when a member has none (the class aura radius, ChampionKinds.member "radius").
const RING_R := 1.1
## Crowd: each living champion is a solid circle of this radius (§4.2).
const SOLID_R := 0.32
const MOTES := 64
const MEND := Color(0.86, 1.0, 0.9)
const DUST := Color(0.86, 0.82, 0.74)
const CLASS_INDEX := {"warrior": 0, "ranger": 1, "mage": 2, "guardian": 3, "healer": 4}
const NO_ARMY := {}

const RING_SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Champion aura ring on the bridge (ChampionView): a thin white-gold circle, instance colour + alpha.
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float d = abs(r - 0.955) - 0.03;
	float aa = fwidth(r) * 1.2;
	ALBEDO = to_linear(COLOR.rgb);
	ALPHA = COLOR.a * (1.0 - smoothstep(-aa, aa, d));
}
"

const GLYPH_SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Champion class glyph on the bridge (ChampionView): a thin white-gold medallion circle with the
// class sign inside, drawn as distance fields. INSTANCE_CUSTOM.x = class (0 warrior blade,
// 1 ranger arrow, 2 mage star, 3 guardian shield, 4 healer cross); COLOR = the sign's tint.
uniform vec3 line_color : source_color = vec3(1.0, 0.906, 0.639);
varying float v_cls;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
float box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a; vec2 e1 = c - b; vec2 e2 = a - c;
	vec2 v0 = p - a; vec2 v1 = p - b; vec2 v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
			vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
			vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}
float rhombus(vec2 p0, vec2 b) {
	vec2 p = abs(p0);
	vec2 q = b - 2.0 * p;
	float h = clamp((q.x * b.x - q.y * b.y) / dot(b, b), -1.0, 1.0);
	float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
	return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}
float sign_sdf(vec2 p, int k) {
	if (k == 0) {
		float blade = min(box(p - vec2(0.0, 0.16), vec2(0.075, 0.42)),
				tri(p, vec2(-0.075, 0.58), vec2(0.075, 0.58), vec2(0.0, 0.74)));
		float guard = box(p - vec2(0.0, -0.3), vec2(0.3, 0.055));
		float grip = min(box(p - vec2(0.0, -0.5), vec2(0.05, 0.15)), length(p - vec2(0.0, -0.68)) - 0.08);
		return min(blade, min(guard, grip));
	}
	if (k == 1) {
		float shaft = box(p - vec2(0.0, -0.08), vec2(0.05, 0.5));
		float head = tri(p, vec2(-0.26, 0.38), vec2(0.26, 0.38), vec2(0.0, 0.74));
		float f1 = box(p - vec2(0.0, -0.5), vec2(0.2, 0.04));
		float f2 = box(p - vec2(0.0, -0.64), vec2(0.2, 0.04));
		return min(min(shaft, head), min(f1, f2));
	}
	if (k == 2) {
		return min(rhombus(p, vec2(0.2, 0.74)), rhombus(p, vec2(0.74, 0.2)));
	}
	if (k == 3) {
		float top = box(p - vec2(0.0, 0.2), vec2(0.42, 0.32));
		float tail = tri(p, vec2(-0.42, -0.1), vec2(0.42, -0.1), vec2(0.0, -0.7));
		float shield = min(top, tail);
		return max(shield, -(abs(shield + 0.12) - 0.05));
	}
	return min(box(p, vec2(0.16, 0.56)), box(p, vec2(0.56, 0.16)));
}
void vertex() {
	v_cls = INSTANCE_CUSTOM.x;
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float d = sign_sdf(p, int(v_cls + 0.5));
	float ring = abs(length(p) - 0.93) - 0.035;
	float aa = fwidth(length(p)) * 1.2;
	float a_sign = 1.0 - smoothstep(-aa, aa, d);
	float a_ring = 1.0 - smoothstep(-aa, aa, ring);
	ALBEDO = mix(line_color, to_linear(COLOR.rgb), a_sign);
	ALPHA = COLOR.a * max(a_sign, a_ring);
}
"

const MOTE_SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Champion VFX motes (ChampionView): small camera-facing matte diamonds, instance colour + alpha.
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void vertex() {
	float sc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc,
			MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float d = p.x + p.y;
	ALBEDO = to_linear(COLOR.rgb);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.55, 1.0, d));
}
"

static var _ring_sh: Shader
static var _glyph_sh: Shader
static var _mote_sh: Shader

var run: Run
var members: Array = []
var models: Array[RunChampion] = []
var hud: ChampionHud
var _by_id := {}
var _rings: MultiMeshInstance3D
var _glyphs: MultiMeshInstance3D
var _ring_buf := PackedFloat32Array()
var _glyph_buf := PackedFloat32Array()
var _ring_col: Array[Color] = []
var _glyph_col: Array[Color] = []
var _solids: Array = []
var _vk := PackedInt32Array()
var _marks_on := PackedByteArray()
var _ring_r := PackedFloat32Array()
var _cls_idx := PackedFloat32Array()
# Motes (parallel arrays, a ring buffer; age < 0 = still waiting for its delay).
var _motes: MultiMeshInstance3D
var _mote_buf := PackedFloat32Array()
var _m_pos := PackedVector3Array()
var _m_vel := PackedVector3Array()
var _m_age := PackedFloat32Array()
var _m_life := PackedFloat32Array()
var _m_size := PackedFloat32Array()
var _m_grav := PackedFloat32Array()
var _m_col := PackedColorArray()
var _m_next := 0
var _m_live := 0


## Builds a model per member of `p_run.champions` at its slot around the start blob.
func setup(p_run: Run) -> void:
	run = p_run
	members = run.champions.members
	for m: Dictionary in members:
		var c := RunChampion.new()
		c.name = "Champion_%s" % str(m["id"])
		add_child(c)
		c.setup(str(m["class"]), str(m["element"]))
		models.append(c)
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
	_build_marks()
	_build_motes()
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


## Per frame (Run._visuals): places, animates, vaults, draws the marks, ticks the motes.
func draw(dt: float) -> void:
	_place(dt, false)
	var st := run.state
	var running := st == Run.State.RUNNING
	var fighting := st == Run.State.CLASH or st == Run.State.SIEGE
	var cheering := st == Run.State.STAIRS or st == Run.State.WON
	for c in models:
		c.animate(dt, running, fighting, cheering)
	_vault_check()
	_draw_marks()
	_tick_motes(dt)


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


## Triangles and surfaces of all champion meshes, and the draw items this view adds (perf, §10.6).
func budget() -> Dictionary:
	var tris := 0
	var surf := 0
	for c in models:
		tris += c.triangles()
		surf += (c.body.mesh as ArrayMesh).get_surface_count()
	return {"models": models.size(), "tris": tris, "surfaces": surf, "multimeshes": 3,
			"draws_steady": surf + 2, "draws_transient": 1}


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


# ------------------------------------------------------------------ rings and glyphs

func _build_marks() -> void:
	if _ring_sh == null:
		_ring_sh = Shader.new()
		_ring_sh.code = RING_SHADER
		_glyph_sh = Shader.new()
		_glyph_sh.code = GLYPH_SHADER
		_mote_sh = Shader.new()
		_mote_sh.code = MOTE_SHADER
	var n := maxi(models.size(), 1)
	_rings = _mm_instance("Rings", _plane(2.0), _ring_sh, n, false)
	_glyphs = _mm_instance("Glyphs", _plane(1.0), _glyph_sh, n, true)
	(_glyphs.material_override as ShaderMaterial).render_priority = 1
	_ring_buf.resize(n * 16)
	_glyph_buf.resize(n * 20)


func _mm_instance(node_name: String, mesh: Mesh, sh: Shader, count: int, custom: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	add_child(mi)
	return mi


static func _plane(size: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(size, size)
	return p


## One ring (aura radius) and one glyph (just behind the feet, toward the camera) per standing
## champion; a fallen one has none (its ring shattered).
func _draw_marks() -> void:
	var n := 0
	for i in models.size():
		var c := models[i]
		if not c.alive or _marks_on[i] == 0:
			continue
		var r := _ring_r[i]
		var p := c.pos
		var o := n * 16
		_put_xf(_ring_buf, o, r, Vector3(p.x, 0.03, p.z))
		_put_col(_ring_buf, o + 12, _ring_col[i])
		var o2 := n * 20
		_put_xf(_glyph_buf, o2, GLYPH_SIZE, Vector3(p.x, 0.036, p.z + 0.3))
		_put_col(_glyph_buf, o2 + 12, _glyph_col[i])
		_glyph_buf[o2 + 16] = _cls_idx[i]
		n += 1
	_rings.multimesh.buffer = _ring_buf
	_rings.multimesh.visible_instance_count = n
	_glyphs.multimesh.buffer = _glyph_buf
	_glyphs.multimesh.visible_instance_count = n


static func _put_xf(buf: PackedFloat32Array, o: int, s: float, at: Vector3) -> void:
	buf[o] = s
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = at.x
	buf[o + 4] = 0.0
	buf[o + 5] = 1.0
	buf[o + 6] = 0.0
	buf[o + 7] = at.y
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = s
	buf[o + 11] = at.z


static func _put_col(buf: PackedFloat32Array, o: int, c: Color) -> void:
	buf[o] = c.r
	buf[o + 1] = c.g
	buf[o + 2] = c.b
	buf[o + 3] = c.a


# ------------------------------------------------------------------ motes

func _build_motes() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_motes = _mm_instance("Motes", q, _mote_sh, MOTES, false)
	_motes.visible = false
	_mote_buf.resize(MOTES * 16)
	_m_pos.resize(MOTES)
	_m_vel.resize(MOTES)
	_m_age.resize(MOTES)
	_m_life.resize(MOTES)
	_m_size.resize(MOTES)
	_m_grav.resize(MOTES)
	_m_col.resize(MOTES)
	_m_life.fill(0.0)


## One mote at `at` moving at `vel` for `life` s after `delay` s (the oldest is reused when full).
func mote(at: Vector3, vel: Vector3, life: float, size: float, col: Color, delay := 0.0, grav := 0.0) -> void:
	var i := _m_next
	_m_next = (_m_next + 1) % MOTES
	_m_pos[i] = at
	_m_vel[i] = vel
	_m_age[i] = -delay
	_m_life[i] = maxf(life, 0.02)
	_m_size[i] = size
	_m_grav[i] = grav
	_m_col[i] = col


func _tick_motes(dt: float) -> void:
	var n := 0
	for i in MOTES:
		var life := _m_life[i]
		if life <= 0.0:
			continue
		var age := _m_age[i] + dt
		_m_age[i] = age
		if age < 0.0:
			continue
		if age >= life:
			_m_life[i] = 0.0
			continue
		var v := _m_vel[i]
		v.y -= _m_grav[i] * dt
		_m_vel[i] = v
		_m_pos[i] += v * dt
		var k := age / life
		var o := n * 16
		_put_xf(_mote_buf, o, _m_size[i] * (1.0 - 0.5 * k), _m_pos[i])
		var c := _m_col[i]
		_put_col(_mote_buf, o + 12, Color(c.r, c.g, c.b, c.a * (1.0 - k * k)))
		n += 1
	if n == 0 and _m_live == 0:
		return
	_m_live = n
	_motes.visible = n > 0
	if n > 0:
		_motes.multimesh.buffer = _mote_buf
	_motes.multimesh.visible_instance_count = n


## `n` motes bursting from `at` (radial, slightly up), after `delay`.
func _burst(at: Vector3, n: int, speed: float, col: Color, size := 0.09, delay := 0.0, up := 1.0, grav := 4.0) -> void:
	for k in n:
		var a := TAU * (float(k) + randf() * 0.5) / float(n)
		var v := Vector3(cos(a), 0.0, sin(a)) * speed * randf_range(0.6, 1.0)
		v.y = up * randf_range(0.6, 1.2)
		mote(at, v, randf_range(0.35, 0.55), size, col, delay, grav)


## `n` sparkles rising from a disc of radius `r` around `at`.
func _rise(at: Vector3, n: int, r: float, col: Color, delay := 0.0) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + randf() * 0.6
		var k2 := r * randf_range(0.3, 1.0)
		var p := at + Vector3(cos(a) * k2, randf_range(0.1, 0.5), sin(a) * k2)
		mote(p, Vector3(0.0, randf_range(0.8, 1.5), 0.0), randf_range(0.45, 0.7), 0.08, col, delay + randf() * 0.12)


## A tracer of three motes flying from `from` to `to` (one arrow; matte, not a beam).
func _tracer(from: Vector3, to: Vector3, col: Color) -> void:
	var time := clampf(from.distance_to(to) / 30.0, 0.1, 0.45)
	var v := (to - from) / time
	for k in 3:
		mote(from, v, time, 0.1 - 0.02 * k, col, 0.022 * k)


# ------------------------------------------------------------------ rules' fx (ChampionKinds.FX)

## A champ_* event from the rules (Run._champ_fx): the model's pose, its VFX and the HUD.
func on_fx(event: StringName, data: Dictionary) -> void:
	var i := int(_by_id.get(str(data.get("id", "")), -1))
	var c: RunChampion = models[i] if i >= 0 else null
	match event:
		&"champ_leap":
			if c:
				var at := Vector3(float(data.get("x", c.pos.x)), 0.0, -float(data.get("d", -c.pos.z)) + 0.4)
				c.act(&"leap", at)
				_burst(at + Vector3(0.0, 0.08, 0.0), 8, 2.2, DUST, 0.1, RunChampion.impact_delay(&"leap"), 0.8, 5.0)
				Audio.play("brawl", -12.0, 0.15)
		&"champ_shot":
			if c:
				var to := Vector3(float(data.get("x", c.pos.x)), 0.55, -float(data.get("d", -c.pos.z + 6.0)))
				c.act(&"shot", to)
				var from := c.root + Vector3(-0.12, 0.85, -0.3)
				for k in maxi(int(data.get("arrows", 1)), 1):
					_tracer(from + Vector3(0.06 * k, 0.04 * k, 0.0), to + Vector3(0.12 * k, 0.0, 0.0), MARK)
				Audio.play("volley", -16.0, 0.2)
		&"champ_spell":
			if c:
				var sp := Vector3(float(data.get("x", 0.0)), 0.0, -float(data.get("d", 0.0)))
				var r := float(data.get("r", 1.5))
				c.act(&"spell", sp)
				var col: Color = _glyph_col[i]
				run.effects.telegraph_ring(sp, r, Color(col.r, col.g, col.b, 1.0), 0.6)
				_rise(sp, 8, r * 0.8, MARK, RunChampion.impact_delay(&"spell"))
				Audio.play("tesla", -15.0, 0.2)
		&"champ_block":
			if c:
				var it := run.kind_item(int(data.get("hazard", -1)))
				var hp := Vector3(c.pos.x, 0.0, c.pos.z - 1.0)
				if not it.is_empty():
					hp = Vector3(float(it.get("x0", it["x"])), 0.0, -float(it["d"]))
				c.act(&"block", hp)
				run.juice.popup(Loc.t("CHAMP_BLOCK_POP"), hp + Vector3(0.0, 1.55, 0.0), MARK, 0.85)
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
	if hud:
		hud.on_fx(event, data)


## The ring of champion `i` breaks into a few shards (the UnitFx debris pool) and is gone.
func _shatter(i: int) -> void:
	_marks_on[i] = 0
	var c := models[i]
	var r := _ring_r[i]
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		run.fx.debris(Vector3(c.pos.x + cos(a) * r, 0.1, c.pos.z + sin(a) * r), MARK, 1)
