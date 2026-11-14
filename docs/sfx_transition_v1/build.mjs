// 화면 전환(번개 닫힘) 소리 후보: decoded/*.wav → edited/*.wav + 고르기 페이지 transition.html (docs/sfx_super_ult_v1/build.mjs 를 고쳐 씀)
// 다듬기: 앞 무음(최대치 -40dB 아래) 자름(여유 5ms) — 컷인 맞물림(0.15초)에 바로 터지게, 피크 -3dB, 앞 5ms·끝 150ms 페이드, 최대 1.5초.
// 카드에 "피크까지 ms"(소리 시작에서 가장 센 지점까지)를 적어 얼마나 날카롭게 터지는지 비교한다.
// 페이지 형식은 docs/voice_squad_v1/build_page.mjs 와 같다(한 번만 재생·여러 개 체크·코멘트·결과 복사).
//   node build.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, "decoded"), DST = path.join(HERE, "edited");
fs.mkdirSync(DST, { recursive: true });
const PROMPTS = {
  "tr-a": ["번개 치직 → 철판 셔터 쾅", "Fast stylish screen transition: sharp electric lightning crack zapping diagonally, immediately followed by a heavy metal shutter slamming shut with a punchy whoosh, clean sci-fi anime game UI"],
  "tr-b": ["전기 지직 + 휙 → 단단한 탁", "Quick sci-fi panel wipe closing: crisp electric zap and swoosh sliding diagonally into a tight solid thud, short and punchy, modern game menu transition"],
};
const MAX = 1.0, PAD = 0.005, FADE = 0.12, PEAK = Math.pow(10, -3 / 20);

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

const meta = {}, audio = {};
for (const f of fs.readdirSync(SRC).filter((x) => x.endsWith(".wav")).sort()) {
  const id = f.replace(".wav", "");
  const { rate, s } = readWav(path.join(SRC, f));
  let peak = 0; for (const v of s) peak = Math.max(peak, Math.abs(v));
  const th = peak * Math.pow(10, -40 / 20);
  let a = 0; while (a < s.length && Math.abs(s[a]) < th) a++;
  a = Math.max(0, a - Math.round(PAD * rate));
  let out = s.slice(a, Math.min(s.length, a + Math.round(MAX * rate)));
  const g = PEAK / peak, fd = Math.round(FADE * rate), f0 = Math.round(0.005 * rate);
  let e2 = 0;
  for (let k = 0; k < out.length; k++) {
    let e = g;
    if (k < f0) e *= k / f0;
    if (k > out.length - fd) e *= (out.length - k) / fd;
    out[k] *= e; e2 += out[k] * out[k];
  }
  fs.writeFileSync(path.join(DST, f), wav(out, rate));
  let pk = 0, pi = 0; for (let k = 0; k < out.length; k++) if (Math.abs(out[k]) > pk) { pk = Math.abs(out[k]); pi = k; }
  meta[id] = { lead_cut: +(a / rate).toFixed(2), sec: +(out.length / rate).toFixed(2), rms_db: +(10 * Math.log10(e2 / out.length)).toFixed(1), peak_ms: Math.round(pi / rate * 1000) };
  audio[id] = fs.readFileSync(path.join(DST, f)).toString("base64");
  console.log(id, meta[id]);
}
fs.writeFileSync(path.join(HERE, "meta.json"), JSON.stringify(meta, null, 2));

const data = Object.entries(PROMPTS).map(([p, [label, prompt]]) => ({
  key: p, label, prompt,
  clips: [1, 2, 3, 4].filter((n) => meta[`${p}-${n}`]).map((n) => ({ id: `${p}-${n}`, n, ...meta[`${p}-${n}`] })),
}));
const css = fs.readFileSync(path.join(HERE, "..", "voice_gunner_v1", "gunner-voice-v2.html"), "utf8").match(/<style>[\s\S]*?<\/style>/)[0];
const html = `<title>화면 전환 소리</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
${css}
<style>.prompt { font-size:12.5px; color:var(--muted); margin:-6px 0 0; overflow-wrap:anywhere; }</style>
<main>
  <section class="intro">
    <h1>화면 전환 — 번개 닫힘 소리 고르기</h1>
    <p>씬이 바뀔 때 나오는 화면 전환 "번개 닫힘"(번개가 대각선으로 치고 → 모서리의 어두운 판이 그 대각선으로 0.36초 만에 닫힘 → 되감아 0.3초에 열림)에 붙일 소리 후보 ${Object.keys(audio).length}개입니다. 크레딧을 아끼려고 ElevenLabs 효과음(SFX v3, 1초) 설명 2가지 × 변형 4개만 만들었습니다.</p>
    <ul>
      <li>닫히기 시작할 때 한 번 낼 생각입니다. 카드의 "피크까지"가 0.36초 근처면 판이 다 닫히는 순간에 가장 세게 들립니다.</li>
      <li>열릴 때도 소리가 필요하면 코멘트로 알려 주세요(같은 소리를 거꾸로 틀거나 작게 다시 쓰는 방법도 있습니다).</li>
      <li>동그란 버튼을 누르면 <b>한 번만</b> 재생됩니다. 쓸 것을 체크하고(여러 개면 전환마다 무작위) <b>결과 복사</b>로 붙여 주세요.</li>
    </ul>
  </section>
  <details class="verify"><summary>만든 방법</summary>
    <ul>
      <li>ElevenLabs 웹 효과음(SFX v3, 길이 1.0초, 영향 30%, 변형 4개) 2묶음 = 24크레딧. 받은 opus 를 브라우저로 디코딩해 모노로 합침.</li>
      <li>다듬기(<code>build.mjs</code>): 앞 무음만 자르고(-40dB, 여유 5ms), 피크 -3dB, 끝 120ms 페이드, 최대 1초. 카드의 dB는 평균 음량(RMS).</li>
      <li>아직 게임에 넣지 않았습니다.</li>
    </ul>
  </details>
  <div id="list"></div>
  <section class="voice all"><h2>전체 코멘트</h2><textarea id="all-note" placeholder="더 가볍게/무겁게, 열릴 때 소리도 필요한지 등"></textarea></section>
  <pre id="out" hidden></pre>
</main>
<div class="bar"><div class="bar-in"><span class="count" id="count"></span><button class="ghost" id="clear">선택 지우기</button><button id="copy">결과 복사</button></div></div>
<script>
const DATA = ${JSON.stringify(data)};
const AUDIO = ${JSON.stringify(audio)};
const KEY = "ksc-transition-sfx-v1";
let state = { use: {}, note: {}, all: "" };
try { const s = JSON.parse(localStorage.getItem(KEY) || "null"); if (s) state = Object.assign(state, s); } catch (e) {}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {} };
const urls = {};
const url = (id) => urls[id] || (urls[id] = URL.createObjectURL(new Blob([Uint8Array.from(atob(AUDIO[id]), (c) => c.charCodeAt(0))], { type: "audio/wav" })));
let cur = null;
function play(id, btn) {
  if (cur) { cur.a.pause(); cur.btn.classList.remove("playing"); cur.btn.textContent = "▶"; }
  const a = new Audio(url(id));
  cur = { a, btn }; btn.classList.add("playing"); btn.textContent = "■";
  a.onended = () => { btn.classList.remove("playing"); btn.textContent = "▶"; if (cur && cur.a === a) cur = null; };
  a.play().catch(() => {});
}
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const all = [];
const list = document.getElementById("list");
for (const g of DATA) {
  const sec = document.createElement("section"); sec.className = "voice";
  sec.innerHTML = "<h2>" + esc(g.label) + "</h2><p class=\\"prompt\\">" + esc(g.prompt) + "</p>";
  const grid = document.createElement("div"); grid.className = "clips";
  for (const c of g.clips) {
    all.push({ group: g.label, ...c });
    const el = document.createElement("div"); el.className = "clip";
    el.innerHTML = '<div class="row"><button class="play" aria-label="재생">▶</button><div class="lab"><b>변형 ' + c.n + "</b><span>" + c.sec + "초 · 피크까지 " + c.peak_ms + "ms · " + c.rms_db + "dB</span></div></div>"
      + '<label class="use"><input type="checkbox"> 게임에 쓰기</label><textarea placeholder="코멘트"></textarea>';
    const btn = el.querySelector(".play"), cb = el.querySelector("input"), ta = el.querySelector("textarea");
    btn.onclick = () => play(c.id, btn);
    cb.checked = !!state.use[c.id]; el.classList.toggle("on", cb.checked);
    cb.onchange = () => { state.use[c.id] = cb.checked; el.classList.toggle("on", cb.checked); save(); count(); };
    ta.value = state.note[c.id] || ""; ta.oninput = () => { state.note[c.id] = ta.value; save(); };
    grid.appendChild(el);
  }
  sec.appendChild(grid); list.appendChild(sec);
}
const allNote = document.getElementById("all-note");
allNote.value = state.all || ""; allNote.oninput = () => { state.all = allNote.value; save(); };
function count() { document.getElementById("count").textContent = all.filter((c) => state.use[c.id]).length + "개 선택"; }
count();
document.getElementById("clear").onclick = () => { state.use = {}; save(); document.querySelectorAll(".clip").forEach((el) => { el.classList.remove("on"); el.querySelector("input").checked = false; }); count(); };
function report() {
  const lines = ["화면 전환 소리 고르기 (docs/sfx_transition_v1)", ""];
  const picked = all.filter((c) => state.use[c.id]);
  lines.push("[게임에 쓰기 " + picked.length + "개]"); for (const c of picked) lines.push("- " + c.group + " / 변형 " + c.n + " (" + c.id + ")" + (state.note[c.id] ? " — 코멘트: " + state.note[c.id].trim() : "")); if (!picked.length) lines.push("- 없음");
  const notes = all.filter((c) => !state.use[c.id] && (state.note[c.id] || "").trim());
  if (notes.length) { lines.push("", "[고르지 않은 소리 코멘트]"); for (const c of notes) lines.push("- " + c.group + " / 변형 " + c.n + " (" + c.id + "): " + state.note[c.id].trim()); }
  if ((state.all || "").trim()) lines.push("", "[전체 코멘트]", state.all.trim());
  return lines.join("\\n");
}
document.getElementById("copy").onclick = async () => {
  const t = report(), out = document.getElementById("out");
  out.textContent = t; out.hidden = false;
  try { await navigator.clipboard.writeText(t); document.getElementById("count").textContent = "복사했어요 — 대화창에 붙여 주세요"; }
  catch (e) { const r = document.createRange(); r.selectNodeContents(out); const s = getSelection(); s.removeAllRanges(); s.addRange(r); document.getElementById("count").textContent = "아래 글을 복사해 주세요"; }
  out.scrollIntoView({ behavior: "smooth" });
};
</script>
`;
fs.writeFileSync(path.join(HERE, "transition.html"), html);
console.log(Object.keys(audio).length, "clips", (html.length / 1024).toFixed(0), "KB");
