extends Node
## Tiny procedural sound kit: every sound is synthesized at startup into an AudioStreamWAV (no audio files).

const RATE := 22050
var _streams := {}
var _players: Array = []
var _next := 0
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	_build()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(id: String, vol_db := 0.0) -> void:
	if _players.is_empty() or not _streams.has(id):
		return
	if not Game.settings.get("sound", true):
		return
	var now := Time.get_ticks_msec()
	var min_gap := 70 if id == "hit" else 40
	if now - int(_last.get(id, -1000)) < min_gap:
		return
	_last[id] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = vol_db + (-8.0 if id == "hit" else -3.0)
	p.pitch_scale = randf_range(0.93, 1.07)
	p.play()


func _build() -> void:
	_streams["hit"] = _synth(0.09, func(t, _i): return _noise() * _env(t, 0.09, 0.002) * 0.6 + sin(TAU * 140.0 * t) * _env(t, 0.09, 0.001) * 0.5)
	_streams["cast"] = _synth(0.28, func(t, _i): return sin(TAU * (300.0 + 900.0 * t) * t) * _env(t, 0.28, 0.02) * 0.45 + _noise() * _env(t, 0.28, 0.01) * 0.15)
	_streams["level_up"] = _synth(0.7, func(t, _i): return _arp(t, [523.0, 659.0, 784.0, 1046.0], 0.12) * _env(t, 0.7, 0.01) * 0.4)
	_streams["rank"] = _synth(0.25, func(t, _i): return _arp(t, [660.0, 990.0], 0.08) * _env(t, 0.25, 0.005) * 0.4)
	_streams["death"] = _synth(0.9, func(t, _i): return sin(TAU * (220.0 - 150.0 * t) * t) * _env(t, 0.9, 0.01) * 0.5)
	_streams["wave"] = _synth(0.8, func(t, _i): return (sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 165.0 * t)) * _env(t, 0.8, 0.05) * 0.35)
	_streams["boss"] = _synth(1.4, func(t, _i): return (sin(TAU * 55.0 * t) + 0.6 * sin(TAU * 82.5 * t) + 0.3 * _noise()) * _env(t, 1.4, 0.1) * 0.4)
	_streams["clear"] = _synth(0.8, func(t, _i): return _arp(t, [392.0, 523.0, 659.0], 0.15) * _env(t, 0.8, 0.01) * 0.35)
	_streams["teleport"] = _synth(0.45, func(t, _i): return sin(TAU * (900.0 - 700.0 * t) * t) * _env(t, 0.45, 0.02) * 0.3 + _noise() * _env(t, 0.45, 0.05) * 0.08)
	_streams["buy"] = _synth(0.2, func(t, _i): return _arp(t, [1200.0, 1600.0], 0.06) * _env(t, 0.2, 0.003) * 0.3)
	_streams["item"] = _synth(0.3, func(t, _i): return sin(TAU * 700.0 * t) * _env(t, 0.3, 0.01) * 0.3)
	_streams["slam"] = _synth(0.5, func(t, _i): return (_noise() * 0.7 + sin(TAU * 60.0 * t)) * _env(t, 0.5, 0.003) * 0.6)
	_streams["orb"] = _synth(0.3, func(t, _i): return sin(TAU * (500.0 + 200.0 * sin(TAU * 12.0 * t)) * t) * _env(t, 0.3, 0.02) * 0.25)
	_streams["beam"] = _synth(0.8, func(t, _i): return (sin(TAU * 90.0 * t) * 0.6 + _noise() * 0.2) * _env(t, 0.8, 0.1) * 0.4)
	_streams["victory"] = _synth(1.6, func(t, _i): return _arp(t, [392.0, 523.0, 659.0, 784.0, 1046.0, 1046.0], 0.18) * _env(t, 1.6, 0.01) * 0.4)
	_streams["defeat"] = _synth(1.4, func(t, _i): return _arp(t, [392.0, 349.0, 311.0, 262.0], 0.25) * _env(t, 1.4, 0.02) * 0.4)
	_streams["click"] = _synth(0.06, func(t, _i): return sin(TAU * 1000.0 * t) * _env(t, 0.06, 0.001) * 0.3)


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _env(t: float, dur: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - clampf((t - attack) / maxf(0.001, dur - attack), 0.0, 1.0), 2.0)


func _arp(t: float, notes: Array, step: float) -> float:
	var i := mini(int(t / step), notes.size() - 1)
	var f: float = notes[i]
	return sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.15


func _synth(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := clampf(float(f.call(t, i)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
