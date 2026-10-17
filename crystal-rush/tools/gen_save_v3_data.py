#!/usr/bin/env python3
"""Generates scripts/core/save_v3_data.gd (class SaveV3Data): the numbers Save v3 and the v2 -> v3 migration need
(heroes_design.md §12.1, §12.3), taken from the single source of numbers, never typed by hand.

Sources
  1. heroes_consts.json (exported by heroes_sim.py v2): ladder SKILL_BASE / AWAKEN_CAP / BORN_AWAKENED_MIN /
     FACETS_PER_GEM, progress TOME_COST / CHAMP_LEVEL_MAX, portal BEACON, chests TOMES_BOSS, unlocks.
     Looked up at tools/data/heroes_consts.json (the repo copy, WS-A) or passed with --consts.
  2. tools/data/heroes_migration.json: what heroes_consts.json does not carry (the roster ids with their native gem,
     the starters, BOSS_LEVELS, the EXPECTED Champion Level by frontier and the lump-grant caps of
     heroes_sim.migrate_grant). Refreshed from the sim with --sim <path to heroes_sim.py>: the table is recomputed
     exactly as heroes_sim.section_migration does (12 casual EXPECTED-only seeds 7000.., median per frontier) and
     checked against the published anchors of heroes_design.md §12.3; the grant literals are checked against the
     sim source.

Usage
  python3 tools/gen_save_v3_data.py                       # regenerate the .gd from the two json files
  python3 tools/gen_save_v3_data.py --check               # exit 1 when the .gd is out of date (CI / tests)
  python3 tools/gen_save_v3_data.py --sim <heroes_sim.py> # recompute heroes_migration.json, then the .gd
  python3 tools/gen_save_v3_data.py --sim <heroes_sim.py> --roster-only
      # a roster addition: refresh only the ids (heroes / champions / starters) from the sim and keep the published
      # EXPECTED Champion Level table and grant literals (the 12-seed median of that table sits on x.5 boundaries at
      # several frontiers, so a new id that only shifts the RNG stream must not move the §12.3 anchors); the kept
      # table is still checked against the anchors
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_GD = os.path.join(ROOT, "scripts", "core", "save_v3_data.gd")
MIGRATION_JSON = os.path.join(ROOT, "tools", "data", "heroes_migration.json")
CONSTS_CANDIDATES = [
    os.path.join(ROOT, "tools", "data", "heroes_consts.json"),
    "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/heroes/heroes_consts.json",
]
GEMS = ["C", "R", "E", "L", "M"]
# heroes_design.md §12.3 step 3 publishes these Champion Levels; the recomputed table must hit them.
CL_ANCHORS = {24: 3, 32: 4, 40: 5, 48: 5, 56: 6, 80: 9, 112: 13}
# heroes_design.md §12.3 step 2: "Glory ◆ above 1 -> 10 Star Ore each (credited at the Workshop unlock)". The sim
# retires Glory without a number, so the doc is the source for this one value.
ORE_PER_GLORY_STEP = 10


def _consts_path(arg: str | None) -> str:
    for p in ([arg] if arg else []) + CONSTS_CANDIDATES:
        if p and os.path.exists(p):
            return p
    sys.exit("heroes_consts.json not found (pass --consts)")


def refresh_migration_json(sim_path: str, consts: dict, roster_only: bool = False) -> dict:
    """Recomputes heroes_migration.json from heroes_sim.py (read-only use of the sim). `roster_only` refreshes the ids
    and keeps the published table and grant of the current json (see --roster-only)."""
    sim_dir = os.path.dirname(os.path.abspath(sim_path))
    sys.path.insert(0, sim_dir)
    sys.dont_write_bytecode = True
    argv = sys.argv
    sys.argv = [sim_path]
    import heroes_sim as H  # noqa: E402
    sys.argv = argv
    src = open(sim_path, encoding="utf-8").read()
    body = src[src.index("def migrate_grant"):src.index("def ", src.index("def migrate_grant") + 10)]
    m_beacon = re.search(r"beacons = min\((\d+),", body)
    m_chest = re.search(r"n_hero = min\((\d+), max\(0, \(L - UNLOCK_AT\[\"champions\"\]\) // (\d+)\)\)", body)
    if not (m_beacon and m_chest and "TOMES_BOSS * after(UNLOCK_AT[\"skills\"])" in body
            and "n_grand = after(UNLOCK_AT[\"champions\"])" in body and "L = level - 1" in body):
        sys.exit("heroes_sim.migrate_grant changed shape: update gen_save_v3_data.py")
    tf = {int(k): v for k, v in consts["team_demand"].items()}
    if roster_only:
        cl = json.load(open(MIGRATION_JSON, encoding="utf-8"))["expected_champion_level"]
    else:
        runs = [H.simulate("casual", 7000 + s, 112, tf=tf, expected_only=True) for s in range(12)]
        cl = [1] + [int(statistics.median(r[0].cl_at.get(L, 1) for r in runs)) for L in range(1, 113)]
    bad = {L: (cl[L], v) for L, v in CL_ANCHORS.items() if cl[L] != v}
    if bad:
        sys.exit("EXPECTED Champion Level differs from heroes_design.md §12.3: %s" % bad)
    data = {
        "_source": "heroes_sim.py v2 (%s) via tools/gen_save_v3_data.py --sim" % os.path.basename(sim_path),
        "heroes": {h: GEMS[d["n"]] for h, d in H.HEROES.items()},
        "champions": {c: GEMS[d["n"]] for c, d in H.CHAMPS.items()},
        "starters": list(H.STARTERS),
        "start_owned": [h for h, d in H.HEROES.items() if d.get("starter") == 0],
        "champion_max_gem": "L",
        "boss_levels": list(H.BOSS_LEVELS),
        "campaign_levels": H.E.CAMPAIGN_LEVELS,
        "grant": {"beacon_cap": int(m_beacon.group(1)), "hero_chest_cap": int(m_chest.group(1)),
                  "hero_chest_every": int(m_chest.group(2)), "frontier_offset": 1},
        "expected_champion_level": cl,
    }
    os.makedirs(os.path.dirname(MIGRATION_JSON), exist_ok=True)
    with open(MIGRATION_JSON, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    return data


def _gd(v) -> str:
    """Python value -> GDScript literal (dicts keep insertion order)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "[" + ", ".join(_gd(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join("%s: %s" % (_gd(str(k)), _gd(x)) for k, x in v.items()) + "}"
    raise TypeError(v)


def _typed(name: str, kind: str, v) -> str:
    return "const %s: Array[%s] = %s" % (name, kind, _gd(v))


def render(consts: dict, mig: dict, consts_sha: str, mig_sha: str) -> str:
    lad, prog, portal, chests, unl = consts["ladder"], consts["progress"], consts["portal"], consts["chests"], consts["unlocks"]
    beacon = portal["BEACON"]
    lines = [
        "class_name SaveV3Data",
        "## GENERATED by tools/gen_save_v3_data.py — do not edit by hand (python3 tools/gen_save_v3_data.py).",
        "## Numbers Save v3 and the v2 -> v3 migration read (heroes_design.md §12.1, §12.3). Sources:",
        "## heroes_consts.json sha256 %s, tools/data/heroes_migration.json sha256 %s." % (consts_sha[:16], mig_sha[:16]),
        "## WS-A's Ladder / HeroData / ChampionData carry the same numbers for the rules; this file only feeds",
        "## the save layer so Save v3 has no load-order dependency on the rule classes.",
        "",
        "const GEMS: Array[String] = %s" % _gd(GEMS),
        "## Hero id -> native gem (roster order).",
        "const HERO_NATIVE := %s" % _gd(mig["heroes"]),
        "## Champion id -> native gem (roster order). Champions recut at most to CHAMPION_MAX_GEM.",
        "const CHAMPION_NATIVE := %s" % _gd(mig["champions"]),
        "const CHAMPION_MAX_GEM := %s" % _gd(mig["champion_max_gem"]),
        "const HERO_MAX_GEM := \"M\"",
        _typed("STARTERS", "String", mig["starters"]),
        "## Heroes owned by a brand-new account.",
        _typed("START_OWNED", "String", mig["start_owned"]),
        "",
        "# ---- ladder (heroes_consts.json \"ladder\")",
        "const FACETS_PER_GEM := %d" % lad["FACETS_PER_GEM"],
        _typed("SKILL_BASE", "int", lad["SKILL_BASE"]),
        "const AWAKEN_MIN_GEM := %s" % _gd(lad["AWAKEN_MIN_GEM"]),
        "const AWAKEN_CAP := %s" % _gd(lad["AWAKEN_CAP"]),
        "const BORN_AWAKENED_MIN := %s" % _gd(lad["BORN_AWAKENED_MIN"]),
        "## Ult power = (1 + ULT_RANK_STEP x (rank - 1)) x (1 + LV_ULT x (lvl - 1)) (no-loss migration check).",
        "const ULT_RANK_STEP := %s" % _gd(float(lad["ULT_RANK_STEP"])),
        "const LV_ULT := %s" % _gd(float(lad["LV_ULT"])),
        "",
        "# ---- progress (heroes_consts.json \"progress\")",
        "## TOME_COST[r] = Tomes for skill rank r -> r + 1.",
        _typed("TOME_COST", "int", prog["TOME_COST"]),
        "const CHAMP_LEVEL_MAX := %d" % prog["CHAMP_LEVEL_MAX"],
        "",
        "# ---- unlock levels (heroes_consts.json \"unlocks\"; after_win)",
        "const UNLOCK_AT := %s" % _gd(unl),
        "",
        "# ---- lump grant on update day (heroes_design.md §12.3 step 3 = heroes_sim.migrate_grant)",
        "## Frontier L = next level to play - FRONTIER_OFFSET (the last level cleared).",
        "const FRONTIER_OFFSET := %d" % mig["grant"]["frontier_offset"],
        "const BEACON_FIRST_CLEAR := %s" % _gd(float(beacon["first_clear"])),
        "const BEACON_BOSS := %s" % _gd(beacon["boss"]),
        "const BEACON_CAP := %d" % mig["grant"]["beacon_cap"],
        "const HERO_CHEST_CAP := %d" % mig["grant"]["hero_chest_cap"],
        "const HERO_CHEST_EVERY := %d" % mig["grant"]["hero_chest_every"],
        "const TOMES_BOSS := %d" % chests["TOMES_BOSS"],
        "## Star Ore per Glory step above 1 (credited at the Workshop unlock; heroes_design.md §12.3 step 2).",
        "const ORE_PER_GLORY_STEP := %d" % ORE_PER_GLORY_STEP,
        "const CAMPAIGN_LEVELS := %d" % mig["campaign_levels"],
        _typed("BOSS_LEVELS", "int", mig["boss_levels"]),
        "## EXPECTED Champion Level at frontier L (index 0..112), median of the sim's casual EXPECTED-only runs.",
        _typed("EXPECTED_CHAMPION_LEVEL", "int", mig["expected_champion_level"]),
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--consts")
    ap.add_argument("--sim")
    ap.add_argument("--roster-only", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.roster_only and not a.sim:
        sys.exit("--roster-only needs --sim <heroes_sim.py>")
    cpath = _consts_path(a.consts)
    craw = open(cpath, "rb").read()
    consts = json.loads(craw)
    if a.sim:
        refresh_migration_json(a.sim, consts, a.roster_only)
    mraw = open(MIGRATION_JSON, "rb").read()
    text = render(consts, json.loads(mraw), hashlib.sha256(craw).hexdigest(), hashlib.sha256(mraw).hexdigest())
    if a.check:
        cur = open(OUT_GD, encoding="utf-8").read() if os.path.exists(OUT_GD) else ""
        if cur != text:
            print("save_v3_data.gd is OUT OF DATE (run python3 tools/gen_save_v3_data.py)")
            sys.exit(1)
        print("save_v3_data.gd in sync (%s)" % os.path.relpath(cpath, ROOT) if cpath.startswith(ROOT) else
              "save_v3_data.gd in sync (%s)" % cpath)
        return
    with open(OUT_GD, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("wrote %s" % os.path.relpath(OUT_GD, ROOT))


if __name__ == "__main__":
    main()
