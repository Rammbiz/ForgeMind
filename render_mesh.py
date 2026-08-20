"""Isometric drawing sheet for a triangle mesh (STL / OBJ / 3MF).

Plain Python: no CAD kernel is involved, which is why the mesh
pipeline is the fastest one in the bot. The sheet is put together by
drawing.py, exactly like the STEP one, so both look the same.
"""

import json
import os
import sys

sys.path.insert(0, r"C:\ForgeMind")

import numpy as np

import drawing as dw

from i18n import DEFAULT_LANGUAGE, t

from mesh_analyzer import feature_edges, load_mesh


# ============================================================
# CONFIG
# ============================================================

VIEW_BOX = (dw.CONTENT_LEFT, 142, dw.CONTENT_RIGHT, 1200)
VIEW_MARGIN = 118

BOTTOM_BAND_TOP = 1226
LEGEND_RIGHT = 1230

# Above this, drawing every feature edge costs more time than it
# adds detail on a 2000 px wide sheet.
MAX_DRAWN_EDGES = 200000

# A mesh has no exact surface to compare an edge against, so the
# depth test gets a slice of the model size as slack.
EDGE_TOLERANCE_RATIO = 0.0006


# ============================================================
# REPORT
# ============================================================

def load_report(mesh_file):

    json_file = os.path.splitext(mesh_file)[0] + ".json"

    if not os.path.exists(json_file):
        return {}

    try:

        with open(json_file, "r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return {}


def mesh_state(report, language):
    """One line on the health of the mesh."""

    mesh = report.get("mesh", {})

    if mesh.get("watertight"):
        return t(language, "mesh_state_ok")

    problems = []

    if mesh.get("open_edges"):
        problems.append(
            t(
                language,
                "mesh_state_open",
                count=mesh["open_edges"]
            )
        )

    if mesh.get("non_manifold_edges"):
        problems.append(
            t(
                language,
                "mesh_state_non_manifold",
                count=mesh["non_manifold_edges"]
            )
        )

    return ", ".join(problems) or t(language, "mesh_state_ok")


def legend_rows(report, language):

    rows = []

    if report.get("triangles"):
        rows.append((
            t(language, "lbl_triangles"),
            "{:,}".format(report["triangles"]).replace(",", " ")
        ))

    if report.get("surface_area_mm2"):
        rows.append((
            t(language, "lbl_surface"),
            dw.format_number(report["surface_area_mm2"]) + " мм²"
            if language == "uk"
            else dw.format_number(report["surface_area_mm2"]) + " mm²"
        ))

    mesh = report.get("mesh", {})

    if mesh.get("closed") and report.get("volume_mm3"):
        rows.append((
            t(language, "lbl_volume"),
            dw.format_number(report["volume_mm3"])
            + (" мм³" if language == "uk" else " mm³")
        ))

    return rows


# ============================================================
# MAIN
# ============================================================

def main():

    if len(sys.argv) < 2:
        print("Usage: render_mesh.py <mesh_file> [language]")
        sys.exit(1)

    mesh_file = sys.argv[1]

    language = (
        sys.argv[2]
        if len(sys.argv) > 2
        else DEFAULT_LANGUAGE
    )

    if not os.path.exists(mesh_file):
        print("ERROR: mesh file not found:")
        print(mesh_file)
        sys.exit(1)

    print()
    print("=" * 90)
    print("FORGEMIND MESH SHEET")
    print("=" * 90)
    print()

    print("MESH:", mesh_file)

    mesh = load_mesh(mesh_file)

    if mesh is None:
        print("ERROR: no triangles in this mesh.")
        sys.exit(1)

    points = mesh["points"]
    faces = mesh["faces"]

    print("TRIANGLES:", len(faces))

    low = points.min(axis=0)
    high = points.max(axis=0)

    size = high - low

    diagonal = float(np.linalg.norm(size))

    report = load_report(mesh_file)

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
        raster.draw_mesh(
            points,
            faces,
            camera,
            viewport,
            normals=mesh["normals"]
        )
    )

    raster.contact_shadow()
    raster.outline()

    edges = feature_edges(
        points,
        faces,
        mesh["normals"],
        mesh["edges"]
    )

    print("FEATURE EDGES:", len(edges))

    if 0 < len(edges) <= MAX_DRAWN_EDGES:

        print(
            "EDGE SEGMENTS:",
            raster.draw_lines(
                points[edges[:, 0]],
                points[edges[:, 1]],
                camera,
                viewport,
                tolerance=EDGE_TOLERANCE_RATIO * diagonal
            )
        )

    page = raster.flatten()

    # --------------------------------------------------------
    # Annotations
    # --------------------------------------------------------

    dw.frame(page)

    dw.header(
        page,
        t(language, "sheet_header_mesh"),
        os.path.basename(mesh_file)
    )

    dw.box_dimensions(
        page,
        viewport.screen_points(dw.box_corners(low, high), camera),
        [dw.format_number(v) for v in size]
    )

    dw.axis_triad(
        page,
        camera,
        (dw.CONTENT_RIGHT - 96, VIEW_BOX[3] - 74)
    )

    dw.table(
        page,
        (dw.CONTENT_LEFT, BOTTOM_BAND_TOP, LEGEND_RIGHT, dw.CONTENT_BOTTOM),
        t(language, "lbl_mesh").upper(),
        legend_rows(report, language),
        note=t(language, "mesh_no_units")
    )

    dw.title_block(
        page,
        [
            (t(language, "lbl_file"), os.path.basename(mesh_file)),
            (
                t(language, "lbl_size"),
                dw.format_size(size, t(language, "unit_mm"))
            ),
            (t(language, "lbl_mesh"), mesh_state(report, language)),
            (t(language, "lbl_date"), dw.today())
        ],
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_mesh")
    )

    output_file = os.path.splitext(mesh_file)[0] + "_render.png"

    page.save(output_file, "PNG", optimize=True)

    print()
    print("PNG:", output_file)
    print("FILE SIZE:", os.path.getsize(output_file), "bytes")

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
