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

# ------------------------------------------------------------------ motion v2 (Genshin-soft menus)
## Menus: soft fades/slides 180-280 ms with ease-out (no overshoot). Rewards/upgrades stay juicy.
const MENU_IN := 0.24
const MENU_OUT := 0.18
const MENU_SLIDE := 48.0           ## px a sheet / panel travels while fading in
const TAB_FADE := 0.18             ## content cross-fade when a tab changes
const GLOW_PERIOD := 2.4           ## gentle breathing glow (ready CTA, notify badge)
const CTA_SWEEP_EVERY := 4.0       ## light sweep across the amber CTA
const CARD_STAGGER := 0.04         ## Genshin card pop-in step

# ------------------------------------------------------------------ layout (720 x 1280 canvas)
const MIN_TOUCH := 88.0
const MIN_TEXT := 20
const TOP_BAR_H := 96.0            ## 0-96: portrait ring + currency plates
const RIBBON_Y := 104.0            ## world ribbon / screen title row (44 tall)
const NAV_H := 100.0               ## v3: slim frosted strip (was a 120 slab + 28 medallion rise)
const NAV_RISE := 10.0             ## v3.1: the slender Play ring rises 10 px above the hairline, no more
const TAB_BAR_H := NAV_H + NAV_RISE ## legacy name: room the nav takes at the bottom (110)
const DOCK_H := 132.0              ## a screen dock (back tab + CTA) above the nav
const GUTTER := 24.0               ## side margin
const GAP := 12.0                  ## default gap between cards / rows
const ROW_H := 64.0                ## list row pitch (hairline divider, no boxes)
const CARD_RADIUS := 10.0          ## legacy name: v2 corners are 45-degree chamfers
const CHAMFER_L := 12.0            ## CTA, sheets, modals
const CHAMFER := 10.0              ## panels, cards
const CHAMFER_S := 8.0             ## buttons, plates
const CHAMFER_XS := 6.0            ## chips, tags
const HAIRLINE_W := 1.0            ## v3: legacy canvas width; new code sizes lines in DEVICE px (UIKit.px)
const HAIRLINE_PX := 1.0           ## v3: every frame / divider / ring = 1 device px (crisp at 1080 / 1440)
const SELECT_PX := 1.5             ## v3.1: active underline, active Play ring, CTA rim, selected card. Nothing heavier.

# ------------------------------------------------------------------ v3.1 porcelain glass (binding spec ui_v3_spec.md §1)
## Glass = translucent cream over the frosted world (KitGlass) + ONE 1 px gold hairline + a 1 px
## inner LIGHT line just inside it (light catching the glass edge). No dark borders, soft shadows.
## Lines (§1.1). At s < 0.9 (540-class) gold lines on frost draw at 1.25x (UIKit.line_px).
const LINE_GOLD := Color(0.788, 0.659, 0.416, 0.78)   ## #C9A86A @ 0.78: the 1 px gold frame on glass
const LINE_GOLD_DEEP := Color(0.659, 0.514, 0.247, 0.90) ## #A8833F @ 0.90: lines that must read on light frost (nav hairline, Play ring, flourishes)
const LINE_LIGHT := Color(1.0, 1.0, 1.0, 0.62)        ## inner light line (top), fades to 0.18 at the bottom
const LOW_DENSITY_LINE := 1.25     ## §1.1a: line width factor when the device scale is < 0.9
## Glass (§1.2).
const GLASS_TOP := Color(0.988, 0.976, 0.949, 0.80)   ## #FCF9F2 @ 0.80: flat glass panel tint (no snapshot)
const GLASS_BOT := Color(0.969, 0.949, 0.910, 0.86)   ## #F7F2E8 @ 0.86
const GLASS_TEXT_A := 0.94         ## any surface under BODY text: text beds, list rows, toasts (0.93-0.99)
const GLASS_THIN_A := 0.72         ## plates / chips / pills / ribbons over the 3D (+0.10..0.14 per kind)
const SHEET_FILL := Color(0.969, 0.949, 0.910, 0.84)  ## sheet body outside the text zones (flat fallback)
const FROST_RIM_TINT := 0.62       ## frosted modal / sheet body: share of cream over the world (rim, margins)
const FROST_TEXT_TINT := 0.94      ## effective tint behind the text column (the text bed)
const FROST_DESAT := 0.25          ## modal / sheet frost: the sky stays faintly blue (0.45 turned it greige)
const FROST_LIFT := 0.22           ## ... and bright (Genshin glass, not a grey rim on paper)
const NAV_FROST_CONTRAST := 0.75   ## nav frost keeps more of the world (the floor ring, map lines ghost through)
const NAV_FROST_DESAT := 0.30
const BED_FEATHER_MODAL := 12.0    ## modal / panel text bed feather (a crisp glass rim, no milky band)
const FROST_TINT := FROST_RIM_TINT ## legacy name
const FROST_MODAL_TINT := 0.72     ## modal / panel rim: closer to the bed (no grey inner band), still glass
const NAV_TINT_TOP := 0.20         ## nav strip tint at the hairline (v3.1 fix: 0.40 read opaque; the world ghosts through)
const NAV_TINT_MID := 0.80         ## ... at the label cap height
const NAV_TINT_BOT := 0.88         ## ... at the strip bottom
const BACKDROP_VEIL := [0.42, 0.48, 0.56] ## cream veil over the frosted world on the cream tabs: PAPER_0 top / mid, PAPER_1 bottom
const SHADOW_A := 0.10             ## soft slate shadow (x0.6-1.4 per kind); the CTA glows warm at 0.18 instead
const SCRIM_MODAL := 0.42          ## modal dim (v2 0.50, A 0.36); ceremonies stay at SCRIM_CEREMONY
const SCRIM_CEREMONY := 0.56
## Ink (§1.3). Rule: text >= 4.5:1 on the worst 5 % of its own surface, glyphs >= 3.5:1.
const INK_DIM_GLASS := Color("#62574F")   ## secondary text on any glass / frost, inactive nav labels (4.8 worst)
const GOLD_TEXT_GLASS := Color("#7A5520") ## engraved caps / amber-ink labels on frost; active nav label (4.6 worst)
## Bottom nav v3.1 (§1.4, §6; 720 canvas): a frosted strip, monoline gold glyphs, one clear active state.
const NAV_GLYPH := 48.0            ## glyph box (stroke 2.0 canvas px, min UIKit.px(1.5))
const NAV_STROKE := 2.0
const NAV_LABEL := 22              ## label size, Medium, +1 px tracking, both states
const NAV_GOLD := Color("#7E6136") ## inactive glyph (3.95:1 worst frost)
const NAV_GOLD_ON := Color("#5A4220") ## active glyph (7.6:1 typical)
const NAV_PLAY_R := 30.0           ## slender Play ring (60 px double ring)
const NAV_SAG := 5.0               ## hairline arch: the sides sit 5 px lower than the centre
const NAV_WASH := Color("#F1D99A") ## gold-leaf wash behind the active glyph (a glow, never a tile)
const NAV_WASH_A := 0.50           ## wash alpha (white core NAV_WASH_CORE_A): visible at arm's length (MF-1)
const NAV_WASH_CORE_A := 0.40
const NAV_DUOTONE := 0.40          ## active glyph duotone fill share
const NAV_LABEL_ON := Color("#80470A") ## active nav label: clear burnt amber (6.4:1 typical, AA-safe at 540)
const NAV_PLAY_QUIET := 0.72       ## inactive Play topaz value (the active tab must outweigh it, MF-2)
const NAV_PLAY_QUIET_A := 0.85     ## ... its alpha; the inactive ring sits at 0.70
const NAV_BADGE := Color("#E3922C") ## 9 px amber diamond badge

# ------------------------------------------------------------------ palette v2 (fusion §6.5)
## Surfaces (cream "documents you hold").
const PAPER_0 := Color("#FBF7EF")  ## raised chip, porcelain HUD plate, panel highlight
const PAPER_1 := Color("#F7F1E6")  ## panel body
const PAPER_2 := Color("#ECE5D8")  ## secondary button, card footer strip
const PAPER_3 := Color("#E3D8C4")  ## pressed, wells, unowned cards
## Gold line language.
const HAIRLINE := Color("#C9A86A") ## hairlines, frames, chamfer lines (decorative)
const GOLD_HI := Color("#E3CB94")  ## lines and labels over art
const GOLD_TEXT := Color("#8A6A2F") ## engraved caps on opaque cream or the text bed only (4.5:1)
## Text.
const INK := Color("#4B5669")      ## text on cream (6.6:1)
const INK_DIM := Color("#6E625B")  ## taupe labels on OPAQUE cream only (5.3:1); on glass use INK_DIM_GLASS
const INK_SOFT := Color("#675C56") ## small labels that need more contrast (18 px, 5.5:1)
const ON_SCENE := Color("#FFF8EC") ## warm white on 3D / art, always with a soft shadow
const SCRIM := Color("#1E2433")    ## shadows, scrims (never a flat dark panel)
## Key action (amber jewel CTA).
const CTA_HI := Color("#FFE6A3")
const CTA := Color("#F5AE45")
const CTA_LO := Color("#D9822E")
const CTA_RIM := Color("#9C5A1F")
const TOPAZ := Color("#FFB52E")
## CTA study (owner: the amber reads as AI): the KitCTA body style. "amber" (shipped) |
## "porcelain" | "ink" | "sapphire" | "champagne". Dev galleries override with --cta=<name>.
const CTA_STYLE := "amber"
const CTA_STYLES: Array[String] = ["amber", "porcelain", "ink", "sapphire", "champagne"]
## The live CTA style (KitCTA.style forwards here). Read from `--cta=<name>` on the command line
## at load, so the theme and every painted style see it before the first screen is built.
static var cta_style: String = _boot_cta_style()
## Refined calm study styles ("ink", "porcelain"): the key-action path loses its amber too (nav
## Play crystal, hub progress diamonds, Victory band, multiplier glow, toggle fill, lux primary).
const KEY_INK := Color("#2C3158")      ## ink enamel, top
const KEY_INK_LO := Color("#252A4D")   ## ink enamel, bottom (a ~3 % step, nearly flat)
const KEY_GOLD := Color("#C9AE78")     ## the one muted gold hairline of the calm key button
const KEY_LABEL_DARK := Color("#2B2440")  ## ink label on porcelain / the calm Victory title
const TOPAZ_HI := Color("#FFC860")
## States.
const PLUS := Color("#2F7322")     ## stat increase on cream (5:1)
const PLUS_ON_SCENE := Color("#8DE302")
const ALERT := Color("#C0392B")    ## alert text
const ALERT_FILL := Color("#D4515B")
const NEW_TAG := Color("#FFCF3F")
const NEW_INK := Color("#6A4512")
const NOTIFY := Color("#F5AE45")   ## gold "!" badge (no red dots)
const SOCKET := Color("#2B3245")   ## slate socket behind family glyphs
## Home stage.
const SKY_TOP := Color("#7DB9E8")
const SKY_MID := Color("#BFE0F2")
const HORIZON := Color("#FBE3BC")
const SUN := Color("#FFD98A")
const BRIDGE_BODY := Color("#DDF6FF")
const BRIDGE_EDGE := Color("#8FD9F0")

## The five gems (rarity ladder C R E L M). `top`/`bot` = card ground gradient, `rim` = inner
## rim + vivid accent, `light` = lit facet pip / glints, `deep` = shadow facet, `cut` = gem-cut
## silhouette (colour-blind code): round / square / triangle / star / eye.
const GEMS := {
	"quartz": {"name": "GEM_QUARTZ", "top": Color("#77879A"), "bot": Color("#CAD4DF"), "rim": Color("#E2E9F0"),
			"light": Color("#F2F5F8"), "deep": Color("#5C6672"), "cut": "round", "metal": Color("#AEB7C2")},
	"sapphire": {"name": "GEM_SAPPHIRE", "top": Color("#2D6A9C"), "bot": Color("#63A9DD"), "rim": Color("#3FA9FF"),
			"light": Color("#A8DBFF"), "deep": Color("#1B4E7E"), "cut": "square", "metal": Color("#E8E6E0")},
	"amethyst": {"name": "GEM_AMETHYST", "top": Color("#553A8F"), "bot": Color("#9C7BD0"), "rim": Color("#B06CFF"),
			"light": Color("#DCC2FF"), "deep": Color("#7A35D6"), "cut": "triangle", "metal": Color("#E3C67E")},
	"topaz": {"name": "GEM_TOPAZ", "top": Color("#A4612A"), "bot": Color("#E8AE5C"), "rim": Color("#FFB52E"),
			"light": Color("#FFE3A6"), "deep": Color("#C26A12"), "cut": "star", "metal": Color("#E3C67E")},
	"opal": {"name": "GEM_OPAL", "top": Color("#1A1530"), "bot": Color("#3A2D63"), "rim": Color("#E8D8FF"),
			"light": Color("#F3EAFF"), "deep": Color("#120E22"), "cut": "eye", "metal": Color("#E3C67E"),
			"flecks": [Color("#7FE3FF"), Color("#B48CFF"), Color("#FF9FD6"), Color("#FFE28A")]},
}
const GEM_ORDER: Array[String] = ["quartz", "sapphire", "amethyst", "topaz", "opal"]
const RARITY_GEM := {"C": "quartz", "U": "quartz", "R": "sapphire", "E": "amethyst", "L": "topaz", "M": "opal"}

# ------------------------------------------------------------------ legacy palette (remapped to v2)
## Cream parchment for the warm tabs (Heroes, Barracks, Shop), ink for text on it.
const CREAM := PAPER_1
const CREAM_DARK := PAPER_3
const PARCH_INK := INK
const PARCH_INK_DIM := INK_DIM
## Arsenal stage (was a deep navy spotlight): now a warm, light workshop haze.
const STAGE_TOP := Color("#E9DCC3")
const STAGE_BOTTOM := Color("#C9B79A")
## Upgrade-ready green and claim gold (readable on cream).
const READY := PLUS
const CLAIM := CTA


## Gem key ("quartz".."opal") of a rarity letter ("C".."M") or a gem key passed through.
static func _boot_cta_style() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cta="):
			return a.trim_prefix("--cta=")
	return CTA_STYLE


## True for the refined calm key-action styles (no amber on the key-action path).
static func calm_cta() -> bool:
	return cta_style == "ink" or cta_style == "porcelain"


## The accent of the key-action path: amber (shipped) or the calm deep gold line.
static func key_line() -> Color:
	return LINE_GOLD_DEEP if calm_cta() else CTA_LO


static func gem_of(r: String) -> String:
	if GEMS.has(r):
		return r
	return str(RARITY_GEM.get(r, "quartz"))


## The gem spec dictionary (GEMS entry) of a rarity letter or gem key.
static func gem(r: String) -> Dictionary:
	return GEMS[gem_of(r)]


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
