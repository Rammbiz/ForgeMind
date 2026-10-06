class_name Odometer
extends Control
## Rolling number (mechanical odometer): each digit column scrolls like a counter wheel, so a
## change from 1 290 to 1 310 rolls the tens wheel through 9 -> 0 -> 1. Used by the currency
## chips (RewardFly rolls them from first arrival to last + 150 ms) and the result flow.
## Thousands are grouped like Loc.num(). Draws with UIKit's bold font, a dark outline and a
## soft shadow (same look as UIKit.heading).

signal finished

@export var font_size := 30:
	set(v):
		font_size = v
		_measure()
@export var color := UIKit.TEXT
@export var outline := 6
## Horizontal alignment of the number inside the control.
@export var align := HORIZONTAL_ALIGNMENT_LEFT

var value := 0
var _shown := 0.0
var _from := 0.0
var _to := 0.0
var _t := 0.0
var _dur := 0.0
var _digit_w := 18.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure()


## Sets the number. `animate` rolls from the shown value over `duration` (ease-out).
func set_value(v: int, animate := true, duration := 0.6) -> void:
	value = v
	if not animate or UITokens.reduce_motion() or not is_inside_tree():
		_shown = float(v)
		_dur = 0.0
		_measure()
		queue_redraw()
		return
	_from = _shown
	_to = float(v)
	_t = 0.0
	_dur = maxf(duration, 0.05)
	_measure()


## Rolls to `v` without changing the final `value` bookkeeping order (alias for clarity).
func roll_to(v: int, duration := 0.6) -> void:
	set_value(v, true, duration)


func _process(delta: float) -> void:
	if _dur <= 0.0:
		return
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	_shown = lerpf(_from, _to, e)
	if k >= 1.0:
		_shown = _to
		_dur = 0.0
		finished.emit()
	queue_redraw()


func _measure() -> void:
	var f := UIKit.font(true)
	_digit_w = f.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var chars := _text_for(maxi(absi(value), absi(int(_shown)))).length()
	custom_minimum_size = Vector2(chars * _digit_w + outline, f.get_height(font_size))
	queue_redraw()


func _text_for(n: int) -> String:
	if Engine.get_main_loop() and (Engine.get_main_loop() as SceneTree).root.has_node("Loc"):
		return Loc.num(n)
	return str(n)


func _draw() -> void:
	var f := UIKit.font(true)
	var x_val := maxf(_shown, 0.0)
	var target := int(round(x_val)) if _dur <= 0.0 else int(floor(x_val))
	var text := _text_for(maxi(target, int(_to) if _dur > 0.0 else target))
	# Digits in the final text (right-aligned positions) map to powers of ten.
	var digits := 0
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += 1
	var sep_w := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.6
	var total_w := 0.0
	for ch in text:
		total_w += _digit_w if (ch >= "0" and ch <= "9") else sep_w
	var x := 0.0
	match align:
		HORIZONTAL_ALIGNMENT_CENTER: x = (size.x - total_w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT: x = size.x - total_w
	var line_h := f.get_height(font_size)
	var base_y := (size.y - line_h) * 0.5 + f.get_ascent(font_size)
	var clip_top := (size.y - line_h) * 0.5
	var k := digits - 1
	for ch in text:
		if not (ch >= "0" and ch <= "9"):
			x += sep_w
			continue
		var unit := pow(10.0, float(k))
		var q := floor(x_val / unit)
		var d := int(fposmod(q, 10.0))
		var rem := x_val - q * unit
		var roll := 0.0
		if _dur > 0.0:
			roll = fposmod(x_val, 1.0) if k == 0 else clampf(rem - (unit - 1.0), 0.0, 1.0)
		# Leading zeros of a shorter shown number stay blank.
		var blank := q <= 0.0 and k > 0 and x_val < unit
		if not blank:
			_digit(f, str(d), Vector2(x, base_y - roll * line_h), clip_top, line_h, 1.0 - roll)
		if roll > 0.0 and not (blank and d == 9):
			_digit(f, str((d + 1) % 10), Vector2(x, base_y + (1.0 - roll) * line_h), clip_top, line_h, roll)
		x += _digit_w
		k -= 1


func _digit(f: Font, s: String, pos: Vector2, clip_top: float, line_h: float, alpha: float) -> void:
	if pos.y - f.get_ascent(font_size) > clip_top + line_h * 0.85 or pos.y < clip_top + line_h * 0.2:
		return
	var cw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p := pos + Vector2((_digit_w - cw) * 0.5, 0)
	var a := clampf(alpha * 1.6, 0.0, 1.0)
	draw_string_outline(f, p + Vector2(0, maxf(2.0, font_size / 14.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline + 4, Color(0, 0, 0.04, 0.45 * a))
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(0.02, 0.03, 0.08, 0.95 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, color.a * a))
