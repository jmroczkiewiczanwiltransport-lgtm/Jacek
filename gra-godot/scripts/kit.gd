extends RefCounted
## Narzędzia do budowania brył i materiałów w kodzie.
## Projekt nie ma plików modeli 3D: wszystko powstaje tutaj, więc każdą bryłę
## można później podmienić na gotowy model (.glb) bez zmiany logiki gry.

static var _mats := {}
static var _noise := {}


## Materiał PBR z pamięcią podręczną. `opts` to dodatkowe właściwości StandardMaterial3D.
static func mat(color: Color, rough := 0.6, metal := 0.0, opts := {}) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(), rough, metal, str(opts)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	for k in opts:
		m.set(k, opts[k])
	_mats[key] = m
	return m


## Lakier samochodowy: lekko metaliczny, z warstwą bezbarwną.
static func paint(color: Color) -> StandardMaterial3D:
	return mat(color, 0.38, 0.35, {"clearcoat_enabled": true, "clearcoat": 0.9, "clearcoat_roughness": 0.12})


static func glass(tint := Color(0.05, 0.08, 0.1, 0.45)) -> StandardMaterial3D:
	return mat(tint, 0.04, 0.2, {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA, "cull_mode": BaseMaterial3D.CULL_DISABLED})


## Osobny (nie z pamięci podręcznej) materiał świecący, którego jasność zmienia się w trakcie gry.
static func lamp(color: Color, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.55)
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Bezszwowa tekstura szumu (opcjonalnie jako mapa normalnych).
static func noise_tex(seed_: int, freq: float, normal := false, size := 512, bump := 6.0) -> NoiseTexture2D:
	var key := "%d|%.4f|%s|%d|%.1f" % [seed_, freq, normal, size, bump]
	if _noise.has(key):
		return _noise[key]
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = normal
	t.bump_strength = bump
	t.generate_mipmaps = true
	_noise[key] = t
	return t


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	# Godot traktuje jako przód ścianę o wierzchołkach zgodnych z ruchem wskazówek zegara.
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var t := b; b = c; c = t
		var tn := nb; nb = nc; nc = tn
		var tu := ub; ub = uc; uc = tu
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nc); st.set_uv(uc); st.add_vertex(c)


## Prostopadłościan o zaokrąglonych krawędziach (środek w początku układu).
static func rounded_box(size: Vector3, r := 0.06) -> ArrayMesh:
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var t := tan(deg_to_rad(22.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var a1 := (axis + 1) % 3
		var a2 := (axis + 2) % 3
		var c1 := [-h[a1], -(h[a1] - r) - r * t, -(h[a1] - r), h[a1] - r, (h[a1] - r) + r * t, h[a1]]
		var c2 := [-h[a2], -(h[a2] - r) - r * t, -(h[a2] - r), h[a2] - r, (h[a2] - r) + r * t, h[a2]]
		for side in [-1.0, 1.0]:
			var pts := []
			var nrm := []
			var uvs := []
			for i in 6:
				for j in 6:
					var p := Vector3.ZERO
					p[axis] = side * h[axis]
					p[a1] = c1[i]
					p[a2] = c2[j]
					var inner := Vector3(clampf(p.x, -(h.x - r), h.x - r), clampf(p.y, -(h.y - r), h.y - r), clampf(p.z, -(h.z - r), h.z - r))
					var n := (p - inner).normalized()
					pts.append(inner + n * r)
					nrm.append(n)
					uvs.append(Vector2(c1[i], c2[j]))
			for i in 5:
				for j in 5:
					var a := i * 6 + j
					var b := a + 1
					var c := a + 6
					var d := a + 7
					_tri(st, pts[a], pts[b], pts[d], nrm[a], nrm[b], nrm[d], uvs[a], uvs[b], uvs[d])
					_tri(st, pts[a], pts[d], pts[c], nrm[a], nrm[d], nrm[c], uvs[a], uvs[d], uvs[c])
	st.generate_tangents()
	return st.commit()


## Bryła obrotowa wokół osi X. `profile`: punkty (pozycja wzdłuż osi, promień).
static func lathe(profile: PackedVector2Array, segments := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	var norms := []
	for i in profile.size():
		var prev := profile[maxi(i - 1, 0)]
		var next := profile[mini(i + 1, profile.size() - 1)]
		var d := (next - prev).normalized()
		var n2 := Vector2(-d.y, d.x)   # normalna profilu: (wzdłuż osi, promieniowo)
		if n2.y < 0.0 and profile[i].y > 0.001 and i > 0 and i < profile.size() - 1:
			pass
		var ring := []
		var nr := []
		for s in segments + 1:
			var a := TAU * float(s) / float(segments)
			var dir := Vector3(0.0, cos(a), sin(a))
			ring.append(Vector3(profile[i].x, 0.0, 0.0) + dir * profile[i].y)
			nr.append((Vector3(n2.x, 0.0, 0.0) + dir * n2.y).normalized())
		rings.append(ring)
		norms.append(nr)
	for i in profile.size() - 1:
		for s in segments:
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s + 1]
			var c: Vector3 = rings[i + 1][s]
			var d: Vector3 = rings[i + 1][s + 1]
			var ua := Vector2(float(s) / segments * 8.0, float(i))
			if a.distance_squared_to(b) > 1e-9:
				_tri(st, a, b, d, norms[i][s], norms[i][s + 1], norms[i + 1][s + 1], ua, ua, ua)
			if c.distance_squared_to(d) > 1e-9:
				_tri(st, a, d, c, norms[i][s], norms[i + 1][s + 1], norms[i + 1][s], ua, ua, ua)
	return st.commit()


static var _wheel_meshes := {}

## Koło ciężarówki: opona + felga. Oś wzdłuż X, środek w początku układu.
static func wheel(radius: float, width: float, dual := false) -> Node3D:
	var key := "%.3f|%.3f" % [radius, width]
	if not _wheel_meshes.has(key):
		var w := width * 0.5
		var rim := radius * 0.56
		var tire := PackedVector2Array([
			Vector2(-w, rim), Vector2(-w, radius - 0.07), Vector2(-w + 0.025, radius - 0.02), Vector2(-w + 0.06, radius),
			Vector2(w - 0.06, radius), Vector2(w - 0.025, radius - 0.02), Vector2(w, radius - 0.07), Vector2(w, rim)])
		var rimp := PackedVector2Array([
			Vector2(-w * 0.9, rim + 0.005), Vector2(-w * 0.75, rim * 0.9), Vector2(-w * 0.2, rim * 0.82), Vector2(-w * 0.1, rim * 0.34),
			Vector2(w * 0.25, rim * 0.3), Vector2(w * 0.3, 0.0)])
		_wheel_meshes[key] = [lathe(tire, 28), lathe(rimp, 20)]
	var node := Node3D.new()
	var offs := [0.0]
	if dual:
		offs = [-width * 0.54, width * 0.54]
	for o in offs:
		var t := MeshInstance3D.new()
		t.mesh = _wheel_meshes[key][0]
		t.material_override = mat(Color(0.035, 0.035, 0.04), 0.92)
		t.position.x = o
		node.add_child(t)
		var r := MeshInstance3D.new()
		r.mesh = _wheel_meshes[key][1]
		r.material_override = mat(Color(0.72, 0.74, 0.76), 0.32, 0.9)
		r.position.x = o
		node.add_child(r)
	return node


## Dodaje do `parent` bryłę z siatki. Zwraca MeshInstance3D.
static func part(parent: Node, mesh: Mesh, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, material: Material, pos := Vector3.ZERO, r := 0.03, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return part(parent, rounded_box(size, r), material, pos, rot_deg)


static func cyl(parent: Node, radius: float, height: float, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = 20
	m.rings = 1
	return part(parent, m, material, pos, rot_deg)


## Wstęga wzdłuż krzywej (jezdnia, pobocze, linia). Odsunięcia w metrach: dodatnie = w prawo od kierunku jazdy.
## UV: x = metry w poprzek od lewej krawędzi, y = metry wzdłuż.
static func ribbon(curve: Curve3D, off_left: float, off_right: float, y: float, step := 3.0, from := 0.0, to := -1.0) -> ArrayMesh:
	var length := curve.get_baked_length()
	if to < 0.0:
		to = length
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_d := 0.0
	var first := true
	var d := from
	while true:
		var dd := minf(d, to)
		var p := curve.sample_baked(dd)
		var ahead := curve.sample_baked(minf(dd + 0.5, length))
		var back := curve.sample_baked(maxf(dd - 0.5, 0.0))
		var tan_ := (ahead - back)
		tan_.y = 0.0
		tan_ = tan_.normalized()
		var right := tan_.cross(Vector3.UP)
		var l := p + right * off_left + Vector3(0, y, 0)
		var r := p + right * off_right + Vector3(0, y, 0)
		if not first:
			var w := off_right - off_left
			_tri(st, prev_l, prev_r, r, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0, prev_d), Vector2(w, prev_d), Vector2(w, dd))
			_tri(st, prev_l, r, l, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0, prev_d), Vector2(w, dd), Vector2(0, dd))
		prev_l = l
		prev_r = r
		prev_d = dd
		first = false
		if d >= to:
			break
		d += step
	st.generate_tangents()
	return st.commit()


## Krzywa gładka przez punkty (Catmull-Rom zapisany jako Bezier).
static func curve_through(points: Array, bake := 1.0) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = bake
	for i in points.size():
		var p: Vector3 = points[i]
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var h := (b - a) / 6.0
		c.add_point(p, -h, h)
	return c
