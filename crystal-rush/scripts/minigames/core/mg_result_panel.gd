class_name MinigameResultPanel
extends Control
## The shared result panel of a Fair mini-game (docs/design/minigames/README.md «Shell»): over a 0.42 scrim, a
## porcelain modal with the outcome, the three stars, score and best, what this play paid (coins, Road XP, Star
## Ore or its coins, new cosmetics) or plainly why it paid nothing, today's rewards left, the ad button ONLY when
## this win can be paid by an ad AND Ads.can_show() (never a disabled button), «Ще раз» (porcelain key) and
## «Назад». The bundle was booked and saved before this panel exists (MinigamesMeta.book).

signal retry_pressed
signal back_pressed
signal ad_pressed

const W := 640.0

var bundle := {}
var ad_button: Button
var retry_button: Button
var back_button: Button
var _rewards_box: VBoxContainer
var _left_label: Label


func setup(p_bundle: Dictionary) -> void:
	bundle = p_bundle


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, UITokens.SCRIM_MODAL)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var p := UIKit.panel("modal", Vector2(36, 30))
	p.custom_minimum_size = Vector2(W, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var won := bool(bundle.get("won", false))
	var title := UIKit.heading(Loc.t("MG_WIN" if won else "MG_LOSE"), 40, UIKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var st := MinigameUI.stars(int(bundle.get("stars", 0)), 64.0, true)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 28)
	v.add_child(score_row)
	score_row.add_child(UIKit.label(Loc.f("MG_SCORE", [Loc.num(int(bundle.get("score", 0)))]), 26, UIKit.INK, true))
	var best_key := "MG_NEW_BEST" if bool(bundle.get("new_best", false)) and int(bundle.get("score", 0)) > 0 else ""
	var best := UIKit.label(Loc.t(best_key) if best_key != "" else Loc.f("MG_BEST", [Loc.num(int(bundle.get("best_score", 0)))]),
			24, UIKit.GOLD_TEXT_GLASS if best_key != "" else UIKit.INK_DIM_GLASS)
	score_row.add_child(best)
	var dv := UIKit.divider(W - 120.0)
	dv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(dv)
	_rewards_box = VBoxContainer.new()
	_rewards_box.add_theme_constant_override("separation", 2)
	v.add_child(_rewards_box)
	_fill_rewards(bundle)
	_left_label = MinigameUI.body(_left_text(bundle), 22, UIKit.INK_DIM_GLASS)
	_left_label.visible = _left_label.text != ""
	v.add_child(_left_label)
	if bool(bundle.get("ad_offer", false)) and Ads.can_show():
		ad_button = UIKit.secondary_button(Loc.t("MG_AD_BUTTON"), "gift", Vector2(480, 72), 24)
		ad_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ad_button.pressed.connect(func() -> void: ad_pressed.emit())
		v.add_child(ad_button)
	retry_button = UIKit.cta_button(Loc.t("MG_RETRY"), "", Vector2(440, 96), 36)
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	v.add_child(retry_button)
	back_button = UIKit.plate_link(Loc.t("MG_BACK"), "back", Vector2(320, 64), 24)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	v.add_child(back_button)
	UIKit.pop_in(p, 0.0, MinigameUI.POP)


## The ad was watched: `b` = MinigamesMeta.book_ad's bundle. The ad button goes away and the paid rows show.
func show_ad_bundle(b: Dictionary) -> void:
	if ad_button and is_instance_valid(ad_button):
		ad_button.queue_free()
		ad_button = null
	if not bool(b.get("ok", false)):
		return
	for c in _rewards_box.get_children():
		c.queue_free()
	_fill_rewards(b)
	_left_label.text = Loc.t("MG_AD_DONE")
	_left_label.visible = true


func _fill_rewards(b: Dictionary) -> void:
	var rows := reward_rows(b)
	if rows.is_empty():
		if bool(b.get("coins_capped", false)):
			_rewards_box.add_child(MinigameUI.body(Loc.t("MG_COINS_CAP"), 24, UIKit.INK))
			return
		var why := "MG_NO_REWARD_LOSS" if str(b.get("reason", "")) == "loss" else "MG_NO_REWARD_FREE"
		_rewards_box.add_child(MinigameUI.body(Loc.t(why), 24, UIKit.INK))
		return
	_rewards_box.add_child(UIKit.section(Loc.t("MG_REWARD")))
	for r: Array in rows:
		_rewards_box.add_child(UIKit.list_row(str(r[0]), str(r[1]), str(r[2]), UIKit.INK))
	if bool(b.get("coins_capped", false)):
		_rewards_box.add_child(MinigameUI.body(Loc.t("MG_COINS_CAP"), 22, UIKit.INK_DIM_GLASS))


## [label, value, icon] rows of what bundle `b` paid ([] = nothing).
static func reward_rows(b: Dictionary) -> Array:
	var out: Array = []
	if int(b.get("coins", 0)) > 0:
		out.append([Loc.t("MG_ROW_COINS"), "+" + Loc.num(int(b["coins"])), "coin"])
	if int(b.get("road_xp", 0)) > 0:
		out.append([Loc.t("MG_ROW_ROAD"), "+" + Loc.num(int(b["road_xp"])), "map"])
	if int(b.get("ore", 0)) > 0:
		out.append([Loc.t("MG_ROW_ORE"), "+" + Loc.num(int(b["ore"])), "glint"])
	if int(b.get("ore_coins", 0)) > 0:
		out.append([Loc.t("MG_ROW_ORE_COINS"), "+" + Loc.num(int(b["ore_coins"])), "coin"])
	var all := MinigameRegistry.cosmetics()
	for c in (b.get("cosmetics", []) as Array):
		var cd: Dictionary = all.get(str(c), {})
		var kind_key := "MG_KIND_" + str(cd.get("kind", "title")).to_upper()
		out.append([Loc.f("MG_ROW_NEW", [Loc.t(kind_key)]), Loc.t(str(cd.get("name", str(c)))), "trophy"])
	return out


static func _left_text(b: Dictionary) -> String:
	if bool(b.get("rewarded", false)) or str(b.get("reason", "")) == "loss":
		return Loc.f("MG_LEFT_TODAY", [Loc.num(int(b.get("rewarded_left", 0))), Loc.num(int(EconData.FAIR["rewarded_per_day"]))])
	return ""
