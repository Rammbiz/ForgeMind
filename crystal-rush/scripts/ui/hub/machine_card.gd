class_name MachineCard
extends Control
## A machine card of the Arsenal grid (arsenal_design.md §7.1-7.2, card data §6.2), UI v2
## (Genshin-style rarity card, ui_v2_contract §3.8): a KitGemCard ground in the rarity's gem
## gradient with its fracture pattern, thin gold frame and the gem-cut mark top-left; the
## machine render (MachineThumbs; the vector icon until it is ready) standing in a soft light
## pool; a cream name strip with "Рів. 7" and the blueprint count; the blueprint progress as a
## thin amber bar on the seam. Family = slate socket top-right, Lead = crown over the top edge,
## Deck / Focus = small cream sockets above the seam, upgradable / talent pick = the gold notify
## badge (an up chevron / "!"; no green arrows). Prestige frames (Lv13+) add a metal hairline.
## Unowned: desaturated ground, slate silhouette, lock socket, "Світ 1, рівень 5"; Meta-2: the
## family glyph and "Скоро".
## UI v3.1 (§7.3): the selected card is a 1.5 dpx deep-gold frame with a diagonal pair of corner
## brackets (top-left, bottom-right) and a small diamond on the top edge, with no glow slab; the
## name is Medium 20 and the footer line Medium 22; every ring is 1 dpx.
## Draw-call budget: every static layer (ground, fracture, art, frame, footer text, seam bar,
## sockets, badges, crown, selection frame) is rendered once into a per-card SubViewport at the
## screen's pixel scale and shown as ONE premultiplied texture; it is re-rendered only when the
## card data, the selection, the thumb or the size changes. Only the Legendary+ glint (_Fx) is
## live (nothing travels around the frame).

signal pressed(id: String)

const SIZE := Vector2(156, 212)
const FOOTER_RATIO := 0.4
const NAME_SIZE := 20               ## one name size for the whole grid (2 lines allowed), Medium
const SMALL_SIZE := 22              ## footer line 2 (>= 22 px on glass, §5 / MF-15)
const PAD := 30.0                   ## bake margin: selection glow ring, crown above the top edge
const PRESTIGE := {"bronze": Color("#C98B5A"), "silver": Color("#C9D2DC"), "gold": Color("#E8B84A")}

var card: Dictionary = {}
var compact := false:           ## deck editor list: no blueprint bar
	set(v):
		compact = v
		_sync()
var selected := false:
	set(v):
		if v == selected:
			return
		selected = v
		queue_redraw()
		if _over:
			_over.queue_redraw()
		_rebake()
var picked := false:            ## deck list: already in the deck (dimmed + check)
	set(v):
		picked = v
		_sync()
static var _premult: ShaderMaterial
var _vp: SubViewport                ## the bake (static layers), rendered on change only
var _root: Control                  ## the card's static layers inside the bake, at PAD
var _img: _Baked                    ## the baked texture, drawn in the grid
var _bake_queued := false
var _gem: KitGemCard
var _art: _Art
var _over: _Over
var _fam: KitSocket
var _badge: KitSocket
var _badge_icon: Icons
var _fx: _Fx
var _tex: Texture2D
var _t := 0.0
var _press := false


func _init(p_card := {}) -> void:
	card = p_card
	custom_minimum_size = SIZE
	# PASS: a drag over the card still scrolls the grid; a tap without movement selects.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_t = randf() * 10.0
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.position = Vector2(PAD, PAD)
	_vp.add_child(_root)
	_img = _Baked.new()
	_img.mc = self
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _premult == null:
		_premult = ShaderMaterial.new()
		_premult.shader = load("res://shaders/ui/baked_premult.gdshader") as Shader
	_img.material = _premult
	add_child(_img)
	_gem = KitGemCard.new()
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gem.footer_ratio = FOOTER_RATIO
	_gem.pips = -1
	_root.add_child(_gem)
	_art = _Art.new()
	_art.mc = self
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gem.content.add_child(_art)
	_fam = KitSocket.new()
	_fam.slate = false
	_fam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fam)
	_over = _Over.new()
	_over.mc = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_over)
	_badge = KitSocket.new()
	_badge.badge_text = "!"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_root.add_child(_badge)
	_badge_icon = Icons.make("arrow_up", 18.0, UIKit.BROWN)
	_badge_icon.visible = false
	_badge.add_child(_badge_icon)
	# The only per-frame layer: the light travelling along an Epic+ frame (the rest is static).
	_fx = _Fx.new()
	_fx.mc = self
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	resized.connect(_layout)


func _ready() -> void:
	UIJuice.press(self, true)
	get_viewport().size_changed.connect(_rebake)
	_sync()
	_load_thumb()
	_layout()


func set_card(c: Dictionary) -> void:
	card = c
	_sync()
	_load_thumb()


func _id() -> String:
	return str(card.get("id", ""))


func _locked() -> String:
	return str(card.get("locked", ""))


func _footer_h() -> float:
	return roundf(size.y * FOOTER_RATIO)


func _seam() -> float:
	return size.y - _footer_h()


func _layout() -> void:
	_root.size = size
	_img.position = -Vector2(PAD, PAD)
	_img.size = size + Vector2(PAD, PAD) * 2.0
	var s := clampf(size.x * 0.2, 26.0, 40.0)
	_fam.size = Vector2(s, s)
	_fam.position = Vector2(size.x - s - 6.0, 7.0)
	# The one state badge: a 28 px gold "!" inside the card, bottom-right of the art.
	var bs := 28.0
	_badge.size = Vector2(bs, bs)
	_badge.position = Vector2(size.x - bs - 7.0, _seam() - bs - 9.0)
	_badge_icon.size = Vector2(bs, bs) * 0.62
	_badge_icon.position = Vector2(bs, bs) * 0.19
	if _over:
		_over.queue_redraw()
	_rebake()


## Re-renders the static layers once (coalesced to one bake per frame).
func _rebake() -> void:
	if _bake_queued:
		return
	_bake_queued = true
	_do_bake.call_deferred()


func _do_bake() -> void:
	_bake_queued = false
	if not is_inside_tree() or size.x < 2.0 or size.y < 2.0:
		return
	# Bake at the screen's pixel density (canvas_items stretch), so the card stays crisp.
	var k := clampf(get_viewport().get_final_transform().get_scale().x, 0.5, 4.0)
	var logical := Vector2i(ceili(size.x + PAD * 2.0), ceili(size.y + PAD * 2.0))
	var px := Vector2i(ceili(logical.x * k), ceili(logical.y * k))
	if _vp.size != px:
		_vp.size = px
	_vp.size_2d_override = logical
	_root.size = size
	_gem.queue_redraw()
	_art.queue_redraw()
	_over.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_img.queue_redraw()


func _sync() -> void:
	if card.is_empty() or _gem == null:
		return
	var locked := _locked()
	_gem.gem = str(card.get("rarity", "C"))
	_gem.dim = locked != ""
	_gem.title = ""
	_gem.footer = ""
	_fam.icon = "el_" + str(card.get("family", "kinetic"))
	_fam.modulate.a = 0.55 if locked != "" else 1.0
	var badge := str(card.get("badge", "")) if locked == "" else ""
	_badge.visible = badge != ""
	_badge_icon.visible = false
	_badge.badge_text = "!"
	modulate = Color(1, 1, 1, 0.55) if picked else Color.WHITE
	_art.queue_redraw()
	_over.queue_redraw()
	queue_redraw()
	_rebake()


func _load_thumb() -> void:
	if not is_inside_tree() or card.is_empty():
		return
	var id := _id()
	var asc := int(card.get("lvl", 0)) >= ArsenalData.ASCENSION_LEVEL
	_tex = MachineThumbs.get_thumb(self, id, asc)
	if _tex == null and WeaponModels.KINDS.has(id):
		var svc := MachineThumbs.service(get_tree())
		if not svc.rendered.is_connected(_on_rendered):
			svc.rendered.connect(_on_rendered)
	_art.queue_redraw()
	_rebake()


func _on_rendered(key: String, tex: Texture2D) -> void:
	if key == MachineThumbs.key_of(_id(), int(card.get("lvl", 0)) >= ArsenalData.ASCENSION_LEVEL):
		_tex = tex
		_art.queue_redraw()
		_rebake()


func _animated() -> bool:
	return _locked() == "" and str(card.get("rarity", "C")) in ["L", "M"]


func _process(delta: float) -> void:
	_t += delta
	if _animated():
		_fx.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = true
			set_meta("down_at", event.global_position)
		elif _press:
			_press = false
			var moved: float = (event.global_position as Vector2).distance_to(get_meta("down_at", event.global_position))
			if moved < 14.0 and get_global_rect().has_point(event.global_position):
				Audio.play("click", -8.0)
				pressed.emit(_id())
	elif event is InputEventMouseMotion and _press:
		if (event.global_position as Vector2).distance_to(get_meta("down_at", event.global_position)) >= 14.0:
			_press = false


## v3: no glow slab behind a selected card (the frame and brackets are in the bake).
func _draw() -> void:
	pass


## §7.3 / §3.4 selected frame on any CanvasItem: a 1.5 dpx LINE_GOLD_DEEP chamfer frame just
## outside `r` (cut `cham`), a 1 dpx light line inside it, a diagonal pair of corner brackets
## (top-left and bottom-right: 12 px arms following the 45-degree cut, a small lozenge on the cut)
## and a 10 px cut-gem diamond on the top edge. Shared by the Vault's cache picker.
static func draw_sel_frame(ci: CanvasItem, r: Rect2, cham: float) -> void:
	var deep := UITokens.LINE_GOLD_DEEP
	var o := UIKit.px(1.0)
	var fr := r.grow(o * 1.5)
	GemDraw.outline(ci, GemDraw.chamfer_rect(fr, cham + o), Color(deep.r, deep.g, deep.b, 0.95), UIKit.line_px(1.5))
	GemDraw.outline(ci, GemDraw.chamfer_rect(r.grow(-o * 0.5), maxf(cham - o, 2.0)), Color(1, 1, 1, 0.55), UIKit.px(1.0))
	var g := 6.0
	var br := r.grow(g)
	var c := cham + g * 0.41
	var arm := 12.0
	var col := Color(deep.r, deep.g, deep.b, 0.8)
	for k in 2:
		var o0 := br.position if k == 0 else br.end
		var dx := Vector2(1, 0) if k == 0 else Vector2(-1, 0)
		var dy := Vector2(0, 1) if k == 0 else Vector2(0, -1)
		var pts := PackedVector2Array([o0 + dy * (c + arm), o0 + dy * c, o0 + dx * c, o0 + dx * (c + arm)])
		ci.draw_polyline(pts, col, UIKit.line_px(1.0), true)
		var n := (dx + dy).normalized()
		var m := o0 + (dx + dy) * (c * 0.5) + n * 3.0
		var t := Vector2(-n.y, n.x)
		ci.draw_colored_polygon(PackedVector2Array([m + n * 2.6, m + t * 1.4, m - n * 2.6, m - t * 1.4]), col)
	GemDraw.draw_diamond(ci, Vector2(r.get_center().x, fr.position.y), 10.0, Color("#F3E2B8"), deep)


# ------------------------------------------------------------------ layers

## Art layer (inside the card's clip, above the gem ground): light pool, contact shadow and the
## machine render, or the silhouette / family glyph of a locked machine.
func draw_art(ci: CanvasItem) -> void:
	if card.is_empty():
		return
	var w := size.x
	var seam := _seam()
	var locked := _locked()
	var g: Dictionary = UITokens.gem(str(card.get("rarity", "C")))
	var lc: Color = g["light"]
	var side := minf(w * 0.96, seam * 0.98)
	var c := Vector2(w * 0.5, seam * 0.56)
	if locked == "":
		var pr := side * 0.62
		KitGemCard.glow_in(ci, Rect2(c - Vector2(pr, pr), Vector2(pr, pr) * 2.0), Rect2(Vector2.ZERO, Vector2(w, seam)), Color(lc.r, lc.g, lc.b, 0.4))
	# Contact shadow under the machine.
	var sh := Rect2(Vector2(c.x - side * 0.36, c.y + side * 0.2), Vector2(side * 0.72, side * 0.2))
	ci.draw_texture_rect(UIKit.glow_texture(), sh, false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.32 if locked == "" else 0.14))
	var ir := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
	if locked == "phase":
		Icons.line(ci, "el_" + str(card.get("family", "kinetic")), ir.grow(-side * 0.3), Color(UITokens.INK_DIM.r, UITokens.INK_DIM.g, UITokens.INK_DIM.b, 0.45))
		return
	if _tex:
		if locked != "":
			ci.draw_texture_rect(_tex, ir, false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.42))
		else:
			ci.draw_texture_rect(_tex, ir, false)
	else:
		var icon_r := ir.grow(-side * 0.16)
		Icons.draw_icon(ci, _id(), icon_r, Color.WHITE if locked == "" else Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.42))


## Overlay layer (above the card frame): footer text, seam bar, marks, selection outline.
func draw_over(ci: CanvasItem) -> void:
	if card.is_empty():
		return
	var w := size.x
	var fh := _footer_h()
	var seam := _seam()
	var locked := _locked()
	var lvl := int(card.get("lvl", 0))
	var fb := UIKit.font_w("medium")
	var fm := UIKit.font_w("medium")
	# Name (footer line 1): one size for the grid; a long name wraps to 2 lines (over the art
	# edge on a soft cream lip), ellipsis only as a last resort.
	var name := Loc.t(str(card.get("name", "")))
	var ns := NAME_SIZE
	var line2 := not compact or locked != ""
	var ny := seam + (fh * 0.47 if line2 else fh * 0.62) + (4.0 if not compact and locked == "" else 0.0)
	var ncol := UITokens.INK if locked == "" else UITokens.INK_DIM
	var lines := _name_lines(name, fb, ns, w - 12.0)
	if lines.size() == 1:
		var nw := fb.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		ci.draw_string(fb, Vector2((w - nw) * 0.5, ny), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ns, ncol)
	else:
		var y0 := seam + 5.0 + ns + 1.0
		for i in 2:
			var nw2 := fb.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
			ci.draw_string(fb, Vector2((w - nw2) * 0.5, y0 + (ns + 2.0) * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ns, ncol)
	# Footer line 2: level + blueprint count, or where to find it.
	var ss := SMALL_SIZE
	var y2 := size.y - 8.0
	if locked == "world":
		var home := int(card.get("home_level", 0))
		var txt := Loc.f("LOCKED_WORLD", [ArsenalData.world_of(home), ArsenalData.level_in_world(home)]) if home > 0 else Loc.t("LOCKED_SOON")
		_center_text(ci, txt, w * 0.5, y2, ss, UIKit.INK_DIM, w - 12.0)
	elif locked == "phase":
		_center_text(ci, Loc.t("LOCKED_SOON"), w * 0.5, y2, ss, UIKit.INK_DIM, w - 12.0)
	elif compact:
		_center_text(ci, Loc.f("LV", [lvl]), w * 0.5, y2, ss, UITokens.GOLD_TEXT_GLASS, w - 12.0)
	else:
		var maxed := lvl >= ArsenalData.MAX_LEVEL
		var lt := Loc.f("LV", [lvl])
		ci.draw_string(fm, Vector2(10.0, y2), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UITokens.GOLD_TEXT_GLASS)
		var bt := Loc.t("LV_MAX") if maxed else "%d/%d" % [maxi(int(card.get("bp", 0)), 0), int(card.get("bp_need", 0))]
		var bw := fm.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		ci.draw_string(fm, Vector2(w - 10.0 - bw, y2), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UITokens.INK if bool(card.get("can_upgrade", false)) else UIKit.INK_DIM)
		_seam_bar(ci, seam, maxed)
	# Deck membership: a thin gold hairline along the top edge (Focus lives on the detail).
	if locked == "" and bool(card.get("in_deck", false)):
		var ch0 := _gem._cham()
		var dy := UIKit.px(1.0)
		ci.draw_line(Vector2(ch0 + 4.0, 2.0), Vector2(w - ch0 - 4.0, 2.0), UITokens.CTA_LO, UIKit.line_px(1.5))
		ci.draw_line(Vector2(ch0 + 4.0, 2.0 + dy * 1.5), Vector2(w - ch0 - 4.0, 2.0 + dy * 1.5), Color(1.0, 0.97, 0.88, 0.85), dy)
	# Locked: a lock socket in the middle of the art.
	if locked == "world":
		var lc := Vector2(w * 0.5, seam * 0.52)
		var lr := clampf(w * 0.14, 16.0, 26.0)
		_mini_socket(ci, lc, lr * 2.0, "lock")
	# Prestige frame: a metal hairline just inside the gold one.
	var fr := str(card.get("frame", ""))
	if PRESTIGE.has(fr) and locked == "":
		GemDraw.outline(ci, GemDraw.chamfer_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), _gem._cham() - 1.0), PRESTIGE[fr], UIKit.line_px(1.0))
	# Selected (§7.3): 1.5 dpx deep gold + the diagonal bracket pair, no glow slab.
	if selected and locked == "":
		draw_sel_frame(ci, Rect2(Vector2.ZERO, size), _gem._cham())
	# Lead: a painted crown over the top edge (the state badge slot: not with the "!").
	if bool(card.get("is_lead", false)) and locked == "" and not _badge.visible:
		var cs := clampf(w * 0.26, 30.0, 46.0)
		Icons.draw_icon(ci, "crown", Rect2(Vector2(w * 0.5 - cs * 0.5, -cs * 0.52), Vector2(cs, cs)))
	# Deck list: a check over a picked card.
	if picked:
		_mini_socket(ci, Vector2(w * 0.5, seam * 0.5), clampf(w * 0.3, 36.0, 52.0), "check")


## The blueprint progress: a thin amber bar on a cream bed straddling the seam.
func _seam_bar(ci: CanvasItem, seam: float, maxed: bool) -> void:
	var w := size.x
	var bed_h := 12.0
	var bed := Rect2(Vector2(10.0, seam - bed_h * 0.5), Vector2(w - 20.0, bed_h))
	ci.draw_colored_polygon(GemDraw.chamfer_rect(bed, 4.0), UITokens.PAPER_1)
	GemDraw.outline(ci, GemDraw.chamfer_rect(bed, 4.0), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), UIKit.line_px(1.0))
	var tr := bed.grow_individual(-4.0, -3.5, -4.0, -3.5)
	ci.draw_colored_polygon(GemDraw.chamfer_rect(tr, 2.0), UITokens.PAPER_3)
	var need := maxi(int(card.get("bp_need", 0)), 1)
	var have := maxi(int(card.get("bp", 0)), 0)
	var wild := int(card.get("wild", 0))
	var k := 1.0 if maxed else clampf(float(have) / float(need), 0.0, 1.0)
	if not maxed and wild > 0 and have < need:
		var wk := clampf(float(have + wild) / float(need), 0.0, 1.0)
		if wk > k:
			var wr := Rect2(tr.position, Vector2(tr.size.x * wk, tr.size.y))
			ci.draw_colored_polygon(GemDraw.chamfer_rect(wr, 2.0), UITokens.CTA_HI)
	if k > 0.0:
		var can := bool(card.get("can_upgrade", false))
		var fr := Rect2(tr.position, Vector2(maxf(tr.size.x * k, 4.0), tr.size.y))
		var pts := GemDraw.chamfer_rect(fr, 2.0)
		var top := UITokens.CTA_HI if (can or maxed) else UITokens.CTA.lightened(0.25)
		var bot := UITokens.CTA_LO if (can or maxed) else UITokens.CTA
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, (p.y - fr.position.y) / maxf(fr.size.y, 1.0)))
		ci.draw_polygon(pts, cols)
	if k >= 0.999:
		GemDraw.draw_keystone(ci, Vector2(bed.end.x - 1.0, seam), 10.0, 1.0, Color(1.0, 0.86, 0.5))


func _mini_socket(ci: CanvasItem, c: Vector2, s: float, icon: String) -> void:
	var r := s * 0.5
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.3 + Vector2(0, 2), Vector2(r, r) * 2.6), false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
	ci.draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.94))
	ci.draw_arc(c, r - UIKit.px(0.5), 0, TAU, 64, UITokens.HAIRLINE, UIKit.line_px(1.0), true)
	var isz := r * 1.15
	Icons.line(ci, icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), UITokens.INK)


func _center_text(ci: CanvasItem, txt: String, cx: float, y: float, fs: int, col: Color, max_w: float) -> void:
	var f := UIKit.font_w("medium")
	while fs > 16 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, Vector2(cx - tw * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## The animated layer (Legendary+ only, redrawn per frame): the signature glint on the gem mark
## now and then. v3: no light travels around the frame (no looping shine).
func draw_fx(ci: CanvasItem) -> void:
	var r := str(card.get("rarity", "C"))
	if card.is_empty() or _locked() != "" or not r in ["L", "M"]:
		return
	var w := size.x
	if r in ["L", "M"]:
		var k := fposmod(_t, 4.0)
		if k < 0.6:
			var a := sin(k / 0.6 * PI)
			var mc := Vector2(_gem._cham() + clampf(w * 0.15, 18.0, 40.0) * 0.5 + 2.0, _gem._cham() + clampf(w * 0.15, 18.0, 40.0) * 0.5 + 2.0)
			GemDraw.draw_glint(ci, mc + Vector2(-4, -4), 18.0 * a + 4.0, Color(1, 1, 1, 0.9 * a))


## Splits `name` into 1-2 lines that fit `max_w` at `fs` (word wrap; ellipsis last).
static func _name_lines(name: String, f: Font, fs: int, max_w: float) -> PackedStringArray:
	if f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return PackedStringArray([name])
	var words := name.split(" ")
	if words.size() >= 2:
		var best := -1
		for i in range(1, words.size()):
			var a := " ".join(words.slice(0, i))
			var b := " ".join(words.slice(i))
			if f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w and f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
				best = i
		if best > 0:
			return PackedStringArray([" ".join(words.slice(0, best)), " ".join(words.slice(best))])
	var cut := name
	while cut.length() > 2 and f.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		cut = cut.substr(0, cut.length() - 1)
	return PackedStringArray([cut + "…"])


class _Baked extends Control:
	var mc: MachineCard

	func _draw() -> void:
		draw_texture_rect(mc._vp.get_texture(), Rect2(Vector2.ZERO, size), false)


class _Fx extends Control:
	var mc: MachineCard

	func _draw() -> void:
		mc.draw_fx(self)


class _Art extends Control:
	var mc: MachineCard

	func _draw() -> void:
		mc.draw_art(self)


class _Over extends Control:
	var mc: MachineCard

	func _draw() -> void:
		mc.draw_over(self)


# ------------------------------------------------------------------ shared helpers (legacy API)

## A box with a vertical gradient (top colour over the upper ~half, blended into `bot`), drawn
## on any CanvasItem. v2: chamfered (45-degree cuts, `rad` capped at 12) instead of rounded.
static func grad_box(ci: CanvasItem, r: Rect2, top: Color, bot: Color, rad: int) -> void:
	var pts := GemDraw.chamfer_rect(r, minf(float(mini(rad, 12)), minf(r.size.x, r.size.y) * 0.4))
	var cols := PackedColorArray()
	var h := maxf(r.size.y, 1.0)
	for p in pts:
		var t := clampf((p.y - r.position.y) / h, 0.0, 1.0)
		cols.append(top.lerp(bot, smoothstep(0.3, 0.8, t)))
	ci.draw_polygon(pts, cols)


static func _perimeter(r: Rect2, d: float) -> Vector2:
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.end - Vector2(d, 0)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)
