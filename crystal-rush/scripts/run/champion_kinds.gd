class_name ChampionKinds
extends RefCounted
## Champion behaviour rules over a KindView (heroes design §4.2, §4.3, §10.4-10.5). Pure static,
## shared by Run and LevelSim like HeroKinds: Run and LevelSim own the soldiers, the hazards and
## the clash; they call the hooks below at the matching moments and the rules decide what the
## champions add, absorb or take. Nothing here touches nodes; VFX / SFX / HUD go through view.fx.
##
## Phase H2 = class templates (§4.3) with the action tier (I-IV) upgrades, plus each champion's
## twist (§6.11-6.27) as a TWISTS row: plain fields the class rules read (no per-id branches).
##
## A member (Champions.members, KindView.champions()) is a Dictionary made by member():
## {id, slot, class, element, gem, native, status, tier, mult, hp, hp_max, alive, action, aura, aura_effect,
##  radius, x, d, cd, acc, shots, pool, pool_cap, fed, shield, field_left, field_d, field_x, field_cd,
##  heal_cd, block_id, block_left, cleave_acc, kills, heals, blocks, dmg_taken,
##  tw, fight, foe_id, fight_cd, plant, plant_cd, plant_hit, rimed, rime_id, rime_left, teth_a, teth_b,
##  teth_left, circ_d, circ_x, circ_r, circ_left, circ_tick, cut_id, cut_left, cut, catch_cd, catch_id,
##  catch_left, saved, struct}
## x / d = the champion's place on the bridge (d = run distance, ahead = larger), set every step
## from the blob centre and its slot. `tw` = the champion's TWISTS row (shared, read-only); every
## other field is a scalar, so Champions.copy (a shallow duplicate per member) branches cleanly.
## `saved` = soldiers its Blocks, plants, rime, catches and circle cut spared, `struct` = damage it
## dealt to structures (dev tools: the budget table; not in the report).
##
## Hook order a view owner follows each step (Run._process, LevelSim.step):
##   step(view, members, dt)                 every step, after the army moved
##   hazard_loss_mult(members)               x every hazard / turret loss (Healer aura)
##   absorb_hazard(view, members, id, kind, lost, army, radius) on every hazard loss (Guardian Block,
##                                           Олена's rime)
##   absorb_turret(view, members, id, lost)  on every turret loss, before the Healer aura (Німб IV)
##   clash_loss_mult(members)                x the army's clash losses (Guardian aura, Менгір's circle)
##   clash_kill_mult(members)                x the foe's clash losses (Warrior aura)
##   tick_free(members)                      before a clash tick: true = this tick costs the army 0
##   cleave(members)                         per FIGHT_TICK in a clash: extra foe kills (Warrior)
##   clash_hit(view, members, hit, guardian_hero) per clash tick with the army alive: front share
##   absorb_tick(view, members, hit)         per clash tick at army 0: a champion takes it (true)
##   feed(members, n)                        every soldier lost (any cause): Healer revive pool
##   volley_mult(members) / volley_status(members)  army volleys (Ranger / Mage aura)

## view.fx events the rules send (Run: VFX / SFX / HUD medallions; LevelSim: counted). Data keys:
## leap {id, target, d, x, verb, targets} · shot {id, target, d, x, arrows, pierce, homing} ·
## spell {id, d, x, r} · block {id, hazard, kind, stamp} · mend {id, n, front} · heal {id, target, hp} ·
## hit {id, hp, hp_max} · down {id, slot, x, d} · revive {id} ·
## twist {id, twist, ...}: a twist's own moment (TWIST_FX lists each twist's keys).
const FX: Array[StringName] = [&"champ_leap", &"champ_shot", &"champ_spell", &"champ_block", &"champ_mend",
		&"champ_heal", &"champ_hit", &"champ_down", &"champ_revive", &"champ_twist"]

## champ_twist `twist` values and their data keys (the views draw them; the rules only report):
## undermine {target, d, x, burrow_s} (Борко: the dirt ridge, then the eruption at the target) ·
## cross {target, d, x, r} (Брант: the burning cross) · blades {target} (Брант: BURN on the clash squad) ·
## brazier {hazard} (Іво: the blocked barricade burns) · bartka {target, d, x,
## targets} (Довбуш: the throw and the return) · probe {target, d, x, reveal [ids]} (Тео) · harpoon
## {target, partner, d, x, s} (Дара: the tether) · lull {target, n, s} (Тая) · circle {d, x, r, s} (Менгір) ·
## pages {target, d, x} (Тарас) · plant {ticks} (Отто) · rod {targets [ids], d, x} (Німб) · charge {target,
## d, x} (Снаряд: "Гав — бум!") · catch {hazard} (Німб IV) · tonic {target, d, x} (Міла) · balm {n} (Олена) ·
## rime {n} (Олена: the rimed soldiers spare n at a hazard).
const TWIST_FX := &"champ_twist"

## Slot names in the conflict order of §4.2 (front -> rear -> left -> right).
const FRONT := &"front"
const LEFT := &"left"
const RIGHT := &"right"
const REAR := &"rear"
const SLOT_ORDER: Array[StringName] = [FRONT, REAR, LEFT, RIGHT]
## Who takes the clash ticks once the army is gone (§4.2): front -> left -> right -> rear.
const ABSORB_ORDER: Array[StringName] = [FRONT, LEFT, RIGHT, REAR]

## Class -> preferred slots (§4.2: Guardian / Warrior front, Ranger / Mage rear then right,
## Healer left / right). Classes are WS-A's TeamData ids.
const CLASS_SLOTS := {
	"guardian": [FRONT], "warrior": [FRONT],
	"ranger": [REAR, RIGHT], "mage": [REAR, RIGHT],
	"healer": [LEFT, RIGHT],
}

## Class templates (§4.3). Rates, radii and counts never scale with the ladder (kit identity);
## `action` (kills / damage / soldiers per pulse) arrives already x ladder x cl x relic.
const CLASS := {
	"warrior": {"cleave": 0.07, "leap_cd": 5.0, "leap_cd_iv": 4.0, "leap_range": 3.0, "leap_range_ii": 4.0,
			"leap_add_ii": 1.0, "lane": 1.0, "status_s": 2.0},
	"ranger": {"cd": 1.2, "range": 14.0, "lane": 1.6, "extra_every": 3, "proc_iii": 0.5, "pierce_every": 5,
			"pierce": 3, "status_s": 2.0},
	"mage": {"cd": 4.0, "cd_iv": 3.5, "range": 12.0, "lane": 2.5, "r": 1.5, "r_ii": 2.0, "struct_iii": 1.5,
			"field_s": 2.0, "field_every": 0.5, "field_kills": 1.0, "status_s": 2.0},
	"guardian": {"cd": 5.0, "r": 1.0, "r_ii": 1.4, "spare": 4.0, "shield_iii": 1.5, "barricade_iv": 5.0, "behind": 6.0},
	"healer": {"feed": 0.3, "cap": 30.0, "cap_iv": 1.5, "cd": 3.0, "cd_iv": 2.0, "add_ii": 1.0,
			"heal_cd": 15.0, "heal_frac": 0.1},
}

## Per-champion twists (§6.11-6.27): fields the class rules read; a champion without a row (or a
## stats row passing `twist: {}`, the dev tools' bare template) runs the class template alone.
## Fields marked "knob" were tuned in LevelSim (scripts/dev/test_champion_twists.gd: the budget table,
## §4.1 / §4.3 "twists are tuned inside +-3%" of the bare class template; owner decision 2026-10-09: a
## twist over the band is cut to it); the ratio follows, then the sheet's value measured the same way
## (Руді + Мейра pooled, levels 15-112 step 4, 50 runs).
## Counts, radii and durations never scale. LevelSim measures what its KindView records model: MARK, BURN
## and JOLT (expected values), holds (clash damage), tethers. CHILL, SEAL and STAGGER change nothing (as in
## the Run's Statuses); groundings and reveals need Flying / Phantom squads and a tether two squads <= 4 u
## apart, which LevelGen levels do not have: Борко, Альба, Дара and Тарас measure UNMEASURED (twist = no
## twist). The class templates measure far below §4.3's ~1.0 / s (owner decision: kept; the budget is
## re-computed from measured values later), so the twists that move clash losses keep only a small share.
##
## Every class: status (replaces the element status) · status_at [tiers] (the sheet's tiers that add
## the status before the template's tier III) · fight_status / fight_every / fight_s (a status on the
## squad in clash contact: once at each clash start when fight_every is 0, else every fight_every s).
## Warrior (the leap): verb (fx name) · no_flying · leap_targets · return (always leap_targets strikes: the
## return pass hits the first squad again) · reach / reach_ii · add_ii (x mult per
## squad from tier II) · cd / cd_iv · armored_first · path_r_iii (tier III: the status also on squads <= r
## of the path) · splash_r (the leap's status also on squads <= r of the target) · burrow_s (fx only).
## Ranger: flying_mult · flying_range · prefer_flying · homing (fx only) · probe_every / probe_status /
## probe_s / probe_reach · harpoon_every / tether_r / tether_share / tether_s / ground_s.
## Mage: target (&"nearest" | densest) · page_share / page_reach · lull_s / lull_strength (KindView.hold) ·
## circle_s / circle_s_iv / circle_cut / brand_s.
## Guardian: cd · bar / behind (x mult: the blocked barricade's damage / the kills on the squad behind;
## absent = action) · bar_fx · stamp · charge_reach / charge_status / charge_s (the Block's strike goes to
## the nearest squad instead) · charge_bar (x Action into a blocked barricade when no squad is near) ·
## rod_targets / rod_reach / rod_status (x action each) · plant_ticks / plant_cd / plant_share /
## plant_cut (the share of a planted tick the army is spared; absent = 1, the whole tick) ·
## catch_r / catch_cd / catch_tier (absorb_turret; no catch_cd = shares the Block cd).
## Healer (after a pulse that returned >= 1): pulse_status / pulse_s / pulse_reach / pulse_back /
## pulse_all · rime_cap / rime_per.
const TWISTS := {
	# §6.11 Міла — Тонік: a returning pulse MARKs the nearest squad <= 12 u (reveals Phantom). Knob pulse_s
	# 3 -> 0.15 s: 1.025 (3 s: 1.111; 0.5 s: 1.050; even one 0.05 s step: 1.016: the vial follows losses, so
	# it lands on the clash squad under the hero's fire).
	"mila": {"pulse_status": "mark", "pulse_s": 0.15, "pulse_reach": 12.0, "pulse_fx": &"tonic"},
	# §6.12 Іво — Жар: the blocked barricade takes his Action (1.4 x power, generated: knob 3 -> 1.4 through
	# heroes_tables.py) and burns (fx). 1.022 (Action 3: 1.109; the sheet's clash-start BURN alone is +38%,
	# and a BURN lasts at least its own 3 s, so it was cut; Action 3 + BURN: 1.489).
	"ivo": {"behind": 1.0, "bar_fx": &"brazier"},
	# §6.13 Борко — Підкоп: the leap is a burrow (never Flying) that erupts with STAGGER.
	"borko": {"verb": &"undermine", "no_flying": true, "status_at": [1], "burrow_s": 0.4},
	# §6.14 Альба — Крижана стріла: x1.5 vs Flying, 16 u vs Flying, prefers Flying, CHILL (proc 0.5) at II.
	"alba": {"flying_mult": 1.5, "flying_range": 16.0, "prefer_flying": true, "status_at": [2]},
	# §6.15 Отто — Панцир-фортеця: at a clash start (8 s apart) he plants: the first 2 ticks cost the army
	# plant_cut less (he takes that share x0.5). Knob plant_cut 1 -> 0.002: 1.020 (1, the whole tick: 10.71;
	# 0.01: 1.100; one whole tick once per level: 2.72). A tick costs ceil(min(army, foe) / 14) soldiers,
	# the template Block ~0.13 soldiers / s.
	"otto": {"plant_ticks": 2, "plant_cd": 8.0, "plant_share": 0.5, "plant_cut": 0.002},
	# §6.16 Тая — Пилок снів: squads hit are lulled 1.5 s (KindView.hold). Knob lull_strength 0.5 -> 0.004:
	# 1.023 (0.5: 3.877; 0.02: 1.115). The lull pays only when it lasts until the squad reaches the army
	# (lull_s <= 0.9 s: no effect, 1.0 s: 1.671 at 0.5), so the length stays and the strength is cut.
	"taya": {"lull_s": 1.5, "lull_strength": 0.004},
	# §6.17 Брант — Розжарені клинки: BURN on the clash squad; the leap's status also burns <= 1.5 u.
	"brant": {"fight_status": "burn", "fight_every": 1.0, "fight_s": 3.0, "fight_fx": &"blades", "splash_r": 1.5},
	# §6.18 Тео — Зоряний зонд: homing; every 4th shot is a probe (MARK 3 s, reveals Phantom <= 14 u).
	"teo": {"homing": true, "probe_every": 4, "probe_status": "mark", "probe_s": 3.0, "probe_reach": 14.0},
	# §6.19 Олена — Морозний бальзам: a pulse CHILLs squads <= 2 u of the army front; returns are rimed.
	# Knob rime_cap 3 -> 1: 1.024 (3: 1.051).
	"olena": {"pulse_status": "chill", "pulse_s": 1.5, "pulse_reach": 2.0, "pulse_back": 2.0, "pulse_all": true,
			"pulse_fx": &"balm", "rime_cap": 1.0, "rime_per": 1.0},
	# §6.20 Німб — Громовідвід: every Block chains 3 hostiles <= 5 u (his Action each + JOLT); IV a Block can
	# instead catch a turret shot (no catch_cd: it shares the Block cd, as the sheet). Knob catch_r 1.6 -> 1.3:
	# 1.011 (1.6: 1.042; with an own 5 s timer 1.014, at 1.6 1.048).
	"nimb": {"behind": 1.0, "bar": 1.0, "rod_targets": 3, "rod_reach": 5.0, "rod_status": "jolt",
			"catch_r": 1.3, "catch_tier": 4},
	# §6.21 Дара — Гарпун-блискавка: every 3rd shot tethers its squad to the nearest other <= 4 u
	# (KindView.tether: 50% of what either takes also hits the other).
	"dara": {"harpoon_every": 3, "tether_r": 4.0, "tether_share": 0.5, "tether_s": 3.0, "ground_s": 1.5},
	# §6.22 Менгір — Рунне коло: the strike carves a circle; squads in it are Branded and deal less clash
	# damage. Knob circle_cut 0.25 -> 0.003: 1.019 (0.25: 2.571; 0.01: 1.063): the circle's squad is
	# usually the next clash and every tick of it is cut (the circle's length and brand_s barely move it).
	"menhir": {"circle_s": 3.0, "circle_s_iv": 5.0, "circle_cut": 0.003, "brand_s": 3.0},
	# §6.25 Тарас — Слово: the book hits the NEAREST squad; its pages cut on into the next squad <= 3 u.
	"taras": {"target": &"nearest", "page_share": 0.5, "page_reach": 3.0},
	# §6.26 Снаряд — Нюх сапера: Block cd 6 s (knob); the defused charge (his Action) + MARK 3 s on the
	# nearest squad <= 6 u, instead of the template's +1 kill; the stamp reads «ЧИСТО!». Knob charge_bar 0.5
	# (no squad near: half the charge into the blocked barricade): 1.000 (none: 0.962, all: 1.038); the cd
	# does not move it (hazards stand > 8 s apart), and no squad stands <= 6 u of a Block in LevelGen levels.
	"snaryad": {"cd": 6.0, "charge_reach": 6.0, "charge_status": "mark", "charge_s": 3.0, "charge_bar": 0.5,
			"stamp": &"clear"},
	# §6.27 Довбуш — Бартка: instead of the leap, through the first 2 squads <= 6 u (his Action each +
	# STAGGER), the most armoured first; it spins back to his hand (one squad in range: the return strikes it
	# again, so a throw is always 2 x his Action, the sheet's budget); II + add_ii per squad and 7 u; III
	# STAGGER <= 1 u of the path. Knob add_ii 0.5 -> 0.15: 1.007 (0.5: 1.102; no return: 0.757).
	"dovbush": {"verb": &"bartka", "leap_targets": 2, "return": true, "reach": 6.0, "reach_ii": 7.0, "add_ii": 0.15,
			"armored_first": true, "path_r_iii": 1.0},
}

## Element -> the status it applies (ArsenalData.FAMILIES[element].status; rune = seal).
const ELEMENT_STATUS := {"kinetic": "stagger", "volt": "jolt", "frost": "chill", "plasma": "burn",
		"tech": "mark", "rune": "seal"}

const _NO_TWIST := {}

## Champion id -> kind row {class, slot, element}: ChampionData.CHAMPIONS (one table, WS-A).
static func row(id: String) -> Dictionary:
	return ChampionData.CHAMPIONS.get(id, {})


## The champion's twist row (TWISTS; empty for none).
static func twist(id: String) -> Dictionary:
	return TWISTS.get(id, _NO_TWIST)


## A run member from a team row (Meta._team_block: ChampionsMeta.stats + slot + aura_effect). A row may
## carry `twist` (a Dictionary): it replaces the TWISTS row (dev tools: `{}` = the bare class template).
static func member(st: Dictionary, slot: StringName) -> Dictionary:
	var cls := str(st.get("class", ""))
	var el := str(st.get("element", ""))
	var hp := float(st.get("hp", 0.0))
	var aura := minf(float(st.get("aura", 0.0)), ChampionData.AURA_CAP)
	var id := str(st.get("id", ""))
	var tw: Dictionary = st["twist"] if st.get("twist") is Dictionary else twist(id)
	var m := {"id": id, "slot": slot, "class": cls, "element": el,
			"gem": str(st.get("gem", st.get("native", "C"))), "native": str(st.get("native", "C")),
			"status": ELEMENT_STATUS.get(el, ""), "tier": int(st.get("tier", 1)), "mult": float(st.get("mult", 1.0)),
			"hp": hp, "hp_max": hp, "alive": hp > 0.0, "action": float(st.get("action", 0.0)), "aura": aura,
			"aura_effect": aura * float(ChampionData.AURA_SHARE.get(String(slot), 0.0)),
			"radius": float(st.get("radius", 1.0)), "x": 0.0, "d": 0.0, "cd": 0.0, "acc": 0.0, "shots": 0,
			"pool": 0.0, "pool_cap": 0.0, "fed": 0.0, "shield": 0.0, "field_left": 0.0, "field_d": 0.0, "field_x": 0.0,
			"field_cd": 0.0, "heal_cd": 0.0, "block_id": -1, "block_left": 0.0, "cleave_acc": 0.0,
			"kills": 0.0, "heals": 0.0, "blocks": 0, "dmg_taken": 0.0,
			"tw": tw, "fight": false, "foe_id": -1, "fight_cd": 0.0, "plant": 0, "plant_cd": 0.0, "plant_hit": false,
			"rimed": 0.0, "rime_id": -1, "rime_left": 0.0, "teth_a": -1, "teth_b": -1, "teth_left": 0.0,
			"circ_d": 0.0, "circ_x": 0.0, "circ_r": 0.0, "circ_left": 0.0, "circ_tick": 0.0, "cut_id": -1,
			"cut_left": 0.0, "cut": 0.0, "catch_cd": 0.0, "catch_id": -1, "catch_left": 0.0, "saved": 0.0,
			"struct": 0.0}
	if tw.has("status"):
		m["status"] = str(tw["status"])
	if cls == "healer":
		var c: Dictionary = CLASS["healer"]
		m["pool_cap"] = float(c["cap"]) * float(m["mult"]) * (float(c["cap_iv"]) if int(m["tier"]) >= 4 else 1.0)
		m["cd"] = _healer_cd(m)
		m["heal_cd"] = float(c["heal_cd"])
	return m


## Forgets every target a member holds by id (a Block in progress, the clash foe, a rimed squad, a
## tether, a cut, a turret catch). For a copy whose ids mean other items (the bot's planner snapshot
## re-indexes the Run's items): timers and pools stay.
static func drop_refs(m: Dictionary) -> void:
	for k: String in m:
		if k.ends_with("_id") or k in ["teth_a", "teth_b"]:
			m[k] = -1
		elif k == "block_left" or k in ["rime_left", "teth_left", "cut_left", "catch_left"]:
			m[k] = 0.0
	m["fight"] = false


## Places `members` ([{id, class}] in team order) on the slots: each takes its first free
## preferred slot, else the first free slot in SLOT_ORDER. Returns id -> slot. Empty while the
## champions phase is off or `count` is 0.
static func assign_slots(members: Array, count: int) -> Dictionary:
	var out := {}
	if not HeroKinds.champions_live() or count <= 0:
		return out
	var free: Array[StringName] = SLOT_ORDER.duplicate()
	for m: Dictionary in members.slice(0, count):
		var pick: StringName = &""
		var want: Array = []
		if m.has("slot") and str(m["slot"]) != "":
			want.append(StringName(str(m["slot"])))
		want.append_array(CLASS_SLOTS.get(str(m.get("class", "")), []))
		for sl: StringName in want:
			if sl in free:
				pick = sl
				break
		if pick == &"" and not free.is_empty():
			pick = free[0]
		if pick != &"":
			free.erase(pick)
			out[str(m["id"])] = pick
	return out


## Offset of `slot` from the blob centre for a blob of radius `r` (§4.2 contract, `r' = max(r,
## 0.6)`; x = across the bridge, y = along the run, + = behind the centre).
static func slot_offset(slot: StringName, r: float) -> Vector2:
	var rr := maxf(r, 0.6)
	match slot:
		FRONT:
			return Vector2(0.0, -0.63 * rr)
		LEFT:
			return Vector2(-0.55 * rr, 0.1 * rr)
		RIGHT:
			return Vector2(0.55 * rr, 0.1 * rr)
		REAR:
			return Vector2(0.0, 0.69 * rr)
	return Vector2.ZERO


static func living(members: Array) -> Array:
	return members.filter(func(m: Dictionary) -> bool: return bool(m["alive"]))


## The living member in `slot` ({} when empty or fallen).
static func in_slot(members: Array, slot: StringName) -> Dictionary:
	for m: Dictionary in members:
		if m["slot"] == slot and bool(m["alive"]):
			return m
	return {}


## True when the twist adds the champion's status at `tier` (template: from tier III; `status_at`
## lists the sheet's earlier tiers, e.g. Борко's STAGGER at I).
static func _status_on(m: Dictionary, tier: int) -> bool:
	if str(m["status"]) == "":
		return false
	if tier >= 3:
		return true
	var at: Variant = (m["tw"] as Dictionary).get("status_at")
	return at is Array and (at as Array).has(tier)


# ------------------------------------------------------------------ every step

## One step of every living champion: follow the blob, then its class Action. Places every member
## (fallen ones too, so a fallen model stays where it fell: only living ones move).
static func step(view: KindView, members: Array, dt: float) -> void:
	if members.is_empty():
		return
	# One snapshot of the army for the whole step (a Mend inside the loop changes it; a view may
	# refresh one shared dictionary in place).
	var a := view.army()
	var r := float(a["radius"])
	var ax := float(a["x"])
	var ad := float(a["d"])
	var fighting := view.in_fight()
	# The squad in clash contact, looked up once per step and only for a twist that needs it.
	var contact: Dictionary = {}
	var looked := false
	for m: Dictionary in members:
		if not bool(m["alive"]):
			continue
		var off := slot_offset(m["slot"], r)
		m["x"] = ax + off.x
		m["d"] = ad - off.y
		m["shield"] = maxf(float(m["shield"]) - dt, 0.0)
		var tw: Dictionary = m["tw"]
		if not tw.is_empty():
			if fighting and not looked and _needs_contact(tw):
				contact = _contact(view, a)
				looked = true
			_twist_step(view, m, tw, fighting, contact, dt)
		match str(m["class"]):
			"warrior":
				_warrior(view, m, dt)
			"ranger":
				_ranger(view, m, dt)
			"mage":
				_mage(view, m, dt)
			"guardian":
				m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
			"healer":
				_healer(view, members, m, dt)


static func _needs_contact(tw: Dictionary) -> bool:
	return tw.has("fight_status") or tw.has("plant_ticks") or tw.has("circle_cut")


## The squad in clash contact: the living squad nearest the hero's meeting point (CONTACT ahead of
## the hero) over the blob's width ({} in the siege or when none).
static func _contact(view: KindView, a: Dictionary) -> Dictionary:
	var r := float(a["radius"])
	var hd := float(a["d"]) + Balance.HERO_GAP + r * Balance.BLOB_STRETCH
	var x := float(a["x"])
	var best: Dictionary = {}
	var best_k := INF
	for s: Dictionary in view.squads_in(hd - 3.0, hd + Balance.CONTACT + 1.0, x - r - 0.5, x + r + 0.5):
		var k := absf(float(s["d"]) - hd - Balance.CONTACT)
		if k < best_k:
			best_k = k
			best = s
	return best


## The twist's per-step part: timers, the clash start (a new foe in contact, or the siege), the clash
## status (Іво, Брант), Отто's plant and Менгір's circle cut.
static func _twist_step(view: KindView, m: Dictionary, tw: Dictionary, fighting: bool, contact: Dictionary,
		dt: float) -> void:
	m["plant_cd"] = maxf(float(m["plant_cd"]) - dt, 0.0)
	m["catch_cd"] = maxf(float(m["catch_cd"]) - dt, 0.0)
	if float(m["teth_left"]) > 0.0:
		m["teth_left"] = float(m["teth_left"]) - dt
	if float(m["cut_left"]) > 0.0:
		m["cut_left"] = float(m["cut_left"]) - dt
	m["cut"] = 0.0
	if not fighting:
		m["fight"] = false
		m["foe_id"] = -1
		return
	var cid := int(contact.get("id", -1))
	var start := not bool(m["fight"]) or cid != int(m["foe_id"])
	m["fight"] = true
	m["foe_id"] = cid
	if tw.has("plant_ticks") and start and m["slot"] == FRONT and float(m["plant_cd"]) <= 0.0:
		m["plant"] = int(tw["plant_ticks"])
		m["plant_cd"] = float(tw.get("plant_cd", 8.0))
		view.fx(TWIST_FX, {"id": m["id"], "twist": &"plant", "ticks": int(m["plant"])})
	if cid < 0:
		return
	if tw.has("fight_status"):
		var every := float(tw.get("fight_every", 0.0))
		var due := start
		if not start and every > 0.0:
			m["fight_cd"] = float(m["fight_cd"]) - dt
			due = float(m["fight_cd"]) <= 0.0
		if due:
			m["fight_cd"] = every
			view.status(cid, StringName(str(tw["fight_status"])), float(tw.get("fight_s", 3.0)))
			view.fx(TWIST_FX, {"id": m["id"], "twist": tw.get("fight_fx", &"fight"), "target": cid})
	if tw.has("circle_cut") and cid == int(m["cut_id"]) and float(m["cut_left"]) > 0.0:
		m["cut"] = float(tw["circle_cut"])


static func _warrior(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["warrior"]
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if view.in_fight() or float(m["cd"]) > 0.0:
		return
	var tw: Dictionary = m["tw"]
	var tier := int(m["tier"])
	var reach := float(tw.get("reach_ii", c["leap_range_ii"])) if tier >= 2 else float(tw.get("reach", c["leap_range"]))
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var sq := view.squads_in(d, d + reach, x - lane, x + lane)
	if sq.is_empty():
		return
	if bool(tw.get("no_flying", false)):
		sq = sq.filter(func(s: Dictionary) -> bool: return not bool(s.get("flying", false)))
		if sq.is_empty():
			return
	if bool(tw.get("armored_first", false)):
		# "Robin Hood": the most armoured squad in range first, then by distance.
		sq.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			var pa := bool(p.get("armored", false))
			if pa != bool(q.get("armored", false)):
				return pa
			return float(p["d"]) < float(q["d"]))
	else:
		sq.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	var n_targets := mini(int(tw.get("leap_targets", 1)), sq.size())
	# The bartka's return: with fewer squads in range than it flies through, it strikes the first again
	# on its way back to his hand (always leap_targets hits).
	var strikes := int(tw.get("leap_targets", 1)) if bool(tw.get("return", false)) else n_targets
	var kills := float(m["action"]) + (float(tw.get("add_ii", c["leap_add_ii"])) * float(m["mult"]) if tier >= 2 else 0.0)
	var st := StringName(str(m["status"]))
	var with_status := _status_on(m, tier)
	var far := d
	for k in strikes:
		var t: Dictionary = sq[k % n_targets]
		m["kills"] = float(m["kills"]) + view.hit(int(t["id"]), kills, {"src": m["id"], "kind": &"leap"})
		far = maxf(far, float(t["d"]))
		if with_status:
			view.status(int(t["id"]), st, float(c["status_s"]))
	var first: Dictionary = sq[0]
	if with_status:
		var pr := float(tw.get("path_r_iii", 0.0)) if tier >= 3 else 0.0
		if pr > 0.0:
			# Tier III bartka: the status also catches squads <= pr of its path (to the farthest target).
			for s: Dictionary in view.squads_in(d, far, x - lane - pr, x + lane + pr):
				if not _among(sq, n_targets, int(s["id"])):
					view.status(int(s["id"]), st, float(c["status_s"]))
		var sr := float(tw.get("splash_r", 0.0))
		if sr > 0.0:
			# Брант's burning cross: the status on the squads <= sr of the target.
			var fd := float(first["d"])
			var fxx := float(first["x"])
			for s2: Dictionary in view.squads_in(fd - sr, fd + sr, fxx - sr, fxx + sr):
				if int(s2["id"]) != int(first["id"]):
					view.status(int(s2["id"]), st, float(c["status_s"]))
			view.fx(TWIST_FX, {"id": m["id"], "twist": &"cross", "target": int(first["id"]), "d": fd, "x": fxx, "r": sr})
	var verb: StringName = tw.get("verb", &"leap")
	view.fx(&"champ_leap", {"id": m["id"], "target": int(first["id"]), "d": float(first["d"]), "x": float(first["x"]),
			"verb": verb, "targets": n_targets})
	if verb != &"leap":
		view.fx(TWIST_FX, {"id": m["id"], "twist": verb, "target": int(first["id"]), "d": float(first["d"]),
				"x": float(first["x"]), "targets": n_targets, "burrow_s": float(tw.get("burrow_s", 0.0))})
	m["cd"] = float(tw.get("cd_iv", c["leap_cd_iv"])) if tier >= 4 else float(tw.get("cd", c["leap_cd"]))


## Books one hit on target row `t`: a squad's soldiers removed go to kills, a structure's damage to
## struct (dev tools: structure damage = soldiers its spikes or shots will not take).
static func _tally(m: Dictionary, t: Dictionary, dmg: float, got: int) -> void:
	if t.has("n"):
		m["kills"] = float(m["kills"]) + got
	else:
		m["struct"] = float(m["struct"]) + dmg


## True when squad `id` is one of the first `n` rows of `rows`.
static func _among(rows: Array, n: int, id: int) -> bool:
	for k in n:
		if int((rows[k] as Dictionary)["id"]) == id:
			return true
	return false


static func _ranger(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["ranger"]
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if float(m["cd"]) > 0.0:
		return
	var tw: Dictionary = m["tw"]
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var reach := float(c["range"])
	var fly_reach := float(tw.get("flying_range", reach))
	var targets: Array = []
	for s: Dictionary in view.squads_in(d - 0.5, d + maxf(reach, fly_reach), x - lane - 2.0, x + lane + 2.0):
		if float(s["d"]) <= d + reach or bool(s.get("flying", false)):
			targets.append(s)
	for h: Dictionary in view.hazards_in(d - 0.5, d + reach):
		if str(h["kind"]) != "blade" and absf(float(h["x"]) - x) <= lane + 2.0:
			targets.append(h)
	if targets.is_empty():
		return
	if bool(tw.get("prefer_flying", false)):
		targets.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			var pf := bool(p.get("flying", false))
			if pf != bool(q.get("flying", false)):
				return pf
			return float(p["d"]) < float(q["d"]))
	else:
		targets.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	var tier := int(m["tier"])
	var shot := int(m["shots"]) + 1
	m["shots"] = shot
	var count := 1
	if tier >= 4 and shot % int(c["pierce_every"]) == 0:
		count = int(c["pierce"])
	var arrows := 2 if tier >= 2 and shot % int(c["extra_every"]) == 0 else 1
	var with_status := _status_on(m, tier)
	var first: Dictionary = targets[0]
	var first_dmg := 0.0
	for a in arrows:
		for k in mini(count, targets.size()):
			var t: Dictionary = targets[k]
			var dmg := float(m["action"])
			if bool(t.get("flying", false)):
				dmg *= float(tw.get("flying_mult", 1.0))
			var tid := int(t["id"])
			_tally(m, t, dmg, view.hit(tid, dmg, {"src": m["id"], "kind": &"shot"}))
			if k == 0:
				first_dmg += dmg
			if with_status and t.has("n"):
				view.status(tid, StringName(str(m["status"])), float(c["status_s"]) * float(c["proc_iii"]))
	var fid := int(first["id"])
	var probe := int(tw.get("probe_every", 0))
	if probe > 0 and shot % probe == 0 and first.has("n"):
		_probe(view, m, tw, first)
	var harpoon := int(tw.get("harpoon_every", 0))
	if harpoon > 0 and shot % harpoon == 0 and first.has("n"):
		_harpoon(view, m, tw, first, first_dmg)
	view.fx(&"champ_shot", {"id": m["id"], "target": fid, "d": float(first["d"]), "x": float(first["x"]),
			"arrows": arrows, "pierce": count, "homing": bool(tw.get("homing", false))})
	m["cd"] = float(c["cd"])


## Тео's probe: MARKs its target and reveals the Phantom squads within probe_reach (fx: the view reveals).
static func _probe(view: KindView, m: Dictionary, tw: Dictionary, t: Dictionary) -> void:
	view.status(int(t["id"]), StringName(str(tw.get("probe_status", "mark"))), float(tw.get("probe_s", 3.0)))
	var reveal: Array = []
	var d := float(m["d"])
	for s: Dictionary in view.squads_in(d - 0.5, d + float(tw.get("probe_reach", 14.0)), -INF, INF):
		if bool(s.get("phantom", false)):
			reveal.append(int(s["id"]))
	view.fx(TWIST_FX, {"id": m["id"], "twist": &"probe", "target": int(t["id"]), "d": float(t["d"]), "x": float(t["x"]),
			"reveal": reveal})


## Дара's harpoon: the hit squad is tethered to the nearest other squad <= tether_r for tether_s
## (KindView.tether: tether_share of every damage either takes, from any source, also hits the other; the
## view applies it, so her later hits are never mirrored here). The harpoon shot itself landed before the
## tether: the partner takes tether_share of it at once, before the tether is made (else that share would
## bounce back). A Flying target is grounded for ground_s (KindView.ground).
static func _harpoon(view: KindView, m: Dictionary, tw: Dictionary, t: Dictionary, dmg: float) -> void:
	var tid := int(t["id"])
	var td := float(t["d"])
	var tx := float(t["x"])
	var tr := float(tw.get("tether_r", 4.0))
	var partner: Dictionary = {}
	var best := INF
	for s: Dictionary in view.squads_in(td - tr, td + tr, tx - tr, tx + tr):
		if int(s["id"]) == tid:
			continue
		var k := Vector2(float(s["x"]) - tx, float(s["d"]) - td).length()
		if k <= tr and k < best:
			best = k
			partner = s
	if bool(t.get("flying", false)):
		view.ground(tid, float(tw.get("ground_s", 1.5)))
	if partner.is_empty():
		return
	var pid := int(partner["id"])
	var share := float(tw.get("tether_share", 0.0))
	m["teth_a"] = tid
	m["teth_b"] = pid
	m["teth_left"] = float(tw.get("tether_s", 3.0))
	m["kills"] = float(m["kills"]) + view.hit(pid, dmg * share, {"src": m["id"], "kind": &"tether"})
	view.tether(tid, pid, share, float(m["teth_left"]))
	view.fx(TWIST_FX, {"id": m["id"], "twist": &"harpoon", "target": tid, "partner": pid, "d": td, "x": tx,
			"s": float(m["teth_left"])})


static func _mage(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["mage"]
	var tw: Dictionary = m["tw"]
	var tier := int(m["tier"])
	var rad := float(c["r_ii"]) if tier >= 2 else float(c["r"])
	# Tier IV: the field left by the last spell keeps killing.
	if float(m["field_left"]) > 0.0:
		m["field_left"] = float(m["field_left"]) - dt
		m["field_cd"] = float(m["field_cd"]) - dt
		while float(m["field_cd"]) <= 0.0 and float(m["field_left"]) > -dt:
			m["field_cd"] = float(m["field_cd"]) + float(c["field_every"])
			var fd := float(m["field_d"])
			var fx0 := float(m["field_x"])
			for s: Dictionary in view.squads_in(fd - rad, fd + rad, fx0 - rad, fx0 + rad):
				m["kills"] = float(m["kills"]) + view.hit(int(s["id"]), float(c["field_kills"]) * float(m["mult"]),
						{"src": m["id"], "kind": &"field"})
	if tw.has("circle_cut"):
		_circle_step(view, m, tw, dt)
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if float(m["cd"]) > 0.0:
		return
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var sq := view.squads_in(d, d + float(c["range"]), x - lane, x + lane)
	if sq.is_empty():
		return
	var best: Dictionary = {}
	if tw.get("target", &"") == &"nearest":
		# Тарас: the nearest squad, not the densest.
		for s0: Dictionary in sq:
			if best.is_empty() or float(s0["d"]) < float(best["d"]):
				best = s0
	else:
		# The densest squad = the most soldiers inside the spell radius around it.
		var best_n := -1.0
		for s: Dictionary in sq:
			var n := 0.0
			for o: Dictionary in sq:
				if absf(float(o["d"]) - float(s["d"])) <= rad and absf(float(o["x"]) - float(s["x"])) <= rad:
					n += float(o["n"])
			if n > best_n:
				best_n = n
				best = s
	var cd0 := float(best["d"])
	var cx0 := float(best["x"])
	var st := StringName(str(m["status"]))
	var lull := float(tw.get("lull_s", 0.0))
	var lulled := 0
	for s2: Dictionary in sq:
		if absf(float(s2["d"]) - cd0) <= rad and absf(float(s2["x"]) - cx0) <= rad:
			var sid := int(s2["id"])
			m["kills"] = float(m["kills"]) + view.hit(sid, float(m["action"]), {"src": m["id"], "kind": &"spell"})
			if st != &"":
				view.status(sid, st, float(c["status_s"]))
			if lull > 0.0:
				# Тая's lull: speed and clash damage x (1 - lull_strength) (the view's hold verb).
				view.hold(sid, lull, float(tw.get("lull_strength", 0.5)))
				lulled += 1
	var smult := float(c["struct_iii"]) if tier >= 3 else 1.0
	for h: Dictionary in view.hazards_in(cd0 - rad, cd0 + rad):
		if str(h["kind"]) != "blade" and absf(float(h["x"]) - cx0) <= rad:
			_tally(m, h, float(m["action"]) * smult, view.hit(int(h["id"]), float(m["action"]) * smult,
					{"src": m["id"], "kind": &"spell"}))
	view.fx(&"champ_spell", {"id": m["id"], "d": cd0, "x": cx0, "r": rad})
	if lulled > 0:
		view.fx(TWIST_FX, {"id": m["id"], "twist": &"lull", "target": int(best["id"]), "n": lulled, "s": lull})
	var field_d := cd0
	var field_x := cx0
	var ps := float(tw.get("page_share", 0.0))
	if ps > 0.0:
		var page := _pages(view, m, tw, sq, cd0, cx0, rad, ps)
		if not page.is_empty():
			field_d = float(page["d"])
			field_x = float(page["x"])
	if tw.has("circle_cut"):
		m["circ_d"] = cd0
		m["circ_x"] = cx0
		m["circ_r"] = rad
		var cs := float(tw.get("circle_s", 3.0))
		m["circ_left"] = float(tw.get("circle_s_iv", cs)) if tier >= 4 else cs
		m["circ_tick"] = 0.0
		view.fx(TWIST_FX, {"id": m["id"], "twist": &"circle", "d": cd0, "x": cx0, "r": rad, "s": float(m["circ_left"])})
		_circle_step(view, m, tw, 0.0)
	if tier >= 4:
		m["field_left"] = float(c["field_s"])
		m["field_cd"] = float(c["field_every"])
		m["field_d"] = field_d
		m["field_x"] = field_x
	m["cd"] = float(c["cd_iv"]) if tier >= 4 else float(c["cd"])


## Тарас's pages: the next squad behind the target (d beyond it, <= page_reach, in the throw line =
## the spell radius across) not already in the blast takes page_share of the kills and the status.
## Returns that squad ({} when none).
static func _pages(view: KindView, m: Dictionary, tw: Dictionary, sq: Array, cd0: float, cx0: float, rad: float,
		share: float) -> Dictionary:
	var page: Dictionary = {}
	for s: Dictionary in view.squads_in(cd0, cd0 + float(tw.get("page_reach", 3.0)), cx0 - rad, cx0 + rad):
		var sd := float(s["d"])
		if sd <= cd0 or (sd - cd0 <= rad and absf(float(s["x"]) - cx0) <= rad):
			continue
		if page.is_empty() or sd < float(page["d"]):
			page = s
	if page.is_empty():
		return page
	var pid := int(page["id"])
	m["kills"] = float(m["kills"]) + view.hit(pid, float(m["action"]) * share, {"src": m["id"], "kind": &"pages"})
	if str(m["status"]) != "":
		view.status(pid, StringName(str(m["status"])), float(CLASS["mage"]["status_s"]))
	view.fx(TWIST_FX, {"id": m["id"], "twist": &"pages", "target": pid, "d": float(page["d"]), "x": float(page["x"])})
	return page


## Менгір's circle: while it lasts, every 0.5 s the squads inside are Branded; the one nearest the army
## is remembered (cut_id) for brand_s, and while it is the clash foe the army loses x (1 - circle_cut).
static func _circle_step(view: KindView, m: Dictionary, tw: Dictionary, dt: float) -> void:
	if float(m["circ_left"]) <= 0.0:
		return
	m["circ_left"] = float(m["circ_left"]) - dt
	m["circ_tick"] = float(m["circ_tick"]) - dt
	if float(m["circ_tick"]) > 0.0:
		return
	m["circ_tick"] = 0.5
	var cd0 := float(m["circ_d"])
	var cx0 := float(m["circ_x"])
	var rr := float(m["circ_r"])
	var near: Dictionary = {}
	var bs := float(tw.get("brand_s", 3.0))
	for s: Dictionary in view.squads_in(cd0 - rr, cd0 + rr, cx0 - rr, cx0 + rr):
		if Vector2(float(s["x"]) - cx0, float(s["d"]) - cd0).length() > rr + 0.5:
			continue
		view.status(int(s["id"]), &"seal", bs)
		if near.is_empty() or float(s["d"]) < float(near["d"]):
			near = s
	if not near.is_empty():
		m["cut_id"] = int(near["id"])
		m["cut_left"] = bs


static func _healer_cd(m: Dictionary) -> float:
	var c: Dictionary = CLASS["healer"]
	return float(c["cd_iv"]) if int(m["tier"]) >= 4 else float(c["cd"])


static func _healer(view: KindView, members: Array, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["healer"]
	m["cd"] = float(m["cd"]) - dt
	if float(m["cd"]) <= 0.0:
		m["cd"] = float(m["cd"]) + _healer_cd(m)
		var per := float(m["action"]) + (float(c["add_ii"]) * float(m["mult"]) if int(m["tier"]) >= 2 else 0.0)
		var n := floorf(minf(float(m["pool"]), per))
		if n >= 1.0 and float(view.army()["n"]) >= 1.0:
			m["pool"] = float(m["pool"]) - n
			m["heals"] = float(m["heals"]) + n
			view.add_soldiers(n, &"mend")
			view.fx(&"champ_mend", {"id": m["id"], "n": n, "front": int(m["tier"]) >= 2})
			var tw: Dictionary = m["tw"]
			if not tw.is_empty():
				_pulse_twist(view, m, tw, n)
	if int(m["tier"]) >= 3:
		m["heal_cd"] = float(m["heal_cd"]) - dt
		if float(m["heal_cd"]) <= 0.0:
			m["heal_cd"] = float(c["heal_cd"])
			var f := in_slot(members, FRONT)
			if not f.is_empty():
				var add := minf(float(f["hp_max"]) * float(c["heal_frac"]), float(f["hp_max"]) - float(f["hp"]))
				f["hp"] = float(f["hp"]) + add
				view.fx(&"champ_heal", {"id": m["id"], "target": f["id"], "hp": add})


## After a pulse that returned `n`: the pulse's status (Міла's Tonic on the nearest squad ahead,
## Олена's Frost Balm on every squad <= pulse_reach of the army front) and Олена's rimed soldiers.
static func _pulse_twist(view: KindView, m: Dictionary, tw: Dictionary, n: float) -> void:
	if tw.has("rime_cap"):
		m["rimed"] = minf(float(m["rimed"]) + n, float(tw["rime_cap"]))
	if not tw.has("pulse_status"):
		return
	var a := view.army()
	var r := float(a["radius"])
	var front := float(a["d"]) + r * Balance.BLOB_STRETCH
	var x := float(a["x"])
	var st := StringName(str(tw["pulse_status"]))
	var sec := float(tw.get("pulse_s", 3.0))
	var sq := view.squads_in(front - float(tw.get("pulse_back", 0.0)), front + float(tw.get("pulse_reach", 12.0)),
			x - r - 2.0, x + r + 2.0)
	if sq.is_empty():
		return
	var fx_name: StringName = tw.get("pulse_fx", &"pulse")
	if bool(tw.get("pulse_all", false)):
		for s: Dictionary in sq:
			view.status(int(s["id"]), st, sec)
		view.fx(TWIST_FX, {"id": m["id"], "twist": fx_name, "n": sq.size()})
		return
	var near: Dictionary = sq[0]
	for s2: Dictionary in sq:
		if float(s2["d"]) < float(near["d"]):
			near = s2
	view.status(int(near["id"]), st, sec)
	view.fx(TWIST_FX, {"id": m["id"], "twist": fx_name, "target": int(near["id"]), "d": float(near["d"]),
			"x": float(near["x"])})


# ------------------------------------------------------------------ auras (living members only)

static func _aura_sum(members: Array, cls: String) -> float:
	var s := 0.0
	for m: Dictionary in members:
		if bool(m["alive"]) and str(m["class"]) == cls:
			s += float(m["aura_effect"])
	return s


## x the foe's clash losses: Warrior aura "squads in contact lose +x% in clashes".
static func clash_kill_mult(members: Array) -> float:
	return 1.0 + _aura_sum(members, "warrior")


## x the army's clash losses: Guardian aura "clash losses -x%"; x (1 - circle_cut) while the foe stands
## in a Менгір circle (or left it less than brand_s ago); x (1 - plant_cut) on Отто's planted tick (a
## partial plant: tick_free flagged it and returned false). Called right after tick_free, as the Run and
## LevelSim do.
static func clash_loss_mult(members: Array) -> float:
	var k := maxf(0.0, 1.0 - _aura_sum(members, "guardian"))
	for m: Dictionary in members:
		if not bool(m["alive"]):
			continue
		if float(m["cut"]) > 0.0:
			k *= 1.0 - float(m["cut"])
		if bool(m.get("plant_hit", false)):
			k *= 1.0 - _plant_cut(m)
	return k


## x every hazard / turret loss: Healer aura "hazard losses -x%".
static func hazard_loss_mult(members: Array) -> float:
	return maxf(0.0, 1.0 - _aura_sum(members, "healer"))


## x army volley damage: Ranger aura "army volley damage +x%".
static func volley_mult(members: Array) -> float:
	return 1.0 + _aura_sum(members, "ranger")


## Mage aura: soldiers' volleys apply the mage's element status with chance `proc`
## ([{status, proc}], one row per living mage). LevelSim has no statuses and ignores it.
static func volley_status(members: Array) -> Array:
	var out: Array = []
	for m: Dictionary in members:
		if bool(m["alive"]) and str(m["class"]) == "mage" and str(m["status"]) != "":
			out.append({"status": str(m["status"]), "proc": float(m["aura_effect"]), "id": m["id"]})
	return out


# ------------------------------------------------------------------ hazards

## A hazard (`kind` barricade / blade / spike / turret) takes `lost` soldiers of an army of `army`
## (blob radius `radius`). A ready Guardian Blocks the first contact of hazard `hazard_id`: the
## soldiers within its block radius are spared (the blob's share inside that circle), the
## barricade takes the Block's damage (tier IV +5) or the squad behind it the Block's kills (a
## twist may send that strike elsewhere: Снаряд's charge, plus Німб's chain). Then Олена's rimed
## soldiers spare up to their count at that hazard. Returns the soldiers still lost. Turrets are
## never Blocked (§4.2: they never target champions; Німб's tier IV catch is absorb_turret).
static func absorb_hazard(view: KindView, members: Array, hazard_id: int, kind: StringName, lost: float,
		army: float, radius: float) -> float:
	if lost <= 0.0 or kind == &"turret":
		return lost
	var left := _block(view, members, hazard_id, kind, lost, army, radius)
	if left > 0.0:
		left = _rime(view, members, hazard_id, left)
	return left


static func _block(view: KindView, members: Array, hazard_id: int, kind: StringName, lost: float,
		army: float, radius: float) -> float:
	for m: Dictionary in members:
		if not bool(m["alive"]) or str(m["class"]) != "guardian":
			continue
		# The same hazard keeps being blocked until its share is used up.
		if int(m["block_id"]) == hazard_id and float(m["block_left"]) > 0.0:
			var spare := minf(float(m["block_left"]), lost)
			m["block_left"] = float(m["block_left"]) - spare
			m["saved"] = float(m["saved"]) + spare
			return lost - spare
		if float(m["cd"]) > 0.0:
			continue
		var c: Dictionary = CLASS["guardian"]
		var br := float(c["r_ii"]) if int(m["tier"]) >= 2 else float(c["r"])
		# The soldiers inside the Block circle: the blob's share of it, at most "spare" x (br / r)^2
		# (§4.3: about 4 soldiers per Block at tier I, the class's value of ~1 soldier / s).
		var share := clampf((br * br) / maxf(radius * radius, 0.01), 0.0, 1.0)
		var cap := float(c["spare"]) * (br * br) / (float(c["r"]) * float(c["r"]))
		var tw: Dictionary = m["tw"]
		m["block_id"] = hazard_id
		m["block_left"] = clampf(army * share, 1.0, cap)
		m["cd"] = float(tw.get("cd", c["cd"]))
		m["blocks"] = int(m["blocks"]) + 1
		if int(m["tier"]) >= 3:
			m["shield"] = float(c["shield_iii"])
		_block_strike(view, m, tw, hazard_id, kind)
		if tw.has("rod_targets"):
			_rod(view, m, tw, hazard_id)
		view.fx(&"champ_block", {"id": m["id"], "hazard": hazard_id, "kind": kind, "stamp": tw.get("stamp", &"block")})
		var spare2 := minf(float(m["block_left"]), lost)
		m["block_left"] = float(m["block_left"]) - spare2
		m["saved"] = float(m["saved"]) + spare2
		return lost - spare2
	return lost


## The Block's own strike: a blocked barricade takes `bar` (x mult; tier IV +5), else the squad behind
## takes `behind` kills (both default to the Action). Снаряд's charge replaces it: the nearest squad
## <= charge_reach takes the Action + charge_status (a barricade takes it when no squad is near).
static func _block_strike(view: KindView, m: Dictionary, tw: Dictionary, hazard_id: int, kind: StringName) -> void:
	var c: Dictionary = CLASS["guardian"]
	var mult := float(m["mult"])
	var d := float(m["d"])
	var x := float(m["x"])
	if tw.has("charge_reach"):
		var cr := float(tw["charge_reach"])
		var near: Dictionary = {}
		var best := INF
		for s: Dictionary in view.squads_in(d - 1.0, d + cr, x - cr, x + cr):
			var k := Vector2(float(s["x"]) - x, float(s["d"]) - d).length()
			if k <= cr and k < best:
				best = k
				near = s
		if not near.is_empty():
			var nid := int(near["id"])
			m["kills"] = float(m["kills"]) + view.hit(nid, float(m["action"]), {"src": m["id"], "kind": &"charge"})
			view.status(nid, StringName(str(tw.get("charge_status", m["status"]))), float(tw.get("charge_s", 3.0)))
			view.fx(TWIST_FX, {"id": m["id"], "twist": &"charge", "target": nid, "d": float(near["d"]),
					"x": float(near["x"])})
		elif kind == &"barricade" and float(tw.get("charge_bar", 0.0)) > 0.0:
			# No squad near: the charge goes off in the blocked barricade (charge_bar x his Action).
			var cb := float(m["action"]) * float(tw["charge_bar"])
			view.hit(hazard_id, cb, {"src": m["id"], "kind": &"charge"})
			m["struct"] = float(m["struct"]) + cb
		return
	if kind == &"barricade":
		var bar := float(tw["bar"]) * mult if tw.has("bar") else float(m["action"])
		bar += float(c["barricade_iv"]) if int(m["tier"]) >= 4 else 0.0
		view.hit(hazard_id, bar, {"src": m["id"], "kind": &"block"})
		m["struct"] = float(m["struct"]) + bar
		if tw.has("bar_fx"):
			view.fx(TWIST_FX, {"id": m["id"], "twist": tw["bar_fx"], "hazard": hazard_id})
		return
	var sq := view.squads_in(d, d + float(c["behind"]), x - 1.5, x + 1.5)
	if sq.is_empty():
		return
	var first: Dictionary = sq[0]
	for s2: Dictionary in sq:
		if float(s2["d"]) < float(first["d"]):
			first = s2
	var behind := float(tw["behind"]) * mult if tw.has("behind") else float(m["action"])
	m["kills"] = float(m["kills"]) + view.hit(int(first["id"]), behind, {"src": m["id"], "kind": &"block"})
	if tw.has("status") and str(m["status"]) != "":
		view.status(int(first["id"]), StringName(str(m["status"])), 2.0)


## Німб's Lightning Rod: the rod_targets hostiles nearest him (<= rod_reach; squads and structures, never
## blades, never the hazard he just blocked: the chain leaves it) take the Action each, squads + rod_status.
static func _rod(view: KindView, m: Dictionary, tw: Dictionary, blocked: int) -> void:
	var d := float(m["d"])
	var x := float(m["x"])
	var rr := float(tw.get("rod_reach", 5.0))
	var pool: Array = []
	for s: Dictionary in view.squads_in(d - rr, d + rr, x - rr, x + rr):
		pool.append(s)
	for h: Dictionary in view.hazards_in(d - rr, d + rr):
		if str(h["kind"]) != "blade" and int(h["id"]) != blocked:
			pool.append(h)
	var near: Array = []
	for t: Dictionary in pool:
		var k := Vector2(float(t["x"]) - x, float(t["d"]) - d).length()
		if k <= rr:
			near.append([k, t])
	if near.is_empty():
		return
	near.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var st := StringName(str(tw.get("rod_status", m["status"])))
	var ids: Array = []
	for k2 in mini(int(tw["rod_targets"]), near.size()):
		var t2: Dictionary = near[k2][1]
		var tid := int(t2["id"])
		ids.append(tid)
		_tally(m, t2, float(m["action"]), view.hit(tid, float(m["action"]), {"src": m["id"], "kind": &"rod"}))
		if t2.has("n"):
			view.status(tid, st, 2.0)
	view.fx(TWIST_FX, {"id": m["id"], "twist": &"rod", "targets": ids, "d": d, "x": x})


## Олена's rime: the rimed soldiers (rime_per each, up to rime_cap) spare that many at the first hazard
## contact after the pulses that rimed them (then they are spent, like a Block's share).
static func _rime(view: KindView, members: Array, hazard_id: int, lost: float) -> float:
	var left := lost
	for m: Dictionary in members:
		if not bool(m["alive"]) or left <= 0.0:
			continue
		if int(m["rime_id"]) != hazard_id or float(m["rime_left"]) <= 0.0:
			if float(m["rimed"]) <= 0.0:
				continue
			var tw: Dictionary = m["tw"]
			m["rime_id"] = hazard_id
			m["rime_left"] = float(m["rimed"]) * float(tw.get("rime_per", 1.0))
			m["rimed"] = 0.0
			view.fx(TWIST_FX, {"id": m["id"], "twist": &"rime", "n": float(m["rime_left"]), "hazard": hazard_id})
		var spare := minf(float(m["rime_left"]), left)
		m["rime_left"] = float(m["rime_left"]) - spare
		m["saved"] = float(m["saved"]) + spare
		left -= spare
	return left


## A turret shot (or, in LevelSim, a step of turret fire) costing `lost` soldiers, before the Healer
## aura: Німб's tier IV catches one shot aimed at the soldiers within catch_r of him (§6.20, §10.5:
## turrets never target champions; the shot is caught on the aegis). The shot's soldier = the blob
## edge nearest the turret (the same estimate in Run and LevelSim). A catch lasts until one soldier's
## worth is spared (a Run shot is 1), then waits catch_cd (its own timer; without catch_cd it shares
## the Block cooldown). Returns the soldiers still lost.
static func absorb_turret(view: KindView, members: Array, turret_id: int, lost: float) -> float:
	if lost <= 0.0:
		return lost
	for m: Dictionary in members:
		if not bool(m["alive"]) or str(m["class"]) != "guardian":
			continue
		var tw: Dictionary = m["tw"]
		if not tw.has("catch_r") or int(m["tier"]) < int(tw.get("catch_tier", 4)):
			continue
		if int(m["catch_id"]) == turret_id and float(m["catch_left"]) > 0.0:
			var spare := minf(float(m["catch_left"]), lost)
			m["catch_left"] = float(m["catch_left"]) - spare
			m["saved"] = float(m["saved"]) + spare
			return lost - spare
		var own := tw.get("catch_cd") != null
		if (float(m["catch_cd"]) if own else float(m["cd"])) > 0.0:
			continue
		if not _catch_reach(view, m, turret_id, float(tw["catch_r"])):
			continue
		m["catch_id"] = turret_id
		m["catch_left"] = 1.0
		if own:
			m["catch_cd"] = float(tw["catch_cd"])
		else:
			m["cd"] = float(tw.get("cd", CLASS["guardian"]["cd"]))
		m["blocks"] = int(m["blocks"]) + 1
		view.fx(&"champ_block", {"id": m["id"], "hazard": turret_id, "kind": &"turret", "stamp": &"catch"})
		view.fx(TWIST_FX, {"id": m["id"], "twist": &"catch", "hazard": turret_id})
		var spare2 := minf(1.0, lost)
		m["catch_left"] = 1.0 - spare2
		m["saved"] = float(m["saved"]) + spare2
		return lost - spare2
	return lost


## True when turret `turret_id`'s shot would land within `reach` of member `m`: the soldier it aims
## at is the blob edge (an ellipse BLOB_STRETCH long) nearest the turret.
static func _catch_reach(view: KindView, m: Dictionary, turret_id: int, reach: float) -> bool:
	var a := view.army()
	var r := maxf(float(a["radius"]), 0.01)
	var ad := float(a["d"])
	var ax := float(a["x"])
	for h: Dictionary in view.hazards_in(ad - 20.0, ad + 20.0):
		if int(h["id"]) != turret_id:
			continue
		var dx := float(h["x"]) - ax
		var dd := float(h["d"]) - ad
		var e := Vector2(dx / r, dd / (r * Balance.BLOB_STRETCH)).length()
		var px := ax + (dx / e if e > 1.0 else dx)
		var pd := ad + (dd / e if e > 1.0 else dd)
		return Vector2(px - float(m["x"]), pd - float(m["d"])).length() <= reach
	return false


## The member that caught turret `turret_id`'s shot this moment ({} when none): the Run flies the
## shot to it.
static func catcher(members: Array, turret_id: int) -> Dictionary:
	for m: Dictionary in members:
		if bool(m["alive"]) and int(m["catch_id"]) == turret_id:
			return m
	return {}


# ------------------------------------------------------------------ clash

## True when this clash tick costs the army nothing: a Guardian's tier III shield after a Block, else
## one of Отто's planted ticks with plant_cut 1 (absent = 1). Consumes it. A planted tick with plant_cut
## < 1 is not free: it is flagged (plant_hit) and costs the army x (1 - plant_cut) through clash_loss_mult;
## either way he takes the spared share at plant_share in clash_hit.
static func tick_free(members: Array) -> bool:
	var f := in_slot(members, FRONT)
	if f.is_empty():
		return false
	f["plant_hit"] = false
	if float(f["shield"]) > 0.0:
		f["shield"] = 0.0
		return true
	if int(f["plant"]) > 0:
		f["plant"] = int(f["plant"]) - 1
		f["plant_hit"] = true
		return _plant_cut(f) >= 1.0
	return false


## The share of a planted tick the army is spared (Отто's plant_cut, 1 = the whole tick).
static func _plant_cut(m: Dictionary) -> float:
	return clampf(float((m["tw"] as Dictionary).get("plant_cut", 1.0)), 0.0, 1.0)


## Extra foe kills this clash tick (Warrior Cleave, 0.07 x mult per FIGHT_TICK; fractions carry;
## tier III cleaves a second squad in contact: the owner applies the kills to the foe only).
static func cleave(members: Array) -> float:
	var total := 0.0
	var c: Dictionary = CLASS["warrior"]
	for m: Dictionary in members:
		if not bool(m["alive"]) or str(m["class"]) != "warrior":
			continue
		var acc := float(m["cleave_acc"]) + float(c["cleave"]) * float(m["mult"]) * (2.0 if int(m["tier"]) >= 3 else 1.0)
		var k := floorf(acc)
		m["cleave_acc"] = acc - k
		m["kills"] = float(m["kills"]) + k
		total += k
	return total


## The front champion in contact takes its share of a clash tick of `hit` soldiers:
## acc += hit x CLASH_SHARE (x CLASH_SHARE_GUARDIAN_HERO with a Guardian hero), loses floor(acc); on a
## planted tick (tick_free) the share the army was spared (plant_cut) costs it plant_share instead of
## CLASH_SHARE (a whole planted tick: hit x plant_share). A fall ends its contributions at once
## (fx champ_down).
static func clash_hit(view: KindView, members: Array, hit: float, guardian_hero: bool) -> void:
	for mc: Dictionary in members:
		# Менгір's circle cut this tick (clash_loss_mult): booked for the budget table.
		if float(mc["cut"]) > 0.0 and bool(mc["alive"]):
			mc["saved"] = float(mc["saved"]) + hit * float(mc["cut"])
	var f := in_slot(members, FRONT)
	if f.is_empty() or hit <= 0.0:
		return
	var share := ChampionData.CLASH_SHARE
	if bool(f["plant_hit"]):
		f["plant_hit"] = false
		var pc := _plant_cut(f)
		share = lerpf(share, float((f["tw"] as Dictionary).get("plant_share", share)), pc)
		f["saved"] = float(f["saved"]) + hit * pc
	share *= ChampionData.CLASH_SHARE_GUARDIAN_HERO if guardian_hero else 1.0
	var acc := float(f["acc"]) + hit * share
	var dmg := floorf(acc)
	f["acc"] = acc - dmg
	if dmg > 0.0:
		_damage(view, f, dmg)


## At army 0 a living champion takes the whole tick (front -> left -> right -> rear) before the
## hero does. Returns true when one did.
static func absorb_tick(view: KindView, members: Array, hit: float) -> bool:
	for sl in ABSORB_ORDER:
		var m := in_slot(members, sl)
		if not m.is_empty():
			_damage(view, m, hit)
			return true
	return false


static func _damage(view: KindView, m: Dictionary, dmg: float) -> void:
	var taken := minf(dmg, float(m["hp"]))
	m["hp"] = float(m["hp"]) - taken
	m["dmg_taken"] = float(m["dmg_taken"]) + taken
	view.fx(&"champ_hit", {"id": m["id"], "hp": float(m["hp"]), "hp_max": float(m["hp_max"])})
	if float(m["hp"]) <= 0.0001:
		m["hp"] = 0.0
		m["alive"] = false
		m["field_left"] = 0.0
		m["shield"] = 0.0
		m["plant"] = 0
		m["cut"] = 0.0
		view.fx(&"champ_down", {"id": m["id"], "slot": m["slot"], "x": float(m["x"]), "d": float(m["d"])})


# ------------------------------------------------------------------ healing

## Soldiers lost (any cause) feed every living Healer's revive pool (30%, capped per level).
static func feed(members: Array, n: float) -> void:
	if n <= 0.0:
		return
	var c: Dictionary = CLASS["healer"]
	for m: Dictionary in members:
		if bool(m["alive"]) and str(m["class"]) == "healer":
			# The cap is per level: what was fed counts against it even after it is spent.
			var add := minf(n * float(c["feed"]), maxf(float(m["pool_cap"]) - float(m["fed"]), 0.0))
			m["fed"] = float(m["fed"]) + add
			m["pool"] = float(m["pool"]) + add


## A Healer hero's revive (Ейра form II, Пава): back at `hp_frac` of max HP. False when `id` is
## alive or unknown.
static func revive(view: KindView, members: Array, id: String, hp_frac: float) -> bool:
	for m: Dictionary in members:
		if str(m["id"]) == id and not bool(m["alive"]):
			m["alive"] = true
			m["hp"] = maxf(1.0, float(m["hp_max"]) * hp_frac)
			m["acc"] = 0.0
			view.fx(&"champ_revive", {"id": id})
			return true
	return false


## The result screen's per-champion line (§10.5).
static func report(members: Array) -> Array:
	var out: Array = []
	for m: Dictionary in members:
		out.append({"id": m["id"], "alive": bool(m["alive"]), "kills": int(round(float(m["kills"]))),
				"heals": int(round(float(m["heals"]))), "blocks": int(m["blocks"]),
				"dmg_taken": int(round(float(m["dmg_taken"])))})
	return out
