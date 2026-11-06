extends RefCounted

# Every sound in Nine Coats is synthesised here, at startup, from sine waves and
# a little noise. There are no audio files in the project.
#
# The music is a slow six-note figure in A minor over a low drone: it is meant
# to be almost boring, the way a room with a fire in it is almost boring.

const MUSIC_RATE := 16000
const SFX_RATE := 22050

static var _music: AudioStreamWAV = null
static var _step: AudioStreamWAV = null
static var _voice: AudioStreamWAV = null
static var _ping: AudioStreamWAV = null
static var _chime: AudioStreamWAV = null


static func _stream(buf: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


static func music() -> AudioStreamWAV:
	if _music != null:
		return _music
	var rate: int = MUSIC_RATE
	# A minor pentatonic, walked slowly, with one note repeated to settle it
	var beats: Array = [220.00, 246.94, 329.63, 293.66, 261.63, 329.63]
	var step_len: float = 2.6
	var dur: float = step_len * float(beats.size())
	var n: int = int(dur * float(rate))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)

	for i in range(beats.size()):
		var f: float = float(beats[i])
		var start: int = int(float(i) * step_len * float(rate))
		var tail: int = int(3.8 * float(rate))
		for k in range(tail):
			var idx: int = start + k
			if idx >= n:
				break
			var t: float = float(k) / float(rate)
			# soft attack, long decay: a piano with the lid down
			var env: float = exp(-t * 1.05) * (1.0 - exp(-t * 45.0))
			var v: float = sin(TAU * f * t) * 0.55
			v += sin(TAU * f * 2.0 * t) * 0.13
			v += sin(TAU * f * 3.0 * t) * 0.045
			buf[idx] += v * env * 0.20

	# a quiet drone underneath, breathing
	for k in range(n):
		var t: float = float(k) / float(rate)
		buf[k] += sin(TAU * 110.0 * t) * 0.030 * (0.70 + 0.30 * sin(TAU * 0.07 * t))

	# fade both ends so the loop point is not a click
	var fade: int = int(float(rate) * 0.09)
	for k in range(fade):
		var a: float = float(k) / float(fade)
		buf[k] *= a
		buf[n - 1 - k] *= a

	_music = _stream(buf, rate, true)
	return _music


static func step() -> AudioStreamWAV:
	if _step != null:
		return _step
	var rate: int = SFX_RATE
	var n: int = int(float(rate) * 0.11)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var prev: float = 0.0
	var seed: int = 12345
	for k in range(n):
		var t: float = float(k) / float(rate)
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed % 2000) / 1000.0 - 1.0
		# a one-pole low pass: a boot on old boards, not a hiss
		var s: float = prev * 0.74 + noise * 0.26
		prev = s
		buf[k] = s * exp(-t * 40.0) * 0.55
	_step = _stream(buf, rate, false)
	return _step


static func voice() -> AudioStreamWAV:
	if _voice != null:
		return _voice
	var rate: int = SFX_RATE
	var n: int = int(float(rate) * 0.09)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for k in range(n):
		var t: float = float(k) / float(rate)
		var env: float = exp(-t * 26.0) * (1.0 - exp(-t * 220.0))
		var v: float = sin(TAU * 262.0 * t) * 0.60 + sin(TAU * 524.0 * t) * 0.18
		buf[k] = v * env * 0.48
	_voice = _stream(buf, rate, false)
	return _voice


static func ping() -> AudioStreamWAV:
	if _ping != null:
		return _ping
	var rate: int = SFX_RATE
	var n: int = int(float(rate) * 0.24)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for k in range(n):
		var t: float = float(k) / float(rate)
		var env: float = exp(-t * 13.0) * (1.0 - exp(-t * 300.0))
		var v: float = sin(TAU * 880.0 * t) * 0.50 + sin(TAU * 1320.0 * t) * 0.22
		buf[k] = v * env * 0.42
	_ping = _stream(buf, rate, false)
	return _ping


static func chime() -> AudioStreamWAV:
	if _chime != null:
		return _chime
	var rate: int = SFX_RATE
	var n: int = int(float(rate) * 1.1)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for k in range(n):
		var t: float = float(k) / float(rate)
		var env: float = exp(-t * 2.6) * (1.0 - exp(-t * 120.0))
		var v: float = sin(TAU * 220.0 * t) * 0.45
		v += sin(TAU * 330.0 * t) * 0.22
		v += sin(TAU * 440.0 * t) * 0.12
		buf[k] = v * env * 0.34
	_chime = _stream(buf, rate, false)
	return _chime
