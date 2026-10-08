class_name HeroShowcasePlate
extends HeroSkillPlate
## A HeroSkillPlate for the Showcase / Manage sheet. Before the skill ranks open (L30, §11.3:
## "Ult + Attack plates, no hallmarks") the rank hallmark is replaced by a quiet kind tag
## («Ульта», «Атака») so no rank number shows; afterwards it is the plain hallmark. The skill
## name and the native-ceiling note are separate 22 px labels under it (the plate's own text is
## off), see HeroShowcase._skill_block().
##   var p := HeroShowcasePlate.make_from(hero, "ult", 96, true)

var kind_tag := ""


static func make_from(h: Dictionary, s: String, px := 96.0, ranks_open := true) -> HeroShowcasePlate:
	var row: Dictionary = (h["skills"] as Dictionary)[s]
	var p := HeroShowcasePlate.new()
	p.skill = s
	p.title = ""
	p.rank = int(row["rank"])
	p.cap = int(row["cap"])
	p.form_gem = str(row.get("form_gem", "")) if s == "ult" else ""
	p.plate = px
	p.locked = not bool(row.get("open", false)) if s == "awakened" else false
	p.born = bool(row.get("born", false))
	if not ranks_open and not p.locked:
		p.kind_tag = HeroesText.skill_kind(s)
	return p


func _draw() -> void:
	super()
	if kind_tag == "" or locked:
		return
	# Cover the hallmark with the kind tag (same seat on the bottom edge of the plate).
	var s := plate
	var c := Vector2(size.x * 0.5, 12.0 + s * 0.5)
	var f := UIKit.font_w("bold")
	var fs := 20
	var hm := HeroesText.t("SKL_MAX") if rank >= cap else HeroesText.t("SKL_RANK_SHORT", [rank, cap])
	var hw := UIKit.font_w("extrabold").get_string_size(hm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 26.0
	var tw := f.get_string_size(kind_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := maxf(tw + 24.0, hw)
	var tr := Rect2(Vector2(c.x - w * 0.5, c.y + s * 0.5 - 16.0), Vector2(w, 32.0))
	var tp := GemDraw.chamfer_rect(tr, 6.0)
	draw_colored_polygon(tp, UITokens.PAPER_0)
	GemDraw.outline(self, tp, UITokens.HAIRLINE, 1.2)
	draw_string(f, Vector2(tr.get_center().x - tw * 0.5, tr.get_center().y + f.get_ascent(fs) * 0.36), kind_tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.GOLD_TEXT)
