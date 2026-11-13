## 절차 생성 배경음(scripts/hub/ambience.gd) 파형 점검: 클리핑 없음 · 적당한 음량 · 루프 이음매가 끊기지 않음.
##   godot --headless --path . -s res://tools/test/probe_ambience.gd
extends SceneTree


func _init() -> void:
	var fail := 0
	for kind in ["hub", "dive"]:
		var t0 := Time.get_ticks_msec()
		Ambience._build(kind)
		var ms := Time.get_ticks_msec() - t0
		var s: AudioStreamWAV = Ambience._cache[kind]
		var n := s.data.size() / 2
		var peak := 0.0
		var sum := 0.0
		var max_step := 0.0
		var prev := s.data.decode_s16(0) / 32768.0
		for i in n:
			var v := s.data.decode_s16(i * 2) / 32768.0
			peak = maxf(peak, absf(v))
			sum += v * v
			if i > 0:
				max_step = maxf(max_step, absf(v - prev))
			prev = v
		var rms := sqrt(sum / n)
		var seam := absf(s.data.decode_s16(0) / 32768.0 - s.data.decode_s16((n - 1) * 2) / 32768.0)
		var ok := peak < 0.79 and rms > 0.05 and rms < 0.4 and seam <= max_step * 1.5 and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end == n
		if not ok:
			fail += 1
		print("[ambience] %s %s: %.1fs loop, built in %d ms, peak %.2f (int16 clip at 0.79 of scale), rms %.3f, seam step %.4f vs max in-loop step %.4f" %
			["ok  " if ok else "FAIL", kind, float(n) / s.mix_rate, ms, peak, rms, seam, max_step])
	print("[ambience] DONE failures=%d" % fail)
	quit(1 if fail > 0 else 0)
