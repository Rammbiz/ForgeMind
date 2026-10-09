class_name HeroFx
extends Node3D
## The new heroes' ult shapes and attack patterns (heroes design §6.2-6.10, §6.28, §6.29) in ONE
## MultiMesh draw, the way ChampionFx draws the champions' VFX (§10.6: + 0 draws per effect; the node
## hides itself, 0 draws, while nothing is live). Placeholders until the art pass: matte, alpha-blended,
## unshaded, no glow and nothing additive (§10.3: white-gold #FFE7A3 and the hero's element accent lifted
## toward it, never a gem hue or a saturated orange gradient).
##
## The rules talk to it through RunKindView.fx -> Run: `ult_shape` {kind, form, shape, phase start | hit |
## end, d, x, r, d0, d1, x0, x1, angle, reach, charges, s, targets} (on_shape) and `hero_attack` {pattern,
## targets, d, x, proc} (on_attack). Distances are run distances (scene z = -d), target ids Run.kind_item ids.
##
## Every primitive is one instance of a unit quad; INSTANCE_CUSTOM.x picks how SHADER draws it:
##   RING   flat thin circle on the road (custom.y = half width in quad units)
##   DISC   flat soft disc (custom.y = the hard core share)
##   MOTE   camera-facing shape (custom.y = DIAMOND ROUND STAR BLADE DOVE EYE ANCHOR FEATHER; custom.z = spin)
##   VRING  camera-facing thin circle
##   BAND   camera-facing band from one point to another (custom.y = half width, custom.z 1 = fades out
##          toward its end)
##   RECT   a quad placed by its own basis (flat on the road or standing), custom.y = its style: PLAIN,
##          GRID (frost), PARCHMENT (Сірко's scroll: abstract lines, a darker edge), RAMPART (Вартан's wall:
##          basalt below 0.3 u, faint crystal above), RAY (fades toward its far end), CHAIN (links)
##
## Gate legibility (§10.2): the shader caps every pixel whose view ray crosses a panel of the next gate
## rows at GATE_CAP alpha (gates[], refreshed each frame from Run), the gate labels draw above it (render
## priority 3 over this draw's 1, and it writes no depth), Вартан's rampart stays <= 0.6 u tall with
## alpha <= 0.5 above 0.3 u, Люмен's rays are <= 0.12 u wide, and there is no full-screen flash at all.
##
## Pool rules (ChampionFx's): POOL slots, a new primitive takes the next free slot (the oldest when all
## are busy); ages run on the run's frame time; a delay holds a primitive back unseen. The live ult shapes
## that follow the army (the comet corridor, the fan, the wall, the eyes, the frost front, the scroll) are
## drawn from their state every frame, ahead of the pool.

enum { RING, DISC, MOTE, VRING, BAND, RECT }
enum { DIAMOND, ROUND, STAR, BLADE, DOVE, EYE, ANCHOR, FEATHER }
enum { PLAIN, GRID, PARCHMENT, RAMPART, RAY, CHAIN }
enum { BALLISTIC, CURVE, STILL }

const POOL := 200
## Instances drawn from the live shapes' state each frame (fan rays, eyes, wall panels, scroll).
const SHAPE_SLOTS := 40
const STRIDE := 20
const FADE_IN := 0.05
## Seconds an anchor or a glaive falls before it lands (the drop's first pulse waits for it).
const FALL := 0.24
## Gate panels the shader checks (the next gate rows), and the alpha cap over them (§10.2.3).
const GATES := 6
const GATE_CAP := 0.35
const GATE_AHEAD := 45.0
## Gate panel height the cap covers (Models.GATE_H plus the crossbar and its label).
const GATE_TOP := 2.7

## Palette (§10.3).
const MARK := Color("#FFE7A3")
const INK := Color(0.05, 0.06, 0.12)
const STEEL := Color(0.3, 0.32, 0.4)
const DUST := Color(0.86, 0.82, 0.74)
const MEND := Color(0.86, 1.0, 0.9)
const ICE := Color(0.9, 0.96, 1.0)
const PARCH := Color(0.98, 0.93, 0.8)
const SEAL := Color(0.56, 0.2, 0.26)
## Вартан's rampart: basalt lifted a little toward the bridge's light (a black bar reads as a hole), and
## the slabs' lighter tops.
const BASALT := Color(0.44, 0.42, 0.42)
const STONE_TOP := Color(0.66, 0.64, 0.62)
const IVORY := Color(1.0, 0.98, 0.94)
## Люмен's spectrum: pastel tints lifted toward white (rose, peach, cream, mint, sky, lilac, white).
const SPECTRUM: Array[Color] = [Color("#FFC2D0"), Color("#FFD8BC"), Color("#FFF0B8"), Color("#C4F0D0"),
		Color("#BCDDFF"), Color("#DACBFF"), Color("#FFFFFF")]

const SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// HeroFx: the new heroes' ult shapes and attacks, one MultiMesh of unit quads. INSTANCE_CUSTOM.x = the
// primitive (0 ring, 1 disc, 2 mote, 3 camera ring, 4 band, 5 rect), y / z its parameters; COLOR = tint +
// alpha. Matte, no glow. Every pixel whose view ray crosses a panel of the next gate rows is capped at
// gate_cap alpha (heroes design §10.2).
uniform vec4 gates[6];
uniform float gate_z[6];
uniform float gate_cap = 0.35;
// Colours are drawn as authored (GL Compatibility writes them out as they are; no linear decode).
uniform vec3 line_color = vec3(1.0, 0.906, 0.639);
uniform vec3 ink_color = vec3(0.05, 0.06, 0.12);
varying vec4 v_c;
varying vec2 v_s;
varying vec3 v_w;

float box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float seg(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}
float fill(float d) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(-aa, aa, d);
}
// Camera-facing shapes in -1..1: 0 diamond, 1 round, 2 four-point star, 3 blade, 4 dove, 5 eye (the iris
// in the tint, the almond in white-gold, an ink pupil), 6 anchor, 7 feather.
vec4 mote(vec2 p, int k, vec3 col) {
	if (k == 1) {
		return vec4(col, 1.0 - smoothstep(0.3, 1.0, length(p)));
	}
	if (k == 2) {
		vec2 a = abs(p);
		return vec4(col, 1.0 - smoothstep(0.7, 1.0, sqrt(a.x) + sqrt(a.y)));
	}
	if (k == 3) {
		vec2 a = abs(p);
		return vec4(col, 1.0 - smoothstep(0.75, 1.0, a.x * 3.2 + a.y));
	}
	if (k == 4) {
		// A dove from below: the body, two wings swept up and out, a fan tail.
		float body = length(vec2(p.x * 2.6, p.y + 0.05)) - 0.42;
		float wl = seg(p, vec2(-0.08, 0.02), vec2(-0.88, 0.42), 0.13);
		float wr = seg(p, vec2(0.08, 0.02), vec2(0.88, 0.42), 0.13);
		float tail = box(p - vec2(0.0, -0.52), vec2(0.12 + (-0.52 - p.y) * 0.4, 0.16));
		float d = min(min(body, tail), min(wl, wr));
		return vec4(col, fill(d));
	}
	if (k == 5) {
		// An eye: an almond of two circle arcs, the iris disc, an ink pupil.
		float almond = max(length(p - vec2(0.0, -0.62)) - 0.95, length(p - vec2(0.0, 0.62)) - 0.95);
		float iris = length(p) - 0.3;
		float pupil = length(p) - 0.12;
		float a = fill(almond);
		vec3 c = mix(line_color, col, fill(iris));
		c = mix(c, ink_color, fill(pupil));
		return vec4(c, a);
	}
	if (k == 6) {
		// An anchor: the ring, the stock, the shank, the curved arms with their flukes.
		float ring = abs(length(p - vec2(0.0, 0.74)) - 0.13) - 0.05;
		float stock = box(p - vec2(0.0, 0.5), vec2(0.3, 0.05));
		float shank = box(p - vec2(0.0, -0.05), vec2(0.06, 0.6));
		float arm = max(abs(length(p - vec2(0.0, -0.1)) - 0.62) - 0.07, p.y + 0.12);
		float fl = min(length(p - vec2(-0.6, -0.12)) - 0.12, length(p - vec2(0.6, -0.12)) - 0.12);
		float d = min(min(ring, stock), min(min(shank, arm), fl));
		return vec4(col, fill(d));
	}
	if (k == 7) {
		// A feather: a slim vane along the quill.
		float vane = length(vec2(p.x * 3.4, p.y * 1.05)) - 0.92;
		float quill = box(p - vec2(0.0, -0.7), vec2(0.03, 0.3));
		return vec4(col, max(fill(vane) * 0.9, fill(quill)));
	}
	vec2 a = abs(p);
	return vec4(col, 1.0 - smoothstep(0.55, 1.0, a.x + a.y));
}

void vertex() {
	v_c = INSTANCE_CUSTOM;
	v_s = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	int mode = int(INSTANCE_CUSTOM.x + 0.5);
	if (mode == 2 || mode == 3) {
		float sx = v_s.x;
		float sy = v_s.y;
		float a = mode == 2 ? INSTANCE_CUSTOM.z : 0.0;
		vec3 rx = INV_VIEW_MATRIX[0].xyz;
		vec3 ry = INV_VIEW_MATRIX[1].xyz;
		vec3 ax = (rx * cos(a) + ry * sin(a)) * sx;
		vec3 ay = (ry * cos(a) - rx * sin(a)) * sy;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(ax, 0.0), vec4(ay, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (mode == 4) {
		vec3 axis = MODEL_MATRIX[0].xyz;
		vec3 c = MODEL_MATRIX[3].xyz;
		vec3 to_cam = INV_VIEW_MATRIX[3].xyz - c;
		vec3 side = cross(axis, to_cam);
		float sl = length(side);
		side = sl > 0.00001 ? side / sl * INSTANCE_CUSTOM.y * 2.0 : vec3(0.0, INSTANCE_CUSTOM.y * 2.0, 0.0);
		v_s = vec2(length(axis), INSTANCE_CUSTOM.y * 2.0);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(axis, 0.0), vec4(side, 0.0), vec4(normalize(to_cam), 0.0),
				MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_w = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	int mode = int(v_c.x + 0.5);
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 col = COLOR.rgb;
	float a = 0.0;
	if (mode == 0 || mode == 3) {
		float r = length(p);
		float d = abs(r - 0.955) - v_c.y;
		float aa = fwidth(r) * 1.2;
		a = 1.0 - smoothstep(-aa, aa, d);
	} else if (mode == 1) {
		a = 1.0 - smoothstep(v_c.y, 1.0, length(p));
	} else if (mode == 2) {
		vec4 m = mote(p, int(v_c.y + 0.5), col);
		col = m.rgb;
		a = m.a;
	} else if (mode == 4) {
		float across = abs(p.y);
		a = (1.0 - smoothstep(0.3, 1.0, across)) * (1.0 - smoothstep(0.88, 1.0, abs(p.x)));
		if (v_c.z > 0.5) {
			a *= mix(1.0, 0.2, clamp(p.x * 0.5 + 0.5, 0.0, 1.0));
		}
	} else {
		// RECT: p.x across, p.y along (+1 = the far end / the top); w = the point in units from the centre.
		int st = int(v_c.y + 0.5);
		vec2 w = p * v_s * 0.5;
		vec2 h = v_s * 0.5;
		float soft = max(v_c.z, 0.02);
		float ex = 1.0 - smoothstep(h.x - soft, h.x, abs(w.x));
		float ey = 1.0 - smoothstep(h.y - soft, h.y, abs(w.y));
		a = ex * ey;
		if (st == 1) {
			// Frost: a square grid racing over the floor, the lines denser than the cells.
			vec2 g = abs(fract(w * 1.6 + 0.5) - 0.5);
			float line = 1.0 - smoothstep(0.03, 0.07, min(g.x, g.y));
			a *= 0.35 + 0.65 * line;
		} else if (st == 2) {
			// Parchment: abstract lines (never text), a darker edge, the rolled-paper shading at both ends.
			float rows = abs(fract(w.y * 1.3) - 0.5);
			float words = step(0.22, fract(w.x * 0.8 + floor(w.y * 1.3) * 0.47));
			float lines = (1.0 - smoothstep(0.04, 0.08, rows)) * step(abs(w.x), h.x - 0.7) * words
					* (0.6 + 0.4 * step(0.5, fract(w.y * 0.37 + floor(w.x * 0.9) * 0.31)));
			col = mix(col, col * 0.62, lines * 0.8);
			float edge = 1.0 - smoothstep(0.12, 0.35, min(h.x - abs(w.x), h.y - abs(w.y)));
			col = mix(col, col * 0.78, edge);
		} else if (st == 3) {
			// Вартан's rampart: basalt slabs to 0.3 u under a white-gold cap line, then a faint crystal crest
			// of low teeth up to 0.6 u at alpha <= 0.42 (heroes design §10.2.4).
			float y = v_w.y;
			float k = 1.0 - smoothstep(0.285, 0.3, y);
			float jx = abs(fract(w.x / 0.55) - 0.5);
			col = mix(col, col * 0.68, (1.0 - smoothstep(0.012, 0.03, jx)) * k);
			float tooth = abs(fract(w.x / 0.42) - 0.5) * 2.0;
			float crest_top = 0.44 + 0.15 * (1.0 - tooth);
			float crest = (1.0 - k) * (1.0 - smoothstep(crest_top - 0.012, crest_top, y));
			col = mix(vec3(0.88, 0.91, 0.97), col, k);
			float cap = (1.0 - smoothstep(0.007, 0.014, abs(y - 0.283))) * step(y, 0.3);
			col = mix(col, line_color, cap);
			a *= max(max(k, cap), crest * min(0.42, COLOR.a) / max(COLOR.a, 0.01));
		} else if (st == 4) {
			a *= mix(1.0, 0.15, clamp(p.y * 0.5 + 0.5, 0.0, 1.0));
		} else if (st == 5) {
			// A chain lying across the road: oval links along its length.
			float t = fract(w.x * 2.4) - 0.5;
			float link = abs(length(vec2(t * 1.4, w.y / max(h.y, 0.01) * 0.5)) - 0.36) - 0.1;
			a *= fill(link);
		}
	}
	float alpha = COLOR.a * a;
	// Gate legibility: a pixel whose view ray crosses a panel of the next gate rows is capped.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = v_w - cam;
	for (int i = 0; i < 6; i++) {
		vec4 g = gates[i];
		if (g.w <= 0.0 || abs(ray.z) < 0.0001) {
			continue;
		}
		float t = (gate_z[i] - cam.z) / ray.z;
		if (t <= 0.0) {
			continue;
		}
		vec3 hit = cam + ray * t;
		if (hit.x > g.x && hit.x < g.y && hit.y > g.z && hit.y < g.w) {
			alpha = min(alpha, gate_cap);
		}
	}
	ALBEDO = col;
	ALPHA = alpha;
}
"

static var _shader: Shader

var run: Run
var hero_id := ""
## The hero's element accent lifted toward white-gold (ChampionView's rule), and a deeper version.
var accent := MARK
var _mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var _buf := PackedFloat32Array()
var _cap := 0
var _shown := -1
var _gate_box := PackedVector4Array()
var _gate_z := PackedFloat32Array()

# The pool (ChampionFx's layout).
var _mode := PackedByteArray()
var _motion := PackedByteArray()
var _param := PackedFloat32Array()
var _param2 := PackedFloat32Array()
var _p0 := PackedVector3Array()
var _p1 := PackedVector3Array()
var _p2 := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _ang := PackedFloat32Array()
var _fo := PackedFloat32Array()
var _col := PackedColorArray()
var _next := 0
var _live := 0

## The live ult shape drawn from state (one ult at a time): {kind, shape, t, life, end (fade-out start,
## -1 while it runs), ...its own keys}. Empty when none.
var _shape: Dictionary = {}
## Draw calls this node issued in its last frame (0 or 1; the bench reads it).
var draws := 0


## Builds the one draw for hero `p_hero` of `p_run` (its element accent from HeroData.HEROES).
func setup(p_run: Run, p_hero: String) -> void:
	run = p_run
	hero_id = p_hero
	name = "HeroFx"
	var el := str((HeroData.HEROES.get(hero_id, {}) as Dictionary).get("element", ""))
	var fam: Dictionary = ArsenalData.FAMILIES.get(el, {})
	accent = (fam.get("accent", MARK) as Color).lerp(MARK, 0.45)
	_init_pool()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_cap = POOL + SHAPE_SLOTS
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.name = "HeroFxDraw"
	_mm.multimesh = mm
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 1
	_mat.set_shader_parameter(&"gate_cap", GATE_CAP)
	_mm.material_override = _mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.extra_cull_margin = 2.0
	_mm.visible = false
	add_child(_mm)
	_buf.resize(_cap * STRIDE)
	_gate_box.resize(GATES)
	_gate_z.resize(GATES)


func _init_pool() -> void:
	_mode.resize(POOL)
	_motion.resize(POOL)
	_param.resize(POOL)
	_param2.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_s0.resize(POOL)
	_s1.resize(POOL)
	_grav.resize(POOL)
	_spin.resize(POOL)
	_ang.resize(POOL)
	_fo.resize(POOL)
	_p0.resize(POOL)
	_p1.resize(POOL)
	_p2.resize(POOL)
	_col.resize(POOL)
	_life.fill(0.0)


## Live (or waiting) pooled primitives, and whether an ult shape is drawn from state.
func active() -> int:
	return _live + (1 if not _shape.is_empty() else 0)


## Draws this node adds now (perf, §10.6): 1 while anything is live, else 0.
func budget() -> Dictionary:
	return {"draws_steady": 0, "draws_transient": 1, "pool": POOL, "shape_slots": SHAPE_SLOTS, "live": active()}


# ------------------------------------------------------------------ the rules' events

## An `ult_shape` event (RunKindView.fx): the shape's start, a hit or its end.
func on_shape(data: Dictionary) -> void:
	var ph := StringName(str(data.get("phase", "hit")))
	var kind := StringName(str(data.get("kind", "")))
	var shape := StringName(str(data.get("shape", "")))
	match kind:
		&"anchor":
			_anchor(ph, data)
		&"sunglaive":
			_sunglaive(ph, data)
		&"rime":
			_rime(ph, data)
		&"letter":
			_letter(ph, data)
		&"comet":
			_comet(ph, data)
		&"spectrum":
			_spectrum(ph, data)
		&"forgewall":
			_forgewall(ph, data)
		&"eyes":
			_eyes(ph, data)
		&"doves":
			_doves(ph, data)
		&"field":
			_field(data)
		_:
			# A kind without its own look yet: the shape's generic mark.
			match shape:
				&"drop":
					_anchor(ph, data)
				&"area":
					_rime(ph, data)
				&"beam":
					_comet(ph, data)
				&"fan":
					_spectrum(ph, data)
				&"wall":
					_forgewall(ph, data)
				&"ward":
					_eyes(ph, data)
				&"flock":
					_doves(ph, data)


## A `hero_attack` volley (Run._hero_attack): swing, beam, dart, boulder (orbs: Мейра's own path).
func on_attack(data: Dictionary) -> void:
	var pattern := StringName(str(data.get("pattern", "dart")))
	var proc := StringName(str(data.get("proc", "")))
	var from := run.hero.muzzle()
	var targets: Array = data.get("targets", [])
	if proc == &"comet" or proc == &"lance":
		# Іскар's Comet Bolt, Люмен's lance: one bright streak down the corridor to the end of the hero's range.
		var far := Vector3(from.x, 0.5, -run.d - float(run.def.get("range", 14.0)))
		band(from, far, 0.09, 0.2, Color(IVORY.r, IVORY.g, IVORY.b, 0.85), 0.0, 0.3, true)
	var k := 0
	for id: int in targets:
		var to := _target_at(id, 0.5)
		if to == Vector3.INF:
			continue
		var side := Vector3(0.14 * float(k) - 0.07 * float(targets.size() - 1), 0.0, 0.0)
		match pattern:
			&"swing":
				if k == 0:
					_slash(from)
				var t := clampf(from.distance_to(to) / 34.0, 0.08, 0.3)
				if proc == &"throw":
					curve(from, (from + to) * 0.5 + Vector3(0.0, 1.2, 0.0), to, t * 1.6, 0.42, STEEL, 0.0, ANCHOR, 14.0)
				else:
					curve(from, (from + to) * 0.5 + Vector3(0.0, 0.5, 0.0), to, t, 0.26, Color(MARK.r, MARK.g, MARK.b, 0.9),
							0.0, BLADE, 10.0)
				_spark(to, accent, t)
			&"beam":
				band(from + side, to, 0.05, 0.12, Color(_beam_col(k).r, _beam_col(k).g, _beam_col(k).b, 0.75), 0.0, 0.3)
				ring(Vector3(to.x, 0.04, to.z), 0.15, 0.45, 0.05, 0.25, Color(accent.r, accent.g, accent.b, 0.7))
				if proc == &"mend":
					_rise(run.army_view.front_point(), 5, 0.4, MEND)
			&"boulder":
				var t2 := clampf(from.distance_to(to) / 22.0, 0.12, 0.5)
				curve(from, (from + to) * 0.5 + Vector3(0.0, 1.6, 0.0), to, t2, 0.2, BASALT, 0.0, ROUND)
				ring(Vector3(to.x, 0.04, to.z), 0.2, 0.9, 0.06, 0.35, Color(DUST.r, DUST.g, DUST.b, 0.7), t2)
				_burst(to, 5, 1.4, DUST, 0.09, t2)
			_:
				var t3 := clampf(from.distance_to(to) / 34.0, 0.08, 0.32)
				var shape := FEATHER if hero_id == "pava" else DIAMOND
				if proc == &"dove" or proc == &"eye":
					shape = DOVE if proc == &"dove" else EYE
					t3 *= 1.8
					curve(from, (from + to) * 0.5 + Vector3(0.0, 2.2, 0.0), to, t3, 0.36, IVORY if proc == &"dove" else accent,
							0.0, shape)
				else:
					for j in 2:
						curve(from + side, (from + to) * 0.5 + side, to, t3, 0.14 - 0.04 * j, Color(accent.r, accent.g,
								accent.b, 0.95), 0.025 * j, shape if j == 0 else DIAMOND)
				_spark(to, accent, t3)
		k += 1
	match pattern:
		&"swing":
			Audio.play("blade", -16.0, 0.2)
		&"beam":
			Audio.play("frost" if hero_id == "eira" else "laser", -17.0, 0.25)
		&"boulder":
			Audio.play("cannon", -13.0, 0.2)
		_:
			Audio.play("arrow", -15.0, 0.25)


## A Healer hero stood a champion up again (RunKindView.revive_champion): a feather of light from the
## hero to it and a white-gold ring at its feet (ChampionView adds its own rise).
func on_revive(at: Vector3) -> void:
	var from := run.hero.muzzle()
	curve(from, (from + at) * 0.5 + Vector3(0.0, 1.4, 0.0), at + Vector3(0.0, 0.6, 0.0), 0.4, 0.22, MARK, 0.0, FEATHER)
	ring(Vector3(at.x, 0.05, at.z), 0.2, 0.75, 0.05, 0.7, Color(MARK.r, MARK.g, MARK.b, 0.85), 0.35)


# ------------------------------------------------------------------ the ult looks (§6 sheets)

## Арін's Skyfall Anchor (drop): the anchor falls from the sky on its chain, the impact ring and dust, then
## it stands planted while the chain lying across the hold area holds the squads. The rules' first pulse
## comes with the cast: its look waits until the anchor lands (FALL).
func _anchor(ph: StringName, data: Dictionary) -> void:
	var at := _ground(data, "d")
	var r := float(data.get("r", 2.5))
	match ph:
		&"start":
			_shape = {"kind": &"anchor", "t": 0.0, "life": 4.0, "pulses": 0}
			curve(at + Vector3(0.0, 7.5, 0.0), at + Vector3(0.0, 4.0, 0.0), at + Vector3(0.0, 0.85, 0.0), FALL, 1.7, STEEL,
					0.0, ANCHOR)
			band(at + Vector3(0.0, 9.0, 0.0), at + Vector3(0.0, 1.2, 0.0), 0.05, FALL + 0.35, Color(STEEL.r, STEEL.g,
					STEEL.b, 0.8), 0.0, 0.5)
			disc(Vector3(at.x, 0.03, at.z), r * 0.2, r * 0.9, FALL, Color(INK.r, INK.g, INK.b, 0.22), 0.0, 0.3, 0.9)
			Audio.play("whoosh_gate", -6.0)
		&"hit":
			var wait := _landing()
			var hold := float(run.ult.get("hold", 3.0))
			mote(at + Vector3(0.0, 0.85, 0.0), Vector3.ZERO, hold, 1.7, STEEL, wait, 0.0, ANCHOR)
			ring(Vector3(at.x, 0.04, at.z), r * 0.25, r, 0.07, 0.55, Color(MARK.r, MARK.g, MARK.b, 0.9), wait, 0.5)
			disc(Vector3(at.x, 0.03, at.z), r * 0.4, r * 1.1, 0.7, Color(DUST.r, DUST.g, DUST.b, 0.4), wait, 0.2)
			_burst(at + Vector3(0.0, 0.2, 0.0), 10, 3.0, DUST, 0.12, wait, 1.6, 6.0, BLADE)
			# The chain across the hold area (hold_width), a little in front of the anchor.
			var hw := float(run.ult.get("hold_width", 4.0))
			rect(Vector3(at.x, 0.035, at.z + 0.3), Vector3(hw, 0.0, 0.0), Vector3(0.0, 0.0, -0.3), hold,
					Color(STEEL.r, STEEL.g, STEEL.b, 0.85), CHAIN, 0.02, wait)
			_embers_on(data.get("targets", []), MARK, wait)
			run.juice.add_trauma(0.45)
			Audio.play("explosion", -3.0, 0.1)


## Веста's Sunrise (drop, pulses): the glaive falls and plants, then every pulse a white-gold ring runs out
## to the radius with five soft rays turning on the road (the first pulse waits for the glaive to land).
func _sunglaive(ph: StringName, data: Dictionary) -> void:
	var at := _ground(data, "d")
	var r := float(data.get("r", 6.0))
	match ph:
		&"start":
			_shape = {"kind": &"sunglaive", "t": 0.0, "life": 4.0, "pulses": 0}
			curve(at + Vector3(0.0, 6.0, 0.6), at + Vector3(0.0, 4.0, 0.0), at + Vector3(0.0, 0.7, 0.0), FALL, 1.1, MARK,
					0.0, BLADE, 0.0)
			mote(at + Vector3(0.0, 0.7, 0.0), Vector3.ZERO, 1.6, 1.1, MARK, FALL, 0.0, BLADE)
			Audio.play("plasma", -5.0)
		&"hit":
			var wait := _landing()
			var n := int(_shape.get("pulses", 0)) if _shape.get("kind", &"") == &"sunglaive" else 0
			if _shape.get("kind", &"") == &"sunglaive":
				_shape["pulses"] = n + 1
			var turn := 0.25 * float(n)
			ring(Vector3(at.x, 0.04, at.z), r * 0.15, r, 0.05, 0.5, Color(MARK.r, MARK.g, MARK.b, 0.85), wait, 0.45)
			for k in 5:
				var a := turn + TAU * float(k) / 5.0
				var dir := Vector3(sin(a), 0.0, -cos(a))
				rect(Vector3(at.x, 0.03, at.z) + dir * r * 0.55, Vector3(dir.z, 0.0, -dir.x) * 0.55, dir * r * 0.9, 0.45,
						Color(MARK.r, MARK.g, MARK.b, 0.42), RAY, 0.25, wait)
			_embers_on(data.get("targets", []), accent, wait)
			run.juice.add_trauma(0.3 if n == 0 else 0.16)
			Audio.play("explosion" if n == 0 else "cannon", -4.0 if n == 0 else -8.0, 0.15)


## Веста's Sun Field (form III; the rules' `field` event): a faint white-gold disc of radius `r` lies `s`
## seconds where the sunburst was.
func _field(data: Dictionary) -> void:
	if StringName(str(data.get("phase", ""))) != &"start":
		return
	var at := _ground(data, "d")
	var r := float(data.get("r", 6.0))
	disc(Vector3(at.x, 0.025, at.z), r, r, maxf(float(data.get("s", 4.0)), 0.3), Color(MARK.r, MARK.g, MARK.b, 0.12), 0.0,
			0.6, 0.85)
	ring(Vector3(at.x, 0.03, at.z), r, r, 0.04, maxf(float(data.get("s", 4.0)), 0.3), Color(MARK.r, MARK.g, MARK.b, 0.35),
			0.0, 0.85)


## Seconds until the falling anchor / glaive of the live drop lands (0 once it has).
func _landing() -> float:
	if _shape.get("kind", &"") != &"anchor" and _shape.get("kind", &"") != &"sunglaive":
		return 0.0
	return maxf(FALL - float(_shape.get("t", FALL)), 0.0)


## Ейра's Winter Litany (area, sweep): a frost front runs from `d0` to `d1` across the bridge in `s`
## seconds, a square grid of rime races behind it; the army's returning soldiers rise at its front.
func _rime(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"rime", "shape": &"area", "t": 0.0, "life": maxf(float(data.get("s", 0.6)), 0.05) + 1.2,
					"sweep": maxf(float(data.get("s", 0.6)), 0.05), "d0": float(data.get("d0", run.d)),
					"d1": float(data.get("d1", run.d + 14.0)), "end": -1.0}
			Audio.play("frost", -4.0)
		&"hit":
			for id: int in data.get("targets", []):
				var p := _target_at(id, 0.3)
				if p != Vector3.INF:
					_rise(p, 4, 0.5, ICE, 0.0, STAR)
			_rise(run.army_view.front_point(), 8, 0.6, MEND, 0.1)
			run.juice.add_trauma(0.2)
		&"end":
			_close(&"rime")


## Сірко's Cossack Reply (area): the parchment unrolls over the lane from `d0` to `d1`, the full bridge
## wide, a wax seal at its near edge (abstract lines only; never text); every hit is a roar of laughter.
func _letter(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"letter", "shape": &"area", "t": 0.0, "life": _span(data, 2.0) + 0.5,
					"d0": float(data.get("d0", run.d + 3.0)), "d1": float(data.get("d1", run.d + 15.0)), "end": -1.0}
			Audio.play("upgrade", -4.0)
			Audio.play("whoosh_gate", -8.0)
		&"hit":
			for id: int in data.get("targets", []):
				var p := _target_at(id, 1.1)
				if p != Vector3.INF:
					_burst(p, 4, 1.2, MARK, 0.1, 0.0, 1.4, 2.0, STAR)
			var h := run.hero.muzzle()
			vring(h + Vector3(0.0, 0.3, 0.0), 0.3, 1.4, 0.05, 0.45, Color(MARK.r, MARK.g, MARK.b, 0.8))
			run.juice.add_trauma(0.3)
			Audio.play("brawl", -6.0, 0.1)
		&"end":
			_close(&"letter")


## Іскар's Comet Fall (beam): a corridor `x0`..`x1` wide down the road from `d0` to `d1` (relative to the
## hero, so it runs with the army), a comet streaking down it every tick and a thin sky-to-road strike on
## every target.
func _comet(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"comet", "shape": &"beam", "t": 0.0, "life": _span(data, 1.5) + 0.5, "end": -1.0,
					"from": float(data.get("d0", run.d + 2.0)) - run.d, "to": float(data.get("d1", run.d + 30.0)) - run.d,
					"x": (float(data.get("x0", run.hx - 0.8)) + float(data.get("x1", run.hx + 0.8))) * 0.5,
					"w": absf(float(data.get("x1", 0.8)) - float(data.get("x0", -0.8)))}
			var x := float(_shape["x"])
			band(Vector3(x, 9.0, -run.d - 6.0), Vector3(x, 0.2, -run.d - 2.0), 0.1, 0.3, Color(accent.r, accent.g, accent.b,
					0.8), 0.0, 0.3, true)
			Audio.play("tesla", -3.0)
		&"hit":
			if _shape.get("kind", &"") != &"comet":
				return
			if data.has("x0") and data.has("x1"):
				_shape["x"] = (float(data["x0"]) + float(data["x1"])) * 0.5
			var x2 := float(_shape["x"])
			var near := Vector3(x2, 0.35, -run.d - float(_shape["from"]))
			var far := Vector3(x2, 0.35, -run.d - float(_shape["to"]))
			curve(near, near.lerp(far, 0.5) + Vector3(0.0, 0.2, 0.0), far, 0.24, 0.42, IVORY, 0.0, STAR)
			for id: int in data.get("targets", []):
				var p := _target_at(id, 0.4)
				if p != Vector3.INF:
					band(p + Vector3(0.0, 6.5, 0.0), p, 0.05, 0.16, Color(IVORY.r, IVORY.g, IVORY.b, 0.85), 0.0, 0.3)
					_spark(p, accent, 0.0)
			Audio.play("laser", -12.0, 0.2)
		&"end":
			_close(&"comet")


## Люмен's Spectral Crown (fan): `charges` thin pastel rays (<= 0.12 u) over `angle` degrees from its prism,
## `reach` long, flickering every frame; sparks on the targets of each tick; form IV's crown shards fall at
## the end.
func _spectrum(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"spectrum", "shape": &"fan", "t": 0.0, "life": _span(data, 2.5) + 0.5, "end": -1.0,
					"angle": float(data.get("angle", 60.0)), "reach": float(data.get("reach", 16.0)),
					"rays": clampi(int(data.get("charges", run.ult.get("rays", 7))), 1, 11)}
			vring(run.hero.muzzle() + Vector3(0.0, 0.35, 0.0), 0.2, 0.6, 0.06, 0.5, Color(MARK.r, MARK.g, MARK.b, 0.85))
			Audio.play("laser", -4.0)
		&"hit":
			# Form IV's crown shards fall at the close on the biggest hostiles (a hit over the whole screen).
			var shards := float(data.get("reach", 0.0)) > float(_shape.get("reach", 16.0)) + 1.0
			var k := 0
			for id: int in data.get("targets", []):
				var p := _target_at(id, 0.5)
				if p == Vector3.INF:
					continue
				if shards:
					curve(p + Vector3(randf_range(-0.6, 0.6), 4.0, 0.4), p + Vector3(0.0, 2.0, 0.0), p, 0.35, 0.2, IVORY,
							randf() * 0.15, STAR)
				else:
					_spark(p, SPECTRUM[k % SPECTRUM.size()], 0.0)
				k += 1
			Audio.play("laser", -16.0, 0.3)
		&"end":
			for id: int in data.get("targets", []):
				var p2 := _target_at(id, 0.4)
				if p2 != Vector3.INF:
					curve(p2 + Vector3(randf_range(-0.6, 0.6), 4.0, 0.4), p2 + Vector3(0.0, 2.0, 0.0), p2, 0.35, 0.2, IVORY,
							randf() * 0.15, STAR)
			_close(&"spectrum")


## Вартан's Forgewall (wall): a knee-high rampart `x0`..`x1` wide that rises `d0 - d` ahead and travels
## with the army for `s` seconds (basalt to 0.3 u, faint crystal to 0.6 u: §10.2.4); sparks where squads
## and shots meet it; at the end it drops (form IV: it topples forward as a landslide).
func _forgewall(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"forgewall", "shape": &"wall", "t": 0.0, "life": _span(data, 5.0) + 0.35, "end": -1.0,
					"ahead": float(data.get("d", data.get("d0", run.d + 3.0))) - run.d,
					"x": (float(data.get("x0", run.hx - 3.0)) + float(data.get("x1", run.hx + 3.0))) * 0.5,
					"w": absf(float(data.get("x1", 3.0)) - float(data.get("x0", -3.0)))}
			var c := _wall_center()
			_burst(c + Vector3(0.0, 0.1, 0.0), 10, 2.0, DUST, 0.12, 0.0, 1.2, 5.0, BLADE)
			run.juice.add_trauma(0.35)
			Audio.play("build", -3.0)
		&"hit":
			if _shape.get("kind", &"") != &"forgewall":
				return
			for id: int in data.get("targets", []):
				var p := _target_at(id, 0.35)
				if p != Vector3.INF:
					var c2 := _wall_center()
					_spark(Vector3(p.x, 0.35, c2.z - 0.05), MARK, 0.0)
		&"end":
			if _shape.get("kind", &"") == &"forgewall" and int(data.get("form", 1)) >= 4:
				var c3 := _wall_center()
				for k in 5:
					var off := Vector3(randf_range(-2.4, 2.4), 0.03, -randf_range(0.5, 9.0))
					disc(c3 + off, 0.3, 1.1, 0.8, Color(DUST.r, DUST.g, DUST.b, 0.45), 0.06 * k, 0.2)
				_burst(c3 + Vector3(0.0, 0.3, -1.0), 12, 3.4, BASALT, 0.14, 0.0, 1.0, 7.0, BLADE)
			_close(&"forgewall")


## Пава's Thousand Eyes (ward): her fan of eyes opens behind her in a wave and stays `s` seconds, the
## squads in `reach` are Branded (a rune ring each); at the close the eyes shut and the recorded soldiers
## rise back at the army front (form IV: eyes open over every squad hit).
func _eyes(ph: StringName, data: Dictionary) -> void:
	match ph:
		&"start":
			_shape = {"kind": &"eyes", "shape": &"ward", "t": 0.0, "life": _span(data, 3.0) + 0.4, "end": -1.0}
			var reach := float(data.get("reach", 16.0))
			for sq: Dictionary in run.kind_view.squads_in(run.d - 0.5, run.d + reach, -99.0, 99.0):
				ring(Vector3(float(sq["x"]), 0.05, -float(sq["d"])), 0.4, 1.1, 0.05, 0.8, Color(accent.r, accent.g,
						accent.b, 0.75), 0.05)
			Audio.play("upgrade", -5.0)
		&"hit":
			for id: int in data.get("targets", []):
				var p := _target_at(id, 0.9)
				if p != Vector3.INF:
					mote(p, Vector3(0.0, 0.3, 0.0), 0.8, 0.42, accent, 0.0, 0.0, EYE)
		&"end":
			for id: int in data.get("targets", []):
				var p2 := _target_at(id, 0.9)
				if p2 != Vector3.INF:
					mote(p2, Vector3(0.0, 0.3, 0.0), 0.8, 0.42, accent, 0.0, 0.0, EYE)
			_rise(run.army_view.front_point(), 10, 0.7, MEND, 0.05)
			Audio.play("recruit", -8.0)
			_close(&"eyes")


## Ольга's Fly Home (flock): every wave a dove flies from her over the squads to each struck structure or
## gate (an arc, never landing on the bridge), embers where it lands.
func _doves(ph: StringName, data: Dictionary) -> void:
	var from := run.hero.muzzle() + Vector3(0.0, 0.35, 0.0)
	match ph:
		&"start":
			for k in 8:
				var a := -1.0 + 2.0 * float(k) / 7.0
				mote(from, Vector3(sin(a) * 2.4, 2.4 + randf() * 0.8, -1.6), 0.7, 0.55, IVORY, 0.03 * k, -1.0, DOVE)
			Audio.play("whoosh_gate", -4.0)
		&"hit":
			var k2 := 0
			for id: int in data.get("targets", []):
				var to := _target_at(id, 0.7)
				if to == Vector3.INF:
					continue
				var t := clampf(from.distance_to(to) / 22.0, 0.35, 0.9)
				for j2 in 2:
					var ctrl := (from + to) * 0.5 + Vector3(randf_range(-1.4, 1.4), 3.0 + 0.6 * float(j2), 0.0)
					curve(from, ctrl, to + Vector3(0.0, 0.3 * float(j2), 0.0), t, 0.6 - 0.12 * float(j2), IVORY,
							0.02 * k2 + 0.08 * float(j2), DOVE)
				for j in 3:
					mote(to + Vector3(randf_range(-0.3, 0.3), 0.2, 0.0), Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.2),
							0.0), 0.6, 0.1, accent, t + 0.05 * j, -0.3, ROUND)
				ring(Vector3(to.x, 0.04, to.z), 0.2, 0.8, 0.05, 0.4, Color(MARK.r, MARK.g, MARK.b, 0.75), t)
				k2 += 1
			Audio.play("plasma", -10.0, 0.2)


## How long a lasting shape stays when its `end` never comes: the event's `s`, else the ult's `duration`,
## else `fallback` seconds.
func _span(data: Dictionary, fallback: float) -> float:
	var s := float(data.get("s", 0.0))
	if s <= 0.0:
		s = float(run.ult.get("duration", fallback))
	return maxf(s, 0.3)


## Ends the live shape `kind` with a short fade (no-op when another shape is live).
func _close(kind: StringName) -> void:
	if _shape.get("kind", &"") == kind and float(_shape.get("end", -1.0)) < 0.0:
		_shape["end"] = float(_shape["t"])


# ------------------------------------------------------------------ per frame

## Ticks the pool and the live shape by `dt` (the run's frame time) and fills the one draw.
func draw(dt: float) -> void:
	_tick(dt)
	var n := 0
	n = _write_shape(dt, n)
	n = _write_pool(n, true)
	n = _write_pool(n, false)
	draws = 1 if n > 0 else 0
	if n == 0 and _shown == 0:
		return
	_shown = n
	_mm.visible = n > 0
	var mm := _mm.multimesh
	if n > 0:
		_update_gates()
		mm.custom_aabb = _bounds(n)
		mm.buffer = _buf
	mm.visible_instance_count = n


## The next gate rows' panels for the shader's cap: [x0, x1, y0, y1] per gate and its plane z.
func _update_gates() -> void:
	var k := 0
	var rows := 0
	var last_row := -999
	for g: Dictionary in run._gates:
		if k >= GATES:
			break
		var gd := float(g["d"])
		if gd < run.d - 0.5 or not g.get("alive", false):
			continue
		if gd > run.d + GATE_AHEAD:
			break
		var row := int(g.get("row", -1))
		if row != last_row:
			rows += 1
			last_row = row
			if rows > 2:
				break
		var hw := float(g.get("w", 2.0)) * 0.5
		_gate_box[k] = Vector4(float(g["x"]) - hw, float(g["x"]) + hw, 0.0, GATE_TOP)
		_gate_z[k] = -gd
		k += 1
	for j in range(k, GATES):
		_gate_box[j] = Vector4.ZERO
		_gate_z[j] = 0.0
	_mat.set_shader_parameter(&"gates", _gate_box)
	_mat.set_shader_parameter(&"gate_z", _gate_z)


func _tick(dt: float) -> void:
	if not _shape.is_empty():
		_shape["t"] = float(_shape.get("t", 0.0)) + dt
		var end := float(_shape.get("end", -1.0))
		if float(_shape["t"]) >= float(_shape.get("life", 9.0)) or (end >= 0.0 and float(_shape["t"]) - end > 0.3):
			_shape = {}
	if _live == 0:
		return
	for i in POOL:
		var life := _life[i]
		if life <= 0.0:
			continue
		var age := _age[i] + dt
		_age[i] = age
		if age < 0.0:
			continue
		if age >= life:
			_life[i] = 0.0
			_live -= 1
			continue
		if _spin[i] != 0.0:
			_ang[i] += _spin[i] * dt
		if _motion[i] == BALLISTIC:
			var v := _p1[i]
			v.y -= _grav[i] * dt
			_p1[i] = v
			_p0[i] += v * dt


## The live shape's instances (drawn from state, so they follow the army); returns the next instance.
func _write_shape(_dt: float, n: int) -> int:
	if _shape.is_empty() or not _shape.has("shape"):
		return n
	var t := float(_shape["t"])
	var end := float(_shape.get("end", -1.0))
	var fade := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.0, 0.3, t - end) if end >= 0.0 else 1.0)
	var cap := n + SHAPE_SLOTS
	match StringName(str(_shape["kind"])):
		&"comet":
			var x := float(_shape["x"])
			var w := float(_shape["w"])
			var d0 := run.d + float(_shape["from"])
			var d1 := run.d + float(_shape["to"])
			var c := Vector3(x, 0.03, -(d0 + d1) * 0.5)
			n = _put_rect(n, c, Vector3(w, 0.0, 0.0), Vector3(0.0, 0.0, -(d1 - d0)), Color(accent.r, accent.g, accent.b,
					0.3 * fade), PLAIN, 0.25)
			n = _put_rect(n, c + Vector3(0.0, 0.005, 0.0), Vector3(0.16, 0.0, 0.0), Vector3(0.0, 0.0, -(d1 - d0)),
					Color(IVORY.r, IVORY.g, IVORY.b, 0.75 * fade), RAY, 0.05)
		&"spectrum":
			var o := run.hero.muzzle() + Vector3(0.0, 0.2, -0.2)
			var rays := int(_shape["rays"])
			var half := deg_to_rad(float(_shape["angle"]) * 0.5)
			var reach := float(_shape["reach"])
			for k in rays:
				if n >= cap:
					break
				var a := -half + 2.0 * half * (float(k) / maxf(float(rays - 1), 1.0))
				var far := Vector3(o.x + sin(a) * reach, 0.25, o.z - cos(a) * reach)
				far.x = clampf(far.x, -Balance.BRIDGE_HALF - 1.0, Balance.BRIDGE_HALF + 1.0)
				var flick := 0.8 + 0.2 * sin(t * 23.0 + float(k) * 1.7)
				var col: Color = SPECTRUM[k % SPECTRUM.size()]
				n = _put_band(n, o, far, 0.1, Color(col.r, col.g, col.b, 0.85 * fade * flick), true)
		&"forgewall":
			var c2 := _wall_center()
			var w2 := float(_shape["w"])
			var rise := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.0, 0.3, t - end) if end >= 0.0 else 1.0)
			var h := 0.6 * rise
			if h > 0.01:
				# A low ground shadow, the slab face with its crystal crest (one standing quad: the shader splits it
				# at 0.3 u) and the lighter top of the slabs, so it reads as a rampart from the camera's height.
				n = _put_rect(n, Vector3(c2.x, 0.02, c2.z + 0.25), Vector3(w2 + 0.3, 0.0, 0.0), Vector3(0.0, 0.0, -0.9),
						Color(INK.r, INK.g, INK.b, 0.22 * rise), PLAIN, 0.3)
				n = _put_rect(n, Vector3(c2.x, h * 0.5, c2.z), Vector3(w2, 0.0, 0.0), Vector3(0.0, h, 0.0),
						Color(BASALT.r, BASALT.g, BASALT.b, 0.95), RAMPART, 0.03)
				var top := minf(h, 0.295)
				n = _put_rect(n, Vector3(c2.x, top, c2.z - 0.17), Vector3(w2, 0.0, 0.0), Vector3(0.0, 0.0, -0.34),
						Color(STONE_TOP.r, STONE_TOP.g, STONE_TOP.b, 0.95), PLAIN, 0.03)
		&"eyes":
			var hp := run.hero.global_position + Vector3(0.0, 1.05, 0.35)
			var open := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(0.0, 0.3, t - end) if end >= 0.0 else 1.0)
			var eyes := 11
			for k2 in eyes:
				if n >= cap:
					break
				var u := float(k2) / float(eyes - 1)
				var a2 := lerpf(-1.25, 1.25, u)
				var blink := smoothstep(0.0, 0.25, t - absf(u - 0.5) * 0.4)
				var s := 0.42 * open * blink
				if s < 0.01:
					continue
				var p := hp + Vector3(sin(a2) * 1.15, cos(a2) * 0.9, 0.0)
				n = _put_mote(n, p, s, Color(accent.r, accent.g, accent.b, 0.9), EYE, 0.0)
			n = _put_vring(n, hp + Vector3(0.0, -0.15, 0.0), 1.3 * open, 0.04, Color(MARK.r, MARK.g, MARK.b, 0.55 * open))
		&"rime":
			var sweep := float(_shape["sweep"])
			var d0r := float(_shape["d0"])
			var d1r := float(_shape["d1"])
			var k3 := clampf(t / sweep, 0.0, 1.0)
			var front := lerpf(d0r, d1r, k3)
			var gone := smoothstep(sweep, sweep + 0.9, t)
			var span := front - d0r
			if span > 0.1:
				n = _put_rect(n, Vector3(0.0, 0.03, -(d0r + front) * 0.5), Vector3(Balance.BRIDGE_HALF * 2.0, 0.0, 0.0),
						Vector3(0.0, 0.0, -span), Color(ICE.r, ICE.g, ICE.b, 0.5 * (1.0 - gone) * fade), GRID, 0.3)
			if k3 < 1.0:
				n = _put_rect(n, Vector3(0.0, 0.04, -front), Vector3(Balance.BRIDGE_HALF * 2.0, 0.0, 0.0),
						Vector3(0.0, 0.0, -1.0), Color(IVORY.r, IVORY.g, IVORY.b, 0.55 * fade), PLAIN, 0.45)
		&"letter":
			var d0l := float(_shape["d0"])
			var d1l := float(_shape["d1"])
			var unroll := smoothstep(0.0, 0.35, t)
			var far2 := lerpf(d0l + 0.5, d1l, unroll)
			var len2 := far2 - d0l
			var wl := Balance.BRIDGE_HALF * 2.0 - 0.4
			n = _put_rect(n, Vector3(0.0, 0.05, -(d0l + far2) * 0.5), Vector3(wl, 0.0, 0.0), Vector3(0.0, 0.0, -len2),
					Color(PARCH.r, PARCH.g, PARCH.b, 0.62 * fade), PARCHMENT, 0.08)
			# The rolled end and the wax seal.
			n = _put_band(n, Vector3(-wl * 0.5, 0.16, -far2), Vector3(wl * 0.5, 0.16, -far2), 0.14,
					Color(PARCH.r * 0.85, PARCH.g * 0.85, PARCH.b * 0.85, 0.6 * fade), false)
			n = _put_disc(n, Vector3(0.0, 0.06, -far2 + 0.75), 0.36, Color(SEAL.r, SEAL.g, SEAL.b, 0.85 * fade), 0.75)
	return n


## The wall's centre now: `ahead` u in front of the hero, at its cast x.
func _wall_center() -> Vector3:
	return Vector3(float(_shape.get("x", run.hx)), 0.0, -run.d - float(_shape.get("ahead", 3.0)))


## Writes the live pooled primitives of one layer (`flat`: on the road, else above it) from instance `n`.
func _write_pool(n: int, flat: bool) -> int:
	if _live == 0:
		return n
	for i in POOL:
		if n >= _cap:
			break
		if _life[i] <= 0.0 or _age[i] < 0.0:
			continue
		var mode := int(_mode[i])
		var is_flat := mode == RING or mode == DISC or (mode == RECT and _p1[i].y == 0.0 and _p2[i].y == 0.0)
		if is_flat != flat:
			continue
		var k := _age[i] / _life[i]
		var c := _col[i]
		c.a *= smoothstep(0.0, FADE_IN, _age[i]) * (1.0 - smoothstep(_fo[i], 1.0, k))
		var o := n * STRIDE
		var grow := 1.0 - (1.0 - k) * (1.0 - k)
		var s := lerpf(_s0[i], _s1[i], grow)
		match mode:
			RING:
				put_flat(_buf, o, _p0[i], s * 2.0)
				put_tail(_buf, o, c, RING, 0.5 * _param[i] / maxf(s, 0.01))
			DISC:
				put_flat(_buf, o, _p0[i], s * 2.0)
				put_tail(_buf, o, c, DISC, _param[i])
			VRING:
				put_face(_buf, o, _p0[i], s * 2.0, s * 2.0)
				put_tail(_buf, o, c, VRING, 0.5 * _param[i] / maxf(s, 0.01))
			BAND:
				put_band(_buf, o, _p0[i], _p2[i], _param[i])
				put_tail(_buf, o, c, BAND, _param[i] * 0.5, _param2[i])
			RECT:
				put_rect(_buf, o, _p0[i], _p1[i], _p2[i])
				put_tail(_buf, o, c, RECT, _param[i], _param2[i])
			_:
				var at := _p0[i]
				if _motion[i] == CURVE:
					var u := 1.0 - k
					at = _p0[i] * (u * u) + _p1[i] * (2.0 * u * k) + _p2[i] * (k * k)
				put_face(_buf, o, at, s, s)
				put_tail(_buf, o, c, MOTE, _param[i], _ang[i])
		n += 1
	return n


func _put_rect(n: int, at: Vector3, ax: Vector3, ay: Vector3, col: Color, style: int, soft: float) -> int:
	if n >= _cap:
		return n
	var o := n * STRIDE
	put_rect(_buf, o, at, ax, ay)
	put_tail(_buf, o, col, RECT, float(style), soft)
	return n + 1


func _put_band(n: int, a: Vector3, b: Vector3, width: float, col: Color, taper: bool) -> int:
	if n >= _cap:
		return n
	var o := n * STRIDE
	put_band(_buf, o, a, b, width)
	put_tail(_buf, o, col, BAND, width * 0.5, 1.0 if taper else 0.0)
	return n + 1


func _put_mote(n: int, at: Vector3, size: float, col: Color, shape: int, spin: float) -> int:
	if n >= _cap:
		return n
	var o := n * STRIDE
	put_face(_buf, o, at, size, size)
	put_tail(_buf, o, col, MOTE, float(shape), spin)
	return n + 1


func _put_vring(n: int, at: Vector3, r: float, width: float, col: Color) -> int:
	if n >= _cap or r <= 0.01:
		return n
	var o := n * STRIDE
	put_face(_buf, o, at, r * 2.0, r * 2.0)
	put_tail(_buf, o, col, VRING, 0.5 * width / r)
	return n + 1


func _put_disc(n: int, at: Vector3, r: float, col: Color, core: float) -> int:
	if n >= _cap:
		return n
	var o := n * STRIDE
	put_flat(_buf, o, at, r * 2.0)
	put_tail(_buf, o, col, DISC, core)
	return n + 1


## The box around the first `n` instances (as ChampionView._bounds).
func _bounds(n: int) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var big := 0.0
	for k in n:
		var o := k * STRIDE
		var p := Vector3(_buf[o + 3], _buf[o + 7], _buf[o + 11])
		lo = lo.min(p)
		hi = hi.max(p)
		big = maxf(big, maxf(absf(_buf[o]) + absf(_buf[o + 4]) + absf(_buf[o + 8]),
				absf(_buf[o + 1]) + absf(_buf[o + 5]) + absf(_buf[o + 9])))
	var pad := Vector3.ONE * (big * 0.5 + 0.2)
	return AABB(lo - pad, hi - lo + pad * 2.0)


# ------------------------------------------------------------------ spawning (the pool)

## A camera-facing mote at `at` moving at `vel` (gravity `grav`), spun `spin` rad/s; it shrinks to 70 % of
## `size` and fades over `life` after `delay`.
func mote(at: Vector3, vel: Vector3, life: float, size: float, col: Color, delay := 0.0, grav := 0.0, shape := DIAMOND,
		spin := 0.0) -> void:
	var i := _take(MOTE, BALLISTIC, life, delay, col, 0.6)
	_p0[i] = at
	_p1[i] = vel
	_s0[i] = size
	_s1[i] = size * 0.7
	_grav[i] = grav
	_spin[i] = spin
	_param[i] = float(shape)
	_ang[i] = 0.0


## A mote flying a curve from `from` through the pull of `ctrl` to `to` in `life` after `delay`; it keeps
## `size` and fades only in the last 15 %.
func curve(from: Vector3, ctrl: Vector3, to: Vector3, life: float, size: float, col: Color, delay := 0.0, shape := DIAMOND,
		spin := 0.0) -> void:
	var i := _take(MOTE, CURVE, life, delay, col, 0.85)
	_p0[i] = from
	_p1[i] = ctrl
	_p2[i] = to
	_s0[i] = size
	_s1[i] = size
	_spin[i] = spin
	_param[i] = float(shape)


## A thin circle flat on the road at `at`, growing from radius `r0` to `r1`, `width` u wide.
func ring(at: Vector3, r0: float, r1: float, width: float, life: float, col: Color, delay := 0.0, fo := 0.45) -> void:
	var i := _take(RING, STILL, life, delay, col, fo)
	_p0[i] = at
	_s0[i] = r0
	_s1[i] = r1
	_param[i] = width


## A soft disc flat on the road (radius r0 -> r1); `core` = the share of the radius at full alpha.
func disc(at: Vector3, r0: float, r1: float, life: float, col: Color, delay := 0.0, core := 0.0, fo := 0.5) -> void:
	var i := _take(DISC, STILL, life, delay, col, fo)
	_p0[i] = at
	_s0[i] = r0
	_s1[i] = r1
	_param[i] = core


## A thin circle facing the camera at `at` (radius r0 -> r1).
func vring(at: Vector3, r0: float, r1: float, width: float, life: float, col: Color, delay := 0.0) -> void:
	var i := _take(VRING, STILL, life, delay, col, 0.4)
	_p0[i] = at
	_s0[i] = r0
	_s1[i] = r1
	_param[i] = width


## A band facing the camera from `a` to `b`, `width` u wide (`taper`: it fades toward `b`).
func band(a: Vector3, b: Vector3, width: float, life: float, col: Color, delay := 0.0, fo := 0.3, taper := false) -> void:
	var i := _take(BAND, STILL, life, delay, col, fo)
	_p0[i] = a
	_p2[i] = b
	_param[i] = width
	_param2[i] = 1.0 if taper else 0.0
	_s0[i] = 1.0
	_s1[i] = 1.0


## A quad centred at `at` spanning `ax` across and `ay` along (flat when both lie in the road plane), in
## `style` with edges `soft` u wide, after `delay`.
func rect(at: Vector3, ax: Vector3, ay: Vector3, life: float, col: Color, style := PLAIN, soft := 0.1,
		delay := 0.0) -> void:
	var i := _take(RECT, STILL, life, delay, col, 0.6)
	_p0[i] = at
	_p1[i] = ax
	_p2[i] = ay
	_param[i] = float(style)
	_param2[i] = soft
	_s0[i] = 1.0
	_s1[i] = 1.0


func _take(mode: int, motion: int, life: float, delay: float, col: Color, fo: float) -> int:
	var i := _next
	for k in POOL:
		var j := (_next + k) % POOL
		if _life[j] <= 0.0:
			i = j
			break
	_next = (i + 1) % POOL
	if _life[i] <= 0.0:
		_live += 1
	_mode[i] = mode
	_motion[i] = motion
	_life[i] = maxf(life, 0.02)
	_age[i] = -delay
	_col[i] = col
	_fo[i] = fo
	_grav[i] = 0.0
	_spin[i] = 0.0
	_ang[i] = 0.0
	_param2[i] = 0.0
	return i


# ------------------------------------------------------------------ small looks

## A crescent slash in front of the hero (a swing): three short bands bent into an arc.
func _slash(from: Vector3) -> void:
	var c := from + Vector3(0.0, -0.1, -0.55)
	var prev := c + Vector3(-0.55, 0.25, 0.1)
	for k in 3:
		var a := -0.9 + 0.9 * float(k + 1)
		var nxt := c + Vector3(sin(a) * 0.6, 0.25 - absf(sin(a)) * 0.35, -cos(a) * 0.2 + 0.1)
		band(prev, nxt, 0.07, 0.14, Color(MARK.r, MARK.g, MARK.b, 0.85 - 0.15 * k), 0.012 * k, 0.4)
		prev = nxt


## A small hit: a ring on the road and three sparks, `delay` s after now.
func _spark(at: Vector3, col: Color, delay: float) -> void:
	ring(Vector3(at.x, 0.04, at.z), 0.1, 0.5, 0.05, 0.28, Color(col.r, col.g, col.b, 0.8), delay)
	_burst(at, 3, 1.6, col, 0.08, delay, 1.2, 4.0)


## `n` motes bursting from `at` (radial, slightly up), after `delay`.
func _burst(at: Vector3, n: int, speed: float, col: Color, size := 0.09, delay := 0.0, up := 1.0, grav := 4.0,
		shape := DIAMOND) -> void:
	for k in n:
		var a := TAU * (float(k) + randf() * 0.5) / float(n)
		var v := Vector3(cos(a), 0.0, sin(a)) * speed * randf_range(0.6, 1.0)
		v.y = up * randf_range(0.6, 1.2)
		mote(at, v, randf_range(0.35, 0.55), size, col, delay, grav, shape, randf_range(-6.0, 6.0) if shape == BLADE else 0.0)


## `n` sparkles rising from a disc of radius `r` around `at`.
func _rise(at: Vector3, n: int, r: float, col: Color, delay := 0.0, shape := DIAMOND) -> void:
	for k in n:
		var a := TAU * float(k) / float(n) + randf() * 0.6
		var k2 := r * randf_range(0.3, 1.0)
		var p := at + Vector3(cos(a) * k2, randf_range(0.1, 0.5), sin(a) * k2)
		mote(p, Vector3(0.0, randf_range(0.8, 1.5), 0.0), randf_range(0.45, 0.7), 0.1, col, delay + randf() * 0.12, 0.0,
				shape)


## Matte embers over every target id in `ids` (Burn), in `col`, after `delay`.
func _embers_on(ids: Array, col: Color, delay := 0.0) -> void:
	for id: int in ids:
		var p := _target_at(id, 0.3)
		if p == Vector3.INF:
			continue
		for k in 2:
			mote(p + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.2, 0.2)), Vector3(0.0, randf_range(0.7, 1.2), 0.0),
					0.6, 0.1, col, delay + randf() * 0.2, -0.3, ROUND)


## Where the shape event sits on the road: (x, 0, -data[key]) (the hero's x and d when missing).
func _ground(data: Dictionary, key: String) -> Vector3:
	return Vector3(float(data.get("x", run.hx)), 0.0, -float(data.get(key, data.get("d", run.d))))


## World point of target `id` at height `y` (a squad's front, a structure, a gate); INF when unknown.
func _target_at(id: int, y: float) -> Vector3:
	var it := run.kind_item(id)
	if it.is_empty():
		return Vector3.INF
	var x := float(it.get("x", 0.0))
	if str(it.get("kind", "")) == "squad" and it.get("alive", false):
		var sp := run.hazards.squad_point(it)
		return Vector3(sp.x, y, sp.z)
	return Vector3(x, y, -float(it["d"]))


func _beam_col(k: int) -> Color:
	if hero_id == "lumen":
		return SPECTRUM[(k * 3) % SPECTRUM.size()]
	return ICE if hero_id == "eira" else accent


# ------------------------------------------------------------------ instance layout (MultiMesh TRANSFORM_3D)

## A quad lying flat on the road at `at`, `size` u across.
static func put_flat(buf: PackedFloat32Array, o: int, at: Vector3, size: float) -> void:
	put_rect(buf, o, at, Vector3(size, 0.0, 0.0), Vector3(0.0, 0.0, -size))


## A camera-facing quad at `at`, `w` x `h` u (the shader turns it to the camera).
static func put_face(buf: PackedFloat32Array, o: int, at: Vector3, w: float, h: float) -> void:
	buf[o] = w
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = at.x
	buf[o + 4] = 0.0
	buf[o + 5] = h
	buf[o + 6] = 0.0
	buf[o + 7] = at.y
	buf[o + 8] = 0.0
	buf[o + 9] = 0.0
	buf[o + 10] = maxf(w, h)
	buf[o + 11] = at.z


## A band from `a` to `b`, `width` u wide (the shader turns it about its axis to the camera).
static func put_band(buf: PackedFloat32Array, o: int, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var m := (a + b) * 0.5
	buf[o] = d.x
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = m.x
	buf[o + 4] = d.y
	buf[o + 5] = width
	buf[o + 6] = 0.0
	buf[o + 7] = m.y
	buf[o + 8] = d.z
	buf[o + 9] = 0.0
	buf[o + 10] = width
	buf[o + 11] = m.z


## A quad centred at `at` whose local x spans `ax` and local y spans `ay` (its normal is their cross).
static func put_rect(buf: PackedFloat32Array, o: int, at: Vector3, ax: Vector3, ay: Vector3) -> void:
	var az := ax.cross(ay)
	var l := az.length()
	az = az / l if l > 0.00001 else Vector3.UP
	buf[o] = ax.x
	buf[o + 1] = ay.x
	buf[o + 2] = az.x
	buf[o + 3] = at.x
	buf[o + 4] = ax.y
	buf[o + 5] = ay.y
	buf[o + 6] = az.y
	buf[o + 7] = at.y
	buf[o + 8] = ax.z
	buf[o + 9] = ay.z
	buf[o + 10] = az.z
	buf[o + 11] = at.z


## Colour and custom data of the instance at `o` (custom = mode, p, q, 0).
static func put_tail(buf: PackedFloat32Array, o: int, c: Color, mode: int, p := 0.0, q := 0.0) -> void:
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = c.a
	buf[o + 16] = float(mode)
	buf[o + 17] = p
	buf[o + 18] = q
	buf[o + 19] = 0.0
