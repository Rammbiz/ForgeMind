class_name KitTitlePlate
extends Control
## UI v3.1 title / world ribbon (§7.4): a slim glass plate (1 dpx gold + 1 dpx light), Medium text with chamfered ends, a gold
## hairline and tiny cut-gem marquise terminals outside both ends ("Світ 2 · Луки · Рівень 14").
## Bitmap override: ribbon.png (nine-patch via lux "ribbon").

var text := "":
	set(v):
		text = v
		queue_redraw()
var font_size := 22
var on_scene := true          ## stronger shadow when it floats over a 3D scene
var accent := ""              ## optional accent word drawn in gold_text (Genshin: one accent word)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var term := 14.0
	var r := Rect2(Vector2(term, 0), Vector2(size.x - term * 2.0, size.y))
	draw_style_box(UIKit.lux("ribbon" if not on_scene else "pill"), r)
	var y := size.y * 0.5
	GemDraw.draw_marquise(self, Vector2(term * 0.5, y), Vector2(1, 0), 10.0)
	GemDraw.draw_marquise(self, Vector2(size.x - term * 0.5, y), Vector2(1, 0), 10.0)
	var f := UIKit.font_w("medium")
	var fs := font_size
	while fs > 20 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 32.0:
		fs -= 1
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := y + f.get_ascent(fs) * 0.38 + 1.0
	var x := (size.x - tw) * 0.5
	if accent != "" and text.find(accent) >= 0:
		var i := text.find(accent)
		var pre := text.substr(0, i)
		var post := text.substr(i + accent.length())
		draw_string(f, Vector2(x, base), pre, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
		x += f.get_string_size(pre, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(x, base), accent, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.GOLD_TEXT_GLASS)
		x += f.get_string_size(accent, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(x, base), post, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
	else:
		draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
