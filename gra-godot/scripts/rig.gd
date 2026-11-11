extends Node3D
## Zestaw gracza: ciągnik siodłowy + naczepa połączone sworzniem.
## Układ lokalny pojazdu: przód = +Z, lewa strona (kierowca) = +X, góra = +Y.

const Kit = preload("res://scripts/kit.gd")

signal impact(severity: float, what: String)

# --- parametry jazdy (pół-symulacja) ---
const V_LIMIT := 25.0            # ogranicznik 90 km/h
const V_REVERSE := 3.6           # ok. 13 km/h na wstecznym
const POWER := 520000.0          # W, moc na kołach (z zapasem względem realnych 370 kW, żeby gra nie była ospała)
const F_MAX := 95000.0           # N, maks. siła napędowa przy ruszaniu
const BRAKE_DECEL := 6.4         # m/s^2 przy pełnym hamowaniu na suchej nawierzchni
const TRACTOR_MASS := 8000.0
const TRAILER_MASS := 7000.0
const KINGPIN := Vector3(0.0, 1.22, -0.70)   # sworzeń w układzie ciągnika
const WHEEL_R := 0.535

# --- wejście (ustawiane przez main.gd lub testy) ---
var throttle := 0.0
var brake_in := 0.0
var steer_in := 0.0
var gear := 1                    # 1 = D, 0 = N, -1 = R
var parking := true
var retarder := 0                # 0..3
var lights := 0                  # 0 = wył., 1 = mijania, 2 = drogowe
var blinker := 0                 # -1 prawy, 1 lewy, 2 awaryjne, 0 brak
var wipers := 0                  # 0..2
var horn := false
var controls_enabled := true

# --- stan ---
var tractor: VehicleBody3D
var trailer: VehicleBody3D
var joint: Generic6DOFJoint3D
var cargo_mass := 18000.0
var grip := 1.0                  # 1.0 sucho, ok. 0.62 mokro
var offroad := false
var speed := 0.0                 # m/s wzdłuż osi ciągnika (ujemna = do tyłu)
var steer := 0.0
var blink_on := false
var articulation := 0.0          # kąt złamania zestawu (rad)

var _wheels_t: Array[VehicleWheel3D] = []
var _wheels_tr: Array[VehicleWheel3D] = []
var _prev_v_t := Vector3.ZERO
var _prev_v_tr := Vector3.ZERO
var _impact_cd := 0.0
var _settle := 1.0
var _blink_t := 0.0
var _wiper_t := 0.0

var interior: Node3D
var exterior_cab: Node3D
var steering_wheel: Node3D
var speed_label: Label3D
var wiper_l: Node3D
var wiper_r: Node3D
var head_l: SpotLight3D
var head_r: SpotLight3D
var tail_glow: OmniLight3D
var m_head: StandardMaterial3D
var m_tail: StandardMaterial3D
var m_blink_l: StandardMaterial3D
var m_blink_r: StandardMaterial3D
var m_rev: StandardMaterial3D
var m_marker: StandardMaterial3D
var mirror_l: SubViewport
var mirror_r: SubViewport


func _ready() -> void:
	m_head = Kit.lamp(Color(1.0, 0.96, 0.86))
	m_tail = Kit.lamp(Color(1.0, 0.06, 0.03))
	m_blink_l = Kit.lamp(Color(1.0, 0.55, 0.05))
	m_blink_r = Kit.lamp(Color(1.0, 0.55, 0.05))
	m_rev = Kit.lamp(Color(1.0, 1.0, 0.95))
	m_marker = Kit.lamp(Color(1.0, 0.6, 0.1))
	_build_tractor()
	_build_trailer()
	_couple()
	set_cargo(cargo_mass)
	set_grip(grip)


# ---------------------------------------------------------------- budowa

func _add_wheel(body: VehicleBody3D, pos: Vector3, traction: bool, steering: bool, dual: bool, width: float, stiffness := 42.0) -> VehicleWheel3D:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.wheel_radius = WHEEL_R
	w.wheel_rest_length = 0.24
	w.suspension_travel = 0.26
	# Sztywność i tłumienie w Godocie są liczone na jednostkę masy nadwozia.
	w.suspension_stiffness = stiffness
	w.suspension_max_force = 1500000.0
	w.damping_compression = 0.7 * sqrt(stiffness)
	w.damping_relaxation = 1.1 * sqrt(stiffness)
	w.wheel_friction_slip = 1.0
	w.wheel_roll_influence = 0.12
	w.use_as_traction = traction
	w.use_as_steering = steering
	body.add_child(w)
	var vis := Kit.wheel(WHEEL_R, width, dual)
	if pos.x < 0.0:
		vis.rotation_degrees.y = 180.0
	w.add_child(vis)
	return w


## Domyślne tłumienie ruchu z ustawień projektu działałoby jak stały hamulec, więc je wyłączamy;
## opory liczymy sami w _physics_process.
func _no_damp(b: RigidBody3D) -> void:
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.05


func _build_tractor() -> void:
	tractor = VehicleBody3D.new()
	tractor.name = "Tractor"
	tractor.mass = TRACTOR_MASS
	tractor.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	tractor.center_of_mass = Vector3(0.0, 0.95, 1.3)
	_no_damp(tractor)
	tractor.contact_monitor = true
	tractor.max_contacts_reported = 4
	tractor.body_entered.connect(_on_hit.bind("ciągnik"))
	add_child(tractor)
	var s1 := CollisionShape3D.new()
	var b1 := BoxShape3D.new(); b1.size = Vector3(2.5, 2.9, 2.35)
	s1.shape = b1; s1.position = Vector3(0, 2.4, 2.75)
	tractor.add_child(s1)
	var s2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new(); b2.size = Vector3(2.4, 0.62, 6.2)
	s2.shape = b2; s2.position = Vector3(0, 0.9, 0.85)
	tractor.add_child(s2)
	# Ciągnik dźwiga też nacisk naczepy na siodło, stąd dużo sztywniejsza oś tylna.
	var wy := WHEEL_R + 0.24 - 0.1
	_wheels_t.append(_add_wheel(tractor, Vector3(1.02, wy, 2.55), false, true, false, 0.32, 62.0))
	_wheels_t.append(_add_wheel(tractor, Vector3(-1.02, wy, 2.55), false, true, false, 0.32, 62.0))
	_wheels_t.append(_add_wheel(tractor, Vector3(0.9, wy, -1.05), true, false, true, 0.3, 115.0))
	_wheels_t.append(_add_wheel(tractor, Vector3(-0.9, wy, -1.05), true, false, true, 0.3, 115.0))

	var cab_paint := Kit.paint(Color(0.86, 0.5, 0.04))
	var dark := Kit.mat(Color(0.06, 0.065, 0.07), 0.7)
	var plastic := Kit.mat(Color(0.1, 0.105, 0.11), 0.85)
	var chrome := Kit.mat(Color(0.82, 0.83, 0.85), 0.18, 1.0)
	var alu := Kit.mat(Color(0.66, 0.68, 0.7), 0.42, 0.9)

	# podwozie (widoczne zawsze)
	var ch := Node3D.new(); ch.name = "Chassis"; tractor.add_child(ch)
	for sx in [-1.0, 1.0]:
		Kit.box(ch, Vector3(0.14, 0.3, 6.1), dark, Vector3(sx * 0.42, 0.9, 0.85), 0.02)
		Kit.cyl(ch, 0.33, 1.35, alu, Vector3(sx * 0.98, 0.72, 0.85), Vector3(90, 0, 0))
		Kit.box(ch, Vector3(0.72, 0.07, 1.45), plastic, Vector3(sx * 0.9, 1.14, -1.05), 0.03)
		Kit.box(ch, Vector3(0.3, 0.16, 0.06), m_tail, Vector3(sx * 0.86, 0.95, -2.16), 0.02)
		Kit.box(ch, Vector3(0.12, 0.62, 1.95), plastic, Vector3(sx * 1.19, 0.82, 2.75), 0.04)
	Kit.cyl(ch, 0.52, 0.09, dark, Vector3(0, 1.17, -0.7))
	Kit.box(ch, Vector3(1.0, 0.1, 0.9), dark, Vector3(0, 1.08, -0.7), 0.02)
	Kit.cyl(ch, 0.07, 1.9, chrome, Vector3(-0.95, 2.35, 1.42))
	Kit.box(ch, Vector3(2.5, 0.44, 0.32), plastic, Vector3(0, 0.7, 3.82), 0.08)
	for sx in [-1.0, 1.0]:
		Kit.box(ch, Vector3(0.44, 0.2, 0.06), m_head, Vector3(sx * 0.86, 0.93, 3.975), 0.02)
		Kit.box(ch, Vector3(0.16, 0.16, 0.07), m_blink_l if sx > 0 else m_blink_r, Vector3(sx * 1.17, 0.93, 3.95), 0.02)

	# nadwozie kabiny z zewnątrz (chowane w widoku z kabiny)
	exterior_cab = Node3D.new(); exterior_cab.name = "CabExterior"; tractor.add_child(exterior_cab)
	Kit.box(exterior_cab, Vector3(2.5, 2.4, 2.3), cab_paint, Vector3(0, 2.33, 2.75), 0.16)
	Kit.box(exterior_cab, Vector3(2.38, 0.6, 2.0), cab_paint, Vector3(0, 3.72, 2.62), 0.22)
	Kit.box(exterior_cab, Vector3(2.3, 0.98, 0.05), Kit.glass(), Vector3(0, 2.78, 3.895), 0.02, Vector3(-4, 0, 0))
	Kit.box(exterior_cab, Vector3(2.2, 0.72, 0.05), plastic, Vector3(0, 1.58, 3.905), 0.02)
	for i in 4:
		Kit.box(exterior_cab, Vector3(1.9, 0.035, 0.03), chrome, Vector3(0, 1.36 + i * 0.15, 3.935), 0.01)
	Kit.box(exterior_cab, Vector3(2.42, 0.11, 0.34), plastic, Vector3(0, 3.32, 3.98), 0.04)
	for sx in [-1.0, 1.0]:
		Kit.box(exterior_cab, Vector3(0.04, 0.78, 1.05), Kit.glass(), Vector3(sx * 1.245, 2.72, 3.15), 0.01)
		Kit.box(exterior_cab, Vector3(0.05, 0.05, 0.3), plastic, Vector3(sx * 1.36, 3.1, 3.72), 0.01)
		Kit.box(exterior_cab, Vector3(0.14, 0.58, 0.24), plastic, Vector3(sx * 1.5, 2.82, 3.74), 0.05)

	_build_interior(plastic, dark, chrome)

	# reflektory
	for sx in [-1.0, 1.0]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(sx * 0.86, 0.95, 4.05)
		sp.rotation_degrees = Vector3(-5.0, 180.0, 0.0)   # światło świeci wzdłuż -Z węzła, więc obracamy je ku przodowi (+Z)
		sp.light_color = Color(1.0, 0.95, 0.86)
		sp.spot_range = 130.0
		sp.spot_angle = 44.0
		sp.spot_attenuation = 0.55
		sp.shadow_enabled = sx > 0.0
		sp.visible = false
		tractor.add_child(sp)
		if sx > 0.0: head_l = sp
		else: head_r = sp


func _build_interior(plastic: Material, dark: Material, chrome: Material) -> void:
	interior = Node3D.new(); interior.name = "Interior"; interior.visible = false
	tractor.add_child(interior)
	var trim := Kit.mat(Color(0.16, 0.16, 0.17), 0.9)
	var soft := Kit.mat(Color(0.23, 0.22, 0.21), 0.95)
	Kit.box(interior, Vector3(2.36, 0.56, 0.66), trim, Vector3(0, 2.02, 3.55), 0.1)            # deska
	Kit.box(interior, Vector3(0.74, 0.3, 0.3), plastic, Vector3(0.55, 2.36, 3.5), 0.07)        # zegary
	Kit.box(interior, Vector3(2.4, 0.16, 0.5), soft, Vector3(0, 3.33, 3.6), 0.05)              # podsufitka nad szybą
	Kit.box(interior, Vector3(2.4, 0.06, 2.2), soft, Vector3(0, 3.42, 2.7), 0.02)              # sufit
	Kit.box(interior, Vector3(2.4, 2.0, 0.06), soft, Vector3(0, 2.45, 1.66), 0.02)             # ściana tylna
	Kit.box(interior, Vector3(2.4, 0.06, 2.3), dark, Vector3(0, 1.5, 2.75), 0.02)              # podłoga
	for sx in [-1.0, 1.0]:
		Kit.box(interior, Vector3(0.11, 1.12, 0.11), trim, Vector3(sx * 1.19, 2.8, 3.86), 0.03, Vector3(-4, 0, 0))   # słupek A
		Kit.box(interior, Vector3(0.06, 0.82, 1.9), trim, Vector3(sx * 1.215, 1.92, 2.9), 0.03)                       # drzwi
		Kit.box(interior, Vector3(0.07, 0.36, 2.2), soft, Vector3(sx * 1.21, 3.24, 2.75), 0.02)                       # nad oknem
		Kit.box(interior, Vector3(0.08, 0.86, 0.1), trim, Vector3(sx * 1.21, 2.72, 2.58), 0.02)                       # słupek B
	Kit.box(interior, Vector3(0.5, 1.0, 0.5), soft, Vector3(0.55, 2.0, 2.45), 0.1)             # oparcie fotela
	# kierownica
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(0.55, 2.2, 3.16)
	steering_wheel.rotation_degrees = Vector3(62.0, 0, 0)
	interior.add_child(steering_wheel)
	var spin := Node3D.new(); spin.name = "Spin"; steering_wheel.add_child(spin)
	var tm := TorusMesh.new(); tm.inner_radius = 0.2; tm.outer_radius = 0.245; tm.rings = 28; tm.ring_segments = 10
	Kit.part(spin, tm, Kit.mat(Color(0.05, 0.05, 0.055), 0.6))
	Kit.box(spin, Vector3(0.42, 0.03, 0.06), plastic, Vector3.ZERO, 0.01)
	Kit.box(spin, Vector3(0.06, 0.03, 0.22), plastic, Vector3(0, 0, -0.11), 0.01)
	Kit.cyl(spin, 0.06, 0.05, plastic)
	Kit.cyl(interior, 0.035, 0.5, dark, Vector3(0.55, 2.0, 3.3), Vector3(62, 0, 0))
	# prędkość na zegarach
	speed_label = Label3D.new()
	speed_label.text = "0"
	speed_label.font_size = 64
	speed_label.pixel_size = 0.0011
	speed_label.modulate = Color(0.75, 0.95, 1.0)
	speed_label.position = Vector3(0.55, 2.38, 3.34)
	speed_label.rotation_degrees = Vector3(-20, 180, 0)
	speed_label.shaded = false
	speed_label.no_depth_test = false
	interior.add_child(speed_label)
	# wycieraczki (po zewnętrznej stronie szyby, widoczne z kabiny)
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.45 + 0.35, 2.33, 3.94)
		interior.add_child(piv)
		Kit.box(piv, Vector3(0.018, 0.66, 0.018), dark, Vector3(0, 0.33, 0), 0.006)
		piv.rotation_degrees.z = 80.0
		if sx > 0.0: wiper_l = piv
		else: wiper_r = piv
	# lusterka: obraz z dodatkowych kamer skierowanych do tyłu
	mirror_l = _make_mirror(1.0)
	mirror_r = _make_mirror(-1.0)


func _make_mirror(sx: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(224, 400)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.3
	cam.far = 400.0
	vp.add_child(cam)
	var holder := RemoteTransform3D.new()
	holder.position = Vector3(sx * 1.62, 2.82, 3.7)
	holder.rotation_degrees = Vector3(-3.0, -sx * 4.5, 0.0)   # kamera patrzy wzdłuż -Z, czyli do tyłu pojazdu
	tractor.add_child(holder)
	holder.remote_path = holder.get_path_to(cam)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_texture = vp.get_texture()
	mm.uv1_scale = Vector3(-1, 1, 1)       # odbicie lustrzane
	mm.uv1_offset = Vector3(1, 0, 0)
	var q := QuadMesh.new(); q.size = Vector2(0.24, 0.46)
	var mi := Kit.part(interior, q, mm, Vector3(sx * 1.52, 2.8, 3.93), Vector3(0, 180.0 - sx * 14.0, 0))
	Kit.box(interior, Vector3(0.3, 0.52, 0.05), Kit.mat(Color(0.1, 0.105, 0.11), 0.85), Vector3(sx * 1.53, 2.8, 3.97), 0.02, Vector3(0, -sx * 14.0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return vp


func _build_trailer() -> void:
	trailer = VehicleBody3D.new()
	trailer.name = "Trailer"
	trailer.mass = TRAILER_MASS
	trailer.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	trailer.center_of_mass = Vector3(0, 1.5, -4.9)
	_no_damp(trailer)
	trailer.contact_monitor = true
	trailer.max_contacts_reported = 4
	trailer.body_entered.connect(_on_hit.bind("naczepa"))
	trailer.position = Vector3(KINGPIN.x, 0, KINGPIN.z)
	add_child(trailer)
	var s1 := CollisionShape3D.new()
	var b1 := BoxShape3D.new(); b1.size = Vector3(2.55, 2.72, 13.6)
	s1.shape = b1; s1.position = Vector3(0, 2.64, -5.2)
	trailer.add_child(s1)
	var s2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new(); b2.size = Vector3(2.45, 0.7, 6.0)
	s2.shape = b2; s2.position = Vector3(0, 0.85, -9.0)
	trailer.add_child(s2)
	var wy := WHEEL_R + 0.24 - 0.035
	for z in [-6.4, -7.72, -9.04]:
		for sx in [1.0, -1.0]:
			_wheels_tr.append(_add_wheel(trailer, Vector3(sx * 1.02, wy, z), false, false, false, 0.385))

	var body_m := Kit.mat(Color(0.86, 0.87, 0.88), 0.46, 0.05)
	var band := Kit.mat(Color(0.07, 0.22, 0.42), 0.4, 0.2)
	var dark := Kit.mat(Color(0.06, 0.065, 0.07), 0.7)
	var steel := Kit.mat(Color(0.6, 0.62, 0.64), 0.45, 0.85)
	var v := Node3D.new(); v.name = "Visual"; trailer.add_child(v)
	Kit.box(v, Vector3(2.55, 2.72, 13.6), body_m, Vector3(0, 2.64, -5.2), 0.05)
	Kit.box(v, Vector3(2.57, 0.42, 13.3), band, Vector3(0, 1.62, -5.2), 0.02)
	for sx in [-1.0, 1.0]:
		Kit.box(v, Vector3(0.16, 0.42, 12.2), dark, Vector3(sx * 0.5, 1.06, -5.8), 0.02)
		Kit.box(v, Vector3(0.12, 0.8, 0.12), steel, Vector3(sx * 0.72, 0.7, -1.9), 0.02)
		Kit.box(v, Vector3(0.3, 0.04, 0.3), steel, Vector3(sx * 0.72, 0.3, -1.9), 0.01)
		Kit.box(v, Vector3(0.05, 0.1, 5.0), steel, Vector3(sx * 1.25, 0.95, -3.4), 0.02)
		Kit.box(v, Vector3(0.05, 0.1, 5.0), steel, Vector3(sx * 1.25, 0.62, -3.4), 0.02)
		Kit.box(v, Vector3(0.7, 0.06, 3.7), dark, Vector3(sx * 1.0, 1.13, -7.72), 0.02)
		Kit.box(v, Vector3(0.6, 0.5, 0.03), dark, Vector3(sx * 1.0, 0.5, -9.8), 0.01)
		# tylna belka świateł
		Kit.box(v, Vector3(0.34, 0.17, 0.06), m_tail, Vector3(sx * 0.98, 0.95, -12.03), 0.02)
		Kit.box(v, Vector3(0.2, 0.17, 0.06), m_blink_l if sx > 0 else m_blink_r, Vector3(sx * 0.7, 0.95, -12.03), 0.02)
		Kit.box(v, Vector3(0.16, 0.17, 0.06), m_rev, Vector3(sx * 0.5, 0.95, -12.03), 0.02)
		Kit.box(v, Vector3(0.12, 0.08, 0.05), m_tail, Vector3(sx * 1.18, 3.9, -12.02), 0.01)
		# zamki drzwi
		for k in [0.3, 0.9]:
			Kit.cyl(v, 0.018, 2.5, steel, Vector3(sx * k, 2.62, -12.03))
		# obrysówki boczne
		var z := 0.9
		while z > -11.8:
			Kit.box(v, Vector3(0.03, 0.06, 0.14), m_marker, Vector3(sx * 1.285, 1.3, z), 0.01)
			z -= 2.6
	Kit.box(v, Vector3(0.03, 2.6, 0.03), dark, Vector3(0, 2.62, -12.02), 0.005)
	Kit.box(v, Vector3(2.4, 0.24, 0.1), dark, Vector3(0, 0.95, -11.97), 0.03)
	Kit.box(v, Vector3(2.4, 0.13, 0.13), steel, Vector3(0, 0.55, -11.9), 0.03)
	Kit.box(v, Vector3(0.5, 0.115, 0.02), Kit.mat(Color(0.92, 0.92, 0.9), 0.5), Vector3(0, 0.95, -12.03), 0.005)
	Kit.box(v, Vector3(2.45, 0.055, 0.02), Kit.mat(Color(0.95, 0.78, 0.1), 0.35), Vector3(0, 1.31, -12.03), 0.005)
	Kit.box(v, Vector3(0.06, 0.6, 0.6), dark, Vector3(0, 0.95, -0.02), 0.02)   # płyta sprzęgu
	tail_glow = OmniLight3D.new()
	tail_glow.position = Vector3(0, 0.9, -13.6)
	tail_glow.light_color = Color(1, 0.1, 0.05)
	tail_glow.omni_range = 7.0
	tail_glow.light_energy = 0.0
	trailer.add_child(tail_glow)


func _couple() -> void:
	tractor.add_collision_exception_with(trailer)
	joint = Generic6DOFJoint3D.new()
	joint.position = KINGPIN
	add_child(joint)
	joint.node_a = joint.get_path_to(tractor)
	joint.node_b = joint.get_path_to(trailer)
	# obrót wokół osi pionowej swobodny (z ogranicznikiem), przechyły niemal zablokowane
	joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(-88.0))
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(88.0))
	joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(-7.0))
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(7.0))
	joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(-3.0))
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(3.0))


# ---------------------------------------------------------------- ustawienia

func set_cargo(kg: float) -> void:
	cargo_mass = kg
	trailer.mass = TRAILER_MASS + kg
	trailer.center_of_mass = Vector3(0, 1.45 + kg / 60000.0, -4.9)


func set_grip(g: float) -> void:
	grip = g
	_apply_grip()


func _apply_grip() -> void:
	var mu := grip * (0.55 if offroad else 1.0)
	for w in _wheels_t + _wheels_tr:
		w.wheel_friction_slip = mu


## Przenosi cały zestaw w nowe miejsce (pozycja sworznia na ziemi + kierunek jazdy).
func place(pos: Vector3, heading: Vector3) -> void:
	var b := Basis.looking_at(-heading.normalized(), Vector3.UP)   # looking_at ustawia -Z na cel, a przód pojazdu to +Z
	var tf := Transform3D(b, pos)
	for body in [tractor, trailer]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	tractor.global_transform = tf * Transform3D(Basis.IDENTITY, Vector3(-KINGPIN.x, 0.02, -KINGPIN.z))
	trailer.global_transform = tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0))
	joint.global_transform = tf * Transform3D(Basis.IDENTITY, Vector3(0, KINGPIN.y, 0))
	_prev_v_t = Vector3.ZERO
	_prev_v_tr = Vector3.ZERO
	_settle = 1.0
	steer = 0.0


func total_mass() -> float:
	return tractor.mass + trailer.mass


## Środek tylnej krawędzi naczepy (do oceny podjazdu pod rampę).
func trailer_rear() -> Vector3:
	return trailer.global_transform * Vector3(0, 0, -12.0)


func trailer_heading() -> Vector3:
	return trailer.global_basis.z


func set_cab_view(on: bool, mirrors: bool) -> void:
	interior.visible = on
	exterior_cab.visible = not on
	var mode := SubViewport.UPDATE_ALWAYS if (on and mirrors) else SubViewport.UPDATE_DISABLED
	mirror_l.render_target_update_mode = mode
	mirror_r.render_target_update_mode = mode


# ---------------------------------------------------------------- fizyka

func _physics_process(delta: float) -> void:
	var fwd := tractor.global_basis.z
	speed = tractor.linear_velocity.dot(fwd)
	var vabs := absf(speed)
	var ticks := 1.0 / delta      # hamulce w Godocie podaje się jako impuls na krok fizyki
	var th := throttle if controls_enabled else 0.0
	var br := brake_in if controls_enabled else 1.0
	var st_in := steer_in if controls_enabled else 0.0

	# kierownica: im szybciej, tym mniejszy maksymalny skręt kół
	var max_angle := lerpf(0.66, 0.06, clampf(vabs / 24.0, 0.0, 1.0))
	steer = move_toward(steer, st_in * max_angle, (0.75 if absf(st_in) > 0.01 else 1.1) * delta)

	# napęd
	var force := 0.0
	if th > 0.0 and gear != 0 and not parking:
		force = minf(F_MAX, POWER / maxf(vabs, 1.0)) * th
		if gear == 1:
			force *= clampf((V_LIMIT + 0.4 - speed) / 0.8, 0.0, 1.0)
		else:
			force = -minf(force, 60000.0) * clampf((V_REVERSE + 0.3 + speed) / 0.6, 0.0, 1.0)

	# hamulce: zasadniczy + zwalniacz + postojowy
	var mass := total_mass()
	var decel := br * minf(BRAKE_DECEL, 9.0 * grip)
	if retarder > 0 and th <= 0.0 and vabs > 3.0 and gear == 1:
		decel += 0.45 * retarder
	if th <= 0.0 and vabs > 0.5:
		decel += 0.12   # hamowanie silnikiem
	var f_brake := mass * decel
	var b_t := f_brake * 0.42 / 4.0 / ticks
	var b_tr := f_brake * 0.58 / 6.0 / ticks
	if parking:
		b_t = 900.0
		b_tr = 900.0
	for w in _wheels_t:
		w.steering = steer if w.use_as_steering else 0.0
		w.engine_force = force * 0.5 if w.use_as_traction else 0.0
		w.brake = b_t if force == 0.0 else 0.0
	for w in _wheels_tr:
		w.brake = b_tr

	# opory toczenia i powietrza
	if vabs > 0.2:
		var drag := (0.0065 * (2.6 if offroad else 1.0)) * mass * 9.81 + 3.4 * speed * speed
		tractor.apply_central_force(-fwd * signf(speed) * drag)

	# kąt między ciągnikiem a naczepą
	var tf := trailer.global_basis.z
	articulation = atan2(fwd.cross(tf).y, fwd.dot(tf))

	# wykrywanie uderzeń: nagła zmiana prędkości któregoś z członów
	_settle = maxf(0.0, _settle - delta)
	_impact_cd = maxf(0.0, _impact_cd - delta)
	var dv_t := (tractor.linear_velocity - _prev_v_t).length()
	var dv_tr := (trailer.linear_velocity - _prev_v_tr).length()
	_prev_v_t = tractor.linear_velocity
	_prev_v_tr = trailer.linear_velocity
	if _hit_pending != "" and _settle <= 0.0 and _impact_cd <= 0.0:
		var dv := maxf(dv_t, dv_tr)
		if dv > 0.25:
			_impact_cd = 0.6
			impact.emit(dv, _hit_pending)
	_hit_pending = ""


var _hit_pending := ""

func _on_hit(_body: Node, what: String) -> void:
	_hit_pending = what


# ---------------------------------------------------------------- światła i animacje

func _process(delta: float) -> void:
	_blink_t += delta
	blink_on = fmod(_blink_t, 0.7) < 0.35
	var l_on := blink_on and (blinker == 1 or blinker == 2)
	var r_on := blink_on and (blinker == -1 or blinker == 2)
	m_blink_l.emission_energy_multiplier = 4.0 if l_on else 0.0
	m_blink_r.emission_energy_multiplier = 4.0 if r_on else 0.0
	var braking := (brake_in > 0.05 and controls_enabled) or (not controls_enabled and absf(speed) > 0.3)
	m_tail.emission_energy_multiplier = 5.0 if braking else (1.0 if lights > 0 else 0.0)
	tail_glow.light_energy = 0.9 if braking else (0.12 if lights > 0 else 0.0)
	m_head.emission_energy_multiplier = [0.0, 3.0, 6.0][lights]
	m_marker.emission_energy_multiplier = 2.0 if lights > 0 else 0.0
	m_rev.emission_energy_multiplier = 3.5 if gear == -1 else 0.0
	for sp in [head_l, head_r]:
		sp.visible = lights > 0
		sp.light_energy = 24.0 if lights == 1 else 42.0
		sp.spot_range = 130.0 if lights == 1 else 240.0
		sp.rotation_degrees.x = -5.0 if lights == 1 else -1.5
	if interior.visible:
		steering_wheel.get_node("Spin").rotation.y = -steer * 9.0
		speed_label.text = str(int(round(absf(speed) * 3.6)))
		if wipers > 0 or _wiper_t > 0.0:
			_wiper_t += delta * (1.1 if wipers <= 1 else 2.0)
			if _wiper_t >= 1.0:
				_wiper_t = 0.0 if wipers == 0 else _wiper_t - 1.0
			var a := 80.0 - sin(_wiper_t * PI) * 105.0
			wiper_l.rotation_degrees.z = a
			wiper_r.rotation_degrees.z = a
