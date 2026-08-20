"""Shared translations.

Imported by the bot and by the worker scripts (which run in other
interpreters), so it must stay pure standard library.
"""

LANGUAGES = ("uk", "en")

DEFAULT_LANGUAGE = "uk"

LANGUAGE_NAMES = {
    "uk": "🇺🇦 Українська",
    "en": "🇬🇧 English"
}


STRINGS = {

    # --------------------------------------------------------
    # Language menu
    # --------------------------------------------------------

    "language_prompt": {
        "uk": "Обери мову / Choose language:",
        "en": "Choose language / Обери мову:"
    },
    "language_set": {
        "uk": "✅ Мова: українська.",
        "en": "✅ Language: English."
    },
    "btn_language": {
        "uk": "🌐 Мова",
        "en": "🌐 Language"
    },

    # --------------------------------------------------------
    # Greeting and hints
    # --------------------------------------------------------

    "greeting": {
        "uk": (
            "ForgeMind — аналіз CAD-файлів для виробництва.\n"
            "Надішли файл — поверну звіт, кресленик і документи "
            "для цеху.\n\n"
            "📥 Що приймаю\n"
            "• STEP / STP / FCStd — 3D-модель\n"
            "• DWG — розберу сам: тіла → 3D, креслення → розкрій\n"
            "• DXF — плоский розкрій\n"
            "• STL / OBJ / 3MF — сітка\n\n"
            "📤 Що поверну\n"
            "• Звіт: габарит, деталі, отвори по діаметрах\n"
            "• Кресленик: ізометрія з габаритними розмірами\n"
            "• Розкрій: довжина різу, врізання, площа\n"
            "• Сітка: об'єм і перевірка на діри та дефекти\n\n"
            "🔘 Кнопками під звітом\n"
            "• 🧊 3D-вьювер просто в Telegram — торкнись деталі "
            "й побачиш її позицію, кількість і отвори\n"
            "• 📋 Специфікація у CSV для Excel\n"
            "• 📐 Деталювання: окремий аркуш на кожну деталь, "
            "у гнутих — довжини ділянок і кути згинів\n"
            "• 📏 Кресленик з DXF: діаметр біля кожного отвору, "
            "розміри від краю, вид з торця й ескіз\n"
            "• 🔍 Перевірка файла: незамкнені й дубльовані "
            "контури, найменший отвір, перемички\n"
            "• 📍 Координати всіх отворів у CSV\n\n"
            "/language — мова   /start — це повідомлення"
        ),
        "en": (
            "ForgeMind — CAD file analysis for the shop floor.\n"
            "Send a file and get back a report, a drawing and "
            "shop paperwork.\n\n"
            "📥 What I take\n"
            "• STEP / STP / FCStd — solid model\n"
            "• DWG — sorted out for you: solids → 3D, "
            "drawing → nesting\n"
            "• DXF — flat nesting\n"
            "• STL / OBJ / 3MF — mesh\n\n"
            "📤 What I return\n"
            "• Report: overall size, parts, holes by diameter\n"
            "• Drawing: isometric view with overall dimensions\n"
            "• Nesting: cut length, pierces, area\n"
            "• Mesh: volume and a check for holes and defects\n\n"
            "🔘 Buttons under the report\n"
            "• 🧊 A 3D viewer inside Telegram — tap a part to see "
            "its item number, quantity and holes\n"
            "• 📋 Bill of materials as CSV for Excel\n"
            "• 📐 Detail sheets: one per part, with run lengths "
            "and bend angles for bent ones\n"
            "• 📏 Dimensioned drawing from a DXF: a diameter on "
            "every hole, dimensions off a datum edge, an edge "
            "view and a pictorial\n"
            "• 🔍 File check: open and duplicated contours, the "
            "smallest hole, the thinnest bridges\n"
            "• 📍 Coordinates of every hole as CSV\n\n"
            "/language — language   /start — this message"
        )
    },
    "text_hint": {
        "uk": (
            "Я працюю з файлами, а не з текстом.\n\n"
            "Прикріпи креслення або модель — і я поверну "
            "звіт, візуалізацію та специфікацію.\n"
            "Підтримую: STEP, STP, FCStd, DWG, DXF, "
            "STL, OBJ, 3MF."
        ),
        "en": (
            "I work with files, not text.\n\n"
            "Attach a drawing or a model and I will return "
            "a report, a visualisation and a bill of materials.\n"
            "Supported: STEP, STP, FCStd, DWG, DXF, "
            "STL, OBJ, 3MF."
        )
    },
    # --------------------------------------------------------
    # Upload and analysis
    # --------------------------------------------------------

    "unsupported_format": {
        "uk": (
            "⚠️ Формат {format} не підтримується.\n\n"
            "Надішли, будь ласка, файл в одному з "
            "цих форматів:\n{formats}"
        ),
        "en": (
            "⚠️ The {format} format is not supported.\n\n"
            "Please send a file in one of "
            "these formats:\n{formats}"
        )
    },
    "received": {
        "uk": "{format} отримано: {name}\n{action}",
        "en": "{format} received: {name}\n{action}"
    },
    "action_cutmap": {
        "uk": "Запускаю аналіз розкрою...",
        "en": "Running nesting analysis..."
    },
    "action_mesh": {
        "uk": "Запускаю аналіз сітки...",
        "en": "Running mesh analysis..."
    },
    "action_cad": {
        "uk": "Запускаю CAD-аналіз...",
        "en": "Running CAD analysis..."
    },

    # Nobody minds waiting; they mind not knowing they have to.
    "wait_big": {
        "uk": (
            "\n⏳ Файл великий — на це піде близько хвилини, "
            "інколи дві. Я напишу, щойно буде готово."
        ),
        "en": (
            "\n⏳ It is a large file — this takes about a minute, "
            "sometimes two. I will write as soon as it is done."
        )
    },
    "wait_convert": {
        "uk": (
            "\n⏳ Конвертація DWG триває до хвилини."
        ),
        "en": (
            "\n⏳ Converting a DWG takes up to a minute."
        )
    },
    "wait_detail": {
        "uk": (
            "\n⏳ Кожна деталь малюється окремо — це може "
            "зайняти до хвилини."
        ),
        "en": (
            "\n⏳ Every part is drawn on its own sheet, so this "
            "can take up to a minute."
        )
    },

    "dwg_received": {
        "uk": "DWG отримано: {name}\nРозпізнаю вміст...",
        "en": "DWG received: {name}\nInspecting contents..."
    },
    "dwg_is_3d": {
        "uk": "✅ У файлі 3D-тіла.\n{action}",
        "en": "✅ The file contains 3D solids.\n{action}"
    },
    "dwg_is_2d": {
        "uk": "✅ У файлі плоске креслення.\n{action}",
        "en": "✅ The file contains a flat drawing.\n{action}"
    },
    "dwg_failed": {
        "uk": "❌ Не вдалося обробити DWG:\n{error}",
        "en": "❌ Could not process the DWG:\n{error}"
    },
    "dwg_needs_converter": {
        "uk": (
            "у файлі плоске креслення, а для нього "
            "потрібен ODA File Converter.\n\n"
            "Він безкоштовний і ставиться однією командою:\n"
            "winget install ODA.ODAFileConverter"
        ),
        "en": (
            "the file holds a flat drawing, which needs the "
            "ODA File Converter.\n\n"
            "It is free and installs with one command:\n"
            "winget install ODA.ODAFileConverter"
        )
    },

    "analysis_failed": {
        "uk": "❌ Аналіз завершився з помилкою.\n\n{error}",
        "en": "❌ Analysis failed.\n\n{error}"
    },
    "json_missing": {
        "uk": "❌ Аналіз завершився, але JSON не створено.",
        "en": "❌ Analysis finished but produced no JSON."
    },
    "json_unreadable": {
        "uk": "❌ Не вдалося прочитати результат аналізу:\n{error}",
        "en": "❌ Could not read the analysis result:\n{error}"
    },

    # --------------------------------------------------------
    # Visualisation
    # --------------------------------------------------------

    "building_render": {
        "uk": "🖼️ Будую візуалізацію...",
        "en": "🖼️ Building the visualisation..."
    },
    "render_failed": {
        "uk": "⚠️ Не вдалося побудувати візуалізацію:\n{error}",
        "en": "⚠️ Could not build the visualisation:\n{error}"
    },
    "caption_cutmap": {
        "uk": (
            "🖼️ Карта розкрою (отвори червоним, "
            "відкриті контури синім)"
        ),
        "en": (
            "🖼️ Cut map (holes in red, "
            "open contours in blue)"
        )
    },
    "caption_mesh": {
        "uk": "🖼️ Ізометричний вигляд сітки",
        "en": "🖼️ Isometric view of the mesh"
    },
    "caption_iso": {
        "uk": "🖼️ Ізометрична візуалізація (отвори червоним)",
        "en": "🖼️ Isometric visualisation (holes in red)"
    },

    "json_caption": {
        "uk": "📄 Повний результат аналізу",
        "en": "📄 Full analysis result"
    },
    "json_too_big": {
        "uk": (
            "📄 Повний JSON завеликий для Telegram "
            "({size:.1f} МБ) і залишився на сервері:\n{path}"
        ),
        "en": (
            "📄 The full JSON is too large for Telegram "
            "({size:.1f} MB) and stayed on the server:\n{path}"
        )
    },

    # --------------------------------------------------------
    # Extra actions
    # --------------------------------------------------------

    "extras_prompt": {
        "uk": "Що ще зробити з цим файлом?",
        "en": "Anything else for this file?"
    },
    "btn_spec": {
        "uk": "📋 Специфікація",
        "en": "📋 Bill of materials"
    },
    "btn_detail": {
        "uk": "📐 Деталювання (PDF)",
        "en": "📐 Detail sheets (PDF)"
    },
    "btn_viewer": {
        "uk": "🧊 Подивитись у 3D",
        "en": "🧊 Open in 3D"
    },
    "btn_manufacturing": {
        "uk": "🔍 Перевірити файл і зміряти",
        "en": "🔍 Check the file and measure"
    },
    "btn_holes": {
        "uk": "📍 Отвори у CSV ({count})",
        "en": "📍 Holes as CSV ({count})"
    },
    # --------------------------------------------------------
    # The standard sheet, for customers who want the stamp
    # --------------------------------------------------------

    "col_applied": {"uk": "Перв. застосув.", "en": "First used in"},
    "col_reference": {"uk": "Довід. №", "en": "Ref. no."},
    "col_signed_1": {"uk": "Підпис і дата", "en": "Signature and date"},
    "col_duplicate": {"uk": "Інв. № дубл.", "en": "Dupl. inv. no."},
    "col_replaced": {"uk": "Взам. інв. №", "en": "Repl. inv. no."},
    "col_signed_2": {"uk": "Підпис і дата", "en": "Signature and date"},
    "col_original": {"uk": "Інв. № прим.", "en": "Orig. inv. no."},

    "head_change": {"uk": "Зм.", "en": "Chg."},
    "head_sheet": {"uk": "Арк.", "en": "Sh."},
    "head_document": {"uk": "№ докум.", "en": "Doc. no."},
    "head_signature": {"uk": "Підп.", "en": "Sign."},
    "head_date": {"uk": "Дата", "en": "Date"},

    "stage_designed": {"uk": "Розроб.", "en": "Drawn"},
    "stage_checked": {"uk": "Перев.", "en": "Checked"},
    "stage_technical": {"uk": "Т.контр.", "en": "Tech."},
    "stage_control": {"uk": "Н.контр.", "en": "Norm."},
    "stage_approved": {"uk": "Затв.", "en": "Appr."},

    "head_letter": {"uk": "Літ.", "en": "Lit."},
    "head_mass": {"uk": "Маса", "en": "Mass"},
    "head_scale": {"uk": "Масштаб", "en": "Scale"},
    "head_page": {"uk": "Аркуш", "en": "Sheet"},
    "head_pages": {"uk": "Аркушів", "en": "Sheets"},

    "material_sheet": {
        "uk": "Лист {thickness} мм",
        "en": "Sheet {thickness} mm"
    },

    "req_file": {
        "uk": (
            "Деталь виготовити згідно з файлом «{file}»; "
            "розміри зняті з нього автоматично."
        ),
        "en": (
            "Manufacture the part to the file «{file}»; the "
            "dimensions were measured from it automatically."
        )
    },
    "req_turned": {
        "uk": "На кресленику деталь повернуто на {angle}° відносно файлу.",
        "en": "The part is turned {angle}° here against the file."
    },
    "req_nominal": {
        "uk": (
            "Товщину не задано: на загальному вигляді вона "
            "умовна, вид з торця не будувався."
        ),
        "en": (
            "No thickness was given: the pictorial shows a "
            "nominal one and there is no edge view."
        )
    },
    "req_tolerances": {
        "uk": (
            "Граничні відхилення, шорсткість і припуски не "
            "задані — узгодити з виробником."
        ),
        "en": (
            "Tolerances, surface finish and allowances are not "
            "given here: agree them with the manufacturer."
        )
    },

    "part_of_nest": {
        "uk": "деталь {index} з {total} · {count} шт. у файлі",
        "en": "part {index} of {total} · {count} on the sheet"
    },
    "opt_nest_one": {
        "uk": "🧩 Розкрій: один аркуш на файл",
        "en": "🧩 Nest: one sheet for the file"
    },
    "opt_nest_each": {
        "uk": "🧩 Розкрій: аркуш на кожну деталь",
        "en": "🧩 Nest: a sheet for every part"
    },

    "opt_title": {
        "uk": "Що поставити на кресленику?",
        "en": "What goes on the drawing?"
    },
    "opt_thickness": {
        "uk": "⬛ Товщина: {value}",
        "en": "⬛ Thickness: {value}"
    },
    "opt_thickness_none": {
        "uk": "не вказана",
        "en": "not given"
    },
    "opt_shape_on": {
        "uk": "📐 Радіуси й кути: так",
        "en": "📐 Radii and angles: yes"
    },
    "opt_shape_off": {
        "uk": "📐 Радіуси й кути: ні",
        "en": "📐 Radii and angles: no"
    },
    "opt_details_auto": {
        "uk": "🔍 Виносні елементи: де тісно",
        "en": "🔍 Enlarged details: where it is crowded"
    },
    "opt_details_all": {
        "uk": "🔍 Виносні елементи: усі вузли",
        "en": "🔍 Enlarged details: every corner"
    },
    "opt_details_off": {
        "uk": "🔍 Виносні елементи: ні",
        "en": "🔍 Enlarged details: no"
    },
    "opt_style_own": {
        "uk": "📄 Оформлення: ForgeMind",
        "en": "📄 Sheet: ForgeMind"
    },
    "opt_style_eskd": {
        "uk": "📄 Оформлення: ЄСКД зі штампом",
        "en": "📄 Sheet: the standard one, with the stamp"
    },
    "opt_build": {
        "uk": "✅ Побудувати кресленик",
        "en": "✅ Build the drawing"
    },

    "btn_drawing": {
        "uk": "📏 Кресленик з розмірами",
        "en": "📏 Dimensioned drawing"
    },
    "drawing_only_flat": {
        "uk": (
            "⚠️ Кресленик з розмірами будується з плоского DXF, "
            "а тут {format}."
        ),
        "en": (
            "⚠️ The dimensioned drawing needs a flat DXF; "
            "this is {format}."
        )
    },
    "drawing_pick_thickness": {
        "uk": (
            "Якої товщини лист? У DXF товщини немає, а вид з "
            "торця без неї не побудувати."
        ),
        "en": (
            "How thick is the plate? A DXF does not carry a "
            "thickness, and the edge view needs one."
        )
    },
    "btn_thickness_skip": {
        "uk": "Не вказувати",
        "en": "Skip"
    },
    "drawing_building": {
        "uk": "📏 Кресленик будується…",
        "en": "📏 Drawing the sheet…"
    },
    "drawing_failed": {
        "uk": "⚠️ Не вдалося побудувати кресленик:\n{error}",
        "en": "⚠️ Could not build the drawing:\n{error}"
    },
    "drawing_caption": {
        "uk": "📏 Кресленик: {size} мм, лист {thickness} мм",
        "en": "📏 Drawing: {size} mm, {thickness} mm plate"
    },
    "drawing_caption_plain": {
        "uk": (
            "📏 Кресленик: {size} мм. Товщину не вказано — "
            "виду з торця немає."
        ),
        "en": (
            "📏 Drawing: {size} mm. No thickness given, so there "
            "is no edge view."
        )
    },
    "drawing_pdf": {
        "uk": "Той самий кресленик у PDF — для друку.",
        "en": "The same drawing as a PDF, for printing."
    },

    "file_gone": {
        "uk": "⚠️ Файл більше недоступний — надішли його ще раз.",
        "en": "⚠️ That file is gone — please send it again."
    },
    "no_parts": {
        "uk": "⚠️ У цьому файлі немає окремих деталей.",
        "en": "⚠️ This file has no separate parts."
    },
    "detail_only_3d": {
        "uk": (
            "⚠️ Деталювання будується лише з 3D-моделі "
            "(STEP, FCStd), а тут {format}."
        ),
        "en": (
            "⚠️ Detail sheets need a 3D model "
            "(STEP, FCStd); this is {format}."
        )
    },
    "detail_building": {
        "uk": "📐 Будую деталювання: {count} {word}…",
        "en": "📐 Building detail sheets: {count} {word}…"
    },
    "detail_failed": {
        "uk": "⚠️ Не вдалося побудувати деталювання:\n{error}",
        "en": "⚠️ Could not build the detail sheets:\n{error}"
    },
    "detail_caption": {
        "uk": (
            "📐 Деталювання: {count} {word}, "
            "по одному на кожну унікальну деталь"
        ),
        "en": (
            "📐 Detail sheets: {count} {word}, "
            "one per unique part"
        )
    },
    "spec_caption": {
        "uk": "📋 Специфікація у CSV (Excel)",
        "en": "📋 Bill of materials as CSV (Excel)"
    },
    "holes_none": {
        "uk": "⚠️ Отворів у цьому файлі немає.",
        "en": "⚠️ This file has no holes."
    },
    "holes_caption": {
        "uk": "📍 Координати всіх отворів ({count} шт.)",
        "en": "📍 Coordinates of all holes ({count})"
    },

    # --------------------------------------------------------
    # Reports: shared
    # --------------------------------------------------------

    "report_cad_done": {
        "uk": "✅ CAD-аналіз завершено",
        "en": "✅ CAD analysis complete"
    },
    "report_dxf_done": {
        "uk": "✅ DXF-аналіз завершено",
        "en": "✅ DXF analysis complete"
    },
    "report_mesh_done": {
        "uk": "✅ Аналіз сітки завершено",
        "en": "✅ Mesh analysis complete"
    },
    "parts_count": {
        "uk": "Деталей: {count}",
        "en": "Parts: {count}"
    },
    "size_3d": {
        "uk": "Габарит: {x} × {y} × {z} мм",
        "en": "Size: {x} × {y} × {z} mm"
    },
    "size_2d": {
        "uk": "Габарит: {x} × {y} мм",
        "en": "Size: {x} × {y} mm"
    },
    "volume": {
        "uk": "Об'єм: {value} мм³",
        "en": "Volume: {value} mm³"
    },
    "solids": {
        "uk": "Тіл: {count}",
        "en": "Solids: {count}"
    },
    "faces": {
        "uk": "Граней: {count}",
        "en": "Faces: {count}"
    },
    "edges": {
        "uk": "Ребер: {count}",
        "en": "Edges: {count}"
    },
    "holes_total": {
        "uk": "🔧 Отворів: {count} — розгорни для переліку ↓",
        "en": "🔧 Holes: {count} — expand for the list ↓"
    },
    "holes_round_total": {
        "uk": "🔧 Круглих отворів: {count} — розгорни для переліку ↓",
        "en": "🔧 Round holes: {count} — expand for the list ↓"
    },
    "holes_none_found": {
        "uk": "Отворів не знайдено.",
        "en": "No holes found."
    },
    "holes_round_none": {
        "uk": "Круглих отворів не знайдено.",
        "en": "No round holes found."
    },
    "hole_group_3d": {
        "uk": "Ø{diameter} × {length} мм — {count} шт.",
        "en": "Ø{diameter} × {length} mm — {count} pcs"
    },
    "hole_group_2d": {
        "uk": "Ø{diameter} мм — {count} шт.",
        "en": "Ø{diameter} mm — {count} pcs"
    },
    "hole_coords_header": {
        "uk": "📍 Координати отворів:",
        "en": "📍 Hole coordinates:"
    },
    "hole_coords_too_many": {
        "uk": (
            "📍 Отворів забагато ({count}) для списку в чаті — "
            "повні координати у JSON."
        ),
        "en": (
            "📍 Too many holes ({count}) to list in chat — "
            "full coordinates are in the JSON."
        )
    },

    # --------------------------------------------------------
    # Reports: DXF
    # --------------------------------------------------------

    "contours_total": {
        "uk": "Контурів: {count}",
        "en": "Contours: {count}"
    },
    "contours_breakdown": {
        "uk": (
            "  зовнішніх: {outer}, внутрішніх: {inner}, "
            "відкритих: {open}"
        ),
        "en": (
            "  outer: {outer}, inner: {inner}, "
            "open: {open}"
        )
    },
    "cut_length": {
        "uk": "Довжина різу: {value} мм",
        "en": "Cut length: {value} mm"
    },
    "pierces": {
        "uk": "Врізань: {count}",
        "en": "Pierces: {count}"
    },
    "area": {
        "uk": "Площа: {value} мм²",
        "en": "Area: {value} mm²"
    },
    "perimeter": {
        "uk": "Периметр: {value} мм",
        "en": "Perimeter: {value} mm"
    },
    "units_inches": {
        "uk": "ℹ️ Файл у дюймах — перерахував у міліметри.",
        "en": "ℹ️ The file is in inches — converted to millimetres."
    },
    "units_odd": {
        "uk": (
            "⚠️ У файлі одиниці вказані як «{declared}», "
            "але рахую в міліметрах."
        ),
        "en": (
            "⚠️ The file declares units as \"{declared}\", "
            "but millimetres are used."
        )
    },

    # --------------------------------------------------------
    # Reports: mesh
    # --------------------------------------------------------

    "triangles": {
        "uk": "Трикутників: {count}",
        "en": "Triangles: {count}"
    },
    "surface_area": {
        "uk": "Площа поверхні: {value} мм²",
        "en": "Surface area: {value} mm²"
    },
    "volume_unavailable": {
        "uk": "Об'єм: не визначений (сітка незамкнена)",
        "en": "Volume: unavailable (mesh is not closed)"
    },
    "mesh_check_header": {
        "uk": "🔍 Перевірка сітки:",
        "en": "🔍 Mesh check:"
    },
    "mesh_ok": {
        "uk": "Сітка герметична, дефектів немає.",
        "en": "Mesh is watertight, no defects."
    },
    "mesh_open_edges": {
        "uk": "⚠️ Відкритих ребер: {count} — модель має діри.",
        "en": "⚠️ Open edges: {count} — the model has holes."
    },
    "mesh_non_manifold": {
        "uk": (
            "Non-manifold ребер: {count} — зазвичай це "
            "кілька тіл, що дотикаються."
        ),
        "en": (
            "Non-manifold edges: {count} — usually several "
            "bodies touching."
        )
    },
    "mesh_degenerate": {
        "uk": "Вироджених трикутників: {count}",
        "en": "Degenerate triangles: {count}"
    },
    "mesh_no_units": {
        "uk": (
            "ℹ️ Меш-формати не зберігають одиниць виміру — "
            "рахую в міліметрах."
        ),
        "en": (
            "ℹ️ Mesh formats carry no units — "
            "millimetres are assumed."
        )
    },

    # --------------------------------------------------------
    # Manufacturability
    # --------------------------------------------------------

    "mfg_nothing": {
        "uk": "⚠️ У цьому файлі нема чого міряти.",
        "en": "⚠️ There is nothing to measure in this file."
    },

    "mfg_faults": {
        "uk": "⚠️ У файлі знайдено помилок: {count} — розгорни ↓",
        "en": "⚠️ Faults found in the file: {count} — expand ↓"
    },
    "mfg_no_faults": {
        "uk": "✅ Помилок у файлі немає — виміри всередині ↓",
        "en": "✅ No faults in the file — measurements inside ↓"
    },
    "mfg_problems": {
        "uk": "Помилки у файлі (не залежать від верстата):",
        "en": "Faults in the file, whatever the machine:"
    },
    "mfg_measured": {
        "uk": "Виміряно:",
        "en": "Measured:"
    },
    "mfg_no_thresholds": {
        "uk": (
            "Оцінку не даю — вона залежить від твого верстата. "
            "Дай мінімальні діаметри, перемички й радіуси по "
            "товщинах, і я поставлю поруч «проходить / ні»."
        ),
        "en": (
            "No verdict here: that depends on your machine. Give me "
            "minimum diameters, bridges and radii by thickness and "
            "each line gets a pass or a fail beside it."
        )
    },

    "measure_hole": {
        "uk": "найменший отвір Ø{diameter} у {thickness} мм (поз. {position})",
        "en": "smallest hole Ø{diameter} in {thickness} mm (item {position})"
    },
    "measure_hole_flat": {
        "uk": "найменший отвір Ø{diameter}",
        "en": "smallest hole Ø{diameter}"
    },
    "measure_bridge": {
        "uk": (
            "найтонша перемичка між отворами {value} мм "
            "у {thickness} мм (поз. {position})"
        ),
        "en": (
            "thinnest metal between holes {value} mm in "
            "{thickness} mm (item {position})"
        )
    },
    "measure_bridge_flat": {
        "uk": "найтонша перемичка між отворами {value} мм",
        "en": "thinnest metal between holes {value} mm"
    },
    "measure_flange": {
        "uk": (
            "найкоротша полиця під згин {value} мм "
            "у {thickness} мм (поз. {position})"
        ),
        "en": (
            "shortest flange to bend {value} mm in {thickness} mm "
            "(item {position})"
        )
    },
    "measure_radius": {
        "uk": (
            "найменший радіус згину {value} мм "
            "у {thickness} мм (поз. {position})"
        ),
        "en": (
            "tightest bend radius {value} mm in {thickness} mm "
            "(item {position})"
        )
    },
    "measure_biggest": {
        "uk": "найбільша деталь {length} × {width} × {thickness} мм",
        "en": "largest part {length} × {width} × {thickness} mm"
    },
    "measure_sheet": {
        "uk": "габарит розкрою {length} × {width} мм",
        "en": "nest size {length} × {width} mm"
    },

    "mfg_duplicate": {
        "uk": (
            "Накладені контури: {count} — машина ріже той самий "
            "слід двічі, друга подача йде по повітрю."
        ),
        "en": (
            "Contours lying on top of another: {count} — the "
            "machine cuts the same path twice and the second pass "
            "runs in air."
        )
    },
    "mfg_degenerate": {
        "uk": (
            "Порожні контури: {count} — нічого не оточують, але "
            "кожен коштує врізання."
        ),
        "en": (
            "Empty contours: {count} — they enclose nothing and "
            "each one still costs a pierce."
        )
    },
    "mfg_open": {
        "uk": (
            "Відкриті контури: {count} — не ріжуться як замкнений "
            "шлях, машина їх пропустить."
        ),
        "en": (
            "Open contours: {count} — they will not cut as a "
            "closed path and the machine will skip them."
        )
    },
    "mfg_mesh_open": {
        "uk": (
            "Сітка незамкнена, відкритих ребер: {count}. Для "
            "різання чи друку її треба спершу зашити."
        ),
        "en": (
            "The mesh is not closed: {count} open edges. It has to "
            "be repaired before cutting or printing."
        )
    },

    # --------------------------------------------------------
    # Bill of materials
    # --------------------------------------------------------

    "bom_title": {
        "uk": "📋 Специфікація",
        "en": "📋 Bill of materials"
    },
    "bom_total": {
        "uk": "Всього деталей: {count}",
        "en": "Total parts: {count}"
    },
    "bom_unique": {
        "uk": "Унікальних: {count} — розгорни для переліку ↓",
        "en": "Unique: {count} — expand for the list ↓"
    },
    "bom_volume": {
        "uk": "Сумарний об'єм: {value} мм³",
        "en": "Total volume: {value} mm³"
    },
    "bom_row": {
        "uk": "{position}. {name} — {count} шт.",
        "en": "{position}. {name} — {count} pcs"
    },
    "bom_row_holes": {
        "uk": ", отворів: {count}",
        "en": ", holes: {count}"
    },
    "bom_more": {
        "uk": "… ще {count} {word} — у файлі CSV.",
        "en": "… {count} more {word} — see the CSV."
    },

    "csv_number": {"uk": "№", "en": "No."},
    "csv_name": {"uk": "Позначення", "en": "Designation"},
    "csv_qty": {"uk": "Кількість", "en": "Quantity"},
    "csv_size_x": {"uk": "Габарит X, мм", "en": "Size X, mm"},
    "csv_size_y": {"uk": "Габарит Y, мм", "en": "Size Y, mm"},
    "csv_size_z": {"uk": "Габарит Z, мм", "en": "Size Z, mm"},
    "csv_volume": {"uk": "Об'єм, мм³", "en": "Volume, mm³"},
    "csv_holes": {"uk": "Отворів", "en": "Holes"},
    "csv_faces": {"uk": "Граней", "en": "Faces"},
    "csv_edges": {"uk": "Ребер", "en": "Edges"},
    "csv_diameter": {"uk": "Ø, мм", "en": "Ø, mm"},
    "csv_length": {"uk": "Довжина, мм", "en": "Length, mm"},
    "csv_part": {"uk": "Деталь", "en": "Part"},
    "csv_axis_x": {"uk": "Вісь X", "en": "Axis X"},
    "csv_axis_y": {"uk": "Вісь Y", "en": "Axis Y"},
    "csv_axis_z": {"uk": "Вісь Z", "en": "Axis Z"},

    # --------------------------------------------------------
    # Drawing sheets: shared furniture
    #
    # These go on the sheets themselves, so they stay short: a
    # title block cell is 530 px wide and does not wrap.
    # --------------------------------------------------------

    "unit_mm": {"uk": "мм", "en": "mm"},

    "count_pieces": {
        "uk": "{count} шт.",
        "en": "{count} pcs"
    },

    "hole_row_3d": {
        "uk": "Ø{diameter} × {length} мм",
        "en": "Ø{diameter} × {length} mm"
    },
    "hole_row_2d": {
        "uk": "Ø{diameter} мм",
        "en": "Ø{diameter} mm"
    },

    "lbl_date": {"uk": "Дата", "en": "Date"},
    "lbl_file": {"uk": "Файл", "en": "File"},
    "lbl_size": {"uk": "Габарит", "en": "Overall"},
    "lbl_content": {"uk": "Склад", "en": "Content"},
    "lbl_quantity": {"uk": "Кількість", "en": "Quantity"},
    "lbl_volume": {"uk": "Об'єм", "en": "Volume"},
    "lbl_holes": {"uk": "Отвори", "en": "Holes"},
    "lbl_source": {"uk": "Виріб", "en": "Assembly"},
    "lbl_triangles": {"uk": "Трикутників", "en": "Triangles"},
    "lbl_surface": {"uk": "Поверхня", "en": "Surface"},
    "lbl_mesh": {"uk": "Сітка", "en": "Mesh"},
    "lbl_developed": {
        "uk": "Довжина по осі",
        "en": "Length along axis"
    },
    "lbl_cut": {"uk": "Різ", "en": "Cut"},
    "lbl_pierces": {"uk": "врізань", "en": "pierces"},
    "lbl_contours": {
        "uk": "Контурів (зовн./внутр./відкр.)",
        "en": "Contours (outer/inner/open)"
    },
    "lbl_area": {"uk": "Площа, мм²", "en": "Area, mm²"},
    "lbl_perimeter": {"uk": "Периметр, мм", "en": "Perimeter, mm"},

    "callout_count": {"uk": "{count} отв.", "en": "{count} holes"},
    "callout_slots": {"uk": "{count} паз.", "en": "{count} slots"},
    "legend_slot": {"uk": "Паз {size} мм", "en": "Slot {size} mm"},

    "lbl_thickness": {"uk": "Товщина", "en": "Thickness"},

    "note_mm": {
        "uk": "Розміри в міліметрах",
        "en": "Dimensions in millimetres"
    },
    "note_no_tolerances": {
        "uk": "відхилення, шорсткість і припуски — за виробником",
        "en": "tolerances, finish and allowances are the maker's"
    },

    "view_holes": {"uk": "ОТВОРИ", "en": "HOLES"},
    "view_callout": {
        "uk": "ОТВОРИ · РАДІУСИ · КУТИ",
        "en": "HOLES · RADII · ANGLES"
    },
    "view_dims": {"uk": "РОЗМІРИ", "en": "DIMENSIONS"},
    "view_edge": {"uk": "ВИД З ТОРЦЯ", "en": "EDGE VIEW"},
    "view_iso": {"uk": "ЗАГАЛЬНИЙ ВИГЛЯД", "en": "PICTORIAL"},
    "view_iso_nominal": {
        "uk": "ЗАГАЛЬНИЙ ВИГЛЯД · товщина умовна",
        "en": "PICTORIAL · nominal thickness"
    },

    "note_turned": {
        "uk": "деталь повернуто на {angle}°",
        "en": "part turned by {angle}°"
    },
    "note_inches": {
        "uk": "Кресленик у дюймах, розміри переведені в мм",
        "en": "Drawn in inches, dimensions converted to mm"
    },


    "tag_iso": {"uk": "ІЗОМЕТРІЯ", "en": "ISOMETRIC"},
    "tag_mesh": {"uk": "СІТКА", "en": "MESH"},
    "tag_detail": {"uk": "ДЕТАЛЮВАННЯ", "en": "DETAIL"},
    "tag_cut": {"uk": "РОЗКРІЙ", "en": "CUT MAP"},
    "tag_drawing": {"uk": "КРЕСЛЕНИК", "en": "DRAWING"},
    "sheet_header_details": {
        "uk": "ForgeMind · Виносні елементи",
        "en": "ForgeMind · Enlarged details"
    },
    "note_details": {
        "uk": "Ті самі розміри, збільшено · відхилення — за виробником",
        "en": "The same dimensions, enlarged · tolerances are the maker's"
    },
    "tag_details": {"uk": "ВИНОСКИ", "en": "DETAILS"},
    "lbl_details": {"uk": "Виноски", "en": "Details"},

    "sheet_header_drawing": {
        "uk": "ForgeMind · Кресленик деталі",
        "en": "ForgeMind · Part drawing"
    },
    "sheet_header_iso": {
        "uk": "ForgeMind · Ізометрія",
        "en": "ForgeMind · Isometric view"
    },
    "sheet_header_mesh": {
        "uk": "ForgeMind · Ізометрія сітки",
        "en": "ForgeMind · Mesh view"
    },
    "sheet_header_cut": {
        "uk": "ForgeMind · Карта розкрою",
        "en": "ForgeMind · Cut map"
    },


    "legend_holes": {"uk": "ОТВОРИ", "en": "HOLES"},
    "legend_runs": {"uk": "ДІЛЯНКИ", "en": "SEGMENTS"},
    "legend_run_note": {
        "uk": "Довжини по осі деталі, кути між ділянками",
        "en": "Lengths along the part's axis, angles between runs"
    },
    "run_row": {"uk": "Ділянка {number}", "en": "Segment {number}"},
    "run_total": {"uk": "Разом", "en": "Total"},
    "legend_more_types": {
        "uk": "… ще {count} типів — усі у CSV",
        "en": "… {count} more types — all in the CSV"
    },
    "legend_unnumbered": {
        "uk": "Отворів надто багато для нумерації — координати у CSV",
        "en": "Too many holes to number — coordinates in the CSV"
    },
    "legend_coordinates": {
        "uk": "Повні координати — у CSV",
        "en": "Full coordinates — in the CSV"
    },

    "mesh_state_ok": {
        "uk": "герметична",
        "en": "watertight"
    },
    "mesh_state_open": {
        "uk": "{count} відкритих ребер",
        "en": "{count} open edges"
    },
    "mesh_state_non_manifold": {
        "uk": "{count} non-manifold",
        "en": "{count} non-manifold"
    },

    # --------------------------------------------------------
    # Detail sheets
    # --------------------------------------------------------

    "sheet_position": {
        "uk": "Поз. {position} — {name}",
        "en": "Item {position} — {name}"
    },
    "sheet_of": {
        "uk": "{file}   ·   аркуш {page} з {pages}",
        "en": "{file}   ·   sheet {page} of {pages}"
    },
    "sheet_view_plane": {
        "uk": "Вигляд у площині деталі",
        "en": "View in the part's own plane"
    },
    "sheet_view_profile": {
        "uk": "Профіль деталі з розмірами ділянок",
        "en": "Part profile with run dimensions"
    },
    "sheet_iso": {
        "uk": "Ізометрія деталі",
        "en": "Isometric view"
    },
    "sheet_locator": {
        "uk": "Розташування у виробі",
        "en": "Location in the assembly"
    },
    "sheet_rotated": {
        "uk": (
            "Деталь повернуто для креслення — "
            "розміри по її власних осях"
        ),
        "en": (
            "The part is rotated for the drawing — "
            "sizes are along its own axes"
        )
    },
    "sheet_sent": {
        "uk": "📐 Аркуш деталювання, поз. {position}",
        "en": "📐 Detail sheet, item {position}"
    },
    "sheet_thickness": {
        "uk": "s{value}",
        "en": "s{value}"
    },
}


def normalize(language):

    return language if language in LANGUAGES else DEFAULT_LANGUAGE


def t(language, key, **kwargs):
    """Looks up a string, falling back to the default language."""

    entry = STRINGS.get(key)

    if entry is None:
        return key

    text = entry.get(normalize(language)) or entry[DEFAULT_LANGUAGE]

    if kwargs:

        try:
            return text.format(**kwargs)
        except (KeyError, IndexError, ValueError):
            return text

    return text


def plural(language, count, one, few, many):
    """Picks the right noun form for a count.

    Ukrainian needs three forms (1 аркуш, 2 аркуші, 5 аркушів);
    English needs two, so `few` is reused as its plural.
    """

    if normalize(language) != "uk":
        return one if count == 1 else few

    tail = abs(count) % 100

    if 11 <= tail <= 14:
        return many

    last = tail % 10

    if last == 1:
        return one

    if 2 <= last <= 4:
        return few

    return many


def sheets_word(language, count):

    return plural(
        language,
        count,
        "аркуш" if normalize(language) == "uk" else "page",
        "аркуші" if normalize(language) == "uk" else "pages",
        "аркушів"
    )


def items_word(language, count):

    return plural(
        language,
        count,
        "позиція" if normalize(language) == "uk" else "item",
        "позиції" if normalize(language) == "uk" else "items",
        "позицій"
    )


def parts_word(language, count):

    return plural(
        language,
        count,
        "деталь" if normalize(language) == "uk" else "part",
        "деталі" if normalize(language) == "uk" else "parts",
        "деталей"
    )


def holes_word(language, count):

    return plural(
        language,
        count,
        "отвір" if normalize(language) == "uk" else "hole",
        "отвори" if normalize(language) == "uk" else "holes",
        "отворів"
    )
