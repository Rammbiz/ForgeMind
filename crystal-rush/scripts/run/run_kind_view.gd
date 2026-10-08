class_name RunKindView
extends KindView
## KindView over the live run (heroes design §10.4): the rules' hits land through the Run's own
## hurt / gate code, fx events become the hero's poses, VFX, SFX and HUD signals. The ult clock
## is the Run's own (Run.ult_clock), so fx handlers always see the current clock.

var run: Run


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


func army() -> Dictionary:
	return {"n": float(run.army), "x": run.hx, "d": run.d, "radius": run.blob_radius(),
			"reserves": 0.0, "revive_pool": 0.0}


func champions() -> Array:
	return run.champions.members


func fx(event: StringName, data := {}) -> void:
	run._ult_fx(event, data)
