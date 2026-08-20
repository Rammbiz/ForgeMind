"""FreeCAD-side geometry, shared by everything that needs BREP.

Only ever imported inside freecadcmd — the bot's own interpreter
has no FreeCAD module. Nothing here draws: the renderers get plain
numpy arrays back and hand them to drawing.py.
"""

import math
import os

import numpy as np

import FreeCAD
import Import

import drawing


# Two faces meeting at less than this are tangent: the line between
# them is an artefact of how the model was built, not an edge that
# anybody can see or measure.
TANGENT_ANGLE = 12.0

# Above this the adjacency scan costs more than the tidier result
# is worth.
TANGENT_FACE_LIMIT = 20000

EDGE_DEFLECTION = 0.6


# ============================================================
# DOCUMENTS
# ============================================================

def open_document(path):
    """FreeCAD's own files are opened, everything else imported."""

    if os.path.splitext(path)[1].lower() == ".fcstd":
        return FreeCAD.openDocument(path)

    Import.open(path)

    return FreeCAD.ActiveDocument


def solid_parts(doc):
    """Objects that are one solid each — the real parts."""

    parts = []

    for obj in doc.Objects:

        if obj.TypeId != "Part::Feature":
            continue

        if not hasattr(obj, "Shape") or obj.Shape.isNull():
            continue

        if len(obj.Shape.Solids) != 1:
            continue

        parts.append(obj)

    return parts


# ============================================================
# SIZE
# ============================================================

def optimal_box(shape):
    """The tight bounding box.

    The plain BoundBox is built from surface control poles, not
    geometry: on a metre-long curved part it came out 240 mm too
    large. Cross-checked against a mesh of the same part.
    """

    try:
        return shape.optimalBoundingBox()
    except Exception:
        return shape.BoundBox


def box_size(box):

    return np.array([box.XLength, box.YLength, box.ZLength])


def model_bounds(parts):
    """Overall low and high corner of a list of parts."""

    boxes = [optimal_box(obj.Shape) for obj in parts]

    return (
        np.array([
            min(b.XMin for b in boxes),
            min(b.YMin for b in boxes),
            min(b.ZMin for b in boxes)
        ]),
        np.array([
            max(b.XMax for b in boxes),
            max(b.YMax for b in boxes),
            max(b.ZMax for b in boxes)
        ])
    )


def deflection_for(diagonal, ratio=0.0012, low=0.04, high=5.0):
    """Tessellation tolerance scaled to the size of the model."""

    return min(high, max(low, diagonal * ratio))


# ============================================================
# MESH
# ============================================================

def tessellate(shape, deflection):
    """(points, faces) as numpy arrays, or (None, None)."""

    try:
        points, faces = shape.tessellate(deflection)
    except Exception:
        return None, None

    if not points or not faces:
        return None, None

    vertices = np.array(
        [[p.x, p.y, p.z] for p in points],
        dtype=np.float64
    )

    triangles = np.array(
        [f for f in faces if len(f) == 3],
        dtype=np.int64
    )

    if triangles.size == 0:
        return None, None

    return vertices, triangles


def merge_meshes(meshes):

    all_points = []
    all_faces = []

    offset = 0

    for points, faces in meshes:

        if points is None:
            continue

        all_points.append(points)
        all_faces.append(faces + offset)

        offset += len(points)

    if not all_points:
        return None, None

    return np.concatenate(all_points), np.concatenate(all_faces)


def collect_triangles(parts, deflection):

    return merge_meshes([
        tessellate(obj.Shape, deflection)
        for obj in parts
    ])


# ============================================================
# EDGES
# ============================================================

def edge_key(edge):
    """Geometric identity of an edge, stable across FreeCAD builds."""

    centre = edge.CenterOfMass

    return (
        round(centre.x, 4),
        round(centre.y, 4),
        round(centre.z, 4),
        round(edge.Length, 4)
    )


def face_normal(face, point):

    u, v = face.Surface.parameter(point)

    normal = face.normalAt(u, v)

    if face.Orientation == "Reversed":
        normal = normal.multiply(-1.0)

    return normal


def is_tangent(edge, first, second, angle):
    """True when the two faces flow into each other at this edge."""

    try:

        middle = edge.valueAt(
            (edge.FirstParameter + edge.LastParameter) / 2.0
        )

        a = face_normal(first, middle)
        b = face_normal(second, middle)

    except Exception:
        return False

    return math.degrees(a.getAngle(b)) < angle


def shape_edges(
    shape,
    deflection=EDGE_DEFLECTION,
    tangent_angle=TANGENT_ANGLE
):
    """Model edges as polylines, without the tangent ones.

    A fillet blending into a wall, or the seam of a cylinder, is a
    line in the topology but not a line on the part; drawing them
    all is what made the early renders look like scribble.
    """

    adjacency = {}

    if len(shape.Faces) <= TANGENT_FACE_LIMIT:

        for face in shape.Faces:

            for edge in face.Edges:
                adjacency.setdefault(edge_key(edge), []).append(face)

    polylines = []

    dropped = 0

    for edge in shape.Edges:

        neighbours = adjacency.get(edge_key(edge), [])

        if len(neighbours) == 2 and is_tangent(
            edge,
            neighbours[0],
            neighbours[1],
            tangent_angle
        ):
            dropped += 1
            continue

        try:
            points = edge.discretize(Deflection=deflection)
        except Exception:

            try:
                points = edge.discretize(24)
            except Exception:
                continue

        if len(points) < 2:
            continue

        polylines.append(
            np.array(
                [[p.x, p.y, p.z] for p in points],
                dtype=np.float64
            )
        )

    return polylines, dropped


def part_edges(parts, deflection=EDGE_DEFLECTION):
    """Edges of several parts at once."""

    polylines = []

    dropped = 0

    for obj in parts:

        lines, skipped = shape_edges(obj.Shape, deflection)

        polylines.extend(lines)
        dropped += skipped

    return polylines, dropped


# ============================================================
# BENT BARS AND STRIPS
#
# A bar bent in one plane has no flat side to lay it down on:
# whichever way it is turned the sheet shows its profile, and the
# overall box around a zigzag is a number nobody can cut to. What
# the shop needs is the length of every straight run and the angle
# at every bend, and those are read off the profile outline here.
# ============================================================

# Two outline edges within this angle belong to the same straight
# run; a radiused bend collapses to its theoretical corner, which
# is where a bend is dimensioned from anyway.
COLLINEAR_ANGLE = 5.0

# The two sides of one run point in opposite directions.
OPPOSITE_DOT = -0.985

# Beyond this the outline is not a bent bar but something curved.
MAX_OUTLINE_EDGES = 40
MAX_RUNS = 8

# A run has to be a real slice of the part, or noise on the outline
# turns into a dimension of its own.
MIN_RUN_RATIO = 0.04

# And it has to be longer than the material is thick. The chords of
# a bend radius are a couple of millimetres each and would otherwise
# be read as two more flanges inside the fold.
MIN_RUN_WIDTHS = 1.5

# End to end, the runs have to be at least this much of the
# part's longest side, or they are not what the part is.
MIN_DEVELOPED_RATIO = 0.85

# A bent bar does not wrap around itself. The flat end of a
# round bar is a disc, its outline is a circle, and the chords
# of that circle pair up into convincing little runs that turn
# through nearly a thousand degrees between them.
MAX_TOTAL_TURN = 300.0

# And a run shorter than the material is thick is a facet, not
# a run: real ones came out at two to three times the section,
# the circle's chords at a fifth of it.
MIN_RUN_THICKNESS = 0.6


def face_direction(face, deflection):
    """Mean normal of a face, and how flat the face really is.

    Rhino writes every surface as a B-spline, planes included, so
    asking a converted DWG what type its surfaces are answers
    nothing. Its own triangles do answer.
    """

    points, triangles = tessellate(face, deflection)

    if points is None:
        return None, 0.0

    normals = drawing.triangle_normals(points, triangles)
    areas = drawing.triangle_areas(points, triangles)

    mean = (normals * areas[:, None]).sum(axis=0)

    length = float(np.linalg.norm(mean))

    if length < 1e-12:
        return None, 0.0

    mean = mean / length

    return mean, float(np.abs(normals @ mean).min())


def profile_outline(shape, rotation, centre, deflection=0.5):
    """The part's own outline, as seen along the view axis.

    Only a part with one big flat face square to the viewer has
    one — a bar or a strip bent in a single plane. That face is the
    profile, and its outer wire is the exact polygon.
    """

    best = None

    for face in shape.Faces:

        normal, flatness = face_direction(face, deflection)

        if normal is None or flatness < 0.999:
            continue

        if abs(float((rotation @ normal)[2])) < 0.99:
            continue

        if best is None or face.Area > best.Area:
            best = face

    if best is None:
        return None

    try:
        points = best.OuterWire.discretize(Deflection=deflection)
    except Exception:
        return None

    if len(points) < 5:
        return None

    local = drawing.to_frame(
        np.array([[p.x, p.y, p.z] for p in points], dtype=np.float64),
        rotation,
        centre
    )

    return local[:, :2]


def simplify_outline(outline, minimum):
    """Duplicate and collinear points dropped from a closed outline."""

    kept = []

    for point in outline:

        if kept and np.linalg.norm(point - kept[-1]) < minimum:
            continue

        kept.append(point)

    if len(kept) > 2 and np.linalg.norm(kept[0] - kept[-1]) < minimum:
        kept.pop()

    limit = math.cos(math.radians(COLLINEAR_ANGLE))

    changed = True

    while changed and len(kept) > 3:

        changed = False

        result = []

        for index in range(len(kept)):

            before = kept[index - 1]
            here = kept[index]
            after = kept[(index + 1) % len(kept)]

            first = here - before
            second = after - here

            scale = np.linalg.norm(first) * np.linalg.norm(second)

            if scale < 1e-12:
                changed = True
                continue

            if float(first @ second) / scale > limit:
                changed = True
                continue

            result.append(here)

        kept = result

    return np.array(kept)


def pair_outline_edges(corners):
    """Outline edges matched into the two sides of each run."""

    count = len(corners)

    edges = [
        (corners[i], corners[(i + 1) % count])
        for i in range(count)
    ]

    directions = []
    lengths = []

    for head, tail in edges:

        span = tail - head

        length = float(np.linalg.norm(span))

        lengths.append(length)
        directions.append(span / max(length, 1e-9))

    partner = [-1] * count

    for i in range(count):

        best = None

        for j in range(count):

            if i == j:
                continue

            if float(directions[i] @ directions[j]) > OPPOSITE_DOT:
                continue

            axis = directions[i]

            own = sorted([
                float(edges[i][0] @ axis),
                float(edges[i][1] @ axis)
            ])

            other = sorted([
                float(edges[j][0] @ axis),
                float(edges[j][1] @ axis)
            ])

            overlap = min(own[1], other[1]) - max(own[0], other[0])

            if overlap < 0.3 * min(lengths[i], lengths[j]):
                continue

            between = (
                (edges[j][0] + edges[j][1]) / 2.0
                - (edges[i][0] + edges[i][1]) / 2.0
            )

            distance = float(
                np.linalg.norm(between - (between @ axis) * axis)
            )

            if best is None or distance < best[0]:
                best = (distance, j)

        if best is not None:
            partner[i] = best[1]

    runs = []
    widths = []

    for i in range(count):

        j = partner[i]

        if j < 0 or partner[j] != i or i > j:
            continue

        runs.append((
            (edges[i][0] + edges[j][1]) / 2.0,
            (edges[i][1] + edges[j][0]) / 2.0
        ))

        axis = directions[i]

        between = (
            (edges[j][0] + edges[j][1]) / 2.0
            - (edges[i][0] + edges[i][1]) / 2.0
        )

        widths.append(
            float(np.linalg.norm(between - (between @ axis) * axis))
        )

    return runs, widths


def crossing(first, second):
    """Where two run centre lines meet, if they do.

    A press-braked part has an arc at every fold, so consecutive
    runs stop short of each other by the bend radius and never
    share a point. Their lines still cross at the corner the
    drawing dimensions to, and that is the vertex worth having.
    """

    origin = first[0]

    a = first[1] - first[0]
    b = second[1] - second[0]

    denominator = a[0] * b[1] - a[1] * b[0]

    if abs(denominator) < 1e-9:
        return None

    delta = second[0] - origin

    along = (delta[0] * b[1] - delta[1] * b[0]) / denominator

    return origin + a * along


def chain_runs(runs, tolerance):
    """Runs walked into one chain, each turned head to tail."""

    if not runs:
        return None

    remaining = list(runs)

    chain = [remaining.pop(0)]

    while remaining:

        for index, (start, end) in enumerate(remaining):

            if np.linalg.norm(start - chain[-1][1]) <= tolerance:
                chain.append((start, end))

            elif np.linalg.norm(end - chain[-1][1]) <= tolerance:
                chain.append((end, start))

            elif np.linalg.norm(end - chain[0][0]) <= tolerance:
                chain.insert(0, (start, end))

            elif np.linalg.norm(start - chain[0][0]) <= tolerance:
                chain.insert(0, (end, start))

            else:
                continue

            remaining.pop(index)

            break

        else:
            return None

    return chain


def centre_line(chain):
    """The chain as points: two free ends and a corner per bend."""

    points = [chain[0][0]]

    for first, second in zip(chain, chain[1:]):

        corner = crossing(first, second)

        if corner is None:
            corner = (first[1] + second[0]) / 2.0

        points.append(corner)

    points.append(chain[-1][1])

    return np.array(points)


def profile_along(shape, rotation, centre, extents, deflection):
    """Runs and angles seen along this frame's third axis, or None."""

    outline = profile_outline(shape, rotation, centre, deflection)

    if outline is None:
        return None

    span = float(max(extents[0], extents[1]))

    corners = simplify_outline(outline, max(0.5, 0.004 * span))

    if len(corners) < 4 or len(corners) > MAX_OUTLINE_EDGES:
        return None

    runs, widths = pair_outline_edges(corners)

    keep = [
        index
        for index, run in enumerate(runs)
        if np.linalg.norm(run[1] - run[0]) > MIN_RUN_RATIO * span
        and np.linalg.norm(run[1] - run[0]) > MIN_RUN_WIDTHS * widths[index]
    ]

    runs = [runs[index] for index in keep]
    widths = [widths[index] for index in keep]

    if not 2 <= len(runs) <= MAX_RUNS:
        return None

    # The runs have to be most of the outline. Counting leftover
    # edges instead breaks on a radiused bend, where each arc adds
    # corners of its own to both sides of the fold.
    outline_length = sum(
        float(np.linalg.norm(corners[(i + 1) % len(corners)] - corners[i]))
        for i in range(len(corners))
    )

    paired_length = 2.0 * sum(
        float(np.linalg.norm(run[1] - run[0]))
        for run in runs
    )

    if outline_length <= 0 or paired_length / outline_length < 0.6:
        return None

    # The gap between two runs is the bend radius, not zero, so the
    # tolerance has to cover a fold rather than a rounding error.
    chain = chain_runs(runs, max(1.5, 0.15 * span))

    if chain is None or len(chain) < 2:
        return None

    line = centre_line(chain)

    if len(line) < 3:
        return None

    # The runs have to describe the whole part, not a chamfer on
    # the corner of it: a 5 mm standoff otherwise comes out as a
    # bent bar with two 1 mm runs.
    if sum(
        float(np.linalg.norm(line[i + 1] - line[i]))
        for i in range(len(line) - 1)
    ) < MIN_DEVELOPED_RATIO * span:
        return None

    lengths = [
        float(np.linalg.norm(line[i + 1] - line[i]))
        for i in range(len(line) - 1)
    ]

    angles = []

    for i in range(1, len(line) - 1):

        first = line[i - 1] - line[i]
        second = line[i + 1] - line[i]

        scale = np.linalg.norm(first) * np.linalg.norm(second)

        if scale < 1e-9:
            angles.append(180.0)
            continue

        angles.append(
            math.degrees(
                math.acos(
                    max(-1.0, min(1.0, float(first @ second) / scale))
                )
            )
        )

    thickness = float(np.mean(widths)) if widths else 0.0

    if sum(180.0 - angle for angle in angles) > MAX_TOTAL_TURN:
        return None

    if thickness > 0.0 and min(lengths) < MIN_RUN_THICKNESS * thickness:
        return None

    return {
        "line": line,
        "lengths": lengths,
        "angles": angles,
        "thickness": thickness,
        "developed": float(sum(lengths))
    }


def bent_profile(shape, rotation, centre, extents, deflection=0.5):
    """Straight runs and bend angles of a part bent in one plane.

    The profile can face any of the part's three axes: a bar bent
    on edge shows it along the view already chosen, while a bar or
    a sheet bent the flat way hides it on the side, because there
    the flats carry the area and the view went face-on. All three
    are tried, the chosen view first.

    Returns (profile, rotation, extents) — the frame comes back
    turned to whichever axis the profile was found along, and
    profile is None when the part is not bent at all.
    """

    for axis in (2, 0, 1):

        if axis == 2:
            candidate, sizes = rotation, extents
        else:
            candidate, sizes = drawing.reordered_frame(
                rotation,
                extents,
                axis
            )

        profile = profile_along(
            shape,
            candidate,
            centre,
            sizes,
            deflection
        )

        if profile is not None:
            return profile, candidate, sizes

    return None, rotation, extents


def bend_radii(shape, axis, tolerance=0.02):
    """Radii of the cylindrical faces that are bends, not holes.

    A bend's axis runs across the profile, the same way the part was
    folded; a hole through a flange points the other way. That is
    what separates them, and it is the only thing that does.

    Rhino writes every surface as a B-spline, so a converted DWG has
    no cylinder for this to find and comes back empty.
    """

    axis = drawing.normalize(axis)

    radii = []

    for face in shape.Faces:

        surface = face.Surface

        if type(surface).__name__ != "Cylinder":
            continue

        direction = drawing.normalize([
            surface.Axis.x,
            surface.Axis.y,
            surface.Axis.z
        ])

        if abs(float(direction @ axis)) < 1.0 - tolerance:
            continue

        radii.append(round(float(surface.Radius), 3))

    return sorted(set(radii))


# ============================================================
# HARDWARE
#
# Half the solids in an assembly are usually screws, nuts and
# standoffs, and a bill of materials that offers to draw a
# detail sheet for an M3 screw is a bill nobody reads. They are
# told apart by shape, because that is all a STEP file carries:
# a body turned about one axis, with or without a hole down it,
# is hardware; a plate with a hole pattern is not.
# ============================================================

# Nothing bigger than this is a fastener, whatever it looks like.
HARDWARE_LENGTH = 150.0
HARDWARE_ACROSS = 30.0

# How much of the outside has to be turned about one axis.
ROUND_SHARE = 0.30


def face_facts(shape):
    """The cylinders and the flats of one solid, by area."""

    cylinders = []
    planes = []

    for face in shape.Faces:

        kind = face.Surface.TypeId

        try:
            area = float(face.Area)
        except Exception:
            continue

        if kind == "Part::GeomCylinder":

            cylinders.append({
                "axis": normalized(face.Surface.Axis),
                "point": tuple(face.Surface.Center),
                "radius": float(face.Surface.Radius),
                "area": area
            })

        elif kind == "Part::GeomPlane":

            planes.append({
                "normal": normalized(face.Surface.Axis),
                "area": area
            })

    return cylinders, planes


def normalized(vector):

    length = math.sqrt(
        vector.x * vector.x + vector.y * vector.y + vector.z * vector.z
    )

    if length < 1e-12:
        return (0.0, 0.0, 1.0)

    return (vector.x / length, vector.y / length, vector.z / length)


def parallel_axes(first, second):

    return abs(
        first[0] * second[0] + first[1] * second[1] + first[2] * second[2]
    ) > 0.99


def hardware_facts(shape, size):
    """What a solid looks like, for the bill of materials.

    Returns None for anything too big to be a fastener, so the
    cost is only paid on the small bodies.
    """

    values = sorted(float(v) for v in size)

    if values[2] > HARDWARE_LENGTH or values[1] > HARDWARE_ACROSS:
        return None

    cylinders, planes = face_facts(shape)

    if not cylinders:
        return None

    # The axis of the largest cylinder is the axis of the part.
    main = max(cylinders, key=lambda c: c["area"])

    axis = main["axis"]

    along = [c for c in cylinders if parallel_axes(c["axis"], axis)]

    total = sum(face.Area for face in shape.Faces)

    if total <= 0.0:
        return None

    radii = sorted(set(round(c["radius"], 2) for c in along))

    # A flat across the axis is an end; a flat along it is one of
    # the six faces of a nut.
    flats = sum(
        1 for plane in planes
        if abs(
            plane["normal"][0] * axis[0]
            + plane["normal"][1] * axis[1]
            + plane["normal"][2] * axis[2]
        ) < 0.2
    )

    return {
        "round_share": round(sum(c["area"] for c in along) / total, 3),
        "radii": radii,
        "flats": flats,
        "length": round(values[2], 2),
        "across": round(values[1], 2)
    }
