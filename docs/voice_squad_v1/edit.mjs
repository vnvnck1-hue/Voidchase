// decoded/*.wav(웹에서 받은 mp3 를 브라우저로 디코딩한 44.1kHz 모노) → edited/*.wav 게임용 다듬기 + meta.json
// docs/voice_gunner_v1/edit.mjs 2차 규칙 + 건너 2차 선택 때의 음절 편집을 처음부터 적용:
// 20ms RMS 가 최대치 -30dB 넘는 덩어리 중 가장 센 하나만(KEEP_TWO 는 그 앞 덩어리까지), 앞뒤 여유 10ms,
// 덩어리 사이 쉼 0.06초, 최대 0.6초, 피크 -3dB, 앞 5ms·끝 40ms 페이드.
// 평균 음높이(자기상관, 소리 구간)도 적어 목소리 톤 비교에 쓴다.
//   node edit.mjs                decoded/ 전부 → edited/
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, "decoded"), DST = path.join(HERE, "edited");
fs.mkdirSync(DST, { recursive: true });
const GAP = 0.06, PAD = 0.01, FADE = 0.04, TH_DB = -30, PEAK = Math.pow(10, -3 / 20);
const maxFor = () => 0.6;
const KEEP_TWO = ["knight_lola_skill-04", "knight_aisyah_skill-04"];   // "흡… 핫!"

function readWav(file) {
  const b = fs.readFileSync(file);
  const rate = b.readUInt32LE(24), n = b.readUInt32LE(40) / 2, s = new Float32Array(n);
  for (let i = 0; i < n; i++) s[i] = b.readInt16LE(44 + i * 2) / 32768;
  return { rate, s };
}
function wav(samples, rate) {
  const b = Buffer.alloc(44 + samples.length * 2);
  b.write("RIFF", 0); b.writeUInt32LE(36 + samples.length * 2, 4); b.write("WAVE", 8); b.write("fmt ", 12);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24);
  b.writeUInt32LE(rate * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write("data", 36); b.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  return b;
}
function energySegs(s, rate) {
  const w = Math.round(rate * 0.02), rms = [];
  for (let i = 0; i < s.length; i += w) { let e = 0; for (let k = i; k < Math.min(i + w, s.length); k++) e += s[k] * s[k]; rms.push(Math.sqrt(e / w)); }
  const th = Math.max(...rms) * Math.pow(10, TH_DB / 20), segs = [];
  let start = -1;
  rms.forEach((v, j) => { if (v > th && start < 0) start = j; if (v <= th && start >= 0) { segs.push([start * 0.02, j * 0.02]); start = -1; } });
  if (start >= 0) segs.push([start * 0.02, rms.length * 0.02]);
  const dur = s.length / rate;
  const out = [];
  for (const [a, b] of segs.filter(([a, b]) => b - a > 0.06).map(([a, b]) => [Math.max(0, a - PAD), Math.min(dur, b + PAD)])) {
    if (out.length && a - out[out.length - 1][1] < 0.08) out[out.length - 1][1] = Math.max(out[out.length - 1][1], b);
    else out.push([a, b]);
  }
  return out;
}
// 40ms 창 자기상관으로 120~900Hz 기본 주파수, 유성음(상관 0.5 이상) 창의 중앙값
function pitch(s, rate) {
  const w = Math.round(rate * 0.04), lo = Math.floor(rate / 900), hi = Math.ceil(rate / 120), f0 = [];
  let peak = 0; for (const v of s) peak = Math.max(peak, Math.abs(v));
  for (let i = 0; i + w + hi < s.length; i += w) {
    let e = 0; for (let k = 0; k < w; k++) e += s[i + k] * s[i + k];
    if (Math.sqrt(e / w) < peak * 0.1) continue;
    let best = 0, lag = 0;
    for (let L = lo; L <= hi; L++) {
      let c = 0, e2 = 0; for (let k = 0; k < w; k++) { c += s[i + k] * s[i + k + L]; e2 += s[i + k + L] * s[i + k + L]; }
      const r = c / Math.sqrt(e * e2 + 1e-12); if (r > best) { best = r; lag = L; }
    }
    if (best > 0.5) f0.push(rate / lag);
  }
  f0.sort((a, b) => a - b);
  return f0.length ? Math.round(f0[f0.length >> 1]) : null;
}

const meta = { clips: {} };
for (const f of fs.readdirSync(SRC).filter((x) => x.endsWith(".wav")).sort()) {
  const key = f.replace(".wav", ""), MAX = maxFor(key);
  const { rate, s } = readWav(path.join(SRC, f));
  const all = energySegs(s, rate), parts = [];
  // 한 음절 원칙(건너 2차 피드백 "두 번 한다 → 한 번만"): 소리 덩어리 중 가장 센 것 하나만.
  // 두 동작을 의도한 문구(KEEP_TWO)만 가장 센 덩어리와 그 앞 덩어리를 둘 다.
  const energy = all.map(([a, b]) => { let e = 0; for (let i = Math.round(a * rate); i < Math.round(b * rate); i++) e = Math.max(e, Math.abs(s[i])); return e; });
  const top = energy.indexOf(Math.max(...energy));
  const segs = KEEP_TWO.some((p) => key.includes(p)) && top > 0 ? all.slice(top - 1, top + 1) : all.slice(top, top + 1);
  let len = 0, cut = false;
  segs.forEach(([a, b], k) => {
    if (len >= MAX) { cut = true; return; }
    if (k > 0) { parts.push(new Float32Array(Math.round(GAP * rate))); len += GAP; }
    let piece = s.slice(Math.round(a * rate), Math.round(b * rate));
    if (len + piece.length / rate > MAX) { piece = piece.slice(0, Math.max(0, Math.round((MAX - len) * rate))); cut = true; }
    parts.push(piece); len += piece.length / rate;
  });
  let out = new Float32Array(parts.reduce((n, p) => n + p.length, 0)), o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  let peak = 0; for (const v of out) peak = Math.max(peak, Math.abs(v));
  const g = peak > 0 ? PEAK / peak : 1, fd = Math.round(FADE * rate), f0 = Math.round(0.005 * rate);
  for (let k = 0; k < out.length; k++) {
    let e = g;
    if (k < f0) e *= k / f0;
    if (k > out.length - fd) e *= (out.length - k) / fd;
    out[k] *= e;
  }
  fs.writeFileSync(path.join(DST, f), wav(out, rate));
  meta.clips[key] = { raw_sec: +(s.length / rate).toFixed(2), sec: +(out.length / rate).toFixed(2), cut, segs: all.length, kept: segs.length, f0: pitch(out, rate) };
  console.log(key.padEnd(26), meta.clips[key].raw_sec, "→", meta.clips[key].sec + "s", cut ? "잘림" : "", "덩어리", all.length, "중", segs.length, "f0", meta.clips[key].f0);
}
fs.writeFileSync(path.join(HERE, "meta.json"), JSON.stringify(meta, null, 2));
