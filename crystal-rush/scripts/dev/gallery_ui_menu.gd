extends Node
## Dev preview of the title screen (role UI). Saves ui_menu.png (uk), ui_settings.png (uk) and
## ui_menu_en.png into the scratchpad rshots folder (or --out=DIR), then quits.
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_ui_menu.tscn

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Save.coins = 85
	Save.upgrades = {"army": 3, "power": 1}
	Save.level = 4
	Loc.set_language("uk", false)
	var menu := Menu.new()
	add_child(menu)
	await _wait(3.5)
	await _shot("ui_menu")
	menu.call("_open_settings")
	await _wait(0.7)
	await _shot("ui_settings")
	menu.call("_close_settings")
	Loc.set_language("en", false)
	await _wait(3.0)
	await _shot("ui_menu_en")
	get_tree().quit(0)


## Waits `s` seconds of game time (frame deltas; xvfb renders slowly and deltas are capped).
func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
