"""What the file says about itself, before anyone cuts it.

This began as a manufacturability verdict and was wrong to. The
rules it judged by — a hole at least as wide as the plate is thick,
a bridge of one and a half thicknesses — are rules of thumb from the
CO2 era. A fibre laser puts a 3 mm hole through 6 mm plate every
day, so the warning told a shop something false about its own
equipment, in a tone that implied otherwise.

So this measures instead of judging. Two things come back:

* **Problems** — what is wrong with the *file*, on any machine:
  contours that do not close, contours cut twice, contours that
  enclose nothing, a mesh with holes in it. None of these depend on
  what stands on the shop floor.

* **Measurements** — the numbers somebody quoting the job reaches
  for anyway: the smallest hole, the thinnest bridge, the shortest
  flange, the tightest bend radius, each with the material it sits
  in. No verdict attached, because the shop knows its machine and
  this file does not.

Thresholds come back the day the shop's own table replaces the
guesses. Then these same numbers get a pass or a fail beside them,
with the shop's own rule as the reason.
"""

import math

from i18n import t


# ============================================================
# CONFIGURATION
# ============================================================

# Holes are compared only against holes drilled the same way.
PARALLEL = 0.99

# What counts as sheet rather than a machined or bought part.
PLATE_RATIO = 8.0

# A plate fills its own bounding box. A frame bent from square tube
# does not — its box is mostly air — and without this it would be
# read as a 50 mm plate.
PLATE_FILL = 0.35

# Long lists help nobody.
MAX_LINES = 14


# ============================================================
# GEOMETRY
# ============================================================

def part_size(part):

    size = part.get("bounding_box", {}).get("size", {})

    values = sorted(
        value
        for value in (size.get("x"), size.get("y"), size.get("z"))
        if value
    )

    return values if len(values) == 3 else None


def is_plate(size, volume=None):

    if size[1] <= PLATE_RATIO * size[0]:
        return False

    if not volume:
        return True

    box = size[0] * size[1] * size[2]

    return box > 0 and volume / box >= PLATE_FILL


def positions_by_part(data, rows):
    """Which bill-of-materials position each part belongs to.

    Identical parts share a position and only one of them carries
    its name, so the row is found by the same signature the bill
    grouped them with.
    """

    from bom import part_signature

    by_name = {
        part.get("name"): part
        for part in data.get("parts", [])
    }

    by_signature = {}

    for row in rows:

        part = by_name.get(row["name"])

        if part is not None:
            by_signature[part_signature(part)] = row["position"]

    return {
        part.get("index"): by_signature.get(part_signature(part))
        for part in data.get("parts", [])
    }


def holes_by_part(data):

    grouped = {}

    for hole in data.get("holes", []):
        grouped.setdefault(hole.get("part"), []).append(hole)

    return grouped


def parallel(first, second):

    if not first or not second:
        return True

    return abs(sum(a * b for a, b in zip(first, second))) > PARALLEL


def across(first, second, axis):
    """Distance between two hole centres across their common axis.

    Plain distance is the wrong measure: a counterbore is two holes
    on one axis, a millimetre apart down it, and subtracting their
    radii from that leaves a bridge of nothing. Only the offset
    across the axis is metal.
    """

    delta = [b - a for a, b in zip(first, second)]

    if not axis:
        return math.sqrt(sum(d * d for d in delta))

    along = sum(d * a for d, a in zip(delta, axis))

    return math.sqrt(
        max(sum(d * d for d in delta) - along * along, 0.0)
    )


def thinnest_bridge(holes, flat=False):
    """The least metal left between any two holes.

    A pair with nothing between them is not a bridge at all: a
    counterbore down one axis, or the two ends of a slot.
    """

    closest = None

    for index, first in enumerate(holes):

        centre = first.get("center")

        if not centre:
            continue

        for second in holes[index + 1:]:

            other = second.get("center")

            if not other:
                continue

            if flat:

                apart = math.sqrt(
                    sum(
                        (a - b) ** 2
                        for a, b in zip(centre[:2], other[:2])
                    )
                )

            else:

                if not parallel(first.get("axis"), second.get("axis")):
                    continue

                apart = across(centre, other, first.get("axis"))

            metal = (
                apart
                - first.get("diameter_mm", 0.0) / 2.0
                - second.get("diameter_mm", 0.0) / 2.0
            )

            if metal <= 0.0:
                continue

            if closest is None or metal < closest:
                closest = metal

    return closest


# ============================================================
# PROBLEMS: true on any machine
# ============================================================

def problems(data, language):

    found = []

    contours = data.get("contours", {})

    if contours.get("open"):
        found.append(
            t(language, "mfg_open", count=contours["open"])
        )

    if contours.get("duplicate"):
        found.append(
            t(language, "mfg_duplicate", count=contours["duplicate"])
        )

    if contours.get("degenerate"):
        found.append(
            t(language, "mfg_degenerate", count=contours["degenerate"])
        )

    mesh = data.get("mesh", {})

    if mesh.get("open_edges") and not mesh.get("watertight"):
        found.append(
            t(language, "mfg_mesh_open", count=mesh["open_edges"])
        )

    return found


# ============================================================
# MEASUREMENTS: the numbers, without an opinion
# ============================================================

def number(value):

    if value is None:
        return None

    if abs(value - round(value)) < 0.05:
        return str(int(round(value)))

    return "{:.1f}".format(value)


def measure_solid(data, language):

    from bom import build_bom

    positions = positions_by_part(data, build_bom(data))

    grouped = holes_by_part(data)

    smallest = None
    bridge = None
    flange = None
    radius = None
    biggest = None

    for part in data.get("parts", []):

        size = part_size(part)

        if size is None:
            continue

        index = part.get("index")

        position = positions.get(index)

        holes = grouped.get(index, [])

        # Only sheet gets the hole numbers: a small hole in a turned
        # standoff is drilled, and nobody is quoting it as laser work.
        if holes and is_plate(size, part.get("volume_mm3")):

            for hole in holes:

                diameter = hole.get("diameter_mm")

                if diameter and (
                    smallest is None or diameter < smallest[0]
                ):
                    smallest = (diameter, size[0], position)

            metal = thinnest_bridge(holes)

            if metal is not None and (bridge is None or metal < bridge[0]):
                bridge = (metal, size[0], position)

        bend = part.get("bend")

        if bend and bend.get("thickness"):

            shortest = min(bend.get("runs") or [0.0])

            if shortest and (flange is None or shortest < flange[0]):
                flange = (shortest, bend["thickness"], position)

            for value in bend.get("radii") or []:

                if radius is None or value < radius[0]:
                    radius = (value, bend["thickness"], position)

        if biggest is None or size[2] > biggest[2]:
            biggest = size

    lines = []

    if smallest:
        lines.append(
            t(
                language,
                "measure_hole",
                diameter=number(smallest[0]),
                thickness=number(smallest[1]),
                position=smallest[2]
            )
        )

    if bridge:
        lines.append(
            t(
                language,
                "measure_bridge",
                value=number(bridge[0]),
                thickness=number(bridge[1]),
                position=bridge[2]
            )
        )

    if flange:
        lines.append(
            t(
                language,
                "measure_flange",
                value=number(flange[0]),
                thickness=number(flange[1]),
                position=flange[2]
            )
        )

    if radius:
        lines.append(
            t(
                language,
                "measure_radius",
                value=number(radius[0]),
                thickness=number(radius[1]),
                position=radius[2]
            )
        )

    if biggest:
        lines.append(
            t(
                language,
                "measure_biggest",
                length=number(biggest[2]),
                width=number(biggest[1]),
                thickness=number(biggest[0])
            )
        )

    return lines


def measure_flat(data, language):

    lines = []

    holes = [
        hole
        for hole in data.get("holes", [])
        if hole.get("diameter_mm")
    ]

    if holes:

        lines.append(
            t(
                language,
                "measure_hole_flat",
                diameter=number(
                    min(hole["diameter_mm"] for hole in holes)
                )
            )
        )

        metal = thinnest_bridge(holes, flat=True)

        if metal is not None:
            lines.append(
                t(language, "measure_bridge_flat", value=number(metal))
            )

    size = data.get("bounding_box", {}).get("size", {})

    if size.get("x") and size.get("y"):

        lines.append(
            t(
                language,
                "measure_sheet",
                length=number(size["x"]),
                width=number(size["y"])
            )
        )

    return lines


def measure_mesh(data, language):

    size = data.get("bounding_box", {}).get("size", {})

    if not size:
        return []

    return [
        t(
            language,
            "measure_biggest",
            length=number(size.get("x")),
            width=number(size.get("y")),
            thickness=number(size.get("z"))
        )
    ]


# ============================================================
# REPORT
# ============================================================

def can_review(data):
    """Whether this analysis holds anything worth looking at."""

    return bool(
        data.get("parts")
        or data.get("contours")
        or data.get("mesh")
    )


def review(data, language):
    """(summary, details), or (None, None) if there is nothing to say."""

    if not can_review(data):
        return None, None

    faults = problems(data, language)

    if data.get("parts"):
        numbers = measure_solid(data, language)

    elif data.get("contours"):
        numbers = measure_flat(data, language)

    else:
        numbers = measure_mesh(data, language)

    lines = []

    if faults:

        lines.append(t(language, "mfg_problems"))

        lines.extend("• " + line for line in faults[:MAX_LINES])

        lines.append("")

    if numbers:

        lines.append(t(language, "mfg_measured"))

        lines.extend("• " + line for line in numbers[:MAX_LINES])

        lines.append("")

    lines.append(t(language, "mfg_no_thresholds"))

    summary = (
        t(language, "mfg_faults", count=len(faults))
        if faults
        else t(language, "mfg_no_faults")
    )

    return summary, "\n".join(lines)
