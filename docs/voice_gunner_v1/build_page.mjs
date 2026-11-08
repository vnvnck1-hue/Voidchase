// 건너 추임새 고르기 페이지 gunner-voice.html
// 마녀산장 output/audio-guest-voices-v02/build_erin_pick.mjs 형식: 목소리별로 스킬·피격 후보를 모아
// 여러 개 체크(게임에서 무작위로 돌려 씀)·소리별/전체 코멘트·결과 복사. 소리는 누를 때 한 번만 재생.
//   node build_page.mjs        1차 cast.json    → gunner-voice.html
//   node build_page.mjs v2     2차 cast_v2.json → gunner-voice-v2.html (지금 게임에 들어간 소리 묶음 포함)
// 소리는 edited/ 의 현재 다듬기 결과를 넣는다(edit.mjs 규칙이 바뀌면 다시 만들 때 길이가 달라진다).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const V2 = process.argv[2] === "v2";
const CAST = JSON.parse(fs.readFileSync(path.join(HERE, V2 ? "cast_v2.json" : "cast.json"), "utf8"));
const meta = JSON.parse(fs.readFileSync(path.join(HERE, "meta.json"), "utf8"));
const audio = {};
const clipOf = (id, label, take, group) => {
  audio[id] = fs.readFileSync(path.join(HERE, "edited", id + ".wav")).toString("base64");
  const c = meta.clips[id] || {};
  return { id, label, take, group, sec: c.sec ?? null, f0: c.f0 ?? null, cut: !!c.cut };
};
const data = [];
if (CAST.ingame) data.push({
  name: "지금 게임에 들어감", full: "1차에서 고른 스킬 3개", note: "0.8초 이하로 다시 다듬음 · 체크를 빼면 게임에서 뺌",
  sets: [{ key: "skill", title: "스킬 사용 (다중 사격)", clips: CAST.ingame.map((g) => ({ ...clipOf(g.id, g.label, 0, g.group), inGame: true })) }],
});
data.push(...Object.entries(CAST.voices).map(([vk, v]) => ({
  name: v.name, full: v.full, note: v.note,
  sets: Object.entries(CAST.groups).map(([gk, g]) => ({
    key: gk, title: g.name,
    clips: g.lines.flatMap((l, i) => [1, 2].map((t) => clipOf(`${vk}_${gk}-0${i + 1}-t${t}`, l.label, t, gk))),
  })),
})));
const total = Object.keys(audio).length;
const fresh = total - (CAST.ingame?.length || 0);
const INTRO = V2 ? `
    <h1>건너 — 추임새 2차 (짧고 임팩트 있게)</h1>
    <p>1차 피드백 <b>"대부분 너무 길다, 더 임팩트 있게 짧게, 미소녀 서브컬처 게임에 어울리게"</b>에 맞춰 고르신 <b>Irohauta</b> 목소리로 한 음절 위주의 기합·비명 ${fresh}개(문구 12개 × 테이크 2개)를 새로 만들었습니다. 모두 <b>0.8초 이하</b>로 다듬었습니다.</p>
    <ul>
      <li><b>스킬 사용</b>: "핫!" · "얍!" · "타앗!" · "세잇!" · "하잇!" · "흣!"</li>
      <li><b>피격</b>: "꺅!" · "읏!" · "아읏!" · "히앗!" · "큿!" · "꺄웃!"</li>
      <li>맨 위 <b>지금 게임에 들어감</b>은 1차에서 고르신 스킬 3개입니다. 이미 게임의 건너 스킬 시전에 연결했고, 같은 0.8초 규칙으로 다시 다듬어 0.42~0.64초가 됐습니다. 체크를 빼면 게임에서도 뺍니다.</li>
    </ul>
    <p>동그란 버튼을 누르면 <b>한 번만</b> 재생됩니다. 게임에 쓸 것을 <b>여러 개 체크</b>하면 그중에서 무작위로 돌려 씁니다. 다 고르면 <b>결과 복사</b>로 붙여 주세요.</p>` : `
    <h1>건너 — 스킬·피격 추임새 고르기</h1>
    <p>VOID DEFENSE 분대의 <b>핑크 건너</b>(SMG 메이드, 눈치 빠른 관찰자)에게 붙일 말 없는 짧은 추임새 후보 ${total}개입니다. ElevenLabs 애니풍 여성 목소리 3종(Irohauta·Kano·Pipi) × 문구 8개 × 테이크 2개.</p>
    <ul>
      <li><b>스킬 사용</b>(다중 사격): "하앗!" · "흡… 하앗!" · "에잇!" · "후훗~ 하앗!"</li>
      <li><b>피격</b>: "꺄앗!" · "윽…!" · "아얏!" · "큭… 으읏!"</li>
    </ul>
    <p>동그란 버튼을 누르면 <b>한 번만</b> 재생됩니다. 게임에 쓸 것을 <b>여러 개 체크</b>하면 스킬·피격 때 그중에서 무작위로 돌려 씁니다(목소리를 섞어 골라도 됩니다). 소리마다, 그리고 맨 아래에 전체 코멘트를 남길 수 있습니다. 다 고르면 <b>결과 복사</b>로 대화창에 붙여 주세요.</p>`;
const TRIM = V2
  ? "소리 난 구간만 남김: 20ms 음량이 최대치 -30dB 넘는 구간, 앞뒤 여유 10ms, 구간 사이 쉼 0.06초, <b>최대 0.8초</b>, 피크 -3dB, 끝 40ms 페이드 → 44.1kHz 16bit 모노 WAV. \"끝 잘림\"은 0.8초에서 자른 것."
  : "받은 MP3(44.1kHz)를 소리 난 구간만 남기게 다듬음: 20ms 음량이 최대치 -35dB 넘는 구간, 구간 사이 쉼 0.1초, 최대 1.6초(\"후훗~ 하앗!\"만 2.2초), 피크 -3dB, 끝 60ms 페이드 → 44.1kHz 16bit 모노 WAV.";

const html = `<title>${V2 ? "건너 추임새 2차" : "건너 추임새 고르기"}</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root { --bg:#f6eef1; --panel:#fffafc; --ink:#2a1f24; --muted:#7c6870; --line:#e6d3da; --accent:#b8436e; --accent-soft:#f6dbe5; --pick:#2f6b4f; --pick-soft:#dcefe4; color-scheme:light; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#1c1619; --panel:#261e22; --ink:#f0e2e8; --muted:#a8919a; --line:#3d3036; --accent:#ee8db0; --accent-soft:#40252f; --pick:#7cc7a0; --pick-soft:#1f3328; color-scheme:dark; } }
:root[data-theme="dark"] { --bg:#1c1619; --panel:#261e22; --ink:#f0e2e8; --muted:#a8919a; --line:#3d3036; --accent:#ee8db0; --accent-soft:#40252f; --pick:#7cc7a0; --pick-soft:#1f3328; color-scheme:dark; }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.6 "Noto Sans KR", system-ui, sans-serif; padding:24px 16px 110px; }
main { max-width:980px; margin:0 auto; display:grid; gap:20px; }
h1 { font-family:"Gowun Batang", serif; font-size:26px; margin:0; text-wrap:balance; }
.intro p { margin:6px 0 0; color:var(--muted); max-width:70ch; }
.intro ul { margin:8px 0 0; padding-left:20px; color:var(--muted); max-width:70ch; }
details.verify { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:10px 14px; color:var(--muted); font-size:13.5px; }
details.verify summary { cursor:pointer; color:var(--ink); }
code { font:12.5px ui-monospace, Consolas, monospace; background:var(--accent-soft); border-radius:4px; padding:0 4px; overflow-wrap:anywhere; }
.voice { background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:16px; display:grid; gap:14px; }
.voice h2 { margin:0; font-family:"Gowun Batang", serif; font-size:20px; display:flex; gap:10px; align-items:baseline; flex-wrap:wrap; }
.voice h2 small { font:13px "Noto Sans KR", sans-serif; color:var(--muted); }
.set h3 { margin:0 0 8px; font-size:13px; letter-spacing:.04em; color:var(--accent); font-weight:700; }
.clips { display:grid; grid-template-columns:repeat(auto-fill, minmax(210px, 1fr)); gap:10px; }
.clip { border:1px solid var(--line); border-radius:10px; padding:10px; display:grid; gap:6px; min-width:0; background:var(--bg); }
.clip.on { border-color:var(--pick); background:var(--pick-soft); }
.row { display:flex; gap:8px; align-items:center; }
.play { flex:none; width:34px; height:34px; border-radius:50%; border:0; background:var(--accent); color:var(--panel); cursor:pointer; font-size:13px; }
.play.playing { background:var(--pick); }
.lab { min-width:0; }
.lab b { display:block; font-size:14px; font-weight:500; overflow-wrap:anywhere; }
.lab span { font-size:12px; color:var(--muted); overflow-wrap:anywhere; font-variant-numeric:tabular-nums; }
label.use { display:flex; gap:6px; align-items:center; font-size:13px; cursor:pointer; }
label.use input { accent-color:var(--pick); width:16px; height:16px; }
textarea { width:100%; min-height:34px; resize:vertical; font:13px "Noto Sans KR", sans-serif; color:var(--ink); background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:5px 7px; }
.all textarea { min-height:70px; }
.bar { position:fixed; left:0; right:0; bottom:0; background:var(--panel); border-top:1px solid var(--line); padding:10px 16px calc(10px + env(safe-area-inset-bottom, 0px)); }
.bar-in { max-width:980px; margin:0 auto; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
.bar .count { margin-right:auto; color:var(--muted); font-variant-numeric:tabular-nums; }
.bar button { font:inherit; border:0; border-radius:8px; padding:8px 16px; cursor:pointer; background:var(--accent); color:var(--panel); }
.bar button.ghost { background:transparent; color:var(--muted); border:1px solid var(--line); }
pre#out { white-space:pre-wrap; background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:12px; font-size:12.5px; }
</style>
<main>
  <section class="intro">${INTRO}
  </section>
  <details class="verify"><summary>만든 방법·확인한 것</summary>
    <ul>
      <li>저장된 ElevenLabs API 키가 무효(401)라 로그인한 웹 화면(텍스트 음성 변환, <b>Eleven v4</b>, 안정성 50%·유사성 75%)에서 생성. 한 번 생성에 테이크 2개가 나와 둘 다 받음. 입력 문구는 <code>[감정 태그] 추임새</code> 형태.</li>
      <li>${TRIM} 이 페이지에서 듣는 것이 다듬은 WAV입니다.</li>
      <li>평균 음높이(자기상관)는 모두 소녀 음역(1차 315~850Hz, 2차 474~711Hz). 카드의 Hz는 그 값입니다.</li>
      <li><b>확인 못 한 것</b>: 받아쓰기(STT)는 API 키가 없어 못 돌렸습니다. 태그를 소리 내 읽었거나 다른 말을 했는지는 귀로 확인해 주세요.${V2 ? "" : " 게임에는 아직 넣지 않았습니다."}</li>
      <li>파일: <code>docs/voice_gunner_v1/</code> — 원본 <code>raw_web/*.mp3</code>, 다듬은 <code>edited/*.wav</code>, 문구 <code>${V2 ? "cast_v2.json" : "cast.json"}</code>, 길이·음높이 <code>meta.json</code>.</li>
    </ul>
  </details>
  <div id="list"></div>
  <section class="voice all"><h2>전체 코멘트</h2><textarea id="all-note" placeholder="목소리 톤, 더 만들었으면 하는 추임새, 다른 캐릭터 진행 여부 등"></textarea></section>
  <pre id="out" hidden></pre>
</main>
<div class="bar"><div class="bar-in"><span class="count" id="count">0개 선택</span><button class="ghost" id="clear">선택 지우기</button><button id="copy">결과 복사</button></div></div>
<script>
const DATA = ${JSON.stringify(data)};
const AUDIO = ${JSON.stringify(audio)};
const KEY = "${V2 ? "ksc-gunner-voice-v2" : "ksc-gunner-voice-v1"}";
let state = { use: {}, note: {}, all: "" };
try { const s = JSON.parse(localStorage.getItem(KEY) || "null"); if (s) state = Object.assign(state, s); } catch (e) {}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {} };
const urls = {};
const url = (id) => urls[id] || (urls[id] = URL.createObjectURL(new Blob([Uint8Array.from(atob(AUDIO[id]), (c) => c.charCodeAt(0))], { type: "audio/wav" })));
let cur = null;
function play(id, btn) {
  if (cur) { cur.a.pause(); cur.btn.classList.remove("playing"); cur.btn.textContent = "▶"; }
  const a = new Audio(url(id)); a.loop = false;
  cur = { a, btn }; btn.classList.add("playing"); btn.textContent = "■";
  a.onended = () => { btn.classList.remove("playing"); btn.textContent = "▶"; if (cur && cur.a === a) cur = null; };
  a.play().catch(() => {});
}
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const list = document.getElementById("list");
const all = [];
for (const v of DATA) {
  const sec = document.createElement("section"); sec.className = "voice";
  sec.innerHTML = "<h2>" + esc(v.name) + " <small>" + esc(v.note) + " · " + esc(v.full) + "</small></h2>";
  for (const s of v.sets) {
    const box = document.createElement("div"); box.className = "set";
    box.innerHTML = "<h3>" + esc(s.title) + "</h3>";
    const grid = document.createElement("div"); grid.className = "clips";
    for (const c of s.clips) {
      all.push({ voice: v.name, set: s.title, group: s.key, ...c });
      const el = document.createElement("div"); el.className = "clip";
      el.innerHTML = '<div class="row"><button class="play" aria-label="재생">▶</button><div class="lab"><b>' + esc(c.label) + (c.take ? " · 테이크 " + c.take : "") + "</b><span>" + (c.sec ? c.sec + "초" : "") + (c.f0 ? " · " + c.f0 + "Hz" : "") + (c.cut ? " · 끝 잘림" : "") + '</span></div></div>'
        + '<label class="use"><input type="checkbox"> 게임에 쓰기</label><textarea placeholder="코멘트"></textarea>';
      const btn = el.querySelector(".play"), cb = el.querySelector("input"), ta = el.querySelector("textarea");
      btn.onclick = () => play(c.id, btn);
      if (c.inGame && state.use[c.id] === undefined) state.use[c.id] = true;
      cb.checked = !!state.use[c.id]; el.classList.toggle("on", cb.checked);
      cb.onchange = () => { state.use[c.id] = cb.checked; el.classList.toggle("on", cb.checked); save(); count(); };
      ta.value = state.note[c.id] || ""; ta.oninput = () => { state.note[c.id] = ta.value; save(); };
      grid.appendChild(el);
    }
    box.appendChild(grid); sec.appendChild(box);
  }
  list.appendChild(sec);
}
const allNote = document.getElementById("all-note");
allNote.value = state.all || ""; allNote.oninput = () => { state.all = allNote.value; save(); };
function count() {
  const p = all.filter((c) => state.use[c.id]);
  document.getElementById("count").textContent = "스킬 " + p.filter((c) => c.group === "skill").length + "개 · 피격 " + p.filter((c) => c.group === "hurt").length + "개 선택 (무작위로 돌려 씀)";
}
count();
document.getElementById("clear").onclick = () => { state.use = {}; save(); document.querySelectorAll(".clip").forEach((el) => { el.classList.remove("on"); el.querySelector("input").checked = false; }); count(); };
function report() {
  const lines = ["${V2 ? "건너 추임새 2차" : "건너 추임새 고르기"} (docs/voice_gunner_v1)"];
  for (const [g, name] of [["skill", "스킬 사용"], ["hurt", "피격"]]) {
    const picked = all.filter((c) => c.group === g && state.use[c.id]);
    lines.push("", "[" + name + " " + picked.length + "개 — 무작위로 돌려 씀]");
    for (const c of picked) lines.push("- " + c.voice + " / " + c.label + (c.take ? " / 테이크 " + c.take : "") + " (" + c.id + ")" + (state.note[c.id] ? " — 코멘트: " + state.note[c.id].trim() : ""));
    if (!picked.length) lines.push("- 없음");
  }
  const notes = all.filter((c) => !state.use[c.id] && (state.note[c.id] || "").trim());
  if (notes.length) { lines.push("", "[고르지 않은 소리 코멘트]"); for (const c of notes) lines.push("- " + c.voice + " / " + c.label + (c.take ? " / 테이크 " + c.take : "") + " (" + c.id + "): " + state.note[c.id].trim()); }
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
fs.writeFileSync(path.join(HERE, V2 ? "gunner-voice-v2.html" : "gunner-voice.html"), html);
console.log(total, "clips", (html.length / 1024).toFixed(0), "KB");
