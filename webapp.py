"""The Mini App: a viewer page, and the models it is allowed to show.

Telegram opens a Mini App in its own browser, so the page has to be
reachable over public HTTPS. A tunnel gives it that, which means
this little server is exposed to the whole internet — hence the two
gates below.

The first is Telegram's own: every Mini App receives an `initData`
string signed with HMAC-SHA256 by Telegram itself, keyed on the bot
token. Nobody without the token can forge it, so it proves which
Telegram account is asking. The second is ownership: a file is only
served to the chat that uploaded it, looked up in owners.json.

The page never carries initData in a URL. It trades it once for a
short-lived signed link, because the viewer fetches the model
itself and a URL is the only thing it can be told.
"""

import gzip
import hashlib
import hmac
import json
import logging
import os
import time
import urllib.parse

from aiohttp import web


log = logging.getLogger("forgemind.webapp")


# ============================================================
# CONFIGURATION
# ============================================================

WEBAPP_DIRECTORY = r"C:\ForgeMind\webapp"
FILES_DIRECTORY = r"C:\ForgeMind\files"

OWNERS_FILE = os.path.join(FILES_DIRECTORY, "owners.json")

PORT = 47318

# A signed model link outlives a look at the model and nothing more.
LINK_LIFETIME = 3600

# Telegram signs initData when the Mini App is opened; a stale one
# means the page has been sitting open for a day.
INIT_DATA_LIFETIME = 86400

# Below this a gzip pass costs more than it saves.
GZIP_THRESHOLD = 8192

VIEWER_EXTENSIONS = {
    ".glb", ".stl", ".obj", ".3mf", ".step", ".stp", ".fcstd", ".brep"
}

FLAT_EXTENSIONS = {".dxf"}


# ============================================================
# OWNERSHIP
# ============================================================

def load_owners():

    try:

        with open(OWNERS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return {}


def remember_owner(token, chat_id):
    """Records who may look at this upload."""

    owners = load_owners()

    owners[str(token)] = str(chat_id)

    try:

        with open(OWNERS_FILE, "w", encoding="utf-8") as f:
            json.dump(owners, f)

    except Exception as e:
        log.warning("Could not save owners: %s", e)


# ============================================================
# TELEGRAM SIGNATURE
# ============================================================

def check_init_data(init_data, token):
    """Returns the Telegram user id, or None if the data is not real.

    The recipe is Telegram's: every field except `hash` sorted and
    joined with newlines, signed with a key that is itself the
    HMAC of the bot token under the constant "WebAppData".
    """

    if not init_data:
        return None

    fields = urllib.parse.parse_qsl(
        init_data,
        keep_blank_values=True
    )

    received = None

    lines = []

    for key, value in sorted(fields):

        if key == "hash":
            received = value
            continue

        lines.append("{}={}".format(key, value))

    if not received:
        return None

    secret = hmac.new(
        b"WebAppData",
        token.encode("utf-8"),
        hashlib.sha256
    ).digest()

    expected = hmac.new(
        secret,
        "\n".join(lines).encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected, received):
        return None

    data = dict(fields)

    try:
        issued = int(data.get("auth_date", "0"))
    except ValueError:
        return None

    if time.time() - issued > INIT_DATA_LIFETIME:
        return None

    try:
        user = json.loads(data.get("user", "{}"))
    except ValueError:
        return None

    return user.get("id")


# ============================================================
# SIGNED LINKS
# ============================================================

def sign_link(token, name, expiry, secret):

    return hmac.new(
        secret.encode("utf-8"),
        "{}:{}:{}".format(token, name, expiry).encode("utf-8"),
        hashlib.sha256
    ).hexdigest()[:32]


def check_link(token, name, expiry, signature, secret):

    if not expiry.isdigit() or int(expiry) < time.time():
        return False

    return hmac.compare_digest(
        sign_link(token, name, expiry, secret),
        signature or ""
    )


# ============================================================
# FILES
# ============================================================

def find_upload(token, extensions=None):
    """The uploaded file carrying this token, converted one first."""

    matches = []

    for name in os.listdir(FILES_DIRECTORY):

        base, extension = os.path.splitext(name)

        if not base.endswith("_" + token):
            continue

        extension = extension.lower()

        if extensions and extension not in extensions:
            continue

        # A converted DWG leaves two files sharing one token.
        matches.append(
            (1 if extension == ".dwg" else 0, name)
        )

    if not matches:
        return None

    return os.path.join(FILES_DIRECTORY, sorted(matches)[0][1])


def viewable(token):
    """What the viewer should open for this upload, and how.

    A solid model is shown as the GLB exported beside it: the
    browser can read STEP itself, but only by fetching a CAD kernel
    first and tessellating a whole assembly on the handset.
    """

    original = find_upload(token, VIEWER_EXTENSIONS)

    if original:

        # The GLB sits beside the upload it was exported from.
        exported = os.path.splitext(original)[0] + "_view.glb"

        if os.path.exists(exported):
            return exported, "model"

        return original, "model"

    flat = find_upload(token, FLAT_EXTENSIONS)

    if flat:

        # The contours the analysis flattened, written beside the
        # file: the report says how many holes there are, this is
        # what draws them.
        geometry = os.path.splitext(flat)[0] + "_flat.json"

        if os.path.exists(geometry):
            return geometry, "flat"

    return None, None


def gzipped(path):
    """Serves a compressed twin, made once and kept beside the file.

    Vertex data is float arrays, and float arrays gzip to a fifth of
    their size: five megabytes over mobile data becomes one.
    """

    packed = path + ".gz"

    if (
        not os.path.exists(packed)
        or os.path.getmtime(packed) < os.path.getmtime(path)
    ):

        with open(path, "rb") as source:

            with gzip.open(packed, "wb", compresslevel=6) as target:
                target.write(source.read())

    return packed


# ============================================================
# ROUTES
# ============================================================

async def handle_auth(request):
    """Trades a signed Mini App session for a link to one model."""

    secrets = request.app["secrets"]

    body = await request.json()

    user = check_init_data(body.get("initData", ""), secrets["token"])

    if user is None:
        return web.json_response({"error": "unauthorized"}, status=401)

    token = str(body.get("token", ""))

    if not token.isalnum():
        return web.json_response({"error": "bad token"}, status=400)

    owner = load_owners().get(token)

    if owner is not None and str(user) != owner:
        return web.json_response({"error": "forbidden"}, status=403)

    path, kind = viewable(token)

    if path is None:
        return web.json_response({"error": "gone"}, status=404)

    name = os.path.basename(path)

    expiry = str(int(time.time()) + LINK_LIFETIME)

    report = read_report(token)

    return web.json_response({
        "kind": kind,
        "name": name,
        "url": "/m/{}/{}?e={}&k={}".format(
            token,
            urllib.parse.quote(name),
            expiry,
            sign_link(token, name, expiry, secrets["link"])
        ),
        "info": report,
        "parts": read_parts(token),
        "session": sign_link(token, "session", expiry, secrets["link"]),
        "expiry": expiry
    })


def read_parts(token):
    """The part map exported beside the mesh, if there is one.

    This is what makes the viewer worth having over any other: the
    bot already knows what every solid in the assembly is, so a tap
    can answer with its position, quantity and holes.
    """

    original = find_upload(token, VIEWER_EXTENSIONS)

    if not original:
        return None

    path = os.path.splitext(original)[0] + "_view.json"

    if not os.path.exists(path):
        return None

    try:

        with open(path, "r", encoding="utf-8") as f:
            return json.load(f).get("parts")

    except Exception:
        return None


def read_report(token):
    """The numbers the bot already worked out, for the info bar."""

    path = find_upload(token, {".json"})

    if not path:
        return None

    try:

        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

    except Exception:
        return None

    box = data.get("bounding_box", {}).get("size", {})

    summary = {
        "parts": data.get("parts_count"),
        "holes": len(data.get("holes", [])),
        "size": [box.get("x"), box.get("y"), box.get("z")],
        "cut": data.get("cut_length_mm"),
        "pierces": data.get("pierces"),
        "contours": data.get("contours", {}).get("total")
    }

    return {k: v for k, v in summary.items() if v is not None}


async def handle_sheet(request):
    """Sends one detail sheet into the chat the model came from.

    The Mini App cannot hand a file to Telegram itself, but the bot
    it was opened from can, and it is running in this very process.
    """

    secrets = request.app["secrets"]

    deliver = request.app.get("deliver")

    if deliver is None:
        return web.json_response({"error": "unavailable"}, status=503)

    body = await request.json()

    token = str(body.get("token", ""))
    expiry = str(body.get("expiry", ""))

    if not token.isalnum() or not check_link(
        token,
        "session",
        expiry,
        body.get("session", ""),
        secrets["link"]
    ):
        return web.json_response({"error": "expired"}, status=403)

    try:
        position = int(body.get("position", 0))
    except (TypeError, ValueError):
        return web.json_response({"error": "bad position"}, status=400)

    owner = load_owners().get(token)

    if owner is None:
        return web.json_response({"error": "unknown chat"}, status=404)

    sent = await deliver(token, int(owner), position)

    if not sent:
        return web.json_response({"error": "failed"}, status=500)

    return web.json_response({"ok": True})


async def handle_model(request):
    """The model bytes, to whoever holds a live signed link."""

    secrets = request.app["secrets"]

    token = request.match_info["token"]
    name = request.match_info["name"]

    if not check_link(
        token,
        name,
        request.query.get("e", ""),
        request.query.get("k", ""),
        secrets["link"]
    ):
        return web.Response(status=403, text="link expired")

    if os.path.basename(name) != name or name.startswith("."):
        return web.Response(status=400, text="bad name")

    path = os.path.join(FILES_DIRECTORY, name)

    if not os.path.exists(path):
        return web.Response(status=404, text="gone")

    headers = {"Cache-Control": "private, max-age=3600"}

    if (
        os.path.getsize(path) > GZIP_THRESHOLD
        and "gzip" in request.headers.get("Accept-Encoding", "")
    ):

        headers["Content-Encoding"] = "gzip"

        return web.FileResponse(gzipped(path), headers=headers)

    return web.FileResponse(path, headers=headers)


async def handle_index(request):

    return web.FileResponse(
        os.path.join(WEBAPP_DIRECTORY, "index.html"),
        headers={"Cache-Control": "no-cache"}
    )


# ============================================================
# SERVER
# ============================================================

def build_app(bot_token, link_secret, deliver=None):

    app = web.Application()

    app["secrets"] = {"token": bot_token, "link": link_secret}

    # Called as deliver(token, chat_id, position) to put a detail
    # sheet in the chat; the bot supplies it.
    app["deliver"] = deliver

    app.router.add_get("/", handle_index)
    app.router.add_post("/auth", handle_auth)
    app.router.add_post("/sheet", handle_sheet)
    app.router.add_get("/m/{token}/{name}", handle_model)

    app.router.add_static("/static", WEBAPP_DIRECTORY)

    return app


async def start(bot_token, link_secret, port=PORT, deliver=None):
    """Starts the viewer server inside the bot's own event loop."""

    runner = web.AppRunner(
        build_app(bot_token, link_secret, deliver)
    )

    await runner.setup()

    site = web.TCPSite(runner, "127.0.0.1", port)

    await site.start()

    log.info("Viewer server listening on 127.0.0.1:%d", port)

    return runner
