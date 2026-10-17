class_name MinigameGame
extends Control
## Base of every Fair mini-game (docs/design/minigames/README.md «The game contract»). The game is the PLAY AREA
## only: MinigameShell around it shows the backdrop, the title, the pause button, the intro card and the result
## panel, books the reward and saves. A game:
##   - is portrait (720 x 1280 canvas; the shell gives it the rect under its top bar: use `size`);
##   - takes touch AND mouse: touch arrives as emulated mouse events, so handle InputEventMouseButton /
##     InputEventMouseMotion in _gui_input (or use Buttons); never read Input.* directly in game logic;
##   - is deterministic from params.seed: every random choice uses `rng` (never randf / randi / Array.shuffle /
##     pick_random), and game time advances only through tick(dt) (the shell calls it every frame; tests and bots
##     call it themselves with manual_time);
##   - ends exactly once with finish(won, score, stars, stats).
##
## Override (all optional): _on_setup() (state from params / rng, no nodes needed), _on_build() (nodes; runs on
## entering the tree), _on_start() (the intro card closed, the clock runs), _on_tick(dt), _on_pause(on),
## status_text() (one line under the title), prepare_shot(name) (a named shot state, INFO.shots).

signal finished(result: Dictionary)   ## {won, score, stars 0..3, stats {}, seed, time}; emitted once
signal status_changed                 ## status_text() changed (the shell re-reads it)

var params := {}                      ## setup() params: {id, seed, mode, host, manual_time, ...}
var rng := RandomNumberGenerator.new()
var game_id := ""
var mode := "free"                    ## "rewarded" | "free" (only for the game's own wording; the shell pays)
var manual_time := false              ## true: nothing advances unless tick() is called (tests, bots, shots)
var started := false
var paused := false
var elapsed := 0.0                    ## game seconds (sum of tick dt)
var result := {}                      ## the finished result ({} until finish())
var _built := false


## Called once before the node enters the tree. `p.seed` seeds `rng`.
func setup(p: Dictionary) -> void:
	params = p.duplicate(true)
	if p.has("id"):
		game_id = str(p["id"])
	mode = str(p.get("mode", "free"))
	manual_time = bool(p.get("manual_time", false))
	rng.seed = int(p.get("seed", 1))
	started = false
	paused = false
	elapsed = 0.0
	result = {}
	_on_setup()


func _ready() -> void:
	if not _built:
		_built = true
		_on_build()


## The intro card closed: the play begins.
func start() -> void:
	if started:
		return
	if not _built:
		_built = true
		_on_build()
	started = true
	_on_start()


func _process(delta: float) -> void:
	if not manual_time:
		tick(minf(delta, 0.1))


## Advances the game by `dt` seconds (no-op before start(), while paused and after finish()).
func tick(dt: float) -> void:
	if not started or paused or is_done():
		return
	elapsed += dt
	_on_tick(dt)


## Advances `seconds` in steps of `step` (tests, bots, shots).
func advance(seconds: float, step := 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds - 1e-6 and not is_done():
		tick(step)
		t += step


func set_paused(on: bool) -> void:
	if paused == on:
		return
	paused = on
	_on_pause(on)


func is_done() -> bool:
	return not result.is_empty()


## Ends the play (once). A win has 1..3 stars, a loss 0. `stats`: numbers (or {key: number}) the account sums per
## game for later milestones; keep them small.
func finish(won: bool, score: int, stars: int, stats: Dictionary = {}) -> void:
	if is_done():
		return
	result = {"won": won, "score": maxi(0, score), "stars": clampi(stars, 1, 3) if won else 0,
			"stats": stats.duplicate(true), "seed": int(params.get("seed", 0)), "time": snappedf(elapsed, 0.01)}
	finished.emit(result)


# ------------------------------------------------------------------ overridables

func _on_setup() -> void:
	pass


func _on_build() -> void:
	pass


func _on_start() -> void:
	pass


func _on_tick(_dt: float) -> void:
	pass


func _on_pause(_on: bool) -> void:
	pass


## One short line under the title (tries left, time, score); "" = none.
func status_text() -> String:
	return ""


## Puts the board into the named shot state (INFO.shots) for the gallery; may await.
func prepare_shot(_name: String) -> void:
	pass
