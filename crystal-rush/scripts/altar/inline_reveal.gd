class_name InlineReveal
extends Control
## The inline Stone Cache reveal on the result screen (arsenal_design.md §5.6 first paragraph,
## Brawl Stars Starr Drop length, <= 2.5 s, skippable from 0.5 s). The bundle (§6.6) was
## rolled, granted and SAVED by Meta before this node exists; nothing here decides anything.
##   present: the egg drops onto its dais, "Торкнись, щоб розбити" pulses;
##   strike:  one tap or 1.0 s auto (EconData.REVEAL.auto_strike);
##   tell:    +0.15 s the crack glows in the FINAL best rarity colour at once (no ladder);
##   burst:   +0.25 s the egg shatters with a flare and sparks in that colour;
##   fan-out: the cards fly out face-down (60 ms stagger), flip fast and spark into their bars;
##   coins:   the bonus slot pops "+N" (the flow flies it to the chip).
## skip() jumps to the end state; `done` fires once either way.

signal done

const CARD_FULL := Vector2(176, 250)
const CARD_COMPACT := Vector2(160, 228)
const GAP := 16.0
const EGG_FULL := 300.0
const EGG_COMPACT := 220.0

var rev: Dictionary = {}
## Timeline speed: 1 = design timings; "Швидкі церемонії" uses 0.6.
var speed := 1.0
var finished := false
## Smaller egg and cards (the result screen); set before adding to the tree.
var compact := false
var CARD := CARD_FULL
var EGG := EGG_FULL
var _lift := 0.0

var _egg: EggView
var _hint: Label
var _cards: Array[AltarCard] = []
var _coins_row: HBoxContainer
var _clock := 0.0
var _events: Array = []         ## [[t, Callable]] sorted by t
var _struck := false
var _flash: ColorRect
var _rays: UIKit.Rays


func setup(p_rev: Dictionary) -> void:
	rev = p_rev
	if bool(Meta.setting("fast_ceremonies", false)):
		speed = 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if compact:
		CARD = CARD_COMPACT
		EGG = EGG_COMPACT
	custom_minimum_size = Vector2(CARD.x * 3 + GAP * 2, EGG + CARD.y + 70)
	var best := str(rev.get("best", "C"))
	var bc := UITokens.rarity(best)
	_rays = UIKit.Rays.new()
	bc = Color(UITokens.gem(best)["rim"])
	_rays.color = Color(bc.r, bc.g, bc.b, 0.0)
	_rays.on_light = true
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)
	_egg = EggView.new(str(rev.get("type", "stone")))
	_egg.frame_k = 1.45
	add_child(_egg)
	# It plays on the cream result sheet: ink / gold text, no strokes.
	_hint = UIKit.label(Loc.t("TAP_TO_CRACK"), 22, UIKit.GOLD_TEXT, true)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	for cd: Dictionary in rev.get("cards", []):
		var c := AltarCard.new(cd)
		c.custom_minimum_size = CARD
		c.size = CARD
		c.visible = false
		add_child(c)
		_cards.append(c)
	_coins_row = HBoxContainer.new()
	_coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_coins_row.add_theme_constant_override("separation", 8)
	_coins_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coins := int(rev.get("coins", 0))
	if coins > 0:
		_coins_row.add_child(Icons.make("coin", 40.0))
		_coins_row.add_child(UIKit.number("+" + Loc.num(coins), 34, false, UIKit.GOLD_TEXT))
	_coins_row.modulate.a = 0.0
	add_child(_coins_row)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	resized.connect(_layout)
	_layout()
	_egg.present()
	UIJuice.haptic("THUD", 0.7)
	var hint_tw := _hint.create_tween().set_loops()
	hint_tw.tween_property(_hint, "modulate:a", 0.45, 0.6)
	hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.6)
	if UITokens.reduce_motion() or bool(Meta.setting("quick_reveal", false)):
		_quick()
		return
	_at(float(EconData.REVEAL["auto_strike"]) * speed, _strike)


func _layout() -> void:
	var w := size.x
	_egg.size = Vector2(EGG * 2.0, EGG * 1.45)
	_egg.position = Vector2(w * 0.5 - EGG, EGG * 0.5 - EGG * 0.725)
	_rays.size = Vector2(EGG * 2.2, EGG * 2.2)
	_rays.position = Vector2(w * 0.5, EGG * 0.5) - _rays.size * 0.5
	_hint.size = Vector2(w, 34)
	_hint.position = Vector2(0, EGG + 40)
	for i in _cards.size():
		_cards[i].position = slot(i)
	_coins_row.size = Vector2(w, 44)
	_coins_row.position = Vector2(0, EGG + CARD.y + 22 - _lift)
	_flash.size = size
	_flash.position = Vector2.ZERO


## Top-left of card `i` in its final row.
func slot(i: int) -> Vector2:
	var n := maxi(_cards.size(), 1)
	var row_w := n * CARD.x + (n - 1) * GAP
	return Vector2((size.x - row_w) * 0.5 + i * (CARD.x + GAP), EGG + 10 - _lift)


## Canvas position of the coins line (RewardFly source).
func coins_point() -> Vector2:
	return _coins_row.get_global_rect().get_center()


func _gui_input(e: InputEvent) -> void:
	if UIJuice.is_tap(e) and not _struck:
		accept_event()
		_strike()


func _at(t: float, fn: Callable) -> void:
	_events.append([_clock + t, fn])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	_clock += delta
	while not _events.is_empty() and float(_events[0][0]) <= _clock:
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 4.0)


func _strike() -> void:
	if _struck:
		return
	_struck = true
	_events.clear()
	_hint.visible = false
	Audio.play("crate_hit", -3.0)
	UIJuice.haptic("CLICK", 0.7)
	var best := str(rev.get("best", "C"))
	_at(float(EconData.REVEAL["tell"]) * speed, func():
		_egg.tell(best)
		Audio.note(4, -10.0)
		Audio.note(7, -12.0)
		UIJuice.haptic("QUICK_RISE", 0.5))
	_at((float(EconData.REVEAL["tell"]) + 0.12) * speed, _egg.heavy)
	_at((float(EconData.REVEAL["tell"]) + float(EconData.REVEAL["burst"])) * speed, _burst)


func _burst() -> void:
	var best := str(rev.get("best", "C"))
	var bc := UITokens.rarity(best)
	_egg.burst()
	var c := _egg.position + _egg.egg_point()
	UIJuice.flare(self, c, bc, "full" if best in ["E", "L", "M"] else "standard", 110.0)
	UIKit.sparkles(self, c, bc.lightened(0.35), int(EconData.REVEAL["particles"].get(best, 40)) / 2, 340.0)
	_flash.color = Color(bc.r, bc.g, bc.b, 0.0).lerp(Color(1, 1, 1, 0.55), 0.7)
	_rays.create_tween().tween_property(_rays, "color:a", 0.42, 0.25)
	Audio.play("geode_break", -2.0)
	Audio.play("crate_open", -4.0)
	UIJuice.haptic("THUD", 1.0)
	_at(float(EconData.REVEAL["fan"]) * speed - float(EconData.REVEAL["burst"]) * speed + 0.05, _fan)


func _fan() -> void:
	var c := _egg.position + _egg.egg_point()
	var stagger := float(EconData.REVEAL["fan_stagger"])
	for i in _cards.size():
		var card := _cards[i]
		card.visible = true
		card.position = c - CARD * 0.5
		card.scale = Vector2(0.35, 0.35)
		card.pivot_offset = CARD * 0.5
		card.modulate.a = 0.0
		var tw := card.create_tween().set_parallel(true)
		tw.tween_interval(i * stagger)
		tw.chain().tween_property(card, "position", slot(i), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
	Audio.play("whoosh_gate", -8.0)
	var t := 0.3 + _cards.size() * stagger
	for i in _cards.size():
		var card := _cards[i]
		var ft := card.flip_time(0.6 * speed)
		_at(t, func(): card.flip(ft))
		_at(t + ft + 0.04, card.sparks)
		t += 0.14 * speed
	_at(t + 0.2, _show_coins)
	_at(t + 0.75, _finish)


func _show_coins() -> void:
	if int(rev.get("coins", 0)) <= 0:
		return
	_coins_row.modulate.a = 1.0
	UIJuice.pop(_coins_row, 0.0, UITokens.ENTER, 0.6)
	Audio.play("coin", -6.0)


func _finish() -> void:
	if finished:
		return
	finished = true
	_events.clear()
	done.emit()


## Reduce Motion / Quick reveal: cross-fade straight to the cards with one chime.
func _quick() -> void:
	_struck = true
	_hint.visible = false
	_egg.tell(str(rev.get("best", "C")))
	_egg.burst()
	for i in _cards.size():
		var card := _cards[i]
		card.visible = true
		card.position = slot(i)
		card.show_face_now()
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.2)
	_coins_row.modulate.a = 1.0
	Audio.chord(7, true, -8.0)
	_at(0.25, _finish)


## After the reveal: the spent egg fades and the cards rise into its place (the result
## screen needs the room for the Best-upgrade row).
func collapse() -> void:
	if _lift > 0.0:
		return
	_lift = EGG - 34.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_egg, "modulate:a", 0.0, 0.25)
	tw.tween_property(_rays, "modulate:a", 0.0, 0.25)
	for i in _cards.size():
		tw.tween_property(_cards[i], "position", slot(i), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_coins_row, "position:y", EGG + CARD.y + 22 - _lift, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Jumps to the end state (cards up, bars full, coins shown) and fires `done`.
func skip() -> void:
	if finished:
		return
	Meta.note_skip("inline_reveal")
	_events.clear()
	_struck = true
	_hint.visible = false
	if int(_egg.cache.get_meta("stage", 0)) < 3:
		_egg.tell(str(rev.get("best", "C")))
		_egg.burst()
	_rays.color.a = 0.42
	for i in _cards.size():
		var card := _cards[i]
		card.visible = true
		card.modulate.a = 1.0
		card.position = slot(i)
		card.show_face_now()
	_coins_row.modulate.a = 1.0
	_finish()
