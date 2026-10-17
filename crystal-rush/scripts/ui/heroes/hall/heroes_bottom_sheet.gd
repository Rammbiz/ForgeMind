class_name HeroesBottomSheet
extends Control
## A full-screen holder for one kit bottom sheet (KitSheet, UI v3.1: frosted glass with the text bed,
## a straight fading top rule with a centre diamond; HeroFrost picks the screen it frosts) with a
## title row (title + optional extra controls + close disc) and a `body` VBox. Used by the
## Codex «?» and the Manage sheet «Покращення». Works in three hosts:
##  * a Hub modal (hub.push_modal(sheet); the hub draws the scrim; `hub_modal = true`),
##  * a HeroesNav "modal" route (emits `closed`, the router closes it),
##  * inside a full-screen heroes screen (Showcase): `own_scrim = true` draws the slate scrim
##    and taps on it close the sheet.
## Motion: UIJuice.sheet_in on enter, sheet_out on close (Reduce Motion: instant).
##   var s := HeroesBottomSheet.new(); s.title = "Довідник"; s.own_scrim = true
##   host.add_child(s); s.body.add_child(...)
##   s.closed.connect(func(): s.queue_free())

signal closed

var title := "":
	set(v):
		title = v
		if _title:
			_title.text = v
var own_scrim := false
## Own scrim look: "slate" (flat SCRIM 45 %) or "warm" (a warm gradient, 0 at the top to ~30 %
## at the bottom, ~22 % on average: the hero above the sheet stays bright, Genshin's character
## screen keeps the character in view).
var scrim_style := "slate"
var hub_modal := false
var hub: Hub
## Sheet height as a share of the screen (0 = fit the content, up to max_frac).
var height_frac := 0.0
var max_frac := 0.86
## true: the sheet stays hidden after _ready until show_in() (a subclass that sizes itself to
## laid-out content waits a frame or two first, so the slide-in ends at the right height).
var defer_in := false
var sheet: KitSheet
var body: VBoxContainer
var head: HBoxContainer
var _title: Label
var _scrim: ColorRect
var _warm: TextureRect
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	sheet = UIKit.sheet(Vector2(UITokens.GUTTER + 4.0, 26.0))
	# v3.1: over a full heroes screen the sheet frosts THAT screen (its sky and splash); over the
	# Hall the kit's world frost stays. Frost rim + top 20 % ramp, rows on the 94 % text bed.
	HeroFrost.frost_sheet(sheet, Vector2(UITokens.GUTTER + 4.0, 26.0))
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	sheet.add_child(v)
	head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	_title = UIKit.heading(title, 34, UITokens.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	var x := UIKit.edge_button("close", 30.0)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(close)
	head.add_child(x)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	resized.connect(_layout)
	sheet.resized.connect(_layout)


func _ready() -> void:
	if own_scrim:
		_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		_scrim.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				close())
		if scrim_style == "warm":
			_warm = TextureRect.new()
			var gt := GradientTexture2D.new()
			var gr := Gradient.new()
			var wc := Color("#3A2A1A")
			gr.set_color(0, Color(wc.r, wc.g, wc.b, 0.0))
			gr.add_point(0.45, Color(wc.r, wc.g, wc.b, 0.16))
			gr.set_color(gr.get_point_count() - 1, Color(wc.r, wc.g, wc.b, 0.34))
			gt.gradient = gr
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(0, 1)
			gt.width = 4
			gt.height = 64
			_warm.texture = gt
			_warm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_warm.stretch_mode = TextureRect.STRETCH_SCALE
			_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_warm.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(_warm)
			move_child(_warm, 1)
			_warm.modulate.a = 0.0
			_warm.create_tween().tween_property(_warm, "modulate:a", 1.0, UITokens.MENU_IN)
		else:
			_scrim.create_tween().tween_property(_scrim, "color:a", UITokens.SCRIM_MODAL, UITokens.MENU_IN)
	_layout()
	if defer_in:
		sheet.modulate.a = 0.0
		return
	if not UITokens.reduce_motion():
		UIJuice.sheet_in(sheet)


## Shows a `defer_in` sheet (slides in from its final height).
func show_in() -> void:
	sheet.modulate.a = 1.0
	_layout()
	if not UITokens.reduce_motion():
		UIJuice.sheet_in(sheet)


func _vp_h() -> float:
	return size.y if size.y > 1.0 else get_viewport_rect().size.y


func _layout() -> void:
	var H := _vp_h()
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	var ins := hub.insets() if hub else Vector4.ZERO
	var h := H * height_frac if height_frac > 0.0 else minf(sheet.get_combined_minimum_size().y, H * max_frac)
	h = maxf(h, sheet.get_combined_minimum_size().y) if height_frac <= 0.0 else h
	h = minf(h + ins.w, H * max_frac + ins.w)
	sheet.position = Vector2(0, H - h)
	sheet.size = Vector2(W, h)


## Closes the sheet the right way for its host.
func close() -> void:
	if _closing:
		return
	if str(get_meta("heroes_host", "")) == "modal":
		# A HeroesNav modal route: the router plays the exit (play_exit) and frees the layer.
		_closing = true
		if own_scrim:
			_fade_scrim_out()
		closed.emit()
		return
	if hub_modal and hub:
		_closing = true
		hub.close_modal(self)
		return
	_closing = true
	Audio.play("click", -12.0)
	var tw := play_exit()
	if own_scrim:
		_fade_scrim_out()
	if tw:
		tw.finished.connect(func(): closed.emit())
	else:
		closed.emit()


func _fade_scrim_out() -> void:
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.create_tween().tween_property(_scrim, "color:a", 0.0, UITokens.MENU_OUT)
	if _warm:
		_warm.create_tween().tween_property(_warm, "modulate:a", 0.0, UITokens.MENU_OUT)


## Hub.pop_modal calls this for the exit motion.
func play_exit() -> Tween:
	if UITokens.reduce_motion():
		return null
	return UIJuice.sheet_out(sheet)
