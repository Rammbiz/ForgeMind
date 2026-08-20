"""One drawing sheet per unique part, as a multi-page PDF.

Runs inside freecadcmd. Each sheet carries the part drawn square to
the page, an isometric of it, and the whole assembly with that part
picked out in red so the shop can see where it belongs.

The part is deliberately not drawn in the orientation it happens to
have in the model: a bracket sitting at 31 degrees inside an
assembly has an axis-aligned bounding box that is nothing like its
real size, and cutting to that number would scrap the part. A bar
bent in one plane gets no useful box at all, so it is dimensioned
run by run instead.
"""

import json
import os
import sys

sys.path.insert(0, r"C:\ForgeMind")

import numpy as np

from PIL import Image, ImageDraw

import cad
import drawing as dw
import detail_dxf as marks

from bom import build_bom

from i18n import DEFAULT_LANGUAGE, holes_word, t


# ============================================================
# LAYOUT
# ============================================================

# A view longer than this gets the full width of the sheet; below
# it the part is squarer and the panels sit side by side.
WIDE_ASPECT = 2.2

PANEL_GAP = 54
BAND_GAP = 26

LEGEND_LEFT = dw.CONTENT_LEFT

# Room inside the main panel for the dimension chains. A bent
# bar carries them along its own axis, clear of the material,
# which needs more room than a box around a plate.
MAIN_MARGIN = 104
PROFILE_MARGIN = 160
VIEW_MARGIN = 34

# A part this much flatter than it is wide is sheet metal, and the
# shop reads its thickness as a note, not as a dimension.
PLATE_RATIO = 8.0
PLATE_THICKNESS = 30.0

# Sizes closer than this count as the same, so a part that is
# already square to the model is not announced as turned.
ROTATED_TOLERANCE = 0.02

# A hole only reads as a circle if it points at the viewer.
HOLE_AXIS_ALIGNMENT = 0.94

MAX_HOLE_GROUPS = 8
MAX_RUN_ROWS = 8

# 2000 px at this density is close to A4 landscape.
PDF_RESOLUTION = 170
PDF_QUALITY = 92


def sheet_layout(aspect, rows):
    """Panel rectangles for this part, and the title block's top.

    A long part drawn into a square panel wastes three quarters of
    it, so the views are rearranged rather than shrunk.
    """

    band_top = dw.CONTENT_BOTTOM - (
        dw.TITLE_HEAD_HEIGHT + dw.TITLE_ROW_HEIGHT * rows
    )

    bottom = band_top - BAND_GAP

    top = 152

    if aspect >= WIDE_ASPECT:

        split = int(top + (bottom - top) * 0.58)

        return {
            "main": (dw.CONTENT_LEFT, top, dw.CONTENT_RIGHT, split),
            "iso": (dw.CONTENT_LEFT, split + PANEL_GAP, 1000, bottom),
            "locator": (1030, split + PANEL_GAP, dw.CONTENT_RIGHT, bottom),
            "band": band_top
        }

    split = int(top + (bottom - top) * 0.47)

    return {
        "main": (dw.CONTENT_LEFT, top, 1150, bottom),
        "iso": (1204, top, dw.CONTENT_RIGHT, split),
        "locator": (1204, split + PANEL_GAP, dw.CONTENT_RIGHT, bottom),
        "band": band_top
    }


# ============================================================
# PANELS
# ============================================================

def render_panel(
    rect,
    points,
    faces,
    camera,
    margin,
    ramp=dw.STEEL_RAMP,
    polylines=None,
    tolerance=0.0,
    shadow=0.16
):
    """Renders one panel; returns (raster, viewport) in panel space."""

    width = rect[2] - rect[0]
    height = rect[3] - rect[1]

    raster = dw.Raster(width, height, background=dw.PANEL_FILL)

    viewport = dw.Viewport(
        dw.project(points, camera),
        (0, 0, width, height),
        margin=margin
    )

    raster.draw_mesh(points, faces, camera, viewport, ramp)

    if shadow:
        raster.contact_shadow(strength=shadow)

    raster.outline()

    if polylines:
        raster.draw_edges(
            polylines,
            camera,
            viewport,
            tolerance=tolerance
        )

    return raster, viewport


def place_panel(sheet, rect, image, caption):

    sheet.paste(image, (rect[0], rect[1]))

    dw.panel(sheet, rect, fill=None)

    dw.panel_caption(sheet, rect, caption)


# ============================================================
# HOLES
# ============================================================

def part_holes(data, index):

    return [
        hole
        for hole in data.get("holes", [])
        if hole.get("part") == index
    ]


def hole_schedule(holes, language):

    groups = {}

    for hole in holes:

        key = round(hole.get("diameter_mm", 0.0), 1)

        groups[key] = groups.get(key, 0) + 1

    ranked = sorted(groups.items())

    rows = [
        (
            t(
                language,
                "hole_row_2d",
                diameter=dw.format_number(diameter)
            ),
            t(language, "count_pieces", count=count)
        )
        for diameter, count in ranked[:MAX_HOLE_GROUPS]
    ]

    return rows, len(ranked) - len(rows)


def flat_holes(holes, rotation, centre, camera):
    """Holes that open toward the viewer, in the part's own frame.

    Which is a flat drawing in everything but name, so the same
    callouts and chains can be put on it.
    """

    kept = []

    for hole in holes:

        point = hole.get("center")

        if not point:
            continue

        axis = hole.get("axis")

        if axis:

            local_axis = rotation @ np.array(axis, dtype=np.float64)

            if abs(float(local_axis @ camera[2])) < HOLE_AXIS_ALIGNMENT:
                continue

        kept.append(hole)

    if not kept:
        return []

    local = dw.to_frame(
        np.array([hole["center"] for hole in kept], dtype=np.float64),
        rotation,
        centre
    )

    return [
        {
            "center": [float(local[index][0]), float(local[index][1])],
            "diameter_mm": hole.get("diameter_mm", 0.0)
        }
        for index, hole in enumerate(kept)
    ]


def draw_face_holes(panel, holes, rotation, centre, camera, viewport):
    """Rings on the holes that open toward the viewer."""

    if not holes:
        return

    centres = []
    radii = []

    for hole in holes:

        point = hole.get("center")

        if not point:
            continue

        axis = hole.get("axis")

        if axis:

            local_axis = rotation @ np.array(axis, dtype=np.float64)

            if abs(float(local_axis @ camera[2])) < HOLE_AXIS_ALIGNMENT:
                continue

        centres.append(point)
        radii.append(hole.get("diameter_mm", 0.0) / 2.0)

    if not centres:
        return

    local = dw.to_frame(
        np.array(centres, dtype=np.float64),
        rotation,
        centre
    )

    dw.hole_markers(
        panel,
        viewport.screen_points(local, camera),
        [r * viewport.scale for r in radii],
        minimum_radius=3.5
    )


# ============================================================
# BENT BARS
# ============================================================

def segment_distance(point, head, tail):

    span = tail - head

    length = float(span @ span)

    if length < 1e-9:
        return float(np.linalg.norm(point - head))

    position = max(0.0, min(1.0, float((point - head) @ span) / length))

    return float(np.linalg.norm(point - (head + span * position)))


def clear_side(line, index, reach):
    """Which side of a run its dimension can stand clear on.

    "Away from the centre" is the usual rule and it fails on a
    zigzag, where the middle run sits on the centre; the side with
    more room around it is the one that works.
    """

    head = line[index]
    tail = line[index + 1]

    span = tail - head

    length = float(np.linalg.norm(span))

    if length < 1e-9:
        return np.array([0.0, -1.0])

    direction = span / length

    perpendicular = np.array([-direction[1], direction[0]])

    best = None

    for side in (perpendicular, -perpendicular):

        probe = (head + tail) / 2.0 + side * reach

        clearance = min(
            segment_distance(probe, line[i], line[i + 1])
            for i in range(len(line) - 1)
        )

        if best is None or clearance > best[0]:
            best = (clearance, side)

    return best[1]


def draw_bent_profile(image, profile, viewport, language):
    """Every straight run dimensioned, every bend angle marked.

    Both stand off the centre line by half the bar and then some:
    the runs are dimensioned along their axis, and a fixed offset
    would leave the chains buried inside the material.
    """

    line = profile["line"]

    screen = viewport.screen_points(
        np.column_stack([line, np.zeros(len(line))]),
        dw.TOP_CAMERA
    )

    half = profile["thickness"] / 2.0 * viewport.scale

    offset = max(dw.DIMENSION_OFFSET, half + 30.0)
    radius = max(52.0, half + 26.0)

    for index, length in enumerate(profile["lengths"]):

        dw.dimension(
            image,
            screen[index],
            screen[index + 1],
            dw.format_number(length),
            clear_side(screen, index, offset),
            offset=offset
        )

    for index, angle in enumerate(profile["angles"], 1):

        dw.angle_marker(
            image,
            screen[index],
            screen[index - 1],
            screen[index + 1],
            "{}°".format(dw.format_number(angle)),
            radius=radius
        )


def run_schedule(profile, language):

    rows = []

    for index, length in enumerate(profile["lengths"], 1):

        rows.append((
            t(language, "run_row", number=index),
            dw.format_number(length)
        ))

        if len(rows) >= MAX_RUN_ROWS:
            break

    rows.append((
        t(language, "run_total"),
        dw.format_number(profile["developed"])
    ))

    return rows


# ============================================================
# SHEET
# ============================================================

def build_sheet(
    row,
    part,
    locator,
    source_name,
    page,
    pages,
    language
):
    """One finished sheet for one bill-of-materials position."""

    sheet = dw.sheet()

    dw.frame(sheet)

    dw.header(
        sheet,
        t(
            language,
            "sheet_position",
            position=row["position"],
            name=row["name"]
        ),
        t(
            language,
            "sheet_of",
            file=source_name,
            page=page,
            pages=pages
        ),
        dw.today()
    )

    points = part["points"]
    faces = part["faces"]
    extents = part["extents"]
    profile = part["profile"]
    size = part["size"]

    layout = sheet_layout(
        extents[0] / max(extents[1], 1e-9),
        5 if profile else 4
    )

    # --------------------------------------------------------
    # Main view: the part square to the sheet
    # --------------------------------------------------------

    panel, viewport = render_panel(
        layout["main"],
        points,
        faces,
        dw.TOP_CAMERA,
        PROFILE_MARGIN if profile else MAIN_MARGIN,
        polylines=part["edges"],
        tolerance=part["tolerance"]
    )

    image = panel.flatten()

    if profile:

        # The box around a zigzag is not a number anybody can cut
        # to; the runs and the angles are.
        draw_bent_profile(image, profile, viewport, language)

    else:

        flat = flat_holes(
            part["holes"],
            part["rotation"],
            part["centre"],
            dw.TOP_CAMERA
        )

        # part["points"] are already in the part frame; the holes
        # come from the report in model coordinates, which is why
        # only they are turned into it.
        bbox = (
            float(points[:, 0].min()),
            float(points[:, 1].min()),
            float(points[:, 0].max()),
            float(points[:, 1].max())
        )

        # A plate with holes gets the same markup a DXF of it
        # would have got: every diameter called out with how many
        # there are, and the holes measured off one datum edge.
        if flat:

            marks.draw_flat_marks(
                image,
                flat,
                bbox,
                (
                    0,
                    0,
                    layout["main"][2] - layout["main"][0],
                    layout["main"][3] - layout["main"][1]
                ),
                language,
                viewport.scale,
                marks.Placed(viewport, dw.TOP_CAMERA, bbox),
                baseline=False,
                side=-1
            )

            dw.box_dimensions(
                image,
                viewport.screen_points(
                    dw.box_corners(points.min(axis=0), points.max(axis=0)),
                    dw.TOP_CAMERA
                ),
                [dw.format_number(v) for v in extents],
                axes=(0, 1)
            )

        else:

            dw.box_dimensions(
                image,
                viewport.screen_points(
                    dw.box_corners(points.min(axis=0), points.max(axis=0)),
                    dw.TOP_CAMERA
                ),
                [dw.format_number(v) for v in extents],
                axes=(0, 1)
            )

    draw_face_holes(
        image,
        part["holes"],
        part["rotation"],
        part["centre"],
        dw.TOP_CAMERA,
        viewport
    )

    # Sheet metal states its thickness as a note. Both other sides
    # have to be much larger, and the stock has to be something a
    # shop actually cuts: a 780 mm bracket 40 mm thick is not sheet
    # metal, however long it is.
    if (
        size[1] > PLATE_RATIO * size[2]
        and size[2] <= PLATE_THICKNESS
    ):

        ImageDraw.Draw(image).text(
            (layout["main"][2] - layout["main"][0] - 132, 34),
            t(
                language,
                "sheet_thickness",
                value=dw.format_number(size[2])
            ),
            fill=dw.INK,
            font=dw.font(30, "drawing")
        )

    place_panel(
        sheet,
        layout["main"],
        image,
        t(
            language,
            "sheet_view_profile" if profile else "sheet_view_plane"
        )
    )

    # --------------------------------------------------------
    # Isometric of the part alone
    # --------------------------------------------------------

    iso_rect = layout["iso"]

    iso_camera = dw.fitting_camera(
        extents,
        iso_rect[2] - iso_rect[0] - 2 * VIEW_MARGIN,
        iso_rect[3] - iso_rect[1] - 2 * VIEW_MARGIN
    )

    panel, _ = render_panel(
        iso_rect,
        points,
        faces,
        iso_camera,
        VIEW_MARGIN,
        polylines=part["edges"],
        tolerance=part["tolerance"]
    )

    place_panel(
        sheet,
        iso_rect,
        panel.flatten(),
        t(language, "sheet_iso")
    )

    # --------------------------------------------------------
    # Locator: the whole assembly with this part picked out
    # --------------------------------------------------------

    locator_rect = layout["locator"]

    panel = locator["raster"][locator_rect].copy()

    # Drawn over the assembly rather than depth tested: the point is
    # to find the part, so it has to be visible even when it sits
    # behind something.
    panel.draw_mesh(
        part["world_points"],
        faces,
        locator["camera"][locator_rect],
        locator["viewport"][locator_rect],
        dw.HIGHLIGHT_RAMP
    )

    image = panel.flatten()

    screen = locator["viewport"][locator_rect].screen_points(
        part["world_points"],
        locator["camera"][locator_rect]
    )

    ImageDraw.Draw(image).rectangle(
        (
            float(screen[:, 0].min()) - 11,
            float(screen[:, 1].min()) - 11,
            float(screen[:, 0].max()) + 11,
            float(screen[:, 1].max()) + 11
        ),
        outline=dw.ACCENT,
        width=2
    )

    place_panel(
        sheet,
        locator_rect,
        image,
        t(language, "sheet_locator")
    )

    # --------------------------------------------------------
    # Title block and schedule
    # --------------------------------------------------------

    rows = [
        (
            t(language, "lbl_quantity"),
            t(language, "count_pieces", count=row["count"])
        ),
        (
            t(language, "lbl_size"),
            dw.format_size(size, t(language, "unit_mm"))
        )
    ]

    if profile:
        rows.append((
            t(language, "lbl_developed"),
            "{} {}".format(
                dw.format_number(profile["developed"]),
                t(language, "unit_mm")
            )
        ))

    rows.append((
        t(language, "lbl_holes"),
        "{} {}".format(
            len(part["holes"]),
            holes_word(language, len(part["holes"]))
        )
    ))

    rows.append((t(language, "lbl_source"), source_name))

    block = dw.title_block(
        sheet,
        rows,
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_detail")
    )

    if profile:

        heading = t(language, "legend_runs")
        schedule = run_schedule(profile, language)
        note = t(language, "legend_run_note")

    else:

        heading = t(language, "legend_holes")
        schedule, hidden = hole_schedule(part["holes"], language)

        note = None

        if not schedule:
            schedule = [(t(language, "holes_none_found"), "")]

        elif hidden > 0:
            note = t(language, "legend_more_types", count=hidden)

    if part["rotated"]:
        note = t(language, "sheet_rotated")

    dw.table(
        sheet,
        (LEGEND_LEFT, block[1], block[0] - 24, dw.CONTENT_BOTTOM),
        heading,
        schedule,
        columns=2,
        note=note
    )

    return sheet


# ============================================================
# PREPARATION
# ============================================================

def prepare_part(obj, data, row, deflection):
    """Everything one sheet needs about one part.

    The part is turned into its own frame here — longest side
    first, thinnest last — so every view on the sheet and every
    number printed on it agree with each other.
    """

    world_points, faces = cad.tessellate(obj.Shape, deflection)

    if world_points is None:
        return None

    rotation, size, centre = dw.oriented_frame(world_points, faces)

    rotation, extents = dw.reordered_frame(
        rotation,
        size,
        dw.view_axis(world_points, faces, rotation)
    )

    # A bent part is turned again if its profile faces another way.
    profile, rotation, extents = cad.bent_profile(
        obj.Shape,
        rotation,
        centre,
        extents,
        deflection
    )

    box_size = cad.box_size(cad.optimal_box(obj.Shape))

    # A part that sits at an angle in the assembly has a bounding
    # box far bigger than itself; the sheet says so.
    rotated = bool(
        np.any(
            np.abs(np.sort(box_size)[::-1] - size)
            > ROTATED_TOLERANCE * np.maximum(size, 1e-6)
        )
    )

    edges, _ = cad.shape_edges(obj.Shape)

    return {
        "points": dw.to_frame(world_points, rotation, centre),
        "world_points": world_points,
        "faces": faces,
        "edges": [
            dw.to_frame(line, rotation, centre)
            for line in edges
        ],
        "extents": extents,
        "size": size,
        "rotation": rotation,
        "centre": centre,
        "rotated": rotated,
        "tolerance": 0.3 * deflection,
        "holes": part_holes(data, row["index"]),
        "profile": profile
    }


class Locator:
    """The assembly rendered once per panel size, reused by sheets.

    Two layouts mean two panel sizes, and re-rendering the whole
    assembly for every sheet would dominate the run time.
    """

    def __init__(self, parts, deflection):

        self.points, self.faces = cad.merge_meshes([
            cad.tessellate(obj.Shape, deflection)
            for obj in parts
        ])

        low, high = cad.model_bounds(parts)

        self.size = high - low

        self.rasters = {}
        self.cameras = {}
        self.viewports = {}

    def prepare(self, rect):

        if rect in self.rasters:
            return

        width = rect[2] - rect[0]
        height = rect[3] - rect[1]

        camera = dw.fitting_camera(
            self.size,
            width - 2 * VIEW_MARGIN,
            height - 2 * VIEW_MARGIN
        )

        raster = dw.Raster(width, height, background=dw.PANEL_FILL)

        viewport = dw.Viewport(
            dw.project(self.points, camera),
            (0, 0, width, height),
            margin=VIEW_MARGIN
        )

        raster.draw_mesh(
            self.points,
            self.faces,
            camera,
            viewport,
            dw.CONTEXT_RAMP
        )

        raster.outline(color=(158, 164, 174))

        self.rasters[rect] = raster
        self.cameras[rect] = camera
        self.viewports[rect] = viewport


class LocatorView:
    """Small adapter so a sheet can index the locator by rectangle."""

    def __init__(self, locator, kind):

        self.locator = locator
        self.kind = kind

    def __getitem__(self, rect):

        self.locator.prepare(rect)

        if self.kind == "raster":
            return self.locator.rasters[rect]

        if self.kind == "camera":
            return self.locator.cameras[rect]

        return self.locator.viewports[rect]


# ============================================================
# MAIN
# ============================================================

def main():

    if len(sys.argv) < 2:
        print("Usage: detail_sheets.py <cad_file> [language]")
        sys.exit(1)

    cad_file = sys.argv[1]

    language = (
        sys.argv[2]
        if len(sys.argv) > 2
        else DEFAULT_LANGUAGE
    )

    # One position only, for the viewer's "send me this sheet".
    wanted = None

    if len(sys.argv) > 3 and sys.argv[3].isdigit():
        wanted = int(sys.argv[3])

    if not os.path.exists(cad_file):
        print("ERROR: file not found:")
        print(cad_file)
        sys.exit(1)

    json_file = os.path.splitext(cad_file)[0] + ".json"

    if not os.path.exists(json_file):
        print("ERROR: analysis JSON missing.")
        sys.exit(1)

    print()
    print("=" * 90)
    print("FORGEMIND DETAIL SHEETS")
    print("=" * 90)
    print()

    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    rows = build_bom(data)

    if not rows:
        print("ERROR: no parts to detail.")
        sys.exit(1)

    print("POSITIONS:", len(rows))

    doc = cad.open_document(cad_file)

    parts = cad.solid_parts(doc)

    by_name = {obj.Name: obj for obj in parts}

    low, high = cad.model_bounds(parts)

    assembly_deflection = cad.deflection_for(
        float(np.linalg.norm(high - low))
    )

    print("DEFLECTION:", round(assembly_deflection, 3))

    locator = Locator(parts, assembly_deflection)

    views = {
        "raster": LocatorView(locator, "raster"),
        "camera": LocatorView(locator, "camera"),
        "viewport": LocatorView(locator, "viewport")
    }

    source_name = os.path.basename(cad_file)

    sheets = []

    for page, row in enumerate(rows, 1):

        if wanted is not None and row["position"] != wanted:
            continue

        obj = by_name.get(row["name"])

        if obj is None:
            print("SKIP (part not found):", row["name"])
            continue

        size = cad.box_size(cad.optimal_box(obj.Shape))

        part = prepare_part(
            obj,
            data,
            row,
            cad.deflection_for(float(np.linalg.norm(size)))
        )

        if part is None:
            print("SKIP (no mesh):", row["name"])
            continue

        sheets.append(
            build_sheet(
                row,
                part,
                views,
                source_name,
                page,
                len(rows),
                language
            )
        )

        print(
            "SHEET {} of {} - {} size {} {}".format(
                page,
                len(rows),
                row["name"],
                np.round(part["size"], 1),
                (
                    "runs {}".format(
                        [round(v, 1) for v in part["profile"]["lengths"]]
                    )
                    if part["profile"]
                    else ("(turned)" if part["rotated"] else "")
                )
            )
        )

    if not sheets:
        print("ERROR: no sheets produced.")
        sys.exit(1)

    output_file = os.path.splitext(cad_file)[0] + (
        "_details.pdf"
        if wanted is None
        else "_sheet{}.pdf".format(wanted)
    )

    sheets[0].save(
        output_file,
        save_all=True,
        append_images=sheets[1:],
        resolution=PDF_RESOLUTION,
        quality=PDF_QUALITY
    )

    print()
    print("PDF:", output_file)
    print("PAGES:", len(sheets))
    print("FILE SIZE:", os.path.getsize(output_file), "bytes")

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
