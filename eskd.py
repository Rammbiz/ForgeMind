"""The standard page: frame, binding column, title block.

Some customers will not take a drawing without ЄСКД furniture on
it, so the same views can be put on a page in that form: the
frame 20 mm off the left edge and 5 off the rest, the column of
little boxes down the left side, the designation repeated upside
down in the corner, the numbered technical requirements above the
block, and ГОСТ 2.104 form 1 itself.

The sheet is the same pixel size as the ForgeMind one, so the
layout engine does not care which is drawn. Nothing here claims a
scale, and the five signature rows are left empty: the sheet is
printed and signed by the people whose names belong there.

Pure numpy + PIL through drawing.py.
"""

from PIL import Image, ImageDraw

import drawing as dw


# ============================================================
# THE PAGE
# ============================================================

PAGE_WIDTH = dw.PAGE_WIDTH
PAGE_HEIGHT = dw.PAGE_HEIGHT

# The page is as wide as an A3 is long; everything else follows
# from that, and the millimetre is the unit the standard is
# written in.
PX_PER_MM = PAGE_WIDTH / 420.0

MARGIN_LEFT = 20.0
MARGIN = 5.0

FRAME_WIDTH = 2

PAPER = (255, 255, 255)

INK = (24, 26, 30)
THIN = (96, 102, 110)


def mm(value):

    return value * PX_PER_MM


def sheet():

    return Image.new("RGB", (PAGE_WIDTH, PAGE_HEIGHT), PAPER)


def field():
    """The drawing field, in millimetres, inside the frame."""

    return (
        MARGIN_LEFT,
        MARGIN,
        PAGE_WIDTH / PX_PER_MM - MARGIN,
        PAGE_HEIGHT / PX_PER_MM - MARGIN
    )


def box(left, top, right, bottom):

    return (mm(left), mm(top), mm(right), mm(bottom))


def rectangle(image, rect, width=1, fill=None, outline=INK):

    ImageDraw.Draw(image).rectangle(
        box(*rect),
        fill=fill,
        outline=outline,
        width=width
    )


def frame(image):
    """The heavy frame with its binding margin."""

    rectangle(image, field(), width=FRAME_WIDTH)


# ============================================================
# TYPE
#
# The standard sets text by the height of its capitals: 2.5,
# 3.5, 5, 7 mm. The drawing font is asked for the pixel size
# that comes out at the height wanted.
# ============================================================

_SIZES = {}


def font_mm(height, kind="drawing"):

    key = (round(height, 2), kind)

    if key in _SIZES:
        return _SIZES[key]

    wanted = mm(height)

    size = max(6, int(round(wanted)))

    for _ in range(8):

        chosen = dw.font(size, kind)

        box = chosen.getbbox("0")

        measured = box[3] - box[1]

        if measured <= 0 or abs(measured - wanted) <= 0.6:
            break

        size = max(6, int(round(size * wanted / measured)))

    _SIZES[key] = dw.font(size, kind)

    return _SIZES[key]


def write(image, position, text, height=3.5, kind="drawing",
          fill=INK, anchor="lt"):

    ImageDraw.Draw(image).text(
        position,
        dw.plain(text),
        font=font_mm(height, kind),
        fill=fill,
        anchor=anchor
    )


def fitted(text, width, height, kind="drawing"):
    """The largest of these heights whose text still fits."""

    while height > 1.6:

        if dw.text_width(dw.plain(text), font_mm(height, kind)) <= mm(width):
            return height

        height -= 0.25

    return height


def cell_text(image, rect, text, height=3.5, kind="drawing", fill=INK):
    """Centred in a cell given in millimetres, shrunk if it must be."""

    if not text:
        return

    left, top, right, bottom = rect

    height = fitted(text, (right - left) - 2.0, height, kind)

    write(
        image,
        (mm((left + right) / 2.0), mm((top + bottom) / 2.0) + 1),
        text,
        height,
        kind,
        fill,
        anchor="mm"
    )


# ============================================================
# THE BINDING COLUMN
# ============================================================

# Bottom to top, with the height of each box.
LEFT_COLUMN = [
    ("col_original", 25.0),
    ("col_signed_2", 35.0),
    ("col_replaced", 25.0),
    ("col_duplicate", 25.0),
    ("col_signed_1", 35.0),
    ("col_reference", 60.0),
    ("col_applied", 60.0)
]

CAPTION_WIDTH = 5.0
VALUE_WIDTH = 7.0

COLUMN_WIDTH = CAPTION_WIDTH + VALUE_WIDTH


def left_column(image, translate):
    """Fields 19 to 23, standing on the binding margin."""

    say = translate

    left, top, right, bottom = field()

    caption_right = left + CAPTION_WIDTH
    column_right = left + COLUMN_WIDTH

    block_x, block_y = block_origin()

    # The column stops on top of the title block when the block
    # reaches across to it.
    if block_x <= column_right + 1.0:
        bottom = block_y

    total = sum(height for _, height in LEFT_COLUMN)

    factor = min(1.0, (bottom - top) / total)

    pen = ImageDraw.Draw(image)

    y = bottom

    for key, height in LEFT_COLUMN:

        step = height * factor

        rectangle(image, (left, y - step, column_right, y))

        pen.line(
            [
                (mm(caption_right), mm(y - step)),
                (mm(caption_right), mm(y))
            ],
            fill=INK,
            width=1
        )

        caption = say(key)

        patch = dw.text_patch(
            dw.plain(caption),
            font_mm(fitted(caption, step - 3.0, 2.5)),
            INK
        )

        dw.paste_rotated(
            image,
            patch,
            (
                mm((left + caption_right) / 2.0),
                mm(y - step / 2.0)
            ),
            90.0
        )

        y -= step

    return column_right


# ============================================================
# THE DESIGNATION, UPSIDE DOWN IN THE CORNER
# ============================================================

MARK_WIDTH = 70.0
MARK_HEIGHT = 14.0


def designation_mark(image, text, left):
    """Field 26: the designation again, for a folded sheet."""

    if not text:
        return

    _, top, _, _ = field()

    rect = (left, top, left + MARK_WIDTH, top + MARK_HEIGHT)

    rectangle(image, rect)

    patch = dw.text_patch(
        dw.plain(text),
        font_mm(fitted(text, MARK_WIDTH - 6.0, 7.0)),
        INK
    )

    dw.paste_rotated(
        image,
        patch,
        (
            mm((rect[0] + rect[2]) / 2.0),
            mm((rect[1] + rect[3]) / 2.0)
        ),
        180.0
    )


# ============================================================
# THE TITLE BLOCK (ГОСТ 2.104, form 1)
# ============================================================

BLOCK_WIDTH = 185.0
BLOCK_HEIGHT = 55.0

ROW = 5.0

# Зм. | Арк. | № докум. | Підп. | Дата
LEFT_COLUMNS = (0.0, 7.0, 17.0, 40.0, 55.0, 65.0)

STAGES = (
    "stage_designed",
    "stage_checked",
    "stage_technical",
    None,
    "stage_control",
    "stage_approved"
)


def block_origin():

    _, _, right, bottom = field()

    return right - BLOCK_WIDTH, bottom - BLOCK_HEIGHT


def title_block(image, values, translate):
    """The block itself; `values` fills what the sheet knows."""

    say = translate

    x0, y0 = block_origin()

    def at(left, top, right, bottom):

        return (x0 + left, y0 + top, x0 + right, y0 + bottom)

    pen = ImageDraw.Draw(image)

    def line(left, top, right, bottom, width=1):

        pen.line(
            [
                (mm(x0 + left), mm(y0 + top)),
                (mm(x0 + right), mm(y0 + bottom))
            ],
            fill=INK,
            width=width
        )

    rectangle(image, at(0, 0, BLOCK_WIDTH, BLOCK_HEIGHT), width=FRAME_WIDTH)

    for row in range(1, 11):
        line(0.0, row * ROW, LEFT_COLUMNS[-1], row * ROW)

    for x in LEFT_COLUMNS[2:-1]:
        line(x, 0.0, x, BLOCK_HEIGHT)

    # The stage names take the two narrow columns together, so
    # that line stops where the revision rows do.
    line(LEFT_COLUMNS[1], 0.0, LEFT_COLUMNS[1], 5 * ROW)

    headers = (
        "head_change",
        "head_sheet",
        "head_document",
        "head_signature",
        "head_date"
    )

    for index, key in enumerate(headers):

        cell_text(
            image,
            at(
                LEFT_COLUMNS[index],
                4 * ROW,
                LEFT_COLUMNS[index + 1],
                5 * ROW
            ),
            say(key),
            2.5
        )

    for index, key in enumerate(STAGES):

        if key is None:
            continue

        top = (5 + index) * ROW

        cell_text(
            image,
            at(0.0, top, LEFT_COLUMNS[2], top + ROW),
            say(key),
            2.5
        )

    line(LEFT_COLUMNS[-1], 0.0, LEFT_COLUMNS[-1], BLOCK_HEIGHT, FRAME_WIDTH)

    line(LEFT_COLUMNS[-1], 3 * ROW, BLOCK_WIDTH, 3 * ROW)
    line(LEFT_COLUMNS[-1], 8 * ROW, 135.0, 8 * ROW)

    line(135.0, 3 * ROW, 135.0, BLOCK_HEIGHT)
    line(135.0, 4 * ROW, BLOCK_WIDTH, 4 * ROW)
    line(135.0, 6 * ROW, BLOCK_WIDTH, 6 * ROW)
    line(135.0, 8 * ROW, BLOCK_WIDTH, 8 * ROW)

    line(155.0, 3 * ROW, 155.0, 8 * ROW)
    line(170.0, 3 * ROW, 170.0, 6 * ROW)

    cell_text(
        image,
        at(LEFT_COLUMNS[-1], 0.0, BLOCK_WIDTH, 3 * ROW),
        values.get("designation", ""),
        7.0
    )

    cell_text(
        image,
        at(LEFT_COLUMNS[-1], 3 * ROW, 135.0, 8 * ROW),
        values.get("name", ""),
        5.0
    )

    cell_text(
        image,
        at(LEFT_COLUMNS[-1], 8 * ROW, 135.0, BLOCK_HEIGHT),
        values.get("material", ""),
        3.5
    )

    for left, right, key, value in (
        (135.0, 155.0, "head_letter", ""),
        (155.0, 170.0, "head_mass", ""),
        (170.0, BLOCK_WIDTH, "head_scale", "")
    ):

        cell_text(image, at(left, 3 * ROW, right, 4 * ROW), say(key), 2.5)
        cell_text(image, at(left, 4 * ROW, right, 6 * ROW), value, 5.0)

    cell_text(image, at(135.0, 6 * ROW, 155.0, 8 * ROW), say("head_page"), 2.5)

    cell_text(
        image,
        at(155.0, 6 * ROW, BLOCK_WIDTH, 8 * ROW),
        "{} {}".format(say("head_pages"), values.get("sheets", "1")),
        2.5
    )

    cell_text(
        image,
        at(135.0, 8 * ROW, BLOCK_WIDTH, BLOCK_HEIGHT),
        values.get("company", ""),
        4.0,
        kind="bold"
    )

    return x0, y0


# ============================================================
# TECHNICAL REQUIREMENTS
# ============================================================

REQUIREMENT_HEIGHT = 3.5
REQUIREMENT_STEP = 6.0
REQUIREMENT_GAP = 7.0
REQUIREMENT_INDENT = 6.0


def notes_left():
    """Where the notes start: level with the block, clear of the column."""

    left, _, _, _ = field()

    block_x, _ = block_origin()

    return max(block_x, left + COLUMN_WIDTH + 4.0)


def wrap(text, width, height=REQUIREMENT_HEIGHT):
    """Breaks a note into lines that fit `width` millimetres."""

    chosen = font_mm(height)

    room = mm(width)

    lines = []

    current = ""

    for word in dw.plain(text).split():

        candidate = (current + " " + word).strip()

        if current and dw.text_width(candidate, chosen) > room:
            lines.append(current)
            current = word
        else:
            current = candidate

    if current:
        lines.append(current)

    return lines or [""]


def requirement_rows(lines):
    """The notes as the physical lines they will occupy."""

    _, _, right, _ = field()

    room = right - notes_left() - REQUIREMENT_INDENT

    rows = []

    for number, text in enumerate(lines, 1):

        for index, piece in enumerate(wrap(text, room)):
            rows.append((str(number) if index == 0 else "", piece))

    return rows


def requirements(image, rows):
    """Draws notes already broken into lines; returns their top."""

    _, y0 = block_origin()

    if not rows:
        return y0

    left = notes_left()

    top = y0 - REQUIREMENT_GAP - REQUIREMENT_STEP * len(rows)

    y = top

    for number, text in rows:

        if number:
            write(image, (mm(left), mm(y)), number, REQUIREMENT_HEIGHT)

        write(
            image,
            (mm(left + REQUIREMENT_INDENT), mm(y)),
            text,
            REQUIREMENT_HEIGHT
        )

        y += REQUIREMENT_STEP

    return top


def stamp(image, text):
    """A line in the margin, where a CAD system puts its file name."""

    left, _, _, bottom = field()

    write(
        image,
        (mm(left), mm(bottom + 1.0)),
        text,
        2.2,
        kind="text",
        fill=THIN
    )


def drawing_area(note_rows):
    """What is left of the page for the views, in pixels."""

    left, top, right, bottom = field()

    block_x, block_y = block_origin()

    ceiling = block_y - REQUIREMENT_GAP - REQUIREMENT_STEP * note_rows - 4.0

    inner = left + COLUMN_WIDTH + 4.0

    def pixels(*values):
        return tuple(int(round(mm(value))) for value in values)

    views = pixels(inner, top + MARK_HEIGHT + 4.0, right, ceiling)

    corner = pixels(inner, ceiling + 4.0, block_x - 4.0, bottom)

    return views, corner
