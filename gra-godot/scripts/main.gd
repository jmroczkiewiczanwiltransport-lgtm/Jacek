extends Node3D
## Scena główna: składa świat, zestaw gracza, ruch, niebo i interfejs; prowadzi zlecenie od MOP-u do rampy.

const World = preload("res://scripts/world.gd")
const Rig = preload("res://scripts/rig.gd")
const SkyRig = preload("res://scripts/sky.gd")
const Cameras = preload("res://scripts/cameras.gd")
const Hud = preload("res://scripts/hud.gd")
const Traffic = preload("res://scripts/traffic.gd")

const CONTRACTS := [
	{"cargo": "Napoje na paletach", "mass": 18000.0, "frag": 1.0, "time": "day", "rain": 0.0, "bay": 3, "window": 450.0, "rate": 2400, "events": ["breakdown"],
		"note": "Na początek: dzień i sucha jezdnia. Rampa 3 leży między dwiema zajętymi."},
	{"cargo": "Stal w kręgach", "mass": 25000.0, "frag": 0.7, "time": "overcast", "rain": 0.0, "bay": 5, "window": 480.0, "rate": 3100, "events": ["rain"],
		"note": "25 t na naczepie: zestaw wolniej się rozpędza i dłużej hamuje. Prognoza zapowiada deszcz na trasie."},
	{"cargo": "Elektronika", "mass": 12000.0, "frag": 1.6, "time": "dusk", "rain": 0.0, "bay": 8, "window": 450.0, "rate": 3700, "events": ["rebook", "breakdown"],
		"note": "Kruchy ładunek: każde uderzenie kosztuje o 60% więcej. Zapada zmierzch — włącz światła (L)."},
	{"cargo": "Leki, transport pilny", "mass": 10000.0, "frag": 1.4, "time": "night", "rain": 1.0, "bay": 5, "window": 470.0, "rate": 4600, "events": ["rebook"],
		"note": "Noc i deszcz. Mokra jezdnia wydłuża hamowanie o ponad jedną trzecią, a w zakręcie łatwiej o poślizg."},
]
const QUALITY_NAMES := ["niska", "średnia", "wysoka"]
const OBJECTIVES := ["Wyjedź z MOP-u na drogę ekspresową", "Do ronda", "Rondo: pierwszy zjazd, strefa przemysłowa", "Do bramy centrum logistycznego", "Cofnij pod rampę %d"]

var world
var rig
var sky
var cams
var hud
var traffic

var state := "menu"          # menu | drive | pause | result
var c_idx := 0
var contract := {}
var career := 0
var quality := 2
var t_left := 0.0
var cargo := 100.0
var stage := 0
var bay_num := 3
var hits := 0
var events := {}             # nazwa -> {z, done}
var last_result := 0
var _hint_lights := 0.0
var _wrong_exit := false
var _dock_msg_cd := 0.0
var _help_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	sky = SkyRig.new(); add_child(sky)
	world = World.new(); add_child(world)
	world.build()
	rig = Rig.new(); add_child(rig)
	rig.impact.connect(_on_impact)
	traffic = Traffic.new(); add_child(traffic)
	traffic.setup(world, rig)
	cams = Cameras.new(); add_child(cams)
	cams.setup(rig)
	hud = Hud.new(); add_child(hud)
	hud.action.connect(_on_action)
	for n in [sky, world, rig, traffic, cams]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	if OS.has_environment("KNC_Q"):
		quality = int(OS.get_environment("KNC_Q"))
	sky.set_quality(quality)
	_prepare(0)
	_show_menu()
	_dev_hooks()


func _setup_input() -> void:
	var keys := {
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT], "throttle": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
		"gear": [KEY_R], "parking": [KEY_SPACE], "blink_left": [KEY_Q], "blink_right": [KEY_E], "hazard": [KEY_F],
		"lights": [KEY_L], "wipers": [KEY_P], "retarder": [KEY_T], "camera": [KEY_C],
		"look_left": [KEY_Z], "look_right": [KEY_X], "confirm": [KEY_ENTER, KEY_KP_ENTER], "pause": [KEY_ESCAPE], "help": [KEY_F1], "rescue": [KEY_BACKSPACE],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var axes := {"steer_left": [JOY_AXIS_LEFT_X, -1.0], "steer_right": [JOY_AXIS_LEFT_X, 1.0], "throttle": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "brake": [JOY_AXIS_TRIGGER_LEFT, 1.0]}
	for a in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axes[a][0]
		ev.axis_value = axes[a][1]
		InputMap.action_add_event(a, ev)
	var pads := {"parking": JOY_BUTTON_A, "gear": JOY_BUTTON_X, "camera": JOY_BUTTON_Y, "blink_left": JOY_BUTTON_LEFT_SHOULDER, "blink_right": JOY_BUTTON_RIGHT_SHOULDER,
		"lights": JOY_BUTTON_DPAD_UP, "wipers": JOY_BUTTON_DPAD_DOWN, "retarder": JOY_BUTTON_DPAD_RIGHT, "pause": JOY_BUTTON_START, "confirm": JOY_BUTTON_B}
	for a in pads:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pads[a]
		InputMap.action_add_event(a, ev)


# ---------------------------------------------------------------- zlecenie

## Ustawia świat pod zlecenie: warunki, masę, zestaw na miejscu startu.
func _prepare(idx: int) -> void:
	c_idx = idx % CONTRACTS.size()
	contract = CONTRACTS[c_idx].duplicate(true)
	var lap := idx / CONTRACTS.size()
	contract["n"] = idx + 1
	contract["rate"] = int(contract["rate"] * (1.0 + 0.2 * lap))
	contract["window"] = contract["window"] - 25.0 * lap
	sky.set_time(contract["time"], true)
	sky.set_rain(contract["rain"])
	world.set_night(sky.is_night())
	traffic.clear()
	traffic.set_night(sky.is_night())
	traffic.density = 1.0 + 0.15 * lap
	rig.set_cargo(contract["mass"])
	rig.set_grip(sky.grip())
	rig.place(world.spawn_pos, world.spawn_dir)
	rig.gear = 1
	rig.parking = true
	rig.retarder = 0
	rig.blinker = 0
	rig.wipers = 0
	rig.lights = 0
	rig.throttle = 0.0
	rig.brake_in = 0.0
	rig.steer_in = 0.0
	rig.controls_enabled = false
	cams.snap()
	bay_num = contract["bay"]
	t_left = contract["window"]
	cargo = 100.0
	stage = 0
	hits = 0
	_hint_lights = 0.0
	_wrong_exit = false
	events = {}
	for e in contract["events"]:
		match e:
			"breakdown": events[e] = {"z": randf_range(950.0, 2300.0), "done": false, "placed": false}
			"rain": events[e] = {"z": randf_range(700.0, 1400.0), "done": false}
			"rebook": events[e] = {"z": 2250.0, "done": false}


func _conditions() -> String:
	var s: String = sky.label()
	if contract["events"].has("rain"):
		s += ", możliwy deszcz"
	return s


func _show_menu() -> void:
	state = "menu"
	get_tree().paused = false
	hud.set_hud_visible(false)
	var rows := [["Ładunek", contract["cargo"]], ["Masa ładunku", "%d t" % int(contract["mass"] / 1000.0)], ["Rampa", str(contract["bay"])],
		["Okno rozładunku zamyka się za", Hud.fmt_time(contract["window"])], ["Warunki", _conditions()], ["Stawka", Hud.fmt_zl(contract["rate"])]]
	var lead := "Dowieź ładunek z MOP-u do centrum logistycznego i cofnij naczepę pod wyznaczoną rampę, zanim zamknie się okno rozładunku."
	hud.show_board("Zlecenie nr %d" % contract["n"], "Kurs na czas 3D", lead, rows,
		[["Ruszaj", "start"], ["Inne zlecenie", "next"], ["Grafika: " + QUALITY_NAMES[quality], "quality"]], contract["note"])


func _start() -> void:
	_prepare(contract["n"] - 1)
	state = "drive"
	get_tree().paused = false
	rig.controls_enabled = true
	rig.lights = 1 if sky.is_night() else 0
	hud.hide_overlay()
	hud.set_hud_visible(true)
	hud.help.visible = true
	_help_t = 0.0
	hud.dispatcher("Zlecenie nr %d: %s, rampa %d. Zwolnij hamulec postojowy (Spacja) i ruszaj. Kamerę zmienisz klawiszem C." % [contract["n"], contract["cargo"], bay_num], 9.0)


func _on_action(act: String, _arg) -> void:
	match act:
		"start": _start()
		"next":
			_prepare(contract["n"])
			_show_menu()
		"quality":
			quality = (quality + 2) % 3
			sky.set_quality(quality)
			_show_menu()
		"resume": _resume()
		"retry":
			if state == "result": career -= last_result
			_start()
		"menu":
			_prepare(contract["n"] - 1)
			_show_menu()
		"next_contract":
			_prepare(contract["n"])
			_show_menu()
		"quit": get_tree().quit()


func _pause() -> void:
	if state != "drive":
		return
	state = "pause"
	get_tree().paused = true
	hud.show_board("Zlecenie nr %d · %s" % [contract["n"], contract["cargo"]], "Postój", "", [],
		[["Jedź dalej", "resume"], ["Kurs od nowa", "retry"], ["Menu", "menu"]], Hud.HELP_TEXT)


func _resume() -> void:
	if state != "pause":
		return
	state = "drive"
	get_tree().paused = false
	hud.hide_overlay()


# ---------------------------------------------------------------- pętla gry

func _physics_process(delta: float) -> void:
	if state != "drive":
		return
	rig.steer_in = Input.get_axis("steer_right", "steer_left")
	rig.throttle = Input.get_action_strength("throttle")
	rig.brake_in = Input.get_action_strength("brake")
	cams.look = Input.get_axis("look_left", "look_right")
	var pos: Vector3 = rig.tractor.global_position
	var off: bool = not world.is_paved(pos)
	if off != rig.offroad:
		rig.offroad = off
		rig._apply_grip()
	if not is_equal_approx(rig.grip, sky.grip()):
		rig.set_grip(sky.grip())
	world.update_gate(pos, delta)
	t_left -= delta
	# ściąga klawiszy znika po pół minuty jazdy; F1 przywraca
	if _help_t >= 0.0:
		_help_t += delta
		if _help_t > 30.0:
			_help_t = -1.0
			hud.help.visible = false
	_update_stage(pos)
	_update_events(pos)
	if t_left < -120.0:
		_fail("Okno rozładunku zamknęło się ponad 2 minuty temu. Rampa przyjęła następny zestaw.")


func _update_stage(pos: Vector3) -> void:
	var c: Curve3D = world.main_curve
	match stage:
		0:
			var d := c.get_closest_offset(pos)
			var f: Array = world._frame(c, d)
			var lat: float = (pos - f[0]).dot(f[2])
			if pos.z > 240.0 and lat > -4.0 and lat < 4.2:
				stage = 1
				hud.toast("Na drodze ekspresowej. Ogranicznik: 90 km/h")
		1:
			if pos.distance_to(World.RB_C) < 80.0:
				stage = 2
		2:
			if pos.x < -95.0 and absf(pos.z - 3260.0) < 14.0:
				stage = 3
			elif pos.z > 3335.0 and pos.x > -40.0 and not _wrong_exit:
				_wrong_exit = true
				hud.toast("To zjazd na Toruń. Backspace: powrót na trasę (−30 s)", 6.0, true)
		3:
			if pos.x < -343.0 and absf(pos.z - 3260.0) < 40.0:
				stage = 4
				hud.dispatcher("Jesteś na placu. Rampa %d — numer jest nad bramą i na nawierzchni. Cofnij naczepę pod odboje, zaciągnij postojowy i zgłoś rozładunek (Enter)." % bay_num, 10.0)
		4:
			_update_dock()


func _bay() -> Dictionary:
	return world.bays[bay_num - 1]


## Odchyłki naczepy względem rampy: bok (m), odległość od odbojów (m), kąt (stopnie).
func dock_error() -> Dictionary:
	var b := _bay()
	var rear: Vector3 = rig.trailer_rear()
	var bp: Vector3 = b["pos"]
	var bd: Vector3 = b["dir"]
	var h: Vector3 = rig.trailer_heading()
	return {"lat": rear.x - bp.x, "dist": (rear - bp).dot(bd), "ang": rad_to_deg(atan2(h.cross(bd).y, h.dot(bd)))}


func _update_dock() -> void:
	var e := dock_error()
	if absf(e["lat"]) < 30.0 and e["dist"] < 45.0:
		var side := "w lewo" if e["lat"] > 0.0 else "w prawo"
		hud.show_dock("RAMPA %d\nbok: %d cm %s\nkąt: %.1f°\ndo odbojów: %.1f m" % [bay_num, int(absf(e["lat"]) * 100.0), side, absf(e["ang"]), maxf(0.0, e["dist"])])
	else:
		hud.show_dock("")
	_dock_msg_cd = maxf(0.0, _dock_msg_cd - get_physics_process_delta_time())


func _try_dock() -> void:
	if stage != 4:
		hud.toast("Rozładunek zgłosisz dopiero pod rampą")
		return
	var e := dock_error()
	if absf(rig.speed) > 0.15 or not rig.parking:
		hud.toast("Zatrzymaj zestaw i zaciągnij hamulec postojowy (Spacja)")
	elif absf(e["lat"]) > 3.0:
		hud.toast("To nie ta rampa. Twoja ma numer %d" % bay_num, 3.5, true)
	elif e["dist"] > 1.0:
		hud.toast("Za daleko od rampy: %.1f m" % e["dist"], 3.0)
	elif absf(e["lat"]) > 0.6:
		hud.toast("Za bardzo z boku: %d cm. Popraw ustawienie" % int(absf(e["lat"]) * 100.0), 3.0)
	elif absf(e["ang"]) > 6.0:
		hud.toast("Naczepa stoi krzywo: %.0f°. Popraw ustawienie" % absf(e["ang"]), 3.0)
	else:
		_finish(e)


func _update_events(pos: Vector3) -> void:
	if sky.is_night() and rig.lights == 0:
		_hint_lights += get_physics_process_delta_time()
		if _hint_lights > 8.0:
			_hint_lights = -60.0
			hud.dispatcher("Jedziesz bez świateł. Włącz mijania klawiszem L.", 6.0)
	if stage > 2:
		return
	for k in events:
		var ev: Dictionary = events[k]
		if ev["done"]:
			continue
		match k:
			"breakdown":
				if not ev["placed"]:
					ev["placed"] = true
					traffic.add_breakdown(ev["z"])
				if pos.z > ev["z"] - 420.0 and pos.x > -30.0:
					ev["done"] = true
					hud.dispatcher("Uwaga: zepsuty pojazd za 400 m, stoi na pasie awaryjnym i wystaje na prawy pas. Zjedź na lewy.", 8.0)
			"rain":
				if pos.z > ev["z"]:
					ev["done"] = true
					sky.set_rain(1.0, 35.0)
					hud.dispatcher("Front z deszczem nad trasą. Jezdnia robi się śliska: zwolnij, zwiększ odstęp, włącz wycieraczki (P).", 9.0)
			"rebook":
				if pos.z > ev["z"]:
					ev["done"] = true
					var free := []
					for b in world.bays:
						if b["free"] and b["num"] != bay_num:
							free.append(b["num"])
					var old := bay_num
					bay_num = free[randi() % free.size()]
					hud.dispatcher("Zmiana awizacji: rampa %d jest zajęta. Podjedź pod rampę %d." % [old, bay_num], 10.0)


func _on_impact(dv: float, what: String) -> void:
	if state != "drive":
		return
	var pct: float = clampf(dv * 4.0, 1.0, 45.0) * contract["frag"]
	cargo = maxf(0.0, cargo - pct)
	hits += 1
	hud.toast("Uderzenie (%s): −%d%% ładunku" % [what, maxi(1, int(round(pct)))], 2.4, true)
	if cargo <= 0.0:
		_fail("Ładunek nie nadaje się do odbioru. Odbiorca odmówił przyjęcia towaru.")


func _rescue() -> void:
	if state != "drive":
		return
	var c: Curve3D = world.main_curve
	var p: Vector3 = world.spawn_pos
	var d: Vector3 = world.spawn_dir
	match stage:
		1:
			var off := clampf(c.get_closest_offset(rig.tractor.global_position) - 30.0, 600.0, c.get_baked_length() - 80.0)
			var f: Array = world._frame(c, off)
			p = f[0] + f[2] * 1.75
			d = f[1]
		2:
			p = Vector3(2, 0, 3140)
			d = Vector3(0, 0, 1)
		3:
			p = Vector3(-140, 0, 3258.25)
			d = Vector3(-1, 0, 0)
		4:
			p = Vector3(-352, 0, 3256)
			d = Vector3(-1, 0, 0)
	rig.place(p, d)
	rig.gear = 1
	rig.parking = true
	cams.snap()
	t_left -= 30.0
	_wrong_exit = false
	hud.toast("Powrót na trasę: −30 s. Zwolnij postojowy (Spacja)", 4.0)


func _finish(e: Dictionary) -> void:
	state = "result"
	rig.controls_enabled = false
	hud.show_dock("")
	hud.set_hud_visible(false)
	var rate: int = contract["rate"]
	var lat_cm := int(round(absf(e["lat"]) * 100.0))
	var ang: float = absf(e["ang"])
	var bonus := int(minf(rate * 0.25, maxf(0.0, t_left) * 5.0))
	var late := int(maxf(0.0, -t_left) * 20.0)
	var dmg := 100 - int(ceil(cargo))
	var cut := int(rate * dmg / 100.0 * 1.2)
	var grade := "do przyjęcia"
	var prec := 0
	if lat_cm <= 15 and ang <= 1.5:
		grade = "wzorowo"
		prec = int(rate * 0.1)
	elif lat_cm <= 35 and ang <= 3.0:
		grade = "dobrze"
		prec = int(rate * 0.04)
	var net := maxi(0, rate + bonus + prec - late - cut)
	last_result = net
	career += net
	var rows := [["Ładunek", contract["cargo"]], ["Czas przejazdu", "%s z %s" % [Hud.fmt_time(contract["window"] - t_left), Hud.fmt_time(contract["window"])]],
		["Stan ładunku", "%d%%" % (100 - dmg)], ["Ustawienie pod rampą %d" % bay_num, "%s (%d cm, %.1f°)" % [grade, lat_cm, ang]], ["Stawka", Hud.fmt_zl(rate)]]
	if bonus > 0: rows.append(["Premia za czas", Hud.fmt_zl(bonus)])
	if prec > 0: rows.append(["Premia za ustawienie", Hud.fmt_zl(prec)])
	if late > 0: rows.append(["Kara umowna za spóźnienie", Hud.fmt_zl(-late)])
	if cut > 0: rows.append(["Potrącenie za szkody (%d%%)" % dmg, Hud.fmt_zl(-cut)])
	rows.append(["Do wypłaty", Hud.fmt_zl(net)])
	rows.append(["Zarobek w tej karierze", Hud.fmt_zl(career)])
	hud.show_board("List przewozowy nr %04d" % contract["n"], "Dostarczono", "", rows, [["Następne zlecenie", "next_contract"], ["Powtórz kurs", "retry"]])


func _fail(reason: String) -> void:
	if state != "drive":
		return
	state = "result"
	last_result = 0
	rig.controls_enabled = false
	hud.show_dock("")
	hud.set_hud_visible(false)
	hud.show_board("List przewozowy nr %04d" % contract["n"], "Anulowano", reason, [["Ładunek", contract["cargo"]], ["Stan ładunku", "%d%%" % int(ceil(cargo))], ["Do wypłaty", Hud.fmt_zl(0)]],
		[["Spróbuj ponownie", "retry"], ["Menu", "menu"]])


func _objective_distance(pos: Vector3) -> float:
	var c: Curve3D = world.main_curve
	match stage:
		0, 1: return maxf(0.0, c.get_baked_length() - c.get_closest_offset(pos)) + 170.0
		2: return pos.distance_to(Vector3(-90, 0, 3256))
		3: return pos.distance_to(world.gate_pos)
		4: return maxf(0.0, rig.trailer_rear().distance_to(_bay()["pos"]))
	return -1.0


func _process(_delta: float) -> void:
	if state != "drive":
		return
	var pos: Vector3 = rig.tractor.global_position
	var obj: String = OBJECTIVES[stage]
	if stage == 4:
		obj = obj % bay_num
	var line2 := ""
	if rig.parking and rig.throttle > 0.1: line2 = "Hamulec postojowy zaciągnięty — zwolnij go Spacją"
	elif rig.offroad and absf(rig.speed) > 1.0: line2 = "Poza jezdnią: gorsza przyczepność i większe opory"
	elif absf(rig.articulation) > 1.2: line2 = "Zestaw mocno złamany — wyprostuj, jadąc do przodu"
	hud.state = {"kmh": absf(rig.speed) * 3.6, "gear": "P" if rig.parking else ("D" if rig.gear == 1 else "R"),
		"bl": rig.blink_on and (rig.blinker == 1 or rig.blinker == 2), "br": rig.blink_on and (rig.blinker == -1 or rig.blinker == 2),
		"parking": rig.parking, "lights": rig.lights, "lights_txt": ["ŚW", "MIJ", "DROG"][rig.lights], "retarder": rig.retarder, "wipers": rig.wipers,
		"line1": "Kamera: %s  ·  %s" % [Cameras.NAMES[cams.mode].to_lower(), sky.label()], "line2": line2, "art": rig.articulation}
	hud.update_drive(t_left, obj, _objective_distance(pos), cargo, "Zlecenie %d · rampa %d" % [contract["n"], bay_num])


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if state == "drive": _pause()
		elif state == "pause": _resume()
		return
	if state != "drive":
		return
	if e.is_action_pressed("camera"): cams.set_mode(cams.mode + 1)
	elif e.is_action_pressed("parking"): rig.parking = not rig.parking
	elif e.is_action_pressed("gear"):
		if absf(rig.speed) < 1.0: rig.gear = -1 if rig.gear == 1 else 1
		else: hud.toast("Kierunek jazdy zmienisz po zatrzymaniu")
	elif e.is_action_pressed("lights"): rig.lights = (rig.lights + 1) % 3
	elif e.is_action_pressed("wipers"): rig.wipers = (rig.wipers + 1) % 3
	elif e.is_action_pressed("retarder"): rig.retarder = (rig.retarder + 1) % 4
	elif e.is_action_pressed("blink_left"): rig.blinker = 0 if rig.blinker == 1 else 1
	elif e.is_action_pressed("blink_right"): rig.blinker = 0 if rig.blinker == -1 else -1
	elif e.is_action_pressed("hazard"): rig.blinker = 0 if rig.blinker == 2 else 2
	elif e.is_action_pressed("confirm"): _try_dock()
	elif e.is_action_pressed("rescue"): _rescue()
	elif e.is_action_pressed("help"): hud.help.visible = not hud.help.visible


# ---------------------------------------------------------------- haki deweloperskie

## Zmienne środowiskowe do zrzutów ekranu: KNC_SHOT (plik), KNC_AT (miejsce), KNC_CAM, KNC_TIME, KNC_RAIN, KNC_C (zlecenie), KNC_MENU=1.
func _dev_hooks() -> void:
	if not OS.has_environment("KNC_SHOT"):
		return
	var E := func(k: String, d: String) -> String: return OS.get_environment(k) if OS.has_environment(k) else d
	_prepare(int(E.call("KNC_C", "0")))
	if E.call("KNC_MENU", "0") == "1":
		_show_menu()
	else:
		_start()
		if OS.has_environment("KNC_TIME"): sky.set_time(E.call("KNC_TIME", "day"), true)
		if OS.has_environment("KNC_RAIN"): sky.set_rain(float(E.call("KNC_RAIN", "0")))
		world.set_night(sky.is_night())
		traffic.set_night(sky.is_night())
		rig.lights = 1 if sky.is_night() else 0
		var at: String = E.call("KNC_AT", "")
		var c: Curve3D = world.main_curve
		match at:
			"road":
				var f: Array = world._frame(c, 1500.0)
				rig.place(f[0] + f[2] * 1.75, f[1])
				stage = 1
				for i in 5:
					traffic.spawn("right" if i % 2 == 0 else "left", world.paths["right"].get_closest_offset(f[0]) + 45.0 + i * 38.0)
				traffic.spawn("oncoming", world.paths["oncoming"].get_closest_offset(f[0]) - 80.0)
			"rb":
				rig.place(Vector3(2, 0, 3150), Vector3(0, 0, 1))
				stage = 2
			"yard":
				rig.place(Vector3(-372, 0, 3256), Vector3(-1, 0, 0))
				stage = 4
			"dock":
				rig.place(Vector3(_bay()["pos"].x + 0.1, 0, World.DOCK_Z - 12.4), Vector3(0, 0, -1))
				stage = 4
		rig.parking = at == "dock"
		cams.snap()
		if OS.has_environment("KNC_CAM"): cams.set_mode(int(E.call("KNC_CAM", "1")))
		if E.call("KNC_RESULT", "0") == "1":
			await get_tree().create_timer(1.0).timeout
			_try_dock()
	await get_tree().create_timer(float(E.call("KNC_WAIT", "2.5"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("KNC_SHOT"))
	print("zapisano ", OS.get_environment("KNC_SHOT"))
	get_tree().quit()
