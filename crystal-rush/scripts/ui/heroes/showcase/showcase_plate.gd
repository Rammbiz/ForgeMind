class_name HeroShowcasePlate
extends HeroSkillPlate
## A HeroSkillPlate for the Showcase / Manage sheet. Before the skill ranks open (L30, §11.3:
## "Ult + Attack plates, no hallmarks") the plate shows no rank hallmark at all
## (HeroSkillPlate.show_hallmark = false); the kind («УЛЬТА», «АТАКА») is a 20 px caps label above
## the plate and the skill name a 22 px line under it, both drawn by the screen
## (HeroShowcase._skill_block), so the plate's own text is off.
##   var p := HeroShowcasePlate.make_from(hero, "ult", 104, true)


static func make_from(h: Dictionary, s: String, px := 104.0, ranks_open := true) -> HeroShowcasePlate:
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
	p.show_hallmark = ranks_open
	return p
