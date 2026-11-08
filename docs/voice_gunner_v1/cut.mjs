// 2차 선택(2026-11-06) 음절 편집: decoded/ 원본에서 소리 덩어리(음절)를 하나씩 잘라 edited/<key>-sN.wav 로.
// 덩어리 = 20ms 음량이 최대치 -30dB 넘는 구간(0.08초 미만 틈은 이음), 앞뒤 여유 10ms, 피크 -3dB, 앞 5ms·끝 40ms 페이드, 최대 0.6초.
// 요청: "하잇을 두 번" → 첫 음절만 / "흣, 휴 두 개" → 음절별로 / "히얏 두 번" → 첫 음절만 / "큿 두 음절" → t1 하나, t2 둘로.
//   node cut.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CUTS = {
  "v2iro_skill-05-t1": [1],
  "v2iro_skill-06-t1": [1, 2, 3],   // 3번은 들리지 않던 짧은 끝소리 — 확인용
  "v2iro_hurt-04-t2": [1],
  "v2iro_hurt-05-t1": [1],
  "v2iro_hurt-05-t2": [1, 2],
};
const PAD = 0.01, FADE = 0.04, MAX = 0.6, PEAK = Math.pow(10, -3 / 20);

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
function segs(s, rate) {
  const w = Math.round(rate * 0.02), rms = [];
  for (let i = 0; i < s.length; i += w) { let e = 0; for (let k = i; k < Math.min(i + w, s.length); k++) e += s[k] * s[k]; rms.push(Math.sqrt(e / w)); }
  const th = Math.max(...rms) * Math.pow(10, -30 / 20), raw = [];
  let start = -1;
  rms.forEach((v, j) => { if (v > th && start < 0) start = j; if (v <= th && start >= 0) { raw.push([start * 0.02, j * 0.02]); start = -1; } });
  if (start >= 0) raw.push([start * 0.02, rms.length * 0.02]);
  const out = [];
  for (const [a, b] of raw.filter(([a, b]) => b - a > 0.06)) {
    if (out.length && a - out[out.length - 1][1] < 0.08) out[out.length - 1][1] = b;
    else out.push([a, b]);
  }
  return out;
}

const meta = JSON.parse(fs.readFileSync(path.join(HERE, "meta.json"), "utf8"));
for (const [key, picks] of Object.entries(CUTS)) {
  const { rate, s } = readWav(path.join(HERE, "decoded", key + ".wav"));
  const sg = segs(s, rate), dur = s.length / rate;
  console.log(key, "덩어리", sg.map(([a, b]) => a.toFixed(2) + "~" + b.toFixed(2)).join(" "));
  for (const n of picks) {
    if (!sg[n - 1]) { console.log("  없음 s" + n); continue; }
    const [a, b] = sg[n - 1];
    let out = s.slice(Math.round(Math.max(0, a - PAD) * rate), Math.round(Math.min(dur, b + PAD, a - PAD + MAX) * rate));
    let peak = 0; for (const v of out) peak = Math.max(peak, Math.abs(v));
    const g = PEAK / peak, fd = Math.round(FADE * rate), f0 = Math.round(0.005 * rate);
    for (let k = 0; k < out.length; k++) {
      let e = g;
      if (k < f0) e *= k / f0;
      if (k > out.length - fd) e *= (out.length - k) / fd;
      out[k] *= e;
    }
    const id = `${key}-s${n}`;
    fs.writeFileSync(path.join(HERE, "edited", id + ".wav"), wav(out, rate));
    meta.clips[id] = { from: key, seg: n, sec: +(out.length / rate).toFixed(2), cut: b - a + 2 * PAD > MAX };
    console.log("  ", id, meta.clips[id].sec + "s");
  }
}
fs.writeFileSync(path.join(HERE, "meta.json"), JSON.stringify(meta, null, 2));
