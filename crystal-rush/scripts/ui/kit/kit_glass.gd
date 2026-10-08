class_name KitGlass
## UI v3.1 "porcelain glass" (binding spec ui_v3_spec.md §4): the frosted-world backdrop shared by
## the glass surfaces. The Hub owns one WorldSnap (a 1/10-res still of the Home 3D, blurred once
## per refresh). Glass Controls (the nav strip, modals, sheets) sample it at SCREEN_UV through
## shared materials (shaders/ui/ui_frost.gdshader): one texture tap per pixel, no screen copy, no
## render-pass break, and it keeps working after the hub turns 3D off.
## Without a snapshot (run HUD, menus outside the hub, headless) frost() returns null and the
## surfaces fall back to flat translucent cream (the painted look, no shader).
##   KitGlass.attach_world(hub, stage.camera(), stage, stage.world)  # hub _ready
##   KitGlass.refresh_world()      # leaving / arriving at Play (3D still on), biome change, Deck swap
##   panel.material = KitGlass.frost(UITokens.FROST_RIM_TINT)          # may be null: skip it
##   strip.material = KitGlass.frost_nav()                             # vertex alpha = tint ramp
##   KitGlass.when_ready(node, func(): ...)                            # still rendered (cross-fade)
##   KitGlass.world_alpha()        # 0..1 cross-fade of the world into the frost (first still)
##   KitGlass.set_page_tint(col)   # §4.6: frost behind a modal leans toward the page colour
## No flash on the first frame (§4.1): materials handed out before the first still is rendered
## draw a flat cream (frost_contrast 0, so the empty texture never shows) and the world
## cross-fades in over 180 ms once it is ready (snap with Reduce Motion).
## The still also refreshes on NOTIFICATION_APPLICATION_RESUMED (Android GL context loss) and on
## window resize.

const FROST_SHADER := preload("res://shaders/ui/ui_frost.gdshader")
## Geometry on this render layer is left out of the snapshot (the main camera still sees it).
const SNAP_HIDDEN_LAYER := 1 << 19
const FADE_TIME := 0.18
## Frost parameters (shader defaults, §4.2) and the flat "not ready" values they fade from.
const FROST := {"frost_contrast": 0.55, "frost_mid": 0.80}
const FROST_NAV := {"frost_contrast": UITokens.NAV_FROST_CONTRAST, "frost_mid": 0.80}
const FLAT := {"frost_contrast": 0.0, "frost_mid": 0.93}

static var _snap: WorldSnap
static var _mats := {}
static var _nav_mat: ShaderMaterial
static var _fade := 0.0
static var _page_tint := Color.WHITE


## Creates the world snapshot under `host` (the Hub) for camera `cam`, and renders it once.
## `hide_root`: its geometry (the hero, the Deck machines, the dais...) stays out of the still, so
## no blurred figure ghosts under the glass; `keep` (a child of it, e.g. the world) stays in.
static func attach_world(host: Node, cam: Camera3D, hide_root: Node = null, keep: Node = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _snap and is_instance_valid(_snap):
		_snap.queue_free()
	_fade = 0.0
	_snap = WorldSnap.new()
	host.add_child(_snap)
	_snap.hide_root = hide_root
	_snap.keep = keep
	_snap.setup(cam)
	for m: ShaderMaterial in _all_mats():
		m.set_shader_parameter("snap_tex", _snap.texture())
	_apply_fade()
	_snap.refresh()


## Re-renders the still (call while the Home 3D is still on: leaving / arriving at Play, a biome
## or world change, a hero / machine swap in the Deck).
static func refresh_world() -> void:
	if attached():
		_snap.refresh()


## A snapshot exists (it may not be rendered yet).
static func attached() -> bool:
	return _snap != null and is_instance_valid(_snap)


## The still has been rendered at least once.
static func has_world() -> bool:
	return attached() and _snap.ready_once


## The blurred world texture, or null (not attached or not rendered yet).
static func world_texture() -> Texture2D:
	return _snap.texture() if has_world() else null


## 0..1: how far the first still has cross-faded in (multiply a world backdrop's alpha by it).
static func world_alpha() -> float:
	return (1.0 - pow(1.0 - _fade, 3.0)) if has_world() else 0.0


## Calls `cb` once the still is rendered (at once if it already is); bound to `node`'s life.
static func when_ready(node: Node, cb: Callable) -> void:
	if has_world():
		cb.call()
		return
	if not attached():
		return
	_snap.still_ready.connect(func():
		if is_instance_valid(node):
			cb.call(), CONNECT_ONE_SHOT)


## Emits `cb` every time the still changes (refresh done, or the cross-fade step) while `node` lives.
static func on_change(node: Node, cb: Callable) -> void:
	if not attached():
		return
	var f := func():
		if is_instance_valid(node):
			cb.call()
	_snap.changed.connect(f)
	node.tree_exiting.connect(func():
		if attached() and _snap.changed.is_connected(f):
			_snap.changed.disconnect(f), CONNECT_ONE_SHOT)


## Shared frost material (`tint` = share of the painted cream over the world: 0.62 rims, see
## UITokens.FROST_RIM_TINT), or null when there is no snapshot (flat fallback).
static func frost(tint := UITokens.FROST_RIM_TINT) -> ShaderMaterial:
	if not attached():
		return null
	var key := "%.2f" % tint
	if _mats.has(key):
		return _mats[key]
	var m := _make()
	m.set_shader_parameter("tint", tint)
	# v3.1 fix: modal / sheet frost keeps a faint sky hue and is bright (glass, not a grey rim).
	m.set_shader_parameter("frost_desat", UITokens.FROST_DESAT)
	m.set_shader_parameter("frost_lift", UITokens.FROST_LIFT)
	_mats[key] = m
	return m


## The nav strip's frost: vertex alpha carries the tint ramp (§6.3), or null (flat fallback).
static func frost_nav() -> ShaderMaterial:
	if not attached():
		return null
	if _nav_mat == null:
		_nav_mat = ShaderMaterial.new()
		_nav_mat.shader = FROST_SHADER
		_nav_mat.set_meta("frost", FROST_NAV)
		_nav_mat.set_shader_parameter("snap_tex", _snap.texture())
		_fade_mat(_nav_mat, _fade if has_world() else 0.0)
		_nav_mat.set_shader_parameter("alpha_is_tint", true)
		# v3.1 fix: more of the world (contrast 0.75, desat 0.30) so the floor's gold ring and the
		# map lines visibly ghost through the strip's upper third on Play.
		_nav_mat.set_shader_parameter("frost_desat", UITokens.NAV_FROST_DESAT)
		# The nav keeps a white page tint (it sits on Play's sky as well as on the cream tabs).
		_nav_mat.set_shader_parameter("page_tint", Color.WHITE)
	return _nav_mat


## §4.6 frost coherence: the frost behind a modal leans toward the page colour (`col` mixed
## `k` toward white; Color.WHITE on Play). The nav keeps white.
static func set_page_tint(col: Color, k := 0.75) -> void:
	# Hue only: scale the colour so its brightest channel is 1 (amethyst x warm cream used to
	# darken the frost to a dirty neutral grey), then lean it toward white by `k`.
	var mx := maxf(col.r, maxf(col.g, col.b))
	var hue := Color(col.r / mx, col.g / mx, col.b / mx, 1.0) if mx > 0.001 else Color.WHITE
	_page_tint = Color.WHITE if col == Color.WHITE else hue.lerp(Color.WHITE, k)
	_page_tint.a = 1.0
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("page_tint", _page_tint)


static func _make() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FROST_SHADER
	m.set_shader_parameter("snap_tex", _snap.texture())
	m.set_shader_parameter("page_tint", _page_tint)
	_fade_mat(m, _fade if has_world() else 0.0)
	return m


static func _all_mats() -> Array:
	var out: Array = _mats.values()
	if _nav_mat:
		out.append(_nav_mat)
	return out


static func _fade_mat(m: ShaderMaterial, k: float) -> void:
	var target: Dictionary = m.get_meta("frost", FROST)
	for p: String in target.keys():
		m.set_shader_parameter(p, lerpf(float(FLAT[p]), float(target[p]), k))


static func _apply_fade() -> void:
	var k := _fade if has_world() else 0.0
	for m: ShaderMaterial in _all_mats():
		_fade_mat(m, k)


## The world snapshot (tech.md B): a SubViewport sharing the Home World3D renders a 1/10-res still
## through a copy of the hub camera (UPDATE_ONCE), then a second SubViewport blurs it once
## (7x7 gaussian). Both stay UPDATE_DISABLED between refreshes, so the texture persists with 3D off.
class WorldSnap extends Node:
	const DIV := 10.0
	const SPREAD := 1.6
	signal still_ready
	signal changed
	var ready_once := false
	var hide_root: Node
	var keep: Node
	var _snap: SubViewport
	var _blur: SubViewport
	var _cam: Camera3D
	var _rect: ColorRect
	var _src_cam: Camera3D
	var _busy := false
	var _again := false

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
		m.set_shader_parameter("spread", SPREAD)
		_rect.material = m
		_blur.add_child(_rect)
		add_child(_blur)
		_resize()
		get_viewport().size_changed.connect(_on_resize)
		set_process(false)

	func texture() -> Texture2D:
		return _blur.get_texture()

	func _notification(what: int) -> void:
		# Android: the GL context can be lost while paused; re-shoot the still on resume.
		if what == NOTIFICATION_APPLICATION_RESUMED and _src_cam != null:
			refresh()

	func _on_resize() -> void:
		_resize()
		refresh()

	## Re-renders the still: the 3D pass this frame, the blur pass the next. The old still stays
	## on screen until the new one is blurred (no flash); the first one cross-fades in.
	func refresh() -> void:
		if _src_cam == null or not is_instance_valid(_src_cam):
			return
		if _busy:
			_again = true
			return
		_busy = true
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
		_snap.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(_blur):
			return
		_blur.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(self):
			return
		_busy = false
		var first := not ready_once
		ready_once = true
		if first:
			if UITokens.reduce_motion():
				KitGlass._fade = 1.0
			else:
				set_process(true)
			KitGlass._apply_fade()
			still_ready.emit()
		changed.emit()
		if _again:
			_again = false
			refresh()

	func _process(delta: float) -> void:
		KitGlass._fade = minf(1.0, KitGlass._fade + delta / FADE_TIME)
		# Cubic ease-out on the way in.
		var k := 1.0 - pow(1.0 - KitGlass._fade, 3.0)
		for m: ShaderMaterial in KitGlass._all_mats():
			KitGlass._fade_mat(m, k)
		changed.emit()
		if KitGlass._fade >= 1.0:
			set_process(false)

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
