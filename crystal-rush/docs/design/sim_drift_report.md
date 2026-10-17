# Meta-1 drift: the Run vs LevelSim (no team, phase 0)

Owner decision 09.10 #3: investigate and report only. Nothing in this report is implemented. LevelSim, the Run,
LevelGen and every shipped level are unchanged (proof in §6). The tool that measured it is
`scripts/dev/drift_report.gd` (scene `scenes/dev/drift_report.tscn`); how to run it is in §7.

## 1. Summary (one page)

**What was measured.** Every campaign level 1-112 × Bolt, Titan and Seer: 336 cases. The EXPECTED synthetic account,
shipped flags (heroes phase 0), no team. The planner's best path (`LevelSim.best_path`, 13 candidates, the path
`level_check` plays) is played twice: by the real Run, stepped on game time at `Run.SUBSTEP`, and by LevelSim. Then
LevelSim is replayed again with one Run input or rule swapped in at a time, to see how much of the gap each mechanism
explains. A second path (p2) is planned with the crates the Run drew already known, as a player who reads the crate
badges would choose.

**The gap.** The Run brings **245,519** soldiers to the fortress over the 336 cases; LevelSim predicts **277,321**:
the Run is **11.5% below** LevelSim (this matches the 11-15% of the earlier 30-case sample). With p2 (the player can
pick crates) the Run brings 248,172: **10.5% below**.

- **36 of 336 cases** (11%) miss LevelSim's fortress army by more than 25%. Every one of them is the Run doing worse.
- **4 outcome flips**, all "the Run loses, LevelSim wins": L79 Titan, L83 Titan, L83 Seer, L107 Bolt. No case flips
  the other way.
- **Where:** the gap grows with the arsenal. Levels without the Prism in the deck (L1-21, 63 cases): -4.9%. Levels
  with it (L22-112, 273 cases): -12.0%. By world: W1 -9.3%, W2 -10.1%, W3 -10.7%, W4 -11.1%, W5 -12.5%, W6 -11.2%,
  W7 -13.5% (each world also holds its 8 invasion levels, L57-112). The drifting cases are spread over every world:
  W6 has the most (9), W1 the fewest (1); 15 are campaign levels (L1-56) and 21 invasion levels (L57-112).
- **The Run is near-deterministic** on a fixed path and fixed crates: other global seeds change nothing, and two
  processes differ by at most 11 soldiers (§3.3). Over 4 crate draws (attempts) per case on 84 cases the Run's
  fortress army moves 4.8% on average (median 1.2%), and the mean over draws is just as far below LevelSim (-10.1%)
  as one draw (-10.0%).

**Why: shares of the gap** (sequential: each line adds one mechanism on top of the ones above it, so the lines add
up to the gap; the last column swaps in that mechanism alone):

| Mechanism | Soldiers | Share of the gap | Alone |
|---|---:|---:|---:|
| Crate contents differ (2a) | +4,962 | 16% | |
| Steering lag: the Run's hero lands a little off the planned x (new) | +3,587 | 11% | +3,587 |
| Machine warm-up, mostly the railgun's charge (2b) | +1,834 | 6% | +1,890 |
| **Prism amp: LevelSim amps every hero shot, gate hits too (new)** | **+11,919** | **37%** | +11,489 |
| Machine kill rate (the Run's machines kill less) | +497 | 2% | +2,265 |
| Barricades (1b) | +416 | 1% | +441 |
| Rotors and sweepers (1a) | +1,522 | 5% | +2,928 |
| Turrets | -455 | -1% | -463 |
| Gate values (what remains of the gate difference) | -478 | -2% | +9,850 |
| Residual: clashes and timing | +7,997 | 25% | |
| **Total** | **+31,802** | 100% | |

**What the four earlier suspects turned out to be.**
- **(1a) Rotors at large armies:** real but smaller than it looked, and not the drawn-unit weight. When LevelSim's
  band model crosses a rotor from the Run's own state (same army, x and hazard clock) it predicts 1,489 soldiers
  where the Run loses 2,131: it under-counts rotors by about 30% at every army size of 60 and more, with or without
  drawn units worth more than one soldier. The famous L46 Titan rotor (290 vs 0) is the Titan's quake armour: in
  LevelSim the quake was still running when the army crossed, because LevelSim's own crates timed the ult
  differently; with the Run's crates LevelSim loses 203 there, the Run 228. Sweepers cost more (Run 5,094,
  LevelSim 1,822), but there the model is right at the Run's state (4,512): the Run simply crosses at another
  moment, and 19 sweepers that LevelSim's line slips past hit the Run (1,230 soldiers), the Run arriving a median
  0.3 s off.
- **(1b) Barricades met at full hp:** mostly a crate effect. LevelSim's own draws often give it a railgun that breaks
  the barricade before contact (LevelSim loses 719 there, 1,461 with the Run's crates, the Run 1,836). The band model
  itself is right: from the Run's state it predicts 1,808 of the Run's 1,836.
- **(2a) Crate contents:** 458 of 2,364 draws differ. This is not bad luck in the Run: over 4 draws the Run averages
  the same. It is the fixed path: the planner picks crates and lines for LevelSim's own draws. Planned with the
  Run's crates known (p2), LevelSim's estimate stays where it was (276,024 vs 277,321) and the Run gains 2,653.
- **(2b) Railgun charge-up:** confirmed and small: 6% of the gap.

**Three new mechanisms carry most of the rest.**
1. **The Prism amp (37%).** `Run._hero_attack` gives a hero shot +amp only when the Prism crosses it (the target at
   least 2.5 u ahead in the lane) and never on a gate. `LevelSim.hero_damage` gives it to every hero shot: gate hits
   (so LevelSim's gates hand out about 8% more soldiers: 269,607 vs the Run's 250,173) and squads in a clash 1.1 u
   ahead. This one rule difference is the largest single cause, on every level with a Prism (L22+).
2. **Steering lag and zero clearance (11%, plus about a third of the residual).** LevelSim's hero sits exactly on the
   path; the Run's hero follows it through `STEER_HALFLIFE`. A swerve that ends at a gate row ends about 0.4 u short
   (L8 and L107: 0.42 u; 137 rows in 111 cases crossed more than the planner's 0.25 u margin off the planned x). The planner also keeps
   the blob exactly tangent to squads it slips past (no margin at all): in 21 cases the Run's hero, a hair short of
   the planned x, starts a clash LevelSim never has, at 0.0000 u inside the clash test, for 2,689 soldiers (L89
   Bolt 405 and Titan 503, L96 Titan 249, L79 Titan 245, L23 Titan 181, ...).
3. **The bot's ult rule (dev tools only, small).** `Bot.snapshot` sees a clash only when the squad's front is within
   0.6 u of CONTACT, so a squad met from the side (passed clear, then swerved into) reads as "no fight" and the ult
   waits. With `test_kind_parity.step`'s rule 13 of the 336 Run results change by more than the process noise (12
   lower, 1 higher; 988 soldiers fewer in all; L48 Bolt falls from 556 to a loss, its first clash at d 52.2 against
   a squad whose front is at 52.4). It does not touch the game; this report's runs read the fight from the Run.

**What to do (nothing done here, §5).** The biggest lever is one rule decision: does the Prism amp gate hits? Making
the Run match LevelSim (amp on every hero shot) moves no level; making LevelSim match the Run re-bakes L22+.
Planning with a squad clearance and a steering-lag margin is the next lever. Every LevelSim-side fix moves LevelGen:
levels are built at load time from LevelSim's reference players, so a LevelSim rule change re-bakes every level it
touches (§5.1).

## 2. Method

- **Cases.** Levels 1-112 × {Bolt, Titan, Seer}. The account is `champ_survival.account_for(level, "expected", hero)`
  with an empty team; the profile is `Meta.run_profile(level)` with the shipped flags (heroes phase 0). The Run and
  LevelSim get the same profile (a copy taken before the Run starts).
- **Path p1.** `LevelSim.best_path` with 13 candidates (as `level_check`), on LevelSim's own crate draws.
- **The Run.** `test_kind_parity`'s driver: the Run in the tree, headless, stepped by hand at `Run.SUBSTEP` (1/40 s),
  steered with `Run.steer_to` a spring lag ahead on the path, its Effects (projectiles) stepped on game time, engine
  run with `--fixed-fps 10` and 4 Run steps a frame so SceneTreeTimers (the rocket salvo, mortar bomblets) also run
  on game time. The ult fires by the shared policy (`HeroKinds.ult_worth`), its "in a fight" test read from the Run.
  A subclass (`DRun`) books what every hazard cost, kills by source, gate rows, the hero's x at each row and every
  clash; it changes no rule.
- **LevelSim.** The tool's own copy of `LevelSim.step`, checked float for float against `LevelSim.simulate` on every
  case (0 failures in all 1,344 rows: the main sweep, the census pass and the attempts). Replays: `own` (LevelSim as the planner sees it), `rc` (the Run's crate
  contents), then a chain that adds one Run input or rule at a time:
  - `lag`: the hero's x follows the path through the Run's steering (the driver's lead, then `STEER_HALFLIFE`);
  - `warm`: a crate's machine hops out (`Weapons.ARRIVE_TIME` 0.8 s) and waits its first cooldown (0.5 s; the
    railgun its charge + telegraph, 3.4 s at Rank I; the mortar also its 0.8 s shell flight);
  - `amp`: the Prism amp only where the Run gives it;
  - `mach`: every machine's squad damage × (the Run's machine kills / LevelSim's), one factor per case;
  - `bar`, `blade`, `tur`: every barricade / rotor or sweeper / turret costs what it cost in the Run (soldiers for
    barricades and turrets, the share of the army for blades), once, at the army's first contact;
  - `gates`: every gate the Run passed shows the op and value the Run passed it with.
  The chain order is a choice; the "alone" column shows each mechanism without the others. Hazards and gates are
  injected Run values, not rule fixes: they measure, they do not propose.
- **Model at the Run's state.** Each barricade, rotor and sweeper the Run met is crossed once more by LevelSim's band
  model, started from the Run's state at contact (army, armour, barricade hp, the blob's real centre x, the hazard
  clock), the hero following the path. This separates "the model is wrong" from "the state or timing differs".
- **Path p2.** `best_path` re-planned with the Run's p1 crate contents already in `State.content`, then everything
  again. 422 of the crates the p2 Run drew differ from p1's (its own route resolves them in another order), so p2
  is a fair but not perfect "player who reads the badges".
- **Attempts.** On every 4th level (84 cases) the Run was played 4 times on p1 with other run ids (other crate draws).
- **Limits.** The path is fixed: the Run cannot re-plan as the in-game bot or a player does. Per case the
  decomposition is chaotic (a 0.1 s shift can arm a quake or move a sweeper, ±300 soldiers); only sums over many
  cases are meaningful. Injected hazards are paid at first contact, not spread over the crossing.

## 3. Evidence

### 3.1 Per world (p1; the chooser column is the Run on p2 against LevelSim's p1 estimate)

| World | Levels | Cases | Run / LevelSim fortress army | Gap | Flips | Off by > 25% | Chooser (p2) gap |
|---|---|---:|---:|---:|---:|---:|---:|
| 1 | L1-8, L57-64 | 48 | 22,385 / 24,669 | -9.3% | 0 | 1 | -7.1% |
| 2 | L9-16, L65-72 | 48 | 25,747 / 28,646 | -10.1% | 0 | 6 | -6.7% |
| 3 | L17-24, L73-80 | 48 | 34,263 / 38,371 | -10.7% | 1 | 7 | -9.2% |
| 4 | L25-32, L81-88 | 48 | 35,526 / 39,972 | -11.1% | 2 | 3 | -9.7% |
| 5 | L33-40, L89-96 | 48 | 37,674 / 43,038 | -12.5% | 0 | 6 | -14.0% |
| 6 | L41-48, L97-104 | 48 | 43,732 / 49,243 | -11.2% | 0 | 9 | -10.8% |
| 7 | L49-56, L105-112 | 48 | 46,192 / 53,382 | -13.5% | 1 | 4 | -12.5% |
| **All** | L1-112 | 336 | 245,519 / 277,321 | -11.5% | 4 | 36 | -10.5% |

By band: L1-3 (tutorials) -4.6%, L4-21 -4.9%, L22-56 -11.5%, L57-112 -12.2%. By hero: Bolt -13.2%, Titan -11.5%,
Seer -9.7%.

Each mechanism alone, as a share of LevelSim's fortress army with the Run's crates (crates: share of LevelSim's own):

| World | Crates | Lag | Warm-up | Prism amp | Machine rate | Barricades | Rotors, sweepers | Turrets | Gate values |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | +2.9% | +0.6% | +1.3% | +3.9% | +0.8% | +0.1% | +1.5% | -0.2% | +3.4% |
| 2 | +3.6% | +1.2% | +0.4% | +3.8% | +1.1% | +0.3% | -0.1% | -0.1% | +3.0% |
| 3 | +1.1% | +3.5% | +1.0% | +4.1% | +1.6% | -0.0% | +1.7% | +0.1% | +3.2% |
| 4 | +0.9% | +3.6% | +0.5% | +3.9% | +1.2% | -0.0% | +0.9% | -0.3% | +3.7% |
| 5 | +0.3% | +0.2% | +0.8% | +4.6% | +0.3% | +0.0% | +0.2% | -0.2% | +4.2% |
| 6 | +2.2% | +0.3% | +0.9% | +4.9% | +0.5% | +0.6% | +2.4% | -0.1% | +3.9% |
| 7 | +2.3% | +0.3% | +0.2% | +4.0% | +0.6% | +0.1% | +0.8% | -0.3% | +3.5% |

The Prism amp is +4.5% on the 273 cases with a Prism in the deck (L22+) and +0.7% on the 63 without (mostly L21,
whose NEW crate is the Prism).

### 3.2 Hazards (p1)

| Hazard | Met | Run lost | LevelSim's model at the Run's state | LevelSim (own) | LevelSim, the Run's crates | Armour differs | Contact > 0.3 s off |
|---|---:|---:|---:|---:|---:|---:|---:|
| Barricade | 288 | 1,836 | 1,808 | 719 | 1,461 | 3 | 31 |
| Rotor | 257 | 2,131 | 1,489 | 1,248 | 1,566 | 3 | 35 |
| Sweeper | 190 | 5,094 | 4,512 | 1,822 | 3,455 | 1 | 29 |
| Turret | 138 | 1,358 | - | 1,378 | 1,750 | 1 | 20 |

Share of the army lost per crossing, by the Run's army at contact (above 220 a drawn unit is worth more than one
soldier):

| Hazard | Army | Crossings | Run | Model at the Run's state | LevelSim (own) |
|---|---|---:|---:|---:|---:|
| Rotor | < 60 | 34 | 12.8% | 11.5% | 11.8% |
| Rotor | 60-220 | 87 | 6.3% | 4.4% | 3.9% |
| Rotor | > 220 | 136 | 1.6% | 1.1% | 0.7% |
| Sweeper | < 60 | 36 | 7.4% | 4.0% | 11.9% |
| Sweeper | 60-220 | 36 | 8.3% | 6.6% | 5.1% |
| Sweeper | > 220 | 118 | 6.8% | 6.1% | 1.9% |
| Barricade | < 60 | 79 | 7.7% | 5.2% | 8.5% |
| Barricade | 60-220 | 83 | 3.9% | 3.9% | 2.0% |
| Barricade | > 220 | 126 | 2.1% | 2.1% | 0.5% |

Hazards one side hit and the other passed free (LevelSim with the Run's crates): sweepers 19 hit only the Run (1,230
soldiers, contact a median 0.3 s off) and 5 only LevelSim (98); rotors 6 / 5 (114 / 40); barricades 2 / 1 (201 /
128). Where both were hit, rotors cost the Run 1,815 and LevelSim 1,334 (model at the Run's state 1,261): the rotor
under-count is the model; for sweepers both-hit cost 3,816 / 3,219 (model 3,516): the sweeper gap is timing.
Barricades at contact: the Run met them with 36,299 hp in all (20 of 288 already broken), LevelSim with 33,827 (35
broken), LevelSim with the Run's crates 35,740 (23 broken).

### 3.3 Kills, gates, clashes (p1; Run / LevelSim / LevelSim with the Run's crates)

| Quantity | Run | LevelSim | Run's crates |
|---|---:|---:|---:|
| Machine kills (burn and Jolt chains counted) | 13,972 | 20,549 | 16,087 |
| Soldiers from gates | 250,173 | 269,607 | 270,173 |
| Clash losses | 40,185 | 34,066 | 36,490 |
| Kills before the first clash | 20,933 | 24,844 | |
| ... by the hero / machines / ult | 4,779 / 3,430 / 8,869 | 5,081 / 6,214 / 9,603 | |
| Ults fired | 1,124 | 1,119 | |

Gate rows passed with another op or value: 2,392 of 2,952 (mostly a few soldiers of pumping).

Clash census (a second p1 pass of the same tool, §7): 66 squads only the Run fought (57 cases, 3,160 soldiers), 10
only LevelSim fought (428). 21 of those cases start exactly at the tangency (2,689 soldiers, the zero clearance of
§1); the others are squads LevelSim had already killed before contact. The clashes both fought cost the Run 37,012
and LevelSim 33,637 (+10%): the Run's squads arrive with more hp (fewer kills before contact) and the Run pays whole
soldiers per tick (`ceil` of the squad's hp). The Run is not bit-exact between processes: `Audio.play` draws pitch
from the global RNG with real-time throttling, so 10 of the 336 fortress armies moved by 1-11 soldiers between the
two passes (15 soldiers in all, 0.006%).

### 3.4 Cases off by more than 25% or flipped (p1)

Sequential parts in soldiers (LevelSim minus Run; a positive part is what that mechanism costs the Run). Boss levels
marked. The last column is the Run on p2.

| Level (world) | Hero | Run / LevelSim | Crates | Lag | Warm | Amp | Mach | Bar | Blade | Tur | Gates | Residual | p2 Run |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| L21 (3) | seer | 347 W / 670 W | -9 | +35 | +0 | +27 | -1 | +0 | +4 | -2 | +274 | -6 | 347 W |
| L23 (3) | titan | 361 W / 593 W | -5 | +26 | +10 | +32 | -20 | +0 | -1 | -2 | +5 | +187 | 369 W |
| L24 (3, boss) | bolt | 409 W / 603 W | +121 | +234 | +20 | +13 | +14 | +6 | -11 | +0 | -199 | -4 | 556 W |
| L24 (3, boss) | seer | 393 W / 568 W | +335 | -215 | +20 | +17 | +9 | -11 | -20 | +0 | -2 | +41 | 500 W |
| L26 (4) | titan | 296 W / 440 W | +110 | +3 | +0 | +16 | +8 | +0 | +8 | -2 | +0 | +1 | 432 W |
| L37 (5) | bolt | 381 W / 638 W | -6 | -2 | +0 | +195 | -167 | +0 | +0 | +0 | +3 | +235 | 358 W |
| L37 (5) | seer | 364 W / 590 W | +2 | -2 | +155 | +24 | -7 | +0 | +0 | +0 | -1 | +57 | 332 W |
| L43 (6) | bolt | 266 W / 569 W | +183 | +9 | +59 | +12 | +0 | +30 | +9 | +0 | +0 | +1 | 258 W |
| L43 (6) | titan | 497 W / 684 W | +71 | -0 | +89 | +33 | +0 | +4 | -8 | +0 | +0 | -1 | 660 W |
| L44 (6) | bolt | 400 W / 589 W | +61 | +1 | +0 | +23 | -4 | -0 | +106 | +0 | +1 | +1 | 488 W |
| L45 (6) | bolt | 369 W / 571 W | -55 | -4 | +18 | +23 | +51 | +138 | +24 | +0 | +6 | +3 | 558 W |
| L46 (6) | titan | 638 W / 940 W | +232 | -192 | +0 | +28 | +207 | +0 | +33 | -2 | -4 | -0 | 941 W |
| L47 (6) | seer | 459 W / 636 W | -2 | +41 | +16 | -13 | +302 | +0 | -29 | +0 | -140 | +1 | 464 W |
| L48 (6, boss) | bolt | 556 W / 786 W | +0 | +8 | +0 | +64 | +0 | +0 | +77 | +0 | +3 | +80 | 554 W |
| L49 (7) | bolt | 345 W / 514 W | +83 | +7 | +0 | +25 | -14 | +0 | +60 | +0 | +1 | +6 | 475 W |
| L62 (1) | bolt | 544 W / 818 W | +0 | -33 | +208 | +16 | +79 | +0 | +1 | +39 | -34 | -2 | 544 W |
| L65 (2) | seer | 514 W / 752 W | +374 | -1 | +0 | +15 | +6 | +0 | -211 | +0 | +2 | +53 | 625 W |
| L66 (2) | seer | 470 W / 689 W | +114 | -54 | +0 | +42 | +235 | +0 | -22 | +0 | -26 | -69 | 573 W |
| L66 (2) | titan | 453 W / 733 W | +167 | -12 | +3 | +31 | +1 | +0 | +0 | +0 | -6 | +95 | 582 W |
| L69 (2) | bolt | 771 W / 1034 W | +124 | +4 | +0 | +51 | +5 | +0 | +31 | +0 | +29 | +19 | 1046 W |
| L71 (2) | bolt | 444 W / 809 W | +0 | +146 | +19 | +111 | -0 | +0 | +0 | -6 | +3 | +91 | 467 W |
| L71 (2) | titan | 511 W / 770 W | +36 | +106 | +0 | +41 | -6 | +0 | +0 | +0 | +0 | +82 | 511 W |
| L79 (3) | bolt | 343 W / 934 W | +0 | +545 | +0 | +17 | -1 | +2 | +21 | +0 | +5 | +1 | 877 W |
| L79 (3) | seer | 419 W / 771 W | +0 | +305 | +0 | +31 | +0 | -2 | +17 | +0 | +1 | -0 | 526 W |
| L79 (3) | titan | 253 L / 783 W | +0 | +498 | +0 | +15 | +10 | -1 | +4 | +0 | +0 | +5 | 476 W |
| L83 (4) | seer | 0 L / 882 W | +0 | +18 | +0 | +864 | +0 | +0 | +0 | +0 | +0 | +0 | 0 L |
| L83 (4) | titan | 0 L / 1043 W | +59 | +984 | +0 | +0 | +0 | +0 | +0 | +0 | +0 | +0 | 0 L |
| L89 (5) | bolt | 528 W / 1110 W | -11 | +0 | +0 | +54 | +0 | +0 | +0 | -15 | +4 | +549 | 519 L |
| L89 (5) | titan | 618 W / 1168 W | -13 | -3 | +0 | +72 | +0 | +0 | +0 | -15 | +0 | +508 | 638 W |
| L95 (5) | bolt | 1093 W / 1496 W | +0 | +0 | +0 | +37 | +0 | +0 | +104 | +14 | +11 | +237 | 1093 W |
| L96 (5, boss) | titan | 552 W / 847 W | -8 | -2 | +0 | +56 | -8 | +0 | +0 | +0 | +7 | +251 | 558 W |
| L98 (6) | bolt | 711 W / 978 W | +9 | +115 | +5 | +192 | -278 | +124 | +14 | +0 | +26 | +59 | 651 W |
| L103 (6) | seer | 821 W / 1111 W | +33 | -4 | +19 | +28 | +27 | +0 | +160 | +0 | +0 | +26 | 763 W |
| L107 (7) | bolt | 0 L / 1218 W | +0 | -41 | +4 | +55 | +51 | +0 | +0 | -29 | +0 | +1177 | 0 L |
| L108 (7) | bolt | 1154 W / 1600 W | +277 | -2 | +0 | +33 | +107 | +0 | +19 | +0 | +10 | +1 | 1287 W |
| L108 (7) | seer | 1101 W / 1470 W | +311 | -2 | +0 | +70 | +30 | +0 | -41 | +0 | +1 | +1 | 1337 W |

Five traced cases:
- **L107 Bolt (flip).** Gate row 1 at d 45.4: the path holds x -1.00, the gate spans -2.70..-0.60, the Run's hero is
  still at -0.58 after its swerve. It passes through the gap, misses +130 and loses the first clash. The lag replay
  (LevelSim's coarser 0.05 s steps) lands just inside the gate and still takes it: a knife edge even for the lag
  model.
- **L89 Titan (residual 508).** At d 279.5 the path holds x 2.50; the squad stands at -1.20 ± 1.50 and the blob radius
  is 2.20, so the blob edge touches the squad exactly (|2.50 + 1.20| = 2.20 + 1.50). LevelSim (item x in a
  float32 array) reads it as clear; the Run's hero, a hair short of 2.50, clashes and loses 503 soldiers.
- **L46 Titan (rotor 290 vs 0 in the earlier sample).** With its own crates LevelSim's quake armour is still on at the
  d 268.8 rotor; with the Run's crates it is off and LevelSim loses 203 there, the Run 228 (the band model from the
  Run's state: 193).
- **L43 Bolt.** LevelSim's own draws field a Rank III railgun that breaks both barricades before contact; the Run's
  draws do not (crates +183), and its railgun charges 3.4 s first (warm-up +59).
- **L48 Bolt.** With `test_kind_parity`'s snapshot ult rule the Run never fires its ult in the first clash (a squad
  met from the side) and loses the level; reading the fight from the Run it wins with 556.

### 3.5 The earlier 30-case sample

The same 10 levels (41-47, 50, 53, 55) × 3 heroes in this sweep: the Run 13.9% below LevelSim, hazard losses 1,896
vs 568. The earlier sample (phase H2 forced, 9 planner candidates, the snapshot ult rule) had 11-15% and 2,272 vs 473.

## 4. Mechanisms in plain words

1. **Prism amp (37%).** The design (§2.5 Prism: "every friendly projectile that crosses it gains +20%") is read two
   ways. The Run: only shots that pass the Prism, which hovers 3 u ahead, so no gate hits and no squad in a clash.
   LevelSim: every hero shot. LevelSim's hero pumps gates harder (its gates hand out ~8% more soldiers) and kills
   clashing squads faster.
2. **Steering lag and zero clearance.** LevelSim's hero is on the path; the Run's hero chases it. The planner leaves
   0.25 u at gates (less than the lag at the end of a swerve) and 0 u at squads.
3. **Crates.** Different random streams (the Run draws 30 u ahead from a per-run stream; LevelSim at opening from a
   per-crate seed) and a path that was chosen for LevelSim's draws.
4. **Machine warm-up.** The Run's machines hop out of the crate (0.8 s) and wait a cooldown; the railgun charges 3.4 s.
   LevelSim pays the average damage from the first step.
5. **Machine kill rate.** The Run's machines kill 13% less than LevelSim's rows with the same crates (mortar only
   fires with a target under its ring, shots fly, the railgun's lane locks where the hero stood). Before the first
   clash LevelSim's machines kill 1.8× as much.
6. **Hazard timing.** The planner threads sweepers and rotors at the phase it computes. The Run reaches them a little
   earlier or later (clash lengths, kills) and the phase is gone. The barricade band model is right; the rotor band
   model under-counts by ~30%.
7. **Residual (25%, 7,997 soldiers).** About a third is the zero-clearance clashes above (the lag replay does not
   catch a tangency off by a millionth). Another part is lag misses the lag replay, stepping at LevelSim's 0.05 s,
   lands just inside: L8 (all three heroes, ~30 of ~260 soldiers) crosses gate row 7 at x 0.58 where the gate starts
   at 0.60, L107 Bolt row 1 at -0.58 against -0.60. The rest is the clashes themselves: the same squads cost the Run
   10% more, because they arrive bigger and the Run rounds each tick up to whole soldiers, and every small difference
   before an "x" gate is multiplied by it.

## 5. Candidate fixes (none implemented)

### 5.1 What any fix does to LevelGen

`LevelGen.build` runs when a level loads; levels are not stored. From L4 its numbers follow `e`, the mean army of two
reference players (Bolt and Titan, `LevelSim.reference_profile`: FRESH machines from NEW crates, no Lead, hero Lv1,
`REF_DT` 0.2, `PLAN_GATE_MARGIN`) on their best simple lines; the fortress hp and the stairs follow their army at the
gate. So:
- a **Run-side** fix (or a fix in the bot / planner only, `gate_margin` paths excluded) moves **no level**;
- a **LevelSim rule** fix moves `e` wherever the reference players meet the changed rule, and every later number of
  that level (gates, squads, hazards, fortress, stairs) follows: those levels **re-bake**. A fix that lowers
  LevelSim's army lowers `e`, so the re-baked level gets smaller numbers and a weaker fortress: **easier**, closer to
  what the Run delivers. A planning margin (`gate_margin` is set on LevelGen's reference players too) does the same.
- The per-world "alone" column of §3.1 is the size of each change for the EXPECTED account. The reference players
  are weaker (no Lead, fewer machines), so for machine and Prism rules their `e` moves less than that.

### 5.2 Per mechanism

| # | Mechanism | Candidate fix | Effect on the drift | Effect on LevelGen |
|---|---|---|---|---|
| A | Prism amp (37%) | **A1 (Run):** the Prism amps every hero shot, gates and clashing squads too. **A2 (LevelSim):** `hero_damage` amps only targets ≥ 2.5 u ahead and never gates, as `Run._hero_attack`. | Either closes ~11,500 soldiers (the "alone" value, 4-5% of the fortress army on L22+). | A1: none. A2: re-bakes L22+ where a reference player opens a Prism crate (no Lead, so from that crate on); smaller numbers there. Decide first which reading of §2.5 is the design. |
| B | Steering lag at gates | **B1 (planner, dev only):** `best_path` plans with the hero on the Run's spring (or asks 0.6 u at a row right after a swerve). **B2 (LevelSim rule):** model the spring in `LevelSim.step`. **B3 (driver, dev only):** steer with more lead. | ~3,600 soldiers (11%); several flips (L79, L83 Titan). | B1, B3: none (but `level_check` and the bot change). B2: re-bakes every L4+ level with a swerve before a gate row: slightly smaller numbers. |
| C | Zero clearance at squads | **C1 (planner, dev only):** a squad counts as met within `r + hw + margin` in planning (`gate_margin`'s twin). **C2 (data hygiene):** store LevelSim's `x` / `hw` as float64 or compare with a 0.001 tolerance, so a tangency reads the same in both. | ~2,700 soldiers in 21 cases, a third of the residual (§4.7). | C1 inside `gate_margin` code would also reach LevelGen's reference players: re-bakes levels where they slip past a squad at tangency, those get easier. C1 limited to `best_path`: none. C2: tiny re-bake risk (only exact tangencies), direction mixed. |
| D | Crate contents | **D1 (planner, dev only):** plan with the Run's crate draws (resolve 30 u ahead with `Run._pick_rng`'s rule) or average over draws. **D2 (LevelSim rule):** draw like the Run. | p1 vs p2 shows a chooser recovers about half (2,653 of 4,962); the rest is the fixed-path artefact. | D1: none. D2: re-bakes every level with a deck crate (L4+), direction random per level (the Run's mean over draws equals one draw, so no systematic shift). |
| E | Machine warm-up (2b) | **E1 (LevelSim):** a new machine waits `ARRIVE_TIME` + its first cooldown (railgun: charge + telegraph) before its average starts. | ~1,850 soldiers (6%). | Re-bakes levels where a reference player opens a crate, L4+: a little smaller numbers (0.2-1.3% of the army by world for the EXPECTED account). |
| F | Machine kill rate | **F1 (LevelSim):** recalibrate `sim_row` per machine from Run measurements (this tool's `run_mach` / `rc_mach` per id); the mortar's ring condition and the railgun's lane lock are the known misses. | ~500 after the above, ~2,300 alone. | Re-bakes every level where reference players field machines (L4+), smaller numbers. |
| G | Hazard timing (sweepers, rotors) | **G1 (planner):** price a moving hazard at its worst (or mean) over ±0.12-0.3 s of phase, like `PLAN_TIME_MARGIN` for moving gates. **G2 (LevelSim rule):** rotor band model: more slices and the Run's swept-arc test (it under-counts ~30% at the Run's own state). | ~1,500 (5%) in the chain, ~2,900 alone. | G1 in `gate_margin` planning also steers LevelGen's reference players: they stop threading moving hazards, lose more there, `e` drops after rotors (L4+) and sweepers (L6+): those levels re-bake easier. G2: re-bakes every level with rotors (L4+), easier after each rotor. |
| H | Bot ult rule | **H1 (dev only):** `Bot.snapshot` / `test_kind_parity.step` read the fight from `run.state` (as this tool does). | 988 soldiers in 13 cases; L48 Bolt flips back to a win. | None. |
| I | Turrets | No fix needed now: the only mechanism that favours the Run (LevelSim with the Run's crates loses 1,750 to turrets, the Run 1,358). | -455 soldiers. | |

Suggested order, smallest LevelGen impact first: H1 and B3 (dev tools), then the Prism decision (A1 needs no
re-bake), then C1/B1 limited to `best_path` (the planner and `level_check` only). The LevelSim rule fixes (A2, B2,
D2, E1, F1, G1, G2) each re-bake many levels and belong to one planned LevelGen re-bake, measured with this tool and
`level_check` before and after.

## 6. Phase 0 is untouched

The commit adds only a dev tool (nothing references it) and this report. Proof, before and after adding them:
- `test_kinds` (the phase 0 identity checks): `TEST_KINDS PASS: 168 passed, 0 failed` both times.
- `level_check` on all 112 levels × 3 heroes (EXPECTED, no random paths): 343 lines, identical (`diff` empty).

The other checks on the same tree: test_meta 551/0, test_heroes (`--no-python`) 1900/0, test_heroes_ui 399/0,
test_loc 61/0, test_champ_hud 87/0, test_champion_twists (`--budget=0`) 81/0, test_juice done, autotest phase 0 and
phase 2 won 2 of 2, `gen_heroes_data.py --check` in sync, `loc_lint.py` the 47 known table errors and no new one.
`test_kind_parity --quick` fails 10 of 12 team deltas (army and heals columns) on the base commit itself; this
commit does not touch it.

## 7. Reproduce

```
godot --headless --fixed-fps 10 --path crystal-rush res://scenes/dev/drift_report.tscn -- --autotest \
      --from=1 --to=14 --out=DIR        # one shard; 8 shards of 14 levels in parallel take about an hour
godot --headless --path crystal-rush res://scenes/dev/drift_report.tscn -- --autotest --merge=DIR
```
`--levels=43,89 --heroes=titan --replan=0 --verbose` traces single cases (kills by source, gate rows, the hero's x
at every row, Run-only clashes). `--seeds=4 --replan=0` plays 4 attempts (§2; levels 4, 8, ..., 112 here).
`--ult=snapshot` uses `test_kind_parity.step`'s ult rule. The CSVs (`drift_*.csv`, one row per case, path and
attempt; `drift_*_haz.csv`, one row per hazard met) hold every number above. The numbers here come from three
passes of this tool: the full sweep (both paths), the clash census (p1, `--replan=0`; its clash columns were added
after the full sweep, every other column agrees within the process noise of §3.3) and the attempts.
