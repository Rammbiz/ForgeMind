#!/usr/bin/env python3
"""Crystal Rush meta economy sim, v2 (arsenal_design.md sections 3, 5, 6).

What it checks (every number quoted in the design doc comes from this output):
  1. Totals of every sink (Arsenal, heroes, Barracks, Tactics, Haven, assets).
  2. Cache (pack) odds: exact best-card tables per pool state + pity-stream Monte Carlo.
  3. In-run arsenal budget: crate picker + RANK gates + EVOLVE/FUSE gates per level band.
  4. Campaign pacing for 5 archetypes x 3 spending policies, walls (attempts, loss streaks, boss win rates).
  5. Long horizon (200 levels: campaign 56 + Invasion): first Ascension / Talent III / Apex / Lv15.
  6. Ceremony seconds per session, ad-watcher and payer deltas.
  7. Invariants: prints PASS/FAIL for each and exits 1 if any fails (tools/check_all.sh runs it).

Run:  python3 economy_sim.py              (full, ~3-5 min)
      python3 economy_sim.py --quick      (fewer seeds, for tuning)
All tunables live in CONFIG. EconData/ArsenalData in the game must hold the same numbers
(tools/export_econ.gd writes build/econ.json; the shipped port of this sim loads it).
"""
from __future__ import annotations

import argparse
import collections
import math
import random
import statistics
import sys
from dataclasses import dataclass, field

# =============================================================================================
# CONFIG
# =============================================================================================
LEVELS_PER_WORLD = 8
CAMPAIGN_LEVELS = 56                     # 7 worlds x 8; levels after this are Invasion chapters
RARITIES = ["C", "R", "E", "L", "M"]
RAR_IDX = {r: i for i, r in enumerate(RARITIES)}

# id, rarity, home world (0 = Mythic, forged at the Rift Anvil), family
MACHINES = [
    ("drone", "C", 1, "tech"), ("ballista", "C", 1, "kinetic"), ("cannon", "C", 1, "plasma"),
    ("rockets", "C", 1, "tech"), ("mortar", "R", 1, "kinetic"),
    ("gatling", "C", 2, "kinetic"), ("laser", "R", 2, "plasma"), ("railgun", "E", 2, "volt"),
    ("tesla", "R", 3, "volt"), ("banner", "R", 3, "rune"), ("prism", "L", 3, "plasma"),
    ("cryo", "C", 4, "frost"), ("frost_miner", "R", 4, "frost"), ("ram", "E", 4, "kinetic"),
    ("harvester", "R", 5, "rune"), ("arc_fence", "E", 5, "volt"), ("aegis", "E", 5, "frost"),
    ("sentinel", "E", 6, "tech"), ("gravity", "L", 6, "rune"), ("tuner", "L", 6, "volt"),
    ("starfall", "M", 0, "rift"), ("chrono", "M", 0, "rift"), ("phoenix", "M", 0, "rift"), ("echo", "M", 0, "rift"),
]
MDEF = {m: (r, w, f) for m, r, w, f in MACHINES}
MYTHIC_ORDER = ["starfall", "chrono", "phoenix", "echo"]
# gold NEW crate: world -> {level in world: machine}
NEW_CRATE_LEVELS = {1: {2: "ballista", 3: "cannon", 5: "rockets", 6: "mortar"}}
for _w in range(2, 7):
    _trio = [m for m, (r, w, f) in MDEF.items() if w == _w]
    NEW_CRATE_LEVELS[_w] = {1: _trio[0], 3: _trio[1], 5: _trio[2]}
START_OWNED = ["drone"]

START_LEVEL = {"C": 1, "R": 2, "E": 3, "L": 4, "M": 5}
SYNC_CAP = 7                              # Arsenal Sync never skips the Ascension beat
MAX_LEVEL = 15
TALENT_LEVELS = (3, 6, 10)
LEAD_LEVEL = 5
ASCENSION_LEVEL = 8
APEX_LEVEL = 12
# coins to reach level L, identical for every rarity
COIN_TO = {2: 40, 3: 80, 4: 150, 5: 250, 6: 380, 7: 540, 8: 740, 9: 980, 10: 1260,
           11: 1580, 12: 1950, 13: 3600, 14: 5200, 15: 7500}
# blueprints to reach level L per rarity (a Legendary levels about as fast as a Common)
BP_TO = {
    "C": dict(zip(range(2, 16), [0, 3, 4, 5, 6, 8, 10, 12, 15, 18, 22, 40, 55, 75])),   # Lv2 coin-only (first Arsenal visit, blueprints hidden until L6)
    "R": dict(zip(range(3, 16), [1, 2, 2, 3, 3, 4, 5, 6, 7, 9, 16, 22, 30])),
    "E": dict(zip(range(4, 16), [1, 1, 1, 1, 2, 2, 2, 3, 3, 6, 8, 10])),
    "L": dict(zip(range(5, 16), [1, 1, 1, 1, 1, 1, 1, 2, 3, 4, 5])),
    "M": dict(zip(range(6, 16), [1, 1, 1, 1, 1, 1, 1, 3, 4, 5])),
}
MACHINE_DMG_PER_LVL = 0.08                # +8% per level, linear (Lv15 = x2.12)

# Hero: levels 1..30, coins = round(HERO_K * L^HERO_EXP, 10); cap = 6 + 3 x world reached (30 in Invasion)
HERO_K, HERO_EXP, HERO_MAX = 30, 1.40, 30
HERO_DMG_PER_LVL = 0.035
GLORY_AT_BOSS_WINS = [1, 3, 5, 7]         # Glory ranks 2..5 = world bosses beaten with that hero
# Barracks: 5 tracks x 10 levels, cost = round(BAR_K * L^BAR_EXP, 5); cap = 2 + 2 x world reached
BAR_TRACKS = {"recruits": 0.015, "reserves": 0.010, "scrape_guard": 0.010, "drill": 0.012, "volleys": 0.012}
BAR_K, BAR_EXP, BAR_MAX = 70, 1.55, 10
# Tactics row (ex-Workshop): 6 nodes x 3 ranks, independent prices, every rank a visible >= 3% effect
TACTICS = {"crate_craft": 0.008, "weak_point": 0.008, "streak": 0.006, "lead_engineer": 0.008,
           "war_chest": 0.0, "ult_primer": 0.006}
TACTICS_PRICE = [600, 1400, 2800]
TACTICS_MAX = 3
WAR_CHEST_COINS = 0.05                    # +5% victory coins per rank
# Haven (world rebuild): crowns per stage; each stage = +1 Citadel and 1 pick of 4 featured items
HAVEN_STAGE_COST = [2, 3, 4, 4, 5]
HAVEN_BP_BUNDLE = 8                       # featured blueprint bundle size (2 of the 4 featured items)

# power = 0.50 machines + 0.25 hero + 0.25 army  (x tactics); machines carry >= 50% of growth
W_MACH, W_HERO, W_ARMY = 0.50, 0.25, 0.25
ASC_POWER, APEX_POWER, TALENT_POWER, RARITY_EDGE = 0.12, 0.06, 0.05, 0.03
GLORY_POWER = 0.015                       # each Glory rank = +1 starting soldier (~1.5% army power)

# Difficulty curve the level designer targets (base army fixed, never scaled by account)
DEMAND_GROWTH = 0.0165
BOSS_DEMAND = [1.00, 1.00, 1.04, 1.05, 1.05, 1.06, 1.07]   # per world (W1-2 bosses teach); Invasion bosses reuse it
def demand(level: int) -> float:
    n = level if level <= CAMPAIGN_LEVELS else level - CAMPAIGN_LEVELS
    boss = BOSS_DEMAND[world_of(n) - 1] if (n - 1) % LEVELS_PER_WORLD == LEVELS_PER_WORLD - 1 else 1.0
    return (1.0 + DEMAND_GROWTH * (level - 1)) * boss

FORCED_WIN_LEVELS = 3                     # tutorial: the L1-3 fortress always falls
RETRY_ASSIST_STEP, RETRY_ASSIST_CAP = 0.05, 0.25   # Reinforcements per loss on the same level

# Income
def victory_coins(level: int, survivors: int) -> int:
    return 20 + 6 * level + min(survivors // 3, 25)

def pickup_coins(level: int) -> float:
    return 8 + 0.7 * level

LOSS_VICTORY_SHARE = 0.25                 # loss pays 25% of victory coins x bridge fraction + 70% pickups
LOSS_PICKUP_SHARE = 0.70
LOSS_CACHE_CHARGE = 1.0 / 3.0             # 3 losses = 1 Stone Cache
REPLAY_SHARE = 0.60                       # replay of a cleared level: 60% coins, no crowns
REPLAY_CACHES_PER_DAY = 3                 # ... and a Stone Cache only on the first 3 replay wins of a day
STARTER_COINS, STARTER_BP = 2000, 6

ARCHETYPES = {
    #               lv/day lv/sess skill  stairs crowns dailies ads/day
    "casual":   dict(lpd=4,  lps=2,  skill=0.35, stairs=1.7, crowns=1.7, dailies=2, ads=0),
    "regular":  dict(lpd=8,  lps=4,  skill=0.60, stairs=2.4, crowns=2.2, dailies=3, ads=0),
    "hardcore": dict(lpd=20, lps=10, skill=0.85, stairs=3.2, crowns=2.7, dailies=3, ads=0),
    "weak":     dict(lpd=3,  lps=2,  skill=0.20, stairs=1.4, crowns=1.3, dailies=1, ads=0),
    "ad_watcher": dict(lpd=4, lps=2, skill=0.35, stairs=1.7, crowns=1.7, dailies=2, ads=3),
}
AD_CAP_PER_DAY = 3
AD_FREE_LEVELS = 10                       # no x2 button on L1-10

LOGIN_CYCLE = [("coins", 150), ("bp_rare", 2), ("coins", 250), ("cache", "stone"), ("gems", 20),
               ("coins", 400), ("cache", "royal")]
DAILY_MISSION_COINS = lambda frontier: 60 + 4 * frontier
DAILY_MISSION_GEMS = 5
WEEKLY_BONUS = dict(cache="world", coins=1500, gems=50)

# ---- Caches (packs). One table for roller, (i) screen, and this sim ----------------------
CARD_ODDS = {"C": 68.0, "R": 24.0, "E": 6.5, "L": 1.4, "M": 0.1}
STACK = {"C": (2, 4), "R": (1, 2), "E": (1, 1), "L": (1, 1), "M": (1, 1)}
CACHES = {
    # blueprint slots, guaranteed min rarity of the LAST slot (re-rolled from eligible rarities),
    # coin bonus slot (base, per frontier level), Legendary weight multiplier on every slot
    "stone": dict(slots=3, guaranteed="R", coins=(30, 3), leg_weight=1.0),
    "world": dict(slots=5, guaranteed="E", coins=(120, 8), leg_weight=1.0),
    "royal": dict(slots=8, guaranteed="E", coins=(300, 12), leg_weight=4.0),
}
WILD_CARD_CHANCE = 0.005                  # a blueprint slot becomes a Wild Blueprint of the same rarity
MYTHIC_CARDS_IN = ("world", "royal")      # the single Mythic blueprint source among caches
PITY_EPIC = 8                             # the 8th cache in a row without Epic+ guarantees it (counts only while E is in the pool)
PITY_LEG_SOFT, PITY_LEG_HARD = 20, 30     # Legendary on the guaranteed slot: >= 3% x (n - 19) from n = 20; certain at 30
DECK_WEIGHT = 1.5                         # disclosed: machines in your Deck are 1.5x as likely within a rarity
FOCUS_SHARE = 0.40                        # disclosed: 40% of cards of the Focus machine's rarity go to it

# Run drip: each fielded machine in a WON run fills its blueprint bar (x1.5 if it reached Rank III)
DRIP = {"C": 1.0, "R": 0.5, "E": 0.25, "L": 0.12, "M": 0.06}

ARSENAL_RATING_STEP = 10                  # rating (no damage!) -> one Arsenal Track node per 10
TRACK_CACHE_EVERY = 3

# ---- In-run arsenal budget (crate picker, RANK gates, EVOLVE/FUSE gates) --------------------
def crate_events(level: int, boss: bool) -> int:
    n = 2 if level <= 30 else 4               # L1 has none (tutorial); L2 = scripted NEW crate + 1
    return n + (1 if boss else 0)

def rank_gates(level: int) -> int:
    return 0 if level <= 10 else 1

PAIR_FROM = 5                             # from L5 every crate is a pair: open one, the other folds
MAX_FIELDED = 3
DUP_SHARE_AT_2 = 0.5                      # once 2 are fielded, 50% of crates are duplicates of a fielded machine
RARITY_PICK_W = {"C": 1.0, "R": 0.8, "E": 0.6, "L": 0.45, "M": 0.35}
RECIPE_WEIGHT = 3.0                       # a duplicate one step from a recipe is x2 as likely
BONUS_HIT_P = {"casual": 0.35, "regular": 0.55, "hardcore": 0.75, "weak": 0.25, "ad_watcher": 0.35}
TAKE_RANK_GATE_P = 0.65                   # rank gate competes with an army gate in its row
TAKE_EVOLVE_P = 0.85
POWER_GATE_CATALYST_P = 0.90              # catalyst gate (resolved at spawn to the recipe op, shows the recipe icon) taken
EVOLUTIONS = {  # machine: ("partner", id) | ("gate", op)
    "ballista": ("gate", "multi"), "gatling": ("gate", "rate"), "rockets": ("gate", "dmg"),
    "ram": ("partner", "mortar"), "tesla": ("partner", "arc_fence"), "laser": ("partner", "prism"),
    "drone": ("partner", "sentinel"), "cryo": ("partner", "frost_miner"), "harvester": ("partner", "drone"),
    "railgun": ("partner", "arc_fence"), "starfall": ("gate", "dmg"), "echo": ("partner", "tuner"),
}
FUSIONS = [("tesla", "cryo"), ("cannon", "mortar"), ("laser", "railgun"), ("gatling", "rockets"),
           ("gravity", "cannon"), ("banner", "sentinel"), ("arc_fence", "aegis"), ("tuner", "harvester")]

# ---- Ceremony budget (seconds; everything skippable after first view) ------------------------
CEREMONY = {"micro": 0.35, "standard": 1.2, "full": 3.0, "result_min": 2.5, "cache_inline": 2.0,
            "cache_altar": 5.0}
LEVEL_SECONDS = 45.0

# ---- Asset manifest (counts printed; Meshy generations = assets x attempts) -------------------
ASSET_MANIFEST = {
    "P0": {"family chassis (Kinetic, Plasma, Tech, Volt)": 4, "machines W1-W2 + Prism": 9,
           "moving parts W1-W2 (gatling drum, mortar tube, laser lens, prism ring)": 4,
           "caches + altar + pedestal": 5, "currency props (coin, gem, blueprint, crown)": 4,
           "crate NEW (platinum)": 1, "crew operator": 1},
    "P1": {"family chassis (Frost, Rune)": 2, "machines W3-W6": 11,
           "moving parts W3-W6 (frost-miner drum, tuner dish, gravity core)": 3,
           "Ascension branches E/L": 16, "Fusion double-wide chassis": 1, "Haven dioramas (stage 1 + 5)": 14,
           "soldier tiers T3-T5": 3, "raider variants (Flying, Armored)": 2},
    "P2": {"Rift chassis": 1, "Mythic modules": 4, "moving part (chrono bell)": 1, "Mythic branches": 8,
           "Boss Core + Rift Anvil": 2, "X-Ray Cache": 1, "Citadel stage 1 + 5": 2, "hero Seer": 1},
}
MESHY_ATTEMPTS = 3

# =============================================================================================
# MODEL
# =============================================================================================
def hero_cost(lvl: int) -> int:
    return int(round(HERO_K * lvl ** HERO_EXP / 10.0)) * 10

def bar_cost(lvl: int) -> int:
    return int(round(BAR_K * lvl ** BAR_EXP / 5.0)) * 5

def world_of(level: int) -> int:
    return min(7, (level - 1) // LEVELS_PER_WORLD + 1)

def is_boss(level: int) -> bool:
    return (level - 1) % LEVELS_PER_WORLD == LEVELS_PER_WORLD - 1


@dataclass
class Player:
    kind: str
    rng: random.Random
    policy: str = "greedy"
    coins: int = 0
    gems: int = 0
    crowns: int = 0
    cores: int = 0
    hero_lvl: int = 1
    glory: int = 1
    boss_wins: int = 0
    barracks: dict = field(default_factory=lambda: {t: 0 for t in BAR_TRACKS})
    tactics: dict = field(default_factory=lambda: {t: 0 for t in TACTICS})
    citadel: int = 0
    haven: dict = field(default_factory=dict)
    machines: dict = field(default_factory=dict)
    wild: dict = field(default_factory=lambda: {r: 0 for r in RARITIES})
    world_reached: int = 1
    since_epic: int = 0
    since_leg: int = 0
    leg_welcome_done: bool = False
    track_nodes: int = 0
    mythics_forged: int = 0
    log_buys: list = field(default_factory=list)
    spent: dict = field(default_factory=lambda: {"machines": 0, "hero": 0, "barracks": 0, "tactics": 0})
    earned_coins: int = 0
    src: dict = field(default_factory=dict)
    caches_opened: int = 0
    cache_charge: float = 0.0
    ceremony_s: float = 0.0
    firsts: dict = field(default_factory=dict)   # machine level reached -> attempt index
    frontier: int = 1
    attempt: int = 0

    def earn(self, n: int, source: str) -> None:
        self.coins += n
        self.earned_coins += n
        self.src[source] = self.src.get(source, 0) + n

    # ---- power --------------------------------------------------------------------------------
    @staticmethod
    def mpow(mid: str, lvl: int) -> float:
        p = 1.0 + MACHINE_DMG_PER_LVL * (lvl - 1)
        p *= 1.0 + TALENT_POWER * sum(1 for t in TALENT_LEVELS if lvl >= t)
        if lvl >= ASCENSION_LEVEL:
            p *= 1.0 + ASC_POWER
        if lvl >= APEX_LEVEL:
            p *= 1.0 + APEX_POWER
        return p * (1.0 + RARITY_EDGE * RAR_IDX[MDEF[mid][0]])

    def deck_size(self) -> int:
        return min(6, 3 + max(0, self.world_reached - 2))      # 3 (W1-2), 4 (W3), 5 (W4), 6 (W5+)

    def deck(self) -> list:
        return sorted(self.machines, key=lambda k: -self.mpow(k, self.machines[k]["lvl"]))[:self.deck_size()]

    def parts(self) -> tuple:
        deck = self.deck()
        vals = [self.mpow(k, self.machines[k]["lvl"]) for k in deck]
        top = vals[:3]
        mach = sum(top) / len(top) if top else 1.0      # normalised by slots owned (empty slots are not 0)
        if len(vals) > 3:                               # crate draws are weighted by level, so the top 3 dominate
            mach = 0.8 * mach + 0.2 * (sum(vals[3:]) / len(vals[3:]))
        lead = 1.0 + 0.04 * self.tactics["lead_engineer"] / 3.0
        hero = 1.0 + HERO_DMG_PER_LVL * (self.hero_lvl - 1)
        army = 1.0 + sum(BAR_TRACKS[t] * l for t, l in self.barracks.items()) + GLORY_POWER * (self.glory - 1)
        tac = 1.0 + sum(TACTICS[t] * r for t, r in self.tactics.items())
        return mach * lead, hero, army, tac

    def power(self) -> float:
        m, h, a, t = self.parts()
        return (W_MACH * m + W_HERO * h + W_ARMY * a) * t

    def rating(self) -> int:
        return sum(m["lvl"] for m in self.machines.values()) + 5 * sum(
            1 for m in self.machines.values() if m["lvl"] >= ASCENSION_LEVEL)

    # ---- unlocks ------------------------------------------------------------------------------
    def unlock(self, mid: str) -> None:
        if mid in self.machines:
            return
        r = MDEF[mid][0]
        levels = sorted((m["lvl"] for m in self.machines.values()), reverse=True)
        sync = levels[2] - 2 if len(levels) >= 3 else 1
        self.machines[mid] = {"lvl": max(START_LEVEL[r], min(sync, SYNC_CAP)), "bp": 0, "frac": 0.0}

    def pool(self) -> list:
        return [m for m, (r, w, f) in MDEF.items() if r != "M" and 1 <= w <= self.world_reached] + \
               [m for m in self.machines if MDEF[m][0] == "M"]

    # ---- caches -------------------------------------------------------------------------------
    def open_cache(self, kind: str, inline: bool = True) -> None:
        pool = self.pool()
        present = {MDEF[m][0] for m in pool}
        rolled = roll_cache(kind, present, self, self.rng)
        for r, wild in rolled:
            self._grant_card(r, pool, wild)
        g = CACHES[kind]
        self.earn(g["coins"][0] + g["coins"][1] * self.frontier, "caches")
        self.caches_opened += 1
        self.ceremony_s += CEREMONY["cache_inline"] if kind == "stone" else CEREMONY["cache_altar"]

    def _grant_card(self, r: str, pool: list, wild: bool) -> None:
        if wild:
            self.wild[r] += 1
            return
        cands = [m for m in pool if MDEF[m][0] == r]
        if not cands:
            return
        unowned = [m for m in cands if m not in self.machines]
        if r in ("L", "M") and unowned:
            mid = self.rng.choice(unowned)               # duplicate protection for the top tiers
        else:
            deck = self.deck()
            focus = deck[0] if deck else None
            if focus in cands and self.rng.random() < FOCUS_SHARE:
                mid = focus
            else:
                weights = [DECK_WEIGHT if m in deck else 1.0 for m in cands]
                mid = self.rng.choices(cands, weights)[0]
        n = self.rng.randint(*STACK[r])
        if mid not in self.machines:
            self.unlock(mid)
            n -= 1
        m = self.machines[mid]
        if m["lvl"] >= MAX_LEVEL:
            self.wild[r] += max(0, n)                    # maxed machine: blueprints become Wild 1:1
        else:
            m["bp"] += max(0, n)

    # ---- spending -----------------------------------------------------------------------------
    def mythic_bp(self) -> None:
        """Expedition 5/5: 1 blueprint for the lowest forged Mythic, else a stored Wild Mythic."""
        ms = [m for m in self.machines if MDEF[m][0] == "M" and self.machines[m]["lvl"] < MAX_LEVEL]
        if ms:
            self.machines[min(ms, key=lambda k: self.machines[k]["lvl"])]["bp"] += 1
        else:
            self.wild["M"] += 1

    def bp_need(self, mid: str, nl: int) -> int:
        return BP_TO[MDEF[mid][0]].get(nl, 0)

    def options(self):
        opts = []
        for mid, m in self.machines.items():
            nl = m["lvl"] + 1
            if nl > MAX_LEVEL:
                continue
            need = self.bp_need(mid, nl)
            if m["bp"] + self.wild[MDEF[mid][0]] >= need:
                opts.append(("machine", mid, COIN_TO[nl]))
        if self.unlocked("hero") and self.hero_lvl < self.hero_cap():
            opts.append(("hero", None, hero_cost(self.hero_lvl)))
        if self.unlocked("barracks"):
            cap = min(BAR_MAX, 2 + 2 * self.world_reached)
            for t, l in self.barracks.items():
                if l < cap:
                    opts.append(("barracks", t, bar_cost(l + 1)))
        if self.unlocked("tactics"):
            for t, r in self.tactics.items():
                if r < TACTICS_MAX:
                    opts.append(("tactics", t, TACTICS_PRICE[r]))
        return opts

    def hero_cap(self) -> int:
        return HERO_MAX if self.frontier > CAMPAIGN_LEVELS else min(HERO_MAX, 6 + 3 * self.world_reached)

    def unlocked(self, system: str) -> bool:
        # UnlockQueue (design 4.6): Arsenal after L3, hero levels with Titan at L4, Barracks at L12, Tactics at L26
        # Tactics at W4.
        f = self.frontier
        return {"arsenal": f > 3, "hero": f > 4, "barracks": f > 12, "tactics": f > 25}[system]

    def free_spend(self, li: int) -> int:
        bought = 0
        for w in range(1, self.world_reached + 1):
            s = self.haven.get(w, 0)
            while s < 5 and self.frontier > 16 and self.crowns >= HAVEN_STAGE_COST[s]:
                self.crowns -= HAVEN_STAGE_COST[s]
                s += 1
                self.haven[w] = s
                self.citadel += 1
                if s <= 2:                               # stages 1-2: the player picks a featured blueprint bundle
                    trio = [m for m, (r, ww, f) in MDEF.items() if ww == w and m in self.machines]
                    if trio:
                        self.machines[self.rng.choice(trio)]["bp"] += max(1, HAVEN_BP_BUNDLE // (1 + RAR_IDX[MDEF[trio[0]][0]]))
                self.log_buys.append((li, "haven"))
                bought += 1
        while self.cores >= 3 and self.mythics_forged < 4:
            self.cores -= 3
            self.unlock(MYTHIC_ORDER[self.mythics_forged])
            self.mythics_forged += 1
            self.log_buys.append((li, "mythic"))
        while self.mythics_forged >= 4 and self.cores >= 1:   # Boss Core overflow = 1 Mythic blueprint
            self.cores -= 1
            self.mythic_bp()
        return bought

    def spend(self, li: int) -> int:
        bought = self.free_spend(li)
        if not self.unlocked("arsenal"):
            return bought
        while True:
            opts = [o for o in self.options() if o[2] <= self.coins]
            if self.policy != "greedy":
                # green arrows are drawn only on Deck machines (and the Best-upgrade row), design 7.3
                deck = set(self.deck())
                opts = [o for o in opts if o[0] != "machine" or o[1] in deck]
            if self.policy == "machines_only":
                opts = [o for o in opts if o[0] == "machine"]
            if not opts:
                return bought
            if self.policy == "greedy":                  # the "Best upgrade" button
                base = self.power()
                best, best_v = None, -1.0
                for o in opts:
                    v = (1.3 if o[0] == "machine" else 1.0) * max(self._gain(o) - base, 1e-6) / o[2]
                    if v > best_v:
                        best, best_v = o, v
            else:                                        # spread / machines_only: cheapest green arrow first
                best = min(opts, key=lambda o: o[2])
            self._apply(best, li)
            bought += 1

    def _gain(self, o) -> float:
        kind, key, _ = o
        if kind == "machine":
            self.machines[key]["lvl"] += 1; p = self.power(); self.machines[key]["lvl"] -= 1
        elif kind == "hero":
            self.hero_lvl += 1; p = self.power(); self.hero_lvl -= 1
        elif kind == "barracks":
            self.barracks[key] += 1; p = self.power(); self.barracks[key] -= 1
        else:
            self.tactics[key] += 1; p = self.power(); self.tactics[key] -= 1
        return p

    def _apply(self, o, li: int) -> None:
        kind, key, cost = o
        self.coins -= cost
        if kind == "machine":
            m = self.machines[key]
            need = self.bp_need(key, m["lvl"] + 1)
            r = MDEF[key][0]
            use = min(m["bp"], need)
            m["bp"] -= use
            self.wild[r] -= need - use
            m["lvl"] += 1
            self.spent["machines"] += cost
            self.firsts.setdefault(m["lvl"], (self.attempt, self.frontier))
            beat = m["lvl"] in TALENT_LEVELS or m["lvl"] in (LEAD_LEVEL, ASCENSION_LEVEL, APEX_LEVEL, MAX_LEVEL)
            self.ceremony_s += CEREMONY["full" if beat else "standard"]
        elif kind == "hero":
            self.hero_lvl += 1
            self.spent["hero"] += cost
            self.ceremony_s += CEREMONY["standard"]
        elif kind == "barracks":
            self.barracks[key] += 1
            self.spent["barracks"] += cost
            self.ceremony_s += CEREMONY["micro"]
        else:
            self.tactics[key] += 1
            self.spent["tactics"] += cost
            self.ceremony_s += CEREMONY["micro"]
        self.log_buys.append((li, kind))


# ---- the cache roller (GeodeRoller in the game is a line-by-line port) ----------------------
def slot_weights(present: set, leg_weight: float, min_r: str | None, allow_m: bool) -> dict:
    w = {}
    for r in RARITIES:
        if r not in present or (r == "M" and not allow_m):
            continue
        if min_r is not None and RAR_IDX[r] < RAR_IDX[min_r]:
            continue
        w[r] = CARD_ODDS[r] * (leg_weight if r == "L" else 1.0)
    return w


def guaranteed_min(kind: str, present: set) -> str:
    """Best rarity the pool allows, capped at the cache's guarantee."""
    want = CACHES[kind]["guaranteed"]
    best_present = max((r for r in present if r != "M"), key=lambda r: RAR_IDX[r])
    return want if RAR_IDX[want] <= RAR_IDX[best_present] else best_present


def roll_cache(kind: str, present: set, pity, rng: random.Random) -> list:
    """Returns [(rarity, is_wild)]. `pity` has since_epic, since_leg, leg_welcome_done (mutated)."""
    g = CACHES[kind]
    allow_m = kind in MYTHIC_CARDS_IN
    e_in, l_in = "E" in present, "L" in present
    cards = []
    for i in range(g["slots"] - 1):
        w = slot_weights(present, g["leg_weight"], None, allow_m)
        cards.append(_draw(w, rng))
    # guaranteed (last) slot
    gmin = guaranteed_min(kind, present)
    if e_in and pity.since_epic + 1 >= PITY_EPIC and RAR_IDX[gmin] < RAR_IDX["E"]:
        gmin = "E"
    w = slot_weights(present, g["leg_weight"], gmin, allow_m)
    if l_in:
        n = pity.since_leg + 1
        if (not pity.leg_welcome_done) or n >= PITY_LEG_HARD:
            w = {"L": 1.0}
        elif n >= PITY_LEG_SOFT:
            target = min(1.0, 0.03 * (n - PITY_LEG_SOFT + 1))
            tot = sum(w.values())
            if w.get("L", 0.0) / tot < target:
                rest = tot - w["L"]
                w = {r: (v / rest) * (1 - target) if r != "L" else target for r, v in w.items()}
    cards.append(_draw(w, rng))
    best = max(cards, key=lambda r: RAR_IDX[r])
    if e_in:
        pity.since_epic = 0 if RAR_IDX[best] >= RAR_IDX["E"] else pity.since_epic + 1
    if l_in:
        pity.since_leg = 0 if RAR_IDX[best] >= RAR_IDX["L"] else pity.since_leg + 1
        pity.leg_welcome_done = True
    return [(r, rng.random() < WILD_CARD_CHANCE) for r in cards]


def _draw(w: dict, rng: random.Random) -> str:
    tot = sum(w.values())
    x = rng.random() * tot
    for r, v in w.items():
        x -= v
        if x <= 0:
            return r
    return list(w)[-1]


def exact_best_table(kind: str, present: set) -> dict:
    """Exact best-card distribution of one cache, no pity active (what the (i) screen shows)."""
    g = CACHES[kind]
    allow_m = kind in MYTHIC_CARDS_IN
    def cdf(w):
        tot = sum(w.values()); acc = 0.0; out = {}
        for r in RARITIES:
            acc += w.get(r, 0.0) / tot; out[r] = acc
        return out
    free = cdf(slot_weights(present, g["leg_weight"], None, allow_m))
    guar = cdf(slot_weights(present, g["leg_weight"], guaranteed_min(kind, present), allow_m))
    F = {r: free[r] ** (g["slots"] - 1) * guar[r] for r in RARITIES}
    out, prev = {}, 0.0
    for r in RARITIES:
        out[r] = F[r] - prev
        prev = F[r]
    return out


def per_card_table(kind: str, present: set, guaranteed: bool) -> dict:
    g = CACHES[kind]
    allow_m = kind in MYTHIC_CARDS_IN
    w = slot_weights(present, g["leg_weight"], guaranteed_min(kind, present) if guaranteed else None, allow_m)
    tot = sum(w.values())
    return {r: w.get(r, 0.0) / tot for r in RARITIES}


# =============================================================================================
# IN-RUN ARSENAL MONTE CARLO (crate_picker + rank gates + EVOLVE/FUSE gates)
# =============================================================================================
def inrun_level(rng, deck: list, lead: str | None, level: int, kind: str) -> dict:
    boss = is_boss(level)
    fielded = {}                       # id -> rank 1..3
    if lead:
        fielded[lead] = 1
    gates_taken = set()
    for op in ("multi", "rate", "dmg"):
        if rng.random() < POWER_GATE_CATALYST_P:
            gates_taken.add(op)
    evolved = fused = False
    reached3 = False

    def recipe_step(mid):
        # True if one more rank (or this machine fielded) completes an evolution or fusion
        r = fielded.get(mid, 0)
        ev = EVOLUTIONS.get(mid)
        if ev and r == 2:
            return True
        for a, b in FUSIONS:
            if mid in (a, b):
                other = b if mid == a else a
                if fielded.get(other, 0) >= 2 and r == 1:
                    return True
        return False

    def pick_option():
        nf = len(fielded)
        cands_new = [m for m in deck if m not in fielded] if nf < MAX_FIELDED else []
        cands_dup = [m for m in fielded if fielded[m] < 3]
        use_dup = (not cands_new) or (nf >= 2 and rng.random() < DUP_SHARE_AT_2)
        if use_dup and cands_dup:
            w = [RECIPE_WEIGHT if recipe_step(m) else 1.0 for m in cands_dup]
            return rng.choices(cands_dup, w)[0]
        if cands_new:
            # design 3.5: RARITY_PICK_W x LEVEL_W (levels equal in this MC) x 2 if it completes a recipe pair
            def w_new(m):
                pair = any((m == a and b in fielded) or (m == b and a in fielded) for a, b in FUSIONS) or \
                       any(ev[0] == "partner" and ((m == k and ev[1] in fielded) or (m == ev[1] and k in fielded))
                           for k, ev in EVOLUTIONS.items())
                return RARITY_PICK_W[MDEF[m][0]] * (2.0 if pair else 1.0)
            return rng.choices(cands_new, [w_new(m) for m in cands_new])[0]
        if cands_dup:
            return rng.choice(cands_dup)
        return None

    def value(mid):
        if mid is None:
            return -1
        return (3 if recipe_step(mid) else 0) + (2 if fielded.get(mid, 0) == 2 else 0) + (1 if mid in fielded else 0)

    def grant(mid, bonus):
        nonlocal reached3
        if mid is None:
            return
        fielded[mid] = min(3, fielded.get(mid, 0) + 1 + (1 if bonus else 0))
        if fielded[mid] == 3:
            reached3 = True

    def check_evo():
        nonlocal evolved, fused
        if evolved and fused:
            return
        for mid, r in list(fielded.items()):
            ev = EVOLUTIONS.get(mid)
            if not evolved and ev and r >= 3:
                ok = (ev[0] == "partner" and ev[1] in fielded) or (ev[0] == "gate" and ev[1] in gates_taken)
                if ok and rng.random() < TAKE_EVOLVE_P:
                    evolved = True
        if not fused:
            for a, b in FUSIONS:
                if fielded.get(a, 0) >= 2 and fielded.get(b, 0) >= 2 and rng.random() < TAKE_EVOLVE_P:
                    fused = True
                    break

    n_crates = crate_events(level, boss)
    n_rank = rank_gates(level)
    events = ["crate"] * n_crates + ["rank"] * n_rank
    rng.shuffle(events)
    # the first event of a level with a crate is always a crate (LevelGen places crates before rank gates)
    if "crate" in events:
        events.remove("crate"); events.insert(0, "crate")
    skill_pick = {"casual": 0.6, "regular": 0.8, "hardcore": 0.95, "weak": 0.5, "ad_watcher": 0.6}[kind]
    for ev in events:
        if ev == "crate":
            a = pick_option()
            if level >= PAIR_FROM:
                b = pick_option()
                if rng.random() < skill_pick:
                    a = a if value(a) >= value(b) else b
                else:
                    a = rng.choice([a, b])
            grant(a, rng.random() < BONUS_HIT_P[kind])
        else:
            if fielded and rng.random() < TAKE_RANK_GATE_P:
                cands = [m for m in fielded if fielded[m] < 3]
                if cands:
                    grant(max(cands, key=value), False)
        check_evo()
    return dict(r2=any(r >= 2 for r in fielded.values()), r3=reached3, evo=evolved, fus=fused,
                any=evolved or fused)


def inrun_report(seeds: int) -> dict:
    rng = random.Random(77)
    bands = [("L2-10", 2, 10, 1), ("L11-30", 11, 30, 3), ("L31-56", 31, 56, 5)]
    out = {}
    for label, lo, hi, w_hint in bands:
        acc = collections.defaultdict(int)
        n = 0
        for kind in ("casual", "regular", "hardcore"):
            for s in range(seeds):
                level = rng.randint(lo, hi)
                world = world_of(level)
                owned = [m for m, (r, w, f) in MDEF.items() if 1 <= w <= world]
                if world >= 4:
                    owned += MYTHIC_ORDER[:min(4, (world - 3))]
                size = min(6, 3 + max(0, world - 2))
                deck = rng.sample(owned, min(size, len(owned)))
                # Auto-deck / deck editor shows recipes: 70% of decks hold a recipe pair
                if rng.random() < 0.7:
                    pairs = [p for p in FUSIONS if p[0] in owned and p[1] in owned] + \
                            [(m, ev[1]) for m, ev in EVOLUTIONS.items() if ev[0] == "partner" and m in owned and ev[1] in owned]
                    if pairs:
                        a, b = rng.choice(pairs)
                        for x in (a, b):
                            if x not in deck:
                                deck[-1 if deck[-1] not in (a, b) else 0] = x
                lead = deck[0] if level >= 9 else None   # Lead perk needs Lv5 (sim: around L9)
                res = inrun_level(rng, deck, lead, level, kind)
                for k, v in res.items():
                    acc[k] += v
                n += 1
        out[label] = {k: acc[k] / n for k in ("r2", "r3", "evo", "fus", "any")}
    return out


# =============================================================================================
# CAMPAIGN SIMULATION
# =============================================================================================
def stage_of(i: int) -> tuple:
    """Frontier index -> (mode, level used for difficulty and pay, is_boss, world).
    1..56 campaign; 57..112 Invasion (night versions of worlds 1-7 in order; difficulty keeps climbing
    as level 56 + n, pay as level 56 + n/2); 113+ replay of cleared content (60% coins, Stone Cache only
    on the first 3 wins of a day)."""
    if i <= CAMPAIGN_LEVELS:
        return "campaign", i, is_boss(i), world_of(i), i
    if i <= 2 * CAMPAIGN_LEVELS:
        n = i - CAMPAIGN_LEVELS
        return "invasion", i, is_boss(n), world_of(n), CAMPAIGN_LEVELS + n // 2
    return "replay", 2 * CAMPAIGN_LEVELS, False, 7, CAMPAIGN_LEVELS


def simulate(kind: str, seed: int, levels: int = 60, policy: str = "greedy", payer: str | None = None,
             days: int | None = None):
    a = ARCHETYPES[kind]
    p = Player(kind, random.Random(seed), policy=policy)
    for m in START_OWNED:
        p.unlock(m)
    if payer == "starter":
        p.coins += STARTER_COINS                 # Starter Arsenal: coins + blueprints for OWNED W1 machines + cosmetic
        p.machines["drone"]["bp"] += STARTER_BP
    rng = p.rng
    day, level_today, session_levels, login_idx, ads_today, replay_caches = 0, 0, 0, 0, 0, 0
    sessions, sess_cer = [], []
    cur_buys, cur_cer0 = 0, 0.0
    level = 1
    checkpoints, rlog = {}, []
    best_crowns = {}
    last_track_rating = -1
    losses_here = 0
    new_day = True
    max_attempts = (levels if days is None else 10 ** 6) * 8
    while (level <= levels if days is None else day < days) and p.attempt < max_attempts:
        mode, dl, boss, world, pay = stage_of(level)
        if new_day:
            k_, val = LOGIN_CYCLE[login_idx % 7]
            if level > 16:                       # login cycle opens at W3 (UnlockQueue)
                login_idx += 1
                if k_ == "coins":
                    p.earn(val, "login")
                elif k_ == "gems":
                    p.gems += val
                elif k_ == "cache":
                    p.open_cache(val)
                elif k_ == "bp_rare":
                    rares = [m for m in p.machines if MDEF[m][0] == "R"]
                    if rares:
                        p.machines[rng.choice(rares)]["bp"] += val
                p.earn(a["dailies"] * DAILY_MISSION_COINS(min(level, CAMPAIGN_LEVELS)), "missions")
                p.gems += a["dailies"] * DAILY_MISSION_GEMS
                if day % 7 == 6:
                    p.earn(WEEKLY_BONUS["coins"], "missions")
                    p.open_cache(WEEKLY_BONUS["cache"])
                    if level > 42:               # weekly Expedition (opens at L43): unlimited retries in the week
                        p.open_cache("world")
                        if rng.random() < 0.3 + 0.6 * a["skill"]:
                            p.open_cache("royal")
                            p.mythic_bp()
            ads_today = 0
            replay_caches = 0
            new_day = False
        p.attempt += 1
        p.world_reached = max(p.world_reached, world)
        p.frontier = level
        assist = min(RETRY_ASSIST_CAP, RETRY_ASSIST_STEP * losses_here)
        raw = p.power() / demand(dl)
        ratio = raw * (1.0 + assist)
        win_p = 1.0 / (1.0 + math.exp(-(7.0 * (ratio - 1.0) + 3.0 * (a["skill"] - 0.5) + 1.6)))
        win_p = min(0.98, max(0.12, win_p))
        won = level <= FORCED_WIN_LEVELS or rng.random() < win_p or mode == "replay"
        rlog.append((level, ratio, won, raw))
        pick = pickup_coins(pay) * (0.7 + 0.6 * a["skill"])
        wpos = (level - 1) % LEVELS_PER_WORLD + 1
        nm = NEW_CRATE_LEVELS.get(world, {}).get(wpos) if mode == "campaign" else None
        if nm:
            p.unlock(nm)
        p.ceremony_s += CEREMONY["result_min"]
        share = REPLAY_SHARE if mode == "replay" else 1.0
        if won:
            losses_here = 0
            surv = max(0, int(rng.gauss(30 + 60 * a["skill"], 20)))
            stairs = max(1.2, min(5.0, rng.gauss(a["stairs"], 0.5)))
            vc = victory_coins(pay, surv) * (1 + WAR_CHEST_COINS * p.tactics["war_chest"])
            base_gain = (vc + pick) * share
            p.earn(int(base_gain), "level (victory + pickups)")
            p.earn(int(base_gain * (stairs - 1.0)), "stairs multiplier")
            if a["ads"] and level > AD_FREE_LEVELS and ads_today < min(a["ads"], AD_CAP_PER_DAY):
                ads_today += 1
                p.earn(int(base_gain * stairs), "rewarded x2")
            if mode != "replay":
                cr = max(1, min(3, int(round(rng.gauss(a["crowns"], 0.6)))))
                prev = best_crowns.get(level, 0)
                if cr > prev:
                    p.crowns += cr - prev
                    best_crowns[level] = cr
                if level >= 6:                   # first Stone Cache at L6 (UnlockQueue)
                    p.open_cache("world" if boss else "stone")
                if boss:
                    p.cores += 1
                    if mode == "campaign":
                        p.boss_wins += 1
                        p.glory = 1 + sum(1 for t in GLORY_AT_BOSS_WINS if p.boss_wins >= t)
            elif replay_caches < REPLAY_CACHES_PER_DAY:
                replay_caches += 1
                p.open_cache("stone")
            for mid in p.deck()[:3]:
                m = p.machines[mid]
                if m["lvl"] < MAX_LEVEL:
                    m["frac"] += DRIP[MDEF[mid][0]] * (1.5 if rng.random() < 0.3 + 0.4 * a["skill"] else 1.0)
                    whole = int(m["frac"])
                    m["bp"] += whole
                    m["frac"] -= whole
            if level > 40:                       # Arsenal Track opens at W5; nodes count from that rating
                if last_track_rating < 0:
                    last_track_rating = p.rating() // ARSENAL_RATING_STEP * ARSENAL_RATING_STEP
                while p.rating() >= last_track_rating + ARSENAL_RATING_STEP:
                    last_track_rating += ARSENAL_RATING_STEP
                    p.track_nodes += 1
                    if p.track_nodes % TRACK_CACHE_EVERY == 0:
                        p.open_cache("royal" if p.track_nodes % (TRACK_CACHE_EVERY * 4) == 0 else "stone")
                    else:
                        p.earn(100 + 10 * min(level, CAMPAIGN_LEVELS), "arsenal track")
            if mode != "replay":
                level += 1
        else:
            losses_here += 1
            frac = rng.uniform(0.3, 0.95)
            p.earn(int(victory_coins(pay, 0) * LOSS_VICTORY_SHARE * frac + pick * LOSS_PICKUP_SHARE * frac), "lost runs")
            p.cache_charge += LOSS_CACHE_CHARGE
            if p.cache_charge >= 1.0 and level >= 6:
                p.cache_charge -= 1.0
                p.open_cache("stone")
            for mid in p.deck()[:3]:
                m = p.machines[mid]
                m["frac"] += 0.5 * DRIP[MDEF[mid][0]]
        cur_buys += p.spend(level)
        session_levels += 1
        level_today += 1
        if session_levels >= a["lps"]:
            sessions.append(cur_buys)
            sess_cer.append((p.ceremony_s - cur_cer0) / (session_levels * LEVEL_SECONDS + (p.ceremony_s - cur_cer0)))
            cur_buys, session_levels, cur_cer0 = 0, 0, p.ceremony_s
        if level_today >= a["lpd"]:
            level_today = 0
            day += 1
            new_day = True
            if days is not None and day in (30, 60, 90, 120, 150, 180):
                checkpoints["d%d" % day] = dict(
                    level=level, by_rar={r: statistics.mean([m["lvl"] for k, m in p.machines.items() if MDEF[k][0] == r] or [0]) for r in RARITIES},
                    maxed=sum(1 for m in p.machines.values() if m["lvl"] >= MAX_LEVEL), earned=p.earned_coins,
                    avg=statistics.mean(m["lvl"] for m in p.machines.values()))
        cp = level - 1
        if days is None and cp in (5, 10, 20, 30, 40, 50, 56, 60) and cp not in checkpoints:
            checkpoints[cp] = dict(
                day=day + 1, attempts=p.attempt, coins=p.coins, earned=p.earned_coins,
                machines=len(p.machines), avg_lvl=statistics.mean(m["lvl"] for m in p.machines.values()),
                top_lvl=max(m["lvl"] for m in p.machines.values()),
                deck_lvl=statistics.mean(p.machines[k]["lvl"] for k in p.deck()[:3]),
                hero=p.hero_lvl, glory=p.glory, barracks=sum(p.barracks.values()),
                tactics=sum(p.tactics.values()), citadel=p.citadel, rating=p.rating(),
                ratio=p.power() / demand(stage_of(max(1, level - 1))[1]), caches=p.caches_opened, gems=p.gems,
                wild=sum(p.wild.values()), parts=p.parts())
    if session_levels:
        sessions.append(cur_buys)
    p.day_end = day + 1
    return p, checkpoints, sessions, rlog, sess_cer


# =============================================================================================
# REPORTS
# =============================================================================================
def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else 0


def walls(rlog):
    per = collections.Counter(l for l, *_ in rlog)
    cur = best = 0
    for l, r, w, _ in rlog:
        cur = 0 if w else cur + 1
        best = max(best, cur)
    boss = collections.defaultdict(list)
    for l, r, w, _ in rlog:
        if is_boss(l) and l <= CAMPAIGN_LEVELS:
            boss[world_of(l)].append(w)
    return max(per.values()), best, boss


def campaign(kind, seeds, levels=60, policy="greedy", payer=None):
    res = []
    for s in range(seeds):
        res.append(simulate(kind, 1000 + s, levels, policy, payer))
    return res


def summarize(label, res, levels, show_table=True):
    INV = {}
    cps = [r[1] for r in res]
    print("=" * 112)
    print(label)
    if show_table:
        print("%-4s %5s %6s %7s %7s %5s %6s %6s %6s %5s %5s %5s %5s %6s %5s %6s" % (
            "lvl", "day", "tries", "earned", "unspent", "mach", "avgLv", "deckLv", "topLv", "hero",
            "glory", "barr", "tact", "citad", "cache", "pow/dem"))
        for cp in (5, 10, 20, 30, 40, 50, 56, 60):
            rows = [c[cp] for c in cps if cp in c]
            if not rows:
                continue
            m = lambda k: statistics.mean(r[k] for r in rows)
            print("%-4d %5.1f %6.1f %7.0f %7.0f %5.1f %6.1f %6.1f %6.1f %5.1f %5.1f %5.1f %5.1f %6.1f %5.1f %6.2f" % (
                cp, m("day"), m("attempts"), m("earned"), m("coins"), m("machines"), m("avg_lvl"), m("deck_lvl"),
                m("top_lvl"), m("hero"), m("glory"), m("barracks"), m("tactics"), m("citadel"), m("caches"), m("ratio")))
    att = [len(r[3]) for r in res]
    mx, streak, boss = [], [], collections.defaultdict(list)
    bossr, nonbossr = [], []
    for r in res:
        a, b, bw = walls(r[3])
        mx.append(a); streak.append(b)
        for w, v in bw.items():
            boss[w].extend(v)
        for l, ratio, won, raw in r[3]:
            (bossr if is_boss(l) else nonbossr).append(raw)
    win = 100.0 * levels / statistics.mean(att)
    bwr = {w: round(100 * sum(v) / len(v)) for w, v in sorted(boss.items())}
    print("attempts for %d levels %.1f (win %.0f%%) | max attempts on one level p50 %d p90 %d max %d | "
          "loss streak p50 %d p90 %d max %d" % (levels, statistics.mean(att), win, pct(mx, .5), pct(mx, .9), max(mx),
                                                pct(streak, .5), pct(streak, .9), max(streak)))
    print("boss win rate by world:", bwr, "| raw power/demand: boss %.2f, non-boss %.2f" % (
        statistics.mean(bossr), statistics.mean(nonbossr)))
    sess = [x for r in res for x in r[2]]
    cer = [x for r in res for x in r[4]]
    print("sessions with >=1 upgrade %.0f%%, upgrades/session %.2f, ceremony share of session time: mean %.0f%% p90 %.0f%%" % (
        100 * sum(1 for x in sess if x > 0) / max(1, len(sess)), statistics.mean(sess) if sess else 0,
        100 * statistics.mean(cer) if cer else 0, 100 * pct(cer, .9)))
    spent = collections.defaultdict(float)
    for r in res:
        for k, v in r[0].spent.items():
            spent[k] += v / len(res)
    tot = sum(spent.values()) or 1
    print("coin spend: " + ", ".join("%s %.0f%%" % (k, 100 * v / tot) for k, v in spent.items()))
    src = collections.defaultdict(float)
    for r in res:
        for k, v in r[0].src.items():
            src[k] += v / len(res)
    tot = sum(src.values()) or 1
    print("coin income: " + ", ".join("%s %.0f%%" % (k, 100 * v / tot) for k, v in sorted(src.items(), key=lambda x: -x[1])))
    # power decomposition at the last checkpoint
    lastcp = max(c for c in cps[0]) if cps[0] else None
    if lastcp:
        parts = [c[lastcp]["parts"] for c in cps if lastcp in c]
        m = statistics.mean(x[0] for x in parts); h = statistics.mean(x[1] for x in parts)
        a = statistics.mean(x[2] for x in parts); t = statistics.mean(x[3] for x in parts)
        g = (W_MACH * (m - 1), W_HERO * (h - 1), W_ARMY * (a - 1))
        tg = sum(g) + (t - 1)
        print("power growth share at L%d: machines %.0f%%, hero %.0f%%, army %.0f%%, tactics %.0f%%" % (
            lastcp, 100 * g[0] / tg, 100 * g[1] / tg, 100 * g[2] / tg, 100 * (t - 1) / tg))
        INV["mach_share"] = g[0] / tg
    unsp = [c[cp]["coins"] for c in cps for cp in c if cp <= 60]
    print("unspent coins at checkpoints: median %d, p90 %d | end gems %.0f, wild BPs %.1f" % (
        pct(unsp, .5), pct(unsp, .9), statistics.mean(r[0].gems for r in res), statistics.mean(sum(r[0].wild.values()) for r in res)))
    INV.update(win=win, boss_min=min(bwr.values()) if bwr else 100, streak_p90=pct(streak, .9),
               maxatt_p90=pct(mx, .9), days=statistics.mean(r[0].day_end for r in res),
               cer=statistics.mean(cer) if cer else 0, with_buy=sum(1 for x in sess if x > 0) / max(1, len(sess)))
    return INV


def firsts_report(kind, seeds, days=180):
    lpd = ARCHETYPES[kind]["lpd"]
    out = collections.defaultdict(list)
    by_day = collections.defaultdict(list)
    camp_day, inv_day = [], []
    for s in range(seeds):
        p, cps, sess, rlog, cer = simulate(kind, 3000 + s, 10 ** 6, days=days)
        for L in (ASCENSION_LEVEL, 10, APEX_LEVEL, MAX_LEVEL):
            if L in p.firsts:
                att, lvl = p.firsts[L]
                out[L].append((lvl, att / lpd + 1))
        for k, c in cps.items():
            by_day[k].append(c)
        firsts_at = {}
        for i, (l, *_r) in enumerate(rlog):
            firsts_at.setdefault(l, i)
        if CAMPAIGN_LEVELS + 1 in firsts_at:
            camp_day.append(firsts_at[CAMPAIGN_LEVELS + 1] / lpd + 1)
        if 2 * CAMPAIGN_LEVELS + 1 in firsts_at:
            inv_day.append(firsts_at[2 * CAMPAIGN_LEVELS + 1] / lpd + 1)
    line = []
    for L, v in sorted(out.items()):
        line.append("Lv%d: L%d / day %.0f (%d%%)" % (L, pct([x for x, _ in v], .5), pct([d for _, d in v], .5),
                                                     100 * len(v) // seeds))
    print("  %-9s first machine at " % kind + " | ".join(line))
    print("            campaign done day %.0f, Invasion done day %s" % (
        statistics.median(camp_day) if camp_day else -1, "%.0f" % statistics.median(inv_day) if inv_day else "not within %d" % days))
    prev = None
    for k in ("d30", "d60", "d90", "d120", "d180"):
        rows = by_day.get(k)
        if not rows:
            continue
        e = statistics.mean(r["earned"] for r in rows)
        rate = "" if prev is None else ", coins/day since previous %.0f" % ((e - prev[1]) / (int(k[1:]) - prev[0]))
        prev = (int(k[1:]), e)
        print("            day %-3s frontier L%.0f, avg machine Lv %.1f, maxed %.1f/24, by rarity: %s%s" % (
            k[1:], statistics.mean(r["level"] for r in rows), statistics.mean(r["avg"] for r in rows),
            statistics.mean(r["maxed"] for r in rows),
            " ".join("%s %.1f" % (r, statistics.mean(x["by_rar"][r] for x in rows)) for r in RARITIES), rate))
    return {L: pct([x for x, _ in v], .5) for L, v in out.items()}, {L: pct([d for _, d in v], .5) for L, v in out.items()}


def pity_stream(n, present, kind="stone"):
    class P: pass
    pt = P(); pt.since_epic = 0; pt.since_leg = 0; pt.leg_welcome_done = True
    rng = random.Random(5)
    legs = epics = 0
    gaps, last, max_e_gap, last_e = [], 0, 0, 0
    for i in range(n):
        cards = roll_cache(kind, present, pt, rng)
        b = max((r for r, _ in cards), key=lambda r: RAR_IDX[r])
        if RAR_IDX[b] >= 3:
            legs += 1; gaps.append(i - last); last = i
        if RAR_IDX[b] >= 2:
            epics += 1; max_e_gap = max(max_e_gap, i - last_e); last_e = i
    return n / max(1, legs), n / max(1, epics), max(gaps) if gaps else 0, max_e_gap


def mc_best(kind, present, n=200000):
    class P: pass
    pt = P(); pt.since_epic = 0; pt.since_leg = 0; pt.leg_welcome_done = True
    rng = random.Random(9)
    cnt = collections.Counter()
    for i in range(n):
        pt.since_epic = 0; pt.since_leg = 0
        cards = roll_cache(kind, present, pt, rng)
        cnt[max((r for r, _ in cards), key=lambda r: RAR_IDX[r])] += 1
    return {r: cnt[r] / n for r in RARITIES}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=200)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--section", default="all")
    args = ap.parse_args()
    seeds = 60 if args.quick else args.seeds
    fails = []
    def inv(name, ok, detail):
        print("  [%s] %s  (%s)" % ("PASS" if ok else "FAIL", name, detail))
        if not ok:
            fails.append(name)

    print("Crystal Rush meta economy sim v2 | seeds per archetype: %d" % seeds)
    # ---------------- 1. totals -----------------------------------------------------------
    print("\n## 1. Sink totals")
    arsenal = sum(sum(c for l, c in COIN_TO.items() if l > START_LEVEL[r]) for m, (r, w, f) in MDEF.items())
    per_machine = {r: sum(c for l, c in COIN_TO.items() if l > START_LEVEL[r]) for r in RARITIES}
    bp_tot = {r: sum(BP_TO[r].values()) for r in RARITIES}
    hero_tot = sum(hero_cost(l) for l in range(1, HERO_MAX))
    bar_track = sum(bar_cost(l) for l in range(1, BAR_MAX + 1))
    tac_tot = len(TACTICS) * sum(TACTICS_PRICE)
    print("machine coins per target level:", COIN_TO, "| sum Lv1->15 = %d" % sum(COIN_TO.values()))
    print("coins per machine from rarity start:", per_machine, "| full Arsenal (24 machines) = %d" % arsenal)
    print("blueprints Lv start->15 per rarity:", bp_tot)
    print("hero levels 1->30 per hero: %d (L1->2 %d, L10->11 %d, L29->30 %d)" % (
        hero_tot, hero_cost(1), hero_cost(10), hero_cost(29)))
    print("Barracks: per track %d (L1 %d, L5 %d, L10 %d), %d tracks = %d" % (
        bar_track, bar_cost(1), bar_cost(5), bar_cost(10), len(BAR_TRACKS), bar_track * len(BAR_TRACKS)))
    print("Tactics: %d nodes x ranks %s = %d" % (len(TACTICS), TACTICS_PRICE, tac_tot))
    print("Grand coin sink (Arsenal + 2 heroes + Barracks + Tactics) = %d" % (arsenal + 2 * hero_tot + bar_track * len(BAR_TRACKS) + tac_tot))
    print("Haven: %s crowns per world = %d; 7 worlds = %d (max crowns from campaign = %d)" % (
        HAVEN_STAGE_COST, sum(HAVEN_STAGE_COST), 7 * sum(HAVEN_STAGE_COST), 3 * CAMPAIGN_LEVELS))
    na = 0
    for ph, d in ASSET_MANIFEST.items():
        n = sum(d.values()); na += n
        print("assets %s: %d (%s) -> ~%d Meshy generations at %d attempts" % (
            ph, n, ", ".join("%s %d" % kv for kv in d.items()), n * MESHY_ATTEMPTS, MESHY_ATTEMPTS))
    print("assets total: %d -> ~%d generations" % (na, na * MESHY_ATTEMPTS))

    # ---------------- 2. caches -------------------------------------------------------------
    print("\n## 2. Cache odds (exact, no pity) per pool state; MC check 200k; pity streams 200k")
    states = [("W1 (C,R)", {"C", "R"}), ("W2 (C,R,E)", {"C", "R", "E"}),
              ("W3+ (C,R,E,L)", {"C", "R", "E", "L"}), ("Mythic forged", {"C", "R", "E", "L", "M"})]
    for label, present in states:
        print(" pool %s" % label)
        for kind in CACHES:
            ex = exact_best_table(kind, present)
            pc = per_card_table(kind, present, False)
            pg = per_card_table(kind, present, True)
            print("   %-6s best: %s | per free slot: %s | guaranteed slot: %s" % (
                kind, " ".join("%s %.2f%%" % (r, 100 * ex[r]) for r in RARITIES if ex[r] > 0),
                " ".join("%s %.2f%%" % (r, 100 * pc[r]) for r in RARITIES if pc[r] > 0),
                " ".join("%s %.2f%%" % (r, 100 * pg[r]) for r in RARITIES if pg[r] > 0)))
    full = {"C", "R", "E", "L"}
    for kind in CACHES:
        ex = exact_best_table(kind, full)
        mc = mc_best(kind, full, 200000 if not args.quick else 50000)
        nmc = 200000 if not args.quick else 50000
        z = max(abs(ex[r] - mc[r]) / math.sqrt(max(ex[r] * (1 - ex[r]), 1e-12) / nmc) for r in RARITIES if ex[r] > 0)
        dev = max(abs(ex[r] - mc[r]) for r in RARITIES)
        inv("odds table matches roller (%s)" % kind, z <= 4.0, "max %.2f SE, max |exact - MC| %.3f pp" % (z, 100 * dev))
    for label, present in states[1:]:
        lp, ep, lg, eg = pity_stream(200000 if not args.quick else 50000, present)
        print(" stone-cache stream, pool %s: 1 Legendary per %.1f caches (longest gap %d), Epic+ every %.2f (longest gap %d)" % (
            label, lp, lg, ep, eg))
        if "L" in present:
            inv("Legendary hard pity holds (%s)" % label, lg <= PITY_LEG_HARD, "longest gap %d" % lg)
        inv("Epic hard pity holds (%s)" % label, eg <= PITY_EPIC, "longest gap %d" % eg)

    # ---------------- 3. in-run budget -------------------------------------------------------
    print("\n## 3. In-run arsenal budget (per level, mixed archetypes)")
    ir = inrun_report(3000 if not args.quick else 800)
    for band, d in ir.items():
        print("  %-7s P(Rank II+) %.0f%%  P(Rank III) %.0f%%  P(evolution) %.0f%%  P(fusion) %.0f%%  P(evo or fusion) %.0f%%" % (
            band, 100 * d["r2"], 100 * d["r3"], 100 * d["evo"], 100 * d["fus"], 100 * d["any"]))
    inv("L2-10 Rank II >= 70%", ir["L2-10"]["r2"] >= 0.70, "%.0f%%" % (100 * ir["L2-10"]["r2"]))
    inv("L2-10 evo or fusion is a rare treat (5-20%)", 0.05 <= ir["L2-10"]["any"] <= 0.20, "%.0f%%" % (100 * ir["L2-10"]["any"]))
    inv("L11-30 Rank III 60-85%", 0.60 <= ir["L11-30"]["r3"] <= 0.85, "%.0f%%" % (100 * ir["L11-30"]["r3"]))
    inv("L11-30 evo or fusion 30-45%", 0.30 <= ir["L11-30"]["any"] <= 0.45, "%.0f%%" % (100 * ir["L11-30"]["any"]))
    inv("L31+ Rank III >= 70%", ir["L31-56"]["r3"] >= 0.70, "%.0f%%" % (100 * ir["L31-56"]["r3"]))
    inv("L31+ evo or fusion 50-65%", 0.50 <= ir["L31-56"]["any"] <= 0.65, "%.0f%%" % (100 * ir["L31-56"]["any"]))
    inv("L31+ fusion 10-25%", 0.10 <= ir["L31-56"]["fus"] <= 0.25, "%.0f%%" % (100 * ir["L31-56"]["fus"]))
    if args.section == "inrun":
        return

    # ---------------- 4. campaign -------------------------------------------------------------
    print("\n## 4. Campaign (60 levels = 56 campaign + 4 Invasion), greedy 'Best upgrade' policy")
    R = {}
    for kind in ("casual", "regular", "hardcore"):
        a = ARCHETYPES[kind]
        R[kind] = summarize("%s (%d lv/day, %d lv/session, skill %.2f, stairs x%.1f)" % (
            kind.upper(), a["lpd"], a["lps"], a["skill"], a["stairs"]), campaign(kind, seeds), 60)
    print("\n## 4b. Spending policies and weaker players (walls)")
    P = {}
    for kind, pol in (("casual", "spread"), ("casual", "machines_only"), ("weak", "greedy"), ("weak", "spread"),
                      ("ad_watcher", "greedy")):
        P[(kind, pol)] = summarize("%s / %s" % (kind, pol), campaign(kind, seeds, 60, pol), 60, show_table=False)
    print("\n## 4c. Payer check (Starter Arsenal), casual greedy")
    PS = summarize("casual / greedy / Starter Arsenal", campaign("casual", seeds, 60, "greedy", "starter"), 60, show_table=False)

    # ---------------- 5. long horizon ----------------------------------------------------------
    print("\n## 5. Long horizon (180 days: campaign, then Invasion (difficulty 56+n), then replay at 60%)")
    F, FD = {}, {}
    for kind in ("casual", "regular", "hardcore"):
        F[kind], FD[kind] = firsts_report(kind, max(20, seeds // 6))

    # ---------------- 6. invariants -------------------------------------------------------------
    print("\n## 6. Invariants")
    for kind in ("casual", "regular", "hardcore"):
        inv("%s boss win >= 65%% every world" % kind, R[kind]["boss_min"] >= 65, "min %d%%" % R[kind]["boss_min"])
        inv("%s loss streak p90 <= 3" % kind, R[kind]["streak_p90"] <= 3, "p90 %d" % R[kind]["streak_p90"])
        inv("%s max attempts on one level p90 <= 4" % kind, R[kind]["maxatt_p90"] <= 4, "p90 %d" % R[kind]["maxatt_p90"])
        inv("%s ceremony <= 15%% of session time" % kind, R[kind]["cer"] <= 0.15, "%.0f%%" % (100 * R[kind]["cer"]))
        inv("%s machines >= 50%% of power growth" % kind, R[kind]["mach_share"] >= 0.50, "%.0f%%" % (100 * R[kind]["mach_share"]))
    inv("casual sessions with a purchase >= 85%", R["casual"]["with_buy"] >= 0.85, "%.0f%%" % (100 * R["casual"]["with_buy"]))
    inv("casual win rate 65-85%", 65 <= R["casual"]["win"] <= 85, "%.0f%%" % R["casual"]["win"])
    inv("casual spread policy boss win >= 60%", P[("casual", "spread")]["boss_min"] >= 60, "min %d%%" % P[("casual", "spread")]["boss_min"])
    inv("casual machines-only boss win >= 55%", P[("casual", "machines_only")]["boss_min"] >= 55, "min %d%%" % P[("casual", "machines_only")]["boss_min"])
    inv("weak casual boss win >= 55%", P[("weak", "greedy")]["boss_min"] >= 55, "min %d%%" % P[("weak", "greedy")]["boss_min"])
    inv("ad watcher win-rate gain <= 6 pp", P[("ad_watcher", "greedy")]["win"] - R["casual"]["win"] <= 6,
        "+%.1f pp" % (P[("ad_watcher", "greedy")]["win"] - R["casual"]["win"]))
    inv("Starter Arsenal win-rate gain <= 3 pp", PS["win"] - R["casual"]["win"] <= 3, "+%.1f pp" % (PS["win"] - R["casual"]["win"]))
    reg_apex = F["regular"].get(APEX_LEVEL, 999)
    inv("regular first Apex (Lv12) at L44-60", 44 <= reg_apex <= 60, "level %d" % reg_apex)
    reg_asc = F["regular"].get(ASCENSION_LEVEL, 999)
    inv("regular first Ascension (Lv8) at L20-34", 20 <= reg_asc <= 34, "level %d" % reg_asc)
    print("\n%d invariant(s) failed" % len(fails) if fails else "\nall invariants pass")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
