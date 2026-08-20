"""Cut map for a flat drawing (DXF, or a DWG that turned out flat).

Plain Python with ezdxf. The page furniture comes from drawing.py so
the cut map, the isometric and the detail sheets are recognisably
the same document family.
"""

import json
import os
import sys

sys.path.insert(0, r"C:\ForgeMind")

from PIL import Image, ImageDraw

import drawing as dw

from dxf_analyzer import find_holes, load_contours

from i18n import DEFAULT_LANGUAGE, t


# ============================================================
# CONFIG
# ============================================================

# Drawing area, with room around the part for the dimensions.
VIEW_BOX = (dw.CONTENT_LEFT, 142, dw.CONTENT_RIGHT, 1200)
VIEW_MARGIN = 108

BOTTOM_BAND_TOP = 1226
LEGEND_RIGHT = 1230

MATERIAL_COLOR = (176, 187, 199, 255)

CONTOUR_COLOR = (28, 28, 30, 255)
CONTOUR_WIDTH = 2

# Open contours are engraving or marking rather than a cut-out.
OPEN_COLOR = (36, 104, 190, 255)
OPEN_WIDTH = 2

# Holes are outlined rather than covered by a marker: a blob large
# enough to see is larger than a small hole, and would hide the very
# feature it points at.
HOLE_COLOR = (198, 44, 44, 255)
HOLE_WIDTH = 2

# Numbers are only readable, and only worth cross-referencing
# against the chat report, while there are few holes.
MAX_LABELLED_HOLES = 12

HOLE_LABEL_OFFSET = 13

MAX_HOLE_GROUPS = 6


# ============================================================
# HELPERS
# ============================================================

def load_report(dxf_file):

    json_file = os.path.splitext(dxf_file)[0] + ".json"

    if not os.path.exists(json_file):
        return {}

    try:

        with open(json_file, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return {}


def make_transform(bbox, box, margin, scale_up=1):
    """Maps drawing coordinates to pixels, Y flipped, centred.

    `scale_up` renders the geometry on a larger canvas that is then
    reduced, which is what smooths the contours.
    """

    min_x, min_y, max_x, max_y = bbox

    width = max(max_x - min_x, 1e-9)
    height = max(max_y - min_y, 1e-9)

    left, top, right, bottom = box

    usable_width = max(right - left - 2 * margin, 1)
    usable_height = max(bottom - top - 2 * margin, 1)

    scale = min(usable_width / width, usable_height / height)

    offset_x = left + margin + (usable_width - width * scale) / 2.0
    offset_y = top + margin + (usable_height - height * scale) / 2.0

    def transform(point):

        px = offset_x + (point[0] - min_x) * scale

        # Drawing Y grows upward, screen Y grows downward.
        py = (
            offset_y
            + height * scale
            - (point[1] - min_y) * scale
        )

        return px * scale_up, py * scale_up

    rect = (
        offset_x,
        offset_y,
        offset_x + width * scale,
        offset_y + height * scale
    )

    return transform, rect, scale


def to_pixels(points, transform):

    return [transform(p) for p in points]


# ============================================================
# GEOMETRY
# ============================================================

def draw_part(canvas, contours, transform, weight=1):
    """Fills the material, punches the cut-outs, strokes the edges."""

    pen = ImageDraw.Draw(canvas)

    closed = [c for c in contours if c["closed"]]

    for contour in closed:

        if contour["inner"]:
            continue

        pen.polygon(
            to_pixels(contour["points"], transform),
            fill=MATERIAL_COLOR
        )

    # A cut-out is a hole in the material, not a solid shape, so the
    # page has to show through it.
    for contour in closed:

        if not contour["inner"]:
            continue

        pen.polygon(
            to_pixels(contour["points"], transform),
            fill=(MATERIAL_COLOR[0], MATERIAL_COLOR[1], MATERIAL_COLOR[2], 0)
        )

    for contour in closed:

        is_hole = contour.get("is_hole")

        pen.line(
            to_pixels(contour["points"], transform),
            fill=HOLE_COLOR if is_hole else CONTOUR_COLOR,
            width=(HOLE_WIDTH if is_hole else CONTOUR_WIDTH) * weight,
            joint="curve"
        )

    for contour in contours:

        if contour["closed"]:
            continue

        pen.line(
            to_pixels(contour["points"], transform),
            fill=OPEN_COLOR,
            width=OPEN_WIDTH * weight,
            joint="curve"
        )


def draw_hole_labels(page, holes, transform, scale):
    """Numbers set beside the holes, never on top of them."""

    if not holes or len(holes) > MAX_LABELLED_HOLES:
        return

    pen = ImageDraw.Draw(page)

    label_font = dw.font(19, "bold")

    for hole in holes:

        centre = hole.get("center")

        if not centre:
            continue

        x, y = transform(centre)

        # The clearance has to follow the hole: a fixed offset lands
        # inside anything larger than itself.
        radius = hole.get("diameter_mm", 0.0) / 2.0 * scale

        offset = radius * 0.71 + HOLE_LABEL_OFFSET

        pen.text(
            (x + offset, y - offset - 18),
            str(hole.get("index", "?")),
            fill=dw.ACCENT,
            font=label_font,
            stroke_width=3,
            stroke_fill=(255, 255, 255)
        )


# ============================================================
# SHEET
# ============================================================

def legend_rows(report, language):

    rows = []

    contours = report.get("contours", {})

    if contours:
        rows.append((
            t(language, "lbl_contours"),
            "{} / {} / {}".format(
                contours.get("outer", 0),
                contours.get("inner", 0),
                contours.get("open", 0)
            )
        ))

    if report.get("area_mm2"):
        rows.append((
            t(language, "lbl_area"),
            dw.format_number(report["area_mm2"])
        ))

    if report.get("perimeter_mm"):
        rows.append((
            t(language, "lbl_perimeter"),
            dw.format_number(report["perimeter_mm"])
        ))

    groups = report.get("hole_groups", [])

    for group in groups[:MAX_HOLE_GROUPS]:

        rows.append((
            t(
                language,
                "hole_row_2d",
                diameter=dw.format_number(group["diameter_mm"])
            ),
            t(language, "count_pieces", count=group["count"])
        ))

    return rows, max(0, len(groups) - MAX_HOLE_GROUPS)


def legend_note(report, holes, hidden, language):

    if hidden > 0:
        return t(language, "legend_more_types", count=hidden)

    if report.get("units") == "in":
        return t(language, "units_inches")

    if len(holes) > MAX_LABELLED_HOLES:
        return t(language, "legend_unnumbered")

    if holes:
        return t(language, "legend_coordinates")

    return None


# ============================================================
# MAIN
# ============================================================

def main():

    if len(sys.argv) < 2:
        print("Usage: render_dxf.py <dxf_file> [language]")
        sys.exit(1)

    dxf_file = sys.argv[1]

    language = (
        sys.argv[2]
        if len(sys.argv) > 2
        else DEFAULT_LANGUAGE
    )

    if not os.path.exists(dxf_file):
        print("ERROR: DXF file not found:")
        print(dxf_file)
        sys.exit(1)

    print()
    print("=" * 90)
    print("FORGEMIND CUT MAP")
    print("=" * 90)
    print()

    print("DXF:", dxf_file)

    data = load_contours(dxf_file)

    contours = data["contours"]

    print("CONTOURS:", len(contours))

    if not contours or data["bbox"] is None:
        print("ERROR: nothing drawable in this DXF.")
        sys.exit(1)

    # Tags the contours as holes, matching the report numbering.
    holes = find_holes(contours, data["scale"])

    print("HOLES:", len(holes))

    report = load_report(dxf_file)

    # --------------------------------------------------------
    # Geometry, drawn large and reduced for smooth contours
    # --------------------------------------------------------

    page = dw.sheet()

    transform, rect, scale = make_transform(
        data["bbox"],
        VIEW_BOX,
        VIEW_MARGIN
    )

    over, _, _ = make_transform(
        data["bbox"],
        VIEW_BOX,
        VIEW_MARGIN,
        scale_up=dw.SUPERSAMPLE
    )

    canvas = Image.new(
        "RGBA",
        (
            dw.PAGE_WIDTH * dw.SUPERSAMPLE,
            dw.PAGE_HEIGHT * dw.SUPERSAMPLE
        ),
        (MATERIAL_COLOR[0], MATERIAL_COLOR[1], MATERIAL_COLOR[2], 0)
    )

    draw_part(canvas, contours, over, weight=dw.SUPERSAMPLE)

    canvas = canvas.resize(
        (dw.PAGE_WIDTH, dw.PAGE_HEIGHT),
        Image.Resampling.LANCZOS
    )

    page.paste(canvas, (0, 0), canvas)

    # --------------------------------------------------------
    # Annotations
    # --------------------------------------------------------

    dw.frame(page)

    dw.header(
        page,
        t(language, "sheet_header_cut"),
        os.path.basename(dxf_file)
    )

    min_x, min_y, max_x, max_y = data["bbox"]

    left, top, right, bottom = rect

    dw.dimension(
        page,
        (left, bottom),
        (right, bottom),
        dw.format_number(max_x - min_x),
        (0.0, 1.0)
    )

    dw.dimension(
        page,
        (left, top),
        (left, bottom),
        dw.format_number(max_y - min_y),
        (-1.0, 0.0)
    )

    draw_hole_labels(page, holes, transform, scale)

    rows, hidden = legend_rows(report, language)

    dw.table(
        page,
        (dw.CONTENT_LEFT, BOTTOM_BAND_TOP, LEGEND_RIGHT, dw.CONTENT_BOTTOM),
        t(language, "tag_cut"),
        rows,
        columns=2,
        note=legend_note(report, holes, hidden, language)
    )

    dw.title_block(
        page,
        [
            (t(language, "lbl_file"), os.path.basename(dxf_file)),
            (
                t(language, "lbl_size"),
                "{} × {} {}".format(
                    dw.format_number(max_x - min_x),
                    dw.format_number(max_y - min_y),
                    t(language, "unit_mm")
                )
            ),
            (
                t(language, "lbl_cut"),
                "{} {} · {} {}".format(
                    dw.format_number(report.get("cut_length_mm", 0.0)),
                    t(language, "unit_mm"),
                    report.get("pierces", 0),
                    t(language, "lbl_pierces")
                )
            ),
            (t(language, "lbl_date"), dw.today())
        ],
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_cut")
    )

    output_file = (
        os.path.splitext(dxf_file)[0]
        + "_render.png"
    )

    page.save(output_file, "PNG", optimize=True)

    print()
    print("PNG:", output_file)
    print("FILE SIZE:", os.path.getsize(output_file), "bytes")

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
