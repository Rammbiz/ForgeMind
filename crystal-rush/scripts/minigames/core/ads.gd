class_name Ads
## Rewarded ads (arsenal_design.md §6.6: AdMob rewarded only, always started by the player, never a pulse; the
## button is ABSENT when offline or while no ad is loaded, never a grey disabled button).
## The project has no ads SDK yet, so this is a stub: with no `provider`, can_show() is false and no ad button
## ever appears. The future AdMob plugin (WS6) sets `provider` to an object with:
##   can_show() -> bool            an ad is loaded and the device is online
##   show(done: Callable)          plays it; calls done.call(true) when the player earned the reward, else false
## Dev runs and tests use DevProvider (an ad that is always ready and completes at once).
##
##   if Ads.can_show(): add the button;  on press: Ads.show(func(ok: bool): if ok: Meta.fair_book_ad(...))

static var provider: Object = null


## True when a rewarded ad can play right now (false offline, with no ad loaded, or with no SDK).
static func can_show() -> bool:
	return provider != null and provider.has_method("can_show") and bool(provider.call("can_show"))


## Plays a rewarded ad; `done.call(earned: bool)` runs once (false at once when none can show).
static func show(done: Callable) -> void:
	if not can_show():
		done.call(false)
		return
	provider.call("show", done)


## Dev / test provider: always ready (unless `ready` is false); `show` reports `earn` on the next frame.
class DevProvider:
	extends RefCounted
	var ready := true
	var earn := true
	var shown := 0

	func can_show() -> bool:
		return ready

	func show(done: Callable) -> void:
		shown += 1
		done.call_deferred(earn)
