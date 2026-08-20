import csv
import os

from i18n import DEFAULT_LANGUAGE, items_word, t


# ============================================================
# CONFIGURATION
# ============================================================

# Two parts count as the same item when their size, volume and
# topology all match at this precision.
SIZE_PRECISION = 1
VOLUME_PRECISION = 1

# Rows shown in the chat message; the rest stay in the CSV.
MAX_CHAT_ROWS = 15

# Excel picks the delimiter from the system list separator, and
# a UTF-8 BOM is what makes it read Cyrillic correctly.
CSV_DELIMITER = ";"
CSV_ENCODING = "utf-8-sig"


# ============================================================
# GROUPING
# ============================================================

def part_signature(part):
    """Identity of a part for bill-of-materials grouping.

    Dimensions are sorted so a part that sits rotated in the
    assembly still groups with its twins.
    """

    size = part.get("bounding_box", {}).get("size", {})

    dims = tuple(sorted(
        round(size.get(axis, 0.0), SIZE_PRECISION)
        for axis in ("x", "y", "z")
    ))

    return (
        dims,
        round(part.get("volume_mm3", 0.0), VOLUME_PRECISION),
        part.get("faces", 0),
        part.get("edges", 0)
    )


def holes_per_part(data):

    counts = {}

    for hole in data.get("holes", []):

        index = hole.get("part")

        if index is not None:
            counts[index] = counts.get(index, 0) + 1

    return counts


def build_bom(data):
    """Groups identical parts into bill-of-materials rows."""

    parts = data.get("parts", [])

    if not parts:
        return []

    hole_counts = holes_per_part(data)

    groups = {}

    for part in parts:

        key = part_signature(part)

        if key not in groups:

            size = part.get("bounding_box", {}).get("size", {})

            groups[key] = {
                "count": 0,
                "name": part.get("name", "?"),
                "index": part.get("index", 0),
                "size_x": round(size.get("x", 0.0), 2),
                "size_y": round(size.get("y", 0.0), 2),
                "size_z": round(size.get("z", 0.0), 2),
                "volume_mm3": round(
                    part.get("volume_mm3", 0.0),
                    2
                ),
                "faces": part.get("faces", 0),
                "edges": part.get("edges", 0),
                "holes": hole_counts.get(
                    part.get("index"),
                    0
                )
            }

        groups[key]["count"] += 1

    rows = sorted(
        groups.values(),
        key=lambda row: (-row["count"], -row["volume_mm3"])
    )

    for position, row in enumerate(rows, 1):
        row["position"] = position

    return rows


# ============================================================
# CSV EXPORT
# ============================================================

def write_bom_csv(rows, path, language=DEFAULT_LANGUAGE):

    with open(
        path,
        "w",
        newline="",
        encoding=CSV_ENCODING
    ) as f:

        writer = csv.writer(f, delimiter=CSV_DELIMITER)

        writer.writerow([
            t(language, "csv_number"),
            t(language, "csv_name"),
            t(language, "csv_qty"),
            t(language, "csv_size_x"),
            t(language, "csv_size_y"),
            t(language, "csv_size_z"),
            t(language, "csv_volume"),
            t(language, "csv_holes"),
            t(language, "csv_faces"),
            t(language, "csv_edges")
        ])

        for row in rows:

            writer.writerow([
                row["position"],
                row["name"],
                row["count"],
                f'{row["size_x"]:.2f}',
                f'{row["size_y"]:.2f}',
                f'{row["size_z"]:.2f}',
                f'{row["volume_mm3"]:.2f}',
                row["holes"],
                row["faces"],
                row["edges"]
            ])

    return path


def write_holes_csv(data, path, language=DEFAULT_LANGUAGE):
    """Hole table for CNC use: 3D files carry an axis, 2D do not."""

    holes = data.get("holes", [])

    if not holes:
        return None

    is_3d = "axis" in holes[0]

    with open(
        path,
        "w",
        newline="",
        encoding=CSV_ENCODING
    ) as f:

        writer = csv.writer(f, delimiter=CSV_DELIMITER)

        header = [
            t(language, "csv_number"),
            t(language, "csv_diameter")
        ]

        if is_3d:
            header += [
                t(language, "csv_length"),
                t(language, "csv_part")
            ]

        header += ["X", "Y"]

        if is_3d:
            header += [
                "Z",
                t(language, "csv_axis_x"),
                t(language, "csv_axis_y"),
                t(language, "csv_axis_z")
            ]

        writer.writerow(header)

        for number, hole in enumerate(holes, 1):

            center = hole.get("center", [0, 0, 0])

            row = [
                hole.get("index", number),
                f'{hole.get("diameter_mm", 0):.3f}'
            ]

            if is_3d:
                row += [
                    f'{hole.get("length_mm", 0):.3f}',
                    hole.get("part", "")
                ]

            row += [
                f"{center[0]:.3f}",
                f"{center[1]:.3f}"
            ]

            if is_3d:

                axis = hole.get("axis", [0, 0, 0])

                row += [
                    f"{center[2]:.3f}",
                    f"{axis[0]:.5f}",
                    f"{axis[1]:.5f}",
                    f"{axis[2]:.5f}"
                ]

            writer.writerow(row)

    return path


# ============================================================
# CHAT TEXT
# ============================================================

def build_bom_text(rows, data, language=DEFAULT_LANGUAGE):
    """Returns (summary, details); the caller folds the details away."""

    lines = []

    total = sum(row["count"] for row in rows)

    lines.append(t(language, "bom_title"))
    lines.append("")

    lines.append(t(language, "bom_total", count=total))
    lines.append(t(language, "bom_unique", count=len(rows)))

    total_volume = data.get("total", {}).get("volume_mm3")

    if total_volume:
        lines.append(
            t(
                language,
                "bom_volume",
                value=f"{total_volume:,.1f}".replace(",", " ")
            )
        )

    details = []

    shown = rows[:MAX_CHAT_ROWS]

    for row in shown:

        details.append(
            t(
                language,
                "bom_row",
                position=row["position"],
                name=row["name"],
                count=row["count"]
            )
        )

        detail = (
            f'   {row["size_x"]:.1f} × '
            f'{row["size_y"]:.1f} × '
            f'{row["size_z"]:.1f} '
            + ("мм" if language == "uk" else "mm")
        )

        if row["holes"]:
            detail += t(
                language,
                "bom_row_holes",
                count=row["holes"]
            )

        details.append(detail)

    if len(rows) > len(shown):

        details.append("")
        hidden = len(rows) - len(shown)

        details.append(
            t(
                language,
                "bom_more",
                count=hidden,
                word=items_word(language, hidden)
            )
        )

    return "\n".join(lines), "\n".join(details)
