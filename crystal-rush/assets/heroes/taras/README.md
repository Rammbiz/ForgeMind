# taras art (assets/heroes/taras) — champion «Тарас — Кобзар»

- `card.png` — the owner's 3:4 card (Gemini 4K, 2026-10-09, 3584x4800; source in `art_src/heroes/taras/`), scaled to 1152x1543, cut out.
  A respectful heroic portrait inspired by Taras Shevchenko's 1859 self-portrait (lambskin hat, sheepskin coat, vyshyvanka).
- `splash.png` — the same art (cameos and walkouts use the splash slot).
- `model.glb` (+ `model_Image_0.jpg`, 1024²) — the 3D champion (2026-10-10): nano-banana-2 A-pose sheet from the card
  (`art_src/heroes/taras/taras_sheet_front_src.jpg`) → Meshy-T2 8 417 triangles → Meshy humanoid rig. Meshy gave him a short grey
  beard; it is painted out of the albedo (chin and jaw to the cheek tone by the texels' 3D position, the moustache kept). 6 clips
  merged into one file: run, idle, action (Over Shoulder Throw), hit (Hit Reaction), fall (the stand-up of Kneel on One Knee and
  Stand, 0.3–1.8 s, reversed: he sinks to one knee and stays there), victory (Gentleman's Bow). ChampionView plays them on the run's
  fx events (`ART_CLIP_SPEED`).
- `prop_book.glb` (+ `prop_book_0.jpg`, 512²) — the throwing book, Meshy-T2 1 465 triangles (sheet in
  `art_src/heroes/taras/taras_prop_book_src.jpg`), hung on RightHand by `HeroModels.ART_PROPS`.
- `action.png` — 256² action icon «Слово / The Word» (Gemini, heroes_prompts C23 (e), style from Ольга's skill icons; source
  `art_src/heroes/taras/taras_action_src.jpg`, 2048²). A draft, not wired into the UI yet.
