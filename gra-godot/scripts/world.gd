extends Node3D
## Mapa: MOP -> droga ekspresowa -> rondo -> droga do strefy przemysłowej -> plac z rampami.
## Kierunek jazdy trasą to +Z. Prawa strona jadącego to -X.
## Wszystko jest płaskie (y = 0) i powstaje w kodzie.

const Kit = preload("res://scripts/kit.gd")

const RB_C := Vector3(6, 0, 3260)       # środek ronda
const RB_IN := 15.0                     # wyspa
const RB_OUT := 26.0
const RB_MID := 20.5
const ARM_E := 4.0
const PHI := 0.42                       # kąt (rad) między osią wlotu a punktem włączenia na pierścień
const MAIN_END := 3100.0
const DOCK_Z := 3300.0
const YARD := Rect2(-485, 3185, 150, 115)   # x, z, szer., głęb.
const MASK_ORIGIN := Vector2(-700, -900)
const MASK_SIZE := Vector2i(500, 2600)      # piksel = 2 m

var main_curve: Curve3D
var paths := {}                 # tory dla ruchu: "right", "left", "oncoming"
var spawn_pos := Vector3(-43.75, 0, 16)
var spawn_dir := Vector3(0, 0, 1)
var bays: Array = []            # {num, pos, dir, free}
var gate_pos := Vector3(-335, 0, 3260)
var lamps: Array[Light3D] = []
var lamp_mat: StandardMaterial3D
var window_mat: StandardMaterial3D

var _mask: Image
var _static: StaticBody3D
var _rail_xf: Array[Transform3D] = []
var _post_xf: Array[Transform3D] = []
var _noise: NoiseTexture2D
var _nmap: NoiseTexture2D
var _road_shader: Shader
var _gate_arm: Node3D
var _gate_shape: CollisionShape3D
var _excl: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20260411
	_mask = Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
	_noise = Kit.noise_tex(11, 0.012)
	_nmap = Kit.noise_tex(23, 0.035, true, 512, 5.0)
	_road_shader = load("res://shaders/road.gdshader")
	lamp_mat = Kit.lamp(Color(1.0, 0.86, 0.62))
	window_mat = Kit.lamp(Color(1.0, 0.85, 0.6))
	_static = StaticBody3D.new()
	_static.name = "Static"
	add_child(_static)
	# Podłoże jako gruba płyta, nie WorldBoundaryShape3D: silnik Jolt ogranicza „nieskończoną” płaszczyznę
	# do ok. 1 km od jej środka, a mapa jest dłuższa.
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(12000, 6, 12000)
	gs.shape = gb
	gs.position = Vector3(-100, -3, 1700)
	_static.add_child(gs)
	_ground()
	_expressway()
	_mop()
	_roundabout()
	_north_road()
	_access_road()
	_depot()
	_scenery()
	_flush_rails()
	_trees()


# ---------------------------------------------------------------- pomocnicze

func _v(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)


func _d_at_z(curve: Curve3D, z: float) -> float:
	var lo := 0.0
	var hi := curve.get_baked_length()
	for i in 24:
		var mid := (lo + hi) * 0.5
		if curve.sample_baked(mid).z < z: lo = mid
		else: hi = mid
	return (lo + hi) * 0.5


func _frame(curve: Curve3D, d: float) -> Array:
	var length := curve.get_baked_length()
	var p := curve.sample_baked(clampf(d, 0.0, length))
	var t := curve.sample_baked(minf(d + 0.5, length)) - curve.sample_baked(maxf(d - 0.5, 0.0))
	t.y = 0.0
	t = t.normalized()
	return [p, t, t.cross(Vector3.UP)]


func _off(curve: Curve3D, d: float, off: float) -> Vector3:
	var f := _frame(curve, d)
	return f[0] + f[2] * off


func _off_pts(curve: Curve3D, off: float, from: float, to: float, step := 25.0) -> Array:
	var pts := []
	var d := from
	while d < to:
		pts.append(_off(curve, d, off))
		d += step
	pts.append(_off(curve, to, off))
	return pts


func _asphalt(solid := [], dash := [], base := Color(0.2, 0.2, 0.215), dash_zone := Vector2(-1, -1), dlen := 4.0, dgap := 8.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _road_shader
	m.set_shader_parameter("noise_tex", _noise)
	m.set_shader_parameter("normal_tex", _nmap)
	m.set_shader_parameter("base_color", base)
	var s := [-1.0, -1.0, -1.0, -1.0]
	var d := [-1.0, -1.0, -1.0, -1.0]
	for i in solid.size(): s[3 - i] = solid[solid.size() - 1 - i]   # ostatnia linia trafia do .w (może być przerywana na odcinku)
	for i in dash.size(): d[i] = dash[i]
	m.set_shader_parameter("solid_lines", Vector4(s[0], s[1], s[2], s[3]))
	m.set_shader_parameter("dash_lines", Vector4(d[0], d[1], d[2], d[3]))
	m.set_shader_parameter("edge_dash_zone", dash_zone)
	m.set_shader_parameter("dash_len", dlen)
	m.set_shader_parameter("dash_gap", dgap)
	return m


func _stamp(p: Vector3) -> void:
	var px := int((p.x - MASK_ORIGIN.x) / 2.0)
	var pz := int((p.z - MASK_ORIGIN.y) / 2.0)
	if px >= 0 and pz >= 0 and px < MASK_SIZE.x and pz < MASK_SIZE.y:
		_mask.set_pixel(px, pz, Color.WHITE)


func _stamp_rect(r: Rect2) -> void:
	var x := r.position.x
	while x <= r.end.x:
		var z := r.position.y
		while z <= r.end.y:
			_stamp(_v(x, z))
			z += 1.5
		x += 1.5


## Jezdnia wzdłuż krzywej; zaznacza też utwardzoną nawierzchnię w masce.
func _road(curve: Curve3D, off_l: float, off_r: float, mat: Material, y := 0.03, from := 0.0, to := -1.0) -> MeshInstance3D:
	var mi := Kit.part(self, Kit.ribbon(curve, off_l, off_r, y, 3.0, from, to), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if to < 0.0: to = curve.get_baked_length()
	var d := from
	while d <= to:
		var o := off_l
		while o <= off_r + 0.01:
			_stamp(_off(curve, d, o))
			o += 1.4
		d += 1.4
	return mi


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: Material, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	var o := Vector3(0, y, 0)
	Kit._tri(st, a + o, b + o, c + o, up, up, up, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
	Kit._tri(st, a + o, c + o, d + o, up, up, up, Vector2(a.x, a.z), Vector2(c.x, c.z), Vector2(d.x, d.z))
	st.generate_tangents()
	var mi := Kit.part(self, st.commit(), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 12:
		for j in 12:
			_stamp(a.lerp(b, i / 11.0).lerp(d.lerp(c, i / 11.0), j / 11.0))


func _line(curve: Curve3D, off: float, width := 0.2, from := 0.0, to := -1.0, y := 0.045) -> void:
	var mi := Kit.part(self, Kit.ribbon(curve, off - width * 0.5, off + width * 0.5, y, 2.0, from, to), Kit.mat(Color(0.8, 0.8, 0.76), 0.6))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _col_box(size: Vector3, tf: Transform3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = tf
	_static.add_child(cs)
	return cs


## Bryła z kolizją (budynek, zapora itp.).
func _solid(size: Vector3, pos: Vector3, mat: Material, r := 0.05, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := Kit.box(self, size, mat, pos, r, Vector3(0, yaw_deg, 0))
	_col_box(size, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))
	return mi


## Bariera energochłonna wzdłuż krzywej (siatka zbiorcza + kolizja).
func _rail(curve: Curve3D, off: float, from: float, to: float) -> void:
	var d := from
	while d < to:
		var f := _frame(curve, d + 2.0)
		var b := Basis(f[2], Vector3.UP, f[1])
		var p: Vector3 = f[0] + f[2] * off
		_rail_xf.append(Transform3D(b, p + Vector3(0, 0.62, 0)))
		_post_xf.append(Transform3D(b, _off(curve, d, off) + Vector3(0, 0.36, 0)))
		d += 4.0
	d = from
	while d < to:
		var seg := minf(8.0, to - d)
		var f2 := _frame(curve, d + seg * 0.5)
		_col_box(Vector3(0.3, 0.9, seg + 0.3), Transform3D(Basis(f2[2], Vector3.UP, f2[1]), f2[0] + f2[2] * off + Vector3(0, 0.45, 0)))
		d += 8.0


func _flush_rails() -> void:
	var steel := Kit.mat(Color(0.62, 0.64, 0.66), 0.42, 0.85)
	var sets := [[_rail_xf, Kit.rounded_box(Vector3(0.07, 0.3, 4.02), 0.03)], [_post_xf, Kit.rounded_box(Vector3(0.09, 0.72, 0.12), 0.02)]]
	for s in sets:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = s[1]
		mm.instance_count = s[0].size()
		for i in s[0].size():
			mm.set_instance_transform(i, s[0][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = steel
		add_child(mmi)


## Latarnia: słup z wysięgnikiem i oprawą; światło włączane po zmroku.
func _lamp(pos: Vector3, toward: Vector3, h := 9.0, arm := 2.2, power := 5.0) -> void:
	var steel := Kit.mat(Color(0.5, 0.52, 0.54), 0.5, 0.8)
	var dir := toward.normalized()
	Kit.cyl(self, 0.09, h, steel, pos + Vector3(0, h * 0.5, 0), Vector3.ZERO, 0.06)
	var head := pos + Vector3(0, h, 0) + dir * arm
	var n := Node3D.new()
	n.position = pos + Vector3(0, h, 0) + dir * (arm * 0.5)
	n.basis = Basis.looking_at(dir)
	add_child(n)
	Kit.box(n, Vector3(0.07, 0.07, arm), steel, Vector3.ZERO, 0.02)
	Kit.box(n, Vector3(0.3, 0.1, 0.7), steel, Vector3(0, 0, -arm * 0.5), 0.04)
	Kit.box(n, Vector3(0.22, 0.03, 0.55), lamp_mat, Vector3(0, -0.06, -arm * 0.5), 0.01)
	var l := SpotLight3D.new()
	l.position = head + Vector3(0, -0.15, 0)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.spot_angle = 68.0
	l.spot_range = h * 3.2
	l.spot_attenuation = 0.7
	l.light_color = Color(1.0, 0.84, 0.6)
	l.light_energy = power
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	lamps.append(l)
	_col_box(Vector3(0.25, 3.0, 0.25), Transform3D(Basis.IDENTITY, pos + Vector3(0, 1.5, 0)))


## Tablica z napisem, zwrócona przodem do nadjeżdżających (travel = kierunek ich jazdy).
func _board(pos: Vector3, travel: Vector3, lines: Array, kind := "green", size := Vector2(6.0, 2.6), height := 2.4) -> void:
	var n := Node3D.new()
	n.position = pos
	n.basis = Basis.looking_at(travel.normalized())
	add_child(n)
	var bg := {"green": Color(0.02, 0.3, 0.16), "blue": Color(0.03, 0.2, 0.5), "white": Color(0.9, 0.9, 0.88), "yellow": Color(0.92, 0.72, 0.05)}
	var fg := Color.WHITE if kind in ["green", "blue"] else Color(0.05, 0.05, 0.05)
	var steel := Kit.mat(Color(0.5, 0.52, 0.54), 0.5, 0.8)
	var cy := height + size.y * 0.5
	Kit.box(n, Vector3(size.x, size.y, 0.08), Kit.mat(bg[kind], 0.55), Vector3(0, cy, 0), 0.03)
	Kit.box(n, Vector3(size.x + 0.12, size.y + 0.12, 0.05), Kit.mat(fg, 0.55), Vector3(0, cy, -0.02), 0.03)
	for sx in [-1.0, 1.0]:
		Kit.cyl(n, 0.07, height + size.y, steel, Vector3(sx * (size.x * 0.5 - 0.4), (height + size.y) * 0.5, -0.1))
	var lh := size.y / (lines.size() + 0.6)
	for i in lines.size():
		var l := Label3D.new()
		l.text = lines[i]
		l.font_size = 96
		l.pixel_size = lh * 0.72 / 96.0
		l.modulate = fg
		l.outline_size = 0
		l.shaded = false
		l.position = Vector3(0, cy + size.y * 0.5 - lh * (i + 0.8), 0.06)
		n.add_child(l)
	_col_box(Vector3(0.3, 2.0, 0.3), Transform3D(Basis.IDENTITY, pos + Vector3(0, 1.0, 0)))


## Okrągły znak ograniczenia prędkości.
func _limit_sign(pos: Vector3, travel: Vector3, value: String) -> void:
	var n := Node3D.new()
	n.position = pos
	n.basis = Basis.looking_at(travel.normalized())
	add_child(n)
	Kit.cyl(n, 0.04, 2.6, Kit.mat(Color(0.5, 0.52, 0.54), 0.5, 0.8), Vector3(0, 1.3, -0.05))
	Kit.cyl(n, 0.45, 0.03, Kit.mat(Color(0.8, 0.06, 0.05), 0.5), Vector3(0, 2.75, 0), Vector3(90, 0, 0))
	Kit.cyl(n, 0.35, 0.035, Kit.mat(Color(0.93, 0.93, 0.9), 0.5), Vector3(0, 2.75, 0.004), Vector3(90, 0, 0))
	var l := Label3D.new()
	l.text = value
	l.font_size = 96
	l.pixel_size = 0.0042
	l.modulate = Color(0.05, 0.05, 0.05)
	l.outline_size = 0
	l.shaded = false
	l.position = Vector3(0, 2.75, 0.03)
	n.add_child(l)


# ---------------------------------------------------------------- teren

func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("noise_tex", _noise)
	m.set_shader_parameter("normal_tex", _nmap)
	var mi := Kit.part(self, pm, m, Vector3(-100, 0, 1700))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- droga ekspresowa

func _expressway() -> void:
	main_curve = Kit.curve_through([_v(0, -700), _v(0, -250), _v(0, 200), _v(30, 650), _v(90, 1050), _v(120, 1450), _v(95, 1850), _v(45, 2250), _v(12, 2650), _v(0, 2900), _v(0, MAIN_END)], 2.0)
	var c := main_curve
	var total := c.get_baked_length()
	# nasza jezdnia: od -4 (opaska) do +6 (pas awaryjny); linie: krawędź lewa 0.5, przerywana 4.0, krawędź prawa 7.5
	var merge_a := _d_at_z(c, 235.0)
	var merge_b := _d_at_z(c, 575.0)
	_road(c, -4.0, 6.0, _asphalt([0.5, 7.5], [4.0], Color(0.2, 0.2, 0.215), Vector2(merge_a, merge_b)))
	# jezdnia przeciwna (lustrzana): od -18 do -8
	_road(c, -18.0, -8.0, _asphalt([2.5, 9.5], [6.0], Color(0.2, 0.2, 0.215)))
	_rail(c, 6.7, 0.0, _d_at_z(c, -95.0))
	_rail(c, 6.7, _d_at_z(c, 590.0), total - 12.0)
	_rail(c, -6.0, 0.0, total - 8.0)
	_rail(c, -18.7, 0.0, total - 12.0)
	# ekrany akustyczne po prawej
	var scr := Kit.mat(Color(0.2, 0.36, 0.27), 0.7)
	var scr_top := Kit.mat(Color(0.6, 0.72, 0.76, 0.5), 0.1, 0.1, {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA})
	var d := _d_at_z(c, 1350.0)
	var d_end := _d_at_z(c, 1820.0)
	while d < d_end:
		var f := _frame(c, d + 3.0)
		var b := Basis(f[2], Vector3.UP, f[1])
		var p: Vector3 = f[0] + f[2] * 9.5
		var n := Node3D.new()
		n.transform = Transform3D(b, p)
		add_child(n)
		Kit.box(n, Vector3(0.18, 3.0, 5.9), scr, Vector3(0, 1.5, 0), 0.02)
		Kit.box(n, Vector3(0.06, 1.3, 5.9), scr_top, Vector3(0, 3.65, 0), 0.01)
		Kit.box(n, Vector3(0.22, 4.4, 0.16), Kit.mat(Color(0.4, 0.42, 0.44), 0.5, 0.7), Vector3(0, 2.2, 3.0), 0.02)
		_col_box(Vector3(0.3, 4.4, 6.0), Transform3D(b, p + Vector3(0, 2.2, 0)))
		d += 6.0
	# słupki prowadzące co 50 m
	var post_m := Kit.mat(Color(0.9, 0.9, 0.88), 0.6)
	var red := Kit.lamp(Color(1, 0.1, 0.05), 0.6)
	d = 20.0
	while d < total - 20.0:
		var p2 := _off(c, d, 7.6)
		Kit.box(self, Vector3(0.12, 1.0, 0.05), post_m, p2 + Vector3(0, 0.5, 0), 0.02)
		Kit.box(self, Vector3(0.09, 0.16, 0.06), red, p2 + Vector3(0, 0.82, 0), 0.01)
		d += 50.0
	# znaki
	var f1 := _frame(c, _d_at_z(c, 700.0))
	_limit_sign(f1[0] + f1[2] * 8.2, f1[1], "90")
	var f2 := _frame(c, _d_at_z(c, 2150.0))
	_board(f2[0] + f2[2] * 11.5, f2[1], ["Strefa przemysłowa", "rondo  1 km"], "green", Vector2(7.0, 2.8))
	var f3 := _frame(c, _d_at_z(c, 2700.0))
	_board(f3[0] + f3[2] * 11.0, f3[1], ["Koniec drogi", "ekspresowej 400 m"], "white", Vector2(5.4, 2.2))
	var f4 := _frame(c, _d_at_z(c, 2860.0))
	_limit_sign(f4[0] + f4[2] * 8.2, f4[1], "70")
	var f5 := _frame(c, _d_at_z(c, 3020.0))
	_limit_sign(f5[0] + f5[2] * 8.2, f5[1], "40")
	_board(f5[0] + f5[2] * 11.0 + f5[1] * 30.0, f5[1], ["Strefa przemysłowa  →", "Toruń  ↑"], "green", Vector2(7.4, 2.8))


func _mop() -> void:
	var plain := _asphalt([], [], Color(0.23, 0.23, 0.24))
	var lot := Rect2(-66, -80, 52, 210)
	_quad(_v(lot.position.x, lot.position.y), _v(lot.end.x, lot.position.y), _v(lot.end.x, lot.end.y), _v(lot.position.x, lot.end.y), plain, 0.02)
	_stamp_rect(lot)
	_excl.append(lot.grow(12.0))
	# pas włączenia: od wyjazdu z parkingu do prawego pasa
	var c := main_curve
	var pts := [_v(-43.75, 30), _v(-42.5, 100), _v(-32, 165), _off(c, _d_at_z(c, 235.0), 5.4), _off(c, _d_at_z(c, 320.0), 5.4), _off(c, _d_at_z(c, 430.0), 5.4), _off(c, _d_at_z(c, 510.0), 3.7), _off(c, _d_at_z(c, 585.0), 1.9)]
	var acc := Kit.curve_through(pts, 2.0)
	_road(acc, -2.3, 2.3, plain, 0.024)
	_line(acc, 2.2, 0.2, 60.0, acc.get_baked_length() - 150.0)
	paths["merge"] = acc
	# stanowiska dla ciężarówek
	var paint := Kit.mat(Color(0.8, 0.8, 0.76), 0.6)
	for i in 7:
		var x := -60.0 + i * 6.5
		Kit.box(self, Vector3(0.15, 0.01, 24.0), paint, Vector3(x, 0.035, 5.0), 0.0)
	# budynek obsługi podróżnych
	_solid(Vector3(9.0, 4.2, 22.0), Vector3(-59.0, 2.1, 95.0), Kit.mat(Color(0.72, 0.7, 0.66), 0.8), 0.1)
	Kit.box(self, Vector3(10.2, 0.25, 23.5), Kit.mat(Color(0.22, 0.24, 0.27), 0.6), Vector3(-58.6, 4.3, 95.0), 0.05)
	Kit.box(self, Vector3(0.06, 1.6, 16.0), window_mat, Vector3(-54.46, 2.0, 95.0), 0.02)
	_excl.append(Rect2(-70, 80, 20, 30))
	for z in [-50.0, 20.0, 90.0]:
		_lamp(_v(-67.5, z), Vector3(1, 0, 0), 10.0, 2.5, 6.0)
	_lamp(_v(-13.0, 60.0), Vector3(-1, 0, 0), 10.0, 2.5, 6.0)
	_board(_v(-12.0, 150.0), Vector3(0, 0, 1), ["MOP Dobrzyń"], "blue", Vector2(4.6, 1.5), 2.2)
	# dwa zaparkowane zestawy
	_parked_trailer(_v(-53.0, 4.0), Vector3(0, 0, 1), true)
	_parked_trailer(_v(-27.0, -6.0), Vector3(0, 0, 1), true)


# ---------------------------------------------------------------- rondo

func _ring_pt(a: float, r := RB_MID) -> Vector3:
	return RB_C + Vector3(cos(a), 0, sin(a)) * r


func _ring_pts(a_from: float, a_to: float) -> Array:
	# ruch po rondzie odbywa się w stronę malejącego kąta
	var pts := []
	var a := a_from
	while a > a_to + 0.01:
		pts.append(_ring_pt(a))
		a -= 0.16
	pts.append(_ring_pt(a_to))
	return pts


## Punkty wlotu (do ronda) i wylotu (z ronda) dla ramienia o kącie `a`.
func _arm(a: float) -> Dictionary:
	var u := Vector3(cos(a), 0, sin(a))
	var t := Vector3(sin(a), 0, -cos(a))     # kierunek ruchu na pierścieniu przy tym ramieniu
	var inn := [RB_C + u * (RB_OUT + 70) + t * ARM_E, RB_C + u * (RB_OUT + 32) + t * ARM_E, RB_C + u * (RB_OUT + 9) + t * (ARM_E + 1.6), _ring_pt(a - PHI)]
	var out := [_ring_pt(a + PHI), RB_C + u * (RB_OUT + 9) - t * (ARM_E + 1.6), RB_C + u * (RB_OUT + 32) - t * ARM_E, RB_C + u * (RB_OUT + 70) - t * ARM_E]
	return {"in": inn, "out": out, "u": u, "t": t}


func _roundabout() -> void:
	var plain := _asphalt([], [], Color(0.21, 0.21, 0.225))
	# pierścień
	var ring_pts := []
	for i in 49:
		ring_pts.append(_ring_pt(-TAU * i / 48.0))
	var ring := Kit.curve_through(ring_pts, 1.0)
	_road(ring, -(RB_MID - RB_IN) + 2.0, RB_OUT - RB_MID, plain, 0.034)
	# pierścień najazdowy z kostki i wyspa
	var apron := Kit.part(self, Kit.ribbon(ring, -(RB_MID - RB_IN), -(RB_MID - RB_IN) + 2.0, 0.05, 2.0), Kit.mat(Color(0.33, 0.3, 0.28), 0.9))
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line(ring, -(RB_MID - RB_IN) + 2.1, 0.2)
	var isl := CylinderMesh.new()
	isl.top_radius = RB_IN - 1.5
	isl.bottom_radius = RB_IN
	isl.height = 0.5
	Kit.part(self, isl, Kit.mat(Color(0.12, 0.2, 0.05), 0.95), RB_C + Vector3(0, 0.25, 0))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RB_IN - 4.0
	cyl.height = 1.6
	cs.shape = cyl
	cs.position = RB_C + Vector3(0, 0.8, 0)
	_static.add_child(cs)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_stamp(RB_C + Vector3(sx, 0, sz) * 3.0)
	_excl.append(Rect2(RB_C.x - 45, RB_C.z - 45, 90, 90))
	# ramiona: S (ekspresowa), N (droga krajowa), strefa (w prawo = -X)
	var arms := {"S": _arm(-PI * 0.5), "N": _arm(PI * 0.5), "Z": _arm(PI)}
	for k in arms:
		var arm: Dictionary = arms[k]
		var cin := Kit.curve_through(arm["in"] + [_ring_pt(_arm_angle(k) - PHI - 0.3)], 1.0)
		var cout := Kit.curve_through([_ring_pt(_arm_angle(k) + PHI + 0.3)] + arm["out"], 1.0)
		_road(cin, -2.75, 2.75, plain, 0.028, 0.0, cin.get_baked_length() - 5.0)
		_road(cout, -2.75, 2.75, plain, 0.028, 5.0)
		_line(cin, 2.5, 0.2, 0.0, cin.get_baked_length() - 14.0)
		_line(cin, -2.5, 0.2, 0.0, cin.get_baked_length() - 20.0)
		_line(cout, 2.5, 0.2, 14.0)
		_line(cout, -2.5, 0.2, 20.0)
		# wysepka rozdzielająca z tablicą kierującą
		var u: Vector3 = arm["u"]
		var mid := RB_C + u * (RB_OUT + 24.0)
		var isl2 := Kit.box(self, Vector3(2.4, 0.3, 26.0), Kit.mat(Color(0.5, 0.5, 0.48), 0.9), mid + Vector3(0, 0.1, 0), 0.12)
		isl2.basis = Basis.looking_at(u)
		_chevron(RB_C + u * (RB_IN - 3.0), u)
		_lamp(RB_C + u.rotated(Vector3.UP, 0.6) * (RB_OUT + 3.5), -u.rotated(Vector3.UP, 0.6), 10.0, 2.6, 6.0)
		_lamp(RB_C + u.rotated(Vector3.UP, -0.6) * (RB_OUT + 3.5), -u.rotated(Vector3.UP, -0.6), 10.0, 2.6, 6.0)
	# przejście z dwóch jezdni ekspresówki w ramię S
	var s: Dictionary = arms["S"]
	var e0: Vector3 = s["in"][0]
	var x0: Vector3 = s["out"][3]
	var me := _frame(main_curve, main_curve.get_baked_length())
	var mp: Vector3 = me[0]
	_quad(mp + me[2] * 6.0, mp + me[2] * -4.0, e0 + Vector3(2.75, 0, 0), e0 + Vector3(-2.75, 0, 0), plain, 0.026)
	_quad(mp + me[2] * -8.0, mp + me[2] * -18.0, x0 + Vector3(2.75, 0, 0), x0 + Vector3(-2.75, 0, 0), plain, 0.026)
	# tory ruchu
	var c := main_curve
	var d_end := _d_at_z(c, 3040.0)
	var through_n := _ring_pts(-PI * 0.5 - PHI, -PI * 1.5 + PHI)          # z S do wylotu N
	var north_out: Array = arms["N"]["out"]
	var tail_n := [_v(4.25, 3440), _v(4.25, 3600), _v(4.25, 4150)]
	paths["right"] = Kit.curve_through(_off_pts(c, 1.75, 0.0, d_end, 40.0) + s["in"].slice(0, 3) + through_n + north_out.slice(1) + tail_n, 2.0)
	var d_m1 := _d_at_z(c, 2880.0)
	paths["left"] = Kit.curve_through(_off_pts(c, -1.75, 0.0, d_m1, 40.0) + [_off(c, _d_at_z(c, 2960.0), 0.0), _off(c, _d_at_z(c, 3030.0), 1.75)] + s["in"].slice(0, 3) + through_n + north_out.slice(1) + tail_n, 2.0)
	var north_in: Array = arms["N"]["in"]
	var through_s := _ring_pts(PI * 0.5 - PHI, -PI * 0.5 + PHI)
	var south_out: Array = s["out"]
	var back := _off_pts(c, -13.75, 0.0, _d_at_z(c, 3040.0), 40.0)
	back.reverse()
	paths["oncoming"] = Kit.curve_through([_v(7.75, 4150), _v(7.75, 3600), _v(7.75, 3440)] + north_in.slice(0, 3) + through_s + south_out.slice(1) + back, 2.0)
	paths["player_exit"] = Kit.curve_through(_ring_pts(-PI * 0.5 - PHI, -PI + PHI) + arms["Z"]["out"].slice(1), 1.0)


func _arm_angle(k: String) -> float:
	return {"S": -PI * 0.5, "N": PI * 0.5, "Z": PI}[k]


## Tablica „nakaz jazdy w prawo” na wyspie, na wprost wlotu.
func _chevron(pos: Vector3, toward: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.basis = Basis.looking_at(-toward)
	add_child(n)
	Kit.box(n, Vector3(4.2, 0.9, 0.06), Kit.mat(Color(0.04, 0.04, 0.05), 0.6), Vector3(0, 1.5, 0), 0.02)
	for i in 4:
		var l := Label3D.new()
		l.text = "›"
		l.font_size = 160
		l.pixel_size = 0.0075
		l.modulate = Color(0.95, 0.75, 0.05)
		l.outline_size = 0
		l.shaded = false
		l.position = Vector3(1.5 - i * 1.0, 1.62, 0.05)
		n.add_child(l)
	for sx in [-1.0, 1.0]:
		Kit.cyl(n, 0.05, 1.5, Kit.mat(Color(0.5, 0.52, 0.54), 0.5, 0.8), Vector3(sx * 1.7, 0.75, -0.06))


func _north_road() -> void:
	var axis := Kit.curve_through([_v(6, 3350), _v(6, 3700), _v(6, 4300)], 2.0)
	_road(axis, -3.6, 3.6, _asphalt([0.25, 6.95], [3.6], Color(0.22, 0.22, 0.23), Vector2(-1, -1), 4.0, 4.0), 0.022, 4.0)
	_board(_v(-2.5, 3420), Vector3(0, 0, 1), ["Toruń  54", "Lipno  21"], "green", Vector2(4.4, 2.0), 2.2)
	_limit_sign(_v(0.2, 3470), Vector3(0, 0, 1), "70")


func _access_road() -> void:
	# od ronda w stronę -X do bramy
	var axis := Kit.curve_through([_v(-80, 3260), _v(-200, 3260), _v(-336, 3260)], 2.0)
	_road(axis, -3.6, 3.6, _asphalt([0.25, 6.95], [3.6], Color(0.23, 0.23, 0.235), Vector2(-1, -1), 2.0, 4.0), 0.022, 8.0)
	var x := -110.0
	while x > -320.0:
		_lamp(_v(x, 3254.2), Vector3(0, 0, 1), 9.0, 2.2, 5.0)
		x -= 45.0
	_board(_v(-52, 3248.5), Vector3(-1, 0, 0), ["Centrum logistyczne", "bramy 1–8"], "white", Vector2(5.2, 2.0), 2.2)
	_limit_sign(_v(-118, 3254.6), Vector3(-1, 0, 0), "40")
	paths["access"] = Kit.curve_through([_v(-90, 3256), _v(-150, 3258.25), _v(-300, 3258.25), _v(-345, 3258.25)], 2.0)


# ---------------------------------------------------------------- plac i magazyn

func _depot() -> void:
	var yard_m := _asphalt([], [], Color(0.27, 0.27, 0.275))
	yard_m.set_shader_parameter("mottle", 0.16)
	var y0 := YARD.position
	var y1 := YARD.end
	_quad(_v(y0.x, y0.y), _v(y1.x, y0.y), _v(y1.x, y1.y), _v(y0.x, y1.y), yard_m, 0.02)
	_stamp_rect(YARD)
	_excl.append(Rect2(-500, 3170, 180, 220))
	# magazyn
	var wall := Kit.mat(Color(0.74, 0.76, 0.78), 0.55, 0.3, {"normal_enabled": true, "normal_texture": _nmap, "uv1_triplanar": true, "uv1_scale": Vector3(0.12, 0.12, 0.12)})
	var band := Kit.mat(Color(0.07, 0.22, 0.42), 0.5, 0.2)
	var dark := Kit.mat(Color(0.07, 0.075, 0.08), 0.8)
	_solid(Vector3(132, 12.0, 70), Vector3(-410, 6.0, DOCK_Z + 35.0), wall, 0.15)
	Kit.box(self, Vector3(132.3, 1.6, 70.3), band, Vector3(-410, 10.6, DOCK_Z + 35.0), 0.1)
	Kit.box(self, Vector3(62.0, 0.3, 5.0), Kit.mat(Color(0.3, 0.32, 0.34), 0.5, 0.5), Vector3(-384, 5.3, DOCK_Z - 2.3), 0.05)   # zadaszenie ramp
	var occupied := [1, 2, 4, 6, 7]
	for i in 8:
		var x := -362.0 - 6.2 * i
		var num := i + 1
		var free := not (num in occupied)
		bays.append({"num": num, "pos": _v(x, DOCK_Z), "dir": Vector3(0, 0, -1), "free": free})
		Kit.box(self, Vector3(3.3, 3.5, 0.2), dark, Vector3(x, 2.95, DOCK_Z - 0.05), 0.05)                          # kurtyna
		Kit.box(self, Vector3(2.7, 2.9, 0.1), Kit.mat(Color(0.55, 0.57, 0.6), 0.5, 0.4), Vector3(x, 2.75, DOCK_Z + 0.02), 0.02)   # brama
		for sx in [-1.0, 1.0]:
			Kit.box(self, Vector3(0.25, 0.5, 0.18), Kit.mat(Color(0.03, 0.03, 0.03), 0.95), Vector3(x + sx * 1.1, 1.0, DOCK_Z - 0.1), 0.04)   # odboje
			Kit.box(self, Vector3(0.14, 0.012, 17.0), Kit.mat(Color(0.86, 0.7, 0.08), 0.6), Vector3(x + sx * 1.9, 0.03, DOCK_Z - 8.5), 0.0)       # linie stanowiska
		var l := Label3D.new()
		l.text = str(num)
		l.font_size = 128
		l.pixel_size = 0.012
		l.modulate = Color(0.95, 0.95, 0.92)
		l.outline_size = 0
		l.shaded = false
		l.position = Vector3(x, 5.9, DOCK_Z - 0.12)
		l.rotation_degrees.y = 180.0
		add_child(l)
		var g := Label3D.new()
		g.text = str(num)
		g.font_size = 128
		g.pixel_size = 0.02
		g.modulate = Color(0.86, 0.7, 0.08)
		g.outline_size = 0
		g.position = Vector3(x, 0.05, DOCK_Z - 19.5)
		g.rotation_degrees = Vector3(-90, 180, 0)
		add_child(g)
		if not free:
			_parked_trailer(_v(x, DOCK_Z - 0.35 - 12.0), Vector3(0, 0, -1), false)
	_col_box(Vector3(52.0, 1.3, 0.3), Transform3D(Basis.IDENTITY, Vector3(-384, 0.65, DOCK_Z - 0.1)))
	# ogrodzenie i brama
	var fence_m := Kit.mat(Color(0.35, 0.37, 0.38), 0.6, 0.6)
	var segs := [[_v(y0.x, y0.y), _v(y1.x, y0.y)], [_v(y0.x, y0.y), _v(y0.x, y1.y)], [_v(y1.x, y0.y), _v(y1.x, 3248.0)], [_v(y1.x, 3272.0), _v(y1.x, y1.y)]]
	for sg in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var len_ := a.distance_to(b)
		var mid := (a + b) * 0.5
		var n := Node3D.new()
		n.position = mid
		n.basis = Basis.looking_at((b - a).normalized())
		add_child(n)
		Kit.box(n, Vector3(0.04, 2.0, len_), Kit.mat(Color(0.4, 0.42, 0.44, 0.55), 0.6, 0.5, {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA}), Vector3(0, 1.1, 0), 0.01)
		Kit.box(n, Vector3(0.08, 0.08, len_), fence_m, Vector3(0, 2.1, 0), 0.02)
		_col_box(Vector3(0.3, 2.2, len_), Transform3D(n.basis, mid + Vector3(0, 1.1, 0)))
	_solid(Vector3(5.0, 3.2, 6.0), Vector3(-339.5, 1.6, 3277.0), Kit.mat(Color(0.8, 0.8, 0.78), 0.7), 0.1)       # portiernia
	Kit.box(self, Vector3(0.06, 1.2, 4.0), window_mat, Vector3(-336.96, 2.0, 3277.0), 0.02)
	Kit.box(self, Vector3(5.6, 0.2, 6.6), dark, Vector3(-339.5, 3.3, 3277.0), 0.05)
	_gate_arm = Node3D.new()
	_gate_arm.position = Vector3(-336.0, 1.05, 3270.6)
	add_child(_gate_arm)
	var arm := Kit.box(_gate_arm, Vector3(0.12, 0.12, 20.0), Kit.mat(Color(0.9, 0.9, 0.88), 0.5), Vector3(0, 0, -10.0), 0.03)
	for i in 5:
		Kit.box(arm, Vector3(0.13, 0.13, 1.6), Kit.mat(Color(0.8, 0.08, 0.06), 0.5), Vector3(0, 0, -7.0 + i * 3.6), 0.03)
	Kit.box(self, Vector3(0.5, 1.2, 0.5), Kit.mat(Color(0.85, 0.65, 0.05), 0.5), Vector3(-336.0, 0.6, 3270.9), 0.05)
	_gate_shape = _col_box(Vector3(0.3, 1.2, 20.0), Transform3D(Basis.IDENTITY, Vector3(-336.0, 0.9, 3260.6)))
	_board(_v(-326, 3247.0), Vector3(-1, 0, 0), ["CENTRUM LOGISTYCZNE", "awizacje: bramy 1–8"], "blue", Vector2(6.4, 2.0), 2.0)
	# maszty oświetleniowe placu
	for x in [-350.0, -400.0, -450.0]:
		_lamp(_v(x, y0.y + 1.5), Vector3(0, 0, 1), 14.0, 3.0, 9.0)
	for x in [-352.0, -413.0, -470.0]:
		_lamp(_v(x, DOCK_Z - 0.7), Vector3(0, 0, -1), 12.5, 6.0, 9.0)
	# naczepy odstawione pod płotem
	for i in 6:
		_parked_trailer(_v(-362.0 - i * 7.0, y0.y + 6.0 + 12.0), Vector3(0, 0, 1), false)


## Odstawiona naczepa (opcjonalnie z ciągnikiem): bryła z kolizją. `pos` = sworzeń, `heading` = przód.
func _parked_trailer(pos: Vector3, heading: Vector3, with_tractor: bool) -> void:
	var n := Node3D.new()
	n.position = pos
	n.basis = Basis.looking_at(-heading.normalized())
	add_child(n)
	var cols := [Color(0.82, 0.83, 0.84), Color(0.2, 0.3, 0.42), Color(0.55, 0.14, 0.1), Color(0.78, 0.74, 0.62), Color(0.3, 0.34, 0.36)]
	var body := Kit.mat(cols[_rng.randi() % cols.size()], 0.5, 0.05)
	var dark := Kit.mat(Color(0.06, 0.065, 0.07), 0.7)
	Kit.box(n, Vector3(2.55, 2.72, 13.6), body, Vector3(0, 2.64, -5.2), 0.05)
	Kit.box(n, Vector3(1.2, 0.4, 12.0), dark, Vector3(0, 1.06, -5.8), 0.02)
	Kit.box(n, Vector3(2.4, 0.2, 0.1), dark, Vector3(0, 0.9, -11.97), 0.03)
	for z in [-6.4, -7.72, -9.04]:
		for sx in [-1.0, 1.0]:
			var w := Kit.wheel(0.535, 0.385)
			w.position = Vector3(sx * 1.02, 0.535, z)
			n.add_child(w)
	for sx in [-1.0, 1.0]:
		Kit.box(n, Vector3(0.12, 1.0, 0.12), dark, Vector3(sx * 0.72, 0.6, -1.9), 0.02)
	_col_box(Vector3(2.55, 3.4, 13.6), Transform3D(n.basis, n.transform * Vector3(0, 2.3, -5.2)))
	if with_tractor:
		var paint := Kit.paint([Color(0.1, 0.25, 0.5), Color(0.55, 0.08, 0.06), Color(0.85, 0.85, 0.86)][_rng.randi() % 3])
		Kit.box(n, Vector3(2.5, 2.9, 2.3), paint, Vector3(0, 2.4, 3.45), 0.16)
		Kit.box(n, Vector3(2.3, 0.95, 0.05), Kit.glass(), Vector3(0, 2.8, 4.6), 0.02)
		Kit.box(n, Vector3(2.3, 0.4, 6.0), dark, Vector3(0, 0.9, 1.6), 0.03)
		for z in [3.25, -0.35]:
			for sx in [-1.0, 1.0]:
				var w2 := Kit.wheel(0.535, 0.32, z < 0.0)
				w2.position = Vector3(sx * 0.98, 0.535, z)
				n.add_child(w2)
		_col_box(Vector3(2.5, 3.6, 6.4), Transform3D(n.basis, n.transform * Vector3(0, 1.8, 1.5)))


# ---------------------------------------------------------------- otoczenie

func _scenery() -> void:
	# hale w strefie przemysłowej i przy trasie
	var halls := [[-170, 3340, 70, 40, 10, 0.72], [-250, 3190, 60, 46, 9, 0.6], [-150, 3170, 50, 36, 11, 0.66], [-560, 3260, 46, 90, 10, 0.7], [-130, 2600, 80, 50, 9, 0.68], [180, 1500, 60, 40, 8, 0.62]]
	for h in halls:
		var c := Color(h[5], h[5] + 0.02, h[5] + 0.04)
		_solid(Vector3(h[2], h[4], h[3]), Vector3(h[0], h[4] * 0.5, h[1]), Kit.mat(c, 0.6, 0.25), 0.15)
		Kit.box(self, Vector3(h[2] + 0.3, 1.2, h[3] + 0.3), Kit.mat(Color(0.5, 0.12, 0.08) if int(h[0]) % 3 == 0 else Color(0.1, 0.3, 0.2), 0.5, 0.2), Vector3(h[0], h[4] - 1.4, h[1]), 0.1)
		Kit.box(self, Vector3(h[2] * 0.5, 1.4, 0.08), window_mat, Vector3(h[0], 3.0, h[1] - h[3] * 0.5 - 0.02), 0.02)
		_excl.append(Rect2(h[0] - h[2] * 0.5 - 8, h[1] - h[3] * 0.5 - 8, h[2] + 16, h[3] + 16))
	# komin i silosy
	Kit.cyl(self, 2.2, 55.0, Kit.mat(Color(0.62, 0.6, 0.58), 0.8), Vector3(-600, 27.5, 3150), Vector3.ZERO, 1.5)
	for i in 3:
		Kit.cyl(self, 5.0, 22.0, Kit.mat(Color(0.7, 0.72, 0.74), 0.4, 0.6), Vector3(-560 - i * 12.0, 11.0, 3380))
	_excl.append(Rect2(-620, 3130, 90, 270))


func _trees() -> void:
	var meshes := [_tree_mesh(false), _tree_mesh(true)]
	var xfs := [[], []]
	var tries := 0
	while xfs[0].size() + xfs[1].size() < 900 and tries < 20000:
		tries += 1
		# skupiska wzdłuż trasy: losowy punkt na osi + odsunięcie w bok
		var d := _rng.randf_range(0.0, 4200.0)
		var base: Vector3
		if d < main_curve.get_baked_length():
			base = main_curve.sample_baked(d)
		else:
			base = _v(_rng.randf_range(-500, 100), _rng.randf_range(3100, 4200))
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var p := base + Vector3(side * _rng.randf_range(24.0, 260.0) + (-6.0 if side < 0.0 else 0.0), 0, _rng.randf_range(-20, 20))
		if _near_paved(p, 13.0): continue
		var blocked := false
		for r in _excl:
			if r.has_point(Vector2(p.x, p.z)):
				blocked = true
				break
		if blocked: continue
		# lasy tam, gdzie szum jest wysoki; pojedyncze drzewa gdzie indziej rzadko
		var k := 0.5 + 0.5 * sin(p.x * 0.011) * cos(p.z * 0.007 + 1.3)
		if _rng.randf() > k * k * 1.6 + 0.05: continue
		var conifer := _rng.randf() < 0.4 + 0.3 * sin(p.z * 0.003)
		var s := _rng.randf_range(0.75, 1.35)
		var b := Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s))
		xfs[1 if conifer else 0].append(Transform3D(b, p))
	for i in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = xfs[i].size()
		for j in xfs[i].size():
			mm.set_instance_transform(j, xfs[i][j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _near_paved(p: Vector3, r: float) -> bool:
	for a in 8:
		var q := p + Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * r
		if is_paved(q): return true
	return is_paved(p)


## Drzewo: pień + korona z kilku nieregularnych brył (liściaste) albo stożków (iglaste).
func _tree_mesh(conifer: bool) -> ArrayMesh:
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_leaf := SurfaceTool.new()
	st_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12 if conifer else 0.2
	trunk.bottom_radius = 0.28 if conifer else 0.36
	trunk.height = 3.0 if conifer else 4.2
	trunk.radial_segments = 7
	trunk.rings = 1
	st_trunk.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, trunk.height * 0.5, 0)))
	var noise := FastNoiseLite.new()
	noise.seed = 5 if conifer else 9
	noise.frequency = 0.55
	if conifer:
		for i in 4:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 2.3 - i * 0.48
			cone.height = 3.4 - i * 0.3
			cone.radial_segments = 9
			cone.rings = 1
			st_leaf.append_from(cone, 0, Transform3D(Basis(Vector3.UP, i * 0.7), Vector3(0, 2.6 + i * 2.0, 0)))
	else:
		var blobs := [[Vector3(0, 6.2, 0), 2.7], [Vector3(1.5, 5.2, 0.6), 1.9], [Vector3(-1.3, 5.5, -0.8), 2.0], [Vector3(0.2, 5.0, -1.6), 1.7], [Vector3(-0.4, 7.6, 0.5), 1.8]]
		for b in blobs:
			var sp := SphereMesh.new()
			sp.radius = b[1]
			sp.height = b[1] * 1.7
			sp.radial_segments = 10
			sp.rings = 6
			var arr := sp.get_mesh_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for vi in verts.size():
				var v := verts[vi]
				verts[vi] = v * (1.0 + 0.28 * noise.get_noise_3dv(v * 1.3 + b[0]))
			arr[Mesh.ARRAY_VERTEX] = verts
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			st_leaf.append_from(am, 0, Transform3D(Basis.IDENTITY, b[0]))
	var mesh := ArrayMesh.new()
	st_trunk.commit(mesh)
	st_leaf.commit(mesh)
	var leaf_tex := Kit.noise_tex(31, 0.09, false, 256)
	mesh.surface_set_material(0, Kit.mat(Color(0.2, 0.15, 0.1), 0.95))
	var leaf_col := Color(0.07, 0.17, 0.07) if conifer else Color(0.16, 0.27, 0.07)
	mesh.surface_set_material(1, Kit.mat(leaf_col, 0.9, 0.0, {"albedo_texture": leaf_tex, "uv1_triplanar": true, "uv1_scale": Vector3(0.45, 0.45, 0.45), "backlight_enabled": true, "backlight": Color(0.12, 0.2, 0.04)}))
	return mesh


# ---------------------------------------------------------------- zapytania w trakcie gry

func is_paved(p: Vector3) -> bool:
	var px := int((p.x - MASK_ORIGIN.x) / 2.0)
	var pz := int((p.z - MASK_ORIGIN.y) / 2.0)
	if px < 0 or pz < 0 or px >= MASK_SIZE.x or pz >= MASK_SIZE.y:
		return false
	return _mask.get_pixel(px, pz).r > 0.5


func set_night(on: bool) -> void:
	for l in lamps:
		l.visible = on
	lamp_mat.emission_energy_multiplier = 6.0 if on else 0.0
	window_mat.emission_energy_multiplier = 2.2 if on else 0.0


## Szlaban: podnosi się, gdy zestaw podjeżdża do bramy.
func update_gate(rig_pos: Vector3, delta: float) -> void:
	var open := rig_pos.distance_to(gate_pos) < 45.0
	var target := deg_to_rad(82.0) if open else 0.0
	_gate_arm.rotation.x = move_toward(_gate_arm.rotation.x, target, delta * 1.2)
	_gate_shape.disabled = _gate_arm.rotation.x > deg_to_rad(45.0)
