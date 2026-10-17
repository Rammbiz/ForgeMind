# skovoroda art (assets/heroes/skovoroda) — champion C32 «Сковорода — Невловимий» (wave 9, heroes_design.md §6.34)

- `card.png` — the 3:4 card (Gemini, 2026-10-10; 1792x2400 source in `art_src/heroes/skovoroda/skovoroda_card_src.jpg`), scaled to
  1152x1543, cut out (tools/art/cutlib.py).
  A respectful portrait inspired by the philosopher Hryhorii Skovoroda (not the banknote portrait): a tall, lean wanderer
  with a calm half-smile, a dust-cream travelling cloak and shirt with gold baroque embroidery, a satchel, a wooden sopilka
  at the belt, a long wooden staff whose carved claws hold a long pointed violet amethyst (the heart gem), a golden net
  slipping off behind him.
  The golden net's mesh (right of the staff) was cleared afterwards with `tools/art/net_holes.py` (region
  `0.30 0.86 0.62 1.0`, tol 28): about 200 cells see through; a few tiny grey slivers stay where strands cross.
- `splash.png` — the same art (cameos and walkouts use the splash slot).
- Framing: `HeroArt.META["skovoroda"]` (eyes at x 0.525, y 0.23 of the card).
