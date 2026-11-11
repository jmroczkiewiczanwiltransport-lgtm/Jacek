extends Node3D
## Ruch uliczny: pojazdy jadą po torach z world.paths, trzymają odstęp i ustępują na rondzie.
## Pojazdy są kinematyczne (AnimatableBody3D) — zestaw gracza zderza się z nimi fizycznie.

const Kit = preload("res://scripts/kit.gd")
const World = preload("res://scripts/world.gd")

const KINDS := {
	"car":   {"size": Vector3(1.8, 1.45, 4.5), "wheel": 0.32, "axles": [1.4, -1.35]},
	"suv":   {"size": Vector3(1.92, 1.72, 4.7), "wheel": 0.36, "axles": [1.45, -1.4]},
	"van":   {"size": Vector3(2.0, 2.5, 5.7), "wheel": 0.36, "axles": [1.9, -1.7]},
	"truck": {"size": Vector3(2.5, 3.6, 8.6), "wheel": 0.5, "axles": [3.2, -2.3, -3.4]},
}
const COLORS := [Color(0.55, 0.06, 0.05), Color(0.08, 0.2, 0.45), Color(0.78, 0.79, 0.8), Color(0.05, 0.05, 0.06), Color(0.4, 0.42, 0.45), Color(0.75, 0.6, 0.1), Color(0.1, 0.3, 0.2), Color(0.9, 0.9, 0.9)]

var world
var rig
var cars: Array = []
var density := 1.0
var night := false
var max_cars := 14
var enabled := true

var _rng := RandomNumberGenerator.new()
var _spawn_t := 0.0
var _blink := 0.0


func setup(w, r) -> void:
	world = w
	rig = r
	_rng.randomize()


func clear() -> void:
	for c in cars:
		c.body.queue_free()
	cars.clear()


func set_night(on: bool) -> void:
	night = on
	for c in cars:
		_apply_lights(c)


# ---------------------------------------------------------------- budowa pojazdu

func _make(kind: String) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var s: Vector3 = k["size"]
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.set_meta("label", "inny pojazd")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(s.x, s.y - 0.3, s.z)
	cs.shape = bs
	cs.position = Vector3(0, s.y * 0.5 + 0.15, 0)
	body.add_child(cs)
	var paint := Kit.paint(COLORS[_rng.randi() % COLORS.size()])
	var dark := Kit.mat(Color(0.05, 0.05, 0.055), 0.75)
	var head := Kit.lamp(Color(1.0, 0.96, 0.86))
	var tail := Kit.lamp(Color(1.0, 0.06, 0.03))
	var blink := Kit.lamp(Color(1.0, 0.55, 0.05))
	var r: float = k["wheel"]
	if kind == "truck":
		Kit.box(body, Vector3(2.3, 0.35, 8.4), dark, Vector3(0, 0.85, 0), 0.03)
		Kit.box(body, Vector3(2.45, 2.5, 2.1), paint, Vector3(0, 2.1, 3.2), 0.15)
		Kit.box(body, Vector3(2.25, 0.85, 0.05), Kit.glass(), Vector3(0, 2.6, 4.26), 0.02)
		Kit.box(body, Vector3(2.5, 2.7, 6.2), Kit.mat(Color(0.82, 0.83, 0.84), 0.5), Vector3(0, 2.4, -1.15), 0.06)
	else:
		var h := s.y
		var van := kind == "van"
		Kit.box(body, Vector3(s.x, h * (0.72 if van else 0.46), s.z), paint, Vector3(0, 0.3 + h * (0.36 if van else 0.23), 0), 0.14)
		if van:
			Kit.box(body, Vector3(s.x - 0.1, 0.62, 0.06), Kit.glass(), Vector3(0, 1.75, s.z * 0.5 - 0.02), 0.02, Vector3(-8, 0, 0))
			Kit.box(body, Vector3(s.x - 0.04, 0.5, 1.1), Kit.glass(), Vector3(0, 1.8, s.z * 0.5 - 0.9), 0.03)
		else:
			Kit.box(body, Vector3(s.x - 0.18, h * 0.4, s.z * 0.52), Kit.glass(Color(0.04, 0.06, 0.08, 0.8)), Vector3(0, 0.3 + h * 0.63, -0.2), 0.12)
			Kit.box(body, Vector3(s.x - 0.3, 0.05, s.z * 0.42), paint, Vector3(0, 0.3 + h * 0.84, -0.2), 0.02)
	for z in k["axles"]:
		for sx in [-1.0, 1.0]:
			var w := Kit.wheel(r, 0.22 if kind != "truck" else 0.3)
			w.position = Vector3(sx * (s.x * 0.5 - 0.12), r, z)
			if sx < 0.0: w.rotation_degrees.y = 180.0
			body.add_child(w)
	var ly := 0.72 if kind != "truck" else 1.0
	for sx in [-1.0, 1.0]:
		Kit.box(body, Vector3(0.38, 0.14, 0.05), head, Vector3(sx * (s.x * 0.5 - 0.32), ly, s.z * 0.5 + 0.005), 0.02)
		Kit.box(body, Vector3(0.36, 0.14, 0.05), tail, Vector3(sx * (s.x * 0.5 - 0.3), ly + 0.1, -s.z * 0.5 - 0.005), 0.02)
		Kit.box(body, Vector3(0.12, 0.12, 0.06), blink, Vector3(sx * (s.x * 0.5 - 0.07), ly + 0.1, -s.z * 0.5), 0.02)
		Kit.box(body, Vector3(0.12, 0.12, 0.06), blink, Vector3(sx * (s.x * 0.5 - 0.07), ly, s.z * 0.5), 0.02)
	var sp := SpotLight3D.new()
	sp.position = Vector3(0, ly, s.z * 0.5 + 0.1)
	sp.rotation_degrees = Vector3(-6, 180, 0)
	sp.spot_range = 45.0
	sp.spot_angle = 38.0
	sp.light_energy = 5.0
	sp.light_color = Color(1.0, 0.95, 0.85)
	sp.shadow_enabled = false
	body.add_child(sp)
	add_child(body)
	var c := {"body": body, "kind": kind, "hl": s.z * 0.5, "hw": s.x * 0.5, "head": head, "tail": tail, "blink": blink, "spot": sp,
		"path": null, "d": 0.0, "v": 0.0, "vt": 0.0, "static": false, "braking": false}
	_apply_lights(c)
	return c


func _apply_lights(c: Dictionary) -> void:
	c.head.emission_energy_multiplier = 4.0 if night else 0.6
	c.spot.visible = night and not c.static
	c.tail.emission_energy_multiplier = 4.5 if c.braking else (1.2 if night else 0.0)


# ---------------------------------------------------------------- rozmieszczanie

func _place(c: Dictionary) -> void:
	var curve: Curve3D = c.path
	var length := curve.get_baked_length()
	var p := curve.sample_baked(c.d)
	var t := (curve.sample_baked(minf(c.d + 1.5, length)) - curve.sample_baked(maxf(c.d - 1.5, 0.0)))
	t.y = 0.0
	if t.length_squared() < 0.0001:
		t = Vector3(0, 0, 1)
	c.body.global_transform = Transform3D(Basis.looking_at(-t.normalized()), p + c.get("side", Vector3.ZERO))


func spawn(path_name: String, d: float, kind := "") -> Dictionary:
	var curve: Curve3D = world.paths[path_name]
	if kind == "":
		var r := _rng.randf()
		if path_name == "left": kind = "car" if r < 0.7 else "suv"
		else: kind = "truck" if r < 0.34 else ("van" if r < 0.52 else ("suv" if r < 0.7 else "car"))
	var c := _make(kind)
	c.path = curve
	c.pname = path_name
	c.d = clampf(d, 0.0, curve.get_baked_length() - 1.0)
	if kind == "truck": c.vt = _rng.randf_range(20.5, 23.5)
	elif path_name == "left": c.vt = _rng.randf_range(29.0, 35.0)
	else: c.vt = _rng.randf_range(24.0, 29.5)
	c.v = c.vt
	_place(c)
	cars.append(c)
	return c


## Zdarzenie: zepsuty pojazd wystający z pasa awaryjnego na prawy pas.
func add_breakdown(z: float) -> Vector3:
	var curve: Curve3D = world.paths["right"]
	var d := curve.get_closest_offset(Vector3(world.main_curve.sample_baked(world._d_at_z(world.main_curve, z)).x, 0, z))
	var c := _make("van" if _rng.randf() < 0.5 else "car")
	c.path = curve
	c.pname = "right"
	c.d = d
	c.static = true
	var f: Array = world._frame(curve, d)
	c.side = f[2] * 2.25
	c.body.set_meta("label", "zepsuty pojazd")
	_place(c)
	_apply_lights(c)
	cars.append(c)
	# trójkąt ostrzegawczy 60 m wcześniej
	var tri := Kit.cyl(self, 0.3, 0.5, Kit.mat(Color(0.85, 0.08, 0.05), 0.5), curve.sample_baked(d - 60.0) + f[2] * 2.6 + Vector3(0, 0.25, 0), Vector3.ZERO, 0.0)
	tri.mesh.radial_segments = 3
	c.extra = tri
	return c.body.global_position


func _path_spawn_ok(curve: Curve3D, d: float, side := Vector3.ZERO) -> bool:
	var p := curve.sample_baked(d) + side
	for c in cars:
		if c.body.global_position.distance_to(p) < 34.0:
			return false
	var rp: Vector3 = rig.tractor.global_position
	return p.distance_to(rp) > 90.0 and p.distance_to(rig.trailer.global_transform * Vector3(0, 0, -6)) > 90.0


func _try_spawn() -> void:
	var moving := 0
	for c in cars:
		if not c.static: moving += 1
	if moving >= int(max_cars * density):
		return
	var rp: Vector3 = rig.tractor.global_position
	var r := _rng.randf()
	var pname := "right" if r < 0.36 else ("left" if r < 0.56 else "oncoming")
	var curve: Curve3D = world.paths[pname]
	var dp := curve.get_closest_offset(rp)
	var d := 0.0
	if pname == "oncoming":
		d = dp - _rng.randf_range(320.0, 620.0)
	elif pname == "left":
		d = dp - _rng.randf_range(160.0, 330.0) if _rng.randf() < 0.65 else dp + _rng.randf_range(300.0, 560.0)
	else:
		d = dp + _rng.randf_range(260.0, 560.0) if _rng.randf() < 0.75 else dp - _rng.randf_range(180.0, 320.0)
	if d < 5.0 or d > curve.get_baked_length() - 60.0:
		return
	# nie wstawiamy pojazdów na rondzie ani tuż przed nim
	if curve.sample_baked(d).distance_to(World.RB_C) < 130.0:
		return
	if _path_spawn_ok(curve, d):
		spawn(pname, d)


# ---------------------------------------------------------------- jazda

func _limit_at(p: Vector3) -> float:
	var dr := p.distance_to(World.RB_C)
	if dr < 34.0: return 7.0
	if dr < 110.0: return lerpf(7.5, 14.0, (dr - 34.0) / 76.0)
	if p.z > 3300.0: return 19.4
	if p.z > 2950.0: return 14.0
	if p.z > 2700.0: return 19.4
	return 99.0


func _physics_process(delta: float) -> void:
	if not enabled or rig == null:
		return
	_blink += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.6
		_try_spawn()
	# przeszkody: inne pojazdy oraz dwa człony zestawu gracza
	var obs := []
	for c in cars:
		obs.append([c.body.global_position, c.hl, c.hw, c.v, c])
	var tr: Transform3D = rig.tractor.global_transform
	var tl: Transform3D = rig.trailer.global_transform
	var pv: float = rig.tractor.linear_velocity.length()
	obs.append([tr * Vector3(0, 0, 1.0), 3.1, 1.3, pv, null])
	obs.append([tl * Vector3(0, 0, -5.2), 6.9, 1.3, pv, null])
	var rp := tr.origin
	var dead := []
	for c in cars:
		var body: AnimatableBody3D = c.body
		var pos := body.global_position
		if c.static:
			var on := fmod(_blink, 0.8) < 0.4
			c.blink.emission_energy_multiplier = 4.0 if on else 0.0
			if pos.distance_to(rp) > 900.0 and pos.z < rp.z: dead.append(c)
			continue
		var fwd := body.global_basis.z
		var gap := 1e9
		var lead_v := 0.0
		for o in obs:
			if o[4] == c: continue
			var rel: Vector3 = o[0] - pos
			var ahead := rel.dot(fwd)
			if ahead <= 0.0 or ahead > 90.0: continue
			var lat := absf(rel.cross(fwd).y)
			if lat > c.hw + o[2] + 0.35: continue
			var g: float = ahead - o[1] - c.hl
			if g < gap:
				gap = g
				lead_v = maxf(0.0, o[3]) if o[4] == null else o[3]
		var want: float = minf(c.vt, _limit_at(pos))
		# pierwszeństwo na rondzie: przed wjazdem sprawdź, czy z lewej ktoś nadjeżdża po pierścieniu
		var dr := pos.distance_to(World.RB_C)
		var inward := (World.RB_C - pos).normalized().dot(fwd) > 0.5
		if inward and dr > World.RB_OUT + 1.0 and dr < World.RB_OUT + 20.0:
			var a_me := atan2(pos.z - World.RB_C.z, pos.x - World.RB_C.x)
			for o in obs:
				if o[4] == c: continue
				var q: Vector3 = o[0]
				if q.distance_to(World.RB_C) > World.RB_OUT + 1.0: continue
				var da := wrapf(atan2(q.z - World.RB_C.z, q.x - World.RB_C.x) - a_me, -PI, PI)
				if da > -0.25 and da < 1.25:
					gap = minf(gap, dr - World.RB_OUT - 3.0 - c.hl)
					lead_v = 0.0
		if gap < 85.0:
			want = minf(want, maxf(0.0, lead_v + (gap - (4.0 + c.v * 0.9)) * 0.5))
		var dv: float = want - c.v
		c.v = maxf(0.0, c.v + clampf(dv, -6.0 * delta, 1.6 * delta))
		var braking: bool = dv < -1.0
		if braking != c.braking:
			c.braking = braking
			_apply_lights(c)
		c.d += c.v * delta
		var curve: Curve3D = c.path
		if c.d >= curve.get_baked_length() - 2.0 or pos.distance_to(rp) > 1100.0:
			dead.append(c)
			continue
		_place(c)
	for c in dead:
		if c.has("extra"): c.extra.queue_free()
		c.body.queue_free()
		cars.erase(c)
