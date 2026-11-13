## 대사 옹알이 음성(scripts/story/voice_babble.gd) 점검: 화자·모음별 음절이 만들어지고, 클리핑 없이 들릴 만한 크기이며,
## 한글 모음 분류가 맞는지, 화자마다 기본 음높이가 실제로 다른지(영점 교차로 추정) 본다.
##   godot --headless --path . -s res://tools/test/probe_voice.gd
extends SceneTree


func _init() -> void:
	var fail := 0
	var cases := {"가": "a", "네": "e", "이": "i", "오": "o", "우": "u", "쪽": "o", "왕": "a", "께": "e", " ": "", "…": "", "?": ""}
	for ch in cases:
		var got := VoiceBabble.vowel_of(ch)
		if got != cases[ch]:
			fail += 1
			print("[voice] FAIL vowel_of(%s) = '%s' (want '%s')" % [ch, got, cases[ch]])
	print("[voice] vowel mapping checked (%d cases)" % cases.size())
	var pitches := {}
	for who in VoiceBabble.VOICES:
		var t0 := Time.get_ticks_msec()
		VoiceBabble.warm(who)
		var ms := Time.get_ticks_msec() - t0
		var worst_peak := 0.0
		var min_rms := 9.0
		for v in VoiceBabble.FORMANTS:
			var s: AudioStreamWAV = VoiceBabble._cache[who + "/" + v]
			var n := s.data.size() / 2
			var peak := 0.0
			var sum := 0.0
			for i in n:
				var x := s.data.decode_s16(i * 2) / 32768.0
				peak = maxf(peak, absf(x))
				sum += x * x
			worst_peak = maxf(worst_peak, peak)
			min_rms = minf(min_rms, sqrt(sum / n))
		# 기본 음높이 추정: 'a' 음절 가운데 구간의 자기상관 봉우리
		var a: AudioStreamWAV = VoiceBabble._cache[who + "/a"]
		var n2 := a.data.size() / 2
		var from := n2 / 5
		var win := n2 / 2
		var best_lag := 0
		var best := -1.0
		for lag in range(int(VoiceBabble.RATE / 600.0), int(VoiceBabble.RATE / 80.0)):
			var acc := 0.0
			for i in win - lag:
				acc += (a.data.decode_s16((from + i) * 2) / 32768.0) * (a.data.decode_s16((from + i + lag) * 2) / 32768.0)
			acc /= float(win - lag)
			if acc > best:
				best = acc
				best_lag = lag
		var f0 := float(VoiceBabble.RATE) / best_lag
		pitches[who] = f0
		var want := float(VoiceBabble.VOICES[who]["f0"])
		var ok := worst_peak < 0.62 and min_rms > 0.03 and absf(f0 - want) / want < 0.12
		if not ok:
			fail += 1
		print("[voice] %s %s: 5 syllables in %d ms, peak %.2f, min rms %.3f, measured pitch %.0f Hz (set %.0f)" % ["ok  " if ok else "FAIL", who, ms, worst_peak, min_rms, f0, want])
	print("[voice] DONE failures=%d" % fail)
	quit(1 if fail > 0 else 0)
