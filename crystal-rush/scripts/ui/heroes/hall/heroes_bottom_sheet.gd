class_name HeroesBottomSheet
extends Control
## A full-screen holder for one kit bottom sheet (KitSheet: cream, arched top, keystone) with a
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
var hub_modal := false
var hub: Hub
## Sheet height as a share of the screen (0 = fit the content, up to max_frac).
var height_frac := 0.0
var max_frac := 0.86
var sheet: KitSheet
var body: VBoxContainer
var head: HBoxContainer
var _title: Label
var _scrim: ColorRect
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
		_scrim.create_tween().tween_property(_scrim, "color:a", 0.45, UITokens.MENU_IN)
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
		_closing = true
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
		_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scrim.create_tween().tween_property(_scrim, "color:a", 0.0, UITokens.MENU_OUT)
	if tw:
		tw.finished.connect(func(): closed.emit())
	else:
		closed.emit()


## Hub.pop_modal calls this for the exit motion.
func play_exit() -> Tween:
	if UITokens.reduce_motion():
		return null
	return UIJuice.sheet_out(sheet)
