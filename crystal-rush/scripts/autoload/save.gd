extends Node
## Persistent progress and settings (user://save.cfg), schema v3 (arsenal_design.md §9.2,
## meta1_contracts.md §5, heroes_design.md §12.1).
##
## The file is one ConfigFile. Every top-level key of `account` (EconData.fresh_account() shape:
## meta, progress, wallet, arsenal, heroes, barracks, ...) is a section, every key inside it a
## value; `[meta] version=3`. The legacy keys the old menu and the run still read are written
## next to them ([progress] level/coins/hero, [upgrades] army/power, [settings] music/sfx/
## language/quality/vibration) and mirrored into `level`, `coins`, `hero`, `upgrades`.
## The Meta autoload works on `account` by reference and calls save_data().
##
## Writes are atomic: temp file -> parse check -> previous file kept as .bak -> rename. A file
## that fails to load (or is not a save) falls back to the .bak.
## A save without `[meta] version` is v1 and migrates once (migrate_v1, then migrate_v2); the v1
## file is kept as save_v1_backup.cfg. A `version=2` file is read over the v3 defaults (every Meta-1
## key kept) and stamped v3 by migrate_v2 (never by migrate_v1: audit F1); the v2 file is kept once
## as save_v2_backup.cfg. The hero systems' update-day conversion (SaveMigrate.update_day) runs on
## the first load of a build where EconData.heroes_live() is true.
## Dev / test runs (--autotest, --shot) are readonly: nothing is read from or written to disk.

signal settings_changed
signal coins_changed(coins: int)

const PATH := "user://save.cfg"
const VERSION := 3
const V1_BACKUP := "user://save_v1_backup.cfg"   ## (next to `path`)
const V2_BACKUP := "user://save_v2_backup.cfg"   ## (next to `path`)
## Keys of shared sections that belong to the legacy fields, not to `account`.
const LEGACY_KEYS := {"progress": ["coins", "hero"], "settings": ["music", "sfx", "language", "quality", "vibration"]}

var level := 1                 # next level to play (1-based); mirrors account.progress.level
var coins := 0                 # mirrors account.wallet.coins
var hero := "bolt"
var upgrades := {"army": 0, "power": 0}   # legacy menu / run (retire with the old menu)
var music_volume := 0.7
var sfx_volume := 0.85
var language := ""
var quality := "high"
var vibration := true
var readonly := false          # dev/test runs must not touch the player's save
## Save v2 account (all meta sections). {} in readonly runs (Meta builds a synthetic one).
var account: Dictionary = {}
## 1 / 2 when this session migrated a v1 / v2 save (the hub shows MIGRATION_CARD for v1 via
## Meta.pending_unlocks).
var migrated_from := 0
## Where the data came from: "" new player | "main" | "bak".
var loaded_from := ""
var path := PATH


func _ready() -> void:
	load_data()


func load_data() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest") or a.begins_with("--shot"):
			readonly = true
	if readonly:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--hero="):
				hero = a.trim_prefix("--hero=")
			elif a.begins_with("--level="):
				level = maxi(1, int(a.trim_prefix("--level=")))
			elif a.begins_with("--army="):
				upgrades["army"] = maxi(0, int(a.trim_prefix("--army=")))
			elif a.begins_with("--power="):
				upgrades["power"] = maxi(0, int(a.trim_prefix("--power=")))
		return
	load_from_disk()


## Reads `path` (or its .bak), migrates v1 / v2 files and writes them back as v3 at once.
## `live` (-1 = EconData.heroes_live()) runs the hero systems' update day (tests pass 0 / 1).
func load_from_disk(live := -1) -> void:
	var is_live := EconData.heroes_live() if live < 0 else live > 0
	var res := read_file(path)
	var cfg: ConfigFile = res["cfg"]
	loaded_from = str(res["from"])
	var now := int(Time.get_unix_time_from_system())
	if cfg == null:
		account = EconData.fresh_account()
		_from_account()
		if is_live and not SaveMigrate.update_day(account, now).is_empty():
			save_data()
		return
	_read_legacy(cfg)
	var ver := int(cfg.get_value("meta", "version", 0))
	if ver >= 2:
		account = account_from_cfg(cfg)
		if ver == 2:
			migrated_from = 2
			_backup_once(V2_BACKUP)
			migrate_v2(account, now, 0)
	else:
		account = migrate_v1(cfg)
		migrated_from = 1
		_backup_once(V1_BACKUP)
		upgrades["power"] = 0        # refunded in coins by the migration
		migrate_v2(account, now, 0)
	var went_live := is_live and not SaveMigrate.update_day(account, now).is_empty()
	_from_account()
	if migrated_from > 0 or went_live:
		save_data()


## Copies the file being migrated to `backup` (next to `path`) unless a copy exists already.
func _backup_once(backup: String) -> void:
	var b := path.get_base_dir().path_join(backup.get_file())
	if FileAccess.file_exists(path) and not FileAccess.file_exists(b):
		DirAccess.copy_absolute(path, b)


func save_data() -> void:
	if readonly:
		return
	_to_account()
	write_file(path, _legacy(), account)


## Legacy field values for the file.
func _legacy() -> Dictionary:
	return {"level": level, "coins": coins, "hero": hero, "upgrades": upgrades.duplicate(), "music": music_volume,
			"sfx": sfx_volume, "language": language, "quality": quality, "vibration": vibration}


func _read_legacy(cfg: ConfigFile) -> void:
	level = maxi(1, int(cfg.get_value("progress", "level", 1)))
	coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
	hero = str(cfg.get_value("progress", "hero", hero))
	if not Balance.HEROES.has(hero):
		hero = "bolt"
	for k in upgrades:
		upgrades[k] = clampi(int(cfg.get_value("upgrades", k, 0)), 0, Balance.MAX_UPGRADE)
	music_volume = clampf(float(cfg.get_value("settings", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx", sfx_volume)), 0.0, 1.0)
	language = str(cfg.get_value("settings", "language", ""))
	quality = str(cfg.get_value("settings", "quality", quality))
	vibration = bool(cfg.get_value("settings", "vibration", vibration))


## account -> legacy mirrors (after a load).
func _from_account() -> void:
	var p: Dictionary = account["progress"]
	level = maxi(1, int(p.get("level", level)))
	coins = maxi(0, int((account["wallet"] as Dictionary).get("coins", coins)))
	if p.has("hero") and Balance.HEROES.has(str(p["hero"])):
		hero = str(p["hero"])
	p["hero"] = hero


## legacy mirrors -> account (before a write). The legacy router may have advanced `level`
## (Save.level_won) and the old menu changes `coins` (Meta mirrors both ways).
func _to_account() -> void:
	if account.is_empty():
		account = EconData.fresh_account()
	var p: Dictionary = account["progress"]
	p["level"] = maxi(int(p.get("level", 1)), level)
	level = int(p["level"])
	(account["wallet"] as Dictionary)["coins"] = coins
	p["hero"] = hero


# ======================================================================== file io (static, testable)

## Loads `p` (or its .bak when `p` is missing, unreadable or not a save).
## Returns {cfg: ConfigFile | null, from: "main" | "bak" | ""}.
static func read_file(p: String) -> Dictionary:
	for cand in [[p, "main"], [p + ".bak", "bak"]]:
		if not FileAccess.file_exists(str(cand[0])):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(str(cand[0])) == OK and (cfg.has_section("progress") or cfg.has_section("meta")):
			return {"cfg": cfg, "from": cand[1]}
	return {"cfg": null, "from": ""}


## Writes the legacy keys plus every account section to `p` atomically (tmp + parse check +
## .bak + rename). Returns OK or the failing Error.
static func write_file(p: String, legacy: Dictionary, acc: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	for section in acc:
		var sec: Variant = acc[section]
		if not sec is Dictionary:
			continue
		for key in (sec as Dictionary):
			var v: Variant = (sec as Dictionary)[key]
			if v != null:
				cfg.set_value(str(section), str(key), v)
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "level", int(legacy.get("level", 1)))
	cfg.set_value("progress", "coins", int(legacy.get("coins", 0)))
	cfg.set_value("progress", "hero", str(legacy.get("hero", "bolt")))
	var up: Dictionary = legacy.get("upgrades", {})
	for k in up:
		cfg.set_value("upgrades", str(k), int(up[k]))
	for k2 in ["music", "sfx", "language", "quality", "vibration"]:
		if legacy.has(k2):
			cfg.set_value("settings", k2, legacy[k2])
	var tmp := p + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	var check := ConfigFile.new()
	if check.load(tmp) != OK or int(check.get_value("meta", "version", 0)) != VERSION:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(p):
		DirAccess.copy_absolute(p, p + ".bak")
	return DirAccess.rename_absolute(tmp, p)


## A v2 / v3 file -> account: every section read over EconData.fresh_account() defaults (keys of the
## wrong type keep the default; unknown keys are kept for forward compatibility), then sanitised.
## A v2 file keeps `[meta] version=2` here; migrate_v2() stamps it.
static func account_from_cfg(cfg: ConfigFile) -> Dictionary:
	var acc := EconData.fresh_account()
	for section in acc:
		if not cfg.has_section(section) or not acc[section] is Dictionary:
			continue
		var tmpl: Dictionary = acc[section]
		var skip: Array = LEGACY_KEYS.get(section, [])
		for key in cfg.get_section_keys(section):
			if skip.has(key):
				continue
			var v: Variant = cfg.get_value(section, key)
			if tmpl.has(key):
				var fixed: Variant = _coerce(tmpl[key], v)
				if fixed != null:
					tmpl[key] = fixed
			elif v != null:
				tmpl[key] = v
	if cfg.has_section_key("progress", "hero"):
		(acc["progress"] as Dictionary)["hero"] = str(cfg.get_value("progress", "hero", "bolt"))
	sanitize(acc)
	return acc


## `v` converted to the type of `tmpl` (int <-> float, bool), or null when incompatible.
static func _coerce(tmpl: Variant, v: Variant) -> Variant:
	var tt := typeof(tmpl)
	var vt := typeof(v)
	if tt == vt:
		return v
	if tt == TYPE_INT and (vt == TYPE_FLOAT or vt == TYPE_BOOL):
		return int(v)
	if tt == TYPE_FLOAT and (vt == TYPE_INT or vt == TYPE_BOOL):
		return float(v)
	if tt == TYPE_BOOL and (vt == TYPE_INT or vt == TYPE_FLOAT):
		return bool(v)
	return null


## Repairs a loaded account: unknown machines dropped, every machine state has every key with
## sane values, deck presets are arrays of strings, counters are non-negative.
static func sanitize(acc: Dictionary) -> void:
	var p: Dictionary = acc["progress"]
	p["level"] = maxi(1, int(p.get("level", 1)))
	p["world_reached"] = clampi(maxi(int(p.get("world_reached", 1)), ArsenalData.world_of(int(p["level"]))), 1, 7)
	var w: Dictionary = acc["wallet"]
	for c in ["coins", "gems", "crowns", "cores"]:
		w[c] = maxi(0, int(w.get(c, 0)))
	if not w.get("wild") is Dictionary:
		w["wild"] = {}
	for r in ArsenalData.RARITY_ORDER:
		(w["wild"] as Dictionary)[r] = maxi(0, int((w["wild"] as Dictionary).get(r, 0)))
	var ms: Dictionary = (acc["arsenal"] as Dictionary)["machines"]
	for id in ms.keys():
		if not ArsenalData.MACHINES.has(str(id)) or not ms[id] is Dictionary:
			ms.erase(id)
			continue
		var st: Dictionary = ms[id]
		var base := EconData.new_machine_state(str(id), 1)
		for k in base:
			if not st.has(k) or _coerce(base[k], st[k]) == null:
				st[k] = base[k]
			else:
				st[k] = _coerce(base[k], st[k])
		st["lvl"] = clampi(int(st["lvl"]), 1, ArsenalData.MAX_LEVEL)
		st["bp"] = maxi(0, int(st["bp"]))
		var tal: Array = st["talents"]
		while tal.size() < 3:
			tal.append("")
		for i in tal.size():
			tal[i] = str(tal[i]) if tal[i] != null else ""
	for id2 in ArsenalData.START_OWNED:
		if not ms.has(id2):
			ms[id2] = EconData.new_machine_state(id2, 1)
	var ar: Dictionary = acc["arsenal"]
	var decks: Array = ar.get("decks", []) if ar.get("decks") is Array else []
	while decks.size() < 3:
		decks.append([])
	for i2 in decks.size():
		var clean: Array = []
		if decks[i2] is Array:
			for id3 in decks[i2]:
				if ms.has(str(id3)) and not clean.has(str(id3)):
					clean.append(str(id3))
		decks[i2] = clean
	ar["decks"] = decks
	ar["deck_active"] = clampi(int(ar.get("deck_active", 0)), 0, decks.size() - 1)
	var un: Dictionary = acc["unlocks"]
	for k2 in ["done", "pending"]:
		if not un.get(k2) is Array:
			un[k2] = []
	SaveMigrate.sanitize_v3(acc)


## v2 -> v3 (heroes_design.md §12.3): lossless and idempotent. The schema step only (every Meta-1
## key kept, nothing granted); the update-day conversion and lump grant run with `live`
## (EconData.heroes_live() by default). Returns the account.
static func migrate_v2(acc: Dictionary, now_s := 0, live := -1) -> Dictionary:
	SaveMigrate.migrate_v2(acc, now_s, EconData.heroes_live() if live < 0 else live > 0)
	return acc


## v1 -> v2 (§9.2): keeps the level; grants every NEW machine whose crate is behind the player
## (rarity start level); one Boss Core, boss win and Glory step per boss level passed (on the
## hero last used); upgrades.army -> Barracks Recruits (above the world cap kept as a
## grandfathered bonus); upgrades.power refunded in coins; Crown 1 on every cleared level;
## the UnlockQueue catch-up tour and the one-time MIGRATION_CARD.
static func migrate_v1(cfg: ConfigFile) -> Dictionary:
	var acc := EconData.fresh_account()
	var lvl := maxi(1, int(cfg.get_value("progress", "level", 1)))
	var h := str(cfg.get_value("progress", "hero", "bolt"))
	if not (acc["heroes"] as Dictionary).has(h):
		h = "bolt"
	var p: Dictionary = acc["progress"]
	p["level"] = lvl
	p["world_reached"] = ArsenalData.world_of(lvl)
	p["hero"] = h
	var w: Dictionary = acc["wallet"]
	w["coins"] = maxi(0, int(cfg.get_value("progress", "coins", 0)))
	# NEW machines behind the player.
	var ms: Dictionary = (acc["arsenal"] as Dictionary)["machines"]
	var seen: Dictionary = (acc["arsenal"] as Dictionary)["seen"]
	for id in ArsenalData.live_ids():
		var at := ArsenalData.new_crate_level(id)
		if at > 0 and at < lvl and not ms.has(id):
			ms[id] = EconData.new_machine_state(id, int(EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
		if ms.has(id):
			seen[id] = true
	# Bosses passed.
	var bosses := 0
	for l in range(1, lvl):
		if ArsenalData.is_boss(l):
			bosses += 1
	p["boss_wins"] = bosses
	w["cores"] = bosses
	var hs: Dictionary = (acc["heroes"] as Dictionary)[h]
	hs["boss_wins"] = bosses
	var glory := 1
	for need in EconData.GLORY_AT_BOSS_WINS:
		if bosses >= need:
			glory += 1
	hs["glory"] = glory
	# Old coin upgrades.
	var army := clampi(int(cfg.get_value("upgrades", "army", 0)), 0, Balance.MAX_UPGRADE)
	var power := clampi(int(cfg.get_value("upgrades", "power", 0)), 0, Balance.MAX_UPGRADE)
	var b: Dictionary = acc["barracks"]
	var cap := EconData.barracks_cap(int(p["world_reached"]))
	b["recruits"] = mini(mini(EconData.BARRACKS_MAX, army), cap)
	if army - int(b["recruits"]) > 0:
		(b["grandfathered"] as Dictionary)["recruits"] = mini(EconData.BARRACKS_MAX, army) - int(b["recruits"])
	var refund := 0
	for i in power:
		refund += Balance.upgrade_cost("power", i)
	w["coins"] = int(w["coins"]) + refund
	# Crowns: Crown 1 for every cleared level (banked).
	var cb: Dictionary = p["crowns_best"]
	for l2 in range(1, lvl):
		cb[l2] = 1
	w["crowns"] = lvl - 1
	if lvl > 1:
		(acc["counters"] as Dictionary)["wins"] = lvl - 1
	# Catch-up tour + the one-time card.
	(acc["meta"] as Dictionary)["migrated_from"] = 1
	(acc["meta"] as Dictionary)["migration_refund"] = refund
	if lvl > 1 or army > 0 or power > 0:
		(acc["unlocks"] as Dictionary)["cards"] = ["MIGRATION_CARD"]
		UnlockQueue.start_catch_up(acc, lvl)
	return acc


# ======================================================================== legacy menu API

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	save_data()


func upgrade_cost(kind: String) -> int:
	return Balance.upgrade_cost(kind, int(upgrades[kind]))


func can_upgrade(kind: String) -> bool:
	return int(upgrades[kind]) < Balance.MAX_UPGRADE and coins >= upgrade_cost(kind)


func buy_upgrade(kind: String) -> bool:
	if not can_upgrade(kind):
		return false
	var cost := upgrade_cost(kind)
	upgrades[kind] = int(upgrades[kind]) + 1
	add_coins(-cost)
	return true


func set_hero(type: String) -> void:
	if Balance.HEROES.has(type):
		hero = type
		save_data()


func level_won() -> void:
	level += 1
	save_data()


func apply_settings() -> void:
	save_data()
	apply_performance()
	settings_changed.emit()


## Battery saver: lower render resolution and frame cap.
func apply_performance() -> void:
	var high := quality == "high"
	Engine.max_fps = 60 if high else 30
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 1.0 if high else 0.75


## Short haptic pulse on phones (no-op elsewhere or when disabled).
func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
