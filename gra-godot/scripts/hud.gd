extends CanvasLayer
## Interfejs: zegary, plan kursu, pomocnik podjazdu pod rampę, komunikaty dyspozytora, plansze menu.

signal action(name: String, arg)

const GREEN := Color(0.043, 0.42, 0.263)
const PAINT := Color(0.957, 0.965, 0.945)
const ASPHALT := Color(0.07, 0.08, 0.09, 0.86)
const WARN := Color(0.96, 0.77, 0.09)
const STOP := Color(0.87, 0.22, 0.18)

var root: Control
var dash: Control
var timer_lbl: Label
var timer_cap: Label
var timer_sub: Label
var timer_box: PanelContainer
var cargo_lbl: Label
var info_lbl: Label
var toast_lbl: Label
var phone: PanelContainer
var phone_lbl: Label
var dock: PanelContainer
var dock_lbl: Label
var help: PanelContainer
var overlay: Control
var overlay_box: VBoxContainer

var state := {}          # dane dla zegarów (ustawia main.gd)
var compact := false     # telefon: same zegary, bo stan urządzeń pokazują przyciski dotykowe
var _toast_t := 0.0
var _phone_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# plan kursu: tablica u góry
	timer_box = _panel(GREEN, PAINT, 3, 12)
	_pin(timer_box, Control.PRESET_CENTER_TOP, 0, 14)
	root.add_child(timer_box)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	timer_box.add_child(tv)
	timer_cap = _label("OKNO ROZŁADUNKU", 15, PAINT)
	timer_lbl = _label("0:00", 54, PAINT)
	timer_sub = _label("", 18, PAINT)
	for l in [timer_cap, timer_lbl, timer_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tv.add_child(l)

	var cargo_box := _panel(ASPHALT, Color(1, 1, 1, 0.2), 1, 6)
	cargo_box.position = Vector2(18, 14)
	root.add_child(cargo_box)
	cargo_lbl = _label("ŁADUNEK 100%", 22, PAINT)
	cargo_box.add_child(cargo_lbl)

	var info_box := _panel(ASPHALT, Color(1, 1, 1, 0.2), 1, 6)
	_pin(info_box, Control.PRESET_TOP_RIGHT, -18, 14)
	root.add_child(info_box)
	info_lbl = _label("", 18, PAINT)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_box.add_child(info_lbl)

	toast_lbl = _label("", 26, Color(0.06, 0.07, 0.07))
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var toast_box := _panel(WARN, Color(0.06, 0.07, 0.07), 2, 6)
	toast_box.name = "ToastBox"
	_pin(toast_box, Control.PRESET_CENTER_TOP, 0, 150)
	toast_box.add_child(toast_lbl)
	toast_box.visible = false
	root.add_child(toast_box)

	# dyspozytor
	phone = _panel(Color(0.09, 0.1, 0.11, 0.94), GREEN, 2, 10)
	_pin(phone, Control.PRESET_CENTER_RIGHT, -18, 0)
	phone.custom_minimum_size = Vector2(340, 0)
	phone.visible = false
	root.add_child(phone)
	var pv := VBoxContainer.new()
	phone.add_child(pv)
	pv.add_child(_label("DYSPOZYTOR", 14, WARN))
	phone_lbl = _label("", 20, PAINT)
	phone_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_lbl.custom_minimum_size = Vector2(320, 0)
	pv.add_child(phone_lbl)

	# pomocnik podjazdu
	dock = _panel(ASPHALT, WARN, 2, 8)
	_pin(dock, Control.PRESET_CENTER_LEFT, 18, 0)
	dock.visible = false
	root.add_child(dock)
	dock_lbl = _label("", 20, PAINT)
	dock.add_child(dock_lbl)

	# zegary
	dash = Control.new()
	dash.custom_minimum_size = Vector2(640, 150)
	_pin(dash, Control.PRESET_CENTER_BOTTOM, 0, -14)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash.draw.connect(_draw_dash)
	root.add_child(dash)

	help = _panel(ASPHALT, Color(1, 1, 1, 0.2), 1, 10)
	help.position = Vector2(18, 64)
	root.add_child(help)
	help.add_child(_label(HELP_TEXT, 15, PAINT))

	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.04, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var sign_ := _panel(GREEN, PAINT, 3, 26)
	sign_.custom_minimum_size = Vector2(620, 0)
	center.add_child(sign_)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	sign_.add_child(overlay_box)
	set_hud_visible(false)


const HELP_TEXT := "W/S lub strzałki góra/dół  gaz / hamulec      A/D lub strzałki w bok  kierownica\nR  kierunek jazdy D/R (na postoju)   Spacja  hamulec postojowy\nQ/E  kierunkowskazy   F  awaryjne   L  światła   P  wycieraczki\nT  zwalniacz   H  klakson   C  kamera   Z/X  spojrzenie w lusterka\nEnter  zgłoś rozładunek   Backspace  powrót na trasę (−30 s)\nF1  ukryj tę ściągę   M  dźwięk   Esc  postój"
const TOUCH_HELP := "Lewy kciuk: kierownica (przesuwaj w bok). Prawy: GAZ i HAMULEC — im wyżej trzymasz palec, tym mocniej.\nD/R kierunek jazdy (na postoju) · P hamulec postojowy · KAM widok · strzałki i AW: kierunkowskazy, awaryjne\nŚW światła · WYC wycieraczki · ZW zwalniacz · TRĄB klakson · ZGŁOŚ ROZŁADUNEK pod rampą"


## Przypina kontrolkę do krawędzi lub środka ekranu z odsunięciem; rozmiar wynika z zawartości.
func _pin(c: Control, preset: int, dx: float, dy: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = dx
	c.offset_right = dx
	c.offset_top = dy
	c.offset_bottom = dy
	var ax := c.anchor_left
	var ay := c.anchor_top
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if is_equal_approx(ax, 0.5) else (Control.GROW_DIRECTION_BEGIN if ax > 0.5 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if is_equal_approx(ay, 0.5) else (Control.GROW_DIRECTION_BEGIN if ay > 0.5 else Control.GROW_DIRECTION_END)


func _panel(bg: Color, border: Color, bw: int, pad: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = pad + 6
	sb.content_margin_right = pad + 6
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func set_hud_visible(on: bool) -> void:
	root.visible = on


func set_compact(on: bool) -> void:
	compact = on
	dash.custom_minimum_size = Vector2(250 if on else 640, 150)
	dash.reset_size()
	_pin(dash, Control.PRESET_CENTER_BOTTOM, 0, -14)
	# na telefonie rogi ekranu zajmują przyciski, więc komunikaty idą na górę
	if on:
		_pin(phone, Control.PRESET_TOP_RIGHT, -18, 124)
		_pin(dock, Control.PRESET_TOP_LEFT, 18, 64)
		phone.custom_minimum_size = Vector2(300, 0)
		phone_lbl.custom_minimum_size = Vector2(280, 0)
		phone_lbl.add_theme_font_size_override("font_size", 17)
	else:
		_pin(phone, Control.PRESET_CENTER_RIGHT, -18, 0)
		_pin(dock, Control.PRESET_CENTER_LEFT, 18, 0)
		phone.custom_minimum_size = Vector2(340, 0)
		phone_lbl.custom_minimum_size = Vector2(320, 0)
		phone_lbl.add_theme_font_size_override("font_size", 20)


static func fmt_time(s: float) -> String:
	var n := int(round(absf(s)))
	return "%d:%02d" % [n / 60, n % 60]


static func fmt_zl(v: float) -> String:
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if v < 0 else "") + s + out + " zł"


# ---------------------------------------------------------------- aktualizacja w trakcie jazdy

func update_drive(t_left: float, objective: String, dist: float, cargo: float, info: String) -> void:
	timer_lbl.text = ("+" if t_left < 0 else "") + fmt_time(t_left)
	timer_cap.text = "SPÓŹNIENIE" if t_left < 0 else "OKNO ROZŁADUNKU"
	var sb: StyleBoxFlat = timer_box.get_theme_stylebox("panel")
	sb.bg_color = STOP if t_left < 0 else (WARN if t_left < 30 else GREEN)
	var fg := Color(0.06, 0.07, 0.07) if (t_left >= 0 and t_left < 30) else PAINT
	for l in [timer_cap, timer_lbl, timer_sub]:
		l.add_theme_color_override("font_color", fg)
	var dtxt := ""
	if dist >= 0.0:
		dtxt = ("%.1f km" % (dist / 1000.0)).replace(".", ",") if dist >= 950.0 else "%d m" % (int(dist / 10.0) * 10)
		dtxt = "  ·  " + dtxt
	timer_sub.text = objective + dtxt
	cargo_lbl.text = "ŁADUNEK %d%%" % int(ceil(cargo))
	cargo_lbl.add_theme_color_override("font_color", STOP if cargo < 40 else PAINT)
	info_lbl.text = info
	dash.queue_redraw()


func toast(text: String, seconds := 2.6, bad := false) -> void:
	toast_lbl.text = text
	var box: PanelContainer = toast_lbl.get_parent()
	var sb: StyleBoxFlat = box.get_theme_stylebox("panel")
	sb.bg_color = STOP if bad else WARN
	toast_lbl.add_theme_color_override("font_color", PAINT if bad else Color(0.06, 0.07, 0.07))
	box.visible = true
	box.reset_size()
	_toast_t = seconds


func dispatcher(text: String, seconds := 8.0) -> void:
	phone_lbl.text = text
	phone.visible = true
	_phone_t = seconds


func show_dock(text: String) -> void:
	dock.visible = text != ""
	dock_lbl.text = text
	if text != "":
		dock.reset_size()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_lbl.get_parent().visible = false
	if _phone_t > 0.0:
		_phone_t -= delta
		if _phone_t <= 0.0:
			phone.visible = false


func _draw_dash() -> void:
	var s := state
	if s.is_empty():
		return
	var font := ThemeDB.fallback_font
	var w := dash.size.x
	var h := dash.size.y
	dash.draw_style_box(_dash_box, Rect2(0, 0, w, h))
	# prędkościomierz
	var c := Vector2(95, 98)
	var r := 70.0
	var a0 := deg_to_rad(150.0)
	var a1 := deg_to_rad(390.0)
	dash.draw_arc(c, r, a0, a1, 48, Color(1, 1, 1, 0.35), 3.0, true)
	for i in 13:
		var a := lerpf(a0, a1, i / 12.0)
		var d := Vector2(cos(a), sin(a))
		dash.draw_line(c + d * (r - (10 if i % 2 == 0 else 6)), c + d * r, PAINT if i < 9 else STOP, 2.0, true)
	var kmh: float = s.get("kmh", 0.0)
	var an := lerpf(a0, a1, clampf(kmh / 120.0, 0.0, 1.0))
	dash.draw_line(c, c + Vector2(cos(an), sin(an)) * (r - 14), WARN, 4.0, true)
	dash.draw_circle(c, 6.0, PAINT)
	dash.draw_string(font, Vector2(c.x - 40, c.y + 44), str(int(round(kmh))), HORIZONTAL_ALIGNMENT_CENTER, 80, 30, PAINT)
	dash.draw_string(font, Vector2(c.x - 40, c.y + 60), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 1, 1, 0.6))
	# bieg
	var gear: String = s.get("gear", "D")
	dash.draw_string(font, Vector2(190, 62), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, WARN if gear == "R" else PAINT)
	dash.draw_string(font, Vector2(190, 84), "KIERUNEK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	if compact:
		var a2: float = s.get("art", 0.0)
		dash.draw_line(Vector2(212, 136), Vector2(212, 112), PAINT, 5.0)
		dash.draw_line(Vector2(212, 112), Vector2(212, 112) + Vector2(-sin(a2), -cos(a2)) * 16.0, WARN if absf(a2) > 0.9 else Color(0.35, 0.6, 1.0), 6.0)
		return
	# kontrolki
	var lamps := [
		["<", s.get("bl", false), Color(0.3, 0.9, 0.3)], [">", s.get("br", false), Color(0.3, 0.9, 0.3)],
		["P", s.get("parking", false), STOP], [s.get("lights_txt", "ŚW"), s.get("lights", 0) > 0, Color(0.35, 0.6, 1.0) if s.get("lights", 0) == 2 else Color(0.3, 0.9, 0.3)],
		["ZW %d" % s.get("retarder", 0), s.get("retarder", 0) > 0, WARN], ["WYC %d" % s.get("wipers", 0), s.get("wipers", 0) > 0, PAINT],
	]
	var x := 262.0
	for l in lamps:
		var on: bool = l[1]
		var rect := Rect2(x, 24, 56, 34)
		dash.draw_rect(rect, Color(l[2].r, l[2].g, l[2].b, 0.9 if on else 0.1), true)
		dash.draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
		var ink := Color(0.05, 0.05, 0.05) if on else Color(1, 1, 1, 0.55)
		if l[0] == "<" or l[0] == ">":
			# strzałka kierunkowskazu rysowana, bo nie każda czcionka ma taki znak
			var d := -1.0 if l[0] == "<" else 1.0
			var cc := rect.get_center()
			dash.draw_colored_polygon(PackedVector2Array([cc + Vector2(d * 10, 0), cc + Vector2(-d * 7, -9), cc + Vector2(-d * 7, 9)]), ink)
		else:
			dash.draw_string(font, Vector2(x, 47), l[0], HORIZONTAL_ALIGNMENT_CENTER, 56, 16, ink)
		x += 61.0
	# wiersz informacji
	dash.draw_string(font, Vector2(262, 92), s.get("line1", ""), HORIZONTAL_ALIGNMENT_LEFT, w - 280, 16, PAINT)
	dash.draw_string(font, Vector2(262, 116), s.get("line2", ""), HORIZONTAL_ALIGNMENT_LEFT, w - 280, 14, Color(1, 1, 1, 0.65))
	# kąt złamania zestawu
	var art: float = s.get("art", 0.0)
	var bx := 190.0
	dash.draw_line(Vector2(bx + 22, 136), Vector2(bx + 22, 112), PAINT, 5.0)
	dash.draw_line(Vector2(bx + 22, 112), Vector2(bx + 22, 112) + Vector2(sin(art), -cos(art)) * -0.0, PAINT, 1.0)
	dash.draw_line(Vector2(bx + 22, 112), Vector2(bx + 22, 112) + Vector2(-sin(art), -cos(art)) * 16.0, WARN if absf(art) > 0.9 else Color(0.35, 0.6, 1.0), 6.0)


var _dash_box := _make_dash_box()

func _make_dash_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ASPHALT
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	return sb


# ---------------------------------------------------------------- plansze

func hide_overlay() -> void:
	overlay.visible = false


## Plansza w formie tablicy drogowej. rows: [[etykieta, wartość], ...]; buttons: [[napis, akcja, argument], ...]
func show_board(eyebrow: String, title: String, lead: String, rows: Array, buttons: Array, note := "") -> void:
	for ch in overlay_box.get_children():
		overlay_box.remove_child(ch)
		ch.queue_free()
	var k := 0.8 if compact else 1.0        # telefon: mniejsze pismo, żeby plansza zmieściła się na wysokość
	overlay_box.add_theme_constant_override("separation", int(10 * k))
	if eyebrow != "":
		overlay_box.add_child(_label(eyebrow.to_upper(), int(16 * k), PAINT))
	var t := _label(title.to_upper(), int(54 * k), PAINT)
	overlay_box.add_child(t)
	if lead != "":
		var l := _label(lead, int(19 * k), PAINT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		overlay_box.add_child(l)
	if rows.size() > 0:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 30)
		grid.add_theme_constant_override("v_separation", int(6 * k))
		for r in rows:
			var kl := _label(r[0], int(17 * k), Color(1, 1, 1, 0.85))
			kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var v := _label(str(r[1]), int(22 * k), PAINT if not str(r[1]).begins_with("−") else Color(1.0, 0.75, 0.7))
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(kl)
			grid.add_child(v)
		overlay_box.add_child(grid)
	if note != "":
		var n := _label(note, int(16 * k), PAINT)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(560, 0)
		var nb := _panel(Color(0.027, 0.286, 0.18), Color(0, 0, 0, 0), 0, 8)
		nb.add_child(n)
		overlay_box.add_child(nb)
	var hb: Container
	if buttons.size() > 3:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 8)
		hb = g
	else:
		hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
	var first: Button = null
	for b in buttons:
		var btn := Button.new()
		btn.text = String(b[0]).to_upper()
		btn.add_theme_font_size_override("font_size", int(22 * k))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52 if not compact else 46)
		var primary := first == null
		var sb := StyleBoxFlat.new()
		sb.bg_color = WARN if primary else Color(0, 0, 0, 0)
		sb.border_color = Color(0.06, 0.07, 0.07) if primary else PAINT
		sb.set_border_width_all(3 if primary else 2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		var sbh := sb.duplicate()
		sbh.bg_color = WARN.lightened(0.2) if primary else Color(1, 1, 1, 0.12)
		for st in ["normal", "pressed"]:
			btn.add_theme_stylebox_override(st, sb)
		btn.add_theme_stylebox_override("hover", sbh)
		btn.add_theme_stylebox_override("focus", sbh)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(cn, Color(0.06, 0.07, 0.07) if primary else PAINT)
		var act: String = b[1]
		var arg = b[2] if b.size() > 2 else null
		btn.pressed.connect(func(): action.emit(act, arg))
		hb.add_child(btn)
		if first == null:
			first = btn
	overlay_box.add_child(hb)
	overlay.visible = true
	if first:
		(func(): if is_instance_valid(first) and first.is_inside_tree(): first.grab_focus()).call_deferred()
