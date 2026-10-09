class_name RunChampion
extends Node3D
## One champion on the bridge (heroes design §4.2, §10.1): the grey-box placeholder that stands
## in for the clip character until the Meshy models arrive. A 1.10 u adult figure (knights
## 0.60-0.80, heroes 1.35-1.45; about 7.5 heads) in ONE matte warm-grey porcelain material with
## a thin white-gold fresnel rim (no emission, no glow), carrying a class prop that reads at a
## glance: Warrior blade, Ranger bow (+ quiver), Mage staff with an orb (+ robe), Guardian tower
## shield (+ helm), Healer satchel and flask. One mesh, one surface, about 2.5k triangles.
##
## The rig lives in the vertex shader: every vertex carries its body part in UV2.x and SHADER
## bends the limbs about fixed joints (the constants below) from four uniforms, so a champion is
## one draw call with no Skeleton3D. ChampionView calls follow() and animate() once a frame:
## idle bob, run cycle (limb swing), fight stance, the class action pose (leap arc, draw, raise,
## shield forward, kneel pulse), hit flinch, the hop over hazards, and the fall (a short hold,
## a 0.6 s topple, it lies there, then sinks away after 2 s).

## Joints of the rig (model space: feet at y 0, facing -Z; x = half distance across). SHADER
## bends about the same points: keep both in step.
const HIP := Vector2(0.068, 0.56)
const KNEE := Vector2(0.07, 0.30)
const ANKLE := Vector2(0.07, 0.06)
const SHOULDER := Vector2(0.14, 0.885)
const ELBOW := Vector2(0.155, 0.715)
const WRIST := Vector2(0.16, 0.565)
const HAND_Y := 0.53
const HEIGHT := 1.10

## Body parts (UV2.x of every vertex).
enum Part { TORSO, HEAD, ARM_L, ARM_R, FORE_L, FORE_R, THIGH_L, THIGH_R, SHIN_L, SHIN_R }

## Vertex tints over the material's warm grey porcelain (props and trims read by value only).
const SKIN := Color(1.0, 1.0, 1.0)
const CLOTH := Color(0.84, 0.83, 0.84)
const DARK := Color(0.6, 0.58, 0.57)
const GOLD := Color(1.0, 0.88, 0.6)
const STEEL := Color(0.93, 0.95, 1.0)
const WOOD := Color(0.78, 0.68, 0.56)

const RUN_CYCLE := 10.5      ## stride phase rad/s at RUN_SPEED (about 3.3 steps/s)
const HOP_TIME := 0.42
const HOP_H := 0.45
const FALL_HOLD := 0.12      ## a beat in the hit pose before the topple (the run adds its hit-stop)
const FALL_TIME := 0.6
const LIE_TIME := 2.0
const SINK_TIME := 0.8
const FLINCH_TIME := 0.25
const ACTION_LEN := {&"leap": 0.9, &"shot": 0.55, &"spell": 0.7, &"block": 0.6, &"mend": 0.8}
## Leap root motion: out to the target until LEAP_HIT (the impact), back from LEAP_BACK.
const LEAP_HIT := 0.4
const LEAP_BACK := 0.52
const LEAP_H := 0.7

## Class carry pose: shoulder pitch L, R and elbow bend L, R (radians; + = forward). The prop arm
## holds still while running (SWING: arm swing share L, R).
const HOLD := {
	"warrior": [0.0, 0.25, 0.35, 0.6],
	"ranger": [0.25, 0.0, 0.7, 0.35],
	"mage": [0.0, 0.1, 0.35, 1.45],
	"guardian": [0.35, 0.0, 1.25, 0.35],
	"healer": [0.15, 0.0, 0.9, 0.3],
}
const SWING := {
	"warrior": [1.0, 0.6], "ranger": [0.3, 1.0], "mage": [1.0, 0.15], "guardian": [0.15, 1.0], "healer": [0.5, 1.0],
}

## Pose channels (_p, _a): the shader uniforms plus the root lift and yaw.
enum P { HIP_L, HIP_R, KNEE_L, KNEE_R, SH_L, SH_R, RAISE_L, RAISE_R, EL_L, EL_R, LEAN, NOD, LIFT, YAW, COUNT }

const SHADER := "shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// RunChampion's procedural rig: UV2.x = body part, the limbs bend about the joints below.
// legs = hip pitch L, R and knee bend L, R; arms = shoulder pitch L, R and raise (outward) L, R;
// body = elbow bend L, R, torso lean (forward +) and head nod; look = hit flash, rim, dim.
uniform vec4 legs = vec4(0.0);
uniform vec4 arms = vec4(0.0);
uniform vec4 body = vec4(0.0);
uniform vec4 look = vec4(0.0, 0.55, 0.0, 0.0);
uniform vec3 base_color : source_color = vec3(0.81, 0.78, 0.74);
uniform vec3 rim_color : source_color = vec3(1.0, 0.906, 0.639);

const vec3 HIP_L = vec3(-0.068, 0.56, 0.0);
const vec3 HIP_R = vec3(0.068, 0.56, 0.0);
const vec3 KNEE_L = vec3(-0.07, 0.30, 0.0);
const vec3 KNEE_R = vec3(0.07, 0.30, 0.0);
const vec3 SH_L = vec3(-0.14, 0.885, 0.0);
const vec3 SH_R = vec3(0.14, 0.885, 0.0);
const vec3 EL_L = vec3(-0.155, 0.715, 0.0);
const vec3 EL_R = vec3(0.155, 0.715, 0.0);
const vec3 WAIST = vec3(0.0, 0.64, 0.0);
const vec3 NECK = vec3(0.0, 0.95, 0.0);

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	int part = int(UV2.x + 0.5);
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	mat3 r = mat3(1.0);
	// Child joints first (knee, elbow), then their parents (hip, shoulder), then the torso.
	if (part == 8 || part == 9) {
		vec3 k = part == 8 ? KNEE_L : KNEE_R;
		r = rot_x(-(part == 8 ? legs.z : legs.w));
		v = r * (v - k) + k;
		n = r * n;
	}
	if (part == 6 || part == 8) {
		r = rot_x(legs.x);
		v = r * (v - HIP_L) + HIP_L;
		n = r * n;
	}
	if (part == 7 || part == 9) {
		r = rot_x(legs.y);
		v = r * (v - HIP_R) + HIP_R;
		n = r * n;
	}
	if (part == 4) {
		r = rot_x(body.x);
		v = r * (v - EL_L) + EL_L;
		n = r * n;
	}
	if (part == 5) {
		r = rot_x(body.y);
		v = r * (v - EL_R) + EL_R;
		n = r * n;
	}
	if (part == 2 || part == 4) {
		r = rot_z(-arms.z) * rot_x(arms.x);
		v = r * (v - SH_L) + SH_L;
		n = r * n;
	}
	if (part == 3 || part == 5) {
		r = rot_z(arms.w) * rot_x(arms.y);
		v = r * (v - SH_R) + SH_R;
		n = r * n;
	}
	if (part == 1) {
		r = rot_x(-body.w);
		v = r * (v - NECK) + NECK;
		n = r * n;
	}
	if (part <= 5) {
		r = rot_x(-body.z);
		v = r * (v - WAIST) + WAIST;
		n = r * n;
	}
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	vec3 c = base_color * to_linear(COLOR.rgb);
	// A thin white-gold rim (fresnel) on a matte porcelain body; the hit flash lightens, never glows.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c = mix(c, rim_color, clamp(fres * look.y, 0.0, 1.0));
	c = mix(c, vec3(1.0), clamp(look.x, 0.0, 1.0) * 0.55);
	c *= 1.0 - 0.35 * clamp(look.z, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.68;
	SPECULAR = 0.3;
}
"

static var _shader: Shader
static var _meshes := {}

var cls := "warrior"
var body: MeshInstance3D
var mat: ShaderMaterial
## Where the champion stands now (smoothed, world; the leap and the hop ride on top of it).
var pos := Vector3.ZERO
var alive := true
## Root of the drawn model this frame (pos + action motion), for VFX anchors.
var root := Vector3.ZERO

var _placed := false
var _goal_prev := Vector3.ZERO
var _t := 0.0
var _phase := 0.0
var _run_w := 0.0
var _fight_w := 0.0
var _cheer_w := 0.0
var _act: StringName = &""
var _act_t := 0.0
var _act_len := 0.0
var _act_at := Vector3.ZERO
var _flinch := 0.0
var _flash := 0.0
var _hop := 0.0
var _fall := -1.0
var _rise := 0.0
var _p := PackedFloat32Array()
var _a := PackedFloat32Array()
var _legs := Vector4.ZERO
var _arms := Vector4.ZERO
var _body := Vector4.ZERO
var _look := Vector4(0.0, 0.55, 0.0, 0.0)


## Builds the model for class `p_cls` (TeamData class id). The element is not drawn on the body:
## the run keeps it neutral (§10.3) and shows the element on the glyph (ChampionView).
func setup(p_cls: String, _element := "") -> void:
	cls = p_cls if HOLD.has(p_cls) else "warrior"
	_p.resize(P.COUNT)
	_a.resize(P.COUNT)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = _shader
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh_for(cls)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The shader raises arms and props above the rest-pose bounds.
	body.extra_cull_margin = 1.0
	add_child(body)


## Triangles of this champion's mesh (perf budget, §10.6).
func triangles() -> int:
	var m := body.mesh as ArrayMesh
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_index_len(s) / 3
	return n


# ------------------------------------------------------------------ state changes

## Follows `goal` (the slot on the bridge, world): the run's forward advance is carried at once,
## the rest eases in (soldiers spring to their slots the same way). Fallen champions stay put.
func follow(goal: Vector3, dt: float, snap := false) -> void:
	if not alive:
		return
	if snap or not _placed:
		_placed = true
		pos = goal
		_goal_prev = goal
		return
	pos.z += goal.z - _goal_prev.z
	_goal_prev = goal
	pos.x += (goal.x - pos.x) * (1.0 - exp(-9.0 * dt))
	pos.z += (goal.z - pos.z) * (1.0 - exp(-12.0 * dt))


## The class action (ChampionKinds fx): leap | shot | spell | block | mend, toward world `at`.
func act(kind: StringName, at := Vector3.INF) -> void:
	if not alive:
		return
	_act = kind
	_act_t = 0.0
	_act_len = float(ACTION_LEN.get(kind, 0.6))
	_act_at = at if at != Vector3.INF else pos + Vector3(0, 0, -2.0)


## Seconds from act() to the impact of `kind` (VFX timing).
static func impact_delay(kind: StringName) -> float:
	match kind:
		&"leap":
			return LEAP_HIT * float(ACTION_LEN[&"leap"])
		&"spell":
			return 0.18
		&"mend":
			return 0.3
	return 0.0


func flinch() -> void:
	if alive:
		_flinch = FLINCH_TIME
		_flash = 1.0


## A small hop over a hazard (champions vault like the hero; hazards never touch them).
func vault() -> void:
	if alive and _hop <= 0.0 and _act != &"leap":
		_hop = HOP_TIME


## Down for the level (§4.2): a beat, the topple, it lies there, then sinks away.
func fall() -> void:
	if not alive:
		return
	alive = false
	_fall = 0.0
	_act = &""
	_hop = 0.0
	_flash = 1.0


## A Healer hero's revive: stands back up where it fell (ChampionView moves it back to its slot).
func revive() -> void:
	alive = true
	_fall = -1.0
	_rise = 0.5
	_flash = 1.0
	visible = true
	_placed = false


# ------------------------------------------------------------------ animation

## One frame of animation. `running` / `fighting` / `cheering` blend the base gaits; the action,
## flinch, hop and fall play on top. Sets the four shader uniforms and the node transform.
func animate(dt: float, running: bool, fighting: bool, cheering := false) -> void:
	if not visible:
		return
	_t += dt
	_run_w = move_toward(_run_w, 1.0 if running and alive else 0.0, dt * 5.0)
	_fight_w = move_toward(_fight_w, 1.0 if fighting and alive else 0.0, dt * 4.0)
	_cheer_w = move_toward(_cheer_w, 1.0 if cheering and alive else 0.0, dt * 3.0)
	_phase = fmod(_phase + dt * RUN_CYCLE * maxf(_run_w, 0.15), TAU)
	_base_pose()
	var off := Vector3.ZERO
	if _act != &"":
		_act_t += dt
		var s := _act_t / maxf(_act_len, 0.01)
		if s >= 1.0:
			_act = &""
		else:
			off = _action_pose(s)
			var w := smoothstep(0.0, 0.12, s) * (1.0 - smoothstep(0.82, 1.0, s))
			if _act == &"leap":
				w = 1.0 - smoothstep(0.85, 1.0, s)
			for i in P.COUNT:
				_p[i] = lerpf(_p[i], _a[i], w)
	if _flinch > 0.0:
		_flinch = maxf(_flinch - dt, 0.0)
		var k := sin(_flinch / FLINCH_TIME * PI)
		_p[P.LEAN] -= 0.3 * k
		_p[P.NOD] -= 0.25 * k
		_p[P.RAISE_L] += 0.25 * k
		_p[P.RAISE_R] += 0.25 * k
		off.z += 0.07 * k
	_flash = maxf(_flash - dt * 4.0, 0.0)
	var lift := _p[P.LIFT]
	if _hop > 0.0:
		_hop = maxf(_hop - dt, 0.0)
		var h := 1.0 - _hop / HOP_TIME
		lift += HOP_H * 4.0 * h * (1.0 - h)
		_p[P.KNEE_L] += 0.9 * sin(h * PI)
		_p[P.KNEE_R] += 0.9 * sin(h * PI)
		_p[P.HIP_L] += 0.5 * sin(h * PI)
		_p[P.HIP_R] += 0.5 * sin(h * PI)
	var pitch := 0.0
	var sink := 0.0
	if _fall >= 0.0:
		_fall += dt
		var k2 := clampf((_fall - FALL_HOLD) / FALL_TIME, 0.0, 1.0)
		pitch = 1.45 * k2 * k2
		_p[P.RAISE_L] = 0.9 * k2
		_p[P.RAISE_R] = 0.9 * k2
		_p[P.SH_L] = 0.5 * k2
		_p[P.SH_R] = 0.5 * k2
		_p[P.HIP_L] = 0.25 * k2
		_p[P.KNEE_R] = 0.4 * k2
		_look.z = k2
		var lie := _fall - FALL_HOLD - FALL_TIME - LIE_TIME
		if lie > 0.0:
			sink = 0.75 * clampf(lie / SINK_TIME, 0.0, 1.0)
			if lie >= SINK_TIME:
				visible = false
	elif _rise > 0.0:
		_rise = maxf(_rise - dt, 0.0)
		pitch = 1.45 * (_rise / 0.5) * (_rise / 0.5)
		_look.z = _rise / 0.5
	else:
		_look.z = 0.0
	_legs = Vector4(_p[P.HIP_L], _p[P.HIP_R], _p[P.KNEE_L], _p[P.KNEE_R])
	_arms = Vector4(_p[P.SH_L], _p[P.SH_R], _p[P.RAISE_L], _p[P.RAISE_R])
	_body = Vector4(_p[P.EL_L], _p[P.EL_R], _p[P.LEAN], _p[P.NOD])
	_look.x = _flash
	mat.set_shader_parameter(&"legs", _legs)
	mat.set_shader_parameter(&"arms", _arms)
	mat.set_shader_parameter(&"body", _body)
	mat.set_shader_parameter(&"look", _look)
	root = pos + off + Vector3(0.0, lift - sink, 0.0)
	position = root
	rotation = Vector3(pitch, _p[P.YAW], 0.0)


## Idle / run / fight / cheer blend into _p.
func _base_pose() -> void:
	var hold: Array = HOLD[cls]
	var sw: Array = SWING[cls]
	var s := sin(_phase)
	var breathe := sin(_t * 1.7)
	var rw := _run_w
	var fw := _fight_w
	var cw := _cheer_w
	var hip := 0.62 * s * rw
	_p[P.HIP_L] = hip + 0.3 * fw
	_p[P.HIP_R] = -hip + 0.3 * fw
	_p[P.KNEE_L] = 0.06 + rw * (0.25 + 0.8 * maxf(0.0, cos(_phase - 0.3))) + 0.55 * fw
	_p[P.KNEE_R] = 0.06 + rw * (0.25 + 0.8 * maxf(0.0, cos(_phase + PI - 0.3))) + 0.55 * fw
	var swing := 0.55 * s * rw
	_p[P.SH_L] = float(hold[0]) - swing * float(sw[0]) + 2.4 * cw
	_p[P.SH_R] = float(hold[1]) + swing * float(sw[1]) + 2.4 * cw * 0.6
	_p[P.RAISE_L] = 0.08 + 0.02 * breathe + 0.3 * cw
	_p[P.RAISE_R] = 0.08 - 0.02 * breathe + 0.3 * cw
	_p[P.EL_L] = float(hold[2]) + 0.7 * rw * float(sw[0])
	_p[P.EL_R] = float(hold[3]) + 0.7 * rw * float(sw[1])
	_p[P.LEAN] = 0.012 * breathe + 0.16 * rw + 0.12 * fw
	_p[P.NOD] = -0.12 * rw + 0.04 * fw
	_p[P.LIFT] = 0.006 * sin(_t * 1.7 + 0.6) * (1.0 - rw) + 0.035 * absf(cos(_phase)) * rw - 0.04 * fw \
			+ 0.05 * cw * absf(sin(_t * 5.0))
	_p[P.YAW] = 0.0
	if fw > 0.0:
		# In contact: the free arm keeps working (the warrior hacks, the others brace).
		var hack := 0.5 + 0.5 * sin(_t * 7.0)
		match cls:
			"warrior":
				_p[P.SH_R] += fw * (0.4 + 1.4 * hack)
				_p[P.EL_R] += fw * 0.6 * (1.0 - hack)
			"guardian":
				_p[P.SH_L] += fw * 0.5
			"mage", "healer", "ranger":
				_p[P.SH_R] += fw * 0.2 * hack


## The class action at progress `s` (0..1) into _a; returns the root offset (leap arc).
func _action_pose(s: float) -> Vector3:
	for i in P.COUNT:
		_a[i] = _p[i]
	var off := Vector3.ZERO
	var to := _act_at - pos
	match _act:
		&"leap":
			# Out to the squad front, the strike, back to the slot.
			var k := 0.0
			var h := 0.0
			if s < LEAP_HIT:
				var u := s / LEAP_HIT
				k = u * u * (3.0 - 2.0 * u)
				h = LEAP_H * 4.0 * u * (1.0 - u)
			elif s < LEAP_BACK:
				k = 1.0
			else:
				var v := (s - LEAP_BACK) / (1.0 - LEAP_BACK)
				k = 1.0 - v * v * (3.0 - 2.0 * v)
				h = LEAP_H * 0.5 * 4.0 * v * (1.0 - v)
			off = Vector3(to.x * k, h, to.z * k)
			var air := 1.0 if s < LEAP_HIT else 0.0
			var strike := smoothstep(LEAP_HIT - 0.05, LEAP_HIT + 0.04, s) \
					* (1.0 - smoothstep(LEAP_BACK, LEAP_BACK + 0.15, s))
			_a[P.SH_R] = lerpf(2.7, 0.35, strike) if s < LEAP_BACK else _p[P.SH_R]
			_a[P.EL_R] = lerpf(0.4, 0.0, strike)
			_a[P.SH_L] = 0.9 * air + 0.3
			_a[P.HIP_L] = 0.9 * air + 0.5 * strike
			_a[P.HIP_R] = 0.7 * air + 0.2 * strike
			_a[P.KNEE_L] = 1.4 * air + 0.8 * strike
			_a[P.KNEE_R] = 1.2 * air + 0.9 * strike
			_a[P.LEAN] = 0.15 + 0.4 * strike
			_a[P.LIFT] = -0.08 * strike
		&"shot":
			# Bow arm out, string hand drawn to the chin, turned toward the target.
			_a[P.SH_L] = 1.55
			_a[P.RAISE_L] = -0.05
			_a[P.EL_L] = 0.05
			_a[P.SH_R] = 1.45
			_a[P.RAISE_R] = -0.3
			_a[P.EL_R] = 2.0 * (1.0 - smoothstep(0.55, 0.62, s))
			_a[P.LEAN] = 0.02
			_a[P.YAW] = clampf(atan2(-to.x, -to.z), -0.7, 0.7)
		&"spell":
			# The staff thrust forward (held upright), the free hand open toward the spell.
			_a[P.SH_R] = 1.6
			_a[P.EL_R] = 0.0
			_a[P.RAISE_R] = 0.05
			_a[P.SH_L] = 1.2
			_a[P.EL_L] = 0.25
			_a[P.LEAN] = 0.1
			_a[P.LIFT] = 0.02 * sin(s * PI)
			_a[P.YAW] = clampf(atan2(-to.x, -to.z), -0.5, 0.5)
		&"block":
			# Shield forward and in, braced low.
			_a[P.SH_L] = 0.9
			_a[P.RAISE_L] = -0.35
			_a[P.EL_L] = 0.7
			_a[P.SH_R] = -0.3
			_a[P.HIP_L] = 0.55
			_a[P.HIP_R] = 0.2
			_a[P.KNEE_L] = 0.75
			_a[P.KNEE_R] = 0.6
			_a[P.LEAN] = 0.25
			_a[P.LIFT] = -0.07
		&"mend":
			# Kneel on the right knee, the flask held up, a pulse at the top.
			_a[P.HIP_L] = 1.35
			_a[P.KNEE_L] = 1.45
			_a[P.HIP_R] = 0.1
			_a[P.KNEE_R] = 1.6
			_a[P.LIFT] = -0.22
			_a[P.SH_L] = 0.9 + 0.25 * sin(s * PI)
			_a[P.EL_L] = 1.2
			_a[P.SH_R] = 0.45
			_a[P.EL_R] = 0.2
			_a[P.LEAN] = 0.25
	return off


# ------------------------------------------------------------------ the grey-box mesh

## The class mesh (built once per class and cached).
static func mesh_for(p_cls: String) -> ArrayMesh:
	if _meshes.has(p_cls):
		return _meshes[p_cls]
	var b := Builder.new()
	_body_parts(b, p_cls)
	_prop(b, p_cls)
	var m := b.commit()
	_meshes[p_cls] = m
	return m


static func _body_parts(b: Builder, p_cls: String) -> void:
	var robe := p_cls == "mage"
	# Torso: pelvis (lying across), chest, belt, neck; the mage's robe.
	b.add(_capsule(0.085, 0.24), Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.8)),
			Vector3(0.0, 0.585, 0.0)), Part.TORSO, CLOTH)
	b.add(_capsule(0.1, 0.36), _sc(Vector3(1.2, 1.0, 0.75), Vector3(0.0, 0.77, 0.0)), Part.TORSO, CLOTH if robe else SKIN)
	b.add(_cyl(0.105, 0.105, 0.035), _sc(Vector3(1.0, 1.0, 0.78), Vector3(0.0, 0.665, 0.0)), Part.TORSO, DARK)
	b.add(_cyl(0.034, 0.038, 0.08), _at(Vector3(0.0, 0.955, 0.0)), Part.TORSO, SKIN)
	if robe:
		b.add(_cyl(0.11, 0.17, 0.36), _sc(Vector3(1.0, 1.0, 0.85), Vector3(0.0, 0.47, 0.0)), Part.TORSO, CLOTH)
	# Head (7.5 heads tall: crown at 1.10).
	b.add(_sphere(0.072), _sc(Vector3(0.92, 1.08, 1.0), Vector3(0.0, 1.025, 0.0)), Part.HEAD, SKIN)
	for side: float in [-1.0, 1.0]:
		var l := side < 0.0
		var arm := Part.ARM_L if l else Part.ARM_R
		var fore := Part.FORE_L if l else Part.FORE_R
		var thigh := Part.THIGH_L if l else Part.THIGH_R
		var shin := Part.SHIN_L if l else Part.SHIN_R
		var sh := Vector3(SHOULDER.x * side, SHOULDER.y, 0.0)
		var el := Vector3(ELBOW.x * side, ELBOW.y, 0.0)
		var wr := Vector3(WRIST.x * side, WRIST.y, 0.0)
		var hip := Vector3(HIP.x * side, HIP.y, 0.0)
		var kn := Vector3(KNEE.x * side, KNEE.y, 0.0)
		var an := Vector3(ANKLE.x * side, ANKLE.y, 0.0)
		b.add(_sphere(0.048), _at(sh), arm, SKIN)
		b.add(_capsule(0.037, 0.21), _seg(sh, el), arm, SKIN)
		b.add(_capsule(0.032, 0.19), _seg(el, wr), fore, SKIN)
		b.add(_sphere(0.033), _sc(Vector3(0.9, 1.15, 1.0), Vector3(WRIST.x * side, HAND_Y, -0.005)), fore, SKIN)
		b.add(_capsule(0.056, 0.32), _seg(hip, kn), thigh, CLOTH)
		b.add(_capsule(0.043, 0.3), _seg(kn, an), shin, CLOTH)
		b.add(_box(Vector3(0.075, 0.055, 0.155)), _at(Vector3(ANKLE.x * side, 0.03, -0.035)), shin, DARK)
		if p_cls == "warrior" or p_cls == "guardian":
			# Pauldrons.
			var pad := sh + Vector3(0.012 * side, 0.02, 0.0)
			b.add(_sphere(0.066), _sc(Vector3(1.0, 0.7, 1.05), pad), arm, STEEL if p_cls == "guardian" else GOLD)


## The class prop and headwear.
static func _prop(b: Builder, p_cls: String) -> void:
	var hand_l := Vector3(-WRIST.x, HAND_Y, 0.0)
	var hand_r := Vector3(WRIST.x, HAND_Y, 0.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var hood := _sc(Vector3(1.0, 1.0, 1.12), Vector3(0.0, 1.03, 0.022))
	match p_cls:
		"warrior":
			# A straight blade along -Z from the right fist (the elbow bend raises it), guard, pommel;
			# a low crest on the head.
			b.add(_box(Vector3(0.012, 0.046, 0.46)), _at(hand_r + fwd * 0.29), Part.FORE_R, STEEL)
			b.add(_box(Vector3(0.13, 0.022, 0.024)), _at(hand_r + fwd * 0.055), Part.FORE_R, GOLD)
			b.add(_sphere(0.021, 6, 4), _at(hand_r - fwd * 0.06), Part.FORE_R, GOLD)
			b.add(_box(Vector3(0.02, 0.04, 0.15)), _at(Vector3(0.0, 1.085, 0.01)), Part.HEAD, GOLD)
		"ranger":
			# Bow: an arc through the left fist, belly toward the hand (drawn, it stands upright and
			# the belly faces the target), the string, a quiver on the back, a hood.
			var r := 0.3
			var c := hand_l + Vector3(0.0, r, 0.0)
			var pts: Array[Vector3] = []
			for k in 9:
				var th := deg_to_rad(-65.0 + 130.0 * k / 8.0)
				pts.append(c + Vector3(0.0, -r * cos(th), r * sin(th)))
			for k in 8:
				var rad := 0.013 if k in [3, 4] else 0.009
				var seg_len := pts[k].distance_to(pts[k + 1]) + 0.01
				b.add(_cyl(rad, rad, seg_len, 6), _seg(pts[k], pts[k + 1]), Part.FORE_L, WOOD)
			b.add(_cyl(0.003, 0.003, pts[0].distance_to(pts[8]), 4), _seg(pts[0], pts[8]), Part.FORE_L, STEEL)
			var quiver := Transform3D(Basis(Vector3.BACK, -0.45), Vector3(0.07, 0.83, 0.095))
			b.add(_cyl(0.038, 0.034, 0.3), quiver, Part.TORSO, DARK)
			b.add(_sphere(0.084), hood, Part.HEAD, CLOTH)
		"mage":
			# Staff along -Z through the right fist (upright once the elbow bends), the orb on top, a hood.
			b.add(_cyl(0.015, 0.015, 1.1, 6), _seg(hand_r - fwd * 0.58, hand_r + fwd * 0.52), Part.FORE_R, WOOD)
			b.add(_sphere(0.055), _at(hand_r + fwd * 0.58), Part.FORE_R, SKIN)
			b.add(_cyl(0.03, 0.02, 0.05, 6), _seg(hand_r + fwd * 0.5, hand_r + fwd * 0.54), Part.FORE_R, GOLD)
			b.add(_sphere(0.084), hood, Part.HEAD, CLOTH)
		"guardian":
			# Tower shield on the left forearm, authored along the forearm's normal so the carry pose
			# (forearm forward) stands it upright facing the front; gold rim and boss; a helm.
			var sc := hand_l + Vector3(-0.045, -0.05, -0.09)
			b.add(_box(Vector3(0.3, 0.035, 0.56)), _at(sc), Part.FORE_L, STEEL)
			var rims: Array[Vector3] = [Vector3(0.0, -0.022, 0.275), Vector3(0.31, 0.02, 0.025),
					Vector3(0.0, -0.022, -0.275), Vector3(0.31, 0.02, 0.025),
					Vector3(0.15, -0.022, 0.0), Vector3(0.025, 0.02, 0.56),
					Vector3(-0.15, -0.022, 0.0), Vector3(0.025, 0.02, 0.56)]
			for k in 4:
				b.add(_box(rims[2 * k + 1]), _at(sc + rims[2 * k]), Part.FORE_L, GOLD)
			b.add(_sphere(0.042, 8, 4), _sc(Vector3(1.0, 0.5, 1.0), sc + Vector3(0.0, -0.025, 0.0)), Part.FORE_L, GOLD)
			b.add(_sphere(0.08), _sc(Vector3(1.0, 0.92, 1.06), Vector3(0.0, 1.035, 0.0)), Part.HEAD, STEEL)
		"healer":
			# Satchel on the right hip on a strap across the chest, a flask in the left hand, a headband.
			var strap := Transform3D(Basis(Vector3.BACK, 0.62), Vector3(0.0, 0.79, -0.078))
			b.add(_box(Vector3(0.065, 0.1, 0.13)), _at(Vector3(0.135, 0.6, 0.0)), Part.TORSO, DARK)
			b.add(_box(Vector3(0.022, 0.44, 0.012)), strap, Part.TORSO, GOLD)
			b.add(_sphere(0.036, 8, 5), _at(hand_l + Vector3(0.0, -0.05, -0.01)), Part.FORE_L, SKIN)
			b.add(_cyl(0.012, 0.014, 0.04, 6), _at(hand_l + Vector3(0.0, -0.1, -0.01)), Part.FORE_L, GOLD)
			b.add(_cyl(0.076, 0.076, 0.022, 12), _sc(Vector3(1.0, 1.0, 1.05), Vector3(0.0, 1.045, 0.0)), Part.HEAD, GOLD)


## Transform placing a primitive at `p`.
static func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


## Transform placing a primitive scaled by `scl` at `p`.
static func _sc(scl: Vector3, p: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(scl), p)


## Transform placing a Y-aligned primitive between `a` and `b` (centre, axis along b - a).
static func _seg(a: Vector3, b: Vector3) -> Transform3D:
	var dir := b - a
	if dir.y < 0.0:
		dir = -dir
	return Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())), (a + b) * 0.5)


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, 2.0 * r + 0.001)
	m.radial_segments = 10
	m.rings = 3
	return m


static func _cyl(top: float, bottom: float, h: float, segs := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func _sphere(r: float, segs := 10, rings := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = 2.0 * r
	m.radial_segments = segs
	m.rings = rings
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Collects primitives into one surface: vertex colour = tint, UV2.x = body part.
class Builder extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## Appends `mesh` placed by `xf` as body part `part` tinted `col`.
	func add(mesh: PrimitiveMesh, xf: Transform3D, part: int, col: Color) -> void:
		var a := mesh.get_mesh_arrays()
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		var base := v.size()
		for i in pv.size():
			v.append(xf * pv[i])
			n.append((nb * pn[i]).normalized())
			c.append(col)
			uv2.append(Vector2(float(part), 0.0))
		for j in pi:
			idx.append(base + j)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
