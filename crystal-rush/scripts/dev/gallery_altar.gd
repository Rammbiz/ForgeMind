extends Node
## Dev preview of WS5 (Altar ceremony, inline Stone reveal, NEW walkout, result and loss
## screens). Builds a synthetic account, plays each beat and saves PNGs, then quits.
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##     --resolution 720x1280 res://scenes/dev/gallery_altar.tscn -- --out=DIR --shots=a,b [--lang=en]
## Shots:
##   altar        present, strike, tell, burst, fan, flip, summary of a World Cache (best Epic)
##   burst_C|R|E|L  the burst beat in each rarity colour
##   tell_L       the Legendary tell (light pillars)
##   walkout_altar  a NEW machine card walking out on the Altar
##   inline       the inline Stone reveal (present, burst, cards)
##   walkout      the result-flow NEW machine walkout (silhouette, light, name)
##   win          the win result flow over a still backdrop (no run)
##   loss         the loss screen

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots/ws5"
var shots: Array[String] = ["altar"]
var level := 14
var _n := 0


func _ready() -> void:
	var lang := "uk"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"lang": lang = v
			"level": level = maxi(1, int(v))
			"shots":
				shots.clear()
				for s in v.split(",", false):
					shots.append(s)
	printerr("GA start")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Save.level = level
	Loc.set_language(lang, false)
	var acc := Meta.synthetic_account(level, "expected")
	(acc["wallet"] as Dictionary)["coins"] = 2480
	Meta.account = acc
	printerr("GA acc")
	MachineThumbs.service(get_tree())
	await get_tree().process_frame
	for id in ArsenalData.live_ids():
		MachineThumbs.get_thumb(self, id, false)
	printerr("GA wait")
	await _wait(1.5)
	printerr("GA waited")
	for s in shots:
		await _run_shot(s)
	print("GALLERY_ALTAR done ", _n)
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _snap(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		print("SHOT ", name, " (headless)")
		_n += 1
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "%s/%s.png" % [out_dir, name]
	img.save_png(p)
	_n += 1
	print("SHOT ", p)


## A §6.6 bundle from rows [rarity, id, count, new, bp_before, bp_after, bp_need, upgradable].
static func fake_rev(type: String, rows: Array, coins := 120) -> Dictionary:
	var cards: Array = []
	var best := "C"
	for r: Array in rows:
		cards.append({"rarity": r[0], "id": r[1], "count": r[2], "wild": str(r[1]) == "", "new": r[3],
				"guaranteed": false, "lvl": 3, "bp_before": r[4], "bp_after": r[5], "bp_need": r[6], "upgradable": r[7]})
		if CacheModels.tier(str(r[0])) > CacheModels.tier(best):
			best = str(r[0])
	(cards[cards.size() - 1] as Dictionary)["guaranteed"] = true
	return {"type": type, "source": "boss", "best": best, "altar": type == "world", "coins": coins, "cards": cards}


static func world_rev(best := "E") -> Dictionary:
	var rows := [["C", "ballista", 3, false, 4, 7, 10, false], ["C", "drone", 4, false, 6, 10, 10, true],
			["R", "cannon", 2, false, 1, 3, 6, false], ["R", "mortar", 1, false, 2, 3, 6, false]]
	match best:
		"L": rows.append(["L", "railgun", 1, false, 0, 1, 2, false])
		"R": rows.append(["R", "rockets", 2, false, 3, 5, 6, false])
		"C": rows.append(["C", "gatling", 2, false, 1, 3, 10, false])
		_: rows.append(["E", "laser", 1, false, 1, 2, 3, false])
	return fake_rev("world", rows, 232)


func _altar(rev: Dictionary) -> CacheAltar:
	var a := CacheAltar.new()
	a.setup(rev)
	add_child(a)
	return a


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _run_shot(s: String) -> void:
	printerr("GA shot ", s)
	await _clear()
	printerr("GA cleared")
	match s:
		"altar":
			var a := _altar(world_rev("E"))
			await _wait_clock(a, 0.75)
			await _snap("altar_1_present")
			a.call("_do_strike")
			await _wait_clock(a, 0.2)
			await _snap("altar_2_strike")
			await _until_state(a, "tell")
			await _wait_clock(a, 0.14)
			await _snap("altar_3_tell")
			await _until_state(a, "burst")
			await _wait_clock(a, 0.12)
			await _snap("altar_4_burst")
			await _until_state(a, "flips")
			await _wait_clock(a, 0.2)
			await _snap("altar_5_fan")
			for i in 2:
				a.call("_flip_next")
				await _until_idle(a)
			await _snap("altar_6_flip")
			a.call("_flip_next")
			await _until_idle(a)
			a.call("_flip_next")
			await _wait(0.25)
			await _snap("altar_6b_flip_rare")
			await _until_idle(a)
			a.call("_flip_next")
			await _wait(0.45)
			await _snap("altar_7_flip_epic")
			await _until_idle(a)
			await _wait(0.6)
			await _snap("altar_7b_flipped")
			await _until_state(a, "summary")
			await _wait(1.6)
			await _snap("altar_8_summary")
		"burst_C", "burst_R", "burst_E", "burst_L":
			var r := s.substr(6)
			var a := _altar(world_rev(r))
			await _wait(0.6)
			a.call("_do_strike")
			await _until_state(a, "burst")
			await _wait_clock(a, 0.1)
			await _snap("altar_burst_" + r)
		"stages":
			for r in ["C", "R", "E", "L"]:
				await _clear()
				var a := _altar(world_rev(r))
				await _wait_clock(a, 0.6)
				a.call("_do_strike")
				await _until_state(a, "tell")
				a.hold_clock = true
				await _wait(0.35)
				await _snap("stage_%s_1_tell" % r)
				CacheModels.set_crack(a.cache, 2)
				await _wait(0.3)
				await _snap("stage_%s_2_crack" % r)
				a.hold_clock = false
				await _until_state(a, "burst")
				await _wait_clock(a, 0.1)
				await _snap("stage_%s_3_burst" % r)
		"tell_L":
			var a := _altar(world_rev("L"))
			await _wait(0.6)
			a.call("_do_strike")
			await _until_state(a, "tell")
			await _wait_clock(a, 0.2)
			await _snap("altar_tell_L")
		"walkout_altar":
			var rev := fake_rev("world", [["C", "drone", 3, false, 4, 7, 10, false], ["R", "cannon", 2, false, 1, 3, 6, false],
					["R", "mortar", 1, false, 2, 3, 6, false], ["E", "railgun", 1, true, 0, 0, 3, false], ["E", "laser", 1, false, 1, 2, 3, false]], 232)
			var a := _altar(rev)
			await _wait_clock(a, 0.6)
			a.call("_do_strike")
			await _until_state(a, "flips")
			for i in 3:
				a.call("_flip_next")
				await _until_idle(a)
			a.call("_flip_next")
			await _wait(0.55)
			await _snap("altar_walk_1")
			await _wait(0.55)
			await _snap("altar_walk_2_name")
			await _wait(0.6)
			await _snap("altar_walk_3_volley")
			await _until_idle(a)
			await _wait(0.3)
			await _snap("altar_walk_4_card")
		"inline":
			var bg := _backdrop()
			var rev := fake_rev("stone", [["C", "ballista", 3, false, 4, 7, 10, false], ["C", "drone", 2, false, 8, 10, 10, true],
					["R", "cannon", 1, false, 2, 3, 6, false]], 72)
			var ir := InlineReveal.new()
			ir.setup(rev)
			ir.position = Vector2(36, 380)
			ir.size = Vector2(648, 640)
			bg.add_child(ir)
			await _wait(0.5)
			await _snap("inline_1_present")
			await _wait(0.75)
			await _snap("inline_2_burst")
			await _wait(0.5)
			await _snap("inline_3_fan")
			await _wait(1.2)
			await _snap("inline_4_cards")
		"walkout":
			var bg := _backdrop()
			var w := Walkout.new()
			w.setup("railgun", true)
			bg.add_child(w)
			await _wait(0.4)
			await _snap("walkout_1_silhouette")
			await _wait(0.6)
			await _snap("walkout_2_light")
			await _wait(0.7)
			await _snap("walkout_3_name")
			await _wait(0.75)
			await _snap("walkout_4_volley")
		"probe":
			var t0 := Time.get_ticks_msec()
			HubShowcase.owner_dais(1.5)
			printerr("GA dais ms ", Time.get_ticks_msec() - t0)
			t0 = Time.get_ticks_msec()
			var e := EggView.new("stone")
			printerr("GA egg ms ", Time.get_ticks_msec() - t0)
			t0 = Time.get_ticks_msec()
			add_child(e)
			printerr("GA egg add ms ", Time.get_ticks_msec() - t0)
			await get_tree().process_frame
			printerr("GA frame")
			await _wait(0.3)
			printerr("GA waited 0.3")
		"probe2":
			var bg := _backdrop()
			printerr("GA bg")
			await _wait(0.3)
			printerr("GA bg waited")
			var w := Walkout.new()
			w.setup("railgun", true)
			printerr("GA w new")
			bg.add_child(w)
			printerr("GA w added")
			await get_tree().process_frame
			printerr("GA w frame")
			await _wait(0.3)
			printerr("GA w waited")
		"win", "loss":
			pass


func _until_idle(a: CacheAltar) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while bool(a.get("_busy")) and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame


func _until_state(a: CacheAltar, st: String) -> void:
	var t0 := Time.get_ticks_msec()
	while a.state != st and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame


## Waits until the node's own `_clock` advanced `sec` (xvfb renders slowly).
func _wait_clock(n: Node, sec: float) -> void:
	var c0 := float(n.get("_clock"))
	var t0 := Time.get_ticks_msec()
	while float(n.get("_clock")) < c0 + sec and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame


## A dark stage backdrop on a CanvasLayer for the 2D-only shots.
func _backdrop() -> Control:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	layer.add_child(root)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, UITokens.STAGE_TOP)
	g.set_color(1, UITokens.STAGE_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	return root
