class_name SummonSheet
extends Control
## Base of the Portal sheets (Шанси, Вибір за печатками, Історія, Фокус): a frosted glass modal
## (UI v3.1: HeroFrost / KitGlass frost, the text bed, one 1 dpx frame, top-corner flourishes), title + close disc, a divider and a
## scrolling body, centred between the top bar and the dock. Works in both hosts:
##  * HeroesNav route ("odds", "seals"): the hub modal layer gives the scrim; `closed` -> back();
##  * embedded over the Portal screen (args ["embedded"]): PortalScreen adds the scrim.
## Subclasses override `_title()` and `_fill(body)`; `refill()` rebuilds the body.

signal closed

var hub: Hub
var embedded := false
var body: VBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _shown := false


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	embedded = args.has("embedded")


func _title() -> String:
	return ""


func _fill(_b: VBoxContainer) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	# v3.1 (§9 summon row): a frosted modal (the Portal night glows through the rim), the 94 % text
	# bed under the body, top-corner flourishes; the kit's world frost when no heroes screen is up.
	_panel = PanelContainer.new()
	if not HeroFrost.frost_panel(_panel, "modal", Vector2(28, 24)):
		_panel.free()
		_panel = UIKit.panel("modal", Vector2(28, 24))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var tl := UIKit.heading(_title(), 34, UITokens.INK)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(tl)
	var x := UIKit.edge_button("close", 30.0)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(func(): closed.emit())
	head.add_child(x)
	col.add_child(head)
	col.add_child(UIKit.divider(600.0))
	var bed := UIKit.text_bed_of(_panel)
	if bed:
		bed.header = head
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	# The list melts into the bed at its edges: the bed colour reaches FULL strength before the
	# edge (never a flat crop through the Opal cards). Painted: the cards clip themselves, and
	# nested clip groups do not compose in gl_compatibility.
	HeroHScrollFade.paint_v(_scroll, UITokens.PAPER_0, 88.0, 22.0)
	_fill(body)
	resized.connect(_layout)
	_panel.modulate.a = 0.0
	_layout.call_deferred()


func refill() -> void:
	for c in body.get_children():
		c.queue_free()
	_fill(body)
	_layout.call_deferred()


func _layout() -> void:
	var W := size.x
	var H := size.y
	if W < 10.0:
		return
	var ins := UIKit.safe_insets(get_viewport())
	var g := UITokens.GUTTER
	var top := ins.y + 100.0
	var bottom := ins.w + 156.0
	var maxh := H - top - bottom
	var pw := W - 2.0 * g
	var content_h := body.get_combined_minimum_size().y
	var chrome := 24.0 * 2.0 + 12.0 * 2.0 + 64.0 + 12.0
	var ph := minf(maxh, content_h + chrome + 8.0)
	_scroll.custom_minimum_size.y = maxf(ph - chrome, 80.0)
	_panel.size = Vector2(pw, ph)
	_panel.position = Vector2(g, top + (maxh - ph) * 0.42)
	if not _shown:
		_shown = true
		_panel.modulate.a = 1.0
		UIJuice.sheet_in(_panel)


func play_exit() -> Tween:
	return UIJuice.sheet_out(_panel)


## A table row: [icon][label ........ value] with a hairline under it (no boxes).
static func row(left: Control, text: String, value: String, value_color := UITokens.INK, size := 24, bold_value := true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size.y = 48
	if left:
		left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(left)
	var l := UIKit.label(text, size, UITokens.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	if value != "":
		var r := UIKit.label(value, size, value_color, bold_value)
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(r)
	v.add_child(h)
	v.add_child(UIKit.hairline())
	return v


## A gem-cut mark control of `px`.
static func gem_mark(g: String, px := 34.0) -> Control:
	var m := PortalScreen._GemMark.new()
	m.gem = g
	m.custom_minimum_size = Vector2(px, px)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## A wrapped body paragraph (22 px, ink dim).
static func para(text: String, size := 22, color := UITokens.INK_DIM_GLASS) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l
