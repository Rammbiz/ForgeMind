extends Control
## ГРАТИ tab = the Home screen (UI v2, fusion §6.8 "Home", concept home_v1 layout with Genshin
## restraint). Over HubStage's bright 3D bridgehead (the hero large on the dais, the Deck
## machines behind) it lays out only quiet chrome:
##   - the world ribbon "Світ 2 · Кораловий риф · Рівень 14" (KitTitlePlate) and, when active,
##     the Reinforcements chip under it;
##   - two round cream edge buttons per side (line icons in thin gold rings): Події, Пошта |
##     Завдання, Сховище (gold "!" + soft pulse while caches wait);
##   - small porcelain tags under the Deck machines (rarity gem, level, the Lead's crown) -
##     a tap opens the Deck;
##   - the world's level path as a slim line of facets (cleared = lit topaz, the current one
##     breathing, crowns as tiny pips, the boss fortress at the end);
##   - the amber jewel PLAY ("ГРАТИ" + "Рівень N").
## A tap on the hero makes them turn to the camera.

const WORLD_KEYS: Array[String] = ["WORLD_SPACE", "WORLD_REEF", "WORLD_MYSTIC", "WORLD_VOLCANO", "WORLD_ICE", "WORLD_SKY", "WORLD_RIFT"]
const PLAY_SIZE := Vector2(448, 112)
const RAIL_R := 38.0

var hub: Hub
var _ribbon: KitTitlePlate
var _assist: PanelContainer
var _assist_lbl: Label
var _path: LevelPath
var _cta: KitCTA
var _rails: Array[RoundButton] = []
var _vault_btn: RoundButton
var _quests_btn: RoundButton
var _tags: Array[DeckTag] = []
var _hero_hit: Control
var _shown_once := false
var _launching := false


func setup(p_hub: Hub) -> void:
	hub = p_hub


static func world_name(w: int) -> String:
	return Loc.t(WORLD_KEYS[clampi(w - 1, 0, WORLD_KEYS.size() - 1)])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hero tap target (lowest, so every control sits above it).
	_hero_hit = Control.new()
	_hero_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_hit.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e) and hub and hub.stage:
			hub.stage.poke_hero()
			UIJuice.haptic("TICK", 0.4))
	add_child(_hero_hit)
	# World ribbon.
	_ribbon = UIKit.title_plate("", 440)
	_ribbon.font_size = 22
	add_child(_ribbon)
	# Reinforcements chip.
	_assist = UIKit.pill()
	_assist.mouse_filter = Control.MOUSE_FILTER_STOP
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ar.add_child(Icons.make("plus", 22.0, UITokens.PLUS))
	_assist_lbl = UIKit.label("", 20, UITokens.PLUS, true)
	ar.add_child(_assist_lbl)
	_assist.add_child(ar)
	_assist.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			var a := EconData.assist(Meta.assist_stacks())
			hub.toast(Loc.f("ASSIST_DESC", [int(a["soldiers"]), int(round(float(a["dmg_add"]) * 100.0))]), "plus"))
	add_child(_assist)
	# Edge rails: two per side.
	var ev := _rail("events", func(): _soon("HOME_EVENTS", "events"))
	var mail := _rail("mail", func(): _soon("HOME_MAIL", "mail"))
	_quests_btn = _rail("quests", func(): _soon("HOME_QUESTS", "quests"))
	_vault_btn = _rail("chest", func(): hub.open_vault())
	_rails = [ev, mail, _quests_btn, _vault_btn]
	# Level path (facets) and PLAY.
	_path = LevelPath.new()
	_path.custom_minimum_size = Vector2(520, 58)
	_path.size = Vector2(520, 58)
	_path.current_pressed.connect(_play)
	_path.node_pressed.connect(_on_node)
	add_child(_path)
	_cta = UIKit.cta_button(Loc.t("PLAY").to_upper(), "", PLAY_SIZE, 46)
	_cta.size = PLAY_SIZE
	_cta.pressed.connect(_play)
	add_child(_cta)
	resized.connect(_layout)
	_layout()
	refresh()


func _rail(icon: String, on_press: Callable) -> RoundButton:
	var b := UIKit.edge_button(icon, RAIL_R)
	b.pressed.connect(func():
		UIJuice.haptic("CLICK", 0.4)
		on_press.call())
	add_child(b)
	return b


func _soon(key: String, icon: String) -> void:
	Audio.play("click", -8.0)
	hub.toast(HomeText.f("HOME_SOON", [HomeText.t(key)]), icon)


## Free layout (page-local): ribbon at the top (page top = y 104 of the screen), rails at
## y 96 / 200, PLAY with its bottom just above the nav medallion, the facet path above it.
func _layout() -> void:
	var w := size.x if size.x > 0.0 else 720.0
	var h := size.y if size.y > 0.0 else 994.0
	_ribbon.size = Vector2(440, 44)
	_ribbon.position = Vector2((w - 440.0) * 0.5, 0)
	var asz := _assist.get_combined_minimum_size()
	_assist.size = asz
	_assist.position = Vector2((w - asz.x) * 0.5, 54)
	var d := RAIL_R * 2.0 + 8.0
	var left_x := 18.0
	var right_x := w - 18.0 - d
	var ys := [92.0, 196.0]
	(_rails[0] as Control).position = Vector2(left_x, ys[0])
	(_rails[1] as Control).position = Vector2(left_x, ys[1])
	(_rails[2] as Control).position = Vector2(right_x, ys[0])
	(_rails[3] as Control).position = Vector2(right_x, ys[1])
	# PLAY: bottom 6 px below the page (the page ends 34 px above the nav's medallion room).
	var cta_y := h + 6.0 - PLAY_SIZE.y
	_cta.position = Vector2((w - PLAY_SIZE.x) * 0.5, cta_y)
	_cta.pivot_offset = PLAY_SIZE * 0.5
	_path.position = Vector2((w - _path.size.x) * 0.5, cta_y - _path.size.y - 10.0)


func on_show() -> void:
	refresh()
	if UITokens.reduce_motion():
		return
	# Soft arrival: chrome fades in, rails drift in from their edges, PLAY rises a little.
	var first := not _shown_once
	_shown_once = true
	_ribbon.modulate.a = 0.0
	_ribbon.create_tween().tween_property(_ribbon, "modulate:a", 1.0, UITokens.MENU_IN).set_delay(0.05)
	for i in _rails.size():
		var r: Control = _rails[i]
		if not r.visible:
			continue
		r.modulate.a = 0.0
		var tw := r.create_tween()
		tw.tween_property(r, "modulate:a", 1.0, UITokens.MENU_IN).set_delay(0.08 + 0.04 * (i % 2))
	_path.modulate.a = 0.0
	_path.create_tween().tween_property(_path, "modulate:a", 1.0, UITokens.MENU_IN).set_delay(0.12)
	if first:
		_cta.modulate.a = 0.0
		var tc := _cta.create_tween()
		tc.tween_property(_cta, "modulate:a", 1.0, UITokens.MENU_IN + 0.06).set_delay(0.1)


func on_hide() -> void:
	pass


func refresh() -> void:
	if not is_node_ready():
		return
	var lv := Meta.level()
	var w := ArsenalData.world_of(lv)
	var wn := world_name(w)
	_ribbon.text = "%s · %s · %s" % [Loc.f("WORLD_N", [w]), wn, Loc.f("LEVEL", [lv])]
	_ribbon.accent = wn
	_cta.text = Loc.t("PLAY").to_upper()
	_cta.sub = Loc.f("LEVEL", [lv])
	_path.level = lv
	_path.queue_redraw()
	var stacks := Meta.assist_stacks() if bool(Meta.setting("reinforcements", true)) else 0
	_assist.visible = stacks > 0
	if stacks > 0:
		var a := EconData.assist(stacks)
		_assist_lbl.text = Loc.f("ASSIST_CHIP", [int(round(float(a["dmg_add"]) * 100.0))])
	var n := Meta.vault().size()
	_vault_btn.visible = Meta.is_unlocked("stone_cache") or n > 0
	_vault_btn.badge = "!" if n > 0 else ""
	_vault_btn.highlight = n > 0
	_layout()
	_sync_tags()


## One tag per Deck machine standing on the stage.
func _sync_tags() -> void:
	if hub == null or hub.stage == null:
		return
	hub.stage.refresh()
	var ids := hub.stage.deck_ids()
	while _tags.size() > ids.size():
		(_tags.pop_back() as DeckTag).queue_free()
	while _tags.size() < ids.size():
		var t := DeckTag.new()
		t.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				Audio.play("click", -8.0)
				hub.open_deck())
		add_child(t)
		move_child(t, 1)
		_tags.append(t)
	var ld := Meta.lead()
	for i in ids.size():
		var t := _tags[i]
		t.id = ids[i]
		t.lvl = Meta.machine_level(ids[i])
		t.lead = ids[i] == ld
		t.queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or hub == null or hub.stage == null:
		return
	var origin := get_global_rect().position
	for i in _tags.size():
		var p := hub.stage.deck_screen_pos(i)
		var t := _tags[i]
		t.visible = p.x >= 0.0
		t.position = p - origin - Vector2(t.size.x * 0.5, t.size.y - 22.0)
	var hr := hub.stage.hero_screen_rect()
	_hero_hit.position = hr.position - origin
	_hero_hit.size = hr.size


func _play() -> void:
	if _launching:
		return
	UIJuice.haptic("THUD", 0.7)
	if UITokens.reduce_motion() or hub.stage == null:
		hub.play.emit()
		return
	# The camera dollies onto the bridge, then the run loads.
	_launching = true
	hub.stage.dolly(0.45)
	get_tree().create_timer(0.4).timeout.connect(func():
		_launching = false
		if is_instance_valid(hub):
			hub.play.emit())


func _on_node(level: int) -> void:
	var nc := ArsenalData.new_crate_at(level)
	if ArsenalData.is_boss(level):
		hub.toast(Loc.t("WORLD_CACHE_HINT"), "fortress")
	elif nc != "" and not Meta.owned(nc):
		hub.toast(Loc.f("NEW_CRATE_AT", [Loc.t(ArsenalData.MACHINES[nc]["name"])]), nc)
	else:
		hub.toast(Loc.f("LEVEL", [level]), "map")


## A Deck machine's tag on the terrace: a porcelain chip with the rarity gem, "Рів. N" and the
## Lead's small crown. The control is tall so the machine above the chip is tappable too.
class DeckTag extends Control:
	var id := ""
	var lvl := 1
	var lead := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(150, 150)

	func _draw() -> void:
		if id == "":
			return
		var f := UIKit.font_w("bold")
		var txt := Loc.f("LV", [lvl])
		var fs := 18
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := tw + 46.0
		var r := Rect2(Vector2((size.x - cw) * 0.5, size.y - 34.0), Vector2(cw, 30))
		draw_style_box(UIKit.lux("pill"), r)
		var gem := UITokens.gem_of(ArsenalData.rarity_of(id))
		GemDraw.draw_mark(self, gem, Vector2(r.position.x + 17.0, r.get_center().y), 15.0)
		draw_string(f, Vector2(r.position.x + 30.0, r.position.y + 21.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
		if lead:
			Icons.draw_icon(self, "crown", Rect2(Vector2(r.position.x - 12.0, r.position.y - 20.0), Vector2(30, 30)))


## The world's level path as a slim line of facets on a translucent porcelain plate: cleared
## levels are lit topaz facets with tiny crown pips under them, the current level is a larger
## breathing facet with its number, levels ahead are engraved outlines (a NEW machine on one
## shows a small glint), the boss fortress closes the line.
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
		if is_visible_in_tree():
			queue_redraw()

	func _first() -> int:
		return (ArsenalData.world_of(level) - 1) * ArsenalData.LEVELS_PER_WORLD + 1

	func _node_pos(i: int) -> Vector2:
		var n := ArsenalData.LEVELS_PER_WORLD
		return Vector2(lerpf(46.0, size.x - 46.0, float(i) / float(n - 1)), 24.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var hit := -1
			var best := 40.0
			for i in ArsenalData.LEVELS_PER_WORLD:
				var d: float = absf(event.position.x - _node_pos(i).x)
				if d < best:
					best = d
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
		draw_style_box(UIKit.lux("pill"), Rect2(Vector2(10, 2), Vector2(size.x - 20, size.y - 4)))
		var a := _node_pos(0)
		var b := _node_pos(n - 1)
		# The line: lit (amber) up to the current level, a hairline after it.
		var cur_i := clampi(level - first, 0, n - 1)
		var cx := _node_pos(cur_i).x
		draw_line(a, Vector2(cx, a.y), Color(UITokens.CTA.r, UITokens.CTA.g, UITokens.CTA.b, 0.85), 2.5, true)
		draw_line(Vector2(cx, a.y), b, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8), 1.5, true)
		var f := UIKit.font_w("bold")
		var breathe := 0.5 + 0.5 * sin(fmod(_t, 200.0 * PI) * TAU / UITokens.GLOW_PERIOD)
		for i in n:
			var l := first + i
			var p := _node_pos(i)
			var boss := i == n - 1
			if boss:
				var lit := l <= level
				draw_circle(p, 15.0, UITokens.PAPER_0)
				draw_arc(p, 14.5, 0, TAU, 32, UITokens.HAIRLINE, 1.5, true)
				Icons.line(self, "trophy", Rect2(p - Vector2(10, 10), Vector2(20, 20)), UITokens.GOLD_TEXT if lit else UITokens.INK_DIM)
				if l == level:
					draw_arc(p, 19.0 + breathe * 3.0, 0, TAU, 40, Color(UITokens.CTA.r, UITokens.CTA.g, UITokens.CTA.b, 0.7 - breathe * 0.4), 2.0, true)
				continue
			if l < level:
				GemDraw.draw_pip(self, p, 18.0, true, UITokens.TOPAZ)
				var cr := _crowns(l)
				for k in 3:
					var dp := p + Vector2((k - 1) * 6.0, 16.0)
					draw_circle(dp, 1.8, UITokens.CTA_LO if k < cr else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5))
			elif l == level:
				draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(26, 26), Vector2(52, 52)), false, Color(1.0, 0.78, 0.4, 0.35 + 0.3 * breathe))
				GemDraw.draw_pip(self, p, 28.0, true, UITokens.TOPAZ)
				var t := str(l)
				var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				draw_string(f, Vector2(p.x - tw * 0.5, p.y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITokens.GOLD_TEXT)
			else:
				GemDraw.draw_pip(self, p, 16.0, false)
			var nc := ArsenalData.new_crate_at(l)
			if nc != "" and l >= level and not Meta.owned(nc):
				GemDraw.draw_glint(self, p + Vector2(10, -12), 12.0 + breathe * 3.0, Color(1.0, 0.85, 0.45, 0.95))
