"""Isometric drawing sheet for a STEP / FCStd model.

Runs inside freecadcmd: it needs the BREP kernel for the geometry
and for the model edges. Everything visual lives in drawing.py, so
this file only decides what belongs on the sheet.
"""

import json
import os
import sys

sys.path.insert(0, r"C:\ForgeMind")

import numpy as np

import cad
import drawing as dw

from i18n import (
    DEFAULT_LANGUAGE,
    holes_word,
    parts_word,
    t
)


# ============================================================
# CONFIG
# ============================================================

DEFAULT_STEP = r"C:\ForgeMind\files\holes_test.stp"

# Drawing area on the sheet, and the clearance kept around the
# model inside it for the dimension chains.
VIEW_BOX = (dw.CONTENT_LEFT, 142, dw.CONTENT_RIGHT, 1200)
VIEW_MARGIN = 118

BOTTOM_BAND_TOP = 1226
LEGEND_RIGHT = 1230

# --- Holes ---

# Beyond this many holes the numbers overlap into an unreadable
# blob, so the rings are drawn without them.
MAX_MARKED_HOLES = 60

MAX_HOLE_GROUPS = 8


# ============================================================
# HOLES
# ============================================================

def load_analysis(path):

    json_file = os.path.splitext(path)[0] + ".json"

    if not os.path.exists(json_file):
        return {}

    try:

        with open(json_file, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return {}


def hole_groups(holes, language):
    """Hole schedule rows, most common type first."""

    groups = {}

    for hole in holes:

        key = (
            round(hole.get("diameter_mm", 0.0), 1),
            round(hole.get("length_mm", 0.0), 1)
        )

        groups[key] = groups.get(key, 0) + 1

    ranked = sorted(groups.items(), key=lambda item: -item[1])

    rows = []

    for (diameter, length), count in ranked[:MAX_HOLE_GROUPS]:

        rows.append((
            t(
                language,
                "hole_row_3d",
                diameter=dw.format_number(diameter),
                length=dw.format_number(length)
            ),
            t(language, "count_pieces", count=count)
        ))

    hidden = len(ranked) - len(rows)

    return rows, hidden


def hole_faces(holes, camera):
    """The end of each hole that faces the camera.

    The analysis reports a hole by its middle, which sits inside
    the material; the ring belongs on the surface, and the depth
    test only works if it is tested there too.
    """

    centres = []
    radii = []
    numbers = []

    toward_viewer = camera[2]

    for index, hole in enumerate(holes):

        centre = hole.get("center")

        if not centre:
            continue

        point = np.array(centre, dtype=np.float64)

        axis = hole.get("axis")
        length = hole.get("length_mm", 0.0)

        if axis and length:

            axis = np.array(axis, dtype=np.float64)

            side = 1.0 if float(axis @ toward_viewer) >= 0.0 else -1.0

            point = point + axis * (length / 2.0 * side)

        centres.append(point)
        radii.append(hole.get("diameter_mm", 0.0) / 2.0)
        numbers.append(hole.get("index", index + 1))

    if not centres:
        return None, None, None

    return (
        np.array(centres),
        np.array(radii),
        numbers
    )


def draw_holes(page, holes, raster, camera, viewport, tolerance):

    centres, radii, numbers = hole_faces(holes, camera)

    if centres is None:
        return 0

    screen = viewport.screen_points(centres, camera)

    seen = raster.visible(
        screen,
        dw.project(centres, camera)[:, 2],
        tolerance=tolerance
    )

    if not seen.any():
        return 0

    screen = screen[seen]
    radii = radii[seen] * viewport.scale

    shown = int(seen.sum())

    dw.hole_markers(
        page,
        screen,
        radii,
        numbers=(
            [n for n, keep in zip(numbers, seen.tolist()) if keep]
            if shown <= MAX_MARKED_HOLES
            else None
        ),
        width=2 if shown <= MAX_MARKED_HOLES else 1
    )

    return shown


# ============================================================
# SHEET
# ============================================================

def draw_legend(page, holes, marked, language):

    rows, hidden = hole_groups(holes, language)

    note = None

    if hidden > 0:
        note = t(language, "legend_more_types", count=hidden)

    elif marked > MAX_MARKED_HOLES:
        note = t(language, "legend_unnumbered")

    elif holes:
        note = t(language, "legend_coordinates")

    dw.table(
        page,
        (dw.CONTENT_LEFT, BOTTOM_BAND_TOP, LEGEND_RIGHT, dw.CONTENT_BOTTOM),
        t(language, "legend_holes"),
        rows,
        columns=2,
        note=note or t(language, "holes_none_found")
    )


def draw_title_block(page, name, size, parts, holes, language):

    composition = "{} {}, {} {}".format(
        parts,
        parts_word(language, parts),
        holes,
        holes_word(language, holes)
    )

    dw.title_block(
        page,
        [
            (t(language, "lbl_file"), name),
            (
                t(language, "lbl_size"),
                dw.format_size(size, t(language, "unit_mm"))
            ),
            (t(language, "lbl_content"), composition),
            (t(language, "lbl_date"), dw.today())
        ],
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_iso")
    )


# ============================================================
# MAIN
# ============================================================

def main():

    step_file = sys.argv[1] if len(sys.argv) >= 2 else DEFAULT_STEP

    language = (
        sys.argv[2]
        if len(sys.argv) > 2
        else DEFAULT_LANGUAGE
    )

    if not os.path.exists(step_file):
        print("ERROR: STEP file not found:")
        print(step_file)
        sys.exit(1)

    print()
    print("=" * 90)
    print("FORGEMIND ISOMETRIC SHEET")
    print("=" * 90)
    print()

    print("STEP:", step_file)

    doc = cad.open_document(step_file)

    parts = cad.solid_parts(doc)

    print("PARTS:", len(parts))

    if not parts:
        print("ERROR: no solid parts in this file.")
        sys.exit(1)

    low, high = cad.model_bounds(parts)

    size = high - low

    diagonal = float(np.linalg.norm(size))

    deflection = cad.deflection_for(diagonal)

    print("SIZE:", np.round(size, 1))
    print("DEFLECTION:", round(deflection, 3))

    points, faces = cad.collect_triangles(parts, deflection)

    if points is None:
        print("ERROR: tessellation produced no geometry.")
        sys.exit(1)

    print("TRIANGLES:", len(faces))

    # --------------------------------------------------------
    # Geometry layer
    # --------------------------------------------------------

    raster = dw.Raster(dw.PAGE_WIDTH, dw.PAGE_HEIGHT)

    camera = dw.fitting_camera(
        size,
        VIEW_BOX[2] - VIEW_BOX[0] - 2 * VIEW_MARGIN,
        VIEW_BOX[3] - VIEW_BOX[1] - 2 * VIEW_MARGIN
    )

    viewport = dw.Viewport(
        dw.project(points, camera),
        VIEW_BOX,
        margin=VIEW_MARGIN
    )

    print(
        "FRONT FACES:",
        raster.draw_mesh(points, faces, camera, viewport)
    )

    raster.contact_shadow()
    raster.outline()

    polylines, dropped = cad.part_edges(parts)

    print("EDGES:", len(polylines), "TANGENT DROPPED:", dropped)

    # Only as much slack as the depth map's own error: a generous
    # tolerance here is what lets the edges of a part show through
    # the 2 mm plate in front of it.
    tolerance = 0.3 * deflection

    print(
        "EDGE SEGMENTS:",
        raster.draw_edges(
            polylines,
            camera,
            viewport,
            tolerance=tolerance
        )
    )

    page = raster.flatten()

    # --------------------------------------------------------
    # Annotations
    # --------------------------------------------------------

    dw.frame(page)

    dw.header(
        page,
        t(language, "sheet_header_iso"),
        os.path.basename(step_file)
    )

    dw.box_dimensions(
        page,
        viewport.screen_points(
            dw.box_corners(low, high),
            camera
        ),
        [dw.format_number(v) for v in size]
    )

    dw.axis_triad(
        page,
        camera,
        (dw.CONTENT_RIGHT - 96, VIEW_BOX[3] - 74)
    )

    data = load_analysis(step_file)

    holes = data.get("holes", [])

    marked = draw_holes(page, holes, raster, camera, viewport, tolerance)

    print("HOLES:", len(holes), "MARKED:", marked)

    draw_legend(page, holes, marked, language)

    draw_title_block(
        page,
        os.path.basename(step_file),
        size,
        len(parts),
        len(holes),
        language
    )

    output_file = os.path.splitext(step_file)[0] + "_render.png"

    page.save(output_file, "PNG", optimize=True)

    print()
    print("PNG:", output_file)
    print("FILE SIZE:", os.path.getsize(output_file), "bytes")

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
