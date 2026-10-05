class_name LevelGen
## Builds a level as a list of things along the bridge. Every section offers a choice between
## the two lanes; numbers follow an estimate of the army a sensible player would have, so
## later levels push harder without becoming luck.
##
## Each item: {"kind": "tile"|"gate"|"squad"|"barricade"|"coin"|"fortress", "lane": 0|1|-1,
##             "d": distance along the bridge, "value": int, "op": String (gates)}

const SECTION := 24.0


static func build(level: int, start_army: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * level + 17
	var items: Array[Dictionary] = []
	var e := float(start_army)         # expected army
	var d := 14.0
	var sections := 6 + mini(level, 8)
	var kinds := ["tiles", "gates", "barricade", "squads", "tiles", "gates", "coins", "barricade"]
	for s in sections:
		var kind: String = "tiles" if s == 0 else kinds[rng.randi() % kinds.size()]
		if s == 1:
			kind = "gates"
		var a := rng.randi() % 2          # the lane that gets the "main" option
		var b := 1 - a
		match kind:
			"tiles":
				var c := rng.randi_range(6, 9) + level / 3
				_tiles(items, a, d + 4.0, c)
				var m := maxi(3, int(round(e * rng.randf_range(0.4, 0.7))) + level * 2)
				items.append({"kind": "squad", "lane": b, "d": d + 9.0, "value": m})
				_coins(items, b, d + 13.0, 4)
				e += c
			"gates":
				var plus := int(round(minf(e, 40.0) * rng.randf_range(0.5, 1.1))) + 3 + level
				var roll := rng.randf()
				# Multipliers only while the army is small: they would snowball otherwise.
				if e > 60.0:
					roll = 0.5
				if roll < 0.45 or level < 2:
					items.append({"kind": "gate", "lane": a, "d": d + 10.0, "op": "+", "value": plus})
					items.append({"kind": "gate", "lane": b, "d": d + 10.0, "op": "x", "value": 2})
					e = maxf(e + plus, e * 2.0)
				elif roll < 0.75:
					var minus := rng.randi_range(5, 10) + level
					items.append({"kind": "gate", "lane": a, "d": d + 10.0, "op": "+", "value": plus})
					items.append({"kind": "gate", "lane": b, "d": d + 10.0, "op": "-", "value": minus})
					e += plus
				else:
					# Greed test: triple the army, but a squad waits right behind it.
					var guard := int(round(e * 1.2)) + 4 + level
					items.append({"kind": "gate", "lane": a, "d": d + 8.0, "op": "x", "value": 3})
					items.append({"kind": "squad", "lane": a, "d": d + 16.0, "value": guard})
					items.append({"kind": "gate", "lane": b, "d": d + 8.0, "op": "+", "value": plus})
					e = maxf(e + plus, e * 3.0 - guard * 0.8)
			"barricade":
				var h := 3 + level + rng.randi_range(0, 4)
				items.append({"kind": "barricade", "lane": a, "d": d + 6.0, "value": h})
				var c2 := h + 5 + rng.randi_range(0, 4)
				_tiles(items, a, d + 9.0, c2)
				var m2 := maxi(3, int(round(e * 0.5)) + level)
				items.append({"kind": "squad", "lane": b, "d": d + 10.0, "value": m2})
				e += c2 - h
			"squads":
				var small := maxi(2, int(round(e * 0.3)) + 2)
				var big := int(round(e * 0.7)) + 4 + level
				items.append({"kind": "squad", "lane": a, "d": d + 9.0, "value": small})
				items.append({"kind": "squad", "lane": b, "d": d + 9.0, "value": big})
				_coins(items, b, d + 13.0, 6)
				e = maxf(e - small * 0.6, 1.0)
			"coins":
				_tiles(items, a, d + 5.0, 5)
				_coins(items, b, d + 5.0, 8)
				e += 5
		d += SECTION
	var fortress := int(round(e * 0.5)) + 6 + level * 2
	items.append({"kind": "fortress", "lane": -1, "d": d + 8.0, "value": fortress})
	items.sort_custom(func(x: Dictionary, y: Dictionary): return float(x["d"]) < float(y["d"]))
	return {"items": items, "length": d + 8.0, "expected": e}


static func _tiles(items: Array[Dictionary], lane: int, d: float, count: int) -> void:
	for i in count:
		items.append({"kind": "tile", "lane": lane, "d": d + i * 1.2, "value": 1})


static func _coins(items: Array[Dictionary], lane: int, d: float, count: int) -> void:
	for i in count:
		items.append({"kind": "coin", "lane": lane, "d": d + i * 1.1, "value": 1})
