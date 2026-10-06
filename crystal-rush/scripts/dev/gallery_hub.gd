extends Node
## Dev preview of the meta hub (WS4). Builds an account, opens the Hub on each tab and its
## sheets, and saves PNGs, then quits.
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_hub.tscn [-- --out=DIR --lang=en --level=14 --profile=expected --shots=play,arsenal --tag=720]
## Profiles: fresh1 (a brand-new account, tabs locked), fresh | expected | max (Meta.synthetic_account).
## Shots: play arsenal deck detail heroes barracks shop vault odds settings unlock upgrade reveal.

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var level := 14
var profile := "expected"
var tag := ""
var shots: Array[String] = ["play", "arsenal", "detail", "deck", "heroes", "barracks", "shop", "vault", "odds", "settings"]
var hub: Hub


func _ready() -> void:
	var lang := "uk"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"lang": lang = v
			"level": level = maxi(1, int(v))
			"profile": profile = v
			"tag": tag = v
			"shots":
				shots.clear()
				for s in v.split(",", false):
					shots.append(s)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Save.level = level
	Save.hero = "bolt"
	Loc.set_language(lang, false)
	_make_account()
	MachineThumbs.service(get_tree())
	await get_tree().process_frame
	# Warm the machine renders so the cards show them.
	for id in Meta.owned_ids():
		MachineThumbs.get_thumb(self, id, Meta.machine_level(id) >= ArsenalData.ASCENSION_LEVEL)
	hub = Hub.new("play")
	add_child(hub)
	await _wait(2.5)
	for s in shots:
		await _shot_step(s)
	get_tree().quit(0)


func _make_account() -> void:
	var acc: Dictionary
	if profile == "fresh1":
		acc = EconData.fresh_account()
		(acc["progress"] as Dictionary)["level"] = level
	else:
		acc = Meta.synthetic_account(level, profile)
	var w: Dictionary = acc["wallet"]
	w["coins"] = 1260 + level * 95
	w["gems"] = 40
	w["crowns"] = (level - 1) * 2
	(w["wild"] as Dictionary)["R"] = 3
	(w["wild"] as Dictionary)["C"] = 6
	for id: String in (acc["arsenal"] as Dictionary)["machines"]:
		var st: Dictionary = (acc["arsenal"] as Dictionary)["machines"][id]
		st["bp"] = EconData.bp_to(ArsenalData.rarity_of(id), int(st["lvl"]) + 1) - (0 if id in ["ballista", "drone"] else 3)
	var cb: Dictionary = (acc["progress"] as Dictionary)["crowns_best"]
	for l in range(1, level):
		cb[l] = 1 + (l * 7) % 3
	if level >= 9:
		((acc["vault"] as Dictionary)["caches"] as Array).append({"type": "world", "source": "boss", "level": 8})
		((acc["vault"] as Dictionary)["caches"] as Array).append({"type": "stone", "source": "win", "level": level - 1})
	(acc["progress"] as Dictionary)["losses_here"] = 2
	Meta.account = acc
	(Meta.account["progress"] as Dictionary)["hero"] = "bolt"


func _shot_step(s: String) -> void:
	match s:
		"play", "arsenal", "heroes", "barracks", "shop":
			_close_modals()
			if hub.tab_bar.is_locked(s):
				print("locked tab ", s)
			hub.select_tab(s, false)
			await _wait(1.6)
			await _shot("hub_" + s)
		"deck":
			_close_modals()
			hub.open_deck()
			await _wait(1.2)
			await _shot("hub_deck")
			var a: Control = hub.pages.get("arsenal")
			if a and a.has_method("show_sub"):
				a.call("show_sub", "machines")
		"detail", "detail2":
			_close_modals()
			hub.select_tab("arsenal", false)
			var id := Meta.lead() if Meta.lead() != "" else (Meta.deck()[0] if not Meta.deck().is_empty() else "drone")
			if s == "detail2":
				id = "railgun"
			hub.open_machine(id)
			await _wait(1.6)
			await _shot("hub_" + s)
		"upgrade":
			var d := _top_modal()
			if d and d.has_method("press_upgrade"):
				d.call("press_upgrade")
				await _wait(0.4)
				await _shot("hub_upgrade_confirm")
				d.call("press_upgrade")
				await _wait(0.35)
				await _shot("hub_upgrade_flare")
				await _wait(1.6)
				await _shot("hub_upgrade_done")
		"vault":
			_close_modals()
			hub.select_tab("play", false)
			hub.open_vault()
			await _wait(1.0)
			await _shot("hub_vault")
		"reveal":
			_close_modals()
			hub.open_cache(0)
			await _wait(2.2)
			await _shot("hub_reveal")
		"odds":
			_close_modals()
			hub.open_odds("stone")
			await _wait(1.0)
			await _shot("hub_odds")
		"settings":
			_close_modals()
			hub.open_settings()
			await _wait(1.0)
			await _shot("hub_settings")
		"fly":
			_close_modals()
			hub.select_tab("play", false)
			await _wait(0.5)
			Meta.add_currency("coins", 250, "gallery")
			hub.fly_reward("coins", 250, hub.ui.size * Vector2(0.5, 0.55))
			await _wait(0.42)
			await _shot("hub_fly")
			await _wait(1.2)
		"beat":
			_close_modals()
			hub.select_tab("arsenal", false)
			var bid := ""
			for mid in Meta.owned_ids():
				if Meta.can_upgrade(mid) and Meta.beat_at(Meta.machine_level(mid) + 1) != "":
					bid = mid
			if bid == "":
				for mid2 in Meta.owned_ids():
					var st: Dictionary = (Meta.account["arsenal"] as Dictionary)["machines"][mid2]
					st["lvl"] = 4
					st["bp"] = 99
					bid = mid2
					break
			hub.open_machine(bid)
			await _wait(1.0)
			var d := _top_modal()
			d.call("press_upgrade")
			await _wait(0.2)
			d.call("press_upgrade")
			await _wait(0.9)
			await _shot("hub_beat")
			await _wait(2.5)
		"unlock":
			_close_modals()
			hub.call("_show_pending_unlocks")
			await _wait(1.2)
			await _shot("hub_unlock")


func _top_modal() -> Control:
	var host: Control = hub.get("_modal_host")
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(host.get_child_count() - 1).get_meta("content")


func _close_modals() -> void:
	while hub.has_modal():
		hub.pop_modal()


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
