class_name ForgeIcons
## «Кришталева кузня» icons: faceted low-poly silhouettes in three tones (light / mid / dark
## facets, lit from the top-left), no outlines - each icon is "a crystal of its object".
## Shapes live in a 100 x 100 box: [tone, x0, y0, x1, y1, ...]. Tones index the icon's
## palette; tone 9 is a 3 px line in palette[5] (white).

const SHAPES := {
	# Brilliant-cut crystal (gems currency).
	"gem": [
		[1, 10, 36, 30, 14, 42, 36], [5, 30, 14, 70, 14, 58, 36, 42, 36], [2, 70, 14, 90, 36, 58, 36],
		[1, 10, 36, 42, 36, 50, 90], [0, 42, 36, 58, 36, 50, 90], [3, 58, 36, 90, 36, 50, 90],
	],
	# Folded blueprint sheet with a white crosshair.
	"blueprint": [
		[1, 10, 20, 38, 12, 38, 80, 10, 88], [0, 38, 12, 64, 22, 64, 90, 38, 80], [2, 64, 22, 90, 12, 90, 80, 64, 90],
		[9, 24, 50, 78, 50], [9, 51, 26, 51, 74], [9, 30, 30, 44, 30],
	],
	# Geode egg, the cracked side showing amethyst (Vault / caches).
	"geode": [
		[1, 50, 6, 30, 14, 17, 34, 40, 44], [0, 17, 34, 14, 60, 36, 64, 40, 44], [1, 14, 60, 25, 82, 50, 93, 36, 64],
		[2, 50, 93, 74, 82, 60, 64, 36, 64], [2, 74, 82, 86, 60, 60, 64],
		[4, 50, 6, 70, 15, 84, 36, 86, 60, 60, 64, 40, 44],
		[3, 46, 46, 56, 14, 64, 48], [5, 56, 14, 64, 48, 58, 50], [3, 62, 54, 80, 26, 80, 56], [6, 80, 26, 80, 56, 72, 58],
		[6, 42, 52, 46, 30, 54, 54],
	],
	# Anvil with a crystal (Arsenal = the forge).
	"anvil": [
		[3, 52, 26, 62, 2, 70, 26], [4, 62, 2, 76, 12, 70, 26],
		[1, 4, 30, 32, 24, 32, 42], [5, 32, 22, 96, 22, 96, 30, 32, 30], [0, 32, 30, 96, 30, 90, 46, 38, 46],
		[2, 46, 46, 82, 46, 74, 64, 54, 64], [1, 32, 64, 92, 64, 98, 82, 26, 82], [2, 26, 82, 98, 82, 98, 90, 26, 90],
	],
	# Crystal gate (Play: the run starts through it).
	"gate": [
		[6, 32, 92, 32, 40, 50, 26, 68, 40, 68, 92],
		[0, 12, 92, 12, 42, 24, 36, 24, 92], [1, 24, 36, 32, 40, 32, 92, 24, 92],
		[1, 68, 40, 76, 36, 76, 92, 68, 92], [2, 76, 36, 88, 42, 88, 92, 76, 92],
		[5, 12, 42, 50, 8, 50, 20, 24, 36], [0, 50, 8, 88, 42, 76, 36, 50, 20],
		[3, 44, 12, 50, -4, 56, 12], [5, 50, 46, 60, 62, 50, 78, 40, 62], [3, 50, 46, 60, 62, 50, 78],
	],
	# Fox head (Heroes: Bolt).
	"fox": [
		[1, 10, 4, 40, 32, 22, 46], [4, 17, 15, 34, 32, 24, 40], [2, 90, 4, 78, 46, 60, 32], [4, 83, 15, 76, 40, 66, 32],
		[0, 40, 32, 60, 32, 50, 52], [0, 22, 46, 40, 32, 50, 52, 36, 66], [1, 78, 46, 60, 32, 50, 52, 64, 66],
		[1, 22, 46, 36, 66, 10, 62], [2, 78, 46, 90, 62, 64, 66],
		[5, 36, 66, 50, 52, 64, 66, 50, 94], [6, 50, 52, 64, 66, 50, 94], [4, 44, 85, 56, 85, 50, 94],
		[4, 30, 46, 43, 49, 34, 53], [4, 70, 46, 66, 53, 57, 49],
	],
	# Knight helm, white enamel, gold ridge, ice crest (Barracks).
	"helm": [
		[3, 42, 0, 58, 0, 54, 20, 46, 20], [4, 58, 0, 66, 6, 54, 20],
		[0, 20, 30, 50, 16, 50, 60, 18, 58], [1, 50, 16, 80, 30, 82, 58, 50, 60],
		[7, 18, 58, 82, 58, 80, 67, 20, 67], [1, 20, 67, 50, 67, 50, 94, 27, 84], [2, 50, 67, 80, 67, 73, 84, 50, 94],
		[4, 26, 42, 46, 47, 46, 52, 27, 49], [4, 54, 47, 74, 42, 73, 49, 54, 52], [7, 47, 16, 53, 16, 53, 58, 47, 58],
	],
	# Settings: a faceted nut.
	"gear": [
		[0, 50, 6, 81, 19, 50, 34], [0, 50, 6, 50, 34, 19, 19], [5, 19, 19, 50, 34, 34, 50, 6, 50],
		[1, 81, 19, 94, 50, 66, 50, 50, 34], [2, 94, 50, 81, 81, 50, 66, 66, 50], [2, 81, 81, 50, 94, 50, 66],
		[1, 50, 94, 19, 81, 34, 50, 50, 66], [0, 6, 50, 19, 81, 34, 50],
		[4, 50, 34, 66, 50, 50, 66, 34, 50],
	],
	# Upgrade: two stacked chevrons.
	"up": [
		[0, 50, 6, 50, 26, 18, 54, 6, 44], [2, 50, 6, 94, 44, 82, 54, 50, 26],
		[1, 50, 42, 50, 62, 18, 90, 6, 80], [3, 50, 42, 94, 80, 82, 90, 50, 62],
	],
	"lock": [
		[2, 28, 44, 28, 26, 50, 10, 72, 26, 72, 44, 62, 44, 62, 30, 50, 21, 38, 30, 38, 44],
		[0, 16, 44, 54, 44, 50, 92, 20, 92], [1, 54, 44, 84, 44, 80, 92, 50, 92], [4, 46, 60, 54, 60, 52, 78, 48, 78],
	],
	"plus": [[0, 40, 10, 60, 10, 60, 90, 40, 90], [0, 10, 40, 90, 40, 90, 60, 10, 60], [1, 50, 50, 60, 40, 90, 40, 90, 60, 60, 60]],
	"check": [[0, 6, 52, 20, 38, 40, 58, 40, 82], [1, 40, 58, 80, 14, 94, 28, 40, 82]],
	"sword": [
		[5, 40, 14, 50, 0, 50, 62, 40, 62], [6, 50, 0, 60, 14, 60, 62, 50, 62], [7, 20, 62, 80, 62, 76, 72, 24, 72],
		[2, 44, 72, 56, 72, 56, 88, 44, 88], [7, 38, 88, 62, 88, 50, 100],
	],
	"heart": [[0, 8, 34, 28, 14, 50, 30, 50, 86], [1, 50, 30, 72, 14, 92, 34, 50, 86], [5, 18, 30, 28, 22, 36, 30]],
	"range": [[0, 50, 6, 94, 50, 50, 50], [1, 94, 50, 50, 94, 50, 50], [2, 50, 94, 6, 50, 50, 50], [5, 6, 50, 50, 6, 50, 50], [4, 40, 40, 60, 40, 60, 60, 40, 60]],
	"bolt": [[1, 60, 2, 20, 58, 46, 58, 34, 98, 82, 40, 56, 40, 72, 2], [0, 60, 2, 20, 58, 46, 58, 52, 40]],
	"ad": [[0, 8, 18, 92, 18, 92, 50, 8, 50], [1, 8, 50, 92, 50, 92, 82, 8, 82], [5, 40, 32, 64, 50, 40, 68]],
}

## Palettes: [light, mid, dark, accent, accent dark, white, extra, gold].
const PALS := {
	"gem": [Color("C9F6FF"), Color("6FD7FF"), Color("2B8DE0"), Color("1D5FB4"), Color("0E2F6A"), Color("FFFFFF")],
	"blueprint": [Color("8CC8FF"), Color("4A92F0"), Color("2558C2"), Color("1A3C8C"), Color("0E2050"), Color("E8F6FF")],
	"geode": [Color("8B8FA8"), Color("5E627C"), Color("383B52"), Color("D6B6FF"), Color("2A1640"), Color("F4E8FF"), Color("9B5CFF")],
	"anvil": [Color("D9E2F2"), Color("97A6C6"), Color("55628A"), Color("BFF3FF"), Color("3CB8FF"), Color("FFFFFF")],
	"gate": [Color("E9FBFF"), Color("8FDDF5"), Color("3D8FC4"), Color("FFFFFF"), Color("3CB8FF"), Color("FFFFFF"), Color(0.36, 0.8, 1.0, 0.55)],
	"fox": [Color("FFB271"), Color("F07A2A"), Color("B2470F"), Color("FFC59A"), Color("3A1B10"), Color("FFF5EA"), Color("D8CEC4")],
	"helm": [Color("FFFFFF"), Color("DCE0EA"), Color("A5ADC2"), Color("BFF3FF"), Color("1E2A4A"), Color("FFFFFF"), Color("3CB8FF"), Color("E2B04A")],
	"gear": [Color("D9E2F2"), Color("97A6C6"), Color("55628A"), Color("BFF3FF"), Color("1A2140"), Color("F4F8FF")],
	"up": [Color("FFFFFF"), Color("BFF3FF"), Color("6FD7FF"), Color("3CB8FF"), Color("1E5CB0"), Color("FFFFFF")],
	"lock": [Color("D9E2F2"), Color("97A6C6"), Color("55628A"), Color("BFF3FF"), Color("1A2140"), Color("FFFFFF")],
	"plus": [Color("0A1736"), Color("1C3A70"), Color("1C3A70"), Color("1C3A70"), Color("1C3A70"), Color("0A1736")],
	"check": [Color("BFF3FF"), Color("6FD7FF"), Color("2B8DE0"), Color("1D5FB4"), Color("0E2F6A"), Color("FFFFFF")],
	"sword": [Color("E9FBFF"), Color("8FDDF5"), Color("55628A"), Color("BFF3FF"), Color("1A2140"), Color("FFFFFF"), Color("B9D8F0"), Color("E2B04A")],
	"heart": [Color("FFB0A0"), Color("FF5A4A"), Color("A51E1E"), Color("FFFFFF"), Color("5A0A0A"), Color("FFE6E0")],
	"range": [Color("E2CCFF"), Color("A66BFF"), Color("5A26B8"), Color("FFFFFF"), Color("2A1060"), Color("F4E8FF")],
	"bolt": [Color("FFF4C0"), Color("FFC94A"), Color("B07A10"), Color("FFFFFF"), Color("5A3A06"), Color("FFFFFF")],
	"ad": [Color("E2CCFF"), Color("A66BFF"), Color("5A26B8"), Color("FFFFFF"), Color("2A1060"), Color("FFFFFF")],
}

## Deep-ink palette for light icons sitting on an ice prism.
const DEEP := [Color("2F7FD6"), Color("1A5FB8"), Color("0C3A80"), Color("0A2456"), Color("06142E"), Color("E9FBFF"), Color(0.05, 0.2, 0.5, 0.75), Color("C9922E")]

const GREY := [Color("8A94B4"), Color("6A7496"), Color("4C5574"), Color("7A84A4"), Color("2A3150"), Color("A8B0CA"), Color("6A7496"), Color("8A94B4")]


## Draws icon `name` into `r`. "coin" is a cut gold gem.
static func draw(ci: CanvasItem, name: String, r: Rect2, grey := false, pal_override: Array = []) -> void:
	if name == "coin":
		var c := r.get_center()
		var rad := minf(r.size.x, r.size.y) * 0.48
		var gp: Array = [Color("FFF3C8"), Color("FFC94A"), Color("A86A12")] if not grey else [GREY[0], GREY[1], GREY[2]]
		ForgeKit.draw_gem(ci, c, rad, 8, gp, PI / 8.0, 0.64, false)
		# Embossed rhombus on the table.
		var k := rad * 0.3
		var col: Color = Color("C88A1E") if not grey else GREY[2]
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 1.2), c + Vector2(k, 0), c + Vector2(0, k * 1.2), c + Vector2(-k, 0)]), col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 1.2), c + Vector2(k, 0), c + Vector2(0, 0)]), Color("FFE9A8") if not grey else GREY[0])
		return
	if not SHAPES.has(name):
		return
	var pal: Array = pal_override if not pal_override.is_empty() else (GREY if grey else PALS.get(name, PALS["gem"]))
	var sx := r.size.x / 100.0
	var sy := r.size.y / 100.0
	for sh: Array in SHAPES[name]:
		var tone := int(sh[0])
		var pts := PackedVector2Array()
		for i in range(1, sh.size(), 2):
			pts.append(r.position + Vector2(float(sh[i]) * sx, float(sh[i + 1]) * sy))
		if tone == 9:
			ci.draw_line(pts[0], pts[1], pal[5], maxf(2.0, 3.0 * sx), true)
			continue
		var col: Color = pal[mini(tone, pal.size() - 1)]
		ci.draw_colored_polygon(pts, col)
