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
##   - the world's level path as a slim line of facets on a glass pill (cleared = lit topaz on a
##     1.5 dpx amber line, the current one larger in a soft static glow, a 1 dpx hairline ahead,
##     the boss trophy at the end; nothing breathes);
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
const FADE_SKIP := 0.3          ## s: a first frame slower than this skips the chrome fade
var _fade: Array = []           ## [control, delay, duration] while the arrival fade runs
var _fade_req := 0              ## ms when on_show asked for the fade
var _fade_t0 := -1              ## ms of the first frame of the fade (-1 = not started)


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
	_assist_lbl = UIKit.label("", 22, UITokens.PLUS, true)
	ar.add_child(_assist_lbl)
	_assist.add_child(ar)
	_assist.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			var a := EconData.assist(Meta.assist_stacks())
			hub.toast(Loc.f("ASSIST_DESC", [int(a["soldiers"]), int(round(float(a["dmg_add"]) * 100.0))]), "plus"))
	add_child(_assist)
	# Edge rails: two per side.
	# The three features to come show a muted icon and their name (a visible "скоро" state);
	# Сховище is live.
	var ev := _rail("events", func(): _soon("HOME_EVENTS", "events"), HomeText.t("HOME_EVENTS"), true)
	var mail := _rail("mail", func(): _soon("HOME_MAIL", "mail"), HomeText.t("HOME_MAIL"), true)
	_quests_btn = _rail("quests", func(): _soon("HOME_QUESTS", "quests"), HomeText.t("HOME_QUESTS"), true)
	_vault_btn = _rail("chest", func(): hub.open_vault(), Loc.t("VAULT"))
	_rails = [ev, mail, _quests_btn, _vault_btn]
	# Level path (facets) and PLAY.
	_path = LevelPath.new()
	_path.custom_minimum_size = Vector2(360, 46)
	_path.size = Vector2(360, 46)
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


func _rail(icon: String, on_press: Callable, caption := "", soon := false) -> RoundButton:
	var b := UIKit.edge_button(icon, RAIL_R)
	b.caption = caption
	if soon:
		b.icon_tint = Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.45)
		b.caption_color = UITokens.INK_DIM_GLASS
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
	var ys := [92.0, 212.0]
	(_rails[0] as Control).position = Vector2(left_x, ys[0])
	(_rails[1] as Control).position = Vector2(left_x, ys[1])
	(_rails[2] as Control).position = Vector2(right_x, ys[0])
	(_rails[3] as Control).position = Vector2(right_x, ys[1])
	# PLAY: bottom 6 px below the page (the page ends 34 px above the nav's medallion room).
	var cta_y := h + 6.0 - PLAY_SIZE.y
	_cta.position = Vector2((w - PLAY_SIZE.x) * 0.5, cta_y)
	_cta.pivot_offset = PLAY_SIZE * 0.5
	_path.position = Vector2((w - _path.size.x) * 0.5, cta_y - _path.size.y - 6.0)


func on_show() -> void:
	refresh()
	if UITokens.reduce_motion():
		return
	# Soft arrival on a tab switch back to Home: ribbon, rails and level path fade in. Driven
	# by the wall clock from the first drawn frame, not by tweens, and any frame slower than
	# FADE_SKIP ends it at once: slow frames can no longer leave the chrome half-faded.
	var first := not _shown_once
	_shown_once = true
	_fade.clear()
	# A freshly built hub arrives under the router's scene fade, on the slowest frames of all
	# (shader compiles, the 3D stage): its chrome is there from the first drawn frame.
	if first:
		_end_fade()
		return
	_fade.append([_ribbon, 0.05, UITokens.MENU_IN])
	for i in _rails.size():
		var r: Control = _rails[i]
		if r.visible:
			_fade.append([r, 0.08 + 0.04 * (i % 2), UITokens.MENU_IN])
	_fade.append([_path, 0.12, UITokens.MENU_IN])
	for f: Array in _fade:
		(f[0] as Control).modulate.a = 0.0
	_fade_req = Time.get_ticks_msec()
	_fade_t0 = -1


## Advances the chrome fade (see on_show).
func _step_fade() -> void:
	if _fade.is_empty():
		return
	var now := Time.get_ticks_msec()
	# A slow frame (the hub's first frame compiles shaders and builds the 3D stage: its delta,
	# or the time since on_show, runs to seconds) skips the fade: the chrome is simply there.
	if get_process_delta_time() > FADE_SKIP or (_fade_t0 < 0 and now - _fade_req > int(FADE_SKIP * 1000.0)):
		_end_fade()
		return
	if _fade_t0 < 0:
		_fade_t0 = now
	var t := (now - _fade_t0) / 1000.0
	var done := true
	for f: Array in _fade:
		var k := clampf((t - float(f[1])) / float(f[2]), 0.0, 1.0)
		(f[0] as Control).modulate.a = 1.0 - pow(1.0 - k, 3.0)
		done = done and k >= 1.0
	if done:
		_fade.clear()


func _end_fade() -> void:
	for f: Array in _fade:
		(f[0] as Control).modulate.a = 1.0
	_fade.clear()


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
	_step_fade()
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
		# v3: a thin glass chip (1 dpx gold + light line), Medium 22 ink (text >= 22 on glass).
		var f := UIKit.font_w("medium")
		var txt := Loc.f("LV", [lvl])
		var fs := 22
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := tw + 52.0
		var r := Rect2(Vector2(roundf((size.x - cw) * 0.5), size.y - 38.0), Vector2(roundf(cw), 34))
		draw_style_box(UIKit.lux("pill"), r)
		var gem := UITokens.gem_of(ArsenalData.rarity_of(id))
		GemDraw.draw_mark(self, gem, Vector2(r.position.x + 19.0, r.get_center().y), 16.0)
		var base := r.position.y + (r.size.y + f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string(f, Vector2(r.position.x + 33.0, roundf(base)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
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
	var _press := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _first() -> int:
		return (ArsenalData.world_of(level) - 1) * ArsenalData.LEVELS_PER_WORLD + 1

	func _node_pos(i: int) -> Vector2:
		var n := ArsenalData.LEVELS_PER_WORLD
		return Vector2(lerpf(34.0, size.x - 34.0, float(i) / float(n - 1)), size.y * 0.5)

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
		# v3 lines (§3.1): the walked part a 1.5 dpx amber rule, the road ahead a 1 dpx hairline,
		# both on a whole pixel row (straight rules, no AA blur).
		var y := GemDraw.pixel_y(self, a.y)
		draw_line(Vector2(a.x, y), Vector2(cx, y), Color(UITokens.CTA_LO.r, UITokens.CTA_LO.g, UITokens.CTA_LO.b, 0.9), UIKit.line_px(1.5))
		draw_line(Vector2(cx, y), Vector2(b.x, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), UIKit.line_px(1.0))
		for i in n:
			var l := first + i
			var p := _node_pos(i)
			var boss := i == n - 1
			if boss:
				var lit := l <= level
				draw_circle(p, 15.0, UITokens.PAPER_0)
				draw_arc(p, 15.0 - UIKit.px(0.5), 0, TAU, 48, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0), true)
				Icons.line(self, "trophy", Rect2(p - Vector2(10, 10), Vector2(20, 20)), UITokens.GOLD_TEXT if lit else UIKit.INK_DIM)
				if l == level:
					# The boss is up: a static 1.5 dpx amber ring (nothing pulses).
					draw_arc(p, 19.0, 0, TAU, 48, Color(UITokens.CTA_LO.r, UITokens.CTA_LO.g, UITokens.CTA_LO.b, 0.9), UIKit.line_px(1.5), true)
				continue
			if l < level:
				# A lit facet only (the crowns live on the level's tap toast; no 4 px pips).
				GemDraw.draw_pip(self, p, 18.0, true, UITokens.TOPAZ)
			elif l == level:
				draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(26, 26), Vector2(52, 52)), false, Color(1.0, 0.8, 0.45, 0.5))
				GemDraw.draw_pip(self, p, 28.0, true, UITokens.TOPAZ)
			else:
				GemDraw.draw_pip(self, p, 16.0, false)
			var nc := ArsenalData.new_crate_at(l)
			if nc != "" and l >= level and not Meta.owned(nc):
				GemDraw.draw_glint(self, p + Vector2(10, -12), 13.0, Color(1.0, 0.85, 0.45, 0.95))
