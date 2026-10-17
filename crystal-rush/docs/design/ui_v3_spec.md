# Crystal Rush: UI v3 binding spec ("porcelain glass", final)

**Status:** BINDING for the implementation workflow. This file wins over the three direction specs. `ui_v2_contract.md` still holds for everything this file does not change (§10).
**Owner request (verbatim):** "працюй над дизайном, дай прозорості і витонченості ліній" + "нижнє меню також перероби, надто якесь мультяшне і дешеве".
**Direction:** Genshin x AFK Journey, portrait, much closer to Genshin, bright cream, gold and ink. No dark sci-fi UI, no generic web tab bar, no "2010" ornament.
**Owner board:** `uiv3/owner_board.png` (current v2, then А/Б/В with А marked «Обрано»).

---

## 0. Decision

**Winner: A "porcelain glass".** All three judges ranked it first (A > C > B): owner fidelity 8.5, art director 7.5, mobile UX/perf 7.5. A is the only direction where the owner sees all three asks at a glance:

- **Transparency:** real frost through the nav, the modals, the Heroes sheet and the Shop/Barracks backdrops.
- **Lines:** one device px gold, everywhere.
- **Nav:** one frosted strip, one fading hairline, and one family of thin gold glyphs. This is the Genshin Paimon-menu idiom, with no medallion and no stickers.

**Start from:**

| | |
|---|---|
| Worktree | `/home/user/ForgeMind/.claude/worktrees/wf_2ce040fe-e4e-3` |
| Branch | `worktree-wf_2ce040fe-e4e-3` |
| Commit | `102dab89952bcd57f9cf51a6f33917d85107b06f` (on base `0b945a1`) |

Main (`ccr-ea3be44f-lbour0`) is now at `124eccf`. The two new commits touch no UI files (`scripts/ui`, `shaders` diff is empty), so rebase A onto `124eccf` first. That rebase should be conflict-free.

**Heroes UI** lives on branch `h3a-ui` (`2a3f3c1`, worktree `.claude/worktrees/h3a-ui`, forked at `c402bfb`). It is not in main yet.

- Among the design-system and hub files it only touches `scripts/ui/hub/tab_heroes.gd` (+49 lines).
- Its 5.6 k lines under `scripts/ui/heroes/**` and `scripts/ui/summon/**` call these APIs: `UIKit.label/panel/button/section/hairline/divider/lux/socket/segmented/cta_button/edge_button/toast/scroll_fade/soft_shadow/scene_label/glow_texture` and `GemDraw.outline/cut_points/draw_gem/draw_glint/draw_keystone/draw_marquise/draw_hairline/chamfer_rect/draw_mark`.
- **Every one of those signatures must stay source-compatible** (§12, phase 3).

**Grafts taken from the runners-up:**

| from | graft | where in this spec |
|---|---|---|
| B | 1.5 device px amber active underline with facet ends | §6.4 |
| B | Vector elongated cut-gem CTA (tracked Bold caps, flat amber, 1 px table light, no streak, no painted chip) | §7.6 |
| B | Shadow knock-out under translucent bodies | §4.4 |
| B | Corner brackets, as the light form of C's flourish on the selected card | §3.4 |
| C | Corner flourishes, only on modals (top corners) and the selected card (diagonal pair) | §3.4 |
| C | Nav hairline as a very gentle arch that fades to the sides | §6.2 |
| C | Soft gold-leaf wash behind the active glyph, as a glow and never a tile | §6.4 |
| C | Field-cannon meaning for Arsenal, redrawn in A's monoline | §6.5 |
| C | Text surfaces 93-99 % opaque where body text sits; frost only in rims, headers and margins | §4.3 |
| C | Frosted world behind all four cream tabs | §4.5 |
| C | Inactive nav labels Medium in a darker taupe | §5 |
| C | 48 px glyph box and a slightly heavier stroke | §6.5 |

**Never take:**

- C's gold-leaf octagon tile, crown-for-Play, winged-helm or castle clip-art, hatch strokes, or scroll filigree on dividers.
- B's floating outlined plate, the ▶ lozenge, or slate glyphs.

---

## 1. Tokens (`scripts/ui/fx/ui_tokens.gd`, v3 block; replaces A's v3 block)

Canvas is 720 x 1280 (`canvas_items` stretch). **px** means canvas px. **dpx** means device px, written in code as `UIKit.px(n)`. The device scale is `s = UIKit.ui_scale()`: 0.75 at 540, 1.0 at 720, 1.5 at 1080, 2.0 at 1440.

### 1.1 Lines

| token | value | use |
|---|---|---|
| `HAIRLINE_PX` | 1.0 dpx | every frame, divider, row rule, ring, nav hairline |
| `SELECT_PX` | 1.5 dpx | active underline, active Play ring, CTA rim, selected card frame. **Nothing is heavier than 1.5 dpx except §1.1a.** |
| `LINE_GOLD` | `#C9A86A` @ 0.78 | gold frame line on glass |
| `LINE_GOLD_DEEP` | `#A8833F` @ 0.90 | lines that must read on light frost: nav hairline, Play ring, flourishes |
| `LINE_LIGHT` | `#FFFFFF` @ 0.62 → 0.18 down the sides | inner light line, 1 dpx, directly inside the gold line |
| `HAIRLINE_W` | 1.0 | legacy canvas name, kept for old callers |

**§1.1a Low-density floor:** when `s < 0.9` (540-class), every 1 dpx gold line on a frosted surface draws at 1.25 dpx and every 1.5 dpx line draws at 1.75 dpx. Add `UIKit.line_px(n)`, which returns `px(n * (1.25 if s < 0.9 else 1.0))`. This stops lines falling to ~0.5 alpha grey on PenTile AMOLED (UX must-fix 8).

### 1.2 Glass

| token | value | use |
|---|---|---|
| `GLASS_TOP` / `GLASS_BOT` | `#FCF9F2` @ 0.80 / `#F7F2E8` @ 0.86 | flat glass panel tint (no snapshot) |
| `GLASS_TEXT_A` | **0.94** (range 0.93-0.99) | **any surface under body text**: text beds, list rows, sheet stat zones, toasts, flat modal 0.97 |
| `GLASS_THIN_A` | 0.72 (+0.10..0.14 per kind) | plates, chips, pills, ribbons over the 3D |
| `SHEET_FILL` | `#F7F2E8` @ 0.84 | sheet body outside text zones |
| `FROST_RIM_TINT` | 0.62 | frosted modal/sheet body: share of cream over the world, rim and empty margins |
| `FROST_TEXT_TINT` | 0.94 | effective tint behind the text column (via the text bed, §4.3) |
| `NAV_TINT_TOP` / `NAV_TINT_MID` / `NAV_TINT_BOT` | 0.40 / 0.80 / 0.88 | nav strip tint ramp at the hairline / label cap height / strip bottom (§6.3) |
| `BACKDROP_VEIL` | PAPER_0 @ 0.42 top, 0.48 mid, PAPER_1 @ 0.56 bottom | cream veil over the frosted world on the cream tabs |
| `SHADOW_A` | 0.10 (x0.6-1.4 per kind) | slate `#1E2433` soft shadow; the CTA uses a warm glow at 0.18 instead |
| `SCRIM_MODAL` | **0.42** (was 0.50 in v2, 0.36 in A) | modal dim; ceremonies stay at 0.56 |

**Why the scrim is 0.42.** The owner judge asked to keep A's lighter dim. The UX judge measured that at 0.36 the page and nav behind a modal are as bright as the modal (mean luma 153), so the modal loses focus. 0.42 keeps the room light and still separates figure from ground, because the frost inside the modal now carries the transparency.

### 1.3 Ink (new or changed tokens are bold)

| token | hex | contrast: cream / typical frost / worst frost | use |
|---|---|---|---|
| `INK` | `#4B5669` | 6.6 / 6.0 / 5.1 | body text |
| `INK_DIM` | `#6E625B` | 5.3 / 4.8 / 4.1 | secondary text **on opaque cream only** |
| **`INK_DIM_GLASS`** | `#62574F` | 6.2 / 5.6 / 4.8 | secondary text on any glass or frost, inactive nav labels |
| `GOLD_TEXT` | `#8A6A2F` | 4.5 / 4.0 / 3.4 | engraved caps **on opaque cream or the text bed only** |
| **`GOLD_TEXT_GLASS`** | `#7A5520` | 5.9 / 5.4 / 4.6 | engraved caps and amber-ink labels on frost; active nav label |
| **`NAV_GOLD`** | `#7E6136` (was `#9A7A44`) | 5.1 / 4.6 / 3.95 | inactive nav glyph (non-text: needs ≥ 3.5 worst) |
| **`NAV_GOLD_ON`** | `#5A4220` (was `#6E5122`) | 8.4 / 7.6 / 6.5 | active nav glyph (≥ 7 typical) |
| `CTA_TEXT` | `#5A3212` | ~5 on amber | CTA label |

"Worst frost" is `#DDD5C6`, the darkest 5 % of the Settings frost sample. "Nav sky worst" is `#D9DCD8`, where all the values above stay within 0.3 of the worst-frost column. **Rule: every text pixel must reach ≥ 4.5:1 against the worst 5 % background sample of its own surface, and glyphs ≥ 3.5:1.**

### 1.4 Nav geometry

| token | v3 final | A | v2 |
|---|---|---|---|
| `NAV_H` | 100 | 100 | 120 |
| `NAV_RISE` | **10** (Play ring rises 10 px above the hairline, no more) | 14 | 28 |
| `TAB_BAR_H` | **110** (= NAV_H + NAV_RISE) | 114 | 148 |
| `NAV_GLYPH` | **48** box, stroke **2.0 px** (min `px(1.5)`) | 44 / 1.76 | 54-64 painted |
| `NAV_LABEL` | 22, Medium, +1 px tracking, both states | 22 Regular/Medium | 18-19 Bold |
| `NAV_PLAY_R` | **30** (60 px double ring) | 31 | 46 medallion |
| `NAV_SAG` | 5 (hairline arch: sides 5 px lower than the centre) | 0 | 14 |

### 1.5 Unchanged v2 tokens

These stay as they are: palette (PAPER_0..3, HAIRLINE, GOLD_HI, CTA_HI/CTA/CTA_LO/CTA_RIM, TOPAZ, gems, rarities), motion durations, `CHAMFER_L/CHAMFER/CHAMFER_S/CHAMFER_XS` (12/10/8/6, 45-degree), `MIN_TOUCH` 88, `GUTTER` 24, `TOP_BAR_H` 96, `RIBBON_Y` 104, `DOCK_H` 132.

---

## 2. Rendering primitives (from A; keep and extend)

- **`KitBox`** (`scripts/ui/kit/kit_box.gd`): every `UIKit.lux()` style is painted at device scale `s` and drawn through a 1/s transform. Rings are therefore exactly 1 dpx at 540, 720, 1080 and 1440.
  - Cache key prefix: `v3_`. Bump it to `v31_` so A's cached PNGs are repainted.
  - **Add C's `flourish` export and `_flourishes()`** (copy from worktree `wf_2ce040fe-e4e-5`, `crystal-rush/scripts/ui/kit/kit_box.gd` lines 17-19 and 34-80) with the parameters in §3.4.
  - Also take C's whole-pixel snap of the device rect (`(rect.position * s).round()` **before** subtracting the shadow), so the 1 px ring lands on a pixel row.
- **`UIKit.px(n)`**, **`UIKit.ui_scale()`**, **`GemDraw.pixel_y`**, and **`UIKit.line_px(n)`** (new, §1.1a).
- **Straight rules:** primitive lines (`width = -1` or `px(1)` without AA) on pixel-row centres, with per-vertex alpha fades in one `draw_polyline_colors` call.
- **Curves and diagonals:** `antialiased = true` at `line_px(1..1.5)`. If on-device QA (§14, D3) shows stepping on Mali or Adreno, bake the nav glyphs into device-scale textures. Use one `SubViewport` `UPDATE_ONCE` per (glyph, state, s) and cache it like KitBox. The API does not change.
- **No `msaa_2d`:** it has no effect in Compatibility (measured in tech.md).

---

## 3. Line system

### 3.1 Widths (dpx; canvas px at 720 are equal)

| element | width | colour |
|---|---|---|
| panel, card, plate, chip, button frame | 1 gold + 1 light inside | `LINE_GOLD`, `LINE_LIGHT` |
| dividers, list-row rules, tab rail | 1 | HAIRLINE @ 0.55, fading over the outer 22-25 % |
| nav hairline (engraved pair) | 1 gold + 1 light directly under it | `LINE_GOLD_DEEP` @ 0.85, white @ 0.62 |
| Play ring | inactive 1 outer + 1 inner; active 1.5 outer | §6.6 |
| active nav underline, active tab underline | 1.5 | `CTA_LO` `#D9822E` |
| selected card | 1.5 gold + diagonal flourish | `LINE_GOLD_DEEP` |
| CTA rim | 1 rim + 1 table light | `CTA_RIM` @ 0.7, `#FFFAE6` @ 0.9 |
| line icons (`KitIcons.line`) | `clamp(size*0.055, 1.3, 2.4)` px | ink / GOLD_HI / ON_SCENE |
| nav glyphs | 2.0 px (min `px(1.5)`) | `NAV_GOLD` / `NAV_GOLD_ON` |
| progress track | 1 hairline frame, 4 px glass track, amber fill | |

### 3.2 Where lines are used, and where never

**Used:**

- one frame per surface
- section dividers (with a diamond centre)
- list-row separators
- the tab rail
- the nav hairline
- the sheet top (a straight fading rule with a centre diamond; only the nav keeps an arch)

**Never:**

- dark outlines
- lines or outlines around text, or text emboss
- 1x textures stretched
- a second **gold** frame inside a frame (the inner line is always light)
- lines on the CTA body beyond its rim and table light
- borders on chips inside a card
- underlines anywhere except the active tab and active nav

### 3.3 Terminals and accents

| accent | spec |
|---|---|
| Diamond (`GemDraw.draw_diamond`) | 9-12 px cut gem: lit left facet, shaded right facet, 1 dpx edge. Used at the divider centre, the active nav hairline, a full progress bar's end and the sheet-top centre. **Replaces every crystal keystone.** `draw_keystone` keeps its signature and draws this diamond. |
| Marquise (`draw_marquise`) | 8-10 px long, width 0.2 of its length, flat gold. Used at rule ends. |
| Facet (B) | 7 px diamond. Used only at the two ends of the active underline. |
| Fades | rules fade to 0 over their outer 22-25 % |

### 3.4 Corner flourish (graft from C, restrained)

- **Where:** modals (`UIKit.modal`, `panel("modal")`, Settings, Vault, Odds, Profile, summon sheets) on **top corners** only, and the selected card on a **diagonal pair** (top-left and bottom-right).
- **Never on:** panels, chips, rows, plates, buttons, sheets or the nav.
- **Anatomy:**
  - a 1 dpx inner bracket that follows the chamfer, inset 6 px
  - arms 20 px (modal) or 12 px (card)
  - a curl of radius 2.6 px at each arm end
  - a 2.2 px lozenge on the cut, pointing inwards
  - colour `LINE_GOLD_DEEP` @ 0.8
  - drawn in device space (2 calls per corner)
- Skip the flourish when the box is smaller than 80 x 56 px.

---

## 4. Glass recipe

### 4.1 World still (`KitGlass.WorldSnap`; A's code with two changes)

1. **Resolution and blur:** set `DIV` to **10** (72 x 128 at 720) and the blur `spread` to **1.6**. That gives a stronger, lower-variance frost and fixes the "dirty window" blotches (all three judges).
2. **Figures stay out:** hero, Deck machines, dais, blob shadow and ring move to `SNAP_HIDDEN_LAYER` (layer 20). This is unchanged.

**Refresh:**

- at hub start
- when **arriving** at Play (A)
- **and** when leaving Play, before `disable_3d` (C)
- on biome or world change (`Світ N → N+1`)
- on hero or machine swap in the Deck
- on `NOTIFICATION_APPLICATION_RESUMED` (Android GL context loss)
- on window resize (already there)

**No flash on first frame:** when a cream tab opens before the still is ready, draw the backdrop flat for that frame and cross-fade the world in over 180 ms when `ready_once` turns true. Never pop from flat to frosted in one frame (UX must-fix 6).

### 4.2 Frost shader (`shaders/ui/ui_frost.gdshader`, v3.1: replaces A's file)

```glsl
// UI v3.1 porcelain frost (Godot 4.7, gl_compatibility). Material of a Control that paints an
// opaque porcelain body (KitBox nine-patch or a polygon). Each painted pixel is mixed with the
// PRE-BLURRED world still at SCREEN_UV. 1 bilinear tap per pixel, no screen copy, no pass break.
// Children keep their own material, so text and icons stay crisp.
shader_type canvas_item;

uniform sampler2D snap_tex : filter_linear, repeat_disable;
uniform float tint = 0.62;            // share of painted cream over the world (rim / margins)
uniform float frost_lift = 0.14;      // brighten the world (bright Genshin frost)
uniform float frost_desat = 0.45;     // calm its colours (was 0.25: blue/purple blobs)
uniform float frost_contrast = 0.55;  // compress luma variance toward frost_mid ("milk glass")
uniform float frost_mid = 0.80;       // the luma band centre the world is pulled toward
uniform vec4 warm : source_color = vec4(1.0, 0.976, 0.93, 1.0);
uniform vec4 page_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // optional: tint toward the page behind (§4.6)
uniform bool alpha_is_tint = false;   // nav strip: vertex alpha carries the tint ramp

void fragment() {
	vec4 p = COLOR;
	vec3 bg = texture(snap_tex, SCREEN_UV).rgb;
	float l = dot(bg, vec3(0.299, 0.587, 0.114));
	bg = mix(bg, vec3(l), frost_desat);
	bg = vec3(frost_mid) + (bg - vec3(frost_mid)) * frost_contrast;
	bg = bg * (1.0 - frost_lift) + frost_lift;
	bg *= warm.rgb * page_tint.rgb;
	float t = alpha_is_tint ? p.a : tint;
	// Where the strip is most transparent (low t) a little of the sharp scene also shows.
	float a = alpha_is_tint ? clamp(0.55 + t * 0.5, 0.0, 1.0) : p.a;
	COLOR = vec4(mix(bg, p.rgb, t), a);
}
```

`snap_blur.gdshader` is unchanged: a 7x7 gaussian run once per refresh.

`KitGlass.frost(tint)` caches one material per tint. Add `KitGlass.frost_nav()`, which returns a separate cached material with `alpha_is_tint = true`.

### 4.3 Three strengths, and the text-bed rule

| strength | surfaces | recipe |
|---|---|---|
| **Frosted** | nav strip, modals, Heroes sheet, Arsenal sheet, summon sheets | opaque porcelain body plus `frost(0.62)` (`frost_nav()` for the nav). **Body text never sits directly on it:** see the text bed below. |
| **Frosted backdrop** | Arsenal, Heroes, Barracks and Shop backdrops (3D off) | world still drawn full-screen plus `BACKDROP_VEIL` (§1.2); no spot, rays or vignette |
| **Flat translucent** | cards 0.84-0.88, plates 0.82-0.86, chips 0.82-0.86, buttons 0.84-0.86, ghost 0.08-0.16, wells 0.45-0.5, segmented track 0.32-0.36; text rows and toasts at `GLASS_TEXT_A` | KitBox `_glass()` specs, each with a 1 dpx gold edge and a 1 dpx light line |

**Text bed (graft of C's 93-99 % rule).** This applies to every frosted modal and sheet; it is must-fix 2 and 3 from all judges.

- `UIKit.frost_into()`, `frost_panel()`, `modal()` and `sheet()` insert, as the PanelContainer's **first child**, a `TextureRect` with `mouse_filter = IGNORE` drawing the new lux kind **`text_bed`**.
- `text_bed` is cream `PAPER_0` @ **0.94**, with no line and no shadow. Its edges are feathered over 28 px (painted with the spec blur and cached like any other KitBox).
- The bed fills the content rect (inside the panel padding). Frost therefore shows only in the rim band, the header margin above the first row and the corners.
- Heroes and Arsenal sheets: the bed covers the stat/row zone. The top 20 % of the sheet (above the first row) stays at the frost rim tint as a frost ramp.
- **Acceptance:** in the Settings modal, the 8-bit luma standard deviation of non-text pixels inside the text column is ≤ 4. The worst-5 % contrast of INK is ≥ 5.0:1 and of INK_DIM_GLASS ≥ 4.5:1.

### 4.4 Shadows

- **Knock out the shadow under the body** in `_paint` for every translucent kind (from B). A translucent panel never shows its own shadow through itself.
- Use one soft halo texture (`UIKit.glow_texture`) instead of stacked discs everywhere.

### 4.5 Coverage

| screen | backdrop | sheet / panel |
|---|---|---|
| Play | live 3D | nav frosted (`frost_nav`); plates and pills flat translucent |
| Arsenal | frosted backdrop | `_Stage` haze in `tab_arsenal.gd` alphas × 0.55; sheet frosted with a text bed under the card grid header and best-upgrade row |
| Heroes | frosted backdrop | `tab_heroes.gd` stage haze polygons (lines ~669-697) alphas × 0.55; sheet frosted, top 20 % ramp, stat rows on the bed |
| Shop, Barracks | frosted backdrop | rows flat at `GLASS_TEXT_A` |
| Modals (hub) | the page plus a 0.42 scrim | frosted + text bed + top-corner flourishes |
| Run HUD, results, menus outside the hub | no still | flat translucent; the flat `modal` is 0.97; same 1 dpx lines, weights, flourish and CTA (§9) |

### 4.6 Frost coherence (lower priority, P3)

When a modal opens over a cream tab, set the frost material's `page_tint` to the page's dominant colour mixed 25 % toward white. Example: the Shop vault purple `#8F6FD0` gives roughly `#E3DBF3`. On Play it stays white. This stops the modal reading as a fake window onto the sky.

---

## 5. Typography (one font: M PLUS Rounded 1c)

| role | size | weight | colour | notes |
|---|---|---|---|---|
| Big numbers (power, price ≥ 40) | 40-64 | ExtraBold | INK | the only ExtraBold |
| Screen title | 40 | Bold | INK | |
| Heading < 30 px, card title | 24-28 | Medium | INK | |
| Body / row label | 24-26 | Regular | INK | |
| Secondary text on glass | ≥ 22 | Medium | `INK_DIM_GLASS` | **22 px minimum on glass** (Barracks "Далі: +1", gem-card footers) |
| Section caps | 20-22 | Medium, +10 % tracking | `GOLD_TEXT` on the bed, `GOLD_TEXT_GLASS` on frost | |
| Nav label | 22 | Medium, +1 px | inactive `INK_DIM_GLASS`, active `GOLD_TEXT_GLASS` | no size or weight jump |
| CTA label | ≤ 38 | Bold, +8 % tracking when all caps | `CTA_TEXT` | no emboss, no outline |
| Secondary button | 24-26 | Medium | INK | |
| Text on 3D | v2 rule | Medium/Bold | ON_SCENE + `soft_shadow()` | unchanged |

`UIKit.font_w()` mapping (A's lighter scale): "bold" → Medium for titles under 30 px, headings keep Bold, and "extrabold" is used only for numbers ≥ 40. No outlines anywhere: the PrimaryButton theme outline is removed.

---

## 6. Bottom nav (the headline change)

### 6.1 Anatomy (720 canvas; control 720 x 110 + safe inset)

```
y  0      top of the Play ring (rises NAV_RISE = 10 above the hairline)
y 10      hairline apex (centre); sides at y 15 (NAV_SAG 5), fading out over the outer 22 %
          engraved pair: 1 dpx LINE_GOLD_DEEP @0.85 + 1 dpx white @0.62 directly below;
          the line is open ±3 px around the Play ring (the stone is set INTO the line)
y 10..110 frosted strip (frost_nav), tint ramp §6.3
y 20..68  glyph boxes 48 x 48 (centre y 44)
y 10..70  Play ring 60 px (centre y 40)
y 94      label baseline (22 Medium), 16 px above the strip bottom
y 102     active underline (1.5 dpx), 8 px under the baseline
slots     5 x 144 px; hit area = the full 144 x 110 slot (> 88)
```

### 6.2 The strip

- One frosted cream strip. Its **only line is the hairline**, which arches very gently: centre high, sides 5 px lower, fading out to both sides (C's arch, A's weight).
- No slab, no shadow, no keystone, no plate outline, no floating rounded plate.

### 6.3 Transparency on Play (must-fix 3)

The strip polygon is drawn with vertex alpha as the tint (`frost_nav`, `alpha_is_tint`):

| y | tint |
|---|---|
| hairline (y 10) | 0.40 |
| label cap height (y 70) | 0.80 |
| bottom (y 110) | 0.88 |

At the top edge the output alpha comes out ~0.75, so the map floor and its lines visibly ghost through the upper third. Labels sit on ≥ 0.80 tint.

**Fallback:** with no still, a flat cream gradient @ 0.84 → 0.92.

### 6.4 Active state (must-fix 1; owner, art-director and UX judges agree)

The active tab must win clearly at 540, at arm's length, in sunlight. Every element below is required:

1. **Underline (B):** 1.5 dpx `CTA_LO` rule, width = label width + 16 (clamped 56-120), 8 px under the baseline. It fades in from both ends and has 7 px amber facets at its ends.
2. **Hairline diamond (A):** 12 px topaz cut-gem diamond riding the hairline above the active slot, with a 52 px, 1.5 dpx amber glint fading out at both ends.
3. **Gold-leaf wash (C, softened):** a feathered elliptical glow (`glow_texture`) 120 x 80 in `#F1D99A` @ 0.32, plus a white core 56 x 40 @ 0.30, centred on the glyph. **No edge, no octagon, no tile.**
4. **Glyph:** `NAV_GOLD_ON` (≥ 7:1) with a 28 % `CTA_HI` duotone fill of its closed shapes.
5. **Label:** `GOLD_TEXT_GLASS` Medium, the same size and weight as inactive. The inactive label is `INK_DIM_GLASS` Medium (≥ 4.5:1 worst).

### 6.5 Glyph family (`KitIcons.nav`; the `tab_*` kinds keep aliasing it)

One monoline family, all with the same rules:

- 48 px box
- stroke 2.0 px (min `px(1.5)`, which also adds +0.25-0.5 dpx at s < 1)
- round joins and caps
- one silhouette each
- one small gem accent each
- no fills except the active duotone; no gradients, rims, shadows, multicolour or hatch strokes

| tab | glyph | change from A |
|---|---|---|
| Магазин | brilliant-cut gem: table, crown and pavilion facets | **drop the 4-ray "+" sparkle** |
| Арсенал | **field cannon**: barrel on a diagonal up-right with a muzzle ring and a breech knob; one wheel (circle plus 4 spokes) and a short trail line; the gem accent is a 6 px diamond on the barrel band | **replaces the crossed swords** (C's meaning, A's line; no engraving hatch) |
| Грати | the Play ring (§6.6); `nav("play")` stays the arch gate only where it is drawn small | |
| Герої | crested helm with a T-visor and a brow gem | unchanged |
| Казарми | swallow-tail banner with a diamond emblem and finial | unchanged. Swap to "keep with a pennant" in A's monoline only if the 5-second test (§14, D5) fails |

### 6.6 Грати (must-fix 4; resolves the judges' conflict)

The owner judge wants the topaz always lit. The art-director and UX judges want it not to look selected on every tab. Resolution:

- **Inactive** (another tab is active):
  - outline-only double ring with no disc fill: outer 1 dpx `LINE_GOLD_DEEP` @ 0.85, inner 1 dpx @ 0.40 at r − 3
  - a 1 dpx white arc on the upper left
  - the faceted topaz crystal (`KitIcons.topaz_crystal`, 32 px tall) stays **in full topaz hue at 85 % value, with no glow**: lit, but quiet; never grey or "disabled"
  - label `INK_DIM_GLASS`
- **Active:**
  - the ring warms to `#D29A45` at 1.5 dpx
  - the disc fills with frosted cream (`frost_nav` @ 0.85)
  - the crystal goes to 100 % with a soft inner glow
  - hairline diamond on top of the ring, underline under the label
  - label **`GOLD_TEXT_GLASS`** (amber ink, never slate-blue)
- **Rise:** at most 10 px above the hairline in both states. No medallion, no 1.22x pop, no breathing.

### 6.7 Badges, locked state, motion

- **Badge:** 9 px amber diamond (`#E3922C`) with a 1 px cream edge at the glyph's top-right. No glow, no pulse, no number.
- **Locked:** glyph and ring @ 36 %, label @ 50 %, a 16 px line lock at the glyph's lower right, no socket disc. Tapping it shows the v2 lock toast.
- **Motion:**
  - the underline, wash and diamond glide together, 180 ms cubic ease-out
  - the glyph colour cross-fades in 120 ms
  - press: wash flash @ 0.25 for 0.25 s, no scale
  - "Менше руху" (reduce motion): snap, no glide
  - redraw only while something moves (A already does this)

---

## 7. Components

### 7.1 Panels and modals

- Body: frosted (hub) or flat 0.97 (outside the hub).
- Frame: 1 dpx gold + 1 dpx light, chamfer 12.
- Top-corner flourishes (§3.4) and the text bed (§4.3).
- Title 40 Bold INK; close button = 1 dpx ring glass disc.
- Header divider: a fading 1 dpx rule with a diamond centre.

### 7.2 Sheets

- Frosted, with the top 20 % as a frost ramp and stat rows on the text bed.
- Sheet top: a straight fading rule with a 9 px centre diamond. No arch cap and no fill (B and C agree: only the nav arches).

### 7.3 Cards

- Flat glass 0.84-0.88, 1 dpx gold frame, one soft halo shadow.
- **Selected card:** 1.5 dpx `LINE_GOLD_DEEP` frame plus the diagonal flourish pair, with no extra glow slab.
- **Gem cards** (`kit_gem_card`): keep the rarity grounds and cuts, opaque for gem identity. Change to: 1 dpx frame, two faint shadow layers (not four), glass footer and pip bed at 0.86, footer text ≥ 22 Medium.

### 7.4 Plates, chips, pills, ribbon

- Flat translucent (§4.3), 1 dpx gold and 1 dpx light.
- Currency "+": a thin line plus sign, not a disc.
- World ribbon: a glass plate with marquise ends and Medium text.

### 7.5 Tabs, segmented control, progress

- Tabs: 1 dpx fading rail, 1.5 dpx `CTA_LO` active underline with facet ends, no keystone, label Medium.
- Segmented control: a track at 0.32-0.36 glass with a 1 dpx line; the selected segment is cream 0.92 with a 1 dpx gold line.
- Progress: 1 dpx frame, a 4 px glass track and an amber fill. No end ticks; a 9 px diamond lights at the end when full.

### 7.6 CTA: vector cut gem (graft from B; must-fix 4 of the art director)

Port B's `KitCTA._draw()` and helpers from worktree `wf_2ce040fe-e4e-4`, file `crystal-rush/scripts/ui/kit/kit_cta.gd`, lines 76-231. Keep A's no-emboss rule.

- **Body:** at most 96 px tall, centred in the touch rect; the hit area keeps the full rect.
- **Shape:** a chamfered polygon (`GemDraw.chamfer_rect`) with a cut of `clamp(h*0.3, 10, 26)`: an elongated cut gem, never a pill.
- **Fill:** flat amber in 3 stops, `#FFD98A` → `CTA #F5AE45` → `#E8963A`. Pressed: `#F9C76A` → `#EEA23E` → `#DC8A32`.
- **Lines:** 1 dpx table light `#FFFAE6` @ 0.9 under the top edge, and one 1 dpx `CTA_RIM` rim @ 0.7.
- **Shadow:** a soft warm glow quad `(0.6, 0.38, 0.15)` @ 0.18 (0.10 pressed). No brown drop.
- **Topaz:** a small **vector** cushion topaz (`GemDraw.draw_gem("cushion", …, TOPAZ, "#FFF0C2", "#C2620E")`) at the left end, `clamp(h*0.42, 24, 40)` px. **Do not use the painted `cta_topaz` texture or a bezel slab.**
- **Removed:** the specular streak and the sheen sweep. The sweep stays only as a single 0.16-strength pass on the first show of ГРАТИ.
- **Label:** Bold, all-caps tracked 8 % (`spacing_glyph = round(fs*0.08)`), capped at 38. The sub-line is Medium `#6E3A0F`.
- **Press:** scale 0.98 for 70 ms, return in 160 ms with no overshoot, flash glow on the topaz.
- **Disabled:** glass 0.88-0.9 with a 1 dpx hairline rim; label `INK_DIM`.
- **Applies to:** ГРАТИ, Покращити, Відкрити, every price button (the "250" coin button uses the coin icon in place of the topaz), and summon / Portal pull buttons.

### 7.7 Secondary, ghost and text buttons

- Secondary: glass 0.84-0.86, 1 dpx gold and light, Medium INK, no outline.
- Ghost: 0.08-0.16 glass with a 1 dpx line.
- Text button: no frame.

### 7.8 Settings toggles (art director must-fix 8)

`settings_panel.gd` `class Toggle`:

- **Track:** 56 x 28, chamfer 6, with a 1 dpx hairline.
- **Off:** glass @ 0.5 with a 1 dpx HAIRLINE @ 0.7.
- **On:** a thinner amber fill (`CTA` @ 0.92, inset 3 px from the hairline) and a 1 dpx `CTA_LO` line.
- **Knob:** a 22 px circle `#FFFDF8` with a 1 dpx `LINE_GOLD` edge and a soft shadow @ 0.12. Travel 120 ms ease-out.
- Hit area: the whole row (as in v2).

### 7.9 Edge buttons, sockets, avatar (top bar)

- **Edge buttons:** a glass disc @ 0.66-0.76, one 1 dpx ring, a 1 dpx rim-light arc and one halo shadow. "Ready" is a static 1.5 dpx amber ring; nothing pulses. Captions are 22 Medium on a glass chip.
- **Avatar:** a glass ring, a 2 dpx amber progress arc on a 1 dpx gold track, and the level on a chamfered glass plate with a 1 dpx `LINE_GOLD_DEEP` edge.

### 7.10 Run HUD, results and run modals (coverage, must-fix 6)

Outside the hub there is no still, so these stay flat. They must not mix v2 3 px bands with v3 hairlines.

- `run_hud.gd`, `hud_view.gd`: plates via lux (KitBox) with 1 dpx lines; the ult button gets a 1 dpx ring, a 4 px glass track, a 1.5 dpx bezel and a glow shadow, keeping its ready juice. Pause and the in-run modal use the flat `modal` at 0.97 with top-corner flourishes and the new CTA.
- `result_flow.gd`, `loss_screen.gd`: result bands get 1 dpx gold rules with diamond centres instead of keystones; reward cards use the §7.3 rules; CTAs use §7.6; text weights follow §5.
- `menu.gd`: the same kit and the same fallbacks.

### 7.11 Toasts and badges

- **Toasts:** flat glass at `GLASS_TEXT_A`, a 1 dpx gold line and Medium INK.
- **Notify badge:** an amber diamond (as in the nav), or a 28 px amber disc with a 1 dpx cream ring when it carries "!".

---

## 8. Icons (outside the nav)

- **Line icons:** stroke `clamp(s*0.055, 1.3, 2.4)`, with ink on cream, `GOLD_HI` on slate and `ON_SCENE` on 3D.
- **Painted objects stay painted and opaque:** coin, gem, crown, blueprint, gem cuts, topaz, hero art. Objects stay solid; containers become glass.
- The painted `tab_*` sticker family is retired from routing. `tab_*` aliases `nav()` everywhere (unlock cards, reward-fly targets, the Barracks title, Arsenal fallback thumbs).

---

## 9. What changes per screen

| screen / file | change |
|---|---|
| `hub.gd` | keep A's hook (`KitGlass.attach_world`, frosted backdrop, refresh on arriving at Play); **add** refresh on leaving Play, on biome change, on Deck swap and on app resume; backdrop veil per §1.2; scrim 0.42; cross-fade when the still becomes ready (§4.1) |
| `tab_play.gd` | none (the CTA and plates inherit) |
| `tab_arsenal.gd` | `_Stage` haze alphas × 0.55 so the frosted world shows; sheet frosted + text bed (A's `SHEET_FILL` stays for the fallback) |
| `tab_heroes.gd` | stage haze polygons (~669-697) alphas × 0.55; sheet frost + top 20 % ramp + bed; **merge with h3a-ui's +49 lines** (phase 3) |
| `tab_shop.gd`, `tab_barracks.gd` | rows at `GLASS_TEXT_A`; 22 px minimum secondary text (Barracks "Далі: +1", descriptions) |
| `settings_panel.gd` | `frost_into` (A) + slim Toggle (§7.8) |
| `vault_view.gd`, `odds_view.gd`, `profile_card.gd`, `machine_detail.gd`, `deck_editor.gd` | inherit via `panel("modal")` / `modal()`; check text sizes ≥ 22 on glass |
| `top_bar.gd`, `round_button.gd` | §7.9 |
| `run_hud.gd`, `hud_view.gd`, `result_flow.gd`, `loss_screen.gd`, `menu.gd` | §7.10 |
| `scripts/ui/heroes/**` (h3a-ui) | `hall/heroes_bottom_sheet.gd`, `showcase/manage_sheet.gd`, `team/team_roster_sheet.gd`, `hall/codex_sheet.gd` → frosted sheet + text bed; `widgets/engraved_bar.gd` → §7.5 progress; `widgets/gem_emblem.gd` stays opaque (object) with a 1 dpx rim; `hero_icons.gd` line strokes per §8; `champion/champion_parts.gd`, `recut/*` → the CTA from §7.6 and 1 dpx lines; ceremonies keep the 0.56 scrim |
| `scripts/ui/summon/**` (h3a-ui) | `summon_sheet.gd`, `focus_sheet.gd`, `history_sheet.gd`, `odds_sheet.gd` → frosted sheet + text bed + flourish (modal-type); `seal_shop.gd` → rows at `GLASS_TEXT_A`, price CTAs from §7.6; `portal_screen.gd` pull buttons → §7.6; `portal_ring.gd`, `portal_sky.gd`, `summon_fx.gd`, `summon_ceremony.gd` stay as art (no glass), only frames and text follow §3 and §5; `summon_summary.gd` → result rules (§7.10) |

Keep h3a's CI lint: a `StyleBoxFlat` corner radius > 8 px under `scripts/ui/heroes` or `scripts/ui/summon` fails.

---

## 10. What stays from UI v2

- **Palette:** cream PAPER_0..3, gold HAIRLINE `#C9A86A`, ink `#4B5669`, amber topaz CTA, gem colours and rarity names (Кварц / Сапфір / Аметист / Топаз / Опал).
- **Shape and type:** one font (M PLUS Rounded 1c), 45-degree chamfers (12/10/8/6), no pills.
- **Layout:** the portrait AFK-style layout (top bar 96, ribbon 104, five-tab bottom nav with Play in the centre, docks), touch minimum 88, safe-area insets.
- **Text on 3D:** ON_SCENE + `soft_shadow()`.
- **Objects:** painted currencies, gem cards with rarity grounds, hero portraits.
- **Ceremonies:** summon, recut and level-up keep their own art and their 0.56 scrim.
- **Copy and localisation:** every string key and all text.
- **APIs:** every public kit API (`lux` kinds, `KitNav.draw_arch_top/_arch_points/draw_bar/draw_medallion`, `HubTabBar` signals, methods and `anchor()`, `NAV_RISE`, `TAB_BAR_H`, `KitCTA` properties, `GemDraw` signatures).

---

## 11. Must-fix list (consolidated from the three judges; IDs used by the implementation workflow)

| ID | prio | fix | spec | acceptance |
|---|---|---|---|---|
| MF-1 | P0 | Active tab too weak | §6.4 | 540 shot: 5 of 5 viewers name the active tab in < 1 s; the active glyph is ≥ 7:1 typical |
| MF-2 | P0 | Play ring hierarchy and "always selected" | §6.6 | on Heroes, Arsenal and Shop at 540, the active tab outweighs Play; the ring is outline-only with no disc; the crystal is not grey |
| MF-3 | P0 | Dirty frost under text | §4.1 (DIV 10, spread 1.6), §4.2 (desat 0.45, contrast 0.55), §4.3 text bed | luma SD ≤ 4 in the Settings text column; INK ≥ 5.0:1, INK_DIM_GLASS ≥ 4.5:1 at the worst 5 % |
| MF-4 | P0 | Nav glass not visible on Play | §6.3 tint ramp | top third of the strip: map lines visibly ghost through (side-by-side zoom); labels ≥ 4.5:1 |
| MF-5 | P0 | CTA still a v2 toy | §7.6 | ГРАТИ, Покращити, Відкрити and 250 have no painted chip, streak or emboss; edges crisp at 1080 |
| MF-6 | P1 | Arsenal glyph meaning; Shop "+" | §6.5 | 5-second test: Arsenal is read as "cannons/machines"; the Shop gem has no sparkle |
| MF-7 | P1 | Contrast floor | §1.3 tokens | every text ≥ 4.5:1 and every glyph ≥ 3.5:1 on the worst sample (script in §14) |
| MF-8 | P1 | Transparency coverage | §4.5, §9 | Arsenal and Heroes visibly show the frosted world above and beside the sheet |
| MF-9 | P1 | Settings toggles heavy | §7.8 | |
| MF-10 | P1 | Run HUD, results and run modals mix v2 bands with v3 hairlines | §7.10 | 1080 zoom of the result band and the pause modal: 1 dpx lines |
| MF-11 | P1 | Glyph and line AA on device | §2 | 1080 and 1440 zooms show no stepping on diagonals; on-device check D3 |
| MF-12 | P1 | 540 thinness | §1.1a, §6.5 min stroke | 540 zoom: nav top line and modal edges ≥ 0.8 alpha |
| MF-13 | P2 | Modal dim and focus | §1.2 scrim 0.42 | mean luma of the page behind is ≥ 25 below the modal mean |
| MF-14 | P2 | Snapshot staleness and first frame | §4.1 refresh list + cross-fade | world 2→3, Deck swap and resume each show the right still; no flat→frost pop |
| MF-15 | P2 | Text ≥ 22 on glass | §5 | Barracks and gem-card footers |
| MF-16 | P3 | Frost coherence behind modals on cream tabs | §4.6 page_tint | |

---

## 12. Implementation plan (file by file)

**Work tree:** create a new branch `ui-v3` from `102dab8`, then rebase onto `124eccf`. Do not touch the main checkout until review passes. One commit per phase, with the attribution lines from the session reminder.

### Phase 1: design-system layer (every screen inherits)

1. **`scripts/ui/fx/ui_tokens.gd`:** the §1 tokens: `NAV_RISE` 10, `NAV_GLYPH` 48, `NAV_PLAY_R` 30, `NAV_SAG`, ink tokens, `GLASS_TEXT_A`, `FROST_RIM_TINT`, `NAV_TINT_*`, `BACKDROP_VEIL`, `SCRIM_MODAL`, `LINE_GOLD_DEEP`.
2. **`shaders/ui/ui_frost.gdshader`:** §4.2 verbatim.
3. **`scripts/ui/kit/kit_glass.gd`:** `DIV` 10, blur spread 1.6, `frost_nav()`, `page_tint` setter, `ready` signal for the cross-fade, and the resume hook (`NOTIFICATION_APPLICATION_RESUMED` → `refresh_world`).
4. **`scripts/ui/kit/kit_box.gd`:** C's `flourish` + `_flourishes()` (§3.4) and C's whole-pixel snap.
5. **`scripts/ui/ui_kit.gd`:**
   - `line_px()` and the `text_bed` lux kind
   - `frost_into/frost_panel/modal/sheet` insert the bed and use `FROST_RIM_TINT`; `modal` kinds get top flourishes
   - the shadow knock-out in `_paint` for translucent kinds (B)
   - secondary text helpers default to `INK_DIM_GLASS` on glass
   - cache prefix `v31_`
6. **`scripts/ui/kit/kit_cta.gd`:** port B's vector cut gem (§7.6) onto A's file, keeping A's `SlimBox` hit-area logic. Use the vector topaz.
7. **`scripts/ui/kit/kit_icons.gd`:** nav family at 48 / 2.0, the new Arsenal cannon, the Shop gem without the sparkle, `topaz_crystal` quiet and lit states.
8. **`scripts/ui/kit/kit_nav.gd`:**
   - `Strip` with the vertex-alpha tint ramp and `frost_nav`
   - `draw_top_line` with `NAV_SAG` arch and fade
   - `draw_play_ring(on: float)` per §6.6
   - new `draw_indicator(c, w, k)` (B's underline + A's diamond + the leaf wash)
9. **`scripts/ui/hub/tab_bar.gd`:** layout §6.1, active state §6.4, label colours, motion §6.7.
10. **`scripts/ui/kit/gem_draw.gd`, `kit_tabs.gd`, `kit_progress.gd`, `kit_gem_card.gd`, `kit_socket.gd`, `kit_title_plate.gd`, `kit_currency_plate.gd`, `kit_sheet.gd`, `round_button.gd`, `hub/top_bar.gd`:** §3, §7.3-§7.9.

**Gate 1:** gallery shots at 720 for Play, Arsenal, Heroes, Shop and Settings, plus the specimens. Draw calls are ≤ A's numbers + 5 % (§13).

### Phase 2: hub screens

- `hub.gd`, `settings_panel.gd`, `tab_arsenal.gd`, `tab_heroes.gd` (main's version), `tab_shop.gd`, `tab_barracks.gd`, `vault_view.gd`, `odds_view.gd`, `profile_card.gd`, `machine_detail.gd`, `deck_editor.gd` (§9).
- Then `run_hud.gd`, `hud_view.gd`, `result_flow.gd`, `loss_screen.gd`, `menu.gd` (§7.10).

**Gate 2:** the full acceptance set (§14) at 720, 540 and 1080.

### Phase 3: Heroes and Summon screens (after h3a-ui lands in main)

- If h3a-ui has merged: rebase `ui-v3` and apply the §9 heroes and summon rows.
- If it has not: put the touch-ups on a branch from the `h3a-ui` tip merged with `ui-v3`. **Never edit the `h3a-ui` worktree** (another workflow owns it).
- Resolve the `tab_heroes.gd` conflict by keeping h3a's routing and applying the haze, sheet and bed changes.
- Run `test_heroes_ui.gd` and h3a's gallery shots: `portal_odds`, `portal_seals`, hall, showcase, team, recut and codex.

### Phase 4: device QA (§14 D1-D5) and owner shots

---

## 13. Performance budget (gl_compatibility, Android low/mid; reference device Mali-G52 class at 1080 x 2400)

| item | budget | A measured (llvmpipe) |
|---|---|---|
| Draw calls, Play | ≤ 610 (A 580 + 5 %; v2 748) | 580 |
| Draw calls, Arsenal / Heroes / Shop / Settings | ≤ 340 / 485 / 315 / 675 | 322 / 462 / 299 / 641 |
| Canvas + 3D objects | ≤ 1/2 of v2 on every tab | ~1/3 |
| Screen copies (`BackBufferCopy`, `hint_screen_texture`) | **0** | 0 |
| Per-frame 3D passes added by glass | **0** (the still is `UPDATE_ONCE`) | 0 |
| Still refresh | ≤ 1 x (1/100-pixel 3D render + 7x7 blur at 72x128), only on the triggers in §4.1 | 1/64 at DIV 8 |
| Full-screen blended layers on a cream tab with a modal open | ≤ 3 (backdrop still, veil, frosted modal) | 3 |
| GPU frame time on the reference device | ≤ 12 ms on Shop + Settings modal, ≤ 16.6 ms on Play | to measure (D1) |
| First-launch KitBox paint at s = 2.0, cold cache | ≤ 250 ms total hub build increase | to measure (D2) |
| Nav redraws | only while the indicator glides or a flash plays | yes |

**New-cost notes:**

- The flourishes add 2 canvas calls per corner, on modals and the selected card only (~4-8 calls per screen).
- The text bed adds 1 textured quad per frosted modal or sheet.
- The CTA polygon replaces a nine-patch, bezel and emboss (net fewer calls; B measured −27-34 % with it).

**Measurement:** llvmpipe frame times are noise (ratios 0.87-1.25 both ways). Gate on **draw calls and object counts** (deterministic), and gate frame time on the device only. Probe: `uiv3/dir_A-porcelain-glass/tools/v3_perf.gd`, run in interleaved before/after rounds.

---

## 14. Acceptance

### 14.1 Shots (gallery account level 14, expected profile)

Write all shots under `uiv3/final/`. At each resolution a shot passes only if nothing overlaps or clips, and the nav, CTA and flourish lines are 1 dpx (1.25 at 540).

| resolution | shots |
|---|---|
| 720 x 1280 | `hub_{play,arsenal,heroes,shop,barracks,settings}_720`, `vault_720`, `odds_720`, `deck_720`, `detail_720`, `profile_720`, `run_hud_720`, `pause_720`, `result_win_720`, `result_loss_720`, `specimen_{base,widgets,icons,cards,hud,home}_720` |
| 540 x 1200 | `hub_{play,heroes,shop,settings}_540`, `nav540_{play,heroes}` (x3 nearest zoom) |
| 1080 x 1920 | `hub_{play,heroes,settings}_1080`, `cta_1080_zoom_x3`, `modal_corner_1080_zoom_x3`, `nav_1080_zoom_x3`, `result_band_1080_zoom_x3` |
| 1440 x 2560 | `hub_play_1440`, `nav_1440_zoom_x2` |
| h3a screens (phase 3) | `heroes_hall`, `hero_showcase`, `manage_sheet`, `team`, `recut`, `codex`, `portal`, `portal_odds`, `portal_seals`, `summon_summary` at 720 and 540 |
| boards | `final/board.png` (v2 vs v3 final per tab, with nav zooms) and an updated `owner_board.png` row "Фінал" |

### 14.2 Measurements (scripted, PIL)

- **Contrast:** for each text and glyph crop, the background is the median and the worst 5 % of non-ink pixels. Text must reach ≥ 4.5:1 (MF-7). Report a table per surface.
- **Frost evenness:** luma standard deviation in the Settings text column must be ≤ 4 (MF-3).
- **Line width:** sample columns across the nav hairline, the modal edge and the CTA rim at 1080 and 1440. The gold run must be 1 px (1.5 dpx lines up to 2 px), with peak alpha ≥ 0.8.
- **Active tab:** a crop of each nav state at 540, placed side by side in `final/nav_states_540.png`.

### 14.3 Device and human checks (phase 4)

| ID | check |
|---|---|
| D1 | GPU frame time on Mali-G52 class: Play, Shop with the Settings modal, Heroes |
| D2 | Cold-cache hub build at s = 2.0 |
| D3 | AA of glyph diagonals and arcs on Mali and Adreno at 1080 and 1440; if stepped, bake the glyphs (§2) |
| D4 | onPause/onResume: the still is restored with no black or stale frost |
| D5 | 5-second icon test with 3+ people: Магазин, Арсенал (cannon), Грати, Герої, Казарми |

---

## 15. Sources

| what | where |
|---|---|
| Winner spec, shots, perf | `uiv3/dir_A-porcelain-glass/` (`spec.md`, `board.png`, `perf.txt`, `extra/`, `after1080/`) |
| Donor code | B: `.claude/worktrees/wf_2ce040fe-e4e-4` (`kit_cta.gd`, `kit_nav.gd draw_indicator`, `ui_kit.gd _paint` knock-out); C: `.claude/worktrees/wf_2ce040fe-e4e-5` (`kit_box.gd` flourish, `kit_icons.gd nav_arsenal` for the cannon's proportions, `hub.gd` backdrop) |
| Judge crops | `uiv3/judge_owner/`, `uiv3/judge_ux/` |
| Tech background | `uiv3/tech.md` (glass options, hairline lab), `uiv3/audit.md`, `uiv3/references.md` |
| Contract base | `uiv2/ui_v2_contract.md`; owner decisions `crystal-rush/docs/design/ui_decisions.md`, `fusion_genshin_afkj.md` |
| Owner board | `uiv3/owner_board.png` (script `uiv3/synth/owner_board.py`) |
