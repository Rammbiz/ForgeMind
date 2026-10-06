extends Control
## Dev-only: renders the UI-direction font shortlist through Godot's own text server
## (variable axes via FontVariation, Ukrainian Cyrillic) and saves a PNG, then quits.
## Run: godot --path . --resolution 720x1280 res://scenes/dev/skin_fonts.tscn -- --out=<dir>

const FONTS := [
	["A  Yeseva One", "res://assets/fonts/YesevaOne-Regular.ttf", {}],
	["A  Vollkorn SC Black", "res://assets/fonts/VollkornSC-Black.ttf", {}],
	["A  Bona Nova SC Bold", "res://assets/fonts/BonaNovaSC-Bold.ttf", {}],
	["A  Commissioner 700 FLAR100", "res://assets/fonts/Commissioner-VF.ttf", {"wght": 700, "FLAR": 100}],
	["B  Science Gothic 800 wdth160", "res://assets/fonts/ScienceGothic-VF.ttf", {"wght": 800, "wdth": 160}],
	["B  Unbounded 800", "res://assets/fonts/Unbounded-VF.ttf", {"wght": 800}],
	["B  Geologica 700 SHRP100", "res://assets/fonts/Geologica-VF.ttf", {"wght": 700, "SHRP": 100}],
	["C  Dela Gothic One", "res://assets/fonts/DelaGothicOne-Regular.ttf", {}],
	["C  Oi", "res://assets/fonts/Oi-Regular.ttf", {}],
	["C  Orelega One", "res://assets/fonts/OrelegaOne-Regular.ttf", {}],
	["C  Podkova 800", "res://assets/fonts/Podkova-VF.ttf", {"wght": 800}],
]
const LINE1 := "Кришталевий Ривок · Грати"
const LINE2 := "Їжак ґанок є’ · 2 590 · ×2.5 · Рів. 14"

var _out_dir := "user://"


static func make_font(path: String, axes: Dictionary) -> Font:
	var base: FontFile = load(path)
	if axes.is_empty():
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	var va := {}
	for tag in axes:
		va[TextServerManager.get_primary_interface().name_to_tag(tag)] = axes[tag]
	fv.variation_opentype = va
	return fv


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_dir = a.substr(6)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0c0e1e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var y := 14.0
	for row in FONTS:
		var f := make_font(row[1], row[2])
		var tag := Label.new()
		tag.text = row[0]
		tag.add_theme_font_size_override("font_size", 15)
		tag.add_theme_color_override("font_color", Color("78c8ff"))
		tag.position = Vector2(16, y)
		add_child(tag)
		var l1 := Label.new()
		l1.text = LINE1
		l1.add_theme_font_override("font", f)
		l1.add_theme_font_size_override("font_size", 46 if row[0].find("Oi") < 0 else 34)
		l1.add_theme_color_override("font_color", Color("ffd27a"))
		l1.add_theme_color_override("font_outline_color", Color("2a1606"))
		l1.add_theme_constant_override("outline_size", 6)
		l1.position = Vector2(16, y + 16)
		add_child(l1)
		var l2 := Label.new()
		l2.text = LINE2
		l2.add_theme_font_override("font", f)
		l2.add_theme_font_size_override("font_size", 28 if row[0].find("Oi") < 0 else 22)
		l2.add_theme_color_override("font_color", Color("f0f2ff"))
		l2.position = Vector2(16, y + 72)
		add_child(l2)
		y += 114.0
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	img.save_png(_out_dir.path_join("fonts_godot.png"))
	print("saved ", _out_dir.path_join("fonts_godot.png"))
	get_tree().quit(0)
