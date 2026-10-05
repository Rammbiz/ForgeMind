extends Node
## Scene router: menu <-> run, with fade transitions.
## Dev flags (after `--`): --autotest, --levelcheck, --shot=path.png, --screen=menu|run, --level=N,
## --hero=bolt|titan
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
	for tool: String in ["autotest", "levelcheck", "shot"]:
		if _args.has(tool):
			_start_dev(tool)
			return
	show_menu()


func _start_dev(tool: String) -> void:
	var path: String = {
		"autotest": "res://scripts/dev/autoplay.gd",
		"levelcheck": "res://scripts/dev/level_check.gd",
		"shot": "res://scripts/dev/screenshot.gd",
	}[tool]
	if not ResourceLoader.exists(path):
		push_error("main: missing dev tool " + path)
		get_tree().quit(1)
		return
	var dev: Node = load(path).new()
	dev.set("args", _args)
	add_child(dev)


func show_menu() -> void:
	var m := Menu.new()
	m.play.connect(start_run)
	_switch(m)


func start_run() -> void:
	_switch(make_play(Save.level, Save.hero))


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
	run.connect("finished", func(won: bool, coins: int, _reason: String):
		Save.add_coins(coins)
		if won:
			Save.level_won())
	hud.connect("retry", start_run)
	hud.connect("next", start_run)
	hud.connect("menu", show_menu)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	Audio.play_music("meadow" if level % 2 == 1 else "canyon")
	return holder


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
