# Crystal Rush UI direction: Genshin Impact × AFK Journey fusion

Owner's brief: *"In Genshin everything looks very beautiful. In AFK Journey too. Combine them."* This document takes the
binding owner answers in `uiref/fusion/OWNER_DECISIONS.md` as given. It also respects the frozen game rules: the gem
ladder, facets (Грані) instead of stars, the Portal ceremony rules and the run-palette rule (`heroes/framework.md` §0.1,
§1.2; `heroes/research_presentation.md` §1–2).

## 0. Коротко (відповідь власнику: «що скажеш про цей напрям?»)

**Напрям правильний, і я за нього.** Genshin і AFK Journey дотримуються тих самих правил, яких бракувало нашим
прототипам. Велике мальоване чи відрендерене мистецтво займає екран, а «хром» (рамки й плашки) майже невидимий.
Рідкість передається кольором, а не орнаментом. Кремові панелі мають одну тонку золоту лінію замість десятка рамок.
AFK Journey до того ж портретна гра, тобто готовий шаблон розкладки під наш 720×1280.

Ризиків два. Перший: стати «клоном Genshin». Його знімає наша власна мова, а саме ограновані кути панелей, мотив мосту,
самоцвіти з огранками замість зірок і бурштинова кнопка з кристалом (§6.10). Другий: обсяг роботи. Цей стиль тримається
лише на **намальованих бітмапах** (9-slice панелі, кнопки, рамки) і мальованих героях, тож код малює тільки розкладку.

Моя рекомендація:
- **Варіант C, світлий**: кремові панелі у світлих теплих меню, світлі «порцелянові» плашки в забігу, космос лише як
  один зі світів.
- **Шрифт M PLUS Rounded 1c**. Він найближчий до шрифту Genshin, а і ї є ґ ’ я перевірив.
- **Бурштинова ключова кнопка** з топазом.
- **Картка героя**: мальований портрет на градієнті кольору самоцвіту.

Наступний крок: згенерувати 3 концепт-екрани з §7 у Gemini. Будувати починаємо тільки після того, як власник побачить
ціль.

## Files produced (all under `scratchpad/uiref/fusion/`)

| File | What |
|---|---|
| `board_genshin.png` | 41 Genshin screens grouped by section, captioned (1600 wide) |
| `board_afkj.png` | 35 AFK Journey screens + 15 AFK Arena screens (1600 wide) |
| `board_closeups.png` | 30 tight crops, codes **G01–G14, J01–J13, A01–A03** (used as "Close Gxx" below) |
| `moodboard_fusion.png` | portrait 1200×2400 moodboard: 16 reference crops plus Vesta (17 tiles), the proposed palette, the 5-gem card sketch and a type sample |
| `palette_samples.png`, `palettes.json` | 50 sampled swatches (named region → dominant k-means cluster / ink percentile) + 8-colour palettes of 12 whole screens |
| `type_specimen.png` | 8 rounded Cyrillic faces against the Genshin type, with the Ukrainian glyph test |
| `_work/*.py` | scripts that rebuild everything (`board_*.py`, `moodboard.py`, `palette.py`, `palette_board.py`, `specimen.py`); `_work/fonts/` holds the downloaded OFL fonts |

Close-up index (board order):

| Code | Source | Shows |
|---|---|---|
| G01 | Genshin 03 | text tabs with a diamond bullet, active = larger + hollow diamond |
| G02 | Genshin 03 | stat rows without boxes, hollow ascension stars, hairline XP bar |
| G03 | Genshin 27 | pack tile: painted crystals, bonus rosette, cream price footer |
| G04 | Genshin 10 | detail card: rarity header band over a cream body |
| G05 | Genshin 37 | corner-bracket frame around a media window |
| G06 | Genshin 22 | 5★ reveal: hero bursting out of shattered crystal |
| G07 | Genshin 10 | rarity item cards: gradient ground, curved corner, stars, cream level strip, NEW tag |
| G08 | Genshin 23 | ×10 bookmark cards in rarity colour |
| G09 | Genshin 21 | element emblem + name + star row lock-up |
| G10 | Genshin 14 | rate rows tinted gold / violet |
| G11 | Genshin 14 | parchment modal: gold frame, corner flourish, ochre close, pill tabs |
| G12 | Genshin 09 | primary pill: dark ring icon + cream body |
| G13 | Genshin 38 | "Obtained" title + hairline divider with diamond terminals |
| G14 | Genshin 12 | currency capsules |
| J01 | AFKJ 18 | ×10: duplicates fold into cream cards, NEW heroes break the grid |
| J02 | AFKJ 07 | ascension: crystal pair, Elite+ » Epic, cream stat table, orange CTA |
| J03 | AFKJ 20 | faction ribbons with emblem medallions |
| J04 | AFKJ 15 | recruit block: banner title, guarantee line, Recruit 1 / 10 |
| J05 | AFKJ 05 | rarity crystal in a hairline cage, italic name, 4 badges |
| J06 | AFKJ 04 | roster cards: painted busts, level ribbon, faction badge |
| J07 | AFKJ 34 | choice cards: tinted icon wedge + cream body |
| J08 | AFKJ 19 | new-hero ribbon: drop-cap name, quote, role chips |
| J09 | AFKJ 05 | giant italic level numerals + power plate |
| J10 | AFKJ 04 | drop-cap title |
| J11 | AFKJ 03 | bottom nav, active tab raised on a medallion |
| J12 | AFKJ 06 | gold hexagon skill icons with rank |
| J13 | AFKJ 05 | dock: white back tab + big CTA with cost chips |
| A01 | AFKA 05 | gem medallion + stars + rank pips + name |
| A02 | AFKA 04 | rarity = frame colour + star row |
| A03 | AFKA 07 | gold pill CTAs with cost |

---

## 1. Binding inputs (what this fusion must obey)

From `OWNER_DECISIONS.md`:
- **Take from Genshin:**
  - light cream panels with gold lines;
  - the character screen: hero on a soft element-coloured stage, attribute tabs, constellation/talents;
  - rarity cards: gradient ground, clean element icons, star marks.
- **Do not take** Genshin's wish ceremony. We keep our own Portal ceremony.
- **Take from AFK Journey:**
  - painted hero portraits;
  - the storybook look: parchment, painted frames and ornaments;
  - the warm fairy-tale palette.
- **Do not take** AFK Journey's world-as-menu map.
- **Brightness:** menus are light and warm, and the run HUD is light too (no heavy dark glass). The dark cosmic world is
  only one of the levels.
- **Home:** the hero stands in a live 3D scene, large, on a pedestal at the start of the bridge in warm light, with
  machines nearby, few buttons and a big precious "Play".
- **Typography:** ONE soft, rounded, friendly font in the Genshin manner for everything, with titles just heavier. No
  storybook serif.
- **Navigation:** an AFK Journey-style bottom bar. It is light, has painted icons with labels, and the active tab rises.
- **Buttons:**
  - ordinary actions: cream with a thin gold edge;
  - key actions (Грати, Призвати, Покращити): warm gold-amber with a crystal, richly rendered as a bitmap.
- **Hero card:**
  - painted splash portrait on a gem-colour gradient;
  - thin gold frame;
  - gem emblem at the top;
  - class + element;
  - name + level at the bottom.

From the frozen system docs:
- **Rarity:**
  - The five tiers and their colour-blind cuts are Кварц (round), Сапфір (square), Аметист (triangle), Топаз (star) and
    Опал (eye).
  - The UI hexes are `#D6DEE6`, `#3FA9FF`, `#B06CFF` (body `#7A35D6`), `#FFB52E`, and black opal `#1A1530` with
    hue-cycle.
  - The tier is redundantly coded by cut, setting metal, background fracture pattern, the engraved name and lightness
    (framework §1.2).
- **Facets (Грані)** are 0–5 per gem and use **rhombus pips, not stars**. ★ stays reserved for star-shards.
- **Portal:** the result is rolled and SAVED first. At +0.6 s all seeds light in their final gem colour, with no suspense
  ladder. Amethyst+ items get walkouts with the identity beats Class → Element → Faction → Name. Ceremonies are always
  skippable. The Portal never links to the Shop.
- **Run palette rule:** gem hues never mark heroes or champions in the run.
- **Notifications:** a gold "!" badge, never red dots with numbers (arsenal §7.4).

---

## 2. Genshin Impact: the UI system

The sources are landscape 16:9 captures (`board_genshin.png`). Pixel numbers below are at 1920×1080.

### 2.1 Panel types: where cream and where dark

| Panel | Material | Used for | Evidence |
|---|---|---|---|
| **Cream / parchment card** | warm off-white `#F9F4EB`–`#ECE5D9`, faint paper grain, 1–2 px gold frame `#CEB283`, small corner flourishes | anything you *read* as a document: banner cards, rates/details modal, item detail body, shop tiles, battle-pass columns, tutorial text | 12, 14 (G11, G10), 10 (G04), 25–28 |
| **Cream pill** | the same cream, fully rounded | every ordinary button, sort/filter dropdowns, segmented tabs | 03, 08, 09 (G12), 39, 40 |
| **Dark translucent slab** | navy/slate `#242E3E`–`#515A6B` at 70–90% with a blurred world behind it | lists and grids that sit over the live world: Paimon menu tiles, quest list, tutorial list, settings rows, talent detail | 01 (slate tiles `#515A6B`), 07, 32, 37, 40 |
| **No panel at all** | text and icons directly over art with a soft shadow | character stats, tabs, dialogue, rewards "Obtained", level-up | 03 (G01, G02), 33, 38 (G13) |
| **Full-width band** | one saturated band across a dimmed screen | level-up (blue `#0A68A8`), "Challenge Completed" (gold) | 09, 41 |

The rule underneath is simple. **Cream = a document you hold. Dark glass = a list floating over the world. Nothing = the
hero's own space.** The character screen has no panels at all.

### 2.2 Ornament line language

- **One line, two terminals.** Dividers are 1–2 px gold hairlines `#CCB68A` that end in a small hollow diamond with a short
  curl, often with a 4-point sparkle ✦ above the midpoint (G13, the 08 dividers at y 240 / 930, G04 header band ends).
- **Frames are double hairlines** with a 4–6 px gap. The inner one is thinner. Notched corners hold a small flourish (G11).
- **Background filigree:** large, very faint (3–6% alpha) circular astrolabe/compass patterns under banners and modals
  (12, 14).
- **The sparkle ✦ is Genshin's signature mark.** It shows up as the active-tab marker, next to titles, at the end of
  pills and in rarity glitter (G01, G13, 26). **We must not copy it** (§6.10).

### 2.3 Corner treatments

- Pills: fully rounded (radius = h/2).
- Cards: 6–10 px radius. On item cards **the coloured field has a large rounded bottom-right corner (r≈40 px)** that
  reveals the cream level strip beneath (G07). This is the most recognisable Genshin card silhouette.
- Modals: square with a notched or chamfered gold corner and a flourish (G11).
- ×10 result cards: a tall **bookmark** with an arched, notched top and a pointed bottom (G08).
- The media window has cyan **corner brackets** instead of a full frame (G05).

### 2.4 Buttons

| Role | Look | Size (1080p) |
|---|---|---|
| Primary | cream pill + a **dark circular icon socket on the left** (a yellow ring "O", or an X for cancel) + slate label (G12) | 330–480 × 60–80 |
| Secondary | the same cream pill without the socket, or a "ghost" outline pill at 40% (39) | 220 × 56 |
| Close | 72 px cream disc with a dark X, top-right, 60 px margin; on parchment it is an ochre tab `#B38345` hooked on the frame (G11) | 72 |
| Currency | dark translucent capsule: icon, value, "+" disc (G14) | 190 × 50 |
| Tabs | text only + diamond bullet; active = 48 px vs 38 px, hollow diamond, with a sparkle at the rail (G01) | pitch 87 px |

Genshin keeps buttons quiet. Only colour (a yellow ring) and position (bottom-right) mark the primary action.

### 2.5 Rarity cards and star marks

- **Card ground = rarity colour** as a soft vertical gradient with faint filigree:
  - 1★ grey `#77787B`
  - 2★ green `#4C7B6B`
  - 3★ blue `#517B9A`
  - 4★ violet `#8C79B8`
  - 5★ ochre-gold `#AC794C`

  These are muted, mid-value colours (sampled). They never shout, so the art on top reads first.
- A **cream footer strip** `#EEE8DD` (≈20% of card height) holds "Lv. 9" or a count. A yellow **NEW** tag `#EFB439` sits
  hooked on the top-right corner (G07).
- **Stars** are filled 5-point stars `#F6C433` with a thin warm outline, centred on the seam between art and strip.
  Ascension uses **hollow** star outlines that fill in (G02).
- The same colours return everywhere: banner rate bands (gold `#CEB283`, violet `#B5A8C9`, G10), meteor colour,
  silhouette backgrounds (`#2D2740` violet, `#F2A049` gold), ×10 cards (G08), shop tiles (26). **Rarity is a colour
  system, not an ornament.**

### 2.6 Element icons

Each element is a single bold glyph (flame, droplet, swirl, geo diamond, snowflake, leaf, lightning):
- a flat 2-tone fill in the element's colour with a thin dark outline and a soft outer glow (G09 Geo, G06 Cryo);
- 64–110 px on reveal screens, 24–32 px inline;
- the same glyph is the top-left breadcrumb badge on the character screen (03–06).

The element also **tints the whole stage**: the character screen nebula is Anemo teal `#309E9B`, Geo ochre `#B79A48`,
Hydro blue (03, 04, 06). That is one chromatic signal at screen scale instead of a dozen small ones.

### 2.7 Typography

- The game face is **HYWenHei 85W** (汉仪文黑). It is a rounded-terminal humanist sans with high x-height, soft corners and
  mild warmth, used for Latin and Cyrillic alike. It is commercial, so we cannot ship it.
- One family does everything. Hierarchy comes from size and colour:
  - gold `#CCB68A` breadcrumbs ("Anemo / interface");
  - white names at 40–48 px;
  - slate ink `#4B5669` on cream;
  - element-coloured keywords inside body text (07, 37).
- Banner titles add **one coloured accent word** ("When **Warm** Winds Cavort", 13; "Event Wish 'Viridescent **Vigil**'",
  G11).
- Sizes at 1080p: body 26 px, labels 28–30, tabs 38/48 (active), headline numerals 62 px (G04 "62"), level-up "Lv. 10"
  ≈ 70 px.

Cyrillic-capable Google Fonts lookalikes. All were downloaded and the glyphs checked with fontTools; see
`type_specimen.png`. The test string is і ї є ґ І Ї Є Ґ ’ ʼ « » — №.

| Font | Ukrainian test | Verdict |
|---|---|---|
| **M PLUS Rounded 1c** (OFL; Thin…Black, 7 static weights) | **all present** | **closest to HYWenHei**: the same Asian "rounded gothic" genre, humanist proportions, tabular digits by default (all 650 u) |
| **Nunito** (OFL; variable wght 200–1000) | all present | rounder and more bubbly; the best fallback; 1 variable file 277 KB; tabular digits |
| Rubik (in the repo today) | all present | only slightly rounded; reads geometric/techy, not "Genshin-soft" |
| Ysabeau Infant | all present | elegant, but too calligraphic and narrow for buttons |
| Comfortaa | all present | too geometric and thin; Cyrillic forms look odd (т, д) |
| Balsamiq Sans | missing № | too handwritten |
| Murecho | missing ʼ U+02BC | close in feel, but fails the apostrophe |
| Zen Maru Gothic | **missing і ї є ґ** | fails (Russian-only Cyrillic) |
| Kosugi Maru | **missing і ї є ґ « » —** | fails |
| Varela Round, Fredoka, Quicksand | no Cyrillic subset at all | fail |

### 2.8 Spacing and density

Measured at 1080p on 03 / 10:

| Element | Measurement |
|---|---|
| Edge margins | 60–155 px (5.5–8% of the short side) |
| Tab list | starts at x 220; pitch 87 px (8% H) |
| Stat rows | pitch 45 px (4.2% H); no separators, value right-aligned |
| Right info column | 415 px wide (22% W) |
| Inventory cards | 155×190; gap 28 |
| Detail card | 615 wide; header band 70 tall |

The character screen leaves about **55% of the screen to the hero** and puts no element in the middle third.

Density is low: about 12–18 interactive elements per screen versus 25–30 on our rejected prototypes. Genshin's mobile
targets are small (a 60 px pill is about 20 dp). For touch sizes we follow AFK Journey (§3.1) instead.

### 2.9 Motion cues

These are described from the captures and general play knowledge; re-check them against a screen recording before
tuning.
- Panels **slide 40–80 px from their anchor edge with a fade** (≈0.25 s, ease-out). The Paimon menu slides from the left
  while the world blurs.
- Item cards **pop in staggered** (≈40 ms each) with a small scale overshoot. NEW tags and rarity glitter sparkle on a
  loop.
- Level-up and "Challenge Completed" bands **wipe horizontally**. The numeral counts up, and green arrows bounce once (09,
  41).
- Tabs cross-fade the content and slide the bullet. The stage tint cross-fades when the element changes.
- Idle: slow drifting motes over the nebula, and a breathing glow on the ready burst button (36).

### 2.10 The wish ceremony (for knowledge only; the owner kept our Portal)

There are four beats, each reading rarity before identity:
1. **Meteor:** a shooting star over a sea of clouds. Its colour is the best rarity in the batch: blue, violet, or
   gold-white with a **rainbow ring halo** for 5★ (15–17).
2. **Silhouette:** a black hero silhouette on a rarity-coloured burst with triangular shards (18, 19).
3. **Splash:** the painted gacha splash, not the 3D model, over gold shards or a **shattered crystal** (G06). The element
   emblem, name and stars fly in at the left (G09). 3★ weapons sit on a white torn-paper burst with a duplicate ribbon
   (20).
4. **×10 summary:** bookmark cards sorted by rarity (G08, 24). Even a bad pull looks clean.

What our Portal already shares is beat 1's honesty (the portal column takes the best gem colour at +0.6 s) and beat 3's
material (crystal shatter → step-out). What we must *not* copy is the sky-over-clouds meteor, the silhouette beat and the
bookmark card shape.

### 2.11 The character screen (03–07)

- A **3D model stands full-height at centre** on an element-tinted nebula.
- **Left:** a plain text tab list (Attributes · Weapons · Artifacts · Constellation · Talents · Profile) beside a narrow
  party-avatar rail.
- **Right column:** name, 6 hollow ascension stars, "Level 6 / 20" with a hairline XP bar, 5 stat rows with no boxes, a
  ghost "Details" pill, lore text, and a cream "Level Up" pill bottom-right.
- **Constellation** turns the duplicate track into a **star chart** drawn over the nebula, with 6 locked round nodes on
  an arc (05).
- **Talents:** 6 monoline glyph discs on an arc (06).
- Every tab keeps the hero visible and only swaps the information column.

---

## 3. AFK Journey (and AFK Arena): the system

AFK Journey runs in portrait on phones (`board_afkj.png`). Pixel numbers below are at the capture's width, scaled to
720 where noted.

### 3.1 Storybook / painterly treatment

- **The world is a painting.** Even 3D scenes have a gouache look: soft cel shading, hand-painted textures, warm bounce
  light. Menus are painted dioramas (02 Mystical House, 04 Resonating Hall). Hero screens sit on painted landscapes with
  a real sky (05 Lucius on a sunny meadow, 07 on a dusk field), not on abstract gradients.
- **Paper everywhere:**
  - warm off-white paper `#F6F1EB` / `#E5DFD3` with a faint fibre texture;
  - torn or brush-edged paper strips ("BATTLE OVER" on orange paper, 27);
  - ribbons with diagonal swallow-tail ends (30, J08).
- **The corner language is asymmetric:**
  - panels and buttons have **one large rounded corner (bottom-right, r≈24 at 768 w) and small or square others**: the
    back tab, the Level Up slab, relic cards, wishlist rows (J13, J07, J03);
  - big CTAs carry a faint diamond/star pattern in one corner (J13, J04).
- **Stained glass and arches** carry ceremony screens: the class upgrade rose window (11), class gear (10), arena gothic
  arches (33), the arched talent window (09).

### 3.2 Frames

- Portrait cards: a thin light inner border, a rounded rectangle, and a **coloured ground behind a painted bust**
  (gold-orange for S-level, violet for A-level, J06). A level ribbon with italic numerals sits on the bottom edge and a
  small faction badge in the bottom-left corner.
- Hero rarity: a **cut crystal inside a hairline "cage"** (an elongated hexagon of white lines with radial hatching), with
  the tier label underneath (J05: "Legendary+"). This is very close to our Living Gem.
- Ascension shows **two crystals side by side, "Elite+ » Epic"** (J02).
- ×10 results: duplicates collapse into **plain cream cards** (acorn icon + "x4"), and **NEW heroes break the grid**:
  taller, gold or violet frame, "New" ribbon (J01). That is honest and readable.

### 3.3 Warm palette (sampled, §4)

- Paper `#F6F1EB` / `#E5DFD3`, warm taupe ink `#8F8280` (labels) on cream.
- The CTA pair is **green `#669C5E`** (normal) and **orange `#E5963A`** (premium / 10×).
- The nav bar is mauve-brown `#6C5C5D`; the drop-cap block is green `#609656`.
- Crystals: Elite violet `#8B3CB4`, Epic orange `#E7A54B`, Legendary red `#CC4845`.
- Factions:
  - Lightbearer `#485A90`
  - Mauler `#49251E`
  - Wilder `#275D5D`
  - Graveborn `#35414E`
- Skies are saturated `#2782C7` with soft clouds.

### 3.4 Hero art usage

- **Hero detail = full-height figure on a painted landscape** (05). The UI hugs the corners:
  - crystal + name top-left;
  - giant italic "Level 191" plus a power plate bottom-right (J09);
  - a dock at the bottom (J13).
- Painted busts on every roster card (J06), wishlist row (J03) and shop shard (22).
- Big painted key art on recruitment banners and events (15–17, 30).
- New-hero reveal: a **3D close-up on a saturated purple swoosh** with a giant drop-cap name ribbon (J08).

### 3.5 Recruitment ceremony

1. **Banner:** key art + a drop-cap banner title + a guarantee line ("Elite Hero guaranteed upon ten recruits"), and
   **Recruit 1 (green) / Recruit 10 (orange)** with cost chips (J04). Round banner medallions sit at the bottom
   (Rate-Up / All-Hero / Epic / Stargaze), with a pity line on rate-up banners (16).
2. **Reveal:** new heroes get a close-up with a name ribbon, a quote and role chips (Class · Faction), J08. AFK Arena's
   premium "stargaze" is a crystal-ball flash with rays and a "hold your finger" instruction (afka 09).
3. **×10 summary:** duplicates are folded, NEW heroes break the grid (J01).

### 3.6 Faction and class badges

- Factions are **round medallions** (light compass star, red-gold sun, green leaf, dark eye) sitting on coloured ribbons
  (J03).
- Classes are small white glyph discs next to the name (J05: 4 discs: faction, class, damage type, rank).
- Skills are **gold hexagons** with a rank number at the bottom (J12).

### 3.7 Typography

- An **italic book serif** for titles, with a **coloured drop-cap block**: a green square with a large white serif
  capital ("**R**esonating Hall", J10).
- Body text uses a serif too. Numerals are giant and italic (J09).
- The owner explicitly rejected this serif. We keep only the **scale contrast**: giant numerals versus small labels.

### 3.8 How it differs from Genshin

| | Genshin | AFK Journey |
|---|---|---|
| Orientation | landscape | portrait |
| Stage | abstract element nebula | a real painted place (meadow, hall, stained glass) |
| Panels | symmetric pills, notched cream documents, dark glass lists | asymmetric paper slabs with one big rounded corner, torn paper, ribbons |
| Primary CTA | quiet cream pill + ring icon | loud full-width green / orange slab |
| Type | rounded sans, no italics | italic serif + drop caps |
| Rarity | colour grounds + stars | crystals in cages + coloured frames |
| Mood | cool, airy, elegant | warm, cosy, fairy-tale |
| Touch size | small | generous: CTA 100 px tall at 768 w (≈94 px at 720) |

### 3.9 AFK Arena: how the franchise solved portrait (Lilith, 2019)

- **Hub = an illustrated isometric city.** Every building is a labelled menu entry. Two **vertical scroll-icon rails**
  run down the left (timed events) and right (Quests, Bag, Mail, Friends), with a collapse chevron (afka 01, 02).
- **Hero detail:**
  - the hero stands centre on a pedestal;
  - 6 gear slots split **3 left | 3 right**;
  - a gem medallion + 5 stars + red rank pips + title + name at the top (A01);
  - a power plate, a stat row, three gold pills, and a sub-nav of 5 painted icons (Engrave, Inn, Skins, Hero, Skills).
  - The **backdrop changes with rarity**: a dark tomb for Ascended, a bright marble temple for Elite (05 vs 06).
- **Roster:** a 5-column grid where **frame colour = rarity**, stars sit under the frame, a level tag on top, and a
  faction filter row of round medallions with sub-tabs underneath (A02, afka 04).
- **Nav:** 5 wooden tabs with painted icons and labels; the active tab is lighter and inset.
- **Weaknesses we should not inherit:** the dark wood and gold-trim heaviness, everything framed, cyan CTAs that fight the
  palette. AFK Journey is AFK Arena's own correction: lighter, more paper, fewer frames, a bigger hero.

---

## 4. Sampled palettes (from the screenshots)

The method is in `_work/palette.py`. Each named region is cropped from the source and clustered with k-means (k = 4) on
up to 40k pixels. The value shown is the dominant cluster (`dom`), the mean of the darkest 8% (`ink`) or brightest 8%
(`hi`) of pixels, or the most saturated cluster with ≥ 8% share (`sat`). Boxes and all clusters are in `palettes.json`;
the visual is `palette_samples.png`.

**Genshin Impact**

| Swatch | Hex | | Swatch | Hex |
|---|---|---|---|---|
| parchment modal | `#F9F4EB` | | 1★ card | `#77787B` |
| banner card cream | `#F0ECE8` | | 2★ card | `#4C7B6B` |
| card footer cream | `#EEE8DD` | | 3★ card | `#517B9A` |
| cream detail-card body | `#ECE5D9` | | 4★ card | `#8C79B8` |
| cream pill button | `#ECE6D8` | | 5★ card | `#AC794C` |
| ink on cream | `#4B5669` | | star mark | `#F6C433` |
| gold header text | `#CCB68A` | | 5★ rate band | `#CEB283` |
| slate menu tile | `#515A6B` | | 4★ rate band | `#B5A8C9` |
| navy list slab | `#242E3E` | | 4★ silhouette violet | `#2D2740` |
| close X (ochre) | `#B38345` | | 5★ silhouette gold | `#F2A049` |
| NEW tag | `#EFB439` | | level-up band | `#0A68A8` |
| guarantee red | `#E5636C` | | stat-up green | `#8DE302` |
| Anemo stage | `#309E9B` | | Geo stage | `#B79A48` |

**AFK Journey**

| Swatch | Hex | | Swatch | Hex |
|---|---|---|---|---|
| cream table panel | `#F6F1EB` | | crystal Elite | `#8B3CB4` |
| paper ground | `#E5DFD3` | | crystal Epic | `#E7A54B` |
| dupe card cream | `#F1EBD1` | | crystal Legendary | `#CC4845` |
| ink (numerals) | `#8F8280` | | level numerals gold | `#EABC4E` |
| green CTA | `#669C5E` | | faction Lightbearer | `#485A90` |
| orange CTA | `#E5963A` | | faction Mauler | `#49251E` |
| drop-cap green | `#609656` | | faction Wilder | `#275D5D` |
| nav bar mauve | `#6C5C5D` | | faction Graveborn | `#35414E` |
| reveal swoosh | `#7240B6` | | NEW tag | `#FED50E` |
| sky | `#2782C7` | | distant haze | `#7094A0` |

**AFK Arena:** wood `#231D19`, gold pill `#E7CC8E`, cyan CTA `#5EFEFE`, parchment `#B9986B`.

Whole-screen dominant colours (k = 8; full lists in `palettes.json`):

| Screen | Dominant colours |
|---|---|
| Genshin 14 rates modal | `#F7F3EC` 24%, sky `#90AFCE` 21% |
| Genshin 12 banner | `#F5F1EE` 21%, ochre `#BB7E49` 18% |
| AFKJ 07 ascension | `#91999E` 32%, `#E5E0D4` 15%, `#F6F2EB` 14% |
| AFKJ 18 ×10 | `#F0EAD1` 36% |
| AFKA 05 | `#3F2D20` 19%, `#1A130D` 17% (dark wood) |

The point: **in both target games cream and paper take 15–36% of the pixels.** In AFK Arena dark wood takes 36%. That is
the brightness shift the owner is asking for.

---

## 5. What to take from each (specific)

From **Genshin**:
1. **Cream document panels** with one gold hairline frame and a faint background filigree (G11, G04). This is the base of
   our modals, detail cards and sheets.
2. **No boxes around information on hero screens.** Stats are icon + label + right-aligned value over the art with a soft
   shadow (G02). Text tabs (G01) become our hero-screen sub-tabs.
3. **Rarity grounds on cards:** a muted vertical gradient in the tier colour, a **cream footer strip** for level/count and
   a seam row of marks (G07). We use facet rhombi instead of stars.
4. **Element tints the stage** (03, 04, 06): our hero screen tints its painted backdrop with the hero's *gem* (as already
   specified in research_presentation §1.3 layer 0) and its element sets the particle motes.
5. **Full-width result bands** instead of modal boxes for level-up, recut and victory (09, 41), and **bare item rows**
   for rewards (G13 / 38).
6. **Typography discipline:** one rounded family, a gold breadcrumb, an accent-coloured keyword, big numerals (G04 "62").
7. The **constellation idea** (05) as the facet track: our 5 facets are drawn as a small cut diagram (a girdle outline
   with 5 facet planes that light up) on the Грані tab.
8. **Pack tiles where the painted object grows with the tier** (G03), for Gems packs and caches.

From **AFK Journey**:
1. **Portrait layout skeleton:**
   - hero detail: a full-height painted figure, emblem + name top-left, big level numerals bottom-right, a dock with a
     white back tab + a wide CTA (05, J05, J09, J13);
   - recruitment: key art → guarantee line → CTA pair (J04);
   - ×10: NEW breaks the grid (J01);
   - bottom nav with a raised active tab (J11).
2. **Painted busts on every card** (J06) and **painted places as backdrops** (05, 07): our heroes stand in *worlds*, not in
   gradients.
3. **Touch sizes:** CTAs 96–100 px tall, back tab 112×96, nav bar 120 px.
4. **Paper texture and the asymmetric corner** as the secondary panel language: for ribbons and the dock, used sparingly.
5. **Ascension as two crystals "A » B"** (J02): exactly our Recut (Огранка) display (Сапфір » Аметист).
6. **Faction ribbons with medallions** (J03): our 4 factions in the team/synergy screen.
7. **Name ribbon reveal with quote + identity chips** (J08): the end card of our walkout.

From **AFK Arena** (portrait):
1. **Side rails** of at most two icon buttons per side on Home, with a collapse chevron.
2. **Backdrop changes with rarity** (afka 05 vs 06), confirming our gem-tinted backdrop rule.
3. **Faction filter as round medallions** above the roster grid (A02 row).

---

## 6. FUSION for Crystal Rush (portrait 720×1280)

### 6.1 The formula in one line

**Genshin's information discipline and rarity colour system + AFK Journey's portrait skeleton, painted worlds and warmth +
our own gem and bridge language**, rendered as bitmaps.

### 6.2 What our signature adds (the anti-clone layer)

1. **Facet-cut corners** instead of Genshin's rounded/notched corners and AFKJ's asymmetric leaf corner.
   - Every cream panel and button has **45° chamfered corners (10 px at 720 w; 6 px on chips)**, like a gem's girdle seen
     from above.
   - Large panels get a **double chamfer**: a 10 px cut with a 1.5 px gold hairline running 4 px inside it.
   - Our silhouette reads as *cut stone*, not paper or pill.
2. **Crystal-facet ornament.**
   - Dividers are a gold hairline whose terminals are **a tiny cut-gem marquise** (6×10 px, with a table line) rather
     than Genshin's diamond-and-curl. The centre carries a **facet "keystone"**: a 12 px rhombus split into 4 facets,
     catching light.
   - No ✦ sparkles anywhere. Our glint is a **4-ray cross with one long ray** (a refraction streak). It is used only on
     rarity and CTAs.
3. **Bridge motif.**
   - Section headers and the top edge of the nav bar are a **shallow arch** (sag 6 px over 720) with a crystal keystone
     at the centre. That is the bridge span.
   - Progress bars are drawn as **bridge tiles**: segmented, each segment a small chamfered crystal plank that lights up
     (+1 tiles). This is the run's own vocabulary.
   - The home screen literally starts at the bridgehead.
4. **Gem rarity marks.**
   - The Living Gem emblem (procedural cut, real refraction) replaces stars and letter codes.
   - **Facet pips are rhombi**, not stars. Lit pips are filled with the gem's light tone; unlit pips are an engraved gold
     outline.
   - The background fracture pattern per gem (Кварц 60/120° planes, Сапфір 12° grid, Аметист triangles, Топаз 5 rays,
     Опал conchoidal arcs) replaces Genshin's nebula and AFKJ's slashes.
5. **Amber crystal CTA.** Only the key verbs (Грати, Призвати, Покращити, Огранити, Далі on Victory) use an amber slab with
   a **real cut topaz set into its left end**. That is the Genshin ring-socket idea re-made as our gem.

### 6.3 Cream panels and the world: option A / B / C

| Option | Description | Verdict |
|---|---|---|
| A | Brighter world everywhere: no dark worlds at all; cream everywhere | loses the variety the level ladder needs (frost, canyon, space nights are good runs) |
| B | Dark translucent HUD over the run + cream only in menus | **rejected by the owner** ("run HUD also light, no heavy dark glass") |
| **C (recommended): C-bright** | menus are cream on bright, warm 3D/painted stages; the run HUD uses light "porcelain" chips; space is one world among several; dark is only a gradient scrim under text on art and the Portal's night sky | matches the owner's answer and keeps contrast in every world |

How C-bright works in practice:

**Menus.**
- Every menu screen has a lit stage behind it:
  - Home: the bridgehead at dawn;
  - Heroes: the hero's faction world;
  - Arsenal: a sunlit workshop deck.
- Panels are cream `#F7F1E6`. The backdrop is never a flat dark colour.

**Run HUD = porcelain chips.**
- Cream `#FBF7EF` at 92% opacity, 1.5 px gold line `#C9A86A`, chamfered corners, slate ink text.
- A soft shadow (`#1E2433` at 25%, 8 px blur, 2 px down) lets the chips read on a sunny meadow and on the space world
  alike. They are small, edge-hugging and never full-width slabs.
- Gem hues never appear in the HUD (run palette rule).

**Dark is allowed only in three places:**
1. The bottom 30% scrim under the skills row on art (0→55% `#1E2433`).
2. Text-on-art shadows.
3. The Portal backdrop, a twilight sky, because summoning glow needs a dark ground. Its panels are still cream.

**Worlds.** Meadow, canyon, frost, sunset, space… The space world keeps its stars but gets a warm nebula key light so the
porcelain HUD and the army still pop.

### 6.4 Typography pick (Cyrillic)

**M PLUS Rounded 1c** (OFL, Google Fonts) is the single family:

| Role | Weight | Size (720 w) | Colour |
|---|---|---|---|
| Hero name (display) | ExtraBold | 64 px (56 if > 7 letters) | `#FFF8EC` on art + 3 px soft shadow `#1E2433` 40% |
| Big numerals (level, power, price) | Black | 72–96 px | ink on cream / `#FFF8EC` on art |
| Screen title | ExtraBold | 40 px | ink `#4B5669` |
| Primary button | ExtraBold | 36 px | white with a 3 px `#9C5A1F` outline + 2 px drop |
| Secondary button | Bold | 28 px | ink |
| Body | Medium | 24 px (line height 1.3) | ink |
| Labels / small caps | Medium | 20 px, +6% tracking | ink-2 `#7A6F69` |
| Minimum | Medium | 18 px | — |

- Verified: і ї є ґ І Ї Є Ґ ’ ʼ « » — № are all present (fontTools + render, `type_specimen.png`).
- Digits are tabular by default, so counters do not jitter.
- **Shipping:** subset to Latin + Latin-Ext + Cyrillic + punctuation (`pyftsubset`). That is ≈160 KB per weight, so the 4
  weights Medium, Bold, ExtraBold and Black come to ≈640 KB. Use Godot `FontFile` with MSDF for the ≥ 64 px display sizes.
- **Fallback:** Nunito (variable, one 277 KB file) if M PLUS weight files are too heavy.
- **Rubik**, the current repo face, retires from menus: it is not round enough for the owner's brief.
- Colour accents in text follow Genshin: one accent word per title, in the gem or element colour.

### 6.5 Palette (tokens, hex)

Derived from the samples in §4 and contrast-checked (WCAG ratios in brackets).

**Menu surfaces**

| Token | Hex | Use |
|---|---|---|
| `paper_0` | `#FBF7EF` | panel top highlight, porcelain chips |
| `paper_1` | `#F7F1E6` | panel body (between Genshin `#F9F4EB` and AFKJ `#F6F1EB`) |
| `paper_2` | `#ECE5D8` | secondary buttons, card footer strip, zebra rows (= Genshin pill `#ECE6D8`) |
| `paper_3` | `#E3D8C4` | page ground behind cards, pressed state, unowned cards |
| `gold_line` | `#C9A86A` | hairlines, frames, chamfer lines (decorative only, 2.0:1) |
| `gold_hi` | `#E3CB94` | lines and labels over art or dark |
| `gold_text` | `#8A6A2F` | engraved section titles on cream (4.5:1, ≥ 20 px) |
| `ink` | `#4B5669` | text on cream (6.6:1 on `paper_1`), from Genshin |
| `ink_2` | `#7A6F69` | labels (4.3:1, ≥ 18 px), AFKJ's warm taupe darkened |
| `ink_on_art` | `#FFF8EC` | text on art, always with a shadow |

**Key action (amber crystal CTA)**

| Token | Hex |
|---|---|
| `amber_hi` | `#FFE6A3` |
| `amber` | `#F5AE45` |
| `amber_lo` | `#D9822E` |
| `amber_rim` | `#9C5A1F` |

The CTA is a vertical gradient `amber_hi` → `amber` → `amber_lo`, with a 2 px `amber_rim` bevel and a cut topaz
`#FFB52E` / `#FFC860` set at the left. The label is white with a `amber_rim` outline, giving 5.4:1 against the outline.

**States**

| Token | Hex | Use |
|---|---|---|
| `plus` | `#3E8A2C` on cream / `#8DE302` on art | stat increase |
| `alert` | `#C0392B` text / `#D4515B` | badge fill |
| `new_tag` | `#FFCF3F` | NEW tag fill, with `#6A4512` text |
| `notify` | `#F5AE45` | gold "!" badge (no red dots) |

**Stage and world (Home)**

| Token | Hex |
|---|---|
| `sky_top` | `#7DB9E8` |
| `sky_mid` | `#BFE0F2` |
| `horizon` | `#FBE3BC` |
| `sun` | `#FFD98A` |
| `bridge_body` | `#DDF6FF` |
| `bridge_edge` | `#8FD9F0` |
| `bridge_trim` | gold `#C9A86A` |

**Shadows and scrims:** `scrim` `#1E2433` (0–55% gradients, chip shadow 25%).

**Bottom nav:** bar `paper_0` at 94%, top arch line `gold_line`, labels `ink_2` 16 px, active label `amber_lo`, active
medallion amber.

Family (element) accents stay frozen (arsenal §2.1). In meta UI they sit inside a round **slate socket** `#2B3245` with a
gold ring, so even Frost ivory `#F8FFD8` reads on cream.

### 6.6 Rarity treatment for the 5 gems

Every hero, champion or machine card is built the same way, following Genshin's construction with our marks:

| Part | Construction |
|---|---|
| Ground | a gem gradient (top → bottom) |
| Art | the painted bust |
| Frame | thin gold, plus an inner 1 px rim in the gem's light tone |
| Footer | a cream strip with name and level |
| Facet row | 5 rhombus pips on the seam |
| Emblem | top-left (Living Gem sprite) |
| Badges | class + element sockets, top-right |

| Gem | Card ground (top → bottom) | Rim | Setting / frame metal | Glow & motion | Background (full screens) |
|---|---|---|---|---|---|
| **Кварц** | `#7F8A96` → `#C3CCD5` | `#D6DEE6` | brushed steel `#AEB7C2`, 4 claws | none; matte | frosted 60/120° planes |
| **Сапфір** | `#2D6A9C` → `#63A9DD` | `#3FA9FF` | white gold | inner glow 20% `#7CC4FF`; glint every 8 s | crisp square grid tilted 12° |
| **Аметист** | `#553A8F` → `#9C7BD0` | `#B06CFF` (emblem body `#7A35D6`) | yellow gold, 3 V-prongs | animated energy lines on the frame | 30/90/150° triangles, colour-zoned |
| **Топаз** | `#A4612A` → `#E8AE5C` | `#FFB52E` | gold filigree, 5 prongs | warm bloom 45% `#FFC860` + slow sparkle; light pillar in ceremonies | 5 rays at 72° behind the head |
| **Опал** | black opal `#1A1530` → `#3A2D63` + play-of-colour flecks (small, blurred, hue-cycling `#7FE3FF / #B48CFF / #FF9FD6 / #FFE28A`) | iridescent hue-cycle | gold + 12-diamond halo | art **breaks the frame** (head over the top edge) | conchoidal arcs with a spectral rim |

- The ground values sit in the same mid-value band as Genshin's grounds, from `#77787B` to `#AC794C`, so the art leads.
  The gem identity is carried by the emblem cut + rim + name, which keeps it colour-blind safe.
- Facet pips: 12 px rhombi; lit = the gem light tone with a white table line; unlit = an engraved `gold_line` outline.
  "Повна огранка" (5/5) adds a slow shimmer along the pip row.
- Recut (Огранка) display = AFKJ's crystal pair: native emblem » new emblem, both in their cuts, with the doublet seam on
  the result (framework §1.2).

### 6.7 Component kit (all painted bitmaps, 9-slice; code only lays out)

| Component | Spec (720 w) |
|---|---|
| Cream panel | `paper_1` with a faint paper grain (3%) and a very faint facet filigree (4%) in one corner. Chamfer 10. Outer 1.5 px `gold_line`, inner hairline 4 px in. Header plate: a cream ribbon with marquise terminals. Shadow `#1E2433` 18%, 12 px blur. 9-slice margins 28 |
| Secondary button | `paper_2`, 1.5 px `gold_line`, chamfer 8, height 72–80, label 28 px ink. Optional 40 px gem-socket icon at the left. Pressed: `paper_3` + 2 px down |
| Primary CTA (amber crystal) | 88–112 px tall, ≥ 360 px wide; chamfer 12; gradient + bevel; cut topaz 56 px at the left end; label 36–44 px; light sweep every 4 s; press = squash 0.97 + topaz flash |
| Back | AFKJ white tab 96×88 at the bottom-left of the dock, chamfered, ink arrow |
| Close | 64 px cream disc with an ink X and a gold ring, top-right, 24 px margin |
| Currency capsule | porcelain chip 172×52, icon 40 px overlapping the left end, value 24 px Bold tabular, "+" 32 px disc (Coins only; Gems earned only = opens the earn list) |
| Tabs (segmented) | cream track 64 px tall; active segment = a raised `paper_0` chip with a gold underline keystone |
| Divider | `gold_line` 1.5 px, marquise terminals, centre facet keystone |
| Toast / band | full-width band 120–160 px tall in the theme colour (Victory: amber; Level-up: gem colour), dimming behind it at 40% |
| Card (hero) | 216×300; ground + bust + footer strip 64 px; emblem 52 px; facet row on the seam |
| Badge "!" | 28 px gold disc, ink "!" |

### 6.8 The six key screens (H = 1280; on taller phones the art band grows, the chrome does not)

#### 1. Home (tab «Грати»)

**Stage (3D, full bleed).** The bridgehead plaza at dawn:
- a round stone-and-gold plaza in the foreground (y 760–1000);
- the crystal bridge (`bridge_body` tiles, gold trim) runs from it to the vanishing point at x 360, y 430;
- behind: sky `sky_top` → `horizon` over clouds and meadow islands, tinted by the current world.

**Hero.** Stands on a round pedestal whose rim glows in the hero's native gem colour.
- Feet at y 860, head at y 300: about 44% of H, eye line at 27%.
- Plays an idle animation, and turns to the camera when tapped.

**Machines.** The Lead machine and the next two deck machines sit on the plaza at 0.55 scale (x 130 and x 590, y 700–860)
with idle loops. Tapping one opens Arsenal.

**Top bar (y 0–96).**
- Left: a 76 px avatar with a gold ring + a level chip.
- Right: two capsules, Coins and Gems.

**World plate (y 104–148).** A cream ribbon 380×44 centred: «Світ 2 · Луки · Рівень 14».

**Rails.** At most 2 buttons per side: 76 px cream chamfered discs with painted icons.
- Left: Події, Пошта.
- Right: Завдання, Скриня героїв (gold "!" when ready).

**Play.** A centred amber crystal slab at y 960–1072 (448×112) with a topaz at the left and «ГРАТИ» at 44 px. A second
line, «Рівень 14», sits inside under the label at 20 px.

**Under Play (y 1084–1118).** A row of 3 small threat-preview property icons (porcelain chips), only from L10.

**Nav (y 1160–1280).** Light bar with a top arch, 5 tabs:
- Магазин · Арсенал · **Грати** (centre; the active tab rises 28 px on an amber medallion 104 px) · Герої · Казарми;
- painted icons 64 px, labels 16 px.

**Motion:**
- a slow 12 s camera sway (±2°);
- light motes over the bridge;
- the Play glint every 4 s;
- tapping Play makes the camera dolly onto the bridge (0.6 s) before the run loads.

#### 2. Hero roster (tab «Герої»)

**Stage.** The Hall-of-Heroes painted backdrop (a warm interior with stained-crystal windows) behind a cream sheet that
covers y 200–1160.

| Zone | Content |
|---|---|
| Top bar (y 0–96) | currencies (Coins); right: the **Портал** button, 168×64, amber-small with a ring icon and a "!" when Beacons ≥ 1 |
| Title (y 104–156) | «Герої» 40 px + «7 / 10» ink_2; sub-tabs: segmented control **Герої · Чемпіони · Подвиги** (y 164–228) |
| Filters (y 240–296) | facet-cut chips: Самоцвіт · Клас · Стихія · Фракція · sort (Сила). Faction chips are AFKA-style round medallions |
| Grid (y 308–1148, scroll) | heroes: **3 × 216×300**, gap 12, margins 24 (the card is in §6.6/§6.7). Champions: **4 × 156×200** cameo cards with the same ground/rim rules. Unowned: a `paper_3` card with the ink silhouette at 18%, the fragment bar and a «Як отримати» tap |
| Nav | Герої active |

Sort order: Самоцвіт then Рівень. NEW cards wear the yellow tag. Tapping a card plays the crystallise wipe into Hero
detail.

#### 3. Hero detail «Вітрина героя»: Vesta (Топаз · Воїн · Плазма · Орден Світанку)

This applies research_presentation §1.3 zones in the fusion skin.

**Backdrop.** A painted Dawn Order world (a sunrise over the crystal bridge and white-gold ramparts), gradient-mapped to
the Topaz ramp. The 5 Topaz fracture planes radiate from behind the head at 10–14% alpha, with a light sweep every 6 s.

**Splash.** Vesta full-bleed in the right two-thirds, eye line at y 346, bleeding off the right and bottom edges. A
breathing rig and topaz motes play over her.

**Top-left column (x 28–260):**
- y 96–296: the Living Gem: a Topaz star cut in a gold filigree setting, 200 px box. Under it a cream plate «ТОПАЗ» in
  22 px small caps with marquise terminals.
- y 304–378: «Веста» 64 px ExtraBold `ink_on_art`. y 382–410: «Сонцекута» 24 px `gold_hi`.
- y 424–488: 3 round sockets, 64 px each, with gold rings: Воїн (crossed blades), Плазма (family glyph in its frozen
  accent on slate), Орден Світанку (sunrise sigil). Tapping one shows the synergy tooltip.
- y 500–524: facet row: 5 rhombus pips, 22 px (3 lit) + the fragment micro-bar «12 / 40».

**Top-right.** Fragment and Tome capsules.

**Level and power (y 820–944).** The bottom scrim starts at y 780. No box (Genshin), giant numerals (AFKJ):
- left: «Рів.» 20 px over «23» in 88 px Black + «/ 30» 28 px;
- right: «Сила» 20 px over «12 480» in 48 px.

**Skills (y 960–1092, tags to 1120).** 4 **cut-gem plates** (octagonal, chamfered, 132×132, gap 16, x 72–648): cream
enamel with gold walls and engraved
icons (Ульта, Атака, Клич, Пробудження as a sealed geode). Each has a hallmark stamp tag (3 / 5 / МАКС crown).
- The plates sit on the bottom scrim.
- Sub-tabs Огляд · Грані · Навички · Спорядження open the cream manage sheet from the bottom.

**Dock (y 1140–1256):**
- back tab 96×88;
- **«ПОКРАЩИТИ»** amber CTA 400×100 with a cost chip «1 260» (coin);
- secondary cream «3D» 112×88.

**Motion:**
- a swipe moves to the next hero through the crystallise wipe;
- tapping the gem spins it and plays its note;
- tapping the art hides the chrome.

#### 4. Portal (Призов) + reveal

**Static screen (our layout from research_presentation §2.2, fusion skin).**

Backdrop: a twilight sky (`#2A2550` → `#4A3A7A` → warm horizon `#F5AE45` glow at the bottom). This is the only
intentionally dark ground. The floor is the bridge's end, a crystal platform.

| Zone | Content |
|---|---|
| Top | back tab (dock) and a Beacon capsule («Маяк 12»). **No shop link** |
| y 112–288 | «Хто може з’явитися» cream ribbon header + a carousel of 5 mini hero cards 96×144 with gem grounds; **Фокус** chip on the chosen hero |
| y 300–820 | the **Portal ring** centred at y 560, diameter 520: gold filigree with 5 inset gem sockets (one per tier); its interior is a slow starlit swirl; idle hum |
| y 840–940 | two cream bars with chamfered ends: «Топаз або краще ≤ 23» (bridge-tile segments) and «Печатки 47 / 120 → вибір героя»; (i) odds chip at the right |
| Dock y 1100–1240 | secondary cream «Призов ×1 · 1 маяк» (300×96) + amber CTA «ПРИЗВАТИ ×10 · 10» (360×104) |

**Reveal (unchanged beats, research_presentation §2.3).**
- **Present** (0–0.4 s): seeds rise into an arc.
- **Tell** (+0.6 s): every seed lights in its final gem colour and cut. The portal column takes the best gem colour, with
  a pre-sting and twin pillars for Topaz+.
- **Sort** (0.85 s).
- **Batch crack** of Кварц/Сапфір (cards land face-up in the summary).
- **Walkouts** for Аметист+:
  - the light pillar in the gem colour;
  - the crystal grows in its cut;
  - Class → Element → Faction labels light inside it;
  - the shatter;
  - the splash steps out through the crystallise wipe;
  - the emblem flies top-left;
  - the name slams in.

**The fusion skin adds the end card of each walkout (AFKJ J08).** A cream **name ribbon** with chamfered ends crosses the
lower third (y 900–1060):
- «НОВИЙ» tag;
- name 64 px;
- a quote line 22 px;
- three identity chips (class, element, faction sockets).

**×10 summary:**
- 2 rows × 5 cards (124×186) on a cream sheet, sorted by gem high → low;
- duplicates fold to **cream fragment cards** «+30» (AFKJ J01);
- NEW cards are 10% taller and break the row (AFKJ);
- Seals odometer, pity bar;
- dock: amber «Готово» + cream «До героя: Веста».

#### 5. Arsenal (tab «Арсенал»)

**Stage.** A sunlit workshop deck at the bridge's side (painted). The Lead machine on a turntable fills y 160–520 (3D,
idle fire animation); the title sits over its top-left corner.

| Zone | Content |
|---|---|
| y 104–150 | title «Арсенал» + «Колода 4 / 6» + Auto-deck cream button (right) |
| y 530–690 | **Deck row:** 6 chamfered slots, 104×136, gap 8, margin 21. Lead slot with a crown; empty slot = an open gold setting (prongs open, research_presentation S4). Family counts under the row as socket chips («Volt 2 · Frost 1») and recipe hints |
| y 700–760 | segmented tabs **Машини · Спорядження армії** + filter chips (Рідкість · Родина) |
| y 772–1148 | **Machine grid** (scroll): 4 × 156×200 cards. Ground = rarity gradient (machines use the same 5 ladder colours, §6.6; names stay Common…Mythic until the owner approves gem names). 3D thumb, family socket top-right, level footer strip «Рів. 7», blueprint bar «12 / 20» on the seam, gold "!" when upgradable |

Machine detail is a cream sheet from the bottom: 3D turntable header, stat rows with no boxes, the talent pick 1-of-2 as
AFKJ choice cards (J07), and «ПОКРАЩИТИ» amber CTA with a cost.

#### 6. Result (after a run)

The run scene stays visible, frozen and dimmed to 60% brightness (not darkened to black).

**Victory:**
- A **full-width amber band** at y 180–330 wipes in (Genshin 09/41). It carries «ПЕРЕМОГА» 56 px ExtraBold white with an
  amber_rim outline, the level name under it in 22 px, and crystal keystone ornaments at both ends.
- **Crowns:** 3 crown sockets at y 350–440 fill one by one (gold, 0.25 s each).
- **Stats** with no boxes, y 470–620: Вижило «38», Знищено «212», Час «1:42»; numerals 40 px, labels 18 px.
- **Rewards** as a **bare item row** at y 650–820 (Genshin 38): 96×120 cards on rarity grounds with count footers
  (Монети, Креслення, Маяк…), staggered pop-in.
- At most **one inline reveal** (Hero Chest) in the y 840–1000 slot (framework rule).
- Dock y 1120–1240: amber «ДАЛІ» + cream «Повтор» / «Головна».

**Defeat:**
- The same layout with a **cool cream band** («Поразка», ink text, `paper_2` band with a slate rim).
- Tips are AFKJ choice cards: «Посилити армію», «Змінити колоду», «Підкріплення».
- Partial payout row.
- No red, no dark glass.

### 6.9 Risks and how to avoid them

| Risk | How it would happen | Mitigation |
|---|---|---|
| **"Genshin clone"** | cream pills + ✦ sparkles + the curved card corner + Genshin element glyphs + meteor wish + rounded font = instant recognition | keep the **principles**, swap every **mark**: facet-cut corners (not pills); marquise/keystone ornament (no ✦, no diamond-and-curl); our gem fracture backdrops (no nebula); facet rhombi (no stars); our family glyphs (frozen arsenal set); no meteor; the amber crystal CTA (not cream + ring socket); the ×10 card is a **girdle silhouette** (elongated hexagon, not a bookmark) |
| "AFK clone" | italic serif drop caps, green/orange slab pair, mauve nav | the serif is already rejected; our CTA pair is cream + amber, never green/orange; the nav is light cream with an arch, not mauve |
| Cream on bright worlds = low contrast, washed out | cream panels over a sunny sky | every panel has a 12 px soft shadow and a 1.5 px gold line; a backdrop vignette of 10%; ink text 6.6:1; on the brightest worlds dim the backdrop 15% behind sheets |
| Porcelain HUD fights the army in bright worlds | white chips over white crystal tiles | chips stay at the edges (top 96 px, sides); shadow + gold line; the crowd counter keeps its own frozen style |
| Production cost | painted heroes ×22, painted worlds, bitmap kit | one kit (≈25 9-slices + 12 icons) shared by all screens; worlds reuse the run arenas as menu stages; heroes already follow the layered splash pipeline (P7) |
| Generic "fantasy cream" | no identity once the ornaments are gone | the 3 identity anchors are always on screen: the Living Gem, the bridge (Home, progress bars, nav arch) and the amber topaz CTA |
| Font weight on low-end Android | 4 static CJK-derived files | subset to ≈160 KB each; MSDF only for display sizes |
| Legal | copying Genshin ornaments or the HYWenHei font | we ship OFL M PLUS Rounded 1c; all ornaments are drawn new from the gem/bridge brief; references stay in the scratchpad |

### 6.10 "Do not copy" list (for prompt writers and artists)

- The 4-point sparkle ✦.
- The dark ring "O" socket on cream pills.
- The curved bottom-right card corner.
- Bookmark ×10 cards.
- Genshin element glyphs and the Paimon tile grid.
- The meteor-over-clouds sky.
- AFKJ italic drop caps, green/orange CTA pairs, the mauve nav and acorn duplicate cards.
- AFKA wooden frames.

---

## 7. Concept-screen prompts for Gemini (so the owner sees the target before we build)

### Setup (для власника)

- **Інструмент.** Gemini з моделлю **Nano Banana Pro** (або новішою), найкраще в **Google AI Studio**: Aspect ratio
  **9:16**, Resolution **4K** (мінімум 1440×2560).
- **Референси**, прикріпіть до кожного промту:
  1. `uiref/fusion/moodboard_fusion.png` (стиль і палітра; промт каже брати з нього лише матеріали, а не розкладку);
  2. для екрана героя ще й `heroes/vesta_gemini.jpg` (персонаж).
- **Текст.** Модель може помилитися в українських словах. Це нормально для концепту: ми все одно накладаємо справжній
  текст у грі. Якщо слово зіпсоване, попросіть «Fix the text to exactly: …».
- **Результат.** Завантажуйте оригінал (PNG), не скріншот. Зробіть по 2–4 варіанти кожного екрана й оберіть найкращий.

### Prompt 1: Home screen

```
Create ONE finished mobile game screen mockup (a clean in-game screenshot, not a device photo).

FORMAT
- Portrait 9:16, 2160x3840 px (never below 1440x2560). Flat screenshot: no phone frame, no hands, no watermark.
- UI resolution logic: the screen is 720 logical px wide; every UI size below is given in logical px (multiply by 3 for 2160 px).

ART STYLE
- Premium 2026 mobile fantasy RPG. A fusion of Genshin Impact's clean light interface (cream panels, one thin gold hairline, generous air, no boxes around information) and AFK Journey's warm hand-painted storybook world (soft painterly 3D, gouache textures, golden morning light).
- Use the attached moodboard ONLY for materials, palette and finish, not for layout.
- UI pieces are rendered bitmap assets, not flat vector: cream enamel panels with a faint paper grain, polished gold hairlines, faceted crystals with real refraction and highlights. Corners of panels and buttons are cut at 45 degrees like a gemstone girdle (small chamfers), not pill-round.

CONTENT (top to bottom)
- Top bar (0-96 px): left - a round player portrait in a gold ring with a small level badge "14"; right - two cream currency capsules with a soft shadow: a gold coin icon with "12 480" and a small "+", a faceted blue gem icon with "320".
- Under it, centred, a slim cream ribbon plate with tiny gold gemstone terminals and the text "Світ 2 · Луки · Рівень 14".
- A live 3D scene fills the screen: dawn at the head of a long CRYSTAL BRIDGE. The bridge is made of translucent ice-white crystal planks with gold trim; it starts from a round stone-and-gold plaza in the foreground and runs straight into the distance toward the horizon above a sea of soft clouds and small green meadow islands.
- On a round stone pedestal at the bridgehead stands a heroine, large (from about 23% to 67% of the screen height): a young woman knight with a copper-auburn braid, white-enamel and gold plate armour with sunburst engravings, a crimson-orange half-cape, holding a glaive whose blade is one big glowing topaz crystal. The pedestal rim glows warm topaz-amber.
- Two war machines idle on the plaza slightly behind her, one on each side: a bronze-and-steel cannon on the left, a crystal ballista on the right.
- Edge buttons: left edge - two small round cream buttons with painted icons (a scroll, a sealed letter); right edge - two (a quest book, a small treasure chest with a gold "!" badge).
- Lower centre (y 960-1072): the big PLAY button - a wide warm gold-amber slab with chamfered gem-cut corners and a subtle bevel; a real cut topaz gem set into its left end; the word "ГРАТИ" in a heavy rounded friendly white typeface with a dark amber outline; a small line "Рівень 14" under it inside the button. A soft light sweep across it.
- Bottom (1160-1280): a light cream navigation bar whose top edge is a very shallow arch with a tiny crystal keystone in the middle; five painted icons with labels: "Магазин", "Арсенал", "Грати", "Герої", "Казарми". The middle tab "Грати" is active: its icon sits larger on a round amber medallion that rises above the bar.
- Typography everywhere: one soft rounded humanist sans (like M PLUS Rounded), heavier for titles. No serif, no italics.

COLOR
- Morning sky #7DB9E8 fading to a warm horizon #FBE3BC, sunlight #FFD98A from the upper left.
- UI cream #F7F1E6 and #ECE5D8, gold hairlines #C9A86A, text slate #4B5669.
- Play button amber #FFE6A3 -> #F5AE45 -> #D9822E with a #9C5A1F rim; topaz #FFB52E.
- Bridge crystal #DDF6FF with #8FD9F0 edges. Everything bright, warm and airy.

COMPOSITION
- The heroine is the focal point, centred, her eyes at about 25-27% of the height; the bridge leads the eye from her to the horizon.
- UI hugs the edges: top 12% and bottom 22% only; the middle is pure scene.
- Exactly one loud element: the PLAY button.

AVOID
Dark or space background, heavy dark glass panels, neon, comic-book outlines, thick black strokes, flat vector UI, pill-shaped buttons, four-point sparkle stars, star rating icons, red notification dots with numbers, cluttered icon grids, more than two buttons per side, any real game's logo or characters, extra text, misspelled words, blurry details.
```

### Prompt 2: Hero detail with Vesta

```
Create ONE finished mobile game screen mockup: the hero detail screen for the heroine in the attached character reference.

FORMAT
- Portrait 9:16, 2160x3840 px (never below 1440x2560). Flat in-game screenshot: no phone frame, no watermark.
- The screen is 720 logical px wide; UI sizes below are logical px (x3 for 2160).

ART STYLE
- Premium 2026 mobile RPG hero screen: Genshin Impact's information discipline (no boxes around stats, clean light type over the art) fused with AFK Journey's portrait hero screen (full-height painted hero standing in a real painted place, big numbers, generous buttons).
- The heroine is the SAME painterly splash style as the attached reference (hand-painted fantasy key art, crisp edges, warm light). Use the attached moodboard only for UI materials and palette.
- UI pieces are rendered bitmaps: cream enamel, polished gold hairlines, faceted gems with refraction. Panel and button corners are small 45-degree gem-cut chamfers.

CONTENT
- Background: a painted sunrise landscape - the crystal bridge and white-and-gold ramparts on a cliff above clouds, colour-graded toward warm topaz gold. Five very faint translucent crystal planes radiate from behind the heroine's head like light rays (about 12% opacity).
- The heroine (Vesta: copper-auburn braid, amber eyes, thin scar on the left cheek, white-enamel and gold plate with sunburst engravings, crimson-orange half-cape, glaive with a single blazing faceted topaz blade) fills the right two-thirds, from head to below the knees, bleeding off the right and bottom edges; her eyes at about 27% of the height. Topaz sparks drift around the blade.
- Top-left column (left 36% of the width):
  - A large cut TOPAZ gemstone in a five-point star cut, set in an ornate gold filigree setting with five prongs, glowing warm amber (about 200 px box). Under it a small cream plate with the word "ТОПАЗ" in small caps.
  - The name "Веста" very large in a heavy rounded white typeface with a soft shadow; under it "Сонцекута" in smaller warm-gold letters.
  - Three round 64 px badges in gold rings: crossed blades (class), a glowing plasma orb in rose-magenta on a dark slate disc (element), a rising-sun sigil (faction).
  - A row of five small diamond-shaped facet pips: three lit amber, two engraved empty; a thin progress bar "12 / 40" under them.
- Top-right: two small cream capsules (a crystal fragment icon "12", a book icon "3").
- Lower area, with no box (text directly over the art on a soft dark gradient at the very bottom): left "Рів." small over a giant number "23" and "/ 30"; right "Сила" small over "12 480".
- Skills row: four octagonal gem-cut plates (132 px) in cream enamel with gold walls and engraved icons (a glaive slash, a sunburst, a war horn, a sealed rough geode with a glowing crack for the locked fourth). Each has a tiny gold tag under it: "3", "5", "1", and a lock.
- Bottom dock: a white chamfered back tab with a slate arrow on the left; a wide warm gold-amber button with a cut topaz at its left end and the word "ПОКРАЩИТИ" plus a small coin chip "1 260"; a small cream button "Деталі" with a tiny 3D-cube icon on the right.
- Typography: one soft rounded humanist sans (like M PLUS Rounded); heavier for titles. No serif.

COLOR
- Warm sunrise: gold #FFD98A light, topaz #FFB52E / #FFC860 accents, cream #F7F1E6, gold hairlines #C9A86A, text on art #FFF8EC, slate ink #4B5669 on cream, amber button #F5AE45 -> #D9822E.
- Every crystal in the scene is golden topaz; no teal, green or purple crystals.

COMPOSITION
- Left 36% of the width is a calm column for the emblem, name and badges; the heroine owns the rest.
- The bottom 30% holds numbers, skills and the dock; the middle of the screen has no UI.

AVOID
Boxes or panels around stats, star icons, letter rarity codes like "SR", comic fonts with thick black outlines, flat vector icons, pill buttons, four-point sparkles, dark heavy glass, Genshin or AFK Journey logos or characters, extra text, misspelled words, extra fingers or limbs, cropped head.
```

### Prompt 3: Portal summon (the "Tell" moment of a ×10)

```
Create ONE finished mobile game screen mockup: the hero summoning portal at the moment a ten-summon reveals its gems.

FORMAT
- Portrait 9:16, 2160x3840 px (never below 1440x2560). Flat in-game screenshot: no phone frame, no watermark.
- The screen is 720 logical px wide; UI sizes below are logical px (x3 for 2160).

ART STYLE
- Premium 2026 mobile RPG ceremony screen: Genshin Impact's clean light UI and AFK Journey's warm painterly magic. Use the attached moodboard only for materials and palette.
- The scene is a twilight sky (the only dark-ish screen in the game) with warm light; UI panels stay light cream. Rendered bitmap finish: polished gold filigree, real faceted gems with refraction and dispersion, soft volumetric light.

CONTENT
- Background: the far end of the crystal bridge becomes a round crystal platform floating above twilight clouds; the sky goes from deep indigo at the top through violet to a warm amber glow at the horizon.
- Centre (ring centre at 44% of the height, diameter 72% of the width): a large circular PORTAL ring of gold filigree with five small inset gemstones around it (a round clear quartz, a square blue sapphire, a triangular violet amethyst, a star-cut golden topaz, an oval black opal with rainbow flecks). Inside the ring a slow swirl of starlight. A column of warm golden light rises from the ring.
- Ten crystal seeds float in an arc across the ring, each already glowing in its own gem colour and cut: four frosted white-grey round quartz, three blue square sapphires, two violet triangular amethysts, one golden five-point-star topaz that is the brightest and has a small golden light pillar.
- Top: a cream ribbon header "Хто може з’явитися" with a row of five small hero cards (painted portraits on gem-coloured gradient grounds with thin gold frames).
- Top-right: a cream capsule with a glowing lighthouse-beacon icon "12".
- Below the ring: two cream progress bars with gem-cut chamfered ends and gold frames, each made of small crystal tile segments like bridge planks: "Топаз або краще ≤ 23" and "Печатки 47 / 120 → вибір героя"; a small round "i" chip at the right.
- Bottom dock: a white chamfered back tab with an arrow on the left; a cream button "Призов ×1 · 1"; a wide warm gold-amber button with a cut topaz at its left end: "ПРИЗВАТИ ×10 · 10".
- Typography: one soft rounded humanist sans (like M PLUS Rounded). No serif.

COLOR
- Sky #2A2550 -> #4A3A7A -> horizon glow #F5AE45. Gold filigree #C9A86A to #FFE6A3 highlights.
- Gems exactly: quartz #D6DEE6, sapphire #3FA9FF, amethyst #B06CFF, topaz #FFB52E, black opal #1A1530 with rainbow flecks.
- UI cream #F7F1E6, slate text #4B5669, amber button #F5AE45 -> #D9822E.

COMPOSITION
- The portal ring and the seeds are the focal point; the UI is limited to the top 22% and the bottom 25%.
- The single topaz seed is the brightest object on the screen.

AVOID
Shop or purchase buttons, prices in money, "buy" text, shooting stars or meteors over clouds, character silhouettes, four-point sparkles, star icons, dark glass panels, neon cyberpunk light, comic outlines, any real game's logo or characters, extra text, misspelled words.
```

---

## 8. Next steps (proposal)

1. The owner generates the 3 concept screens (§7) and picks or adjusts. We do not build before this.
2. If approved, re-target the **UI-kit prompts** (`ui_kit_prompts.md`) to this fusion: cream chamfered panel, amber crystal
   CTA, secondary cream button, nav bar with arch + medallion, currency capsule, divider set, gem card grounds ×5, porcelain
   HUD chip.
3. Swap the menu face to M PLUS Rounded 1c (subset), and run `loc_lint` / glyph checks on all strings.
4. Build in the order Home → Hero detail → Roster → Portal skin → Arsenal → Result, each checked against its concept
   screen at 720×1280 and 720×1560.
