extends SceneTree
## Test całej trasy bez okna: autopilot jedzie z MOP-u na plac, potem sprawdzana jest ocena podjazdu pod rampę.
##   godot --headless --path . -s tests/game_test.gd
const World = preload("res://scripts/world.gd")
var main
var pts: Array = []
var idx := 0
var t := 0.0
var phase := 0
var max_art := 0.0
var max_lat := 0.0
var fails := 0

func _initialize() -> void:
	# Przyspieszenie testu: 6x więcej kroków fizyki na sekundę przy tej samej długości kroku (1/120 s).
	Engine.physics_ticks_per_second = 720
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64

func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  BLAD ") + what)
	if not ok: fails += 1

func _sample(curve: Curve3D, from := 0.0, to := -1.0) -> void:
	if to < 0.0: to = curve.get_baked_length()
	var d := from
	while d < to:
		pts.append(curve.sample_baked(d))
		d += 3.0

func _process(_dt: float) -> bool:
	if main == null:
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		if not main.has_method("_start"):
			print("BLAD: scena glowna nie wczytala skryptu"); return true
		return false
	if phase == 0:
		main._start()
		main.traffic.enabled = false
		main.events.clear()      # bez zdarzeń losowych: przejazd ma być powtarzalny
		main.rig.impact.connect(func(dv, what): print("  UDERZENIE dv=%.2f %s  t=%.1f ciagnik=%s naczepa=%s" % [dv, what, t, main.rig.tractor.global_position, main.rig.trailer.global_position]))
		main.rig.parking = false
		var w = main.world
		var right: Curve3D = w.paths["right"]
		var merge: Curve3D = w.paths["merge"]
		_sample(merge)
		var d0 := right.get_closest_offset(merge.sample_baked(merge.get_baked_length()))
		var d1 := right.get_closest_offset(w._ring_pt(-PI * 0.5 - World.PHI))
		_sample(right, d0 + 6.0, d1)
		_sample(w.paths["player_exit"])
		_sample(w.paths["access"], 4.0)
		for p in [Vector3(-352, 0, 3257.5), Vector3(-366, 0, 3256), Vector3(-380, 0, 3254)]: pts.append(p)
		print("trasa autopilota: %d punktow, ok. %.1f km" % [pts.size(), pts.size() * 3.0 / 1000.0])
		phase = 1
	return false

func _physics_process(delta: float) -> bool:
	if phase < 1: return false
	t += delta
	var rig = main.rig
	var pos: Vector3 = rig.tractor.global_transform * Vector3(0, 0, 2.5)
	pos.y = 0.0
	if phase == 1:
		while idx < pts.size() - 1 and pts[idx].distance_to(pos) < 6.0: idx += 1
		# najbliższy punkt z przodu
		var look := int(clampf(absf(rig.speed) * 0.55, 3.0, 12.0))
		var target: Vector3 = pts[mini(idx + look, pts.size() - 1)]
		var fwd: Vector3 = rig.tractor.global_basis.z
		var to := (target - pos); to.y = 0.0
		var ang := atan2(fwd.cross(to).y, fwd.dot(to))
		Input.action_press("steer_left", clampf(ang * 2.2, 0.0, 1.0)); Input.action_press("steer_right", clampf(-ang * 2.2, 0.0, 1.0))
		var dr := pos.distance_to(World.RB_C)
		var vt := 24.5
		if main.stage == 0: vt = 14.0 if pos.z < 230.0 else 24.5
		if dr < 260.0: vt = lerpf(7.0, 24.5, clampf((dr - 60.0) / 200.0, 0.0, 1.0))
		if main.stage >= 3: vt = 9.0
		if main.stage == 4 or idx > pts.size() - 6: vt = 3.0
		var v: float = rig.speed
		Input.action_press("throttle", clampf((vt - v) * 0.6, 0.0, 1.0)); Input.action_press("brake", clampf((v - vt - 0.8) * 0.5, 0.0, 1.0))
		if OS.has_environment("KNC_DBG") and int(t * 120.0) % 3600 == 0:
			print("t=%.0f pos=(%.1f, %.1f) v=%.1f steer=%.2f ang=%.2f idx=%d target=(%.1f, %.1f) art=%.0f yaw=%.0f thr=%.2f brk=%.2f" % [t, pos.x, pos.z, v, rig.steer, ang, idx, target.x, target.z, rad_to_deg(rig.articulation), rad_to_deg(rig.tractor.global_rotation.y), rig.throttle, rig.brake_in])
		max_art = maxf(max_art, absf(rig.articulation))
		max_lat = maxf(max_lat, pts[maxi(idx - 1, 0)].distance_to(pos) - 6.0)
		if idx >= pts.size() - 1 or t > 420.0:
			Input.action_release("throttle"); Input.action_release("steer_left"); Input.action_release("steer_right"); Input.action_press("brake", 1.0)
			print("przejazd: czas gry %.0f s, etap %d, ladunek %.0f%%, uderzen %d, maks. kat zlamania %.0f st, pozostalo %.0f s" % [t, main.stage, main.cargo, main.hits, rad_to_deg(max_art), main.t_left])
			_check(main.stage == 4, "autopilot dojechal na plac (etap 4)")
			_check(main.hits == 0, "bez uderzen po drodze")
			_check(t < 330.0, "przejazd trasy w rozsadnym czasie (< 330 s)")
			_check(rig.tractor.global_position.is_finite(), "pozycje skonczone")
			phase = 2; t = 0.0
	elif phase == 2:
		if t > 3.0:
			Input.action_release("brake")
			# ustawiamy naczepę pod właściwą rampą, lekko krzywo
			var b: Dictionary = main._bay()
			rig.place(Vector3(b["pos"].x + 0.22, 0, World.DOCK_Z - 12.45), Vector3(0.03, 0, -1))
			rig.parking = true
			phase = 3; t = 0.0
	elif phase == 3:
		if t > 2.5:
			var e: Dictionary = main.dock_error()
			print("ustawienie pod rampa: bok %.2f m, odleglosc %.2f m, kat %.1f st" % [e["lat"], e["dist"], e["ang"]])
			_check(absf(e["lat"] + 0.14) < 0.1 and absf(e["dist"] - 0.45) < 0.15, "odchylki pod rampa policzone poprawnie")
			main._try_dock()
			_check(main.state == "result", "rozladunek przyjety, plansza wyniku")
			_check(main.last_result > 0, "wyplata dodatnia: %d zl" % main.last_result)
			# zła rampa
			main._on_action("retry", null)
			main.stage = 4
			var wrong: Dictionary = main.world.bays[7]
			rig.place(Vector3(wrong["pos"].x, 0, World.DOCK_Z - 12.45), Vector3(0, 0, -1)); rig.parking = true
			phase = 4; t = 0.0
	elif phase == 4:
		if t > 2.0:
			main._try_dock()
			_check(main.state == "drive", "zla rampa odrzucona")
			# ruch uliczny: 40 s jazdy z włączonym ruchem
			main._rescue(); main.stage = 1; main._rescue()
			main.traffic.enabled = true; rig.parking = false
			phase = 5; t = 0.0
	elif phase == 5:
		Input.action_press("throttle", 1.0 if rig.speed < 20.0 else 0.0)
		if t > 40.0:
			var n: int = main.traffic.cars.size()
			print("ruch: %d pojazdow wokol gracza po 40 s" % n)
			_check(n >= 4, "ruch uliczny sie pojawia")
			print("WYNIK: %s" % ("wszystko OK" if fails == 0 else "%d bledow" % fails))
			return true
	return false
