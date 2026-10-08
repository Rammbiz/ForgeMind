class_name KitSocket
extends Control
## UI v2 round socket: a cream (or slate) disc with a thin gold ring and a line icon - class /
## element / faction sockets, info dots, the "badge ring". With `badge_text` set it is the gold
## notify badge instead (gold disc, deep-brown glyph, white rim).
## Bitmap overrides: socket_cream.png / socket_slate.png / badge_notify.png (square, any size).

signal pressed

var icon := "":
	set(v):
		icon = v
		queue_redraw()
var slate := false
var icon_color := Color(0, 0, 0, 0)     ## (0,0,0,0) = auto: ink on cream, gold_hi on slate
var badge_text := "":
	set(v):
		badge_text = v
		queue_redraw()
var ring := true


func _ready() -> void:
	if mouse_filter != Control.MOUSE_FILTER_IGNORE and pressed.get_connections().size() == 0:
		mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(e: InputEvent) -> void:
	if UIJuice.is_tap(e):
		pressed.emit()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5 - 1.0
	if badge_text != "":
		_draw_badge(c, r)
		return
	var tex := UIKit.kit_texture("socket_slate" if slate else "socket_cream")
	# v3: a whisper of shadow, 1-device-px rings.
	var lw := UIKit.px(1.0)
	draw_circle(c + Vector2(0, 1.5), r + 0.5, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.07))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	elif slate:
		draw_circle(c, r, UITokens.SOCKET)
		draw_circle(c + Vector2(0, -r * 0.12), r * 0.8, UITokens.SOCKET.lightened(0.07))
		draw_arc(c, r - lw * 0.5, 0, TAU, 64, UITokens.HAIRLINE, lw, true)
		draw_arc(c, r - 4.0, 0, TAU, 64, Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.3), lw, true)
	else:
		draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.88))
		if ring:
			draw_arc(c, r - lw * 0.5, 0, TAU, 64, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), lw, true)
			draw_arc(c, r - lw * 1.5, PI * 1.05, PI * 1.75, 24, Color(1, 1, 1, 0.7), lw, true)
	if icon != "":
		var col := icon_color
		if col.a <= 0.0:
			col = UITokens.GOLD_HI if slate else UITokens.INK
		var isz := r * 1.18
		Icons.draw_icon(self, icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), col)


func _draw_badge(c: Vector2, r: float) -> void:
	var tex := UIKit.kit_texture("badge_notify")
	draw_circle(c + Vector2(0, 1.5), r, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.22))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		draw_circle(c, r, Color(1, 0.98, 0.92))
		draw_circle(c, r - 1.5, Color("#E39A35"))
		draw_circle(c + Vector2(0, -r * 0.12), r * 0.78, UITokens.NOTIFY.lightened(0.12))
	var f := UIKit.font_w("extrabold")
	var fs := int(r * 1.25)
	if badge_text.length() > 1:
		fs = int(r * 1.0)
	var tw := f.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(c.x - tw * 0.5, c.y + f.get_ascent(fs) * 0.36 + 0.5), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.BROWN)
