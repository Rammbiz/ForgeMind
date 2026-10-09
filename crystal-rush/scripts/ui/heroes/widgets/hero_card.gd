class_name HeroCard
extends Control
## The hero / champion collection card (owner round 2: painted portrait on a gem-gradient ground,
## thin gold frame, gem emblem top-left, class + element, name and level at the bottom). Built on
## the kit's KitGemCard (ground, fracture pattern, frame, footer, seam pips) plus:
##  * the art by HeroArt state: splash crop / card.png, the live 3D bust for starters (one baked
##    render per hero, shared by every card), or the engraved class emblem ("unknown" card);
##  * the gem emblem top-left, a DOUBLET stone for a recut character (rule #3);
##  * class (cream socket) + element (slate socket) bottom-right of the art; S shows the class only;
##  * the «НОВИЙ» mark top-right (v3.1: the amber notify diamond, HeroWaxSeal under 76 px); facet pips on the seam once the character has fragments;
##  * locked / unowned: dimmed ground, a lock disc and the source line («Портал», «Після рівня 24»).
## Sizes: "S" 124x186 (x10 summary, team slots) · "M" 156x208 (champions, compact grids) ·
## "L" 216x300 (Hall heroes) · "XL" 300x416 (the Hall while it lists < 6 heroes). Every size
## keeps a >= 88 px touch target.
## Footer text is drawn by HeroCard (not the kit's 14 px footer): the name at 22-28 px and the
## sub-line (level / role / source) at 20-22 px. `footer_mode`: "full" (name + sub-line; L, M,
## XL default) · "name" (S default, or when the screen prints the sub-line outside the card) ·
## "none". `show_role = false` drops a champion's role line (Team prints it as its own chip).
##   var c := HeroCard.make(HeroesUIModel.hero("vesta"), "L")
##   c.pressed.connect(func(id): open_showcase(id))
##   c.set_data(HeroesUIModel.hero("vesta"))      # refresh in place

signal pressed(id: String)

const SIZES := {"S": Vector2(124, 186), "M": Vector2(156, 208), "L": Vector2(216, 300), "XL": Vector2(300, 416)}
const FOOTER := {"S": 0.26, "M": 0.3, "L": 0.22, "XL": 0.2}
## Footer type sizes per card size: [name, name min, sub-line].
const FOOT_TYPE := {"S": [22, 18, 20], "M": [24, 18, 20], "L": [26, 20, 22], "XL": [32, 24, 24]}

var data: Dictionary = {}
var size_kind := "L"
## "auto" (S = "name", others "full") · "full" · "name" · "none".
var footer_mode := "auto":
	set(v):
		footer_mode = v
		if is_node_ready():
			_apply()
var show_role := true:
	set(v):
		show_role = v
		if is_node_ready():
			_apply()
var card: KitGemCard
var _foot: _Footer
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
	_foot = _Footer.new()
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_foot)
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
	var fh := roundf(s.y * _footer_ratio())
	var so := _socket_px()
	var sw := so * _sockets.get_child_count() + 4.0 * maxi(0, _sockets.get_child_count() - 1)
	# Unowned: the sockets move to the top-right corner (the bottom of the art carries the
	# «Де знайти» cartouche) and the lock disc sits in the upper third, off the face.
	var owned := bool(data.get("owned", true))
	_sockets.position = Vector2(s.x - sw - 8.0, s.y - fh - so - 10.0) if owned else Vector2(s.x - sw - 8.0, 8.0)
	_lock.size = Vector2(s.x * 0.3, s.x * 0.3)
	_lock.position = Vector2((s.x - _lock.size.x) * 0.5, (s.y - fh) * 0.3 - _lock.size.y * 0.5)
	if _seal:
		# v3.1: the amber notify diamond sits inside the top-right corner (never over the face).
		_seal.position = Vector2(s.x - _seal.size.x - 2.0, 2.0)


func _apply() -> void:
	if data.is_empty():
		return
	var is_hero := str(data.get("kind", "hero")) == "hero"
	var owned := bool(data.get("owned", false))
	var gem := str(data.get("gem", "C"))
	card.gem = gem
	card.footer_ratio = _footer_ratio()
	card.title = ""
	card.footer = ""
	card.dim = not owned
	# A dimmed (unowned) opal card drops the kit's play-of-colour layer so it greys like the rest
	# (KitGemCard keeps it on for every opal; requested as a kit fix).
	var opal_layer := card.get("_opal") as Control
	if opal_layer:
		opal_layer.visible = UITokens.gem_of(gem) == "opal" and owned and UIKit.kit_texture("card_opal") == null
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
	elif show_role:
		foot = str(data.get("role", ""))
	var mode := footer_mode
	if mode == "auto":
		mode = "name" if size_kind == "S" else "full"
	_foot.title = str(data.get("name", "")) if mode != "none" else ""
	_foot.sub = foot if mode == "full" else ""
	_foot.type = FOOT_TYPE[size_kind]
	_foot.footer_ratio = _footer_ratio()
	_foot.dim = not owned
	# Pips only once the character has fragments or facets (progressive disclosure §11.3).
	var show_pips := owned and (int(data.get("facets", 0)) > 0 or int(data.get("frags", 0)) > 0)
	card.pips = int(data.get("facets", 0)) if show_pips else -1
	_foot.pips = show_pips
	_emblem.gem = gem
	_emblem.native = str(data.get("native", gem)) if bool(data.get("is_recut", false)) else ""
	_emblem.modulate.a = 0.55 if not owned else 1.0
	# Sockets.
	for ch in _sockets.get_children():
		ch.queue_free()
	var so := _socket_px()
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
			var px := 40.0 if size_kind == "S" else (44.0 if size_kind == "M" else (50.0 if size_kind == "L" else 56.0))
			_seal = HeroWaxSeal.make(px)
			add_child(_seal)
	elif _seal:
		_seal.queue_free()
		_seal = null
	_lock.visible = not owned
	_foot.queue_redraw()
	_apply_art()
	_layout()


## The cream footer share of the card height: a name-only footer is a quarter shorter.
func _footer_ratio() -> float:
	var r := float(FOOTER[size_kind])
	var mode := footer_mode
	if mode == "auto":
		mode = "name" if size_kind == "S" else "full"
	if mode != "full" and size_kind != "S":
		r *= 0.74
	return r


func _socket_px() -> float:
	return {"S": 30.0, "M": 34.0, "L": 40.0, "XL": 48.0}[size_kind]


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
			var px := 192 if size_kind == "S" else (256 if size_kind != "XL" else 384)
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
		var target := card.art.modulate.a
		card.art.modulate.a = 0.0
		create_tween().tween_property(card.art, "modulate:a", target, 0.25)


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


## The footer text over the kit's cream strip: the name (bold, fitted to the width) and the
## sub-line, centred; room is left for the facet pips on the seam.
class _Footer extends Control:
	var title := ""
	var sub := ""
	var type: Array = [26, 20, 22]
	var footer_ratio := 0.22
	var pips := false
	var dim := false

	func _draw() -> void:
		if title == "" and sub == "":
			return
		var fh := roundf(size.y * footer_ratio)
		var seam := size.y - fh
		var room := 7.0 if pips else 0.0
		var f := UIKit.font_w("bold")
		var fm := UIKit.font_w("medium")
		var w := size.x - 14.0
		var ts := int(type[0])
		while ts > int(type[1]) and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > w:
			ts -= 1
		var ss := int(type[2])
		while ss > 17 and fm.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x > w:
			ss -= 1
		var body := fh - room
		var th := f.get_ascent(ts) * 0.92
		var sh := fm.get_ascent(ss) * 0.92 if sub != "" else 0.0
		var gap := 3.0 if sub != "" else 0.0
		var y := seam + room + (body - th - sh - gap) * 0.5
		if title != "":
			var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
			draw_string(f, Vector2((size.x - tw) * 0.5, y + th), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, UITokens.INK if not dim else UITokens.INK_DIM_GLASS)
		if sub != "":
			var sw := fm.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
			draw_string(fm, Vector2((size.x - sw) * 0.5, y + th + gap + sh), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UITokens.INK_DIM_GLASS)


class _LockDisc extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		HeroV3.disc(self, c, R, 0.88, HeroV3.GOLD, 0.8, 0.1)
		var s := R * 1.0
		Icons.draw_icon(self, "lock", Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), UITokens.INK_DIM_GLASS)
