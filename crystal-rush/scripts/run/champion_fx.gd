class_name ChampionFx
extends RefCounted
## The champions' marks and VFX in ONE MultiMesh draw (heroes design §10.5, §10.6; the twists §6.11-6.27).
## ChampionView owns one MultiMeshInstance3D of SHADER over a unit quad and writes, every frame: each
## champion's contact shadow, foot ring, aura ring and class glyph (the put_* helpers), then this pool of
## short-lived primitives (action motes, tracers, spell rings, the twists' placeholders, the ring shatter),
## then its own per-frame bands (Дара's tethers) and the stamp plate. So the marks cost one draw while a
## champion stands and no effect adds a draw of its own (§10.6: + 0 transient for VFX; only the stamp's
## text is a second draw).
##
## Every primitive is one instance; INSTANCE_CUSTOM.x picks how SHADER draws it:
##   RING  flat thin circle on the road (custom.y = half width in quad units)
##   SIGN  flat sign: the class glyphs 0-4 (custom.z 1 = inside the medallion circle), CROSS, RUNES
##   DISC  flat soft disc (a contact shadow, a dirt patch; custom.y = the hard core share)
##   MOTE  camera-facing mote (custom.y = DIAMOND, ROUND, PAGE, STAR, BLADE; custom.z = spin angle)
##   PLATE camera-facing chamfered porcelain plate with one gold line (the champion stamp)
##   VRING camera-facing thin circle (the aegis catch, the probe ping)
##   BAND  camera-facing band from one point to another (tethers, the chain), custom.y = half width
## Run palette (§10.3): white-gold and the element accents lifted toward it, alpha-blended, unshaded and
## matte: nothing additive, no glow, small and short over the bridge so the next gate row keeps its
## contrast (§10.2).
##
## Pool rules: POOL slots, a new primitive takes the next free slot (the oldest when all are busy);
## ages run on the run's frame time (ChampionView.draw), a delay holds a primitive back unseen.

enum { RING, SIGN, DISC, MOTE, PLATE, VRING, BAND }
enum { DIAMOND, ROUND, PAGE, STAR, BLADE }
## SIGN kinds after the class glyphs (ChampionView.CLASS_INDEX 0-4).
const CROSS := 5
const RUNES := 6

const POOL := 160
## Floats per instance: transform 12, colour 4, custom 4.
const STRIDE := 20
const FADE_IN := 0.05

enum { BALLISTIC, CURVE, STILL }

const SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Champion marks and VFX (ChampionFx): one MultiMesh of unit quads, INSTANCE_CUSTOM.x = the primitive
// (0 ring, 1 sign, 2 disc, 3 mote, 4 plate, 5 camera ring, 6 band), COLOR = tint + alpha. Matte, no glow.
uniform vec3 line_color : source_color = vec3(1.0, 0.906, 0.639);
uniform vec3 plate_color : source_color = vec3(0.984, 0.969, 0.937);
uniform vec3 plate_line : source_color = vec3(0.788, 0.659, 0.416);
varying vec4 v_c;
varying vec2 v_s;

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
// Class signs (0 warrior blade, 1 ranger arrow, 2 mage star, 3 guardian shield, 4 healer cross), the
// burning X cross (5) and the rune circle (6), as distance fields in -1..1.
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
	if (k == 4) {
		return min(box(p, vec2(0.16, 0.56)), box(p, vec2(0.56, 0.16)));
	}
	if (k == 5) {
		vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.70710678;
		return min(box(q, vec2(0.95, 0.09)), box(q.yx, vec2(0.95, 0.09)));
	}
	float r = length(p);
	float ring1 = abs(r - 0.93) - 0.03;
	float ring2 = abs(r - 0.7) - 0.02;
	float sector = (fract(atan(p.y, p.x) / 6.2831853 * 8.0 + 0.5) - 0.5) * 0.7853982 * r;
	float tick = max(abs(sector) - 0.035, abs(r - 0.815) - 0.075);
	return min(min(ring1, ring2), tick);
}
// Camera-facing motes: 0 diamond, 1 round, 2 page, 3 four-point star, 4 blade.
float mote_a(vec2 p, int k) {
	if (k == 1) {
		return 1.0 - smoothstep(0.3, 1.0, length(p));
	}
	if (k == 2) {
		float d = box(p, vec2(0.6, 0.8));
		float aa = fwidth(d) * 1.2;
		return (1.0 - smoothstep(-aa, aa, d)) * (0.82 + 0.18 * step(0.12, abs(p.y + 0.1)));
	}
	if (k == 3) {
		vec2 a = abs(p);
		return 1.0 - smoothstep(0.7, 1.0, sqrt(a.x) + sqrt(a.y));
	}
	if (k == 4) {
		vec2 a = abs(p);
		return 1.0 - smoothstep(0.75, 1.0, a.x * 3.2 + a.y);
	}
	vec2 a = abs(p);
	return 1.0 - smoothstep(0.55, 1.0, a.x + a.y);
}

void vertex() {
	v_c = INSTANCE_CUSTOM;
	v_s = vec2(1.0);
	int mode = int(INSTANCE_CUSTOM.x + 0.5);
	if (mode == 3 || mode == 4 || mode == 5) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		v_s = vec2(sx, sy);
		float a = mode == 3 ? INSTANCE_CUSTOM.z : 0.0;
		vec3 rx = INV_VIEW_MATRIX[0].xyz;
		vec3 ry = INV_VIEW_MATRIX[1].xyz;
		vec3 ax = (rx * cos(a) + ry * sin(a)) * sx;
		vec3 ay = (ry * cos(a) - rx * sin(a)) * sy;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(ax, 0.0), vec4(ay, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (mode == 6) {
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
}

void fragment() {
	int mode = int(v_c.x + 0.5);
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 col = to_linear(COLOR.rgb);
	float a = 0.0;
	if (mode == 0 || mode == 5) {
		float r = length(p);
		float d = abs(r - 0.955) - v_c.y;
		float aa = fwidth(r) * 1.2;
		a = 1.0 - smoothstep(-aa, aa, d);
	} else if (mode == 1) {
		float d = sign_sdf(p, int(v_c.y + 0.5));
		float aa = fwidth(length(p)) * 1.2;
		float a_sign = 1.0 - smoothstep(-aa, aa, d);
		a = a_sign;
		if (v_c.z > 0.5) {
			float ring = abs(length(p) - 0.93) - 0.035;
			a = max(a_sign, 1.0 - smoothstep(-aa, aa, ring));
			col = mix(to_linear(line_color), col, a_sign);
		}
	} else if (mode == 2) {
		a = 1.0 - smoothstep(v_c.y, 1.0, length(p));
	} else if (mode == 3) {
		a = mote_a(p, int(v_c.y + 0.5));
	} else if (mode == 4) {
		// The stamp plate: a 45-degree chamfered porcelain plate, one ~1 px gold line inside its edge.
		vec2 h = v_s * 0.5;
		vec2 w = p * h;
		float ch = min(h.y * 0.55, 0.12);
		float d = max(max(abs(w.x) - h.x, abs(w.y) - h.y), (abs(w.x) + abs(w.y) - (h.x + h.y - ch)) * 0.70710678);
		float aa = fwidth(w.x) * 1.0;
		float lw = fwidth(w.x) * 0.75;
		a = 1.0 - smoothstep(-aa, aa, d);
		float line = 1.0 - smoothstep(lw, lw + aa, abs(d + aa * 3.0));
		col = mix(to_linear(plate_color), to_linear(plate_line), line);
	} else {
		float across = abs(p.y);
		a = (1.0 - smoothstep(0.3, 1.0, across)) * (1.0 - smoothstep(0.88, 1.0, abs(p.x)));
	}
	ALBEDO = col;
	ALPHA = COLOR.a * a;
}
"

var _mode := PackedByteArray()
var _motion := PackedByteArray()
var _param := PackedFloat32Array()
var _p0 := PackedVector3Array()
var _p1 := PackedVector3Array()
var _p2 := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _ang := PackedFloat32Array()
var _fo := PackedFloat32Array()
var _col := PackedColorArray()
var _next := 0
var _live := 0


func _init() -> void:
	_mode.resize(POOL)
	_motion.resize(POOL)
	_param.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_s0.resize(POOL)
	_s1.resize(POOL)
	_grav.resize(POOL)
	_drag.resize(POOL)
	_spin.resize(POOL)
	_ang.resize(POOL)
	_fo.resize(POOL)
	_p0.resize(POOL)
	_p1.resize(POOL)
	_p2.resize(POOL)
	_col.resize(POOL)
	_life.fill(0.0)


## Live (or waiting) primitives in the pool.
func active() -> int:
	return _live


## Empties the pool.
func clear() -> void:
	_life.fill(0.0)
	_live = 0


# ------------------------------------------------------------------ spawning

## A camera-facing mote at `at` moving at `vel` (gravity `grav`, drag `drag` / s), spun `spin` rad/s; it
## shrinks to half its `size` (width, u) and fades over `life` after `delay`.
func mote(at: Vector3, vel: Vector3, life: float, size: float, col: Color, delay := 0.0, grav := 0.0,
		shape := DIAMOND, drag := 0.0, spin := 0.0) -> void:
	var i := _take(MOTE, BALLISTIC, life, delay, col, 0.0)
	_p0[i] = at
	_p1[i] = vel
	_s0[i] = size
	_s1[i] = size * 0.5
	_grav[i] = grav
	_drag[i] = drag
	_spin[i] = spin
	_param[i] = float(shape)
	_ang[i] = randf() * TAU if spin != 0.0 else 0.0


## A mote flying a curve from `from` through the pull of `ctrl` to `to` in `life` after `delay` (arrows
## that home in, a flask, a thrown axe, pages); it keeps `size` and fades only in the last 20 %.
func curve(from: Vector3, ctrl: Vector3, to: Vector3, life: float, size: float, col: Color, delay := 0.0,
		shape := DIAMOND, spin := 0.0) -> void:
	var i := _take(MOTE, CURVE, life, delay, col, 0.8)
	_p0[i] = from
	_p1[i] = ctrl
	_p2[i] = to
	_s0[i] = size
	_s1[i] = size
	_spin[i] = spin
	_param[i] = float(shape)
	_ang[i] = 0.0


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


## A sign flat on the road (`kind`: CROSS, RUNES or a class 0-4), `size` u across, turned `yaw` and spun
## `spin` rad/s.
func sign(at: Vector3, size: float, kind: int, life: float, col: Color, delay := 0.0, yaw := 0.0, spin := 0.0,
		fo := 0.6) -> void:
	var i := _take(SIGN, STILL, life, delay, col, fo)
	_p0[i] = at
	_s0[i] = size
	_s1[i] = size
	_param[i] = float(kind)
	_ang[i] = yaw
	_spin[i] = spin


## A thin circle facing the camera at `at` (radius r0 -> r1).
func vring(at: Vector3, r0: float, r1: float, width: float, life: float, col: Color, delay := 0.0) -> void:
	var i := _take(VRING, STILL, life, delay, col, 0.4)
	_p0[i] = at
	_s0[i] = r0
	_s1[i] = r1
	_param[i] = width


## A band facing the camera from `a` to `b`, `width` u wide.
func band(a: Vector3, b: Vector3, width: float, life: float, col: Color, delay := 0.0, fo := 0.3) -> void:
	var i := _take(BAND, STILL, life, delay, col, fo)
	_p0[i] = a
	_p2[i] = b
	_param[i] = width
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
	_drag[i] = 0.0
	_spin[i] = 0.0
	_ang[i] = 0.0
	return i


# ------------------------------------------------------------------ per frame

## Ages and moves every primitive by `dt` (ChampionView.draw, the run's frame time).
func tick(dt: float) -> void:
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
			if _drag[i] > 0.0:
				v *= maxf(0.0, 1.0 - _drag[i] * dt)
			_p1[i] = v
			_p0[i] += v * dt


## Writes the live primitives of one layer (`flat`: the ones on the road, else the ones above it) into
## `buf` from instance `n`, at most up to `cap`; returns the next free instance.
func write(buf: PackedFloat32Array, n: int, cap: int, flat: bool) -> int:
	if _live == 0:
		return n
	for i in POOL:
		if n >= cap:
			break
		if _life[i] <= 0.0 or _age[i] < 0.0:
			continue
		var mode := int(_mode[i])
		if (mode == RING or mode == SIGN or mode == DISC) != flat:
			continue
		var k := _age[i] / _life[i]
		var c := _col[i]
		var fade := smoothstep(0.0, FADE_IN, _age[i]) * (1.0 - smoothstep(_fo[i], 1.0, k))
		c.a *= fade
		var o := n * STRIDE
		var grow := 1.0 - (1.0 - k) * (1.0 - k)
		var s := lerpf(_s0[i], _s1[i], grow)
		match mode:
			RING:
				put_flat(buf, o, _p0[i], s * 2.0, 0.0)
				put_tail(buf, o, c, RING, 0.5 * _param[i] / maxf(s, 0.01))
			DISC:
				put_flat(buf, o, _p0[i], s * 2.0, 0.0)
				put_tail(buf, o, c, DISC, _param[i])
			SIGN:
				put_flat(buf, o, _p0[i], s, _ang[i])
				put_tail(buf, o, c, SIGN, _param[i])
			VRING:
				put_face(buf, o, _p0[i], s * 2.0, s * 2.0)
				put_tail(buf, o, c, VRING, 0.5 * _param[i] / maxf(s, 0.01))
			BAND:
				put_band(buf, o, _p0[i], _p2[i], _param[i])
				put_tail(buf, o, c, BAND, _param[i] * 0.5)
			_:
				var at := _p0[i]
				if _motion[i] == CURVE:
					var u := 1.0 - k
					at = _p0[i] * (u * u) + _p1[i] * (2.0 * u * k) + _p2[i] * (k * k)
				put_face(buf, o, at, s, s)
				put_tail(buf, o, c, MOTE, _param[i], _ang[i])
		n += 1
	return n


# ------------------------------------------------------------------ instance layout (MultiMesh TRANSFORM_3D)

## A quad lying flat on the road at `at`, `size` u across, turned `yaw` (its top toward -Z at yaw 0, the
## way the run faces).
static func put_flat(buf: PackedFloat32Array, o: int, at: Vector3, size: float, yaw: float) -> void:
	var c := cos(yaw) * size
	var s := sin(yaw) * size
	buf[o] = c
	buf[o + 1] = -s
	buf[o + 2] = 0.0
	buf[o + 3] = at.x
	buf[o + 4] = 0.0
	buf[o + 5] = 0.0
	buf[o + 6] = size
	buf[o + 7] = at.y
	buf[o + 8] = -s
	buf[o + 9] = -c
	buf[o + 10] = 0.0
	buf[o + 11] = at.z


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
