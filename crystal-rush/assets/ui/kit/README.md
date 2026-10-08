# UI v2 kit: bitmap names for the owner's assets

Drop a PNG into `crystal-rush/assets/ui/kit/` with one of the names below. The game uses it in place of the element it draws
in code now. Godot has to import the file once (open the editor, or run `godot --headless --path . --import`).
Remove the file and the procedural version comes back. No code change is needed.

How it works: `UIKit.kit_texture(name)` returns `res://assets/ui/kit/<name>.png` if it exists, otherwise null. Nine-patch
surfaces take their margins from `assets/ui/kit/kit.json`, which already holds defaults for every name in table A. If your
art uses different corner sizes, edit the numbers there.

General rules for all bitmaps:
- PNG, RGBA, transparent background, sRGB, no baked text.
- Paint at **2x** the listed size (the game canvas is 720 wide; phones show it at about 2 px per point). In kit.json, margins
  are in **source** pixels, so double them for 2x art.
- Light from the upper left. Soft shadows go *inside* the PNG, and `expand` in kit.json says how far they reach past the
  element's rectangle.
- Style: Genshin-grade restraint. Cream `#F7F1E6`, one gold hairline `#C9A86A`, 45° chamfered corners (6 to 12 px at 1x),
  soft shadow, no thick outlines, no ✦ sparkles, no stars.

## A. Nine-patch surfaces (`StyleBoxTexture`, stretched)

`margins` = [left, top, right, bottom] at 1x. The defaults below are already in kit.json; double them for 2x art.

| Name | What it is | Typical size (1x) | Default margins | Notes |
|---|---|---|---|---|
| `panel` | cream document panel (also `cream`, `parch`) | 600×400 | 40,40,40,40 | outer hairline plus an inner hairline 5 px in, chamfer 12, shadow 16 px |
| `modal` | modal / dialog panel | 640×480 | 44,44,44,48 | deeper shadow |
| `cream_glass` | translucent cream over 3D (also `glass`) | 400×120 | 32,32,32,32 | 85–90 % alpha |
| `sheet` | bottom-sheet body | 720×800 | 44,56,44,40 | the arch + keystone on top are drawn in code (KitNav.draw_arch_top) |
| `card` / `card_sel` / `card_dim` | cream card / selected (amber double line + glow) / unowned | 216×300 | 28 | |
| `pill` | porcelain HUD plate | 200×52 | 24 | 92 % alpha, gold line |
| `plate` | currency plate body | 172×52 | 24 | the icon is separate (`icon_coin` …) |
| `chip` | small chip / caption | 120×30 | 16 | |
| `ribbon` | title / world ribbon body | 380×44 | 28,22,28,22 | marquise terminals are drawn in code |
| `toast` / `banner` | toast / tutorial hint | 360×64 | 32 | |
| `button` / `button_pressed` / `button_disabled` | secondary cream button | 240×72 | 26 | pressed = `#E3D8C4` |
| `primary` / `primary_pressed` / `primary_disabled` | **amber jewel CTA body** (ГРАТИ, Призвати, Покращити, Забрати) | 448×104 | 40,36,40,40 | `#FFE6A3 → #F5AE45 → #D9822E`, fine rim, **no gem** (the topaz is `cta_topaz`) |
| `primary_compact` | CTA body for narrow price buttons | 170×72 | 32,30,32,34 | |
| `ghost` | transparent hairline button | 200×64 | 24 | |
| `seg` / `seg_sel` | segmented track / raised selected chip | 600×60 / 200×52 | 20 / 22,20,22,22 | `seg_sel` has the amber underline |
| `tabbar` | legacy nav bar body | 720×120 | 40,40,40,20 | |
| `nav_bar` | **bottom nav bar with the arched top edge** | 720×128 | 60,48,60,24 | include the arch, hairline and keystone; drawn 8 px above the bar rect |
| `tab_sel` | raised selected tab chip | 140×120 | 28 | |
| `well` | inset well (also `parch_well`) | 300×60 | 16 | |
| `band_amber` / `band_cool` | full-width result band (victory / defeat) | 720×140 | 24,28,24,28 | |
| `tag_new` | NEW tag | 56×22 | 12 | |
| `card_frame` | gold frame over gem cards | 216×300 | 24 | only the frame; the gem ground comes from `card_<gem>` |

## B. Single images (drawn at the element's size)

| Name | What it is | Size (1x) | Notes |
|---|---|---|---|
| `cta_topaz` | **the cut topaz at the left end of the CTA**, in its gold bezel | 56×72 (tall cushion) | drawn at height = 62 % of the button height; aspect is kept |
| `edge_button` | round edge button disc (cream, thin gold ring) | 76×76 | the line icon is drawn on top in code |
| `socket_cream` / `socket_slate` | class / element / faction socket discs | 64×64 | slate = `#2B3245` with a gold ring |
| `badge_notify` | gold "!" badge disc | 28×28 | the glyph is drawn on top in code |
| `badge_gem` | small gold cut gem for the bottom-nav tab badges | 40×40 | drawn at 20×20 with a soft glow behind it |
| `nav_medallion` | **raised round amber medallion** of the active nav tab | 104×104 | the painted tab icon is drawn on top |
| `card_quartz`, `card_sapphire`, `card_amethyst`, `card_topaz`, `card_opal` | gem-card **grounds** (gradient + that gem's fracture pattern) | 216×300 | stretched to the card; the bust, footer, pips, mark and frame are drawn on top |
| `fx_glint` | particle sprite: our refraction glint (4 rays, one long) | 64×64 | white, additive |

## C. Icons: `icon_<kind>.png` (square, drawn at the icon's rect)

Painted icons. These are coloured; the game uses only their alpha for dimming.

| Name | Motif |
|---|---|
| `icon_coin` | gold coin with an embossed facet rhombus |
| `icon_gem` | sapphire brilliant (blue) |
| `icon_crown` | gold crown with a sapphire |
| `icon_blueprint` | blue blueprint sheet |
| `icon_beacon` | Маяк: a topaz on a cream post, glowing |
| `icon_tome` | violet tome with a keystone |
| `icon_fragment` | amethyst trillion shard |
| `icon_tab_shop` | **Магазин**: coin pouch |
| `icon_tab_arsenal` | **Арсенал**: cannon on a cog |
| `icon_tab_play` | **Грати**: crystal bridge arch with a keystone |
| `icon_tab_heroes` | **Герої**: sunburst shield |
| `icon_tab_barracks` | **Казарми**: tent with a pennant |

Line icons. These are monochrome and get **tinted** by the game (ink on cream, gold on slate, warm white on scenes), so
paint them **white** on transparent with 2–3 px strokes (at 1x) and rounded caps:
`icon_settings icon_back icon_close icon_info icon_help icon_lock icon_unlock icon_check icon_plus icon_minus icon_home
icon_pause icon_play icon_fast icon_restart icon_sound icon_music icon_vibrate icon_globe icon_odds icon_events icon_mail
icon_quests icon_chest icon_portal icon_team icon_gift icon_calendar icon_filter icon_sort icon_search icon_chevron
icon_chevron_down icon_arrow_up icon_swap icon_auto icon_deck icon_helmet icon_target icon_edit icon_trophy icon_map`

Classes: `icon_cls_warrior` (crossed blades), `icon_cls_ranger` (bow), `icon_cls_mage` (orb in a ring),
`icon_cls_guardian` (tower shield), `icon_cls_healer` (lantern).
Elements: `icon_el_kinetic` (double chevron), `icon_el_volt` (bolt), `icon_el_frost` (crystal flake), `icon_el_plasma`
(flame drop), `icon_el_tech` (cog), `icon_el_rune` (rune lozenge), `icon_el_rift` (crescent rift).
Factions: `icon_fac_dawn` (sunrise), `icon_fac_wildfang` (claw marks), `icon_fac_stoneheart` (faceted heart),
`icon_fac_celestial` (crescent + small rhombus).

Any other icon kind (machines, statuses, caches …) can be overridden the same way: `icon_<kind>.png`.

## D. Priority order for the owner (the biggest visual win first)

1. `primary` + `cta_topaz` (the ГРАТИ / Призвати jewel)
2. `icon_tab_*` ×5 + `nav_medallion` + `nav_bar`
3. `icon_coin`, `icon_gem`, `icon_crown` (top bar)
4. `card_<gem>` ×5 + `card_frame`
5. `panel`, `sheet`, `button`, `plate`, `edge_button`
