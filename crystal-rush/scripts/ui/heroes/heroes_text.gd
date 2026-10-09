class_name HeroesText
extends RefCounted
## Strings of the Heroes meta UI (phase H3a). Every screen asks for copy through ONE call:
##
##   HeroesText.t("PORTAL_PITY_L", [7])        # -> "Топаз або краще ≤ 7"
##   HeroesText.hero_name("vesta")             # -> "Веста"
##
## Lookup order: (1) Loc.STRINGS when the §12.4 key exists there and is not a stale Meta-1 value
## (see STALE), (2) the screen tables under scripts/ui/heroes/text/ (EXTRA_TABLES; each screen
## owner adds keys to its own file, never here), (3) the fallback table FALLBACK below,
## (4) the key itself. Key names follow heroes_design.md §12.4 and part U §6.1 with the final
## renames (Міць not Сила, Повні грані not Повна огранка, Focus 60 not 40), so H3b can move the
## rows into Loc and delete FALLBACK without touching a screen.
## No literal number in copy: every number is a %d / %s placeholder filled from data
## (heroes_design.md §12.4); no emoji code points anywhere (§9.1 lint).

## Screen-owned extra tables: each file declares `const T := {"KEY": ["uk", "en"]}`.
## Missing files are skipped, so a screen agent creates its own file and nothing else.
const EXTRA_TABLES: Array[String] = [
	"res://scripts/ui/heroes/text/text_hall.gd",
	"res://scripts/ui/heroes/text/text_showcase.gd",
	"res://scripts/ui/heroes/text/text_portal.gd",
	"res://scripts/ui/heroes/text/text_team.gd",
	"res://scripts/ui/heroes/text/text_ceremony.gd",
]

## Loc keys that already exist with a Meta-1 meaning the heroes design renames (key -> the
## Meta-1 uk value). While Loc still holds that value the fallback wins; once WS-Loc updates
## the row, Loc wins automatically.
const STALE := {
	"HERO_BOLT": "Блискавка",
	"HERO_TITAN": "Громило",
	"HERO_SEER": "Провидиця",
}

## Plural word forms [uk one, few, many, en one, en many] for HeroesText.count().
const PLURALS := {
	"tome": ["том", "томи", "томів", "Tome", "Tomes"],
	"frag": ["фрагмент", "фрагменти", "фрагментів", "fragment", "fragments"],
	"seal": ["печатка", "печатки", "печаток", "Seal", "Seals"],
	"beacon": ["маяк", "маяки", "маяків", "Beacon", "Beacons"],
	"facet": ["грань", "грані", "граней", "facet", "facets"],
	"summon": ["призов", "призови", "призовів", "summon", "summons"],
	"ore": ["руда", "руди", "руди", "Star Ore", "Star Ore"],
	"hero": ["герой", "герої", "героїв", "hero", "heroes"],
}

const FALLBACK := {
	# ---------------------------------------------------------------- heroes (§6.0)
	"HERO_TITAN": ["Горан", "Goran"], "HERO_TITAN_TITLE": ["Кам’яний велет", "The Stone Titan"],
	"HERO_ARIN": ["Арін", "Arin"], "HERO_ARIN_TITLE": ["Якір Світанку", "Anchor of Dawn"],
	"HERO_BOLT": ["Руді", "Rudi"], "HERO_BOLT_TITLE": ["Громовий лис", "Thunder Fox"],
	"HERO_EIRA": ["Ейра", "Eira"], "HERO_EIRA_TITLE": ["Сестра Інею", "Rime Sister"],
	"HERO_SEER": ["Мейра", "Meira"], "HERO_SEER_TITLE": ["Провидиця", "The Seer"],
	"HERO_ISKAR": ["Іскар", "Iskar"], "HERO_ISKAR_TITLE": ["Мисливець на комети", "Comet Hunter"],
	"HERO_VESTA": ["Веста", "Vesta"], "HERO_VESTA_TITLE": ["Сонцекута", "Sunforged"],
	"HERO_VARTAN": ["Вартан", "Vartan"], "HERO_VARTAN_TITLE": ["Серце Горна", "Forgeheart"],
	"HERO_LUMEN": ["Люмен", "Lumen"], "HERO_LUMEN_TITLE": ["Живий Опал", "The Living Opal"],
	"HERO_PAVA": ["Пава", "Pava"], "HERO_PAVA_TITLE": ["Тисячоока", "The Thousand-Eyed"],
	# ---------------------------------------------------------------- champions (§6.0)
	"CHAMP_MILA": ["Міла", "Mila"], "CHAMP_MILA_TITLE": ["Польова алхімічка", "Field Alchemist"],
	"CHAMP_MILA_ROLE": ["Повертає полеглих", "Returns the fallen"],
	"CHAMP_IVO": ["Іво", "Ivo"], "CHAMP_IVO_TITLE": ["Жаровий щит", "Brazier Shield"],
	"CHAMP_IVO_ROLE": ["Приймає удар леза", "Takes the blade hit"],
	"CHAMP_BORKO": ["Борко", "Borko"], "CHAMP_BORKO_TITLE": ["Рубака з нори", "Burrow Brawler"],
	"CHAMP_BORKO_ROLE": ["Пірнає під загін", "Dives under squads"],
	"CHAMP_ALBA": ["Альба", "Alba"], "CHAMP_ALBA_TITLE": ["Сніжне Перо", "Snowquill"],
	"CHAMP_ALBA_ROLE": ["Збиває летунів", "Downs the fliers"],
	"CHAMP_OTTO": ["Отто", "Otto"], "CHAMP_OTTO_TITLE": ["Ходяча фортеця", "Walking Fortress"],
	"CHAMP_OTTO_ROLE": ["Тримає першу сутичку", "Holds the first clash"],
	"CHAMP_TAYA": ["Тая", "Taya"], "CHAMP_TAYA_TITLE": ["Шепіт рун", "Rune Whisper"],
	"CHAMP_TAYA_ROLE": ["Присипляє загони", "Lulls the squads"],
	"CHAMP_BRANT": ["Брант", "Brant"], "CHAMP_BRANT_TITLE": ["Обсидіановий клинок", "Obsidian Blade"],
	"CHAMP_BRANT_ROLE": ["Палить у сутичці", "Burns in the clash"],
	"CHAMP_TEO": ["Тео", "Teo"], "CHAMP_TEO_TITLE": ["Зоряний картограф", "Star Cartographer"],
	"CHAMP_TEO_ROLE": ["Знаходить фантомів", "Finds the phantoms"],
	"CHAMP_OLENA": ["Олена", "Olena"], "CHAMP_OLENA_TITLE": ["Морозна знахарка", "Frost Herbalist"],
	"CHAMP_OLENA_ROLE": ["Лікує і студить", "Heals and chills"],
	"CHAMP_NIMB": ["Німб", "Nimb"], "CHAMP_NIMB_TITLE": ["Щит бурі", "Storm Aegis"],
	"CHAMP_NIMB_ROLE": ["Відводить блискавку", "Grounds the lightning"],
	"CHAMP_DARA": ["Дара", "Dara"], "CHAMP_DARA_TITLE": ["Небесна гарпунниця", "Sky Harpooner"],
	"CHAMP_DARA_ROLE": ["Зшиває загони", "Stitches squads together"],
	"CHAMP_MENHIR": ["Менгір", "Menhir"], "CHAMP_MENHIR_TITLE": ["Старійшина рун", "Rune Elder"],
	"CHAMP_MENHIR_ROLE": ["Креслить рунні кола", "Carves rune circles"],
	# ---------------------------------------------------------------- gems (§2.1; case forms part U §6.1)
	"GEM": ["Самоцвіт", "Gem"], "RARITY": ["Рідкість", "Rarity"],
	"GEM_C": ["Кварц", "Quartz"], "GEM_R": ["Сапфір", "Sapphire"], "GEM_E": ["Аметист", "Amethyst"],
	"GEM_L": ["Топаз", "Topaz"], "GEM_M": ["Опал", "Opal"],
	"GEM_C_GEN": ["Кварцу", "Quartz"], "GEM_R_GEN": ["Сапфіру", "Sapphire"], "GEM_E_GEN": ["Аметисту", "Amethyst"],
	"GEM_L_GEN": ["Топазу", "Topaz"], "GEM_M_GEN": ["Опалу", "Opal"],
	"GEM_C_PL": ["Кварців", "Quartz"], "GEM_R_PL": ["Сапфірів", "Sapphire"], "GEM_E_PL": ["Аметистів", "Amethyst"],
	"GEM_L_PL": ["Топазів", "Topaz"], "GEM_M_PL": ["Опалів", "Opal"],
	"GEM_C_ADJ": ["кварцове", "quartz"], "GEM_R_ADJ": ["сапфірове", "sapphire"], "GEM_E_ADJ": ["аметистове", "amethyst"],
	"GEM_L_ADJ": ["топазове", "topaz"], "GEM_M_ADJ": ["опалове", "opal"],
	"GEM_CUT_C": ["кругла огранка", "round cut"], "GEM_CUT_R": ["квадратна огранка", "square cut"],
	"GEM_CUT_E": ["трикутна огранка", "trillion cut"], "GEM_CUT_L": ["зіркова огранка", "star cut"],
	"GEM_CUT_M": ["маркіз", "marquise"],
	"A11Y_GEM": ["Рідкість: %s (%s)", "Rarity: %s (%s)"],
	"NATIVE": ["Корінний", "Native"], "NATIVE_GEM": ["Корінний %s", "Native %s"],
	# ---------------------------------------------------------------- tags (§5)
	"CLASS": ["Клас", "Class"], "ELEMENT": ["Стихія", "Element"], "FACTION": ["Фракція", "Faction"],
	"CLASS_WARRIOR": ["Воїн", "Warrior"], "CLASS_RANGER": ["Стрілець", "Ranger"], "CLASS_MAGE": ["Маг", "Mage"],
	"CLASS_GUARDIAN": ["Страж", "Guardian"], "CLASS_HEALER": ["Цілитель", "Healer"],
	"FACTION_DAWN": ["Орден Світанку", "Dawn Order"], "FACTION_WILDFANG": ["Дикі Ікла", "Wildfang"],
	"FACTION_STONEHEART": ["Кам’яне Серце", "Stoneheart"], "FACTION_CELESTIAL": ["Небожителі", "Celestials"],
	"FAM_KINETIC": ["Кінетика", "Kinetic"], "FAM_VOLT": ["Вольт", "Volt"], "FAM_FROST": ["Мороз", "Frost"],
	"FAM_PLASMA": ["Плазма", "Plasma"], "FAM_TECH": ["Техно", "Tech"], "FAM_RUNE": ["Руна", "Rune"],
	# ---------------------------------------------------------------- skills (§3.3, §6 sheets)
	"SKL_ULT": ["Ульта", "Ultimate"], "SKL_ATTACK": ["Атака", "Attack"], "SKL_RALLY": ["Клич", "Rally"],
	"SKL_AWAKEN": ["Пробудження", "Awakening"], "SKL_RELIC": ["Реліквія", "Relic"],
	"SKL_RANK": ["Ранг %d / %d", "Rank %d / %d"], "SKL_RANK_SHORT": ["%d / %d", "%d / %d"],
	"SKL_MAX": ["МАКС", "MAX"], "SKL_BORN": ["Від народження", "Born awakened"],
	"SKL_NATIVE_ONLY": ["Ранг %d — лише для корінних %s", "Rank %d — native %s only"],
	"SKL_FORM_NATIVE_ONLY": ["Форма %s — лише для корінних %s", "Form %s — native %s only"],
	"SKL_LOCKED_AT": ["Відкриється на рівні %d", "Opens at level\u00A0%d"],
	"SKL_AFTER_FULL": ["після Повних граней", "after Full facets"],
	"SKL_FORM": ["Форма %s", "Form %s"],
	"FORM_C": ["Кварцова форма", "Quartz form"], "FORM_R": ["Сапфірова форма", "Sapphire form"],
	"FORM_E": ["Аметистова форма", "Amethyst form"], "FORM_L": ["Топазова форма", "Topaz form"],
	"FORM_M": ["Опалова форма", "Opal form"],
	"ULT_STORM": ["Громовий вихор", "Thunder Storm"], "ULT_QUAKE": ["Смарагдовий розлом", "Emerald Quake"],
	"ULT_RIFT": ["Зоряний розлом", "Star Rift"],
	"ULT_ARIN": ["Якір з неба", "Skyfall Anchor"], "ULT_EIRA": ["Зимова літанія", "Winter Litany"],
	"ULT_ISKAR": ["Падіння комети", "Comet Fall"], "ULT_VESTA": ["Сонцесходження", "Sunrise"],
	"ULT_VARTAN": ["Кована стіна", "Forgewall"], "ULT_LUMEN": ["Спектральний вінець", "Spectral Crown"],
	"ULT_PAVA": ["Тисяча очей", "Thousand Eyes"],
	"ATK_TITAN": ["Брилобій", "Boulderfist"], "ATK_ARIN": ["Якірний удар", "Anchor Strike"],
	"ATK_BOLT": ["Розгалужений лис", "Forked Fox"], "ATK_EIRA": ["Промінь інею", "Rime Ray"],
	"ATK_SEER": ["Передбачення", "Foresight"], "ATK_ISKAR": ["Зоряна голка", "Starneedle"],
	"ATK_VESTA": ["Сонячна глефа", "Sun Glaive"], "ATK_VARTAN": ["Заклепкова гармата", "Rivet Cannon"],
	"ATK_LUMEN": ["Розщеплене світло", "Split Light"], "ATK_PAVA": ["Очі пір’я", "Feather Eyes"],
	"RALLY_TITAN": ["Кам’яна шкіра", "Stone Skin"], "RALLY_ARIN": ["Муштра Світанку", "Dawn Drill"],
	"RALLY_BOLT": ["Іскра зграї", "Pack Spark"], "RALLY_EIRA": ["Обітниця сестер", "Sisters’ Vow"],
	"RALLY_SEER": ["Передчуття", "Premonition"], "RALLY_ISKAR": ["Зоряна лінія", "Star Line"],
	"RALLY_VESTA": ["Клич Світанку", "Dawn Call"], "RALLY_VARTAN": ["Кований стрій", "Forged Rank"],
	"RALLY_LUMEN": ["Призма вівтаря", "Prism Rite"], "RALLY_PAVA": ["Вічне віяло", "Ever-Fan"],
	"AWK_TITAN": ["Кришталевий колос", "Crystal Colossus"], "AWK_ARIN": ["Розгін", "Momentum"],
	"AWK_BOLT": ["Штормовий лис", "Storm Fox"], "AWK_EIRA": ["Тиха варта", "Quiet Vigil"],
	"AWK_SEER": ["Затемнення", "Eclipse"], "AWK_ISKAR": ["Перигелій", "Perihelion"],
	"AWK_VESTA": ["Сонцестояння", "Solstice"], "AWK_VARTAN": ["Броньований марш", "Armoured March"],
	"AWK_LUMEN": ["Гра кольорів", "Play of Colour"], "AWK_PAVA": ["Пробуджені очі", "Opened Eyes"],
	"RELIC_TITAN": ["Ключ-камінь мосту", "Bridge Keystone"], "RELIC_ARIN": ["Якірний ланцюг", "Anchor Chain"],
	"RELIC_BOLT": ["Крилатий вінець", "Winged Circlet"], "RELIC_EIRA": ["Крижана струна", "Rime String"],
	"RELIC_SEER": ["Лампа рун", "Rune Lamp"], "RELIC_ISKAR": ["Уламок комети", "Comet Shard"],
	"RELIC_VESTA": ["Сонячна застібка", "Sun Clasp"], "RELIC_VARTAN": ["Ядро горна", "Forge Core"],
	"RELIC_LUMEN": ["Вінцевий уламок", "Crown Shard"], "RELIC_PAVA": ["Перо першого ока", "First-Eye Plume"],
	# champions: Action kinds (by class) and aura lines
	"ACT_WARRIOR": ["Розтин", "Cleave"], "ACT_RANGER": ["Постріл", "Shot"], "ACT_MAGE": ["Чари", "Spell"],
	"ACT_GUARDIAN": ["Блок", "Block"], "ACT_HEALER": ["Зцілення", "Mend"],
	"AURA_WARRIOR": ["Загони в сутичці втрачають більше", "Squads in contact lose more"],
	"AURA_RANGER": ["Залпи армії сильніші", "Army volleys hit harder"],
	"AURA_MAGE": ["Залпи накладають тавро", "Volleys apply Brand"],
	"AURA_GUARDIAN": ["Менше втрат у сутичках", "Fewer clash losses"],
	"AURA_HEALER": ["Менше втрат від пасток", "Fewer hazard losses"],
	"CHAMP_UI_ACTION": ["Дія", "Action"], "CHAMP_UI_AURA": ["Аура", "Aura"],
	"CHAMP_UI_TIER": ["Ярус %s", "Tier %s"],
	"CHAMP_UI_TIER_NATIVE": ["Ярус %s — лише для корінних %s", "Tier %s — native %s only"],
	"CHAMP_UI_SHARED_LEVEL": ["Рівень чемпіонів %d / %d", "Champion Level %d / %d"],
	"CHAMP_UI_LEVEL_CAP": ["Рівень чемпіонів %d / %d · більше після Світу %d", "Champion Level %d / %d · more after World %d"],
	"CHAMP_UI_AURA_NOTE": ["діє на солдатів у колі", "affects soldiers inside the ring"],
	# ---------------------------------------------------------------- currencies (§1.3, §7)
	"CUR_BEACON": ["Маяки", "Beacons"], "CUR_SEAL": ["Печатки", "Seals"], "CUR_TOME": ["Томи", "Tomes"],
	"CUR_ORE": ["Зоряна руда", "Star Ore"], "CUR_FRAGS": ["Фрагменти", "Fragments"],
	"CUR_COINS": ["Монети", "Coins"],
	"CUR_BEACON_NOTE": ["Маяки дає лише гра: перемоги, боси, завдання", "Beacons come only from play: wins, bosses, missions"],
	# ---------------------------------------------------------------- facets / recut / awakening (§3.2)
	"FACET_NAME": ["Грані", "Facets"], "FACET_FULL": ["Повні грані", "Full facets"],
	"FACET_COUNT": ["Грані %d / %d", "Facets %d / %d"],
	"FACET_ROW": ["Грані %d / %d · %d / %d фрагм.", "Facets %d / %d · %d / %d frag."],
	"FACET_CARD": ["Грані %d / %d → Повні грані: +1 межа навичок", "Facets %d / %d → Full facets: +1 skill cap"],
	"FACET_TO_NEXT": ["%d / %d до грані %d", "%d / %d to facet %d"],
	"FACET_GIVES": ["+%s до показників за грань", "+%s to stats per facet"],
	"FACET_GIVES_FULL": ["На п’ятій грані: +1 межа навичок", "At the fifth facet: +1 skill cap"],
	"FACET_FRAGS": ["%d / %d фрагм.", "%d / %d frag."],
	"FACET_MAX": ["Найвища огранка · надлишок → Томи", "Highest cut · extra → Tomes"],
	"RECUT_TITLE": ["Огранка", "Recut"], "RECUT_CTA": ["Огранити", "Recut"],
	"RECUT_TO": ["Огранити → %s", "Recut → %s"],
	"RECUT_UNLOCKS": ["Відкриває", "Unlocks"],
	"RECUT_COL_NOW": ["Зараз", "Now"], "RECUT_COL_AFTER": ["Після огранки", "After recut"],
	"RECUT_COL_NATIVE": ["Корінний %s", "Native %s"],
	"RECUT_ROW_POWER": ["Міць", "Might"], "RECUT_ROW_CAP": ["Межа рангу", "Rank cap"],
	"RECUT_ROW_FORM": ["Форма ульти", "Ult form"], "RECUT_ROW_AWAKEN": ["Пробудження", "Awakening"],
	"RECUT_ROW_TIER": ["Ярус дії", "Action tier"],
	"RECUT_FROM": ["огранений із %s", "recut from %s"],
	"RECUT_DOUBLET": ["Корінний %s · зараз %s", "Native %s · now %s"],
	"RECUT_HONEST": ["Огранений %s росте з кожною гранню, але корінний %s завжди сильніший.", "A recut %s grows with every facet, but a native %s is always stronger."],
	"RECUT_EQUAL": ["На тій самій грані корінний %s сильніший на %s", "At the same facet a native %s is %s stronger"],
	"RECUT_NEED": ["Ще %d до Повних граней", "%d more to Full facets"],
	"RECUT_COST": ["%d фрагм.", "%d frag."],
	"RECUT_MAX": ["Найвища огранка", "Highest cut"],
	"RECUT_OPAL_HEROES": ["Опал — лише для героїв", "Opal is for heroes only"],
	"RECUT_NO_DROP": ["Жодне число не падає: грані починаються з нуля", "No number drops: facets restart at zero"],
	"AWAKEN_OPEN": ["Пробудження відкрито", "Awakening open"],
	"AWAKEN_BORN": ["Корінні Топази й Опали народжуються пробудженими", "Native Topaz and Opal are born awakened"],
	"AWAKEN_NEEDS": ["Пробудження: Повні грані в Аметисті або вище", "Awakening: Full facets in Amethyst or higher"],
	# ---------------------------------------------------------------- level / power / sync (§3.1)
	"SHOW_LV": ["Рів. %d", "Lv %d"], "SHOW_LEVEL": ["Рів. %d / %d", "Lv %d / %d"],
	"SHOW_POWER": ["Міць %s", "Might %s"], "POWER": ["Міць", "Might"],
	"SHOW_SKILLS": ["Навички", "Skills"], "SHOW_DETAILS": ["Деталі", "Details"], "SHOW_3D": ["3D", "3D"],
	"SHOW_CTA_UPGRADE": ["Покращити", "Upgrade"], "SHOW_CTA_WHERE": ["Де знайти", "Where to find"],
	"SHOW_IN_TEAM": ["У команді", "In the team"],
	"SYNC_LINE": ["Синхронізовано з найкращим героєм", "Synced with your best hero"],
	"MANAGE_TAB_LEVEL": ["Рівень", "Level"], "MANAGE_TAB_FACETS": ["Грані", "Facets"],
	"MANAGE_TAB_SKILLS": ["Навички", "Skills"], "MANAGE_TAB_GEAR": ["Спорядження", "Gear"],
	"MANAGE_LEVEL_CAP": ["Макс. у цьому світі: %d", "Max in this world: %d"],
	"MANAGE_LOCKED": ["Відкриється після рівня\u00A0%d", "Unlocks after level\u00A0%d"],
	# ---------------------------------------------------------------- hall (part U §2.1)
	"HALL_TITLE": ["Зала героїв", "Hall of Heroes"],
	"HALL_TAB_HEROES": ["Герої", "Heroes"], "HALL_TAB_CHAMPIONS": ["Чемпіони", "Champions"],
	"HALL_TAB_FEATS": ["Подвиги", "Feats"],
	"HALL_COUNT": ["%d / %d", "%d / %d"],
	"HALL_FILTER_GEM": ["Рідкість", "Rarity"], "HALL_FILTER_CLASS": ["Клас", "Class"],
	"HALL_FILTER_ELEMENT": ["Стихія", "Element"], "HALL_FILTER_FACTION": ["Фракція", "Faction"],
	"HALL_SORT_GEM": ["Рідкість", "Rarity"], "HALL_SORT_POWER": ["Міць", "Might"],
	"HALL_SORT_LEVEL": ["Рівень", "Level"], "HALL_SORT_NEW": ["Нові", "New"],
	"HALL_NEW": ["НОВИЙ", "NEW"],
	"HALL_SRC_PORTAL": ["Портал", "Portal"], "HALL_SRC_SEALS": ["Печатки · %d", "Seals · %d"],
	"HALL_SRC_LEVEL": ["Після рівня\u00A0%d", "After level\u00A0%d"], "HALL_SRC_CHEST": ["Скриня героїв", "Hero Chest"],
	"HALL_WAITING": ["Нові герої чекають", "New heroes are waiting"],
	"HALL_PLATE_PORTAL": ["Портал", "Portal"], "HALL_PLATE_WORKSHOP": ["Майстерня", "Workshop"],
	"HALL_PLATE_LOCKED": ["%s · після рівня\u00A0%d", "%s · after level\u00A0%d"],
	"LOCKED": ["Закрито", "Locked"],
	# ---------------------------------------------------------------- team (§5.5, part U §2.7)
	"TEAM_TITLE": ["Команда", "Team"], "TEAM_HERO": ["Герой", "Hero"], "TEAM_CHAMPIONS": ["Чемпіони", "Champions"],
	"TEAM_AUTO": ["Підібрати", "Auto-team"], "TEAM_PRESET": ["Набір %d", "Preset %d"],
	"TEAM_SLOT_EMPTY": ["Порожньо", "Empty"], "TEAM_SLOT_LOCKED": ["Після рівня\u00A0%d", "After level\u00A0%d"],
	"TEAM_NO_MACHINE": ["%s: машин цієї стихії поки немає", "%s: no machines of this element yet"],
	"TEAM_SYNERGY": ["Синергія", "Synergy"],
	"SYN_DAWN": ["%s %s: +%d солдатів біля фортеці", "%s %s: +%d soldiers at the siege"],
	"SYN_WILDFANG": ["%s %s: +%s заряду ульти", "%s %s: +%s ult charge"],
	"SYN_STONEHEART": ["%s %s: −%s втрат від пасток", "%s %s: −%s hazard losses"],
	"SYN_CELESTIAL": ["%s %s: +%s шкоди машин", "%s %s: +%s machine damage"],
	"SYN_PAIR_WARRIOR": ["Двоє воїнів: загони в сутичці втрачають +%s", "Two Warriors: squads lose +%s in clashes"],
	"SYN_PAIR_RANGER": ["Двоє стрільців: +%s темпу героя", "Two Rangers: +%s hero attack rate"],
	"SYN_PAIR_MAGE": ["Двоє магів: +%s сили ульти", "Two Mages: +%s ult effect"],
	"SYN_PAIR_GUARDIAN": ["Двоє стражів: +%s здоров’я чемпіонів", "Two Guardians: +%s champion HP"],
	"SYN_PAIR_HEALER": ["Двоє цілителів: +%s запасу відродження", "Two Healers: +%s revive pool"],
	"SYN_AFFINITY": ["Спорідненість · %s: +%s шкоди машин", "Affinity · %s: +%s machine damage"],
	"SYN_MEMBERS": ["%s %d / %d", "%s %d / %d"],
	"SYN_NONE": ["Додай чемпіона тієї ж фракції — і команда отримає бонус", "Add a champion of the same faction for a team bonus"],
	# ---------------------------------------------------------------- portal (§7.1-§7.4)
	"PORTAL_TITLE": ["Портал", "Portal"], "PORTAL_POOL": ["Хто може з’явитися", "Who can appear"],
	"PORTAL_X1": ["Призвати ×1", "Summon ×1"], "PORTAL_X10": ["Призвати ×10", "Summon ×10"],
	"PORTAL_SUMMON": ["Призвати", "Summon"],
	"PORTAL_WELCOME": ["Вітальний призов ×10 · безкоштовно", "Welcome summon ×10 · free"],
	"PORTAL_WELCOME_RULE": ["Серед десяти — щонайменше Топаз", "At least one Topaz in these ten"],
	"PORTAL_PITY_L": ["Топаз або краще ≤ %d", "Topaz or better in ≤ %d"],
	"PORTAL_PITY_E": ["Аметист+ ≤ %d", "Amethyst+ ≤ %d"],
	"PORTAL_PITY_E_LINE": ["Аметист або краще — щонайпізніше на %d-му призові", "Amethyst or better by summon %d at the latest"],
	"PORTAL_PITY_L_LINE": ["Топаз або краще: шанс росте з %d-го призову (+%s щоразу) і гарантований на %d-му", "Topaz or better: the chance rises from summon %d (+%s each time) and is certain on summon %d"],
	"PORTAL_OPAL_LINE": ["Серед результатів «Топаз або краще»: Опал %s, Топаз %s", "Inside a Topaz-or-better result: Opal %s, Topaz %s"],
	"PORTAL_DUP_LINE": ["Спершу — герой цієї рідкості, якого в тебе ще немає", "An unowned hero of the rolled rarity comes first"],
	"PORTAL_FOCUS_60": ["Фокус: %s результатів цього самоцвіту", "Focus: %s of this gem’s results"],
	"PORTAL_FOCUS": ["Фокус", "Focus"], "PORTAL_HISTORY": ["Історія", "History"], "PORTAL_ODDS": ["Шанси", "Odds"],
	"PORTAL_SEALS": ["Печатки %d / %d → вибір: %s", "Seals %d / %d → pick: %s"],
	"PORTAL_SEALS_PICK": ["Вибір", "Pick"],
	"PORTAL_NEED": ["Потрібно %d · є %d", "Need %d · have %d"],
	"PORTAL_COST": ["%d %s", "%d %s"],
	"PORTAL_PERMANENT": ["Портал постійний: без банерів, дат і таймерів", "One permanent Portal: no banners, dates or timers"],
	"PORTAL_ODDS_TITLE": ["Шанси Порталу", "Portal odds"],
	"PORTAL_ODDS_BASE": ["За призов", "Per summon"], "PORTAL_ODDS_TOTAL": ["З гарантіями", "With guarantees"],
	"PORTAL_ODDS_ONE_IN": ["1 з %s", "1 in %s"],
	"PORTAL_ODDS_HEROES": ["Шанс кожного героя зараз", "Each hero’s chance right now"],
	"PORTAL_TOPAZ_PLUS": ["Топаз або краще", "Topaz or better"], "PORTAL_AMETHYST_PLUS": ["Аметист або краще", "Amethyst or better"],
	"PORTAL_SEAL_EARN": ["Кожен призов — +%d печатка", "Every summon: +%d Seal"],
	"SEAL_SHOP_TITLE": ["Вибір за печатками", "Pick with Seals"],
	"SEAL_PICK_CTA": ["Обрати · %s", "Choose · %s"],
	"SEAL_NOTE": ["Вибір за печатками не змінює гарантій і не дає нових печаток", "Seal picks don’t change guarantees and give no Seals"],
	"SEAL_OWNED": ["+%d фрагм.", "+%d frag."],
	"SEAL_OVERFLOW": ["+%d томів (надлишок)", "+%d Tomes (overflow)"],
	"SEAL_PRICE": ["%d печаток", "%d Seals"],
	# ---------------------------------------------------------------- summon ceremony (§9.4)
	"SUMMON_SKIP": ["Пропустити", "Skip"], "SUMMON_NEW": ["НОВИЙ", "NEW"],
	"SUMMON_TO_HERO": ["До героя: %s", "To hero: %s"],
	"SUMMON_FRAGS": ["+%d фрагм.", "+%d frag."],
	"SUMMON_SEALS_ADD": ["+%d печаток · %d / %d", "+%d Seals · %d / %d"],
	"SUMMON_SUMMARY": ["Призов ×10", "Summon ×10"],
	"SUMMON_DONE": ["Готово", "Done"],
	"CER_FULL_FACETS": ["Повні грані", "Full facets"],
	"CER_RECUT": ["Огранено: %s", "Recut: %s"],
	"CER_AWAKEN": ["Пробудження", "Awakening"],
	"CER_NEW_FORM": ["Нова форма ульти: %s", "New ult form: %s"],
	"CER_NEW_HERO": ["Новий герой", "New hero"],
	"CER_TEAM_READY": ["Команда готова", "The team is ready"],
	# ---------------------------------------------------------------- chests (§7.5)
	"CHEST_HERO": ["Скриня героїв", "Hero Chest"], "CHEST_GRAND": ["Велика скриня героїв", "Grand Hero Chest"],
	"CHEST_KNOWN": ["Вміст відомий наперед", "Contents known in advance"],
	"CHEST_TEAM_WEIGHT": ["Герой команди ×%d", "Team hero ×%d"],
	"CHEST_PITY": ["Топаз-чемпіон — щонайпізніше в %d-й скрині", "A Topaz champion by chest %d at the latest"],
	# ---------------------------------------------------------------- workshop / chronicle / codex
	"WORKSHOP_TITLE": ["Майстерня", "Workshop"],
	"WORKSHOP_NO_RANDOM": ["Без випадковостей: ти отримуєш саме те, що бачиш", "No randomness: you get exactly what you see"],
	"CHRONICLE_TITLE": ["Хроніка героя", "Hero Chronicle"],
	"CODEX_TITLE": ["Довідник", "Codex"],
	"CODEX_GEM": ["Самоцвіт: рідкість героя. Огранка піднімає самоцвіт, але корінний завжди сильніший.", "Gem: a hero’s rarity. A recut raises it, but a native is always stronger."],
	"CODEX_CLASS": ["Клас: як герой б’ється. Двоє одного класу — бонус.", "Class: how a hero fights. Two of a class give a bonus."],
	"CODEX_ELEMENT": ["Стихія: машини тієї ж стихії б’ють сильніше.", "Element: machines of the same element hit harder."],
	"CODEX_FACTION": ["Фракція: двоє, троє чи четверо разом — бонус команді.", "Faction: two, three or four together give a team bonus."],
	"CODEX_RECUT": ["Огранка: на Повних гранях самоцвіт стає наступним.", "Recut: at Full facets the gem becomes the next one."],
	# ---------------------------------------------------------------- unlocks / coach marks (§11)
	"UNL_CHAMPIONS": ["Скриня героїв: перший чемпіон іде з тобою", "Hero Chest: your first champion joins you"],
	"UNL_PORTAL": ["Портал кличе героїв", "The Portal calls heroes"],
	"UNL_SKILLS": ["Навички ростуть окремо: Томи", "Skills grow on their own: Tomes"],
	"UNL_WORKSHOP": ["Майстерня: викуй спорядження", "Workshop: forge your gear"],
	"UNL_SLOT3": ["Третій чемпіон у команді", "A third champion in the team"],
	"TUT_HALL_CARD": ["Герої ведуть армію. Торкнись, щоб роздивитися", "Heroes lead the army. Tap to take a closer look"],
	"TUT_TEAM_SLOT": ["Чемпіон б’ється сам — нічого натискати не треба", "Your champion fights on its own — no taps needed"],
	"TUT_TEAM_SYNERGY": ["Однакова фракція — бонус усій команді", "Same faction — a bonus for the whole team"],
	"TUT_TEAM_PLAY": ["Команда готова. До бою!", "The team is ready. To battle!"],
	"TUT_PORTAL_WELCOME": ["Вітальний призов: десять призовів безкоштовно", "Welcome summon: ten summons, free"],
	"TUT_PORTAL_SEALS": ["Кожен призов — печатка. Збери %d — обери Топаз сам", "Each summon gives a Seal. %d Seals: pick a Topaz"],
	"TUT_PORTAL_PITY": ["Топаз або краще — щонайменше раз на %d призовів", "Topaz or better at least once every %d summons"],
	"TUT_SHOWCASE_SWIPE": ["Свайп — наступний герой", "Swipe for the next hero"],
	"TUT_SKILLS_FREE": ["Перший ранг ульти — у подарунок", "Your first Ult rank is free"],
	"TUT_SKILLS_CAP": ["Межа рангу росте з гранями та огранкою", "The rank cap grows with facets and recuts"],
	"TUT_FACETS_FIRST": ["Фрагменти → Грані: п’ять граней — нова межа", "Fragments → Facets: five facets raise the cap"],
	"TUT_RECUT_NATIVE": ["Корінний — самоцвіт, з яким персонаж народився", "Native is the gem a character was born with"],
	"TUT_AWAKEN": ["Пробудження: четверта навичка", "Awakening: the fourth skill"],
	"TUT_WORKSHOP_FREE": ["Перше спорядження — безкоштовно", "Your first piece of gear is free"],
	# ---------------------------------------------------------------- generic
	"UI_BACK": ["Назад", "Back"], "UI_CLOSE": ["Закрити", "Close"], "UI_CONFIRM": ["Підтвердити", "Confirm"],
	"UI_NOT_BUILT": ["Екран ще будується: %s", "Screen still being built: %s"],
	"UI_ROUTE_LOCKED": ["Відкриється після рівня\u00A0%d", "Opens after level\u00A0%d"],
}

static var _extra: Dictionary = {}
static var _extra_loaded := false


## The string for `key` in the current language, formatted with `args` when given.
static func t(key: String, args: Array = []) -> String:
	var s := _raw(key)
	if args.is_empty():
		return s
	return s % args


## True when any source (Loc, a screen table, the fallback) has `key`.
static func has(key: String) -> bool:
	return _loc_value(key) != "" or _extras().has(key) or FALLBACK.has(key)


## "uk" | "en".
static func lang() -> String:
	var loc := _loc()
	return str(loc.get("lang")) if loc else "uk"


static func _raw(key: String) -> String:
	var v := _loc_value(key)
	if v != "":
		return v
	var row: Array = _extras().get(key, FALLBACK.get(key, []))
	if row.is_empty():
		return key
	return str(row[0] if lang() == "uk" else row[mini(1, row.size() - 1)])


static func _loc() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Loc")


static func _loc_value(key: String) -> String:
	var loc := _loc()
	if loc == null:
		return ""
	var table: Dictionary = loc.get("STRINGS")
	if not table.has(key):
		return ""
	var row: Array = table[key]
	if STALE.has(key) and str(row[0]) == str(STALE[key]):
		return ""
	return str(loc.call("t", key))


static func _extras() -> Dictionary:
	if _extra_loaded:
		return _extra
	_extra_loaded = true
	for p in EXTRA_TABLES:
		if not ResourceLoader.exists(p):
			continue
		var scr := load(p) as GDScript
		if scr == null:
			continue
		var tbl: Variant = scr.get_script_constant_map().get("T")
		if tbl is Dictionary:
			_extra.merge(tbl as Dictionary, true)
	return _extra


# ------------------------------------------------------------------ helpers

## Gem key "C".."M" (or "quartz".."opal") -> its uk / en name.
static func gem_name(gem: String, form := "") -> String:
	var k := gem_letter(gem)
	return t("GEM_" + k + ("_" + form if form != "" else ""))


## "quartz" / "C" / ... -> "C".."M".
static func gem_letter(gem: String) -> String:
	if gem.length() == 1:
		return gem
	var i := UITokens.GEM_ORDER.find(gem)
	return Ladder.GEMS[maxi(i, 0)]


static func hero_name(id: String) -> String:
	return t("HERO_" + id.to_upper())


static func hero_title(id: String) -> String:
	return t("HERO_" + id.to_upper() + "_TITLE")


static func champ_name(id: String) -> String:
	return t("CHAMP_" + id.to_upper())


static func champ_title(id: String) -> String:
	return t("CHAMP_" + id.to_upper() + "_TITLE")


static func champ_role(id: String) -> String:
	return t("CHAMP_" + id.to_upper() + "_ROLE")


## Hero or champion name (champions are looked up when `id` is not a hero).
static func name_of(id: String) -> String:
	return hero_name(id) if HeroData.HEROES.has(id) else champ_name(id)


static func class_label(cls: String) -> String:
	return t("CLASS_" + cls.to_upper())


static func element_label(el: String) -> String:
	return t("FAM_" + el.to_upper())


static func faction_label(fac: String) -> String:
	return t("FACTION_" + fac.to_upper())


## Skill display name: `skill` = "ult" | "attack" | "rally" | "awakened" | "relic".
## Starters keep the Meta-1 ult keys (ULT_STORM / ULT_QUAKE / ULT_RIFT, shouts lose the "!").
static func skill_name(hero_id: String, skill: String) -> String:
	var up := hero_id.to_upper()
	match skill:
		"ult":
			var kind := str((HeroData.HEROES.get(hero_id, {}) as Dictionary).get("ult", ""))
			if hero_id in HeroData.STARTERS:
				return t("ULT_" + kind.to_upper()).trim_suffix("!")
			return t("ULT_" + up)
		"attack": return t("ATK_" + up)
		"rally": return t("RALLY_" + up)
		"awakened": return t("AWK_" + up)
		"relic": return t("RELIC_" + up)
	return skill


## Skill kind label ("Ульта", "Атака", "Клич", "Пробудження").
static func skill_kind(skill: String) -> String:
	match skill:
		"ult": return t("SKL_ULT")
		"attack": return t("SKL_ATTACK")
		"rally": return t("SKL_RALLY")
		"awakened": return t("SKL_AWAKEN")
	return t("SKL_RELIC")


## Roman numeral 1..5 (ult forms, Action tiers, faction tiers).
static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## A share 0..1 as a percentage string, uk decimal comma: 0.5209 -> "52,09%", 0.6 -> "60%".
static func pct(p: float, decimals := -1) -> String:
	var v := p * 100.0
	var d := decimals
	if d < 0:
		d = 0 if absf(v - roundf(v)) < 0.005 else 2
	var s := ("%." + str(d) + "f") % v
	if lang() == "uk":
		s = s.replace(".", ",")
	return s + "%"


## Integer with thousands grouping (Loc.num).
static func num(n: int) -> String:
	var loc := _loc()
	return str(loc.call("num", n)) if loc else str(n)


## "%d <word>" with the right plural form: count(46, "tome") -> "46 томів".
static func count(n: int, word: String) -> String:
	var f: Array = PLURALS.get(word, [word, word, word, word, word])
	var w := ""
	if lang() == "uk":
		var a := absi(n)
		if a % 10 == 1 and a % 100 != 11:
			w = f[0]
		elif a % 10 in [2, 3, 4] and not (a % 100 in [12, 13, 14]):
			w = f[1]
		else:
			w = f[2]
	else:
		w = f[3] if absi(n) == 1 else f[4]
	return num(n) + " " + w


## Every fallback / extra string, for the lint test (no emoji, no literal "N%").
static func all_strings() -> Array[String]:
	var out: Array[String] = []
	for tbl: Dictionary in [FALLBACK, _extras()]:
		for k: String in tbl:
			for v in (tbl[k] as Array):
				out.append(str(v))
	return out
