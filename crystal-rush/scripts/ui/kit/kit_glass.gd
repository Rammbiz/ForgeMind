class_name KitGlass
## UI v3 "porcelain glass" (direction A): the frosted-world backdrop shared by the glass surfaces.
## The Hub owns one WorldSnap (a 1/8-res still of the Home 3D, blurred once per refresh). Glass
## Controls (the nav strip, modals, the backdrop of the tabs where 3D is off) sample it at
## SCREEN_UV through ONE shared material (shaders/ui/ui_frost.gdshader): one texture tap per pixel,
## no screen copy, no render-pass break, and it keeps working after the hub turns 3D off.
## Without a snapshot (run HUD, menus outside the hub, headless) frost() returns null and the
## surfaces fall back to flat translucent cream (the painted look, no shader).
##   KitGlass.attach_world(hub, stage.camera())   # hub _ready, after the stage exists
##   KitGlass.refresh_world()                      # when leaving Play (before 3D goes off)
##   panel.material = KitGlass.frost()             # may be null: then just skip it

const FROST_SHADER := preload("res://shaders/ui/ui_frost.gdshader")

static var _snap: WorldSnap
static var _mats := {}


## Geometry on this render layer is left out of the snapshot (the main camera still sees it).
const SNAP_HIDDEN_LAYER := 1 << 19


## Creates the world snapshot under `host` (the Hub) for camera `cam`, and renders it once.
## `hide_root`: its geometry (the hero, the Deck machines, the dais...) stays out of the still, so
## no blurred figure ghosts under the glass; `keep` (a child of it, e.g. the world) stays in.
static func attach_world(host: Node, cam: Camera3D, hide_root: Node = null, keep: Node = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _snap and is_instance_valid(_snap):
		_snap.queue_free()
	_snap = WorldSnap.new()
	host.add_child(_snap)
	_snap.hide_root = hide_root
	_snap.keep = keep
	_snap.setup(cam)
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("snap_tex", _snap.texture())
	_snap.refresh()


## Re-renders the still (call while the Home 3D is still on: when leaving Play).
static func refresh_world() -> void:
	if has_world():
		_snap.refresh()


static func has_world() -> bool:
	return _snap != null and is_instance_valid(_snap) and _snap.ready_once


## The blurred world texture, or null.
static func world_texture() -> Texture2D:
	return _snap.texture() if has_world() else null


## Shared frost material (`tint` = share of the painted cream; 0.68+ under body text), or null
## when there is no snapshot yet.
static func frost(tint := 0.7) -> ShaderMaterial:
	if not has_world():
		return null
	var key := "%.2f" % tint
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = FROST_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("snap_tex", _snap.texture())
	_mats[key] = m
	return m


## The world snapshot (tech.md B): a SubViewport sharing the Home World3D renders a 1/8-res still
## through a copy of the hub camera (UPDATE_ONCE), then a second SubViewport blurs it once
## (7x7 gaussian). Both stay UPDATE_DISABLED between refreshes, so the texture persists with 3D off.
class WorldSnap extends Node:
	const DIV := 8.0
	var ready_once := false
	var hide_root: Node
	var keep: Node
	var _snap: SubViewport
	var _blur: SubViewport
	var _cam: Camera3D
	var _rect: ColorRect
	var _src_cam: Camera3D

	func setup(src_cam: Camera3D) -> void:
		_src_cam = src_cam
		_snap = SubViewport.new()
		_snap.world_3d = get_viewport().world_3d
		_snap.msaa_3d = Viewport.MSAA_DISABLED
		_snap.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_cam = Camera3D.new()
		_cam.cull_mask = 0xFFFFF & ~SNAP_HIDDEN_LAYER
		_snap.add_child(_cam)
		add_child(_snap)
		_blur = SubViewport.new()
		_blur.disable_3d = true
		_blur.transparent_bg = false
		_blur.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_rect = ColorRect.new()
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/ui/snap_blur.gdshader")
		m.set_shader_parameter("src", _snap.get_texture())
		_rect.material = m
		_blur.add_child(_rect)
		add_child(_blur)
		_resize()
		get_viewport().size_changed.connect(_on_resize)

	func texture() -> Texture2D:
		return _blur.get_texture()

	func _on_resize() -> void:
		_resize()
		refresh()

	## Re-renders the still: the 3D pass this frame, the blur pass the next.
	func refresh() -> void:
		if _src_cam == null or not is_instance_valid(_src_cam):
			return
		_cam.global_transform = _src_cam.global_transform
		_cam.fov = _src_cam.fov
		_cam.keep_aspect = _src_cam.keep_aspect
		_cam.v_offset = _src_cam.v_offset
		_cam.h_offset = _src_cam.h_offset
		_cam.near = _src_cam.near
		_cam.far = _src_cam.far
		_cam.environment = _src_cam.environment
		_cam.attributes = _src_cam.attributes
		_cam.current = true
		if hide_root and is_instance_valid(hide_root):
			_hide(hide_root)
		ready_once = true
		_snap.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if is_instance_valid(_blur):
			_blur.render_target_update_mode = SubViewport.UPDATE_ONCE

	## Moves the figures (GeometryInstance3D under hide_root, outside `keep`) to the hidden layer.
	func _hide(n: Node) -> void:
		if n == keep:
			return
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).layers = SNAP_HIDDEN_LAYER
		for c in n.get_children():
			_hide(c)

	func _resize() -> void:
		var ws := Vector2(get_window().size)
		var s := Vector2i(maxi(16, int(ws.x / DIV)), maxi(16, int(ws.y / DIV)))
		_snap.size = s
		_blur.size = s
		_rect.size = Vector2(s)
		(_rect.material as ShaderMaterial).set_shader_parameter("texel", Vector2(1.0 / s.x, 1.0 / s.y))
