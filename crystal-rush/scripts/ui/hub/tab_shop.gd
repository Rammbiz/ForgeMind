extends Control
## Магазин tab - Meta-1 placeholder (arsenal_design.md §6.6, §7.1): the promise (no timers, no
## energy, no paid random packs), the Vault with its Caches, the odds and guarantees screen,
## and the coming products shown as sealed cards. Purchases arrive with WS6 (Meta-3).

var hub: Hub
var _vault_lbl: Label
var _pity_lbl: Label


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
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 20)
	sc.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	m.add_child(col)
	var title := UIKit.gradient_heading(Loc.t("TAB_SHOP"), 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var promise := UIKit.heading(Loc.t("SHOP_PROMISE"), 22, Color(1.0, 0.9, 0.75), 6)
	promise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(promise)
	# Vault card
	col.add_child(_feature("cache_world", Loc.t("VAULT"), Loc.t("VAULT_DESC"), Loc.t("OPEN"), func(): hub.open_vault(), true))
	_vault_lbl = col.get_child(col.get_child_count() - 1).get_meta("sub_label")
	# Odds card
	col.add_child(_feature("percent", Loc.t("ODDS_TITLE"), "", Loc.t("ODDS"), func(): hub.open_odds("stone"), false))
	_pity_lbl = col.get_child(col.get_child_count() - 1).get_meta("sub_label")
	# Coming products
	var soon := UIKit.heading(Loc.t("SHOP_SOON").to_upper(), 22, UIKit.GOLD, 5)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(soon)
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 12)
	for ic: String in ["chest", "gem", "crown"]:
		var card := SoonCard.new()
		card.icon = ic
		card.custom_minimum_size = Vector2(200, 230)
		grid.add_child(card)
	col.add_child(grid)
	var nr := UIKit.heading(Loc.t("NO_RANDOM"), 20, UIKit.TEXT_DIM, 5)
	nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nr)
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	var restore := UIKit.button(Loc.t("RESTORE"), false, 360.0)
	restore.custom_minimum_size.y = 64
	restore.add_theme_font_size_override("font_size", 22)
	restore.disabled = true
	rrow.add_child(restore)
	col.add_child(rrow)
	refresh()
	UIJuice.stagger(col.get_children(), 0.0, 0.05)


func on_show() -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_vault_lbl.text = Loc.f("VAULT_COUNT", [Meta.vault().size()]) if not Meta.vault().is_empty() else Loc.t("VAULT_EMPTY")
	var pl := Meta.pity_left()
	_pity_lbl.text = Loc.f("PITY_LEG", [pl]) if pl >= 0 else Loc.t("PITY_LEG_LOCKED")


func _feature(icon: String, title: String, sub: String, btn_text: String, on_press: Callable, big: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("parch", Vector2(22, 18)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	var ic := Icons.make(icon, 96.0 if big else 72.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon == "percent":
		ic.tint = UITokens.PARCH_INK
	row.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIKit.label(title, 30, UITokens.PARCH_INK, true))
	var s := UIKit.label(sub, 20, UITokens.PARCH_INK_DIM, false)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	row.add_child(v)
	var b := UIKit.styled_button(btn_text, "green", Vector2(170, 72), 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	row.add_child(b)
	p.set_meta("sub_label", s)
	return p


## A sealed product card ("Скоро").
class SoonCard extends Control:
	var icon := "chest"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(4, 8), size - Vector2(8, 14))
		draw_style_box(UIKit.lux("parch_card"), r)
		var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.42)
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(90, 90), Vector2(180, 180)), false, Color(1.0, 0.75, 0.35, 0.35))
		Icons.draw_icon(self, icon, Rect2(c - Vector2(52, 52), Vector2(104, 104)), Color(0.75, 0.68, 0.6, 0.9))
		var lc := c + Vector2(40, 36)
		draw_circle(lc, 20, Color(0.42, 0.24, 0.08))
		draw_circle(lc, 17, Color(0.95, 0.86, 0.66))
		Icons.draw_icon(self, "lock", Rect2(lc - Vector2(12, 12), Vector2(24, 24)), Color(0.4, 0.24, 0.1))
		var f := UIKit.font(true)
		var t := Loc.t("SOON")
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.end.y - 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UITokens.PARCH_INK)
