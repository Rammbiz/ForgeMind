# ForgeMind: notes for any Claude Code session (local or cloud)

The repo holds several unrelated things. The live project is **`crystal-rush/`** (Godot 4.7, GL Compatibility): «Кришталевий Ривок /
Crystal Rush», a portrait mobile crowd-runner with a deep gacha meta (heroes, champions, Portal, Workshop). `crystal-bastion/` is an
older Godot project; the Python files in the root are unrelated CAD tools. Work only in `crystal-rush/` unless asked.

## The owner and how to work with them
- The owner writes Ukrainian, reads on a phone. Reply in Ukrainian, plainly, no jargon. Use they/them for the owner.
- Chain work without pausing; report often, with screenshots (`SendUserFile` / the app shows images). Give COMPLETE prompts for art
  with all technical data (see `crystal-rush/docs/design/heroes_prompts.md` for the format).
- The look the owner wants: premium "heavy luxe", Genshin x AFK Journey fusion, bright, 1 device-px gold lines, 45-degree chamfers
  (never pills), one font (M PLUS Rounded 1c), no text outlines. The owner dislikes anything that "reeks of AI": saturated orange
  gradients, glossy highlights, glows, cartoonish stickers.
- Never ask the owner to paste keys or tokens into chat; keys live in environment variables (`MESHY_API_KEY`). Never send the owner's
  email anywhere. Do not spend Higgsfield credits without asking. No PR unless asked. No model names in commits or code comments.
- Develop on branch `ccr-ea3be44f-lbour0`; commit with clear messages and end them with the attribution lines the harness gives you.

## Where things are (crystal-rush/)
- Design docs: `docs/design/heroes_design.md` (the rules, §-numbered; the source of truth for numbers), `heroes_prompts.md` (art
  prompts for every character), `heroes_ua_icons.md` (50 judged ideas for more Ukrainian heroes/champions), `ui_v3_spec.md`
  (only on the ui-v3 branch for now).
- Game data is GENERATED: `tools/heroes_sim.py` + `tools/heroes_tables.py` -> `tools/gen_heroes_data.py` -> `tools/data/*.json` and
  `scripts/core/*_data.gd`. Never hand-type tables; run the generators with `--check`. Odds tables: `tools/odds_table.gd --check/--diff`.
- Everything heroes/Portal is behind `EconData.HEROES_PHASE` (0); the gallery forces it on (`HeroesUIModel.force_on`).
- Roster now: 12 heroes (titan, arin, bolt, eira, seer, iskar, vesta, vartan, lumen, pava, sirko, olha) and 15 champions
  (mila, ivo, borko, alba, otto, taya, brant, teo, olena, nimb, dara, menhir, taras, snaryad, dovbush). Collector numbers are one
  shared line in joining order (sirko = 26, olha = 27).
- Painted art by the owner: `assets/heroes/<id>/splash.png` (heroes) and `card.png` (+`splash.png`) for champions; 4K sources in
  `art_src/heroes/<id>/` (ignored by Godot). Per-character framing is `HeroArt.META` in `scripts/ui/heroes/hero_art.gd`.

## Art pipeline (tools/art/, tools/art_prompts/)
- Cut-out: `tools/art/cutlib.py` (see `tools/art/README.md`): scale to 1152 px wide, `cutout(im, tol=10)`, `clean(...)`, look at the
  preview on dark and at zoomed edges, then install and add the META line. Needs Python with Pillow, numpy, scipy.
- Prompt page for the owner: `python tools/art_prompts/build.py --repo` rewrites `docs/art_prompts/index.html` (opened through
  htmlpreview.github.io; that host disables `<script>`, so the page boots from `<img onload>` and navigates with JS handlers: keep it).
  Add finished art to `RECEIVED` in `build.py`.
- Meshy (3D): API key in env var `MESHY_API_KEY` (never in chat). Pipeline per character: front sheet + side/back sheet -> Multi-image
  to 3D (~8k tris for champions, ~15k for heroes) -> rig (humanoid, <= 30 bones) -> clips (idle, run, action, special, hit, fall,
  victory, flourish) -> `assets/heroes/<id>/`. Prompts and clip tables are in `heroes_prompts.md`.

## Checks (run before pushing)
- Import: `godot --headless --path crystal-rush --import`.
- Tests: scenes `scenes/dev/test_meta.tscn`, `test_kinds`, `test_heroes`, `test_heroes_ui`, `test_loc`, `test_juice`
  (`godot --headless --path crystal-rush res://scenes/dev/<scene>.tscn`, each with a clean user-data dir). All must pass.
- Autotest: `godot --headless --path crystal-rush -- --autotest --level=1 --levels=2 --hero=bolt --speed=6`.
- Screenshots: `scenes/dev/heroes_gallery.tscn -- --out=DIR --tag=720 --state=late --shots=hall,showcase_olha,portal`
  (states fresh / mid / late / welcome; `--walk_hero=<id> --t=<s>` for walkouts) and `scenes/dev/gallery_hub.tscn`.
  Run on a real window at `--resolution 720x1280` (the cloud used xvfb on Linux). Always LOOK at the shots.

## State of play (update this section when it changes)
- Done and pushed: Taras, Snaryad, Dovbush (champions), Sirko, Olha (heroes), prompts page, art tools.
- **UI v3 "porcelain glass"** is finished on the cloud-only branch `ui-v3` (hub, Heroes, Portal restyle; accepted) and is NOT in this
  branch yet. Merge order: choose the key button, merge `ui-v3` into this branch, run all checks, build APK 2.4.
- **Key button (CTA)**: the owner dislikes the amber one; two finished alternatives, «Чорнило» (ink-navy) and «Порцеляна» (white
  enamel), exist on the cloud-only branch `cta-study`. Waiting for the owner's pick (recommended: Чорнило).
- Next in the queue: H2 champions in the run, H3b wire UI to the real Meta API + Loc (delete the HeroesText fallback), H4 Workshop,
  Meta-1 review, Meta-2, perf pass; more characters from `heroes_ua_icons.md` as the owner picks (Леонтович, Франко, Рукавичка,
  Мамай, Одарка, Сковорода ...). Unfinished 3D work: no character has a Meshy model yet except the starters.
