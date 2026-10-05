extends SceneTree
## Vertex-animation-texture (VAT) baker for crowd units drawn by CrowdView with
## shaders/crowd_vat.gdshader (one MultiMesh, every unit playing a real skeletal clip).
##
##   godot --headless --path . --script res://tools/bake_vat.gd -- \
##       --in=res://assets/units/knight/knight_src.glb --out=res://assets/units/knight/
##   options:
##       --anims=a.glb,b.glb|lib.res  extra animation sources (GLB/GLTF files or an AnimationLibrary /
##                                    Animation resource). Default: <out>/<name>_anims.res if present.
##       --save-anims                 also write the extra animations to <out>/<name>_anims.res, so the
##                                    big source GLBs do not have to live in the project
##       --clips=run,walk,...         bake only these clips (default: all of CLIPS)
##       --height=0.75                height of the baked unit in world units (feet at y = 0)
##       --max-width=4096             widest texture row; more vertices wrap onto several rows per frame
##       --albedo=PATH                albedo image (default <in without .glb>_albedo.jpg, else the GLB's)
##       --albedo-format=etc2|raw     etc2 (default: VRAM-compressed on GLES3 phones) or uncompressed
##       --name=knight                output prefix (default: input name without "_src")
##       --verify                     cross-check the CPU skinning against Skeleton3D +
##                                    MeshInstance3D.bake_mesh_from_current_skeleton_pose()
##
## The source GLB is read with GLTFDocument at bake time, so it needs no editor import. For every
## frame of every clip the baker builds the bone poses (sampled animation or procedural), computes
## the global bone transforms, skins every vertex on the CPU (bind poses from the Skin, up to 4
## weights) and writes:
##   <name>_vat_pos.res     ImageTexture RGBAH: xyz = position (feet at y = 0, facing +Z), w = root
##                          yaw in radians (only "despin" clips use it; the shader re-applies it so
##                          fast spins interpolate as rotations instead of collapsing chords)
##   <name>_vat_nrm.res     ImageTexture RGBAH: xyz = normal (same de-spun frame)
##   <name>_vat_mesh.res    ArrayMesh of the rest pose: UV = albedo UV, UV2.x = vertex index,
##                          custom_aabb = every baked frame; meta "vat" = the clip table
##   <name>_vat_albedo.res  albedo with mipmaps (ETC2 by default)
##   <name>_vat.json        the clip table, human readable
## Texel of vertex v in frame f: (v % width, f * rows_per_frame + v / width).

## name: clip id. src: "anim:<Animation name>" or "proc:<function>". frames: baked frames.
## start/length: seconds of the source to sample ("auto" length = the loop period; Meshy/Mixamo
## exports repeat the first key at the end, which is dropped so the seam has no duplicate frame).
## leg_fix: re-solve the longer leg with IK (this rig's right leg bones are 25% longer than the
## left, so retargeted clips push that foot through the floor).
## ground: "clip" = one lift for the clip so the lowest foot touches y = 0, "frame" = also lift any
## frame that would dip below the floor. pin_root: drop horizontal root motion. despin: store the
## root yaw in the alpha channel. loop_blend: seconds at the end that blend back into the start pose.
## jump: [t0, t1, height] extra airborne arc (source seconds, model units).
const CLIPS := [
	{"name": "run", "src": "anim:Running", "frames": 19, "start": 0.0, "length": "auto", "loop": true,
		"leg_fix": true, "ground": "clip", "prop_follow": 0.35},
	{"name": "walk", "src": "anim:Walking", "frames": 16, "start": 0.0, "length": "auto", "loop": true,
		"leg_fix": true, "ground": "clip", "prop_follow": 0.35},
	{"name": "attack", "src": "proc:attack", "frames": 16, "start": 0.0, "length": 0.8, "loop": true,
		"ground": "clip"},
	{"name": "idle", "src": "proc:idle", "frames": 8, "start": 0.0, "length": 2.4, "loop": true,
		"ground": "clip"},
	{"name": "victory", "src": "anim:360_Power_Spin_Jump", "frames": 44, "start": 0.45, "length": 2.2,
		"loop": true, "leg_fix": true, "pin_root": true, "despin": true, "ground": "frame",
		"loop_blend": 0.35, "jump": [1.08, 1.86, 0.42]},
]

const FOOT_BONES := ["LeftFoot", "LeftToeBase", "LeftToe_End", "RightFoot", "RightToeBase", "RightToe_End"]

var _args := {}
var _exit := 1
var _frame := 0
var _verify_state := 0

var _root: Node3D
var _sk: Skeleton3D
var _mi: MeshInstance3D
var _nb := 0
var _parent := PackedInt32Array()
var _order := PackedInt32Array()
var _rest: Array = []           # Transform3D local rest per bone
var _bone := {}                 # short bone name ("Hips") -> index
var _vcount := 0
var _wpv := 4                   # weights per vertex
var _pos := PackedVector3Array()
var _nrm := PackedVector3Array()
var _uv := PackedVector2Array()
var _idx := PackedInt32Array()
var _vbone := PackedInt32Array()    # skin bind index per influence
var _vw := PackedFloat32Array()
var _bind: Array = []               # Transform3D per skin bind
var _bind_bone := PackedInt32Array()  # skeleton bone per skin bind
var _foot := PackedInt32Array()     # vertices mostly weighted to a foot or toe
var _anims := {}                    # Animation name -> Animation
var _extra_anims := {}
var _albedo_src: Texture2D

var _rest_glob: Array = []         # Transform3D global rest per bone
var _prop_bone := -1                # bone carrying the held prop's grip (-1 = no prop)
var _prop_grip := Vector3.ZERO      # grip point, rest pose, model space
var _prop_axis := Vector3.UP        # prop direction (butt to tip), rest pose
var _prop_butt := Vector3.ZERO      # lower end of the prop, rest pose
var _prop_follow := 1.0
var _prop_aim: Variant = null       # Basis, set per frame by procedural clips

var _scale := 1.0
var _origin := Vector3.ZERO         # model-space point that becomes (0, 0, 0)
var _verify_clip := {}
var _verify_locals: Array = []
var _verify_p := PackedVector3Array()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		var t0 := Time.get_ticks_msec()
		_exit = 1
		if _bake():
			_exit = 0
			print("VAT bake done in %d ms" % (Time.get_ticks_msec() - t0))
			if _args.has("verify"):
				_verify_state = 1
				return false
		quit(_exit)
		return true
	if _verify_state > 0:
		if not _verify_step():
			quit(_exit)
			return true
		return false
	# A script error inside _bake() lands here on the next frame: give up instead of hanging.
	quit(_exit)
	return true


# ------------------------------------------------------------------------------------------ main

func _bake() -> bool:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var src := str(_args.get("in", "res://assets/units/knight/knight_src.glb"))
	var out := str(_args.get("out", src.get_base_dir())).trim_suffix("/") + "/"
	var prefix := str(_args.get("name", src.get_file().get_basename().trim_suffix("_src")))
	var height := float(_args.get("height", "0.75"))
	var max_w := int(_args.get("max-width", "4096"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	_root = _load_gltf(src)
	if _root == null:
		push_error("bake_vat: cannot read " + src)
		return false
	get_root().add_child(_root)
	if not _read_rig():
		return false
	for ap in _root.find_children("*", "AnimationPlayer", true, false):
		_collect_anims(ap as AnimationPlayer, _anims)
	var anim_src := str(_args.get("anims", ""))
	if anim_src == "" and FileAccess.file_exists(out + prefix + "_anims.res"):
		anim_src = out + prefix + "_anims.res"
	for p in anim_src.split(",", false):
		_load_anim_source(p.strip_edges())
	for k in _extra_anims:
		_anims[k] = _extra_anims[k]
	if _args.has("save-anims") and not _extra_anims.is_empty():
		var lib := AnimationLibrary.new()
		for k in _extra_anims:
			lib.add_animation(k, _extra_anims[k])
		var e := ResourceSaver.save(lib, out + prefix + "_anims.res", ResourceSaver.FLAG_COMPRESS)
		print("saved %s_anims.res (%s): %s" % [prefix, ", ".join(_extra_anims.keys()), error_string(e)])
	print("anims: ", ", ".join(_anims.keys()))

	# Bake space: hips over the origin, feet on y = 0, `height` tall, facing +Z (as the GLB).
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in _pos:
		lo = lo.min(p)
		hi = hi.max(p)
	_rest_glob = _fk(_rest)
	_fix_props(hi.y - lo.y)
	for v in _vcount:
		var o := v * _wpv
		if _vbone[o] == _bind.size():
			continue
		var dom := 0
		for k in _wpv:
			if _vw[o + k] > _vw[o + dom]:
				dom = k
		if _short(_sk.get_bone_name(_bind_bone[_vbone[o + dom]])) in FOOT_BONES:
			_foot.append(v)
	var hips: Transform3D = _rest_glob[_bone["Hips"]]
	_origin = Vector3(hips.origin.x, lo.y, hips.origin.z)
	_scale = height / maxf(hi.y - lo.y, 1e-4)
	print("source: %d vertices, %d triangles, %d bones, %d binds, %d weights/vertex, %.3f tall -> scale %.4f" % [
		_vcount, _idx.size() / 3, _nb, _bind.size(), _wpv, hi.y - lo.y, _scale])

	var want := PackedStringArray(str(_args.get("clips", "")).split(",", false))
	var clips: Array = []
	for c in CLIPS:
		if want.is_empty() or want.has(c["name"]):
			clips.append(c)
	var width := mini(_vcount, max_w)
	var rpf := ceili(float(_vcount) / width)
	var total := 0
	for c in clips:
		total += int(c["frames"])
	var pos_img := Image.create_empty(width, total * rpf, false, Image.FORMAT_RGBAH)
	var nrm_img := Image.create_empty(width, total * rpf, false, Image.FORMAT_RGBAH)
	var table := {}
	var bounds := AABB()
	var first_bounds := true
	var frame0 := 0
	for c in clips:
		var t0 := Time.get_ticks_msec()
		var res := _bake_clip(c)
		if res.is_empty():
			return false
		var frames: Array = res["p"]
		var normals: Array = res["n"]
		var yaw: PackedFloat32Array = res["yaw"]
		for f in frames.size():
			var pf: PackedVector3Array = frames[f]
			var nf: PackedVector3Array = normals[f]
			var cy := cos(yaw[f])
			var sy := sin(yaw[f])
			for v in _vcount:
				var p := pf[v]
				# The shader rotates by +yaw about Y, so store the position with it taken out.
				if first_bounds:
					bounds = AABB(p, Vector3.ZERO)
					first_bounds = false
				else:
					bounds = bounds.expand(p)
				var n := nf[v]
				var x := v % width
				var y := (frame0 + f) * rpf + v / width
				pos_img.set_pixel(x, y, Color(p.x * cy - p.z * sy, p.y, p.x * sy + p.z * cy, yaw[f]))
				nrm_img.set_pixel(x, y, Color(n.x * cy - n.z * sy, n.y, n.x * sy + n.z * cy, 0.0))
		var length: float = res["length"]
		table[c["name"]] = {
			"frame": frame0, "row": frame0 * rpf, "frames": frames.size(),
			"fps": frames.size() / length, "length": length, "loop": bool(c.get("loop", true)),
			"ground_speed": res["ground_speed"], "lift": res["lift"],
		}
		print("  %-8s frames %3d..%3d  %.3f s @ %.2f fps  loop=%s  lift=%.3f  ground speed %.2f u/s  (%d ms)" % [
			c["name"], frame0, frame0 + frames.size() - 1, length, frames.size() / length,
			c.get("loop", true), res["lift"], res["ground_speed"], Time.get_ticks_msec() - t0])
		frame0 += frames.size()

	# Rest mesh: positions only matter for bounds and as a fallback; the shader replaces them.
	var verts := PackedVector3Array()
	verts.resize(_vcount)
	var uv2 := PackedVector2Array()
	uv2.resize(_vcount)
	for v in _vcount:
		verts[v] = _to_bake(_pos[v])
		uv2[v] = Vector2(float(v), 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = _nrm
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	# No compression flags: UV2 must stay a full float to carry the vertex index.
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.custom_aabb = bounds.grow(0.02)
	var meta := {
		"version": 1, "source": src, "vertex_count": _vcount, "triangles": _idx.size() / 3,
		"width": width, "rows_per_frame": rpf, "frames_total": total, "height": height,
		"scale": _scale, "origin": [_origin.x, _origin.y, _origin.z], "facing": "+Z",
		"bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z],
		"textures": {"pos": prefix + "_vat_pos.res", "nrm": prefix + "_vat_nrm.res", "albedo": prefix + "_vat_albedo.res"},
		"clips": table,
	}
	mesh.set_meta("vat", meta)
	mesh.resource_name = prefix + "_vat"

	var err := OK
	err = maxi(err, ResourceSaver.save(ImageTexture.create_from_image(pos_img), out + prefix + "_vat_pos.res", ResourceSaver.FLAG_COMPRESS))
	err = maxi(err, ResourceSaver.save(ImageTexture.create_from_image(nrm_img), out + prefix + "_vat_nrm.res", ResourceSaver.FLAG_COMPRESS))
	err = maxi(err, ResourceSaver.save(mesh, out + prefix + "_vat_mesh.res", ResourceSaver.FLAG_COMPRESS))
	var alb := _albedo_image(src)
	if alb:
		alb.generate_mipmaps()
		if str(_args.get("albedo-format", "etc2")) == "etc2":
			alb.compress(Image.COMPRESS_ETC2, Image.COMPRESS_SOURCE_SRGB)
		err = maxi(err, ResourceSaver.save(ImageTexture.create_from_image(alb), out + prefix + "_vat_albedo.res", ResourceSaver.FLAG_COMPRESS))
	else:
		push_warning("bake_vat: no albedo image found")
	var jf := FileAccess.open(out + prefix + "_vat.json", FileAccess.WRITE)
	if jf:
		jf.store_string(JSON.stringify(meta, "\t", false) + "\n")
		jf.close()
	if err != OK:
		push_error("bake_vat: saving failed: " + error_string(err))
		return false
	var mb := func(f: String) -> String:
		return "%.2f MB" % (FileAccess.get_file_as_bytes(out + f).size() / 1048576.0)
	print("wrote %s{_vat_pos,_vat_nrm,_vat_mesh,_vat_albedo}.res + %s_vat.json" % [out + prefix, prefix])
	print("  textures %dx%d RGBAH (%d rows/frame, %d frames) = %.2f MB each in VRAM; files pos %s, nrm %s, mesh %s, albedo %s" % [
		width, total * rpf, rpf, total, width * total * rpf * 8 / 1048576.0,
		mb.call(prefix + "_vat_pos.res"), mb.call(prefix + "_vat_nrm.res"), mb.call(prefix + "_vat_mesh.res"), mb.call(prefix + "_vat_albedo.res")])
	print("  bounds ", bounds)
	# Read the files back: the shader depends on exact, unfiltered half floats.
	var back := ResourceLoader.load(out + prefix + "_vat_pos.res", "", ResourceLoader.CACHE_MODE_IGNORE) as ImageTexture
	if back == null or back.get_width() != width or back.get_height() != total * rpf:
		push_error("bake_vat: position texture did not load back")
		return false
	var mback := ResourceLoader.load(out + prefix + "_vat_mesh.res", "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	if mback == null or not mback.has_meta("vat"):
		push_error("bake_vat: mesh did not load back")
		return false
	var uv2b: PackedVector2Array = mback.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	if uv2b[_vcount - 1].x != float(_vcount - 1):
		push_error("bake_vat: UV2 vertex index was not kept exactly")
		return false
	return true


# ------------------------------------------------------------------------------------ rig input

func _load_gltf(path: String) -> Node3D:
	var abs_path := ProjectSettings.globalize_path(path) if path.contains("://") else path
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(abs_path, st) != OK:
		return null
	return doc.generate_scene(st) as Node3D


static func _short(bone_name: String) -> String:
	var i := bone_name.find("mixamorig")
	if i >= 0:
		var rest := bone_name.substr(i + 9)
		while rest.length() > 0 and (rest[0] in [":", "_"] or rest[0].is_valid_int()):
			rest = rest.substr(1)
		return rest
	return bone_name


func _read_rig() -> bool:
	for mi in _root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin and m.mesh:
			_mi = m
			break
	if _mi == null:
		push_error("bake_vat: no skinned MeshInstance3D")
		return false
	_sk = _mi.get_node_or_null(_mi.skeleton) as Skeleton3D
	if _sk == null:
		var sks := _root.find_children("*", "Skeleton3D", true, false)
		_sk = sks[0] if sks.size() > 0 else null
	if _sk == null:
		push_error("bake_vat: no Skeleton3D")
		return false
	_nb = _sk.get_bone_count()
	_parent.resize(_nb)
	var depth := PackedInt32Array()
	depth.resize(_nb)
	for b in _nb:
		_parent[b] = _sk.get_bone_parent(b)
		_rest.append(_sk.get_bone_rest(b))
		_bone[_short(_sk.get_bone_name(b))] = b
		var d := 0
		var p := _parent[b]
		while p >= 0:
			d += 1
			p = _sk.get_bone_parent(p)
		depth[b] = d
	var ord := range(_nb)
	ord.sort_custom(func(x: int, y: int) -> bool: return depth[x] < depth[y] or (depth[x] == depth[y] and x < y))
	_order = PackedInt32Array(ord)
	for need in ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot", "Spine", "Spine1", "Spine2", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand"]:
		if not _bone.has(need):
			push_error("bake_vat: the rig has no %s bone (expects a Mixamo-style skeleton)" % need)
			return false
	var skin := _mi.skin
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = _sk.find_bone(skin.get_bind_name(i))
		if b < 0:
			push_error("bake_vat: skin bind %d (%s) matches no bone" % [i, skin.get_bind_name(i)])
			return false
		_bind_bone.append(b)
		_bind.append(skin.get_bind_pose(i))
	# Mesh to skeleton space (identity for Meshy exports, kept for safety).
	var mesh_xf := _sk.global_transform.affine_inverse() * _mi.global_transform if _mi.is_inside_tree() else Transform3D.IDENTITY
	for s in _mi.mesh.get_surface_count():
		var a := _mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if bones.is_empty() or w.is_empty():
			push_warning("bake_vat: surface %d has no skin weights, skipped" % s)
			continue
		_wpv = bones.size() / v.size()
		var base := _vcount
		for i in v.size():
			_pos.append(mesh_xf * v[i])
			_nrm.append((mesh_xf.basis * (n[i] if n.size() > 0 else Vector3.UP)).normalized())
			_uv.append(uv[i] if uv.size() > 0 else Vector2.ZERO)
			var sum := 0.0
			for k in _wpv:
				sum += w[i * _wpv + k]
			var dom := 0
			for k in _wpv:
				_vbone.append(bones[i * _wpv + k])
				_vw.append(w[i * _wpv + k] / maxf(sum, 1e-6))
				if w[i * _wpv + k] > w[i * _wpv + dom]:
					dom = k
		if idx.is_empty():
			for i in v.size():
				idx.append(i)
		for i in idx:
			_idx.append(base + i)
		_vcount += v.size()
		if s == 0:
			var mat := _mi.get_active_material(s) as BaseMaterial3D
			if mat:
				_albedo_src = mat.albedo_texture
	if _vcount == 0:
		return false
	# The Skin's bind poses must describe the rest pose, otherwise "rest" frames would not match.
	var g := _fk(_rest)
	var worst := 0.0
	for i in _bind.size():
		var m: Transform3D = (g[_bind_bone[i]] as Transform3D) * (_bind[i] as Transform3D)
		worst = maxf(worst, m.origin.length() + (m.basis.x - Vector3.RIGHT).length() + (m.basis.y - Vector3.UP).length())
	if worst > 1e-3:
		push_warning("bake_vat: bind poses differ from the skeleton rest (%.4f); frames still use the binds" % worst)
	return true


func _collect_anims(ap: AnimationPlayer, into: Dictionary) -> void:
	for an in ap.get_animation_list():
		var a := ap.get_animation(an)
		var key := an.get_slice("/", an.get_slice_count("/") - 1)
		if a and key != "RESET":
			into[key] = a


func _load_anim_source(p: String) -> void:
	if p.get_extension().to_lower() in ["glb", "gltf"]:
		var n := _load_gltf(p)
		if n == null:
			push_error("bake_vat: cannot read animation source " + p)
			return
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			_collect_anims(ap as AnimationPlayer, _extra_anims)
		n.free()
		return
	var r := load(p)
	if r is AnimationLibrary:
		for k in (r as AnimationLibrary).get_animation_list():
			_extra_anims[str(k)] = (r as AnimationLibrary).get_animation(k)
	elif r is Animation:
		_extra_anims[p.get_file().get_basename()] = r
	else:
		push_error("bake_vat: %s is not an animation source" % p)


func _albedo_image(src: String) -> Image:
	var path := str(_args.get("albedo", src.get_basename() + "_albedo.jpg"))
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.convert(Image.FORMAT_RGB8)
			return img
	if _albedo_src:
		var img2 := _albedo_src.get_image()
		if img2:
			img2.decompress()
			img2.convert(Image.FORMAT_RGB8)
			return img2
	return null


# ---------------------------------------------------------------------------------- pose maths

func _fk(L: Array) -> Array:
	var G := []
	G.resize(_nb)
	for b in _order:
		var p := _parent[b]
		G[b] = L[b] if p < 0 else (G[p] as Transform3D) * (L[b] as Transform3D)
	return G


## Rotates bones about their own joints by character-space rotations (`rot`: bone -> Quaternion,
## axes: +X = the unit's left, +Y up, +Z forward) and moves joints by character-space offsets
## (`move`: bone -> Vector3, meant for the hips). Children follow. Returns new local poses.
func _pose(L: Array, rot: Dictionary, move := {}) -> Array:
	var G := []
	G.resize(_nb)
	var out := L.duplicate()
	for b in _order:
		var p := _parent[b]
		var g: Transform3D = L[b] if p < 0 else (G[p] as Transform3D) * (L[b] as Transform3D)
		if move.has(b):
			g.origin += move[b]
		if rot.has(b):
			g.basis = Basis(rot[b] as Quaternion) * g.basis
		G[b] = g
		out[b] = g if p < 0 else (G[p] as Transform3D).affine_inverse() * g
	return out


## Two-bone IK on the chain a -> b -> c (thigh, shin, foot or upper arm, forearm, hand): puts the
## effector (c's joint, or `eff`, a point in b's local space such as the fist on the forearm) at
## `target`, bending b towards `pole`. `end_basis` (a global basis) orients c; null keeps c's pose
## relative to b.
func _ik(L: Array, a: int, b: int, c: int, target: Vector3, pole: Vector3, end_basis: Variant = null, eff: Variant = null) -> Array:
	var G := _fk(L)
	var ga: Transform3D = G[a]
	var gb: Transform3D = G[b]
	var gc: Transform3D = G[c]
	var A := ga.origin
	var B := gb.origin
	var C: Vector3 = gc.origin if eff == null else gb * (eff as Vector3)
	var l1 := A.distance_to(B)
	var l2 := B.distance_to(C)
	var to := target - A
	var d := clampf(to.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
	var dir := to.normalized() if to.length() > 1e-6 else (C - A).normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var sa := sqrt(maxf(0.0, 1.0 - ca * ca))
	var pv := pole - A
	pv -= dir * pv.dot(dir)
	if pv.length() < 1e-6:
		pv = (B - A) - dir * (B - A).dot(dir)
	pv = pv.normalized()
	var B2 := A + dir * (l1 * ca) + pv * (l1 * sa)
	var C2 := A + dir * d
	var q1 := Quaternion((B - A).normalized(), (B2 - A).normalized())
	ga.basis = Basis(q1) * ga.basis
	var gb2 := Transform3D(Basis(q1) * gb.basis, B2)
	var q2 := Quaternion((q1 * (C - B)).normalized(), (C2 - B2).normalized())
	gb2.basis = Basis(q2) * gb2.basis
	var gc2: Transform3D = gb2 * (gb.affine_inverse() * gc)
	if end_basis != null:
		gc2.basis = end_basis
	var out := L.duplicate()
	var pa := _parent[a]
	out[a] = ga if pa < 0 else (G[pa] as Transform3D).affine_inverse() * ga
	out[b] = ga.affine_inverse() * gb2
	out[c] = gb2.affine_inverse() * gc2
	return out


func _leg_len(side: String) -> float:
	return (_rest[_bone[side + "Leg"]] as Transform3D).origin.length() + (_rest[_bone[side + "Foot"]] as Transform3D).origin.length()


## Retargeted clips assume equal legs. Re-solve the longer leg so it reaches as far, relative to
## its length, as the clip asks, keeping the knee plane and the foot's orientation.
func _fix_legs(L: Array) -> Array:
	var ll := _leg_len("Left")
	var lr := _leg_len("Right")
	if absf(ll - lr) < 0.03 * maxf(ll, lr):
		return L
	var side := "Right" if lr > ll else "Left"
	var ratio := minf(ll, lr) / maxf(ll, lr)
	var a: int = _bone[side + "UpLeg"]
	var b: int = _bone[side + "Leg"]
	var c: int = _bone[side + "Foot"]
	var G := _fk(L)
	var A: Vector3 = (G[a] as Transform3D).origin
	var C: Vector3 = (G[c] as Transform3D).origin
	return _ik(L, a, b, c, A + (C - A) * ratio, (G[b] as Transform3D).origin, (G[c] as Transform3D).basis)


func _blend(A: Array, B: Array, t: float) -> Array:
	var out := A.duplicate()
	for b in _nb:
		var x: Transform3D = A[b]
		var y: Transform3D = B[b]
		out[b] = Transform3D(Basis(x.basis.get_rotation_quaternion().slerp(y.basis.get_rotation_quaternion(), t)), x.origin.lerp(y.origin, t))
	return out


func _anim_locals(a: Animation, t: float, pin_root: bool) -> Array:
	var L := _rest.duplicate()
	for tr in a.get_track_count():
		var path := str(a.track_get_path(tr))
		var bn := path.get_slice(":", 1) if path.contains(":") else path.get_file()
		var b := _sk.find_bone(bn)
		if b < 0:
			b = int(_bone.get(_short(bn), -1))
		if b < 0:
			continue
		var x: Transform3D = L[b]
		match a.track_get_type(tr):
			Animation.TYPE_ROTATION_3D:
				x.basis = Basis(a.rotation_track_interpolate(tr, t))
			Animation.TYPE_POSITION_3D:
				x.origin = a.position_track_interpolate(tr, t)
		L[b] = x
	if pin_root:
		var h: int = _bone["Hips"]
		var x: Transform3D = L[h]
		var r: Transform3D = _rest[h]
		x.origin = Vector3(r.origin.x, x.origin.y, r.origin.z)
		L[h] = x
	return L


## Loop period of a clip: Meshy/Mixamo loops repeat the first key at the end; drop it. Some
## tracks (this export's Hips) carry one extra key, so the shortest repeating track wins.
static func _loop_period(a: Animation) -> float:
	var period := INF
	for tr in a.get_track_count():
		if a.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var k := a.track_get_key_count(tr)
		if k < 3:
			continue
		if (a.track_get_key_value(tr, 0) as Quaternion).angle_to(a.track_get_key_value(tr, k - 1)) < 0.01:
			period = minf(period, a.track_get_key_time(tr, k - 1))
	return period if period < INF and period > 0.0 else a.length


func _to_bake(p: Vector3) -> Vector3:
	return (p - _origin) * _scale


func _skin(G: Array) -> Array:
	var M := []
	M.resize(_bind.size() + 1)
	for i in _bind.size():
		M[i] = (G[_bind_bone[i]] as Transform3D) * (_bind[i] as Transform3D)
	M[_bind.size()] = _prop_matrix(G)
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	P.resize(_vcount)
	N.resize(_vcount)
	for v in _vcount:
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		var o := v * _wpv
		for k in _wpv:
			var w := _vw[o + k]
			if w <= 0.0:
				continue
			var m: Transform3D = M[_vbone[o + k]]
			p += (m * _pos[v]) * w
			n += (m.basis * _nrm[v]) * w
		P[v] = _to_bake(p)
		N[v] = n.normalized()
	return [P, N]


## The held prop (spear) as a rigid pseudo-bone: its grip rides on the bone holding it; it turns
## by `_prop_aim` (a character-space rotation from the rest pose, set by procedural clips) or by
## `_prop_follow` of the holding bone's rotation (1 = rigid in the fist, less = stays upright).
func _prop_matrix(G: Array) -> Transform3D:
	if _prop_bone < 0:
		return Transform3D.IDENTITY
	var gf: Transform3D = G[_prop_bone]
	var gr: Transform3D = _rest_glob[_prop_bone]
	var grip := gf * (gr.affine_inverse() * _prop_grip)
	var r: Basis
	if _prop_aim != null:
		r = _prop_aim
	else:
		var d := (gf.basis * gr.basis.inverse()).get_rotation_quaternion()
		r = Basis(Quaternion.IDENTITY.slerp(d, _prop_follow))
	var m := Transform3D(r, grip) * Transform3D(Basis.IDENTITY, -_prop_grip)
	# Never plant the butt in the floor: let the shaft slide up through the fist instead.
	var up := (r * _prop_axis).y
	var butt := m * _prop_butt
	var floor_y := _origin.y + 0.02 / maxf(_scale, 1e-4) * 0.441
	if up > 0.25 and butt.y < floor_y:
		m.origin += r * _prop_axis * ((floor_y - butt.y) / up)
	return m


## Meshy's auto-rig spreads held props over unrelated bones (this knight's spear over the head and
## the right toes, the shield over the left thigh). Re-bind them rigidly:
##   spear: the longest thin mesh island plus the small islands strung along its axis (head,
##          collar) -> the prop pseudo-bone, pivoting at the grip, carried by the bone that owns
##          the fist around the shaft;
##   shield-like islands: small islands mixing one side's arm and leg weights, away from the legs
##          -> that side's forearm.
func _fix_props(model_h: float) -> void:
	var islands := _islands()
	var hips_x: float = (_rest_glob[_bone["Hips"]] as Transform3D).origin.x
	# Spear shaft.
	var shaft: PackedInt32Array
	var best := 0.0
	for isl in islands:
		var bb := AABB(_pos[isl[0]], Vector3.ZERO)
		for v in isl:
			bb = bb.expand(_pos[v])
		var e := [bb.size.x, bb.size.y, bb.size.z]
		e.sort()
		if e[2] > 0.4 * model_h and e[2] > 3.5 * e[1] and e[2] > best:
			best = e[2]
			shaft = isl
	if not shaft.is_empty():
		var ys := []
		for v in shaft:
			ys.append(_pos[v])
		ys.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.y < q.y)
		var m := maxi(1, ys.size() / 7)
		var lo := Vector3.ZERO
		var hi := Vector3.ZERO
		for i in m:
			lo += ys[i]
			hi += ys[ys.size() - 1 - i]
		lo /= m
		hi /= m
		var axis := (hi - lo).normalized()
		var span := lo.distance_to(hi)
		var prop := {}
		for v in shaft:
			prop[v] = true
		var r := 0.06 * model_h
		for isl in islands:
			if isl.size() > 150 or prop.has(isl[0]):
				continue
			var inside := true
			var c := Vector3.ZERO
			for v in isl:
				var d := _pos[v] - lo
				if (d - axis * d.dot(axis)).length() > r:
					inside = false
					break
				c += _pos[v]
			c /= isl.size()
			var t := (c - lo).dot(axis)
			if inside and (t > 0.75 * span or t < 0.05 * span):
				for v in isl:
					prop[v] = true
		# The fist: other vertices hugging the shaft in its middle part; their main bone holds it.
		var votes := {}
		var grip := Vector3.ZERO
		var nh := 0
		for v in _vcount:
			if prop.has(v):
				continue
			var d := _pos[v] - lo
			var t := d.dot(axis)
			if t < 0.1 * span or t > 0.8 * span or (d - axis * t).length() > 0.05 * model_h:
				continue
			var o := v * _wpv
			var dom := 0
			for k in _wpv:
				if _vw[o + k] > _vw[o + dom]:
					dom = k
			var b := _bind_bone[_vbone[o + dom]]
			votes[b] = int(votes.get(b, 0)) + 1
			grip += lo + axis * t
			nh += 1
		if nh > 0:
			var holder := -1
			for b in votes:
				if holder < 0 or votes[b] > votes[holder]:
					holder = b
			_prop_bone = holder
			_prop_grip = grip / nh
			_prop_axis = axis
			_prop_butt = lo
			for v in prop:
				var o: int = v * _wpv
				for k in _wpv:
					_vbone[o + k] = _bind.size() if k == 0 else 0
					_vw[o + k] = 1.0 if k == 0 else 0.0
			print("  prop: %d spear vertices re-bound to a pseudo-bone held by %s at %s, axis %s, %.3f long" % [
				prop.size(), _sk.get_bone_name(holder), _prop_grip, axis, span])
	# Shields and other props strapped to an arm but weighted to a leg.
	for isl in islands:
		if isl.size() > 150 or _vbone[isl[0] * _wpv] == _bind.size():
			continue
		for side in ["Left", "Right"]:
			var arm := 0.0
			var leg := 0.0
			var tot := 0.0
			var c := Vector3.ZERO
			for v in isl:
				c += _pos[v]
				for k in _wpv:
					var w := _vw[v * _wpv + k]
					var bn := _short(_sk.get_bone_name(_bind_bone[_vbone[v * _wpv + k]]))
					tot += w
					if bn.begins_with(side) and (bn.contains("Arm") or bn.contains("Hand")):
						arm += w
					elif bn.begins_with(side) and (bn.contains("Leg") or bn.contains("Foot") or bn.contains("Toe")):
						leg += w
			c /= isl.size()
			if arm / tot >= 0.15 and leg / tot >= 0.3 and absf(c.x - hips_x) > 0.15 * model_h:
				var bind := _bind_bone.find(_bone[side + "ForeArm"])
				if bind < 0:
					continue
				for v in isl:
					for k in _wpv:
						_vbone[v * _wpv + k] = bind if k == 0 else 0
						_vw[v * _wpv + k] = 1.0 if k == 0 else 0.0
				print("  prop: %d-vertex island at %s re-bound from %s leg+arm to %sForeArm" % [isl.size(), c, side, side])


## Connected mesh islands (vertices welded by position across UV seams).
func _islands() -> Array:
	var par := PackedInt32Array()
	par.resize(_vcount)
	for i in _vcount:
		par[i] = i
	var root := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	var seen := {}
	for i in _vcount:
		var key := Vector3i((_pos[i] * 20000.0).round())
		if seen.has(key):
			var a: int = root.call(i)
			var b: int = root.call(seen[key])
			if a != b:
				par[a] = b
		else:
			seen[key] = i
	for t in range(0, _idx.size(), 3):
		for e in 2:
			var a: int = root.call(_idx[t + e])
			var b: int = root.call(_idx[t + e + 1])
			if a != b:
				par[a] = b
	var groups := {}
	for i in _vcount:
		var r: int = root.call(i)
		if not groups.has(r):
			groups[r] = PackedInt32Array()
		groups[r].append(i)
	return groups.values()


# ----------------------------------------------------------------------------------- clip bake

func _clip_locals(c: Dictionary, t: float) -> Array:
	var src := str(c["src"])
	_prop_follow = float(c.get("prop_follow", 1.0))
	_prop_aim = null
	var L: Array
	if src.begins_with("anim:"):
		L = _anim_locals(_anims[src.substr(5)], t, bool(c.get("pin_root", false)))
		if c.get("leg_fix", false):
			L = _fix_legs(L)
	else:
		L = call("_proc_" + src.substr(5), t / float(c["length"]))
	return L


func _bake_clip(c: Dictionary) -> Dictionary:
	var src := str(c["src"])
	if src.begins_with("anim:") and not _anims.has(src.substr(5)):
		push_error("bake_vat: clip %s needs animation '%s' (have: %s). Pass --anims=..." % [c["name"], src.substr(5), ", ".join(_anims.keys())])
		return {}
	if src.begins_with("proc:") and not has_method("_proc_" + src.substr(5)):
		push_error("bake_vat: no procedural clip " + src)
		return {}
	var start := float(c.get("start", 0.0))
	var length := 0.0
	if str(c.get("length", "auto")) == "auto":
		length = _loop_period(_anims[src.substr(5)]) - start
	else:
		length = float(c["length"])
	var n := int(c["frames"])
	var blend_w := float(c.get("loop_blend", 0.0))
	var L0 := _clip_locals(c, start)
	var frames := []
	var normals := []
	var yaw := PackedFloat32Array()
	var ankles := []
	var hips_rest: Basis = (_fk(_rest)[_bone["Hips"]] as Transform3D).basis
	var prev_yaw := 0.0
	for f in n:
		var tl := length * f / n
		var L := L0 if f == 0 else _clip_locals(c, start + tl)
		if blend_w > 0.0 and tl > length - blend_w:
			L = _blend(L, L0, smoothstep(0.0, 1.0, (tl - (length - blend_w)) / blend_w))
		var G := _fk(L)
		var pn := _skin(G)
		frames.append(pn[0])
		normals.append(pn[1])
		ankles.append([_to_bake((G[_bone["LeftFoot"]] as Transform3D).origin), _to_bake((G[_bone["RightFoot"]] as Transform3D).origin)])
		var y := 0.0
		if c.get("despin", false):
			var q := ((G[_bone["Hips"]] as Transform3D).basis * hips_rest.inverse()).get_rotation_quaternion()
			y = 2.0 * atan2(q.y, q.w)
			y = prev_yaw + wrapf(y - prev_yaw, -PI, PI)
			prev_yaw = y
		yaw.append(y)
	# Ground: one lift for the whole clip from the feet, then (for acrobatics) per-frame lifts so
	# no frame dips below the floor, plus an optional airborne arc.
	var mode := str(c.get("ground", "clip"))
	var lift := 0.0
	if mode != "none":
		var lowest := INF
		var check := [0] if mode == "frame" else range(n)
		for f in check:
			var pf: PackedVector3Array = frames[f]
			for v in _foot:
				lowest = minf(lowest, pf[v].y)
		lift = -lowest if lowest < INF else 0.0
	var jump: Array = c.get("jump", [])
	for f in n:
		var pf: PackedVector3Array = frames[f]
		var extra := lift
		if mode == "frame":
			var lowest := INF
			for p in pf:
				lowest = minf(lowest, p.y)
			extra += maxf(0.0, -(lowest + lift))
		if jump.size() == 3:
			var u := clampf((start + length * f / n - float(jump[0])) / (float(jump[1]) - float(jump[0])), 0.0, 1.0)
			extra += float(jump[2]) * _scale * sin(PI * u)
		if extra != 0.0:
			for v in _vcount:
				pf[v].y += extra
			frames[f] = pf
			ankles[f][0].y += extra
			ankles[f][1].y += extra
	# Natural ground speed: how fast a planted foot slides back (units/s at playback speed 1).
	var speed := 0.0
	var samples := 0
	for side in 2:
		var lo := INF
		for f in n:
			lo = minf(lo, (ankles[f][side] as Vector3).y)
		for f in n:
			var g := (f + 1) % n
			if not c.get("loop", true) and g == 0:
				continue
			var a0: Vector3 = ankles[f][side]
			var a1: Vector3 = ankles[g][side]
			if a0.y < lo + 0.025 * _scale and a1.y < lo + 0.025 * _scale:
				speed += absf(a1.z - a0.z) * n / length
				samples += 1
	speed = speed / samples if samples > 0 else 0.0
	if not src.begins_with("anim:") or not (c["name"] in ["run", "walk"]):
		speed = 0.0
	if _args.has("verify") and _verify_clip.is_empty() and src.begins_with("anim:"):
		_verify_clip = c
		_verify_locals = _clip_locals(c, start + length * 3 / n)
		var pn3 := _skin(_fk(_verify_locals))
		_verify_p = pn3[0]
	return {"p": frames, "n": normals, "yaw": yaw, "length": length, "lift": lift, "ground_speed": speed}


# ------------------------------------------------------------------------------ verification

## Poses the real Skeleton3D like a baked frame and compares Godot's own skinning with ours.
func _verify_step() -> bool:
	if _verify_clip.is_empty():
		print("verify: no sampled clip to check")
		return false
	if _verify_state == 1:
		for b in _nb:
			var x: Transform3D = _verify_locals[b]
			_sk.set_bone_pose_position(b, x.origin)
			_sk.set_bone_pose_rotation(b, x.basis.get_rotation_quaternion())
			_sk.set_bone_pose_scale(b, Vector3.ONE)
		_sk.force_update_all_bone_transforms()
		_verify_state = 2
		return true
	var baked := _mi.bake_mesh_from_current_skeleton_pose()
	if baked == null:
		print("verify: bake_mesh_from_current_skeleton_pose() unavailable")
		return false
	var v: PackedVector3Array = baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	var mean := 0.0
	for i in mini(v.size(), _verify_p.size()):
		var e := _to_bake(v[i]).distance_to(_verify_p[i])
		worst = maxf(worst, e)
		mean += e
	mean /= maxf(1.0, v.size())
	print("verify (%s frame 3): Godot skinning vs CPU bake: max %.6f, mean %.6f units (unit height %.2f)" % [
		_verify_clip["name"], worst, mean, float(_args.get("height", "0.75"))])
	_exit = 0 if worst < 0.002 else 1
	return false


# -------------------------------------------------------------------------- procedural clips

static func _deg(x: float, y: float, z: float) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))


static func _ease(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))


func _rest_global(bone_name: String) -> Transform3D:
	return _rest_glob[_bone[bone_name]]


## Keeps both feet where they stand in the rest pose (plus offsets) after the hips moved.
func _plant_feet(L: Array, left_off := Vector3.ZERO, right_off := Vector3.ZERO) -> Array:
	for side in ["Left", "Right"]:
		var foot := _rest_global(side + "Foot")
		var off: Vector3 = left_off if side == "Left" else right_off
		var G := _fk(L)
		var knee: Vector3 = (G[_bone[side + "Leg"]] as Transform3D).origin
		L = _ik(L, _bone[side + "UpLeg"], _bone[side + "Leg"], _bone[side + "Foot"], foot.origin + off, knee + Vector3(0, 0, 0.3), foot.basis)
	return L


## Subtle breathing on the rest pose (spear upright, shield on the left arm).
func _proc_idle(u: float) -> Array:
	var s := sin(TAU * u)
	var c := cos(TAU * u)
	var rot := {
		_bone["Spine1"]: _deg(-1.2 * s, 0.8 * c, 0.0),
		_bone["Spine2"]: _deg(-1.6 * s, 0.6 * c, 0.6 * c),
		_bone["Head"]: _deg(2.0 * s, -1.0 * c, 0.0),
		_bone["LeftArm"]: _deg(0.0, 0.0, -2.0 * s),
		_bone["RightArm"]: _deg(1.5 * s, 0.0, 1.5 * s),
	}
	var L := _pose(_rest, rot, {_bone["Hips"]: Vector3(0.006 * c, -0.012 * (0.5 + 0.5 * s), 0.0)})
	return _plant_feet(L)


## Thrust curve: 0 = spear cocked back, 1 = fully extended. Wind up, stab fast, hold, recover.
static func _thrust(u: float) -> float:
	if u < 0.42:
		return lerpf(0.3, 0.0, _ease(u / 0.42))
	if u < 0.54:
		return 1.0 - pow(1.0 - (u - 0.42) / 0.12, 3.0)
	if u < 0.66:
		return lerpf(1.0, 0.93, (u - 0.54) / 0.12)
	return lerpf(0.93, 0.3, _ease((u - 0.66) / 0.34))


## Spear thrust: the shoulders wind away and the fist pulls back beside the hip, then the knight
## lunges and stabs forward with the spear levelled at the enemy, shield up on the left arm.
func _proc_attack(u: float) -> Array:
	var k := _thrust(u)
	var twist := lerpf(-24.0, 26.0, k)
	var rot := {
		_bone["Hips"]: _deg(lerpf(2.0, 8.0, k), twist * 0.45, 0.0),
		_bone["Spine1"]: _deg(lerpf(-2.0, 6.0, k), twist * 0.3, 0.0),
		_bone["Spine2"]: _deg(lerpf(-2.0, 6.0, k), twist * 0.25, 0.0),
		_bone["Head"]: _deg(lerpf(0.0, -8.0, k), -twist * 0.8, 0.0),
		_bone["LeftArm"]: _deg(lerpf(30.0, 18.0, k), 0.0, lerpf(-10.0, -16.0, k)),
		_bone["LeftForeArm"]: _deg(lerpf(30.0, 15.0, k), 0.0, 0.0),
	}
	var hips_move := Vector3(lerpf(0.01, -0.02, k), lerpf(-0.035, -0.07, k), lerpf(-0.03, 0.07, k))
	var L := _pose(_rest, rot, {_bone["Hips"]: hips_move})
	L = _plant_feet(L, Vector3(0.0, 0.0, 0.09), Vector3(0.0, 0.0, -0.06))
	if _prop_bone < 0:
		return L
	# Fist from beside the hip to a long forward reach; the spear levelled at the enemy.
	var grip := Vector3(-0.33, 0.56, -0.02).lerp(Vector3(-0.15, 0.61, 0.56), k)
	var aim := Vector3(0.06, lerpf(0.02, -0.14, k), 1.0).normalized()
	_prop_aim = Basis(Quaternion(_prop_axis, aim))
	var fore: int = _bone["RightForeArm"]
	var eff: Vector3 = (_rest_glob[fore] as Transform3D).affine_inverse() * _prop_grip
	var G := _fk(L)
	var elbow: Vector3 = (G[fore] as Transform3D).origin
	return _ik(L, _bone["RightArm"], fore, _bone["RightHand"], grip, elbow + Vector3(-0.4, -0.2, -0.3), null, eff)
