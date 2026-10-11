# Боси світів / World Bosses — специфікація

Чернетка для затвердження, 11.10.2026 (друга редакція: після перевірки рецензента виправлено таймінг бою, геометрію
ударів, ульту, вимірювання планки й арт-контракт). У коді ще нічого не зроблено.

Рішення власника, на яких стоїть документ (`side_content_ideas.md:55-69`, ідея №7 `:200-207`): сім різних босів, кожен
зі своєю 3D-моделлю (модель робить власник у Meshy за нашими листами); вони вожді орди «Жаророгі / the Emberhorn» в
образах українського фольклору; звичайний гравець перемагає боса щонайменше 8 разів із 10; нагороди тільки вже задумані
плюс титул за першу перемогу.

Як читати:
- Частини **«Коротко»** написано для власника, простими словами.
- Частини **«For developers»** англійською, з посиланнями `файл:рядок` на код, який ми беремо готовим.
  «Not found» означає, що в репозиторії цього немає (ми не вгадуємо).
- Шляхи в коді рахуються від `crystal-rush/`.
- Арт-промти (§11) повні, у форматі `heroes_prompts.md`: копіюйте блок цілком.
- Питання до вас зібрано в §12. У кожному варіант «А» раджу я.

Зміст: §0 Одна сторінка · §1 Мета і планка · §2 Де стоять боси · §3 Спільна будова бою · §4 Сім босів · §5 Баланс ·
§6 Нагороди · §7 3D: заглушка і контракт моделі · §8 Інтерфейс і тексти · §9 Збереження й телеметрія · §10 Перевірки ·
§11 Арт-промти · §12 Питання до власника · Відхилені зауваження критика.

---

## 0. Одна сторінка для власника

- **Сім босів, по одному на останньому, восьмому рівні кожного світу**: рівні 8, 16, 24, 32, 40, 48, 56. У нічній
  «Навалі» ті самі боси чекають на рівнях 64, 72, 80, 88, 96, 104, 112.
- **Фортеця лишається, але стає воротами боса.** Бос стоїть перед нею і б'ється сам. Коли він падає, фортеця
  розвалюється, як і зараз, а далі сходи.
- **Бій має три частини, і всі вони вже знайомі гравцю:**
  1. **Удари.** Останні ~10 секунд мосту бос кидає удари. **Кожен удар б'є лише по одному боці мосту.** Червоне поле
     з'являється за 1,2 секунди до удару, а другий бік завжди вільний і вміщує все військо, навіть найбільше.
  2. **Щит.** Бос ставить щит із двох замків. Перед ним стоять дві пари воріт: звичайні «+» і ворота-ключ. Ворота-ключ
     треба зарядити пострілами героя, як нинішні фіолетові ворота заряду. Пройшов крізь заряджені, і замок злітає, а
     військо ще й поповнюється.
  3. **Бій із босом.** Військо впирається в боса, і він 1,2 секунди замахується на Великий удар: заносить зброю, а
     кнопка ульти показує відлік. **Ульта збиває цей удар.** Далі звичайна облога, як із фортецею.
- **У кожного боса свій удар**, пов'язаний зі світом, і своє правило, як від нього втекти: Змій б'є хвостом по одному
  боці, а наступний удар завжди йде по другому; Водяник відкриває вир на тому боці, де ти стоїш; Блуд ставить ворота,
  що міняються; Князь надовго заливає один бік лавою; Мара дихає на вільний бік, тож головне не метушитися; Вихор
  пускає смерч, що перебігає міст і крутиться біля других перил; Лихо кидає довгий погляд щоразу на інший бік, ніж
  попередній удар.
- **Планка складності:** звичайний гравець перемагає 8 разів із 10 з першої спроби. Перевіряє бот, що грає «як
  звичайна людина»: трохи промахується, трохи запізнюється з ультою. Кожного боса бот грає по 50 разів на кожного
  героя: 10 спроб замало, щоб відрізнити «8 із 10» від «7 із 10».
- **Нагороди тільки вже задумані:** Світова схованка, Ядро боса (лише за першу перемогу), +2 Маяки, Велика скриня героїв,
  Томи, Зоряна руда й трофей (коли запрацюють герої та Майстерня). Нове лише одне: **титул за першу перемогу**.
- **Поки нема 3D-моделі,** бос стоїть як заглушка. Варіантів три: фігура з картки над стіною, фігура з фронт-листа
  перед ворітьми, збільшений рядовий Жаророгий. Я покажу вам усі три на справжньому знімку бою, і ви оберете (§7.1,
  питання 2).
- **Що потрібно від вас:** 7 карток босів, 7 фронт-листів і 7 листів «бік + спина» у Gemini (промти в §11), потім 7
  моделей у Meshy за контрактом із §7.2. Почати раджу зі Змія (перший бос) і Князя (обличчя орди).

---

## 1. Мета і критерії успіху

### Коротко

Зараз восьмий рівень світу закінчується тією самою стіною, що й решта. Бос має стати подією: його видно здалеку, у нього
є ім'я, обличчя, свій удар і своя музика, а перемога відчувається. Водночас він не повинен ставати стіною, об яку
звичайний гравець б'ється по п'ять разів. Тому планка така: **8 перемог із 10 з першої спроби у звичайного гравця**.
Усе має читатися на телефоні: одне червоне поле на один удар; удар завжди б'є лише по одному боці мосту, а на другому
вміщується все військо; жодного дрібного тексту в бою. Якщо планка 8 із 10 вимагатиме зробити боса легшим, ніж
закладено в розрахунок економіки, перемагає планка, а нові цифри економіки я покажу вам (питання 15).

### For developers: measurable criteria (every boss, every gate before `BossData.LIVE = true`)

| # | Criterion | Target | Measured by (§10) |
|---|---|---|---|
| C1 | The owner's bar: a casual player beats the boss on the first try | **50 bot seeds per (boss, hero, phase).** Pass per (boss, phase), pooled over the starters: point estimate ≥ 0.80 **and** Wilson 90% lower bound ≥ 0.70; floor per (boss, hero, phase): point estimate ≥ 0.72; spread between starters ≤ 10 pp per boss. Phases: 0 (shipping) and `HEROES_RUN_PHASE` 2 with the scripted team. Heroes: bolt, titan and seer on **all seven bosses at phase 0** (Мейра unlocks at L5 there, `EconData.HERO_UNLOCK.seer = 5`, `econ_data.gd:41`); at phase 2 seer from W3 (she moves to L24 with heroes, heroes §11.1) | `boss_check`: the real Run + `Bot` at `BossData.CASUAL_SKILL`, EXPECTED synthetic account, Reinforcements off |
| C1n | Night (Invasion) bosses | the owner's choice (§12 Q5); same pass rule | same, levels 64-112 |
| C2 | Not a free win | the lazy path (`x = 0`) loses every boss in ≥ 45 of 50 seeds | `boss_check --bot=lazy` |
| C3 | The boss is the world's peak, not a cliff | the boss level's planner margin equals a plain level-8 build × `m_boss`, with `m_boss = BOSS_DEMAND[w] ± 0.03` (`tools/economy_sim.py:100`: 1.00, 1.00, 1.04, 1.05, 1.05, 1.06, 1.07). **C1 overrides C3** (§5.5) | `demand_bake --boss` (§5.5) |
| C4 | It feels like an event, not a slog | roar to "boss down" 17-21 s; the clash (contact to "boss down") 2.4-5.5 s; **exactly one Great Blow per clash**; whole boss level ≤ 60 s incl. stairs | `boss_check` timings, T2 |
| C5 | Readable on a phone | every strike warns **≥ 1.2 s** (the red fill reaches the rim at impact); a strike covers **at most one side lane** (`abs(x) ≥ 1.2`), so the free width is ≥ `SAFE_MIN` 4.7 u = the widest blob (2 × `BLOB_MAX` 2.2, `balance.gd:14`) + 2 × `UNIT_R` 0.12 (`balance.gd:17`); strike lines ≥ 10.5 u apart (0.71 s to move across between two events at the widest blob); the first warning ≥ 1 s after the roar; ≤ 1 strike warning alive at a time; run toasts ≥ 0.8 s apart; gate labels keep ≥ 3:1 (heroes §10.2 rule 1); strike colours ΔE2000 ≥ 10 from the bad-gate colours | `test_boss` + `hud_lab --gate-legibility` on boss levels |
| C6 | The sim stays honest | Run vs LevelSim on boss levels (bot at skill 1.0, same path): same outcome 10/10; strike losses ±10%, and a perfect dodge at the widest blob loses ≤ 1 soldier in both; locks broken equal; blows landed equal; clash time ±0.3 s; Блуд's faces and the `aimed` / `away` sides identical | `test_boss --parity` |
| C7 | Champions | the front champion still survives 40-60% of boss levels, side/rear ≥ 90% | `champ_survival` (`scripts/dev/champ_survival.gd:32-33`) |
| C8 | Phone performance | the worst 10 s (boss clash with army, convoy, ult, 3 champions) p95 ≤ 20 ms mid, ≤ 25 ms low | heroes §10.6 bench, boss model in |

Why 50 seeds and a confidence bound. The layout is fixed per level (LevelGen seed), so "seeds" only vary the bot's noise
and the Run's `randf`. With 10 seeds, P(≥ 8 of 10) is 0.68 at a true 80% and still 0.38 at a true 70%; with about 38
gates (7 bosses × 2-3 heroes × 2 phases) all passing at a true 85% has p ≈ 0.0005, so tuning would never converge or
would cherry-pick. At 50 seeds per hero, pooled to 100-150 per boss, a true 80% gives a Wilson 90% lower bound of
0.73-0.74 (passes) and a true 70% fails. Runtime: about 1 900 Run plays for C1, ~8 s each at `--speed=6`, so ~4 h in one
process; run 4-6 headless processes in parallel.

Caveat that shapes C1: LevelSim is optimistic. The Run brings about 11.5% fewer soldiers to the fortress than LevelSim
predicts on the same path (`docs/design/sim_drift_report.md` §1). So the owner's bar is measured **in the Run with the
bot**, never in LevelSim alone; LevelSim plans, calibrates and is checked for parity on the new boss rules only.

---

## 2. Де стоять боси

### Коротко

Бос живе на восьмому рівні кожного світу. Фортеця не зникає: бос стоїть перед нею, як вартовий на воротах. Останні
100 одиниць мосту (приблизно 15 секунд бігу) належать босові: спершу удари, потім щит, потім бій. Решта рівня звичайна.

| Світ | Рівень | Навала (ніч) | Бос | Світ на екрані зараз |
|---|---|---|---|---|
| 1 Космос | 8 | 64 | Зоряний Змій | космос |
| 2 Риф | 16 | 72 | Водяник | риф |
| 3 Містика | 24 | 80 | Блуд | космос |
| 4 Вулкан | 32 | 88 | Князь Жаророгих | риф |
| 5 Лід | 40 | 96 | Морозна Мара | космос |
| 6 Небо | 48 | 104 | Вихор | риф |
| 7 Розлом | 56 | 112 | Лихо Однооке | космос |

Світи 3-7 поки що малюються як космос і риф по черзі, бо інших світів у грі ще нема. Боси мають добре читатися на обох.

### For developers

- Boss levels already exist as data: `ArsenalData.is_boss(level)` = level in world 8 (`scripts/core/arsenal_data.gd:726-727`),
  8 levels per world (`arsenal_data.gd:58-59`), Invasion maps back onto worlds 1-7 (`world_of`, `arsenal_data.gd:716-719`);
  the 14 boss levels are listed in `SaveV3Data.BOSS_LEVELS` (`scripts/core/save_v3_data.gd:49`). The run profile already
  carries `boss: bool` (`scripts/autoload/meta.gd:1578-1584`).
- Today a boss level differs from other levels only by one extra crate (`INRUN_BUDGET.boss_extra`,
  `arsenal_data.gd:86-89`, used at `scripts/run/level_gen.gd:164`) and by the rewards (§6). No NEW crate sits on a level 8
  (`ArsenalData.NEW_CRATES`, `arsenal_data.gd:104-111`). The hub only shows a toast on a boss node (`WORLD_CACHE_HINT`,
  `scripts/ui/hub/tab_play.gd:285-288`).
- Visual worlds: only `space` and `reef` exist (`scripts/core/worlds.gd:86`); worlds 3-7 alternate between them
  (`worlds.gd:95-99`). `Worlds.LEVELS_PER_WORLD := 5` (`worlds.gd:87`) is stale; bosses use `ArsenalData.is_boss` only.
- World hazards of plan2 (meteors, currents, mirror arches, lava jets, ice slides, splitters): **not found** in the run code
  (`level_gen.gd`, `hazards.gd`, `run.gd`). They exist only as names in the Haven passives (`econ_data.gd:128-135`,
  arsenal §4.3 table `arsenal_design.md:1042-1048`) and in Feats counters (`econ_data.gd:228`). Squad properties are off
  (`FEATURES.properties = false`, `arsenal_data.gd:38`). `plan2.md` itself is **not found** in the repo. Therefore each
  boss's signature strike (§4) is self-contained and echoes its world's planned hazard; when that hazard ships, the
  boss strike becomes its "big version".
- **The fortress is extended, not replaced.** The level keeps its `{"kind": "fortress"}` item (built in
  `LevelGen._finish`, `level_gen.gd:862-879`) with an added `"boss": "<id>"` key. Every path that needs the fortress keeps
  working unchanged: spawning (`scripts/run/run.gd:492-501`), blocking and siege start (`run.gd:806-808`), machine
  targeting (`Balance.MACHINE_TARGETS`, `scripts/core/balance.gd:32`), the ult's fortress hits (`hero_kinds.gd:939-943`,
  `:1235-1238`), the win, the collapse and the stairs (`run.gd:2785-2852`), crowns and stats (`run.gd:3004-3045`), the siege
  camera (`run.gd:3232-3247`). The boss body stands in front of the gate (`FORT_BACK`, `run.gd:42`) once a model exists
  (the placeholder tiers, §7.1, differ); the fortress hp `Label3D` is hidden on boss levels (the HUD boss bar replaces it, §8.2).

**Boss level layout** (d measured back from the boss line `fd`, the fortress `d`; `RUN_SPEED` 6.5 u/s, `balance.gd:7`;
the widest blob: radius `BLOB_MAX` 2.2 from an army of 40 (`BLOB_K` 0.35 × sqrt(army), `balance.gd:12-14`), half-depth
2.2 × `BLOB_STRETCH` 1.15 = 2.53, front `HERO_GAP` 0.6 behind the hero, rear 5.66 behind the hero):

| d | What | Built by |
|---|---|---|
| 10 → fd − 102 | normal procedural chunks; the boss crate shares squeezed into this stretch (`CRATE_SHARES × (1 − 100 / fd)`). The loop stops at `fd − ARENA − 30` (the longest chunk advances `g.d` by 28 u, `level_gen.gd:751`), then a `tiles` chunk or a coin line fills the gap: nothing crosses fd − 102, and the last thing before the roar is never a squad, barricade, blade or turret (today's loop runs `while g.d < length − 26` and lets the last chunk overshoot, `level_gen.gd:343`, `:372`) | `LevelGen._procedural` (`level_gen.gd:329-372`) with the boss bound |
| hero at fd − 100 | boss roar (`phase` clip 1.4 s), HUD boss bar slides in, phase 1 diamond lit; L8: the strike hint | Run (`BossView`) |
| fd − 100 → fd − 32 | **Phase 1, strikes**: five strike lines at fd − 80, − 69.5, − 59, − 48.5, − 38 (10.5 u = 1.62 s apart). Warnings start at hero fd − 88.8 (1.72 s after the roar, after the `phase` clip ends), − 78.3, − 67.8, − 57.3, − 46.8. A recruit group + tiles 3 u past each line on the free side lane's centre; no squads, blades, turrets, crates or gate rows (Блуд: one gate row instead of event 3) | new `LevelGen._boss_arena(g)` |
| hero at fd − 32 | boss raises the shield (`phase` clip): 2 locks, pool 0.30 × hp0 (§3.3). The army's rear has left line 5 at hero fd − 32.3 | Run / LevelSim through `BossRules` |
| fd − 32 → fd − 1.1 | **Phase 2, shield**: key-gate rows at fd − 30 and fd − 17 (`[key gate, + gate]`, sides alternate) | `_boss_arena` |
| hero at fd − 1.1 | **Phase 3, clash** (`Balance.CONTACT`, `balance.gd:19`): 1.2 s standoff with the Great Blow, then today's siege | Run siege state, boss variant |
| fd + 6 | stairs, unchanged | `level_gen.gd:873-877` |

Level lengths stay `target_length(level)` (`level_gen.gd:179-182`: L8 250 u, L16+ 290 u), so a boss run is about
38-45 s to the clash, then 2.4-5.5 s of clash and ~2.2 s of defeat ceremony. Phase 1 lasts 10.5 s (roar to shield),
phase 2 4.75 s (shield to contact).

---

## 3. Спільна будова бою

### Коротко

Усі сім босів б'ються за одним планом. Кожна частина зроблена з того, що гравець уже знає:

| Частина | Що бачить гравець | Що робить гравець | На чому стоїть |
|---|---|---|---|
| 1. Удари (≈ 10 с) | бос замахується, на одному боці мосту з'являється червоне поле, через 1,2 с туди падає удар | веде військо на другий бік, підбирає там новобранців | шипи й леза, червоне попередження, вже готове в грі |
| 2. Щит (≈ 5 с) | біля боса два замки, попереду дві пари воріт: «+» і ворота-ключ | стріляє героєм у ворота-ключ, щоб зарядити їх, і проходить крізь них | ворота заряду з рівня 3 |
| 3. Бій (≈ 2,5-5 с) | військо впирається в боса; він 1,2 с замахується на Великий удар, а кнопка ульти показує відлік; потім облога | тисне ульту, поки йде відлік | облога фортеці й ульта |
| Перемога (≈ 2 с) | бос падає, з нього вилітає Ядро, фортеця розвалюється | радіє | теперішній кінець рівня |

Якщо замки не зламані, щит забирає ще по 15% здоров'я боса за кожен замок. Це не програш, просто бій дорожчий.

### For developers

#### 3.1 Reuse map (what each phase is built from)

| Need | Reused system (file:line) | New code |
|---|---|---|
| Ground warning, ≥ 1.2 s | `Effects.telegraph_enemy(pos, radius, life)` (`scripts/core/effects.gd:1147-1148`) and `telegraph_enemy_band(from, dir, length, width, life)` (`effects.gd:1152-1154`), shader `shaders/telegraph_ring.gdshader` (`effects.gd:26`), budget `MAX_ENEMY_TELEGRAPHS = 6` (`effects.gd:35`). Both exist and are only used by a gallery today (`scripts/dev/gallery_meta_models.gd:432`). Both draw `ENEMY_RED` (1.0, 0.16, 0.10) (`effects.gd:36`), which is ΔE2000 1.7 from the bad-gate field (1.0, 0.16, 0.14) (`Models.GATE_KINDS.bad`, `scripts/core/models.gd:40`) | call them with `life = BossData.WARN` and a colour argument: fill `STRIKE_FILL` #8E1A1E (ΔE2000 24 from the bad field), rim `STRIKE_RIM` #F2E6DC (ΔE2000 12 from the bad gate's core (1.0, 0.82, 0.7)); the shader has one `color` uniform (`telegraph_ring.gdshader:14`), so add a `rim_color` uniform |
| A strike kills the soldiers that cross it, capped | the barricade hazard band: Run `Hazards.check_army` (`scripts/run/hazards.gd:178`), kills through `Run.hazard_kills` (`run.gd:1356`); LevelSim `_hazards` band model with the barricade cap `min(mass × chord × army, hp)` (`scripts/run/level_sim.gd:1907-1959`, `_chord_share` with the railing pile `:1984-1999`) | item kind `strike` = a time-gated, capped band over one side lane (§3.2), resolved by `BossRules`, outside the armoured early return of `Hazards.check_army` (`hazards.gd:178-180`) and LevelSim's `s.armor > 0.0` skip (`level_sim.gd:1923`) |
| Вихор's twister, Лихо's gaze | **no moving bands.** Both are side-lane bands like every strike; the twister's run across the bridge and the eye's beam are visuals during the warning only. Sweeper code (`Hazards.sweeper_x`, `hazards.gd:156`; `_blade_band`, `level_sim.gd:2004-2015`) is not reused: sweepers are where the Run and LevelSim drift most (`sim_drift_report.md:165`: Run 5,094 vs LevelSim 1,822 soldiers; contact a median 0.3 s off, `:57-58`), and a moving band crossing while the army passes (0.8-1.1 s) leaves no lane-wide gap | none |
| Блуд's gates that swap | blinking gates `{"blink": {op, value, period}}` (`LevelGen._c_blink`, `level_gen.gd:803-817`); LevelSim `blink_phase` / `gate_view` (`level_sim.gd:644-656`) | the pair's clock starts when the hero reaches `row_d − 12`; today `blink_phase` uses absolute run time, `floor(t / period) % 2` (`level_sim.gd:650-656`), and the Run and LevelSim reach rows a median 0.3 s apart (`sim_drift_report.md` §1), so at a 1.2 s period the faces would differ about 25% of the time. Antiphase pair = swapped base/blink values |
| Key gates (phase 2) | charge gates: `LevelGen._c_charge` (`level_gen.gd:621-651`), Run `_hit_gate` charge flip (`run.gd:1271-1287`, `Balance.GATE_HIT_GAIN.charge = 2`, `balance.gd:35`), unflipped pass costs soldiers (`run.gd:1159-1164`); LevelSim `_hit_gate` / `_apply` (`level_sim.gd:1001`, `:691-698`) | reward op `"lock"`; `need` sized from hero fire (§3.3), not `_c_charge`'s `6 + L / 3` |
| Boss clash (phase 3) | siege: `Run._begin_siege` / `_siege` (`run.gd:2543-2588`), LevelSim `_siege` (`level_sim.gd:2194-2215`), exchange `_burst` = `ceil(min(army, hp) / 14)` per `FIGHT_TICK` 0.07 s (`run.gd:2539-2540`, `balance.gd:20`), hero finale `Balance.FINALE_TIME = 3` (`balance.gd:22`), champions' siege tick (`run.gd:2671-2690`) | a 1.2 s standoff at contact (no exchange) carrying the one Great Blow; then today's siege, unchanged (§3.4) |
| The ult has a job | `Run.use_ult` (`run.gd:2219-2231`), LevelSim `use_ult` (`level_sim.gd:1853-1860`), auto policy `HeroKinds.ult_worth` (`scripts/run/hero_kinds.gd:1812-1833`), read by the bot (`scripts/dev/bot.gd:68-69` through `LevelSim.ult_worth`, `level_sim.gd:1849-1850`) | one shared boss rule in `ult_worth` (hold from the roar, cast in the blow's warning) + `stagger_until` (§3.4) |
| Shake, hitstop, haptics | `Juice.add_trauma` (`scripts/core/juice.gd:146`), `hitstop` (`:179`), `haptic` (`:235`) with `HAPTICS` "hit_big", "win" (`juice.gd:37-46`) | none |
| Champions in the fight | hazard path with Healer trim and Guardian Block: Run `_champion_hazard` (`run.gd:2693-2704`), LevelSim `_champ_hazard` (`level_sim.gd:1969`), `ChampionKinds.absorb_hazard` (`scripts/run/champion_kinds.gd:1048-1055`, `_block` `:1058`) | strikes enter it as `&"strike"` (treated as `&"barricade"`); the blow as `&"blow"` (`_block` only, no Rime) |
| Account upgrades on hazards | Barracks Scrape Guard, per hazard item and contact (`Army.scrape_spare`, `scripts/run/army.gd:492-496`; LevelSim `level_sim.gd:1944-1951`; up to `BARRACKS_MAX` 10, `econ_data.gd:95`, track cap 4 in W1, `:98-100`); titan's v3 rally `army_scrape` +3 per contact (`scripts/core/hero_data.gd:17`, `team_data.gd:47`); hero ult wards (Run `run.gd:1384-1394`, LevelSim `level_sim.gd:1953-1956`) | all strikes of one boss share **one** guard slot (the whole phase 1 counts as one contact: Run `scrape_spare(boss_item, lost)`, LevelSim one `s.guard` index for the boss group); wards do not apply to strikes or the blow; Scrape Guard does not apply to the blow. Without this, 5-7 strike items plus the blow would let upgrades erase ~35% of the boss's damage at L8 (caps 11-12 minus 4 per contact) |
| Defeat, collapse, stairs | `Run._win` (`run.gd:2785-2852`), `result.boss_core` (`run.gd:3014`) | boss `defeat` clip + core pop before the collapse |
| Siege music sting | `Audio.play("boss")` at the siege start (`run.gd:2562`, sfx list `scripts/autoload/audio.gd:14`) | boss stingers via `tools/gen_sfx.py` |

**One rules implementation.** Like `HeroKinds` / `ChampionKinds` over `KindView` (heroes §10.4), the boss rules live in
one pure static class `scripts/run/boss_rules.gd` (`BossRules`) called by both the Run and LevelSim: strike sides and
windows, caps, armour, the shared guard slot, key-gate locks and the shield pool, the pre-contact cap, the standoff and
the blow, stagger and the ult hold. The Run adds visuals through `BossView` (`scripts/run/boss_view.gd`); LevelSim adds
nothing visual. Nothing is written twice.

#### 3.2 Phase 1: strikes

**Geometry rule (C5).** Every strike covers exactly one side lane: `x ∈ [1.2, 3.5]` (side +1) or `[−3.5, −1.2]` (side −1),
i.e. lane centre `LANE_X` 2.35, half width `LANE_HALF` 1.15, the soldier radius included. The free width is 4.7 u, more
than the widest blob (4.4 u + 2 × `UNIT_R`), so an army whose centre is anywhere in `[−3.0, −1.12]` (or the mirror) takes
nothing, and at `hx ≈ −1.15` it fits between the strike and the railing without squeezing against either. Why: the blob reaches `BLOB_MAX` from an army of 40, which covers
every boss level, and LevelSim's own band model (`_chord_share` with the railing pile, `level_sim.gd:1984-1999`) gives a
**perfect** dodge of a centre-lane strike (free strips 2.4 u) a loss of ~5% of the army; in the Run, soldiers squeezed
against a rail are pushed back inward and the rear trails, so the loss is higher there. Centre-lane strikes, "two lanes
of three" and "half the bridge" are therefore out.

Item shape emitted by `_boss_arena`:

```
{"kind": "strike", "type": "boulder|lash|aimed|lane|away|twister|gaze", "d": line_d, "side": -1 | 1 | 0,
 "len": 0.0, "bands": 1, "cap": int, "group": "<boss id>", "boss": "<id>", "event": k}
# side 0 = resolved at the warning (aimed, away); len = extra lethal depth past the line (lane 8, gaze 5)
```

Timing and sides, identical in Run and LevelSim (`BossRules.strike_state`):

- **Warning** starts when the hero reaches `d − LEAD − WARN × RUN_SPEED` = `d − 8.8` (`LEAD` 1.0 u, `WARN` 1.2 s). The
  telegraph (one band over the whole lethal area, also for the long strikes) is drawn at that moment with `life = 1.2`;
  its fill reaches the rim exactly at impact. `aimed` and `away` sides resolve at that moment (below), then never change.
- **Impact** when the hero reaches `d − LEAD` (1.2 s later at full speed; phase 1 holds no squads, and the last
  procedural chunk is never a squad, barricade, blade or turret, so the hero never stops there; `test_boss` asserts the
  hero is RUNNING at every warning).
- **Lethal area**: the side lane over `d ∈ [line − 0.3, line + len + 0.3]` (`SPIKES_HALF_Z` 0.3 as barricades,
  `hazards.gd:23`). From impact, soldiers whose centre is inside it die, at most `cap` in total, until the army's last rank
  has passed the far end or `BURN` 2.5 s have passed (the rear always passes first: 1.1 s for a short strike, 1.9 s for
  the gaze, 2.3 s for the lava jet).
- **Moving between events**: at the widest blob the rear leaves a short strike at hero `line + 6.1` and the front meets the
  next line at hero `line + 10.7`: 4.6 u = 0.71 s to cross 2.24 u (the blob follows the hero with `ARMY_FOLLOW` 10/s,
  `level_sim.gd:1979`). The next warning is already up (it started at hero `line + 1.7`), so the player sees where to go
  before the army is free to move. A strike with `len > 0` (lava, gaze) is followed by an event on the **same** side,
  because its band is still lethal when the next front arrives.
- **Sides** (all deterministic; no `randf` / `randi` at run time, so the Run, LevelSim and the bot's snapshot agree):
  - `boulder`, `lash`, `lane`, `twister`: from the level rng at generation, never three times in a row on one side,
    overridden by the previous signature's rule (`lash`: next on the OTHER side; `lane`, `twister`, `gaze`: next on the
    SAME side).
  - `aimed` (Водяник): the hero's side at the warning, `side = sign(hx)`; if `abs(hx) < 0.3`, `side = 1 if hash([level,
    event]) % 2 == 0 else −1`.
  - `away` (Мара): the side the hero is NOT on at the warning, `−sign(hx)`, same tie rule.
  - `gaze` (Лихо): opposite to the previous event's side (event 1: rng).
  - Event 5's side is known at generation for every boss (a `boulder` or a `gaze`), so the first key gate goes to the
    other side and the hero can aim at it while dodging.
- **Armour** (titan's quake, `armor_time` 6 s, `balance.gd:60`): halves a strike's cap (rounded up) instead of the full
  immunity hazards get today. Without this, a quake cast at the first warning (hero fd − 88.8) protects for 39 u, i.e.
  strikes 1-4, and phase 1 is free for one starter.
- After each line `_boss_arena` places a recruit group worth `round(want(g, line_d + 6) × 0.25)` and a short tile line
  **at the free side lane's centre** (`x = −side × 2.35`), 3 u past the line. Recruits are picked up within blob radius +
  `RECRUIT_PAD` 0.4 = 2.6 u (`balance.gd:26`): an army that dodged collects them, an army standing in the struck lane
  (4.7 u away) does not.
- Caps are sized from LevelGen's expected army at the line (`g.e`, `level_gen.gd:9-17`): `cap = round(a × e) + b` with
  `[a, b]` per strike type (§4.8). `LevelGen.scale_enemies` (`level_gen.gd:143-153`) scales `strike.cap` by the team
  demand, exactly as it scales barricade hp.

Readability rules (C5): one telegraph per strike (the lava jet is one long band, not three); at most one strike warning
alive at a time (warning k ends at its impact, warning k + 1 starts 2.7 u later); no gate row within 6 u of a strike
line; no full-screen flash; red is only ever a threat, and the strike red is a darker crimson than the bad gates.

#### 3.3 Phase 2: key gates, locks and the shield

- Two rows `[key gate, + gate]` at fd − 30 and fd − 17 (gates at `x = ±ROW2_X` 1.65, `level_gen.gd:29`), the key gate on
  alternating sides (first side = away from event 5's strike).
- **Key gate** = a charge gate (`op "charge"`, value `−need`) with reward `{"op": "lock", "value": round(want(g, row_d + 22))}`.
  `need` is sized from the hero's fire in the window the hero really has, not from `_c_charge`'s `6 + L / 3 + rng(0..2)`
  (`level_gen.gd:626`), which assumes a calm 16 u approach and reaches 27-45 on night levels (14-23 hero damage, 4-6 s of
  Bolt's base fire): `need = max(6, round(KEY_FILL 0.8 × GATE_HIT_GAIN.charge 2 × dps_min(L) × KEY_WINDOW 1.6 s))`, with
  `dps_min(L)` the lower damage per second of the two reference heroes (`REF_HEROES`, `level_gen.gd:41`) at the EXPECTED
  profile of level L (LevelGen stays account-independent: the number is a design constant per level). The window: the
  hero fires at a gate from its range (bolt 15, titan 12, seer 16 u: `balance.gd:54`, `:59`, `:69`) until it passes it, about 1.85-2.5 s at full speed,
  while also steering. The Seer fills ×1.5 (`balance.gd:70`). Passing a flipped key gate adds `value` soldiers **and**
  breaks one lock. Passed unflipped it costs `need` soldiers and breaks nothing (today's rule, `run.gd:1159-1164`,
  `level_sim.gd:691-698`).
- **+ gate** beside it: `round(want × 0.6) + level` (as `_c_charge`, `level_gen.gd:641`). The flipped key gate is always the
  better pick. This is an **aim test, not a trade-off**: every starter's range is 12-16 u, so the boss is out of range
  until the hero has passed the second key row (fd − 17), and key-gate fire never competes with chipping the boss.
- **Shield.** Created when the hero reaches `SHIELD_AT` (fd − 32): `shield = LOCK_SHIELD 0.15 × hp0 × 2` (hp0 = the boss's
  starting hp, after `scale_enemies`). From then on all boss damage (hero, machines, volleys, ult, siege ticks) takes the
  shield first, then hp. Breaking a lock removes `min(0.15 × hp0, shield left)`; shield already spent stays spent. Before
  `SHIELD_AT` there is no shield. One implementation (`BossRules.boss_damage`, `BossRules.break_lock`), tested in T2.
  Shown as a hatched segment on the HUD bar.
- **Pre-contact cap.** Until contact the boss's hp cannot fall below `(1 − PRE_CAP 0.5) × hp0`; further hits only spark
  ("the boss parries"). Shield damage does not count toward the cap. Why: today the fortress hp is `pre-damage of the
  reference players + their army × share` (`level_gen.gd:954-989`), and a stronger path chips far more on the way (the
  spec review's LevelSim probe: on today's L16 the planner reaches the gate with 3-30 hp left of ~165); without a cap
  such players would never see the clash, the blow or the ult beat.
- Visual: two dark obsidian plates orbit the boss at chest height; a broken lock shatters (`Effects` debris, shockwave)
  with the toast «Замок зламано!»; both gone gives «Щит упав!». Run toasts are queued at least `TOAST_GAP` 0.8 s apart
  (the second lock, the shield and the blow warning can otherwise land within ~1 s).

#### 3.4 Phase 3: the standoff, the Great Blow, the siege

- **Why not a slower siege.** The siege exchange is `ceil(min(army, hp) / 14)` per 0.07 s tick on both sides
  (`run.gd:2539-2580`, `level_sim.gd:2194-2210`). It shrinks geometrically and then loses 1 per tick for the last ~14 hp,
  so a siege lasts about `14 × ln(hp / 14) + 14` ticks: hp 30 → 21 ticks (1.5 s), 100 → 36 (2.5 s), 200 → 45 (3.2 s).
  Stretching the tick would stretch a siege to 4-11 s and, because hero, machine, volley and champion damage is per
  second, would change who wins (DPS kits and decks would gain three times the time per tick). So the exchange stays
  exactly as today, and the boss adds a fixed beat in front of it.
- **Standoff** at contact (`Run._begin_siege`, `run.gd:2543`): for `WINDUP` 1.2 s the boss holds the gate. No exchange tick
  runs (the siege loop starts after the standoff); the hero, machines and volleys keep firing as in any siege (into the
  shield first). The Great Blow's warning runs for the whole standoff and is shown three ways: the boss's `blow` wind-up
  clip (or the placeholder's tilt), a 1 dpx countdown ring on the HUD ult button (no glow; every boss, every time, §8.2),
  and a secondary ground disc under the front rank (`telegraph_enemy`, radius = blob radius, `STRIKE_FILL`).
- **Great Blow**: lands at the end of the standoff unless cancelled. The army loses `max(2, round(BLOW_SHARE[w] × army at
  contact))` from the front rank (`Run.boss_blow(n)`: a count of front units, not touched units; LevelSim the same count).
  No Scrape Guard, no wards; Healer trim and a ready Guardian Block apply (`absorb_hazard` with `&"blow"`, `_block` only).
  Champions take no direct blow damage. **Exactly one Great Blow per clash.** If the boss falls during the standoff, there
  is no blow.
- **Siege**: then today's siege runs unchanged (`FIGHT_TICK`, `_burst`, champions' siege tick). Champions idle during the
  standoff (no exchange ticks).
- **Stagger**: a cast while the blow's warning runs, or within `STAGGER` 2.5 s before the blow would land (that is, from
  1.3 s before contact), cancels it: the boss reels back (`stagger` clip), toast «Удар збито!», haptic "ult".
- **The ult policy on boss levels: one shared rule in `HeroKinds.ult_worth`** (used by the Run's bot, LevelSim, the
  reference players and the planner, `bot.gd:68-69`, `level_sim.gd:1849-1850`). From the roar (hero at fd − `ROAR_AT`)
  until the blow lands or is cancelled, a ready ult is **held** (worth 0), except while the blow's warning runs (worth 1).
  New `KindView` methods `boss_hold()` and `blow_warning()` (base `false`), checked before the `in_fight()` branch, for v3
  and Meta-1 rows alike. Two view changes on boss levels: the boss's fortress item does not count in `threat_ahead`
  (today it adds 99, `run_kind_view.gd:121-122`, `sim_kind_view.gd:91-92`), and strike items do not count in
  `hazard_near` (`sim_kind_view.gd:96-99`; `RunKindView` keeps the base answer `false`, `kind_view.gd:83`), so titan's
  guard row (`hero_kinds.gd:91`, `:1828-1831`) never fires on a strike. Why: today a Meta-1 row fires as soon as the
  fortress is within reach and 99 ≥ 0.35 × army, i.e. at any army ≤ 283, which is 12-16 u (2-2.5 s) before contact, and
  a stagger from that cast ends before a blow at contact + 1.2 s; titan's guard row also fires on any hazard within 6 u,
  so it would spend the ult on strike 1. A human player may cast whenever; the countdown ring says when it pays.
- During the clash the hero cannot steer (hero x only moves in RUNNING / READY, `run.gd:750-751`), which is why phase 3
  threats are answered with the ult, never with dodging.
- Army gone: the hero gets `FINALE_TIME` 3 s as today.
- First boss only (L8): the level script fills the ult 2 u before the clash (`script.ult_ready_at`, as tutorial 3 does,
  `level_gen.gd:302`; read by the Run at `run.gd:757-761` and LevelSim at `level_sim.gd:484-486`), and the hold rule
  keeps it for the warning, so the lesson "ult breaks the blow" always lands the first time. Owner question §12 Q8.

#### 3.5 Defeat and loss

- **Win**: `Run._win` (`run.gd:2785`) gains a 1.2 s boss beat before its collapse: hitstop 0.12 s (existing), the boss
  `defeat` clip (or the placeholder tipping back, §7.3), and on a first clear the Boss Core (opal heart, arsenal asset A-39,
  `arsenal_design.md:2002`) pops out and flies to the HUD in 1.0 s. Big toast «%s подолано» (§8.5). Then the existing
  collapse, stairs and result flow (result-screen order in §8.4).
- **Loss** (`ARMY_LOST`, `NOT_ENOUGH`): unchanged rules (Reinforcements `econ_data.gd:181-182`, loss payout
  `econ_data.gd:403-406`). The loss screen gets one tip keyed by the biggest loss source in soldiers (§8.4).

#### 3.6 Shared constants (`scripts/core/boss_data.gd`, hand-written like `econ_data.gd`)

```gdscript
class_name BossData
## World bosses (docs/design/world_bosses_spec.md). Hand-written data; BossRules reads it in the Run and in LevelSim.
const LIVE := false                 # rollout flag: off until every §10 gate is green
const ORDER: Array[String] = ["zmii", "vodianyk", "blud", "kniaz", "mara", "vykhor", "lykho"]   # world 1..7
const WARN := 1.2                   # s of ground warning before a strike turns lethal (minimum)
const LEAD := 1.0                   # u: the strike line turns lethal when the hero is this far before it
const BURN := 2.5                   # s a landed strike stays lethal at most (the army's rear always passes sooner)
const ARENA := 100.0                # u before the boss line where the arena starts; procedural chunks end 2 u before
const ROAR_AT := 100.0              # u before the boss line: the roar and the HUD bar (1.72 s before the first warning)
const P1_LINES: Array[float] = [80.0, 69.5, 59.0, 48.5, 38.0]   # u before the boss line, 10.5 u apart
const SHIELD_AT := 32.0             # u before the boss line: the shield goes up (the rear has left line 5)
const KEY_ROWS: Array[float] = [30.0, 17.0]                     # u before the boss line
const LANE_X := 2.35                # a strike covers one side lane: |x| in [LANE_X - LANE_HALF, 3.5]
const LANE_HALF := 1.15
const SAFE_MIN := 4.7               # u: free width at every strike (>= 2 * BLOB_MAX + 2 * UNIT_R = 4.64)
const KEY_WINDOW := 1.6             # s of hero fire a key gate is sized for
const KEY_FILL := 0.8               # share of that fire the gate needs
const LOCK_SHIELD := 0.15           # share of hp0 per lock in the shield pool
const PRE_CAP := 0.5                # share of hp0 the boss can lose before contact
const WINDUP := 1.2                 # s: the standoff at contact = the Great Blow's warning
const STAGGER := 2.5                # s before the blow lands in which any ult cast cancels it
const SHARE_OFFSET := -0.05         # boss clash share vs LevelGen's fortress share (level_gen.gd:959)
const TOAST_GAP := 0.8              # s between two run toasts
const STRIKE_FILL := Color("8e1a1e")   # dE2000 24 from the bad-gate field (models.gd:40)
const STRIKE_RIM := Color("f2e6dc")    # dE2000 12 from the bad gate's core
const BOULDER := {"len": 0.0, "cap": [0.05, 2]}                 # cap = round(a * e) + b
const CASUAL_SKILL := 0.6           # placeholder; set by boss_check --calibrate (spec §5.4)
const BOSSES := {
	"zmii":     {"world": 1, "pattern": "BSBBS", "sig": {"type": "lash", "len": 0.0, "next": "other", "cap": [0.06, 2]}, "blow": 0.06, "demand": 1.00},
	"vodianyk": {"world": 2, "pattern": "BSBSB", "sig": {"type": "aimed", "len": 0.0, "cap": [0.07, 2]}, "blow": 0.06, "demand": 1.00},
	"blud":     {"world": 3, "pattern": "BBGBB", "sig": {"type": "two_faced", "period": 1.2, "clock_from": 12.0}, "blow": 0.07, "demand": 1.04},
	"kniaz":    {"world": 4, "pattern": "BSBSB", "sig": {"type": "lane", "len": 8.0, "bands": 3, "next": "same", "cap": [0.035, 1]}, "blow": 0.07, "demand": 1.05},
	"mara":     {"world": 5, "pattern": "BSBSB", "sig": {"type": "away", "len": 0.0, "cap": [0.07, 2]}, "blow": 0.08, "demand": 1.05},
	"vykhor":   {"world": 6, "pattern": "BSBSB", "sig": {"type": "twister", "len": 0.0, "spin": 2.0, "next": "same", "cap": [0.08, 2]}, "blow": 0.08, "demand": 1.06},
	"lykho":    {"world": 7, "pattern": "SBSBS", "sig": {"type": "gaze", "len": 5.0, "side": "opposite", "next": "same", "cap": [0.08, 2]}, "blow": 0.09, "demand": 1.07},
}
# pattern letters per phase-1 event: B boulder, S signature, G Блуд's two-faced gate row
```

---

## 4. Сім босів

### Коротко: спільні правила образу й ударів

- Кожен бос — **вождь орди Жаророгих**, що вбрався в образ із нашого фольклору. Тому в усіх спільна палітра ворога:
  темний кармін, чорний обсидіан, стара бронза і тонкі темно-жаринні тріщини. Усе матове, без глянцю. Одна
  прикраса-камінь: **темний нефрит** (зелений, але глибокий, не яскравий). Питання про камінь §12 Q1.
- **Не Вій.** Ніяких живих людей. Ніякої війни чи політики: жодних прапорів, гербів, тризубів, хрестів, півмісяців,
  справжніх військових форм, шоломів чи літер. Жаророгі вигадані й не схожі на жодного справжнього ворога.
- Грізні, але не криваві й не страшні для дітей: без крові, ран, черепів і кісток, без жахастиків. Без світіння й
  частинок на арті (усі ефекти додає гра).
- Біла емаль і золото — матеріали наших героїв, на босах їх нема. Бронза і чорний метал — так.
- Кожен має: звичайний удар (кидок, червоне поле на одному боці мосту), **свій удар** (новий у кожному світі) і
  **Великий удар** у бою (його збиває ульта).
- **Кожен удар б'є лише по одному боці мосту**, ніколи посередині й ніколи по двох боках разом. Так усе військо, навіть
  найбільше, завжди вміщується на другому боці. Різняться удари тим, як дізнатися, куди вдарить: десь видно одразу, десь
  «туди, де ти стоїш», десь «туди, де тебе нема».

Що означають числа нижче:
- «Удар забирає до X» — найбільше солдатів, яких один удар може вбити, у відсотках від армії, що зазвичай є в цей момент.
- Хто ухилився, не втрачає нічого: вільний бік ширший за все військо (перевіряємо тестом і в грі, і в симуляторі).

### 4.1 Зоряний Змій `zmii` — Світ 1, Космос, рівень 8

**Хто це.** Крилатий змій із казки про Кирила Кожум'яку: він упав на міст разом із зорепадом, і його луска з
небесного заліза. Перший бос, тому найпростіший і вчить читати удари та перебігати з боку на бік.
**Вигляд.** Величезний змій-дракон стоїть на двох задніх лапах; одна голова з рогами; луска темного метеоритного
заліза з тонким сріблястим візерунком; кармінове черево; крила кажана з карміновими перетинками; хвіст із бронзовою
булавою. Нефрит на лобі між рогами.
**Що робить.**
- Звичайний удар «Зоряні луски»: кидає важку луску, червоне поле на одному боці мосту.
- Свій удар **«Удар хвостом»**: хвіст падає на один бік мосту, а наступний удар завжди йде по другому, тож одразу
  перебігай. Забирає до 6% армії.
- Великий удар «Кільця Змія»: забирає 6% армії, якщо не збити ультою.
- Порядок ударів: луска, хвіст, луска, луска, хвіст.

### 4.2 Водяник `vodianyk` — Світ 2, Риф, рівень 16

**Хто це.** Старий господар вод, що спить під млином і тягне у вир тих, хто зазівався.
**Вигляд.** Кремезний старий велетень зі шкірою, мов вологий матовий вулканічний камінь; довга борода й волосся з
темно-кармінових водоростей; корона з чорного корала з бронзовими мушлями; уламок бронзового млинового колеса замість
наплічника; довге весло-багор (не тризуб). Нефрит у центрі корони.
**Що робить.**
- Звичайний удар «Мулисті брили».
- Свій удар **«Вир»**: відкривається на тому боці мосту, де військо стоїть у момент попередження. Перебіжи на другий
  бік. Забирає до 7%.
- Великий удар «Хвиля»: 6%.
- Порядок: брила, вир, брила, вир, брила.

### 4.3 Блуд `blud` — Світ 3, Містика, рівень 24

**Хто це.** Дух, що водить манівцями: підморгує ворітьми й плутає стежки. Хитрий пустун, а не страховисько.
**Вигляд.** Високий і худий, із довгими тонкими пальцями; вузьке хитре обличчя з темно-сірою шкірою: довгий тонкий ніс,
вигнуті чорні брови, вузькі очі й крива усмішка; широкий пом'ятий кармінний капелюх; подертий кармінний каптан із
бронзовими ґудзиками; на поясі сухий очерет і бронзові дзвіночки; кривий посох із клітковим ліхтарем, а в ліхтарі
«фальшиве світло»: нефрит. Впізнають його за капелюхом, очеретом, дзвіночками й ліхтарем, а не за страшним обличчям.
**Що робить.**
- Звичайний удар «Блудні вогники».
- Свій удар **«Двоїсті ворота»**: двоє воріт по черзі стають то добрими, то поганими (раз на 1,2 секунди). Влучи в
  добрі. Це ті самі «мерехтливі» ворота, що вже є в грі, тільки парою.
- Великий удар «Морок»: 7%.
- Порядок: вогник, вогник, двоїсті ворота, вогник, вогник.
- З героями: після цього боса до гравця приєднується Мейра (з героями вона приходить після боса Світу 3). Без героїв
  Мейра вже поруч із рівня 5.

### 4.4 Князь Жаророгих `kniaz` — Світ 4, Вулкан, рівень 32

**Хто це.** Володар орди. Той самий, кому Сірко з військом колись написав листа, і він досі лютує. (Ім'я «Князь» —
питання §12 Q12.)
**Вигляд.** Високий вождь у матових чорних обсидіанових латах із кармінними пластинами й бронзою; величезні закручені
роги з вулканічного каменю з темно-жаринними тріщинами, зрослі з короною-шоломом; закрите забрало у формі суворого
обличчя (не людське обличчя); кармінний плащ без жодного знака; важка обсидіанова булава. Нефрит у короні над забралом.
**Що робить.**
- Звичайний удар «Вогняні брили».
- Свій удар **«Лавовий струмінь»**: лава заливає один бік мосту на вісім кроків уперед і тримається, поки військо не
  пробіжить; наступний удар падає туди ж, тож лишайся на другому боці. Забирає до 11% разом.
- Великий удар «Рогатий таран»: 7%.
- Порядок: брила, струмінь, брила, струмінь, брила.

### 4.5 Морозна Мара `mara` — Світ 5, Лід, рівень 40

**Хто це.** Дух довгої зими. Її проводжають навесні, і вона цього страшенно не любить.
**Вигляд.** Висока, худорлява, велична, вся закрита одягом; корона з довгих шпилів чорного матового льоду з сивим
інеєм; кармінна вуаль; довга розрізна сукня поверх обладунку на ногах (щоб ноги було видно для 3D); попеляста шкіра;
без зброї (без серпа). Нефрит у брошці на комірі.
**Що робить.**
- Звичайний удар «Крижані брили».
- Свій удар **«Подих Мари»**: мороз падає на той бік мосту, де війська НЕМА. Не метушись і стій, де стоїш: хто кинеться
  туди, стане крижаною статуєю. Забирає до 7%.
- Великий удар «Хуртовина»: 8%.
- Порядок: брила, подих, брила, подих, брила.

### 4.6 Вихор `vykhor` — Світ 6, Небо, рівень 48

**Хто це.** Чорт, що танцює у вихорі й розкидає загони, мов солому.
**Вигляд.** Жилавий, худий, ріжки, гострі вуха, довгий хвіст-батіг із бронзовим вістрям; ноги в темній козячій шерсті
від коліна й копита (коліна звичайні, людські, щоб модель гнулася правильно); темна матова обсидіанова шкіра з
темно-жаринними тріщинами на передпліччях; довгий подертий кармінний пояс-шарф, що закручується спіраллю. Без вил,
без пентаграм, без вогню. Нефрит у бронзовій сережці. Сам смерч гра малює окремо.
**Що робить.**
- Звичайний удар «Каміння з вітру».
- Свій удар **«Смерч»**: смерч вилітає від одних перил, перебігає міст і крутиться біля других. Червоне поле одразу
  показує, де він зупиниться: тікай туди, звідки він вилетів. Наступний удар падає туди ж, де смерч. Забирає до 8%.
- Великий удар «Порив»: 8%.
- Порядок: камінь, смерч, камінь, смерч, камінь.

### 4.7 Лихо Однооке `lykho` — Світ 7, Розлом, рівень 56

**Хто це.** Одноокий велетень із казки. Сидить у Розломі й бачить крізь нього все. Останній бос кампанії.
**Вигляд.** Дуже високий, кістлявий велетень із шкірою, мов вивітрений базальт; одне велике кругле око посеред чола,
**райдужка ока і є нефрит**; важкі брови, повіки звичайні (не як у Вія); кармінне лахміття, шкіряний фартух із бронзовими
заклепками, бронзові ланцюги на поясі; палиця з почорнілого дубового стовбура в бронзових обручах.
**Що робить.**
- Звичайний удар «Кам'яні брили».
- Свій удар **«Погляд»**: довгий погляд падає на один бік мосту, щоразу на інший, ніж попередній удар, тож доведеться
  перебігати. Наступна брила падає туди ж, де погляд. Забирає до 8%.
- Великий удар «Удар палицею»: 9%.
- Порядок: погляд, брила, погляд, брила, погляд.

### 4.8 For developers: exact numbers

Shared boulder (`B`): a side-lane band at the line (`len` 0), side from the level rng (never three in a row on one side)
unless the previous signature sets it, `cap = round(0.05 e) + 2`. `e` = LevelGen's expected army at the line. There is no
"two boulders at once" event any more: two side lanes leave only the 2.4 u centre, narrower than the blob.

| # | id | World | Levels | Phase-1 pattern | Signature (`S`) | Geometry and side rule (every strike: one side lane, §3.2) | Cap per event | Great Blow | `BLOW_SHARE` | `BOSS_DEMAND` target |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `zmii` | 1 Space | 8 / 64 | B S B B S | Tail Lash `lash` | short band; side from rng; the next event strikes the OTHER side (0.71 s to cross) | `round(0.06 e) + 2` | Serpent Coils | 0.06 | 1.00 |
| 2 | `vodianyk` | 2 Reef | 16 / 72 | B S B S B | Undertow `aimed` | short band on the hero's side at the warning, `sign(hx)`; tie (`abs(hx) < 0.3`) by `hash([level, event])` | `round(0.07 e) + 2` | Wave | 0.06 | 1.00 |
| 3 | `blud` | 3 Mystic | 24 / 80 | B B G B B | Two-Faced Gates `G` | one 2-gate row at the event line: left `{+ round(want × 1.35)}` blink `{− (round(0.3 e) + L)}`, right the reverse, `period` 1.2 s (`_c_blink` numbers, `level_gen.gd:806-813`); the faces' clock starts when the hero reaches `row_d − 12` | — (a gate; the bad face costs `0.3 e + L`) | Gloom | 0.07 | 1.04 |
| 4 | `kniaz` | 4 Volcano | 32 / 88 | B S B S B | Lava Jet `lane` | side lane from the line 8 u forward, 3 bands at +0, +4, +8 sharing the line's warning (one long band telegraph); lethal until the army's rear passes the last band (~2.3 s from impact); side from rng; the next event strikes the SAME side | `round(0.035 e) + 1` per band (≤ `0.105 e + 3`) | Horn Ram | 0.07 | 1.05 |
| 5 | `mara` | 5 Ice | 40 / 96 | B S B S B | Mara's Breath `away` | short band on the side the hero is NOT on at the warning, `−sign(hx)`, same tie rule; victims become ice statues (UnitFx variant) | `round(0.07 e) + 2` | Blizzard | 0.08 | 1.05 |
| 6 | `vykhor` | 6 Sky | 48 / 104 | B S B S B | Twister `twister` | short band; side from rng; the twister visual starts at the opposite rail at the warning, crosses during it and spins on the struck lane for 2.0 s; the red telegraph sits on the struck lane for the whole 1.2 s; the next event strikes the SAME side | `round(0.08 e) + 2` | Gust | 0.08 | 1.06 |
| 7 | `lykho` | 7 Rift | 56 / 112 | S B S B S | The Gaze `gaze` | band 5 u long (`d ∈ [line − 0.3, line + 5.3]`); side opposite to the previous event (event 1: rng); the next event strikes the SAME side | `round(0.08 e) + 2` | Club Smash | 0.09 | 1.07 |

Worked example, L8 (Змій): `goal_army(8) = 247` (`level_gen.gd:186-187`); at fd − 80 the expected army is ~170, so a boulder
caps at 11, the tail at 12, the blow takes ~11 of a ~190 army. At L56 (Лихо) `e` ≈ 420-480: boulder ≤ 26, gaze ≤ 38, blow
~40 of ~450. These are starting values; §5.3 lists the knobs.

Invasion (night) bosses use the same rows; difficulty comes from the level offset (`EconData.INVASION`, `econ_data.gd:180`)
and the Invasion team demand. The run tints the boss with the world's night light; the HUD shows a «Ніч» chip.

---

## 5. Баланс

### Коротко

Бос не має бути ні подарунком, ні стіною. Ми робимо так:
1. Комп'ютерний «ідеальний гравець», що вже зараз підбирає розмір фортеці, проходить і боса, з усіма правилами бою
   (щит, замах, ульта). Здоров'я боса підбираємо так, щоб бій коштував йому стільки ж війська, скільки фортеця, трохи
   менше.
2. Потім бот, що грає «як звичайна людина» (трохи промахується, трохи спізнюється, інколи забуває ульту), по 50 разів
   грає кожного боса кожним героєм. Треба 8 перемог із 10 або більше. Якщо менше, ослаблюємо удари, а не робимо
   фортецю «безкоштовною».
3. Перевіряємо, що бос складніший за звичайний рівень рівно настільки, наскільки вже розраховано в економіці (на 0-7%).
   Якщо для планки 8 із 10 боса доведеться зробити легшим, ніж у розрахунку, перемагає планка: я перерахую економіку й
   покажу вам, що змінилося.
4. Те саме з увімкненими героями й чемпіонами, і окремо перевіряємо, щоб жоден герой не мав помітно легшого боса за
   інших (різниця не більше 10 перемог зі 100).

### For developers

#### 5.1 What LevelSim must model (so the planner, TEAM_DEMAND and the bot stay honest)

All through `BossRules`, mirrored by the Run:
1. `K.STRIKE` (new kind in `LevelSim.K`, `level_sim.gd:98`): indexed in `haz` like barricades, resolved in `_hazards`
   (`level_sim.gd:1907-1959`) with the barricade cap (`hp = cap`) and `_chord_share` restricted to the side lane, gated by
   `BossRules.strike_live(it, s.d, s.t)`. `aimed` / `away` sides resolved when `s.d` crosses the warning distance (from
   the path, so the planner sees the consequence of its own line); `lane` = 3 sub-bands sharing one window. Strikes skip
   the `s.armor > 0.0` skip (`level_sim.gd:1923`) and use `ceil(cap / 2)` while armoured. Scrape Guard: one `s.guard`
   slot for the boss group. No wards on strikes.
2. No new blade types: the twister and the gaze are `K.STRIKE` bands (§3.1).
3. `"lock"` reward op in `_apply` (`level_sim.gd:667-718`): `_gain` the value, `BossRules.break_lock(s)`.
4. Boss state on `State` (copied by `State.copy()`): `boss_id`, `locks_left` (2), `shield`, `shield_up`, `standoff_t`,
   `blow` (0 pending, 1 warning, 2 landed, 3 cancelled), `stagger_until`, `strike_deaths`, `last_side`, `face_t0` (Блуд).
5. `_hurt` on the boss (`level_sim.gd:1035`) goes through `BossRules.boss_damage` (shield first, then hp, `PRE_CAP` before
   contact); `_siege` (`level_sim.gd:2194`) runs the standoff (`BossRules.standoff_step`) first, then today's loop
   unchanged; `use_ult` (`level_sim.gd:1853`) sets `stagger_until`.
6. The bot's snapshot (`scripts/dev/bot.gd:148`, through `LevelSim.level_from_items`, `level_sim.gd:2454`) copies strike
   items with their resolved sides, the boss state and Блуд's `face_t0`, so `LevelSim.plan` (`level_sim.gd:2295`) dodges
   what it can see; fogged values for skill < 1 stay fogged as today (`bot.gd:64`).
7. `LevelSim.value` (`level_sim.gd:2262`) needs no change: strikes and the blow cost army, which it already values.
8. `SimKindView`: `threat_ahead` skips the boss's fortress item, `hazard_near` skips strike items, plus `boss_hold()` and
   `blow_warning()` (§3.4); `RunKindView` the same three.

#### 5.2 Calibration of the boss hp (`LevelGen._ref_boss`, replaces `_ref_fortress` on boss levels)

Today's `_ref_fortress` (`level_gen.gd:954-989`) walks the two reference players (bolt, titan, `REF_HEROES`,
`level_gen.gd:41`) to the gate on their best simple lines and sets `hp = pre-damage + army × share`. That closed form
holds only for a pure 1:1 exchange with nothing else going on. The boss adds the pre-contact cap, the shield, the
standoff (1.2 s of hero and machine fire with no exchange), the blow and the boss ult policy, so `_ref_boss` **bisects
hp0 on the fully simulated fight** instead:
- target: the reference players' mean clash cost (army at contact minus army at the win, blow included, divided by the
  army at contact) equals `share = clamp(0.35 + 0.05 × (L − 4), 0.35, 0.6) + SHARE_OFFSET (−0.05)` (the fortress share,
  `level_gen.gd:959`, minus 5 points as a buffer for casual players, who often eat the blow);
- the references break both locks and follow the boss ult policy, so with a ready ult they cancel the blow; a player who
  breaks no lock pays the whole 0.30 × hp0 shield on top;
- ~12 bisection steps × 2 references per boss level. LevelGen builds a level at load, so measure the build time (target
  ≤ 150 ms per boss level on a mid phone); if it is slower, precompute hp0 per boss level into a generated table.

The stairs keep `STAIRS_UNITS` from the measured survivors (`level_gen.gd:867-877`).

#### 5.3 Knobs (in the order to turn them)

| Knob | Start | Effect | Range |
|---|---|---|---|
| strike `cap` shares (`[a, b]` per type) | §4.8 | casual losses in phase 1; planner barely affected | a ∈ [0.03, 0.10] |
| `BLOW_SHARE[w]` | 0.06-0.09 | the cost of a missed ult | [0.04, 0.12] |
| `KEY_FILL` | 0.8 | how hard the key gates are to flip | [0.6, 1.0] |
| `LOCK_SHIELD` | 0.15 | the cost of skipping key gates | [0.10, 0.25] |
| `SHARE_OFFSET` | −0.05 | the boss hp for everyone (C3) | [−0.10, +0.05] |
| `PRE_CAP` | 0.5 | how much a strong path can chip before the clash | [0.3, 0.6] |
| `P1_LINES` count | 5 | event length and strike pressure (spacing stays ≥ 10.5 u) | 4-5 |

Never tune the boss by making it cheaper for strong accounts only (arsenal design rule: upgrades must not erase a run
decision, `arsenal_design.md:19-21`), and never by scaling LevelGen to account power (`arsenal_design.md:17`).

#### 5.4 The casual bot (C1)

- `Bot` already models a weaker player: `skill < 1` adds a reaction delay `(1 − skill) × 0.35 s`, aim noise
  `σ = (1 − skill) × 1.2 u` and a random pick with probability `(1 − skill) × 0.25` per think (`bot.gd:96-111`).
- Add the same realism to the ult: at `skill < 1` the bot casts a ready ult only `(1 − skill) × 1.5 s` after the policy
  says so (in a fight, or when the blow's warning starts), and skips the whole fight or blow with probability
  `(1 − skill) × 0.5` (today it casts at once, `bot.gd:68-69`). At 0.6: 0.6 s late (still inside the 1.2 s warning),
  20% of clashes without an ult. The bot reads `LevelSim.ult_worth`, so the boss hold applies to it automatically.
- **Calibrate `CASUAL_SKILL`** once (`boss_check --calibrate`), against a **phase-matched** target: the skill at which the
  Run bot's first-try win rate on the non-boss levels 4-7 of worlds 1-3 (EXPECTED profile, 50 seeds each, Reinforcements
  off; 600 runs, one standard error ≈ 1.7 pp) equals the economy model's casual win rate for that phase ± 3 pp: **78% at
  phase 0** (Meta-1 reference casual, heroes §8.3 last row, `heroes_design.md:2398`) and **84% at phase 2** (casual
  greedy, `heroes_design.md:2389`). Write both values and the measured lines into `BossData`.
- Caveat, named so nobody over-reads the number: those targets are attempt win rates of an economy model over all levels
  (forced L1-3 wins and Reinforcements included), not a measured steering skill. Therefore:
  1. `boss_check --curve` publishes, per boss, the win rate at skill 0.4, 0.5, 0.6, 0.7 and 0.8, so the owner sees how
     sensitive each boss is to the skill guess;
  2. an optional human calibration (owner question §12 Q13): 20 first tries on levels 4-7 by a casual player, logged by
     `MetaTelemetry`; the bot's skill is then fitted to that win rate instead.
- C1 then plays every boss level 50 seeds per hero at that skill (pass rule in C1). Reference points: at today's
  `BOSS_DEMAND` the economy models already predict the casual boss win in the worst world at 74% at Meta-1
  (`heroes_design.md:2398`; arsenal's own run says 72%, `arsenal_design.md:1309`) and 80% with heroes
  (`heroes_design.md:2389`). The owner's bar is stricter, so expect C1 to ask for easier bosses from W5 on; §5.5 says what
  happens then.

#### 5.5 Difficulty equivalence and TEAM_DEMAND (C3)

- New mode `demand_bake --boss` (`scripts/dev/demand_bake.gd`): for each boss level, bisection on `m` (as `demand_bake`
  does for the team, `demand_bake.gd:1-20`) so that the planner's win margin on a **plain** build of that level
  (`LevelGen._build` without the arena) × `m` (`LevelGen.scale_enemies`) equals its margin on the boss build. Target
  `m_boss = BOSS_DEMAND[w] ± 0.03`; that is what `economy_sim.py` and `heroes_sim.py` already assume for bosses
  (`tools/economy_sim.py:100-104`), so the economy numbers stay true.
- **C1 overrides C3.** If meeting C1 drives `m_boss` below `BOSS_DEMAND[w] − 0.03`, keep the C1 tuning, write the measured
  `m_boss` into `economy_sim.BOSS_DEMAND`, re-run `economy_sim.py` and `heroes_sim.py` (pace, Star Ore, Beacons, loss
  streaks) as part of the gate, and report the changed numbers to the owner (§12 Q15). Nothing ships with C1 red and C3
  green.
- `TEAM_DEMAND` (`TeamData.TEAM_DEMAND`, heroes §8.2) was baked with samples at level-in-world 2, 4, 6, **8**
  (`demand_bake.gd:27`, `:30`), so the boss changes one of four samples per world. After bosses land, re-run the H2 bake
  (`--pos=2,4,6,8 --inv_fix=1`) and report the per-world delta; adopt only with the lead's OK. If the boss samples alone
  sit more than 0.04 away from their world's value, report it; a boss-only multiplier needs the owner's yes.
- `LevelGen.team_demand` (`level_gen.gd:133-137`) applies to the boss through `scale_enemies`: fortress value (boss hp)
  and strike caps. Rewards (key-gate values, recruits) and the key-gate `need` are not scaled, as today.

#### 5.6 Phase 0 vs heroes phases

| | Phase 0 (shipping, `HEROES_PHASE = 0`, `econ_data.gd:52`) | Heroes phase 2 dev / 3 live (`econ_data.gd:53-57`) |
|---|---|---|
| Hero | Meta-1 rows (`Balance.HEROES`, `balance.gd:51-74`); bolt, titan, seer on every boss | v3 kits through `HeroKinds`; seer from W3 |
| Ult policy | the shared boss hold (§3.4) over the Meta-1 policy | the shared boss hold over the v3 policy |
| Champions | none | fight in the siege as today (`run.gd:2671-2690`); idle in the standoff; the blow reaches them only through Block |
| Boss hp | as calibrated (§5.2) | × `TEAM_DEMAND` of the world |
| Rewards | Meta-1 bundle (§6) | + Beacons, Grand Hero Chest, Tomes, Star Ore, trophy (`rewards.gd:281-313`, live only) |
| Flag | bosses depend on `BossData.LIVE` only, not on the heroes phase | same |

#### 5.7 KIT_INDEX and champions

- **Champion `KIT_INDEX` / `KIT_P0`** are measured on `P0_SPREAD` = levels 15, 19, 23 and so on to 111 (`from 15, step 4`,
  `scripts/dev/test_champion_twists.gd:44`). Every one is odd, so **no boss level is ever sampled**: boss rules cannot move
  the twist budget. Keep it so: `test_boss` asserts that `P0_SPREAD` contains no `ArsenalData.is_boss` level, and any new
  kit spread must skip boss levels (side content rule: mode rules stay out of `KIT_INDEX`, `side_content_ideas.md:749`).
- **Hero `KIT_INDEX`** is the sim's power index (`tools/heroes_sim.py:2077-2101`, `hero_index_t`), not LevelSim, so the
  boss does not touch it.
- **Kit dependence, named.** The stagger rule and the boss ult hold are the same for every hero kind; kinds differ in how
  often the ult is ready, which is their budgeted ult charge. Two kit effects remain and are bounded on purpose: titan's
  quake armour halves strike caps instead of erasing them (§3.2), and titan's guard row never fires on a strike (§3.4).
  Scrape Guard and the titan rally count phase 1 as one contact (§3.1). C1 reports the spread between starters per boss
  (≤ 10 pp).
- **Guardians** gain one extra use on boss levels (a ready Block absorbs the blow through `absorb_hazard`); Healers trim
  the blow like any hazard. Both are class behaviour, inside the templates, and outside the KIT spread.
- **Front champion survival** on boss levels (40-60%, `champ_survival.gd:32-33`) is re-measured (C7). The exchange is
  unchanged and the standoff has no exchange, so the front's share of clash hits barely moves; the blow does not hit
  champions directly.

---

## 6. Нагороди

### Коротко

За боса не з'являється нічого нового, крім титулу. Усе інше вже задумано й навіть уже прив'язано до восьмих рівнів:

| Нагорода | Коли | Де вже є |
|---|---|---|
| Світова схованка (замість Кам'яної) | перша перемога | працює зараз |
| Ядро боса | **лише перша перемога** (14 за всю гру) | працює зараз, але дається й на повторах; виправити |
| +2 Маяки | перша перемога, коли відкрито Портал | задумано для героїв |
| Велика скриня героїв | перша перемога, коли відкрито чемпіонів | задумано для героїв |
| +1 Том | перша перемога, коли відкрито навички | задумано для героїв |
| 14 Зоряної руди (вночі 20) і трофей | перша перемога, коли відкрито Майстерню | задумано, ще не в коді |
| Лічильник перемог над босами для героя | кожна перша перемога | працює зараз |
| **Титул за першу перемогу** | перша перемога (нічний титул — питання 14) | нове, лише прикраса |

«Слава» героя (зірочки за босів) була задумана, але нова система героїв її скасовує й переводить у Зоряну руду. Тому
окремо Славу боси не дають; лічильник «перемог над босами з цим героєм» лишається й видно на картці боса.

Титули (короткі фрази, щоб пасували будь-кому): «Гроза Змія», «Сухі ноги», «Вірна стежка», «Зламані роги», «Весна прийшла»,
«Тиха днина», «Лиха не знати». Титул можна обрати в профілі, він показується під іменем. Сили не дає.

### For developers

| Reward | Code today | Change |
|---|---|---|
| World Cache on a first-clear boss win | `EconData.win_cache` (`econ_data.gd:415-419`), booked in step 6 only `if won and not replay` (`rewards.gd:154-158`); test `test_meta.gd:573` | none |
| Boss Core | `result.boss_core = 1` on **any** boss win (`run.gd:3014`); booked whenever set, replays included (`rewards.gd:147-148`, outside the `not replay` block at `:137`) | **book only on a first clear** (arsenal: "14 in a full pass", `arsenal_design.md:652`; `rewards.gd:147` moves inside `if not replay`). Today replays of level 8 are rare (no level select yet), but level select is coming (side content "Двійник характерника") |
| Boss wins, per hero | `progress.boss_wins`, `heroes.<id>.boss_wins`, Feat `bosses_beaten` (`rewards.gd:140-146`, `econ_data.gd:233`) | none |
| +2 Beacons | `PortalData.BEACON.boss = 2` (`scripts/core/portal_data.gd:26`), `rewards.gd:294-295` (live only) | none |
| Grand Hero Chest | `rewards.gd:312-313` (live only) | none |
| Tomes +1 | `PortalData.TOMES_BOSS` (`portal_data.gd:61`), `rewards.gd:298-301` | none |
| Star Ore 14 / 20, trophy | heroes §3.4 (`heroes_design.md:455-466`), §7.6 (`:2302-2311`), `heroes_sim.py:289-304`; `GearData` / `gear_data.gd` **not found** (H4) | trophies get boss provenance names («Трофей: Водяник / Trophy: the Vodyanyk») instead of the placeholder «Кракен» (`heroes_design.md:1512`) |
| Glory ◆ | Meta-2 data `GLORY_AT_BOSS_WINS` (`econ_data.gd:91`), set by the v2 migration (`save.gd:359-363`); **retired** by heroes v3 (`heroes_design.md:145`), converted to Star Ore (`save_v3_data.gd:46-47`) | do not revive; show "bosses beaten with this hero" instead |
| Interim "every 8th fortress counts as the boss" | `arsenal_design.md:655-656` | retired by the real bosses |
| First-win title | **not found** (no title system: `scripts/ui/hub/profile_card.gd`, `econ_data.gd` have none) | new `titles` save section (§9), cosmetic only, granted in `Rewards.level_end` on a first clear; a night variant `TITLE_NIGHT` if the owner says yes (§12 Q14) |

Replays (once level select exists) follow the replay rules (`EconData.REPLAY`, `econ_data.gd:179`): 60% coins, Stone Cache
within the daily 3, no core, no title, no Beacons.

---

## 7. 3D: заглушка і контракт моделі

### 7.1 Заглушка, поки нема моделі (коротко)

Порівняли чотири варіанти:

| Варіант | Як виглядає | Скільки коштує | Ризик |
|---|---|---|---|
| А. Мальована фігура з картки за стіною фортеці | ваша картка (вирізана, як картки чемпіонів) стоїть над стіною, видно від голови до пояса, як велетень за мурами; код лише трохи її нахиляє й струшує | нуль нових картинок: картка потрібна однаково для екрана боса | картку малюють знизу й збоку, а камера бою дивиться згори й ззаду, тож плоска фігура може читатися як наліпка; бос стоїть за стіною, а не виходить назустріч |
| Б. Мальована фігура з фронт-листа перед ворітьми | вирізаний фронт-лист стоїть на мосту перед ворітьми на весь зріст, без ракурсу знизу | нуль нових картинок: лист потрібен однаково для Meshy | поза на листі — А-поза з порожніми руками, тож фігура виглядає як манекен; рухи лише легкі нахили |
| В. Збільшений рядовий Жаророгий | наш вартовий орди, збільшений у 4-5 разів, з короною й рогами з простих форм | лише код | у великому розмірі видно грубу геометрію й розмиту текстуру, і всі сім босів однакові |
| Г. Чекати моделей | — | — | боси з'являться лише з останньою моделлю |

Що раджу: щойно буде перша картка й перший фронт-лист, я зроблю знімки А, Б і В на справжній камері бою на телефонному
екрані й покажу вам. Оберете те, що не схоже на наліпку (питання 2). Гравці побачать або обрану заглушку, або модель.

### 7.2 Контракт моделі для власника (Meshy)

**Що робите ви:** картка (§11 «a») → фронт-лист (§11 «b») → бік + спина (§11 «b2», той самий чат, потім розрізати
навпіл) → Meshy «Multi-image to 3D» з трьох листів (фронт, бік, спина) → Remesh → Rig → анімації → GLB. Лист «бік +
спина» потрібен, щоб Meshy не вигадував спину: її видно в кліпах `defeat` і `walk`. Пропи (весло, ліхтар, булава,
палиця) — окремі моделі без ригу.

| Що | Значення |
|---|---|
| Трикутники | ціль **18 000** (не більше 20 000); Remesh: Triangle |
| Текстура | одна, base colour; завантажуйте як дає Meshy (2K-4K), я зменшу до 1024² |
| Матеріал | один |
| Риг | Humanoid у Meshy; маркери: підборіддя, зап'ястя, лікті, коліна, пах |
| Не позначати | крила, хвіст, бороду, плащ, вуаль, шарф, ланцюги |
| Як рухаються крила, хвіст, плащ | **жорстко, разом із тілом.** Інструмента, що оживляє такі частини окремими кістками, у грі поки нема. Meshy сам прив'яже їх до найближчих кісток; я перевірю модель у переглядачі, і якщо крило тягнеться за рукою, перев'яжу його до спини окремим кроком (до години на боса) |
| Висота в грі | ≈ 7,5 одиниці (у 10 разів вищий за солдата); масштаб у файлі не важливий |
| Пози | листи в A-позі, руки порожні |
| Спроби | до 3 на модель; якщо «попливли» руки чи обличчя, краще перегенерувати лист |
| Назва файлу | `<id>.glb` (наприклад `zmii.glb`), пропи `<id>_prop_<назва>.glb` |
| Проп | ≈ 2 500 трикутників, без ригу |

**Кліпи** (назви для Godot; пресет Meshy беріть найближчий, перейменовувати не треба, лише напишіть, що є що):

| Кліп | Пресет Meshy (найближчий) | Тривалість | Цикл | Що відбувається |
|---|---|---|---|---|
| `idle` | Idle / Breathing Idle | 2.4 с | так | важко дихає, озирається на міст |
| `throw` | Throw / Overhand Throw | 0.8 с | ні | звичайний удар: кидок униз на міст |
| `signature` | за босом (таблиця нижче) | 1.0-1.6 с | ні | свій удар |
| `blow` | Heavy Attack / Ground Slam | 1.6 с | ні | Великий удар: 1.2 с замах, 0.4 с удар (я розріжу) |
| `hurt` | Hit Reaction | 0.4 с | ні | короткий здриг від влучання |
| `phase` | Roar / Battle Cry | 1.4 с | ні | рик на початку ударів і коли ставить щит |
| `stagger` | Knockback / Stumble Back | 0.8 с | ні | ульта збила удар: відсахнувся |
| `defeat` | Dying / Kneel Down | 2.0-2.5 с | ні | падає на коліно або навзнак; останній кадр тримаю |
| `walk` (за бажанням) | Walking | 1.0 с | так | два кроки назустріч військові на початку бою |

Свій удар (`signature`) за босом:

| Бос | Пресет | Що відбувається |
|---|---|---|
| Змій | Spin Attack | обертається всім тілом; хвіст і крила йдуть за ним жорстко (окремий удар хвостом без кісток хвоста неможливий) |
| Водяник | Reach / Grab Pull | тягне руку вниз, ніби смикає під воду |
| Блуд | Wave / Beckon | маніть пальцем і хитає ліхтарем |
| Князь | Stomp / Ground Pound | б'є булавою в землю (лава — ефект) |
| Мара | Cast / Breath | широкий видих із піднятою долонею |
| Вихор | Spin / Dance Spin | обертається на одній нозі |
| Лихо | Look Around / Scan | повільно веде головою з краю в край |

Особливості ригу:
- **Змій** стоїть на задніх лапах: Meshy Humanoid ставить «ноги» на задні лапи, «руки» на передні. Крила на листах
  напівпідняті за спиною й ростуть зі спини (не розкинуті вбоки на висоті рук), щоб Meshy прив'язав їх до спини, а не
  до рук. Хвіст і крила не позначати.
- **Вихор**: ноги людської будови з коліньми вперед, у шерсті й з копитами (так у нових промтах), тож маркери ставте як
  звичайні. Смерч під ним гра малює окремо.
- **Мара, Водяник, Блуд**: довгий одяг розрізаний спереду, щоб було видно обидві ноги нижче коліна (так задумано в
  листах), інакше риг склеїть ноги.

### 7.3 For developers

- Loader `BossModels.art(id)` mirrors `HeroModels.art` (`scripts/core/hero_models.gd:603-670`): `res://assets/bosses/<id>/model.glb`,
  clips by name, loops `idle` and `walk`, props on bones like `HeroModels.ART_PROPS` (`hero_models.gd:613`). Import:
  `node tools/prepare_model.mjs in.glb out.glb 18000 1024 512` then `tools/import_model.sh out.glb assets/bosses/<id>/model.glb`
  (headers `tools/prepare_model.mjs:1-8`, `tools/import_model.sh:1-6`). Run material: one matte material with the run's rim,
  as heroes (heroes §10.3); `prepare_model.mjs` drops the metal/roughness map (`prepare_model.mjs:9`), so baked specular
  hotspots in the albedo would look wrong: the prompts forbid them (§11). No gem hex in code (the jade lives in the
  texture, see `test_run_palette` scan, `scripts/dev/test_run_palette.gd:29-38`).
- **Rule: tails, wings, cloaks and veils stay rigid unless a bone tool exists.** The pipeline cannot add bones:
  `prepare_model.mjs` only simplifies and resizes, `import_model.sh` only imports textures, and `hero_models.gd` only poses
  the humanoid's named bones (`set_bone_pose_rotation`, `:360-361`); `SpringBoneSimulator3D` appears only in the heroes
  design (`heroes_design.md:1072`), **not found** in code. Meshy's humanoid auto-rig weights unmarked wings and tails to
  the nearest arm, spine and leg bones. Remedy when a wing stretches with an arm: re-weight it to the spine in Blender
  (Blender on the owner's PC: not checked; about 1 h per boss, done on our side). Hence Змій's signature is a whole-body
  spin, not a tail whip.
- **Placeholder tiers** (`BossView`), all three rendered by T13 at the siege camera (`run.gd:3232-3247`: it looks down
  ~27°, direction (0, 6.6, 12.8)) before the owner answers Q2:
  - `billboard_card`: `assets/bosses/<id>/card.png` (cut-out of the card with `tools/art/cutlib.py` as for champion
    cards, CLAUDE.md "Cut-out"), a Y-billboard quad 7.5 u tall tilted to the camera pitch, alpha scissor, drawn above
    the fortress wall with the feet hidden behind it (the card is framed to mid-thigh). The card is painted from ~15° below
    facing the lower left, so code motion is limited to small tilts (≤ 6°) and the 0.1 s `hurt` shake; no squash, no
    sink, no lean-back (they read as a flat sticker). The boss stays behind the wall in this tier.
  - `billboard_sheet`: the front sheet (b) cut out, full body, standing in front of the gate (`FORT_BACK`), no upward
    perspective; same motion limits. It shows the A-pose with empty hands.
  - `sentinel` (dev only unless the owner picks it): the owner's Emberhorn Sentinel `assets/units/emberhorn/emberhorn_src.glb`
    (measured: 1 800 tris, 28 joints, one clip "Running", 512² albedo) or its VAT bake
    (`assets/units/emberhorn/emberhorn_vat.json`: clips run, attack, idle, death; `VatClip.EMBER`, `scripts/run/vat_clip.gd:21-34`)
    drawn as a one-unit `CrowdView` scaled to 7.5 u, plus a procedural horned crown and cape from `Models` primitives.
  - Order at run time: model, else the tier the owner chose, else `sentinel` in dev builds; `test_boss` fails a release
    build that would show a tier the owner did not choose.
- Phone budget: the boss adds ≤ 1 skinned mesh (≤ 20k tris, 1 material, 1024² ETC2) + ≤ 1 prop; inside the heroes §10.6 gate
  for the worst 10 s, which already names "boss siege" (`heroes_design.md:2739`).

---

## 8. Інтерфейс і тексти

### 8.1 Картка боса (перед боєм)

- Відкривається двома шляхами:
  - гравець торкається вузла боса на мапі: кнопки «До бою» (порцелянова) і «Пізніше»;
  - гравець тисне «Грати» на рівні боса: лише «До бою» і хрестик «закрити» (без «Пізніше», бо вибору рівня ще нема і
    «пізніше» вело б у нікуди).
- Перша зустріч із босом — уся картка; далі одразу бій, а в бою коротка табличка з іменем на 1,6 с. Нічна зустріч
  (Навала) — питання 14.
- Склад: велика мальована картка боса (3:4) з ім'ям у лівому верхньому куті; під нею одним рядком прізвисько; 1-2
  рядки історії; рядок «Його удари» з трьома значками (звичайний удар, свій удар, Великий удар) і одним реченням до
  кожного; рядок «Нагорода» (лише те, що вже відкрито в цій грі); «Перемог над босами з цим героєм: N».
- Стиль: порцелянове скло, тонка золота лінія в 1 піксель, зрізані під 45° кути, один шрифт, без обводки тексту.

For developers: hub modal `scripts/ui/hub/boss_card.gd` (UI v3 modal, `docs/design/ui_v3_spec.md` §7.1: frosted body, 1 dpx
gold + 1 dpx light frame, chamfer 12; CTA §7.6), opened from `TabPlay._on_node` (`tab_play.gd:285-288`, replaces the toast)
with both buttons, and before the run on a boss level with «До бою» + close only; the run READY state shows a 1.6 s name
banner (reuse `HudView.pill_toast`, `scripts/ui/hud_view.gd:463`). "Seen" is kept per boss and per day/night
(`bosses.<id>.seen`, `.night.seen`, §9). It realises arsenal's planned threat preview "boss portrait"
(`arsenal_design.md:827`). Ask before large `scripts/ui/` changes while the cloud session is active (CLAUDE.md "State of play").

### 8.2 У бою: смуга здоров'я, частини бою, замки, відлік удару

- Під верхньою панеллю, по центру, 560 × 18 пікселів: ім'я боса над смугою; смуга темна, заповнення темно-кармінне;
  щит видно як світлий заштрихований шматок поверх (не блакитний, щоб не плутати з добрими воротами).
- Ліворуч від імені три маленькі ромби: удари, щит, бій. Світиться поточний (ромби з UI v3).
- Праворуч на смузі дві маленькі пластинки-замки; зламаний тріскається.
- Смуга з'являється з риком боса за 100 одиниць до нього; до того бос просто видніється вдалині.
- Число здоров'я над фортецею на рівні боса не показуємо (смуга замінює його).
- **Відлік Великого удару**: щоразу, на кожному босі, кнопка ульти отримує тонке кільце (1 піксель, без світіння), яке
  за 1,2 секунди замикається; бос у цей час помітно заносить зброю. Червоне коло під військом лишається, але воно
  другорядне: під 200 солдатами його погано видно.
- Короткі написи («Замок зламано!», «Щит упав!», «Удар збито!») стають у чергу з паузою щонайменше 0,8 секунди, щоб
  не налазили один на одного.

For developers: `scripts/ui/boss_bar.gd` in `HudView` (`hud_view.gd`, top bar `_build_top` `:112`), fed by `RunHud` from new
`Run` signals `boss_phase(i)`, `boss_hp(hp, hp0, shield)`, `boss_lock(left)`, `boss_blow(t_left)`. Tokens: `UITokens` v3
(`ui_v3_spec.md` §1): 1 dpx `LINE_GOLD` frame + `LINE_LIGHT`, chamfer 6, track ink glass, fill crimson `#9E1B22`, shield
hatch porcelain `#D9D4CC` at 45°. Diamonds `GemDraw.draw_diamond` (`ui_v3_spec.md:180`). The ult-button ring: 1 dpx
`LINE_GOLD` arc, progress = elapsed / `WINDUP`. Toast queue in `RunHud`, `TOAST_GAP` 0.8 s. The fortress label is hidden on
boss levels.

### 8.3 Підказки

- На першому босі (рівень 8), як і було:
  - Перед першим ударом (з риком): «Червоне поле: туди вдарить. Перейди на другий бік!»
  - Перед першими воротами-ключем: «Стріляй у ворота-ключ, щоб їх зарядити».
  - На початку бою, якщо ульта готова: «Тисни ульту, щоб збити удар!» (кільце-відлік на кнопці є завжди).
- **На кожному босі при першій зустрічі** — одна підказка до його власного удару, перед першим таким ударом (тексти в
  §8.5, ключі `HINT_BOSS_<ID>`). Так гравець, що не читав картку, не зустріне вир, лаву чи погляд наосліп.

For developers: `LevelGen._hint` (`level_gen.gd:1005`): on L8 the three keys; on each boss level `HINT_BOSS_<ID>` at the
first signature event's warning d − 6 (the hint fires once per key, `g.shown`, `:1006-1008`); icons via
`HudView.HINT_ICONS` (`hud_view.gd:19-24`).

### 8.4 Перемога і поразка

- **Перемога** (≈ 2 с перед звичним кінцем): бос падає, з нього вилітає Ядро (лише перший раз) і летить угору екрана,
  великий напис «Зоряного Змія подолано», далі фортеця розвалюється і сходи.
- **Екран результату** йде звичним порядком, нове лише одне коротке речення:
  1-5. як зараз (монети, сходи, статистика, залп, нагороди летять до вкладок);
  5c. Ядро боса летить у кільце Ковадла (лише перша перемога, до 1,5 с);
  5c+. рядок «Новий титул: Гроза Змія» (0,6 с, просто рядок, не окреме відкриття);
  5d. позначки завдань;
  6. одне «відкриття» на екран, як і зараз: пріоритет — сценарна скриня, потім Велика скриня героїв, потім скриня
     героя, потім Кам'яна схованка; Світова схованка ніколи не відкривається тут, лише кнопками «Відкрити на вівтарі» /
     «Пізніше».
- **Поразка**: звичний екран поразки плюс одна порада за тим, що забрало найбільше солдатів: удари, цілий щит чи
  Великий удар (усе рахуємо в солдатах).

For developers: result order = arsenal §7.3 steps 1-5, 5c (`arsenal_design.md:1460`), the title line (new, a text line like
5d), 5d, 6 (`arsenal_design.md:1462`), with the one-inline-reveal rule and its priority (`heroes_design.md:2299-2300`).
Loss tip: compare `strike_deaths`, `shield_cost` = shield hp left at contact (the siege trades 1 hp for 1 soldier, so it
counts as soldiers) and `blow_deaths`; the largest picks `BOSS_TIP_STRIKES`, `BOSS_TIP_LOCKS` or `BOSS_TIP_BLOW`.

### 8.5 Тексти (uk / en) і ключі Loc

Правила: жодних трьох крапок (ні окремим символом, ні трьома знаками); числа лише через `%d` / `%s` (heroes §12.4, `loc_lint`); «ворота», а
не «брама», як у чинних підказках (`scripts/autoload/loc.gd:62-65`); «солдати» в бою, як `HINT_CHAMPION` (`loc.gd:1360`).
Слово «печатка» не вживаємо (це валюта Порталу, heroes §7.4), тому в щита «замки». Імена босів перевірено: у `loc.gd`
таких немає; «Вихор шаблі» (`ATK_SIRKO_B9`, `loc.gd:865`) інша назва, конфлікту немає.

Імена, прізвиська, історії, удари, титули:

| Key | uk | en |
|---|---|---|
| `BOSS_ZMII` | Зоряний Змій | The Star Serpent |
| `BOSS_ZMII_ACC` | Зоряного Змія | The Star Serpent |
| `BOSS_ZMII_EPITHET` | Луска з небесного заліза | Scales of Sky-Iron |
| `BOSS_ZMII_LORE` | Зоряний Змій упав на міст разом із зорепадом і забрав собі все небесне залізо.\nКажуть, його луску не бере жодна стріла, але колись його здолав простий кожум'яка. | The Star Serpent fell onto the bridge with a meteor shower and claimed all the sky-iron for itself.\nThey say no arrow can pierce its scales, yet a simple tanner once beat it. |
| `BOSS_ZMII_VOLLEY` | Зоряні луски | Star Scales |
| `BOSS_ZMII_STRIKE` | Удар хвостом | Tail Lash |
| `BOSS_ZMII_STRIKE_DESC` | Хвіст б'є по одному боці мосту. Наступний удар піде по другому, тож перебігай. | The tail strikes one side of the bridge. The next strike hits the other side, so cross over. |
| `BOSS_ZMII_BLOW` | Кільця Змія | Serpent Coils |
| `HINT_BOSS_ZMII` | Хвіст б'є по одному боці. Наступний удар піде по другому! | The tail strikes one side. The next strike hits the other! |
| `TITLE_BOSS_ZMII` | Гроза Змія | Bane of the Serpent |
| `BOSS_VODIANYK` | Водяник | The Vodyanyk |
| `BOSS_VODIANYK_ACC` | Водяника | The Vodyanyk |
| `BOSS_VODIANYK_EPITHET` | Господар тихого виру | Lord of the Still Whirlpool |
| `BOSS_VODIANYK_LORE` | Водяник спить під старим млином на дні рифу й не терпить, коли по його воді ходять.\nХто зазівається, того він тягне у вир. | The Vodyanyk sleeps under the old mill at the bottom of the reef and hates anyone walking on his water.\nWhoever gapes, he pulls into the whirlpool. |
| `BOSS_VODIANYK_VOLLEY` | Мулисті брили | Mud Boulders |
| `BOSS_VODIANYK_STRIKE` | Вир | Undertow |
| `BOSS_VODIANYK_STRIKE_DESC` | Вир відкривається на твоєму боці мосту. Перебіжи на другий. | The whirlpool opens on your side of the bridge. Cross to the other. |
| `BOSS_VODIANYK_BLOW` | Хвиля | The Wave |
| `HINT_BOSS_VODIANYK` | Вир відкривається там, де ти. Перебігай! | The whirlpool opens where you are. Cross over! |
| `TITLE_BOSS_VODIANYK` | Сухі ноги | Dry Feet |
| `BOSS_BLUD` | Блуд | Blud |
| `BOSS_BLUD_ACC` | Блуда | Blud |
| `BOSS_BLUD_EPITHET` | Той, що водить манівцями | The One Who Leads Astray |
| `BOSS_BLUD_LORE` | Блуд водить манівцями: ворота в нього підморгують, а стежки звиваються.\nДивись уважно, бо його вогник завжди світить не туди. | Blud leads travellers astray: his gates wink and his paths twist.\nLook closely, because his little light always shines the wrong way. |
| `BOSS_BLUD_VOLLEY` | Блудні вогники | Wandering Lights |
| `BOSS_BLUD_STRIKE` | Двоїсті ворота | Two-Faced Gates |
| `BOSS_BLUD_STRIKE_DESC` | Двоє воріт по черзі стають то добрими, то поганими. Влучи в добрі. | Two gates keep swapping good and bad. Time it and take the good one. |
| `BOSS_BLUD_BLOW` | Морок | Gloom |
| `HINT_BOSS_BLUD` | Ворота міняються. Заходь у сині! | The gates keep swapping. Take the blue one! |
| `TITLE_BOSS_BLUD` | Вірна стежка | True Path |
| `BOSS_KNIAZ` | Князь Жаророгих | The Emberhorn Prince |
| `BOSS_KNIAZ_ACC` | Князя Жаророгих | The Emberhorn Prince |
| `BOSS_KNIAZ_EPITHET` | Володар орди | Lord of the Horde |
| `BOSS_KNIAZ_LORE` | Князь Жаророгих веде орду й досі лютує через листа, якого йому колись написав Сірко з усім військом.\nРоги в нього з лави, а терпіння ще коротше. | The Emberhorn Prince leads the horde and still fumes over the letter Sirko and his whole host once wrote him.\nHis horns are lava, and his temper is shorter. |
| `BOSS_KNIAZ_VOLLEY` | Вогняні брили | Fire Boulders |
| `BOSS_KNIAZ_STRIKE` | Лавовий струмінь | Lava Jet |
| `BOSS_KNIAZ_STRIKE_DESC` | Лава надовго заливає один бік мосту. Тримайся другого. | Lava floods one side of the bridge for a while. Keep to the other. |
| `BOSS_KNIAZ_BLOW` | Рогатий таран | Horn Ram |
| `HINT_BOSS_KNIAZ` | Лава тримається довго. Не повертайся на її бік! | The lava lasts. Don't go back to its side! |
| `TITLE_BOSS_KNIAZ` | Зламані роги | Broken Horns |
| `BOSS_MARA` | Морозна Мара | Frost Mara |
| `BOSS_MARA_ACC` | Морозну Мару | Frost Mara |
| `BOSS_MARA_EPITHET` | Подих довгої зими | Breath of the Long Winter |
| `BOSS_MARA_LORE` | Морозна Мара приносить довгу зиму: де вона дихне, там солдати стають крижаними.\nЇї проводжають щовесни, і вона страшенно цього не любить. | Frost Mara brings the long winter: where she breathes, soldiers turn to ice.\nPeople see her off every spring, and she hates it. |
| `BOSS_MARA_VOLLEY` | Крижані брили | Ice Boulders |
| `BOSS_MARA_STRIKE` | Подих Мари | Mara's Breath |
| `BOSS_MARA_STRIKE_DESC` | Мороз падає на той бік, де тебе нема. Не метушись і стій, де стоїш. | The frost falls on the side where you are not. Keep calm and stay where you are. |
| `BOSS_MARA_BLOW` | Хуртовина | Blizzard |
| `HINT_BOSS_MARA` | Мороз падає туди, де тебе нема. Стій на місці! | The frost falls where you are not. Stay put! |
| `TITLE_BOSS_MARA` | Весна прийшла | Spring Has Come |
| `BOSS_VYKHOR` | Вихор | The Whirlwind |
| `BOSS_VYKHOR_ACC` | Вихора | The Whirlwind |
| `BOSS_VYKHOR_EPITHET` | Танцюрист у вихорі | Dancer in the Wind |
| `BOSS_VYKHOR_LORE` | Вихор танцює над Небесною гаванню й розкидає загони, мов солому.\nКажуть, вихор стихає, коли в нього влучити, тож цілься добре. | The Whirlwind dances over the Sky Harbour and scatters squads like straw.\nThey say a whirlwind dies down when you hit it, so aim well. |
| `BOSS_VYKHOR_VOLLEY` | Каміння з вітру | Wind-Thrown Stones |
| `BOSS_VYKHOR_STRIKE` | Смерч | Twister |
| `BOSS_VYKHOR_STRIKE_DESC` | Смерч перебігає міст і крутиться біля других перил. Тікай туди, звідки він вилетів. | The twister crosses the bridge and spins by the far rail. Go where it came from. |
| `BOSS_VYKHOR_BLOW` | Порив | Gust |
| `HINT_BOSS_VYKHOR` | Дивись на червоне поле: смерч зупиниться там! | Watch the red field: the twister stops there! |
| `TITLE_BOSS_VYKHOR` | Тиха днина | A Calm Day |
| `BOSS_LYKHO` | Лихо Однооке | One-Eyed Likho |
| `BOSS_LYKHO_ACC` | Лихо Однооке | One-Eyed Likho |
| `BOSS_LYKHO_EPITHET` | Бачить крізь Розлом | Sees Through the Rift |
| `BOSS_LYKHO_LORE` | Лихо Однооке сидить у Розломі й бачить крізь нього все, що ми робимо.\nНе буди лиха, поки тихо, кажуть люди. Тепер уже пізно. | One-Eyed Likho sits in the Rift and sees through it everything we do.\nLet trouble sleep, people say. It is too late now. |
| `BOSS_LYKHO_VOLLEY` | Кам'яні брили | Rock Boulders |
| `BOSS_LYKHO_STRIKE` | Погляд | The Gaze |
| `BOSS_LYKHO_STRIKE_DESC` | Довгий погляд падає щоразу на інший бік, ніж попередній удар. Перебігай. | The long Gaze always falls on the other side from the last strike. Cross over. |
| `BOSS_LYKHO_BLOW` | Удар палицею | Club Smash |
| `HINT_BOSS_LYKHO` | Погляд падає на інший бік, ніж минулий удар. Перебігай! | The Gaze falls opposite the last strike. Cross over! |
| `TITLE_BOSS_LYKHO` | Лиха не знати | Trouble-Free |

Спільні тексти:

| Key | uk | en |
|---|---|---|
| `BOSS_VOLLEY_DESC` | Червоне поле на мосту: за мить туди вдарить. Перейди на другий бік. | A red field on the bridge: a strike lands there in a moment. Move to the other side. |
| `BOSS_BLOW_DESC` | Коли військо впирається в боса, він замахується на Великий удар. Тисни ульту, поки йде відлік. | When your army reaches the boss, it winds up a Great Blow. Hit your ult during the countdown. |
| `BOSS_LOCKS_DESC` | Щит тримають два замки. Заряди ворота-ключ пострілами героя й пройди крізь них. | Two locks hold the shield. Charge a key gate with your hero's shots and run through it. |
| `BOSS_STRIKES` | Його удари | Its strikes |
| `BOSS_REWARDS` | Нагорода | Reward |
| `BOSS_FIRST_WIN` | За першу перемогу | For the first win |
| `BOSS_WINS_HERO` | Перемог над босами з цим героєм: %d | Bosses beaten with this hero: %d |
| `BOSS_FIGHT` | До бою | To battle |
| `BOSS_LATER` | Пізніше | Later |
| `BOSS_NIGHT` | Ніч | Night |
| `BOSS_PHASE_STRIKES` | Удари | Strikes |
| `BOSS_PHASE_SHIELD` | Щит | Shield |
| `BOSS_PHASE_CLASH` | Бій | Clash |
| `BOSS_LOCKS_LEFT` | Замків: %d | Locks: %d |
| `BOSS_LOCK_BROKEN` | Замок зламано! | Lock broken! |
| `BOSS_SHIELD_DOWN` | Щит упав! | Shield down! |
| `BOSS_BLOW_BROKEN` | Удар збито! | Blow broken! |
| `BOSS_DOWN` | %s подолано! | %s falls! |
| `BOSS_CORE_PLUS` | Ядро боса +1 | Boss Core +1 |
| `BOSS_TITLE_NEW` | Новий титул: %s | New title: %s |
| `HINT_BOSS_STRIKE` | Червоне поле: туди вдарить. Перейди на другий бік! | Red field: a strike lands there. Move to the other side! |
| `HINT_BOSS_KEY` | Стріляй у ворота-ключ, щоб їх зарядити | Shoot the key gate to charge it |
| `HINT_BOSS_ULT` | Тисни ульту, щоб збити удар! | Hit your ult to break the blow! |
| `BOSS_TIP_STRIKES` | Найбільше втрат від ударів. Дивись на червоні поля й перебігай на другий бік заздалегідь. | Most losses came from strikes. Watch the red fields and cross to the other side early. |
| `BOSS_TIP_LOCKS` | Найбільше коштував цілий щит. Наступного разу заряди ворота-ключ. | The shield cost you the most. Next time charge the key gates. |
| `BOSS_TIP_BLOW` | Великий удар влучив. Тисни ульту, коли на кнопці йде відлік. | The Great Blow landed. Hit your ult while the button counts down. |
| `TITLES` | Титули | Titles |
| `TITLE_NONE` | Без титулу | No title |
| `TITLE_NIGHT` | %s · Ніч | %s · Night |

`BOSS_DOWN` takes `BOSS_<ID>_ACC` (Ukrainian needs the accusative: «Морозну Мару подолано!»). `TITLE_NIGHT` only if the
owner says yes to Q14. Existing keys stay: `BOSS`, `BOSS_LEVEL`, `WORLD_CACHE_HINT` (`loc.gd:385-387`), `CUR_CORE`
(`loc.gd:322`). `loc_lint.py` glossary gets the seven boss names, «Ядро боса», «замок» (shield) and «ворота-ключ».

---

## 9. Save and telemetry (for developers)

- Existing, unchanged: `progress.boss_wins`, `heroes.<id>.boss_wins` (`econ_data.gd:555`, `:592`), `wallet.cores`
  (`econ_data.gd:557`), `workshop.trophies` (`econ_data.gd:567`; heroes §12.1), Feat counter `bosses_beaten`.
- New sections, created by `EconData.fresh_account()` (`econ_data.gd:540-583`), filled by `sanitize()`, added to old saves
  by one migration step (side content rule: a new section comes with a migration step). Day and night are kept apart:
  ```
  bosses  {<id>: {seen: bool, wins: int, losses: int, first_t: int, best_s: float,
                  night: {seen: bool, wins: int, losses: int, first_t: int}}}
  titles  {owned: [title_id], shown: ""}
  ```
- Retro titles: an account whose frontier is past a boss level on update day gets that title quietly (no ceremony), so
  nobody loses out by having beaten the old fortress (owner question §12 Q6). Boss Cores are not re-granted (they were
  already booked). Retro accounts get `seen = true` for bosses already passed, so no card pops up for an old boss.
- `Run.result.stats` (fixed keys, arsenal §9.4, `arsenal_design.md:1767-1773`) gains: `boss_strike_deaths`, `boss_strikes_hit`,
  `boss_locks`, `boss_shield_cost`, `boss_blow_deaths`, `boss_blow_cancelled`, `boss_clash_s`, `boss_phase` (furthest phase
  reached).
- Telemetry (local only, `MetaTelemetry.note`, `scripts/meta/meta_telemetry.gd:103`): event `boss` with
  `{id, level, night, won, attempt, phase, strike_deaths, locks, shield_cost, blow_deaths, blow_cancelled, clash_s,
  army_at_boss, hero}`. It feeds the post-launch check of C1 (real first-try win rates per boss) and the optional human
  calibration (§5.4), never a network call.
- Rewards idempotency is unchanged (`run_id`, `rewards.gd:20-23`).

---

## 10. Test plan (for developers)

All Godot runs: headless where possible; windowed shots on the hidden desktop only, muted (`--audio-driver Dummy`), with
`--out` outside the repo and `--shots` given (CLAUDE.md "Screenshots"). `-- --autotest` keeps the save read-only.

| # | Test | Asserts | Gate |
|---|---|---|---|
| T1 | `test_boss.tscn -- --autotest` (new, headless) | BossData: 7 ids in world order, numbers in the §5.3 ranges; every Loc key of §8.5 exists in uk and en, no ellipsis, no digit next to `%`; LevelGen boss build: no procedural item at d > fd − 102 and the last one before the arena is not a squad / barricade / blade / turret; the roar ≥ 1 s before the first warning; five lines at the listed d, ≥ 10.5 u apart; no squad / blade / turret / crate / gate row inside phase 1 (Блуд: exactly one 2-gate row); every strike covers one side lane only and leaves ≥ `SAFE_MIN` 4.7 u free; the side rules (`lash` → other, `lane` / `twister` / `gaze` → same, `gaze` opposite to the previous); event 5's side known and the first key gate on the other side; two key-gate rows; deterministic (two builds equal); `scale_enemies` scales boss hp and strike caps only; `P0_SPREAD` holds no boss level | every commit touching bosses |
| T2 | `test_boss --rules` | warning starts at hero d = line − 8.8 and lasts ≥ 1.2 s; `aimed` / `away` sides follow `sign(hx)` and the hash tie rule; Блуд's faces follow the approach clock; caps hold; armour halves strike caps; strikes are invisible to `hazard_near` and the boss to `threat_ahead`; Scrape Guard spares once per phase; no wards on strikes or the blow; shield = 0.30 × hp0 at `SHIELD_AT`, a lock removes min(0.15 × hp0, shield left), nothing before `SHIELD_AT`; `PRE_CAP` keeps hp ≥ 0.5 × hp0 until contact; the standoff lasts 1.2 s with no exchange; **exactly one blow per clash**, cancelled by a cast in its warning or within 2.5 s before it lands; the ult policy holds from the roar and fires in the warning; **on every boss level × starter hero × phase, the reference player (skill 1) reaches contact with a ready ult and cancels the blow** (a level where the ult is not ready is reported with its numbers); clash length within C4; each starter at the EXPECTED profile flips both key gates at skill 1; finale 3 s unchanged | same |
| T3 | `test_boss --parity` | Run (headless, fixed path, bot skill 1.0) vs `LevelSim.simulate` on each boss level × bolt / titan / seer, plus one case with max Barracks (Scrape Guard 10) and one titan case with the quake in phase 1: same outcome 10/10, strike deaths ±10%, a perfect dodge at the widest blob loses ≤ 1 soldier in both, locks equal, blows landed equal, clash time ±0.3 s; two Runs and LevelSim pick identical Блуд faces and `aimed` / `away` sides (C6) | before `LIVE` |
| T4 | `test_boss --rewards` | first clear: World Cache, exactly 1 core, title, `boss_wins` +1; replay: no core, no title, Stone Cache rules; live phase: +2 Beacons, Grand Hero Chest, Tomes after skills; retro migration grants titles and `seen` only; night wins go to `bosses.<id>.night` | same |
| T5 | `boss_check.tscn -- --autotest --calibrate` (new) | finds `CASUAL_SKILL` per phase (§5.4: 78% at phase 0, 84% at phase 2, 50 seeds × 12 levels); prints `BOSS_CHECK_CALIBRATE phase=<p> skill=<s> win=<pct>`; `--curve` prints the win rate per boss at skill 0.4-0.8 | once, then on bot changes |
| T6 | `boss_check -- --autotest --levels=8,16,24,32,40,48,56 --seeds=50 --profile=expected` | C1 at phase 0 (bolt, titan, seer on all seven) and `--phase=2` (scripted team; seer from W3): the pooled point estimate ≥ 0.80 and Wilson 90% lower bound ≥ 0.70 per boss, every hero ≥ 0.72, starter spread ≤ 10 pp; C2 with `--bot=lazy`; C4 timings and one blow per clash; prints one `BOSS_CHECK` line per (level, hero, phase) with wins, n, Wilson bound, and a summary. Runtime ~4 h single process: run 4-6 headless processes | before `LIVE` |
| T7 | `boss_check --night` (levels 64-112) | C1n (the owner's choice in Q5), same pass rule | before night bosses ship |
| T8 | `demand_bake -- --autotest --boss=1` | C3: `m_boss` within `BOSS_DEMAND[w] ± 0.03`, or, where C1 forced it lower, the economy re-run and the owner report (§5.5); then the H2 re-bake delta report | before `LIVE` |
| T9 | `champ_survival` | C7: front 40-60% on boss levels, side / rear ≥ 90% | heroes phase gates |
| T10 | existing suites | `test_meta` (boss L8 World Cache `test_meta.gd:573`, cores `:681`, `:694`), `test_heroes` (Beacons `test_heroes.gd:1963-1970`), `test_heroes_ui`, `test_loc`, `test_kinds`, `test_juice`, `loc_lint`, `gen_heroes_data --check`, `gen_save_v3_data --check`, odds `--diff` / `--check`, autotest L1-2 | every push |
| T11 | `hud_lab --gate-legibility` on L24 (Блуд's two-faced row) and every key-gate row | C5: labels ≥ 3:1 while telegraphs are drawn | before `LIVE` |
| T12 | `test_run_palette` with the boss card cut-outs (**before any Meshy work**), then the models, added to the pixel set; plus the strike telegraph colours | ≥ 90% of boss pixels ΔE2000 ≥ 10 from every gate and pickup colour (`test_run_palette.gd:1-30`); the cracks (#C2410C, ΔE2000 12.9 from the bad-gate field) and the crimson (#B81A17, 15.7) checked under the run's tonemap, not only in sRGB; ember pixels stay below the glow threshold (no bloom); `STRIKE_FILL` / `STRIKE_RIM` ≥ 10 from the bad gate | before `LIVE` |
| T13 | Shots: new `scenes/dev/gallery_boss.tscn -- --out=<dir> --shots=<list>` at 720×1280 | `intro_<id>`, `bar_p1`, `bar_p2_locks`, `bar_p3`, `strike_<id>` (the frame where the telegraph is half full), `key_gate`, `blow_warn` **at full army** (the ult-button ring and the boss wind-up must read; the ground disc is secondary), `stagger`, `defeat_<id>`, and at the siege camera `billboard_card_<id>`, `billboard_sheet_<id>`, `sentinel_<id>` for the owner's Q2; uk and en; look at every shot zoomed at edges, the telegraph rim, the cut-out hair and wings, and the HUD bar corners before showing the owner | before showing |
| T14 | Phone bench | C8 with the heaviest boss model in | before `LIVE` |

Ship order: (1) BossData + BossRules + LevelGen arena + LevelSim + the shared ult rule, with the placeholder tiers; T1-T4.
(2) T5-T8 green on all seven bosses (cards exist by then). (3) UI (card, bar, ring, ceremony) + T11-T13; the owner picks
the placeholder (Q2). (4) `LIVE = true`. (5) Meshy models replace placeholders one by one; T12-T14 per model.

---

## 11. Арт-промти (Gemini)

### 11.0 Загальне

- Інструмент: Gemini «Nano Banana Pro» у тому ж чаті, де робили героїв, або `crystal-rush/tools/art/gemini_image.py`
  (ваш ключ, кожна пачка з вашого дозволу). Прикріпіть `style_anchor.png` (еталон стилю, `heroes_prompts.md` §1.1).
- Порядок для кожного боса: **(a) картка** → затвердили → **(b) фронт-лист** у тому ж чаті з карткою як референсом →
  **(b2) бік + спина** у тому ж чаті (16:9, потім розріжте навпіл) → (c) проп, якщо є. Один чат на боса.
- Перевірка перед відправкою (30 секунд): фон рівний сірий без підлоги й тіні; лівий верх порожній (картка); жодного
  світіння, вогню, диму, іскор; жодних літер і рун, схожих на літери (урок Менгіра); камінь лише один і темно-нефритовий;
  немає білої емалі й золота; немає крові й черепів; усе матове: немає глянцевих відблисків, мокрого блиску й
  «лакованих» поверхонь (гра малює моделі матовими, і відблиск, намальований на текстурі, виглядає брудом); на листах
  видно обидві ступні, руки порожні.
- Куди класти: оригінали `art_src/bosses/<id>/<id>_card_src.jpg`, `<id>_sheet_front_src.jpg`, `<id>_sheet_side_src.jpg`,
  `<id>_sheet_back_src.jpg`, `<id>_prop_<назва>_src.jpg`;
  у грі `assets/bosses/<id>/card.png` (вирізаю я). Назви файлів від вас будь-які, я впізнаю боса сам.
- Якщо генератор щось проігнорував, не правте промт, а напишіть у тому ж чаті одне уточнення:
  `Remove all glow, fire, smoke and sparks; change nothing else.` ·
  `Keep the upper-left 33% x 35% of the canvas empty flat grey; change nothing else.` ·
  `Make the only gemstone a single deep jade-green stone; remove every other crystal; change nothing else.` ·
  `Remove all letters, runes and symbols; change nothing else.` · `Show both feet fully; change nothing else.` ·
  `Make every surface matte and remove all glossy highlights; change nothing else.`
- **Де ці промти на телефоні.** Поки що лише в цьому файлі. Сторінка промтів, яку ви відкриваєте з телефона, збирається
  тільки з `heroes_prompts.md`. Перед тим як ви почнете, я перенесу §11 у розділ «Боси» в `heroes_prompts.md` (або навчу
  сторінку читати й цей файл), перебудую її й перевірю, що змінилося лише потрібне.
  For developers: `tools/art_prompts/build.py` reads only `docs/design/heroes_prompts.md` (`build.py:10`) and only
  `art_src/heroes` (`build.py:69`, `RECEIVED` `:70`); the CLAUDE.md install routine has no boss path. Do the move (or a
  second source plus `art_src/bosses`) in one commit with the page rebuild, then `git diff --stat`.

---

### 11.1 Зоряний Змій `zmii`

**(a) Картка боса (3:4, до середини стегна)** — `zmii_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no sky, no floor, no ground shadow.
- One single creature. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; menacing and majestic, never gory, never cute.
- Anatomy: a plausible, powerful creature with believable weight and musculature. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no glow, no fire, no breath, no smoke, no sparks, no particles, no light rays, no motion trails); the game adds every effect itself.

CREATURE - a giant winged serpent-dragon inspired by the winged serpent of Ukrainian folk tales, a chieftain of a fictional fire horde, whose scales are forged from fallen star-iron
- Body: standing upright on two powerful hind legs like a rearing lizard, a long sinuous neck, a long muscular tail; front legs with four strong clawed fingers used like arms.
- Head: ONE head only; long armoured jaw with sharp teeth, two swept-back black horns, a bony brow ridge; eyes with matte ember-orange irises that do not glow.
- Scales: large overlapping plates of dark meteoric star-iron, gunmetal grey-black with a fine silvery cross-hatched etched pattern and crisp satin edges; the throat and underbelly in deep crimson satin-matte plates (#B81A17, shadows #6B0D0F); aged dark bronze ridges along the spine (#C7732E); thin deep ember-orange crack lines (#C2410C) between the scale plates, painted as matte colour like cooling embers seen in daylight.
- Wings: two large bat-like wings with deep crimson membranes and black obsidian finger-bones (#16131A), half raised behind the body.
- Tail: ending in a heavy club of star-iron capped with dark bronze.
- Gemstone: ONE single deep jade-green satin-finish cabochon (body #1E7A55, shadows #0C3B28), about 3% of the figure height, set in a dark bronze mount on the brow between the horns. It does not glow.

COLOR LOCK
- Palette: dark star-iron grey-black, deep crimson, black obsidian, aged dark bronze, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: rearing up and lunging toward the lower left, head lowered toward the viewer with the jaw open in a silent roar (no fire), front claws spread, wings half raised behind, the tail curling around the right side of the image.
- Camera low at the creature's waist height looking up about 15 degrees so it towers over the viewer; long lens, little perspective distortion.
- Framing: from the tips of the horns and wings down to mid-thigh of the hind legs; the figure continues off the bottom edge. The whole head and the horns stay inside the frame with a margin of at least 4% of the image height.
- The creature stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the head, claws, horns or wing tips inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, more than one head, extra limbs, extra wings, deformed claws, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, glowing eyes, fire, fire breath, flames, lava light, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, cute or comic look, blood, gore, wounds, skulls, bones, flags, banners, emblems or insignia of any real army, state or party, political or religious symbols, crosses, tridents, crescents, star-shaped symbols, white enamel, polished gold filigree, any resemblance to a creature or character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `zmii_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
ступні видно, кігті порожні, крила напівпідняті за спиною й відділені від рук (не розкинуті вбоки), хвіст видно між ногами.

```
Create ONE creature reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CREATURE
- Exactly the same creature as in the attached reference image (the approved card): the giant winged serpent-dragon standing upright on two hind legs, one horned head, dark meteoric star-iron scales with a fine silvery cross-hatched pattern, a deep crimson satin-matte throat and underbelly (#B81A17), dark bronze spine ridges (#C7732E), thin matte ember-orange cracks between the plates, bat-like wings with deep crimson membranes and black obsidian finger-bones, a long tail ending in a bronze-capped star-iron club, and one deep jade-green stone (#1E7A55) on the brow between the horns.
- Same head, scales, colours and materials as the reference; nothing added, nothing removed.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from the horn tips to the hind feet, both hind feet fully visible, centred; the body fills about 85% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: standing upright on the straight hind legs, feet slightly apart and pointing forward; the front limbs held like arms, straight, angled about 40 degrees down and away from the body; claws open and EMPTY, fingers together, clearly separated from the body.
- Wings half raised behind the back, symmetrical, their roots on the spine above the shoulder blades; the membranes point up and back and are clearly separated from the front limbs; never spread out sideways at arm height.
- The tail hangs straight down behind the body to the ground and its end curls forward, visible between the hind feet, touching nothing else.
- Head straight, looking forward, mouth closed, eyes open.

RENDER
- The same painterly game-art style as the reference, presented as a clean creature turnaround for a 3D artist; plausible powerful anatomy; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no fire, no smoke, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, folded wings fused to the body, wings spread out to the sides at arm height, a held object, cropped feet, side or three-quarter view, perspective distortion, dramatic lighting, glowing eyes, fire, smoke, floating parts, more than one head, extra limbs, background objects, glossy highlights, specular hotspots, wet shine, text, letters, watermark.
```

*(b2) Бік + спина для Meshy* — `zmii_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `zmii_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `zmii_sheet_side.png`, права → `zmii_sheet_back.png`. Перевірте: в обох видах одна голова, крила напівпідняті за спиною, хвіст видно цілим.

```
Create ONE creature turnaround image that shows exactly two views of the same creature, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the creature's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the creature's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CREATURE
- Exactly the same creature, colours and proportions as in the attached front reference image: the giant winged serpent-dragon standing upright on two hind legs, one horned head, dark meteoric star-iron scales with a fine silvery cross-hatched pattern, a deep crimson satin-matte throat and underbelly, dark bronze spine ridges, thin matte deep ember-orange cracks between the plates, two bat-like wings with deep crimson membranes and black obsidian finger-bones, a long tail ending in a bronze-capped star-iron club, and one deep jade-green stone on the brow between the horns.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: standing upright on straight hind legs, the front limbs straight about 40 degrees down and away from the body, claws open and empty.
- The wings stay half raised behind the back exactly as in the front reference, their roots on the spine above the shoulder blades, clearly apart from the front limbs.
- The tail hangs straight down behind the body to the ground and curls forward at the tip: in the profile view the whole tail is visible behind the legs; in the back view it runs down the centre line. The bronze spine ridges are visible in both views.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; plausible powerful creature anatomy, one head; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, more than one head, wings spread out sideways at arm height, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** трикутників · Symmetry **On**.

```
Giant winged serpent-dragon standing upright on two hind legs, one horned head, scales of dark meteoric iron with a fine silvery cross-hatched pattern, deep crimson underbelly plates, dark bronze spine ridges, thin matte ember-orange cracks, bat wings with crimson membranes half raised behind the back, long tail with a bronze-capped club, one small jade-green stone on the brow. Stylized hand-painted 3D game creature, menacing, clean readable silhouette, A-pose, empty claws, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no fire, no particles, no floating parts, all parts physically connected.
```

---

### 11.2 Водяник `vodianyk`

**(a) Картка боса** — `vodianyk_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no water surface, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; menacing and ancient, never gory, never comic.
- Proportions: a huge, broad, heavy-set elder giant, about 7 heads tall, slightly hunched but powerful. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no glow, no splashes, no flying drops, no bubbles, no mist, no particles, no light rays, no motion trails); the game adds every effect itself.

CHARACTER - an ancient water lord inspired by the vodyanyk of Ukrainian folk tales, who sleeps under an old mill and drags careless travellers into the whirlpool; here a chieftain of a fictional fire horde who drowned his forge-fire in the reef
- Skin: like damp but fully matte black volcanic stone (#16131A) with cool grey highlights and no shine; deep wrinkles; heavy brow; small eyes with matte ember-orange irises that do not glow.
- Hair and beard: very long, heavy beard and hair of dark crimson river-weed (#6B0D0F with #B81A17 highlights), hanging in heavy strands to the waist, threaded with small dark bronze shell beads.
- Crown: a crown of branching black coral with small dark bronze shells; ONE single deep jade-green satin-finish cabochon (body #1E7A55, shadows #0C3B28), about 3% of the figure height, set in the centre of the crown in a bronze mount. It does not glow.
- Armour and clothes: a mantle of dark crimson waterweed over broad shoulders; overlapping dark bronze fish-scale plates (#C7732E, aged and matte) on the chest; a broken segment of a heavy bronze mill wheel worn as a pauldron on the left shoulder; thin matte ember-orange crack lines (#C2410C) in the bronze like cooling embers seen in daylight; a wide belt of black rope and bronze rings; a crimson waterweed robe that ends above the knees over wrapped dark trousers.
- Hands: big webbed hands with dark bronze rings on the fingers.
- Weapon: a long heavy black wooden boat-hook oar with a curved dark bronze hook at its end (a single hook, never a trident or fork).

COLOR LOCK
- Palette: matte black volcanic-stone skin, deep crimson weed, black coral, aged dark bronze, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere. No blue, cyan, teal, aqua, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours; no turquoise water colours on the character.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: leaning forward over the viewer, the left webbed hand reaching down toward the lower left as if pulling someone under, the right hand gripping the boat-hook oar upright at his side; the beard swinging forward; a cold, patient, menacing stare at the lower left.
- Camera low at his waist height looking up about 15 degrees so he towers over the viewer; long lens, little perspective distortion.
- Framing: from the top of the coral crown down to mid-thigh; the figure continues off the bottom edge. The whole crown and the oar's hook stay inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the head, hands or the hook inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the oar, cropped head, background objects, water surface, floor, cast shadow, gradient or vignette background, glow, glowing eyes, splashes, drops, bubbles, mist, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, comic look, fish tail, trident, fork, blood, gore, wounds, skulls, bones, drowned bodies, flags, emblems or insignia of any real army, state or party, political or religious symbols, crosses, crescents, white enamel, polished gold filigree, any resemblance to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `vodianyk_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
обидві ноги видно нижче коліна, руки порожні, борода не зливається з руками.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the huge, broad elder water lord with skin like damp matte black volcanic stone, a very long beard and hair of dark crimson river-weed with small bronze shell beads, a crown of black coral with one deep jade-green stone (#1E7A55) in the centre, dark bronze fish-scale plates on the chest, a broken bronze mill-wheel segment on the left shoulder, a crimson waterweed mantle, a black rope belt with bronze rings, a crimson waterweed robe ending above the knees over wrapped dark trousers, bare webbed feet with bronze toe rings.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The boat-hook oar is NOT in this image (it is made as a separate model).
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart, both legs clearly separate from the knee down; feet pointing forward.
- Webbed hands open and EMPTY, palms facing down, fingers together, clearly separated from the body and from the beard.
- The beard hangs straight down in front of the chest to the belt, not touching the arms; the robe hangs straight.
- Neutral heavy expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a huge, broad, heavy-set elder about 7 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no drops, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, legs hidden under one long robe, side or three-quarter view, perspective distortion, dramatic lighting, glowing eyes, water effects, floating parts, extra fingers, fish tail, trident, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `vodianyk_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `vodianyk_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `vodianyk_sheet_side.png`, права → `vodianyk_sheet_back.png`. Перевірте: уламок колеса видно лише на лівому плечі, ноги розділені нижче коліна, борода не торкається рук.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the huge, broad elder water lord with skin like damp matte black volcanic stone, a very long beard and hair of dark crimson river-weed with small bronze shell beads, a crown of black coral with one deep jade-green stone (#1E7A55), dark bronze fish-scale plates on the chest, a broken bronze mill-wheel segment on the LEFT shoulder only, a crimson waterweed mantle, a black rope belt with bronze rings, a crimson waterweed robe ending above the knees over wrapped dark trousers, bare webbed feet with bronze toe rings. No oar.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty, fingers together.
- The beard hangs straight down in front of the chest, not touching the arms; the hair and the waterweed mantle hang down the back to the waist (seen in the back view); the mill-wheel segment is clearly visible on the left shoulder in the profile view.
- Both legs clearly separate from the knee down in both views.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a huge, broad, heavy-set elder about 7 heads tall; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, an oar, a trident, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Проп «boat-hook oar»** — `vodianyk_prop_oar.png` → Meshy Image to 3D → `vodianyk_prop_oar.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка.

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same boat-hook oar as in the attached reference image (the approved card): a long, heavy, straight black wooden shaft, a flat oar blade at the bottom end, and a single curved dark bronze hook (#C7732E, aged and matte) at the top end bound to the shaft with black rope; thin matte ember-orange crack lines in the bronze. A single hook only, never a trident or a fork. No gemstones.

VIEW
- The whole object alone, shown once, standing upright with the hook at the top, straight side view, centred, filling about 90% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no water, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, a trident, a fork, perspective distortion, cropped ends, dramatic light, glow, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(d) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **Auto** (наплічник лише зліва).

```
Huge broad elder water lord, skin like damp matte black volcanic stone, very long beard and hair of dark crimson river-weed with small bronze shell beads, crown of black coral with one small jade-green stone, bronze fish-scale chest plates, a broken bronze mill-wheel segment on the left shoulder, crimson weed mantle, rope belt with bronze rings, crimson robe ending above the knees over wrapped trousers, bare webbed feet. Stylized hand-painted 3D game character, menacing, clean readable silhouette, A-pose, empty webbed hands, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no water effects, no particles, no floating parts, all parts physically connected.
```

---

### 11.3 Блуд `blud`

**(a) Картка боса** — `blud_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no fog, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; sly, mischievous and a little eerie, never horror, never gory, never comic.
- Proportions: a tall, lean spirit with believable adult proportions, about 7.5 heads tall, arms of normal length and long thin fingers; slender but not skeletal. No chibi or cartoon proportions, no stretched horror proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light, including the lantern.
- Effects: none in the image (no glow, no will-o'-wisp light, no fog, no smoke, no sparks, no particles, no light rays, no motion trails); the game adds every effect itself.

CHARACTER - a trickster spirit inspired by the blud of Ukrainian folk belief, who leads travellers astray at night; here a chieftain of a fictional fire horde
- Face: a narrow, sly, clearly readable face of dark grey-black matte skin (#16131A) with cool grey highlights: a long thin nose, high arched black brows, narrow eyes with matte ember-orange irises that do not glow, and a thin crooked closed-lip grin; long straight black hair hanging from under a wide-brimmed, dented crimson felt hat. His identity comes from the hat, the reeds, the bells and the lantern, not from a frightening face.
- Coat: a long, tattered deep crimson coat (#B81A17, shadows #6B0D0F) with ragged hems, open at the front from the waist down over slim dark trousers so both legs are clearly visible; a row of many small dark bronze buttons (#C7732E, aged and matte); thin matte ember-orange crack lines (#C2410C) along the seams like cooling embers seen in daylight.
- Belt: a black leather belt hung with bundles of dried reeds and small dark bronze bells.
- Boots: tall pointed dark boots with bronze buckles.
- Weapon: a long crooked black wooden staff; from its hooked top hangs a small dark bronze cage-lantern holding ONE single deep jade-green satin-finish stone (body #1E7A55, shadows #0C3B28), the false light; the stone does not glow.

COLOR LOCK
- Palette: dark grey-black skin, deep crimson coat and hat, aged dark bronze, dried-reed straw, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: leaning in from the right with a sly, beckoning curl of one long finger toward the lower left; the other hand holds the staff so the lantern hangs out in front of him at chest height; head tilted, grinning.
- Camera at his chest height looking up about 10 degrees; long lens, little perspective distortion.
- Framing: from the top of the hat down to mid-thigh; the figure continues off the bottom edge. The whole hat, the staff's hook and the lantern stay inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the face, hands, hat or lantern inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the staff, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, glowing eyes, glowing lantern, fog, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, clown or comic look, featureless or faceless mask, missing nose, horror look, stretched or unnaturally elongated body, overly long arms, tentacles, suit and tie, skeleton, blood, gore, wounds, skulls, bones, flags, emblems or insignia of any real army, state or party, political or religious symbols, crosses, crescents, white enamel, polished gold filigree, any resemblance to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `blud_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
обидві ноги видно (каптан розстебнутий), руки порожні, капелюх цілком у кадрі.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the tall, lean trickster spirit with a narrow sly face of dark grey-black matte skin, a long thin nose, arched black brows, matte ember-orange eyes, a thin crooked closed-lip grin, long black hair, a wide-brimmed dented crimson felt hat, a long tattered deep crimson coat with many small bronze buttons, open from the waist down over slim dark trousers, a black belt hung with dried reeds and small bronze bells, tall pointed dark boots with bronze buckles.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The staff and the cage-lantern are NOT in this image (they are made as a separate model); the jade stone sits in the lantern, so the body itself carries no gemstone.
- COLOR LOCK: no gemstones or crystals on the body. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from the top of the hat to the toes, both feet fully visible, centred; the figure fills about 90% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart, both legs clearly separate below the open coat; feet pointing forward.
- Hands open and EMPTY, palms facing down, the long fingers together, clearly separated from the body.
- The coat tails hang straight down behind the legs; the reeds and bells sit flat against the hips.
- Neutral sly expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall, lean spirit about 7.5 heads tall with believable adult proportions; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no fog, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held staff or lantern, faceless mask, stretched proportions, cropped feet, cropped hat, legs hidden under a closed coat, side or three-quarter view, perspective distortion, dramatic lighting, glowing eyes, floating parts, extra fingers, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `blud_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `blud_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `blud_sheet_side.png`, права → `blud_sheet_back.png`. Перевірте: обличчя з носом і бровами видно в профіль, капелюх цілком у кадрі, ноги видно під розстебнутим каптаном.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall, lean trickster spirit with a narrow sly face of dark grey-black matte skin, a long thin nose, arched black brows, matte ember-orange eyes, a thin crooked closed-lip grin, long black hair, a wide-brimmed dented crimson felt hat, a long tattered deep crimson coat with many small bronze buttons, open from the waist down over slim dark trousers, a black belt hung with dried reeds and small bronze bells, tall pointed dark boots with bronze buckles. No staff, no lantern.
- COLOR LOCK: no gemstones or crystals on the body (the jade stone sits in the lantern, made separately). No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty, fingers together.
- The profile view shows the face with its long nose and the full hat brim; the back view shows the long black hair, the hat brim and the ragged coat tails hanging straight down behind the legs.
- The reeds and bells sit flat against the hips; both legs clearly visible below the open coat.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall, lean spirit about 7.5 heads tall with believable adult proportions; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, faceless mask, stretched proportions, a staff, a lantern, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Проп «staff and cage-lantern»** — `blud_prop_lantern.png` → `blud_prop_lantern.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка.

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same staff and lantern as in the attached reference image (the approved card): a long crooked black wooden staff with a hooked top; from the hook hangs, on a short rigid dark bronze rod (not a chain), a small dark bronze cage-lantern (#C7732E, aged and matte) holding ONE deep jade-green satin-finish stone (#1E7A55). The stone does not glow.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals.

VIEW
- The whole object alone, shown once, standing upright with the hook and lantern at the top, straight side view, centred, filling about 90% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no light from the lantern, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, a hanging chain, perspective distortion, cropped ends, dramatic light, glow, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(d) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **On**.

```
Tall lean trickster spirit, narrow sly face with dark grey-black matte skin, long thin nose, arched brows and a thin crooked grin, long black hair, wide-brimmed dented crimson felt hat, long tattered deep crimson coat with many small bronze buttons, open from the waist down over slim dark trousers, belt with dried reeds and small bronze bells, tall pointed boots with bronze buckles. Stylized hand-painted 3D game character, eerie, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no particles, no floating parts, all parts physically connected.
```

---

### 11.4 Князь Жаророгих `kniaz`

**(a) Картка боса** — `kniaz_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no lava field, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; imposing, regal and menacing, never gory.
- Proportions: a towering, broad-shouldered armoured warlord, about 7.5 heads tall including the horns. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no glow, no fire, no lava light, no smoke, no embers flying, no sparks, no particles, no light rays, no motion trails); the game adds every effect itself.

CHARACTER - the prince of a fictional fire horde, the lord of all its chieftains
- Helm and horns: a closed crown-helm of black obsidian whose visor is shaped like a stern, abstract face (not a human face, no visible skin); two huge ram-like curling horns grow from the helm, made of black volcanic rock with thin deep ember-orange crack lines (#C2410C) painted as matte colour like cooling lava seen in daylight; a jagged crown band of dark bronze (#C7732E, aged and matte) fused into the base of the horns; ONE single deep jade-green satin-finish cabochon (body #1E7A55, shadows #0C3B28), about 3% of the figure height, set in the crown band above the visor. It does not glow. Two narrow eye slits in the visor with matte ember-orange depth, no glow.
- Armour: heavy layered plate armour of satin-matte black obsidian (#16131A) with deep crimson satin-matte panels (#B81A17, shadows #6B0D0F) on the chest, pauldrons and tassets; dark bronze rims and rivets; thin matte ember-orange cracks along the plate edges.
- Cloak: a heavy deep crimson cloak with a ragged hem, plain, with no emblem, hanging from both pauldrons to mid-calf.
- Weapon: a huge two-handed flanged mace with a head of black obsidian bound by two dark bronze bands, on a long black haft with a bronze butt cap.

COLOR LOCK
- Palette: black obsidian, deep crimson satin-matte plates, aged dark bronze, black volcanic rock horns, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: striding toward the lower left, the mace raised over his right shoulder in both hands, ready to strike down; the horns lowered like a charging ram; the cloak swinging behind.
- Camera low at his waist height looking up about 15 degrees so he towers over the viewer; long lens, little perspective distortion.
- Framing: from the tips of the horns down to mid-thigh; the figure continues off the bottom edge. The whole helm, both horns and the mace head stay inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the horns, hands or mace inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, a visible human face, extra characters, extra fingers, extra limbs, fused or deformed hands, a hand merged into the haft, cropped head, cropped horns, background objects, floor, cast shadow, gradient or vignette background, glow, glowing eyes, glowing cracks, fire, flames, lava light, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, comic look, blood, gore, wounds, skulls, bones, flags, banners, coats of arms, emblems or insignia of any real army, state, ruler or party, real historical armour or uniforms, political or religious symbols, crosses, tridents, crescents, eagles, white enamel, polished gold filigree, any resemblance to a real person or to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `kniaz_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
обидва роги цілком у кадрі, плащ висить за спиною, руки порожні.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the towering armoured warlord in a closed black obsidian crown-helm with a stern abstract visor, two huge ram-like curling horns of black volcanic rock with thin matte ember-orange cracks, a dark bronze crown band with one deep jade-green stone (#1E7A55) above the visor, heavy black obsidian plate armour with deep crimson satin-matte panels and dark bronze rims, a plain deep crimson cloak with a ragged hem, armoured boots.
- Same helm, armour, colours and materials as the reference; nothing added, nothing removed. The mace is NOT in this image (it is made as a separate model).
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from the horn tips to the toes, both feet fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Gauntleted hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The cloak hangs straight down behind the body to mid-calf, not touching the arms or the ground; the horns curl symmetrically.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a towering warlord about 7.5 heads tall including the horns; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no fire, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held weapon or object, cropped feet, cropped horns, a visible human face, side or three-quarter view, perspective distortion, dramatic lighting, glowing cracks or eyes, floating parts, extra fingers, emblems, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `kniaz_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `kniaz_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `kniaz_sheet_side.png`, права → `kniaz_sheet_back.png`. Перевірте: обидва роги цілком у кадрі в обох видах, плащ без жодного знака.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, armour, colours and proportions as in the attached front reference image: the towering armoured warlord in a closed black obsidian crown-helm with a stern abstract visor, two huge ram-like curling horns of black volcanic rock with thin matte deep ember-orange cracks, a dark bronze crown band with one deep jade-green stone (#1E7A55) above the visor, heavy satin-matte black obsidian plate armour with deep crimson satin-matte panels and dark bronze rims, a plain deep crimson cloak with a ragged hem, armoured boots. No mace.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; gauntleted hands open and empty, fingers together.
- The profile view shows the full curl of the near horn and the profile of the visor; the back view shows both horns curling symmetrically and the plain cloak hanging straight down the back to mid-calf, with no emblem.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a towering warlord about 7.5 heads tall including the horns; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, a visible human face, emblems on the cloak, a mace, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Проп «obsidian mace»** — `kniaz_prop_mace.png` → `kniaz_prop_mace.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка.

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same mace as in the attached reference image (the approved card): a huge two-handed flanged mace; the head is black obsidian with six thick flanges, bound by two dark bronze bands (#C7732E, aged and matte) with thin matte ember-orange crack lines; a long black haft with a dark bronze collar and a bronze butt cap. No gemstones, no emblems.

VIEW
- The whole object alone, shown once, standing upright with the head at the top, straight side view, centred, filling about 90% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no fire, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, emblems, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(d) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **On**.

```
Towering armoured warlord, closed black obsidian crown-helm with a stern abstract visor, two huge ram-like curling horns of black volcanic rock with thin matte ember-orange cracks, dark bronze crown band with one small jade-green stone, heavy black obsidian plate armour with deep crimson satin-matte panels and bronze rims, plain deep crimson cloak with a ragged hem, armoured boots. Stylized hand-painted 3D game character, imposing, clean readable silhouette, A-pose, empty gauntlets, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no fire, no particles, no floating parts, all parts physically connected.
```

---

### 11.5 Морозна Мара `mara`

**(a) Картка боса** — `mara_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no snow, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; refined face with clean delicate features; soft painterly rendering with crisp clean edges; rich but controlled colour; cold, regal and menacing, never gory, never seductive.
- Proportions: a tall, gaunt, regal adult woman-like winter spirit, about 8 heads tall, fully covered by her clothes. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no glow, no frost breath, no snowflakes, no mist, no sparks, no particles, no light rays, no motion trails); the game adds every effect itself.

CHARACTER - a winter spirit inspired by Mara of Ukrainian folk custom, the long winter that people see off every spring; here a chieftain of a fictional fire horde
- Face: pale ash-grey skin, sharp high cheekbones, thin closed lips, a cold unblinking stare; eyes with matte ember-orange irises that do not glow; long straight black hair under the veil.
- Crown: a tall crown of long, sharp spikes of opaque black ice that looks like dark matte obsidian (#16131A), no facets, edged with soft grey-white hoarfrost; a long deep crimson veil (#B81A17, shadows #6B0D0F) falling from the crown over the shoulders and back.
- Gown: a long layered gown of deep crimson and black, split open at the front from the hips down over slim legs in black obsidian greaves and pointed dark sabatons, so both legs are clearly visible from the knee down; grey-white hoarfrost painted along the hems; thin matte ember-orange crack lines (#C2410C) in the black armour plates of the bodice like cooling embers seen in daylight; dark bronze clasps (#C7732E, aged and matte).
- Brooch: ONE single deep jade-green satin-finish cabochon (body #1E7A55, shadows #0C3B28), about 3% of the figure height, in a dark bronze brooch at the high collar. It does not glow.
- Hands: long thin fingers with short claw tips of black ice. No weapon.

COLOR LOCK
- Palette: deep crimson and black cloth, black obsidian-like ice, soft grey-white hoarfrost, pale ash-grey skin, aged dark bronze, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere; the ice spikes are opaque and dark, not crystals. No blue, cyan, teal, icy-blue, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: standing tall and still, one long hand raised toward the lower left with the fingers spread as if breathing winter onto the bridge (no effect drawn), the other hand holding the veil at her chest; the veil swept back by an unseen wind; the cold stare aimed at the lower left.
- Camera at her waist height looking up about 12 degrees so she towers over the viewer; long lens, little perspective distortion.
- Framing: from the tips of the ice crown down to mid-thigh; the figure continues off the bottom edge. The whole crown stays inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the face, hands or crown spikes inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, cropped head, cropped crown, background objects, snow, floor, cast shadow, gradient or vignette background, glow, glowing eyes, frost breath, snowflakes, mist, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, revealing or seductive clothing, sickle, scythe, weapons, corpse or death imagery, blood, gore, wounds, skulls, bones, blue ice crystals, flags, emblems or insignia of any real army, state or party, political or religious symbols, crosses, crescents, white enamel, polished gold filigree, any resemblance to a real person or to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `mara_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
обидві ноги видно нижче коліна, вуаль висить за спиною й не торкається рук, корона цілком у кадрі.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the tall, gaunt, regal winter spirit with pale ash-grey skin and long black hair, a tall crown of opaque black-ice spikes edged with grey-white hoarfrost, a long deep crimson veil, a layered crimson-and-black gown split open at the front from the hips down over slim legs in black obsidian greaves and pointed dark sabatons, dark bronze clasps, a dark bronze brooch with one deep jade-green stone (#1E7A55) at the high collar, black-ice claw tips on the fingers.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. No weapon.
- COLOR LOCK: the jade stone is the only gemstone; the ice is opaque and dark. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from the crown tips to the toes, both feet fully visible, centred; the figure fills about 90% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart, both legs clearly separate below the split gown; feet pointing forward.
- Hands open and EMPTY, palms facing down, fingers together, clearly separated from the body and the veil.
- The veil hangs straight down behind the shoulders and back, not touching the arms; the gown panels hang straight at the sides.
- Neutral cold expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a tall, gaunt figure about 8 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no snow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held object or weapon, cropped feet, cropped crown, legs hidden under one long skirt, side or three-quarter view, perspective distortion, dramatic lighting, glowing eyes, floating parts, extra fingers, revealing clothing, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `mara_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `mara_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `mara_sheet_side.png`, права → `mara_sheet_back.png`. Перевірте: корона цілком у кадрі, вуаль висить по спині й не торкається рук, ноги в поножах видно в профіль.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the tall, gaunt, regal winter spirit with pale ash-grey skin and long black hair, a tall crown of opaque black-ice spikes edged with grey-white hoarfrost, a long deep crimson veil, a layered crimson-and-black gown split open at the front from the hips down over slim legs in black obsidian greaves and pointed dark sabatons, dark bronze clasps, a dark bronze brooch with one deep jade-green stone (#1E7A55) at the high collar, black-ice claw tips on the fingers. No weapon.
- COLOR LOCK: the jade stone is the only gemstone; the ice is opaque and dark. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty, fingers together.
- The veil hangs straight down the back from the crown to the knees (seen whole in the back view), not touching the arms; the crown spikes are visible in both views.
- The profile view shows one greaved leg clearly through the split gown; the gown panels hang straight.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a tall, gaunt figure about 8 heads tall, fully covered, never revealing; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, revealing clothing, blue ice, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **On**.

```
Tall gaunt regal winter spirit, pale ash-grey skin, long black hair, tall crown of opaque black-ice spikes with grey-white frost, long deep crimson veil, layered crimson and black gown split open at the front over slim legs in black obsidian greaves, dark bronze clasps, small jade-green stone in a bronze brooch at the collar, black-ice claw tips. Stylized hand-painted 3D game character, cold and menacing, fully covered, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no snow, no particles, no floating parts, all parts physically connected.
```

---

### 11.6 Вихор `vykhor`

**(a) Картка боса** — `vykhor_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no clouds, no tornado, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; wild, fast and menacing, never gory, never comic or cute.
- Proportions: a lean, wiry, sinewy adult storm-devil, about 7.5 heads tall. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no whirlwind, no wind lines, no dust, no flying debris, no glow, no sparks, no particles, no light rays, no motion trails); the game adds the whirlwind and every effect itself.

CHARACTER - a whirlwind devil inspired by Ukrainian folk belief that a devil dances inside every whirlwind; here a chieftain of a fictional fire horde
- Head: two short curved black horns, long pointed ears, a narrow sharp face with a wide grin showing sharp teeth (fierce, not comic), wild black hair; eyes with matte ember-orange irises that do not glow; a dark bronze hoop earring in the left ear holding ONE single deep jade-green satin-finish stone (body #1E7A55, shadows #0C3B28), about 2% of the figure height. It does not glow.
- Body: dark obsidian-black skin (#16131A) with cool grey highlights over lean, defined muscles; thin deep ember-orange crack lines (#C2410C) on the forearms and shins painted as matte colour like cooling embers seen in daylight.
- Legs: human-shaped legs with normal forward-bending knees (not digitigrade), covered in dark goat fur from the knee down, ending in black cloven hooves.
- Tail: a long thin whip tail ending in a small dark bronze barb.
- Clothes: a long, tattered deep crimson sash (#B81A17, shadows #6B0D0F) wrapped around the waist and chest and streaming out in a spiral; wide dark trousers to the knee; dark bronze arm rings and wrist cuffs (#C7732E, aged and matte). No weapon.

COLOR LOCK
- Palette: obsidian-black skin, deep crimson sash, dark fur, black horns and hooves, aged dark bronze, thin matte ember-orange cracks, one deep jade-green stone.
- The jade stone is the only gemstone or crystal anywhere. No blue, cyan, teal, sky-blue, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: caught mid-spin in a wild dance, balanced on one hoof, the other leg kicked up behind, both arms flung wide, the body leaning toward the lower left, the sash and the tail spiralling around him, grinning at the viewer.
- Camera at his waist height looking up about 10 degrees; long lens, little perspective distortion.
- Framing: from the tips of the horns down to the knees; the figure continues off the bottom edge. The whole head and both hands stay inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the head, hands, sash ends or tail inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, extra characters, extra fingers, extra limbs, fused or deformed hands, cropped head, background objects, floor, cast shadow, gradient or vignette background, whirlwind, tornado, wind lines, dust, glow, glowing eyes, fire, flames, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, cute or comic look, digitigrade or backward-bending legs, pitchfork, trident, pentagram, wings, blood, gore, wounds, skulls, bones, flags, emblems or insignia of any real army, state or party, political or religious symbols, crosses, crescents, white enamel, polished gold filigree, any resemblance to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `vykhor_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
обидва копита видно, пояс-шарф висить, а не летить, хвіст звисає позаду до землі.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the lean, wiry storm-devil with two short curved black horns, long pointed ears, wild black hair, obsidian-black skin with thin matte ember-orange cracks on the forearms and shins, human-shaped legs with forward-bending knees, dark goat fur from the knee down and black cloven hooves, a long thin whip tail with a small bronze barb, a deep crimson sash wrapped around the waist and chest, wide dark trousers to the knee, dark bronze arm rings and wrist cuffs, a bronze hoop earring in the left ear with one deep jade-green stone (#1E7A55).
- Same face, body, costume, colours and materials as the reference; nothing added, nothing removed. No weapon. No whirlwind.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from the horn tips to the hooves, both hooves fully visible, centred; the figure fills about 88% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround).
- Symmetrical A-pose: arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; hooves pointing forward.
- Clawed hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The sash ends hang straight down at the sides of the hips, not flying; the tail hangs straight down behind the legs and its tip rests on the ground beside the right hoof, touching nothing else.
- Neutral sly expression, mouth closed, eyes open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a lean, wiry figure about 7.5 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no wind, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, spinning, flying cloth, digitigrade legs, a held object, cropped hooves, side or three-quarter view, perspective distortion, dramatic lighting, glowing eyes, whirlwind, floating parts, extra fingers, wings, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `vykhor_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `vykhor_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `vykhor_sheet_side.png`, права → `vykhor_sheet_back.png`. Перевірте: коліна гнуться вперед (як у людини), копита видно, хвіст звисає до землі й не торкається ніг.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, body, colours and proportions as in the attached front reference image: the lean, wiry storm-devil with two short curved black horns, long pointed ears, wild black hair, matte obsidian-black skin with thin matte deep ember-orange cracks on the forearms and shins, human-shaped legs with forward-bending knees, dark goat fur from the knee down and black cloven hooves, a long thin whip tail with a small bronze barb, a deep crimson sash wrapped around the waist and chest, wide dark trousers to the knee, dark bronze arm rings and wrist cuffs, a bronze hoop earring in the LEFT ear with one deep jade-green stone (#1E7A55). No weapon, no whirlwind.
- COLOR LOCK: the jade stone is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; hands open and empty, fingers together.
- The knees bend forward like a human's; the fur starts at the knee.
- The tail grows from the base of the spine and hangs straight down behind the legs, its tip resting on the ground beside the right hoof, touching nothing else (seen whole in the back view); the sash ends hang straight down at the hips, not flying; the earring is visible on the left ear in the profile view.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a lean, wiry figure about 7.5 heads tall; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, digitigrade or backward-bending legs, wings, a whirlwind, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **Auto** (сережка й хвіст збоку).

```
Lean wiry storm devil, two short curved black horns, long pointed ears, wild black hair, obsidian-black skin with thin matte ember-orange cracks on the forearms and shins, human-shaped legs with dark goat fur below the knee and black cloven hooves, long thin whip tail with a small bronze barb, deep crimson sash around the waist and chest, wide dark trousers to the knee, bronze arm rings, bronze hoop earring with a small jade-green stone. Stylized hand-painted 3D game character, fierce, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no wind effects, no particles, no floating parts, all parts physically connected.
```

---

### 11.7 Лихо Однооке `lykho`

**(a) Картка боса** — `lykho_card.png`

Налаштування: формат **3:4** · якість **2K-4K** (мінімум 1536×2048) · 2-4 варіанти · референс: `style_anchor.png` · оригінал PNG.

```
Create ONE vertical boss key-art card illustration for a premium fantasy mobile game.

FORMAT
- Aspect ratio 3:4 (portrait). Resolution 1536x2048 px or higher; never below 1152x1536.
- Background: perfectly flat, uniform light grey #BFBFBF across the whole canvas. No gradient, no vignette, no scenery, no cave, no floor, no ground shadow.
- One single character. No text, no letters, no numbers, no logo, no watermark, no signature, no frame, no border, no UI elements.

ART STYLE
- Same art style as the attached style reference image: elegant semi-realistic painterly fantasy key art for a premium mobile game; soft painterly rendering with crisp clean edges; rich but controlled colour; ominous, ancient and menacing, never gory, never comic.
- Proportions: a towering, gaunt, bony giant with very long arms and large hands, about 8 heads tall, slightly stooped. No chibi or cartoon proportions, no thick outlines.
- Lighting: warm white key light from the upper left front; a thin neutral cool-white rim light from behind on the right; soft neutral ambient fill. Nothing in the image emits light.
- Effects: none in the image (no glow, no eye beam, no smoke, no sparks, no particles, no light rays, no motion trails); the game adds every effect itself.

CHARACTER - the one-eyed giant Likho of Ukrainian folk tales, who sees everything; here a chieftain of a fictional fire horde who watches the world through the Rift
- Head: a long, gaunt face with skin like weathered grey-black basalt (#16131A with cool grey highlights), a heavy brow, hollow cheeks, a wide grim mouth with closed lips; ONE single large round eye in the middle of the forehead, wide open with normal eyelids, its iris a smooth satin-finish deep jade-green stone (body #1E7A55, shadows #0C3B28) with a black pupil; the eye does not glow. No other eyes and no empty eye sockets. Long matted black hair.
- Clothes: tattered deep crimson rags (#B81A17, shadows #6B0D0F) over the shoulders and hips; a heavy dark leather blacksmith's apron studded with dark bronze rivets (#C7732E, aged and matte); several dark bronze chains wrapped around the waist; a black obsidian collar plate at the neck; thin deep ember-orange crack lines (#C2410C) on the forearms and in the collar plate, painted as matte colour like cooling embers seen in daylight; wrapped dark cloth on the shins, bare large feet.
- Weapon: a huge club made from a blackened oak trunk bound with three dark bronze bands.

COLOR LOCK
- Palette: grey-black basalt skin, deep crimson rags, dark leather, aged dark bronze, black obsidian, thin matte ember-orange cracks, one deep jade-green eye.
- The jade iris is the only gemstone or crystal anywhere. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow or opal colours.
- No white enamel and no polished gold filigree. Keep the crimson deep and dark; no large areas of pure bright red.

POSE & COMPOSITION
- Pose: hunched forward over the viewer, the head lowered and turned slightly so the single eye stares straight at the lower left; one long arm dragging the oak club behind on the right, the other huge open hand reaching toward the lower left.
- Camera low at his waist height looking up about 15 degrees so he towers over the viewer; long lens, little perspective distortion.
- Framing: from the top of the head down to mid-thigh; the figure continues off the bottom edge. The whole head stays inside the frame with a margin of at least 4% of the image height.
- The character stands slightly right of centre (body centre line at about 60% of the width). Keep the upper-left area (left 33% of the width, top 35% of the height) as empty flat background: it is reserved for the game's name plate. Never the head, eye or hands inside it.

AVOID
Blurry or low resolution, text, letters, numbers, letter-like runes or glyphs, watermark, signature, logo, frame, border, UI, extra characters, two eyes, three eyes, empty eye sockets, huge drooping eyelids, eyelids reaching the ground, helpers lifting eyelids, extra fingers, extra limbs, fused or deformed hands, a hand merged into the club, cropped head, background objects, floor, cast shadow, gradient or vignette background, glow, glowing eye, eye beam, fire, smoke, sparks, particles, light rays, lens flare, motion blur, glossy highlights, specular hotspots, wet shine, thick outlines, chibi or cartoon proportions, comic look, toga, ancient Greek clothing, blood, gore, wounds, skulls, bones, flags, emblems or insignia of any real army, state or party, political or religious symbols, crosses, crescents, white enamel, polished gold filigree, any resemblance to a character from an existing game, film, comic or anime.
```

**(b) Фронт-лист для Meshy** — `lykho_sheet_front.png`

Налаштування: формат **1:1** · якість **2K+** (≥ 2048×2048) · 2 варіанти · референси: затверджена картка + `style_anchor.png`. Перевірте:
одне око, ступні видно, ланцюги лежать на поясі й не звисають до землі, руки порожні.

```
Create ONE character reference image for image-to-3D conversion (front view).

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery.
- No text, no logo, no watermark, no frame.

CHARACTER
- Exactly the same character as in the attached reference image (the approved card): the towering, gaunt one-eyed giant with grey-black basalt skin, one large round eye in the middle of the forehead whose iris is a smooth satin-finish deep jade-green stone (#1E7A55), a heavy brow, long matted black hair, tattered deep crimson rags over the shoulders and hips, a dark leather blacksmith's apron with bronze rivets, dark bronze chains wrapped around the waist, a black obsidian collar plate, thin matte ember-orange cracks on the forearms, wrapped dark cloth on the shins, bare large feet.
- Same face, costume, colours and materials as the reference; nothing added, nothing removed. The oak club is NOT in this image (it is made as a separate model).
- COLOR LOCK: the jade iris is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- Full body from head to toe, both feet fully visible, centred; the figure fills about 90% of the image height with small even margins.
- Straight front view, camera at chest height, no perspective distortion (like an orthographic turnaround); standing upright, not stooped.
- Symmetrical A-pose: the long arms straight, angled about 40 degrees down from horizontal and away from the body; legs straight and slightly apart; feet pointing forward.
- Huge hands open and EMPTY, palms facing down, fingers together, clearly separated from the body.
- The chains lie tight around the waist; the rags and the apron hang straight, not touching the arms.
- Neutral grim expression, mouth closed, the single eye open looking forward.

RENDER
- The same painterly game-art style as the reference, presented as a clean character turnaround for a 3D artist; a towering, gaunt giant about 8 heads tall; clean readable shapes.
- Soft even studio lighting from the front. No rim light, no dramatic shadows, no glow, no particles, no motion blur.
- Every part physically connected to the body; nothing floating.

AVOID
Action pose, a held club or object, cropped feet, two eyes, drooping eyelids, side or three-quarter view, perspective distortion, dramatic lighting, glowing eye, floating parts, hanging chains, extra fingers, background objects, glossy highlights, specular hotspots, wet shine, text, watermark.
```

*(b2) Бік + спина для Meshy* — `lykho_sheet_sideback.png`

Налаштування: формат **16:9** · якість **4K** (≥ 3840×2160) · референси: затверджений `lykho_sheet_front.png` + картка. Потім розріжте
навпіл (будь-який редактор, «Обрізати»): ліва половина → `lykho_sheet_side.png`, права → `lykho_sheet_back.png`. Перевірте: одне око (у профіль видно одне око посеред чола), ланцюги тісно на поясі, ступні видно.

```
Create ONE character turnaround image that shows exactly two views of the same character, for image-to-3D conversion.

FORMAT
- Aspect ratio 16:9 (landscape). Resolution 3840x2160 px; never below 2560x1440.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no scenery. No text, no logo, no watermark, no frame.
- Two full-body figures side by side at exactly the same scale and height, both from head to toe with both feet visible: the LEFT half of the image shows the character's LEFT side in strict profile (facing the left edge of the image); the RIGHT half shows the character's BACK. A clear empty gap between them; nothing crosses the vertical centre line of the image.

CHARACTER
- Exactly the same character, costume, colours and proportions as in the attached front reference image: the towering, gaunt one-eyed giant with grey-black basalt skin, one large round eye in the middle of the forehead whose iris is a smooth satin-finish deep jade-green stone (#1E7A55), a heavy brow, long matted black hair, tattered deep crimson rags over the shoulders and hips, a dark leather blacksmith's apron with bronze rivets, dark bronze chains wrapped tight around the waist, a black obsidian collar plate, thin matte deep ember-orange cracks on the forearms, wrapped dark cloth on the shins, bare large feet. No club.
- COLOR LOCK: the jade iris is the only gemstone. No blue, cyan, teal, violet, pink, amber-gold or clear-white crystals; no rainbow colours. No white enamel, no polished gold.

POSE & VIEW
- The same A-pose as the front reference: arms straight, about 40 degrees down and away from the body; legs straight and slightly apart; huge hands open and empty, fingers together. Standing upright, not stooped.
- One eye only: in the profile view the single eye is seen from the side in the middle of the forehead; the back view shows the long matted hair, the apron straps crossing on the back and the rags hanging straight.
- The chains lie tight around the waist and do not hang down.
- Each figure fills about 88% of the image height. Camera at chest height, no perspective distortion.

RENDER
- The same painterly game-art style as the reference, a clean turnaround for a 3D artist; a towering, gaunt giant about 8 heads tall; clean readable shapes.
- Soft even studio lighting. No rim light, no dramatic shadows, no glow, no particles; every surface matte. Every part physically connected.

AVOID
A front view, more or fewer than two figures, different scales, three-quarter views, action poses, held weapons or objects, cropped feet, perspective distortion, dramatic light, glow, two eyes, drooping eyelids, hanging chains, a club, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(c) Проп «oak club»** — `lykho_prop_club.png` → `lykho_prop_club.glb` (~2 500 трикутників, без ригу).
Налаштування: формат **1:1** · якість **2K+** · референс: картка.

```
Create ONE prop reference image for image-to-3D conversion.

FORMAT
- Aspect ratio 1:1 (square). Resolution 2048x2048 px.
- Background: perfectly flat, uniform light grey #BFBFBF. No floor, no shadow, no stand. No text, no logo, no watermark, no frame.

OBJECT
- Exactly the same club as in the attached reference image (the approved card): a huge club made from a blackened, gnarled oak trunk, thick at the striking end and narrowing to a grip, bound with three dark bronze bands (#C7732E, aged and matte); a few short broken branch stubs near the thick end. No gemstones, no spikes of metal.

VIEW
- The whole object alone, shown once, standing upright with the thick end at the top, straight side view, centred, filling about 90% of the image height; both ends fully inside the frame.
- No hands, no character, no stand, no second copy.

RENDER
- The same painterly game-art style as the reference, clean shapes for a 3D artist.
- Soft even studio lighting from the front. No glow, no sparks, no particles, no motion blur. Every part physically connected.

AVOID
Hands, a character, a second object, perspective distortion, cropped ends, dramatic light, glow, glossy highlights, specular hotspots, wet shine, text, watermark.
```

**(d) Meshy, текстовий промт (запасний; основний шлях — Multi-image з листів b + b2).** Remesh **18 000** · Symmetry **On**.

```
Towering gaunt one-eyed giant, grey-black basalt skin, one large round eye in the middle of the forehead with a jade-green iris, heavy brow, long matted black hair, tattered deep crimson rags, dark leather blacksmith apron with bronze rivets, bronze chains wrapped around the waist, black obsidian collar plate, thin matte ember-orange cracks on the forearms, wrapped shins, bare large feet. Stylized hand-painted 3D game character, ominous, clean readable silhouette, A-pose, empty hands, full body, front view, plain light grey background, soft even lighting, matte surfaces, no glossy highlights, no glow, no particles, no floating parts, all parts physically connected.
```

---

## 12. Питання до власника

Варіант «А» в кожному питанні раджу я. Можна відповісти просто «як радиш».

**1. Який камінь носять боси?**
Кожен бос має одну прикрасу-камінь, як герої мають камінь-серце.
- А. Один темно-нефритовий (глибокий зелений) у кожного. Він не плутається ні з воротами, ні з рідкістю героїв (раджу)
- Б. Темний гранат, у тон до кармінного: ледь помітний, зате «свій» для орди
- В. Опалове Ядро боса прямо на грудях: те саме, що випадає після перемоги. Гарний зв'язок, але опал у грі означає найвищу рідкість героїв

**2. Що стоїть у бою, поки нема 3D-моделі?**
- А. Спершу я покажу вам три заглушки на справжньому знімку бою з телефона (фігура з картки над стіною, фігура з фронт-листа перед ворітьми, збільшений рядовий Жаророгий), і ви оберете ту, що не схожа на наліпку (раджу)
- Б. Одразу фігура з картки над стіною, без порівняння
- В. Чекати моделей і не вмикати босів до того

**3. Що буде, якщо не зламати замки щита?**
- А. Щит забирає ще 15% здоров'я боса за кожен цілий замок. Можна перемогти й так, просто дорожче (раджу)
- Б. 25% за замок: замки стають майже обов'язковими
- В. Без щита: ворота-ключ просто дають солдатів

**4. Як ульта діє на Великий удар?**
- А. Будь-яка ульта під час замаху (1,2 секунди відліку) або трохи раніше, не раніше ніж за 1,3 секунди до сутички, збиває удар. Просто й однаково для всіх героїв (раджу)
- Б. Лише ульта, натиснута саме під час відліку (складніше, але цікавіше вправним)
- В. Ульта удару не збиває, вона лише б'є боса

**5. Нічні боси в «Навалі»: яка планка?**
Зараз розрахунок економіки чекає, що звичайний гравець перемагає нічний восьмий рівень приблизно 65 разів зі 100 з
героями і 53 зі 100 без них. Тобто ніч зараз помітно важча за день.
- А. Ті самі сім босів уночі, планка 7 із 10. Нічних босів доведеться трохи послабити порівняно з теперішнім розрахунком, і я покажу, що зміниться в економіці (раджу)
- Б. Планка 8 із 10, як у кампанії: послабити ще більше, ніч стане майже як день
- В. Планка як зараз у розрахунку: близько 6 із 10 з героями і 5 із 10 без них; ніч лишається важкою
- Г. Окремі нічні боси (ще сім моделей)

**6. Титули тим, хто вже пройшов боса до оновлення?**
- А. Так, тихо видати титули за всі вже пройдені восьмі рівні, без церемонії. Ядро боса вже нараховане (раджу)
- Б. Ні, титул лише за нову перемогу
- В. Без титулів узагалі

**7. Як часто показувати велику картку боса?**
- А. Перший раз уся картка, далі коротка табличка з іменем на 1,6 секунди (раджу)
- Б. Картку щоразу перед боєм
- В. Лише табличку, без картки

**8. Перший бос (Зоряний Змій, рівень 8): чи давати готову ульту перед боєм?**
- А. Так, лише на першому босі: тоді урок «ульта збиває удар» спрацює в кожного (раджу)
- Б. Ні, як звичайно

**9. Ядро боса на повторах?**
Зараз гра дає Ядро за кожну перемогу на восьмому рівні, навіть повторну. Задумано 14 за всю гру.
- А. Лише за першу перемогу, як задумано (раджу)
- Б. За кожну перемогу

**10. Князь і лист Сірка: жартуємо?**
- А. Так: в історії Князя один рядок про те, що він досі лютує через листа від Сірка з військом (раджу)
- Б. Ні, без згадки про Сірка

**11. У якому порядку робити арт і моделі?**
- А. Спершу всі сім карток (на них стоїть заглушка й екран боса), потім фронт-листи й листи «бік + спина», потім моделі: Змій і Князь першими (раджу)
- Б. Боса за босом: картка, листи, модель, далі наступний
- В. Лише Змій повністю, решту пізніше

**12. Як звати володаря орди?**
«Князь» — гарне старе слово, і в грі вже є княгиня Ольга. Хтось може відчути, що лиходій і героїня мають один титул.
- А. Лишити «Князь Жаророгих», як ви вже обрали: Ольга — княгиня Рунічного лісу, він — князь орди, у грі вони не плутаються (раджу)
- Б. «Володар Жаророгих»
- В. «Вождь Жаророгих»

**13. Хто в нас «звичайний гравець» для перевірки планки 8 із 10?**
- А. Бот, налаштований за розрахунком економіки; плюс я покажу для кожного боса, як змінюється відсоток перемог від уміння гравця, щоб було видно, наскільки бос чутливий (раджу)
- Б. Ви або хтось зі знайомих, хто грає «звичайно», зіграєте 20 коротких перших спроб на рівнях 4-7, і бота я налаштую під цей результат
- В. Обидва: спершу бот, потім уточнення за вашими спробами

**14. Нічна перемога над босом: окрема картка й титул?**
- А. Так: при першій нічній зустрічі коротка картка того самого боса з позначкою «Ніч», а за першу нічну перемогу титул «Гроза Змія · Ніч» (раджу)
- Б. Картка так, окремого титулу ні
- В. Нічого окремого: уночі одразу бій

**15. Якщо планка 8 із 10 вимагатиме зробити боса легшим, ніж закладено в розрахунок економіки?**
Зараз економіка вважає боса трохи важчим за звичайний рівень (на 0-7% залежно від світу). Розрахунок уже тепер чекає,
що звичайний гравець перемагає найважчого боса приблизно 74 рази зі 100 без героїв і 80 з героями, тобто нижче
вашої планки або на самій межі.
- А. Перемагає планка 8 із 10. Я перерахую економіку з новими цифрами (швидкість проходження, Зоряна руда, Маяки, серії поразок) і покажу вам, що змінилося (раджу)
- Б. Перемагає економіка: на світах 5-7 планка 7 із 10

---

## Відхилені зауваження критика

Every finding of the review was checked against the code and accepted; the lines below record only the parts of
suggested fixes that were not taken, with the reason.

- Finding "BOSS_TICK" (critical), alternative "schedule blows by tick count": not taken. One fixed standoff with exactly
  one blow keeps the clash length and the blow count deterministic (C4, C6 "blows landed equal") and teaches one lesson;
  extra blows by tick count would still fall outside a single ult's stagger in long sieges.
- Finding "ult timing" (critical), optional "allow a phase-1 cast when a strike would kill ≥ X": not taken. It brings back
  the mis-timed ult for the blow, and titan's armour already has a bounded phase-1 effect (strike caps halved).
- Finding "free strip narrower than the army" (high), alternative "clamp BLOB_MAX lower inside the arena": not taken.
  Squeezing up to 220 drawn soldiers into a smaller ellipse halves the area per unit (visible overlap) and changes the
  blob code in Army and LevelSim everywhere; restricting strikes to one side lane is local to the boss code.
- Finding "moving strikes undefined" (medium), the twister as "one rail-to-rail pass with a lane-wide gap at the moment
  of crossing": not taken in that form. The army needs 0.8-1.1 s to pass a line; any lateral motion of a band during that
  time sweeps more than the 2.3 u a 4.4 u blob can leave free on a 7 u bridge. Both the twister and the gaze are therefore
  static side-lane bands; the twister's run across the bridge and the eye's beam are visuals during the warning, and the
  red telegraph always shows the landing lane.
- Finding "8 of 10 cannot be measured" (high), "fix the bot's parameters from a short owner playtest": taken as an
  owner option (§12 Q13), not the default. Twenty human tries give a win rate with a standard error of about 9 pp, and
  the owner's time is scarce; the published win-vs-skill curve shows the sensitivity either way.
- Finding "billboard contradicts the fight" (medium), "cut it from the frontal sheet (b) and place it in front of the
  gate": taken as one of the three placeholders shown to the owner, not as the default. The front sheet is an A-pose
  with empty hands and reads as a mannequin; the owner decides after the siege-camera shots (§7.1, Q2).
