class_name RunKindView
extends KindView
## KindView over the live run (heroes design §10.4): the rules' hits land through the Run's own
## hurt / gate code, fx events become the hero's poses, VFX, SFX and HUD signals. The ult clock
## is the Run's own (Run.ult_clock), so fx handlers always see the current clock.
##
## H2 (champions): target ids are the items' indices in Run.items (stamped as "kid" at spawn,
## Run.kind_item); squads_in / hazards_in read the run's own lists in run distances (d >= 0,
## scene z = -d); hit lands through Run.hurt (kill coins, ult charge, statuses and kill fx as for
## any hit) and returns the soldiers removed; status goes through the run's Statuses; add_soldiers
## through Run.champion_mend (spawned at the blob front); champ_* fx go to Run._champ_fx (VFX and
## the HUD medallions), every other event to the ult's Run._ult_fx.
##
## The rules poll every step while a champion waits for a target, so the answers allocate nothing
## when nothing is there: army() refreshes one dictionary, an empty query returns `_none`, and an
## item's row dictionary is made once and refreshed in place ("kv" on the item).
##
## H2 verbs: a hold / grounding is stamped on the squad's item as the run time it ends ("hold_end",
## "hold_k", "ground_end"; Run's clash / siege ticks and Hazards.step_squads read hold_k); tethers and
## wards live here (Run.hurt passes a tether's share through tether_share); status_mult is the Run's
## Statuses.vs (MARK). Nothing is stamped or stored unless a champion or hero-kind rule calls a verb.
##
## H2 hero kinds (§6.2-6.10, §6.28, §6.29), as SimKindView answers them: squads_in / hazards_in rows carry
## the half width `hw`; structures_in adds crates and the fortress; gates_in lists the gates of rows not
## crossed yet (hit(gate id, n) = n hero hits); a hit tagged "kind" &"ult" lands without MARK's vs (an
## ult's hit, as Run._ult_hit), &"attack" is a hero shot (source "hero"); siege(); army()["lost"] = the
## soldiers lost this run (Run.lost_total); expose / strip / silence are stamped on the item as the run
## time they end ("expose_end" + "expose_k": the Run's clash ticks x (1 + k); "strip_end": the squad's rows
## say armored false; "silence_end": Hazards.step_turrets holds its fire, as LevelSim._turrets skips it);
## reveal(.., &"gates") shows the hidden gates (&"phantoms" waits for the Phantoms); buff keeps the team
## buffs (Run.volley_mult reads &"volleys", Run.hurt's volleys &"volley_status", Weapons._b2 &"machines");
## revive_champion stands a fallen champion up (ChampionKinds.revive) with the hero's touch drawn by HeroFx;
## lose takes soldiers off the army. Wards: grant_ward adds charges (or, with `replace`, sets them: the
## drones' grant each period); every spend reads KindView.WARD_SPEND, the table SimKindView / LevelSim use
## (absorb: a hazard or turret hit; spend_wards: the Run's clash ticks spend the "clash" wards of Вартан's
## wall HP). `ult_shape` and `hero_attack` fx go to the Run (the hero's pose, juice) and on to its HeroFx
## (the starters' v3 volleys: the Run's own shot VFX).

## Hurt source of every champion hit (Run.hurt / Statuses: not a machine, chains like a hero hit).
const SOURCE := "champion"

var run: Run
var _army := {"n": 0.0, "x": 0.0, "d": 0.0, "radius": 0.0, "reserves": 0.0, "revive_pool": 0.0, "lost": 0.0}
var _none: Array = []
var _found: Array = []
var _no_status := {}
var _hz_lists: Array = []
## The lists structures_in walks (made once: the rules poll it every step).
var _st_lists: Array = []
## [[item a, item b, share, end run time], ...] (tether).
var _tethers: Array = []
var _tethering := false
## kind -> [charges, end run time] (grant_ward / absorb / spend_wards).
var _wards := {}
## kind -> [value, end run time, data] (buff).
var _buffs := {}


func _init(p_run: Run) -> void:
	run = p_run


func distance() -> float:
	return run.d


func ult_power() -> float:
	return run.hero.ult_power()


func clock() -> HeroKinds.Clock:
	return run.ult_clock


func store_clock(c: HeroKinds.Clock) -> void:
	if c != run.ult_clock:
		run.ult_clock = c


func area_hit(d0: float, d1: float, kills: float, breaks: float, gates: bool) -> void:
	run._ult_hit(d0, d1, gates, kills, breaks)


func grant_armor(sec: float) -> void:
	run._armor = sec


func in_fight() -> bool:
	return run.state == Run.State.CLASH or run.state == Run.State.SIEGE


## d = the blob CENTRE's run distance (the champion slots hang off it, as LevelSim.army_center_d),
## x = the blob centre x (the blob follows the hero's x); reserves = the Barracks soldiers due at the
## siege; lost = the soldiers lost this run from any cause (Run.lost_total: the ward and the army_loss
## policy read it). revive_pool stays 0 as in SimKindView (a Healer hero's pool is HeroKinds.Clock.pool).
func army() -> Dictionary:
	var r := run.blob_radius()
	_army["n"] = float(run.army)
	_army["x"] = run.hx
	_army["d"] = run.d - Balance.HERO_GAP - r * Balance.BLOB_STRETCH
	_army["radius"] = r
	_army["reserves"] = float(run.army_view.reserves()) if run.army_view else 0.0
	_army["lost"] = run.lost_total
	return _army


## True during the fortress siege (in_fight() is a clash or the siege).
func siege() -> bool:
	return run.state == Run.State.SIEGE


## Hostile hp within `reach` u ahead the Meta-1 policy weighs (SimKindView.threat_ahead): squads over the
## blob's lane (+0.5 u) count their hp, the fortress counts 99.
func threat_ahead(reach: float) -> float:
	var total := 0.0
	var r := run.blob_radius()
	for it: Dictionary in run._ult_targets(run.d - 0.5, run.d + reach):
		var k := str(it["kind"])
		if k == "squad" and absf(float(it["x"]) - run.hx) <= r + float(it.get("w", 2.4)) * 0.5 + 0.5:
			total += float(it["hp"])
		elif k == "fortress":
			total += 99.0
	return total


func champions() -> Array:
	return run.champions.members


## champ_* events to the champions' view and HUD, the new hero kinds' `ult_shape` / `hero_attack` to the
## Run's HeroFx (with the hero's pose), the starters' timed / waves events to the Run's ult VFX.
func fx(event: StringName, data := {}) -> void:
	if ChampionKinds.FX.has(event):
		run._champ_fx(event, data)
	elif event == &"ult_shape":
		run._ult_shape_fx(data)
	elif event == &"hero_attack":
		run._hero_attack_fx(data)
	else:
		run._ult_fx(event, data)


# ------------------------------------------------------------------ H2: champions

## Living squads with d in [d0, d1] whose span (x +- w / 2) overlaps [x0, x1] (rows with `hw`).
func squads_in(d0: float, d1: float, x0: float, x1: float) -> Array:
	_found.clear()
	var list := run.hazards.squads
	for i in range(_lower(list, d0), list.size()):
		var it := list[i]
		var di := float(it["d"])
		if di > d1:
			break
		if not it["alive"]:
			continue
		var x := float(it["x"])
		var hw := float(it.get("w", 2.4)) * 0.5
		if x + hw < x0 or x - hw > x1:
			continue
		_found.append(_squad_row(it))
	return _answer()


## Living structures with d in [d0, d1]: spiked barricades ("barricade"), blades, turrets and
## geodes (never crates, gates or the fortress). Blades are listed (hp 0); the rules skip them.
## Rows carry `hw` (Run.half_span).
func hazards_in(d0: float, d1: float) -> Array:
	_found.clear()
	if _hz_lists.is_empty():
		var hz := run.hazards
		_hz_lists = [hz.spikes, hz.blades, hz.turrets, hz.geodes]
	for list: Array[Dictionary] in _hz_lists:
		for i in range(_lower(list, d0), list.size()):
			var it := list[i]
			if float(it["d"]) > d1:
				break
			if it["alive"]:
				_found.append(_hazard_row(it))
	return _answer()


## What a hero ult or attack may break with d in [d0, d1]: the hazards_in structures (never blades) plus the
## crates and the fortress (hw = the half bridge): [{id, d, x, kind, hp, hw}], by d.
func structures_in(d0: float, d1: float) -> Array:
	_found.clear()
	if _st_lists.is_empty():
		var hz := run.hazards
		_st_lists = [hz.spikes, hz.turrets, hz.geodes, hz.crates]
	for list: Array[Dictionary] in _st_lists:
		for i in range(_lower(list, d0), list.size()):
			var it := list[i]
			if float(it["d"]) > d1:
				break
			if it["alive"]:
				_found.append(_hazard_row(it))
	var f: Dictionary = run._fortress
	if not f.is_empty() and f.get("alive", false) and float(f["d"]) >= d0 and float(f["d"]) <= d1:
		_found.append(_hazard_row(f))
	if _found.size() > 1:
		_found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	return _answer()


## Gates of rows not crossed yet with d in [max(d0, hero), d1], nearest first (the hero kinds' gate hits and
## gate-row policies): [{id, row, d, x, hw, kind (the op it shows now), value, hidden}]; ids hit() accepts.
func gates_in(d0: float, d1: float) -> Array:
	_found.clear()
	var list := run._gates
	for i in range(_lower(list, maxf(d0, run.d)), list.size()):
		var it := list[i]
		if float(it["d"]) > d1:
			break
		if it["alive"]:
			_found.append(_gate_row(it))
	return _answer()


## One hit of `dmg` (on a squad x status_mult: MARK) through Run.hurt; returns the squad soldiers
## removed (0 for structures). Tags (the hero kinds): "kind" &"ult" = an ult's hit (no MARK's vs, hurt
## source "ult"), "src" "hero" = a hero shot (source "hero"); a crate or the fortress (structures_in ids)
## takes `dmg` like any structure. A gate (a gates_in id) takes `dmg` hero hits at once (Run.ult_gate_hit:
## the hero's damage with the Prism amp, as an area_hit's gate hits); returns 0.
func hit(target_id: int, dmg: float, tags := {}) -> int:
	var it := run.kind_item(target_id)
	if it.is_empty() or not it.get("alive", false) or dmg <= 0.0:
		return 0
	var kind := str(it["kind"])
	if kind == "gate":
		run.ult_gate_hit(it, dmg)
		return 0
	# Crates break only to the hero kinds (structures_in); the champions never hit them.
	if kind == "blade" or (kind == "crate" and str(tags.get("src", "")) != "hero"):
		return 0
	var t0 := Time.get_ticks_usec()
	var ult: bool = tags.get("kind", &"") == &"ult"
	var src := "ult" if ult else ("hero" if str(tags.get("src", "")) == "hero" else SOURCE)
	# Soldiers removed = the change of the squad's shown count ceil(hp), as SimKindView counts them.
	var before := ceili(maxf(float(it["hp"]) - 0.001, 0.0))
	run.hurt(it, dmg * (_vs(it) if kind == "squad" and not ult else 1.0), src)
	if run.champ_stepping:
		run.champ_perf["hit_us"] = int(run.champ_perf["hit_us"]) + Time.get_ticks_usec() - t0
	if kind != "squad":
		return 0
	return before - (ceili(maxf(float(it["hp"]) - 0.001, 0.0)) if it["alive"] else 0)


## One stack of status `st` (ChampionKinds.ELEMENT_STATUS names) on squad `target_id`, kept at
## least `s` seconds.
func status(target_id: int, st: StringName, s: float) -> void:
	var it := run.kind_item(target_id)
	if it.is_empty() or run.arsenal == null or run.arsenal.statuses == null:
		return
	var sts := run.arsenal.statuses
	var key := String(st)
	sts.apply(it, key, 1.0, {"id": SOURCE, "stats": {"mark_s": s}})
	if s > 0.0 and sts.has(it, key):
		var e: Dictionary = (it["status"] as Dictionary)[key]
		e["t"] = maxf(float(e["t"]), s)


## Healer Mend: `n` soldiers back at the blob front.
func add_soldiers(n: float, _cause: StringName) -> void:
	run.champion_mend(int(floor(n + 0.0001)))


## `n` soldiers lost to `cause` (the army's own losses path: the Healers are fed, the counter drops).
func lose(n: int, _cause: StringName) -> void:
	run.kind_lose(n)


## A Healer hero's revive (Ейра form II, Пава forms II / V, §4.2): fallen champion `id` stands up at
## `hp_frac` of its max HP (ChampionKinds.revive: champ_revive raises the model) and HeroFx draws the
## hero's touch. False when `id` is alive or unknown.
func revive_champion(id: StringName, hp_frac: float) -> bool:
	if not ChampionKinds.revive(self, run.champions.members, String(id), hp_frac):
		return false
	run.hero_revived(String(id))
	return true


## The Run's Statuses.vs on squad `target_id` (MARK 1.25 while it runs), 1.0 when none.
func status_mult(target_id: int) -> float:
	return _vs(run.kind_item(target_id))


func _vs(it: Dictionary) -> float:
	if it.is_empty() or run.arsenal == null or run.arsenal.statuses == null or str(it.get("kind", "")) != "squad":
		return 1.0
	return run.arsenal.statuses.vs(it)


## Holds squad `squad_id`: stamps the run time it ends and its strength on the item (a new hold keeps
## the stronger strength and the longer time; an expired one is replaced).
func hold(squad_id: int, sec: float, strength := 1.0) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or sec <= 0.0 or strength <= 0.0:
		return
	var k := clampf(strength, 0.0, 1.0)
	var end := float(it.get("hold_end", 0.0))
	if end > run.t:
		k = maxf(k, float(it.get("hold_k", 0.0)))
	it["hold_k"] = k
	it["hold_end"] = maxf(end, run.t + sec)


## The hold on squad item `it` now: its strength, 0 when none (Run's clash / siege ticks: a held foe
## deals x (1 - this); Hazards.step_squads: its charge runs x (1 - this)).
func hold_k(it: Dictionary) -> float:
	if float(it.get("hold_end", 0.0)) <= run.t:
		return 0.0
	return float(it.get("hold_k", 0.0))


## Grounds a Flying squad for `sec` s (its rows say flying false meanwhile); no-op on any other.
func ground(squad_id: int, sec: float) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or sec <= 0.0:
		return
	var props: Variant = it.get("props")
	if not (props is Array and (props as Array).has("flying")):
		return
	it["ground_end"] = maxf(float(it.get("ground_end", 0.0)), run.t + sec)


## Squad `squad_id` loses x (1 + `add`) in its clashes for `sec` s (Веста / Сірко form II): stamped on the
## item ("expose_end", "expose_k"; the larger add and the longer time win), Run's clash ticks read exposed().
func expose(squad_id: int, add: float, sec: float) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or add <= 0.0 or sec <= 0.0:
		return
	var k := add
	var end := float(it.get("expose_end", 0.0))
	if end > run.t:
		k = maxf(k, float(it.get("expose_k", 0.0)))
	it["expose_k"] = k
	it["expose_end"] = maxf(end, run.t + sec)


## The clash loss multiplier of squad item `it` now: 1 + its exposure, 1.0 when none.
func exposed(it: Dictionary) -> float:
	if float(it.get("expose_end", 0.0)) <= run.t:
		return 1.0
	return 1.0 + float(it.get("expose_k", 0.0))


## Squad `squad_id` fights as a plain squad for `sec` s (Сірко form IV): its rows say armored false
## meanwhile ("strip_end"; the Statuses' Armored / Shielded rules do not read it yet).
func strip(squad_id: int, sec: float) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or sec <= 0.0:
		return
	it["strip_end"] = maxf(float(it.get("strip_end", 0.0)), run.t + sec)


## Turret `turret_id` is silenced for `sec` s (Ольга form IV): Hazards.step_turrets holds its fire and spends
## no ward (LevelSim._turrets skips it), Run.turret_hit makes a shot already in flight a miss.
func silence(turret_id: int, sec: float) -> void:
	var it := run.kind_item(turret_id)
	if it.is_empty() or str(it.get("kind", "")) != "turret" or sec <= 0.0:
		return
	it["silence_end"] = maxf(float(it.get("silence_end", 0.0)), run.t + sec)


func silenced(it: Dictionary) -> bool:
	return float(it.get("silence_end", 0.0)) > run.t


## What with d in [d0, d1] is revealed: &"gates" = the hidden gates show their value (Run.reveal_gates: Мейра
## form III, a row reveal); &"phantoms" = the Phantom squads (Пава form IV, the mark proc): a no-op until the
## Phantoms exist.
func reveal(d0: float, d1: float, what: StringName = &"gates") -> void:
	if what == &"gates":
		run.reveal_gates(d0, d1)


## A timed team buff (the larger value and the longer time win): &"volleys" = army volleys x (1 + value)
## (Run.volley_mult), &"volley_status" = every army volley on a squad also applies data.statuses (Run.hurt),
## &"machines" = machine damage + value (buff_value; read by the machines' bucket 2).
func buff(kind: StringName, value: float, sec: float, data := {}) -> void:
	if sec <= 0.0:
		return
	var b: Array = _buffs.get(kind, [0.0, 0.0, {}])
	if float(b[1]) <= run.t:
		b = [0.0, 0.0, {}]
	_buffs[kind] = [maxf(float(b[0]), value), maxf(float(b[1]), run.t + sec), data if not data.is_empty() else b[2]]


## The value of buff `kind` now (0 when none or over).
func buff_value(kind: StringName) -> float:
	if _buffs.is_empty():
		return 0.0
	var b: Array = _buffs.get(kind, [])
	return float(b[0]) if not b.is_empty() and float(b[1]) > run.t else 0.0


## The data of buff `kind` now ({} when none or over).
func buff_data(kind: StringName) -> Dictionary:
	if _buffs.is_empty():
		return _no_status
	var b: Array = _buffs.get(kind, [])
	return b[2] if not b.is_empty() and float(b[1]) > run.t else _no_status


## Tethers squads `a` and `b` for `sec` s: Run.hurt hands every damage either takes to tether_share.
func tether(a: int, b: int, share: float, sec: float) -> void:
	var ia := run.kind_item(a)
	var ib := run.kind_item(b)
	if a == b or ia.is_empty() or ib.is_empty() or share <= 0.0 or sec <= 0.0:
		return
	if not ia.get("alive", false) or not ib.get("alive", false) or str(ia["kind"]) != "squad" or str(ib["kind"]) != "squad":
		return
	for k in range(_tethers.size() - 1, -1, -1):
		if float((_tethers[k] as Array)[3]) <= run.t:
			_tethers.remove_at(k)
	_tethers.append([ia, ib, share, run.t + sec])


## True while any tether was made this run (Run.hurt's cheap test).
func tethered() -> bool:
	return not _tethers.is_empty()


## Run.hurt: `dealt` landed on squad item `it`; each live tether hands its share to the partner (a
## "tether" hit; one hop: the share never passes on).
func tether_share(it: Dictionary, dealt: float) -> void:
	if _tethering or dealt <= 0.0:
		return
	for tt: Array in _tethers:
		if float(tt[3]) <= run.t:
			continue
		var other: Dictionary = {}
		if is_same(tt[0], it):
			other = tt[1]
		elif is_same(tt[1], it):
			other = tt[0]
		if other.is_empty() or not other.get("alive", false):
			continue
		_tethering = true
		run.hurt(other, dealt * float(tt[2]), "tether")
		_tethering = false


## `charges` more wards of ward kind `kind` for `sec` s (charges add up, the longer time is kept, an expired
## ward starts over); with `replace` the store of `kind` becomes exactly `charges` for `sec` s (the drones'
## grant each period; 0 charges or 0 s clear it).
func grant_ward(kind: StringName, charges: int, sec: float, replace := false) -> void:
	if replace:
		_wards.erase(kind)
	if charges <= 0 or sec <= 0.0:
		return
	var w: Array = _wards.get(kind, [0.0, 0.0])
	if float(w[1]) <= run.t:
		w = [0.0, 0.0]
	_wards[kind] = [float(w[0]) + float(charges), maxf(float(w[1]), run.t + sec)]


## Spends up to `want` whole ward charges a `kind` hit may use (KindView.WARD_SPEND, in its order; the Run's
## clash ticks spend the "clash" wards of Вартан's wall HP, one soldier each); returns the charges spent.
func spend_wards(kind: StringName, want: int) -> int:
	if _wards.is_empty() or want <= 0:
		return 0
	var spent := 0
	for wk: StringName in KindView.WARD_SPEND.get(kind, [kind]):
		var w: Array = _wards.get(wk, [])
		if spent >= want or w.is_empty() or float(w[1]) <= run.t or float(w[0]) < 1.0:
			continue
		var take := mini(int(floor(float(w[0]) + 0.0001)), want - spent)
		w[0] = float(w[0]) - float(take)
		spent += take
	return spent


## One ward charge a `kind` hit may spend: from the first ward kind of KindView.WARD_SPEND[kind] holding a
## whole charge (a turret shot: the wall's, a drone's, then a plain turret ward; a blade: the wall's contact
## ward, a blade ward, then a contact ward); true = the hit is absorbed.
func absorb(kind: StringName) -> bool:
	if _wards.is_empty():
		return false
	for wk: StringName in KindView.WARD_SPEND.get(kind, [kind]):
		var w: Array = _wards.get(wk, [])
		if not w.is_empty() and float(w[1]) > run.t and float(w[0]) >= 1.0:
			w[0] = float(w[0]) - 1.0
			return true
	return false


func _answer() -> Array:
	if _found.is_empty():
		_none.clear()
		return _none
	return _found.duplicate()


func _squad_row(it: Dictionary) -> Dictionary:
	var r: Dictionary = it.get("kv", _no_status)
	if r.is_empty():
		var props: Array = it.get("props", []) if it.get("props") is Array else []
		r = {"id": int(it["kid"]), "d": 0.0, "x": 0.0, "n": 0.0, "flying": props.has("flying"),
				"armored": props.has("armored"), "phantom": props.has("phantom"), "status": _no_status,
				"hw": float(it.get("w", 2.4)) * 0.5}
		it["kv"] = r
	r["d"] = float(it["d"])
	r["x"] = float(it["x"])
	r["n"] = float(it["hp"])
	r["status"] = it.get("status", _no_status)
	if it.has("ground_end"):
		# A grounded Flying squad reads as a ground squad (ground).
		var props: Array = it.get("props", []) if it.get("props") is Array else []
		r["flying"] = props.has("flying") and float(it["ground_end"]) <= run.t
	if it.has("strip_end"):
		# A stripped squad fights as a plain one (strip).
		var props2: Array = it.get("props", []) if it.get("props") is Array else []
		r["armored"] = props2.has("armored") and float(it["strip_end"]) <= run.t
	return r


func _gate_row(it: Dictionary) -> Dictionary:
	var r: Dictionary = it.get("kv", _no_status)
	if r.is_empty():
		r = {"id": int(it["kid"]), "row": int(it.get("row", it["kid"])), "d": float(it["d"]), "x": 0.0,
				"hw": float(it.get("w", 2.0)) * 0.5, "kind": "", "value": 0.0, "hidden": false}
		it["kv"] = r
	r["x"] = float(it["x"])
	r["kind"] = str(it["op"])
	r["value"] = float(it["value"])
	r["hidden"] = not bool(it["revealed"])
	return r


func _hazard_row(it: Dictionary) -> Dictionary:
	var r: Dictionary = it.get("kv", _no_status)
	if r.is_empty():
		r = {"id": int(it["kid"]), "d": float(it["d"]), "x": 0.0, "kind": str(it["kind"]), "hp": 0.0,
				"hw": run.half_span(it)}
		it["kv"] = r
	r["x"] = float(it["x"])
	r["hp"] = float(it.get("hp", 0.0))
	return r


## First index of `list` (items sorted by d) with d >= `d0` (binary search).
static func _lower(list: Array[Dictionary], d0: float) -> int:
	var lo := 0
	var hi := list.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(list[mid]["d"]) < d0:
			lo = mid + 1
		else:
			hi = mid
	return lo
