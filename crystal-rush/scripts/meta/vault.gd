class_name Vault
## The Vault («Сховище») for Hero Chests (heroes_design.md §7.5, §12.1; WS-B). Machine Caches stay
## in vault.caches (Meta-1, Meta.open_cache); Hero Chests live next to them in vault.hero_chests so
## a 2.2.1 build reading the same file never meets an unknown Cache type. Pure and static, account
## first; the rolls themselves belong to the HeroChest roller (WS-A), which Meta calls.
##
## Entry: {type: hero_chest | grand_hero_chest, source: win | replay | boss | weekly | expedition |
## unlock | migration, level}. Which chests hold the two scripted champions of §7.5 is HeroChest's
## rule (the first and second chest ever OPENED, chests.scripted); the champions-unlock gift chest
## is granted once (chests.unlock_gift) by Rewards on the unlock win or by the unlock's free step.

const HERO_CHEST := "hero_chest"
const GRAND := "grand_hero_chest"
const TYPES: Array[String] = [HERO_CHEST, GRAND]


## The HeroChest roller's kind for a Vault type: "hero" | "grand" ("" for an unknown type).
static func kind_of(type: String) -> String:
	match type:
		HERO_CHEST:
			return "hero"
		GRAND:
			return "grand"
	return ""


static func type_of(kind: String) -> String:
	return GRAND if kind == "grand" else HERO_CHEST


## Hero Chests waiting in the Vault (the live array).
static func hero_chests(acc: Dictionary) -> Array:
	var v: Dictionary = acc["vault"]
	if not v.get("hero_chests") is Array:
		v["hero_chests"] = []
	return v["hero_chests"]


## Puts a Hero Chest into the Vault; returns its index (-1 for an unknown type).
static func add(acc: Dictionary, type: String, source: String, level: int) -> int:
	if not type in TYPES:
		return -1
	var hc := hero_chests(acc)
	hc.append({"type": type, "source": source, "level": level})
	return hc.size() - 1


## Removes and returns the chest at `index` ({} for a bad index).
static func take(acc: Dictionary, index: int) -> Dictionary:
	var hc := hero_chests(acc)
	if index < 0 or index >= hc.size():
		return {}
	var c: Dictionary = hc[index]
	hc.remove_at(index)
	return c


## The champions-unlock gift (the chest that opens as scripted chest #1, §11.4) once per account:
## true when it is granted now, false when it was granted before.
static func take_unlock_gift(acc: Dictionary) -> bool:
	var cs: Dictionary = acc["chests"]
	if bool(cs.get("unlock_gift", false)):
		return false
	cs["unlock_gift"] = true
	return true
