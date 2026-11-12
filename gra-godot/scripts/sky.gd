extends Node3D
## Niebo, słońce, mgła i pogoda. Stan opisują dwa parametry: pora dnia i pogoda;
## zmiana pogody w trakcie kursu to płynne przejście między zestawami wartości.

const PRESETS := {
	"day":      {"sun": Vector3(-48, 150, 0), "sun_e": 1.25, "sun_c": Color(1.0, 0.96, 0.9), "top": Color(0.18, 0.38, 0.72), "hor": Color(0.62, 0.74, 0.86), "amb": 1.0, "fog": 0.00028, "vfog": 0.0018, "cover": 0.5, "night": false, "label": "dzień, sucho"},
	"overcast": {"sun": Vector3(-55, 150, 0), "sun_e": 0.35, "sun_c": Color(0.9, 0.92, 0.95), "top": Color(0.42, 0.46, 0.5), "hor": Color(0.66, 0.69, 0.72), "amb": 1.15, "fog": 0.0007, "vfog": 0.004, "cover": 1.0, "night": false, "label": "pochmurno"},
	"dusk":     {"sun": Vector3(-5, 172, 0), "sun_e": 0.75, "sun_c": Color(1.0, 0.55, 0.28), "top": Color(0.12, 0.17, 0.36), "hor": Color(0.95, 0.56, 0.3), "amb": 0.7, "fog": 0.0005, "vfog": 0.0035, "cover": 0.7, "night": true, "label": "zmierzch"},
	"night":    {"sun": Vector3(-35, 40, 0), "sun_e": 0.05, "sun_c": Color(0.55, 0.65, 0.9), "top": Color(0.012, 0.018, 0.04), "hor": Color(0.04, 0.052, 0.09), "amb": 1.6, "fog": 0.0006, "vfog": 0.003, "cover": 0.25, "night": true, "label": "noc"},
}

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain: GPUParticles3D
var world_env: WorldEnvironment

var time_key := "day"
var wet := 0.0            # 0 sucho .. 1 mokro (pada)
var wet_target := 0.0
var wet_speed := 0.05
var quality := 2          # 0 niska, 1 średnia, 2 wysoka
var low_end := false      # telefon / renderer mobilny: bez efektów ekranowych, krótsze cienie

var _cur := {}
var _target := {}


func _ready() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.1
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	var cover := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.seed = 77
	n.frequency = 0.0042
	n.fractal_octaves = 5
	n.fractal_gain = 0.55
	cover.noise = n
	cover.width = 1024
	cover.height = 512
	cover.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0))
	ramp.set_color(1, Color(1, 1, 1))
	ramp.set_offset(0, 0.5)
	ramp.set_offset(1, 0.74)
	cover.color_ramp = ramp
	sky_mat.sky_cover = cover
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.light_angular_distance = 0.6
	add_child(sun)
	_make_rain()
	set_time("day", true)
	set_quality(quality)


func _make_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 900 if low_end else 2600
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	rain.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 1, 34)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3(0, -6, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.85)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.86, 0.95, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	rain.draw_pass_1 = q
	rain.emitting = false
	rain.visible = false
	add_child(rain)


func set_quality(q: int) -> void:
	quality = q
	env.ssao_enabled = q >= 1 and not low_end
	env.ssil_enabled = false
	env.sdfgi_enabled = q >= 2 and not low_end
	env.volumetric_fog_enabled = q >= 1 and not low_end
	env.ssr_enabled = q >= 1 and not low_end
	env.ssr_max_steps = 48
	env.glow_enabled = not (low_end and q == 0)
	var vp := get_viewport()
	if low_end:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = [60.0, 100.0, 150.0][q]
		sun.shadow_enabled = true
		if vp:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = [0.6, 0.75, 0.9][q]
		return
	sun.directional_shadow_max_distance = [140.0, 220.0, 280.0][q]
	if vp:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		vp.scaling_3d_scale = [0.77, 1.0, 1.0][q]


func set_time(key: String, instant := false) -> void:
	time_key = key
	_target = PRESETS[key].duplicate()
	if instant or _cur.is_empty():
		_cur = _target.duplicate()
	_apply()


## Pogoda: wilgotność docelowa (0 = sucho, 1 = deszcz) i czas przejścia w sekundach.
func set_rain(target: float, seconds := 0.0) -> void:
	wet_target = target
	if seconds <= 0.0:
		wet = target
	else:
		wet_speed = 1.0 / seconds
	_apply()


func is_night() -> bool:
	return bool(_target.get("night", false))


func grip() -> float:
	return lerpf(1.0, 0.62, wet)


func label() -> String:
	var s: String = PRESETS[time_key]["label"]
	if wet_target > 0.5:
		s = s.replace(", sucho", "") + ", deszcz"
	return s


func _process(delta: float) -> void:
	var changed := false
	if not is_equal_approx(wet, wet_target):
		wet = move_toward(wet, wet_target, wet_speed * delta)
		changed = true
	for k in ["sun_e", "amb", "fog", "vfog", "cover"]:
		if not is_equal_approx(_cur[k], _target[k]):
			_cur[k] = lerpf(_cur[k], _target[k], minf(1.0, delta * 0.5))
			changed = true
	for k in ["sun_c", "top", "hor"]:
		var a: Color = _cur[k]
		var b: Color = _target[k]
		if not a.is_equal_approx(b):
			_cur[k] = a.lerp(b, minf(1.0, delta * 0.5))
			changed = true
	if changed:
		_apply()
	var cam := get_viewport().get_camera_3d()
	if cam and rain.visible:
		rain.global_position = cam.global_position + Vector3(0, 14, 0) - cam.global_basis.z * 12.0


func _apply() -> void:
	var c := _cur
	var w := wet
	# deszcz przyciemnia i wyrównuje niebo
	var grey := Color(0.36, 0.39, 0.42) * (0.25 if c.get("night", false) or _target.get("night", false) and time_key == "night" else 1.0)
	var top: Color = (c["top"] as Color).lerp(grey, w * 0.85)
	var hor: Color = (c["hor"] as Color).lerp(grey * 1.25, w * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.5)
	var cv: float = (hor.get_luminance() * 1.5 + 0.03) * lerpf(c["cover"], 1.0, w)
	sky_mat.sky_cover_modulate = Color(cv, cv, cv * 1.03, 1.0)
	sun.rotation_degrees = _target["sun"]
	sun.light_color = c["sun_c"]
	sun.light_energy = c["sun_e"] * lerpf(1.0, 0.22, w)
	env.ambient_light_energy = c["amb"]
	env.fog_light_color = hor
	env.fog_density = c["fog"] + w * 0.0016
	env.volumetric_fog_density = c["vfog"] + w * 0.004
	env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	env.volumetric_fog_length = 220.0
	rain.visible = w > 0.05
	rain.emitting = w > 0.05
	rain.amount_ratio = clampf(w, 0.05, 1.0)
	RenderingServer.global_shader_parameter_set("wetness", w)
