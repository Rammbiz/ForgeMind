#!/usr/bin/env python3
"""Roster tables for heroes_design.md §6 — generated from heroes_sim.py constants (the single source of truth).

Every per-rank / per-gem number printed in §6 comes from this file. The roster kit values below (KITS, ULT, RALLY,
CHAMPS) are the Quartz-normalised base numbers of the design; the ladder, rank steps, caps and forms are imported from
heroes_sim.py so a later retune of Ladder / PROGRESS regenerates every table (critique B3 / X3).

Run: python3 heroes_tables.py > heroes_tables_output.txt
"""
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import heroes_sim as H  # noqa: E402

GEM = H.GEM_EN
GEM_UK = H.GEM_UK

# ------------------------------------------------------------------------------------------------ hero kits
# (id, uk name, native, class, element, faction, hp, rate, dmg, splash, range, targets, ult charge)
KITS = [
    ("titan", "Горан", 0, "Guardian", "Kinetic", "Stoneheart", 32, 1.2, 4, 3, 12, 1, 40),
    ("arin", "Арін", 0, "Warrior", "Kinetic", "Dawn", 26, 1.6, 3, 2, 11, 1, 36),
    ("bolt", "Руді", 1, "Ranger", "Volt", "Wildfang", 14, 3.6, 1, 0, 15, 1, 35),
    ("eira", "Ейра", 1, "Healer", "Frost", "Dawn", 20, 2.0, 1, 0, 14, 1, 34),
    ("seer", "Мейра", 2, "Mage", "Rune", "Wildfang", 18, 2.0, 1, 0, 16, 2, 38),
    ("iskar", "Іскар", 2, "Ranger", "Volt", "Celestials", 13, 3.2, 1, 0, 16, 1, 36),
    ("vesta", "Веста", 3, "Warrior", "Plasma", "Dawn", 27, 1.5, 3, 2, 12, 1, 38),
    ("vartan", "Вартан", 3, "Guardian", "Tech", "Stoneheart", 33, 1.1, 4, 3, 12, 1, 42),
    ("lumen", "Люмен", 4, "Mage", "Plasma", "Celestials", 17, 2.2, 1, 1, 15, 2, 42),
    ("pava", "Пава", 4, "Healer", "Rune", "Wildfang", 21, 1.9, 1, 0, 14, 1, 44),
    ("sirko", "Сірко", 4, "Warrior", "Rune", "Dawn", 25, 1.7, 3, 2, 11, 1, 42),   # H26, the 11th hero (§6.28)
    ("olha", "Ольга", 4, "Ranger", "Plasma", "Wildfang", 15, 3.4, 1, 0, 16, 1, 40),   # H27, the 12th hero (§6.29)
]

# main ult number per hero (form I, rank 1, Quartz-normalised) + what it measures; forms add RULES (S budget +3% each)
ULT = {
    "titan": (12, "kills & breaks per band (4 bands)"),
    "arin": (22, "impact kills & breaks"),
    "bolt": (5, "storm kills per tick (12 ticks)"),
    "eira": (4, "Litany kills per squad"),
    "seer": (5, "rift kills per tick (8 ticks)"),
    "iskar": (6, "comet kills per tick (6 ticks)"),
    "vesta": (10, "Sunrise kills & breaks per pulse (4 pulses)"),
    "vartan": (8, "wall contact kills (wall HP 30 scales the same)"),
    "lumen": (2, "fan kills & breaks per ray per tick (10 ticks)"),
    "pava": (8, "fan base return (+30% of the revive pool)"),
    "sirko": (16, "laughter kills & breaks per squad / structure under the scroll"),
    "olha": (18, "breaks per structure / gate the flock reaches (squads under the flight path lose a third + BURN)"),
}
# second ult number that scales with ult.power (optional)
ULT2 = {
    "vesta": (8, "Sunstride slam (form IV)", 7),
    "vartan": (8, "Landslide (form IV)", 7),
    "lumen": (4, "Crown Shard hit (form IV)", 7),
    "pava": (4, "Eyes Wide kills (form IV)", 7),
    "sirko": (8, "Second Roar kills & breaks (form III)", 5),
    "olha": (8, "Fourth Revenge kills on the biggest squad (form III)", 5),
}

# Rally hook and base value at rank 1 (Quartz-normalised; = S's per-hook parity base, critique B2)
RALLY = {
    "titan": ("army_scrape", 3.0, "soldiers spared per hazard contact"),
    "arin": ("army_drill", 0.075, "extra clash loss of squads he hit"),
    "bolt": ("machines_element (Volt)", 0.03, "Volt machine damage, bucket 2"),
    "eira": ("champions_hp", 0.15, "champion HP x(1+v)"),
    "seer": ("ult_start", 0.10, "ult charge at level start"),
    "iskar": ("machines_verb (LANE)", 0.025, "LANE machine damage, bucket 2"),
    "vesta": ("army_reserves", 6.0, "soldiers joining at the siege"),
    "vartan": ("army_volleys", 0.15, "army volley damage x(1+v)"),
    "lumen": ("machines_element (Plasma)", 0.03, "Plasma machine damage, bucket 2"),
    "pava": ("champions_aura", 0.06, "champion aura value x(1+v)"),
    "sirko": ("army_recruits", 1.0, "soldiers added to every recruit group"),
    "olha": ("ult_charge", 0.05, "ult charge rate x(1+v)"),
}

# ------------------------------------------------------------------------------------------------ champions
# (id, uk, native, class, element, faction, hp, action number, action label, aura value, aura label, radius, slot)
CHAMPS = [
    ("mila", "Міла", 0, "Healer", "Tech", "Dawn", 30, 3, "soldiers returned per pulse (every 3 s)", 0.12, "hazard losses -", 1.3, "left"),
    ("ivo", "Іво", 0, "Guardian", "Plasma", "Dawn", 60, 1.4, "blocked-barricade damage (Block every 5 s)", 0.10, "clash losses -", 1.0, "front"),
    ("borko", "Борко", 0, "Warrior", "Kinetic", "Wildfang", 48, 3, "Undermine kills (every 5 s)", 0.10, "squad clash loss +", 1.1, "front"),
    ("alba", "Альба", 1, "Ranger", "Frost", "Wildfang", 26, 1.0, "shot damage (every 1.2 s; x1.5 vs Flying)", 0.15, "army volleys +", 1.4, "rear"),
    ("otto", "Отто", 1, "Guardian", "Kinetic", "Stoneheart", 60, 1, "kills per Block (Block every 5 s)", 0.10, "clash losses -", 1.0, "front"),
    ("taya", "Тая", 1, "Mage", "Rune", "Celestials", 26, 4, "Spell kills per squad (every 4 s)", 0.15, "volley status proc x", 1.2, "rear"),
    ("brant", "Брант", 2, "Warrior", "Plasma", "Stoneheart", 48, 3, "leap kills (every 5 s)", 0.10, "squad clash loss +", 1.1, "front"),
    ("teo", "Тео", 2, "Ranger", "Tech", "Celestials", 26, 1.0, "shot damage (every 1.2 s, homing)", 0.15, "army volleys +", 1.4, "rear"),
    ("olena", "Олена", 2, "Healer", "Frost", "Wildfang", 30, 3, "soldiers returned per pulse (every 3 s)", 0.12, "hazard losses -", 1.3, "right"),
    ("nimb", "Німб", 3, "Guardian", "Volt", "Celestials", 60, 2, "Lightning Rod damage x3 targets (per Block)", 0.10, "clash losses -", 1.0, "front"),
    ("dara", "Дара", 3, "Ranger", "Volt", "Dawn", 26, 1.0, "shot damage (every 1.2 s; harpoon every 3rd)", 0.15, "army volleys +", 1.4, "rear"),
    ("menhir", "Менгір", 3, "Mage", "Rune", "Stoneheart", 26, 4, "rune-strike kills per squad (every 4 s)", 0.15, "volley status proc x", 1.2, "right"),
    ("taras", "Тарас", 3, "Mage", "Rune", "Wildfang", 26, 4, "The Word kills per squad (every 4 s; pages cut on)", 0.15, "volley status proc x", 1.2, "rear"),
    ("snaryad", "Снаряд", 2, "Guardian", "Tech", "Dawn", 60, 2, "Sapper's Nose charge kills (per Block, every 6 s; + MARK)", 0.10, "clash losses -", 1.0, "front"),
    ("dovbush", "Довбуш", 3, "Warrior", "Kinetic", "Stoneheart", 48, 1.5, "bartka kills per squad x2 squads (every 5 s; + STAGGER)", 0.10, "squad clash loss +", 1.1, "front"),
]
# §4.2 survival knob (H2): ONE multiplier on the kit HP of every champion whose slot is front (the Guardian and Warrior
# templates), never per champion. The rows above keep the §4.3 template HP; CHAMPS below carries hp x FRONT_HP_MULT
# (rounded), which gen_heroes_data writes into ChampionData and §4.4 prints. Swept in LevelSim by champ_survival
# --run=1 --inv_fix=1 --front_hp=K (EXPECTED profile, re-baked TEAM_DEMAND); 1.0 = the template HP.
FRONT_HP_MULT = 1.1
CHAMPS = [row[:6] + (int(row[6] * FRONT_HP_MULT + 0.5) if row[12] == "front" else row[6],) + row[7:] for row in CHAMPS]
AURA_SHARE = {"front": 0.35, "left": 0.30, "right": 0.30, "rear": 0.25}
AURA_CAP = 0.40
# Twist budget P0_c (§2.3, §4.1, §4.4; owner decision 2026-10-10: the class strength stays and the budget follows the
# measured values; it replaces the design's 1.00 value / s): each champion's bare class template measured in LevelSim
# by scripts/dev/test_champion_twists.gd --budget at its own gem f0, Action tier, slot and element, the EXPECTED
# account's Champion Level, no relic: its kills + heals + soldiers saved + structure damage + what its statuses and
# holds did, per second of play (aura left out); Руді + Мейра pooled, levels 15-112 step 4, gates frozen, 50 runs.
# Every kit's KIT_INDEX = kit value / P0_c lies within 1 +- CHAMP_KIT_TOL. The test fails when a template moves past
# that band from its row (LevelSim, LevelGen, a class template, a kit's HP or Action, the EXPECTED account): re-measure
# and paste its CHAMP_P0 line (--emit), then gen_heroes_data.py --refresh. Measured 2026-10-10.
CHAMP_P0 = {"mila": 0.3940, "ivo": 0.0773, "borko": 0.0750, "alba": 0.2099, "otto": 0.1304, "taya": 0.2003,
            "brant": 0.2567, "teo": 0.4394, "olena": 0.4806, "nimb": 0.1478, "dara": 0.2442, "menhir": 0.3840,
            "taras": 0.3902, "snaryad": 0.1308, "dovbush": 0.2582}

# ------------------------------------------------------------------------------------------------ ult and attack rules
# The §6 hero sheets as data (§6.1-6.10, §6.28 Сірко, §6.29 Ольга; bot policies §10.4), read by gen_heroes_data.py
# --refresh into heroes_roster.json ("ults", "attacks", "kind_vocab") and HeroData.ULTS / ATTACKS. Numbers are the
# sheets' own, Form I = rank 1, Quartz-normalised: kills / breaks / heal / return / wall_hp (and an extra's kills /
# breaks) are further x ult power (ladder x Ult Rank x lv_ult); lengths, radii, rates and counts never scale (kit
# identity). A form is a DELTA merged onto everything below it (a dict merges key by key, anything else is replaced):
# the numbers at form k = base <- forms[0] <- ... <- forms[k - 2] (HeroData.ult_numbers). forms[i] is None where the
# native gem caps the ult below that form (Ladder.ult_form = min(native + 1, ...)). Attack beats merge the same way onto
# the rank-1 attack (HeroData.attack_numbers). "knobs" are the sheet's *(knob)* numbers (LevelSim tuning handles of
# test_kit_budget), as paths into the dict they sit next to. "name" on a form is the sheet's form name (en, a designer
# note): the Loc key ULT_<HERO>_F<n> exists only for a named form. Nothing here is UI copy.
#
# Readings where a sheet is ambiguous (each also in a comment below; the lead decides):
#   R1 rime: the frost wave starts at the hero ("a frost wave to 14 u": from 0).
#   R2 eyes form V: the CHILL to FREEZE lands at the fan's opening, with the BRAND of form I (no time on the sheet).
#   R3 spectrum form V: the ring of light and the machine buff start at the cast (no time on the sheet).
#   R4 doves: "every squad under the flight path loses a third of that (6)" = 6 in total per squad, not per wave.
#   R5 letter / doves: no §10.4 row; the policies are proposals from the sheets' tips (marked "proposed").
#   R6 letter form III: "the Stagger refreshed" = the form I Stagger (2.0 s) applied again.
#   R7 forgewall form IV: the landslide starts at the wall (only its far end, 10 u ahead, is on the sheet).
#   R8 doves: the sheet lists walls and gates among the structures that take the flock's breaks; a gate has a value,
#      not hp (KindView.gates_in), so how a gate takes "breaks" is the lead's call (e.g. hero hits).
ULT_SHAPES = {
    "timed": "a field around the hero for `duration` s; every `tick` s it hits everything with d in [hero - 0.5, "
             "hero + `range`] (the Meta-1 storm / rift; `ahead` places the rift's visual)",
    "waves": "`waves` bands `spacing` u deep, `gap` s apart, from `from` to `to` u ahead of the cast point; each band "
             "hits once",
    "drop": "an impact `ahead` u in front (at the hero's x with `at_x`), `radius` u: `pulses` hits `gap` s apart "
            "(one when absent)",
    "area": "a band from `from` to `to` u ahead, `width` u wide at the hero's x (null = the full bridge): hits once; "
            "its front runs from `from` to `to` in `sweep` s (at once when absent) and it stays `duration` s",
    "beam": "a corridor `width` u wide down the hero's x from `from` to `to` u ahead for `duration` s, hitting every "
            "`tick` s",
    "fan": "`rays` rays over `angle` degrees from the hero's x, `length` u long, for `duration` s; each ray hits every "
           "`tick` s (a squad takes at most `per_squad_max` rays per tick)",
    "wall": "a barrier `width` u wide, `ahead` u in front, that travels with the army for `duration` s: it absorbs "
            "(`absorb`), squads reaching it fight it first (`wall_hp`)",
    "ward": "a window of `duration` s on the army: soldiers lost meanwhile are recorded (x `record`) and at the close "
            "min(recorded, `return` + `return_pool` x revive pool) come back",
    "flock": "birds fly over the squads in `waves` waves `gap` s apart to every structure of `targets` within `reach` u "
             "ahead: each structure takes `breaks` (an equal share per wave), squads under the flight path `kills`",
}
ULT_FIELDS = {
    # geometry and time (never scale)
    "duration": "s the ult or the part lasts", "tick": "s between the hits of a lasting shape",
    "range": "u ahead a timed ult hits", "ahead": "u in front of the hero where the shape is placed",
    "from": "u ahead where the shape starts", "to": "u ahead where the shape ends",
    "width": "u across the bridge (null = the full bridge)", "radius": "u", "at_x": "placed at the hero's x",
    "follow": "follows the hero's x live", "moves": "travels with the army",
    "sweep": "s for an area's front to run from `from` to `to`", "waves": "bands / waves", "spacing": "u, band depth",
    "gap": "s between waves or pulses", "pulses": "hits of a drop", "rays": "rays of a fan", "angle": "degrees",
    "length": "u, ray length", "per_squad_max": "rays one squad takes per tick at most",
    "reach": "u ahead targets are sought", "delay": "s after the cast", "at": "when a part fires (ULT_TIMING)",
    "target": "what a part hits (ULT_TARGETS)", "targets": "structure kinds a flock seeks",
    "count": "targets / turrets", "leap_s": "s the visual leap out and back takes at most (logic x stays under the thumb)",
    # hits (kills / breaks x ult power)
    "kills": "soldiers removed per squad per hit", "breaks": "hp removed per structure per hit",
    "gate_hits": "hero hits on every gate in the shape per hit",
    "neg_gate_hits": "hero hits on every negative gate of the next gate row",
    "fortress": "at the siege the hit lands on the fortress (it takes `breaks`)",
    "flying": "also hits Flying squads", "pierce_shield": "ignores the Shielded pool",
    "flying_mult": "damage x on Flying squads", "ground": "s a Flying squad hit stays grounded",
    "ground_after": "a Flying squad hit stays grounded until the ult ends + this many s",
    "statuses": "status id (ArsenalData.STATUSES; seal = BRAND) -> stacks per hit (lengths: the status rule's)",
    "stagger_s": "s of STAGGER when the sheet gives it", "burn_s": "s of BURN when the sheet gives it",
    "freeze_s": "s of the FREEZE the CHILL stacks end in", "paint_s": "s the biggest squad hit stays PAINTED",
    "reveal": "u ahead hidden gates and Phantom squads are revealed (-1 = the whole screen)",
    "mark_phantoms": "the revealed Phantom squads are MARKed",
    "slow": "hazards, turrets, squads and clash losses run at 1 - slow while it lasts",
    "armor_time": "s the army ignores hazards and turrets", "hold": "s squads touching the hold area are held (no "
    "advance, no clash damage, STAGGERed)", "hold_width": "u, width of the hold area",
    "clash_loss": "squads hit lose this much more in clashes", "clash_loss_s": "s it lasts (null = their next clash)",
    "strip_s": "s squads caught fight as plain squads (Armored / Shielded off)",
    "silence_s": "s turrets on the path miss every shot",
    # army, champions and team (heal / return x ult power)
    "heal": "soldiers the army regains", "heal_pool": "share of the revive pool the army regains on top",
    "record": "x on the soldiers a ward records", "return": "base of a ward's return at the close",
    "return_pool": "share of the revive pool added to a ward's return cap",
    "revive": "fallen champions revived (1 = the first, -1 = all)", "revive_hp": "HP share they stand up with",
    "wall_hp": "HP of a wall (x ult power)", "wall_hp_mult": "x on wall_hp",
    "contact_breaks": "breaks on the barricade a wall absorbs",
    "absorb": "absorb kind (ABSORB_KINDS) -> count (-1 = all)",
    "dmg": "damage per shot", "period": "s between shots", "homing": "shots home",
    "volleys": "army volley damage + (bucket 2) while the blob centre is inside the field",
    "b2": "machine damage + (bucket 2, inside TEAM_B2_CAP)", "breaks_per_s": "breaks per second while it burns",
}
# Fields whose value is a dict of fields (a part of the ult); "status_at" is keyed by ULT_TIMING.
ULT_PARTS = {
    "extra": "the follow-up hit that carries the hero's second ult number (HeroData.HEROES.ult2)",
    "field": "a lingering zone", "turrets": "turrets on a wall",
    "status_at": "ULT_TIMING -> statuses put on squads at that moment ({target, reach | radius, statuses, ..._s})",
    "buff": "a timed team buff", "afterburn": "a struck structure keeps burning",
}
ULT_TIMING = {"cast": "when the ult is cast", "end": "when the ult ends / the ward closes",
              "delay": "`delay` s after the cast", "wave": "as one more wave after the last",
              "land": "where the flock lands (every struck structure)"}
ULT_TARGETS = {"biggest": "the `count` (1) biggest hostiles within `reach`", "biggest_squad": "the biggest squad in reach",
               "area": "the ult's own area again", "strip": "a strip `width` u wide from the ult's place to `to` u ahead",
               "all": "every squad on the screen", "reach": "every squad within `reach` u",
               "struck": "every squad within `radius` u of a struck structure",
               "farthest": "the fortress gate at the siege, else the farthest structure struck",
               "machines": "the fielded machines", "volleys": "the army's volleys (statuses on their targets)"}
# §10.4 bot policy vocabulary: a policy fires when ANY of its conditions holds.
POLICY_WHEN = {
    "squads": (["count", "reach", "from"], ">= count living squads with d in [hero + from, hero + reach] (from 0)"),
    "flying": (["reach"], "a Flying squad within reach"),
    "armored": (["reach"], "an Armored squad within reach"),
    "lane": (["count", "reach"], ">= count hostiles (squads and structures) in the hero's lane within reach"),
    "fan": (["count"], ">= count squads inside the ult's fan (its angle and length)"),
    "structures": (["count", "reach", "kinds"], ">= count structures of kinds within reach"),
    "hazards": (["reach", "kinds"], "a hazard row of kinds ([] = any) within reach"),
    "gate_row": (["reach", "hidden"], "the next gate row within reach (hidden: only while it has unrevealed values)"),
    "clash": (["within"], "a clash is on or starts within `within` s"),
    "siege": ([], "the fortress siege"),
    "army_loss": (["share", "window"], ">= share of the army lost in the last window s"),
    "champion_down": ([], "a champion has fallen"),
}
_STRUCTS = ["barricade", "turret", "geode", "fortress"]

ULTS = {
    "quake": {"hero": "titan", "ref": "§6.1", "shape": "waves", "main": "kills",
              "base": {"waves": 4, "spacing": 3.5, "gap": 0.18, "from": 1.0, "to": 15.0, "kills": 12, "breaks": 12,
                       "armor_time": 6.0},
              "forms": [None, None, None, None],
              "policy": {"ref": "§10.4", "any": [{"when": "structures", "count": 1, "reach": 12.0, "kinds": _STRUCTS},
                                                 {"when": "hazards", "reach": 6.0, "kinds": []}]}},
    "anchor": {"hero": "arin", "ref": "§6.2", "shape": "drop", "main": "kills",
               "base": {"ahead": 8.0, "at_x": True, "radius": 2.5, "kills": 22, "breaks": 22, "hold": 3.0,
                        "hold_width": 4.0, "gate_hits": 3},
               "forms": [None, None, None, None],
               # "a gate cluster <= 8 u ahead" read as the next gate row
               "policy": {"ref": "§10.4", "any": [{"when": "armored", "reach": 8.0},
                                                  {"when": "gate_row", "reach": 8.0, "hidden": False}]}},
    "storm": {"hero": "bolt", "ref": "§6.3", "shape": "timed", "main": "kills",
              "base": {"duration": 3.0, "tick": 0.25, "range": 18.0, "kills": 5, "breaks": 3, "gate_hits": 1},
              "forms": [{"name": None, "set": {"flying_mult": 1.5, "ground_after": 1.0, "statuses": {"jolt": 1}}},
                        None, None, None],
              "policy": {"ref": "§10.4", "any": [{"when": "squads", "count": 2, "reach": 16.0},
                                                 {"when": "flying", "reach": 16.0}]}},
    "rime": {"hero": "eira", "ref": "§6.4", "shape": "area", "main": "kills",
             # R1: the wave starts at the hero
             "base": {"from": 0.0, "to": 14.0, "width": None, "sweep": 0.6, "kills": 4, "statuses": {"chill": 3},
                      "freeze_s": 1.0, "heal": 5, "heal_pool": 0.25},
             "forms": [{"name": None, "set": {"revive": 1, "revive_hp": 0.5}}, None, None, None],
             "policy": {"ref": "§10.4", "any": [{"when": "clash", "within": 1.5}]}},
    "rift": {"hero": "seer", "ref": "§6.5", "shape": "timed", "main": "kills",
             "base": {"duration": 4.0, "tick": 0.5, "range": 16.0, "ahead": 7.0, "kills": 5, "breaks": 4, "slow": 0.6},
             "forms": [{"name": None, "set": {"statuses": {"seal": 1}}},
                       {"name": "Starsight", "set": {"reveal": 30.0, "gate_hits": 1}},
                       None, None],
             "policy": {"ref": "§10.4", "any": [{"when": "gate_row", "reach": 10.0, "hidden": True},
                                                {"when": "squads", "count": 3, "reach": 12.0}]}},
    "comet": {"hero": "iskar", "ref": "§6.6", "shape": "beam", "main": "kills",
              "base": {"at_x": True, "width": 1.6, "from": 2.0, "to": 30.0, "duration": 1.5, "tick": 0.25, "kills": 6,
                       "breaks": 5, "flying": True, "pierce_shield": True},
              "forms": [{"name": None, "set": {"flying_mult": 1.5, "ground": 2.0, "paint_s": 4.0}},
                        {"name": "Comet Tail", "set": {"follow": True, "gate_hits": 1}},
                        None, None],
              "policy": {"ref": "§10.4", "any": [{"when": "lane", "count": 3, "reach": 16.0}]}},
    "sunglaive": {"hero": "vesta", "ref": "§6.7", "shape": "drop", "main": "kills",
                  "base": {"ahead": 5.0, "radius": 6.0, "pulses": 4, "gap": 0.3, "kills": 10, "breaks": 10,
                           "statuses": {"burn": 1}},
                  "forms": [{"name": None, "set": {"clash_loss": 0.2, "clash_loss_s": 3.0}, "knobs": ["clash_loss"]},
                            {"name": "Sun Field", "set": {"field": {"duration": 4.0, "radius": 6.0,
                                                                    "statuses": {"burn": 1}, "volleys": 0.10}},
                             "knobs": ["field.volleys"]},
                            {"name": "Sunstride", "set": {"extra": {"at": "delay", "delay": 1.0, "target": "biggest",
                                                                    "reach": 20.0, "radius": 4.0, "kills": 8,
                                                                    "breaks": 8, "neg_gate_hits": 2, "leap_s": 0.6}}},
                            None],
                  "policy": {"ref": "§10.4", "any": [{"when": "squads", "count": 2, "reach": 6.0},
                                                     {"when": "siege"}]}},
    "forgewall": {"hero": "vartan", "ref": "§6.8", "shape": "wall", "main": "kills",
                  "base": {"ahead": 3.0, "width": 6.0, "duration": 5.0, "moves": True, "kills": 8,
                           "statuses": {"stagger": 1}, "wall_hp": 30, "contact_breaks": 10,
                           "absorb": {"turret": -1, "contact": 1}},
                  "forms": [{"name": None, "set": {"wall_hp_mult": 1.5}},
                            {"name": "Rivet Turrets", "set": {"turrets": {"count": 4, "dmg": 1, "period": 0.5,
                                                                          "homing": True, "flying": True,
                                                                          "statuses": {"mark": 1}}}},
                            # R7: the landslide starts at the wall
                            {"name": "Landslide", "set": {"extra": {"at": "end", "target": "strip", "to": 10.0,
                                                                    "width": 6.0, "kills": 8, "breaks": 8}}},
                            None],
                  "policy": {"ref": "§10.4", "any": [{"when": "hazards", "reach": 6.0, "kinds": ["turret", "blade"]}]}},
    "spectrum": {"hero": "lumen", "ref": "§6.9", "shape": "fan", "main": "kills",
                 "base": {"rays": 7, "angle": 60.0, "length": 16.0, "at_x": True, "duration": 2.5, "tick": 0.25,
                          "kills": 2, "breaks": 2, "per_squad_max": 2, "flying": True, "pierce_shield": True},
                 "forms": [{"name": None, "set": {"statuses": {"burn": 1}}},
                           {"name": None, "set": {"gate_hits": 1}},
                           {"name": "Crown Shards", "set": {"extra": {"at": "end", "target": "biggest", "count": 12,
                                                                      "kills": 4, "breaks": 4}}},
                           # R3: the ring of light and the machine buff start at the cast
                           {"name": "Second Dawn", "set": {"status_at": {"cast": {"target": "all",
                                                                                "statuses": {"seal": 1, "burn": 1}}},
                                                           "buff": {"target": "machines", "b2": 0.10,
                                                                    "duration": 6.0}}}],
                 "policy": {"ref": "§10.4", "any": [{"when": "fan", "count": 3}, {"when": "siege"}]}},
    "eyes": {"hero": "pava", "ref": "§6.10", "shape": "ward", "main": "return",
             "base": {"duration": 3.0, "record": 1, "return": 8, "return_pool": 0.30,
                      "status_at": {"cast": {"target": "reach", "reach": 16.0, "statuses": {"seal": 1}}}},
             "forms": [{"name": None, "set": {"revive": 1, "revive_hp": 0.5}},
                       {"name": "Double Count", "set": {"record": 2}},
                       {"name": "Eyes Wide", "set": {"extra": {"at": "end", "target": "all", "kills": 4, "reveal": -1.0,
                                                               "mark_phantoms": True}}},
                       # R2: the CHILL lands at the opening with the form I BRAND (CHILL cap 3 stacks = FREEZE)
                       {"name": "Plumage Rebirth", "set": {"revive": -1, "status_at": {"cast": {"statuses": {"chill": 3},
                                                                                             "freeze_s": 1.0}}}}],
             "policy": {"ref": "§10.4", "any": [{"when": "army_loss", "share": 0.25, "window": 3.0},
                                                {"when": "champion_down"}]}},
    "letter": {"hero": "sirko", "ref": "§6.28", "shape": "area", "main": "kills",
               "base": {"from": 3.0, "to": 15.0, "width": None, "duration": 2.0, "kills": 16, "breaks": 16,
                        "statuses": {"stagger": 1, "seal": 1}, "stagger_s": 2.0, "fortress": True},
               "knobs": ["kills"],
               "forms": [{"name": None, "set": {"to": 19.0, "clash_loss": 0.2, "clash_loss_s": None},
                          "knobs": ["clash_loss"]},
                         # R6: the Stagger refreshed = the form I Stagger again
                         {"name": "The Second Roar", "set": {"extra": {"at": "delay", "delay": 1.0, "target": "area",
                                                                       "kills": 8, "breaks": 8,
                                                                       "statuses": {"stagger": 1}, "stagger_s": 2.0}},
                          "knobs": ["extra.kills", "extra.breaks"]},
                         {"name": "Stripped of Armour", "set": {"strip_s": 5.0}},
                         {"name": "The Whole Sich Writes", "set": {"buff": {"target": "volleys", "duration": 5.0,
                                                                            "statuses": {"seal": 1, "mark": 1}}}}],
               # R5: no §10.4 row; from the tip "the densest row of squads" and the siege counterplay
               "policy": {"ref": "proposed (§6.28 tip)", "any": [{"when": "squads", "count": 2, "from": 3.0,
                                                                  "reach": 15.0}, {"when": "siege"}]}},
    "doves": {"hero": "olha", "ref": "§6.29", "shape": "flock", "main": "breaks",
              # R4: kills = 6 per squad under the path in total (a third of 18)
              "base": {"waves": 3, "gap": 0.4, "reach": 30.0, "targets": ["barricade", "turret", "wall", "gate"],
                       "fortress": True, "breaks": 18, "kills": 6, "statuses": {"burn": 1}, "burn_s": 3.0},
              "knobs": ["breaks"],
              "forms": [{"name": None, "set": {"flying_mult": 1.5, "ground": 2.0}},
                        {"name": "Four Revenges", "set": {"extra": {"at": "wave", "target": "biggest_squad", "kills": 8,
                                                                    "statuses": {"burn": 1}}},
                         "knobs": ["extra.kills"]},
                        {"name": "Sparrows from Every Yard", "set": {"silence_s": 3.0}},
                        {"name": "Iskorosten", "set": {"afterburn": {"target": "farthest", "duration": 4.0,
                                                                     "breaks_per_s": 3.0},
                                                       "status_at": {"land": {"target": "struck", "radius": 6.0,
                                                                           "statuses": {"stagger": 1},
                                                                           "stagger_s": 1.5}}},
                         "knobs": ["afterburn.breaks_per_s"]}],
              # R5: no §10.4 row; from the tip "save the ult for the siege" and the niche (barricade / turret rows)
              "policy": {"ref": "proposed (§6.29 tip)", "any": [{"when": "siege"},
                                                                 {"when": "structures", "count": 2, "reach": 30.0,
                                                                  "kinds": ["barricade", "turret"]}]}},
}

# Attacks (the sheets' Run line and Attack row): rate / dmg / range / splash / targets are the kit (KITS, copied by the
# generator); class traits (Cleave, Long sight +2, Mage proc, Bulwark, Mend) are TeamData-level rules in DOC
# HERO_CLASS_RUN, not repeated here. procs = id -> an every-Nth / on-event special; beats merge like forms.
ATTACK_PATTERNS = {
    "boulder": "a heavy shot with splash (Горан's rock, Вартан's rivet; HeroKinds.ATTACK_BOULDER)",
    "swing": "melee swings in an arc (`arc` u or `arc_deg` degrees)",
    "dart": "fast straight shots (HeroKinds.ATTACK_DART)", "orbs": "homing orbs (HeroKinds.ATTACK_ORBS)",
    "beam": "rays that ignore the Shielded pool",
}
ATTACK_FIELDS = {
    "rate": "attacks per second (kit)", "dmg": "damage per hit (kit)", "range": "u (kit; Rangers +2 Long sight)",
    "splash": "extra kills around a squad target (kit)", "targets": "targets / rays per cast (kit)",
    "arc": "u, width of a swing", "arc_deg": "degrees of a swing", "homing": "shots home",
    "pierce": "squads a shot passes through (-1 = the whole corridor)", "pierce_shield": "ignores the Shielded pool",
    "statuses": "status id (ArsenalData.STATUSES; seal = BRAND) -> proc per hit", "stagger_s": "s of STAGGER",
    "burn_s": "s of BURN", "mark_s": "s of MARK",
    "ground": "s a Flying squad hit stays grounded", "reground": "s before the same squad can be grounded again",
    "structure_mult": "damage x on structures", "reveal_rows": "hidden gate rows a gate hit reveals",
    "charge_mult": "x on charge-gate hits", "focus_mult": "x when spare rays converge on fewer targets",
    "drones": "ward-drones, each absorbs one turret shot at the army", "drone_recharge": "s a drone recharges",
    "drone_contact_cd": "s, shared cooldown of a drone absorbing a blade / barricade contact",
    "mend_share": "share of soldiers lost that feed the revive pool (Healer Mend)",
    "frozen_clash_loss": "the army's clash losses vs a squad she froze x (1 + this)",
    "vs_burning": "damage + on a burning squad (bucket 2)", "burn_jumps": "squads her BURN jumps to on a wipe",
    "burning_machines": "machine damage + on burning squads (bucket 2, inside TEAM_B2_CAP)",
    "burning_volleys": "army volley damage + on burning structures", "procs": "proc id -> its rule (ATTACK_PROCS)",
    # proc fields
    "on": "what triggers it (ATTACK_TRIGGERS)", "every": "every Nth trigger", "r": "u", "chains": "jumps a fork makes",
    "mult": "damage x", "soldiers": "soldiers back from the revive pool", "share": "share of the damage repeated",
    "kills": "soldiers removed per squad", "breaks": "hp removed per structure", "delay": "s",
    "depth": "u along the run", "duration": "s", "reach": "u ahead", "reveal": "u, Phantoms revealed within",
    "reveals": "reveals the Phantom it lands on", "rails": "parallel rails", "rail_dx": "u between a rail and x",
    "needs": "status the target must carry", "cd": "s cooldown", "kinds": "absorb kinds (ABSORB_KINDS)",
    "shield_cd": "s cooldown of the front-champion shield", "shield_ticks": "clash ticks the shield takes",
    "weaken": "the squad deals this much less clash damage", "weaken_s": "s the weaken lasts",
    "target": "farthest | farthest_structure", "fallback": "biggest_squad when no structure is in reach",
}
ATTACK_PROCS = {
    "fork": "chains to `targets` more within `r` (`chains` jumps)", "throw": "a throw to the `target` hostile within "
    "`reach` for x `mult`", "mend": "`soldiers` come back from the revive pool", "comet": "a bolt down the corridor",
    "eye": "plants an Eye: `soldiers` come back when that squad is wiped", "dove": "a dove to the `target` within "
    "`reach`", "echo": "repeats `share` of the hit on the next structure within `reach` behind",
    "burst": "an explosion `r` u at the target", "lance": "pierces the whole corridor for x `mult`",
    "bounce": "bounces to `targets` more within `r`", "mark": "MARKs the target", "ray": "+`targets` rays this cast",
    "strip": "a burning strip across the bridge", "double": "strikes twice", "flinch": "the next squad in the lane "
    "is STAGGERed", "guard": "intercepts one hit of `kinds` per `cd` s",
}
# What a wall / drone / feather can take for the army (KindView.absorb).
ABSORB_KINDS = {"turret": "a turret shot at the army", "blade": "a blade contact",
                "contact": "a blade or barricade contact"}
ATTACK_TRIGGERS = {"hit": "every hero hit (the default)", "structure": "hits on structures",
                   "break": "a structure he breaks", "kill": "a hit that kills", "wipe": "a squad he wipes"}

ATTACKS = {
    "titan": {"pattern": "boulder", "ref": "§6.1", "base": {"structure_mult": 1.5},
              "beats": {"3": {"set": {"statuses": {"stagger": 1.0}, "stagger_s": 0.4}},
                        "6": {"set": {"procs": {"echo": {"on": "structure", "every": 4, "share": 0.5, "reach": 4.0}}},
                              "knobs": ["procs.echo.share"]},
                        "9": {"set": {"procs": {"burst": {"on": "break", "breaks": 2, "r": 1.5}}},
                              "knobs": ["procs.burst.breaks"]}},
              "clips": {"attack_a": "throw", "attack_b": "ground slam", "b_on": None}},
    "arin": {"pattern": "swing", "ref": "§6.2",
             "base": {"arc": 1.5, "statuses": {"stagger": 1.0},
                      "procs": {"throw": {"every": 4, "target": "farthest", "reach": 11.0, "mult": 2.0}}},
             "beats": {"3": {"set": {"procs": {"throw": {"every": 3}}}},
                       "6": {"set": {"procs": {"throw": {"weaken": 0.15, "weaken_s": 3.0}}},
                             "knobs": ["procs.throw.weaken"]},
                       "9": {"set": {"procs": {"burst": {"every": 12, "r": 1.5, "kills": 6}}},
                             "knobs": ["procs.burst.kills"]}},
             "clips": {"attack_a": "overhead swing", "attack_b": "chain throw", "b_on": "throw"}},
    "bolt": {"pattern": "dart", "ref": "§6.3",
             "base": {"ground": 1.2, "reground": 4.0,
                      "procs": {"fork": {"every": 3, "targets": 1, "r": 4.0, "chains": 1}}},
             "beats": {"3": {"set": {"procs": {"fork": {"r": 5.0, "chains": 2}}}, "knobs": ["procs.fork.chains"]},
                       "6": {"set": {"procs": {"lance": {"every": 8, "mult": 2.0}}}, "knobs": ["procs.lance.mult"]},
                       "9": {"set": {"procs": {"fork": {"statuses": {"jolt": 1.0}}}}}},
             "clips": {"attack_a": "paw flick", "attack_b": "two-paw rail shot", "b_on": "lance"}},
    "eira": {"pattern": "beam", "ref": "§6.4",
             "base": {"pierce_shield": True, "statuses": {"chill": 0.5}, "procs": {"mend": {"every": 6, "soldiers": 1}}},
             "beats": {"3": {"set": {"mend_share": 0.25}},
                       "6": {"set": {"frozen_clash_loss": -0.15}},
                       "9": {"set": {"procs": {"mend": {"shield_cd": 10.0, "shield_ticks": 1}}}}},
             "clips": {"attack_a": "pluck", "attack_b": "two-hand chord (heal)", "b_on": "mend"}},
    "seer": {"pattern": "orbs", "ref": "§6.5",
             "base": {"homing": True, "reveal_rows": 1, "charge_mult": 1.5, "statuses": {"seal": 0.5}},
             "beats": {"3": {"set": {"procs": {"bounce": {"on": "kill", "targets": 1, "r": 3.0}}}},
                       "6": {"set": {"procs": {"mark": {"every": 8, "mark_s": 3.0, "reveal": 4.0}}}},
                       "9": {"set": {"reveal_rows": 2}}},
             # the sheet keeps her existing clips (run, idle, cast, ult): no attack_b
             "clips": {"attack_a": "cast", "attack_b": None, "b_on": None}},
    "iskar": {"pattern": "dart", "ref": "§6.6",
              "base": {"pierce": 1, "procs": {"comet": {"every": 6, "pierce": -1, "mult": 3.0, "pierce_shield": True,
                                                        "statuses": {"jolt": 1.0}}}},
              "beats": {"3": {"set": {"pierce": 2}},
                        "6": {"set": {"procs": {"comet": {"every": 5}}}},
                        "9": {"set": {"procs": {"comet": {"rails": 2, "rail_dx": 0.6}}}}},
              "clips": {"attack_a": None, "attack_b": "full-draw rail", "b_on": "comet"}},
    "vesta": {"pattern": "swing", "ref": "§6.7", "base": {"arc_deg": 120.0, "statuses": {"burn": 1.0}},
              "beats": {"3": {"set": {"procs": {"strip": {"every": 4, "depth": 3.0, "duration": 2.0,
                                                          "statuses": {"burn": 1.0}}}}},
                        "6": {"set": {"vs_burning": 0.10}},
                        "9": {"set": {"procs": {"burst": {"every": 10, "r": 4.0, "kills": 6,
                                                          "statuses": {"burn": 1.0}}}}}},
              "clips": {"attack_a": "sweep", "attack_b": "rising slash", "b_on": None}},
    "vartan": {"pattern": "boulder", "ref": "§6.8",
               "base": {"statuses": {"mark": 1.0}, "drones": 2, "drone_recharge": 6.0},
               "beats": {"3": {"set": {"drones": 3}},
                         "6": {"set": {"drone_contact_cd": 8.0}},
                         "9": {"set": {"procs": {"burst": {"on": "structure", "delay": 1.0, "dmg": 2, "r": 1.5}}}}},
               "clips": {"attack_a": "recoil", "attack_b": "shield bash", "b_on": None}},
    "lumen": {"pattern": "beam", "ref": "§6.9",
              "base": {"pierce_shield": True, "statuses": {"burn": 0.5}, "focus_mult": 1.5},
              "beats": {"3": {"set": {"procs": {"ray": {"every": 3, "targets": 1}}}},
                        "6": {"set": {"procs": {"lance": {"every": 5, "mult": 3.0}}}},
                        "9": {"set": {"burn_jumps": 2, "burning_machines": 0.08}}},
              "clips": {"attack_a": "prism flick", "attack_b": "two-hand lance", "b_on": "lance"}},
    "pava": {"pattern": "dart", "ref": "§6.10",
             "base": {"statuses": {"seal": 1.0}, "procs": {"eye": {"every": 5, "soldiers": 1}}},
             "beats": {"3": {"set": {"mend_share": 0.25, "procs": {"eye": {"every": 4}}}},
                       "6": {"set": {"procs": {"eye": {"statuses": {"mark": 1.0}, "reveals": True}}}},
                       "9": {"set": {"procs": {"guard": {"cd": 10.0, "kinds": ["turret", "blade"]}}}}},
             "clips": {"attack_a": "staff flick", "attack_b": "fan snap", "b_on": None}},
    "sirko": {"pattern": "swing", "ref": "§6.28", "base": {"arc": 1.5, "statuses": {"seal": 1.0}},
              "beats": {"3": {"set": {"procs": {"double": {"every": 4}}}},
                        "6": {"set": {"procs": {"flinch": {"on": "wipe", "needs": "seal", "statuses": {"stagger": 1.0},
                                                           "stagger_s": 1.0}}}},
                        "9": {"set": {"procs": {"burst": {"every": 10, "r": 3.0, "kills": 6, "statuses": {"seal": 1.0}}}},
                              "knobs": ["procs.burst.kills"]}},
              "clips": {"attack_a": "diagonal sabre cut", "attack_b": "turning double cut", "b_on": "double"}},
    "olha": {"pattern": "dart", "ref": "§6.29",
             "base": {"procs": {"dove": {"every": 6, "target": "farthest_structure", "reach": 20.0,
                                         "fallback": "biggest_squad", "statuses": {"burn": 1.0}, "burn_s": 3.0}}},
             "beats": {"3": {"set": {"pierce": 1}},
                       "6": {"set": {"burning_volleys": 0.15}, "knobs": ["burning_volleys"]},
                       "9": {"set": {"procs": {"dove": {"every": 5, "reach": 24.0}}}}},
             "clips": {"attack_a": "quick draw and loose", "attack_b": "looses a dove upward", "b_on": "dove"}},
}


def lad(n, g, f):
    return H.ladder(n, g, f)


def cap(n, g, f):
    return H.skill_cap(n, g, f)


def ultp(n, g, f, r):
    return lad(n, g, f) * (1 + H.ULT_RANK_STEP * (r - 1))


def main():
    print("# heroes_tables.py output (constants from heroes_sim.py v2)")
    print("q %.2f · a %.4f · NATIVE_MULT %s · RECUT_STEP %.4f · ULT %+.1f%%/rank · ATTACK %+.1f%%/rank · RALLY %+.0f%%/rank · "
          "lv_ult 1 + %.3f (L-1)" % (H.Q_NATIVE, H.FACET_STEP, [round(x, 4) for x in H.NATIVE_MULT], H.RECUT_STEP,
                                       100 * H.ULT_RANK_STEP, 100 * H.ATK_RANK_STEP, 100 * H.RALLY_RANK_STEP, H.LV_ULT))
    # ---- rank caps / forms / awakening by native
    print("\n## A. What each native can reach (caps f0 / f5 at its own gem; recut path to Opal f5)")
    print("| Native | caps f0/f5 | forms | Awakening (cap) | recut to Opal f5: cap / forms / Awakening cap |")
    print("|---|---|---|---|---|")
    for n in range(5):
        aw = ("born, cap %d" % H.awaken_cap(n, n)) if n >= H.BORN_AWAKENED_MIN else (
            "at Full facets, cap %d" % H.awaken_cap(n, n) if n >= 2 else "only after recut to Amethyst")
        rc = "—" if n == 4 else "%d / %s / %d" % (cap(n, 4, 5), " ".join(["I", "II", "III", "IV", "V"][:n + 1]), H.awaken_cap(n, 4))
        print("| %s | %d / %d | %s | %s | %s |" % (GEM[n], cap(n, n, 0), cap(n, n, 5), " ".join(["I", "II", "III", "IV", "V"][:n + 1]), aw, rc))
    # ---- hero kit table
    print("\n## B. Hero kits (stored = Quartz-normalised; eff = x NATIVE_MULT at the native gem, f0, Lv1, rank 1)")
    print("| Hero | Gem | Class | hp kit -> eff | rate/s | dmg kit -> eff | splash | range | targets | ult charge |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for (hid, uk, n, cls, el, fac, hp, rate, dmg, spl, rng, tg, ch) in KITS:
        m = H.NATIVE_MULT[n]
        print("| %s `%s` | %s | %s | %d -> %.1f | %.1f | %d -> %.2f | %d | %d | %d | %d |" % (
            uk, hid, GEM[n], cls, hp, hp * m, rate, dmg, dmg * m, spl, rng, tg, ch))
    # ---- per-hero rank tables
    print("\n## C. Per-hero rank tables (eff, Lv1, no gear; ult numbers x lv_ult(L) at higher levels: Lv30 x%.2f)" % (1 + H.LV_ULT * 29))
    for (hid, uk, n, cls, el, fac, hp, rate, dmg, spl, rng, tg, ch) in KITS:
        base, what = ULT[hid]
        top = cap(n, n, 5)
        ranks = list(range(1, top + 1))
        rec = cap(n, 4, 5) if n < 4 else None
        print("\n### %s (`%s`, native %s): native caps %d (f0) / %d (Full facets)%s" % (
            uk, hid, GEM[n], cap(n, n, 0), top, "" if rec is None else "; recut to Opal f5 cap %d (forms stay I-%s)" % (
                rec, ["I", "II", "III", "IV", "V"][n])))
        hdr = ["%d" % r for r in ranks] + (["recut Opal f5 r%d" % rec] if rec else [])
        print("| Rank | " + " | ".join(hdr) + " |")
        print("|---|" + "---|" * len(hdr))
        row = []
        for r in ranks:
            f = 0 if r <= cap(n, n, 0) else 5
            row.append("%.1f" % (base * ultp(n, n, f, r)))
        if rec:
            row.append("%.1f" % (base * ultp(n, 4, 5, rec)))
        print("| Ult: %s | %s |" % (what, " | ".join(row)))
        if hid in ULT2:
            b2, w2, from_r = ULT2[hid]
            row = []
            for r in ranks:
                f = 0 if r <= cap(n, n, 0) else 5
                row.append("%.1f" % (b2 * ultp(n, n, f, r)) if r >= from_r else "—")
            if rec:
                row.append("—")
            print("| Ult: %s | %s |" % (w2, " | ".join(row)))
        frow = []
        for r in ranks:
            fm = H.ult_form(n, r)
            frow.append(["I", "II", "III", "IV", "V"][fm - 1])
        if rec:
            frow.append(["I", "II", "III", "IV", "V"][H.ult_form(n, rec) - 1])
        print("| Ult form | %s |" % " | ".join(frow))
        row = []
        for r in ranks:
            f = 0 if r <= cap(n, n, 0) else 5
            row.append("%.2f" % (dmg * lad(n, n, f) * (1 + H.ATK_RANK_STEP * (r - 1))))
        if rec:
            row.append("%.2f" % (dmg * lad(n, 4, 5) * (1 + H.ATK_RANK_STEP * (rec - 1))))
        print("| Attack dmg per hit | %s |" % " | ".join(row))
        brow = [("beat %d" % r) if r in H.ATK_BEATS else "" for r in ranks] + (
            [", ".join("%d" % b for b in H.ATK_BEATS if rec >= b)] if rec else [])
        print("| Attack beats | %s |" % " | ".join(brow))
        hook, rb, rlab = RALLY[hid]
        row = []
        for r in ranks:
            f = 0 if r <= cap(n, n, 0) else 5
            v = rb * lad(n, n, f) * (1 + H.RALLY_RANK_STEP * (r - 1))
            row.append(("%.1f" % v) if rb >= 1 else ("%.3f" % v))
        if rec:
            v = rb * lad(n, 4, 5) * (1 + H.RALLY_RANK_STEP * (rec - 1))
            row.append(("%.1f" % v) if rb >= 1 else ("%.3f" % v))
        print("| Rally `%s`: %s | %s |" % (hook, rlab, " | ".join(row)))
    # ---- champions
    print("\n## D. Champions (kit x ladder x cl(L) x relic; aura value capped at %.2f, effect = value x slot share %s)" % (
        AURA_CAP, AURA_SHARE))
    print("| Champion | Gem | Class | Slot | HP native f0 Lv1 / f5 Lv20 / recut Topaz f5 Lv20 | Action: %s | Aura value -> effect (f0 Lv1 / f5 Lv20 relic+12) | Action tier |" % "native f0 Lv1 / f5 Lv20 / recut Topaz f5 Lv20")
    print("|---|---|---|---|---|---|---|---|")
    cl20 = 1 + H.CL_STEP * 19
    rel12 = 1 + H.C_RELIC[0] + H.C_RELIC[1] * 12
    for (cid, uk, n, cls, el, fac, hp, act, alab, av, aulab, rad, slot) in CHAMPS:
        m0 = lad(n, n, 0)
        m5 = lad(n, n, 5) * cl20
        mr = lad(n, 3, 5) * cl20 if n < 3 else None
        hps = "%.0f / %.0f / %s" % (hp * m0, hp * m5, ("%.0f" % (hp * mr)) if mr else "—")
        acts = "%s: %.2f / %.2f / %s" % (alab, act * m0, act * m5, ("%.2f" % (act * mr)) if mr else "—")
        sh = AURA_SHARE[slot]
        v0 = min(AURA_CAP, av * m0)
        v5 = min(AURA_CAP, av * m5 * rel12)
        aus = "%s %.3f -> %.1f%% / %.3f -> %.1f%%" % (aulab, v0, 100 * v0 * sh, v5, 100 * v5 * sh)
        print("| %s `%s` | %s | %s | %s | %s | %s | %s | %s |" % (uk, cid, GEM[n], cls, slot, hps, acts, aus,
                                                              ["I", "II", "III", "IV"][n] + (" (recut keeps it)" if n < 3 else "")))
    print("\nChampion Level cl(L) = 1 + %.2f (L - 1): Lv20 x%.2f · relic +12 x%.2f · Action tier step +%.0f%% per native gem" % (
        H.CL_STEP, cl20, rel12, 100 * H.ACTION_TIER_STEP))
    # ---- twist budget
    print("\n## E. Twist budget P0_c: the bare class template measured in LevelSim, value / s (CHAMP_P0; the champion")
    print("it was measured on: its gem f0, Action tier, slot and element; aura left out)")
    print("| Class | %s |" % " | ".join("%s (%s)" % (GEM[n], ["I", "II", "III", "IV"][n]) for n in range(4)))
    print("|---|---|---|---|---|")
    for cls in ("Warrior", "Ranger", "Mage", "Guardian", "Healer"):
        cells = []
        for n in range(4):
            got = ["%.4f %s (%s)" % (CHAMP_P0[c[0]], c[1], c[12]) for c in CHAMPS if c[3] == cls and c[2] == n]
            cells.append(" · ".join(got) or "—")
        print("| %s | %s |" % (cls, " | ".join(cells)))


if __name__ == "__main__":
    main()
