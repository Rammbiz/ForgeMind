class_name UIJuice
## Motion and feedback primitives of the meta UI (arsenal_design.md §7.1, §7.4): press bounce,
## pops, sheet slides, Balatro wobble, chip punch, haptics, and the upgrade flare (charge glow
## -> white flash 80 ms -> shockwave -> sparkles) sized by ceremony tier. Timings come from
## UITokens; everything respects Reduce Motion.

static var _last_haptic_ms := -1000


# ------------------------------------------------------------------ haptics

## One haptic pulse. Kinds (meta1_contracts.md §9): THUD, CLICK, TICK, QUICK_RISE, LOW_TICK.
## Uses the Haptics autoload when it exists; else a short Input.vibrate_handheld on mobile.
## Respects Save.vibration and keeps >= 50 ms between pulses.
static func haptic(kind := "CLICK", strength := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var h := tree.root.get_node_or_null("Haptics")
	if h and h.has_method("play"):
		h.call("play", kind, strength)
		return
	var now := Time.get_ticks_msec()
	if now - _last_haptic_ms < 50 or not bool(Save.vibration) or not OS.has_feature("mobile"):
		return
	_last_haptic_ms = now
	var ms := {"THUD": 28, "CLICK": 12, "TICK": 8, "QUICK_RISE": 18, "LOW_TICK": 10}.get(kind, 12) as int
	Input.vibrate_handheld(ms, clampf(0.25 + 0.5 * strength, 0.1, 1.0))


## A named haptic pattern (rarity_C..rarity_M, win, upgrade, weapon) via Haptics, else a THUD.
static func haptic_pattern(name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var h := tree.root.get_node_or_null("Haptics") if tree else null
	if h and h.has_method("pattern"):
		h.call("pattern", name)
	else:
		haptic("THUD", 1.0)


# ------------------------------------------------------------------ press and pops

## Press feedback for any button-like control: 0.92 while held, release -> 1.05 -> 1.0
## (~220 ms), haptic CLICK 0.5. Works for BaseButton (button_down/up) and plain Controls
## (gui_input). The pivot follows the control's centre.
static func press(c: Control, haptics := true) -> void:
	var down := func():
		c.pivot_offset = c.size * 0.5
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2.ONE * UITokens.PRESS_DOWN, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if haptics:
			haptic("CLICK", 0.5)
	var up := func():
		c.pivot_offset = c.size * 0.5
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2.ONE * UITokens.PRESS_OVER, UITokens.PRESS_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, UITokens.PRESS_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if c is BaseButton:
		(c as BaseButton).button_down.connect(down)
		(c as BaseButton).button_up.connect(up)
	else:
		c.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					down.call()
				else:
					up.call())


## True for a completed tap (mouse release / touch release) on a plain Control.
static func is_tap(e: InputEvent) -> bool:
	return e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.pressed


## Pops a control in (scale from `from` with back easing, alpha expo-out).
static func pop(c: Control, delay := 0.0, dur := UITokens.ENTER, from := 0.82) -> void:
	if UITokens.reduce_motion():
		from = 0.98
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * from
	var centre := func(): c.pivot_offset = c.size * 0.5
	if c.is_inside_tree():
		centre.call()
	c.resized.connect(centre)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops a list of controls with UITokens.STAGGER between them.
static func stagger(list: Array, delay := 0.0, step := UITokens.STAGGER, dur := UITokens.ENTER) -> void:
	var i := 0
	for c in list:
		if c is Control:
			pop(c, delay + step * i, dur)
			i += 1


## Fades a control in (alpha only; safe inside containers).
static func fade_in(c: CanvasItem, delay := 0.0, dur := UITokens.STD) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Slides a free-positioned control in from `offset` (px) to its current position.
static func slide_in(c: Control, offset: Vector2, delay := 0.0, dur := UITokens.ENTER) -> Tween:
	var to := c.position
	c.position = to + (offset * 0.2 if UITokens.reduce_motion() else offset)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", to, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.6).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tw


## Slides a free-positioned control out by `offset` and fades it (exit: faster than entrance).
static func slide_out(c: Control, offset: Vector2, dur := UITokens.EXIT) -> Tween:
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", c.position + offset, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


## Scale punch 1 -> s -> 1.
static func punch(c: Control, s := UITokens.CHIP_PUNCH, dur := UITokens.CHIP_PUNCH_TIME) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * s, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Balatro wobble: a decaying rotation shake (amp in units of ~0.25 rad).
static func wobble(c: Control, amp := UITokens.WOBBLE_AMP, dur := UITokens.WOBBLE_TIME) -> void:
	if UITokens.reduce_motion():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_method(func(t: float):
		c.rotation = amp * 0.25 * exp(-5.0 * t) * sin(t * 38.0), 0.0, 1.0, dur)
	tw.tween_callback(func(): c.rotation = 0.0)


## Chip arrival: punch + wobble (RewardFly calls this on the target).
static func chip_hit(c: Control) -> void:
	punch(c)
	wobble(c)


## Gentle endless breathing (scale) for a call-to-action. Returns the looping tween.
static func breathe(c: Control, amount := 0.035, period := 1.6) -> Tween:
	if UITokens.reduce_motion():
		return null
	c.pivot_offset = c.size * 0.5
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


# ------------------------------------------------------------------ flare

## Upgrade flare at `center` (in `host` coordinates), coloured `color`, sized by ceremony tier
## (micro | standard | full): charge glow -> white flash -> shockwave ring(s) -> sparkles.
## Returns the moment (s) of the flash, so the caller can flip the level badge then.
static func flare(host: Control, center: Vector2, color: Color, tier := "standard", radius := 120.0) -> float:
	var total := UITokens.ceremony(tier)
	var f := Flare.new()
	f.color = color
	f.radius = radius * (1.4 if tier == "full" else 1.0)
	f.charge = clampf(total * 0.35, 0.08, 0.9) if tier != "micro" else 0.05
	f.rings = 3 if tier == "full" else (2 if tier == "standard" else 1)
	f.total = maxf(total, 0.4)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size = Vector2(f.radius, f.radius) * 6.0
	f.position = center - f.size * 0.5
	host.add_child(f)
	var at := f.charge
	host.get_tree().create_timer(at).timeout.connect(func():
		if is_instance_valid(host):
			UIKit.sparkles(host, center, color.lightened(0.4), 34 if tier == "full" else 20, f.radius * 2.4))
	if tier == "full":
		haptic("QUICK_RISE", 0.6)
		host.get_tree().create_timer(at).timeout.connect(func(): haptic("THUD", 1.0))
	else:
		host.get_tree().create_timer(at).timeout.connect(func(): haptic("THUD", 0.7 if tier == "standard" else 0.4))
	return at


## The drawn part of a flare: a glow that ramps up, a white core flash, expanding rings.
class Flare extends Control:
	var color := Color(1.0, 0.8, 0.3)
	var radius := 120.0
	var charge := 0.3
	var rings := 2
	var total := 1.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > charge + total:
			queue_free()

	func _draw() -> void:
		var c := size * 0.5
		var g := UIKit.glow_texture()
		if _t < charge:
			var k := _t / maxf(charge, 0.01)
			var r := radius * (0.4 + 0.6 * k)
			draw_texture_rect(g, Rect2(c - Vector2(r, r) * 1.5, Vector2(r, r) * 3.0), false, Color(color.r, color.g, color.b, 0.5 * k))
			return
		var u := _t - charge
		var flash := 1.0 - clampf(u / UITokens.FLASH, 0.0, 1.0)
		if flash > 0.0:
			var fr := radius * 1.6
			draw_texture_rect(g, Rect2(c - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 1, 1, flash))
		var fade := 1.0 - clampf(u / total, 0.0, 1.0)
		var gr := radius * 1.3
		draw_texture_rect(g, Rect2(c - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(color.r, color.g, color.b, 0.55 * fade * fade))
		for i in rings:
			var w := clampf((u - i * 0.09) / 0.55, 0.0, 1.0)
			if w <= 0.0 or w >= 1.0:
				continue
			var e := 1.0 - pow(1.0 - w, 3.0)
			var rr := radius * (0.3 + 2.2 * e)
			draw_arc(c, rr, 0, TAU, 72, Color(color.r, color.g, color.b, 0.9 * (1.0 - w)).lightened(0.35), 10.0 * (1.0 - w) + 1.5, true)
