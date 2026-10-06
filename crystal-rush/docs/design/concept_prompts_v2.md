# Concept prompts v2 (Gemini, Nano Banana Pro): "MUCH closer to Genshin"

Binding inputs: `OWNER_DECISIONS.md` Rounds 1–4, `../../heroes/decisions.md` Addenda 4–5, `../../fusion_genshin_afkj.md`
§2 / §6 / §7. The v1 result is `concepts/home_v1.jpg`. The owner kept its composition and component set, and rejected
its casual-cartoon finish.

Screens in this file (every prompt is complete and self-contained, as Addendum 5 requires; nothing needs to be merged
by hand):
1. Home v2
2. Hero detail, splash mode (Vesta)
3. Hero detail, «Деталі» mode (Vesta in live 3D + the «Атрибути» sheet)
4. Portal v2 (the full prompt, with the v1 §7 Prompt 3 content and all v2 refinements merged in)

Each prompt is about 450 words, section names included. The most important instructions (style benchmark, finish,
typography, proportions) come first, then the character, the colour lock, the layout and a short AVOID list. Only text
that must appear on screen is in quotation marks.

---

## 0. What went wrong in v1 and what v2 changes

| v1 failure (owner verdict) | What in the v1 prompt caused it | v2 fix |
|---|---|---|
| Thick outlined text | The prompt asked for a "heavy rounded **friendly** white typeface **with a dark amber outline**" | "One clean humanist sans, medium weight, small, never outlined", plus AVOID. The amber buttons get a deeper amber centre so white text reads without an outline; if an outline still appears, a follow-up switches the label to deep brown |
| Chibi heroine | "a young woman knight" with no proportion cue and no character reference on Home | "ADULT woman knight, realistic proportions: 8 heads tall, long legs, mature face" (Addendum 5: 7.5–8). `vesta_gemini.jpg` is attached for identity only (not its brushwork or pose) |
| Emoji / clip-art icons, crossed swords twice | "five painted icons" with no motifs | Each nav tab has its own named motif; edge buttons are gold-ringed cream discs with slate line glyphs; AVOID bans emoji icons and repeated motifs |
| Flat, empty grey plaza | "a round stone-and-gold plaza" | "Warm ivory-marble rotunda terrace with gold inlay, crystal-lantern balustrade, steps and planters; never empty" |
| Chunky UI | "a subtle bevel", a big slab, no line weights | "Quiet, minimal UI: almost-flat translucent cream, hairline gold lines, small gem-cut chamfers, soft shadows; no bevels or gloss" |
| Pale, flat light | "everything bright" | Deeper azure sky `#5AA6EC` to a warm horizon, god rays, bloom, haze, sunlit clouds |
| Casual-mobile prior | The prompt opened with "mobile game screen" and "friendly" | Every prompt now opens with a top-tier anime-influenced console-RPG benchmark and "NOT a casual mobile game" |
| Small output | `home_v1.jpg` is a 1116×2000 JPG | 4K setting and downloading the original PNG |

What Genshin's refinement actually is (from `genshin/03, 08, 10, 13, 14, 38`, `board_closeups.png` G01–G14). The prompts
describe these qualities and never name the game:
- **The UI is quiet.** Surfaces are almost flat (a whisper of gradient, no bevel). The drama comes from the art and the
  light, not from the chrome. Saturation is low in the UI and high in the art.
- **Lines.** Hairlines are 1–2 px gold (`#C9A86A` / `#CCB68A`) with small terminals. Frames are double hairlines.
- **Layers.** Cream parchment (`#F7F1E6`) is a document you hold. Translucent layers sit over a blurred, living world,
  with soft diffuse shadows. The hero's own space has no panel at all.
- **Type.** One humanist sans with softened ends, medium weight, small quiet sizes. Hierarchy comes from size and
  colour, never from outlines. White text gets a soft shadow on art; slate `#4B5669` is used on cream.
- **Icons.** Menu icons are monoline glyphs in rings. Painted icons are reserved for items and currencies, and are
  soft, small and lit from the upper left.
- **Space.** Density is low (12–18 interactive elements per screen). The middle third belongs to the hero. Stat rows
  have no boxes.
- **Light.** Luminous painterly light with bloom, motes, rim light and soft gradients. Rarity and element tint the
  whole screen.
- **Characters.** Refined, anime-influenced, adult proportions with clean faces. Never chibi.

---

## Загальне налаштування (для власника, однакове для всіх чотирьох промтів)

- **Інструмент.** Google AI Studio → модель **Nano Banana Pro** (Gemini 3 Pro Image) або новіша. Підійде і застосунок
  Gemini, але в AI Studio видно налаштування.
- **Налаштування.** Aspect ratio **9:16**, Resolution **4K**. Після завантаження перевірте розмір файлу: щонайменше
  **1440×2560** (4K має дати більше). `home_v1.jpg` прийшов як 1116×2000 JPG, тобто менший за мінімум.
- **Новий чат на кожен екран.** Не продовжуйте чат, де генерувався v1: модель тягне звідти мультяшний стиль.
- **Референс.** До кожного промту прикріплюйте лише **один** файл: `heroes/vesta_gemini.jpg` (у промті це «Reference 1»).
  **`moodboard_fusion.png` більше НЕ прикріплюйте:** на ньому персонажі й тексти інших ігор, зірки, червоні крапки й темне
  тло, і модель переносить їх у результат. Палітру промт задає кольорами.
- **Промт копіюйте повністю**, від першого до останнього рядка блоку. Нічого не потрібно дописувати чи замінювати.
- **Варіанти.** Зробіть 2–4 варіанти й оберіть найкращий. Якщо зіпсоване одне слово, напишіть у тому ж чаті:
  `Fix only the text, keep everything else: "…" must read exactly "…"`.
- **Результат.** Завантажуйте **оригінальний PNG** (кнопка Download / «Завантажити повнорозмірне»), не скріншот.
  Назви файлів: `concepts/home_v2_a.png`, `concepts/hero_splash_v2_a.png`, `concepts/hero_details_v2_a.png`,
  `concepts/portal_v2_a.png`.
- **Якщо після двох спроб усе ще мультяшно**, у тому ж чаті прикріпіть `_work/craft_ref_v2.png` (дошка з кропів
  інтерфейсу без персонажів) і надішліть це повідомлення повністю:
  `Redraw this screen with the finish of the attached image: hairline gold lines, quiet almost-flat cream surfaces, soft shadows, small clean text without outlines. Take only that finish. Do not copy its layout, icons, star marks, sparkles, panel colours, English text or anything else from it. Keep this screen's layout, heroine, Ukrainian text and colours exactly.`
- **Текст.** Модель може помилитися в українських словах. Для концепту це не страшно, бо в грі ми накладаємо справжній
  текст. Але перевірте ключові рядки за списком під кожним промтом.

---

## 1. Home screen v2

### Налаштування (для власника)

- Google AI Studio → **Nano Banana Pro**, **9:16**, **4K** (мінімум 1440×2560), новий чат.
- **Reference 1:** `heroes/vesta_gemini.jpg`. Обличчя, коса, обладунок і глефа героїні. Промт бере з нього лише
  зовнішність, а не мазок, позу чи сіре тло.
- **НЕ прикріплюйте `home_v1.jpg`** у першій спробі: модель скопіює його мультяшний рендер. Розкладку з v1 промт
  описує словами. Якщо розкладка «попливе», у тому ж чаті прикріпіть `concepts/home_v1.jpg` і надішліть повністю:
  `The attached image is a rough layout sketch only. Move the elements of your last image to match its positions: portrait, currency plates, ribbon, four edge buttons, heroine on the pedestal, the two machines, the main button and the bottom bar. Keep your refined finish, proportions and icons; take nothing of its cartoon rendering, fonts, outlines or icons.`
- Зробіть 3–4 варіанти. Завантажте оригінальний PNG і збережіть як `concepts/home_v2_a.png`.

### Prompt

```
FORMAT
In-game screenshot, home screen of a premium fantasy RPG; portrait 9:16, 4K; no frame or watermark. Render quoted strings exactly, in Ukrainian; no other text.

ART STYLE
- The polish of a top-tier anime-influenced open-world console RPG (quality only; copy no existing game, character, logo or layout). Elegant, restrained, luminous. NOT a casual mobile game.
- Refined stylised 3D: painterly textures, soft cel shading, bloom, god rays, haze.
- Quiet, minimal UI: almost-flat translucent cream, hairline gold lines, small gem-cut chamfers, soft shadows; no bevels or gloss.
- One clean humanist sans, medium weight, small, never outlined: white with soft shadow on the scene, slate on cream.

CHARACTER
Vesta from Reference 1 (identity and costume only, not its brushwork or pose), refined real-time 3D. ADULT woman knight, realistic proportions: 8 heads tall, long legs, mature face. Copper-auburn braid, amber eyes, cheek scar, white-and-gold sunburst plate armour, crimson-orange half-cape, glaive taller than her with a faceted glowing topaz blade.

COLOR LOCK
Her gems all topaz #FFB52E. Sky #5AA6EC to warm horizon #FBE3BC; cream #F7F1E6; gold #C9A86A; text #4B5669; main button #FFE6A3 to deep amber #D9822E.

LAYOUT AND COMPOSITION
- Top-left: round portrait of her face in a fine gold ring, slate disc "14". Top-right: two slim chamfered cream plates: gold coin "12 480" and small "+"; blue gem "320". Centred below: slim cream ribbon "Світ 2 · Луки · Рівень 14".
- Below, two round gold-ringed cream edge buttons per side with slate line glyphs: pennant, envelope (left); book, chest with a gold "!" (right).
- Bright summer morning at the head of a long crystal bridge with gold trim and lanterns, running to the horizon over sunlit clouds and floating islands.
- Foreground: warm ivory-marble rotunda terrace with gold inlay, crystal-lantern balustrade, steps and planters; never empty.
- Vesta centred on a round marble dais with a glowing topaz rim, calm three-quarter idle, glaive upright; head at 23%, feet at 67% of the height. Behind her: bronze cannon (left), crystal ballista (right).
- Main button at 75-82% height, 58% width: luminous gold-amber jewel slab with a fine rim and a cut topaz in a gold bezel at its left. "ГРАТИ" white, soft shadow only; smaller "Рівень 14" below.
- Bottom bar: light translucent cream, arched gold hairline top edge with a crystal keystone; five small painted icons with taupe labels: "Магазин" coin pouch, "Арсенал" cannon on a cog, "Грати" (centre, active) bridge arch on a raised amber medallion, "Герої" sunburst shield, "Казарми" tent.
- UI only in top 12% and bottom 20%; the main button is the only loud element.

AVOID
Cartoon or casual mobile look; chibi, big head, doll face; outlined, stroked or bubbly text; emoji icons, repeated motifs; chunky glossy bevels, pills, thick borders, dark active-tab slab; dark or neon palette; stars, sparkles, red dots; English text, misspellings, deformed hands.
```

**Check these strings in the result:** «14» · «12 480» · «+» · «320» · «Світ 2 · Луки · Рівень 14» · «!» · «ГРАТИ» ·
«Рівень 14» · «Магазин» · «Арсенал» · «Грати» · «Герої» · «Казарми».

**Corrective follow-ups** (paste in the same chat when needed; each is a complete message):
- Outlines came back: `Remove every text outline and stroke; keep text warm white with only a soft shadow. Change nothing else.`
- The «ГРАТИ» label still has an outline: `Make "ГРАТИ" and "Рівень 14" deep warm brown #5A3410 with no outline, no stroke and no glow. Change nothing else.`
- She is still stylised-cute: `Repaint the heroine with realistic adult proportions, about 8 heads tall, a smaller head, a mature refined face like Reference 1. Keep everything else.`
- Icons look like emoji: `Repaint the five bottom-bar icons as small refined painted inventory icons, soft light from the upper left, no outline, each a different motif as listed. Keep everything else.`
- The floor is empty: `Add detail to the marble terrace: inlaid gold rosette, polished reflections, balustrade shadows, crystal lanterns, flowering planters. Keep everything else.`
- The UI is chunky: `Make every UI element thinner and quieter: hairline gold lines, almost-flat translucent cream, soft shadows, smaller text. Keep the layout, the scene and the heroine.`

---

## 2. Hero detail v2, splash mode (Vesta)

### Налаштування (для власника)

- Google AI Studio → **Nano Banana Pro**, **9:16**, **4K** (мінімум 1440×2560), новий чат.
- **Reference 1:** `heroes/vesta_gemini.jpg`. Поза, обличчя, обладунок і глефа. Сплеш перемальовується тоншим стилем,
  але це та сама Веста в тій самій позі.
- Це обрана вами розкладка: повноекранний сплеш, емблема-самоцвіт, ім’я й титул, три значки, ряд граней («зірок»),
  ряд навичок із плашками рангу, кнопка «Деталі». Кнопки «Покращити» тут навмисно немає: вона живе в режимі «Деталі»
  (промт 3).
- «Зірки» намальовані ромбами-гранями. Це наш підпис замість зірок; вкладка в режимі «Деталі» називається «Зірки», як ви
  обрали.
- Емблема Топазу в промті — **п’ятикутна огранка з п’ятьма променями граней**, а не зірка: слово «star» модель малює
  як пласку жовту зірку-рейтинг.
- Зробіть 3–4 варіанти. Збережіть як `concepts/hero_splash_v2_a.png`.

### Prompt

```
FORMAT
In-game screenshot, hero showcase screen of a premium fantasy RPG; portrait 9:16, 4K; no frame or watermark. Render quoted strings exactly, in Ukrainian; no other text.

ART STYLE
- The key-art and UI polish of a top-tier anime-influenced open-world console RPG (quality only; copy no existing game, character, logo or layout). Elegant, luminous, restrained. NOT a casual mobile game.
- Full-screen splash: semi-realistic, anime-influenced painted key art; refined face, smooth rendering without outlines, luminous light, strong warm rim light, crisp edges.
- Quiet, minimal UI: text on the art, no boxes; hairline gold, small gem-cut chamfers, soft shadows; no bevels.
- One clean humanist sans, small, letter-spaced, never outlined: warm white with soft shadow.

CHARACTER
Vesta from Reference 1: same identity, costume, glaive and diagonal lunge, repainted more refined and luminous. ADULT woman knight, realistic proportions (8 heads), mature face. Copper-auburn braid whipping behind, amber eyes, cheek scar, fierce look; white-and-gold sunburst plate, crimson-orange half-cape; huge blazing faceted topaz glaive blade swung to the lower left, sparks flying.

COLOR LOCK
Every crystal is golden topaz #FFB52E; no teal, green, blue or purple crystals. Wash: honey #FFE6A3 to deep amber #A4612A. Gold #C9A86A; cream #F7F1E6; element accent magenta #D80A71.

LAYOUT AND COMPOSITION
- Background: warm topaz light washes the whole screen, brightest behind her head, deep amber at lower left; five translucent faceted rays behind her head; drifting motes.
- She fills the right two-thirds, head to below the knees, bleeding off right and bottom; eyes at 29% height.
- Left column (left 40%, top 45%), top to bottom: large pentagonal-cut topaz with five facet rays in a fine five-prong gold filigree setting; under it a slim cream plate "ТОПАЗ" in dark-gold capitals. "Веста" large; under it "Сонцекута" in warm gold. Three small round slate badges, fine gold rings, line glyphs: crossed glaive and sword, magenta plasma orb, rising sun. "Воїн · Плазма · Орден Світанку", small. Five small rhombus pips (three lit topaz, two engraved outlines), hairline bar, "12 / 40".
- 45-68% height: no UI.
- Bottom 30%, over a soft dark gradient: "НАВИЧКИ" between two gold hairlines; four octagonal skill plates, thin double gold walls, delicate painted icons on amber enamel (glaive in a sunburst, crescent slash, sun behind a war horn, dim locked geode); small cream rank tags "5", "6", "МАКС" and a padlock.
- Dock: small cream back tab with a slate arrow (left); cream button with a cube glyph and "Деталі" in slate (right).
- Face brightest and sharpest; blade second.

AVOID
Cartoon or casual mobile look; chibi, big head, doll face; outlined, stroked or bubbly text; boxes behind name or stats; letter rarity codes, slash stripes; emoji icons, repeated skill motifs; chunky bevels, pills; stars, sparkles, red dots; English text, misspellings, deformed hands, second weapon, cropped head.
```

**Check these strings in the result:** «ТОПАЗ» · «Веста» · «Сонцекута» · «Воїн · Плазма · Орден Світанку» · «12 / 40» ·
«НАВИЧКИ» · «5» · «6» · «МАКС» · «Деталі».

**Corrective follow-ups:**
- The splash went cartoon: `Repaint the heroine as elegant semi-realistic painterly key art like Reference 1 but more refined: realistic adult proportions, refined face, luminous rim light, no outlines. Keep the UI exactly.`
- The name has an outline: `Remove the outline from "Веста" and "Сонцекута"; keep only a soft shadow. Change nothing else.`
- The skill plates are chunky: `Make the four skill plates finer: thin double gold hairline walls, smaller plates, delicate painted icons. Keep everything else.`
- The emblem became a flat star: `Repaint the emblem as a real faceted pentagonal topaz gemstone with five facet rays, refraction and a white table highlight, in a delicate five-prong gold setting. Keep everything else.`

---

## 3. Hero detail v2, «Деталі» mode (live 3D Vesta + the «Атрибути» tab)

### Налаштування (для власника)

- Google AI Studio → **Nano Banana Pro**, **9:16**, **4K** (мінімум 1440×2560), новий чат.
- **Reference 1:** `heroes/vesta_gemini.jpg`. Ідентичність Вести. Тут вона має виглядати як **жива 3D-модель у грі**
  (реалістичні пропорції, близько 7,5–8 голів), а не як мальований сплеш.
- Якщо таблиця атрибутів вийде «в рамочках», спершу надішліть підказку «The rows came out boxed» нижче; якщо не
  допоможе, скористайтеся `_work/craft_ref_v2.png` і повідомленням із загального налаштування. На ній видно рядки без рамок.
- Зробіть 3–4 варіанти. Збережіть як `concepts/hero_details_v2_a.png`.

### Prompt

```
FORMAT
In-game screenshot, hero details screen of a premium fantasy RPG; portrait 9:16, 4K; no frame or watermark. Render quoted strings exactly, in Ukrainian; no other text.

ART STYLE
- The character-screen polish of a top-tier anime-influenced open-world console RPG (quality only; copy no existing game, character, logo or layout). NOT a casual mobile game.
- Quiet, minimal UI: translucent cream parchment, hairline gold lines, small gem-cut chamfers, soft shadows, generous spacing. Clean text rows divided by hairlines; no boxes, cards or stripes.
- One clean humanist sans, never outlined: medium labels, bold numbers; slate on cream, warm white with soft shadow on the stage.

CHARACTER
Vesta from Reference 1 as a high-quality real-time 3D game model, not a painting: hand-painted textures, soft cel shading, warm rim light. ADULT woman, realistic proportions: 8 heads tall, long legs, mature refined face. Copper-auburn braid, amber eyes, cheek scar; white-and-gold sunburst plate, crimson-orange half-cape, glaive with a huge faceted topaz blade.

COLOR LOCK
Every crystal is golden topaz #FFB52E; no teal, green, blue or purple crystals. Stage #FFE9B8 to amber #B87436 at the corners. Cream #F7F1E6, gold #C9A86A, text slate #4B5669, labels taupe, button #FFE6A3 to deep amber #D9822E.

LAYOUT AND COMPOSITION
- Stage (top 52%): luminous honey-gold haze, brightest behind her; five faint faceted rays; topaz motes. Low round marble dais with a fine glowing topaz rim, soft contact shadow.
- She stands centred, full body, head top at 7%, feet at 49% of the height; relaxed three-quarter idle, glaive upright, blade above her head.
- Top-left: small pentagonal topaz emblem in a gold setting; beside it "Веста", under it "Сонцекута" in warm gold. Top-right: one round cream button, fine gold ring, picture-frame glyph.
- Bottom sheet (bottom 48%), its top edge one arched gold hairline with a crystal keystone:
  - Tabs: "Атрибути" active (bold slate, short gold underline), then "Навички", "Спорядження", "Зірки" in taupe; full-width hairline below.
  - Left: "Рівень" small over large "23" and "/ 30". Right: "Сила" small over "12 480".
  - Thin amber XP bar, 62% full, with "1 480 / 2 400".
  - Five rows: small line glyph in a thin gold ring, label left, value right-aligned: heart "Здоров’я" "74,3"; blade "Шкода" "8,07"; double chevron "Швидкість атаки" "1,5 / с"; target "Дальність" "12"; sunburst "Заряд ульти" "+22%".
  - Bottom centre, the only loud element: luminous gold-amber jewel button, fine rim, cut topaz in a gold bezel at its left; "ПОКРАЩИТИ" white, soft shadow only; under it a tiny coin and "1 260".
- Generous margins; one right-aligned value column.

AVOID
Boxes, tiles, zebra stripes or grid lines behind stats; thick borders; outlined, stroked or bubbly text; chibi, big head, plastic skin; dark or space stage; chunky bevels, pills; emoji icons, repeated icons; stars, sparkles, red dots; English text, misspellings, deformed hands, two glaives.
```

**Check these strings in the result:** «Веста» · «Сонцекута» · «Атрибути» · «Навички» · «Спорядження» · «Зірки» ·
«Рівень» · «23» · «/ 30» · «Сила» · «12 480» · «1 480 / 2 400» · «Здоров’я» · «74,3» · «Шкода» · «8,07» ·
«Швидкість атаки» · «1,5 / с» · «Дальність» · «12» · «Заряд ульти» · «+22%» · «ПОКРАЩИТИ» · «1 260».

The stat values are Vesta at Рів. 23 (`heroes/part_ui_run.md` §2.3: Здоров’я 74,3, Шкода 8,07, Заряд ульти +22%; rate
1,5 / с and range 12 from `part_roster.md` §2.1). They use the Ukrainian decimal comma.

**Corrective follow-ups:**
- The rows came out boxed: `Remove every box and background behind the attribute rows; keep only thin gold hairlines between rows on the cream sheet. Change nothing else.`
- She looks chibi or plastic: `Re-render the heroine as a refined real-time 3D game model with realistic adult proportions (about 8 heads tall), painterly textures and a mature face like Reference 1. Keep the UI exactly.`
- The stage went dark: `Make the stage bright warm topaz gold: luminous honey-gold haze, light motes, no dark nebula. Keep everything else.`
- The button label has an outline: `Make "ПОКРАЩИТИ" and "1 260" deep warm brown #5A3410 with no outline, no stroke and no glow. Change nothing else.`

---

## 4. Portal v2 (complete prompt)

This replaces `fusion_genshin_afkj.md` §7 Prompt 3 for the owner. The v1 content (the ×10 «Tell» moment, the ring, the
seeds, the pity bars, the dock) and the v2 finish are merged into one prompt.

### Налаштування (для власника)

- Google AI Studio → **Nano Banana Pro**, **9:16**, **4K** (мінімум 1440×2560), новий чат.
- **Reference 1:** `heroes/vesta_gemini.jpg`. Лише для маленької картки «Фокус» у ряді «Хто може з’явитися».
  `moodboard_fusion.png` не прикріплюйте.
- Це момент «Tell» призову ×10: десять насінин-кристалів уже світяться своїм самоцвітом, найяскравіша — одна топазова.
  Небо — світлі сутінки (єдиний «темніший» екран, як і домовлено), але панелі світлі.
- Ціни показано маяками, а не грошима: випадкові призови лише за зароблену валюту.
- Зробіть 3–4 варіанти. Збережіть як `concepts/portal_v2_a.png`.

### Prompt

```
FORMAT
In-game screenshot, summoning portal screen of a premium fantasy RPG, mid ten-summon reveal; portrait 9:16, 4K; no frame or watermark. Render quoted strings exactly, in Ukrainian; no other text.

ART STYLE
- The ceremony polish of a top-tier anime-influenced open-world console RPG (quality only; copy no existing game, character, logo, layout or wish effect). Elegant, luminous, restrained. NOT a casual mobile game.
- Painterly 3D: volumetric light, bloom, real faceted gems with refraction.
- Quiet, minimal UI: almost-flat translucent cream, hairline gold, small gem-cut chamfers, soft shadows; no bevels.
- One clean humanist sans, small, never outlined: warm white with soft shadow on the sky, slate on cream.

CHARACTERS
Five tiny refined painted busts with adult faces: Vesta from Reference 1; a being of living white opal with an opal-shard halo; a lynx-woman mystic in an indigo hood; a fox warrior in a gold winged circlet; a mossy stone golem.

COLOR LOCK
Sky soft violet-blue #4A3A7A to rose and warm amber #F5AE45 at the horizon, never black. Gold #C9A86A. Gems: quartz #D6DEE6, sapphire #3FA9FF, amethyst #B06CFF, topaz #FFB52E, black opal #1A1530 with rainbow flecks. Cream #F7F1E6.

LAYOUT AND COMPOSITION
- The crystal bridge ends on a round crystal platform with engraved facets and gold inlay, above luminous dusk clouds.
- Centre (44% height, 72% width): the Portal, a delicate ring of fine gold filigree, never a thick band, set with five small gems: round quartz, square sapphire, triangular amethyst, pentagonal topaz, oval black opal. Inside, a slow starlight swirl.
- Ten crystal seeds arc across the ring, each glowing in its gem colour and cut: four quartz, three sapphires, two amethysts and one topaz, the brightest object, in a thin gold light pillar.
- Top: slim cream ribbon "Хто може з’явитися"; under it the five busts as small gold-framed cards on gem-gradient grounds: Vesta on gold with a tag "Фокус", opal being on dark iridescent, lynx on violet, fox on blue, golem on grey. Top-right: cream plate, beacon-lantern icon, "12".
- Below the ring: two slim cream bars of small crystal tile segments like bridge planks: "Топаз або краще ≤ 23" and "Печатки 47 / 120 → вибір героя"; a small "i" in a gold ring at the right.
- Dock: cream back tab with an arrow (left); cream button "Призов ×1" with a beacon icon and "1" below; at the right a luminous gold-amber jewel button with a cut topaz in a gold bezel at its left, "ПРИЗВАТИ ×10" white, soft shadow only, beacon icon and "10" below.
- UI only in top 22% and bottom 25%.

AVOID
Shop or purchase buttons, money prices; meteors, black silhouettes, bookmark-shaped cards; stars, sparkles, red dots; heavy dark glass, neon; outlined, stroked or bubbly text; chibi or cartoon figures; emoji icons; chunky bevels, pills; English text, misspellings.
```

**Check these strings in the result:** «Хто може з’явитися» · «Фокус» · «12» · «Топаз або краще ≤ 23» ·
«Печатки 47 / 120 → вибір героя» · «i» · «Призов ×1» · «1» · «ПРИЗВАТИ ×10» · «10».

**Corrective follow-ups:**
- The sky went black or neon: `Make the sky a luminous dusk: soft violet-blue at the top, rose and warm amber at the horizon, glowing cloud edges. Keep everything else.`
- The ring is a thick band: `Redraw the portal ring as delicate gold hairline filigree scrollwork, much finer. Keep everything else.`
- The button label has an outline: `Make "ПРИЗВАТИ ×10" and "10" deep warm brown #5A3410 with no outline, no stroke and no glow. Change nothing else.`

---

## 5. Do-not-copy reminder (from `fusion_genshin_afkj.md` §6.10)

- None of the prompts names or asks for any existing game, character, logo, menu or layout; each says "copy no
  existing game's characters, logos, icons or layouts".
- The 4-point ✦ sparkle, the dark ring "O" socket, star rows and star shapes, the curved card corner, bookmark cards, the
  meteor sky, black wish silhouettes and the Paimon tile grid are all excluded (positively by our own marks, and in
  AVOID).
- No reference image with other games' characters is attached. `moodboard_fusion.png` is dropped for that reason.
  `_work/craft_ref_v2.png` holds only UI crops (no characters) and is used only as a last-resort "finish" reference, with
  an explicit "do not copy its layout, icons, marks or text" message.

---

## Що змінив критик

1. **Довжина.** Промти мали 1 784 / 1 318 / 1 289 слів; Nano Banana Pro на такій довжині губить і змішує вказівки.
   Тепер кожен промт має близько 450 слів разом із назвами розділів. Найважливіше стоїть першим: еталон якості,
   тонке оздоблення, шрифт без обведення, реалістичні пропорції. Далі персонаж, кольори, розкладка і короткий AVOID.
2. **Порядок розділів за Addendum 4:** FORMAT → ART STYLE → CHARACTER → COLOR LOCK → LAYOUT AND COMPOSITION → AVOID.
   Окремий розділ CHARACTER і COLOR LOCK тепер є в кожному промті.
3. **Прибрано піксельні координати й більшість hex-кодів.** Модель їх не виконує і може намалювати як текст. Лишилися
   відсотки висоти/ширини для ключових речей (очі, ноги, кнопка, смуги UI) і до 10 кольорів на промт.
4. **Moodboard більше не прикріплюється.** На `moodboard_fusion.png` є персонажі Genshin і AFK Journey, англійський
   текст, зірки, червоні крапки, кнопка з темним кільцем і темне тло. Це і ризик копіювання чужого IP, і джерело
   «мультяшності». Палітра тепер лише в тексті.
5. **Портал — повний промт** замість списку «додайте / замініть» (порушувало правило Addendum 5). Те саме з
   запасними кроками: замість «додайте рядок до промту» тепер готові повні повідомлення для того ж чату
   (`craft_ref_v2.png`, `home_v1.jpg` як ескіз розкладки).
6. **Прибрано праймери казуального стилю:** перші слова «mobile game screen», назву шрифту M PLUS **Rounded** (штовхає
   до «бульбашкового» шрифту), слово «gacha», «friendly». Кожен промт починається з еталона «top-tier anime-influenced
   open-world console RPG» і фрази «NOT a casual mobile game».
7. **Головна ідея Genshin додана явно:** «UI тихий і мінімальний, майже пласкі напівпрозорі кремові поверхні;
   драма — у мистецтві й світлі». У v2 було забагато «ювелірних» деталей (кастові оправи, подвійні кільця, світлова
   смуга на кнопці), що знову тягнуло до важкого UI.
8. **Усунено суперечності:** «capsules» (форма пігулки) при забороні пігулок → «slim chamfered plates»; «star-cut
   topaz» при забороні зірок → «pentagonal-cut topaz with five facet rays» (зберігає наші 5 променів Топазу);
   «light sweep caught mid-way» (глянцева біла смуга) — прибрано; «treasure chest on any tab» в AVOID при скрині на
   бічній кнопці — прибрано; нецільові слова в лапках («luxe moment», «SR», «UR») — прибрано, бо модель малює все в
   лапках. Тепер у лапках лише текст, який має бути на екрані, і в кожному промті є правило «render every quoted
   string exactly, no other text».
9. **Обведення на золотих кнопках.** Білий текст на золоті модель «рятує» обведенням. Центр кнопки тепер глибший
   бурштиновий `#D9822E`, а для кожної золотої кнопки є готова підказка: темно-коричневий напис без обведення.
10. **Референс Вести — лише ідентичність.** Для Home і «Деталі» прямо сказано не брати мазок, позу і сіре тло
    `vesta_gemini.jpg`. Для сплешу — та сама поза, але тонше й світліше. Пропорції — 8 голів (Addendum 5: 7,5–8), дорослі
    риси; chibi заборонено в кожному AVOID.
11. **Home:** білий мармур замінено на теплий, кольору слонової кістки (біла броня Вести не зливається з підлогою);
    тераса описана деталями й словами «never empty»; додано підказку «The UI is chunky». Англійські слова «PLAY» і
    «HOME» прибрано з промту (модель могла написати їх на кнопці), кнопку названо «main button».
12. **Портал:** небо — світлі сутінки, «never black»; кільце — тонка філігрань; додано картку «Фокус» з Вестою
    і чотирма героями ростеру (Люмен, Мейра, Руді, Горан) на ґрунтах їхніх самоцвітів; ціни ×1 / ×10 — дворядкові,
    як «ГРАТИ / Рівень 14» і «ПОКРАЩИТИ / 1 260», з іконкою маяка; в AVOID — метеори, чорні силуети, картки-закладки,
    кнопки покупки.
13. **AVOID скорочено** до головних провалів v1 (мультяшність, обведення, chibi, емодзі, масивні кнопки, темна
    палітра, зайвий і англійський текст). Заборона копіювати чужі ігри стоїть у першому рядку ART STYLE, а «порожня
    підлога» описана позитивно в розкладці. Довгі переліки заборон самі «підказують» моделі ці предмети.
