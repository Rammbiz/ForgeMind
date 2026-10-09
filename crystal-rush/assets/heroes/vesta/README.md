# Vesta art (assets/heroes/vesta)

- `splash.png` — the owner's splash (Gemini, 2026-10-08): 768x1376 source, background cut to transparency and
  scaled 1.5x to 1152x2064 (source kept in `art_src/heroes/vesta/vesta_splash_src.jpg`, ignored by Godot).
  It is the style anchor for all other heroes. The Heroes UI (HeroArt) reads it for the Showcase, the walkout
  and the card crop (`HeroArt.META["vesta"]`; the framing matches the previous placeholder, so the crop and eye line stay).
- A 4K version (2160x3840) replaces this file under the same name when it exists.
- `glaive.glb` + textures: the 3D glaive (run / 3D view), unrelated to the splash.
