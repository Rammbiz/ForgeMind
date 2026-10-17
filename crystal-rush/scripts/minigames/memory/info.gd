extends RefCounted
## «Хто де? Пам’ять із витівками» (side_content_ideas.md, Group 3 #3): the Fair's reference mini-game. This file
## IS the registration: MinigameRegistry finds every scripts/minigames/<id>/info.gd.

const INFO := {
	"id": "memory",
	"kind": "minigame",                                  # "minigame" | "extra"
	"scene": "res://scripts/minigames/memory/game.tscn",
	"host": "hohotun",                                   # Гоготун hosts the tent (owned or not)
	"title": "MG_MEMORY_TITLE",                          # Loc keys of texts.gd
	"tent": "MG_MEMORY_TENT",
	"intro": "MG_MEMORY_INTRO",
	"rules": "MG_MEMORY_RULES",
	"order": 30,                                         # Fair order (lower first)
	"minutes": [1, 3],                                   # a typical play, minutes
	"shots": ["board", "trick", "near_win"],             # named shot states (game.prepare_shot)
}

## Per rewarded play by stars 0..3 (index 0 = a loss: always 0). coins are written at frontier 1 and scale like
## the daily mission coins (EconData.fair_coins); ore_once / cosmetic_once are paid once, by the first rewarded
## win that reaches the tier. Budget: EconData.FAIR (README «Rewards»).
const REWARDS := {
	"coins": [0, 20, 30, 40],
	"road_xp": [0, 5, 5, 5],
	"ore_once": [0, 0, 2, 3],
	"cosmetic_once": ["", "", "memory_title_sharp_eye", "memory_frame_pairs"],
}

## Cosmetics this game can give: {id (starts with the game id): {kind: title | frame | back, name: Loc key}}.
const COSMETICS := {
	"memory_title_sharp_eye": {"kind": "title", "name": "MG_MEMORY_COS_TITLE"},
	"memory_frame_pairs": {"kind": "frame", "name": "MG_MEMORY_COS_FRAME"},
}
