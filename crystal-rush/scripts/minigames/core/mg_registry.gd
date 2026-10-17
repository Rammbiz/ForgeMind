class_name MinigameRegistry
## The Fair's list of games (docs/design/minigames/README.md «Register a game»). A game registers by its own
## folder: scripts/minigames/<id>/info.gd with `const INFO := {...}` (+ REWARDS, COSMETICS). Every folder under
## ROOT with an info.gd is a game (the shared folder `core` and folders starting with "_" are skipped), so adding
## a game never edits a shared file and parallel branches merge without conflicts.
##
##   MinigameRegistry.list()            # every game, Fair order (INFO.order, then id); list("extra") one kind
##   MinigameRegistry.game("memory")    # one entry ({} when unknown): INFO + rewards, cosmetics, shots, dir
##   MinigameRegistry.instance("memory")  # a new MinigameGame from INFO.scene
##
## Texts: scripts/minigames/<id>/texts.gd `const ROWS := {KEY: [uk, en]}` (and core/texts.gd for the shared
## MG_ keys) are merged into Loc at startup (install_texts(), called by Loc._ready), so no game edits loc.gd.

const ROOT := "res://scripts/minigames/"
const CORE := "core"
const KINDS: Array[String] = ["minigame", "extra"]
## INFO keys every game must have. title / tent / intro / rules are Loc keys of the game's own texts.gd.
const REQUIRED: Array[String] = ["id", "kind", "scene", "host", "title", "tent", "intro", "rules", "order"]
## Cosmetic kinds a game may declare in COSMETICS ({id: {kind, name (Loc key)}}).
const COSMETIC_KINDS: Array[String] = ["title", "frame", "back"]

static var _games: Array[Dictionary] = []
static var _by_id := {}
static var _loaded := false


## Every registered game in Fair order. `kind` "" = all, else "minigame" | "extra".
static func list(kind := "") -> Array[Dictionary]:
	_load()
	var out: Array[Dictionary] = []
	for g in _games:
		if kind == "" or str(g["kind"]) == kind:
			out.append(g)
	return out


## Ids in Fair order.
static func ids(kind := "") -> Array[String]:
	var out: Array[String] = []
	for g in list(kind):
		out.append(str(g["id"]))
	return out


static func has(id: String) -> bool:
	_load()
	return _by_id.has(id)


## One game's entry ({} when unknown): the INFO keys plus `rewards` (REWARDS), `cosmetics` (COSMETICS), `shots`
## (INFO.shots or []), `dir` (its folder), `texts` (its ROWS).
static func game(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


## The REWARDS table of game `id` ({} when unknown).
static func rewards(id: String) -> Dictionary:
	return game(id).get("rewards", {})


## Every game's cosmetics: {cosmetic id: {kind, name, game}}.
static func cosmetics() -> Dictionary:
	var out := {}
	for g in list():
		var cs: Dictionary = g["cosmetics"]
		for cid in cs:
			var c: Dictionary = (cs[cid] as Dictionary).duplicate()
			c["game"] = str(g["id"])
			out[str(cid)] = c
	return out


## A new game node of `id` (INFO.scene: a .tscn whose root extends MinigameGame, or a .gd that does). Null when
## unknown or broken.
static func instance(id: String) -> MinigameGame:
	var g := game(id)
	if g.is_empty():
		return null
	var path := str(g["scene"])
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	var node: Node = null
	if res is PackedScene:
		node = (res as PackedScene).instantiate()
	elif res is GDScript:
		node = (res as GDScript).new()
	if node is MinigameGame:
		(node as MinigameGame).game_id = id
		return node
	if node:
		node.free()
	return null


## The ROWS of the shared core table plus every game's texts.gd, merged into Loc (once; idempotent).
static func install_texts() -> void:
	var loc: Node = Engine.get_main_loop().root.get_node_or_null("Loc") if Engine.get_main_loop() is SceneTree else null
	if loc == null or not loc.has_method("add_rows"):
		return
	var skipped: Array = loc.call("add_rows", _rows(ROOT + CORE + "/texts.gd"))
	for g in list():
		skipped.append_array(loc.call("add_rows", g["texts"]))
	for k in skipped:
		push_warning("MinigameRegistry: text key %s not merged (Loc STRINGS has it, or the row is broken)" % k)


## Every problem of game `id`'s registration ([] = fine): INFO keys and kind, the scene loads as a MinigameGame,
## the host has art, the Loc keys exist in its texts.gd in both languages, rewards within the Fair budget,
## cosmetics well-formed and prefixed with the game id.
static func errors(id: String) -> Array[String]:
	var out: Array[String] = []
	var g := game(id)
	if g.is_empty():
		return ["%s: not registered" % id]
	for k in REQUIRED:
		if not g.has(k):
			out.append("%s: INFO.%s missing" % [id, k])
	if not out.is_empty():
		return out
	if str(g["id"]) != str(g["dir"]).trim_suffix("/").get_file():
		out.append("%s: INFO.id must equal the folder name %s" % [id, str(g["dir"])])
	if not str(g["kind"]) in KINDS:
		out.append("%s: INFO.kind %s not in %s" % [id, str(g["kind"]), str(KINDS)])
	var node := instance(id)
	if node == null:
		out.append("%s: INFO.scene %s does not load as a MinigameGame" % [id, str(g["scene"])])
	else:
		node.free()
	var host := str(g["host"])
	if Roster.kind_of(host) == "":
		out.append("%s: INFO.host %s is not a hero or champion id" % [id, host])
	elif HeroArt.card_texture(host) == null:
		out.append("%s: INFO.host %s has no card art" % [id, host])
	var rows: Dictionary = g["texts"]
	var prefix := "MG_" + id.to_upper() + "_"
	for k2 in ["title", "tent", "intro", "rules"]:
		var key := str(g[k2])
		if not key.begins_with(prefix):
			out.append("%s: INFO.%s key %s must start with %s" % [id, k2, key, prefix])
		if not rows.has(key):
			out.append("%s: INFO.%s key %s is not in its texts.gd" % [id, k2, key])
	var title_row: Variant = rows.get(str(g["title"]))
	if title_row is Array:
		for v in (title_row as Array):
			if UIKit.font(true).get_string_size(str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x > MinigameShell.TITLE_W:
				out.append("%s: title «%s» does not fit the top bar on one line at 28 px" % [id, str(v)])
	for key2 in rows:
		if not str(key2).begins_with(prefix):
			out.append("%s: texts.gd key %s must start with %s" % [id, str(key2), prefix])
	for e in MinigamesMeta.budget_errors(g["rewards"], g["cosmetics"]):
		out.append("%s: REWARDS %s" % [id, e])
	var cs: Dictionary = g["cosmetics"]
	for cid in cs:
		var c: Variant = cs[cid]
		if not str(cid).begins_with(id + "_"):
			out.append("%s: cosmetic %s must start with %s_" % [id, str(cid), id])
		if not c is Dictionary or not str((c as Dictionary).get("kind", "")) in COSMETIC_KINDS:
			out.append("%s: cosmetic %s needs kind in %s" % [id, str(cid), str(COSMETIC_KINDS)])
		elif not rows.has(str((c as Dictionary).get("name", ""))):
			out.append("%s: cosmetic %s name key is not in its texts.gd" % [id, str(cid)])
	for s in (g["shots"] as Array):
		if not str(s).is_valid_identifier():
			out.append("%s: shot name %s must be a plain identifier" % [id, str(s)])
	return out


## Forgets the cached list (tests that add a folder).
static func reload() -> void:
	_loaded = false
	_load()


# ------------------------------------------------------------------ loading

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_games.clear()
	_by_id.clear()
	var dirs := DirAccess.get_directories_at(ROOT)
	for d in dirs:
		if d == CORE or d.begins_with("_") or d.begins_with("."):
			continue
		var dir := ROOT + d + "/"
		if not ResourceLoader.exists(dir + "info.gd"):
			continue
		var scr: Variant = load(dir + "info.gd")
		if not scr is GDScript:
			push_warning("MinigameRegistry: %sinfo.gd does not load" % dir)
			continue
		var consts: Dictionary = (scr as GDScript).get_script_constant_map()
		if not consts.get("INFO") is Dictionary:
			push_warning("MinigameRegistry: %sinfo.gd has no const INFO" % dir)
			continue
		var e: Dictionary = (consts["INFO"] as Dictionary).duplicate(true)
		e["dir"] = dir
		e["rewards"] = (consts.get("REWARDS", {}) as Dictionary).duplicate(true) if consts.get("REWARDS") is Dictionary else {}
		e["cosmetics"] = (consts.get("COSMETICS", {}) as Dictionary).duplicate(true) if consts.get("COSMETICS") is Dictionary else {}
		e["shots"] = (e.get("shots", []) as Array).duplicate() if e.get("shots") is Array else []
		e["texts"] = _rows(dir + "texts.gd")
		var id := str(e.get("id", d))
		if _by_id.has(id):
			push_warning("MinigameRegistry: game id %s registered twice (%s)" % [id, dir])
			continue
		_games.append(e)
		_by_id[id] = e
	_games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := int(a.get("order", 1000))
		var ob := int(b.get("order", 1000))
		return oa < ob if oa != ob else str(a.get("id", "")) < str(b.get("id", "")))


## `const ROWS` of a texts.gd ({} when missing).
static func _rows(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var scr: Variant = load(path)
	if not scr is GDScript:
		return {}
	var rows: Variant = (scr as GDScript).get_script_constant_map().get("ROWS")
	return (rows as Dictionary).duplicate(true) if rows is Dictionary else {}
