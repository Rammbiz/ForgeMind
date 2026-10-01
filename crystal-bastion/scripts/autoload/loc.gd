extends Node
## Tiny localization table. Ukrainian is the primary language, English is the fallback.

signal language_changed

const LANGS: Array[String] = ["uk", "en"]

const STRINGS := {
	"GAME_TITLE": ["Кришталевий Бастіон", "Crystal Bastion"],
	"GAME_TAGLINE": ["Захисти кристал від навали", "Defend the crystal from the horde"],
	"PLAY": ["Грати", "Play"],
	"SETTINGS": ["Налаштування", "Settings"],
	"QUIT": ["Вийти", "Quit"],
	"BACK": ["Назад", "Back"],
	"CLOSE": ["Закрити", "Close"],
	"SELECT_LEVEL": ["Оберіть рівень", "Choose a level"],
	"LOCKED": ["Закрито", "Locked"],
	"LOCKED_HINT": ["Пройдіть попередній рівень", "Beat the previous level"],
	"WAVES_N": ["%d хвиль", "%d waves"],
	"LEVEL_1": ["Зелена долина", "Green Valley"],
	"LEVEL_1_SUB": ["Тиха долина, де все починається", "A quiet valley where it all begins"],
	"LEVEL_2": ["Багряний каньйон", "Crimson Canyon"],
	"LEVEL_2_SUB": ["Дві стежки, захід сонця і вежа Тесли", "Two roads, a sunset and the Tesla tower"],
	"LEVEL_3": ["Крижаний перевал", "Frozen Pass"],
	"LEVEL_3_SUB": ["Нічна хуртовина і кришталевий промінь", "Night blizzard and the crystal beam"],
	"WAVE": ["Хвиля", "Wave"],
	"WAVE_FMT": ["Хвиля %d/%d", "Wave %d/%d"],
	"WAVE_BANNER": ["Хвиля %d", "Wave %d"],
	"START": ["Почати", "Start"],
	"NEXT_WAVE": ["Хвиля", "Wave"],
	"PAUSED": ["Пауза", "Paused"],
	"RESUME": ["Продовжити", "Resume"],
	"RESTART": ["Почати знову", "Restart"],
	"MAIN_MENU": ["Головне меню", "Main menu"],
	"LEVELS": ["Рівні", "Levels"],
	"VICTORY": ["Перемога!", "Victory!"],
	"DEFEAT": ["Кристал зруйновано", "The crystal has fallen"],
	"NEXT_LEVEL": ["Далі", "Next"],
	"RETRY": ["Ще раз", "Retry"],
	"STAT_KILLS": ["Знищено ворогів", "Enemies defeated"],
	"STAT_LIVES": ["Вціліло життів", "Lives left"],
	"STAT_GOLD": ["Зароблено золота", "Gold earned"],
	"ALL_CLEAR": ["Усі рівні пройдено! Ви — справжній вартовий.", "All levels cleared! You are a true guardian."],
	"TOWER_ARROW": ["Лучна вежа", "Archer Tower"],
	"TOWER_ARROW_DESC": ["Швидкі постріли по наземних і летючих", "Rapid shots at ground and air"],
	"TOWER_CANNON": ["Гармата", "Cannon"],
	"TOWER_CANNON_DESC": ["Вибух по площі. Лише наземні цілі", "Splash damage. Ground only"],
	"TOWER_FROST": ["Морозна вежа", "Frost Tower"],
	"TOWER_FROST_DESC": ["Сповільнює ворогів навколо цілі", "Slows enemies around the target"],
	"TOWER_TESLA": ["Вежа Тесли", "Tesla Tower"],
	"TOWER_TESLA_DESC": ["Блискавка стрибає між ворогами", "Lightning jumps between enemies"],
	"TOWER_LASER": ["Кришталевий промінь", "Crystal Beam"],
	"TOWER_LASER_DESC": ["Промінь посилюється на одній цілі", "Beam grows stronger on one target"],
	"UPGRADE": ["Покращити", "Upgrade"],
	"SELL": ["Продати", "Sell"],
	"MAX": ["МАКС", "MAX"],
	"TARGET_FIRST": ["Перший", "First"],
	"TARGET_STRONG": ["Сильний", "Strong"],
	"TARGET_CLOSE": ["Ближній", "Close"],
	"LEVEL_SHORT": ["Рів. %d", "Lv. %d"],
	"DAMAGE": ["Шкода", "Damage"],
	"RANGE": ["Дальність", "Range"],
	"RATE": ["Темп", "Rate"],
	"DPS": ["Шкода/с", "DPS"],
	"TAP_AGAIN": ["Торкніться ще раз", "Tap again"],
	"NO_AIR": ["Не б'є летючих", "Can't hit air"],
	"NOT_ENOUGH_GOLD": ["Бракує золота", "Not enough gold"],
	"ENEMY_SLIME": ["Слиз", "Slime"],
	"ENEMY_RUNNER": ["Гоблін-бігун", "Goblin Runner"],
	"ENEMY_BEETLE": ["Броньований жук", "Armored Beetle"],
	"ENEMY_BAT": ["Кажан", "Bat"],
	"ENEMY_SPLITTER": ["Ділильник", "Splitter"],
	"ENEMY_GOLEM": ["Кам'яний голем", "Stone Golem"],
	"NEW_ENEMY": ["Новий ворог: %s", "New enemy: %s"],
	"BOSS_INCOMING": ["Наближається бос!", "Boss incoming!"],
	"LAST_WAVE": ["Остання хвиля!", "Final wave!"],
	"HINT_BUILD": ["Торкніться вільної клітинки, щоб звести вежу", "Tap an empty tile to build a tower"],
	"HINT_START": ["Коли будете готові — почніть хвилю", "Start the wave when you are ready"],
	"MUSIC": ["Музика", "Music"],
	"SOUNDS": ["Звуки", "Sounds"],
	"LANGUAGE": ["Мова", "Language"],
	"LANG_NAME": ["Українська", "English"],
	"GRAPHICS": ["Графіка", "Graphics"],
	"QUALITY_HIGH": ["Висока", "High"],
	"QUALITY_LOW": ["Економна", "Battery saver"],
	"DAMAGE_NUMBERS": ["Числа шкоди", "Damage numbers"],
	"ON": ["Увімк.", "On"],
	"OFF": ["Вимк.", "Off"],
	"RESET_PROGRESS": ["Скинути прогрес", "Reset progress"],
	"RESET_CONFIRM": ["Точно? Торкніться ще раз", "Sure? Tap again"],
	"RESET_DONE": ["Прогрес скинуто", "Progress reset"],
	"STARS_TOTAL": ["Зірок: %d/%d", "Stars: %d/%d"],
}

var lang := "uk"


func _ready() -> void:
	var wanted := Save.language
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			wanted = a.trim_prefix("--lang=")
	if wanted == "":
		wanted = "uk" if OS.get_locale_language() == "uk" else "en"
	set_language(wanted, false)


func set_language(code: String, persist := true) -> void:
	lang = code if code in LANGS else "en"
	TranslationServer.set_locale(lang)
	if persist:
		Save.language = lang
		Save.save_data()
	language_changed.emit()


func next_language() -> String:
	return LANGS[(LANGS.find(lang) + 1) % LANGS.size()]


func t(key: String) -> String:
	if not STRINGS.has(key):
		return key
	var row: Array = STRINGS[key]
	return row[maxi(LANGS.find(lang), 0)]


func f(key: String, args: Array) -> String:
	return t(key) % args
