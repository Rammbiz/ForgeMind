import asyncio
import hashlib
import html
import json
import logging
import os
import re
import socket
import subprocess
import sys
import time
import uuid

from logging.handlers import RotatingFileHandler

from aiogram import Bot, Dispatcher, F, Router
from aiogram.filters import Command, CommandStart
from aiogram.types import (
    CallbackQuery,
    FSInputFile,
    InputMediaPhoto,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    Message,
    WebAppInfo
)
from dotenv import load_dotenv

import manufacturing
import tunnel
import webapp

from bom import (
    build_bom,
    build_bom_text,
    write_bom_csv,
    write_holes_csv
)

from i18n import (
    DEFAULT_LANGUAGE,
    LANGUAGE_NAMES,
    LANGUAGES,
    normalize,
    sheets_word,
    t
)


# ============================================================
# CONFIG
# ============================================================

load_dotenv()

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")

FREECAD = r"C:\Program Files\FreeCAD 1.1\bin\freecadcmd.exe"

# 3D pipeline: runs inside FreeCAD.
ANALYZER = r"C:\ForgeMind\analyzer.py"
RENDERER = r"C:\ForgeMind\render_shaded.py"
DETAIL_SHEETS = r"C:\ForgeMind\detail_sheets.py"

# 2D and mesh pipelines: plain Python, FreeCAD is not involved.
DXF_ANALYZER = r"C:\ForgeMind\dxf_analyzer.py"
DXF_RENDERER = r"C:\ForgeMind\render_dxf.py"
DXF_DRAWING = r"C:\ForgeMind\detail_dxf.py"

MESH_ANALYZER = r"C:\ForgeMind\mesh_analyzer.py"
MESH_RENDERER = r"C:\ForgeMind\render_mesh.py"

# Exports the mesh the in-chat 3D viewer shows.
GLB_EXPORTER = r"C:\ForgeMind\export_glb.py"

FILES_DIR = r"C:\ForgeMind\files"

LOG_FILE = r"C:\ForgeMind\files\bot.log"

# Per-chat language choice, kept on disk so it survives restarts.
LANGUAGE_FILE = r"C:\ForgeMind\files\languages.json"

ANALYSIS_TIMEOUT = 300
RENDER_TIMEOUT = 120

DRAWING_TIMEOUT = 180

# One sheet per unique part, so a large assembly takes a while.
DETAIL_TIMEOUT = 600

GLB_TIMEOUT = 180

# The Mini App server listens here; only the tunnel talks to it.
VIEWER_PORT = 47318

# How often the public address is re-checked. A quick tunnel can
# rotate at any moment, and a button carrying the old address opens
# on "Try again".
VIEWER_REFRESH = 45

# Signs the short-lived model links the Mini App is given.
# Derived from the bot token so it survives a restart without
# being stored anywhere, and cannot be guessed without it.
LINK_SECRET = hashlib.sha256(
    ("forgemind-viewer-links:" + (TOKEN or "")).encode("utf-8")
).hexdigest()

# Above this an upload takes long enough that saying so is
# kinder than leaving the operator watching a silent chat.
BIG_FILE_BYTES = 1_000_000

MAX_LISTED_HOLE_COORDS = 20

# Telegram's own limit is 4096 characters, and an expandable quote
# counts toward it like anything else.
MAX_MESSAGE_LENGTH = 3800

# Telegram refuses bot uploads above 50 MB.
MAX_DOCUMENT_BYTES = 45 * 1024 * 1024

# Uploads and their results are cleaned up after this long.
FILE_RETENTION_DAYS = 7

# Single-instance guard. Telegram allows only one poller per
# token: a second copy (autostart plus a manual launch) makes
# both fail with a 409 conflict.
#
# Must stay below 49152, the start of the Windows dynamic port
# range: a port inside that range gets grabbed at random by
# outgoing connections and the bot would refuse to start.
SINGLE_INSTANCE_PORT = 47317

STEP_EXTENSIONS = {
    ".step",
    ".stp",
    ".fcstd"
}

DXF_EXTENSIONS = {
    ".dxf"
}

# DWG is a closed format that no open library reads. Rhino's
# core does, headlessly, and it also resolves the ACIS bodies
# that AutoCAD stores inside 3D drawings — which a DWG-to-DXF
# converter cannot do, since ACIS survives that trip unreadable.
DWG_EXTENSIONS = {
    ".dwg"
}

RHINO_CONVERTER = r"C:\ForgeMind\rhino_convert.ps1"

DWG_TIMEOUT = 300

MESH_EXTENSIONS = {
    ".stl",
    ".obj",
    ".3mf"
}

SUPPORTED_EXTENSIONS = (
    STEP_EXTENSIONS
    | DXF_EXTENSIONS
    | DWG_EXTENSIONS
    | MESH_EXTENSIONS
)

# Extensions whose plain uppercase spelling looks wrong.
FORMAT_NAMES = {
    ".fcstd": "FCStd"
}


def supported_formats_text():
    """Human-readable format list, grouped by pipeline.

    Derived from the extension sets rather than written out, so
    adding a format cannot leave this list stale.
    """

    names = []

    for group in (
        STEP_EXTENSIONS,
        DWG_EXTENSIONS,
        DXF_EXTENSIONS,
        MESH_EXTENSIONS
    ):

        names.extend(
            sorted(
                FORMAT_NAMES.get(e, e.lstrip(".").upper())
                for e in group
            )
        )

    return ", ".join(names)


# ============================================================
# LOGGING
#
# Messages stay ASCII: this Windows console cannot encode
# emoji, and a logging call must never take the bot down.
# ============================================================

def setup_logging():

    os.makedirs(FILES_DIR, exist_ok=True)

    formatter = logging.Formatter(
        "%(asctime)s  %(levelname)-7s  %(message)s"
    )

    file_handler = RotatingFileHandler(
        LOG_FILE,
        maxBytes=2 * 1024 * 1024,
        backupCount=3,
        encoding="utf-8"
    )

    file_handler.setFormatter(formatter)

    handlers = [file_handler]

    # The autostart task runs pythonw.exe, which has no console:
    # sys.stderr is None there and a stream handler would fail on
    # every log call.
    if sys.stderr is not None:

        console = logging.StreamHandler()
        console.setFormatter(formatter)

        handlers.append(console)

    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.handlers = handlers

    # aiogram's per-update chatter is not useful here.
    logging.getLogger("aiogram").setLevel(logging.WARNING)

    return logging.getLogger("forgemind")


log = setup_logging()


# ============================================================
# TELEGRAM
# ============================================================

dp = Dispatcher()
router = Router()

dp.include_router(router)

bot = Bot(token=TOKEN)


# ============================================================
# HELPERS
# ============================================================

# ============================================================
# LANGUAGE
# ============================================================

def load_languages():

    try:

        with open(LANGUAGE_FILE, "r", encoding="utf-8") as f:
            return {
                str(k): normalize(v)
                for k, v in json.load(f).items()
            }

    except Exception:
        return {}


LANGUAGE_BY_CHAT = load_languages()


def save_languages():

    try:

        with open(LANGUAGE_FILE, "w", encoding="utf-8") as f:
            json.dump(LANGUAGE_BY_CHAT, f, ensure_ascii=False)

    except OSError as e:
        log.warning("Could not save language choice: %s", e)


def language_of(chat_id):

    return LANGUAGE_BY_CHAT.get(
        str(chat_id),
        DEFAULT_LANGUAGE
    )


def set_language(chat_id, language):

    LANGUAGE_BY_CHAT[str(chat_id)] = normalize(language)

    save_languages()


def language_keyboard():

    return InlineKeyboardMarkup(
        inline_keyboard=[[
            InlineKeyboardButton(
                text=LANGUAGE_NAMES[code],
                callback_data=f"lang:{code}"
            )
            for code in LANGUAGES
        ]]
    )


def safe_filename(original_name):
    """Builds an ASCII-only filename safe to pass to FreeCAD.

    FreeCAD's STEP importer crashes the whole process (no
    catchable Python exception) on non-ASCII paths on Windows,
    e.g. Cyrillic names. Non-ASCII characters are stripped and a
    short unique suffix is added to avoid collisions between
    different uploads that reduce to the same ASCII remainder.
    """

    name, ext = os.path.splitext(original_name)

    ascii_name = name.encode("ascii", "ignore").decode("ascii")
    ascii_name = re.sub(r"[^A-Za-z0-9_-]+", "_", ascii_name).strip("_")

    if not ascii_name:
        ascii_name = "file"

    suffix = uuid.uuid4().hex[:8]

    return f"{ascii_name}_{suffix}{ext.lower()}"


# Uploads and everything derived from them carry the random
# suffix added by safe_filename, which is what makes them safe
# to delete automatically.
GENERATED_FILE = re.compile(
    r"_[0-9a-f]{8}(_render|_bom|_holes|_details|_view|_flat|_drawing\d*|_sheet\d+)?"
    r"\.(stp|step|fcstd|dwg|dxf|stl|obj|3mf|json|png|csv|pdf|glb)"
    r"(\.gz)?$",
    re.IGNORECASE
)


def acquire_single_instance_lock():
    """Reserves a local port as a lock.

    Returns the socket (which must stay alive for the whole run)
    or None when another instance already holds it. The lock is
    released by the OS if the process dies, so a crash cannot
    leave a stale lock behind.
    """

    lock = socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM
    )

    try:

        # No SO_REUSEADDR here: on Windows it would let a second
        # instance bind the same port and defeat the lock.
        lock.bind(
            ("127.0.0.1", SINGLE_INSTANCE_PORT)
        )

    except OSError:

        lock.close()

        return None

    return lock


def cleanup_old_files():
    """Removes bot-generated files past the retention window.

    Only files matching the generated-name pattern are touched,
    so anything placed in the directory by hand survives.
    """

    if not os.path.isdir(FILES_DIR):
        return 0

    cutoff = time.time() - FILE_RETENTION_DAYS * 86400

    removed = 0

    for name in os.listdir(FILES_DIR):

        if not GENERATED_FILE.search(name):
            continue

        path = os.path.join(FILES_DIR, name)

        try:

            if os.path.getmtime(path) >= cutoff:
                continue

            os.remove(path)

            removed += 1

        except OSError as e:
            log.warning("Could not remove %s: %s", name, e)

    if removed:
        log.info("Cleanup removed %d old file(s).", removed)

    return removed


def format_number(value, decimals=3):
    return f"{value:,.{decimals}f}".replace(",", " ")


def format_axis(axis):
    return (
        f"({axis[0]:.3f}, "
        f"{axis[1]:.3f}, "
        f"{axis[2]:.3f})"
    )


def folded_message(head, folded=""):
    """Summary in the open, the long tail folded into a quote.

    A hole schedule with forty diameters and a coordinate list are
    what somebody scrolls past, not what they read, so Telegram's
    expandable quote keeps them one line tall until they are wanted.
    """

    # quote=False: apostrophes are ordinary text here, and escaping
    # them only litters the message with entities.
    text = html.escape(head, quote=False)

    if not folded.strip():
        return text

    body = html.escape(folded, quote=False)

    room = MAX_MESSAGE_LENGTH - len(text) - 60

    if len(body) > room:
        body = body[:max(room, 0)].rsplit("\n", 1)[0] + "\n…"

    return (
        text
        + "\n<blockquote expandable>"
        + body
        + "</blockquote>"
    )


def build_report(data, language=DEFAULT_LANGUAGE):
    """Report for a solid model (STEP / FCStd).

    Returns (summary, details): the caller folds the details away.
    """

    unit = "мм" if language == "uk" else "mm"

    lines = [t(language, "report_cad_done"), ""]

    total = data.get("total", {})
    bbox = data.get("bounding_box")

    lines.append(
        t(language, "parts_count", count=data.get("parts_count", 0))
    )

    if bbox:

        size = bbox["size"]

        lines.append(
            t(
                language,
                "size_3d",
                x=f"{size['x']:.3f}",
                y=f"{size['y']:.3f}",
                z=f"{size['z']:.3f}"
            )
        )

    lines.append(
        t(
            language,
            "volume",
            value=format_number(total.get("volume_mm3", 0))
        )
    )

    lines.append(t(language, "solids", count=total.get("solids", 0)))
    lines.append(t(language, "faces", count=total.get("faces", 0)))
    lines.append(t(language, "edges", count=total.get("edges", 0)))

    # --------------------------------------------------------
    # HOLES
    # --------------------------------------------------------

    holes = data.get("holes", [])
    groups = data.get("hole_groups", [])

    lines.append("")

    lines.append(
        t(language, "holes_total", count=len(holes))
        if holes
        else t(language, "holes_none_found")
    )

    details = []

    for group in groups:
        details.append(
            t(
                language,
                "hole_group_3d",
                diameter=group["diameter_mm"],
                length=group["length_mm"],
                count=group["count"]
            )
        )

    if holes and len(holes) <= MAX_LISTED_HOLE_COORDS:

        if details:
            details.append("")

        details.append(t(language, "hole_coords_header"))

        for i, hole in enumerate(holes, 1):

            center = hole.get("center", (0, 0, 0))
            axis = hole.get("axis", (0, 0, 0))

            details.append(
                f"{i}. "
                f"P{hole.get('part', '?')} "
                f"Ø{hole.get('diameter_mm', '?')} "
                f"L={hole.get('length_mm', '?')} {unit}"
            )

            details.append(
                "   "
                f"X={center[0]:.3f} "
                f"Y={center[1]:.3f} "
                f"Z={center[2]:.3f}"
            )

            details.append("   " + f"Axis={format_axis(axis)}")

    elif holes:

        if details:
            details.append("")

        details.append(
            t(language, "hole_coords_too_many", count=len(holes))
        )

    return "\n".join(lines), "\n".join(details)


def build_dxf_report(data, language=DEFAULT_LANGUAGE):
    """Report for a flat drawing (DXF, or a 2D DWG).

    Returns (summary, details): the caller folds the details away.
    """

    lines = [t(language, "report_dxf_done"), ""]

    bbox = data.get("bounding_box")

    if bbox:

        size = bbox["size"]

        lines.append(
            t(
                language,
                "size_2d",
                x=f"{size['x']:.3f}",
                y=f"{size['y']:.3f}"
            )
        )

    contours = data.get("contours", {})

    lines.append(
        t(language, "contours_total", count=contours.get("total", 0))
    )

    lines.append(
        t(
            language,
            "contours_breakdown",
            outer=contours.get("outer", 0),
            inner=contours.get("inner", 0),
            open=contours.get("open", 0)
        )
    )

    lines.append(
        t(
            language,
            "cut_length",
            value=format_number(data.get("cut_length_mm", 0))
        )
    )

    lines.append(
        t(language, "pierces", count=data.get("pierces", 0))
    )

    lines.append(
        t(
            language,
            "area",
            value=format_number(data.get("area_mm2", 0))
        )
    )

    if data.get("perimeter_mm"):

        lines.append(
            t(
                language,
                "perimeter",
                value=format_number(data["perimeter_mm"])
            )
        )

    # --------------------------------------------------------
    # UNITS
    # --------------------------------------------------------

    declared = data.get("units_declared")

    if data.get("units") == "in":
        lines.append("")
        lines.append(t(language, "units_inches"))

    elif declared and declared not in ("mm", "unitless"):
        lines.append("")
        lines.append(t(language, "units_odd", declared=declared))

    # --------------------------------------------------------
    # HOLES
    # --------------------------------------------------------

    holes = data.get("holes", [])
    groups = data.get("hole_groups", [])

    lines.append("")

    lines.append(
        t(language, "holes_round_total", count=len(holes))
        if holes
        else t(language, "holes_round_none")
    )

    details = []

    for group in groups:
        details.append(
            t(
                language,
                "hole_group_2d",
                diameter=group["diameter_mm"],
                count=group["count"]
            )
        )

    if holes and len(holes) <= MAX_LISTED_HOLE_COORDS:

        if details:
            details.append("")

        details.append(t(language, "hole_coords_header"))

        for hole in holes:

            center = hole.get("center", (0, 0))

            details.append(
                f"{hole.get('index', '?')}. "
                f"Ø{hole.get('diameter_mm', '?')} — "
                f"X={center[0]:.3f} "
                f"Y={center[1]:.3f}"
            )

    elif holes:

        if details:
            details.append("")

        details.append(
            t(language, "hole_coords_too_many", count=len(holes))
        )

    return "\n".join(lines), "\n".join(details)


def build_mesh_report(data, language=DEFAULT_LANGUAGE):
    """Report for a triangle mesh (STL / OBJ / 3MF).

    Short enough to stay open, so it folds nothing away.
    """

    lines = [t(language, "report_mesh_done"), ""]

    bbox = data.get("bounding_box")

    if bbox:

        size = bbox["size"]

        lines.append(
            t(
                language,
                "size_3d",
                x=f"{size['x']:.3f}",
                y=f"{size['y']:.3f}",
                z=f"{size['z']:.3f}"
            )
        )

    lines.append(
        t(language, "triangles", count=data.get("triangles", 0))
    )

    lines.append(
        t(
            language,
            "surface_area",
            value=format_number(data.get("surface_area_mm2", 0))
        )
    )

    mesh = data.get("mesh", {})

    if mesh.get("closed"):
        lines.append(
            t(
                language,
                "volume",
                value=format_number(data.get("volume_mm3", 0))
            )
        )
    else:
        lines.append(t(language, "volume_unavailable"))

    # --------------------------------------------------------
    # MESH HEALTH
    # --------------------------------------------------------

    lines.append("")
    lines.append(t(language, "mesh_check_header"))

    if mesh.get("watertight"):
        lines.append(t(language, "mesh_ok"))

    else:

        if mesh.get("open_edges"):
            lines.append(
                t(
                    language,
                    "mesh_open_edges",
                    count=mesh["open_edges"]
                )
            )

        if mesh.get("non_manifold_edges"):
            lines.append(
                t(
                    language,
                    "mesh_non_manifold",
                    count=mesh["non_manifold_edges"]
                )
            )

        if mesh.get("degenerate_triangles"):
            lines.append(
                t(
                    language,
                    "mesh_degenerate",
                    count=mesh["degenerate_triangles"]
                )
            )

    lines.append("")
    lines.append(t(language, "mesh_no_units"))

    return "\n".join(lines), ""


# ============================================================
# SUBPROCESS
# ============================================================

# Child processes get their own console window on Windows, which
# pops up on screen every time a file is analyzed even though the
# bot itself runs windowless under pythonw.
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def run_process(command, timeout):
    """Runs a child process. Returns (ok, error_message)."""

    try:

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            creationflags=NO_WINDOW
        )

    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout} s."

    except Exception as e:
        return False, str(e)

    if result.returncode != 0:

        error = (
            result.stderr.strip()
            or result.stdout.strip()
            or "unknown error."
        )

        return False, error

    return True, ""


def freecad_command(script, file_path, *extra):
    """Runs a project script inside freecadcmd, console only."""

    name = os.path.basename(script)

    argv = [name, str(file_path)] + [str(a) for a in extra]

    code = (
        "import sys; "
        f"sys.argv={argv!r}; "
        f"exec(open(r'{script}', encoding='utf-8').read())"
    )

    return [FREECAD, "-c", code]


# Which pipeline handles which format. STEP needs FreeCAD to
# read BREP geometry; DXF and STL are handled by plain Python,
# which is both faster and one less moving part.
PIPELINES = {
    "dxf": {
        "extensions": DXF_EXTENSIONS,
        "analyzer": DXF_ANALYZER,
        "renderer": DXF_RENDERER,
        "freecad": False
    },
    "mesh": {
        "extensions": MESH_EXTENSIONS,
        "analyzer": MESH_ANALYZER,
        "renderer": MESH_RENDERER,
        "freecad": False
    },
    "step": {
        "extensions": STEP_EXTENSIONS,
        "analyzer": ANALYZER,
        "renderer": RENDERER,
        "freecad": True
    }
}


def get_pipeline(file_path):

    extension = os.path.splitext(file_path)[1].lower()

    for pipeline in PIPELINES.values():

        if extension in pipeline["extensions"]:
            return pipeline

    return None


def build_command(script, file_path, use_freecad, *extra):

    if use_freecad:
        return freecad_command(script, file_path, *extra)

    return [sys.executable, script, str(file_path)] + [
        str(argument) for argument in extra
    ]


def run_capture(command, timeout):
    """Like run_process, but also returns the child's stdout."""

    try:

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            creationflags=NO_WINDOW
        )

    except subprocess.TimeoutExpired:
        return False, "", f"timed out after {timeout} s."

    except Exception as e:
        return False, "", str(e)

    output = result.stdout or ""

    if result.returncode != 0:

        error = (
            output.strip()
            or (result.stderr or "").strip()
            or "unknown error."
        )

        return False, output, error

    return True, output, ""


ODA_DIRECTORY = r"C:\Program Files\ODA"


def find_oda_converter():
    """Locates ODAFileConverter.exe.

    The installer puts it in a version-numbered folder, which is
    not the versionless path ezdxf looks in by default, so ezdxf
    reports it as missing until pointed at the real one.
    """

    if not os.path.isdir(ODA_DIRECTORY):
        return None

    found = []

    for name in os.listdir(ODA_DIRECTORY):

        exe = os.path.join(
            ODA_DIRECTORY,
            name,
            "ODAFileConverter.exe"
        )

        if os.path.exists(exe):
            found.append(exe)

    # Newest version last.
    return sorted(found)[-1] if found else None


def dwg_to_dxf(file_path, language=DEFAULT_LANGUAGE):
    """Flat DWG -> DXF via the ODA File Converter."""

    import ezdxf

    from ezdxf.addons import odafc

    exe = find_oda_converter()

    if exe is None:

        return None, t(language, "dwg_needs_converter")

    ezdxf.options.set("odafc-addon", "win_exec_path", exe)

    dxf_path = os.path.splitext(file_path)[0] + ".dxf"

    try:
        odafc.convert(file_path, dxf_path, version="R2013")

    except Exception as e:
        return None, f"converter error: {e}"

    if not os.path.exists(dxf_path):
        return None, "the converter produced no DXF."

    return dxf_path, None


def convert_dwg(file_path, language=DEFAULT_LANGUAGE):
    """Converts a DWG into something the pipelines can read.

    Rhino's headless core handles 3D drawings, resolving the ACIS
    bodies that AutoCAD stores inside them, and writes STEP. Flat
    drawings go to the ODA converter instead, because Rhino's
    DWG/DXF writer emits DWG regardless of the extension it is
    given.

    Returns (path, kind, None) with kind "3d" or "2d", or
    (None, None, message).
    """

    ok, output, error = run_capture(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", RHINO_CONVERTER,
            file_path
        ],
        DWG_TIMEOUT
    )

    if not ok:
        return None, None, error.replace("ERROR: ", "")[-1000:]

    kind = None
    path = ""

    for line in output.splitlines():

        if line.startswith("RESULT="):
            kind, _, path = line[len("RESULT="):].partition(";")
            kind = kind.strip()
            path = path.strip()

    if kind == "3d" and os.path.exists(path):
        return path, "3d", None

    if kind == "2d":

        dxf_path, dxf_error = dwg_to_dxf(file_path, language)

        if dxf_path is None:
            return None, None, dxf_error

        return dxf_path, "2d", None

    return None, None, "the converter returned no result."


def run_analysis(file_path):
    """Analyzes a STEP, DXF or STL file into a JSON report."""

    pipeline = get_pipeline(file_path)

    if pipeline is None:
        return False, "unsupported format."

    return run_process(
        build_command(
            pipeline["analyzer"],
            file_path,
            pipeline["freecad"]
        ),
        ANALYSIS_TIMEOUT
    )


def run_glb_export(file_path):
    """Writes the mesh the Mini App loads, beside the upload."""

    ok, error = run_process(
        freecad_command(GLB_EXPORTER, file_path),
        GLB_TIMEOUT
    )

    if not ok:
        log.warning(
            "GLB export failed: %s -- %s",
            os.path.basename(file_path),
            (error or "")[-300:]
        )

    return ok


def run_render(file_path, language=DEFAULT_LANGUAGE):
    """Renders the drawing sheet for a STEP, DXF or STL file.

    Every renderer is a pure software rasterizer, so no FreeCAD
    GUI window is ever opened. The language reaches the sheet
    itself: its title block and notes are in the chat's language.

    Returns (png_path, None) on success, or (None, error_message).
    """

    pipeline = get_pipeline(file_path)

    if pipeline is None:
        return None, "unsupported format."

    ok, error = run_process(
        build_command(
            pipeline["renderer"],
            file_path,
            pipeline["freecad"],
            language
        ),
        RENDER_TIMEOUT
    )

    png_file = (
        os.path.splitext(file_path)[0]
        + "_render.png"
    )

    if not ok or not os.path.exists(png_file):

        return None, (
            error or "no PNG was produced."
        )[-1500:]

    return png_file, None


# ============================================================
# EXTRA ACTIONS
#
# Telegram allows only 64 bytes of callback data, so a button
# carries the upload's random suffix instead of a path, and the
# file is found on disk by that token. Deriving it from disk
# also means buttons keep working after a bot restart.
# ============================================================

FILE_TOKEN = re.compile(r"_([0-9a-f]{8})\.[^.]+$")


def file_token(file_path):

    match = FILE_TOKEN.search(os.path.basename(file_path))

    return match.group(1) if match else None


def find_by_token(token):
    """Locates the file a button refers to.

    A converted DWG leaves two files sharing the token: the
    original upload and the STEP or DXF made from it. The
    converted one is what the pipelines can actually read, so
    DWG is only used when nothing was derived from it.
    """

    if not re.fullmatch(r"[0-9a-f]{8}", token or ""):
        return None

    matches = []

    for name in os.listdir(FILES_DIR):

        extension = os.path.splitext(name)[1].lower()

        if extension not in SUPPORTED_EXTENSIONS:
            continue

        if file_token(name) != token:
            continue

        # Raw DWG last; anything else is a readable result.
        priority = 1 if extension in DWG_EXTENSIONS else 0

        matches.append((priority, os.path.join(FILES_DIR, name)))

    if not matches:
        return None

    return sorted(matches)[0][1]


# Set once the tunnel is up; None means the viewer is offline and
# its button is simply not offered.
VIEWER = {"url": None}


def viewer_button(token, language):
    """Opens the model in the Mini App, if there is a way in."""

    if not VIEWER["url"]:
        return None

    return InlineKeyboardButton(
        text=t(language, "btn_viewer"),
        web_app=WebAppInfo(
            url="{}/?t={}".format(VIEWER["url"], token)
        )
    )


def build_actions_keyboard(file_path, data, language):
    """Offers the extras that make sense for this file."""

    token = file_token(file_path)

    if token is None:
        return None

    buttons = []

    # A solid is turned around in 3D; a flat one is laid out as
    # the drawing it is, with its holes tappable.
    if data.get("parts") or data.get("triangles") or data.get("contours"):

        button = viewer_button(token, language)

        if button is not None:
            buttons.append([button])

    # A bill of materials needs a parts list, which only the
    # solid-model pipeline produces.
    if data.get("parts"):

        buttons.append([
            InlineKeyboardButton(
                text=t(language, "btn_spec"),
                callback_data=f"bom:{token}"
            )
        ])

    if data.get("parts"):

        buttons.append([
            InlineKeyboardButton(
                text=t(language, "btn_detail"),
                callback_data=f"detail:{token}"
            )
        ])

    # The same numbers, asked a different question: will this come
    # off the machine as drawn, or will somebody find out the hard
    # way with a sheet already on the table.
    if manufacturing.can_review(data):

        buttons.append([
            InlineKeyboardButton(
                text=t(language, "btn_manufacturing"),
                callback_data=f"mfg:{token}"
            )
        ])

    # A flat drawing is the one thing that can be dimensioned
    # back into a drawing: the shop gets the same part with its
    # holes called out and measured off a datum edge.
    if data.get("format") == "dxf":

        buttons.append([
            InlineKeyboardButton(
                text=t(language, "btn_drawing"),
                callback_data=f"draw:{token}"
            )
        ])

    if data.get("holes"):

        buttons.append([
            InlineKeyboardButton(
                text=t(
                    language,
                    "btn_holes",
                    count=len(data["holes"])
                ),
                callback_data=f"holes:{token}"
            )
        ])

    if not buttons:
        return None

    return InlineKeyboardMarkup(inline_keyboard=buttons)


def remember_original_name(json_file, data, original_name):
    """Keeps the name the file arrived under, inside its report.

    The drawing sheet fills its title block from it: a shop names
    its files <designation> - <name>.dxf, and the two belong in
    two different cells of the block. What is on disk here is the
    safe ASCII version, which has neither.
    """

    if not original_name or data.get("original_name") == original_name:
        return

    data["original_name"] = original_name

    try:

        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    except Exception as e:
        log.warning("Could not record the original name: %s", e)


def load_report_json(file_path):

    json_file = os.path.splitext(file_path)[0] + ".json"

    if not os.path.exists(json_file):
        return None

    try:

        with open(json_file, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return None


@router.callback_query(F.data.startswith("bom:"))
async def bom_handler(callback: CallbackQuery):

    await callback.answer()

    language = language_of(callback.message.chat.id)

    file_path = find_by_token(
        callback.data.split(":", 1)[1]
    )

    data = (
        load_report_json(file_path)
        if file_path
        else None
    )

    if data is None:

        await callback.message.answer(
            t(language, "file_gone")
        )

        return

    rows = build_bom(data)

    if not rows:

        await callback.message.answer(
            t(language, "no_parts")
        )

        return

    log.info(
        "BOM requested: %s (%d positions)",
        os.path.basename(file_path),
        len(rows)
    )

    summary, details = build_bom_text(rows, data, language)

    await callback.message.answer(
        folded_message(summary, details),
        parse_mode="HTML"
    )

    csv_file = (
        os.path.splitext(file_path)[0]
        + "_bom.csv"
    )

    write_bom_csv(rows, csv_file, language)

    await callback.message.answer_document(
        FSInputFile(
            csv_file,
            filename="specification.csv"
        ),
        caption=t(language, "spec_caption")
    )


@router.callback_query(F.data.startswith("detail:"))
async def detail_handler(callback: CallbackQuery):

    await callback.answer()

    language = language_of(callback.message.chat.id)

    file_path = find_by_token(
        callback.data.split(":", 1)[1]
    )

    data = (
        load_report_json(file_path)
        if file_path
        else None
    )

    if data is None:

        await callback.message.answer(
            t(language, "file_gone")
        )

        return

    # Detail sheets need the solid model itself, not just the
    # report, so the file has to be one FreeCAD can open.
    extension = os.path.splitext(file_path)[1].lower()

    if extension not in STEP_EXTENSIONS:

        await callback.message.answer(
            t(
                language,
                "detail_only_3d",
                format=extension.lstrip(".").upper()
            )
        )

        return

    positions = len(build_bom(data))

    await callback.message.answer(
        t(
            language,
            "detail_building",
            count=positions,
            word=sheets_word(language, positions)
        )
        + t(language, "wait_detail")
    )

    log.info(
        "Detail sheets requested: %s (%d positions)",
        os.path.basename(file_path),
        positions
    )

    started = time.monotonic()

    ok, error = await asyncio.to_thread(
        run_process,
        freecad_command(DETAIL_SHEETS, file_path, language),
        DETAIL_TIMEOUT
    )

    pdf_file = (
        os.path.splitext(file_path)[0]
        + "_details.pdf"
    )

    if not ok or not os.path.exists(pdf_file):

        log.error(
            "Detail sheets failed: %s -- %s",
            os.path.basename(file_path),
            (error or "")[-500:]
        )

        await callback.message.answer(
            t(
                language,
                "detail_failed",
                error=(error or "no PDF was produced.")[-1500:]
            )
        )

        return

    log.info(
        "Detail sheets finished: %s in %.1f s",
        os.path.basename(file_path),
        time.monotonic() - started
    )

    await callback.message.answer_document(
        FSInputFile(
            pdf_file,
            filename="details.pdf"
        ),
        caption=t(
            language,
            "detail_caption",
            count=positions,
            word=sheets_word(language, positions)
        )
    )


@router.callback_query(F.data.startswith("mfg:"))
async def manufacturing_handler(callback: CallbackQuery):

    await callback.answer()

    language = language_of(callback.message.chat.id)

    file_path = find_by_token(
        callback.data.split(":", 1)[1]
    )

    data = (
        load_report_json(file_path)
        if file_path
        else None
    )

    if data is None:

        await callback.message.answer(
            t(language, "file_gone")
        )

        return

    summary, details = manufacturing.review(data, language)

    if summary is None:

        await callback.message.answer(
            t(language, "mfg_nothing")
        )

        return

    log.info(
        "Manufacturability requested: %s",
        os.path.basename(file_path)
    )

    await callback.message.answer(
        folded_message(summary, details),
        parse_mode="HTML"
    )


def source_file_name(file_path):
    """The name the file arrived under, if the report kept it."""

    data = load_report_json(file_path) or {}

    return data.get("original_name") or os.path.basename(file_path)


# Plate thicknesses a shop keeps on the rack. A DXF carries no
# thickness at all, and the edge view of the drawing is the one
# place it has to go, so it is asked for rather than guessed.
DRAWING_THICKNESSES = (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 16)


def thickness_keyboard(token, flags, language):

    buttons = []

    row = []

    for value in DRAWING_THICKNESSES:

        row.append(
            InlineKeyboardButton(
                text="{:g}".format(value),
                callback_data="dwv:{}:{:g}:{}".format(token, value, flags)
            )
        )

        if len(row) == 4:
            buttons.append(row)
            row = []

    if row:
        buttons.append(row)

    buttons.append([
        InlineKeyboardButton(
            text=t(language, "btn_thickness_skip"),
            callback_data="dwv:{}:0:{}".format(token, flags)
        )
    ])

    return InlineKeyboardMarkup(inline_keyboard=buttons)


# ============================================================
# THE DRAWING MENU
#
# The sheet has options now, and a shop that wants radii on
# every drawing should not have to say so every time. So the
# choices are remembered per chat, the plate thickness is read
# out of the file name when it is there, and the whole thing is
# one message with one button per choice.
# ============================================================

DRAWING_FLAGS_FILE = r"C:\ForgeMind\files\drawing_flags.json"

# Radii and angles off, the crowded corners enlarged, our own
# page: what most people want on a first drawing.
DEFAULT_FLAGS = "d"


def load_drawing_flags():

    try:

        with open(DRAWING_FLAGS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return {}


DRAWING_FLAGS = load_drawing_flags()


def flags_of(chat_id):

    return DRAWING_FLAGS.get(str(chat_id), DEFAULT_FLAGS)


def remember_flags(chat_id, flags):

    DRAWING_FLAGS[str(chat_id)] = flags

    try:

        with open(DRAWING_FLAGS_FILE, "w", encoding="utf-8") as f:
            json.dump(DRAWING_FLAGS, f)

    except Exception as e:
        log.warning("Could not save the drawing options: %s", e)


# A thickness in the file name, either with its unit or behind
# the S the trade writes it with: "Arm (7mm)", "S(товщ)=6 мм".
THICKNESS_WITH_UNIT = re.compile(
    r"(\d{1,2}(?:[.,]\d+)?)\s*(?:mm|мм)\b",
    re.IGNORECASE
)

THICKNESS_WITH_PREFIX = re.compile(
    r"(?:^|[\s_(\-])[STst](?:овщ\w*)?\s*[=\-]?\s*(\d{1,2}(?:[.,]\d+)?)\b"
)


def thickness_from_name(name):
    """The plate a file name declares, if it declares one."""

    if not name:
        return None

    for pattern in (THICKNESS_WITH_UNIT, THICKNESS_WITH_PREFIX):

        found = pattern.search(name)

        if not found:
            continue

        try:
            value = float(found.group(1).replace(",", "."))
        except ValueError:
            continue

        if 0.2 <= value <= 60.0:
            return "{:g}".format(value)

    return None


def toggled(flags, key):
    """One button press, on the flag string it belongs to."""

    if key == "r":
        return flags.replace("r", "") if "r" in flags else flags + "r"

    if key == "e":
        return flags.replace("e", "") if "e" in flags else flags + "e"

    if key == "p":
        return flags.replace("p", "") if "p" in flags else flags + "p"

    # Details go round: the crowded corners, every corner, none.
    bare = flags.replace("d", "").replace("D", "")

    if "d" in flags:
        return bare + "D"

    if "D" in flags:
        return bare

    return bare + "d"


def is_nest(token):
    """Whether the file holds more than one part."""

    path = find_by_token(token)

    if path is None:
        return False

    contours = (load_report_json(path) or {}).get("contours") or {}

    return contours.get("outer", 0) > 1


def drawing_menu(token, thickness, flags, language, nest=False):

    def option(key, text):

        return [
            InlineKeyboardButton(
                text=text,
                callback_data="dwo:{}:{}:{}:{}".format(
                    token,
                    thickness,
                    flags or "-",
                    key
                )
            )
        ]

    if "D" in flags:
        details = "opt_details_all"
    elif "d" in flags:
        details = "opt_details_auto"
    else:
        details = "opt_details_off"

    rows = [
        [
            InlineKeyboardButton(
                text=t(
                    language,
                    "opt_thickness",
                    value=(
                        "{} {}".format(thickness, t(language, "unit_mm"))
                        if thickness != "0"
                        else t(language, "opt_thickness_none")
                    )
                ),
                callback_data="dwt:{}:{}:{}".format(
                    token,
                    thickness,
                    flags or "-"
                )
            )
        ],
        option("r", t(
            language,
            "opt_shape_on" if "r" in flags else "opt_shape_off"
        )),
        option("d", t(language, details)),
        option("e", t(
            language,
            "opt_style_eskd" if "e" in flags else "opt_style_own"
        )),
    ]

    if nest:

        rows.append(option("p", t(
            language,
            "opt_nest_each" if "p" in flags else "opt_nest_one"
        )))

    rows.append([
        InlineKeyboardButton(
            text=t(language, "opt_build"),
            callback_data="dwb:{}:{}:{}".format(
                token,
                thickness,
                flags or "-"
            )
        )
    ])

    return InlineKeyboardMarkup(inline_keyboard=rows)


@router.callback_query(F.data.startswith("draw:"))
async def drawing_menu_handler(callback: CallbackQuery):
    """Opens the menu that says what goes on the sheet."""

    await callback.answer()

    language = language_of(callback.message.chat.id)

    parts = callback.data.split(":")

    token = parts[1]

    file_path = find_by_token(token)

    if file_path is None:

        await callback.message.answer(t(language, "file_gone"))

        return

    extension = os.path.splitext(file_path)[1].lower()

    if extension not in DXF_EXTENSIONS:

        await callback.message.answer(
            t(
                language,
                "drawing_only_flat",
                format=extension.lstrip(".").upper()
            )
        )

        return

    # A file called "Arm (7mm)" has already said what plate it is
    # on; there is no sense asking again.
    thickness = (
        parts[2]
        if len(parts) > 2
        else thickness_from_name(
            source_file_name(file_path)
        ) or "0"
    )

    flags = flags_of(callback.message.chat.id)

    contours = (load_report_json(file_path) or {}).get("contours") or {}

    await callback.message.answer(
        t(language, "opt_title"),
        reply_markup=drawing_menu(
            token,
            thickness,
            flags,
            language,
            contours.get("outer", 0) > 1
        )
    )


@router.callback_query(F.data.startswith("dwo:"))
async def drawing_option_handler(callback: CallbackQuery):
    """One option turned over, on the same message."""

    await callback.answer()

    language = language_of(callback.message.chat.id)

    _, token, thickness, flags, key = callback.data.split(":")

    flags = toggled("" if flags == "-" else flags, key)

    remember_flags(callback.message.chat.id, flags)

    await callback.message.edit_reply_markup(
        reply_markup=drawing_menu(
            token,
            thickness,
            flags,
            language,
            is_nest(token)
        )
    )


@router.callback_query(F.data.startswith("dwt:"))
async def drawing_thickness_handler(callback: CallbackQuery):
    """The thickness picker, in place of the menu."""

    await callback.answer()

    language = language_of(callback.message.chat.id)

    _, token, thickness, flags = callback.data.split(":")

    await callback.message.edit_reply_markup(
        reply_markup=thickness_keyboard(token, flags, language)
    )


@router.callback_query(F.data.startswith("dwv:"))
async def drawing_value_handler(callback: CallbackQuery):
    """A thickness chosen; back to the menu."""

    await callback.answer()

    language = language_of(callback.message.chat.id)

    _, token, thickness, flags = callback.data.split(":")

    await callback.message.edit_reply_markup(
        reply_markup=drawing_menu(
            token,
            thickness,
            "" if flags == "-" else flags,
            language,
            is_nest(token)
        )
    )


@router.callback_query(F.data.startswith("dwb:"))
async def drawing_build_handler(callback: CallbackQuery):
    """Builds the sheet the menu describes."""

    await callback.answer()

    language = language_of(callback.message.chat.id)

    _, token, thickness, flags = callback.data.split(":")

    flags = "" if flags == "-" else flags

    file_path = find_by_token(token)

    if file_path is None:

        await callback.message.answer(t(language, "file_gone"))

        return

    await callback.message.answer(t(language, "drawing_building"))

    log.info(
        "Part drawing requested: %s (thickness %s, options %s)",
        os.path.basename(file_path),
        thickness,
        flags or "none"
    )

    started = time.monotonic()

    started_at = time.time()

    ok, error = await asyncio.to_thread(
        run_process,
        [
            sys.executable,
            DXF_DRAWING,
            file_path,
            language,
            thickness,
            flags
        ],
        DRAWING_TIMEOUT
    )

    base = os.path.splitext(file_path)[0]

    png_file = base + "_drawing.png"
    pdf_file = base + "_drawing.pdf"

    if not ok or not os.path.exists(png_file):

        log.error(
            "Part drawing failed: %s -- %s",
            os.path.basename(file_path),
            (error or "")[-500:]
        )

        await callback.message.answer(
            t(
                language,
                "drawing_failed",
                error=(error or "no drawing was produced.")[-1500:]
            )
        )

        return

    log.info(
        "Part drawing finished: %s in %.1f s",
        os.path.basename(file_path),
        time.monotonic() - started
    )

    size = (
        (load_report_json(file_path) or {})
        .get("bounding_box", {})
        .get("size", {})
    )

    size_text = "{} × {}".format(
        format_number(size.get("x", 0.0), 1),
        format_number(size.get("y", 0.0), 1)
    )

    if thickness == "0":
        caption = t(language, "drawing_caption_plain", size=size_text)
    else:
        caption = t(
            language,
            "drawing_caption",
            size=size_text,
            thickness=thickness
        )

    # A part with fine work at one end gets a second sheet of
    # enlarged details, and the two travel together.
    second = base + "_drawing2.png"

    if os.path.exists(second) and os.path.getmtime(second) >= started_at:

        await callback.message.answer_media_group([
            InputMediaPhoto(media=FSInputFile(png_file), caption=caption),
            InputMediaPhoto(media=FSInputFile(second))
        ])

    else:

        await callback.message.answer_photo(
            FSInputFile(png_file),
            caption=caption
        )

    # The picture is for looking at; the PDF is for the man who
    # prints it and takes it to the machine.
    if os.path.exists(pdf_file):

        await callback.message.answer_document(
            FSInputFile(pdf_file, filename="drawing.pdf"),
            caption=t(language, "drawing_pdf")
        )


@router.callback_query(F.data.startswith("holes:"))
async def holes_handler(callback: CallbackQuery):

    await callback.answer()

    language = language_of(callback.message.chat.id)

    file_path = find_by_token(
        callback.data.split(":", 1)[1]
    )

    data = (
        load_report_json(file_path)
        if file_path
        else None
    )

    if data is None:

        await callback.message.answer(
            t(language, "file_gone")
        )

        return

    csv_file = (
        os.path.splitext(file_path)[0]
        + "_holes.csv"
    )

    if write_holes_csv(data, csv_file, language) is None:

        await callback.message.answer(
            t(language, "holes_none")
        )

        return

    log.info(
        "Hole table requested: %s (%d holes)",
        os.path.basename(file_path),
        len(data.get("holes", []))
    )

    await callback.message.answer_document(
        FSInputFile(
            csv_file,
            filename="holes.csv"
        ),
        caption=t(
            language,
            "holes_caption",
            count=len(data["holes"])
        )
    )


# ============================================================
# START
# ============================================================

def help_keyboard(language):
    """Language switch always within reach."""

    return InlineKeyboardMarkup(
        inline_keyboard=[[
            InlineKeyboardButton(
                text=t(language, "btn_language"),
                callback_data="lang:menu"
            )
        ]]
    )


@router.message(
    CommandStart()
)
async def start_handler(
    message: Message
):

    known = str(message.chat.id) in LANGUAGE_BY_CHAT

    # First contact asks for a language before anything else, so
    # every later message is already in the right one.
    if not known:

        await message.answer(
            t(DEFAULT_LANGUAGE, "language_prompt"),
            reply_markup=language_keyboard()
        )

        return

    language = language_of(message.chat.id)

    await message.answer(
        t(language, "greeting"),
        reply_markup=help_keyboard(language)
    )


@router.message(Command("language", "lang"))
async def language_command(
    message: Message
):

    await message.answer(
        t(DEFAULT_LANGUAGE, "language_prompt"),
        reply_markup=language_keyboard()
    )


@router.callback_query(F.data.startswith("lang:"))
async def language_handler(
    callback: CallbackQuery
):

    await callback.answer()

    choice = callback.data.split(":", 1)[1]

    if choice == "menu":

        await callback.message.answer(
            t(DEFAULT_LANGUAGE, "language_prompt"),
            reply_markup=language_keyboard()
        )

        return

    set_language(callback.message.chat.id, choice)

    language = language_of(callback.message.chat.id)

    log.info(
        "Language for chat %s set to %s",
        callback.message.chat.id,
        language
    )

    await callback.message.answer(
        t(language, "language_set")
    )

    await callback.message.answer(
        t(language, "greeting")
    )


# ============================================================
# FILE HANDLER
# ============================================================

@router.message()
async def message_handler(
    message: Message
):

    language = language_of(message.chat.id)

    if not message.document:

        # Echoing the text back tells the user nothing; point at
        # what the bot actually does instead.
        await message.answer(
            t(language, "text_hint"),
            reply_markup=help_keyboard(language)
        )

        return

    # --------------------------------------------------------
    # SAVE FILE
    # --------------------------------------------------------

    original_name = (
        message.document.file_name
        or "unknown_file"
    )

    extension = os.path.splitext(
        original_name
    )[1].lower()

    # --------------------------------------------------------
    # UNSUPPORTED
    #
    # Checked before downloading: there is no reason to pull a
    # file the bot cannot read, and such files would also sit in
    # the directory forever, since cleanup only recognises the
    # formats it produced.
    # --------------------------------------------------------

    if extension not in SUPPORTED_EXTENSIONS:

        log.info(
            "Rejected %s from chat %s: unsupported format",
            original_name.encode("ascii", "replace").decode(),
            message.chat.id
        )

        await message.answer(
            t(
                language,
                "unsupported_format",
                format=(
                    extension.lstrip(".").upper()
                    or "?"
                ),
                formats=supported_formats_text()
            )
        )

        return

    os.makedirs(
        FILES_DIR,
        exist_ok=True
    )

    file_name = safe_filename(
        original_name
    )

    file_path = os.path.join(
        FILES_DIR,
        file_name
    )

    file_info = await bot.get_file(
        message.document.file_id
    )

    await bot.download_file(
        file_info.file_path,
        destination=file_path
    )

    log.info(
        "Received %s (%.1f KB) from chat %s, saved as %s",
        original_name.encode("ascii", "replace").decode(),
        os.path.getsize(file_path) / 1024.0,
        message.chat.id,
        file_name
    )

    # --------------------------------------------------------
    # DWG: converted first, then routed by what is inside
    # --------------------------------------------------------

    converted = extension in DWG_EXTENSIONS
    converted_kind = None

    if converted:

        await message.answer(
            t(language, "dwg_received", name=original_name)
            + t(language, "wait_convert")
        )

        new_path, kind, convert_error = await asyncio.to_thread(
            convert_dwg,
            file_path,
            language
        )

        if new_path is None:

            log.error(
                "DWG conversion failed: %s -- %s",
                file_name,
                convert_error
            )

            await message.answer(
                t(language, "dwg_failed", error=convert_error)
            )

            return

        log.info(
            "DWG converted (%s): %s -> %s",
            kind,
            file_name,
            os.path.basename(new_path)
        )

        # Rhino decides the route by what it actually found: a
        # solid body becomes STEP, a flat drawing becomes DXF.
        file_path = new_path
        file_name = os.path.basename(new_path)
        extension = os.path.splitext(new_path)[1].lower()

        converted_kind = kind

    if extension in DXF_EXTENSIONS:
        started_text = t(language, "action_cutmap")

    elif extension in MESH_EXTENSIONS:
        started_text = t(language, "action_mesh")

    else:
        started_text = t(language, "action_cad")

    try:
        heavy = os.path.getsize(file_path) > BIG_FILE_BYTES
    except OSError:
        heavy = False

    if heavy:
        started_text += t(language, "wait_big")

    if converted:

        # The upload was already announced before conversion, and
        # how the file was read is not the user's concern.
        await message.answer(
            t(
                language,
                "dwg_is_3d" if converted_kind == "3d" else "dwg_is_2d",
                action=started_text
            )
        )

    else:

        await message.answer(
            t(
                language,
                "received",
                format=extension.lstrip(".").upper(),
                name=original_name,
                action=started_text
            )
        )

    # Only the chat that sent a file may open it in the viewer.
    webapp.remember_owner(
        file_token(file_path),
        message.chat.id
    )

    log.info(
        "Analysis started: %s (%s)",
        file_name,
        extension
    )

    started = time.monotonic()

    # Off the event loop: analysis can take minutes, and the bot
    # must keep answering everyone else meanwhile.
    ok, error = await asyncio.to_thread(
        run_analysis,
        file_path
    )

    if not ok:

        log.error(
            "Analysis failed: %s -- %s",
            file_name,
            error[-500:]
        )

        await message.answer(
            t(language, "analysis_failed", error=error[-3500:])
        )

        return

    log.info(
        "Analysis finished: %s in %.1f s",
        file_name,
        time.monotonic() - started
    )

    # --------------------------------------------------------
    # JSON
    # --------------------------------------------------------

    json_file = (
        os.path.splitext(
            file_path
        )[0]
        + ".json"
    )

    if not os.path.exists(
        json_file
    ):

        await message.answer(
            t(language, "json_missing")
        )

        return

    try:

        with open(
            json_file,
            "r",
            encoding="utf-8"
        ) as f:

            data = json.load(f)

    except Exception as e:

        await message.answer(
            t(language, "json_unreadable", error=e)
        )

        return

    remember_original_name(json_file, data, original_name)

    # --------------------------------------------------------
    # REPORT
    # --------------------------------------------------------

    if extension in DXF_EXTENSIONS:
        builder = build_dxf_report

    elif extension in MESH_EXTENSIONS:
        builder = build_mesh_report

    else:
        builder = build_report

    summary, details = builder(
        data,
        language
    )

    await message.answer(
        folded_message(summary, details),
        parse_mode="HTML"
    )

    # --------------------------------------------------------
    # VISUALIZATION
    # --------------------------------------------------------

    await message.answer(
        t(language, "building_render")
    )

    render_started = time.monotonic()

    png_file, render_error = await asyncio.to_thread(
        run_render,
        file_path,
        language
    )

    if png_file:

        log.info(
            "Render finished: %s in %.1f s",
            file_name,
            time.monotonic() - render_started
        )

        if extension in DXF_EXTENSIONS:
            caption = t(language, "caption_cutmap")

        elif extension in MESH_EXTENSIONS:
            caption = t(language, "caption_mesh")

        else:
            caption = t(language, "caption_iso")

        await message.answer_photo(
            FSInputFile(png_file),
            caption=caption
        )

    else:

        log.error(
            "Render failed: %s -- %s",
            file_name,
            (render_error or "")[-500:]
        )

        await message.answer(
            t(language, "render_failed", error=render_error)
        )

    # The viewer shows triangles, not BREP: tessellating here takes
    # a couple of seconds, while a phone would have to fetch a CAD
    # kernel first and then do it on the handset.
    if VIEWER["url"] and extension in STEP_EXTENSIONS:

        await asyncio.to_thread(run_glb_export, file_path)

    # --------------------------------------------------------
    # JSON FILE
    # --------------------------------------------------------

    json_size = os.path.getsize(json_file)

    if json_size > MAX_DOCUMENT_BYTES:

        await message.answer(
            t(
                language,
                "json_too_big",
                size=json_size / 1048576,
                path=json_file
            )
        )

    else:

        await message.answer_document(
            FSInputFile(
                json_file,
                filename=(
                    os.path.splitext(original_name)[0]
                    + ".json"
                )
            ),
            caption=t(language, "json_caption")
        )

    # --------------------------------------------------------
    # EXTRA ACTIONS
    # --------------------------------------------------------

    keyboard = build_actions_keyboard(
        file_path,
        data,
        language
    )

    if keyboard is not None:

        await message.answer(
            t(language, "extras_prompt"),
            reply_markup=keyboard
        )


# ============================================================
# MAIN
# ============================================================

async def deliver_sheet(token, chat_id, position):
    """Puts one detail sheet in the chat, at the viewer's request.

    A Mini App cannot hand a file to Telegram itself, but the bot it
    was opened from can, and it is running in this same process.
    """

    file_path = find_by_token(token)

    if file_path is None:
        return False

    if os.path.splitext(file_path)[1].lower() not in STEP_EXTENSIONS:
        return False

    language = language_of(chat_id)

    log.info(
        "Viewer asked for sheet %d of %s",
        position,
        os.path.basename(file_path)
    )

    ok, error = await asyncio.to_thread(
        run_process,
        freecad_command(DETAIL_SHEETS, file_path, language, position),
        DETAIL_TIMEOUT
    )

    sheet = "{}_sheet{}.pdf".format(
        os.path.splitext(file_path)[0],
        position
    )

    if not ok or not os.path.exists(sheet):

        log.warning(
            "Sheet %d failed: %s",
            position,
            (error or "")[-300:]
        )

        return False

    await bot.send_document(
        chat_id,
        FSInputFile(sheet, filename="sheet_{}.pdf".format(position)),
        caption=t(language, "sheet_sent", position=position)
    )

    return True


async def watch_viewer():
    """Keeps the button pointing at the address that works today.

    The address was read once at startup and then believed, so when
    the tunnel restarted every new button opened on "Try again"
    while the log quietly held the answer.
    """

    while True:

        await asyncio.sleep(VIEWER_REFRESH)

        pipe = VIEWER.get("tunnel")

        if pipe is None:
            continue

        try:
            VIEWER["url"] = await asyncio.to_thread(pipe.refresh)

        except Exception as e:
            log.warning("Could not check the tunnel: %s", e)


async def start_viewer():
    """Brings up the Mini App server and its way out to the world."""

    try:

        await webapp.start(
            TOKEN,
            LINK_SECRET,
            VIEWER_PORT,
            deliver=deliver_sheet
        )

        pipe = tunnel.Tunnel(VIEWER_PORT)

        VIEWER["tunnel"] = pipe
        VIEWER["url"] = await asyncio.to_thread(pipe.start)

        asyncio.create_task(watch_viewer())

    except Exception as e:

        log.warning("The 3D viewer could not be started: %s", e)

        VIEWER["url"] = None


async def main():

    log.info("=" * 60)
    log.info("ForgeMind starting up.")

    lock = acquire_single_instance_lock()

    if lock is None:

        log.error(
            "Another ForgeMind instance is already running. "
            "Exiting."
        )

        return

    cleanup_old_files()

    log.info(
        "Supported formats: %s",
        ", ".join(sorted(SUPPORTED_EXTENSIONS))
    )

    await start_viewer()

    log.info("Waiting for messages.")

    try:

        await dp.start_polling(
            bot
        )

    finally:

        if VIEWER.get("tunnel"):
            VIEWER["tunnel"].stop()


if __name__ == "__main__":

    asyncio.run(
        main()
    )