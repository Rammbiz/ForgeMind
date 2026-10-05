class_name Bot
## A simple player for tests: looks a section ahead in both lanes, estimates the army it would
## have in each and steers to the better one. `skill` < 1 makes it pick at random sometimes.

var skill := 1.0
var rng := RandomNumberGenerator.new()
var _decided_at := -100.0


func think(run: Run) -> void:
	if run.state == Run.State.READY:
		run.start()
	if run.d - _decided_at < 3.0:
		return
	_decided_at = run.d
	if run.ult_ready() and _crowd_ahead(run) >= 8:
		run.use_ult()
	if rng.randf() > skill:
		run.steer(rng.randi() % 2)
		return
	var best := run.lane
	var best_score := -INF
	for ln in 2:
		var s := _score(run, ln)
		if s > best_score + 0.5 or (absf(s - best_score) <= 0.5 and ln == run.lane):
			best_score = s
			best = ln
	run.steer(best)


func _score(run: Run, ln: int) -> float:
	var army := float(run.army)
	var coins := 0.0
	var kills := float(run.def["rate"]) * 2.0 * (float(run.def["damage"]) + float(run.def["splash"]))
	for i in range(run._next, run.items.size()):
		var it: Dictionary = run.items[i]
		if float(it["d"]) > run.d + 26.0:
			break
		if not it["alive"] or (int(it["lane"]) >= 0 and int(it["lane"]) != ln):
			continue
		match str(it["kind"]):
			"tile":
				army += 1.0
			"coin":
				coins += 0.25
			"gate":
				match str(it["op"]):
					"+":
						army += float(it["value"])
					"-":
						army -= float(it["value"])
					"x":
						army *= float(it["value"])
			"squad":
				army -= maxf(float(it["hp"]) - kills, 0.0)
			"barricade":
				army -= maxf(float(it["hp"]) - kills * 0.5, 0.0)
	if army < 0.0:
		return army * 4.0 + coins
	return army + coins


func _crowd_ahead(run: Run) -> int:
	var n := 0
	for i in range(run._next, run.items.size()):
		var it: Dictionary = run.items[i]
		if float(it["d"]) > run.d + 16.0:
			break
		if it["alive"] and str(it["kind"]) in ["squad", "barricade", "fortress"]:
			n += int(it["hp"])
	return n
