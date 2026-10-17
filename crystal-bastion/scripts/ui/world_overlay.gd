class_name WorldOverlay
extends Control
## Draws enemy health bars and floating texts on top of the 3D view.

var game: Game
var _texts: Array = []   # {pos: Vector3 or null, screen: Vector2, text, color, t, life, big}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func add_text(world_pos: Vector3, text: String, color: Color, life := 1.0, big := false) -> void:
	if _texts.size() > 60:
		_texts.pop_front()
	_texts.append({"pos": world_pos, "screen": Vector2.ZERO, "text": text, "color": color, "t": 0.0, "life": life, "big": big, "world": true})


func add_screen_text(screen_pos: Vector2, text: String, color: Color, life := 1.2) -> void:
	_texts.append({"pos": Vector3.ZERO, "screen": screen_pos, "text": text, "color": color, "t": 0.0, "life": life, "big": true, "world": false})


func _process(delta: float) -> void:
	# Use unscaled time so popups read well at 2x/3x speed.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	for i in range(_texts.size() - 1, -1, -1):
		_texts[i]["t"] += real_delta
		if _texts[i]["t"] >= _texts[i]["life"]:
			_texts.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if game == null or game.cam == null:
		return
	var cam := game.cam
	var font := UIKit.font(true)
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e.hp >= e.max_hp and not e.boss:
			continue
		var head := e.global_position + Vector3(0, e.size * 2.2 + (0.25 if e.flying else 0.3), 0)
		if cam.is_behind(head):
			continue
		var p := cam.world_to_screen(head)
		var w := 78.0 if e.boss else 40.0
		var h := 9.0 if e.boss else 6.0
		var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
		var bg := Rect2(p - Vector2(w * 0.5 + 2.0, h * 0.5 + 2.0), Vector2(w + 4.0, h + 4.0))
		draw_rect(bg, Color(0.02, 0.02, 0.05, 0.75))
		var col := Color(0.35, 0.95, 0.35).lerp(Color(1.0, 0.85, 0.2), clampf((0.7 - ratio) / 0.4, 0.0, 1.0))
		col = col.lerp(Color(1.0, 0.25, 0.2), clampf((0.35 - ratio) / 0.35, 0.0, 1.0))
		if e.slow_time > 0.0:
			col = col.lerp(Color(0.5, 0.85, 1.0), 0.55)
		draw_rect(Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w * ratio, h)), col)
		draw_rect(Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w * ratio, h * 0.4)), Color(1, 1, 1, 0.25))
		if e.boss:
			Icons.draw_icon(self, "skull", Rect2(p - Vector2(w * 0.5 + 26.0, 12.0), Vector2(22, 22)), Color(1.0, 0.85, 0.75))
	for h in game.heroes:
		if not h.alive:
			continue
		var top := h.bar_point()
		if cam.is_behind(top):
			continue
		var hp_ := cam.world_to_screen(top)
		var hw := 48.0
		var hh := 7.0
		var hr := clampf(h.hp / h.max_hp, 0.0, 1.0)
		var frame := UIKit.GOLD if h.selected else Color(0.02, 0.02, 0.05, 0.8)
		draw_rect(Rect2(hp_ - Vector2(hw * 0.5 + 2.0, hh * 0.5 + 2.0), Vector2(hw + 4.0, hh + 4.0)), frame)
		draw_rect(Rect2(hp_ - Vector2(hw * 0.5, hh * 0.5), Vector2(hw, hh)), Color(0.08, 0.08, 0.12, 0.9))
		var hcol := h.color.lightened(0.25).lerp(Color(1.0, 0.3, 0.25), clampf((0.4 - hr) / 0.4, 0.0, 1.0))
		draw_rect(Rect2(hp_ - Vector2(hw * 0.5, hh * 0.5), Vector2(hw * hr, hh)), hcol)
		draw_rect(Rect2(hp_ - Vector2(hw * 0.5, hh * 0.5), Vector2(hw * hr, hh * 0.4)), Color(1, 1, 1, 0.3))
		Icons.draw_icon(self, "star", Rect2(hp_ - Vector2(hw * 0.5 + 22.0, 10.0), Vector2(18, 18)), h.color.lightened(0.4))
	for tx in _texts:
		var k: float = tx["t"] / tx["life"]
		var pos: Vector2
		if tx["world"]:
			if cam.is_behind(tx["pos"]):
				continue
			pos = cam.world_to_screen(tx["pos"])
		else:
			pos = tx["screen"]
		pos.y -= 46.0 * (1.0 - pow(1.0 - k, 2.0))
		var alpha := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var fs := 30 if tx["big"] else 20
		var scale_in := minf(1.0, k * 8.0)
		fs = int(fs * (0.6 + 0.4 * scale_in))
		var text: String = tx["text"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := pos - Vector2(tw * 0.5, 0)
		var col: Color = tx["color"]
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.05, 0.03, 0.02, alpha * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, alpha))
