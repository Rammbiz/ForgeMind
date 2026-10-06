class_name MachineThumbs
extends Node
## Machine card renders (arsenal_design.md §7.1: card layer 2 "machine render"). Renders each
## live machine (and its Ascension look) once in a transparent SubViewport, 3/4 front view,
## keeps the textures for the session and caches PNGs in user://thumbs/ for later launches.
## Headless runs get null (cards fall back to the vector icon).
##
##   var tex := MachineThumbs.get_thumb(self, "ballista", false)   # null until rendered
##   MachineThumbs.service(get_tree()).rendered.connect(func(key, tex): ...)

signal rendered(key: String, tex: Texture2D)

const PX := 256
## Bump when the procedural models change their look (old PNGs are ignored).
const VERSION := "m1e"

static var _cache := {}
var _queue: Array[String] = []
var _busy := false
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


## The shared renderer node (created on first use under the scene root).
static func service(tree: SceneTree) -> MachineThumbs:
	var n := tree.root.get_node_or_null("MachineThumbs") as MachineThumbs
	if n == null:
		n = MachineThumbs.new()
		n.name = "MachineThumbs"
		tree.root.add_child.call_deferred(n)
	return n


static func key_of(id: String, ascended: bool) -> String:
	return "%s_%s" % [id, "asc" if ascended else "base"]


## The cached render of `id` (null while it renders; requests it).
static func get_thumb(host: Node, id: String, ascended := false) -> Texture2D:
	var key := key_of(id, ascended)
	if _cache.has(key):
		return _cache[key]
	if not WeaponModels.KINDS.has(id) or DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return null
	var disk := _disk_path(key)
	if FileAccess.file_exists(disk):
		var img := Image.load_from_file(disk)
		if img and not img.is_empty():
			img.generate_mipmaps()
			_cache[key] = ImageTexture.create_from_image(img)
			return _cache[key]
	service(host.get_tree()).request(key)
	return null


static func _disk_path(key: String) -> String:
	return "user://thumbs/%s_%s.png" % [VERSION, key]


func request(key: String) -> void:
	if _cache.has(key) or _queue.has(key):
		return
	_queue.append(key)
	if is_inside_tree():
		_pump()
	else:
		ready.connect(_pump, CONNECT_ONE_SHOT)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 1.0)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.95, 0.88)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_color = Color(0.6, 0.8, 1.0)
	rim.light_energy = 0.9
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)


func _pump() -> void:
	if _busy or _queue.is_empty() or not is_inside_tree():
		return
	_busy = true
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		var parts := key.split("_")
		var asc := key.ends_with("_asc")
		var id := key.trim_suffix("_asc").trim_suffix("_base")
		var tex := await _render(id, asc)
		if tex:
			_cache[key] = tex
			rendered.emit(key, tex)
		if parts.is_empty():
			break
	_busy = false


func _render(id: String, asc: bool) -> Texture2D:
	for c in _holder.get_children():
		c.queue_free()
	var m := WeaponModels.machine(id, {"rank": 1, "ascended": asc, "crew": true})
	_holder.add_child(m)
	HubShowcase.hide_rank_marks(m)
	m.rotation.y = PI - 0.62
	WeaponModels.animate(m, 0.3, 0.0, 0.0)
	var box := WeaponModels._visual_aabb(m, m.transform)
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var dir := Vector3(0.0, 0.42, 1.0).normalized()
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 0.92
	_cam.look_at_from_position(center + dir * dist, center + Vector3(0, -box.size.y * 0.04, 0))
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	m.queue_free()
	if img == null or img.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute("user://thumbs")
	img.save_png(_disk_path(key_of(id, asc)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
