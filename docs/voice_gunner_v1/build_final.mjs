// 건너 추임새 적용본 확인 페이지 gunner-voice-final.html
// 게임에 실제로 들어간 assets/audio/void_defense/voice/gunner_*.wav 를 그대로 넣는다(+ 쓰지 않은 음절 편집 참고 1개).
// 스타일은 gunner-voice-v2.html(build_page.mjs v2) 의 것을 그대로 가져온다. 체크를 빼면 "게임에서 빼기"로 결과 복사.
//   node build_final.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GAME = path.join(HERE, "..", "..", "assets", "audio", "void_defense", "voice");
const css = fs.readFileSync(path.join(HERE, "gunner-voice-v2.html"), "utf8").match(/<style>[\s\S]*?<\/style>/)[0];
const secOf = (buf) => +((buf.readUInt32LE(40) / 2) / buf.readUInt32LE(24)).toFixed(2);
const GROUPS = [
  { key: "skill", title: "스킬 사용 (다중 사격) — 8개 중 무작위", clips: [
    ["gunner_skill_01", "\"하앗!\"", "1차 iro_skill-01-t1"],
    ["gunner_skill_02", "\"하앗!\"", "1차 iro_skill-01-t2"],
    ["gunner_skill_03", "\"에잇!\"", "1차 iro_skill-03-t2"],
    ["gunner_skill_04", "\"얍!\"", "2차 v2iro_skill-02-t2"],
    ["gunner_skill_05", "\"세잇!\"", "2차 v2iro_skill-04-t1"],
    ["gunner_skill_06", "\"하잇!\" (한 번만)", "2차 v2iro_skill-05-t1 첫 음절"],
    ["gunner_skill_07", "\"흣!\" (나눔 1)", "2차 v2iro_skill-06-t1 첫째 음절"],
    ["gunner_skill_08", "\"휴\" (나눔 2)", "2차 v2iro_skill-06-t1 둘째 음절"],
  ] },
  { key: "hurt", title: "피격 — 7개 중 무작위, 같은 캐릭터는 1.2초에 한 번", clips: [
    ["gunner_hurt_01", "\"꺅!\"", "2차 v2iro_hurt-01-t1"],
    ["gunner_hurt_02", "\"꺅!\"", "2차 v2iro_hurt-01-t2"],
    ["gunner_hurt_03", "\"읏!\"", "2차 v2iro_hurt-02-t1"],
    ["gunner_hurt_04", "\"히앗!\" (한 번만)", "2차 v2iro_hurt-04-t2 첫 음절"],
    ["gunner_hurt_05", "\"큿!\" (하나로)", "2차 v2iro_hurt-05-t1 첫 음절"],
    ["gunner_hurt_06", "\"큿!\" (나눔 1)", "2차 v2iro_hurt-05-t2 첫째 음절"],
    ["gunner_hurt_07", "\"큿!\" (나눔 2)", "2차 v2iro_hurt-05-t2 둘째 음절"],
  ] },
];
const audio = {};
const data = GROUPS.map((g) => ({ ...g, clips: g.clips.map(([id, label, src]) => {
  const buf = fs.readFileSync(path.join(GAME, id + ".wav"));
  audio[id] = buf.toString("base64");
  return { id, label, src, sec: secOf(buf), inGame: true };
}) }));
const extra = fs.readFileSync(path.join(HERE, "edited", "v2iro_skill-06-t1-s3.wav"));
audio["v2iro_skill-06-t1-s3"] = extra.toString("base64");
data.push({ key: "extra", title: "참고 — 게임에 안 넣음", clips: [{ id: "v2iro_skill-06-t1-s3", label: "\"흣!\" 테이크 1의 셋째 소리", src: "0.8초 다듬기에서 들리던 짧은 끝소리. 쓰려면 체크", sec: secOf(extra), inGame: false }] });

const html = `<title>건너 추임새 적용본</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
${css}
<main>
  <section class="intro">
    <h1>건너 — 게임에 넣은 추임새 (적용본)</h1>
    <p>2차에서 고르신 결과대로 <b>스킬 8개 · 피격 7개</b>를 게임에 넣었습니다. 여기서 듣는 소리는 게임 폴더 <code>assets/audio/void_defense/voice/</code>의 파일 그대로입니다.</p>
    <ul>
      <li><b>음절 편집</b>: "하잇!"·"히앗!"은 첫 음절만, "큿!" 테이크 1은 하나로, "흣·휴"와 "큿!" 테이크 2는 음절마다 따로 나눴습니다(0.16~0.36초).</li>
      <li><b>스킬</b>: 건너가 다중 사격을 쓸 때 8개 중 하나. <b>피격</b>: 건너가 피해를 받을 때 7개 중 하나. 맞을 때마다 나오면 시끄러워서 같은 캐릭터는 <b>1.2초에 한 번</b>만 냅니다.</li>
      <li>뺄 소리는 체크를 풀고, 고칠 점은 코멘트로 남긴 뒤 <b>결과 복사</b>로 붙여 주세요.</li>
    </ul>
  </section>
  <details class="verify"><summary>확인한 것</summary>
    <ul>
      <li>Godot 헤드리스 임포트 후 VDAudio 가 스킬 8·피격 7개를 읽음. 피격 두 번 연속 → 추임새 1번(쿨다운), 목소리 없는 영웅(마법사 등)은 조용히 건너뜀.</li>
      <li>실제 전투 씬에서 건너에게 피해 → <code>voice_gunner_hurt</code> 1회. VDRunner 전투 4사이클: 건너 스킬 시전 수 = <code>voice_gunner_skill</code> 재생 수, 스크립트 오류 없음.</li>
      <li>음절 자르기: 원본에서 20ms 음량이 최대치 -30dB 넘는 덩어리를 하나씩, 앞뒤 10ms, 피크 -3dB, 끝 40ms 페이드 (<code>cut.mjs</code>).</li>
    </ul>
  </details>
  <div id="list"></div>
  <section class="voice all"><h2>전체 코멘트</h2><textarea id="all-note" placeholder="음량, 피격 빈도(1.2초), 다른 캐릭터 진행 등"></textarea></section>
  <pre id="out" hidden></pre>
</main>
<div class="bar"><div class="bar-in"><span class="count" id="count"></span><button id="copy">결과 복사</button></div></div>
<script>
const DATA = ${JSON.stringify(data)};
const AUDIO = ${JSON.stringify(audio)};
const KEY = "ksc-gunner-voice-final";
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
  sec.innerHTML = "<h2>" + esc(g.title) + "</h2>";
  const grid = document.createElement("div"); grid.className = "clips";
  for (const c of g.clips) {
    all.push({ group: g.key, ...c });
    if (state.use[c.id] === undefined) state.use[c.id] = c.inGame;
    const el = document.createElement("div"); el.className = "clip";
    el.innerHTML = '<div class="row"><button class="play" aria-label="재생">▶</button><div class="lab"><b>' + esc(c.label) + "</b><span>" + c.sec + "초 · " + esc(c.src) + "</span></div></div>"
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
function count() {
  const p = all.filter((c) => state.use[c.id]);
  document.getElementById("count").textContent = "스킬 " + p.filter((c) => c.group !== "hurt").length + "개 · 피격 " + p.filter((c) => c.group === "hurt").length + "개 사용";
}
count();
function report() {
  const lines = ["건너 추임새 적용본 확인 (docs/voice_gunner_v1)"];
  const out = all.filter((c) => c.inGame && !state.use[c.id]), add = all.filter((c) => !c.inGame && state.use[c.id]);
  lines.push("", "[게임에서 빼기 " + out.length + "개]"); for (const c of out) lines.push("- " + c.id + " " + c.label); if (!out.length) lines.push("- 없음");
  if (add.length) { lines.push("", "[추가]"); for (const c of add) lines.push("- " + c.id + " " + c.label); }
  const notes = all.filter((c) => (state.note[c.id] || "").trim());
  if (notes.length) { lines.push("", "[소리 코멘트]"); for (const c of notes) lines.push("- " + c.id + " " + c.label + ": " + state.note[c.id].trim()); }
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
fs.writeFileSync(path.join(HERE, "gunner-voice-final.html"), html);
console.log(Object.keys(audio).length, "clips", (html.length / 1024).toFixed(0), "KB");
