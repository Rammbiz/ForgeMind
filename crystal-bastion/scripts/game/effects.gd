class_name Effects
extends Node3D
## One-shot visual effects: particles, flashes, rings, lightning, coins.

var quality_high := true
var _lightning: Array = []   # [{mesh: MeshInstance3D, t: float, life: float}]
var _rings: Array = []       # [{node, t, life, from, to}]
var _flashes: Array = []     # [{node, t, life, from, to}]
var _coins: Array = []       # [{node, t, vel}]


func _process(delta: float) -> void:
	for i in range(_lightning.size() - 1, -1, -1):
		var l: Dictionary = _lightning[i]
		l["t"] += delta
		var k: float = 1.0 - l["t"] / l["life"]
		var mi: MeshInstance3D = l["mesh"]
		if k <= 0.0:
			mi.queue_free()
			_lightning.remove_at(i)
		else:
			mi.transparency = 1.0 - k
	for arr in [_rings, _flashes]:
		for i in range(arr.size() - 1, -1, -1):
			var r: Dictionary = arr[i]
			r["t"] += delta
			var k: float = clampf(r["t"] / r["life"], 0.0, 1.0)
			var n: Node3D = r["node"]
			var e := 1.0 - pow(1.0 - k, 3.0)
			n.scale = Vector3.ONE * lerpf(r["from"], r["to"], e)
			(n as GeometryInstance3D).transparency = k
			if k >= 1.0:
				n.queue_free()
				arr.remove_at(i)
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


func flash(pos: Vector3, color: Color, radius := 0.5, life := 0.25) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.sphere(1.0, -1, 12, 6, false)
	mi.material_override = Mats.flat_color(Color(color.r, color.g, color.b, 0.85), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	add_child(mi)
	_flashes.append({"node": mi, "t": 0.0, "life": life, "from": radius * 0.3, "to": radius})


func ring(pos: Vector3, color: Color, radius := 1.0, life := 0.45) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.torus(0.88, 1.0, 32, 3)
	mi.material_override = Mats.flat_color(Color(color.r, color.g, color.b, 0.9), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.05, 0)
	mi.scale = Vector3.ONE * 0.1
	add_child(mi)
	_rings.append({"node": mi, "t": 0.0, "life": life, "from": 0.1, "to": radius})


func explosion(pos: Vector3, radius: float) -> void:
	flash(pos + Vector3(0, 0.15, 0), Color(1.0, 0.65, 0.25), radius * 0.9, 0.3)
	ring(Vector3(pos.x, pos.y, pos.z), Color(1.0, 0.7, 0.35), radius, 0.4)
	burst(pos + Vector3(0, 0.1, 0), Color(1.0, 0.6, 0.2), 22, 3.5, 0.12, 0.55, -6.0)
	burst(pos + Vector3(0, 0.2, 0), Color(0.35, 0.32, 0.3), 10, 1.2, 0.3, 0.9, 0.8, false)


func frost_nova(pos: Vector3, radius: float) -> void:
	flash(pos + Vector3(0, 0.1, 0), Color(0.5, 0.9, 1.0), radius * 0.6, 0.25)
	ring(pos, Color(0.6, 0.95, 1.0), radius, 0.4)
	burst(pos + Vector3(0, 0.15, 0), Color(0.75, 0.95, 1.0), 14, 2.0, 0.08, 0.6, -2.0)


func hit_spark(pos: Vector3, color: Color) -> void:
	burst(pos, color, 6, 1.6, 0.06, 0.3, -3.0)


func death(pos: Vector3, color: Color, size: float) -> void:
	burst(pos + Vector3(0, size * 0.6, 0), color, 18 + int(size * 20), 2.4 + size * 2.0, 0.09 + size * 0.15, 0.6, -5.0, false)
	burst(pos + Vector3(0, size * 0.6, 0), Color(1, 1, 1), 8, 1.8, 0.07, 0.35, -1.0)
	flash(pos + Vector3(0, size * 0.6, 0), color.lightened(0.3), size * 1.6, 0.2)


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


## Jagged lightning through the given points.
func lightning(points: Array[Vector3], color: Color, life := 0.18, width := 0.05) -> void:
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
	mi.material_override = _lightning_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_lightning.append({"mesh": mi, "t": 0.0, "life": life})
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
