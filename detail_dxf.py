"""A dimensioned drawing of a flat part, built from its own DXF.

The cut map answers "what is on this sheet". This answers the next
question, the one the man at the machine asks: what do I cut it
to. Four views on the usual ForgeMind page, laid out the way a
draughtsman lays them out:

* the part with a diameter callout on every hole, on leaders that
  reach out to the margin rather than crowd the part;
* the same part again, carrying dimension chains from one datum
  edge out to every hole column and every hole row;
* an edge view, which is the only place a thickness can go;
* a small pictorial, so nobody has to imagine it.

A DXF has no thickness. The chat asks for it and passes it in, and
when nobody answers the edge view is dropped and the pictorial is
drawn at a nominal thickness and says so. A number nobody typed
does not go on a drawing.

Plain Python: ezdxf through dxf_analyzer, numpy and PIL through
drawing.py, no CAD kernel anywhere.
"""

import math
import os
import re
import sys

sys.path.insert(0, r"C:\ForgeMind")

import numpy as np

from PIL import Image, ImageDraw, ImageFilter

import drawing as dw
import eskd

from i18n import DEFAULT_LANGUAGE, t

# The plain geometry comes from drawing.py rather than from the
# DXF reader, so this module can also be imported inside
# freecadcmd, where ezdxf does not exist. What does need the
# reader is imported where it is used.
centroid = dw.centroid
point_in_polygon = dw.point_in_polygon
polygon_area = dw.polygon_area
polyline_length = dw.polyline_length


# ============================================================
# CONFIGURATION
# ============================================================

PANEL_GAP = 40

# Ink weights. A drawing is a line drawing: the part is not
# shaded, and the only colour is on the hole centres, so they can
# be picked out of a plate full of them.
CONTOUR_COLOR = (28, 30, 34)
CONTOUR_WIDTH = 2

# An open contour is engraving or marking, not a cut-out.
OPEN_COLOR = (36, 104, 190)

CENTRE_COLOR = (198, 44, 44)

THIN_COLOR = (122, 128, 138)

MATERIAL_COLOR = (196, 204, 214)

LEADER_COLOR = (52, 56, 62)

# Room for the callout leaders, left and right of the part.
CALLOUT_MARGIN = 172

CALLOUT_STEP = 40
CALLOUT_SIZE = 23

# Past a handful of holes the shop calls them out by diameter
# and says how many, which is what all three of the drawings
# this follows do, and what keeps fourteen leaders off a plate
# that has four kinds of hole in it.
MAX_CALLOUTS = 4

# Beyond this the edge view is a hatch pattern rather than a view.
MAX_EDGE_TICKS = 24

# Dimension chains: how far the first one sits off the part, and
# how far apart the rest stack.
CHAIN_OFFSET = 52
CHAIN_STEP = 42

CHAIN_SIZE = 24

# More chains than this is a wall of numbers nobody reads; the
# coordinates are in the report anyway.
MAX_CHAIN = 24

# Hole centres closer than this along an axis are one column.
CLUSTER_MIN = 0.15
CLUSTER_RATIO = 0.002

# Turning the part is only worth the confusion when it buys a
# real share of the page back.
# The smallest box is not always the right box. A tapered arm
# has its holes drilled from a centre line that is a few degrees
# off its own longest edge, and laid down on the edge instead
# every row of holes comes out as two rows a millimetre apart.
# Standing the part on the holes costs a little box and is worth
# it up to here.
PATTERN_SLACK = 1.12

LAY_DOWN_GAIN = 0.85

LAY_DOWN_SAMPLES = 400

# Without a thickness the pictorial still has to be an object, so
# it gets a plausible one and the caption says it is not measured.
NOMINAL_RATIO = 0.014
NOMINAL_MIN = 1.0

ISO_MARGIN = 40

# A nest of fifty parts carries more edges than the pictorial
# has pixels to draw them in, and stroking every hole fills it
# in solid black. Past this the holes are left shaded.
MAX_DRAWN_RINGS = 120

PDF_RESOLUTION = 170
PDF_QUALITY = 92


# ============================================================
# GEOMETRY
# ============================================================

def closed_ring(points):
    """The ring with its first point repeated at the end."""

    if points[0] != points[-1]:
        return list(points) + [points[0]]

    return list(points)


def signed_area(ring):

    total = 0.0

    for i in range(len(ring) - 1):

        x1, y1 = ring[i]
        x2, y2 = ring[i + 1]

        total += x1 * y2 - x2 * y1

    return total / 2.0


def cluster(values, tolerance):
    """Values within `tolerance` of each other, averaged into one."""

    groups = []

    for value in sorted(values):

        if groups and value - groups[-1][-1] <= tolerance:
            groups[-1].append(value)
        else:
            groups.append([value])

    return [sum(group) / len(group) for group in groups]


class Fit:
    """Maps drawing millimetres into a pixel box, Y flipped.

    `over` renders the same layout on a canvas scaled up by that
    factor, which is then reduced: annotations are placed with an
    over=1 twin of the same fit, so the two always agree.
    """

    def __init__(self, bbox, box, margins=(0, 0, 0, 0), over=1, scale=None):

        min_x, min_y, max_x, max_y = bbox

        self.min_x = min_x
        self.min_y = min_y

        self.width = max(max_x - min_x, 1e-9)
        self.height = max(max_y - min_y, 1e-9)

        left, top, right, bottom = box

        margin_left, margin_top, margin_right, margin_bottom = margins

        usable_width = max(
            right - left - margin_left - margin_right,
            1.0
        )

        usable_height = max(
            bottom - top - margin_top - margin_bottom,
            1.0
        )

        # A drawing that states a scale is drawn at it, so the
        # caller can hand down the standard one it settled on.
        self.scale = scale or min(
            usable_width / self.width,
            usable_height / self.height
        )

        self.left = (
            left
            + margin_left
            + (usable_width - self.width * self.scale) / 2.0
        )

        self.top = (
            top
            + margin_top
            + (usable_height - self.height * self.scale) / 2.0
        )

        self.over = over

        self.rect = (
            self.left,
            self.top,
            self.left + self.width * self.scale,
            self.top + self.height * self.scale
        )

    def __call__(self, point):

        x = self.left + (point[0] - self.min_x) * self.scale

        y = (
            self.top
            + (self.height - (point[1] - self.min_y)) * self.scale
        )

        return x * self.over, y * self.over

    def ring(self, points):

        return [self(point) for point in points]

    def enlarged(self, over):

        twin = Fit.__new__(Fit)

        twin.__dict__.update(self.__dict__)

        twin.over = over

        return twin


# ============================================================
# LAYING THE PART DOWN
#
# A part drawn on the diagonal wastes three quarters of the page
# and, worse, its bounding box is a number nobody can buy stock
# to: a 311 x 311 square for a bar 330 long and 30 wide. Turning
# it flat is what a draughtsman does before dimensioning it.
# ============================================================

def turned(points, angle):

    cosine = math.cos(angle)
    sine = math.sin(angle)

    return [
        (x * cosine + y * sine, -x * sine + y * cosine)
        for x, y in points
    ]


def box_area(points):

    xs = [p[0] for p in points]
    ys = [p[1] for p in points]

    return (max(xs) - min(xs)) * (max(ys) - min(ys))


def convex_hull(points):
    """The hull, by monotone chain."""

    unique = sorted(set((round(x, 6), round(y, 6)) for x, y in points))

    if len(unique) < 3:
        return unique

    def half(sequence):

        built = []

        for point in sequence:

            while len(built) >= 2:

                (x1, y1), (x2, y2) = built[-2], built[-1]

                if (x2 - x1) * (point[1] - y1) - (y2 - y1) * (point[0] - x1) > 0:
                    break

                built.pop()

            built.append(point)

        return built[:-1]

    return half(unique) + half(list(reversed(unique)))


def flattest_angle(points):
    """The turn that puts the part in the smallest box, exactly.

    The smallest rectangle around a shape always has one side
    flush with an edge of its convex hull, so the answer is one
    of those directions and no sweep is needed. That matters: a
    sweep resolving a tenth of a degree leaves a quarter of a
    millimetre of tilt over a long arm, and the drawing then
    reports one row of holes as two rows a millimetre apart.
    """

    hull = convex_hull(points)

    if len(hull) < 3:
        return 0.0, box_area(points)

    best = None

    for index in range(len(hull)):

        first = hull[index]
        second = hull[(index + 1) % len(hull)]

        dx = second[0] - first[0]
        dy = second[1] - first[1]

        if math.hypot(dx, dy) < 1e-9:
            continue

        angle = math.atan2(dy, dx) % (math.pi / 2.0)

        area = box_area(turned(hull, angle))

        if best is None or area < best[1]:
            best = (angle, area)

    if best is None:
        return 0.0, box_area(points)

    return best


def pattern_angle(holes, span):
    """The direction the holes themselves are lined up on.

    Every pair of holes votes for a direction, weighted by how
    far apart they are, because a long pair pins an angle down
    and two holes side by side barely do. The votes are counted
    in a window rather than in a bin: a pattern is never exactly
    one angle, and splitting it across two bins loses it.
    """

    if len(holes) < 4:
        return None

    quarter = math.pi / 2.0

    pairs = []

    for index, first in enumerate(holes):

        for second in holes[index + 1:]:

            dx = second["center"][0] - first["center"][0]
            dy = second["center"][1] - first["center"][1]

            length = math.hypot(dx, dy)

            if length < span * 0.02:
                continue

            pairs.append((length, math.atan2(dy, dx) % quarter))

    if len(pairs) < 4:
        return None

    def offset(heading, centre):

        return ((heading - centre + quarter / 2.0) % quarter) - quarter / 2.0

    # Wide enough to hold a pattern that is not exactly one
    # angle, narrow enough not to swallow the diagonals of it.
    window = math.radians(2.5)

    total = sum(length for length, _ in pairs)

    best = None

    for _, centre in pairs:

        weight = sum(
            length for length, heading in pairs
            if abs(offset(heading, centre)) <= window
        )

        if best is None or weight > best[0]:
            best = (weight, centre)

    # Holes that agree about nothing leave the part on its box.
    if best[0] < total * 0.35:
        return None

    found = best[1]

    for tolerance in (window, math.radians(0.4)):

        weight = 0.0
        drift = 0.0

        for length, heading in pairs:

            step = offset(heading, found)

            if abs(step) > tolerance:
                continue

            weight += length
            drift += length * step

        if weight > 0.0:
            found += drift / weight

    return found % quarter


def spin(data, holes, angle):
    """Turns everything by `angle` and returns the new box."""

    for contour in data["contours"]:
        contour["points"] = turned(contour["points"], angle)

    for hole in holes:
        hole["center"] = list(turned([hole["center"]], angle)[0])

    xs = []
    ys = []

    for contour in data["contours"]:
        for x, y in contour["points"]:
            xs.append(x)
            ys.append(y)

    data["bbox"] = (min(xs), min(ys), max(xs), max(ys))

    return data["bbox"]


def lay_down(data, holes):
    """Turns a single part flat, and says by how much.

    Only a single part: a nest is drawn as it will be cut, and
    turning it would say nothing true about the sheet it goes on.
    """

    outer = [
        contour
        for contour in data["contours"]
        if contour["closed"] and not contour["inner"]
    ]

    if len(outer) != 1:
        return 0.0

    angle, area = flattest_angle(outer[0]["points"])

    xs = [p[0] for p in outer[0]["points"]]
    ys = [p[1] for p in outer[0]["points"]]

    span = max(max(xs) - min(xs), max(ys) - min(ys))

    drilled = pattern_angle(holes, span)

    if drilled is not None:

        quarter = math.pi / 2.0

        # The same direction four ways round; the one nearest the
        # box keeps the part the way up it already found.
        offset = ((drilled - angle + quarter / 2.0) % quarter) - quarter / 2.0

        candidate = angle + offset

        drilled_area = box_area(turned(outer[0]["points"], candidate))

        if drilled_area <= area * PATTERN_SLACK:
            angle, area = candidate, drilled_area

    if not angle:
        return 0.0

    upright = box_area(outer[0]["points"])

    # Turning a part that is already square to its own drawing
    # gains nothing and costs the reader the coordinates he knows.
    if area > upright * LAY_DOWN_GAIN:
        return 0.0

    for contour in data["contours"]:
        contour["points"] = turned(contour["points"], angle)

    for hole in holes:
        hole["center"] = list(turned([hole["center"]], angle)[0])

    xs = []
    ys = []

    for contour in data["contours"]:
        for x, y in contour["points"]:
            xs.append(x)
            ys.append(y)

    data["bbox"] = (min(xs), min(ys), max(xs), max(ys))

    return math.degrees(angle)


# ============================================================
# LINE VIEWS
#
# A drawing is a line drawing. The part is not shaded and not
# filled here: a shop reads the outline, and anything else laid
# over it only competes with the dimensions.
# ============================================================

def draw_contours(canvas, contours, fit, weight=1):

    pen = ImageDraw.Draw(canvas)

    for contour in contours:

        points = fit.ring(contour["points"])

        if len(points) < 2:
            continue

        pen.line(
            points,
            fill=(
                CONTOUR_COLOR
                if contour["closed"]
                else OPEN_COLOR
            ),
            width=CONTOUR_WIDTH * weight,
            joint="curve"
        )


def draw_centre_marks(page, holes, fit, reach=8):
    """The little crosses that say "this is a hole, here"."""

    pen = ImageDraw.Draw(page)

    for hole in holes:

        x, y = fit(hole["center"])

        arm = hole["diameter_mm"] / 2.0 * fit.scale + reach

        pen.line([(x - arm, y), (x + arm, y)], fill=CENTRE_COLOR, width=1)
        pen.line([(x, y - arm), (x, y + arm)], fill=CENTRE_COLOR, width=1)


# ============================================================
# ARCS AND CORNERS
#
# A DXF arrives flattened: every arc is a run of short segments
# and every fillet a handful of points. So the radii and the
# corner angles the shop wants marked are measured back off the
# outline rather than read out of the file, which has the happy
# side effect of giving the same answer whatever wrote the DXF
# and whether the arc came in as an ARC, a bulge or a polyline.
# ============================================================

# An arc has to turn this far before it is worth a radius.
MIN_ARC_SWEEP = 22.0

# Points on one arc agree about where its centre is to within
# this share of the radius.
ARC_TOLERANCE = 0.08

# Anything flatter than this is the outline itself, not a fillet.
MAX_ARC_RATIO = 1.1

MAX_RADII = 7

# Radii within this of each other are the same radius.
RADIUS_TOLERANCE = 0.06

# Runs shorter than this share of the part carry no angle worth
# dimensioning.
MIN_RUN_RATIO = 0.06

# A corner this close to square or to straight says nothing that
# the overall dimensions have not said already.
SQUARE_TOLERANCE = 4.0

MAX_ANGLES = 4

# More steps than this along one line is a wall of numbers.
MAX_PITCH_RUNS = 14

RADIUS_STAND_OFF = 16.0
RADIUS_LEADER = 34.0


def circle_through(first, second, third):
    """Centre and radius of the circle through three points."""

    ax, ay = first
    bx, by = second
    cx, cy = third

    turn = 2.0 * (
        ax * (by - cy) + bx * (cy - ay) + cx * (ay - by)
    )

    if abs(turn) < 1e-12:
        return None

    a2 = ax * ax + ay * ay
    b2 = bx * bx + by * by
    c2 = cx * cx + cy * cy

    ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / turn
    uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / turn

    return (ux, uy), math.hypot(ax - ux, ay - uy)


def swept(centre, first, last):
    """How far an arc turns, in degrees."""

    start = math.atan2(first[1] - centre[1], first[0] - centre[0])
    end = math.atan2(last[1] - centre[1], last[0] - centre[0])

    return abs(math.degrees((end - start + math.pi) % (2 * math.pi) - math.pi))


def unique_points(ring):

    points = list(ring)

    if len(points) > 1 and points[0] == points[-1]:
        points.pop()

    return points


def find_arcs(ring, span):
    """Arc runs recovered from one flattened contour."""

    points = unique_points(ring)

    count = len(points)

    if count < 5:
        return []

    limit = span * MAX_ARC_RATIO

    runs = []

    current = None

    for index in range(count):

        trio = (
            points[(index - 1) % count],
            points[index],
            points[(index + 1) % count]
        )

        found = circle_through(*trio)

        if found is None or found[1] > limit:
            current = None
            continue

        centre, radius = found

        if current is not None:

            near = math.hypot(
                centre[0] - current["centre"][0],
                centre[1] - current["centre"][1]
            ) <= radius * ARC_TOLERANCE * 2.0

            same = abs(radius - current["radius"]) <= (
                max(radius, current["radius"]) * ARC_TOLERANCE
            )

            if near and same:

                current["points"].append(trio[2])
                current["indices"].append(index)
                current["radius"] = (
                    current["radius"] * current["count"] + radius
                ) / (current["count"] + 1)
                current["count"] += 1

                continue

        current = {
            "centre": centre,
            "radius": radius,
            "count": 1,
            "points": list(trio),
            "indices": [(index - 1) % count, index, (index + 1) % count]
        }

        runs.append(current)

    arcs = []

    for run in runs:

        if run["count"] < 2:
            continue

        turn = swept(run["centre"], run["points"][0], run["points"][-1])

        if turn < MIN_ARC_SWEEP:
            continue

        middle = run["points"][len(run["points"]) // 2]

        arcs.append({
            "radius": run["radius"],
            "centre": run["centre"],
            "point": middle,
            "sweep": turn,
            "covers": set(run["indices"])
        })

    return arcs

def collect_arcs(contours, bbox):
    """One radius per distinct size, on the arc that shows it best.

    A hole is already called out by its diameter, so its own
    circle is left alone; everything else that curves is fair
    game, which is what the reference drawings mark.
    """

    min_x, min_y, max_x, max_y = bbox

    span = max(max_x - min_x, max_y - min_y)

    found = []

    for contour in contours:

        if contour.get("is_hole") or len(contour["points"]) < 5:
            continue

        found.extend(find_arcs(contour["points"], span))

    best = {}

    for arc in found:

        key = None

        for radius in best:

            if abs(radius - arc["radius"]) <= max(
                radius, arc["radius"]
            ) * RADIUS_TOLERANCE:
                key = radius
                break

        if key is None:
            best[arc["radius"]] = arc
            continue

        # The one that turns furthest is the one worth pointing at.
        if arc["sweep"] > best[key]["sweep"]:
            best[key] = arc

    arcs = sorted(best.values(), key=lambda a: -a["sweep"])

    return arcs[:MAX_RADII]


def fitted_line(points):
    """Direction and a point on it, least squares through a run."""

    count = len(points)

    mean_x = sum(p[0] for p in points) / count
    mean_y = sum(p[1] for p in points) / count

    sxx = sum((p[0] - mean_x) ** 2 for p in points)
    syy = sum((p[1] - mean_y) ** 2 for p in points)
    sxy = sum((p[0] - mean_x) * (p[1] - mean_y) for p in points)

    # The principal direction of the run, which is exact for a
    # straight edge however its ends were cut.
    angle = 0.5 * math.atan2(2.0 * sxy, sxx - syy)

    return (mean_x, mean_y), (math.cos(angle), math.sin(angle))


def outline_runs(ring, minimum, span, tolerance=1.5):
    """The straight runs of a contour, with the arcs taken out.

    A fillet is a curve, and a run that swallows half of one
    points a few degrees away from the edge it belongs to. The
    arcs are already found, so they are cut out first and what is
    left is split again wherever the outline turns.
    """

    points = unique_points(ring)

    count = len(points)

    if count < 3:
        return []

    curved = set()

    for arc in find_arcs(ring, span):
        curved |= arc["covers"]

    runs = []

    current = []

    heading = None

    def close():

        if len(current) >= 2:
            runs.append(list(current))

    for step in range(count):

        here = step % count
        ahead = (step + 1) % count

        if here in curved or ahead in curved:

            close()

            current = []
            heading = None

            continue

        dx = points[ahead][0] - points[here][0]
        dy = points[ahead][1] - points[here][1]

        length = math.hypot(dx, dy)

        if length < 1e-9:
            continue

        angle = math.degrees(math.atan2(dy, dx))

        if heading is None:

            current = [points[here], points[ahead]]
            heading = angle

            continue

        turn = abs((angle - heading + 180.0) % 360.0 - 180.0)

        if turn <= tolerance:

            current.append(points[ahead])

            continue

        close()

        current = [points[here], points[ahead]]
        heading = angle

    close()

    kept = []

    for run in runs:

        length = math.hypot(
            run[-1][0] - run[0][0],
            run[-1][1] - run[0][1]
        )

        if length < minimum:
            continue

        origin, direction = fitted_line(run)

        kept.append({
            "start": run[0],
            "end": run[-1],
            "origin": origin,
            "direction": direction,
            "length": length
        })

    return kept


def crossing(first, second):
    """Where two run centre lines meet, which is the true corner."""

    (x1, y1), (dx1, dy1) = first["origin"], first["direction"]
    (x2, y2), (dx2, dy2) = second["origin"], second["direction"]

    turn = dx1 * dy2 - dy1 * dx2

    if abs(turn) < 1e-9:
        return None

    step = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / turn

    return (x1 + dx1 * step, y1 + dy1 * step)


def corner_angles(contours, bbox):
    """Angles between the long straight runs of the outline.

    Square and straight corners are left out: the overall
    dimensions already say those, and a drawing that marks them
    is a drawing nobody reads.
    """

    min_x, min_y, max_x, max_y = bbox

    span = max(max_x - min_x, max_y - min_y)

    minimum = span * MIN_RUN_RATIO

    found = []

    for contour in contours:

        if contour.get("is_hole") or not contour["closed"]:
            continue

        runs = outline_runs(contour["points"], minimum, span)

        for index in range(len(runs)):

            first = runs[index]
            second = runs[(index + 1) % len(runs)]

            # Runs that do not meet are two different corners.
            gap = math.hypot(
                second["start"][0] - first["end"][0],
                second["start"][1] - first["end"][1]
            )

            if gap > minimum:
                continue

            # A rounded corner is dimensioned to where the two
            # edges would have met, not to the fillet.
            vertex = crossing(first, second) or first["end"]

            back = (first["start"][0] - vertex[0], first["start"][1] - vertex[1])
            ahead = (second["end"][0] - vertex[0], second["end"][1] - vertex[1])

            length_back = math.hypot(*back)
            length_ahead = math.hypot(*ahead)

            if length_back < 1e-9 or length_ahead < 1e-9:
                continue

            cosine = (
                back[0] * ahead[0] + back[1] * ahead[1]
            ) / (length_back * length_ahead)

            angle = math.degrees(math.acos(max(-1.0, min(1.0, cosine))))

            if abs(angle - 90.0) <= SQUARE_TOLERANCE:
                continue

            if angle >= 180.0 - SQUARE_TOLERANCE or angle <= 8.0:
                continue

            found.append({
                "vertex": vertex,
                "back": first["start"],
                "ahead": second["end"],
                "angle": angle,
                "weight": min(first["length"], second["length"])
            })

    found.sort(key=lambda item: -item["weight"])

    # The same angle marked at four corners of a symmetric part
    # is three labels nobody needed.
    kept = []

    for corner in found:

        if any(
            abs(corner["angle"] - other["angle"]) < 0.5
            for other in kept
        ):
            continue

        kept.append(corner)

    return kept[:MAX_ANGLES]

def off_the_part(contours):
    """A test for whether a point is clear of the part altogether."""

    outer = [
        contour["points"]
        for contour in contours
        if contour["closed"] and not contour["inner"]
    ]

    def free(point):

        return not any(point_in_polygon(point, ring) for ring in outer)

    return free


def escape(free, point, direction, reach, span):
    """How far along a direction a label has to go to leave the part."""

    step = max(reach * 0.4, span * 0.02)

    distance = reach

    limit = span * 0.6

    while distance < limit:

        if free((
            point[0] + direction[0] * distance,
            point[1] + direction[1] * distance
        )):
            return distance

        distance += step

    return limit


def draw_radii(page, fit, arcs, contours):
    """R values on short leaders, pointing at the arcs they belong to."""

    if not arcs:
        return

    pen = ImageDraw.Draw(page)

    label_font = dw.font(CHAIN_SIZE - 2, "drawing")

    free = off_the_part(contours)

    reach = (RADIUS_STAND_OFF + RADIUS_LEADER) / max(fit.scale, 1e-9)

    span = max(
        fit.width,
        fit.height
    )

    placed = []

    for arc in arcs:

        x, y = fit(arc["point"])

        # Out along the radius, which leaves the material on a
        # rounded corner and enters the gap on a fillet; if that
        # end lands in metal after all, the other one is taken.
        away = (
            arc["point"][0] - arc["centre"][0],
            arc["point"][1] - arc["centre"][1]
        )

        length = math.hypot(*away)

        if length < 1e-9:
            away = (1.0, 0.0)
            length = 1.0

        away = (away[0] / length, away[1] / length)

        # The leader runs out along the radius until it is off the
        # part, whichever way that is nearer: a fillet inside the
        # outline would otherwise hang its value over the very
        # features it points at.
        forward = escape(free, arc["point"], away, reach, span)

        backward = escape(
            free,
            arc["point"],
            (-away[0], -away[1]),
            reach,
            span
        )

        if backward < forward:
            away = (-away[0], -away[1])
            distance = backward
        else:
            distance = forward

        # Screen Y runs the other way to drawing Y.
        step = (away[0], -away[1])

        out = distance * fit.scale

        text = "R" + dw.format_number(arc["radius"])

        width = dw.text_width(text, label_font)

        # A label that would land on one already placed pushes its
        # own leader further out instead.
        for _ in range(5):

            elbow = (x + step[0] * out, y + step[1] * out)

            box = (
                min(elbow[0], elbow[0] + step[0] * (width + 12)) - 6,
                elbow[1] - 17,
                max(elbow[0], elbow[0] + step[0] * (width + 12)) + 6,
                elbow[1] + 17
            )

            if not any(
                box[0] < other[2] and other[0] < box[2]
                and box[1] < other[3] and other[1] < box[3]
                for other in placed
            ):
                break

            out += 42

        placed.append(box)

        start = (
            x + step[0] * min(RADIUS_STAND_OFF, out * 0.3),
            y + step[1] * min(RADIUS_STAND_OFF, out * 0.3)
        )

        pen.line([start, elbow], fill=LEADER_COLOR, width=1)

        # An arrowhead back at the arc, as on a real drawing.
        dw._arrow(
            pen,
            (x + step[0] * 3.0, y + step[1] * 3.0),
            step,
            LEADER_COLOR
        )

        shelf = 8.0 + width

        if step[0] >= 0.0:
            shelf_end = (elbow[0] + shelf, elbow[1])
            text_x = elbow[0] + 4.0
            anchor = "ls"
        else:
            shelf_end = (elbow[0] - shelf, elbow[1])
            text_x = elbow[0] - 4.0
            anchor = "rs"

        pen.line([elbow, shelf_end], fill=LEADER_COLOR, width=1)

        pen.text(
            (text_x, elbow[1] - 5),
            text,
            font=label_font,
            fill=LEADER_COLOR,
            anchor=anchor,
            stroke_width=3,
            stroke_fill=(255, 255, 255)
        )


def draw_corners(page, fit, angles):
    """The angle at every corner that is neither square nor straight."""

    for corner in angles:

        vertex = fit(corner["vertex"])

        back = fit(corner["back"])
        ahead = fit(corner["ahead"])

        reach = min(
            math.hypot(back[0] - vertex[0], back[1] - vertex[1]),
            math.hypot(ahead[0] - vertex[0], ahead[1] - vertex[1])
        )

        dw.angle_marker(
            page,
            vertex,
            back,
            ahead,
            dw.format_number(corner["angle"]) + "°",
            radius=max(26.0, min(52.0, reach * 0.55)),
            size=20,
            halo=(255, 255, 255)
        )


# ============================================================
# CALLOUTS
# ============================================================

def stacked(wanted, gap, low, high):
    """Label heights, pushed apart just enough not to collide."""

    if not wanted:
        return []

    order = sorted(range(len(wanted)), key=lambda i: wanted[i])

    heights = [wanted[i] for i in order]

    for i in range(1, len(heights)):
        heights[i] = max(heights[i], heights[i - 1] + gap)

    overflow = heights[-1] - high

    if overflow > 0:

        heights = [height - overflow for height in heights]

        for i in range(len(heights) - 2, -1, -1):
            heights[i] = min(heights[i], heights[i + 1] - gap)

    if heights[0] < low:

        shift = low - heights[0]

        heights = [height + shift for height in heights]

    placed = [0.0] * len(wanted)

    for slot, index in enumerate(order):
        placed[index] = heights[slot]

    return placed


def callout_text(hole, count):

    text = "Ø" + dw.format_number(hole["diameter_mm"])

    if count > 1:
        text = "{}×{}".format(count, text)

    return text


def callout_list(holes, grouped=False):
    """One callout per hole, or one per diameter when there are many.

    Twenty leaders reaching across a plate is a thicket, and the
    fifth "Ø3" tells nobody anything the first one did not. The
    page can also ask for the short list outright, when a part is
    too flat to stand that many labels beside it.
    """

    if not grouped and len(holes) <= MAX_CALLOUTS:
        return [(hole, 1, None) for hole in holes]

    groups = {}

    for hole in holes:

        key = round(hole["diameter_mm"], 2)

        groups.setdefault(key, []).append(hole)

    listed = []

    for key in sorted(groups):

        same = groups[key]

        # One label out to each margin, taken from the hole
        # nearest that margin: the leader is then the short one,
        # and two labels of the same diameter never queue up on
        # the same side arguing about which hole they mean.
        listed.append((min(same, key=lambda h: h["center"][0]), len(same), -1))

        if len(same) > 1:
            listed.append((max(same, key=lambda h: h["center"][0]), len(same), 1))

    return listed


def label_side(hole, side, middle):

    if side is not None:
        return side

    return -1 if hole["center"][0] <= middle else 1


def label_room(listed, bbox):
    """Height the labels want, which is not the height of the part.

    A long flat bar carrying fourteen callouts needs more page
    than the bar does, and finding that out after the panels were
    cut is how labels end up in the view below.
    """

    middle = (bbox[0] + bbox[2]) / 2.0

    counts = {-1: 0, 1: 0}

    for hole, _, side in listed:
        counts[label_side(hole, side, middle)] += 1

    return max(counts.values()) * callout_step(listed) + 48


def callout_plan(holes, bbox, room, extras=()):
    """The callouts, grouped if the page cannot hold them all."""

    if not holes and not extras:
        return [], 0.0

    listed = callout_list(holes) + [
        (entry, entry["count"], None) for entry in extras
    ]

    needed = label_room(listed, bbox)

    if needed <= room:
        return listed, needed

    listed = callout_list(holes, grouped=True) + [
        (entry, entry["count"], None) for entry in extras
    ]

    needed = label_room(listed, bbox)

    if needed <= room:
        return listed, needed

    # Still more labels than page. The ones that count for most
    # stay; the rest are in the schedule under the drawing, which
    # is where somebody counting them would look anyway.
    listed = trim_callouts(listed, bbox, room)

    return listed, label_room(listed, bbox)


def trim_callouts(listed, bbox, room):
    """Keeps as many callouts as the view has height for."""

    middle = (bbox[0] + bbox[2]) / 2.0

    per_side = max(1, int((room - 48) // callout_step(listed)))

    kept = {-1: [], 1: []}

    for entry in sorted(listed, key=lambda item: -item[1]):

        side = label_side(entry[0], entry[2], middle)

        if len(kept[side]) < per_side:
            kept[side].append(entry)

    return kept[-1] + kept[1]


def callout_step(listed):
    """Two lines of label want more room between them than one."""

    if any(count > 1 for _, count, _ in listed):
        return CALLOUT_STEP + 26

    return CALLOUT_STEP


def draw_callouts(page, listed, fit, box, language):
    """Diameter labels on leaders that reach out to the margin.

    Shaped the way the shop shapes them: the leader ends in a
    shelf, the diameter sits on the shelf and how many holes it
    is sits under it.
    """

    if not listed:
        return

    middle = (fit.rect[0] + fit.rect[2]) / 2.0

    sides = {-1: [], 1: []}

    for hole, count, side in listed:

        x, y = fit(hole["center"])

        if side is None:
            side = -1 if x <= middle else 1

        sides[side].append((hole, count, x, y))

    pen = ImageDraw.Draw(page)

    label_font = dw.font(CALLOUT_SIZE, "drawing")
    count_font = dw.font(CALLOUT_SIZE - 3, "drawing")

    step = callout_step(listed)

    for side, items in sides.items():

        if not items:
            continue

        heights = stacked(
            [item[3] for item in items],
            step,
            box[1] + 24,
            box[3] - 24
        )

        for (hole, count, x, y), label_y in zip(items, heights):

            text = hole.get("text") or (
                "Ø" + dw.format_number(hole["diameter_mm"])
            )

            unit = hole.get("unit", "callout_count")

            counted = (
                t(language, unit, count=count)
                if count > 1 or hole.get("unit")
                else None
            )

            width = 10 + max(
                dw.text_width(text, label_font),
                dw.text_width(counted, count_font) if counted else 0
            )

            if side < 0:
                shelf_start = box[0] + 8
                shelf_end = shelf_start + width
                text_x = shelf_start + 4
                anchor = "l"
            else:
                shelf_end = box[2] - 8
                shelf_start = shelf_end - width
                text_x = shelf_end - 4
                anchor = "r"

            pen.line(
                [(shelf_start, label_y), (shelf_end, label_y)],
                fill=LEADER_COLOR,
                width=1
            )

            pen.text(
                (text_x, label_y - 5),
                text,
                font=label_font,
                fill=LEADER_COLOR,
                anchor=anchor + "s"
            )

            if counted:

                pen.text(
                    (text_x, label_y + 5),
                    counted,
                    font=count_font,
                    fill=LEADER_COLOR,
                    anchor=anchor + "t"
                )

            radius = hole["diameter_mm"] / 2.0 * fit.scale

            reach = max(abs(label_y - y), 14.0)

            elbow_x = x + side * (radius + reach)

            corner = shelf_end if side < 0 else shelf_start

            # The elbow belongs between the shelf and the hole,
            # whatever the two ended up at.
            if side < 0:
                elbow_x = max(elbow_x, corner + 8)
                elbow_x = min(elbow_x, x - radius - 6)
            else:
                elbow_x = min(elbow_x, corner - 8)
                elbow_x = max(elbow_x, x + radius + 6)

            span_x = elbow_x - x
            span_y = label_y - y

            length = math.hypot(span_x, span_y)

            if length < 1e-6:
                continue

            # A leader points at the centre of its own hole, so it
            # reads as that hole and no other.
            start = (
                x + span_x / length * max(radius, 3.0),
                y + span_y / length * max(radius, 3.0)
            )

            pen.line(
                [start, (elbow_x, label_y), (corner, label_y)],
                fill=LEADER_COLOR,
                width=1
            )


# ============================================================
# DIMENSION CHAINS
# ============================================================

def chain_values(centres, low, high, tolerance):
    """Distinct hole columns (or rows), datum edges left out."""

    values = [
        value
        for value in cluster(centres, tolerance)
        if value - low > tolerance * 4 and high - value > tolerance * 4
    ]

    return values if len(values) <= MAX_CHAIN else []


def draw_guides(page, fit, bbox, holes, columns, rows, tolerance):
    """Centre lines out of the holes, so a chain attaches to one.

    A dimension whose extension line starts at the edge of the
    part measures a column of holes without touching one, and the
    eye has to guess which. These are the lines a draughtsman
    draws through the centres and out past the material.
    """

    pen = ImageDraw.Draw(page)

    min_x, min_y, max_x, max_y = bbox

    reach = tolerance * 2.0

    for value in columns:

        near = [
            hole
            for hole in holes
            if abs(hole["center"][0] - value) <= reach
        ]

        if not near:
            continue

        pen.line(
            [
                fit((value, min(hole["center"][1] for hole in near))),
                fit((value, min_y))
            ],
            fill=THIN_COLOR,
            width=1
        )

        # The chain hole to hole runs along the far side, so the
        # centre line has to reach that edge as well.
        if len(columns) > 1:

            pen.line(
                [
                    fit((value, max(hole["center"][1] for hole in near))),
                    fit((value, max_y))
                ],
                fill=THIN_COLOR,
                width=1
            )

    for value in rows:

        near = [
            hole
            for hole in holes
            if abs(hole["center"][1] - value) <= reach
        ]

        if not near:
            continue

        pen.line(
            [
                fit((min(hole["center"][0] for hole in near), value)),
                fit((min_x, value))
            ],
            fill=THIN_COLOR,
            width=1
        )

        if len(rows) > 1:

            pen.line(
                [
                    fit((max(hole["center"][0] for hole in near), value)),
                    fit((max_x, value))
                ],
                fill=THIN_COLOR,
                width=1
            )


def gaps(values):

    return list(zip(values, values[1:]))


def pitch_runs(values, tolerance):
    """Hole-to-hole steps, with equal ones in a row merged.

    Four holes at eight millimetre centres are one dimension that
    says 3x8, not three dimensions that say 8 and cannot all fit
    between the holes they measure anyway.
    """

    runs = []

    for first, second in gaps(values):

        step = second - first

        if runs and abs(step - runs[-1]["step"]) <= tolerance:

            runs[-1]["end"] = second
            runs[-1]["count"] += 1

            continue

        runs.append({
            "start": first,
            "end": second,
            "step": step,
            "count": 1
        })

    return runs


def pitch_text(run):

    step = dw.format_number(run["step"])

    return step if run["count"] == 1 else "{}×{}".format(run["count"], step)


def merge_unreadable(runs, scale):
    """Steps too small to label here are gathered into one.

    A pattern of two millimetre steps cannot be dimensioned at
    the scale of the whole part however the labels are stacked:
    they are drawn over each other whatever happens. So the run
    of them becomes one dimension carrying the distance across
    the lot, and the enlarged view says what is inside it.
    """

    limit = dw.SHORT_DIMENSION * 0.9

    merged = []

    pending = None

    for run in runs:

        if (run["end"] - run["start"]) * scale < limit:

            if pending is None:
                pending = dict(run)
                pending["count"] = 1
            else:
                pending["end"] = run["end"]

            pending["step"] = pending["end"] - pending["start"]

            continue

        if pending is not None:
            merged.append(pending)
            pending = None

        merged.append(run)

    if pending is not None:
        merged.append(pending)

    return merged


def pitch_levels(runs, scale):
    """Which line each step goes on.

    Every value sits over the middle of the step it measures. One
    whose step is shorter than the value is wide would then run
    into its neighbours, so those take turns on a second and a
    third line, where each has the room to itself.
    """

    label_font = dw.font(CHAIN_SIZE, "drawing")

    levels = []

    crowded = 0

    for run in runs:

        span = (run["end"] - run["start"]) * scale

        if span < dw.text_width(pitch_text(run), label_font) + 14:

            crowded += 1

            # Three lines to take turns on, not two: a pattern of
            # short steps in a row fills two of them and starts
            # writing over itself.
            levels.append(1 + (crowded - 1) % 3)

        else:

            crowded = 0

            levels.append(0)

    return levels


def pitch_lines(runs, scale):
    """How many lines the hole-to-hole chain needs, 0 for none."""

    levels = pitch_levels(runs, scale)

    return 1 + max(levels) if levels else 0


def draw_chains(page, fit, bbox, columns, rows, runs):
    """Every hole column and row measured off one datum corner."""

    min_x, min_y, max_x, max_y = bbox

    corner = (min_x, min_y)

    row_runs, column_runs = runs

    # The datum side sets the pattern on the machine and the far
    # side steps through it. Once the far side carries the steps,
    # one dimension from the datum to the first hole is all the
    # near side has to add: a line for every hole would say the
    # same thing again and cost a line of page each time.
    level = 0

    for value in (columns[:1] if column_runs else columns):

        dw.dimension(
            page,
            fit(corner),
            fit((value, min_y)),
            dw.format_number(value - min_x),
            (0.0, 1.0),
            offset=CHAIN_OFFSET + level * CHAIN_STEP
        )

        level += 1

    dw.dimension(
        page,
        fit(corner),
        fit((max_x, min_y)),
        dw.format_number(max_x - min_x),
        (0.0, 1.0),
        offset=CHAIN_OFFSET + level * CHAIN_STEP
    )

    level = 0

    for value in (rows[:1] if row_runs else rows):

        dw.dimension(
            page,
            fit(corner),
            fit((min_x, value)),
            dw.format_number(value - min_y),
            (-1.0, 0.0),
            offset=CHAIN_OFFSET + level * CHAIN_STEP
        )

        level += 1

    dw.dimension(
        page,
        fit(corner),
        fit((min_x, max_y)),
        dw.format_number(max_y - min_y),
        (-1.0, 0.0),
        offset=CHAIN_OFFSET + level * CHAIN_STEP
    )

    draw_pitch(page, fit, bbox, runs)


def draw_pitch(page, fit, bbox, runs):
    """The distances between the holes themselves.

    Every value on the datum side is measured from the same edge,
    which is what a machine is set from; a shop checking a
    pattern wants the step from one hole to the next, and a
    symmetric pattern says so by repeating its numbers.
    """

    min_x, min_y, max_x, max_y = bbox

    row_runs, column_runs = runs

    for run, line in zip(row_runs, pitch_levels(row_runs, fit.scale)):

        dw.dimension(
            page,
            fit((max_x, run["start"])),
            fit((max_x, run["end"])),
            pitch_text(run),
            (1.0, 0.0),
            offset=CHAIN_OFFSET + line * CHAIN_STEP,
            beside=True
        )

    for run, line in zip(column_runs, pitch_levels(column_runs, fit.scale)):

        dw.dimension(
            page,
            fit((run["start"], max_y)),
            fit((run["end"], max_y)),
            pitch_text(run),
            (0.0, -1.0),
            offset=CHAIN_OFFSET + line * CHAIN_STEP,
            beside=True
        )


# ============================================================
# A NEST IS SEVERAL PARTS
#
# One DXF often holds a whole sheet of them. The cut map draws
# that sheet as it will be cut; this takes it apart again, so
# every part on it can have the drawing it would have had if it
# had arrived on its own.
# ============================================================

# Past this many the set is a catalogue, not a drawing job.
MAX_PART_SHEETS = 12

# Two parts are the same part when these agree.
SIGNATURE_TOLERANCE = 0.02


def inside_contour(point, contour):

    return point_in_polygon(point, contour["points"])


def split_parts(data, holes):
    """One dataset per outer contour, with what belongs to it.

    Returns None when the file holds a single part, which is the
    ordinary case and needs none of this.
    """

    contours = data["contours"]

    outer = [
        contour for contour in contours
        if contour["closed"] and not contour["inner"]
    ]

    if len(outer) < 2:
        return None

    inner = [
        contour for contour in contours
        if contour["closed"] and contour["inner"]
    ]

    loose = [contour for contour in contours if not contour["closed"]]

    parts = []

    for shell in outer:

        own = [
            contour for contour in inner
            if inside_contour(contour["points"][0], shell)
        ]

        marks = [
            contour for contour in loose
            if inside_contour(contour["points"][0], shell)
        ]

        xs = [x for x, _ in shell["points"]]
        ys = [y for _, y in shell["points"]]

        bbox = (min(xs), min(ys), max(xs), max(ys))

        own_holes = [
            hole for hole in holes
            if inside_contour(hole["center"], shell)
        ]

        parts.append({
            "data": {
                "contours": [shell] + own + marks,
                "bbox": bbox,
                "units": data.get("units"),
                "scale": data.get("scale", 1.0)
            },
            "holes": own_holes,
            "area": polygon_area(shell["points"]),
            "size": (max(xs) - min(xs), max(ys) - min(ys))
        })

    return parts


def part_signature(part):
    """What makes two parts on a sheet the same part."""

    width, height = part["size"]

    def rounded(value):
        return round(value / max(SIGNATURE_TOLERANCE, 1e-9))

    holes = sorted(
        rounded(hole["diameter_mm"]) for hole in part["holes"]
    )

    return (
        rounded(min(width, height)),
        rounded(max(width, height)),
        rounded(part["area"]),
        len(part["data"]["contours"]),
        tuple(holes)
    )


def unique_parts(parts):
    """The distinct parts of a nest, biggest first, with counts."""

    seen = {}

    for part in parts:

        key = part_signature(part)

        if key in seen:
            seen[key]["count"] += 1
            continue

        part["count"] = 1

        seen[key] = part

    found = list(seen.values())

    found.sort(key=lambda part: -part["area"])

    return found


# ============================================================
# OPTIONS
#
# Not every shop wants every mark on its first drawing, so the
# chat says what to put on this one. The flags travel as a short
# string because a Telegram button carries 64 bytes and no more.
# ============================================================

def read_options(flags):
    """Turns the flag string from the chat into what to draw."""

    flags = flags or ""

    return {
        # Radii and corner angles: measured either way, drawn on
        # request.
        "shape": "r" in flags,

        # Enlarged details: none, the crowded corners, or every
        # corner worth one.
        "details": 4 if "D" in flags else (MAX_DETAILS if "d" in flags else 0),

        # The page furniture: ours, or the standard one with the
        # stamp for a customer who insists on it.
        "standard": "e" in flags,

        # A nest drawn as it will be cut, or taken apart into a
        # drawing for every part on it.
        "parts": "p" in flags
    }


# ============================================================
# SLOTS
#
# A round hole is called out by its diameter and a shop knows
# what to do with it. Everything else that was cut out of the
# middle of the plate had no number at all on the sheet until
# now, and a slot is the commonest of them.
# ============================================================

# How much longer than wide before an opening is a slot.
SLOT_RATIO = 1.25

MAX_SLOT_RATIO = 30.0

# The rest of them are in the schedule table.
MAX_SLOT_CALLOUTS = 4

# A slot fills its own rectangle; a triangle or a kidney does not.
SLOT_FILL = 0.72


def bounding_rectangle(points):
    """The smallest rectangle around a contour: width, length."""

    best = None

    for step in range(90):

        spun = turned(points, math.radians(step))

        xs = [p[0] for p in spun]
        ys = [p[1] for p in spun]

        width = max(xs) - min(xs)
        height = max(ys) - min(ys)

        area = width * height

        if best is None or area < best[0]:
            best = (area, min(width, height), max(width, height))

    return best[1], best[2]


def find_slots(contours):
    """Openings that are a slot rather than a hole or a cut-out."""

    slots = []

    for contour in contours:

        if not contour["closed"] or not contour["inner"]:
            continue

        if contour.get("is_hole"):
            continue

        points = unique_points(contour["points"])

        if len(points) < 4:
            continue

        width, length = bounding_rectangle(points)

        if width < 1e-6:
            continue

        ratio = length / width

        if ratio < SLOT_RATIO or ratio > MAX_SLOT_RATIO:
            continue

        if polygon_area(contour["points"]) < width * length * SLOT_FILL:
            continue

        slots.append({
            "centre": centroid(points),
            "width": width,
            "length": length
        })

    return slots


def slot_callouts(slots, tolerance, language):
    """One callout per size of slot, with how many there are."""

    groups = {}

    for slot in slots:

        key = (
            round(slot["width"] / max(tolerance, 0.05)),
            round(slot["length"] / max(tolerance, 0.05))
        )

        groups.setdefault(key, []).append(slot)

    entries = []

    for group in groups.values():

        width = sum(slot["width"] for slot in group) / len(group)
        length = sum(slot["length"] for slot in group) / len(group)

        entries.append({
            "center": list(
                min(group, key=lambda slot: slot["centre"][0])["centre"]
            ),
            "diameter_mm": width,
            "text": "{}×{}".format(
                dw.format_number(width),
                dw.format_number(length)
            ),
            "count": len(group),
            "unit": "callout_slots"
        })

    entries.sort(key=lambda entry: -entry["count"] * entry["diameter_mm"])

    return entries[:MAX_SLOT_CALLOUTS]


# ============================================================
# DETAIL VIEWS
#
# The reference drawings all do the same thing with a part that
# is long and finely detailed: the main view carries the overall
# sizes, and the ends where the small holes and the little
# fillets live are drawn again, enlarged, with their own
# dimensions. Anything below about a millimetre and a half on
# paper is not a feature, it is a smudge.
# ============================================================

# A hole narrower than this on the sheet cannot be read.
LEGIBLE_HOLE = 9.0

# Nor can a fillet smaller than this.
LEGIBLE_ARC = 5.0

# Features closer together than this share one detail view.
DETAIL_LINK = 0.085

# A detail bigger than this share of the part is not a
# detail: it is the part again, and enlarging it buys
# nothing.
MAX_DETAIL_SHARE = 0.14

MAX_DETAILS = 2

# What a detail is worth drawing at, relative to the main view.
DETAIL_FACTORS = (2.0, 2.5, 4.0, 5.0, 10.0)

DETAIL_MARGIN = 1.6

MIN_DETAIL_FEATURES = 4

DETAIL_LETTERS = "АБВГ"


def crowded_features(holes, arcs, scale):
    """Where the drawing is too small to read at this scale."""

    points = []

    for hole in holes:

        if hole.get("diameter_mm", 0.0) * scale < LEGIBLE_HOLE:
            points.append(tuple(hole["center"]))

    for arc in arcs:

        if arc["radius"] * scale < LEGIBLE_ARC:
            points.append(tuple(arc["point"]))

    return points


def dense_regions(points, reach, limit, minimum=MIN_DETAIL_FEATURES):
    """The tightest knots of features, taken one at a time.

    Linking everything that is near something else chains half a
    plate into one blob, so the densest point wins a circle of
    its own, its neighbours go with it, and whatever is left over
    gets the next one.
    """

    remaining = list(points)

    found = []

    while remaining and len(found) < limit:

        def neighbours(point):

            return [
                other for other in remaining
                if math.hypot(
                    point[0] - other[0],
                    point[1] - other[1]
                ) <= reach
            ]

        seed = max(remaining, key=lambda point: len(neighbours(point)))

        group = neighbours(seed)

        if len(group) < minimum:
            break

        found.append(group)

        remaining = [point for point in remaining if point not in group]

    return found


def detail_regions(holes, arcs, bbox, scale, limit=MAX_DETAILS):

    # Asked for every corner, the bar for what counts as one
    # comes down a little.
    minimum = MIN_DETAIL_FEATURES if limit <= MAX_DETAILS else 3
    """The circles worth drawing again, larger."""

    min_x, min_y, max_x, max_y = bbox

    span = max(max_x - min_x, max_y - min_y)

    points = crowded_features(holes, arcs, scale)

    if len(points) < minimum:
        return []

    regions = []

    for group in dense_regions(points, span * DETAIL_LINK, limit, minimum):

        centre = (
            sum(p[0] for p in group) / len(group),
            sum(p[1] for p in group) / len(group)
        )

        radius = max(
            math.hypot(p[0] - centre[0], p[1] - centre[1])
            for p in group
        )

        reach = max(radius * DETAIL_MARGIN, span * 0.03)

        if reach > span * MAX_DETAIL_SHARE:
            continue

        regions.append({
            "centre": centre,
            "radius": reach,
            "count": len(group)
        })

    regions.sort(key=lambda region: -region["count"])

    return regions[:limit]


def detail_factor(region, rect, scale):
    """How much bigger the detail is drawn than the main view."""

    room = min(rect[2] - rect[0], rect[3] - rect[1]) - 2 * DETAIL_INSET

    wanted = room / (2.0 * region["radius"] * max(scale, 1e-9))

    best = DETAIL_FACTORS[0]

    for factor in DETAIL_FACTORS:

        if factor <= wanted + 1e-9:
            best = factor

    return best


def inside_region(point, region):

    return math.hypot(
        point[0] - region["centre"][0],
        point[1] - region["centre"][1]
    ) <= region["radius"]

DETAIL_INSET = 120


def mark_detail(page, fit, region, letter):
    """The circle on the main view, and the letter beside it."""

    x, y = fit(region["centre"])

    radius = region["radius"] * fit.scale

    pen = ImageDraw.Draw(page)

    pen.ellipse(
        (x - radius, y - radius, x + radius, y + radius),
        outline=LEADER_COLOR,
        width=1
    )

    # Up and to the right of the circle, on a leader that touches
    # it, which is where a draughtsman puts the letter.
    step = 0.7071

    pen.line(
        [
            (x + radius * step, y - radius * step),
            (x + (radius + 26) * step, y - (radius + 26) * step)
        ],
        fill=LEADER_COLOR,
        width=1
    )

    pen.text(
        (x + (radius + 30) * step, y - (radius + 30) * step),
        letter,
        font=dw.font(CHAIN_SIZE + 2, "drawing"),
        fill=LEADER_COLOR,
        anchor="ls",
        stroke_width=3,
        stroke_fill=(255, 255, 255)
    )


def draw_detail(page, rect, region, factor, scale, data, holes, arcs,
                angles, slots, language, letter, tolerance):
    """One enlarged view of a region, clipped to its own circle."""

    centre = region["centre"]

    radius = region["radius"]

    bbox = (
        centre[0] - radius,
        centre[1] - radius,
        centre[0] + radius,
        centre[1] + radius
    )

    # Drawn at exactly the factor its caption claims, which is
    # what the caption is for.
    fit = Fit(bbox, rect, (DETAIL_INSET,) * 4, scale=factor * scale)

    canvas = Image.new(
        "RGBA",
        (
            dw.PAGE_WIDTH * dw.SUPERSAMPLE,
            dw.PAGE_HEIGHT * dw.SUPERSAMPLE
        ),
        (0, 0, 0, 0)
    )

    draw_contours(
        canvas,
        data["contours"],
        fit.enlarged(dw.SUPERSAMPLE),
        weight=dw.SUPERSAMPLE
    )

    middle = fit(centre)

    reach = radius * fit.scale

    # Clipped to the circle it was taken from, so the detail
    # cannot spill over the rest of the sheet.
    mask = Image.new("L", canvas.size, 0)

    ImageDraw.Draw(mask).ellipse(
        (
            (middle[0] - reach) * dw.SUPERSAMPLE,
            (middle[1] - reach) * dw.SUPERSAMPLE,
            (middle[0] + reach) * dw.SUPERSAMPLE,
            (middle[1] + reach) * dw.SUPERSAMPLE
        ),
        fill=255
    )

    canvas.putalpha(
        Image.composite(
            canvas.getchannel("A"),
            Image.new("L", canvas.size, 0),
            mask
        )
    )

    canvas = canvas.resize(
        (dw.PAGE_WIDTH, dw.PAGE_HEIGHT),
        Image.Resampling.LANCZOS
    )

    page.paste(canvas, (0, 0), canvas)

    ImageDraw.Draw(page).ellipse(
        (
            middle[0] - reach,
            middle[1] - reach,
            middle[0] + reach,
            middle[1] + reach
        ),
        outline=THIN_COLOR,
        width=1
    )

    # --------------------------------------------------------
    # What the detail is for
    # --------------------------------------------------------

    near = [
        hole for hole in holes
        if inside_region(hole["center"], region)
    ]

    draw_centre_marks(page, near, fit)

    listed, _ = callout_plan(
        near,
        bbox,
        rect[3] - rect[1],
        [
            slot for slot in slots
            if inside_region(slot["center"], region)
        ]
    )

    # The labels belong beside the detail, not out at the edge of
    # the sheet with half a page of leader behind them.
    clear = reach + CHAIN_OFFSET + 2 * CHAIN_STEP

    box = (
        max(rect[0], middle[0] - clear - CALLOUT_MARGIN),
        max(rect[1], middle[1] - reach - CALLOUT_TOP),
        min(rect[2], middle[0] + clear + CALLOUT_MARGIN),
        min(rect[3], middle[1] + reach + CALLOUT_TOP)
    )

    draw_callouts(page, listed, fit, box, language)

    draw_radii(
        page,
        fit,
        [arc for arc in arcs if inside_region(arc["point"], region)],
        data["contours"]
    )

    draw_corners(
        page,
        fit,
        [
            corner for corner in angles
            if inside_region(corner["vertex"], region)
        ]
    )

    columns = cluster([hole["center"][0] for hole in near], tolerance)

    rows = cluster([hole["center"][1] for hole in near], tolerance)

    draw_pitch(
        page,
        fit,
        bbox,
        (pitch_runs(rows, tolerance), pitch_runs(columns, tolerance))
    )

    dw.panel_caption(
        page,
        rect,
        "{} ({}:1)".format(letter, dw.format_number(factor))
    )


# ============================================================
# EDGE VIEW
#
# The thickness has nowhere else to go, and the holes show in it
# as the gaps they really are.
# ============================================================

def draw_edge_view(page, rect, bbox, holes, thickness, vertical):

    min_x, min_y, max_x, max_y = bbox

    if vertical:
        view_box = (0.0, min_y, thickness, max_y)
        margins = (44, 74, 96, 44)
    else:
        view_box = (min_x, 0.0, max_x, thickness)
        margins = (44, 44, 96, 84)

    fit = Fit(view_box, rect, margins)

    left, top, right, bottom = fit.rect

    pen = ImageDraw.Draw(page)

    pen.rectangle(
        (left, top, right, bottom),
        fill=MATERIAL_COLOR,
        outline=CONTOUR_COLOR,
        width=CONTOUR_WIDTH
    )

    # Where a hole passes through, there is no material to show.
    # Past a certain count they stop being holes and become a
    # hatch pattern, so they are left off.
    for hole in (holes if len(holes) <= MAX_EDGE_TICKS else []):

        centre = hole["center"][1 if vertical else 0]

        radius = hole["diameter_mm"] / 2.0

        for edge in (centre - radius, centre + radius):

            if vertical:

                _, y = fit((0.0, edge))

                pen.line(
                    [(left, y), (right, y)],
                    fill=THIN_COLOR,
                    width=1
                )

            else:

                x, _ = fit((edge, 0.0))

                pen.line(
                    [(x, top), (x, bottom)],
                    fill=THIN_COLOR,
                    width=1
                )

    thickness_text = dw.format_number(thickness)

    if vertical:

        dw.dimension(
            page,
            (left, top),
            (right, top),
            thickness_text,
            (0.0, -1.0),
            offset=34
        )

        dw.dimension(
            page,
            (right, top),
            (right, bottom),
            dw.format_number(max_y - min_y),
            (1.0, 0.0),
            offset=44
        )

    else:

        dw.dimension(
            page,
            (right, top),
            (right, bottom),
            thickness_text,
            (1.0, 0.0),
            offset=34
        )

        dw.dimension(
            page,
            (left, bottom),
            (right, bottom),
            dw.format_number(max_x - min_x),
            (0.0, 1.0),
            offset=44
        )


# ============================================================
# PICTORIAL
#
# A plate is an extrusion, so it needs no tessellation: the
# segments of the outline are the side walls, and the top face is
# the outline with the holes taken out of it. Every edge is
# therefore exact, which a triangulated one would not be.
# ============================================================

def ring_screen(ring, z, camera, viewport, over):

    points = np.array(
        [[x, y, z] for x, y in ring],
        dtype=np.float64
    )

    return viewport.screen_points(points, camera) * over


def wall_edges(pen, walls, projected, inner, over):
    """The lower rim of every wall we can see, and its corners."""

    group_by_ring = {}

    for wall in walls:

        if projected[wall["ring"]][1] != inner:
            continue

        if wall["front"]:
            pen.line(wall["floor"], fill=CONTOUR_COLOR, width=2 * over)

        group_by_ring.setdefault(wall["ring"], []).append(wall)

    # Where a wall turns away from us, the plate shows its corner.
    for index, group in group_by_ring.items():

        _, _, top, bottom, _ = projected[index]

        for position, wall in enumerate(group):

            if wall["front"] == group[position - 1]["front"]:
                continue

            corner = wall["edge"]

            pen.line(
                [tuple(top[corner]), tuple(bottom[corner])],
                fill=CONTOUR_COLOR,
                width=2 * over
            )


def iso_view(rect, contours, thickness):
    """A shaded pictorial of the plate, or None if there is none."""

    width = int(rect[2] - rect[0])
    height = int(rect[3] - rect[1])

    over = dw.SUPERSAMPLE

    camera = dw.ISO_CAMERA

    rings = [
        (closed_ring(contour["points"]), bool(contour["inner"]))
        for contour in contours
        if contour["closed"] and len(contour["points"]) > 2
    ]

    # Outer first: the top face is punched in that order, and a
    # hole drawn before its own plate would be filled straight in.
    rings.sort(key=lambda item: item[1])

    if not rings:
        return None

    cloud = []

    for ring, _ in rings:
        for x, y in ring:
            cloud.append((x, y, 0.0))
            cloud.append((x, y, thickness))

    viewport = dw.Viewport(
        dw.project(np.asarray(cloud), camera),
        (0, 0, width, height),
        margin=ISO_MARGIN
    )

    canvas = Image.new("RGBA", (width * over, height * over), (0, 0, 0, 0))

    pen = ImageDraw.Draw(canvas)

    projected = []

    for ring, inner in rings:

        top = ring_screen(ring, thickness, camera, viewport, over)
        bottom = ring_screen(ring, 0.0, camera, viewport, over)

        depth = dw.project(
            np.array([[x, y, thickness] for x, y in ring]),
            camera
        )[:, 2]

        projected.append((ring, inner, top, bottom, depth))

    # --------------------------------------------------------
    # Ground shadow, so the part sits on the page
    # --------------------------------------------------------

    shadow = Image.new("L", canvas.size, 0)

    shadow_pen = ImageDraw.Draw(shadow)

    for ring, inner, _, bottom, _ in projected:

        if inner:
            continue

        shadow_pen.polygon(
            [
                (float(x) + 7 * over, float(y) + 11 * over)
                for x, y in bottom
            ],
            fill=64
        )

    canvas.paste(
        Image.new("RGBA", canvas.size, (46, 52, 62, 255)),
        (0, 0),
        shadow.filter(ImageFilter.GaussianBlur(9 * over))
    )

    # --------------------------------------------------------
    # Side walls
    # --------------------------------------------------------

    walls = []

    for index, (ring, inner, top, bottom, depth) in enumerate(projected):

        outward = signed_area(ring) > 0.0

        for i in range(len(ring) - 1):

            dx = ring[i + 1][0] - ring[i][0]
            dy = ring[i + 1][1] - ring[i][1]

            length = math.hypot(dx, dy)

            if length < 1e-9:
                continue

            if outward:
                normal = (dy / length, -dx / length, 0.0)
            else:
                normal = (-dy / length, dx / length, 0.0)

            # The wall of a hole faces the hole, not the world.
            if inner:
                normal = (-normal[0], -normal[1], 0.0)

            walls.append({
                "ring": index,
                "edge": i,
                "normal": normal,
                "depth": float(depth[i] + depth[i + 1]) / 2.0,
                "quad": [
                    tuple(top[i]),
                    tuple(top[i + 1]),
                    tuple(bottom[i + 1]),
                    tuple(bottom[i])
                ],
                "floor": [tuple(bottom[i]), tuple(bottom[i + 1])]
            })

    normals = np.array(
        [wall["normal"] for wall in walls] + [(0.0, 0.0, 1.0)],
        dtype=np.float64
    )

    front, level = dw.shade(normals, camera)

    for i, wall in enumerate(walls):
        wall["front"] = bool(front[i])
        wall["level"] = int(level[i])

    for wall in sorted(walls, key=lambda w: w["depth"]):

        if not wall["front"]:
            continue

        pen.polygon(
            wall["quad"],
            fill=tuple(int(c) for c in dw.STEEL_RAMP[wall["level"]])
        )

    # --------------------------------------------------------
    # Edges of the hole walls, drawn under the material
    #
    # The wall of a hole deeper than it is wide runs on past its
    # own opening, and what somebody would really see out there is
    # the plate. So these go on before the top face, which then
    # covers exactly the part of them that the metal hides.
    # --------------------------------------------------------

    # A pictorial crowded with holes is drawn as shading alone:
    # the strokes would meet and fill it in.
    crowded = len(rings) > MAX_DRAWN_RINGS

    if not crowded:
        wall_edges(pen, walls, projected, True, over)

    # --------------------------------------------------------
    # Top face: the outline with the holes taken out
    # --------------------------------------------------------

    mask = Image.new("L", canvas.size, 0)

    mask_pen = ImageDraw.Draw(mask)

    for ring, inner, top, _, _ in projected:

        mask_pen.polygon(
            [tuple(point) for point in top],
            fill=0 if inner else 255
        )

    canvas.paste(
        Image.new(
            "RGBA",
            canvas.size,
            tuple(int(c) for c in dw.STEEL_RAMP[int(level[-1])]) + (255,)
        ),
        (0, 0),
        mask
    )

    # --------------------------------------------------------
    # Everything the material does not hide
    # --------------------------------------------------------

    if not crowded:
        wall_edges(pen, walls, projected, False, over)

    for ring, inner, top, _, _ in projected:

        if inner and crowded:
            continue

        pen.line(
            [tuple(point) for point in top],
            fill=CONTOUR_COLOR,
            width=2 * over,
            joint="curve"
        )

    return canvas.resize((width, height), Image.Resampling.LANCZOS)


# ============================================================
# SHEET
#
# The ForgeMind page: gradient, double frame, header, schedule
# table bottom left and title block bottom right, the same as
# the cut map and the isometric.
# ============================================================

# The drawing area: below the header, above the bottom band.
AREA_TOP = 152

BAND_ROWS = 4

BAND_TOP = dw.CONTENT_BOTTOM - (
    dw.TITLE_HEAD_HEIGHT + dw.TITLE_ROW_HEIGHT * BAND_ROWS
)

AREA_BOTTOM = BAND_TOP - 26

LEGEND_RIGHT = 1230

# The main block holds the two line views; the side column holds
# the pictorial and the edge view.
MAIN_BLOCK = (dw.CONTENT_LEFT, AREA_TOP, 1480, AREA_BOTTOM)

SIDE_BLOCK = (1520, AREA_TOP, dw.CONTENT_RIGHT, AREA_BOTTOM)

CALLOUT_TOP = 34


def chain_reach(lines):
    """Room a chain of this many lines needs off the part."""

    if not lines:
        return 0

    return CHAIN_OFFSET + (lines - 1) * CHAIN_STEP + 34


def baseline_lines(values, runs):
    """Dimension lines the datum side of the view will carry."""

    if not values:
        return 1

    return (1 if runs else len(values)) + 1


def chain_margins(levels, pitch=(0, 0)):
    """Room the dimensions need on each side of the view.

    Measured off the datum corner on the left and underneath, and
    hole to hole on the other two sides.
    """

    left_lines, bottom_lines = levels

    right_lines, top_lines = pitch

    return (
        chain_reach(left_lines),
        max(30, chain_reach(top_lines)),
        max(34, chain_reach(right_lines)),
        chain_reach(bottom_lines)
    )


def centred(box, width, height):

    left, top, right, bottom = box

    x = left + (right - left - width) / 2.0
    y = top + (bottom - top - height) / 2.0

    return (
        int(round(x)),
        int(round(y)),
        int(round(x + width)),
        int(round(y + height))
    )


def side_column(vertical, has_edge):
    """The pictorial, and under it the edge view if there is one."""

    left, top, right, bottom = SIDE_BLOCK

    if not has_edge:
        return (left, top, right, bottom), None

    # A tall part shows its edge as a tall strip and needs the
    # room; a wide one lies across the bottom of a short panel.
    share = 0.48 if vertical else 0.32

    split = int(bottom - (bottom - top - PANEL_GAP) * share)

    return (
        (left, top, right, split),
        (left, split + PANEL_GAP, right, bottom)
    )

def plan(bbox, levels, labels, pitch, main):
    """Where the two line views go, and the one scale they share.

    The panels are not fixed boxes with the part shrunk into
    whatever is left: the largest scale that fits both views is
    worked out first, both arrangements are measured at it, and
    the boxes are cut to the size that scale needs.
    """

    min_x, min_y, max_x, max_y = bbox

    part_width = max(max_x - min_x, 1e-9)
    part_height = max(max_y - min_y, 1e-9)

    left, top, right, bottom = main

    room_width = right - left
    room_height = bottom - top

    chain_left, chain_top, chain_right, chain_bottom = chain_margins(
        levels,
        pitch
    )

    if not labels:

        scale = min(
            (room_width - chain_left - chain_right) / part_width,
            (room_height - chain_top - chain_bottom) / part_height
        )

        return {
            "callout": None,
            "dims": centred(
                main,
                part_width * scale + chain_left + chain_right,
                part_height * scale + chain_top + chain_bottom
            ),
            "scale": scale
        }

    spare = room_height - PANEL_GAP - chain_top - chain_bottom

    even = (spare - 2 * CALLOUT_TOP) / (2.0 * part_height)

    stacked = min(
        (room_width - 2 * CALLOUT_MARGIN) / part_width,
        (room_width - chain_left - chain_right) / part_width,
        even
        if even * part_height + 2 * CALLOUT_TOP >= labels
        else max((spare - labels) / part_height, 0.0)
    )

    beside = min(
        (room_height - 2 * CALLOUT_TOP) / part_height,
        (room_height - chain_top - chain_bottom) / part_height,
        (
            room_width - PANEL_GAP - 2 * CALLOUT_MARGIN
            - chain_left - chain_right
        ) / (2.0 * part_width)
    )

    scale = max(stacked, beside)

    callout_width = part_width * scale + 2 * CALLOUT_MARGIN

    callout_height = max(
        part_height * scale + 2 * CALLOUT_TOP,
        labels
    )

    dims_width = part_width * scale + chain_left + chain_right
    dims_height = part_height * scale + chain_top + chain_bottom

    if stacked >= beside:

        total = callout_height + PANEL_GAP + dims_height

        first = top + (room_height - total) / 2.0

        callout = centred(
            (left, first, right, first + callout_height),
            callout_width,
            callout_height
        )

        dims = centred(
            (
                left,
                first + callout_height + PANEL_GAP,
                right,
                first + total
            ),
            dims_width,
            dims_height
        )

    else:

        total = callout_width + PANEL_GAP + dims_width

        first = left + (room_width - total) / 2.0

        callout = centred(
            (first, top, first + callout_width, bottom),
            callout_width,
            callout_height
        )

        dims = centred(
            (
                first + callout_width + PANEL_GAP,
                top,
                first + total,
                bottom
            ),
            dims_width,
            dims_height
        )

    return {"callout": callout, "dims": dims, "scale": scale}


def settle(bbox, columns, rows, holes, thickness, contours, language):
    """The whole layout, settled against its own dimension chains.

    The chain on the far side steps out to another line when the
    holes are close together, which changes how much page is left
    for the part, which changes the scale, which decides whether
    they were close together. Two or three passes settle it.
    """

    min_x, min_y, max_x, max_y = bbox

    tolerance = max(
        CLUSTER_MIN,
        max(max_x - min_x, max_y - min_y) * CLUSTER_RATIO
    )

    slots = slot_callouts(
        find_slots(contours),
        tolerance,
        language
    )

    listed, labels = callout_plan(
        holes,
        bbox,
        AREA_BOTTOM - AREA_TOP - 2 * CALLOUT_TOP,
        slots
    )

    iso, edge = side_column(
        (max_y - min_y) >= (max_x - min_x),
        thickness is not None
    )

    if STANDARD["corner"] is not None:

        # On the standard page the title block leaves a corner
        # free, which is exactly where a pictorial belongs.
        iso = STANDARD["corner"]

        edge = SIDE_BLOCK if thickness is not None else None

    runs = (
        pitch_runs(rows, tolerance),
        pitch_runs(columns, tolerance)
    )

    # An axis with more steps than anybody can read keeps its
    # overall dimension and nothing else; the coordinates are in
    # the CSV, which the legend already says.
    if len(runs[0]) > MAX_PITCH_RUNS:
        rows = []
        runs = ([], runs[1])

    if len(runs[1]) > MAX_PITCH_RUNS:
        columns = []
        runs = (runs[0], [])

    levels = (
        baseline_lines(rows, runs[0]),
        baseline_lines(columns, runs[1])
    )

    pitch = (1 if runs[0] else 0, 1 if runs[1] else 0)

    for _ in range(3):

        layout = plan(bbox, levels, labels, pitch, MAIN_BLOCK)

        runs = (
            merge_unreadable(runs[0], layout["scale"]),
            merge_unreadable(runs[1], layout["scale"])
        )

        settled = (
            pitch_lines(runs[0], layout["scale"]),
            pitch_lines(runs[1], layout["scale"])
        )

        if settled == pitch:
            break

        pitch = settled

    layout["iso"] = iso
    layout["edge"] = edge
    layout["levels"] = levels
    layout["columns"] = columns
    layout["rows"] = rows
    layout["listed"] = listed
    layout["slots"] = slots
    layout["runs"] = runs
    layout["pitch"] = pitch
    layout["tolerance"] = tolerance

    return layout

# ============================================================
# WHAT THE SHEET SAYS ABOUT ITSELF
# ============================================================

TOKEN_SUFFIX = re.compile(r"_[0-9a-f]{8}$")


# The standard page is the same size as ours, so the layout
# engine does not care which one it is filling; only the blocks
# it may use change, and they are swapped in here.
STANDARD = {"corner": None, "notes": [], "on": False}

SIDE_WIDTH_PX = 430


def use_standard_page(rows):
    """Points the layout at the ЄСКД page instead of ours."""

    global AREA_TOP, AREA_BOTTOM, MAIN_BLOCK, SIDE_BLOCK

    views, corner = eskd.drawing_area(len(rows))

    AREA_TOP = views[1]
    AREA_BOTTOM = views[3]

    MAIN_BLOCK = (
        views[0],
        views[1],
        views[2] - SIDE_WIDTH_PX - PANEL_GAP,
        views[3]
    )

    SIDE_BLOCK = (views[2] - SIDE_WIDTH_PX, views[1], views[2], views[3])

    STANDARD["corner"] = corner
    STANDARD["notes"] = rows
    STANDARD["on"] = True


TOKEN_SUFFIX = re.compile(r"_[0-9a-f]{8}$")

TRAILING_COPY = re.compile(r"\s*\(\d+\)\s*$")


def designation_and_name(original):
    """A shop file name is <designation> - <name>, so it is split."""

    base = os.path.splitext(original)[0]

    base = TOKEN_SUFFIX.sub("", base)

    base = TRAILING_COPY.sub("", base.replace("^", "")).strip()

    for separator in (" - ", " – ", " — "):

        if separator in base:

            left, right = base.split(separator, 1)

            return left.strip(), TRAILING_COPY.sub("", right).strip()

    parts = base.split("_")

    if len(parts) > 1 and parts[-1][:1].isalpha():
        return "_".join(parts[:-1]), parts[-1]

    return base, ""


def requirement_lines(original, data, turn, thickness, language):
    """The numbered notes, and nothing in them that was guessed."""

    lines = [t(language, "req_file", file=original)]

    if turn:
        lines.append(
            t(language, "req_turned", angle=dw.format_number(turn))
        )

    if data.get("units") == "in":
        lines.append(t(language, "note_inches"))

    if not thickness:
        lines.append(t(language, "req_nominal"))

    lines.append(t(language, "req_tolerances"))

    return lines


def source_name(report, dxf_file):
    """The name the file had when somebody sent it."""

    original = (report or {}).get("original_name")

    if original:
        return original

    return TOKEN_SUFFIX.sub(
        "",
        os.path.splitext(os.path.basename(dxf_file))[0]
    ) + os.path.splitext(dxf_file)[1]


def sheet_note(data, turn, language):
    """The line along the top right: units, the turn, the caveat."""

    parts = [
        t(
            language,
            "note_inches" if data.get("units") == "in" else "note_mm"
        )
    ]

    if turn:
        parts.append(
            t(language, "note_turned", angle=dw.format_number(turn))
        )

    # Nothing on this sheet is a manufacturing decision, and the
    # shop was clear that nobody but the maker can set one.
    parts.append(t(language, "note_no_tolerances"))

    return " · ".join(parts)


def hole_rows(holes, language):
    """A hole schedule, for when the DXF was never analysed."""

    groups = {}

    for hole in holes:

        key = round(hole["diameter_mm"], 1)

        groups[key] = groups.get(key, 0) + 1

    return [
        (
            t(language, "hole_row_2d", diameter=dw.format_number(key)),
            t(language, "count_pieces", count=count)
        )
        for key, count in sorted(groups.items())
    ]


class Placed:
    """A Fit for a view that has already been projected.

    The sheets built from a solid model draw a plate face on, so
    its own flat coordinates reach the panel through a similarity
    and every dimension, callout and chain in this module works
    there unchanged. Only the mapping differs, so only the
    mapping is replaced.
    """

    def __init__(self, viewport, camera, bbox):

        self.viewport = viewport
        self.camera = camera

        self.scale = viewport.scale

        min_x, min_y, max_x, max_y = bbox

        self.min_x = min_x
        self.min_y = min_y

        self.width = max(max_x - min_x, 1e-9)
        self.height = max(max_y - min_y, 1e-9)

        corners = [
            self(point)
            for point in (
                (min_x, min_y),
                (max_x, min_y),
                (max_x, max_y),
                (min_x, max_y)
            )
        ]

        xs = [x for x, _ in corners]
        ys = [y for _, y in corners]

        self.rect = (min(xs), min(ys), max(xs), max(ys))

        self.over = 1

    def __call__(self, point):

        flat = np.array(
            [[float(point[0]), float(point[1]), 0.0]],
            dtype=np.float64
        )

        placed = self.viewport.screen_points(flat, self.camera)

        return float(placed[0][0]), float(placed[0][1])

    def ring(self, points):

        return [self(point) for point in points]

    def enlarged(self, over):

        return self


def draw_flat_marks(image, holes, bbox, box, language, scale,
                    place, baseline=True, side=None):
    """The whole markup, on a view somebody else projected.

    This is what a plate drawn from a solid model gets: the same
    diameter callouts and the same dimension chains as a plate
    that arrived as a DXF.
    """

    span = max(bbox[2] - bbox[0], bbox[3] - bbox[1])

    tolerance = max(CLUSTER_MIN, span * CLUSTER_RATIO)

    listed, _ = callout_plan(holes, bbox, box[3] - box[1])

    # On a panel that was not cut to the part there is one clear
    # margin, so every label goes to that side and the chains keep
    # the other. One side holds half as many, so the list is cut
    # to what it can hold, biggest counts first.
    if side is not None:

        # The grouped list carries one label per diameter for each
        # margin; with only one margin in use the second of every
        # pair says the same thing twice.
        single = {}

        for hole, count, _ in listed:

            key = (
                hole.get("text") or round(hole.get("diameter_mm", 0.0), 2),
                count
            )

            single.setdefault(key, (hole, count, side))

        room = int((box[3] - box[1] - 48) // callout_step(listed))

        listed = sorted(
            single.values(),
            key=lambda item: -item[1]
        )[:max(room, 1)]

    columns = chain_values(
        [hole["center"][0] for hole in holes],
        bbox[0],
        bbox[2],
        tolerance
    )

    rows = chain_values(
        [hole["center"][1] for hole in holes],
        bbox[1],
        bbox[3],
        tolerance
    )

    runs = (
        merge_unreadable(pitch_runs(rows, tolerance), scale),
        merge_unreadable(pitch_runs(columns, tolerance), scale)
    )

    if len(runs[0]) > MAX_PITCH_RUNS:
        rows, runs = [], ([], runs[1])

    if len(runs[1]) > MAX_PITCH_RUNS:
        columns, runs = [], (runs[0], [])

    draw_guides(image, place, bbox, holes, columns, rows, tolerance)

    if baseline:
        draw_chains(image, place, bbox, columns, rows, runs)
    else:
        draw_pitch(image, place, bbox, runs)

    draw_callouts(image, listed, place, box, language)


def part_note(caption, language):
    """Which part of a nest this sheet is, if it is one of many."""

    if not caption:
        return ""

    index, total, count = caption

    return " · " + t(
        language,
        "part_of_nest",
        index=index,
        total=total,
        count=count
    )


def build_sheet(dxf_file, data, holes, report, language, thickness,
                turn, layout, options, caption=None):

    contours = data["contours"]

    bbox = data["bbox"]

    min_x, min_y, max_x, max_y = bbox

    columns = layout["columns"]
    rows = layout["rows"]

    standard = options["standard"]

    page = eskd.sheet() if standard else dw.sheet()

    # --------------------------------------------------------
    # The two line views, drawn large and reduced
    # --------------------------------------------------------

    canvas = Image.new(
        "RGBA",
        (
            dw.PAGE_WIDTH * dw.SUPERSAMPLE,
            dw.PAGE_HEIGHT * dw.SUPERSAMPLE
        ),
        (0, 0, 0, 0)
    )

    dims_fit = Fit(
        bbox,
        layout["dims"],
        chain_margins(layout["levels"], layout["pitch"])
    )

    draw_contours(
        canvas,
        contours,
        dims_fit.enlarged(dw.SUPERSAMPLE),
        weight=dw.SUPERSAMPLE
    )

    callout_fit = None

    if layout["callout"] is not None:

        callout_fit = Fit(
            bbox,
            layout["callout"],
            (CALLOUT_MARGIN, CALLOUT_TOP, CALLOUT_MARGIN, CALLOUT_TOP)
        )

        draw_contours(
            canvas,
            contours,
            callout_fit.enlarged(dw.SUPERSAMPLE),
            weight=dw.SUPERSAMPLE
        )

    canvas = canvas.resize(
        (dw.PAGE_WIDTH, dw.PAGE_HEIGHT),
        Image.Resampling.LANCZOS
    )

    page.paste(canvas, (0, 0), canvas)

    # --------------------------------------------------------
    # Dimensions and callouts, at final size so they stay crisp
    # --------------------------------------------------------

    draw_centre_marks(page, holes, dims_fit)

    draw_guides(
        page,
        dims_fit,
        bbox,
        holes,
        columns,
        rows,
        layout["tolerance"]
    )

    draw_chains(page, dims_fit, bbox, columns, rows, layout["runs"])

    dw.panel_caption(page, layout["dims"], t(language, "view_dims"))

    # The first view says what the features are, the second says
    # where they are. Radii and corner angles belong with the
    # first: on the second they would sit among the chains.
    shape_fit = callout_fit or dims_fit

    draw_radii(page, shape_fit, layout["arcs"], contours)

    draw_corners(page, shape_fit, layout["angles"])

    # Anything too small to read here is drawn again on the next
    # sheet, and the circle says which is which.
    for index, region in enumerate(layout["regions"]):
        mark_detail(page, shape_fit, region, DETAIL_LETTERS[index])

    if callout_fit is not None:

        draw_centre_marks(page, holes, callout_fit)

        draw_callouts(
            page,
            layout["listed"],
            callout_fit,
            layout["callout"],
            language
        )

        dw.panel_caption(
            page,
            layout["callout"],
            t(
                language,
                "view_callout" if options["shape"] else "view_holes"
            )
        )

    # --------------------------------------------------------
    # Edge view and pictorial
    # --------------------------------------------------------

    if layout["edge"] is not None:

        rect = layout["edge"]

        dw.panel(page, rect)

        draw_edge_view(
            page,
            rect,
            bbox,
            holes,
            thickness,
            (max_y - min_y) >= (max_x - min_x)
        )

        dw.panel_caption(page, rect, t(language, "view_edge"))

    rect = layout["iso"]

    nominal = thickness is None

    picture = iso_view(
        rect,
        contours,
        thickness or max(
            max(max_x - min_x, max_y - min_y) * NOMINAL_RATIO,
            NOMINAL_MIN
        )
    )

    if picture is not None:

        dw.panel(page, rect)

        page.paste(picture, (rect[0], rect[1]), picture)

        dw.panel(page, rect, fill=None)

        dw.panel_caption(
            page,
            rect,
            t(language, "view_iso_nominal" if nominal else "view_iso")
        )

    # --------------------------------------------------------
    # Page furniture
    # --------------------------------------------------------

    original = source_name(report, dxf_file)

    if standard:

        designation, name = designation_and_name(original)

        say = lambda key: t(language, key)

        eskd.frame(page)

        eskd.left_column(page, say)

        eskd.designation_mark(
            page,
            designation,
            eskd.field()[0] + eskd.COLUMN_WIDTH + 4.0
        )

        eskd.requirements(page, STANDARD["notes"])

        if caption:
            name = (name + " " + part_note(caption, language)).strip()

        eskd.title_block(
            page,
            {
                "designation": designation,
                "name": name,
                "material": (
                    t(
                        language,
                        "material_sheet",
                        thickness=dw.format_number(thickness)
                    )
                    if thickness
                    else ""
                ),
                "sheets": "2" if layout["regions"] else "1",
                "company": "ForgeMind"
            },
            say
        )

        eskd.stamp(page, "ForgeMind · {} · {}".format(original, dw.today()))

        return page

    dw.frame(page)

    dw.header(
        page,
        t(language, "sheet_header_drawing"),
        original + part_note(caption, language),
        note=sheet_note(data, turn, language)
    )

    from render_dxf import legend_note, legend_rows

    legend, hidden = legend_rows(report, language)

    # A part taken out of a nest has no hole groups in the report,
    # because the report counted the whole sheet.
    if not report.get("hole_groups"):
        legend = legend + hole_rows(holes, language)

    for slot in layout["slots"]:

        legend.append((
            t(language, "legend_slot", size=slot["text"]),
            t(language, "count_pieces", count=slot["count"])
        ))

    dw.table(
        page,
        (dw.CONTENT_LEFT, BAND_TOP, LEGEND_RIGHT, dw.CONTENT_BOTTOM),
        t(language, "tag_drawing"),
        legend,
        columns=2,
        note=legend_note(report, holes, hidden, language)
    )

    if thickness is not None:

        third = (
            t(language, "lbl_thickness"),
            "{} {}".format(
                dw.format_number(thickness),
                t(language, "unit_mm")
            )
        )

    else:

        third = (
            t(language, "lbl_cut"),
            "{} {} · {} {}".format(
                dw.format_number(report.get("cut_length_mm", 0.0)),
                t(language, "unit_mm"),
                report.get("pierces", 0),
                t(language, "lbl_pierces")
            )
        )

    dw.title_block(
        page,
        [
            (t(language, "lbl_file"), original),
            (
                t(language, "lbl_size"),
                "{} × {} {}".format(
                    dw.format_number(max(max_x - min_x, max_y - min_y)),
                    dw.format_number(min(max_x - min_x, max_y - min_y)),
                    t(language, "unit_mm")
                )
            ),
            third,
            (t(language, "lbl_date"), dw.today())
        ],
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_drawing")
    )

    return page

def detail_panels(count):
    """One panel per detail, however many were asked for.

    Taken from the blocks the layout is using, so the labels stay
    off the binding column on the standard page. Asked for every
    corner rather than only the crowded ones, four of them go on
    the sheet in two rows.
    """

    left = MAIN_BLOCK[0]
    right = SIDE_BLOCK[2]

    if count <= 1:
        return [(left, AREA_TOP, right, AREA_BOTTOM)]

    middle = (left + right) // 2

    columns = (
        (left, middle - PANEL_GAP // 2),
        (middle + PANEL_GAP // 2, right)
    )

    if count <= 2:
        return [(a, AREA_TOP, b, AREA_BOTTOM) for a, b in columns]

    half = (AREA_TOP + AREA_BOTTOM) // 2

    rows = (
        (AREA_TOP, half - PANEL_GAP // 2),
        (half + PANEL_GAP // 2, AREA_BOTTOM)
    )

    return [
        (a, top, b, bottom)
        for top, bottom in rows
        for a, b in columns
    ][:count]


def build_details(dxf_file, data, holes, report, language, thickness,
                  layout):
    """The second sheet: the crowded corners, drawn larger.

    Nothing new is measured here. The same holes, radii and
    angles are drawn again at a scale where somebody can read
    them, which is what the reference drawings do with every part
    that has fine work at one end.
    """

    regions = layout["regions"]

    if not regions:
        return None

    page = eskd.sheet() if STANDARD["on"] else dw.sheet()

    rects = detail_panels(len(regions))

    regions = regions[:len(rects)]

    for index, (region, rect) in enumerate(zip(regions, rects)):

        draw_detail(
            page,
            rect,
            region,
            detail_factor(region, rect, layout["scale"]),
            layout["scale"],
            data,
            holes,
            layout["arcs"],
            layout["angles"],
            layout["slots"],
            language,
            DETAIL_LETTERS[index],
            layout["tolerance"]
        )

    original = source_name(report, dxf_file)

    if STANDARD["on"]:

        designation, _ = designation_and_name(original)

        say = lambda key: t(language, key)

        eskd.frame(page)

        eskd.left_column(page, say)

        eskd.designation_mark(
            page,
            designation,
            eskd.field()[0] + eskd.COLUMN_WIDTH + 4.0
        )

        eskd.title_block(
            page,
            {
                "designation": designation,
                "name": t(language, "tag_details"),
                "material": "",
                "sheets": "2",
                "company": "ForgeMind"
            },
            say
        )

        return page

    dw.frame(page)

    dw.header(
        page,
        t(language, "sheet_header_details"),
        original,
        note=t(language, "note_details")
    )

    min_x, min_y, max_x, max_y = data["bbox"]

    dw.title_block(
        page,
        [
            (t(language, "lbl_file"), original),
            (
                t(language, "lbl_size"),
                "{} × {} {}".format(
                    dw.format_number(max(max_x - min_x, max_y - min_y)),
                    dw.format_number(min(max_x - min_x, max_y - min_y)),
                    t(language, "unit_mm")
                )
            ),
            (
                t(language, "lbl_details"),
                ", ".join(
                    "{} ({}:1)".format(
                        DETAIL_LETTERS[index],
                        dw.format_number(
                            detail_factor(region, rect, layout["scale"])
                        )
                    )
                    for index, (region, rect) in enumerate(
                        zip(regions, rects)
                    )
                )
            ),
            (t(language, "lbl_date"), dw.today())
        ],
        (dw.CONTENT_RIGHT, dw.CONTENT_BOTTOM),
        tag=t(language, "tag_details")
    )

    return page


def draw_one(dxf_file, data, holes, report, language, thickness,
             options, caption=None):
    """Everything for one part: its sheet, and its details page."""

    turn = lay_down(data, holes)

    if turn:
        print("TURNED:", round(turn, 1), "degrees")

    if options["standard"]:

        # The notes decide how much page is left, so they are
        # written and broken into lines before anything is laid
        # out on it.
        use_standard_page(
            eskd.requirement_rows(
                requirement_lines(
                    source_name(report, dxf_file),
                    data,
                    turn,
                    thickness,
                    language
                )
            )
        )

    bbox = data["bbox"]

    min_x, min_y, max_x, max_y = bbox

    tolerance = max(
        CLUSTER_MIN,
        max(max_x - min_x, max_y - min_y) * CLUSTER_RATIO
    )

    columns = chain_values(
        [hole["center"][0] for hole in holes],
        min_x,
        max_x,
        tolerance
    )

    rows = chain_values(
        [hole["center"][1] for hole in holes],
        min_y,
        max_y,
        tolerance
    )

    def measured(box):

        span = max(box[2] - box[0], box[3] - box[1])

        step = max(CLUSTER_MIN, span * CLUSTER_RATIO)

        return (
            settle(
                box,
                chain_values(
                    [hole["center"][0] for hole in holes],
                    box[0],
                    box[2],
                    step
                ),
                chain_values(
                    [hole["center"][1] for hole in holes],
                    box[1],
                    box[3],
                    step
                ),
                holes,
                thickness,
                data["contours"],
                language
            )
        )

    layout = measured(bbox)

    # The sheet is wider than it is tall, so a tall part lying
    # down is drawn larger on it. Same drawing, more of it.
    spun = spin(data, holes, math.pi / 2.0)

    other = measured(spun)

    # Only a real gain is worth turning the part: a few percent
    # buys nothing and leaves the reader wondering why.
    if other["scale"] > layout["scale"] * 1.15:

        layout = other
        bbox = spun
        turn = (turn + 90.0) % 180.0

        print("LAID ALONG THE SHEET")

    else:

        bbox = spin(data, holes, -math.pi / 2.0)

    # Measured off the outline itself, so the answer is the same
    # whatever wrote the DXF.
    layout["arcs"] = (
        collect_arcs(data["contours"], bbox)
        if options["shape"]
        else []
    )

    layout["angles"] = (
        corner_angles(data["contours"], bbox)
        if options["shape"]
        else []
    )

    # A feature that lands under about a millimetre and a half on
    # paper gets a sheet of its own.
    # The details are found from every arc, not only the ones
    # asked for on the sheet, or turning the radii off would hide
    # the very corner that needed enlarging.
    layout["regions"] = (
        detail_regions(
            holes,
            collect_arcs(data["contours"], bbox),
            bbox,
            layout["scale"],
            options["details"]
        )
        if options["details"]
        else []
    )

    print(
        "RADII:", len(layout["arcs"]),
        "ANGLES:", len(layout["angles"]),
        "DETAILS:", len(layout["regions"])
    )

    page = build_sheet(
        dxf_file,
        data,
        holes,
        report,
        language,
        thickness,
        turn,
        layout,
        options,
        caption
    )

    details = build_details(
        dxf_file,
        data,
        holes,
        report,
        language,
        thickness,
        layout
    )

    return page, details


# ============================================================
# MAIN
# ============================================================

def main():

    from dxf_analyzer import find_holes, load_contours
    from render_dxf import load_report

    if len(sys.argv) < 2:
        print("Usage: detail_dxf.py <dxf_file> [language] [thickness_mm]")
        sys.exit(1)

    dxf_file = sys.argv[1]

    language = (
        sys.argv[2]
        if len(sys.argv) > 2
        else DEFAULT_LANGUAGE
    )

    options = read_options(sys.argv[4] if len(sys.argv) > 4 else "")

    thickness = None

    if len(sys.argv) > 3:

        try:
            thickness = float(sys.argv[3].replace(",", "."))
        except ValueError:
            thickness = None

        if thickness is not None and thickness <= 0.0:
            thickness = None

    if not os.path.exists(dxf_file):
        print("ERROR: DXF file not found:")
        print(dxf_file)
        sys.exit(1)

    # A Ukrainian drawing writes 3,5 and not 3.5.
    dw.DECIMAL = "," if language.lower().startswith("uk") else "."

    print()
    print("=" * 90)
    print("FORGEMIND PART DRAWING")
    print("=" * 90)
    print()

    print("DXF:", dxf_file)
    print("THICKNESS:", thickness if thickness else "not given")
    print("OPTIONS:", options)

    data = load_contours(dxf_file)

    if not data["contours"] or data["bbox"] is None:
        print("ERROR: nothing drawable in this DXF.")
        sys.exit(1)

    holes = find_holes(data["contours"], data["scale"])

    print("CONTOURS:", len(data["contours"]))
    print("HOLES:", len(holes))

    report = load_report(dxf_file) or {}

    # A nest is several parts, and each of them can have the
    # drawing it would have had on its own.
    parts = split_parts(data, holes) if options["parts"] else None

    pages = []

    if parts:

        found = unique_parts(parts)[:MAX_PART_SHEETS]

        print("PARTS:", len(parts), "unique:", len(found))

        for index, part in enumerate(found, 1):

            page, details = draw_one(
                dxf_file,
                part["data"],
                part["holes"],
                {
                    "area_mm2": part["area"],
                    "perimeter_mm": polyline_length(
                        part["data"]["contours"][0]["points"]
                    )
                },
                language,
                thickness,
                options,
                (index, len(found), part["count"])
            )

            pages.append(page)

            if details is not None:
                pages.append(details)

    else:

        page, details = draw_one(
            dxf_file,
            data,
            holes,
            report,
            language,
            thickness,
            options
        )

        pages = [page] + ([details] if details is not None else [])

    page = pages[0]

    details = pages[1] if len(pages) > 1 else None


    base = os.path.splitext(dxf_file)[0]

    png_file = base + "_drawing.png"
    pdf_file = base + "_drawing.pdf"

    page.save(png_file, "PNG", optimize=True)

    print()
    print("PNG:", png_file)

    extra = []

    if details is not None:

        second = base + "_drawing2.png"

        details.save(second, "PNG", optimize=True)

        extra.append(details.convert("RGB"))

        print("PNG:", second)

    page.convert("RGB").save(
        pdf_file,
        "PDF",
        save_all=True,
        append_images=[sheet.convert("RGB") for sheet in pages[1:]],
        resolution=PDF_RESOLUTION,
        quality=PDF_QUALITY
    )

    print("PDF:", pdf_file)

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
