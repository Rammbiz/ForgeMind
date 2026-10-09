#!/usr/bin/env python3
"""Loc lint for Crystal Rush (arsenal_design.md §0, heroes_design.md §1.3 / §12.4). WS-Loc owns this file.

Reads the string tables of scripts/autoload/loc.gd (STRINGS + the phase-gated HEROES_LIVE overlay) and checks
them twice: as SHIPPED (heroes phase below EconData.HEROES_LIVE_PHASE, the 2.2.1 game) and as LIVE (the overlay
applied, what players read once the hero systems are on). Exit code 1 on any error.

    python3 tools/loc_lint.py                 # every check
    python3 tools/loc_lint.py --baseline REF  # + the shipped table equals the one at git REF outside the heroes block
    python3 tools/loc_lint.py --list-glossary # print the glossary rows and exit
    python3 tools/loc_lint.py --quiet         # only errors and the summary line

Checks
  rows       every row has exactly two non-empty strings (uk, en); no key twice in one table
  format     uk and en carry the same placeholders in the same order; an overlay row keeps its base row's
             placeholders (callers never change when the phase flips)
  emoji      no emoji code points (§9.1); the text symbols ★ ◆ ▲ ▶ ◎ ✓ are allowed
  percent    no literal number followed by % (§12.4) outside LEGACY_PCT; no ASCII digit at all in a heroes-block
             value outside DIGIT_OK (numbers are %d / %s filled from data)
  apostrophe uk text uses ’ (U+2019), never ' or ʼ, so one name is never spelled two ways
  glossary   §1.3 glossary (one display name per concept): forbidden synonyms, retired Meta-1 terms in LIVE
  names      one display name never names two different things (machines, heroes, champions, skills, forms,
             relics, gear, tags, gems, currencies, caches); RENAMES lists deliberate departures from the design doc
  doc        names, titles, role lines, skill / beat / form / relic / gear names and lore equal heroes_design.md
             §6 (after RENAMES); the glossary terms equal §1.3
  coverage   every roster id (tools/data/heroes_roster.json) has its keys; every §12.4 key family is present
  code       every literal Loc.t / Loc.f key and every unlock / bundle "line" in scripts/ exists in Loc
  tables     a screen-local table ("KEY": ["uk", "en"] in scripts/ui) may not shadow a Loc key with other text
             (that would change shipped copy); any table row that shares a Loc key has the same placeholders
  length     _DESC / _VALUE <= 90 characters, TUT_* <= 60, HINT_* <= 60 (part U §5.4)
  fonts      every character of every value exists in all four M PLUS Rounded 1c weights (no tofu)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOC = os.path.join(ROOT, "scripts", "autoload", "loc.gd")
DOC = os.path.join(ROOT, "docs", "design", "heroes_design.md")
ROSTER = os.path.join(ROOT, "tools", "data", "heroes_roster.json")
FONTS = [os.path.join(ROOT, "assets", "fonts", "MPLUSRounded1c-%s.ttf" % w) for w in ("Regular", "Medium", "Bold", "ExtraBold")]

HEROES_BEGIN = "# ==== HEROES BEGIN"
HEROES_END = "# ==== HEROES END"

# ------------------------------------------------------------------------------------------------ glossary
# heroes_design.md §1.3 (final). One display name per concept: (en, uk, code id, meaning). `doc` re-reads the table
# and fails when it drifts from these rows.
GLOSSARY = [
    ("Hero", "Герой", "hero", "Leads the run; ult button; 4 skills."),
    ("Champion", "Чемпіон", "champion", "Commander inside the crowd; acts on its own; can fall."),
    ("Team", "Команда", "team", "1 hero + 2-3 champions (never «загін»: enemy squads own it)."),
    ("Rarity", "Рідкість", "gem", "The gem tier; values Кварц … Опал (never «самоцвіт» = the Gems currency)."),
    ("Native", "Корінний", "native", "The gem a character was born with; printed forever."),
    ("Facet / Full facets", "Грань / Повні грані", "facets", "0-5 per gem; 5/5 = Full facets."),
    ("Recut", "Огранка (огранити)", "recut", "Promotion to the next gem; facets restart at 0."),
    ("Fragments", "Фрагменти", "frags", "Per-character duplicate progress."),
    ("Tome", "Том / Томи", "tomes", "Skill-rank resource (heroes only)."),
    ("Star Ore", "Зоряна руда", "ore", "The one Workshop material."),
    ("Ultimate · Attack · Rally · Awakening", "Ульта · Атака · Клич · Пробудження", "ult attack rally awakened", "The four hero skills."),
    ("Ult form", "Форма ульти", "form", "I-V named after the gems; max = the NATIVE gem."),
    ("Champion Level", "Рівень чемпіонів", "champions.level", "One shared coin track for all champions."),
    ("Action / Aura", "Дія / Аура", "action aura", "A champion's own behaviour / its buff to soldiers in its ring."),
    ("Class · Element · Faction", "Клас · Стихія · Фракція", "class element faction", "Synergy tags (element = machine family)."),
    ("Affinity", "Спорідненість", "affinity", "Team members boost fielded machines of their element."),
    ("Portal · Beacon · Seal", "Портал · Маяк · Печатка", "summon beacons summon.seals", "Hero summoning; 1 Beacon = 1 summon."),
    ("Hero Chest / Grand Hero Chest", "Скриня героїв / Велика скриня героїв", "hero_chest grand_hero_chest", "Win rewards."),
    ("Focus", "Фокус", "focus", "The chosen character gets exactly 60% of its gem's results."),
    ("Workshop", "Майстерня", "workshop", "Deterministic gear crafting («кувати» stays a verb)."),
    ("Gear · Relic · Tempering · Trophy", "Спорядження · Реліквія · Гартування · Трофей", "gear relic rank trophies", "Gear."),
    ("Might", "Міць", "power", "The power index on cards (never «Сила»)."),
    ("Chronicle", "Хроніка героя", "chronicle", "Cosmetic pages bought with Tomes (no power)."),
    ("Codex", "Довідник", "codex", "The 5-row explainer sheet behind «?»."),
]

# Keys whose value must be exactly the glossary display name (uk, en). Checked in the LIVE table.
GLOSSARY_KEYS = {
    "TEAM_TITLE": ("Команда", "Team"),
    "RARITY": ("Рідкість", "Rarity"),
    "NATIVE": ("Корінний", "Native"),
    "FACET_NAME": ("Грані", "Facets"),
    "FACET_FULL": ("Повні грані", "Full facets"),
    "RECUT_TITLE": ("Огранка", "Recut"),
    "CUR_FRAGS": ("Фрагменти", "Fragments"),
    "CUR_TOME": ("Томи", "Tomes"),
    "CUR_ORE": ("Зоряна руда", "Star Ore"),
    "SKL_ULT": ("Ульта", "Ultimate"),
    "SKL_ATTACK": ("Атака", "Attack"),
    "SKL_RALLY": ("Клич", "Rally"),
    "SKL_AWAKEN": ("Пробудження", "Awakening"),
    "SKL_FORM_NAME": ("Форма ульти", "Ult form"),
    "CHAMP_LEVEL": ("Рівень чемпіонів", "Champion Level"),
    "CHAMP_UI_ACTION": ("Дія", "Action"),
    "CHAMP_UI_AURA": ("Аура", "Aura"),
    "CLASS": ("Клас", "Class"),
    "ELEMENT": ("Стихія", "Element"),
    "FACTION": ("Фракція", "Faction"),
    "AFFINITY": ("Спорідненість", "Affinity"),
    "PORTAL_TITLE": ("Портал", "Portal"),
    "CUR_BEACON": ("Маяки", "Beacons"),
    "CUR_SEAL": ("Печатки", "Seals"),
    "CHEST_HERO": ("Скриня героїв", "Hero Chest"),
    "CHEST_GRAND": ("Велика скриня героїв", "Grand Hero Chest"),
    "PORTAL_FOCUS": ("Фокус", "Focus"),
    "WORKSHOP_TITLE": ("Майстерня", "Workshop"),
    "GEAR": ("Спорядження", "Gear"),
    "SKL_RELIC": ("Реліквія", "Relic"),
    "TEMPER": ("Гартування", "Tempering"),
    "TROPHY": ("Трофей", "Trophy"),
    "POWER": ("Міць", "Might"),
    "CHRONICLE_TITLE": ("Хроніка героя", "Hero Chronicle"),
    "CODEX_TITLE": ("Довідник", "Codex"),
    "HERO_WORD": ("Герой", "Hero"),
    "CHAMP_WORD": ("Чемпіон", "Champion"),
}

# Forbidden terms: (name, regex, lang, where, key scope regex or None, allowed keys, why).
#   lang  = "uk" | "en" | "both" (which string of a row the regex reads)
#   where = "heroes" (heroes block + overlay, both tables) | "live" (the whole LIVE table) | "all" (heroes keys of
#           SHIPPED + the whole LIVE table)
#   allowed = a set of keys, or None = only heroes-block keys may use the term
FORBIDDEN = [
    ("rarity-gem", r"[Сс]амоцвіт", "uk", "heroes", None, set(), "rarity is «Рідкість»; «Самоцвіти» = the Gems currency"),
    ("rarity-gem-en", r"\b[Gg]ems?\b", "en", "heroes", None, set(), "rarity is «Rarity» in en; Gems = the currency"),
    ("team-squad", r"[Зз]аг[іо]н", "uk", "heroes", r"^(TEAM_|TUT_TEAM)", set(), "the team is «Команда» (never «загін»: enemy squads own it)"),
    ("full-facets", r"[Пп]овн\w* огранк|[Ff]ull cut", "both", "all", None, set(), "«Повні грані / Full facets» (never «Повна огранка»)"),
    ("workshop-forge", r"[Кк]узн[яіеюиь]", "uk", "all", None, set(), "«Майстерня / Workshop» (your Forge; «кувати» stays a verb)"),
    ("workshop-forge-en", r"\bForge\b", "en", "heroes", r"^(WORKSHOP_|UNL_WORKSHOP|UNF_WORKSHOP|TUT_WORKSHOP)", set(), "«Workshop», never «Forge»"),
    ("might-sila", r"(?<![\w’])[Сс]ил[аиуі](?![\w])(?!\s+(ульти|героя|кличу|удару))", "uk", "heroes", None, set(),
     "the power index is «Міць» (Сила = the in-run «Сила героя» gates)"),
    ("might-power", r"(?<![Uu]lt )(?<![Hh]ero )\bPower\b", "en", "heroes", None, set(), "the power index is «Might» in en"),
    ("recut-ascend", r"[Пп]іднесен|[Вв]ознесін|(?<![\w’])[Сс]ходжен|[Aa]scen", "both", "heroes", None, set(), "a gem promotion is «Огранка / Recut» (Піднесення = machine Ascension)"),
    ("facets-stars", r"[Зз]ірк[аиоу]|\bStars?\b", "both", "heroes", r"^(FACET_|RECUT_|TUT_FACETS|CER_FULL)", set(), "facets are «Грані», stars stay reserved for star-shards"),
    ("tome-book", r"[Кк]ниг[аиу]|\bBooks?\b", "both", "heroes", r"^(CUR_TOME|SKL_|REWRITE_|TUT_SKILLS)", set(), "Tomes are «Томи / Tomes»"),
    ("beacon-ticket", r"[Кк]вит(ок|ки|ків)|\b[Tt]ickets?\b", "both", "all", None, set(), "the Portal currency is «Маяки / Beacons»"),
    ("native-ridnyi", r"(?<![\w’])[Рр]ідн(ий|ого|их|і|им)(?![\w])", "uk", "heroes", None, set(), "the birth gem is «Корінний»"),
    ("gear-ekip", r"[Ее]кіпіров|[Аа]мунці", "uk", "heroes", None, set(), "gear is «Спорядження»"),
    ("seal-pechat-live", r"[Пп]ечат[ьі](?!\w)|[Пп]ечаттю", "uk", "live", None, set(), "the Rune status is «Тавро / Brand»; «Печатка» = the Portal Seal"),
    ("seal-en-live", r"\bSeals?\b", "en", "live", None, None, "en «Seal» is the Portal currency only (the status is «Brand»)"),
    ("rarity-retired-uk", r"[Зз]вичайн|[Рр]ідкісн|[Ее]пічн|[Лл]егендарн|[Мм]іфічн", "uk", "live", None, set(),
     "machine rarities adopt the gem names (§15 Q5): Кварц · Сапфір · Аметист · Топаз · Опал"),
    ("rarity-retired-en", r"\b(Commons?|Rares?|Epics?|Legendar(y|ies)|Mythics?)\b", "en", "live", None, set(),
     "machine rarities adopt the gem names in en: Quartz · Sapphire · Amethyst · Topaz · Opal"),
    ("awakening-skill-live", r"[Пп]робуджен|[Aa]waken", "both", "live", None, None, "«Пробудження / Awakening» is the fourth hero skill only (MS_AWAKEN retires)"),
    ("glory-live", r"(?<![\w])Слав[аиу](?![\w])|\bGlory\b|◆", "both", "live", None, {"MIGRATION_HEROES_ORE"}, "Glory ◆ retires with the heroes release"),
    ("soldier-voin", r"(?<![\w’])воїн(и|ів|ам|ами|ах|а|ові)?(?![\w’])", "uk", "live", r"^(?!.*_LORE$)", {"SYN_PAIR_WARRIOR"},
     "army soldiers are «солдати» («Воїн» is the Warrior class; lore prose may say «воїн»)"),
    ("ore-materials", r"[Мм]атеріал|\bMaterials?\b", "both", "heroes", r"^(WORKSHOP_|CUR_ORE|GEAR_)", set(), "one material: «Зоряна руда / Star Ore»"),
]
# "allowed keys" = None above means: allowed only in heroes-block keys (computed at run time).

# Keys of the shipped (2.2.1) table that already print a literal percentage; nothing new joins this list.
LEGACY_PCT = {
    "UPGRADE_POWER_DESC",
    "TAL_TEMPERED_DESC",
    "TAL_LONG_BARREL_DESC",
    "TAL_HAIR_TRIGGER_DESC",
    "TAL_DEEP_COLD_DESC",
    "TAL_WIDE_SPRAY_DESC",
    "TAL_BRITTLE_DESC",
    "TAL_WIDE_BLOOM_DESC",
    "TAL_LONG_LINK_DESC",
    "TAL_PAINT_TARGET_DESC",
    "TAL_RESONANCE_DESC",
    "TAL_WIDE_FIELD_DESC",
    "FOCUS_DESC",
    "ODDS_WILD",
    "ODDS_FOCUS",
}
# Heroes-block keys that may hold a literal digit (fixed UI labels, never a balance number).
DIGIT_OK = {"PORTAL_X1", "PORTAL_X10", "PORTAL_WELCOME", "PORTAL_ODDS_ONE_IN", "SHOW_3D", "SUMMON_X1", "SUMMON_X10"}

# Emoji: anything >= U+1F000, joiners / selectors, and the U+2600-27BF block except these text symbols.
TEXT_SYMBOLS = set("★◆▲▶◎✓→←↑↓·…×−–—≤≥«»№")

# Deliberate departures from the design doc's names (Loc owner, glossary rule "one name per thing").
RENAMES = {
    # §6.8 Vartan form IV «Обвал / Landslide» collides with Горан's Attack beat 6 «Обвал / Rockslide».
    "ULT_VARTAN_F4": ("Зсув", "Landslide"),
    # §3.4 Stoneheart 4-piece «Кам'яна шкіра / Stoneskin» collides with Горан's Rally «Кам'яна шкіра / Stone Skin».
    "GEAR_SET_STONEHEART": ("Гранітна шкіра", "Granite Skin"),
}

# Name families for the "one display name per thing" check. A key belongs to the first family whose regex matches.
NAME_FAMILIES = [
    ("machine", r"^M_[A-Z_]+$"),
    ("weapon", r"^W_[A-Z_]+$"),
    ("hero", r"^HERO_[A-Z]+$"),
    ("hero_title", r"^HERO_[A-Z]+_TITLE$"),
    ("champion", r"^CHAMP_[A-Z]+$"),
    ("champion_title", r"^CHAMP_[A-Z]+_TITLE$"),
    ("champion_role", r"^CHAMP_[A-Z]+_ROLE$"),
    ("ult", r"^ULT_[A-Z]+$"),
    ("ult_form", r"^ULT_[A-Z]+_F[2-5]$"),
    ("attack", r"^ATK_[A-Z]+$"),
    ("attack_beat", r"^ATK_[A-Z]+_B[369]$"),
    ("rally", r"^RALLY_[A-Z]+$"),
    ("awakening", r"^AWK_[A-Z]+$"),
    ("relic", r"^RELIC_[A-Z]+$"),
    ("gear", r"^GEAR_(DAWN|WILDFANG|STONEHEART|CELESTIAL)_(WEAPON|ARMOUR|CHARM)$"),
    ("gear_set", r"^GEAR_SET_[A-Z]+$"),
    ("action", r"^ACT_[A-Z]+$"),
    ("class", r"^CLASS_[A-Z]+$"),
    ("faction", r"^FACTION_[A-Z]+$"),
    ("family", r"^FAM_[A-Z]+$"),
    ("gem", r"^GEM_[CRELM]$"),
    ("form", r"^FORM_[CRELM]$"),
    ("currency", r"^CUR_[A-Z]+$"),
    ("cache", r"^CACHE_[A-Z]+$"),
    ("talent", r"^TAL_[A-Z_]+(?<!_DESC)$"),
    ("ascension", r"^ASC_[A-Z_]+(?<!_DESC)$"),
    ("status", r"^ST_[A-Z]+$"),
]
# Pairs of families that may share a display name because they name the same thing.
NAME_ALIASES = [
    {"machine", "weapon"},          # in-run weapon card = the machine
    {"gem", "rarity"},              # RAR_* adopts the gem names in LIVE
]
# Individual key pairs allowed to share a name (same thing, two keys).
NAME_SAME = [
    {"ATK_SEER", "ASP_FORESIGHT"},
]

# Unlock / bundle line keys the heroes rows print (a missing one is an error; other rows' lines only warn).
REQUIRED_LINES = {"UNL_CHAMPIONS", "UNL_PORTAL", "UNL_SKILLS", "UNL_WORKSHOP", "UNL_SLOT3", "GUEST_SEER_RETURN",
                  "MIGRATION_HEROES_CARD"}

PLACEHOLDER = re.compile(r"%(?:%|[-+0]*\d*(?:\.\d+)?[dsfixXcv])")


def die(msg: str) -> None:
    print("loc_lint: " + msg, file=sys.stderr)
    sys.exit(2)


# ------------------------------------------------------------------------------------------------ parsing

STR_LIT = r'"((?:[^"\\]|\\.)*)"'
ROW = re.compile(r'"([A-Za-z][A-Za-z0-9_\-]*)"\s*:\s*\[\s*' + STR_LIT + r'\s*(?:,\s*' + STR_LIT + r'\s*)?(?:,\s*' + STR_LIT + r'\s*)?\]')


def unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "n":
                out.append("\n"); i += 2; continue
            if n == "t":
                out.append("\t"); i += 2; continue
            if n == "u" and i + 5 < len(s):
                out.append(chr(int(s[i + 2:i + 6], 16))); i += 6; continue
            out.append(n); i += 2; continue
        out.append(c); i += 1
    return "".join(out)


class Table:
    def __init__(self, name: str):
        self.name = name
        self.rows: dict[str, list[str]] = {}
        self.line: dict[str, int] = {}
        self.dupes: list[tuple[str, int]] = []
        self.shape: list[tuple[str, int, int]] = []


def parse_dict(src: str, const_name: str) -> tuple[Table, set[str]]:
    """Rows of `const <name> := { ... }` (closed by a line that is exactly '}'), plus the keys between the
    HEROES BEGIN / END markers."""
    t = Table(const_name)
    heroes: set[str] = set()
    lines = src.split("\n")
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^const " + const_name + r"\s*(:=|:\s*Dictionary\s*=)\s*\{", ln):
            start = i
            break
    if start is None:
        return t, heroes
    in_heroes = False
    for i in range(start + 1, len(lines)):
        ln = lines[i]
        if ln.strip() == "}":
            break
        s = ln.strip()
        if s.startswith(HEROES_BEGIN):
            in_heroes = True
            continue
        if s.startswith(HEROES_END):
            in_heroes = False
            continue
        if s.startswith("#") or not s:
            continue
        for m in ROW.finditer(ln):
            key = m.group(1)
            vals = [unescape(v) for v in m.groups()[1:] if v is not None]
            if key in t.rows:
                t.dupes.append((key, i + 1))
            t.rows[key] = vals
            t.line[key] = i + 1
            if in_heroes:
                heroes.add(key)
    return t, heroes


def table_rows(path: str) -> dict[str, tuple[list[str], int]]:
    """Every '"KEY": ["uk", "en"]' row of any GDScript file (screen-local tables)."""
    out = {}
    try:
        src = open(path, encoding="utf8").read()
    except OSError:
        return out
    for i, ln in enumerate(src.split("\n")):
        for m in ROW.finditer(ln):
            vals = [unescape(v) for v in m.groups()[1:] if v is not None]
            if len(vals) == 2 and re.match(r"^[A-Z][A-Z0-9_\-]+$", m.group(1)):
                out[m.group(1)] = (vals, i + 1)
    return out


# ------------------------------------------------------------------------------------------------ checks

class Lint:
    def __init__(self, quiet: bool):
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.quiet = quiet
        self.counts: dict[str, int] = {}

    def err(self, check: str, msg: str) -> None:
        self.errors.append("ERROR [%s] %s" % (check, msg))
        self.counts[check] = self.counts.get(check, 0) + 1

    def warn(self, check: str, msg: str) -> None:
        self.warnings.append("warn  [%s] %s" % (check, msg))


def placeholders(s: str) -> list[str]:
    return [p for p in PLACEHOLDER.findall(s) if p != "%%"]


def is_emoji(ch: str) -> bool:
    cp = ord(ch)
    if ch in TEXT_SYMBOLS:
        return False
    return cp >= 0x1F000 or cp in (0xFE0F, 0x200D, 0x20E3) or 0x2600 <= cp <= 0x27BF or 0x2B00 <= cp <= 0x2BFF


def check_rows(L: Lint, t: Table) -> None:
    for key, ln in t.dupes:
        L.err("rows", "%s: key %s appears twice (line %d)" % (t.name, key, ln))
    for key, vals in t.rows.items():
        if len(vals) != 2 or any(v.strip() == "" for v in vals):
            L.err("rows", "%s: %s (line %d) needs exactly two non-empty strings [uk, en]" % (t.name, key, t.line[key]))


def check_format(L: Lint, t: Table, base: Table | None) -> None:
    for key, vals in t.rows.items():
        if len(vals) != 2:
            continue
        pu, pe = placeholders(vals[0]), placeholders(vals[1])
        if pu != pe:
            L.err("format", "%s: %s uk %s != en %s" % (t.name, key, pu, pe))
        if base is not None:
            if key not in base.rows:
                L.err("format", "%s: %s overrides a key that STRINGS does not have" % (t.name, key))
            elif placeholders(base.rows[key][0]) != pu:
                L.err("format", "%s: %s %s != the base row's %s (callers do not change with the phase)"
                      % (t.name, key, pu, placeholders(base.rows[key][0])))


def check_text(L: Lint, rows: dict[str, list[str]], heroes_keys: set[str], label: str) -> None:
    for key, vals in rows.items():
        for li, v in enumerate(vals):
            lang = ("uk", "en")[min(li, 1)]
            bad = sorted({c for c in v if is_emoji(c)})
            if bad:
                L.err("emoji", "%s %s.%s: emoji code points %s" % (label, key, lang, " ".join("U+%04X" % ord(c) for c in bad)))
            if re.search(r"\d[   ]?%(?![%ds])", v) and key not in LEGACY_PCT:
                L.err("percent", "%s %s.%s: literal number before %% in «%s» (use a %%s template filled from data)" % (label, key, lang, v))
            if key in heroes_keys and key not in DIGIT_OK and re.search(r"[0-9]", PLACEHOLDER.sub("", v)):
                L.err("percent", "%s %s.%s: literal digit in a heroes string «%s» (numbers come from data)" % (label, key, lang, v))
            if lang == "uk":
                if re.search(r"[А-Яа-яІіЇїЄєҐґ]['ʼ`][А-Яа-яІіЇїЄєҐґ]", v):
                    L.err("apostrophe", "%s %s: use ’ (U+2019) in «%s»" % (label, key, v))
            if v != v.strip() or "  " in v.replace("\n", ""):
                L.err("rows", "%s %s.%s: stray spaces in «%s»" % (label, key, lang, v))
            if key.endswith(("_DESC", "_VALUE")) and len(v) > 90:
                L.err("length", "%s %s.%s: %d characters (max 90)" % (label, key, lang, len(v)))
            if key.startswith(("TUT_", "HINT_")) and key in heroes_keys and len(v) > 60:
                L.err("length", "%s %s.%s: %d characters (max 60, part U §5.4)" % (label, key, lang, len(v)))


def check_forbidden(L: Lint, shipped: dict, live: dict, heroes_keys: set[str]) -> None:
    for name, rx, lang, where, scope, allowed, why in FORBIDDEN:
        pat = re.compile(rx)
        if where == "heroes":
            tables = [("SHIPPED", {k: v for k, v in shipped.items() if k in heroes_keys}),
                      ("LIVE", {k: v for k, v in live.items() if k in heroes_keys})]
        elif where == "live":
            tables = [("LIVE", live)]
        else:
            tables = [("SHIPPED", {k: v for k, v in shipped.items() if k in heroes_keys}), ("LIVE", live)]
        ok = heroes_keys if allowed is None else allowed
        seen = set()
        for label, rows in tables:
            for key, vals in rows.items():
                if (scope and not re.search(scope, key)) or key in ok:
                    continue
                for li, v in enumerate(vals[:2]):
                    if (lang == "uk" and li != 0) or (lang == "en" and li != 1):
                        continue
                    m = pat.search(v)
                    if m and (key, li) not in seen:
                        seen.add((key, li))
                        L.err("glossary", "%s %s.%s «%s» (%s): %s" % (label, key, ("uk", "en")[li], m.group(0), name, why))


def check_glossary_keys(L: Lint, live: dict) -> None:
    for key, (uk, en) in GLOSSARY_KEYS.items():
        if key not in live:
            L.err("glossary", "LIVE %s missing (glossary name «%s / %s»)" % (key, uk, en))
        elif live[key][0] != uk or live[key][1] != en:
            L.err("glossary", "LIVE %s = «%s / %s», the glossary says «%s / %s»" % (key, live[key][0], live[key][1], uk, en))


def family_of(key: str) -> str | None:
    if re.match(r"^RAR_[A-Z]+$", key):
        return "rarity"
    for fam, rx in NAME_FAMILIES:
        if re.match(rx, key):
            return fam
    return None


def check_names(L: Lint, rows: dict, label: str) -> None:
    by_name: dict[tuple[int, str], list[tuple[str, str]]] = {}
    for key, vals in rows.items():
        fam = family_of(key)
        if fam is None or len(vals) != 2:
            continue
        for li in (0, 1):
            n = vals[li].strip().rstrip("!").strip().lower().replace("'", "’")
            if "%" in n:
                continue
            by_name.setdefault((li, n), []).append((fam, key))
    for (li, n), owners in sorted(by_name.items()):
        if len(owners) < 2:
            continue
        fams = {f for f, _ in owners}
        keys = {k for _, k in owners}
        if len(fams) == 1 and len(keys) > 1 and next(iter(fams)) not in ("machine", "weapon", "gem", "rarity"):
            # two keys of one family with one name = two things with one name
            pass
        elif any(fams <= a for a in NAME_ALIASES) or any(keys <= s for s in NAME_SAME):
            continue
        elif len(fams) == 1 and next(iter(fams)) in ("machine", "weapon"):
            continue
        L.err("names", "%s «%s» (%s) names %d things: %s" % (label, n, ("uk", "en")[li], len(keys),
                                                            ", ".join(sorted(keys))))


# ------------------------------------------------------------------------------------------------ doc + roster

def norm_doc(s: str) -> str:
    s = s.strip().replace("'", "’")
    return s


def doc_names(doc: str) -> dict[str, tuple[str, str]]:
    """Expected Loc rows (key -> (uk, en)) read from heroes_design.md §6."""
    exp: dict[str, tuple[str, str]] = {}
    lines = doc.split("\n")
    # §6.0 hero table
    for ln in lines:
        # hero rows have 12 cells (any collector number: H26 Сірко joined after the champions), champion rows 10
        cells = ln.strip().strip("|").split("|")
        m = re.match(r"^\| \d\d \| `(\w+)` \| (.+?) / (.+?) \| (.+?) / (.+?) \| (Кварц|Сапфір|Аметист|Топаз|Опал) \|", ln) \
            if len(cells) == 12 else None
        if m:
            idu = m.group(1).upper()
            exp["HERO_" + idu] = (m.group(2), m.group(3))
            t_en = m.group(5)
            exp["HERO_" + idu + "_TITLE"] = (m.group(4), t_en[0].upper() + t_en[1:])
        m = re.match(r"^\| (\d\d) \| `(\w+)` \| (.+?) / (.+?) \| (.+?) / (.+?) \| (.+?) / (.+?) \| (Кварц|Сапфір|Аметист|Топаз) \|", ln) \
            if len(cells) == 10 else None
        if m:
            idu = m.group(2).upper()
            exp["CHAMP_" + idu] = (m.group(3), m.group(4))
            exp["CHAMP_" + idu + "_TITLE"] = (m.group(5), m.group(6))
            exp["CHAMP_" + idu + "_ROLE"] = (m.group(7), m.group(8))
    # hero sheets
    cur = None
    kind_ult = {}
    for ln in lines:
        m = re.match(r"^### 6\.\d+ H\d\d `(\w+)`", ln)
        if m:
            cur = ("H", m.group(1).upper())
            continue
        m = re.match(r"^### 6\.\d+ C\d\d `(\w+)`", ln)
        if m:
            cur = ("C", m.group(1).upper())
            continue
        if ln.startswith("### "):
            cur = None
            continue
        if not cur:
            continue
        idu = cur[1]
        if cur[0] == "H":
            m = re.match(r"^\| (Ult|Attack|Rally|Awakening|Relic)( `(\w+)`)?[^|]*\| (.+?) / (.+?) \| (.*) \|$", ln)
            if not m:
                continue
            k = m.group(1)
            nm = (m.group(4), m.group(5))
            rule = m.group(6)
            if k == "Ult":
                kind_ult[idu] = m.group(3)
                exp["ULT_" + idu] = nm
                for f in re.finditer(r"\*\*Form (II|III|IV|V) ([^*:—(]+?) / ([^*:(]+?)( \([^)]*\))?:\*\*", rule):
                    n = ["II", "III", "IV", "V"].index(f.group(1)) + 2
                    exp["ULT_%s_F%d" % (idu, n)] = (f.group(2).strip(), f.group(3).strip())
            elif k == "Attack":
                exp["ATK_" + idu] = nm
                for b in re.finditer(r"\*\*beat (\d) (.+?) / (.+?):?\*\*", rule):
                    exp["ATK_%s_B%s" % (idu, b.group(1))] = (b.group(2).strip(), b.group(3).strip().rstrip(":"))
            elif k == "Rally":
                exp["RALLY_" + idu] = nm
            elif k == "Awakening":
                exp["AWK_" + idu] = nm
            elif k == "Relic":
                exp["RELIC_" + idu] = nm
        else:
            m = re.match(r"^\| Twist — (.+?) / (.+?)( \(.*\))? \|", ln)
            if m:
                exp["ACT_" + idu] = (m.group(1).strip(), m.group(2).strip())
            m = re.match(r"^\| Relic (.+?) / (.+?) \|", ln)
            if m:
                exp["RELIC_" + idu] = (m.group(1).strip(), m.group(2).strip())
    # starters keep the Meta-1 ult keys (names checked through them, shout "!" ignored)
    for idu, kind in kind_ult.items():
        if idu in ("TITAN", "BOLT", "SEER"):
            exp["ULT_" + kind.upper()] = exp.pop("ULT_" + idu)
    # §6.23 gear
    sec = doc[doc.find("### 6.23"):doc.find("### 6.24")]
    for m in re.finditer(r"^\| `(\w+)` \| (.+?) / (.+?) \| (.+?) / (.+?) \| (.+?) / (.+?) \|$", sec, re.M):
        f = m.group(1).upper()
        for slot, a, b in (("WEAPON", 2, 3), ("ARMOUR", 4, 5), ("CHARM", 6, 7)):
            exp["GEAR_%s_%s" % (f, slot)] = (m.group(a), m.group(b))
    # §3.4 set names
    sec = doc[doc.find("**Faction sets**"):doc.find("Budget check")]
    fac = {"Орден Світанку": "DAWN", "Дикі Ікла": "WILDFANG", "Кам'яне Серце": "STONEHEART", "Небожителі": "CELESTIAL"}
    for m in re.finditer(r"^\| (.+?) \| .+? \| «(.+?) / (.+?)»", sec, re.M):
        if m.group(1) in fac:
            exp["GEAR_SET_" + fac[m.group(1)]] = (m.group(2), m.group(3))
    # §6.24 lore
    sec = doc[doc.find("### 6.24"):doc.find("Champion en lore")]
    for m in re.finditer(r"^\| (\w+) \| (.+) \|$", sec, re.M):
        if m.group(1) == "id":
            continue
        pre = "HERO_" if ("### 6." in doc and re.search(r"H\d\d `%s`" % m.group(1), doc)) else "CHAMP_"
        exp[pre + m.group(1).upper() + "_LORE"] = (m.group(2).replace(" / ", "\n"), "")
    seg = doc[doc.find("Champion en lore"):doc.find("**Skill-name keys:**")].replace("\n", " ")
    seg = seg[seg.find("**"):]
    for m in re.finditer(r"\*\*(\w+)\*\* (.*?)(?= \*\*\w+\*\* |$)", seg):
        k = "CHAMP_" + m.group(1).upper() + "_LORE"
        if k in exp:
            exp[k] = (exp[k][0], m.group(2).strip().replace(" / ", "\n"))
    flat = doc.replace("\n", " ")
    for m in re.finditer(r"### 6\.\d+ H\d\d `(\w+)`.*?\*\*Lore \(en\):\*\* (.*?)\s*\*\*Personality", flat):
        k = "HERO_" + m.group(1).upper() + "_LORE"
        if k in exp:
            exp[k] = (exp[k][0], "")   # hero en lore is prose on the sheet (rewritten as 3 lines in Loc)
    return {k: (norm_doc(u), norm_doc(e)) for k, (u, e) in exp.items()}


def check_doc(L: Lint, live: dict) -> None:
    if not os.path.exists(DOC):
        L.warn("doc", "heroes_design.md not found; doc check skipped")
        return
    doc = open(DOC, encoding="utf8").read()
    exp = doc_names(doc)
    for key, (uk, en) in sorted(exp.items()):
        if key in RENAMES:
            uk, en = RENAMES[key]
        if key not in live:
            L.err("doc", "LIVE %s missing (doc: «%s / %s»)" % (key, uk, en))
            continue
        got_uk, got_en = live[key][0], live[key][1]
        if key.startswith(("ULT_STORM", "ULT_QUAKE", "ULT_RIFT")):
            got_uk, got_en = got_uk.rstrip("!"), got_en.rstrip("!")
        if got_uk != uk:
            L.err("doc", "LIVE %s uk «%s» != doc «%s»" % (key, got_uk.replace("\n", " / "), uk.replace("\n", " / ")))
        if en and got_en.replace("’", "'") != en.replace("’", "'"):
            L.err("doc", "LIVE %s en «%s» != doc «%s»" % (key, got_en.replace("\n", " / "), en.replace("\n", " / ")))
    # §1.3 glossary table == GLOSSARY
    sec = doc[doc.find("### 1.3"):doc.find("### 1.4")]
    rows = re.findall(r"^\| ([^|]+?) \| ([^|]+?) \| ([^|]+?) \| ([^|]+?) \|$", sec, re.M)
    rows = [r for r in rows if r[0] not in ("en", "---")]
    clean = lambda s: re.sub(r"[*`]", "", s).replace(" (data)", "").strip()
    doc_rows = {clean(r[0]): clean(r[1]) for r in rows}
    for en, uk, _, _ in GLOSSARY:
        if doc_rows.get(en) != uk:
            L.err("doc", "glossary row %s: lint has «%s», §1.3 has «%s»" % (en, uk, doc_rows.get(en)))
    for en in doc_rows:
        if en not in {g[0] for g in GLOSSARY}:
            L.err("doc", "§1.3 row «%s» is not in loc_lint GLOSSARY" % en)


def check_coverage(L: Lint, live: dict) -> None:
    if not os.path.exists(ROSTER):
        L.warn("coverage", "heroes_roster.json not found; roster coverage skipped")
        return
    r = json.load(open(ROSTER, encoding="utf8"))
    gems = r["gems"]["keys"]
    need = []
    for g in gems:
        need += ["GEM_" + g, "GEM_%s_GEN" % g, "GEM_%s_PL" % g, "GEM_%s_ADJ" % g, "FORM_" + g, "GEM_CUT_" + g]
    starters_ult = {"titan": "ULT_QUAKE", "bolt": "ULT_STORM", "seer": "ULT_RIFT"}
    for hid in r["hero_order"]:
        h = r["heroes"][hid]
        u = hid.upper()
        need += ["HERO_" + u, "HERO_%s_TITLE" % u, "HERO_%s_LORE" % u, "ATK_" + u, "ATK_%s_DESC" % u,
                 "RALLY_" + u, "RALLY_%s_DESC" % u, "RALLY_%s_VALUE" % u, "AWK_" + u, "AWK_%s_DESC" % u,
                 "RELIC_" + u, "RELIC_%s_DESC" % u, "ULT_%s_DESC" % u, "ULT_%s_VALUE" % u]
        need.append(starters_ult.get(hid, "ULT_" + u))
        for b in r["atk_beats"]:
            need += ["ATK_%s_B%d" % (u, b), "ATK_%s_B%d_DESC" % (u, b)]
        for n in range(2, gems.index(h["native"]) + 2):
            need.append("ULT_%s_F%d_DESC" % (u, n))
        for k in ("class", "faction"):
            need.append(("CLASS_" if k == "class" else "FACTION_") + h[k].upper())
        need.append("FAM_" + h["element"].upper())
    for cid in r["champion_order"]:
        c = r["champions"][cid]
        u = cid.upper()
        need += ["CHAMP_" + u, "CHAMP_%s_TITLE" % u, "CHAMP_%s_ROLE" % u, "CHAMP_%s_LORE" % u,
                 "ACT_" + u, "ACT_%s_DESC" % u, "ACT_%s_VALUE" % u, "RELIC_" + u, "RELIC_%s_DESC" % u,
                 "ACT_" + c["class"].upper(), "ACT_%s_DESC" % c["class"].upper(),
                 "AURA_" + c["class"].upper(), "AURA_%s_VALUE" % c["class"].upper()]
    for f in r["factions"]:
        u = f.upper()
        need += ["FACTION_" + u, "SYN_" + u, "GEAR_SET_" + u]
        need += ["GEAR_%s_%s" % (u, s) for s in ("WEAPON", "ARMOUR", "CHARM")]
    # §12.4 named keys
    need += ["CUR_BEACON", "CUR_TOME", "CUR_ORE", "CUR_SEAL", "CUR_FRAGS", "PORTAL_WELCOME_RULE", "PORTAL_FOCUS_60",
             "UNL_CHAMPIONS", "UNL_PORTAL", "UNL_SKILLS", "UNL_WORKSHOP", "UNL_SLOT3", "MIGRATION_HEROES_CARD",
             "HINT_CHAMPION", "HINT_AURA", "HINT_CHAMP_BLOCK", "HINT_CHAMP_FALL", "GUEST_SEER_RETURN",
             "TUT_PORTAL_WELCOME", "TUT_FACETS_FIRST"]
    for fam in ("SEAL_", "PORTAL_", "CHEST_", "RECUT_", "FACET_", "AWAKEN_", "WORKSHOP_", "TEAM_", "SYNC_",
                "CHRONICLE_", "CODEX_", "REWRITE_", "TUT_", "SYN_PAIR_"):
        if not any(k.startswith(fam) for k in live):
            L.err("coverage", "no %s* key (heroes_design.md §12.4)" % fam)
    for k in need:
        if k not in live:
            L.err("coverage", "LIVE missing %s" % k)


def check_code(L: Lint, shipped: dict) -> None:
    keys = set(shipped)
    rx_call = re.compile(r'\bLoc\.(?:t|f)\(\s*"([A-Z][A-Z0-9_]+)"\s*[,)]')
    rx_line = re.compile(r'"line"\s*:\s*"([A-Z][A-Z0-9_]+)"')
    for base, _, files in os.walk(os.path.join(ROOT, "scripts")):
        for fn in files:
            if not fn.endswith(".gd") or fn == "loc.gd":
                continue
            p = os.path.join(base, fn)
            src = open(p, encoding="utf8").read()
            local = table_rows(p)
            for i, ln in enumerate(src.split("\n")):
                for m in rx_call.finditer(ln):
                    if m.group(1) not in keys and m.group(1) not in local:
                        L.err("code", "%s:%d Loc key %s does not exist" % (os.path.relpath(p, ROOT), i + 1, m.group(1)))
                for m in rx_line.finditer(ln):
                    if m.group(1) not in keys:
                        (L.err if m.group(1) in REQUIRED_LINES else L.warn)("code", "%s:%d line key %s does not exist" % (os.path.relpath(p, ROOT), i + 1, m.group(1)))


def check_tables(L: Lint, shipped: dict, heroes_keys: set[str]) -> None:
    ui = os.path.join(ROOT, "scripts")
    for base, _, files in os.walk(ui):
        for fn in files:
            if not fn.endswith(".gd") or fn == "loc.gd":
                continue
            p = os.path.join(base, fn)
            rel = os.path.relpath(p, ROOT)
            heroes_screen = rel.startswith(("scripts/ui/heroes/", "scripts/ui/summon/"))
            for key, (vals, ln) in table_rows(p).items():
                if key not in shipped:
                    continue
                if placeholders(vals[0]) != placeholders(shipped[key][0]):
                    L.err("tables", "%s:%d %s has placeholders %s, Loc has %s" % (rel, ln, key, placeholders(vals[0]),
                                                                                  placeholders(shipped[key][0])))
                if not heroes_screen and key not in heroes_keys and list(vals) != list(shipped[key]):
                    L.err("tables", "%s:%d %s shadows Loc with other text (changes shipped copy)" % (rel, ln, key))
                if not heroes_screen and key in heroes_keys and list(vals) != list(shipped[key]):
                    L.err("tables", "%s:%d %s: a new heroes key shadows this screen's own text «%s»" % (rel, ln, key, vals[0]))


def check_fonts(L: Lint, rows_list: list[tuple[str, dict]]) -> None:
    try:
        from fontTools.ttLib import TTFont  # type: ignore
    except ImportError:
        cmaps = []
        for p in FONTS:
            cmaps.append(read_cmap(p))
    else:
        cmaps = [set(TTFont(p).getBestCmap().keys()) for p in FONTS]
    missing: dict[str, set[str]] = {}
    for label, rows in rows_list:
        for key, vals in rows.items():
            for v in vals:
                for c in v:
                    if c in "\n\t":
                        continue
                    if any(ord(c) not in cm for cm in cmaps):
                        missing.setdefault(c, set()).add(label + " " + key)
    for c, keys in sorted(missing.items()):
        L.err("fonts", "U+%04X «%s» (%s) is missing from M PLUS Rounded 1c: %s" % (
            ord(c), c, unicodedata.name(c, "?"), ", ".join(sorted(keys)[:6]) + (" …" if len(keys) > 6 else "")))


def read_cmap(path: str) -> set[int]:
    """Minimal TrueType cmap reader (format 4 and 12) for machines without fontTools."""
    import struct
    data = open(path, "rb").read()
    num = struct.unpack(">H", data[4:6])[0]
    off = None
    for i in range(num):
        tag, _, o, _ = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        if tag == b"cmap":
            off = o
    out: set[int] = set()
    if off is None:
        return out
    n = struct.unpack(">H", data[off + 2:off + 4])[0]
    for i in range(n):
        pid, eid, so = struct.unpack(">HHI", data[off + 4 + 8 * i:off + 12 + 8 * i])
        st = off + so
        fmt = struct.unpack(">H", data[st:st + 2])[0]
        if fmt == 4:
            segx2 = struct.unpack(">H", data[st + 6:st + 8])[0]
            seg = segx2 // 2
            ends = struct.unpack(">%dH" % seg, data[st + 14:st + 14 + segx2])
            starts = struct.unpack(">%dH" % seg, data[st + 16 + segx2:st + 16 + 2 * segx2])
            deltas = struct.unpack(">%dh" % seg, data[st + 16 + 2 * segx2:st + 16 + 3 * segx2])
            ro_pos = st + 16 + 3 * segx2
            ros = struct.unpack(">%dH" % seg, data[ro_pos:ro_pos + segx2])
            for s in range(seg):
                for c in range(starts[s], ends[s] + 1):
                    if c == 0xFFFF:
                        continue
                    if ros[s] == 0:
                        g = (c + deltas[s]) & 0xFFFF
                    else:
                        gp = ro_pos + 2 * s + ros[s] + 2 * (c - starts[s])
                        g = struct.unpack(">H", data[gp:gp + 2])[0]
                        if g:
                            g = (g + deltas[s]) & 0xFFFF
                    if g:
                        out.add(c)
        elif fmt == 12:
            ng = struct.unpack(">I", data[st + 12:st + 16])[0]
            for j in range(ng):
                a, b, _ = struct.unpack(">III", data[st + 16 + 12 * j:st + 28 + 12 * j])
                out.update(range(a, b + 1))
    return out


def check_baseline(L: Lint, ref: str, shipped: dict, heroes_keys: set[str]) -> None:
    try:
        old = subprocess.run(["git", "-C", ROOT, "show", "%s:./scripts/autoload/loc.gd" % ref], capture_output=True,
                             text=True, check=True).stdout
    except subprocess.CalledProcessError as e:
        L.err("baseline", "git show %s failed: %s" % (ref, e.stderr.strip()))
        return
    base, _ = parse_dict(old, "STRINGS")
    for key, vals in base.rows.items():
        if key not in shipped:
            L.err("baseline", "SHIPPED %s removed (it is in %s)" % (key, ref))
        elif list(shipped[key]) != list(vals):
            L.err("baseline", "SHIPPED %s changed from «%s» (the shipped game must read as at %s)" % (key, vals[0], ref))
    added = [k for k in shipped if k not in base.rows and k not in heroes_keys]
    for k in added:
        L.err("baseline", "SHIPPED %s added outside the heroes block" % k)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--baseline", help="git ref whose STRINGS the shipped table must equal outside the heroes block")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--list-glossary", action="store_true")
    ap.add_argument("--loc", help="lint this loc.gd instead of scripts/autoload/loc.gd (tests)")
    a = ap.parse_args()
    if a.list_glossary:
        for row in GLOSSARY:
            print(" | ".join(row))
        return 0
    path = a.loc or LOC
    if not os.path.exists(path):
        die("missing " + path)
    src = open(path, encoding="utf8").read()
    strings, heroes_keys = parse_dict(src, "STRINGS")
    overlay, _ = parse_dict(src, "HEROES_LIVE")
    heroes_keys |= set(overlay.rows)
    L = Lint(a.quiet)
    shipped = dict(strings.rows)
    live = dict(shipped)
    live.update(overlay.rows)

    check_rows(L, strings)
    check_rows(L, overlay)
    check_format(L, strings, None)
    check_format(L, overlay, strings)
    check_text(L, shipped, heroes_keys - set(overlay.rows), "SHIPPED")
    check_text(L, overlay.rows, set(), "LIVE")
    check_forbidden(L, shipped, live, heroes_keys)
    check_glossary_keys(L, live)
    check_names(L, {k: v for k, v in shipped.items() if k not in heroes_keys}, "SHIPPED")
    check_names(L, live, "LIVE")
    check_doc(L, live)
    check_coverage(L, live)
    check_code(L, shipped)
    check_tables(L, shipped, heroes_keys)
    check_fonts(L, [("SHIPPED", shipped), ("LIVE", overlay.rows)])
    if a.baseline:
        check_baseline(L, a.baseline, shipped, heroes_keys)

    if not a.quiet:
        for w in L.warnings:
            print(w)
    for e in L.errors:
        print(e)
    n_chars = len({c for vals in live.values() for v in vals for c in v})
    print("LOC_LINT %s: %d keys shipped (%d in the heroes block), %d overlay rows, %d distinct characters, "
          "%d errors%s" % ("PASS" if not L.errors else "FAIL", len(shipped), len(heroes_keys - set(overlay.rows)),
                           len(overlay.rows), n_chars, len(L.errors),
                           (" (" + ", ".join("%s %d" % kv for kv in sorted(L.counts.items())) + ")") if L.errors else ""))
    return 1 if L.errors else 0


if __name__ == "__main__":
    sys.exit(main())
