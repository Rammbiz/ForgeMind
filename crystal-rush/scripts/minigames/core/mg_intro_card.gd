class_name MinigameIntroCard
extends Control
## The shared intro card of a Fair mini-game (docs/design/minigames/README.md «Shell»): over a 0.42 scrim, a
## porcelain modal with the game's title, the host character's card art (hero or champion; owned or not), the
## host's one line, the rules, today's reward state and the porcelain key button «Грати». Text wraps, never cut.

signal play_pressed
signal back_pressed

const W := 640.0

var entry := {}          ## MinigameRegistry.game(id)
var status := {}         ## Meta.fair_status(id) (or a dev override)
var mode := "free"
var play_button: Button


func setup(p_entry: Dictionary, p_status: Dictionary, p_mode: String) -> void:
	entry = p_entry
	status = p_status
	mode = p_mode


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
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var title := UIKit.heading(Loc.t(str(entry.get("title", ""))), 40, UIKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var dv := UIKit.divider(W - 120.0)
	dv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(dv)
	# Host: card art + name + the one line.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	var host := str(entry.get("host", ""))
	var card := UIKit.gem_card(MinigameUI.char_gem(host), Vector2(200, 266))
	card.art.texture = HeroArt.card_texture(host)
	card.title = MinigameUI.char_name(host)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UIKit.section(Loc.t("MG_HOSTS")))
	var hn := UIKit.heading(MinigameUI.char_name(host), 28, UIKit.INK)
	hn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hn)
	col.add_child(MinigameUI.body(Loc.f("MG_QUOTE", [Loc.t(str(entry.get("intro", "")))]), 26, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	var rules := MinigameUI.body(Loc.t(str(entry.get("rules", ""))), 24, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(rules)
	v.add_child(UIKit.hairline(W - 72.0))
	var ml := MinigameUI.body(mode_line(status, mode), 22, UIKit.INK_DIM_GLASS)
	v.add_child(ml)
	play_button = UIKit.cta_button(Loc.t("MG_PLAY"), "", Vector2(440, 96), 36)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	v.add_child(play_button)
	var back := UIKit.plate_link(Loc.t("MG_BACK"), "back", Vector2(320, 64), 24)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	v.add_child(back)
	UIKit.pop_in(p, 0.0, MinigameUI.POP)


## Today's reward line: "Нагород сьогодні лишилося: 2 з 3" (rewarded) or the free-play line.
static func mode_line(st: Dictionary, p_mode: String) -> String:
	if p_mode == "rewarded":
		return Loc.f("MG_LEFT_TODAY", [Loc.num(int(st.get("rewarded_left", 0))), Loc.num(int(st.get("rewarded_per_day",
				EconData.FAIR["rewarded_per_day"])))])
	return Loc.t("MG_MODE_FREE")
