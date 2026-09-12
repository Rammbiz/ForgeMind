"""Vector marks, drawn in a 100x100 box.

Each entry is a callable returning an SVG fragment.  `{fg}` is substituted with
the mark colour (white on brand cards), so a single drawing serves both the
brand-coloured and the graphite treatments.  Marks are recreations built from
primitives - close enough to be recognised on a home screen at 48dp, drawn
here rather than taken from anyone's asset kit.
"""

MARKS = {}


def mark(name):
    def deco(fn):
        MARKS[name] = fn
        return fn
    return deco


# --------------------------------------------------------------------------- #
# messengers
# --------------------------------------------------------------------------- #

@mark("telegram")
def _telegram():
    return (
        '<path d="M6 46.5 L95 10 L80.5 90 L49.5 66 L35.5 81.5 L35.5 59.5 Z" fill="{fg}"/>'
        '<path d="M35.5 59.5 L84 22 L49.5 66 Z" fill="{fg}" opacity="0.55"/>'
    )


@mark("handset")
def _handset():
    return (
        '<path d="M20.5 16.5c3-3.5 8.4-3.6 11.5-.2l9.2 10c2.7 3 2.7 7.5 0 10.4l-5.3 5.8'
        'c-.9 1-1.1 2.4-.5 3.6 3.6 7.2 9.4 13.1 16.5 16.8 1.2.6 2.6.4 3.5-.6l5.6-5.9'
        'c2.9-3 7.7-3 10.6 0l9.6 9.9c3.3 3.4 3.2 8.9-.3 12.1-8 7.5-20.3 7.8-30.6 2.4'
        'C33.9 71.8 19 55.6 14.6 39.1c-2.3-8.6.2-17.1 5.9-22.6Z" fill="{fg}"/>'
    )


@mark("whatsapp")
def _whatsapp():
    return (
        '<path d="M50 8c23.2 0 42 18.4 42 41 0 22.6-18.8 41-42 41-7.3 0-14.2-1.8-20.2-5'
        'L8 92l7.4-21.2C11.3 64.5 8 57.1 8 49 8 26.4 26.8 8 50 8Z" fill="{fg}"/>'
        '<path d="M37.4 30.5c1.2-.1 2.3.4 2.9 1.6l4 8.2c.6 1.2.4 2.6-.5 3.6l-2.8 3'
        'c-.6.7-.8 1.6-.4 2.4 2.6 5.1 6.7 9.2 11.8 11.8.8.4 1.8.2 2.4-.5l3-3.2'
        'c1-1 2.5-1.3 3.7-.6l8.2 4.2c1.3.7 1.8 2.3 1.1 3.5-2.5 4.6-7.7 7-13 6'
        'C43.6 68.2 31 55.6 27.6 40.6c-1-5.2 1.4-10.3 6-12.8.5-.3 1-.4 1.5-.4Z" fill="#000" opacity="0"/>'
        '<path d="M37.4 30.5c1.2-.1 2.3.4 2.9 1.6l4 8.2c.6 1.2.4 2.6-.5 3.6l-2.8 3'
        'c-.6.7-.8 1.6-.4 2.4 2.6 5.1 6.7 9.2 11.8 11.8.8.4 1.8.2 2.4-.5l3-3.2'
        'c1-1 2.5-1.3 3.7-.6l8.2 4.2c1.3.7 1.8 2.3 1.1 3.5-2.5 4.6-7.7 7-13 6'
        'C43.6 68.2 31 55.6 27.6 40.6c-1-5.2 1.4-10.3 6-12.8.5-.3 1-.4 1.5-.4Z" fill="{bg}"/>'
    )


@mark("viber")
def _viber():
    return (
        '<path d="M50 6c19.5 0 33 11.4 35.6 27.6 2 12.5.4 23.6-3.9 31.7-3 5.6-7.4 9-12.3 10.7'
        'l.2 12.6c0 2.5-2.9 3.8-4.7 2.1l-9.8-9.3c-1.7.1-3.4.2-5.1.2C30.5 81.6 17 70.2 14.4 54'
        'c-2-12.5-.4-23.6 3.9-31.7C23.1 12.6 34.5 6 50 6Z" fill="{fg}"/>'
        '<path d="M37.8 28.2c1-.2 2 .2 2.6 1.1l4.3 6.8c.7 1.1.5 2.5-.4 3.4l-2 1.9'
        'c-.6.6-.8 1.5-.5 2.3 2 5 5.9 9 10.8 11.2.8.4 1.7.2 2.3-.4l2-2.1c.9-.9 2.3-1.1 3.4-.5'
        'l7 4c1.1.6 1.5 2 .9 3.1-2.2 4-6.7 6-11.2 5-12.5-2.8-22.3-12.6-25-25.1-1-4.4.9-8.9 4.8-10.6'
        '.3-.1.6-.2 1-.1Z" fill="{bg}"/>'
        '<path d="M56 22c9.8 1 17.4 8.6 18.4 18.4" fill="none" stroke="{bg}" stroke-width="4.2" stroke-linecap="round"/>'
        '<path d="M55 32.5c5.1.9 9.1 4.9 10 10" fill="none" stroke="{bg}" stroke-width="4.2" stroke-linecap="round"/>'
    )


@mark("signal")
def _signal():
    return (
        '<path d="M50 10c22.6 0 41 16.4 41 36.6 0 20.2-18.4 36.6-41 36.6-4 0-7.9-.5-11.6-1.5'
        'L18 90l4.6-15.4C14 68 9 57.9 9 46.6 9 26.4 27.4 10 50 10Z" fill="{fg}"/>'
    )


@mark("messenger")
def _messenger():
    return (
        '<path d="M50 8C26.8 8 9 25.3 9 47.2c0 12.3 5.6 23.2 14.5 30.4V94l13.4-7.4'
        'c3.9 1.1 8.1 1.7 13.1 1.7 23.2 0 41-17.3 41-39.2C91 25.3 73.2 8 50 8Z" fill="{fg}"/>'
        '<path d="M24.5 57.5 46 34.8l11.6 12.2L77 34.8 55.5 57.6 44.2 45.4Z" fill="{bg}"/>'
    )


@mark("bubble")
def _bubble():
    return (
        '<path d="M50 14c21 0 38 13.7 38 30.6S71 75.2 50 75.2c-3.5 0-6.9-.4-10.1-1.1'
        'L20 86l4.9-15.6C17.1 64.8 12 55.3 12 44.6 12 27.7 29 14 50 14Z" fill="{fg}"/>'
    )


@mark("threads")
def _threads():
    return (
        '<path d="M52 88C30 88 15 74.6 15 49.8 15 25.3 30.2 12 52.2 12c14.2 0 24.4 5.6 29.3 16.3'
        'l-9.6 4.6C68.3 25.3 61.6 21.8 52.1 21.8c-15.6 0-26.5 9.6-26.5 28 0 18.5 10.6 28.4 26.4 28.4'
        '9.7 0 16.6-3.1 20.4-8.1 2.4-3.1 3.5-6.8 3.5-10.3 0-6.3-3-11.3-8.8-14.2-2.4 11.8-9.2 20.2-20.7 20.2'
        '-8.4 0-14.9-5.3-14.9-13.4 0-9.4 8.3-14.8 20.2-14.8 3 0 5.9.2 8.6.7-.6-5.4-3.5-8.5-8.7-8.5'
        '-3.9 0-7.1 1.5-9.3 4.6l-7.9-5.3c3.9-5.7 9.9-8.6 17.4-8.6 11.8 0 18.4 7.2 19 19.3'
        '9.6 3.9 15.2 11.4 15.2 22C85.9 76.3 72.6 88 52 88Z" fill="{fg}"/>'
        '<path d="M52.4 47.8c-6.6 0-10.6 2.4-10.6 6.4 0 2.8 2.3 4.6 5.8 4.6 6.1 0 9.9-4.6 11.4-12.6'
        '-2.1-.3-4.2-.4-6.6-.4Z" fill="{bg}"/>'
    )


# --------------------------------------------------------------------------- #
# social / media
# --------------------------------------------------------------------------- #

@mark("instagram")
def _instagram():
    return (
        '<rect x="12" y="12" width="76" height="76" rx="23" fill="none" stroke="{fg}" stroke-width="8.5"/>'
        '<circle cx="50" cy="50" r="17" fill="none" stroke="{fg}" stroke-width="8.5"/>'
        '<circle cx="71.5" cy="28.5" r="5.2" fill="{fg}"/>'
    )


@mark("facebook")
def _facebook():
    return (
        '<path d="M58.5 92V54.5h12.6L73 39.9H58.5v-9.3c0-4.2 1.2-7.1 7.2-7.1H73V10.6'
        'C71.7 10.4 67.2 10 62 10c-11 0-18.5 6.7-18.5 19v10.9H31V54.5h12.5V92Z" fill="{fg}"/>'
    )


@mark("x_twitter")
def _x_twitter():
    return (
        '<path d="M60.5 14h13L48.8 42.2 78 86h-22L38.8 62.3 19.1 86H6l26.5-30.2L4.5 14h22.6'
        'l15.6 21.6ZM55.9 78.3h7.2L26.9 21.3h-7.7Z" fill="{fg}"/>'
    )


@mark("tiktok")
def _tiktok():
    return (
        '<path d="M62 8h13.5c1.2 9.8 7.6 16.4 17.5 17.3v13.4c-5.9.4-11.2-1.2-17.2-4.6v25.4'
        'c0 21-16.8 31.7-32 25.7-10-4-15.8-13.7-15-25 .8-11.5 10.4-20.4 22-21.1v14'
        'c-1.5.3-3 .6-4.4 1-4.3 1.3-6.8 4.6-6.1 8.9.6 4.1 4.1 6.9 8.4 6.7 5-.2 8.7-4 8.7-9.2'
        'V8.1Z" fill="{fg}"/>'
    )


@mark("tiktok_color")
def _tiktok_color():
    return (
        '<g transform="translate(-4,0)">'
        '<path d="M62 8h13.5c1.2 9.8 7.6 16.4 17.5 17.3v13.4c-5.9.4-11.2-1.2-17.2-4.6v25.4'
        'c0 21-16.8 31.7-32 25.7-10-4-15.8-13.7-15-25 .8-11.5 10.4-20.4 22-21.1v14'
        'c-1.5.3-3 .6-4.4 1-4.3 1.3-6.8 4.6-6.1 8.9.6 4.1 4.1 6.9 8.4 6.7 5-.2 8.7-4 8.7-9.2'
        'V8.1Z" fill="#25F4EE"/></g>'
        '<g transform="translate(4,0)">'
        '<path d="M62 8h13.5c1.2 9.8 7.6 16.4 17.5 17.3v13.4c-5.9.4-11.2-1.2-17.2-4.6v25.4'
        'c0 21-16.8 31.7-32 25.7-10-4-15.8-13.7-15-25 .8-11.5 10.4-20.4 22-21.1v14'
        'c-1.5.3-3 .6-4.4 1-4.3 1.3-6.8 4.6-6.1 8.9.6 4.1 4.1 6.9 8.4 6.7 5-.2 8.7-4 8.7-9.2'
        'V8.1Z" fill="#FE2C55"/></g>'
        '<path d="M62 8h13.5c1.2 9.8 7.6 16.4 17.5 17.3v13.4c-5.9.4-11.2-1.2-17.2-4.6v25.4'
        'c0 21-16.8 31.7-32 25.7-10-4-15.8-13.7-15-25 .8-11.5 10.4-20.4 22-21.1v14'
        'c-1.5.3-3 .6-4.4 1-4.3 1.3-6.8 4.6-6.1 8.9.6 4.1 4.1 6.9 8.4 6.7 5-.2 8.7-4 8.7-9.2'
        'V8.1Z" fill="{fg}"/>'
    )


@mark("youtube")
def _youtube():
    return (
        '<rect x="6" y="22" width="88" height="56" rx="17" fill="{fg}"/>'
        '<path d="M42 36.5 66 50 42 63.5Z" fill="{bg}"/>'
    )


@mark("play_triangle")
def _play_triangle():
    return '<path d="M28 16 84 50 28 84Z" fill="{fg}"/>'


@mark("snapchat")
def _snapchat():
    return (
        '<path d="M50 10c-13.5 0-24 10.5-24 24v12c0 4-2.5 6.5-6 8l-5 2c-2.5 1-2.5 4 0 5'
        'l7 2.5c1.5.5 2 1.5 2.5 3l1.5 5c.8 2.6 3 3.8 5.6 3.2l5.4-1.2c2.6-.6 4.6.2 6.4 2'
        'l4.2 4.2c1.8 1.8 4.6 1.8 6.4 0l4.2-4.2c1.8-1.8 3.8-2.6 6.4-2l5.4 1.2c2.6.6 4.8-.6 5.6-3.2'
        'l1.5-5c.5-1.5 1-2.5 2.5-3l7-2.5c2.5-1 2.5-4 0-5l-5-2c-3.5-1.5-6-4-6-8V34c0-13.5-10.5-24-24-24Z" fill="{fg}"/>'
    )


@mark("pinterest")
def _pinterest():
    return (
        '<path d="M50 8C27 8 15 23.4 15 39.2c0 7.4 3.9 16.5 10.2 19.4 1 .5 1.5.3 1.7-.7'
        '.2-.7.9-3.9 1.3-5.4.1-.5 0-.9-.4-1.4-2.3-2.8-4.2-7.9-4.2-12.7 0-12.3 9.3-24.2 25.1-24.2'
        '13.7 0 23.3 9.3 23.3 22.7 0 15.1-7.6 25.6-17.6 25.6-5.5 0-9.6-4.5-8.3-10.1'
        '1.6-6.6 4.7-13.8 4.7-18.6 0-4.3-2.3-7.9-7.1-7.9-5.6 0-10.2 5.8-10.2 13.6 0 5 1.7 8.4 1.7 8.4'
        'S28.6 73.7 27.5 78.2c-1.7 7.3-.3 16.3-.2 17.2.1.5.8.7 1.1.3.5-.6 6.6-8.2 8.7-15.7'
        '.6-2.1 3.4-13.3 3.4-13.3 1.7 3.2 6.6 6.1 11.9 6.1 15.6 0 26.2-14.2 26.2-33.3C78.6 24.9 66.4 8 50 8Z" fill="{fg}"/>'
    )


@mark("linkedin")
def _linkedin():
    return (
        '<rect x="10" y="36" width="16" height="52" rx="3" fill="{fg}"/>'
        '<circle cx="18" cy="19" r="10" fill="{fg}"/>'
        '<path d="M40 36h15.4v7.3c2.6-4.6 8-8.6 16-8.6 13 0 18.6 7.9 18.6 22.2V88H74V60.5'
        'c0-7.6-2.8-11.4-8.7-11.4-6.4 0-9.9 4.3-9.9 11.4V88H40Z" fill="{fg}"/>'
    )


@mark("reddit")
def _reddit():
    return (
        '<circle cx="50" cy="24" r="8.5" fill="{fg}"/>'
        '<path d="M50 30 54 9l13 3" fill="none" stroke="{fg}" stroke-width="5.5" stroke-linecap="round"/>'
        '<ellipse cx="50" cy="59" rx="36" ry="29" fill="{fg}"/>'
        '<circle cx="14" cy="52" r="11" fill="{fg}"/>'
        '<circle cx="86" cy="52" r="11" fill="{fg}"/>'
        '<circle cx="37" cy="56" r="6.2" fill="{bg}"/>'
        '<circle cx="63" cy="56" r="6.2" fill="{bg}"/>'
        '<path d="M36 71c4.2 4.2 9 6 14 6s9.8-1.8 14-6" fill="none" stroke="{bg}" '
        'stroke-width="5" stroke-linecap="round"/>'
    )


@mark("discord")
def _discord():
    return (
        '<path d="M78.5 19.5C72.4 16.6 65.9 14.5 59 13.4c-.9 1.5-1.9 3.5-2.5 5.1'
        '-7.2-1.1-14.3-1.1-21.4 0-.7-1.6-1.7-3.6-2.6-5.1-6.9 1.2-13.4 3.2-19.5 6.1'
        'C1.3 37.9-1.5 55.7.1 73.3c8.2 6 16.1 9.7 23.9 12.1 1.9-2.6 3.6-5.3 5.1-8.2'
        '-2.8-1.1-5.5-2.4-8-4 .7-.5 1.4-1 2-1.6 15.4 7.1 32.1 7.1 47.3 0 .7.6 1.3 1.1 2 1.6'
        '-2.5 1.5-5.2 2.9-8 4 1.5 2.9 3.2 5.7 5.1 8.2 7.8-2.4 15.7-6.1 23.9-12.1'
        '2-20.4-3.4-38-14.9-53.8Z" fill="{fg}"/>'
        '<ellipse cx="33.4" cy="52.9" rx="8.6" ry="9.6" fill="{bg}"/>'
        '<ellipse cx="65.2" cy="52.9" rx="8.6" ry="9.6" fill="{bg}"/>'
    )


@mark("twitch")
def _twitch():
    return (
        '<path d="M20 8h64v46L66 72H52L40 84H30V72H16V22Zm58 42V16H26v42h14v10l10-10Z" fill="{fg}"/>'
        '<rect x="44" y="28" width="7" height="18" fill="{fg}"/>'
        '<rect x="60" y="28" width="7" height="18" fill="{fg}"/>'
    )


@mark("spotify")
def _spotify():
    return (
        '<circle cx="50" cy="50" r="42" fill="{fg}"/>'
        '<path d="M28 36c14-4 31-3 44 4" fill="none" stroke="{bg}" stroke-width="9" stroke-linecap="round"/>'
        '<path d="M31 51c12-3.5 25-2.5 36 3.5" fill="none" stroke="{bg}" stroke-width="7.5" stroke-linecap="round"/>'
        '<path d="M34 65c9.5-2.5 20-1.8 28 2.8" fill="none" stroke="{bg}" stroke-width="6" stroke-linecap="round"/>'
    )


@mark("netflix")
def _netflix():
    return (
        '<path d="M26 8h17l31 84H57L26 8Z" fill="{fg}" opacity="0.55"/>'
        '<path d="M26 8h14v84H26Z" fill="{fg}"/>'
        '<path d="M60 8h14v84H60Z" fill="{fg}"/>'
    )


# --------------------------------------------------------------------------- #
# google family - these keep their own colours on a neutral card
# --------------------------------------------------------------------------- #

G_BLUE, G_RED, G_YELLOW, G_GREEN = "#4285F4", "#EA4335", "#FBBC05", "#34A853"


@mark("google_g")
def _google_g():
    return (
        '<path d="M88 51.3c0-2.8-.3-5.6-.8-8.2H50v15.5h21.4c-.9 5-3.7 9.2-7.9 12v10h12.8'
        'C83.8 73.6 88 63.4 88 51.3Z" fill="%s"/>'
        '<path d="M50 90c10.7 0 19.7-3.5 26.3-9.6l-12.8-10c-3.6 2.4-8.1 3.8-13.5 3.8'
        '-10.4 0-19.2-7-22.3-16.4H14.4v10.3C21 81.3 34.5 90 50 90Z" fill="%s"/>'
        '<path d="M27.7 57.8c-.8-2.4-1.3-4.9-1.3-7.6s.5-5.2 1.3-7.6V32.3H14.4C11.6 37.7 10 43.7 10 50.2'
        'c0 6.5 1.6 12.5 4.4 17.9l13.3-10.3Z" fill="%s"/>'
        '<path d="M50 26.2c5.9 0 11.1 2 15.3 6l11.4-11.4C69.7 14.4 60.7 10.5 50 10.5c-15.5 0-29 8.7-35.6 21.8'
        'l13.3 10.3C30.8 33.2 39.6 26.2 50 26.2Z" fill="%s"/>'
    ) % (G_BLUE, G_GREEN, G_YELLOW, G_RED)


@mark("gmail")
def _gmail():
    return (
        '<defs><clipPath id="env"><rect x="4" y="18" width="92" height="64" rx="10"/></clipPath></defs>'
        '<rect x="4" y="18" width="92" height="64" rx="10" fill="#FFF"/>'
        '<g clip-path="url(#env)" fill="none" stroke-width="18">'
        '<path d="M13 86V23" stroke="%s"/>'
        '<path d="M13 23 50 54" stroke="%s"/>'
        '<path d="M50 54 87 23" stroke="%s"/>'
        '<path d="M87 23v63" stroke="%s"/>'
        '</g>'
    ) % (G_BLUE, G_RED, G_YELLOW, G_GREEN)


@mark("maps_pin")
def _maps_pin():
    return (
        '<path d="M50 8c16 0 29 13 29 29 0 20.6-23.4 44.6-26.4 47.6-1.4 1.4-3.8 1.4-5.2 0'
        'C44.4 81.6 21 57.6 21 37 21 21 34 8 50 8Z" fill="%s"/>'
        '<circle cx="50" cy="37" r="11.5" fill="#FFF"/>'
    ) % G_RED


@mark("drive")
def _drive():
    return (
        '<path d="M36.5 12h27L92 61H64.5Z" fill="%s"/>'
        '<path d="M36.5 12 8 61l13.5 23L50 35Z" fill="%s"/>'
        '<path d="M8 61h56l-13.5 23h-29Z" fill="%s"/>'
    ) % (G_YELLOW, G_BLUE, G_GREEN)


@mark("photos")
def _photos():
    return (
        '<path d="M48 6c11 0 20 9 20 20v20H48Z" fill="%s"/>'
        '<path d="M94 48c0 11-9 20-20 20H54V48Z" fill="%s"/>'
        '<path d="M52 94c-11 0-20-9-20-20V54h20Z" fill="%s"/>'
        '<path d="M6 52c0-11 9-20 20-20h20v20Z" fill="%s"/>'
    ) % (G_YELLOW, G_RED, G_BLUE, G_GREEN)


@mark("play_store")
def _play_store():
    return (
        '<path d="M14 10.5c-1.9 1-3 3-3 5.7v67.6c0 2.7 1.1 4.7 3 5.7L50 50Z" fill="%s"/>'
        '<path d="M14 10.5 63.5 36 50 50Z" fill="%s"/>'
        '<path d="M14 89.5 50 50l13.5 14Z" fill="%s"/>'
        '<path d="M63.5 36 78.6 44c5 2.7 5 9.3 0 12L63.5 64 50 50Z" fill="%s"/>'
    ) % (G_BLUE, G_GREEN, G_RED, G_YELLOW)


@mark("chrome")
def _chrome():
    return (
        '<circle cx="50" cy="50" r="42" fill="%s"/>'
        '<path d="M50 8c15.4 0 28.8 8.3 36.1 20.7H50c-9.6 0-17.8 6.4-20.4 15.2L16.3 21.3C24 13.1 36.4 8 50 8Z" fill="%s"/>'
        '<path d="M86.1 28.7C90.5 36.1 92 43 92 50c0 23.2-18.8 42-42 42l19.3-33.4c1.7-2.6 2.7-5.7 2.7-9 0-4.2-1.5-8-4-11Z" fill="%s"/>'
        '<path d="M50 92C26.8 92 8 73.2 8 50c0-10.8 4-20.6 10.7-28.1l19.6 33.9c3.1 5.3 8.8 8.9 15.4 9L50 92Z" fill="%s"/>'
        '<circle cx="50" cy="50" r="17" fill="#FFF"/>'
        '<circle cx="50" cy="50" r="13" fill="%s"/>'
    ) % (G_YELLOW, G_RED, G_GREEN, "#4CAF50", G_BLUE)


@mark("meet")
def _meet():
    return (
        '<rect x="8" y="28" width="54" height="44" rx="10" fill="{fg}"/>'
        '<path d="M68 44 86 31c3-2.2 7 0 7 3.6v30.8c0 3.6-4 5.8-7 3.6L68 56Z" fill="{fg}"/>'
    )


@mark("doc_page")
def _doc_page():
    return (
        '<path d="M26 8h32l20 20v64c0 2.2-1.8 4-4 4H26c-2.2 0-4-1.8-4-4V12c0-2.2 1.8-4 4-4Z" fill="{fg}"/>'
        '<path d="M58 8l20 20H62c-2.2 0-4-1.8-4-4Z" fill="{fg}" opacity="0.55"/>'
        '<g fill="{bg}"><rect x="33" y="45" width="34" height="5" rx="2.5"/>'
        '<rect x="33" y="57" width="34" height="5" rx="2.5"/>'
        '<rect x="33" y="69" width="22" height="5" rx="2.5"/></g>'
    )


@mark("keep_bulb")
def _keep_bulb():
    return (
        '<path d="M50 10c16 0 28 12 28 27 0 9-4.5 16-9.5 21-2.5 2.5-4.5 5.5-4.5 9v3H36v-3'
        'c0-3.5-2-6.5-4.5-9C26.5 53 22 46 22 37c0-15 12-27 28-27Z" fill="{fg}"/>'
        '<rect x="38" y="76" width="24" height="7" rx="3.5" fill="{fg}"/>'
        '<rect x="42" y="86" width="16" height="6" rx="3" fill="{fg}"/>'
    )


@mark("translate")
def _translate():
    return (
        '<g stroke="{fg}" stroke-width="6" stroke-linecap="round" fill="none">'
        '<path d="M42 12v8"/><path d="M26 28h32"/>'
        '<path d="M53 32 31 62"/><path d="M34 34 56 62"/>'
        '</g>'
        '<path d="M62 44h12l17 46h-10l-3.5-10H58.5L55 90H45Zm6 10-5.5 16h11Z" fill="{fg}"/>'
    )


@mark("gear")
def _gear():
    teeth = []
    import math
    for i in range(8):
        a = i * 45
        teeth.append(
            '<rect x="43" y="2" width="14" height="22" rx="4" fill="{fg}" '
            'transform="rotate(%d 50 50)"/>' % a
        )
    return (
        "".join(teeth)
        + '<circle cx="50" cy="50" r="30" fill="{fg}"/>'
        + '<circle cx="50" cy="50" r="12" fill="{bg}"/>'
    )


@mark("camera")
def _camera():
    return (
        '<path d="M38 16h24l6 10h14c4.4 0 8 3.6 8 8v42c0 4.4-3.6 8-8 8H18c-4.4 0-8-3.6-8-8V34'
        'c0-4.4 3.6-8 8-8h14Z" fill="{fg}"/>'
        '<circle cx="50" cy="55" r="19" fill="{bg}"/>'
        '<circle cx="50" cy="55" r="12" fill="{fg}"/>'
    )


@mark("gallery")
def _gallery():
    return (
        '<rect x="8" y="16" width="84" height="68" rx="12" fill="{fg}"/>'
        '<circle cx="32" cy="38" r="8" fill="{bg}"/>'
        '<path d="M12 74 38 48l16 16 14-12 20 22v2c0 4.4-3.6 8-8 8H20c-4.4 0-8-3.6-8-8Z" fill="{bg}"/>'
    )


@mark("clock")
def _clock():
    return (
        '<circle cx="50" cy="50" r="40" fill="{fg}"/>'
        '<path d="M50 26v25l17 10" fill="none" stroke="{bg}" stroke-width="8" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
    )


@mark("calculator")
def _calculator():
    return (
        '<rect x="16" y="8" width="68" height="84" rx="12" fill="{fg}"/>'
        '<rect x="26" y="18" width="48" height="18" rx="5" fill="{bg}"/>'
        '<g fill="{bg}">'
        '<circle cx="34" cy="50" r="6"/><circle cx="50" cy="50" r="6"/><circle cx="66" cy="50" r="6"/>'
        '<circle cx="34" cy="66" r="6"/><circle cx="50" cy="66" r="6"/><circle cx="66" cy="66" r="6"/>'
        '<circle cx="34" cy="81" r="6"/><circle cx="50" cy="81" r="6"/><circle cx="66" cy="81" r="6"/>'
        '</g>'
    )


@mark("folder")
def _folder():
    return (
        '<path d="M14 18h24l10 12h38c4.4 0 8 3.6 8 8v40c0 4.4-3.6 8-8 8H14c-4.4 0-8-3.6-8-8V26'
        'c0-4.4 3.6-8 8-8Z" fill="{fg}"/>'
    )


@mark("person")
def _person():
    return (
        '<circle cx="50" cy="33" r="19" fill="{fg}"/>'
        '<path d="M50 58c17 0 31 11.5 33 26.5.4 3.2-2 5.5-5 5.5H22c-3 0-5.4-2.3-5-5.5C19 69.5 33 58 50 58Z" fill="{fg}"/>'
    )


@mark("calendar")
def _calendar():
    return (
        '<rect x="10" y="18" width="80" height="74" rx="12" fill="{fg}"/>'
        '<rect x="10" y="18" width="80" height="20" rx="12" fill="{fg}"/>'
        '<rect x="18" y="44" width="64" height="40" rx="6" fill="{bg}"/>'
        '<rect x="26" y="6" width="10" height="22" rx="5" fill="{fg}"/>'
        '<rect x="64" y="6" width="10" height="22" rx="5" fill="{fg}"/>'
    )


@mark("wallet")
def _wallet():
    return (
        '<rect x="8" y="20" width="84" height="62" rx="14" fill="{fg}"/>'
        '<path d="M64 42h30v20H64c-5.5 0-10-4.5-10-10s4.5-10 10-10Z" fill="{bg}"/>'
        '<circle cx="68" cy="52" r="4.5" fill="{fg}"/>'
    )


@mark("card")
def _card():
    return (
        '<rect x="6" y="20" width="88" height="60" rx="12" fill="{fg}"/>'
        '<rect x="6" y="34" width="88" height="12" fill="{bg}"/>'
        '<rect x="16" y="58" width="26" height="8" rx="4" fill="{bg}"/>'
    )


@mark("cart")
def _cart():
    return (
        '<path d="M8 16h11c2.6 0 4.8 1.8 5.4 4.3L27 30h58c3.4 0 5.9 3.2 5 6.5l-8 29'
        'c-.9 3.3-3.9 5.5-7.3 5.5H36c-3.5 0-6.5-2.4-7.3-5.8L18.6 24H8Z" fill="{fg}"/>'
        '<circle cx="38" cy="84" r="8" fill="{fg}"/>'
        '<circle cx="72" cy="84" r="8" fill="{fg}"/>'
    )


@mark("bag")
def _bag():
    return (
        '<path d="M20 30h60c3.3 0 6 2.6 6.2 5.9l3.4 46c.4 5.3-3.8 9.8-9.1 9.8H19.5'
        'c-5.3 0-9.5-4.5-9.1-9.8l3.4-46C14 32.6 16.7 30 20 30Z" fill="{fg}"/>'
        '<path d="M34 38V26c0-8.8 7.2-16 16-16s16 7.2 16 16v12" fill="none" stroke="{fg}" '
        'stroke-width="8" stroke-linecap="round"/>'
    )


@mark("parcel")
def _parcel():
    return (
        '<path d="M50 6 90 26v48L50 94 10 74V26Z" fill="{fg}"/>'
        '<path d="M10 26 50 46l40-20" fill="none" stroke="{bg}" stroke-width="6" stroke-linejoin="round"/>'
        '<path d="M50 46v48" fill="none" stroke="{bg}" stroke-width="6"/>'
        '<path d="M30 16 70 36v16" fill="none" stroke="{bg}" stroke-width="6" stroke-linecap="round"/>'
    )


@mark("envelope")
def _envelope():
    return (
        '<rect x="6" y="22" width="88" height="56" rx="12" fill="{fg}"/>'
        '<path d="M12 30 50 56 88 30" fill="none" stroke="{bg}" stroke-width="7" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
    )


@mark("truck")
def _truck():
    return (
        '<path d="M6 24h44c2.2 0 4 1.8 4 4v38H6c-2.2 0-4-1.8-4-4V28c0-2.2 1.8-4 4-4Z" fill="{fg}" transform="translate(4,6)"/>'
        '<path d="M58 40h16l14 16v16c0 2.2-1.8 4-4 4H58Z" fill="{fg}" transform="translate(0,0)"/>'
        '<circle cx="30" cy="78" r="9" fill="{fg}"/><circle cx="74" cy="78" r="9" fill="{fg}"/>'
        '<circle cx="30" cy="78" r="3.5" fill="{bg}"/><circle cx="74" cy="78" r="3.5" fill="{bg}"/>'
    )


@mark("train")
def _train():
    return (
        '<path d="M28 8h44c8.8 0 16 7.2 16 16v40c0 8.8-7.2 16-16 16H28c-8.8 0-16-7.2-16-16V24'
        'c0-8.8 7.2-16 16-16Z" fill="{fg}"/>'
        '<rect x="24" y="22" width="52" height="22" rx="6" fill="{bg}"/>'
        '<circle cx="32" cy="62" r="7" fill="{bg}"/><circle cx="68" cy="62" r="7" fill="{bg}"/>'
        '<path d="M30 82 14 96M70 82 86 96" stroke="{fg}" stroke-width="8" stroke-linecap="round"/>'
    )


@mark("taxi")
def _taxi():
    return (
        '<path d="M18 46l8-19c1.6-3.6 5.2-6 9.2-6h29.6c4 0 7.6 2.4 9.2 6l8 19h3c3.3 0 6 2.7 6 6v22'
        'c0 3.3-2.7 6-6 6h-3v4c0 3.3-2.7 6-6 6h-6c-3.3 0-6-2.7-6-6v-4H36v4c0 3.3-2.7 6-6 6h-6'
        'c-3.3 0-6-2.7-6-6v-4h-3c-3.3 0-6-2.7-6-6V52c0-3.3 2.7-6 6-6Z" fill="{fg}"/>'
        '<path d="M30 46l5.5-13h29L70 46Z" fill="{bg}"/>'
        '<circle cx="29" cy="62" r="6" fill="{bg}"/><circle cx="71" cy="62" r="6" fill="{bg}"/>'
    )


@mark("fuel")
def _fuel():
    return (
        '<path d="M50 6c14 0 30 21 30 41 0 18-13.4 31-30 31S20 65 20 47C20 27 36 6 50 6Z" fill="{fg}"/>'
        '<path d="M50 34c7 8 11 14 11 20 0 6.6-5 11-11 11s-11-4.4-11-11c0-6 4-12 11-20Z" fill="{bg}"/>'
    )


@mark("pill")
def _pill():
    return (
        '<rect x="8" y="34" width="84" height="32" rx="16" fill="{fg}" transform="rotate(-45 50 50)"/>'
        '<path d="M50 50 27 73" stroke="{bg}" stroke-width="0" fill="none"/>'
        '<path d="M36 22 78 64" stroke="{bg}" stroke-width="6" stroke-linecap="round" fill="none" '
        'transform="rotate(0 50 50)" opacity="0"/>'
        '<path d="M33.5 33.5 66.5 66.5" stroke="{bg}" stroke-width="6" fill="none"/>'
    )


@mark("heart")
def _heart():
    return (
        '<path d="M50 88C26 72 8 57 8 39.5 8 26 18.5 16 31.5 16 39 16 46 19.5 50 25.5'
        'c4-6 11-9.5 18.5-9.5C81.5 16 92 26 92 39.5 92 57 74 72 50 88Z" fill="{fg}"/>'
    )


@mark("cross_med")
def _cross_med():
    return (
        '<rect x="38" y="10" width="24" height="80" rx="8" fill="{fg}"/>'
        '<rect x="10" y="38" width="80" height="24" rx="8" fill="{fg}"/>'
    )


@mark("shield")
def _shield():
    return (
        '<path d="M50 6 88 20v26c0 22-15.6 38.6-38 48C27.6 84.6 12 68 12 46V20Z" fill="{fg}"/>'
    )


@mark("siren")
def _siren():
    return (
        '<path d="M50 14c14.4 0 26 11.6 26 26v22H24V40c0-14.4 11.6-26 26-26Z" fill="{fg}"/>'
        '<rect x="14" y="62" width="72" height="14" rx="7" fill="{fg}"/>'
        '<rect x="44" y="2" width="12" height="12" rx="6" fill="{fg}"/>'
        '<path d="M14 34 4 28M86 34l10-6M22 16 14 8M78 16l8-8" stroke="{fg}" stroke-width="7" stroke-linecap="round"/>'
    )


@mark("book")
def _book():
    return (
        '<path d="M14 12h28c6.6 0 12 5.4 12 12v64c0-6.6-5.4-12-12-12H14Z" fill="{fg}"/>'
        '<path d="M86 12H58c-6.6 0-12 5.4-12 12v64c0-6.6 5.4-12 12-12h28Z" fill="{fg}" opacity="0.8"/>'
    )


@mark("cap")
def _cap():
    return (
        '<path d="M50 14 96 36 50 58 4 36Z" fill="{fg}"/>'
        '<path d="M24 46v20c0 8 12 16 26 16s26-8 26-16V46L50 58Z" fill="{fg}"/>'
        '<path d="M88 40v22" stroke="{fg}" stroke-width="6" stroke-linecap="round"/>'
    )


@mark("tv")
def _tv():
    return (
        '<rect x="6" y="18" width="88" height="58" rx="10" fill="{fg}"/>'
        '<rect x="16" y="28" width="68" height="38" rx="5" fill="{bg}"/>'
        '<rect x="30" y="84" width="40" height="8" rx="4" fill="{fg}"/>'
    )


@mark("film")
def _film():
    return (
        '<rect x="8" y="16" width="84" height="68" rx="12" fill="{fg}"/>'
        '<g fill="{bg}">'
        '<rect x="16" y="24" width="12" height="11" rx="3"/><rect x="16" y="44" width="12" height="11" rx="3"/>'
        '<rect x="16" y="64" width="12" height="11" rx="3"/><rect x="72" y="24" width="12" height="11" rx="3"/>'
        '<rect x="72" y="44" width="12" height="11" rx="3"/><rect x="72" y="64" width="12" height="11" rx="3"/>'
        '<rect x="34" y="24" width="32" height="51" rx="4"/></g>'
    )


@mark("music_note")
def _music_note():
    return (
        '<path d="M78 8v52c0 9-7.6 16-17 16s-17-7-17-16 7.6-16 17-16c3.3 0 6.4.9 9 2.4V26L36 38v38'
        'c0 9-7.6 16-17 16S2 85 2 76s7.6-16 17-16c3.3 0 6.4.9 9 2.4V26Z" fill="{fg}" '
        'transform="translate(8,2) scale(0.92)"/>'
    )


@mark("mic")
def _mic():
    return (
        '<rect x="36" y="6" width="28" height="50" rx="14" fill="{fg}"/>'
        '<path d="M22 46c0 15.5 12.5 28 28 28s28-12.5 28-28" fill="none" stroke="{fg}" '
        'stroke-width="9" stroke-linecap="round"/>'
        '<path d="M50 74v18" stroke="{fg}" stroke-width="9" stroke-linecap="round"/>'
    )


@mark("globe")
def _globe():
    return (
        '<circle cx="50" cy="50" r="40" fill="none" stroke="{fg}" stroke-width="8"/>'
        '<ellipse cx="50" cy="50" rx="18" ry="40" fill="none" stroke="{fg}" stroke-width="7"/>'
        '<path d="M12 36h76M12 64h76" stroke="{fg}" stroke-width="7" stroke-linecap="round"/>'
    )


@mark("plane")
def _plane():
    return (
        '<path d="M93 50c0 3-2.4 5.4-5.4 5.4H63.6L45.9 86.7c-.9 1.6-2.6 2.6-4.5 2.6h-5.6'
        'c-3.1 0-5.3-3-4.4-5.9l8.4-27.9H23.7l-8 10.7c-1 1.3-2.5 2.1-4.2 2.1H9c-3 0-5.2-2.9-4.4-5.8'
        'L8.4 50 4.6 37.5c-.9-2.9 1.3-5.8 4.4-5.8h2.5c1.7 0 3.2.8 4.2 2.1l8 10.7h16.1l-8.4-27.9'
        'c-.9-2.9 1.3-5.9 4.4-5.9h5.6c1.9 0 3.6 1 4.5 2.6l17.7 31.3h24c3 0 5.4 2.4 5.4 5.4Z" fill="{fg}"/>'
    )


@mark("bolt")
def _bolt():
    return '<path d="M58 4 20 56h20l-6 40 44-56H56Z" fill="{fg}"/>'


@mark("gamepad")
def _gamepad():
    return (
        '<path d="M28 26h44c13.3 0 24 10.7 24 24v6c0 10-8 18-18 18-6 0-11.4-3-14.6-7.6L60 62H40'
        'l-3.4 4.4C33.4 71 28 74 22 74 12 74 4 66 4 56v-6c0-13.3 10.7-24 24-24Z" fill="{fg}"/>'
        '<g fill="{bg}"><rect x="20" y="44" width="20" height="6" rx="3"/>'
        '<rect x="27" y="37" width="6" height="20" rx="3"/>'
        '<circle cx="68" cy="43" r="5"/><circle cx="79" cy="52" r="5"/></g>'
    )


@mark("search")
def _search():
    return (
        '<circle cx="43" cy="43" r="27" fill="none" stroke="{fg}" stroke-width="10"/>'
        '<path d="M63 63 88 88" stroke="{fg}" stroke-width="12" stroke-linecap="round"/>'
    )


@mark("qr")
def _qr():
    return (
        '<g fill="{fg}">'
        '<path d="M10 10h32v32H10Zm8 8v16h16V18Z"/>'
        '<path d="M58 10h32v32H58Zm8 8v16h16V18Z"/>'
        '<path d="M10 58h32v32H10Zm8 8v16h16V66Z"/>'
        '<rect x="56" y="56" width="12" height="12"/><rect x="78" y="56" width="12" height="12"/>'
        '<rect x="67" y="67" width="12" height="12"/><rect x="56" y="78" width="12" height="12"/>'
        '<rect x="78" y="78" width="12" height="12"/></g>'
    )


@mark("trident")
def _trident():
    return (
        '<path d="M50 2 61 15v47H39V15Z" fill="{fg}"/>'
        '<path d="M39 58h22v20L50 96 39 78Z" fill="{fg}"/>'
        '<path d="M8 13 26 24v25c0 8.6 4.6 14 15 15.4v15C20 66.6 8 54 8 36Z" fill="{fg}"/>'
        '<path d="M92 13 74 24v25c0 8.6-4.6 14-15 15.4v15C80 66.6 92 54 92 36Z" fill="{fg}"/>'
    )


@mark("star")
def _star():
    return (
        '<path d="M50 6 63 38l34 2.6-26 22 8.2 33L50 77.6 20.8 95.6 29 62.6l-26-22L37 38Z" fill="{fg}"/>'
    )


@mark("ticket")
def _ticket():
    return (
        '<path d="M12 24h76c3.3 0 6 2.7 6 6v12c-5.5 0-10 4-10 9s4.5 9 10 9v12c0 3.3-2.7 6-6 6H12'
        'c-3.3 0-6-2.7-6-6V60c5.5 0 10-4 10-9s-4.5-9-10-9V30c0-3.3 2.7-6 6-6Z" fill="{fg}"/>'
        '<path d="M60 30v10M60 46v10M60 62v10" stroke="{bg}" stroke-width="5" stroke-linecap="round"/>'
    )


@mark("percent")
def _percent():
    return (
        '<circle cx="30" cy="30" r="14" fill="none" stroke="{fg}" stroke-width="10"/>'
        '<circle cx="70" cy="70" r="14" fill="none" stroke="{fg}" stroke-width="10"/>'
        '<path d="M22 82 78 18" stroke="{fg}" stroke-width="11" stroke-linecap="round"/>'
    )


@mark("cards_stack")
def _cards_stack():
    return (
        '<rect x="14" y="10" width="72" height="72" rx="20" fill="{fg}" opacity="0.35"/>'
        '<rect x="8" y="26" width="84" height="64" rx="20" fill="{fg}"/>'
        '<path d="M22 62 38 46l12 12 14-14 14 14" fill="none" stroke="{bg}" stroke-width="7" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
    )


@mark("weather")
def _weather():
    return (
        '<circle cx="38" cy="34" r="17" fill="{fg}"/>'
        '<g stroke="{fg}" stroke-width="5.5" stroke-linecap="round">'
        '<path d="M38 6v7M38 55v7M10 34h7M59 34h7M18 14l5 5M53 49l5 5M18 54l5-5M53 19l5-5"/></g>'
        '<path d="M44 86c-9.4 0-17-7.2-17-16s7.6-16 17-16c1.3 0 2.6.1 3.8.4C51 48.2 57.9 44 65.8 44'
        'c11.7 0 21.2 9 21.2 20.2 0 .8 0 1.6-.2 2.4 4.2 1.9 7.2 6 7.2 10.8 0 5-4.2 8.6-9.4 8.6Z" fill="{fg}"/>'
    )


@mark("slack")
def _slack():
    bar = ('<rect x="6" y="52" width="40" height="16" rx="8" fill="{fg}" '
           'transform="rotate(%d 50 50)"/>')
    return "".join(bar % a for a in (0, 90, 180, 270))


@mark("chess_pawn")
def _chess_pawn():
    return (
        '<path d="M50 8c8.6 0 15.5 7 15.5 15.5 0 4.8-2.2 9.1-5.7 11.9 5.4 3.2 9.2 8.8 10 15.4H30.2'
        'c.8-6.6 4.6-12.2 10-15.4-3.5-2.8-5.7-7.1-5.7-11.9C34.5 15 41.4 8 50 8Z" fill="{fg}"/>'
        '<path d="M33 57h34c-1 11-4.2 19.8-8.6 26.5H41.6C37.2 76.8 34 68 33 57Z" fill="{fg}"/>'
        '<rect x="22" y="80" width="56" height="13" rx="6.5" fill="{fg}"/>'
    )
