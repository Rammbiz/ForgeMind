class_name ResultFlow
extends CanvasLayer
## The result flow after a WIN (arsenal_design.md §7.3), over the run's last frame (the stairs
## and the fallen fortress keep playing behind a scrim). Everything shown comes from the bundle
## Meta.finish_run() returned - the run was booked and SAVED once before this node exists.
##   1  coin odometer rolls victory + pickups (<= 1.0 s)
##   2  the stairs stamp "×3.2" slams (back easing + THUD) and the odometer rolls to the total
##   3  stats stagger 80 ms: survivors, Crowns 1-3 with pops (a new best glows)
##   5  rewards fly: coins into the coin chip (HubTopBar.HubChip), blueprint drip into the
##      machines' bars and blueprints to the Arsenal chip
##   5a NEW machine walkout (Walkout; unskippable the first time per machine)
##   6  Stone Cache inline reveal (InlineReveal, <= 2.5 s) or "-> Сховище"; World Cache:
##      "Відкрити на вівтарі" (signal altar) / "Пізніше"
##   7  Best-upgrade row (signal upgrade) + "Далі" (signal next)
## "Далі" is live from 0.5 s at every step: before step 7 it lands everything at once and
## skips to step 7 (Meta.note_skip("result")); at step 7 it leaves. Android back = "Далі".
## The static builders (scrim, ribbon, coin chip, drip strip, best-upgrade row) are shared
## with LossScreen.

signal next
signal altar(vault_index: int)
signal upgrade(id: String)

const TAP_FROM := 0.5

var bundle: Dictionary = {}
var result: Dictionary = {}
var step := 0
var root: Control

var _t := 0.0
var _ins := Vector4.ZERO
var _vp := Vector2(720, 1280)
var _events: Array = []
var _clock := 0.0
var _odo: Odometer
var _coin_block: Control
var _stamp: Control
var _stats: HBoxContainer
var _crowns: Array[Control] = []
var _drip: HBoxContainer
var _cache_box: Control
var _inline: InlineReveal
var _best: Control
var _next_btn: Button
var _chip: HubTopBar.HubChip
var _bp_chip: Control
var _walk: Walkout
var _walk_pending := false
var _walk_done := false
var _flown := false
var _final := false
var _left := false


## `p_bundle` = Meta.finish_run(run.result); `p_result` = run.result (survivors, stairs mult).
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
	root.add_child(scrim(_vp, 0.5, 0.94))
	var rays := UIKit.Rays.new()
	rays.color = Color(1.0, 0.82, 0.4, 0.0)
	rays.count = 18
	rays.inner = 0.08
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.size = Vector2(_vp.x * 1.6, _vp.x * 1.6)
	rays.position = Vector2(_vp.x * 0.5, _ins.y + 170) - rays.size * 0.5
	root.add_child(rays)
	rays.create_tween().tween_property(rays, "color:a", 0.24, 0.6)
	_build_top()
	var rib := ribbon(Loc.t("VICTORY"), true, _vp.x)
	rib.position = Vector2(0, _ins.y + 112)
	root.add_child(rib)
	var why := UIKit.heading(Loc.t(str(result.get("reason", "FORTRESS_FALLS"))) if result.has("reason") else Loc.t("FORTRESS_FALLS"), 28, UIKit.TEXT_DIM, 5)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.size = Vector2(_vp.x, 36)
	why.position = Vector2(0, _ins.y + 226)
	root.add_child(why)
	UIJuice.fade_in(why, 0.35)
	_build_coins()
	_build_stats()
	_build_drip()
	_cache_box = Control.new()
	_cache_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cache_box.position = Vector2(0, _ins.y + 590)
	_cache_box.size = Vector2(_vp.x, 470)
	root.add_child(_cache_box)
	_next_btn = UIKit.button(Loc.t("NEXT"), true, 440.0)
	_next_btn.custom_minimum_size.y = 96
	_next_btn.add_theme_font_size_override("font_size", 42)
	_next_btn.size = Vector2(440, 96)
	_next_btn.position = Vector2((_vp.x - 440) * 0.5, _vp.y - 128 - _ins.w)
	_next_btn.pressed.connect(_on_next)
	_next_btn.modulate.a = 0.0
	root.add_child(_next_btn)
	Audio.play("victory", -2.0)
	UIJuice.haptic_pattern("win")
	_at(0.12, func(): UIKit.sparkles(root, Vector2(_vp.x * 0.5, _ins.y + 160), UIKit.GOLD_LIGHT, 40, 420.0))
	_at(TAP_FROM, func(): _next_btn.create_tween().tween_property(_next_btn, "modulate:a", 0.82, 0.2))
	_at(0.35, _step_odometer)


func _at(t: float, fn: Callable) -> void:
	_events.append([_clock + t, fn])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	_t += delta
	_clock += delta
	while not _events.is_empty() and float(_events[0][0]) <= _clock:
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()


# ------------------------------------------------------------------ shared builders

## Full-screen scrim: a vertical gradient from `top_a` to `bottom_a` (deep navy).
static func scrim(vp: Vector2, top_a: float, bottom_a: float) -> Control:
	var tr := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.025, 0.07, top_a))
	g.set_color(1, Color(0.01, 0.012, 0.04, bottom_a))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = vp
	tr.modulate.a = 0.0
	tr.create_tween().tween_property(tr, "modulate:a", 1.0, 0.3)
	return tr


## The title ribbon (gold for a win, slate for a loss) with its heading, `w` wide.
static func ribbon(text: String, won: bool, w: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(w, 104)
	var rb := UIKit.Ribbon.new()
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rb.size = Vector2(560, 96)
	rb.position = Vector2((w - 560) * 0.5, 4)
	if not won:
		rb.set_palette(Color(0.62, 0.66, 0.8), Color(0.3, 0.33, 0.46), Color(0.14, 0.15, 0.24))
	holder.add_child(rb)
	var title: Label
	if won:
		title = UIKit.gradient_heading(text, 64, Color(1, 1, 1), Color(1.0, 0.96, 0.78), Color(1.0, 0.82, 0.45), 12)
		title.add_theme_color_override("font_outline_color", Color(0.42, 0.18, 0.02))
	else:
		title = UIKit.gradient_heading(text, 60, Color(1, 0.94, 0.92), Color(0.86, 0.82, 0.9), Color(0.6, 0.6, 0.72), 12)
		title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(560, 92)
	title.position = Vector2((w - 560) * 0.5, 4)
	holder.add_child(title)
	for n: Control in [rb, title]:
		n.pivot_offset = n.size * 0.5
		n.scale = Vector2(0.2, 1.0)
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(0.1)
		tw.tween_property(n, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return holder


## The coin chip of the hub top bar, standing at `balance`, placed top-right.
static func coin_chip(parent: Control, balance: int, ins: Vector4, vp: Vector2) -> HubTopBar.HubChip:
	var ch := HubTopBar.HubChip.new("coins")
	parent.add_child(ch)
	ch.set_amount(balance, false)
	ch.size = ch.custom_minimum_size
	ch.position = Vector2(vp.x - ch.size.x - 22 - ins.z, ins.y + 20)
	return ch


## A row of drip chips (one per machine the run fed): render, name, the bar filling from
## bp_before to bp_after (+ green arrow when upgradable). Call `fill()` on each to animate.
static func drip_strip(rows: Array, w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size = Vector2(w, 84)
	for r in rows:
		if not r is Dictionary or str((r as Dictionary).get("id", "")) == "":
			continue
		var c := DripChip.new()
		c.data = r
		c.custom_minimum_size = Vector2(minf(212.0, (w - 40.0) / maxf(rows.size(), 1) - 12.0), 80)
		hb.add_child(c)
	return hb


## The Best-upgrade row (§7.3 step 7): "Найкраще покращення" + "<name> Рів. N · cost"; tap
## calls `on_tap(id)`. Empty Control when nothing is affordable.
static func best_row(best: Dictionary, w: float, on_tap: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(18, 10)))
	p.custom_minimum_size = Vector2(w, 86)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if best.is_empty():
		p.visible = false
		return p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var kind := str(best.get("kind", "machine"))
	var id := str(best.get("id", ""))
	var ic := Icons.make(id if kind == "machine" else ("helmet" if kind == "hero" else "fortress"), 60.0)
	row.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(Loc.t("BEST_UPGRADE"), 20, UIKit.TEXT_DIM))
	var lv := int(best.get("to_lvl", 0))
	var txt := Loc.t(str(best.get("label", "")))
	if lv > 0:
		txt += "  " + Loc.f("LV", [lv])
	var nm := UIKit.heading(txt, 28, UIKit.TEXT, 6)
	nm.add_theme_font_size_override("font_size", UIKit.fit_size(txt, w - 300.0, 28, 18))
	v.add_child(nm)
	row.add_child(v)
	var cost := HBoxContainer.new()
	cost.add_theme_constant_override("separation", 6)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_child(Icons.make("coin", 34.0))
	cost.add_child(UIKit.heading(Loc.num(int(best.get("cost", 0))), 30, UIKit.GOLD_LIGHT, 6))
	cost.add_child(Icons.make("arrow_up", 34.0))
	row.add_child(cost)
	p.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			on_tap.call(id))
	UIJuice.press(p)
	return p


# ------------------------------------------------------------------ build

func _build_top() -> void:
	var coins := bundle.get("coins", {}) as Dictionary
	var gain := 0 if bool(bundle.get("duplicate", false)) else int(coins.get("total", 0)) + _inline_coins()
	_chip = coin_chip(root, int(bundle.get("coins_balance", Meta.currency("coins"))) - gain, _ins, _vp)
	# Arsenal chip: where the blueprints fly.
	_bp_chip = Control.new()
	_bp_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bp_chip.size = Vector2(72, 72)
	_bp_chip.position = Vector2(_chip.position.x - 92, _ins.y + 12)
	_bp_chip.draw.connect(func():
		_bp_chip.draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(-14, -14), Vector2(100, 100)), false, Color(0.5, 0.75, 1.0, 0.3))
		_bp_chip.draw_style_box(UIKit.lux("chip"), Rect2(Vector2(4, 8), Vector2(64, 56)))
		Icons.draw_icon(_bp_chip, "tab_arsenal", Rect2(Vector2(10, 10), Vector2(52, 52))))
	root.add_child(_bp_chip)
	var lvl := UIKit.heading(Loc.f("LEVEL", [int(bundle.get("level", result.get("level", 1)))]), 30, UIKit.TEXT, 6)
	lvl.position = Vector2(24 + _ins.x, _ins.y + 30)
	root.add_child(lvl)


func _inline_coins() -> int:
	var n := 0
	for c in bundle.get("caches", []):
		if bool((c as Dictionary).get("inline", false)):
			n += int(((c as Dictionary).get("reveal", {}) as Dictionary).get("coins", 0))
	return n


func _build_coins() -> void:
	_coin_block = Control.new()
	_coin_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_block.size = Vector2(_vp.x, 130)
	_coin_block.position = Vector2(0, _ins.y + 272)
	root.add_child(_coin_block)
	var glow := TextureRect.new()
	glow.texture = UIKit.glow_texture()
	glow.modulate = Color(1.0, 0.72, 0.25, 0.42)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(460, 190)
	glow.position = Vector2((_vp.x - 460) * 0.5 - 40, -36)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_block.add_child(glow)
	var coin := Icons.make("coin", 84.0)
	coin.position = Vector2(_vp.x * 0.5 - 196, 14)
	_coin_block.add_child(coin)
	_odo = Odometer.new()
	_odo.font_size = 96
	_odo.color = UIKit.GOLD_LIGHT
	_odo.outline = 12
	_odo.align = HORIZONTAL_ALIGNMENT_LEFT
	_odo.position = Vector2(_vp.x * 0.5 - 100, 0)
	_odo.size = Vector2(300, 112)
	_odo.set_value(0, false)
	_odo.clip_contents = true
	_coin_block.add_child(_odo)
	var coins := bundle.get("coins", {}) as Dictionary
	var parts := Label.new()
	parts.text = "%s %s  ·  %s %s" % [Loc.t("COINS_BASE"), Loc.num(int(coins.get("victory", 0))), Loc.t("COINS_COLLECTED"), Loc.num(int(coins.get("pickups", 0)))]
	parts.add_theme_font_size_override("font_size", 22)
	parts.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	parts.add_theme_constant_override("outline_size", 4)
	parts.add_theme_color_override("font_outline_color", Color(0, 0.01, 0.05))
	parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts.size = Vector2(_vp.x, 30)
	parts.position = Vector2(0, 112)
	parts.modulate.a = 0.0
	parts.name = "Parts"
	_coin_block.add_child(parts)
	_stamp = Stamp.new()
	_stamp.text = Loc.t("STAIRS_MULT") % HudView._fmt_mult(float(coins.get("stairs_mult", result.get("mult", 1.0))))
	_stamp.size = Vector2(170, 92)
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.position = Vector2(_vp.x - 196 - _ins.z, 6)
	_stamp.rotation = deg_to_rad(-9)
	_stamp.visible = false
	_coin_block.add_child(_stamp)


func _build_stats() -> void:
	_stats = HBoxContainer.new()
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override("separation", 26)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.size = Vector2(_vp.x, 64)
	_stats.position = Vector2(0, _ins.y + 420)
	root.add_child(_stats)
	var surv := PanelContainer.new()
	surv.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(20, 6)))
	surv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sr.add_child(Icons.make("soldier", 40.0))
	sr.add_child(UIKit.heading(Loc.f("RESULT_SURVIVORS", [int(result.get("survivors", 0))]), 28, UIKit.TEXT, 6))
	surv.add_child(sr)
	surv.modulate.a = 0.0
	_stats.add_child(surv)
	var cr := bundle.get("crowns", {}) as Dictionary
	var got := int(cr.get("run", result.get("crowns", 1)))
	var gained := int(cr.get("gained", 0))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 4)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var c := CrownSlot.new()
		c.on = i < got
		c.fresh = i >= got - gained and i < got
		c.custom_minimum_size = Vector2(60, 60)
		c.modulate.a = 0.0
		crow.add_child(c)
		_crowns.append(c)
	_stats.add_child(crow)


func _build_drip() -> void:
	var rows: Array = bundle.get("drip", [])
	_drip = drip_strip(rows, _vp.x)
	_drip.position = Vector2(0, _ins.y + 484)
	_drip.modulate.a = 0.0
	root.add_child(_drip)


# ------------------------------------------------------------------ steps

func _step_odometer() -> void:
	step = 1
	var coins := bundle.get("coins", {}) as Dictionary
	var mult := float(coins.get("stairs_mult", 1.0))
	var base := int(coins.get("victory", 0)) + int(coins.get("pickups", 0))
	# Without a stairs stamp (or on a replay) the odometer goes straight to the paid total.
	_odo.set_value(base if mult > 1.0 else int(coins.get("total", base)), true, 0.85)
	_tick_coins(0.85, 9)
	var parts := _coin_block.get_node("Parts") as Control
	parts.create_tween().tween_property(parts, "modulate:a", 1.0, 0.3)
	_at(0.95, _step_stamp if mult > 1.0 else _step_stats)


func _tick_coins(dur: float, n: int) -> void:
	for i in n:
		_at(dur * float(i) / n, func(): Audio.note(mini(2 + i, 14), -16.0))


func _step_stamp() -> void:
	step = 2
	var coins := bundle.get("coins", {}) as Dictionary
	_stamp.visible = true
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(2.4, 2.4)
	var tw := _stamp.create_tween()
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_at(0.22, func():
		Audio.play("stairs_top", -3.0)
		UIJuice.haptic("THUD", 1.0)
		UIKit.sparkles(root, _coin_block.position + _stamp.position + _stamp.size * 0.5, UIKit.GOLD_LIGHT, 26, 260.0)
		UIJuice.punch(_odo, 1.12, 0.25)
		_odo.set_value(int(coins.get("total", 0)), true, 0.4))
	_at(0.6, _step_stats)


func _step_stats() -> void:
	step = 3
	var i := 0
	for n: Control in [_stats.get_child(0)] + _crowns:
		var c := n
		_at(i * UITokens.STAGGER + i * 0.01, func():
			c.modulate.a = 1.0
			if c is CrownSlot and (c as CrownSlot).on:
				# Crowns stamp in (2x -> 1x, back easing); a new best adds a thud and sparks.
				c.pivot_offset = c.size * 0.5
				c.scale = Vector2(2.0, 2.0)
				c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Audio.note(7 + _crowns.find(c) * 2, -9.0)
				if (c as CrownSlot).fresh:
					UIJuice.haptic("THUD", 0.6)
					UIKit.sparkles(root, c.get_global_rect().get_center(), UIKit.GOLD_LIGHT, 14, 120.0)
			else:
				UIJuice.pop(c, 0.0, 0.28, 0.5))
		i += 1
	_at(0.1 + i * 0.08, _step_rewards)


func _step_rewards() -> void:
	step = 5
	_fly_rewards()
	_drip.create_tween().tween_property(_drip, "modulate:a", 1.0, 0.25)
	var k := 0
	for c in _drip.get_children():
		var dc := c as DripChip
		_at(0.25 + k * 0.1, dc.fill)
		k += 1
	_at(0.75 + k * 0.1, _step_walkout)


func _fly_rewards() -> void:
	if _flown or bool(bundle.get("duplicate", false)):
		_flown = true
		return
	_flown = true
	var total := int((bundle.get("coins", {}) as Dictionary).get("total", 0))
	if total > 0:
		_chip.expect_fly()
		_chip.set_amount(_chip_target(), false)
		RewardFly.layer(get_tree()).fly(_odo.get_global_rect().get_center(), "coins", total, _chip)
	var bp := 0
	for r in bundle.get("drip", []):
		bp += int((r as Dictionary).get("bp_after", 0)) - int((r as Dictionary).get("bp_before", 0))
	if bp > 0:
		RewardFly.layer(get_tree()).fly(_drip.get_global_rect().get_center(), "bp", bp, _bp_chip, 1)


## Coin balance after the coins already shown (the inline Cache bonus flies later).
func _chip_target() -> int:
	return int(bundle.get("coins_balance", Meta.currency("coins"))) - (_inline_coins() if _inline == null or not _inline.finished else 0)


func _step_walkout() -> void:
	var nu := str(bundle.get("new_unlock", ""))
	if nu == "" or _walk_done:
		_step_cache()
		return
	step = 4
	_walk_pending = true
	_walk = Walkout.new()
	_walk.setup(nu, bool(bundle.get("walkout", false)))
	root.add_child(_walk)
	_walk.done.connect(func():
		_walk = null
		_walk_pending = false
		_walk_done = true
		if _final:
			step = 7                # "Далі" during the walkout: without this the next tap was a no-op
			_show_final()
		else:
			_step_cache())


func _step_cache() -> void:
	step = 6
	var caches: Array = bundle.get("caches", [])
	if caches.is_empty():
		_step_final()
		return
	var cd: Dictionary = caches[0]
	var type := str(cd.get("type", "stone"))
	if bool(cd.get("inline", false)):
		_inline = InlineReveal.new()
		_inline.setup(cd.get("reveal", {}))
		_inline.compact = true
		_inline.position = Vector2(36, 34)
		_inline.size = Vector2(_vp.x - 72, 470)
		_cache_box.add_child(_inline)
		_inline.done.connect(_on_inline_done)
		var title := UIKit.heading(Loc.f("CACHE_EARNED", [Loc.t(str((EconData.CACHES[type] as Dictionary)["name"]))]), 30, UIKit.GOLD_LIGHT, 6)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(_vp.x, 36)
		title.position = Vector2(0, 0)
		_cache_box.add_child(title)
	else:
		_cache_box.add_child(_cache_card(type, int(cd.get("vault_index", -1))))
		_at(0.6, _step_final)


func _on_inline_done() -> void:
	var coins := int(_inline.rev.get("coins", 0))
	if coins > 0 and not bool(bundle.get("duplicate", false)):
		_chip.expect_fly()
		_chip.set_amount(int(bundle.get("coins_balance", Meta.currency("coins"))), false)
		RewardFly.layer(get_tree()).fly(_inline.coins_point(), "coins", coins, _chip)
	_at(0.3, _step_final)


## A World Cache (or a Stone Cache sent to the Vault): the breathing egg, its name and the
## Altar / Later buttons (World), or the "Сховище" chip (Stone).
func _cache_card(type: String, vault_index: int) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(_vp.x, 480)
	var egg := EggView.new(type)
	egg.size = Vector2(250, 250)
	egg.position = Vector2((_vp.x - 250) * 0.5, 36)
	box.add_child(egg)
	egg.present()
	var t := UIKit.gradient_heading(Loc.f("CACHE_EARNED", [Loc.t(str((EconData.CACHES[type] as Dictionary)["name"]))]), 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size = Vector2(_vp.x, 50)
	t.position = Vector2(0, -6)
	box.add_child(t)
	if type == "stone":
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(22, 8)))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(Icons.make("vault", 40.0))
		r.add_child(UIKit.heading(Loc.t("RF_TO_VAULT"), 28, UIKit.TEXT, 6))
		pill.add_child(r)
		pill.position = Vector2((_vp.x - 300) * 0.5, 296)
		pill.custom_minimum_size = Vector2(300, 0)
		box.add_child(pill)
		UIJuice.pop(pill, 0.3)
		return box
	var open := UIKit.styled_button(Loc.t("OPEN_ON_ALTAR"), "green", Vector2(420, 88), 32)
	open.position = Vector2((_vp.x - 420) * 0.5, 282)
	open.pressed.connect(func():
		if _left:
			return
		_left = true
		_land_all()
		altar.emit(vault_index))
	box.add_child(open)
	UIKit.add_shine(open, 26.0, 0.6, 2.2, 0.5)
	var later := UIKit.styled_button(Loc.t("LATER"), "button", Vector2(260, 64), 26)
	later.position = Vector2((_vp.x - 260) * 0.5, 378)
	later.pressed.connect(func():
		open.disabled = true
		later.visible = false
		var tw := open.create_tween()
		tw.tween_property(open, "modulate:a", 0.0, 0.2)
		var note := UIKit.heading(Loc.t("RF_IN_VAULT"), 26, UIKit.TEXT_DIM, 5)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.size = Vector2(_vp.x, 34)
		note.position = Vector2(0, 300)
		box.add_child(note)
		UIJuice.fade_in(note))
	box.add_child(later)
	UIJuice.pop(open, 0.2)
	UIJuice.pop(later, 0.3)
	return box


func _step_final() -> void:
	if step >= 7:
		return
	step = 7
	_show_final()


func _show_final() -> void:
	if _best != null:
		return
	if _inline:
		_inline.collapse()
	_best = best_row(bundle.get("best_upgrade", {}), _vp.x - 60, func(id: String):
		if _left or id == "":
			return
		_left = true
		_land_all()
		upgrade.emit(id))
	_best.position = Vector2(30, _next_btn.position.y - 104)
	_best.size = Vector2(_vp.x - 60, 86)
	root.add_child(_best)
	if _best.visible:
		UIJuice.pop(_best, 0.0)
	_next_btn.modulate.a = 1.0
	UIJuice.pop(_next_btn, 0.05)
	UIKit.add_shine(_next_btn, 30.0, 0.6, 2.4, 0.5)


# ------------------------------------------------------------------ skip / leave

func _on_next() -> void:
	if _t < TAP_FROM or _left:
		return
	if step >= 7 and _walk == null:
		_leave()
		return
	skip_to_final()


## "Далі" before step 7: everything lands at once, the flow jumps to step 7. A first-time
## walkout still plays (unskippable once).
func skip_to_final() -> void:
	if _final:
		return
	_final = true
	Meta.note_skip("result")
	_events.clear()
	var coins := bundle.get("coins", {}) as Dictionary
	_odo.set_value(int(coins.get("total", 0)), false)
	(_coin_block.get_node("Parts") as Control).modulate.a = 1.0
	if float(coins.get("stairs_mult", 1.0)) > 1.0:
		_stamp.visible = true
		_stamp.modulate.a = 1.0
		_stamp.scale = Vector2.ONE
	_stats.get_child(0).modulate.a = 1.0
	for c in _crowns:
		c.modulate.a = 1.0
	_drip.modulate.a = 1.0
	for c in _drip.get_children():
		(c as DripChip).fill()
	_fly_rewards()
	RewardFly.layer(get_tree()).land_all()
	if _inline:
		_inline.skip()
	elif step < 6 and not bundle.get("caches", []).is_empty():
		var cd: Dictionary = (bundle.get("caches", []) as Array)[0]
		if bool(cd.get("inline", false)):
			_step_cache()
			_inline.skip()
		else:
			_step_cache()
	var nu := str(bundle.get("new_unlock", ""))
	if nu != "" and not _walk_done and _walk == null and bool(bundle.get("walkout", false)):
		_step_walkout()
		return
	step = 7
	_show_final()


func _land_all() -> void:
	RewardFly.layer(get_tree()).land_all()


func _leave() -> void:
	if _left:
		return
	_left = true
	_land_all()
	next.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and _walk == null:
		_on_next()


# ------------------------------------------------------------------ widgets

## The stairs multiplier stamp: a gold-rimmed seal with "×3.2".
class Stamp extends Control:
	var text := "×2"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(UIKit.glow_texture(), r.grow(30), false, Color(1.0, 0.7, 0.2, 0.5))
		draw_style_box(UIKit.box(Color(0.55, 0.16, 0.04, 0.96), Color(1.0, 0.86, 0.4), 22, 5, 6, Vector2.ZERO), r)
		draw_style_box(UIKit.box(Color(0, 0, 0, 0), Color(1.0, 0.95, 0.75, 0.55), 16, 2, 0, Vector2.ZERO), r.grow(-9))
		var f := UIKit.font(true)
		var fs := 58
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36)
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.3, 0.06, 0.0))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.6))


## One Crown of the 3 (filled gold, or an empty socket); a new best glows.
class CrownSlot extends Control:
	var on := false
	var fresh := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if fresh:
			_t = fmod(_t + delta, 100.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if on and fresh:
			draw_texture_rect(UIKit.glow_texture(), r.grow(18), false, Color(1.0, 0.8, 0.3, 0.45 + 0.2 * sin(_t * 4.0)))
		Icons.draw_icon(self, "crown", r, Color(1, 1, 1, 1) if on else Color(0.2, 0.22, 0.32, 0.9))


## One machine's run drip: render, name and the blueprint bar (bp_before -> bp_after).
class DripChip extends Control:
	var data: Dictionary = {}
	var k := 0.0
	var _tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tex = MachineThumbs.get_thumb(self, str(data.get("id", "")), false)
		if _tex == null and DisplayServer.get_name() != "headless":
			MachineThumbs.service(get_tree()).rendered.connect(func(key: String, tex: Texture2D):
				if is_instance_valid(self) and key == MachineThumbs.key_of(str(data.get("id", "")), false):
					_tex = tex
					queue_redraw())

	func fill() -> void:
		if k >= 1.0:
			return
		var tw := create_tween()
		tw.tween_method(func(v: float):
			k = v
			queue_redraw(), k, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if bool(data.get("upgradable", false)):
				Audio.note(12, -10.0)
				UIJuice.punch(self, 1.08, 0.2))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UIKit.lux("chip"), r)
		var id := str(data.get("id", ""))
		var ir := Rect2(Vector2(4, (size.y - 72) * 0.5), Vector2(72, 72))
		if _tex:
			draw_texture_rect(_tex, ir.grow(6), false)
		else:
			Icons.draw_icon(self, id, ir.grow(-10))
		var f := UIKit.font(true)
		var nm := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else id
		var fs := UIKit.fit_size(nm, size.x - 92, 20, 14)
		draw_string_outline(f, Vector2(80, 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0.01, 0.05))
		draw_string(f, Vector2(80, 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.TEXT)
		var need := maxi(int(data.get("bp_need", 1)), 1)
		var before := float(data.get("bp_before", 0)) + 0.0
		var after := float(data.get("bp_after", before)) + float(data.get("frac", 0.0)) * (1.0 if k >= 1.0 else k)
		var shown := lerpf(before, after, k)
		var br := Rect2(Vector2(80, 42), Vector2(size.x - 92, 18))
		draw_style_box(UIKit.box(Color(0, 0, 0.03, 0.9), Color(1, 1, 1, 0.16), 9, 2, 0, Vector2.ZERO), br)
		var up := bool(data.get("upgradable", false)) and k >= 1.0
		var fk := clampf(shown / need, 0.0, 1.0)
		if fk > 0.0:
			MachineCard.grad_box(self, Rect2(br.position + Vector2(2, 2), Vector2((br.size.x - 4) * fk, br.size.y - 4)),
					Color(0.55, 1.0, 0.5) if up else Color(0.5, 0.82, 1.0), Color(0.2, 0.7, 0.25) if up else Color(0.15, 0.45, 0.95), 7)
		var bt := "%d/%d" % [int(floor(shown + 0.001)), need]
		var tw := f.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(f, Vector2(br.get_center().x - tw * 0.5, br.end.y - 2), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0.01, 0.05))
		draw_string(f, Vector2(br.get_center().x - tw * 0.5, br.end.y - 2), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
		if up:
			Icons.draw_icon(self, "arrow_up", Rect2(Vector2(size.x - 30, 4), Vector2(26, 26)))
