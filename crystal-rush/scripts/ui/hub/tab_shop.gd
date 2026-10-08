extends Control
## Магазин tab - Meta-1 placeholder (arsenal_design.md §6.6, §7.1; UI v2): the title and the
## promise (no timers, no energy, no paid random packs), the Vault as a wide amethyst-ground
## banner card with the waiting Caches' eggs and the one amber jewel «Відкрити», the odds and
## guarantees as a quiet cream row, and the coming products as sealed gem-ground cards
## (Самоцвіти · Образи героїв · Пропуск сезону) with a lock and «Скоро». Purchases arrive with
## WS6 (Meta-3).

const T := {
	"SHOP_GEMS": ["Самоцвіти", "Gems"],
	"SHOP_LOOKS": ["Образи героїв", "Hero looks"],
	"SHOP_PASS": ["Пропуск сезону", "Season pass"],
}
const BANNER := Vector2(672, 300)
const CARD := Vector2(216, 296)

var hub: Hub
var _vault_card: _VaultSlab
var _banner_host: Control
var _sc: ScrollContainer
var _col: VBoxContainer
var _fit_queued := false
var _vault_eggs: HBoxContainer
var _vault_count: Label
var _vault_btn: Button
var _vault_cta: KitCTA
var _pity_lbl: Label


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = T.get(key, [key, key])
	return str(row[0] if Loc.lang == "uk" else row[1])


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", UITokens.GUTTER)
	m.add_theme_constant_override("margin_right", UITokens.GUTTER)
	m.add_theme_constant_override("margin_bottom", 20)
	sc.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	m.add_child(col)
	# Tall phones: the title stays at the top like every tab; the extra height grows the Vault
	# banner (the art) and then opens the gaps a little (no empty bottom third, no floating title).
	_sc = sc
	_col = col
	sc.resized.connect(_queue_fit)
	col.minimum_size_changed.connect(_queue_fit)
	_queue_fit()
	# Title + promise
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.add_child(UIKit.gradient_heading(Loc.t("TAB_SHOP"), 40))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	var pi := Icons.make("check", 22.0, UIKit.PLUS)
	pi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(pi)
	var promise := UIKit.label(Loc.t("SHOP_PROMISE"), 22, UIKit.INK_DIM)
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	promise.custom_minimum_size.x = 400.0
	pr.add_child(promise)
	head.add_child(pr)
	col.add_child(head)
	# The Vault banner
	col.add_child(_vault_banner())
	# Odds row
	col.add_child(_odds_row())
	# Coming products and the no-random promise are notes, not cards: a framed row on this page
	# means "tap me", so they sit on a frameless 94 % cream row (lux "row", §4.3: no body text
	# straight on the veiled world), with the restore link anchored right under them (no empty band).
	var notes := PanelContainer.new()
	notes.add_theme_stylebox_override("panel", UIKit.lux("row", Vector2(8, 12)))
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 10)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_child(nv)
	var hl := UIKit.divider(560.0)
	hl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nv.add_child(hl)
	nv.add_child(_note("lock", Loc.t("SHOP_SOON_ROW"), UITokens.INK_DIM_GLASS))
	nv.add_child(_note("check", Loc.t("NO_RANDOM"), UITokens.GOLD_TEXT_GLASS))
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	var restore := UIKit.text_button(Loc.t("RESTORE"), Vector2(0, 72), 22)
	restore.disabled = true
	restore.add_theme_color_override("font_disabled_color", UITokens.INK_DIM_GLASS)
	rrow.add_child(restore)
	nv.add_child(rrow)
	col.add_child(notes)
	var cards: Array = [notes]
	refresh()
	UIJuice.soft_in(head, Vector2(0, 12))
	UIJuice.cards_in(cards, 0.12)


## §4.6: the frost behind a modal over the Shop leans toward the Vault's amethyst.
func page_tint() -> Color:
	return Color("#8F6FD0")


func on_show() -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var v := Meta.vault()
	_vault_count.text = Loc.f("VAULT_COUNT", [v.size()]) if not v.is_empty() else Loc.t("VAULT_EMPTY").split(".")[0]
	for c in _vault_eggs.get_children():
		_vault_eggs.remove_child(c)
		c.queue_free()
	var types: Array[String] = []
	for cd in v:
		types.append(str((cd as Dictionary).get("type", "stone")))
	if types.is_empty():
		types = ["stone"]
	for i in mini(types.size(), 3):
		var art := VaultView.CacheArt.new()
		art.type = types[i]
		art.custom_minimum_size = Vector2(190, 250)
		art.modulate = Color.WHITE if not v.is_empty() else Color(1, 1, 1, 0.5)
		_vault_eggs.add_child(art)
	if v.size() > 3:
		var more := UIKit.number("+%d" % (v.size() - 3), 30, true)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_vault_eggs.add_child(more)
	_vault_cta.visible = not v.is_empty()
	_vault_btn.visible = v.is_empty()
	var pl := Meta.pity_left()
	_pity_lbl.text = Loc.f("PITY_LEG", [pl]) if pl >= 0 else Loc.t("PITY_LEG_LOCKED")


## The Vault as a wide gem-ground banner: the eggs on the left, the amber «Відкрити» on the
## right (a cream «Відкрити» when the Vault is empty), the name and count on the cream footer.
func _vault_banner() -> Control:
	_vault_card = _VaultSlab.new()
	_vault_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -24
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vault_card.add_child(row)
	_vault_eggs = HBoxContainer.new()
	_vault_eggs.add_theme_constant_override("separation", -28)
	_vault_eggs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vault_eggs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_vault_eggs)
	var bcol := VBoxContainer.new()
	bcol.alignment = BoxContainer.ALIGNMENT_CENTER
	bcol.add_theme_constant_override("separation", 2)
	bcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bcol)
	# Warm white on the amethyst ground, no shadow (a hard text shadow reads as an outline).
	var vt := UIKit.label(Loc.t("VAULT"), 40, UIKit.ON_SCENE, true)
	vt.add_theme_font_override("font", UIKit.font_w("bold"))
	bcol.add_child(vt)
	# Lilac-white at 0.95 (>= 4.5:1 on the slab; the gold ink was 2.6:1 on purple).
	_vault_count = UIKit.label("", 22, Color("#F3E9FF", 0.95))
	_vault_count.add_theme_font_override("font", UIKit.font_w("medium"))
	bcol.add_child(_vault_count)
	bcol.add_child(UIKit.gap(8))
	_vault_cta = UIKit.cta_button(Loc.t("OPEN"), "", Vector2(250, 78), 30)
	_vault_cta.pressed.connect(func(): hub.open_vault())
	bcol.add_child(_vault_cta)
	_vault_btn = UIKit.button(Loc.t("OPEN"), false, 200.0)
	_vault_btn.custom_minimum_size.y = 68
	_vault_btn.pressed.connect(func(): hub.open_vault())
	bcol.add_child(_vault_btn)
	var host := Control.new()
	host.custom_minimum_size = BANNER
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(_vault_card)
	_banner_host = host
	return host


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit.call_deferred()


## Spare = page height - the content at its base size (banner 300, gaps 14): 60 % grows the
## Vault banner (max 180), the rest opens the gaps (max +26 each). Re-runs when the content's
## minimum changes (an autowrapped label reports a huge minimum before its first layout).
func _fit() -> void:
	_fit_queued = false
	if _banner_host == null or _sc.size.y <= 0.0:
		return
	var grown := _banner_host.custom_minimum_size.y - BANNER.y
	var gaps := maxf(_col.get_child_count() - 2, 1)
	var sep := _col.get_theme_constant("separation")
	var base_h := _col.get_combined_minimum_size().y - grown - (sep - 14) * gaps
	var extra := maxf(_sc.size.y - 20.0 - base_h, 0.0)
	var grow := minf(extra * 0.6, 180.0)
	_grow_banner(grow)
	(_col.get_parent() as Control).custom_minimum_size.y = _sc.size.y
	var want := int(14.0 + minf((extra - grow) / gaps, 26.0))
	if want != sep:
		_col.add_theme_constant_override("separation", want)


## Tall phones: the banner (host and the slab) grows by `extra` px.
func _grow_banner(extra: float) -> void:
	if _banner_host == null:
		return
	var sz := BANNER + Vector2(0, roundf(extra))
	if _banner_host.custom_minimum_size == sz:
		return
	_banner_host.custom_minimum_size = sz


## One quiet note line: a small line icon in a thin ring and an engraved caption (no panel).
func _note(icon: String, text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIKit.gap(6))
	var s := UIKit.socket(icon, 40.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var l := UIKit.label(text, 22, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 400.0
	row.add_child(l)
	return row


## The odds and guarantees entry: a quiet cream row (socket, title, the pity line, chevron).
func _odds_row() -> Control:
	# §9: list rows at the text alpha (GLASS_TEXT_A, lux "row").
	var p := UIKit.panel("row", Vector2(18, 12))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var s := UIKit.socket("odds", 56.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(Loc.t("ODDS_TITLE"), 24, UIKit.INK, true))
	_pity_lbl = UIKit.label("", 22, UIKit.INK_DIM)
	v.add_child(_pity_lbl)
	row.add_child(v)
	var ch := Icons.make("chevron", 28.0, UITokens.GOLD_TEXT_GLASS)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ch)
	p.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			Audio.play("click", -8.0)
			UIJuice.press(p, false)
			hub.open_odds("stone"))
	return p


## A sealed product: its painted icon big on a gem ground with a soft glow, a lock socket, the
## product name and «Скоро» on the cream footer.
func _soon_card(icon: String, gem: String, title: String) -> Control:
	var c := UIKit.gem_card(gem, CARD)
	c.footer_ratio = 0.25
	c.title = title
	c.footer = Loc.t("SOON")
	c.pips = -1
	var art := _SealedArt.new()
	art.icon = icon
	art.gem = gem
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.content.add_child(art)
	return VaultView.clipped(c, CARD)


class _SealedArt extends Control:
	var icon := "gem"
	var gem := "sapphire"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 6.0)
		var lc: Color = UITokens.gem(gem)["light"]
		var R := size.x * 0.48
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R), Vector2(R, R) * 2.0), false, Color(lc.r, lc.g, lc.b, 0.75))
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 0.5, Vector2(R, R)), false, Color(1, 1, 1, 0.35))
		var s := size.x * 0.5
		Icons.draw_icon(self, icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))
		GemDraw.draw_glint(self, c + Vector2(s * 0.34, -s * 0.36), 14.0)
		# Lock socket (sealed until the shop opens).
		var lc2 := Vector2(size.x - 26.0, 26.0)
		for i in 3:
			draw_circle(lc2 + Vector2(0, 1.5 + i), 16.0 + i, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))
		draw_circle(lc2, 16.0, UITokens.PAPER_0)
		draw_arc(lc2, 15.25, 0, TAU, 40, UITokens.HAIRLINE, 1.5, true)
		Icons.line(self, "lock", Rect2(lc2 - Vector2(10, 10), Vector2(20, 20)), UITokens.INK)


## The Vault banner (UI v3.1): an amethyst cut-stone slab, not a generic card grid. The gem's
## own vertical gradient, a soft vertical light column and a light pool behind the eggs, a 1 dpx
## light line inside the edge and the 1 dpx gold frame; every fill is cut to the same 45-degree
## chamfer polygon as the frame (no cream corner wedges). The gem mark sits top-left.
class _VaultSlab extends Control:
	const GEM := "amethyst"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _cham() -> float:
		return float(UITokens.CHAMFER_L)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pts := GemDraw.chamfer_rect(r, _cham())
		var g: Dictionary = UITokens.gem(GEM)
		var top: Color = (g["top"] as Color).lerp(g["bot"], 0.12)
		# The low end a little deeper than the gem's light bottom, so the warm-white title and
		# the lilac count keep >= 4.5:1 down the whole right column.
		var bot: Color = (g["bot"] as Color).lerp(g["top"], 0.3)
		var lc: Color = g["light"]
		# Two faint shadow layers.
		for i in 2:
			var o := Vector2(0, 2.0 + i * 2.4)
			var sp := PackedVector2Array()
			for p in pts:
				sp.append(p + o)
			draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))
		# Body: the gem's vertical gradient.
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, p.y / maxf(size.y, 1.0)))
		draw_polygon(pts, cols)
		# Soft vertical light column behind the eggs (peaks at x 30 %, fades to both sides and
		# toward the bottom), cut to the chamfer.
		var cx := size.x * 0.3
		var hw := size.x * 0.2
		var a_top := 0.26
		var a_bot := 0.06
		var lcol := func(p: Vector2) -> Color:
			var fx := 1.0 - clampf(absf(p.x - cx) / hw, 0.0, 1.0)
			var fy := lerpf(a_top, a_bot, clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0))
			return Color(lc.r, lc.g, lc.b, fx * fy)
		_fill_clipped(PackedVector2Array([Vector2(cx - hw, 0), Vector2(cx, 0), Vector2(cx, size.y), Vector2(cx - hw, size.y)]), pts, lcol)
		_fill_clipped(PackedVector2Array([Vector2(cx, 0), Vector2(cx + hw, 0), Vector2(cx + hw, size.y), Vector2(cx, size.y)]), pts, lcol)
		# Light pool behind the eggs and a faint lift behind the title column.
		var R := size.y * 0.55
		KitGemCard.glow_in(self, Rect2(Vector2(cx - R, size.y * 0.52 - R), Vector2(R, R) * 2.0), r.grow(-_cham()), Color(lc.r, lc.g, lc.b, 0.30))
		# A 1 dpx light line inside the edge (bright on top, fading down the sides).
		var ins := GemDraw.chamfer_rect(r.grow(-UIKit.px(1.5)), maxf(_cham() - 0.6, 1.0))
		var loop := ins.duplicate()
		loop.append(ins[0])
		var lcs := PackedColorArray()
		for p in loop:
			var k := clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
			lcs.append(Color(1.0, 0.97, 1.0, lerpf(0.55, 0.12, k)))
		draw_polyline_colors(loop, lcs, UIKit.px(1.0), true)
		# The 1 dpx gold frame on the same polygon.
		GemDraw.outline(self, pts, UITokens.HAIRLINE, UIKit.line_px(1.0))
		# Gem-cut mark top-left.
		var ms := 30.0
		GemDraw.draw_mark(self, GEM, Vector2(_cham() + ms * 0.5 + 6.0, _cham() + ms * 0.5 + 6.0), ms)

	## Draws `band` cut to `shape` (convex), each vertex coloured by `fn` (linear within a band).
	func _fill_clipped(band: PackedVector2Array, shape: PackedVector2Array, fn: Callable) -> void:
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(band, shape):
			if poly.size() < 3:
				continue
			var cs := PackedColorArray()
			for p in poly:
				cs.append(fn.call(p))
			draw_polygon(poly, cs)
