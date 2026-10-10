extends Node
## Scene router: hub (Hub, the meta home screen) <-> run <-> Cache Altar, with fade transitions.
## A finished run is booked ONCE through Meta.finish_run(run.result) (coins, Crowns, drip,
## Caches, frontier - saved before anything animates), then the ResultFlow (win) or the
## LossScreen (loss) plays over the run's last frame. World Caches open on the CacheAltar
## (from the result flow or the hub's Vault via Hub.open_altar).
## Dev flags (after `--`): --autotest, --levelcheck, --loop, --campaign, --shot=path.png, --screen=menu|run,
## --level=N, --hero=bolt|titan, --heroes_phase=N [--team=id,id] (dev runs only, see _dev_heroes),
## --preview (the preview build's launcher on a PC; Preview)
## The run scripts are loaded on demand, so the router (menu, level_check) still works while
## the run code is being rewritten.

const RUN_SCRIPT := "res://scripts/run/run.gd"
const HUD_SCRIPT := "res://scripts/ui/run_hud.gd"

var current: Node
var _fade: ColorRect
var _busy := false
var _args := {}


func _ready() -> void:
	Save.apply_performance()
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.04, 0.1, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_dev_heroes()
	for tool: String in ["autotest", "levelcheck", "shot", "loop", "campaign"]:
		if _args.has(tool):
			_start_dev(tool)
			return
	show_menu()


## Dev runs only (Save.readonly: --autotest / --shot), never the shipped flow:
## --heroes_phase=N sets EconData.phase_override (2 = champions in the run, heroes design §13.2)
## and rebuilds the synthetic account under it; --team=id,id,.. (with it) fields those champions,
## owned or not, in the team (up to 4, team order).
func _dev_heroes() -> void:
	if not Save.readonly or not _args.has("heroes_phase"):
		return
	EconData.phase_override = maxi(int(_args["heroes_phase"]), -1)
	Meta.load_account()
	if not _args.has("team") or not EconData.heroes_run():
		return
	_field_team(Array(str(_args["team"]).split(",", false)))


## Fields champions `ids` (owned or not, up to 4, team order) in the synthetic account's team (dev runs).
func _field_team(ids_in: Array) -> void:
	var acc: Dictionary = Meta.account
	var roster: Dictionary = (acc["champions"] as Dictionary)["roster"]
	var ids: Array = []
	for id in ids_in:
		if ChampionData.CHAMPIONS.has(str(id)) and not ids.has(str(id)) and ids.size() < 4:
			ids.append(str(id))
			if not roster.has(str(id)):
				roster[str(id)] = EconData.new_champion_state(str(id), true, "dev")
	(acc["team"] as Dictionary)["champions"] = ids


## The preview build's home (Preview): pick a hero, champions and a level, then play.
func show_preview() -> void:
	var l := PreviewLauncher.new()
	l.play.connect(_preview_play)
	_switch(l)


## A preview run: the EXPECTED account at `level` under the heroes run phase, `hero` leading `team`.
func _preview_play(hero: String, team: Array, level: int) -> void:
	Save.level = level
	Save.hero = hero
	EconData.phase_override = EconData.HEROES_RUN_PHASE
	Meta.load_account()
	(Meta.account["team"] as Dictionary)["hero"] = hero
	_field_team(team)
	start_run()


func _start_dev(tool: String) -> void:
	var path: String = {
		"autotest": "res://scripts/dev/autoplay.gd",
		"levelcheck": "res://scripts/dev/level_check.gd",
		"shot": "res://scripts/dev/screenshot.gd",
		"loop": "res://scripts/dev/loop_check.gd",
		"campaign": "res://scripts/dev/campaign_check.gd",
	}[tool]
	if not ResourceLoader.exists(path):
		push_error("main: missing dev tool " + path)
		get_tree().quit(1)
		return
	var dev: Node = load(path).new()
	dev.set("args", _args)
	add_child(dev)


## The home screen: the meta hub on its Play tab.
func show_menu() -> void:
	if Preview.on():
		show_preview()
		return
	show_hub("play")


## The meta hub (Hub) opened on `tab` (play | arsenal | heroes | barracks | shop); the loss
## screen's "Арсенал" button uses show_hub("arsenal"). `machine` opens that machine's detail
## (the result flow's Best-upgrade row, the Altar's "Покращити <machine>").
func show_hub(tab := "play", machine := "") -> Hub:
	if Preview.on():
		show_preview()
		return null
	var h := Hub.new(tab)
	h.play.connect(start_run)
	h.open_altar.connect(open_altar)
	if machine != "":
		h.ready.connect(func():
			if is_instance_valid(h):
				h.open_machine(machine), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	_switch(h)
	return h


## Opens the Vault Cache `index` on the Altar. Meta.open_cache rolls, grants and SAVES first;
## the ceremony only shows the result.
func open_altar(index: int) -> void:
	var rev := Meta.open_cache(index)
	if rev.is_empty():
		return
	show_altar(rev)


## The Cache opening ceremony for a reveal bundle (§6.6); "Готово" returns to the hub's Play
## tab, "Покращити <machine>" to that machine in the Arsenal.
func show_altar(rev: Dictionary) -> CacheAltar:
	var a := CacheAltar.new()
	a.setup(rev)
	a.done.connect(func(action: String, id: String):
		if action == "upgrade" and id != "":
			show_hub("arsenal", id)
		else:
			show_hub("play"))
	_switch(a)
	return a


func start_run() -> void:
	_switch(make_play(Meta.level(), Meta.hero()))


## A run with its HUD, wired to the router. Dev tools use it too.
func make_play(level: int, hero: String) -> Node:
	var holder := Node.new()
	holder.name = "Play"
	var run: Node3D = (load(RUN_SCRIPT) as GDScript).new()
	run.call("setup", level, hero)
	holder.add_child(run)
	var hud: CanvasLayer = (load(HUD_SCRIPT) as GDScript).new()
	hud.call("setup", run)
	holder.add_child(hud)
	run.connect("finished", func(won: bool, _coins: int, _reason: String): _on_run_finished(holder, won))
	hud.connect("retry", start_run)
	hud.connect("next", start_run)
	hud.connect("menu", show_menu)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	Audio.play_music("meadow" if level % 2 == 1 else "canyon")
	return holder


## The Best-upgrade row's target: a machine opens its detail in the Arsenal, a hero the
## Heroes tab, a Barracks track the Barracks tab.
func open_best(id: String) -> void:
	if ArsenalData.MACHINES.has(id):
		show_hub("arsenal", id)
	elif EconData.BARRACKS.has(id):
		show_hub("barracks")
	else:
		show_hub("heroes")


## The run ended: book it exactly once (Meta.finish_run pays, saves and returns the bundle),
## then the win ResultFlow or the LossScreen over the run (autotest books but shows nothing).
func _on_run_finished(holder: Node, won: bool) -> void:
	if not is_instance_valid(holder) or holder.has_meta("bundle"):
		return
	var run: Node = holder.get_meta("run")
	var res: Dictionary = run.get("result") if run.get("result") is Dictionary else {}
	if res.is_empty():
		res = {"won": won}
	var bundle := Meta.finish_run(res)
	holder.set_meta("bundle", bundle)
	if _args.has("autotest") and res.has("team_report"):
		_print_champions(run, res)
	if _args.has("autotest") or _args.has("levelcheck"):
		return
	var hud: CanvasLayer = holder.get_meta("hud")
	var view: Variant = hud.get("view")
	if view is Control:
		var v := view as Control
		v.create_tween().tween_property(v, "modulate:a", 0.0, 0.25)
	# The big army count over the hero would print through the flow's scrim.
	run.set("hide_army_label", true)
	var al: Variant = run.get("_army_label")
	if al is Label3D and is_instance_valid(al):
		(al as Label3D).visible = false
	if won:
		var flow := ResultFlow.new()
		flow.setup(bundle, res)
		flow.next.connect(func(): show_hub("play"))
		flow.altar.connect(func(index: int): open_altar(index))
		flow.upgrade.connect(open_best)
		holder.add_child(flow)
		holder.set_meta("flow", flow)
	else:
		var loss := LossScreen.new()
		loss.setup(bundle, res)
		loss.retry.connect(start_run)
		loss.arsenal.connect(func(): show_hub("arsenal"))
		holder.add_child(loss)
		holder.set_meta("flow", loss)


## Autotest with champions: one CHAMPIONS line per level (members as id:slot:alive and the run's
## team_report) and one CHAMPIONS_PERF line (Champions.step cost, the placeholders' budget).
## (Duck-typed like the rest of the router: the run scripts stay loaded on demand.)
func _print_champions(run: Node, res: Dictionary) -> void:
	var ch: Variant = run.get("champions")
	var ms: Variant = (ch as Object).get("members") if ch is Object else null
	var parts: Array[String] = []
	if ms is Array:
		for m: Dictionary in ms:
			parts.append("%s:%s:%s" % [str(m["id"]), str(m["slot"]), str(bool(m["alive"]))])
	print("CHAMPIONS level=%d members=%s report=%s" % [int(res.get("level", 0)), ",".join(parts),
			JSON.stringify(res["team_report"])])
	var perf: Variant = run.get("champ_perf")
	var cv: Variant = run.get("champ_view")
	if perf is Dictionary:
		var p: Dictionary = perf
		var steps := maxi(int(p["steps"]), 1)
		var bud: Variant = (cv as Object).call("budget") if cv is Object and (cv as Object).has_method("budget") else {}
		var own := float(int(p["us"]) - int(p.get("hit_us", 0)) - int(p.get("fx_us", 0))) / float(steps)
		print("CHAMPIONS_PERF level=%d step_us_avg=%.1f rules_us_avg=%.1f step_us_max=%d steps=%d over_250us=%d"
				% [int(res.get("level", 0)), float(p["us"]) / float(steps), own, int(p["max_us"]), int(p["steps"]),
				int(p.get("over_250us", 0))] + " budget=" + JSON.stringify(bud))


func _switch(next: Node, instant := false) -> void:
	if _busy:
		next.queue_free()
		return
	_busy = true
	get_tree().paused = false
	if current:
		current.process_mode = Node.PROCESS_MODE_DISABLED
	if current and not instant:
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := _fade_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.25)
		await tw.finished
	if current:
		current.queue_free()
		await get_tree().process_frame
	current = next
	add_child(next)
	move_child(next, 0)
	# A pause requested during the fade (Android back, focus loss) must not freeze the new scene.
	get_tree().paused = false
	await get_tree().process_frame
	var tw2 := _fade_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_tween() -> Tween:
	return _fade.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)


## Used by dev tools: switch immediately without fades.
func set_scene_now(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.color.a = 0.0
