# ForgeMind: notes for any Claude Code session (local or cloud)

The repo holds several unrelated things. The live project is **`crystal-rush/`** (Godot 4.7, GL Compatibility): «Кришталевий Ривок /
Crystal Rush», a portrait mobile crowd-runner with a deep gacha meta (heroes, champions, Portal, Workshop). `crystal-bastion/` is an
older Godot project; the Python files in the root are unrelated CAD tools. Work only in `crystal-rush/` unless asked.
All paths below are from the repo root.

## The owner and how to work with them
- The owner writes Ukrainian, reads on a phone. Reply in Ukrainian, plainly, no jargon. Use they/them for the owner.
- Chain work without pausing; report often. Send screenshots with `SendUserFile` if the session has it; if not, say so in one line
  and describe the shot. Never push PNGs just to show them. Give COMPLETE art prompts with all technical data (format:
  `crystal-rush/docs/design/heroes_prompts.md`).
- The look the owner wants: premium "heavy luxe", Genshin x AFK Journey fusion, bright, 1 device-px gold lines, 45-degree chamfers
  (never pills), one font (M PLUS Rounded 1c), no text outlines. The owner dislikes anything that "reeks of AI": saturated orange
  gradients, glossy highlights, glows, cartoonish stickers.
- Art arrives as chat images with random names. Never ask the owner to rename anything: identify the character and kind
  (splash / card / sheet) by looking. If you cannot find the file on disk, ask where it was saved.
- Do not spend Higgsfield credits without asking. Never send the owner's email anywhere. No PR unless asked.
- Commits: clear message; end it with exactly the attribution lines your harness asks for (as given, even if they name a model; add
  none if none are given). No model names anywhere else: commit text, PR text, code comments, docs.

## Secrets and git
- Never ask for keys or tokens in chat and never write one into a repo file. The repo is PUBLIC. The root `.env` is tracked: never
  add keys to it and never print it; tell the owner once that the Telegram token in it should be rotated. Keys go into Windows user
  environment variables that the owner sets themselves (then restarts the Claude app). Never create a variable named
  `ANTHROPIC_API_KEY` (Claude Code would switch to API-key login).
- Branch `ccr-ea3be44f-lbour0`. A cloud session works on the same branch. Start with `git fetch`, `git status`, `git pull --ff-only`;
  before pushing `git pull --rebase`. Never force-push or rewrite pushed history; on a conflict stop and tell the owner.
- Stage files by name (no `git add -A`). Never commit `.claude/`, screenshots or `crystal-bastion/` changes. Modified
  `crystal-bastion/**/*.import` files are Godot churn: `git restore crystal-bastion` (ask if anything else changed there).
- Windows line endings: run `git ls-files --eol crystal-rush/tools/data/heroes_consts.json`. If it shows `w/crlf`, the generator
  `--check` falsely says OUT OF DATE (it hashes raw JSON bytes). Do NOT regenerate or commit stamps; tell the owner and, with their OK
  and no uncommitted work, `git config core.autocrlf false`, then `git rm -r -q --cached crystal-rush` and
  `git checkout HEAD -- crystal-rush` (a plain `git checkout` leaves the CRLF files as they are). Never commit CRLF files.

## Where things are (crystal-rush/)
- Design docs in `docs/design/`: `heroes_design.md` (the rules, §-numbered; source of truth for numbers), `heroes_prompts.md` (art
  prompts for every character; §1.7 Meshy, §2 order of work), `heroes_ua_icons.md` (shortlist of Ukrainian icons as future
  characters: 11 top picks, Сірко and Ольга done, plus "later" and "do not take" lists). `ui_v3_spec.md` arrives with the ui-v3 merge.
- Game data is GENERATED, never hand-typed. Edit `tools/heroes_sim.py` / `tools/heroes_tables.py` / the design doc, then
  `python3 crystal-rush/tools/gen_heroes_data.py --refresh` (rebuilds `tools/data/heroes_roster.json` and the generated blocks of
  `scripts/core/{ladder,hero_data,champion_data,team_data,portal_data,ceremony_data}.gd`). Despite its "refreshed" message it does
  NOT rebuild `tools/data/heroes_consts.json` (that is `heroes_sim.py --export`; change it only on purpose). A roster change also
  needs `python3 crystal-rush/tools/gen_save_v3_data.py --sim crystal-rush/tools/heroes_sim.py --roster-only` (rewrites
  `tools/data/heroes_migration.json` + `save_v3_data.gd`). `econ_data.gd` and `arsenal_data.gd` are hand-written.
- Everything heroes/Portal is behind `EconData.HEROES_PHASE` (0); the gallery forces it on (`HeroesUIModel.force_on`).
- Roster: 12 heroes (titan, arin, bolt, eira, seer, iskar, vesta, vartan, lumen, pava, sirko, olha) and 15 champions
  (mila, ivo, borko, alba, otto, taya, brant, teo, olena, nimb, dara, menhir, taras, snaryad, dovbush). Collector numbers are one
  shared line in joining order (sirko = 26, olha = 27).
- Painted art: `assets/heroes/<id>/splash.png` (heroes); champions `card.png` + `splash.png` in the same folder (NOT
  `assets/champions/` as heroes_prompts.md §1.6 says). 4K sources: `art_src/heroes/<id>/<id>_<kind>_src.jpg` (JPEG q88; Godot
  ignores art_src). Framing per character: `HeroArt.META` in `scripts/ui/heroes/hero_art.gd`. Missing: champion cards for brant, teo,
  olena, nimb, dara, menhir.

## Art pipeline (crystal-rush/tools/art/, crystal-rush/tools/art_prompts/)
- Install routine for new art: source -> `art_src/...`, cut-out, `assets/heroes/<id>/splash.png` or `card.png`, `HeroArt.META` line,
  `RECEIVED` entry in build.py, rebuild the prompt page, showcase shot, send it.
- Cut-out: `tools/art/cutlib.py` (see `tools/art/README.md`; Python with Pillow, numpy, scipy): resize to 1152 px wide,
  `arr = cutout(im, tol=10)`, `bg` = median RGB of a 6-px top/left/right border, `o, n = clean(arr, bg, hole_regions=[(y0,y1,x0,x1)],
  hole_std=3.0, hole_d=8)` (boxes for enclosed gaps, e.g. inside a bow string), `preview(o, path)`; look on dark and at zoomed edges.
- Prompt page: `python3 crystal-rush/tools/art_prompts/build.py --repo` rewrites `crystal-rush/docs/art_prompts/index.html`. FIRST add
  `'olha': [('olha/olha_splash_src.jpg', 'Сплеш (4K)')],` after the `'sirko'` line in `RECEIVED` (missing in the committed build.py;
  with it the rebuild is byte-identical). After any rebuild check `git diff --stat`: only what you meant may change. The page is
  viewed via htmlpreview, which disables `<script>`, so it boots from `<img onload>` with JS handlers: keep that. Owner's link
  (updates after push): https://htmlpreview.github.io/?https://github.com/Rammbiz/ForgeMind/blob/ccr-ea3be44f-lbour0/crystal-rush/docs/art_prompts/index.html
- Meshy (3D): the OWNER makes models on the Meshy website from our sheets (`heroes_prompts.md` §1.7). Targets ~8k tris champions,
  ~15k heroes. Rig: champions <= 30 bones, no extra skinned bones; heroes humanoid + scripted bones (hair, tail, filaments). Clips:
  champions idle, run, action, special, hit, fall, victory, flourish; heroes idle, run, attack_a, attack_b, ult_cast, hit, victory,
  flourish, summon_pose + extras in the hero's table. We shrink and import the GLB they send: `crystal-rush/tools/prepare_model.mjs`
  (Node, npm packages in a scratch dir; pass the triangle target, default 17000) then `crystal-rush/tools/import_model.sh` (bash,
  honours `$GODOT`); usage in their headers.

## Checks (run before pushing; commands from the repo root)
- Windows: `godot` is usually not on PATH. Try `where.exe godot*`; else ask the owner ONCE for the full path of the Godot 4.7
  `..._console.exe` (console build, so output reaches the shell) and use it wherever this says `godot`. Python is `py` or `python`,
  not `python3`. `xvfb-run` is Linux-only. The clone path has a space (`FiberForm CNC`): quote paths.
- Import: `godot --headless --path crystal-rush --import` (~35 s).
- Tests (exit code = failures): `godot --headless --path crystal-rush res://scenes/dev/<scene>.tscn -- --autotest` for test_meta,
  test_kinds, test_heroes, test_heroes_ui, test_loc, test_juice. `-- --autotest` is REQUIRED: it makes Save read-only so the owner's
  real save is never touched (test_meta only writes into a `test_meta/` subfolder of the user dir). Pass = "... 0 failed";
  test_juice only prints "JUICE_TEST done"; test_meta's "ConfigFile parse error" line is expected. ~2 min for all six.
  test_heroes calls `python3`; on Windows add `--no-python` and run the Python checks below yourself.
- Python checks: `python3 crystal-rush/tools/gen_heroes_data.py --check`, `python3 crystal-rush/tools/gen_save_v3_data.py --check`
  (exit 1 = out of date), `python3 crystal-rush/tools/loc_lint.py` (must print LOC_LINT PASS).
- Odds (the `--` is required, else nothing is checked): `godot --headless --path crystal-rush --script res://tools/odds_table.gd --
  --diff` (3 s) and `... -- --check` (~100 s Monte Carlo); both must print `ODDS_TABLE PASS`.
- Autotest: `godot --headless --path crystal-rush -- --autotest --level=1 --levels=2 --hero=bolt --speed=6` -> AUTOTEST_SUMMARY with
  won == levels.
- Screenshots (real window, NOT --headless, which saves nothing; Linux prefix `xvfb-run -a -s "-screen 0 1400x1400x24"`):
  `godot --path crystal-rush --resolution 720x1280 res://scenes/dev/heroes_gallery.tscn -- --out=<dir> --tag=720 --state=late
  --shots=hall,showcase_olha,portal` (states fresh/mid/late/welcome; names in `SHOTS` of `scripts/dev/heroes_gallery_shots.gd`;
  walkouts `--shots=walkout_L --walk_hero=olha --t=1.5`, gems C/R/E/L/M). Hub: `... res://scenes/dev/gallery_hub.tscn -- --out=<dir>
  --tag=720 --shots=play,heroes`. ALWAYS pass `--out` (outside the repo) and `--shots`: defaults are old cloud /tmp paths, and
  `--shots` keeps the save read-only. Always LOOK at the shots (720x1280; no "unknown shot" warning).
- APK: `crystal-rush/tools/build_android.sh` (bash; usage in its header; needs export templates, ANDROID_SDK_ROOT, JDK 17+). Bump
  `version/name` and `version/code` in `crystal-rush/export_presets.cfg` (now 2.3.0 / 7). Never commit keystores or passwords.

## State of play (update this section when it changes)
- Done and pushed: Taras, Snaryad, Dovbush (champions), Sirko, Olha (heroes), prompts page, art tools.
- **UI v3 "porcelain glass" + the «Порцеляна» key button are IN this branch** (merge c65e6a2: hub, Heroes, Portal restyle;
  `UITokens.CTA_STYLE = "porcelain"`, `--cta=ink|amber` only for dev comparisons). Spec: `crystal-rush/docs/design/ui_v3_spec.md`.
  The last amber accents are gone too (Ult button, avatar arc, nav, Portal, progress bars: ink + gold). The cloud session builds
  APK 2.4 from this branch next (version bump in export_presets.cfg). Ask before large `crystal-rush/scripts/ui/` changes while
  the cloud session is active, and always `git pull --ff-only` first so the two sessions do not collide.
- Next in the queue: H2 champions in the run, H3b wire UI to the real Meta API + Loc (delete the HeroesText fallback), H4 Workshop,
  Meta-1 review, Meta-2, perf pass; more characters from `heroes_ua_icons.md` as the owner picks (Леонтович, Франко, Рукавичка,
  Мамай, Одарка, Сковорода ...).
- 3D: no character has its new Meshy model yet. Starters run on old models (`assets/models/heroes/bolt.glb`, `titan.glb`,
  `assets/heroes/seer/seer.glb`) due for the wave-0 remake; only Vesta's glaive prop is new. Order: `heroes_prompts.md` §2.
