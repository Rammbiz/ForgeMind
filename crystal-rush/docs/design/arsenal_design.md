# Crystal Rush — ARSENAL & META design (v2, implementation-ready)

Owner request (uk → en): "Many different weapons. So you can upgrade a lot. Some kind of packs too. Take references NOT only
from this genre. Make everything full-fledged. Heavy luxe!"

Inputs: `plan2.md` (game design, Ukrainian), `etap1_spec.md` (run build spec, being implemented), five research sweeps,
three critic reviews of v1. Code read: `scripts/autoload/save.gd`, `scripts/core/balance.gd`, `scripts/core/models.gd`,
`scripts/core/weapon_models.gd`, `scripts/core/effects.gd`, `scripts/core/worlds.gd`, `scripts/ui/hud_view.gd`,
`scripts/ui/menu.gd`, `scripts/main.gd`, `tools/prepare_model.mjs`.

Every number in this document is printed by `scratchpad/economy_sim.py` (v2) or `scratchpad/tools_proto/palette_check.py`.
Output: `scratchpad/economy_sim_output.txt`. The sim exits 1 when an invariant fails; `tools/check_all.sh` (§9.8) runs it.

Hard constraints honoured everywhere: offline-first single player; no forced ads; no timers that block play; no
pay-to-win pressure; random rewards are EARNED only and show odds and pity; anything bought with money is deterministic
and is a non-consumable entitlement; level difficulty never scales to account power (LevelGen keeps
`base_army = START_ARMY`, etap1 §4).

**Design rule added in v2 (applies to every permanent upgrade, Haven passive and paid item):** it must (a) add an
option, (b) amplify a skilled choice, or (c) be cosmetic. Upgrades that erase a run decision (bigger pickup radius,
cheaper crates, weaker fortress, guaranteed top stair) are not allowed. Code review checklist item.

### v2 at a glance (what changed from v1)

- Packs are **Caches** (the in-run breakable stays a *geode*). Two pity systems instead of five; guarantees are
  pool-aware; the disclosed odds are computed from the roller itself (§5).
- In-run: crates are hero-only targets with a gold BONUS segment, crates come in pairs from L5, new **RANK** and
  **CATALYST** gates, and a gold **EVOLVE/FUSE** gate when a recipe is met. Measured: Rank III in 73% of L11–30
  levels, an Evolution or Fusion in 34% (L11–30) and 56% (L31+) (§3.2).
- Every machine has one **verb** bound to the hero: LANE, PAINT, PLACE or RULE (§2.2).
- Beats moved to where players are: Talents Lv3/6/10, Ascension Lv8, **Apex** Lv12, Prestige Lv13–15. Regular
  player's first Apex at campaign level 48 (§2.1, §6.4).
- Four wallet currencies (Coins, Gems, Crowns, Blueprints) + Wild Blueprints + Boss Cores shown as a ring. Dust,
  Forge Keys, Sigils, World Forge and the Workshop markup are gone (§6.1).
- Machines carry 73–75% of power growth (v1: ≈20%). Arsenal Rating no longer gives damage.
- Retry assist "Reinforcements", fair loss payout, no ad revive, capped ×2 ads. Measured walls: casual boss win
  ≥ 72% in every world, loss streak p90 3 (§6.4).
- Post-campaign loop specified: Invasion (56 levels), Nightmare, weekly Expedition, replay (§6.5); 180-day sim.
- Real-money items are a fixed SKU list of non-consumables with a total power cap of ≈5 000 coin-equivalent (§6.6).
- Seven chassis (six families + Rift) plus a Fusion chassis, crews, 100 solid-only Meshy prompts with separate moving parts, FIT data, asset budget (§10).

---

## 0. Glossary (locked in WS0; `tools/loc_lint.py` rejects any display name used for two things)

| Term (en) | uk | Glyph | Meaning | Code id |
|---|---|---|---|---|
| Machine | Машина | — | A war machine of the Arsenal. 24 of them. | `machine`, `ArsenalData.MACHINES` |
| Level (Lv1–15) | Рівень | number | Permanent account level of a machine. | `lvl` |
| Rank I–III | Ранг | ▲ chevrons | In-run level of a fielded machine; resets every run. | `rank` (was ★/star) |
| Talent | Талант | — | Pick 1 of 2 at Lv3, Lv6, Lv10. Free respec. | `talents` |
| Lead | Лідер | crown | Deck slot 1; fielded at Rank I from the start once Lv5. | `lead` |
| Ascension | Піднесення | — | Lv8: permanent new form; Epic+ choose branch A/B. | `branch`, `ASCENSION_LEVEL` |
| Apex | Апогей | ◎ ring | Lv12 active, fired in the ult chain. | `apex` (was Overcharge) |
| Prestige | Престиж | laurel | Lv13–15: +8%/level and frame tiers; Lv15 = "Mastered". | — |
| Evolution | Еволюція | gold gate | ONLY the in-run transformation of a machine (or hero card) via the gold EVOLVE gate. | `EVOLUTIONS` |
| Fusion | Злиття | gold gate | Two Rank II+ machines merge via the gold FUSE gate. | `FUSIONS` |
| Family | Родина | glyph | Kinetic, Volt, Frost, Plasma, Tech, Rune (+ Rift = Mythic). | `family` |
| Deck | Колода | — | Machines that crates may hold (3–6 slots). | `deck` |
| Cache | Схованка | — | A pack: Stone, World, Royal, X-Ray. Cracked on the Altar. | `CACHES`, `CacheRoller` |
| Geode | Жеода | — | ONLY the in-run breakable obstacle (etap1 kind `geode`). | `geode` |
| Altar | Вівтар | — | 3D scene where World/Royal Caches are opened. | `CacheAltar` |
| Blueprint | Креслення | scroll | Machine-specific copy; levels that machine. | `bp` |
| Wild Blueprint | Дике креслення | scroll + ✦ | Counts as a blueprint of any machine of its rarity. | `wild[r]` |
| Coins | Монети | coin | The only soft currency. | `coins` |
| Gems | Самоцвіти | gem | Earned-only premium currency for cosmetics and X-Ray Caches. | `gems` |
| Crowns | Корони | crown | 0–3 per level (skill rating) and the Haven currency. | `crowns` (was crystals) |
| Boss Core | Ядро боса | ring segment | 3 forge a Mythic at the Rift Anvil; shown as ring segments, not a wallet chip. | `cores` |
| Rift Anvil | Ковадло Розлому | — | Where Mythics are forged. | `RiftAnvil` (was Core Forge) |
| Haven | Притулок | — | Per-world rebuilt diorama, 5 stages, paid in Crowns. | `haven.gd` (was Sanctuary) |
| Shrine | Святилище | — | ONLY plan2's in-run 1-of-3 card stop. | plan2 §3.1 |
| Citadel | Цитадель | number | Σ Haven stages (0–35); hub headline number. | `citadel` |
| Glory ◆1–5 | Слава | ◆ | Hero rank from world bosses beaten with that hero. | `glory` (was hero ★) |
| Awakening I–III | Пробудження | — | Hero look tiers at hero Lv10/20/30. | (was hero "Evolution") |
| Reinforcements | Підкріплення | + chip | Retry assist after losses on one level. | `assist` |
| Gate Tuner | Камертон | — | Machine #20 (was Overcharger). | `tuner` |
| Phoenix Pyre | Багаття фенікса | — | Mythic #23 (was Phoenix Forge). | `phoenix` |
| Siege Ram | Облоговий таран | — | Machine #14 (was Crystal Ram). | `ram` |
| Rune (family) | Руна | rune | Family #6 (was Crystal); status SEAL. | `rune` |
| Road | Шлях | — | Never-expiring reward chapters (was Crystal Road season). | `road.gd` |
| Expedition | Похід | — | Weekly 5-level seeded run. | `expedition.gd` |
| Halo | Ореол | — | Finish tier 5 (was Prism Aura). | `FINISHES` |

"Crystal" is reserved for the game title and world art. "Star" is reserved for plan2's star-shards. "Forge" is no
longer a system name (only the verb: "forge a Mythic"). "Overcharge/Overclock/Overcharger" are gone; the hero keeps **Overdrive** (plan2 §4), the only "Over-" word.

---

## 1. Pillars — what the meta adds and why

1. **A collection worth knowing (24 machines, 6 families + Rift).** Every machine has ONE damage shape, ONE job and
   ONE verb bound to the hero (§2.2), readable as a black silhouette at 64 px (Plants vs Zombies roles, Bloons TD 6
   tower classes, Into the Breach telegraphs). Worlds add enemy properties (§2.4) that each have answers inside that
   world's own unlocks, so the collection matters every level without hard walls.
2. **Two progression clocks per machine: power and beauty.** Power = Lv1–15 (+8% per level, linear, Brawl Stars) with
   beats at Lv3/6/10 (talents, Rush Royale/DRG), Lv5 (Lead), Lv8 (Ascension, Monster Hunter branches), Lv12 (Apex,
   Brawl Stars Hypercharge), Lv13–15 Prestige. Beauty = Mastery Finishes earned by USING the machine (Marvel Snap
   ladder, Rocket League goal explosions): each tier changes what you see IN the run (§3.8). Finishes give no power.
3. **Runs feed the collection; the collection shapes runs.** Platinum NEW crates unlock machines through play (Dead
   Cells blueprints, kept even on a loss). The Deck decides what crates hold (Clash Royale deck, PvZ seed slots). ONE
   in-run build system: crates, RANK gates, CATALYST gates and the gold EVOLVE/FUSE gate all live in the gate grammar
   the player already reads (plan2 #7 Crowd Evolution rank gates, Vampire Survivors evolutions, TFT traits).
4. **Packs are a ritual, not a slot machine.** Caches are cracked by the hero on the Altar. The tell shows the final
   rarity on the first crack (Genshin meteor colour) — no suspense ladder, no illusion of control. Fairness from
   Hearthstone (pity, duplicate protection), Marvel Snap (never an owned NEW item), Fortnite X-Ray Llamas (paid =
   shown). Random = earned only. Two pity rules, one visible bar.
5. **Every upgrade is a ceremony, sized to its weight.** Three ceremony tiers: micro 0.35 s, standard 1.2 s, full ≤ 3 s
   (§7.3). Measured ceremony share: 13–14% of session time (budget 15%). Two-tap upgrade (Clash Royale), haptic
   composition primitives, RewardFly (Balatro, Peggle). Badges only on the Best upgrade and Deck machines.
6. **Finite, legible, fair economy.** Four wallet currencies, each with one job. Same coin price per level for every
   rarity (Clash Royale 2025). No cap raises after launch. A visible next milestone, the full total in a details sheet.
   Free respec everywhere. Daily things bank and never reset. A stuck player gets help that is not account power
   (Hades God Mode, Crash Aku Aku → Reinforcements).

Deliberately NOT here: chest timers, energy, speed-ups, paid random packs, consumable IAP, seasons that expire, power
on a timer, rating→damage loops, upgrades that delete decisions, offers or ads after a defeat or on a reveal, level
difficulty scaled to account level (Mob Control ±7 lesson).

---

## 2. ARSENAL — 24 war machines + army gear

### 2.1 Shared rules

**Rarity** sets the starting level, blueprint needs and how unusual the behaviour is — never the ceiling (all cap Lv15).
Rarity colour lives in the META UI only (cards, Altar, Vault). In the run a crate's rarity reads from its SHAPE and
MATERIAL and the pips on its forecast label (§3.3), never from hue, because every hue in the run already means a gate
(models.gd `GATE_KINDS`: good blue, bad red, charge violet, power gold, arm teal, hidden grey).

| Rarity | uk | Meta colour | Frame (double-codes rarity) | Crate shell in the run | Start Lv | Machines |
|---|---|---|---|---|---|---|
| Common | Звичайна | silver `#D6DEE6` | plain steel | steel, 1 pip | 1 | 6 |
| Rare | Рідкісна | azure `#3FA9FF` | inner glow | sapphire inlay, 2 pips | 2 | 6 |
| Epic | Епічна | violet `#B06CFF` | animated energy lines | amethyst ribs, 3 pips | 3 | 5 |
| Legendary | Легендарна | amber `#FFB52E` | gold filigree + light pillar | gold filigree, 4 pips, tall white beam | 4 | 3 |
| Mythic | Міфічна | opal hue-cycle shader | art breaks out of the frame | opal shell, 5 pips, tall white beam | 5 | 4 |

**Families** read first by SHAPE (projectile + glyph + status overlay on the squad), colour second. Colours were picked
with `palette_check.py` (CIEDE2000; Machado 2009 CVD simulation): every family accent is ≥ 21.5 ΔE from every gate,
enemy, army and coin colour in normal vision and ≥ 24.7 from each other; family-vs-family stays ≥ 9.6 under
protanopia, deuteranopia and tritanopia. Family-vs-gate under CVD falls to 1.6–7.3 ΔE (no 6-colour set can avoid
that next to 6 gate colours; the search maximum is 22.9 ΔE even in normal vision), so shape carries identity:
a projectile is never gate-shaped and a gate is never projectile-shaped.

| Family | Accent | Glyph | Projectile shape | Status | Squad overlay (CrowdView.set_overlay) | 2-set | 3-set |
|---|---|---|---|---|---|---|---|
| Kinetic | pale copper `#D9B8A6` | chevron | solid bolt / shell with a white tracer | STAGGER | none (push) | +15% damage to structures | +1 pierce on Kinetic shots |
| Volt | storm orchid `#FFA5FF` | bolt | jagged arc, forked line | JOLT | crackle flicker | +1 jump on every chain | hero hits apply Jolt |
| Frost | snow ivory `#F8FFD8` | snowflake | shard / cone mist | CHILL | frost rim, blue-white | +1 Chill stack per hit | rotors/sweepers within 4 u −30% speed |
| Plasma | plasma rose `#D80A71` | orb | round orb with a soft tail | BURN | ember flicker | Burn lasts 4 s | burning squads explode on wipe (2 dmg r1) |
| Tech | signal lime `#49FF0C` | reticle | reticle-missile, tiny drone tracer | MARK | reticle decal on the counter | Mark +10% | +1 projectile on homing machines |
| Rune | rune indigo `#0A0AD8` | rune | rune glyph disc | SEAL | engraved rune ring | Seal lasts 6 s | +1 soldier per 10 machine kills |
| Rift (Mythic only) | opal shader | eye | per machine | — | — | counts as ANY family for sets (best) | — |

Code re-map (WS3/WS4): `WeaponModels.COLORS`, `Effects.KINDS` and `HudView._weapon_color()` switch to these family accents
(the rocket trail stops being enemy orange and becomes Tech lime; the ballista bolt becomes Kinetic copper with a white
tracer instead of power-gate gold). The hero Bolt (orange fox) keeps his fur colour; his projectiles and ult use the Volt accent and a white team rim, so
nothing he fires reads as enemy orange.

**Statuses** (`ArsenalData.STATUSES`; they live on the SQUAD, never per unit):

| Status | stacks_per_hit | max_stacks | decay_s | Rule |
|---|---|---|---|---|
| STAGGER | proc | 1 | 0.4 | squad pushed back 0.3 u; a light hit on a staggered Armored squad ignores the Armored penalty |
| JOLT | proc | 3 | 2.0 per stack | each stack: the squad's next received hit chains to 1 more squad within 2 u (consumes the stack) |
| CHILL | proc | 3 | 1.5 per stack | −10% speed and −10% clash damage per stack; at max → FREEZE 1.0 s (deals 0 clash damage), then 1.0 s immune |
| BURN | proc (refresh) | 1 | 3.0 | removes `1 × acc_mult(source)` units/s (fraction accumulates); when the squad is wiped, Burn jumps to the nearest squad within 3 u |
| MARK | proc (refresh) | 1 | 3.0 | vs-bucket 1.25; reveals Phantom |
| SEAL | proc (refresh) | 1 | 4.0 | each unit killed while sealed: 20% chance of +1 coin (counts toward the Harvester cap) else +0.5% ult charge |

`proc` is the number of stacks one hit applies (Gatling 0.3, Laser tick 0.2, Tesla jump 0.5, Drone 0.5, all others
1.0); fractional stacks accumulate per squad. Chill-resistant squads (Ice) need 5 stacks to freeze and lose 5% per
stack; Burn-resistant squads (Volcano) burn at 0.5 units/s.

**Reactions** (exactly three; world-space word in both status colours + unique VFX + 60 ms hit-stop the first time per
run): Jolt+Chill = **SUPERCONDUCT** (chain damage gets vs ×2.0 on frozen squads); Burn+Chill = **THERMAL SHOCK**
(burst of `5 × acc_mult(trigger)` units, removes both statuses); Mark+Burn = **FLARE** (Burn spreads to the 2 nearest
squads within 3 u).

**Damage formula — exactly three buckets** (Balatro lesson; cards write "+" for bucket 2 and "×" only for bucket 3):
```
dmg  = [ base × acc_mult(L) × rank_mult[R] × evo_mult ]      # bucket 1: the machine (one number on its card)
     × [ 1 + Σ additive ]                                      # bucket 2: sets, Banner, talents, Lead Engineer, overflow, Prism amp
     × vs                                                      # bucket 3: ONE conditional multiplier
acc_mult(L) = 1 + 0.08 × (L − 1)                               # Lv15 = ×2.12
rank_mult   = [1.0, 1.5, 2.1]                                  # = Balance.WEAPON_LEVEL_MULT (etap1)
evo_mult    = 1.25 for an evolved machine; a fused machine uses its own base
overflow    = after Rank III, each further copy: +10%, +7%, +5%, then +3% (bucket 2)
vs          = clamp(max(1, every "vs" condition that applies) × armor, 0.25, 3.0)
              conditions: structures (per machine, e.g. Rockets 1.5, Railgun 2.0, Ram 2.0, Starfall 2.0),
              Mark 1.25, clumped 1.5 (Gravity), Shatter 1.5 (Cryo III vs frozen, Kinetic only),
              Swarm 1.5 (Gatling), Superconduct 2.0
armor       = 0.5 if the target is Armored and the hit is light and the squad is not Staggered, else 1.0
light       := base × acc_mult × rank_mult < 2.0
```
Status, reaction and Apex damage use the SOURCE machine's `acc_mult × rank_mult`, never `vs`. **Chance stats**: each
source either declares a flat chance or `n` stacks for `p = 1 − 1/(1 + 0.15·n)` (Aegis block n = 4.4 → 40%; a second
source adds its n). **Flat caps**: pierce ≤ 6, chain jumps ≤ 8, projectiles per volley ≤ 5 (Doom Barrage 12 is its own
burst), summons ≤ 3, drones ≤ 6. Cards always show the CURRENT total ("Block 40%").

**Per-level beats (every machine)** — moved in v2 so a regular player meets each one during the campaign
(sim, §6.4, regular player: first Lv8 at campaign level 21, first Lv10 at L38, first Lv12 at L48):

| Lv | Beat |
|---|---|
| 1–15 | +8% to the machine's PRIMARY stat per level (damage for damage machines; utility primaries in each sheet, §2.5) |
| 3 | **Talent I**: pick 1 of 2 (family template). Free respec any time. |
| 5 | **Lead**: when in Deck slot 1, the run starts with it fielded at Rank I |
| 6 | **Talent II**: pick 1 of 2 (family template) |
| 8 | **Ascension**: new look + behaviour change. Common/Rare: one form (shader tier + projectile VFX, no new mesh). Epic/Legendary/Mythic: branch A or B (new Meshy module each); switch free at any time |
| 10 | **Talent III**: pick 1 of 2 (unique per machine) |
| 12 | **Apex**: active fired in the ult chain (below). Power budget ≤ one good gate pick. |
| 13–15 | **Prestige**: still +8% per level; frame tiers Bronze/Silver/Gold; Lv15 = gold "Mastered" frame + the machine's Prestige finish. These levels are the long tail (§6.5). |

Family talent templates (Talent I at Lv3 | Talent II at Lv6). Meta-1 ships statuses, so both options of every pair ship:
- Kinetic: "Tempered" +15% damage / "Long Barrel" +20% range | "Piercing" +1 pierce / "Concussive" Stagger push ×2
- Volt: "Capacitor" +1 chain jump / "Hair Trigger" +20% fire rate | "Lingering Charge" Jolt +1 s / "Arc Reach" +1 u jump range
- Frost: "Deep Cold" Chill −5% more per stack / "Wide Spray" +15% area | "Hard Freeze" Freeze +0.5 s / "Brittle" frozen squads take +25% (bucket 2) from Kinetic
- Plasma: "Hot Core" Burn +0.5 units/s / "Wide Bloom" +15% splash radius | "Wildfire" Burn jumps +1 / "Fission" +1 split or bounce
- Tech: "Twin Feed" +1 projectile or drone / "Long Link" +20% range | "Paint Target" Mark +10% / "Smart Fuse" homing may target unrevealed Phantoms
- Rune: "Resonance" +20% primary effect / "Wide Field" +15% radius | "Prospector" Seal also gives +0.5% ult / "Echo Stone" effect lingers +1 s

**Arsenal Sync** (AFK Arena resonance): a newly unlocked machine starts at `max(rarity start, min(7, 3rd-best machine Lv − 2))`.
The cap 7 keeps the Ascension beat for the player.

**Coins and blueprints per level** (`EconData.COIN_TO`, `BP_TO`; coins identical for every rarity; blueprint needs scale
with drop rates so rarities level at the same pace — sim, day 60 casual average: C 11.2 · R 11.2 · E 12.0 · L 11.8):

| Target Lv | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Coins | 40 | 80 | 150 | 250 | 380 | 540 | 740 | 980 | 1 260 | 1 580 | 1 950 | 3 600 | 5 200 | 7 500 | 24 250 |
| BP Common | 0 | 3 | 4 | 5 | 6 | 8 | 10 | 12 | 15 | 18 | 22 | 40 | 55 | 75 | 273 |
| BP Rare | – | 1 | 2 | 2 | 3 | 3 | 4 | 5 | 6 | 7 | 9 | 16 | 22 | 30 | 110 |
| BP Epic | – | – | 1 | 1 | 1 | 1 | 2 | 2 | 2 | 3 | 3 | 6 | 8 | 10 | 40 |
| BP Legendary | – | – | – | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 3 | 4 | 5 | 21 |
| BP Mythic | – | – | – | – | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 3 | 4 | 5 | 19 |

Lv2 of a Common costs coins only: the first Arsenal visit (after L3) needs no blueprint system (§4.6).
Full Arsenal = **578 270 coins** (24 machines from their start levels). Cap 15 is final: the game grows with new machines
and cosmetic ladders, never a Lv16.

**Apex (Lv12) input — no new tap targets.** The thumb is always dragging, so Apex never needs its own button:
- When the hero ult fires, every machine whose Apex ring is full fires its Apex in a chain right after the ult
  (0.25 s apart, a name banner per Apex, one combined cinematic, one hit-stop 70 ms at the start).
- Settings → "Auto Apex" (default off): a full Apex fires on the next worthy target instead (a squad ≥ 30% of the army,
  the fortress, a boss, or for utility machines its own trigger: next gate row for Gate Tuner and Echo, next hazard for
  Aegis, next loss burst for Phoenix).
- Charge: 25 s of being fielded fills the ring; each kill by that machine (or each own event for utility machines: a
  gate hit, an absorb, a rebirth, a toll, a pickup) takes 1 s off. The ring is drawn ON the machine in the world
  (`Models.ult_ring` style, family accent); the HUD slot only mirrors it.
- Signals: `apex_ready(kind)`, `apex_fired(kind)`.

### 2.2 Verbs, positions and targeting

Every machine has exactly one verb bound to the hero, and each sheet (§2.5) has a line "Verb — what the player does
differently". A machine that cannot fill that line was rewritten in v2.

| Verb | Rule | Machines |
|---|---|---|
| **LANE** | Fires straight down the hero's x (corridor ±0.8, etap1 `CORRIDOR`): steering lines up queued targets and the fortress gate. | Ballista, Laser, Railgun, Prism, Cryo, Siege Ram |
| **PAINT** | The hero's last hit puts a world reticle on its target (`Run.painted`, 2 s, refreshed by every hero hit); these machines lock onto it, else the nearest hostile ahead. The hero commands the arsenal (shooter pings, RTS focus fire). | Plasma Cannon, Rocket Pod, Drone, Gatling, Tesla, Gravity Well |
| **PLACE** | Lands at the hero's x, N u ahead, with a friendly telegraph (§2.8). Steering places it. | Siege Mortar (+12 u), Frost Miner (+8 u), Arc Fence (+3 u, travels with the army), Sentinel (+4 u), Starfall (+RUN_SPEED×1.2+2) |
| **RULE** | Acts on the gates, hazards, pickups or clashes the army passes. Steering chooses what it acts on. | War Banner, Harvester, Aegis, Gate Tuner, Chrono Bell, Phoenix Pyre, Echo Reactor |

**Damage budget** (checked by `level_check --budget` with the EXPECTED profile; the SIM table in §2.5 is the input):
at each band's expected army, the three fielded machines deal 35–55% of all player damage (hero + army volleys +
machines) and no single machine more than 30% outside its Apex. Utility machines are budgeted by `control_s` and
`gate_gain` instead. The etap1 numbers of the 5 original machines are the anchor (note: the etap1 Laser at full ramp
already out-damages Bolt on one target, so it is the first machine the budget check looks at); a band that misses the
budget is fixed by tuning machine bases, never the hero.

**Hostiles** (etap1 §5.6) = squads, turrets, barricades, in-run geodes, fortress, bosses. **Crates are NOT machine
targets** (hero and ult only, §3.3). Machines never fire at gates except Gate Tuner.

**Positions (convoy)**: fielded machines roll on the army's flanks at the depth of the army's centre:
slot A at `x = −(blob_radius + 0.9)`, slot B at `x = +(blob_radius + 0.9)`, both clamped to ±3.0; slot C on the side
with more room, 1.4 u behind. When the army is ≤ 10, the convoy moves 1.0 u ahead of the blob centre. Machines are
drawn at **1.25×** the etap1 size. Evolved/fused machines lead ahead of the army beside the hero (x = hero ± 1.2,
1.5 u behind the hero). **Camera rule** (added to etap1 §5.6 camera tuning): every fielded machine is fully visible above
the bottom 18% of the screen; QA screenshots with 3 machines at army 5 and army 150 (`rshot.sh arsenal_convoy_5`,
`arsenal_convoy_150`).

### 2.3 Roster

Home world = where its platinum NEW crate appears (§3.3). v2 re-homed machines so that every world's NEW trio holds at
least one answer to that world's enemy property (test `test_meta.gd::test_world_answers`), and so that the Cache pool has
an Epic from World 2 and a Legendary from World 3 (§5.4).

Flags (`ArsenalData.MACHINES[id]`): `hits_flying` (can target Flying), `light` (base hit < 2.0 → ×0.5 vs Armored),
`ground_only` (cannot hit Flying), `bypass_shield` (beam or arc: ignores Shielded).

| # | id | Name (en / uk) | Rar | Family | Verb | Shape / job | Home | hits_flying | light | ground_only | bypass_shield |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `drone` | Drone / Дрон | C | Tech | PAINT | spotter: Mark + reveal | W1 Space (owned at start) | ✓ | ✓ | | |
| 2 | `ballista` | Ballista / Балиста | C | Kinetic | LANE | pierce line | W1 | | | | |
| 3 | `cannon` | Plasma Cannon / Плазмова гармата | C | Plasma | PAINT | splash orb + Burn | W1 | | | | |
| 4 | `rockets` | Rocket Pod / Ракетниця | C | Tech | PAINT | homing burst, structures | W1 | ✓ | | | |
| 5 | `mortar` | Siege Mortar / Облогова мортира | R | Kinetic | PLACE | lobbed splash | W1 | | | ✓ | |
| 6 | `gatling` | Gatling / Гатлінг | C | Kinetic | PAINT | anti-Swarm shredder | W2 Reef | ✓ | ✓ | | |
| 7 | `laser` | Laser / Лазер | R | Plasma | LANE | ramping beam | W2 | ✓ | | | ✓ |
| 8 | `railgun` | Railgun / Рейкова гармата | E | Volt | LANE | charged infinite pierce + Jolt | W2 | | | | ✓ |
| 9 | `tesla` | Tesla Coil / Котушка Тесли | R | Volt | PAINT | chain | W3 Mystic | ✓ | | | ✓ |
| 10 | `banner` | War Banner / Бойовий штандарт | R | Rune | RULE | army buff (volleys, clash) | W3 | – | – | – | – |
| 11 | `prism` | Prism / Призма | L | Plasma | LANE | amplifier in the hero lane | W3 | ✓ | | | ✓ |
| 12 | `cryo` | Cryo Sprayer / Кріо-гармата | C | Frost | LANE | cone control | W4 Volcano | ✓ | ✓ | | |
| 13 | `frost_miner` | Frost Miner / Крижаний мінер | R | Frost | PLACE | mines; freezes blades and lava jets | W4 | | | ✓ | |
| 14 | `ram` | Siege Ram / Облоговий таран | E | Kinetic | LANE | anti-structure dash | W4 | | | ✓ | |
| 15 | `harvester` | Harvester / Збирач | R | Rune | RULE | economy (capped) | W5 Ice | | ✓ | | |
| 16 | `arc_fence` | Arc Fence / Дуговий паркан | E | Volt | PLACE | stun wall | W5 | ✓ | ✓ | | ✓ |
| 17 | `aegis` | Aegis / Егіда | E | Frost | RULE | hazard absorb, turret block | W5 | – | – | – | – |
| 18 | `sentinel` | Sentinel / Вартовий мех | E | Tech | PLACE | tank walker | W6 Sky | ✓ | | | |
| 19 | `gravity` | Gravity Well / Гравітаційний вир | L | Rune | PAINT | clump + grounds Flying | W6 | ✓ | | | |
| 20 | `tuner` | Gate Tuner / Камертон | L | Volt | RULE | gate economy | W6 | – | – | – | – |
| 21 | `starfall` | Starfall Array / Зорепад | M | Rift | PLACE | orbital strike | Rift Anvil | | | ✓ | ✓ |
| 22 | `chrono` | Chrono Bell / Хронодзвін | M | Rift | RULE | time slow at gate rows | Rift Anvil | – | – | – | – |
| 23 | `phoenix` | Phoenix Pyre / Багаття фенікса | M | Rift | RULE | army rebirth | Rift Anvil | – | – | – | – |
| 24 | `echo` | Echo Reactor / Ехо-реактор | M | Rift | RULE | gate echo | Rift Anvil | – | – | – | – |

Counts: Common 6, Rare 6, Epic 5, Legendary 3, Mythic 4. Families: Kinetic 4, Volt 4, Frost 3, Plasma 3, Tech 3, Rune 3, Rift 4.

**Role check — one damage shape, one job per family slot** (v1 overlaps resolved: Railgun moved to Volt; Drone is a
spotter, not a damage dealer; Gatling owns Swarm; gate economy belongs only to Gate Tuner and Echo; at most one
clash-loss reducer per family):

| Shape \ Family | Kinetic | Volt | Frost | Plasma | Tech | Rune |
|---|---|---|---|---|---|---|
| line / pierce | Ballista | Railgun | — | Laser (beam) | — | — |
| splash / area | Mortar | — | Frost Miner | Cannon | — | Gravity |
| chain / multi | Gatling (ricochet) | Tesla | — | — | Rockets (homing) | — |
| control | Siege Ram (knockback) | Arc Fence (stun) — Volt's clash reducer | Cryo (freeze) — Frost's clash reducer | — | Sentinel (hold) — Tech's | — |
| support / rule | — | Gate Tuner (gates) | Aegis (hazards) | Prism (amp) | Drone (spotter) | Banner (army) — Rune's clash reducer; Harvester (economy) |

### 2.4 Enemy properties (`ArsenalData.PROPERTIES`, WS2 owns the hooks in `scripts/run/hazards.gd`)

Plan2 world mechanics act on the ROAD and GATES (currents, mirror arches, lava jets); properties act on SQUADS only.
LevelGen emits `squad.props: Array[String]`. A property first appears on world level 3 (after plan2 mechanic A on level 1
and B on level 2), never in the boss's first phase, and on ≤ 50% of the world's squads. Rift squads carry two
properties. Threat preview icons on the map node; deck cards that answer a shown property get a green check.

| id | World | Rule (numbers) | Raider look | Answers (machines; ✓ = in that world's NEW trio) |
|---|---|---|---|---|
| `structures` | W1 Space | baseline: turrets, barricades, fortress (not a squad prop) | — | Rockets (vs 1.5), Railgun, Mortar, Siege Ram, Starfall |
| `swarm` | W2 Reef | the squad shows 2× the units; 1 point of machine/hero damage kills 2 units; in the clash each unit is worth 0.5 soldier | raider mesh ×0.7, teal-shifted orange, "≋" icon | Gatling ✓ (vs 1.5), Cannon, Mortar, Tesla |
| `phantom` | W3 Mystic | the counter shows "?" until the squad is Marked or hit by the hero; machines cannot target it until then (Tesla jumps may land on it); clashes normally; once revealed it stays revealed | dither-fade shader (alpha scissor, no overdraw) + "?" counter, same grammar as plan2 hidden gates | Tesla ✓, Drone, Prism (Lens of Ruin), the hero |
| `armored` | W4 Volcano | light hits ×0.5 (§2.1); Burn 0.5 units/s | heavy plate raider (Meshy A-71) | Siege Ram ✓, Frost Miner ✓, Railgun, Ballista, Mortar; Stagger removes the penalty |
| `shielded` | W5 Ice | a shield pool = 30% of the squad's count absorbs non-beam, non-arc damage first; the counter shows "40 + 12⛉" | hex shell shader over the squad | Arc Fence ✓, Laser, Railgun, Tesla |
| `chill_resist` | W5 Ice | Freeze needs 5 Chill stacks; −5% per stack | frost-rim overlay | non-Frost damage (any) |
| `flying` | W6 Sky | hovers 1.2 u; `ground_only` machines cannot hit it; dives to clash normally at contact | glider raider (Meshy A-72) | Gravity Well ✓ (grounds it 2 s), Sentinel ✓, Rockets, Drone, Tesla, Laser |
| `rift` | W7 Rift | two properties from the list above | both overlays | Mythics, Fusions |

### 2.5 Machine sheets

Numbers are at Rank I and Lv1 unless stated; `acc_mult` scales damage (Lv15 ×2.12). Distances in world units (bridge
half width 3.5, run speed 6.5 u/s). "Meshy" refers to the final copy-paste prompt id in Appendix A. "Parts" lists the
pieces that move and how they are made (`M` = separate Meshy model, `P` = procedural in Godot, `V` = VFX/shader only)
with pivot and axis in the module's local space (machines face −Z, the run direction).

---

**1. DRONE — Дрон** · `drone` · Common · Tech · PAINT · spotter · owned at start · silhouette: X-quad with an eye
- Run: hovers 1.2 u above the army, flies to the painted target; **0.6 dmg × 2 shots/s, range 8, applies Mark, hits
  Flying**; its first hit on a Phantom squad reveals it.
- Verb: the player paints for the whole arsenal — every hero hit decides what gets Marked next.
- Ranks: II 2 drones. III Mark +10% (bucket 3 → 1.35) and drones re-paint the next target when theirs dies.
- Primary: damage and Mark duration +8%/Lv.
- Talent III: "Overwatch" drones also Mark turrets and barricades / "Sting" ×2.5 damage, no Mark.
- Ascension (Lv8): **Wasp Drone** — tri-rotor silhouette via shader + stinger tracer VFX; shots pierce 1.
- Apex: **Drone Storm** — 6 temporary drones for 5 s, all Marking.
- Recipe: E7 COMMAND LINK (with Sentinel); E9 partner for Harvester.
- Parts: rotors ×4 `P` (pivot rotor hub, axis +Y, 40 rad/s). Meshy: A-08.

**2. BALLISTA — Балиста** · `ballista` · Common · Kinetic · LANE · pierce line · W1 L2 · silhouette: wide bow arms
- Run: bolt down the hero's lane at the first hostile; **3 dmg, 0.9 shots/s, range 16, pierce 2** (hits 3 in a line).
- Verb: line up queued squads and the fortress gate in the hero's lane.
- Ranks: II pierce 3, +20% damage. III twin bolts.
- Primary: damage +8%/Lv.
- Talent III: "Barbed Bolts" Stagger push ×2 / "Ricochet" after the last pierce the bolt bounces once.
- Ascension: **Storm Ballista** — bolts trail an orchid arc and apply Jolt (shader tier + VFX).
- Apex: **Volley of Kings** — 3 s fan of 12 bolts sweeping the bridge, pierce 6.
- Recipe: E1 BOLT STORM (+1 shot catalyst).
- Parts: bow arms flex `P` (vertex bend in shader on release, 0.12 s), bolt `P`. Meshy: A-09.

**3. PLASMA CANNON — Плазмова гармата** · `cannon` · Common · Plasma · PAINT · splash orb · W1 L3 · silhouette: fat round muzzle
- Run: orb at the painted target; **2 dmg to the target + up to 3 others within r1.2, 0.6 shots/s, range 12, Burn**.
- Verb: paint the densest squad.
- Ranks: II r1.5. III the orb splits into 3 on impact.
- Primary: damage +8%/Lv.
- Talent III: "Nova Core" r+0.4, −15% rate / "Sticky Plasma" impact leaves a 2 s Burn puddle.
- Ascension: **Sun Cannon** — orbs 30% bigger and leave a Burn ring.
- Apex: **Supernova** — one orb, 25 dmg r3.0, Burn 5 s.
- Recipe: F2 MAGMA MORTAR (+ Mortar), F5 SINGULARITY BOMB (+ Gravity Well).
- Parts: barrel recoil `P` (−Z 0.15 u). Meshy: A-10.

**4. ROCKET POD — Ракетниця** · `rockets` · Common · Tech · PAINT · homing burst · W1 L5 · silhouette: boxy 2×3 tube pod
- Run: every 2.5 s **4 rockets × 2 dmg, r0.8 each, range 18, vs structures 1.5, hits Flying**, homing on the painted target.
- Verb: paint the turret or barricade you want gone; rockets do the rest.
- Ranks: II 6 rockets. III cluster: each rocket drops 2 bomblets (1 dmg r0.6).
- Primary: damage +8%/Lv.
- Talent III: "Bunker Buster" 1 rocket per volley vs structures 3.0 / "Swarm Feed" +2 micro-rockets at 50%.
- Ascension: **Hunter Pod** — rockets apply Mark.
- Apex: **Doomsday Salvo** — 16 rockets over 2 s on the largest targets.
- Recipe: E3 DOOM BARRAGE (+damage catalyst); F4 WARHAWK (+ Gatling).
- Parts: none moving (tube flashes `V`). Meshy: A-11.

**5. SIEGE MORTAR — Облогова мортира** · `mortar` · Rare · Kinetic · PLACE · lobbed splash · W1 L6 · silhouette: stubby tube at 45°
- Run: every 2.2 s a shell lands at **(hero x, hero d + 12)** after a 0.8 s hollow ring telegraph: **4 dmg r1.6**;
  cannot hit Flying.
- Verb: steer so the ring sits on the squad or barricade 12 u ahead (Into the Breach).
- Ranks: II r2.0. III 3 bomblets around the impact (1.5 dmg r0.8).
- Primary: damage +8%/Lv.
- Talent III: "Earthbreaker" 0.5 s stun / "Carpet" 3 shells in a line along the lane.
- Ascension: **Titan Mortar** — shells leave a 1 s quake ring (Stagger).
- Apex: **Bombardment** — 10 shells walking up the hero's lane.
- Recipe: F2 MAGMA MORTAR (+ Cannon); partner for E4 (Siege Ram).
- Parts: tube `M` (pivot at the cradle axle, axis X, pitch 35°–60°). Meshy: A-12, part A-12p.

**6. GATLING — Гатлінг** · `gatling` · Common · Kinetic · PAINT · anti-Swarm shredder · W2 L1 · silhouette: 6-barrel drum
- Run: **0.6 dmg × 6 shots/s, range 10, +1 ricochet, Swarm vs 1.5**; spins up from 50% rate over 1.0 s; light; drawn as
  ONE tracer stream.
- Verb: paint the swarm; it shreds crowds the clash would lose to.
- Ranks: II +25% rate. III 2 ricochets.
- Primary: damage +8%/Lv.
- Talent III: "Shredder" hits strip a Shielded pool twice as fast / "Twin Vulcan" splits fire between 2 targets.
- Ascension: **Vulcan Drum** — no spin-up; gold tracers.
- Apex: **Lead Storm** — 3 s at 30 shots/s with 3 ricochets.
- Recipe: E2 VULCAN (+rate catalyst); F4 WARHAWK (+ Rockets).
- Parts: barrel drum `M` (pivot drum centre, axis Z, up to 30 rad/s). Meshy: A-13, part A-13p.

**7. LASER — Лазер** · `laser` · Rare · Plasma · LANE · ramping beam · W2 L3 · silhouette: long barrel with a lens dish
- Run: beam down the hero's lane at the first hostile; **6 DPS (3 split on a crowd), +50% per second on the same target
  up to ×2.5, range 10**, beam (ignores Shielded), proc 0.2 per tick.
- Verb: hold the lane on the fortress or a big squad to ramp.
- Ranks: II ramp cap ×3. III pierces to a 2nd target.
- Primary: damage +8%/Lv.
- Talent III: "Cutter" beam sweeps across a squad row / "Focus" ramp cap ×4, single target.
- Ascension: **Spectral Lance** — colour-cycling beam that Burns.
- Apex: **Solar Line** — 2 s bridge-long beam, 40 DPS.
- Recipe: E6 SPECTRUM (+ Prism); F3 SUNBREAKER (+ Railgun).
- Parts: lens dish `M` (pivot dish centre, axis Z, 2 rad/s idle, 12 rad/s firing). Meshy: A-14, part A-14p.

**8. RAILGUN — Рейкова гармата** · `railgun` · Epic · Volt · LANE · charged pierce · W2 L5 · silhouette: two long parallel rails
- Run: **18 dmg, 3.0 s charge with a 0.4 s glow telegraph, infinite pierce down the hero's lane, range 22, structures
  vs 2.0, Jolt on every target hit**, ignores Shielded.
- Verb: line the lane up before the glow: one shot through the whole queue and the fortress.
- Ranks: II charge 2.4 s. III the lane strip Jolts squads that cross it for 2 s.
- Primary: damage +8%/Lv.
- Talent III: "Overcap" charge +25% for ×1.6 damage / "Rapid Rails" charge −30%, damage −20%.
- Ascension A **Breacher** (vs fortress and boss 3.0). B **Splitter** (forks into 3 at the first hit).
- Apex: **Rail Barrage** — three back-to-back shots across the whole bridge.
- Recipe: E10 STAR LANCE (+ Arc Fence); F3 SUNBREAKER (+ Laser).
- Parts: none moving; rail glow `V`. Meshy: A-15, branches A-40/A-41.

**9. TESLA COIL — Котушка Тесли** · `tesla` · Rare · Volt · PAINT · chain · W3 L1 · silhouette: cage sphere on a coil tower
- Run: arc from the painted target: **2 dmg, 0.8 shots/s, range 9, 3 jumps at −25% per jump within 2.5 u**, proc 0.5,
  hits Flying, jumps may land on unrevealed Phantoms (and reveal them).
- Verb: paint the edge of a cluster; the chain does the rest.
- Ranks: II 5 jumps. III every jump applies Jolt.
- Primary: damage +8%/Lv.
- Talent III: "Forked Arcs" forks at every jump / "Static Field" 3 u aura, 1 dmg per 0.5 s.
- Ascension: **Thunder Spire** — every arc leaves Jolt; triple insulator crown via shader.
- Apex: **Skybreaker** — chains to every hostile within 10 u, 3 pulses.
- Recipe: E5 STORM SPIRE (+ Arc Fence); F1 BLIZZARD COIL (+ Cryo).
- Parts: none moving; arcs `V`. Meshy: A-16.

**10. WAR BANNER — Бойовий штандарт** · `banner` · Rare · Rune · RULE · army buff · W3 L3 · silhouette: tall pole, flag, finial
- Run: no attack. **Army volleys +30% (bucket 2), clash losses −15%.** It is Rune's only clash-loss reducer.
- Verb: fight squads you would otherwise avoid, and take ARM gates over +N gates.
- Ranks: II +45% / −20%. III Rally: +5 soldiers every 10 s.
- Primary: volleys +1.5 pp and clash −0.5 pp per Lv (Lv15: +51% / −22%).
- Talent III: "Warlord" army tier counts +1 for volleys / "Pilgrim" recruits join ×2.
- Ascension: **Royal Standard** — banner of light (shader); also +10% hero damage (bucket 2).
- Apex: **Last Stand** — 4 s: clash losses −80%.
- Recipe: F6 IRON VANGUARD (+ Sentinel).
- Parts: flag `P` (quad with painted texture, vertex wave in shader, amplitude by speed). Meshy: A-17.

**11. PRISM — Призма** · `prism` · Legendary · Plasma · LANE · amplifier · W3 L5 · silhouette: diamond in a gyro ring
- Run: hovers 3 u ahead of the hero inside its corridor and follows its x. **Every friendly projectile that crosses it
  gains +20% damage (bucket 2) and +1 pierce; a beam that crosses it splits into 3 at 60%.** Hero shots always cross it;
  LANE machines' shots do; PAINT shots do when the target is in the hero's lane. Alone: a 1-dmg ray per second.
- Verb: keep targets in the hero's lane so everything passes through the prism.
- Ranks: II +30%. III bolts and orbs split in 2 after crossing.
- Primary: amp +1 pp per Lv.
- Talent III: "Focusing Lens" amp +10 pp / "Wide Facet" prism 40% larger (catches PAINT shots from 1 u further).
- Ascension A **Lens of Ruin** (reveals Phantoms within 8 u). B **Rainbow Prism** (split shots apply Burn, Chill, Jolt in turn).
- Apex: **Refraction Storm** — 4 s: every friendly shot splits in 3.
- Recipe: partner for E6 SPECTRUM (Laser).
- Parts: gyro ring `M` (pivot prism centre, axis X then Y, 1.5 rad/s), prism body `M`. Meshy: A-18, part A-18p, branches A-42/A-43.

**12. CRYO SPRAYER — Кріо-гармата** · `cryo` · Common · Frost · LANE · cone control · W4 L1 · silhouette: tank with a flared nozzle
- Run: **60° cone, 6 u long, along the hero's lane; 1.5 DPS + 1 Chill stack per 0.5 s**; frozen squads deal 0 clash
  damage. Frost's only clash-loss reducer.
- Verb: freeze the squad you are about to clash with; steer the cone onto it 1–2 s early.
- Ranks: II 80° cone. III Shatter: frozen squads take vs 1.5 from Kinetic.
- Primary: damage +8%/Lv and cone length +1%/Lv.
- Talent III: "Glacier" an ice wall holds a squad 2 s / "Cryo Burst" frozen squads lose 2 units on thaw.
- Ascension: **Avalanche Sprayer** — cone +30% length; frost crust shader on the tank.
- Apex: **Flash Freeze** — everything within 8 u frozen 2 s.
- Recipe: E8 ABSOLUTE ZERO (+ Frost Miner); F1 BLIZZARD COIL (+ Tesla).
- Parts: none moving; cone mist `V`. Meshy: A-19.

**13. FROST MINER — Крижаний мінер** · `frost_miner` · Rare · Frost · PLACE · mines · W4 L3 · silhouette: drum magazine
- Run: every 2.5 s a mine lands at **(hero x, hero d + 8)** (hollow ring telegraph): **4 dmg r1.5 + Freeze 1.5 s**
  (not light). A mine on a rotor or sweeper FREEZES THE BLADE 1.5 s; on a lava jet it quenches it for 2 s. Ground only.
- Verb: drop mines on the blade or jet you need to pass, not only on squads.
- Ranks: II 2 mines side by side (±0.8 u). III each mine leaves a 3 s ice patch (−50% squad speed).
- Primary: damage +8%/Lv, freeze +2%/Lv.
- Talent III: "Cryo Field" patch 5 s / "Chain Mines" a mine triggers others within 3 u.
- Ascension: **Permafrost Miner** — mines also freeze turrets 2 s.
- Apex: **Minefield** — 8 mines carpet the next 20 u of the lane.
- Recipe: partner for E8 (Cryo).
- Parts: drum `M` (pivot drum axle, axis X, 6 rad/s on throw). Meshy: A-20, part A-20p.

**14. SIEGE RAM — Облоговий таран** · `ram` · Epic · Kinetic · LANE · anti-structure dash · W4 L5 · silhouette: wedge with a spike head
- Run: every 4 s rolls out **at 14 u/s to 6 u ahead of the hero along its x and back at 10 u/s**: **24 dmg to
  barricades, turrets, in-run geodes, fortress (structures vs 2.0 → 48); 3 dmg + 1 u knockback to squads**. Ground only.
- Verb: point the hero at the barricade you will not have time to shoot.
- Ranks: II cooldown 3 s. III instantly breaks a barricade with ≤ 30 HP.
- Primary: damage +8%/Lv.
- Talent III: "Momentum" does not stop at the first target / "Pinning Spike" 10 DPS while pinned on the fortress.
- Ascension A **Juggernaut** (leaves a 2 s spike strip, 2 dmg/s). B **Drill Ram** (fortress: 10% HP per hit, cooldown 6 s).
- Apex: **Battering Charge** — 3 dashes in 2 s.
- Recipe: E4 IRONCLAD JUGGERNAUT (+ Mortar).
- Parts: wheels `P` (from the Kinetic chassis). Meshy: A-21, branches A-44/A-45.

**15. HARVESTER — Збирач** · `harvester` · Rare · Rune · RULE · economy · W5 L1 · silhouette: claw arm + funnel
- Run: 0.5 DPS. **Pickups (tiles, coins, recruits) within 1.5 u of the army edge fly in; each machine kill: 20% flat
  chance of +1 coin; in-run geodes take ×2 damage.** Coins from Harvester (and Seal) are capped at 25% of the level's
  victory coins. (This replaces v1's wider radius on its own: the radius applies only to pickups the army brushed past
  within 1.5 u, so routing still matters.)
- Verb: route along the edge of pickup lines instead of through them.
- Ranks: II 2.5 u, 30%. III +1 soldier per 15 machine kills.
- Primary: coin chance +1 pp/Lv, reach +0.05 u/Lv.
- Talent III: "Golden Maw" +1 stair step at the finale (max once) / "Recruiter" recruits ×1.5.
- Ascension: **Golden Funnel** — 30% coin chance; gold funnel shader.
- Apex: **Gold Rush** — 4 s: every kill drops a coin (cap still applies).
- Recipe: E9 GOLDEN MAW (+ Drone); F8 MIDAS ENGINE (+ Gate Tuner).
- Parts: funnel `P` spin (axis Y, 3 rad/s). Meshy: A-22.

**16. ARC FENCE — Дуговий паркан** · `arc_fence` · Epic · Volt · PLACE · stun wall · W5 L3 · silhouette: twin spiked pylons
- Run: two pylons travel with the army **3 u ahead of the hero, centred on its x, wall width 3.0**; **pulses every 3 s:
  1 dmg + 0.6 s stun** to everything in it; stunned squads deal no clash damage; deletes enemy turret shots that cross
  it; arc (ignores Shielded). Volt's only clash-loss reducer.
- Verb: sweep the wall across the squad you are about to hit, timing the pulse.
- Ranks: II every 2.4 s, width +30%. III stun 1.0 s.
- Primary: damage +8%/Lv, stun +0.02 s/Lv.
- Talent III: "Static Snare" stunned squads take +25% (bucket 2) / "Conductor" each pulse applies Jolt.
- Ascension A **Tesla Gate** (the wall stays 2 s where it pulsed, like a gate). B **Storm Net** (slows squads 40% while touching).
- Apex: **Thunder Cage** — 3 s continuous wall.
- Recipe: partner for E5 (Tesla) and E10 (Railgun); F7 STORM BULWARK (+ Aegis).
- Parts: none moving; arc `V`. Meshy: A-23, branches A-46/A-47.

**17. AEGIS — Егіда** · `aegis` · Epic · Frost · RULE · hazard absorb · W5 L5 · silhouette: low emitter with 3 tall fins
- Run: a hex dome (shader) over the army front. **Absorbs one spike or blade contact every 5 s (saves up to 10
  soldiers); blocks turret shots at n = 4.4 (40%).** Ring on the machine shows when the absorb is ready.
- Verb: cut a corner through a hazard when the ring is full.
- Ranks: II every 4 s, cap 15. III shield bash: 6 dmg to the absorbed hazard.
- Primary: +1 soldier saved per 2 Lv; block n +0.1/Lv.
- Talent III: "Quick Ward" absorb every 4 s / "Reflector" blocked turret shots return for 3 dmg.
- Ascension A **Bastion Dome** (absorbs 2; dome covers the whole blob). B **Mirror Dome** (reflects 100% of blocked shots; absorbs 1).
- Apex: **Sanctum** — 3 s: the army ignores hazards.
- Recipe: F7 STORM BULWARK (+ Arc Fence).
- Parts: none moving; dome `V`. Meshy: A-24, branches A-48/A-49.

**18. SENTINEL — Вартовий мех** · `sentinel` · Epic · Tech · PLACE · tank walker · W6 L1 · silhouette: chicken-walker (no chassis)
- Run: walks at **RUN_SPEED + 1 to a point 4 u ahead of the hero at its x**; engages any squad in its path: the squad
  stops advancing, Sentinel **soaks 15 units, hits 2 dmg / 0.8 s, hits Flying** (twin arm cannons). Its engagement does
  NOT set CLASH; the army clashes only on blob contact. Redeploys 8 s after breaking. Tech's only clash-loss reducer.
- Verb: walk the Sentinel into the squad you want pinned while the army goes round.
- Ranks: II soak 25. III 2 walkers (±1.2 u).
- Primary: +1 soak per Lv.
- Talent III: "Heavy Plating" soak +60% / "Last Gift" +5 soldiers when it breaks.
- Ascension A **Colossus** (stomp r1.5 every 2 s). B **Guardian** (enemy turrets target the Sentinel instead of soldiers).
- Apex: **Titan Protocol** — 6 s giant form, crushes squads ≤ 20.
- Recipe: partner for E7 (Drone); F6 IRON VANGUARD (+ Banner).
- Parts: legs — auto-rig through the hero rig pipeline (task #8 tooling) and procedural walk cycle; `M` whole body.
  Meshy: A-25, branches A-50/A-51.

**19. GRAVITY WELL — Гравітаційний вир** · `gravity` · Legendary · Rune · PAINT · clump · W6 L3 · silhouette: rings around a black orb
- Run: every 4 s a singularity on the painted squad (else the largest within 14 u): **pulled into a clump (radius
  −50%), slowed 50% for 1.5 s, Flying grounded 2 s; clumped squads take vs 1.5 from splash and chain.**
- Verb: paint the squad to clump, then hit it with splash.
- Ranks: II every 3 s. III implodes for 6 dmg.
- Primary: slow +1 pp/Lv, pull radius +2%/Lv.
- Talent III: "Long Pull" radius +50% / "Dense Core" slow 70%.
- Ascension A **Event Horizon** (swallows turret shots; clump 2.5 s). B **Black Star** (implosion 15 dmg + Seal).
- Apex: **Collapse** — 3 s: every squad on screen pulled into one point, then implodes for 20.
- Recipe: F5 SINGULARITY BOMB (+ Cannon).
- Parts: 3 rings `P` (torus meshes, axes X/Y/Z, 1.2/1.6/2.0 rad/s), core `M`. Meshy: A-26, part A-26p, branches A-52/A-53.

**20. GATE TUNER — Камертон** · `tuner` · Legendary · Volt · RULE · gate economy · W6 L5 · silhouette: dish + fork antenna
- Run: a thin orchid beam (VFX) only at the gate in the hero's corridor in the next row (and charge gates): **+3 to the
  gate value per hit, 1.5 hits/s, range 14, 0 damage**; −N gates move toward 0, then positive.
- Verb: steer toward the gate you want charged one row early.
- Ranks: II +4 per hit. III ×-gates gain +0.1 per hit (cap +0.5).
- Primary: +0.15 per hit per Lv (Lv15 +5.1).
- Talent III: "Fast Cycle" +30% hit rate / "Long Dish" range +5.
- Ascension A **Flipper Array** (also holds blinking gates in their good state 2 s). B **Prospector Dish** (in-run geodes ×2 reward).
- Apex: **Full Spectrum** — the next gate row: every gate +50%.
- Recipe: partner for E12 (Echo); F8 MIDAS ENGINE (+ Harvester).
- Parts: dish `M` (pivot dish mount, yaw Y and pitch X). Meshy: A-27, part A-27p, branches A-54/A-55.

**21. STARFALL ARRAY — Зорепад** · `starfall` · Mythic · Rift · PLACE · orbital strike · Rift Anvil · silhouette: tall antenna spire
- Run: every 7 s marks **(hero x, hero d + RUN_SPEED × 1.2 + 2)**; the hollow ring follows the hero's x until 0.4 s
  before impact, then locks; impact 1.2 s after the mark: **30 dmg r2.0, structures vs 2.0; a charge gate inside is fully
  flipped**. Ground only.
- Verb: steer the ring onto the target 9.8 u ahead, then commit for the last 0.4 s.
- Ranks: II every 5.5 s. III double strike (second ring 0.5 s later at the new hero x).
- Primary: damage +8%/Lv.
- Talent III: "Meteor Shower" 3 small strikes r1.0 / "Sun Pillar" beam lingers 1 s.
- Ascension A **Meteor Choir** (3 meteors). B **Solar Spear** (one strike every 9 s, 80 dmg).
- Apex: **Starfall** — 8 strikes along the lane ahead.
- Recipe: E11 SUPERNOVA ARRAY (+damage catalyst).
- Parts: ring `P` (torus, axis Y). Meshy: A-28, branches A-56/A-57.

**22. CHRONO BELL — Хронодзвін** · `chrono` · Mythic · Rift · RULE · time slow · Rift Anvil · silhouette: bell in a clockwork arch
- Run: rings **when the army passes a gate row** (cooldown 10 s): **hostiles within 9 u ahead at 30% speed for 2.5 s;
  moving and blinking gates of the NEXT row freeze in their current state; turret shots slowed; your machines +30% fire
  rate during the toll.** The slow-mo always frames the next row.
- Verb: pick the row whose blinking ×3 you want frozen and pass the row before it at the right moment.
- Ranks: II 3.0 s. III rotors and sweepers within 9 u freeze too.
- Primary: duration +0.05 s/Lv.
- Talent III: "Long Toll" radius 12 / "Quick Toll" cooldown 7 s.
- Ascension A **Stasis Bell** (2 s full stop instead of slow). B **Haste Bell** (army and machines +50% rate during the toll).
- Apex: **Stopped Clock** — 3 s: everything except your army stops.
- Parts: bell `M` (pivot at the bell's top, axis X, swing ±20°), cogs `P`. Meshy: A-29, part A-29p, branches A-58/A-59.

**23. PHOENIX PYRE — Багаття фенікса** · `phoenix` · Mythic · Rift · RULE · rebirth · Rift Anvil · silhouette: brazier with wings
- Run: **25% of soldiers lost (any cause) rise as flame soldiers 1.5 s later at the army rear (cap 30 per level)**;
  flame soldiers count 1 and Burn on clash.
- Verb: take the riskier line through a hazard for the bigger reward.
- Ranks: II 35% (cap 45). III reborn soldiers count 1.5 in clashes.
- Primary: rebirth +0.7 pp/Lv.
- Talent III: "Pyre" rebirth also refunds 1% ult / "Ember Guard" reborn soldiers ignore the next hazard.
- Ascension A **Sunpyre** (cap 60). B **Ashen Host** (reborn soldiers burst for 2 dmg when they die again).
- Apex: **Rebirth** — revive 50% of everyone lost this level (cap 40).
- Parts: flames `V`. Meshy: A-30, branches A-60/A-61.

**24. ECHO REACTOR — Ехо-реактор** · `echo` · Mythic · Rift · RULE · gate echo · Rift Anvil · silhouette: twin rings around a core
- Run: after you pass a positive gate, an **echo gate replaying 50% of its effect** (+N → +N/2; ×N → ×(1 + (N−1)/2))
  spawns at the same x in the first free **echo pocket** within the next 12 u: LevelGen marks pockets (gaps ≥ 6 u from
  any item) in its item list (`echo_pockets: [d]`). No pocket → the charge is refunded. Recharge 14 s. Echo gates show
  the forecast like normal gates.
- Verb: plan two gates ahead: take the gate whose echo you want.
- Ranks: II 65%. III 80% and echoes power gates.
- Primary: echo +1 pp/Lv.
- Talent III: "Resonant Echo" recharge 10 s / "Twin Echo" two echoes at 35%.
- Ascension A **Perfect Echo** (100% once per level). B **Harmonic Echo** (+5 soldiers per echo).
- Apex: **Reverb** — the next 3 positive gates echo at 100%.
- Recipe: E12 RESONANCE (+ Gate Tuner).
- Parts: 2 rings `P` (torus, axes X and Z). Meshy: A-31, branches A-62/A-63.

**Mythic acquisition** (Rift Anvil, Arsenal sub-tab): every world boss and every Invasion boss drops 1 Boss Core (14 in a
full pass); 3 cores forge the Mythic of your choice; after all four are forged, each further core = 1 blueprint for your
lowest Mythic. Mythic blueprints otherwise come only from World and Royal Caches (0.1% per card), the Expedition 5/5
reward and run drip. Never sold. **Interim source until plan2 world bosses exist (Meta-3 dependency):** the fortress of
every 8th level counts as the boss and drops the core.

**SIM abstraction** (`ArsenalData.MACHINES[id].sim`, used by `LevelSim` for the EXPECTED profile instead of 24 behaviours;
numbers at Rank I Lv1, scaled by `acc_mult × rank_mult`):

| id | dps | aoe_r | control_s (per 10 s) | structure_mult | gate_gain/s | other |
|---|---|---|---|---|---|---|
| drone | 1.2 | 0 | 0 | 1.0 | 0 | mark 0.6 uptime |
| ballista | 2.7 | 0 (3 targets) | 0.3 | 1.0 | 0 | |
| cannon | 1.2 | 1.2 | 0 | 1.0 | 0 | burn 0.6 units/s |
| rockets | 3.2 | 0.8 | 0 | 1.5 | 0 | flying |
| mortar | 1.8 | 1.6 | 0 | 1.0 | 0 | ground only |
| gatling | 3.6 | 0 (+1 ricochet) | 0 | 1.0 | 0 | swarm 1.5, light |
| laser | 9.0 | 0 | 0 | 1.0 | 0 | beam |
| railgun | 6.0 | 0 (all in lane) | 0 | 2.0 | 0 | beam |
| tesla | 4.4 | 2.5 (chain) | 0 | 1.0 | 0 | |
| banner | 0 | 0 | 0 | 1.0 | 0 | volley ×1.30, clash ×0.85 |
| prism | 1.0 | 0 | 0 | 1.0 | 0 | amp +20% on lane fire |
| cryo | 1.5 | 1.0 | 2.0 | 1.0 | 0 | freeze |
| frost_miner | 1.6 | 1.5 | 6.0 | 1.0 | 0 | blade freeze 0.4/s |
| ram | 0.75 | 0 | 0 | 8.0 (24/4 s → structures only) | 0 | ground only |
| harvester | 0.5 | 0 | 0 | 1.0 | 0 | pickups +1.5 u edge |
| arc_fence | 0.33 | 1.5 | 2.0 | 1.0 | 0 | stun |
| aegis | 0 | 0 | 0 | 1.0 | 0 | saves 2 soldiers/s of hazard |
| sentinel | 2.5 | 0 | 3.0 | 1.0 | 0 | soak 15 |
| gravity | 0 | 2.0 | 3.75 | 1.0 | 0 | clump vs 1.5 |
| tuner | 0 | 0 | 0 | 1.0 | 4.5 | |
| starfall | 4.3 | 2.0 | 0 | 2.0 | 0 | flips charge gates |
| chrono | 0 | 9.0 | 2.1 | 1.0 | 0 | freezes next row |
| phoenix | 0 | 0 | 0 | 1.0 | 0 | rebirth 25% |
| echo | 0 | 0 | 0 | 1.0 | 0 | gate echo 50% per 14 s |

### 2.6 In-run Evolutions and Fusions (`EVOLUTIONS`, `FUSIONS`)

**One meaning of "Evolution"**: the gold EVOLVE gate. When a recipe is met, the next gate row at least 12 u ahead
replaces its weakest positive gate with a gold EVOLVE (or FUSE) gate showing the two icons merging and the result's
name; the player may decline it by taking another gate; it reappears in the next two rows, then waits for the next row
after a new crate. Plan2's hero-card evolutions use the same gate when the Shrine system ships (§3.6).

**Only two catalyst kinds** (both shown in the trait strip and on forecasts): (a) a partner machine is fielded;
(b) a specific power gate (`rate`, `dmg`, `multi`) was taken this run. Hero identity is never a catalyst (v1's Titan
and Bolt recipes became Aspect perks, §4.1). Cap: at most 2 evolved/fused machines at once (`MAX_EVOLVED := 2`).

Rules: an evolved machine keeps its Lv, talents, branch and finish, `evo_mult` 1.25 on bucket 1 plus the listed
changes. A fused machine: Lv = max(parent Lv); Rank fixed at III; talents of both parents active; Apex, branch and
finish of parent A (the first listed); later crates of either parent give overflow; it frees one slot.
Visuals: an Evolution = parent model × 1.2 scale + finish shader "aura" tier + its own projectile VFX (no new mesh).
A Fusion = the double-wide war cart chassis (Meshy A-70) carrying both parent modules, with merged VFX.
First discovery: 0.12 s hit-stop + discovery card (result flow step 5b) + Codex entry.

| id | Recipe (Rank III + catalyst) | Result (stats at Lv1; ×acc_mult) |
|---|---|---|
| E1 | Ballista + `multi` gate | BOLT STORM: 5-bolt fan, 3.5 dmg each, 1.0/s, pierce 4, range 16 |
| E2 | Gatling + `rate` gate | VULCAN: 0.7 × 10/s, 2 ricochets, no spin-up, Swarm vs 1.5 |
| E3 | Rocket Pod + `dmg` gate | DOOM BARRAGE: 12 rockets × 2.5 every 3 s; the 12th takes 5% of fortress HP |
| E4 | Siege Ram + Mortar fielded | IRONCLAD JUGGERNAUT: dash every 3 s, 40 dmg structures, leaves a 2 s spike strip (2 dmg/s) |
| E5 | Tesla + Arc Fence fielded | STORM SPIRE: 3 dmg to every hostile within 6 u every 1.2 s, applies Jolt |
| E6 | Laser + Prism fielded | SPECTRUM: 3 ramping beams, 5 DPS each, ramp cap ×2.5 |
| E7 | Drone + Sentinel fielded | COMMAND LINK: 3 drones; painted targets are Marked at 1.35; drones auto-paint for PAINT machines |
| E8 | Cryo + Frost Miner fielded | ABSOLUTE ZERO: every 6 s a freeze wave 10 u ahead across the bridge, 2 dmg + Freeze 1.5 s |
| E9 | Harvester + Drone fielded | GOLDEN MAW: pickup reach 3 u, 35% coin per kill (cap applies), +1 stair step |
| E10 | Railgun + Arc Fence fielded | STAR LANCE: 1.5 s charge, 22 dmg, the lane strip Jolts 3 s |
| E11 | Starfall + `dmg` gate | SUPERNOVA ARRAY: 36 dmg, craters Burn 3 s |
| E12 | Echo + Gate Tuner fielded | RESONANCE: ×-gate echoes at 100% |

| id | Fusion (both Rank II+) | Result (stats at Lv1) |
|---|---|---|
| F1 | Tesla + Cryo | BLIZZARD COIL: 2.5 dmg, 1.0/s, 5 jumps, every jump +1 Chill; Superconduct always on |
| F2 | Plasma Cannon + Mortar | MAGMA MORTAR: PLACE +12 u, 5 dmg r1.6 every 2 s, Burn pool r1.5 for 3 s |
| F3 | Laser + Railgun | SUNBREAKER: 2 s charge, a 1.5 s beam sweeping the row, 25 DPS, infinite pierce |
| F4 | Gatling + Rocket Pod | WARHAWK: 0.6 × 8/s + every 2 s 3 homing micro-rockets × 1.5; hits Flying |
| F5 | Gravity Well + Plasma Cannon | SINGULARITY BOMB: every 3.5 s pull, then 8 dmg r2 + Burn |
| F6 | War Banner + Sentinel | IRON VANGUARD: walker carries the banner; the squad it holds takes vs 1.5 from the army; army clash losses −25% |
| F7 | Arc Fence + Aegis | STORM BULWARK: absorb every 4 s; every absorb pulses a 1.0 s stun r3 |
| F8 | Gate Tuner + Harvester | MIDAS ENGINE: +4 per gate hit and +1 coin per gate hit (cap applies); ×-gates +0.15 per hit (cap +0.6) |

**Codex** (Diablo IV aspects, Gungeon synergies): 20 entries; undiscovered ones show a silhouette and the family pair
("Volt + Frost …"); discovering all 20 = Feat F-43 + a Royal Cache.

### 2.7 Army gear — the soldier weapon track (separate from machines)

In a run, ARM gates raise the army tier by one (etap1 `arm_tier`). The account decides how high a run can go: tiers
T3–T5 unlock by **world reached** (not Crowns), so skill unlocks beauty and passives, never army power.

| Tier | id | uk | Unlock | In-run effect (base) |
|---|---|---|---|---|
| T0 | `spear` | Списи | start | melee only (1:1 clash) |
| T1 | `crossbow` | Арбалети | start | volley 0.05 × army dmg every 0.5 s, range 7, vs squads |
| T2 | `blaster` | Кришталеві бластери | start (etap1) | volley 0.09 every 0.45 s, range 8, also structures |
| T3 | `arc_lance` | Дугові списи | reach World 3 | volley 0.10, every 3rd volley chains 1 |
| T4 | `prism_rifle` | Призмові гвинтівки | reach World 5 | volley 0.12, pierce 1, structures vs 1.5 |
| T5 | `starforged` | Зорекуті | reach World 7 | volley 0.14, the first clash loss every 3 s is ignored |

**ARM gate at the account's max tier** shows and gives its real effect instead: "+20% залпи" (volley damage +20% for the
rest of the run, bucket 2, stacks twice) — the forecast label shows that text, never a dead "+1 tier". Barracks
"Volleys" track scales every tier (§4.2). Soldier skins per tier are cosmetic (Haven, Road).

### 2.8 Readability, VFX, audio and animation rules (WS3 owns `effects.gd`, WS5 owns stingers)

**Visual priority ladder** (draw order, saturation and size budget, top wins): 1 threat telegraphs (enemy, filled red) →
2 gate numbers and forecasts → 3 hero shots → 4 army counter → 5 machine shots → 6 status overlays → 7 environment.
**Budgets**: ≤ 60 live projectiles (machines get ≤ 36 of them, hero 16, army volleys 8 streak batches); ≤ 4 friendly
ground telegraphs at once (oldest dims); ≤ 1 floating number per squad per 0.3 s; machine particles ≤ 600 total.

**Telegraph grammar** (friendly vs enemy never share a shape): friendly = hollow dashed ring in the family accent with
4 inward chevrons, 0.06 u line, no fill; enemy (plan2 meteors, lava jets, boss markers) = filled red disc with a solid
rim. Friendly lines (Railgun) = two dashed rails, enemy lines = solid red band.

**Per-machine VFX/SFX** (`MACHINES[id].vfx` / `.sfx`; `Effects.projectile` gains these kinds; Effects gallery
`scripts/dev/gallery_fx.gd` shows all 24 side by side, `--sheet` renders them on all 7 road palettes with CVD filters):

| id | vfx kind | width | length | lifetime s | particles_max | telegraph | sfx (fire / impact) |
|---|---|---|---|---|---|---|---|
| drone | tracer_dot | 0.08 | 0.8 | 0.15 | 6 | — | `drone_chirp` / `tick_hit` |
| ballista | bolt | 0.24 | 2.3 | 0.5 | 8 | — | `ballista_twang` / `wood_thunk` |
| cannon | orb | 0.55 | 1.5 | 0.6 | 24 | — | `plasma_whoomp` / `plasma_pop` |
| rockets | missile_trail | 0.24 | 1.2 | 0.9 | 40 | — | `rocket_hiss` / `rocket_boom` |
| mortar | shell_arc | 0.3 | — | 0.8 | 30 | ring r1.6 0.8 s | `mortar_thoomp` / `shell_boom` |
| gatling | tracer_stream | 0.1 | 3.0 | continuous | 12 | — | `gatling_loop` / `bullet_tick` |
| laser | beam | 0.18 | ≤10 | continuous | 20 | — | `laser_loop` / `sizzle` |
| railgun | rail_beam | 0.3 | 22 | 0.25 | 30 | 2 dashed rails 0.4 s | `rail_charge` + `rail_crack` / `pierce_ring` |
| tesla | chain_arc | 0.12 | jump | 0.18 | 16 | — | `tesla_zap` / `arc_snap` |
| banner | aura_ring | — | r 2.0 | continuous | 20 | — | `banner_flap` (rare) / — |
| prism | refract_flash | 0.4 | — | 0.2 | 12 | — | `prism_chime` / — |
| cryo | cone_mist | 60° | 6 | continuous | 60 | — | `cryo_hiss` / `freeze_crack` |
| frost_miner | mine_toss | 0.3 | — | 0.7 | 24 | ring r1.5 until landing | `mine_clack` / `ice_burst` |
| ram | dash_streak | 1.0 | 6 | 0.5 | 30 | — | `ram_rumble` / `ram_crash` |
| harvester | magnet_lines | 0.05 | 1.5 | 0.4 | 16 | — | `harvest_ping` / `coin_drop` |
| arc_fence | fence_wall | 3.0 | 0.2 | 0.35 pulse | 40 | — | `fence_hum` / `fence_pulse` |
| aegis | dome | r 1.6 | — | 0.5 flash | 24 | — | `dome_ward` / `dome_bash` |
| sentinel | twin_tracer | 0.1 | 1.0 | 0.2 | 10 | — | `mech_step` + `mech_shot` / `metal_hit` |
| gravity | singularity | r 1.8 | — | 1.5 | 50 | ring r1.8 0.3 s | `gravity_drone` / `implode` |
| tuner | gate_beam | 0.06 | ≤14 | continuous | 8 | — | `tuner_tone` / `gate_tick_up` |
| starfall | orbital_beam | 1.2 | sky | 0.6 | 80 | ring r2.0 1.2 s | `star_lock` + `orbital_boom` |
| chrono | toll_wave | r 9 | — | 0.8 | 40 | — | `bell_toll` / — |
| phoenix | flame_soldier | — | — | 1.5 rise | 30 | — | `pyre_whoosh` / `ember_burst` |
| echo | echo_gate | gate w | — | 0.6 spawn | 20 | gate outline 0.6 s | `echo_reverb` / — |

Status VFX: overlays via `CrowdView.set_overlay` (frost rim, ember flicker, crackle, reticle decal, rune ring) + one
counter icon per status. Reaction pops: world-space word in both status colours, 0.6 s. Apex VFX: one full-screen-edge
vignette in the family accent + the machine's Apex projectile, ≤ 2.5 s.

**Audio identity** (procedural via `tools/gen_sfx.py`, registered in `Audio.SFX_NAMES`): family palette — Kinetic wooden
thunk + metal twang; Volt bright zap crackle; Frost crystalline hiss + chime; Plasma low whoomp; Tech digital chirp +
servo; Rune stone chime + bell; Rift choir shimmer. Rank layers: Rank II adds a sub-bass layer (−12 dB), Rank III a
metallic tail. Ducking: hero shots 0 dB, machines −4 dB, army volleys −8 dB, statuses −10 dB; music ducks −3 dB on
Apex. Voice limits: 2 voices per machine kind, 10 machine voices total (steal the oldest), pitch ±6%.

**Rank model changes** (Squad Busters Super/Ultra): Rank II = 1.15× scale + procedural armour plates (or a second barrel
where the module has one); Rank III = 1.3× scale + gold crest + idle aura (shader) + heavier fire sound. A rank-up is a
0.5 s forge moment: sparks, clang, haptic CLICK 0.7, scale pop.

**Animation spec (every machine)**: idle (servo bob 1.6 s, crew breathing); fire (recoil −Z 0.12 s, return 0.25 s,
muzzle flash); rank-up (above); **docking** on acquisition: the crate bursts, the machine unfolds from the crate shell and
skids into its convoy slot ≤ 0.8 s with a clack and haptic "weapon"; Ascension transform (meta only, §7.3); **crew**: one
operator (crew Meshy asset A-69 on the soldier rig) per chassis machine with idle / load / cheer poses (procedural bones
like the heroes); free-model machines (Drone, Prism, Sentinel) have no crew.

---

## 3. IN-RUN ARSENAL — Deck, crates, RANK / CATALYST / EVOLVE gates, HUD

### 3.1 Deck, Lead, Auto-deck, threat preview

- **Deck slots**: 3 when the Deck opens (L10), +1 at World 3, World 4 and World 5 → **6 slots max** (Lead + 5). More slots
  would dilute crates (v1 sim: a fixed 3-deck beat the 8-slot design). Slots may stay **empty**; Auto-deck leaves them
  empty when the extra machine would lower the recipe or level odds. Later worlds reward a third **preset** (World 6).
- **Lead** (slot 1, crown icon): at Lv5+ the run starts with it fielded at Rank I.
- **Auto-deck** builds for the next level's threat preview: answers to shown properties first, then the best recipe pair
  among owned machines, then highest level. The deck editor shows family counts and possible recipes like a TFT bench
  ("Volt 2 · Frost 1 · рецепти: Blizzard Coil, Storm Spire").
- **Threat preview** (long-press a map node): property icons, boss portrait, the in-run budget for that level ("2 скрині
  · 1 ворота рангу") and the green check on deck cards that answer a property.
- Before L10 the deck is automatic (all owned machines, max 5).

### 3.2 The in-run arsenal budget (`ArsenalData.INRUN_BUDGET`, measured by `economy_sim.py` §3 and `test_meta.gd`)

| Level band | Crate events | RANK gates | Pairs | Catalyst gates | Measured P(Rank II+) | P(Rank III) | P(Evolution) | P(Fusion) | P(Evo or Fusion) |
|---|---|---|---|---|---|---|---|---|---|
| L1 | 0 | 0 | — | — | — | — | — | — | — |
| L2–10 | 2 (+1 on the boss) | 0 | from L5 | when a recipe needs one | 82% | 16% | 5% | 10% | 15% (a rare treat) |
| L11–30 | 2 (+1 on bosses) | 1 | yes | yes | 98% | 73% | 24% | 14% | 34% |
| L31–56, Invasion | 4 (+1 on bosses) | 1 | yes | yes | 100% | 99% | 41% | 21% | 56% |
| Expedition | 4 per level, carried over 5 levels | 1 | yes | yes | — | — | — | — | — |

Ship targets (sim invariants; `level_check` fails a band more than ±10 pp off once the bot measures the real game):
L2–10 Rank II ≥ 70%, Evo/Fusion 5–20%; L11–30 Rank III 60–85%, Evo/Fusion 30–45%; L31+ Rank III ≥ 70%, Evo/Fusion
50–65%, Fusion 10–25%. Model assumptions (printed in the sim): crate BONUS success casual 35% / regular 55% / hardcore 75%;
a pair is resolved in the player's favour 60/80/95% of the time; a RANK gate is taken 65% of the time (it competes with
an army gate); a catalyst gate is taken 90%; an EVOLVE/FUSE gate 85%; 70% of decks hold a recipe pair (Auto-deck shows them).

### 3.3 Crates (etap1 kind `crate`; LevelGen owns placement, `crate_picker.gd` owns contents)

- **Placement**: LevelGen emits crates with `weapon: "deck"` per §3.2, or a fixed id + `new: true` for the platinum NEW
  crate (always the level's first crate, so a slot is free). From L5 every crate event is a **pair**: two crates side by
  side 2.2 u apart, `pair: <id>`. A pair follows the gate-row rule: the first crate opened claims its reward, the other
  folds and dims (0.2 s), so the pair is a real choice by steering (Slay the Spire card reward, plan2 gate rows).
- **Resolution**: contents are resolved when the crate first comes within **30 u** of the hero (just before its label is
  readable) and then locked. A pair is resolved jointly with two distinct contents. Contents never change after that:
  a crate never shows a machine that would convert into something else.
- **Hero-only target**: machines ignore crates; the hero (and the ult) opens them. This keeps the crate a hero-aim
  decision and lets the BONUS reward the player, not the arsenal.
- **HP bar with two segments**: OPEN = the crate's `value` (LevelGen: ≈ 1.0 s of the current hero DPS at the level's
  expected stats) and **BONUS** = `CRATE_BONUS_HP := 0.6 × value`, drawn as a gold segment with a ring that fills on the
  crate. When OPEN empties, the crate opens on army contact or when BONUS empties, whichever is first. If BONUS empties
  first, the granted machine gets **+1 Rank** (capped at III; beyond III it becomes overflow). At most one bonus step per
  crate. The fill is normalised by hero DPS so Bolt (3.6 hits/s × 1) and Titan (1.1 hits/s × 4 + splash) both need about
  1.5 s for the BONUS; Tactics "Crate Craft" shortens it (§4.2). No colour climb: the ring fills, the crate glints gold
  when full.
- **Forecast label** above every crate, the same component as the gate forecast (`Models.gate_style` sub-label). The MACHINE is locked at 30 u; the label's EFFECT text
  is recomputed live whenever the fielded set changes before the crate is opened: "NEW · Рейкова гармата", "Тесла II", "→ II Кріо",
  "ВОЛЬТ 2/3", "+10% Балиста" (overflow), and pips for rarity (1–5). The machine miniature sits in the crate window.
- **NEW crate**: platinum shell with a "NEW" ribbon and a tall white beam (never gold: gold means power gates). Opening it
  fields the machine AND unlocks it permanently, even if the level is then lost. In-run reveal ≤ 0.8 s (docking, §2.8);
  the full walkout plays after the run (result step 5a).
- **Captain chest** (plan2 §3.4, when captains ship in World 2): a gold-trimmed crate dropped by the captain; opens into a
  1-of-3 Shrine card pick once the Shrine exists (§3.6); until then it is a Rank crate (+1 Rank to the weakest fielded
  machine, label "→ II ...").

**NEW crate schedule** (`ArsenalData.NEW_CRATES`):

| World | Level in world → machine |
|---|---|
| 1 Space | L2 Ballista (scripted, HINT_CRATE), L3 Plasma Cannon, L5 Rocket Pod, L6 Siege Mortar (Drone owned at start) |
| 2 Reef | L1 Gatling, L3 Laser, L5 Railgun |
| 3 Mystic | L1 Tesla Coil, L3 War Banner, L5 Prism |
| 4 Volcano | L1 Cryo Sprayer, L3 Frost Miner, L5 Siege Ram |
| 5 Ice | L1 Harvester, L3 Arc Fence, L5 Aegis |
| 6 Sky | L1 Sentinel, L3 Gravity Well, L5 Gate Tuner |
| 7 Rift | no NEW crates; 4 crates per level (+1 on the boss), Fusion-friendly layouts; Mythics via the Rift Anvil |

A Cache card for a machine not yet owned unlocks it early with a full walkout; its NEW crate later becomes a normal deck crate.

### 3.4 RANK, CATALYST and EVOLVE/FUSE gates (new gate ops; etap1 §4 schema)

| op | Fields | Resolved | Shows | Effect |
|---|---|---|---|---|
| `rank` | `fallback: {op: "+", value}` | at 30 u, like crates | machine icon + "II"/"III" | +1 Rank to that fielded machine (the one closest to a recipe, else the lowest rank); if nothing is fielded it becomes its fallback "+N" gate |
| `catalyst` | `fallback: {op: "rate"\|"dmg"\|"multi"}` | at 30 u | power-gate look + the recipe's two icons | resolves to the power op a fielded machine at Rank II+ needs for its recipe; else to its fallback power op |
| `evolve` / `fuse` | `recipe: "E5"` | spawned by Run (not LevelGen) into the next row ≥ 12 u ahead when a recipe is met | gold frame, two icons merging, result name | performs the Evolution/Fusion; replaces the weakest positive gate of that row; reappears in the next 2 rows if declined |

RANK gates sit in rows next to army gates: the decision is quality vs quantity (plan2 #7). Run validates that the row
still has at least one gate the forecast shows as positive for the army (LevelGen rule from etap1).

### 3.5 `crate_picker.gd` (pure, unit-tested; `test_meta.gd::test_inrun_budget` ports `economy_sim.inrun_level`)

```
func pick(deck: Array, fielded: Dictionary, rng) -> String:          # fielded: id -> rank 1..3
    var free := MAX_FIELDED - fielded.size()
    var news := deck.filter(func(m): return not fielded.has(m)) if free > 0 else []
    var dups := fielded.keys().filter(func(m): return fielded[m] < 3)
    var use_dup := news.is_empty() or (fielded.size() >= 2 and rng.randf() < DUP_SHARE_AT_2)   # 0.5
    if use_dup and not dups.is_empty():
        return weighted(dups, func(m): return RECIPE_WEIGHT if one_step_from_recipe(m, fielded) else 1.0)  # 3.0
    if not news.is_empty():
        return weighted(news, func(m): return RARITY_W[rarity(m)] * LEVEL_W(lvl(m)) * (2.0 if completes_pair(m, fielded) else 1.0))
    if not dups.is_empty(): return rng_choice(dups)
    return "overflow:" + best_fielded(fielded)                       # all Rank III: overflow crate
RARITY_W := {C: 1.0, R: 0.8, E: 0.6, L: 0.45, M: 0.35}
LEVEL_W(lv) := 0.75 + 0.05 × lv            # Lv1 0.8 … Lv15 1.5: your stronger machines show up more (sim: 80/20 top-3 blend)
```
Pairs call `pick` twice with the first result excluded. There is no hidden rarity offset: the picker is rule-based and
the only "luck" is the weighted draw above, fully shown by the forecast label before the player commits.

### 3.6 One in-run build system (how plan2's Shrine plugs in)

Plan2 §3.1's Shrine (1-of-3 cards) is not built yet; the Arsenal does not depend on it. When it ships it uses the same
grammar: its pool gains **machine cards** ("+1 Rank: Тесла", "Overflow +15%: Балиста", "Каталізатор: вважається, що ти
взяв ворота швидкості"), and hero-card evolutions use the gold EVOLVE gate (one visual, one word). Shrine stops are capped
at 2 per level once 2 or more machines are fielded, so a 30–60 s level never asks for more than ~6 build decisions.
Captain's Bounty and "signature Shrine card" (v1) are removed.

### 3.7 In-run HUD for the arsenal (WS4 owns `scripts/ui/hud_view.gd`)

- **Machine slots** move from the top-left row to a **bottom-left column of 3 × 88 px** above the safe area, mirroring
  the ult button (bottom-right). They are display-only (`mouse_filter = IGNORE`): icon, rank chevrons, Apex ring mirror,
  rarity frame. The army-arms chip sits above them.
- **Trait strip** (TFT): above the slots, one chip per family present with pips 1/2/3; lights up with a one-time toast at
  2 and 3 ("ВОЛЬТ 2: +1 стрибок"). Catalysts met show as a small gold link icon on the chip.
- **Apex chain**: no tap target (§2.1). The ult button shows small gold dots for each full Apex that will chain.
- **Status overlays** on squads (§2.8) + one counter icon per status. Reaction words in world space.
- **Forecast component** shared by gates, crates, RANK/CATALYST/EVOLVE gates (one script, `forecast_label.gd`, WS3).
- Old `WEAPON_NAMES` (5 kinds) and `_weapon_color()` in `hud_view.gd` are replaced by `ArsenalData.MACHINES[id].name` and
  the family accent.

### 3.8 Mastery Finishes (cosmetic, visible IN the run) and Arsenal Rating

Every fielded machine earns Mastery XP per run: 10, +5 if it reached Rank III, +5 if it evolved/fused. Thresholds
40 / 120 / 250 / 450 / 750 / 1200 XP. Each tier adds a layer you see during play (Rocket League boosts, CS kill effects):

| Tier | Finish | uk | What changes in the run |
|---|---|---|---|
| 1 | Polished Steel | Полірована сталь | clean material, crisp specular |
| 2 | Gold Trim | Золоте оздоблення | gold muzzle flash |
| 3 | Crystal Inlay | Кришталева інкрустація | crystal projectile trail |
| 4 | Energy Veins | Енергетичні жили | family-accent trail + animated veins |
| 5 | Halo | Ореол | unique kill effect |
| 6 | Infinity | Нескінченність | unique impact + a firing-sound layer; random alternate colourway "Flare" (Obsidian, Aurora, Ember, Frostglass, Rose Gold, Void) |

Finishes are shader tiers on the same mesh (`finish.gdshader` with the albedo-derived mask, §10.4). Equip any owned finish.

**Arsenal Rating** (internal; the UI shows only the Track bar): +1 per machine level, +5 per Ascension, +2 per Mastery
finish, +3 per Apex. **It gives no damage.** It only advances the Arsenal Track (§8.2). Shop, Road and Haven cosmetics add 0 rating (test:
`test_meta.gd::test_purchases_do_not_move_rating` — no SKU, gem item or Road reward changes rating, Track, pity or Caches).

---

## 4. UPGRADES — all permanent layers

| Layer | Tab | Paid with | Job | Opens (§4.6) |
|---|---|---|---|---|
| Machine levels Lv1–15 (talents, Lead, Ascension, Apex, Prestige) | Arsenal | Coins + Blueprints | main power (73–75% of growth) + variety | after L3 |
| Mastery Finishes | Arsenal | use (free) | beauty in the run, Arsenal Track | L33 |
| Mythics | Arsenal → Rift Anvil | Boss Cores | chase goals | L24 |
| Hero levels 1–30, Ult ranks, Awakening, Aspects | Heroes | Coins | hero power + style | L4 |
| Glory ◆1–5 | Heroes | world bosses beaten with that hero | finale reserves, hero perks | L8 (first boss) |
| Barracks (5 tracks) + Armory tiers + soldier skins | Barracks | Coins | army | L12 |
| Tactics row (6 nodes × 3 ranks) | Barracks | Coins | small rule tweaks | L26 |
| Haven per world → Citadel | Map (world node) | Crowns | info passives, options, cosmetics, featured items | L16 |

### 4.1 Heroes (Bolt, Titan; third hero Seer the lynx-mystic, unlocked free by beating the World 3 boss)

- **Hero level 1–30**: coins per level-up `round(30 × L^1.4, 10)` (L1→2 30 · L10→11 750 · L29→30 3 350; 42 140 per hero).
  Each level: +3.5% hero damage, +4% hero HP, +1% ult charge rate. **Cap = 6 + 3 × world reached** (W1 9 … W7 27;
  30 in Invasion) so a farmer cannot out-level content.
- Milestones: Lv5 **Ult Rank II** (+20% ult effect); Lv10 **Awakening I** (plan2 hero evolution look: new materials and
  VFX, no new mesh) + **Aspect II** + **Overdrive** (plan2 §4); Lv15 Ult Rank III; Lv20 Awakening II + Aspect III; Lv25 Ult
  Rank IV; Lv30 Awakening III + trait cap +50%.
- **Aspects** (Hades weapon aspects; swap freely before a run). Hero-identity machine bonuses live here, not in recipes:
  - Bolt: *Forked Fox* (default: every 3rd hit chains to 1) · *Railshot* (Lv10: hits pierce the corridor, −30% rate, +80%
    damage; Railgun and Laser charge/ramp 15% faster) · *Storm Fox* (Lv20: every 6th hit calls a mini-storm r1.5; Tesla
    and Arc Fence apply +1 Jolt stack).
  - Titan: *Bulwark* (default: splash 2) · *Seismic* (Lv10: each hit sends a 3 u Stagger line; Siege Ram and Mortar knock
    back 1 u more) · *Crystal Colossus* (Lv20: hits leave spikes for 3 s; Siege Ram ×1.25 structure damage in bucket 2).
- **Glory ◆1–5** (Archero hero stars, earned not bought): ◆2/◆3/◆4/◆5 at 1/3/5/7 world bosses beaten WITH that hero.
  Every ◆ above 1 of ANY hero: **+1 Reserve soldier at the siege** account-wide (finale bigger, gate math intact).
  Hero-specific: ◆2 trait cap +50%; ◆3 ult charge −10%; ◆4 Aspect perk +50%; ◆5 Radiant skin + aura.
- **Hero collection** (plan2): each owned hero +1 Reserve soldier.

### 4.2 Barracks (army) — replaces the old "army" and "power" coin upgrades

Five tracks, Lv0–10 each, coins `round(70 × L^1.55, 5)` (L1 70 · L5 850 · L10 2 485; 11 015 per track, 55 075 for all).
**Track cap = 2 + 2 × world reached** (W1 4 … W4+ 10). Every track amplifies a skilled choice or adds an option; none
touches the starting army, so LevelGen's gate puzzle ("+30 beats ×2 while the army is under 30") stays intact.

| Track | uk | Per level | At Lv10 | Rule it serves |
|---|---|---|---|---|
| Recruits | Новобранці | each grey recruit group you collect brings +1 extra soldier per 2 levels | +5 per group | rewards routing to recruits |
| Reserves | Резерв | +2 soldiers join at the siege | +20 | bigger finale and stairs |
| Scrape Guard | Обережність | the first 1 soldier per level lost per barricade or blade contact is saved | first 10 per contact | rewards edge play (plan2 "edge −3 vs straight −30") |
| Drill | Муштра | squads the hero hit within 2 s before contact lose +3% more in the clash | +30% | rewards aiming at squads |
| Volleys | Залпи | +6% army-tier volley damage | +60% | rewards ARM gates |

Armory tiers T3–T5 unlock by world reached (§2.7). Soldier-skin wardrobe lives here.

**Tactics row** (was the Workshop; opens L26; independent prices **600 / 1 400 / 2 800** per rank, 6 nodes × 3 ranks = 28 800;
free respec; every rank a visible effect ≥ 3%):

| Node | uk | Per rank | Rule it serves |
|---|---|---|---|
| Crate Craft | Майстер скринь | crate BONUS segment −10% | rewards hero aim on crates |
| Weak Point | Слабке місце | the fortress shows a glowing weak point that moves every 3 s; hero hits on it +15% | rewards aim at the siege |
| Streak | Серія | a run of 8+ tiles in a row gives +1 soldier per 8 / 6 / 5 tiles | rewards clean lines |
| Lead Engineer | Головний інженер | Lead machine +4% damage (bucket 2) | deck choice |
| War Chest | Скарбниця | +5% victory coins | economy (no run effect) |
| Ult Primer | Запал | the ult starts each level at +5% charge | earlier ult decision |

Removed from v1 because they delete decisions: Quick Hands (crate HP), Tile Magnet (pickup radius), Sappers (fortress HP),
Stair Climbers (stair cost), Gate Tuning, Captain's Bounty, Calibrated Crates, Spare Parts, Overflow.

### 4.3 Haven and Citadel (plan2 §7 "відбудова святині", paid in Crowns)

Each world has a Haven diorama (crystal temple, coral reef city, rune grove, magma hall, ice monastery, sky harbour, rift
observatory). **5 stages costing 2 / 3 / 4 / 4 / 5 Crowns** (18 per world, 126 for all; the campaign alone offers 168).
Each stage: a visible rebuild step (stage 1 and stage 5 are separate Meshy dioramas, the steps between are material/VFX
swaps), **+1 Citadel**, the stage passive below, and on stages 1–4 the player **picks 1 of the world's 4 featured items**
(deterministic, no keys; all 4 are owned by stage 4). Stage 5 = the restored diorama + the world's Haven finish for its
machines. **Citadel (0–35) is the hub's headline number** (Boom Beach HQ); it gates nothing that adds army power.

Featured items (picked at stages 1–4): two blueprint bundles for that world's machines (8 Common / 4 Rare / 2 Epic /
2 Legendary blueprints), the world's soldier skin and the world's Altar theme.

Passives (`EconData.HAVEN_PASSIVES`, 35 entries; information, options, economy or cosmetics only):

| World | Stage 1 | Stage 2 | Stage 3 | Stage 4 | Stage 5 |
|---|---|---|---|---|---|
| 1 Space | +1 deck preset | star-shard glints visible from 25 u | +3% victory coins | low-gravity jump arcs drawn 0.3 s earlier | Haven finish "Starlight" (W1 machines) |
| 2 Reef | currents shown 0.5 s earlier | RANK gates resolve at 40 u (earlier label) | +3% pickup coins | bubble-column capacity number shown | "Coral" finish |
| 3 Mystic | Phantom "?" shows a ±20% count range | mirror-arch preview shows both states larger | +3% victory coins | hidden rune gates reveal 0.3 s faster when hit | "Runic" finish |
| 4 Volcano | lava-jet markers 0.2 s earlier | light-hit icon on machine slots vs Armored | +3% pickup coins | melt-gate (10 → 3 knights) forecast shows clash outcome | "Magma" finish |
| 5 Ice | ice-slide path preview line | Shielded pool shown as a bar on the counter | +3% victory coins | frozen-soldier blocks show their HP | "Frostglass" finish |
| 6 Sky | splitter lever effect shown on the fork | Flying squads cast a ground shadow 2 u ahead | +3% pickup coins | speed-portal duration ring | "Stormcloud" finish |
| 7 Rift | Rift squads' two property icons enlarged | EVOLVE gate stays one extra row | +3% victory coins | +1 deck preset | "Void" finish + Citadel crown |

**Crowns (0–3 per level, improvement only; replaces v1 "crystals")**: crown 1 = win; crown 2 = army at the fortress ≥
`EconData.CROWN_ARMY[level]`, baked by `tools/bake_crowns.gd` as 60% of the LevelSim best-path army with the EXPECTED profile
for that level (plan2: "the maximum is computed by the bot"); crown 3 = all three star-shards collected in this run. A
stronger account makes crown 2 somewhat easier; crowns 1 and 3 are pure skill. Invasion levels have their own crowns.

### 4.4 Reinforcements (retry assist) and the loss payout

- **Reinforcements / Підкріплення** (Hades God Mode, Crash Aku Aku): after each loss on the same level, the next attempt
  gets +2 starting soldiers and +5% hero and machine damage (bucket 2), up to 5 stacks (+10 soldiers, +25%). A chip on the
  PLAY button and the loss screen shows it ("Підкріплення +15%"); Settings toggle "Допомога після поразок" (default on).
  It resets on a win and is off in Expedition and Nightmare. LevelGen is untouched. Sim effect: casual boss win ≥ 72% in
  every world, loss streak p90 3, max attempts on one level p90 4.
- **Loss payout**: `(0.25 × victory_coins(L, 0) + 0.70 × pickups collected) × fraction of the bridge covered`; +1/3 of a
  Stone Cache charge (three losses = one Stone Cache, from L6); fielded machines get 50% of their drip; a NEW crate opened
  stays unlocked. The loss screen shows progress ("Пройдено 72% мосту"), the payout, the charge (2/3), the Reinforcements
  chip and two buttons: **"Ще раз"** (primary) and "Арсенал" (secondary, opens with the Best-upgrade row). No ad, no offer,
  no revive prompt.

### 4.5 First-session script (time budget; ≤ 2 new systems per session)

| Step | Content | Time |
|---|---|---|
| Boot | studio + title 2 s, straight into L1 (no menu) | 3 s |
| L1 | drag, tiles, blue gates; fortress always falls; stairs | 25 s run + 5 s result |
| L2 | red gates + forecast, first crate (Ballista NEW, docking) | 35 s + 6 s (+4 s NEW walkout) |
| L3 | charge gate, scripted ult, siege | 40 s + 6 s |
| Arsenal intro | hub opens on the Arsenal tab, one coin-only upgrade (Ballista Lv2), full ceremony | 25 s |
| L4 | Titan joins: hero choice card, Heroes tab with a free first hero level | 45 s + 30 s |
| Session 1 total | L1–L4 ≈ 5 min, 2 tabs opened (Arsenal, Heroes) | ≈ 5 min |
| Session 2 | L5 pairs, L6 first Stone Cache + blueprints (inline reveal 2.5 s), L7, L8 boss + World Cache on the Altar (first Altar visit plays in full, ≈ 6 s) | ≈ 7 min |

### 4.6 UnlockQueue (`scripts/meta/unlock_queue.gd`; gated by level AND session)

Rules: at most one new tab or currency per 2 levels and at most 2 per session; an unlock that would be the 3rd in a session
waits for the next session start (session = app foreground after ≥ 5 min away). Each unlock: a locked-tab visual before it
opens (frosted icon + "Рівень 12"), one tutorial line, and its first step free. Migrated players get the same queue as a
"catch-up tour" (§9.2).

| Opens at | Unlock | First step free | Tutorial line (uk / en) |
|---|---|---|---|
| L1–3 | run only (plan2 §9 tutorial) | — | "Тягни, щоб вести армію" / "Drag to lead the army" |
| after L3 | **Arsenal** (Ballista, Drone; coin-only Lv2) | Ballista Lv2 | "Покращ машину за монети" / "Upgrade a machine with coins" |
| L4 | **Titan + Heroes tab** (hero levels) | first hero level | "Обери, хто веде армію" / "Choose who leads the army" |
| L5 | crate pairs (in-run) | — | "Дві скрині — бери одну" / "Two crates — take one" |
| L6 | **Stone Cache + Blueprints** | the scripted cache (Ballista + Drone) | "Схованка: креслення для твоїх машин" / "A cache: blueprints for your machines" |
| L8 | **Altar + World Cache**; Boss Core ring appears | the first World Cache | "Розбий схованку героєм" / "Crack the cache with your hero" |
| L10 | **Deck** (3 slots) + Lead | Auto-deck pre-filled | "Колода вирішує, що в скринях" / "Your deck decides what crates hold" |
| L11 | RANK gates (in-run) | — | "Ворота рангу посилюють машину" / "Rank gates power up a machine" |
| L12 | **Barracks** | first Recruits level | "Казарми: армія, що росте від твоїх рішень" / "Barracks: an army that grows from your choices" |
| L13 | **Talents** | free pick + free respec | "Талант змінює, як стріляє машина" / "A talent changes how a machine fires" |
| L16 | **Haven + Crowns** (crowns since L1 shown banked) | stage 1 pre-paid | "Відбудуй світ за корони" / "Rebuild the world with crowns" |
| L17 | **Daily missions + login** | first mission done | "Щоденні завдання чекають до 3 днів" / "Dailies wait up to 3 days" |
| any (first time) | catalyst gate / EVOLVE gate hint | — | "Золоті ворота — еволюція" / "Gold gate — evolution" |
| L24 | **Rift Anvil** (3 cores → Mythic) | the first forge | "Викуй міфічну машину" / "Forge a Mythic machine" |
| L26 | **Tactics** row | first rank | "Тактика: дрібні правила бою" / "Tactics: small battle rules" |
| L28 | **Shop** | — | "Магазин: оздоби й набори без випадковостей" / "Shop: finishes and sets, no randomness" |
| L33 | **Finishes + Codex** (Mastery counted since day 1) | first finish | "Машина вчиться, поки воює" / "Machines learn while they fight" |
| L41 | **Arsenal Track** | backlog = one Royal Cache | "Кожен рівень машин веде цим шляхом" / "Every machine level moves you along" |
| L43 | **Weekly Expedition + Road** | — | "Похід: 5 рівнів, машини не скидаються" / "Expedition: 5 levels, machines carry over" |
| L57 | **Invasion**; Nightmare per finished Haven | — | "Нічні світи: Вторгнення" / "Night worlds: Invasion" |

Hardcore players (20 levels/day) still get at most 2 new systems per session: the queue holds the rest for later sessions.

---

## 5. PACKS — Caches on the Altar

### 5.1 The two-track rule (code review checklist item)

- **Random = earned.** Caches come only from play: level wins, three losses, bosses, the Arsenal Track, login day 4 and 7,
  the weekly missions and Expedition, Feats, replays (first 3 per day). Nothing random is ever sold for money or gems.
- **Paid = deterministic.** Money buys only the fixed SKUs of §6.6 (contents listed, non-consumable). Earned Gems buy
  cosmetics and **X-Ray Caches** whose exact contents are shown before purchase (Fortnite X-Ray Llamas, FIFA Preview Packs).
- No paid item feeds Arsenal Rating, the Track, pity counters or Cache drops (test in §3.8). No kompu gacha. This keeps the
  game outside paid-loot-box rules (Belgium, the Netherlands, Brazil minors 2026, Australia M rating, Ukie, Korea), while
  every earned Cache still discloses odds (Apple 3.1.1 / Google Play spirit).
- No timers, speed-ups, "open now", streak loss, countdown offers, or offers on or right after a reveal or a defeat.
- Odds live in ONE table (`EconData.CACHES`, `CARD_ODDS`, `STACK`, `PITY`) read by `CacheRoller`, the (i) screen and the
  sim. Any change appears in the in-game changelog (§9.8) and the (i) screen marks changed rows for one version
  (Nexon MapleStory fine lesson).

### 5.2 Cache lineup (`EconData.CACHES`)

| Cache | uk | Look (Meshy, App. A) | Blueprint slots | Guaranteed last slot | Bonus slot | Sources |
|---|---|---|---|---|---|---|
| **Stone Cache** | Кам'яна схованка | slate egg, sapphire points (A-32) | 3 | Rare+ | coins `30 + 3 × frontier` | every win from L6 (World Cache on bosses); every 3 losses; login day 4; Track; first 3 replay wins per day; Invasion wins |
| **World Cache** | Світова схованка | basalt egg, amethyst seams (A-33) | 5 | Epic+ (best rarity present) | coins `120 + 8 × frontier` | world and Invasion bosses; weekly 5/5 missions; Expedition 3/5 |
| **Royal Cache** | Королівська схованка | obsidian egg, gold filigree (A-34) | 8, Legendary weight ×4 on every slot | Epic+ | coins `300 + 12 × frontier` | every 12th Track node; login day 7; Expedition 5/5; Feat milestones; Codex complete |
| **X-Ray Cache** | Прозора схованка | opal egg with a window (A-35) | fixed, shown before buying | — | — | Shop, for earned Gems only; 3 on display, rotate on each world clear (never on a clock) |

**Card schema** (what one slot can be): a blueprint stack for one machine of the rolled rarity — Common 2–4, Rare 1–2,
Epic 1, Legendary 1, Mythic 1 (uniform within the range). With probability 0.5% the slot instead becomes a **Wild
Blueprint** of the same rarity (own line on the odds screen). The bonus slot is always coins. Mythic cards exist only in
World and Royal Caches and only after the first Mythic is forged (the single Mythic source among Caches).
**Pool** = machines whose home world you have reached + forged Mythics. A card for an unowned machine unlocks it with a
full walkout. **Machine choice inside a rarity** (disclosed under the table): Legendary and Mythic cards go to an unowned
machine of that rarity first (duplicate protection); otherwise 40% go to your **Focus** machine if it has that rarity
(Arsenal → machine → "Фокус"; default = your Lead), and the rest are drawn with your Deck machines ×1.5.

### 5.3 The roller (`scripts/meta/cache_roller.gd`, a line-by-line port of `economy_sim.roll_cache`)

```
roll(type, pool, pity, rng):
  present  = rarities in pool (Mythic only for World/Royal and only if forged)
  w(r)     = CARD_ODDS[r] × (4 if r == L and type == royal else 1), over present rarities
  slots 1..n−1: draw from w
  last slot:   gmin = min(type.guaranteed, best rarity present)            # "best rarity present in the pool"
               if E present and pity.since_epic + 1 ≥ 8 and gmin < E: gmin = E
               draw from w restricted to rarities ≥ gmin (re-normalised)     # re-roll, never "bump a low roll"
               if L present:
                   n = pity.since_leg + 1
                   if not pity.leg_welcome_done or n ≥ 30: last slot = L    # first cache after L enters the pool; hard pity
                   elif n ≥ 20: P(L on last slot) = max(its base share, 0.03 × (n − 19)), others scaled down
  each slot: 0.5% → Wild Blueprint of its rarity
  pity.since_epic = 0 if best ≥ E else +1   (only while E is in the pool; frozen otherwise)
  pity.since_leg  = 0 if best ≥ L else +1   (only while L is in the pool; frozen otherwise)
```
The result and the RNG state are saved BEFORE any animation (no reroll by killing the app).

### 5.4 Disclosed odds (exact, printed by the sim; the (i) screen shows the row for the player's CURRENT pool)

Per card in a free slot: **Common 68% · Rare 24% · Epic 6.5% · Legendary 1.4% · Mythic 0.1%**, re-normalised over the
rarities in your pool. Best card per Cache (no pity active; `tools/odds_table.gd` prints the same table from the shipped
`EconData`, CI fails on any drift > 0.01 pp; a 200 000-roll Monte Carlo of the roller agrees within 1 standard error):

| Pool | Cache | Best card: Rare | Epic | Legendary | Mythic | Guaranteed slot per card |
|---|---|---|---|---|---|---|
| World 1 (C, R) | Stone / World / Royal | 100% | — | — | — | R 100% |
| World 2 (C, R, E) | Stone | 68.65% | 31.35% | — | — | R 78.69% · E 21.31% |
| | World, Royal | — | 100% | — | — | E 100% |
| World 3+ (C, R, E, L) | Stone | 63.81% | 29.14% | 7.05% | — | R 75.24% · E 20.38% · L 4.39% |
| | World | — | 77.76% | 22.24% | — | E 82.28% · L 17.72% |
| | Royal (L ×4) | — | 36.48% | 63.52% | — | E 53.72% · L 46.28% |
| + a Mythic forged | World | — | 76.48% | 21.87% | 1.64% | E 81.25% · L 17.50% · M 1.25% |
| | Royal | — | 35.94% | 62.58% | 1.48% | E 53.28% · L 45.90% · M 0.82% |

What it means with pity (Stone Caches only, 200 000-cache streams): from World 3, **1 Legendary per 11.8 Caches** (the
longest gap is exactly 30, the hard pity) and an Epic or better every 2.63 Caches (longest gap 8). In World 2 an Epic or
better every 3.01 Caches. The odds screen also lists: stack sizes, Wild 0.5% per slot, Focus 40%, Deck ×1.5, duplicate
protection, the pity rules in one sentence each, and "Легендарні з'являються у Світі 3" while no Legendary is in the pool.

### 5.5 Pity, duplicates, Wild Blueprints, Focus

- **Two pity rules, one visible bar.** Epic: the 8th Cache in a row without Epic+ guarantees it (counts only while an Epic
  is in the pool). Legendary: soft from the 20th Cache (≥ 3% per Cache on the last slot, rising), hard at 30, and the
  first Cache after a Legendary enters the pool (World 3) is a Legendary ("welcome"). The Altar shows one bar:
  "Легендарна гарантовано ≤ N"; it is hidden until a Legendary is in the pool. Counters are shared across Cache types
  and saved in `[pity]`. No Mythic pity: Mythic blueprints have deterministic sources (Boss Core overflow, Expedition).
- **No hidden in-run rarity offset**: the crate picker is rule-based and shown by the forecast (§3.5).
- **Duplicate protection**: Legendary/Mythic cards go to unowned machines of the pool first; a "NEW" result is never an
  owned machine (Marvel Snap 2025).
- **Wild Blueprints** (Дикі креслення, per rarity, replace v1 Dust): filled automatically by (a) 0.5% Wild slots, (b) blueprints
  for a Lv15 machine converting 1:1 into Wild of that rarity, (c) Arsenal Track fixed nodes (Wild Legendary at rating 150,
  300, 450). A machine short of blueprints uses Wild ones of its rarity automatically when the player upgrades (the
  confirm button says "використає 2 дикі"). A Wild Mythic waits for a forged Mythic.
- **Focus** (Brawl Stars Starr Road, Snap Spotlight preview): pick one machine any time; 40% of cards of its rarity go to it
  and the Altar shows the ETA ("Рейкова гармата 12/20 · ≈3 перемоги").

### 5.6 Opening ceremony (result rolled and SAVED before any animation; no suspense ladder)

**Stone Caches open inline on the result screen** (Brawl Stars Starr Drop length, ≤ 2.5 s, skippable from 0.5 s): one
tap or 1 s auto → the egg cracks once showing the FINAL best rarity colour at once → cards fan out → blueprint sparks fly
to their bars. Setting "Схованки в сховище" sends them to the Vault instead (default ON from the 11th Stone Cache).
**World and Royal Caches, first unlocks and every Legendary+ walkout use the Altar** (`CacheAltar`, 3D SubViewport,
portrait; hero left-front, altar centre, world-palette temple). Godot: one AnimationPlayer per beat, Tweens for cards,
`Engine.time_scale` untouched (UI tweens `set_ignore_time_scale(true)`; slow-mo is scene-local `speed_scale`).

| t (s) | Beat | Visual | Sound | Haptic |
|---|---|---|---|---|
| 0.00–0.35 | **Present** | cache drops onto the altar (ease-out-back), dust ring, rune ring lights; idle breathe 1.00↔1.02 / 1.6 s; odds (i) chip and the pity bar visible | thud + stone tail | THUD 0.7 |
| tap or 1.0 s auto | **Strike** (decoration) | one hero strike: Bolt lightning / Titan emerald fist; the camera frames the hero at 3/4 from behind so the VFX carries the hit (procedural pose; keyframed clips are a Meta-3 option) | hit transient | CLICK 0.7 |
| +0.15 | **Honest tell** | light leaks through the crack in the colour of the BEST rarity inside, final from the first frame; Legendary+: two light pillars with a 0.25 s pre-sting | riser (pitch by tier) | QUICK_RISE 0.5 |
| +0.25 | **Burst** | 80 ms hit-stop, pre-fractured cache shatters (8–12 chunks), shockwave in rarity colour, camera trauma 0.35 (0.6 Legendary+); particles 40/70/120/200/250 by tier | crack + boom + stinger | THUD 1.0 |
| +0.35 | **Fan-out** | cards fly face-down into an arc (60 ms stagger), sorted ascending; each back glows its rarity | whoosh per card | TICK 0.5 first/last |
| tap / "Відкрити все" | **Flips** | Common 0.25 s · Rare 0.35 s · Epic 0.5 s · **Legendary 1.2 s walkout** (card dissolves into the 3D machine, it rolls onto the altar, turns, fires one volley; identity in 3 beats: family glyph → world emblem → name + model) · **Mythic 2.0 s** (world desaturates to 15% except the item, choir sting) | per-rarity stinger; music −6 dB 300 ms on Epic+ | §5.7 |
| +0.40 | **Sparks** | duplicates dissolve into blueprint sparks that fly into the machine's bar (count-up, green arrow if now upgradable); NEW badge on new items | pentatonic pings | none |
| end | **Summary** | grid by rarity; primary CTA **"Готово"**, secondary "Покращити [machine]" (deep link). "Відкрити все" exists only in the Vault. Never "Buy". | soft chord | — |

Totals: ≈ 3 s with no Epic, 5–6 s with a Legendary, ≈ 7 s with a Mythic; hold 0.3 s anywhere → summary. The first unlock
of each Legendary/Mythic plays in full once. **X-Ray Caches** skip Strike and Tell: contents are already known. Settings:
"Швидке відкриття", Reduce Motion (cross-fades ≤ 200 ms + one chime).

### 5.7 Rarity sensory language (meta UI: frames, cards, Caches, Altar; the run uses shells and pips, §2.1)

| Tier | Colour | Frame | Gem cut (colour-blind code) | Stinger (transient / body / tail) | Haptic |
|---|---|---|---|---|---|
| Common | `#D6DEE6` | plain steel | round | tick / steel / short shimmer | none |
| Rare | `#3FA9FF` | inner glow | square | chime +2 st / glass / 0.6 s | TICK 0.5 |
| Epic | `#B06CFF` | animated energy lines | triangle | 2-note arpeggio / crystal / 0.9 s | CLICK 0.7 ×2 |
| Legendary | `#FFB52E` | gold filigree + light pillar | star | brass clang / choir / 1.2 s | THUD 1.0, +100 ms CLICK 0.7 ×2 |
| Mythic | opal hue-cycle | art breaks out of the frame | eye | unique sting / choir + bells / 1.5 s | 3 pulses 0.5/0.7/1.0 @ 70 ms + LOW_TICK |

### 5.8 Fairness checklist (ship gate)

Tells never lie (the forecast label, the crack colour, the pity bar) · no near-miss or downgrade animation · no suspense
ladder · no slot-reel visuals · no offers after a reveal or a defeat · no limited-time anything · every low pull ends in
visible progress (pity bar, sparks into bars, Wild counters) · odds one tap away on every Cache, for the current pool ·
paid content deterministic and non-consumable · parental purchase lock (Settings → PIN, default on for accounts the Play
Families policy marks as child) · results saved before animation · odds changes listed in the changelog screen.

---

## 6. ECONOMY

### 6.1 Currencies (one job each; the top bar shows Coins, Gems and one tab chip)

| Currency | uk | Sources | Sinks (only) | Notes |
|---|---|---|---|---|
| Coins | Монети | level wins (× stairs), pickups, losses (partial), Caches, missions, login, Track, replays | machine levels, hero levels, Barracks, Tactics | the only soft currency |
| Blueprints (per machine) | Креслення | Caches, run drip, NEW crates, Haven featured bundles, login day 2 | that machine's levels | bar shows "12/20" |
| Wild Blueprints (per rarity) | Дикі креслення | 0.5% card slots, Lv15 overflow 1:1, Track fixed nodes, Expedition (Wild Mythic) | any machine of that rarity | replaces Dust; shown inside the blueprint bar |
| Crowns | Корони | 0–3 per level, improvement only (§4.3) | Haven stages | cannot be farmed |
| Gems | Самоцвіти | daily missions 5 each, login day 5 (20), weekly 50, Feats, Road | cosmetics, X-Ray Caches | **earned only**; never buy levels, coins or random Caches |
| Boss Cores | Ядра босів | world, Invasion and Nightmare bosses (14 in campaign + Invasion) | Rift Anvil (3 → a Mythic); overflow → Mythic blueprint | shown as segments on the Anvil ring, not in the wallet |

Removed from v1: Dust, Forge Keys, Hero Sigils, World Forge, the Workshop price markup, "supply packs".

### 6.2 Income formulas (`EconData`; replaces `Balance.victory_coins`)

```
victory_coins(L, survivors) = 20 + 6·L + min(floor(survivors / 3), 25)      # × (1 + 0.05 × War Chest rank)
pickups ≈ 8 + 0.7·L     (road coins; Harvester and Seal coins capped at +25% of victory_coins)
win payout  = (victory_coins + pickups) × stairs multiplier (×1.2 … ×5)
loss payout = (0.25 × victory_coins(L, 0) + 0.70 × pickups) × bridge fraction; +1/3 Stone Cache charge
replay      = 60% of the win payout of that level; no Crowns; Stone Cache only on the first 3 replay wins per day
Invasion n  = difficulty of campaign level 56 + n, pays as level 56 + n/2, full Crowns, Stone/World Caches, Boss Cores
run drip    = each fielded machine in a won run fills its bar by C 1.0 / R 0.5 / E 0.25 / L 0.12 / M 0.06 (×1.5 at Rank III)
daily       = login card (Continue mode) + 3 missions × (60 + 4·frontier) coins + 5 gems each; weekly 1 500 coins + World Cache + 50 gems
rewarded ad = ×2 on one win payout, at most 3 per day, never on L1–10, never on a loss
```
Examples (regular: ≈ 66 survivors, stairs ≈ ×2.4): L10 ≈ 280 coins + Stone Cache 60; L30 ≈ 610 + 120; L56 ≈ 1 030 + 200 per win.

### 6.3 Sinks and curves (all in `EconData`; totals printed by the sim)

| Sink | Formula / table | Total |
|---|---|---|
| Machine level | coins 40 … 7 500 per target level (§2.1), blueprints per rarity | 24 250 per machine from Lv1; **578 270** for the Arsenal |
| Hero level | `round(30·L^1.4, 10)` | 42 140 per hero |
| Barracks | `round(70·L^1.55, 5)`, 5 tracks × 10 | 11 015 per track, 55 075 total |
| Tactics | 600 / 1 400 / 2 800 per rank, 6 nodes | 28 800 |
| **All coin sinks** (Arsenal + 2 heroes + Barracks + Tactics) | | **746 425** |
| Haven | 2/3/4/4/5 Crowns per world | 18 per world, 126 total (campaign offers 168) |
| Mythic | 3 Boss Cores each | 12; overflow → Mythic blueprints |

### 6.4 Simulation results (`economy_sim.py`, 200 seeds per archetype, `economy_sim_output.txt`)

**Model.** Each attempt's win chance = `sigmoid(7·(power × (1 + assist) / demand − 1) + 3·(skill − 0.5) + 1.6)`, clamped
12–98%; L1–3 always won (tutorial). `demand(L) = (1 + 0.0165·(L − 1)) × boss`, boss = 1.00, 1.00, 1.04, 1.05, 1.05, 1.06,
1.07 for worlds 1–7 (the first two bosses teach). `power = (0.50 × machines + 0.25 × hero + 0.25 × army) × tactics`;
machines = the mean of the top-3 deck machines (normalised by slots owned, so an empty slot is not a 0) blended 80/20 with
the rest of the deck, including talents, Ascension, Apex and a 3%/rarity kit edge. Spending: **greedy** = the "Best
upgrade" value function; **spread** = cheapest badged item first (badges only on Deck machines + other tabs, §7.4);
**machines-only** = cheapest Deck machine first, nothing else. UnlockQueue levels are applied. Not modelled (named so the
reader knows): gem spend (cosmetics only), Road (no power), Shrine cards, Haven passives (information only), Harvester and
Seal coins (capped at +25% of victory coins), the quality of talent choices (valued at +5% each), and telemetry-driven
demand (replace `demand()` with bot-measured win rates once Meta-1 runs).

| Archetype (levels/day, skill, stairs) | Attempts for 60 levels (win) | Days | Coins earned | Boss win, worst world | Loss streak p90 / max | Max tries on one level p90 | Deck Lv @L30 / @L60 | Hero Lv @L60 | Citadel @L60 |
|---|---|---|---|---|---|---|---|---|---|
| Casual (4, .35, ×1.7) | 72.9 (82%) | 18.8 | 51 000 | 72% (W7) | 3 / 4 | 4 | 8.0 / 11.2 | 14.8 | 29.8 |
| Regular (8, .60, ×2.4) | 64.9 (92%) | 8.7 | 55 500 | 88% | 2 / 3 | 3 | 8.1 / 11.6 | 15.8 | 34.9 |
| Hardcore (20, .85, ×3.2) | 62.1 (97%) | 4.0 | 63 500 | 94% | 1 / 3 | 2 | 8.7 / 12.0 | 18.3 | 35.0 |

Players who do not follow the Best-upgrade button (casual skill), and weaker players:

| Variant | Win rate | Boss win, worst world | Loss streak p90 | Max tries p90 |
|---|---|---|---|---|
| casual / spread (cheapest badge first) | 79% | 66% | 3 | 4 |
| casual / machines-only (the owner's pitch: "upgrade weapons") | 79% | 62% | 3 | 4 |
| weak casual (3/day, skill .20, stairs ×1.4, 1 daily) / greedy | 74% | 59% | 3 | 4 |
| weak casual / spread | 71% | 59% | 4 | 5 |
| casual + 3 rewarded ads/day | 88% (+5.5 pp vs casual) | 78% | 2 | 3 |
| casual + Starter Arsenal | 85% (+2.7 pp) | 74% | 2 | 3 |

**Pacing checks** (all pass; the full list is in the output):
- **Machines carry the game**: 73–75% of power growth at L60 comes from machine levels (v1 ≈ 20%); coin spend split
  (regular) machines 56%, hero 16%, Barracks 11%, Tactics 17%. "Machines-only" players are now as strong as "spread" ones.
- **Something to buy every session**: 97% (casual) to 100% of sessions have ≥ 1 upgrade; 3.6 (casual) / 8.3 (regular)
  upgrades per session; unspent coins at checkpoints median 66–97, p90 206–237.
- **Ceremony share** of session time 13–14% (p90 18%), under the 15% budget.
- **Saving targets**: in Crowns, each world's Haven stage 5 (5 Crowns ≈ 2 sessions of new crowns); in coins, the Prestige
  levels 13–15 (3 600 / 5 200 / 7 500 ≈ 0.5–1.5 days of post-campaign income). During the campaign the Best-upgrade
  button always has something under one session of income (unspent median 66–97): kept on purpose for short mobile sessions.
- **Power vs demand**: boss 1.02–1.07, non-boss 1.05–1.10 on average; there is no planned dip (v1's "dip" was a boss-level
  sampling artefact). Bosses are the walls; Reinforcements caps how long one lasts.
- **Income mix (regular)**: stairs 38%, level base 27%, Caches 20%, missions 9%, Track 4%, login 1%. Casual leans on
  missions (17%) and Caches (25%) because those bank or come per level, not per stair step.
- **Beats** (first machine to reach): Ascension Lv8 at campaign level 21 (casual day 7, regular day 4; hardcore L16,
  day 2); Talent III Lv10 at L38–39 (hardcore L32); **Apex Lv12 at L48 for regular and hardcore, L57 for casual** (day 18,
  the first Invasion level); Lv15 after the campaign (regular day 39, casual day 77, hardcore day 12).

### 6.5 Post-campaign loop and the long horizon (sim §5, 180 days)

- **Invasion** (opens after the World 7 boss): night versions of worlds 1–7 in order, 56 levels; level n plays at the
  difficulty of campaign level 56 + n (denser squads, plan2 "Вторгнення") and pays as level 56 + n/2; full Crowns (their
  own track), Stone/World Caches, Boss Cores from its bosses. It is the end-game that makes Lv11–15 matter: its last world
  needs a near-maxed deck or Reinforcements.
- **Nightmare** (plan2): one level per world, unlocked by finishing that world's Haven (stage 5); no +1 tiles; first clear
  = Boss Core + Royal Cache; afterwards replay rules.
- **Weekly Expedition** (§8.4): 5 seeded levels, World Cache at 3/5, Royal Cache + a Mythic blueprint at 5/5.
- **Replay** of any cleared level: 60% coins, no Crowns, Stone Cache on the first 3 replay wins of the day.

| Player | Campaign done | Invasion done | First Lv15 | Day 30 | Day 60 | Day 90 | Day 120 | Day 180 | Coins/day after Invasion |
|---|---|---|---|---|---|---|---|---|---|
| Casual | day 18 | day 37 | day 77 | avg Lv 8.2 | 10.9 | 12.7 | 13.7 (11.7 maxed) | 14.3 (all 20 non-Mythics maxed) | ≈ 4 700 |
| Regular | day 9 | day 17 | day 39 | 11.2 | 13.3 (9.1 maxed) | 14.0 (19.3 maxed) | 14.2 (19.9 maxed) | 14.4 | ≈ 8 600 |
| Hardcore | day 4 | day 7 | day 12 | 12.6 | 13.8 | 14.1 | 14.3 | 14.5 | ≈ 21 900 |

Rarities level at the same pace (casual day 60: C 11.2 · R 11.2 · E 12.0 · L 11.8), confirming the blueprint table.
Mythics are the long tail: average Mythic level at day 180 is 10.7 (casual) to 12.1 (hardcore), fed by Boss Core
overflow and the Expedition. So: a regular player finishes the 20 non-Mythic machines around day 100–120 and is still
growing Mythics at day 180; a casual player maxes the non-Mythics around day 150–180. "6+ months to full mastery"
holds only including Mythics and finishes; v1's "first Lv15 day 25–35" is replaced by the measured day 39 (regular).

Tuning knobs (change `EconData`, re-run, keep the §6 invariants of the sim green): casual boss win ≥ 65% in every world;
loss streak p90 ≤ 3; max tries on one level p90 ≤ 4; casual win rate 65–85%; spread ≥ 60% and machines-only ≥ 55% worst
boss; weak casual ≥ 55%; ad watcher ≤ +6 pp and Starter ≤ +3 pp over casual; machines ≥ 50% of power growth; ceremony
≤ 15% of session time; regular first Ascension at L20–34 and first Apex at L44–60; the §3.2 in-run budget bands.

### 6.6 Monetisation (optional, fair, offline-first; WS6)

**Every real-money product is a non-consumable entitlement** (Google Play one-time product, acknowledged, restored with
`queryPurchases` on every launch and on "Відновити покупки" in Settings), so nothing is lost on reinstall. There are no
consumable IAP, no gem packs and no random items for money. Paid power total ≈ 5 000 coin-equivalent ≈ 9% of a regular
player's campaign income (55 500): Starter + six World Sets.

| SKU | Price tier | Contents (exact) | Coin-equivalent power | When visible |
|---|---|---|---|---|
| `starter_arsenal` | $2.99 | 2 000 coins + 6 blueprints for each of Drone and Ballista (owned machines only) + "Royal Gold" finish for Ballista + gold hub frame | ≈ 2 600 | Shop from L28 |
| `supporter` | $4.99 | rewarded ×2 without watching the ad (same cap 3/day, same rules) + "Sunrise" Altar theme + supporter badge | ad-equivalent only (+5.5 pp measured for a daily ad watcher) | Shop from L28 |
| `world_set_1` … `world_set_6` | $1.99 each | that world's soldier skin + Haven-style finish for its machines + one blueprint stack for its machines capped at `EconData.WORLD_SET_CAP[w]` (the free player's median level at that point) | ≤ 400 each | only for worlds cleared ≥ 2 worlds ago |
| `road_premium` | $4.99 | premium lane of every shipped Road chapter (cosmetics + gems) | 0 | from L43 |
| `skin_storm_regalia_bolt`, `skin_obsidian_titan` | $3.99 each | hero skin + matching ult VFX | 0 | from L28 |
| `flare_obsidian`, `flare_aurora`, `flare_rose_gold` | $2.99 each | that Flare colourway for every machine | 0 | from L33 |

- Gem prices (earned gems; anchors): X-Ray Cache 120–400 by contents, finish 150–300, Altar theme 200, soldier skin 250.
- **Ads** (AdMob rewarded only, player-initiated): ×2 payout on a win, cap **3 per day**, never on L1–10, the button never
  pulses, and it is **absent** when offline or when no ad is loaded (never a disabled grey button). No revive ad, no
  interstitials, no ad or offer on the defeat screen. Google **UMP** consent form on first launch in EEA/UK before the ads
  SDK initialises; "Налаштування реклами" in Settings reopens it.
- **Billing**: `GodotGooglePlayBilling` plugin (WS6): `startConnection`, `queryProductDetails`, `purchase`, acknowledge within
  3 days, `queryPurchases` on launch; entitlements cached in `[shop]` and re-validated whenever Play is reachable; offline
  launches trust the cache. Parental purchase lock in Settings (PIN).
- Power purchasable for money is capped as above and is never exclusive: every machine, level, Mythic, Ascension, recipe and
  Apex is earnable by play. Recipes, Boss Cores and Caches are never sold.

---

## 7. META UI — the hub (portrait 720×1280, safe areas respected; WS4)

### 7.1 Global layout, per-tab wireframes, gesture map

Five labelled tabs: **Магазин · Арсенал · ГРА (raised, default) · Герої · Казарми**. Top bar (0–7%): avatar with the Citadel
ring left; ≤ 3 currency chips right (Coins, Gems, + one per tab: Arsenal = Wild Blueprints, Heroes = none, Barracks =
none, Map = Crowns). Tab bar 88–100%. Zones per tab (percent of screen height):

| Tab | 7–30% | 30–55% | 55–74% | 74–88% |
|---|---|---|---|---|
| **ГРА / Play** (map) | live world map: level nodes along a glowing path, Haven diorama button at the top of each world | (map continues) | (map continues) | PLAY CTA (70% width, 72 pt, "Рівень 23 · Рунічний ліс", Reinforcements chip) + Deck row of 3 chips |
| **Арсенал** | 3D showcase: the selected machine on a pedestal, turntable | sub-tabs (Машини · Колода · Кодекс · Ковадло) + filter chips at 30–35%, then 3-column card grid | grid | grid; Best-upgrade row pinned at 80–88% |
| **Герої** | 3D showcase 7–55%: hero big, swipe carousel on the showcase | (showcase) | level bar + two-tap level-up, milestone track | Aspects, Glory ◆, skins |
| **Казарми** | 3D showcase: soldier formation in the current tier skin | 5 track rows (icon, Lv/cap, effect "+5 за групу", price) | Tactics row (6 nodes) | Armory ladder T0–T5, wardrobe |
| **Магазин** | header + "Відновити покупки" | sections: SKUs (contents listed), X-Ray Caches (contents shown), cosmetics | | |

Side rails (Play tab only, ≤ 2 icons each, progress rings, not red dots): left = Expedition, Road; right = Missions,
Cache Vault. **Gesture map**: horizontal tab swipe works only on the tab bar and on the 7–30% showcase strip of tabs that
have no carousel there (Play, Arsenal, Barracks); the hero carousel, finish carousel and deck drag-to-reorder own their own
areas; long-press on a deck card starts a drag. Vertical scroll inside zones only.

Motion tokens (`UITokens`): FAST 0.15 s, STD 0.30 s, SLOW 0.45 s; ceremonies by tier (§7.3). Position/scale: spring or
TRANS_BACK (1.70158) on arrivals only; opacity/colour: TRANS_EXPO ease-out; exits faster than entrances (280/180 ms).
Button press 0.92 → 1.05 → 1.0 (≈ 220 ms) + haptic CLICK 0.5. Min touch 44 pt, min text 11 pt.

**Style (v2)**: painted 9-slice frames ≥ 4 px with bevel and inner shadow (no 1–2 px hairlines that alias on 720 px);
warm, bright panels for Heroes, Barracks and Shop (cream parchment + gold); the dark navy spotlight stage only behind the
Arsenal showcase. Machine cards are 3 layers (backdrop, machine render, FX/particles) with drag/gyro tilt parallax
(±6°); Epic+ cards get an animated frame. Thumbnails are rendered at first launch into `user://thumbs/` (one per machine ×
equipped finish, re-rendered when a finish changes); the selected card shows the live 3D model in the showcase.
Saturated colour only for rarity, CTAs and the family accent; everything else ≈ 30% desaturated (plan2 readability).

### 7.2 Screens and flows (entry → states → exit)

| Screen | Entry | States | Exit |
|---|---|---|---|
| **Play map** | default tab; after every result | node: number, Crowns 0–3, star-shards 0–3, threat icons; locked worlds silhouetted; mode chips on cleared worlds (Invasion, Nightmare) | PLAY → run; long-press node → Threat preview sheet (+ Auto-deck) |
| **Haven view** | Haven button atop a world | 5-stage diorama (stage model swap), stage list with Crown cost, passive, featured-item picker (4 cards, pick 1) | build → full ceremony (camera orbit, material wipe ≤ 3 s) → back |
| **Machines grid** | Arsenal tab | filters (All, family, owned, upgradable); card: frame, render, Lv, blueprint bar + Wild hint, green arrow only for Deck machines and the Best upgrade; unowned = silhouette + "Світ 3, рівень 5" | tap → Machine detail |
| **Machine detail** | card tap | turntable + live demo loop of its NEXT state (sandbox `machine_demo.gd`: Weapons node + 3 dummy squads + a dummy barricade in a SubViewport); stat rows with green deltas; beat track (Lv1…15 icons at 3/5/6/8/10/12/15); talents (2 cards per tier); Focus toggle; finishes carousel | two-tap upgrade (tap 1 morphs in 150 ms to "Підтвердити · 1 260", tap 2 → ceremony) |
| **Talent pick** | the level-up ceremony that reaches Lv3/6/10 ends on two cards; or a gold "!" on the card later | default = none until picked (the machine works without it); free swap any time | pick → micro ceremony |
| **Ascension branch** (Epic+) | the Lv8 ceremony ends on a split screen A/B, each with a live demo loop | pick; switch free later from detail | pick → Ascension transform (≤ 3 s, camera orbit, new-model reveal) |
| **Deck editor** | Arsenal → Колода | 3–6 slots (locked ones show the world that opens them), Lead crown, presets A/B/C, Auto-deck, family counts + recipe hints, Mission tags | back (auto-saves) |
| **Codex** | Arsenal → Кодекс | 20 entries: discovered (card + recipe) / silhouette + family pair hint | — |
| **Rift Anvil** | Arsenal → Ковадло (from L24) | 4 Mythic cradles, core ring segments 0–3, choose a Mythic | forge → Mythic ceremony (2 s Peggle moment) → Machine detail |
| **Cache Vault** | right rail | list by type with counts; empty state: "Схованок немає. Перемоги приносять кам'яні схованки." | open one → Altar; "Відкрити все" → batch |
| **Missions / Road / Track** | right rail / left rail / Arsenal header | Missions: 3 dailies + weekly 5 with progress bars, reroll (1/day), claim; Road: chapter strip with free and premium lanes; Track: horizontal node path, next 5 nodes visible, claim backlog | claim → RewardFly |
| **Expedition** | left rail (L43+) | intro card (this week's 5 worlds, rewards 3/5 and 5/5, best banked), in-run HUD shows "Похід 2/5" | start / continue / restart (unlimited this week) |
| **Feats** | Heroes tab → Подвиги | 60 feats, 3 tiers each, counters | claim → RewardFly |
| **Shop purchase** | Shop tab | product sheet: exact contents, coin-equivalent, "Без випадковостей"; parental PIN if enabled → Play sheet → on success acknowledge → reward fly; on cancel nothing; offline → "Потрібен інтернет для покупки" | back |
| **Settings** | gear | music, sfx, language, vibration, Reduce Motion, Fast ceremonies, Quick reveal, Caches to Vault, Auto Apex, Reinforcements, ad consent, restore purchases, parental lock, changelog ("Що нового") | back |
| **Loss screen** | run lost | §4.4 (progress, payout, charge, Reinforcements chip) | "Ще раз" / "Арсенал" |

### 7.3 Result flow (after a win) and ceremony tiers

"Далі" is tappable from **0.5 s** at every step; tapping it grants everything at once and skips to step 7.
1. Coin odometer rolls ≤ 1.0 s (Duolingo). 2. Stairs stamp "×3.2" with back easing + THUD. 3. Stats stagger 80 ms
(survivors, Crowns 1–3 with pops, star-shards). 4. Victory lap: leftover machine charge fires a coin barrage ≤ 1.5 s.
5. Rewards fly to their tabs (coins to the chip, blueprints to the Arsenal icon).
5a. **NEW machine walkout** (only when a NEW crate was opened): silhouette → light → name slam → one demo volley, ≤ 4 s,
unskippable only the first time per machine (Brawl Stars unlock).
5b. **Discovery card** for a first Evolution/Fusion: card with shine sweep + Codex entry, ≤ 1.5 s.
5c. **Boss Core** flies into the Rift Anvil ring segment, ≤ 1.5 s.
5d. **Mission ticks**: one line ("Завдання 2/3 ✓"), 0.6 s.
6. Stone Cache inline reveal ≤ 2.5 s (or "→ Сховище"); World Cache: "Відкрити на вівтарі" / "Пізніше".
7. **Best-upgrade row** (one pre-selected upgrade, "Найкраще покращення: Рейкова гармата Lv9 · 980", one tap opens its
two-tap confirm; never spent automatically) + **"Далі"** (primary). Celebration intensity scales with log5(overshoot).

**Ceremony tiers** (`UITokens.CEREMONY_*`): micro 0.35 s (Barracks, Tactics, hero levels without a milestone); standard
1.2 s (machine levels without a beat); full ≤ 3 s (beats at Lv3/5/6/8/10/12/15, Ascension, Haven stages, Mythic forge).
"Fast ceremonies" (Settings) halves standard and full; it is ON by default from the player's third day. "Покращити все"
on Barracks tracks buys the cheapest affordable ranks in one micro ceremony. Sim: ceremonies are 13–14% of session time.

### 7.4 Reward flows and notification discipline

- **RewardFly** (one node on a top CanvasLayer): source = 3D position via `Camera3D.unproject_position`; icon count
  `clamp(4 + 3·log2(amount/base), 6, 20)`; burst 0.2 s outward 60–140 px (expo-out), hold 0.08 s, fly 0.45–0.65 s on a
  bezier, 30 ms stagger; counter rolls from first arrival to last + 150 ms; chip punch 1.0→1.2→1.0 (140 ms) + Balatro
  wobble (amp 0.4, 0.4 s). Ticks: 2 layers ±10% pitch, +1 semitone per arrival (cap +12), ≤ 15 ticks/s; haptic on first
  and last only. Tap → everything lands with one chord.
- **Upgrade flare**: charge (glow ramp, riser) → white flash 80 ms → hit-stop 70 ms → shockwave → level badge flip →
  stats count up staggered 70 ms; THUD 1.0. Durations by tier (§7.3).
- **Badges**: a green arrow only on the Best-upgrade item and on affordable Deck machines; a gold "!" for claimables
  (missions, talent picks, Track nodes). No numeric red dots. At most one dismissible "new in shop" dot per world clear.
- **Arsenal header**: the next milestone only ("до Піднесення Рейкової гармати: 2 рівні"); the full total ("47% · 312 400
  монет до повного Арсеналу") lives in a details sheet.

---

## 8. MISSIONS, ROAD, TRACK, EXPEDITION, FEATS, CODEX

Counters come from `Run.result.stats` (fixed keys, §9.4) and are summed in `[counters]`.

### 8.1 Daily missions (`EconData.MISSION_POOL`; 3 per day, bank 3 days, 1 free reroll per day; L17+)

Reward each: coins `60 + 4 × frontier` + 5 gems + 40 Road XP. Missions only use owned machines; "Mission" tag in the deck editor.

| id | Text (uk) | Counter (stats key) | Target |
|---|---|---|---|
| M01 | Виграй 3 рівні | `wins` | 3 |
| M02 | Відкрий 4 скрині | `crates_opened` | 4 |
| M03 | Наповни бонус скрині 2 рази | `crate_bonus` | 2 |
| M04 | Досягни рангу III | `rank3_reached` | 1 |
| M05 | Візьми 2 ворота рангу | `rank_gates` | 2 |
| M06 | Виклич еволюцію або злиття | `evolutions + fusions` | 1 |
| M07 | Виграй з машиною [Lead] у колоді-лідері | `wins_with_lead[id]` | 2 |
| M08 | Знищ 60 ворогів машинами [родина] | `kills_by_family[f]` | 60 |
| M09 | Заморозь 10 загонів | `statuses.freeze` | 10 |
| M10 | Підпали 15 загонів | `statuses.burn` | 15 |
| M11 | Познач 20 загонів | `statuses.mark` | 20 |
| M12 | Виклич 3 реакції | `reactions_total` | 3 |
| M13 | Зламай 4 барикади | `barricades_broken` | 4 |
| M14 | Збий 5 турелей | `turrets_destroyed` | 5 |
| M15 | Зберіть 30 рекрутів | `recruits` | 30 |
| M16 | Пройди рівень без втрат на шипах | `levels_no_hazard_loss` | 1 |
| M17 | Дійди до сходинки ×3 | `stairs_reached_3` | 2 |
| M18 | Візьми 8 добрих воріт | `gates_by_op.good` | 8 |
| M19 | Переверни 3 ворота-заряди | `gates_by_op.charge_flipped` | 3 |
| M20 | Використай ульту 4 рази | `ult_uses` | 4 |
| M21 | Запусти Апогей 2 рази | `apex_uses` | 2 |
| M22 | Візьми фортецю менш ніж за 8 с | `fortress_fast` | 1 |
| M23 | Збери всі осколки зірки на рівні | `levels_all_shards` | 1 |
| M24 | Здобудь 5 корон | `crowns_gained` | 5 |
| M25 | Пройди 2 рівні Вторгнення | `invasion_wins` | 2 |
| M26 | Виграй, маючи 3 машини однієї родини | `wins_family3` | 1 |
| M27 | Відкрий 2 схованки | `caches_opened` | 2 |
| M28 | Покращ будь-що 3 рази | `upgrades_bought` | 3 |

**Weekly** (5 missions from the same pool ×4 targets, bank 1 extra week): 5/5 → World Cache + 1 500 coins + 50 gems + 100 Road XP.
**Login cycle** (7 cards, Continue mode, never resets, L17+): 150 coins · 2 Rare blueprints · 250 coins · Stone Cache ·
20 gems · 400 coins · Royal Cache. Calendar: local date (`calendar.gd`); a clock moved backwards never removes anything,
it only stops new grants until the date passes the last grant.

### 8.2 Arsenal Track (free, permanent, driven by Arsenal Rating; L41+)

A node every 10 rating; the rating earned before L41 is paid as one welcome Royal Cache. 12-node cycle:
1 coins `100 + 10 × frontier` · 2 coins · 3 Stone Cache · 4 3 Wild Common · 5 20 gems · 6 Stone Cache · 7 coins · 8 2 Wild
Rare · 9 Stone Cache · 10 20 gems · 11 1 Wild Epic · 12 Royal Cache. Fixed overrides: rating 150, 300, 450 = 1 Wild
Legendary (no collection drought). The next 5 nodes are always visible.

### 8.3 Road (Шлях; replaces the 28-day Crystal Road season)

12 chapters × 10 tiers × 100 Road XP shipped in the build; **chapters never expire**; new chapters ship with updates.
XP: missions 40, weeklies 100, wins 5 (the first 20 wins per day count). Free lane: gems, soldier skins, Altar themes,
victory poses, bridge trails — no coins, blueprints or Caches (no power on the Road). Premium lane (`road_premium`
entitlement): finishes, hero ult variants, more gems. Nothing is time-limited, so there is no Archive shop.

### 8.4 Weekly Expedition (Похід; plan2 §7 "Кришталевий похід"; L43+)

- Seed = ISO week of the local date; LevelGen builds 5 levels from 5 different worlds at difficulty = the player's
  campaign frontier (capped at 56) with Expedition chunks; army, machines, Ranks and Evolutions carry over (§3.2: 4 crate
  events per level).
- **Unlimited retries within the week**, always from level 1; the best result banks; Reinforcements are off.
- Rewards (once per week): 3/5 World Cache; 5/5 Royal Cache + 1 blueprint for your lowest forged Mythic (or a stored Wild
  Mythic if none is forged). Score = survivors at the last fortress; local best kept per week.
- Clock moved backwards: the current week stays; no second reward for the same week.

### 8.5 Feats (Подвиги; 60 feats × 3 tiers = 180 rewards; Hades Fated List)

Rewards: tier 1 10 gems, tier 2 25 gems, tier 3 50 gems; every 10th completed tier 3 also gives a Royal Cache.

| id | Feat | Counter | Tiers |
|---|---|---|---|
| F-01 | Перемоги | wins | 25 / 100 / 400 |
| F-02 | Корони | crowns_total | 30 / 90 / 168 |
| F-03 | Відбудовані притулки | haven_complete | 1 / 4 / 7 |
| F-04 | Цитадель | citadel | 10 / 20 / 35 |
| F-05 | Машини в колекції | machines_owned | 8 / 16 / 24 |
| F-06 | Піднесення | ascensions | 1 / 6 / 20 |
| F-07 | Апогеї розблоковано | apex_unlocked | 1 / 6 / 20 |
| F-08 | Майстерні машини (Lv15) | mastered | 1 / 8 / 24 |
| F-09 | Оздоби | finishes_total | 10 / 50 / 144 |
| F-10 | Ранг III | rank3_reached | 10 / 100 / 500 |
| F-11 | Еволюції | evolutions | 5 / 40 / 150 |
| F-12 | Злиття | fusions | 3 / 25 / 100 |
| F-13 | Різні еволюції | evolutions_distinct | 3 / 8 / 12 |
| F-14 | Різні злиття | fusions_distinct | 2 / 5 / 8 |
| F-15 | Скрині відкрито | crates_opened | 50 / 400 / 2 000 |
| F-16 | Бонус скрині | crate_bonus | 20 / 150 / 800 |
| F-17 | Ворота рангу | rank_gates | 10 / 80 / 400 |
| F-18 | Каталізатори | catalyst_gates | 5 / 40 / 200 |
| F-19 | Добрі ворота | gates_by_op.good | 200 / 1 500 / 8 000 |
| F-20 | Ворота-заряди перевернуто | gates_by_op.charge_flipped | 20 / 150 / 800 |
| F-21 | Заморожені загони | statuses.freeze | 50 / 400 / 2 000 |
| F-22 | Підпалені загони | statuses.burn | 50 / 400 / 2 000 |
| F-23 | Позначені загони | statuses.mark | 50 / 400 / 2 000 |
| F-24 | Оглушені загони | statuses.stun | 50 / 400 / 2 000 |
| F-25 | Надпровідність | reactions.superconduct | 10 / 80 / 400 |
| F-26 | Термошок | reactions.thermal_shock | 10 / 80 / 400 |
| F-27 | Спалах | reactions.flare | 10 / 80 / 400 |
| F-28 | Лезо заморожено Мінером | blades_frozen | 1 / 25 / 150 |
| F-29 | Лаву погашено | lava_quenched | 1 / 25 / 150 |
| F-30 | Фантомів розкрито | phantoms_revealed | 10 / 100 / 500 |
| F-31 | Летунів приземлено | flyers_grounded | 10 / 100 / 500 |
| F-32 | Барикади | barricades_broken | 30 / 250 / 1 500 |
| F-33 | Турелі | turrets_destroyed | 30 / 250 / 1 500 |
| F-34 | Жеоди (на мосту) | geodes_broken | 30 / 250 / 1 500 |
| F-35 | Рекрути | recruits | 200 / 2 000 / 10 000 |
| F-36 | Без втрат на шипах | levels_no_hazard_loss | 5 / 40 / 200 |
| F-37 | Сходи ×5 | stairs_reached_5 | 1 / 20 / 100 |
| F-38 | Фортеця за 8 с | fortress_fast | 5 / 40 / 200 |
| F-39 | Усі осколки зірки | levels_all_shards | 10 / 60 / 112 |
| F-40 | Ульти | ult_uses | 50 / 400 / 2 000 |
| F-41 | Апогеї | apex_uses | 10 / 100 / 600 |
| F-42 | Овердрайви | overdrive_uses | 5 / 50 / 300 |
| F-43 | Кодекс | codex_entries | 5 / 12 / 20 |
| F-44 | Міфічні машини | mythics_forged | 1 / 2 / 4 |
| F-45 | Боси світів | bosses_beaten | 3 / 7 / 14 |
| F-46 | Кошмари | nightmares_cleared | 1 / 4 / 7 |
| F-47 | Вторгнення | invasion_wins | 8 / 28 / 56 |
| F-48 | Походи 5/5 | expedition_full | 1 / 5 / 20 |
| F-49 | Слава героїв ◆ | glory_total | 4 / 8 / 12 |
| F-50 | Рівень героя | hero_max_level | 10 / 20 / 30 |
| F-51 | Казарми | barracks_levels | 10 / 30 / 50 |
| F-52 | Тактика | tactics_ranks | 3 / 10 / 18 |
| F-53 | Схованки | caches_opened | 25 / 200 / 1 000 |
| F-54 | Легендарні карти | legendary_cards | 3 / 20 / 100 |
| F-55 | Завдання | missions_done | 20 / 150 / 600 |
| F-56 | Тижні | weeklies_done | 2 / 10 / 40 |
| F-57 | Шлях | road_tiers | 10 / 60 / 120 |
| F-58 | Перемоги кожною родиною (3 машини однієї родини) | families_won_with | 2 / 4 / 6 |
| F-59 | Перемоги з Підкріпленням вимкненим після 3 поразок | comeback_no_assist | 1 / 5 / 20 |
| F-60 | Перемоги без машин | wins_no_machines | 1 / 5 / 20 |

### 8.6 Codex

Arsenal → Кодекс: 12 Evolutions + 8 Fusions; entries show the recipe after discovery and a family-pair hint before.
Completing all 20 → Feat F-43 tier 3 + Royal Cache.

---

## 9. IMPLEMENTATION PLAN (Godot 4.7, gl_compatibility, typed GDScript, etap1 §0 conventions)

State when written: etap1 stage 1 is in progress (`weapon_models.gd`, `effects.gd`, `juice.gd`, audio exist;
`scripts/run/weapons.gd`, `army.gd`, `hazards.gd` do not yet; `Balance` is still the lane-runner version; the in-run HUD
lives in `scripts/ui/hud_view.gd`). Meta work starts with data and rules that do not touch run files and plugs into
`Weapons` when etap1 stage 2 lands. `Worlds.LEVELS_PER_WORLD` becomes **8**; `Worlds.ORDER` gains reef, mystic, volcano,
ice, sky, rift as their roads arrive (fallback: space road with a world tint).

### 9.1 Data (GDScript const files, `class_name`, no runtime parsing; exported to JSON for the sim)

`scripts/core/arsenal_data.gd` — `class_name ArsenalData`:
```
const RARITIES := {"C": {"name": "RAR_COMMON", "ui_color": Color("#D6DEE6"), "pips": 1, "start": 1, "gem": "round"}, ... "M": {...}}
const FAMILIES := {"kinetic": {"name": "FAM_KINETIC", "accent": Color("#D9B8A6"), "glyph": "chevron", "status": "stagger",
                   "projectile": "bolt", "overlay": "", "set2": {"structures_add": 0.15}, "set3": {"pierce": 1}}, ...}
const STATUSES := {"chill": {"stacks_per_hit": "proc", "max_stacks": 3, "decay_s": 1.5, "slow": 0.10, "freeze_s": 1.0,
                   "immune_s": 1.0, "resist_max_stacks": 5, "resist_slow": 0.05}, ...}             # §2.1 table
const REACTIONS := {"superconduct": {"a": "jolt", "b": "chill", "vs": 2.0}, "thermal_shock": {...}, "flare": {...}}
const PROPERTIES := {"swarm": {"world": 2, "unit_value": 0.5, "dmg_kills": 2, "icon": "swarm", "raider": "small"}, ...}  # §2.4
const MACHINES := {
  "railgun": {"name": "M_RAILGUN", "desc": "M_RAILGUN_DESC", "rarity": "E", "family": "volt", "verb": "lane",
    "shape": "rail", "home": 2, "mount": "chassis_volt", "crew": true,
    "flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": true},
    "base": {"damage": 18, "charge": 3.0, "telegraph": 0.4, "pierce": 99, "range": 22.0, "structures": 2.0, "proc": 1.0},
    "move": {},                                                    # speeds/offsets: ram {"out": 14, "back": 10, "reach": 6}, sentinel {"speed_add": 1.0, "ahead": 4}, ...
    "primary": {"stat": "damage", "per_level": 0.08},
    "ranks": [{}, {"charge": 2.4}, {"lane_jolt_s": 2.0}],
    "talent3": [{"id": "overcap", ...}, {"id": "rapid_rails", ...}],
    "ascension": {"a": {"id": "breacher", "mods": {"boss_vs": 3.0}, "asset": "railgun_a"}, "b": {...}},
    "apex": {"id": "rail_barrage", "shots": 3},
    "recipes": ["E10", "F3"],
    "sim": {"dps": 6.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 2.0, "gate_gain": 0.0},
    "vfx": {"kind": "rail_beam", "width": 0.3, "length": 22.0, "lifetime": 0.25, "particles_max": 30, "telegraph": "rails"},
    "sfx": ["rail_charge", "rail_crack", "pierce_ring"]},
  ... 24 entries (§2.5) }
const FIT := {"railgun": {"fit": AABB(Vector3(-0.45, 0, -0.9), Vector3(0.9, 0.7, 1.8)), "deck_y": 0.42,
              "yaw_pivot": Vector3(0, 0.42, 0), "muzzle": Vector3(0, 0.55, -0.95), "forward_deg": 180.0,
              "parts": {}}, ...}                                   # measured in gallery_weapons.gd (§10.3)
const FAMILY_TALENTS := {...}; const EVOLUTIONS := {"E1": {"machine": "ballista", "catalyst": {"gate": "multi"}, "into": {...}}, ...}
const FUSIONS := {"F1": {"a": "tesla", "b": "cryo", "into": {...}}, ...}
const ARMY_TIERS := [...]  # §2.7, unlock by world
const NEW_CRATES := {1: {2: "ballista", 3: "cannon", 5: "rockets", 6: "mortar"}, 2: {1: "gatling", 3: "laser", 5: "railgun"}, ...}
const INRUN_BUDGET := {"crates": [[1, 1, 0], [2, 10, 2], [11, 30, 2], [31, 999, 4]], "boss_extra": 1,
                       "rank_gates": [[11, 999, 1]], "pairs_from": 5}
const MAX_FIELDED := 3; const MAX_EVOLVED := 2; const RANK_MULT := [1.0, 1.5, 2.1]; const OVERFLOW := [0.10, 0.07, 0.05, 0.03]
const DUP_SHARE_AT_2 := 0.5; const RECIPE_WEIGHT := 3.0; const CRATE_BONUS_HP := 0.6
const RARITY_PICK_W := {"C": 1.0, "R": 0.8, "E": 0.6, "L": 0.45, "M": 0.35}
```
`Balance.WEAPONS` (etap1) stays as the Rank I/Lv1 base for the 5 original kinds; `MACHINES[k].base` must match it (test)
until `Balance.WEAPONS` is deleted in Meta-2.

`scripts/core/econ_data.gd` — `class_name EconData`: `COIN_TO`, `BP_TO`, `START_LEVEL`, `SYNC_CAP`, `hero_cost(L)`,
`barracks_cost(L)`, `BARRACKS`, `TACTICS` (+ prices), `HAVEN_COST`, `HAVEN_PASSIVES`, `HAVEN_FEATURED`, `CROWN_ARMY`
(baked), `CACHES`, `CARD_ODDS`, `STACK`, `PITY`, `WILD_CARD_CHANCE`, `DECK_WEIGHT`, `FOCUS_SHARE`, `DRIP`, `MASTERY_XP`,
`FINISHES`, `LOGIN_CYCLE`, `MISSION_POOL`, `WEEKLY`, `FEATS`, `TRACK`, `ROAD`, `victory_coins()`, `loss_coins()`,
`REPLAY`, `INVASION`, `RETRY_ASSIST`, `AD_RULES`, `SKUS`, `WORLD_SET_CAP`, `UNLOCKS`.
`tools/export_econ.gd` (`godot --headless --script`) writes `build/econ.json`; `tools/economy_sim.py` (port of the
scratchpad sim) loads it, so the sim always tests the shipped numbers.

### 9.2 Save schema v2 (`scripts/autoload/save.gd`, ConfigFile, atomic write + .bak)

```
[meta]        version=2, rng_state:int (cache RNG; advanced and saved BEFORE any reveal animation), sessions:int, last_session:int
[progress]    level, crowns_best {level -> 0..3}, shards_best {level -> bitmask}, invasion_level, invasion_crowns {n -> 0..3},
              nightmare {world -> cleared}, world_reached, boss_wins
[wallet]      coins, gems, crowns, cores, wild {C,R,E,L,M}
[arsenal]     machines {id -> {lvl, bp, frac, xp, talents [i,i,i] (-1 = unchosen), branch "", finish, finishes bitmask, apex_auto}},
              decks [[ids x6] x3], deck_active, focus, codex {E1: true, ...}, seen {id: true}, mythics_forged []
[heroes]      bolt {lvl, glory, boss_wins, aspect, skin}, titan {...}, seer {...}
[barracks]    recruits, reserves, scrape_guard, drill, volleys, tactics {node -> rank}, skins {tier -> skin}
[haven]       stages {world -> 0..5}, featured {world -> [picked ids]}
[pity]        since_epic, since_leg, leg_welcome_done
[vault]       caches [{type, source, level}]
[daily]       login_idx, last_day "YYYY-MM-DD", missions [{id, progress, done, claimed}], banked, weekly [...], reroll_day
[track]       rating_claimed, road {chapter, xp, claimed_free [], claimed_premium []}
[expedition]  week "YYYY-Www", best, cur_level, army, machines {id: rank}, evolved [], reward_claimed {3: bool, 5: bool}
[counters]    every Run.result.stats key summed (missions and feats read these)
[feats]       {id -> tier}
[unlocks]     done [ids], pending [ids]
[shop]        entitlements {sku: purchase_token}, last_verified_day, parental_lock, ad_consent
[telemetry]   per level {attempts, wins, losses_before_quit}, session_lengths [], skips {ceremony: n}   # local only
[settings]    music, sfx, language, quality, vibration, reduce_motion, fast_ceremonies, quick_reveal, caches_to_vault,
              auto_apex, reinforcements
```
**Migration v1 → v2** (in `load_data`, when `meta/version` is missing):
- `progress.level` keeps its number (v1 had 5 levels per world in one world; v2 counts the same levels on 8-per-world maps).
- Grant every NEW machine whose crate level < `level` (the crates are behind the player) and one Boss Core per 8th level
  passed; `boss_wins` and Glory accordingly (all on the hero last used).
- `upgrades.army = n` → `barracks.recruits = min(10, n)`, and any amount above the cap of the reached world is kept as a
  grandfathered "+n bonus" (shown, never removed). `upgrades.power = m` → refund `Σ upgrade_cost("power", 0..m−1)` coins.
- `crowns_best = 1` for cleared levels; one-time card "Твої покращення переїхали в Казарми й Героїв".
- The UnlockQueue replays every unlock with level < `level` as a catch-up tour, at most 2 per session.

### 9.3 Rules (pure and testable; the UI never mutates Save directly)

- Autoload **`Meta`** (`scripts/autoload/meta.gd`, after Save): signals `wallet_changed(cur, value)`, `machine_changed(id)`,
  `hero_changed(id)`, `unlocked(kind, id)`, `cache_added(type)`; `run_profile(level)`, `finish_run(result) -> Dictionary`
  (calls `Rewards.level_end`, saves once). `main.gd`'s `finished` handler calls `Meta.finish_run(run.result)` instead of
  `Save.add_coins` / `level_won`.
- `scripts/meta/arsenal.gd` (`class_name Arsenal`): `can_upgrade`, `upgrade`, `cost` (incl. Wild use), `set_talent`,
  `set_branch`, `set_finish`, `set_focus`, `unlock(id, source)` (Arsenal Sync), `forge_mythic`, `rating`, `next_milestone`,
  `remaining_cost`, `deck/set_deck/auto_deck(threats)`, `stats(id, rank := 1)` (final numbers for UI and Run, the §2.1
  formula), `best_upgrade()` (the sim's greedy value function).
- `scripts/meta/cache_roller.gd` (`CacheRoller.roll(type, pool, owned, pity, rng) -> {cards, best, pity_after, coins}`).
- `scripts/meta/rewards.gd` (`Rewards.level_end(result)`): coins (win/loss/replay/Invasion), Crowns (improvement only),
  Cache or charge, drip, Mastery XP, NEW unlock, Boss Core, Codex, counters, missions, feats; returns the bundle for the
  result flow.
- `heroes_meta.gd`, `barracks.gd` (incl. Tactics), `haven.gd`, `missions.gd`, `track.gd`, `road.gd`, `expedition.gd`,
  `calendar.gd`, `unlock_queue.gd`, `shop.gd` (entitlements, `IAP_ENABLED`), `ads.gd` (cap, consent, offline), `telemetry.gd`.

### 9.4 How runs read the account and what they report

`Meta.run_profile(level)` (built once in `Run.setup`):
```
{ "deck": ["railgun", "tesla", ...], "lead": "railgun",
  "machines": {"railgun": Arsenal.stats("railgun"), ...},          # Lv, talents, branch, finish baked in
  "hero": {"id": "bolt", "lvl": 14, "aspect": "railshot", "glory": 3, "ult_rank": 2, "dmg_mult": 1.455, "hp_mult": 1.52},
  "army": {"recruit_bonus": 3, "reserves": 12, "scrape_guard": 4, "drill": 0.15, "volley_mult": 1.36, "max_tier": 4,
           "glory_reserves": 3},
  "tactics": {"crate_bonus_mult": 0.8, "weak_point": 0.3, "streak_every": 6, "lead_add": 0.08, "ult_start": 0.10},
  "assist": {"stacks": 2},                                         # Reinforcements: +4 soldiers, +10% (bucket 2)
  "haven_info": ["shard_glint_25", "rank_label_40", ...],          # information passives
  "codex": {...}, "auto_apex": false }
```
- `Weapons` (etap1 `scripts/run/weapons.gd`) takes stats from `profile.machines`, ranks via `RANK_MULT`; statuses in
  `scripts/run/statuses.gd` (per-squad dict `status: {chill: stacks, burn: t, mark: t, jolt: stacks, seal: t}`); reactions
  there too; Evolution/Fusion checks in `scripts/run/evolutions.gd` (listens to `weapon_added`, gate taken, rank changes) and
  spawns EVOLVE/FUSE gates via `Run.inject_gate(row_d, gate)`.
- Crates and gates: LevelGen places `crate` (`weapon: "deck"`, `pair`), `gate` with op `rank`/`catalyst` (+ fallbacks),
  `squad.props`, `echo_pockets`; `crate_picker.gd` resolves at 30 u. Bot and LevelSim read resolved runtime items.
- The **EXPECTED profile** for level L = the sim's regular player at L with every layer (machine levels and deck, hero
  level + Aspect + Glory, all Barracks tracks, Tactics, Haven info passives), written per level by `tools/economy_sim.py --export-expected`
  to `build/expected_profile.json`, which `level_check` and `tools/bake_crowns.gd` read.
- `LevelSim.simulate(..., profile)` uses each machine's `sim` abstraction; `level_check --profile=fresh|expected|max`:
  the best path must win with FRESH on L1–8 and with EXPECTED everywhere; the lazy path must lose or win by a clearly
  smaller margin; and with EXPECTED, L1–20 must keep "the best gate depends on the army" (forecast check). Never pass
  account power into LevelGen.
- **`Run.result`** gains `crowns` (0–3), `shards` (bitmask), `fielded [{id, rank, kills, evolved, fused}]`,
  `discoveries [E3, F1]`, `new_unlock`, `boss_core`, `bridge_fraction`, and **`stats`** with fixed keys:
  `wins, kills_total, kills_by_machine {id}, kills_by_family {f}, crates_opened, crate_bonus, rank_gates, catalyst_gates,
  rank3_reached, evolutions, fusions, evolutions_ids [], fusions_ids [], gates_by_op {good, bad, x, charge_flipped, arm,
  power, rank, catalyst, evolve}, statuses {freeze, burn, mark, stun, jolt, seal}, reactions {superconduct, thermal_shock,
  flare}, reactions_total, blades_frozen, lava_quenched, phantoms_revealed, flyers_grounded, barricades_broken,
  turrets_destroyed, geodes_broken, recruits, tiles, hazard_losses, clash_losses, levels_no_hazard_loss, star_shards,
  levels_all_shards, ult_uses, apex_uses, overdrive_uses, fortress_time, fortress_fast, army_peak, army_at_fortress,
  survivors, stairs_mult, stairs_reached_3, stairs_reached_5, crowns_gained, invasion_wins, wins_family3,
  wins_no_machines, wins_with_lead {id}`. `MISSION_POOL` and `FEATS` reference only these keys (test).
- New signals: `apex_ready(kind)`, `apex_fired(kind)`, `evolved(kind, id)`, `fused(a, b, id)`, `crate_resolved(item)`.

### 9.5 New scenes and scripts

| Area | Files |
|---|---|
| Hub shell | `scripts/ui/hub/hub.gd` (`Hub`, replaces `Menu`; `main.gd.show_menu()` → Hub), `hub_showcase.gd`, `tab_bar.gd`, `top_bar.gd`, `side_rail.gd` |
| Tabs | `tab_play.gd` (world map), `haven_view.gd`, `tab_arsenal.gd`, `machine_card.gd`, `machine_detail.gd`, `machine_demo.gd` (sandbox SubViewport), `deck_editor.gd`, `codex_view.gd`, `rift_anvil_view.gd`, `tab_heroes.gd`, `feats_view.gd`, `tab_barracks.gd`, `tab_shop.gd`, `missions_panel.gd`, `track_panel.gd`, `road_panel.gd`, `expedition_view.gd`, `vault_view.gd`, `loss_screen.gd`, `settings_panel.gd`, `changelog_view.gd` |
| FX | `scripts/ui/fx/ui_tokens.gd`, `ui_juice.gd`, `reward_fly.gd`, `ceremony.gd`, `odometer.gd` |
| Result | `scripts/ui/result_flow.gd` (moves `show_result` out of `hud_view.gd`) |
| In-run HUD | `scripts/ui/hud_view.gd` (machine column, trait strip, Apex dots), `scripts/ui/forecast_label.gd` (shared) |
| Altar | `scripts/altar/cache_altar.gd`, `altar_card.gd`, `scripts/core/cache_models.gd` (procedural fallback caches, altar) |
| Haptics | `scripts/autoload/haptics.gd`: Android API 30+ `VibrationEffect.startComposition().addPrimitive(...)` through `JavaClassWrapper` with the Activity from `Engine.get_singleton("AndroidRuntime").getActivity()` (Godot 4.4+), guarded by `Vibrator.arePrimitivesSupported`; fallback `Input.vibrate_handheld(12–20 ms, 0.3–0.6)`; ≥ 50 ms between pulses; respects Settings. `Juice.haptic()` delegates here. |
| Shaders | `finish.gdshader` (tier 0–6 using `<id>_mask.png`), `opal.gdshader`, `rarity_beam.gdshader`, `card_back.gdshader`, `cache_crack.gdshader`, `aura.gdshader` (evolution), `phantom_dither.gdshader`, `shield_hex.gdshader`, `telegraph_ring.gdshader` (dashed hollow ring with chevrons) — no sin-hash noise, TIME wrapped |
| Thumbnails | `scripts/ui/thumb_cache.gd`: first launch renders machine × finish into `user://thumbs/` (≈ 0.3 s each, behind the title); dev sheets with `tools/render_thumbs.gd` under `xvfb-run -a godot --rendering-driver opengl3 --path . --script tools/render_thumbs.gd` (like `rshot.sh`) |
| Loc | keys `M_<ID>`, `M_<ID>_DESC`, `TAL_<ID>`, `ASC_<ID>`, `APX_<ID>`, `EVO_<ID>`, `FUS_<ID>`, `FAM_*`, `RAR_*`, `ST_*`, `RX_*`, `PROP_*`, `CACHE_*`, `CUR_*`, `TAB_*`, `BAR_*`, `TAC_*`, `HAV_*`, `MIS_*`, `FEAT_*`, `ODDS_*`, `PITY_*`, `UNL_*`, `SKU_*` (uk first, en second; §11) |

### 9.6 Workstreams (parallel, disjoint file ownership)

| WS | Owner files | Depends on | Delivers |
|---|---|---|---|
| **WS0 Contracts** (≈ 1 day, first) | `arsenal_data.gd`, `econ_data.gd` skeletons (all keys; real numbers for Meta-1), `autoload/meta.gd` stubs, Save v2 doc-comment, glossary + `tools/loc_lint.py` | this doc | frozen interfaces |
| **WS1 Meta core** | `autoload/save.gd` (v2 + migration), `autoload/meta.gd`, `scripts/meta/*`, `tools/export_econ.gd`, `tools/economy_sim.py`, `tools/odds_table.gd`, `tools/bake_crowns.gd`, `scripts/dev/test_meta.gd` | WS0 | rules, roller, rewards, unlock queue, tests, sim |
| **WS2 Run integration** | `run/weapons.gd` (after etap1), `run/statuses.gd`, `run/evolutions.gd`, `run/crate_picker.gd`, `run/hazards.gd` property hooks, crate/gate/props/echo fields in `run/level_gen.gd` (with the LEVELS owner), `run/level_sim.gd` + `dev/bot.gd` profile and `sim` abstraction | WS0, etap1 stage 2 | 24 behaviours, statuses, reactions, properties, recipes, budget |
| **WS2b Hero & army hooks** | `run/run_hero.gd` (Aspects, Overdrive, ult ranks, Awakening look), `run/army.gd` (Armory T3–T5, Recruits bonus, Reserves at the siege, Scrape Guard, Drill, Reinforcements) | WS0, etap1 stage 2 | hero and army meta in the run |
| **WS3 Models, VFX, audio assets** | `core/weapon_models.gd` (family chassis + module + crew assembly, `FIT`, 24 procedural fallbacks, rank attachments), `core/cache_models.gd`, `core/effects.gd` (≈ 20 new kinds, telegraph grammar, budgets), shaders, `scripts/dev/gallery_fx.gd`, `scripts/dev/gallery_weapons.gd` (FIT overlay), `tools/palette_check.py`, `tools/prepare_model.mjs --mask`, `tools/gen_sfx.py` machine sounds | WS0 | every machine visible and audible before Meshy assets exist |
| **WS4 Hub UI + in-run HUD** | `ui/hub/*`, `ui/fx/*`, `ui/hud_view.gd`, `ui/icons.gd` (24 machines + 20 evolved forms + family, status, property, currency, tab icons), `ui/forecast_label.gd`, `autoload/haptics.gd`, `autoload/loc.gd` (sole owner; others send key lists), `ui/ui_kit.gd` | WS0, WS1 | tabs, flows, ceremonies, RewardFly, HUD |
| **WS5 Altar & result** | `altar/*`, `ui/result_flow.gd`, `ui/loss_screen.gd`, `main.gd` finished handler (→ `Meta.finish_run`), Altar stingers (with the audio owner) | WS1, WS3 | Cache reveal, result and loss flows |
| **WS6 Liveops-lite + store** | `meta/missions.gd`, `track.gd`, `road.gd`, `expedition.gd`, `calendar.gd`, `shop.gd`, `ads.gd`, `ui/hub/tab_shop.gd`, panels; GodotGooglePlayBilling plugin, AdMob + UMP plugin, export presets | WS1 | missions, login, Track, Road, Expedition, Shop, billing, ads |

### 9.7 Phases

- **Meta-1 "luxe slice" (≈ 3 weeks)**: 9 machines at full bar — W1–W2 (Drone, Ballista, Cannon, Rockets, Mortar,
  Gatling, Laser, Railgun) + Prism so the whole rarity ladder (C/R/E/L) and the Legendary walkout exist. Exit criterion per
  machine: family chassis or full model, crew, moving parts, Rank II/III models, Ascension look, per-machine sounds and
  Rank layers, docking, in-run finish layers 1–3, VFX within budget, sheet numbers verified by the bot. Also: statuses
  (no reactions or sets), Talents I/II (both options), Lead, Deck (3), NEW crates, pairs, BONUS segment, RANK gates,
  forecast labels, Stone + World Caches + Altar + odds + pity + Vault, Wild Blueprints, Focus, hero levels, Barracks
  (all 5 tracks), Reinforcements, loss payout, result and loss flows, RewardFly, Haptics, Save v2 + migration,
  UnlockQueue up to L16, local telemetry.
- **Meta-2**: the other 11 non-Mythic machines (each to the Meta-1 bar), reactions + set bonuses, catalyst and EVOLVE/FUSE
  gates + Codex, Ascension branches, Talent III, Tactics, Haven + Crowns + Citadel, Armory T3–T5, Aspects + Glory, Mastery
  finishes 4–6, enemy properties (each with its world), missions + login.
- **Meta-3**: Mythics + Rift Anvil (**hard dependency: plan2 world bosses**; interim: every 8th fortress drops the core),
  Apex, Royal Caches, Arsenal Track, Road, Expedition, Invasion + Nightmare, Shop + Billing + Ads, Feats, X-Ray Caches.

Each phase ends with `tools/check_all.sh`, bot runs per world, screenshot QA of every screen (`rshot.sh`, gallery sheets),
ceremonies tuned by 50 ms frame captures.

### 9.8 Tests, tools, telemetry, changelog

- **`tools/check_all.sh`** (local CI; no hosted CI exists): `godot --headless --path . --import` → `test_meta.gd` →
  `python3 tools/economy_sim.py --quick` (exit 1 on any invariant) → `level_check --from=1 --to=56 --profile=expected` →
  `python3 tools/palette_check.py` → `godot --headless --script tools/odds_table.gd --check` (fails if the (i) table
  drifts) → `python3 tools/loc_lint.py`.
- **`test_meta.gd`**: roller odds by chi-square per rarity over 1 000 000 rolls (|z| ≤ 4 per rarity) for every pool state;
  pity caps (Epic gap ≤ 8, Legendary gap ≤ 30), welcome Legendary, frozen counters; duplicate protection; crate picker
  budget (port of `inrun_level`, bands of §3.2 within ±5 pp of the sim); every world's property has an answer among its
  unlocks; every `MACHINES` entry has `flags`, `sim`, `vfx`, `sfx`, `FIT` and Loc keys; missions and feats use known stats
  keys; no paid item changes rating/Track/pity/Caches; migration fixtures (v1 saves at levels 1, 9, 30).
- **Balance gate** (forced-deck experiments, bot, EXPECTED profile): for each machine M, decks {M + 2 baseline machines}
  vs baseline over 200 seeds per world; flag > +15% win delta as overpowered, < −10% as dead. Any world where the lazy path
  wins with a similar margin is flagged empty (plan2 rule).
- **Local telemetry** (`telemetry.gd`, never sent anywhere): attempts per level, wins, losses before quitting a session,
  session lengths, ceremony skips; a debug screen (7 taps on the version label) exports `user://telemetry.json` so the
  owner can replace the sim's win-chance sigmoid with real data.
- **Changelog screen** (Settings → "Що нового"): per-version notes; when odds or pity change, a single card appears once
  on the next hub visit (never on a reveal) and the (i) screen marks the changed rows for that version.

---

## 10. ART PIPELINE — Meshy (image prompt → 3D), import, budget

### 10.1 Rules

1. Generate each **family chassis first** (Appendix A, A-01…A-07) and use its render as the **style reference image** for
   every module of that family.
2. Prompts describe **solid parts only**. Every energy element (strings, arcs, beams, shields, flames, sparkles, ripples)
   is a Godot shader or VFX. Every prompt ends with: "no glow, no energy beams, no particles, no floating parts, all parts
   physically connected", and modules add "flat circular mounting base at the bottom".
3. The run camera sees machines from high behind: prompts ask for "readable from above and behind, key shapes on top,
   detailed back, three-quarter rear top-down view".
4. Team signature = white enamel with **thin** gold trim; the family line sets the accent and materials (v1's shared
   "ice-blue crystals" are gone, so families differ and gold stays rare).
5. Moving parts are separate small models (listed per machine, "part" prompts) or procedural; Evolutions add no mesh;
   Fusions use the double-wide chassis A-07; Common/Rare Ascensions are shader + VFX only (v1's 12 attachments dropped).

### 10.2 Asset list by phase (counts printed by the sim's manifest)

| Phase | Assets | Meshy generations (×3 attempts) |
|---|---|---|
| P0 / Meta-1 | 4 family chassis (Kinetic, Plasma, Tech, Volt), 9 machines, 4 moving parts, 3 Caches + Altar + pedestal, 4 currency props, NEW crate, crew operator = **28** | ≈ 84 |
| P1 / Meta-2 | 2 chassis (Frost, Rune), 11 machines, 3 moving parts, 16 E/L branches, Fusion chassis, 14 Haven dioramas, 3 soldier tiers, 2 raider variants = **52** | ≈ 156 |
| P2 / Meta-3 | Rift chassis, 4 Mythics, 1 moving part, 8 Mythic branches, Boss Core + Rift Anvil, X-Ray Cache, Citadel ×2, hero Seer = **20** | ≈ 60 |
| Total | **100** | **≈ 300** |

Credit estimate: multiply the generations by the per-generation price shown in Meshy for image→3D with texture at the time
of generation (the price changes; task #6 is already blocked on credits, so P0 is ordered by gameplay value: chassis →
W1 machines → Caches/Altar → W2 machines → props). Procedural fallbacks keep every phase shippable without assets.

### 10.3 Import data (`ArsenalData.FIT`, measured in `gallery_weapons.gd`)

`FIT[id] = {fit: AABB, deck_y, yaw_pivot: Vector3, muzzle: Vector3, forward_deg, parts: {name: {node, pivot, axis}}}`.
Machines face **−Z** (the run direction; `weapon_models.gd` already places the muzzle at −Z); `forward_deg` rotates a GLB
that Meshy delivered facing another way. `WeaponModels.asset()` stops fitting one fixed AABB with a hard-coded muzzle:
it reads `FIT`. The gallery draws the muzzle (red cross), yaw pivot (blue) and part pivots/axes (yellow arrows) for QA.
Test: every model key has a `FIT` entry. Etap1's "+Z towards the camera" applies to road items, not machines.

### 10.4 `prepare_model.mjs` and textures

- `--mask` mode derives `<id>_mask.png` from the albedo: R = gold (hue 35–55°, s > 0.4, v > 0.5), G = the family accent
  (family hue ± 20°), B = white enamel (s < 0.15, v > 0.75). `finish.gdshader` uses R for gold trim (matcap metal), G for
  inlays and veins, B for the clean body. Metal/roughness stays dropped (toy shading), the mask replaces it.
- Texture sizes: **512** for modules, parts, props and currencies; **1024** for heroes, chassis and Haven dioramas;
  import as ETC2/ASTC (VRAM compressed). Triangles: modules ≈ 6k, chassis ≈ 8k, free models ≈ 10k, dioramas ≈ 17k.
- **APK budget ≤ 80 MB** (current arm64 APK ≈ 30 MB): ~100 GLBs at 512–1024 ≈ 30–40 MB; if over, Haven dioramas move to a
  Play Asset Delivery install-time pack. Thumbnails are rendered at first launch, not shipped.

---

## 11. Localisation (uk first, en second; `Loc` sole owner WS4)

Key schema in §9.5. Draft copy for the core names (the rest is in the tables above: machine names §2.3, Talent III and
Apex names §2.5, passives §4.3, missions §8.1, feats §8.5, unlock lines §4.6):

| Key | uk | en |
|---|---|---|
| TAB_SHOP / TAB_ARSENAL / TAB_PLAY / TAB_HEROES / TAB_BARRACKS | Магазин / Арсенал / ГРА / Герої / Казарми | Shop / Arsenal / PLAY / Heroes / Barracks |
| CUR_COINS / CUR_GEMS / CUR_CROWNS / CUR_BP / CUR_WILD / CUR_CORE | Монети / Самоцвіти / Корони / Креслення / Дикі креслення / Ядро боса | Coins / Gems / Crowns / Blueprints / Wild Blueprints / Boss Core |
| RAR_COMMON…RAR_MYTHIC | Звичайна / Рідкісна / Епічна / Легендарна / Міфічна | Common / Rare / Epic / Legendary / Mythic |
| FAM_KINETIC…FAM_RIFT | Кінетика / Вольт / Мороз / Плазма / Техно / Руна / Розлом | Kinetic / Volt / Frost / Plasma / Tech / Rune / Rift |
| ST_STAGGER…ST_SEAL | Відкидання / Розряд / Холод / Опік / Мітка / Печать | Stagger / Jolt / Chill / Burn / Mark / Seal |
| RX_SUPERCONDUCT / RX_THERMAL / RX_FLARE | Надпровідність! / Термошок! / Спалах! | Superconduct! / Thermal Shock! / Flare! |
| PROP_SWARM…PROP_FLYING | Рій / Фантом / Броня / Щит / Морозостійкі / Летуни | Swarm / Phantom / Armored / Shielded / Chill-resistant / Flying |
| CACHE_STONE / CACHE_WORLD / CACHE_ROYAL / CACHE_XRAY | Кам'яна схованка / Світова схованка / Королівська схованка / Прозора схованка | Stone Cache / World Cache / Royal Cache / X-Ray Cache |
| RANK_UP | Ранг %s! | Rank %s! |
| GATE_RANK / GATE_CATALYST / GATE_EVOLVE / GATE_FUSE | Ранг / Каталізатор / Еволюція / Злиття | Rank / Catalyst / Evolve / Fuse |
| CRATE_NEW / CRATE_BONUS | НОВА / Бонус! | NEW / Bonus! |
| APEX_READY | Апогей готовий | Apex ready |
| ASSIST_CHIP | Підкріплення +%d%% | Reinforcements +%d%% |
| PITY_LEG | Легендарна гарантовано ≤ %d | Legendary guaranteed in ≤ %d |
| PITY_LEG_LOCKED | Легендарні з'являються у Світі 3 | Legendaries appear in World 3 |
| ODDS_TITLE | Шанси і гарантії | Odds and guarantees |
| BEST_UPGRADE | Найкраще покращення | Best upgrade |
| LOSS_PROGRESS | Пройдено %d%% мосту | %d%% of the bridge covered |
| RETRY / NEXT / LATER / DONE | Ще раз / Далі / Пізніше / Готово | Retry / Next / Later / Done |
| VAULT_EMPTY | Схованок немає. Перемоги приносять кам'яні схованки. | No caches. Wins bring Stone Caches. |
| NO_RANDOM | Без випадковостей: усе, що бачиш, — твоє | No randomness: what you see is what you get |
| RESTORE | Відновити покупки | Restore purchases |
| EVO_E1…EVO_E12 | Буря болтів / Вулкан / Судний залп / Залізний джаґернаут / Штормовий шпиль / Спектр / Командний зв'язок / Абсолютний нуль / Золота паща / Зоряний спис / Наднова / Резонанс | Bolt Storm / Vulcan / Doom Barrage / Ironclad Juggernaut / Storm Spire / Spectrum / Command Link / Absolute Zero / Golden Maw / Star Lance / Supernova Array / Resonance |
| FUS_F1…FUS_F8 | Хуртовинна котушка / Магмова мортира / Сонцелам / Боєвий яструб / Бомба-сингулярність / Залізний авангард / Штормовий бастіон / Двигун Мідаса | Blizzard Coil / Magma Mortar / Sunbreaker / Warhawk / Singularity Bomb / Iron Vanguard / Storm Bulwark / Midas Engine |

Ukrainian plurals use `Loc.plural(n, one, few, many)`; numbers use a thin space for thousands ("12 400").

---

## 12. Risks and owner decisions

- **Scope**: 24 machines × behaviours, VFX, sounds and art is the bulk of the work. Meta-1 ships 9 machines at the full
  luxe bar; later machines join only at that bar (each is one data entry + one behaviour + one module + its sounds).
- **Readability with 3 machines + statuses + properties**: budgets and the priority ladder (§2.8) are the contract; the
  gallery sheet on all 7 road palettes with CVD filters is a ship gate per phase; validate on a low-end phone later.
- **Design load**: 24 Talent III pairs + 24 Ascension branches (16 E/L + 8 Mythic) are hand-designed; Talent I/II are
  family templates.
- **Model truth**: the economy sim is a model; replace the win-chance sigmoid and `demand()` with bot data and local
  telemetry once Meta-1 runs. The in-run budget's player-choice rates (pairs, RANK gates, catalysts) must be measured.
- **Dependencies**: plan2 world bosses (Boss Cores, Meta-3), captains (captain chests), the Shrine (machine cards). The
  Arsenal works without them (interim rules in §2.5, §3.3, §3.6).
- **Owner decisions needed**: (1) Mythics only via Boss Cores (recommended); (2) whether X-Ray Caches ship in v1;
  (3) Seer timing (recommended: World 3 boss reward); (4) prices of the six SKU types in §6.6; (5) whether to add
  consumable gem packs later (only with cloud save, e.g. Play Games Saved Games).

---

## Appendix A — Meshy prompts (final, copy-paste; generated by `doc_parts/gen_prompts.py`)

Order inside a family: generate the chassis, then use its render as the style reference image for the module and its parts. "Separate moving part" models are imported as child nodes at the pivots listed in §2.5 and `ArsenalData.FIT`.

| id | Asset | Phase / notes | Prompt |
|---|---|---|---|
| A-01 | Kinetic chassis | P0; wheels re-made procedurally for spin | Compact siege wagon war cart chassis on four large spoked wooden wheels, flat empty top deck with a round mounting ring, a small seat and footboard at the back for one operator, reinforced front bumper with a bronze chevron crest. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-02 | Plasma chassis | P0 | Compact hover war cart chassis resting on four thick round hover pads attached under its corners, smooth flat empty top deck with a round mounting ring, a small operator step at the back, sleek armored nose with a magenta crystal crest. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-03 | Tech chassis | P0; legs auto-rigged like the heroes | Compact four-legged walker chassis with short sturdy mechanical legs and wide feet, flat empty top deck with a round mounting ring, an operator platform with a hand rail at the back, angular armor plates. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-04 | Volt chassis | P0 | Compact tracked war cart chassis on two short tank tracks, flat empty top deck with a round mounting ring, copper coil housings on both sides, an operator seat at the back, ceramic insulator studs along the edges. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-05 | Frost chassis | P1 | Compact sled war cart chassis on two curved steel runners, flat empty top deck with a round mounting ring, frosted glass side panels, an operator standing board at the back, a pointed prow with an ice-crystal ornament. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-06 | Rune chassis | P1 | Compact stone cart chassis on four solid carved stone wheels, flat empty top deck with a round mounting ring, rune-engraved side slabs, an operator seat carved into the back, an indigo enamel rune medallion on the front. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-07 | Rift chassis | P2 | Compact ceremonial altar cart chassis on four ornate gold wheels, white marble flat empty top deck with a round mounting ring, gold filigree railings, an operator step at the back, an opal crystal set into the front. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-08 | Drone | P0; rotors procedural | Small hovering four-rotor X-shaped combat drone, a single round lens eye, a small underslung gun, four empty round rotor hubs at the arm tips. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-09 | Ballista | P0; Kinetic chassis | Weapon module for a war cart: a giant crossbow ballista with wide recurved bow arms, a thick braided rope bowstring pulled tight, a long bolt with a bronze tip resting in the rail, two winch drums with gold caps at the back. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-10 | Plasma Cannon | P0; Plasma chassis | Weapon module for a war cart: a short heavy plasma cannon with a fat round flared muzzle, a hot pink crystal core visible through a ring window in the barrel, armored barrel bands, cooling fins along the top. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-11 | Rocket Pod | P0; Tech chassis | Weapon module for a war cart: a boxy rocket pod launcher with a two by three grid of round launch tubes, armor plates, lime painted rims on the tube mouths, a small radar dish fixed to the side. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-12 | Siege Mortar cradle | P0; Kinetic chassis | Weapon module for a war cart: a reinforced mortar cradle with two thick side cheeks and an axle between them, an empty socket where a tube will sit, a stack of three bronze-banded shells beside it. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-12p | Mortar tube (part) | P0; pivot = axle, axis X | Separate moving part for a war machine: a short fat siege mortar tube with bronze chevron bands and a flared mouth, a trunnion axle through its middle. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-13 | Gatling mount | P0; Kinetic chassis | Weapon module for a war cart: a gatling gun mount with a sturdy pivot base, a rear ammunition drum with a gold cap, two chunky handles, and an empty front bearing where a rotating barrel cluster will attach. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-13p | Gatling barrels (part) | P0; pivot = cluster centre, axis Z | Separate moving part for a war machine: a rotary cluster of six short gun barrels held together by two bronze rings, chunky and short. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-14 | Laser | P0; Plasma chassis | Weapon module for a war cart: a long slender laser cannon barrel with gold rings and hot pink crystal coils along it, an empty round collar at the muzzle where a lens dish will attach. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-14p | Laser lens dish (part) | P0; pivot = dish centre, axis Z | Separate moving part for a war machine: a round faceted crystal lens set in a thick black enamel dish with a gold rim. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-15 | Railgun | P0; Volt chassis | Weapon module for a war cart: a long railgun made of two parallel thick rails with a wide gap between them, solid copper braces joining the rails at each third of their length, a capacitor block with ceramic cells at the back. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-16 | Tesla Coil | P1; Volt chassis | Weapon module for a war cart: a tall copper Tesla coil tower with three black ceramic insulator rings, topped with an open copper cage sphere, small coil spikes around the base. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-17 | War Banner | P1; Rune chassis; flag cloth is procedural | Weapon module for a war cart: a tall war banner pole with a short stiff carved stone crossbar near the top, an indigo enamel rune finial on top, gold tassels hanging close against the pole, small shield plates around the base. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-18 | Prism | P0; free model | A tall faceted crystal prism with a hot pink-magenta tint, gold caps on its top and bottom points with short axle pins. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-18p | Prism gyro ring (part) | P0; pivot = prism centre, axes X then Y | Separate moving part for a war machine: an engraved gold gyroscope ring with four short inward clamps. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-19 | Cryo Sprayer | P1; Frost chassis | Weapon module for a war cart: a squat pressurized cryo tank with a wide flared nozzle, a frosted glass gauge, small ice-crystal ornaments around the muzzle, hoses wrapped tightly against the tank. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-20 | Frost Miner launcher | P1; Frost chassis | Weapon module for a war cart: a mine launcher with a short catapult arm, an empty axle bracket where a drum magazine will sit, a small rack of round mines with snowflake caps. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-20p | Frost Miner drum (part) | P1; pivot = drum axle, axis X | Separate moving part for a war machine: a drum magazine holding six round frost mines with snowflake-engraved caps in a steel frame. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-21 | Siege Ram | P1; Kinetic chassis | Weapon module for a war cart: a battering ram front: a heavy wedge-shaped armored ram with a huge pointed bronze spike head, reinforced side plates and thick rivets. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-22 | Harvester | P1; Rune chassis; funnel spin procedural | Weapon module for a war cart: a mechanical claw arm holding a wide funnel-shaped magnet, a small hopper full of gold coins, a rune-engraved stone counterweight. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-23 | Arc Fence | P1; Volt chassis | Weapon module for a war cart: two short spiked pylons standing on one shared base plate about a meter apart, each pylon with stacked ceramic insulator rings and a copper spike cap, a solid copper bar connecting their bases. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-24 | Aegis | P1; Frost chassis; dome is a shader | Weapon module for a war cart: a low round shield emitter with three tall frosted-glass fins standing upright, a ring of gold-capped vents around the base, a frosted dome cap in the middle. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-25 | Sentinel | P1; auto-rig + procedural walk | Small bipedal guardian mech with backward-bending legs, a single round visor, stubby twin arm cannons, a white enamel chest plate, standing in a neutral pose with both feet flat. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-26 | Gravity Well pylon | P1; Rune chassis; rings procedural | Weapon module for a war cart: a short rune-engraved stone pylon with three gold ring brackets fixed around an empty cradle on its top. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-26p | Gravity core (part) | P1; pivot = centre | Separate moving part for a war machine: a smooth black stone orb with thin violet crack lines. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-27 | Gate Tuner mount | P1; Volt chassis | Weapon module for a war cart: a dish mount with a sturdy yaw ring, two battery cells with ceramic tops, an empty bracket on top where a dish will attach. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-27p | Gate Tuner dish (part) | P1; pivot = bracket, yaw Y and pitch X | Separate moving part for a war machine: a satellite dish with a forked two-prong antenna at its centre and a copper rim. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-28 | Starfall Array | P2; Rift chassis; orbit ring procedural | Weapon module for a war cart: a tall slim antenna spire with stepped marble tiers, an opal crystal at the top held by gold prongs, gold filigree bands, a ring bracket halfway up. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-29 | Chrono Bell arch | P2; Rift chassis | Weapon module for a war cart: an ornate clockwork arch of white marble and gold gears, an opal crystal clock face at the top of the arch, an empty hook under the arch where a bell will hang. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-29p | Chrono bell (part) | P2; pivot = top loop, axis X | Separate moving part for a war machine: an ornate gold bell with engraved clock numerals, a heavy clapper and a top loop. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-30 | Phoenix Pyre | P2; Rift chassis; real flames are VFX | Weapon module for a war cart: a gold and marble anvil-shaped brazier bowl holding a large opal crystal heart, two stylized metal wings fixed to its sides, carved gold metal flame shapes around the heart. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-31 | Echo Reactor | P2; Rift chassis; rings procedural | Weapon module for a war cart: a reactor pedestal with a central opal crystal core in a gold cage and two fixed gold ring brackets on its sides. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-32 | Stone Cache | P0 | Stylized fantasy geode egg, fist-sized rough slate-grey stone with milky white quartz and small sapphire crystal points breaking through the top. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-33 | World Cache | P0 | Stylized geode egg of cracked black basalt with violet amethyst crystal clusters bursting from its seams, faint gold flecks. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-34 | Royal Cache | P0 | Ornate geode egg of polished black obsidian wrapped in engraved gold filigree bands, amber sunstone crystals erupting from the top like a crown. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-35 | X-Ray Cache | P2 | Pearlescent opal geode egg with a clear polished glass window on the front showing crystals inside, thin gold bands. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-36 | Altar | P0 | Circular reveal altar about one and a half meters wide, carved white stone pedestal with an engraved rune ring, four short amethyst pillars at the edge, a polished top platform with gold inlay, ancient temple style. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-37 | Showcase pedestal | P0 | Ornate circular display pedestal, polished dark navy stone base with gold filigree trim, a carved crystal ring inset around the top edge, short crystal shards rising at four points, empty flat top. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-38 | NEW crate | P0; rarity shells are material swaps | Supply capsule crate with a large round glass window on the front, platinum-white armored shell with silver ribs, a raised ribbon-shaped plate across the top, sturdy corner bumpers. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-39 | Boss Core | P2 | Fist-sized opal crystal heart caged in gold and white marble ribs. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-40 | Railgun A Breacher | P1 | Weapon module for a war cart: a massive railgun with two thick rails ending in a ram-shaped copper capacitor head, heavy braces, a large capacitor block at the back. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-41 | Railgun B Splitter | P1 | Weapon module for a war cart: a railgun with two rails ending in a three-pronged copper fork, ceramic insulators along the rails. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-42 | Prism A Lens of Ruin | P1 | A faceted crystal prism with a hot pink-magenta tint set inside a thick gold lens frame with engraved targeting marks, gold caps with axle pins. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-43 | Prism B Rainbow Prism | P1 | A cluster of three small faceted crystal prisms joined at their bases by a gold clasp. Materials: glossy black enamel armor with hot pink-magenta crystal accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-44 | Siege Ram A Juggernaut | P1 | Weapon module for a war cart: a wedge-shaped armored ram covered in short bronze spikes along its top, ending in a huge pointed spike head. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-45 | Siege Ram B Drill Ram | P1 | Weapon module for a war cart: a wedge-shaped armored ram ending in a large spiral bronze drill bit. Materials: dark walnut wood, riveted bronze plates and pale copper accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-46 | Arc Fence A Tesla Gate | P1 | Weapon module for a war cart: two spiked pylons on one base plate joined at the top by a solid copper arch shaped like a gate frame. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-47 | Arc Fence B Storm Net | P1 | Weapon module for a war cart: two spiked pylons on one base plate with a woven copper wire net stretched tight between them. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-48 | Aegis A Bastion Dome | P1 | Weapon module for a war cart: a wide double shield emitter with six tall frosted-glass fins standing in a ring. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-49 | Aegis B Mirror Dome | P1 | Weapon module for a war cart: a low shield emitter with a mirror-polished silver dome cap and three short fins. Materials: frosted glass panels and pale blue-white steel with snow-ivory accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-50 | Sentinel A Colossus | P1 | Heavy bipedal guardian mech with huge shoulder plates, thick stomping feet, a single round visor and twin arm cannons, standing in a neutral pose with both feet flat. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-51 | Sentinel B Guardian | P1 | Slim bipedal guardian mech holding a large tower shield with a lime painted emblem, a single round visor, standing in a neutral pose with both feet flat. Materials: graphite composite plates with lime-green painted light strips. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-52 | Gravity A Event Horizon | P1 | Weapon module for a war cart: a stone pylon holding a flat carved stone disc around an empty core cradle, gold ring brackets. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-53 | Gravity B Black Star | P1 | Weapon module for a war cart: a stone pylon holding a spiky black star-shaped stone core with four gold rings fixed around it. Materials: carved pale stone and deep indigo enamel with engraved rune grooves. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-54 | Gate Tuner A Flipper Array | P1 | Weapon module for a war cart: twin satellite dishes mounted back to back on one yaw ring, forked antennas at their centres. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-55 | Gate Tuner B Prospector Dish | P1 | Weapon module for a war cart: a satellite dish with a copper drill-shaped antenna and a bank of ceramic battery cells under it. Materials: polished copper coils and black ceramic insulators with pale orchid-violet accents. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-56 | Starfall A Meteor Choir | P2 | Weapon module for a war cart: an antenna spire with three smaller crystal spires around the main one, opal crystals held by gold prongs. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-57 | Starfall B Solar Spear | P2 | Weapon module for a war cart: a single tall spear-shaped spire with a long opal crystal blade on top and gold filigree bands. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-58 | Chrono A Stasis Bell | P2 | Weapon module for a war cart: an ornate marble and gold clockwork arch holding a heavy closed bell with a gold lock plate. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-59 | Chrono B Haste Bell | P2 | Weapon module for a war cart: an ornate marble and gold clockwork arch holding a pair of small bells with gold wing ornaments. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-60 | Phoenix A Sunpyre | P2 | Weapon module for a war cart: a large gold brazier bowl with carved gold sun-ray flame shapes around an opal crystal heart. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-61 | Phoenix B Ashen Host | P2 | Weapon module for a war cart: a dark iron brazier with carved ember-shaped metal flames and grey ash stone around an opal crystal heart. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-62 | Echo A Perfect Echo | P2 | Weapon module for a war cart: a reactor pedestal with one large opal crystal core and a single wide gold ring bracket. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-63 | Echo B Harmonic Echo | P2 | Weapon module for a war cart: a reactor pedestal with a tuning-fork shaped gold frame around an opal crystal core. Materials: white marble and gold filigree with opal iridescent crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected, flat circular mounting base at the bottom. |
| A-64 | Coin | P0 | Chunky gold coin with an embossed faceted crystal emblem and a thick beveled rim. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-65 | Gem | P0 | Faceted blue crystal gem, eight-sided brilliant cut, slight violet tint at the edges. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-66 | Blueprint | P0 | Rolled blueprint scroll of blue paper with white technical line drawings, held by a gold clasp with a small crystal. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-67 | Crown | P0 | Small chunky gold crown with three rounded points each topped with a blue crystal, engraved band. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-68 | Rift Anvil | P2 | Grand forge altar with four empty crystal cradles around a central anvil, white marble and gold, an opal crystal set into the anvil front. Stylized hand-painted 3D game asset, premium mobile game quality, chunky readable shapes, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-69 | Crew operator | P0; soldier rig, idle/load/cheer poses | Small chunky soldier mechanic for a crowd game, white enamel armor with thin gold trim, a leather tool apron, a short wrench on the belt, round helmet with goggles, standing in a neutral A-pose. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-70 | Fusion chassis | P1 | Double-wide war cart chassis, wider than it is long, on six sturdy wheels, flat empty top deck with two round mounting rings side by side, an operator seat at the back centre, a gold chevron crest on the front. Materials: brushed steel and white enamel. Stylized hand-painted 3D game asset, premium mobile game quality, chunky exaggerated silhouette readable from above and behind at small size, key shapes on top, detailed back, white enamel with thin gold trim, single object centered, three-quarter rear top-down view, whole object visible, plain light grey background, soft studio lighting, no text, no logo, no characters, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-71 | Armored raider | P1; Volcano property | Small chunky enemy raider soldier for a crowd game, heavy dark steel plate armor with red-orange cloth, horned helmet, a large square shield and a short spear, standing in a neutral A-pose. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-72 | Flying raider | P1; Sky property | Small chunky enemy raider soldier crouched on a one-person glider with short stiff bat-like wings of dark steel and red-orange canvas, holding a spear. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-73 | Soldier T3 arc lance | P1 | Small chunky knight soldier for a crowd game, white enamel armor with thin gold trim and ice-blue accents, holding a halberd with a copper coil head, standing in a neutral A-pose. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-74 | Soldier T4 prism rifle | P1 | Small chunky soldier for a crowd game, white enamel armor with thin gold trim and ice-blue accents, holding a short rifle with a crystal prism barrel, standing in a neutral A-pose. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-75 | Soldier T5 starforged | P1 | Small chunky knight soldier for a crowd game, white enamel and gold armor with star-shaped engravings, a short sword and a round shield, standing in a neutral A-pose. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-76 | Haven Space stage 1 | P1 | Ruined crystal temple on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-77 | Haven Space stage 5 | P1 | Fully restored crystal temple on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-78 | Haven Reef stage 1 | P1 | Ruined coral reef city on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-79 | Haven Reef stage 5 | P1 | Fully restored coral reef city on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-80 | Haven Mystic stage 1 | P1 | Ruined rune grove shrine on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-81 | Haven Mystic stage 5 | P1 | Fully restored rune grove shrine on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-82 | Haven Volcano stage 1 | P1 | Ruined magma forge hall on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-83 | Haven Volcano stage 5 | P1 | Fully restored magma forge hall on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-84 | Haven Ice stage 1 | P1 | Ruined ice monastery on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-85 | Haven Ice stage 5 | P1 | Fully restored ice monastery on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-86 | Haven Sky stage 1 | P1 | Ruined sky harbour with airship docks on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-87 | Haven Sky stage 5 | P1 | Fully restored sky harbour with airship docks on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-88 | Haven Rift stage 1 | P1 | Ruined rift observatory on a floating rock island, broken white marble walls with thin gold trim, one intact tower with a cracked crystal spire, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-89 | Haven Rift stage 5 | P1 | Fully restored rift observatory on a floating rock island, intact white marble walls with gold trim, a whole crystal spire, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-90 | Citadel stage 1 | P2 | Ruined crystal citadel on a floating rock island, broken white marble walls with thin gold trim, a cracked central crystal tower, scaffolding and rubble. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-91 | Citadel stage 5 | P2 | Fully restored crystal citadel on a floating rock island, intact white marble walls with gold trim, a tall whole crystal tower, banners, lit windows. Stylized hand-painted mobile game diorama, premium quality, chunky readable shapes, whole island visible, three-quarter top-down view, plain light grey background, soft studio lighting, no text, no logo, no characters, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
| A-92 | Hero Seer | P2 | Heroic anthropomorphic lynx mystic, slender build, tufted ears, white and violet robes with gold trim, holding a crystal staff, standing in an A-pose for rigging. Stylized hand-painted 3D game character, premium mobile game quality, chunky proportions readable at tiny size, single character centered, full body, front view, plain light grey background, soft studio lighting, no text, no logo, no ground, no glow, no energy beams, no particles, no floating parts, all parts physically connected. |
