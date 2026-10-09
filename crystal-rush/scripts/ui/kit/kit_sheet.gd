class_name KitSheet
extends PanelContainer
## UI v3.1 bottom sheet (spec §7.2): frosted cream glass (UIKit.sheet() gives it the KitGlass frost
## and the text bed under its rows; the top 20 % stays a frost ramp), its top edge a STRAIGHT
## fading 1 dpx gold rule with a light line under it and a 9 px cut-gem diamond at the centre (only
## the nav arches; no cap fill). Flat SHEET_FILL without a snapshot. Children go in like any
## PanelContainer. Motion: UIJuice.sheet_in(sheet) / sheet_out(sheet).

var arch := 10.0       ## legacy (ignored: the sheet top is straight in v3.1)
var keystone := true   ## the centre diamond


func _ready() -> void:
	if not has_theme_stylebox_override("panel"):
		add_theme_stylebox_override("panel", UIKit.lux("sheet"))
	resized.connect(queue_redraw)


func _draw() -> void:
	# Frosted: the TextBed overlay draws the rule (outside the frost material).
	if material:
		return
	KitNav.draw_arch_top(self, Rect2(Vector2.ZERO, size), arch, UITokens.CHAMFER_L, UITokens.SHEET_FILL, keystone)
