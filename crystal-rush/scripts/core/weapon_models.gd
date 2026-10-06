class_name WeaponModels
## Procedural war machines of the Arsenal and the crates that hold them (arsenal_design.md
## §2.8, §9.7 "full bar"). Team signature: white enamel, thin gold trim, dark navy running gear
## and ice-blue crystals; each FAMILY adds its chassis shape, a glyph and its accent
## (ArsenalData.FAMILIES): Kinetic = wheeled cart with copper plates and a chevron, Plasma =
## hover pod with rose energy rings and an orb, Tech = tracked carrier with lime sensors and a
## reticle, Volt = long six-wheeler with orchid insulator stacks and a bolt. Free machines
## (Drone, Prism) have no chassis and no crew. Chunky toy proportions, bevelled hulls.
##
## Machines face -Z (the run direction) out of the box. Node layout:
##   root (meta role "machine")          <- the run moves / tweens this node (its scale is free)
##     Rig                               <- Rank scale (ArsenalData.RANK_SCALE), dock squash
##       chassis meshes, Axle pivots (meta "wheels"), Crew (operator on the rear step)
##       Yaw                             <- aim() turns it about Y
##         Recoil / Tube / Drum ...      <- moving parts with pivots
##           Muzzle                      <- shots leave here (meta "muzzle")
##     Chevrons (Rank ▲ marks), Aura (Rank II/III ground ring)
## Metas: "kind", "family", "rank" (= "level", 1..3), "yaw", "recoil", "muzzle", "rig",
## "wheels", "star_y", "ascended", "branch".
##
## Rank II = ×1.15 + armour plates (or the module's second barrel / tube / ring); Rank III =
## ×1.3 + gold crest + gold aura and the module's Rank III part. Ascension (Lv8) = an animated
## family-accent sheen over the whole machine (rarity_sheen.gdshader), an accent halo, and for
## Epic+ the branch module (A in Meta-1). animate() drives recoil, wheels, rotors, the mortar
## tube, the gatling drum, the railgun charge, the prism gyro, hover bob and the crew poses.
##
## Asset hook: a GLB at Worlds.LIST[w].models[kind] or res://assets/machines/<kind>.glb
## replaces the procedural body; it is fitted with ArsenalData.FIT[kind] (fit AABB,
## forward_deg, muzzle, parts {name: {node, pivot, axis, speed}}) - see asset_for().

const KINDS: Array[String] = ["ballista", "cannon", "laser", "rockets", "drone", "mortar", "gatling", "railgun", "prism"]
const WHITE := Color(0.93, 0.94, 0.98)
const PEARL := Color(0.72, 0.76, 0.86)
const GOLD := Color(1.0, 0.76, 0.3)
const NAVY := Color(0.14, 0.18, 0.31)
const ICE := Color(0.36, 0.82, 1.0)
const ICE_HOT := Color(0.72, 0.95, 1.0)
const COPPER := Color(0.86, 0.6, 0.46)
## Emissive version of each family accent (the accents of ArsenalData.FAMILIES pushed to full
## brightness so they bloom; the hue is the family's).
const FAMILY_GLOW := {
	"kinetic": Color(1.0, 0.78, 0.6),
	"volt": Color(1.0, 0.52, 1.0),
	"frost": Color(0.95, 1.0, 0.82),
	"plasma": Color(1.0, 0.2, 0.56),
	"tech": Color(0.42, 1.0, 0.16),
	"rune": Color(0.36, 0.42, 1.0),
	"rift": Color(0.92, 0.85, 1.0),
}
const WHEEL_R := 0.17
const DRONE_Y := 0.62
const PRISM_Y := 1.1
const MACHINE_DIR := "res://assets/machines/"
const GLASS_SHADER := preload("res://shaders/weapon_glass.gdshader")
const PILLAR_SHADER := preload("res://shaders/loot_pillar.gdshader")
const SHEEN_SHADER := preload("res://shaders/rarity_sheen.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
## Crate shells by rarity (§2.1 table): body metal, inlay glow, rib glow.
const CRATE_SHELLS := {
	"C": {"body": Color(0.86, 0.88, 0.93), "inlay": Color(0.72, 0.82, 0.95), "metal": 0.55},
	"R": {"body": Color(0.9, 0.93, 1.0), "inlay": Color(0.25, 0.62, 1.0), "metal": 0.2},
	"E": {"body": Color(0.93, 0.9, 1.0), "inlay": Color(0.7, 0.4, 1.0), "metal": 0.2},
	"L": {"body": Color(1.0, 0.96, 0.88), "inlay": Color(1.0, 0.72, 0.2), "metal": 0.2},
	"M": {"body": Color(0.97, 0.95, 1.0), "inlay": Color(0.9, 0.8, 1.0), "metal": 0.2},
	"new": {"body": Color(0.96, 0.97, 1.0), "inlay": Color(0.85, 0.95, 1.0), "metal": 0.75},
}

static var _meshes := {}
static var _mats := {}
static var _ring_tex: Texture2D
static var _font: Font


## Family accent of a machine (ArsenalData.FAMILIES): HUD chips, projectile and muzzle tints.
static func icon_color(kind: String) -> Color:
	if ArsenalData.MACHINES.has(kind):
		return ArsenalData.accent(kind)
	return ICE


## Emissive (bloom) colour of a machine's family accent: beams, glows, rings.
static func glow_color(kind: String) -> Color:
	if ArsenalData.MACHINES.has(kind):
		return FAMILY_GLOW.get(ArsenalData.family_of(kind), ICE)
	return ICE


static func _family(kind: String) -> String:
	return ArsenalData.family_of(kind) if ArsenalData.MACHINES.has(kind) else "kinetic"


static func _mount(kind: String) -> String:
	if not ArsenalData.MACHINES.has(kind):
		return "chassis_kinetic"
	return str((ArsenalData.MACHINES[kind] as Dictionary).get("mount", "chassis_kinetic"))


static func _has_crew(kind: String) -> bool:
	return ArsenalData.MACHINES.has(kind) and bool((ArsenalData.MACHINES[kind] as Dictionary).get("crew", false))


## A war machine of `kind` (KINDS; other ids get a family stand-in). `opts`:
##   rank 1..3 (default 1), ascended (bool), branch "a"|"b" (Epic+), crew (bool; default from
##   ArsenalData.MACHINES[kind].crew), mini (bool: no crew, for crate windows and icons).
static func machine(kind: String, opts := {}) -> Node3D:
	var root := _machine_body(kind, opts)
	set_rank(root, int(opts.get("rank", 1)))
	if bool(opts.get("ascended", false)):
		set_ascended(root, true, str(opts.get("branch", "a")))
	return root


static func _machine_body(kind: String, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Machine_" + kind
	root.set_meta("kind", kind)
	root.set_meta("role", "machine")
	root.set_meta("level", 1)
	root.set_meta("rank", 1)
	root.set_meta("family", _family(kind))
	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	root.set_meta("rig", rig)
	var crew := bool(opts.get("crew", _has_crew(kind))) and not bool(opts.get("mini", false))
	var glb := asset_for(kind)
	if glb != null:
		_from_asset(root, rig, kind, glb, crew)
		return root
	var yaw := Node3D.new()
	yaw.name = "Yaw"
	var recoil := Node3D.new()
	recoil.name = "Recoil"
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	var ctx := {"root": root, "rig": rig, "yaw": yaw, "recoil": recoil, "muzzle": muzzle, "kind": kind,
		"groups": [], "star_y": 1.05, "deck": 0.44, "half": 0.28, "crest": Vector3(0, 0.3, 0.1), "crest_parent": yaw}
	var mount := _mount(kind)
	if kind == "drone" or kind == "prism" or mount == "free":
		var hover := Node3D.new()
		hover.name = "Hover"
		hover.position = Vector3(0, PRISM_Y if kind == "prism" else DRONE_Y, 0)
		if kind == "prism":
			# The Legendary reads big: it floats alone in the hero's lane.
			hover.scale = Vector3.ONE * 1.25
		rig.add_child(hover)
		hover.add_child(yaw)
		root.set_meta("hover", hover)
		root.set_meta("hover_y", hover.position.y)
		if kind == "prism":
			_prism(ctx)
		else:
			_drone(ctx)
	else:
		match mount:
			"chassis_plasma":
				_chassis_plasma(ctx)
			"chassis_tech":
				_chassis_tech(ctx)
			"chassis_volt":
				_chassis_volt(ctx)
			_:
				_chassis_kinetic(ctx)
		yaw.position = Vector3(0, float(ctx["deck"]), 0)
		rig.add_child(yaw)
		match kind:
			"ballista":
				_ballista(ctx)
			"cannon":
				_cannon(ctx)
			"laser":
				_laser(ctx)
				ctx["star_y"] = 1.12
			"rockets":
				_rockets(ctx)
			"mortar":
				_mortar(ctx)
				ctx["star_y"] = 1.12
			"gatling":
				_gatling(ctx)
			"railgun":
				_railgun(ctx)
			_:
				_standin(ctx)
		_armour(ctx)
		if crew:
			_crew(ctx)
	if recoil.get_parent() == null:
		yaw.add_child(recoil)
	if muzzle.get_parent() == null:
		recoil.add_child(muzzle)
	if kind != "prism" and kind != "drone" or ctx.has("crest_force"):
		_crest(ctx)
	_halo(ctx)
	root.set_meta("yaw", yaw)
	root.set_meta("yaw_y", yaw.position.y)
	root.set_meta("recoil", recoil)
	root.set_meta("muzzle", muzzle)
	root.set_meta("star_y", float(ctx["star_y"]))
	root.set_meta("groups", ctx["groups"])
	if not root.has_meta("wheels"):
		root.set_meta("wheels", [])
	Mats.bake(rig)
	return root


## Registers a pivot that is only visible for Rank `lo`..`hi` and/or a given ascension state
## (`asc` "" = any, "on" = ascended, "off" = not ascended, "a"/"b" = that branch).
static func _group(ctx: Dictionary, parent: Node3D, gname: String, lo := 1, hi := 3, asc := "", pos := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	g.position = pos
	parent.add_child(g)
	(ctx["groups"] as Array).append({"node": g, "lo": lo, "hi": hi, "asc": asc})
	return g


static func _apply_groups(node: Node3D) -> void:
	var rank := int(node.get_meta("rank", 1))
	var asc := bool(node.get_meta("ascended", false))
	var br := str(node.get_meta("branch", "a"))
	for g: Dictionary in node.get_meta("groups", []):
		var n := g["node"] as Node3D
		if not is_instance_valid(n):
			continue
		var vis := rank >= int(g["lo"]) and rank <= int(g["hi"])
		match str(g["asc"]):
			"on":
				vis = vis and asc
			"off":
				vis = vis and not asc
			"a", "b":
				vis = vis and asc and br == str(g["asc"])
		n.visible = vis


# ------------------------------------------------------------------ asset hook

## The owner's sculpted machine for `kind`, fitted with ArsenalData.FIT[kind], or null.
static func asset_for(kind: String) -> Node3D:
	var fit: Dictionary = ArsenalData.FIT.get(kind, {})
	var box: AABB = fit.get("fit", AABB(Vector3(-0.4, 0, -0.5), Vector3(0.8, 0.85, 1.0)))
	return asset(kind, box, float(fit.get("forward_deg", 0.0)))


## Optional sculpted override: a GLB listed in a world's "models" under `key` (or
## res://assets/machines/<key>.glb), turned by `forward_deg` about Y and scaled to fit `fit`
## (bottom centred). Returns null when no file exists.
static func asset(key: String, fit: AABB, forward_deg := 0.0) -> Node3D:
	var paths: Array[String] = []
	for w: Dictionary in Worlds.LIST.values():
		var p := str((w.get("models", {}) as Dictionary).get(key, ""))
		if p != "":
			paths.append(p)
	paths.append(MACHINE_DIR + key + ".glb")
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var raw := scene.instantiate() as Node3D
		var inst := Node3D.new()
		inst.name = "Asset_" + key
		inst.add_child(raw)
		raw.rotation.y = deg_to_rad(forward_deg)
		var box := _visual_aabb(inst, Transform3D.IDENTITY)
		if box.size.length() < 0.0001:
			return inst
		var k := minf(fit.size.x / box.size.x, minf(fit.size.y / box.size.y, fit.size.z / box.size.z))
		inst.scale = Vector3.ONE * k
		var centre := box.get_center() * k
		inst.position = Vector3(fit.get_center().x - centre.x, fit.position.y - box.position.y * k, fit.get_center().z - centre.z)
		return inst
	return null


static func _from_asset(root: Node3D, rig: Node3D, kind: String, glb: Node3D, crew: bool) -> void:
	var fit: Dictionary = ArsenalData.FIT.get(kind, {})
	var box: AABB = fit.get("fit", AABB(Vector3(-0.4, 0, -0.5), Vector3(0.8, 0.85, 1.0)))
	var yaw := Node3D.new()
	yaw.name = "Yaw"
	rig.add_child(yaw)
	yaw.add_child(glb)
	var recoil := Node3D.new()
	recoil.name = "Recoil"
	yaw.add_child(recoil)
	var mz := Node3D.new()
	mz.name = "Muzzle"
	mz.position = fit.get("muzzle", Vector3(0, 0.45, -0.55))
	recoil.add_child(mz)
	# Named moving parts: wrap each in a pivot so animate() can spin it.
	var spins: Array[Dictionary] = []
	var parts: Dictionary = fit.get("parts", {})
	var sheet: Dictionary = (ArsenalData.MACHINES.get(kind, {}) as Dictionary).get("parts", {})
	for pname: String in parts:
		var spec: Dictionary = parts[pname]
		var src := glb.find_child(str(spec.get("node", pname)), true, false) as Node3D
		if src == null:
			continue
		var pivot := Node3D.new()
		pivot.name = "Part_" + pname
		pivot.position = spec.get("pivot", Vector3.ZERO)
		yaw.add_child(pivot)
		var xf := _xform_to(src, yaw)
		src.get_parent().remove_child(src)
		pivot.add_child(src)
		src.transform = pivot.transform.affine_inverse() * xf
		var s2: Dictionary = sheet.get(pname, {})
		spins.append({"node": pivot, "axis": spec.get("axis", s2.get("axis", Vector3.FORWARD)),
			"speed": float(spec.get("speed", s2.get("speed", 0.0))), "firing": float(s2.get("speed_firing", spec.get("speed", s2.get("speed", 0.0))))})
	root.set_meta("spin_parts", spins)
	var ctx := {"root": root, "rig": rig, "yaw": yaw, "recoil": recoil, "muzzle": mz, "kind": kind, "groups": [],
		"star_y": box.end.y + 0.2, "deck": box.size.y * 0.5, "half": box.size.x * 0.5,
		"crest": Vector3(0, box.end.y, box.end.z - box.size.z * 0.3), "crest_parent": yaw, "len": box.size.z}
	if crew:
		ctx["step_z"] = box.end.z + 0.04
		_crew(ctx)
	_crest(ctx)
	_halo(ctx)
	root.set_meta("yaw", yaw)
	root.set_meta("yaw_y", 0.0)
	root.set_meta("recoil", recoil)
	root.set_meta("muzzle", mz)
	root.set_meta("wheels", [])
	root.set_meta("star_y", float(ctx["star_y"]))
	root.set_meta("groups", ctx["groups"])
	root.set_meta("asset", true)


static func _xform_to(n: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _visual_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for ch in n.get_children():
		var t: Transform3D = xf * (ch as Node3D).transform if ch is Node3D else xf
		if ch is VisualInstance3D:
			var b := t * (ch as VisualInstance3D).get_aabb()
			out = b if first else out.merge(b)
			first = false
		var sub := _visual_aabb(ch, t)
		if sub.size != Vector3.ZERO:
			out = sub if first else out.merge(sub)
			first = false
	return out


## Measured fit data of a procedural machine (dev: gallery_meta_models --view=fit prints these
## for ArsenalData.FIT): {fit: AABB, deck_y, yaw_pivot, muzzle, forward_deg}.
static func measure(kind: String) -> Dictionary:
	var m := machine(kind, {"crew": false})
	var rig := m.get_meta("rig") as Node3D
	var box := _visual_aabb(rig, rig.transform)
	var yaw := m.get_meta("yaw") as Node3D
	var mz := m.get_meta("muzzle") as Node3D
	var out := {"fit": box, "deck_y": float(m.get_meta("yaw_y", 0.0)), "yaw_pivot": _xform_to(yaw, m).origin,
		"muzzle": _xform_to(mz, m).origin, "forward_deg": 0.0}
	m.free()
	return out


# ------------------------------------------------------------------ rank, ascension, dock

## Rank (1..3) of a fielded machine: Rig scale, Rank parts, ▲ chevrons and the ground aura.
static func set_rank(node: Node3D, rank: int) -> void:
	rank = clampi(rank, 1, 3)
	node.set_meta("rank", rank)
	node.set_meta("level", rank)
	var rig: Node3D = _nm(node, "rig")
	if rig:
		rig.scale = Vector3.ONE * ArsenalData.RANK_SCALE[rank - 1]
	_apply_groups(node)
	for n in ["Stars", "Chevrons", "Aura"]:
		var old := node.get_node_or_null(n)
		if old:
			node.remove_child(old)
			old.queue_free()
	var chev := Node3D.new()
	chev.name = "Chevrons"
	chev.position = Vector3(0, float(node.get_meta("star_y", 1.05)) * ArsenalData.RANK_SCALE[rank - 1], 0)
	node.add_child(chev)
	var mi := MeshInstance3D.new()
	mi.mesh = _chevron_mesh(rank)
	mi.material_override = _star_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chev.add_child(mi)
	node.set_meta("stars", chev)
	if rank >= 2:
		var aura := MeshInstance3D.new()
		aura.name = "Aura"
		aura.mesh = Mats.quad(Vector2(1.5, 1.5) * ArsenalData.RANK_SCALE[rank - 1])
		aura.material_override = _aura_material(ICE if rank == 2 else GOLD)
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.position = Vector3(0, 0.03, 0)
		node.add_child(aura)


## Etap-1 name of set_rank() (the run still calls it; ★ stars became ▲ Rank chevrons).
static func set_level(node: Node3D, level: int) -> void:
	set_rank(node, level)


## Ascension look (Lv8, §2.1): an animated sheen in the family accent over the whole machine,
## an accent halo, and for Epic+ machines the branch module ("a" in Meta-1).
static func set_ascended(node: Node3D, on: bool, branch := "a") -> void:
	node.set_meta("ascended", on)
	node.set_meta("branch", branch)
	_apply_groups(node)
	var rig: Node3D = _nm(node, "rig")
	if rig == null:
		return
	var mat: ShaderMaterial = null
	if on:
		mat = ShaderMaterial.new()
		mat.shader = SHEEN_SHADER
		var c := glow_color(str(node.get_meta("kind", "")))
		mat.set_shader_parameter("color", c)
		mat.set_shader_parameter("strength", 1.3)
		mat.set_shader_parameter("rim_power", 1.3)
	_overlay(rig, mat)


static func _overlay(n: Node, mat: Material) -> void:
	for ch in n.get_children():
		if ch is GeometryInstance3D and not (ch as Node).has_meta("no_sheen"):
			(ch as GeometryInstance3D).material_overlay = mat
		_overlay(ch, mat)


## Docking pose (§2.8): `u` 0 = folded inside the crate shell, 1 = deployed. The caller moves
## the machine (skid into the convoy slot, ≤ 0.8 s); this unfolds it: body squash and stretch,
## the turret rising from the hull and swinging forward, the crew hopping on last.
static func dock(node: Node3D, u: float) -> void:
	u = clampf(u, 0.0, 1.0)
	var rig: Node3D = _nm(node, "rig")
	var yaw: Node3D = _nm(node, "yaw")
	var rs: float = ArsenalData.RANK_SCALE[int(node.get_meta("rank", 1)) - 1]
	var v := u - 1.0
	var back := 1.0 + 2.70158 * v * v * v + 1.70158 * v * v  # ease-out-back
	if rig:
		var sy := lerpf(0.45, 1.0, back)
		var sxz := lerpf(0.75, 1.0, clampf(u * 1.6, 0.0, 1.0))
		rig.scale = Vector3(sxz, sy, sxz) * rs
	if yaw:
		var y0 := float(node.get_meta("yaw_y", yaw.position.y))
		var tu := smoothstep(0.25, 0.85, u)
		yaw.position.y = y0 - (1.0 - tu) * 0.22
		yaw.rotation.x = (1.0 - tu) * 0.9
	var crew: Node3D = _nm(node, "crew")
	if crew:
		var cu := smoothstep(0.6, 0.95, u)
		crew.scale = Vector3.ONE * maxf(cu, 0.001)
	var chev: Node3D = _nm(node, "stars")
	if chev:
		chev.visible = u >= 0.98


## Crew pose: "idle" (breathing, looks around), "load" (arms forward, follows the shot kick)
## or "cheer" (arms up, bouncing; Rank-up and victory).
static func set_crew_pose(node: Node3D, pose: String) -> void:
	node.set_meta("crew_pose", pose)


## Railgun (or any charging machine) charge 0..1: rails and capacitors glow brighter, the slug
## between the rails grows. animate() reads it.
static func set_charge(node: Node3D, k: float) -> void:
	node.set_meta("charge", clampf(k, 0.0, 1.0))


## Mortar tube pitch in degrees (35..60, design §2.5 parts). Default 50.
static func set_pitch(node: Node3D, deg: float) -> void:
	node.set_meta("pitch", clampf(deg, 35.0, 60.0))


## Turns the machine's yaw node so the muzzle faces `target` (world space). `weight` < 1
## eases towards it (call every frame with e.g. 1 - exp(-12 * delta)).
static func aim(node: Node3D, target: Vector3, weight := 1.0) -> void:
	var yaw: Node3D = _nm(node, "yaw")
	if yaw == null or not node.is_inside_tree():
		return
	var parent := yaw.get_parent() as Node3D
	var local := parent.global_transform.affine_inverse() * target - yaw.position
	if Vector2(local.x, local.z).length_squared() < 0.0001:
		return
	var want := atan2(-local.x, -local.z)
	yaw.rotation.y = lerp_angle(yaw.rotation.y, want, clampf(weight, 0.0, 1.0))


## Animates a machine or a crate. `t` is the run time in seconds, `fire` 0..1 is the shot
## kick (1 right after a shot, decaying to 0). For the laser it is the beam intensity and for
## the gatling the barrel spin (0 idle .. 1 full rate). `roll` is the distance travelled for
## the wheels (by default t × Balance.RUN_SPEED).
static func animate(node: Node3D, t: float, fire: float, roll := -1.0) -> void:
	if str(node.get_meta("role", "")) == "crate":
		_animate_crate(node, t, fire)
		return
	var kind := str(node.get_meta("kind", ""))
	var last := float(node.get_meta("last_t", t))
	var dt := clampf(t - last, 0.0, 0.1)
	node.set_meta("last_t", t)
	fire = clampf(fire, 0.0, 1.0)
	var kick := fire * fire * (3.0 - 2.0 * fire)
	var dist := roll if roll >= 0.0 else t * Balance.RUN_SPEED
	for w: Node3D in node.get_meta("wheels", []):
		w.rotation.x = -dist / float(w.get_meta("r", WHEEL_R))
	var body: Node3D = _nm(node, "float_body")
	if body:
		body.position.y = sin(t * 2.4) * 0.018
		body.rotation.z = sin(t * 1.3) * 0.02
	for sp: Dictionary in node.get_meta("spin_parts", []):
		var pn := sp["node"] as Node3D
		var spd := lerpf(float(sp["speed"]), float(sp["firing"]), fire)
		pn.rotate_object_local(sp["axis"] as Vector3, spd * dt)
	_animate_crew(node, t, kick)
	var halo: Node3D = _nm(node, "halo")
	if halo and halo.visible:
		halo.rotation.y = fposmod(t * 0.8, TAU)
	var recoil: Node3D = _nm(node, "recoil")
	if recoil == null:
		return
	match kind:
		"ballista":
			recoil.position.z = kick * 0.12
			for b: Node3D in node.get_meta("bolts", []):
				b.scale = Vector3.ONE * maxf(clampf(1.0 - fire * 1.6, 0.0, 1.0), 0.001)
			for arm: Node3D in node.get_meta("arms", []):
				arm.rotation.y = float(arm.get_meta("side")) * (0.32 * kick - 0.05)
		"cannon":
			recoil.position.z = kick * 0.16
			var core: Node3D = _nm(node, "core")
			if core:
				core.scale = Vector3.ONE * (1.0 + 0.5 * kick + 0.08 * sin(t * 9.0))
		"laser":
			var gem: Node3D = _nm(node, "gem")
			if gem:
				gem.rotation.z = fposmod(t * (1.5 + fire * 10.0), TAU)
				gem.scale = Vector3.ONE * (1.0 + fire * 0.18 + 0.04 * sin(t * 6.0))
			var lens: Node3D = _nm(node, "lens")
			if lens:
				var a := float(node.get_meta("lens_a", 0.0)) + dt * lerpf(2.0, 12.0, fire)
				node.set_meta("lens_a", fposmod(a, TAU))
				lens.rotation.z = a
			recoil.position.z = 0.02 * fire * sin(t * 40.0)
		"rockets":
			recoil.position.z = kick * 0.1
			for tips: Node3D in node.get_meta("tips", []):
				tips.scale = Vector3.ONE * maxf(clampf(1.0 - fire * 1.4, 0.0, 1.0), 0.001)
		"drone":
			var hover: Node3D = _nm(node, "hover")
			if hover:
				hover.position.y = DRONE_Y + sin(t * 2.6) * 0.05
				hover.rotation.z = sin(t * 1.7) * 0.06
				hover.rotation.x = sin(t * 2.1) * 0.04 + kick * 0.12
			for r: Node3D in node.get_meta("rotors", []):
				r.rotation.y = fposmod(t * 38.0 * (1.0 if r.get_meta("cw") else -1.0), TAU)
			var wing: Node3D = _nm(node, "wingman")
			if wing and wing.visible:
				var a2 := fposmod(t * 1.4, TAU)
				wing.position = Vector3(cos(a2) * 0.62, 0.12 + sin(t * 3.1) * 0.05, sin(a2) * 0.62)
				wing.rotation.y = -a2
			recoil.position.z = kick * 0.05
		"mortar":
			var tube: Node3D = _nm(node, "tube")
			if tube:
				var pitch := float(node.get_meta("pitch", 50.0))
				tube.rotation.x = deg_to_rad(pitch - kick * 6.0)
			recoil.position.z = kick * 0.14
		"gatling":
			var drum: Node3D = _nm(node, "drum")
			if drum:
				var a3 := float(node.get_meta("drum_a", 0.0)) + dt * lerpf(0.6, 30.0, fire)
				node.set_meta("drum_a", fposmod(a3, TAU))
				drum.rotation.z = a3
			recoil.position.z = 0.012 * fire * sin(t * 70.0)
			recoil.position.x = 0.006 * fire * sin(t * 53.0)
		"railgun":
			var ch := float(node.get_meta("charge", 0.0))
			var glow := maxf(ch, kick)
			for m: StandardMaterial3D in node.get_meta("charge_mats", []):
				m.emission_energy_multiplier = 0.35 + glow * 4.2 + 0.25 * ch * sin(t * 30.0)
			var slug: Node3D = _nm(node, "slug")
			if slug:
				slug.scale = Vector3.ONE * maxf(ch * (1.0 + 0.1 * sin(t * 40.0)), 0.001)
				slug.visible = ch > 0.02
			recoil.position.z = kick * 0.22
		"prism":
			var hover2: Node3D = _nm(node, "hover")
			if hover2:
				hover2.position.y = PRISM_Y + sin(t * 1.8) * 0.06
			var gyro_a: Node3D = _nm(node, "gyro_a")
			var gyro_b: Node3D = _nm(node, "gyro_b")
			var gyro_c: Node3D = _nm(node, "gyro_c")
			var sp := 1.5 + fire * 6.0
			if gyro_a:
				gyro_a.rotation.x = fposmod(t * sp * 0.7, TAU)
			if gyro_b:
				gyro_b.rotation.y = fposmod(t * sp, TAU)
			if gyro_c and gyro_c.visible:
				gyro_c.rotation.z = fposmod(-t * sp * 0.8, TAU)
			var body2: Node3D = _nm(node, "prism_body")
			if body2:
				body2.rotation.y = fposmod(t * 0.9, TAU)
				body2.scale = Vector3.ONE * (1.0 + kick * 0.16)
			var crown: Node3D = _nm(node, "crown")
			if crown and crown.visible:
				crown.rotation.y = fposmod(-t * 1.2, TAU)
		_:
			recoil.position.z = kick * 0.1


static func _animate_crew(node: Node3D, t: float, kick: float) -> void:
	var crew: Node3D = _nm(node, "crew")
	if crew == null or not crew.visible:
		return
	var arms: Array = crew.get_meta("arms")
	var pose := str(node.get_meta("crew_pose", "idle"))
	var breathe := sin(t * TAU / 1.6)
	crew.scale = Vector3(1.0, 1.0 + 0.025 * breathe, 1.0)
	var load := kick if pose == "idle" else (1.0 if pose == "load" else 0.0)
	crew.rotation.y = sin(t * 0.7) * 0.18 * (1.0 - load)
	crew.position.y = float(crew.get_meta("y0")) + (absf(sin(t * 7.0)) * 0.05 if pose == "cheer" else 0.0)
	for i in arms.size():
		var arm := arms[i] as Node3D
		var side := -1.0 if i == 0 else 1.0
		if pose == "cheer":
			arm.rotation = Vector3(2.7 + sin(t * 9.0 + i) * 0.25, 0, side * 0.35)
		else:
			arm.rotation = Vector3(lerpf(0.12 + 0.05 * breathe, 1.35, load), 0, side * lerpf(0.18, 0.05, load))


# ------------------------------------------------------------------ materials

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"white":
			m = Mats.solid(WHITE, 0.35, 0.2)
		"pearl":
			m = Mats.solid(PEARL, 0.45, 0.25)
		"gold":
			m = Mats.solid(GOLD, 0.3, 0.85)
		"navy":
			m = Mats.solid(NAVY, 0.55, 0.3)
		"tyre":
			# Metallic 0.3 puts tyres in the baked "metal" class with the gold: one draw call
			# for a whole wheel row.
			m = Mats.solid(Color(0.1, 0.12, 0.2), 0.8, 0.3)
		"copper":
			m = Mats.solid(COPPER, 0.32, 0.8)
		"steel":
			m = Mats.solid(Color(0.8, 0.84, 0.92), 0.3, 0.7)
		"ice":
			m = Mats.glow(ICE, 2.0)
		"hot":
			m = Mats.glow(ICE_HOT, 2.6)
		_:
			if key.begins_with("acc_"):
				m = Mats.glow(FAMILY_GLOW.get(key.trim_prefix("acc_"), ICE), 2.4)
			elif key.begins_with("accd_"):
				m = Mats.glow(FAMILY_GLOW.get(key.trim_prefix("accd_"), ICE), 1.1)
			else:
				m = Mats.solid(Color.MAGENTA)
	_mats[key] = m
	return m


## A glow material of its own (not baked) for parts whose brightness animates.
static func _dyn_glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


## Mats.part with a named material.
static func _p(parent: Node3D, mesh: Mesh, key: String, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var glowing := key in ["ice", "hot"] or key.begins_with("acc")
	return Mats.part(parent, mesh, _mat(key), pos, rot, scl, not glowing)


# ------------------------------------------------------------------ family chassis

## Shared rear step the crew stands on, and the rear deck crystals (team signature).
## The family emblem on the hull's rear face (the face the run camera sees): `y` its height.
static func _rear(ctx: Dictionary, z_end: float, y: float, half: float, emblem_y := -1.0) -> void:
	var rig: Node3D = ctx["rig"]
	_p(rig, bevel_box(Vector3(0.36, 0.035, 0.15), 0.012), "pearl", Vector3(0, y, z_end + 0.07))
	_p(rig, bevel_box(Vector3(0.38, 0.02, 0.02), 0.006), "gold", Vector3(0, y + 0.02, z_end + 0.145))
	for sx: float in [-1.0, 1.0]:
		_p(rig, bevel_box(Vector3(0.03, 0.12, 0.03), 0.008), "gold", Vector3(0.17 * sx, y - 0.06, z_end + 0.02))
	ctx["step_z"] = z_end + 0.07
	ctx["step_y"] = y + 0.018
	ctx["crew_x"] = 0.1
	ctx["half"] = half
	_emblem(rig, _family(str(ctx["kind"])), Vector3(-0.12, emblem_y if emblem_y > 0.0 else y + 0.09, z_end + 0.012), 1.0)


## Family glyph on a gold-rimmed navy plate facing +Z (§2.1 glyphs: Kinetic chevron, Volt
## bolt, Plasma orb, Tech reticle; Frost / Rune / Rift fall back to a crystal).
static func _emblem(parent: Node3D, fam: String, pos: Vector3, k: float) -> void:
	var acc := "acc_" + fam
	_p(parent, Mats.cyl(0.075 * k, 0.075 * k, 0.02, 12, false), "gold", pos, Vector3(90, 0, 0))
	_p(parent, Mats.cyl(0.062 * k, 0.062 * k, 0.024, 12, false), "navy", pos + Vector3(0, 0, 0.002), Vector3(90, 0, 0))
	var f := pos + Vector3(0, 0, 0.016)
	match fam:
		"kinetic":
			for sx: float in [-1.0, 1.0]:
				_p(parent, Mats.box(Vector3(0.062 * k, 0.018 * k, 0.012)), acc, f + Vector3(0.021 * sx, 0.0, 0) * k, Vector3(0, 0, 38.0 * sx))
			for sx: float in [-1.0, 1.0]:
				_p(parent, Mats.box(Vector3(0.05 * k, 0.014 * k, 0.012)), acc, f + Vector3(0.017 * sx, -0.028, 0) * k, Vector3(0, 0, 38.0 * sx))
		"plasma":
			_p(parent, Mats.torus(0.03 * k, 0.04 * k, 14, 4), acc, f, Vector3(90, 0, 0))
			_p(parent, Mats.sphere(0.018 * k, -1, 8, 4), acc, f)
		"tech":
			_p(parent, Mats.torus(0.026 * k, 0.034 * k, 14, 4), acc, f, Vector3(90, 0, 0))
			for q in 4:
				var a := TAU * q / 4.0
				_p(parent, Mats.box(Vector3(0.008, 0.02, 0.01) * k), acc, f + Vector3(cos(a), sin(a), 0) * 0.044 * k, Vector3(0, 0, rad_to_deg(a) + 90.0))
			_p(parent, Mats.sphere(0.008 * k, -1, 6, 3), acc, f)
		"volt":
			var pts: Array[Vector3] = [Vector3(0.018, 0.04, 0), Vector3(-0.008, 0.002, 0), Vector3(0.01, -0.004, 0), Vector3(-0.016, -0.042, 0)]
			for i in pts.size() - 1:
				var a2 := pts[i] * k
				var b2 := pts[i + 1] * k
				_p(parent, Mats.box(Vector3(0.016 * k, a2.distance_to(b2) + 0.008, 0.012)), acc, f + (a2 + b2) * 0.5, Vector3(0, 0, rad_to_deg(atan2(b2.x - a2.x, a2.y - b2.y))))
		_:
			_p(parent, Mats.crystal(0.025 * k, 0.08 * k), acc, f)


## Kinetic: a bevelled white cart on four spoked wheels, copper side armour with rivets, a
## copper chevron on the nose, crystal headlights.
static func _chassis_kinetic(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig"]
	_p(rig, bevel_box(Vector3(0.56, 0.17, 0.86), 0.05), "white", Vector3(0, 0.31, 0))
	_p(rig, bevel_box(Vector3(0.62, 0.06, 0.92), 0.02), "gold", Vector3(0, 0.215, 0))
	_p(rig, bevel_box(Vector3(0.44, 0.1, 0.74), 0.02), "navy", Vector3(0, 0.16, 0))
	for sx: float in [-1.0, 1.0]:
		_p(rig, bevel_box(Vector3(0.035, 0.1, 0.46), 0.012), "copper", Vector3(0.29 * sx, 0.315, 0.0))
		for z: float in [-0.16, 0.0, 0.16]:
			_p(rig, Mats.sphere(0.018, -1, 8, 4), "gold", Vector3(0.31 * sx, 0.315, z))
		_p(rig, bevel_box(Vector3(0.09, 0.06, 0.03), 0.012), "hot", Vector3(0.17 * sx, 0.31, -0.435))
	# Copper chevron glyph on the nose.
	for sx: float in [-1.0, 1.0]:
		_p(rig, bevel_box(Vector3(0.13, 0.035, 0.03), 0.008), "copper", Vector3(0.045 * sx, 0.33, -0.44), Vector3(0, 0, -32.0 * sx))
	_p(rig, Mats.cyl(0.2, 0.235, 0.06, 20, false), "gold", Vector3(0, 0.42, -0.04))
	_p(rig, bevel_box(Vector3(0.44, 0.05, 0.16), 0.015), "pearl", Vector3(0, 0.41, 0.3))
	for sx: float in [-1.0, 1.0]:
		_p(rig, Mats.crystal(0.04, 0.16), "ice", Vector3(0.2 * sx, 0.47, 0.33))
	_wheels(ctx, [-0.27, 0.27], 0.33, WHEEL_R, "copper")
	_rear(ctx, 0.43, 0.235, 0.28, 0.33)
	ctx["deck"] = 0.44


## Plasma: a rounded white hover pod on four glowing pads, a rose energy ring round its waist,
## a rose orb glyph on the nose; it floats instead of rolling (meta "float_body").
static func _chassis_plasma(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig"]
	var body := Node3D.new()
	body.name = "Float"
	rig.add_child(body)
	ctx["root"].set_meta("float_body", body)
	_p(body, Mats.sphere(0.32, 0.3, 22, 9, false), "white", Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.42))
	_p(body, Mats.torus(0.3, 0.345, 32, 6), "gold", Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.42))
	_p(body, Mats.torus(0.27, 0.31, 32, 6), "acc_plasma", Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.42))
	_p(body, Mats.cyl(0.24, 0.27, 0.06, 20, false), "navy", Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.4))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pad := Vector3(0.27 * sx, 0.16, 0.3 * sz)
			_p(body, Mats.cyl(0.09, 0.1, 0.08, 14, false), "white", pad)
			_p(body, Mats.cyl(0.1, 0.1, 0.025, 14, false), "gold", pad + Vector3(0, 0.045, 0))
			_p(body, Mats.cyl(0.065, 0.065, 0.02, 14, false), "acc_plasma", pad + Vector3(0, -0.045, 0))
		_p(body, bevel_box(Vector3(0.09, 0.05, 0.03), 0.012), "hot", Vector3(0.15 * sx, 0.31, -0.445))
	# Orb glyph on the nose.
	_p(body, Mats.torus(0.045, 0.07, 16, 5), "gold", Vector3(0, 0.36, -0.44), Vector3(90, 0, 0))
	_p(body, Mats.sphere(0.04, -1, 10, 6), "acc_plasma", Vector3(0, 0.36, -0.445))
	_p(body, Mats.cyl(0.2, 0.235, 0.05, 20, false), "gold", Vector3(0, 0.455, -0.02))
	for sx: float in [-1.0, 1.0]:
		_p(body, Mats.crystal(0.035, 0.15), "ice", Vector3(0.17 * sx, 0.46, 0.3))
	# Under-glow pool on the road.
	var pool := MeshInstance3D.new()
	pool.name = "HoverGlow"
	pool.mesh = Mats.quad(Vector2(1.0, 1.25))
	pool.material_override = _pool_material(FAMILY_GLOW["plasma"])
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.025, 0)
	pool.set_meta("no_sheen", true)
	rig.add_child(pool)
	ctx["rig_body"] = body
	_rear(ctx, 0.455, 0.2, 0.33, 0.33)
	# The step hangs from the floating pod.
	for ch in rig.get_children():
		if ch is MeshInstance3D and ch != pool:
			rig.remove_child(ch)
			body.add_child(ch)
	ctx["deck"] = 0.47
	ctx["root"].set_meta("wheels", [])


## Tech: a tracked carrier - two navy treads with white track plates and gold sprockets
## (they turn), white mudguards with lime sensors, a lime reticle glyph and an antenna.
static func _chassis_tech(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig"]
	_p(rig, bevel_box(Vector3(0.36, 0.16, 0.74), 0.04), "white", Vector3(0, 0.3, 0))
	_p(rig, bevel_box(Vector3(0.3, 0.06, 0.64), 0.02), "navy", Vector3(0, 0.19, 0))
	var wheels: Array[Node3D] = []
	for sx: float in [-1.0, 1.0]:
		var x := 0.25 * sx
		_p(rig, bevel_box(Vector3(0.15, 0.2, 0.66), 0.05), "tyre", Vector3(x, 0.12, 0))
		for k in 8:
			_p(rig, bevel_box(Vector3(0.155, 0.02, 0.055), 0.006), "pearl", Vector3(x, 0.225, -0.28 + k * 0.08))
		_p(rig, bevel_box(Vector3(0.19, 0.03, 0.86), 0.012), "white", Vector3(x, 0.255, 0))
		_p(rig, bevel_box(Vector3(0.2, 0.012, 0.6), 0.004), "gold", Vector3(x, 0.273, 0))
		_p(rig, bevel_box(Vector3(0.05, 0.035, 0.03), 0.01), "acc_tech", Vector3(x, 0.26, -0.44))
		for sz: float in [-1.0, 1.0]:
			var axle := Node3D.new()
			axle.name = "Sprocket"
			axle.position = Vector3(x, 0.12, 0.33 * sz)
			axle.set_meta("r", 0.1)
			rig.add_child(axle)
			_p(axle, Mats.cyl(0.1, 0.1, 0.165, 10, true), "tyre", Vector3.ZERO, Vector3(0, 0, 90))
			_p(axle, Mats.cyl(0.07, 0.07, 0.17, 6, true), "gold", Vector3.ZERO, Vector3(0, 0, 90))
			_p(axle, Mats.box(Vector3(0.175, 0.13, 0.025)), "navy", Vector3.ZERO)
			wheels.append(axle)
	ctx["root"].set_meta("wheels", wheels)
	# Reticle glyph on the nose.
	_p(rig, Mats.torus(0.05, 0.068, 18, 4), "acc_tech", Vector3(0, 0.31, -0.375), Vector3(90, 0, 0))
	for k in 4:
		var a := TAU * k / 4.0
		_p(rig, Mats.box(Vector3(0.012, 0.04, 0.012)), "acc_tech", Vector3(cos(a) * 0.08, 0.31 + sin(a) * 0.08, -0.375), Vector3(0, 0, rad_to_deg(a) + 90.0))
	_p(rig, Mats.cyl(0.2, 0.235, 0.06, 20, false), "gold", Vector3(0, 0.41, -0.04))
	# Antenna with a lime tip.
	_p(rig, Mats.cyl(0.012, 0.016, 0.42, 6), "navy", Vector3(-0.14, 0.58, 0.3))
	_p(rig, Mats.sphere(0.03, -1, 8, 4), "acc_tech", Vector3(-0.14, 0.8, 0.3))
	_p(rig, Mats.crystal(0.04, 0.15), "ice", Vector3(0.14, 0.45, 0.3))
	_rear(ctx, 0.43, 0.24, 0.33, 0.3)
	ctx["deck"] = 0.43


## Volt: a long low six-wheeler - white hull, gold skirt, orchid insulator stacks at the back
## corners, orchid side strips and a bolt glyph on the nose.
static func _chassis_volt(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig"]
	_p(rig, bevel_box(Vector3(0.52, 0.15, 1.02), 0.045), "white", Vector3(0, 0.28, 0))
	_p(rig, bevel_box(Vector3(0.58, 0.05, 1.08), 0.02), "gold", Vector3(0, 0.195, 0))
	_p(rig, bevel_box(Vector3(0.4, 0.08, 0.92), 0.02), "navy", Vector3(0, 0.15, 0))
	for sx: float in [-1.0, 1.0]:
		_p(rig, bevel_box(Vector3(0.025, 0.04, 0.7), 0.008), "acc_volt", Vector3(0.262 * sx, 0.29, 0.0))
		_p(rig, bevel_box(Vector3(0.08, 0.05, 0.03), 0.012), "hot", Vector3(0.16 * sx, 0.29, -0.515))
		# Insulator stack.
		var base := Vector3(0.19 * sx, 0.36, 0.36)
		_p(rig, Mats.cyl(0.025, 0.03, 0.2, 8, false), "navy", base + Vector3(0, 0.1, 0))
		for k in 3:
			_p(rig, Mats.cyl(0.055 - k * 0.008, 0.055 - k * 0.008, 0.022, 14, false), "acc_volt", base + Vector3(0, 0.05 + k * 0.055, 0))
		_p(rig, Mats.sphere(0.03, -1, 10, 5), "gold", base + Vector3(0, 0.22, 0))
	# Bolt glyph.
	var pts: Array[Vector3] = [Vector3(0.03, 0.34, -0.52), Vector3(-0.01, 0.3, -0.52), Vector3(0.015, 0.29, -0.52), Vector3(-0.025, 0.24, -0.52)]
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var ang := rad_to_deg(atan2(b.x - a.x, a.y - b.y))
		_p(rig, Mats.box(Vector3(0.022, a.distance_to(b) + 0.012, 0.02)), "acc_volt", mid, Vector3(0, 0, ang))
	_p(rig, Mats.cyl(0.19, 0.225, 0.05, 20, false), "gold", Vector3(0, 0.375, -0.02))
	_wheels(ctx, [-0.36, 0.0, 0.36], 0.29, 0.13, "gold")
	_rear(ctx, 0.51, 0.215, 0.26, 0.28)
	ctx["deck"] = 0.4
	ctx["star_y"] = 1.0


## Spoked wheels on one axle pivot per row (both wheels on it: fewer draw calls).
static func _wheels(ctx: Dictionary, zs: Array, x: float, r: float, hub: String) -> void:
	var rig: Node3D = ctx["rig"]
	var wheels: Array[Node3D] = []
	for z: float in zs:
		var axle := Node3D.new()
		axle.name = "Axle"
		axle.position = Vector3(0, r, z)
		axle.set_meta("r", r)
		rig.add_child(axle)
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(x * sx, 0, 0)
			_p(axle, Mats.cyl(r, r, 0.13, 18, false), "tyre", c, Vector3(0, 0, 90))
			_p(axle, Mats.cyl(r * 0.65, r * 0.65, 0.14, 14, false), "gold", c, Vector3(0, 0, 90))
			_p(axle, Mats.box(Vector3(0.15, r * 1.18, 0.035)), "steel", c)
			_p(axle, Mats.box(Vector3(0.15, 0.035, r * 1.18)), "steel", c)
			_p(axle, Mats.cyl(r * 0.28, r * 0.28, 0.16, 8, false), hub, c, Vector3(0, 0, 90))
			for k in 8:
				var a := TAU * k / 8.0
				_p(axle, Mats.box(Vector3(0.135, 0.035, 0.05)), "tyre", c + Vector3(0, cos(a) * r, sin(a) * r), Vector3(rad_to_deg(-a), 0, 0))
		wheels.append(axle)
	ctx["root"].set_meta("wheels", wheels)


## Rank II+ side armour: pearl plates with gold rims and rivets along the hull.
static func _armour(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig_body"] if ctx.has("rig_body") else ctx["rig"]
	var g := _group(ctx, rig, "R2_Armour", 2)
	var half := float(ctx["half"]) + 0.035
	var y := float(ctx["deck"]) - 0.13
	for sx: float in [-1.0, 1.0]:
		_p(g, bevel_box(Vector3(0.04, 0.13, 0.5), 0.015), "pearl", Vector3(half * sx, y, 0.0))
		_p(g, bevel_box(Vector3(0.05, 0.02, 0.52), 0.006), "gold", Vector3(half * sx, y + 0.07, 0.0))
		_p(g, bevel_box(Vector3(0.05, 0.12, 0.02), 0.006), "gold", Vector3(half * sx, y, -0.25))
		for z: float in [-0.14, 0.0, 0.14]:
			_p(g, Mats.sphere(0.017, -1, 8, 4), "gold", Vector3((half + 0.022) * sx, y, z))


## Rank III gold crest: a fan of three gold blades round an ice crystal.
static func _crest(ctx: Dictionary) -> void:
	var parent: Node3D = ctx["crest_parent"]
	var g := _group(ctx, parent, "R3_Crest", 3, 3, "", ctx["crest"])
	_p(g, Mats.cyl(0.05, 0.06, 0.04, 12, false), "gold", Vector3.ZERO)
	for k in 3:
		var a := (k - 1) * 28.0
		var b := bevel_box(Vector3(0.035, 0.17, 0.06), 0.012)
		_p(g, b, "gold", Vector3(sin(deg_to_rad(a)) * 0.06, 0.09, 0.0), Vector3(0, 0, -a))
	_p(g, Mats.crystal(0.032, 0.14), "hot", Vector3(0, 0.15, -0.035))


## Ascension halo: a slowly turning ring of accent crystals above the machine.
static func _halo(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var rig: Node3D = ctx["rig"]
	var kind := str(ctx["kind"])
	var g := _group(ctx, rig, "ASC_Halo", 1, 3, "on", Vector3(0, float(ctx["star_y"]) - 0.12, 0))
	var fam := "acc_" + _family(kind)
	_p(g, Mats.torus(0.2, 0.225, 28, 4), "gold", Vector3.ZERO)
	for k in 6:
		var a := TAU * k / 6.0
		_p(g, Mats.crystal(0.025, 0.09), fam, Vector3(cos(a) * 0.212, 0.0, sin(a) * 0.212))
	root.set_meta("halo", g)


## Crew operator (crew Meshy A-69 stand-in): a small Crystal Knight - white plate, navy
## tabard, gold belt and pauldrons, ice visor and the army's ice crystal crest - standing on
## the rear step facing the enemy. One static body (breathes by scale) and two arm pivots;
## no shadows (5 draw calls).
static func _crew(ctx: Dictionary) -> void:
	var rig: Node3D = ctx["rig_body"] if ctx.has("rig_body") else ctx["rig"]
	var crew := Node3D.new()
	crew.name = "Crew"
	var y0 := float(ctx.get("step_y", 0.25))
	crew.position = Vector3(float(ctx.get("crew_x", 0.0)), y0, float(ctx.get("step_z", 0.5)))
	crew.set_meta("y0", y0)
	rig.add_child(crew)
	var parts: Array[MeshInstance3D] = []
	for sx: float in [-1.0, 1.0]:
		parts.append(_p(crew, bevel_box(Vector3(0.05, 0.12, 0.06), 0.015), "navy", Vector3(0.035 * sx, 0.06, 0)))
		parts.append(_p(crew, bevel_box(Vector3(0.055, 0.03, 0.075), 0.01), "white", Vector3(0.035 * sx, 0.015, -0.008)))
	parts.append(_p(crew, bevel_box(Vector3(0.13, 0.12, 0.09), 0.03), "white", Vector3(0, 0.18, 0)))
	parts.append(_p(crew, bevel_box(Vector3(0.136, 0.022, 0.096), 0.008), "gold", Vector3(0, 0.125, 0)))
	parts.append(_p(crew, bevel_box(Vector3(0.07, 0.09, 0.012), 0.004), "navy", Vector3(0, 0.15, -0.05)))
	parts.append(_p(crew, bevel_box(Vector3(0.07, 0.09, 0.012), 0.004), "navy", Vector3(0, 0.15, 0.05)))
	for sx: float in [-1.0, 1.0]:
		parts.append(_p(crew, Mats.sphere(0.036, -1, 10, 5), "gold", Vector3(0.072 * sx, 0.235, 0)))
	parts.append(_p(crew, Mats.sphere(0.058, 0.11, 14, 7), "white", Vector3(0, 0.315, 0)))
	parts.append(_p(crew, Mats.torus(0.052, 0.064, 18, 4), "gold", Vector3(0, 0.295, 0)))
	parts.append(_p(crew, bevel_box(Vector3(0.075, 0.02, 0.012), 0.005), "ice", Vector3(0, 0.32, -0.054)))
	parts.append(_p(crew, Mats.crystal(0.022, 0.1), "ice", Vector3(0, 0.4, 0.005)))
	var arms: Array[Node3D] = []
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(0.085 * sx, 0.225, 0)
		crew.add_child(arm)
		parts.append(_p(arm, bevel_box(Vector3(0.042, 0.11, 0.045), 0.014), "white", Vector3(0, -0.05, 0)))
		parts.append(_p(arm, Mats.sphere(0.026, -1, 8, 4), "white", Vector3(0, -0.11, 0)))
		arms.append(arm)
	for mi in parts:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crew.set_meta("arms", arms)
	ctx["root"].set_meta("crew", crew)


# ------------------------------------------------------------------ machines (Meta-1)

## Ballista (Kinetic): a long stock with a swept bow (arms flex on a shot) and a gold bolt
## with a crystal head; Rank III loads twin bolts. Ascension: orchid storm strings.
static func _ballista(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, bevel_box(Vector3(0.2, 0.14, 0.24), 0.03), "pearl", Vector3(0, 0.05, 0.02))
	_p(yaw, bevel_box(Vector3(0.13, 0.1, 0.8), 0.03), "white", Vector3(0, 0.16, -0.02))
	_p(yaw, bevel_box(Vector3(0.16, 0.03, 0.62), 0.01), "gold", Vector3(0, 0.215, -0.04))
	_p(yaw, bevel_box(Vector3(0.14, 0.02, 0.3), 0.008), "copper", Vector3(0, 0.12, -0.05))
	_p(yaw, bevel_box(Vector3(0.18, 0.14, 0.12), 0.03), "white", Vector3(0, 0.2, 0.34))
	_p(yaw, Mats.crystal(0.05, 0.2), "ice", Vector3(0, 0.33, 0.34))
	_p(yaw, bevel_box(Vector3(0.22, 0.12, 0.1), 0.03), "gold", Vector3(0, 0.17, -0.3))
	# Winch drums at the back.
	for sx: float in [-1.0, 1.0]:
		_p(yaw, Mats.cyl(0.045, 0.045, 0.05, 10, false), "copper", Vector3(0.115 * sx, 0.2, 0.3), Vector3(0, 0, 90))
	var arms: Array[Node3D] = []
	var tips: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(0.08 * sx, 0.18, -0.3)
		arm.set_meta("side", sx)
		yaw.add_child(arm)
		var dir := Vector3(sx, 0, 0).rotated(Vector3.UP, -sx * deg_to_rad(-22.0))
		_p(arm, bevel_box(Vector3(0.42, 0.075, 0.075), 0.02), "white", dir * 0.21, Vector3(0, -sx * -22.0, 0))
		_p(arm, bevel_box(Vector3(0.2, 0.09, 0.09), 0.02), "gold", dir * 0.1, Vector3(0, -sx * -22.0, 0))
		_p(arm, bevel_box(Vector3(0.1, 0.095, 0.095), 0.02), "copper", dir * 0.3, Vector3(0, -sx * -22.0, 0))
		_p(arm, Mats.sphere(0.05, -1, 10, 6), "gold", dir * 0.43)
		_p(arm, Mats.crystal(0.035, 0.12), "hot", dir * 0.43 + Vector3(0, 0.07, 0))
		var r2 := _group(ctx, arm, "R2_Tip", 2)
		_p(r2, Mats.crystal(0.03, 0.1), "gold", dir * 0.47 + Vector3(0, 0.0, -0.03), Vector3(-60, 0, 0))
		arms.append(arm)
		tips.append(arm.position + dir * 0.43)
	# Bowstring: two glowing strands from the arm tips back to the nock (ice; orchid storm
	# strings when ascended).
	var nock := Vector3(0, 0.2, 0.06)
	var ice_strings := _group(ctx, yaw, "Strings", 1, 3, "off")
	var storm_strings := _group(ctx, yaw, "ASC_Strings", 1, 3, "on")
	for tp in tips:
		var mid := (tp + nock) * 0.5
		var l := tp.distance_to(nock)
		for pair: Array in [[ice_strings, "hot"], [storm_strings, "acc_volt"]]:
			var s := MeshInstance3D.new()
			s.mesh = Mats.box(Vector3(0.022, 0.022, l))
			s.material_override = _mat(str(pair[1]))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(pair[0] as Node3D).add_child(s)
			s.transform = Transform3D(Basis.looking_at(tp - mid, Vector3.UP), mid)
	var bolts: Array[Node3D] = []
	for i in 2:
		var holder: Node3D = recoil if i == 0 else _group(ctx, recoil, "R3_Bolt", 3)
		var bolt := Node3D.new()
		bolt.name = "Bolt"
		bolt.position = Vector3(0.0 if i == 0 else 0.0, 0.245 if i == 0 else 0.3, -0.1)
		holder.add_child(bolt)
		_p(bolt, Mats.box(Vector3(0.035, 0.035, 0.66)), "gold")
		_p(bolt, Mats.crystal(0.055, 0.22), "hot", Vector3(0, 0, -0.4), Vector3(-90, 0, 0))
		_p(bolt, Mats.box(Vector3(0.13, 0.012, 0.09)), "white", Vector3(0, 0, 0.29))
		_p(bolt, Mats.box(Vector3(0.012, 0.13, 0.09)), "copper", Vector3(0, 0, 0.29))
		bolts.append(bolt)
	muzzle.position = Vector3(0, 0.245, -0.6)
	recoil.add_child(muzzle)
	root.set_meta("bolts", bolts)
	root.set_meta("arms", arms)
	ctx["crest"] = Vector3(0, 0.27, 0.34)


## Plasma Cannon (Plasma): a round turret, a fat barrel wrapped in rose coils, a gold muzzle
## brake and a plasma tank in a gold cage. Rank II: a fourth coil and a wider brake; Rank III:
## a crown round the muzzle.
static func _cannon(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, Mats.sphere(0.25, 0.3, 20, 10, false), "white", Vector3(0, 0.12, 0.02))
	_p(yaw, Mats.torus(0.22, 0.27, 24, 8), "gold", Vector3(0, 0.1, 0.02))
	for sx: float in [-1.0, 1.0]:
		_p(yaw, bevel_box(Vector3(0.06, 0.12, 0.2), 0.02), "navy", Vector3(0.24 * sx, 0.14, 0.05))
		_p(yaw, bevel_box(Vector3(0.02, 0.06, 0.14), 0.008), "acc_plasma", Vector3(0.275 * sx, 0.14, 0.05))
	_p(yaw, Mats.sphere(0.12, -1, 14, 8), "acc_plasma", Vector3(0, 0.3, 0.17))
	_p(yaw, Mats.torus(0.115, 0.14, 16, 6), "gold", Vector3(0, 0.3, 0.17), Vector3(90, 0, 0))
	_p(yaw, Mats.torus(0.115, 0.14, 16, 6), "gold", Vector3(0, 0.3, 0.17), Vector3(0, 0, 90))
	_p(recoil, Mats.cyl(0.1, 0.125, 0.62, 18, false), "white", Vector3(0, 0.15, -0.3), Vector3(90, 0, 0))
	for i in 3:
		_p(recoil, Mats.torus(0.105, 0.15, 18, 6), "acc_plasma", Vector3(0, 0.15, -0.16 - i * 0.13), Vector3(90, 0, 0))
	var r2 := _group(ctx, recoil, "R2_Coil", 2)
	_p(r2, Mats.torus(0.1, 0.145, 18, 6), "gold", Vector3(0, 0.15, -0.095), Vector3(90, 0, 0))
	_p(r2, Mats.cyl(0.175, 0.16, 0.05, 16, false), "gold", Vector3(0, 0.15, -0.55), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.15, 0.14, 0.11, 16, false), "gold", Vector3(0, 0.15, -0.62), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.155, 0.155, 0.025, 16, false), "navy", Vector3(0, 0.15, -0.58), Vector3(90, 0, 0))
	var r3 := _group(ctx, recoil, "R3_Crown", 3)
	for k in 6:
		var a := TAU * k / 6.0
		_p(r3, Mats.crystal(0.025, 0.1), "ice", Vector3(cos(a) * 0.15, 0.15 + sin(a) * 0.15, -0.66), Vector3(-90, 0, 0))
	var core := Node3D.new()
	core.name = "Core"
	core.position = Vector3(0, 0.15, -0.66)
	recoil.add_child(core)
	Mats.part(core, Mats.sphere(0.075, -1, 12, 6), Mats.glow(Color(1.0, 0.7, 0.88), 2.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	muzzle.position = Vector3(0, 0.15, -0.72)
	recoil.add_child(muzzle)
	root.set_meta("core", core)
	ctx["crest"] = Vector3(0, 0.36, 0.0)


## Laser (Plasma): a gold lens dish on a mast (it turns, faster while firing) focusing a big
## spinning rose crystal held by claws. Rank II: an outer lens ring; Rank III: twin side
## crystals.
static func _laser(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, bevel_box(Vector3(0.24, 0.1, 0.3), 0.03), "pearl", Vector3(0, 0.04, 0.04))
	_p(yaw, Mats.cyl(0.07, 0.1, 0.26, 12, false), "white", Vector3(0, 0.18, 0.04))
	_p(yaw, Mats.cyl(0.11, 0.11, 0.04, 12, false), "gold", Vector3(0, 0.1, 0.04))
	recoil.position = Vector3(0, 0.34, 0)
	_p(recoil, Mats.sphere(0.13, -1, 16, 8, false), "white", Vector3(0, 0, 0.1))
	var lens := Node3D.new()
	lens.name = "Lens"
	lens.position = Vector3(0, 0, -0.02)
	recoil.add_child(lens)
	_p(lens, Mats.cyl(0.29, 0.1, 0.12, 24, false), "gold", Vector3.ZERO, Vector3(-90, 0, 0))
	_p(lens, Mats.cyl(0.25, 0.09, 0.06, 24, false), "white", Vector3(0, 0, -0.04), Vector3(-90, 0, 0))
	for k in 6:
		var a := TAU * k / 6.0
		_p(lens, Mats.box(Vector3(0.02, 0.15, 0.012)), "acc_plasma", Vector3(cos(a) * 0.17, sin(a) * 0.17, -0.075), Vector3(0, 0, rad_to_deg(a) - 90.0))
	var r2 := _group(ctx, lens, "R2_Ring", 2)
	_p(r2, Mats.torus(0.29, 0.33, 28, 5), "gold", Vector3(0, 0, -0.01), Vector3(90, 0, 0))
	for k in 8:
		var a2 := TAU * k / 8.0
		_p(r2, Mats.sphere(0.02, -1, 6, 4), "acc_plasma", Vector3(cos(a2) * 0.31, sin(a2) * 0.31, -0.03))
	_p(recoil, Mats.cyl(0.07, 0.07, 0.04, 10, false), "hot", Vector3(0, 0, -0.07), Vector3(-90, 0, 0))
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		var off := Vector3(cos(a), sin(a), 0)
		var from := off * 0.24 + Vector3(0, 0, -0.07)
		var to := off * 0.085 + Vector3(0, 0, -0.3)
		var claw := MeshInstance3D.new()
		claw.mesh = bevel_box(Vector3(0.04, 0.04, from.distance_to(to)), 0.012)
		claw.material_override = _mat("gold")
		recoil.add_child(claw)
		claw.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP if absf(off.y) < 0.9 else Vector3.RIGHT), (from + to) * 0.5)
	var gem := Node3D.new()
	gem.name = "Gem"
	gem.position = Vector3(0, 0, -0.27)
	recoil.add_child(gem)
	Mats.part(gem, Mats.crystal(0.1, 0.46), Mats.glow(Color(1.0, 0.62, 0.84), 2.4), Vector3.ZERO, Vector3(-90, 0, 0), Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		_p(recoil, Mats.crystal(0.045, 0.18), "ice", Vector3(0.2 * sx, 0.12, 0.08), Vector3(0, 0, -30.0 * sx))
		_p(recoil, bevel_box(Vector3(0.05, 0.16, 0.16), 0.015), "navy", Vector3(0.13 * sx, 0, 0.12))
	var r3 := _group(ctx, recoil, "R3_Crystals", 3)
	for sx: float in [-1.0, 1.0]:
		_p(r3, Mats.crystal(0.04, 0.2), "acc_plasma", Vector3(0.24 * sx, -0.08, 0.06), Vector3(0, 0, -150.0 * sx))
	muzzle.position = Vector3(0, 0, -0.52)
	recoil.add_child(muzzle)
	root.set_meta("gem", gem)
	root.set_meta("lens", lens)
	ctx["crest"] = Vector3(0, 0.47, 0.1)


## Rocket Pod (Tech): a bevelled pod pitched up; 2×2 tubes at Rank I, the third column opens at
## Rank II (6 rockets); lime tube rims. The warheads vanish on a volley and slide back in.
static func _rockets(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, bevel_box(Vector3(0.22, 0.12, 0.22), 0.03), "pearl", Vector3(0, 0.05, 0.02))
	for sx: float in [-1.0, 1.0]:
		_p(yaw, bevel_box(Vector3(0.05, 0.2, 0.14), 0.015), "gold", Vector3(0.17 * sx, 0.14, 0.02))
	recoil.position = Vector3(0, 0.22, 0.02)
	recoil.rotation_degrees = Vector3(16, 0, 0)
	_p(recoil, bevel_box(Vector3(0.5, 0.34, 0.5), 0.06), "white", Vector3(0, 0.02, 0))
	for sy: float in [-1.0, 1.0]:
		_p(recoil, bevel_box(Vector3(0.52, 0.04, 0.52), 0.015), "gold", Vector3(0, 0.02 + 0.13 * sy, 0))
	_p(recoil, bevel_box(Vector3(0.46, 0.3, 0.04), 0.012), "navy", Vector3(0, 0.02, -0.25))
	_p(recoil, Mats.crystal(0.05, 0.2), "ice", Vector3(0.14, 0.24, 0.12), Vector3(0, 0, -15))
	_p(recoil, bevel_box(Vector3(0.12, 0.06, 0.16), 0.02), "pearl", Vector3(-0.1, 0.21, 0.08))
	_p(recoil, Mats.torus(0.03, 0.042, 14, 4), "acc_tech", Vector3(-0.1, 0.245, 0.08))
	var tips_all: Array[Node3D] = []
	var cover := _group(ctx, recoil, "R1_Cover", 1, 1)
	var extra := _group(ctx, recoil, "R2_Tubes", 2)
	var tips_a := Node3D.new()
	tips_a.name = "Tips"
	tips_a.position = Vector3(0, 0.02, -0.26)
	recoil.add_child(tips_a)
	var tips_b := Node3D.new()
	tips_b.name = "Tips2"
	tips_b.position = Vector3(0, 0.02, -0.26)
	extra.add_child(tips_b)
	tips_all.append(tips_a)
	tips_all.append(tips_b)
	for col in 3:
		var x := (col - 1) * 0.15
		for sy: float in [-1.0, 1.0]:
			var p := Vector3(x, 0.075 * sy, 0)
			var third := col == 1
			var holder: Node3D = extra if third else recoil
			_p(holder, Mats.cyl(0.062, 0.062, 0.04, 14, false), "gold", p + Vector3(0, 0.02, -0.265), Vector3(90, 0, 0))
			_p(holder, Mats.cyl(0.05, 0.05, 0.045, 12, false), "acc_tech", p + Vector3(0, 0.02, -0.27), Vector3(90, 0, 0))
			var tips: Node3D = tips_b if third else tips_a
			_p(tips, Mats.cyl(0.0, 0.042, 0.12, 10, false), "white", p + Vector3(0, 0, -0.06), Vector3(-90, 0, 0))
			_p(tips, Mats.cyl(0.042, 0.042, 0.03, 10, false), "gold", p + Vector3(0, 0, -0.01), Vector3(-90, 0, 0))
			if third:
				_p(cover, bevel_box(Vector3(0.12, 0.1, 0.02), 0.01), "pearl", p + Vector3(0, 0.02, -0.262))
				_p(cover, Mats.sphere(0.015, -1, 6, 4), "gold", p + Vector3(0, 0.02, -0.275))
	muzzle.position = Vector3(0, 0.02, -0.34)
	recoil.add_child(muzzle)
	root.set_meta("tips", tips_all)
	ctx["crest"] = Vector3(0.0, 0.2, 0.18)
	ctx["crest_parent"] = recoil


## Siege Mortar (Kinetic): a stubby fat tube at 50° in a gold-capped cradle (pivot at the
## axle, axis X, 35°–60°), copper bands, a shell pair on the turntable for the crew to load.
## Rank II: a reinforced muzzle collar; Rank III: a bomblet rack on the deck.
static func _mortar(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var rig: Node3D = ctx["rig"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, Mats.cyl(0.19, 0.2, 0.05, 20, false), "white", Vector3(0, 0.025, 0))
	_p(yaw, Mats.torus(0.17, 0.2, 24, 4), "gold", Vector3(0, 0.05, 0))
	for sx: float in [-1.0, 1.0]:
		_p(yaw, bevel_box(Vector3(0.05, 0.24, 0.28), 0.02), "white", Vector3(0.155 * sx, 0.15, 0.0))
		_p(yaw, bevel_box(Vector3(0.056, 0.03, 0.29), 0.008), "gold", Vector3(0.155 * sx, 0.275, 0.0))
		_p(yaw, bevel_box(Vector3(0.012, 0.1, 0.16), 0.004), "copper", Vector3(0.183 * sx, 0.14, 0.0))
		_p(yaw, Mats.cyl(0.045, 0.045, 0.03, 12, false), "gold", Vector3(0.19 * sx, 0.2, 0.0), Vector3(0, 0, 90))
	_p(yaw, Mats.cyl(0.032, 0.032, 0.3, 10, false), "navy", Vector3(0, 0.2, 0.0), Vector3(0, 0, 90))
	# Two shells standing on the turntable, ready to load.
	for sx: float in [-1.0, 1.0]:
		var sp := Vector3(0.075 * sx, 0.05, 0.15)
		_p(yaw, Mats.cyl(0.035, 0.035, 0.1, 10, false), "white", sp + Vector3(0, 0.05, 0))
		_p(yaw, Mats.cyl(0.0, 0.035, 0.06, 10, false), "gold", sp + Vector3(0, 0.13, 0))
		_p(yaw, Mats.cyl(0.037, 0.037, 0.015, 10, false), "copper", sp + Vector3(0, 0.07, 0))
	var tube := Node3D.new()
	tube.name = "Tube"
	tube.position = Vector3(0, 0.2, 0.0)
	tube.rotation.x = deg_to_rad(50.0)
	yaw.add_child(tube)
	tube.add_child(recoil)
	_p(recoil, Mats.sphere(0.135, -1, 16, 8, false), "navy", Vector3(0, 0, 0.08), Vector3.ZERO, Vector3(1, 1, 0.8))
	_p(recoil, Mats.cyl(0.12, 0.13, 0.46, 18, false), "white", Vector3(0, 0, -0.1), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.138, 0.138, 0.04, 18, false), "gold", Vector3(0, 0, 0.06), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.134, 0.134, 0.07, 18, false), "copper", Vector3(0, 0, -0.08), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.128, 0.128, 0.03, 18, false), "gold", Vector3(0, 0, -0.22), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.15, 0.13, 0.06, 18, false), "gold", Vector3(0, 0, -0.34), Vector3(90, 0, 0))
	_p(recoil, Mats.cyl(0.09, 0.09, 0.01, 14, false), "navy", Vector3(0, 0, -0.372), Vector3(90, 0, 0))
	_p(recoil, Mats.torus(0.075, 0.092, 16, 4), "ice", Vector3(0, 0, -0.368), Vector3(90, 0, 0))
	# Copper chevron on the tube's back (seen from the run camera).
	for sx: float in [-1.0, 1.0]:
		_p(recoil, bevel_box(Vector3(0.08, 0.02, 0.025), 0.006), "copper", Vector3(0.03 * sx, 0.128, -0.15), Vector3(-90, 0, -30.0 * sx))
	_p(recoil, Mats.crystal(0.03, 0.12), "ice", Vector3(0.0, 0.14, 0.02), Vector3(90, 0, 0))
	var r2 := _group(ctx, recoil, "R2_Collar", 2)
	_p(r2, Mats.cyl(0.165, 0.165, 0.05, 18, false), "copper", Vector3(0, 0, -0.29), Vector3(90, 0, 0))
	for k in 6:
		var a := TAU * k / 6.0
		_p(r2, Mats.sphere(0.016, -1, 6, 4), "gold", Vector3(cos(a) * 0.168, sin(a) * 0.168, -0.29))
	var r3 := _group(ctx, rig, "R3_Rack", 3)
	_p(r3, bevel_box(Vector3(0.06, 0.03, 0.26), 0.008), "copper", Vector3(-0.235, 0.42, 0.0))
	for k in 3:
		var sp2 := Vector3(-0.235, 0.47, -0.09 + k * 0.09)
		_p(r3, Mats.cyl(0.026, 0.026, 0.07, 8, false), "white", sp2)
		_p(r3, Mats.cyl(0.0, 0.026, 0.04, 8, false), "gold", sp2 + Vector3(0, 0.055, 0))
	muzzle.position = Vector3(0, 0, -0.4)
	recoil.add_child(muzzle)
	root.set_meta("tube", tube)
	root.set_meta("pitch", 50.0)
	ctx["crest"] = Vector3(0, 0.3, 0.12)


## Gatling (Kinetic): a white receiver with a copper ammo drum and a six-barrel cluster that
## spins up (pivot at the drum centre, axis Z, up to 30 rad/s). Rank II: a gun shield; Rank
## III: a second ammo drum.
static func _gatling(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	_p(yaw, bevel_box(Vector3(0.22, 0.1, 0.24), 0.03), "pearl", Vector3(0, 0.05, 0.03))
	for sx: float in [-1.0, 1.0]:
		_p(yaw, bevel_box(Vector3(0.04, 0.17, 0.12), 0.012), "gold", Vector3(0.135 * sx, 0.14, 0.03))
	_p(recoil, bevel_box(Vector3(0.2, 0.17, 0.32), 0.04), "white", Vector3(0, 0.2, 0.06))
	_p(recoil, bevel_box(Vector3(0.1, 0.02, 0.3), 0.006), "gold", Vector3(0, 0.292, 0.06))
	for sx: float in [-1.0, 1.0]:
		_p(recoil, bevel_box(Vector3(0.012, 0.1, 0.2), 0.004), "copper", Vector3(0.103 * sx, 0.2, 0.06))
		_p(recoil, Mats.sphere(0.014, -1, 6, 4), "gold", Vector3(0.11 * sx, 0.24, -0.02))
		_p(recoil, Mats.sphere(0.014, -1, 6, 4), "gold", Vector3(0.11 * sx, 0.24, 0.14))
		# Handles for the operator.
		_p(recoil, Mats.cyl(0.012, 0.012, 0.12, 6, false), "gold", Vector3(0.06 * sx, 0.2, 0.26), Vector3(90, 0, 0))
		_p(recoil, Mats.cyl(0.022, 0.022, 0.06, 8, false), "navy", Vector3(0.06 * sx, 0.2, 0.33), Vector3(90, 0, 0))
	# Ammo drum (right) with the feed chute.
	for side in 2:
		var sx := 1.0 if side == 0 else -1.0
		var holder: Node3D = recoil if side == 0 else _group(ctx, recoil, "R3_Drum", 3)
		_p(holder, Mats.cyl(0.095, 0.095, 0.12, 16, false), "copper", Vector3(0.19 * sx, 0.19, 0.1), Vector3(0, 0, 90))
		for dx: float in [-0.065, 0.065]:
			_p(holder, Mats.cyl(0.1, 0.1, 0.015, 16, false), "gold", Vector3(0.19 * sx + dx, 0.19, 0.1), Vector3(0, 0, 90))
		_p(holder, Mats.cyl(0.03, 0.03, 0.13, 8, false), "ice", Vector3(0.19 * sx, 0.19, 0.1), Vector3(0, 0, 90))
		_p(holder, bevel_box(Vector3(0.08, 0.05, 0.08), 0.01), "navy", Vector3(0.12 * sx, 0.25, 0.04))
	# Barrel cluster.
	var drum := Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(0, 0.2, -0.1)
	recoil.add_child(drum)
	for k in 6:
		var a := TAU * k / 6.0
		var off := Vector3(cos(a) * 0.058, sin(a) * 0.058, 0)
		_p(drum, Mats.cyl(0.024, 0.024, 0.5, 8, false), "white", off + Vector3(0, 0, -0.25), Vector3(90, 0, 0))
		_p(drum, Mats.cyl(0.015, 0.015, 0.012, 6, false), "navy", off + Vector3(0, 0, -0.502), Vector3(90, 0, 0))
	_p(drum, Mats.cyl(0.032, 0.032, 0.48, 8, false), "navy", Vector3(0, 0, -0.24), Vector3(90, 0, 0))
	for z: float in [-0.03, -0.24, -0.46]:
		_p(drum, Mats.cyl(0.095, 0.095, 0.03, 12, false), "gold", Vector3(0, 0, z), Vector3(90, 0, 0))
	_p(drum, Mats.cyl(0.098, 0.098, 0.04, 12, false), "copper", Vector3(0, 0, -0.35), Vector3(90, 0, 0))
	var r2 := _group(ctx, recoil, "R2_Shield", 2)
	for sx: float in [-1.0, 1.0]:
		_p(r2, bevel_box(Vector3(0.11, 0.2, 0.03), 0.012), "white", Vector3(0.16 * sx, 0.22, -0.13), Vector3(0, -18.0 * sx, 0))
		_p(r2, bevel_box(Vector3(0.115, 0.02, 0.035), 0.006), "gold", Vector3(0.16 * sx, 0.325, -0.13), Vector3(0, -18.0 * sx, 0))
	_p(r2, bevel_box(Vector3(0.24, 0.06, 0.03), 0.012), "white", Vector3(0, 0.33, -0.12))
	_p(r2, bevel_box(Vector3(0.1, 0.03, 0.035), 0.008), "copper", Vector3(0, 0.33, -0.14))
	muzzle.position = Vector3(0, 0.2, -0.64)
	recoil.add_child(muzzle)
	root.set_meta("drum", drum)
	ctx["crest"] = Vector3(0, 0.31, 0.16)
	ctx["crest_parent"] = recoil


## Railgun (Volt): two long parallel rails with gold caps and orchid inner strips, three gold
## coil frames, a capacitor bank with orchid cells and a slug that grows between the rails as
## it charges (set_charge). Rank II: capacitor fins; Rank III: gold rail prongs. Ascension A
## (Breacher): a gold penetrator collar; B (Splitter): a three-prong fork.
static func _railgun(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	var charge_mats: Array[StandardMaterial3D] = []
	var vg: Color = FAMILY_GLOW["volt"]
	# Everything that glows with the charge is merged into one mesh with its own material.
	var charge := Node3D.new()
	_p(yaw, Mats.cyl(0.17, 0.19, 0.05, 18, false), "navy", Vector3(0, 0.025, 0.05))
	_p(yaw, bevel_box(Vector3(0.26, 0.1, 0.34), 0.03), "white", Vector3(0, 0.09, 0.08))
	for sx: float in [-1.0, 1.0]:
		_p(yaw, bevel_box(Vector3(0.012, 0.04, 0.24), 0.004), "acc_volt", Vector3(0.132 * sx, 0.09, 0.08))
	# Two rails: navy cores under white caps with gold edges; the orchid charge lines run along
	# the inner top edges (seen from the run camera).
	for sx: float in [-1.0, 1.0]:
		_p(recoil, bevel_box(Vector3(0.06, 0.08, 1.06), 0.02), "navy", Vector3(0.09 * sx, 0.19, -0.27))
		_p(recoil, bevel_box(Vector3(0.075, 0.035, 1.02), 0.012), "white", Vector3(0.09 * sx, 0.24, -0.27))
		_p(recoil, bevel_box(Vector3(0.012, 0.012, 0.98), 0.004), "gold", Vector3(0.128 * sx, 0.255, -0.27))
		Mats.part(charge, Mats.box(Vector3(0.016, 0.014, 0.94)), _mat("acc_volt"), Vector3(0.055 * sx, 0.255, -0.29))
		Mats.part(charge, Mats.box(Vector3(0.01, 0.05, 0.9)), _mat("acc_volt"), Vector3(0.058 * sx, 0.19, -0.3))
		# Muzzle tips.
		_p(recoil, bevel_box(Vector3(0.085, 0.1, 0.06), 0.02), "gold", Vector3(0.09 * sx, 0.21, -0.79))
	for z: float in [-0.12, -0.5]:
		_p(recoil, Mats.torus(0.15, 0.185, 20, 5), "gold", Vector3(0, 0.21, z), Vector3(90, 0, 0), Vector3(1.0, 0.75, 1.0))
	# Capacitor bank.
	_p(recoil, bevel_box(Vector3(0.26, 0.16, 0.24), 0.04), "white", Vector3(0, 0.2, 0.22))
	_p(recoil, bevel_box(Vector3(0.27, 0.02, 0.25), 0.006), "gold", Vector3(0, 0.12, 0.22))
	for sx: float in [-1.0, 0.0, 1.0]:
		Mats.part(charge, Mats.cyl(0.03, 0.03, 0.07, 10, false), _mat("acc_volt"), Vector3(0.075 * sx, 0.31, 0.22))
		_p(recoil, Mats.cyl(0.036, 0.036, 0.015, 10, false), "gold", Vector3(0.075 * sx, 0.35, 0.22))
	# Bolt glyph on the back plate.
	_p(recoil, bevel_box(Vector3(0.12, 0.12, 0.012), 0.01), "navy", Vector3(0, 0.2, 0.345))
	var pts: Array[Vector3] = [Vector3(0.025, 0.25, 0.352), Vector3(-0.01, 0.2, 0.352), Vector3(0.015, 0.195, 0.352), Vector3(-0.02, 0.15, 0.352)]
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		_p(recoil, Mats.box(Vector3(0.018, a.distance_to(b) + 0.01, 0.01)), "acc_volt", (a + b) * 0.5, Vector3(0, 0, rad_to_deg(atan2(b.x - a.x, a.y - b.y))))
	var cmi := MeshInstance3D.new()
	cmi.name = "ChargeGlow"
	cmi.mesh = merge(charge)
	var cm := _dyn_glow(vg, 0.35)
	cmi.material_override = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.set_meta("no_bake", true)
	recoil.add_child(cmi)
	charge_mats.append(cm)
	var slug := Node3D.new()
	slug.name = "Slug"
	slug.position = Vector3(0, 0.2, -0.24)
	recoil.add_child(slug)
	var sm := Mats.part(slug, Mats.sphere(0.045, 0.16, 10, 5), Mats.glow(Color(1.0, 0.85, 1.0), 3.5), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	sm.set_meta("no_bake", true)
	slug.scale = Vector3.ONE * 0.001
	var r2 := _group(ctx, recoil, "R2_Fins", 2)
	for k in 3:
		_p(r2, bevel_box(Vector3(0.02, 0.1, 0.18), 0.006), "white", Vector3(-0.08 + k * 0.08, 0.33, 0.22))
		_p(r2, bevel_box(Vector3(0.024, 0.015, 0.18), 0.004), "acc_volt", Vector3(-0.08 + k * 0.08, 0.385, 0.22))
	var r3 := _group(ctx, recoil, "R3_Prongs", 3)
	for sx: float in [-1.0, 1.0]:
		_p(r3, bevel_box(Vector3(0.04, 0.05, 0.16), 0.012), "gold", Vector3(0.1 * sx, 0.2, -0.84), Vector3(0, 8.0 * sx, 0))
		_p(r3, Mats.crystal(0.022, 0.08), "acc_volt", Vector3(0.112 * sx, 0.2, -0.93), Vector3(-90, 0, 0))
	var asc_a := _group(ctx, recoil, "ASC_Breacher", 1, 3, "a")
	_p(asc_a, Mats.cyl(0.07, 0.16, 0.14, 16, false), "gold", Vector3(0, 0.2, -0.82), Vector3(-90, 0, 0))
	_p(asc_a, Mats.torus(0.12, 0.15, 18, 4), "acc_volt", Vector3(0, 0.2, -0.78), Vector3(90, 0, 0))
	_p(asc_a, Mats.cyl(0.0, 0.06, 0.12, 10, false), "white", Vector3(0, 0.2, -0.94), Vector3(-90, 0, 0))
	var asc_b := _group(ctx, recoil, "ASC_Splitter", 1, 3, "b")
	for k in 3:
		var ang := (k - 1) * 22.0
		_p(asc_b, bevel_box(Vector3(0.035, 0.035, 0.22), 0.01), "gold", Vector3(sin(deg_to_rad(ang)) * 0.09, 0.2, -0.86), Vector3(0, -ang, 0))
	muzzle.position = Vector3(0, 0.2, -0.8)
	recoil.add_child(muzzle)
	root.set_meta("charge_mats", charge_mats)
	root.set_meta("slug", slug)
	root.set_meta("charge", 0.0)
	ctx["crest"] = Vector3(0, 0.33, 0.12)
	ctx["crest_parent"] = recoil


## Drone (Tech, free): a white saucer with a gold ring, an ice dome and a lime spotter eye,
## four rotor arms and a glowing thruster; a soft light pool on the road shows its height.
## Rank II: a wingman drone orbiting it; Rank III: a lime halo antenna.
static func _drone(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var rig: Node3D = ctx["rig"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	var rotors: Array[Node3D] = []
	_drone_core(yaw, rotors)
	for sx: float in [-1.0, 1.0]:
		_p(recoil, Mats.cyl(0.025, 0.025, 0.16, 8, false), "navy", Vector3(0.08 * sx, -0.07, -0.14), Vector3(90, 0, 0))
		_p(recoil, Mats.cyl(0.03, 0.03, 0.03, 8, false), "gold", Vector3(0.08 * sx, -0.07, -0.22), Vector3(90, 0, 0))
	muzzle.position = Vector3(0, -0.07, -0.25)
	yaw.add_child(recoil)
	recoil.add_child(muzzle)
	var wing := _group(ctx, yaw, "R2_Wingman", 2)
	var wbody := Node3D.new()
	wbody.name = "WingBody"
	wbody.scale = Vector3.ONE * 0.5
	wing.add_child(wbody)
	_drone_core(wbody, rotors)
	root.set_meta("wingman", wing)
	var r3 := _group(ctx, yaw, "R3_Antenna", 3)
	_p(r3, Mats.cyl(0.01, 0.014, 0.2, 6), "gold", Vector3(0, 0.22, 0.06))
	_p(r3, Mats.torus(0.05, 0.065, 16, 4), "acc_tech", Vector3(0, 0.34, 0.06), Vector3(90, 0, 0))
	_p(r3, Mats.sphere(0.022, -1, 8, 4), "hot", Vector3(0, 0.34, 0.06))
	root.set_meta("rotors", rotors)
	root.set_meta("wheels", [])
	ctx["star_y"] = 1.08
	var pool := MeshInstance3D.new()
	pool.name = "LightPool"
	pool.mesh = Mats.quad(Vector2(0.9, 0.9))
	pool.material_override = _pool_material(ICE)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.025, 0)
	pool.set_meta("no_sheen", true)
	rig.add_child(pool)


static func _drone_core(yaw: Node3D, rotors: Array[Node3D]) -> void:
	_p(yaw, Mats.sphere(0.22, 0.17, 24, 10, false), "white", Vector3.ZERO)
	_p(yaw, Mats.torus(0.2, 0.25, 28, 8), "gold", Vector3(0, -0.005, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	_p(yaw, Mats.sphere(0.11, 0.13, 16, 8, false), "ice", Vector3(0, 0.07, 0.02))
	_p(yaw, Mats.cyl(0.13, 0.13, 0.025, 18, false), "gold", Vector3(0, 0.04, 0.02))
	_p(yaw, Mats.cyl(0.07, 0.03, 0.09, 12, false), "navy", Vector3(0, -0.1, 0))
	_p(yaw, Mats.cyl(0.05, 0.0, 0.08, 10, false), "hot", Vector3(0, -0.17, 0))
	_p(yaw, Mats.sphere(0.06, -1, 12, 6, false), "navy", Vector3(0, -0.02, -0.19))
	_p(yaw, Mats.sphere(0.042, -1, 12, 6, false), "acc_tech", Vector3(0, -0.02, -0.225))
	_p(yaw, Mats.torus(0.045, 0.06, 14, 4), "gold", Vector3(0, -0.02, -0.215), Vector3(90, 0, 0))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var dir := Vector3(sin(a), 0, cos(a))
		var arm := MeshInstance3D.new()
		arm.mesh = bevel_box(Vector3(0.05, 0.035, 0.26), 0.012)
		arm.material_override = _mat("white")
		yaw.add_child(arm)
		arm.position = dir * 0.24
		arm.rotation = Vector3(0, a, 0)
		var hub := dir * 0.37 + Vector3(0, 0.02, 0)
		_p(yaw, Mats.torus(0.115, 0.14, 22, 6), "gold", hub)
		_p(yaw, Mats.cyl(0.03, 0.03, 0.06, 8, false), "navy", hub)
		_p(yaw, Mats.sphere(0.016, -1, 6, 4), "acc_tech", hub + Vector3(0, -0.04, 0))
		var rotor := Node3D.new()
		rotor.name = "Rotor"
		rotor.position = hub + Vector3(0, 0.035, 0)
		rotor.set_meta("cw", k % 2 == 0)
		yaw.add_child(rotor)
		Mats.part(rotor, bevel_box(Vector3(0.21, 0.012, 0.04), 0.004), _mat("pearl"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(rotor, bevel_box(Vector3(0.04, 0.012, 0.21), 0.004), _mat("pearl"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(rotor, Mats.sphere(0.022, -1, 8, 4), _mat("ice"), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ONE, false)
		rotors.append(rotor)


## Prism (Plasma, free, Legendary): a faceted rose-white diamond with gold tips and a gold
## girdle floating in a two-ring gyro (gold ring about X, white ring about Y), a gold keel
## below. Rank II: a third rose ring; Rank III: a crown of crystal shards. Ascension A (Lens
## of Ruin): an eye lens; B (Rainbow Prism): tri-colour facets.
static func _prism(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var rig: Node3D = ctx["rig"]
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var muzzle: Node3D = ctx["muzzle"]
	yaw.add_child(recoil)
	var body := Node3D.new()
	body.name = "Body"
	recoil.add_child(body)
	# A glass diamond (see-through rose facets) round a white-hot core, caged by gold edges.
	var glass := Mats.part(body, Mats.crystal(0.21, 0.62), _prism_glass(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	glass.set_meta("no_bake", true)
	Mats.part(body, Mats.crystal(0.1, 0.36), Mats.glow(Color(1.0, 0.86, 0.96), 3.4), Vector3.ZERO, Vector3(0, 30, 0), Vector3.ONE, false)
	_p(body, Mats.torus(0.2, 0.235, 6, 4), "gold", Vector3.ZERO, Vector3(0, 30, 0))
	for k in 6:
		var a0 := deg_to_rad(30.0 + 60.0 * k)
		var eq := Vector3(cos(a0) * 0.21, 0, sin(a0) * 0.21)
		for tip: Vector3 in [Vector3(0, 0.31, 0), Vector3(0, -0.31, 0)]:
			var bar := MeshInstance3D.new()
			bar.mesh = Mats.box(Vector3(0.014, 0.014, eq.distance_to(tip)))
			bar.material_override = _mat("gold")
			body.add_child(bar)
			bar.transform = Transform3D(Basis.looking_at(tip - eq, Vector3.UP if absf((tip - eq).normalized().y) < 0.99 else Vector3.RIGHT), (eq + tip) * 0.5)
	_p(body, Mats.cyl(0.0, 0.05, 0.1, 6), "gold", Vector3(0, 0.33, 0))
	_p(body, Mats.cyl(0.05, 0.0, 0.1, 6), "gold", Vector3(0, -0.33, 0))
	for k in 6:
		var a := TAU * k / 6.0 + TAU / 12.0
		_p(body, Mats.sphere(0.018, -1, 6, 4), "acc_plasma", Vector3(cos(a) * 0.235, 0, sin(a) * 0.235))
	var ga := Node3D.new()
	ga.name = "GyroA"
	recoil.add_child(ga)
	_p(ga, Mats.torus(0.36, 0.405, 36, 6), "gold", Vector3.ZERO, Vector3(0, 0, 90))
	for k in 4:
		var a2 := TAU * k / 4.0
		_p(ga, Mats.crystal(0.026, 0.09), "ice", Vector3(0, cos(a2) * 0.383, sin(a2) * 0.383), Vector3(rad_to_deg(a2), 0, 0))
	var gb := Node3D.new()
	gb.name = "GyroB"
	ga.add_child(gb)
	_p(gb, Mats.torus(0.29, 0.325, 32, 6), "white", Vector3.ZERO)
	for k in 6:
		var a3 := TAU * k / 6.0
		_p(gb, Mats.sphere(0.022, -1, 8, 4), "gold", Vector3(cos(a3) * 0.307, 0, sin(a3) * 0.307))
	var gc := _group(ctx, recoil, "R2_GyroC", 2)
	_p(gc, Mats.torus(0.44, 0.465, 40, 4), "acc_plasma", Vector3.ZERO, Vector3(90, 0, 0))
	var crown := _group(ctx, yaw, "R3_Crown", 3, 3, "", Vector3(0, 0.46, 0))
	for k in 5:
		var a4 := TAU * k / 5.0
		_p(crown, Mats.crystal(0.03, 0.14), "hot", Vector3(cos(a4) * 0.15, 0, sin(a4) * 0.15), Vector3(cos(a4) * 18.0, 0, -sin(a4) * 18.0))
	_p(crown, Mats.torus(0.13, 0.15, 20, 4), "gold", Vector3(0, -0.06, 0))
	# Keel below.
	_p(yaw, Mats.cyl(0.07, 0.0, 0.2, 8), "gold", Vector3(0, -0.52, 0))
	_p(yaw, Mats.torus(0.05, 0.075, 14, 4), "white", Vector3(0, -0.44, 0))
	_p(yaw, Mats.sphere(0.03, -1, 8, 4), "acc_plasma", Vector3(0, -0.63, 0))
	var asc_a := _group(ctx, recoil, "ASC_Lens", 1, 3, "a")
	_p(asc_a, Mats.torus(0.09, 0.12, 22, 5), "gold", Vector3(0, 0, -0.27), Vector3(90, 0, 0))
	_p(asc_a, Mats.cyl(0.09, 0.09, 0.015, 18, false), "navy", Vector3(0, 0, -0.27), Vector3(90, 0, 0))
	_p(asc_a, Mats.sphere(0.045, -1, 10, 6), "acc_plasma", Vector3(0, 0, -0.28))
	var asc_b := _group(ctx, recoil, "ASC_Rainbow", 1, 3, "b")
	var tri: Array[Color] = [Color(1.0, 0.45, 0.2), Color(0.6, 0.95, 1.0), Color(1.0, 0.55, 1.0)]
	for k in 3:
		var a5 := TAU * k / 3.0
		Mats.part(asc_b, Mats.crystal(0.05, 0.2), Mats.glow(tri[k], 2.4), Vector3(cos(a5) * 0.28, 0.0, sin(a5) * 0.28), Vector3.ZERO, Vector3.ONE, false)
	muzzle.position = Vector3.ZERO
	recoil.add_child(muzzle)
	root.set_meta("gyro_a", ga)
	root.set_meta("gyro_b", gb)
	root.set_meta("gyro_c", gc)
	root.set_meta("prism_body", body)
	root.set_meta("crown", crown)
	root.set_meta("wheels", [])
	ctx["star_y"] = PRISM_Y + 0.9
	var pool := MeshInstance3D.new()
	pool.name = "LightPool"
	pool.mesh = Mats.quad(Vector2(1.3, 1.3))
	pool.material_override = _pool_material(FAMILY_GLOW["plasma"])
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.025, 0)
	pool.set_meta("no_sheen", true)
	rig.add_child(pool)


static func _prism_glass() -> StandardMaterial3D:
	if _mats.has("prism_glass"):
		return _mats["prism_glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.7, 0.88, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.3
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.62)
	m.emission_energy_multiplier = 0.45
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.2
	_mats["prism_glass"] = m
	return m


## Meta-2 / unknown machines: a family-accent crystal on a turret (keeps every id drawable).
static func _standin(ctx: Dictionary) -> void:
	var yaw: Node3D = ctx["yaw"]
	var recoil: Node3D = ctx["recoil"]
	var fam := "acc_" + _family(str(ctx["kind"]))
	_p(yaw, bevel_box(Vector3(0.26, 0.12, 0.26), 0.03), "pearl", Vector3(0, 0.06, 0))
	_p(recoil, Mats.cyl(0.06, 0.08, 0.4, 12, false), "white", Vector3(0, 0.16, -0.2), Vector3(90, 0, 0))
	_p(recoil, Mats.crystal(0.09, 0.3), fam, Vector3(0, 0.3, 0.05))
	(ctx["muzzle"] as Node3D).position = Vector3(0, 0.16, -0.42)


# ------------------------------------------------------------------ crate

## Weapon crate: a hexagonal capsule with a glass window showing the miniature machine on a
## glowing pedestal, a beacon ring, a loot pillar and an hp label. Faces +Z (towards the army).
## `weapon` "" or "deck" = contents not resolved yet (a "?" crystal; crate_set_content()
## swaps it). `opts`: rarity "C".."M" (shell material + pips, §2.1), new (bool: the platinum
## NEW crate - steel-white shell, white pillar), badge (String shown above the hp: pass a
## Loc text), bonus (int > 0: the gold BONUS segment ring, crate_bonus()). Metas: "label",
## "content", "glass", "kind", "role" = "crate", "badge", "bonus_ring".
static func crate(weapon: String, hp := 0, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Crate_" + (weapon if weapon != "" else "deck")
	root.set_meta("kind", weapon)
	root.set_meta("role", "crate")
	var is_new := bool(opts.get("new", false))
	var rarity := str(opts.get("rarity", ArsenalData.rarity_of(weapon) if ArsenalData.MACHINES.has(weapon) else "C"))
	var shell: Dictionary = CRATE_SHELLS["new" if is_new else rarity] if CRATE_SHELLS.has(rarity) or is_new else CRATE_SHELLS["C"]
	var col := Color(0.92, 0.97, 1.0) if is_new else icon_color(weapon)
	var glow_col := Color(0.9, 0.97, 1.0) if is_new else glow_color(weapon)
	var glb := asset("crate_new" if is_new else "crate", AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.4, 1.2)))
	if glb != null:
		root.add_child(glb)
	else:
		var white := Mats.solid(shell["body"], 0.3, float(shell["metal"]))
		var pearl := Mats.solid(PEARL, 0.45, 0.25)
		var gold := Mats.solid(GOLD, 0.3, 0.85)
		var navy := Mats.solid(NAVY, 0.6, 0.3)
		var ice := Mats.glow(ICE, 2.6)
		var inlay := Mats.glow(shell["inlay"], 2.4)
		var accent := Mats.glow(glow_col, 2.8)
		Mats.part(root, _hex(0.6, 0.64, 0.08), gold, Vector3(0, 0.04, 0))
		Mats.part(root, _hex(0.55, 0.58, 0.34), white, Vector3(0, 0.25, 0))
		Mats.part(root, _hex(0.585, 0.585, 0.06), gold, Vector3(0, 0.44, 0))
		Mats.part(root, _hex(0.5, 0.5, 0.03), navy, Vector3(0, 0.485, 0))
		for k in 6:
			var a := TAU * k / 6.0
			var dir := Vector3(sin(a), 0, cos(a))
			var face := dir * 0.49 + Vector3(0, 0.25, 0)
			if k % 3 == 0:
				Mats.part(root, Mats.cyl(0.11, 0.11, 0.04, 6, true), gold, face + dir * 0.02, Vector3(90, rad_to_deg(a), 0))
				Mats.part(root, Mats.cyl(0.075, 0.075, 0.05, 6, true), accent, face + dir * 0.03, Vector3(90, rad_to_deg(a), 0), Vector3.ONE, false)
			else:
				Mats.part(root, bevel_box(Vector3(0.24, 0.05, 0.03), 0.01), pearl, face + dir * 0.015, Vector3(0, rad_to_deg(a), 0))
				Mats.part(root, bevel_box(Vector3(0.18, 0.025, 0.03), 0.008), inlay, face + dir * 0.03 + Vector3(0, -0.08, 0), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
		# Rarity pips on the front gold band (+Z faces the army): 1..5 small cut gems.
		var pips := int((ArsenalData.RARITIES.get(rarity, {}) as Dictionary).get("pips", 1))
		if is_new:
			pips = 0
		for i in pips:
			var px := (i - (pips - 1) * 0.5) * 0.1
			Mats.part(root, Mats.crystal(0.03, 0.07), inlay, Vector3(px, 0.44, 0.555), Vector3(0, 0, 90), Vector3.ONE, false)
		var rib_mat: Material = gold if rarity == "L" or is_new else white
		for k in 3:
			var a := TAU * (k * 2 + 1) / 6.0 + TAU / 12.0
			var p := Vector3(sin(a), 0, cos(a)) * 0.47
			Mats.part(root, bevel_box(Vector3(0.1, 0.64, 0.1), 0.03), rib_mat, p + Vector3(0, 0.78, 0), Vector3(0, rad_to_deg(a), 0))
			Mats.part(root, bevel_box(Vector3(0.12, 0.05, 0.12), 0.015), gold, p + Vector3(0, 0.62, 0), Vector3(0, rad_to_deg(a), 0))
			if rarity in ["R", "E", "L", "M"] or is_new:
				Mats.part(root, bevel_box(Vector3(0.03, 0.46, 0.105), 0.008), inlay, p * 1.01 + Vector3(0, 0.8, 0), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
			Mats.part(root, Mats.crystal(0.035, 0.14), accent, p * 1.12 + Vector3(0, 0.82, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(root, _hex(0.5, 0.5, 0.05), gold, Vector3(0, 1.1, 0))
		Mats.part(root, _hex(0.3, 0.5, 0.16), white, Vector3(0, 1.2, 0))
		Mats.part(root, _hex(0.2, 0.3, 0.06), gold, Vector3(0, 1.3, 0))
		Mats.part(root, Mats.crystal(0.13, 0.46), ice if not is_new else Mats.glow(Color(0.95, 0.98, 1.0), 3.0), Vector3(0, 1.5, 0), Vector3.ZERO, Vector3.ONE, false)
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			Mats.part(root, Mats.crystal(0.05, 0.2), accent, Vector3(sin(a) * 0.16, 1.4, cos(a) * 0.16), Vector3(cos(a) * 30.0, 0, -sin(a) * 30.0), Vector3.ONE, false)
		if is_new:
			# Platinum NEW crate: a gold star burst on the crown and a second gold band.
			Mats.part(root, _hex(0.6, 0.6, 0.04), gold, Vector3(0, 0.12, 0))
			for k in 8:
				var a := TAU * k / 8.0
				Mats.part(root, Mats.crystal(0.025, 0.16), Mats.glow(Color(1.0, 0.86, 0.45), 2.6), Vector3(sin(a) * 0.12, 1.5, cos(a) * 0.12), Vector3(cos(a) * 70.0, 0, -sin(a) * 70.0), Vector3.ONE, false)
		Mats.part(root, Mats.cyl(0.2, 0.25, 0.07, 18, false), gold, Vector3(0, 0.53, 0))
		Mats.part(root, Mats.cyl(0.17, 0.17, 0.02, 18, false), Mats.glow(glow_col.lerp(Color.WHITE, 0.35), 3.0), Vector3(0, 0.57, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.bake(root)
		var content := Node3D.new()
		content.name = "Content"
		content.position = Vector3(0, 0.58, 0)
		root.add_child(content)
		root.set_meta("content", content)
		_crate_fill(root, weapon)
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.light_color = glow_col.lerp(ICE, 0.4)
		lamp.light_energy = 1.6
		lamp.omni_range = 2.2
		lamp.omni_attenuation = 1.4
		lamp.position = Vector3(0, 0.95, 0.15)
		lamp.shadow_enabled = false
		root.add_child(lamp)
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		glass.mesh = _hex(0.44, 0.47, 0.6)
		var gm := ShaderMaterial.new()
		gm.shader = GLASS_SHADER
		gm.set_shader_parameter("color", ICE.lerp(glow_col, 0.3))
		gm.set_shader_parameter("noise_tex", NOISE_TEX)
		gm.set_shader_parameter("height", 0.6)
		glass.material_override = gm
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.position = Vector3(0, 0.79, 0)
		root.add_child(glass)
		root.set_meta("glass", glass)
	var ring := MeshInstance3D.new()
	ring.name = "Beacon"
	ring.mesh = Mats.quad(Vector2(2.1, 2.1))
	ring.material_override = _aura_material(glow_col)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.03, 0)
	root.add_child(ring)
	root.set_meta("beacon", ring)
	var tall := is_new or bool((ArsenalData.RARITIES.get(rarity, {}) as Dictionary).get("beam", false))
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55 if not tall else 0.42
	cm.bottom_radius = 0.6 if not tall else 0.5
	cm.height = 5.0 if not tall else 9.0
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	pillar.mesh = cm
	var pm := ShaderMaterial.new()
	pm.shader = PILLAR_SHADER
	pm.set_shader_parameter("color", (Color(1, 1, 1) if tall else glow_col.lerp(Color.WHITE, 0.15)))
	pm.set_shader_parameter("noise_tex", NOISE_TEX)
	pm.set_shader_parameter("strength", 1.7 if not tall else 2.1)
	pillar.material_override = pm
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.position = Vector3(0, cm.height * 0.5, 0)
	root.add_child(pillar)
	var l := _label(str(hp) if hp > 0 else "", 120, Color(1.0, 0.96, 0.86))
	l.position = Vector3(0, 1.98, 0)
	root.add_child(l)
	root.set_meta("label", l)
	var badge := str(opts.get("badge", ""))
	if badge != "":
		var b := _label(badge, 64, Color(1.0, 0.86, 0.4))
		b.position = Vector3(0, 2.42, 0)
		root.add_child(b)
		root.set_meta("badge", b)
	if int(opts.get("bonus", 0)) > 0:
		_bonus_ring(root)
	return root


## Swaps the miniature in the crate window (e.g. when a "deck" crate resolves at
## ArsenalData.CRATE_RESOLVE_D). "" / "deck" shows the "?" crystal.
static func crate_set_content(node: Node3D, weapon: String) -> void:
	node.set_meta("kind", weapon)
	if node.has_meta("content"):
		_crate_fill(node, weapon)


static func _crate_fill(root: Node3D, weapon: String) -> void:
	var content: Node3D = root.get_meta("content")
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if weapon == "" or weapon == "deck" or not ArsenalData.MACHINES.has(weapon):
		var q := Node3D.new()
		q.name = "Mystery"
		content.add_child(q)
		Mats.part(q, Mats.crystal(0.12, 0.36), Mats.glow(ICE_HOT, 2.2), Vector3(0, 0.24, 0), Vector3.ZERO, Vector3.ONE, false)
		var l := _label("?", 96, Color(1.0, 0.96, 0.86))
		l.position = Vector3(0, 0.26, 0.0)
		q.add_child(l)
		root.set_meta("mini", null)
		return
	var mini := _machine_body(weapon, {"mini": true})
	_apply_groups(mini)
	var big := weapon in ["railgun", "gatling", "cannon", "laser"]
	mini.scale = Vector3.ONE * (0.6 if weapon == "drone" else (0.4 if weapon == "prism" else (0.46 if big else 0.52)))
	if weapon == "drone":
		mini.position.y = -0.24
	elif weapon == "prism":
		mini.position.y = -0.28
	content.add_child(mini)
	root.set_meta("mini", mini)


## The gold BONUS segment (§3.3): 12 segments round the crate base light up as `ratio` 0..1
## of the bonus hp is dealt; full = +1 Rank.
static func crate_bonus(node: Node3D, ratio: float) -> void:
	var segs: Array = node.get_meta("bonus_segs", [])
	var lit := int(round(clampf(ratio, 0.0, 1.0) * segs.size()))
	for i in segs.size():
		(segs[i] as MeshInstance3D).material_override = Mats.glow(Color(1.0, 0.8, 0.3), 3.0) if i < lit else Mats.solid(Color(0.22, 0.2, 0.3), 0.5, 0.3)


static func _bonus_ring(root: Node3D) -> void:
	var g := Node3D.new()
	g.name = "BonusRing"
	g.position = Vector3(0, 0.1, 0)
	root.add_child(g)
	var segs: Array[MeshInstance3D] = []
	Mats.part(g, Mats.torus(0.76, 0.8, 36, 4), Mats.solid(GOLD, 0.3, 0.85), Vector3(0, -0.04, 0))
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		var mi := Mats.part(g, bevel_box(Vector3(0.28, 0.07, 0.08), 0.02), Mats.solid(Color(0.22, 0.2, 0.3), 0.5, 0.3),
			Vector3(sin(a) * 0.78, 0.0, cos(a) * 0.78), Vector3(0, rad_to_deg(a) + 90.0, 0), Vector3.ONE, false)
		segs.append(mi)
	root.set_meta("bonus_segs", segs)
	root.set_meta("bonus_ring", g)


## Cracks spread over the crate glass as `ratio` (0 intact .. 1 broken) grows; `flash` 0..1
## whitens it briefly (set 1 on a hit and let animate() fade it).
static func crate_damage(node: Node3D, ratio: float, flash := 1.0) -> void:
	var glass: MeshInstance3D = _nm(node, "glass")
	if glass == null:
		return
	var m := glass.material_override as ShaderMaterial
	m.set_shader_parameter("damage", clampf(ratio, 0.0, 1.0))
	node.set_meta("flash", flash)
	node.set_meta("shake", 1.0)


static func _animate_crate(node: Node3D, t: float, fire: float) -> void:
	var content: Node3D = _nm(node, "content")
	if content:
		content.rotation.y = fposmod(t * 1.1, TAU)
		content.position.y = 0.58 + sin(t * 2.2) * 0.025
	var mini: Node3D = _nm(node, "mini")
	if mini and is_instance_valid(mini):
		animate(mini, t, 0.0, 0.0)
	var flash := maxf(float(node.get_meta("flash", 0.0)), fire)
	var glass: MeshInstance3D = _nm(node, "glass")
	if glass:
		(glass.material_override as ShaderMaterial).set_shader_parameter("flash", flash)
	node.set_meta("flash", maxf(float(node.get_meta("flash", 0.0)) - 0.12, 0.0))
	var shake := float(node.get_meta("shake", 0.0))
	if shake > 0.0:
		node.rotation.z = sin(t * 60.0) * 0.06 * shake
		node.set_meta("shake", maxf(shake - 0.1, 0.0))
	else:
		node.rotation.z = 0.0
	var beacon: MeshInstance3D = _nm(node, "beacon")
	if beacon:
		var s := 1.0 + 0.06 * sin(t * 3.0)
		beacon.scale = Vector3(s, 1.0, s)
	var ring: Node3D = _nm(node, "bonus_ring")
	if ring:
		ring.rotation.y = fposmod(t * 0.6, TAU)


# ------------------------------------------------------------------ meshes and materials

## A box with chamfered edges (flat-shaded bevels catch highlights; reads premium at small
## sizes). `r` is the chamfer width.
static func bevel_box(size: Vector3, r: float) -> Mesh:
	var key := "bb%s|%.3f" % [size, r]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var signs := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for axis in 3:
		var j := (axis + 1) % 3
		var k := (axis + 2) % 3
		for s: float in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			for sg: Vector2 in signs:
				var p := Vector3.ZERO
				p[axis] = s * h[axis]
				p[j] = sg.x * (h[j] - r)
				p[k] = sg.y * (h[k] - r)
				pts.append(p)
			_poly(st, pts)
	for i in 3:
		var j := (i + 1) % 3
		var k := (i + 2) % 3
		for si: float in [-1.0, 1.0]:
			for sj: float in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for step in 4:
					var p := Vector3.ZERO
					var sk := 1.0 if step == 0 or step == 3 else -1.0
					var on_i := step < 2
					p[i] = si * (h[i] if on_i else h[i] - r)
					p[j] = sj * (h[j] - r if on_i else h[j])
					p[k] = sk * (h[k] - r)
					pts.append(p)
				_poly(st, pts)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var pts: Array[Vector3] = [
					Vector3(sx * h.x, sy * (h.y - r), sz * (h.z - r)),
					Vector3(sx * (h.x - r), sy * h.y, sz * (h.z - r)),
					Vector3(sx * (h.x - r), sy * (h.y - r), sz * h.z),
				]
				_poly(st, pts)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Adds a convex polygon (fan) with a flat outward normal (the shape is centred on 0).
static func _poly(st: SurfaceTool, pts: Array[Vector3]) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot(c) < 0.0:
		pts.reverse()
		n = -n
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i + 1], pts[i]]:
			st.set_normal(n)
			st.add_vertex(p)


## Hexagonal prism, flat-shaded (hex reads best with hard edges).
static func _hex(top: float, bottom: float, height: float) -> Mesh:
	return Mats.cyl(top, bottom, height, 6, true)


## Rank marks: `rank` stacked ▲ chevrons (gold with a light centre on a dark outline).
static func _chevron_mesh(rank: int) -> Mesh:
	var key := "chev%d" % rank
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rank:
		var y0 := i * 0.085
		for layer in 2:
			var w := 0.13 if layer == 0 else 0.105
			var h := 0.085 if layer == 0 else 0.068
			var t := 0.06 if layer == 0 else 0.036
			var z := 0.0 if layer == 0 else 0.004
			var yb := y0 - (0.012 if layer == 0 else 0.0)
			var edge := Color(0.05, 0.07, 0.16) if layer == 0 else Color(1.0, 0.68, 0.18)
			var hi := Color(0.05, 0.07, 0.16) if layer == 0 else Color(1.0, 0.97, 0.75)
			var apex := Vector3(0, yb + h, z)
			var inner := Vector3(0, yb + h - t * 1.1, z)
			for sx: float in [-1.0, 1.0]:
				var outer := Vector3(w * sx, yb, z)
				var outer_in := Vector3((w - t) * sx, yb, z)
				var quad := [[apex, hi], [outer, edge], [outer_in, edge], [inner, hi]]
				var tris := [[0, 1, 2], [0, 2, 3]] if sx > 0.0 else [[0, 2, 1], [0, 3, 2]]
				for tr: Array in tris:
					for vi: int in tr:
						st.set_color(quad[vi][1])
						st.set_normal(Vector3.BACK)
						st.add_vertex(quad[vi][0])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _star_material() -> StandardMaterial3D:
	if _mats.has("star_m"):
		return _mats["star_m"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.25, 1.2, 1.1)
	_mats["star_m"] = m
	return m


## Soft glowing ring on the road (aura / beacon), additive.
static func _aura_material(c: Color) -> StandardMaterial3D:
	var key := "aura" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = _ring_texture()
	m.albedo_color = Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func _pool_material(c: Color) -> StandardMaterial3D:
	var key := "pool" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = Mats.soft_texture()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	_mats[key] = m
	return m


static func _ring_texture() -> Texture2D:
	if _ring_tex:
		return _ring_tex
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var ring := exp(-pow((d - 0.8) / 0.07, 2.0))
			var inner := exp(-pow((d - 0.8) / 0.25, 2.0)) * 0.25 * float(d < 0.8)
			var tick := 0.0
			var ang := atan2(y - c, x - c)
			if d > 0.88 and d < 0.95:
				tick = 0.55 * smoothstep(0.75, 0.95, cos(ang * 12.0))
			var a := clampf(ring + inner + tick, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## A world label: bold number with a dark outline, facing the camera.
static func _label(text: String, px: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if _font == null:
		_font = load("res://assets/fonts/Rubik-ExtraBold.ttf") as Font
	l.font = _font
	l.font_size = px
	l.pixel_size = 0.006
	l.outline_size = maxi(8, px / 6)
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.06, 0.15, 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


## Merges every MeshInstance3D under `root` (StandardMaterial3D albedo → vertex colour) into
## one ArrayMesh for a MultiMesh, and frees `root`.
static func merge(root: Node3D) -> ArrayMesh:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
	_merge_into(g, root, Transform3D.IDENTITY)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g["v"]
	arrays[Mesh.ARRAY_NORMAL] = g["n"]
	arrays[Mesh.ARRAY_COLOR] = g["c"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	root.free()
	return mesh


static func _merge_into(g: Dictionary, n: Node, xf: Transform3D) -> void:
	for ch in n.get_children():
		var t: Transform3D = xf * (ch as Node3D).transform if ch is Node3D else xf
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			Mats._append_mesh(g, mi.mesh, t, mat.albedo_color if mat else Color.WHITE)
		_merge_into(g, ch, t)


## A node meta or null when it is missing (get_meta(key, null) prints an error in Godot 4).
static func _nm(n: Object, key: String) -> Variant:
	return n.get_meta(key) if n.has_meta(key) else null
