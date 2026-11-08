// 갈림길 석판 솟아오르는 소리 후보: decoded/*.wav(브라우저 디코딩 44.1kHz 모노) → edited/*.wav + 고르기 페이지 slab-rise.html
// 다듬기: 앞 무음(최대치 -40dB 아래) 자름(여유 10ms), 피크 -3dB, 앞 5ms·끝 150ms 페이드, 최대 2.0초.
// 페이지 형식은 docs/voice_squad_v1/build_page.mjs 와 같다(한 번만 재생·여러 개 체크·코멘트·결과 복사).
//   node build.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, "decoded"), DST = path.join(HERE, "edited");
fs.mkdirSync(DST, { recursive: true });
const PROMPTS = {
  "slab-a": ["무거운 고대 석판이 차례로", "Heavy ancient stone slabs rising up from the ground one after another, deep grinding rumble with rattling stone clunks, magical temple floor assembling"],
  "slab-b": ["마법 석판이 맞물림 + 반짝임", "Magical stone tiles emerging from below and locking into place, cascading series of soft stone thuds and grinding with a faint mystical shimmer"],
  "slab-c": ["작은 블록이 착착 깔림", "Quick cascade of many small stone blocks rising and clicking into place like a path being built, dry stone clacks over a short low rumble"],
  "slab-d": ["깊은 울림 + 마지막 쿵", "Deep earth rumble as a stone bridge assembles itself, heavy slabs sliding up and settling with a final solid thump"],
  "slab-e": ["공허 에너지 + 떠오르는 발판", "Ethereal void energy hum while floating stone platforms rise and knock together, airy whoosh and stone knocks"],
};
const MAX = 2.0, PAD = 0.01, FADE = 0.15, PEAK = Math.pow(10, -3 / 20);

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
  meta[id] = { lead_cut: +(a / rate).toFixed(2), sec: +(out.length / rate).toFixed(2), rms_db: +(10 * Math.log10(e2 / out.length)).toFixed(1) };
  audio[id] = fs.readFileSync(path.join(DST, f)).toString("base64");
  console.log(id, meta[id]);
}
fs.writeFileSync(path.join(HERE, "meta.json"), JSON.stringify(meta, null, 2));

const data = Object.entries(PROMPTS).map(([p, [label, prompt]]) => ({
  key: p, label, prompt,
  clips: [1, 2, 3, 4].map((n) => ({ id: `${p}-${n}`, n, ...meta[`${p}-${n}`] })),
}));
const css = fs.readFileSync(path.join(HERE, "..", "voice_gunner_v1", "gunner-voice-v2.html"), "utf8").match(/<style>[\s\S]*?<\/style>/)[0];
const html = `<title>석판 솟아오름 소리</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
${css}
<style>.prompt { font-size:12.5px; color:var(--muted); margin:-6px 0 0; overflow-wrap:anywhere; }</style>
<main>
  <section class="intro">
    <h1>갈림길 — 석판이 솟아오르는 소리 고르기</h1>
    <p>방을 클리어하고 <b>다음 스테이지 방향을 정할 때</b>, 새 복도·방 석판이 바닥 아래에서 시간차로 솟아오르는 연출(<code>VDBoard.raise_tiles</code>, 블록마다 0.5초, 전체 약 1.5~2초)에 붙일 소리 후보 ${Object.keys(audio).length}개입니다. ElevenLabs 효과음(SFX v3, 2초) 설명 5가지 × 변형 4개.</p>
    <ul>
      <li>석판이 올라오기 시작할 때 한 번 재생하는 것을 생각하고 만들었습니다(블록마다 내면 수십 개가 겹칩니다).</li>
      <li>동그란 버튼을 누르면 <b>한 번만</b> 재생됩니다. 쓸 것을 체크하세요(여러 개면 갈림길마다 무작위). 다 고르면 <b>결과 복사</b>로 붙여 주시면 게임에 넣겠습니다.</li>
    </ul>
  </section>
  <details class="verify"><summary>만든 방법</summary>
    <ul>
      <li>로그인한 ElevenLabs 웹 효과음 화면(SFX v3, 길이 2.0초, 프롬프트 영향 30%, 한 번에 변형 4개)에서 생성. 받은 opus 를 브라우저로 디코딩해 모노로 합침.</li>
      <li>다듬기(<code>build.mjs</code>): 앞 무음만 자르고(-40dB), 피크 -3dB, 끝 150ms 페이드, 최대 2초. 카드의 dB는 평균 음량(RMS)으로, 게임 볼륨 맞출 때 참고합니다.</li>
      <li>아직 게임에 넣지 않았습니다.</li>
    </ul>
  </details>
  <div id="list"></div>
  <section class="voice all"><h2>전체 코멘트</h2><textarea id="all-note" placeholder="더 무겁게/가볍게, 길이, 마지막 쿵 소리 여부 등"></textarea></section>
  <pre id="out" hidden></pre>
</main>
<div class="bar"><div class="bar-in"><span class="count" id="count"></span><button class="ghost" id="clear">선택 지우기</button><button id="copy">결과 복사</button></div></div>
<script>
const DATA = ${JSON.stringify(data)};
const AUDIO = ${JSON.stringify(audio)};
const KEY = "ksc-slab-rise-v1";
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
    el.innerHTML = '<div class="row"><button class="play" aria-label="재생">▶</button><div class="lab"><b>변형 ' + c.n + "</b><span>" + c.sec + "초 · " + c.rms_db + "dB</span></div></div>"
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
  const lines = ["석판 솟아오름 소리 고르기 (docs/sfx_slab_rise_v1)", ""];
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
fs.writeFileSync(path.join(HERE, "slab-rise.html"), html);
console.log(Object.keys(audio).length, "clips", (html.length / 1024).toFixed(0), "KB");
