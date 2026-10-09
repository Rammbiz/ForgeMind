class_name ChampionKinds
extends RefCounted
## Champion behaviour rules over a KindView (heroes design §4.2, §4.3, §10.4-10.5). Pure static,
## shared by Run and LevelSim like HeroKinds: Run and LevelSim own the soldiers, the hazards and
## the clash; they call the hooks below at the matching moments and the rules decide what the
## champions add, absorb or take. Nothing here touches nodes; VFX / SFX / HUD go through view.fx.
##
## Phase H2 = class templates (§4.3) with the action tier (I-IV) upgrades; per-champion twists
## (§6.11-6.27) are TWISTS rows (only the plain numeric ones so far).
##
## A member (Champions.members, KindView.champions()) is a Dictionary made by member():
## {id, slot, class, element, gem, native, status, tier, mult, hp, hp_max, alive, action, aura, aura_effect,
##  radius, x, d, cd, acc, shots, pool, pool_cap, fed, shield, field_left, field_d, field_x, field_cd,
##  heal_cd, block_id, block_left, cleave_acc, kills, heals, blocks, dmg_taken}
## x / d = the champion's place on the bridge (d = run distance, ahead = larger), set every step
## from the blob centre and its slot.
##
## Hook order a view owner follows each step (Run._process, LevelSim.step):
##   step(view, members, dt)                 every step, after the army moved
##   hazard_loss_mult(members)               x every hazard / turret loss (Healer aura)
##   absorb_hazard(view, members, id, kind, lost, army, radius) on every hazard loss (Guardian Block)
##   clash_loss_mult(members)                x the army's clash losses (Guardian aura)
##   clash_kill_mult(members)                x the foe's clash losses (Warrior aura)
##   tick_free(members)                      before a clash tick: true = this tick costs the army 0
##   cleave(members)                         per FIGHT_TICK in a clash: extra foe kills (Warrior)
##   clash_hit(view, members, hit, guardian_hero) per clash tick with the army alive: front share
##   absorb_tick(view, members, hit)         per clash tick at army 0: a champion takes it (true)
##   feed(members, n)                        every soldier lost (any cause): Healer revive pool
##   volley_mult(members) / volley_status(members)  army volleys (Ranger / Mage aura)

## view.fx events the rules send (Run: VFX / SFX / HUD medallions; LevelSim: counted). Data keys:
## leap {id, target, d, x} · shot {id, target, d, x, arrows, pierce} · spell {id, d, x, r} ·
## block {id, hazard, kind} · mend {id, n, front} · heal {id, target, hp} · hit {id, hp, hp_max} ·
## down {id, slot, x, d} · revive {id}.
const FX: Array[StringName] = [&"champ_leap", &"champ_shot", &"champ_spell", &"champ_block", &"champ_mend",
		&"champ_heal", &"champ_hit", &"champ_down", &"champ_revive"]

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

## Per-champion twists that are plain numbers on the class template (§6.11-6.27). The rest of
## each sheet's twist (MARK charges, harpoons, the Word's pages ...) arrives with the art waves.
const TWISTS := {
	"alba": {"flying_mult": 1.5},
	"teo": {"homing": true},
	"dovbush": {"targets": 2, "status": "stagger"},
	"snaryad": {"cd": 6.0, "status": "mark"},
}

## Element -> the status it applies (ArsenalData.FAMILIES[element].status; rune = seal).
const ELEMENT_STATUS := {"kinetic": "stagger", "volt": "jolt", "frost": "chill", "plasma": "burn",
		"tech": "mark", "rune": "seal"}

## Champion id -> kind row {class, slot, element}: ChampionData.CHAMPIONS (one table, WS-A).
static func row(id: String) -> Dictionary:
	return ChampionData.CHAMPIONS.get(id, {})


## A run member from a team row (Meta._team_block: ChampionsMeta.stats + slot + aura_effect).
static func member(st: Dictionary, slot: StringName) -> Dictionary:
	var cls := str(st.get("class", ""))
	var el := str(st.get("element", ""))
	var hp := float(st.get("hp", 0.0))
	var aura := minf(float(st.get("aura", 0.0)), ChampionData.AURA_CAP)
	var m := {"id": str(st.get("id", "")), "slot": slot, "class": cls, "element": el,
			"gem": str(st.get("gem", st.get("native", "C"))), "native": str(st.get("native", "C")),
			"status": ELEMENT_STATUS.get(el, ""), "tier": int(st.get("tier", 1)), "mult": float(st.get("mult", 1.0)),
			"hp": hp, "hp_max": hp, "alive": hp > 0.0, "action": float(st.get("action", 0.0)), "aura": aura,
			"aura_effect": aura * float(ChampionData.AURA_SHARE.get(String(slot), 0.0)),
			"radius": float(st.get("radius", 1.0)), "x": 0.0, "d": 0.0, "cd": 0.0, "acc": 0.0, "shots": 0,
			"pool": 0.0, "pool_cap": 0.0, "fed": 0.0, "shield": 0.0, "field_left": 0.0, "field_d": 0.0, "field_x": 0.0,
			"field_cd": 0.0, "heal_cd": 0.0, "block_id": -1, "block_left": 0.0, "cleave_acc": 0.0,
			"kills": 0.0, "heals": 0.0, "blocks": 0, "dmg_taken": 0.0}
	var tw: Dictionary = TWISTS.get(m["id"], {})
	if tw.has("status"):
		m["status"] = str(tw["status"])
	if cls == "healer":
		var c: Dictionary = CLASS["healer"]
		m["pool_cap"] = float(c["cap"]) * float(m["mult"]) * (float(c["cap_iv"]) if int(m["tier"]) >= 4 else 1.0)
		m["cd"] = _healer_cd(m)
		m["heal_cd"] = float(c["heal_cd"])
	return m


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


# ------------------------------------------------------------------ every step

## One step of every living champion: follow the blob, then its class Action. Places every member
## (fallen ones too, so a fallen model stays where it fell: only living ones move).
static func step(view: KindView, members: Array, dt: float) -> void:
	if members.is_empty():
		return
	var a := view.army()
	var r := float(a["radius"])
	for m: Dictionary in members:
		if not bool(m["alive"]):
			continue
		var off := slot_offset(m["slot"], r)
		m["x"] = float(a["x"]) + off.x
		m["d"] = float(a["d"]) - off.y
		m["shield"] = maxf(float(m["shield"]) - dt, 0.0)
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


static func _warrior(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["warrior"]
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if view.in_fight() or float(m["cd"]) > 0.0:
		return
	var tier := int(m["tier"])
	var reach := float(c["leap_range_ii"]) if tier >= 2 else float(c["leap_range"])
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var sq := view.squads_in(d, d + reach, x - lane, x + lane)
	if sq.is_empty():
		return
	sq.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	var tw: Dictionary = TWISTS.get(m["id"], {})
	var n_targets := int(tw.get("targets", 1))
	var kills := float(m["action"]) + (float(c["leap_add_ii"]) * float(m["mult"]) if tier >= 2 else 0.0)
	var first: Dictionary = sq[0]
	for k in mini(n_targets, sq.size()):
		var t: Dictionary = sq[k]
		var got := view.hit(int(t["id"]), kills, {"src": m["id"], "kind": &"leap"})
		m["kills"] = float(m["kills"]) + got
		if (tier >= 3 or tw.has("status")) and str(m["status"]) != "":
			view.status(int(t["id"]), StringName(str(m["status"])), float(c["status_s"]))
	view.fx(&"champ_leap", {"id": m["id"], "target": int(first["id"]), "d": float(first["d"]), "x": float(first["x"])})
	m["cd"] = float(c["leap_cd_iv"]) if tier >= 4 else float(c["leap_cd"])


static func _ranger(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["ranger"]
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if float(m["cd"]) > 0.0:
		return
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var reach := float(c["range"])
	var targets: Array = []
	for s: Dictionary in view.squads_in(d - 0.5, d + reach, x - lane - 2.0, x + lane + 2.0):
		targets.append(s)
	for h: Dictionary in view.hazards_in(d - 0.5, d + reach):
		if str(h["kind"]) != "blade" and absf(float(h["x"]) - x) <= lane + 2.0:
			targets.append(h)
	if targets.is_empty():
		return
	targets.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	var tier := int(m["tier"])
	var shot := int(m["shots"]) + 1
	m["shots"] = shot
	var count := 1
	if tier >= 4 and shot % int(c["pierce_every"]) == 0:
		count = int(c["pierce"])
	var arrows := 2 if tier >= 2 and shot % int(c["extra_every"]) == 0 else 1
	var tw: Dictionary = TWISTS.get(m["id"], {})
	for a in arrows:
		for k in mini(count, targets.size()):
			var t: Dictionary = targets[k]
			var dmg := float(m["action"])
			if bool(t.get("flying", false)):
				dmg *= float(tw.get("flying_mult", 1.0))
			var got := view.hit(int(t["id"]), dmg, {"src": m["id"], "kind": &"shot"})
			m["kills"] = float(m["kills"]) + got
			if tier >= 3 and str(m["status"]) != "" and t.has("n"):
				view.status(int(t["id"]), StringName(str(m["status"])), float(c["status_s"]) * float(c["proc_iii"]))
	var first: Dictionary = targets[0]
	view.fx(&"champ_shot", {"id": m["id"], "target": int(first["id"]), "d": float(first["d"]), "x": float(first["x"]),
			"arrows": arrows, "pierce": count})
	m["cd"] = float(c["cd"])


static func _mage(view: KindView, m: Dictionary, dt: float) -> void:
	var c: Dictionary = CLASS["mage"]
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
	m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
	if float(m["cd"]) > 0.0:
		return
	var d := float(m["d"])
	var x := float(m["x"])
	var lane := float(c["lane"])
	var sq := view.squads_in(d, d + float(c["range"]), x - lane, x + lane)
	if sq.is_empty():
		return
	# The densest squad = the most soldiers inside the spell radius around it.
	var best: Dictionary = {}
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
	for s2: Dictionary in sq:
		if absf(float(s2["d"]) - cd0) <= rad and absf(float(s2["x"]) - cx0) <= rad:
			m["kills"] = float(m["kills"]) + view.hit(int(s2["id"]), float(m["action"]), {"src": m["id"], "kind": &"spell"})
			if str(m["status"]) != "":
				view.status(int(s2["id"]), StringName(str(m["status"])), float(c["status_s"]))
	var smult := float(c["struct_iii"]) if tier >= 3 else 1.0
	for h: Dictionary in view.hazards_in(cd0 - rad, cd0 + rad):
		if str(h["kind"]) != "blade" and absf(float(h["x"]) - cx0) <= rad:
			view.hit(int(h["id"]), float(m["action"]) * smult, {"src": m["id"], "kind": &"spell"})
	view.fx(&"champ_spell", {"id": m["id"], "d": cd0, "x": cx0, "r": rad})
	if tier >= 4:
		m["field_left"] = float(c["field_s"])
		m["field_cd"] = float(c["field_every"])
		m["field_d"] = cd0
		m["field_x"] = cx0
	m["cd"] = float(c["cd_iv"]) if tier >= 4 else float(c["cd"])


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
	if int(m["tier"]) >= 3:
		m["heal_cd"] = float(m["heal_cd"]) - dt
		if float(m["heal_cd"]) <= 0.0:
			m["heal_cd"] = float(c["heal_cd"])
			var f := in_slot(members, FRONT)
			if not f.is_empty():
				var add := minf(float(f["hp_max"]) * float(c["heal_frac"]), float(f["hp_max"]) - float(f["hp"]))
				f["hp"] = float(f["hp"]) + add
				view.fx(&"champ_heal", {"id": m["id"], "target": f["id"], "hp": add})


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


## x the army's clash losses: Guardian aura "clash losses -x%".
static func clash_loss_mult(members: Array) -> float:
	return maxf(0.0, 1.0 - _aura_sum(members, "guardian"))


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
## barricade takes the Block's damage (tier IV +5) or the squad behind it the Block's kills.
## Returns the soldiers still lost. Turrets are never Blocked (§4.2: they never target champions;
## Німб's tier IV absorb is a turret twist, not a Block).
static func absorb_hazard(view: KindView, members: Array, hazard_id: int, kind: StringName, lost: float,
		army: float, radius: float) -> float:
	if lost <= 0.0 or kind == &"turret":
		return lost
	for m: Dictionary in members:
		if not bool(m["alive"]) or str(m["class"]) != "guardian":
			continue
		# The same hazard keeps being blocked until its share is used up.
		if int(m["block_id"]) == hazard_id and float(m["block_left"]) > 0.0:
			var spare := minf(float(m["block_left"]), lost)
			m["block_left"] = float(m["block_left"]) - spare
			return lost - spare
		if float(m["cd"]) > 0.0:
			continue
		var c: Dictionary = CLASS["guardian"]
		var br := float(c["r_ii"]) if int(m["tier"]) >= 2 else float(c["r"])
		# The soldiers inside the Block circle: the blob's share of it, at most "spare" x (br / r)^2
		# (§4.3: about 4 soldiers per Block at tier I, the class's value of ~1 soldier / s).
		var share := clampf((br * br) / maxf(radius * radius, 0.01), 0.0, 1.0)
		var cap := float(c["spare"]) * (br * br) / (float(c["r"]) * float(c["r"]))
		var tw: Dictionary = TWISTS.get(m["id"], {})
		m["block_id"] = hazard_id
		m["block_left"] = clampf(army * share, 1.0, cap)
		m["cd"] = float(tw.get("cd", c["cd"]))
		m["blocks"] = int(m["blocks"]) + 1
		if int(m["tier"]) >= 3:
			m["shield"] = float(c["shield_iii"])
		if kind == &"barricade":
			var dmg := float(m["action"]) + (float(c["barricade_iv"]) if int(m["tier"]) >= 4 else 0.0)
			view.hit(hazard_id, dmg, {"src": m["id"], "kind": &"block"})
		else:
			var d := float(m["d"])
			var sq := view.squads_in(d, d + float(c["behind"]), float(m["x"]) - 1.5, float(m["x"]) + 1.5)
			if not sq.is_empty():
				sq.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
				m["kills"] = float(m["kills"]) + view.hit(int((sq[0] as Dictionary)["id"]), float(m["action"]),
						{"src": m["id"], "kind": &"block"})
				if str(m["status"]) != "" and tw.has("status"):
					view.status(int((sq[0] as Dictionary)["id"]), StringName(str(m["status"])), 2.0)
		view.fx(&"champ_block", {"id": m["id"], "hazard": hazard_id, "kind": kind})
		var spare2 := minf(float(m["block_left"]), lost)
		m["block_left"] = float(m["block_left"]) - spare2
		return lost - spare2
	return lost


# ------------------------------------------------------------------ clash

## True when this clash tick costs the army nothing (a Guardian's tier III shield after a Block);
## consumes the shield.
static func tick_free(members: Array) -> bool:
	var f := in_slot(members, FRONT)
	if f.is_empty() or float(f["shield"]) <= 0.0:
		return false
	f["shield"] = 0.0
	return true


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
## acc += hit x CLASH_SHARE (x CLASH_SHARE_GUARDIAN_HERO with a Guardian hero), loses floor(acc).
## A fall ends its contributions at once (fx champ_down).
static func clash_hit(view: KindView, members: Array, hit: float, guardian_hero: bool) -> void:
	var f := in_slot(members, FRONT)
	if f.is_empty() or hit <= 0.0:
		return
	var share := ChampionData.CLASH_SHARE * (ChampionData.CLASH_SHARE_GUARDIAN_HERO if guardian_hero else 1.0)
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
