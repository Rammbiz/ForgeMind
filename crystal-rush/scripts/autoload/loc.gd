extends Node
## Tiny localization table. Ukrainian is the primary language, English is the fallback.

signal language_changed

const LANGS: Array[String] = ["uk", "en"]

const STRINGS := {
	"GAME_TITLE": ["Кришталевий Ривок", "Crystal Rush"],
	"GAME_TAGLINE": ["Веди армію, збирай зброю, бери фортецю", "Lead the army, grab the guns, take the fortress"],
	"PLAY_LEVEL": ["Рівень %d", "Level %d"],
	"LEVEL": ["Рівень %d", "Level %d"],
	"CHOOSE_HERO": ["Обери героя", "Choose your hero"],
	"HERO_BOLT": ["Блискавка", "Bolt"],
	"HERO_BOLT_DESC": ["Швидкий лис: часті блискавки здалеку", "Swift fox: rapid lightning from afar"],
	"HERO_TITAN": ["Громило", "Titan"],
	"HERO_TITAN_DESC": ["Кам'яний вартовий: важкі удари по натовпу", "Stone guardian: heavy blows that hit a crowd"],
	"ULT_STORM": ["Громовий вихор!", "Thunder vortex!"],
	"ULT_QUAKE": ["Смарагдовий розлом!", "Emerald quake!"],
	"UPGRADE_ARMY": ["Армія", "Army"],
	"UPGRADE_ARMY_DESC": ["+2 воїни на старті", "+2 soldiers at the start"],
	"UPGRADE_POWER": ["Сила героя", "Hero power"],
	"UPGRADE_POWER_DESC": ["+12% швидкість атак", "+12% attack speed"],
	"MAX": ["Макс.", "Max"],
	"VICTORY": ["Перемога!", "Victory!"],
	"DEFEAT": ["Поразка", "Defeat"],
	"FORTRESS_FALLS": ["Фортецю взято!", "The fortress falls!"],
	"ARMY_LOST": ["Армію розбито", "Your army was routed"],
	"NOT_ENOUGH": ["Забракло сил на браму", "Not enough strength for the gate"],
	"COINS_EARNED": ["+%d монет", "+%d coins"],
	"NEXT": ["Далі", "Next"],
	"RETRY": ["Ще раз", "Retry"],
	"MENU": ["Меню", "Menu"],
	"PAUSED": ["Пауза", "Paused"],
	"RESUME": ["Продовжити", "Resume"],
	"SETTINGS": ["Налаштування", "Settings"],
	"MUSIC": ["Музика", "Music"],
	"SOUND": ["Звуки", "Sounds"],
	"LANGUAGE": ["Мова", "Language"],
	"LANG_NAME": ["Українська", "English"],
	"GRAPHICS": ["Графіка", "Graphics"],
	"QUALITY_HIGH": ["Висока", "High"],
	"QUALITY_LOW": ["Економна", "Battery saver"],
	"VIBRATION": ["Вібрація", "Vibration"],
	"ON": ["Увімк.", "On"],
	"OFF": ["Вимк.", "Off"],
	"CLOSE": ["Закрити", "Close"],
	"ULT_READY": ["Ульта готова!", "Ultimate ready!"],
	"ULT": ["Ульта", "Ult"],
	"WORLD_SPACE": ["Орбітальна траса", "Orbital Track"],
	# Run: control and tutorial hints
	"DRAG_HINT": ["Тягни, щоб вести армію", "Drag to lead your army"],
	"HINT_DRAG": ["Тягни, щоб вести армію", "Drag to lead your army"],
	"HINT_GATES": ["Обирай ворота з кращим числом", "Pick the gate with the better number"],
	"HINT_FORECAST": ["Під воротами — скільки воїнів стане", "Under each gate: your army after it"],
	"HINT_CRATE": ["Стріляй по ящику — забери зброю!", "Shoot the crate to grab the weapon!"],
	"HINT_CHARGE": ["Веди героя на ворота — постріли їх перевернуть", "Aim your hero at the gate: shots flip it"],
	"HINT_ULT": ["Тисни ульту!", "Hit your ultimate!"],
	"HINT_SPIKES": ["Шипи вбивають воїнів — обходь краєм", "Spikes kill soldiers: slip past the edge"],
	"HINT_BLADES": ["Чекай, поки лезо пройде", "Wait for the blade to pass"],
	"HINT_RECRUITS": ["Збирай сірих рекрутів", "Pick up the grey recruits"],
	"HINT_ARM": ["Арбалети стріляють ще до бою", "Crossbows fire before the clash"],
	"HINT_TURRET": ["Збий турель, поки вона косить армію", "Take the turret down before it mows your army"],
	"HINT_GEODE": ["Розбий жеоду — там нагорода", "Crack the geode: there is a prize inside"],
	# Weapons and power-ups
	"NEW_WEAPON": ["Нова зброя", "New weapon"],
	"WEAPON_GOT": ["%s!", "%s!"],
	"WEAPON_UP": ["%s ★%d", "%s ★%d"],
	"W_BALLISTA": ["Балиста", "Ballista"],
	"W_CANNON": ["Плазмова гармата", "Plasma cannon"],
	"W_LASER": ["Лазер", "Laser"],
	"W_ROCKETS": ["Ракетниця", "Rocket launcher"],
	"W_DRONE": ["Дрон", "Drone"],
	"ARM_SPEAR": ["Списи", "Spears"],
	"ARM_CROSSBOW": ["Арбалети", "Crossbows"],
	"ARM_BLASTER": ["Бластери", "Blasters"],
	"ARMY_ARMED": ["Армія озброєна", "Army armed"],
	"POWER_RATE": ["+%d%% швидкість", "+%d%% attack speed"],
	"POWER_DMG": ["+%d шкода", "+%d damage"],
	"POWER_MULTI": ["+1 постріл", "+1 shot"],
	"HERO_POWER": ["Сила героя", "Hero power"],
	"ARMOR": ["Смарагдова броня!", "Emerald armour!"],
	# Result
	"STAIRS_MULT": ["×%s", "×%s"],
	"MULTIPLIER": ["Множник", "Multiplier"],
	"SURVIVORS": ["Вижило: %d", "Survivors: %d"],
	"COINS_BASE": ["За перемогу", "Victory bonus"],
	"COINS_COLLECTED": ["Зібрано", "Collected"],
	"COINS_TOTAL": ["Разом", "Total"],
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
