extends Node
## Dev tool (main.gd `-- --loop`): plays the whole meta loop through the real router and saves
## a PNG at every stop (headless: no PNGs, same path), then quits with the number of problems:
##   hub (Play) -> PLAY -> the run (bot, x`--speed`) -> Meta.finish_run -> ResultFlow (win) ->
##   "Відкрити на вівтарі" (a World Cache on a boss level) or "Далі" -> CacheAltar (strike,
##   "Відкрити все", summary, "Готово") -> hub -> a lost run (army cut to 1) -> LossScreen ->
##   "Арсенал" -> hub (Arsenal) -> quit.
## Flags: --level=N (default 8: the World 1 boss, which drops a World Cache), --profile=expected,
## --hero=bolt|titan, --speed=3, --out=DIR. The account is synthetic and never saved.

var args := {}
var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots/ws5/loop"
var main: Node
var speed := 3.0
var problems := 0
var _bot: Bot


func _ready() -> void:
	main = get_parent()
	out_dir = str(args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	speed = float(args.get("speed", "3"))
	var level := int(args.get("level", "8"))
	Save.readonly = true
	Save.level = level
	var acc := Meta.synthetic_account(level, str(args.get("profile", "expected")))
	(acc["progress"] as Dictionary)["hero"] = str(args.get("hero", "bolt"))
	Meta.account = acc
	Save.hero = str(args.get("hero", "bolt"))
	_bot = Bot.new()
	_loop.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _snap(name: String) -> void:
	print("LOOP ", name, " scene=", _scene().name if _scene() else "-", " coins=", Meta.currency("coins"), " level=", Meta.level())
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/loop_%s.png" % [out_dir, name])


func _fail(msg: String) -> void:
	problems += 1
	push_error("LOOP problem: " + msg)


func _scene() -> Node:
	var c: Variant = main.get("current")
	if c == null or not is_instance_valid(c):
		return null
	return c as Node


func _await_scene(cls: String, timeout := 20.0) -> Node:
	var t := 0.0
	while t < timeout:
		var c := _scene()
		if c and not main.get("_busy") and (c.get_script() as Script) and (c.get_script() as Script).get_global_name() == cls:
			return c
		if c and cls == "Play" and c.name == "Play" and not main.get("_busy"):
			return c
		await get_tree().process_frame
		t += get_process_delta_time()
	_fail("no %s scene after %.0f s" % [cls, timeout])
	return null


func _loop() -> void:
	main.call("show_hub", "play")
	var hub := await _await_scene("Hub") as Hub
	await _wait(2.0)
	await _snap("01_hub")
	var coins0 := Meta.currency("coins")
	var level0 := Meta.level()
	hub.play.emit()
	var holder := await _await_scene("Play")
	if holder == null:
		_quit()
		return
	var flow := await _play_run(holder, false)
	if flow == null:
		_quit()
		return
	var won := flow is ResultFlow
	if Meta.currency("coins") <= coins0:
		_fail("coins did not grow after the run (%d -> %d)" % [coins0, Meta.currency("coins")])
	if won and Meta.level() != level0 + 1:
		_fail("frontier did not advance (%d -> %d)" % [level0, Meta.level()])
	await _wait(1.2)
	await _snap("02_result_a")
	await _wait(1.6)
	await _snap("03_result_b")
	await _wait(3.5)
	await _snap("04_result_c")
	if won:
		var rf := flow as ResultFlow
		var open := _find_button(rf.root, Loc.t("OPEN_ON_ALTAR"))
		if rf.step < 7:
			rf.call("_on_next")         # "Далі" before step 7: everything lands, step 7
			await _wait(0.6)
			open = _find_button(rf.root, Loc.t("OPEN_ON_ALTAR"))
			await _snap("05_result_final")
		if open:
			open.pressed.emit()
			var altar := await _await_scene("CacheAltar") as CacheAltar
			if altar:
				await _drive_altar(altar)
		else:
			rf.call("_on_next")
	else:
		(flow as LossScreen).call("_leave", false)
	hub = await _await_scene("Hub") as Hub
	await _wait(1.5)
	await _snap("09_hub_after")
	# A lost run: the loss screen.
	if hub:
		hub.play.emit()
		holder = await _await_scene("Play")
		if holder:
			var loss := await _play_run(holder, true)
			if loss is LossScreen:
				await _wait(2.6)
				await _snap("10_loss")
				await _wait(1.5)
				await _snap("11_loss_b")
				(loss as LossScreen).call("_leave", false)
				hub = await _await_scene("Hub") as Hub
				await _wait(1.5)
				await _snap("12_hub_arsenal")
			elif loss != null:
				_fail("the forced loss showed a win flow")
	_quit()


## Plays the run in `holder` with the bot (army cut to 1 when `lose`), returns the flow node.
func _play_run(holder: Node, lose: bool) -> Node:
	var run: Run = holder.get_meta("run")
	Engine.time_scale = speed
	Juice.base_time_scale = speed
	Juice.hitstop_enabled = false
	var t := 0.0
	var cut := false
	while is_instance_valid(holder) and not holder.has_meta("flow") and t < 240.0:
		if run.state == Run.State.READY:
			run.start()
		if lose and not cut and run.state == Run.State.RUNNING and run.d > 4.0:
			run.set_army(1)
			cut = true
		if run.state != Run.State.WON and run.state != Run.State.LOST:
			_bot.think(run)
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0
	if not is_instance_valid(holder) or not holder.has_meta("flow"):
		_fail("the run did not finish (t=%.0f)" % t)
		return null
	if not holder.has_meta("bundle"):
		_fail("no bundle booked")
	print("LOOP bundle ", JSON.stringify(_brief(holder.get_meta("bundle"))))
	return holder.get_meta("flow")


func _brief(b: Dictionary) -> Dictionary:
	return {"won": b.get("won"), "level": b.get("level"), "coins": b.get("coins"), "caches": (b.get("caches", []) as Array).map(
			func(c: Dictionary) -> String: return "%s%s" % [c.get("type"), "(inline)" if c.get("inline") else ""]),
			"new_unlock": b.get("new_unlock"), "walkout": b.get("walkout"), "crowns": b.get("crowns"), "drip": (b.get("drip", []) as Array).size(),
			"duplicate": b.get("duplicate"), "assist": b.get("assist")}


func _drive_altar(altar: CacheAltar) -> void:
	await _wait(0.7)
	await _snap("06_altar_present")
	altar.call("_do_strike")
	await _wait(0.45)
	await _snap("07_altar_burst")
	await _wait(1.6)
	altar.call("_on_open_all")
	var t := 0.0
	while altar.state != "summary" and t < 30.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if altar.state != "summary":
		_fail("the altar never reached the summary")
	await _wait(1.2)
	await _snap("08_altar_summary")
	altar.call("_leave", "done", "")


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


func _quit() -> void:
	print("LOOP_DONE problems=", problems)
	get_tree().quit(problems)
