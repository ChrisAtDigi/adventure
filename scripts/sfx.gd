extends Node
## All sound is synthesised at startup, so the project ships no audio files.
## Registered as the `Sfx` autoload.

const RATE := 22050
## How loud the gift shop jingle is in each room. It is never fully off.
const JINGLE_DB := {"lobby": -23.0, "hatchery": -32.0, "control": -36.0}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _jingle: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams = {
		"tick": _wav(_noise_burst(0.012, 0.25, 0.0)),
		"pickup": _wav(_notes([660.0, 990.0], 0.08, 9.0, 0.2)),
		"error": _wav(_notes([131.0, 110.0], 0.11, 3.0, 0.6)),
		"achieve": _wav(_notes([523.0, 659.0, 784.0, 1047.0], 0.085, 6.0, 0.25)),
		"thunk": _wav(_noise_burst(0.2, 0.9, 0.93)),
		"bell": _wav(_bell()),
		"power": _wav(_sweep(45.0, 140.0, 0.7)),
	}
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_ambient = _looping(_wav(_ambient_loop(), true), -20.0)
	_jingle = _looping(_wav(_jingle_loop(), true), -60.0)


func play(sound: String, volume_db := -9.0) -> void:
	if not _streams.has(sound):
		return
	for player in _pool:
		if not player.playing:
			player.stream = _streams[sound]
			player.volume_db = volume_db
			player.play()
			return


func set_room(room_id: String) -> void:
	_jingle.volume_db = JINGLE_DB.get(room_id, -40.0)


func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted


func _looping(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## A run of plucked notes. `harmonic` adds a brighter overtone.
func _notes(freqs: Array, note_len: float, decay: float, harmonic: float) -> PackedFloat32Array:
	var per := int(note_len * RATE)
	var out := PackedFloat32Array()
	out.resize(per * freqs.size())
	for n in freqs.size():
		var freq: float = freqs[n]
		for i in per:
			var t := float(i) / RATE
			var envelope := exp(-decay * t) * minf(1.0, t * 400.0) * minf(1.0, (note_len - t) * 200.0)
			var wave := sin(TAU * freq * t) + harmonic * sin(TAU * 2.0 * freq * t)
			out[n * per + i] = wave * envelope * 0.45
	return out


## Filtered noise that dies away: clicks (smoothing 0) through to thuds (smoothing near 1).
func _noise_burst(length: float, volume: float, smoothing: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var held := 0.0
	for i in count:
		held = held * smoothing + rng.randf_range(-1.0, 1.0) * (1.0 - smoothing)
		var fade := 1.0 - float(i) / count
		out[i] = held * fade * fade * volume * (1.0 + smoothing * 6.0)
	return out


func _bell() -> PackedFloat32Array:
	var count := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var wave := sin(TAU * 1568.0 * t) * exp(-4.0 * t)
		wave += 0.5 * sin(TAU * 3136.0 * t) * exp(-7.0 * t)
		wave += 0.3 * sin(TAU * 4240.0 * t) * exp(-9.0 * t)
		out[i] = wave * 0.4 * minf(1.0, t * 800.0)
	return out


func _sweep(from_hz: float, to_hz: float, length: float) -> PackedFloat32Array:
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var k := float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, k * k) / RATE
		out[i] = (sin(phase) + 0.4 * sin(phase * 2.0)) * 0.4 * sin(PI * k)
	return out


## Six seconds of cave: a low drone that breathes, and two drips.
func _ambient_loop() -> PackedFloat32Array:
	var length := 6.0
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var breath := 0.6 + 0.4 * sin(TAU * t / length)
		var wave := 0.5 * sin(TAU * 55.0 * t) + 0.28 * sin(TAU * 82.5 * t) * breath
		wave += _drip(t - 2.1, 1760.0) + _drip(t - 4.4, 1320.0)
		out[i] = wave * 0.5
	return out


func _drip(t: float, freq: float) -> float:
	if t < 0.0 or t > 0.5:
		return 0.0
	return 0.22 * sin(TAU * freq * t * (1.0 - 0.3 * t)) * exp(-14.0 * t)


## The gift shop jingle: a cheerful music-box tune on a tape that is starting to stretch.
func _jingle_loop() -> PackedFloat32Array:
	var tune := [523.0, 659.0, 784.0, 659.0, 880.0, 784.0, 659.0, 523.0,
			587.0, 698.0, 880.0, 698.0, 784.0, 784.0, 1047.0, 0.0]
	var note_len := 0.3
	var per := int(note_len * RATE)
	var out := PackedFloat32Array()
	out.resize(per * tune.size())
	var phase := 0.0
	for n in tune.size():
		var freq: float = tune[n]
		for i in per:
			var index := n * per + i
			var t := float(i) / RATE
			var wobble := 1.0 + 0.007 * sin(TAU * 0.42 * float(index) / RATE)
			phase += TAU * freq * wobble / RATE
			var envelope := exp(-5.0 * t) * minf(1.0, t * 300.0) * minf(1.0, (note_len - t) * 200.0)
			out[index] = (sin(phase) + 0.3 * sin(phase * 2.0)) * envelope * 0.5 if freq > 0.0 else 0.0
	return out
