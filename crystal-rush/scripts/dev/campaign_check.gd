extends Node
## Dev tool (main.gd `-- --campaign`): plays a REAL account through the real router and checks
## the Meta-1 loop end to end. Unlike --loop the save is NOT readonly: run it with a temporary
## user dir (XDG_DATA_HOME=/tmp/x godot ...) so the player's own save is never touched.
##
##   for each level: hub (ack unlock cards) -> pick a hero (rotates through the unlocked ones)
##   -> PLAY -> bot run -> Meta.finish_run (exactly once: a second finish_run must be a duplicate
##   and pay nothing) -> ResultFlow / LossScreen -> World Cache on the Altar, Vault Caches on the
##   Altar from the hub -> spend coins through the hub UI (MachineDetail two-tap upgrade, Heroes
##   level button, Barracks buy) -> the next run's profile must carry the new numbers.
##
## Flags: --to=N (last level, default 10), --speed=6, --state=FILE (JSON written at the end and,
## with --phase=verify, compared after a restart), --phase=play|verify, --hero=rotate|bolt|...,
## --new-session (a fresh UnlockQueue session: up to 2 more unlock cards),
## --out=DIR (PNGs when rendered). Exit code = number of problems.

var args := {}
var main: Node
var problems := 0
var speed := 6.0
var out_dir := ""
var _bot: Bot
var _expect := {}            ## numbers the next run's profile must carry (set after purchases)
var _hero_i := 0
var _log: Array[String] = []


func _ready() -> void:
	main = get_parent()
	speed = float(args.get("speed", "6"))
	out_dir = str(args.get("out", ""))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	Loc.set_language(str(args.get("lang", "uk")), false)
	_bot = Bot.new()
	if Save.readonly:
		_fail("Save is readonly: --campaign needs a real (temporary) save")
	print("CAMPAIGN user_dir=", OS.get_user_data_dir(), " loaded_from=", Save.loaded_from, " migrated=", Save.migrated_from,
			" level=", Meta.level(), " coins=", Meta.currency("coins"))
	if args.has("new-session"):
		# As if the player came back after more than UNLOCK_RULES.session_gap_s away.
		(Meta.account["meta"] as Dictionary)["last_session"] = 1
		Meta.call("_session_resume")
	if str(args.get("phase", "play")) == "verify":
		_verify.call_deferred()
	else:
		_campaign.call_deferred()


func _fail(msg: String) -> void:
	problems += 1
	push_error("CAMPAIGN problem: " + msg)
	_log.append("PROBLEM " + msg)


func _note(msg: String) -> void:
	print("CAMPAIGN ", msg)
	_log.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _scene() -> Node:
	var c: Variant = main.get("current")
	if c == null or not is_instance_valid(c):
		return null
	return c as Node


func _await_scene(cls: String, timeout := 30.0) -> Node:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var c := _scene()
		if c and not main.get("_busy"):
			var s := c.get_script() as Script
			if cls == "Play" and c.name == "Play":
				return c
			if s and s.get_global_name() == cls:
				return c
		await get_tree().process_frame
	_fail("no %s scene after %.0f s" % [cls, timeout])
	return null


func _snap(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/camp_%s.png" % [out_dir, name])


func _until(cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			return false
		await get_tree().process_frame
	return true


# ------------------------------------------------------------------------------ the campaign

func _campaign() -> void:
	var to := int(args.get("to", "10"))
	var guard := 0
	while Meta.level() <= to and guard < to * 3 + 6 and problems < 25:
		guard += 1
		var hub := await _hub("play")
		if hub == null:
			break
		await _ack_unlocks(hub)
		_pick_hero()
		await _open_vault_caches(hub)
		hub = await _hub("play") if not (_scene() is Hub) else _scene() as Hub
		await _ack_unlocks(hub)
		await _spend(hub)
		var lvl := Meta.level()
		await _play_level(hub, lvl)
	# The rest of the Vault and coins, so the saved state has some of everything.
	var hub2 := await _hub("play")
	if hub2:
		await _ack_unlocks(hub2)
		await _open_vault_caches(hub2)
		hub2 = await _hub("play")
		await _ack_unlocks(hub2)
		await _spend(hub2)
	_write_state()
	_quit()


func _hub(tab: String) -> Hub:
	if _scene() is Hub and not main.get("_busy"):
		var h := _scene() as Hub
		h.select_tab(tab, false)
		return h
	main.call("show_hub", tab)
	var hub := await _await_scene("Hub") as Hub
	await _wait(0.4)
	return hub


func _ack_unlocks(hub: Hub) -> void:
	if hub == null:
		return
	for _i in 8:
		await _wait(0.7)
		if not hub.has_modal():
			return
		var top: Control = (hub.get("_modals") as Array).back().get_meta("content")
		if top is Hub.UnlockCard:
			_note("unlock card at L%d" % Meta.level())
			await _snap("unlock_L%d_%d" % [Meta.level(), _i])
		hub.pop_modal()


func _pick_hero() -> void:
	var mode := str(args.get("hero", "rotate"))
	var list: Array[String] = []
	for h: String in Balance.HERO_ORDER:
		if Meta.hero_unlocked(h):
			list.append(h)
	var pick := mode
	if mode == "rotate":
		pick = list[_hero_i % list.size()]
		_hero_i += 1
	if not Meta.hero_unlocked(pick):
		pick = "bolt"
	Meta.set_hero(pick)


## Opens every Vault Cache through hub -> main.open_altar -> CacheAltar.
func _open_vault_caches(hub: Hub) -> void:
	var n := 0
	while Meta.vault().size() > 0 and n < 12 and hub != null:
		n += 1
		var before := Meta.vault().size()
		var coins0 := Meta.currency("coins")
		var owned0 := Meta.owned_ids()
		var type := str((Meta.vault()[0] as Dictionary).get("type", ""))
		hub.open_cache(0)
		var altar := await _await_scene("CacheAltar") as CacheAltar
		if altar == null:
			return
		if Meta.vault().size() != before - 1:
			_fail("Vault did not shrink after open_cache (%d -> %d)" % [before, Meta.vault().size()])
		await _drive_altar(altar, "vault_%s_L%d" % [type, Meta.level()])
		_note("vault %s opened: coins %d -> %d, owned %s -> %s" % [type, coins0, Meta.currency("coins"), owned0, Meta.owned_ids()])
		hub = await _await_scene("Hub") as Hub
		await _wait(0.4)
		await _ack_unlocks(hub)


func _drive_altar(altar: CacheAltar, tag: String) -> void:
	await _until(func() -> bool: return not is_instance_valid(altar) or float(altar.get("_clock")) >= 0.7, 20.0)
	await _snap(tag + "_a")
	altar.call("_do_strike")
	await _wait(0.6)
	altar.call("_on_open_all")
	var ok := await _until(func() -> bool: return not is_instance_valid(altar) or altar.state == "summary", 60.0)
	if not ok:
		_fail("the altar never reached the summary (state %s)" % altar.state)
	await _wait(0.8)
	await _snap(tag + "_summary")
	if is_instance_valid(altar):
		altar.call("_leave", "done", "")


# ------------------------------------------------------------------------------ purchases

func _spend(hub: Hub) -> void:
	if hub == null:
		return
	_expect.clear()
	var bought := 0
	for _i in 40:
		var b := Meta.best_upgrade()
		if b.is_empty():
			break
		var kind := str(b.get("kind", ""))
		var id := str(b.get("id", ""))
		var coins0 := Meta.currency("coins")
		var ok := false
		match kind:
			"machine":
				ok = await _buy_machine(hub, id)
			"hero":
				ok = await _buy_hero(hub, id)
			"barracks":
				ok = await _buy_barracks(hub, id)
		if not ok:
			_fail("could not buy best_upgrade %s %s through the UI (coins %d)" % [kind, id, coins0])
			break
		bought += 1
		var spent := coins0 - Meta.currency("coins")
		if spent != int(b.get("cost", spent)) and int(b.get("cost", 0)) > 0:
			_fail("%s %s cost %d but %d coins left the wallet" % [kind, id, int(b["cost"]), spent])
	if bought > 0:
		_note("bought %d upgrades, coins left %d" % [bought, Meta.currency("coins")])
	await _ack_unlocks(hub)


func _buy_machine(hub: Hub, id: String) -> bool:
	var st0 := Meta.stats(id, 1)
	var lv0 := Meta.machine_level(id)
	hub.select_tab("arsenal", false)
	await _wait(0.2)
	await _ack_unlocks(hub)
	hub.open_machine(id)
	await _wait(0.5)
	var md: MachineDetail = null
	for h: Control in hub.get("_modals"):
		if h.get_meta("content") is MachineDetail:
			md = h.get_meta("content")
	if md == null:
		_fail("MachineDetail did not open for " + id)
		return false
	md.press_upgrade()
	await _wait(0.15)
	md.press_upgrade()
	await _wait(1.2)
	if Meta.machine_level(id) != lv0 + 1:
		_fail("%s stayed Lv%d after the two-tap upgrade" % [id, Meta.machine_level(id)])
		hub.pop_modal()
		return false
	if out_dir != "" and lv0 + 1 in [3, 5, 8]:
		await _snap("detail_%s_lv%d" % [id, lv0 + 1])
	var st1 := Meta.stats(id, 1)
	if JSON.stringify(st0.get("stats")) == JSON.stringify(st1.get("stats")):
		_fail("%s Lv%d -> Lv%d did not change its stats" % [id, lv0, lv0 + 1])
	_expect["machine:" + id] = st1.get("stats")
	_note("machine %s Lv%d -> Lv%d  %s" % [id, lv0, lv0 + 1, _diff(st0.get("stats", {}), st1.get("stats", {}))])
	hub.pop_modal()
	await _wait(0.4)
	return true


func _buy_hero(hub: Hub, id: String) -> bool:
	var p0 := Meta.hero_profile(id)
	var lv0 := Meta.hero_level(id)
	hub.select_tab("heroes", false)
	await _wait(0.3)
	await _ack_unlocks(hub)
	var page: Control = hub.pages.get("heroes")
	if page == null:
		return false
	var idx := Balance.HERO_ORDER.find(id)
	page.set("_idx", idx)
	page.call("refresh")
	await _wait(0.2)
	page.call("_press_level", id)
	await _wait(0.15)
	page.call("_press_level", id)
	await _wait(0.6)
	if Meta.hero_level(id) != lv0 + 1:
		_fail("hero %s stayed Lv%d after the level button" % [id, Meta.hero_level(id)])
		return false
	var p1 := Meta.hero_profile(id)
	_expect["hero:" + id] = p1
	_note("hero %s Lv%d -> Lv%d  %s" % [id, lv0, lv0 + 1, _diff(p0, p1)])
	return true


func _buy_barracks(hub: Hub, track: String) -> bool:
	var a0 := Meta.army_profile()
	var lv0 := Meta.barracks_level(track)
	hub.select_tab("barracks", false)
	await _wait(0.3)
	await _ack_unlocks(hub)
	var page: Control = hub.pages.get("barracks")
	if page == null:
		return false
	page.call("_buy", track, null)
	await _wait(0.4)
	if Meta.barracks_level(track) != lv0 + 1:
		_fail("Barracks %s stayed Lv%d after _buy" % [track, Meta.barracks_level(track)])
		return false
	var a1 := Meta.army_profile()
	if JSON.stringify(a0) == JSON.stringify(a1):
		_fail("Barracks %s Lv%d did not change the army profile" % [track, lv0 + 1])
	_expect["army"] = a1
	_note("barracks %s Lv%d -> Lv%d  %s" % [track, lv0, lv0 + 1, _diff(a0, a1)])
	return true


func _diff(a: Dictionary, b: Dictionary) -> String:
	var out: Array[String] = []
	for k in b:
		if a.get(k) != b[k] and not (b[k] is Dictionary or b[k] is Array):
			out.append("%s %s->%s" % [k, str(a.get(k)), str(b[k])])
	return ", ".join(out)


# ------------------------------------------------------------------------------ one level

func _play_level(hub: Hub, lvl: int) -> void:
	var coins0 := Meta.currency("coins")
	var vault0 := Meta.vault().size()
	var owned0 := Meta.owned_ids()
	hub.select_tab("play", false)
	hub.play.emit()
	var holder := await _await_scene("Play")
	if holder == null:
		return
	var run: Run = holder.get_meta("run")
	_bot.reset()
	_check_profile(run)
	Engine.time_scale = speed
	Juice.base_time_scale = speed
	Juice.hitstop_enabled = false
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(holder) and not holder.has_meta("flow") and Time.get_ticks_msec() - t0 < 300000:
		if run.state == Run.State.READY:
			run.start()
		if run.state != Run.State.WON and run.state != Run.State.LOST:
			_bot.think(run)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0
	if not is_instance_valid(holder) or not holder.has_meta("flow"):
		_fail("L%d run did not finish" % lvl)
		return
	var bundle: Dictionary = holder.get_meta("bundle")
	var res: Dictionary = run.result
	var won := bool(res.get("won", false))
	var paid := int((bundle.get("coins", {}) as Dictionary).get("total", 0))
	var inline_coins := 0
	for c: Dictionary in bundle.get("caches", []):
		if bool(c.get("inline", false)):
			inline_coins += int((c.get("reveal", {}) as Dictionary).get("coins", 0))
	var delta := Meta.currency("coins") - coins0
	_note("L%d %s hero=%s army@fort=%s survivors=%s coins+%d (paid %d, inline cache %d) crowns=%s caches=%s new=%s fielded=%s" % [
			lvl, "WON" if won else "LOST", run.hero_type, str(res.get("army_at_fortress", run.get("army"))), str(res.get("survivors")), delta, paid,
			inline_coins, str(bundle.get("crowns")), str((bundle.get("caches", []) as Array).map(func(c): return c.get("type"))),
			str(bundle.get("new_unlock")), str((res.get("fielded", []) as Array).map(func(f): return "%s%d" % [f.get("id"), int(f.get("rank", 1))]))])
	if delta != paid + inline_coins:
		_fail("L%d wallet moved %d but the bundle paid %d (+%d inline cache)" % [lvl, delta, paid, inline_coins])
	# Exactly once: the same result again must be a duplicate and pay nothing.
	var c1 := Meta.currency("coins")
	var dup := Meta.finish_run(res)
	if not bool(dup.get("duplicate", false)) or Meta.currency("coins") != c1:
		_fail("L%d a second finish_run was booked again (duplicate=%s, coins %d -> %d)" % [lvl, str(dup.get("duplicate")), c1, Meta.currency("coins")])
	if won:
		if Meta.level() != lvl + 1:
			_fail("L%d won but the frontier is %d" % [lvl, Meta.level()])
		var want := EconData.win_cache(lvl)
		var got: Array = (bundle.get("caches", []) as Array).map(func(c): return str(c.get("type")))
		if want == "" and not got.is_empty():
			_fail("L%d dropped a Cache before L%d: %s" % [lvl, EconData.CACHE_FROM_LEVEL, got])
		if want != "" and not got.has(want):
			_fail("L%d should drop a %s Cache, got %s" % [lvl, want, got])
		var nc := ArsenalData.new_crate_at(lvl)
		if nc != "" and not owned0.has(nc) and not Meta.owned(nc):
			_fail("L%d won but the NEW crate machine %s is not owned" % [lvl, nc])
	await _drive_flow(holder, won, lvl)


func _check_profile(run: Run) -> void:
	var p := run.profile
	var hero_id := run.hero_type
	var crates := run.items.filter(func(it: Dictionary) -> bool: return str(it.get("kind", "")) == "crate")
	_note("L%d profile: profile=%s deck=%s lead=%s new_crate=%s owned=%s crates=%d %s" % [run.level, str(p.get("profile")),
			str(p.get("deck")), str(p.get("lead")), str(p.get("new_crate")), str(p.get("owned")), crates.size(),
			str(crates.map(func(it): return "%s%s" % [it.get("weapon"), "*" if it.get("new", false) else ""]))])
	for k: String in _expect:
		if k.begins_with("machine:"):
			var id := k.trim_prefix("machine:")
			var m: Dictionary = (p.get("machines", {}) as Dictionary).get(id, {})
			if m.is_empty():
				continue                            # not in the deck: nothing to carry
			if JSON.stringify(m.get("stats")) != JSON.stringify(_expect[k]):
				_fail("run profile %s stats %s != bought %s" % [id, JSON.stringify(m.get("stats")), JSON.stringify(_expect[k])])
			else:
				_note("next run carries %s stats (dmg %s)" % [id, str((m.get("stats", {}) as Dictionary).get("dmg"))])
		elif k.begins_with("hero:"):
			if k.trim_prefix("hero:") != hero_id:
				continue
			var h: Dictionary = p.get("hero", {})
			for key: String in ["dmg_mult", "hp_mult", "ult_rate_mult"]:
				if absf(float(h.get(key, 0)) - float((_expect[k] as Dictionary).get(key, 0))) > 1e-5:
					_fail("run profile hero %s %s=%s, bought %s" % [hero_id, key, str(h.get(key)), str((_expect[k] as Dictionary).get(key))])
			var want_hp := int(round(float(Balance.HEROES[hero_id]["hp"]) * float(h.get("hp_mult", 1.0))))
			if run.hero_hp != want_hp:
				_fail("hero hp in the run %d != base x hp_mult %d" % [run.hero_hp, want_hp])
			else:
				_note("next run hero %s hp %d (x%.2f), dmg x%.2f" % [hero_id, run.hero_hp, float(h.get("hp_mult")), float(h.get("dmg_mult"))])
		elif k == "army":
			if JSON.stringify(p.get("army")) != JSON.stringify(_expect[k]):
				_fail("run profile army %s != bought %s" % [JSON.stringify(p.get("army")), JSON.stringify(_expect[k])])
			else:
				_note("next run army block %s" % JSON.stringify(p.get("army")))
	var want_army := Balance.START_ARMY + int((p.get("assist", {}) as Dictionary).get("soldiers", 0))
	if run.army != want_army:
		_fail("start army %d != START_ARMY + assist %d" % [run.army, want_army])


func _drive_flow(holder: Node, won: bool, lvl: int) -> void:
	var flow: Node = holder.get_meta("flow")
	await _until(func() -> bool: return not is_instance_valid(flow) or float(flow.get("_clock")) >= 1.0, 30.0)
	if won:
		var rf := flow as ResultFlow
		await _snap("result_L%d" % lvl)
		rf.call("_on_next")
		await _wait(1.2)
		await _until(func() -> bool: return not is_instance_valid(rf) or rf.step >= 7 or rf.get("_walk") != null, 20.0)
		var w: Variant = rf.get("_walk")
		if w != null and is_instance_valid(w):
			await _wait(3.6)
			if is_instance_valid(w) and (w as Node).has_method("close"):
				(w as Node).call("close")
			await _wait(0.6)
			if rf.step < 7:
				rf.call("_on_next")
				await _wait(1.2)
		await _snap("result_final_L%d" % lvl)
		var open := _find_button(rf.root, Loc.t("OPEN_ON_ALTAR"))
		if open:
			open.pressed.emit()
			var altar := await _await_scene("CacheAltar") as CacheAltar
			if altar:
				await _drive_altar(altar, "world_L%d" % lvl)
		else:
			rf.call("_on_next")
	else:
		await _wait(1.5)
		await _snap("loss_L%d" % lvl)
		(flow as LossScreen).call("_leave", false)
	await _await_scene("Hub")


func _find_button(n: Node, text: String) -> Button:
	if n == null:
		return null
	if n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


# ------------------------------------------------------------------------------ persistence

func _state() -> Dictionary:
	var a := Meta.account
	var machines := {}
	for id in Meta.owned_ids():
		var st := Meta.machine_state(id)
		machines[id] = {"lvl": int(st.get("lvl", 0)), "bp": int(st.get("bp", 0)), "talents": st.get("talents", [])}
	var heroes := {}
	for h: String in Balance.HERO_ORDER:
		heroes[h] = Meta.hero_level(h)
	var barracks := {}
	for t: String in EconData.BARRACKS_ORDER:
		barracks[t] = Meta.barracks_level(t)
	return {"level": Meta.level(), "coins": Meta.currency("coins"), "crowns": Meta.currency("crowns"),
			"gems": Meta.currency("gems"), "cores": Meta.currency("cores"), "hero": Meta.hero(), "deck": Meta.deck(),
			"machines": machines, "heroes": heroes, "barracks": barracks,
			"vault": Meta.vault().map(func(c): return str(c.get("type"))), "pity": a.get("pity", {}),
			"run_seq": int((a["meta"] as Dictionary).get("run_seq", 0)), "version": int((a["meta"] as Dictionary).get("version", 0))}


func _write_state() -> void:
	var path := str(args.get("state", ""))
	var s := _state()
	print("CAMPAIGN_STATE ", JSON.stringify(s))
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(s))


func _verify() -> void:
	var path := str(args.get("state", ""))
	var want: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" and FileAccess.file_exists(path) else null
	var s := _state()
	print("CAMPAIGN_STATE ", JSON.stringify(s))
	if not want is Dictionary:
		_fail("no state file to verify: " + path)
	else:
		var w: Dictionary = want
		var a: Dictionary = JSON.parse_string(JSON.stringify(s))     # same number types as the file
		for k in w:
			if JSON.stringify(w[k]) != JSON.stringify(a.get(k)):
				_fail("after restart %s = %s, saved %s" % [k, JSON.stringify(a.get(k)), JSON.stringify(w[k])])
		if problems == 0:
			_note("restart verified: %d keys identical" % w.size())
	var cfg := ConfigFile.new()
	if cfg.load(Save.path) != OK:
		_fail("cannot read " + Save.path)
	elif int(cfg.get_value("meta", "version", 0)) != Save.VERSION:
		_fail("save.cfg is not v%d" % Save.VERSION)
	main.call("show_hub", "play")
	var hub := await _await_scene("Hub") as Hub
	await _wait(1.5)
	await _snap("verify_hub")
	if hub:
		for tab: String in ["arsenal", "heroes", "barracks", "play"]:
			if not hub.tab_bar.is_locked(tab):
				hub.select_tab(tab, false)
				await _wait(0.8)
				await _snap("verify_" + tab)
	_quit()


func _quit() -> void:
	print("CAMPAIGN_DONE problems=", problems)
	get_tree().quit(problems)
