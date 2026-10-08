extends RefCounted
## Portal / Odds / Seal shop / History / Focus copy that the foundation FALLBACK table does not
## have yet (heroes_design.md §12.4 namespaces PORTAL_* and SEAL_*). Owned by the Portal screens
## (scripts/ui/summon/*). Every number is a %d / %s placeholder filled from data; no emoji.
## WS-Loc / H3b moves these rows into Loc, then this file can be deleted.

const T := {
	# ---- Portal screen
	"PORTAL_FREE": ["Безкоштовно", "Free"],
	"PORTAL_SEALS_ALL": ["Печатки %d → можна обрати %s", "Seals %d → you can pick %s"],
	"PORTAL_POOL_COUNT": ["%d героїв", "%d heroes"],
	"PORTAL_DUP_SHORT": ["Повтор: +%d фрагм.", "Repeat: +%d frag."],
	"PORTAL_BEACONS_A11Y": ["Маяки: %d", "Beacons: %d"],
	# ---- Odds sheet
	"PORTAL_ODDS_GEMS": ["Рідкість", "Rarity"],
	"PORTAL_ODDS_RULES": ["Гарантії і правила", "Guarantees and rules"],
	"PORTAL_ODDS_OWNED": ["є", "owned"],
	"PORTAL_ODDS_NOW": ["Зараз: Топаз або краще — %s наступного призову", "Now: Topaz or better — %s on the next summon"],
	"PORTAL_ODDS_SEAL_PRICES": ["Вибір за печатками: %s", "Seal picks: %s"],
	"PORTAL_ODDS_SEAL_ROW": ["%s — %d", "%s — %d"],
	"PORTAL_ODDS_CHEST": ["Скриня героїв (чемпіони)", "Hero Chest (champions)"],
	# ---- History sheet
	"PORTAL_HISTORY_TITLE": ["Історія призовів", "Summon history"],
	"PORTAL_HISTORY_EMPTY": ["Тут з’являться твої призови", "Your summons will appear here"],
	"PORTAL_HISTORY_NO": ["№ %d", "No. %d"],
	"PORTAL_HISTORY_NOTE": ["Останні %d призовів", "The last %d summons"],
	# ---- Focus sheet
	"PORTAL_FOCUS_TITLE": ["Фокус", "Focus"],
	"PORTAL_FOCUS_HELP": ["Фокус безкоштовний і змінюється будь-коли", "Focus is free and can change any time"],
	"PORTAL_FOCUS_LOCKED": ["Фокус запрацює, коли всі герої цієї рідкості будуть твоїми (%d / %d)", "Focus starts once you own every hero of this rarity (%d / %d)"],
	"PORTAL_FOCUS_NONE": ["Без фокуса", "No Focus"],
	"PORTAL_FOCUS_SOLO": ["У цій рідкості один герой — фокус не потрібен", "One hero of this rarity — no Focus needed"],
	# ---- Seal shop
	"SEAL_SECTION": ["%s · %s", "%s · %s"],
	"SEAL_NEED": ["Ще %s", "%s more"],
	"SEAL_CONFIRM": ["Так, обрати · %s", "Yes, choose · %s"],
	"SEAL_HAVE": ["У тебе %s", "You have %s"],
	"SEAL_GIVES_HERO": ["Новий герой", "New hero"],
}
