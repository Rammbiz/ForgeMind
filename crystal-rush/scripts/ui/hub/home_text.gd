class_name HomeText
## Strings the Home screen needs that Loc does not have yet (UI v2). Loc wins as soon as it
## defines the key, so moving these into scripts/autoload/loc.gd needs no code change here.
##   HomeText.t("HOME_MAIL")

const FALLBACK := {
	"HOME_EVENTS": ["Події", "Events"],
	"HOME_MAIL": ["Пошта", "Mail"],
	"HOME_QUESTS": ["Завдання", "Quests"],
	"HOME_SOON": ["%s — скоро", "%s: coming soon"],
	"NAV_PLAY": ["Грати", "Play"],
	"HOME_DECK_HINT": ["Колода", "Deck"],
}


static func t(key: String) -> String:
	var s := Loc.t(key)
	if s != key:
		return s
	var row: Array = FALLBACK.get(key, [key, key])
	return str(row[1] if Loc.lang == "en" else row[0])


static func f(key: String, args: Array) -> String:
	return t(key) % args
