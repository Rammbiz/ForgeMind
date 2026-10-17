# olha art (assets/heroes/olha) — hero «Ольга — Княгиня Помсти»

- `dove.png` — the white dove cut from `splash.png` (top right, the hand and crown masked, a soft fade under the tail), 277x257: the painted doves of her signature walkout beat (`summon_ceremony._draw_painted_dove`).
- `splash.png` — the owner's 4K splash (Gemini, 2026-10-09, 3072x5504; source re-encoded in `art_src/heroes/olha/`, ignored by Godot),
  scaled to 1152x2064, background cut to transparency (the sheer veil keeps the cut's own edge; a keyed translucent veil was tried and
  rejected because it thinned the dove's tail). Eyes at ~29 % already, so no crop. Framing in `scripts/ui/heroes/hero_art.gd` (`META`).
- `model.glb` (+ `model_texture_0.jpg`, 1024²) — the 3D hero (Meshy 7.1 multi-view from three nano-banana-pro sheets in
  `art_src/heroes/olha/olha_sheet_{front,side,back}_src.jpg`, Ultra geometry, remeshed to 14 893 triangles, retextured from the
  same three views because Meshy's remesh re-bake cut seams across the face; colour +18 % saturation, +6 % brightness). Meshy
  humanoid rig; 9 clips merged into one file: run, idle, attack_a (Archery Shot), attack_b (Archery Shot 1), ult_cast (Charged
  Spell Cast), hit (Hit Reaction with Bow), victory (Cheer with One Hand Up), summon_pose (Relax Arms then Strike Battle Pose),
  flourish (Rightward Spin). HeroModels.art() loads it in place of the grey-box proxy; clip speeds in `ART_SPEED`.
- `prop_bow.glb` (2 626 tris), `prop_quiver.glb` (1 470), `prop_dove.glb` (890) — Meshy-T2 props (sheets in `art_src/...
  olha_prop_*_src.jpg`), textures 512² / 512² / 256²; hung on the rig by `HeroModels.ART_PROPS` (bow: LeftHand, the Meshy archery
  presets are left-handed; quiver: Hips, her left; dove: RightHand, victory only).
- `skill_{ult,attack,rally,awaken}.png` — 256² skill icons (nano-banana-pro, heroes_prompts H12 (e)); drafts, not wired into the
  UI yet (the Manage sheet still draws its glyphs).
