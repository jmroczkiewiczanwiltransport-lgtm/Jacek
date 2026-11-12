extends SceneTree
## Test fizyki zestawu bez okna:  godot --headless --path . -s tests/sim_test.gd
const Rig = preload("res://scripts/rig.gd")
var rig
var t := 0.0
var step := 0
var mark := {}
var out: Array[String] = []

func _initialize() -> void:
	var root3 := Node3D.new(); root.add_child(root3)
	var ground := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); ground.add_child(cs); root3.add_child(ground)
	rig = Rig.new(); root3.add_child(rig)

func _log(s: String) -> void:
	out.append(s); print(s)

func _physics_process(delta: float) -> bool:
	t += delta
	var kmh: float = rig.speed * 3.6
	match step:
		0:
			if t > 2.0:
				_log("spoczynek: ciagnik y=%.3f naczepa y=%.3f, przechyl naczepy=%.2f st, masa=%.0f kg" % [rig.tractor.global_position.y, rig.trailer.global_position.y, rad_to_deg(rig.trailer.rotation.x), rig.total_mass()])
				rig.parking = false; rig.throttle = 1.0; mark.t0 = t; step = 1
		1:
			if not mark.has("t50") and kmh >= 50.0: mark.t50 = t - mark.t0
			if not mark.has("t80") and kmh >= 80.0: mark.t80 = t - mark.t0
			if t - mark.t0 > 60.0 or kmh >= 89.5:
				_log("rozpedzanie: 0-50 km/h %.1f s, 0-80 km/h %.1f s, v max po %.1f s = %.1f km/h" % [mark.get("t50", -1.0), mark.get("t80", -1.0), t - mark.t0, kmh])
				rig.throttle = 0.0; rig.brake_in = 1.0; mark.bz = rig.tractor.global_position.z; mark.bt = t; mark.bv = rig.speed; step = 2
		2:
			if absf(rig.speed) < 0.15:
				var d: float = rig.tractor.global_position.z - mark.bz
				_log("hamowanie z %.0f km/h: droga %.1f m, czas %.1f s (srednio %.2f m/s2), kat zlamania %.1f st" % [mark.bv * 3.6, d, t - mark.bt, mark.bv / (t - mark.bt), rad_to_deg(rig.articulation)])
				rig.brake_in = 0.0; rig.throttle = 0.5; rig.steer_in = 1.0; mark.t1 = t; mark.p1 = rig.tractor.global_position; mark.maxart = 0.0; step = 3
		3:
			mark.maxart = maxf(mark.maxart, absf(rig.articulation))
			if t - mark.t1 > 14.0:
				var yaw: float = rig.tractor.global_rotation.y
				_log("skret w lewo 14 s: v=%.1f km/h, obrot ciagnika %.0f st, maks. kat zlamania %.0f st, y ciagnika %.2f" % [kmh, rad_to_deg(yaw), rad_to_deg(mark.maxart), rig.tractor.global_position.y])
				rig.steer_in = 0.0; rig.throttle = 0.0; rig.brake_in = 1.0; step = 4
		4:
			if absf(rig.speed) < 0.1:
				rig.brake_in = 0.0; rig.gear = -1; rig.throttle = 0.6; rig.steer_in = -0.35; mark.t2 = t; mark.maxart = 0.0; step = 5
		5:
			mark.maxart = maxf(mark.maxart, absf(rig.articulation))
			if t - mark.t2 > 12.0:
				_log("cofanie ze skretem 12 s: v=%.1f km/h, kat zlamania teraz %.0f st (maks. %.0f st), pozycje skonczone=%s" % [kmh, rad_to_deg(rig.articulation), rad_to_deg(mark.maxart), str(rig.tractor.global_position.is_finite() and rig.trailer.global_position.is_finite())])
				return true
	if t > 150.0:
		_log("PRZEKROCZONO CZAS w kroku %d" % step); return true
	return false
