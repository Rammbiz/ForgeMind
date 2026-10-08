extends RefCounted
## Hall of Heroes copy (owner: the Hall screen, scripts/ui/heroes/hall/*). Loaded by HeroesText
## (EXTRA_TABLES) after Loc and before the foundation fallback. Key families follow §12.4
## (HALL_*, CODEX_*, FEAT_*); WS-Loc moves these rows into Loc in H3b and deletes this file.
## No literal numbers: every number is a %d / %s placeholder filled from data.

const T := {
	"HALL_FILTER_ALL": ["Усі", "All"],
	"HALL_FILTER_EMPTY": ["Немає героїв із цим фільтром", "No heroes match this filter"],
	"HALL_FILTER_RESET": ["Показати всіх", "Show everyone"],
	"HALL_WHERE": ["Де знайти", "Where to find"],
	"HALL_OWNED_SHORT": ["%d з %d", "%d of %d"],
	"HALL_PORTAL_SUB": ["%s · Топаз або краще ≤ %d", "%s · Topaz or better in ≤ %d"],
	"HALL_PITY_SHORT": ["Топаз+ ≤ %d", "Topaz+ in ≤ %d"],
	"HALL_PORTAL_WELCOME": ["Вітальний призов чекає", "The welcome summon is waiting"],
	"HALL_WORKSHOP_SUB": ["%s · без випадковостей", "%s · no randomness"],
	"HALL_TEASER": ["Скоро", "Soon"],
	"HALL_TEASER_NORANDOM": ["без випадковостей", "no randomness"],
	"HALL_CHAMP_LEVEL_NOTE": ["Один рівень для всіх чемпіонів", "One level for every champion"],
	"HALL_CHAMP_ROLE_HINT": ["Чемпіони б’ються самі — у колі армії", "Champions fight on their own inside the army"],
	# Feats (§3.6; rows = HeroData.FEATS)
	"HALL_FEATS_TITLE": ["Подвиги героїв", "Hero Feats"],
	"HALL_FEATS_NOTE": ["Рахують лише те, що зароблено грою. Нагорода — Томи, ніколи Маяки.", "They count only what you earned by playing. Rewards are Tomes, never Beacons."],
	"HALL_FEATS_EMPTY": ["Подвиги з’являться разом із першим героєм", "Feats appear with your first hero"],
	"HALL_FEAT_TIER": ["Щабель %s", "Tier %s"],
	"HALL_FEAT_DONE": ["Усі щаблі пройдено", "Every tier done"],
	"HALL_FEAT_REWARD": ["Нагорода: %s", "Reward: %s"],
	"FEAT_F-61": ["Герої в колекції", "Heroes collected"],
	"FEAT_F-62": ["Огранки", "Recuts"],
	"FEAT_F-63": ["Повні грані", "Full facets"],
	"FEAT_F-64": ["Чемпіони в колекції", "Champions collected"],
	"FEAT_F-65": ["Ранги навичок", "Skill ranks"],
	"FEAT_F-66": ["Пробудження", "Awakenings"],
	"FEAT_F-70": ["Рівень чемпіонів", "Champion Level"],
	# Codex «?» (§11.3): five rows, each «де це видно»
	"CODEX_SUB": ["П’ять речей, які варто знати про героїв", "Five things worth knowing about heroes"],
	"CODEX_WHERE": ["Де видно: %s", "Where: %s"],
	"CODEX_GEM_T": ["Самоцвіт", "Gem"],
	"CODEX_CLASS_T": ["Клас", "Class"],
	"CODEX_ELEMENT_T": ["Стихія", "Element"],
	"CODEX_FACTION_T": ["Фракція", "Faction"],
	"CODEX_RECUT_T": ["Огранка", "Recut"],
	"CODEX_GEM_WHERE": ["тло картки, огранка емблеми", "the card ground, the emblem’s cut"],
	"CODEX_CLASS_WHERE": ["світлий значок на картці", "the light badge on a card"],
	"CODEX_ELEMENT_WHERE": ["темний значок на картці", "the dark badge on a card"],
	"CODEX_FACTION_WHERE": ["вітрина героя, команда", "the Showcase, the team"],
	"CODEX_RECUT_WHERE": ["подвійний камінь в емблемі", "the two-tone stone in the emblem"],
}
