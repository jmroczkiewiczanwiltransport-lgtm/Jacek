extends Control
## Sterowanie dotykowe: kierownica i pedały analogowe, reszta jako przyciski.
## Obsługuje wiele palców naraz (każdy palec „trzyma” strefę, w której dotknął ekranu).

signal tapped(id: String)

const PAINT := Color(0.957, 0.965, 0.945)
const WARN := Color(0.96, 0.77, 0.09)
const STOP := Color(0.87, 0.22, 0.18)
const BASE := Color(0.07, 0.08, 0.09, 0.62)

var active := false          # włączone tylko w trakcie jazdy
var steer := 0.0             # -1 w prawo .. 1 w lewo
var gas := 0.0
var brake := 0.0
var horn := false
var look := 0.0
var lit := {}                # id -> bool: podświetlenie przycisku (stan urządzenia)
var labels := {"gear": "D", "lights": "ŚW", "retarder": "ZW 0", "wipers": "WYC 0"}
var show_confirm := false
var cab := false

var _zones := {}             # id -> Rect2
var _touch := {}             # indeks palca -> id strefy
var _steer_x := 0.0
var _size := Vector2.ZERO

# Strzałki rysujemy jako trójkąty: czcionka w wersji przeglądarkowej i na Androidzie nie ma takich znaków.
const TAPS := {"gear": "D", "parking": "P", "camera": "KAM", "blink_left": "<", "hazard": "AW", "blink_right": ">",
	"lights": "ŚW", "wipers": "WYC", "retarder": "ZW", "pause": "II", "confirm": "ZGŁOŚ ROZŁADUNEK"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _layout() -> void:
	var w := _size.x
	var h := _size.y
	_zones = {
		"steer": Rect2(22, h - 148, 330, 126),
		"brake": Rect2(w - 300, h - 196, 128, 176),
		"gas": Rect2(w - 158, h - 226, 136, 206),
		"gear": Rect2(w - 300, h - 300, 66, 58), "parking": Rect2(w - 226, h - 300, 66, 58),
		"horn": Rect2(w - 152, h - 300, 66, 58), "camera": Rect2(w - 78, h - 300, 66, 58),
		"blink_left": Rect2(22, h - 222, 62, 58), "hazard": Rect2(90, h - 222, 62, 58), "blink_right": Rect2(158, h - 222, 62, 58),
		"lights": Rect2(226, h - 222, 62, 58), "wipers": Rect2(294, h - 222, 62, 58), "retarder": Rect2(362, h - 222, 70, 58),
		"pause": Rect2(w - 84, 62, 62, 52),
		"confirm": Rect2(w * 0.5 - 150, h - 236, 300, 56),
		"look_left": Rect2(0, h * 0.5 - 46, 54, 92), "look_right": Rect2(w - 54, h * 0.5 - 46, 54, 92),
	}


func _shown(id: String) -> bool:
	if id == "confirm": return show_confirm
	if id == "look_left" or id == "look_right": return cab
	return true


func _zone_at(p: Vector2) -> String:
	for id in _zones:
		if _shown(id) and (_zones[id] as Rect2).grow(6.0).has_point(p):
			return id
	return ""


func release_all() -> void:
	_touch.clear()
	steer = 0.0
	gas = 0.0
	brake = 0.0
	horn = false
	look = 0.0
	queue_redraw()


func _input(e: InputEvent) -> void:
	if not active or not visible:
		return
	if e is InputEventScreenTouch:
		var p: Vector2 = make_input_local(e).position
		if e.pressed:
			var id := _zone_at(p)
			if id == "":
				return
			_touch[e.index] = id
			if TAPS.has(id):
				tapped.emit(id)
			else:
				_apply(id, p)
			get_viewport().set_input_as_handled()
		elif _touch.has(e.index):
			_release(_touch[e.index])
			_touch.erase(e.index)
			get_viewport().set_input_as_handled()
		queue_redraw()
	elif e is InputEventScreenDrag and _touch.has(e.index):
		_apply(_touch[e.index], make_input_local(e).position)
		queue_redraw()


func _apply(id: String, p: Vector2) -> void:
	var r: Rect2 = _zones[id]
	match id:
		"steer":
			_steer_x = clampf((p.x - r.get_center().x) / (r.size.x * 0.5 * 0.78), -1.0, 1.0)
			steer = -_steer_x if absf(_steer_x) > 0.05 else 0.0      # dodatni skręt w grze to w lewo
		"gas": gas = clampf((r.end.y - p.y) / r.size.y * 1.3, 0.3, 1.0)
		"brake": brake = clampf((r.end.y - p.y) / r.size.y * 1.3, 0.3, 1.0)
		"horn": horn = true
		"look_left": look = -1.0
		"look_right": look = 1.0


func _release(id: String) -> void:
	match id:
		"steer":
			steer = 0.0
			_steer_x = 0.0
		"gas": gas = 0.0
		"brake": brake = 0.0
		"horn": horn = false
		"look_left", "look_right": look = 0.0


func _process(_delta: float) -> void:
	# rozmiar bierzemy z obszaru widoku: ukryta kontrolka nie zawsze ma aktualny własny rozmiar
	var vs := get_viewport_rect().size
	if visible and vs != _size:
		_size = vs
		position = Vector2.ZERO
		size = vs
		_layout()
		queue_redraw()


func _box(r: Rect2, fill: Color, border: Color, radius := 12) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text(r: Rect2, s: String, px: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(r.position.x, r.get_center().y + px * 0.36), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, col)


## Trójkąt-strzałka: dir = -1 w lewo, 1 w prawo.
func _arrow(c: Vector2, s: float, dir: int, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s, 0), c + Vector2(-dir * s * 0.7, -s), c + Vector2(-dir * s * 0.7, s)]), col)


func _draw() -> void:
	if _zones.is_empty():
		return
	var edge := Color(1, 1, 1, 0.4)
	# kierownica
	var sr: Rect2 = _zones["steer"]
	_box(sr, BASE, edge, int(sr.size.y * 0.5))
	_arrow(Vector2(sr.position.x + 28, sr.get_center().y), 11.0, -1, Color(1, 1, 1, 0.6))
	_arrow(Vector2(sr.end.x - 28, sr.get_center().y), 11.0, 1, Color(1, 1, 1, 0.6))
	draw_circle(sr.get_center() + Vector2(_steer_x * (sr.size.x * 0.5 - 62), 0), 44.0, Color(PAINT.r, PAINT.g, PAINT.b, 0.92))
	# pedały: wypełnienie pokazuje wciśnięcie
	for id in ["brake", "gas"]:
		var r: Rect2 = _zones[id]
		var v := brake if id == "brake" else gas
		var col := STOP if id == "brake" else Color(0.2, 0.62, 0.35)
		_box(r, Color(col.r, col.g, col.b, 0.38), edge, 14)
		if v > 0.0:
			_box(Rect2(r.position.x, r.end.y - r.size.y * v, r.size.x, r.size.y * v), Color(col.r, col.g, col.b, 0.9), edge, 14)
		_text(r, "HAMULEC" if id == "brake" else "GAZ", 18, PAINT)
	# przyciski
	for id in TAPS:
		if not _shown(id):
			continue
		var r2: Rect2 = _zones[id]
		var on: bool = lit.get(id, false)
		var primary: bool = id == "confirm"
		var fill := BASE
		if primary: fill = WARN
		elif on: fill = Color(WARN.r, WARN.g, WARN.b, 0.9) if id != "parking" else Color(STOP.r, STOP.g, STOP.b, 0.92)
		_box(r2, fill, Color(0.06, 0.07, 0.07) if primary else edge, 10)
		var txt: String = labels.get(id, TAPS[id])
		var ink := Color(0.06, 0.07, 0.07) if (primary or (on and id != "parking")) else PAINT
		if id == "blink_left" or id == "blink_right":
			_arrow(r2.get_center(), 12.0, -1 if id == "blink_left" else 1, ink)
		else:
			_text(r2, txt, 20 if txt.length() <= 4 else (15 if not primary else 20), ink)
	var hr: Rect2 = _zones["horn"]
	_box(hr, Color(WARN.r, WARN.g, WARN.b, 0.9) if horn else BASE, edge, 10)
	_text(hr, "TRĄB", 15, Color(0.06, 0.07, 0.07) if horn else PAINT)
	if cab:
		for id in ["look_left", "look_right"]:
			var r3: Rect2 = _zones[id]
			_box(r3, BASE, edge, 10)
			_arrow(r3.get_center(), 13.0, -1 if id == "look_left" else 1, PAINT)
