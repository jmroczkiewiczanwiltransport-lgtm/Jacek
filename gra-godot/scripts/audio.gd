extends Node
## Dźwięk w całości generowany w kodzie przy starcie — projekt nie ma plików audio.
## Silnik ma własny „dźwiękowy” model obrotów ze zmianą biegów (12 przełożeń), choć w jeździe skrzyni nie ma.

const RATE := 22050

var rig
var sky
var cams
var muted := false
var pass_stream: AudioStreamWAV       # szum toczenia dla mijanych pojazdów (używa go traffic.gd)

var rpm := 600.0
var gear_i := 0
var _shift_t := 0.0
var _blink_prev := false
var _park_prev := true
var _beep_t := 0.0
var _p := {}
var _ext_bus := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242
	_setup_bus()
	_build()


func _setup_bus() -> void:
	# Szyna „Zewn”: w widoku z kabiny dźwięki z zewnątrz są przytłumione filtrem dolnoprzepustowym.
	_ext_bus = AudioServer.get_bus_index("Zewn")
	if _ext_bus < 0:
		AudioServer.add_bus()
		_ext_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_ext_bus, "Zewn")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 1100.0
		AudioServer.add_bus_effect(_ext_bus, lp)
		AudioServer.set_bus_effect_enabled(_ext_bus, 0, false)
		var lim := AudioEffectLimiter.new()
		AudioServer.add_bus_effect(0, lim)


func set_muted(on: bool) -> void:
	muted = on
	AudioServer.set_bus_mute(0, on)


# ---------------------------------------------------------------- generowanie próbek

func _noise(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = _rng.randf_range(-1.0, 1.0)
	return b


func _lowpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	var o := PackedFloat32Array()
	o.resize(b.size())
	for i in b.size():
		y += a * (b[i] - y)
		o[i] = y
	return o


func _highpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var lp := _lowpass(b, hz)
	for i in b.size():
		lp[i] = b[i] - lp[i]
	return lp


## Skleja koniec z początkiem, żeby pętla szumu nie „pykała”.
func _crossfade(b: PackedFloat32Array, m: int) -> PackedFloat32Array:
	var n := b.size() - m
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		o[i] = b[i]
	for i in m:
		var k := float(i) / m
		o[i] = b[i] * k + b[n + i] * (1.0 - k)
	return o


func _stream(b: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := b.size()
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var k := 0.89 / peak * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(b[i] * k))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


func _player(id: String, stream: AudioStream, ext: bool, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Zewn" if ext else "Master"
	p.volume_db = -60.0 if loop else -6.0
	add_child(p)
	if loop:
		p.play()
	_p[id] = p
	return p


func _build() -> void:
	var n := RATE
	# silnik: 6 cylindrów, 600 obr./min na biegu jałowym = 30 zapłonów na sekundę
	var eng := PackedFloat32Array()
	eng.resize(n)
	var knock := _highpass(_lowpass(_noise(n), 1800.0), 300.0)
	var amp := [1.0, 0.8, 0.55, 0.5, 0.36, 0.3, 0.22, 0.18, 0.14, 0.1]
	var phs := []
	for h in 10:
		phs.append(_rng.randf() * TAU)
	for i in n:
		var t := float(i) / RATE
		var ph := TAU * 30.0 * t
		var s := 0.8 * sin(ph * 0.5 + 0.3)
		for h in 10:
			s += amp[h] * sin(ph * (h + 1) + phs[h])
		var cyc := fmod(t * 30.0, 1.0)
		eng[i] = s * 0.42 + knock[i] * exp(-cyc * 9.0) * (0.8 + 0.2 * sin(ph / 3.0)) * 2.6
	_player("engine", _stream(eng, true), true, true)

	# toczenie, wiatr, deszcz
	var road := _crossfade(_highpass(_lowpass(_noise(n * 2 + 3000), 520.0), 55.0), 3000)
	pass_stream = _stream(road, true)
	_player("road", pass_stream, true, true)
	var wind_raw := _highpass(_lowpass(_noise(n * 2 + 3000), 2400.0), 320.0)
	for i in wind_raw.size():
		wind_raw[i] *= 0.75 + 0.25 * sin(TAU * 0.5 * i / RATE)
	_player("wind", _stream(_crossfade(wind_raw, 3000), true), true, true)
	var rain_raw := _highpass(_noise(n * 2 + 3000), 2600.0)
	for k in 260:
		var at := _rng.randi_range(0, rain_raw.size() - 200)
		for j in 120:
			rain_raw[at + j] += sin(j * 0.9) * exp(-j * 0.06) * _rng.randf_range(0.5, 1.6)
	var rain_s := _stream(_crossfade(rain_raw, 3000), true)
	_player("rain", rain_s, true, true)
	_player("spray", rain_s, true, true)

	# klakson: dwa tony z alikwotami
	var horn := PackedFloat32Array()
	horn.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 11):
			var a := 1.0 / pow(h, 0.75)
			s += a * sin(TAU * 310.0 * h * t) + a * 0.9 * sin(TAU * 370.0 * h * t + 0.7)
		horn[i] = s
	_player("horn", _stream(horn, true), true, false).volume_db = -3.0

	# sygnał cofania
	var beep := PackedFloat32Array()
	beep.resize(int(RATE * 0.26))
	for i in beep.size():
		var t := float(i) / RATE
		var env := minf(1.0, minf(t / 0.008, (0.26 - t) / 0.02))
		beep[i] = (sin(TAU * 1150.0 * t) + 0.4 * sin(TAU * 2300.0 * t) + 0.25 * sin(TAU * 3450.0 * t)) * env
	_player("beep", _stream(beep, false), true, false).volume_db = -9.0

	# przekaźnik kierunkowskazów
	for kind in ["tick", "tock"]:
		var b := PackedFloat32Array()
		b.resize(int(RATE * 0.035))
		var f := 2100.0 if kind == "tick" else 1500.0
		for i in b.size():
			var t := float(i) / RATE
			b[i] = (sin(TAU * f * t) * 0.7 + _rng.randf_range(-1.0, 1.0) * 0.5) * exp(-t * 160.0)
		_player(kind, _stream(b, false), false, false).volume_db = -14.0

	# syk hamulca postojowego
	var hiss := _highpass(_noise(int(RATE * 0.7)), 1400.0)
	for i in hiss.size():
		var t := float(i) / RATE
		hiss[i] *= exp(-t * 5.0) * minf(1.0, t / 0.01)
	_player("hiss", _stream(hiss, false), true, false).volume_db = -10.0

	# uderzenie
	var hit := _lowpass(_noise(int(RATE * 0.5)), 750.0)
	for i in hit.size():
		var t := float(i) / RATE
		hit[i] = hit[i] * exp(-t * 9.0) * 1.5 + sin(TAU * 58.0 * t) * exp(-t * 7.0)
	_player("impact", _stream(hit, false), false, false).volume_db = -3.0

	# sygnały interfejsu
	var blip := PackedFloat32Array()
	blip.resize(int(RATE * 0.09))
	for i in blip.size():
		var t := float(i) / RATE
		blip[i] = sin(TAU * 880.0 * t) * exp(-t * 30.0)
	_player("blip", _stream(blip, false), false, false).volume_db = -16.0
	var jing := PackedFloat32Array()
	jing.resize(int(RATE * 0.75))
	var notes := [392.0, 494.0, 587.0, 784.0]
	for i in jing.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in 4:
			var tt: float = t - k * 0.13
			if tt >= 0.0:
				s += (sin(TAU * notes[k] * tt) + 0.3 * sin(TAU * notes[k] * 2.0 * tt)) * exp(-tt * 5.5)
		jing[i] = s
	_player("jingle", _stream(jing, false), false, false).volume_db = -9.0


# ---------------------------------------------------------------- odtwarzanie

func play(id: String, gain := 1.0) -> void:
	var p: AudioStreamPlayer = _p.get(id)
	if p == null:
		return
	if gain != 1.0:
		p.volume_db = linear_to_db(clampf(gain, 0.05, 1.5)) - 3.0
	p.play()


static func _db(v: float) -> float:
	return maxf(-60.0, linear_to_db(maxf(v, 0.0001)))


func _process(delta: float) -> void:
	if rig == null:
		return
	var v: float = absf(rig.speed)
	var th: float = rig.throttle if rig.controls_enabled else 0.0
	# model obrotów: przełożenie = obr./min na każdy m/s; ostatni bieg daje 1250 obr./min przy 90 km/h
	var ratio := 50.0 * pow(1.28, 11 - gear_i)
	var r := v * ratio
	if rig.gear == -1:
		gear_i = 0
	if gear_i == 0:
		r = maxf(r, 600.0 + th * 520.0)      # ruszanie na sprzęgle
	if _shift_t > 0.0:
		_shift_t -= delta
	elif rig.gear == 1 and gear_i < 11 and r > (1560.0 if th > 0.5 else 1380.0):
		gear_i += 1
		_shift_t = 0.42
	elif gear_i > 0 and r < 930.0:
		gear_i -= 1
		_shift_t = 0.3
	rpm = lerpf(rpm, clampf(r, 600.0, 2150.0), 1.0 - exp(-delta * 6.0))
	var load := th * (0.2 if _shift_t > 0.0 else 1.0)
	var e: AudioStreamPlayer = _p["engine"]
	e.pitch_scale = rpm / 600.0
	e.volume_db = _db(lerpf(0.3, 0.85, load) * (0.72 + 0.28 * rpm / 2000.0))
	var k := clampf(v / 25.0, 0.0, 1.0)
	_p["road"].volume_db = _db(pow(k, 1.3) * 0.5 * (1.7 if rig.offroad else 1.0))
	_p["road"].pitch_scale = 0.7 + k * 0.6
	_p["wind"].volume_db = _db(k * k * 0.32)
	var wet: float = sky.wet if sky else 0.0
	_p["rain"].volume_db = _db(wet * 0.42)
	_p["spray"].volume_db = _db(wet * k * 0.4)
	_p["spray"].pitch_scale = 0.8
	# kierunkowskazy
	var bl: bool = rig.blinker != 0 and rig.blink_on
	if rig.blinker != 0 and bl != _blink_prev:
		_p["tick" if bl else "tock"].play()
	_blink_prev = bl
	# sygnał cofania
	if rig.gear == -1 and not rig.parking and rig.controls_enabled:
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 0.72
			_p["beep"].play()
	else:
		_beep_t = 0.0
	if rig.parking != _park_prev:
		_park_prev = rig.parking
		_p["hiss"].play()
	var h: AudioStreamPlayer = _p["horn"]
	if rig.horn and rig.controls_enabled:
		if not h.playing:
			h.play()
	elif h.playing:
		h.stop()
	if cams:
		AudioServer.set_bus_effect_enabled(_ext_bus, 0, cams.mode == 0)
