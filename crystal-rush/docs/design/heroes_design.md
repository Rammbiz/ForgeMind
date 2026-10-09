# Кришталевий Ривок / Crystal Rush — Heroes & Champions: final design (v2)

Status: **implementation-ready design**, written after the two critic passes; code starts after APK 2.1 (decision 20).
Merges `framework.md`, `part_systems.md` (S), `part_roster.md` (R), `part_ui_run.md` (U), `research_*.md` and
`audit.md`, with every blocker and major finding of `critique_economy.md` / `critique_experience.md` applied
(`decision_log.md` lists all 45). Consistent with `arsenal_design.md` (two-track rule, fairness checklist, no
limited-time anything) except where §1.4 lists an owner-level change.

Numbers: every table marked *(sim)* is pasted from `heroes/heroes_sim.py` v2 (`heroes_sim_output.txt`, 80 seeds,
`PYTHONHASHSEED=0`, exit 0) or `heroes/heroes_tables.py` (`heroes_tables_output.txt`), both reading one constant set
exported to `heroes/heroes_consts.json`. Display names are uk first, then en. Part U remains the pixel-level appendix for
layouts (§9).

Contents: 0 Owner summary · 1 Pillars and owner decisions · 2 Rarity and the native ceiling · 3 Hero progression ·
4 Champions · 5 Classes, elements, factions, synergies · 6 Roster (11 heroes, 15 champions) · 7 Portal, Seals, Hero
Chests, Workshop, odds, pity · 8 Economy and sim results · 9 Screens and ceremonies · 10 Run integration and performance ·
11 Onboarding and unlock pacing · 12 Save v3, data, Loc, telemetry, tests · 13 Implementation plan · 14 Art production
plan · 15 Risks and open questions.

## 0. Owner summary (one page, plain language)

**What you get.** 11 heroes (2 per gem Кварц → Топаз, 3 of Опал since Сірко joined) who lead the run, and 15 champions (3 per gem Кварц and Сапфір, 4 of Аметист since Снаряд joined, 5 of Топаз since Тарас and Довбуш)
who walk inside the crowd as commanders and act on their own. A team is 1 hero + 2 champions from level 14, 3 from
level 40. Руді, Горан and Мейра stay the starters (Мейра visits for one level at L5 and joins at the World 3 boss).

**How they grow.** Four separate tracks, each with its own resource, so nothing competes with your machines for coins:
level (coins, with Hero Sync), facets and gems (fragments from duplicates: 5 «Грані», then «Огранка» to the next gem),
skills (Tomes: Ult, Attack, Rally, and the fourth skill «Пробудження»), and gear (one material, «Зоряна руда», crafted
exactly in the «Майстерня» — no randomness). Champions add one shared coin track, Champion Level.

**Your rule #3 holds, and is visible.** A character raised to a higher gem never reaches a native of that gem: stats at
most 96%, one skill-rank cap lower, ult forms capped by the birth gem, Awakening one rank lower. Native Топаз and Опал
heroes are born with all four skills, so the top tier visibly has more. This is proven with the real hero kits, not only
on paper (worst case 0.98 of a native even with every tuning tolerance against us). Two small formula changes need your
yes (Q1, Q2).

**Random only from play.** The Portal costs only Маяки (Beacons), which you earn by playing; every summon gives a
Печатка (Seal) and 40 / 100 / 200 Seals buy any Аметист / Топаз / Опал hero you choose. Pity: Аметист or better by the
10th summon, Топаз or better certain by the 30th. The first free ×10 always holds a Топаз, and says so. Hero Chests
(champions) come from wins. Money buys only cosmetics at launch: no hero packs, no fragments, no Beacons. Nothing is ever
limited-time.

**Fair for free players (measured, 80 seeds × 112 levels).** Casual win rate 84%, every campaign boss ≥ 80%; a player who
ignores every random result plays at Meta-1's difficulty (79% vs 78%); lucky vs unlucky summoners differ by 1 pp;
machines stay the biggest share of power (50–52% at L60). Ceremonies take 14.2–14.5% of play time (limit 15%).
Players coming from the current save get everything the content they already played would have paid, on update day.

**When things happen (casual p50 · regular p50).** First champion: day 5 · day 2. Portal and first Топаз hero: day 7 ·
day 3. First Опал hero: day 24 · day 10. All 10 heroes: day 56 · day 30. A hero fully cut at Опал: day 63 · day 49.
Tomes no longer pile up: the cosmetic «Хроніка героя» pages absorb the surplus.

**The look.** Your Genshin × AFK Journey fusion: light cream panels, gold lines, painted portraits, M PLUS Rounded 1c,
45° cut corners (never pills), amber crystal buttons for key actions, realistic proportions for heroes and champions.
Big reveals for rare heroes (skippable from 0.5 s), small quick moments for everything frequent.

**Building it (after APK 2.1).** Six phases with test gates: foundations (save, shared rules) → data and rules → champions
in the run with placeholders and phone performance gates → hub screens → Workshop (release 1 if ready, else release 2,
nothing is lost) → art waves. A character enters the Portal and chests only when its art is complete.

**What you do.** Art in four waves in the order players meet characters (≈ 220 images, 19 Meshy characters,
≈ 75–105 h in total); prompts come next in `heroes_prompts.md`. Answer the 11 questions in §15.2 (defaults are already
in place).

## 1. Pillars and the owner's decisions

### 1.1 Pillars (every later section obeys these)

| # | Pillar | What it means in numbers / rules |
|---|---|---|
| P1 | **Rarity is felt, the ceiling is honest** (decision 3, addendum 1) | A recut character never reaches a native of its current gem: stats ≤ 0.96×, rank cap −1, ult forms capped by the native gem, Awakening cap −1 — at equal AND at max investment, with real kits (§2). Native Amethyst / Topaz / Opal heroes show four skills the moment they arrive. |
| P2 | **Random only from play** (decision 5, arsenal two-track rule) | Beacons, Seals, Hero Chests, Tomes, fragments-from-random and pity are earned only. At launch money buys **cosmetics only** (skins, champion skins, Portal themes); no hero SKU, no Hero Edition, no fragment SKU. No Feat, Track node or Road node pays Beacons (§7.3). |
| P3 | **Machines stay the backbone** (arsenal pillar) | Machines ≥ 50% of power growth at L60 for every archetype and the largest share at L112; hero axes spend their own resources, never coins (skills = Tomes, recut = fragments, Workshop = Star Ore); mean machine level at L112 ≈ Meta-1's (§8). |
| P4 | **The free floor is today's game** | Level difficulty is re-baked once (`TEAM_DEMAND`) on the EXPECTED profile (starters + the welcome Topaz + two scripted champions); a player who ignores every random result plays ≈ Meta-1's difficulty (casual win 79% vs Meta-1's 78%); luck is upside (≤ 8 pp), the luck gap ≤ 6 pp (§8). |
| P5 | **Heavy luxe at the peaks, a clean arcade in the run** (addendum 1, peak–end) | Walkouts, the Showcase, Recut, Full facets, Awakening, team-ready and victory-with-the-hero get the budget; frequent moments are micro; ceremonies ≤ 15% of session time (measured 14.2–14.5%). The run keeps the gate rows readable (§10.2). |
| P6 | **No limited-time anything** | One permanent Portal, player-chosen Focus, no banners, dates, timers or "last chance"; new heroes join the permanent pool; odds changes are listed in the changelog. |
| P7 | **Readable for a newcomer** (decision 10) | Progressive disclosure: one new idea per unlock; locked axes are hidden until 2 levels before they open; a one-line synergy mode until the Portal; a 5-row «Довідник / Codex» (§11.3). |
| P8 | **One source of truth** | Every number lives in `Ladder` / `HeroData.PROGRESS` / `TeamData` / `PortalData` / `GearData` / `CeremonyData`, exported to JSON; this doc's tables are generated from `heroes_sim.py` v2 + `heroes_tables.py`; UI copy never contains a literal percentage (§12.4). |

### 1.2 The owner's 20 decisions + 5 addenda — where each one lives

| # | Owner decision (decisions.md) | Implemented as | § | Status |
|---|---|---|---|---|
| 1 | Heroes + Champions from packs | 11 heroes (Portal) + 15 champions (Hero Chests; the roster in §6.0) | 4, 6, 7 | ✓ |
| 2 | 1 hero + 2–3 champions per run | «Команда / Team»: 2 slots from L14, 3rd at the World 5 boss (L40) | 4.1, 11 | ✓ (unlock L18 → L14, critic M7) |
| 3 | 5 tiers; ascended never reaches natives | four brakes + real-kit parity tests; F-CAP and F-AWK2 change two FROZEN formulas | 2 | ✓ **owner sign-off needed** for F-CAP / F-AWK2 (§15 Q1–Q2) |
| 4 | Gem names, big cut-gem emblem | Кварц · Сапфір · Аметист · Топаз · Опал, Living Gem emblem, 5 colour-blind channels | 2.1 | ✓ |
| 5 | Random only from play; money = deterministic | earned-only rollers; launch shop = cosmetics only (no hero SKUs, no Editions) | 7.7 | ✓ (stricter than decision 5 allows; §15 Q4) |
| 6 | Shards → stars → gem ascension | Фрагменти → **Грані** (5 per gem) → **Огранка** (recut); stars stay reserved for star-shards | 3.2 | ✓ (naming: §15 Q6 — your UI answer used «Зірки») |
| 7 | Pity + choice | Amethyst+ by the 10th, Topaz+ soft 21 / hard 30, Seals 40 / 100 / 200, welcome ×10 «щонайменше Топаз» | 7 | ✓ |
| 8 | Portal + Chests; Caches stay for machines | Portal (Beacons), Hero Chest / Grand Hero Chest; Caches untouched | 7 | ✓ |
| 9 | 3 skills + an awakened 4th at high stars | Ульта · Атака · Клич + Пробудження; every recut opens it at Full facets in Amethyst+; **native Amethyst / Topaz / Opal are born awakened** (rarity visibly has more, addendum 1; Amethyst added at the H1 gate, F-AWK3) | 3.3 | ✓ (F-AWK2, §15 Q2) |
| 10 | Class + Element + Faction, readable | 5 classes · 6 elements (= machine families) · 4 factions; progressive disclosure | 5, 11.3 | ✓ |
| 11 | Level · stars & gem · skill ranks · gear | coins · fragments · Tomes · Star Ore (each axis its own resource) | 3 | ✓ |
| 12 | Bolt, Titan, Seer are starters | Руді (Sapphire), Горан (Quartz), Мейра (Amethyst); Seer guest level at L5, joins at the World 3 boss (L24) | 6, 11 | ✓ (§15 Q7) |
| 13 | 2D splash + live 3D | layered splash (cutout + rig + fx masks) on the Showcase; «Деталі» = live 3D on a gem stage + cream sheet | 9.3 | ✓ |
| 14 | Champions = squad commanders | own clip characters in the crowd, act on their own, aura on nearby soldiers, can fall | 4.2, 10 | ✓ (Mage aura now lifts soldiers too) |
| 15 | Cinematic reveal for rare ones, skippable | Q 1.2 s · S 1.8 s · Amethyst / Topaz / Opal walkouts 0.6 + 2.6 / 3.6 / 5.0 s, skippable from 0.5 s | 9.4 | ✓ |
| 16 | 10 heroes + 12 champions | 2 heroes per gem, 3 champions per gem Quartz–Topaz; + C23 Тарас (Topaz), C24 Снаряд (Amethyst), C25 Довбуш (Topaz) and the 11th hero H26 Сірко (Opal), owner requests 2026-10-09 | 6 | ✓ |
| 17 | Humans, beasts, creatures | 10 · 8 · 8 (§6.0 coverage) | 6 | ✓ |
| 18 | Name + title, readable in uk and en | every name (26 with Тарас, Снаряд, Довбуш and Сірко); 5 titles changed after the IP / meaning review | 6.0 | ✓ (§15 Q8) |
| 19 | Forge + trophies, little randomness | «Майстерня / Workshop» (your "Forge"): craft exactly what is shown, one material «Зоряна руда», 7 boss trophies (+3 ranks from each night boss), zero randomness | 3.4 | ✓ (name: §15 Q6) |
| 20 | Design now, code after APK 2.1 + prompts now | this doc; prompts in `heroes/heroes_prompts.md` (next workflow step) | 13, 14 | ✓ |
| A1 | Second reference: top tier visibly has more | 4 skills on native Amethyst / Topaz / Opal at pull, gem-washed full screens, more particles per gem | 2, 9 | ✓ |
| A2 | Pre-committed Vesta, Lumen, owl, healer, tortoise | Веста (Topaz), Люмен (Opal), Альба, Міла, Отто | 6 | ✓ |
| A3 | Gemini Vesta = style reference; COLOR LOCK | every prompt locks crystals to the native gem | 14 | ✓ |
| A4 | Prompt format | FORMAT · ART STYLE · CHARACTER · COLOR LOCK · POSE · AVOID + uk tool note; complete text, never patches | 14 | ✓ |
| A5 | Genshin × AFK Journey, realistic proportions; remake only the 3 heroes | 3D heroes and champions at realistic adult proportions (7.5–8 heads for humanoids); crowd soldiers stay chibi; Bolt / Titan / Seer remade | 9.1, 14 | ✓ |

UI direction (binding, `../uiref/fusion/OWNER_DECISIONS.md`): **Genshin Impact × AFK Journey fusion, "much closer to
Genshin", C-bright** — light cream panels with thin gold lines, painted portraits, one rounded font (M PLUS Rounded 1c),
45° facet-chamfered corners (never pills), the amber crystal CTA for key verbs, light porcelain run HUD. §9 is written in
this direction; the older A / B / C notes of part U are superseded.

### 1.3 Glossary (final; `tools/loc_lint.py` gets these rows)

| en | uk | Code id | Meaning (one line) |
|---|---|---|---|
| Hero | Герой | `hero` | Leads the run; ult button; 4 skills. |
| Champion | Чемпіон | `champion` | Commander inside the crowd; acts on its own; can fall. |
| Team | Команда | `team` | 1 hero + 2–3 champions (never «загін»: enemy squads own it). |
| Rarity | Рідкість | `gem` | The gem tier; values Кварц … Опал (never «самоцвіт» = the Gems currency). |
| Native | Корінний | `native` (data) | The gem a character was born with; printed forever. |
| Facet / Full facets | Грань / **Повні грані** | `facets` | 0–5 per gem; 5/5 = Full facets (was «Повна огранка», renamed so it never reads as a recut). |
| Recut | Огранка (огранити) | `recut` | Promotion to the next gem; facets restart at 0, nothing drops. |
| Fragments | Фрагменти | `frags` | Per-character duplicate progress. |
| Tome | Том / Томи | `tomes` | Skill-rank resource (heroes only). |
| Star Ore | **Зоряна руда** | `ore` | The one Workshop material (replaces 4 faction materials). |
| Ultimate · Attack · Rally · Awakening | Ульта · Атака · Клич · Пробудження | `ult` `attack` `rally` `awakened` | The four hero skills. |
| Ult form | Форма ульти | `form` | I–V named after the gems; max = the NATIVE gem. |
| Champion Level | Рівень чемпіонів | `champions.level` | One shared coin track for all champions. |
| Action / Aura | Дія / Аура | `action` `aura` | A champion's own behaviour / its buff to soldiers in its ring. |
| Class · Element · Faction | Клас · Стихія · Фракція | `class` `element` `faction` | Synergy tags (element = machine family). |
| Affinity | Спорідненість | `affinity` | Team members boost fielded machines of their element. |
| Portal · Beacon · Seal | Портал · Маяк · Печатка | `summon` `beacons` `summon.seals` | Hero summoning; 1 Beacon = 1 summon; +1 Seal per summon. |
| Hero Chest / Grand Hero Chest | Скриня героїв / Велика скриня героїв | `hero_chest` `grand_hero_chest` | Win rewards: champions, hero fragments, (Grand) Tomes. |
| Focus | Фокус | `focus` | The chosen character gets exactly 60% of its gem's results. |
| Workshop | Майстерня | `workshop` | Deterministic gear crafting (your "Forge"; «кувати» stays a verb). |
| Gear · Relic · Tempering · Trophy | Спорядження · Реліквія · Гартування · Трофей | `gear` `relic` `rank` `trophies` | Weapon / Armour / Charm + a signature relic; +0…+12; boss gifts. |
| Might | **Міць** | `power` | The power index on cards (was «Сила», which collides with the in-run «Сила героя» gates). |
| Chronicle | **Хроніка героя** | `chronicle` | Cosmetic pages bought with Tomes (no power). |
| Codex | **Довідник** | `codex` | The 5-row explainer sheet behind «?». |

Meta-1 renames requested (Loc only, keys stay): `ST_SEAL` «Печать» → «Тавро / Brand» (frees «Печатка»); `MS_AWAKEN`
and "Glory ◆" retire; `HERO_UNLOCK.seer` 5 → 24 (+ a one-level guest at L5, §11.1). Machine rarity labels adopt the gem
names in the same release (recommended; §15 Q5).

### 1.4 FROZEN framework items this document changes (each needs the owner's yes; defaults below are already wired in)

| Item | Framework (v1) | This document | Why (finding) |
|---|---|---|---|
| Skill cap formula B2 | `2 + n + g + [f5]` | `SKILL_BASE[g] − [g > n] + [f5]` (F-CAP) | a recut always one cap below a native; multi-gem recuts become worth it (E06) |
| Awakening B4 | opens at Full cut in Amethyst+ for everyone | + native Amethyst / Topaz / Opal heroes are **born awakened** (F-AWK2; Amethyst added by F-AWK3 at the H1 gate) | removes the transient rule-#3 breach and the cross-facet one (a Sapphire recut to Amethyst at Full facets beat a native Amethyst at 0–3 facets, 1.0225); top tier visibly has 4 skills (E02, X01) |
| Ult power | no level term | `× lv_ult(L) = 1 + 0.036 (L − 1)` | no-loss migration of Meta-1 Ult Rank II–IV (S CI-1) |
| Clash damage | `ceil(hit × 0.25)` per tick | fractional accumulator | champions would lose ≥ 14 HP/s (X10) |
| Aura share | measured from soldier positions | fixed per slot (front 0.35 · side 0.30 · rear 0.25) | LevelSim has no positions (X09) |
| Unlocks | champions L18 · Portal L22 | champions **L14** · Portal **L20** | time-to-fun (E10) |
| Feats | F-61/62/66 pay Beacons | every hero Feat pays Tomes | money → Beacons leak (E01) |
| Materials | 4 faction materials | one «Зоряна руда / Star Ore» | currency count (E11) |
| Focus | "40% to Focus" | Focus character = exactly **60%** of its gem | disclosure (E04, X18) |
| Coins in hero axes | skills, recut, Workshop cost coins | none (coins stay for machines, Barracks, Tactics, hero levels, Champion Level) | machines crowd-out (E07) |

## 2. Rarity and the native ceiling (owner rule #3)

> Decision 3: "A weaker character CAN be ascended to a higher tier, but it must never reach the strength, skills and
> ults of characters that are NATIVELY of that tier."

### 2.1 The five gems (keys C R E L M = the Meta-1 rarity enum; one ladder for machines and characters)

| Key | uk / en | UI hex | Emblem body | Cut (colour-blind code) | Setting · prongs | Full-screen fracture pattern | Note | Haptic | Ceremony (max) |
|---|---|---|---|---|---|---|---|---|---|
| C | Кварц / Quartz | `#D6DEE6` | `#D6DEE6` | round (rose dome) | brushed steel · 4 claws | parallel planes 60° / 120° | C6 1046.5 Hz | none | 1.2 s |
| R | Сапфір / Sapphire | `#3FA9FF` | `#3FA9FF` | square (Asscher) | white gold · 4 double claws | square grid tilted 12° | E6 1318.5 | TICK 0.5 | 1.8 s |
| E | Аметист / Amethyst | `#B06CFF` | `#7A35D6` (deutan fix) | triangle (trillion) | yellow gold · 3 V-prongs | triangles 30 / 90 / 150° | G6 1568.0 | CLICK 0.7 ×2 | 0.6 + 2.6 s |
| L | Топаз / Topaz | `#FFB52E` | `#FFB52E` | star (5-point) | gold filigree · 5 prongs | 5 rays at 72° | B6 1975.5 | THUD 1.0 + CLICK ×2 | 0.6 + 3.6 s |
| M | Опал / Opal | hue-cycle 10 s | black opal `#1A1530` + play-of-colour | eye (marquise cabochon) | gold + 12-diamond halo | conchoidal arcs | D7 2349.3 | 3 pulses + LOW_TICK | 0.6 + 5.0 s |

Five redundant channels on every emblem ≥ 48 px (FROZEN): cut silhouette · setting metal + prong count · fracture pattern ·
engraved gem name · lightness ladder (L* 88 / 79 / 67 / 40.5 / 8.7). Minimum pairwise ΔE2000 of the emblem bodies 22.1
(deutan) — research_presentation §5.

**Doublet emblem (rule #3 made visible):** a recut character's stone = crown in the CURRENT gem, pavilion in the NATIVE
gem, a 1.5 px gold seam and a 12 px chip of the native cut on the bottom prong. Every stat row and skill plate of a recut
character prints its native ceiling («Ранг 9 — лише для корінних Топазів»). No ceiling is ever hidden.

**Run palette rule:** gem hues never mark a character in the run (white-gold `#FFE7A3` ring + class glyph + one 10 px gem
pip); and the run material **neutralises the crystal region of every model** (fx mask G: −70% saturation, lifted toward
ice-white `#EAF4FF`) except while that character's ult or special plays, because COLOR LOCK paints gem hues into the
albedo and Topaz sits at ΔE 2.4 from the power gate (§10.2).

### 2.2 The four brakes (final formulas; constants from `heroes_sim.py` v2 → `heroes_consts.json`)

```
B1 stats   ladder(n, g, f) = NATIVE_MULT[n] × RECUT_STEP^(g − n) × (1 + a·f)
           NATIVE_MULT[i] = q^i, q = 1.08 → [1.000, 1.080, 1.1664, 1.2597, 1.3605]
           a = FACET_STEP = 0.0073 (+0.73% per facet)   RECUT_STEP = 1 + 5a = 1.0365
           check (FROZEN): 1 + 5a = 1.0365 ≤ CEILING × q = 0.96 × 1.08 = 1.0368 ✓  → recut/native = 0.9597 per gem climbed
B2 skills  skill_cap(n, g, f) = SKILL_BASE[g] − [g > n] + [f == 5]      SKILL_BASE = [2, 4, 6, 8, 10]      (F-CAP)
           → a recut is always exactly ONE rank cap below a native of its current gem
B3 ults    ult_form(n, rank) = min(n + 1, #{FORM_AT_RANK ≤ rank}),  FORM_AT_RANK = [1, 3, 5, 7, 9]  (max form = native gem)
B4 4th     can_awaken(n, g, f) = g ≥ Аметист and (f == 5  or  (g == n and n ≥ Аметист))                   (F-AWK2/3)
           awaken_cap(n, g) = AWAKEN_CAP[g] − [g > n],  AWAKEN_CAP = {Аметист 2, Топаз 3, Опал 4}
           native Amethyst / Topaz / Opal heroes are obtained with Awakening rank 1 already open
Champions  same B1; Action tier = native + 1 (I…IV), fixed at birth; champion recut stops at Topaz
```

The ladder multiplies hero damage, hero HP, ult effect and Rally value (champions: HP, Action power, Aura value). It never
multiplies rates, ranges, radii, cooldowns or counts (kit identity).

**Caps, forms and Awakening by (native → current gem)** *(sim §1b; "cap f0/f5")*:

| native \ current | Кварц | Сапфір | Аметист | Топаз | Опал |
|---|---|---|---|---|---|
| Кварц | 2/3 · I · — | 3/4 · I · — | 5/6 · I · 1 | 7/8 · I · 2 | 9/10 · I · 3 |
| Сапфір | | 4/5 · II · — | 5/6 · II · 1 | 7/8 · II · 2 | 9/10 · II · 3 |
| Аметист | | | 6/7 · III · 2 (born) | 7/8 · III · 2 | 9/10 · III · 3 |
| Топаз | | | | 8/9 · IV · 3 (born) | 9/10 · IV · 3 |
| Опал | | | | | 10/11 · V · 4 (born) |

Every off-diagonal cell is strictly below the diagonal of its column in all three numbers.

**Stat ladder ratio** *(sim §1a)*: recut ÷ native of the same gem and facet = 0.960 (one gem climbed) · 0.921 (two) ·
0.884 (three) · 0.848 (Quartz → Opal), identical at every facet.

### 2.3 Rule #3 proven on the full power index *(sim §1c, §1e)*

`HeroesMeta.power` (shown ×1000 as «Міць»): 1.000 = the Meta-1 hero at Lv1. eq = equal investment (same level, facets,
ranks both may hold, same Awakening rank, same full gear); max = each at f5 with every cap of its own.

| Path | Lv | eq f0 | eq f5 | native max | recut max | ratio max |
|---|---|---|---|---|---|---|
| Кварц → Сапфір | 1 / 30 | 0.950 / 0.949 | 0.950 / 0.948 | 1.698 / 4.061 | 1.580 / 3.764 | 0.931 / 0.927 |
| Кварц → Аметист | 1 / 30 | 0.903 / 0.899 | 0.902 / 0.899 | 2.097 / 5.040 | 1.785 / 4.268 | 0.852 / 0.847 |
| Кварц → Топаз | 1 / 30 | 0.857 / 0.852 | 0.856 / 0.852 | 2.482 / 5.995 | 1.998 / 4.795 | 0.805 / 0.800 |
| Кварц → Опал | 1 / 30 | 0.813 / 0.807 | 0.812 / 0.806 | 2.914 / 7.075 | 2.243 / 5.397 | 0.770 / 0.763 |
| Сапфір → Аметист | 1 / 30 | 0.950 / 0.948 | 0.950 / 0.948 | 2.097 / 5.040 | 1.880 / 4.501 | 0.897 / 0.893 |
| Сапфір → Топаз | 1 / 30 | 0.902 / 0.899 | 0.902 / 0.899 | 2.482 / 5.995 | 2.105 / 5.059 | 0.848 / 0.844 |
| Сапфір → Опал | 1 / 30 | 0.856 / 0.852 | 0.856 / 0.851 | 2.914 / 7.075 | 2.363 / 5.697 | 0.811 / 0.805 |
| Аметист → Топаз | 1 / 30 | 0.950 / 0.948 | 0.950 / 0.948 | 2.482 / 5.995 | 2.216 / 5.338 | 0.893 / 0.890 |
| Аметист → Опал | 1 / 30 | 0.902 / 0.899 | 0.902 / 0.898 | 2.914 / 7.075 | 2.489 / 6.012 | 0.854 / 0.850 |
| Топаз → Опал | 1 / 30 | 0.950 / 0.948 | 0.950 / 0.948 | 2.914 / 7.075 | 2.622 / 6.344 | 0.900 / 0.897 |

Measured over every path, f 0–5, Lv 1 / 10 / 20 / 30: **worst equal-investment 0.9504, worst max-investment 0.9306,
transient case 0.9504** (F-AWK2 removes it: a native Amethyst / Topaz / Opal always holds at least the Awakening ranks
a recut can hold). **Across facet counts** (H1 gate, F-AWK3): a recut at any facet count with every cap of its own stays
below a native of its gem at any facet count, worst 0.9849 (native at its own caps or at the recut's ranks); with
Awakening born only from Topaz, a Sapphire recut to Amethyst at Full facets beat a native Amethyst at 0–3 facets
(1.0225 at Lv30), because the f5-vs-f0 ladder gap (0.9947) is smaller than one Awakening rank (`test_rule3_cross_facet`). Champions (n < g ≤ Topaz, Champion Lv
1 / 10 / 20, relic +12): worst 0.9254, and the recut keeps its lower Action tier.

**With real kits (critique B2).** The index above is kit-blind. Real kits differ, so the binding test is a **kit profile
tolerance**: at every reference state (Lv1 rank 1 f0; each Attack beat reached; each ult form; each Awakening rank; relic
+4 / +8 / +12) LevelSim's measured index of every hero lies within **±1.5%** of the kit-blind P0 index at that state
(`HeroData.KIT_INDEX[id][state]`, `test_kit_budget`). Adversarial worst case (the recut hero's profile at +1.5%, the
native's at −1.5%): **equal investment 0.9797, max investment 0.9589 — rule #3 holds with ≥ 2% margin**. Without the
profile check, per-item bands stacking the wrong way could reach 1.056, which is why each item has a design band AND the
whole profile is measured:

| Item | Design value (index) | Band (LevelSim) | Applies to |
|---|---|---|---|
| Ult rank | +5% ult effect / rank | exact (data) | all heroes |
| Attack rank | +1% hero damage / rank | exact (data) | all heroes |
| Rally rank | +10% of the hook base / rank | exact (data) | all heroes |
| Attack beat (ranks 3 / 6 / 9) | +1.0% hero index | ±0.3 pp | class template + hero twist |
| Ult form II–IV | +3.0% ult effectiveness | ±0.5 pp | rules, never a numeric step |
| Ult form V (Opal) | +5.0% ult effectiveness | ±0.5 pp | finale + second element |
| Awakening rank | +4.0% hero index / rank | ±0.5 pp | team-only rules measured by the team delta |
| Hero relic beat (+4 / +8 / +12) | +3.0% | ±0.5 pp | one named modifier each |
| Rally hook base | ≈ 3 Barracks levels (§5.4 table) | ±5% (`test_rally_parity`) | one hook per hero |
| Champion kit (`ChampionData.KIT_INDEX`) | P0_c = 1.00 value / s at f0 Lv1 | ±3% | every Action tier rule +4% inside it |

Champions across classes: a recut champion is compared with the **weakest native of its current gem, any class** (Topaz
has no native Warrior or Healer). With every champion kit at ±3%: worst 0.9827 < 1.

### 2.4 What a recut is worth (F-CAP sandwich, sim §1e)

Recut value at max (Lv30, f5, every cap, full gear) sits between the natives of the gem below and the gem it reached:

| Recut path | Recut max | Native of the gem below | Native of the reached gem |
|---|---|---|---|
| Кварц → Сапфір | 3.76 | Кварц 3.55 | Сапфір 4.06 |
| Кварц → Аметист | 4.27 | Сапфір 4.06 | Аметист 5.04 |
| Кварц → Топаз | 4.79 | Аметист 5.04 | Топаз 5.99 |
| Кварц → Опал | **5.40** | Топаз 5.99 (Аметист 5.04) | Опал 7.08 |
| Сапфір → Опал | 5.70 | Топаз 5.99 | Опал 7.08 |
| Аметист → Опал | **6.01** | Топаз 5.99 | Опал 7.08 |
| Топаз → Опал | 6.34 | Топаз 5.99 | Опал 7.08 |

So "Горан to Opal" (925 fragments, no coins) ends stronger than the Amethyst Мейра at max and below a native Topaz —
worth doing, never a native. Monotone: no stat, cap or form ever drops along any path (`ladder(n,g,5) = ladder(n,g+1,0)`;
the cap at (g, 5) equals the cap at (g + 1, 0) for natives and rises by 1 for recuts).

### 2.5 Rule #3 test list (`scripts/dev/test_heroes.gd`; S may add, never remove)

1. `Ladder.check()` at load: `1 + 5a ≤ 0.96 q`; `test_rule3_stats` ∀ n < g, f: `ladder(n,g,f) ≤ 0.96 ladder(g,g,f)`.
2. `test_rule3_caps`: ∀ n < g, f: `skill_cap(n,g,f) = skill_cap(g,g,f) − 1`.
3. `test_rule3_forms`: ∀ n < g: max form of the recut < max form of the native.
4. `test_rule3_awaken`: ∀ n < g ≥ E: `awaken_cap(n,g) < awaken_cap(g,g)`; native L/M awakened at f0; `can_awaken` false
   for g < E.
5. `test_rule3_power` (real kits): every real hero recut into every higher native gem vs every real native of that gem,
   at equal and max investment, Lv 1/10/20/30, f 0–5, gear 0 / max — ratio < 1 (LevelSim `KIT_INDEX` profiles).
6. `test_monotone`: no number decreases along a ladder path.
7. `test_kit_budget`: every hero's KIT_INDEX profile within ±1.5% of P0 at every reference state; every item inside its
   band (table above).
7c. `test_champion_budget`: every champion's KIT_INDEX within ±3% of P0_c; each Action tier rule +4% ± 0.5 pp.
8. `test_no_loss_migration`: a v2 hero's damage, HP and ult power after migration ≥ its v2 numbers (sim §1d: Titan Lv5
   ×1.20 → ×1.20, Lv25 ×1.60 → ×1.96).
9. `test_rule3_equal_ranks`: ∀ n < g, ∀ f, ∀ r ≤ awaken_cap(n, g): index(recut, r) < index(native, r).
10. `test_awaken_band`: every Awakening rank of every hero = 4.0% ± 0.5 pp (team-only rules by the team win-rate delta).
11. `test_rally_parity`: every hook base within ±5% of 3 Barracks levels in LevelSim.
12. `test_gear_budget`: full gear at +12 ≤ +35% damage and ≤ +35% HP (measured +16.2% / +25.6%).
13. `test_champion_cross_class`: recut champion vs the weakest native of its current gem, any class, < 1.
14. `test_rule3_tolerance_grid`: the §1e adversarial grid stays < 1 when `Ladder` constants change (CI runs
    `heroes_sim.py --section ladder`).

## 3. Heroes: progression (level · facets & gems · skills · gear)

Four axes (decision 11), each paid with its own resource so no axis competes with machines for coins (critique M4):

| Axis | Resource | Where it comes from | What it raises |
|---|---|---|---|
| Level 1–30 | coins (Meta-1 curve) | every win | damage, HP, ult charge, ult power |
| Facets → recut (gem) | fragments of that character | duplicates, chest cards, owned Seal picks | the B1 ladder; +1 rank cap at Full facets; Awakening eligibility |
| Skill ranks | Tomes | Grand Hero Chests, bosses, weekly, Expedition, Feats, overflow | Ult / Attack / Rally / Awakening ranks |
| Gear | Star Ore | first clears, bosses, replays, weekly, Expedition | weapon / armour / charm / relic stats + named modifiers |

### 3.1 Level (coins) and Hero Sync

| Item | Value |
|---|---|
| Levels | 1–30; `EconData.hero_cost(L) = round(30·L^1.4 / 10)·10` (L1→2 30 · L10→11 750 · L29→30 3 350; 42 140 per hero) — Meta-1, unchanged |
| Cap | `6 + 3 × world_reached` (W1 9 … W7 27), 30 once the frontier passes L56 |
| Per level | +3.5% hero damage, +4% hero HP, +1% ult charge rate (Meta-1), **ult power × `lv_ult(L) = 1 + 0.036 (L − 1)`** (Lv30 ×2.04; replaces Meta-1's Ult Rank II–IV; keeps the no-loss migration, §2.5 test 8) |
| Hero Sync / Синхронізація | `eff_lvl(h) = max(own, min(cap, best_own − 3))`; levelling a synced hero pays `hero_cost(eff)` and sets `own = eff + 1`; a new hero arrives synced; label «Синхронізовано з найкращим героєм» |
| Level beats | gear slots open at hero Lv **1 / 4 / 8 / 12** (weapon / armour / charm / relic), visible only once the Workshop is open |

### 3.2 Fragments, Facets (Грані), Full facets (Повні грані), Recut (Огранка)

| `HeroData.PROGRESS` (champions reuse it) | Кварц | Сапфір | Аметист | Топаз | Опал |
|---|---|---|---|---|---|
| `DUP_FRAGS[native]` — fragments per duplicate copy | 10 | 15 | 25 | 50 | 100 |
| `FACET_FRAGS[g]` f0→1 … f4→5 | 5 · 5 · 10 · 10 · 20 | 10 · 10 · 15 · 15 · 25 | 15 · 15 · 20 · 20 · 30 | 20 · 20 · 30 · 30 · 50 | 30 · 30 · 40 · 40 · 60 |
| Full facets of the gem (sum) | 50 | 75 | 100 | 150 | 200 |
| `RECUT_FRAGS[g → g+1]` (no coins) | 40 | 60 | 100 | 150 | — |
| Chest hero-fragment card `round(0.15 × DUP)` (Grand ×2) | 2 | 2 | 4 | 8 | 15 |
| Owned Seal pick = 2 × DUP | — | — | 50 (40 Seals) | 100 (100) | 200 (200) |
| `OVERFLOW_FRAGS_PER_TOME` at the absolute max | 20 | 20 | 20 | 20 | 20 |

Totals *(sim §2)*: own-gem Full facets = 5 / 5 / 4 / 3 / 2 duplicates; a hero to Opal f5 = 925 / 835 / 700 / 500 / 200
fragments (92.5 / 55.7 / 28 / 10 / 2 duplicates); a champion to Topaz f5 = 575 / 485 / 350 / 150 fragments. No coins.

Rules:
- A copy of an owned character → `DUP_FRAGS[native]` fragments. Hero-fragment chest cards target OWNED heroes only
  (team hero weight ×2). Heroes are never unlocked by fragments.
- **Facet up** is a free tap; «+» fills every affordable pip; all facets bought in one Hall visit play ONE micro
  ceremony (0.35 s). A facet is shown as progress, not as a power jump: the pip engraves a facet line on the Living Gem,
  the card says «Грані 3 / 5 → Повні грані: +1 межа навичок», and the true value is printed once in the Facets tab
  («+0,73% до показників за грань»). No stat count-up (critique X06).
- **Full facets** (5/5): +1 rank cap on Ult, Attack and Rally; Awakening opens if the current gem is Amethyst+; recut
  becomes available. Full ceremony 1.6 s.
- **Recut**: needs f = 5 and `RECUT_FRAGS[g]`; facets restart at 0; **no number drops** (`RECUT_STEP = 1 + 5a`); the
  next Full facets adds +1 cap. Full ceremony 3.0 s. Best upgrade values "recut + every facet the banked fragments buy at
  once" (a bare recut changes no number).
- **Overflow**: fragments at the absolute max (hero Опал f5 · champion Топаз f5) become Tomes at 20 : 1 at once; every
  screen that could grant them says so first (§9.3 overflow labels).

### 3.3 Skill ranks (Tomes only)

| Rank r → r+1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 | 10→11 |
|---|---|---|---|---|---|---|---|---|---|---|
| `TOME_COST[r]` | 2 | 3 | 5 | 8 | 12 | 16 | 20 | 25 | 30 | 40 |
| cumulative to reach r+1 | 2 | 5 | 10 | 18 | 30 | 46 | 66 | 91 | 121 | 161 |

| Native (own gem, Full facets) | max rank | Tomes per skill | Tomes 3 skills | Awakening cap | Tomes Awakening |
|---|---|---|---|---|---|
| Кварц | 3 | 5 | 15 | — (recut to Amethyst) | 0 |
| Сапфір | 5 | 18 | 54 | — (recut to Amethyst) | 0 |
| Аметист | 7 | 46 | 138 | 2 | 2 |
| Топаз | 9 | 91 | 273 | 3 (born) | 5 |
| Опал | 11 | 161 | 483 | 4 (born) | 10 |

Roster at native max: 1 960 Tomes; all 10 at Opal f5 (recut caps 10): 3 930 Tomes. No coins anywhere.

| Skill | Numeric per rank | Rule content | Budget (§2.3) |
|---|---|---|---|
| Ульта / Ultimate | **+5% ult effect** | forms II–V at ranks 3 / 5 / 7 / 9, capped by the native gem; forms add RULES, never a numeric step | form +3% ult (Opal V +5%) |
| Атака / Attack | **+1% hero damage** | beats at ranks 3 / 6 / 9 (class template + hero twist); mostly utility (stagger, mark, reveal, pierce) | beat +1% index |
| Клич / Rally | **+10% of the hook base** | one hook per hero, base = S parity (§5.4) | ±5% parity |
| Пробудження / Awakening | rule per rank | every recut: opens at Full facets in Amethyst+; native Amethyst / Topaz / Opal: born with rank 1 | +4% index / rank |

- The skills unlock at L30; before that every rank is 1 except a born Awakening (and migrated Ult ranks). Free first
  step: one free Ult rank on the team hero.
- **«Переписати навички / Rewrite skills»**: on a hero that is not in the active team or a preset, every Tome spent on
  its ranks comes back (100%); ranks return to 1 (a born / opened Awakening to 1). Free, no timer; confirmation sheet
  «Повернеться: 46 томів · Ранги стануть 1». Feat F-65 counts **peak** ranks (`skills_peak{}`), so a rewrite never
  re-counts (critique B1).

**Tome income (earned only)** — cut to ≈ 0.45× of part S (Tomes were 70–77% unspent at day 180):

| Source | Tomes | Notes |
|---|---|---|
| Grand Hero Chest | 2 (fixed, after L30) | Hero Chests hold no Tomes |
| World-boss first clear | 1 | campaign + Invasion, after L30 |
| Weekly 5/5 · Expedition 5/5 | 2 · 2 | |
| Hero Feats F-61 … F-70 | 2 / 4 / 8 per tier | §3.6 |
| Overflow | 1 per 20 fragments at the absolute max | |
| Migration | 1 × world bosses passed after L30 | §12.3 |

### 3.4 Gear and the Workshop (Майстерня) — Star Ore only, zero randomness (decision 19)

**Slots:** hero = Зброя / Weapon (`dmg_add`) · Обладунок / Armour (`hp_add`) · Оберіг / Charm (`ult_add` + `charge_add`) ·
Реліквія / Relic. Champion = Relic only. **12 faction items** (4 factions × 3 slots, crafted once per account, wearable by
any hero, re-equip free) + **one relic per character** (26 with Тарас, Снаряд, Довбуш and Сірко, auto-equipped). Stats never depend on the wearer.

| Slot | Stat | base | per rank | beats +4 / +8 / +12 | +0 | +3 | +6 | +9 | +12 |
|---|---|---|---|---|---|---|---|---|---|
| Зброя | `dmg_add` | 0.010 | 0.005 | 0.01 / 0.01 / 0.02 | 1.0% | 2.5% | 5.0% | 7.5% | 11.0% |
| Обладунок | `hp_add` | 0.020 | 0.008 | 0.01 / 0.01 / 0.02 | 2.0% | 4.4% | 7.8% | 11.2% | 15.6% |
| Оберіг | `ult_add` / `charge_add` | 0.010 / 0.010 | 0.005 / 0.003 | 0.01 / 0.01 / 0.01 · 0.005 / 0.005 / 0.01 | 1.0 / 1.0% | 2.5 / 1.9% | 5.0 / 3.3% | 7.5 / 4.7% | 10.0 / 6.6% |
| Реліквія героя | `dmg_add` / `hp_add` | 0.010 / 0.020 | 0.001 / 0.0025 | three named skill modifiers (+3% index each) | 1.0 / 2.0% | | | | 2.2 / 5.0% |
| Реліквія чемпіона | HP, Action power, Aura | 0.03 | 0.01 | three named Action / Aura modifiers | 3% | 6% | 9% | 12% | 15% |

Item gem tier = rank band: +0–2 Кварц · +3–5 Сапфір · +6–8 Аметист · +9–11 Топаз · +12 Опал.
Temper cap `min(12, 2 × world_reached)`: +8 when the Workshop opens (W4), +10 in W5, +12 from W6.

**Faction sets** (2 pieces = stat; 4 pieces = 3 own-faction items + the hero's own relic = rule, ≈ +5% index):

| Faction | 2 pieces | 4 pieces |
|---|---|---|
| Орден Світанку | +3% hero damage | «Присяга / Oath»: the hero's Rally value ×1.30 |
| Дикі Ікла | +5% ult charge rate | «Зграя / Pack»: when the ult ends 20% of its charge returns |
| Кам'яне Серце | +5% hero HP | «Кам'яна шкіра / Stoneskin»: hero HP ×1.15; the first clash tick at army 0 is absorbed |
| Небожителі | +5% ult effect | «Зоряна мітка / Star Mark»: ult effect +6%, machines of the hero's element +3% (inside TEAM_B2_CAP) |

Budget check: max damage +16.2% (weapon 11 + relic 2.2 + Dawn set 3), max HP +25.6% (×1.15 with Stoneskin) — inside
the ≤ 35% / 35% rule.

**Costs (Star Ore «Зоряна руда», one material for every faction; critique m1):**

| Action | Star Ore | Ceremony |
|---|---|---|
| Craft an item (+0, exact result shown before) | 40 | 1.2 s (three strikes) |
| Craft a hero relic · a champion relic | 60 · 30 | 1.2 s |
| Temper r → r+1 (item, hero relic) | 8 + 4r | 0.35 s; tier change (+3 / +6 / +9) 1.2 s; beats (+4 / +8 / +12) 1.2 s |
| Temper r → r+1 (champion relic) | ⌈(8 + 4r) / 2⌉ | same |

To +12: item 400 Star Ore · hero relic 420 · champion relic 210; everything (12 items + 26 relics, C23–C25 and H26 included) 12 570 Star Ore.

**Star Ore income** (earned only; one pool, so ≈ 0.45× the v1 per-faction amounts):

| Source | Amount |
|---|---|
| First-clear win, campaign W1…W7 | 2 · 3 · 3 · 4 · 4 · 5 · 7 |
| First-clear win, Invasion W1…W7 | 3 · 4 · 4 · 5 · 5 · 5 · 9 |
| Replay win | 60% of the replayed world's campaign amount (fractions bank in `wallet.ore_charge`) |
| World-boss first clear | 14 (campaign) · 20 (Invasion) |
| Weekly 5/5 · Expedition 5/5 | 10 · 10 |
| Feats F-67 / F-69 | 10 / 20 / 40 Star Ore per tier |
| Retro grant at the Workshop unlock | everything the played wins and bosses would have paid + W1–W4 trophies + one free craft |

**Trophies** (`GearData.TROPHIES`, ready at +3; the night boss of the same world adds +3 ranks; past +12 the ranks
return as Star Ore): L8 `dawn_weapon` · L16 `wildfang_charm` · L24 `wildfang_weapon` · L32 `stoneheart_armour` · L40
`stoneheart_charm` · L48 `dawn_armour` · L56 `celestial_weapon` (Invasion L64…L112 temper the same items). Five items
and every relic is craft-only.

### 3.5 «Хроніка героя / Hero Chronicle» — the Tome sink with no power (critique M6 / X13)

Per owned hero, 5 pages bought with Tomes: **10 · 15 · 20 · 30 · 40** (115 per hero, 1 265 for 11, +115 per new hero):
① a lore page (the 3 lore lines + 2 new), ② a voice-line text card, ③ a splash variant frame, ④ a Showcase backdrop tint,
⑤ a gilded card back. Pure cosmetics, earned only (no firewall issue), micro ceremony 0.35 s. Opens from the Showcase dock
(a book icon next to «Деталі») and from the Hall header once the skills unlock (L30); not a fourth sub-tab (the Hall
keeps three). The sim's policy buys pages only from Tomes above a reserve of
40: regular players bank 46 of 608 Tomes at day 180 and spend 175 on 15 pages (v1: 1 262 of 1 670 banked), §8.6.

### 3.6 Hero Feats (new rows; earned copies only; F-42 Overdrive and F-49 Glory retire)

| id | Feat (uk / en) | Counter (counts only `got.via ∈ {start, progress, portal, seal, chest, migration}`) | Tiers | Reward per tier |
|---|---|---|---|---|
| F-61 | Герої в колекції / Heroes collected | heroes owned | 4 / 7 / 10 | 2 / 4 / 8 Tomes |
| F-62 | Огранки / Recuts | recuts (heroes + champions) | 1 / 6 / 20 | 2 / 4 / 8 Tomes |
| F-63 | Повні грані / Full facets | Full facets reached | 2 / 10 / 30 | 2 / 4 / 8 Tomes |
| F-64 | Чемпіони в колекції / Champions collected | champions owned | 4 / 8 / 12 | 2 / 4 / 8 Tomes |
| F-65 | Ранги навичок / Skill ranks | Σ (peak rank − 1) | 10 / 40 / 100 | 2 / 4 / 8 Tomes |
| F-66 | Пробудження / Awakenings | Awakenings opened (born ones count) | 1 / 3 / 6 | 2 / 4 / 8 Tomes |
| F-67 | Повна команда / Full-team wins | wins_full_team | 10 / 100 / 400 | 10 / 20 / 40 Star Ore |
| F-68 | Синергії / Synergies won with | distinct synergy ids | 3 / 8 / 14 | 2 / 4 / 8 Tomes |
| F-69 | Гартування +12 / Tempered to +12 | items at +12 | 1 / 4 / 12 | 10 / 20 / 40 Star Ore |
| F-70 | Рівень чемпіонів / Champion Level | champion_level | 5 / 12 / 20 | 2 / 4 / 8 Tomes |

**Hero Feats never pay Beacons and never count toward Meta-1's "every 10th tier 3 = Royal Cache"** (that counter keeps
counting machine Feats only), so no paid or coin-bought progress can reach a random reward (critique B1).

## 4. Champions (squad commanders, decision 14)

### 4.1 Model

| Aspect | Rule |
|---|---|
| Roster | 12 at launch: 3 natives each of Кварц, Сапфір, Аметист, Топаз; + C23 Тарас (Топаз), C24 Снаряд (Аметист) and C25 Довбуш (Топаз), owner requests 2026-10-09 = 15, so Аметист holds 4 and Топаз 5. Opal is hero-only. Recut stops at Топаз (`CHAMPION_MAX_GEM = "L"`). |
| Sources | Hero Chests and Grand Hero Chests (copies); the two scripted first chests. Never the Portal, never Seals, never a SKU. |
| Tracks | Facets & recut (fragments, same tables as heroes) · **Champion Level** (one shared coin track, Lv1–20, `cl(L) = 1 + 0.04 (L − 1)`, cost `round(40·L^1.5/10)·10`, 26 840 coins in total, cap `2 + 2 × world_reached`, 20 in Invasion) · **Relic** (Star Ore, +0…+12, +3% +1%/rank on HP, Action and Aura, three named modifiers). No Tomes, no gear slots. |
| Skills | **Action** (class template + the champion's twist; tier I–IV = native gem + 1, fixed at birth, a recut keeps its tier) and **Aura** (class hook; value capped at `AURA_CAP 0.40`; effect = value × the slot's fixed share). |
| Duplicates | `DUP_FRAGS[native]`; past Топаз f5 → Tomes 20 : 1. |
| Chest Focus | when every champion of a gem is owned, the Focus champion gets exactly **60%** of that gem's champion cards; the others share 40% evenly (20% each of two; 13.33% each of three in Аметист; 10% each of four in Топаз). |
| Synergy | counts fully, native-blind and gem-blind. |
| Budget (critique M2) | power weight `W_C = 0.012` per champion-index point (a native champion at f0 Lv1 ≈ 4.8% of the Lv1 hero term); expected uptime 0.94 (champions can fall); invariant **champions + synergy ≤ 12% of power growth at L60** (measured 7.7–8.6%). Every kit's `ChampionData.KIT_INDEX` = P0_c ± 3% in LevelSim (§2.3). |

### 4.2 The commander in the run (framework §5.2 with the fixes)

| Item | Contract |
|---|---|
| Render | own skinned clip character (`RunChampion`), 1.10 u tall (knights 0.60–0.80, heroes 1.35–1.45), 6–8k tris, 1 surface, ≤ 30 bones, albedo 512²; realistic adult proportions (addendum 5) |
| Slots | offsets from the blob centre, `r' = max(r, 0.6)`: front (0, −0.63 r') · left (−0.55 r', +0.1 r') · right (+0.55 r', +0.1 r') · rear (0, +0.69 r'); preferred by class (Guardian / Warrior front, Ranger / Mage rear → right, Healer left / right); conflicts → next free in front → rear → left → right |
| Crowd | each champion is a `solids` circle r 0.32; soldiers part around it; hazards vaulted like the hero; **turrets never target champions** (Німб's tier IV is a block on a shot aimed at soldiers) |
| **Aura share (fixed)** | `ChampionData.AURA_SHARE = {front 0.35, left 0.30, right 0.30, rear 0.25}` — the same numbers in Run and LevelSim (critique X09); the measured soldier share drives only the visual lift of soldiers inside the ring |
| **Clash damage (fractional)** | the front champion in contact accumulates `share_acc += hit × 0.25` per tick and loses `floor(share_acc)` HP (×0.5 with a Guardian hero); at army 0 living champions absorb clash ticks front → left → right → rear, then the hero |
| **Survival targets** (EXPECTED profile, LevelSim) | front champion survives ≥ 75% of campaign levels and 40–60% of boss levels; side / rear ≥ 90% — tune kit HP, never the rule |
| Death | permanent for the level: hit-stop 0.2 s, `fall` clip, ring shatters, HUD medallion cracks; its Action, Aura, Rally-on-champion and synergy contributions stop at once; one 0.6 s fall flourish per champion |
| Revive | only a Healer hero (Ейра form II, Пава form II / V / Awakening) at 50% HP (Пава's Awakening 30%); never a gate, ad or currency; every level starts with all members alive |
| Input | none: no tap targets; HUD medallions ignore input |
| LevelSim / bot | one `sim` row per champion through the shared `KindView` rules (§10.4); survival measured, not assumed |

### 4.3 Class templates (final numbers; Quartz-normalised; × ladder × cl × relic)

| Class | Kit HP | Action (template) | Aura (hook × fixed slot share) | Radius | Tier II | Tier III | Tier IV |
|---|---|---|---|---|---|---|---|
| Воїн / Warrior | 48 | **Cleave**: in a clash +0.07 kills per FIGHT_TICK (≈ 1.0 kill/s, fractions carry); outside clashes every 5 s leaps at a squad ≤ 3 u ahead: 3 kills | squads in contact lose +10% in clashes | 1.1 | leap 4 kills, range 4 u | the leap applies the element status | cleave hits 2 squads in contact; leap cd 4 s |
| Стрілець / Ranger | 26 | **Shot**: every 1.2 s at the PAINT target, else the nearest hostile ahead ≤ 14 u; dmg 1.0; hits Flying | army volley damage +15% | 1.4 | +1 arrow every 3rd shot | shots apply the element status (proc 0.5) | every 5th shot pierces 3 |
| Маг / Mage | 26 | **Spell**: every 4 s an area hit r 1.5 on the densest squad ≤ 12 u ahead: 4 kills per squad + element status | **soldiers in the ring apply the champion's element status with their volleys (proc 0.15)** (decision 14: nearby soldiers get stronger) | 1.2 | radius 2.0 | structures ×1.5 | cd 3.5 s + a 2 s field (1 kill / 0.5 s) |
| Страж / Guardian | 60 | **Block**: absorbs one blade / spike / barricade contact on soldiers within 1.0 u (0 losses, «БЛОК») + 1 kill on the squad behind it; cooldown 5 s; takes the front clash share | clash losses −10% | 1.0 | block radius 1.4 u | after a Block a 1.5 s front shield (next clash tick costs 0) | the blocked barricade takes 5 |
| Цілитель / Healer | 30 | **Mend**: 30% of soldiers lost feed the revive pool (cap 30 per level × power); every 3 s returns up to 3 | hazard losses −12% | 1.3 | +1 per pulse; returns land at the blob front | every 15 s cleanses a curse lane / DoT and heals the front champion 10% | pool cap +50%, pulse every 2 s |

Trims against part R (critique M2): Warrior Cleave 0.20 → 0.07 kills/tick and leap 4 → 3; Mage Spell 3 → 4 kills,
cooldown 5 → 4 s; Guardian Block cooldown 6 → 5 s + 1 kill; Healer pulse 2 → 3 soldiers. Each class lands at value
≈ 1.0 / s at f0 Lv1 (Warrior ≈ 0.3 clash + 0.4 leap + aura; Ranger 0.83 + aura; Mage 1.0–1.2; Guardian ≈ 4 soldiers
per 5 s + 0.2; Healer ≤ 1.0 pool-limited). Twists (§6.11–6.22, §6.25–6.27) are tuned inside ±3%.

### 4.4 Champion numbers by gem (generated, `heroes_tables.py` §D)

HP and Action at f0 Lv1 / Full facets Lv20 (no relic) / recut to Topaz f5 Lv20; aura value → effect at the champion's
slot share (value capped 0.40; right column with relic +12):

| Champion | Gem · class · slot | HP | Action (main number) | Aura value → effect | Tier |
|---|---|---|---|---|---|
| Міла `mila` | Кварц · Healer · left | 30 / 55 / 61 | returned per pulse 3.00 / 5.47 / 6.09 | hazard −0.120 → 3.6% / 0.252 → 7.6% | I |
| Іво `ivo` | Кварц · Guardian · front | 60 / 109 / 122 | blocked-barricade damage 3.00 / 5.47 / 6.09 | clash −0.100 → 3.5% / 0.210 → 7.3% | I |
| Борко `borko` | Кварц · Warrior · front | 48 / 88 / 98 | Undermine kills 3.00 / 5.47 / 6.09 | squad clash loss +0.100 → 3.5% / 0.210 → 7.3% | I |
| Альба `alba` | Сапфір · Ranger · rear | 28 / 51 / 55 | shot dmg (×1.5 vs Flying) 1.08 / 1.97 / 2.12 | volleys +0.162 → 4.0% / 0.340 → 8.5% | II |
| Отто `otto` | Сапфір · Guardian · front | 65 / 118 / 127 | kills per Block 1.08 / 1.97 / 2.12 (+ planted ticks 2) | clash −0.108 → 3.8% / 0.227 → 7.9% | II |
| Тая `taya` | Сапфір · Mage · rear | 28 / 51 / 55 | Spell kills per squad 4.32 / 7.88 / 8.47 | volley status proc 0.162 → 4.0% / 0.340 → 8.5% | II |
| Брант `brant` | Аметист · Warrior · front | 56 / 102 / 106 | leap kills 3.50 / 6.38 / 6.62 | squad clash loss +0.117 → 4.1% / 0.245 → 8.6% | III |
| Тео `teo` | Аметист · Ranger · rear | 30 / 55 / 57 | shot dmg (homing) 1.17 / 2.13 / 2.21 | volleys +0.175 → 4.4% / 0.367 → 9.2% | III |
| Олена `olena` | Аметист · Healer · right | 35 / 64 / 66 | returned per pulse 3.50 / 6.38 / 6.62 | hazard −0.140 → 4.2% / 0.294 → 8.8% | III |
| Снаряд `snaryad` | Аметист · Guardian · front | 70 / 128 / 132 | Sapper's Nose charge kills (per Block, every 6 s; + MARK) 2.33 / 4.26 / 4.41 | clash −0.117 → 4.1% / 0.245 → 8.6% | III |
| Німб `nimb` | Топаз · Guardian · front | 76 / 138 / — | Lightning Rod dmg ×3 targets 2.52 / 4.60 | clash −0.126 → 4.4% / 0.264 → 9.2% | IV |
| Дара `dara` | Топаз · Ranger · rear | 33 / 60 / — | shot dmg (harpoon every 3rd) 1.26 / 2.30 | volleys +0.189 → 4.7% / 0.396 → 9.9% | IV |
| Менгір `menhir` | Топаз · Mage · right | 33 / 60 / — | rune-strike kills per squad 5.04 / 9.19 | volley status proc 0.189 → 5.7% / 0.396 → 11.9% | IV |
| Тарас `taras` | Топаз · Mage · rear | 33 / 60 / — | The Word kills per squad 5.04 / 9.19 | volley status proc 0.189 → 4.7% / 0.396 → 9.9% | IV |
| Довбуш `dovbush` | Топаз · Warrior · front | 60 / 110 / — | bartka kills per squad ×2 squads (+ STAGGER) 1.89 / 3.45 | squad clash loss +0.126 → 4.4% / 0.264 → 9.2% | IV |

Max-investment ratio of a recut champion to the weakest native Topaz of any class (rule #3, cross-class): ≤ 0.983 with
every kit at ±3% (§2.3). The Champion Showcase prints the ceiling: «Ярус IV — лише для корінних Топазів».

## 5. Classes, elements, factions, synergies

### 5.1 Classes (5)

Hero kit bands are Lv1 / rank-1 shapes stored Quartz-normalised (eff = kit × NATIVE_MULT); the band check is on the
stored kit.

| id | uk / en | Glyph | Hero band (hp · rate/s · dmg · splash · range · targets) | Hero class trait (run) | Champion template | Pair bonus (2 of the class) |
|---|---|---|---|---|---|---|
| `warrior` | Воїн / Warrior | crossed blades | 24–28 · 1.4–1.8 · 3 · 2 · 11–12 · 1 | Cleave: hero hits on a squad in a clash ×1.5 | Cleave + leap | squads lose +12% in clashes |
| `ranger` | Стрілець / Ranger | bow | 12–16 · 3.0–4.0 · 1 · 0 · 15–17 · 1 | Long sight +2 u; chain / pierce at Attack rank 3 | Shot | hero attack rate +5%, Ranger champions' cooldown −15% |
| `mage` | Маг / Mage | orb in a ring | 16–20 · 1.8–2.4 · 1 · 0–1 · 14–16 · 2 | Attack applies its element status (proc 0.5) | Spell + status aura | ult effect +8% |
| `guardian` | Страж / Guardian | tower shield | 30–34 · 1.0–1.3 · 4 · 3 · 11–12 · 1 | Bulwark: at army 0 absorbs clash ticks with ×1.5 HP; champions' clash share −50% | Block | champion HP +25%, Block cooldown −20% |
| `healer` | Цілитель / Healer | lantern | 18–22 · 1.8–2.2 · 1 · 0 · 13–15 · 1 | Mend: 20% of soldiers lost feed the revive pool; **only Healer heroes revive champions** | Mend | revive pool +25%, Mend rate +20% |

### 5.2 Elements (6) = machine families; Affinity

`ELEMENTS = [kinetic, volt, frost, plasma, tech, rune]` (= `ArsenalData.FAMILY_ORDER` without Rift; display, accent, glyph
and status reuse `FAM_*`). **Affinity / Спорідненість**: fielded machines of family E get `+0.03 × living members of
element E` (bucket 2, cap +0.09); Rift machines use the best count present. Celestials + Affinity + Rally machine hooks
together add at most **`TEAM_B2_CAP = +0.20`** to one machine (critique m7; `level_check --budget` reports cap hits).
Statuses only where a kit says so; elements never form a counter wheel. Frost and Rune have no live machine before
Meta-2: the Team screen says «Мороз: машин цієї стихії поки немає». When Meta-2 machines ship, `TEAM_DEMAND` is re-baked
in the same release (Мейра's Rune affinity switches on inside the EXPECTED profile) and listed in the changelog
(critique m8).

### 5.3 Factions (4) and their home worlds

| id | uk / en | Theme | Home worlds | Tier I (2) · II (3) · III (4) |
|---|---|---|---|---|
| `dawn` | Орден Світанку / Dawn Order | knights, priests, engineers of the orbital temple and the sky harbour | W1 · W6 | +4 · +8 · +14 soldiers at the siege |
| `wildfang` | Дикі Ікла / Wildfang | beast-kin of the reef and the rune forest | W2 · W3 | +6% · +12% · +20% ult charge |
| `stoneheart` | Кам'яне Серце / Stoneheart | stone and crystal beings of the magma forge and the ice pass | W4 · W5 | −15% · −30% · −45% hazard losses |
| `celestial` | Небожителі / Celestials | star-born beings of the Rift | W7 | +3% · +6% · +10% machine damage (bucket 2) |

Only the highest tier of each faction is active; a 2 + 2 team runs two tier-I factions. Each faction has 2–4 heroes (Орден Світанку 4 since H26 Сірко: Арін, Ейра, Веста, Сірко) and
3–4 champions (Дикі Ікла 4 since C23 Тарас, Орден Світанку 4 since C24 Снаряд, Кам'яне Серце 4 since C25 Довбуш), so a mono-faction team of 4 is always possible. Faction identity lives in trophies, item looks and
set bonuses; there is one material (Star Ore).

### 5.4 Rally hooks and their parity bases (each hero uses exactly one; S's per-hook value ≈ 3 Barracks levels)

`rally.value = base × ladder(n, g, f) × (1 + 0.10 (rank − 1))`; LevelSim checks every base at ±5% (`test_rally_parity`).

| Hook | Target | Base (rank 1, Quartz-normalised) | Hero |
|---|---|---|---|
| `army_scrape` | `Army.scrape_spare()` | +3 soldiers spared per hazard contact | Горан |
| `army_drill` | `Army.drill_mult()` | +0.075 extra clash loss of squads the hero hit ≤ 2 s before | Арін |
| `machines_element` | `Weapons._b2(m)` own family | +0.03 (inside TEAM_B2_CAP) | Руді (Volt), Люмен (Plasma) |
| `champions_hp` | champion HP | ×(1 + 0.15) | Ейра |
| `ult_start` | `tactics.ult_start` | +0.10 (total `ult_start` ≤ 0.40) | Мейра |
| `machines_verb` | `Weapons._b2(m)` one verb | +0.025 LANE (inside TEAM_B2_CAP) | Іскар |
| `army_reserves` | `Army.reserves()` | +6 soldiers at the siege | Веста |
| `army_volleys` | `Army.volley_mult()` | ×(1 + 0.15) | Вартан |
| `champions_aura` | champion aura value | ×(1 + 0.06) (critique M2: was 0.12; capped by AURA_CAP) | Пава |
| `army_recruits` | `Army.recruits()` | +1 soldier per recruit group | Сірко |
| `ult_charge` | charge rate | ×1.05 | (free for future heroes) |

### 5.5 Display contract (progressive disclosure, §11.3)

- **Until the Portal opens** the Team screen shows synergy in **simple mode**: one plain line per ACTIVE bonus
  («Кам'яне Серце: −15% втрат від пасток»), no columns, no possible tags.
- **From the Portal (L20)**: the full panel — three columns Клас · Стихія · Фракція, chips «Дикі Ікла 2 / 4 ●○○», ≤ 5
  effect lines (≤ 2 faction, ≤ 2 class, 1 Affinity), possible tags at 40% alpha, delta badges on candidate cards
  («+Фракція», «+Клас», dim «−Стихія»).
- Effect lines are Loc templates filled from `TeamData` (never literal numbers in copy).
- Run: a 1.2 s start banner (≤ 3 icons) during READY; a fallen champion's synergy icons flash once on its medallion.
- Counts use LIVING members, are native-blind and gem-blind.

### 5.6 Tag matrix, designed pairs and starter teams

| Tag | Heroes | Champions | Total |
|---|---|---|---|
| Воїн | Арін, Веста, Сірко | Борко, Брант, Довбуш | 6 |
| Стрілець | Руді, Іскар | Альба, Тео, Дара | 5 |
| Маг | Мейра, Люмен | Тая, Менгір, Тарас | 5 |
| Страж | Горан, Вартан | Іво, Отто, Німб, Снаряд | 6 |
| Цілитель | Ейра, Пава | Міла, Олена | 4 |
| Kinetic · Volt · Frost · Plasma · Tech · Rune | Горан, Арін · Руді, Іскар · Ейра · Веста, Люмен · Вартан · Мейра, Пава, Сірко | Борко, Отто, Довбуш · Німб, Дара · Альба, Олена · Іво, Брант · Міла, Тео, Снаряд · Тая, Менгір, Тарас | 5 · 4 · 3 · 4 · 4 · 6 |
| Орден Світанку | Арін, Ейра, Веста, Сірко | Міла, Іво, Дара, Снаряд | 8 |
| Дикі Ікла | Руді, Мейра, Пава | Борко, Альба, Олена, Тарас | 7 |
| Кам'яне Серце | Горан, Вартан | Отто, Брант, Менгір, Довбуш | 6 |
| Небожителі | Іскар, Люмен | Тая, Тео, Німб | 5 |

Designed pairs (★): Горан + Отто (scripted first chest for Горан: Stoneheart I + Guardian pair + Kinetic ×2) · Руді +
Альба (scripted for Руді: Wildfang I + Ranger pair + SUPERCONDUCT) · Арін + Борко (Warrior pair + double stagger) · Ейра
+ Олена (Healer pair + Frost ×2) · Мейра + Тая (Mage pair) · Іскар + Тео (Celestials + Ranger pair; MARK down the lane) ·
Веста + Міла (Dawn + FLARE) · Вартан + Брант (Stoneheart + FLARE) · Люмен + Тая (Celestials + Mage pair) · Пава + Олена
(Wildfang + Healer pair) · Мейра + Тарас (Wildfang + Mage pair + Rune ×2) · Вартан + Снаряд (Guardian pair + Tech ×2) · Веста + Снаряд
(Dawn + FLARE: his MARK, her BURN) · Горан + Довбуш (Stoneheart + Kinetic ×2) · Арін + Довбуш (Warrior pair + Kinetic ×2) · Сірко +
Довбуш (Warrior pair + STAGGER twice: the laughter and the bartka) · Сірко + Тарас (Rune ×2: the Letter and the Word).

Reactions are arsenal §2.1 (unchanged): JOLT + CHILL = SUPERCONDUCT · BURN + CHILL = THERMAL SHOCK · MARK + BURN = FLARE.

| Starter team | Members | Complete when | Plays like |
|---|---|---|---|
| «Буревій / Stormfront» | Руді + Альба + Борко (+ Олена) | Руді at start, Альба = scripted chest #1, Борко = Кварц | fastest ult loop; gates and fliers; Борко fixes Armored with STAGGER |
| «Кам'яна стіна / Stonewall» | Горан + Отто + Іво (+ Брант / Менгір) | Горан L4, Отто = scripted chest #1, Іво = Кварц | walks through blades, breaks walls |
| «Варта Світанку / Dawn Watch» | Арін + Міла + Іво (+ Дара) | Арін = commonest Portal hero, Міла = scripted chest #2 | wins by soldiers at the fortress |

## 6. Roster: 11 heroes and 15 champions (full sheets)

### 6.0 At a glance

Collector numbers: heroes 01–10, champions 11–25 (in gem order at launch; C23 Тарас, C24 Снаряд and C25 Довбуш joined after launch, numbered as they
joined), H26 Сірко (the 11th hero, joined after them; heroes and champions share one number line). Names read the same in uk and en; titles translate.
Five titles changed after the IP / meaning review (critique X21): Руді «Громовий лис / Thunder Fox» (was "the Bolt", a
2008 film), Горан «Кам'яний велет / the Stone Titan» (was «Громило», uk "thug"), Альба «Сніжне Перо / Snowquill" (the
white feather means cowardice in English), Німб «Щит бурі / Storm Aegis» (Stormshield is a known MMO city), Олена
«Морозна знахарка / Frost Herbalist». Before the splash prompts are final the owner runs a store / trademark search on all
26 names + titles (§15 Q8).

| № | id | Name | Title uk / en | Gem | Class | Element | Faction | Species · gender | Niche | Ult kind | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 01 | `titan` | Горан / Goran | Кам'яний велет / the Stone Titan | Кварц | Guardian | Kinetic | Stoneheart | creature (stone golem) · m | structures | `quake` | progression L4 |
| 02 | `arin` | Арін / Arin | Якір Світанку / Anchor of Dawn | Кварц | Warrior | Kinetic | Dawn | human · m | armored | `anchor` | Portal |
| 03 | `bolt` | Руді / Rudi | Громовий лис / Thunder Fox | Сапфір | Ranger | Volt | Wildfang | beast (red fox) · m | flying | `storm` | start |
| 04 | `eira` | Ейра / Eira | Сестра Інею / Rime Sister | Сапфір | Healer | Frost | Dawn | human · f | shielded | `rime` | Portal |
| 05 | `seer` | Мейра / Meira | Провидиця / the Seer | Аметист | Mage | Rune | Wildfang | beast (lynx) · f | — | `rift` | L5 guest · joins L24 |
| 06 | `iskar` | Іскар / Iskar | Мисливець на комети / Comet Hunter | Аметист | Ranger | Volt | Celestials | creature (star-born) · m | — | `comet` | Portal · Seals 40 |
| 07 | `vesta` | Веста / Vesta | Сонцекута / Sunforged | Топаз | Warrior | Plasma | Dawn | human · f | — | `sunglaive` | Portal · Seals 100 |
| 08 | `vartan` | Вартан / Vartan | Серце Горна / Forgeheart | Топаз | Guardian | Tech | Stoneheart | creature (automaton) · m | — | `forgewall` | Portal · Seals 100 |
| 09 | `lumen` | Люмен / Lumen | Живий Опал / the Living Opal | Опал | Mage | Plasma (+Rune in V) | Celestials | creature (living opal) · n | — | `spectrum` | Portal · Seals 200 |
| 10 | `pava` | Пава / Pava | Тисячоока / the Thousand-Eyed | Опал | Healer | Rune (+Frost in V) | Wildfang | beast (peacock-kin) · f | — | `eyes` | Portal · Seals 200 |
| 26 | `sirko` | Сірко / Sirko | Характерник / the Charmed Otaman | Опал | Warrior | Rune (+Tech in V) | Dawn | human · m | — | `letter` | Portal · Seals 200 |

| № | id | Name | Title uk / en | Role line (`CHAMP_<ID>_ROLE`) | Gem | Class | Element | Faction | Species · gender |
|---|---|---|---|---|---|---|---|---|---|
| 11 | `mila` | Міла / Mila | Польова алхімічка / Field Alchemist | Повертає полеглих / Returns the fallen | Кварц | Healer | Tech | Dawn | human · f |
| 12 | `ivo` | Іво / Ivo | Жаровий щит / Brazier Shield | Приймає удар леза / Takes the blade hit | Кварц | Guardian | Plasma | Dawn | human · m |
| 13 | `borko` | Борко / Borko | Рубака з нори / Burrow Brawler | Пірнає під загін / Dives under squads | Кварц | Warrior | Kinetic | Wildfang | beast (badger) · m |
| 14 | `alba` | Альба / Alba | Сніжне Перо / Snowquill | Збиває летунів / Downs the fliers | Сапфір | Ranger | Frost | Wildfang | beast (snowy owl) · f |
| 15 | `otto` | Отто / Otto | Ходяча фортеця / Walking Fortress | Тримає першу сутичку / Holds the first clash | Сапфір | Guardian | Kinetic | Stoneheart | beast (tortoise) · m |
| 16 | `taya` | Тая / Taya | Шепіт рун / Rune Whisper | Присипляє загони / Lulls the squads | Сапфір | Mage | Rune | Celestials | creature (moth sprite) · f |
| 17 | `brant` | Брант / Brant | Обсидіановий клинок / Obsidian Blade | Палить у сутичці / Burns in the clash | Аметист | Warrior | Plasma | Stoneheart | creature (obsidian) · m |
| 18 | `teo` | Тео / Teo | Зоряний картограф / Star Cartographer | Знаходить фантомів / Finds the phantoms | Аметист | Ranger | Tech | Celestials | human · m |
| 19 | `olena` | Олена / Olena | Морозна знахарка / Frost Herbalist | Лікує і студить / Heals and chills | Аметист | Healer | Frost | Wildfang | beast (reindeer) · f |
| 20 | `nimb` | Німб / Nimb | Щит бурі / Storm Aegis | Відводить блискавку / Grounds the lightning | Топаз | Guardian | Volt | Celestials | creature (storm knight) · n |
| 21 | `dara` | Дара / Dara | Небесна гарпунниця / Sky Harpooner | Зшиває загони / Stitches squads together | Топаз | Ranger | Volt | Dawn | human · f |
| 22 | `menhir` | Менгір / Menhir | Старійшина рун / Rune Elder | Креслить рунні кола / Carves rune circles | Топаз | Mage | Rune | Stoneheart | creature (runestone) · n |
| 23 | `taras` | Тарас / Taras | Кобзар / The Kobzar | Пробиває загони словом / Breaks squads with the Word | Топаз | Mage | Rune | Wildfang | human · m |
| 24 | `snaryad` | Снаряд / Snaryad | Пес-сапер / The Sapper Hound | Знешкоджує пастки / Defuses the traps | Аметист | Guardian | Tech | Dawn | beast (Jack Russell terrier) · m |
| 25 | `dovbush` | Довбуш / Dovbush | Опришок / The Carpathian Rebel | Кидає бартку крізь загони / Hurls the bartka through squads | Топаз | Warrior | Kinetic | Stoneheart | human · m |

Coverage: classes W 6 · R 5 · M 5 · G 6 · H 4; elements Kin 5 · Volt 4 · Plasma 4 · Rune 6 · Frost 3 · Tech 4;
factions 8 · 7 · 6 · 5; species humans 10 · beasts 8 · creatures 8. The heroes of a gem never share a class or a
splash pose (Опал: Люмен Mage P3, Пава Healer P1, Сірко Warrior P2). The enemy horde is «Жаророгі / the Emberhorn» (lore only).

**How to read a sheet.** *Kit* = stored Quartz-normalised; *eff* = what the native sees (× NATIVE_MULT). Rank tables are
**generated** (`heroes_tables.py` from the sim constants; Lv1, no gear; every ult number is further × `lv_ult(L)`, Lv30
×2.04, and × gear). Forms II–V are **rules** (budget +3% ult each, Opal V +5%), Attack beats are mostly utility (+1%
index each), Awakening ranks +4% index each — numbers marked *(knob)* are the LevelSim tuning handles that
`test_kit_budget` closes. Every play tip names x-position, a gate kind or an ult moment (the thumb only steers x).

Shared kit table (eff at the native gem, f0, Lv1, rank 1):

| Hero | hp kit → eff | rate /s | dmg kit → eff | splash | range | targets | ult charge |
|---|---|---|---|---|---|---|---|
| Горан | 32 → 32.0 | 1.2 | 4 → 4.00 | 3 | 12 | 1 | 40 |
| Арін | 26 → 26.0 | 1.6 | 3 → 3.00 | 2 | 11 | 1 | 36 |
| Руді | 14 → 15.1 | 3.6 | 1 → 1.08 | 0 | 15 (+2 Long sight) | 1 | 35 |
| Ейра | 20 → 21.6 | 2.0 | 1 → 1.08 | 0 | 14 | 1 | 34 |
| Мейра | 18 → 21.0 | 2.0 | 1 → 1.17 | 0 | 16 | 2 | 38 |
| Іскар | 13 → 15.2 | 3.2 | 1 → 1.17 | 0 | 16 (+2) | 1 | 36 |
| Веста | 27 → 34.0 | 1.5 | 3 → 3.78 | 2 (120° arc) | 12 | 1 | 38 |
| Вартан | 33 → 41.6 | 1.1 | 4 → 5.04 | 3 | 12 | 1 | 42 |
| Люмен | 17 → 23.1 | 2.2 | 1 → 1.36 | 1 | 15 | 2 rays | 42 |
| Пава | 21 → 28.6 | 1.9 | 1 → 1.36 | 0 | 14 | 1 | 44 |
| Сірко | 25 → 34.0 | 1.7 | 3 → 4.08 | 2 (1.5 u arc) | 11 | 1 | 42 |

Starters never fall below their Meta-1 Lv1 numbers (Bolt hp 14 → 15.1, Seer 18 → 21.0).

---

### 6.1 H01 `titan` — Горан — Кам'яний велет / Goran — the Stone Titan
Кварц · Guardian · Kinetic · Stoneheart · stone golem · niche `structures` · ult `quake` · joins at L4 (unchanged).

**Fantasy:** a walking mountain that breaks every wall between the army and the fortress. **Lore (en):** the keystone of
an old Magma Mines bridge, woken when the Emberhorn cracked it; the clear heart-crystal in his chest was the Stoneheart
elders' gift and "will change colour as he grows"; he has never left a soldier on the wrong side of a gate.
**Personality:** slow, patient, protective, bone-dry humour; guards a moss sprout on his shoulder.
**Voice:** pick «Стіна? Добре. Я люблю стіни.» / "A wall? Good. I like walls." · ult «Земле — вставай!» / "Earth — rise!"
**Run:** a heavy rock throw every 0.83 s, splash 3; structures (barricade, turret, geode, crate, fortress, boss armour)
×1.5 with a crack decal; Bulwark at army 0. **Tip:** «Веди Горана на стіни — він їх ламає.» / "Steer Goran at walls —
he breaks them."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `quake` (charge 40) | Смарагдовий розлом / Emerald Quake | **Form I:** 4 travelling bands 3.5 u deep (0.18 s apart, 1 → 15 u): each band kills 12 per squad and breaks 12 per structure; then the army is hazard-immune 6.0 s (the roster's one hazard-immunity ult). Only form I (native Кварц). |
| Attack | Брилобій / Boulderfist | splash 3, structures ×1.5 · **beat 3 Сейсміка / Seismic:** hits STAGGER the squad 0.4 s (strips the Armored penalty for everyone) · **beat 6 Обвал / Rockslide** (recut): every 4th structure hit repeats 50% *(knob)* of its damage on the next structure ≤ 4 u behind · **beat 9 Детонація / Detonation** (recut to Opal): a structure he breaks bursts for 2 *(knob)* on structures ≤ 1.5 u |
| Rally `army_scrape` | Кам'яна шкіра / Stone Skin | +3 soldiers spared per hazard contact × ladder × rank |
| Awakening (recut to Аметист+ only; cap 1 / 2 / 3 at Аметист / Топаз / Опал) | Кришталевий колос / Crystal Colossus | at a fortress or boss siege his hits also land 12 / 16 / 20% of their damage on the gate and the army's ram ticks +5 / 7 / 9% *(knob; siege-only rule, measured ×2 per-level)* |
| Relic | Ключ-камінь мосту / Bridge Keystone | +4 bands 1 u deeper · +8 hazard immunity +1 s · +12 the last band STAGGERs every squad |

| Rank (eff, Lv1) | 1 | 2 | 3 | recut → Опал f5 r10 |
|---|---|---|---|---|
| Quake kills & breaks per band | 12.0 | 12.6 | 13.7 | 20.8 |
| Ult form | I | I | I | I |
| Attack damage per hit | 4.00 | 4.04 | 4.23 | 5.22 |
| Stone Skin (spared per contact) | 3.0 | 3.3 | 3.7 | 6.8 |

**Interactions:** Kinetic machines (Ballista, Mortar, Gatling, Ram) via Affinity; Seismic lets Gatling ignore Armored;
Stoneheart team = "walk through the blades". **Counterplay:** best Quartz breaker; weak vs many small squads and fliers.
**Visual (remake in realistic proportions, addendum 5):** a massive stone golem ≈ 2.4 m, heroic but anatomically plausible
mass, head ≈ 1/9 of height under a heavy brow, forearms and fists huge, moss mantle and two emerald crystal clusters on
the shoulders (emerald = body material, pre-system), gold bands on the fists `#D4A94A`, amber eyes `#FFB040`. **Heart gem:**
one clear round-cut quartz in the chest plate (the only cut gem on him; carries the tier colour via fx mask G).
Splash P2 Advance (fist toward the viewer, low camera). **Clips:** idle 3.0 · run · attack_a throw · attack_b ground slam
· ult_cast 1.2 · hit · victory chest beat · flourish 2.5 (the sprout climbs his finger) · summon_pose 1.2. Re-rig as a
clip character (replaces `_pose_giant`). **Signature beat:** rubble rises around his feet and falls away.

### 6.2 H02 `arin` — Арін — Якір Світанку / Arin — Anchor of Dawn
Кварц · Warrior · Kinetic · Dawn Order · human · niche `armored` · ult `anchor` · the commonest NEW Portal hero.

**Fantasy:** a sky-harbour dock knight who swings a ship's anchor like a hammer and stops a charge dead. **Lore (en):** a
cargo hauler too poor for a squire's sword; he tore an anchor from its mooring and held the gangway alone until the Order
came; they knighted him on the spot. **Personality:** cheerful, stubborn, loud, protective of rookies.
**Voice:** «Тримаю! Хто ще на борт?» / "Got it! Who else is coming aboard?" · ult «Кидаю якір!» / "Dropping anchor!"
**Run:** short heavy swings (range 11, splash 2 in a 1.5 u arc), every hit STAGGERs; every 4th hit is an Anchor Throw to
the farthest hostile ≤ 11 u for ×2. Warrior Cleave ×1.5 in clashes. **Tip:** «Стань навпроти найбільшого загону — і
кидай якір перед зіткненням.» / "Line up with the biggest squad — drop anchor before contact."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `anchor` (36) | Якір з неба / Skyfall Anchor | **Form I:** a sky-ship anchor drops 8 u ahead at his x: impact r 2.5 kills 22 / breaks 22; its chain (4 u wide) **holds** every squad touching it 3.0 s (no advance, no clash damage, STAGGER); gates under the impact take 3 hero hits. Only form I. |
| Attack | Якірний удар / Anchor Strike | STAGGER on hit, Anchor Throw every 4th · **beat 3 Важкий замах / Heavy Swing:** Anchor Throw every 3rd hit · **beat 6 Відплив / Undertow** (recut): a squad hit by the Throw deals −15% *(knob)* clash damage for 3 s · **beat 9 Мала кітва / Little Anchor** (recut to Opal): every 12th hit drops a small anchor r 1.5, 6 kills *(knob)* |
| Rally `army_drill` | Муштра Світанку / Dawn Drill | squads he hit ≤ 2 s before contact lose +0.075 more in the clash |
| Awakening (recut only; cap 1 / 2 / 3) | Розгін / Momentum | each squad wiped gives +4% attack rate for 5 s, stacking to 1 / 2 / 3 |
| Relic | Якірний ланцюг / Anchor Chain | +4 Throw range +2 u · +8 hold +0.5 s · +12 Throw splash +1 |

| Rank (eff) | 1 | 2 | 3 | recut → Опал f5 r10 |
|---|---|---|---|---|
| Anchor impact kills & breaks | 22.0 | 23.1 | 25.1 | 38.2 |
| Attack damage per hit | 3.00 | 3.03 | 3.17 | 3.91 |
| Dawn Drill | 0.075 | 0.083 | 0.093 | 0.170 |

**Interactions:** STAGGER opens Armored squads to Gatling and Ballista; Dawn Order (Міла, Іво, Дара) = reserves at the
siege; Warrior pair with Борко / Брант. **Counterplay:** short range; no answer to fliers or phantoms.
**Visual:** broad-shouldered young man, realistic adult 7.5 heads, sandy hair tied back, freckles; an **anchor-hammer**
(anchor crown = hammer head, flukes = two curved spikes) and 2 m of chain round the left forearm; white enamel breastplate
with a gold sunburst rivet, navy dock coat `#24324F`, copper chain (Kinetic accent at 65%). **COLOR LOCK: clear quartz**
(one round heart gem in the anchor's crown ring; no coloured crystals). Splash P1 Guard. **Clips:** idle · run ·
attack_a overhead swing · attack_b chain throw · ult_cast (leap and hurl) · hit · victory · flourish chain spin ·
summon_pose. **Signature beat:** an anchor chain drops from above and wraps his forearm.

### 6.3 H03 `bolt` — Руді — Громовий лис / Rudi — Thunder Fox
Сапфір · Ranger · Volt · Wildfang · red fox · niche `flying` · ult `storm` · owned from the start.

**Fantasy:** a cocky thunder-fox who fires faster than you can count and knocks fliers out of the sky. **Lore (en):** born
in a lightning-struck den above the Coral Reef; the elders' gold winged circlet was meant to stop his sparks — it did not.
**Personality:** fast-talking show-off, secretly kind to recruits; counts his hits aloud.
**Voice:** «Швидше! Іще швидше!» / "Faster! Even faster!" · ult «Буря, за мною!» / "Storm, follow me!"
**Run:** a stream of lightning darts (rate 3.6, range 17), every 3rd hit forks to 1 more ≤ 4 u; a hit on a Flying squad
**grounds** it 1.2 s (ground-only machines may then hit it; re-ground after 4 s). **Tip:** «Веди Руді крізь ряди воріт —
він вирощує їх найшвидше.» / "Weave Rudi through the gate rows — he grows them fastest."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `storm` (35) | Громовий вихор / Thunder Storm | **Form I:** the Meta-1 storm around him 3.0 s, tick 0.25 s, range 18: 5 kills per squad and 3 breaks per structure per tick; gates in range take a hero hit per tick. **Form II (Сапфір, rank 3) — Ranger rule:** every Flying squad in range is grounded for the storm + 1 s and takes ×1.5; each tick adds 1 JOLT. |
| Attack | Розгалужений лис / Forked Fox | fork every 3rd hit, grounds fliers · **beat 3 Подвійна вилка / Double Fork:** fork range 5 u and a fork may chain once more *(knob)* · **beat 6 Рейковий постріл / Railshot** (recut; a native Sapphire stops at rank 5): every 8th hit pierces the corridor ×2 *(knob)* · **beat 9 Буревісник / Stormcaller** (recut to Opal): a forked dart applies 1 JOLT |
| Rally `machines_element` (Volt) | Іскра зграї / Pack Spark | Volt machines (Railgun, Tesla, Arc Fence, Gate Tuner) +0.03 bucket 2 |
| Awakening (recut only; cap 1 / 2 / 3) | Штормовий лис / Storm Fox | every 8th / 7th / 6th hit calls a mini-storm r 1.5 for 1 s: 0.5 kills per tick |
| Relic | Крилатий вінець / Winged Circlet | +4 fork range +1 u · +8 storm range +2 u · +12 grounded +0.5 s |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|
| Storm kills per tick | 5.4 | 5.7 | 5.9 | 6.2 | 6.7 | 9.0 |
| Ult form | I | I | II | II | II | II |
| Attack damage per hit | 1.08 | 1.09 | 1.10 | 1.11 | 1.16 | 1.36 |
| Pack Spark (bucket 2) | 0.032 | 0.036 | 0.039 | 0.042 | 0.047 | 0.071 |

**Interactions:** JOLT + Альба's / Олена's CHILL = SUPERCONDUCT; Wildfang = the fastest ult loop; Ranger pair (hero
rate +5%). **Counterplay:** ★ gates and fliers; weak vs Armored (needs Арін / Борко stagger) and at army 0 (HP 15).
**Visual (remake, realistic):** a slim athletic fox-kin, realistic 7 heads with a fox head, tall dark-tipped ears, a tail
as long as his body, orange-red fur `#E0602A`, cream muzzle and chest, crimson lacquered armour `#9E2030` with gold trim,
gold winged circlet. **COLOR LOCK: sapphire** (Asscher-cut sapphires `#3FA9FF` in the circlet and chest; no green or
violet). Splash P6 Prowl (leaping toward the viewer). **Clips:** idle (bouncing) · run · attack_a paw flick · attack_b
two-paw rail shot · ult_cast spin leap · hit · victory finger guns · flourish tail spin · summon_pose. Re-rig as a clip
character (replaces `_pose_speedster`). **Signature beat:** lands from a lightning fork; sparks run along his tail.

### 6.4 H04 `eira` — Ейра — Сестра Інею / Eira — Rime Sister
Сапфір · Healer · Frost · Dawn Order · human · niche `shielded` · ult `rime` · Portal.

**Fantasy:** a temple medic whose ice harp freezes the enemy and closes her soldiers' wounds. **Lore (en):** she tended
the wounded in the orbital temple infirmary, where cold never ran out; she tunes frost like a harp; "nobody gets left in
the snow". **Personality:** calm, precise, quietly stubborn, dry hospital humour.
**Voice:** «Тримайтеся ближче. Холод — це ліки.» / "Stay close. Cold is medicine." · ult «Зимо, заспівай!» / "Winter, sing!"
**Run:** a frost ray in pulses (rate 2.0, range 14), a **beam** that ignores the Shielded pool and applies CHILL (proc
0.5); every 6th hit plucks a mend chord: 1 soldier returns from the revive pool. **Tip:** «Заморозь перед сутичкою —
ульта, тоді бій.» / "Freeze before the clash — ult first, then fight."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `rime` (34) | Зимова літанія / Winter Litany | **Form I:** a frost wave to 14 u across the bridge (0.6 s): every squad 3 CHILL stacks (→ FREEZE 1.0 s) and loses 4; the army regains 5 + 25% of the revive pool. **Form II — Healer rule:** also revives the first fallen champion at 50% HP. |
| Attack | Промінь інею / Rime Ray | beam, CHILL 0.5, mend chord every 6th · **beat 3 Тепла рука / Warm Hand:** Mend share 20% → 25% · **beat 6 Крихка варта / Brittle Ward** (recut): when a squad she chilled FREEZES, the army's next clash with it loses −15% · **beat 9 Тиха струна / Quiet String** (recut to Opal): once per 10 s a mend chord shields the front champion for one clash tick |
| Rally `champions_hp` | Обітниця сестер / Sisters' Vow | champion HP ×(1 + 0.15) |
| Awakening (recut only; cap 1 / 2 / 3) | Тиха варта / Quiet Vigil | the first champion that would fall each level is sealed in ice 2 s (takes nothing), then stands at 15 / 20 / 25% HP (prevention, Healer-only) |
| Relic | Крижана струна / Rime String | +4 mend chord every 5th · +8 Litany reach +2 u · +12 FREEZE +0.25 s |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|
| Litany kills per squad | 4.3 | 4.5 | 4.8 | 5.0 | 5.4 | 7.2 |
| Ult form | I | I | II | II | II | II |
| Attack damage per hit | 1.08 | 1.09 | 1.10 | 1.11 | 1.16 | 1.36 |
| Sisters' Vow (champion HP +) | 16% | 18% | 19% | 21% | 24% | 36% |

**Interactions:** CHILL + JOLT = SUPERCONDUCT, + BURN = THERMAL SHOCK; Healer pair with Міла / Олена; Frost machines are
Meta-2 (Affinity empty until then). **Counterplay:** ★ shielded squads; breaks nothing fast.
**Visual:** a tall slim woman, realistic 7.5–8 heads, long hooded white habit-coat with a high frost-fur collar, dark brown
hair in a low bun, grey eyes; a **harp-staff** as tall as her with six ice-crystal strings; pale gold trim, steel-blue
lining `#5C7590`. **COLOR LOCK: sapphire** (string nodes and a square heart gem on the collar; no white "ice crystals" that
read as quartz). Splash P3 Cast (no glow in the art). **Clips:** idle (plucks a string, breath fog) · run · attack_a
pluck · attack_b two-hand chord (`heal`) · ult_cast harp swept overhead · hit · victory bow · flourish · summon_pose.
**Signature beat:** a square-grid frost pattern races across the floor.

### 6.5 H05 `seer` — Мейра — Провидиця / Meira — the Seer
Аметист · Mage · Rune · Wildfang · lynx · ult `rift` · **guest at L5** (one scripted level she leads, «Мейра повернеться
біля Боса Світу 3») · **joins at L24** (World 3 boss); v2 saves that own her keep her.

**Fantasy:** a lynx mystic who sees through hidden gates and folds time around the enemy. **Lore (en):** keeper of the
rune-lamps of the Rune Forest; the third-eye rune on her brow opened and she saw the Rift tear before it happened.
**Personality:** serene, teasing, enigmatic; loves riddles. **Voice:** «Я вже бачила цей бій. Ми виграли.» / "I have seen
this battle. We won." · ult «Зорі, розступіться.» / "Stars, part."
**Run:** twin homing violet orbs (2 targets, range 16); a hit reveals the next hidden gate row; hits on charge gates ×1.5;
BRAND proc 0.5. **Tip:** «Тримай Мейру в ряду прихованих воріт — вона відкриває їх першою.» / "Keep Meira in the
hidden-gate row — she reveals it first."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `rift` (38) | Зоряний розлом / Star Rift | **Form I:** the Meta-1 rift 7 u ahead for 4.0 s (tick 0.5 s, range 16): 5 kills, 4 breaks, slow 0.6 on hazards, turrets, squads and clash losses. **Form II — Mage rule:** BRAND on every squad inside each tick. **Form III Зоресвід / Starsight (Аметист):** while open, hidden gates and Phantom squads ≤ 30 u are revealed and gates inside the range take one hero hit per tick. |
| Attack | Передбачення / Foresight | twin orbs, row reveal, charge gates ×1.5, BRAND 0.5 · **beat 3 Зоряне плетиво / Starweave:** a killing orb bounces to 1 more ≤ 3 u · **beat 6 Тіньова мітка / Umbral Mark:** every 8th hit MARKs 3 s and reveals Phantoms ≤ 4 u · **beat 9 Третє око / Third Eye** (recut to Opal): the reveal shows 2 rows ahead |
| Rally `ult_start` | Передчуття / Premonition | the ult starts each level at +10% (total `ult_start` ≤ 0.40) |
| Awakening (native: opens at Full facets in Amethyst; cap 2, 3 if recut to Opal) | Затемнення / Eclipse | when the ult ends, time stops for hazards, turrets and squads 0.5 / 0.7 / 0.9 s (hero, army and machines keep firing) |
| Relic | Лампа рун / Rune Lamp | +4 a revealed row also shows charge-gate values · +8 rift +0.5 s · +12 BRAND +1 s |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|---|---|
| Rift kills per tick | 5.8 | 6.1 | 6.4 | 6.7 | 7.0 | 7.3 | 7.9 | 9.4 |
| Ult form | I | I | II | II | III | III | III | III |
| Attack damage per hit | 1.17 | 1.18 | 1.19 | 1.20 | 1.21 | 1.22 | 1.28 | 1.42 |
| Premonition | 11.7% | 12.8% | 14.0% | 15.2% | 16.3% | 17.5% | 19.3% | 24.7% |

**Interactions:** Rune machines are Meta-2 (BRAND feeds Harvester coins); Mage pair with Тая / Менгір; reveal + Тео's
probes = no Phantom survives. **Counterplay:** ★ phantom and hidden / charge gates; low damage per orb.
**Visual (remake, realistic):** a slender lynx-kin woman, realistic 7.5 heads with a lynx head, long black ear tufts,
charcoal fur `#2B2A30`, white tail tip, a deep pointed hood and an indigo cape `#2E2EB4` longer than her body, violet
lining, gold filigree. **COLOR LOCK: amethyst** (trillion clasp, orbiting shards, third-eye rune; no blue or teal).
Splash P3 Cast. **Clips:** existing `run, idle, cast, ult` + hit · victory · flourish (orbs juggle) · summon_pose.
**Signature beat:** the splash appears eyes-closed; the eyes open last.

### 6.6 H06 `iskar` — Іскар — Мисливець на комети / Iskar — Comet Hunter
Аметист · Ranger · Volt · Celestials · star-born · ult `comet` · Portal · Seals 40.

**Fantasy:** a star-born sniper who lines up the road and threads one comet through all of it. **Lore (en):** he fell
through the Rift as a comet and woke in the Rift Heart observatory holding a bow made of his own tail of light; he speaks
in star-chart coordinates. **Personality:** aloof, exact, quietly curious; pockets small earthly things.
**Voice:** «Курс прокладено.» / "Course plotted." · ult «Падай, комето!» / "Fall, comet!"
**Run:** fast needles (rate 3.2, range 18) that **pierce 1**; every 6th shot is a Comet Bolt: infinite corridor pierce ×3,
1 JOLT, ignores the Shielded pool. Contrast with Руді: Руді spreads sideways, Іскар goes deep along one line.
**Tip:** «Тримай Іскара на одній лінії з чергою — і не смикай.» / "Hold Iskar on one line with the queue — don't twitch."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `comet` (36) | Падіння комети / Comet Fall | **Form I:** a sky-to-road railstrike down his x, 1.6 u wide, 2 → 30 u ahead, 1.5 s, tick 0.25 s: 6 kills per squad and 5 breaks per structure per tick; hits Flying; ignores Shielded. **Form II — Ranger rule:** Flying ×1.5 and grounded 2 s; the biggest squad hit is PAINTED 4 s. **Form III Хвіст комети / Comet Tail (Аметист):** the strike follows his x live (sweep) and every gate it crosses takes one hero hit per tick. |
| Attack | Зоряна голка / Starneedle | pierce 1; Comet Bolt every 6th · **beat 3 Наскрізь / Through-and-through:** pierce 2 · **beat 6 Хвостатий вогонь / Tailfire:** Comet Bolt every 5th · **beat 9 Подвійна рейка / Twin Rails** (recut to Opal): the Comet Bolt fires two rails at x ± 0.6 |
| Rally `machines_verb` (LANE) | Зоряна лінія / Star Line | LANE machines (Ballista, Laser, Railgun, Prism, Cryo, Ram) +0.025 bucket 2 |
| Awakening (native: Full facets in Amethyst; cap 2, 3 at Opal) | Перигелій / Perihelion | while his x moves < 0.3 u over 1.5 s: attack rate +6 / 9 / 12% and each still second advances the Comet counter by 1 |
| Relic | Уламок комети / Comet Shard | +4 Comet counter −1 shot · +8 Comet Fall +0.25 s · +12 Comet Bolts ground fliers 1 s |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|---|---|
| Comet kills per tick | 7.0 | 7.3 | 7.7 | 8.0 | 8.4 | 8.7 | 9.4 | 11.3 |
| Ult form | I | I | II | II | III | III | III | III |
| Attack damage per hit | 1.17 | 1.18 | 1.19 | 1.20 | 1.21 | 1.22 | 1.28 | 1.42 |
| Star Line (bucket 2) | 0.029 | 0.032 | 0.035 | 0.038 | 0.041 | 0.044 | 0.048 | 0.062 |

**Interactions:** Railgun is Volt AND LANE (signature machine); Тео's MARK on the queue; JOLT + CHILL = SUPERCONDUCT.
**Counterplay:** ★ shielded and lined-up squads, fortress gate lines; side-rail turrets are off his corridor.
**Visual:** a very tall slender star-born, realistic 8 heads, smooth masked face with two white eyes and no mouth, three
long swept-back light filaments from the crown like a comet tail; night star-glass body `#1B2350` with white star specks,
white enamel shoulder plates, gold filigree, Volt orchid sash `#EFB5EF`; the **rail-bow**: two parallel amethyst rails
joined by gold bridges. **COLOR LOCK: amethyst** (rails + trillion heart gem on the sternum; no sapphire tones). Splash P4
Aim (lower-left → upper-right diagonal). **Clips:** idle (hovers on his toes) · run (long gliding strides) · attack_a ·
attack_b full-draw rail · ult_cast · hit · victory · flourish (bow spin behind the back) · summon_pose. Filaments:
scripted bones + `SpringBoneSimulator3D` (§14.2). **Signature beat:** a comet streaks across the background and becomes
his drawn shot.

### 6.7 H07 `vesta` — Веста — Сонцекута / Vesta — Sunforged (committed look)
Топаз · Warrior · Plasma · Dawn Order · human · ult `sunglaive` · Portal · Seals 100 · **born awakened**.

**Fantasy:** a knight-commander whose topaz glaive carries a captured noon; hordes burn where she swings. **Lore (en):**
she forged her glaive in the orbital temple's sun-furnace (its blade is one topaz that drank a noon); the scar on her
cheek is from holding the temple gate against the first raid. **Personality:** fierce, noble, warm with her troops.
**Voice:** «За мною — до сонця!» / "With me — to the sun!" · ult «Полудень!» / "High noon!"
**Run:** glaive sweeps (rate 1.5, range 12, splash 2 in a 120° arc); every hit sets BURN (jumps on wipe). Her topaz blade is
non-emissive in the run except during the ult. **Tip:** «Веди Весту в найбільшу орду — вогонь перекинеться сам.» /
"Steer Vesta into the biggest horde — the fire spreads by itself."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `sunglaive` (38) | Сонцесходження / Sunrise | **Form I:** she plants the glaive; a sunburst 5 u ahead, r 6: 4 pulses 0.3 s apart, each kills 10 and breaks 10; BURN on every squad hit. **Form II — Warrior rule:** squads hit lose +20% *(knob)* in clashes for 3 s. **Form III Сонячне поле / Sun Field:** the burst leaves a 4 s field r 6; squads entering it Burn; army volleys +10% *(knob)* while the blob centre is inside. **Form IV Сонцекрок / Sunstride (Топаз):** 1.0 s later she leaps onto the biggest hostile ≤ 20 u and slams r 4: 8 kills / 8 breaks; every negative gate in the next row takes 2 hero hits. The leap is visual: her logic x stays under the thumb, the model arcs out and springs back to x in ≤ 0.6 s; hits are computed at the target (critique X24). |
| Attack | Сонячна глефа / Sun Glaive | arc splash 2, BURN · **beat 3 Сонячний слід / Sunwake:** every 4th hit leaves a burning strip across the bridge (3 u, 2 s) · **beat 6 Відблиск / Glint:** hits on a burning squad +10% (bucket 2) · **beat 9 Полудень / High Noon:** every 10th hit releases a sun-flare r 4: 6 per squad + BURN |
| Rally `army_reserves` | Клич Світанку / Dawn Call | +6 soldiers join at the siege × ladder × rank |
| Awakening (born; cap 3) | Сонцестояння / Solstice | after her ult a second cast is ready for 6 s at 12 / 16 / 20% power (forms I–III, no leap) |
| Relic | Сонячна застібка / Sun Clasp | +4 BURN +0.5 s · +8 Sunrise radius +0.5 u · +12 Sunstride radius +1 u |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Sunrise kills & breaks per pulse | 12.6 | 13.2 | 13.9 | 14.5 | 15.1 | 15.7 | 16.4 | 17.0 | 18.3 | 19.6 |
| Sunstride slam (form IV) | — | — | — | — | — | — | 13.1 | 13.6 | 14.6 | — |
| Ult form | I | I | II | II | III | III | IV | IV | IV | IV |
| Attack damage per hit | 3.78 | 3.82 | 3.85 | 3.89 | 3.93 | 3.97 | 4.01 | 4.04 | 4.23 | 4.43 |
| Dawn Call (soldiers at the siege) | 7.6 | 8.3 | 9.1 | 9.8 | 10.6 | 11.3 | 12.1 | 12.8 | 14.1 | 15.4 |

**Interactions:** BURN + MARK = FLARE (Міла, Тео, Вартан), BURN + CHILL = THERMAL SHOCK; Dawn Order = the siege team.
**Counterplay:** ★ hordes and sieges; no answer to fliers, phantoms, shields.
**Visual (committed, `prompts_vesta_v2.md`):** a lean woman knight, realistic 7.5–8 heads, white-enamel plate with
sunburst engravings, long copper-auburn braid, crimson-orange half-cape, amber eyes, a thin scar on the left cheek; a
**glaive** longer than she is with a gold sun-ray crossguard and one faceted topaz blade. **COLOR LOCK: topaz**
(blade, pauldron cluster, star-cut heart gem on the breastplate). Splash P2 Advance. **Clips:** idle · run · attack_a
sweep · attack_b rising slash · ult_cast plant · ult_leap 1.0 · hit · victory · flourish glaive twirl · summon_pose.
Braid and cape: scripted bones + `SpringBoneSimulator3D`. **Signature beat:** she spins the glaive once and plants it; a
five-ray sunburst flares.

### 6.8 H08 `vartan` — Вартан — Серце Горна / Vartan — Forgeheart
Топаз · Guardian · Tech · Stoneheart · basalt-and-brass automaton · ult `forgewall` · Portal · Seals 100 · **born
awakened**.

**Fantasy:** a living forge-fortress that walls off turrets and blades and marks every target for the machines. **Lore
(en):** built by Stoneheart smiths around a living topaz core to guard the Great Forge; he carried the last smiths out on
his shield. **Personality:** formal, literal, loyal; clipped reports. **Voice:** «Позицію зайнято. Ніхто не пройде.» /
"Position taken. No one passes." · ult «Стіну зведено!» / "The wall stands!"
**Run:** heavy rivet shots (rate 1.1, splash 3) that MARK the target (Tech, vs 1.25, reveals Phantom); two brass
ward-drones each absorb one turret shot aimed at the army (recharge 6 s). **Tip:** «Вмикай стіну перед рядом турелей або
лез.» / "Raise the wall right before a turret or blade row."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `forgewall` (42) | Кована стіна / Forgewall | **Form I:** a **knee-high** basalt-and-crystal rampart (≤ 0.6 u tall, α ≤ 0.5 above 0.3 u, so the next gate row stays readable — critique X07), 6 u wide, rises 3 u ahead and travels with the army 5 s: it absorbs every turret shot at the army and the first blade / barricade contact (that barricade takes 10); squads reaching it are Staggered, lose 8 and fight the wall first (wall HP 30). **Form II — Guardian rule:** wall HP +50% (no hazard immunity: one hazard-ult per roster, critique X24). **Form III Заклепкові вежі / Rivet Turrets:** 4 turrets on the rampart fire homing rivets (1 dmg × 4 every 0.5 s, hit Flying, MARK). **Form IV Обвал / Landslide (Топаз):** when the wall expires it topples forward: a 6 u-wide landslide to 10 u ahead kills 8 and breaks 8. |
| Attack | Заклепкова гармата / Rivet Cannon | splash 3, MARK, 2 ward-drones · **beat 3 Третій дрон / Third Drone:** 3 ward-drones · **beat 6 Аварійна стіна / Emergency Wall:** a drone may also absorb one blade / barricade contact (8 s cooldown, shared) · **beat 9 Розпечена заклепка / Molten Rivet:** structure hits leave a rivet that detonates after 1 s: 2 dmg r 1.5 |
| Rally `army_volleys` | Кований стрій / Forged Rank | army volleys ×(1 + 0.15) |
| Awakening (born; cap 3) | Броньований марш / Armoured March | champions take −12 / −16 / −20% clash damage (team rule, measured by the team delta) |
| Relic | Ядро горна / Forge Core | +4 ward recharge −1 s · +8 wall +0.5 s · +12 Landslide reaches 12 u |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | recut → Опал f5 r10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Wall contact kills (wall HP scales the same) | 10.1 | 10.6 | 11.1 | 11.6 | 12.1 | 12.6 | 13.1 | 13.6 | 14.6 | 15.7 |
| Landslide (form IV) | — | — | — | — | — | — | 13.1 | 13.6 | 14.6 | — |
| Ult form | I | I | II | II | III | III | IV | IV | IV | IV |
| Attack damage per hit | 5.04 | 5.09 | 5.14 | 5.19 | 5.24 | 5.29 | 5.34 | 5.39 | 5.64 | 5.90 |
| Forged Rank (volleys +) | 18.9% | 20.8% | 22.7% | 24.6% | 26.5% | 28.3% | 30.2% | 32.1% | 35.3% | 38.6% |

**Interactions:** MARK refreshes Drone's Mark, gives Rockets a painted focus; MARK + BURN = FLARE (Брант, Іво);
Stoneheart team ignores W4–W5 hazards. **Counterplay:** ★ turret and blade rows; the slowest gate hero (1.1 hits/s).
**Visual:** an upright knightly automaton, realistic 7.5 heads, small helm with a T-visor, broad pauldrons, slim brass
waist; left forearm = a kite-shield of basalt slabs edged in brass; right forearm = a short rivet cannon with a drum
magazine; a furnace grille in the chest; two fist-sized brass ward-drones (separate meshes, procedural orbit). Basalt
`#2E2B2B`, brass `#B08A3E`, enamel visor plate, Tech lime only on drone lamps. **COLOR LOCK: topaz** (star-cut furnace
core = heart gem, drone lenses; no orange lava — enemy colour). Splash P5 Bulwark. **Clips:** idle · run (measured
march) · attack_a recoil · attack_b shield bash · ult_cast (shield slammed down) · hit · victory (steam vent) · flourish
(drones loop) · summon_pose. **Signature beat:** his chest furnace ignites; rivets glow in sequence.

### 6.9 H09 `lumen` — Люмен — Живий Опал / Lumen — the Living Opal (committed look)
Опал · Mage · Plasma (+ Rune in form V) · Celestials · living opal · ult `spectrum` · Portal 1.41% / Seals 200 · **born
awakened** · pronoun «воно» (§15 Q9).

**Fantasy:** the first light that came through the Rift; its prism splits a beam into colours that burn through any
shield. **Lore (en):** a being of living opal that remembers the colour of every star; it fights so that no colour is ever
put out. **Personality:** serene, gentle, otherworldly; delighted by laughter.
**Voice:** «Світло пам'ятає тебе.» / "The light remembers you." · ult «Розквітни, спектре!» / "Bloom, spectrum!"
**Run:** the prism fires 2 beam rays per cast (rate 2.2, range 15, splash 1): beams ignore Shielded and BURN (proc 0.5);
with fewer targets than rays, spare rays converge for ×1.5. **Tip:** «Тримай Люмена в центрі мосту — віяло накриває обидва
боки.» / "Keep Lumen mid-bridge — the fan covers both sides."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `spectrum` (42) | Спектральний вінець / Spectral Crown | **Form I:** a 7-ray fan 60° wide at its x, 16 u long, 2.5 s, tick 0.25 s: each ray kills 2 and breaks 2 per tick (a squad takes ≤ 2 rays per tick); hits Flying; ignores Shielded. **Form II — Mage rule:** BURN on every squad hit. **Form III:** each tick every gate inside the fan takes one hero hit. **Form IV Осколки вінця / Crown Shards:** at the end the halo shards fall on the 12 biggest hostiles: 4 kills / breaks each. **Form V Друге світання / Second Dawn (Опал; + Rune):** a ring of light over the screen: every squad Branded and Burning; fielded machines +10% damage (bucket 2, inside TEAM_B2_CAP) for 6 s — no fire-rate buff, no Apex charge (critique B3). Ray count and camera beat (≤ 8% FOV push-in, ≤ 0.6 s) are the luxe; additive layers α ≤ 0.35 over gate panels. |
| Attack | Розщеплене світло / Split Light | 2 beam rays, BURN 0.5, focus ×1.5 · **beat 3 Третій промінь / Third Ray:** every 3rd cast fires a third ray · **beat 6 Спис спектра / Spectrum Lance:** every 5th cast the rays merge into a white corridor lance ×3 · **beat 9 Веселковий вогонь / Rainbow Fire:** her Burn jumps to 2 squads on wipe; burning squads take +8% from machines (bucket 2, inside the cap) |
| Rally `machines_element` (Plasma) | Призма вівтаря / Prism Rite | Plasma machines (Plasma Cannon, Laser, Prism) +0.03 bucket 2 |
| Awakening (born; cap 4) | Гра кольорів / Play of Colour | every 10 / 9 / 8 / 7 s its rays change element for 4 s (Plasma → Volt → Frost → Rune), so its own hits complete the team's reactions |
| Relic | Вінцевий уламок / Crown Shard | +4 focus ×1.5 → ×1.7 · +8 fan 60° → 70° · +12 Crown Shards 12 → 14 targets |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Fan kills & breaks per ray per tick | 2.7 | 2.9 | 3.0 | 3.1 | 3.3 | 3.4 | 3.5 | 3.7 | 3.8 | 3.9 | 4.2 |
| Crown Shard hit (form IV) | — | — | — | — | — | — | 7.1 | 7.3 | 7.6 | 7.9 | 8.5 |
| Ult form | I | I | II | II | III | III | IV | IV | V | V | V |
| Attack damage per hit | 1.36 | 1.37 | 1.39 | 1.40 | 1.41 | 1.43 | 1.44 | 1.46 | 1.47 | 1.48 | 1.55 |
| Prism Rite (bucket 2) | 0.041 | 0.045 | 0.049 | 0.053 | 0.057 | 0.061 | 0.065 | 0.069 | 0.073 | 0.078 | 0.085 |

**Interactions:** Prism (Legendary LANE amplifier) is its signature machine; Play of Colour fires SUPERCONDUCT, THERMAL
SHOCK and FLARE without a partner. **Counterplay:** ★ shielded and gate-heavy levels; light damage per ray vs Armored.
**Visual (committed):** a tall slender celestial being, realistic 8 heads, living white opal skin `#F2F0F7` with rainbow
fire inside, calm face with glowing white eyes, a floating **halo-crown of opal shards** (3D: one rigid ring on the head
bone), translucent starlight robes with gold filigree, a floating faceted **prism** in the left hand. **COLOR LOCK:
opal** (marquise cabochon heart gem on the brow; the prism is clear crystal with opal fire). Splash P3 Cast. **Clips:**
idle (prism rotates, robes drift) · run (glide 10 cm above the road) · attack_a prism flick · attack_b two-hand lance ·
ult_cast · hit · victory · flourish (halo shards orbit wide) · summon_pose. **Signature beat:** it descends through a
spectrum split by its prism; colours land on the planes.

### 6.10 H10 `pava` — Пава — Тисячоока / Pava — the Thousand-Eyed
Опал · Healer · Rune (+ Frost in form V) · Wildfang · peacock-kin · ult `eyes` · Portal 1.41% / Seals 200 · **born
awakened**.

**Fantasy:** the grove's thousand-eyed guardian; when she opens her fan, the fallen stand up again. **Lore (en):** keeper of
the Thousand-Eyed Grove of the Rune Forest, where every fallen feather becomes an eye; she has never forgotten a face.
**Personality:** regal, maternal, unhurried; stern with the careless. **Voice:** «Я бачу кожного з вас.» / "I see every one
of you." · ult «Розкрийтеся, очі!» / "Open, eyes!"
**Run:** feather darts (rate 1.9, range 14) that BRAND (proc 1.0); every 5th hit plants an Eye on the squad: when that
squad is wiped, 1 soldier returns from the revive pool. **Tip:** «Відкривай віяло, коли армія тане.» / "Open the fan
when the army is melting."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `eyes` (44) | Тисяча очей / Thousand Eyes | **Form I:** her fan opens 3.0 s; every soldier lost meanwhile is recorded and at close returns `min(lost, 8 + 30% of the revive pool)`; every squad ≤ 16 u is Branded. **Form II — Healer rule:** revives the first fallen champion at 50% HP. **Form III Подвійний облік / Double Count:** every soldier lost while the fan is open is recorded twice (the return cap is unchanged) — her identity is returning, not blocking (critique X24). **Form IV Розплющені очі / Eyes Wide:** at close the eyes open across the screen (0.8 s white flash ≤ 60%): every squad loses 4, Phantoms revealed and MARKed. **Form V Відродження пір'я / Plumage Rebirth (Опал; + Frost):** revives **all** fallen champions at 50% HP; squads ≤ 16 u CHILLed to FREEZE 1.0 s. |
| Attack | Очі пір'я / Feather Eyes | BRAND 1.0; Eye every 5th · **beat 3 Тепле гніздо / Warm Nest:** Mend share 20% → 25%, Eye every 4th · **beat 6 Пильне око / Watchful:** Eyes also MARK and reveal Phantom · **beat 9 Віяло-заслін / Fan Guard:** once per 10 s a feather intercepts one turret shot or blade contact on the army |
| Rally `champions_aura` | Вічне віяло / Ever-Fan | champions' aura value ×(1 + 0.06) (capped by AURA_CAP 0.40) |
| Awakening (born; cap 4) | Пробуджені очі / Opened Eyes | a fallen champion stands up again after 10 / 9 / 8 / 7 s at 30% HP, once per level (a Healer-hero revive) |
| Relic | Перо першого ока / First-Eye Plume | +4 Eye every hit −1 (min 3) · +8 fan +0.5 s · +12 revived champions +10% HP |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Fan base return (+30% of the pool) | 10.9 | 11.4 | 12.0 | 12.5 | 13.1 | 13.6 | 14.1 | 14.7 | 15.2 | 15.8 | 16.9 |
| Eyes Wide kills (form IV) | — | — | — | — | — | — | 7.1 | 7.3 | 7.6 | 7.9 | 8.5 |
| Ult form | I | I | II | II | III | III | IV | IV | V | V | V |
| Attack damage per hit | 1.36 | 1.37 | 1.39 | 1.40 | 1.41 | 1.43 | 1.44 | 1.46 | 1.47 | 1.48 | 1.55 |
| Ever-Fan (aura value +) | 8.2% | 9.0% | 9.8% | 10.6% | 11.4% | 12.2% | 13.1% | 13.9% | 14.7% | 15.5% | 16.9% |

**Interactions:** the best hero for a 3-champion team (capped); Healer pair with Міла / Олена; BRAND + Harvester = the
coin team (Meta-2). **Counterplay:** ★ hazard- and clash-heavy levels; the lowest structure damage.
**Visual:** a tall regal peacock-kin woman, realistic 7.5 heads with a small bird head and a five-feather crest, long
neck, white enamel high collar; a long closed train of eye-feathers that opens into a full circular **fan** (a separate
mesh unfolded by code, no blend shapes — critique X13); a slim quill staff topped by one opal eye. Deep Rune-indigo
plumage `#2E2EB4` shading to ink-teal `#1F4E5A`, gold filigree, bone-white heartwood beads. **COLOR LOCK: opal** (every
eye-spot is an opal marquise cabochon; heart gem on the collar; no green or blue gems). Splash P1 Guard (fan half-open
behind her like a halo). **Clips:** idle (preens) · run (long-legged bird gait) · attack_a staff flick · attack_b fan snap
· ult_cast (fan opens; code-driven) · hit · victory · flourish (full fan display) · summon_pose. **Signature beat:** a fan
of a thousand eyes opens behind her; the eyes blink open in a wave.

### 6.11–6.22 Champions — common rules

These rules cover C23 Тарас, C24 Снаряд and C25 Довбуш too (their sheets are §6.25–6.27, after the Loc appendix, so the
§ numbers above stay).

- **Numbers** are the §4.4 generated rows (kit × ladder × `cl(L)` × relic): *native f0 Lv1 / native f5 Lv20 / recut to
  Топаз f5 Lv20*. Tier extras (II–IV) come on top of the main number and are counted in `KIT_INDEX` (P0_c ± 3%).
  Durations, radii, counts and ticks never scale.
- **Proportions:** realistic adult proportions for every champion (owner addendum 5 overrides the "slightly chibi" note
  of prompts batch 1); beast-kin and creatures keep plausible anatomy. Card art 3:4 from mid-thigh, 1536 × 2048, the
  quiet column clear for the emblem; run model 1.10 u.
- **Clips (all):** `idle` 2.0 s · `run` · `action` (upper body) · `special` (full body) · `hit` · `fall` · `victory` ·
  `flourish` 1.5 s. Unique `special` per sheet. Fall flourish 0.6 s (one sound + one prop beat).
- **COLOR LOCK** = the native gem for every crystal on the character; element colour lives only in cloth accents and VFX.
- **Twist** names are `ACT_<ID>`; the class aura line is `AURA_<CLASS>`; lore lines are in §6.24.

### 6.11 C11 `mila` — Міла — Польова алхімічка / Mila — Field Alchemist (committed look)
Кварц · Healer · Tech · Dawn Order · human · f · slot **left** · scripted chest #2 (`SCRIPTED_SECOND`).

**Fantasy:** the youngest field medic of the Order, running into the fight with a lantern that turns pain into light.
**Personality:** bright, brave, chatty, a little clumsy; scolds soldiers for getting hurt. **Voice:** pick «Не вмирати —
це наказ!» / "No dying — that's an order!" · action «Тримай, ще тепле!» / "Here — still warm!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 30 / 55 / 61 |
| Action — Mend | 30% of soldiers lost feed the pool (cap 30 × power per level); every 3 s returns up to 3 × power | 3.00 / 5.47 / 6.09 per pulse |
| Twist — Тонік / Tonic | a pulse that returns ≥ 1 soldier throws a flare vial: MARK on the nearest squad ≤ 12 u for 3 s (reveals Phantom) | — |
| Aura (r 1.3) | hazard losses − value × 0.30 (left) | 0.120 → 3.6% / 0.252 → 7.6% (relic +12) |
| Tier | I (a recut keeps I) | — |
| Relic Ліхтар наставниці / Mentor's Lantern | +4 pool cap +5 · +8 pulse −0.25 s · +12 Tonic MARK +1 s | — |

**Fall:** the lantern drops and gutters out; she reaches for it. **Visual:** a slight young woman (≈ 1.60 m, realistic),
big satchel on the hip, **brass lantern** raised high (signature), short wavy chestnut hair with a green ribbon; cream
robes `#EFE6D2`, sage apron `#8FB07A` (Tech lime at 40%), gold trim, vials tinted neutral amber. **COLOR LOCK: clear
quartz** (lantern crystal + round heart gem on the apron clasp). Card P3 Cast, lantern toward the viewer. **Special:**
kneel-and-raise (big pulse).

### 6.12 C12 `ivo` — Іво — Жаровий щит / Ivo — Brazier Shield
Кварц · Guardian · Plasma · Dawn Order · human · m · slot **front**.

**Fantasy:** an earnest young squire who blocks blades with a shield made from a temple brazier — still warm.
**Personality:** earnest, freckled, over-formal; worships Веста and tries far too hard. **Voice:** pick «Я прикрию! Чесне
лицарське!» / "I've got you! Knight's honour!" · action «БЛОК!» / "BLOCK!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | takes the front clash share (fractional accumulator) | 60 / 109 / 122 |
| Action — Block | absorbs one blade / spike / barricade contact within 1.0 u (0 losses, «БЛОК») + 1 kill on the squad behind; cd 5 s | — |
| Twist — Жар / Brazier Heat | a blocked barricade takes 3 × power and burns; at each clash start the squad in contact gets BURN | 3.00 / 5.47 / 6.09 damage |
| Aura (r 1.0) | clash losses − value × 0.35 (front) | 0.100 → 3.5% / 0.210 → 7.3% |
| Tier | I | — |
| Relic Решітка жаровні / Brazier Grate | +4 block radius +0.1 u · +8 barricade burn +50% · +12 Block cd −0.5 s | — |

**Fall:** the shield clangs flat, its coal dims; he salutes from one knee. **Visual:** a lanky 17-year-old squire in
slightly oversized white-enamel plate (visor up), a **round brazier-shield** whose boss is an iron grate holding a glowing
coal-crystal, short spear; gold rivets, Plasma-rose sash `#B42E71`, ginger hair, freckles. **COLOR LOCK: clear quartz**
(coal-crystal + heart gem on the gorget; fire is FX). Card P5 Bulwark. **Special:** plant-and-brace block.

### 6.13 C13 `borko` — Борко — Рубака з нори / Borko — Burrow Brawler
Кварц · Warrior · Kinetic · Wildfang · beast (badger) · m · slot **front** (→ left behind a Guardian).

**Fantasy:** a badger digger who goes under the enemy's feet and comes up swinging. **Personality:** gruff, stubborn,
loyal, funny; restless above ground. **Voice:** pick «Нагорі тісно. Унизу — моє.» / "Up top is crowded. Down below is
mine." · action «Знизу!» / "From below!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 48 / 88 / 98 |
| Action — Cleave | in a clash +0.07 kills per FIGHT_TICK × power (fractions carry) | — |
| Twist — Підкоп / Undermine (his leap) | every 5 s outside a clash he burrows 0.4 s (a dirt ridge races ahead) and erupts under a squad ≤ 3 u: 3 × power kills + STAGGER; never Flying | 3.00 / 5.47 / 6.09 kills |
| Aura (r 1.1) | squads in contact lose + value × 0.35 | 0.100 → 3.5% / 0.210 → 7.3% |
| Tier | I | — |
| Relic Дідова лопата / Grandsire's Spade | +4 Undermine range +0.5 u · +8 Undermine kills +15% · +12 cleave STAGGERs once per 1 s | — |

**Fall:** sinks into a dirt mound, only his nose showing, then the mound settles. **Visual:** a stocky badger-kin (≈ 1.50 m,
broad, plausible digger musculature), striped black-white face, a long **spade-axe** over the shoulder, miner's leather
harness, brass goggles pushed up; grey-black fur, heartwood leather `#6B4A2E`, Kinetic copper fittings `#D0BBAF`.
**COLOR LOCK: clear quartz** (heart gem in the harness buckle). Card P6 Prowl. **Special:** dive and burst out (the body
hides under a VFX dirt mound).

### 6.14 C14 `alba` — Альба — Сніжне Перо / Alba — Snowquill (committed look)
Сапфір · Ranger · Frost · Wildfang · beast (snowy owl) · f · slot **rear** · scripted chest #1 for Руді.

**Fantasy:** a silent snowy-owl archer who owns the sky. **Personality:** quiet, watchful, dry wit, perfectionist; blinks
slowly when amused. **Voice:** pick «Небо чисте. Поки що.» / "Sky's clear. For now." · action «Донизу!» / "Down you go!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 28 / 51 / 55 |
| Action — Shot | every 1.2 s at the PAINT target, else the nearest hostile ≤ 14 u (16 u vs Flying); hits Flying ×1.5 | 1.08 / 1.97 / 2.12 dmg |
| Twist — Крижана стріла / Ice Arrow | shots apply CHILL (proc 0.5) and prefer a Flying squad over the painted target | — |
| Aura (r 1.4) | army volley damage + value × 0.25 (rear) | 0.162 → 4.0% / 0.340 → 8.5% |
| Tier | II: +1 arrow every 3rd shot (a recut keeps II) | — |
| Relic Сніжна тятива / Snow String | +4 range +1 u · +8 CHILL proc +0.25 · +12 Flying ×1.5 → ×1.75 | — |

**Fall:** feathers burst up like snow; she folds into a ball of plumage. **Visual (re-issue `prompts_batch1` #6 with COLOR
LOCK and realistic proportions):** a tall slender owl-kin woman, round owl head with golden eyes, feathered sleeves that
flare like wings, short feathered hood, a **sapphire-crystal longbow** as tall as she is; white and silver plumage with
grey speckles, silver-blue leather, white wood. **COLOR LOCK: sapphire** (bow crystal, arrow tips, square heart gem on
the quiver strap; no turquoise). Idle: the 120° head swivel. **Special:** wing-flare jump shot.

### 6.15 C15 `otto` — Отто — Ходяча фортеця / Otto — Walking Fortress (committed look)
Сапфір · Guardian · Kinetic · Stoneheart · beast (tortoise) · m · slot **front** · scripted chest #1 for Горан and default.

**Fantasy:** an ancient tortoise whose shell has grown into a little crystal fortress; the first clash breaks on him.
**Personality:** wise, unhurried, kind, grandfatherly; tells very long stories. **Voice:** pick «Не поспішай. Стіна — це
я.» / "No rush. I am the wall." · action «Тримаю...» / "Holding..."

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 65 / 118 / 127 |
| Action — Block | template (1.0 u, cd 5 s) + 1 × power kills on the squad behind | 1.08 / 1.97 / 2.12 kills |
| Twist — Панцир-фортеця / Shell Fortress | at each clash start he plants: the first 2 clash ticks cost the army 0 (he takes them at ×0.5); 8 s between plants | 2 ticks (a count, never scales) |
| Aura (r 1.0) | clash losses − value × 0.35 | 0.108 → 3.8% / 0.227 → 7.9% |
| Tier | II: block radius 1.4 u | — |
| Relic Перший камінчик / First Pebble | +4 aura radius +0.1 u · +8 plant cooldown −1 s · +12 plant absorbs 3 ticks | — |

**Fall:** pulls into his shell; one crystal tower cracks and topples. **Visual (re-issue `prompts_batch1` #8):** a broad
tortoise-kin (≈ 1.55 m, heavy, plausible reptile anatomy) with a high domed shell grown into a miniature three-tower
fortress, a **bronze tower shield**; olive scaly skin, bronze bands `#A0702E`, stone-grey shell, copper trims. **COLOR
LOCK: sapphire** `#3FA9FF` (tower crystals, square heart gem on the shield boss). **Special:** plant (shield slammed down,
shell glows).

### 6.16 C16 `taya` — Тая — Шепіт рун / Taya — Rune Whisper
Сапфір · Mage · Rune · Celestials · creature (moth sprite) · f · slot **rear** (→ right if a Ranger holds the rear).

**Fantasy:** a star-moth whose rune-dust sends whole squads to sleep mid-charge. **Personality:** dreamy, shy, kind, a
little spooky; whispers. **Voice:** pick «Тсс... вони вже засинають.» / "Shh... they're falling asleep." · action
«Спи...» / "Sleep..."

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 28 / 51 / 55 |
| Action — Spell | every 4 s a dust burst r 1.5 on the densest squad ≤ 12 u: 4 × power kills per squad + BRAND | 4.32 / 7.88 / 8.47 kills |
| Twist — Пилок снів / Dream Dust | squads hit are lulled 1.5 s (50% speed and clash damage) | — |
| Aura (r 1.2) | soldiers in the ring apply BRAND with their volleys at proc value × 0.25 | 0.162 → 4.0% / 0.340 → 8.5% |
| Tier | II: radius 2.0 | — |
| Relic Колискова / Lullaby Chime | +4 lull +0.25 s · +8 spell radius +0.2 u · +12 lulled squads at 40% instead of 50% | — |

**Fall:** wings fold; she drifts down like a leaf and dims. **Visual:** a small hovering moth-sprite (the one non-humanoid
scale exception: body ≈ 0.9 m, wingspan 1.8 m) with a smooth oval mask-face and large dark eyes, fluffy moonsilver
collar `#C9D3E6`, **two pairs of broad moth wings** with rune eye-marks, a **rune chime** of three stone tablets; dusk-lilac
wings shading to Rune indigo `#2E2EB4`. **COLOR LOCK: sapphire** (chime bead, square heart gem on the collar).
**Special:** big wing beat releasing dust; `run` is a hover loop (wings on 2 extra bones each, flapped by code).

### 6.17 C17 `brant` — Брант — Обсидіановий клинок / Brant — Obsidian Blade
Аметист · Warrior · Plasma · Stoneheart · creature (obsidian geode-born) · m · slot **front** (→ left).

**Fantasy:** a black-glass warrior born from a split geode, whose red-hot blades set every clash on fire.
**Personality:** fiery, impatient, proud, competitive. **Voice:** pick «Хто перший? Я.» / "Who's first? Me." · action
«Наскрізь!» / "Straight through!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 56 / 102 / 106 |
| Action — Cleave + leap | +0.07 kills per FIGHT_TICK in his clash; every 5 s a leap at a squad ≤ 3 u | 3.50 / 6.38 / 6.62 leap kills |
| Twist — Розжарені клинки / Red-hot Blades | cleave ticks apply BURN to the clash squad; the leap leaves a burning cross (BURN on squads ≤ 1.5 u) | — |
| Aura (r 1.1) | squads in contact lose + value × 0.35 | 0.117 → 4.1% / 0.245 → 8.6% |
| Tier | III: II leap +1 kill, range 4 u · III the leap applies the status (the cross) | — |
| Relic Серце жеоди / Geode Heart | +4 cleave +0.01 per tick · +8 burning cross radius +0.5 u · +12 leap cd −0.5 s | — |

**Fall:** cracks along his geode seam, the chest crystals go dark, he kneels on his blades. **Visual:** a lean, tall
humanoid of black volcanic glass (≈ 1.90 m, realistic athletic proportions), a crest of obsidian shards on head and
spine, chest split like a geode full of crystals, **twin obsidian sickle-blades** with glowing edges; obsidian `#15131A`
with violet sheen, Plasma-rose edge glow `#B42E71` (no orange lava — enemy colour), brass wrist bands. **COLOR LOCK:
amethyst** (geode crystals = heart gem, trillion facets). **Special:** leap with a downward X-cut.

### 6.18 C18 `teo` — Тео — Зоряний картограф / Teo — Star Cartographer
Аметист · Ranger · Tech · Celestials · human · m · slot **rear**.

**Fantasy:** a young astronomer whose telescope-crossbow and star-probes find what hides. **Personality:** nerdy,
excitable, talks fast and in numbers; brave when it counts. **Voice:** pick «Координати є! Стріляю!» / "Coordinates
locked! Firing!" · action «Бачу тебе!» / "I see you!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 30 / 55 / 57 |
| Action — Shot | every 1.2 s, homing (Tech), hits Flying | 1.17 / 2.13 / 2.21 dmg |
| Twist — Зоряний зонд / Star Probe | every 4th shot is a probe: reveals Phantom squads ≤ 14 u and MARKs its target 3 s | — |
| Aura (r 1.4) | army volley damage + value × 0.25 | 0.175 → 4.4% / 0.367 → 9.2% |
| Tier | III: II +1 bolt every 3rd shot · III shots apply MARK (proc 0.5) | — |
| Relic Журнал зондів / Probe Logbook | +4 probe reveal range +2 u · +8 MARK +1 s · +12 a probe every 3rd shot | — |

**Fall:** his goggles crack; star-charts scatter in the wind. **Visual:** a lanky young man (≈ 1.80 m), round brass
goggles, a long night-blue **star-chart cloak** `#1B2350` printed with constellation lines, a **telescope-crossbow**, a
finned brass **probe drone** at his shoulder; moonsilver, brass `#B08A3E`, Tech-lime lens rings `#5ED437`. **COLOR LOCK:
amethyst** (telescope lens, trillion heart gem on the cloak clasp). **Special:** launches the probe overhead.

### 6.19 C19 `olena` — Олена — Морозна знахарка / Olena — Frost Herbalist
Аметист · Healer · Frost · Wildfang · beast (reindeer) · f · slot **right** (→ left).

**Fantasy:** a reindeer herbalist whose antler bells slow a fever and a charge alike. **Personality:** warm, grounded,
motherly, practical; full of folk sayings. **Voice:** pick «Холод — до рани, тепло — до серця.» / "Cold for the wound,
warmth for the heart." · action «Дзень — і легше.» / "A chime — and it eases."

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | — | 35 / 64 / 66 |
| Action — Mend | template (30% → pool, every 3 s) | 3.50 / 6.38 / 6.62 per pulse |
| Twist — Морозний бальзам / Frost Balm | each pulse applies 1 CHILL to squads ≤ 2 u of the army front; returned soldiers are *rimed*: the next hazard contact spares 1 extra per rimed soldier (cap 3) | — |
| Aura (r 1.3) | hazard losses − value × 0.30 | 0.140 → 4.2% / 0.294 → 8.8% |
| Tier | III: II +1 per pulse, returns land at the blob front · III every 15 s cleanses a curse lane / DoT and heals the front champion 10% | — |
| Relic Рогові дзвоники / Antler Bells | +4 pulse −0.25 s · +8 Frost Balm radius +0.5 u · +12 rimed cap 3 → 4 | — |

**Fall:** the bells ring once, discordant; she kneels, antlers lowered. **Visual:** a tall reindeer-kin woman (≈ 1.75 m +
**wide antlers** hung with tiny crystal bells — signature), thick winter fur collar, felt robe in deep red-brown
`#7A3B2E` with Frost-ivory embroidery `#F4F8DF`, **bone herb-staff** with frost-herb bundles. **COLOR LOCK: amethyst**
(antler bells, trillion heart gem on the collar; no blue ice crystals). **Special:** shakes the antlers (big chime pulse).

### 6.20 C20 `nimb` — Німб — Щит бурі / Nimb — Storm Aegis
Топаз · Guardian · Volt · Celestials · creature (storm-cloud knight) · n · slot **front**.

**Fantasy:** a living thunderstorm in a knight's armour; blades and bolts bend toward it and vanish into the cloud.
**Personality:** booming, jovial, protective, theatrical; laughs in thunder. **Voice:** pick «Гримить? Це я радію!» /
"Thunder? That's me being happy!" · action «Сюди, блискавко!» / "Over here, lightning!"

| Part | Rule | f0 Lv1 / f5 Lv20 |
|---|---|---|
| HP | — | 76 / 138 |
| Action — Block | template (1.0 u, cd 5 s, +1 kill) | — |
| Twist — Громовідвід / Lightning Rod | every Block discharges a chain: 3 hostiles ≤ 5 u take 2 × power and 1 JOLT | 2.52 / 4.60 per target |
| Aura (r 1.0) | clash losses − value × 0.35 | 0.126 → 4.4% / 0.264 → 9.2% |
| Tier | IV (native only): II block radius 1.4 u · III 1.5 s front shield after a Block · IV the blocked barricade takes 5 × power, and a Block can instead catch one turret shot aimed at soldiers within 1.6 u (shares the cd; turrets never target champions) | — |
| Relic Гроза в пляшці / Bottled Storm | +4 Lightning Rod +1 target · +8 block radius +0.1 u · +12 turret catch range +0.4 u | — |

**Fall:** the cloud rains out, the empty armour clatters down, the halo flickers off. **Visual:** a knight's white-enamel
breastplate, pauldrons and closed helm worn by a body of **dark storm cloud** with lightning veins (≈ 1.95 m; a cloud
skirt hides the legs so the humanoid rig works), a **halo of lightning**, a **round aegis shield** and a short
lightning-rod lance; storm grey-violet `#4A4660`, gold, Volt orchid lightning `#EFB5EF`. **COLOR LOCK: topaz** (the
aegis's star-cut centre = heart gem, lance tip). **Special:** shield raised, lightning drawn in; `run` is a glide loop.

### 6.21 C21 `dara` — Дара — Небесна гарпунниця / Dara — Sky Harpooner
Топаз · Ranger · Volt · Dawn Order · human · f · slot **rear**.

**Fantasy:** a storm-whaler from the Sky Harbour whose harpoon pulls fliers down and stitches two squads together.
**Personality:** bold, sardonic, competitive, generous with her crew; hums shanties. **Voice:** pick «Гарпун заряджено —
хто перший?» / "Harpoon's loaded — who's first?" · action «Попався!» / "Gotcha!"

| Part | Rule | f0 Lv1 / f5 Lv20 |
|---|---|---|
| HP | — | 33 / 60 |
| Action — Shot | every 1.2 s, hits Flying | 1.26 / 2.30 dmg |
| Twist — Гарпун-блискавка / Thunder Harpoon | every 3rd shot tethers the hit squad to the nearest other squad ≤ 4 u for 3 s (50% of damage dealt to one also hits the other) and grounds a Flying squad 1.5 s | — |
| Aura (r 1.4) | army volley damage + value × 0.25 | 0.189 → 4.7% / 0.396 → 9.9% |
| Tier | IV: II +1 bolt every 3rd shot · III shots apply JOLT (proc 0.5) · IV every 5th shot pierces 3 | — |
| Relic Лебідка гарпуна / Harpoon Winch | +4 tether +0.5 s · +8 tether share 50% → 60% · +12 grounding 1.5 → 2.0 s | — |

**Fall:** the line snaps and whips back; she drops to one knee, hand on her hat. **Visual:** an athletic woman in her
thirties (≈ 1.75 m), long sky-navy captain's coat `#24324F` with one white-enamel pauldron, brimmed hat with goggles, a
**heavy harpoon-gun** with a drum of coiled copper chain (signature), dark braided hair, Volt orchid stripes. **COLOR
LOCK: topaz** (star-cut harpoon tip, heart gem on the hat band). **Special:** harpoon fire with recoil and a heave.

### 6.22 C22 `menhir` — Менгір — Старійшина рун / Menhir — Rune Elder
Топаз · Mage · Rune · Stoneheart · creature (walking runestone) · n · slot **right** (rear when free).

**Fantasy:** a thousand-year-old standing stone that woke to protect the names carved on it. **Personality:** ancient,
solemn, slow-spoken, unexpectedly tender; speaks in proverbs. **Voice:** pick «Я пам'ятаю кожне ім'я.» / "I remember
every name." · action «Хай буде коло.» / "Let there be a circle."

| Part | Rule | f0 Lv1 / f5 Lv20 |
|---|---|---|
| HP | — | 33 / 60 |
| Action — Spell | every 4 s a rune strike r 1.5 on the densest squad ≤ 12 u: kills per squad + BRAND | 5.04 / 9.19 kills |
| Twist — Рунне коло / Rune Circle | the strike carves a circle for 3 s: squads crossing it are Branded and deal −25% clash damage for 3 s | — |
| Aura (r 1.2) | soldiers in the ring apply BRAND with their volleys at proc value × 0.30 | 0.189 → 5.7% / 0.396 → 11.9% |
| Tier | IV: II radius 2.0 · III structures ×1.5 · IV cd 3.5 s, circle 5 s + a 2 s field (1 kill / 0.5 s) | — |
| Relic Найдавніша руна / Eldest Rune | +4 circle +0.5 s · +8 circle clash cut −25% → −30% · +12 circle radius +0.25 u | — |

**Fall:** topples forward like a felled tree, runes going dark one by one. **Visual:** a tall narrow **standing-stone
slab** body (≈ 2.2 m, the tallest champion silhouette; still 1.10 u in the run by scale), short thick stone legs, long
arms of stacked stones, one deep-set eye-light, frost and moss on the top edge, **three rune tablets orbiting** (separate
meshes, procedural orbit); grey-blue granite `#5A6270`, Rune-indigo grooves `#2E2EB4`. **COLOR LOCK: topaz** (runes
inlaid with topaz, star-cut heart gem). **Special:** palm slam on the road (circle carve).

### 6.23 Faction gear names (`GearData.ITEMS`, numbers §3.4)

| Faction | Зброя / Weapon (`dmg_add`) | Обладунок / Armour (`hp_add`) | Оберіг / Charm (`ult_add` + `charge_add`) |
|---|---|---|---|
| `dawn` | Сонцесталевий клинок / Sunsteel Blade | Емалевий нагрудник / Enamel Cuirass | Світанковий медальйон / Dawn Medallion |
| `wildfang` | Ікло серцевини / Heartwood Fang | Плетена шкура / Woven Hide | Коралове намисто / Coral Beads |
| `stoneheart` | Базальтове вістря / Basalt Edge | Магмова броня / Magma Plate | Льодяне серце / Ice Heart |
| `celestial` | Місячне жало / Moonsilver Sting | Зоряна мантія / Starglass Mantle | Підвіска-орбіта / Orbit Pendant |

Boss trophies reuse these 12 names with a provenance line («Трофей: Кракен / Trophy: the Kraken»). Hero relic names
and beats are on each hero sheet (Сірко's on §6.28); champion relics are on §6.11–6.22 and §6.25–6.27.

### 6.24 Loc appendix — uk lore (`HERO_<ID>_LORE`, `CHAMP_<ID>_LORE`; " / " = line break; en = the sheets)

| id | uk lore |
|---|---|
| titan | Горан був ключовим каменем старого мосту в Магмових копальнях, доки Жаророгі не розкололи його — і камінь прокинувся. / Прозорий кристал у його грудях — дар старійшин Кам'яного Серця, і кажуть, він змінить колір, коли Горан виросте. / Він рахує кожну зламану стіну й ще жодного разу не лишив воїна по той бік воріт. |
| arin | Арін виріс на причалах Небесної гавані, тягаючи вантажні ланцюги, — на меч зброєносця грошей не було. / Коли Жаророгі пішли на абордаж, він вирвав якір із причалу й сам тримав трап, доки не прибув Орден. / Його посвятили в лицарі просто там; якір він лишив собі, а вузли досі в'яже по-докерськи. |
| bolt | Руді народився в норі на скелях над Кораловим рифом, куди влучила блискавка, — відтоді його хутро тріщить. / Старійшини Диких Іклів дали йому золотий крилатий вінець, щоб іскри не підпалювали ліс; не допомогло. / Він веде армію попереду, бо деінде просто не витримує. |
| eira | Ейра доглядала поранених у лазареті орбітального кришталевого храму, де холод був єдиними ліками, що ніколи не закінчувалися. / Вона навчилася настроювати іній, як арфу: одна струна спиняє кров, інша — серцебиття ворожої атаки. / Коли Жаророгі дійшли до Крижаних вершин, вона пішла з армією, бо «в снігу нікого не лишаємо». |
| seer | Мейра доглядала рунні лампи Рунічного лісу, де кожен стовбур — сторінка старої зоряної мапи. / Однієї ночі руна третього ока на її чолі розплющилася сама, і вона побачила, як розривається Розлом, ще до того, як це сталося. / Відтоді вона завжди йде на ряд попереду всіх — і рідко помиляється. |
| iskar | Іскар упав крізь Розлом кометою й прокинувся в зруйнованій обсерваторії Серця Розлому з луком, зітканим із власного світляного хвоста. / Небожителі кажуть, що кожен зореродний полює на світло, яке загубив; Іскар натомість полює на бойові комети Жаророгих. / Він говорить координатами зоряних мап і ніколи не промахується двічі по тій самій цілі. |
| vesta | Веста сама викувала свою глефу в сонячному горні орбітального храму: її лезо — один топаз, що випив цілий полудень. / Шрам на щоці — з дня, коли вона втримала браму храму проти першого набігу Жаророгих; Орден зробив її наймолодшою лицаркою-командувачкою. / Воїни кажуть, що повітря теплішає, коли вона проходить уздовж строю. |
| vartan | Вартана збудували ковалі Кам'яного Серця в Магмових копальнях — із базальту й латуні довкола живого топазового ядра, — щоб він стеріг Великий горн. / Коли Жаророгі затопили копальні, він виніс останніх ковалів на своєму щиті, і вогонь у ньому відтоді не згасав. / Він пережив своїх творців і вважає своїм горном кожного, «хто стоїть за моєю спиною». |
| lumen | Люмен — перше світло, що пройшло крізь Розлом: істота з живого опалу, яка пам'ятає колір кожної зорі. / Там, де воно ступає, біле світло розпадається на барви, а вогонь Жаророгих здається блідим. / Воно не воює за чийсь бік — воно воює, щоб жодна барва не згасла. |
| pava | Пава береже Тисячоокий гай у Рунічному лісі, де кожне пір'я, що впало, стає оком, яке стереже звіролюдей. / Вона бачила кожного воїна, що йшов під стягом Диких Іклів, і жодного обличчя не забула. / Жаророгі звуть її віяло прокляттям гаю, бо те, що вони там зрубали, не лишається лежати. |
| sirko | Сірко — отаман вільного війська Небесної гавані, і за все життя він не програв жодної битви. / Його звуть характерником: стріли Жаророгих його не беруть, а сірим вовком він обганяє їхніх розвідників. / Коли володар Жаророгих звелів йому скоритися, усе військо писало відповідь разом — і реготало так, що орда спинилася. |
| mila | Міла була наймолодшою ученицею лазарету орбітального храму — і завжди першою вибігала в поле. / У її ліхтарі — прозорий кристал, що п'є біль воїнів і повертає його світлом. / Вона підписує кожну пляшечку дрібним почерком і ще не загубила жодної — як і жодного пораненого, якого можна було винести. |
| ivo | Іво доглядав сонячні жаровні орбітального храму й мріяв про лицарство. / Коли лезо Жаророгого цілило Весті в бік, він закрив її кришкою жаровні — і Орден дозволив лишити її як щит. / Він полірує його щовечора, і той ніколи до кінця не холоне. |
| borko | Борко прокопав тунелі під корінням Рунічного лісу, де звіролюди ховають малечу. / Коли Жаророгі пішли маршем по його даху, він виліз просто під ними. / У нього шрам на кожен обвал і жарт на кожен шрам. |
| alba | Альба вартує на найвищій сухій гілці Рунічного лісу, звідки видно обрій над рифом. / Її лук вирізано з білої сосни, у яку влучила блискавка, а тятива — з морозу. / Жоден летун не перетнув її неба — а про того, що перетнув, вона не говорить. |
| otto | Отто старший за найстаріший тунель Магмових копалень, а кришталева фортеця на його спині почалася з одного камінчика. / Дітей Кам'яного Серця вчать ховатися за ним — тепер і воїнів теж. / Він ходить повільно, говорить ще повільніше й жодного разу не ступив назад. |
| taya | Тая випурхнула з Розлому тієї першої ночі, коли розірвалися зорі, — летіла на вогні обсерваторії. / Рунний пилок із її крил присипляє все, що дихає: вона пускає його на Жаророгих — і на воїнів, які не можуть заснути перед боєм. / З кожного світу вона забирає по колисковій. |
| brant | Брант вилупився з жеоди в Магмових копальнях, коли по ній ударив молот Жаророгого. / Він народився злим і квапливим, тож ковалі дали йому два клинки, щоб він перестав битися кулаками. / Аметист у його грудях сяє тим яскравіше, чим ближче бій, — він зве це своїм серцебиттям. |
| teo | Тео складав мапу неба в обсерваторії Розлому, коли зорі почали падати крізь нього. / Він перетворив телескоп на арбалет, а зоряні зонди — на розвідників, і тепер наносить на мапу схованки Жаророгих. / Кожен загублений зонд він називає на ім'я й записує в нотатник. |
| olena | Олена ходить високими стежками між Рунічним лісом і Крижаними вершинами й збирає трави, що ростуть лише під снігом. / Дзвоники на її рогах дзвенять нотою, що вгамовує гарячку — і атаку. / Кожне село звіролюдей тримає біля дверей миску солі — раптом вона завітає. |
| nimb | Німб — гроза, що пройшла крізь Розлом і вирішила лишитися; Небожителі дали їй обладунок, щоб вона мала форму. / Він п'є блискавки: леза й розряди, націлені на воїнів, вигинаються до нього й зникають у хмарі. / Коли він задоволений, то гуркоче — і воїни навчилися вважати це добрим знаком. |
| dara | Дара була капітанкою китобійного човника в Небесній гавані й полювала на грозових скатів між хмарами. / Тепер вона полює на планери Жаророгих: її гарпунний трос стягує летуна з неба й зшиває два загони докупи. / Вона виграє кожен двобій на руках на причалах — Аріна теж. |
| menhir | Менгір тисячу зим стояв на перевалі Крижаних вершин, і Кам'яне Серце вирізало на ньому свою історію. / Коли Жаророгі спробували його звалити, руни прокинулися — і він пішов. / Він пам'ятає кожне ім'я, вирізане на ньому, і читає їх уголос перед кожним боєм. |
| taras | Тарас прийшов у Рунічний ліс із торбою книжок і навчив звіролюдей записувати власні пісні. / Його слово не горить: коли Жаророгі підпалили ліс, сторінки його книжок знялися в повітря й розтяли полум'я, мов леза. / Він вірить, що вчасно сказане слово сильніше за будь-яку зброю, — і кожен бій починає з рядка. |
| snaryad | Снаряд був найменшим цуценям у псарні Небесної гавані, а нюх мав найкращий у всьому Ордені Світанку. / Він чує пастку Жаророгих за три кроки й знешкоджує її раніше, ніж до неї ступить бодай один воїн. / Кожне висмикнуте запобіжне кільце він носить на грудях, як медаль, — і щоразу чекає, що його назвуть молодцем. |
| dovbush | Довбуш — син гір: він виріс на перевалі Крижаних вершин, і скелі Кам'яного Серця досі звуть його своїм. / Він забирає в жорстоких ватажків Жаророгих награбоване й віддає тим, кого вони пограбували, а прості стріли його не беруть. / Його бартка летить туди, куди він покаже, — і завжди повертається до руки. |

Champion en lore (3 lines each, same order as uk; en for heroes is on the hero sheets):
**mila** Mila was the youngest apprentice in the orbital temple's infirmary, and always the first one out to the field. /
Her lantern holds a clear crystal that drinks the soldiers' pain and gives it back as light. / She labels every vial in
tiny handwriting and has never lost one — nor any patient who could still be carried. **ivo** Ivo tended the
sun-braziers of the orbital temple and dreamed of knighthood. / When an Emberhorn blade came for Vesta's flank he blocked
it with a brazier lid, and the Order let him keep it. / He polishes it every evening, and it never quite cools down.
**borko** Borko dug the tunnels under the Rune Forest roots where the beast-kin hide their cubs. / When the Emberhorn
marched over his roof, he came up underneath them. / He has a scar for every collapse and a joke for every scar.
**alba** Alba keeps watch from the highest snag of the Rune Forest. / Her bow is carved from a lightning-struck white
pine and strung with frost. / No flier has crossed her sky — and she does not talk about the one that did. **otto** Otto
is older than the oldest tunnel of the Magma Mines; the fortress on his back began as one pebble. / Stoneheart children
are taught to hide behind him — now so are the soldiers. / He walks slowly, speaks slower, and has never stepped back.
**taya** Taya drifted out of the Rift on the night the stars tore, following the observatory lamps. / Her rune-dust puts
anything that breathes to sleep — the Emberhorn, and soldiers who cannot sleep before a battle. / She collects a lullaby
from every world she passes. **brant** Brant cracked out of a geode when an Emberhorn hammer struck it. / He was born
angry and in a hurry, so the smiths gave him two blades to stop him using his fists. / The amethyst in his chest glows
brighter the closer the fight — he calls it his heartbeat. **teo** Teo was mapping the sky from the Rift observatory
when the stars began to fall through it. / He turned his telescope into a crossbow and his probes into scouts. / He
names every probe he loses and keeps the list in his notebook. **olena** Olena walks the high trails between the Rune
Forest and the Frost Peaks, gathering herbs that grow only under snow. / The bells on her antlers ring a note that slows
a fever — and a charge. / Every beast-kin village keeps a bowl of salt by the door in case she passes. **nimb** Nimb is a
thunderstorm that came through the Rift and decided to stay; the Celestials gave it armour to hold a shape. / It drinks
lightning — blades and bolts aimed at the soldiers bend toward it and vanish. / When it is content it rumbles, and the
soldiers take that as a good omen. **dara** Dara captained a whaling skiff in the Sky Harbour, hunting storm-rays. / Now
her harpoon line pulls Emberhorn gliders out of the sky and stitches raiding parties together. / She wins every
arm-wrestling match on the piers, Arin's included. **menhir** Menhir stood on the Frost Peaks pass for a thousand winters
while the Stoneheart carved their history into it. / When the Emberhorn tried to pull it down, the runes woke and it
walked. / It remembers every name carved into it and reads them aloud before each battle. **taras** Taras came to the Rune
Forest with a satchel of books and taught the beast-kin to write their own songs down. / His word does not burn: when
the Emberhorn set the forest alight, the pages of his books rose into the air and cut the flames like blades. / He
believes a word spoken in time is stronger than any weapon, and he opens every battle with a line. **snaryad** Snaryad was
the smallest pup in the Sky Harbour kennels and had the keenest nose in the whole Dawn Order. / He smells an Emberhorn
trap three steps away and defuses it before a single soldier sets foot on it. / He wears every safety ring he has pulled
on his chest like a medal, and every time he waits to be called a good boy. **dovbush** Dovbush is a son of the
mountains: he grew up on the Frost Peaks pass, and the Stoneheart rocks still call him their own. / He takes back what
the cruel Emberhorn chieftains have plundered and returns it to those they robbed, and ordinary arrows cannot touch him.
/ His bartka flies wherever he points, and it always comes back to his hand.

**Skill-name keys:** heroes `ULT_<ID>` (starters keep `ULT_STORM`, `ULT_QUAKE`, `ULT_RIFT`), `ATK_<ID>`, `RALLY_<ID>`,
`AWK_<ID>`, beats `ATK_<ID>_B3/B6/B9`, forms `ULT_<ID>_F2…F5` (names = the bold names on each sheet); champions
`ACT_<ID>` (twist names above), `AURA_<CLASS>`, `CHAMP_<ID>_ROLE`; relics `RELIC_<ID>`; gear `GEAR_<FACTION>_<SLOT>`.
`_DESC` lines (≤ 90 characters) are Loc templates filled from data (`%d`/`%s`), never literal numbers.


### 6.25 C23 `taras` — Тарас — Кобзар / Taras — the Kobzar (committed look)
Топаз · Mage · Rune · Wildfang · human · m · slot **rear** (→ right if a Ranger holds the rear) · joined after launch
(owner request 2026-10-09); Hero Chests only, like every champion. The common rules of §6.11–6.22 apply.

**Fantasy:** a kobzar, a poet and painter who carries the word of his people; his heavy books are bound in brass and
topaz, strike like stones and burst into pages that cut like blades. A tribute to Taras Shevchenko (1814–1861), the
Ukrainian national poet, drawn after his 1860 etched self-portrait in a fur cap and sheepskin coat (from A. Denier's
1858 photograph). **Tone (binding):** he is revered; every line about him is
respectful and dignified, never a joke at his expense, no political slogans, no quotations turned into catchphrases.
**Personality:** calm, wise, warm with the young, stern with cruelty; speaks little, and every word lands. **Voice:**
pick «Слово не згорить.» / "A word does not burn." · action «Слово!» / "The Word!"

| Part | Rule | f0 Lv1 / f5 Lv20 |
|---|---|---|
| HP | — | 33 / 60 |
| Action — Spell | every 4 s a heavy book thrown at the **nearest** squad ≤ 12 u ahead (not the densest): r 1.5, kills per squad + BRAND | 5.04 / 9.19 kills |
| Twist — Слово / The Word | on impact the book bursts into pages that cut on through the squad: the next squad behind it ≤ 3 u in the throw line takes 50% of the kills and BRAND *(knob: the 50% page share)* | — |
| Aura (r 1.2) | soldiers in the ring apply BRAND with their volleys at proc value × 0.25 (rear) | 0.189 → 4.7% / 0.396 → 9.9% |
| Tier | IV (native only): II radius 2.0 · III structures ×1.5 · IV cd 3.5 s, the pages leave a 2 s field (1 kill / 0.5 s) | — |
| Relic Перо поета / The Poet's Quill | +4 page line +1 u · +8 page share 50% → 60% · +12 page field +0.5 s | — |

**Fall:** he sinks to one knee with the open book pressed to his chest; loose pages settle around him like snow.
**Visual (the owner's card, `assets/heroes/taras/`):** a man in his forties (≈ 1.78 m, realistic proportions), grey
lambskin hat, long drooping moustache, brown sheepskin coat with cream fleece trim, white vyshyvanka with red and black
cross-stitch, a **Rune-indigo sash** `#2E2EB4` with Wildfang **coral beads**, dark trousers, tall boots; a **heavy
brass-cornered book raised to throw** (signature), an open book held to the chest, a third book on a strap. **COLOR
LOCK: topaz** (the star-cut golden topaz on the open book's clasp = heart gem; no other crystals). Card: the book raised
to throw. **Special:** two-handed overhead throw; the pages burst in a fan.

**Why these tags (coverage note):** Топаз · Mage · Rune repeats Менгір's gem, class and element (only the faction and
the slot differ), and Mage / Rune become the largest tags (5 each) while Frost and Tech stay at 3; a Топаз Warrior or
Healer of Frost or Tech would have filled thinner cells. The owner's concept (a book thrower whose word cuts through a
squad) is a Mage Spell, so the tags stay; no §5 rule forbids them. Designed pair: Мейра + Тарас (Wildfang + Mage pair +
Rune ×2).

### 6.26 C24 `snaryad` — Снаряд — Пес-сапер / Snaryad — the Sapper Hound (committed look)
Аметист · Guardian · Tech · Dawn Order · beast (Jack Russell terrier-kin) · m · slot **front** · joined after launch
(owner request 2026-10-09); Hero Chests only, like every champion. The common rules of §6.11–6.22 apply.

**Fantasy:** a small dog with a very big heart: the Dawn Order's sapper hound, who sniffs out the traps the Emberhorn
hide on the road, defuses each one before a soldier steps on it and carries the charge back to its owners. Inspired by
the famous Ukrainian sapper-dog meme and hyperbolised a little; the owner named him «Снаряд». The real dog's name, any
emergency-service name or insignia, real mines, the war and the real dog's story never appear anywhere a player can see;
his traps are the Emberhorn horde's fantasy blade, spike and barricade traps. **Tone (binding):** affectionate and
proud, a little funny in his seriousness (a big hero, just not a tall one); never a joke at his expense, no war, no
politics. **Personality:** earnest, brave and very serious about his work; proud of every ring, and happiest when
praised. **Voice:** pick «Гав! Чисто!» / "Woof! All clear!" · action «Хто тут найкращий сапер? Я!» / "Who's the best
sapper? Me!"

| Part | Rule | f0 Lv1 / f5 Lv20 / recut Топаз |
|---|---|---|
| HP | takes the front clash share (fractional accumulator) | 70 / 128 / 132 |
| Action — Block | the template, but the Block **reaches ahead**: he dashes up to 3 u ahead of the crowd and defuses the first blade / spike / barricade contact before the soldiers touch it (0 losses; the stamp reads «ЧИСТО!» / "ALL CLEAR!" instead of «БЛОК»), then trots back to his slot; cd 5 s → **6 s** *(knob)* | — |
| Twist — Нюх сапера / Sapper's Nose | the defused charge is carried and dropped on the nearest enemy squad ≤ 6 u ("Гав — бум!"): 2 × power kills *(knob)* + MARK 3 s; this replaces the template's +1 kill | 2.33 / 4.26 / 4.41 kills |
| Aura (r 1.0) | clash losses − value × 0.35 (front) | 0.117 → 4.1% / 0.245 → 8.6% |
| Tier | III: II block radius 1.4 u · III after a Block a 1.5 s front shield (the next clash tick costs 0) | — |
| Relic Перше кільце / The First Ring | +4 dash reach +1 u · +8 MARK +1 s · +12 Block cd −0.5 s | — |

Budget: (≈ 4 soldiers saved + 2 kills) per 6 s ≈ the template's (4 + 1) per 5 s; MARK is the twist. The cooldown and the
charge kills are the knobs that keep `KIT_INDEX` = P0_c ± 3%. The relic is the first safety ring he ever pulled.

**Fall:** he lies down and covers his nose with his paws; the tail still wags, weakly. **Visual (the owner's card and
splash, `assets/heroes/snaryad/`):** an upright, heroically barrel-chested Jack Russell terrier-kin (≈ 1.40 m, plausible
anatomy, short powerful legs): white fur, tan-brown ears and eye patches, a white blaze, a black nose, a white tail with a
tan base; a polished **white-enamel sapper helmet** with a gold rim; a white-enamel cuirass with gold filigree over a
cream quilted tunic with gold trim; **small gold rings worn like medals** on the left chest (pulled safety rings, one per
cleared trap); a gold-and-leather **bandolier of five amethyst crystals** in short gold casings ("cartridges"); a brown
leather belt; a short cream half-cape with gold embroidery over the right shoulder; one brown leather glove on the right
paw; brown leather ankle wraps; a round **white-enamel detector-disc shield** with gold concentric rings and an amethyst
cabochon at the centre on the left arm; a long **brass detector probe** with a leather-wrapped grip, two Tech signal-lime
rings and a brass point. **COLOR LOCK: amethyst** (the kite-cut amethyst in the belt buckle = heart gem; the bandolier
crystals and the shield cabochon). Card: the proud guard, shield braced, probe upright like a standard. **Special:** a
nose-up sniff, then a dash ahead and a proud sit.

**Why these tags (coverage note):** no Аметист Guardian champion existed (Аметист had a Warrior, a Ranger and a Healer)
and Tech had three members; Снаряд fills both. Орден Світанку goes from 3 to 4 champions (§5.3: 3–4 holds), Аметист from
3 to 4. Designed pairs: Вартан + Снаряд (Guardian pair + Tech ×2) · Веста + Снаряд (Dawn + FLARE: his MARK, her BURN).

### 6.27 C25 `dovbush` — Довбуш — Опришок / Dovbush — the Carpathian Rebel (committed look)
Топаз · Warrior · Kinetic · Stoneheart · human · m · slot **front** (→ left behind a Guardian) · joined after launch
(owner request 2026-10-09); Hero Chests only, like every champion. The common rules of §6.11–6.22 apply.

**Fantasy:** the leader of the mountain rebels and a son of the mountains: he takes from the cruel and gives to the poor,
leaps over gorges, and his bartka (a Hutsul axe on a long haft) flies where he points and comes back to his hand. A
tribute to Oleksa Dovbush (1700–1745), the legendary leader of the Carpathian opryshky, "the Carpathian Robin Hood"
(legend: ordinary bullets could not harm him; Dovbush's Rocks carry his name). The face is original: it is not modelled
on any actor, and no film or actor is named or referenced anywhere. **Tone (binding):** heroic, folk legend, admiring; no
guns, no blood, no politics. **Personality:** reckless, generous, laughing in danger; kind to the weak, merciless to the
cruel. **Voice:** pick «Гори — мої!» / "The mountains are mine!" · action «Лети, бартко!» / "Fly, bartka!"

| Part | Rule | f0 Lv1 / f5 Lv20 |
|---|---|---|
| HP | — | 60 / 110 |
| Action — Cleave | the template: +0.07 kills per FIGHT_TICK in his clash | — |
| Twist — Бартка / The Bartka | instead of the leap, every 5 s *(knob)* he hurls the bartka down the lane: it flies through the first two squads ≤ 6 u ahead, 1.5 × power kills in each *(knob)* + STAGGER, and spins back to his hand; "Robin Hood": its first target is always the most armoured squad in range | 1.89 / 3.45 kills per squad |
| Aura (r 1.1) | squads in contact lose + value × 0.35 (front) | 0.126 → 4.4% / 0.264 → 9.2% |
| Tier | IV (native only): II +0.5 kills per squad, reach 7 u · III the STAGGER also catches squads ≤ 1 u of the bartka's path · IV cleave hits 2 squads in contact; bartka cd 4 s | — |
| Relic Зачарований черес / The Charmed Belt | +4 the first clash hit on him each level costs 0 HP · +8 bartka reach +1 u · +12 bartka cd −0.5 s | — |

Budget: 2 squads × 1.5 kills per 5 s = the template leap's 3 kills per 5 s, at a longer reach; STAGGER is the twist (the
template applies the element status only from tier III). The per-squad kills and the cooldown keep `KIT_INDEX` = P0_c ±
3%. The relic is the charmed belt of the legend that ordinary bullets could not touch him.

**Fall:** he drops to one knee and plants the bartka; his hat falls. **Visual (the owner's card, `assets/heroes/dovbush/`):**
an original face (not modelled on any actor): a handsome, weathered man of about thirty (≈ 1.85 m, realistic
proportions), long dark-brown hair, a thick dark moustache, a scar through the left eyebrow, grey eyes, a reckless grin;
a black felt **kresania hat** with a studded, beaded band and black-and-white feathers; a white linen shirt with
red-orange-yellow-black Hutsul embroidery; an open **keptar** vest (leather with red and green appliqué, brass studs,
tassels); a very wide studded leather **cheres belt** with buckles and two leather pouches; a heavy shaggy dark-brown
**hunia cloak** with pale-copper edging and a long fringe; dark trousers, leather leg wraps; the **bartka** (a
wooden-hafted axe) on his right shoulder (signature); his left arm thrust forward, pointing at the target. **COLOR LOCK:
topaz** (the pear-cut golden topaz in the cheres = heart gem; no other crystals). Card: the bartka on the shoulder, the
left arm pointing at the target. **Special:** a spinning bartka throw.

**Why these tags (coverage note):** Топаз had two Mages (Менгір, Тарас), a Guardian and a Ranger and no Warrior champion
(the coverage note of §6.25); Довбуш fills it. Kinetic goes from 4 to 5, Кам'яне Серце from 3 to 4 champions ("son of the
mountains"; §5.3: 3–4 holds), Топаз from 4 to 5. Designed pairs: Горан + Довбуш (Stoneheart + Kinetic ×2: STAGGER twice) ·
Арін + Довбуш (Warrior pair + Kinetic ×2).

### 6.28 H26 `sirko` — Сірко — Характерник / Sirko — the Charmed Otaman (committed look)
Опал · Warrior · Rune (+ Tech in form V) · Dawn Order · human · m · ult `letter` · Portal (the Opal share, now among 3) /
Seals 200 · **born awakened** · the 11th hero, joined after launch (owner request 2026-10-09; collector № 26, numbers
follow the joining order). Opal now holds three heroes of three classes (Люмен Mage, Пава Healer, Сірко Warrior). The
Opal rules of §6.9–6.10 apply: born with all four skills, ult forms to V.

**Fantasy:** the unbeaten, laughing otaman of the Sky Harbour's free host: a kharakternyk (a warrior-sorcerer charmed
against harm) whose mocking letter stops the horde in its tracks. A tribute to Ivan Sirko (d. 1680), the legendary kosh
otaman of the Zaporizhian Sich, said never to have lost a battle; legend calls him a kharakternyk charmed against
bullets, and the mocking reply letter (painted by Repin) is famous. In the game the letter goes to the lord of the
Emberhorn horde, and its text is never shown. **Tone (binding):** proud, witty, legendary; no insult to any real nation or
religion, no politics, no firearms anywhere a player can see. **Lore (en):** the otaman of the Sky Harbour's free host,
who has never lost a battle; Emberhorn arrows cannot touch the kharakternyk, and as a grey wolf he outruns their scouts;
when the Emberhorn lord ordered him to surrender, the whole host wrote the answer together and laughed so hard the horde
stopped. **Personality:** proud, sly, booming; laughs loudest when the odds are worst; a father to his host.
**Voice:** pick «Сірко ще не програвав!» / "Sirko has never lost!" · ult «А ну, хлопці, пишемо відповідь!» / "Right,
lads — let's write him an answer!"
**Run:** sabre cuts (rate 1.7, range 11, splash 2 in a 1.5 u arc); every hit BRANDs (the element status on hit, as
Арін's STAGGER and Веста's BURN). Warrior Cleave ×1.5 in clashes. **Tip:** «Пускай лист перед найщільнішим рядом загонів
— регіт спинить їх до сутички.» / "Send the letter just before the densest row of squads — the laughter stops them before
the clash."

| Skill | uk / en | Rule |
|---|---|---|
| Ult `letter` (42) | Лист султанові / The Letter to the Sultan | **Form I:** he raises the letter and a huge parchment scroll unrolls over the lane from 3 u to 15 u ahead, the full bridge width, for 2.0 s; the whole army roars with laughter: every squad under it loses 16 *(knob)*, is Staggered 2.0 s and Branded; every structure under it takes 16 breaks; at the siege the scroll lands on the fortress and its walls take the breaks. The parchment shows only abstract lines and a wax seal (the text is never shown). **Form II — Warrior rule:** the scroll reaches 4 u further (to 19 u), and squads caught lose +20% *(knob)* in their next clash. **Form III Другий регіт / The Second Roar:** 1.0 s later a second laughter pulse under the scroll: 8 kills / 8 breaks *(knob)* per squad, the Stagger refreshed. **Form IV Без обладунків / Stripped of Armour:** squads caught lose their armour (Armored and Shielded fight as plain squads) for 5 s. **Form V Уся Січ пише / The Whole Sich Writes (Опал; + Tech):** for 5 s every army volley Brands and Marks its target (MARK + BURN = FLARE with a Plasma teammate) — no fire-rate buff, no Apex charge (critique B3). The scroll is drawn at α ≤ 0.5 over gate panels and the camera beat is ≤ 8% FOV push-in, ≤ 0.6 s, so the next gate row stays readable (§10.2). |
| Attack | Козацька шабля / Cossack Sabre | sabre cuts, splash 2 in a 1.5 u arc, BRAND on every hit · **beat 3 Подвійна рубка / Double Cut:** every 4th hit strikes twice · **beat 6 Сміх отамана / The Otaman's Laugh:** when he wipes a Branded squad, the next squad in his lane flinches (STAGGER 1 s) · **beat 9 Вихор шаблі / Sabre Whirl:** every 10th hit a sabre whirl r 3: 6 per squad *(knob)* + BRAND |
| Rally `army_recruits` | Січ на поміч / The Sich Comes to Help | +1 soldier joins every recruit group the army picks up × ladder × rank (the free hook of §5.4) |
| Awakening (born; cap 4) | Заговорений / Charmed | the legend that bullets could not touch him: at the siege the fortress's first 1 / 2 / 3 / 4 volleys at the army miss (a missed volley costs 0 soldiers) |
| Relic | Перо писаря / The Scribe's Quill | +4 the scroll +2 u longer · +8 Stagger under the scroll +0.5 s · +12 The Whole Sich Writes +1 s |

| Rank (eff) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Laughter kills & breaks per squad / structure | 21.8 | 22.9 | 23.9 | 25.0 | 26.1 | 27.2 | 28.3 | 29.4 | 30.5 | 31.6 | 33.8 |
| Second Roar (form III) | — | — | — | — | 13.1 | 13.6 | 14.1 | 14.7 | 15.2 | 15.8 | 16.9 |
| Ult form | I | I | II | II | III | III | IV | IV | V | V | V |
| Attack damage per hit | 4.08 | 4.12 | 4.16 | 4.20 | 4.24 | 4.29 | 4.33 | 4.37 | 4.41 | 4.45 | 4.65 |
| The Sich Comes to Help (soldiers per recruit group) | 1.4 | 1.5 | 1.6 | 1.8 | 1.9 | 2.0 | 2.2 | 2.3 | 2.4 | 2.6 | 2.8 |

Budget: forms II–IV are rules at +3% ult effectiveness each and form V +5% (§2.3); Attack beats +1% each; Awakening +4%
per rank, measured by the army's siege losses; relic beats +3% each; the Rally base is the §5.4 parity base (+1 per recruit
group ≈ 3 Barracks levels, `test_rally_parity` ±5% once LevelSim lands). The knobs marked *(knob)* keep his `KIT_INDEX`
profile within ±1.5% of P0 at every reference state (`test_kit_budget`). Rule #3: a recut into Opal holds forms I–IV at
most, Awakening cap 3 and rank cap 10 against his V, 4 and 11.

**Interactions:** BRAND on every hit; form V MARKs for the machines (MARK + BURN = FLARE with Веста, Брант, Іво); Dawn
Order (4 heroes now) = the siege team, and his Rally feeds the recruits; Warrior pair with Борко / Брант / Довбуш.
**Counterplay:** ★ dense rows of squads, armoured hordes (form IV) and sieges; short range, no answer to fliers.
**Visual (the owner's splash, `assets/heroes/sirko/`):** a powerful, weathered, laughing Cossack otaman of about fifty,
realistic 7.5–8 heads, broad-shouldered; a shaved head with one long grey-streaked forelock (oseledets) curled back over
the ear; a long drooping grey-streaked moustache; bushy brows, sharp grey eyes, head tilted back in a broad mocking laugh;
a **silver-grey wolf-pelt mantle** with the wolf's head on his right shoulder (the kharakternyk who could become a wolf),
fastened by a gold clasp; a deep crimson `#8E1B2B` **zhupan** with gold embroidery and frogging over a white linen shirt;
a very wide rune-indigo `#2E2EB4` silk **sash** with gold stripes and long fringed ends; enormous deep-indigo
**sharovary** (a heroic exaggeration); red leather boots; a curved **sabre** with a gold hilt and an opal in the pommel,
held low in his right hand; a long **parchment letter** with a wax seal and a dangling cord raised in his left hand (no
readable text, only abstract lines). **COLOR LOCK: opal** (the round black-opal heart gem in the gold clasp of the wolf
pelt — a round cut, not the marquise of §2.1, as on the owner's splash; the opal in the sabre pommel). Splash P2 Advance.
**Clips:** idle (twists his moustache, chuckles) · run (wide confident stride, the sharovary and sash ends flapping) ·
attack_a diagonal sabre cut · attack_b turning double cut · ult_cast (unrolls the letter overhead and roars with
laughter; the big scroll over the lane is code) · hit · victory (laughs with the letter held high) · flourish (sabre
twirl, moustache twist) · summon_pose. Forelock, sash ends and slit sleeves: scripted bones + `SpringBoneSimulator3D`;
the wolf head is rigid on the shoulder. **Signature beat:** he unrolls the letter toward the camera with a booming laugh;
the wax seal flashes opal.

**Why these tags (coverage note):** Opal had a Mage and a Healer; Сірко adds its first Warrior (the heroes of a gem never
share a class). Rune goes from 5 to 6, Warrior from 5 to 6, and Орден Світанку from 3 to 4 heroes (§5.3 now 2–4 heroes,
like the champions' 3–4). His Rally takes the free `army_recruits` hook (§5.4). Designed pairs: Сірко + Довбуш (Warrior
pair + STAGGER twice) · Сірко + Тарас (Rune ×2: the Letter and the Word).

## 7. Portal, Seals, Hero Chests, Workshop, odds and pity

Everything random in this section is **earned by play only** (P2). All odds below are printed by `heroes_sim.py` §3–§4
(exact tables + Monte Carlo) and are the rows the (i) sheets show, generated by `tools/odds_table.gd --portal|--chest`;
`odds_table --check` re-runs a 1 000 000-roll Monte Carlo **per character** and fails at |z| > 4.

### 7.1 «Портал / Portal» (`PortalData`, unlock L20)

| Item | Rule |
|---|---|
| Cost | 1 Маяк / Beacon = 1 summon; ×10 = 10 Beacons. **No discount, no bonus summon** — every summon has the same odds, pity step and +1 Seal, so summoning daily is never worse than hoarding. |
| Pool | one permanent Portal; every hero (11 since Сірко) minus the starters the player owns; new heroes join the permanent pool (changelog lists the odds change); never a banner, date or timer |
| Welcome | one free ×10 at the unlock with the disclosed rule **«Серед десяти — щонайменше Топаз» / "At least one Topaz in these ten"**: if summons 1–9 hold no Topaz+, the 10th is Topaz+ (Opal 20% inside it). The free ×10 gives +10 Seals and moves pity like any ×10. |
| Duplicate protection | an unowned eligible hero of the rolled gem first |
| Focus | player-chosen per gem, any time, free: once every hero of that gem is owned, the Focus hero gets **exactly 60%** of that gem's results and the others share 40% evenly, for any roster size (`FOCUS_TOTAL 0.60`). Copy «Фокус: 60% результатів цього самоцвіту». |
| Ceremony | Quartz 1.2 s · Sapphire 1.8 s · Amethyst / Topaz / Opal walkouts 0.6 + 2.6 / 3.6 / 5.0 s, skippable from 0.5 s; a ×10 shows one summary grid after the best walkout (§9.4) |

### 7.2 Disclosed odds (sim §3, 1 000 000 summons)

| Gem | Base per summon | Consolidated (exact, stationary pity chain) | Monte Carlo | 1 in |
|---|---|---|---|---|
| Кварц | 55.00% | 52.09% | 52.08% | 1.9 |
| Сапфір | 28.00% | 26.52% | 26.52% | 3.8 |
| Аметист | 12.00% | 14.35% | 14.37% | 7.0 |
| Топаз | 4.00% | 5.63% | 5.64% | 17.8 |
| Опал | 1.00% | 1.41% | 1.40% | 71.1 |
| **Топаз or better** | 5.00% | **7.03%** | 7.04% | **14.22** |
| **Аметист or better** | 17.00% | 21.39% | 21.41% | 4.68 |

Monte Carlo vs exact: max |z| 0.80, χ²(4 df) 0.94. **Pity**, shown verbatim (uk / en):
- «Аметист або краще — щонайпізніше на 10-му призові» / "Amethyst or better by your 10th summon at the latest".
- «Топаз або краще: шанс росте з 21-го призову (+7% щоразу) і гарантований на 30-му» / "Topaz or better: the chance
  rises from your 21st summon (+7% each time) and is certain on the 30th".
- Inside a Topaz-or-better result: Опал 20%, Топаз 80%. No Opal pity — Seals cover the tail (§7.4).

Topaz+ chance by summon count since the last Topaz+: 1–20: 5% · 21: 12% · 22: 19% · 23: 26% · 25: 40% · 27: 54% ·
29: 68% · 30: 100%. Measured gaps: Amethyst+ mean 4.67, max 10; Topaz+ mean 14.2, p50 14, p90 25, max 30; Opal mean 71.6,
p50 52, p90 158, longest 758 in 1 000 000 (why 200 Seals buy any Opal).

| Best gem in one ×10 | Аметист | Топаз | Опал |
|---|---|---|---|
| Welcome ×10 (disclosed Topaz+ rule) | 0% | 78.46% | 21.54% |
| Fresh pity, no rule (reference) | 59.87% | 30.56% | 9.56% |
| Typical ×10 (stationary pity) | 43.56% | 42.99% | 13.45% |

**Per-hero odds** (the (i) sheet lists every eligible hero's current %, KR item-level disclosure; sim §3b):

| Stage | Горан C | Арін C | Руді R | Ейра R | Мейра E | Іскар E | Веста L | Вартан L | Люмен M | Пава M | Сірко M |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A. Portal opens (L20): own Руді, Горан | 0% | 52.09% | 0% | 26.52% | — (joins L24) | 14.35% | 2.81% | 2.81% | 0.47% | 0.47% | 0.47% |
| B. Мейра joined; one hero of each gem owned (Веста, Люмен) | 26.05% | 26.05% | 13.26% | 13.26% | 7.18% | 7.18% | 0% | 5.63% | 0% | 0.70% | 0.70% |
| C. all 11 owned, no Focus | 26.05% | 26.05% | 13.26% | 13.26% | 7.18% | 7.18% | 2.81% | 2.81% | 0.47% | 0.47% | 0.47% |
| D. all 11 owned, Focus = Горан / Руді / Мейра / Веста / Люмен | 31.26% | 20.84% | 15.91% | 10.61% | 8.61% | 5.74% | 3.38% | 2.25% | 0.84% | 0.28% | 0.28% |

**Per-hero odds of one summon, every hero of the gem owned** (printed by `odds_table --portal`, checked by `--diff`
against `DISCLOSED_HERO` and by `--check` per hero through `Summon.pick_hero` at stages A–D):

| Gem | Heroes | Each, no Focus | Focus | Each other |
|---|---|---|---|---|
| Кварц | 2 | 26.05% | 31.26% | 20.84% |
| Сапфір | 2 | 13.26% | 15.91% | 10.61% |
| Аметист | 2 | 7.18% | 8.61% | 5.74% |
| Топаз | 2 | 2.81% | 3.38% | 2.25% |
| Опал | 3 | 0.47% | 0.84% | 0.28% |

H26 Сірко joined the Opal pool (2 → 3 heroes): each Opal hero 0.70% → 0.47%, each non-Focus Opal hero 0.56% → 0.28%
(the Focus keeps exactly 60% of the gem, 0.84%); these two rows are in the odds changelog (§7.5). The gem odds, the pity,
the ×10 tables, the welcome rule, the Seal prices and the Opal share inside Topaz+ are unchanged: a new hero only splits
its gem's share.

Meta-1 machine Focus adopts the same "exactly" wording in this release (`FOCUS_TOTAL 0.40` for machines, the Deck ×1.5
applied to the remainder only; copy «Фокус: 40% результатів цієї рідкості»), so both rollers disclose a fixed share.

### 7.3 «Маяки / Beacons» — the only Portal currency (earned only)

| Source (fixed nodes) | Beacons |
|---|---|
| First-clear win (campaign, Invasion, Nightmare) | +0.2 (the fraction banks in `beacon_charge`) |
| World-boss first clear (campaign + Invasion) | +2 |
| Daily missions | +⅓ each (3 a day, banks 3 days) |
| Weekly 5/5 | +4 |
| Expedition 3/5 · 5/5 | +1 · +2 |
| Login cycle, day-7 card | +1 |
| Welcome ×10 | 10 free summons (not Beacons) |

**Never a Beacon source:** Feats (hero Feats pay Tomes, §3.6), Arsenal Track nodes, the Road (either lane), replays,
rewarded ads, `supporter` ×2, any SKU, Gems, any random chest. `test_two_track_property` (§12.6) proves it on same-seed
runs. Measured income per day is in §8.4.

### 7.4 «Печатки / Seals», duplicates, overflow

| Item | Value |
|---|---|
| Seals per summon | +1 (×10 = +10, welcome = +10); never expire; Seal picks give no Seals and move no pity |
| Seal shop | any eligible hero of Аметист **40** · Топаз **100** · Опал **200** Seals |
| Owned pick | **2 × that hero's duplicate fragments**: 50 / 100 / 200 (1.25 / 1.00 / 1.00 fragments per Seal) — one owned Opal pick = one full Opal Full facets (the Opal-tail answer) |
| Duplicate → fragments | `DUP_FRAGS[native]` 10 · 15 · 25 · 50 · 100; expected 17.0 fragments per summon (170 per ×10) once the roster is owned |
| Overflow at the absolute max | 20 fragments = 1 Tome (`OVERFLOW_FRAGS_PER_TOME`) |

### 7.5 «Скриня героїв / Hero Chest» and «Велика скриня героїв / Grand Hero Chest» (`PortalData.CHESTS`, unlock L14)

| | Hero Chest | Grand Hero Chest |
|---|---|---|
| Sources | `chest_charge += 1/3` per win from L14 (campaign, Invasion; replays: only the first 3 replay wins a day) | world-boss first clear (campaign + Invasion), weekly 5/5, Expedition 5/5 |
| Champion cards | 2, each Кварц 62% · Сапфір 27% · Аметист 9% · Топаз 2% | 3, the last drawn among Аметист+ only |
| Hero-fragment card | 1 owned hero (**team hero ×2 weight**, disclosed): `round(0.15 × DUP)` = 2 / 2 / 4 / 8 / 15 | the same × 2 |
| Tomes | none | 2 (after L30) |
| Best card (exact, no pity) | Кварц 38.44% · Сапфір 40.77% · Аметист 16.83% · Топаз 3.96% | Аметист 78.58% · Топаз 21.42% |
| Pity | a Топаз champion card by the 15th chest without one (both kinds count; hard) | same counter |
| Inside a gem | unowned champion first; a complete gem → the champion Focus gets **exactly 60%**, the others share 40% evenly (20% each of two; 13.33% each of three in Аметист; 10% each of four in Топаз) | same |
| Reveal | inline on the result screen: **1.6 s**, 1.2 s when nothing is NEW; a NEW champion adds the 2.0 s cameo | same, inside the boss's Altar visit |

Measured stream (300 000 chests, 5 Hero : 1 Grand, with pity, sim §4): per card Кварц 56.45% · Сапфір 24.49% · Аметист
14.14% · Топаз 4.92%; a Topaz champion card every 9.60 chests, longest gap 15; Monte Carlo vs the exact best-card table
max |z| 1.11. Expected 13.5 fragments per champion card once its gem is complete (27 per Hero Chest, 40.5 per Grand).

**Per-champion odds of one free card** (every gem complete; printed by `odds_table --chest`, checked by `--diff`
against `DISCLOSED_CHAMP` and by `--check` per champion through `HeroChest.pick_champion`):

| Gem | Champions | Each, no Focus | Focus | Each other |
|---|---|---|---|---|
| Кварц | 3 | 20.67% | 37.20% | 12.40% |
| Сапфір | 3 | 9.00% | 16.20% | 5.40% |
| Аметист | 4 | 2.25% | 5.40% | 1.20% |
| Топаз | 5 | 0.40% | 1.20% | 0.20% |

**Odds changelog** (`odds_table.gd ODDS_CHANGELOG`; the (i) sheet marks these rows «Змінено у …» for one version):

| Version | Pool | Row | Was → now | Why |
|---|---|---|---|---|
| 2.4.0 | Hero Chest, Топаз card (4 champions) | each champion, no Focus | 0.67% → 0.50% | C23 Тарас joins the Topaz champions (3 → 4) |
| 2.4.0 | Hero Chest, Топаз card (4 champions) | each non-Focus champion | 0.40% → 0.27% | same; the Focus keeps exactly 60% of the gem (1.20%) |
| 2.4.0 | Hero Chest, Аметист card (4 champions) | each champion, no Focus | 3.00% → 2.25% | C24 Снаряд joins the Amethyst champions (3 → 4) |
| 2.4.0 | Hero Chest, Аметист card (4 champions) | each non-Focus champion | 1.80% → 1.20% | same; the Focus keeps exactly 60% of the gem (5.40%) |
| 2.4.0 | Hero Chest, Топаз card (5 champions) | each champion, no Focus | 0.50% → 0.40% | C25 Довбуш joins the Topaz champions (4 → 5) |
| 2.4.0 | Hero Chest, Топаз card (5 champions) | each non-Focus champion | 0.27% → 0.20% | same; the Focus keeps exactly 60% of the gem (1.20%) |
| 2.4.0 | Portal, Опал (3 heroes) | each hero, no Focus | 0.70% → 0.47% | H26 Сірко joins the Opal heroes (2 → 3) |
| 2.4.0 | Portal, Опал (3 heroes) | each non-Focus hero | 0.56% → 0.28% | same; the Focus keeps exactly 60% of the gem (0.84%) |

`version` is the release the player sees in «Змінено у %s». `--diff` fails when a chest gem's pool differs from the
launch pools (`LAUNCH_POOLS`, 3 per gem) or a Portal gem's hero pool from `LAUNCH_HERO_POOLS` (2 per gem) without a row
whose `pool_after` is the current pool; only those current rows are checked against the exact table, so older rows stay
as history.

The gem odds of a card, the best-card tables and the chest pity are unchanged (Тарас, Снаряд and Довбуш are champions:
never in the Portal); the Portal changed only inside the Opal share (Сірко, §7.2).

**Scripted chests:** chest #1 at the unlock = Альба if Руді is the team hero, else Отто (+ one rolled card + fragments);
chest #2 = Міла (+ one rolled card). **One inline reveal per result screen** (priority scripted > Grand > Hero Chest >
Stone Cache); anything displaced goes to the Vault («Сховище») and opens there in a 0.3 s batch.

### 7.6 «Майстерня / Workshop» (your "Forge"; unlock L32, the World 4 boss) — zero randomness

| Item | Rule |
|---|---|
| Material | one «Зоряна руда / Star Ore» from first clears, bosses, replays, weekly and Expedition (no drop chance; fixed amounts §3.4) |
| Craft | pick a recipe, see the exact item and its stats, pay: item 40 · hero relic 60 · champion relic 30 Star Ore |
| Temper | +0 … +12, `8 + 4r` per step (champion relic half); cap `min(12, 2 × world_reached)`; beats at +4 / +8 / +12 |
| Trophies | 7 boss trophies, one per campaign world boss, ready at +3; the Invasion night boss of the same world adds +3 ranks (past +12 the ranks return as Star Ore); shown on the boss card before the fight |
| Retro grant | at the unlock: everything played wins and bosses would have paid + W1–W4 trophies + one free craft |
| Odds | none to disclose — the Workshop screen says «Без випадковостей: ти отримуєш саме те, що бачиш» |

### 7.7 What money may buy at launch (two-track rule, arsenal §6.6)

| May contain (exact, shown before purchase) | Never contains |
|---|---|
| hero skin + matching ult VFX ($3.99) · champion skin ($1.99) · Portal theme ($2.99) · splash foil frame | any hero or champion copy, fragments, Beacons, Seals, Hero / Grand Chests, Tomes, Star Ore, Workshop items, Champion Level, pity, Feat progress |

No hero SKU, no Hero Edition, no fragment SKU at launch (E01 / X02). Existing Meta-1 SKUs (`starter_arsenal`,
`supporter`, World Sets, `road_premium`, Flares) are unchanged except that **the paid Road lane no longer pays Gems**
(its Gem nodes pay coins at the arsenal exchange rate), so Gems stay earned-only. Earned Gems buy hero / champion
cosmetics only: skin recolour 200, champion aura colour 150, Portal theme 300 Gems.

## 8. Economy and simulation results *(sim: `heroes_sim.py` v2, full run, 80 campaign seeds, 30 long-horizon seeds (90 since 2026-10-09, §8.9), exit 0)*

### 8.1 Power model and coin sinks

Account power = Meta-1 terms (machines 0.50 · hero 0.25 · army 0.25, `E.W_MACH / W_HERO / W_ARMY`) with the hero term
built from §2.3's index (ladder × level × skill ranks × gear) + **champions** `W_C 0.012` per champion-index point ×
uptime 0.94 + synergy (Affinity inside `TEAM_B2_CAP`). Hero axes spend their own resources: skills = Tomes, recut =
fragments, Workshop = Star Ore. **Coins** remain for machines, Barracks, Tactics, hero levels and Champion Level.

| Coin sink of the hero system (upper bound) | Coins |
|---|---|
| Hero levels (11 heroes since Сірко, no Hero Sync) | 463 540 |
| Champion Level 1 → 20 (one shared track) | 26 840 |
| Skills · recut · Workshop | 0 · 0 · 0 |
| **Total** (Meta-1 Arsenal for comparison: 578 270) | **490 380** |

### 8.2 `TEAM_DEMAND` — the one-time difficulty re-bake

LevelGen enemy budget multiplier per world = EXPECTED-profile power / Meta-1 power × margin. The EXPECTED profile (P4) is
a casual player who fields only the best **starter**, the disclosed **welcome Topaz** and the **two scripted
champions**, with zero Portal duplicate fragments (critique E20). Margin search: no μ > 1.00 kept the EXPECTED-only
floor at ≥ 67% campaign / ≥ 62% Invasion, so μ = 1.00; Invasion inherits the W7 value and is multiplied by
`INV_DEMAND_MU 0.98` (at 1.00 the 80-seed run gave casual loss-streak p90 4 and max-attempts p90 5).

| World | W1 | W2 | W3 | W4 | W5 | W6 | W7 | Inv W1 | Inv W2 | Inv W3 | Inv W4 | Inv W5 | Inv W6 | Inv W7 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EXPECTED profile / Meta-1 | 1.028 | 1.030 | 1.054 | 1.070 | 1.111 | 1.123 | 1.158 | 1.156 | 1.147 | 1.158 | 1.158 | 1.154 | 1.155 | 1.145 |
| median full account / Meta-1 (reference) | 1.028 | 1.030 | 1.063 | 1.092 | 1.133 | 1.164 | 1.199 | 1.206 | 1.198 | 1.224 | 1.220 | 1.209 | 1.213 | 1.206 |
| **ADOPTED `TEAM_DEMAND`** | **1.028** | **1.030** | **1.054** | **1.070** | **1.111** | **1.123** | **1.158** | **1.133** | **1.124** | **1.135** | **1.135** | **1.131** | **1.132** | **1.122** |

`TEAM_DEMAND` is versioned with the data and re-baked (LevelSim, real kits) in phase H2 and whenever Meta-2 machines
switch Affinity on (§15 R5).

### 8.3 Campaign + Invasion, 112 levels (80 seeds per row)

| Archetype / policy | Win | Boss min campaign · Invasion | Loss streak p90 | Max tries p90 | Ceremony mean (p90) | Machines share L60 · L112 | Machine Lv L112 |
|---|---|---|---|---|---|---|---|
| casual (greedy) | 84% | 80% · 65% | 3 | 4 | 14.2% (23%) | 50% · 49% | 8.59 |
| regular | 91% | 91% · 78% | 2 | 3 | 14.5% (20%) | 51% · 49% | 8.62 |
| hardcore | 97% | 96% · 88% | 2 | 3 | 14.2% (17%) | 52% · 49% | 8.84 |
| casual · spread | 81% | 75% · 69% | 3 | 4 | 12.6% | 45% · 43% | 6.02 |
| casual · machines only | 69% | 61% · 47% | 5 | 6 | 11.4% | 63% · 65% | 6.63 |
| weak casual | 76% | 71% · 55% | 4 | 5 | 13.9% | 50% · 49% | 8.59 |
| ad watcher | 87% | 82% · 68% | 3 | 4 | 14.8% | 52% · 49% | 9.42 |
| casual · EXPECTED-only team (no Portal / chest luck) | 79% | 74% · 58% | 4 | 5 | 13.4% | 54% · 54% | 8.64 |
| casual · Starter Arsenal ($2.99) | 85% | 82% · 64% | 3 | 4 | 14.3% | 49% · 49% | 8.57 |
| *Meta-1 reference casual (no hero system, 60 seeds)* | *78%* | *74% · 53%* | — | — | — | — | — |

Power growth share at L60 (casual): machines 50%, heroes 33%, champions + synergy 9%, Barracks 5%, Tactics 4%. Coin
spend (casual): machines 47%, Barracks 26%, Tactics 16%, Champion Level 7%, hero levels 5%.

**Fairness numbers:** Portal / chest upside over the EXPECTED-only floor mean **+4.4 pp** (p10 0.0, p50 +4.3, p90 +9.2);
luck gap top-25% vs bottom-25% Topaz+ summons **−1.0 pp** (luck barely matters to winning); ad watcher **+3.8 pp**;
Starter Arsenal **+1.4 pp**. Two-track property (same seeds, Starter Arsenal vs free): play-count Beacons identical per
seed, rating-driven Beacons 0; the only difference is +0.041 Beacons / day from progressing faster (bounded by the
Starter ≤ +3 pp rule).

### 8.4 Earned income per day (mean, 30 seeds × 180 days; all earned by play)

| Archetype · phase (days) | Beacons | Summons = Seals | Tomes | Star Ore | Fragments | Chests |
|---|---|---|---|---|---|---|
| casual · campaign (16.4) | 2.63 | 2.31 | 2.63 | 21.3 | 75.6 | 1.44 |
| casual · Invasion (17.4) | 3.08 | 3.12 | 3.33 | 26.4 | 121.8 | 1.64 |
| casual · after content (146.2) | 1.66 | 1.66 | 2.75 | 13.4 | 79.1 | 1.22 |
| regular · campaign (7.5) | 5.11 | 3.98 | 5.74 | 45.0 | 138.7 | 3.02 |
| regular · Invasion (7.8) | 5.21 | 5.58 | 6.24 | 56.4 | 234.7 | 3.44 |
| regular · after content (164.7) | 2.02 | 2.03 | 3.12 | 23.3 | 86.4 | 1.23 |
| hardcore · campaign (2.9) | 9.84 | 6.98 | 11.47 | 112.4 | 277.9 | 7.33 |
| hardcore · Invasion (2.9) | 9.72 | 10.35 | 14.63 | 143.7 | 502.9 | 8.56 |
| hardcore · after content (174.2) | 2.09 | 2.10 | 3.31 | 57.4 | 89.3 | 1.26 |

Beacon sources, regular campaign: welcome ×10 1.33 · world bosses 1.33 · first clears 0.96 · dailies 0.65 · weekly 0.53 ·
Expedition 0.32 · Track **0.00** · Feats **0** (none pay Beacons). Tome sources, regular campaign: Feats 3.23 · Grand
chests 1.52 · bosses 0.53 · weekly 0.27 · Expedition 0.20 · Hero Chests 0. Summons done by day 30 / 90 / 180: casual
80 / 180 / 335 · regular 100 / 220 / 410 · hardcore 110 / 230 / 420.

### 8.5 Milestones — day reached, p10 / p50 / p90

| Milestone | casual | regular | hardcore |
|---|---|---|---|
| champions + Hero Chest (L14) | 4 / 5 / 5 | 2 / 2 / 3 | 1 / 1 / 1 |
| Portal + welcome ×10 (L20) = first Topaz hero = first Awakening | 6 / 7 / 7 | 3 / 3 / 3 | 2 / 2 / 2 |
| first Opal hero | 7 / 24 / 84 | 3 / 10 / 59 | 3 / 7 / 72 |
| first Topaz champion | 7 / 11 / 13 | 3 / 5 / 6 | 1 / 2 / 3 |
| first Full facets | 8 / 9 / 10 | 4 / 5 / 5 | 2 / 2 / 2 |
| first recut (any) · first hero recut | 12 · 14 | 6 · 7 | 3 · 4 |
| full team (hero + 3 champions) | 11 / 12 / 14 | 6 / 6 / 6 | 3 / 3 / 3 |
| Workshop (L32) · first item at +12 | 10 · 57 | 5 · 33 | 2 · 20 |
| first skill rank 7 · rank 9 | 40 · 77 | 21 · 56 | 14 · 56 |
| all 15 champions (C24–C25 run, 90 seeds, 2026-10-09; all 13 in the same 90-seed run before them: 14 / 21 / 29 · 7 / 11 / 15 · 3 / 5 / 7; all 12 at launch: 14 / 18 / 24 · 7 / 9 / 11 · 3 / 4 / 5) | 19 / 27 / 35 | 9 / 14 / 21 | 4 / 6 / 14 |
| all 10 heroes | 21 / 56 / 98 | 10 / 30 / 77 | 12 / 63 / 84 |
| first hero recut to Opal · first hero at Opal f5 | 49 · 63 | 28 · 49 | 28 · 54 |
| first skill rank 11 (Opal max) | 20% of seeds by day 180 | 13% | 6% |

Time-to-fun (E10): casual meets champions on day 5 and the Portal with its guaranteed Topaz on day 7 (v1: day 6 and the
first Topaz on day 10); regular on day 2 and day 3.

### 8.6 Long horizon and dead currencies (p50)

| Regular account | d1 | d3 | d7 | d14 | d30 | d60 | d90 | d180 |
|---|---|---|---|---|---|---|---|---|
| frontier level | 8 | 23 | 53 | 104 | 113 | 113 | 113 | 113 |
| heroes owned · team hero gem (0 = Кварц … 4 = Опал) | 2 · 1 | 6 · 3 | 8 · 3 | 9 · 3 | 10 · 4 | 10 · 4 | 10 · 4 | 10 · 4 |
| team hero Ult + Attack + Rally ranks · Awakening | 3 · 0 | 3 · 1 | 12 · 3 | 17 · 3 | 19 · 3 | 23 · 3 | 26 · 3 | 30 · 3 |
| champions owned · Champion Level | 0 · 1 | 7 · 3 | 12 · 6 | 15 · 14 | 15 · 18 | 15 · 20 | 15 · 20 | 15 · 20 |
| recuts done · summons done | 0 · 0 | 0 · 10 | 2 · 30 | 9 · 70 | 15 · 100 | 23 · 160 | 28 · 220 | 38 · 410 |
| Seals banked · Tomes banked | 0 · 0 | 10 · 0 | 30 · 2 | 70 · 6 | 55 · 4 | 65 · 13 | 20 · 12 | 30 · 47 |
| average machine level | 3.6 | 4.7 | 6.5 | 8.2 | 11.2 | 13.3 | 14.0 | 14.5 |

| Day 180 (p50) | Tomes earned | banked | spent on Chronicle | Seals banked | owned Seal picks |
|---|---|---|---|---|---|
| casual | 500 | 44 | 80 (8 pages) | 20 | 3 |
| regular | 608 | 46 | 175 (15 pages) | 30 | 4 |
| hardcore | 657 | 46 | 235 (19 pages) | 40 | 5 |

v1 for comparison: regular banked 1 262 of 1 670 Tomes. Power growth share at day 180 (after content): machines 40–41%,
heroes 43–44%, champions + synergy 7%, Barracks 5%, Tactics 4% — post-content growth is mostly hero recuts toward Opal;
the post-content floor "machines ≥ 35%" holds (41%).

### 8.7 Migrated v2 saves (systems open on update day; catch-up only vs the lump grant)

| Update at | Grant (mean) | Fresh account · catch-up only · + lump grant, boss win in the next two worlds |
|---|---|---|
| L24 | 3 Beacons, 5 chests, Champion Lv 3 | W4 85 / 83 / 84% · W5 81 / 81 / 81% |
| L40 | 10 Beacons, 12 chests, Champion Lv 5 | W6 85 / 83 / 84% · W7 80 / 78 / 80% |
| L56 | 17 Beacons, 20 chests, Champion Lv 6 | Inv W1 87 / 82 / 87% · Inv W2 88 / 86 / 88% |

With the grant the worst deficit against a fresh account is **0.9 pp** (invariant ≤ 3 pp); catch-up only would cost up
to 5 pp at L56.

### 8.8 Invariants (all PASS in the final run)

Campaign / Invasion: casual / regular / hardcore boss win ≥ 65% every campaign world and ≥ 60% every Invasion world;
loss streak p90 ≤ 3; max tries on one level p90 ≤ 4; ceremony ≤ 15% of session time; machines ≥ 50% of power growth at
L60 and the largest share at L112 (≥ 40%); casual sessions with a purchase ≥ 85%; casual win rate 65–85%; spread ≥ 60%,
machines-only ≥ 55%, weak ≥ 55% worst boss; EXPECTED-only casual ≥ 65% every campaign world; luck gap ≤ 6 pp; upside
≤ +8 pp; ad watcher ≤ +6 pp; Starter Arsenal ≤ +3 pp; two-track structural property; champions + synergy ≤ 12% of L60
growth. Rule #3: §2.5 tests 1–14 (incl. the real-kit tolerance grid and the cross-class champion test). Odds: Monte Carlo
|z| ≤ 4, pity caps, welcome rule. Migration ≤ 3 pp. Long horizon: regular first Topaz ≤ day 7, casual ≤ 14; first Opal
≤ 30 / 45; first recut ≤ 10 / 21; all 10 heroes regular day 25–100, casual 35–140; Opal f5 regular day 30–90; rank 9
≤ 75 / 110; time-to-fun casual champions ≤ day 5 and Portal ≤ day 7; machines ≥ 35% at day 180; Tomes banked ≤ 25% of
earned; Seals banked ≤ 120.

### 8.9 Tuning history (why numbers moved from part S)

| Change | From → to | Reason |
|---|---|---|
| Hero coin sinks | skills, recut, Workshop in coins → Tomes / fragments / Star Ore | machines crowd-out (E07) |
| Ult rank step · level term | +10% (framework) / +8% (part S) → +5% / rank · `lv_ult = 1 + 0.036 (L − 1)` | machines share at L60; no-loss migration |
| Tome income | ≈ ×0.45 (Grand 2, boss 1, weekly / Expedition 2, Feats 2 / 4 / 8, overflow 20 : 1, Hero Chest 0) | 70–77% unspent at day 180 |
| Boss Beacons · Feat / Track Beacons | 3 → 2 · removed | E01, E16 |
| Unlocks | champions 18 → 14 · Portal 22 → 20 (a Portal at L18 was tried: casual machines share at L60 fell to 49%) | E10 |
| Facet step `a` | 0.0074 → 0.0073 | frozen ceiling check (E15) |
| Invasion demand | ×1.00 → ×0.98 | casual loss-streak p90 (this run) |
| Chest hero-fragment card | 0.2 → 0.15 × DUP | collection pace and Tome overflow |
| C23 Тарас joins (2026-10-09) | 12 → 13 champions, Топаз pool 3 → 4 | full re-run (repo `tools/heroes_sim.py`, 80 seeds, `PYTHONHASHSEED=0`): all 69 invariants PASS before and after. Real shift: completing the champion roster takes longer (p50 casual day 18 → 21, regular 9 → 11, hardcore 4 → 5); Workshop all relics 11 520 → 11 730 Star Ore. Everything else moves only by the RNG stream (win rates ±1 pp, champions + synergy at L60 8–9%, `TEAM_DEMAND` recalibration ≤ 0.003 per world, not re-baked: the EXPECTED profile holds no Тарас); the EXPECTED Champion Level table (`SaveV3Data`) re-derived, §12.3 anchors hold |
| C24 Снаряд + C25 Довбуш join (2026-10-09) | 13 → 15 champions, Аметист pool 3 → 4, Топаз 4 → 5 · long-horizon seeds 30 → 90 | full re-run before (C23 roster) and after, both with 90 long-horizon seeds: all 69 invariants PASS in both. Real shift: completing the champion roster takes longer (p50 casual day 21 → 27, regular 11 → 14, hardcore 5 → 6); Workshop all relics 11 730 → 12 150 Star Ore. Everything else moves only by the RNG stream (win rates unchanged, champions + synergy at L60 8.0–8.3%, `TEAM_DEMAND` recalibration ≤ 0.004 per world, not re-baked: the EXPECTED profile holds neither). Why 90 seeds: with 30 the p50 day of «all 10 heroes» (p10 ≈ day 10, p90 ≈ day 77) moved between day 21 and 42 with the RNG stream alone and crossed the invariant's day-25 bound (the champions never touch the Portal; 90 seeds: day 28 before, 35 after). The EXPECTED Champion Level table (`SaveV3Data`) is kept as published (`gen_save_v3_data.py --roster-only`): its 12-seed median sits on x.5 at several frontiers, the 60-seed means moved ≤ 0.15 except L80 (+0.35), so the §12.3 anchors stay |

## 9. Screens and ceremonies

Part U (`heroes/part_ui_run.md` §1–§3, §6–§8) stays the **pixel-level appendix** (wireframes, zone tables, scene trees,
shader specs). This section is normative where it differs; every override below is a critic finding applied.

### 9.1 Direction and primitives (binding: Genshin × AFK Journey fusion, "much closer to Genshin", C-bright)

Light cream panels `#F6F0E2` with thin gold lines `#C9A24A`, painted portraits, one rounded font (**M PLUS Rounded 1c**,
weights 500 / 700 / 800; never a system default), **45° facet-chamfered corners on every plate, chip, bar and button
(never pills)**, the amber topaz crystal CTA `#F2A93B` for key verbs only (Summon, Recut, Craft, Play), white-gold
markers, light porcelain run HUD. Parts U's A / B / C direction notes are superseded.

Every primitive has a drawn style (critique X22), all from `UITokens` + `icons.gd`:

| Primitive | Look | Never |
|---|---|---|
| Plate / card | cream, 1 px gold hairline, 45° chamfer 10 px, soft drop 0 4 12 α 0.12 | rounded radius > 8 px |
| CTA | amber crystal bar, chamfered both ends, 88 px tall, label 30 px 800 | gradient pill, glow halo |
| Secondary button | cream with gold rule, chamfer 8 px | ghost pill |
| Filter / Focus / History / Odds chips | engraved cartouche 56 visual / 88 hit, chamfer 6 px, active = gold fill + dark text | capsule chip |
| Toggle | two-facet switch (a gem slides between two chamfered seats) | iOS pill toggle |
| Toast / tooltip | cream slip with a gold top rule, chamfered, ≤ 2 lines | dark rounded bubble |
| Fragment / pity / Champion Level bars | engraved channel 10 px, filled with the gem's UI hex, facet tick marks | rounded progress capsule |
| NEW stamp · gold «!» | wax-seal stamp «НОВИЙ» · 32 px gold lozenge | red dot, numeric badge |
| Page dial | five cut-gem pips | dots |

CI lint: a `StyleBoxFlat` corner radius > 8 px under `scripts/ui/heroes` or `scripts/ui/summon` fails unless whitelisted;
`test_heroes_ui` fails on emoji code points (U+1F300–1FAFF, U+2600–27BF) in Loc strings — all glyphs come from `icons.gd`.

### 9.2 Hub map and entry points (unlock levels final)

| Destination (uk / en) | Kind | Entry | Opens at |
|---|---|---|---|
| «Зала героїв / Hall of Heroes» (Heroes tab, sub-tab keys Герої · Чемпіони · Подвиги) | tab | tab bar | L4 (existing) |
| Чемпіони sub-tab (grid + the shared Champion Level row + chest Focus chip) | sub-tab | Hall | L14 |
| Portal plate · Workshop plate in the Hall header | plates | Hall | L20 · L32 (frosted only 2 levels before; hidden earlier) |
| «Вітрина героя / Hero Showcase» · «Вітрина чемпіона / Champion Showcase» | full screen | card tap, deep links | L4 · L14 |
| «Покращення / Manage sheet» (Рівень · Грані · Навички · Спорядження) | sheet | Showcase dock | tabs appear as their system unlocks (§11.3) |
| «Огранка / Recut» | full screen | dock CTA at Full facets | first Full facets |
| «Команда / Team» (+ roster sheet, presets ×3, Auto-team) | full screen | Play-tab team row | L14 |
| «Портал / Portal» (+ Seal shop, Odds, History, Focus sheets) | full screen | Hall plate, unlock line | L20 |
| «Майстерня / Workshop» | full screen | Hall plate, Manage → Спорядження | L32 |
| «Хроніка героя / Hero Chronicle» | sheet | Showcase dock book icon, Hall header | L30 |
| «Довідник / Codex» | sheet | «?» on Hall, Team, Portal, Showcase | L4 (rows appear with their systems) |
| Hero Chests in the Vault | list section | Vault rail, result chip «→ Сховище» | L14 |
| Shop «Герої» section (skins, champion skins, Portal themes) | shop section | Shop tab | L28 (existing Shop) |

One router `Hub.route(uri, ctx)` with the URIs of part U §1.3 (`hero/<id>[/level|/facets|/skills|/gear|/recut|/skill/<s>]`,
`champion/<id>`, `champions/level`, `team[/slot/<i>|/auto]`, `portal[/seals|/odds|/history|/focus]`,
`workshop[/item/<id>|/relic/<id>]`, `vault/hero_chests`, `replay/<id>`, plus `hero/<id>/chronicle`, `codex/<row>`,
`shop/heroes`). Locked routes return false and show the lock line. Android back on a ceremony skips to its end state
(grants are saved before any animation). Badges: part U §1.4 (team members and the Best-upgrade target only; **the
Portal plate never has a badge**).

### 9.3 Screen rules that changed

| Screen | Final rule (finding) |
|---|---|
| Hero Showcase | Left column = emblem 200 px · name 68 px · title · 3 badges · **one combined facets + fragments row** («Грані 3 / 5 · 32 / 30 фрагм.»). **Gear is not on the Showcase**; it lives in the Manage sheet «Спорядження» tab (X43). Power line reads «Міць 12 480» (X40). Dock: ‹ · one contextual CTA · «3D» · book icon (Chronicle, L30+). Skin chip lists **owned skins only** — never an offer after a walkout (X36). |
| Skill plates | Only unlocked skills are drawn (§11.3): Ult + Attack from L4, Rally from L30, Awakening plate from the first Full facets in Amethyst+ (always present on native Amethyst / Topaz / Opal: born awakened). The Ult bezel stone = the current form's gem; a recut hero's bezel can never pass its native gem (rule #3 visible on the plate). |
| Facets | presented as **progress, not stats**: micro 0.35 s, batched across characters on one screen, each engraves a facet line on the Living Gem; no stat count-up; card text «Грані 3 / 5 → +1 межа навичок» (X26); the Manage sheet's facet row still prints the
true value in small text («+0,73% до характеристик», generated from `Ladder.FACET_STEP`) so nothing is hidden (E12). The luxe sits on Full facets (1.6 s) and the first rank bought in the new cap. |
| Recut | own screen; leads with **what it unlocks** («+2 межі навичок · форма IV · Пробудження»), then the honesty table **Зараз · Після огранки · Корінний** (Might, skill cap, ult form, Awakening, Action tier for champions), the native-ceiling bar, cost (fragments only), two-tap «Огранити». The ceiling block is never collapsed. |
| Rewrite skills | Manage → Навички → «Переписати навички»: sheet lists ranks and the exact Tomes returned («Повернеться: 46 томів · Ранги стануть 1»); disabled for a hero in the active team or a preset; two-tap; no coins involved (X36). |
| Team | 1 hero + 2 slots (3rd at L40); simple synergy mode (one line per active bonus) until L20, the full 3-column panel from L20 (§5.5); Auto-team and 3 presets; candidate cards show delta badges. |
| Portal | top bar shows **Beacons only**; pool carousel · 3D Portal ring · one pity bar «Топаз або краще ≤ N» with the engraved «Аметист+ ≤ 7» label · Seals bar + «Вибір» · Focus / History / Odds chips · ×1 and ×10 (amber CTA). The summary has **no «Ще ×10» link** (X38). Welcome state: one free ×10 with «Серед десяти — щонайменше Топаз» above it. |
| Odds sheet (i) | per-gem table + **every eligible hero's current %** + the pity sentences + Focus «60%» + chest hero-card «герой команди ×2»; every sentence generated from `PortalData` / `CHEST_*` (Loc templates validated by `odds_table --check`); «Змінено у 2.x» marker for one version after a pool change (`odds_table --diff` writes the changelog row). |
| Seal shop | eligible heroes with price; an owned hero shows «+200 фрагм.»; a hero at the absolute max shows the honest overflow «+10 томів (надлишок)» (X36). |
| Champion Showcase | 3:4 card art, emblem, role line first, Action / Aura plates with tier pips (I–IV, «Ярус IV — лише для корінних Топазів»), relic socket, «У забігу» demo loop. |
| Workshop | one material «Зоряна руда»; item wall by faction; item sheet with exact stats per rank; trophies with provenance; «Без випадковостей» line. |
| Shop «Герої» | hero skins, champion skins, Portal themes, prices shown; nothing else (§7.7). |
| Hall states | all-max, Champion Level cap «Рівень чемпіонів 12 / 12 · більше після Світу 6», Workshop temper cap «+8 / 12 · більше в Світі 5» labels drawn (X36). |

### 9.4 Ceremony register = `CeremonyData` (one const, read by the UI and by `heroes_sim.py`)

| Ceremony | Length | Fast ceremonies / Quick reveal | Reduce Motion |
|---|---|---|---|
| Summon ×1 Кварц · Сапфір | 1.2 · 1.8 s total | 1.2 · 1.2 s | 200 ms cross-fade + chime |
| Summon Аметист / Топаз / Опал, NEW | prologue 0.6 + walkout 2.6 / 3.6 / 5.0 s, skippable from 0.5 s | short walkout 0.6 + 1.2 s | static splash + name ≤ 1.0 s |
| Summon Аметист+ duplicate | 0.6 + 1.2 s | same | static |
| ×10 | summary frame 1.2 s after the best walkout; facet cracks batched 0.5 s | all walkouts short | summary only |
| Seal pick NEW · owned | 1.8 · 1.2 s (known contents, no tell) | 1.2 s | static |
| Hero Chest inline (result screen) | **1.6 s**, 1.2 s with nothing NEW | same | fan-out, no burst |
| NEW champion cameo | 1.5 s (next one in the same chest 1.0 s) | 1.0 s | static bust |
| Facet | 0.35 s micro, batched | — | 0.2 s fade |
| Full facets | 1.6 s | 0.8 s | 0.5 s |
| Recut | 3.0 s | 1.5 s | 0.6 s |
| Skill rank | 0.6 s | 0.3 s | 0.2 s |
| New ult form (rank 3 / 5 / 7 / 9) | 1.6 s | 0.8 s | 0.5 s |
| Awakening opens | 3.0 s | 1.5 s | 0.6 s |
| Hero level · Champion Level · temper · Chronicle page | 0.35 s micro | — | — |
| Craft · temper tier change · temper beat (+4 / +8 / +12) | 1.2 s | 0.6 s | 0.35 s |
| Vault batch (displaced chest / cache) | 0.3 s | — | — |
| Migration summary card | 3.0 s once | — | static |
| Team-ready · victory with the hero | 0.4 s · +0 s (rides result steps 2–3) | 0.2 s | none |

Measured with this table (sim §5, 80 seeds): ceremony share of session time **casual 14.1% · regular 14.5% · hardcore
14.2%** (≤ 15% invariant; final run §8.3). Fast ceremonies switches ON from day 3 (existing). Peak-end budget goes to
walkouts, the Showcase, Recut, Full facets, Awakening, team-ready and victory-with-the-hero (part U §3.8); signature beats
per hero are on the sheets (§6).

### 9.5 Honesty and fairness rows added to the arsenal checklist

1. No banner, timer, countdown, "last chance", limited pool, or price change by time (P6).
2. The welcome ×10 runs the real roller; its promise is exactly the disclosed rule; the only scripted grants (two first
   Hero Chests) are shown as **known-contents** chests («Вміст відомий наперед»).
3. Every odds sentence is generated from data; the (i) sheet shows per-character odds for the current state.
4. A walkout never ends on an offer; no shop link appears on summon, chest or recut screens.
5. Skips never abort a grant; the grant is saved before the first frame.
6. Rule #3 is visible: the doublet emblem, the native-ceiling ticks, the Ult bezel cap, «Ярус IV — лише для корінних».
7. A new character joins the permanent pool and only splits its gem's share (H26 Сірко: Opal 2 → 3 heroes); the gem
   odds, the pity and the Seal prices never move with the roster, and every changed per-character row carries an odds
   changelog row and «Змінено у» for one version (`odds_table --diff` fails without it).

### 9.6 States, failure paths and fallbacks (critique X36)

| Case | Behaviour |
|---|---|
| Save write fails during a grant | `Save.write_atomic` with rollback; the ceremony does not start; toast «Не вдалося зберегти — нічого не витрачено» |
| Older APK opens a v3 save (sideload) | unknown hero / champion ids move to `_orphans` (never deleted) and come back to the roster when a build that knows them opens the save; a save with a newer version opens read-only with a line |
| Missing or corrupt art | card crop → silhouette → class placeholder (`HeroArt.state`); a deletion test removes each file and checks no crash |
| Clock moved back | dailies and day-7 login use a monotonic day guard (`max_day_seen`); no Beacon is paid twice for one day |
| All-max states | absolute max (Opal f5 · rank 11 · +12): filigree corners, overflow shown honestly, no CTA |

### 9.7 Accessibility, audio, haptics

Part U §6.2–§6.4 unchanged: five gem channels everywhere (cut, setting, fracture pattern, engraved name, lightness),
Reduce Motion, haptics off, photosensitivity cap for all (≤ 3 flashes / s, peak ≤ 60% white), text scale 100 / 115 / 130%,
«Ульта ліворуч», touch ≥ 88 px, text ≥ 22 px. Audio: one stated SFX source with licences (§14.1); one ring per action.

## 10. Run integration and performance

### 10.1 What the run gets (one profile, no id branches)

`Run` and `LevelSim` read hero and champion numbers **only** from `Meta.run_profile(level)` (`profile.hero`,
`profile.team`, framework §9.8 shapes); `Balance.HEROES` stops being read once heroes ship. Champions = audit Option A
(`RunChampion`: one skinned clip character each, hero-grade matte + white-gold rim; contract §4.2). Rings and glyphs are
two MultiMeshes for all champions (1 draw each). The hero keeps the existing drag + ult input; champions take no input.

### 10.2 Gate-legibility rule (critique X27) — the run's core decision stays readable

1. No ult or champion VFX, and no solid, may drop the **next gate row's label contrast below 3 : 1** (measured on the
   label rect against what is drawn behind it).
2. Gate labels draw with `no_depth_test` and a render priority above ult VFX while any ult is active.
3. Additive ult layers over a gate panel are capped at α ≤ 0.35; full-screen flashes (Пава form IV) ≤ 60% peak white
   and never during the 0.8 s before the army reaches a gate row.
4. Вартан's Forgewall is a **knee-high rampart** (≤ 0.6 u, α ≤ 0.5 above 0.3 u); Люмен's fan rays are thin (≤ 0.12 u) and
   fade over gate panels; Веста's Sunstride is visual only (logic x stays under the thumb; the model springs back in
   ≤ 0.6 s).
5. `hud_lab --gate-legibility` renders every hero kind × form and every champion special on a W4 template with a gate row
   at 6 u and fails below 3 : 1.

### 10.3 Run palette vs COLOR LOCK (critique X28)

The run material **neutralises the G-mask crystal region** (desaturate 70%, lift toward ice-white `#EAF4FF`) on every hero
and champion, except during that character's own ult / special (0.2 s ramp up, 0.4 s back); meta screens keep full gem
colour. `prepare_model.mjs` already writes the heart-gem / crystal range into mask G. Run-side markers use
`RunPalette.MARKER` (white-gold `#FFE7A3`, ring α 0.25) or the element accent (`ArsenalData.FAMILIES`), never `GemData`
except the 10 px gem pip. Test: ≥ 90% of run-model pixels at ΔE2000 ≥ 10 from every `GATE_KINDS` and pickup colour, and
a scan of run scenes for gem hexes.

### 10.4 One rules implementation: `KindView` (critique X32)

`scripts/run/hero_kinds.gd` and `scripts/run/champion_kinds.gd` are **pure static** rule code over a `KindView`
interface; `Run` implements it with nodes and VFX signals, `LevelSim` with arrays. Nothing is written twice.

```gdscript
class_name KindView extends RefCounted     # abstract; RunKindView (scenes + signals) and SimKindView (arrays)
func squads_in(z0: float, z1: float, x0: float, x1: float) -> Array      # [{id, z, x, n, flying, armored, phantom, status}]
func gates_in(z0: float, z1: float) -> Array        # [{row, x, kind, value}]
func hazards_in(z0: float, z1: float) -> Array      # [{id, z, x, kind, hp}]
func army() -> Dictionary                           # {n, x, z, radius, reserves, revive_pool}
func champions() -> Array                           # [{id, slot, hp, alive, x, z}]
func hit(target_id: int, dmg: float, tags := {}) -> int          # returns kills
func status(target_id: int, st: StringName, s: float) -> void    # BURN CHILL JOLT MARK BRAND STAGGER (existing set)
func lose(n: int, cause: StringName) -> void
func revive_champion(id: StringName, hp_frac: float) -> bool
func ground(squad_id: int, s: float) -> void ; func hold(squad_id: int, s: float) -> void ; func absorb(kind: StringName) -> bool
func fx(event: StringName, data := {}) -> void      # Run: VFX/SFX; LevelSim: no-op (counted for budget checks)
```

**Bot ult policies** (`HeroKinds.ult_worth(kind, view) -> float`, used by the bot, `level_check` and LevelSim; the
Meta-1 hard-coded `titan` branch of `level_sim.gd` is removed):

| Hero (kind) | Fire when |
|---|---|
| Горан `quake` | a structure (barricade, turret, geode, fortress) ≤ 12 u ahead, or a hazard row ≤ 6 u |
| Арін `anchor` | an Armored squad or a gate cluster ≤ 8 u ahead |
| Руді `storm` | ≥ 2 squads or a Flying squad in 16 u |
| Ейра `rime` | a clash starts or will start ≤ 1.5 s |
| Мейра `rift` | the next gate row is ≤ 10 u and unrevealed values exist, or ≥ 3 squads ≤ 12 u |
| Іскар `comet` | ≥ 3 hostiles in one lane ≤ 16 u |
| Веста `sunglaive` | ≥ 2 squads ≤ 6 u, or the fortress siege |
| Вартан `forgewall` | a turret or blade row ≤ 6 u ahead |
| Люмен `spectrum` | ≥ 3 squads inside the 60° fan, or the fortress siege |
| Пава `eyes` | ≥ 25% of the army lost in the last 3 s, or a champion down |

`test_kind_parity`: Run (headless) vs LevelSim kills within ±3% on 10 seeds × every hero × 3 team setups.

### 10.5 Champions in the run (summary of §4.2; U implements)

| Topic | Rule |
|---|---|
| Slots | front / left / right / rear offsets from the blob centre with `r' = max(r, 0.6)`; class preference; conflicts resolved front → rear → left → right |
| Aura | `AURA_SHARE` fixed per slot; the soldier-lift visual uses the measured share (visual only) |
| Clash | fractional accumulator `share_acc += hit × 0.25`, ×0.5 with a Guardian hero; at army 0 champions absorb front → left → right → rear, then the hero |
| HUD | medallions 72 px (HP ring, action glyph, 10 px gem pip) above the ult button bottom-right; `mouse_filter = IGNORE`; if a gate / hazard rect intersects a medallion it fades to α 0.5 (hud_lab overlay on W4 checks the right-lane gate labels, critique X43; fallback: a bottom row at y ≥ H − 240) |
| Start banner | 1.2 s during READY, ≤ 3 synergy icons; Rally popups with the horn glyph throttled 1 / 3 s; Affinity rim on matching HUD machine slots |
| Death | hit-stop 0.2 s, `fall` clip, ring shatters, medallion cracks, its synergy icons flash once; contributions stop at once |
| Siege / stairs | champions stop at the fortress line and keep acting; result screen step 2 shows `team_report [{id, alive, kills, heals, blocks, dmg_taken}]` |
| Turrets | never target champions; Німб's tier IV is an absorb in `Hazards.step_turrets` on a shot aimed at soldiers |

### 10.6 Performance — absolute gates (critique X31), measured before art lock

Reference phones: **low** = Adreno 610 class (Snapdragon 662 / 680, 4 GB); **mid** = Adreno 619 / Mali-G68 MC4 class
(Snapdragon 695 / Exynos 1280–1380, 6 GB). Nothing has been measured on a phone yet; phase H0 records the baseline.

| Gate (mid unless stated) | Target |
|---|---|
| Steady W4 run (220 knights, 2 squads in view) | p95 frame ≤ 16.6 ms |
| Worst 10 s (boss siege, 2 squads, Rank III convoy, Opal ult, 3 champions) | p95 ≤ 20 ms, max ≤ 33 ms |
| 10-minute thermal soak | p95 drift ≤ +25% |
| Low phone, worst 10 s | p95 ≤ 25 ms with the low preset |
| Hero Showcase (splash + rig + FX) · Details 3D | p95 ≤ 16.6 ms |
| Walkout step-out | no hitch > 50 ms |
| Added by 3 champions | ≤ +10 draws (+1 transient), ≤ +25k tris / pass, CPU `Champions.step` ≤ 0.25 ms, 3 AnimationTrees ≤ 0.45 ms |

**Fallback ladder** (applied in order until the gates pass; each step is a `Quality` flag): champion shadows off →
AnimationTree 30 Hz (`advance`) → ult VFX particle counts ×0.5 → aura soldier lift off → champion 6k-tri LOD → crowd
`MAX_SHOWN` mid 160. Bench scene `scenes/dev/gallery_champions.tscn --bench` (60 s scripted W4 run, A/B with champions
off, records p50 / p95, draw calls, primitives, `TIME_PROCESS`, texture memory). No `GPUParticles3D` (Compatibility):
`CPUParticles` / MultiMesh pools only.

### 10.7 Memory and package size (critique X39)

Texture residency (part U §8.6): Hall = thumbs atlas only (≈ 6.6 MB); Showcase = current hero + both neighbours (≈ 36 MB,
gate 48 MB); Details 3D releases neighbours first; Portal ≤ 3 splashes resident; Run = a 512 × 1024 face atlas (0.5 MB).
**Direct-APK cap raised to 140 MB** (the owner sideloads; Play Asset Delivery does not exist for APKs). Import settings
= part U §8.6: hero splash cutouts shipped at 0.5× of the 2160 × 3840 master (≈ 920 × 1830 after alpha trim, Lossy WebP
q 88), champion cards at 0.667× of 1536 × 2048, masks lossless PNG, backgrounds and atlases ASTC 4×4 HQ, GLB albedo ETC2
(heroes 1024², champions 512²); masters stay out of the APK. Hero / champion art adds ≈ 21 MB 2D + 17 MB 3D. CI prints a per-character size report and fails above 140 MB; asset packs are revisited only if Play AAB
distribution starts.

## 11. Onboarding and unlock pacing

### 11.1 `EconData.UNLOCKS` rows (final; `kind hero` never takes a session slot)

```
{"id": "seer_guest","kind": "inrun",    "from_level": 5,  "line": "",              "phase": H}   # one scripted level led by Мейра
{"id": "champions", "kind": "system",   "after_win": 14, "line": "UNL_CHAMPIONS", "free": "first_champion", "phase": H}
{"id": "portal",    "kind": "currency", "after_win": 20, "line": "UNL_PORTAL",    "free": "welcome_x10",    "phase": H}
{"id": "seer",      "kind": "hero",     "after_win": 24, "line": "",              "phase": 1}   # moved from 5 (owner Q7)
{"id": "skills",    "kind": "system",   "after_win": 30, "line": "UNL_SKILLS",    "free": "first_rank",     "phase": H}
{"id": "workshop",  "kind": "system",   "after_win": 32, "line": "UNL_WORKSHOP",  "free": "first_craft",    "phase": H}
{"id": "slot3",     "kind": "hero",     "after_win": 40, "line": "UNL_SLOT3",     "phase": H}
```

`_grant_free` gains `first_champion` (scripted chest #1 + `team.champions = [it]`), `welcome_x10`, `first_rank` (one free
Ult rank on the team hero), `first_craft` (+ `Workshop.retro_grant`). The Seer guest level: L5 is played with Мейра as
the hero (her real kit at Lv5, no ownership); its result line «Мейра повернеться біля Боса Світу 3» / "Meira will return
at the World 3 boss"; a v2 save that owns her keeps her.

### 11.2 Session placement (≤ 2 new systems per session; the existing queue holds overflow)

| Session | Regular (4 levels / session) | Casual (2 levels / session) |
|---|---|---|
| L13–14 | S4: talents 13 · **champions 14** (haven 16 queued) | S7: talents 13 · **champions 14** |
| L15–20 | S5: haven (queued) · dailies 17 (**Portal 20 queued**) | S8 haven 16 · S9 dailies 17 · S10 **Portal 20** |
| L21–24 | S6: **Portal** (queued) · rift anvil 24 (+ Мейра joins, no slot) | S12: rift anvil 24 (+ Мейра) |
| L25–28 | S7: tactics 26 · shop 28 | S13 tactics · S14 shop |
| L29–32 | S8: **skills 30 · Workshop 32** | S15 skills · S16 Workshop |
| L40 | slot 3 (no slot) | slot 3 (no slot) |

Hardcore players (10 levels / session) meet the same order through the queue. Scripted chest #2, Мейра and slot 3 never
take a slot. `test_meta._test_unlock_queue` per-session lists are updated with this table.

### 11.3 Progressive disclosure (critique X25) — hide what is locked; teasers only 2 levels before

| Moment | Shown | Hidden until |
|---|---|---|
| L4–13 | Showcase: emblem, name, title, **class badge only**, level line, **Ult + Attack plates (no hallmarks)**, dock. Hall cards without pips or bars. | element / faction badges → L14 / L20 · facets + fragments → the first fragment · Rally / Awakening plates → L28 teaser, L30 live · Manage tabs → each 2 levels before its unlock |
| L14 | Champions sub-tab, Team (2 slots), faction badge; **role line first** on every cameo, slot and medallion («Збиває летунів»); **synergy simple mode** (one plain line per active bonus) | class-pair and Affinity columns · Champion Level row (when 2 champions are owned) · chest Focus (when a gem is complete) |
| First hero-fragment card | the hero's facets + fragments row appears with the in-place beat «Фрагменти → Грані» | — |
| L20 (the welcome ×10 gives 4–6 heroes, so choices exist) | element badges, Affinity line, the **full 3-column synergy panel** with possible tags | — |
| L30 | Rally plate, hallmarks, Tomes chip, rank caps, Chronicle | Awakening plate: always on native Amethyst / Topaz / Opal (born awakened); others after their first Full facets in Amethyst+ |
| L32 | Workshop; gear lives in the Manage sheet «Спорядження» tab | relic socket until hero Lv 12 |
| First Full facets / first recut | Recut screen («Відкриває» block first), doublet emblem, Awakening beat | — |

**«Довідник / Codex»** (88 px «?» on the Hall, Team, Portal and Showcase top bars; never a coach mark): five rows
— Самоцвіт · Клас · Стихія · Фракція · Огранка — each a glyph, two lines of copy and «де це видно»; a row appears when
its system unlocks.

### 11.4 Beat by beat (result-screen beat · first visit coach marks ≤ 3 steps · free first step)

| after_win | Result-screen beat | First visit | Free step |
|---|---|---|---|
| 4 | Горан joins (NEW card + rubble beat) | Hall: «Герої ведуть армію. Торкнись, щоб роздивитися» | first hero level |
| 5 | Мейра leads one guest level; her line after the result | — | — |
| 14 | **scripted chest #1** inline (known contents) → cameo of Альба (Руді team) or Отто → «Скриня героїв: перший чемпіон іде з тобою» | Team: ① the slot «Чемпіон б'ється сам — нічого натискати не треба» ② the synergy line ③ PLAY | champion in slot 1 |
| 15–17 | in-run hints, one per level: first Action «Чемпіон б'ється сам — бережи його»; first clash «Солдати в колі чемпіона сильніші» | — | — |
| next chest (≈ L17) | **scripted chest #2** (Міла, known contents) → auto-placed in slot 2 | — | — |
| 20 | «Портал кличе героїв» + «До Порталу» | Portal: ① the welcome ×10 «Серед десяти — щонайменше Топаз» ② (after the summary) Seals «Кожен призов — печатка. Збери 100 — обери Топаз сам» ③ the pity bar | welcome ×10 |
| after the welcome summary | — | Showcase of the best new hero: swipe glyph «Свайп — наступний герой» | — |
| 24 | **Мейра joins**: Amethyst walkout in result step 5a; «Повтор появи» after | — | — |
| 30 | «Навички ростуть окремо: Томи» + «До навичок» | Skills: ① «Перший ранг ульти — у подарунок» ② «Межа рангу росте з гранями та огранкою» | one free Ult rank |
| 32 | «Майстерня: викуй спорядження» | Workshop: retro grant plays (≤ 1.5 s); ① «Перше спорядження — безкоштовно» ② «Вдягни — і воно діє в забігу» | first craft + retro grant |
| 40 | «Третій чемпіон у команді»; the third slot's prongs open (0.6 s) | — | — |
| first Full facets in Amethyst+ (non-born) | in place | the geode plate «Пробудження: четверта навичка» | Awakening rank 1 |

Coach marks never block the drag, never stack with an unlock line, are shown once (`seen_tips`), and never appear in a
run (in-run teaching = the existing `HINT_*` banners, ≤ 1 per level). Copy keys and texts: part U §5.4, with
`TUT_PORTAL_WELCOME` «Вітальний призов: десять призовів безкоштовно» + `PORTAL_WELCOME_RULE` «Серед десяти — щонайменше
Топаз» / "At least one Topaz in these ten" and the new `TUT_FACETS_FIRST` «Фрагменти → Грані: п'ять граней — нова межа» /
"Fragments → Facets: five facets raise the cap".

### 11.5 Time-to-fun (critique E10; measured, sim §6b, p50 day)

Measured p50 (§8.5): casual meets the first champion on **day 5** and the Portal with its guaranteed Topaz on **day 7**
(p10 day 4 / 6; v1: day 6 and the first Topaz on day 10); regular on day 2 and day 3; hardcore on day 1 and day 2.
Invariant: casual ≤ day 5 / ≤ day 7.

### 11.6 Migrated players (v2 → v3)

On the first hub visit after the update a migrated player sees the one-time **migration summary card** (3.0 s) «Герої
отримали самоцвіти, навички й спорядження» with the **lump grant** (§12.3) listed line by line, then «До Зали». Every
unlock already passed opens **on update day** (no catch-up tour gating power); the tour only plays the beats (≤ 2 per
session as hub cards, the scripted chest as a known-contents card) and their coach marks on first visit.

## 12. Save v3, data and rule classes, Loc, telemetry, tests

### 12.1 Save v3 (`Save.VERSION = 3`; every section created by `EconData.fresh_account()` — audit F2)

```
meta       {version 3, ... Meta-1 keys, max_day_seen: int}
wallet     {... Meta-1 keys, beacons: int, tomes: int, ore: int, beacon_charge: float, chest_charge: float, ore_charge: float}
heroes     {<id>: {owned, lvl (own), gem "C".."M", facets 0..5, frags,
                   skills {ult, attack, rally, awakened (0 = sealed)}, skills_peak {ult, attack, rally, awakened},
                   loadout {weapon, armour, charm}, skin, boss_wins, seen, chronicle 0..5,
                   got {t, via: "start|progress|portal|seal|chest|migration|guest"}}}
champions  {level, roster {<id>: {owned, gem, facets, frags, seen, got}}}
team       {hero, champions [], presets [{hero, champions}] x3, preset}
summon     {seals, since_e, since_l, total, focus {gem: id}, history [≤ 100], welcome_done}
chests     {since_l, total, focus {gem: id}, scripted 0..2}
workshop   {items {item_id: rank}, relics {char_id: rank}, trophies [boss levels], retro_done}
vault      {caches [{type: stone|world|royal|xray|hero_chest|grand_hero_chest, source, level}], ...}
_orphans   {heroes {}, champions {}}          # unknown ids from a newer APK, never deleted
```

Rules: `native` is never saved (data only); `fresh_account()` creates an entry for every starter (Руді owned at start)
and all new sections; `sanitize()` gains `_sanitize_heroes()` / `_sanitize_champions()` (unknown ids → `_orphans`;
orphans whose id the build knows again → back to the roster,
nested keys filled, `gem` clamped to `[native, max_gem]`, facets 0..5, ranks clamped to caps, `skills_peak ≥ skills`).
`Save.write_atomic()` writes to a temp file and renames; a grant that fails to save rolls back the in-memory account.
`via: "shop"` does not exist at launch (no hero SKUs).

### 12.2 Data and rule classes (framework §9.1 names; one JSON export, `tools/export_econ.gd` ↔ `heroes_consts.json`)

| File · class | Holds | Generated / checked by |
|---|---|---|
| `scripts/core/ladder.gd` `Ladder` | `Q_NATIVE 1.08`, `FACET_STEP 0.0073`, `RECUT_STEP 1.0365`, `CEILING 0.96`, `SKILL_BASE`, `FORM_AT_RANK [1,3,5,7,9]`, `AWAKEN_CAP {E 2, L 3, M 4}`, `BORN_AWAKENED_MIN "L"`, `ULT/ATK/RALLY_RANK_STEP 0.05/0.01/0.10`, `LV_ULT 0.036`; `mult`, `skill_cap` (F-CAP), `ult_form`, `can_awaken`, `awaken_cap`, `check()` | `test_rule3_*` |
| `scripts/core/hero_data.gd` `HeroData` | `HEROES` (kits, skills, forms, beats, Awakening, relic, sim rows, `KIT_INDEX`), `PROGRESS` | `heroes_tables.py` → §6 tables; `test_kit_budget` |
| `scripts/core/champion_data.gd` `ChampionData` | `CHAMPIONS`, `AURA_SHARE`, `AURA_CAP 0.40`, `CLASH_SHARE 0.25`, `SLOTS_AT {14: 2, 40: 3}`, `CHAMP_LEVEL`, `KIT_INDEX` | `test_champion_budget` |
| `scripts/core/team_data.gd` `TeamData` | classes, elements, factions, tiers, pairs, Affinity, `TEAM_B2_CAP 0.20`, `RALLY_HOOKS` | `level_check --budget` |
| `scripts/core/portal_data.gd` `PortalData` | odds, pity, `FOCUS_TOTAL 0.60`, Seals, welcome rule, `BEACON` nodes, chests, `CHEST_*`, scripted chests | `odds_table --check / --diff` |
| `scripts/core/gear_data.gd` `GearData` | items, sets, relic stats, `CRAFT_ORE`, `TEMPER_ORE`, trophies, `ORE_PER_WIN`, `ORE_BOSS` | `test_gear_numbers` |
| `scripts/core/ceremony_data.gd` `CeremonyData` | every ceremony length of §9.4 | read by UI and `heroes_sim.py` |
| `scripts/core/hero_art.gd` `HeroArt` | per character `state {placeholder, splash, complete}`, splash, masks, crops, eye line | only `complete` characters enter the Portal pool, chests or the Seal shop |
| `scripts/meta/roster.gd` · `heroes_meta.gd` · `champions_meta.gd` · `team.gd` · `summon.gd` · `hero_chest.gd` · `workshop.gd` | pure static rules (`acc` first) | `test_heroes.gd` |
| `scripts/run/kind_view.gd` · `hero_kinds.gd` · `champion_kinds.gd` | shared rules for Run and LevelSim (§10.4) | `test_kind_parity` |

### 12.3 Migration v2 → v3 (critique E08: no catch-up gating; a lump grant on update day)

1. `load_data()`: `version 3` → `account_from_cfg`; `version 2` → `account_from_cfg` + `migrate_v2(acc)`; no version →
   `migrate_v1` + `migrate_v2` (audit F1: v2 saves must never route into `migrate_v1`). `save_v2_backup.cfg` once.
2. Heroes: every v2 hero → `owned`, `lvl` kept, `gem = native`, facets 0, frags 0; `skills.ult` = min(max(1, Meta-1
   `ult_rank(lvl)`), `skill_cap(n, n, 0)`), excess ranks refunded as Tomes; attack = rally = 1; native Amethyst+
   born awakened (the Seer, a native Amethyst, gets Awakening rank 1); aspect dropped; Glory ◆ above 1 → 10 Star Ore each (credited at the Workshop
   unlock); a v2-owned Seer stays owned. The Ult level term `lv_ult` keeps every migrated Ult ≥ its v2 value
   (`test_no_loss_migration`: damage, HP and ult power ≥ v2; Горан Lv5 measured ×1.20).
3. **Lump grant** at frontier level L (what the content already played would have paid since each unlock):
   Beacons `min(60, 0.2 × (L − 20) + 2 × world bosses passed after L20)` · Hero Chests `min(20, ⌊(L − 14) / 3⌋)` ·
   Grand Hero Chests = world bosses passed after L14 · Tomes `1 × world bosses passed after L30` · Champion Level =
   the EXPECTED Champion Level of that frontier (L24 3 · L32 4 · L40 5 · L48 5 · L56 6 · L80 9 · L112 13) · the welcome
   ×10, both scripted chests and the Workshop retro grant as for a new player. Chests open in the Vault (batch 0.3 s).
4. One summary card (3.0 s, §11.6); every passed unlock is open on update day.
5. Fixtures `save_v2_L9.cfg`, `save_v2_L30.cfg`, `save_v2_L56.cfg`; chain test v1 → v3. Measured (§8.7): with the grant the
   boss win in the two worlds after the update stays within 3 pp of a fresh account (worst deficit in §8.7).

### 12.4 Loc keys (WS-Loc is the sole owner; uk first; `tools/loc_lint.py` gets the §1.3 glossary)

`HERO_<ID>`, `HERO_<ID>_TITLE`, `HERO_<ID>_LORE`, `CHAMP_<ID>`, `CHAMP_<ID>_TITLE`, `CHAMP_<ID>_ROLE`, `CHAMP_<ID>_LORE`,
`GEM_C…GEM_M`, `CLASS_*`, `FACTION_*`, `SYN_*`, `ULT_<ID>` (starters keep `ULT_STORM`, `ULT_QUAKE`, `ULT_RIFT`),
`ULT_<ID>_F2…F5`, `ATK_<ID>`, `ATK_<ID>_B3/B6/B9`, `RALLY_<ID>`, `AWK_<ID>` (+ `_DESC` templates), `FORM_C…FORM_M`,
`ACT_<ID>`, `AURA_<CLASS>`, `GEAR_<FACTION>_<SLOT>`, `RELIC_<ID>`, `CUR_BEACON`, `CUR_TOME`, `CUR_ORE`, `SEAL_*`, `PORTAL_*`
(incl. `PORTAL_WELCOME_RULE`, `PORTAL_FOCUS_60`), `CHEST_*`, `RECUT_*`, `FACET_*`, `AWAKEN_*`, `WORKSHOP_*`, `TEAM_*`,
`SYNC_*`, `CHRONICLE_*`, `CODEX_*`, `REWRITE_*`, `UNL_CHAMPIONS`, `UNL_PORTAL`, `UNL_SKILLS`, `UNL_WORKSHOP`, `UNL_SLOT3`,
`MIGRATION_HEROES_CARD`, `TUT_*` (§11.4), `HINT_CHAMPION`, `HINT_AURA`, `HINT_CHAMP_BLOCK`, `HINT_CHAMP_FALL`. Elements
reuse `FAM_*`. Meta-1 renames (Loc only, keys stay): `ST_SEAL` «Печать» → «Тавро / Brand»; machine rarity labels adopt
the gem names (§15 Q5). **No literal number in any copy string**: `_DESC` and odds lines are templates filled from data
(`%d` / `%s`); `loc_lint` fails on a digit followed by `%` in a uk / en value outside the whitelist. All values of names,
titles, lore, skills, relics and gear are in §6.

### 12.5 Telemetry (`MetaTelemetry.note(acc, event, data)`; local only, no network)

`summon {n, best, e_left, l_left, seals, welcome}` · `seal_pick {id, gem, cost, owned}` · `chest {type, best, scripted,
inline}` · `facet {kind, id, gem, f}` · `recut {kind, id, from, to}` · `skill_rank {id, skill, rank, form}` ·
`rewrite {id, tomes_back}` · `awaken {id, born}` · `hero_level {id, lvl, synced}` · `champion_level {lvl}` ·
`craft {item}` · `temper {item, rank}` · `chronicle {id, page}` · `team_set {hero, champions, synergies}` ·
`team_run {level, hero, champions, synergies, won, lost_ids}` · `champion_lost {id, level, t, cause}` ·
`ceremony {kind, s, skipped}` · `migration {from_level, grant}`. Stats keys appended: `champion_kills, champion_heals,
champion_blocks, champions_lost, wins_full_team, wins_with_hero {id}, synergy_wins {id}`.

### 12.6 Tests and tools (CI; all must pass before a phase gate)

| # | Test | Asserts |
|---|---|---|
| 1 | `test_rule3_ladder` | `Ladder.check()`; native > recut at every (g, f) and at max investment; ratio ≤ 0.96 |
| 2 | `test_rule3_caps` | F-CAP skill cap, form cap, Awakening cap and born-awakened rule for all 5 × 5 states |
| 3 | `test_rule3_kits` | every hero's `KIT_INDEX` profile within ±1.5% of P0 at every reference state; worst recut / native ratio ≤ 0.98 (§2.3; the full list of 14 rule-#3 tests is §2.5) |
| 4 | `test_kit_budget` | forms 3% ± 0.5 (Opal V 5%), Attack beats 1% ± 0.3, relic beats 3% ± 0.5, Awakening 4% ± 0.5 pp per rank, Rally parity ± 5% |
| 5 | `test_champion_budget` | champion `KIT_INDEX` = P0_c ± 3%; cross-class recut champion ≤ 0.983 of the weakest native Topaz; AURA_CAP applied |
| 6 | `test_odds` | `odds_table --check`: per-character 1 000 000-roll Monte Carlo per pool state, |z| ≤ 4; pity gaps (Amethyst+ ≤ 10, Topaz+ ≤ 30, chest Topaz ≤ 15); Focus exactly 60%; welcome rule; Loc odds strings match data |
| 7 | `test_two_track_property` | same-seed 112-level runs with and without each SKU: Beacons, Seals, chest charge, Caches, pity and per-hero odds identical; no Beacon node keyed to rating or money |
| 8 | `test_no_loss_migration` + fixtures | v1 → v3 and v2 → v3 chains; run numbers ≥ v2; lump grant values |
| 9 | `test_kind_parity` | Run vs LevelSim kills ±3% (10 seeds × every hero × 3 teams) |
| 10 | `test_survival` | LevelSim EXPECTED: front champion survives ≥ 75% of campaign levels, 40–60% of boss levels; side / rear ≥ 90% |
| 11 | `hud_lab --gate-legibility` | every kind × form ≥ 3 : 1 on the next gate row (§10.2) |
| 12 | `test_run_palette` | ≥ 90% run-model pixels ΔE ≥ 10 from gate / pickup colours; no gem hex in run scenes |
| 13 | `test_heroes_ui` | no emoji code points; StyleBox radius lint; every state of §9.6 renders; deletion fallback |
| 14 | `test_unlock_queue` | §11.2 per-session lists |
| 15 | `test_save_v3` | sanitize, `_orphans`, atomic write rollback, monotonic day guard |
| 16 | `bench` (phone) | §10.6 absolute gates, low + mid |
| 17 | `heroes_sim.py` | exit 0 (all §8.8 invariants) after any data change; tables regenerated by `heroes_tables.py` |
| 18 | APK size report | ≤ 140 MB, per-character sizes |

## 13. Implementation plan (after APK 2.1; decision 20)

Nothing here starts before APK 2.1 ships. Every workstream owns a disjoint set of files; a file outside its column is
changed only through its owner. All numbers come from `heroes_consts.json` (exported by `heroes_sim.py`), so a balance
change is one data PR plus a re-run, never a code hunt.

### 13.1 Workstreams and file ownership

| WS | Scope | Owns (create / modify) | Reads only |
|---|---|---|---|
| **A · Rules & data** | consts, rollers, rules, tools, sim port | `scripts/core/{ladder,hero_data,champion_data,team_data,portal_data,ceremony_data}.gd`, `scripts/meta/{roster,heroes_meta,champions_meta,team,summon,hero_chest}.gd`, `tools/{export_econ.gd,odds_table.gd,economy_sim.py}`, `scripts/dev/test_heroes.gd` | Save, Run |
| **B · Save & Meta API** | Save v3, migration, unlocks, rewards, Vault, telemetry | `scripts/autoload/save.gd`, `scripts/core/econ_data.gd` (`fresh_account`, `UNLOCKS`, `STATS_KEYS`), `scripts/autoload/meta.gd` (new API), `scripts/meta/{unlock_queue,rewards,vault,meta_telemetry}.gd`, `scripts/dev/fixtures/save_v2_*.cfg`, `test_meta.gd` additions | rules (A) |
| **C · Run & LevelSim** | KindView, hero / champion kinds, champions in the crowd, HUD medallions, bot, level_check, bench | `scripts/run/{kind_view,hero_kinds,champion_kinds,champions,run_champion}.gd`, `scripts/run/run.gd`, `hazards.gd`, `army.gd`, `hud.gd` (run HUD), `scripts/sim/level_sim.gd`, bot + `tools/level_check*`, `scenes/dev/gallery_champions.tscn`, `hud_lab` | profile (B), data (A) |
| **D · Meta UI** | Hall, Showcases, Manage, Recut, Team, Portal, chests, ceremonies, Codex, Chronicle, Shop section, router | `scripts/ui/heroes/*`, `scripts/ui/summon/*`, `scripts/ui/hub.gd` (routes), `res://shaders/ui/*`, `scripts/core/gem_data.gd`, `scenes/ui/heroes/*`, `test_heroes_ui.gd` | Meta API (B) |
| **E · Art integration** | HeroArt, clip characters, model prep, re-rigs | `scripts/core/{hero_art,clip_character,champion_models,hero_models}.gd`, `assets/heroes/*`, `assets/champions/*`, `tools/prepare_model.mjs` | — |
| **F · Workshop** | gear, sets, relics, trophies, retro grant | `scripts/core/gear_data.gd`, `scripts/meta/workshop.gd`, `scripts/ui/heroes/workshop_view.gd`, `scenes/ui/heroes/workshop*.tscn` | A, B |
| **Loc** | all strings | `scripts/autoload/loc.gd`, `tools/loc_lint.py` | everything |

Meta-1 touch points in the same release (each owned as listed): machine Focus "exactly 40%" (A, `cache_roller`), paid
Road lane Gems → coins (B), `ST_SEAL` rename and gem rarity labels (Loc), Seer 5 → 24 + guest level (B + C).

### 13.2 Phases and gates (a phase starts only when the previous gate is green)

| Phase | Work | Gate (§12.6 test numbers) |
|---|---|---|
| **H0 Foundation** (no visible change) | Save v3 + `migrate_v2` behind the phase flag; `KindView` refactor of Руді / Горан / Мейра with **zero behaviour change**; phone baseline on low + mid | all Meta-1 tests green; `level_check` results identical for the three starters; baseline bench recorded (16) |
| **H1 Rules & data** | consts generated from `heroes_consts.json`; rollers, rules, Meta API, unlocks; `economy_sim.py` port | 1–8, 14, 15, 17 |
| **H2 Champions in the run** (class placeholders: 5 grey-box clip characters) | `Champions`, `RunChampion`, slots, aura, clash accumulator, death / revive, HUD medallions, bot ult policies, new hero kinds with placeholder VFX | 9–12, 16 (absolute perf gates), survival targets |
| **H3 Meta UI** | every screen of §9 in the fusion direction, `CeremonyData`, Codex, Chronicle, Rewrite, Shop «Герої», fallbacks | 13; ceremony share from bot telemetry ≤ 15%; owner UI review on device |
| **H4 Workshop** (WS-F) | Workshop, gear, sets, relics, trophies, retro grant | Workshop tests + sim green with gear; **ships in release 1 if green by the release cut, otherwise release 2** (the retro grant makes a late unlock lossless) |
| **H5 Art integration** (waves, §14) | per character: splash / card → 3D → clips → `HeroArt.state = complete` | per character: palette test, size report, fallback test; only `complete` characters enter the Portal pool, chests and the Seal shop |
| **Release** | every character `complete`, `heroes_sim.py` exit 0 on the shipped data, 18 green | owner sign-off on Q1–Q2 |

### 13.3 Parallelism

H0 is A + B + C together (disjoint files). From H1, D builds against a stub Meta API (fixture accounts) while A / B
finish; C works with class placeholders until E delivers. E runs continuously from day 1 (art waves are the long pole,
§14). F starts when H1 is green.

## 14. Art production plan (for the owner)

### 14.1 The bill (critique X33, counted)

| Asset | Count |
|---|---|
| Hero splashes 9:16 (2160 × 3840 master) · champion cards 3:4 (1536 × 2048) | 10 · 12 |
| Faction backgrounds (720 × 1680) | 4 |
| Model-sheet views (front / side / back / weapon) for Meshy | 19 characters × 4 = 76 (the committed Веста / Люмен / Альба keep their sheets if already made) |
| Skill icons (10 heroes × 4) · champion Action icons (12) · class aura icons (5) | 57 |
| Gear (12) · relics (22) · Star Ore, Beacon, Tome, Seal | 38 |
| Glyphs (classes, elements, factions, horn, states) | ≈ 20 |
| 3D characters through Meshy (+ the Grand Hero Chest) | 19 + 1 (Руді and Горан are re-rigged, Мейра remade) |
| Clips | ≈ 190 (heroes 9 each, champions 8 each, plus specials) |
| SFX | ≈ 70 from **one** stated library with licences recorded in `assets/audio/LICENSES.md` |
| **Total final images** | ≈ 220; owner time ≈ 75–105 h |

The counts above are the launch bill (10 heroes, 12 champions). C23 Тарас, C24 Снаряд and C25 Довбуш each add one
champion card and splash (already supplied by the owner), one Action icon, one relic icon and their champion clips; H26
Сірко adds one hero splash (supplied by the owner), four model-sheet views, four skill icons, one relic icon, one Meshy
character (+ the sabre and letter props) and the hero clips.

### 14.2 Rules for every prompt (the prompt writer applies them in `heroes/heroes_prompts.md`)

- Addendum-4 format: FORMAT · ART STYLE (the Gemini Vesta style reference) · CHARACTER · COLOR LOCK · POSE &
  COMPOSITION · AVOID · uk tool note; complete text, never patches. Mood reference images are never reused; no
  copyrighted character resemblance.
- **COLOR LOCK** = the native gem on every crystal; crystals **non-emissive**, no sparks, a neutral cool-white rim (glow
  and rim are added in-engine). Веста stays as approved.
- **Realistic adult proportions** for heroes and champions (7.5–8 heads for humanoids; beast-kin and creatures
  plausible); only the crowd soldiers stay chibi (addendum 5).
- Per character the order is: splash / card → model sheet (4 views) → Meshy multi-view → remesh → rig → `prepare_model.mjs`
  (heart gem / crystal range written into mask G) → clips.
- Rigging limits: **no extra skinned bones on champions** (rigid attachments or shader sway); hero extras via scripted
  bones + `SpringBoneSimulator3D`; Пава's fan is a separate mesh unfolded by code; form icons use one shader treatment
  (no 20 hand-made loops).

### 14.3 Waves (in the order players meet characters; count Meshy credits before Wave 1)

| Wave | Characters | Why first |
|---|---|---|
| 0 | re-rig Руді and Горан as clip characters; remake Руді / Горан / Мейра in realistic proportions (addendum 5); 5 class placeholder champions | starters and H2 need them |
| 1 | Арін, Ейра, Іскар (first Portal heroes) · Іво, Борко (first chest champions) · 3D of the committed five: Веста, Люмен, Альба, Міла, Отто | L14–L20 content |
| 2 | Вартан, Пава · Тая, Брант, Тео, Олена | Topaz / Opal and Amethyst-chest content |
| 3 | Німб, Дара, Менгір · 4 faction backgrounds · Grand Hero Chest · icon sets | rare chest content and polish |

A character becomes `complete` only with: splash / card, rig + fx masks, 3D model with clips, icons, and passing the
palette and size tests. Until then it stays out of every pool (no player ever sees a placeholder in a reward).

### 14.4 What the owner does per character (≈ 4–5 h)

1. Generate the splash / card from the prompt; pick; cut out (alpha), keep the master.
2. Generate the 4-view model sheet; Meshy multi-view → remesh → auto-rig (humanoid).
3. Pick the Meshy clips from the suggested presets (part R §8 mapping); export GLB.
4. Hand the files to WS-E (`assets/heroes/<id>/` or `assets/champions/<id>/`); WS-E runs `prepare_model.mjs`, keys
   `summon_pose`, sets `HeroArt.state`.

## 15. Risks and open questions

### 15.1 Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | 60 fps on mid Android is unmeasured | H0 phone baseline; absolute gates + fallback ladder (§10.6) before art lock |
| R2 | Art is the long pole (≈ 220 images, 19 Meshy characters, Meshy credits already short) | waves + `HeroArt.state`; release waits for every character `complete` |
| R3 | Scope (4 hub systems, 25 characters, save v3) | phased gates H0–H5; Workshop may slip to release 2 losslessly |
| R4 | The Meta-1 integration is adding Мейра at L5 right now | Q7; the guest level keeps her at L5 either way |
| R5 | `TEAM_DEMAND` is a model (sim) value | LevelSim re-bake on the EXPECTED profile in H2 with real kits; re-bake again when Meta-2 Frost / Rune machines switch Affinity on |
| R6 | Casual win rate 84% sits near the 85% ceiling; EXPECTED-only Invasion floor is 57% (no invariant; Meta-1's own was 53%) | watch telemetry; the Invasion margin `INV_DEMAND_MU` is one knob |
| R7 | Kit budgets are designed, not yet measured | `test_kit_budget` / `test_rule3_kits` in LevelSim close every *(knob)* value before release |

### 15.2 Questions for the owner (defaults already wired in)

| Q | Question | Default |
|---|---|---|
| Q1 | F-CAP: a recut is always one skill-rank cap below a native of the same gem (changes a FROZEN formula) | yes |
| Q2 | F-AWK2: native Topaz / Opal heroes are born awakened (four skills at pull); **F-AWK3 (H1 gate): native Amethysts too** (Мейра, Іскар), else rule #3 breaks across facet counts — the alternative is to accept that case in writing | yes (Amethyst included) |
| Q3 | Update cadence: a regular player owns every hero (11 since Сірко) around day 25–100; this assumes ≥ 1 new hero a month | record the assumption |
| Q4 | Launch shop = cosmetics only (no hero SKUs, no Editions), stricter than decision 5 allows | yes |
| Q5 | Machine rarity labels adopt the gem names in the same release | yes |
| Q6 | Names: «Грані» (your UI answer said «Зірки») and «Майстерня» (you said «Кузня») | Грані · Майстерня |
| Q7 | Мейра: L5 guest level + joins at L24, or joins at L5 as today | guest L5, join L24 |
| Q8 | Store / trademark search on every name + title (26 with Тарас, Снаряд, Довбуш and Сірко) before splash prompts are final | owner runs it |
| Q9 | Люмен's pronoun «воно» / "it" | воно |
| Q10 | Workshop in release 1 or release 2 | release 1 if green |
| Q11 | Пава as a peacock-kin · Німб's tier IV turret catch · Веста's cape crimson-orange vs crimson-rose | keep · keep · crimson-rose in the regenerated splash |
