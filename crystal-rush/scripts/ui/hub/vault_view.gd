class_name VaultView
extends Control
## Cache Vault (arsenal_design.md §5.2, §7.2; UI v2): a cream modal with the title, the odds (i)
## disc and the close disc; every waiting Cache as a gem-ground rarity card (Stone = sapphire,
## World = amethyst, Royal = topaz, X-Ray = quartz) with its 3D egg rendered in, the name, the
## card count and level; tap a card to pick it, and the one amber jewel «Відкрити» (World Caches:
## «на вівтарі» - the Altar) opens it. The empty state, and the Legendary pity bar. Opening goes
## through Hub.open_cache() (the Altar when WS5 listens, else the inline Reveal below; the
## result is rolled, granted and saved by Meta before anything animates).

const CACHE_GEM := {"stone": "sapphire", "world": "amethyst", "royal": "topaz", "xray": "quartz"}
const T := {
	"V_ON_ALTAR": ["на вівтарі", "on the Altar"],
	"V_PICK": ["Обери схованку", "Pick a cache"],
	"V_EMPTY_HINT": ["Перемоги приносять кам’яні схованки, боси світів — світові.", "Wins bring Stone Caches, world bosses bring World Caches."],
	"V_TAKE": ["Забрати", "Collect"],
}

var hub: Hub
var _sheet: PanelContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _cta: KitCTA
var _sel := 0
var _cards: Array[Control] = []
static var _thumbs := {}       ## cache type -> Texture2D (3D egg render, once per session)


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = T.get(key, [key, key])
	return str(row[0] if Loc.lang == "uk" else row[1])


func setup(p_hub: Hub, _a: Variant = null) -> void:
	hub = p_hub


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	# Centred between the top bar and the nav; its height follows the content.
	_sheet = UIKit.panel("modal", Vector2(28, 24))
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	var mid := (ins.y + UITokens.TOP_BAR_H - ins.w - UITokens.TAB_BAR_H) * 0.5
	var half_w := 360.0 - UITokens.GUTTER
	_sheet.offset_left = -half_w + (ins.x - ins.z) * 0.5
	_sheet.offset_right = half_w + (ins.x - ins.z) * 0.5
	_sheet.offset_top = mid
	_sheet.offset_bottom = mid
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_sheet.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var t := UIKit.heading(Loc.t("VAULT"), 40, UIKit.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var info := UIKit.edge_button("info", 26.0)
	info.pressed.connect(func(): hub.open_odds("world" if _has("world") else "stone"))
	head.add_child(info)
	var close := UIKit.edge_button("close", 26.0)
	close.pressed.connect(func(): hub.close_modal(self))
	head.add_child(close)
	col.add_child(head)
	col.add_child(UIKit.divider(560.0))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_scroll)
	UIKit.scroll_fade(_scroll, Color("#F8F3E9"), 40.0, 18.0)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 10)
	cc.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 16)
	pad.add_child(_grid)
	col.add_child(UIKit.hairline())
	col.add_child(PityBar.make())
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	_cta = UIKit.cta_button(Loc.t("OPEN"), "", Vector2(440, 92), 34)
	_cta.pressed.connect(_open_selected)
	crow.add_child(_cta)
	col.add_child(crow)
	_fill()
	_sheet.minimum_size_changed.connect(_center, CONNECT_DEFERRED)
	_center()
	UIJuice.soft_in(_sheet, Vector2(0, 28))


## Centres the modal (its height follows the content) between the top bar and the nav.
func _center() -> void:
	var ins := hub.insets()
	var mid := (ins.y + UITokens.TOP_BAR_H - ins.w - UITokens.TAB_BAR_H) * 0.5
	var h := _sheet.get_combined_minimum_size().y
	_sheet.offset_top = mid - h * 0.5
	_sheet.offset_bottom = mid + h * 0.5


func play_exit() -> Tween:
	return UIJuice.soft_out(_sheet, Vector2(0, 20))


## The scroll area's height: the grid's rows, up to what fits between the bars.
func _fit_scroll(rows: int, row_h: float) -> void:
	var ins := hub.insets()
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)
	var avail := vp.y - ins.y - ins.w - UITokens.TOP_BAR_H - UITokens.TAB_BAR_H - 24.0 - 330.0
	_scroll.custom_minimum_size.y = clampf(rows * row_h + 18.0, 240.0, maxf(240.0, avail))


func _has(type: String) -> bool:
	for c in Meta.vault():
		if str((c as Dictionary).get("type", "")) == type:
			return true
	return false


static func gem_of_cache(type: String) -> String:
	return str(CACHE_GEM.get(type, "sapphire"))


func _fill() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	var v := Meta.vault()
	if v.is_empty():
		_grid.columns = 1
		var e := VBoxContainer.new()
		e.custom_minimum_size = Vector2(540, 0)
		e.add_theme_constant_override("separation", 10)
		var egg := CacheArt.new()
		egg.type = "stone"
		egg.custom_minimum_size = Vector2(200, 200)
		egg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		egg.modulate = Color(1, 1, 1, 0.4)
		e.add_child(egg)
		var l := UIKit.label(Loc.t("VAULT_EMPTY").split(".")[0] + ".", 26, UIKit.INK, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_child(l)
		var l2 := UIKit.label(tr2("V_EMPTY_HINT"), 22, UIKit.INK_DIM)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_child(l2)
		_grid.add_child(e)
		_cta.visible = false
		_fit_scroll(1, 330.0)
		return
	_grid.columns = 3
	_sel = clampi(_sel, 0, v.size() - 1)
	for i in v.size():
		var cd: Dictionary = v[i]
		var type := str(cd.get("type", "stone"))
		var spec: Dictionary = EconData.CACHES.get(type, EconData.CACHES["stone"])
		var card := UIKit.gem_card(gem_of_cache(type), Vector2(184, 246))
		card.footer_ratio = 0.27
		card.title = Loc.t(str(spec["name"]))
		card.footer = "%s · %s" % [Loc.f("ODDS_SLOTS", [int(spec.get("slots", 3))]), Loc.f("LV", [int(cd.get("level", 1))])]
		var art := CacheArt.new()
		art.type = type
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_top = 8
		art.offset_bottom = -4
		card.content.add_child(art)
		var holder := _Pick.new()
		holder.custom_minimum_size = Vector2(184, 246)
		holder.add_child(clipped(card, Vector2(184, 246)))
		holder.selected = i == _sel
		var idx := i
		holder.pressed.connect(func(): _pick(idx))
		_grid.add_child(holder)
		_cards.append(holder)
	_cta.visible = true
	_fit_scroll(int(ceil(v.size() / 3.0)), 262.0)
	_sync_cta()
	UIJuice.cards_in(_cards, 0.08)


func _pick(i: int) -> void:
	if i == _sel:
		_open_selected()
		return
	_sel = i
	Audio.play("click", -8.0)
	UIJuice.haptic("TICK", 0.3)
	for j in _cards.size():
		(_cards[j] as _Pick).selected = j == _sel
	UIJuice.punch(_cards[i], 1.04, 0.16)
	_sync_cta()


func _sync_cta() -> void:
	var v := Meta.vault()
	if _sel >= v.size():
		return
	var type := str((v[_sel] as Dictionary).get("type", "stone"))
	var altar := bool((EconData.CACHES.get(type, {}) as Dictionary).get("altar", false))
	_cta.text = Loc.t("OPEN")
	_cta.sub = tr2("V_ON_ALTAR") if altar else Loc.t(str((EconData.CACHES.get(type, EconData.CACHES["stone"]) as Dictionary)["name"]))


func _open_selected() -> void:
	if _sel >= Meta.vault().size():
		return
	var idx := _sel
	hub.pop_modal()
	hub.open_cache(idx)


## `card` (a KitGemCard of `size`) inside a rect clip with a little room for its shadow and
## NEW tag. Works around the gem card's fracture lines drawing past its edges.
static func clipped(card: Control, card_size: Vector2, pad := 10.0) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = card_size
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(-pad, -pad)
	clip.size = card_size + Vector2(pad, pad) * 2.0
	host.add_child(clip)
	card.position = Vector2(pad, pad)
	card.size = card_size
	clip.add_child(card)
	host.set_meta("card", card)
	return host


## Renders cache `type`'s 3D egg once (transparent, 3/4 light) and keeps it for the session.
## Null in headless runs (CacheArt then draws the painted icon).
static func cache_thumb(host: Node, type: String) -> Texture2D:
	if _thumbs.has(type):
		return _thumbs[type]
	if DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return null
	_thumbs[type] = null
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.get_tree().root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.98, 0.94, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -30, 0)
	key.light_color = Color(1.0, 0.97, 0.92)
	key.light_energy = 0.9
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	rim.light_color = Color(1.0, 0.9, 0.78)
	rim.light_energy = 0.6
	rim.light_specular = 0.0
	vp.add_child(rim)
	var egg := CacheModels.cache(type)
	egg.rotation_degrees.y = 24.0
	vp.add_child(egg)
	var h := float((CacheModels.TYPES.get(type, CacheModels.TYPES["stone"]) as Dictionary)["h"])
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, h * 0.72, 2.75 * maxf(h, 1.0)), Vector3(0, h * 0.5, 0))
	var tree := host.get_tree()
	await RenderingServer.frame_post_draw
	await tree.process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		_thumbs.erase(type)
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		_thumbs.erase(type)
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_thumbs[type] = tex
	return tex


## A cache's egg: the 3D render when ready, else the painted icon (soft glow behind it).
class CacheArt extends Control:
	var type := "stone"
	var _tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_tex = VaultView._thumbs.get(type)
		if _tex == null and not VaultView._thumbs.has(type):
			_load()
		elif _tex == null:
			_wait()

	func _load() -> void:
		var t: Texture2D = await VaultView.cache_thumb(self, type)
		if is_instance_valid(self):
			_tex = t
			queue_redraw()

	func _wait() -> void:
		for _i in 30:
			await get_tree().process_frame
			if not is_instance_valid(self):
				return
			var t: Texture2D = VaultView._thumbs.get(type)
			if t:
				_tex = t
				queue_redraw()
				return

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var gk := VaultView.gem_of_cache(type)
		var lc: Color = UITokens.gem(gk)["light"]
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(s, s) * 0.62, Vector2(s, s) * 1.24), false, Color(lc.r, lc.g, lc.b, 0.55))
		if _tex:
			draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
			var ic := "cache_" + type if type in ["stone", "world"] else "cache_world"
			Icons.draw_icon(self, ic, Rect2(c - Vector2(s, s) * 0.34, Vector2(s, s) * 0.68))


## A pickable card holder: when selected, the v3 selected frame (MachineCard.draw_sel_frame:
## 1.5 dpx deep gold, a diagonal bracket pair, a diamond on the top edge; no glow slab).
class _Pick extends Control:
	signal pressed
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		for c in get_children():
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			(c as Control).set_anchors_preset(Control.PRESET_FULL_RECT)

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e):
			pressed.emit()

	func _draw() -> void:
		if not selected:
			return
		MachineCard.draw_sel_frame(self, Rect2(Vector2.ZERO, size).grow(2.0), UITokens.CHAMFER + 2.0)


## Legendary pity: caps label + a fine bar + "≤ N", or the World 3 note.
class PityBar extends VBoxContainer:
	## `on_scene`: over a 3D scene (the night altar) the labels are warm white / gold_hi with
	## a soft slate glow instead of ink on cream.
	static func make(on_scene := false) -> PityBar:
		var p := PityBar.new()
		p.add_theme_constant_override("separation", 4)
		var left := Meta.pity_left()
		if left < 0:
			var t := UIKit.label(Loc.t("PITY_LEG_LOCKED"), 22, UIKit.GOLD_HI if on_scene else UIKit.INK_DIM)
			if on_scene:
				UIKit.soft_shadow(t, 22, 1.6)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p.add_child(t)
			return p
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var m := _Mark.new()
		m.custom_minimum_size = Vector2(26, 26)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		var l := UIKit.caps(Loc.t("ODDS_PITY_BAR"), 20, UIKit.ON_SCENE if on_scene else UIKit.INK_DIM)
		if on_scene:
			UIKit.soft_shadow(l, 20, 1.6)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var n := UIKit.label(Loc.f("PITY_SHORT", [left]), 22, UIKit.GOLD_HI if on_scene else UITokens.GOLD_TEXT_GLASS, true)
		if on_scene:
			UIKit.soft_shadow(n, 22, 1.6)
		row.add_child(n)
		p.add_child(row)
		var hard := float(EconData.PITY["leg_hard"])
		var bar := UIKit.progress(hard - left, hard, 300.0, 8.0)
		bar.fill_color = UITokens.bar_fill() if UITokens.calm_cta() else UITokens.TOPAZ
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_child(bar)
		return p

	class _Mark extends Control:
		func _draw() -> void:
			GemDraw.draw_mark(self, "topaz", size * 0.5, minf(size.x, size.y) * 0.86)


## Built-in Cache reveal (fallback when no Altar is connected): over a soft scrim, rays in the
## best gem's light, the cache name as on-scene text, the cards fanning out sorted by rarity
## (§6.6) as gem-ground cards with the machine render, the count and NEW; then «Забрати» flies
## the coins to their plate. The bundle was granted and saved before this opens.
class Reveal extends Control:
	var hub: Hub
	var rev: Dictionary = {}
	var _cards: Array[Control] = []

	func setup(p_hub: Hub, p_rev: Dictionary) -> void:
		hub = p_hub
		rev = p_rev

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var best := str(rev.get("best", "C"))
		var bg: Dictionary = UITokens.gem(best)
		var bl: Color = bg["light"]
		var shade := ColorRect.new()
		shade.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.58)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		var rays := UIKit.Rays.new()
		rays.color = Color(bl.r, bl.g, bl.b, 0.3)
		rays.set_anchors_preset(Control.PRESET_CENTER)
		rays.offset_left = -480
		rays.offset_right = 480
		rays.offset_top = -600
		rays.offset_bottom = 360
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rays)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 22)
		add_child(col)
		var t := UIKit.scene_label(Loc.t(str((EconData.CACHES[str(rev.get("type", "stone"))] as Dictionary)["name"])), 46)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
		var fan := HFlowContainer.new()
		fan.alignment = FlowContainer.ALIGNMENT_CENTER
		fan.add_theme_constant_override("h_separation", 14)
		fan.add_theme_constant_override("v_separation", 16)
		col.add_child(fan)
		for cd: Dictionary in rev.get("cards", []):
			var card := RevealCard.make(cd)
			var host := VaultView.clipped(card, Vector2(196, 262))
			host.set_meta("rarity", card.get_meta("rarity"))
			fan.add_child(host)
			_cards.append(host)
		var coins := int(rev.get("coins", 0))
		var crow := HBoxContainer.new()
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		crow.add_theme_constant_override("separation", 10)
		if coins > 0:
			var ci := Icons.make("coin", 44.0)
			ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			crow.add_child(ci)
			crow.add_child(UIKit.number("+" + Loc.num(coins), 44, true))
		col.add_child(crow)
		# «Забрати» sits in the PLAY slot (the dock), the only jewel on screen while the Home
		# chrome is faded out under the reveal.
		var b := UIKit.cta_button(VaultView.tr2("V_TAKE"), "", Vector2(448, 100), 40)
		b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		var ins := hub.insets() if hub else Vector4.ZERO
		b.offset_left = -224
		b.offset_right = 224
		b.offset_bottom = -(UITokens.TAB_BAR_H + ins.w + 28.0)
		b.offset_top = b.offset_bottom - 100.0
		b.pressed.connect(func():
			if coins > 0:
				hub.fly_reward("coins", coins, crow.get_global_rect().get_center())
			hub.close_modal(self))
		add_child(b)
		col.offset_bottom = -(UITokens.TAB_BAR_H + ins.w + 140.0)
		var flip: Dictionary = EconData.REVEAL["flip"]
		var delay := 0.15
		for i in _cards.size():
			UIJuice.pop(_cards[i], delay, UITokens.SLOW, 0.4)
			var r := str(_cards[i].get_meta("rarity", "C"))
			delay += float(EconData.REVEAL["fan_stagger"]) + float(flip.get(r, 0.3)) * 0.4
			if r in ["E", "L", "M"]:
				var cref := _cards[i]
				var lc: Color = UITokens.gem(r)["light"]
				get_tree().create_timer(delay).timeout.connect(func():
					if is_instance_valid(cref):
						UIKit.sparkles(self, cref.get_global_rect().get_center() - global_position, lc, 40, 300.0)
						UIJuice.haptic_pattern("rarity_" + r))
		UIJuice.pop(b, delay + 0.2)
		UIJuice.fade_in(t, 0.0, UITokens.STD)
		Audio.play("crate_open", -2.0)

	func play_exit() -> Tween:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
		return tw


## A revealed card: the machine render on its gem ground, its name and ×count on the cream
## footer, NEW tag; a Wild Blueprint shows the wild icon.
class RevealCard:
	static func make(data: Dictionary) -> KitGemCard:
		var r := str(data.get("rarity", "C"))
		var id := str(data.get("id", ""))
		var c := UIKit.gem_card(r, Vector2(196, 262))
		c.set_meta("rarity", r)
		c.footer_ratio = 0.27
		var wild := bool(data.get("wild", false)) or id == ""
		c.title = Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) and not wild else Loc.t("CUR_WILD")
		c.footer = "×%d" % int(data.get("count", 1))
		c.new_tag = bool(data.get("new", false))
		var art := _MachineArt.new()
		art.id = "" if wild else id
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 6
		art.offset_right = -6
		art.offset_top = 10
		c.content.add_child(art)
		return c


class _MachineArt extends Control:
	var id := ""
	var _tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		if id == "":
			return
		_tex = MachineThumbs.get_thumb(self, id, false)
		if _tex == null and DisplayServer.get_name() != "headless":
			MachineThumbs.service(get_tree()).rendered.connect(func(key: String, tex: Texture2D):
				if is_instance_valid(self) and key == MachineThumbs.key_of(id, false):
					_tex = tex
					queue_redraw())

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var rr := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		if id == "":
			Icons.draw_icon(self, "wild", rr.grow(-s * 0.18))
		elif _tex:
			draw_texture_rect(_tex, rr.grow(s * 0.06), false)
		else:
			Icons.draw_icon(self, id, rr.grow(-s * 0.12))
