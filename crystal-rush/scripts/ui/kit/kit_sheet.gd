class_name KitSheet
extends PanelContainer
## UI v2 bottom sheet: the cream "sheet" body (lux "sheet": chamfered, hairline + inner
## hairline) with a shallow ARCH on its top edge (the bridge span, sag `arch` px) carrying a
## gold hairline and a crystal keystone at the centre. Children go in like any PanelContainer.
## Motion: UIJuice.sheet_in(sheet) / sheet_out(sheet).

var arch := 10.0
var keystone := true


func _ready() -> void:
	if not has_theme_stylebox_override("panel"):
		add_theme_stylebox_override("panel", UIKit.lux("sheet"))
	resized.connect(queue_redraw)


func _draw() -> void:
	KitNav.draw_arch_top(self, Rect2(Vector2.ZERO, size), arch, UITokens.CHAMFER_L, UITokens.PAPER_1, keystone)
