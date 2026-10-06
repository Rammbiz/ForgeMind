extends Control
## ГРА tab (arsenal_design.md §7.1 Play map): the world banner, the hero and the Deck machines
## on the road behind (HubStage), the world's level path (8 nodes along a glowing trail: cleared
## levels with their Crowns, the current one pulsing, NEW-machine teasers, the boss fortress
## with its World Cache), the Vault on the right rail, then the PLAY call-to-action
## ("Рівень 3 · Орбітальна траса") with the Reinforcements chip, and the Deck row.

const WORLD_KEYS: Array[String] = ["WORLD_SPACE", "WORLD_REEF", "WORLD_MYSTIC", "WORLD_VOLCANO", "WORLD_ICE", "WORLD_SKY", "WORLD_RIFT"]

var hub: Hub
var _col: VBoxContainer
var _banner_world: Label
var _banner_name: Label
var _path: LevelPath
var _cta: Button
var _cta_title: Label
var _cta_sub: Label
var _assist: PanelContainer
var _assist_lbl: Label
var _deck_row: HBoxContainer
var _vault_btn: RoundButton


func setup(p_hub: Hub) -> void:
	hub = p_hub


static func world_name(w: int) -> String:
	return Loc.t(WORLD_KEYS[clampi(w - 1, 0, WORLD_KEYS.size() - 1)])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col = VBoxContainer.new()
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_col.offset_left = UITokens.GUTTER
	_col.offset_right = -UITokens.GUTTER
	_col.offset_bottom = -10
	_col.add_theme_constant_override("separation", 8)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	# World banner
	var banner := VBoxContainer.new()
	banner.add_theme_constant_override("separation", -6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_world = UIKit.heading("", 24, Color(0.72, 0.88, 1.0), 6)
	_banner_world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(_banner_world)
	_banner_name = UIKit.gradient_heading("", 50)
	_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(_banner_name)
	_col.add_child(banner)
	_col.add_child(UIKit.spacer(false))
	# Level path
	_path = LevelPath.new()
	_path.custom_minimum_size = Vector2(0, 220)
	_path.current_pressed.connect(func(): _play())
	_path.node_pressed.connect(_on_node)
	_col.add_child(_path)
	# Reinforcements chip
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_assist = PanelContainer.new()
	_assist.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.24, 0.12, 0.92), Color(0.45, 0.95, 0.5, 0.9), 22, 3, 6, Vector2(18, 6)))
	_assist.mouse_filter = Control.MOUSE_FILTER_STOP
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 8)
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.add_child(Icons.make("plus", 24.0, Color(0.6, 1.0, 0.6)))
	_assist_lbl = UIKit.heading("", 24, Color(0.85, 1.0, 0.85), 5)
	ar.add_child(_assist_lbl)
	_assist.add_child(ar)
	_assist.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			var a := EconData.assist(Meta.assist_stacks())
			hub.toast(Loc.f("ASSIST_DESC", [int(a["soldiers"]), int(round(float(a["dmg_add"]) * 100.0))]), "plus", Color(0.75, 1.0, 0.75)))
	arow.add_child(_assist)
	_col.add_child(arow)
	# PLAY call-to-action
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta = UIKit.button("", true, 504.0)
	_cta.custom_minimum_size = Vector2(504, 132)
	_cta.pressed.connect(_play)
	var cc := VBoxContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -7
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_theme_constant_override("separation", -8)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta_title = UIKit.heading(Loc.t("PLAY").to_upper(), 54, Color(1, 1, 0.96), 0)
	_cta_title.add_theme_color_override("font_shadow_color", Color(0.5, 0.18, 0.0, 0.7))
	_cta_title.add_theme_constant_override("shadow_offset_y", 4)
	_cta_title.add_theme_constant_override("outline_size", 10)
	_cta_title.add_theme_color_override("font_outline_color", Color(0.55, 0.22, 0.02))
	_cta_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(_cta_title)
	_cta_sub = UIKit.label("", 24, Color(0.36, 0.14, 0.02), true)
	_cta_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(_cta_sub)
	_cta.add_child(cc)
	crow.add_child(_cta)
	_col.add_child(crow)
	UIKit.add_shine(_cta, 30.0, 0.9, 3.2, 0.55)
	UIJuice.breathe(_cta, 0.025, 1.8)
	# Deck row
	_deck_row = HBoxContainer.new()
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.add_theme_constant_override("separation", 14)
	_deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_deck_row)
	# Right rail: the Vault.
	_vault_btn = RoundButton.new(40.0)
	_vault_btn.icon_kind = "cache_world"
	_vault_btn.base_color = Color(0.12, 0.08, 0.22, 0.94)
	_vault_btn.caption = Loc.t("VAULT")
	_vault_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vault_btn.position = Vector2(-UITokens.GUTTER - 100, 118)
	_vault_btn.pressed.connect(func(): hub.open_vault())
	add_child(_vault_btn)
	refresh()
	UIJuice.stagger([banner, _path, _cta, _deck_row], 0.05, 0.08)


func on_show() -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var lv := Meta.level()
	var w := ArsenalData.world_of(lv)
	_banner_world.text = Loc.f("WORLD_N", [w]).to_upper()
	_banner_name.text = world_name(w)
	_banner_name.add_theme_font_size_override("font_size", UIKit.fit_size(_banner_name.text, size.x - 80.0 if size.x > 0 else 600.0, 50, 30))
	_cta_sub.text = "%s · %s" % [Loc.f("LEVEL", [lv]), world_name(w)]
	_path.level = lv
	_path.queue_redraw()
	var stacks := Meta.assist_stacks() if bool(Meta.setting("reinforcements", true)) else 0
	_assist.visible = stacks > 0
	if stacks > 0:
		var a := EconData.assist(stacks)
		_assist_lbl.text = Loc.f("ASSIST_CHIP", [int(round(float(a["dmg_add"]) * 100.0))])
	var n := Meta.vault().size()
	_vault_btn.visible = Meta.is_unlocked("stone_cache") or n > 0
	_vault_btn.badge = str(n) if n > 0 else ""
	_vault_btn.highlight = n > 0
	_vault_btn.caption = Loc.t("VAULT")
	for c in _deck_row.get_children():
		c.queue_free()
	var d := Meta.deck()
	var ld := Meta.lead()
	var cap := UIKit.heading(Loc.t("DECK").to_upper(), 20, UIKit.TEXT_DIM, 5)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_row.add_child(cap)
	for i in maxi(Meta.deck_slots(), 3):
		var chip := DeckChip.new()
		chip.id = d[i] if i < d.size() else ""
		chip.lead = chip.id != "" and chip.id == ld
		chip.lvl = Meta.machine_level(chip.id) if chip.id != "" else 0
		chip.custom_minimum_size = Vector2(84, 84)
		chip.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				hub.open_deck())
		UIJuice.press(chip)
		_deck_row.add_child(chip)


func _play() -> void:
	UIJuice.haptic("THUD", 0.7)
	Audio.play("click")
	hub.play.emit()


func _on_node(level: int) -> void:
	var nc := ArsenalData.new_crate_at(level)
	if ArsenalData.is_boss(level):
		hub.toast(Loc.t("WORLD_CACHE_HINT"), "fortress")
	elif nc != "" and not Meta.owned(nc):
		hub.toast(Loc.f("NEW_CRATE_AT", [Loc.t(ArsenalData.MACHINES[nc]["name"])]), nc)
	else:
		hub.toast(Loc.f("LEVEL", [level]), "crystal")


## One machine of the Deck: rarity-rimmed medallion with the machine render, its level and the
## Lead crown.
class DeckChip extends Control:
	var id := ""
	var lvl := 0
	var lead := false
	var _tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		if id != "":
			_tex = MachineThumbs.get_thumb(self, id, lvl >= ArsenalData.ASCENSION_LEVEL)
			if _tex == null and WeaponModels.KINDS.has(id):
				MachineThumbs.service(get_tree()).rendered.connect(func(k: String, t: Texture2D):
					if k == MachineThumbs.key_of(id, lvl >= ArsenalData.ASCENSION_LEVEL) and is_instance_valid(self):
						_tex = t
						queue_redraw())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c + Vector2(0, 4), r + 1.0, Color(0, 0, 0.03, 0.5))
		if id == "":
			draw_circle(c, r, Color(0.04, 0.05, 0.1, 0.85))
			draw_arc(c, r - 1.0, 0, TAU, 40, Color(1, 1, 1, 0.18), 2.0, true)
			Icons.draw_icon(self, "plus", Rect2(c - Vector2(14, 14), Vector2(28, 28)), Color(1, 1, 1, 0.35))
			return
		var rc := UITokens.rarity(ArsenalData.rarity_of(id))
		draw_circle(c, r, rc.darkened(0.45))
		draw_circle(c + Vector2(0, -1), r - 1.5, rc)
		draw_circle(c, r - 5.0, Color(0.06, 0.08, 0.18))
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.7, UITokens.family(ArsenalData.family_of(id)).darkened(0.55))
		var ir := Rect2(c - Vector2(r, r) * 0.82, Vector2(r, r) * 1.64)
		if _tex:
			draw_texture_rect(_tex, ir.grow(6), false)
		else:
			Icons.draw_icon(self, id, ir.grow(-8))
		draw_arc(c, r - 5.0, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.3), 2.0, true)
		var f := UIKit.font(true)
		var t := str(lvl)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var br := Rect2(Vector2(c.x - tw * 0.5 - 9, size.y - 22), Vector2(tw + 18, 24))
		draw_style_box(UIKit.box(Color(0.05, 0.06, 0.14), rc, 10, 2, 0, Vector2.ZERO), br)
		draw_string(f, Vector2(c.x - tw * 0.5, br.position.y + 19), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
		if lead:
			Icons.draw_icon(self, "crown", Rect2(Vector2(c.x - 16, -10), Vector2(32, 32)))


## The world's level path: 8 nodes on a gentle wave, cleared / current / ahead / boss.
class LevelPath extends Control:
	signal current_pressed
	signal node_pressed(level: int)
	var level := 1
	var _t := 0.0
	var _press := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _first() -> int:
		return (ArsenalData.world_of(level) - 1) * ArsenalData.LEVELS_PER_WORLD + 1

	func _node_pos(i: int) -> Vector2:
		var n := ArsenalData.LEVELS_PER_WORLD
		var x := lerpf(52.0, size.x - 64.0, float(i) / float(n - 1))
		var y := size.y * 0.56 + (-1.0 if i % 2 == 0 else 1.0) * 30.0
		if i == n - 1:
			y = size.y * 0.5
		return Vector2(x, y)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var hit := -1
			for i in ArsenalData.LEVELS_PER_WORLD:
				if event.position.distance_to(_node_pos(i)) < 44.0:
					hit = i
			if event.pressed:
				_press = hit
			elif hit >= 0 and hit == _press:
				var l := _first() + hit
				if l == level:
					current_pressed.emit()
				else:
					node_pressed.emit(l)
				_press = -1
			accept_event()

	func _crowns(l: int) -> int:
		var cb: Dictionary = (Meta.account.get("progress", {}) as Dictionary).get("crowns_best", {})
		return int(cb.get(l, cb.get(str(l), 1 if l < level else 0)))

	func _draw() -> void:
		var n := ArsenalData.LEVELS_PER_WORLD
		var first := _first()
		var pts := PackedVector2Array()
		for i in n:
			pts.append(_node_pos(i))
		# Trail: smooth curve through the nodes (Catmull-Rom), dark bed, then lit / dim halves.
		var curve := PackedVector2Array()
		var lit_upto := -1
		for i in n - 1:
			var p0 := pts[maxi(i - 1, 0)]
			var p1 := pts[i]
			var p2 := pts[i + 1]
			var p3 := pts[mini(i + 2, n - 1)]
			for s in 12:
				var t := float(s) / 12.0
				var t2 := t * t
				var t3 := t2 * t
				curve.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
			if first + i + 1 <= level:
				lit_upto = curve.size()
		curve.append(pts[n - 1])
		draw_polyline(curve, Color(0.0, 0.01, 0.05, 0.65), 20.0, true)
		draw_polyline(curve, Color(0.3, 0.38, 0.62, 0.55), 8.0, true)
		# Dashes on the road ahead.
		for k in range(maxi(lit_upto, 0), curve.size() - 1, 3):
			draw_line(curve[k], curve[mini(k + 1, curve.size() - 1)], Color(0.75, 0.85, 1.0, 0.55), 4.0, true)
		if lit_upto > 0:
			var lit := curve.slice(0, lit_upto + 1)
			draw_polyline(lit, Color(1.0, 0.7, 0.25, 0.35), 18.0, true)
			draw_polyline(lit, Color(1.0, 0.82, 0.38), 8.0, true)
			draw_polyline(lit, Color(1.0, 0.97, 0.8), 3.0, true)
			# A spark running along the lit trail.
			var k2 := int(fposmod(_t * 30.0, float(lit.size())))
			draw_texture_rect(UIKit.glow_texture(), Rect2(lit[k2] - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 0.95, 0.7, 0.9))
		var f := UIKit.font(true)
		for i in n:
			var l := first + i
			var p := pts[i]
			var boss := i == n - 1
			var cur := l == level
			var done := l < level
			var r := 40.0 if boss else (36.0 if cur else 28.0)
			if cur:
				var pulse := 0.5 + 0.5 * sin(fmod(_t, 100.0) * 3.5)
				draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(0.45, 0.85, 1.0, 0.45 + 0.25 * pulse))
				draw_arc(p, r + 8.0 + pulse * 6.0, 0, TAU, 48, Color(0.6, 0.92, 1.0, 0.8 - pulse * 0.5), 3.0, true)
			draw_circle(p + Vector2(0, 5), r + 2.0, Color(0, 0, 0.03, 0.55))
			var rim_hi: Color
			var rim_lo: Color
			var face: Color
			if boss:
				rim_hi = Color(1.0, 0.86, 0.5) if (done or cur) else Color(0.62, 0.5, 0.42)
				rim_lo = Color(0.55, 0.18, 0.08)
				face = Color(0.42, 0.08, 0.08) if not done else Color(0.6, 0.38, 0.1)
			elif done:
				rim_hi = Color(1.0, 0.92, 0.6)
				rim_lo = Color(0.7, 0.42, 0.1)
				face = Color(0.98, 0.7, 0.22)
			elif cur:
				rim_hi = Color(0.85, 1.0, 1.0)
				rim_lo = Color(0.15, 0.45, 0.75)
				face = Color(0.2, 0.55, 0.95)
			else:
				rim_hi = Color(0.5, 0.56, 0.72)
				rim_lo = Color(0.16, 0.18, 0.28)
				face = Color(0.08, 0.1, 0.2)
			draw_circle(p, r, rim_lo.darkened(0.3))
			draw_circle(p + Vector2(0, -1.2), r - 1.2, rim_hi)
			draw_circle(p + Vector2(0, 1.5), r - 4.0, rim_lo)
			draw_circle(p, r - 6.0, face)
			draw_circle(p + Vector2(0, -r * 0.18), (r - 6.0) * 0.72, face.lightened(0.12))
			draw_arc(p, r - 7.0, PI * 1.12, PI * 1.88, 18, Color(1, 1, 1, 0.35), 2.5, true)
			if boss:
				Icons.draw_icon(self, "fortress", Rect2(p - Vector2(r, r) * 0.62, Vector2(r, r) * 1.24), Color(1, 1, 1) if (done or cur) else Color(0.7, 0.66, 0.7))
				Icons.draw_icon(self, "cache_world", Rect2(p + Vector2(r * 0.35, -r * 1.35), Vector2(34, 34)))
				var bl := Loc.t("BOSS")
				var bw := f.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				draw_string_outline(f, p + Vector2(-bw * 0.5, r + 24), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.1, 0.0, 0.0))
				draw_string(f, p + Vector2(-bw * 0.5, r + 24), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.6, 0.5))
			else:
				var txt := str(l)
				var fs := 30 if cur else 24
				var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var tc := Color(1, 1, 1) if (cur or done) else Color(0.62, 0.68, 0.82)
				var oc := Color(0.45, 0.24, 0.02) if done else Color(0.02, 0.06, 0.2)
				draw_string_outline(f, p + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, oc)
				draw_string(f, p + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
			if done and not boss:
				var cr := _crowns(l)
				for k in 3:
					var a := -PI / 2.0 + (k - 1) * 0.55
					var cp := p + Vector2(cos(a), sin(a)) * (r + 8.0)
					Icons.draw_icon(self, "crown", Rect2(cp - Vector2(10, 10), Vector2(20, 20)), Color.WHITE if k < cr else Color(0.25, 0.25, 0.35, 0.8))
			if cur:
				var bob := sin(fmod(_t, 100.0) * 4.0) * 5.0
				var pin := p + Vector2(0, -r - 34 + bob)
				draw_colored_polygon(PackedVector2Array([pin + Vector2(-13, -6), pin + Vector2(13, -6), pin + Vector2(0, 14)]), Color(0.02, 0.05, 0.15))
				draw_colored_polygon(PackedVector2Array([pin + Vector2(-10, -5), pin + Vector2(10, -5), pin + Vector2(0, 10)]), Color(1.0, 0.8, 0.3))
			# NEW machine teaser.
			var nc := ArsenalData.new_crate_at(l)
			if nc != "" and l >= level and not Meta.owned(nc):
				var bp := p + Vector2(0, (r + 46) * (1.0 if i % 2 == 0 else -1.0))
				if cur:
					bp = p + Vector2(0, r + 50)
				draw_circle(bp + Vector2(0, 3), 25, Color(0, 0, 0.04, 0.5))
				draw_circle(bp, 25, Color(0.85, 0.9, 1.0))
				draw_circle(bp, 22, Color(0.12, 0.16, 0.3))
				Icons.draw_icon(self, nc, Rect2(bp - Vector2(17, 17), Vector2(34, 34)))
				var tag := Loc.t("CRATE_NEW")
				var tw2 := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				var tr := Rect2(bp + Vector2(-tw2 * 0.5 - 6, 14), Vector2(tw2 + 12, 19))
				draw_style_box(UIKit.box(Color(0.92, 0.95, 1.0), Color(0.35, 0.45, 0.7), 8, 1, 0, Vector2.ZERO), tr)
				draw_string(f, Vector2(tr.position.x + 6, tr.position.y + 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.15, 0.35))
