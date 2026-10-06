# Heroes & Champions — owner decisions (2026-10-06, binding)

The owner sent `owner_reference_hero_screen.png` (a hero detail screen from another mobile game: big
painted splash art of a knight, a huge rarity mark "SR" top-left, name + title ("Leon — Fearless Knight"), two
shield badges under the name (class/faction), a "Skills" row of 3 square icons with level plates "1 / 1 / Max",
diagonal white slash cuts across a blue background, back arrow bottom-left). It is a MOOD reference only:
never reuse its names, character design, layout 1:1 or art. Owner: "I'd do something like this in our packs.
They could be new soldiers or real heroes. Rarity names we'll invent."

Answers (test-style questionnaire):

| # | Question | Owner's answer |
|---|---|---|
| 1 | What drops from packs | **Heroes + Champions.** Rare HEROES (lead the run, ult + skills) and more frequent CHAMPIONS (special fighters inside the crowd: archer, healer, shield-bearer…) |
| 2 | Collected characters per run | **1 hero + 2–3 champions** (champion slots; synergies; pre-run decision) |
| 3 | Rarity tiers | **5 tiers. A weaker character CAN be ascended to a higher tier, but it must never reach the strength, skills and ults of characters that are NATIVELY of that tier.** (owner's own wording — a hard design rule) |
| 4 | Rarity names | **Gemstones: Кварц · Сапфір · Аметист · Топаз · Опал** (Quartz · Sapphire · Amethyst · Topaz · Opal). A large cut-gem emblem replaces letter codes like "SR". |
| 5 | Money | **Random only from play.** Random packs/summons are earned only; money buys only deterministic bundles with known contents (a specific hero, skin, shards). Keeps us outside paid-loot-box rules. |
| 6 | Duplicates | **Shards → stars → gem ascension.** Duplicates convert to shards; shards raise stars (power, skill level caps); at max stars, ascension to the next gem — with the ceiling below native characters (answer 3). |
| 7 | Guarantee | **Pity + choice.** Topaz+ guaranteed by the N-th summon (visible bar) AND every summon gives a "Seal" (Печатка); accumulated Seals let you pick a specific hero. |
| 8 | Where they come from | **Portal + Chests.** A Summoning Portal for heroes (own earned currency, ×1 / ×10) and Hero Chests from wins for champions and shards. Existing Caches stay for machines. |
| 9 | Skills | **3 skills + an awakened 4th at high stars.** Ult (button), Attack (how the hero fights), Leader (army/machine bonus); 4th "Awakened" opens at high stars. All upgrade to Max. |
| 10 | Synergy systems | **Class + Element + Faction** (all three; deepest combinatorics — must still be readable for newcomers). Element = the machine families. |
| 11 | What upgrades on a hero (multi) | **Level (coins) · Stars & gem (shards) · Skill ranks (separate resource) · Gear / relics** — all four. |
| 12 | Existing heroes (Bolt the thunder fox, Titan the emerald stone guardian, Seer the lynx mystic) | **Starters in the collection.** They get gem, class, element, faction and skills under the new system; still unlocked by progression; their shards also drop from packs. |
| 13 | Presentation | **2D splash + live 3D.** Owner generates a big portrait 2D splash per hero (cards, reveals, detail screen); the Meshy model (built from it) runs in the run and turns on a "Details" view. |
| 14 | Champions in the run | **Squad commanders.** Each champion runs inside the crowd (bigger, with an aura) and acts on its own: archer shoots, healer returns fallen soldiers, shield-bearer takes a blade hit; nearby soldiers get stronger. Losing a champion hurts. |
| 15 | Reveal | **Cinematic for rare ones.** Quartz/Sapphire 1–2 s; Amethyst+ light pillar in gem colour, crystal shatters, hero steps out in a pose, emblem + name + title fly in. Always skippable. |
| 16 | Roster for first release | **10 heroes + 12 champions** (2 heroes per gem; cover all classes and factions; then +1–2 heroes per update). |
| 17 | Who they are | **Mix of humans, beasts and creatures** (knights/mages as humans, beast warriors like the fox and lynx, stone/crystal beings). |
| 18 | Names | **Name + title.** Short name readable in both Ukrainian and English (e.g. Vesta, Ragnar, Arin) + a translatable title ("Безстрашний лицар / Fearless Knight"). |
| 19 | Gear source | **Forge + trophies.** Materials drop in runs and from bosses; in the Forge you craft a specific item and know exactly what you get; bosses also drop ready trophies of their set. Little randomness, much control. |
| 20 | When | **Design now, code after APK 2.1.** Full design doc + Meshy/2D prompts for 10 heroes and 12 champions now so the owner can start generating; implementation starts after APK 2.1 and the menu style choice. |

Standing owner preferences: "важкий люкс" (heavy luxe) — beauty and depth first, optimise later; lots to upgrade;
references from other genres too; the owner dislikes UI that looks like every other AI-made game (generic pill
buttons, generic fonts) — a signature look is being chosen now (directions A «Ювелірна майстерня» / B
«Кришталева кузня» / C «Емаль і золото», see ../ui_direction_research.md); uk first, en second.

## Addendum — owner's second reference and key insight (binding)

Second mood reference: `owner_reference_hero_screen_2.png` (same other game): a TOP-tier hero screen, "UR", a historical
figure as a heroine ("Flame of Faith"), warm gold/orange full-screen wash (the first reference, an "SR" hero, was blue), 4 skills
(one at "Max") where the SR hero had 3. Mood only — never reuse the character, name or art.

Owner's words: "The game itself can't carry heavy luxe everywhere, but moments like this add a lot to that feeling."
=> Design rule: **invest disproportionately in PEAK "luxe moments"** (peak–end rule): the hero detail screen, the Portal
reveal, the splash art itself, ascension, first-time walkouts, squad-ready, victory with the hero. These must feel like a
premium gacha at its best, even if the run stays a clean readable arcade.

What reads as "luxe" in the references (use, in our own gem language):
- The whole screen is washed in the RARITY colour (blue for the mid tier, warm gold for the top tier): our gem colour drives the
  full-screen background, light and particles (Сапфір blue, Аметист violet, Топаз gold, Опал iridescent).
- Higher rarity visibly has MORE: the 4th skill slot, richer background, more particles — rarity is felt, not only labelled.
- Splash art density: semi-realistic painterly faces, wind-blown hair/cloth, dynamic foreshortened pose (weapon pointing at the
  viewer), strong rim light, the character breaking out of the frame, big readable silhouette; huge bold rarity mark top-left;
  name + coloured title; two badges; skills row with level plates.

## Addendum 2 — PRE-COMMITTED characters (the owner is generating their art NOW; binding for the roster)

Prompts already handed to the owner: `prompts_batch1.md`. The framework/roster MUST include these with these looks
(names/titles are working names the roster designer may polish, but keep them if they fit; native gem as stated):
- Hero **Vesta / Веста — Sunforged / Сонцекута**: HUMAN woman knight-commander, copper-auburn braid, topaz-gold + white-enamel
  plate with sunburst engravings, crimson-orange half-cape, glaive whose blade is one faceted blazing topaz crystal. Native **Topaz**.
  Suggested class Warrior, element Plasma (sun-fire). (Deliberately NOT a banner/fleur-de-lis heroine — no resemblance to the reference.)
- Hero **Lumen / Люмен — The Living Opal / Живий Опал**: CREATURE, a tall slender celestial being of living white opal with rainbow
  fire inside, halo-crown of floating opal shards, translucent starlight robes, casts through a prism that splits light. Native **Opal**.
  Suggested class Mage, element Rune (or Plasma — framework decides).
- Champion **owl archer**: BEAST, anthropomorphic snowy owl ranger with a crystal longbow (sapphire-blue crystal), white/silver plumage.
- Champion **healer**: HUMAN young field alchemist-priestess with a lantern of healing crystal light (soft green-gold), satchel of vials.
- Champion **tortoise shield-bearer**: BEAST/CREATURE, sturdy tortoise-folk guardian whose shell grows into a crystal fortress, carries a
  huge tower shield — the "takes the blade hit" commander.
Also handed over: Summoning Portal and Hero Chest (Meshy) prompts, and 2D splash prompts for the 3 existing heroes (Bolt, Titan, Seer)
matching their current 3D models (Bolt: orange-red fox, gold winged circlet with cyan gem, crimson armour; Titan: grey stone golem, moss
shoulders, emerald crystals and glowing green veins, amber eyes; Seer: dark-furred lynx woman, indigo-violet hooded cape, violet eyes).
Pipeline agreed for splash art: character on a PLAIN FLAT light-grey background (we cut it out and draw the gem-coloured background,
light and particles in-engine), portrait 9:16, character in the right 2/3 with the top-left kept clear for the gem emblem + name.

## Addendum 3 — first splash tests (Vesta), style direction
Two generations of Vesta: Higgsfield (`vesta_v1.png`: semi-realistic painterly, gorgeous face, but teal gems + green/rainbow
sword = wrong gem language, sword not glaive) and Gemini (`vesta_gemini.jpg`: on-brief — topaz-gold crystals, glaive, scar, braid,
diagonal action pose with a free top-left corner; stylised hand-painted game-art look that matches our stylised 3D models and
can stay consistent for beasts/creatures; only 572x1024 — must be regenerated/upscaled to >= 1152x2048).
Recommended (pending owner confirmation): the Gemini look is the STYLE REFERENCE for all 22 characters (attach it to every
splash prompt: "in the same art style as the reference image"). Mocks: `vesta_mocks_pair.png`. Rule learned: every splash prompt
must lock the crystal colour to the native gem ("all crystals and gems are <gem colour>, no other gem colours").

## Addendum 4 — prompt format (owner request, binding for EVERY future prompt)
Owner confirmed the Gemini Vesta as the style reference. Every prompt handed to the owner must be a full, self-contained
structured prompt with explicit technical data, in these sections: FORMAT (aspect ratio; resolution in px, e.g. splash 9:16
2160x3840, never below 1440x2560; Meshy sheet 1:1 2048x2048; card art 3:4 1536x2048; icons 1:1 1024x1024; background exactly
flat #BFBFBF), ART STYLE (same as the attached style reference), CHARACTER (all identity details), COLOR LOCK (native gem colour
for all crystals, explicit forbidden colours), POSE & COMPOSITION (framing, safe zone: top-left 40% x 40% empty for emblem/name,
face height, what may overlap), AVOID list, plus a Ukrainian note with tool settings (aspect/quality fields, reference image,
variations, download the ORIGINAL full-size file, minimum size check) and the Meshy settings + animation list for 3D.
Template: `prompts_vesta_v2.md`.

## Addendum 5 — art style calibration after the first home concept (binding, supersedes earlier style notes)
UI/art direction is now "Genshin Impact x AFK Journey, MUCH closer to Genshin" (see ../uiref/fusion/OWNER_DECISIONS.md and
../fusion_genshin_afkj.md). The owner rejected the casual-cartoon drift of the first home concept (thick outlines, chibi heroine,
emoji icons). Consequences for heroes/champions:
- 3D PROPORTIONS: REALISTIC like the painted splash (adult heroic anatomy, about 7.5-8 heads tall), NOT chibi and NOT "slightly
  large head". Applies to heroes in the run, on the home stage and in the 3D "Деталі" view. Meshy character-sheet prompts must say
  "realistic adult proportions, about 7.5 heads tall".
- 2D SPLASH STYLE: elegant semi-realistic painterly fantasy illustration leaning toward Genshin's refined anime-influenced key art
  (clean refined faces, luminous soft lighting, delicate ornament), keeping our gem colour lock and crisp edges. No thick outlines,
  no cartoon proportions.
- Existing heroes (Bolt fox, Titan, Seer lynx) and the chibi crowd soldiers will need remakes in realistic proportions to stay
  consistent — flag it in the art production plan as a decision for the owner (do not silently drop them).
- Owner decision on remakes: REMAKE ONLY THE HEROES (Bolt fox, Titan, Seer lynx) in realistic proportions; the crowd soldiers stay
  chibi (they are tiny and shown by the hundred, so the camera barely shows their proportions).
- Owner rule (binding for every prompt from now on): always hand over the COMPLETE prompt text with all changes already merged in;
  never send "replace this block / add this line" patch instructions.
