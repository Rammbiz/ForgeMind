class_name CratePicker
## What a "deck" crate holds (arsenal_design.md §3.5): pure and rule-based, resolved once when the
## crate comes within ArsenalData.CRATE_RESOLVE_D of the hero and then locked. The only luck is
## the weighted draw below, and the crate's forecast label shows the result before the player
## commits. Pairs call pick() twice, the second time with the first result in `exclude`.
##
## pick(deck, fielded {id: rank 1..3}, levels {id: account Lv}, rng, exclude) returns a machine
## id, or "overflow:<id>" when every fielded machine is at Rank III and nothing new fits.

## Rarity weight of a NEW pick (rarer machines show up a little less often).
const RARITY_W := ArsenalData.RARITY_PICK_W


static func pick(deck: Array, fielded: Dictionary, levels: Dictionary, rng: RandomNumberGenerator, exclude := "") -> String:
	var ex := exclude.trim_prefix("overflow:")
	var free := ArsenalData.MAX_FIELDED - fielded.size()
	var news: Array[String] = []
	if free > 0:
		for m in deck:
			var id := str(m)
			if not fielded.has(id) and id != ex and ArsenalData.is_live(id):
				news.append(id)
	var dups: Array[String] = []
	for m in fielded:
		var id2 := str(m)
		if int(fielded[m]) < 3 and id2 != ex:
			dups.append(id2)
	var use_dup := news.is_empty() or (fielded.size() >= 2 and rng.randf() < ArsenalData.DUP_SHARE_AT_2)
	if use_dup and not dups.is_empty():
		var w: Array[float] = []
		for id3 in dups:
			# Recipes (EVOLVE / FUSE) arrive in Meta-2: every duplicate weighs the same until then.
			w.append(ArsenalData.RECIPE_WEIGHT if _one_step_from_recipe(id3, fielded) else 1.0)
		return _weighted(dups, w, rng)
	if not news.is_empty():
		var w2: Array[float] = []
		for id4 in news:
			var r := ArsenalData.rarity_of(id4)
			var lv := int(levels.get(id4, EconData.START_LEVEL.get(r, 1)))
			w2.append(float(RARITY_W.get(r, 1.0)) * level_w(lv) * (2.0 if _completes_pair(id4, fielded) else 1.0))
		return _weighted(news, w2, rng)
	if not dups.is_empty():
		return dups[rng.randi() % dups.size()]
	var best := best_fielded(fielded, levels)
	if best != "":
		return "overflow:" + best
	# Nothing fielded and nothing left in the deck (a 1-machine deck in a pair): repeat it.
	for m in deck:
		if ArsenalData.is_live(str(m)):
			return str(m)
	return "drone"


## LEVEL_W(lv) = 0.75 + 0.05 x lv: stronger machines show up a little more (Lv1 0.8 .. Lv15 1.5).
static func level_w(lv: int) -> float:
	return 0.75 + 0.05 * float(lv)


## The fielded machine an overflow copy goes to: highest Rank, then highest account level.
static func best_fielded(fielded: Dictionary, levels: Dictionary) -> String:
	var best := ""
	var key := -1.0
	for m in fielded:
		var k := float(fielded[m]) * 100.0 + float(levels.get(m, 1))
		if k > key:
			key = k
			best = str(m)
	return best


## Splits "overflow:<id>" -> [id, true]; a plain id -> [id, false].
static func parse(content: String) -> Array:
	if content.begins_with("overflow:"):
		return [content.trim_prefix("overflow:"), true]
	return [content, false]


static func _weighted(ids: Array[String], w: Array[float], rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for x in w:
		total += x
	var roll := rng.randf() * total
	for k in ids.size():
		roll -= w[k]
		if roll <= 0.0:
			return ids[k]
	return ids[ids.size() - 1]


## Meta-2 (FEATURES.evolutions / fusions): a duplicate that would complete a recipe.
static func _one_step_from_recipe(_id: String, _fielded: Dictionary) -> bool:
	return false


## Meta-2: a new machine that forms a Fusion pair with a fielded one.
static func _completes_pair(_id: String, _fielded: Dictionary) -> bool:
	return false
