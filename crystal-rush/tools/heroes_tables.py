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
}
# second ult number that scales with ult.power (optional)
ULT2 = {
    "vesta": (8, "Sunstride slam (form IV)", 7),
    "vartan": (8, "Landslide (form IV)", 7),
    "lumen": (4, "Crown Shard hit (form IV)", 7),
    "pava": (4, "Eyes Wide kills (form IV)", 7),
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
}

# ------------------------------------------------------------------------------------------------ champions
# (id, uk, native, class, element, faction, hp, action number, action label, aura value, aura label, radius, slot)
CHAMPS = [
    ("mila", "Міла", 0, "Healer", "Tech", "Dawn", 30, 3, "soldiers returned per pulse (every 3 s)", 0.12, "hazard losses -", 1.3, "left"),
    ("ivo", "Іво", 0, "Guardian", "Plasma", "Dawn", 60, 3, "blocked-barricade damage (Block every 5 s)", 0.10, "clash losses -", 1.0, "front"),
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
]
AURA_SHARE = {"front": 0.35, "left": 0.30, "right": 0.30, "rear": 0.25}
AURA_CAP = 0.40


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


if __name__ == "__main__":
    main()
