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
var _vault_card: KitGemCard
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
	var promise := UIKit.label(Loc.t("SHOP_PROMISE"), 19, UIKit.INK_SOFT)
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
	# means "tap me", so these sit as quiet engraved lines under a hairline.
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 10)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl := UIKit.divider(560.0)
	hl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notes.add_child(hl)
	notes.add_child(_note("lock", Loc.t("SHOP_SOON_ROW"), UIKit.INK_SOFT))
	notes.add_child(_note("check", Loc.t("NO_RANDOM"), UIKit.GOLD_TEXT))
	col.add_child(notes)
	var cards: Array = [notes]
	# The restore link sits at the foot of the page (the spare height above it reads as air).
	var foot_gap := Control.new()
	foot_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	foot_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot_gap)
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	var restore := UIKit.text_button(Loc.t("RESTORE"), Vector2(0, 72), 22)
	restore.disabled = true
	restore.add_theme_color_override("font_disabled_color", UIKit.INK_SOFT)
	rrow.add_child(restore)
	col.add_child(rrow)
	refresh()
	UIJuice.soft_in(head, Vector2(0, 12))
	UIJuice.cards_in(cards, 0.12)


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
	_vault_card = UIKit.gem_card("amethyst", BANNER)
	_vault_card.footer_ratio = 0.0
	_vault_card.pips = -1
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -24
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vault_card.content.add_child(row)
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
	var vt := UIKit.scene_label(Loc.t("VAULT"), 40)
	bcol.add_child(vt)
	_vault_count = UIKit.scene_label("", 20, false)
	_vault_count.add_theme_color_override("font_color", UIKit.GOLD_HI)
	bcol.add_child(_vault_count)
	bcol.add_child(UIKit.gap(8))
	_vault_cta = UIKit.cta_button(Loc.t("OPEN"), "", Vector2(250, 78), 30)
	_vault_cta.pressed.connect(func(): hub.open_vault())
	bcol.add_child(_vault_cta)
	_vault_btn = UIKit.button(Loc.t("OPEN"), false, 200.0)
	_vault_btn.custom_minimum_size.y = 68
	_vault_btn.pressed.connect(func(): hub.open_vault())
	bcol.add_child(_vault_btn)
	var host := VaultView.clipped(_vault_card, BANNER)
	host.mouse_filter = Control.MOUSE_FILTER_PASS
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


## Tall phones: the banner (host, its clip and the card) grows by `extra` px.
func _grow_banner(extra: float) -> void:
	if _banner_host == null:
		return
	var sz := BANNER + Vector2(0, roundf(extra))
	if _banner_host.custom_minimum_size == sz:
		return
	_banner_host.custom_minimum_size = sz
	var clip := _banner_host.get_child(0) as Control
	clip.size = sz + Vector2(20, 20)
	_vault_card.size = sz


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
	var l := UIKit.label(text, 21, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 400.0
	row.add_child(l)
	return row


## The odds and guarantees entry: a quiet cream row (socket, title, the pity line, chevron).
func _odds_row() -> Control:
	var p := UIKit.panel("card", Vector2(18, 12))
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
	_pity_lbl = UIKit.label("", 19, UIKit.INK_DIM)
	v.add_child(_pity_lbl)
	row.add_child(v)
	var ch := Icons.make("chevron", 28.0, UIKit.GOLD_TEXT)
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
