class_name HeroesGalleryShots
extends RefCounted
## Shot registry of the Heroes dev gallery (scenes/dev/heroes_gallery.tscn). One line per shot.
## A key ending in "_*" is a prefix: "showcase_vesta" matches "showcase_*" with arg "vesta", and
## "{arg}" in the uri is replaced by it. Screen agents ADD ONE LINE for a new shot; the routes
## themselves live in HeroesNav.ROUTES (a missing screen script shoots a quiet placeholder).
##
## Entry fields:
##   uri      HeroesNav URI; "hall" / "hall/<sub>" select the Heroes tab of the real hub instead
##   state    HeroesUIModel state to load before the shot (default: the --state argument)
##   wait     seconds to wait after opening (default 1.4; ceremonies add --t)
##   force    [{id, gem}] for HeroesUIModel.force_next ("{gem}" = the arg as a gem letter,
##            "{gem_hero}" = the walkout hero of that gem from WALKOUT_HERO)
##   builtin  a gallery page built in heroes_gallery.gd ("widgets", "widgets_cards")

const SHOTS := {
	"widgets": {"builtin": "widgets"},
	"widgets_cards": {"builtin": "widgets_cards"},
	"hall": {"uri": "hall"},
	"hall_champions": {"uri": "hall/champions"},
	"showcase_*": {"uri": "hero/{arg}"},
	"showcase3d_*": {"uri": "hero/{arg}/3d", "wait": 2.4},
	"manage_*": {"uri": "hero/{arg}/manage"},
	"recut_*": {"uri": "recut/{arg}"},
	"champion_*": {"uri": "champion/{arg}"},
	"team": {"uri": "team"},
	"portal": {"uri": "portal"},
	"portal_welcome": {"uri": "portal", "state": "welcome"},
	"odds": {"uri": "odds"},
	"seals": {"uri": "seals"},
	"walkout_*": {"uri": "summon/walkout/{gem}", "force": [{"id": "{gem_hero}", "gem": "{gem}"}], "wait": 0.6},
	"summary10": {"uri": "summon/x10", "wait": 0.6},
}

## The hero a walkout shot uses for each gem (the gallery's force_next).
const WALKOUT_HERO := {"C": "arin", "R": "eira", "E": "iskar", "L": "vesta", "M": "lumen"}


## The entry and arg for shot `name` ({} when unknown).
static func resolve(name: String) -> Dictionary:
	if SHOTS.has(name):
		return {"entry": SHOTS[name], "arg": ""}
	for k: String in SHOTS:
		if k.ends_with("_*") and name.begins_with(k.trim_suffix("*")):
			return {"entry": SHOTS[k], "arg": name.trim_prefix(k.trim_suffix("*"))}
	return {}
