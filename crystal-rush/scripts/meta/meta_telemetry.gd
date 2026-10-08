class_name MetaTelemetry
## Local telemetry (arsenal_design.md §9.8; never sent anywhere): attempts and wins per level,
## losses before quitting a session, session lengths, ceremony skips and a capped event log.
## A debug screen (7 taps on the version label, WS4) calls Meta -> export_json() and writes
## user://telemetry.json so the owner can replace the sim's win-chance curve with real data.
##
## Account: telemetry {levels {"<L>": {attempts, wins, losses, quits_after_loss}},
## session_lengths [s] (last 200), skips {ceremony: n}, events [{e, t, d}] (last 400), last {level, won}}.

const MAX_EVENTS := 400
const MAX_SESSIONS := 200
const EXPORT_PATH := "user://telemetry.json"
## Heroes & Champions events (heroes_design.md §12.5; local only): event -> the keys its data
## carries. The rule classes (WS-A) and Rewards / Meta (WS-B) write them with note();
## missing_keys() is the schema check test_meta runs on every event the hero flows produce.
const HERO_EVENTS := {
	"summon": ["n", "best", "e_left", "l_left", "seals", "welcome"],
	"seal_pick": ["id", "gem", "cost", "owned"],
	"chest": ["type", "best", "scripted", "inline"],
	"facet": ["kind", "id", "gem", "f"],
	"recut": ["kind", "id", "from", "to"],
	"skill_rank": ["id", "skill", "rank", "form"],
	"rewrite": ["id", "tomes_back"],
	"awaken": ["id", "born"],
	"hero_level": ["id", "lvl", "synced"],
	"champion_level": ["lvl"],
	"craft": ["item"],
	"temper": ["item", "rank"],
	"chronicle": ["id", "page"],
	"team_set": ["hero", "champions", "synergies"],
	"team_run": ["level", "hero", "champions", "synergies", "won", "lost_ids"],
	"champion_lost": ["id", "level", "t", "cause"],
	"ceremony": ["kind", "s", "skipped"],
	"migration": ["from_level", "grant"],
}


## Keys of HERO_EVENTS[event] missing from `data` ([] when complete or for a non-hero event).
static func missing_keys(event: String, data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: String in HERO_EVENTS.get(event, []):
		if not data.has(k):
			out.append(k)
	return out


## The logged rows of `event`, oldest first (tests, the debug export).
static func events_of(acc: Dictionary, event: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in (_tel(acc).get("events", []) as Array):
		if r is Dictionary and str((r as Dictionary).get("e", "")) == event:
			out.append(r)
	return out


static func _tel(acc: Dictionary) -> Dictionary:
	if not acc.get("telemetry") is Dictionary:
		acc["telemetry"] = {"levels": {}, "session_lengths": [], "skips": {}, "events": []}
	return acc["telemetry"]


## One finished attempt of `level`.
static func attempt(acc: Dictionary, level: int, won: bool, now_s := 0) -> void:
	var tl: Dictionary = _tel(acc)
	if not tl.get("levels") is Dictionary:
		tl["levels"] = {}
	var key := str(level)
	var row: Dictionary = (tl["levels"] as Dictionary).get(key, {"attempts": 0, "wins": 0, "losses": 0, "quits_after_loss": 0})
	row["attempts"] = int(row.get("attempts", 0)) + 1
	row["wins"] = int(row.get("wins", 0)) + (1 if won else 0)
	row["losses"] = int(row.get("losses", 0)) + (0 if won else 1)
	(tl["levels"] as Dictionary)[key] = row
	tl["last"] = {"level": level, "won": won}
	note(acc, "attempt", {"level": level, "won": won}, now_s)


## A session of `seconds` ended. When it ended right after a loss, that level counts a quit.
static func session(acc: Dictionary, seconds: int) -> void:
	var tl: Dictionary = _tel(acc)
	if not tl.get("session_lengths") is Array:
		tl["session_lengths"] = []
	var sl: Array = tl["session_lengths"]
	sl.append(maxi(0, seconds))
	while sl.size() > MAX_SESSIONS:
		sl.remove_at(0)
	var last: Dictionary = tl.get("last", {}) if tl.get("last") is Dictionary else {}
	if not last.is_empty() and not bool(last.get("won", true)):
		var row: Dictionary = (tl["levels"] as Dictionary).get(str(last["level"]), {})
		if not row.is_empty():
			row["quits_after_loss"] = int(row.get("quits_after_loss", 0)) + 1
		tl["last"] = {}


## The player skipped `ceremony` (inline_reveal, altar, upgrade, walkout, result ...).
static func skip(acc: Dictionary, ceremony: String) -> void:
	var tl: Dictionary = _tel(acc)
	if not tl.get("skips") is Dictionary:
		tl["skips"] = {}
	(tl["skips"] as Dictionary)[ceremony] = int((tl["skips"] as Dictionary).get(ceremony, 0)) + 1


## One event row {e, t, d}; the log keeps the last MAX_EVENTS rows.
static func note(acc: Dictionary, event: String, data: Dictionary = {}, now_s := 0) -> void:
	var tl: Dictionary = _tel(acc)
	if not tl.get("events") is Array:
		tl["events"] = []
	var ev: Array = tl["events"]
	ev.append({"e": event, "t": now_s if now_s > 0 else int(Time.get_unix_time_from_system()), "d": data})
	while ev.size() > MAX_EVENTS:
		ev.remove_at(0)


## Everything as JSON (telemetry + counters + a progress summary).
static func export_json(acc: Dictionary) -> String:
	var p: Dictionary = acc.get("progress", {})
	var out := {"version": 2, "exported": int(Time.get_unix_time_from_system()),
			"progress": {"level": p.get("level", 1), "world_reached": p.get("world_reached", 1), "boss_wins": p.get("boss_wins", 0)},
			"telemetry": _tel(acc), "counters": acc.get("counters", {}),
			"sessions": (acc.get("meta", {}) as Dictionary).get("sessions", 0)}
	return JSON.stringify(out, "\t")


## Writes export_json() to `path`. Returns the Error.
static func write_export(acc: Dictionary, path := EXPORT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(export_json(acc))
	f.close()
	return OK
