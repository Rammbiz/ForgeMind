class_name KitCTA
extends Button
## The amber key action (UI v3.1, spec §7.6; graft of B's vector cut gem onto A): an elongated
## CUT-GEM body drawn as a vector polygon (45-degree cuts of clamp(h * 0.3, 10, 26), flat-lit
## amber in 3 stops, a 1 dpx table light under the top edge and ONE 1 dpx rim; no sheen, no
## streak, no brown drop: a soft warm glow underneath), at most BODY_MAX px tall and centred in
## its touch rect (the hit area keeps the full rect), a small VECTOR cushion topaz at the left
## end (no painted chip, no bezel slab), a deep amber-brown label (Bold, all caps tracked 8 %,
## capped at 38 px; never outlined or embossed) and an optional Medium second line. Press: 0.98
## for 70 ms, back in 160 ms with no overshoot, a flash on the topaz. Disabled: quiet glass with
## a 1 dpx hairline rim and an INK_DIM label. The light sweep plays once only, on the first show
## of ГРАТИ (0.16 strength). Only for key actions: ГРАТИ, Покращити, Відкрити, price buttons.
## Bitmap overrides: assets/ui/kit/primary*.png (then the painted body is used), cta_topaz.png.
## `text` / `icon` work like a normal Button (the Button's own text is hidden and redrawn);
## `gem_icon` = an Icons kind ("coin") drawn in place of the topaz (price buttons).
## CTA STUDY (owner: «жовті головні кнопки ... дуже віддає ШІ»): `KitCTA.style` picks the body
## (UITokens.CTA_STYLE, default "amber" = the shipped one above; galleries take --cta=<name>).
## The study styles share the metrics, cut, gem slot and touch rect, and have NO glow, NO sweep,
## NO gloss: "porcelain" (ivory enamel, 1.5 dpx gold rim + 1 dpx inner hairline, ink label,
## the context gem), "ink" (ink-navy enamel, 1 dpx gold rim, ivory label, gold-set gem),
## "sapphire" (translucent sapphire glass, 1 dpx pale-gold rim, one facet line, white label),
## "champagne" (muted champagne-gold, 1 dpx bronze rim, bronze-ink label).
## `ctx_gem` = the screen's gem (a GEMS key or rarity letter) for the small gem; "" = clear quartz.

var sub := "":
	set(v):
		sub = v
		queue_redraw()
var label_size := 40:
	set(v):
		label_size = v
		add_theme_font_size_override("font_size", v)
		queue_redraw()
var sub_size := 22
var topaz := true:
	set(v):
		topaz = v
		_apply_pad()
		queue_redraw()
var gem_icon := "":
	set(v):
		gem_icon = v
		queue_redraw()
var sweep := true
## Context gem of the screen (hero / recut target); "" = clear quartz. Study styles only.
var ctx_gem := "":
	set(v):
		ctx_gem = v
		queue_redraw()
## Dev galleries: draw the pressed state without a touch.
var preview_down := false:
	set(v):
		preview_down = v
		queue_redraw()
static var style: String = UITokens.CTA_STYLE
const BODY_MAX := 96.0
const MAX_BODY_H := BODY_MAX
const MAX_LABEL := 38
var _flash := 0.0
var _sweep_rect: ColorRect
var _sweep_mat: ShaderMaterial
var _painted := false
static var _swept_play := false
static var _caps_fonts := {}


func _init() -> void:
	theme_type_variation = "PrimaryButton"
	focus_mode = Control.FOCUS_NONE
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(k, Color(0, 0, 0, 0))
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		add_theme_color_override(k, Color(0, 0, 0, 0))
	add_theme_constant_override("outline_size", 0)
	add_theme_font_override("font", UIKit.font_w("bold"))
	# The owner's bitmap body (assets/ui/kit/primary.png) keeps the painted nine-patch (slimmed);
	# otherwise the body is the vector cut gem drawn in _draw().
	_painted = UIKit.kit_texture("primary") != null
	if not _painted:
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
	pressed.connect(func(): Audio.play("click", -4.0))
	button_down.connect(_down)
	button_up.connect(_up)


func _ready() -> void:
	_apply_pad()
	if _painted:
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var base := get_theme_stylebox(st)
			if base and not base is SlimBox:
				var sb := SlimBox.new()
				sb.inner = base
				add_theme_stylebox_override(st, sb)
	# A single soft sweep on the first show of ГРАТИ (never a loop: no shimmering toy).
	if sweep and style == "amber" and not _swept_play and not UITokens.reduce_motion() and text == Loc.t("PLAY").to_upper():
		_swept_play = true
		_sweep_rect = ColorRect.new()
		_sweep_rect.color = Color.WHITE
		_sweep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sweep_mat = ShaderMaterial.new()
		_sweep_mat.shader = load(UIKit.SHINE_SHADER_PATH) as Shader
		_sweep_mat.set_shader_parameter("strength", 0.16)
		_sweep_mat.set_shader_parameter("progress", -1.0)
		_sweep_rect.material = _sweep_mat
		add_child(_sweep_rect)
		resized.connect(_sync_sweep)
		_sync_sweep()
		var tw := _sweep_rect.create_tween()
		tw.tween_interval(0.9)
		tw.tween_method(func(v: float): _sweep_mat.set_shader_parameter("progress", v if not disabled else -1.0), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_sweep_rect.queue_free)


func _apply_pad() -> void:
	# Hidden Button text still sizes the control; keep room for the topaz on the left.
	if topaz and custom_minimum_size.x < 200.0:
		custom_minimum_size.x = 200.0


## The drawn body: never taller than BODY_MAX (the touch area keeps the full rect), centred.
func _body_rect() -> Rect2:
	var h := minf(size.y, BODY_MAX)
	return Rect2(Vector2(0, roundf((size.y - h) * 0.5)), Vector2(size.x, h))


## Height of the body (legacy name).
func _body_h() -> float:
	return minf(size.y, BODY_MAX)


## The cut: 45-degree corners of ~30 % of the body height (an elongated cut gem, never a pill).
func _cut(br: Rect2) -> float:
	return roundf(clampf(br.size.y * 0.3, 10.0, 26.0))


func _gem_size(br: Rect2) -> float:
	return clampf(br.size.y * 0.42, 24.0, 40.0)


func _gem_zone() -> float:
	if not topaz and gem_icon == "":
		return 0.0
	var br := _body_rect()
	return _gem_size(br) + _cut(br) + 10.0


func _sync_sweep() -> void:
	if _sweep_rect == null or not is_instance_valid(_sweep_rect):
		return
	var br := _body_rect()
	_sweep_rect.position = br.position
	_sweep_rect.size = br.size
	_sweep_mat.set_shader_parameter("rect_size", br.size)
	_sweep_mat.set_shader_parameter("chamfer", _cut(br))


func _down() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.98, 0.98), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash = 1.0
	set_process(true)
	UIJuice.haptic("CLICK", 0.6)


func _up() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()
	else:
		set_process(false)


static func _caps_font(fs: int) -> Font:
	if _caps_fonts.has(fs):
		return _caps_fonts[fs]
	var fv := FontVariation.new()
	fv.base_font = UIKit.font_w("bold")
	fv.spacing_glyph = maxi(1, int(round(fs * 0.08)))
	_caps_fonts[fs] = fv
	return fv


func _draw() -> void:
	var down := (is_pressed() or preview_down) and not disabled
	var dis := disabled
	var br := _body_rect()
	if down:
		br.position.y += 1.0
	var ch := _cut(br)
	var h := br.size.y
	if not _painted:
		_draw_body(br, ch, down, dis)
	var gem_w := _gem_zone()
	# A small vector cushion topaz at the left end (a jewel point, not a bezel slab), or the
	# price icon (a coin) in its place.
	if gem_w > 0.0:
		var gs := _gem_size(br)
		var gc := Vector2(br.position.x + ch + 4.0 + gs * 0.5, br.get_center().y - 1.0)
		if gem_icon != "":
			Icons.draw_icon(self, gem_icon, Rect2(gc - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), Color(1, 1, 1, 0.55 if dis else 1.0))
		elif style != "amber":
			_draw_ctx_gem(gc, gs, dis)
		else:
			var tex := UIKit.kit_texture("cta_topaz")
			if tex:
				var ts := Vector2(gs, gs) * Vector2(float(tex.get_width()) / maxf(1.0, float(tex.get_height())), 1.0)
				draw_texture_rect(tex, Rect2(gc - ts * 0.5, ts), false, Color(1, 1, 1, 0.55 if dis else 1.0))
			elif dis:
				GemDraw.draw_gem(self, "cushion", gc, gs, Color("#D9CDB8"), Color("#F2EDE4"), Color("#AFA28B"), false)
			else:
				# No white star glint (the toy sparkle §6.5 removed): facets + the lit table only.
				GemDraw.draw_gem(self, "cushion", gc, gs, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"), false)
		if _flash > 0.0 and style == "amber":
			var fr := gs * (0.9 + 0.8 * (1.0 - _flash))
			draw_texture_rect(UIKit.glow_texture(), Rect2(gc - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 0.95, 0.75, _flash * 0.8))
	# Label (+ optional icon and second line), centred in the area right of the gem.
	if text == "" and sub == "":
		return
	var fs := mini(label_size, MAX_LABEL)
	var caps := text == text.to_upper() and text != text.to_lower()
	var f: Font = _caps_font(fs) if caps else UIKit.font_w("bold")
	var area_x0 := gem_w + (6.0 if gem_w > 0.0 else ch + 6.0)
	var area_x1 := size.x - ch - 8.0
	var avail := area_x1 - area_x0
	var ico_w := 0.0
	if icon:
		ico_w = fs * 0.9 + 8.0
	while fs > 20 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + ico_w > avail:
		fs -= 1
		if caps:
			f = _caps_font(fs)
		ico_w = (fs * 0.9 + 8.0) if icon else 0.0
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := tw + ico_w
	var x := area_x0 + (avail - total) * 0.5
	var fsub := UIKit.font_w("medium")
	var has_sub := sub != ""
	var asc := f.get_ascent(fs)
	var desc := f.get_descent(fs)
	var line_h := asc + desc
	var ss := mini(sub_size, maxi(20, int(h * 0.24)))
	var sub_h := (fsub.get_ascent(ss) + fsub.get_descent(ss) - 2.0) if has_sub else 0.0
	var block := line_h * 0.86 + sub_h
	var top_y := br.position.y + (h - block) * 0.5 - 1.0
	var base_y := top_y + asc * 0.93
	var col: Color = UIKit.INK_DIM if dis else (UIKit.CTA_TEXT if style == "amber" else _spec()["label"])
	var sub_col: Color = UIKit.INK_DIM if dis else (UIKit.CTA_TEXT if style == "amber" else _spec()["sub"])
	if icon:
		var isz := fs * 0.9
		draw_texture_rect(icon, Rect2(Vector2(x, base_y - asc * 0.78), Vector2(isz, isz)), false, Color(1, 1, 1, 0.6 if dis else 1.0))
		x += ico_w
	draw_string(f, Vector2(roundf(x), roundf(base_y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if has_sub:
		var sw := fsub.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var sx := area_x0 + (avail - sw) * 0.5
		var sy := base_y + desc + fsub.get_ascent(ss) - 2.0
		draw_string(fsub, Vector2(roundf(sx), roundf(sy)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, sub_col)


## The vector cut-gem body: warm glow, 3-stop flat amber, the 1 dpx table light, the 1 dpx rim.
func _draw_body(br: Rect2, ch: float, down: bool, dis: bool) -> void:
	if style != "amber":
		_draw_study_body(br, ch, down, dis)
		return
	var pts := GemDraw.chamfer_rect(br, ch)
	var h := br.size.y
	if not dis:
		draw_texture_rect(UIKit.glow_texture(), Rect2(br.position + Vector2(-br.size.x * 0.06, h * 0.35), Vector2(br.size.x * 1.12, h * 0.9)), false,
				Color(0.6, 0.38, 0.15, 0.10 if down else 0.18))
	var top := Color("#FFD98A") if not down else Color("#F9C76A")
	var mid := UITokens.CTA if not down else Color("#EEA23E")
	var bot := Color("#E8963A") if not down else Color("#DC8A32")
	if dis:
		top = Color(0.988, 0.976, 0.949, 0.9)
		mid = Color(0.969, 0.949, 0.91, 0.89)
		bot = Color(0.925, 0.898, 0.847, 0.88)
	# Body as one polygon with the three stops (extra vertices on the side edges at 50 %).
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	var ym := br.position.y + h * 0.5
	for i in pts.size():
		var p := pts[i]
		poly.append(p)
		cols.append(_stop(p.y, br, top, mid, bot))
		if i == 2 or i == 6:
			# Right side (2 -> 3) and left side (6 -> 7) cross the middle stop.
			poly.append(Vector2(p.x, ym))
			cols.append(mid)
	draw_polygon(poly, cols)
	var w1 := UIKit.px(1.0)
	if not dis:
		# Table light: 1 dpx just inside the top edge and down the two upper cuts.
		var ty := GemDraw.pixel_y(self, br.position.y + w1 * 1.5)
		var k := w1 * 1.5
		draw_polyline(PackedVector2Array([Vector2(br.position.x + k, br.position.y + ch + k * 0.4), Vector2(br.position.x + ch + k * 0.4, ty),
				Vector2(br.end.x - ch - k * 0.4, ty), Vector2(br.end.x - k, br.position.y + ch + k * 0.4)]), Color(1, 0.98, 0.9, 0.9), w1, true)
	var rim := Color(UITokens.CTA_RIM.r, UITokens.CTA_RIM.g, UITokens.CTA_RIM.b, 0.7) if not dis else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8)
	GemDraw.outline(self, _inset(pts, w1 * 0.5), rim, UIKit.line_px(1.0))


## CTA study: the colours and lines of each study style (see the header).
const STUDY := {
	"porcelain": {"top": Color("#FAF5EC"), "mid": Color("#F7F1E6"), "bot": Color("#F1E9DA"),
			"ptop": Color("#EFE7D8"), "pmid": Color("#ECE3D2"), "pbot": Color("#E5DAC6"), "alpha": 1.0,
			"rim": Color(0.659, 0.514, 0.247, 0.95), "rim_w": 1.5, "inner": Color(0.788, 0.659, 0.416, 0.62),
			"label": Color("#2B2440"), "sub": Color("#4A4258"), "shadow": true, "facet": false,
			"gem_edge": Color(0.659, 0.514, 0.247, 0.9), "gem_scale": 0.78},
	"ink": {"top": Color("#272B50"), "mid": Color("#23274A"), "bot": Color("#1E2140"),
			"ptop": Color("#1F2343"), "pmid": Color("#1C2040"), "pbot": Color("#181B36"), "alpha": 1.0,
			"rim": Color(0.835, 0.706, 0.451, 0.95), "rim_w": 1.0, "inner": Color(0.835, 0.706, 0.451, 0.26),
			"label": Color("#F7F1E6"), "sub": Color("#D8D0BF"), "shadow": false, "facet": false,
			"gem_edge": Color(0.847, 0.722, 0.447, 1.0), "gem_scale": 0.8},
	"sapphire": {"top": Color("#2C55B8"), "mid": Color("#264AA5"), "bot": Color("#1F3C8F"),
			"ptop": Color("#24489F"), "pmid": Color("#203F92"), "pbot": Color("#1A3378"), "alpha": 0.88,
			"rim": Color(0.91, 0.84, 0.643, 0.92), "rim_w": 1.0, "inner": Color(0, 0, 0, 0),
			"label": Color("#FFFFFF"), "sub": Color("#DCE6FF"), "shadow": false, "facet": true,
			"gem_edge": Color(0.91, 0.84, 0.643, 0.95), "gem_scale": 0.8},
	"champagne": {"top": Color("#DDCDA7"), "mid": Color("#D8C79F"), "bot": Color("#C3AE7E"),
			"ptop": Color("#D0BF96"), "pmid": Color("#CAB88E"), "pbot": Color("#B5A06F"), "alpha": 1.0,
			"rim": Color(0.549, 0.416, 0.22, 0.9), "rim_w": 1.0, "inner": Color(0, 0, 0, 0),
			"label": Color("#3A2E1E"), "sub": Color("#4A3B26"), "shadow": true, "facet": false,
			"gem_edge": Color(0.549, 0.416, 0.22, 0.85), "gem_scale": 0.8},
}


static func _spec() -> Dictionary:
	return STUDY.get(style, STUDY["porcelain"])


## Study body: flat enamel / glass in a faint top-to-bottom step, a crisp 1-2 px contact shadow
## under the light bodies (never a glow), the rim, an optional inner hairline and facet line.
func _draw_study_body(br: Rect2, ch: float, down: bool, dis: bool) -> void:
	var sp := _spec()
	var pts := GemDraw.chamfer_rect(br, ch)
	var h := br.size.y
	var w1 := UIKit.px(1.0)
	if dis:
		var dt := Color(0.988, 0.976, 0.949, 0.9)
		var dm := Color(0.969, 0.949, 0.91, 0.89)
		var db := Color(0.925, 0.898, 0.847, 0.88)
		_fill(pts, br, dt, dm, db)
		GemDraw.outline(self, _inset(pts, w1 * 0.5), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8), UIKit.line_px(1.0))
		return
	if bool(sp["shadow"]) and not down:
		draw_colored_polygon(_shift(pts, Vector2(0, UIKit.px(2.0))), Color(0.12, 0.10, 0.16, 0.07))
		draw_colored_polygon(_shift(pts, Vector2(0, UIKit.px(1.0))), Color(0.12, 0.10, 0.16, 0.10))
	var a := float(sp["alpha"])
	var top: Color = sp["ptop"] if down else sp["top"]
	var mid: Color = sp["pmid"] if down else sp["mid"]
	var bot: Color = sp["pbot"] if down else sp["bot"]
	top.a = a
	mid.a = a
	bot.a = a
	_fill(pts, br, top, mid, bot)
	if bool(sp["facet"]):
		# One cut-crystal facet toward the right end: a slightly lighter plane behind a 1 dpx line.
		var xt := br.end.x - ch - h * 0.3
		var xb := xt - h * 0.6
		var plane := PackedVector2Array([Vector2(xt, br.position.y), Vector2(br.end.x - ch, br.position.y), Vector2(br.end.x, br.position.y + ch),
				Vector2(br.end.x, br.end.y - ch), Vector2(br.end.x - ch, br.end.y), Vector2(xb, br.end.y)])
		draw_colored_polygon(plane, Color(1, 1, 1, 0.05))
		draw_line(Vector2(xt, br.position.y + w1), Vector2(xb, br.end.y - w1), Color(1, 1, 1, 0.2), w1, true)
	var inner: Color = sp["inner"]
	if inner.a > 0.0:
		# 3 canvas px in, snapped to whole device px so the 1 dpx line stays crisp at 1080.
		var d := UIKit.px(roundf(3.0 * UIKit.ui_scale()))
		GemDraw.outline(self, GemDraw.chamfer_rect(br.grow(-d), maxf(2.0, ch - d * 0.4142)), inner, UIKit.line_px(1.0))
	var rw := UIKit.line_px(float(sp["rim_w"]))
	GemDraw.outline(self, _inset(pts, rw * 0.5), sp["rim"], rw)


## Study styles: the small left gem in the screen's gem colour (clear quartz when unknown; an ice
## crystal on sapphire glass), cut as the CTA cushion, no glint, set in a 1 dpx metal edge.
func _draw_ctx_gem(gc: Vector2, gs: float, dis: bool) -> void:
	var sp := _spec()
	var s := roundf(gs * float(sp["gem_scale"]))
	var base := Color("#A9B6C4")
	var light := Color("#F2F5F8")
	var deep := Color("#5C6672")
	if dis:
		base = Color("#D9CDB8")
		light = Color("#F2EDE4")
		deep = Color("#AFA28B")
	elif style == "sapphire":
		base = Color("#DCE7F4")
		light = Color("#FFFFFF")
		deep = Color("#7F97B8")
	elif ctx_gem != "":
		var key := UITokens.gem_of(ctx_gem)
		var g: Dictionary = UITokens.gem(key)
		light = g["light"]
		deep = g["deep"]
		base = g["rim"]
		if key == "quartz":
			base = Color("#A9B6C4")
		elif key == "opal":
			base = Color("#3A2D63")
	GemDraw.draw_gem(self, "cushion", gc, s, base, light, deep, false)
	var edge: Color = sp["gem_edge"] if not dis else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8)
	GemDraw.outline(self, GemDraw.cut_points("cushion", gc, s + UIKit.px(4.0)), edge, UIKit.line_px(1.0))


## The body polygon in three vertical stops (extra vertices where the side edges cross 50 %).
func _fill(pts: PackedVector2Array, br: Rect2, top: Color, mid: Color, bot: Color) -> void:
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	var ym := br.position.y + br.size.y * 0.5
	for i in pts.size():
		var p := pts[i]
		poly.append(p)
		cols.append(_stop(p.y, br, top, mid, bot))
		if i == 2 or i == 6:
			poly.append(Vector2(p.x, ym))
			cols.append(mid)
	draw_polygon(poly, cols)


static func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out


static func _stop(y: float, br: Rect2, top: Color, mid: Color, bot: Color) -> Color:
	var t := clampf((y - br.position.y) / maxf(br.size.y, 1.0), 0.0, 1.0)
	return top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bot, t * 2.0 - 1.0)


## The polygon pulled `d` px toward its centre (so the 1 px rim sits inside the body edge).
static func _inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= maxf(1.0, float(pts.size()))
	var out := PackedVector2Array()
	for p in pts:
		var v := c - p
		out.append(p + Vector2(signf(v.x), signf(v.y)) * d)
	return out


## Owner bitmap body: the painted CTA style at most BODY_MAX tall, centred in the button rect.
class SlimBox extends StyleBox:
	var inner: StyleBox

	func _draw(ci: RID, rect: Rect2) -> void:
		var h := minf(rect.size.y, BODY_MAX)
		inner.draw(ci, Rect2(Vector2(rect.position.x, rect.position.y + roundf((rect.size.y - h) * 0.5)), Vector2(rect.size.x, h)))

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return inner._get_draw_rect(rect) if inner.has_method("_get_draw_rect") else rect
