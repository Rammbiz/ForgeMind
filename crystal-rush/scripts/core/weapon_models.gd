class_name WeaponModels
## Procedural war machines of the player's army and the weapon crates that hold them.
## Player palette: white enamel, gold trim, dark navy running gear and ice-blue glowing
## crystals; chunky toy proportions with bevelled hulls so edges catch the light.
##
## Machines face -Z (the run direction, towards the enemy) out of the box. Every machine has:
##   meta "yaw"     Node3D turned about Y to aim (see aim())
##   meta "muzzle"  Node3D marker where shots leave (global_position)
##   meta "kind"    weapon key; meta "level" 1..3 (see set_level())
## Wheeled machines (ballista, cannon, laser, rockets) are ~0.8 tall; the drone hovers with
## its body ~0.6 above the road. animate() drives recoil, wheels, the drone bob and rotors.
## A GLB override (Worlds.LIST[world].models[kind], see asset()) replaces the procedural body.

const KINDS: Array[String] = ["ballista", "cannon", "laser", "rockets", "drone"]
const WHITE := Color(0.93, 0.94, 0.98)
const PEARL := Color(0.72, 0.76, 0.86)
const GOLD := Color(1.0, 0.76, 0.3)
const NAVY := Color(0.14, 0.18, 0.31)
const ICE := Color(0.36, 0.82, 1.0)
const ICE_HOT := Color(0.72, 0.95, 1.0)
const COLORS := {
	"ballista": Color(1.0, 0.8, 0.36),
	"cannon": Color(0.62, 0.52, 1.0),
	"laser": Color(0.3, 0.92, 1.0),
	"rockets": Color(1.0, 0.56, 0.3),
	"drone": Color(0.42, 1.0, 0.7),
}
const WHEEL_R := 0.17
const DRONE_Y := 0.62
const GLASS_SHADER := preload("res://shaders/weapon_glass.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

static var _meshes := {}
static var _mats := {}
static var _ring_tex: Texture2D
static var _font: Font


## Signature colour of a weapon (crate beacon, HUD accents, projectile tint).
static func icon_color(kind: String) -> Color:
	return COLORS.get(kind, ICE)


## A war machine of `kind` (one of KINDS) at level 1.
static func machine(kind: String) -> Node3D:
	var root := _machine_body(kind)
	set_level(root, 1)
	return root


static func _machine_body(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Machine_" + kind
	root.set_meta("kind", kind)
	root.set_meta("role", "machine")
	root.set_meta("level", 1)
	var glb := asset(kind, AABB(Vector3(-0.4, 0, -0.5), Vector3(0.8, 0.85, 1.0)))
	if glb != null:
		var yaw0 := Node3D.new()
		yaw0.name = "Yaw"
		root.add_child(yaw0)
		yaw0.add_child(glb)
		var mz := Node3D.new()
		mz.name = "Muzzle"
		mz.position = Vector3(0, 0.45, -0.55)
		yaw0.add_child(mz)
		root.set_meta("yaw", yaw0)
		root.set_meta("muzzle", mz)
		root.set_meta("wheels", [])
		root.set_meta("star_y", 1.05)
		return root
	var yaw := Node3D.new()
	yaw.name = "Yaw"
	var recoil := Node3D.new()
	recoil.name = "Recoil"
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	var star_y := 1.05
	if kind == "drone":
		var hover := Node3D.new()
		hover.name = "Hover"
		hover.position = Vector3(0, DRONE_Y, 0)
		root.add_child(hover)
		hover.add_child(yaw)
		root.set_meta("hover", hover)
		_drone(root, yaw, recoil, muzzle)
		star_y = 1.08
	else:
		_chassis(root)
		yaw.position = Vector3(0, 0.44, 0)
		root.add_child(yaw)
		match kind:
			"ballista":
				_ballista(root, yaw, recoil, muzzle)
			"cannon":
				_cannon(root, yaw, recoil, muzzle)
			"laser":
				_laser(root, yaw, recoil, muzzle)
				star_y = 1.12
			_:
				_rockets(root, yaw, recoil, muzzle)
	yaw.add_child(recoil)
	if muzzle.get_parent() == null:
		recoil.add_child(muzzle)
	root.set_meta("yaw", yaw)
	root.set_meta("recoil", recoil)
	root.set_meta("muzzle", muzzle)
	root.set_meta("star_y", star_y)
	Mats.bake(root)
	return root


## Optional sculpted override: a GLB listed in a world's "models" under `key`, scaled to fit
## `fit` (bottom centred). Returns null when no world lists it or the file is missing.
static func asset(key: String, fit: AABB) -> Node3D:
	for w: Dictionary in Worlds.LIST.values():
		var models: Dictionary = w.get("models", {})
		var path := str(models.get(key, ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate() as Node3D
		var box := _visual_aabb(inst, Transform3D.IDENTITY)
		if box.size.length() < 0.0001:
			return inst
		var k := minf(fit.size.x / box.size.x, minf(fit.size.y / box.size.y, fit.size.z / box.size.z))
		inst.scale = Vector3.ONE * k
		var centre := box.get_center() * k
		inst.position = Vector3(fit.get_center().x - centre.x, fit.position.y - box.position.y * k, fit.get_center().z - centre.z)
		return inst
	return null


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


## Shows `level` gold stars above the machine (1..3). Level 2 adds an ice aura ring on the
## road under it, level 3 a gold one.
static func set_level(node: Node3D, level: int) -> void:
	level = clampi(level, 1, 3)
	node.set_meta("level", level)
	for n in ["Stars", "Aura"]:
		var old := node.get_node_or_null(n)
		if old:
			node.remove_child(old)
			old.queue_free()
	var stars := Node3D.new()
	stars.name = "Stars"
	stars.position = Vector3(0, float(node.get_meta("star_y", 1.05)), 0)
	node.add_child(stars)
	for i in level:
		var s := MeshInstance3D.new()
		s.mesh = _star_mesh()
		s.material_override = _star_material()
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = Vector3((i - (level - 1) * 0.5) * 0.24, -absf(i - (level - 1) * 0.5) * 0.04, 0)
		s.scale = Vector3.ONE * (1.0 if level == 1 or i * 2 == level - 1 else 0.86)
		stars.add_child(s)
	node.set_meta("stars", stars)
	if level >= 2:
		var aura := MeshInstance3D.new()
		aura.name = "Aura"
		aura.mesh = Mats.quad(Vector2(1.5, 1.5))
		aura.material_override = _aura_material(ICE if level == 2 else GOLD)
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.position = Vector3(0, 0.03, 0)
		node.add_child(aura)


## Turns the machine's yaw node so the muzzle faces `target` (world space). `weight` < 1
## eases towards it (call every frame with e.g. 1 - exp(-12 * delta)).
static func aim(node: Node3D, target: Vector3, weight := 1.0) -> void:
	var yaw: Node3D = node.get_meta("yaw", null)
	if yaw == null or not node.is_inside_tree():
		return
	var parent := yaw.get_parent() as Node3D
	var local := parent.global_transform.affine_inverse() * target - yaw.position
	if Vector2(local.x, local.z).length_squared() < 0.0001:
		return
	var want := atan2(-local.x, -local.z)
	yaw.rotation.y = lerp_angle(yaw.rotation.y, want, clampf(weight, 0.0, 1.0))


## Animates a machine or a crate. `t` is the run time in seconds, `fire` 0..1 is the shot
## kick (1 right after a shot, decaying to 0; for the laser: the beam intensity). `roll` is the
## distance travelled for the wheels (by default t × Balance.RUN_SPEED).
static func animate(node: Node3D, t: float, fire: float, roll := -1.0) -> void:
	if str(node.get_meta("role", "")) == "crate":
		_animate_crate(node, t, fire)
		return
	var kind := str(node.get_meta("kind", ""))
	fire = clampf(fire, 0.0, 1.0)
	var kick := fire * fire * (3.0 - 2.0 * fire)
	var dist := roll if roll >= 0.0 else t * Balance.RUN_SPEED
	for w: Node3D in node.get_meta("wheels", []):
		w.rotation.x = -dist / WHEEL_R
	var recoil: Node3D = node.get_meta("recoil", null)
	if recoil == null:
		return
	match kind:
		"ballista":
			recoil.position.z = kick * 0.12
			var bolt: Node3D = node.get_meta("bolt", null)
			if bolt:
				var load := clampf(1.0 - fire * 1.6, 0.0, 1.0)
				bolt.scale = Vector3.ONE * maxf(load, 0.001)
			for arm: Node3D in node.get_meta("arms", []):
				arm.rotation.y = float(arm.get_meta("side")) * (0.32 * kick - 0.05)
		"cannon":
			recoil.position.z = kick * 0.16
			var core: Node3D = node.get_meta("core", null)
			if core:
				core.scale = Vector3.ONE * (1.0 + 0.5 * kick + 0.08 * sin(t * 9.0))
		"laser":
			var gem: Node3D = node.get_meta("gem", null)
			if gem:
				gem.rotation.z = t * (1.5 + fire * 10.0)
				gem.scale = Vector3.ONE * (1.0 + fire * 0.18 + 0.04 * sin(t * 6.0))
			recoil.position.z = 0.02 * fire * sin(t * 40.0)
		"rockets":
			recoil.position.z = kick * 0.1
			var tips: Node3D = node.get_meta("tips", null)
			if tips:
				tips.scale = Vector3.ONE * maxf(clampf(1.0 - fire * 1.4, 0.0, 1.0), 0.001)
		"drone":
			var hover: Node3D = node.get_meta("hover", null)
			if hover:
				hover.position.y = DRONE_Y + sin(t * 2.6) * 0.05
				hover.rotation.z = sin(t * 1.7) * 0.06
				hover.rotation.x = sin(t * 2.1) * 0.04 + kick * 0.12
			for r: Node3D in node.get_meta("rotors", []):
				r.rotation.y = t * 38.0 * (1.0 if r.get_meta("cw") else -1.0)
			recoil.position.z = kick * 0.05


# ------------------------------------------------------------------ crate

## Weapon crate: a white-and-gold hexagonal capsule with an ice glass window showing the
## miniature machine inside on a glowing pedestal, a beacon ring in the weapon's colour and
## a hp label. Faces +Z (towards the army). Metas: "label" (Label3D), "content" (the
## miniature pivot), "glass" (MeshInstance3D, see crate_damage()), "kind", "role" = "crate".
static func crate(weapon: String, hp := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Crate_" + weapon
	root.set_meta("kind", weapon)
	root.set_meta("role", "crate")
	var col := icon_color(weapon)
	var glb := asset("crate", AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.4, 1.2)))
	if glb != null:
		root.add_child(glb)
	else:
		var white := Mats.solid(WHITE, 0.35, 0.2)
		var pearl := Mats.solid(PEARL, 0.45, 0.25)
		var gold := Mats.solid(GOLD, 0.3, 0.85)
		var navy := Mats.solid(NAVY, 0.6, 0.3)
		var ice := Mats.glow(ICE, 2.6)
		var accent := Mats.glow(col, 2.8)
		# Base: gold plinth, a white hexagonal body with glowing emblems, a gold band.
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
				Mats.part(root, bevel_box(Vector3(0.18, 0.025, 0.03), 0.008), ice, face + dir * 0.03 + Vector3(0, -0.08, 0), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
		# Three ribs holding the glass and the crown.
		for k in 3:
			var a := TAU * (k * 2 + 1) / 6.0 + TAU / 12.0
			var p := Vector3(sin(a), 0, cos(a)) * 0.47
			Mats.part(root, bevel_box(Vector3(0.1, 0.64, 0.1), 0.03), white, p + Vector3(0, 0.78, 0), Vector3(0, rad_to_deg(a), 0))
			Mats.part(root, bevel_box(Vector3(0.12, 0.05, 0.12), 0.015), gold, p + Vector3(0, 0.62, 0), Vector3(0, rad_to_deg(a), 0))
			Mats.part(root, Mats.crystal(0.035, 0.14), accent, p * 1.12 + Vector3(0, 0.82, 0), Vector3.ZERO, Vector3.ONE, false)
		# Crown.
		Mats.part(root, _hex(0.5, 0.5, 0.05), gold, Vector3(0, 1.1, 0))
		Mats.part(root, _hex(0.3, 0.5, 0.16), white, Vector3(0, 1.2, 0))
		Mats.part(root, _hex(0.2, 0.3, 0.06), gold, Vector3(0, 1.3, 0))
		Mats.part(root, Mats.crystal(0.13, 0.46), ice, Vector3(0, 1.5, 0), Vector3.ZERO, Vector3.ONE, false)
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			Mats.part(root, Mats.crystal(0.05, 0.2), accent, Vector3(sin(a) * 0.16, 1.4, cos(a) * 0.16), Vector3(cos(a) * 30.0, 0, -sin(a) * 30.0), Vector3.ONE, false)
		# Pedestal with a glowing top in the weapon's colour.
		Mats.part(root, Mats.cyl(0.2, 0.25, 0.07, 18, false), gold, Vector3(0, 0.53, 0))
		Mats.part(root, Mats.cyl(0.17, 0.17, 0.02, 18, false), Mats.glow(col.lerp(Color.WHITE, 0.35), 3.0), Vector3(0, 0.57, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.bake(root)
		# The miniature, turning slowly behind the glass, lit from inside.
		var content := Node3D.new()
		content.name = "Content"
		content.position = Vector3(0, 0.58, 0)
		root.add_child(content)
		var mini := _machine_body(weapon)
		mini.scale = Vector3.ONE * (0.52 if weapon != "drone" else 0.6)
		if weapon == "drone":
			mini.position.y = -0.24
		content.add_child(mini)
		root.set_meta("content", content)
		root.set_meta("mini", mini)
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.light_color = col.lerp(ICE, 0.4)
		lamp.light_energy = 1.6
		lamp.omni_range = 2.2
		lamp.omni_attenuation = 1.4
		lamp.position = Vector3(0, 0.95, 0.15)
		lamp.shadow_enabled = false
		root.add_child(lamp)
		# Glass capsule: a hex window with a tapered top.
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		glass.mesh = _hex(0.44, 0.47, 0.6)
		var gm := ShaderMaterial.new()
		gm.shader = GLASS_SHADER
		gm.set_shader_parameter("color", ICE.lerp(col, 0.3))
		gm.set_shader_parameter("noise_tex", NOISE_TEX)
		gm.set_shader_parameter("height", 0.6)
		glass.material_override = gm
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.position = Vector3(0, 0.79, 0)
		root.add_child(glass)
		root.set_meta("glass", glass)
	# Beacon ring on the road in the weapon's colour.
	var ring := MeshInstance3D.new()
	ring.name = "Beacon"
	ring.mesh = Mats.quad(Vector2(2.1, 2.1))
	ring.material_override = _aura_material(col)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.03, 0)
	root.add_child(ring)
	root.set_meta("beacon", ring)
	var l := _label(str(hp) if hp > 0 else "", 120, Color(1.0, 0.96, 0.86))
	l.position = Vector3(0, 1.98, 0)
	root.add_child(l)
	root.set_meta("label", l)
	return root


## Cracks spread over the crate glass as `ratio` (0 intact .. 1 broken) grows; `flash` 0..1
## whitens it briefly (set 1 on a hit and let animate() fade it).
static func crate_damage(node: Node3D, ratio: float, flash := 1.0) -> void:
	var glass: MeshInstance3D = node.get_meta("glass", null)
	if glass == null:
		return
	var m := glass.material_override as ShaderMaterial
	m.set_shader_parameter("damage", clampf(ratio, 0.0, 1.0))
	node.set_meta("flash", flash)
	node.set_meta("shake", 1.0)


static func _animate_crate(node: Node3D, t: float, fire: float) -> void:
	var content: Node3D = node.get_meta("content", null)
	if content:
		content.rotation.y = t * 1.1
		content.position.y = 0.58 + sin(t * 2.2) * 0.025
	var mini: Node3D = node.get_meta("mini", null)
	if mini:
		animate(mini, t, 0.0, 0.0)
	var flash := maxf(float(node.get_meta("flash", 0.0)), fire)
	var glass: MeshInstance3D = node.get_meta("glass", null)
	if glass:
		(glass.material_override as ShaderMaterial).set_shader_parameter("flash", flash)
	node.set_meta("flash", maxf(float(node.get_meta("flash", 0.0)) - 0.12, 0.0))
	var shake := float(node.get_meta("shake", 0.0))
	if shake > 0.0:
		node.rotation.z = sin(t * 60.0) * 0.06 * shake
		node.set_meta("shake", maxf(shake - 0.1, 0.0))
	else:
		node.rotation.z = 0.0
	var beacon: MeshInstance3D = node.get_meta("beacon", null)
	if beacon:
		var s := 1.0 + 0.06 * sin(t * 3.0)
		beacon.scale = Vector3(s, 1.0, s)


# ------------------------------------------------------------------ machines

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
			m = Mats.solid(Color(0.1, 0.12, 0.2), 0.8)
		"ice":
			m = Mats.glow(ICE, 2.0)
		"hot":
			m = Mats.glow(ICE_HOT, 2.6)
	_mats[key] = m
	return m


## Bevelled hull with gold skirt, navy belly, crystal headlights, a power cell and four
## spoked wheels on two axles (pivots in meta "wheels").
static func _chassis(root: Node3D) -> void:
	Mats.part(root, bevel_box(Vector3(0.54, 0.17, 0.84), 0.05), _mat("white"), Vector3(0, 0.31, 0))
	Mats.part(root, bevel_box(Vector3(0.6, 0.06, 0.9), 0.02), _mat("gold"), Vector3(0, 0.215, 0))
	Mats.part(root, bevel_box(Vector3(0.42, 0.1, 0.72), 0.02), _mat("navy"), Vector3(0, 0.16, 0))
	Mats.part(root, bevel_box(Vector3(0.3, 0.05, 0.3), 0.015), _mat("pearl"), Vector3(0, 0.41, 0.24))
	for sx: float in [-1.0, 1.0]:
		Mats.part(root, bevel_box(Vector3(0.09, 0.06, 0.03), 0.012), _mat("hot"), Vector3(0.17 * sx, 0.31, -0.425), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(root, bevel_box(Vector3(0.03, 0.05, 0.5), 0.01), _mat("ice"), Vector3(0.272 * sx, 0.31, 0.0), Vector3.ZERO, Vector3.ONE, false)
	# Power cell at the back.
	Mats.part(root, Mats.cyl(0.075, 0.075, 0.22, 6), _mat("ice"), Vector3(0, 0.47, 0.3), Vector3(90, 0, 0), Vector3.ONE, false)
	for z: float in [0.2, 0.4]:
		Mats.part(root, Mats.cyl(0.09, 0.09, 0.035, 12, false), _mat("gold"), Vector3(0, 0.47, z), Vector3(90, 0, 0))
	Mats.part(root, Mats.cyl(0.2, 0.235, 0.06, 20, false), _mat("gold"), Vector3(0, 0.42, -0.04))
	# Two axles (one pivot each, both wheels on it) keep the draw calls down.
	var wheels: Array[Node3D] = []
	for sz: float in [-1.0, 1.0]:
		var axle := Node3D.new()
		axle.name = "Axle"
		axle.position = Vector3(0, WHEEL_R, 0.27 * sz)
		root.add_child(axle)
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(0.33 * sx, 0, 0)
			Mats.part(axle, Mats.cyl(WHEEL_R, WHEEL_R, 0.13, 18, false), _mat("tyre"), c, Vector3(0, 0, 90))
			Mats.part(axle, Mats.cyl(0.11, 0.11, 0.14, 14, false), _mat("gold"), c, Vector3(0, 0, 90))
			Mats.part(axle, Mats.box(Vector3(0.15, 0.2, 0.035)), _mat("white"), c)
			Mats.part(axle, Mats.box(Vector3(0.15, 0.035, 0.2)), _mat("white"), c)
			Mats.part(axle, Mats.cyl(0.045, 0.045, 0.16, 8, false), _mat("ice"), c, Vector3(0, 0, 90), Vector3.ONE, false)
			for k in 8:
				var a := TAU * k / 8.0
				Mats.part(axle, Mats.box(Vector3(0.135, 0.035, 0.05)), _mat("tyre"), c + Vector3(0, cos(a) * WHEEL_R, sin(a) * WHEEL_R), Vector3(rad_to_deg(-a), 0, 0))
		wheels.append(axle)
	root.set_meta("wheels", wheels)


## Ballista: a long stock with a swept bow (arms flex on a shot) and a gold bolt with a
## crystal head that vanishes on the shot and reloads.
static func _ballista(root: Node3D, yaw: Node3D, recoil: Node3D, muzzle: Node3D) -> void:
	Mats.part(yaw, bevel_box(Vector3(0.2, 0.14, 0.24), 0.03), _mat("pearl"), Vector3(0, 0.05, 0.02))
	Mats.part(yaw, bevel_box(Vector3(0.13, 0.1, 0.8), 0.03), _mat("white"), Vector3(0, 0.16, -0.02))
	Mats.part(yaw, bevel_box(Vector3(0.16, 0.03, 0.62), 0.01), _mat("gold"), Vector3(0, 0.215, -0.04))
	Mats.part(yaw, bevel_box(Vector3(0.18, 0.14, 0.12), 0.03), _mat("white"), Vector3(0, 0.2, 0.34))
	Mats.part(yaw, Mats.crystal(0.05, 0.2), _mat("ice"), Vector3(0, 0.33, 0.34), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(yaw, bevel_box(Vector3(0.22, 0.12, 0.1), 0.03), _mat("gold"), Vector3(0, 0.17, -0.3))
	var arms: Array[Node3D] = []
	var tips: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(0.08 * sx, 0.18, -0.3)
		arm.set_meta("side", sx)
		yaw.add_child(arm)
		var dir := Vector3(sx, 0, 0).rotated(Vector3.UP, -sx * deg_to_rad(-22.0))
		Mats.part(arm, bevel_box(Vector3(0.42, 0.075, 0.075), 0.02), _mat("white"), dir * 0.21, Vector3(0, -sx * -22.0, 0))
		Mats.part(arm, bevel_box(Vector3(0.2, 0.09, 0.09), 0.02), _mat("gold"), dir * 0.1, Vector3(0, -sx * -22.0, 0))
		Mats.part(arm, Mats.sphere(0.05, -1, 10, 6, false), _mat("gold"), dir * 0.43)
		Mats.part(arm, Mats.crystal(0.035, 0.12), _mat("hot"), dir * 0.43 + Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
		arms.append(arm)
		tips.append(arm.position + dir * 0.43)
	# Bowstring: two glowing strands from the arm tips back to the nock.
	var nock := Vector3(0, 0.2, 0.06)
	for tp in tips:
		var mid := (tp + nock) * 0.5
		var len := tp.distance_to(nock)
		var s := MeshInstance3D.new()
		s.mesh = Mats.box(Vector3(0.022, 0.022, len))
		s.material_override = _mat("hot")
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		yaw.add_child(s)
		s.transform = Transform3D(Basis.looking_at(tp - mid, Vector3.UP), mid)
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0, 0.245, -0.1)
	recoil.add_child(bolt)
	Mats.part(bolt, Mats.box(Vector3(0.035, 0.035, 0.66)), _mat("gold"), Vector3(0, 0, 0))
	Mats.part(bolt, Mats.crystal(0.055, 0.22), _mat("hot"), Vector3(0, 0, -0.4), Vector3(-90, 0, 0), Vector3.ONE, false)
	Mats.part(bolt, Mats.box(Vector3(0.13, 0.012, 0.09)), _mat("white"), Vector3(0, 0, 0.29))
	Mats.part(bolt, Mats.box(Vector3(0.012, 0.13, 0.09)), _mat("white"), Vector3(0, 0, 0.29))
	muzzle.position = Vector3(0, 0.245, -0.6)
	recoil.add_child(muzzle)
	root.set_meta("bolt", bolt)
	root.set_meta("arms", arms)


## Plasma cannon: a round turret with a fat barrel wrapped in glowing coils, a gold muzzle
## brake and a plasma tank on its back.
static func _cannon(root: Node3D, yaw: Node3D, recoil: Node3D, muzzle: Node3D) -> void:
	Mats.part(yaw, Mats.sphere(0.25, 0.3, 20, 10, false), _mat("white"), Vector3(0, 0.12, 0.02))
	Mats.part(yaw, Mats.torus(0.22, 0.27, 24, 8), _mat("gold"), Vector3(0, 0.1, 0.02))
	for sx: float in [-1.0, 1.0]:
		Mats.part(yaw, bevel_box(Vector3(0.06, 0.12, 0.2), 0.02), _mat("navy"), Vector3(0.24 * sx, 0.14, 0.05))
		Mats.part(yaw, bevel_box(Vector3(0.02, 0.06, 0.14), 0.008), _mat("ice"), Vector3(0.275 * sx, 0.14, 0.05), Vector3.ZERO, Vector3.ONE, false)
	# Plasma tank in a gold cage.
	Mats.part(yaw, Mats.sphere(0.12, -1, 14, 8, false), _mat("hot"), Vector3(0, 0.3, 0.17), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(yaw, Mats.torus(0.115, 0.14, 16, 6), _mat("gold"), Vector3(0, 0.3, 0.17), Vector3(90, 0, 0))
	Mats.part(yaw, Mats.torus(0.115, 0.14, 16, 6), _mat("gold"), Vector3(0, 0.3, 0.17), Vector3(0, 0, 90))
	Mats.part(recoil, Mats.cyl(0.1, 0.125, 0.62, 18, false), _mat("white"), Vector3(0, 0.15, -0.3), Vector3(90, 0, 0))
	for i in 3:
		Mats.part(recoil, Mats.torus(0.105, 0.15, 18, 6), _mat("ice"), Vector3(0, 0.15, -0.16 - i * 0.13), Vector3(90, 0, 0), Vector3.ONE, false)
	Mats.part(recoil, Mats.cyl(0.15, 0.14, 0.11, 16, false), _mat("gold"), Vector3(0, 0.15, -0.62), Vector3(90, 0, 0))
	Mats.part(recoil, Mats.cyl(0.155, 0.155, 0.025, 16, false), _mat("navy"), Vector3(0, 0.15, -0.58), Vector3(90, 0, 0))
	var core := Node3D.new()
	core.name = "Core"
	core.position = Vector3(0, 0.15, -0.66)
	recoil.add_child(core)
	Mats.part(core, Mats.sphere(0.075, -1, 12, 6, false), _mat("hot"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	muzzle.position = Vector3(0, 0.15, -0.72)
	recoil.add_child(muzzle)
	root.set_meta("core", core)


## Laser emitter: a gold dish on a mast focusing a big spinning crystal held by claws.
static func _laser(root: Node3D, yaw: Node3D, recoil: Node3D, muzzle: Node3D) -> void:
	Mats.part(yaw, bevel_box(Vector3(0.24, 0.1, 0.3), 0.03), _mat("pearl"), Vector3(0, 0.04, 0.04))
	Mats.part(yaw, Mats.cyl(0.07, 0.1, 0.26, 12, false), _mat("white"), Vector3(0, 0.18, 0.04))
	Mats.part(yaw, Mats.cyl(0.11, 0.11, 0.04, 12, false), _mat("gold"), Vector3(0, 0.1, 0.04))
	recoil.position = Vector3(0, 0.34, 0)
	Mats.part(recoil, Mats.sphere(0.13, -1, 16, 8, false), _mat("white"), Vector3(0, 0, 0.1))
	Mats.part(recoil, Mats.cyl(0.29, 0.1, 0.12, 24, false), _mat("gold"), Vector3(0, 0, -0.02), Vector3(-90, 0, 0))
	Mats.part(recoil, Mats.cyl(0.25, 0.09, 0.06, 24, false), _mat("white"), Vector3(0, 0, -0.06), Vector3(-90, 0, 0))
	Mats.part(recoil, Mats.cyl(0.07, 0.07, 0.04, 10, false), _mat("hot"), Vector3(0, 0, -0.07), Vector3(-90, 0, 0), Vector3.ONE, false)
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
	Mats.part(gem, Mats.crystal(0.1, 0.46), _mat("hot"), Vector3.ZERO, Vector3(-90, 0, 0), Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		Mats.part(recoil, Mats.crystal(0.045, 0.18), _mat("ice"), Vector3(0.2 * sx, 0.12, 0.08), Vector3(0, 0, -30.0 * sx), Vector3.ONE, false)
		Mats.part(recoil, bevel_box(Vector3(0.05, 0.16, 0.16), 0.015), _mat("navy"), Vector3(0.13 * sx, 0, 0.12))
	muzzle.position = Vector3(0, 0, -0.52)
	recoil.add_child(muzzle)
	root.set_meta("gem", gem)


## Rocket launcher: a bevelled pod pitched up with four tubes; the gold warheads vanish on a
## volley and slide back in.
static func _rockets(root: Node3D, yaw: Node3D, recoil: Node3D, muzzle: Node3D) -> void:
	Mats.part(yaw, bevel_box(Vector3(0.22, 0.12, 0.22), 0.03), _mat("pearl"), Vector3(0, 0.05, 0.02))
	for sx: float in [-1.0, 1.0]:
		Mats.part(yaw, bevel_box(Vector3(0.05, 0.2, 0.14), 0.015), _mat("gold"), Vector3(0.13 * sx, 0.14, 0.02))
	recoil.position = Vector3(0, 0.22, 0.02)
	recoil.rotation_degrees = Vector3(16, 0, 0)
	Mats.part(recoil, bevel_box(Vector3(0.48, 0.34, 0.5), 0.06), _mat("white"), Vector3(0, 0.02, 0))
	for sy: float in [-1.0, 1.0]:
		Mats.part(recoil, bevel_box(Vector3(0.5, 0.04, 0.52), 0.015), _mat("gold"), Vector3(0, 0.02 + 0.13 * sy, 0))
	Mats.part(recoil, bevel_box(Vector3(0.44, 0.3, 0.04), 0.012), _mat("navy"), Vector3(0, 0.02, -0.25))
	Mats.part(recoil, Mats.crystal(0.05, 0.2), _mat("ice"), Vector3(0.14, 0.24, 0.12), Vector3(0, 0, -15), Vector3.ONE, false)
	Mats.part(recoil, bevel_box(Vector3(0.12, 0.06, 0.16), 0.02), _mat("pearl"), Vector3(-0.1, 0.21, 0.08))
	var tips := Node3D.new()
	tips.name = "Tips"
	tips.position = Vector3(0, 0.02, -0.26)
	recoil.add_child(tips)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var p := Vector3(0.11 * sx, 0.075 * sy, 0)
			Mats.part(recoil, Mats.cyl(0.075, 0.075, 0.04, 14, false), _mat("gold"), p + Vector3(0, 0.02, -0.265), Vector3(90, 0, 0))
			Mats.part(recoil, Mats.cyl(0.058, 0.058, 0.045, 12, false), _mat("ice"), p + Vector3(0, 0.02, -0.27), Vector3(90, 0, 0), Vector3.ONE, false)
			Mats.part(tips, Mats.cyl(0.0, 0.05, 0.13, 10, false), _mat("white"), p + Vector3(0, 0, -0.06), Vector3(-90, 0, 0))
			Mats.part(tips, Mats.cyl(0.05, 0.05, 0.03, 10, false), _mat("gold"), p + Vector3(0, 0, -0.01), Vector3(-90, 0, 0))
	muzzle.position = Vector3(0, 0.02, -0.34)
	recoil.add_child(muzzle)
	root.set_meta("tips", tips)


## Drone: a white saucer with a gold ring, a crystal dome and eye, four rotor arms and a
## glowing thruster; a soft light pool on the road shows its height.
static func _drone(root: Node3D, yaw: Node3D, recoil: Node3D, muzzle: Node3D) -> void:
	Mats.part(yaw, Mats.sphere(0.22, 0.17, 24, 10, false), _mat("white"), Vector3.ZERO)
	Mats.part(yaw, Mats.torus(0.2, 0.25, 28, 8), _mat("gold"), Vector3(0, -0.005, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	Mats.part(yaw, Mats.sphere(0.11, 0.13, 16, 8, false), _mat("ice"), Vector3(0, 0.07, 0.02), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(yaw, Mats.cyl(0.13, 0.13, 0.025, 18, false), _mat("gold"), Vector3(0, 0.04, 0.02))
	Mats.part(yaw, Mats.cyl(0.07, 0.03, 0.09, 12, false), _mat("navy"), Vector3(0, -0.1, 0))
	Mats.part(yaw, Mats.cyl(0.05, 0.0, 0.08, 10, false), _mat("hot"), Vector3(0, -0.17, 0), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(yaw, Mats.sphere(0.06, -1, 12, 6, false), _mat("navy"), Vector3(0, -0.02, -0.19))
	Mats.part(yaw, Mats.sphere(0.042, -1, 12, 6, false), _mat("hot"), Vector3(0, -0.02, -0.225), Vector3.ZERO, Vector3.ONE, false)
	var rotors: Array[Node3D] = []
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var dir := Vector3(sin(a), 0, cos(a))
		var arm := MeshInstance3D.new()
		arm.mesh = bevel_box(Vector3(0.05, 0.035, 0.26), 0.012)
		arm.material_override = _mat("white")
		yaw.add_child(arm)
		arm.position = dir * 0.24 + Vector3(0, 0.0, 0)
		arm.rotation = Vector3(0, a, 0)
		var hub := dir * 0.37 + Vector3(0, 0.02, 0)
		Mats.part(yaw, Mats.torus(0.115, 0.14, 22, 6), _mat("gold"), hub)
		Mats.part(yaw, Mats.cyl(0.03, 0.03, 0.06, 8, false), _mat("navy"), hub)
		var rotor := Node3D.new()
		rotor.name = "Rotor"
		rotor.position = hub + Vector3(0, 0.035, 0)
		rotor.set_meta("cw", k % 2 == 0)
		yaw.add_child(rotor)
		Mats.part(rotor, bevel_box(Vector3(0.21, 0.012, 0.04), 0.004), _mat("pearl"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(rotor, bevel_box(Vector3(0.04, 0.012, 0.21), 0.004), _mat("pearl"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(rotor, Mats.sphere(0.022, -1, 8, 4, false), _mat("ice"), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ONE, false)
		rotors.append(rotor)
	for sx: float in [-1.0, 1.0]:
		Mats.part(recoil, Mats.cyl(0.025, 0.025, 0.16, 8, false), _mat("navy"), Vector3(0.08 * sx, -0.07, -0.14), Vector3(90, 0, 0))
		Mats.part(recoil, Mats.cyl(0.03, 0.03, 0.03, 8, false), _mat("gold"), Vector3(0.08 * sx, -0.07, -0.22), Vector3(90, 0, 0))
	muzzle.position = Vector3(0, -0.07, -0.25)
	recoil.add_child(muzzle)
	root.set_meta("rotors", rotors)
	root.set_meta("wheels", [])
	var pool := MeshInstance3D.new()
	pool.name = "LightPool"
	pool.mesh = Mats.quad(Vector2(0.9, 0.9))
	pool.material_override = _pool_material()
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.025, 0)
	root.add_child(pool)


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
	# Edge bevels.
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
	# Corner triangles.
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
	# Godot's front faces wind clockwise seen from outside.
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i + 1], pts[i]]:
			st.set_normal(n)
			st.add_vertex(p)


## Hexagonal prism, flat-shaded (hex reads best with hard edges).
static func _hex(top: float, bottom: float, height: float) -> Mesh:
	return Mats.cyl(top, bottom, height, 6, true)


static func _star_mesh() -> Mesh:
	if _meshes.has("star"):
		return _meshes["star"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dark outline star behind a gold star with a light centre (vertex colours).
	for layer in 2:
		var ro := 0.115 if layer == 0 else 0.09
		var ri := ro * 0.46
		var z := 0.0 if layer == 0 else 0.004
		var edge := Color(0.05, 0.07, 0.16) if layer == 0 else Color(1.0, 0.68, 0.18)
		var centre := Color(0.05, 0.07, 0.16) if layer == 0 else Color(1.0, 0.97, 0.75)
		for i in 10:
			var a0 := PI * 0.5 + TAU * i / 10.0
			var a1 := PI * 0.5 + TAU * (i + 1) / 10.0
			var r0 := ro if i % 2 == 0 else ri
			var r1 := ro if (i + 1) % 2 == 0 else ri
			for v in [[Vector3(0, 0, z), centre], [Vector3(cos(a1) * r1, sin(a1) * r1, z), edge], [Vector3(cos(a0) * r0, sin(a0) * r0, z), edge]]:
				st.set_color(v[1])
				st.set_normal(Vector3.BACK)
				st.add_vertex(v[0])
	var mesh := st.commit()
	_meshes["star"] = mesh
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


static func _pool_material() -> StandardMaterial3D:
	if _mats.has("pool"):
		return _mats["pool"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = Mats.soft_texture()
	m.albedo_color = Color(ICE.r, ICE.g, ICE.b, 0.55)
	_mats["pool"] = m
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
