class_name MachineCard
extends Control
## A machine card of the Arsenal grid (arsenal_design.md §7.1-7.2, card data §6.2): three
## layers - a backdrop lit in the family accent, the machine render (MachineThumbs; the vector
## icon until it is ready), then frame and FX. Rarity frame (Epic+ animated), Prestige frames
## from Lv13, rarity pips, family glyph, Lead crown, Deck ribbon, Focus mark, level pill and the
## blueprint bar (green when the upgrade is affordable). Badges per §7.4: green arrow (Deck
## machine or Best upgrade affordable) or gold "!" (talent pick). Unowned: a dark silhouette
## and "Світ 1, рівень 5"; Meta-2 machines: the family glyph and "Скоро".

signal pressed(id: String)

const SIZE := Vector2(214, 292)

var card: Dictionary = {}
var compact := false            ## deck editor list: no blueprint bar
var selected := false
var _tex: Texture2D
var _t := 0.0
var _press := false


func _init(p_card := {}) -> void:
	card = p_card
	custom_minimum_size = SIZE
	# PASS: a drag over the card still scrolls the grid; a tap without movement selects.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_t = randf() * 10.0


func _ready() -> void:
	UIJuice.press(self, true)
	_load_thumb()


func set_card(c: Dictionary) -> void:
	card = c
	_load_thumb()
	queue_redraw()


func _id() -> String:
	return str(card.get("id", ""))


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


func _on_rendered(key: String, tex: Texture2D) -> void:
	if key == MachineThumbs.key_of(_id(), int(card.get("lvl", 0)) >= ArsenalData.ASCENSION_LEVEL):
		_tex = tex
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var r := str(card.get("rarity", "C"))
	if str(card.get("badge", "")) != "" or r in ["E", "L", "M"] or selected:
		queue_redraw()


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


func _draw() -> void:
	if card.is_empty():
		return
	var f := UIKit.font(true)
	var r := str(card.get("rarity", "C"))
	var rc := UITokens.rarity(r)
	var fam := str(card.get("family", "kinetic"))
	var fc := UITokens.family(fam)
	var locked := str(card.get("locked", ""))
	var lvl := int(card.get("lvl", 0))
	var body := Rect2(Vector2(4, 10), size - Vector2(8, 16))
	var rad := 24
	# Shadow
	draw_style_box(UIKit.box(Color(0, 0, 0.03, 0.5), Color(0, 0, 0, 0), rad + 2, 0, 0, Vector2.ZERO), Rect2(body.position + Vector2(0, 6), body.size))
	if selected:
		draw_texture_rect(UIKit.glow_texture(), body.grow(26), false, Color(1.0, 0.8, 0.35, 0.55))
	# Frame: rarity metal (prestige frames override), darker for locked cards.
	var frame_hi := rc.lightened(0.35)
	var frame_lo := rc.darkened(0.45)
	match str(card.get("frame", "")):
		"bronze":
			frame_hi = Color(1.0, 0.75, 0.5)
			frame_lo = Color(0.5, 0.26, 0.1)
		"silver":
			frame_hi = Color(1.0, 1.0, 1.0)
			frame_lo = Color(0.48, 0.52, 0.62)
		"gold":
			frame_hi = Color(1.0, 0.96, 0.7)
			frame_lo = Color(0.78, 0.46, 0.08)
	if locked != "":
		frame_hi = frame_hi.lerp(Color(0.35, 0.38, 0.48), 0.65)
		frame_lo = frame_lo.lerp(Color(0.1, 0.11, 0.16), 0.65)
	_grad_box(body, frame_hi, frame_lo, rad)
	var inner := body.grow(-5)
	# Backdrop: family-lit render zone over deep navy.
	var split := inner.position.y + inner.size.y * (0.62 if not compact else 0.7)
	var zone := Rect2(inner.position, Vector2(inner.size.x, split - inner.position.y))
	var top_c := fc.darkened(0.45) if locked == "" else Color(0.08, 0.09, 0.14)
	var bot_c := Color(0.04, 0.05, 0.12)
	_grad_box(inner, top_c, bot_c, rad - 4)
	if locked == "":
		draw_texture_rect(UIKit.glow_texture(), Rect2(zone.get_center() - Vector2(zone.size.x, zone.size.y) * 0.62, zone.size * 1.24), false, Color(fc.r, fc.g, fc.b, 0.55))
		if r in ["E", "L", "M"]:
			_rays(zone.get_center(), zone.size.x * 0.62, Color(rc.r, rc.g, rc.b, 0.22))
		draw_texture_rect(UIKit.glow_texture(), Rect2(zone.get_center() + Vector2(-zone.size.x * 0.4, zone.size.y * 0.22), Vector2(zone.size.x * 0.8, zone.size.y * 0.3)), false, Color(0, 0, 0.02, 0.6))
	# Render (or icon / silhouette).
	var ir := Rect2(zone.position + Vector2(8, 16), zone.size - Vector2(16, 18))
	var sq := minf(ir.size.x, ir.size.y)
	ir = Rect2(ir.get_center() - Vector2(sq, sq) * 0.5, Vector2(sq, sq))
	if locked == "phase":
		Icons.draw_icon(self, "fam_" + fam, ir.grow(-sq * 0.2), Color(0.25, 0.27, 0.36, 0.9))
	elif _tex:
		var mod := Color.WHITE if locked == "" else Color(0.0, 0.0, 0.02, 0.92)
		draw_texture_rect(_tex, ir.grow(sq * 0.12), false, mod)
		if locked != "":
			draw_texture_rect(_tex, Rect2(ir.grow(sq * 0.12).position + Vector2(0, -2), ir.grow(sq * 0.12).size), false, Color(0.4, 0.5, 0.8, 0.18))
	else:
		Icons.draw_icon(self, _id(), ir.grow(-sq * 0.12), Color.WHITE if locked == "" else Color(0.05, 0.05, 0.1, 0.95))
	# Plate
	var plate := Rect2(Vector2(inner.position.x, split), Vector2(inner.size.x, inner.end.y - split))
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2)), Color(frame_hi.r, frame_hi.g, frame_hi.b, 0.55))
	# Name
	var name := Loc.t(str(card.get("name", "")))
	var fs := UIKit.fit_size(name, plate.size.x - 16, 22, 15)
	var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ny := plate.position.y + 26
	var ncol := Color(1, 1, 1) if locked == "" else Color(0.6, 0.62, 0.7)
	draw_string_outline(f, Vector2(plate.get_center().x - tw * 0.5, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.01, 0.02, 0.06))
	draw_string(f, Vector2(plate.get_center().x - tw * 0.5, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ncol)
	if locked == "world":
		var home := int(card.get("home_level", 0))
		var txt := Loc.f("LOCKED_WORLD", [ArsenalData.world_of(home), ArsenalData.level_in_world(home)]) if home > 0 else Loc.t("LOCKED_SOON")
		_small_center(txt, plate.get_center().x, ny + 30, 17, Color(0.7, 0.75, 0.9))
		_lock(ir.get_center())
	elif locked == "phase":
		_small_center(Loc.t("LOCKED_SOON"), plate.get_center().x, ny + 30, 18, Color(0.62, 0.66, 0.82))
	else:
		_level_row(plate, ny + 10, lvl)
	# Corner marks: rarity pips, family glyph, Lead crown, Deck ribbon, Focus.
	for i in int(card.get("pips", 1)):
		var pc := inner.position + Vector2(14 + i * 15, 16)
		var dm := PackedVector2Array([pc + Vector2(0, -7), pc + Vector2(6, 0), pc + Vector2(0, 7), pc + Vector2(-6, 0)])
		draw_colored_polygon(dm, Color(0, 0, 0.04, 0.7))
		var dm2 := PackedVector2Array([pc + Vector2(0, -5.5), pc + Vector2(4.5, 0), pc + Vector2(0, 5.5), pc + Vector2(-4.5, 0)])
		draw_colored_polygon(dm2, rc if locked == "" else rc.darkened(0.5))
	var gc := Vector2(inner.end.x - 22, zone.end.y - 22)
	draw_circle(gc, 17, Color(0.02, 0.03, 0.08, 0.8))
	Icons.draw_icon(self, "fam_" + fam, Rect2(gc - Vector2(13, 13), Vector2(26, 26)), Color.WHITE if locked == "" else Color(0.5, 0.5, 0.6))
	if bool(card.get("in_deck", false)) and locked == "":
		var rb := Rect2(Vector2(body.position.x - 2, zone.end.y - 30), Vector2(56, 24))
		draw_colored_polygon(PackedVector2Array([rb.position, rb.position + Vector2(rb.size.x, 0), rb.position + Vector2(rb.size.x - 10, rb.size.y * 0.5), rb.position + Vector2(rb.size.x, rb.size.y), rb.position + Vector2(0, rb.size.y)]), Color(1.0, 0.76, 0.28))
		Icons.draw_icon(self, "deck", Rect2(rb.position + Vector2(10, 1), Vector2(22, 22)), Color(1, 1, 1))
	if bool(card.get("is_lead", false)):
		var bob := sin(fmod(_t, 100.0) * 2.0) * 1.5
		Icons.draw_icon(self, "crown", Rect2(Vector2(size.x * 0.5 - 22, -10 + bob), Vector2(44, 44)))
	if bool(card.get("is_focus", false)):
		var fp := inner.position + Vector2(18, 44)
		draw_circle(fp, 14, Color(0.02, 0.03, 0.08, 0.8))
		Icons.draw_icon(self, "focus", Rect2(fp - Vector2(11, 11), Vector2(22, 22)))
	# Epic+ animated frame: a light running around the border.
	if r in ["E", "L", "M"] and locked == "":
		var per := 2.0 * (body.size.x + body.size.y)
		var d := fposmod(_t * 160.0, per)
		var p := _perimeter(body, d)
		draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, 0.75))
		draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(40, 40), Vector2(80, 80)), false, Color(rc.r, rc.g, rc.b, 0.4))
	# Badge
	var badge := str(card.get("badge", ""))
	if badge != "" and locked == "":
		var bc := Vector2(size.x - 14, 14 + sin(fmod(_t, 100.0) * 4.0) * 3.0)
		draw_circle(bc + Vector2(0, 3), 19, Color(0, 0, 0, 0.45))
		if badge == "arrow":
			draw_circle(bc, 19, Color(0.05, 0.32, 0.08))
			draw_circle(bc, 16.5, Color(0.36, 0.88, 0.34))
			Icons.draw_icon(self, "arrow_up", Rect2(bc - Vector2(13, 14), Vector2(26, 26)))
		else:
			draw_circle(bc, 19, Color(0.5, 0.25, 0.02))
			draw_circle(bc, 16.5, Color(1.0, 0.8, 0.25))
			draw_string(f, bc + Vector2(-5, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.32, 0.12, 0.0))


func _level_row(plate: Rect2, y: float, lvl: int) -> void:
	var f := UIKit.font(true)
	var lv_txt := str(lvl)
	var maxed := lvl >= ArsenalData.MAX_LEVEL
	# Level gem
	var lc := Vector2(plate.position.x + 26, y + 22)
	draw_circle(lc + Vector2(0, 2), 19, Color(0, 0, 0.03, 0.6))
	draw_circle(lc, 19, Color(0.55, 0.36, 0.1))
	draw_circle(lc + Vector2(0, -1), 17, Color(1.0, 0.86, 0.45))
	draw_circle(lc, 14.5, Color(0.1, 0.13, 0.3))
	var lw := f.get_string_size(lv_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(f, lc + Vector2(-lw * 0.5, 7), lv_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
	if compact:
		return
	# Blueprint bar
	var bar := Rect2(Vector2(lc.x + 22, y + 10), Vector2(plate.end.x - lc.x - 32, 24))
	draw_style_box(UIKit.box(Color(0.01, 0.015, 0.04, 0.95), Color(1, 1, 1, 0.12), 10, 1, 0, Vector2.ZERO), bar)
	var need := int(card.get("bp_need", 0))
	var have := int(card.get("bp", 0))
	var wild := int(card.get("wild", 0))
	var can := bool(card.get("can_upgrade", false))
	var k := 1.0 if maxed else clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0)
	var fill := Rect2(bar.position + Vector2(2, 2), Vector2(maxf((bar.size.x - 4) * k, 0.0), bar.size.y - 4))
	if fill.size.x > 4:
		var c1 := Color(0.45, 0.95, 0.4) if can else (Color(1.0, 0.78, 0.3) if have >= need or maxed else Color(0.3, 0.62, 1.0))
		_grad_box(fill, c1.lightened(0.25), c1.darkened(0.2), 8)
		draw_rect(Rect2(fill.position + Vector2(3, 2), Vector2(fill.size.x - 6, 4)), Color(1, 1, 1, 0.3))
	if not maxed and wild > 0 and have < need:
		var wk := clampf(float(have + wild) / float(maxi(need, 1)), 0.0, 1.0)
		if wk > k:
			draw_rect(Rect2(Vector2(fill.end.x, fill.position.y), Vector2((bar.size.x - 4) * (wk - k), fill.size.y)), Color(0.75, 0.5, 1.0, 0.4))
	var txt := Loc.t("LV_MAX") if maxed else "%d/%d" % [have, need]
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var tp := Vector2(bar.get_center().x - tw * 0.5 + (6 if can else 0), bar.position.y + 18)
	draw_string_outline(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0.02, 0.06, 0.95))
	draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1))
	if can:
		Icons.draw_icon(self, "arrow_up", Rect2(Vector2(bar.position.x - 2, bar.position.y - 3), Vector2(28, 28)))
	else:
		Icons.draw_icon(self, "blueprint", Rect2(Vector2(bar.position.x - 6, bar.position.y - 4), Vector2(28, 28)))


func _small_center(txt: String, cx: float, y: float, fs: int, col: Color) -> void:
	var f := UIKit.font(true)
	fs = UIKit.fit_size(txt, size.x - 28, fs, 13)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, Vector2(cx - tw * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.01, 0.02, 0.06))
	draw_string(f, Vector2(cx - tw * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _lock(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3), 26, Color(0, 0, 0, 0.5))
	draw_circle(c, 26, Color(0.25, 0.27, 0.36))
	draw_circle(c, 23, Color(0.08, 0.09, 0.15))
	Icons.draw_icon(self, "lock", Rect2(c - Vector2(15, 16), Vector2(30, 30)), Color(0.85, 0.88, 1.0))


func _grad_box(r: Rect2, top: Color, bot: Color, rad: int) -> void:
	grad_box(self, r, top, bot, rad)


## A rounded box with a vertical gradient (top colour over the upper ~half, blended into
## `bot`), drawn on any CanvasItem.
static func grad_box(ci: CanvasItem, r: Rect2, top: Color, bot: Color, rad: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bot
	sb.set_corner_radius_all(rad)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
	var h := r.size.y
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = top
	sb2.set_corner_radius_all(mini(rad, int(h * 0.4)))
	sb2.corner_detail = 8
	sb2.anti_aliasing = true
	sb2.corner_radius_bottom_left = 0
	sb2.corner_radius_bottom_right = 0
	ci.draw_style_box(sb2, Rect2(r.position, Vector2(r.size.x, h * 0.4)))
	ci.draw_polygon(PackedVector2Array([r.position + Vector2(0, h * 0.4 - 0.5), r.position + Vector2(r.size.x, h * 0.4 - 0.5), r.position + Vector2(r.size.x, h * 0.75), r.position + Vector2(0, h * 0.75)]),
			PackedColorArray([top, top, Color(top.r, top.g, top.b, 0.0), Color(top.r, top.g, top.b, 0.0)]))


func _rays(c: Vector2, R: float, col: Color) -> void:
	var n := 10
	for i in n:
		var a := fmod(_t, 1000.0) * 0.12 + TAU * i / n
		var d0 := Vector2(cos(a - 0.08), sin(a - 0.08))
		var d1 := Vector2(cos(a + 0.08), sin(a + 0.08))
		draw_polygon(PackedVector2Array([c, c + d0 * R, c + d1 * R]), PackedColorArray([col, Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.0)]))


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
