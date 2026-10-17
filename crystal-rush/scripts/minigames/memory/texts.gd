extends RefCounted
## Texts of «Хто де?» (uk first, then en). Merged into Loc at startup; tools/loc_lint.py checks them. Every key
## starts with MG_MEMORY_. Character names and catch phrases come from Loc (CHAMP_* / ACT_*) through %s.

const ROWS := {
	"MG_MEMORY_TITLE": ["Хто де?", "Who’s Where?"],
	"MG_MEMORY_TENT": ["Пам’ять із витівками", "Memory with tricks"],
	"MG_MEMORY_INTRO": ["Я трохи переплутаю картки. Пильнуй!", "I may shuffle a card or two. Keep your eyes open!"],
	"MG_MEMORY_RULES": ["Відкривай по дві картки й шукай пари. Деякі персонажі мають свої витівки. Знайди всі пари, поки є спроби.", "Turn two cards at a time and find the pairs. Some characters play tricks. Find every pair before your tries run out."],
	"MG_MEMORY_STATUS": ["Спроби: %s з %s · Пари: %s з %s", "Tries: %s of %s · Pairs: %s of %s"],
	"MG_MEMORY_TRICK_SWAP": ["%s: «%s» Дві картки помінялися місцями.", "%s: “%s” Two cards swapped places."],
	"MG_MEMORY_TRICK_OPEN": ["%s розгортає «%s», і ще одна пара відкривається сама.", "%s opens %s, and one more pair turns up by itself."],
	"MG_MEMORY_TRICK_PEEK": ["%s бачить наперед: сусідні картки на мить відкриті.", "%s sees ahead: the cards next door open for a moment."],
	"MG_MEMORY_TRICK_BONUS": ["%s: «%s» Ще дві спроби.", "%s: “%s” Two more tries."],
	"MG_MEMORY_TRICK_SLIP": ["%s вислизає: цей промах не рахується.", "%s slips away: this miss does not count."],
	"MG_MEMORY_COS_TITLE": ["Пильне око", "Sharp Eye"],
	"MG_MEMORY_COS_FRAME": ["Пари", "Pairs"],
}
