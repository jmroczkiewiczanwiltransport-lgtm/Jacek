extends Node3D
## Cztery widoki przełączane w trakcie jazdy.

const NAMES := ["Kabina", "Zza naczepy", "Z góry", "Kamera cofania"]

var rig
var cam: Camera3D
var mode := 1
var look := 0.0            # kabina: -1 = w lewo (lusterko), 1 = w prawo
var mirrors := true
var _look_s := 0.0
var _heading := Vector3(0, 0, 1)
var _pos := Vector3.ZERO
var _snap := true


func setup(r) -> void:
	rig = r
	cam = Camera3D.new()
	cam.far = 5000.0
	add_child(cam)
	cam.current = true
	set_mode(mode)


func set_mode(m: int) -> void:
	mode = posmod(m, NAMES.size())
	rig.set_cab_view(mode == 0, mirrors)
	cam.near = 0.1 if mode == 0 else 0.4
	cam.fov = [72.0, 56.0, 46.0, 84.0][mode]
	_snap = true


func snap() -> void:
	_snap = true


func _process(delta: float) -> void:
	if rig == null:
		return
	var tr: Transform3D = rig.tractor.global_transform
	var tl: Transform3D = rig.trailer.global_transform
	var up := Vector3.UP
	var h: Vector3 = (tl.basis.z * 0.65 + tr.basis.z * 0.35)
	h.y = 0.0
	h = h.normalized()
	_heading = h if _snap else _heading.lerp(h, 1.0 - exp(-delta * 3.0)).normalized()
	match mode:
		0:
			_look_s = lerpf(_look_s, look, 1.0 - exp(-delta * 9.0))
			var dir := tr.basis.z.rotated(tr.basis.y, -_look_s * 1.3).rotated(tr.basis.x, deg_to_rad(7.0))
			var head := tr * Vector3(0.55 - _look_s * 0.12, 2.74, 2.9)
			cam.global_transform = Transform3D(Basis.looking_at(dir, tr.basis.y), head)
		1:
			var anchor := tl * Vector3(0, 0, -5.0)
			var want := anchor - _heading * 19.0 + up * 7.4
			_pos = want if _snap else _pos.lerp(want, 1.0 - exp(-delta * 7.0))
			cam.global_position = _pos
			cam.look_at(tr.origin + _heading * 16.0 + up * 1.4, up)
		2:
			var center := (tr.origin + tl * Vector3(0, 0, -7.0)) * 0.5
			cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, _heading), center + up * 44.0)
		3:
			var p := tl * Vector3(0, 3.95, -12.15)
			var d := (-tl.basis.z).rotated(tl.basis.x, deg_to_rad(-34.0))
			cam.global_transform = Transform3D(Basis.looking_at(d, up), p)
	_snap = false
