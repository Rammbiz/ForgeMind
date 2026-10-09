class_name HeroFrost
extends Node
## Screen-local frost for the full-screen Heroes / Summon screens (UI v3.1 spec §4.2-§4.3 applied
## to the painted screens). The hub's KitGlass still is the Home 3D world; over the Showcase, Team,
## Recut or Portal the glass must show THAT screen (Веста's armour, the Portal night), not a sky
## that is not there. A HeroFrost renders the screen's backdrop layers (its baked backdrop texture,
## the painted splash at its rect, flat colour bands) into a 1/10-res SubViewport ONCE, blurs it
## once (the kit's snap_blur 7x7), and hands out ui_frost materials that sample it at SCREEN_UV:
## the same shader, the same one tap per pixel, no screen copy, nothing per frame.
## Sheets and modals opened over the screen pick it up through HeroFrost.mat() / frost_sheet() /
## frost_panel(); with no HeroFrost up (the Hall inside the hub) they use KitGlass (the world).
##   var fr := HeroFrost.attach(self)                 # in the screen's _ready
##   fr.set_layers([{"tex": bg_tex, "rect": Rect2(Vector2.ZERO, vp)},
##                  {"tex": splash, "rect": splash_rect}])   # (re)renders the still
##   panel.material = HeroFrost.mat()                 # top screen's frost, or KitGlass, or null
## Budget (§13): two SubViewports of ~72 x 128 px rendered UPDATE_ONCE per set_layers / refresh.

const DIV := 10.0
const SPREAD := 1.6
const BLUR := preload("res://shaders/ui/snap_blur.gdshader")
const FROST_SHADER := preload("res://shaders/ui/ui_frost.gdshader")

static var _stack: Array[HeroFrost] = []

var layers: Array = []
## Frost look: the kit's sheet / modal frost, a little more of the screen kept (it is art).
var contrast := 0.7
var desat := 0.2
var lift := 0.16
var ready_once := false
var _snap: SubViewport
var _blur: SubViewport
var _blur_rect: ColorRect
var _mats := {}
var _busy := false
var _again := false


## Creates the frost of `host` (a full-screen heroes screen) as its child.
static func attach(host: Node) -> HeroFrost:
	var f := HeroFrost.new()
	host.add_child(f)
	return f


## The frost of the topmost live heroes screen (null when none is up).
static func current() -> HeroFrost:
	for i in range(_stack.size() - 1, -1, -1):
		var f := _stack[i]
		if is_instance_valid(f) and f.is_inside_tree():
			return f
	return null


## A frost material: the top heroes screen's still, else the hub world (KitGlass), else null.
static func mat(tint := UITokens.FROST_MODAL_TINT) -> ShaderMaterial:
	var f := current()
	if f:
		return f.material(tint)
	return KitGlass.frost(tint)


## Frosts a KitSheet (UIKit.sheet) with the top screen's still (no-op without one: the kit already
## used the world or the flat fallback). `pad` = the pad the sheet was made with.
static func frost_sheet(s: KitSheet, pad := Vector2(-1, -1), f: HeroFrost = null) -> void:
	if f == null:
		f = current()
	if f == null:
		return
	s.add_theme_stylebox_override("panel", UIKit.lux("sheet_frost", pad))
	s.material = f.material(UITokens.FROST_RIM_TINT)
	UIKit.text_bed(s, 0.2).sheet_top = true


## Frosts a PanelContainer as the kit's frosted `kind` ("modal" | "panel"): the opaque-painted body,
## the frost material at `tint`, the 1 dpx frame overlay (flourishes on a modal) and, with `bed`,
## the 94 % text bed under its content (§4.3). `bed = false` is for glass that carries only short
## labels whose contrast the tint itself guarantees (tint >= 0.78: INK >= 5:1 on the darkest art).
## Returns false (nothing changed) when no heroes screen frost is up.
static func frost_panel(p: PanelContainer, kind := "modal", pad := Vector2(-1, -1), f: HeroFrost = null,
		tint := UITokens.FROST_MODAL_TINT, bed := true) -> bool:
	if f == null:
		f = current()
	if f == null:
		return false
	p.add_theme_stylebox_override("panel", UIKit.lux(kind + "_frost", pad))
	p.material = f.material(tint)
	var tb := UIKit.text_bed(p)
	tb.frame_kind = kind + "_lines"
	tb.bed = bed
	return true


func _init() -> void:
	_snap = SubViewport.new()
	_snap.disable_3d = true
	_snap.transparent_bg = false
	_snap.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_snap)
	_blur = SubViewport.new()
	_blur.disable_3d = true
	_blur.transparent_bg = false
	_blur.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_blur_rect = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = BLUR
	m.set_shader_parameter("src", _snap.get_texture())
	m.set_shader_parameter("spread", SPREAD)
	_blur_rect.material = m
	_blur.add_child(_blur_rect)
	add_child(_blur)


func _enter_tree() -> void:
	if not _stack.has(self):
		_stack.append(self)


func _exit_tree() -> void:
	_stack.erase(self)


func texture() -> Texture2D:
	return _blur.get_texture()


## Layers, back to front, in CANVAS coordinates of the screen (720-wide canvas):
##   {"tex": Texture2D, "rect": Rect2, "mod": Color (optional)}
##   {"color": Color, "rect": Rect2}
##   {"grad": [top, bottom], "rect": Rect2}
##   {"mat": Material, "rect": Rect2}                  (a shader backdrop, e.g. the Portal sky)
func set_layers(p_layers: Array) -> void:
	layers = p_layers
	if not is_inside_tree():
		return
	_rebuild()
	refresh()


## Re-renders the still (e.g. once the screen's own backdrop bake is done).
func refresh() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _busy:
		_again = true
		return
	_busy = true
	_snap.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_blur.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	_busy = false
	if OS.has_environment("HERO_FROST_DEBUG"):
		var im := texture().get_image()
		for ch in _snap.get_children():
			print("  L ", ch.get_class(), " ", (ch as Control).position, " ", (ch as Control).size, " q=", ch.is_queued_for_deletion())
		print("HERO_FROST ", get_parent().name, " ", _snap.size, " layers=", layers.size(), " px=", im.get_pixel(im.get_width() / 2, im.get_height() * 3 / 4) if im else null)
		if im:
			im.save_png("/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/uiv3/p3/frost_%s.png" % get_parent().name)
	if not ready_once:
		ready_once = true
		for m: ShaderMaterial in _mats.values():
			_look(m, true)
	if _again:
		_again = false
		refresh()


func _ready() -> void:
	if not layers.is_empty():
		_rebuild()
		refresh()


func _rebuild() -> void:
	for c in _snap.get_children():
		c.queue_free()
	var ws := Vector2(get_window().size) if get_window() else Vector2(720, 1280)
	var px := Vector2i(maxi(16, int(ws.x / DIV)), maxi(16, int(ws.y / DIV)))
	_snap.size = px
	_blur.size = px
	_blur_rect.size = Vector2(px)
	(_blur_rect.material as ShaderMaterial).set_shader_parameter("texel", Vector2(1.0 / px.x, 1.0 / px.y))
	var canvas := (get_viewport() as Viewport).get_visible_rect().size if get_viewport() else Vector2(720, 1280)
	var k := Vector2(px) / Vector2(maxf(canvas.x, 1.0), maxf(canvas.y, 1.0))
	for L: Dictionary in layers:
		var r: Rect2 = L.get("rect", Rect2(Vector2.ZERO, canvas))
		var rr := Rect2(r.position * k, r.size * k)
		if L.has("tex") and L["tex"] != null:
			var t := TextureRect.new()
			t.texture = L["tex"]
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.position = rr.position
			t.size = rr.size
			t.modulate = L.get("mod", Color.WHITE)
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			_snap.add_child(t)
		elif L.has("mat"):
			var mr := ColorRect.new()
			mr.color = Color.WHITE
			mr.material = L["mat"]
			mr.position = rr.position
			mr.size = rr.size
			_snap.add_child(mr)
		elif L.has("grad"):
			var g := _Grad.new()
			g.top = (L["grad"] as Array)[0]
			g.bot = (L["grad"] as Array)[1]
			g.position = rr.position
			g.size = rr.size
			_snap.add_child(g)
		elif L.has("color"):
			var c := ColorRect.new()
			c.color = L["color"]
			c.position = rr.position
			c.size = rr.size
			_snap.add_child(c)


## The frost material at `tint` (share of the painted cream over the screen), cached per tint.
func material(tint := UITokens.FROST_MODAL_TINT) -> ShaderMaterial:
	var key := "%.2f" % tint
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = FROST_SHADER
	m.set_shader_parameter("snap_tex", texture())
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("page_tint", Color.WHITE)
	_look(m, ready_once)
	_mats[key] = m
	return m


func _look(m: ShaderMaterial, on: bool) -> void:
	# Until the first still is rendered the glass is flat cream (the empty texture never shows).
	m.set_shader_parameter("frost_contrast", contrast if on else 0.0)
	m.set_shader_parameter("frost_mid", 0.8 if on else 0.93)
	m.set_shader_parameter("frost_desat", desat)
	m.set_shader_parameter("frost_lift", lift)


class _Grad extends Control:
	var top := Color.WHITE
	var bot := Color.WHITE

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([top, top, bot, bot]))
