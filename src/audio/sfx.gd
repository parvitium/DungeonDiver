class_name Sfx
extends RefCounted
## Tiny generated WAV placeholders so hit/hurt/wind-up have audible feedback.


static var _cache: Dictionary = {}


static func hurt_grunt() -> AudioStreamWAV:
	return _cached("hurt", 165.0, 0.22, 0.72, true)


static func flesh_hit() -> AudioStreamWAV:
	return _cached("hit", 90.0, 0.12, 0.85, true)


static func attack_windup() -> AudioStreamWAV:
	return _cached("windup", 110.0, 0.28, 0.45, false)


static func death_fall() -> AudioStreamWAV:
	return _cached("death", 70.0, 0.4, 0.55, true)


static func _cached(key: String, hz: float, seconds: float, volume: float, noisy: bool) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var stream := _tone(hz, seconds, volume, noisy)
	_cache[key] = stream
	return stream


static func _tone(hz: float, seconds: float, volume: float, noisy: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := maxi(1, int(float(rate) * seconds))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hz * 1000.0)
	for i in n:
		var t := float(i) / float(rate)
		var env := 1.0 - t / seconds
		var sample := sin(TAU * hz * t) * env
		if noisy:
			sample = sample * 0.55 + (rng.randf() * 2.0 - 1.0) * 0.45 * env
		var s := int(clampf(sample * volume, -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
