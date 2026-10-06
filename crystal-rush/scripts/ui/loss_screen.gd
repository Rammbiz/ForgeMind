class_name LossScreen
extends CanvasLayer
## The loss screen (arsenal_design.md §4.4, §7.2): no ad, no offer, no revive prompt - just
## what the attempt still earned, from the bundle Meta.finish_run() returned (booked and SAVED
## before this node exists).
##   * how far the army got: "Пройдено 72% мосту" on a bridge bar with the hero marker;
##   * the payout ((0.25 × victory(L, 0) + 0.70 × pickups) × fraction), rolled and flown
##     into the coin chip;
##   * the Stone Cache charge 1/3 per loss from L6 (three = a Stone Cache, opened inline or
##     sent to the Vault);
##   * the fielded machines' half drip, a NEW machine kept from its crate (walkout);
##   * the Reinforcements chip for the next attempt ("Підкріплення +15%" and what it gives);
##   * "Ще раз" (primary, signal retry) and "Арсенал" (signal arsenal).
## Both buttons are live from 0.5 s; leaving lands every reward at once. Android back = Арсенал.

signal retry
signal arsenal

const TAP_FROM := 0.5

var bundle: Dictionary = {}
var result: Dictionary = {}
var root: Control

var _t := 0.0
var _ins := Vector4.ZERO
var _vp := Vector2(720, 1280)
var _events: Array = []
var _clock := 0.0
var _chip: HubTopBar.HubChip
var _bar: BridgeBar
var _odo: Odometer
var _charge: ChargePips
var _drip: HBoxContainer
var _assist: Control
var _mid: Control
var _inline: InlineReveal
var _walk: Walkout
var _retry_btn: Button
var _arsenal_btn: Button
var _flown := false
var _left := false


func setup(p_bundle: Dictionary, p_result: Dictionary) -> void:
	bundle = p_bundle
	result = p_result


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_vp = root.get_viewport_rect().size
	_ins = UIKit.safe_insets(root.get_viewport())
	root.add_child(ResultFlow.scrim(_vp, 0.5, 0.95))
	var gain := 0 if bool(bundle.get("duplicate", false)) else int((bundle.get("coins", {}) as Dictionary).get("total", 0)) + _inline_coins()
	_chip = ResultFlow.coin_chip(root, int(bundle.get("coins_balance", Meta.currency("coins"))) - gain, _ins, _vp)
	var lvl := UIKit.heading(Loc.f("LEVEL", [int(bundle.get("level", result.get("level", 1)))]), 30, UIKit.TEXT, 6)
	lvl.position = Vector2(24 + _ins.x, _ins.y + 30)
	root.add_child(lvl)
	var rib := ResultFlow.ribbon(Loc.t("DEFEAT"), false, _vp.x)
	rib.position = Vector2(0, _ins.y + 112)
	root.add_child(rib)
	var why := UIKit.heading(Loc.t(str(result.get("reason", "ARMY_LOST"))), 28, UIKit.TEXT_DIM, 5)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.size = Vector2(_vp.x, 36)
	why.position = Vector2(0, _ins.y + 226)
	root.add_child(why)
	UIJuice.fade_in(why, 0.3)
	_build_progress()
	_build_payout()
	_build_charge()
	_mid = Control.new()
	_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid.position = Vector2(0, _ins.y + 590)
	_mid.size = Vector2(_vp.x, 400)
	root.add_child(_mid)
	_drip = ResultFlow.drip_strip(bundle.get("drip", []), _vp.x)
	_drip.position = Vector2(0, 0)
	_drip.modulate.a = 0.0
	_mid.add_child(_drip)
	_build_assist()
	_retry_btn = UIKit.button(Loc.t("RETRY"), true, 440.0)
	_retry_btn.custom_minimum_size.y = 96
	_retry_btn.add_theme_font_size_override("font_size", 42)
	_retry_btn.size = Vector2(440, 96)
	_retry_btn.position = Vector2((_vp.x - 440) * 0.5, _vp.y - 214 - _ins.w)
	_retry_btn.pressed.connect(func(): _leave(true))
	root.add_child(_retry_btn)
	_arsenal_btn = UIKit.styled_button(Loc.t("ARSENAL_BTN"), "button", Vector2(320, 76), 30)
	_arsenal_btn.position = Vector2((_vp.x - 320) * 0.5, _vp.y - 104 - _ins.w)
	_arsenal_btn.pressed.connect(func(): _leave(false))
	root.add_child(_arsenal_btn)
	for b: Control in [_retry_btn, _arsenal_btn]:
		b.modulate.a = 0.0
	_at(TAP_FROM, func():
		UIJuice.pop(_retry_btn, 0.0)
		UIJuice.pop(_arsenal_btn, 0.08)
		UIKit.add_shine(_retry_btn, 30.0, 0.8, 2.6, 0.45))
	Audio.play("defeat", -3.0)
	_at(0.3, _step_progress)


func _at(t: float, fn: Callable) -> void:
	_events.append([_clock + t, fn])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	_t += delta
	_clock += delta
	while not _events.is_empty() and float(_events[0][0]) <= _clock:
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()


func _inline_coins() -> int:
	var n := 0
	for c in bundle.get("caches", []):
		if bool((c as Dictionary).get("inline", false)):
			n += int(((c as Dictionary).get("reveal", {}) as Dictionary).get("coins", 0))
	return n


func _frac() -> float:
	var c := bundle.get("coins", {}) as Dictionary
	return clampf(float(c.get("bridge_fraction", result.get("bridge_fraction", 0.0))), 0.0, 1.0)


# ------------------------------------------------------------------ build

func _build_progress() -> void:
	var lbl := UIKit.heading(Loc.f("LOSS_PROGRESS", [int(round(_frac() * 100.0))]), 32, UIKit.TEXT, 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(_vp.x, 40)
	lbl.position = Vector2(0, _ins.y + 284)
	lbl.modulate.a = 0.0
	lbl.name = "ProgressLabel"
	root.add_child(lbl)
	_bar = BridgeBar.new()
	_bar.size = Vector2(_vp.x - 120, 64)
	_bar.position = Vector2(60, _ins.y + 330)
	_bar.modulate.a = 0.0
	root.add_child(_bar)


func _build_payout() -> void:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(_vp.x, 96)
	row.position = Vector2(0, _ins.y + 410)
	row.name = "Payout"
	row.modulate.a = 0.0
	root.add_child(row)
	var cap := UIKit.heading(Loc.t("RF_EARNED"), 26, UIKit.TEXT_DIM, 5)
	cap.position = Vector2(_vp.x * 0.5 - 240, 30)
	row.add_child(cap)
	var coin := Icons.make("coin", 64.0)
	coin.position = Vector2(_vp.x * 0.5 - 40, 14)
	row.add_child(coin)
	_odo = Odometer.new()
	_odo.font_size = 72
	_odo.color = UIKit.GOLD_LIGHT
	_odo.outline = 10
	_odo.position = Vector2(_vp.x * 0.5 + 34, 4)
	_odo.size = Vector2(260, 90)
	_odo.set_value(0, false)
	_odo.clip_contents = true
	row.add_child(_odo)


func _build_charge() -> void:
	var ch: Dictionary = bundle.get("cache_charge", {})
	if ch.is_empty() or int(bundle.get("level", result.get("level", 1))) < EconData.CACHE_FROM_LEVEL:
		return
	_charge = ChargePips.new()
	_charge.value = int(ch.get("value", 0))
	_charge.size = Vector2(440, 70)
	_charge.position = Vector2((_vp.x - 440) * 0.5, _ins.y + 512)
	_charge.modulate.a = 0.0
	root.add_child(_charge)


func _build_assist() -> void:
	var a: Dictionary = bundle.get("assist", {})
	if int(a.get("stacks", 0)) <= 0 or not bool(Meta.setting("reinforcements", true)):
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(20, 12)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var badge := AssistBadge.new()
	badge.custom_minimum_size = Vector2(70, 70)
	row.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pct := int(round(float(a.get("dmg_add", 0.0)) * 100.0))
	v.add_child(UIKit.heading(Loc.f("ASSIST_CHIP", [pct]), 30, Color(0.6, 1.0, 0.62), 6))
	var d := UIKit.label(Loc.f("ASSIST_DESC", [int(a.get("soldiers", 0)), pct]), 21, UIKit.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	row.add_child(v)
	p.custom_minimum_size = Vector2(_vp.x - 80, 100)
	p.position = Vector2(40, _retry_btn_y() - 132)
	p.modulate.a = 0.0
	root.add_child(p)
	_assist = p


func _retry_btn_y() -> float:
	return _vp.y - 214 - _ins.w


# ------------------------------------------------------------------ steps

func _step_progress() -> void:
	var lbl := root.get_node("ProgressLabel") as Control
	lbl.create_tween().tween_property(lbl, "modulate:a", 1.0, 0.25)
	_bar.create_tween().tween_property(_bar, "modulate:a", 1.0, 0.2)
	_bar.run_to(_frac(), 0.8)
	_at(0.85, _step_payout)


func _step_payout() -> void:
	var row := root.get_node("Payout") as Control
	row.modulate.a = 1.0
	UIJuice.pop(row, 0.0, 0.3, 0.7)
	var total := int((bundle.get("coins", {}) as Dictionary).get("total", 0))
	_odo.set_value(total, true, 0.6)
	for i in 6:
		_at(i * 0.1, func(): Audio.note(mini(2 + i, 14), -16.0))
	_at(0.7, _fly)
	_at(0.75, _step_charge)


func _fly() -> void:
	if _flown or bool(bundle.get("duplicate", false)):
		_flown = true
		return
	_flown = true
	var total := int((bundle.get("coins", {}) as Dictionary).get("total", 0))
	if total > 0:
		_chip.expect_fly()
		_chip.set_amount(int(bundle.get("coins_balance", Meta.currency("coins"))) - _inline_coins(), false)
		RewardFly.layer(get_tree()).fly(_odo.get_global_rect().get_center(), "coins", total, _chip)


func _step_charge() -> void:
	if _charge:
		_charge.modulate.a = 1.0
		UIJuice.pop(_charge, 0.0, 0.3, 0.7)
		_charge.fill_new(0.25)
	_at(0.6 if _charge else 0.0, _step_drip)


func _step_drip() -> void:
	_drip.create_tween().tween_property(_drip, "modulate:a", 1.0, 0.25)
	var k := 0
	for c in _drip.get_children():
		_at(0.2 + k * 0.1, (c as ResultFlow.DripChip).fill)
		k += 1
	_at(0.4 + k * 0.1, _step_walkout)


func _step_walkout() -> void:
	var nu := str(bundle.get("new_unlock", ""))
	if nu == "":
		_step_cache()
		return
	_walk = Walkout.new()
	_walk.setup(nu, bool(bundle.get("walkout", false)))
	root.add_child(_walk)
	_walk.done.connect(func():
		_walk = null
		_step_cache())


func _step_cache() -> void:
	var caches: Array = bundle.get("caches", [])
	if caches.is_empty():
		_step_assist()
		return
	var cd: Dictionary = caches[0]
	_drip.visible = false
	if bool(cd.get("inline", false)):
		_inline = InlineReveal.new()
		_inline.setup(cd.get("reveal", {}))
		_inline.position = Vector2(36, 10)
		_inline.size = Vector2(_vp.x - 72, 500)
		_mid.add_child(_inline)
		_inline.done.connect(func():
			var coins := int(_inline.rev.get("coins", 0))
			if coins > 0 and not bool(bundle.get("duplicate", false)):
				_chip.expect_fly()
				_chip.set_amount(int(bundle.get("coins_balance", Meta.currency("coins"))), false)
				RewardFly.layer(get_tree()).fly(_inline.coins_point(), "coins", coins, _chip)
			_step_assist())
		if _assist:
			_assist.visible = false
	else:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(22, 8)))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(Icons.make("cache_stone", 48.0))
		r.add_child(UIKit.heading(Loc.t("CACHE_STONE") + "  ·  " + Loc.t("RF_TO_VAULT"), 26, UIKit.TEXT, 6))
		pill.add_child(r)
		pill.position = Vector2(60, 20)
		_mid.add_child(pill)
		UIJuice.pop(pill, 0.0)
		_at(0.4, _step_assist)


func _step_assist() -> void:
	if _assist and _assist.visible:
		_assist.modulate.a = 1.0
		UIJuice.slide_in(_assist, Vector2(0, 40), 0.0)
		Audio.note(9, -10.0)
		UIJuice.haptic("TICK", 0.5)


# ------------------------------------------------------------------ leave

func _leave(again: bool) -> void:
	if _t < TAP_FROM or _left or _walk != null:
		return
	_left = true
	_fly()
	if _inline and not _inline.finished:
		_inline.skip()
	RewardFly.layer(get_tree()).land_all()
	if again:
		retry.emit()
	else:
		arsenal.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		_leave(false)


# ------------------------------------------------------------------ widgets

## The bridge: a stone track from the start (army) to the fortress, filled to how far the army
## got, with a glowing marker there.
class BridgeBar extends Control:
	var k := 0.0
	var _t := 0.0

	func run_to(target: float, dur: float) -> void:
		var tw := create_tween()
		tw.tween_property(self, "k", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t = fmod(_t + delta, 100.0)
		queue_redraw()

	func _draw() -> void:
		var h := 26.0
		var r := Rect2(Vector2(36, (size.y - h) * 0.5), Vector2(size.x - 72, h))
		draw_style_box(UIKit.box(Color(0.02, 0.025, 0.06, 0.95), Color(0.55, 0.62, 0.85, 0.5), 13, 3, 4, Vector2.ZERO), r)
		# Plank seams.
		for i in 11:
			var x := r.position.x + r.size.x * (i + 1) / 12.0
			draw_line(Vector2(x, r.position.y + 5), Vector2(x, r.end.y - 5), Color(1, 1, 1, 0.08), 2.0)
		var w := (r.size.x - 6) * clampf(k, 0.0, 1.0)
		if w > 2.0:
			MachineCard.grad_box(self, Rect2(r.position + Vector2(3, 3), Vector2(w, h - 6)), Color(0.6, 0.85, 1.0), Color(0.2, 0.42, 0.95), 10)
		Icons.draw_icon(self, "soldier", Rect2(Vector2(-6, size.y * 0.5 - 24), Vector2(48, 48)))
		Icons.draw_icon(self, "fortress", Rect2(Vector2(size.x - 44, size.y * 0.5 - 26), Vector2(52, 52)), Color(1, 0.75, 0.7))
		var mx := r.position.x + 3 + w
		var g := 22.0 + 4.0 * sin(_t * 4.0)
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(mx - g, size.y * 0.5 - g), Vector2(g, g) * 2.0), false, Color(0.6, 0.85, 1.0, 0.9))
		draw_circle(Vector2(mx, size.y * 0.5), 9.0, Color(1, 1, 1))


## Stone Cache charge: three gem sockets, filled ones glow sapphire; "Схованка 2/3".
class ChargePips extends Control:
	var value := 0
	var _fresh := 0.0

	func fill_new(delay: float) -> void:
		_fresh = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			Audio.note(8 + value, -9.0)
			UIJuice.haptic("TICK", 0.5))
		tw.tween_method(func(v: float):
			_fresh = v
			queue_redraw(), 0.0, 1.0, 0.4)

	func _draw() -> void:
		var f := UIKit.font(true)
		var txt := Loc.f("LOSS_CHARGE", [value])
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var total := tw + 20 + 3 * 52
		var x0 := (size.x - total) * 0.5
		Icons.draw_icon(self, "cache_stone", Rect2(Vector2(x0 - 62, size.y * 0.5 - 28), Vector2(56, 56)))
		draw_string_outline(f, Vector2(x0, size.y * 0.5 + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color(0, 0.01, 0.05))
		draw_string(f, Vector2(x0, size.y * 0.5 + 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIKit.TEXT)
		for i in 3:
			var c := Vector2(x0 + tw + 46 + i * 52, size.y * 0.5)
			var on := i < value
			var k := 1.0 if i < value - 1 else (_fresh if i == value - 1 else 0.0)
			draw_circle(c, 19.0, Color(0.02, 0.03, 0.08, 0.95))
			draw_arc(c, 19.0, 0, TAU, 32, Color(0.6, 0.7, 0.95, 0.6), 3.0, true)
			if on and k > 0.0:
				draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(30, 30) * k, Vector2(60, 60) * k), false, Color(0.3, 0.7, 1.0, 0.8))
				var s := 14.0 * k
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]), Color(0.45, 0.8, 1.0))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, 0)]), Color(0.85, 0.96, 1.0))


## Reinforcements badge: a green shield with a plus.
class AssistBadge extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.8, Vector2(r, r) * 3.6), false, Color(0.4, 1.0, 0.5, 0.35))
		var pts := PackedVector2Array([c + Vector2(-r, -r * 0.8), c + Vector2(r, -r * 0.8), c + Vector2(r * 0.9, r * 0.2), c + Vector2(0, r * 1.05), c + Vector2(-r * 0.9, r * 0.2)])
		draw_colored_polygon(pts, Color(0.12, 0.45, 0.2))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.82)
		draw_colored_polygon(inner, Color(0.3, 0.85, 0.4))
		draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.5), Vector2(r * 0.24, r * 0.95)), Color(1, 1, 0.92))
		draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.14), Vector2(r * 0.9, r * 0.24)), Color(1, 1, 0.92))
