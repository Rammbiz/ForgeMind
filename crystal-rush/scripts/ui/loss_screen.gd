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
var _sheet: KitSheet


func setup(p_bundle: Dictionary, p_result: Dictionary) -> void:
	bundle = p_bundle
	result = p_result


const TITLE_Y := 100.0
const SHEET_Y := 290.0


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
	root.add_child(ResultFlow.scrim(_vp, 0.84, 0.92))
	var gain := 0 if bool(bundle.get("duplicate", false)) else int((bundle.get("coins", {}) as Dictionary).get("total", 0)) + _inline_coins()
	_chip = ResultFlow.coin_chip(root, int(bundle.get("coins_balance", Meta.currency("coins"))) - gain, _ins, _vp)
	root.add_child(ResultFlow.level_plate(int(bundle.get("level", result.get("level", 1))), _ins))
	# Tall phones: the scene band above the sheet grows (half the extra height); the top bar
	# stays put and the sheet's chrome keeps its size.
	_ins.y += ResultFlow.tall_band(_vp, _ins)
	# Calm: a cool porcelain title that settles in, the reason, and (when the copy exists) a
	# word of encouragement. No red anywhere.
	var rib := ResultFlow.ribbon(Loc.t("DEFEAT"), false, _vp.x)
	rib.position = Vector2(0, _ins.y + TITLE_Y)
	root.add_child(rib)
	var why_text := Loc.t(str(result.get("reason", "ARMY_LOST")))
	if Loc.STRINGS.has("LOSS_CHEER"):
		why_text += "  ·  " + Loc.t("LOSS_CHEER")
	var why := UIKit.scene_label(why_text, UIKit.fit_size(why_text, _vp.x - 60.0, 24, 18), false)
	why.add_theme_color_override("font_color", Color(UIKit.ON_SCENE.r, UIKit.ON_SCENE.g, UIKit.ON_SCENE.b, 0.88))
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.size = Vector2(_vp.x, 32)
	why.position = Vector2(0, _ins.y + TITLE_Y + 116)
	root.add_child(why)
	UIJuice.fade_in(why, 0.3)
	_sheet = UIKit.sheet()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.position = Vector2(0, _ins.y + SHEET_Y)
	_sheet.size = Vector2(_vp.x, _vp.y - _ins.y - SHEET_Y + 24)
	root.add_child(_sheet)
	UIJuice.sheet_in(_sheet, 0.08)
	_build_progress()
	_build_payout()
	_build_charge()
	_mid = Control.new()
	_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid.position = Vector2(0, _ins.y + SHEET_Y + 304)
	_mid.size = Vector2(_vp.x, 400)
	root.add_child(_mid)
	_drip = ResultFlow.drip_strip(bundle.get("drip", []), _vp.x - 48.0)
	_drip.position = Vector2(24, 0)
	_drip.modulate.a = 0.0
	_mid.add_child(_drip)
	_build_assist()
	_retry_btn = UIKit.cta_button(Loc.t("RETRY"), "", Vector2(440, 96), 40)
	_retry_btn.size = Vector2(440, 96)
	_retry_btn.position = Vector2((_vp.x - 440) * 0.5, _retry_btn_y())
	_retry_btn.pressed.connect(func(): _leave(true))
	root.add_child(_retry_btn)
	_arsenal_btn = UIKit.secondary_button(Loc.t("ARSENAL_BTN"), "", Vector2(320, 72), 26)
	_arsenal_btn.size = Vector2(320, 72)
	_arsenal_btn.position = Vector2((_vp.x - 320) * 0.5, _vp.y - 100 - _ins.w)
	_arsenal_btn.pressed.connect(func(): _leave(false))
	root.add_child(_arsenal_btn)
	for b: Control in [_retry_btn, _arsenal_btn]:
		b.modulate.a = 0.0
	_at(TAP_FROM, func():
		UIJuice.soft_in(_retry_btn, Vector2(0, 16))
		UIJuice.soft_in(_arsenal_btn, Vector2(0, 16), 0.08))
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
	var lbl := UIKit.label(Loc.f("LOSS_PROGRESS", [int(round(_frac() * 100.0))]), 26, UIKit.INK, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(_vp.x, 34)
	lbl.position = Vector2(0, _ins.y + SHEET_Y + 30)
	lbl.modulate.a = 0.0
	lbl.name = "ProgressLabel"
	root.add_child(lbl)
	_bar = BridgeBar.new()
	_bar.size = Vector2(_vp.x - 96, 60)
	_bar.position = Vector2(48, _ins.y + SHEET_Y + 68)
	_bar.modulate.a = 0.0
	root.add_child(_bar)


func _build_payout() -> void:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(_vp.x, 100)
	row.position = Vector2(0, _ins.y + SHEET_Y + 140)
	row.name = "Payout"
	row.modulate.a = 0.0
	root.add_child(row)
	var cap := UIKit.section(Loc.t("RF_EARNED"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(_vp.x, 26)
	row.add_child(cap)
	var coin := Icons.make("coin", 58.0)
	coin.position = Vector2(_vp.x * 0.5 - 120, 34)
	row.add_child(coin)
	_odo = Odometer.new()
	_odo.font_size = 68
	_odo.color = UIKit.INK
	_odo.position = Vector2(_vp.x * 0.5 - 48, 28)
	_odo.size = Vector2(240, 80)
	_odo.set_value(0, false)
	_odo.clip_contents = true
	row.add_child(_odo)


func _build_charge() -> void:
	var ch: Dictionary = bundle.get("cache_charge", {})
	if ch.is_empty() or int(bundle.get("level", result.get("level", 1))) < EconData.CACHE_FROM_LEVEL:
		return
	_charge = ChargePips.new()
	_charge.value = int(ch.get("value", 0))
	_charge.size = Vector2(440, 56)
	_charge.position = Vector2((_vp.x - 440) * 0.5, _ins.y + SHEET_Y + 244)
	_charge.modulate.a = 0.0
	root.add_child(_charge)


func _build_assist() -> void:
	var a: Dictionary = bundle.get("assist", {})
	if int(a.get("stacks", 0)) <= 0 or not bool(Meta.setting("reinforcements", true)):
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("plate", Vector2(16, 10)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var badge := AssistBadge.new()
	badge.custom_minimum_size = Vector2(64, 64)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var pct := int(round(float(a.get("dmg_add", 0.0)) * 100.0))
	v.add_child(UIKit.label(Loc.f("ASSIST_CHIP", [pct]), 26, UIKit.PLUS, true))
	var d := UIKit.label(Loc.f("ASSIST_DESC", [int(a.get("soldiers", 0)), pct]), 20, UIKit.INK_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	row.add_child(v)
	p.custom_minimum_size = Vector2(_vp.x - UITokens.GUTTER * 2.0, 96)
	p.position = Vector2(UITokens.GUTTER, _retry_btn_y() - 124)
	p.modulate.a = 0.0
	root.add_child(p)
	_assist = p


func _retry_btn_y() -> float:
	return _vp.y - 210 - _ins.w


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
	UIJuice.pop(row, 0.0, 0.3, 0.9)
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
		UIJuice.soft_in(_charge, Vector2(0, 10))
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
		_inline.position = Vector2(36, 6)
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
		pill.add_theme_stylebox_override("panel", UIKit.lux("plate", Vector2(16, 8)))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gt := ResultFlow.GemThumb.new()
		gt.icon = "cache_stone"
		gt.custom_minimum_size = Vector2(56, 56)
		r.add_child(gt)
		var rl := UIKit.label(Loc.t("CACHE_STONE") + "  ·  " + Loc.t("RF_TO_VAULT"), 24, UIKit.INK, true)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.size_flags_vertical = Control.SIZE_FILL
		r.add_child(rl)
		pill.add_child(r)
		pill.position = Vector2(UITokens.GUTTER, 10)
		_mid.add_child(pill)
		UIJuice.pop(pill, 0.0)
		_at(0.4, _step_assist)


func _step_assist() -> void:
	if _assist and _assist.visible:
		_assist.modulate.a = 1.0
		UIJuice.slide_in(_assist, Vector2(0, 24), 0.0)
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

## The bridge, v2: a row of cream crystal planks from the start (army) to the fortress, the
## planks the army crossed lit amber, a warm topaz keystone where it stopped; line icons at
## both ends.
class BridgeBar extends Control:
	const TILES := 12
	var k := 0.0
	var _t := 0.0

	func run_to(target: float, dur: float) -> void:
		var tw := create_tween()
		tw.tween_property(self, "k", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t = fmod(_t + delta, 100.0)
		queue_redraw()

	func _draw() -> void:
		var h := 18.0
		var x0 := 48.0
		var x1 := size.x - 48.0
		var cy := size.y * 0.5
		var gap := 4.0
		var tw := (x1 - x0 - gap * (TILES - 1)) / TILES
		var fill := (x1 - x0) * clampf(k, 0.0, 1.0)
		for i in TILES:
			var r := Rect2(Vector2(x0 + i * (tw + gap), cy - h * 0.5), Vector2(tw, h))
			var pts := GemDraw.chamfer_rect(r, 4.0)
			draw_colored_polygon(pts, UITokens.PAPER_3)
			var lit := clampf((fill - (r.position.x - x0)) / tw, 0.0, 1.0)
			if lit > 0.0:
				var fr := Rect2(r.position, Vector2(maxf(tw * lit, 4.0), h))
				var fp := GemDraw.chamfer_rect(fr, 4.0)
				var cols := PackedColorArray()
				for p in fp:
					cols.append(UITokens.CTA_HI.lerp(UITokens.CTA, (p.y - fr.position.y) / h))
				draw_polygon(fp, cols)
			GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), 1.0)
		Icons.draw_icon(self, "soldier", Rect2(Vector2(0, cy - 22), Vector2(44, 44)))
		Icons.draw_icon(self, "fortress", Rect2(Vector2(size.x - 44, cy - 24), Vector2(46, 46)))
		var mx := x0 + fill
		var g := 20.0 + 4.0 * sin(_t * 3.0)
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(mx - g, cy - g), Vector2(g, g) * 2.0), false, Color(1.0, 0.78, 0.36, 0.8))
		GemDraw.draw_gem(self, "star", Vector2(mx, cy), 26.0, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"))


## Stone Cache charge: "Схованка 2/3" and three sapphire gem sockets (cut gems when filled,
## engraved gold bezels when empty).
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
		var f := UIKit.font_w("bold")
		var txt := Loc.f("LOSS_CHARGE", [value])
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var total := 48.0 + tw + 20.0 + 3.0 * 48.0
		var x0 := (size.x - total) * 0.5
		var cy := size.y * 0.5
		Icons.draw_icon(self, "cache_stone", Rect2(Vector2(x0, cy - 22), Vector2(44, 44)))
		draw_string(f, Vector2(x0 + 52.0, cy + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIKit.INK)
		for i in 3:
			var c := Vector2(x0 + 52.0 + tw + 40.0 + i * 48.0, cy)
			var k := 1.0 if i < value - 1 else (_fresh if i == value - 1 else 0.0)
			var bez := GemDraw.cut_points("square", c, 30.0)
			draw_colored_polygon(bez, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.9))
			GemDraw.outline(self, bez, UITokens.HAIRLINE, 1.2)
			if i < value and k > 0.0:
				draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(26, 26) * k, Vector2(52, 52) * k), false, Color(0.4, 0.72, 1.0, 0.55))
				GemDraw.draw_mark(self, "sapphire", c, 24.0 * (0.6 + 0.4 * k), k)


## Reinforcements badge: a cream disc with a thin gold ring and a green shield-plus.
class AssistBadge extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var sc := UITokens.SCRIM
		for i in 3:
			draw_circle(c + Vector2(0, 1.5 + i), r - 1.0 + i, Color(sc.r, sc.g, sc.b, 0.06), true, -1.0, true)
		draw_circle(c, r, UITokens.PAPER_1, true, -1.0, true)
		draw_circle(c + Vector2(0, -r * 0.1), r * 0.84, UITokens.PAPER_0, true, -1.0, true)
		draw_arc(c, r - 0.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
		var s := r * 0.62
		var pts := PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.9, s * 0.2), c + Vector2(0, s * 1.05), c + Vector2(-s * 0.9, s * 0.2)])
		draw_colored_polygon(pts, Color(UITokens.PLUS.r, UITokens.PLUS.g, UITokens.PLUS.b, 0.16))
		GemDraw.outline(self, pts, UITokens.PLUS, 2.0)
		draw_line(c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.5), UITokens.PLUS, 3.0, true)
		draw_line(c + Vector2(-s * 0.44, s * 0.04), c + Vector2(s * 0.44, s * 0.04), UITokens.PLUS, 3.0, true)
