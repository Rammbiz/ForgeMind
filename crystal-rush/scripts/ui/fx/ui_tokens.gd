class_name UITokens
## Design tokens of the meta UI (arsenal_design.md §7.1, §7.3): motion timings, ceremony tiers,
## sizes and the palette the hub shares with the in-run HUD (UIKit holds the painted styles).
## Canvas is 720 px wide (≈ 2 px per pt on a phone): 44 pt touch = 88 px, 11 pt text = 22 px.

# ------------------------------------------------------------------ motion
const FAST := 0.15
const STD := 0.30
const SLOW := 0.45
## Exits are faster than entrances (§7.1: 280 / 180 ms).
const ENTER := 0.28
const EXIT := 0.18
## TRANS_BACK overshoot (Godot's default back curve is 1.70158).
const BACK := 1.70158
## Button press 0.92 -> 1.05 -> 1.0 in ~220 ms (+ haptic CLICK 0.5).
const PRESS_DOWN := 0.92
const PRESS_OVER := 1.05
const PRESS_TIME := 0.22
## Chip punch on a RewardFly arrival: 1.0 -> 1.2 -> 1.0 in 140 ms + wobble (amp 0.4, 0.4 s).
const CHIP_PUNCH := 1.2
const CHIP_PUNCH_TIME := 0.14
const WOBBLE_AMP := 0.4
const WOBBLE_TIME := 0.4
## Stagger between items popping in (stats, cards).
const STAGGER := 0.07

# ------------------------------------------------------------------ ceremonies (§7.3)
const CEREMONY_MICRO := 0.35       ## Barracks, hero levels without a milestone
const CEREMONY_STANDARD := 1.2     ## machine levels without a beat
const CEREMONY_FULL := 3.0         ## beats (Lv3/5/6/8/10/12/15), Ascension
## Upgrade flare phases (fractions of the tier duration): charge, flash 80 ms, hit-stop 70 ms.
const FLASH := 0.08
const HITSTOP := 0.07

# ------------------------------------------------------------------ layout (720 x 1280 canvas)
const MIN_TOUCH := 88.0
const MIN_TEXT := 22
const TOP_BAR_H := 92.0            ## 0-7 %
const TAB_BAR_H := 150.0           ## 88-100 %
const GUTTER := 22.0
const CARD_RADIUS := 26.0

# ------------------------------------------------------------------ palette
## Cream parchment for the warm tabs (Heroes, Barracks, Shop), ink for text on it.
const CREAM := Color(0.99, 0.94, 0.82)
const CREAM_DARK := Color(0.9, 0.79, 0.6)
const PARCH_INK := Color(0.29, 0.17, 0.08)
const PARCH_INK_DIM := Color(0.48, 0.34, 0.2)
## Arsenal stage: deep navy spotlight.
const STAGE_TOP := Color(0.06, 0.08, 0.2)
const STAGE_BOTTOM := Color(0.01, 0.015, 0.05)
## Upgrade-ready green and claim gold.
const READY := Color(0.42, 0.95, 0.42)
const CLAIM := Color(1.0, 0.8, 0.25)


## Duration of a ceremony tier ("micro" | "standard" | "full"), halved for standard and full
## when "Fast ceremonies" is on, and cut to the micro length with Reduce Motion.
static func ceremony(tier: String) -> float:
	var d := CEREMONY_MICRO
	match tier:
		"standard": d = CEREMONY_STANDARD
		"full": d = CEREMONY_FULL
	if tier != "micro" and bool(_setting("fast_ceremonies", false)):
		d *= 0.5
	if reduce_motion():
		d = minf(d, CEREMONY_MICRO)
	return d


## Ceremony tier of a machine level-up: full on a beat level, else standard.
static func upgrade_tier(beat: String) -> String:
	return "full" if beat != "" else "standard"


static func reduce_motion() -> bool:
	return bool(_setting("reduce_motion", false))


## Rarity UI colour (ArsenalData.RARITIES ui_color) for "C".."M".
static func rarity(r: String) -> Color:
	var d: Dictionary = ArsenalData.RARITIES.get(r, ArsenalData.RARITIES["C"])
	return d["ui_color"]


## A vivid family accent for UI (the data accents of Frost/Rune are too pale/dark for text).
static func family(f: String) -> Color:
	match f:
		"kinetic": return Color(1.0, 0.72, 0.5)
		"volt": return Color(1.0, 0.55, 1.0)
		"frost": return Color(0.62, 0.92, 1.0)
		"plasma": return Color(1.0, 0.34, 0.62)
		"tech": return Color(0.55, 1.0, 0.35)
		"rune": return Color(0.48, 0.55, 1.0)
		"rift": return Color(0.9, 0.82, 1.0)
	return Color(0.8, 0.85, 1.0)


static func _setting(key: String, default: Variant) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return default
	var meta := tree.root.get_node_or_null("Meta")
	if meta == null or (meta.get("account") as Dictionary).is_empty():
		return default
	return meta.call("setting", key, default)
