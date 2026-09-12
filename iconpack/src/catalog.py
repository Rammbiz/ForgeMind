"""Which apps the pack themes, how each one looks, and what it maps to.

An entry carries three things: the card treatment, the mark, and the component
names a launcher will ask about.  Where a package's launcher activity is not
known for certain, a few conventional patterns are emitted alongside it - a
component that does not exist simply never matches, while a hit means the app
gets its bespoke tile instead of the generic fallback.
"""


class App:
    __slots__ = ("slug", "name", "card", "glyph", "packages", "components", "scale", "fg", "dy", "tags")

    def __init__(self, slug, name, card, glyph, packages=(), components=(),
                 scale=0.56, fg="#FFFFFF", dy=0, tags=()):
        self.slug = slug
        self.name = name
        self.card = card
        self.glyph = glyph
        self.packages = tuple(packages)
        self.components = tuple(components)
        self.scale = scale
        self.fg = fg
        self.dy = dy
        self.tags = tuple(tags)


# card constructors -------------------------------------------------------- #

def brand(color):
    return ("brand", color, None)


def brand_glow(color, glow):
    return ("brand", color, glow)


def graphite(glow=None):
    return ("graphite", None, glow)


def porcelain(glow=None):
    return ("porcelain", None, glow)


# glyph constructors ------------------------------------------------------- #

def M(name):
    """A drawn mark."""
    return ("mark", name, {})


def T(text, face="geo", tracking=-0.03, width=0.86, height=0.56):
    """A letter mark."""
    return ("text", text, {"face": face, "tracking": tracking, "width": width, "height": height})


# component patterns for packages whose launcher activity we do not pin down
ACTIVITY_PATTERNS = (
    "{pkg}.MainActivity",
    "{pkg}.ui.MainActivity",
    "{pkg}.SplashActivity",
    "{pkg}.ui.main.MainActivity",
    "{pkg}.activity.MainActivity",
)


def components_for(app):
    """Every ComponentInfo string this app should claim, de-duplicated."""
    out = []
    seen = set()

    def add(comp):
        if comp not in seen:
            seen.add(comp)
            out.append(comp)

    for comp in app.components:
        add(comp)
    for pkg in app.packages:
        for pattern in ACTIVITY_PATTERNS:
            add("%s/%s" % (pkg, pattern.format(pkg=pkg)))
    return out


def load():
    """All apps, in display order."""
    from apps_ua import APPS as UA
    from apps_world import APPS as WORLD
    from apps_system import APPS as SYSTEM

    apps = list(UA) + list(WORLD) + list(SYSTEM)
    seen = {}
    for a in apps:
        if a.slug in seen:
            raise ValueError("duplicate slug: %s" % a.slug)
        seen[a.slug] = a
    return apps
