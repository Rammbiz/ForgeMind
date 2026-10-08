class_name ResultFlow
extends CanvasLayer
## The result flow after a WIN (arsenal_design.md §7.3), over the run's last frame (the stairs
## and the fallen fortress keep playing behind a scrim). Everything shown comes from the bundle
## Meta.finish_run() returned - the run was booked and SAVED once before this node exists.
##   1  coin odometer rolls victory + pickups (<= 1.0 s)
##   2  the stairs stamp "×3.2" slams (back easing + THUD) and the odometer rolls to the total
##   3  stats stagger 80 ms: survivors, Crowns 1-3 with pops (a new best glows)
##   5  rewards fly: coins into the coin chip (HubTopBar.HubChip), blueprint drip into the
##      machines' bars and blueprints to the Arsenal chip
##   5a NEW machine walkout (Walkout; unskippable the first time per machine)
##   6  Stone Cache inline reveal (InlineReveal, <= 2.5 s) or "-> Сховище"; World Cache:
##      "Відкрити на вівтарі" (signal altar) / "Пізніше"
##   7  Best-upgrade row (signal upgrade) + "Далі" (signal next)
## "Далі" is live from 0.5 s at every step: before step 7 it lands everything at once and
## skips to step 7 (Meta.note_skip("result")); at step 7 it leaves. Android back = "Далі".
## The static builders (scrim, ribbon, coin chip, drip strip, best-upgrade row) are shared
## with LossScreen.

signal next
signal altar(vault_index: int)
signal upgrade(id: String)

const TAP_FROM := 0.5

var bundle: Dictionary = {}
var result: Dictionary = {}
var step := 0
var root: Control

var _t := 0.0
var _ins := Vector4.ZERO
var _ins0 := Vector4.ZERO      ## safe insets without the tall-phone band (top bar)
var _vp := Vector2(720, 1280)
var _events: Array = []
var _clock := 0.0
var _odo: Odometer
var _coin_block: Control
var _stamp: Control
var _stats: Control
var _crowns: Array[Control] = []
var _crown_row: HBoxContainer
var _sheet: KitSheet
var _next_soft: Button
var _drip: HBoxContainer
var _cache_box: Control
var _inline: InlineReveal
var _best: Control
var _next_btn: KitCTA
var _chip: HubTopBar.HubChip
var _bp_chip: Control
var _walk: Walkout
var _walk_pending := false
var _walk_done := false
var _flown := false
var _final := false
var _left := false
var _altar_open := false


## `p_bundle` = Meta.finish_run(run.result); `p_result` = run.result (survivors, stairs mult).
func setup(p_bundle: Dictionary, p_result: Dictionary) -> void:
	bundle = p_bundle
	result = p_result


## Layout (y below the safe top; the sheet runs to the bottom edge, tall phones grow the gap
## above "Далі", never the chrome).
const TITLE_Y := 100.0
const SHEET_Y := 362.0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_vp = root.get_viewport_rect().size
	_ins = UIKit.safe_insets(root.get_viewport())
	_ins0 = _ins
	# Tall phones: the scene band above the sheet grows (half the extra height); the top bar
	# stays put and the sheet's chrome keeps its size.
	_ins.y += tall_band(_vp, _ins)
	root.add_child(scrim(_vp, 0.45, 0.62))
	# Victory light: a warm pool and slow soft rays behind the title (juicy, never loud).
	var pool := TextureRect.new()
	pool.texture = UIKit.glow_texture()
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.size = Vector2(_vp.x * 1.3, 420)
	pool.position = Vector2(-_vp.x * 0.15, _ins.y + TITLE_Y + 50 - 210)
	pool.modulate = Color(1.0, 0.78, 0.42, 0.0)
	root.add_child(pool)
	pool.create_tween().tween_property(pool, "modulate:a", 0.42, 0.6)
	var rays := UIKit.Rays.new()
	rays.color = Color(1.0, 0.86, 0.55, 0.0)
	rays.inner = 0.1
	rays.gem = "topaz"
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.size = Vector2(_vp.x * 1.5, _vp.x * 1.5)
	rays.position = Vector2(_vp.x * 0.5, _ins.y + TITLE_Y + 50) - rays.size * 0.5
	root.add_child(rays)
	rays.create_tween().tween_property(rays, "color:a", 0.16, 0.8)
	_build_top()
	var rib := ribbon(Loc.t("VICTORY"), true, _vp.x)
	rib.position = Vector2(0, _ins.y + TITLE_Y)
	root.add_child(rib)
	# The reason sits on the amber band in deep amber ink (no gold-on-brown).
	var why := UIKit.label(Loc.t(str(result.get("reason", "FORTRESS_FALLS"))) if result.has("reason") else Loc.t("FORTRESS_FALLS"), 24, UITokens.NEW_INK, true)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.size = Vector2(_vp.x, 32)
	why.position = Vector2(0, _ins.y + TITLE_Y + 96)
	root.add_child(why)
	UIJuice.fade_in(why, 0.35)
	_build_crowns()
	_sheet = UIKit.sheet()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.position = Vector2(0, _ins.y + SHEET_Y)
	_sheet.size = Vector2(_vp.x, _vp.y - _ins.y - SHEET_Y + 24)
	root.add_child(_sheet)
	UIJuice.sheet_in(_sheet, 0.1)
	_build_coins()
	_build_stats()
	_build_drip()
	_cache_box = Control.new()
	_cache_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cache_box.position = Vector2(0, _ins.y + SHEET_Y + 318)
	_cache_box.size = Vector2(_vp.x, 470)
	root.add_child(_cache_box)
	_next_btn = UIKit.cta_button(Loc.t("NEXT"), "", Vector2(440, 96), 40)
	_next_btn.size = Vector2(440, 96)
	_next_btn.position = Vector2((_vp.x - 440) * 0.5, _vp.y - 124 - _ins.w)
	_next_btn.pressed.connect(_on_next)
	_next_btn.modulate.a = 0.0
	root.add_child(_next_btn)
	# While a World Cache offers its Altar, "Далі" steps back to a cream secondary (one amber
	# jewel per screen); "Пізніше" hands the jewel back.
	_next_soft = UIKit.secondary_button(Loc.t("NEXT"), "", Vector2(320, 76), 28)
	_next_soft.size = Vector2(320, 76)
	_next_soft.position = Vector2((_vp.x - 320) * 0.5, _next_btn.position.y + 10)
	_next_soft.pressed.connect(_on_next)
	_next_soft.visible = false
	root.add_child(_next_soft)
	Audio.play("victory", -2.0)
	UIJuice.haptic_pattern("win")
	_at(0.12, func(): UIKit.sparkles(root, Vector2(_vp.x * 0.5, _ins.y + TITLE_Y + 50), UIKit.GOLD_LIGHT, 40, 420.0))
	_at(TAP_FROM, func(): _next_btn.create_tween().tween_property(_next_btn, "modulate:a", 1.0, 0.2))
	_build_placeholders()
	_at(0.35, _step_odometer)


func _at(t: float, fn: Callable) -> void:
	_events.append([_clock + t, fn])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	_t += delta
	_clock += delta
	while not _events.is_empty() and float(_events[0][0]) <= _clock:
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()


## Cream wells where the rows will land (drip chips, the cache card, the best upgrade), laid
## out at once so the sheet never looks empty while the sequence plays.
func _build_placeholders() -> void:
	var ph := Control.new()
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.size = _vp
	var rects: Array[Rect2] = []
	var drip: Array = bundle.get("drip", [])
	if not drip.is_empty():
		rects.append(Rect2(Vector2(24, _ins.y + SHEET_Y + 244), Vector2(_vp.x - 48, 76)))
	if not (bundle.get("caches", []) as Array).is_empty():
		rects.append(Rect2(Vector2(UITokens.GUTTER, _ins.y + SHEET_Y + 332), Vector2(_vp.x - UITokens.GUTTER * 2.0, 252)))
	if not (bundle.get("best_upgrade", {}) as Dictionary).is_empty():
		rects.append(Rect2(Vector2(UITokens.GUTTER, _next_btn.position.y - 102), Vector2(_vp.x - UITokens.GUTTER * 2.0, 84)))
	ph.draw.connect(func():
		for r in rects:
			var pts := GemDraw.chamfer_rect(r, 10.0)
			ph.draw_colored_polygon(pts, Color(UITokens.PAPER_2.r, UITokens.PAPER_2.g, UITokens.PAPER_2.b, 0.55))
			GemDraw.outline(ph, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.35), 1.0))
	root.add_child(ph)
	root.move_child(ph, root.get_children().find(_sheet) + 1)
	ph.modulate.a = 0.0
	ph.create_tween().tween_property(ph, "modulate:a", 1.0, 0.3)


# ------------------------------------------------------------------ shared builders

## Full-screen scrim (v2, no blur): a warm translucent slate gradient from `top_a` to
## `bottom_a` plus a soft vignette, so the run's last frame (and its gate numbers) recedes
## behind the result while the world still reads as a world. Fades in.
static func scrim(vp: Vector2, top_a: float, bottom_a: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = vp
	# Neutral slate (#1E2433): the frozen run dims but is never tinted brown.
	var sl := UITokens.SCRIM
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(sl.r, sl.g, sl.b, top_a), Color(sl.r, sl.g, sl.b, lerpf(top_a, bottom_a, 0.5)),
			Color(sl.r * 0.85, sl.g * 0.85, sl.b * 0.85, bottom_a)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	holder.add_child(_tex_rect(gt, vp))
	var v := Gradient.new()
	v.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	v.colors = PackedColorArray([Color(sl.r, sl.g, sl.b, 0.0), Color(sl.r, sl.g, sl.b, 0.06), Color(sl.r * 0.7, sl.g * 0.7, sl.b * 0.7, 0.45)])
	var vt := GradientTexture2D.new()
	vt.gradient = v
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.42)
	vt.fill_to = Vector2(1.18, 1.05)
	vt.width = 128
	vt.height = 128
	holder.add_child(_tex_rect(vt, vp))
	holder.modulate.a = 0.0
	holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.3)
	return holder


## Extra px the title band takes on screens taller than 1280 canvas px (half the excess).
static func tall_band(vp: Vector2, ins: Vector4) -> float:
	return clampf((vp.y - ins.y - ins.w - 1280.0) * 0.5, 0.0, 200.0)


static func _tex_rect(t: Texture2D, vp: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = vp
	return tr


## The big result title on the scene, `w` wide: soft warm gradient type with no stroke (warm
## white into topaz for a win, warm white into cool porcelain for a loss), a soft slate
## shadow and halo, and a gold hairline with marquise terminals and a keystone under it.
## A win punches in (juicy); a loss settles in softly.
static func ribbon(text: String, won: bool, w: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(w, 104)
	if won:
		# §6.8 Result: a full-width amber band that wipes in from the centre and fades out at
		# both ends, gold hairlines with crystal keystones; the title sits on it.
		text = text.trim_suffix("!").to_upper()
		var band := _VictoryBand.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.size = Vector2(w, 168)
		band.position = Vector2(0, -26)
		holder.add_child(band)
		band.create_tween().tween_property(band, "reveal", 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fs := UIKit.fit_size(text, w - 80.0, 76 if won else 72, 44)
	var title: Label
	if won:
		title = UIKit.number(text, fs, false, UIKit.ON_SCENE)
		# A soft 0-offset slate glow (3 px), no offset shadow / extrude.
		title.add_theme_color_override("font_shadow_color", Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.42))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 0)
		title.add_theme_constant_override("shadow_outline_size", 6)
	else:
		title = UIKit.gradient_heading(text, fs, UIKit.ON_SCENE, Color("#E9EDF3"), Color("#B9C3D2"))
		UIKit.soft_shadow(title, fs, 1.4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(w, 96)
	title.position = Vector2(0, 0)
	holder.add_child(title)
	if not won:
		HudView._halo_behind(title, UIKit.font_w("extrabold").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 0.8)
	var line := _TitleLine.new()
	line.visible = not won
	line.won = won
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(minf(w - 120.0, 480.0), 16)
	line.position = Vector2((w - line.size.x) * 0.5, 100)
	holder.add_child(line)
	title.pivot_offset = title.size * 0.5
	title.modulate.a = 0.0
	line.modulate.a = 0.0
	var tw := title.create_tween()
	tw.tween_interval(0.1)
	if won and not UITokens.reduce_motion():
		title.scale = Vector2(1.35, 1.35)
		tw.tween_property(title, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(title, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		title.position.y = 14.0
		tw.tween_property(title, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(title, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var lt := line.create_tween()
	lt.tween_interval(0.3)
	lt.tween_property(line, "modulate:a", 1.0, 0.3)
	return holder


## Title label for a result Ribbon band (HudView's legacy panel): warm white on the amber band
## (win) or ink on the cool cream band (loss); soft shadow, no stroke.
static func ribbon_title(text: String, won: bool, size := 56) -> Label:
	var l: Label
	if won:
		l = UIKit.number(text, size, false, UIKit.CTA_TEXT)
		l.add_theme_color_override("font_shadow_color", Color(0.55, 0.27, 0.05, 0.45))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 6)
	else:
		l = UIKit.number(text, size, false, UIKit.INK)
	return l


## The porcelain level plate (top-left), as on the run HUD.
static func level_plate(level: int, ins: Vector4) -> Control:
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(16, 6)))
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.custom_minimum_size.y = 52
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(row)
	var mark := Icons.make("map", 28.0, UIKit.GOLD_TEXT)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var l := UIKit.label(Loc.f("LEVEL", [level]), 24, UIKit.INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	lp.position = Vector2(22 + ins.x, ins.y + 20)
	lp.size = lp.get_combined_minimum_size()
	return lp


## The coin chip of the hub top bar, standing at `balance`, placed top-right.
static func coin_chip(parent: Control, balance: int, ins: Vector4, vp: Vector2) -> HubTopBar.HubChip:
	var ch := HubTopBar.HubChip.new("coins")
	parent.add_child(ch)
	ch.set_amount(balance, false)
	ch.size = ch.custom_minimum_size
	ch.position = Vector2(vp.x - ch.size.x - 22 - ins.z, ins.y + 20)
	return ch


## A row of drip chips (one per machine the run fed): render on its gem square, name, the bar
## filling from bp_before to bp_after (+ a gold badge when upgradable). Call `fill()` on each.
static func drip_strip(rows: Array, w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size = Vector2(w, 84)
	for r in rows:
		if not r is Dictionary or str((r as Dictionary).get("id", "")) == "":
			continue
		var c := DripChip.new()
		c.data = r
		c.custom_minimum_size = Vector2(minf(312.0, (w - 8.0) / maxf(rows.size(), 1) - 12.0), 76)
		hb.add_child(c)
	return hb


## The Best-upgrade row (§7.3 step 7): a cream plate - the machine on its gem square, "Найкраще
## покращення" (engraved caps) over "<name> · Рів. N", the cost in gold text and a chevron. Quiet
## on purpose: "Далі" stays the one amber jewel. Tap calls `on_tap(id)`. Hidden when nothing is
## affordable.
static func best_row(best: Dictionary, w: float, on_tap: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("plate", Vector2(14, 8)))
	p.custom_minimum_size = Vector2(w, 84)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if best.is_empty():
		p.visible = false
		return p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var kind := str(best.get("kind", "machine"))
	var id := str(best.get("id", ""))
	var medal := GemThumb.new()
	medal.id = id if kind == "machine" else ""
	medal.icon = id if kind == "machine" else ("helmet" if kind == "hero" else "fortress")
	medal.custom_minimum_size = Vector2(64, 64)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.section(Loc.t("BEST_UPGRADE"), 18))
	var lv := int(best.get("to_lvl", 0))
	var txt := Loc.t(str(best.get("label", "")))
	if lv > 0:
		txt += " · " + Loc.f("LV", [lv])
	var nm := UIKit.label(txt, UIKit.fit_size(txt, w - 330.0, 26, 18), UIKit.INK, true)
	v.add_child(nm)
	row.add_child(v)
	var cost := HBoxContainer.new()
	cost.add_theme_constant_override("separation", 6)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := Icons.make("coin", 34.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.add_child(coin)
	var cl := UIKit.number(Loc.num(int(best.get("cost", 0))), 28, false, UIKit.GOLD_TEXT)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.add_child(cl)
	var chev := Icons.make("chevron", 28.0, UIKit.GOLD_TEXT)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.add_child(chev)
	row.add_child(cost)
	p.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			on_tap.call(id))
	UIJuice.press(p)
	return p


# ------------------------------------------------------------------ build

func _build_top() -> void:
	var coins := bundle.get("coins", {}) as Dictionary
	var gain := 0 if bool(bundle.get("duplicate", false)) else int(coins.get("total", 0)) + _inline_coins()
	_chip = coin_chip(root, int(bundle.get("coins_balance", Meta.currency("coins"))) - gain, _ins0, _vp)
	# Blueprint chip: where the blueprints fly (the parchment icon and the run's count, as on
	# the Arsenal), shown only when the run dripped blueprints.
	var bp := 0
	for r in bundle.get("drip", []):
		bp += int((r as Dictionary).get("bp_after", 0)) - int((r as Dictionary).get("bp_before", 0))
	var bpt := "+%d" % bp
	var bw := 64.0 + UIKit.font_w("extrabold").get_string_size(bpt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_bp_chip = Control.new()
	_bp_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bp_chip.size = Vector2(bw, 56)
	_bp_chip.position = Vector2(_chip.position.x - bw - 12, _chip.position.y + (_chip.size.y - 56) * 0.5)
	_bp_chip.draw.connect(func():
		_bp_chip.draw_style_box(UIKit.lux("plate"), Rect2(Vector2(2, 4), Vector2(bw - 4, 48)))
		Icons.draw_icon(_bp_chip, "blueprint", Rect2(Vector2(8, 8), Vector2(40, 40)))
		_bp_chip.draw_string(UIKit.font_w("extrabold"), Vector2(52, 37), bpt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.INK))
	_bp_chip.visible = bp > 0
	root.add_child(_bp_chip)
	root.add_child(level_plate(int(bundle.get("level", result.get("level", 1))), _ins0))


func _inline_coins() -> int:
	var n := 0
	for c in bundle.get("caches", []):
		if bool((c as Dictionary).get("inline", false)):
			n += int(((c as Dictionary).get("reveal", {}) as Dictionary).get("coins", 0))
	return n


func _build_coins() -> void:
	_coin_block = Control.new()
	_coin_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_block.size = Vector2(_vp.x, 130)
	_coin_block.position = Vector2(0, _ins.y + SHEET_Y + 26)
	root.add_child(_coin_block)
	var glow := TextureRect.new()
	glow.texture = UIKit.glow_texture()
	glow.modulate = Color(1.0, 0.8, 0.42, 0.34)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(440, 150)
	glow.position = Vector2((_vp.x - 440) * 0.5 - 30, -20)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_block.add_child(glow)
	var cap := UIKit.section(Loc.t("RF_EARNED"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(_vp.x, 26)
	cap.position = Vector2(0, 0)
	_coin_block.add_child(cap)
	var coin := Icons.make("coin", 72.0)
	coin.position = Vector2(_vp.x * 0.5 - 178, 34)
	_coin_block.add_child(coin)
	_odo = Odometer.new()
	_odo.font_size = 84
	_odo.color = UIKit.INK
	_odo.align = HORIZONTAL_ALIGNMENT_LEFT
	_odo.position = Vector2(_vp.x * 0.5 - 94, 26)
	_odo.size = Vector2(300, 96)
	_odo.set_value(0, false)
	_odo.clip_contents = true
	_coin_block.add_child(_odo)
	var coins := bundle.get("coins", {}) as Dictionary
	var parts := UIKit.label("%s %s  ·  %s %s" % [Loc.t("COINS_BASE"), Loc.num(int(coins.get("victory", 0))), Loc.t("COINS_COLLECTED"), Loc.num(int(coins.get("pickups", 0)))], 20, UIKit.INK_DIM)
	parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts.size = Vector2(_vp.x, 28)
	parts.position = Vector2(0, 122)
	parts.modulate.a = 0.0
	parts.name = "Parts"
	_coin_block.add_child(parts)
	_stamp = Stamp.new()
	_stamp.text = Loc.t("STAIRS_MULT") % HudView._fmt_mult(float(coins.get("stairs_mult", result.get("mult", 1.0))))
	_stamp.size = Vector2(132, 76)
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.position = Vector2(_vp.x - 172 - _ins.z, 36)
	_stamp.rotation = 0.0
	_stamp.visible = false
	_coin_block.add_child(_stamp)


## Crowns 1-3 as topaz gem marks on the scene under the title (a new best glows).
func _build_crowns() -> void:
	var cr := bundle.get("crowns", {}) as Dictionary
	var got := int(cr.get("run", result.get("crowns", 1)))
	var gained := int(cr.get("gained", 0))
	_crown_row = HBoxContainer.new()
	_crown_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crown_row.add_theme_constant_override("separation", 22)
	_crown_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_row.size = Vector2(_vp.x, 96)
	_crown_row.position = Vector2(0, _ins.y + TITLE_Y + 156)
	root.add_child(_crown_row)
	for i in 3:
		var c := CrownSlot.new()
		c.on = i < got
		c.fresh = i >= got - gained and i < got
		c.big = i == 1
		c.custom_minimum_size = Vector2(92, 92) if i == 1 else Vector2(76, 76)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.modulate.a = 0.0
		_crown_row.add_child(c)
		_crowns.append(c)


## Survivors: a list row on the sheet (soldier icon, label, value).
func _build_stats() -> void:
	_stats = Control.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.position = Vector2(UITokens.GUTTER + 20, _ins.y + SHEET_Y + 172)
	_stats.size = Vector2(_vp.x - (UITokens.GUTTER + 20) * 2.0, 56)
	root.add_child(_stats)
	var surv := UIKit.list_row(Loc.t("RESULT_SURVIVORS").replace(": %d", "").replace(":%d", ""), Loc.num(int(result.get("survivors", 0))), "soldier")
	surv.size = _stats.size
	surv.custom_minimum_size = Vector2(_stats.size.x, 56)
	surv.modulate.a = 0.0
	_stats.add_child(surv)


func _build_drip() -> void:
	var rows: Array = bundle.get("drip", [])
	_drip = drip_strip(rows, _vp.x - 48.0)
	_drip.position = Vector2(24, _ins.y + SHEET_Y + 240)
	_drip.modulate.a = 0.0
	root.add_child(_drip)


# ------------------------------------------------------------------ steps

func _step_odometer() -> void:
	step = 1
	var coins := bundle.get("coins", {}) as Dictionary
	var mult := float(coins.get("stairs_mult", 1.0))
	var base := int(coins.get("victory", 0)) + int(coins.get("pickups", 0))
	# Without a stairs stamp (or on a replay) the odometer goes straight to the paid total.
	_odo.set_value(base if mult > 1.0 else int(coins.get("total", base)), true, 0.85)
	_tick_coins(0.85, 9)
	var parts := _coin_block.get_node("Parts") as Control
	parts.create_tween().tween_property(parts, "modulate:a", 1.0, 0.3)
	_at(0.95, _step_stamp if mult > 1.0 else _step_stats)


func _tick_coins(dur: float, n: int) -> void:
	for i in n:
		_at(dur * float(i) / n, func(): Audio.note(mini(2 + i, 14), -16.0))


func _step_stamp() -> void:
	step = 2
	var coins := bundle.get("coins", {}) as Dictionary
	_stamp.visible = true
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(2.4, 2.4)
	var tw := _stamp.create_tween()
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_at(0.22, func():
		Audio.play("stairs_top", -3.0)
		UIJuice.haptic("THUD", 1.0)
		UIKit.sparkles(root, _coin_block.position + _stamp.position + _stamp.size * 0.5, UIKit.GOLD_LIGHT, 26, 260.0)
		UIJuice.punch(_odo, 1.12, 0.25)
		_odo.set_value(int(coins.get("total", 0)), true, 0.4))
	_at(0.6, _step_stats)


func _step_stats() -> void:
	step = 3
	var i := 0
	var seq: Array = []
	seq.append_array(_crowns)
	seq.append(_stats.get_child(0))
	for n: Control in seq:
		var c := n
		_at(i * UITokens.STAGGER + i * 0.01, func():
			c.modulate.a = 1.0
			if c is CrownSlot and (c as CrownSlot).on:
				# Crowns stamp in (2x -> 1x, back easing); a new best adds a thud and glints.
				c.pivot_offset = c.size * 0.5
				c.scale = Vector2(1.9, 1.9)
				c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Audio.note(7 + _crowns.find(c) * 2, -9.0)
				if (c as CrownSlot).fresh:
					UIJuice.haptic("THUD", 0.6)
					UIKit.sparkles(root, c.get_global_rect().get_center(), UIKit.GOLD_LIGHT, 14, 120.0)
			else:
				UIJuice.pop(c, 0.0, 0.28, 0.5))
		i += 1
	_at(0.1 + i * 0.08, _step_rewards)


func _step_rewards() -> void:
	step = 5
	_fly_rewards()
	_drip.create_tween().tween_property(_drip, "modulate:a", 1.0, 0.25)
	var k := 0
	for c in _drip.get_children():
		var dc := c as DripChip
		_at(0.25 + k * 0.1, dc.fill)
		k += 1
	_at(0.75 + k * 0.1, _step_walkout)


func _fly_rewards() -> void:
	if _flown or bool(bundle.get("duplicate", false)):
		_flown = true
		return
	_flown = true
	var total := int((bundle.get("coins", {}) as Dictionary).get("total", 0))
	if total > 0:
		_chip.expect_fly()
		_chip.set_amount(_chip_target(), false)
		RewardFly.layer(get_tree()).fly(_odo.get_global_rect().get_center(), "coins", total, _chip)
	var bp := 0
	for r in bundle.get("drip", []):
		bp += int((r as Dictionary).get("bp_after", 0)) - int((r as Dictionary).get("bp_before", 0))
	if bp > 0:
		RewardFly.layer(get_tree()).fly(_drip.get_global_rect().get_center(), "bp", bp, _bp_chip, 1)


## Coin balance after the coins already shown (the inline Cache bonus flies later).
func _chip_target() -> int:
	return int(bundle.get("coins_balance", Meta.currency("coins"))) - (_inline_coins() if _inline == null or not _inline.finished else 0)


func _step_walkout() -> void:
	var nu := str(bundle.get("new_unlock", ""))
	if nu == "" or _walk_done:
		_step_cache()
		return
	step = 4
	_walk_pending = true
	_walk = Walkout.new()
	_walk.setup(nu, bool(bundle.get("walkout", false)))
	root.add_child(_walk)
	_walk.done.connect(func():
		_walk = null
		_walk_pending = false
		_walk_done = true
		if _final:
			step = 7                # "Далі" during the walkout: without this the next tap was a no-op
			_show_final()
		else:
			_step_cache())


func _step_cache() -> void:
	step = 6
	var caches: Array = bundle.get("caches", [])
	if caches.is_empty():
		_step_final()
		return
	var cd: Dictionary = caches[0]
	var type := str(cd.get("type", "stone"))
	if bool(cd.get("inline", false)):
		_inline = InlineReveal.new()
		_inline.setup(cd.get("reveal", {}))
		_inline.compact = true
		_inline.position = Vector2(36, 30)
		_inline.size = Vector2(_vp.x - 72, 470)
		_cache_box.add_child(_inline)
		_inline.done.connect(_on_inline_done)
		# The reveal is tall: "Далі" steps aside while it plays (no overlap with its coin line).
		_next_btn.create_tween().tween_property(_next_btn, "modulate:a", 0.0, 0.15)
		_next_btn.disabled = true
		var title := UIKit.label(Loc.f("CACHE_EARNED", [Loc.t(str((EconData.CACHES[type] as Dictionary)["name"]))]), 26, UIKit.INK, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(_vp.x, 34)
		title.position = Vector2(0, 0)
		_cache_box.add_child(title)
		UIJuice.fade_in(title)
	else:
		_cache_box.add_child(_cache_card(type, int(cd.get("vault_index", -1))))
		_at(0.6, _step_final)


func _on_inline_done() -> void:
	var coins := int(_inline.rev.get("coins", 0))
	if coins > 0 and not bool(bundle.get("duplicate", false)):
		_chip.expect_fly()
		_chip.set_amount(int(bundle.get("coins_balance", Meta.currency("coins"))), false)
		RewardFly.layer(get_tree()).fly(_inline.coins_point(), "coins", coins, _chip)
	_at(0.3, _step_final)


## Gem of a Cache type (its guaranteed rarity): stone sapphire, world amethyst, royal topaz.
static func cache_gem(type: String) -> String:
	match type:
		"stone": return "sapphire"
		"world": return "amethyst"
		"royal": return "topaz"
		"xray": return "opal"
	return "sapphire"


## A World Cache (or a Stone Cache sent to the Vault): a cream card with the breathing egg on
## its gem-ground card at the left, the name, the guarantee and the Altar / Later buttons
## (World), or the "У сховище" chip (Stone).
func _cache_card(type: String, vault_index: int) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(_vp.x, 280)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(0, 0)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(UITokens.GUTTER, 14)
	card.size = Vector2(_vp.x - UITokens.GUTTER * 2.0, 252)
	box.add_child(card)
	var gem := UIKit.gem_card(cache_gem(type), Vector2(196, 228))
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.footer_ratio = 0.0
	gem.position = Vector2(UITokens.GUTTER + 12, 26)
	gem.size = Vector2(196, 228)
	box.add_child(gem)
	var egg := EggView.new(type)
	egg.position = Vector2(-12, -2)
	egg.size = Vector2(220, 220)
	gem.content.add_child(egg)
	egg.present()
	var x0 := UITokens.GUTTER + 230.0
	var cw := _vp.x - x0 - UITokens.GUTTER - 18.0
	var nm := Loc.t(str((EconData.CACHES[type] as Dictionary)["name"]))
	var t := UIKit.label(nm, UIKit.fit_size(nm, cw, 32, 22), UIKit.INK, true)
	t.position = Vector2(x0, 36)
	t.size = Vector2(cw, 40)
	box.add_child(t)
	var g := str((EconData.CACHES[type] as Dictionary).get("guaranteed", ""))
	if g != "" and ArsenalData.RARITIES.has(g):
		var gl := UIKit.label(Loc.f("ODDS_GUARANTEED", [Loc.t(str((ArsenalData.RARITIES[g] as Dictionary)["name"]))]), 19, UIKit.INK_DIM)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.position = Vector2(x0, 80)
		gl.size = Vector2(cw, 50)
		box.add_child(gl)
	UIJuice.soft_in(card, Vector2(0, 16))
	UIJuice.pop(gem, 0.08, UITokens.ENTER, 0.8)
	if type == "stone":
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UIKit.lux("chip", Vector2(16, 8)))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(Icons.make("vault", 36.0))
		var rl := UIKit.label(Loc.t("RF_TO_VAULT"), 24, UIKit.INK, true)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.size_flags_vertical = Control.SIZE_FILL
		r.add_child(rl)
		pill.add_child(r)
		pill.position = Vector2(x0, 170)
		box.add_child(pill)
		UIJuice.pop(pill, 0.3)
		return box
	var open := UIKit.cta_button(Loc.t("OPEN_ON_ALTAR"), "", Vector2(cw, 80), 26)
	open.topaz = cw >= 300.0
	open.position = Vector2(x0, 138)
	open.size = Vector2(cw, 80)
	open.pressed.connect(func():
		if _left:
			return
		_left = true
		_land_all()
		altar.emit(vault_index))
	box.add_child(open)
	var later := UIKit.text_button(Loc.t("LATER"), Vector2(cw, 72), 22)
	later.position = Vector2(x0, 210)
	later.size = Vector2(cw, 72)
	later.pressed.connect(func():
		open.disabled = true
		later.visible = false
		var tw := open.create_tween()
		tw.tween_property(open, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): open.visible = false)
		var note := UIKit.label(Loc.t("RF_IN_VAULT"), 22, UIKit.INK_DIM, true)
		note.position = Vector2(x0, 160)
		note.size = Vector2(cw, 34)
		box.add_child(note)
		UIJuice.fade_in(note)
		_altar_open = false
		_sync_next())
	box.add_child(later)
	_altar_open = true
	UIJuice.pop(open, 0.2)
	UIJuice.fade_in(later, 0.3)
	return box


## "Далі" is the amber jewel unless the Altar button is up (then a cream secondary).
func _sync_next() -> void:
	if _next_btn == null or _next_soft == null:
		return
	var loud := not _altar_open or step < 7
	if _next_btn.visible == loud:
		return
	_next_btn.visible = loud
	_next_soft.visible = not loud
	if not loud:
		UIJuice.fade_in(_next_soft, 0.0, 0.2)
	else:
		UIJuice.pop(_next_btn, 0.0)


func _step_final() -> void:
	if step >= 7:
		return
	step = 7
	_show_final()


func _show_final() -> void:
	if _best != null:
		return
	if _inline:
		_inline.collapse()
	_best = best_row(bundle.get("best_upgrade", {}), _vp.x - UITokens.GUTTER * 2.0, func(id: String):
		if _left or id == "":
			return
		_left = true
		_land_all()
		upgrade.emit(id))
	_best.position = Vector2(UITokens.GUTTER, _next_btn.position.y - 102)
	_best.size = Vector2(_vp.x - UITokens.GUTTER * 2.0, 84)
	root.add_child(_best)
	if _best.visible:
		UIJuice.soft_in(_best, Vector2(0, 16))
	_next_btn.modulate.a = 1.0
	_next_btn.disabled = false
	_sync_next()
	if _next_btn.visible:
		UIJuice.pop(_next_btn, 0.05)


# ------------------------------------------------------------------ skip / leave

func _on_next() -> void:
	if _t < TAP_FROM or _left:
		return
	if step >= 7 and _walk == null:
		_leave()
		return
	skip_to_final()


## "Далі" before step 7: everything lands at once, the flow jumps to step 7. A first-time
## walkout still plays (unskippable once).
func skip_to_final() -> void:
	if _final:
		return
	_final = true
	Meta.note_skip("result")
	_events.clear()
	var coins := bundle.get("coins", {}) as Dictionary
	_odo.set_value(int(coins.get("total", 0)), false)
	(_coin_block.get_node("Parts") as Control).modulate.a = 1.0
	if float(coins.get("stairs_mult", 1.0)) > 1.0:
		_stamp.visible = true
		_stamp.modulate.a = 1.0
		_stamp.scale = Vector2.ONE
	(_stats.get_child(0) as Control).modulate.a = 1.0
	for c in _crowns:
		c.modulate.a = 1.0
	_drip.modulate.a = 1.0
	for c in _drip.get_children():
		(c as DripChip).fill()
	_fly_rewards()
	RewardFly.layer(get_tree()).land_all()
	if _inline:
		_inline.skip()
	elif step < 6 and not bundle.get("caches", []).is_empty():
		var cd: Dictionary = (bundle.get("caches", []) as Array)[0]
		if bool(cd.get("inline", false)):
			_step_cache()
			_inline.skip()
		else:
			_step_cache()
	var nu := str(bundle.get("new_unlock", ""))
	if nu != "" and not _walk_done and _walk == null and bool(bundle.get("walkout", false)):
		_step_walkout()
		return
	step = 7
	_show_final()


func _land_all() -> void:
	RewardFly.layer(get_tree()).land_all()


func _leave() -> void:
	if _left:
		return
	_left = true
	_land_all()
	next.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and _walk == null:
		_on_next()


# ------------------------------------------------------------------ widgets

## The stairs multiplier stamp: an amber chamfered seal (the CTA jewel's colours, a fine rim
## and an inner light line) with "×3.2" in warm white - no stroke, a soft amber shadow.
class Stamp extends Control:
	var text := "×2"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(UIKit.glow_texture(), r.grow(26), false, Color(1.0, 0.76, 0.32, 0.45))
		var pts := GemDraw.chamfer_rect(r, 12.0)
		for i in 4:
			var sp := PackedVector2Array()
			for p in pts:
				sp.append(p + Vector2(0, 2.0 + i * 1.5))
			draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.07))
		var cols := PackedColorArray()
		for p in pts:
			var k := p.y / maxf(size.y, 1.0)
			cols.append(UITokens.CTA_HI.lerp(UITokens.CTA, minf(k * 1.6, 1.0)).lerp(UITokens.CTA_LO, maxf(k - 0.55, 0.0) * 2.0))
		draw_polygon(pts, cols)
		GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(-4.0), 9.0), Color(1.0, 0.95, 0.8, 0.75), 1.2)
		GemDraw.outline(self, pts, UITokens.CTA_RIM, 1.5)
		var f := UIKit.font_w("extrabold")
		var fs := 48
		while fs > 26 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 22.0:
			fs -= 2
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36)
		draw_string(f, p + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.64, 0.5))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.CTA_TEXT)


## One Crown of the 3 as a gold gem mark: a topaz star-cut gem in its gold bezel (won), or
## the empty engraved bezel; a new best breathes a warm glow and a glint.
class CrownSlot extends Control:
	var on := false
	var fresh := false
	var big := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if fresh and on:
			_t = fmod(_t + delta, 100.0)
			queue_redraw()

	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.66
		var c := size * 0.5 + Vector2(0, s * 0.14)
		var bez := GemDraw.chamfer_rect(Rect2(c - Vector2(s * 0.42, s * 0.52), Vector2(s * 0.84, s * 1.04)), s * 0.24)
		var crown := Rect2(c + Vector2(-s * 0.36, -s * 1.08), Vector2(s * 0.72, s * 0.72))
		if on:
			var k := 0.5 + 0.18 * sin(_t * 3.0) if fresh else 0.3
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(s, s) * 1.3, Vector2(s, s) * 2.6), false, Color(1.0, 0.8, 0.38, k))
			var sh := PackedVector2Array()
			for p in bez:
				sh.append(p + Vector2(0, 2.5))
			draw_colored_polygon(sh, Color(0.2, 0.12, 0.04, 0.3))
			draw_colored_polygon(bez, UITokens.HAIRLINE)
			GemDraw.outline(self, bez, Color(0.45, 0.32, 0.12, 0.7), 1.2)
			GemDraw.draw_gem(self, "cushion", c, s * 0.82, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"))
			Icons.draw_icon(self, "crown", crown)
			if fresh:
				var g := 0.5 + 0.5 * sin(_t * 2.2)
				GemDraw.draw_glint(self, c + Vector2(-s * 0.16, -s * 0.2), s * 0.55 * g, Color(1, 1, 1, 0.9 * g))
		else:
			draw_colored_polygon(bez, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.1))
			GemDraw.outline(self, bez, Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.55), 1.5)
			Icons.draw_icon(self, "crown", crown, Color(1, 1, 1, 0.22))


## A machine on its rarity's gem ground (a small chamfered square: gradient, light pool, the
## render or painted icon, inner rim + gold hairline). `id` "" draws `icon` on a topaz ground.
class GemThumb extends Control:
	var id := "":
		set(v):
			id = v
			_tex = null
			_fetch()
	var icon := ""
	var _tex: Texture2D
	var _wired := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fetch()

	func _fetch() -> void:
		if id == "" or not is_inside_tree():
			return
		_tex = MachineThumbs.get_thumb(self, id, false)
		if _tex == null and not _wired and DisplayServer.get_name() != "headless":
			_wired = true
			MachineThumbs.service(get_tree()).rendered.connect(func(key: String, tex: Texture2D):
				if is_instance_valid(self) and key == MachineThumbs.key_of(id, false):
					_tex = tex
					queue_redraw())
		queue_redraw()

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var r := Rect2((size - Vector2(side, side)) * 0.5 + Vector2(1, 1), Vector2(side - 2, side - 2))
		var ch := clampf(side * 0.12, 5.0, 9.0)
		var pts := GemDraw.chamfer_rect(r, ch)
		var gk := HudView._gem_of(id) if id != "" else "topaz"
		var g: Dictionary = UITokens.gem(gk)
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, (p.y - r.position.y) / maxf(r.size.y, 1.0)))
		draw_polygon(pts, cols)
		var lc: Color = g["light"]
		draw_texture_rect(UIKit.glow_texture(), r.grow(-side * 0.05), false, Color(lc.r, lc.g, lc.b, 0.3))
		if _tex:
			var s := side * 1.55
			draw_texture_rect(_tex, Rect2(r.get_center() - Vector2(s, s) * 0.5 + Vector2(0, 3), Vector2(s, s)), false)
		else:
			var k := icon if icon != "" else id
			Icons.draw_icon(self, k, r.grow(-side * 0.14))
		var rim: Color = g["rim"]
		GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(-2.5), ch - 1.0), Color(rim.r, rim.g, rim.b, 0.7), 1.0)
		GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)


## One machine's run drip: a cream chip with the machine on its gem square, the name and the
## blueprint bar (cream track, amber fill) counting bp_before -> bp_after; a gold notify badge
## when the machine became upgradable.
class DripChip extends Control:
	var data: Dictionary = {}
	var k := 0.0
	var _thumb: GemThumb
	var _badge: KitSocket

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb = GemThumb.new()
		_thumb.position = Vector2(8, (size.y - 60) * 0.5)
		_thumb.size = Vector2(60, 60)
		add_child(_thumb)
		_thumb.id = str(data.get("id", ""))
		_badge = UIKit.notify_badge("!", 24.0)
		_badge.size = Vector2(24, 24)
		_badge.position = Vector2(size.x - 18, -8)
		_badge.visible = bool(data.get("upgradable", false)) and k >= 1.0
		add_child(_badge)
		resized.connect(func():
			_thumb.position = Vector2(8, (size.y - 60) * 0.5)
			_badge.position = Vector2(size.x - 18, -8))

	func fill() -> void:
		if k >= 1.0:
			return
		var tw := create_tween()
		tw.tween_method(func(v: float):
			k = v
			queue_redraw(), k, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if bool(data.get("upgradable", false)):
				Audio.note(12, -10.0)
				if _badge:
					_badge.visible = true
					UIJuice.pop(_badge, 0.0, 0.3, 0.4)
				UIJuice.punch(self, 1.06, 0.2))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UIKit.lux("plate"), r)
		var id := str(data.get("id", ""))
		var f := UIKit.font_w("bold")
		var fm := UIKit.font_w("medium")
		var x0 := 80.0
		var nm := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else id
		var fs := UIKit.fit_size(nm, size.x - x0 - 12.0, 20, 18)
		draw_string(f, Vector2(x0, 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK)
		var need := maxi(int(data.get("bp_need", 1)), 1)
		var before := float(data.get("bp_before", 0)) + 0.0
		var after := float(data.get("bp_after", before)) + float(data.get("frac", 0.0)) * (1.0 if k >= 1.0 else k)
		var shown := lerpf(before, after, k)
		var br := Rect2(Vector2(x0, 40), Vector2(size.x - x0 - 14.0, 10))
		var tp := GemDraw.chamfer_rect(br, 3.0)
		draw_colored_polygon(tp, UITokens.PAPER_3)
		var fk := clampf(shown / need, 0.0, 1.0)
		if fk > 0.0:
			var fr := Rect2(br.position, Vector2(maxf(br.size.x * fk, 6.0), br.size.y))
			var fp := GemDraw.chamfer_rect(fr, 3.0)
			var cols := PackedColorArray()
			for p in fp:
				cols.append(UITokens.CTA_HI.lerp(UITokens.CTA, (p.y - fr.position.y) / maxf(fr.size.y, 1.0)))
			draw_polygon(fp, cols)
		GemDraw.outline(self, tp, UITokens.HAIRLINE, 1.0)
		var bt := "%d / %d" % [int(floor(shown + 0.001)), need]
		draw_string(fm, Vector2(x0, size.y - 9.0), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.INK_DIM)
		var gain := int(data.get("bp_after", 0)) - int(data.get("bp_before", 0))
		if gain > 0:
			var gt := "+%d" % gain
			var gw := f.get_string_size(gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f, Vector2(size.x - 14.0 - gw, size.y - 9.0), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.GOLD_TEXT)


## The gold hairline under a result title: marquise terminals, a crystal keystone, fading ends.
class _TitleLine extends Control:
	var won := true

	func _draw() -> void:
		var y := size.y * 0.5
		var col := UITokens.GOLD_HI if won else Color(0.86, 0.88, 0.92, 0.85)
		GemDraw.draw_hairline(self, Vector2(0, y), Vector2(size.x, y), col, 1.5, true, true)


## The victory band (§6.8): an amber band across the width whose alpha fades to 0 over the
## outer 18 % at each side, 1.5 px gold hairlines top and bottom with crystal keystones; it
## wipes in from the centre (`reveal` 0..1).
class _VictoryBand extends Control:
	var reveal := 0.0:
		set(v):
			reveal = v
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var half := w * 0.5 * reveal
		var x0 := w * 0.5 - half
		var x1 := w * 0.5 + half
		if half < 2.0:
			return
		var xs := [x0, lerpf(x0, x1, 0.18), lerpf(x0, x1, 0.82), x1]
		var ax := [0.0, 1.0, 1.0, 0.0]
		var ys := [10.0, h * 0.5, h - 10.0]
		var cs := [Color("#F7C46A"), Color("#EFA445"), Color("#D98632")]
		var a := 0.94
		for j in 2:
			for i in 3:
				var c00: Color = cs[j]
				var c10: Color = cs[j + 1]
				draw_polygon(PackedVector2Array([Vector2(xs[i], ys[j]), Vector2(xs[i + 1], ys[j]), Vector2(xs[i + 1], ys[j + 1]), Vector2(xs[i], ys[j + 1])]),
						PackedColorArray([Color(c00, a * ax[i]), Color(c00, a * ax[i + 1]), Color(c10, a * ax[i + 1]), Color(c10, a * ax[i])]))
		# Soft light across the top third.
		draw_polygon(PackedVector2Array([Vector2(xs[1], ys[0]), Vector2(xs[2], ys[0]), Vector2(xs[2], h * 0.36), Vector2(xs[1], h * 0.36)]),
				PackedColorArray([Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		var gl := UITokens.GOLD_HI
		for y: float in [6.0, h - 6.0]:
			for i in 3:
				draw_polygon(PackedVector2Array([Vector2(xs[i], y - 0.75), Vector2(xs[i + 1], y - 0.75), Vector2(xs[i + 1], y + 0.75), Vector2(xs[i], y + 0.75)]),
						PackedColorArray([Color(gl, ax[i]), Color(gl, ax[i + 1]), Color(gl, ax[i + 1]), Color(gl, ax[i])]))
		for x: float in [xs[1], xs[2]]:
			for y: float in [6.0, h - 6.0]:
				GemDraw.draw_keystone(self, Vector2(x, y), 14.0, reveal, Color(1.0, 0.92, 0.7))
		GemDraw.draw_keystone(self, Vector2(w * 0.5, h - 6.0), 20.0, reveal, Color(1.0, 0.92, 0.7))
