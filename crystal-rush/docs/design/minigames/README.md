# Ярмарок: міні-ігри. Основа і правила для будівників

Дата: 11.10.2026. Код: `crystal-rush/scripts/minigames/`. Перша гра-зразок: «Хто де? Пам’ять із витівками».

## Для вас (коротко)

**Що зроблено.**
Основа, на якій кожна міні-гра Ярмарку стоїть однаково.
Перша гра на ній: «Хто де?» (пам’ять із картками наших героїв і чемпіонів).
Тепер кожен будівник додає свою гру в окрему теку й нічого спільного не чіпає.

**Як виглядає гра.**
1. Картка-вступ: господар ятки (його картка), одна його фраза, правила, скільки нагород лишилося сьогодні, кнопка «Грати».
2. Сама гра. Угорі назва, рядок стану й кнопка паузи.
3. Підсумок: зірки (до трьох), рахунок, що саме дали, кнопки «Ще раз» і «Назад».

**Нагороди.**
- За кожну гру — 3 нагороди на день, і лише за перемоги. Програш нагороду не забирає.
- Четверта нагорода — тільки після реклами, яку гравець вмикає сам. Реклами в грі ще нема, тому цієї кнопки поки не видно. Без інтернету її теж не буде: ні звичайної, ні сірої.
- Далі грати можна скільки завгодно, уже без нагороди. Рекорд і зірки рахуються завжди.
- Що дають: монети (помітно менше, ніж кампанія), досвід Шляху, один раз трохи Зоряної руди за нові зірки (поки героїв нема, руду платимо монетами), титули й рамки карток.
- Монет за день з усього Ярмарку не більше, ніж за 6 щоденних завдань. Досвіду Шляху — не більше, ніж за одне завдання.
- День рахується за місцевим часом телефона. Якщо перевести годинник назад, нічого не скинеться і нових нагород не буде.

**Збереження.** У збереженні з’явився розділ Ярмарку. Старі збереження отримують його самі, нічого не губиться.

**Персонажі за гру.** Готовий «гачок»: гра може дати персонажа Кварц–Аметист, а Топаз і Опал — лише фрагменти. Жодна гра ним поки не користується.

**Як подивитися.** Галерея для розробки показує список ігор і запускає будь-яку (збереження не чіпає):
`godot --path crystal-rush --resolution 720x1280 res://scenes/dev/minigames_gallery.tscn`

**Що далі.** Окремо готується сам Ярмарок (частина 1: екран за кнопкою «Події», доручення, цвіт папороті). Він покаже список ігор із цієї основи. Будівники (~17) додають по одній грі.

---

## For builders: the contract (English)

Everything below is binding for every Fair game (the «minigame» kind) and for the two bigger «extra» games
(«Кристалевий Бастіон», «Січові карти»). The reference game `scripts/minigames/memory/` follows all of it: copy its
shape.

### 1. Folder layout (one folder per game; touch nothing else)

```
crystal-rush/scripts/minigames/<id>/        <id> = snake_case, also the game id
  info.gd        REQUIRED  registration: const INFO, REWARDS, COSMETICS (section 2)
  texts.gd       REQUIRED  const ROWS := {"MG_<ID>_...": ["uk", "en"]} (section 5)
  game.tscn      REQUIRED  root Control with game.gd (or point INFO.scene at a .gd that extends MinigameGame)
  game.gd        REQUIRED  extends MinigameGame (section 3)
  bot.gd         REQUIRED  func play(game, want_win) (section 9)
  selftest.gd    REQUIRED  func run(t: MinigameTest) (section 9)
  *.gd           optional  your rules / views; a global class_name must start with Mg<Id> (MgMemoryBoard)
crystal-rush/docs/design/minigames/<id>.md   REQUIRED  the game's design doc (uk summary, rules, numbers, art list)
```

The shared code lives in `scripts/minigames/core/` (do not edit it; ask the lead for a change):

| File · class | What it gives you |
|---|---|
| `mg_registry.gd` `MinigameRegistry` | finds every game folder; `list(kind)`, `ids()`, `game(id)`, `has(id)`, `rewards(id)`, `cosmetics()`, `instance(id)`, `errors(id)`, `install_texts()` |
| `mg_game.gd` `MinigameGame` | the base class of a game (section 3) |
| `mg_shell.gd` `MinigameShell` | runs a game end to end: backdrop, top bar, intro, pause, result, booking (section 4) |
| `mg_intro_card.gd` `MinigameIntroCard` | the shared intro card (host art, host line, rules, today's rewards, «Грати») |
| `mg_result_panel.gd` `MinigameResultPanel` | the shared result panel (stars, score, reward rows, ad button rule, «Ще раз», «Назад») |
| `mg_ui.gd` `MinigameUI` | still backdrop, `stars()`, `draw_star()`, `plate()`, `body()`, `draw_card_back()`, `char_name(id)`, `char_gem(id)` |
| `ads.gd` `Ads` | rewarded-ad stub: `can_show()`, `show(done)`, `DevProvider` |
| `mg_test.gd` `MinigameTest` | helpers for selftests and bots: `ok`, `eq`, `make_game`, `free_game`, `tap`, `tap_control`, `run_bot` |
| `texts.gd` | the shell's own MG_ texts |

Rules live outside the folder: `scripts/meta/minigames_meta.gd` `MinigamesMeta` (limits, booking, save section,
character hook), `EconData.FAIR` (budget numbers), `Meta.fair_*` (the facade the shell calls).

### 2. Register a game: `info.gd`

The registry loads every `scripts/minigames/<dir>/info.gd` (skipping `core` and folders starting with `_`). Adding a
game is adding a folder: no shared list, so parallel branches never conflict. (Nothing references a game's files
statically, so the APK must keep exporting all resources: `export_filter="all_resources"` in export_presets.cfg, as
now; with a narrower filter add `scripts/minigames/*` to include_filter.)

```gdscript
extends RefCounted
const INFO := {
	"id": "memory",                      # = the folder name
	"kind": "minigame",                  # "minigame" | "extra"
	"scene": "res://scripts/minigames/memory/game.tscn",
	"host": "hohotun",                   # a hero / champion id with art (owned or not)
	"title": "MG_MEMORY_TITLE",          # Loc keys in YOUR texts.gd
	"tent": "MG_MEMORY_TENT",            # the short Fair tent line
	"intro": "MG_MEMORY_INTRO",          # the host's one line (shown in «»)
	"rules": "MG_MEMORY_RULES",          # one or two lines of rules
	"order": 30,                         # Fair order, lower first (ask the lead for your number)
	"minutes": [1, 3],                   # a typical play (owner: 1-5 minutes; extra games may run longer)
	"shots": ["board", "trick", "near_win"],   # your named shot states (section 10)
}
const REWARDS := {...}                   # section 6
const COSMETICS := {"memory_frame_pairs": {"kind": "frame", "name": "MG_MEMORY_COS_FRAME"}}
```

`MinigameRegistry.errors(id)` (run by test_minigames) checks: every INFO key, `id` = folder, kind, the scene loads as a
MinigameGame, the host has card art, every INFO Loc key is in the game's texts.gd, every text key starts with
`MG_<ID>_`, rewards within budget, cosmetic ids start with `<id>_` with a kind in title | frame | back and a name key.
(The registry has `game(id)`, not `get(id)`: `get` is taken by Godot's Object.)

### 3. The game contract: `MinigameGame`

The game is the PLAY AREA only. The shell owns the title, pause, intro, result, Meta and saving.

- **Size.** Portrait 720 x 1280 canvas; the shell gives the game the rect under its 164 px top bar (720 x 1116 on a
  16:9 phone, taller on long phones). Lay out from `size` in `_on_build()` and on `resized`.
- **Input.** Touch AND mouse: touch arrives as emulated mouse events, so handle `InputEventMouseButton` /
  `InputEventMouseMotion` in `_gui_input` (or use Buttons). Never read `Input.*` in game logic. Expose a public method
  for each player action (memory: `tap_card(slot)`) so bots and tests use the same path as a finger.
- **Determinism.** Every random choice uses `rng` (seeded from `params.seed`): never `randf()`, `randi()`,
  `Array.shuffle()`, `pick_random()`, `Time.*` or frame counts in rules. Game time only moves through `tick(dt)`.
  Visual tweens are fine; rules never wait on a tween.
- **Lifecycle.** `setup(params)` (before the tree; `params = {id, seed, mode, host, manual_time}`), `_on_setup()`
  (build state from `rng`), `_on_build()` (nodes, on entering the tree), `start()` -> `_on_start()` (the intro
  closed), `tick(dt)` -> `_on_tick(dt)` (every frame, or by tests with `manual_time`; `advance(seconds)` steps many),
  `set_paused(on)` -> `_on_pause(on)` (no input, no time while paused), and exactly one
  `finish(won, score, stars, stats)`.
- **Result.** `finished(result)`: `{won, score, stars, stats, seed, time}`. A win has 1-3 stars, a loss 0 (finish()
  enforces it). `stats` = small numbers or `{key: number}`; the account sums them per game
  (`fair.games[id].counters`) for your later milestones (memory sends `tries`, `tricks`, `found {character: 1}`).
- **Status line.** `status_text()` (one short line under the title: tries, time, score); emit `status_changed`
  when it changes.
- **Mode.** `mode` ("rewarded" | "free") is only for wording; never pay anything yourself.
- **Length.** 1-5 minutes; quick moments 0.35 s; no endless idle animation (nothing loops while the player waits).

### 4. Shell, intro card, result panel (what you get for free)

`MinigameShell.open(id, opts)` -> add it full screen; it emits `closed(bundle)` and frees itself.
1. `Meta.fair_begin(id)` deals `{seed, mode}` (every start a new seed, so quitting never replays a board) and saves.
2. The intro card: host card art, «Веде гру», host name, «intro line», rules, today's line, «Грати», «Назад».
3. Play. Pause disc (top left), Android back = pause, the app leaving = pause. Pause panel: «Продовжити»,
   «Вийти з гри» (a quit books nothing and uses nothing).
4. `finish()` -> `Meta.fair_book(id, result, mode)` books and SAVES, then after 0.6 s the result panel: «Перемога!» /
   «Цього разу ні», three stars (pop once, 0.35 s each), «Рахунок», «Найкраще» or «Новий рекорд!», the reward rows
   (coins, Road XP, Star Ore or its coins, new title / frame / back) or the reason nothing was paid, rewards left
   today, the ad button (only when this win can be paid by an ad AND `Ads.can_show()`), «Ще раз», «Назад».
opts (dev / tests): `seed`, `mode`, `skip_intro`, `manual_time`, `keep_on_close`, `no_auto_pause`.

### 5. Texts

- `texts.gd`: `const ROWS := {"MG_<ID>_KEY": ["uk", "en"]}`. Ukrainian first, natural and short, plain words; English
  with its own joke where a pun needs one (Пан Коцький's «Мяу» / «Мало!» needs an English pun, not a translation).
- Merged into Loc at startup (`Loc._ready` -> `MinigameRegistry.install_texts()`); use `Loc.t("MG_<ID>_X")` /
  `Loc.f(...)`. Never hard-code player text; never edit `loc.gd`. A merged row never replaces a Loc key.
- Character names and catch phrases come from Loc (`MinigameUI.char_name(id)`, `Loc.t("ACT_<ID>")`) through `%s`.
- The title must fit the top bar on one line at 28 px (about 18 characters; `MinigameRegistry.errors` measures both
  languages). The tent line is short too: the Fair shows it on a sign.
- `tools/loc_lint.py` lints these tables like loc.gd: two non-empty strings, same placeholders in uk and en, ’ (never
  ' or ʼ), no emoji, no stray spaces, no literal number before %, the glossary of LIVE rows, M PLUS Rounded 1c
  coverage, plus: **no «…» or "..."** (wrap, never cut), keys `MG_<ID>_`, never a Loc key, never in two tables, INFO
  keys present, and the content words (never «міна»/mine: Снаряд finds a «пастка»; never «Петро Щур»; no «Carol of
  the Bells»; no «Сорочинський»).
- Labels that can grow: `autowrap_mode = AUTOWRAP_WORD_SMART` with a fixed width (`MinigameUI.body`, `plate(text,
  size, color, width)`); never clip, never shrink below 22 px on glass.

### 6. Rewards and the budget (`EconData.FAIR`, `MinigamesMeta`)

Per game and LOCAL day: **3 rewarded WINS** pay the table; a loss never pays and never uses a rewarded play (so a
quick loss can not be farmed); after the 3rd, **one** more win can be paid by a player-started rewarded ad; every other
play is free forever (best score and stars still count). One-time rewards (Star Ore, cosmetics) of a star tier are
paid by the first REWARDED win that reaches the tier. Free plays never pay, milestones included.

The table (index = stars 0..3; index 0 is always 0 / ""):

```gdscript
const REWARDS := {
	"coins": [0, 20, 30, 40],            # per rewarded win, written at frontier 1, <= FAIR.coins_3star_max (40)
	"road_xp": [0, 5, 5, 5],             # per rewarded win, <= FAIR.road_xp_play_max (5)
	"ore_once": [0, 0, 2, 3],            # once per tier; the game's total <= FAIR.ore_per_game_max (10)
	"cosmetic_once": ["", "", "memory_title_sharp_eye", "memory_frame_pairs"],   # once per tier
}
```

**The budget I assume, and why** (arsenal_design.md §6.2, §8.1, §8.3; heroes_design.md §3.4):

| Item | Rule | Why |
|---|---|---|
| Coins per rewarded win | table value x `mission_coins(frontier) / mission_coins(1)` (`EconData.fair_coins`), 3 stars <= 40 at frontier 1 | scales like the daily mission coins, so a 3-star win is <= 0.63 of a daily mission at every frontier: 40 · 75 · 115 · 180 coins at frontier 1 · 15 · 30 · 56 |
| Coins, whole Fair, per day | <= `FAIR.coins_day_missions` (6) daily missions: 384 · 720 · 1 080 · 1 704 | a player who clears every game adds at most ~6 missions a day; the campaign stays the main income (a replay win alone pays ~170 · 370 · 620 in a minute at L10 · L30 · L56) |
| Road XP per rewarded win | <= 5 (= one counted campaign win) | the Road is cosmetics + gems |
| Road XP, whole Fair, per day | <= 40 (= one daily mission) | the Fair never drives the Road; banked in `fair.road_xp` until road.gd ships |
| Star Ore | one-time tiers only, <= 10 per game (= one Weekly 5/5) | 17 games <= 170 Ore, ~1.2 % of the Workshop's 14 250; never per play |
| Ore before the heroes | paid as coins, 25 per Ore (`FAIR.ore_coins`) | «Поки героїв нема, руду й томи в нагородах заміняють монети» |
| Cosmetics | titles, card frames, card backs (`COSMETICS`) | owner decision: rewards are coins, cosmetics, a little Ore, Road XP; no power for money |

Holidays («у день свята нагорода подвійна») and the weekly Fair chest are the Fair's (part 1) job, not a game's.

### 7. Save (`fair` section, schema 1)

`EconData.fresh_account()["fair"]` = `{v, day, today {id: n}, ads {id: n}, xp_day, coins_day, road_xp, games {id:
{best_score, best_stars, plays, starts, wins, rewarded, once [tiers], ad_play, counters {}}}, cosmetics [ids], chars
[ids]}`. A save written before the Fair loads with the fresh section; `MinigamesMeta.migrate()` (called from
`SaveMigrate.sanitize_v3` on every load) creates or upgrades it in place, `sanitize()` repairs types and ranges.
Unknown game ids are kept (a game a newer build removed keeps its record). Dev and test runs (`-- --autotest`,
`--shots`) never write. **Day rule:** the counters belong to `fair.day` = floor((unix + device UTC bias) / 86 400); they
reset only when the local day is AFTER `fair.day`; a clock moved backwards resets nothing and waits until the date
passes the stored day (as the daily missions, arsenal_design.md §8.1).

### 8. Ads and characters (hooks)

- **Ads.** There is no ads SDK in the project, so `Ads.provider` is null, `Ads.can_show()` is false and no ad button
  ever shows. The AdMob plugin (WS6) sets `Ads.provider` (`can_show() -> bool`, `show(done: Callable)` calling
  `done.call(earned)`). The result panel shows the button only when the win can be paid by an ad and an ad can show;
  on success the shell calls `Meta.fair_book_ad(id, result, play_n)` (refused for an older play, a loss, or a second
  time a day).
- **Characters.** `Meta.fair_grant_character(game_id, char_id)` (`MinigamesMeta.grant_character`): a native Кварц /
  Сапфір / Аметист character joins (`got.via = "fair"`, counted as earned for the Feats); a Топаз / Опал one gets
  fragments only. Live phase only. No game uses it yet: ask the owner first.

### 9. Tests: `selftest.gd` and `bot.gd`

`scenes/dev/test_minigames.tscn` runs, for every registered game: `MinigameRegistry.errors(id)`, the texts, then
`await <selftest.gd>.new().run(t)` with a `MinigameTest`, then the bot from seeds 1, 2, 3 (must WIN, stars >= 1) and
1, 2 (must LOSE, stars 0), the same seed twice (same result), and every INFO shot. It prints
`TEST_MINIGAMES PASS: n passed, 0 failed` and exits with the failure count.

- **selftest.gd**: `func run(t: MinigameTest) -> void` (may await). Test your rules directly (pure classes), the view
  following them, one real tap through the viewport (`t.tap(pos)`: a mouse press + release, the way touch arrives),
  pause blocking input, and anything you balanced (memory prints its bot's win rate and stars over 120 seeds).
- **bot.gd**: `func play(game: MinigameGame, want_win: bool) -> void`. Plays through your public action methods and
  `game.advance(seconds)` (synchronous is best; it must end the game within a few thousand ticks). `want_win` plays
  like a good player (memory: a perfect memory that knows only what the board showed); the losing bot may read the
  board, its job is to prove a loss ends the game. A game that is not winnable from every seed must say so in its doc
  and deal only winnable boards.
- `MinigameTest`: `make_game(seed, mode, start)` (manual time, in the shell's play rect, in the tree),
  `free_game(g)`, `tap(pos)`, `tap_control(c)`, `ok(cond, what)`, `eq(a, b, what)`, `run_bot(seed, want_win)`.

### 10. Shots and the dev gallery

`scenes/dev/minigames_gallery.tscn`: no args = the list of every game (tap to play in the real shell); `--game=<id>
--seed=<n>` = play one; `--out=<dir> --tag=720 --shots=<names>` = screenshots `<dir>/<id>_<shot>_720.png`;
`-- --autotest` = every game through the shell with its bot (exit code = failures). Framework shots: `list`, `intro`,
`play`, `pause`, `result_win`, `result_lose`, `result_free` (today's rewards used, no ad), `result_ad` (an ad ready);
plus your `INFO.shots`, each set up by `prepare_shot(name)` (instant, no animation; may read your own state).
Windowed runs only on the hidden desktop, output OUTSIDE the repo:

```
bash /c/Usmishka3D/tools/hidden_godot.sh <log> 180 --path crystal-rush --resolution 720x1280 \
  res://scenes/dev/minigames_gallery.tscn -- --out=<scratchpad>/mg/<id> --tag=720 --game=<id> \
  --shots=intro,play,<your shots>,pause,result_win,result_lose,result_free,result_ad
```

LOOK at every shot and crop details at 2-3x: overlaps, clipped or cut text, «…», card corners, 1 px lines.

### 11. Look and content rules

Premium porcelain and gold (Genshin x AFK Journey), bright: 1 device-px gold lines (`UIKit.line_px(1)`), 45-degree
chamfers (`GemDraw.chamfer_rect`, never pills), one font (M PLUS Rounded 1c via `UIKit`), no text outlines, no glow, no
glossy highlights, no saturated orange gradients, nothing cartoonish; reuse `UIKit` / `UITokens` / `MinigameUI`.
No living people's names or likenesses (Мотиватор has no real name or face; Щур is never «Петро Щур»); no war or
politics; songs only folk or rights-free («Щедрик»: melody + Ukrainian text, no foreign recordings); pysanka and
embroidery patterns are our own (no church symbols, no museum copies); Снаряд is a «пастка», never a «міна». Characters
the player does not own may host and visit; never a «buy» button.

### 12. Art: code first, prompts for later

No new 3D models. Use existing art: `HeroArt.card_texture(id)` (every hero and champion), `assets/ui/kit` icons and
plates, `UIKit` widgets, or draw with code (matte; shaders stay matte). The game must look finished with code art. If
painted 2D art would make it better, list it in `docs/design/minigames/<id>.md` with a COMPLETE Gemini prompt in the
format of `docs/design/heroes_prompts.md` (the lead generates it later, with the owner's permission):

````
*Name* — `assets/minigames/<id>/<file>.png` · Налаштування: 1:1 · 2K · референс: style_anchor.png

```
Create ONE <object> for a premium mobile game UI.

FORMAT
- Aspect ratio 1:1. Resolution 2048x2048 px. The object centred, about 80 % of the frame.
- Flat solid #BFBFBF background (it will be cut out). No text, no frame, no watermark.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy for a premium
  mobile game; soft painterly rendering with crisp clean edges; delicate gold filigree; porcelain and gold.
- Lighting: warm white key light from the upper left; soft neutral fill. No glow, sparks, particles or light rays.

OBJECT
- <what it is, materials, colours (hex), size relations, details>

COLOR LOCK
- <allowed colours> · <forbidden colours>

POSE & COMPOSITION
- <view angle, how it sits in the frame, what stays empty>

AVOID
Blurry or low resolution, text, letters, numbers, watermark, logo, frame, border, UI, background objects, floor, cast
shadow, gradient or vignette background, glow, sparks, particles, light rays, thick outlines, cartoon or sticker
style, crosses or religious symbols, flags, brand marks, any resemblance to an existing game, film or comic.
```
````

### 13. Checks to run before you hand in (from the repo root, Windows paths)

```
C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path crystal-rush --import     (run it TWICE after adding
    a class_name: the first pass prints "not declared" errors until the class cache refreshes)
...console.exe --headless --path crystal-rush res://scenes/dev/test_minigames.tscn -- --autotest
...console.exe --headless --path crystal-rush res://scenes/dev/minigames_gallery.tscn -- --autotest
...console.exe --headless --path crystal-rush res://scenes/dev/<s>.tscn -- --autotest   for test_meta, test_kinds,
    test_heroes (add --no-python), test_heroes_ui, test_loc, test_juice
py crystal-rush/tools/loc_lint.py         only the 47 old [tables] errors may remain
py crystal-rush/tools/gen_heroes_data.py --check
```

Then the shots (section 10), LOOKED at. Commit only your folder, your doc and the generated `*.gd.uid` files of your
folder (stage by name, LF line endings, never screenshots).

### 14. What a builder may touch

- YES: `scripts/minigames/<id>/**`, `docs/design/minigames/<id>.md`.
- NO: `scripts/minigames/core/**`, other games' folders, `scripts/autoload/*` (Loc, Meta, Save), `scripts/core/*`,
  `scripts/meta/*`, `scripts/ui/**` (the hub is the Fair's), `project.godot`, `tools/*`, the six test scenes,
  `scenes/dev/test_minigames.tscn`, `scenes/dev/minigames_gallery.tscn`. Need a shared change (a new UI helper, a new
  sound, a reward kind)? Write it in your doc under «Потрібно від основи» and tell the lead.

### 15. For the Fair (part 1): the API

```gdscript
for g in MinigameRegistry.list():          # Fair order; g.id, g.kind, g.title, g.tent, g.host, g.order, g.minutes
	var st := Meta.fair_status(g.id)       # rewarded_left, rewarded_per_day, ad_left, mode, best_score, best_stars
var shell := MinigameShell.open(id)        # add full screen over the hub; shell.closed.connect(...)
Meta.fair_cosmetics()                      # owned cosmetic ids; MinigameRegistry.cosmetics() names them
Meta.fair_road_xp()                        # Road XP banked by the Fair
```

The reward-limit rule (3 rewarded wins per game per local day, 1 ad reward after them, the Fair-wide coin and Road XP
caps) lives in `EconData.FAIR` and `MinigamesMeta`; a Fair spec that needs other numbers changes them there, once.
The shell handles Android back itself (play -> pause, pause -> resume, intro / result -> close): while a shell is open
the Fair should leave back to it.
