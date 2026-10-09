extends Node
## Dev gallery of the Heroes meta UI (phase H3a). Turns the Hall on (HeroesUIModel.force_on), loads a
## mock account state, builds the real hub (top bar + nav) and shoots the requested screens.
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 \
##     res://scenes/dev/heroes_gallery.tscn -- --out=DIR --tag=720 --state=mid --shots=hall,showcase_vesta
## Args: --out=DIR · --tag=720 (file suffix) · --state=fresh|mid|late|welcome · --shots=a,b,c (names in
## HeroesGalleryShots.SHOTS; "showcase" alone uses --hero) · --t=SECONDS (into a ceremony) ·
## --hero=vesta · --lang=uk|en · --hold (keep the window open after the shots) ·
## --cta=amber|porcelain|ink|sapphire|champagne (KitCTA study style).
## Files: <out>/<shot>[_<tag>].png. Headless runs build everything and save nothing.

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/h3ui/shots"
var tag := ""
var state := "mid"
var hero := "vesta"
var walk_hero := ""
var t_into := 0.0
var hold := false
var shots: Array[String] = ["widgets", "widgets_cards", "hall"]
var hub: Hub
var _page_layer: CanvasLayer

const LEVEL_OF := {"fresh": 4, "mid": 20, "late": 40, "welcome": 20}


func _ready() -> void:
	var lang := "uk"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"tag": tag = v
			"state": state = v
			"hero": hero = v
			"walk_hero": walk_hero = v
			"lang": lang = v
			"t": t_into = float(v)
			"hold": hold = true
			"cta": KitCTA.style = v
			"shots":
				shots.clear()
				for s in v.split(",", false):
					shots.append(s.strip_edges())
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Loc.set_language(lang, false)
	HeroesUIModel.force_on = true
	_load_state(state)
	await get_tree().process_frame
	hub = Hub.new("play")
	add_child(hub)
	await _wait(1.2)
	for s in shots:
		await _shot_step(s)
	if not hold:
		get_tree().quit(0)


func _load_state(st: String) -> void:
	HeroesUIModel.set_state(st)
	var lvl := int(LEVEL_OF.get(st, 20)) + 1
	Save.level = lvl
	var acc := Meta.synthetic_account(lvl, "expected")
	var w: Dictionary = acc["wallet"]
	var cur := HeroesUIModel.currencies()
	w["coins"] = int(cur["coins"])
	w["gems"] = 40
	Meta.account = acc


func _shot_step(name: String) -> void:
	var r := HeroesGalleryShots.resolve(name)
	if r.is_empty() and HeroesGalleryShots.SHOTS.has(name + "_*"):
		r = {"entry": HeroesGalleryShots.SHOTS[name + "_*"], "arg": hero}
	if r.is_empty():
		push_warning("heroes_gallery: unknown shot " + name)
		return
	var e: Dictionary = r["entry"]
	var arg := str(r["arg"])
	_reset()
	if e.has("state") and str(e["state"]) != HeroesUIModel.state_name():
		_load_state(str(e["state"]))
		_refresh_hall()
	elif not e.has("state") and HeroesUIModel.state_name() != state:
		_load_state(state)
		_refresh_hall()
	if e.has("builtin"):
		_build_page(str(e["builtin"]))
		await _wait(float(e.get("wait", 1.2)))
		await _shot(name)
		return
	var gem := _gem_letter(arg)
	if e.has("force"):
		var f: Array = []
		for fx: Dictionary in e["force"]:
			# --walk_hero=<id> overrides the per-gem walkout hero (e.g. Мейра's eyes-closed beat).
			var wh := walk_hero if walk_hero != "" else str(HeroesGalleryShots.WALKOUT_HERO.get(gem, "vesta"))
			f.append({"id": str(fx["id"]).replace("{gem_hero}", wh),
					"gem": str(fx["gem"]).replace("{gem}", gem)})
		HeroesUIModel.force_next = f
	var uri := str(e["uri"]).replace("{arg}", arg).replace("{gem}", gem)
	if uri.begins_with("hall"):
		hub.select_tab("heroes", false)
		var sub := uri.get_slice("/", 1) if uri.contains("/") else ""
		var page: Control = hub.pages.get("heroes")
		if sub != "" and page and page.has_method("show_tab"):
			page.call("show_tab", sub)
		await _wait(float(e.get("wait", 1.4)))
		await _shot(name)
		return
	hub.select_tab("heroes", false)
	await _wait(0.3)
	# force: the gallery shoots locked routes too (team / portal at L4) to check their layout.
	var c := HeroesNav.open(hub, uri, self, true)
	var wait := float(e.get("wait", 1.4))
	if c and c.has_method("gallery_seek"):
		await _wait(wait)
		c.call("gallery_seek", t_into)
		await _wait(0.12)
	else:
		await _wait(wait + t_into)
	await _shot(name)


func _gem_letter(arg: String) -> String:
	var a := arg.to_lower()
	match a:
		"quartz", "c": return "C"
		"sapphire", "r": return "R"
		"amethyst", "e": return "E"
		"topaz", "l": return "L"
		"opal", "m": return "M"
	return "L"


func _refresh_hall() -> void:
	var page: Control = hub.pages.get("heroes")
	if page and page.has_method("refresh"):
		page.call("refresh")


func _reset() -> void:
	HeroesNav.close_all()
	while hub.has_modal():
		hub.pop_modal()
	if _page_layer:
		_page_layer.queue_free()
		_page_layer = null


func _build_page(which: String) -> void:
	_page_layer = CanvasLayer.new()
	_page_layer.layer = 8
	add_child(_page_layer)
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_layer.add_child(root)
	root.add_child(HeroesWidgetSpecimen.build(which))


## Waits `s` seconds of game time (frame deltas; xvfb renders slowly and deltas are capped).
func _wait(s: float) -> void:
	var t := 0.0
	var frames := 0
	var headless := DisplayServer.get_name() == "headless"
	while t < s and not (headless and frames >= 20):
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT ", name, " (headless, not saved)")
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := name + ("_" + tag if tag != "" else "") + ".png"
	img.save_png(out_dir.path_join(file))
	print("SHOT ", file)
