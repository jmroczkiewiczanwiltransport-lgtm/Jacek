extends SceneTree
## Test sterowania dotykowego i dźwięku bez okna:  godot --headless --path . -s tests/touch_audio_test.gd
var main
var step := 0
var frames := 0
var fails := 0

func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  BLAD ") + what)
	if not ok: fails += 1

## Dotknięcie strefy sterowania: przelicza jej środek (z przesunięciem) na współrzędne okna.
func _touch(id: String, index: int, pressed: bool, rel := Vector2(0.5, 0.5)) -> void:
	var r: Rect2 = main.touch._zones[id]
	var local := r.position + r.size * rel
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = root.get_final_transform() * (main.touch.get_global_transform() * local)
	Input.parse_input_event(ev)

## Energia składowej o częstotliwości f w strumieniu (algorytm Goertzela), znormalizowana do długości.
func _tone(stream: AudioStreamWAV, f: float) -> float:
	var d := stream.data
	var n := mini(d.size() / 2, 11025)
	var w := TAU * f / stream.mix_rate
	var c := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in n:
		var s0 := d.decode_s16(i * 2) / 32768.0 + c * s1 - s2
		s2 = s1
		s1 = s0
	return sqrt(maxf(0.0, s1 * s1 + s2 * s2 - c * s1 * s2)) / n

func _rms(stream: AudioStreamWAV) -> float:
	var d := stream.data
	var n := d.size() / 2
	var acc := 0.0
	for i in n:
		var v := d.decode_s16(i * 2) / 32768.0
		acc += v * v
	return sqrt(acc / maxi(n, 1))

func _process(_dt: float) -> bool:
	if main == null:
		OS.set_environment("KNC_TOUCH", "1")
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		return false
	if not main.ready_done:
		return false
	frames += 1
	var rig = main.rig
	match step:
		0:
			main._start()
			main.traffic.enabled = false
			main.events.clear()
			step = 1; frames = 0
		1:
			if frames == 5:
				_check(main.touch_mode and main.touch.visible and main.touch.active, "sterowanie dotykowe wlaczone i widoczne w trakcie jazdy")
				_check(is_equal_approx(root.content_scale_factor, 1.35), "interfejs powiekszony dla telefonu")
				_touch("parking", 0, true); _touch("parking", 0, false)
			if frames == 10:
				_check(rig.parking == false, "przycisk P zwalnia hamulec postojowy")
				_touch("gas", 1, true, Vector2(0.5, 0.2))
				_touch("steer", 0, true, Vector2(0.9, 0.5))
			if frames == 30:
				_check(rig.throttle > 0.9, "pedal gazu (palec wysoko) daje pelny gaz: %.2f" % rig.throttle)
				_check(rig.steer_in < -0.8, "kierownica w prawo przy drugim palcu jednoczesnie: %.2f" % rig.steer_in)
				_touch("gas", 1, false); _touch("steer", 0, false)
				_touch("brake", 2, true, Vector2(0.5, 0.75))
			if frames == 40:
				_check(rig.throttle == 0.0 and rig.steer_in == 0.0, "puszczenie palcow zeruje gaz i kierownice")
				_check(rig.brake_in > 0.25 and rig.brake_in < 0.6, "hamulec dozowany (palec nisko): %.2f" % rig.brake_in)
				_touch("brake", 2, false)
				for id in ["lights", "wipers", "retarder", "blink_left", "camera"]:
					_touch(id, 3, true); _touch(id, 3, false)
				_touch("horn", 4, true)
			if frames == 50:
				_check(rig.lights == 1 and rig.wipers == 1 and rig.retarder == 1 and rig.blinker == 1, "przyciski swiatel, wycieraczek, zwalniacza i kierunkowskazu")
				_check(main.cams.mode == 2, "przycisk KAM zmienia widok")
				_check(rig.horn and main.audio._p["horn"].playing, "klakson gra, gdy trzymasz przycisk")
				_touch("horn", 4, false)
				_touch("pause", 5, true); _touch("pause", 5, false)
			if frames == 60:
				_check(main.state == "pause" and not main.touch.visible, "przycisk postoju zatrzymuje gre i chowa sterowanie")
				main._resume()
				step = 2; frames = 0
		2:
			var a = main.audio
			var names := ["engine", "road", "wind", "rain", "horn", "beep", "tick", "tock", "hiss", "impact", "blip", "jingle"]
			var quiet := []
			for nm in names:
				var st: AudioStreamWAV = a._p[nm].stream
				if st.data.size() < 400 or _rms(st) < 0.02: quiet.append(nm)
			_check(quiet.is_empty(), "wszystkie %d dzwiekow wygenerowane i nieme nie sa %s" % [names.size(), str(quiet)])
			var horn: AudioStreamWAV = a._p["horn"].stream
			_check(_tone(horn, 310.0) > 6.0 * _tone(horn, 340.0) and _tone(horn, 370.0) > 6.0 * _tone(horn, 340.0), "klakson ma dwa tony: 310 i 370 Hz")
			var beep: AudioStreamWAV = a._p["beep"].stream
			_check(_tone(beep, 1150.0) > 8.0 * _tone(beep, 800.0), "sygnal cofania: 1150 Hz")
			var eng: AudioStreamWAV = a._p["engine"].stream
			_check(_tone(eng, 30.0) > 4.0 * _tone(eng, 41.0), "silnik: rytm 30 zaplonow na sekunde na biegu jalowym")
			_check(a._p["engine"].playing and a._p["road"].playing, "petle silnika i toczenia graja")
			# model obrotów: rozpędzanie do 90 km/h przechodzi przez biegi, obroty w zakresie
			a.gear_i = 0; a.rpm = 600.0
			var max_rpm := 0.0
			var min_rpm := 9999.0
			rig.controls_enabled = true
			var saved_speed: float = rig.speed
			for i in 2400:
				rig.speed = minf(25.0, i * 0.0125)
				rig.throttle = 1.0
				a._process(1.0 / 60.0)
				max_rpm = maxf(max_rpm, a.rpm); min_rpm = minf(min_rpm, a.rpm)
			rig.speed = saved_speed; rig.throttle = 0.0
			_check(a.gear_i == 11, "przy 90 km/h silnik jest na 12. biegu (jest %d.)" % (a.gear_i + 1))
			_check(max_rpm < 2000.0 and min_rpm >= 600.0, "obroty przy rozpedzaniu w zakresie 600-2000 (%.0f-%.0f)" % [min_rpm, max_rpm])
			_check(absf(a.rpm - 1250.0) < 80.0, "przy 90 km/h okolo 1250 obr./min (%.0f)" % a.rpm)
			a.set_muted(true)
			_check(AudioServer.is_bus_mute(0), "wyciszenie dziala")
			a.set_muted(false)
			print("WYNIK: %s" % ("wszystko OK" if fails == 0 else "%d bledow" % fails))
			return true
	return false
