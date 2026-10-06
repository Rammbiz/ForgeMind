# Heroes & Champions — decision log (critic findings → accepted / rejected)

Final, v2. Ids: **E01–E20** = economy critic (`critique_economy.md`, findings 1–20 of the JSON), **X01–X25** = experience
critic (`critique_experience.md`, findings 21–45 of the JSON). "Accepted" = applied in `heroes_design.md`;
"Accepted (modified)" = applied with different numbers, the reason says why; numbers come from `heroes_sim.py` v2
(`heroes_sim_output.txt`, 80 seeds, exit 0) and `heroes_tables.py`.

Tally: 45 findings (6 blockers, 23 majors, 16 minors) · 36 accepted as proposed · 4 accepted with different numbers
(E07, E08, E09, X15) · 3 merged into another finding (E12, E19, X17) · 2 accepted with one sub-proposal rejected (X01,
X25) · 0 fully rejected. Every blocker and every major is applied.

## Economy critic (E01–E20)

| Id | Sev | Finding | Decision | Reason | § |
|---|---|---|---|---|---|
| E01 | blocker | Money reaches Beacons / Royal Cache via hero Feats; paid heroes move Portal odds; Road listed as a Beacon source | **Accepted** | No hero SKUs / Editions at launch (cosmetics only); every hero Feat pays Tomes; hero Feats outside the Royal-Cache counter; F-65 counts peak ranks (`skills_peak`); Road and Arsenal Track pay no Beacons; `test_two_track_property` + sim structural invariant | 7.3, 7.7, 3.6, 12.6, 8.8 |
| E02 | blocker | Rule #3 proven only kit-blind; Awakenings far over budget; transient breach | **Accepted** | F-AWK2 (native Topaz / Opal born awakened), Awakening band 4% ± 0.5 pp / rank, all 10 Awakenings rescaled; `KIT_INDEX` profile ±1.5% at every reference state (worst 0.9797 eq / 0.9589 max); Rally parity ±5%; champion `KIT_INDEX` ±3% + cross-class test | 2.2–2.5, 6 |
| E03 | blocker | Part S vs part R numbers disagree | **Accepted** | One source: `heroes_sim.py` constants → `heroes_consts.json` → `heroes_tables.py` regenerates every rank / kit / champion table in §6 and §4.4; R's forms, beats and twists trimmed into the item bands | 2.3, 4.4, 6, 12.2 |
| E04 | major | Focus disclosed as 40%, real share 70% | **Accepted** | `FOCUS_TOTAL 0.60` for Portal and chests ("exactly 60%" for any roster size); per-character odds on the (i) sheet; machines adopt "exactly 40%" in the same release | 7.1, 7.2, 7.5 |
| E05 | major | Champion power not tied to kits; must-picks; no aura cap | **Accepted** | `W_C 0.012`, uptime 0.94, class templates trimmed (Cleave 0.07, leap 3, Mage 4 kills / 4 s, Block 5 s + 1 kill, Healer 3 / pulse), `AURA_CAP 0.40`, Ever-Fan 0.06, invariant champions + synergy ≤ 12% at L60 (measured 7.7–8.6%) | 4, 8.8 |
| E06 | major | Recut past one gem is worthless | **Accepted** | F-CAP `SKILL_BASE[g] − [g>n] + [f5]` (owner sign-off Q1) | 2.2, 2.4 |
| E07 | major | Hero coin sinks crowd out machines | **Accepted (modified)** | Coins removed from skills, recut and Workshop as proposed; offset is Ult **+5%** / rank (not 6%) with `lv_ult 0.036`, Attack +1%, Tome income ≈ ×0.45 and explicit Star Ore income ≈ ×0.45 — 6% left machines at 48–50% of L60 growth in the full run; final 50 / 51 / 52%; rank-9 pacing targets ≤ day 75 / 110 adopted | 3.3, 8.3 |
| E08 | major | Migrated players face the re-bake without the systems | **Accepted (modified)** | Lump grant on update day with the final unlock levels and income constants (Beacons `min(60, 0.2 × (L−20) + 2 × bosses after L20)`, Hero Chests `min(20, ⌊(L−14)/3⌋)`, Grands = bosses after L14, Tomes 1 × bosses after L30, EXPECTED Champion Level, welcome ×10, scripted chests, retro grant); measured worst deficit vs a fresh account in §8.7 (≤ 3 pp) | 12.3, 8.7 |
| E09 | major | Plateau and dead Tomes / Seals | **Accepted (modified)** | Owned Seal pick = 2 × DUP; Hero Chests hold no Tomes, Grand 2, overflow 20 : 1; Chronicle pages **10 / 15 / 20 / 30 / 40** (115 per hero) instead of 20 … 80, because total Tome income was cut further for E07; banked Tomes and Seals at day 180 in §8.6 | 3.3, 3.5, 7.4, 8.6 |
| E10 | major | Time-to-fun: first luxe after D3; welcome ×10 Topaz only 40% | **Accepted** | Disclosed welcome rule «Серед десяти — щонайменше Топаз» (measured 100%); champions L18 → **L14**, Portal L22 → **L20**; EXPECTED includes the welcome Topaz | 7.1, 11, 8.5 |
| E11 | minor | Too many currencies | **Accepted** | One «Зоряна руда / Star Ore» replaces 4 faction materials (−3 currencies) | 3.4, 1.3 |
| E12 | minor | Facets feel empty (+0.73%) | **Accepted (merged with X06)** | Facets are presented as progress (micro, batched, engraving), the Manage row prints the true value «+0,73%» in small text; luxe on Full facets | 9.3 |
| E13 | minor | Per-hero odds and "team hero ×2" not shown | **Accepted** | (i) sheet lists every eligible hero's current % and the chest hero-card weight | 7.2, 9.3 |
| E14 | minor | Paid Road lane pays Gems | **Accepted** | Paid Road Gem nodes pay coins; Gems stay earned-only | 7.7 |
| E15 | minor | S's lever q 1.08 / a 0.0074 breaks the frozen check | **Accepted** | `a = 0.0073` (1 + 5a = 1.0365 ≤ 0.96 × 1.08 = 1.0368) | 2.2 |
| E16 | minor | Beacon income above the framework target | **Accepted** | Boss Beacons 3 → 2, Feat and Track Beacons removed; final per-day income in §8.4; the remaining surplus is kept on purpose for time-to-fun and listed as Q3 | 7.3, 8.4, 15 |
| E17 | minor | `TEAM_B2_CAP` unchecked | **Accepted** | `TEAM_B2_CAP 0.20` + `level_check --budget` gate | 5.2, 12.2 |
| E18 | minor | Meta-2 Affinity moves the floor | **Accepted** | `TEAM_DEMAND` versioned with the data, re-baked in the same release, listed in the changelog | 5.2, 15.1 |
| E19 | minor | Opal duplicate drought | **Accepted (merged with E09)** | Owned Opal Seal pick = 200 fragments = one Opal Full facets | 7.4 |
| E20 | minor | EXPECTED policy spends random Portal duplicates | **Accepted** | EXPECTED gets zero Portal duplicate fragments; it includes only the disclosed welcome Topaz and the two scripted champions | 8.2 |

## Experience critic (X01–X25)

| Id | Sev | Finding | Decision | Reason | § |
|---|---|---|---|---|---|
| X01 | blocker | Awakenings break rule #3; Amethyst+ natives should be born awakened; band ±10% | **Accepted (modified)** | Same fix family as E02. Born awakened = native **Topaz / Opal** only (E02's version): the measured grid has no transient breach with it, Amethyst natives (Мейра, Іскар) keep Awakening as their Full-facets reward, and progressive disclosure keeps Мейра at 3 skills at L24. Band 4% ± 0.5 pp (= ±12.5%), inside the critic's tolerance; `test_awaken_band` added | 2.2, 12.6 |
| X02 | blocker | Two-track firewall: Feats, Editions | **Accepted** | Feat counters count only `via ∈ {start, progress, portal, seal, chest, migration}`; no Editions and no hero SKUs at launch; two-track test | 3.6, 7.7, 12.6 |
| X03 | blocker | Parts disagree; not implementation-ready | **Accepted** | Same as E03; Loc copy is data-filled with a lint against literal `\d+%` | 12.2, 12.4 |
| X04 | major | Ceremony budget breaks with U's timings | **Accepted** | One `CeremonyData` table read by the UI and the sim (facet 0.35 batched, skill 0.6, form 1.6, Full facets 1.6, chest 1.6 / 1.2 without NEW, cameo 1.5); final full run 14.2 / 14.5 / 14.2% | 9.4, 8.3 |
| X05 | major | ~30 new nouns; locked axes shown early | **Accepted** | Progressive disclosure table, synergy simple mode until L20, role line first, «Довідник / Codex», teasers only 2 levels early | 11.3, 5.5 |
| X06 | major | Facet / recut upgrades feel empty | **Accepted** | Facets as progress; luxe on Full facets and the first rank in the new cap; Recut screen leads with what it unlocks | 9.3 |
| X07 | major | Forgewall and ult VFX hide the gate row | **Accepted** | Gate-legibility rule (≥ 3 : 1), knee-high rampart, `no_depth_test` labels, α ≤ 0.35, `hud_lab --gate-legibility` | 10.2, 6.8 |
| X08 | major | COLOR LOCK hues collide with gate / pickup colours in the run | **Accepted** | Run material neutralises the G-mask crystal region except during the character's own ult; ΔE ≥ 10 test | 10.3 |
| X09 | major | Mage aura contradicts decision 14; aura share unsimulable | **Accepted** | Fixed `AURA_SHARE`; Mage aura = soldiers in the ring apply the element status (proc 0.15); `AURA_CAP 0.40` | 4.2, 4.3 |
| X10 | major | `ceil` clash damage; champions never die in S | **Accepted** | Fractional accumulator; LevelSim models HP / death / revive; survival targets; uptime 0.94 in the power model | 4.2, 8.1 |
| X11 | major | 60 fps unproven; delta-only gates | **Accepted** | Absolute gates on low / mid phones, thermal soak, fallback ladder, bench before art lock | 10.6 |
| X12 | major | Rules written twice (Run + LevelSim); bot ult policies missing | **Accepted** | `KindView` with pure static kinds; per-kind `ult_worth` for all 10 heroes; `test_kind_parity` ±3% | 10.4 |
| X13 | major | Art bill ≈ 220 images; rig extras Meshy cannot make | **Accepted** | `HeroArt.state` gating, waves, class placeholders, no extra skinned bones on champions, SpringBone for hero extras, Пава's fan as a mesh, one SFX library | 14 |
| X14 | major | Prompt pack for all 22 missing | **Accepted** | Rules and wave order fixed here (§14.2); the prompts themselves are the next workflow step (`heroes/heroes_prompts.md`), written from §6 briefs; non-emissive crystals, neutral rim; Веста stays as approved | 14.2 |
| X15 | major | Scope too large for one release | **Accepted (modified)** | Phases H0–H5 with gates; the Workshop is the last workstream and **ships in release 1 if green, otherwise release 2** (not unconditionally H2 as proposed: it is ready-made content and the retro grant makes either choice lossless) | 13 |
| X16 | major | Missing flows (Rewrite UI, Shop, overflow honesty, save failure, orphans, art fallback, caps, clock) | **Accepted** | All specified | 9.3, 9.6, 12.1 |
| X17 | major | Tomes pile up; add a cosmetic Tome sink | **Accepted (merged with E09)** | Implemented as «Хроніка героя / Hero Chronicle» (same idea as «Скрипторій»; one name kept) | 3.5 |
| X18 | major | Focus copy wrong; odds changelog unowned; «Ще ×10» link | **Accepted** | Odds sentences generated from data, `odds_table --diff` changelog, «Змінено у» marker, «Ще ×10» removed | 7.2, 9.3 |
| X19 | major | Play Asset Delivery impossible for sideloaded APKs | **Accepted** | APK cap 140 MB, part U import settings, per-character size report in CI | 10.7 |
| X20 | minor | «Огранка» vs «Повна огранка»; «Сила» collides | **Accepted** | «Повні грані / Full facets», «Міць / Might»; glossary + `loc_lint` | 1.3 |
| X21 | minor | Names / titles with IP or meaning problems | **Accepted** | Snowquill, Storm Aegis, Thunder Fox, Frost Herbalist, «Кам'яний велет / the Stone Titan»; trademark search Q8 | 6.0 |
| X22 | minor | Generic-UI primitives default to pills; emoji glyphs | **Accepted** | Primitive table in the fusion direction; radius lint; emoji lint | 9.1 |
| X23 | minor | Showcase too dense; medallions may cover gates | **Accepted** | Gear moved to the Manage sheet, facets + fragments one row; medallion fade / bottom-row fallback checked in `hud_lab` | 9.3, 10.5 |
| X24 | minor | Play tips the thumb cannot follow; three hazard-ignoring ults; Sunstride control | **Accepted** | Tips name x, a gate kind or an ult moment; Пава form III Double Count; Вартан form II wall HP +50%; Sunstride visual only | 6.4, 6.7, 6.8, 6.10, 10.2 |
| X25 | minor | Owner confirmations (Seer timing, Грані / Майстерня names, update cadence) | **Accepted (partly rejected)** | Asked as Q3, Q6, Q7 with defaults wired in. Rejected: the alternative "slower chest Topaz" option — collection pace is already slower in v2 (all 10 heroes regular p50 in the 25–100-day window), so no extra slow-down is needed | 15.2 |

## Partly rejected items (summary)

1. **X01 / finding 21 — Amethyst natives born awakened.** Kept to Topaz / Opal (E02 version). Amethyst natives
   awaken at Full facets (their felt f5 beat); rule #3 holds without the extra rule (worst eq 0.9797, max 0.9589).
2. **X25 / finding 45 — slower chest Topaz.** Not needed; v2 collection is already slower than v1.

Other numeric deviations from the critics' proposed values (all measured in the final run): Ult step +5% (critic +6%),
Chronicle 115 Tomes / hero (critic 230), Hero Chest Tomes 0 (critic 1), boss Beacons 2 (critic "3 or 2"), Invasion
`TEAM_DEMAND` × 0.98 (new: the 80-seed run showed casual loss-streak p90 4 at × 1.00; × 0.98 restores p90 3 and max
attempts p90 4).
