class_name Preview
## The owner's preview build («Crystal Rush Preview», export preset "Android Preview" with the feature tag
## `preview`; on a PC `-- --preview`): a separate app id, so the real game's save is never touched. It
## boots into PreviewLauncher (hero, up to 4 champions, level), plays dev runs (Save.readonly: nothing is
## read from or written to disk; Meta builds the EXPECTED synthetic account) with the heroes phase forced
## to HEROES_RUN_PHASE, and every way back to the hub returns to the launcher. Never on in the shipped app.

static var _on := -1


static func on() -> bool:
	if _on < 0:
		_on = 1 if OS.has_feature("preview") or "--preview" in OS.get_cmdline_user_args() else 0
	return _on == 1
