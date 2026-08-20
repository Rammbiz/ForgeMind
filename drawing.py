"""Shared drawing layer for every ForgeMind renderer.

Pure numpy + PIL, so the same code runs in the project venv and
inside freecadcmd. Nothing here touches a CAD kernel: callers hand
over plain vertex and triangle arrays.

Geometry is rasterized at SUPERSAMPLE times the final size and then
reduced, which is what makes the edges smooth. Text and dimensions
are drawn afterwards, at the final size, so they stay crisp.
"""

import datetime
import math
import os

import numpy as np

from PIL import Image, ImageDraw, ImageFilter, ImageFont


# ============================================================
# PAGE
# ============================================================

SUPERSAMPLE = 2

PAGE_WIDTH = 2000
PAGE_HEIGHT = 1500

# Two borders, as on a drawing sheet: a hairline at the paper edge
# and the heavy frame with the wide binding margin on the left.
EDGE_INSET = 14
BORDER_LEFT = 56
BORDER_INSET = 28

EDGE_LINE = (198, 201, 207)
BORDER_LINE = (58, 62, 70)

CONTENT_LEFT = BORDER_LEFT + 18
CONTENT_RIGHT = PAGE_WIDTH - BORDER_INSET - 18
CONTENT_TOP = BORDER_INSET + 14
CONTENT_BOTTOM = PAGE_HEIGHT - BORDER_INSET - 14

BACKGROUND_TOP = (253, 253, 254)
BACKGROUND_BOTTOM = (234, 236, 241)

PANEL_FILL = (255, 255, 255)
PANEL_BORDER = (200, 204, 211)
PANEL_HEADER = (243, 245, 248)

INK = (26, 28, 32)
LINE = (52, 56, 62)
MUTED = (112, 117, 126)
ACCENT = (198, 44, 44)


# ============================================================
# FONTS
#
# ISOCPEUR is the ISO 3098 drawing font: it arrives with AutoCAD
# and Rhino, covers Cyrillic, and is what makes dimensions look
# like dimensions. Segoe UI carries the prose, where a 0.35 mm
# technical pen is simply too thin to read on screen.
# ============================================================

FONT_DIRECTORY = r"C:\Windows\Fonts"

FONT_FILES = {
    "drawing": ("isocpeur.ttf", "segoeui.ttf", "arial.ttf"),
    "text": ("segoeui.ttf", "arial.ttf"),
    "bold": ("segoeuib.ttf", "arialbd.ttf", "segoeui.ttf")
}

# The drawing font is narrow and small on the body, so it needs a
# bigger nominal size to sit level with the prose.
FONT_SCALE = {"drawing": 1.30, "text": 1.0, "bold": 1.0}

_FONTS = {}


def font(size, kind="text"):
    """Cached font lookup; falls back to whatever PIL can offer."""

    key = (size, kind)

    if key in _FONTS:
        return _FONTS[key]

    pixels = int(round(size * FONT_SCALE.get(kind, 1.0)))

    chosen = None

    for name in FONT_FILES.get(kind, FONT_FILES["text"]):

        path = os.path.join(FONT_DIRECTORY, name)

        if not os.path.exists(path):
            continue

        try:
            chosen = ImageFont.truetype(path, pixels)
            break
        except Exception:
            continue

    if chosen is None:
        chosen = ImageFont.load_default()

    _FONTS[key] = chosen

    return chosen


def text_width(text, chosen_font):

    box = chosen_font.getbbox(text)

    return box[2] - box[0]


# A Ukrainian drawing writes 3,5 where an English one writes 3.5.
# The sheet sets this once from the language it is drawn in.
DECIMAL = "."


def format_number(value, decimals=1):
    """Whole numbers lose their decimal point, as on a drawing."""

    if abs(value - round(value)) < 0.05:
        return str(int(round(value)))

    return f"{value:.{decimals}f}".replace(".", DECIMAL)


def format_size(size, unit="mm"):

    return (
        " × ".join(format_number(v) for v in size)
        + " "
        + unit
    )


def today():

    return datetime.date.today().strftime("%d.%m.%Y")


# Emoji read well in a chat message and have no glyph at all in a
# drawing font, where they come out as hollow boxes.
EMOJI_RANGES = (
    (0x2139, 0x2139),
    (0x2190, 0x21FF),
    (0x2600, 0x27BF),
    (0x2B00, 0x2BFF),
    (0xFE00, 0xFE0F),
    (0x1F000, 0x1FAFF)
)


def plain(text):
    """Chat text made fit for a drawing sheet."""

    text = str(text)

    kept = []

    for character in text:

        code = ord(character)

        if any(low <= code <= high for low, high in EMOJI_RANGES):
            continue

        kept.append(character)

    return "".join(kept).strip()


# ============================================================
# CAMERAS
# ============================================================

# ============================================================
# PLAIN 2D GEOMETRY
#
# The markup needs these on both sides of the fence: in the venv
# for a DXF and inside freecadcmd for a solid, and neither can
# import the other side, so they live here with the rest of what
# is shared.
# ============================================================

def polyline_length(points):

    total = 0.0

    for i in range(len(points) - 1):
        total += math.hypot(
            points[i + 1][0] - points[i][0],
            points[i + 1][1] - points[i][1]
        )

    return total


def polygon_area(points):
    """Absolute shoelace area of a closed ring."""

    total = 0.0

    for i in range(len(points) - 1):

        x1, y1 = points[i][0], points[i][1]
        x2, y2 = points[i + 1][0], points[i + 1][1]

        total += x1 * y2 - x2 * y1

    return abs(total) / 2.0


def centroid(points):

    xs = [p[0] for p in points[:-1]]
    ys = [p[1] for p in points[:-1]]

    if not xs:
        return 0.0, 0.0

    return sum(xs) / len(xs), sum(ys) / len(ys)


def point_in_polygon(point, polygon):

    x, y = point[0], point[1]

    inside = False

    for i in range(len(polygon) - 1):

        x1, y1 = polygon[i][0], polygon[i][1]
        x2, y2 = polygon[i + 1][0], polygon[i + 1][1]

        if (y1 > y) != (y2 > y):

            t = (y - y1) / (y2 - y1)

            if x < x1 + t * (x2 - x1):
                inside = not inside

    return inside


def normalize(vector):

    vector = np.asarray(vector, dtype=np.float64)

    length = np.linalg.norm(vector)

    return vector / (length if length > 1e-12 else 1.0)


def camera_from_direction(direction, up=(0.0, 0.0, 1.0)):
    """Rows of the result are screen right, screen up and depth.

    `direction` points from the model toward the viewer, and depth
    grows toward the viewer, so a larger depth is nearer. The set
    is right-handed, which is what keeps the view from coming out
    mirrored — a mirrored part on a shop drawing is a scrapped part.
    """

    forward = normalize(direction)

    right = np.cross(np.asarray(up, dtype=np.float64), forward)

    # Looking straight along `up`: any perpendicular will do.
    if np.linalg.norm(right) < 1e-9:
        right = np.cross((0.0, 1.0, 0.0), forward)

    right = normalize(right)

    return np.array([right, np.cross(forward, right), forward])


# Viewed from the front, right and above, which is the isometric
# every mechanical CAD package opens with.
ISO_CAMERA = camera_from_direction((1.0, -1.0, 1.0))

FRONT_CAMERA = camera_from_direction((0.0, -1.0, 0.0))
RIGHT_CAMERA = camera_from_direction((1.0, 0.0, 0.0))
TOP_CAMERA = camera_from_direction((0.0, 0.0, 1.0))


def project(points, camera):
    """World points -> (screen u, screen v, depth)."""

    return np.asarray(points, dtype=np.float64) @ camera.T


def projected_extent(camera, size):
    """Screen width and height of an axis-aligned box."""

    size = np.abs(np.asarray(size, dtype=np.float64))

    return (
        float(np.abs(camera[0]) @ size),
        float(np.abs(camera[1]) @ size)
    )


def fitting_camera(size, width, height, standard_bonus=1.15):
    """The isometric that puts the most of the model on the sheet.

    A frame that is thin in Y, drawn with Z up, wastes two thirds
    of the page and shows its plates edge-on. Turning it so the
    thin direction runs across the sheet is what anyone would do
    with the model in their hands, so all three assignments are
    tried and the one that draws biggest wins. The familiar Z-up
    isometric carries a handicap, so an ordinary part is never
    turned for the sake of a few percent.
    """

    best = None

    for vertical in range(3):

        others = [axis for axis in range(3) if axis != vertical]

        direction = np.zeros(3)
        direction[others[0]] = 1.0
        direction[others[1]] = -1.0
        direction[vertical] = 1.0

        up = np.zeros(3)
        up[vertical] = 1.0

        camera = camera_from_direction(direction, up)

        span_x, span_y = projected_extent(camera, size)

        scale = min(
            width / max(span_x, 1e-9),
            height / max(span_y, 1e-9)
        )

        if vertical == 2:
            scale *= standard_bonus

        if best is None or scale > best[0]:
            best = (scale, camera)

    return best[1]


class Viewport:
    """Fits a projected cloud into a pixel box.

    Coordinates come out in final-image pixels; the rasterizer
    scales them up by the supersample factor itself, so one
    viewport serves both the geometry and the annotations.
    """

    def __init__(self, cam_points, box, margin=0.0):

        left, top, right, bottom = box

        cam_points = np.asarray(cam_points, dtype=np.float64)

        self.min_u = float(cam_points[:, 0].min())
        self.max_v = float(cam_points[:, 1].max())

        span_u = max(
            float(cam_points[:, 0].max()) - self.min_u,
            1e-9
        )

        span_v = max(
            self.max_v - float(cam_points[:, 1].min()),
            1e-9
        )

        usable_width = max(right - left - 2 * margin, 1.0)
        usable_height = max(bottom - top - 2 * margin, 1.0)

        self.scale = min(
            usable_width / span_u,
            usable_height / span_v
        )

        self.origin_x = (
            left
            + margin
            + (usable_width - span_u * self.scale) / 2.0
        )

        self.origin_y = (
            top
            + margin
            + (usable_height - span_v * self.scale) / 2.0
        )

    def __call__(self, cam):

        cam = np.asarray(cam, dtype=np.float64)

        return (
            self.origin_x + (cam[:, 0] - self.min_u) * self.scale,
            self.origin_y + (self.max_v - cam[:, 1]) * self.scale
        )

    def map(self, points, camera):

        return self(project(points, camera))

    def screen_points(self, points, camera):
        """Same, but as an (n, 2) array of pixel coordinates."""

        sx, sy = self.map(points, camera)

        return np.stack([sx, sy], axis=1)


# ============================================================
# SHADING
# ============================================================

SHADE_LEVELS = 64

# Camera-space lights, so the model keeps the same lighting from
# whatever direction it is viewed. Neither light points straight at
# the camera: a surface facing the viewer would then be the
# brightest thing on the sheet and read as white paper.
KEY_LIGHT = normalize((-0.50, 0.62, 0.60))
FILL_LIGHT = normalize((0.70, -0.10, 0.50))

AMBIENT = 0.30
KEY_STRENGTH = 0.55
FILL_STRENGTH = 0.16

# Slightly brighter midtones; flat shading without it looks muddy.
SHADE_GAMMA = 1.12


def build_ramp(shadow, light, levels=SHADE_LEVELS):
    """Colour ramp from the deepest shadow to the brightest face."""

    k = np.linspace(0.0, 1.0, levels)[:, None]

    shadow = np.asarray(shadow, dtype=np.float64)
    light = np.asarray(light, dtype=np.float64)

    return np.clip(
        shadow + (light - shadow) * k,
        0,
        255
    ).astype(np.uint8)


# Cool shadows and near-white highlights read as machined metal.
STEEL_RAMP = build_ramp((66, 78, 95), (240, 243, 247))
HIGHLIGHT_RAMP = build_ramp((128, 26, 26), (250, 198, 192))
CONTEXT_RAMP = build_ramp((172, 178, 189), (245, 246, 249))


def triangle_normals(points, faces):

    v0 = points[faces[:, 0]]

    normals = np.cross(
        points[faces[:, 1]] - v0,
        points[faces[:, 2]] - v0
    )

    lengths = np.linalg.norm(normals, axis=1)
    lengths[lengths < 1e-15] = 1.0

    return normals / lengths[:, None]


def triangle_areas(points, faces):

    v0 = points[faces[:, 0]]

    return 0.5 * np.linalg.norm(
        np.cross(
            points[faces[:, 1]] - v0,
            points[faces[:, 2]] - v0
        ),
        axis=1
    )


def shade(normals, camera, levels=SHADE_LEVELS):
    """Which faces point at us, and how brightly each is lit."""

    in_camera = normals @ camera.T

    front = in_camera[:, 2] > 0.0

    # An STL with reversed winding would otherwise render as an
    # empty page; almost nothing is front-facing only in that case.
    if front.sum() * 4 < len(front):
        in_camera = -in_camera
        front = in_camera[:, 2] > 0.0

    intensity = (
        AMBIENT
        + KEY_STRENGTH * np.maximum(in_camera @ KEY_LIGHT, 0.0)
        + FILL_STRENGTH * np.maximum(in_camera @ FILL_LIGHT, 0.0)
    )

    intensity = np.clip(intensity, 0.0, 1.0) ** (1.0 / SHADE_GAMMA)

    return front, np.clip(
        (intensity * (levels - 1)).astype(np.int64),
        0,
        levels - 1
    )


# ============================================================
# RASTERIZER
# ============================================================

def gradient_array(width, height, top, bottom):

    ramp = np.linspace(0.0, 1.0, height)[:, None]

    column = (
        np.asarray(top, dtype=np.float64) * (1.0 - ramp)
        + np.asarray(bottom, dtype=np.float64) * ramp
    )

    return np.repeat(
        column[:, None, :],
        width,
        axis=1
    ).astype(np.uint8)


def _erode(mask, radius):
    """Square erosion, separable, cheap enough for a big canvas."""

    result = mask

    for axis in (0, 1):

        shrunk = result

        for step in range(1, radius + 1):
            shrunk = (
                shrunk
                & np.roll(result, step, axis=axis)
                & np.roll(result, -step, axis=axis)
            )

        result = shrunk

    return result


def _split_segments(segments, step, budget):
    """Cuts screen-space segments into pieces of at most `step` px.

    Whole segments are the wrong unit for hiding lines: a model
    edge often arrives as a single segment hundreds of pixels long,
    and half of it can be behind another part.
    """

    length = np.hypot(
        segments[:, 3] - segments[:, 0],
        segments[:, 4] - segments[:, 1]
    )

    step = max(step, 1.0)

    while True:

        pieces = np.maximum(
            1,
            np.ceil(length / step)
        ).astype(np.int64)

        if pieces.sum() <= budget:
            break

        step *= 2.0

    if pieces.max() == 1:
        return segments

    parent = np.repeat(np.arange(len(segments)), pieces)

    starts = np.concatenate([[0], np.cumsum(pieces)[:-1]])

    within = np.arange(pieces.sum()) - np.repeat(starts, pieces)

    count = np.repeat(pieces, pieces).astype(np.float64)

    t0 = (within / count)[:, None]
    t1 = ((within + 1) / count)[:, None]

    head = segments[parent][:, 0:3]
    tail = segments[parent][:, 3:6]

    return np.concatenate(
        [
            head + (tail - head) * t0,
            head + (tail - head) * t1
        ],
        axis=1
    )


def _depth_planes(x, y, depth, faces, face_depth):
    """Screen-space depth plane of every triangle: (a, b, c).

    Depth at a pixel is a*column + b*row + c, which is exact for a
    flat triangle. The cheap alternative — one mean depth per
    triangle — puts a long oblique face tens of millimetres away
    from where it really is, and the edge visibility test then
    hides most of the model's edges.
    """

    a0 = faces[:, 0]
    a1 = faces[:, 1]
    a2 = faces[:, 2]

    e1x = x[a1] - x[a0]
    e1y = y[a1] - y[a0]
    e1d = depth[a1] - depth[a0]

    e2x = x[a2] - x[a0]
    e2y = y[a2] - y[a0]
    e2d = depth[a2] - depth[a0]

    nx = e1y * e2d - e1d * e2y
    ny = e1d * e2x - e1x * e2d
    nz = e1x * e2y - e1y * e2x

    slope_x = np.zeros(len(faces), dtype=np.float64)
    slope_y = np.zeros(len(faces), dtype=np.float64)
    offset = face_depth.astype(np.float64).copy()

    # Edge-on triangles have no gradient to solve for; their mean
    # depth is as good as it gets.
    solid = np.abs(nz) > 1e-9

    slope_x[solid] = -nx[solid] / nz[solid]
    slope_y[solid] = -ny[solid] / nz[solid]

    offset[solid] = (
        depth[a0][solid]
        - slope_x[solid] * x[a0][solid]
        - slope_y[solid] * y[a0][solid]
    )

    return slope_x, slope_y, offset


class Raster:
    """Supersampled shaded geometry with a per-pixel depth map.

    Meant to be used in this order: draw_mesh for every body, then
    contact_shadow and outline, then draw_edges, then flatten. The
    stages are separate because each one needs the finished result
    of the one before it.
    """

    def __init__(
        self,
        width,
        height,
        background=(BACKGROUND_TOP, BACKGROUND_BOTTOM),
        supersample=SUPERSAMPLE
    ):

        self.width = int(width)
        self.height = int(height)

        self.ss = max(1, int(supersample))

        self.w = self.width * self.ss
        self.h = self.height * self.ss

        if background is None:
            self.rgb = np.zeros((self.h, self.w, 3), dtype=np.uint8)

        elif isinstance(background[0], (tuple, list)):
            self.rgb = gradient_array(
                self.w,
                self.h,
                background[0],
                background[1]
            )

        else:
            self.rgb = np.empty((self.h, self.w, 3), dtype=np.uint8)
            self.rgb[:, :] = np.asarray(background, dtype=np.uint8)

        self.depth = np.zeros((self.h, self.w), dtype=np.float32)
        self.mask = np.zeros((self.h, self.w), dtype=bool)

        self.image = None

    def copy(self):
        """A rendered background that several sheets can reuse."""

        clone = Raster.__new__(Raster)

        clone.width = self.width
        clone.height = self.height
        clone.ss = self.ss
        clone.w = self.w
        clone.h = self.h

        clone.rgb = self.rgb.copy()
        clone.depth = self.depth.copy()
        clone.mask = self.mask.copy()

        clone.image = None

        return clone

    # --------------------------------------------------------

    def draw_mesh(
        self,
        points,
        faces,
        camera,
        viewport,
        ramp=STEEL_RAMP,
        normals=None
    ):
        """Rasterizes a triangle soup; the nearest surface wins.

        Triangles are stamped into an index image far-to-near, so
        the value left in each pixel identifies the triangle in
        front there — which gives both the colour and an exact
        depth map for the price of one rasterizer pass.
        """

        points = np.asarray(points, dtype=np.float64)
        faces = np.asarray(faces, dtype=np.int64)

        if len(faces) == 0:
            return 0

        if normals is None:
            normals = triangle_normals(points, faces)

        front, levels = shade(normals, camera)

        faces = faces[front]
        levels = levels[front]

        if len(faces) == 0:
            return 0

        cam = project(points, camera)

        sx, sy = viewport(cam)

        depth = cam[:, 2]

        face_depth = depth[faces].mean(axis=1)

        order = np.argsort(face_depth)

        faces = faces[order]
        levels = levels[order]
        face_depth = face_depth[order]

        x = sx * self.ss
        y = sy * self.ss

        plane = _depth_planes(x, y, depth, faces, face_depth)

        px = np.rint(x).astype(np.int64).tolist()
        py = np.rint(y).astype(np.int64).tolist()

        index = Image.new("I", (self.w, self.h), 0)

        pen = ImageDraw.Draw(index)

        a_list = faces[:, 0].tolist()
        b_list = faces[:, 1].tolist()
        c_list = faces[:, 2].tolist()

        for i in range(len(a_list)):

            a = a_list[i]
            b = b_list[i]
            c = c_list[i]

            slot = i + 1

            # outline=fill closes the seams left by rounding.
            pen.polygon(
                (
                    px[a], py[a],
                    px[b], py[b],
                    px[c], py[c]
                ),
                fill=slot,
                outline=slot
            )

        stamped = np.asarray(index)

        hit = stamped > 0

        if not hit.any():
            return 0

        rows, columns = np.nonzero(hit)

        slots = stamped[rows, columns] - 1

        self.rgb[rows, columns] = ramp[levels][slots]

        self.depth[rows, columns] = (
            plane[0][slots] * columns
            + plane[1][slots] * rows
            + plane[2][slots]
        )

        self.mask |= hit

        self.image = None

        return len(a_list)

    # --------------------------------------------------------

    def contact_shadow(
        self,
        strength=0.26,
        color=(80, 88, 104),
        radius=None,
        offset=None
    ):
        """A soft shadow of the silhouette, so nothing floats."""

        if not self.mask.any():
            return

        if radius is None:
            radius = max(4, int(0.009 * self.height * self.ss))

        if offset is None:
            offset = (
                max(1, int(0.004 * self.width * self.ss)),
                max(1, int(0.007 * self.height * self.ss))
            )

        blurred = Image.fromarray(
            (self.mask * 255).astype(np.uint8)
        ).filter(ImageFilter.GaussianBlur(radius))

        alpha = np.asarray(blurred).astype(np.float32) / 255.0

        shifted = np.zeros_like(alpha)

        dx, dy = int(offset[0]), int(offset[1])

        shifted[dy:, dx:] = alpha[
            : alpha.shape[0] - dy,
            : alpha.shape[1] - dx
        ]

        # Only the ground takes the shadow; the body keeps its own
        # shading.
        shifted[self.mask] = 0.0

        k = (shifted * strength)[:, :, None]

        self.rgb = (
            self.rgb * (1.0 - k)
            + np.asarray(color, dtype=np.float32) * k
        ).astype(np.uint8)

        self.image = None

    def outline(self, color=(34, 38, 44), width=None):
        """Heavy stroke around the silhouette and through holes.

        Tessellated cylinders have no model edge along their
        silhouette, so without this the body would fade into the
        page exactly where it should read as a hard boundary.
        """

        if not self.mask.any():
            return

        if width is None:
            width = self.ss + 1

        ring = self.mask & ~_erode(self.mask, int(width))

        self.rgb[ring] = np.asarray(color, dtype=np.uint8)

        self.image = None

    # --------------------------------------------------------

    def _ensure_image(self):

        if self.image is None:
            self.image = Image.fromarray(self.rgb, "RGB")

        return self.image

    def draw_edges(
        self,
        polylines,
        camera,
        viewport,
        color=LINE,
        width=None,
        tolerance=0.0,
        step=10.0,
        budget=500000
    ):
        """Draws the visible parts of polylines, hiding the rest.

        Every segment is cut into pieces of at most `step` final
        pixels and each piece is tested on its own, so an edge that
        runs behind another part is drawn up to the point where it
        disappears instead of all or nothing.

        `tolerance` is in model units and only covers the error of
        the depth map itself; making it generous instead is what
        lets edges show through a 2 mm plate.
        """

        gathered = []

        for line in polylines:

            line = np.asarray(line, dtype=np.float64)

            if len(line) < 2:
                continue

            cam = project(line, camera)

            sx, sy = viewport(cam)

            depth = cam[:, 2]

            gathered.append(
                np.stack(
                    [
                        sx[:-1] * self.ss, sy[:-1] * self.ss, depth[:-1],
                        sx[1:] * self.ss, sy[1:] * self.ss, depth[1:]
                    ],
                    axis=1
                )
            )

        if not gathered:
            return 0

        return self._draw_segments(
            np.concatenate(gathered),
            color=color,
            width=width,
            tolerance=tolerance,
            step=step,
            budget=budget
        )

    def draw_lines(
        self,
        starts,
        ends,
        camera,
        viewport,
        color=LINE,
        width=None,
        tolerance=0.0,
        step=10.0,
        budget=500000
    ):
        """draw_edges for loose segments given as two point arrays.

        Mesh feature edges arrive by the hundred thousand, and
        wrapping each one in its own little array first costs more
        than drawing them.
        """

        head = project(starts, camera)
        tail = project(ends, camera)

        head_x, head_y = viewport(head)
        tail_x, tail_y = viewport(tail)

        return self._draw_segments(
            np.stack(
                [
                    head_x * self.ss, head_y * self.ss, head[:, 2],
                    tail_x * self.ss, tail_y * self.ss, tail[:, 2]
                ],
                axis=1
            ),
            color=color,
            width=width,
            tolerance=tolerance,
            step=step,
            budget=budget
        )

    def _draw_segments(
        self,
        segments,
        color=LINE,
        width=None,
        tolerance=0.0,
        step=10.0,
        budget=500000
    ):

        segments = _split_segments(
            segments,
            step * self.ss,
            budget
        )

        mx = np.rint(
            (segments[:, 0] + segments[:, 3]) / 2.0
        ).astype(np.int64)

        my = np.rint(
            (segments[:, 1] + segments[:, 4]) / 2.0
        ).astype(np.int64)

        inside = (
            (mx >= 0)
            & (my >= 0)
            & (mx < self.w)
            & (my < self.h)
        )

        own = (segments[:, 2] + segments[:, 5]) / 2.0

        surface = np.zeros(len(segments), dtype=np.float64)
        covered = np.zeros(len(segments), dtype=bool)

        surface[inside] = self.depth[my[inside], mx[inside]]
        covered[inside] = self.mask[my[inside], mx[inside]]

        keep = inside & (~covered | (own >= surface - tolerance))

        pen = ImageDraw.Draw(self._ensure_image())

        if width is None:
            width = self.ss

        drawn = segments[keep]

        for row in drawn.tolist():

            pen.line(
                [
                    (row[0], row[1]),
                    (row[3], row[4])
                ],
                fill=color,
                width=width
            )

        return len(drawn)

    def visible(self, screen, depths, tolerance=0.0):
        """Which of these points the surface does not hide.

        Used for hole markers: without it every hole on the far
        side of the part is marked too, and a perforated assembly
        turns into a rash of rings.
        """

        screen = np.asarray(screen, dtype=np.float64)

        columns = np.rint(screen[:, 0] * self.ss).astype(np.int64)
        rows = np.rint(screen[:, 1] * self.ss).astype(np.int64)

        inside = (
            (columns >= 0)
            & (rows >= 0)
            & (columns < self.w)
            & (rows < self.h)
        )

        surface = np.zeros(len(screen), dtype=np.float64)
        covered = np.zeros(len(screen), dtype=bool)

        surface[inside] = self.depth[rows[inside], columns[inside]]
        covered[inside] = self.mask[rows[inside], columns[inside]]

        return inside & (
            ~covered
            | (np.asarray(depths, dtype=np.float64) >= surface - tolerance)
        )

    def flatten(self):
        """The finished geometry layer at its final size."""

        image = self._ensure_image()

        if self.ss == 1:
            return image

        return image.resize(
            (self.width, self.height),
            Image.Resampling.LANCZOS
        )


# ============================================================
# ORIENTATION
# ============================================================

def _tightest_angle(flat, angles):
    """The angle among `angles` giving the smallest bounding area."""

    cos = np.cos(angles)[:, None]
    sin = np.sin(angles)[:, None]

    x = flat[:, 0][None, :]
    y = flat[:, 1][None, :]

    u = x * cos + y * sin
    v = -x * sin + y * cos

    area = (
        (u.max(axis=1) - u.min(axis=1))
        * (v.max(axis=1) - v.min(axis=1))
    )

    return float(angles[int(np.argmin(area))])


def _plane_sweep(flat, extra=(), steps=45):
    """Rotation of the tightest rectangle around a 2D cloud.

    The exact answer is nearly always one of `extra` — the side
    faces of the part, projected into this plane — so those are
    tried alongside the sweep. A sweep alone lands a fraction of a
    degree off, which on a metre-long part is a millimetre of lie
    on the drawing.
    """

    if len(flat) > 20000:
        flat = flat[:: max(1, len(flat) // 20000)]

    step = 90.0 / steps

    candidates = np.arange(steps) * step

    if len(extra):
        candidates = np.concatenate([
            candidates,
            np.asarray(extra, dtype=np.float64) % 90.0
        ])

    best = _tightest_angle(flat, np.radians(candidates))

    return _tightest_angle(
        flat,
        best + np.radians(np.linspace(-step, step, 41))
    )


def dominant_axes(points, faces, limit=5):
    """Face normals that carry the most area, biggest first.

    Fabricated parts are mostly flat-sided, so a part's own axes
    are the normals of its large faces. Normals are folded onto one
    hemisphere and quantized, which groups the two sides of a plate
    into a single very heavy direction; the direction reported back
    is the area-weighted mean inside the group, not the rounded
    key, so it stays exact.
    """

    if faces is None or len(faces) == 0:
        return []

    normals = triangle_normals(points, faces)
    areas = triangle_areas(points, faces)

    leading = np.argmax(np.abs(normals), axis=1)

    sign = np.sign(
        normals[np.arange(len(normals)), leading]
    )
    sign[sign == 0] = 1.0

    normals = normals * sign[:, None]

    # 0.01 is about 0.6 deg, fine enough to keep real faces apart.
    keys, inverse = np.unique(
        np.rint(normals * 100.0).astype(np.int32),
        axis=0,
        return_inverse=True
    )

    inverse = np.asarray(inverse).reshape(-1)

    weight = np.bincount(
        inverse,
        weights=areas,
        minlength=len(keys)
    )

    total = weight.sum()

    if total <= 0.0:
        return []

    mean = np.stack(
        [
            np.bincount(
                inverse,
                weights=normals[:, axis] * areas,
                minlength=len(keys)
            )
            for axis in range(3)
        ],
        axis=1
    )

    axes = []

    for index in np.argsort(-weight)[:limit]:

        if weight[index] < 0.02 * total:
            break

        axes.append(normalize(mean[index]))

    return axes


def oriented_frame(points, faces=None):
    """The part's own axes, longest first, thinnest last.

    A part that sits at an angle inside an assembly is still drawn
    square to the sheet, and the size printed on that sheet is the
    size the shop actually has to cut. The model axes are a
    candidate too, and they win ties, so a part that is already
    square is left exactly as it was modelled.

    Returns (rotation, extents, centre): rotation @ (p - centre)
    puts a point into the part frame.
    """

    points = np.asarray(points, dtype=np.float64)

    centre = (points.min(axis=0) + points.max(axis=0)) / 2.0

    local = points - centre

    candidates = [np.eye(3)]

    axes = dominant_axes(local, faces)

    for number, axis in enumerate(axes):

        # Any pair perpendicular to the face normal will do as a
        # starting basis; the sweep finds the real orientation.
        helper = (
            np.array([0.0, 0.0, 1.0])
            if abs(axis[2]) < 0.9
            else np.array([1.0, 0.0, 0.0])
        )

        first = normalize(np.cross(helper, axis))
        second = np.cross(axis, first)

        flat = np.stack(
            [local @ first, local @ second],
            axis=1
        )

        # The other big faces of the part are already square to it,
        # so their directions in this plane are the exact answers
        # the sweep is looking for.
        hints = []

        for other in axes[:number] + axes[number + 1:]:

            planar = other - axis * float(other @ axis)

            if np.linalg.norm(planar) < 0.1:
                continue

            hints.append(
                math.degrees(
                    math.atan2(
                        float(planar @ second),
                        float(planar @ first)
                    )
                )
            )

        angle = _plane_sweep(flat, hints)

        cos = math.cos(angle)
        sin = math.sin(angle)

        candidates.append(
            np.array([
                first * cos + second * sin,
                -first * sin + second * cos,
                axis
            ])
        )

    best = None

    for number, rotation in enumerate(candidates):

        projected = local @ rotation.T

        extents = projected.max(axis=0) - projected.min(axis=0)

        volume = float(np.prod(np.maximum(extents, 1e-9)))

        # The model axes only lose to a clearly tighter box, so a
        # square part is never nudged by half a degree.
        if number > 0:
            volume *= 1.02

        if best is None or volume < best[0]:
            best = (volume, rotation, extents)

    rotation = best[1]

    order = np.argsort(-best[2])

    rotation = rotation[order]

    # A left-handed frame would mirror the part on the sheet.
    if np.linalg.det(rotation) < 0.0:
        rotation[2] = -rotation[2]

    projected = local @ rotation.T

    extents = projected.max(axis=0) - projected.min(axis=0)

    return rotation, extents, centre


def to_frame(points, rotation, centre):

    return (np.asarray(points, dtype=np.float64) - centre) @ rotation.T


def view_axis(points, faces, rotation):
    """Which axis of the frame the part shows the most of.

    Looking along the thinnest side of the bounding box is right
    for a plate and wrong for a rolled band, whose thinnest side is
    its height: the box says nothing about how much of the part is
    actually facing you, and the band comes out as a hairline arc.
    The shadow it casts along each axis does say it — for a closed
    body that is half the sum of |n·d| over the face areas.
    """

    if faces is None or len(faces) == 0:
        return 2

    normals = triangle_normals(points, faces)
    areas = triangle_areas(points, faces)

    shadow = (np.abs(rotation @ normals.T) * areas).sum(axis=1)

    return int(np.argmax(shadow))


def reordered_frame(rotation, extents, axis):
    """Puts `axis` last, as the view direction, and the longer of
    the other two first, so the part lies across the sheet.

    A permutation can leave the frame left-handed, which would draw
    the part mirrored; flipping the view direction fixes that and
    only means looking at the part from the other side.
    """

    others = [a for a in range(3) if a != axis]

    if extents[others[0]] < extents[others[1]]:
        others.reverse()

    order = others + [axis]

    rotation = rotation[order].copy()
    extents = extents[order].copy()

    if np.linalg.det(rotation) < 0.0:
        rotation[2] = -rotation[2]

    return rotation, extents


# ============================================================
# SHEET FURNITURE
# ============================================================

def sheet(width=PAGE_WIDTH, height=PAGE_HEIGHT):

    return Image.fromarray(
        gradient_array(
            width,
            height,
            BACKGROUND_TOP,
            BACKGROUND_BOTTOM
        ),
        "RGB"
    )


def frame(image):
    """The paper edge and the heavy border with its binding margin."""

    pen = ImageDraw.Draw(image)

    width, height = image.size

    pen.rectangle(
        (
            EDGE_INSET,
            EDGE_INSET,
            width - EDGE_INSET,
            height - EDGE_INSET
        ),
        outline=EDGE_LINE,
        width=1
    )

    pen.rectangle(
        (
            BORDER_LEFT,
            BORDER_INSET,
            width - BORDER_INSET,
            height - BORDER_INSET
        ),
        outline=BORDER_LINE,
        width=3
    )


def header(image, title, subtitle=None, note=None):
    """Sheet title, top left, with an optional note on the right."""

    pen = ImageDraw.Draw(image)

    pen.text(
        (CONTENT_LEFT, CONTENT_TOP),
        plain(title),
        fill=INK,
        font=font(31, "bold")
    )

    if subtitle:
        pen.text(
            (CONTENT_LEFT, CONTENT_TOP + 44),
            plain(subtitle),
            fill=MUTED,
            font=font(21)
        )

    if note:

        note_font = font(21)

        note = plain(note)

        pen.text(
            (
                CONTENT_RIGHT - text_width(note, note_font),
                CONTENT_TOP + 8
            ),
            note,
            fill=MUTED,
            font=note_font
        )


def panel(image, rect, fill=PANEL_FILL, border=PANEL_BORDER):

    ImageDraw.Draw(image).rectangle(
        rect,
        fill=fill,
        outline=border,
        width=1
    )


def panel_caption(image, rect, text):

    ImageDraw.Draw(image).text(
        (rect[0] + 4, rect[1] - 30),
        plain(text),
        fill=MUTED,
        font=font(20)
    )


TITLE_HEAD_HEIGHT = 56
TITLE_ROW_HEIGHT = 44
TITLE_LABEL_WIDTH = 176


def title_block(
    image,
    rows,
    anchor,
    width=706,
    brand="ForgeMind",
    tag=None
):
    """The block in the bottom-right corner of a drawing sheet.

    `rows` are (label, value) pairs and the block grows upward from
    the anchor, so callers only place its corner.
    """

    pen = ImageDraw.Draw(image)

    right, bottom = anchor

    height = TITLE_HEAD_HEIGHT + TITLE_ROW_HEIGHT * len(rows)

    left = right - width
    top = bottom - height

    pen.rectangle(
        (left, top, right, bottom),
        fill=PANEL_FILL,
        outline=BORDER_LINE,
        width=2
    )

    pen.rectangle(
        (left, top, right, top + TITLE_HEAD_HEIGHT),
        fill=PANEL_HEADER,
        outline=BORDER_LINE,
        width=1
    )

    pen.text(
        (left + 16, top + 12),
        brand,
        fill=INK,
        font=font(28, "bold")
    )

    if tag:

        tag_font = font(21, "drawing")

        pen.text(
            (
                right - 16 - text_width(tag, tag_font),
                top + 18
            ),
            tag,
            fill=MUTED,
            font=tag_font
        )

    label_font = font(19)
    value_font = font(22, "drawing")

    y = top + TITLE_HEAD_HEIGHT

    for label, value in rows:

        pen.line(
            [(left, y), (right, y)],
            fill=PANEL_BORDER,
            width=1
        )

        pen.text(
            (left + 16, y + 12),
            plain(label),
            fill=MUTED,
            font=label_font
        )

        pen.text(
            (left + TITLE_LABEL_WIDTH, y + 9),
            plain(value),
            fill=INK,
            font=value_font
        )

        y += TITLE_ROW_HEIGHT

    pen.line(
        [
            (left + TITLE_LABEL_WIDTH - 14, top + TITLE_HEAD_HEIGHT),
            (left + TITLE_LABEL_WIDTH - 14, bottom)
        ],
        fill=PANEL_BORDER,
        width=1
    )

    return (left, top, right, bottom)


def table(image, rect, heading, rows, columns=1, note=None):
    """Bordered list of (left, right) pairs, e.g. a hole schedule."""

    pen = ImageDraw.Draw(image)

    left, top, right, bottom = rect

    pen.rectangle(rect, fill=PANEL_FILL, outline=BORDER_LINE, width=2)

    pen.rectangle(
        (left, top, right, top + 46),
        fill=PANEL_HEADER,
        outline=BORDER_LINE,
        width=1
    )

    pen.text(
        (left + 16, top + 12),
        plain(heading),
        fill=INK,
        font=font(22, "bold")
    )

    row_font = font(22, "drawing")
    count_font = font(21, "drawing")

    if not rows:

        pen.text(
            (left + 16, top + 62),
            plain(note or ""),
            fill=MUTED,
            font=font(21)
        )

        return

    per_column = int(math.ceil(len(rows) / float(columns)))

    column_width = (right - left) / float(columns)

    # The note keeps its own line at the bottom of the panel.
    limit = bottom - (38 if note else 6)

    for index, row in enumerate(rows):

        column = index // per_column
        line = index % per_column

        x = left + column * column_width + 16
        y = top + 58 + line * 34

        if y + 30 > limit:
            break

        pen.text(
            (x, y),
            plain(row[0]),
            fill=INK,
            font=row_font
        )

        if len(row) > 1 and row[1]:

            value = plain(row[1])

            pen.text(
                (
                    left + (column + 1) * column_width
                    - 18
                    - text_width(value, count_font),
                    y
                ),
                value,
                fill=MUTED,
                font=count_font
            )

    if note:

        pen.text(
            (left + 16, bottom - 34),
            plain(note),
            fill=MUTED,
            font=font(19)
        )


# ============================================================
# DIMENSIONS
# ============================================================

DIMENSION_COLOR = (28, 30, 34)

DIMENSION_GAP = 9
DIMENSION_OFFSET = 46
DIMENSION_OVERSHOOT = 12

ARROW_LENGTH = 16
ARROW_HALF_WIDTH = 4.5

# Below this the arrows no longer fit between the extension lines.
SHORT_DIMENSION = 58


def _xy(point):
    """PIL wants plain floats, not numpy scalars."""

    return (float(point[0]), float(point[1]))


def _arrow(pen, tip, direction, color=DIMENSION_COLOR):

    tip = _xy(tip)

    dx = float(direction[0])
    dy = float(direction[1])

    base = (
        tip[0] - dx * ARROW_LENGTH,
        tip[1] - dy * ARROW_LENGTH
    )

    px = -dy * ARROW_HALF_WIDTH
    py = dx * ARROW_HALF_WIDTH

    pen.polygon(
        [
            tip,
            (base[0] + px, base[1] + py),
            (base[0] - px, base[1] - py)
        ],
        fill=color
    )


def text_patch(text, chosen_font, fill, halo=None):
    """Text on its own transparent patch, ready to be rotated.

    `halo` paints the same text underneath in that colour and a
    little wider, which is what keeps a value readable where it
    has to sit over the drawing rather than beside it.
    """

    box = chosen_font.getbbox(text)

    edge = 4 + (3 if halo else 0)

    patch = Image.new(
        "RGBA",
        (
            max(1, box[2] - box[0] + 2 * edge),
            max(1, box[3] - box[1] + 2 * edge)
        ),
        (0, 0, 0, 0)
    )

    ImageDraw.Draw(patch).text(
        (edge - box[0], edge - box[1]),
        text,
        font=chosen_font,
        fill=fill,
        stroke_width=3 if halo else 0,
        stroke_fill=halo
    )

    return patch


def paste_rotated(image, patch, centre, angle):

    if abs(angle) > 0.5:
        patch = patch.rotate(
            angle,
            expand=True,
            resample=Image.BICUBIC
        )

    image.paste(
        patch,
        (
            int(round(centre[0] - patch.width / 2.0)),
            int(round(centre[1] - patch.height / 2.0))
        ),
        patch
    )


def dimension(
    image,
    start,
    end,
    text,
    side,
    offset=DIMENSION_OFFSET,
    size=24,
    color=DIMENSION_COLOR,
    beside=False
):
    """One dimension: extension lines, arrows and an aligned value.

    `side` is a screen vector pointing away from the part; the
    dimension line is laid parallel to start->end at `offset`
    pixels along it, and the value sits on the far side of the
    line, aligned with it, the way a drawing has it.
    """

    pen = ImageDraw.Draw(image)

    start = np.asarray(start, dtype=np.float64)
    end = np.asarray(end, dtype=np.float64)

    span = end - start

    length = float(np.linalg.norm(span))

    if length < 1e-6:
        return

    direction = span / length

    side = np.asarray(side, dtype=np.float64)

    perpendicular = np.array([-direction[1], direction[0]])

    if perpendicular @ side < 0.0:
        perpendicular = -perpendicular

    a = start + perpendicular * offset
    b = end + perpendicular * offset

    for corner, point in ((start, a), (end, b)):

        pen.line(
            [
                _xy(corner + perpendicular * DIMENSION_GAP),
                _xy(point + perpendicular * DIMENSION_OVERSHOOT)
            ],
            fill=color,
            width=1
        )

    pen.line([_xy(a), _xy(b)], fill=color, width=1)

    if length >= SHORT_DIMENSION:

        _arrow(pen, a, (-direction[0], -direction[1]), color)
        _arrow(pen, b, (direction[0], direction[1]), color)

    else:

        # No room inside: arrows come in from the outside, as GOST
        # allows for a narrow feature.
        outside = direction * (ARROW_LENGTH + 6)

        pen.line(
            [_xy(a - outside), _xy(b + outside)],
            fill=color,
            width=1
        )

        _arrow(pen, a, (direction[0], direction[1]), color)
        _arrow(pen, b, (-direction[0], -direction[1]), color)

    patch = text_patch(text, font(size, "drawing"), color)

    angle = math.degrees(math.atan2(-direction[1], direction[0]))

    # Keep the value readable rather than upside down.
    if angle > 90.0:
        angle -= 180.0
    elif angle < -90.0:
        angle += 180.0

    # The patch is rotated to run along the dimension line, so what
    # has to clear the line is its height and what has to clear the
    # arrow is its width, whatever the angle. Measuring the rotated
    # bounding box instead put every vertical value a full step out
    # from its own line and straight through the next one along.
    across = 0.5 * patch.height + 7.0
    along = 0.5 * patch.width + 7.0

    # A short span normally throws its value out past the arrow,
    # where there is room for it. In a chain of them that room
    # belongs to the next value along, so `beside` keeps every
    # value over the middle of what it measures and lets the
    # caller step the crowded ones out to another line instead.
    if length < SHORT_DIMENSION and not beside:
        centre = b + direction * (along + ARROW_LENGTH + 10)
    else:
        centre = (a + b) / 2.0 + perpendicular * across

    paste_rotated(image, patch, centre, angle)


def angle_marker(
    image,
    vertex,
    first,
    second,
    text,
    radius=58,
    size=22,
    color=DIMENSION_COLOR,
    halo=None
):
    """The angle between two runs: an arc with the value outside it.

    A bend is the one thing a bar drawing cannot leave out, and it
    is not a length, so it gets the arc rather than a chain.
    """

    pen = ImageDraw.Draw(image)

    vertex = np.asarray(vertex, dtype=np.float64)

    a = np.asarray(first, dtype=np.float64) - vertex
    b = np.asarray(second, dtype=np.float64) - vertex

    length_a = float(np.linalg.norm(a))
    length_b = float(np.linalg.norm(b))

    if length_a < 1e-6 or length_b < 1e-6:
        return

    a = a / length_a
    b = b / length_b

    start = math.degrees(math.atan2(a[1], a[0]))
    end = math.degrees(math.atan2(b[1], b[0]))

    # PIL sweeps clockwise from start; the interior angle is the
    # short way round.
    if (end - start) % 360.0 > 180.0:
        start, end = end, start

    pen.arc(
        (
            vertex[0] - radius,
            vertex[1] - radius,
            vertex[0] + radius,
            vertex[1] + radius
        ),
        start,
        end,
        fill=color,
        width=1
    )

    bisector = a + b

    length = float(np.linalg.norm(bisector))

    if length < 1e-6:
        # A straight joint has no side to put the value on.
        bisector = np.array([-a[1], a[0]])
    else:
        bisector = bisector / length

    patch = text_patch(text, font(size, "drawing"), color, halo)

    paste_rotated(
        image,
        patch,
        vertex + bisector * (radius + 28.0),
        0.0
    )


# Corner index is 4*x + 2*y + z, so the edges along each axis are
# the pairs that differ in exactly that bit.
BOX_EDGES = (
    ((0, 4), (1, 5), (2, 6), (3, 7)),
    ((0, 2), (1, 3), (4, 6), (5, 7)),
    ((0, 1), (2, 3), (4, 5), (6, 7))
)


def box_corners(low, high):

    low = np.asarray(low, dtype=np.float64)
    high = np.asarray(high, dtype=np.float64)

    corners = []

    for x in (low[0], high[0]):
        for y in (low[1], high[1]):
            for z in (low[2], high[2]):
                corners.append((x, y, z))

    return np.array(corners)


def box_dimensions(
    image,
    screen,
    labels,
    axes=(0, 1, 2),
    offset=DIMENSION_OFFSET,
    size=24
):
    """Overall dimensions along the projected box edges.

    For each axis the outermost of the four parallel edges is
    dimensioned, with a nudge toward the lower side of the view, so
    an isometric ends up dimensioned the way a draughtsman would do
    it: width and depth below, height up the side.
    """

    screen = np.asarray(screen, dtype=np.float64)

    centre = screen.mean(axis=0)

    for axis in axes:

        label = labels[axis]

        if not label:
            continue

        best = None

        for i, j in BOX_EDGES[axis]:

            span = screen[j] - screen[i]

            length = float(np.linalg.norm(span))

            if length < 1e-6:
                continue

            perpendicular = np.array([-span[1], span[0]]) / length

            away = (screen[i] + screen[j]) / 2.0 - centre

            reach = float(perpendicular @ away)

            side = perpendicular if reach > 0 else -perpendicular

            # Ties are common on a symmetric box; prefer the edge
            # whose dimension lands below the view.
            score = abs(reach) * (1.0 + 0.06 * side[1])

            if best is None or score > best[0]:
                best = (score, i, j, side)

        if best is None:
            continue

        dimension(
            image,
            screen[best[1]],
            screen[best[2]],
            label,
            best[3],
            offset=offset,
            size=size
        )


# ============================================================
# MARKERS
# ============================================================

def hole_markers(
    image,
    centres,
    radii,
    numbers=None,
    color=ACCENT,
    minimum_radius=5.0,
    width=2
):
    """Thin rings on the holes, at the size the holes really are.

    Filled dots hide the very feature they point at, and a big
    fixed marker turns a perforated plate into a rash, so the ring
    is drawn at the projected radius and only grows when a hole is
    too small to see.
    """

    pen = ImageDraw.Draw(image)

    label_font = font(19, "bold")

    for index, (centre, radius) in enumerate(zip(centres, radii)):

        x, y = float(centre[0]), float(centre[1])

        r = max(float(radius), minimum_radius)

        pen.ellipse(
            (x - r, y - r, x + r, y + r),
            outline=color,
            width=width
        )

        if r > 9.0:

            pen.line(
                [(x - r * 0.45, y), (x + r * 0.45, y)],
                fill=color,
                width=1
            )

            pen.line(
                [(x, y - r * 0.45), (x, y + r * 0.45)],
                fill=color,
                width=1
            )

        if numbers is None:
            continue

        # Clear of the ring, whatever the ring's size.
        away = max(r, 8.0) * 0.75

        pen.text(
            (x + away + 4, y - away - 18),
            str(numbers[index]),
            fill=color,
            font=label_font,
            stroke_width=3,
            stroke_fill=(255, 255, 255)
        )


AXIS_COLORS = (
    (192, 74, 74),
    (86, 148, 92),
    (74, 108, 188)
)


def axis_triad(image, camera, centre, size=52, labels=("X", "Y", "Z")):
    """A small XYZ marker, so the view direction is never a guess."""

    pen = ImageDraw.Draw(image)

    label_font = font(19, "bold")

    for axis in range(3):

        world = np.zeros(3)
        world[axis] = 1.0

        screen = camera @ world

        # Screen y grows downward.
        tip = (
            float(centre[0] + screen[0] * size),
            float(centre[1] - screen[1] * size)
        )

        pen.line(
            [_xy(centre), tip],
            fill=AXIS_COLORS[axis],
            width=3
        )

        direction = np.array([
            screen[0],
            -screen[1]
        ])

        length = float(np.linalg.norm(direction))

        if length > 1e-6:
            _arrow(
                pen,
                tip,
                tuple(direction / length),
                AXIS_COLORS[axis]
            )

        text = labels[axis]

        pen.text(
            (
                tip[0] + direction[0] / max(length, 1e-6) * 14 - 6,
                tip[1] + direction[1] / max(length, 1e-6) * 14 - 11
            ),
            text,
            fill=AXIS_COLORS[axis],
            font=label_font,
            stroke_width=3,
            stroke_fill=(255, 255, 255)
        )
