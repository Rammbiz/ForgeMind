extends Node
## Dev parse check for the UI role's scripts (loads each one with autoloads present), then quits.
##   godot --headless --path . res://scenes/dev/gallery_ui_check.tscn

const FILES := [
	"res://scripts/ui/ui_kit.gd", "res://scripts/ui/icons.gd", "res://scripts/ui/round_button.gd",
	"res://scripts/ui/hud_view.gd", "res://scripts/ui/run_hud.gd", "res://scripts/ui/menu.gd",
	"res://scripts/main.gd", "res://scripts/autoload/loc.gd", "res://scripts/dev/gallery_ui_hud.gd",
	"res://scripts/dev/gallery_ui_menu.gd",
]


func _ready() -> void:
	var bad := 0
	for f: String in FILES:
		var s := load(f) as GDScript
		if s == null or not s.can_instantiate():
			print("UICHECK FAIL ", f)
			bad += 1
		else:
			print("UICHECK ok ", f)
	get_tree().quit(bad)
