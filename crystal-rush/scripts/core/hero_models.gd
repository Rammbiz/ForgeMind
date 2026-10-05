class_name HeroModels
## The two sculpted heroes from Crystal Bastion (rigged Meshy models, see that project's
## tools/rig_hero.py) and their procedural bone animation, shared by the runner.
## Bone rotations are blended in code from layered poses, so the rig needs no clips.

const HERO_DIR := "res://assets/models/heroes/"
## World height of the sculpted heroes (rigged Meshy models, 1 unit tall in the file).
const HERO_HEIGHT := {"bolt": 1.35, "titan": 1.45}
const HERO_STYLE := {"bolt": "speedster", "titan": "giant"}


## A hero at its in-game size, facing +Z. Metadata: "anim", "style", "skeleton", "bones",
## "bar_y" (height above the head for labels) and "portrait" ([eye, target] for UI cameras).
static func hero(type: String) -> Node3D:
	return _rigged_hero(type, HERO_DIR + type + ".glb")


static func _rigged_hero(type: String, path: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var rig := (load(path) as PackedScene).instantiate() as Node3D
	var h := float(HERO_HEIGHT.get(type, 1.0))
	rig.scale = Vector3.ONE * h
	root.add_child(rig)
	var sk := rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bones := {}
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i)] = i
	_tune_hero(rig, Save.quality == "high")
	root.set_meta("anim", "rig")
	root.set_meta("style", HERO_STYLE.get(type, "giant"))
	root.set_meta("skeleton", sk)
	root.set_meta("bones", bones)
	root.set_meta("hips_rest", sk.get_bone_rest(bones["hips"]).origin)
	# Thigh and shin lengths, for keeping the feet on the ground when the legs bend.
	root.set_meta("leg", Vector2(sk.get_bone_rest(bones["shin.L"]).origin.length(), sk.get_bone_rest(bones["foot.L"]).origin.length()))
	root.set_meta("state", {"t": -1.0, "move": 0.0, "fight": 0.0})
	# Head-and-shoulders framing, from where the head sits in the rig file.
	var head := sk.get_bone_global_rest(bones["head"]).origin * h
	var face := head + Vector3(0, (0.12 if type == "bolt" else 0.06) * h, 0)
	root.set_meta("portrait", [face + Vector3(0.05, 0.08, 1.45 if type == "bolt" else 1.6), face])
	root.set_meta("bar_y", h + 0.12)
	return root


static func _tune_hero(n: Node, quality_high: bool) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality_high else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as StandardMaterial3D
			if src:
				mi.set_surface_override_material(s, _hero_material(src, quality_high))
	for ch in n.get_children():
		_tune_hero(ch, quality_high)


static var _hero_mats := {}


## The painted Meshy texture already carries the shading; keep it matte with a soft rim so
## the hero reads against busy arenas.
static func _hero_material(src: StandardMaterial3D, quality_high: bool) -> StandardMaterial3D:
	var key := [src, quality_high]
	if _hero_mats.has(key):
		return _hero_mats[key]
	var m := src.duplicate() as StandardMaterial3D
	m.metallic = 0.0
	m.roughness = 0.8
	m.metallic_specular = 0.35
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	if not quality_high:
		m.normal_enabled = false
	_hero_mats[key] = m
	return m



## Per-frame hero animation. `attack` runs 1 -> 0 over one swing, `ability` and `ult` 1 -> 0
## over the super moves; `alt` alternates the striking hand and `combat` raises the guard.
## `pace` scales the run cycle to the ground speed (1 = the heroes' own jog).
static func animate_hero(model: Node3D, t: float, moving: bool, attack: float, ability := 0.0, ult := 0.0, alt := false, combat := false, pace := 1.0) -> void:
	_animate_rig(model, t, moving, attack, ability, ult, alt, combat, pace)


## Rigged heroes: bone rotations (degrees, about the model's own axes, since every rest
## rotation is identity) are blended from layered poses. Everything is a function of time
## plus a little smoothed state kept on the model, so the rig needs no animation clips.
static func _animate_rig(model: Node3D, t: float, moving: bool, attack: float, ability: float, ult: float, alt: bool, combat: bool, pace: float) -> void:
	var sk: Skeleton3D = model.get_meta("skeleton")
	var bones: Dictionary = model.get_meta("bones")
	var st: Dictionary = model.get_meta("state")
	var dt := clampf(t - float(st["t"]), 0.0, 0.1)
	st["t"] = t
	st["move"] = move_toward(float(st["move"]), 1.0 if moving else 0.0, dt * 7.0)
	st["fight"] = move_toward(float(st["fight"]), 1.0 if combat and not moving else 0.0, dt * 4.0)
	var pose := {}
	# x: extra hip height (bobs, jumps), y: how much the standing-leg contact applies.
	var lift: Vector2
	if str(model.get_meta("style")) == "speedster":
		lift = _pose_speedster(pose, t, float(st["move"]), float(st["fight"]), attack, ability, ult, alt, pace)
	else:
		lift = _pose_giant(pose, t, float(st["move"]), float(st["fight"]), attack, ability, ult, alt, pace)
	var hips_y := lift.x + _leg_contact(pose, model.get_meta("leg")) * lift.y
	for bname: String in bones:
		var e: Vector3 = pose.get(bname, Vector3.ZERO)
		sk.set_bone_pose_rotation(bones[bname], Quaternion.from_euler(e * (PI / 180.0)))
	sk.set_bone_pose_position(bones["hips"], (model.get_meta("hips_rest") as Vector3) + Vector3(0, hips_y, 0))


## How far the hips must drop so the straighter leg still reaches the ground (<= 0).
static func _leg_contact(pose: Dictionary, leg: Vector2) -> float:
	var reach := 0.0
	for s in ["L", "R"]:
		var thigh: Vector3 = pose.get("thigh." + s, Vector3.ZERO)
		var shin: Vector3 = pose.get("shin." + s, Vector3.ZERO)
		var spread := cos(deg_to_rad(thigh.z))
		reach = maxf(reach, (leg.x * cos(deg_to_rad(thigh.x)) + leg.y * cos(deg_to_rad(thigh.x + shin.x))) * spread)
	return reach - leg.x - leg.y


## Adds `part` (bone -> Euler degrees) to `pose` with weight `w`.
static func _mix(pose: Dictionary, w: float, part: Dictionary) -> void:
	if w <= 0.0:
		return
	for k: String in part:
		pose[k] = (pose.get(k, Vector3.ZERO) as Vector3) + (part[k] as Vector3) * w


## Moves the bones named in `part` towards it by `w`, leaving the others as they are.
static func _lean(pose: Dictionary, w: float, part: Dictionary) -> void:
	if w <= 0.0:
		return
	for k: String in part:
		pose[k] = (pose.get(k, Vector3.ZERO) as Vector3).lerp(part[k], w)


## Moves the whole body towards `part` by `w` (bones it does not name go back to rest).
static func _override(pose: Dictionary, w: float, part: Dictionary) -> void:
	if w <= 0.0:
		return
	for k: String in pose.keys():
		if not part.has(k):
			pose[k] = (pose[k] as Vector3) * (1.0 - w)
	_lean(pose, w, part)


## 0 -> 1 -> 0 envelope of a move that runs `v` from 1 to 0 over `0..1` of its time.
static func _env(v: float, rise: float, fall: float) -> float:
	var u := 1.0 - v
	return smoothstep(0.0, rise, u) * (1.0 - smoothstep(fall, 1.0, u))


## Thunderfox: relaxed sway, a boxer's guard in a fight, a lean "swept-arms" sprint, quick
## alternating jabs, a crouched launch for the dash and a spinning storm stance for the ult.
static func _pose_speedster(pose: Dictionary, t: float, move: float, fight: float, attack: float, ability: float, ult: float, alt: bool, pace: float) -> Vector2:
	var b := sin(t * 2.4)
	var still := 1.0 - move
	var lift := 0.0
	var contact := still
	_mix(pose, still * (1.0 - fight), {
		"spine": Vector3(2.0 + b, 0, 0), "chest": Vector3(b * 1.5, 0, 0),
		"head": Vector3(-2.0, sin(t * 0.7) * 9.0, sin(t * 0.9) * 3.0),
		"upperarm.L": Vector3(4, 0, -32.0 + b), "upperarm.R": Vector3(4, 0, 32.0 - b),
		"forearm.L": Vector3(-18, 0, 0), "forearm.R": Vector3(-18, 0, 0),
		"tail1": Vector3(12.0 + b * 3.0, sin(t * 1.3) * 12.0, 0),
		"tail2": Vector3(0, sin(t * 1.3 - 0.6) * 12.0, 0),
		"tail3": Vector3(0, sin(t * 1.3 - 1.2) * 14.0, 0),
		"tail4": Vector3(0, sin(t * 1.3 - 1.8) * 16.0, 0),
	})
	var hop := sin(t * 7.0)
	_mix(pose, still * fight, {
		"spine": Vector3(8, 0, 0), "chest": Vector3(4.0 + hop, -10, 0), "head": Vector3(-8, 8, 0),
		"upperarm.L": Vector3(-28, 0, -40), "upperarm.R": Vector3(-34, 0, 40),
		"forearm.L": Vector3(-105, 0, 0), "forearm.R": Vector3(-95, 0, 0),
		"thigh.L": Vector3(-16, 0, -3), "shin.L": Vector3(20, 0, 0), "foot.L": Vector3(-4, 0, 0),
		"thigh.R": Vector3(10, 0, 3), "shin.R": Vector3(14, 0, 0), "foot.R": Vector3(-24, 0, 0),
		"tail1": Vector3(28, sin(t * 3.0) * 10.0, 0), "tail2": Vector3(6, sin(t * 3.0 - 0.7) * 10.0, 0),
		"tail3": Vector3(4, sin(t * 3.0 - 1.4) * 12.0, 0), "tail4": Vector3(0, sin(t * 3.0 - 2.1) * 14.0, 0),
	})
	lift += still * fight * absf(hop) * 0.006
	if move > 0.0:
		var p := t * 17.0 * pace
		var run := {
			"hips": Vector3(0, -sin(p) * 8.0, 0), "spine": Vector3(18, 0, 0), "chest": Vector3(8, sin(p) * 10.0, 0),
			"neck": Vector3(-8, 0, 0), "head": Vector3(-18, 0, sin(p) * 3.0),
			"upperarm.L": Vector3(70.0 + sin(p) * 6.0, 0, -12), "upperarm.R": Vector3(70.0 - sin(p) * 6.0, 0, 12),
			"forearm.L": Vector3(-12, 0, 0), "forearm.R": Vector3(-12, 0, 0),
			"hand.L": Vector3(15, 0, 0), "hand.R": Vector3(15, 0, 0),
			"tail1": Vector3(55, sin(p * 0.5) * 8.0, 0), "tail2": Vector3(5, sin(p * 0.5 - 0.7) * 10.0, 0),
			"tail3": Vector3(5, sin(p * 0.5 - 1.4) * 12.0, 0), "tail4": Vector3(0, sin(p * 0.5 - 2.1) * 14.0, 0),
		}
		for side in [["L", p], ["R", p + PI]]:
			var ph: float = side[1]
			run["thigh." + side[0]] = Vector3(-55.0 * sin(ph) - 12.0, 0, 0)
			run["shin." + side[0]] = Vector3(12.0 + 85.0 * maxf(cos(ph), 0.0), 0, 0)
			run["foot." + side[0]] = Vector3(25.0 * maxf(cos(ph), 0.0), 0, 0)
		_mix(pose, move, run)
		lift += move * (absf(sin(p)) * 0.035 - 0.012)
	if attack > 0.0:
		# A quick straight jab, hands alternating; the chest twists into it (mid-run too).
		var e := sin(PI * clampf((1.0 - attack) * 1.4, 0.0, 1.0)) * (still + move * 0.85)
		var s := "R" if alt else "L"
		var sgn := -1.0 if alt else 1.0
		_lean(pose, e, {
			"upperarm." + s: Vector3(-85, -8.0 * sgn, -37.0 * sgn), "forearm." + s: Vector3(-5, 0, 0),
			"hand." + s: Vector3(0, 0, 0),
		})
		_mix(pose, e, {"chest": Vector3(0, -22.0 * sgn, 0), "spine": Vector3(6, 0, 0)})
	if ability > 0.0:
		# Dash: a crouched sprinter's launch with the arms swept back.
		var w := _env(ability, 0.15, 0.55)
		_override(pose, w, {
			"spine": Vector3(35, 0, 0), "chest": Vector3(12, 0, 0), "neck": Vector3(-10, 0, 0), "head": Vector3(-30, 0, 0),
			"upperarm.L": Vector3(85, 0, -15), "upperarm.R": Vector3(85, 0, 15),
			"forearm.L": Vector3(-5, 0, 0), "forearm.R": Vector3(-5, 0, 0),
			"thigh.L": Vector3(-55, 0, 0), "shin.L": Vector3(95, 0, 0), "foot.L": Vector3(-40, 0, 0),
			"thigh.R": Vector3(45, 0, 0), "shin.R": Vector3(35, 0, 0), "foot.R": Vector3(-50, 0, 0),
			"tail1": Vector3(70, 0, 0), "tail2": Vector3(8, 0, 0), "tail3": Vector3(8, 0, 0), "tail4": Vector3(8, 0, 0),
		})
		lift *= 1.0 - w
		contact = lerpf(contact, 1.0, w)
	if ult > 0.0:
		# Storm: running the vortex, leaning hard into the turn (the hero moves the model
		# around the circle; this is the body).
		var w := _env(ult, 0.06, 0.9)
		var p := t * 20.0
		var storm := {
			"spine": Vector3(24, 0, 14), "chest": Vector3(8, 0, 6), "head": Vector3(-20, -15, 0),
			"upperarm.L": Vector3(75, 0, -5), "upperarm.R": Vector3(75, 0, 5),
			"forearm.L": Vector3(-10, 0, 0), "forearm.R": Vector3(-10, 0, 0),
			"tail1": Vector3(70, -20, 0), "tail2": Vector3(5, -15, 0), "tail3": Vector3(5, -15, 0), "tail4": Vector3(0, -10, 0),
		}
		for side in [["L", p], ["R", p + PI]]:
			var ph: float = side[1]
			storm["thigh." + side[0]] = Vector3(-60.0 * sin(ph) - 12.0, 0, 0)
			storm["shin." + side[0]] = Vector3(12.0 + 90.0 * maxf(cos(ph), 0.0), 0, 0)
			storm["foot." + side[0]] = Vector3(25.0 * maxf(cos(ph), 0.0), 0, 0)
		_override(pose, w, storm)
		lift = lerpf(lift, absf(sin(p)) * 0.03 - 0.012, w)
		contact *= 1.0 - w
	return Vector2(lift, contact)


## Stone guardian: heavy breathing, a low brawler's stance in a fight, a rolling stomp,
## alternating hammer fists, a two-fisted ground slam and a leaping quake for the ult.
static func _pose_giant(pose: Dictionary, t: float, move: float, fight: float, attack: float, ability: float, ult: float, alt: bool, pace: float) -> Vector2:
	var b := sin(t * 1.5)
	var still := 1.0 - move
	var lift := 0.0
	var contact := still
	_mix(pose, still * (1.0 - fight), {
		"spine": Vector3(3.0 + b * 1.5, 0, 0), "chest": Vector3(b * 2.0, 0, 0),
		"head": Vector3(-3, sin(t * 0.45) * 12.0, 0),
		"upperarm.L": Vector3(6, 0, -12.0 + b), "upperarm.R": Vector3(6, 0, 12.0 - b),
		"forearm.L": Vector3(-12, 0, 0), "forearm.R": Vector3(-12, 0, 0),
	})
	lift += still * (1.0 - fight) * b * 0.005
	_mix(pose, still * fight, {
		"spine": Vector3(10, 0, 0), "chest": Vector3(6.0 + b * 2.0, 0, 0), "head": Vector3(-10, 0, 0),
		"upperarm.L": Vector3(-25, 0, -8), "upperarm.R": Vector3(-25, 0, 8),
		"forearm.L": Vector3(-40, 0, 0), "forearm.R": Vector3(-40, 0, 0),
		"thigh.L": Vector3(-14, 0, -4), "shin.L": Vector3(20, 0, 0), "foot.L": Vector3(-6, 0, 0),
		"thigh.R": Vector3(-14, 0, 4), "shin.R": Vector3(20, 0, 0), "foot.R": Vector3(-6, 0, 0),
	})
	if move > 0.0:
		var p := t * 6.2 * pace
		var stride := 26.0 + 10.0 * clampf(pace - 1.0, 0.0, 1.0)
		var walk := {
			"hips": Vector3(0, sin(p) * 5.0, sin(p) * 4.0), "spine": Vector3(6, 0, 0),
			"chest": Vector3(2, -sin(p) * 7.0, -sin(p) * 3.0), "head": Vector3(-4, sin(p) * 3.0, 0),
		}
		for side in [["L", p, -1.0], ["R", p + PI, 1.0]]:
			var ph: float = side[1]
			var thigh := -stride * sin(ph) - 4.0
			var shin := 6.0 + 34.0 * maxf(cos(ph), 0.0)
			walk["thigh." + side[0]] = Vector3(thigh, 0, 0)
			walk["shin." + side[0]] = Vector3(shin, 0, 0)
			walk["foot." + side[0]] = Vector3(-(thigh + shin) * 0.6, 0, 0)
			walk["upperarm." + side[0]] = Vector3(22.0 * sin(ph), 0, 10.0 * side[2])
			walk["forearm." + side[0]] = Vector3(-15.0 - 10.0 * maxf(-sin(ph), 0.0), 0, 0)
		_mix(pose, move, walk)
		lift += move * (absf(sin(p)) * 0.022 - 0.012)
	if attack > 0.0:
		# Hammer fist, hands alternating: up, down, then back into the stance (mid-run too).
		still = maxf(still, 0.85)
		var u := 1.0 - attack
		var up := smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.16, 0.3, u))
		var down := smoothstep(0.16, 0.3, u) * (1.0 - smoothstep(0.55, 1.0, u))
		var s := "R" if alt else "L"
		var sgn := -1.0 if alt else 1.0
		_lean(pose, up * still, {"upperarm." + s: Vector3(-140, 0, 8.0 * sgn), "forearm." + s: Vector3(-60, 0, 0)})
		_lean(pose, down * still, {"upperarm." + s: Vector3(-35, 0, -10.0 * sgn), "forearm." + s: Vector3(-5, 0, 0)})
		_mix(pose, still, {"spine": Vector3(-10.0 * up + 18.0 * down, 0, 0), "chest": Vector3(0, -15.0 * sgn * (up + down), 0)})
	if ability > 0.0:
		# Slam: both fists overhead, then down into the ground (the hit lands at SLAM_WINDUP).
		var u := 1.0 - ability
		var up := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.3, 0.42, u))
		var down := smoothstep(0.3, 0.42, u) * (1.0 - smoothstep(0.65, 1.0, u))
		_override(pose, up, {
			"spine": Vector3(-14, 0, 0), "chest": Vector3(-10, 0, 0), "head": Vector3(-18, 0, 0),
			"upperarm.L": Vector3(-125, 0, 12), "upperarm.R": Vector3(-125, 0, -12),
			"forearm.L": Vector3(-45, 0, 0), "forearm.R": Vector3(-45, 0, 0),
		})
		_override(pose, down, {
			"spine": Vector3(26, 0, 0), "chest": Vector3(12, 0, 0), "head": Vector3(8, 0, 0),
			"upperarm.L": Vector3(-40, 0, -22), "upperarm.R": Vector3(-40, 0, 22),
			"forearm.L": Vector3(-5, 0, 0), "forearm.R": Vector3(-5, 0, 0),
			"thigh.L": Vector3(-30, 0, -6), "shin.L": Vector3(40, 0, 0), "foot.L": Vector3(-10, 0, 0),
			"thigh.R": Vector3(-30, 0, 6), "shin.R": Vector3(40, 0, 0), "foot.R": Vector3(-10, 0, 0),
		})
		lift = lerpf(lerpf(lift, 0.03, up), 0.0, down)
		contact = maxf(contact, maxf(up, down))
	if ult > 0.0:
		# Quake: crouch, leap with the fists raised, crash down (at QUAKE_WINDUP), then hold the
		# crouch while the crystal waves roll out.
		var u := 1.0 - ult
		var crouch := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.08, 0.14, u))
		var air := smoothstep(0.08, 0.16, u) * (1.0 - smoothstep(0.24, 0.3, u))
		var land := smoothstep(0.24, 0.3, u) * (1.0 - smoothstep(0.7, 1.0, u))
		_override(pose, crouch, {
			"spine": Vector3(20, 0, 0), "upperarm.L": Vector3(30, 0, -10), "upperarm.R": Vector3(30, 0, 10),
			"thigh.L": Vector3(-40, 0, -6), "shin.L": Vector3(55, 0, 0), "foot.L": Vector3(-15, 0, 0),
			"thigh.R": Vector3(-40, 0, 6), "shin.R": Vector3(55, 0, 0), "foot.R": Vector3(-15, 0, 0),
		})
		_override(pose, air, {
			"spine": Vector3(-16, 0, 0), "chest": Vector3(-10, 0, 0), "head": Vector3(-20, 0, 0),
			"upperarm.L": Vector3(-150, 0, 20), "upperarm.R": Vector3(-150, 0, -20),
			"forearm.L": Vector3(-30, 0, 0), "forearm.R": Vector3(-30, 0, 0),
			"thigh.L": Vector3(-20, 0, -4), "shin.L": Vector3(35, 0, 0), "thigh.R": Vector3(10, 0, 4), "shin.R": Vector3(30, 0, 0),
		})
		_override(pose, land, {
			"spine": Vector3(30, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(10, 0, 0),
			"upperarm.L": Vector3(-30, 0, -35), "upperarm.R": Vector3(-30, 0, 35),
			"forearm.L": Vector3(-5, 0, 0), "forearm.R": Vector3(-5, 0, 0),
			"thigh.L": Vector3(-45, 0, -10), "shin.L": Vector3(60, 0, 0), "foot.L": Vector3(-15, 0, 0),
			"thigh.R": Vector3(-45, 0, 10), "shin.R": Vector3(60, 0, 0), "foot.R": Vector3(-15, 0, 0),
		})
		lift = lerpf(lerpf(lift * (1.0 - crouch), 0.35 * sin(PI * clampf((u - 0.08) / 0.2, 0.0, 1.0)), air), 0.0, land)
		contact = maxf(contact, maxf(crouch, maxf(air, land)))
	return Vector2(lift, contact)


