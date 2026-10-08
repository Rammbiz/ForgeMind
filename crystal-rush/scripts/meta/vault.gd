class_name Vault
## The Vault («Сховище») for Hero Chests (heroes_design.md §7.5, §12.1; WS-B). Machine Caches stay
## in vault.caches (Meta-1, Meta.open_cache); Hero Chests live next to them in vault.hero_chests so
## a 2.2.1 build reading the same file never meets an unknown Cache type. Pure and static, account
## first; the rolls themselves belong to the HeroChest roller (WS-A), which Meta calls.
##
## Entry: {type: hero_chest | grand_hero_chest, source: win | boss | weekly | expedition | unlock |
## migration | mission, level, scripted: 0 | 1 | 2}. `scripted` marks the two known-contents chests
## of §7.5 (#1 at the champions unlock: Альба with Руді as the team hero, else Отто; #2 = the next
## Hero Chest: Міла); chests {scripted} counts the scripted chests GRANTED (0..2), so neither is ever
## granted twice (result screen, catch-up card, migration).

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
static func add(acc: Dictionary, type: String, source: String, level: int, scripted := 0) -> int:
	if not type in TYPES:
		return -1
	var hc := hero_chests(acc)
	hc.append({"type": type, "source": source, "level": level, "scripted": scripted})
	return hc.size() - 1


## Removes and returns the chest at `index` ({} for a bad index).
static func take(acc: Dictionary, index: int) -> Dictionary:
	var hc := hero_chests(acc)
	if index < 0 or index >= hc.size():
		return {}
	var c: Dictionary = hc[index]
	hc.remove_at(index)
	return c


## Scripted chests granted so far (0..2).
static func scripted_granted(acc: Dictionary) -> int:
	return clampi(int((acc["chests"] as Dictionary).get("scripted", 0)), 0, 2)


## Grants scripted chest #n (1 or 2) once: books it in chests.scripted and returns the Vault entry
## (not stored; the caller opens it inline or stores it with add()), or {} when #n was already
## granted or #n - 1 was not.
static func scripted_entry(acc: Dictionary, n: int, source: String, level: int) -> Dictionary:
	if n < 1 or n > 2 or scripted_granted(acc) != n - 1:
		return {}
	(acc["chests"] as Dictionary)["scripted"] = n
	return {"type": HERO_CHEST, "source": source, "level": level, "scripted": n}


## The champion scripted chest #n shows (known contents, §7.5): #1 follows the team hero
## (PortalData.SCRIPTED_FIRST, else SCRIPTED_FIRST_DEFAULT), #2 is PortalData.SCRIPTED_SECOND.
static func scripted_champion(acc: Dictionary, n: int) -> String:
	if n == 2:
		return PortalData.SCRIPTED_SECOND
	var hero := str((acc.get("team", {}) as Dictionary).get("hero", ""))
	return str(PortalData.SCRIPTED_FIRST.get(hero, PortalData.SCRIPTED_FIRST_DEFAULT))
