# Кришталевий Ривок / Crystal Rush — промти для героїв і чемпіонів (`heroes/heroes_prompts.md`)

**Де ми зараз:** дизайн героїв і чемпіонів завершено (`heroes_design.md` v2, симуляція пройдена); цей файл — останній крок дизайну: промти, з якими ви генеруєте арт ВЖЕ ЗАРАЗ. Код героїв починається після APK 2.1 (рішення 20) і йде фазами H0–H5; арт потрібен хвилями (§2), щоб жодна фаза не чекала.

Джерела (вони головні, якщо щось розходиться): `heroes_design.md` v2 (§6 ростер, §9.1 напрям, §10.3 палітра забігу, §10.6–10.7 бюджети, §14 арт-план), `decisions.md` (рішення 1–20 + додатки 1–5), `research_presentation.md` §4–§5, `arsenal_design.md` Appendix A (стиль Meshy-промтів), `prompts_vesta_v2.md` (еталон формату), `uiref/fusion/OWNER_DECISIONS.md` (напрям Genshin × AFK Journey — обов'язковий; старі варіанти A/B/C більше не діють).

**Правила, які виконує кожен промт нижче** (ваші додатки 4 і 5):
- Кожен промт ПОВНИЙ і самодостатній: FORMAT · ART STYLE · CHARACTER/OBJECT · COLOR LOCK · POSE & COMPOSITION · AVOID. Копіюйте блок цілком; жодних «замініть рядок».
- COLOR LOCK: усі кристали персонажа — кольору його КОРІННОГО самоцвіту; заборонені кольори названо явно.
- Реалістичні дорослі пропорції (7.5–8 голів для людиноподібних; звірі й створіння — правдоподібна анатомія). Чібі лишається тільки натовп солдатів.
- Кристали не світяться, немає іскор/частинок/променів: світіння, обідок кольору самоцвіту, частинки й фон гра додає сама (тому той самий арт працює після «Огранки» в будь-який самоцвіт). Єдиний виняток — внутрішній вогонь клинка Вести (затверджений образ).
- Фон завжди рівний сірий `#BFBFBF`; лівий верх кадру порожній під емблему та ім'я.
- Імен персонажів у промтах НЕМАЄ (щоб генератор не малював текст і не тягнув асоціацій з чужими персонажами). Нічого не схоже на ваші референси з іншої гри, на відомих персонажів, прапори чи релігійні символи.

Зміст: §1 Біблія стилю · §2 Порядок генерації і чекліст · §3 Герої (10) · §4 Чемпіони (12) · §5 Емблеми, значки, валюти, Портал, скрині, Майстерня, фони, спорядження, реліквії · §6 Відкриті питання.

## 1. Біблія стилю (одна на всіх 22 персонажів)

### 1.1 Еталон стилю

1. **Зараз:** еталон — Gemini-Веста `heroes/vesta_gemini.jpg` (ви його затвердили; додаток 4). Вона лише 572×1024, тому першим кроком перегенеровуємо Весту в 4K (§3, H07).
2. **Після затвердження нової Вести** збережіть її як `style_anchor.png` і прикріплюйте до КОЖНОГО наступного промту (сплеші, картки, листи, іконки, фони). Промти кажуть «Same art style as the attached style reference image».
3. **Еталон персонажа:** затверджений сплеш/картка — референс для його листів, іконок і майбутніх скінів.
4. Калібрування додатку 5: «значно ближче до Genshin» — витончене напівреалістичне мальовниче фентезі, чисті тонкі риси обличчя з легким аніме-впливом, м'яке світло, тонкий золотий орнамент, БЕЗ товстих контурів і мультяшних пропорцій. Назви ігор у промти не пишемо — стиль описано словами.

### 1.2 Спільні англійські блоки (вже вшиті в кожен промт — тут для довідки)

```
ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
```

```
AVOID (2D characters)
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime.
```

Рідкість «відчувається» (додаток 1): чим вищий самоцвіт, тим багатше оформлення. Рядок «Rarity look» у кожному промті:

| Самоцвіт | Рядок у промті |
|---|---|
| Кварц | Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes. |
| Сапфір | Rarity look (second tier): refined gear with fine trim and a few elegant details. |
| Аметист | Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth. |
| Топаз | Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette. |
| Опал | Rarity look (top tier): the most ornate and otherworldly design in the game: layered luminous materials, delicate ornament and a majestic silhouette. |

### 1.3 Палітри

**Самоцвіти (COLOR LOCK + форма каменя-серця; кожен персонаж має один камінь-серце ≈ 4% висоти фігури, видно спереду):**

| Самоцвіт | Огранка каменя-серця | Колір у промті | Заборонено |
|---|---|---|---|
| Кварц / Quartz (`#D6DEE6`) | round rose-cut dome (a circular stone with softly domed facets) | clear colourless rock quartz, water-clear with a faint cool silver-grey tint | No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones. |
| Сапфір / Sapphire (`#3FA9FF`) | square Asscher step cut with clipped corners | vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows) | No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. |
| Аметист / Amethyst (`#B06CFF`) | triangular trillion cut | deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights) | No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. |
| Топаз / Topaz (`#FFB52E`) | five-pointed star cut | golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows) | No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems. |
| Опал / Opal (`hue-cycle`) | marquise (pointed eye-shaped) smooth cabochon | precious opal with vivid play-of-colour: small shifting flecks of every rainbow colour inside a milky white (white opal) or near-black (black opal #1A1530) body | No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour. |

**Стихії** (= сім'ї машин; акцент костюма — на 60–70% насиченості; в іконках — повний колір; кольори самоцвітів ніколи не домінують у костюмі):

| Стихія | Акцент костюма | Колір мотиву іконок | Тінь іконок |
|---|---|---|---|
| Кінетика / Kinetic | pale copper (#D0BBAF) and warm bronze | pale copper (#D9B8A6) and warm bronze | deep bronze-brown (#4A3426) |
| Вольт / Volt | storm-orchid (#EFB5EF) trim | storm orchid pink-violet (#FFA5FF) lightning with white cores | deep plum (#4A2148) |
| Мороз / Frost | snow-ivory (#F4F8DF) embroidery | snow ivory (#F8FFD8) and frost white | cool slate grey-blue (#46566B) |
| Плазма / Plasma | crimson-rose (#B42E71) cloth | plasma rose (#D80A71) and hot pink-white | deep wine (#4A0F2C) |
| Техно / Tech | signal-lime (#5ED437) details used sparingly | signal lime (#49FF0C) and graphite grey (#3A3F47) | graphite (#24282E) |
| Руна / Rune | rune-indigo (#2E2EB4) cloth | rune indigo (#2E2EB4) with ivory carved lines | ink navy (#141448) |

**Фракції** (матеріали; живуть у костюмах, спорядженні, гербах і фонах):

| Фракція | Матеріали й мотиви | Фон (§5.6) |
|---|---|---|
| Орден Світанку / Dawn Order | white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass | `bg_dawn.png` |
| Дикі Ікла / Wildfang | heartwood leather, woven hide, fur, feathers, carved bone and coral beads | `bg_wildfang.png` |
| Кам'яне Серце / Stoneheart | basalt, granite, brass, moss and frost | `bg_stoneheart.png` |
| Небожителі / Celestials | moonsilver, night-blue star-glass with white star specks, white enamel and fine gold | `bg_celestial.png` |

Спільна ДНК усієї команди: щонайменше один елемент **білої емалі або золота** на кожному персонажі + **камінь-серце**. Помаранчева лава / розпечений метал — колір ворога (Жаророгі), на наших персонажах заборонені.

### 1.4 Пози сплешів (P1–P6) і композиція

| Поза | Опис | Хто |
|---|---|---|
| P1 «Варта / Guard» | зброя впирається в землю, вага на задній нозі | Арін, Пава · Олена, Менгір |
| P2 «Крок / Advance» | крок/випад на глядача, удар у лівий нижній кут | Горан, Веста · Брант |
| P3 «Чари / Cast» | рука до глядача (магію додає гра) | Ейра, Мейра, Люмен · Міла, Тая |
| P4 «Приціл / Aim» | лук/арбалет по діагоналі на лівий низ | Іскар · Альба, Тео, Дара |
| P5 «Щит / Bulwark» | низька стійка, щит уперед | Вартан · Іво, Отто, Німб |
| P6 «Звір / Prowl» | низький присід/стрибок на глядача | Руді · Борко |

Два герої одного самоцвіту ніколи не мають однакової пози чи класу (перевірено). **Композиція героя (9:16, 2160×3840):** персонаж у правих 2/3; лівий верх (40% ширини × 40% висоти) порожній; очі на ≈ 30% висоти; від верху голови до колін, фігура йде за нижній край; корпус повернутий ≈ 30° ліворуч; камера трохи нижче грудей. **Чемпіон (3:4, 1536×2048):** до середини стегна, центр фігури ≈ 60% ширини, лівий верх 33% × 35% порожній, очі на ≈ 24%.

### 1.5 Інструменти, налаштування, послідовність

| Що | Інструмент (рекомендовано) | Формат · якість | Що прикріпити | Варіантів |
|---|---|---|---|---|
| Сплеш героя | Gemini «Nano Banana Pro» (Google AI Studio / Gemini) — на ньому зроблено еталон; або Higgsfield з тією ж моделлю | 9:16 · 4K | `style_anchor.png` (+ старий сплеш для ремейків) | 2–4 |
| Картка чемпіона | те саме | 3:4 · 2K–4K | `style_anchor.png` (+ картка з партії 1, якщо є) | 2–4 |
| Фронт-лист | те саме, в тому ж чаті | 1:1 · 2K | затверджений сплеш/картка + еталон | 2 |
| Бік + спина | те саме, в тому ж чаті | 16:9 · 4K | фронт-лист + сплеш | 2 |
| Лист пропа | те саме | 1:1 · 2K | сплеш | 1–2 |
| Іконки, герби, валюти, предмети | те саме або ChatGPT (GPT-image) | 1:1 · 1K–2K | еталон + сплеш героя | 2–3 |
| Фони фракцій | Midjourney (`--ar 9:21`) або Gemini 9:16 | 9:21 / 9:16 · 4K | еталон | 2–4 |
| 3D | Meshy (найновіша модель) | — | листи b1 + b2 (+ b3) | ≤ 3 спроби |

Поради для однаковості:
- **Один чат на персонажа:** сплеш → фронт → бік+спина → пропи → іконки. Модель «пам'ятає» обличчя й костюм.
- **Seed:** якщо інструмент його показує (Midjourney `--seed`, Higgsfield, Flux, Seedream) — допишіть у назву файлу: `alba_card_s123456.png`. У Gemini seed не видно — просто не видаляйте чат.
- **Midjourney:** той самий текст + `--ar 9:16 --sref <посилання на style_anchor> --oref <посилання на сплеш> --ow 100` (для листів), `--no text, watermark`.
- **Якщо генератор щось проігнорував**, не правте промт — напишіть у тому ж чаті одне з уточнень: `Keep the upper-left 40% x 40% of the canvas empty flat grey; change nothing else.` · `Remove all sparks, glow and particles; change nothing else.` · `Make every crystal the same colour as the heart gem; change nothing else.` · `Use realistic adult proportions, smaller head; change nothing else.` · `Show both feet fully; change nothing else.`
- **Замало пікселів?** `Upscale this image to 4K without changing anything` (Gemini) або Upscale у Higgsfield. Завжди кнопка «Завантажити» → оригінал PNG, не скріншот і не стиснене фото в месенджері.

### 1.6 Що надсилати назад (розміри, формат, назви)

| Що | Розмір (мінімум) | Формат | Назва файлу | Примітка |
|---|---|---|---|---|
| Сплеш героя (оригінал) | 2160×3840 (≥ 1440×2560) | PNG | `<id>_splash.png` | на сірому `#BFBFBF`, як згенерувалось |
| Картка чемпіона (оригінал) | 1536×2048 (≥ 1152×1536) | PNG | `<id>_card.png` | |
| Вирізаний персонаж (за бажанням) | той самий | PNG з прозорістю | `<id>_splash_cut.png` / `<id>_card_cut.png` | Higgsfield «Remove background» або remove.bg; перевірте волосся/хутро на чорному й білому фоні. Не хочете — виріжу сам |
| Фронт-лист | 2048×2048 | PNG | `<id>_sheet_front.png` | |
| Бік + спина | 3840×2160 + 2 половини | PNG | `<id>_sheet_sideback.png`, `<id>_sheet_side.png`, `<id>_sheet_back.png` | |
| Лист пропа | 2048×2048 | PNG | `<id>_prop_<назва>.png` | назви — у розділі персонажа |
| 3D персонажа | — | GLB (або FBX) | `<id>.glb`; якщо Meshy дає кліпи окремо — `<id>_<кліп>.glb` | з ригом і всіма кліпами |
| 3D пропа / об'єкта | — | GLB | `<id>_prop_<назва>.glb`, `portal.glb`, `hero_chest.glb`, `grand_hero_chest.glb`, `workshop.glb` | без ригу |
| Іконки навичок | 1024×1024 | PNG | `<id>_skill_ult.png` · `_attack` · `_rally` · `_awaken`; чемпіон: `<id>_action.png` | |
| Інші 2D | 1024×1024 | PNG | `faction_<f>.png`, `class_<c>_ref.png`, `aura_<c>.png`, `cur_<валюта>.png`, `gear_<f>_<слот>.png`, `relic_<id>.png`, `gemtex_<самоцвіт>.png` | |
| Фони фракцій | 1440×3360 (або 2160×3840) | PNG, сірі | `bg_<f>.png` | |

Тека на Google Drive: `CrystalRush_art/<id>/` (одна на персонажа) і `CrystalRush_art/_shared/` (усе спільне). Я переношу в `art_src/heroes/<id>/` (майстри, не в APK) і `assets/heroes/<id>/` / `assets/champions/<id>/` (зменшені для гри: сплеш 0.5×, картка 0.667×, маски глибини/гойдання/ефектів роблю я). `<id>` — латинський ключ із заголовка (`titan`, `vesta`, `alba`…).

**Перевірка перед відправкою (30 секунд):** ① розмір не менший за мінімум · ② фон рівний сірий, без підлоги й тіні · ③ лівий верх порожній (сплеш/картка) · ④ усі кристали — колір свого самоцвіту · ⑤ немає світіння, іскор, частинок (крім клинка Вести) · ⑥ п'ять пальців, рука не зрослася зі зброєю · ⑦ немає тексту й водяних знаків · ⑧ дорослі пропорції, голова не завелика · ⑨ на листах: ступні видно, руки порожні, обличчя й костюм як на сплеші · ⑩ Google Lens по готовому сплешу — нічого схожого на відомих персонажів.

### 1.7 Meshy: загальні налаштування

1. **Multi-image to 3D**: завантажте `front`, `side`, `back` (якщо мульти-режиму немає — Image to 3D з фронт-листа). Remove background — увімкнено. Модель — найновіша. Symmetry — як у персонажа. Якщо є параметр пози — A-pose.
2. **Texture**: увімкнено (base colour). PBR/metal/roughness гра не використовує (у нас «іграшкові» шейдери з маскою), normal — за бажанням для героїв.
3. **Remesh** (до ригу!): Triangle, Target polycount — як у персонажа.
4. **Animate → Rig**: Humanoid; розставте маркери, як просить Meshy (підборіддя, зап'ястя, лікті, коліна, пах); хвіст, крила, шлейф, плащ — не позначати.
5. **Анімації з бібліотеки** — за таблицею кліпів персонажа. Назви пресетів у Meshy можуть відрізнятися — беріть найближчий; тривалість і цикли я підріжу в Godot. Перейменовувати не треба — напишіть у повідомленні, який пресет на який кліп.
6. **Download**: GLB з усіма анімаціями (або FBX). Пропи — окремі моделі без ригу.
7. **Спроби**: до 3 на модель. Якщо «попливли» руки чи обличчя — краще перегенерувати лист, ніж модель.
8. **Кредити**: перед хвилею 1 порахуйте — 22 персонажі (кожен: генерація + remesh + rig + 8–10 кліпів) + 16 пропів + 4 об'єкти, до 3 спроб кожне. Ціни Meshy змінюються, тому множте на поточну ціну в кабінеті.

| Тип | Трикутники | Текстура в грі | Кістки | Примітка |
|---|---|---|---|---|
| Герой | 12–15k (ціль **15 000**) | 1024² альбедо (+ 1024² normal опційно) | humanoid + мої скриптові (коса, хвіст, філаменти) | 1 матеріал |
| Чемпіон | 6–8k (ціль **8 000**; LOD 6k роблю я) | 512² | ≤ 30, без додаткових скінованих кісток | 1 матеріал; 3 чемпіони разом ≤ +25k трикутників на прохід |
| Проп героя / чемпіона | 2 500 / 1 500 | 512² / 256–512² | — | кріплю на `hand_r` / `hand_l` |
| Портал · Скриня · Велика скриня · Майстерня | 18 000 · 6 000 · 8 000 · 12 000 | 1024² · 512² · 1024² · 1024² | — | |

## 2. Порядок генерації і чекліст

Персонаж потрапляє в Портал і скрині лише коли готове ВСЕ: сплеш/картка, 3D з ригом і кліпами, іконки (до того гравець його не побачить, заглушки в нагородах заборонені). Тому порядок іде за тим, що потрібно кожній фазі коду після APK 2.1.

| Крок | Що | Навіщо саме зараз (що розблоковує) |
|---|---|---|
| 1 | **Веста — сплеш 4K** (H07 a) → затвердити → `style_anchor.png` | еталон стилю для всіх 21 інших; макет «Вітрини героя» (H3) |
| 2 | **Отто, Альба, Міла** повністю: картка → листи → пропи → Meshy 8k → риг → кліпи → іконка | фаза H2: чемпіони в забігу й заміри fps на телефоні зі справжніми моделями; сценарні скрині №1/№2 (L14) |
| 3 | **Набір хабу:** Портал (концепт + Meshy), Скриня героїв, 4 валюти, 4 герби фракцій, 5 значків класів, 4 фони фракцій | екрани H3: Портал, Зала героїв, Команда, Вітрина |
| 4 | **Стартери-ремейки (хвиля 0): Горан, Руді, Мейра** повністю (сплеш → листи → Meshy 15k → риг → кліпи → 4 іконки; Мейрі ще «очі закриті») | вони в грі з L1–L5; без ремейку реліз не вийде (поки працюють старі моделі) |
| 5 | **Веста** до кінця (листи, 3D тіла, кліпи, іконки) + **Люмен** повністю | вітальний ×10 «щонайменше Топаз» вимагає хоча б одного готового Топаза; перший Опал |
| 6 | **Хвиля 1:** Арін, Ейра, Іскар · Іво, Борко | Портал L20 з Кварц–Аметист пулом; скрині L14 з першими Кварц-чемпіонами |
| 7 | **Хвиля 2:** Вартан, Пава · Тая, Брант, Тео, Олена · Майстерня (станок) · 12 іконок спорядження | Топаз/Опал-пул; фаза H4 (Майстерня, L32) |
| 8 | **Хвиля 3:** Німб, Дара, Менгір · Велика скриня · 22 реліквії · 5 аур · (опційно) 5 текстур самоцвітів | рідкісні скрині, полірування |

### 2.1 Чекліст — герої

| Крок | № | Герой | Сплеш | Фронт | Бік+спина | Пропи | Meshy 3D | Риг+кліпи | 4 іконки | Надіслано |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | 01 | Горан `titan` | ☐ | ☐ | ☐ | — | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 6 | 02 | Арін `arin` | ☐ | ☐ | ☐ | ☐ якір-молот | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 4 | 03 | Руді `bolt` | ☐ | ☐ | ☐ | — | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 6 | 04 | Ейра `eira` | ☐ | ☐ | ☐ | ☐ арфа-посох | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 4 | 05 | Мейра `seer` | ☐ (+ очі закриті ☐) | ☐ | ☐ | — | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 6 | 06 | Іскар `iskar` | ☐ | ☐ | ☐ | ☐ рейковий лук | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 1/5 | 07 | Веста `vesta` | ☐ | ☐ (A) / ✓ v1 (B) | ☐ | ✓ глефа (є) | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 7 | 08 | Вартан `vartan` | ☐ | ☐ | ☐ | ☐ дрон-вартовий | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 5 | 09 | Люмен `lumen` | ☐ | ☐ | ☐ | — | ☐ | ☐ | ☐☐☐☐ | ☐ |
| 7 | 10 | Пава `pava` | ☐ | ☐ | ☐ | ☐ посох-перо · ☐ розкрите віяло | ☐ | ☐ | ☐☐☐☐ | ☐ |

### 2.2 Чекліст — чемпіони

| Крок | № | Чемпіон | Картка | Фронт | Бік+спина | Пропи | Meshy 3D | Риг+кліпи | Іконка | Надіслано |
|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 11 | Міла `mila` | ☐ | ☐ | ☐ | ☐ ліхтар | ☐ | ☐ | ☐ | ☐ |
| 6 | 12 | Іво `ivo` | ☐ | ☐ | ☐ | ☐ щит-жаровня | ☐ | ☐ | ☐ | ☐ |
| 6 | 13 | Борко `borko` | ☐ | ☐ | ☐ | ☐ лопата-сокира | ☐ | ☐ | ☐ | ☐ |
| 2 | 14 | Альба `alba` | ☐ | ☐ | ☐ | ☐ лук | ☐ | ☐ | ☐ | ☐ |
| 2 | 15 | Отто `otto` | ☐ | ☐ | ☐ | ☐ баштовий щит | ☐ | ☐ | ☐ | ☐ |
| 7 | 16 | Тая `taya` | ☐ | ☐ | ☐ | — | ☐ | ☐ | ☐ | ☐ |
| 7 | 17 | Брант `brant` | ☐ | ☐ | ☐ | ☐ клинок-серп | ☐ | ☐ | ☐ | ☐ |
| 7 | 18 | Тео `teo` | ☐ | ☐ | ☐ | ☐ арбалет-телескоп · ☐ дрон-зонд | ☐ | ☐ | ☐ | ☐ |
| 7 | 19 | Олена `olena` | ☐ | ☐ | ☐ | ☐ посох із травами | ☐ | ☐ | ☐ | ☐ |
| 8 | 20 | Німб `nimb` | ☐ | ☐ | ☐ | ☐ щит-егіда | ☐ | ☐ | ☐ | ☐ |
| 8 | 21 | Дара `dara` | ☐ | ☐ | ☐ | ☐ гарпун | ☐ | ☐ | ☐ | ☐ |
| 8 | 22 | Менгір `menhir` | ☐ | ☐ | ☐ | — | ☐ | ☐ | ☐ | ☐ |

### 2.3 Чекліст — спільне

| Крок | Що | Скільки | Готово |
|---|---|---|---|
| 3 | Портал: концепт `portal_concept.png` + `portal.glb` | 1 | ☐ ☐ |
| 3 | Скриня героїв: `hero_chest.glb` (або вже зроблена з партії 1) | 1 | ☐ |
| 3 | Валюти `cur_beacons/seals/tomes/ore.png` | 4 | ☐☐☐☐ |
| 3 | Герби фракцій `faction_*.png` | 4 | ☐☐☐☐ |
| 3 | Значки класів (референс для вектора) `class_*_ref.png` | 5 | ☐☐☐☐☐ |
| 3 | Фони фракцій `bg_*.png` | 4 | ☐☐☐☐ |
| 7 | Майстерня: концепт + `workshop.glb` | 1 | ☐ ☐ |
| 7 | Спорядження `gear_*.png` | 12 | ☐☐☐☐☐☐☐☐☐☐☐☐ |
| 8 | Велика скриня: концепт + `grand_hero_chest.glb` | 1 | ☐ ☐ |
| 8 | Реліквії `relic_*.png` | 22 | ☐×22 |
| 8 | Аури класів `aura_*.png` | 5 | ☐☐☐☐☐ |
| 8 | (опційно) Текстури самоцвітів `gemtex_*.png` | 5 | ☐☐☐☐☐ |

Разом: 10 сплешів (+1 «очі закриті» Мейри; для Вести — один із двох варіантів) · 12 карток · 22 фронт-листи (Вестин v1, можливо, вже годиться) · 22 «бік+спина» (кожен дає 2 кадри) · 16 листів пропів · 52 іконки навичок/дій · 5 аур · 4 герби · 5 ескізів класів · 4 валюти · 12 спорядження · 22 реліквії · 4 фони · 4 концепти об'єктів = **≈ 195 зображень** (+5 опційних текстур самоцвітів). Meshy: **22 персонажі** (19 нових + 3 ремейки стартерів) + **16 пропів** + **4 об'єкти**; глефа Вести вже є; спис Іво, спис Німба, призму Люмена, підвіску Таї й таблички Менгіра роблю сам.

## 3. Герої (10)

Порядок усередині: (a) сплеш → (b) листи для Meshy (b1 фронт, b2 бік+спина, b3 пропи) → (c) Meshy текстовий промт (запасний, ≤ 600 символів) → (d) риг і кліпи → (e) 4 іконки навичок (Ульта · Атака · Клич · Пробудження).

Розділи йдуть у порядку генерації (§2): Веста → Горан → Руді → Мейра → Люмен → Арін → Ейра → Іскар → Вартан → Пава.

### H07 `vesta` — Веста — Сонцекута / Vesta — Sunforged

ЗАТВЕРДЖЕНИЙ образ (`prompts_vesta_v2.md`). Сплеш треба перегенерувати у високій роздільності — він стане ЕТАЛОНОМ СТИЛЮ для всіх. Фронт-лист `vesta_sheet_v1.png` і модель глефи (`assets/heroes/vesta/glaive.glb`) вже є. Роль: a young woman knight-commander whose topaz glaive carries a captured noon.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Топаз / Topaz | Воїн | Плазма | Орден Світанку | людина, ж. | P2 Advance | golden amber topaz (#FFB52E) | five-pointed star-cut, the centre of her breastplate |

**(a) 2D-сплеш** — `vesta_splash.png`. Два ПОВНІ варіанти — оберіть один за питанням Q11 (колір плаща). Для першого запуску прикріпіть стару `vesta_gemini.jpg` як референс стилю й персонажа; затверджений результат стає `style_anchor.png` для всіх інших.

Налаштування: формат **9:16** · якість **4K** (≥ 2160×3840) · 2–4 варіанти · референс: `vesta_gemini.jpg` · оригінал PNG.

*Варіант A (за замовчуванням дизайну, Q11): малиново-рожевий плащ — колір її стихії Плазма.*

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7.5–8 heads tall, lean and athletic. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. The crystals look like real cut gemstones with sharp facets; only the glaive blade holds a soft inner sunfire inside the crystal (her signature), nothing else glows.
- Effects: none outside the blade (no sparks, flying shards, particles, smoke, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a young woman knight-commander whose topaz glaive carries a captured noon
- Face: determined, fierce; amber eyes looking straight at the viewer; a thin pale scar across her left cheek.
- Hair: copper-auburn; one long thick braid whipping behind her in the wind; loose strands across the forehead.
- Armour: ornate plate of white enamel and polished gold; sunburst engravings on the breastplate, pauldrons and thigh plates; a cluster of faceted topaz crystals on the right pauldron; small topaz stones in the belt and bracers.
- Cloth: a crimson-rose (#B42E71, a deep crimson with a rose undertone) half-cape and tabard flowing with the motion.
- Weapon: a long glaive, longer than she is; the pole wrapped in white and crimson-rose leather; the gold crossguard shaped like sun rays; the blade is ONE huge faceted topaz crystal.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the centre of her breastplate, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.
- Palette: white enamel #F4F1EA, polished gold #D4A94A, crimson-rose #B42E71 cloth, copper hair, amber eyes.

POSE & COMPOSITION
- Pose P2 Advance: a dynamic lunge in three-quarter view, body turned slightly to the viewer's left, swinging the glaive diagonally down toward the lower-left foreground with strong foreshortening.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The glaive blade is in the lower-left third and never enters the empty upper-left area; the braid streams to the right.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow anywhere except inside the blade crystal, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, flying shards, a banner, fleur-de-lis or lily symbols, a second weapon, teal or green crystals.
```

*Варіант B: малиново-помаранчевий плащ, як у затвердженому v1 і в `vesta_sheet_v1.png`.*

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7.5–8 heads tall, lean and athletic. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. The crystals look like real cut gemstones with sharp facets; only the glaive blade holds a soft inner sunfire inside the crystal (her signature), nothing else glows.
- Effects: none outside the blade (no sparks, flying shards, particles, smoke, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a young woman knight-commander whose topaz glaive carries a captured noon
- Face: determined, fierce; amber eyes looking straight at the viewer; a thin pale scar across her left cheek.
- Hair: copper-auburn; one long thick braid whipping behind her in the wind; loose strands across the forehead.
- Armour: ornate plate of white enamel and polished gold; sunburst engravings on the breastplate, pauldrons and thigh plates; a cluster of faceted topaz crystals on the right pauldron; small topaz stones in the belt and bracers.
- Cloth: a crimson-orange (#C0392B) half-cape and tabard flowing with the motion.
- Weapon: a long glaive, longer than she is; the pole wrapped in white and crimson-orange leather; the gold crossguard shaped like sun rays; the blade is ONE huge faceted topaz crystal.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the centre of her breastplate, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.
- Palette: white enamel #F4F1EA, polished gold #D4A94A, crimson-orange #C0392B cloth, copper hair, amber eyes.

POSE & COMPOSITION
- Pose P2 Advance: a dynamic lunge in three-quarter view, body turned slightly to the viewer's left, swinging the glaive diagonally down toward the lower-left foreground with strong foreshortening.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The glaive blade is in the lower-left third and never enters the empty upper-left area; the braid streams to the right.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow anywhere except inside the blade crystal, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, flying shards, a banner, fleur-de-lis or lily symbols, a second weapon, teal or green crystals.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `vesta_sheet_front.png`. Якщо обрали варіант B (помаранчевий плащ) — **пропустіть**: `vesta_sheet_v1.png` уже підходить. Для варіанта A — згенеруйте:

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш (варіант A) + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the young woman knight-commander with a copper-auburn braid, amber eyes, a thin scar on the left cheek, white-enamel and polished-gold plate with sunburst engravings, a topaz crystal cluster on the right pauldron, a star-cut topaz heart gem on the breastplate, a crimson-rose (#B42E71, a deep crimson with a rose undertone) half-cape and tabard.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The glaive is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The half-cape hangs straight down behind her and does not cover the arms; the braid hangs down her back over the cape.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult anatomy, about 7.5–8 heads tall, lean and athletic; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `vesta_sheet_sideback.png`. Варіант A:

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `vesta_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `vesta_sheet_side.png`, права → `vesta_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the young woman knight-commander with a copper-auburn braid, amber eyes, a thin scar on the left cheek, white-enamel and polished-gold plate with sunburst engravings, a topaz crystal cluster on the right pauldron, a star-cut topaz heart gem on the breastplate, a crimson-rose (#B42E71, a deep crimson with a rose undertone) half-cape and tabard.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The braid lies down the middle of the back over the cape; the full cape is visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7.5–8 heads tall, lean and athletic.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

Варіант B (референс — `vesta_sheet_v1.png`):

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the young woman knight-commander with a copper-auburn braid, amber eyes, a thin scar on the left cheek, white-enamel and polished-gold plate with sunburst engravings, a topaz crystal cluster on the right pauldron, a star-cut topaz heart gem on the breastplate, a crimson-orange (#C0392B) half-cape and tabard.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The braid lies down the middle of the back over the cape; the full cape is visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7.5–8 heads tall, lean and athletic.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «glaive»:* ✓ вже є (`assets/heroes/vesta/glaive.glb`, зроблено з `vesta_glaive_for_meshy.png`). Нічого не генеруйте.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Auto (кластер кристалів лише на правому наплічнику)**.

```
Lean young woman knight-commander, copper-auburn braid, white enamel plate armour with gold sunburst engravings, crimson-rose half-cape and tabard, a cluster of golden amber topaz crystals on the right pauldron, a star-shaped topaz on the breastplate. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Коса — 5 скриптових кісток, пів-плащ — 4 (+ `SpringBoneSimulator3D`, я додам). Глефа вже є — на `hand_r`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | глефа на плечі, коса гойдається |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | впевнений крок, глефа низько збоку |
| `attack_a` | Sword Slash / Spear Sweep | 0.6–0.8 с | ні | горизонтальний розмах |
| `attack_b` | Upward Slash | 0.9–1.1 с | ні | висхідний удар («Полудень») |
| `ult_cast` | Power Up / Ground Plant | 1.2 с | ні | встромляє глефу в землю |
| `ult_leap` | Jump Attack | 1.0 с | ні | стрибок «Сонцекрок» і удар |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | глефа вгору |
| `flourish` | Weapon Twirl | 2.5 с | ні | обертає глефу |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Плазма).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Сонцесходження / Sunrise* — `vesta_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Sunrise (ultimate skill)
- a glaive planted upright in the centre of a five-ray sunburst

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Сонячна глефа / Sun Glaive* — `vesta_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Sun Glaive (attack skill)
- a crescent slash arc that leaves three small embers behind it

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Клич Світанку / Dawn Call* — `vesta_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Dawn Call (army rally skill)
- a half sun rising above a horizon line with five rays

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Сонцестояння / Solstice* — `vesta_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Solstice (awakened skill)
- two suns overlapping, one large and one smaller

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H01 `titan` — Горан — Кам'яний велет / Goran — the Stone Titan

РЕМЕЙК стартера в реалістичних пропорціях (замінює стару модель `titan`). Як референс особи додайте старий рендер/сплеш Титана, але пропорції — нові. Роль: a colossal stone golem guardian, a walking mountain.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Кварц / Quartz | Страж | Кінетика | Кам'яне Серце | створіння (кам'яний голем), ч. | P2 Advance | clear colourless quartz | round rose-cut, the centre of his white-enamel and gold chest plate |

**(a) 2D-сплеш** — `titan_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` + старий сплеш/рендер цього героя (лише як референс особи й кольорів) · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a colossal stone golem about 2.4 m tall with heavy but anatomically plausible mass; a small head (about one ninth of his height), huge forearms and fists, short sturdy legs. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes.

CHARACTER - a colossal stone golem guardian, a walking mountain
- Body: weathered grey granite with natural cracks and chipped edges; a massive boulder torso much wider than the hips; huge forearms and fists with polished gold bands.
- Head: small and blocky, sunk under a heavy stone brow; two bright amber eyes deep under the brow (painted colour, not glowing).
- Growths: a thick moss mantle across the shoulders and upper back; two clusters of rough emerald-green mineral crystals growing from the shoulders; a tiny green sprout with two leaves on his left shoulder.
- Armour: a single white-enamel and gold chest plate set into the stone of his chest.
- Heart gem: one faceted round rose-cut dome (a circular stone with softly domed facets) of clear colourless quartz, about 4% of the figure height, set in the centre of his white-enamel and gold chest plate, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is clear colourless rock quartz, water-clear with a faint cool silver-grey tint. Apart from those rough emerald-green mineral growths, no coloured crystals or gems of any kind: no blue, violet, pink, gold or amber stones. The emerald-green mineral clusters on his shoulders are rough natural parts of his stone body, not cut gems; the heart gem is his ONLY cut gemstone.
- Palette: weathered granite #6E6A66, moss green #5E7A3A, rough emerald-green mineral, polished gold #D4A94A, white enamel, amber eyes #FFB040.

POSE & COMPOSITION
- Pose P2 Advance: he steps toward the viewer from a low camera and drives his huge right fist forward toward the lower-left foreground with strong foreshortening; the left arm swings back for balance; shoulders hunched with power, heavy brow lowered, calm and unstoppable.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The fist is the closest point to the camera and sits in the lower-left third of the image; it never enters the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, flying rocks or rubble, dust clouds, glowing veins, tusks or horns, any other cut gem.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `titan_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the colossal grey granite golem with the moss mantle, two rough emerald-green crystal clusters on the shoulders, the small green sprout on the left shoulder, gold bands on the fists, amber eyes and one round clear quartz heart gem in a white-enamel and gold chest plate.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. Apart from those rough emerald-green mineral growths, no coloured crystals or gems of any kind: no blue, violet, pink, gold or amber stones. The emerald-green mineral clusters on his shoulders are rough natural parts of his stone body, not cut gems; the heart gem is his ONLY cut gemstone.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- His huge stone hands hang open in the A-pose, fingers together, not clenched into fists.
- The two-leaf sprout on his left shoulder is small and firmly attached.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a colossal stone golem about 2.4 m tall with heavy but anatomically plausible mass; a small head (about one ninth of his height), huge forearms and fists, short sturdy legs; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `titan_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `titan_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `titan_sheet_side.png`, права → `titan_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the colossal grey granite golem with the moss mantle, two rough emerald-green crystal clusters on the shoulders, the small green sprout on the left shoulder, gold bands on the fists, amber eyes and one round clear quartz heart gem in a white-enamel and gold chest plate.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. Apart from those rough emerald-green mineral growths, no coloured crystals or gems of any kind: no blue, violet, pink, gold or amber stones. The emerald-green mineral clusters on his shoulders are rough natural parts of his stone body, not cut gems; the heart gem is his ONLY cut gemstone.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The moss mantle covers his upper back; both emerald clusters are visible in the profile view.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a colossal stone golem about 2.4 m tall with heavy but anatomically plausible mass; a small head (about one ninth of his height), huge forearms and fists, short sturdy legs.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Пропи:* немає окремої зброї — руки в 3D порожні або це частина тіла.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Colossal stone golem guardian, massive grey granite boulder torso, small head under a heavy brow, huge forearms and fists with gold bands, thick moss on the shoulders, two rough emerald-green crystal clusters, a white enamel and gold chest plate holding one round clear quartz gem. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid (Meshy auto-rig). Паросток на плечі — 2 скриптові кістки (я додам). Замінює процедурний `_pose_giant`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | кулаки майже торкаються землі, плечі важко дихають |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | важкий тупіт, руки низько |
| `attack_a` | Throw / Overhand Throw | 0.6–0.8 с | ні | кидок брили зверху |
| `attack_b` | Ground Slam / Punch Down | 0.9–1.1 с | ні | удар кулаком у землю (beat «Сейсміка») |
| `ult_cast` | Jump Attack / Ground Smash | 1.2 с | ні | подвійний удар двома кулаками в землю |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory / Chest Pound | 2.5 с | ні | б'є себе в груди |
| `flourish` | Showing Off | 2.5 с | ні | дає паростку залізти на палець (доведу ключами) |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Кінетика).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Смарагдовий розлом / Emerald Quake* — `titan_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Emerald Quake (ultimate skill)
- a heavy stone fist striking down onto a ground line that splits into a jagged crack, with four curved shock-wave arcs spreading outward on both sides

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Брилобій / Boulderfist* — `titan_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Boulderfist (attack skill)
- a round boulder with one deep crack, three sharp stone shards breaking off to the right

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Кам'яна шкіра / Stone Skin* — `titan_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Stone Skin (army rally skill)
- a large cupped stone hand sheltering a small soldier's helmet beneath it

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Кришталевий колос / Crystal Colossus* — `titan_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Crystal Colossus (awakened skill)
- a raised stone gauntlet studded with clear faceted crystals rendered in ivory white with pale copper reflections

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H03 `bolt` — Руді — Громовий лис / Rudi — Thunder Fox

РЕМЕЙК стартера в реалістичних пропорціях (замінює `bolt`). Як референс особи — старий сплеш/рендер лиса (кольори хутра й броні ті самі), але кристали тепер сапфірові, не бірюзові. Роль: a cocky thunder-fox ranger who fires faster than you can count.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Сапфір / Sapphire | Стрілець | Вольт | Дикі Ікла | звір (рудий лис), ч. | P6 Prowl | vivid blue sapphire (#3FA9FF) | square Asscher-cut, the centre of his crimson chest plate |

**(a) 2D-сплеш** — `bolt_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` + старий сплеш/рендер цього героя (лише як референс особи й кольорів) · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a slim athletic fox-kin with realistic anatomy, about 7 heads tall with a natural fox head and digitigrade-free humanoid legs. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (second tier): refined gear with fine trim and a few elegant details.

CHARACTER - a cocky thunder-fox ranger who fires faster than you can count
- Head: a natural red-fox head with tall dark-tipped ears, a cream muzzle, bright blue eyes and a cocky grin.
- Fur: bright orange-red (#E0602A) with a cream chest and throat; a huge bushy tail as long as his body with a cream tip.
- Armour: fitted crimson lacquered armour (#9E2030) with gold trim, gold bracers, light leather boots; storm-orchid (#EFB5EF) trim on the cloth edges.
- Headwear: a gold winged circlet across the forehead with one square sapphire.
- Heart gem: one faceted square Asscher step cut with clipped corners of vivid blue sapphire (#3FA9FF), about 4% of the figure height, set in the centre of his crimson chest plate, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.
- Palette: orange-red fur #E0602A, cream, crimson lacquer #9E2030, polished gold, storm-orchid trim #EFB5EF.

POSE & COMPOSITION
- Pose P6 Prowl: a low hunting leap toward the viewer, body stretched, one paw thrust forward with the fingers spread as if releasing a throw (the lightning is added by the game), the other arm back, the bushy tail streaming behind him in an S-curve toward the right.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the feet (full body); the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The forward paw sits in the lower-left third and never enters the empty upper-left area; the tail sweeps to the right edge.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, nine tails, a cartoon mascot look, cyan or teal gems, a lightning ball in the hand.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `bolt_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the slim orange-red fox-kin with tall dark-tipped ears, cream muzzle and chest, bright blue eyes, a long bushy tail with a cream tip, fitted crimson lacquered armour with gold trim, gold bracers, a gold winged circlet with a square sapphire and a square sapphire heart gem on the chest.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- Full body from head to toe including the ear tips, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The tail hangs down behind him and curves out to his left side so its full length is visible; it does not touch the legs.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a slim athletic fox-kin with realistic anatomy, about 7 heads tall with a natural fox head and digitigrade-free humanoid legs; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `bolt_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `bolt_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `bolt_sheet_side.png`, права → `bolt_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the slim orange-red fox-kin with tall dark-tipped ears, cream muzzle and chest, bright blue eyes, a long bushy tail with a cream tip, fitted crimson lacquered armour with gold trim, gold bracers, a gold winged circlet with a square sapphire and a square sapphire heart gem on the chest.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The tail hangs from the base of the spine, its full length visible in both views.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a slim athletic fox-kin with realistic anatomy, about 7 heads tall with a natural fox head and digitigrade-free humanoid legs.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Пропи:* немає окремої зброї — руки в 3D порожні або це частина тіла.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Slim athletic anthropomorphic red fox warrior, orange-red fur, cream muzzle and chest, tall dark-tipped ears, long bushy tail, crimson lacquered armour with gold trim, gold bracers, gold winged circlet with a square blue sapphire, square blue sapphire on the chest. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid re-rig (замінює `_pose_speedster`). Хвіст — скриптові кістки + `SpringBoneSimulator3D` (я додам).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | підстрибує на носках, хвіст смикається |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | низький спринт, хвіст стелиться |
| `attack_a` | Throw / Quick Throw | 0.6–0.8 с | ні | кидок лапою (дротик) |
| `attack_b` | Spell Cast (two hands) | 0.9–1.1 с | ні | постріл з двох лап («Рейковий постріл») |
| `ult_cast` | Jump Spin / Power Up | 1.2 с | ні | стрибок з обертом, обидві лапи вгору |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | «пістолетики» пальцями |
| `flourish` | Showing Off / Spin | 2.5 с | ні | обертає хвостом |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Вольт).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Громовий вихор / Thunder Storm* — `bolt_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Thunder Storm (ultimate skill)
- a spiral of lightning shaped like a curled fox tail wrapping around a small bright dot

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Розгалужений лис / Forked Fox* — `bolt_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Forked Fox (attack skill)
- one slim dart splitting into two forked lightning darts flying to the upper right

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Іскра зграї / Pack Spark* — `bolt_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Pack Spark (army rally skill)
- a spark jumping from the tip of a fox ear to a small machine cog

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Штормовий лис / Storm Fox* — `bolt_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Storm Fox (awakened skill)
- a tiny storm cloud with a curled fox-tail-shaped lightning bolt beneath it

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H05 `seer` — Мейра — Провидиця / Meira — the Seer

РЕМЕЙК третьої стартової героїні в реалістичних пропорціях (замінює `seer.glb`). Референс особи — старий сплеш/модель Рисі. Роль: a lynx mystic who sees through hidden gates and folds time around the enemy.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Аметист / Amethyst | Маг | Руна | Дикі Ікла | звір (рись), ж. | P3 Cast | deep violet amethyst (#7A35D6) | triangular trillion-cut, the clasp of her cape at the collarbone |

**(a) 2D-сплеш** — `seer_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` + старий сплеш/рендер цього героя (лише як референс особи й кольорів) · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a slender lynx-kin woman with realistic anatomy, about 7.5 heads tall with a natural lynx head. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth.

CHARACTER - a lynx mystic who sees through hidden gates and folds time around the enemy
- Head: a natural lynx head with long black ear tufts, charcoal fur (#2B2A30), violet eyes, a serene teasing half-smile; a small engraved violet rune mark on the forehead (a painted mark, not glowing).
- Body: slender and graceful; a short lynx tail with a white tip.
- Outfit: a deep pointed hood and a rune-indigo cape (#2E2EB4) longer than her body with a violet lining and gold filigree edges; a fitted dark indigo robe beneath with gold trim; soft leather boots.
- Shards: three small faceted amethyst shards float just above her raised palm (props, not magic, not glowing).
- Heart gem: one faceted triangular trillion cut of deep violet amethyst (#7A35D6), about 4% of the figure height, set in the clasp of her cape at the collarbone, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue, teal or sapphire tones in any stone.
- Palette: charcoal fur #2B2A30, rune indigo #2E2EB4, violet lining, gold filigree, white tail tip.

POSE & COMPOSITION
- Pose P3 Cast: one hand reaching toward the viewer, palm up, with the three amethyst shards above it; the other hand holds the edge of the cape; the cape billows out to the right; her eyes look at the viewer.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The raised hand is at chest height in the left half of the figure, below the empty upper-left area; the hood peak stays inside the frame.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a cat-girl look (she has a full lynx head), glowing eyes, magic circles, orbs of light.
```

**(a2) Варіант «очі закриті»** — `seer_splash_eyes_closed.png` (її біт появи: сплеш з'являється з закритими очима, очі відкриваються останніми). Робиться В ТОМУ Ж ЧАТІ редагуванням затвердженого сплеша.

```
Edit the attached image (the approved splash). Change ONLY the eyes: close both eyes gently, relaxed closed eyelids with the lashes visible, a serene expression. Keep everything else exactly identical: pose, composition, colours, lighting, the flat #BFBFBF background and the resolution 2160x3840. No other changes, no text.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `seer_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the slender charcoal-furred lynx-kin woman with long black ear tufts, violet eyes, a small violet rune mark on the forehead, a deep pointed hood, a rune-indigo cape with violet lining and gold filigree, a dark indigo robe and a triangular amethyst cape clasp.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue, teal or sapphire tones in any stone.

POSE & VIEW
- Full body from head to toe including the hood peak and ear tufts, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The hood is up, its pointed peak fully visible above the head; the cape hangs straight behind her and does not cover the arms.
- The short tail with its white tip hangs behind, slightly to her left side.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a slender lynx-kin woman with realistic anatomy, about 7.5 heads tall with a natural lynx head; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `seer_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `seer_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `seer_sheet_side.png`, права → `seer_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the slender charcoal-furred lynx-kin woman with long black ear tufts, violet eyes, a small violet rune mark on the forehead, a deep pointed hood, a rune-indigo cape with violet lining and gold filigree, a dark indigo robe and a triangular amethyst cape clasp.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue, teal or sapphire tones in any stone.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The full length of the cape is visible from the back; the hood peak shows in profile.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a slender lynx-kin woman with realistic anatomy, about 7.5 heads tall with a natural lynx head.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Пропи:* немає окремої зброї — руки в 3D порожні або це частина тіла.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Slender anthropomorphic lynx mystic woman, charcoal fur, long black ear tufts, white tail tip, a deep pointed indigo hood and long indigo cape with violet lining, gold filigree trim, dark indigo robe, a triangular violet amethyst clasp at the collar. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Кулі/уламки — ефекти (окремої моделі не треба).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | уламки кружляють над долонею, хвіст смикається |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | ковзний крок, плащ майорить |
| `attack_a` | Spell Cast | 0.6–0.8 с | ні | закляття однією рукою |
| `attack_b` | Two-hand Cast | 0.9–1.1 с | ні | подвійна куля |
| `ult_cast` | Power Up / Cast Overhead | 1.2 с | ні | розлом: обидві руки вперед-вгору |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | легкий уклін з посмішкою |
| `flourish` | Showing Off / Juggle | 2.5 с | ні | жонглює уламками |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Руна).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Зоряний розлом / Star Rift* — `seer_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Star Rift (ultimate skill)
- a vertical eye-shaped tear in space with three small orbs falling through it

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Передбачення / Foresight* — `seer_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Foresight (attack skill)
- two small orbs orbiting a single open eye

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Передчуття / Premonition* — `seer_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Premonition (army rally skill)
- an hourglass with a small open eye shape inside the upper bulb

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Затемнення / Eclipse* — `seer_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Eclipse (awakened skill)
- a crescent moon covering a sun, leaving only a thin bright ring

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H09 `lumen` — Люмен — Живий Опал / Lumen — the Living Opal

ЗАТВЕРДЖЕНИЙ образ (партія 1 №2). Перегенеруйте з цим промтом: реалістичні пропорції, без променя світла в кадрі. Роль: the first light that came through the Rift, a celestial being of living white opal.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Опал / Opal | Маг | Плазма | Небожителі | створіння (живий опал), воно | P3 Cast | precious opal with rainbow play-of-colour | marquise cabochon, the middle of the brow (a black-opal cabochon with vivid rainbow flecks) |

**(a) 2D-сплеш** — `lumen_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a tall slender celestial being with elegant, plausible humanoid anatomy, about 8 heads tall. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (top tier): the most ornate and otherworldly design in the game: layered luminous materials, delicate ornament and a majestic silhouette.

CHARACTER - the first light that came through the Rift, a celestial being of living white opal
- Body: smooth polished living white opal (#F2F0F7) with soft rainbow play-of-colour shimmering inside the surface; androgynous, serene and kind.
- Face: calm, serene, otherworldly; bright pure-white eyes (painted colour, not a light source).
- Crown: a halo-crown of floating opal shards in a ring above and behind the head.
- Robes: long flowing robes of pale iridescent starlight fabric with gold filigree edges and a crimson-rose (#B42E71) inner lining.
- Focus: a faceted clear crystal prism with opal fire inside, held up in the left hand.
- Heart gem: one marquise (pointed eye-shaped) smooth cabochon of precious opal with rainbow play-of-colour, about 4% of the figure height, set in the middle of the brow (a black-opal cabochon with vivid rainbow flecks), clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is precious opal with vivid play-of-colour: small shifting flecks of every rainbow colour inside a milky white (white opal) or near-black (black opal #1A1530) body. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour.
- Palette: living white opal #F2F0F7 with rainbow flecks, pale iridescent fabric, gold filigree, crimson-rose lining #B42E71.

POSE & COMPOSITION
- Pose P3 Cast: the left hand holds the prism up toward the viewer at arm's length (the light beam is added by the game), the right hand open low at the side, robes drifting as if underwater, the halo shards in a ring behind the head.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only the outermost halo shards may come close to its edge (top-tier art may break the frame slightly); never the face, hands or prism.
- The eyes are at about 30% of the image height from the top.
- The prism is at shoulder height, left of the face but outside the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a light beam, rainbow rays, a human skin tone, a gender-specific body, glowing aura.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `lumen_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the tall slender being of living white opal with rainbow flecks, a serene face with white eyes, a ring of opal shards forming a crown behind the head, long pale iridescent robes with gold filigree edges and a crimson-rose lining, and a marquise black-opal cabochon on the brow.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The prism is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The halo is a solid ring of opal shards attached to the back of the head (connected, not floating).
- The robes hang straight to the ankles and are opaque; the feet show beneath the hem.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall slender celestial being with elegant, plausible humanoid anatomy, about 8 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating (the halo ring touches the back of the head).

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `lumen_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `lumen_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `lumen_sheet_side.png`, права → `lumen_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall slender being of living white opal with rainbow flecks, a serene face with white eyes, a ring of opal shards forming a crown behind the head, long pale iridescent robes with gold filigree edges and a crimson-rose lining, and a marquise black-opal cabochon on the brow.
- COLOR LOCK: every crystal and gemstone is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The halo ring is visible behind the head in both views and touches the back of the head.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall slender celestial being with elegant, plausible humanoid anatomy, about 8 heads tall.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «prism»:* НЕ генеруйте — це проста форма, я зроблю її процедурно в рушії.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Tall slender celestial being of living white opal with rainbow flecks, serene face, white eyes, a solid ring crown of opal shards attached behind the head, long flowing pale iridescent robes with gold filigree edges and a rose inner lining, an eye-shaped opal gem on the brow. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid (ковзний біг роблю кодом). Ореол — жорстке кільце на кістці голови; призму роблю процедурно з опаловим шейдером.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | призма обертається над долонею, мантія дрейфує |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | ковзає над дорогою (ноги ледь рухаються; можна Walking повільно) |
| `attack_a` | Spell Cast | 0.6–0.8 с | ні | змах призмою |
| `attack_b` | Two-hand Cast | 0.9–1.1 с | ні | спис світла двома руками |
| `ult_cast` | Power Up / Arms Open | 1.2 с | ні | призма над головою, руки розкриті |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | плавний уклін |
| `flourish` | Showing Off | 2.5 с | ні | уламки ореолу розлітаються й повертаються (ключами) |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Плазма).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Спектральний вінець / Spectral Crown* — `lumen_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Spectral Crown (ultimate skill)
- a crown of seven rays fanning upward from a small faceted prism

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Розщеплене світло / Split Light* — `lumen_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Split Light (attack skill)
- a single beam entering a triangular prism and leaving it as two beams

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Призма вівтаря / Prism Rite* — `lumen_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Prism Rite (army rally skill)
- a faceted prism standing on a small two-step altar with three short rays

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Гра кольорів / Play of Colour* — `lumen_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Play of Colour (awakened skill)
- a circle divided into four equal segments, each with a different hatch pattern and colour: plasma rose, storm orchid, snow ivory and rune indigo (it must also read in black and white)

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H02 `arin` — Арін — Якір Світанку / Arin — Anchor of Dawn

НОВИЙ (2D → 3D). Найчастіший новий герой Порталу — хвиля 1. Роль: a young sky-harbour dock knight who swings a ship's anchor like a hammer.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Кварц / Quartz | Воїн | Кінетика | Орден Світанку | людина, ч. | P1 Guard | clear colourless quartz | round rose-cut, the ring at the top of the anchor-hammer |

**(a) 2D-сплеш** — `arin_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult heroic anatomy, about 7.5 heads tall, broad-shouldered and strong. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes.

CHARACTER - a young sky-harbour dock knight who swings a ship's anchor like a hammer
- Face: a cheerful, stubborn young man with a confident grin, freckles across the nose, warm brown eyes.
- Hair: sandy-brown, tied back in a short tail, a few loose strands.
- Outfit: a white-enamel breastplate with a single gold sunburst rivet in the centre; a long navy dock coat (#24324F) with rolled sleeves and brass buttons over it; leather gloves; sturdy boots; tarred rope and brass fittings at the belt.
- Chain: about two metres of heavy copper chain wrapped round his left forearm, the loose end hanging down.
- Weapon: an anchor-hammer: a ship's anchor turned into a war hammer; the anchor crown is the hammer head, the two curved flukes are spikes, the long shank is the haft wrapped in tarred rope and copper bands, with a ring at the top.
- Heart gem: one faceted round rose-cut dome (a circular stone with softly domed facets) of clear colourless quartz, about 4% of the figure height, set in the ring at the top of the anchor-hammer, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is clear colourless rock quartz, water-clear with a faint cool silver-grey tint. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.
- Palette: white enamel #F4F1EA, polished gold, navy #24324F, pale copper #D0BBAF chain and bands, tarred-rope brown, sandy hair.

POSE & COMPOSITION
- Pose P1 Guard: he stands his ground with the weight on the back leg, the anchor-hammer planted head-down on the ground in front of him at his right side, both hands resting on the top of the haft, a confident grin; the loose end of the chain swings low toward the lower left.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The anchor head rests in the lower part of the image; the chain stays below the middle of the image height.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a longsword, a blue-and-silver knight look, a pirate skull, a captain's tricorn.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `arin_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the young freckled dock knight with sandy hair tied back, a white-enamel breastplate with a gold sunburst rivet, a long navy dock coat with brass buttons, copper chain wrapped round his left forearm, leather gloves and boots.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The anchor-hammer is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The copper chain stays wrapped round his left forearm; its loose end hangs straight down about 40 cm, not touching the leg.
- The navy coat hangs straight; its tails do not cover the hands.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult heroic anatomy, about 7.5 heads tall, broad-shouldered and strong; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `arin_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `arin_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `arin_sheet_side.png`, права → `arin_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the young freckled dock knight with sandy hair tied back, a white-enamel breastplate with a gold sunburst rivet, a long navy dock coat with brass buttons, copper chain wrapped round his left forearm, leather gloves and boots.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The coat tails hang straight down the back; the short hair tail is visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult heroic anatomy, about 7.5 heads tall, broad-shouldered and strong.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «anchor-hammer»* — `arin_prop_anchor.png` → Meshy Image to 3D → `arin_prop_anchor.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same anchor-hammer as in the attached reference image (the character's approved splash): a ship's anchor turned into a war hammer: the anchor crown is the hammer head, two curved flukes are spikes, the long shank is the haft wrapped in tarred rope and copper bands, a ring at the top holding one round rose-cut clear quartz.
- COLOR LOCK: the stone in the top ring is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

VIEW
- The whole object alone, shown once, standing upright, head down, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «anchor-hammer»:

```
War hammer made from a ship's anchor: anchor crown as the hammer head, two curved flukes as spikes, long shank haft wrapped in tarred rope and copper bands, a ring at the top holding one round clear quartz stone. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Auto (ланцюг лише на лівій руці)**.

```
Young dock knight, broad shoulders, sandy hair tied back, freckles, white enamel breastplate with a gold sunburst rivet, long navy dock coat with brass buttons, leather gloves, heavy copper chain wrapped around the left forearm, sturdy boots. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Ланцюг на лівому передпліччі — 6 скриптових кісток (я додам); молот — окрема модель на `hand_r`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | спирається на руків'я, крутить ланцюг |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | впевнений біг, якір на правому плечі |
| `attack_a` | Sword Slash / Overhead Smash | 0.6–0.8 с | ні | важкий удар зверху |
| `attack_b` | Throw | 0.9–1.1 с | ні | кидок якоря на ланцюгу |
| `ult_cast` | Jump Attack | 1.2 с | ні | стрибок і кидок якоря |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | підкидає молот на плече |
| `flourish` | Weapon Twirl | 2.5 с | ні | розкручує ланцюг |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Кінетика).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Якір з неба / Skyfall Anchor* — `arin_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Skyfall Anchor (ultimate skill)
- a heavy ship's anchor falling point-down onto a cracked ground line, its chain looping up behind it

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Якірний удар / Anchor Strike* — `arin_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Anchor Strike (attack skill)
- an anchor-hammer head mid-swing with one curved speed arc behind it

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Муштра Світанку / Dawn Drill* — `arin_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Dawn Drill (army rally skill)
- two interlocked chain links crossed diagonally with a small sunburst rivet at the crossing

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Розгін / Momentum* — `arin_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Momentum (awakened skill)
- three stacked chevrons pointing up and to the right, the front one the largest, like a gathering surge

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H04 `eira` — Ейра — Сестра Інею / Eira — Rime Sister

НОВА (2D → 3D). Хвиля 1. Роль: a temple field medic whose ice harp freezes the enemy and closes her soldiers' wounds.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Сапфір / Sapphire | Цілитель | Мороз | Орден Світанку | людина, ж. | P3 Cast | vivid blue sapphire (#3FA9FF) | square Asscher-cut, the clasp of her high fur collar |

**(a) 2D-сплеш** — `eira_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7.5–8 heads tall, tall and slender. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (second tier): refined gear with fine trim and a few elegant details.

CHARACTER - a temple field medic whose ice harp freezes the enemy and closes her soldiers' wounds
- Face: calm, compassionate, focused; clear grey eyes; a few freckles of frost on the cheeks.
- Hair: dark brown, in a low bun; the hood is up but pushed back so it frames her face.
- Outfit: a long hooded habit-coat of silver-white wool (#EEF1F4) with white-enamel shoulder pieces, a high frost-fur collar, pale gold trim, a steel-blue lining (#5C7590) and snow-ivory (#F4F8DF) embroidery along the hem.
- Weapon: a harp-staff as tall as she is: a slim silver staff whose head is a small open harp with six thin silver strings, each string tied with a small square sapphire node.
- Heart gem: one faceted square Asscher step cut with clipped corners of vivid blue sapphire (#3FA9FF), about 4% of the figure height, set in the clasp of her high fur collar, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No clear white or icy crystals that could read as quartz; frost is only fur, embroidery and fabric.
- Palette: silver-white wool #EEF1F4, white enamel, pale gold, steel-blue lining #5C7590, snow-ivory embroidery #F4F8DF, dark brown hair.

POSE & COMPOSITION
- Pose P3 Cast: the harp-staff raised in her left hand, her right hand open over the strings as if about to strike a chord (no magic in the image), the coat hem flowing, her gaze toward the viewer.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The harp head sits right of the face and at the same height or lower; the staff runs diagonally down to the lower left.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a nun's habit, a cross, religious symbols, ice crystals, snowflakes floating in the air.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `eira_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the tall slender medic with dark brown hair in a low bun under a pushed-back hood, grey eyes, a long silver-white wool habit-coat with white-enamel shoulder pieces, a high frost-fur collar, pale gold trim, steel-blue lining and a square sapphire heart gem on the collar clasp.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The harp-staff is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No clear white or icy crystals that could read as quartz; frost is only fur, embroidery and fabric.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The hood is pushed back off the head; the long coat hangs straight to the shins and does not cover the hands.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult anatomy, about 7.5–8 heads tall, tall and slender; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `eira_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `eira_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `eira_sheet_side.png`, права → `eira_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall slender medic with dark brown hair in a low bun under a pushed-back hood, grey eyes, a long silver-white wool habit-coat with white-enamel shoulder pieces, a high frost-fur collar, pale gold trim, steel-blue lining and a square sapphire heart gem on the collar clasp.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No clear white or icy crystals that could read as quartz; frost is only fur, embroidery and fabric.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The hood lies on her upper back; the coat hem is level all round.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7.5–8 heads tall, tall and slender.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «harp-staff»* — `eira_prop_harpstaff.png` → Meshy Image to 3D → `eira_prop_harpstaff.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same harp-staff as in the attached reference image (the character's approved splash): a slim silver staff as tall as she is whose head is a small open harp with six thin silver strings, each string tied with a small square sapphire node, pale gold trim.
- COLOR LOCK: every string node is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

VIEW
- The whole object alone, shown once, standing upright, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «harp-staff»:

```
Slim silver staff whose head is a small open harp frame with six thin strings, each with a small square blue sapphire node, pale gold trim, elegant and light. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Tall slender young woman healer, dark brown hair in a low bun, hood pushed back, long silver-white wool habit-coat with white enamel shoulder pieces, high frost-fur collar, pale gold trim, steel-blue lining, a square blue sapphire on the collar. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Арфа-посох — окрема модель на `hand_l`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | перебирає одну струну (пару з дихання додам ефектом) |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | швидкі ковзні кроки, поли пальта летять |
| `attack_a` | Spell Cast | 0.6–0.8 с | ні | щипок струни вперед |
| `attack_b` | Two-hand Cast | 0.9–1.1 с | ні | `heal`: акорд двома руками |
| `ult_cast` | Power Up / Cast Overhead | 1.2 с | ні | арфа над головою широким помахом |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Bow / Victory | 2.5 с | ні | уклін |
| `flourish` | Weapon Twirl | 2.5 с | ні | обертає арфу |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Мороз).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Зимова літанія / Winter Litany* — `eira_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Winter Litany (ultimate skill)
- a small harp silhouette with a large six-pointed snowflake rising from its strings

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Промінь інею / Rime Ray* — `eira_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Rime Ray (attack skill)
- a straight beam that ends in a crisp frost star

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Обітниця сестер / Sisters' Vow* — `eira_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Sisters' Vow (army rally skill)
- an open hand held protectively above a small kite shield with a heart-shaped notch

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Тиха варта / Quiet Vigil* — `eira_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Quiet Vigil (awakened skill)
- a small kneeling figure sealed inside a block of clear ice

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H06 `iskar` — Іскар — Мисливець на комети / Iskar — Comet Hunter

НОВИЙ (2D → 3D). Хвиля 1. Роль: a star-born sniper who lines up the road and threads one comet through all of it.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Аметист / Amethyst | Стрілець | Вольт | Небожителі | створіння (зорянородний), ч. | P4 Aim | deep violet amethyst (#7A35D6) | triangular trillion-cut, the centre of his sternum |

**(a) 2D-сплеш** — `iskar_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a very tall slender star-born being with elongated but plausible humanoid anatomy, about 8 heads tall, long arms. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth.

CHARACTER - a star-born sniper who lines up the road and threads one comet through all of it
- Head: a smooth white enamel-like mask face with two calm white eyes and no mouth; three long ribbon-like filaments of pale fabric sweep back from the crown like a comet tail.
- Body: smooth night-blue star-glass (#1B2350) speckled with tiny white stars, like a night sky inside dark glass (a material, not a crystal).
- Outfit: white-enamel shoulder plates and greaves with gold filigree; a storm-orchid (#EFB5EF) gauze sash at the waist; the filament tips are storm-orchid too.
- Weapon: a rail-bow: a long asymmetric bow made of two parallel amethyst crystal rails joined by small gold bridges, strung with a thin gold wire.
- Heart gem: one faceted triangular trillion cut of deep violet amethyst (#7A35D6), about 4% of the figure height, set in the centre of his sternum, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue sapphire tones in any crystal; the night-blue body is smooth dark glass, not crystal.
- Palette: night star-glass #1B2350 with white specks, white enamel, gold filigree, storm-orchid #EFB5EF, violet amethyst rails.

POSE & COMPOSITION
- Pose P4 Aim: he draws the rail-bow to full tension and aims toward the viewer's lower left, the bow tilted on a diagonal, body sideways and elongated, the three filaments streaming back to the right.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The front end of the bow points to the lower-left third; the bow never enters the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a mouth, a human face, an arrow made of light, glowing filaments, a sci-fi robot look.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `iskar_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the very tall slender star-born with a smooth white mask face (two white eyes, no mouth), three long pale filaments swept back from the crown, a night-blue star-glass body with white star specks, white-enamel shoulder plates and greaves with gold filigree, a storm-orchid sash and a triangular amethyst heart gem on the sternum.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The rail-bow is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue sapphire tones in any crystal; the night-blue body is smooth dark glass, not crystal.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The three filaments sweep back from the crown and hang down along his back without touching the arms.
- The smooth mask faces straight forward, both white eyes open.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a very tall slender star-born being with elongated but plausible humanoid anatomy, about 8 heads tall, long arms; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `iskar_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `iskar_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `iskar_sheet_side.png`, права → `iskar_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the very tall slender star-born with a smooth white mask face (two white eyes, no mouth), three long pale filaments swept back from the crown, a night-blue star-glass body with white star specks, white-enamel shoulder plates and greaves with gold filigree, a storm-orchid sash and a triangular amethyst heart gem on the sternum.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue sapphire tones in any crystal; the night-blue body is smooth dark glass, not crystal.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The three filaments hang down the middle of the back, fully visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a very tall slender star-born being with elongated but plausible humanoid anatomy, about 8 heads tall, long arms.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «rail-bow»* — `iskar_prop_railbow.png` → Meshy Image to 3D → `iskar_prop_railbow.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same rail-bow as in the attached reference image (the character's approved splash): a long asymmetric bow of two parallel amethyst crystal rails joined by small gold bridges, strung with a thin gold wire.
- COLOR LOCK: each crystal rail is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems.

VIEW
- The whole object alone, shown once, standing upright, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «rail-bow»:

```
Long asymmetric fantasy bow made of two parallel violet amethyst crystal rails joined by small gold bridges, a thin gold wire string, elegant and sharp. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Very tall slender star-born archer, smooth white mask face with two white eyes and no mouth, three long pale ribbon filaments swept back from the crown, dark night-blue glass body with white star specks, white enamel shoulder plates and greaves, gold filigree, orchid sash. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. 3 філаменти — по 4 скриптові кістки + `SpringBoneSimulator3D` (я додам). Лук — окрема модель на `hand_l`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | ширяє на носках, філаменти дрейфують |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | довгі ковзні кроки |
| `attack_a` | Archery Shot | 0.6–0.8 с | ні | швидкий постріл |
| `attack_b` | Archery Shot (charged) | 0.9–1.1 с | ні | повний натяг, рейковий постріл |
| `ult_cast` | Power Up | 1.2 с | ні | лук до неба, потім вперед |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | спокійний кивок, лук вертикально |
| `flourish` | Weapon Twirl | 2.5 с | ні | обертає лук за спиною |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Вольт).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Падіння комети / Comet Fall* — `iskar_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Comet Fall (ultimate skill)
- a comet diving straight down onto a long straight road line, its tail streaming up behind it

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Зоряна голка / Starneedle* — `iskar_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Starneedle (attack skill)
- one thin needle-like arrow piercing through two dots in a straight line

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Зоряна лінія / Star Line* — `iskar_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Star Line (army rally skill)
- a straight arrow flying along a ruler-like line with small tick marks

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Перигелій / Perihelion* — `iskar_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Perihelion (awakened skill)
- a small planet with a tight orbit ellipse around it and a tiny comet riding the orbit

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H08 `vartan` — Вартан — Серце Горна / Vartan — Forgeheart

НОВИЙ (2D → 3D). Хвиля 2. Роль: a living forge-fortress, an upright knightly automaton that walls off turrets and blades.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Топаз / Topaz | Страж | Техно | Кам'яне Серце | створіння (автоматон), ч. | P5 Bulwark | golden amber topaz (#FFB52E) | five-pointed star-cut, the furnace in the centre of his chest, seen through the grille (the star-cut topaz core) |

**(a) 2D-сплеш** — `vartan_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: an upright knightly automaton with plausible humanoid anatomy, about 7.5 heads tall, very broad shoulders and a slim waist. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a living forge-fortress, an upright knightly automaton that walls off turrets and blades
- Head: a small knight's helm with a T-shaped visor slit and a white-enamel visor plate; no face.
- Body: armour plates of rough dark basalt (#2E2B2B) edged and riveted in polished brass (#B08A3E); very broad pauldrons with white-enamel caps; a slim brass waist; soot in the joints; a furnace grille in the chest through which the heart gem is seen.
- Left forearm: a kite-shield of basalt slabs edged in brass, built into the arm.
- Right forearm: a short rivet cannon with a drum magazine, built into the arm.
- Drones: two fist-sized round brass ward-drones float beside his shoulders, each with one topaz lens and a tiny signal-lime (#5ED437) lamp.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the furnace in the centre of his chest, seen through the grille (the star-cut topaz core), clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems. No orange lava, no molten metal, no fire anywhere (that is the enemy's colour).
- Palette: basalt #2E2B2B, polished brass #B08A3E, white enamel, soot black, tiny signal-lime lamps #5ED437.

POSE & COMPOSITION
- Pose P5 Bulwark: a low braced stance, the shield forearm pushed forward toward the viewer, the cannon arm cocked back at hip height, the two drones hovering at his shoulders, heavy and unbreakable.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 30% of the image height from the top.
- The shield is the closest object, centred low-left of the figure, never in the empty upper-left area; the drones stay right of the helm.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a human face, a sci-fi robot or mecha look, glowing visor, fire, steam clouds.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `vartan_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the upright knightly automaton with a small helm and T-shaped visor, white-enamel visor plate and pauldron caps, basalt armour plates edged in brass, a slim brass waist, a basalt kite-shield built into the left forearm, a short rivet cannon with a drum magazine built into the right forearm, and a furnace grille in the chest holding a star-cut topaz core.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems. No orange lava, no molten metal, no fire anywhere (that is the enemy's colour).

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The shield is part of the left forearm and the cannon part of the right forearm; both arms stay straight in the A-pose.
- The two ward-drones are NOT in this image (they are separate models).
- The T-visor helm faces straight forward (there is no face).

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; an upright knightly automaton with plausible humanoid anatomy, about 7.5 heads tall, very broad shoulders and a slim waist; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `vartan_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `vartan_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `vartan_sheet_side.png`, права → `vartan_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the upright knightly automaton with a small helm and T-shaped visor, white-enamel visor plate and pauldron caps, basalt armour plates edged in brass, a slim brass waist, a basalt kite-shield built into the left forearm, a short rivet cannon with a drum magazine built into the right forearm, and a furnace grille in the chest holding a star-cut topaz core.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems. No orange lava, no molten metal, no fire anywhere (that is the enemy's colour).

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The back plates show a small furnace chimney between the shoulder blades.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; an upright knightly automaton with plausible humanoid anatomy, about 7.5 heads tall, very broad shoulders and a slim waist.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «ward-drone»* — `vartan_prop_drone.png` → Meshy Image to 3D → `vartan_prop_drone.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same ward-drone as in the attached reference image (the character's approved splash): one fist-sized round brass ward-drone with one star-cut topaz lens on the front, a tiny signal-lime lamp on top and small stubby fins.
- COLOR LOCK: the lens is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

VIEW
- The whole object alone, shown once, floating level, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «ward-drone»:

```
Small round brass ward drone the size of a fist, one star-shaped amber topaz lens on the front, a tiny lime lamp on top, four stubby fins, rivets. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Off (щит і гармата різні)**.

```
Upright knightly automaton guardian, small helm with a T-shaped visor, broad pauldrons with white enamel caps, slim brass waist, dark basalt armour plates edged in brass, a basalt kite shield built into the left forearm, a rivet cannon built into the right forearm, a chest furnace grille. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Дрони — окремі моделі на процедурній орбіті (я). Розкладання щита — 2 скриптові кістки (я).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | щит упертий у землю, «дихає» горном, дрони кружляють |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | важкий розмірений марш |
| `attack_a` | Shooting / Pistol Shot | 0.6–0.8 с | ні | віддача гармати |
| `attack_b` | Shield Bash | 0.9–1.1 с | ні | удар щитом |
| `ult_cast` | Ground Slam | 1.2 с | ні | щит з розмаху в землю |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | випускає пару з плечей (додам ефектом) |
| `flourish` | Showing Off | 2.5 с | ні | дрони роблять петлю (ключами) |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Техно).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Кована стіна / Forgewall* — `vartan_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Forgewall (ultimate skill)
- a low wall of basalt blocks rising out of the ground with two big rivets on top

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Заклепкова гармата / Rivet Cannon* — `vartan_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Rivet Cannon (attack skill)
- a single large rivet framed by a targeting reticle

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Кований стрій / Forged Rank* — `vartan_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Forged Rank (army rally skill)
- three crossbow bolts flying side by side in a neat row

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Броньований марш / Armoured March* — `vartan_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Armoured March (awakened skill)
- a kite shield with a gear-toothed rim

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### H10 `pava` — Пава — Тисячоока / Pava — the Thousand-Eyed

НОВА (2D → 3D). Хвиля 2. Роль: the grove's thousand-eyed guardian; when she opens her fan, the fallen stand up again.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Опал / Opal | Цілитель | Руна | Дикі Ікла | звір (пава), ж. | P1 Guard | precious opal with rainbow play-of-colour | marquise cabochon, the front of her white-enamel high collar |

**(a) 2D-сплеш** — `pava_splash.png`

Налаштування: формат **9:16** · якість **4K** (мінімум 1440×2560, ідеально 2160×3840) · 2–4 варіанти · референс: `style_anchor.png` · завантажуйте ОРИГІНАЛ кнопкою «Завантажити» (PNG), не скріншот.

```
Create ONE vertical hero splash illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 9:16 (portrait). Resolution 2160x3840 px (4K); never below 1440x2560.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a tall regal peacock-kin woman with plausible anatomy, about 7.5 heads tall with a small bird head and a long elegant neck. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (top tier): the most ornate and otherworldly design in the game: layered luminous materials, delicate ornament and a majestic silhouette.

CHARACTER - the grove's thousand-eyed guardian; when she opens her fan, the fallen stand up again
- Head: a small elegant bird head with a five-feather crest, calm dark eyes, a regal maternal expression.
- Plumage: deep rune-indigo (#2E2EB4) feathers shading to ink-teal (#1F4E5A) on the body and wing-like sleeves.
- Outfit: a white-enamel high collar and bracers with gold filigree; strings of bone-white carved heartwood beads.
- Train: a long train of eye-feathers behind her; every eye-spot is an opal cabochon.
- Staff: a slim quill staff of gold and heartwood topped by one opal eye.
- Heart gem: one marquise (pointed eye-shaped) smooth cabochon of precious opal with rainbow play-of-colour, about 4% of the figure height, set in the front of her white-enamel high collar, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is precious opal with vivid play-of-colour: small shifting flecks of every rainbow colour inside a milky white (white opal) or near-black (black opal #1A1530) body. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour. No green or blue gems; the eye-spots are opal, never green or turquoise stones.
- Palette: rune indigo #2E2EB4, ink-teal #1F4E5A, white enamel, gold filigree, bone-white beads, opal eye-spots.

POSE & COMPOSITION
- Pose P1 Guard: she stands tall with the quill staff planted at her side, the feather train half-open behind her like a halo fanning toward the upper right, gaze lowered toward the viewer, serene and powerful.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to the knees; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character occupies the right two-thirds of the canvas. Keep the upper-left area (left 40% of the width, top 40% of the height) as empty flat background: it is reserved for the game's emblem and name. The half-open fan opens toward the upper right; its left edge stays outside the empty upper-left area; never the face, hands or staff.
- The eyes are at about 30% of the image height from the top.
- The staff stands vertically right of her body; the fan frames the head from behind on the right side.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a real peacock with a bird body, green gems, a fully open fan covering the upper-left area.
```

**(b) Листи для Meshy** (з них робиться 3D-модель; зброя й пропи — окремими моделями, тому руки порожні).

*b1 Фронт* — `pava_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджений сплеш цього героя + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на сплеші.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved splash): the tall regal peacock-kin woman with a small bird head and five-feather crest, deep rune-indigo plumage shading to ink-teal, a white-enamel high collar and bracers with gold filigree, bone-white bead strings, a long closed train of eye-feathers with opal eye-spots and a marquise opal heart gem on the collar.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The quill staff is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour. No green or blue gems; the eye-spots are opal, never green or turquoise stones.

POSE & VIEW
- Full body from head to toe including the crest, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The feather train is CLOSED: it hangs straight down behind her to the floor, narrow, not spread.
- The quill staff is NOT in this image (separate model).
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall regal peacock-kin woman with plausible anatomy, about 7.5 heads tall with a small bird head and a long elegant neck; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `pava_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `pava_sheet_front.png` + сплеш. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `pava_sheet_side.png`, права → `pava_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall regal peacock-kin woman with a small bird head and five-feather crest, deep rune-indigo plumage shading to ink-teal, a white-enamel high collar and bracers with gold filigree, bone-white bead strings, a long closed train of eye-feathers with opal eye-spots and a marquise opal heart gem on the collar.
- COLOR LOCK: every crystal and gemstone is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour. No green or blue gems; the eye-spots are opal, never green or turquoise stones.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The closed train hangs down the middle of the back to the floor; the crest shows in profile.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall regal peacock-kin woman with plausible anatomy, about 7.5 heads tall with a small bird head and a long elegant neck.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «quill staff»* — `pava_prop_staff.png` → Meshy Image to 3D → `pava_prop_staff.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same quill staff as in the attached reference image (the character's approved splash): a slim staff of gold and carved heartwood shaped like a long quill, topped by one marquise opal eye-cabochon.
- COLOR LOCK: the eye-cabochon is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour.

VIEW
- The whole object alone, shown once, standing upright, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «quill staff»:

```
Slim staff shaped like a long quill feather, gold and carved heartwood, topped by one eye-shaped opal cabochon with rainbow flecks. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

*b3 Проп «open feather fan»* — `pava_prop_fan.png` (лише як текстура; 3D не потрібне, меш я зроблю кодом).
Налаштування: формат **1:1** · якість **2K+** · референс: сплеш (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same open feather fan as in the attached reference image (the character's approved splash): her train fully opened into a complete circular fan of indigo and ink-teal eye-feathers, every eye-spot an opal cabochon, gold quill tips.
- COLOR LOCK: every eye-spot is precious opal with rainbow play-of-colour. No plain single-colour crystals or gems (no plain blue, green, violet, gold or clear stones); every stone shows opal play-of-colour.

VIEW
- The whole object alone, shown once, fully open, flat to the camera, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **15 000 трикутників** (Triangle) · текстура в грі 1024² (герой; normal 1024² — за бажанням) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Tall regal peacock-kin woman, small bird head with a five-feather crest, long neck, deep indigo plumage shading to ink-teal, white enamel high collar and bracers, gold filigree, bone-white beads, a long closed train of eye-feathers behind, an eye-shaped opal gem on the collar. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid. Шлейф — 5 скриптових кісток; відкрите віяло — окрема меш-модель, яку я розкладаю кодом (без blend shapes), текстура — з листа «open feather fan».

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 3.0 с | так | чистить пір'я на рукаві, шлейф мерехтить |
| `run` | Running / Run Forward | цикл 0.7–0.8 с | так | довгий пташиний крок, шлейф піднятий |
| `attack_a` | Spell Cast / Staff Swing | 0.6–0.8 с | ні | змах посохом, дротики-пір'я |
| `attack_b` | Spell Cast (snap) | 0.9–1.1 с | ні | різко складає віяло |
| `ult_cast` | Power Up / Arms Open | 1.2 с | ні | руки розкриваються, віяло відкриваю кодом |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся, без падіння |
| `victory` | Victory | 2.5 с | ні | царствений уклін |
| `flourish` | Showing Off / Slow Turn | 2.5 с | ні | повне віяло й повільний оберт |
| `summon_pose` | Power Up / Heroic Pose (основа) | 1.2 с | ні | поза появи з Порталу; кінцевий кадр я доведу до пози сплеша |

Смерті для героя немає (бій програє армія), окремий кліп не потрібен. `summon_pose` я доводжу ключами до пози сплеша.

**(e) Іконки навичок** (без рамки — рамку самоцвіту малює гра; колір мотиву — стихія Руна).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + сплеш героя · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

*Ульта — Тисяча очей / Thousand Eyes* — `pava_skill_ult.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Thousand Eyes (ultimate skill)
- an open semicircular fan of feathers with one large eye-spot in the centre

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.
- This is the hero's most powerful skill: make it the boldest, most dynamic motif of the set.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Атака — Очі пір'я / Feather Eyes* — `pava_skill_attack.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Feather Eyes (attack skill)
- a single feather dart with an eye-spot near its tip, flying to the upper right

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Клич — Вічне віяло / Ever-Fan* — `pava_skill_rally.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Ever-Fan (army rally skill)
- a half-open feather fan seen from the front

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Пробудження — Пробуджені очі / Opened Eyes* — `pava_skill_awaken.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Opened Eyes (awakened skill)
- a closed eye just opening, a thin line of light between the eyelids

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

## 4. Чемпіони (12)

Картка 3:4 до середини стегна (вона ж — бюст у камео й на медальйоні). Далі як у героїв, але одна іконка — Дія чемпіона. Реалістичні пропорції (додаток 5 скасовує «трохи чібі» з партії 1). Порядок — за §2: Отто → Альба → Міла → Іво → Борко → Тая → Брант → Тео → Олена → Німб → Дара → Менгір.

### C15 `otto` — Отто — Ходяча фортеця / Otto — Walking Fortress

ЗАТВЕРДЖЕНИЙ образ (партія 1 №8). Перегенеруйте: реалістичні пропорції, сапфірові (не бірюзові) кристали. Сценарна скриня №1 для Горана — потрібна рано. Роль: an ancient tortoise whose shell has grown into a little crystal fortress; the first clash breaks on him.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Сапфір / Sapphire | Страж | Кінетика | Кам'яне Серце | звір (черепаха), ч. (≈1.55 м) | P5 Bulwark | vivid blue sapphire (#3FA9FF) | square Asscher-cut, the boss of his bronze tower shield |

**(a) Картка чемпіона (3:4, до середини стегна)** — `otto_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` + ваша картка з партії 1 (лише як референс образу) · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a broad heavy tortoise-kin with plausible reptile anatomy, about 6 heads tall. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (second tier): refined gear with fine trim and a few elegant details.

CHARACTER - an ancient tortoise whose shell has grown into a little crystal fortress; the first clash breaks on him
- Head: a wise old tortoise head with kind, slow-blinking eyes and a wrinkled beak-like mouth.
- Skin: olive-green scales.
- Shell: a high domed stone-grey shell grown into a miniature fortress with three small towers, each tower set with sapphire crystals.
- Outfit: bronze armour bands (#A0702E) across the chest and arms, pale copper trims.
- Shield: a huge bronze tower shield.
- Heart gem: one faceted square Asscher step cut with clipped corners of vivid blue sapphire (#3FA9FF), about 4% of the figure height, set in the boss of his bronze tower shield, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.
- Palette: olive-green scales, stone grey shell, bronze #A0702E, pale copper trims, sapphire blue crystals.

POSE & COMPOSITION
- Pose P5 Bulwark: braced behind the tower shield, pushing it toward the viewer, the shell fortress rising behind his head, calm and immovable.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The shield fills the lower-left half of the figure; the fortress towers rise behind him on the right.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, cannons on the shell, a famous cartoon turtle look, turquoise crystals.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `otto_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the broad old tortoise-kin with a wise face, olive-green scales, a high domed stone-grey shell grown into a three-tower miniature fortress with sapphire crystals in the towers, bronze armour bands and pale copper trims.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The tower shield is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The shell fortress sits firmly on his back; its three towers are fully visible above the shoulders.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a broad heavy tortoise-kin with plausible reptile anatomy, about 6 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `otto_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `otto_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `otto_sheet_side.png`, права → `otto_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the broad old tortoise-kin with a wise face, olive-green scales, a high domed stone-grey shell grown into a three-tower miniature fortress with sapphire crystals in the towers, bronze armour bands and pale copper trims.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The whole shell fortress with its three towers and sapphire crystals is visible from the back.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a broad heavy tortoise-kin with plausible reptile anatomy, about 6 heads tall.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «tower shield»* — `otto_prop_towershield.png` → Meshy Image to 3D → `otto_prop_towershield.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same tower shield as in the attached reference image (the character's approved card): a huge bronze tower shield with copper trims and one square sapphire in the boss.
- COLOR LOCK: the stone in the boss is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

VIEW
- The whole object alone, shown once, standing upright, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «tower shield»:

```
Huge bronze tower shield, tall rectangle with a slightly curved top, copper trims, riveted bands, one square blue sapphire in the boss. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Broad anthropomorphic tortoise guardian, wise old face, olive-green scaly skin, a high domed stone-grey shell grown into a small three-tower fortress with blue sapphire crystals, bronze armour bands and copper trims. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid (пропорції черепахи), ≤ 30 кісток. Панцир — частина меша на хребті. Щит на `hand_l`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | повільно кліпає, переступає |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | рівний тупіт (швидший, ніж здається) |
| `action` | Shield Block | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): блок щитом |
| `special` | Ground Slam / Shield Plant | 1.0–1.4 с | ні | усе тіло: встромляє щит у землю |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | ховається в панцир, одна вежа тріскається |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Панцир-фортеця / Shell Fortress — `otto_action.png` (колір — стихія Кінетика).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Shell Fortress (champion action)
- a domed shell shaped like a small three-tower fortress planted firmly on a ground line

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C14 `alba` — Альба — Сніжне Перо / Alba — Snowquill

ЗАТВЕРДЖЕНИЙ образ (партія 1 №6). Перегенеруйте з цим промтом: реалістичні пропорції, сапфіровий (не бірюзовий) лук. Сценарна скриня №1 для Руді — потрібна рано. Роль: a silent snowy-owl archer who owns the sky.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Сапфір / Sapphire | Стрілець | Мороз | Дикі Ікла | звір (біла сова), ж. | P4 Aim | vivid blue sapphire (#3FA9FF) | square Asscher-cut, the quiver strap on her chest |

**(a) Картка чемпіона (3:4, до середини стегна)** — `alba_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` + ваша картка з партії 1 (лише як референс образу) · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a tall slender owl-kin woman with plausible anatomy, about 7.5 heads tall with a round owl head. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (second tier): refined gear with fine trim and a few elegant details.

CHARACTER - a silent snowy-owl archer who owns the sky
- Head: a round snowy-owl head with large golden eyes, a short feathered hood, a calm watchful expression.
- Plumage: white and silver with soft grey speckles; feathered sleeves that flare like wings.
- Outfit: light silver-blue leather armour, white-wood and silver fittings, a quiver of arrows with sapphire tips on her back.
- Weapon: a tall elegant longbow as tall as she is, of white wood and sapphire crystal.
- Heart gem: one faceted square Asscher step cut with clipped corners of vivid blue sapphire (#3FA9FF), about 4% of the figure height, set in the quiver strap on her chest, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No turquoise.
- Palette: white and silver plumage, grey speckles, silver-blue leather, white wood, sapphire blue crystal.

POSE & COMPOSITION
- Pose P4 Aim: she draws the longbow and aims straight at the viewer, the feathered sleeves flaring like wings, strong foreshortening on the arrow.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The bow is vertical in the centre-right; the arrow tip points at the viewer, below the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a real owl body, turquoise, glowing arrow.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `alba_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the tall slender snowy-owl-kin archer with a round owl head, large golden eyes, a short feathered hood, white and silver plumage with grey speckles, feathered wing-like sleeves, light silver-blue leather armour, a quiver of sapphire-tipped arrows and a square sapphire heart gem on the quiver strap.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The longbow is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No turquoise.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The feathered sleeves hang down from the arms like short wings without hiding the hands; the quiver is on her back.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall slender owl-kin woman with plausible anatomy, about 7.5 heads tall with a round owl head; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `alba_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `alba_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `alba_sheet_side.png`, права → `alba_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall slender snowy-owl-kin archer with a round owl head, large golden eyes, a short feathered hood, white and silver plumage with grey speckles, feathered wing-like sleeves, light silver-blue leather armour, a quiver of sapphire-tipped arrows and a square sapphire heart gem on the quiver strap.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems. No turquoise.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The quiver with arrows is fully visible on the back.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall slender owl-kin woman with plausible anatomy, about 7.5 heads tall with a round owl head.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «longbow»* — `alba_prop_longbow.png` → Meshy Image to 3D → `alba_prop_longbow.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same longbow as in the attached reference image (the character's approved card): a tall elegant longbow of white wood and sapphire crystal limbs with silver fittings and a white string.
- COLOR LOCK: the crystal in the limbs is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

VIEW
- The whole object alone, shown once, standing upright, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «longbow»:

```
Tall elegant fantasy longbow of white wood with blue sapphire crystal limbs, silver fittings and a white string. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Tall slender anthropomorphic snowy owl archer woman, round owl head with golden eyes, white and silver plumage with grey speckles, feathered sleeves like wings, short feathered hood, silver-blue leather armour, a quiver with a square blue sapphire on the strap. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток, БЕЗ додаткових кісток: рукави-крила — частина рук. Лук на `hand_l`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | голова повертається на 120° і назад (совиний біт) |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | стрибкий біг, крила напіврозкриті |
| `action` | Archery Shot | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): постріл |
| `special` | Jump Attack / Jump Shot | 1.0–1.4 с | ні | усе тіло: стрибок з розкритими крилами й постріл |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | пір'я злітає сніжком (ефект), вона згортається клубочком |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Крижана стріла / Ice Arrow — `alba_action.png` (колір — стихія Мороз).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Ice Arrow (champion action)
- an arrow with a snowflake-shaped tip flying up on a diagonal toward a small falling wing shape

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C11 `mila` — Міла — Польова алхімічка / Mila — Field Alchemist

ЗАТВЕРДЖЕНИЙ образ (партія 1 №7). Перегенеруйте з цим промтом: реалістичні пропорції замість чібі. Скриня №2 (сценарна) — потрібна рано. Роль: the youngest field medic of the Dawn Order, running into the fight with a lantern that turns pain into light.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Кварц / Quartz | Цілитель | Техно | Орден Світанку | людина, ж. (≈1.60 м) | P3 Cast | clear colourless quartz | round rose-cut, the gold clasp of her apron |

**(a) Картка чемпіона (3:4, до середини стегна)** — `mila_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` + ваша картка з партії 1 (лише як референс образу) · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7 heads tall, a slight young woman about 1.60 m. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes.

CHARACTER - the youngest field medic of the Dawn Order, running into the fight with a lantern that turns pain into light
- Face: bright, brave, kind confident smile, warm hazel eyes, a smudge of soot on one cheek.
- Hair: short wavy chestnut hair with a sage-green ribbon.
- Outfit: cream robes (#EFE6D2) with gold trim, a sage-green apron (#8FB07A) with a gold clasp, rolled sleeves, a big brown leather satchel on the hip with small glass vials of neutral amber liquid.
- Lantern: a brass lantern raised high in her right hand, holding one faceted clear quartz crystal (the healing light is added by the game).
- Heart gem: one faceted round rose-cut dome (a circular stone with softly domed facets) of clear colourless quartz, about 4% of the figure height, set in the gold clasp of her apron, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is clear colourless rock quartz, water-clear with a faint cool silver-grey tint. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.
- Palette: cream #EFE6D2, sage green #8FB07A, gold trim, brown leather, neutral amber vials, chestnut hair.

POSE & COMPOSITION
- Pose P3 Cast: she lifts the brass lantern toward the viewer with her right hand, her left hand on the satchel strap, leaning forward with a reassuring smile.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The lantern is at shoulder height, right of the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a nurse cross, a red cross, glowing lantern light, potion smoke.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `mila_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the slight young field alchemist with short wavy chestnut hair and a sage-green ribbon, cream robes with gold trim, a sage-green apron with a round clear quartz heart gem on its gold clasp and a big brown leather satchel with glass vials on the hip.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The brass lantern is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The satchel hangs at her left hip on a strap across the chest; the robe hangs straight to mid-shin.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult anatomy, about 7 heads tall, a slight young woman about 1.60 m; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `mila_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `mila_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `mila_sheet_side.png`, права → `mila_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the slight young field alchemist with short wavy chestnut hair and a sage-green ribbon, cream robes with gold trim, a sage-green apron with a round clear quartz heart gem on its gold clasp and a big brown leather satchel with glass vials on the hip.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The satchel strap crosses her back diagonally.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7 heads tall, a slight young woman about 1.60 m.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «brass lantern»* — `mila_prop_lantern.png` → Meshy Image to 3D → `mila_prop_lantern.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same brass lantern as in the attached reference image (the character's approved card): a brass field lantern with a ring handle, glass panes and one faceted clear quartz crystal inside.
- COLOR LOCK: the crystal inside is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

VIEW
- The whole object alone, shown once, standing upright, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «brass lantern»:

```
Brass field lantern with a ring handle on top, four glass panes and one faceted clear quartz crystal inside, small gold trims. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Auto (сумка збоку)**.

```
Slight young woman field alchemist, short wavy chestnut hair with a green ribbon, cream robes with gold trim, sage-green apron with a gold clasp holding a round clear quartz, brown leather satchel with glass vials on the hip. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток, БЕЗ додаткових кісток. Ліхтар — окрема жорстка модель на `hand_r` (гойдання — шейдером/кодом).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | перевіряє флакон, ліхтар погойдується |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | поспішний підскок, сумка підскакує |
| `action` | Spell Cast / Wave | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): змах ліхтарем |
| `special` | Kneel / Pick Up | 1.0–1.4 с | ні | усе тіло: стає на коліно й піднімає ліхтар (великий імпульс) |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | ліхтар падає й гасне, вона тягнеться до нього |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Тонік / Tonic — `mila_action.png` (колір — стихія Техно).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Tonic (champion action)
- a small round potion vial tilted as if thrown, a short arc behind it ending in a small targeting reticle

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C12 `ivo` — Іво — Жаровий щит / Ivo — Brazier Shield

НОВИЙ. Хвиля 1 (перший Кварц-чемпіон у скринях). Роль: an earnest young squire who blocks blades with a shield made from a temple brazier.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Кварц / Quartz | Страж | Плазма | Орден Світанку | людина, ч. (≈1.75 м, 17 років) | P5 Bulwark | clear colourless quartz | round rose-cut, his gorget (throat plate) |

**(a) Картка чемпіона (3:4, до середини стегна)** — `ivo_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic anatomy of a lanky 17-year-old, about 7.5 heads tall. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes.

CHARACTER - an earnest young squire who blocks blades with a shield made from a temple brazier
- Face: earnest, over-formal, wide determined eyes, freckles; ginger hair.
- Armour: slightly oversized white-enamel plate with gold rivets, the helmet a little too big, visor up; a crimson-rose (#B42E71) sash.
- Shield: a round brazier-shield whose boss is an open iron grate holding one faceted clear quartz coal-crystal (the fire is added by the game).
- Weapon: a short spear held low.
- Heart gem: one faceted round rose-cut dome (a circular stone with softly domed facets) of clear colourless quartz, about 4% of the figure height, set in his gorget (throat plate), clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is clear colourless rock quartz, water-clear with a faint cool silver-grey tint. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.
- Palette: white enamel, gold rivets, crimson-rose sash #B42E71, iron grey grate, ginger hair.

POSE & COMPOSITION
- Pose P5 Bulwark: braced behind the round shield pushed toward the viewer, the spear low at his side, eyes wide and determined over the rim.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The shield is the largest shape, centre-left of the figure, below the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, fire or embers, a red cross, a heraldic lion.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `ivo_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the lanky ginger, freckled 17-year-old squire in slightly oversized white-enamel plate with gold rivets, a too-big helmet with the visor up, a crimson-rose sash and a small round clear quartz heart gem on the gorget.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The brazier-shield and the short spear are NOT in this image (they are made as separate models).
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The visor is up and the face fully visible; the sash hangs from the right shoulder to the left hip.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic anatomy of a lanky 17-year-old, about 7.5 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `ivo_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `ivo_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `ivo_sheet_side.png`, права → `ivo_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the lanky ginger, freckled 17-year-old squire in slightly oversized white-enamel plate with gold rivets, a too-big helmet with the visor up, a crimson-rose sash and a small round clear quartz heart gem on the gorget.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The sash knot is visible at the back of the left hip.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic anatomy of a lanky 17-year-old, about 7.5 heads tall.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «brazier-shield»* — `ivo_prop_shield.png` → Meshy Image to 3D → `ivo_prop_shield.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same brazier-shield as in the attached reference image (the character's approved card): a round shield of iron and white enamel with gold rivets whose boss is an open iron grate holding one faceted clear quartz coal-crystal.
- COLOR LOCK: the coal-crystal in the grate is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

VIEW
- The whole object alone, shown once, facing the camera, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «brazier-shield»:

```
Round shield of iron and white enamel with gold rivets, the boss is an open iron grate holding one faceted clear quartz crystal like a coal. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

*b3 Проп «short spear»:* НЕ генеруйте — це проста форма, я зроблю її процедурно в рушії.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Auto (перев'язь)**.

```
Lanky teenage squire, ginger hair, freckles, slightly oversized white enamel plate armour with gold rivets, a helmet a bit too big with the visor up, crimson-rose sash, a small round clear quartz on the gorget. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Щит на `hand_l`, спис на `hand_r` (спис зроблю сам).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | перехоплює важкий щит, визирає з-за нього |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | старанний біг, щит підскакує, шолом хитається |
| `action` | Shield Block | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): блок щитом |
| `special` | Shield Block (full body) / Brace | 1.0–1.4 с | ні | усе тіло: впирається ногами й тримає удар |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | щит з дзенькотом падає, він салютує з коліна |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Жар / Brazier Heat — `ivo_action.png` (колір — стихія Плазма).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Brazier Heat (champion action)
- a round shield with an iron grate boss holding a hot coal, three short wavy heat lines rising from it

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C13 `borko` — Борко — Рубака з нори / Borko — Burrow Brawler

НОВИЙ. Хвиля 1. Роль: a badger digger who goes under the enemy's feet and comes up swinging.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Кварц / Quartz | Воїн | Кінетика | Дикі Ікла | звір (борсук), ч. (≈1.50 м) | P6 Prowl | clear colourless quartz | round rose-cut, the round buckle of his harness on the chest |

**(a) Картка чемпіона (3:4, до середини стегна)** — `borko_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a stocky badger-kin with plausible anatomy, about 6 heads tall, broad digger musculature, short strong legs. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (lowest tier): practical, sturdy gear with modest trim; handsome but simple, clearly less ornate than higher-rarity heroes.

CHARACTER - a badger digger who goes under the enemy's feet and comes up swinging
- Head: a natural badger head with a striped black-and-white face, small dark eyes, a gruff grin; brass goggles pushed up on the forehead.
- Fur: grey-black with the white face stripe.
- Outfit: a miner's harness of heartwood-brown leather (#6B4A2E) with pale copper (#D0BBAF) fittings, fingerless gloves, sturdy wrapped feet.
- Weapon: a long spade-axe: a digging spade blade with an axe beard on one side, on a worn wooden haft.
- Heart gem: one faceted round rose-cut dome (a circular stone with softly domed facets) of clear colourless quartz, about 4% of the figure height, set in the round buckle of his harness on the chest, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is clear colourless rock quartz, water-clear with a faint cool silver-grey tint. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.
- Palette: grey-black fur, white stripe, heartwood leather #6B4A2E, pale copper #D0BBAF, brass goggles.

POSE & COMPOSITION
- Pose P6 Prowl: a low crouch toward the viewer, the spade-axe gripped in both hands ready to swing, a confident grin.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The spade blade is in the lower-left third, never in the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a cute mascot, a honey badger meme look, dirt clouds.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `borko_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the stocky badger-kin digger with a striped black-and-white face, grey-black fur, brass goggles pushed up, a heartwood-brown leather miner's harness with copper fittings and a round clear quartz heart gem in the harness buckle.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The spade-axe is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The goggles stay pushed up on the forehead; the harness straps are clearly separated from the arms.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a stocky badger-kin with plausible anatomy, about 6 heads tall, broad digger musculature, short strong legs; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `borko_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `borko_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `borko_sheet_side.png`, права → `borko_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the stocky badger-kin digger with a striped black-and-white face, grey-black fur, brass goggles pushed up, a heartwood-brown leather miner's harness with copper fittings and a round clear quartz heart gem in the harness buckle.
- COLOR LOCK: every crystal and gemstone is clear colourless quartz. No coloured crystals or gems of any kind: no blue, green, violet, pink, gold or amber stones.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The harness straps cross on his back; a short badger tail is visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a stocky badger-kin with plausible anatomy, about 6 heads tall, broad digger musculature, short strong legs.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «spade-axe»* — `borko_prop_spadeaxe.png` → Meshy Image to 3D → `borko_prop_spadeaxe.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same spade-axe as in the attached reference image (the character's approved card): a long spade-axe: a broad digging spade blade with an axe beard on one side, worn wooden haft with copper bands.

VIEW
- The whole object alone, shown once, standing upright, blade up, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «spade-axe»:

```
Long spade-axe weapon: a broad digging spade blade with an axe beard on one side, worn wooden haft with copper bands and a leather grip. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Stocky anthropomorphic badger digger warrior, striped black and white face, grey-black fur, heartwood-brown leather miner's harness with copper fittings, fingerless gloves, brass goggles pushed up on the forehead, a round clear quartz in the harness buckle. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Лопата-сокира на `hand_r`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | спирається на лопату, чухає вухо |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | низький перекатний біг |
| `action` | Axe Swing / Sword Slash | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): рубка в сутичці |
| `special` | Jump Attack | 1.0–1.4 с | ні | усе тіло: пірнає в землю й вистрибує (тіло сховаю під купою землі) |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | осідає в купку землі, видно тільки ніс |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Підкоп / Undermine — `borko_action.png` (колір — стихія Кінетика).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with pale copper (#D9B8A6) and warm bronze as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Undermine (champion action)
- a curved tunnel line running under the ground and erupting upward in a burst of earth chunks

COLOUR
- Main colours: pale copper (#D9B8A6) and warm bronze, ivory white and gold; the darkest shading in deep bronze-brown (#4A3426) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C16 `taya` — Тая — Шепіт рун / Taya — Rune Whisper

НОВА. Хвиля 2. Роль: a star-moth sprite whose rune-dust sends whole squads to sleep mid-charge.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Сапфір / Sapphire | Маг | Руна | Небожителі | створіння (міль-фея), ж. (тіло ≈0.9 м, крила 1.8 м) | P3 Cast | vivid blue sapphire (#3FA9FF) | square Asscher-cut, the front of her fluffy collar |

**(a) Картка чемпіона (3:4, до середини стегна)** — `taya_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a small slender hovering moth-sprite with plausible anatomy, about 5 heads tall, delicate limbs (not chibi). No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (second tier): refined gear with fine trim and a few elegant details.

CHARACTER - a star-moth sprite whose rune-dust sends whole squads to sleep mid-charge
- Head: a smooth oval mask-like face with large soft dark eyes, two feathery antennae, a dreamy shy expression.
- Body: slender, with a fluffy moonsilver (#C9D3E6) collar of soft fur and gold thread embroidery; thin legs tucked under while hovering.
- Wings: two pairs of broad moth wings in dusk-lilac shading to rune indigo (#2E2EB4), patterned with rune-like eye marks.
- Chime: a rune-chime of three small stone tablets hanging on threads from a little bar with one sapphire bead.
- Heart gem: one faceted square Asscher step cut with clipped corners of vivid blue sapphire (#3FA9FF), about 4% of the figure height, set in the front of her fluffy collar, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is vivid royal-to-cornflower blue sapphire (body colour #3FA9FF, deep blue #1F6FD6 in the shadows). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.
- Palette: dusk lilac, rune indigo #2E2EB4, moonsilver #C9D3E6, gold thread, grey stone tablets.

POSE & COMPOSITION
- Pose P3 Cast: hovering, she raises the rune-chime toward the viewer with one hand and makes a gentle dust-scattering gesture with the other; the wings spread wide behind her (no dust in the image).
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. The upper-left wing tip may touch its edge; never the face, hands or chime.
- The eyes are at about 24% of the image height from the top.
- The wings spread mostly to the right and up; the face sits right of the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a giant monster moth, a human fairy with butterfly wings, glitter, glowing dust.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `taya_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the small hovering moth-sprite with a smooth oval mask face, large dark eyes, feathery antennae, a fluffy moonsilver collar with gold thread, two pairs of broad dusk-lilac to rune-indigo moth wings with rune eye marks and a square sapphire heart gem on the collar.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The rune-chime is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- Full body from head to toe including the antennae and wing tips, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- Both pairs of wings are spread wide and flat behind her, symmetric, fully visible.
- She stands on her thin legs (feet visible) for the turnaround.
- Calm expression, the large dark eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a small slender hovering moth-sprite with plausible anatomy, about 5 heads tall, delicate limbs (not chibi); clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `taya_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `taya_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `taya_sheet_side.png`, права → `taya_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the small hovering moth-sprite with a smooth oval mask face, large dark eyes, feathery antennae, a fluffy moonsilver collar with gold thread, two pairs of broad dusk-lilac to rune-indigo moth wings with rune eye marks and a square sapphire heart gem on the collar.
- COLOR LOCK: every crystal and gemstone is vivid blue sapphire (#3FA9FF). No turquoise, teal, cyan-green, violet, pink, clear-white or amber crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The back view shows the full wing pattern; the profile view shows how the wings attach to the upper back.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a small slender hovering moth-sprite with plausible anatomy, about 5 heads tall, delicate limbs (not chibi).
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «rune-chime»:* НЕ генеруйте — це проста форма, я зроблю її процедурно в рушії.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Small slender moth sprite girl standing, smooth oval mask face with large dark eyes, feathery antennae, fluffy moonsilver collar with gold thread, two pairs of broad moth wings spread wide in dusk lilac shading to indigo with rune eye marks, a square blue sapphire on the collar. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Крила я відріжу в Blender і зроблю жорсткими частинами на хребті (махають кодом). Якщо авто-риг Meshy не проходить через крила — надішліть модель без ригу.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | повільно віє крилами, підвіска гойдається |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | ширяння на висоті голови лицаря (підскок кодом); можна Idle/Floating |
| `action` | Spell Cast | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): розсипає пилок |
| `special` | Power Up | 1.0–1.4 с | ні | усе тіло: великий помах крилами |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | крила складаються, вона опускається як листок і тьмяніє |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Пилок снів / Dream Dust — `taya_action.png` (колір — стихія Руна).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Dream Dust (champion action)
- a crescent moon with a closed sleepy eye shape on it and three small dust motes drifting down

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C17 `brant` — Брант — Обсидіановий клинок / Brant — Obsidian Blade

НОВИЙ. Хвиля 2. Роль: a black-glass warrior born from a split geode, whose red-hot blades set every clash on fire.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Аметист / Amethyst | Воїн | Плазма | Кам'яне Серце | створіння (обсидіан), ч. (≈1.90 м) | P2 Advance | deep violet amethyst (#7A35D6) | triangular trillion-cut, the geode cavity in his chest (the amethyst crystals) |

**(a) Картка чемпіона (3:4, до середини стегна)** — `brant_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a lean tall humanoid of volcanic glass with realistic athletic anatomy, about 7.5 heads tall. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth.

CHARACTER - a black-glass warrior born from a split geode, whose red-hot blades set every clash on fire
- Body: black volcanic glass (#15131A) with a violet sheen and sharp glassy planes; a crest of obsidian shards on the head and down the spine.
- Chest: split open like a geode, the cavity lined with amethyst crystals.
- Face: sharp glassy features, narrow eyes, a proud impatient expression.
- Fittings: polished brass wrist bands.
- Weapons: twin obsidian sickle-blades with crimson-rose (#B42E71) tinted edges, like glass just out of the furnace (a colour, not a glow).
- Heart gem: one faceted triangular trillion cut of deep violet amethyst (#7A35D6), about 4% of the figure height, set in the geode cavity in his chest (the amethyst crystals), clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No orange lava, no molten cracks, no fire (that is the enemy's colour).
- Palette: obsidian black #15131A with violet sheen, crimson-rose blade edges #B42E71, brass, violet amethyst.

POSE & COMPOSITION
- Pose P2 Advance: mid-charge toward the viewer, both sickle-blades crossed in front of him, leaning forward, fierce grin.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The crossed blades are centre-left at chest height, outside the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, lava, glowing cracks, fire, a demon look, horns.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `brant_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the lean tall humanoid of black volcanic glass with a violet sheen, a crest of obsidian shards on the head and spine, a chest split open like a geode full of amethyst crystals, sharp glassy features and brass wrist bands.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The sickle-blade is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No orange lava, no molten cracks, no fire (that is the enemy's colour).

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The shard crest runs from the top of the head down the spine; the chest geode is fully visible.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a lean tall humanoid of volcanic glass with realistic athletic anatomy, about 7.5 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `brant_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `brant_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `brant_sheet_side.png`, права → `brant_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the lean tall humanoid of black volcanic glass with a violet sheen, a crest of obsidian shards on the head and spine, a chest split open like a geode full of amethyst crystals, sharp glassy features and brass wrist bands.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No orange lava, no molten cracks, no fire (that is the enemy's colour).

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The spine crest of shards is fully visible from the back and in profile.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a lean tall humanoid of volcanic glass with realistic athletic anatomy, about 7.5 heads tall.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «sickle-blade»* — `brant_prop_blade.png` → Meshy Image to 3D → `brant_prop_blade.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same sickle-blade as in the attached reference image (the character's approved card): one obsidian sickle-blade with a crimson-rose tinted edge and a brass-wrapped grip (he carries two identical ones).

VIEW
- The whole object alone, shown once, laid horizontally, edge down, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «sickle-blade»:

```
Curved obsidian sickle blade of black volcanic glass with a crimson-rose tinted edge and a brass-wrapped grip. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Lean tall humanoid warrior made of black volcanic glass with a violet sheen, a crest of obsidian shards on the head and spine, chest split open like a geode full of violet amethyst crystals, brass wrist bands. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Два однакові клинки — одна модель, двічі (`hand_l`, `hand_r`).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | крутить клинки, нетерпляче тупає |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | агресивний спринт з нахилом уперед |
| `action` | Dual Sword Slash / Sword Slash | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): рубка в сутичці |
| `special` | Jump Attack | 1.0–1.4 с | ні | усе тіло: стрибок з ударом хрестом униз |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | тріскається по шву жеоди, кристали гаснуть, стає на коліно на клинки |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Розжарені клинки / Red-hot Blades — `brant_action.png` (колір — стихія Плазма).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with plasma rose (#D80A71) and hot pink-white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Red-hot Blades (champion action)
- two crossed sickle blades with rose-hot edges forming an X

COLOUR
- Main colours: plasma rose (#D80A71) and hot pink-white, ivory white and gold; the darkest shading in deep wine (#4A0F2C) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C18 `teo` — Тео — Зоряний картограф / Teo — Star Cartographer

НОВИЙ. Хвиля 2. Роль: a young astronomer whose telescope-crossbow and star-probes find what hides.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Аметист / Amethyst | Стрілець | Техно | Небожителі | людина, ч. (≈1.80 м) | P4 Aim | deep violet amethyst (#7A35D6) | triangular trillion-cut, the clasp of his cloak |

**(a) Картка чемпіона (3:4, до середини стегна)** — `teo_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7.5 heads tall, lanky. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth.

CHARACTER - a young astronomer whose telescope-crossbow and star-probes find what hides
- Face: a nerdy, excitable young man with an eager grin, round brass goggles on the eyes, messy dark hair.
- Outfit: a long night-blue (#1B2350) star-chart cloak printed with constellation lines; a moonsilver vest, brass (#B08A3E) buckles, signal-lime (#5ED437) lens rings on the goggles; a notebook in the belt.
- Weapon: a telescope-crossbow: a brass telescope forms the stock and barrel, small crossbow limbs at the front, an amethyst lens.
- Drone: a finned brass probe drone hovering at his shoulder.
- Heart gem: one faceted triangular trillion cut of deep violet amethyst (#7A35D6), about 4% of the figure height, set in the clasp of his cloak, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems.
- Palette: night blue #1B2350 with constellation lines, moonsilver, brass #B08A3E, small signal-lime rings #5ED437, violet amethyst lens.

POSE & COMPOSITION
- Pose P4 Aim: he kneels on one knee and sights through the telescope-crossbow toward the viewer's lower left, the cloak spread on the ground behind him, the probe drone at his right shoulder.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The crossbow points to the lower-left third; the drone floats right of his head.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a sci-fi gun, a wizard hat, glowing constellations.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `teo_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the lanky young astronomer with messy dark hair, round brass goggles with lime lens rings, a long night-blue star-chart cloak printed with constellation lines, a moonsilver vest with brass buckles, a notebook in the belt and a triangular amethyst heart gem on the cloak clasp.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The telescope-crossbow is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The goggles are on his eyes; the cloak hangs straight behind him and does not cover the arms.
- The probe drone is NOT in this image (separate model).
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult anatomy, about 7.5 heads tall, lanky; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `teo_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `teo_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `teo_sheet_side.png`, права → `teo_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the lanky young astronomer with messy dark hair, round brass goggles with lime lens rings, a long night-blue star-chart cloak printed with constellation lines, a moonsilver vest with brass buckles, a notebook in the belt and a triangular amethyst heart gem on the cloak clasp.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The back of the cloak shows the constellation print.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7.5 heads tall, lanky.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «telescope-crossbow»* — `teo_prop_crossbow.png` → Meshy Image to 3D → `teo_prop_crossbow.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same telescope-crossbow as in the attached reference image (the character's approved card): a brass telescope forming the stock and barrel, small crossbow limbs at the front, an amethyst lens at the eyepiece end, leather grip.
- COLOR LOCK: the lens is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems.

VIEW
- The whole object alone, shown once, laid horizontally, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «telescope-crossbow»:

```
Fantasy crossbow built from a brass telescope as the stock and barrel, small crossbow limbs at the front, a violet amethyst lens, leather grip. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

*b3 Проп «probe drone»* — тільки Meshy Text to 3D (листа не треба) → `teo_prop_probe.glb`, ~1 500 трикутників, текстура 256–512².

```
Small finned brass probe drone the size of a fist, rocket-like body, three fins, one lime-green lens ring, rivets. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Lanky young astronomer, round brass goggles with lime lens rings, messy dark hair, long night-blue cloak printed with constellation lines, moonsilver vest with brass buckles, a notebook in the belt, a triangular violet amethyst clasp on the cloak. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Арбалет на `hand_r`; дрон — окрема модель, слідує кодом.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | дивиться в телескоп, щось записує |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | схвильований біг, плащ лопоче |
| `action` | Archery Shot / Crossbow Shot | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): постріл |
| `special` | Throw (upward) | 1.0–1.4 с | ні | усе тіло: запускає зонд угору |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | окуляри тріскаються, мапи розлітаються |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Зоряний зонд / Star Probe — `teo_action.png` (колір — стихія Техно).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with signal lime (#49FF0C) and graphite grey (#3A3F47) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Star Probe (champion action)
- a small finned probe drone with one lens, a targeting reticle beside it

COLOUR
- Main colours: signal lime (#49FF0C) and graphite grey (#3A3F47), ivory white and gold; the darkest shading in graphite (#24282E) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C19 `olena` — Олена — Морозна знахарка / Olena — Frost Herbalist

НОВА. Хвиля 2. Роль: a reindeer herbalist whose antler bells slow a fever and a charge alike.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Аметист / Amethyst | Цілитель | Мороз | Дикі Ікла | звір (північний олень), ж. (≈1.75 м + роги) | P1 Guard | deep violet amethyst (#7A35D6) | triangular trillion-cut, the front of her fur collar |

**(a) Картка чемпіона (3:4, до середини стегна)** — `olena_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a tall reindeer-kin woman with plausible anatomy, about 7.5 heads tall plus wide antlers. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (third tier): rich ornament, engraved details and flowing secondary cloth.

CHARACTER - a reindeer herbalist whose antler bells slow a fever and a charge alike
- Head: a gentle reindeer head with warm dark eyes and a calm motherly smile; wide antlers hung with tiny crystal bells.
- Fur: winter-white and ash-grey; a thick winter fur collar.
- Outfit: a felt robe in deep red-brown (#7A3B2E) with snow-ivory (#F4F8DF) embroidery along the borders, strings of heartwood beads.
- Staff: a bone herb-staff with bundles of frost herbs tied near the top.
- Heart gem: one faceted triangular trillion cut of deep violet amethyst (#7A35D6), about 4% of the figure height, set in the front of her fur collar, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is deep royal violet amethyst (body colour #7A35D6, lighter #B06CFF in the highlights). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue ice crystals; frost is only embroidery and herbs.
- Palette: winter-white and ash-grey fur, red-brown felt #7A3B2E, snow-ivory embroidery #F4F8DF, heartwood beads, violet amethyst bells.

POSE & COMPOSITION
- Pose P1 Guard: she stands tall with the herb-staff planted beside her, the other hand raised gently, a calm smile, the antlers framing her head.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. The left antler tips may touch its edge; never the face, hands or staff.
- The eyes are at about 24% of the image height from the top.
- The staff stands vertically right of her body.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a real deer body, orange cloth, blue ice crystals, Christmas or holiday motifs.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `olena_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the tall reindeer-kin herbalist with wide antlers hung with tiny amethyst bells, winter-white and ash-grey fur, a thick fur collar with a triangular amethyst heart gem, a deep red-brown felt robe with snow-ivory embroidery and heartwood beads.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The herb-staff is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue ice crystals; frost is only embroidery and herbs.

POSE & VIEW
- Full body from head to toe including the full antlers, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The antlers are fully visible and symmetric; every small bell hangs close to the antler (attached).
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall reindeer-kin woman with plausible anatomy, about 7.5 heads tall plus wide antlers; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `olena_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `olena_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `olena_sheet_side.png`, права → `olena_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall reindeer-kin herbalist with wide antlers hung with tiny amethyst bells, winter-white and ash-grey fur, a thick fur collar with a triangular amethyst heart gem, a deep red-brown felt robe with snow-ivory embroidery and heartwood beads.
- COLOR LOCK: every crystal and gemstone is deep violet amethyst (#7A35D6). No blue or sapphire-blue, teal, pink-magenta, clear-white or amber crystals or gems. No blue ice crystals; frost is only embroidery and herbs.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The antlers and the back of the robe with embroidered border are visible.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall reindeer-kin woman with plausible anatomy, about 7.5 heads tall plus wide antlers.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «herb-staff»* — `olena_prop_staff.png` → Meshy Image to 3D → `olena_prop_staff.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same herb-staff as in the attached reference image (the character's approved card): a bone staff with bundles of frost herbs tied near the top with ivory cord.

VIEW
- The whole object alone, shown once, standing upright, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «herb-staff»:

```
Staff of pale bone with bundles of dried frost herbs tied near the top with ivory cord, small heartwood beads. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Tall anthropomorphic reindeer woman herbalist, wide antlers hung with small violet amethyst bells, winter-white and ash-grey fur, thick fur collar, deep red-brown felt robe with ivory embroidery, heartwood beads, a triangular amethyst on the collar. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Дзвіночки — частина рогів (жорсткі). Посох на `hand_r`.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | дзенькає дзвіночком, жує травинку |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | рівний крок, дзвіночки дзеленчать |
| `action` | Spell Cast | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): імпульс лікування |
| `special` | Power Up / Head Shake | 1.0–1.4 с | ні | усе тіло: трясе рогами (великий дзвін) |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | дзвіночки фальшиво дзенькають, вона стає на коліно, роги опущені |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Морозний бальзам / Frost Balm — `olena_action.png` (колір — стихія Мороз).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with snow ivory (#F8FFD8) and frost white as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Frost Balm (champion action)
- a small bell with a six-pointed snowflake hanging below it and a sprig of herbs beside it

COLOUR
- Main colours: snow ivory (#F8FFD8) and frost white, ivory white and gold; the darkest shading in cool slate grey-blue (#46566B) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C20 `nimb` — Німб — Щит бурі / Nimb — Storm Aegis

НОВЕ. Хвиля 3. Роль: a living thunderstorm in a knight's armour; blades and bolts bend toward it and vanish into the cloud.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Топаз / Topaz | Страж | Вольт | Небожителі | створіння (лицар-буря), воно (≈1.95 м) | P5 Bulwark | golden amber topaz (#FFB52E) | five-pointed star-cut, the centre of the aegis shield (the star-cut topaz) |

**(a) Картка чемпіона (3:4, до середини стегна)** — `nimb_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a knight-shaped storm being with plausible humanoid proportions, about 7.5 heads tall. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a living thunderstorm in a knight's armour; blades and bolts bend toward it and vanish into the cloud
- Body: a body of dark storm cloud (#4A4660) with storm-orchid (#EFB5EF) lightning-vein patterns (painted pattern, not glowing).
- Armour: a white-enamel breastplate, pauldrons and a closed helm with gold trim, worn by the cloud; a knee-length cloud skirt from the waist; armoured boots below.
- Halo: a jagged ring shaped like lightning, gold with orchid edges, floating just above the helm.
- Shield: a round aegis shield of white enamel and gold with a star-cut topaz centre.
- Weapon: a short lightning-rod lance with a topaz tip.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the centre of the aegis shield (the star-cut topaz), clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.
- Palette: storm grey-violet #4A4660, storm-orchid veins #EFB5EF, white enamel, gold, golden amber topaz.

POSE & COMPOSITION
- Pose P5 Bulwark: the aegis pushed toward the viewer, the lance held low behind it, the cloud body churning behind the armour, booming and protective.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The aegis is the closest object, centre-left of the figure, below the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a face inside the helm, lightning bolts in the air, glowing veins, a ghost look.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `nimb_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the storm knight: a body of dark grey-violet storm cloud with orchid lightning-vein patterns, a white-enamel breastplate, pauldrons and closed helm with gold trim, a knee-length cloud skirt, armoured boots and a jagged gold lightning-shaped halo above the helm.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The aegis shield and the lightning-rod lance are NOT in this image (they are made as separate models).
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The halo is a solid jagged ring touching the top of the helm (connected, not floating).
- Armoured boots and shins show below the knee-length cloud skirt (the legs exist under the skirt).
- The closed helm faces straight forward (there is no visible face).

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a knight-shaped storm being with plausible humanoid proportions, about 7.5 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating (the halo touches the helm).

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `nimb_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `nimb_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `nimb_sheet_side.png`, права → `nimb_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the storm knight: a body of dark grey-violet storm cloud with orchid lightning-vein patterns, a white-enamel breastplate, pauldrons and closed helm with gold trim, a knee-length cloud skirt, armoured boots and a jagged gold lightning-shaped halo above the helm.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The cloud skirt is visible all round; the halo touches the helm.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a knight-shaped storm being with plausible humanoid proportions, about 7.5 heads tall.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «aegis shield»* — `nimb_prop_aegis.png` → Meshy Image to 3D → `nimb_prop_aegis.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same aegis shield as in the attached reference image (the character's approved card): a round aegis shield of white enamel and gold with a star-cut topaz in the centre and jagged gold rays.
- COLOR LOCK: the centre stone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

VIEW
- The whole object alone, shown once, facing the camera, straight front view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «aegis shield»:

```
Round aegis shield of white enamel and gold with jagged gold lightning rays and one star-shaped amber topaz in the centre. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

*b3 Проп «lightning-rod lance»:* НЕ генеруйте — це проста форма, я зроблю її процедурно в рушії.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Storm knight whose body is a dark grey-violet storm cloud with orchid lightning vein patterns, white enamel breastplate, pauldrons and closed helm with gold trim, a solid jagged gold halo ring touching the helm, knee-length cloud skirt, armoured boots. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток (ноги під спідницею). Ковзання й кипіння хмари — шейдер/код. Щит на `hand_l`, спис зроблю сам.

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | хмара кипить, ореол мерехтить |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | ковзає, броня погойдується (можна Walking) |
| `action` | Shield Block | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): блок |
| `special` | Power Up | 1.0–1.4 с | ні | усе тіло: щит угору, «втягує» блискавку |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | хмара виливається дощем, порожня броня з брязкотом падає |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Громовідвід / Lightning Rod — `nimb_action.png` (колір — стихія Вольт).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Lightning Rod (champion action)
- a short rod lance with three forked lightning bolts bending into its tip

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C21 `dara` — Дара — Небесна гарпунниця / Dara — Sky Harpooner

НОВА. Хвиля 3. Роль: a storm-whaler from the Sky Harbour whose harpoon pulls fliers down.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Топаз / Topaz | Стрілець | Вольт | Орден Світанку | людина, ж. (≈1.75 м, 30+) | P4 Aim | golden amber topaz (#FFB52E) | five-pointed star-cut, the band of her hat |

**(a) Картка чемпіона (3:4, до середини стегна)** — `dara_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: realistic adult anatomy, about 7.5 heads tall, an athletic woman in her thirties. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a storm-whaler from the Sky Harbour whose harpoon pulls fliers down
- Face: bold, sardonic, confident half-smile, sharp eyes; dark hair in a long braid.
- Outfit: a long sky-navy (#24324F) captain's coat with storm-orchid (#EFB5EF) stripes and gold buttons, one white-enamel pauldron, leather gloves, tall boots; a wide-brimmed sky-captain hat with goggles on the band.
- Weapon: a heavy harpoon-gun with a drum of coiled copper chain and a star-cut topaz harpoon tip.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the band of her hat, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.
- Palette: sky navy #24324F, storm-orchid stripes #EFB5EF, white enamel, gold, copper chain, golden amber topaz.

POSE & COMPOSITION
- Pose P4 Aim: braced with feet apart, firing the harpoon-gun toward the viewer's lower left, the chain beginning to uncoil from the drum, the coat flaring.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The harpoon tip points to the lower-left third; the coat flares to the right.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a pirate skull, a tricorn hat, a parrot, a famous pirate look.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `dara_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the athletic sky harpooner in her thirties with a long dark braid, a wide-brimmed sky-captain hat with goggles and a star-cut topaz heart gem on the band, a long sky-navy captain's coat with storm-orchid stripes and gold buttons, one white-enamel pauldron, leather gloves and tall boots.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed. The harpoon-gun is NOT in this image (it is made as a separate model).
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The coat hangs straight to the knees and does not cover the hands; the hat sits level on the head.
- Neutral calm expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; realistic adult anatomy, about 7.5 heads tall, an athletic woman in her thirties; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `dara_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `dara_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `dara_sheet_side.png`, права → `dara_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the athletic sky harpooner in her thirties with a long dark braid, a wide-brimmed sky-captain hat with goggles and a star-cut topaz heart gem on the band, a long sky-navy captain's coat with storm-orchid stripes and gold buttons, one white-enamel pauldron, leather gloves and tall boots.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The braid hangs down the back over the coat.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; realistic adult anatomy, about 7.5 heads tall, an athletic woman in her thirties.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «harpoon-gun»* — `dara_prop_harpoon.png` → Meshy Image to 3D → `dara_prop_harpoon.glb` (~1 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка (+ фронт-лист).

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same harpoon-gun as in the attached reference image (the character's approved card): a heavy harpoon-gun of brass and dark wood with a side drum of coiled copper chain and a star-cut topaz harpoon tip.
- COLOR LOCK: the harpoon tip is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

VIEW
- The whole object alone, shown once, laid horizontally, straight side view with its most readable outline toward the camera, centred, filling about 85% of the image width; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, text, watermark.
```

Запасний Meshy Text to 3D для «harpoon-gun»:

```
Heavy fantasy harpoon gun of brass and dark wood, a side drum of coiled copper chain, a harpoon loaded with a star-shaped amber topaz tip. Stylized hand-painted 3D game prop, premium mobile quality, single object centered, whole object visible, plain light grey background, soft studio lighting, no hands, no glow, no particles, no floating parts, all parts physically connected.
```

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **Auto (один наплічник)**.

```
Athletic woman sky harpooner, dark braided hair, wide-brimmed captain's hat with goggles and a star-shaped topaz on the band, long navy coat with orchid stripes and gold buttons, one white enamel pauldron, leather gloves, tall boots. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid, ≤ 30 кісток. Гарпун на `hand_r` (ланцюг — шейдер/код).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | тримає гарпун на плечі, крутить барабан |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | впевнений матроський біг, поли летять |
| `action` | Shooting / Rifle Shot | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): постріл |
| `special` | Rifle Shot + Pull | 1.0–1.4 с | ні | усе тіло: постріл з віддачею й ривок за ланцюг |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | ланцюг лопається й хльостає назад, вона падає на коліно, тримаючи капелюх |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Гарпун-блискавка / Thunder Harpoon — `dara_action.png` (колір — стихія Вольт).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with storm orchid pink-violet (#FFA5FF) lightning with white cores as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Thunder Harpoon (champion action)
- a harpoon head trailing a zigzag chain that ties two small circles together

COLOUR
- Main colours: storm orchid pink-violet (#FFA5FF) lightning with white cores, ivory white and gold; the darkest shading in deep plum (#4A2148) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

### C22 `menhir` — Менгір — Старійшина рун / Menhir — Rune Elder

НОВЕ. Хвиля 3. Роль: a thousand-year-old standing stone that woke to protect the names carved on it.

| Самоцвіт | Клас | Стихія | Фракція | Вид | Поза | COLOR LOCK (усі кристали) | Камінь-серце |
|---|---|---|---|---|---|---|---|
| Топаз / Topaz | Маг | Руна | Кам'яне Серце | створіння (рунний камінь), воно (≈2.2 м) | P1 Guard | golden amber topaz (#FFB52E) | five-pointed star-cut, the centre of the slab where a chest would be |

**(a) Картка чемпіона (3:4, до середини стегна)** — `menhir_card.png`

Налаштування: формат **3:4** · якість **2K–4K** (мінімум 1536×2048) · 2–4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical champion card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined, slightly anime-influenced face with clean delicate features; soft luminous painterly rendering with crisp clean edges; delicate gold filigree; polished white enamel and gold materials; rich but controlled colour.
- Proportions: a tall narrow standing-stone creature with plausible proportions: a slab body, short thick stone legs and long arms of stacked stones. No chibi or cartoon proportions, no oversized head, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. No coloured magic light. Crystals look like real cut gemstones with sharp facets and reflections, but they do not glow and cast no light.
- Effects: none in the image (no glow, sparks, particles, smoke, magic, light beams or motion trails); the game adds every effect itself.
- Rarity look (fourth tier): lavish gold filigree, layered premium materials, flowing cloth and a very dynamic silhouette.

CHARACTER - a thousand-year-old standing stone that woke to protect the names carved on it
- Body: a tall narrow standing-stone slab of grey-blue granite (#5A6270), weathered, with frost and moss on its top edge.
- Face: one deep-set eye near the top of the slab, calm and ancient (no other features).
- Carvings: deep rune grooves in rune indigo (#2E2EB4) running down the slab, inlaid with topaz.
- Limbs: short thick stone legs; long arms of stacked rounded stones.
- Tablets: three small rune tablets floating in an arc around its head.
- Heart gem: one faceted five-pointed star cut of golden amber topaz (#FFB52E), about 4% of the figure height, set in the centre of the slab where a chest would be, clearly visible from the front.

COLOR LOCK
- Every crystal and gemstone on the character is golden amber imperial topaz (body colour #FFB52E, deeper amber #E07B12 in the shadows). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.
- Palette: grey-blue granite #5A6270, rune indigo grooves #2E2EB4, frost white, moss green, golden amber topaz inlays.

POSE & COMPOSITION
- Pose P1 Guard: standing tall and still, arms lowered, the three rune tablets haloing its head, solemn and protective.
- Camera slightly below chest height looking up about 10 degrees, long lens, little perspective distortion; the body is turned about 30 degrees toward the viewer's left so the gaze leads into the empty upper-left area.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height above it.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's emblem. Only loose tips of hair or cloth may touch its edge; never the face, hands or weapon.
- The eyes are at about 24% of the image height from the top.
- The tablets arc around the top of the slab on the right side, outside the empty upper-left area.

AVOID
Blurry or low resolution, text, letters, numbers, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the weapon, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, sparks, particles, smoke, light rays, lens flare, motion blur, thick outlines, chibi or cartoon proportions, crosses or religious symbols, flags, brand marks, any resemblance to a character from an existing game, film, comic or anime, a human face, a golem with a head, glowing runes, Celtic or real-world religious runes.
```

**(b) Листи для Meshy** (руки порожні; зброя/щит — окремі моделі).

*b1 Фронт* — `menhir_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка цього чемпіона + `style_anchor.png`. Перевірте: ступні видно, руки порожні, обличчя й кольори як на картці.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the walking standing stone: a tall narrow grey-blue granite slab with frost and moss on its top edge, one deep-set eye near the top, deep rune-indigo grooves inlaid with topaz, short thick stone legs, long arms of stacked stones and a star-cut topaz heart gem in the centre.
- Same face, costume, colours, materials and heart gem as the reference; nothing added, nothing removed.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The three rune tablets are NOT in this image (separate models).
- The long stone arms hang in the A-pose; the stone hands are open.
- The single deep-set eye looks straight forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall narrow standing-stone creature with plausible proportions: a slab body, short thick stone legs and long arms of stacked stones; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing effects, floating parts, cape or hair covering the arms, extra fingers, background objects, text, watermark.
```

*b2 Бік + спина* — `menhir_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: `menhir_sheet_front.png` + картка. Потім розріжте навпіл (будь-який редактор, «Обрізати»): ліва половина → `menhir_sheet_side.png`, права → `menhir_sheet_back.png`.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the walking standing stone: a tall narrow grey-blue granite slab with frost and moss on its top edge, one deep-set eye near the top, deep rune-indigo grooves inlaid with topaz, short thick stone legs, long arms of stacked stones and a star-cut topaz heart gem in the centre.
- COLOR LOCK: every crystal and gemstone is golden amber topaz (#FFB52E). No teal, cyan, green, blue, violet, clear-white or rainbow crystals or gems.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty.
- The back of the slab shows weathered stone and moss; the runes are only on the front.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall narrow standing-stone creature with plausible proportions: a slab body, short thick stone legs and long arms of stacked stones.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons, cropped feet, perspective distortion, dramatic light, glow, text, watermark.
```

*b3 Проп «rune tablet»:* НЕ генеруйте — це проста форма, я зроблю її процедурно в рушії.

**(c) Meshy — текстовий промт (запасний; основний шлях — Multi-image to 3D з листів b1 + b2).** Remesh: **8 000 трикутників** (Triangle) · текстура в грі 512² (чемпіон) — завантажуйте як дає Meshy, я зменшу · Symmetry: **On**.

```
Walking standing-stone elder, tall narrow grey-blue granite slab body with carved rune grooves inlaid with amber topaz, short thick stone legs, long arms of stacked stones, one deep-set eye near the top, frost and moss on the top edge, a star-shaped topaz in the chest. Stylized hand-painted 3D game character, realistic adult proportions, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, no glow, no particles, no floating parts, all parts physically connected.
```

**(d) Риг і кліпи.** Humanoid (тулуб-плита, 3 кістки хребта), ≤ 30 кісток. Таблички — окремі прості моделі на процедурній орбіті (зроблю сам).

| Кліп (назва для Godot) | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle | 2.0 с | так | таблички кружляють, низьке гудіння |
| `run` | Running / Run Forward | цикл 0.6–0.7 с | так | важкий хиткий крок з боку на бік |
| `action` | Spell Cast | 0.6–0.8 с | ні | верхня частина тіла (я відфільтрую на хребет/руки): рунний удар рукою |
| `special` | Ground Slam | 1.0–1.4 с | ні | усе тіло: долонею об дорогу (креслить коло) |
| `hit` | Hit Reaction | 0.4 с | ні | короткий відсахнувся |
| `fall` | Dying / Knocked Down | 1.2–1.6 с | ні | падає вперед, як зрубане дерево, руни гаснуть одна за одною |
| `victory` | Cheering / Victory | 2.0 с | ні | радість після перемоги |
| `flourish` | Showing Off | 1.5 с | ні | реакція на дотик у «Деталях» |

Після `fall` чемпіон лежить (останній кадр тримаю); підйом при воскресінні — 0.4 с, зроблю з `fall` у зворотному порядку.

**(e) Іконка дії** — Рунне коло / Rune Circle — `menhir_action.png` (колір — стихія Руна).

Налаштування: формат **1:1** · якість **1K–2K** (≥ 1024×1024) · 2–3 варіанти · референси: `style_anchor.png` + картка · робіть усі іконки персонажа в одному чаті, щоб вони вийшли однією серією.

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with rune indigo (#2E2EB4) with ivory carved lines as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Rune Circle (champion action)
- a ring of carved runes lying flat on the ground in perspective, a stone palm print in its centre

COLOUR
- Main colours: rune indigo (#2E2EB4) with ivory carved lines, ivory white and gold; the darkest shading in ink navy (#141448) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

---

## 5. Емблеми, значки, валюти, Портал, скрині, Майстерня, фони, спорядження, реліквії

### 5.1 Емблеми самоцвітів — НЕ генеруємо

П'ять емблем (Кварц · Сапфір · Аметист · Топаз · Опал) і 10 «дублетів» (огранених) малюються в рушії як справжні 3D-камені (`GemCutMesh` + `gem_facet.gdshader`: огранка-силует, оправа, кольоровий «вогонь», анімація; спрайти 128² рендеряться при першому запуску). Генерувати картинки не треба: вони мусять оновлюватися при «Огранці» й бути ідеально однаковими. Опційно (крок 8) можна дати шейдеру мальовані текстури «нутра» каменя — промти нижче (1024² → я зменшу до 256²).

*Кварц* — `gemtex_quartz.png` · Налаштування: 1:1 · 1K · без референсів.

```
Create ONE seamless tileable square texture for a gemstone shader.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- GREYSCALE ONLY, no colour. Seamless: the left and right edges, and the top and bottom edges, continue into each other.
- No text, no objects, no frame, no watermark.

CONTENT
- The interior of a cut gemstone, seen as a flat texture: a faint smoky phantom: a ghostly inner crystal outline and soft cloudy veils, mostly light-mid grey with gentle bright caustic lines.
- Even density over the whole square, no centre focus, no vignette.

AVOID
Colour, a whole gem shape, facet outlines, objects, hard seams, text, watermark.
```

*Сапфір* — `gemtex_sapphire.png` · Налаштування: 1:1 · 1K · без референсів.

```
Create ONE seamless tileable square texture for a gemstone shader.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- GREYSCALE ONLY, no colour. Seamless: the left and right edges, and the top and bottom edges, continue into each other.
- No text, no objects, no frame, no watermark.

CONTENT
- The interior of a cut gemstone, seen as a flat texture: fine silk: thin parallel needle-like lines crossing at 60 degrees, with soft bright caustic patches.
- Even density over the whole square, no centre focus, no vignette.

AVOID
Colour, a whole gem shape, facet outlines, objects, hard seams, text, watermark.
```

*Аметист* — `gemtex_amethyst.png` · Налаштування: 1:1 · 1K · без референсів.

```
Create ONE seamless tileable square texture for a gemstone shader.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- GREYSCALE ONLY, no colour. Seamless: the left and right edges, and the top and bottom edges, continue into each other.
- No text, no objects, no frame, no watermark.

CONTENT
- The interior of a cut gemstone, seen as a flat texture: colour zoning: two broad darker bands crossing diagonally, with soft caustic light patterns between them.
- Even density over the whole square, no centre focus, no vignette.

AVOID
Colour, a whole gem shape, facet outlines, objects, hard seams, text, watermark.
```

*Топаз* — `gemtex_topaz.png` · Налаштування: 1:1 · 1K · без референсів.

```
Create ONE seamless tileable square texture for a gemstone shader.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- GREYSCALE ONLY, no colour. Seamless: the left and right edges, and the top and bottom edges, continue into each other.
- No text, no objects, no frame, no watermark.

CONTENT
- The interior of a cut gemstone, seen as a flat texture: warm inner fire: soft flame-like veils and bright caustic streaks.
- Even density over the whole square, no centre focus, no vignette.

AVOID
Colour, a whole gem shape, facet outlines, objects, hard seams, text, watermark.
```

*Опал* — `gemtex_opal.png` · Налаштування: 1:1 · 1K · без референсів.

```
Create ONE seamless tileable square texture for a gemstone shader.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- GREYSCALE ONLY, no colour. Seamless: the left and right edges, and the top and bottom edges, continue into each other.
- No text, no objects, no frame, no watermark.

CONTENT
- The interior of a cut gemstone, seen as a flat texture: a play-of-colour mask: a patchwork of irregular rounded flecks in many different grey values with crisp edges between them.
- Even density over the whole square, no centre focus, no vignette.

AVOID
Colour, a whole gem shape, facet outlines, objects, hard seams, text, watermark.
```

### 5.2 Значки класів, стихій і гербів фракцій

- **Стихії (6):** НЕ генеруємо — це заморожений набір векторних гліфів арсеналу (шеврон, блискавка, сніжинка, куля, приціл, руна), уже намальований у `icons.gd`.
- **Класи (5):** за вашим рішенням (раунд 3) це чисті лінійні значки в тонкому кільці; я малюю їх вектором у `icons.gd`. Промти нижче дають ЕСКІЗ для обведення (темне чорнило на сірому). Налаштування: 1:1 · 1K · референс не потрібен.

*Воїн / Warrior* — `class_warrior_ref.png`

```
Create ONE square line-icon design reference for a game interface (it will be redrawn as a vector).

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no watermark.

STYLE
- A clean, elegant monoline glyph in ONE dark ink colour (#1E2433), uniform stroke about 5% of the canvas, crisp geometric curves, small flat fills only where needed.
- The glyph sits inside a thin circular ring of the same ink (stroke about 2% of the canvas).

MOTIF
- two crossed blades, simple, iconic, symmetric where possible.

COMPOSITION
- Ring centred at 84% of the canvas width; the glyph inside it at about 60%; readable at 24 px.

AVOID
Shading, gradients, colour, painterly texture, 3D, text, sparkles, thin hairline details, watermark.
```

*Стрілець / Ranger* — `class_ranger_ref.png`

```
Create ONE square line-icon design reference for a game interface (it will be redrawn as a vector).

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no watermark.

STYLE
- A clean, elegant monoline glyph in ONE dark ink colour (#1E2433), uniform stroke about 5% of the canvas, crisp geometric curves, small flat fills only where needed.
- The glyph sits inside a thin circular ring of the same ink (stroke about 2% of the canvas).

MOTIF
- a drawn bow with one arrow, simple, iconic, symmetric where possible.

COMPOSITION
- Ring centred at 84% of the canvas width; the glyph inside it at about 60%; readable at 24 px.

AVOID
Shading, gradients, colour, painterly texture, 3D, text, sparkles, thin hairline details, watermark.
```

*Маг / Mage* — `class_mage_ref.png`

```
Create ONE square line-icon design reference for a game interface (it will be redrawn as a vector).

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no watermark.

STYLE
- A clean, elegant monoline glyph in ONE dark ink colour (#1E2433), uniform stroke about 5% of the canvas, crisp geometric curves, small flat fills only where needed.
- The glyph sits inside a thin circular ring of the same ink (stroke about 2% of the canvas).

MOTIF
- a small orb inside a slim ring, simple, iconic, symmetric where possible.

COMPOSITION
- Ring centred at 84% of the canvas width; the glyph inside it at about 60%; readable at 24 px.

AVOID
Shading, gradients, colour, painterly texture, 3D, text, sparkles, thin hairline details, watermark.
```

*Страж / Guardian* — `class_guardian_ref.png`

```
Create ONE square line-icon design reference for a game interface (it will be redrawn as a vector).

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no watermark.

STYLE
- A clean, elegant monoline glyph in ONE dark ink colour (#1E2433), uniform stroke about 5% of the canvas, crisp geometric curves, small flat fills only where needed.
- The glyph sits inside a thin circular ring of the same ink (stroke about 2% of the canvas).

MOTIF
- a tall tower shield, simple, iconic, symmetric where possible.

COMPOSITION
- Ring centred at 84% of the canvas width; the glyph inside it at about 60%; readable at 24 px.

AVOID
Shading, gradients, colour, painterly texture, 3D, text, sparkles, thin hairline details, watermark.
```

*Цілитель / Healer* — `class_healer_ref.png`

```
Create ONE square line-icon design reference for a game interface (it will be redrawn as a vector).

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no watermark.

STYLE
- A clean, elegant monoline glyph in ONE dark ink colour (#1E2433), uniform stroke about 5% of the canvas, crisp geometric curves, small flat fills only where needed.
- The glyph sits inside a thin circular ring of the same ink (stroke about 2% of the canvas).

MOTIF
- a small hanging lantern, simple, iconic, symmetric where possible.

COMPOSITION
- Ring centred at 84% of the canvas width; the glyph inside it at about 60%; readable at 24 px.

AVOID
Shading, gradients, colour, painterly texture, 3D, text, sparkles, thin hairline details, watermark.
```

- **Герби фракцій (4):** мальовані медальйони (біла емаль + золото, восьмикутник зі зрізаними кутами — наш «фасетний» підпис, не кругла пігулка). Показуються 48–96 px. Налаштування: 1:1 · 1K–2K · референс: `style_anchor.png`.

*Орден Світанку / Dawn Order* — `faction_dawn.png`

```
Create ONE square faction crest icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no ribbon, no logo, no watermark.

ART STYLE
- Painted game-badge style matching the attached style reference image: a medallion of white enamel and polished gold shaped as an octagon with 45-degree cut corners (a faceted plate), a thin gold rim, the motif raised in relief in the centre; soft painterly shading, crisp clean edges; reads at 48 px.

MOTIF
- a half sun with five rays rising over a gentle bridge arch, in navy (#24324F) and gold on the white enamel.

COMPOSITION
- The medallion centred, about 80% of the canvas width; at least 10% empty margin on every side; the motif has at most two shapes.

AVOID
Text, letters, a ribbon or scroll, real-world heraldry, crosses, lions, eagles, flags, four-pointed sparkle stars, glow, round pill shapes, photorealism, watermark.
```

*Дикі Ікла / Wildfang* — `faction_wildfang.png`

```
Create ONE square faction crest icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no ribbon, no logo, no watermark.

ART STYLE
- Painted game-badge style matching the attached style reference image: a medallion of white enamel and polished gold shaped as an octagon with 45-degree cut corners (a faceted plate), a thin gold rim, the motif raised in relief in the centre; soft painterly shading, crisp clean edges; reads at 48 px.

MOTIF
- a curved fang crossed with a long feather, in heartwood brown (#6B4A2E) and bone white on the white enamel.

COMPOSITION
- The medallion centred, about 80% of the canvas width; at least 10% empty margin on every side; the motif has at most two shapes.

AVOID
Text, letters, a ribbon or scroll, real-world heraldry, crosses, lions, eagles, flags, four-pointed sparkle stars, glow, round pill shapes, photorealism, watermark.
```

*Кам'яне Серце / Stoneheart* — `faction_stoneheart.png`

```
Create ONE square faction crest icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no ribbon, no logo, no watermark.

ART STYLE
- Painted game-badge style matching the attached style reference image: a medallion of white enamel and polished gold shaped as an octagon with 45-degree cut corners (a faceted plate), a thin gold rim, the motif raised in relief in the centre; soft painterly shading, crisp clean edges; reads at 48 px.

MOTIF
- a faceted heart-shaped stone wrapped by a brass band, in basalt (#2E2B2B) and brass (#B08A3E) on the white enamel.

COMPOSITION
- The medallion centred, about 80% of the canvas width; at least 10% empty margin on every side; the motif has at most two shapes.

AVOID
Text, letters, a ribbon or scroll, real-world heraldry, crosses, lions, eagles, flags, four-pointed sparkle stars, glow, round pill shapes, photorealism, watermark.
```

*Небожителі / Celestials* — `faction_celestial.png`

```
Create ONE square faction crest icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No text, no letters, no ribbon, no logo, no watermark.

ART STYLE
- Painted game-badge style matching the attached style reference image: a medallion of white enamel and polished gold shaped as an octagon with 45-degree cut corners (a faceted plate), a thin gold rim, the motif raised in relief in the centre; soft painterly shading, crisp clean edges; reads at 48 px.

MOTIF
- a crescent moon inside a tilted orbit ring with one small planet, in night blue (#1B2350) and moonsilver on the white enamel.

COMPOSITION
- The medallion centred, about 80% of the canvas width; at least 10% empty margin on every side; the motif has at most two shapes.

AVOID
Text, letters, a ribbon or scroll, real-world heraldry, crosses, lions, eagles, flags, four-pointed sparkle stars, glow, round pill shapes, photorealism, watermark.
```

### 5.3 Аури класів (5) — іконки аури чемпіона

Колір — тільки слонова кістка й біле золото (`#FFE7A3`, колір маркерів забігу), бо аура — від класу, а не від стихії. Налаштування: 1:1 · 1K–2K · референс: `style_anchor.png` · усі п'ять в одному чаті.

*Аура: Воїн / Warrior* — `aura_warrior.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with warm white-gold (#FFE7A3) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Warrior Aura (squad aura)
- two crossed blades above a tight row of three small soldier helmets (read as one group shape)

COLOUR
- Main colours: warm white-gold (#FFE7A3), ivory white and gold; the darkest shading in warm umber (#4A3A22) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Аура: Страж / Guardian* — `aura_guardian.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with warm white-gold (#FFE7A3) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Guardian Aura (squad aura)
- a tall tower shield standing in front of a tight row of three small soldier helmets (read as one group shape)

COLOUR
- Main colours: warm white-gold (#FFE7A3), ivory white and gold; the darkest shading in warm umber (#4A3A22) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Аура: Стрілець / Ranger* — `aura_ranger.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with warm white-gold (#FFE7A3) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Ranger Aura (squad aura)
- three arrows rising in a fan above a tight row of three small soldier helmets (read as one group shape)

COLOUR
- Main colours: warm white-gold (#FFE7A3), ivory white and gold; the darkest shading in warm umber (#4A3A22) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Аура: Маг / Mage* — `aura_mage.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with warm white-gold (#FFE7A3) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Mage Aura (squad aura)
- a ring of simple carved runes circling above a tight row of three small soldier helmets (read as one group shape)

COLOUR
- Main colours: warm white-gold (#FFE7A3), ivory white and gold; the darkest shading in warm umber (#4A3A22) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

*Аура: Цілитель / Healer* — `aura_healer.png`

```
Create ONE square skill icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no ring, no plate, no badge shape, no vignette (the game adds the frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-icon style matching the attached style reference image: one bold, simple, emblem-like motif with soft painterly shading and crisp clean edges; it reads as a clear solid silhouette at 64 px and stays crisp at 96 px.
- Materials: carved ivory-white porcelain highlights and thin polished gold edges, with warm white-gold (#FFE7A3) as the main colour.
- Soft key light from the upper left. No glow halo, no sparks, no particles, no light rays.

MOTIF - Healer Aura (squad aura)
- a small lantern hanging above a tight row of three small soldier helmets (read as one group shape)

COLOUR
- Main colours: warm white-gold (#FFE7A3), ivory white and gold; the darkest shading in warm umber (#4A3A22) so the motif separates clearly from the grey background.
- No gemstone colours: no blue sapphire, violet amethyst, amber topaz or rainbow opal crystals anywhere (the game frame shows the rarity).

COMPOSITION
- The motif is centred and fits inside a central circle of 76% of the canvas width, with at least 12% empty margin on every side; nothing touches the edges.
- At most three main shapes; no detail smaller than 3% of the canvas.

AVOID
Text, letters, numbers, frame, border, ring, badge plate, background scene, faces, tiny details, photorealism, glow halo, emoji or clip-art look, thick black outlines, gradient background, watermark.
```

### 5.4 Валюти героїв (4)

Налаштування: 1:1 · 1K–2K · референс: `style_anchor.png` · усі чотири в одному чаті. Іконка валюти не має бути схожа на емблему рідкості (огранений камінь в оправі) — тому тут предмети, а не камені.

*Маяк / Beacon* — `cur_beacons.png` (the only Portal currency; must not look like a rarity gem emblem)

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Beacon
- a tiny white-enamel and gold lighthouse tower topped with a faceted clear crystal lantern
- Material language: white enamel and polished gold, premium and simple.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Печатка / Seal* — `cur_seals.png` (gold metal, NOT red wax (the red-wax look is reserved for the NEW stamp))

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Seal
- a round polished gold signet disc with a faceted gem shape raised in relief in its centre and a short ivory ribbon tail
- Material language: white enamel and polished gold, premium and simple.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Том / Tome* — `cur_tomes.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Tome
- a thick small book with white enamel covers, gold corner guards, a gold clasp and an engraved facet pattern on the cover
- Material language: white enamel and polished gold, premium and simple.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Зоряна руда / Star Ore* — `cur_ore.png` (a raw material, not a cut gem)

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Star Ore
- a rough chunk of dark blue-grey ore with tiny six-pointed silver-gold star crystals growing out of it
- Material language: white enamel and polished gold, premium and simple.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

### 5.5 Портал, Скриня героїв, Велика скриня, Майстерня (3D)

Шлях: концепт-картинка (Gemini, 1:1) → Meshy **Image to 3D** з неї (точніше, ніж текст) → якщо не вийшло, Meshy **Text to 3D** з запасного промту. Remesh — як у таблиці §1.7. Без ригу.

*Портал призову / Summoning Portal* — `portal_concept.png` → `portal.glb` · 18 000 трикутників · текстура 1024² · кільце, поміст і стовпи — однією моделлю; кристали в гніздах я підсвічую в рушії.
Навіщо: екран «Портал» (H3): 3D-кільце в центрі; вихор усередині роблю шейдером у кольорі того, хто випадає.

Налаштування концепту: 1:1 · 2K · референс: `style_anchor.png`.

```
Create ONE 3D game asset concept image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no ground shadow, no scenery. No text, no logo, no watermark, no frame.

ART STYLE
- The same painterly game-art style as the attached style reference image, shown as a clean stylized 3D game asset: hand-painted materials, crisp edges, white enamel and polished gold with thin trim, rich but controlled colour.

OBJECT
- A grand summoning portal: a tall upright circular ring gate of white marble with ornate polished gold filigree, about twice the height of a person.
- Five large gem sockets set evenly around the ring, each holding a different cut stone: a round rose-cut clear quartz, a square Asscher-cut blue sapphire, a triangular trillion-cut violet amethyst, a five-pointed star-cut golden amber topaz and a marquise opal cabochon with rainbow flecks.
- The ring stands on a round three-step white marble dais engraved with fine facet lines (no letters, no religious symbols); two slim faceted clear crystal pillars flank it.
- The inside of the ring is open and completely empty.

VIEW
- The whole object visible, alone, centred, filling about 85% of the image; straight front view, camera at the height of the ring centre; no perspective distortion.
- Soft even studio lighting. No glow, no magic effects, no particles, no light inside openings. Every part physically connected; nothing floating.

AVOID
Characters, hands, text, letters, background scene, floor, cast shadow, glow, energy, particles, floating parts, photorealism, watermark.
```

Запасний Meshy Text to 3D:

```
Summoning portal: tall upright white marble ring gate with gold filigree, five gem sockets with a clear quartz, blue sapphire, violet amethyst, amber topaz and an opal, on a round three-step marble dais, two slim clear crystal pillars, the ring open and empty inside. Stylized hand-painted 3D game asset, premium mobile game quality, white enamel with thin gold trim, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no ground, no glow, no particles, no floating parts, all parts physically connected.
```

*Скриня героїв / Hero Chest* — `hero_chest_concept.png` → `hero_chest.glb` · 6 000 трикутників · текстура 512² · одна модель; кришку я відріжу по щілині (шарнір ззаду).
Навіщо: результат забігу і «Сховище» (L14): відкривається інлайн 1.6 с. Якщо ви вже зробили скриню за промтом партії 1 і вона подобається — не перегенеровуйте, лише перевірте, що між кришкою й корпусом є чітка рівна щілина.

Налаштування концепту: 1:1 · 2K · референс: `style_anchor.png`.

```
Create ONE 3D game asset concept image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no ground shadow, no scenery. No text, no logo, no watermark, no frame.

ART STYLE
- The same painterly game-art style as the attached style reference image, shown as a clean stylized 3D game asset: hand-painted materials, crisp edges, white enamel and polished gold with thin trim, rich but controlled colour.

OBJECT
- An ornate fantasy reliquary chest, compact and heavy: dark navy lacquered wood with white enamel panels, polished gold filigree corners and bands.
- A domed lid crowned with one large faceted clear crystal in a gold setting (the game tints it by tier).
- A gold crest lock on the front shaped like a faceted shield with two small wings (no real-world heraldry); small clear crystal studs along the edges.
- Closed, with a clean straight horizontal seam between the lid and the body all the way round (the lid will be opened in the game).

VIEW
- The whole object visible, alone, centred, filling about 85% of the image; three-quarter front view from slightly above; no perspective distortion.
- Soft even studio lighting. No glow, no magic effects, no particles, no light inside openings. Every part physically connected; nothing floating.

AVOID
Characters, hands, text, letters, background scene, floor, cast shadow, glow, energy, particles, floating parts, photorealism, watermark.
```

Запасний Meshy Text to 3D:

```
Ornate fantasy reliquary chest, compact and heavy, dark navy lacquered wood with white enamel panels, gold filigree corners and bands, domed lid crowned with one large faceted clear crystal, gold shield-shaped crest lock with two small wings, clear crystal studs, closed. Stylized hand-painted 3D game asset, premium mobile game quality, white enamel with thin gold trim, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no ground, no glow, no particles, no floating parts, all parts physically connected.
```

*Велика скриня героїв / Grand Hero Chest* — `grand_hero_chest_concept.png` → `grand_hero_chest.glb` · 8 000 трикутників · текстура 1024² · одна модель; кришку відріжу по щілині.
Навіщо: перше проходження світового боса, тиждень 5/5, Експедиція 5/5 (гарантовано Аметист+). Хвиля 3.

Налаштування концепту: 1:1 · 2K · референс: `style_anchor.png`.

```
Create ONE 3D game asset concept image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no ground shadow, no scenery. No text, no logo, no watermark, no frame.

ART STYLE
- The same painterly game-art style as the attached style reference image, shown as a clean stylized 3D game asset: hand-painted materials, crisp edges, white enamel and polished gold with thin trim, rich but controlled colour.

OBJECT
- A grand reliquary chest, larger and far more ornate than a normal chest: white enamel body with polished gold filigree, standing on four gold claw feet shaped like gem prongs.
- A tall domed lid with five faceted clear crystals in gold prong settings in a row along its crest (the game tints them by tier); two gold ring handles on the sides.
- A large gold crest lock on the front shaped like a faceted shield with spread wings (no real-world heraldry).
- Closed, with a clean straight horizontal seam between the lid and the body all the way round.

VIEW
- The whole object visible, alone, centred, filling about 85% of the image; three-quarter front view from slightly above; no perspective distortion.
- Soft even studio lighting. No glow, no magic effects, no particles, no light inside openings. Every part physically connected; nothing floating.

AVOID
Characters, hands, text, letters, background scene, floor, cast shadow, glow, energy, particles, floating parts, photorealism, watermark.
```

Запасний Meshy Text to 3D:

```
Grand ornate reliquary chest, white enamel body with gold filigree on four gold claw feet like gem prongs, tall domed lid with five faceted clear crystals in gold prong settings in a row, gold ring handles, large gold winged shield crest lock, closed. Stylized hand-painted 3D game asset, premium mobile game quality, white enamel with thin gold trim, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no ground, no glow, no particles, no floating parts, all parts physically connected.
```

*Майстерня (станок) / Workshop station* — `workshop_concept.png` → `workshop.glb` · 12 000 трикутників · текстура 1024² · одна модель; іскри й жар роблю ефектами.
Навіщо: шапка екрана «Майстерня» (L32, фаза H4). Вогонь у горні — тільки ефектом (помаранчева лава — колір ворога).

Налаштування концепту: 1:1 · 2K · референс: `style_anchor.png`.

```
Create ONE 3D game asset concept image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no ground shadow, no scenery. No text, no logo, no watermark, no frame.

ART STYLE
- The same painterly game-art style as the attached style reference image, shown as a clean stylized 3D game asset: hand-painted materials, crisp edges, white enamel and polished gold with thin trim, rich but controlled colour.

OBJECT
- A compact jeweller-smith's workshop station on one round white marble platform with a thin gold rim.
- A heavy anvil of dark steel on a white marble block in the centre; beside it a lapidary gem-cutting wheel on a brass stand with a foot treadle.
- A small crucible furnace of basalt and brass with an EMPTY hearth (no fire); a rack with tongs, a hammer and a chisel; a small tray of rough dark ore chunks with tiny silver star specks.
- Clean, readable, premium; white enamel and gold accents on the furniture.

VIEW
- The whole object visible, alone, centred, filling about 85% of the image; three-quarter front view from slightly above; no perspective distortion.
- Soft even studio lighting. No glow, no magic effects, no particles, no light inside openings. Every part physically connected; nothing floating.

AVOID
Characters, hands, text, letters, background scene, floor, cast shadow, glow, energy, particles, floating parts, photorealism, watermark.
```

Запасний Meshy Text to 3D:

```
Compact jeweller-smith workshop station on a round white marble platform with gold rim: dark steel anvil on a marble block, a brass lapidary gem-cutting wheel, a small basalt and brass furnace with an empty hearth, a tool rack with tongs and hammer, a tray of rough ore. Stylized hand-painted 3D game asset, premium mobile game quality, white enamel with thin gold trim, single object centered, three-quarter front view, whole object visible, plain light grey background, soft studio lighting, no text, no ground, no glow, no particles, no floating parts, all parts physically connected.
```

### 5.6 Фонові картини фракцій (4) — фон «Вітрини героя»

Фон малюється ОКРЕМО від персонажа й СІРИМ: шейдер гри перефарбовує його в градієнт самоцвіту (блакитна заливка для Сапфіра, золота для Топаза тощо — як у ваших референсах), тому один фон служить усім героям фракції і всім самоцвітам. Налаштування: 9:21 (Midjourney `--ar 9:21`) або 9:16 4K · референс: `style_anchor.png` · 2–4 варіанти.

*Орден Світанку / Dawn Order* — `bg_dawn.png`

```
Create ONE vertical background painting for a premium fantasy mobile game hero screen.

FORMAT
- Aspect ratio 9:21 (tall portrait), 1440x3360 px. If the tool has no 9:21, use 9:16 at 2160x3840 and keep every important shape inside the central 76% of the width (the sides will be cropped).
- GREYSCALE ONLY: a value painting in neutral greys with no colour at all (the game recolours it in the rarity colour).
- No characters, no creatures, no text, no letters, no logo, no frame, no watermark.

ART STYLE
- The same painterly fantasy style as the attached style reference image: large simple shapes, soft depth haze, painterly brushwork, low detail, calm and luminous.

SCENE
- a sunlit white-marble temple terrace high above the clouds: slender colonnades, a long stone bridge leading away, distant sky-harbour cranes and moored airship silhouettes, soft layered clouds.

VALUES & COMPOSITION
- Mid-to-light values overall, no pure black areas; strong atmospheric depth: near shapes darker, far shapes lighter.
- The brightest soft glow is right of centre, at about 62% of the width and 25-35% of the height (a hero's head will be there).
- The upper-left area (left 40%, top 40%) is calm and low-contrast (the name sits there); the lower 30% is darker and calmer (interface sits there).
- A low horizon at about 70% of the image height.

AVOID
Colour, characters, creatures, text, busy detail, high-contrast patterns, hard black shadows, a frame, a photo look, lens flare, watermark.
```

*Дикі Ікла / Wildfang* — `bg_wildfang.png`

```
Create ONE vertical background painting for a premium fantasy mobile game hero screen.

FORMAT
- Aspect ratio 9:21 (tall portrait), 1440x3360 px. If the tool has no 9:21, use 9:16 at 2160x3840 and keep every important shape inside the central 76% of the width (the sides will be cropped).
- GREYSCALE ONLY: a value painting in neutral greys with no colour at all (the game recolours it in the rarity colour).
- No characters, no creatures, no text, no letters, no logo, no frame, no watermark.

ART STYLE
- The same painterly fantasy style as the attached style reference image: large simple shapes, soft depth haze, painterly brushwork, low detail, calm and luminous.

SCENE
- an ancient rune forest grove: giant twisted trees, hanging moss, huge fern fronds, roots carved with simple patterns, soft light shafts through the canopy.

VALUES & COMPOSITION
- Mid-to-light values overall, no pure black areas; strong atmospheric depth: near shapes darker, far shapes lighter.
- The brightest soft glow is right of centre, at about 62% of the width and 25-35% of the height (a hero's head will be there).
- The upper-left area (left 40%, top 40%) is calm and low-contrast (the name sits there); the lower 30% is darker and calmer (interface sits there).
- A low horizon at about 70% of the image height.

AVOID
Colour, characters, creatures, text, busy detail, high-contrast patterns, hard black shadows, a frame, a photo look, lens flare, watermark.
```

*Кам'яне Серце / Stoneheart* — `bg_stoneheart.png`

```
Create ONE vertical background painting for a premium fantasy mobile game hero screen.

FORMAT
- Aspect ratio 9:21 (tall portrait), 1440x3360 px. If the tool has no 9:21, use 9:16 at 2160x3840 and keep every important shape inside the central 76% of the width (the sides will be cropped).
- GREYSCALE ONLY: a value painting in neutral greys with no colour at all (the game recolours it in the rarity colour).
- No characters, no creatures, no text, no letters, no logo, no frame, no watermark.

ART STYLE
- The same painterly fantasy style as the attached style reference image: large simple shapes, soft depth haze, painterly brushwork, low detail, calm and luminous.

SCENE
- a vast basalt forge hall with tall pillars and giant anvil shapes, its far end opening onto a frozen mountain pass with ice cliffs.

VALUES & COMPOSITION
- Mid-to-light values overall, no pure black areas; strong atmospheric depth: near shapes darker, far shapes lighter.
- The brightest soft glow is right of centre, at about 62% of the width and 25-35% of the height (a hero's head will be there).
- The upper-left area (left 40%, top 40%) is calm and low-contrast (the name sits there); the lower 30% is darker and calmer (interface sits there).
- A low horizon at about 70% of the image height.

AVOID
Colour, characters, creatures, text, busy detail, high-contrast patterns, hard black shadows, a frame, a photo look, lens flare, watermark.
```

*Небожителі / Celestials* — `bg_celestial.png`

```
Create ONE vertical background painting for a premium fantasy mobile game hero screen.

FORMAT
- Aspect ratio 9:21 (tall portrait), 1440x3360 px. If the tool has no 9:21, use 9:16 at 2160x3840 and keep every important shape inside the central 76% of the width (the sides will be cropped).
- GREYSCALE ONLY: a value painting in neutral greys with no colour at all (the game recolours it in the rarity colour).
- No characters, no creatures, no text, no letters, no logo, no frame, no watermark.

ART STYLE
- The same painterly fantasy style as the attached style reference image: large simple shapes, soft depth haze, painterly brushwork, low detail, calm and luminous.

SCENE
- a starlit observatory platform at the edge of a cosmic rift: huge thin orbit rings across the sky, floating rock fragments, a distant spiral of stars.

VALUES & COMPOSITION
- Mid-to-light values overall, no pure black areas; strong atmospheric depth: near shapes darker, far shapes lighter.
- The brightest soft glow is right of centre, at about 62% of the width and 25-35% of the height (a hero's head will be there).
- The upper-left area (left 40%, top 40%) is calm and low-contrast (the name sits there); the lower 30% is darker and calmer (interface sits there).
- A low horizon at about 70% of the image height.

AVOID
Colour, characters, creatures, text, busy detail, high-contrast patterns, hard black shadows, a frame, a photo look, lens flare, watermark.
```

### 5.7 Спорядження (12 предметів, по 3 на фракцію)

Предмети нейтральні за кольором самоцвіту: рамка рідкості (ранг +0…+12 → Кварц…Опал) малюється грою. Налаштування: 1:1 · 1K–2K · референс: `style_anchor.png` · три предмети фракції в одному чаті.

*Орден Світанку · Зброя — Сонцесталевий клинок / Sunsteel Blade* — `gear_dawn_weapon.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Sunsteel Blade
- a straight one-handed sword of pale gold-tinted steel with a white enamel grip and a crossguard shaped like sun rays
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Орден Світанку · Обладунок — Емалевий нагрудник / Enamel Cuirass* — `gear_dawn_armour.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Enamel Cuirass
- a white enamel breastplate with polished gold rims and a small sunburst rivet in the centre
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Орден Світанку · Оберіг — Світанковий медальйон / Dawn Medallion* — `gear_dawn_charm.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Dawn Medallion
- a round gold medallion with a five-ray rising sun over a horizon, on a short white ribbon
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Дикі Ікла · Зброя — Ікло серцевини / Heartwood Fang* — `gear_wildfang_weapon.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Heartwood Fang
- a curved fang-shaped dagger carved from honey-brown heartwood with a bone grip wrapped in leather and a small feather tassel
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Дикі Ікла · Обладунок — Плетена шкура / Woven Hide* — `gear_wildfang_armour.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Woven Hide
- a vest of woven leather strips with fur trim and carved bone toggles
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Дикі Ікла · Оберіг — Коралове намисто / Coral Beads* — `gear_wildfang_charm.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Coral Beads
- a necklace of coral-red and bone-white beads with one carved shell pendant
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Кам'яне Серце · Зброя — Базальтове вістря / Basalt Edge* — `gear_stoneheart_weapon.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Basalt Edge
- a heavy cleaver-like blade of chipped dark basalt bound to a brass handle with leather
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Кам'яне Серце · Обладунок — Магмова броня / Magma Plate* — `gear_stoneheart_armour.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Magma Plate
- a chunky chest plate of dark basalt slabs joined by brass rivets, with dark crimson cooled veins in the stone (no bright orange, no glow)
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Кам'яне Серце · Оберіг — Льодяне серце / Ice Heart* — `gear_stoneheart_charm.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Ice Heart
- a heart-shaped piece of frosted pale ice held in a small brass cage on a short chain (ice, not a gemstone)
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Небожителі · Зброя — Місячне жало / Moonsilver Sting* — `gear_celestial_weapon.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Moonsilver Sting
- a slender needle-like rapier of moonsilver with a crescent-shaped guard and tiny star specks on the blade
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Небожителі · Обладунок — Зоряна мантія / Starglass Mantle* — `gear_celestial_armour.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Starglass Mantle
- a short shoulder mantle of night-blue star-glass plates with white star specks and gold filigree edging
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Небожителі · Оберіг — Підвіска-орбіта / Orbit Pendant* — `gear_celestial_charm.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Orbit Pendant
- a small gold pendant with a tiny planet held inside two crossing orbit rings
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

### 5.8 Реліквії (22, по одній на персонажа)

Налаштування: 1:1 · 1K–2K · референси: `style_anchor.png` + сплеш/картка власника реліквії.

*Горан: Ключ-камінь мосту / Bridge Keystone* — `relic_titan.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Bridge Keystone
- a wedge-shaped keystone of weathered grey granite with a polished gold band and moss on its top edge
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Арін: Якірний ланцюг / Anchor Chain* — `relic_arin.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Anchor Chain
- a coil of heavy copper anchor chain ending in a small gold shackle
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Руді: Крилатий вінець / Winged Circlet* — `relic_bolt.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Winged Circlet
- a gold circlet with two small swept-back wings and one empty square stone setting
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Ейра: Крижана струна / Rime String* — `relic_eira.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Rime String
- a single coiled silver harp string with small frost patterns along it, tied with a pale gold knot
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Мейра: Лампа рун / Rune Lamp* — `relic_seer.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Rune Lamp
- a small hanging lamp of gold filigree with simple rune cut-outs and an indigo silk tassel
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Іскар: Уламок комети / Comet Shard* — `relic_iskar.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Comet Shard
- a jagged shard of night-blue star-glass with a streak of white star specks like a comet tail, capped in gold
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Веста: Сонячна застібка / Sun Clasp* — `relic_vesta.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Sun Clasp
- a polished gold cloak clasp shaped like a five-ray sun with white enamel inlay
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Вартан: Ядро горна / Forge Core* — `relic_vartan.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Forge Core
- a spherical furnace core inside a brass cage with a grille and rivets, cold and dark inside
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Люмен: Вінцевий уламок / Crown Shard* — `relic_lumen.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Crown Shard
- a single curved pearly-white shard from a halo crown set in a small gold cap
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Пава: Перо першого ока / First-Eye Plume* — `relic_pava.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - First-Eye Plume
- one long elegant feather in deep indigo and ink-teal with a single eye-spot
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Міла: Ліхтар наставниці / Mentor's Lantern* — `relic_mila.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Mentor's Lantern
- an old worn brass lantern, patched and dented, with one cracked glass pane
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Іво: Решітка жаровні / Brazier Grate* — `relic_ivo.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Brazier Grate
- a round iron brazier grate with gold rivets and a little soot
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Борко: Дідова лопата / Grandsire's Spade* — `relic_borko.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Grandsire's Spade
- an old worn spade head with copper rivets and a short carved heartwood handle
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Альба: Сніжна тятива / Snow String* — `relic_alba.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Snow String
- a coiled white bowstring with small silver feather charms
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Отто: Перший камінчик / First Pebble* — `relic_otto.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - First Pebble
- a small smooth round river pebble resting on a little bronze stand
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Тая: Колискова / Lullaby Chime* — `relic_taya.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Lullaby Chime
- three small stone tablets hanging from threads under a little gold bar, like a wind chime
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Брант: Серце жеоди / Geode Heart* — `relic_brant.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Geode Heart
- a split geode, black obsidian outside, lined inside with ivory-white crystals
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Тео: Журнал зондів / Probe Logbook* — `relic_teo.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Probe Logbook
- a small leather notebook with brass corners, a star-chart page sticking out and a pencil tucked in the strap
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Олена: Рогові дзвоники / Antler Bells* — `relic_olena.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Antler Bells
- a small antler tine hung with three tiny silver bells
- Material language: heartwood leather, woven hide, fur, feathers, carved bone and coral beads.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Німб: Гроза в пляшці / Bottled Storm* — `relic_nimb.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Bottled Storm
- a corked glass bottle holding a tiny dark storm cloud with an orchid lightning pattern painted on it
- Material language: moonsilver, night-blue star-glass with white star specks, white enamel and fine gold.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Дара: Лебідка гарпуна / Harpoon Winch* — `relic_dara.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Harpoon Winch
- a brass hand winch drum wound with copper chain, with a crank handle
- Material language: white enamel, polished gold, navy cloth, sunburst motifs, sky-harbour rope and brass.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

*Менгір: Найдавніша руна / Eldest Rune* — `relic_menhir.png`

```
Create ONE square item icon for a premium fantasy mobile game.

FORMAT
- Aspect ratio 1:1 (square). Resolution 1024x1024 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No frame, no border, no plate, no shadow on the ground, no vignette (the game adds the rarity frame).
- No text, no letters, no numbers, no logo, no watermark.

ART STYLE
- Painted game-item style matching the attached style reference image: one object, soft painterly rendering with crisp clean edges, rich materials, readable at 96 px.
- Soft key light from the upper left, a thin neutral cool-white rim light from behind on the right. No glow, no sparks, no particles.

OBJECT - Eldest Rune
- a small weathered stone tablet with one deep carved rune and moss on one corner
- Material language: basalt, granite, brass, moss and frost.
- Any crystal on the object is clear colourless crystal (the game frame shows the rarity colour); no coloured gemstones.

COMPOSITION
- The object alone, in a three-quarter view tilted about 30 degrees on a lower-left to upper-right diagonal, centred, filling about 75% of the canvas; at least 10% empty margin on every side.

AVOID
Text, letters, frame, border, hands, characters, a second object, background scene, cast shadow, glow, sparks, coloured gemstones, photorealism, emoji or clip-art look, watermark.
```

## 6. Відкриті питання (за замовчуванням уже вшито в промти)

| # | Питання | За замовчуванням |
|---|---|---|
| P1 | Плащ Вести (Q11 дизайну): малиново-рожевий (колір Плазми) чи помаранчевий, як у v1? | рожевий — варіант A; для B є повні промти, і фронт-лист v1 тоді вже готовий |
| P2 | Внутрішній вогонь клинка Вести лишаємо (затверджений образ) — єдиний кристал, що світиться в арті? | так; решта кристалів не світяться |
| P3 | Зброя й пропи — окремими моделями (на листах руки порожні), як уже зроблено з глефою | так |
| P4 | Сплеші героїв «до колін» (як Веста v2), Руді — на повний зріст (стрибок) | так |
| P5 | Іконки на сірому `#BFBFBF` (ваше правило формату), а не на прозорому | так; прозорий фон можна в ChatGPT, якщо зручніше |
| P6 | Імена в промтах не пишемо; перевірка торгових марок усіх 22 імен і титулів (Q8) — за вами до релізу | так |
| P7 | Камінь-серце Люмена на чолі — чорний опал (контраст із білим тілом, як емблема Опалу) | так |
| P8 | Значки класів малюю вектором (ваш вибір «лінійні значки в кільці»); генеруємо лише ескізи | так |
| P9 | Напрям UI: промти написані під обов'язковий «Genshin × AFK Journey, значно ближче до Genshin»; старі A/B/C не застосовуються | так |
