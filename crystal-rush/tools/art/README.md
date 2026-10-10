# Art tools (moved from the cloud session's scratchpad so a local session has them)

- `cutlib.py` — splash/card cut-out on the flat #BFBFBF background: `cutout(img, tol, sigma, seed_bottom, top_skip)` (border-seeded
  flood against a local background field), `clean(arr, bg, hole_regions, ...)` (enclosed background holes + speck removal),
  `preview(o, path, k)`. Typical use: scale the owner's 4K art to 1152 px wide, `cutout(im, tol=10)`, `clean(..., hole_std=3.0,
  hole_d=8)`, look at the preview on dark, then install as `assets/heroes/<id>/splash.png` / `card.png` with framing in
  `scripts/ui/heroes/hero_art.gd` (`META`). Sources go to `art_src/heroes/<id>/` (JPEG q88).
- `../art_prompts/build.py` — builds the owner's prompt page from `docs/design/heroes_prompts.md`: `python3 build.py --repo` writes
  `docs/art_prompts/index.html` (opened in a browser via htmlpreview); without `--repo` it writes the self-contained page with
  embedded images to `out/` (or `$ART_PROMPTS_OUT`). Add finished art to `RECEIVED` in build.py.
- `gemini_image.py` — one image from Gemini (Google AI Studio): `py gemini_image.py --out x.png --prompt-file p.txt --ref card.png
  --size 2K --aspect 3:4` (references repeatable; `--search` lets the model use Google Search). The key is the owner's Windows
  user variable `GEMINI_API_KEY` (set by them with `~/.claude/mcp/set-gemini-key.py`; never in the repo or a chat). Each call
  costs the owner's AI Studio billing, so ask before batches.
