extends Node
## Headless checks for Juice + Audio (role JUICE, dev only).
## godot --headless --path . res://scenes/dev/test_juice.tscn

var _pulses: Array = []
var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_usec()
	await _audio_checks()
	await _trauma_checks()
	await _hitstop_checks()
	await _haptic_checks()
	await _counter_checks()
	await _popup_checks()
	print("JUICE_TEST done")
	get_tree().quit(0)


func _ms() -> int:
	return int((Time.get_ticks_usec() - _t0) / 1000)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _audio_checks() -> void:
	print("== Audio streams")
	var missing := 0
	for n in Audio.SFX_NAMES:
		var s: AudioStream = Audio.get_sfx(n)
		if s == null:
			missing += 1
			print("  MISSING ", n)
		else:
			var loop := ""
			if s is AudioStreamWAV:
				loop = " loop=%d(%d..%d) rate=%d" % [(s as AudioStreamWAV).loop_mode, (s as AudioStreamWAV).loop_begin,
						(s as AudioStreamWAV).loop_end, (s as AudioStreamWAV).mix_rate]
			print("  %-12s %-18s %.3fs%s" % [n, s.get_class(), s.get_length(), loop])
	print("  loaded %d / %d" % [Audio.SFX_NAMES.size() - missing, Audio.SFX_NAMES.size()])
	var t := Time.get_ticks_usec()
	if not Audio.tones_are_ready():
		await Audio.tones_ready
	print("  tones ready after %d ms (waited %d ms here)" % [_ms(), (Time.get_ticks_usec() - t) / 1000])
	var dump := OS.get_environment("JUICE_TONE_DUMP")
	if dump != "":
		for s in [0, 4, 7, 10, 14]:
			Audio._notes[s].save_to_wav(dump.path_join("tone_note%02d.wav" % s))
		Audio._sparkle.save_to_wav(dump.path_join("tone_sparkle.wav"))
		Audio._wah.save_to_wav(dump.path_join("tone_wah.wav"))
		print("  tones dumped to ", dump)
	for s in 15:
		Audio.note(s)
	Audio.chord(3, true)
	Audio.chord(3, false)
	Audio.play_pitched("stairs_step", -6.0, 1.25)
	Audio.laser_on()
	await _wait(0.2)
	Audio.laser_off()
	print("  note/chord/play_pitched/laser calls OK")


func _trauma_checks() -> void:
	print("== Trauma")
	var j := Juice.new()
	add_child(j)
	await get_tree().process_frame
	j.add_trauma(0.8, "barricade")
	var peak := 0.0
	var last := Vector3.ZERO
	var max_step := 0.0
	for i in 10:
		var o := j.shake_offset()
		peak = maxf(peak, o.length())
		if i > 0:
			max_step = maxf(max_step, (o - last).length())
		last = o
		print("  t=%4dms trauma=%.3f |offset|=%.3f roll=%.2fdeg" % [i * 100, j.trauma, o.length(), rad_to_deg(j.shake_roll())])
		await _wait(0.1)
	j.trauma = 0.0
	for i in 10:
		j.add_trauma(0.1, "clash")
	print("  10x clash +0.1 in one frame -> trauma %.3f (cap 0.25)" % j.trauma)
	await _wait(0.5)
	j.trauma = 0.0
	j.add_trauma(0.1, "clash")
	print("  after 0.5 s refill, clash +0.1 -> %.3f" % j.trauma)
	# Smoothness: step the noise clock exactly as 60 fps frames at trauma 1 (2 s of motion).
	j.set_process(false)
	j.trauma = 1.0
	var prev := j.shake_offset()
	var jump := 0.0
	var mx := 0.0
	var sum := 0.0
	var crossings := 0
	for i in 120:
		j._noise_t += (Juice.SHAKE_SPEED + Juice.SHAKE_SPEED_TRAUMA) / 60.0
		var o := j.shake_offset()
		jump = maxf(jump, (o - prev).length())
		sum += (o - prev).length()
		mx = maxf(mx, o.length())
		if signf(o.x) != signf(prev.x):
			crossings += 1
		prev = o
	print("  trauma 1 @60fps over 2 s: max |offset| %.3f u (limit %.3f), max frame step %.3f u, mean step %.3f u, x zero-crossings %d (~%.1f Hz)" % [mx, Juice.SHAKE_MAX, jump, sum / 120.0, crossings, crossings / 4.0])
	j.set_process(true)
	j.queue_free()


func _hitstop_checks() -> void:
	print("== Hitstop")
	for base in [1.0, 4.0]:
		Juice.base_time_scale = base
		Engine.time_scale = base
		var j := Juice.new()
		add_child(j)
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		j.hitstop(0.12, 0.3, 0.3)
		var line := "  base %.1f:" % base
		while Time.get_ticks_usec() - t < 600000:
			line += " %d:%.3f" % [(Time.get_ticks_usec() - t) / 1000, Engine.time_scale]
			await _wait(0.04)
		print(line)
		print("    after: time_scale=%.3f active=%s" % [Engine.time_scale, j.is_hitstopping()])
		j.queue_free()
	# survives pause: pause the tree mid-freeze, the scale must still come back.
	Juice.base_time_scale = 1.0
	var j2 := Juice.new()
	add_child(j2)
	await get_tree().process_frame
	j2.hitstop(0.1, 0.1)
	get_tree().paused = true
	await _wait(0.35)
	print("  paused during hitstop -> time_scale after 0.35 s = %.3f (expect 1.0)" % Engine.time_scale)
	get_tree().paused = false
	# freed mid-hitstop restores too
	j2.hitstop(0.5)
	print("  mid-freeze scale %.3f" % Engine.time_scale)
	j2.free()
	print("  freed mid-freeze -> time_scale %.3f" % Engine.time_scale)
	Juice.hitstop_enabled = false
	var j3 := Juice.new()
	add_child(j3)
	j3.hitstop(0.2)
	print("  hitstop_enabled=false -> time_scale %.3f" % Engine.time_scale)
	Juice.hitstop_enabled = true
	j3.queue_free()


func _haptic_checks() -> void:
	print("== Haptics (pulses with ms since call)")
	var j := Juice.new()
	add_child(j)
	await get_tree().process_frame
	j.haptic_pulse.connect(func(kind: String, ms: int, amp: float): _pulses.append([_ms(), kind, ms, amp]))
	for kind in ["gate_bad", "ult", "win"]:
		_pulses.clear()
		var t := _ms()
		j.haptic(kind)
		await _wait(0.5)
		var s := "  %-9s" % kind
		for p in _pulses:
			s += " [+%dms %s %dms@%.1f]" % [int(p[0]) - t, p[1], p[2], p[3]]
		print(s)
	_pulses.clear()
	var t2 := _ms()
	for i in 20:
		j.haptic("tile")
		await _wait(0.05)
	print("  20 tiles over 1 s -> %d pulses (throttle 250 ms)" % _pulses.size())
	_pulses.clear()
	t2 = _ms()
	j.haptic("gate_good")
	await _wait(0.02)
	j.haptic("gate_good")
	j.haptic("barricade")
	await _wait(0.3)
	var s2 := "  gate_good, +20ms gate_good (dropped) + barricade (deferred):"
	for p in _pulses:
		s2 += " [+%dms %s]" % [int(p[0]) - t2, p[1]]
	print(s2)
	j.queue_free()


func _counter_checks() -> void:
	print("== Counter")
	var j := Juice.new()
	add_child(j)
	var l := Label3D.new()
	l.text = "10"
	add_child(l)
	await get_tree().process_frame
	var t := Time.get_ticks_usec()
	j.counter(l, 47)
	var line := "  10->47:"
	while Time.get_ticks_usec() - t < 500000:
		line += " %d:%s/%.2f/%s" % [(Time.get_ticks_usec() - t) / 1000, l.text, l.scale.x, "G" if l.modulate.b < 0.9 else "w"]
		await _wait(0.05)
	print(line)
	t = Time.get_ticks_usec()
	j.counter(l, 30)
	line = "  47->30:"
	while Time.get_ticks_usec() - t < 500000:
		line += " %d:%s/%.2f/(%.2f,%.2f,%.2f)" % [(Time.get_ticks_usec() - t) / 1000, l.text, l.scale.x, l.modulate.r, l.modulate.g, l.modulate.b]
		await _wait(0.1)
	print(line)
	l.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("  freed label handled, counters left: %d" % j._counters.size())
	j.queue_free()


func _popup_checks() -> void:
	print("== Popups")
	var j := Juice.new()
	add_child(j)
	await get_tree().process_frame
	for i in 12:
		j.popup("+%d" % i, Vector3(i * 0.1, 1, 0), Color(0.4, 1, 0.5))
	var vis := 0
	for c in j.get_children():
		if c is Label3D and (c as Label3D).visible:
			vis += 1
	print("  12 popups -> %d visible labels (pool %d)" % [vis, Juice.POPUP_POOL])
	var l: Label3D = j._popups[2]
	var y0 := l.global_position.y
	var line := "  popup#2:"
	for i in 8:
		line += " %d:y+%.2f s%.2f a%.2f" % [i * 100, l.global_position.y - y0, l.scale.x, l.modulate.a]
		await _wait(0.1)
	print(line)
	vis = 0
	for c in j.get_children():
		if c is Label3D and (c as Label3D).visible:
			vis += 1
	print("  after 0.8 s visible: %d" % vis)
	j.queue_free()
