#!/usr/bin/env python3
"""Crystal Rush — Heroes & Champions systems + economy sim, v2 (heroes/heroes_design.md §8; v1 = heroes_sim_v1.py).

v2 applies the critics' accepted findings (heroes/decision_log.md): q 1.08 / a 0.0073, F-CAP skill caps, F-AWK2 (native
Amethyst/Topaz/Opal born awakened (H1 gate F1), Awakening +4%/rank), Ult +6%/rank, Attack +1%/rank, LV_ULT 0.035, coin-free hero axes
(skill ranks = Tomes only, recut = fragments only, Workshop = Star Ore only), Tome income ~x0.5, one material
(Star Ore), Feats pay Tomes only, Focus = exactly 60% of its gem, owned Seal pick = 2 x DUP, welcome x10 Topaz+ rule,
champions at L14 and the Portal at L20, CeremonyData, TEAM_B2_CAP 0.20, champion uptime 0.94, migration lump grant,
Chronicle Tome sink, rule-#3 tolerance grid, constants exported to heroes_consts.json.

Pure stdlib. Imports economy_sim.py (Meta-1 v2 sim, same folder) READ-ONLY and extends its Player with:
  rule #3 ladder (framework §2), Facets/Recut (§3.1), Hero Sync and Champion Level (§3.2), skill ranks + Tomes
  (§3.3), Workshop gear (§3.5), team synergy (§4.4), Champions (§6), Portal + Seals + pity (§7.1), Hero Chests
  (§7.2), new income nodes, hero feats, the EXPECTED-profile demand re-bake, and long-horizon milestones.

Every number quoted in heroes_design.md (v2) comes from this file's output (heroes_sim_output.txt) or from
heroes_tables.py, which imports this file's constants.

Run:  PYTHONHASHSEED=0 python3 heroes_sim.py      full (~25 min; seeded, reproducible)
      python3 heroes_sim.py --quick         fewer seeds (tuning)
      python3 heroes_sim.py --section ladder|portal|chest|campaign|long|all
      python3 heroes_sim.py ... --export PATH   also write the constants (export_consts) to PATH
Repo copy (tools/, WS-A): identical to the design sim except that it imports economy_sim.py from its own folder and
writes the constants only with --export (tools/data/heroes_consts.json is refreshed by tools/gen_heroes_data.py).
Exit code 1 if any invariant fails.
"""
from __future__ import annotations

import argparse
import collections
import itertools
import json
import math
import os
import random
import statistics
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import economy_sim as E          # noqa: E402  (Meta-1 sim, read-only)

# =============================================================================================
# 1. GEMS AND THE RULE #3 LADDER (framework §1, §2 — formulas FROZEN, numbers DEFAULT (S))
# =============================================================================================
G = ["C", "R", "E", "L", "M"]
GI = {g: i for i, g in enumerate(G)}
GEM_UK = ["Кварц", "Сапфір", "Аметист", "Топаз", "Опал"]
GEM_EN = ["Quartz", "Sapphire", "Amethyst", "Topaz", "Opal"]

Q_NATIVE = 1.08                 # NATIVE_MULT ratio per native gem (v1: 1.09; S's CI-4 lever, critique F1/F7)
FACET_STEP = 0.0073             # +0.73% per Facet (Грань); 1 + 5a = 1.0365 <= 0.96 x 1.08 = 1.0368 (critique m5)
F = 5                           # FACETS_PER_GEM (FROZEN)
CEILING = 0.96                  # FROZEN
NATIVE_MULT = [Q_NATIVE ** i for i in range(5)]
RECUT_STEP = 1 + F * FACET_STEP
assert RECUT_STEP <= CEILING * Q_NATIVE + 1e-12, "Ladder.check(): 1 + F*a <= CEILING*q"


def ladder(n: int, g: int, f: int) -> float:
    return NATIVE_MULT[n] * RECUT_STEP ** (g - n) * (1 + FACET_STEP * f)


SKILL_BASE = [2 + 2 * i for i in range(5)]          # FROZEN


def skill_cap(n: int, g: int, f: int) -> int:
    """F-CAP (critique M3, owner sign-off): a recut is always exactly ONE cap below a native of its CURRENT gem."""
    return SKILL_BASE[g] - (1 if g > n else 0) + (1 if f == F else 0)


FORM_AT_RANK = [1, 3, 5, 7, 9]                      # FROZEN


def ult_form(n: int, rank: int) -> int:
    return min(n + 1, sum(1 for r in FORM_AT_RANK if rank >= r))


AWAKEN_MIN_GEM = 2                                  # Аметист (FROZEN)
AWAKEN_CAP = {2: 2, 3: 3, 4: 4}                     # FROZEN


# F-AWK2: native heroes from this gem up are born awakened. H1 gate (review F1): Amethyst (2), not Topaz (3). With 3, a
# Sapphire recut to Amethyst at Full facets opened Awakening while a native Amethyst at 0-3 facets had none yet, and the
# recut beat it (1.0225 at Lv30, 16 states): the ladder gap at f5 vs f0 (0.9947) is smaller than one Awakening rank.
BORN_AWAKENED_MIN = 2


def can_awaken(n: int, g: int, f: int) -> bool:
    """F-AWK2 (critique B2/X1, owner sign-off; H1 gate F1): Awakening opens at Full facets in Amethyst+, and native
    Amethyst / Topaz / Opal heroes hold it from the moment they are obtained (rank 1 at f0)."""
    return g >= AWAKEN_MIN_GEM and (f == F or (g == n and n >= BORN_AWAKENED_MIN))


def awaken_cap(n: int, g: int) -> int:
    if g < AWAKEN_MIN_GEM:
        return 0
    return AWAKEN_CAP[g] if g == n else AWAKEN_CAP[g] - 1


HERO_MAX_GEM, CHAMP_MAX_GEM = 4, 3

# ---- hero power index (HeroesMeta.power; 1.0 = a Quartz hero, Lv1, rank 1, no gear = the Meta-1 Lv1 hero) ----
LV_DMG, LV_HP, LV_RATE = 0.035, 0.04, 0.01          # Meta-1 EconData.HERO, kept (FROZEN)
LV_ULT = 0.036                  # CI-1: ult power level term; 0.036 keeps the no-loss migration at Ult +5%/rank (Titan Lv5)
U_SHARE = 0.30                  # share of a hero's run contribution that comes from the ult
ULT_RANK_STEP = 0.05            # +5% ult effect per Ult rank (v1 0.08; critique F2/F7 proposed 0.06; v2 measured margin)
RALLY_RANK_STEP = 0.10          # +10% Rally value per Rally rank (DEFAULT S, kept)
ATK_RANK_STEP = 0.01            # Attack: +1% hero damage per rank (v1 0.015; critique F5/F7)
ATK_BEATS = (3, 6, 9)           # rule beats (R); each budgeted as +4% hero effectiveness
ATK_BEAT = 0.01
FORM_STEP = 0.03                # each ult form above I budgeted as +3% ult effectiveness
HP_W = 0.05                     # weight of hero HP in the index (HP keeps the hero alive at army 0)
AWK_STEP = 0.04                 # Awakening: +4% hero effectiveness per rank (band +-0.5 pp, LevelSim-measured)
RELIC_BEAT = 0.03               # each relic beat (+4/+8/+12) budgeted as +3%
SET4_VALUE = 0.05               # 4-piece faction rule budgeted as +5% hero effectiveness
RALLY_W = 0.03                  # Rally: +0.03 army-term units at Quartz rank 1 (x ladder x rank)

NO_SYN = {"rate": 1.0, "charge": 1.0, "ultp": 1.0, "army": 0.0, "cel": 0.0, "aff": {}, "champ_all": 1.0,
          "champ_cls": {}, "ids": ()}


def hero_index(n, g, f, L, sk, gear, relic_beats=0, set4=False, syn=NO_SYN):
    ult, atk, rally, awk = sk
    lad = ladder(n, g, f)
    atk_m = 1 + ATK_RANK_STEP * (atk - 1) + ATK_BEAT * sum(1 for b in ATK_BEATS if atk >= b)
    dmg = (1 + LV_DMG * (L - 1)) * (1 + gear["dmg"]) * atk_m * syn["rate"]
    form = ult_form(n, ult)
    ultp = ((1 + LV_ULT * (L - 1)) * (1 + ULT_RANK_STEP * (ult - 1)) * (1 + gear["ult"]) *
            (1 + LV_RATE * (L - 1)) * (1 + gear["charge"]) * (1 + FORM_STEP * (form - 1)) * syn["charge"] * syn["ultp"])
    hp = 1 + HP_W * ((1 + LV_HP * (L - 1)) * (1 + gear["hp"]) - 1)
    return (lad * ((1 - U_SHARE) * dmg + U_SHARE * ultp) * hp * (1 + AWK_STEP * awk) *
            (1 + RELIC_BEAT * relic_beats) * (1 + (SET4_VALUE if set4 else 0.0)))


def hero_sim_h(n, g, f, L, sk, gear, relic_beats=0, set4=False, syn=NO_SYN):
    """The sim's hero term: Meta-1's level curve x the RELATIVE multiplier of every new axis (gem ladder, facets,
    ranks, forms, Awakening, gear, relic, set, synergy) at the same level. A Quartz f0 rank-1 hero without gear
    therefore equals Meta-1's hero term exactly (the Meta-1 sim counted level damage only)."""
    return (1 + LV_DMG * (L - 1)) * hero_index(n, g, f, L, sk, gear, relic_beats, set4, syn) / meta1_index(L)


def meta1_index(L):
    """The same index for the Meta-1 hero at level L: no gem, Ult Rank I-IV from level (+20% per rank at Lv1/5/15/25),
    so any ult growth the new system adds beyond Meta-1 is counted as new hero power in the sim."""
    rank = sum(1 for t in (1, 5, 15, 25) if L >= t)
    dmg = 1 + LV_DMG * (L - 1)
    ultp = (1 + 0.20 * (rank - 1)) * (1 + LV_RATE * (L - 1))
    hp = 1 + HP_W * ((1 + LV_HP * (L - 1)) - 1)
    return ((1 - U_SHARE) * dmg + U_SHARE * ultp) * hp


ZERO_GEAR_C = {"dmg": 0.0, "hp": 0.0, "ult": 0.0, "charge": 0.0}


def rally_value(n, g, f, rank, dawn4=False):
    return RALLY_W * ladder(n, g, f) * (1 + RALLY_RANK_STEP * (rank - 1)) * (1.3 if dawn4 else 1.0)


# ---- champions (framework §6): ladder x Champion Level x relic x Action tier (native, fixed) ----
CL_STEP = 0.04                  # cl(L) = 1 + 0.04 (L - 1)
ACTION_TIER_STEP = 0.04         # Action tier I..IV = native gem + 1 (fixed at birth)
C_RELIC = (0.03, 0.01)          # champion relic: +3% +1%/rank on HP, Action power, Aura (+12 = +15%)


def champ_index(n, g, f, cl, relic_rank=-1, mult=1.0):
    r = relic_rank
    relic = 0.0 if r < 0 else C_RELIC[0] + C_RELIC[1] * r
    beats = 0 if r < 0 else sum(1 for b in (4, 8, 12) if r >= b)
    return (ladder(n, g, f) * (1 + CL_STEP * (cl - 1)) * (1 + relic) * (1 + RELIC_BEAT * beats) *
            (1 + ACTION_TIER_STEP * n) * mult)


# =============================================================================================
# 2. ROSTER SLOTS (framework §11; ids h02..c12 until R names them)
# =============================================================================================
HEROES = {
    "titan": dict(n=0, cls="guardian", el="kinetic", fac="stoneheart", starter=4),
    "arin": dict(n=0, cls="warrior", el="kinetic", fac="dawn"),
    "bolt": dict(n=1, cls="ranger", el="volt", fac="wildfang", starter=0),
    "eira": dict(n=1, cls="healer", el="frost", fac="dawn"),
    "seer": dict(n=2, cls="mage", el="rune", fac="wildfang", starter=24),
    "iskar": dict(n=2, cls="ranger", el="volt", fac="celestial"),
    "vesta": dict(n=3, cls="warrior", el="plasma", fac="dawn"),
    "vartan": dict(n=3, cls="guardian", el="tech", fac="stoneheart"),
    "lumen": dict(n=4, cls="mage", el="plasma", fac="celestial"),
    "pava": dict(n=4, cls="healer", el="rune", fac="wildfang"),
}
STARTERS = ("titan", "bolt", "seer")
PAID_HERO_SKUS = ()            # v2: NO hero SKUs and no Hero Editions at launch (critique B1 / X2; two-track rule)
CHAMPS = {
    "mila": dict(n=0, cls="healer", el="tech", fac="dawn"),
    "ivo": dict(n=0, cls="guardian", el="plasma", fac="dawn"),
    "borko": dict(n=0, cls="warrior", el="kinetic", fac="wildfang"),
    "alba": dict(n=1, cls="ranger", el="frost", fac="wildfang"),
    "otto": dict(n=1, cls="guardian", el="kinetic", fac="stoneheart"),
    "taya": dict(n=1, cls="mage", el="rune", fac="celestial"),
    "brant": dict(n=2, cls="warrior", el="plasma", fac="stoneheart"),
    "teo": dict(n=2, cls="ranger", el="tech", fac="celestial"),
    "olena": dict(n=2, cls="healer", el="frost", fac="wildfang"),
    "nimb": dict(n=3, cls="guardian", el="volt", fac="celestial"),
    "dara": dict(n=3, cls="ranger", el="volt", fac="dawn"),
    "menhir": dict(n=3, cls="mage", el="rune", fac="stoneheart"),
    "taras": dict(n=3, cls="mage", el="rune", fac="wildfang"),     # C23, added after launch (heroes_design.md §6.25)
    "snaryad": dict(n=2, cls="guardian", el="tech", fac="dawn"),   # C24, added after launch (heroes_design.md §6.26)
    "dovbush": dict(n=3, cls="warrior", el="kinetic", fac="stoneheart"),  # C25, added after launch (heroes_design.md §6.27)
}
SCRIPTED_FIRST = {"bolt": "alba", "titan": "otto"}
SCRIPTED_FIRST_DEFAULT = "otto"
SCRIPTED_SECOND = "mila"
FACTIONS = ["dawn", "wildfang", "stoneheart", "celestial"]
HOME = {1: "dawn", 2: "wildfang", 3: "wildfang", 4: "stoneheart", 5: "stoneheart", 6: "dawn", 7: "celestial"}

# =============================================================================================
# 3. PROGRESSION TABLES (HeroData.PROGRESS, ChampionData.CHAMP_LEVEL; DEFAULT (S) = final values)
# =============================================================================================
DUP_FRAGS = [10, 15, 25, 50, 100]
FACET_FRAGS = [[5, 5, 10, 10, 20], [10, 10, 15, 15, 25], [15, 15, 20, 20, 30], [20, 20, 30, 30, 50],
               [30, 30, 40, 40, 60]]
RECUT_FRAGS = [40, 60, 100, 150]               # C->R, R->E, E->L, L->M
RECUT_COINS = [0, 0, 0, 0]       # v2 F-COIN0: recut costs fragments only (critique M4)
OVERFLOW_FRAGS_PER_TOME = 20    # v2: 20 fragments at the absolute max = 1 Tome (v1 10; critique M6)
TOME_COST = [0, 2, 3, 5, 8, 12, 16, 20, 25, 30, 40]   # index r = price of rank r -> r+1


def skill_coins(r: int) -> int:
    return 0                    # v2 F-COIN0: skill ranks cost Tomes only (critique M4)


HERO_SYNC_BEHIND = 3
QUARTZ_TO_OPAL = 925           # fragments for a Quartz hero f0 -> Opal f5 (checked in section 2)
RECUT_EAGER = 2.0               # sim only: recut when its coin price <= half the coins held
COLLECTOR_SHARE = 0.25          # sim only: a player recuts a non-team favourite when it costs <= 15% of the coins held
GEAR_SLOT_AT = {"weapon": 1, "armour": 4, "charm": 8, "relic": 12}
CHAMP_LEVEL_MAX = 20


def champ_level_cost(L: int) -> int:                  # L -> L+1
    return int(round(40 * L ** 1.5 / 10.0)) * 10


UNLOCK_AT = {"champions": 14, "portal": 20, "seer": 24, "skills": 30, "workshop": 32, "slot3": 40}   # v2 (critique M7)
TOPAZ_FLOOR_LEVEL = 49          # EXPECTED may include a fresh Topaz hero from here (Portal hard pity, slowest archetype)

# =============================================================================================
# 4. WORKSHOP / GEAR (GearData)
# =============================================================================================
SLOTS = ["weapon", "armour", "charm"]
ITEMS = [fac + "_" + s for fac in FACTIONS for s in SLOTS]
ITEM_STAT = {"weapon": {"dmg": (0.01, 0.005, (0.01, 0.01, 0.02))},          # +12 = +11%
             "armour": {"hp": (0.02, 0.008, (0.01, 0.01, 0.02))},           # +12 = +15.6%
             "charm": {"ult": (0.01, 0.005, (0.01, 0.01, 0.01)), "charge": (0.01, 0.003, (0.005, 0.005, 0.01))}}
HERO_RELIC_STAT = {"dmg": (0.01, 0.001), "hp": (0.02, 0.0025)}       # +12: dmg +2.2%, hp +5%
SET2 = {"dawn": ("dmg", 0.03), "wildfang": ("charge", 0.05), "stoneheart": ("hp", 0.05), "celestial": ("ult", 0.05)}
CRAFT = {"item": (0, 40), "hero_relic": (0, 60), "champ_relic": (0, 30)}   # v2: (coins, Star Ore) — Star Ore only
TEMPER_MAX = 12
TIER_AT = [0, 3, 6, 9, 12]                            # item gem tier by rank band


def temper_cost(kind: str, r: int) -> tuple:          # r -> r+1: (coins, Star Ore); v2: no coins
    c, m = 0, 8 + 4 * r
    if kind == "champ_relic":
        return c // 2, (m + 1) // 2
    return c, m


def item_stats(slot: str, r: int) -> dict:
    out = {}
    for st, (base, per, beats) in ITEM_STAT[slot].items():
        out[st] = base + per * r + sum(b for k, b in zip((4, 8, 12), beats) if r >= k)
    return out


def temper_cap(world_reached: int) -> int:
    return min(TEMPER_MAX, 2 * world_reached)


# boss first clear (campaign L8..56, Invasion L64..112) -> trophy item (ready at +3, or +3 ranks)
TROPHIES = {8: "dawn_weapon", 16: "wildfang_charm", 24: "wildfang_weapon", 32: "stoneheart_armour",
            40: "stoneheart_charm", 48: "dawn_armour", 56: "celestial_weapon"}
for _b, _it in list(TROPHIES.items()):
    TROPHIES[_b + 56] = _it                           # the night boss tempers its day trophy (+3 ranks)
TROPHY_RANK = 3


ORE_PER_WIN = {"campaign": [2, 3, 3, 4, 4, 5, 7], "invasion": [3, 4, 4, 5, 5, 5, 9]}   # Star Ore per first-clear win


def mat_per_win(world: int, mode: str) -> float:
    return float(ORE_PER_WIN["campaign" if mode == "campaign" else "invasion"][world - 1])


MAT_BOSS = {"campaign": 14, "invasion": 20}           # Star Ore per world-boss first clear
ORE_WEEKLY, ORE_EXP5 = 10, 10                         # weekly 5/5, Expedition 5/5
REPLAY_WORLD = {"dawn": 6, "wildfang": 3, "stoneheart": 5, "celestial": 7}   # best home world to replay per faction
REPLAY_MAT_SHARE = 0.6
ORE_INCOME = 1.0                # v2: explicit Star Ore table above (~0.45 x the v1 per-faction amounts; one pool feeds every item)

# =============================================================================================
# 5. TEAM SYNERGY (TeamData; framework §4.4)
# =============================================================================================
FACTION_TIERS = {"dawn": [0, 0.02, 0.04, 0.07],         # army term (+4/+8/+14 reserves; 2 soldiers = 0.01)
                 "wildfang": [1.0, 1.06, 1.12, 1.20],    # ult charge x
                 "stoneheart": [0, 0.02, 0.04, 0.06],    # army term (-15/-30/-45% hazard losses)
                 "celestial": [0, 0.03, 0.06, 0.10]}     # machine damage, bucket 2
AFFINITY_PER, AFFINITY_CAP, TEAM_B2_CAP, B2_EFF = 0.03, 0.09, 0.20, 0.8   # v2 TEAM_B2_CAP 0.20 (critique m7)
CLASS_PAIR = {"warrior": ("army", 0.03), "ranger": ("rate", 1.05), "mage": ("ultp", 1.08),
              "guardian": ("champ_all", 1.05), "healer": ("army", 0.02)}


_SYN_CACHE = {}


def synergy(members: list) -> dict:
    key = tuple(members)
    s = _SYN_CACHE.get(key)
    if s is None:
        s = _SYN_CACHE[key] = _synergy(members)
    return s


def _synergy(members: list) -> dict:
    """members: list of (cls, el, fac). Counts are native-blind (framework W6)."""
    syn = {"rate": 1.0, "charge": 1.0, "ultp": 1.0, "army": 0.0, "cel": 0.0, "aff": {}, "champ_all": 1.0,
           "champ_cls": {}, "ids": []}
    if len(members) < 2:
        return syn
    fc = collections.Counter(m[2] for m in members)
    for fac, c in fc.items():
        tier = 3 if c >= 4 else 2 if c >= 3 else 1 if c >= 2 else 0
        if not tier:
            continue
        syn["ids"].append("fac_%s_%d" % (fac, tier))
        v = FACTION_TIERS[fac][tier]
        if fac in ("dawn", "stoneheart"):
            syn["army"] += v
        elif fac == "wildfang":
            syn["charge"] *= v
        else:
            syn["cel"] += v
    cc = collections.Counter(m[0] for m in members)
    for cls, c in cc.items():
        if c < 2:
            continue
        syn["ids"].append("cls_" + cls)
        k, v = CLASS_PAIR[cls]
        if k == "army":
            syn["army"] += v
        elif k == "champ_all":
            syn["champ_all"] *= v
            syn["champ_cls"]["guardian"] = 1.10        # Block cooldown -20%
        else:
            syn[k] *= v
            if cls == "ranger":
                syn["champ_cls"]["ranger"] = 1.10      # Ranger champions' cooldown -15%
    ec = collections.Counter(m[1] for m in members)
    for el, c in ec.items():
        syn["aff"][el] = min(AFFINITY_CAP, AFFINITY_PER * c)
    if syn["aff"]:
        syn["ids"].append("affinity")
    return syn


# =============================================================================================
# 6. PORTAL (PortalData) — earned only
# =============================================================================================
PORTAL_BASE = {"C": 0.55, "R": 0.28, "E": 0.12, "L": 0.04, "M": 0.01}
PITY_E_HARD = 10
PITY_L_SOFT, PITY_L_STEP, PITY_L_HARD = 21, 0.07, 30
OPAL_SHARE_IN_L = 0.20
FOCUS_TOTAL = 0.60              # v2: the Focus character gets exactly 60% of its gem's results (critique M1 / X15)
SEAL_PRICES = {"E": 40, "L": 100, "M": 200}
# CeremonyData (heroes_design §9.9): ONE table read by the UI timelines and by this sim (critique X4)
CER = {"prologue": 0.6, "x1": [1.2, 1.8], "walkout": {2: 2.6, 3: 3.6, 4: 5.0}, "short_walkout": 1.2,
       "x10_frame": 1.2, "batch_crack": 0.5, "seal_pick_new": 1.8, "seal_pick_owned": 1.2,
       "chest_inline": 1.6, "chest_inline_dup": 1.2, "cameo": 1.5, "cameo_next": 1.0, "vault_batch": 0.3,
       "facet": 0.35, "full_facets": 1.6, "recut": 3.0, "skill": 0.6, "form": 1.6, "awaken": 3.0,
       "hero_level": 0.35, "clevel": 0.35, "craft": 1.2, "temper": 0.35, "temper_tier": 1.2, "temper_beat": 1.2,
       "chronicle": 0.35, "migration_summary": 3.0}
WALKOUT_S = [CER["x1"][0], CER["x1"][1]] + [CER["prologue"] + CER["walkout"][g] for g in (2, 3, 4)]   # x1, new hero

BEACON = {"first_clear": 0.20, "boss": 2, "mission": 1.0 / 3.0, "weekly": 4, "exp3": 1, "exp5": 2,   # v2 boss 3 -> 2 (critique m6)
          "login7": 1, "track_nodes": (5, 10), "track": 0}   # v2: Track nodes pay NO Beacons (the Track is rating-driven
                                                               # and coins buy rating: money -> Beacons leak, two-track rule)


def portal_pl(since_l: int) -> float:
    n = since_l + 1
    base = PORTAL_BASE["L"] + PORTAL_BASE["M"]
    if n >= PITY_L_HARD:
        return 1.0
    if n >= PITY_L_SOFT:
        return min(1.0, base + PITY_L_STEP * (n - PITY_L_SOFT + 1))
    return base


def portal_gem(ps: dict, rng: random.Random) -> str:
    """One summon; mutates ps {since_e, since_l}. The roller order: Topaz+ test (with soft/hard pity), then
    the Amethyst+ hard pity, then the base C/R/E weights."""
    if rng.random() < portal_pl(ps["since_l"]):
        gem = "M" if rng.random() < OPAL_SHARE_IN_L else "L"
    elif ps["since_e"] + 1 >= PITY_E_HARD:
        gem = "E"
    else:
        x = rng.random() * (PORTAL_BASE["C"] + PORTAL_BASE["R"] + PORTAL_BASE["E"])
        gem = "C" if x < PORTAL_BASE["C"] else "R" if x < PORTAL_BASE["C"] + PORTAL_BASE["R"] else "E"
    gi = GI[gem]
    ps["since_e"] = 0 if gi >= 2 else ps["since_e"] + 1
    ps["since_l"] = 0 if gi >= 3 else ps["since_l"] + 1
    return gem


def portal_step_dist(se: int, sl: int) -> dict:
    """Exact outcome distribution of the next summon from pity state (since_e, since_l)."""
    pl = portal_pl(sl)
    out = {"M": pl * OPAL_SHARE_IN_L, "L": pl * (1 - OPAL_SHARE_IN_L)}
    rest = 1 - pl
    if se + 1 >= PITY_E_HARD:
        out.update(C=0.0, R=0.0, E=rest)
    else:
        t = PORTAL_BASE["C"] + PORTAL_BASE["R"] + PORTAL_BASE["E"]
        out.update(C=rest * PORTAL_BASE["C"] / t, R=rest * PORTAL_BASE["R"] / t, E=rest * PORTAL_BASE["E"] / t)
    return out


def portal_next_state(se, sl, gem):
    gi = GI[gem]
    return (0 if gi >= 2 else se + 1), (0 if gi >= 3 else sl + 1)


def portal_exact():
    """Stationary distribution of the pity Markov chain -> exact consolidated odds and mean gaps."""
    states = {(0, 0): 1.0}
    dist = dict(states)
    for _ in range(4000):
        nd = collections.defaultdict(float)
        for (se, sl), p in dist.items():
            for gem, q in portal_step_dist(se, sl).items():
                if q > 0:
                    nd[portal_next_state(se, sl, gem)] += p * q
        diff = sum(abs(nd.get(k, 0) - dist.get(k, 0)) for k in set(nd) | set(dist))
        dist = dict(nd)
        if diff < 1e-15:
            break
    cons = collections.defaultdict(float)
    for (se, sl), p in dist.items():
        for gem, q in portal_step_dist(se, sl).items():
            cons[gem] += p * q
    return dict(cons), dist


def portal_x10_best(start=(0, 0), welcome=False):
    """Exact distribution of the best gem in a x10 from a pity state (DP over the chain). welcome=True applies the
    disclosed welcome rule: if summons 1-9 hold no Topaz+, the 10th is Topaz (80%) or Opal (20%)."""
    dist = {(start, -1): 1.0}
    for k in range(10):
        nd = collections.defaultdict(float)
        for ((se, sl), best), p in dist.items():
            step = portal_step_dist(se, sl)
            if welcome and k == 9 and best < 3:
                step = {"L": 1 - OPAL_SHARE_IN_L, "M": OPAL_SHARE_IN_L}
            for gem, q in step.items():
                if q > 0:
                    nd[(portal_next_state(se, sl, gem), max(best, GI[gem]))] += p * q
        dist = nd
    out = collections.defaultdict(float)
    for (_, best), p in dist.items():
        out[G[best]] += p
    return dict(out)


# =============================================================================================
# 7. HERO CHESTS (PortalData.CHESTS / CHEST_ODDS)
# =============================================================================================
CHEST_ODDS = {"C": 0.62, "R": 0.27, "E": 0.09, "L": 0.02}
CHEST_PITY_L = 15
CHEST_CHARGE_PER_WIN = 1.0 / 3.0
CHEST_REPLAYS_PER_DAY = 3
CHEST_TOMES = {"hero": (0, 0), "grand": (2, 2)}  # v2: Hero Chest no Tomes, Grand 2 fixed (Tome income ~x0.45)
CHEST_HERO_CARD = 0.15          # hero-fragment card = round(0.15 x DUP_FRAGS[native]) fragments (x2 in a Grand chest); v1 0.2
CHEST_CARDS = {"hero": 2, "grand": 3}
CHEST_HERO_FRAG_MULT = {"hero": 1, "grand": 2}
CHEST_INLINE_S = {"hero": CER["chest_inline"], "grand": CER["chest_inline"]}   # inline on the result screen
TOMES_BOSS = 1                  # world-boss first clear (after the skills unlock); v1 5
TOMES_WEEKLY, TOMES_EXP5 = 2, 2  # v1 5 / 5


def chest_draw(rng, minimum=0):
    w = {g: v for g, v in CHEST_ODDS.items() if GI[g] >= minimum}
    t = sum(w.values())
    x = rng.random() * t
    for g, v in w.items():
        x -= v
        if x <= 0:
            return g
    return list(w)[-1]


def roll_chest(kind: str, pity: dict, rng: random.Random) -> list:
    n = CHEST_CARDS[kind]
    cards = [chest_draw(rng) for _ in range(n - 1)]
    last_min = 2 if kind == "grand" else 0
    if pity["since_l"] + 1 >= CHEST_PITY_L:
        last_min = 3
    cards.append(chest_draw(rng, last_min))
    pity["since_l"] = 0 if any(c == "L" for c in cards) else pity["since_l"] + 1
    pity["total"] += 1
    return cards


def chest_exact_best(kind):
    def cdf(minimum):
        w = {g: v for g, v in CHEST_ODDS.items() if GI[g] >= minimum}
        t = sum(w.values())
        acc, out = 0.0, {}
        for g in G[:4]:
            acc += w.get(g, 0) / t
            out[g] = acc
        return out
    free = cdf(0)
    last = cdf(2 if kind == "grand" else 0)
    n = CHEST_CARDS[kind]
    Fb = {g: free[g] ** (n - 1) * last[g] for g in G[:4]}
    out, prev = {}, 0.0
    for g in G[:4]:
        out[g] = Fb[g] - prev
        prev = Fb[g]
    return out


# =============================================================================================
# 8. FEATS (new hero rows; rewards earned only)
# =============================================================================================
HERO_FEATS = {   # v2: every hero Feat pays Tomes (no Beacons: critique B1 / X2); counters count earned copies only
    "F-61": ("heroes_owned", (4, 7, 10), ("tomes", (2, 4, 8))),
    "F-62": ("recuts", (1, 6, 20), ("tomes", (2, 4, 8))),
    "F-63": ("full_cuts", (2, 10, 30), ("tomes", (2, 4, 8))),
    "F-64": ("champions_owned", (4, 8, 12), ("tomes", (2, 4, 8))),
    "F-65": ("skill_ranks", (10, 40, 100), ("tomes", (2, 4, 8))),    # counter = sum(peak rank - 1): rewrites never re-count
    "F-66": ("awakenings", (1, 3, 6), ("tomes", (2, 4, 8))),
    "F-70": ("champion_level", (5, 12, 20), ("tomes", (2, 4, 8))),
}

# =============================================================================================
# 9. POWER MODEL WEIGHTS
# =============================================================================================
W_M, W_H, W_A = E.W_MACH, E.W_HERO, E.W_ARMY      # 0.50 / 0.25 / 0.25 (Meta-1)
W_C = 0.012                                       # champions: each champion index point = 0.012 power
CHAMP_UPTIME = 0.94                               # v2: champions can fall mid-level (LevelSim survival targets, §10.6)
CEREMONY_HERO = {"facet": CER["facet"], "full_cut": CER["full_facets"], "recut": CER["recut"], "skill": CER["skill"],
                 "form": CER["form"], "awaken": CER["awaken"], "clevel": CER["clevel"], "craft": CER["craft"],
                 "temper": CER["temper"], "temper_tier": CER["temper_tier"], "temper_beat": CER["temper_beat"],
                 "hero_level": CER["hero_level"], "chronicle": CER["chronicle"]}
CHRONICLE_PRICES = [10, 15, 20, 30, 40]           # «Хроніка героя» pages (no power): Tomes per page, per owned hero
CHRONICLE_RESERVE = 40                            # sim policy: keep this many Tomes for the next ranks before buying pages
STONE_INLINE_FIRST = 10        # arsenal §5.6
VAULT_BATCH_S = 0.3             # a Stone Cache sent to the Vault (one inline reveal per result screen) opens in a batch

# =============================================================================================
# 10. THE ACCOUNT (extends Meta-1 Player)
# =============================================================================================


def tf_index(mode: str, world: int) -> int:
    return world if mode == "campaign" else 7 + world


class OnePool(dict):
    """«Зоряна руда / Star Ore» (critique m1): ONE material for all factions; any faction key reads and writes the same
    pool, so the v1 faction-keyed code paths keep working unchanged."""
    def __init__(self):
        super().__init__()
        self.v = 0.0

    def __getitem__(self, k):
        return self.v

    def __setitem__(self, k, val):
        self.v = val

    def values(self):
        return [self.v]


class HPlayer(E.Player):
    def __init__(self, kind, rng, policy="greedy"):
        super().__init__(kind, rng, policy=policy)
        self.glory = 1                        # Glory retires (framework D13)
        self.hs = {h: dict(owned=False, gem=d["n"], f=0, frags=0, lvl=1, sk=[1, 1, 1, 0], relic=-1, rnd=False)
                   for h, d in HEROES.items()}
        self.hs["bolt"]["owned"] = True
        self.cs = {c: dict(owned=False, gem=d["n"], f=0, frags=0, relic=-1, rnd=False) for c, d in CHAMPS.items()}
        self.cl = 1
        self.items = {it: -1 for it in ITEMS}
        self.beacons, self.bcharge, self.seals, self.tomes = 0, 0.0, 0, 0
        self.mats = OnePool()                 # Star Ore
        self.welcome_topaz = None             # the hero the welcome x10 Topaz+ rule produced (EXPECTED floor)
        self.peaks = {}                       # (hero, skill) -> peak rank (F-65 counts peaks: rewrites never re-count)
        self.chronicle = collections.defaultdict(int)   # hero -> Chronicle pages bought
        self.migrating = False                # v2 save before its update day (heroes systems off, Meta-1 difficulty)
        self.chest_charge = 0.0
        self.trophy_bank = []
        self.ps = {"since_e": 0, "since_l": 0, "total": 0}
        self.cp = {"since_l": 0, "total": 0, "scripted": 0}
        self.team_h, self.team_c, self.syn = "bolt", [], dict(NO_SYN)
        self.inc = collections.defaultdict(float)
        self.ev = {}
        self.feats = collections.defaultdict(int)
        self.cnt = collections.defaultdict(int)
        self.cer_hero = 0.0
        self.cer_by = collections.defaultdict(float)
        self.day_now = 0
        self.expected_only = False
        self.done = set()                     # unlock rows already processed
        self.welcome_done = False
        self.wspent = collections.defaultdict(float)
        self._mc = None
        self.summons_log = []                 # gems rolled
        self.stone_n = 0
        self.cer_vault_saved = 0.0
        self.cps = {}
        self.chest_log = []
        self.phase = "campaign"

    def open_cache(self, kind, inline=True):
        before = self.ceremony_s
        E.Player.open_cache(self, kind, inline)
        if kind == "stone":
            self.stone_n += 1
            if self.stone_n > STONE_INLINE_FIRST:        # arsenal §5.6: "Схованки в сховище" default ON from the 11th
                saved = (self.ceremony_s - before) - VAULT_BATCH_S
                self.ceremony_s -= saved
                self.cer_vault_saved += saved

    # ---------------------------------------------------------------- helpers
    def on(self, s: str) -> bool:
        if self.migrating and s != "seer":
            return False
        return self.frontier > UNLOCK_AT[s]

    def note(self, key: str):
        if key not in self.ev:
            self.ev[key] = self.day_now + 1

    def credit(self, cur: str, src: str, n: float):
        self.inc[(self.phase, cur, src)] += n

    def owned_h(self):
        return [h for h, s in self.hs.items() if s["owned"]]

    def owned_c(self):
        return [c for c, s in self.cs.items() if s["owned"]]

    def slots(self) -> int:
        return 0 if not self.on("champions") else (3 if self.on("slot3") else 2)

    def champ_cap(self) -> int:
        return CHAMP_LEVEL_MAX if self.frontier > E.CAMPAIGN_LEVELS else min(CHAMP_LEVEL_MAX, 2 + 2 * self.world_reached)

    def top_own(self) -> int:
        return max(s["lvl"] for s in self.hs.values() if s["owned"])

    def eff_lvl(self, hid: str) -> int:
        own = self.hs[hid]["lvl"]
        return max(own, min(self.hero_cap(), self.top_own() - HERO_SYNC_BEHIND))

    # ---------------------------------------------------------------- gear
    def loadout(self, hid):
        if not self.on("workshop"):
            return {}, -1
        L = self.eff_lvl(hid)
        fac_h = HEROES[hid]["fac"]
        eq = {}
        for slot in SLOTS:
            if L < GEAR_SLOT_AT[slot]:
                continue
            best = None
            for fac in FACTIONS:
                r = self.items[fac + "_" + slot]
                if r < 0:
                    continue
                key = (r, fac == fac_h)
                if best is None or key > best[0]:
                    best = (key, fac + "_" + slot)
            if best:
                eq[slot] = best[1]
        relic = self.hs[hid]["relic"] if L >= GEAR_SLOT_AT["relic"] else -1
        return eq, relic

    def gear(self, hid):
        eq, relic = self.loadout(hid)
        st = {"dmg": 0.0, "hp": 0.0, "ult": 0.0, "charge": 0.0}
        cnt = collections.Counter()
        for slot, it in eq.items():
            for k, v in item_stats(slot, self.items[it]).items():
                st[k] += v
            cnt[it.split("_")[0]] += 1
        rb = 0
        if relic >= 0:
            for k, (b, per) in HERO_RELIC_STAT.items():
                st[k] += b + per * relic
            cnt[HEROES[hid]["fac"]] += 1
            rb = sum(1 for b in (4, 8, 12) if relic >= b)
        for fac, c in cnt.items():
            if c >= 2:
                k, v = SET2[fac]
                st[k] += v
        set4 = cnt[HEROES[hid]["fac"]] >= 4
        return st, rb, set4

    # ---------------------------------------------------------------- power
    def mach(self, override=None):
        if override is None and self._mc is not None:
            return self._mc
        vals = []
        for k, mm in self.machines.items():
            lv = override[1] if (override is not None and override[0] == k) else mm["lvl"]
            vals.append((self.mpow(k, lv), k))
        vals.sort(key=lambda x: -x[0])
        deck = vals[:self.deck_size()]
        top = [v for v, _ in deck[:3]]
        mval = sum(top) / len(top) if top else 1.0
        if len(deck) > 3:
            mval = 0.8 * mval + 0.2 * (sum(v for v, _ in deck[3:]) / len(deck[3:]))
        lead = 1.0 + 0.04 * self.tactics["lead_engineer"] / 3.0
        res = (mval * lead, [E.MDEF[k][2] for _, k in deck[:3]])
        if override is None:
            self._mc = res
        return res

    def hero_h(self, hid, syn=None):
        s, d = self.hs[hid], HEROES[hid]
        gs, rb, s4 = self.gear(hid)
        return hero_sim_h(d["n"], s["gem"], s["f"], self.eff_lvl(hid), s["sk"], gs, rb, s4, syn or NO_SYN)

    def rally(self, hid):
        s, d = self.hs[hid], HEROES[hid]
        _, _, s4 = self.gear(hid)
        return rally_value(d["n"], s["gem"], s["f"], s["sk"][2], s4 and d["fac"] == "dawn")

    def cval(self, cid, syn=None):
        s, d = self.cs[cid], CHAMPS[cid]
        syn = syn or NO_SYN
        mult = syn["champ_all"] * syn["champ_cls"].get(d["cls"], 1.0)
        return champ_index(d["n"], s["gem"], s["f"], self.cl, s["relic"] if self.on("workshop") else -1, mult)

    def members(self, hid, cids):
        return [(HEROES[hid]["cls"], HEROES[hid]["el"], HEROES[hid]["fac"])] + \
               [(CHAMPS[c]["cls"], CHAMPS[c]["el"], CHAMPS[c]["fac"]) for c in cids]

    def team_power(self, hid, cids, m=None, virtual_floor=0):
        """Total power for a given team. virtual_floor = number of virtual Quartz f0 champions (EXPECTED slot 3)."""
        mval, fams = m if m is not None else self.mach()
        syn = synergy(self.members(hid, cids))
        h = self.hero_h(hid, syn)
        c = sum(self.cval(cid, syn) for cid in cids)
        c += virtual_floor * champ_index(0, 0, 0, self.cl)
        c *= CHAMP_UPTIME
        msyn = 0.0
        if fams:
            vals = []
            for fam in fams:
                af = max(syn["aff"].values()) if (fam == "rift" and syn["aff"]) else syn["aff"].get(fam, 0.0)
                vals.append(min(TEAM_B2_CAP, af + syn["cel"]))
            msyn = sum(vals) / len(vals)
        a = 1.0 + sum(E.BAR_TRACKS[t] * l for t, l in self.barracks.items())
        t = 1.0 + sum(E.TACTICS[k] * r for k, r in self.tactics.items())
        ral = self.rally(hid)
        P = (W_M * mval * (1 + B2_EFF * msyn) + W_H * h + W_A * (a + ral + syn["army"]) + W_C * c) * t
        parts = dict(m=mval, msyn=msyn, h=h, a=a, rally=ral, syn_army=syn["army"], c=c, t=t)
        return P, parts

    def power(self) -> float:
        return self.team_power(self.team_h, self.team_c)[0]

    def parts_full(self):
        return self.team_power(self.team_h, self.team_c)[1]

    def expected_power(self, floor3=False, topaz_floor=False):
        """EXPECTED profile (framework §9.8): best owned STARTER + the scripted champions (+ optional floors:
        a virtual Quartz champion in slot 3; a virtual Topaz hero at f0 once the Portal hard pity guarantees one)."""
        hs = [h for h in STARTERS if self.hs[h]["owned"]]
        hid = max(hs, key=lambda h: self.hero_h(h))
        first = SCRIPTED_FIRST.get(self.cp.get("first_for", "bolt"), SCRIPTED_FIRST_DEFAULT)
        cids = [c for c in (first, SCRIPTED_SECOND) if self.cs[c]["owned"]][:self.slots()]
        vf = 1 if (floor3 and self.slots() >= 3 and len(cids) == 2) else 0
        P = self.team_power(hid, cids, virtual_floor=vf)[0]
        if topaz_floor and self.frontier >= TOPAZ_FLOOR_LEVEL:
            v = "vartan" if self.hs["vartan"]["owned"] else "vartan"
            save = dict(self.hs[v]), list(self.hs[v]["sk"])
            st = self.hs[v]
            if not st["owned"]:
                st.update(owned=True, gem=3, f=0, frags=0, lvl=1, relic=-1)
                st["sk"] = [1, 1, 1, 0]
            P = max(P, self.team_power(v, cids, virtual_floor=vf)[0])
            self.hs[v].clear()
            self.hs[v].update(save[0])
            self.hs[v]["sk"] = save[1]
        return P

    # ---------------------------------------------------------------- team selection (Auto-team)
    def select_team(self, note=True):
        hs = self.owned_h()
        cs = self.owned_c()
        if self.expected_only:
            hs = [h for h in hs if h in STARTERS or h == self.welcome_topaz]
            first = SCRIPTED_FIRST.get(self.cp.get("first_for", "bolt"), SCRIPTED_FIRST_DEFAULT)
            cs = [c for c in cs if c in (first, SCRIPTED_SECOND)]
        k = self.slots()
        m = self.mach()
        cur = self.team_h
        if note and cur in hs and len(hs) > 1:
            self._maybe_switch_hero(hs)
        hs = [self.team_h] + [h for h in hs if h != self.team_h] if self.team_h in hs else hs
        hs_sorted = sorted(hs, key=lambda h: -self.hero_h(h))[:2]
        cs_sorted = sorted(cs, key=lambda c: -self.cval(c))[:6]
        best, best_p = None, -1.0
        combos = list(itertools.combinations(cs_sorted, min(k, len(cs_sorted)))) if k else [()]
        for hid in hs_sorted:
            for cmb in combos:
                p, _ = self.team_power(hid, list(cmb), m)
                if p > best_p:
                    best, best_p = (hid, list(cmb)), p
        self.team_h, self.team_c = best
        self.syn = synergy(self.members(*best))
        if note and k >= 3 and len(self.team_c) >= 3:
            self.note("full_team")

    def _maybe_switch_hero(self, hs):
        """«Переписати навички / Rewrite skills»: all Tomes spent on a hero's ranks come back (coins do not). A player
        moves to a stronger hero when, given the same ranks (capped by its own caps), it beats the current one by 5%."""
        cur = self.team_h
        cs = self.hs[cur]
        best, best_v = cur, self.hero_h(cur)
        for h in hs:
            if h == cur:
                continue
            s, n = self.hs[h], HEROES[h]["n"]
            cap = skill_cap(n, s["gem"], s["f"])
            keep = list(s["sk"])
            s["sk"] = [max(keep[i], min(cap, cs["sk"][i])) for i in range(3)] + [keep[3]]
            v = self.hero_h(h)
            s["sk"] = keep
            if v > best_v * 1.05:
                best, best_v = h, v
        if best != cur:
            refund = sum(TOME_COST[r] for i in range(4) for r in range(1, cs["sk"][i]) if i < 3 or cs["sk"][3] > 0)
            refund -= 0 if cs["sk"][3] == 0 else 0
            cs["sk"] = [1, 1, 1, 1 if cs["sk"][3] > 0 else 0]
            self.tomes += refund
            self.cnt["rewrites"] += 1
            self.team_h = best

    # ---------------------------------------------------------------- characters
    def grant_hero(self, hid, via):
        s = self.hs[hid]
        if not s["owned"]:
            s.update(owned=True, gem=HEROES[hid]["n"], f=0, frags=0, lvl=1)
            s["rnd"] = via in ("portal", "chest")
            if HEROES[hid]["n"] >= BORN_AWAKENED_MIN and s["sk"][3] == 0:
                s["sk"][3] = 1                    # F-AWK2: native Amethyst+ heroes are born awakened
                self.note("first_awakening")
            n = HEROES[hid]["n"]
            for gi in range(n + 1):
                self.note("hero_gem_%s" % G[gi])
            self.cnt["heroes_owned"] = len(self.owned_h())
            if self.cnt["heroes_owned"] == len(HEROES):
                self.note("all_heroes")
            return True
        self.add_frags("h", hid, DUP_FRAGS[HEROES[hid]["n"]], via)
        return False

    def grant_champ(self, cid, via):
        s = self.cs[cid]
        if not s["owned"]:
            s.update(owned=True, gem=CHAMPS[cid]["n"], f=0, frags=0)
            s["rnd"] = via != "scripted"
            self.note("champ_gem_%s" % G[CHAMPS[cid]["n"]])
            self.cnt["champions_owned"] = len(self.owned_c())
            if self.cnt["champions_owned"] == len(CHAMPS):
                self.note("all_champions")
            return True
        self.add_frags("c", cid, DUP_FRAGS[CHAMPS[cid]["n"]], via)
        return False

    def add_frags(self, kind, cid, n, via):
        s = (self.hs if kind == "h" else self.cs)[cid]
        s["frags"] += n
        s["cum"] = s.get("cum", 0) + n
        if kind == "h" and HEROES[cid]["n"] == 0 and s["cum"] >= QUARTZ_TO_OPAL:
            self.note("quartz_hero_opal_possible")
        self.credit("frags", via, n)
        self._overflow(kind, cid)

    def _overflow(self, kind, cid):
        s = (self.hs if kind == "h" else self.cs)[cid]
        maxg = HERO_MAX_GEM if kind == "h" else CHAMP_MAX_GEM
        if s["gem"] >= maxg and s["f"] >= F and s["frags"] >= OVERFLOW_FRAGS_PER_TOME:
            t = s["frags"] // OVERFLOW_FRAGS_PER_TOME
            s["frags"] -= t * OVERFLOW_FRAGS_PER_TOME
            self.tomes += t
            self.credit("tomes", "overflow", t)

    def pool_of(self, gi):
        return [h for h, d in HEROES.items() if d["n"] == gi and (h not in STARTERS or self.hs[h]["owned"])]

    def pick_hero(self, gem):
        pool = self.pool_of(GI[gem])
        un = [h for h in pool if not self.hs[h]["owned"]]
        if un:
            return self.rng.choice(un)
        focus = max(pool, key=lambda h: self.hero_h(h))
        if len(pool) == 1 or self.rng.random() < FOCUS_TOTAL:
            return focus
        return self.rng.choice([h for h in pool if h != focus])

    def pick_champ(self, gem):
        pool = [c for c, d in CHAMPS.items() if d["n"] == GI[gem]]
        un = [c for c in pool if not self.cs[c]["owned"]]
        if un:
            return self.rng.choice(un)
        focus = max(pool, key=lambda c: (c in self.team_c, self.cval(c)))
        if len(pool) == 1 or self.rng.random() < FOCUS_TOTAL:
            return focus
        return self.rng.choice([c for c in pool if c != focus])

    # ---------------------------------------------------------------- Portal
    def summon(self, count, src="beacons"):
        """x1 / x10 (CeremonyData timings). src == "welcome": the disclosed welcome rule «Серед десяти — щонайменше
        Топаз»: if summons 1-9 hold no Topaz+, the 10th is Topaz+ (Opal 20% inside it). Seals and pity as usual."""
        cer = CER["x10_frame"] + CER["prologue"] if count > 1 else 0.0
        any_lplus, any_qs = False, False
        for i in range(count):
            if src == "welcome" and i == count - 1 and not any_lplus:
                gem = "M" if self.rng.random() < OPAL_SHARE_IN_L else "L"
                self.ps["since_e"] = 0
                self.ps["since_l"] = 0
            else:
                gem = portal_gem(self.ps, self.rng)
            gi = GI[gem]
            any_lplus |= gi >= 3
            self.ps["total"] += 1
            self.summons_log.append(gem)
            hid = self.pick_hero(gem)
            self.seals += 1
            self.credit("seals", "summons", 1)
            if self.expected_only and self.hs[hid]["owned"]:
                new = False                        # EXPECTED floor: Portal duplicates give it no fragments (m10)
            else:
                new = self.grant_hero(hid, "portal")
            if src == "welcome" and gi == 3 and new and self.welcome_topaz is None:
                self.welcome_topaz = hid
            if count == 1:
                cer += WALKOUT_S[gi] if new else (CER["x1"][gi] if gi < 2 else CER["prologue"] + CER["short_walkout"])
            elif gi >= 2:
                cer += CER["walkout"][gi] if new else CER["short_walkout"]
            else:
                any_qs = True
        if count > 1 and any_qs:
            cer += CER["batch_crack"]
        if src == "welcome" and self.welcome_topaz is None:
            # the welcome rule gave an Opal (or a Topaz already owned): the EXPECTED floor still counts a Topaz native
            tz = [h for h in HEROES if HEROES[h]["n"] == 3]
            if self.expected_only:
                t = self.rng.choice(tz)
                if not self.hs[t]["owned"]:
                    self.grant_hero(t, "portal")
                self.welcome_topaz = t
            else:
                self.welcome_topaz = next((h for h in tz if self.hs[h]["owned"]), None)
        self.cer_hero += cer
        self.cer_by["portal"] += cer
        self.ceremony_s += cer
        self.cnt["summons"] += count

    def seal_shop(self):
        if self.expected_only:
            return False
        pool = [h for h in HEROES if h not in STARTERS or self.hs[h]["owned"]]
        un = {g: [h for h in pool if HEROES[h]["n"] == GI[g] and not self.hs[h]["owned"]] for g in ("E", "L", "M")}
        has_lplus = any(self.hs[h]["owned"] and HEROES[h]["n"] >= 3 for h in HEROES)
        pick = None
        if un["M"] and self.seals >= SEAL_PRICES["M"]:
            pick = un["M"][0]
        elif un["L"] and not has_lplus and self.seals >= SEAL_PRICES["L"]:
            pick = un["L"][0]
        elif not un["M"] and un["L"] and self.seals >= SEAL_PRICES["L"]:
            pick = un["L"][0]
        elif not un["M"] and not un["L"]:
            # v2 (critique M6): an owned pick = 2 x DUP_FRAGS for ANY owned hero below its absolute max (team first)
            cands = [h for h in self.owned_h() if G[HEROES[h]["n"]] in SEAL_PRICES
                     and not (self.hs[h]["gem"] >= HERO_MAX_GEM and self.hs[h]["f"] >= F)]
            cands.sort(key=lambda h: (h != self.team_h, -HEROES[h]["n"]))
            if cands and self.seals >= SEAL_PRICES[G[HEROES[cands[0]]["n"]]]:
                pick = cands[0]
        if pick is None:
            return False
        price = SEAL_PRICES[G[HEROES[pick]["n"]]]
        self.seals -= price
        if self.hs[pick]["owned"]:
            self.add_frags("h", pick, 2 * DUP_FRAGS[HEROES[pick]["n"]], "seal")
            self.cnt["seal_owned_picks"] += 1
            new = False
        else:
            new = self.grant_hero(pick, "seal")
        if new:
            self.note("seal_pick_%s" % G[HEROES[pick]["n"]])
        cer = CER["seal_pick_new"] if new else CER["seal_pick_owned"]
        self.cer_by["seal_pick"] += cer
        self.cer_hero += cer
        self.ceremony_s += cer
        return True

    # ---------------------------------------------------------------- Hero Chests
    def open_chest(self, kind, src, forced=None, inline=True):
        cards = roll_chest(kind, self.cp, self.rng)
        cer = 0.0
        cameos = 0
        forced = list(forced or [])
        if not forced and self.cp["scripted"] == 1:   # chest #2 holds the healer (framework §7.2)
            forced = [SCRIPTED_SECOND]
            self.cp["scripted"] = 2
        for i, gem in enumerate(cards):
            if i < len(forced):
                cid = forced[i]
                new = self.grant_champ(cid, "scripted")
            else:
                cid = self.pick_champ(gem)
                new = self.grant_champ(cid, "chest")
            if new:
                cer += CER["cameo"] if cameos == 0 else CER["cameo_next"]
                cameos += 1
            self.chest_log.append(GI[gem])
        if not inline:
            cer += CER["vault_batch"]
        elif cameos == 0 and kind == "hero":
            cer += CER["chest_inline_dup"]        # no NEW card: the shorter inline reveal
        else:
            cer += CHEST_INLINE_S[kind]
        hs = self.owned_h()
        w = [2 if h == self.team_h else 1 for h in hs]
        hid = self.rng.choices(hs, w)[0]
        fr = int(CHEST_HERO_CARD * DUP_FRAGS[HEROES[hid]["n"]] + 0.5) * CHEST_HERO_FRAG_MULT[kind]
        self.add_frags("h", hid, fr, "chest")
        if self.on("skills"):
            lo, hi = CHEST_TOMES[kind]
            t = self.rng.randint(lo, hi)
            self.tomes += t
            self.credit("tomes", kind + "_chest", t)
        self.credit("chests", kind + ":" + src, 1)
        self.cer_by["chest_" + kind] += cer
        self.cer_hero += cer
        self.ceremony_s += cer
        self.cnt["chests"] += 1

    # ---------------------------------------------------------------- free steps (no coins)
    def free_hero_steps(self) -> int:
        changed = 0
        if self.on("portal"):
            if not self.welcome_done:
                self.welcome_done = True
                self.summon(10, "welcome")
                self.credit("beacons", "welcome_x10", 10)
                changed += 1
            while self.beacons >= 10:
                self.beacons -= 10
                self.summon(10)
                changed += 1
            while self.seal_shop():
                changed += 1
        batched = False                       # facets bought in one Hall visit play ONE micro ceremony (all characters)
        for kind, roster in (("h", self.hs), ("c", self.cs)):
            for cid, s in roster.items():
                if not s["owned"]:
                    continue
                while s["f"] < F and s["frags"] >= FACET_FRAGS[s["gem"]][s["f"]]:
                    s["frags"] -= FACET_FRAGS[s["gem"]][s["f"]]
                    s["f"] += 1
                    changed += 1
                    self.cnt["facets"] += 1
                    if s["f"] == F:
                        self.cnt["full_cuts"] += 1
                        self.note("first_full_cut")
                        c = CEREMONY_HERO["full_cut"]
                    else:
                        c = 0.0 if batched else CEREMONY_HERO["facet"]   # "+" fills every affordable pip at once
                    batched = True
                    self.cer_by["facet"] += c
                    self.cer_hero += c
                    self.ceremony_s += c
                if kind == "h" and s["sk"][3] == 0 and can_awaken(HEROES[cid]["n"], s["gem"], s["f"]):
                    s["sk"][3] = 1
                    self.cnt["awakenings"] += 1
                    self.note("first_awakening")
                    self.cer_hero += CEREMONY_HERO["awaken"]
                    self.cer_by["awaken"] += CEREMONY_HERO["awaken"]
                    self.ceremony_s += CEREMONY_HERO["awaken"]
                    changed += 1
                self._overflow(kind, cid)
                if kind == "h" and s["gem"] >= 4 and s["f"] >= F:
                    self.note("hero_opal_f5")
                maxg = HERO_MAX_GEM if kind == "h" else CHAMP_MAX_GEM
                if s["f"] == F and s["gem"] < maxg and s["frags"] >= RECUT_FRAGS[s["gem"]]:
                    self.note("recut_available")
        # recut is a once-per-gem beat: players take it as soon as it costs <= half the coins held (team first)
        if not self.expected_only:
            cands = []
            for kind, roster in (("h", self.hs), ("c", self.cs)):
                maxg = HERO_MAX_GEM if kind == "h" else CHAMP_MAX_GEM
                for cid, s in roster.items():
                    if s["owned"] and s["f"] == F and s["gem"] < maxg and s["frags"] >= RECUT_FRAGS[s["gem"]]:
                        in_team = (cid == self.team_h) if kind == "h" else (cid in self.team_c)
                        cands.append((0 if in_team else 1, RECUT_COINS[s["gem"]], kind, cid))
            for _, cost, kind, cid in sorted(cands):
                if self.unlocked("arsenal") and self.coins >= RECUT_EAGER * cost:
                    self._apply(("recut", (kind, cid), cost), -1)
                    changed += 1
        if changed:
            self.select_team()
        return changed

    def buy_chronicle(self) -> int:
        """«Хроніка героя / Hero Chronicle» (critique M6 / X13): cosmetic pages bought with surplus Tomes, no power.
        Sim policy: once the team hero's next rank costs more than the Tomes held or every skill is capped, spend the
        Tomes above CHRONICLE_RESERVE on the cheapest page of any owned hero."""
        if not self.on("skills") or self.expected_only:
            return 0
        bought = 0
        while True:
            opts = [(CHRONICLE_PRICES[self.chronicle[h]], h) for h in self.owned_h() if self.chronicle[h] < len(CHRONICLE_PRICES)]
            if not opts:
                return bought
            price, h = min(opts)
            if self.tomes - price < CHRONICLE_RESERVE:
                return bought
            self.tomes -= price
            self.chronicle[h] += 1
            self.cnt["chronicle_pages"] += 1
            self.cnt["chronicle_tomes"] += price
            self.cer_by["chronicle"] += CER["chronicle"]
            self.cer_hero += CER["chronicle"]
            self.ceremony_s += CER["chronicle"]
            bought += 1

    # ---------------------------------------------------------------- coin options
    def _recut_candidate(self, kind, cid):
        s = (self.hs if kind == "h" else self.cs)[cid]
        g0, f0 = s["gem"], s["f"]
        s["gem"], s["f"] = g0 + 1, 0
        if kind == "h":
            v_after = self.hero_h(cid)
            s["gem"], s["f"] = g0, f0
            return v_after > self.hero_h(self.team_h) * 0.98
        v_after = self.cval(cid)
        s["gem"], s["f"] = g0, f0
        if len(self.team_c) < self.slots():
            return True
        return v_after > min(self.cval(c) for c in self.team_c) * 0.98

    def options(self):
        opts = []
        self._collector = []
        for mid, m in self.machines.items():
            nl = m["lvl"] + 1
            if nl > E.MAX_LEVEL:
                continue
            need = self.bp_need(mid, nl)
            if m["bp"] + self.wild[E.MDEF[mid][0]] >= need:
                opts.append(("machine", mid, E.COIN_TO[nl]))
        if self.unlocked("barracks"):
            cap = min(E.BAR_MAX, 2 + 2 * self.world_reached)
            for t, lv in self.barracks.items():
                if lv < cap:
                    opts.append(("barracks", t, E.bar_cost(lv + 1)))
        if self.unlocked("tactics"):
            for t, r in self.tactics.items():
                if r < E.TACTICS_MAX:
                    opts.append(("tactics", t, E.TACTICS_PRICE[r]))
        if self.policy == "machines_only":
            return opts
        hid = self.team_h
        if self.unlocked("hero"):
            L = self.eff_lvl(hid)
            if L < self.hero_cap():
                opts.append(("hero", hid, E.hero_cost(L)))
        if self.on("skills"):
            s = self.hs[hid]
            n = HEROES[hid]["n"]
            cap = skill_cap(n, s["gem"], s["f"])
            for i in range(3):
                r = s["sk"][i]
                if r < cap and self.tomes >= TOME_COST[r]:
                    opts.append(("skill", (hid, i), skill_coins(r)))
            r = s["sk"][3]
            if 0 < r < awaken_cap(n, s["gem"]) and self.tomes >= TOME_COST[r]:
                opts.append(("skill", (hid, 3), skill_coins(r)))
        if self.on("champions") and self.cl < self.champ_cap() and self.team_c:
            opts.append(("clevel", None, champ_level_cost(self.cl)))
        for kind, roster in (("h", self.hs), ("c", self.cs)):
            maxg = HERO_MAX_GEM if kind == "h" else CHAMP_MAX_GEM
            for cid, s in roster.items():
                if not s["owned"] or s["f"] < F or s["gem"] >= maxg or s["frags"] < RECUT_FRAGS[s["gem"]]:
                    continue
                in_team = (cid == self.team_h) if kind == "h" else (cid in self.team_c)
                if self.expected_only and not in_team:
                    continue
                if in_team or self._recut_candidate(kind, cid):
                    opts.append(("recut", (kind, cid), RECUT_COINS[s["gem"]]))
                elif RECUT_COINS[s["gem"]] <= COLLECTOR_SHARE * self.coins:
                    self._collector.append(("recut", (kind, cid), RECUT_COINS[s["gem"]]))
        if self.on("workshop"):
            cap = temper_cap(self.world_reached)
            L = self.eff_lvl(hid)
            eq, _ = self.loadout(hid)
            for slot in SLOTS:
                if L < GEAR_SLOT_AT[slot]:
                    continue
                for fac in FACTIONS:
                    it = fac + "_" + slot
                    r = self.items[it]
                    if r < 0:
                        if slot not in eq or fac == HEROES[hid]["fac"]:
                            c, mt = CRAFT["item"]
                            if self.mats[fac] >= mt:
                                opts.append(("craft", it, c))
                    elif r < cap and eq.get(slot) == it:
                        c, mt = temper_cost("item", r)
                        if self.mats[fac] >= mt:
                            opts.append(("temper", it, c))
            if L >= GEAR_SLOT_AT["relic"]:
                s, fac = self.hs[hid], HEROES[hid]["fac"]
                if s["relic"] < 0:
                    c, mt = CRAFT["hero_relic"]
                    if self.mats[fac] >= mt:
                        opts.append(("relic", ("h", hid), c))
                elif s["relic"] < cap:
                    c, mt = temper_cost("hero_relic", s["relic"])
                    if self.mats[fac] >= mt:
                        opts.append(("relic", ("h", hid), c))
            for cid in self.team_c:
                s, fac = self.cs[cid], CHAMPS[cid]["fac"]
                if s["relic"] < 0:
                    c, mt = CRAFT["champ_relic"]
                    if self.mats[fac] >= mt:
                        opts.append(("relic", ("c", cid), c))
                elif s["relic"] < cap:
                    c, mt = temper_cost("champ_relic", s["relic"])
                    if self.mats[fac] >= mt:
                        opts.append(("relic", ("c", cid), c))
        return opts

    def _mut(self, o, sign):
        """Apply (+1) or revert (-1) the state change of an option (no payment)."""
        kind, key, _ = o
        if kind == "machine":
            self.machines[key]["lvl"] += sign
            self._mc = None
        elif kind == "barracks":
            self.barracks[key] += sign
        elif kind == "tactics":
            self.tactics[key] += sign
            self._mc = None
        elif kind == "hero":
            s = self.hs[key]
            if sign > 0:
                s["_old"] = s["lvl"]
                s["lvl"] = self.eff_lvl(key) + 1
            else:
                s["lvl"] = s.pop("_old")
        elif kind == "skill":
            self.hs[key[0]]["sk"][key[1]] += sign
        elif kind == "clevel":
            self.cl += sign
        elif kind == "recut":
            s = (self.hs if key[0] == "h" else self.cs)[key[1]]
            if sign > 0:
                s["_old"] = (s["f"], s["frags"])
                fr = s["frags"] - RECUT_FRAGS[s["gem"]]
                s["gem"] += 1
                s["f"] = 0
                while s["f"] < F and fr >= FACET_FRAGS[s["gem"]][s["f"]]:   # Best upgrade values recut + the
                    fr -= FACET_FRAGS[s["gem"]][s["f"]]                       # facets the banked fragments buy
                    s["f"] += 1
                s["frags"] = fr
            else:
                s["gem"] -= 1
                s["f"], s["frags"] = s.pop("_old")
        elif kind in ("craft", "temper"):
            if kind == "craft":
                self.items[key] = 0 if sign > 0 else -1
            else:
                self.items[key] += sign
        elif kind == "relic":
            s = (self.hs if key[0] == "h" else self.cs)[key[1]]
            if s["relic"] < 0 and sign > 0:
                s["relic"] = 0
                s["_newrelic"] = True
            elif sign < 0 and s.pop("_newrelic", False):
                s["relic"] = -1
            else:
                s["relic"] += sign

    def _gain(self, o) -> float:
        kind = o[0]
        if kind == "machine":
            m = self.mach(override=(o[1], self.machines[o[1]]["lvl"] + 1))
            return self.team_power(self.team_h, self.team_c, m)[0]
        if kind == "recut":
            team = (self.team_h, list(self.team_c), self.syn)
            self._mut(o, +1)
            in_team = (o[1][1] == self.team_h) if o[1][0] == "h" else (o[1][1] in self.team_c)
            if not in_team:
                self.select_team(note=False)
            p = self.power()
            self._mut(o, -1)
            self.team_h, self.team_c, self.syn = team
            return p
        self._mut(o, +1)
        p = self.power()
        self._mut(o, -1)
        if kind == "tactics":
            self._mc = None
        return p

    def _apply(self, o, li):
        kind, key, cost = o
        if kind in ("machine", "barracks", "tactics"):
            E.Player._apply(self, o, li)          # pays the coins itself
            self._mc = None
            return
        self.coins -= cost
        cat = {"hero": "hero", "skill": "skills", "clevel": "champions", "recut": "recut", "craft": "workshop",
               "temper": "workshop", "relic": "workshop"}[kind]
        self.spent[cat] = self.spent.get(cat, 0) + cost
        cer = 0.0
        if kind == "hero":
            s = self.hs[key]
            s["lvl"] = self.eff_lvl(key) + 1
            cer = CEREMONY_HERO["hero_level"]
        elif kind == "skill":
            hid, i = key
            s = self.hs[hid]
            r = s["sk"][i]
            self.tomes -= TOME_COST[r]
            n = HEROES[hid]["n"]
            fb = ult_form(n, r)
            s["sk"][i] += 1
            new_r = s["sk"][i]
            self.peaks[(hid, i)] = max(self.peaks.get((hid, i), 1), new_r)
            self.cnt["skill_ranks"] = sum(v - 1 for v in self.peaks.values())   # F-65: peaks, never re-counted
            if i < 3:
                for t in (5, 7, 9, 11):
                    if new_r >= t:
                        self.note("skill_rank_%d" % t)
                if new_r == skill_cap(n, n, F) and s["gem"] == n:
                    self.note("skill_native_max_%s" % G[n])
            cer = CEREMONY_HERO["form"] if (i == 0 and ult_form(n, new_r) > fb) else CEREMONY_HERO["skill"]
        elif kind == "clevel":
            self.cl += 1
            self.cnt["champion_level"] = self.cl
            cer = CEREMONY_HERO["clevel"]
        elif kind == "recut":
            k, cid = key
            s = (self.hs if k == "h" else self.cs)[cid]
            s["frags"] -= RECUT_FRAGS[s["gem"]]
            s["gem"] += 1
            s["f"] = 0
            self.cnt["recuts"] += 1
            self.note("first_recut")
            self.note("first_recut_" + k)
            if k == "h":
                self.note("hero_recut_to_%s" % G[s["gem"]])
                if cid == "titan" and s["gem"] == 4:
                    self.note("titan_opal")
            cer = CEREMONY_HERO["recut"]
            self.select_team()
        elif kind == "craft":
            fac = key.split("_")[0]
            self.mats[fac] -= CRAFT["item"][1]
            self.items[key] = 0
            self.cnt["crafts"] += 1
            cer = CEREMONY_HERO["craft"]
        elif kind == "temper":
            fac = key.split("_")[0]
            r = self.items[key]
            self.mats[fac] -= temper_cost("item", r)[1]
            self.items[key] = r + 1
            if r + 1 == TEMPER_MAX:
                self.note("first_item_12")
            cer = CEREMONY_HERO["temper_beat" if (r + 1) in (4, 8, 12) else "temper_tier" if (r + 1) in (3, 6, 9) else "temper"]
        elif kind == "relic":
            k, cid = key
            s = (self.hs if k == "h" else self.cs)[cid]
            fac = (HEROES if k == "h" else CHAMPS)[cid]["fac"]
            kind_r = "hero_relic" if k == "h" else "champ_relic"
            if s["relic"] < 0:
                self.mats[fac] -= CRAFT[kind_r][1]
                s["relic"] = 0
                cer = CEREMONY_HERO["craft"]
            else:
                self.mats[fac] -= temper_cost(kind_r, s["relic"])[1]
                s["relic"] += 1
                cer = CEREMONY_HERO["temper_beat" if s["relic"] in (4, 8, 12) else "temper"]
        self.cer_by[kind] += cer
        self.cer_hero += cer
        self.ceremony_s += cer
        self.log_buys.append((li, kind))

    def _res_cost(self, o) -> float:
        """Resource price of a coin-free option (v2 F-COIN0): Tomes for ranks, Star Ore for the Workshop."""
        kind, key, _ = o
        if kind == "skill":
            return float(TOME_COST[self.hs[key[0]]["sk"][key[1]]])
        if kind == "craft":
            return float(CRAFT["item"][1])
        if kind == "temper":
            return float(temper_cost("item", self.items[key])[1])
        if kind == "relic":
            s = (self.hs if key[0] == "h" else self.cs)[key[1]]
            kr = "hero_relic" if key[0] == "h" else "champ_relic"
            return float(CRAFT[kr][1] if s["relic"] < 0 else temper_cost(kr, s["relic"])[1])
        return 1.0

    def spend(self, li: int) -> int:
        self._mc = None
        bought = self.free_spend(li)
        self._mc = None
        bought += self.free_hero_steps()
        self.check_feats()
        if not self.unlocked("arsenal"):
            return bought
        guard = 0
        skip_free = set()
        while guard < 400:
            guard += 1
            opts = [o for o in self.options() if o[2] <= self.coins]
            if self.policy != "greedy":
                deck = set(self.deck())
                opts = [o for o in opts if o[0] != "machine" or o[1] in deck]
            # coin-free hero options (Tomes / Star Ore / fragments) are taken first, best gain per resource unit
            free = [o for o in opts if o[2] == 0 and (o[0], str(o[1])) not in skip_free]
            if free:
                base = self.power()
                scored = [((self._gain(o) - base) / self._res_cost(o), o) for o in free]
                v, best = max(scored, key=lambda t: t[0])
                if v > 1e-12:
                    self._apply(best, li)
                    bought += 1
                    continue
                for _, o in scored:
                    skip_free.add((o[0], str(o[1])))
            opts = [o for o in opts if o[2] > 0]
            if not opts:
                if self._collector and self.policy == "greedy":
                    self._apply(self._collector[0], li)       # recut a favourite outside the team
                    bought += 1
                    continue
                break
            if self.policy == "greedy":
                base = self.power()
                best, best_v = None, -1.0
                for o in opts:
                    v = (1.3 if o[0] == "machine" else 1.0) * max(self._gain(o) - base, 1e-6) / o[2]
                    if v > best_v:
                        best, best_v = o, v
            else:
                best = min(opts, key=lambda o: o[2])
            self._apply(best, li)
            bought += 1
        bought += self.buy_chronicle()
        return bought

    # ---------------------------------------------------------------- migration (v2 save -> v3, heroes_design §12.3)
    def v2_ult_ranks(self):
        """Meta-1 Ult Rank I-IV came from hero level; migrate_v2 sets ult = min(max(1, rank(lvl)), skill_cap(n, n, 0))."""
        for h, s in self.hs.items():
            if s["owned"]:
                L = self.eff_lvl(h)
                r = sum(1 for t in (1, 5, 15, 25) if L >= t)
                s["sk"][0] = max(s["sk"][0], min(max(1, r), skill_cap(HEROES[h]["n"], s["gem"], 0)))

    def migrate_grant(self, level, grant, cl_table):
        """migrate_v2 lump grant (critique M5): what the content already played would have paid since each unlock row.
        Everything is earned by play already done (legally neutral); shown as one summary card + tour cards."""
        if not grant:
            return
        L = level - 1
        after = lambda u: sum(1 for b in BOSS_LEVELS if u < b <= L)
        beacons = min(60, int(BEACON["first_clear"] * max(0, L - UNLOCK_AT["portal"]) + BEACON["boss"] * after(UNLOCK_AT["portal"])))
        self.beacons += beacons
        self.credit("beacons", "migration", beacons)
        n_hero = min(20, max(0, (L - UNLOCK_AT["champions"]) // 3))
        n_grand = after(UNLOCK_AT["champions"])
        for _ in range(n_hero):
            self.open_chest("hero", "migration", inline=False)
        for _ in range(n_grand):
            self.open_chest("grand", "migration", inline=False)
        tomes = TOMES_BOSS * after(UNLOCK_AT["skills"])
        self.tomes += tomes
        self.credit("tomes", "migration", tomes)
        target = cl_table.get(L, self.cl)
        self.cl = max(self.cl, min(self.champ_cap(), target))
        self.ceremony_s += CER["migration_summary"]
        self.cer_hero += CER["migration_summary"]
        self.cer_by["migration"] += CER["migration_summary"]
        self.cnt["migration_beacons"] = beacons
        self.cnt["migration_chests"] = n_hero + n_grand
        self.select_team()

    # ---------------------------------------------------------------- feats
    def check_feats(self):
        self.cnt["heroes_owned"] = len(self.owned_h())
        self.cnt["champions_owned"] = len(self.owned_c())
        for fid, (ctr, tiers, (cur, rew)) in HERO_FEATS.items():
            t = self.feats[fid]
            while t < 3 and self.cnt[ctr] >= tiers[t]:
                v = rew[t]
                if cur == "beacons":
                    if self.on("portal"):
                        self.beacons += v
                        self.credit("beacons", "feats", v)
                    else:
                        break
                else:
                    if self.on("skills"):
                        self.tomes += v
                        self.credit("tomes", "feats", v)
                    else:
                        break
                t += 1
            self.feats[fid] = t

    # ---------------------------------------------------------------- materials / trophies
    def add_mats(self, fac, n, src):
        if src not in ("trophy_refund",):
            n *= ORE_INCOME
        self.mats[fac] += n
        self.credit("mats", src, n)

    def need_faction(self):
        """Faction whose material the player most wants (team hero gear + relics)."""
        want = collections.Counter()
        eq, _ = self.loadout(self.team_h)
        for it in eq.values():
            want[it.split("_")[0]] += 3
        want[HEROES[self.team_h]["fac"]] += 2
        for c in self.team_c:
            want[CHAMPS[c]["fac"]] += 1
        for f in FACTIONS:
            want[f] += 0
        return max(FACTIONS, key=lambda f: want[f] / (1.0 + self.mats[f] / 100.0))

    def grant_trophy(self, item):
        r = self.items[item]
        if r < 0:
            self.items[item] = TROPHY_RANK
        else:
            nr = r + TROPHY_RANK
            if nr > TEMPER_MAX:                   # ranks past +12 come back as the materials of the top ranks
                fac = item.split("_")[0]
                self.add_mats(fac, sum(temper_cost("item", k)[1] for k in range(2 * TEMPER_MAX - nr, TEMPER_MAX)),
                              "trophy_refund")
                nr = TEMPER_MAX
            self.items[item] = nr
        self.cnt["trophies"] += 1


# =============================================================================================
# 11. CAMPAIGN / LONG-HORIZON LOOP (a line-by-line extension of economy_sim.simulate)
# =============================================================================================
BOSS_LEVELS = tuple(range(8, 113, 8))


def simulate(kind, seed, levels=60, policy="greedy", payer=None, days=None, tf=None, expected_only=False,
             track_exp=False, snap_days=(), migrate_at=0, migrate_grant=True, cl_table=None):
    a = E.ARCHETYPES[kind]
    p = HPlayer(kind, random.Random(seed), policy=policy)
    p.expected_only = expected_only
    p.migrating = migrate_at > 0
    p.cl_at = {}
    tf = tf or {}
    for m in E.START_OWNED:
        p.unlock(m)
    if payer == "starter":
        p.coins += E.STARTER_COINS
        p.machines["drone"]["bp"] += E.STARTER_BP
    rng = p.rng
    day, level_today, session_levels, login_idx, ads_today, replay_caches, replay_chests = 0, 0, 0, 0, 0, 0, 0
    sessions, sess_cer = [], []
    cur_buys, cur_cer0, cur_cer_m1 = 0, 0.0, 0.0
    p.sess_cer_m1 = []
    level = 1
    rlog = []
    best_crowns = {}
    last_track_rating = -1
    losses_here = 0
    new_day = True
    phase_att = collections.Counter()
    snaps = {}
    max_attempts = (levels if days is None else 10 ** 6) * 8
    p.select_team()
    while (level <= levels if days is None else day < days) and p.attempt < max_attempts:
        mode, dl, boss, world, pay = E.stage_of(level)
        p.phase = mode if mode != "replay" else "post"
        p.day_now = day
        if new_day:
            k_, val = E.LOGIN_CYCLE[login_idx % 7]
            if level > 16:
                login_idx += 1
                if k_ == "coins":
                    p.earn(val, "login")
                elif k_ == "gems":
                    p.gems += val
                elif k_ == "cache":
                    p.open_cache(val)
                elif k_ == "bp_rare":
                    rares = [m for m in p.machines if E.MDEF[m][0] == "R"]
                    if rares:
                        p.machines[rng.choice(rares)]["bp"] += val
                if login_idx % 7 == 0 and p.on("portal"):         # day-7 card: +2 Beacons
                    p.beacons += BEACON["login7"]
                    p.credit("beacons", "login", BEACON["login7"])
                p.earn(a["dailies"] * E.DAILY_MISSION_COINS(min(level, E.CAMPAIGN_LEVELS)), "missions")
                p.gems += a["dailies"] * E.DAILY_MISSION_GEMS
                if p.on("portal"):
                    p.bcharge += a["dailies"] * BEACON["mission"]
                    p.credit("beacons", "missions", a["dailies"] * BEACON["mission"])
                if day % 7 == 6:
                    p.earn(E.WEEKLY_BONUS["coins"], "missions")
                    p.open_cache(E.WEEKLY_BONUS["cache"])
                    if p.on("portal"):
                        p.beacons += BEACON["weekly"]
                        p.credit("beacons", "weekly", BEACON["weekly"])
                    if p.on("champions"):
                        p.open_chest("grand", "weekly")
                    if p.on("skills"):
                        p.tomes += TOMES_WEEKLY
                        p.credit("tomes", "weekly", TOMES_WEEKLY)
                    p.add_mats(p.need_faction(), ORE_WEEKLY, "weekly")
                    if level > 42:
                        p.open_cache("world")
                        if p.on("portal"):
                            p.beacons += BEACON["exp3"]
                            p.credit("beacons", "expedition", BEACON["exp3"])
                        if rng.random() < 0.3 + 0.6 * a["skill"]:
                            p.open_cache("royal")
                            p.mythic_bp()
                            if p.on("portal"):
                                p.beacons += BEACON["exp5"]
                                p.credit("beacons", "expedition", BEACON["exp5"])
                            p.open_chest("grand", "expedition")
                            if p.on("skills"):
                                p.tomes += TOMES_EXP5
                                p.credit("tomes", "expedition", TOMES_EXP5)
                            p.add_mats(p.need_faction(), ORE_EXP5, "expedition")
            ads_today = 0
            replay_caches = 0
            replay_chests = 0
            new_day = False
        p.attempt += 1
        p.world_reached = max(p.world_reached, world)
        p.frontier = level
        phase_att[p.phase] += 1
        # ---- unlock rows (framework §12)
        if p.on("champions") and "champions" not in p.done:
            p.done.add("champions")
            p.cp["first_for"] = p.team_h if p.team_h in SCRIPTED_FIRST else "default"
            first = SCRIPTED_FIRST.get(p.team_h, SCRIPTED_FIRST_DEFAULT)
            p.cp["scripted"] = 9                     # (no chest-#2 rule while chest #1 opens)
            p.open_chest("hero", "scripted", forced=[first])   # chest #1: scripted champion + 1 rolled card + fragments
            p.cp["scripted"] = 1
            p.note("champions")
            p.select_team()
        if p.on("seer") and not p.hs["seer"]["owned"]:
            p.grant_hero("seer", "progress")
            p.select_team()
        if p.migrating and level > 5 and not p.hs["seer"]["owned"]:
            p.grant_hero("seer", "migration")         # v2 saves met the Seer at L5 and keep her
            p.select_team()
        if p.migrating:
            p.v2_ult_ranks()
            if level > migrate_at:
                p.migrating = False
                p.v2_ult_ranks()
        if migrate_at and not p.migrating and "migration" not in p.done and p.on("champions") and "champions" in p.done:
            p.done.add("migration")
            p.migrate_grant(level, migrate_grant, cl_table or {})
        if p.unlocked("hero") and not p.hs["titan"]["owned"]:
            p.grant_hero("titan", "progress")
            p.select_team()
        if p.on("portal") and "portal" not in p.done:
            p.done.add("portal")
            p.note("portal")
        if payer == "heroes" and p.frontier > 28 and "shop_heroes" not in p.done:
            p.done.add("shop_heroes")                  # paid: the three named heroes of gem <= Amethyst (§10 SKUs)
            for hid in PAID_HERO_SKUS:
                p.grant_hero(hid, "shop")
            p.select_team()
        if p.on("workshop") and "workshop" not in p.done:
            p.done.add("workshop")
            for it in p.trophy_bank:
                p.grant_trophy(it)
            p.trophy_bank = []
            p.note("workshop")
        if p.on("slot3") and "slot3" not in p.done:
            p.done.add("slot3")
            p.select_team()
        if level == 61 and "cp60" not in p.cps:
            p.cps["cp60"] = p.parts_full()
            p.cps["luck56"] = sum(1 for g in p.summons_log if GI[g] >= 3)
        if mode != "replay" and not p.migrating:
            dem = E.demand(dl) * tf.get(tf_index(mode, world), 1.0)
        else:
            dem = E.demand(dl)                          # replays, and a v2 save before its update day (Meta-1 curve)
        if level not in p.cl_at:
            p.cl_at[level] = p.cl
        P = p.power()
        assist = min(E.RETRY_ASSIST_CAP, E.RETRY_ASSIST_STEP * losses_here)
        raw = P / dem
        ratio = raw * (1.0 + assist)
        win_p = 1.0 / (1.0 + math.exp(-(7.0 * (ratio - 1.0) + 3.0 * (a["skill"] - 0.5) + 1.6)))
        win_p = min(0.98, max(0.12, win_p))
        won = level <= E.FORCED_WIN_LEVELS or rng.random() < win_p or mode == "replay"
        pe2 = pe3 = pe4 = None
        if track_exp and mode != "replay":
            pe2 = p.expected_power(False)
            pe3 = p.expected_power(True)
            pe4 = p.expected_power(True, True)
        rlog.append((level, ratio, won, raw, P, pe2, pe3, mode, pe4, 1.0 if level <= E.FORCED_WIN_LEVELS else win_p))
        if p.cnt["summons"] >= 30 and "summon30" not in p.ev:
            p.ev["summon30"] = p.day_now + 1
            p.ev["summon30_level"] = level
        pick = E.pickup_coins(pay) * (0.7 + 0.6 * a["skill"])
        wpos = (level - 1) % E.LEVELS_PER_WORLD + 1
        nm = E.NEW_CRATE_LEVELS.get(world, {}).get(wpos) if mode == "campaign" else None
        if nm:
            p.unlock(nm)
        p.ceremony_s += E.CEREMONY["result_min"]
        share = E.REPLAY_SHARE if mode == "replay" else 1.0
        if won:
            losses_here = 0
            surv = max(0, int(rng.gauss(30 + 60 * a["skill"], 20)))
            stairs = max(1.2, min(5.0, rng.gauss(a["stairs"], 0.5)))
            vc = E.victory_coins(pay, surv) * (1 + E.WAR_CHEST_COINS * p.tactics["war_chest"])
            base_gain = (vc + pick) * share
            p.earn(int(base_gain), "level (victory + pickups)")
            p.earn(int(base_gain * (stairs - 1.0)), "stairs multiplier")
            if a["ads"] and level > E.AD_FREE_LEVELS and ads_today < min(a["ads"], E.AD_CAP_PER_DAY):
                ads_today += 1
                p.earn(int(base_gain * stairs), "rewarded x2")
            stone_inline = False
            grand_inline = False
            if mode != "replay":
                cr = max(1, min(3, int(round(rng.gauss(a["crowns"], 0.6)))))
                prev = best_crowns.get(level, 0)
                if cr > prev:
                    p.crowns += cr - prev
                    best_crowns[level] = cr
                if level >= 6:
                    p.open_cache("world" if boss else "stone")
                    stone_inline = not boss
                if boss:
                    p.cores += 1
                # ---- heroes: first-clear income
                if p.on("portal"):
                    p.bcharge += BEACON["first_clear"]
                    p.credit("beacons", "first_clear", BEACON["first_clear"])
                fac = HOME[world]
                mv = mat_per_win(world, mode)
                p.add_mats(fac, mv, "wins")
                if boss:
                    p.cnt["bosses"] += 1
                    if p.on("portal"):
                        p.beacons += BEACON["boss"]
                        p.credit("beacons", "boss", BEACON["boss"])
                    if p.on("skills"):
                        p.tomes += TOMES_BOSS
                        p.credit("tomes", "boss", TOMES_BOSS)
                    p.add_mats(fac, MAT_BOSS[mode], "boss")
                    it = TROPHIES.get(level)
                    if it:
                        if p.on("workshop"):
                            p.grant_trophy(it)
                        else:
                            p.trophy_bank.append(it)
                    if p.on("champions"):
                        p.open_chest("grand", "boss")
                        grand_inline = True
            else:
                if replay_caches < E.REPLAY_CACHES_PER_DAY:
                    replay_caches += 1
                    p.open_cache("stone")
                    stone_inline = True
                nf = p.need_faction()
                p.add_mats(nf, REPLAY_MAT_SHARE * mat_per_win(REPLAY_WORLD[nf], "campaign"), "replays")
            # ---- Hero Chest charge (every 3rd win; replays only on the first 3 replay wins per day)
            chest_now = False
            if p.on("champions") and (mode != "replay" or replay_chests < CHEST_REPLAYS_PER_DAY):
                if mode == "replay":
                    replay_chests += 1
                p.chest_charge += CHEST_CHARGE_PER_WIN
                if p.chest_charge >= 1.0 - 1e-9:
                    p.chest_charge -= 1.0
                    p.open_chest("hero", "wins", inline=not grand_inline)   # one inline reveal per result screen
                    chest_now = True
            if chest_now and stone_inline and p.stone_n <= STONE_INLINE_FIRST:   # one inline reveal per result screen
                p.ceremony_s -= E.CEREMONY["cache_inline"] - VAULT_BATCH_S
                p.cer_hero -= E.CEREMONY["cache_inline"] - VAULT_BATCH_S
                p.cer_by["stone_to_vault"] -= E.CEREMONY["cache_inline"] - VAULT_BATCH_S
            if p.on("champions") and len(p.team_c) >= 3:
                p.cnt["wins_full_team"] += 1
            for mid in p.deck()[:3]:
                m = p.machines[mid]
                if m["lvl"] < E.MAX_LEVEL:
                    m["frac"] += E.DRIP[E.MDEF[mid][0]] * (1.5 if rng.random() < 0.3 + 0.4 * a["skill"] else 1.0)
                    whole = int(m["frac"])
                    m["bp"] += whole
                    m["frac"] -= whole
            if level > 40:
                if last_track_rating < 0:
                    last_track_rating = p.rating() // E.ARSENAL_RATING_STEP * E.ARSENAL_RATING_STEP
                while p.rating() >= last_track_rating + E.ARSENAL_RATING_STEP:
                    last_track_rating += E.ARSENAL_RATING_STEP
                    p.track_nodes += 1
                    node = (p.track_nodes - 1) % 12 + 1
                    if node in BEACON["track_nodes"] and p.on("portal"):
                        p.beacons += BEACON["track"]
                        p.credit("beacons", "track", BEACON["track"])
                    if p.track_nodes % E.TRACK_CACHE_EVERY == 0:
                        p.open_cache("royal" if p.track_nodes % (E.TRACK_CACHE_EVERY * 4) == 0 else "stone")
                    else:
                        p.earn(100 + 10 * min(level, E.CAMPAIGN_LEVELS), "arsenal track")
            if mode != "replay":
                level += 1
        else:
            losses_here += 1
            frac = rng.uniform(0.3, 0.95)
            p.earn(int(E.victory_coins(pay, 0) * E.LOSS_VICTORY_SHARE * frac + pick * E.LOSS_PICKUP_SHARE * frac), "lost runs")
            p.cache_charge += E.LOSS_CACHE_CHARGE
            if p.cache_charge >= 1.0 and level >= 6:
                p.cache_charge -= 1.0
                p.open_cache("stone")
            for mid in p.deck()[:3]:
                m = p.machines[mid]
                m["frac"] += 0.5 * E.DRIP[E.MDEF[mid][0]]
        if p.bcharge >= 1.0:
            whole = int(p.bcharge + 1e-9)
            p.beacons += whole
            p.bcharge -= whole
        cur_buys += p.spend(level)
        session_levels += 1
        level_today += 1
        if session_levels >= a["lps"]:
            sessions.append(cur_buys)
            sess_cer.append((p.ceremony_s - cur_cer0) / (session_levels * E.LEVEL_SECONDS + (p.ceremony_s - cur_cer0)))
            c_m1 = (p.ceremony_s + p.cer_vault_saved) - cur_cer_m1
            p.sess_cer_m1.append(c_m1 / (session_levels * E.LEVEL_SECONDS + c_m1))
            cur_buys, session_levels, cur_cer0 = 0, 0, p.ceremony_s
            cur_cer_m1 = p.ceremony_s + p.cer_vault_saved
        if level_today >= a["lpd"]:
            level_today = 0
            day += 1
            new_day = True
            if day in snap_days:
                snaps[day] = snapshot(p, level)
    if session_levels:
        sessions.append(cur_buys)
    p.day_end = day + 1
    p.phase_att = phase_att
    p.lpd = a["lpd"]
    return p, snaps, sessions, rlog, sess_cer


def snapshot(p: HPlayer, level: int) -> dict:
    th = p.hs[p.team_h]
    tc = [p.cs[c] for c in p.team_c]
    parts = p.parts_full()
    return dict(
        level=min(level, 113), heroes=len(p.owned_h()), champs=len(p.owned_c()),
        team_native=HEROES[p.team_h]["n"], team_gem=th["gem"], team_f=th["f"], team_lvl=p.eff_lvl(p.team_h),
        team_ranks=sum(th["sk"][:3]), team_awk=th["sk"][3], cl=p.cl,
        champ_gem=statistics.mean([s["gem"] for s in tc]) if tc else 0, n_team_c=len(tc),
        recuts=p.cnt["recuts"], tomes=p.tomes, beacons=p.beacons, seals=p.seals, summons=p.cnt["summons"],
        gear=statistics.mean([p.items[it] for it in p.loadout(p.team_h)[0].values()] or [0]),
        relic=th["relic"], mats=sum(p.mats.values()), coins=p.coins, h=parts["h"], c=parts["c"],
        avg_mach=statistics.mean(m["lvl"] for m in p.machines.values()),
        best_native=max(HEROES[h]["n"] for h in p.owned_h()),
        opal_heroes=sum(1 for h in p.owned_h() if HEROES[h]["n"] == 4))


# =============================================================================================
# 12. REPORTS
# =============================================================================================
def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else float("nan")


FAILS = []


def inv(name, ok, detail):
    print("  [%s] %s  (%s)" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        FAILS.append(name)


def fmt_pct(x):
    return "%.2f%%" % (100 * x)


# ---------------------------------------------------------------- 1. ladder
ZERO_GEAR = {"dmg": 0.0, "hp": 0.0, "ult": 0.0, "charge": 0.0}
MAX_GEAR = {"dmg": 0.11 + 0.022 + 0.03, "hp": 0.156 + 0.05 + 0.05, "ult": 0.10 + 0.05, "charge": 0.066}


def awk_reached(n, g, f):
    """Awakening is open if the character reached Full facets in some gem >= Amethyst on its path, or it is a native
    Amethyst+ hero (born awakened, F-AWK2)."""
    return g >= AWAKEN_MIN_GEM and (f == F or g > max(n, AWAKEN_MIN_GEM) or n >= BORN_AWAKENED_MIN)


def max_ranks(n, g, f):
    c = skill_cap(n, g, f)
    return [c, c, c, awaken_cap(n, g) if awk_reached(n, g, f) else 0]


def section_ladder():
    print("\n## 1. Rule #3 ladder (framework §2): numbers and proof")
    print("NATIVE_MULT q=%.2f -> %s | FACET_STEP a=%.3f | RECUT_STEP=%.3f | RECUT_STEP/q=%.4f <= CEILING %.2f" % (
        Q_NATIVE, [round(x, 4) for x in NATIVE_MULT], FACET_STEP, RECUT_STEP, RECUT_STEP / Q_NATIVE, CEILING))
    # Table A: ladder at every gem x facet, native vs every recut origin
    print("\n### 1a. Stat ladder ladder(n,g,f): native vs recut, every gem and facet (ratio = recut / native)")
    print("| Current gem | f | native | " + " | ".join("from %s (ratio)" % GEM_EN[n] for n in range(4)) + " |")
    print("|---|---|---|" + "---|" * 4)
    worst = 0.0
    for g in range(1, 5):
        for f in range(F + 1):
            cells = []
            for n in range(4):
                if n < g:
                    r = ladder(n, g, f) / ladder(g, g, f)
                    worst = max(worst, r)
                    cells.append("%.3f (%.3f)" % (ladder(n, g, f), r))
                else:
                    cells.append("—")
            print("| %s | %d | %.3f | %s |" % (GEM_EN[g], f, ladder(g, g, f), " | ".join(cells)))
    inv("B1 stats: recut <= CEILING x native at every (n<g, f)", worst <= CEILING + 1e-12, "worst %.4f" % worst)
    # Table B: caps, forms, awakening
    print("\n### 1b. Skill-rank cap / ult form / Awakening cap by (native n -> current gem g), f0 and f5")
    print("| native \\ current | " + " | ".join(GEM_EN) + " |")
    print("|---|" + "---|" * 5)
    ok_caps = True
    for n in range(5):
        cells = []
        for g in range(5):
            if g < n:
                cells.append("")
                continue
            c0, c5 = skill_cap(n, g, 0), skill_cap(n, g, 5)
            fm = ult_form(n, c5)
            ak = awaken_cap(n, g)
            born = " (born)" if (g == n and n >= BORN_AWAKENED_MIN) else ""
            cells.append("cap %d/%d · form %s · awk %s%s" % (c0, c5, GEM_EN[fm - 1][:3], ak if g >= 2 else "—", born))
            if g > n:
                ok_caps &= c5 < skill_cap(g, g, 5) and c0 < skill_cap(g, g, 0)
                ok_caps &= ult_form(n, c5) < ult_form(g, skill_cap(g, g, 5))
                if g >= 2:
                    ok_caps &= awaken_cap(n, g) < awaken_cap(g, g)
        print("| %s | %s |" % (GEM_EN[n], " | ".join(cells)))
    inv("B2/B3/B4 caps, forms, Awakening strictly below natives", ok_caps, "all n<g")
    # Table C: full power index at level breakpoints
    print("\n### 1c. Hero power index (HeroesMeta.power) at gem / facet / level breakpoints (1.000 = Meta-1 Lv1 hero)")
    print("eq = equal investment: same Lv, same facets, the same Ult/Attack/Rally ranks (the recut's caps, which the native may")
    print("also hold), the same Awakening rank where both may hold it, same full gear. transient = the recut keeps the Awakening")
    print("it opened on its path while a fresh native (f<5) has none yet. max = each at f5 with every cap of its own.")
    print("| Path | Lv | eq f0 ratio | eq f5 ratio | transient f0 ratio | native max (f5) | recut max (f5) | ratio max |")
    print("|---|---|---|---|---|---|---|---|")
    worst_eq, worst_mx, worst_tr = 0.0, 0.0, 0.0
    for n in range(4):
        for g in range(n + 1, 5):
            for L in (1, 10, 20, 30):
                row = []
                for f in range(F + 1):
                    rc, nc = max_ranks(n, g, f), max_ranks(g, g, f)
                    eq_r = [min(rc[i], nc[i]) for i in range(4)]
                    nat = hero_index(g, g, f, L, eq_r, MAX_GEAR, 3, True)
                    rec = hero_index(n, g, f, L, eq_r, MAX_GEAR, 3, True)
                    worst_eq = max(worst_eq, rec / nat)
                    tr_r = eq_r[:3] + [rc[3]]
                    rec_tr = hero_index(n, g, f, L, tr_r, MAX_GEAR, 3, True)
                    nat_tr = hero_index(g, g, f, L, eq_r[:3] + [min(nc[3], rc[3]) if nc[3] else 0], MAX_GEAR, 3, True)
                    worst_tr = max(worst_tr, rec_tr / nat_tr)
                    row.append((rec / nat, rec_tr / nat))
                nat_mx = hero_index(g, g, F, L, max_ranks(g, g, F), MAX_GEAR, 3, True)
                rec_mx = hero_index(n, g, F, L, max_ranks(n, g, F), MAX_GEAR, 3, True)
                worst_mx = max(worst_mx, rec_mx / nat_mx)
                if L in (1, 30):
                    print("| %s->%s | %d | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |" % (
                        GEM_EN[n][:3], GEM_EN[g][:3], L, row[0][0], row[5][0], row[0][1], nat_mx, rec_mx, rec_mx / nat_mx))
    inv("power index at equal investment <= 0.96 x native (all paths, every f, Lv 1/10/20/30)", worst_eq <= CEILING + 1e-9, "worst %.4f" % worst_eq)
    inv("transient (recut keeps its path Awakening; native holds what it can) <= 0.96 x native (F-AWK2 removes the case)",
        worst_tr <= CEILING + 1e-9, "worst %.4f" % worst_tr)
    inv("power index at max investment < native (all paths, Lv 1/10/20/30)", worst_mx < 1.0, "worst %.4f" % worst_mx)
    # H1 gate (review F1): across facet counts. A recut at ANY facet count with every cap of its own stays below a native
    # of its current gem at ANY facet count, (a) the native at every cap of its own, (b) the native at the recut's ranks
    # (equal Tomes), its Awakening rank only if its own Awakening is open at that facet count.
    worst_xa, worst_xb = 0.0, 0.0
    for n in range(4):
        for g in range(n + 1, 5):
            for L in (1, 10, 20, 30):
                for fr in range(F + 1):
                    rc = max_ranks(n, g, fr)
                    rec = hero_index(n, g, fr, L, rc, MAX_GEAR, 3, True)
                    for fn in range(F + 1):
                        worst_xa = max(worst_xa, rec / hero_index(g, g, fn, L, max_ranks(g, g, fn), MAX_GEAR, 3, True))
                        nb = rc[:3] + [min(rc[3], awaken_cap(g, g)) if awk_reached(g, g, fn) else 0]
                        worst_xb = max(worst_xb, rec / hero_index(g, g, fn, L, nb, MAX_GEAR, 3, True))
    inv("cross-facet: recut (any f, own caps) < native (any f, own caps), all paths, Lv 1/10/20/30", worst_xa < 1.0,
        "worst %.4f" % worst_xa)
    inv("cross-facet: recut (any f, own caps) < native (any f, the recut's ranks; Awakening only if open)",
        worst_xb < 1.0, "worst %.4f" % worst_xb)
    section_rule3_tolerance()
    # Champions
    wc = 0.0
    for n in range(3):
        for g in range(n + 1, 4):
            for f in range(F + 1):
                for cl in (1, 10, 20):
                    wc = max(wc, champ_index(n, g, f, cl, 12) / champ_index(g, g, f, cl, 12))
    inv("champions: recut <= 0.96 x native and Action tier below (all n<g<=Topaz)", wc <= CEILING + 1e-9, "worst %.4f" % wc)
    # monotone
    mono = True
    for n in range(5):
        prev = (0.0, 0)
        for g in range(n, 5):
            for f in range(F + 1):
                cur = (ladder(n, g, f), skill_cap(n, g, f))
                if cur[0] < prev[0] - 1e-12 or cur[1] < prev[1]:
                    mono = False
                prev = cur
    inv("monotone: no stat or cap ever drops along a ladder path (recut never feels like a loss)", mono, "all paths")
    # max hero vs Meta-1
    best = hero_index(4, 4, 5, 30, max_ranks(4, 4, 5), MAX_GEAR, 3, True)
    m1 = 1 + LV_DMG * 29
    print("\nReference points: Meta-1 Lv30 hero = %.3f; Opal native fully invested Lv30 = %.3f (x%.2f); "
          "Sapphire Bolt Lv1 = %.3f; Amethyst Seer Lv1 = %.3f" % (
              m1, best, best / m1, hero_index(1, 1, 0, 1, [1, 1, 1, 0], ZERO_GEAR), hero_index(2, 2, 0, 1, [1, 1, 1, 0], ZERO_GEAR)))
    # no-loss migration: v2 ult power (Meta-1 Ult Rank I-IV at Lv1/5/15/25 = +20%/rank) vs new at migrated rank
    print("\n### 1d. No-loss migration check (v2 ult power vs v3 at the migrated Ult rank, Lv5..30)")
    ok = True
    rows = []
    for hid, n in (("titan", 0), ("bolt", 1), ("seer", 2)):
        for L in (1, 5, 10, 15, 20, 25, 30):
            v2_rank = sum(1 for t in (1, 5, 15, 25) if L >= t)
            v2 = 1 + 0.20 * (v2_rank - 1)
            r = min(max(1, v2_rank), skill_cap(n, n, 0))
            v3 = ladder(n, n, 0) * (1 + LV_ULT * (L - 1)) * (1 + ULT_RANK_STEP * (r - 1))
            ok &= v3 >= v2 - 1e-9
            if L in (5, 15, 25, 30):
                rows.append("%s Lv%d: v2 x%.2f -> v3 x%.2f (rank %d)" % (hid, L, v2, v3, r))
    print("  " + " · ".join(rows))
    inv("test_no_loss_migration (ult power, with LV_ULT; starters' kits = Meta-1 x NATIVE_MULT)", ok, "Titan/Bolt/Seer Lv1-30")


KIT_TOL = 0.015                 # HeroData.KIT_INDEX profile: at EVERY reference state (Lv1 r1 f0, each beat, each form,
                                # each Awakening rank, relic +4/+8/+12) the measured index is within +-1.5% of P0's
AWK_TOL = 0.005                 # design band per Awakening rank: 4.0% +- 0.5 pp (guide; the profile test is binding)
FORM_TOL = 0.005                # design band per ult form above I: 3.0% +- 0.5 pp of ult effectiveness (guide)
BEAT_TOL = 0.003                # design band per Attack beat: 1.0% +- 0.3 pp (guide)
RELIC_TOL = 0.005               # design band per relic beat: 3.0% +- 0.5 pp (guide)
CHAMP_KIT_TOL = 0.03            # ChampionData.KIT_INDEX within +-3% (Action tier rules 4% each, inside it)


def hero_index_t(n, g, f, L, sk, gear, rb, set4, kit, awk, form, beat, relic):
    """hero_index with per-item budgets replaced (the adversarial tolerance grid of §2.6)."""
    ult, atk, rally, aw = sk
    lad = ladder(n, g, f) * kit
    atk_m = 1 + ATK_RANK_STEP * (atk - 1) + beat * sum(1 for b in ATK_BEATS if atk >= b)
    dmg = (1 + LV_DMG * (L - 1)) * (1 + gear["dmg"]) * atk_m
    fm = ult_form(n, ult)
    ultp = ((1 + LV_ULT * (L - 1)) * (1 + ULT_RANK_STEP * (ult - 1)) * (1 + gear["ult"]) *
            (1 + LV_RATE * (L - 1)) * (1 + gear["charge"]) * (1 + form * (fm - 1)))
    hp = 1 + HP_W * ((1 + LV_HP * (L - 1)) * (1 + gear["hp"]) - 1)
    return (lad * ((1 - U_SHARE) * dmg + U_SHARE * ultp) * hp * (1 + awk * aw) * (1 + relic * rb) *
            (1 + (SET4_VALUE if set4 else 0.0)))


def section_rule3_tolerance():
    """Worst case of rule #3 when every per-item budget sits at the edge of its LevelSim band, adversarially: the recut
    hero's kit, Awakening, forms, beats and relic at +tolerance, the native's at -tolerance (critique B2)."""
    print("\n### 1e. Rule #3 with real-kit tolerances (adversarial: the recut hero's whole profile at +tol, the native's at -tol)")
    print("Binding test: KIT_INDEX profile within +-%.1f%% of P0 at every reference state. Design guides per item: Awakening "
          "%.1f%% +-%.1f pp/rank · form %.1f%% +-%.1f pp · beat %.1f%% +-%.1f pp · relic beat %.1f%% +-%.1f pp" % (
              100 * KIT_TOL, 100 * AWK_STEP, 100 * AWK_TOL, 100 * FORM_STEP, 100 * FORM_TOL, 100 * ATK_BEAT, 100 * BEAT_TOL,
              100 * RELIC_BEAT, 100 * RELIC_TOL))
    hi = (1 + KIT_TOL, AWK_STEP, FORM_STEP, ATK_BEAT, RELIC_BEAT)
    lo = (1 - KIT_TOL, AWK_STEP, FORM_STEP, ATK_BEAT, RELIC_BEAT)
    st = 0.0                                          # what un-checked per-item stacking would do (why the profile test exists)
    for n in range(4):
        for g in range(n + 1, 5):
            for f in (0, F):
                rc, nc = max_ranks(n, g, f), max_ranks(g, g, f)
                eq_r = [min(rc[i], nc[i]) for i in range(4)]
                a = hero_index_t(n, g, f, 1, eq_r, MAX_GEAR, 3, True, 1 + KIT_TOL, AWK_STEP + AWK_TOL, FORM_STEP + FORM_TOL,
                                 ATK_BEAT + BEAT_TOL, RELIC_BEAT + RELIC_TOL)
                b = hero_index_t(g, g, f, 1, eq_r, MAX_GEAR, 3, True, 1 - KIT_TOL, AWK_STEP - AWK_TOL, FORM_STEP - FORM_TOL,
                                 ATK_BEAT - BEAT_TOL, RELIC_BEAT - RELIC_TOL)
                st = max(st, a / b)
    print("  (if every per-item band stacked adversarially with no profile check, the worst ratio would be %.4f — the profile "
          "test is what keeps rule #3)" % st)
    w_eq, w_mx, arg_eq, arg_mx = 0.0, 0.0, None, None
    for n in range(4):
        for g in range(n + 1, 5):
            for L in (1, 10, 20, 30):
                for f in range(F + 1):
                    rc, nc = max_ranks(n, g, f), max_ranks(g, g, f)
                    eq_r = [min(rc[i], nc[i]) for i in range(4)]
                    for gear, rb, s4 in ((ZERO_GEAR, 0, False), (MAX_GEAR, 3, True)):
                        r = hero_index_t(n, g, f, L, eq_r, gear, rb, s4, *hi) / hero_index_t(g, g, f, L, eq_r, gear, rb, s4, *lo)
                        if r > w_eq:
                            w_eq, arg_eq = r, (GEM_EN[n], GEM_EN[g], f, L)
                rm = hero_index_t(n, g, F, L, max_ranks(n, g, F), MAX_GEAR, 3, True, *hi) / \
                    hero_index_t(g, g, F, L, max_ranks(g, g, F), MAX_GEAR, 3, True, *lo)
                if rm > w_mx:
                    w_mx, arg_mx = rm, (GEM_EN[n], GEM_EN[g], L)
    print("  worst equal-investment ratio %.4f at %s->%s f%d Lv%d · worst max-investment ratio %.4f at %s->%s Lv%d" % (
        w_eq, arg_eq[0], arg_eq[1], arg_eq[2], arg_eq[3], w_mx, arg_mx[0], arg_mx[1], arg_mx[2]))
    inv("rule #3 holds with every real-kit tolerance at its adversarial edge (equal investment)", w_eq < 1.0, "worst %.4f" % w_eq)
    inv("rule #3 holds with every real-kit tolerance at its adversarial edge (max investment)", w_mx < 1.0, "worst %.4f" % w_mx)
    wc = 0.0
    for n in range(3):
        for g in range(n + 1, 4):
            for f in range(F + 1):
                for cl in (1, 10, 20):
                    wc = max(wc, champ_index(n, g, f, cl, 12) * (1 + CHAMP_KIT_TOL) / (champ_index(g, g, f, cl, 12) * (1 - CHAMP_KIT_TOL)))
    print("  champions across classes (recut kit +%.0f%% vs the weakest native of its current gem -%.0f%%): worst %.4f" % (
        100 * CHAMP_KIT_TOL, 100 * CHAMP_KIT_TOL, wc))
    inv("champion rule #3 across classes with KIT_INDEX +-3%", wc < 1.0, "worst %.4f" % wc)
    # recut value sandwich (F-CAP): a recut into g at max sits between the natives of g-1 and g
    out = []
    for n in range(4):
        for g in range(n + 1, 5):
            rec = hero_index(n, g, F, 30, max_ranks(n, g, F), MAX_GEAR, 3, True)
            nat = hero_index(g, g, F, 30, max_ranks(g, g, F), MAX_GEAR, 3, True)
            below = hero_index(g - 1, g - 1, F, 30, max_ranks(g - 1, g - 1, F), MAX_GEAR, 3, True)
            out.append("%s->%s %.2f (native %s %.2f; native %s %.2f)" % (GEM_EN[n][:3], GEM_EN[g][:3], rec, GEM_EN[g][:3], nat, GEM_EN[g - 1][:3], below))
    print("  recut value at max (Lv30, f5, all caps, full gear): " + " | ".join(out))


# ---------------------------------------------------------------- 2. sinks
def section_sinks():
    print("\n## 2. Costs and totals (HeroData.PROGRESS, ChampionData, GearData)")
    print("DUP_FRAGS", dict(zip(GEM_EN, DUP_FRAGS)), "| FACET_FRAGS", {GEM_EN[i]: (v, sum(v)) for i, v in enumerate(FACET_FRAGS)})
    print("RECUT_FRAGS", RECUT_FRAGS, "RECUT_COINS", RECUT_COINS, "| OVERFLOW %d frags = 1 Tome" % OVERFLOW_FRAGS_PER_TOME)
    print("| Native | to own-gem Full cut (frags / dups) | to Opal f5 (frags / dups / coins) | champion to Topaz f5 (frags / dups / coins) |")
    print("|---|---|---|---|")
    for n in range(5):
        own = sum(FACET_FRAGS[n])
        tot = sum(sum(FACET_FRAGS[g]) for g in range(n, 5)) + sum(RECUT_FRAGS[g] for g in range(n, 4))
        coins = sum(RECUT_COINS[g] for g in range(n, 4))
        if n <= 3:
            ct = sum(sum(FACET_FRAGS[g]) for g in range(n, 4)) + sum(RECUT_FRAGS[g] for g in range(n, 3))
            cc = sum(RECUT_COINS[g] for g in range(n, 3))
            cs = "%d / %.0f / %d" % (ct, ct / DUP_FRAGS[n], cc)
        else:
            cs = "— (hero-only gem)"
        print("| %s | %d / %.1f | %d / %.1f / %d | %s |" % (GEM_EN[n], own, own / DUP_FRAGS[n], tot, tot / DUP_FRAGS[n], coins, cs))
    cum = [0]
    for r in range(1, 11):
        cum.append(cum[-1] + TOME_COST[r])
    print("TOME_COST r->r+1:", TOME_COST[1:], "| cumulative to rank:", {r + 1: cum[r] for r in range(1, 11)})
    print("SKILL_COINS r->r+1 = 50 r^2:", [skill_coins(r) for r in range(1, 11)], "| per skill to 11 = %d" % sum(skill_coins(r) for r in range(1, 11)))
    print("| Native | max rank (f5) | Tomes per skill | Tomes 3 skills | coins 3 skills | Awakening cap | Tomes Awakening |")
    print("|---|---|---|---|---|---|---|")
    tot_t = tot_c = 0
    for n in range(5):
        cap = skill_cap(n, n, 5)
        t = cum[cap - 1]
        c = sum(skill_coins(r) for r in range(1, cap))
        ak = awaken_cap(n, n)
        ta = cum[ak - 1] if ak else 0
        tot_t += 2 * (3 * t + ta)
        tot_c += 2 * 3 * c
        print("| %s | %d | %d | %d | %d | %s | %d |" % (GEM_EN[n], cap, t, 3 * t, 3 * c, ak or "—", ta))
    print("Roster at native max (10 heroes): %d Tomes, %d coins. All 10 at Opal f5 (recut caps):" % (tot_t, tot_c), end=" ")
    t_all = c_all = 0
    for n in range(5):
        cap = skill_cap(n, 4, 5)
        ak = awaken_cap(n, 4)
        t_all += 2 * (3 * cum[cap - 1] + cum[ak - 1])
        c_all += 2 * (3 * sum(skill_coins(r) for r in range(1, cap)) + sum(skill_coins(r) for r in range(1, ak)))
    print("%d Tomes, %d coins" % (t_all, c_all))
    cl_tot = sum(champ_level_cost(L) for L in range(1, CHAMP_LEVEL_MAX))
    print("Champion Level 1->20: %d coins (L1 %d, L10 %d, L19 %d); cap 2 + 2 x world, 20 in Invasion" % (
        cl_tot, champ_level_cost(1), champ_level_cost(10), champ_level_cost(19)))
    it_c = CRAFT["item"][0] + sum(temper_cost("item", r)[0] for r in range(12))
    it_m = CRAFT["item"][1] + sum(temper_cost("item", r)[1] for r in range(12))
    hr_c = CRAFT["hero_relic"][0] + sum(temper_cost("hero_relic", r)[0] for r in range(12))
    hr_m = CRAFT["hero_relic"][1] + sum(temper_cost("hero_relic", r)[1] for r in range(12))
    cr_c = CRAFT["champ_relic"][0] + sum(temper_cost("champ_relic", r)[0] for r in range(12))
    cr_m = CRAFT["champ_relic"][1] + sum(temper_cost("champ_relic", r)[1] for r in range(12))
    print("Workshop to +12: item %d coins / %d mats; hero relic %d / %d; champion relic %d / %d" % (it_c, it_m, hr_c, hr_m, cr_c, cr_m))
    ws_c = 12 * it_c + len(HEROES) * hr_c + len(CHAMPS) * cr_c
    ws_m = 12 * it_m + len(HEROES) * hr_m + len(CHAMPS) * cr_m
    print("Workshop all (12 items + %d relics): %d coins, %d materials" % (len(HEROES) + len(CHAMPS), ws_c, ws_m))
    print("Item stats by rank (wearer-independent):")
    for slot in SLOTS:
        print("  %-6s " % slot + " ".join("+%d:%s" % (r, ",".join("%s %.3f" % kv for kv in item_stats(slot, r).items())) for r in (0, 3, 4, 6, 8, 9, 12)))
    recut_all = 2 * sum(sum(RECUT_COINS[g] for g in range(n, 4)) for n in range(5))
    recut_ch = sum(sum(RECUT_COINS[g] for g in range(d["n"], 3)) for d in CHAMPS.values())
    hero_lv = len(HEROES) * sum(E.hero_cost(L) for L in range(1, 30))
    print("Coin sinks of the hero system (upper bounds): hero levels (10 heroes, no sync) %d; recut %d (heroes) + %d (champions); "
          "skills %d; Champion Level %d; Workshop %d -> total %d (Meta-1 Arsenal = 578270)" % (
              hero_lv, recut_all, recut_ch, c_all, cl_tot, ws_c, hero_lv + recut_all + recut_ch + c_all + cl_tot + ws_c))


# ---------------------------------------------------------------- 3. Portal
def section_portal(n_mc):
    print("\n## 3. Portal (PortalData): exact odds, pity chain, Monte Carlo (%d summons)" % n_mc)
    cons, dist = portal_exact()
    print("Base per summon (no pity): " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(PORTAL_BASE[g])) for g in G))
    print("Consolidated (exact, stationary pity chain): " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(cons[g])) for g in G))
    lp = cons["L"] + cons["M"]
    ep = cons["E"] + lp
    print("Topaz+ consolidated %s (1 per %.2f summons) · Amethyst+ %s (1 per %.2f) · Opal 1 per %.1f" % (
        fmt_pct(lp), 1 / lp, fmt_pct(ep), 1 / ep, 1 / cons["M"]))
    rng = random.Random(20261006)
    ps = {"since_e": 0, "since_l": 0}
    cnt = collections.Counter()
    gaps_e, gaps_l, gaps_m = [], [], []
    le = ll = lm = 0
    for i in range(1, n_mc + 1):
        g = portal_gem(ps, rng)
        cnt[g] += 1
        gi = GI[g]
        if gi >= 2:
            gaps_e.append(i - le)
            le = i
        if gi >= 3:
            gaps_l.append(i - ll)
            ll = i
        if gi == 4:
            gaps_m.append(i - lm)
            lm = i
    mc = {g: cnt[g] / n_mc for g in G}
    z = max(abs(mc[g] - cons[g]) / math.sqrt(cons[g] * (1 - cons[g]) / n_mc) for g in G)
    chi = sum((cnt[g] - n_mc * cons[g]) ** 2 / (n_mc * cons[g]) for g in G)
    print("Monte Carlo: " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(mc[g])) for g in G) + " | max |z| %.2f, chi2(4 df) %.2f" % (z, chi))
    print("Gaps: Amethyst+ mean %.2f max %d | Topaz+ mean %.2f p50 %d p90 %d max %d | Opal mean %.1f p50 %d p90 %d max %d" % (
        statistics.mean(gaps_e), max(gaps_e), statistics.mean(gaps_l), pct(gaps_l, .5), pct(gaps_l, .9), max(gaps_l),
        statistics.mean(gaps_m), pct(gaps_m, .5), pct(gaps_m, .9), max(gaps_m)))
    inv("Portal MC matches the exact table (|z| <= 4)", z <= 4.0, "max |z| %.2f" % z)
    inv("Amethyst+ hard pity: gap <= %d" % PITY_E_HARD, max(gaps_e) <= PITY_E_HARD, "max %d" % max(gaps_e))
    inv("Topaz+ hard pity: gap <= %d" % PITY_L_HARD, max(gaps_l) <= PITY_L_HARD, "max %d" % max(gaps_l))
    # P(Topaz+) by summon index since the last Topaz+ (the soft-pity curve shown in (i))
    print("Topaz+ chance by summon # since the last Topaz+: " + " ".join("%d:%.0f%%" % (k, 100 * portal_pl(k - 1)) for k in (1, 20, 21, 22, 23, 25, 27, 29, 30)))
    w0 = portal_x10_best((0, 0))
    w = portal_x10_best((0, 0), welcome=True)
    s = portal_x10_best_stationary(dist)
    print("x10 best gem — fresh pity, no welcome rule: " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(w0.get(g, 0))) for g in G))
    print("x10 best gem — WELCOME x10 with the disclosed Topaz+ rule: " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(w.get(g, 0))) for g in G))
    inv("welcome x10 always holds a Topaz+ (disclosed welcome rule)", w.get("C", 0) + w.get("R", 0) + w.get("E", 0) < 1e-12,
        "P(best <= Amethyst) = %.2e" % (w.get("C", 0) + w.get("R", 0) + w.get("E", 0)))
    print("x10 best gem — typical (stationary pity): " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(s.get(g, 0))) for g in G))
    inv("welcome x10 holds an Amethyst+ (hard pity 10)", w.get("C", 0) + w.get("R", 0) < 1e-12, "P(best <= Sapphire) = %.2e" % (w.get("C", 0) + w.get("R", 0)))
    # odds table per pool stage (per hero)
    print("\n### 3b. Disclosed odds per hero by pool stage (consolidated gem odds x share inside the gem)")
    stages = [
        ("A. Portal opens (L20): own Bolt, Titan", {"titan", "bolt"}, None),
        ("B. + Seer (L24) and one of each gem", {"titan", "bolt", "seer", "arin", "eira", "iskar", "vesta", "lumen"}, None),
        ("C. all 10 owned, no Focus set", set(HEROES), None),
        ("D. all 10 owned, Focus = Vesta / Lumen / Seer / Bolt / Titan", set(HEROES), {"L": "vesta", "M": "lumen", "E": "seer", "R": "bolt", "C": "titan"}),
    ]
    order = list(HEROES)
    print("| Stage | " + " | ".join("%s (%s)" % (h, G[HEROES[h]["n"]]) for h in order) + " |")
    print("|---|" + "---|" * len(order))
    for label, owned, focus in stages:
        cells = []
        for h in order:
            gi = HEROES[h]["n"]
            pool = [x for x, d in HEROES.items() if d["n"] == gi and (x not in STARTERS or x in owned)]
            if h not in pool:
                cells.append("—")
                continue
            un = [x for x in pool if x not in owned]
            if un:
                share = (1.0 / len(un)) if h in un else 0.0
            elif focus and G[gi] in focus:
                share = FOCUS_TOTAL if h == focus[G[gi]] else (1 - FOCUS_TOTAL) / (len(pool) - 1)
            else:
                share = 1.0 / len(pool)
            cells.append("%.2f%%" % (100 * cons[G[gi]] * share))
        print("| %s | %s |" % (label, " | ".join(cells)))
    print("Seals: +1 per summon; picks Amethyst %d · Topaz %d · Opal %d (an owned pick = 2 x its duplicate fragments: "
          "%d / %d / %d = %.2f / %.2f / %.2f fragments per Seal)" % (SEAL_PRICES["E"], SEAL_PRICES["L"], SEAL_PRICES["M"],
              2 * DUP_FRAGS[2], 2 * DUP_FRAGS[3], 2 * DUP_FRAGS[4], 2 * DUP_FRAGS[2] / SEAL_PRICES["E"],
              2 * DUP_FRAGS[3] / SEAL_PRICES["L"], 2 * DUP_FRAGS[4] / SEAL_PRICES["M"]))
    print("Focus: the Focus hero gets exactly %.0f%% of its gem's results; the others share %.0f%% (any roster size)" % (
        100 * FOCUS_TOTAL, 100 * (1 - FOCUS_TOTAL)))
    ev = sum(cons[g] * DUP_FRAGS[GI[g]] for g in G)
    print("Expected duplicate fragments per summon (all owned): %.2f; per x10: %.1f" % (ev, 10 * ev))
    return cons


def portal_x10_best_stationary(dist):
    out = collections.defaultdict(float)
    for st, p in dist.items():
        for g, q in portal_x10_best(st).items():
            out[g] += p * q
    return out


# ---------------------------------------------------------------- 4. Hero Chests
def section_chest(n_mc):
    print("\n## 4. Hero Chests: per-card odds, best card, Monte Carlo (%d chests)" % n_mc)
    print("Per champion card: " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(v)) for g, v in CHEST_ODDS.items()))
    for kind in ("hero", "grand"):
        ex = chest_exact_best(kind)
        print("%-5s chest best card (no pity): " % kind + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(ex[g])) for g in G[:4] if ex[g] > 0))
    rng = random.Random(7)
    pity = {"since_l": 0, "total": 0}
    cnt = collections.Counter()
    gaps, last = [], 0
    n_cards = 0
    for i in range(1, n_mc + 1):
        kind = "grand" if i % 6 == 0 else "hero"
        cards = roll_chest(kind, pity, rng)
        for c in cards:
            cnt[c] += 1
        n_cards += len(cards)
        if "L" in cards:
            gaps.append(i - last)
            last = i
    print("Stream (5 Hero : 1 Grand), with pity: per card " + " · ".join("%s %s" % (GEM_EN[GI[g]], fmt_pct(cnt[g] / n_cards)) for g in G[:4]) +
          " | Topaz champion card every %.2f chests, max gap %d" % (statistics.mean(gaps), max(gaps)))
    inv("chest Topaz hard pity: gap <= %d" % CHEST_PITY_L, max(gaps) <= CHEST_PITY_L, "max %d" % max(gaps))
    rng = random.Random(8)
    cnt = collections.Counter()
    N = n_mc
    for i in range(N):
        pt = {"since_l": 0, "total": 0}
        cards = roll_chest("hero", pt, rng)
        cnt[max(cards, key=lambda g: GI[g])] += 1
    ex = chest_exact_best("hero")
    z = max(abs(cnt[g] / N - ex[g]) / math.sqrt(max(ex[g] * (1 - ex[g]), 1e-12) / N) for g in G[:4])
    inv("Hero Chest MC matches the exact best-card table (|z| <= 4)", z <= 4.0, "max |z| %.2f" % z)
    efr = sum(CHEST_ODDS[g] * DUP_FRAGS[GI[g]] for g in CHEST_ODDS)
    print("Expected champion fragments per card once the gem is complete: %.2f (Hero Chest %.1f, Grand %.1f + guaranteed Amethyst+)" % (
        efr, 2 * efr, 3 * efr))


# ---------------------------------------------------------------- 5. campaign
_M1 = {}


def meta1_power_by_level(kind, seeds, levels):
    """Meta-1 baseline: median power at the first attempt of each level."""
    if (kind, seeds, levels) in _M1:
        return _M1[(kind, seeds, levels)]
    per = collections.defaultdict(list)
    for s in range(seeds):
        p, cps, sess, rlog, cer = E.simulate(kind, 1000 + s, levels)
        seen = set()
        for l, ratio, won, raw in rlog:
            if l in seen:
                continue
            seen.add(l)
            dl = E.stage_of(l)[1]
            per[l].append(raw * E.demand(dl))
    _M1[(kind, seeds, levels)] = {l: statistics.median(v) for l, v in per.items()}
    return _M1[(kind, seeds, levels)]


INV_DEMAND_MU = 0.98   # v2 final: Invasion re-bake at 98% of the capped EXPECTED ratio (full-run casual loss streak p90 4 -> 3,
                       # max attempts p90 5 -> 4; Meta-1's own Invasion curve already falls to 53% casual boss win at Inv W7)


def calibrate_tf(seeds, levels=112):
    """TEAM_DEMAND base: the EXPECTED profile = a casual player who only ever fields the best STARTER and the two
    scripted champions (framework §9.8), simulated as a policy. Ratio of its power to Meta-1 casual power, per world.
    Also returns the median full account's ratio (Portal / chest luck included) for reference."""
    p1 = meta1_power_by_level("casual", seeds, levels)
    out = []
    for exo in (True, False):
        ratios = collections.defaultdict(list)
        for s in range(seeds):
            p, snaps, sess, rlog, cer = simulate("casual", 1000 + s, levels, expected_only=exo)
            seen = set()
            for r in rlog:
                l, P, mode = r[0], r[4], r[7]
                if l in seen or mode == "replay":
                    continue
                seen.add(l)
                n = l if l <= E.CAMPAIGN_LEVELS else l - E.CAMPAIGN_LEVELS
                ratios[tf_index(mode, E.world_of(n))].append(P / p1[l])
        out.append({w: round(statistics.median(v), 3) for w, v in sorted(ratios.items())})
    base = {w: max(1.0, v) for w, v in out[0].items()}
    # v2: Invasion inherits the W7 value (late hero investment is upside, not a reason to keep raising enemy budgets)
    for w in list(base):
        if w > 7:
            base[w] = min(base[w], base.get(7, base[w]))
    return base, out[1]


def summarize_quiet(res):
    levels = 112
    att = [sum(1 for r in x[3] if r[7] != "replay") for x in res]
    boss = collections.defaultdict(list)
    for x in res:
        _, _, bw = walls([r for r in x[3] if r[7] != "replay"])
        for w, v in bw.items():
            boss[w].extend(v)
    bwr = {w: 100 * sum(v) / len(v) for w, v in boss.items()}
    return dict(win=100.0 * levels / statistics.mean(att), boss_min=min(v for w, v in bwr.items() if w <= 7),
                inv_min=min(v for w, v in bwr.items() if w > 7))


def walls(rlog):
    per = collections.Counter(r[0] for r in rlog)
    cur = best = 0
    for r in rlog:
        cur = 0 if r[2] else cur + 1
        best = max(best, cur)
    boss = collections.defaultdict(list)
    for r in rlog:
        l = r[0]
        if l <= 2 * E.CAMPAIGN_LEVELS and r[7] != "replay":
            n = l if l <= E.CAMPAIGN_LEVELS else l - E.CAMPAIGN_LEVELS
            if E.is_boss(n):
                boss[tf_index(r[7], E.world_of(n))].append(r[9])    # attempt win probability (low-variance estimator)
    return max(per.values()), best, boss


def summarize(label, res, levels):
    print("=" * 112)
    print(label)
    att = [sum(1 for r in x[3] if r[7] != "replay") for x in res]
    mx, streak, boss = [], [], collections.defaultdict(list)
    for x in res:
        a_, b_, bw = walls([r for r in x[3] if r[7] != "replay"])
        mx.append(a_)
        streak.append(b_)
        for w, v in bw.items():
            boss[w].extend(v)
    win = 100.0 * levels / statistics.mean(att)
    bwr = {w: round(100 * sum(v) / len(v)) for w, v in sorted(boss.items())}
    camp = {w: v for w, v in bwr.items() if w <= 7}
    print("attempts for %d levels %.1f (win %.0f%%) | max attempts on one level p50 %d p90 %d max %d | loss streak p50 %d p90 %d max %d" % (
        levels, statistics.mean(att), win, pct(mx, .5), pct(mx, .9), max(mx), pct(streak, .5), pct(streak, .9), max(streak)))
    print("boss win rate by world (1-7 campaign, 8-14 Invasion):", bwr)
    sess = [y for x in res for y in x[2]]
    cer = [y for x in res for y in x[4]]
    cm1 = [y for x in res for y in x[0].sess_cer_m1]
    print("sessions with >=1 upgrade %.0f%%, upgrades/session %.2f, ceremony share of session time: mean %.1f%% p90 %.0f%% "
          "(Meta-1 convention, every Stone Cache inline: %.1f%%; hero systems %.1f s per level)" % (
        100 * sum(1 for y in sess if y > 0) / max(1, len(sess)), statistics.mean(sess), 100 * statistics.mean(cer), 100 * pct(cer, .9),
        100 * statistics.mean(cm1), statistics.mean(x[0].cer_hero / max(1, x[0].attempt) for x in res)))
    cb = collections.defaultdict(float)
    for x in res:
        for k, v in x[0].cer_by.items():
            cb[k] += v / max(1, x[0].attempt) / len(res)
    print("hero ceremony s/attempt by kind: " + ", ".join("%s %.2f" % kv for kv in sorted(cb.items(), key=lambda kv: -abs(kv[1]))))
    spent = collections.defaultdict(float)
    for x in res:
        for k, v in x[0].spent.items():
            spent[k] += v / len(res)
    tot = sum(spent.values()) or 1
    print("coin spend: " + ", ".join("%s %.0f%%" % (k, 100 * v / tot) for k, v in sorted(spent.items(), key=lambda kv: -kv[1])))
    shares = power_shares([x[0] for x in res])
    sh60 = power_shares([x[0] for x in res], "cp60")
    print("power growth share at L60: " + ", ".join("%s %.0f%%" % (k, 100 * v) for k, v in sh60.items()))
    print("power growth share at L%d: " % levels + ", ".join("%s %.0f%%" % (k, 100 * v) for k, v in shares.items()))
    print("mean machine level at L%d: %.2f (of 15)" % (levels, statistics.mean(statistics.mean(m["lvl"] for m in x[0].machines.values()) for x in res)))
    th = collections.Counter(G[HEROES[x[0].team_h]["n"]] for x in res)
    print("team hero native gem at L%d: %s | champions in team %.2f, mean team champion gem %.2f, Champion Lv %.1f" % (
        levels, dict(th), statistics.mean(len(x[0].team_c) for x in res),
        statistics.mean(statistics.mean([x[0].cs[c]["gem"] for c in x[0].team_c] or [0]) for x in res),
        statistics.mean(x[0].cl for x in res)))
    return dict(win=win, boss_min=min(camp.values()) if camp else 100, inv_min=min([v for w, v in bwr.items() if w > 7] or [100]),
                streak_p90=pct(streak, .9), maxatt_p90=pct(mx, .9), cer=statistics.mean(cer), mach_share=shares["machines"],
                mach60=sh60.get("machines", 0), largest=max(shares, key=shares.get),
                luck={x[0].rng_seed: x[0].cps.get("luck56", 0) for x in res},
                with_buy=sum(1 for y in sess if y > 0) / max(1, len(sess)), shares=shares,
                seed_win={x[0].rng_seed: 100.0 * levels / max(1, sum(1 for r in x[3] if r[7] != "replay")) for x in res},
                res=res, mlv=statistics.mean(statistics.mean(m["lvl"] for m in x[0].machines.values()) for x in res))


def power_shares(players, cp=None):
    acc = collections.defaultdict(float)
    players = [p for p in players if cp is None or cp in p.cps]
    for p in players:
        pt = p.parts_full() if cp is None else p.cps[cp]
        g = {"machines": W_M * (pt["m"] - 1),
             "heroes": W_H * (pt["h"] - 1) + W_A * pt["rally"],
             "champions + synergy": W_C * pt["c"] + W_M * pt["m"] * B2_EFF * pt["msyn"] + W_A * pt["syn_army"],
             "army (Barracks)": W_A * (pt["a"] - 1)}
        g["tactics"] = pt["t"] - 1                    # Meta-1 convention (economy_sim.summarize)
        tg = sum(g.values())
        for k, v in g.items():
            acc[k] += v / tg / len(players)
    return dict(acc)


def run_set(kind, seeds, levels, tf, policy="greedy", payer=None, expected_only=False, base=1000):
    out = []
    for s in range(seeds):
        r = simulate(kind, base + s, levels, policy, payer, tf=tf, expected_only=expected_only)
        r[0].rng_seed = base + s
        out.append(r)
    return out


def section_campaign(seeds, cal_seeds):
    print("\n## 5. Campaign + Invasion with heroes, champions and the EXPECTED-profile demand re-bake")
    tf2, tf_full = calibrate_tf(cal_seeds, 112)
    # margin search: the largest mu keeping the EXPECTED-only casual floor >= 67% boss wins (65% + 2 pp) in every
    # campaign world and >= 62% in every Invasion world (boss win = mean attempt win probability)
    mu_rows = []
    best_mu = 1.0
    for mu in (1.00, 1.01, 1.02, 1.03, 1.04, 1.05):
        tfm = {w: round(v * mu * (INV_DEMAND_MU if w > 7 else 1.0), 3) for w, v in tf2.items()}
        r = summarize_quiet(run_set("casual", max(16, seeds // 2), 112, tfm, expected_only=True, base=5000))
        mu_rows.append((mu, r["boss_min"], r["inv_min"], r["win"]))
        if r["boss_min"] >= 67 and r["inv_min"] >= 62:
            best_mu = mu
    print("Margin search (EXPECTED-only casual): " + " | ".join("mu %.2f: boss min %.0f%%, Invasion min %.0f%%, win %.0f%%" % m for m in mu_rows))
    tf = {w: round(v * best_mu * (INV_DEMAND_MU if w > 7 else 1.0), 3) for w, v in tf2.items()}
    print("TEAM_DEMAND = (EXPECTED-profile power / Meta-1 power) x mu %.2f (Invasion x INV_DEMAND_MU %.2f). LevelGen enemy budget multiplier per world:" % (best_mu, INV_DEMAND_MU))
    print("| World | " + " | ".join(("W%d" % w) if w <= 7 else ("Inv W%d" % (w - 7)) for w in sorted(tf)) + " |")
    print("|---|" + "---|" * len(tf))
    print("| EXPECTED profile (§9.8: best starter + 2 scripted champions, played as a policy) / Meta-1 | " + " | ".join("%.3f" % tf2.get(w, 1) for w in sorted(tf)) + " |")
    print("| median full account (Portal/chest luck) / Meta-1 | " + " | ".join("%.3f" % tf_full[w] for w in sorted(tf)) + " |")
    print("| **ADOPTED TEAM_DEMAND** | " + " | ".join("**%.3f**" % tf[w] for w in sorted(tf)) + " |")
    print("\n### 5a. All archetypes, greedy (Best upgrade), 112 levels (campaign 56 + Invasion 56), demand x TEAM_DEMAND")
    R = {}
    for kind in ("casual", "regular", "hardcore"):
        a = E.ARCHETYPES[kind]
        R[kind] = summarize("%s (%d lv/day, %d lv/session, skill %.2f)" % (kind.upper(), a["lpd"], a["lps"], a["skill"]),
                            run_set(kind, seeds, 112, tf), 112)
    print("\n### 5b. Policies, weaker players, luck and payers (112 levels)")
    P = {}
    for kind, pol, ex in (("casual", "spread", False), ("casual", "machines_only", False), ("weak", "greedy", False),
                          ("ad_watcher", "greedy", False), ("casual", "greedy", True)):
        lab = "%s / %s%s" % (kind, pol, " / EXPECTED-only team (starters + scripted champions)" if ex else "")
        P[(kind, pol, ex)] = summarize(lab, run_set(kind, seeds, 112, tf, pol, expected_only=ex), 112)
    free_runs = run_set("casual", seeds, 112, tf)
    pay_runs = run_set("casual", seeds, 112, tf, payer="starter")
    PS = summarize("casual / greedy / Starter Arsenal ($2.99 coins + blueprints)", pay_runs, 112)
    # two-track property (critique B1): money never raises a random-source currency (same seed, free vs payer)
    def tot(r, cur, skip=()):
        return sum(v for (ph, c, src), v in r[0].inc.items() if c == cur and src not in skip)
    deltas = {cur: [tot(b, cur) - tot(a, cur) for a, b in zip(free_runs, pay_runs)] for cur in ("beacons", "seals", "chests", "tomes")}
    print("Two-track property, casual, same seeds, Starter Arsenal - free over 112 levels: " + " · ".join(
        "%s mean %+.2f max %+.2f" % (c, statistics.mean(v), max(v)) for c, v in deltas.items()))
    def src(r, cur, names):
        return sum(v for (ph, c, s), v in r[0].inc.items() if c == cur and s in names)
    play = [src(b, "beacons", ("first_clear", "boss", "welcome_x10")) - src(a, "beacons", ("first_clear", "boss", "welcome_x10"))
            for a, b in zip(free_runs, pay_runs)]
    rated = sum(src(b, "beacons", ("track",)) for b in pay_runs)
    per_day = [(tot(b, "beacons", ("first_clear", "boss", "welcome_x10")) / max(1, b[0].day_end)) -
               (tot(a, "beacons", ("first_clear", "boss", "welcome_x10")) / max(1, a[0].day_end)) for a, b in zip(free_runs, pay_runs)]
    print("  play-count Beacons (first clears, bosses, welcome) delta per seed max %+.2f · rating-driven Beacons %.0f · "
          "time-based Beacons per day delta mean %+.3f" % (max(abs(x) for x in play), rated, statistics.mean(per_day)))
    # luck: paired per seed (same seed, full team vs EXPECTED-only)
    full = R["casual"]["seed_win"]
    exo = P[("casual", "greedy", True)]["seed_win"]
    d = [full[s] - exo[s] for s in full if s in exo]
    print("\nPortal/chest upside (casual, same seed: full team - EXPECTED-only team), win-rate pp: mean %+.1f p10 %+.1f p50 %+.1f p90 %+.1f" % (
        statistics.mean(d), pct(d, .1), pct(d, .5), pct(d, .9)))
    lk = R["casual"]["luck"]
    order = sorted(full, key=lambda s: lk.get(s, 0))
    q = max(1, len(order) // 4)
    lo, hi = order[:q], order[-q:]
    wl, wh = statistics.mean(full[s] for s in lo), statistics.mean(full[s] for s in hi)
    print("Luck quartiles (Topaz+ summons by L56): bottom 25%% (%.1f Topaz+) win %.1f%% | top 25%% (%.1f Topaz+) win %.1f%% | gap %.1f pp" % (
        statistics.mean(lk[s] for s in lo), wl, statistics.mean(lk[s] for s in hi), wh, wh - wl))
    print("\n### 5c. Invariants")
    for kind in ("casual", "regular", "hardcore"):
        inv("%s boss win >= 65%% every campaign world" % kind, R[kind]["boss_min"] >= 65, "min %d%%" % R[kind]["boss_min"])
        inv("%s Invasion boss win >= 60%% every world" % kind, R[kind]["inv_min"] >= 60, "min %d%%" % R[kind]["inv_min"])
        inv("%s loss streak p90 <= 3" % kind, R[kind]["streak_p90"] <= 3, "p90 %d" % R[kind]["streak_p90"])
        inv("%s max attempts on one level p90 <= 4" % kind, R[kind]["maxatt_p90"] <= 4, "p90 %d" % R[kind]["maxatt_p90"])
        inv("%s ceremony <= 15%% of session time" % kind, R[kind]["cer"] <= 0.15, "%.1f%%" % (100 * R[kind]["cer"]))
        inv("%s machines >= 50%% of power growth at L60 (Meta-1 checkpoint)" % kind, R[kind]["mach60"] >= 0.50, "%.0f%%" % (100 * R[kind]["mach60"]))
        inv("%s machines >= 40%% of power growth at L112 and still the largest share" % kind,
            R[kind]["mach_share"] >= 0.40 and R[kind]["largest"] == "machines", "%.0f%%, largest: %s" % (100 * R[kind]["mach_share"], R[kind]["largest"]))
    inv("casual sessions with a purchase >= 85%", R["casual"]["with_buy"] >= 0.85, "%.0f%%" % (100 * R["casual"]["with_buy"]))
    inv("casual win rate 65-85%", 65 <= R["casual"]["win"] <= 85, "%.0f%%" % R["casual"]["win"])
    inv("casual spread policy boss win >= 60%", P[("casual", "spread", False)]["boss_min"] >= 60, "min %d%%" % P[("casual", "spread", False)]["boss_min"])
    inv("casual machines-only boss win >= 55%", P[("casual", "machines_only", False)]["boss_min"] >= 55, "min %d%%" % P[("casual", "machines_only", False)]["boss_min"])
    inv("weak casual boss win >= 55%", P[("weak", "greedy", False)]["boss_min"] >= 55, "min %d%%" % P[("weak", "greedy", False)]["boss_min"])
    inv("EXPECTED-only casual (no Portal/chest luck) boss win >= 65% every campaign world", P[("casual", "greedy", True)]["boss_min"] >= 65,
        "min %d%%" % P[("casual", "greedy", True)]["boss_min"])
    inv("luck gap: top-25% vs bottom-25% Portal luck casual win rate <= 6 pp", wh - wl <= 6.0, "%.1f pp" % (wh - wl))
    inv("Portal/chest upside over the EXPECTED-only floor, mean <= +8 pp", statistics.mean(d) <= 8.0, "%+.1f pp" % statistics.mean(d))
    inv("ad watcher win-rate gain <= 6 pp", P[("ad_watcher", "greedy", False)]["win"] - R["casual"]["win"] <= 6,
        "%+.1f pp" % (P[("ad_watcher", "greedy", False)]["win"] - R["casual"]["win"]))
    inv("Starter Arsenal win-rate gain <= 3 pp", PS["win"] - R["casual"]["win"] <= 3, "%+.1f pp" % (PS["win"] - R["casual"]["win"]))
    inv("two-track: no Beacon source is keyed to money (play-count Beacons identical per seed; no rating-driven Beacons)",
        max(abs(x) for x in play) < 1e-9 and rated == 0,
        "play delta %.2f, rated %.0f (time-based per-day delta %+.3f comes only from faster progress, capped by the "
        "Starter <= +3 pp rule)" % (max(abs(x) for x in play), rated, statistics.mean(per_day)))
    for kind in ("casual", "regular", "hardcore"):
        cs = power_shares([x[0] for x in R[kind]["res"]], "cp60").get("champions + synergy", 0)
        inv("%s champions + synergy <= 12%% of power growth at L60 (critique M2)" % kind, cs <= 0.12, "%.1f%%" % (100 * cs))
    return tf


# ---------------------------------------------------------------- 6. long horizon
MILESTONES = [("champions", "champions + Hero Chest (L14)"), ("portal", "Portal + welcome x10 (L20)"),
              ("hero_gem_E", "first Amethyst hero"), ("hero_gem_L", "first Topaz hero"), ("hero_gem_M", "first Opal hero"),
              ("seal_pick_M", "first Opal by Seals (pick)"), ("champ_gem_E", "first Amethyst champion"),
              ("champ_gem_L", "first Topaz champion"), ("first_full_cut", "first Full cut (any)"),
              ("recut_available", "first recut available (Full cut + fragments)"),
              ("first_recut", "first recut done (any)"), ("first_recut_h", "first hero recut"),
              ("first_awakening", "first Awakening"), ("full_team", "full team (hero + 3 champions)"),
              ("workshop", "Workshop (L32)"), ("skill_rank_7", "first skill rank 7"), ("skill_rank_9", "first skill rank 9"),
              ("skill_rank_11", "first skill rank 11 (Opal max)"), ("skill_native_max_L", "a Topaz hero at native max rank"),
              ("first_item_12", "first item at +12"), ("all_heroes", "all 10 heroes"), ("all_champions", "all %d champions" % len(CHAMPS)),
              ("hero_recut_to_M", "first hero recut to Opal"), ("hero_opal_f5", "first hero at Opal f5"),
              ("quartz_hero_opal_possible", "a Quartz hero has the fragments for Opal f5")]
SNAP_DAYS = (1, 3, 7, 14, 30, 60, 90, 180)


def section_long(seeds, tf, days=180):
    print("\n## 6. Long horizon (%d days; campaign -> Invasion -> replays) — income, milestones, snapshots" % days)
    allres = {}
    for kind in ("casual", "regular", "hardcore"):
        res = []
        for s in range(seeds):
            r = simulate(kind, 3000 + s, 10 ** 6, days=days, tf=tf, snap_days=SNAP_DAYS)
            res.append(r)
        allres[kind] = res
    # ---- income per day by phase
    print("\n### 6a. Earned income per day (mean over seeds), by phase and source")
    cur_order = ["beacons", "seals", "tomes", "mats", "frags", "chests"]
    for kind, res in allres.items():
        lpd = E.ARCHETYPES[kind]["lpd"]
        print("-- %s (%d attempts/day)" % (kind, lpd))
        for phase in ("campaign", "invasion", "post"):
            dd = [r[0].phase_att[phase] / lpd for r in res]
            dmean = statistics.mean(dd)
            if dmean < 0.5:
                continue
            line = []
            for cur in cur_order:
                srcs = collections.defaultdict(float)
                for r in res:
                    dph = r[0].phase_att[phase] / lpd
                    if dph <= 0:
                        continue
                    for (ph, c, src), v in r[0].inc.items():
                        if ph == phase and c == cur:
                            srcs[src] += v / dph / len(res)
                tot = sum(srcs.values())
                if tot <= 0:
                    continue
                line.append("%s %.2f/day [%s]" % (cur, tot, ", ".join("%s %.2f" % kv for kv in sorted(srcs.items(), key=lambda kv: -kv[1]))))
            print("   %-8s (%.1f days): %s" % (phase, dmean, " | ".join(line)))
    # ---- milestones
    print("\n### 6b. Milestones: day reached p10 / p50 / p90 (— = not by day %d; %% = share of seeds reaching it)" % days)
    print("| Milestone | " + " | ".join(allres) + " |")
    print("|---|" + "---|" * len(allres))
    MS = {}
    for key, label in MILESTONES:
        cells = []
        for kind, res in allres.items():
            v = [r[0].ev.get(key) for r in res]
            got = [x for x in v if x is not None]
            if not got:
                cells.append("—")
                continue
            full = sorted(x if x is not None else 10 ** 6 for x in v)
            f = lambda q: ("%d" % pct(full, q)) if pct(full, q) < 10 ** 6 else "—"
            cells.append("%s / %s / %s (%d%%)" % (f(.1), f(.5), f(.9), 100 * len(got) // len(v)))
            MS[(kind, key)] = pct(full, .5)
        print("| %s | %s |" % (label, " | ".join(cells)))
    # ---- snapshots
    print("\n### 6c. Account snapshots (p50) at day 1 / 3 / 7 / 14 / 30 / 60 / 90 / 180")
    keys = [("level", "frontier"), ("heroes", "heroes owned"), ("best_native", "best native gem (0=Q..4=O)"),
            ("opal_heroes", "Opal heroes owned"), ("team_native", "team hero native"), ("team_gem", "team hero gem"),
            ("team_f", "team hero facets"), ("team_lvl", "team hero level"), ("team_ranks", "team hero Ult+Atk+Rally ranks"),
            ("team_awk", "Awakening rank"), ("champs", "champions owned"), ("n_team_c", "champions in team"),
            ("champ_gem", "mean team champion gem"), ("cl", "Champion Level"), ("recuts", "recuts done"),
            ("summons", "summons done"), ("seals", "Seals banked"), ("tomes", "Tomes banked"), ("gear", "team gear mean +rank"),
            ("relic", "hero relic +rank (-1 none)"), ("avg_mach", "avg machine Lv"), ("h", "hero index h"), ("c", "champion index c")]
    for kind, res in allres.items():
        print("-- %s" % kind)
        print("| metric | " + " | ".join("d%d" % d for d in SNAP_DAYS) + " |")
        print("|---|" + "---|" * len(SNAP_DAYS))
        for k, lab in keys:
            cells = []
            for d in SNAP_DAYS:
                vals = [r[1][d][k] for r in res if d in r[1]]
                cells.append(("%.1f" % statistics.median(vals)) if vals else "")
            print("| %s | %s |" % (lab, " | ".join(cells)))
    print("\n### 6d. Power growth share at day %d (p50 accounts)" % days)
    for kind, res in allres.items():
        sh = power_shares([r[0] for r in res])
        print("  %-8s " % kind + ", ".join("%s %.0f%%" % (k, 100 * v) for k, v in sh.items()))
    sh_reg = power_shares([r[0] for r in allres["regular"]])
    inv("regular machines >= 35%% of power growth at day %d (post-content floor)" % days, sh_reg["machines"] >= 0.35,
        "%.0f%%" % (100 * sh_reg["machines"]))
    # ---- pacing invariants
    def ms(kind, key):
        return MS.get((kind, key), 10 ** 6)
    inv("regular first Topaz hero p50 <= day 7", ms("regular", "hero_gem_L") <= 7, "day %s" % ms("regular", "hero_gem_L"))
    inv("casual first Topaz hero p50 <= day 14", ms("casual", "hero_gem_L") <= 14, "day %s" % ms("casual", "hero_gem_L"))
    inv("regular first Opal hero p50 <= day 30", ms("regular", "hero_gem_M") <= 30, "day %s" % ms("regular", "hero_gem_M"))
    inv("casual first Opal hero p50 <= day 45", ms("casual", "hero_gem_M") <= 45, "day %s" % ms("casual", "hero_gem_M"))
    inv("regular first recut p50 <= day 10", ms("regular", "first_recut") <= 10, "day %s" % ms("regular", "first_recut"))
    inv("casual first recut p50 <= day 21", ms("casual", "first_recut") <= 21, "day %s" % ms("casual", "first_recut"))
    inv("all 10 heroes: regular p50 in day 25-100, casual p50 in day 35-140 (slower than v1's day 28; the roster grows by updates)",
        25 <= ms("regular", "all_heroes") <= 100 and 35 <= ms("casual", "all_heroes") <= 140,
        "regular day %s, casual day %s" % (ms("regular", "all_heroes"), ms("casual", "all_heroes")))
    inv("a hero at Opal f5 is a month-plus goal: regular p50 in day 30-90", 30 <= ms("regular", "hero_opal_f5") <= 90, "day %s" % ms("regular", "hero_opal_f5"))
    inv("first skill rank 9: regular p50 <= day 75, casual p50 <= day 110 (v2 target, critique M4)",
        ms("regular", "skill_rank_9") <= 75 and ms("casual", "skill_rank_9") <= 110,
        "regular day %s, casual day %s" % (ms("regular", "skill_rank_9"), ms("casual", "skill_rank_9")))
    inv("time-to-fun: casual champions p50 <= day 5 and Portal + guaranteed Topaz p50 <= day 7 (v1: day 6 / first Topaz day 10)",
        ms("casual", "champions") <= 5 and ms("casual", "portal") <= 7 and ms("casual", "hero_gem_L") <= 7,
        "champions day %s, Portal day %s" % (ms("casual", "champions"), ms("casual", "portal")))
    # dead-currency check (critique M6 / X13)
    print("\n### 6e. Dead currencies at day %d (p50): Tomes earned / banked / spent on Chronicle pages; Seals banked" % days)
    dead = {}
    for kind, res in allres.items():
        earned = statistics.median(sum(v for (ph, c, src), v in r[0].inc.items() if c == "tomes") for r in res)
        banked = statistics.median(r[0].tomes for r in res)
        chron = statistics.median(r[0].cnt["chronicle_tomes"] for r in res)
        pages = statistics.median(r[0].cnt["chronicle_pages"] for r in res)
        seals = statistics.median(r[0].seals for r in res)
        owned_picks = statistics.median(r[0].cnt["seal_owned_picks"] for r in res)
        print("  %-8s Tomes earned %.0f · banked %.0f · Chronicle %.0f Tomes (%.0f pages of %d) · Seals banked %.0f · owned Seal picks %.0f" % (
            kind, earned, banked, chron, pages, 5 * len(HEROES), seals, owned_picks))
        dead[kind] = (earned, banked, seals)
    reg = dead["regular"]
    inv("regular: Tomes banked at day %d <= 25%% of Tomes earned (sink works)" % days, reg[1] <= 0.25 * reg[0], "%.0f of %.0f" % (reg[1], reg[0]))
    inv("regular: Seals banked at day %d <= 120" % days, reg[2] <= 120, "%.0f" % reg[2])
    return allres


def section_meta1(seeds):
    """Reference: the Meta-1 sim itself over the same 112 levels, boss win as mean attempt win probability."""
    print("\n## 7. Meta-1 reference over 112 levels (economy_sim.simulate, no heroes system; %d seeds)" % seeds)
    for kind in ("casual", "regular", "hardcore", "weak"):
        a = E.ARCHETYPES[kind]
        boss = collections.defaultdict(list)
        att = []
        for s in range(seeds):
            p, cps, sess, rlog, cer = E.simulate(kind, 1000 + s, 112)
            att.append(len(rlog))
            for l, ratio, won, raw in rlog:
                n = l if l <= E.CAMPAIGN_LEVELS else l - E.CAMPAIGN_LEVELS
                if E.is_boss(n):
                    wp = 1.0 / (1.0 + math.exp(-(7.0 * (ratio - 1.0) + 3.0 * (a["skill"] - 0.5) + 1.6)))
                    boss[E.world_of(n) + (0 if l <= E.CAMPAIGN_LEVELS else 7)].append(1.0 if l <= E.FORCED_WIN_LEVELS else min(0.98, max(0.12, wp)))
        print("  %-8s win %.0f%% | boss win by world (1-7 campaign, 8-14 Invasion): %s" % (
            kind, 100.0 * 112 / statistics.mean(att), {w: round(100 * statistics.mean(v)) for w, v in sorted(boss.items())}))


def section_migration(seeds, tf):
    print("\n## 8. Migrated v2 saves: the hero systems open on update day (frontier L); catch-up only vs the lump grant")
    cl_runs = [simulate("casual", 7000 + s, 112, tf=tf, expected_only=True) for s in range(max(8, seeds // 2))]
    cl_table = {L: int(statistics.median(r[0].cl_at.get(L, 1) for r in cl_runs)) for L in range(1, 113)}
    print("EXPECTED Champion Level by frontier (granted on update day): " + ", ".join(
        "L%d %d" % (L, cl_table[L]) for L in (24, 32, 40, 48, 56, 80, 112)))
    worst = 0.0
    for L in (24, 40, 56):
        rows = {}
        grants = []
        for lab, mig, grant in (("fresh account", 0, True), ("v2->v3 catch-up only", L, False), ("v2->v3 + lump grant", L, True)):
            boss = collections.defaultdict(list)
            for s in range(seeds):
                x = simulate("casual", 1000 + s, 112, tf=tf, migrate_at=mig, migrate_grant=grant, cl_table=cl_table)
                if mig and grant:
                    grants.append((x[0].cnt["migration_beacons"], x[0].cnt["migration_chests"]))
                for rr in x[3]:
                    l = rr[0]
                    if l > L and rr[7] != "replay":
                        n = l if l <= E.CAMPAIGN_LEVELS else l - E.CAMPAIGN_LEVELS
                        if E.is_boss(n):
                            boss[tf_index(rr[7], E.world_of(n))].append(rr[9])
            rows[lab] = {w: 100 * statistics.mean(v) for w, v in sorted(boss.items())}
        ws = sorted(rows["fresh account"])
        print("  update at L%d (grant: %.0f Beacons, %.0f chests, mean): boss win by world after the update" % (
            L, statistics.mean(g[0] for g in grants), statistics.mean(g[1] for g in grants)))
        print("  | World | " + " | ".join(("W%d" % w) if w <= 7 else ("Inv W%d" % (w - 7)) for w in ws) + " |")
        print("  |---|" + "---|" * len(ws))
        for lab, bw in rows.items():
            print("  | %s | %s |" % (lab, " | ".join("%.0f%%" % bw.get(w, 0) for w in ws)))
        for w in ws[:2]:
            worst = max(worst, rows["fresh account"][w] - rows["v2->v3 + lump grant"][w])
    inv("migration: with the lump grant, boss win in the two worlds after the update within 3 pp of a fresh account",
        worst <= 3.0, "worst deficit %.1f pp" % worst)


def export_consts(path, tf=None):
    """Single source of truth for the design doc tables (heroes_tables.py) and, after APK 2.1, tools/export_econ.gd."""
    d = {
        "ladder": {"Q_NATIVE": Q_NATIVE, "FACET_STEP": FACET_STEP, "NATIVE_MULT": NATIVE_MULT, "RECUT_STEP": RECUT_STEP,
                   "CEILING": CEILING, "FACETS_PER_GEM": F, "SKILL_BASE": SKILL_BASE, "FORM_AT_RANK": FORM_AT_RANK,
                   "AWAKEN_MIN_GEM": "E", "AWAKEN_CAP": {"E": 2, "L": 3, "M": 4}, "BORN_AWAKENED_MIN": G[BORN_AWAKENED_MIN],
                   "ULT_RANK_STEP": ULT_RANK_STEP, "ATK_RANK_STEP": ATK_RANK_STEP, "RALLY_RANK_STEP": RALLY_RANK_STEP,
                   "LV_DMG": LV_DMG, "LV_HP": LV_HP, "LV_RATE": LV_RATE, "LV_ULT": LV_ULT},
        "budgets": {"AWK_STEP": AWK_STEP, "AWK_TOL": AWK_TOL, "FORM_STEP": FORM_STEP, "FORM_TOL": FORM_TOL,
                    "ATK_BEAT": ATK_BEAT, "BEAT_TOL": BEAT_TOL, "RELIC_BEAT": RELIC_BEAT, "RELIC_TOL": RELIC_TOL,
                    "KIT_TOL": KIT_TOL, "CHAMP_KIT_TOL": CHAMP_KIT_TOL, "SET4_VALUE": SET4_VALUE, "U_SHARE": U_SHARE,
                    "HP_W": HP_W, "RALLY_W": RALLY_W, "W_C": W_C, "CHAMP_UPTIME": CHAMP_UPTIME,
                    "ACTION_TIER_STEP": ACTION_TIER_STEP, "CL_STEP": CL_STEP, "C_RELIC": C_RELIC},
        "progress": {"DUP_FRAGS": DUP_FRAGS, "FACET_FRAGS": FACET_FRAGS, "RECUT_FRAGS": RECUT_FRAGS, "RECUT_COINS": RECUT_COINS,
                     "OVERFLOW_FRAGS_PER_TOME": OVERFLOW_FRAGS_PER_TOME, "TOME_COST": TOME_COST, "SKILL_COINS": 0,
                     "HERO_SYNC_BEHIND": HERO_SYNC_BEHIND, "GEAR_SLOT_AT": GEAR_SLOT_AT, "CHAMP_LEVEL_MAX": CHAMP_LEVEL_MAX,
                     "CHAMP_LEVEL_COST": [champ_level_cost(L) for L in range(1, CHAMP_LEVEL_MAX)],
                     "CHRONICLE_PRICES": CHRONICLE_PRICES},
        "portal": {"BASE_ODDS": PORTAL_BASE, "PITY_E": {"hard": PITY_E_HARD},
                   "PITY_L": {"soft_from": PITY_L_SOFT, "step": PITY_L_STEP, "hard": PITY_L_HARD},
                   "OPAL_SHARE_IN_L": OPAL_SHARE_IN_L, "FOCUS_TOTAL": FOCUS_TOTAL, "SEAL_PRICES": SEAL_PRICES,
                   "OWNED_SEAL_PICK_MULT": 2, "WELCOME_X10": {"free": True, "rule": "topaz_plus_in_10"}, "BEACON": BEACON},
        "chests": {"CHEST_ODDS": CHEST_ODDS, "CHEST_PITY_L": CHEST_PITY_L, "CHEST_CHARGE_PER_WIN": CHEST_CHARGE_PER_WIN,
                   "CHEST_REPLAYS_PER_DAY": CHEST_REPLAYS_PER_DAY, "CHEST_TOMES": CHEST_TOMES, "CHEST_HERO_CARD": CHEST_HERO_CARD,
                   "CHEST_CARDS": CHEST_CARDS, "CHEST_HERO_FRAG_MULT": CHEST_HERO_FRAG_MULT, "CHEST_FOCUS_TOTAL": FOCUS_TOTAL,
                   "TOMES_BOSS": TOMES_BOSS, "TOMES_WEEKLY": TOMES_WEEKLY, "TOMES_EXP5": TOMES_EXP5},
        "team": {"FACTION_TIERS": FACTION_TIERS, "AFFINITY_PER": AFFINITY_PER, "AFFINITY_CAP": AFFINITY_CAP,
                 "TEAM_B2_CAP": TEAM_B2_CAP, "AURA_CAP": 0.40, "CLASS_PAIR": CLASS_PAIR},
        "gear": {"ITEM_STAT": ITEM_STAT, "HERO_RELIC_STAT": HERO_RELIC_STAT, "SET2": SET2, "CRAFT_ORE": {k: v[1] for k, v in CRAFT.items()},
                 "TEMPER_ORE": "8 + 4 r (champion relic: ceil(half))", "TEMPER_MAX": TEMPER_MAX, "TIER_AT": TIER_AT,
                 "TEMPER_CAP_PER_WORLD": 2, "TROPHIES": TROPHIES, "TROPHY_RANK": TROPHY_RANK, "MAT_BOSS": MAT_BOSS,
                 "MAT_PER_WIN": {"campaign": [mat_per_win(w, "campaign") for w in range(1, 8)],
                                 "invasion": [mat_per_win(w, "invasion") for w in range(1, 8)], "replay_share": REPLAY_MAT_SHARE}},
        "ceremony": CER, "feats": {k: {"counter": v[0], "tiers": v[1], "reward": v[2]} for k, v in HERO_FEATS.items()},
        "unlocks": UNLOCK_AT, "team_demand": tf or {}}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(d, fh, indent=1, ensure_ascii=False, default=str)
    print("constants exported to %s" % os.path.basename(path))


# =============================================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--section", default="all")
    ap.add_argument("--seeds", type=int, default=0)
    ap.add_argument("--export", metavar="PATH", default="")
    args = ap.parse_args()
    q = args.quick
    seeds = args.seeds or (24 if q else 80)
    print("Crystal Rush — heroes & champions sim | campaign seeds %d | %s" % (seeds, "quick" if q else "full"))
    sec = args.section
    if sec in ("all", "ladder"):
        section_ladder()
        section_sinks()
    if sec in ("all", "portal"):
        section_portal(200_000 if q else 1_000_000)
    if sec in ("all", "chest"):
        section_chest(100_000 if q else 300_000)
    tf = None
    if sec in ("all", "campaign"):
        tf = section_campaign(seeds, max(16, seeds // 2))
    if sec in ("all", "migration"):
        if tf is None:
            tf, _ = calibrate_tf(16 if q else 30, 112)
        section_migration(12 if q else 24, tf)
    if sec in ("all", "meta1"):
        section_meta1(20 if q else 60)
    if sec in ("all", "long"):
        if tf is None:
            tf, _ = calibrate_tf(16 if q else 30, 112)
            print("TEAM_DEMAND (recalibrated for this section):", tf)
        # 90 seeds (was 30): the p50 day of "all 10 heroes" spreads from day ~9 (p10) to ~77 (p90), so a 30-seed median
        # moved by 7-20 days with the RNG stream alone (a roster addition reshuffles it) and crossed the day-25 bound
        section_long(10 if q else 90, tf)
    if args.export:
        export_consts(args.export, tf)
    print("\n%d invariant(s) failed: %s" % (len(FAILS), FAILS) if FAILS else "\nall invariants pass")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
