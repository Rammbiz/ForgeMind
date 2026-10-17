extends SceneTree
## Loads a GLB at runtime (no import step), prints mesh/material stats and renders
## a few views to PNG so a model can be checked without the editor.
##
##   xvfb-run -a godot --path crystal-bastion --rendering-driver opengl3 --resolution 1280x720 \
##     -s res://tools/inspect_glb.gd -- --glb=/path/model.glb --out=/tmp/prefix

var _glb := ""
var _out := "/tmp/glb"
var _root: Node3D
var _cam: Camera3D
var _frames := 0
var _views: Array = []
var _aabb := AABB()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="):
			_glb = a.substr(6)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_glb, state)
	if err != OK:
		push_error("GLB load failed: %s" % error_string(err))
		quit(1)
		return
	_root = doc.generate_scene(state)
	root.add_child(_root)
	_report()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.36, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	_cam = Camera3D.new()
	root.add_child(_cam)
	var c := _aabb.get_center()
	var r := _aabb.size.length() * 0.5
	# name, camera position, look target, orthographic size (0 = perspective)
	_views = [
		["top", c + Vector3(0, r * 3.0, 0.001), c, maxf(_aabb.size.x, _aabb.size.z) * 1.05],
		["front", c + Vector3(0, r * 1.25, r * 1.85), c, 0.0],
		["side", c + Vector3(r * 2.2, r * 0.4, 0), c, 0.0],
		["back", c + Vector3(0, r * 1.0, -r * 2.2), c, 0.0],
	]


func _report() -> void:
	var tris := 0
	var mats := {}
	var first := true
	for mi in _meshes(_root):
		var m := mi.mesh
		var xf := _xf(mi)
		var box := xf * m.get_aabb()
		_aabb = box if first else _aabb.merge(box)
		first = false
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx.size() > 0 else verts.size()) / 3
			var mat := m.surface_get_material(s)
			if mat and not mats.has(mat):
				mats[mat] = true
				var info := "material %s" % mat.resource_name
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					for slot in [["albedo", sm.albedo_texture], ["normal", sm.normal_texture], ["orm/rough", sm.roughness_texture], ["metal", sm.metallic_texture], ["emission", sm.emission_texture]]:
						if slot[1]:
							info += " %s=%dx%d" % [slot[0], slot[1].get_width(), slot[1].get_height()]
					info += " metal=%.2f rough=%.2f" % [sm.metallic, sm.roughness]
				print(info)
	print("meshes=%d tris=%d aabb=%s size=%s" % [_meshes(_root).size(), tris, _aabb, _aabb.size])


func _xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p is Node3D and p != _root.get_parent():
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_meshes(ch))
	return out


func _process(_delta: float) -> bool:
	_frames += 1
	var vi := _frames / 4
	var phase := _frames % 4
	if vi >= _views.size():
		return true
	var v: Array = _views[vi]
	if phase == 1:
		_cam.position = v[1]
		_cam.look_at(v[2], Vector3.UP if absf((v[2] - v[1]).normalized().y) < 0.99 else Vector3.FORWARD)
		if float(v[3]) > 0.0:
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = float(v[3])
		else:
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.fov = 40.0
		_cam.near = 0.01
		_cam.far = 1000.0
	elif phase == 3:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [_out, v[0]])
		print("saved %s_%s.png" % [_out, v[0]])
	return false
