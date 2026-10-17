extends Node
## Dev-only driver for UI direction C «Емаль і золото» (Toy Enamel Kit): builds each mockup
## screen, saves a 720x1280 PNG and quits. New files only; nothing in the live hub uses it.
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##     --resolution 720x1280 res://scenes/dev/skin_enamel.tscn -- --out=DIR --shots=home,arsenal,modal,specimen

const SCREENS := {
	"home": "res://scripts/ui/skins/enamel/enamel_home.gd",
	"arsenal": "res://scripts/ui/skins/enamel/enamel_arsenal.gd",
	"modal": "res://scripts/ui/skins/enamel/enamel_modal.gd",
	"specimen": "res://scripts/ui/skins/enamel/enamel_specimen.gd",
}

var out_dir := "user://skins"
var shots: Array[String] = ["home", "arsenal", "modal", "specimen"]
var tag := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"tag": tag = v
			"shots":
				shots.clear()
				for s in v.split(",", false):
					shots.append(s)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Loc.set_language("uk", false)
	get_viewport().msaa_2d = Viewport.MSAA_4X
	MachineThumbs.service(get_tree())
	await get_tree().process_frame
	for s in shots:
		var scr: Node = (load(SCREENS[s]) as GDScript).new()
		add_child(scr)
		await scr.prepared()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := out_dir.path_join("enamel_%s%s.png" % [s, tag])
		img.save_png(path)
		print("saved ", path)
		scr.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit(0)
