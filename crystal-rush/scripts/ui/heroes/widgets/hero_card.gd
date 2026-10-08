class_name HeroCard
extends Control
## The hero / champion collection card (owner round 2: painted portrait on a gem-gradient ground,
## thin gold frame, gem emblem top-left, class + element, name and level at the bottom). Built on
## the kit's KitGemCard (ground, fracture pattern, frame, footer, seam pips) plus:
##  * the art by HeroArt state: splash crop / card.png, the live 3D bust for starters (one baked
##    render per hero, shared by every card), or the engraved class emblem ("unknown" card);
##  * the gem emblem top-left, a DOUBLET stone for a recut character (rule #3);
##  * class (cream socket) + element (slate socket) bottom-right of the art; S shows the class only;
##  * the «НОВИЙ» wax seal top-right; facet pips on the seam once the character has fragments;
##  * locked / unowned: dimmed ground, a lock disc and the source line («Портал», «Після рівня 24»).
## Sizes: "S" 124x186 (x10 summary, team slots) · "M" 156x208 (champions, compact grids) ·
## "L" 216x300 (Hall heroes). Every size keeps a >= 88 px touch target.
##   var c := HeroCard.make(HeroesUIModel.hero("vesta"), "L")
##   c.pressed.connect(func(id): open_showcase(id))
##   c.set_data(HeroesUIModel.hero("vesta"))      # refresh in place

signal pressed(id: String)

const SIZES := {"S": Vector2(124, 186), "M": Vector2(156, 208), "L": Vector2(216, 300)}
const FOOTER := {"S": 0.27, "M": 0.25, "L": 0.21}

var data: Dictionary = {}
var size_kind := "L"
var card: KitGemCard
var _emblem: HeroGemEmblem
var _sockets: HBoxContainer
var _seal: HeroWaxSeal
var _lock: Control
var _placeholder: Control
var _down := false


static func make(p_data: Dictionary, p_size := "L") -> HeroCard:
	var c := HeroCard.new()
	c.size_kind = p_size if SIZES.has(p_size) else "L"
	c.custom_minimum_size = SIZES[c.size_kind]
	c.size = SIZES[c.size_kind]
	c.set_data(p_data)
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = KitGemCard.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.show_mark = false
	add_child(card)
	_placeholder = _Placeholder.new()
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.content.add_child(_placeholder)
	_emblem = HeroGemEmblem.new()
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_emblem)
	_sockets = HBoxContainer.new()
	_sockets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sockets.add_theme_constant_override("separation", 4)
	add_child(_sockets)
	_lock = _LockDisc.new()
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock)
	resized.connect(_layout)


func _ready() -> void:
	_layout()
	_apply()


## Fills the card from a HeroesUIModel hero() / champion() dictionary.
func set_data(d: Dictionary) -> void:
	data = d
	if is_node_ready():
		_apply()


func _sz() -> Vector2:
	return size if size.x > 1.0 else SIZES[size_kind]


func _layout() -> void:
	var s := _sz()
	var em := clampf(s.x * 0.24, 30.0, 54.0)
	_emblem.position = Vector2(6, 6)
	_emblem.size = Vector2(em, em)
	var fh := roundf(s.y * float(FOOTER[size_kind]))
	var so := 30.0 if size_kind == "S" else (34.0 if size_kind == "M" else 40.0)
	_sockets.position = Vector2(s.x - (so * _sockets.get_child_count() + 4.0 * maxi(0, _sockets.get_child_count() - 1)) - 8.0, s.y - fh - so - 10.0)
	_lock.size = Vector2(s.x * 0.36, s.x * 0.36)
	_lock.position = Vector2((s.x - _lock.size.x) * 0.5, (s.y - fh) * 0.46 - _lock.size.y * 0.5)
	if _seal:
		_seal.position = Vector2(s.x - _seal.size.x * 0.82, -_seal.size.y * 0.18)


func _apply() -> void:
	if data.is_empty():
		return
	var is_hero := str(data.get("kind", "hero")) == "hero"
	var owned := bool(data.get("owned", false))
	var gem := str(data.get("gem", "C"))
	card.gem = gem
	card.footer_ratio = float(FOOTER[size_kind])
	card.title = str(data.get("name", ""))
	card.dim = not owned
	# Footer: level for owned heroes, the role line for champions (§11.3), the source when locked.
	var foot := ""
	if not owned:
		var src: Dictionary = data.get("source", {})
		match str(src.get("kind", "")):
			"level": foot = HeroesText.t("HALL_SRC_LEVEL", [int(src.get("level", 0))])
			"portal": foot = HeroesText.t("HALL_SRC_PORTAL")
			_: foot = HeroesText.t("HALL_SRC_CHEST") if not is_hero else ""
	elif is_hero:
		foot = HeroesText.t("SHOW_LV", [int(data.get("eff_level", data.get("level", 1)))])
	else:
		foot = str(data.get("role", ""))
	card.footer = foot
	# Pips only once the character has fragments or facets (progressive disclosure §11.3).
	var show_pips := owned and (int(data.get("facets", 0)) > 0 or int(data.get("frags", 0)) > 0)
	card.pips = int(data.get("facets", 0)) if show_pips else -1
	_emblem.gem = gem
	_emblem.native = str(data.get("native", gem)) if bool(data.get("is_recut", false)) else ""
	_emblem.modulate.a = 0.55 if not owned else 1.0
	# Sockets.
	for ch in _sockets.get_children():
		ch.queue_free()
	var so := 30.0 if size_kind == "S" else (34.0 if size_kind == "M" else 40.0)
	var cls := UIKit.socket("cls_" + str(data.get("class", "warrior")), so)
	cls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sockets.add_child(cls)
	if size_kind != "S":
		var el := UIKit.socket("el_" + str(data.get("element", "kinetic")), so, true)
		el.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sockets.add_child(el)
	_sockets.modulate.a = 0.6 if not owned else 1.0
	# NEW wax seal.
	if bool(data.get("is_new", false)) and owned:
		if _seal == null:
			var px := 52.0 if size_kind == "S" else (58.0 if size_kind == "M" else 68.0)
			_seal = HeroWaxSeal.make(px)
			add_child(_seal)
	elif _seal:
		_seal.queue_free()
		_seal = null
	_lock.visible = not owned
	_apply_art()
	_layout()


func _apply_art() -> void:
	var id := str(data.get("id", ""))
	var st := HeroArt.state(id)
	_placeholder.visible = false
	card.art.texture = null
	card.art.modulate = Color(0.3, 0.32, 0.38, 0.35) if card.dim else Color.WHITE
	match st:
		"splash", "card":
			card.art.texture = HeroArt.card_texture(id)
		"live3d":
			var px := 192 if size_kind == "S" else 256
			var tex := HeroArt.cached_portrait(id, px)
			if tex:
				card.art.texture = tex
			else:
				_load_live(id, px)
		"silhouette":
			card.art.texture = HeroArt.silhouette(id)
			card.art.modulate = Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.18)
		_:
			(_placeholder as _Placeholder).cls = str(data.get("class", "warrior"))
			(_placeholder as _Placeholder).gem = str(data.get("gem", "C"))
			_placeholder.modulate.a = 0.45 if card.dim else 1.0
			_placeholder.visible = true
			_placeholder.queue_redraw()


func _load_live(id: String, px: int) -> void:
	if not is_inside_tree():
		await ready
	var tex: Texture2D = await HeroArt.live_portrait(self, id, px)
	if tex == null or not is_instance_valid(self) or str(data.get("id", "")) != id:
		return
	card.art.texture = tex
	if not UITokens.reduce_motion():
		card.art.modulate.a = 0.0
		create_tween().tween_property(card.art, "modulate:a", 1.0, 0.25)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var down: bool = e.pressed
		if down != _down:
			_down = down
			pivot_offset = size * 0.5
			if not UITokens.reduce_motion():
				create_tween().tween_property(self, "scale", Vector2(0.97, 0.97) if down else Vector2.ONE, 0.09)
	if UIJuice.is_tap(e):
		pressed.emit(str(data.get("id", "")))


## Plays the NEW seal press (e.g. when the card first appears after a summon).
func stamp_new(delay := 0.0) -> void:
	if _seal:
		_seal.stamp(delay)


class _Placeholder extends Control:
	var cls := "warrior"
	var gem := "C"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		HeroArt.draw_placeholder(self, r, cls, gem)


class _LockDisc extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 2), R, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.14))
		draw_circle(c, R, UITokens.PAPER_0)
		draw_arc(c, R - 0.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
		var s := R * 1.0
		Icons.draw_icon(self, "lock", Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), UITokens.INK_DIM)
