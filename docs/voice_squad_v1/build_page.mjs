// 분대 3명(기사·마법사·힐러) 추임새 고르기 페이지 squad-voice.html
// docs/voice_gunner_v1/build_page.mjs(마녀산장 erin-pick 형식)와 같은 방식: 캐릭터 → 목소리 → 스킬·피격 후보,
// 여러 개 체크(게임에서 무작위로 돌려 씀)·소리별/전체 코멘트·결과 복사. 소리는 누를 때 한 번만 재생.
//   node build_page.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CAST = JSON.parse(fs.readFileSync(path.join(HERE, "cast.json"), "utf8"));
const meta = JSON.parse(fs.readFileSync(path.join(HERE, "meta.json"), "utf8"));
const css = fs.readFileSync(path.join(HERE, "..", "voice_gunner_v1", "gunner-voice-v2.html"), "utf8").match(/<style>[\s\S]*?<\/style>/)[0];
const audio = {};
const data = Object.entries(CAST.chars).map(([ck, c]) => ({
  key: ck, name: c.name, look: c.look, persona: c.persona, skill: c.skill,
  voices: Object.entries(c.voices).map(([vk, v]) => ({
    name: v.name, full: v.full, note: v.note,
    sets: [["skill", "스킬 사용 — " + c.skill], ["hurt", "피격"]].map(([g, title]) => ({
      key: g, title,
      clips: c[g].flatMap((l, i) => [1, 2].map((t) => {
        const id = `${ck}_${vk}_${g}-0${i + 1}-t${t}`;
        audio[id] = fs.readFileSync(path.join(HERE, "edited", id + ".wav")).toString("base64");
        const m = meta.clips[id] || {};
        return { id, label: l.label, take: t, sec: m.sec, f0: m.f0, cut: !!m.cut, segs: m.segs, kept: m.kept };
      })),
    })),
  })),
}));
const total = Object.keys(audio).length;

const html = `<title>분대 추임새 고르기</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
${css}
<style>
.char { display:grid; gap:14px; }
.char > h2 { margin:8px 0 0; font-family:"Gowun Batang", serif; font-size:24px; }
.char > h2 small { font:13px "Noto Sans KR", sans-serif; color:var(--muted); margin-left:8px; }
nav.jump { display:flex; gap:8px; flex-wrap:wrap; }
nav.jump a { color:var(--accent); background:var(--accent-soft); border-radius:999px; padding:3px 12px; text-decoration:none; font-size:14px; }
</style>
<main>
  <section class="intro">
    <h1>분대 3명 — 스킬·피격 추임새 고르기</h1>
    <p>건너에 이어 <b>기사 · 마법사 · 힐러</b>의 추임새 후보 ${total}개입니다. 캐릭터마다 성격에 맞춘 ElevenLabs 목소리 2종 × 문구 10개(스킬 5 · 피격 5) × 테이크 2개.</p>
    <ul>
      <li>건너 때 피드백을 처음부터 반영했습니다: <b>한 음절 위주</b>, 원본에서 <b>가장 센 소리 덩어리 하나만</b> 남겨 "두 번 하는" 소리를 없앴고(기사 "흡… 핫!"만 두 덩어리), 모두 <b>0.6초 이하</b>.</li>
      <li>기사: 직설적이고 따뜻함 → 힘 있는 기합 · 마법사: 조용하고 건조함 → 낮고 차분한 짧은 소리 · 힐러: 다정함 → 부드럽고 밝은 소리.</li>
      <li>동그란 버튼을 누르면 <b>한 번만</b> 재생됩니다. 캐릭터별로 게임에 쓸 것을 <b>여러 개 체크</b>하면 그중에서 무작위로 돌려 씁니다. 다 고르면 <b>결과 복사</b>로 붙여 주세요. 승인하신 것만 게임에 넣습니다.</li>
    </ul>
  </section>
  <details class="verify"><summary>만든 방법·확인한 것</summary>
    <ul>
      <li>로그인한 ElevenLabs 웹 화면(Eleven v4, 안정성 50%·유사성 75%)에서 생성, 한 번에 테이크 2개. 입력은 <code>[영어 감정 태그] 한국어 추임새</code> (<code>cast.json</code>).</li>
      <li>다듬기(<code>edit.mjs</code>): 20ms 음량이 최대치 -30dB 넘는 덩어리 중 가장 센 하나, 앞뒤 10ms, 최대 0.6초, 피크 -3dB, 끝 40ms 페이드 → 44.1kHz 16bit 모노 WAV. 카드의 "덩어리 n개 중 1"은 원본에 소리 덩어리가 몇 개였는지입니다(여럿이면 숨소리·반복을 덜어낸 것). "끝 잘림"은 길게 끄는 소리를 0.6초에서 자른 것.</li>
      <li>평균 음높이(카드의 Hz): 기사 Lola 약 510 · Aisyah 약 620 · 마법사 Suzu 약 300 · Ayame 약 270 · 힐러 Koume 약 490 · Kano 약 530Hz. 마법사 두 목소리는 차분한 성격에 맞춰 낮은 편입니다.</li>
      <li><b>확인 못 한 것</b>: 받아쓰기(STT)는 API 키가 무효라 못 돌렸습니다. 이상한 말이 섞였는지는 귀로 확인해 주세요. 게임에는 아직 넣지 않았습니다.</li>
    </ul>
  </details>
  <nav class="jump">${data.map((c) => `<a href="#${c.key}">${c.name}</a>`).join("")}</nav>
  <div id="list"></div>
  <section class="voice all"><h2>전체 코멘트</h2><textarea id="all-note" placeholder="캐릭터별 톤, 다시 만들었으면 하는 소리 등"></textarea></section>
  <pre id="out" hidden></pre>
</main>
<div class="bar"><div class="bar-in"><span class="count" id="count"></span><button class="ghost" id="clear">선택 지우기</button><button id="copy">결과 복사</button></div></div>
<script>
const DATA = ${JSON.stringify(data)};
const AUDIO = ${JSON.stringify(audio)};
const KEY = "ksc-squad-voice-v1";
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
const list = document.getElementById("list");
const all = [];
for (const c of DATA) {
  const wrap = document.createElement("section"); wrap.className = "char"; wrap.id = c.key;
  wrap.innerHTML = "<h2>" + esc(c.name) + "<small>" + esc(c.look) + " · " + esc(c.persona) + "</small></h2>";
  for (const v of c.voices) {
    const sec = document.createElement("section"); sec.className = "voice";
    sec.innerHTML = "<h2>" + esc(v.name) + " <small>" + esc(v.note) + " · " + esc(v.full) + "</small></h2>";
    for (const s of v.sets) {
      const box = document.createElement("div"); box.className = "set";
      box.innerHTML = "<h3>" + esc(s.title) + "</h3>";
      const grid = document.createElement("div"); grid.className = "clips";
      for (const x of s.clips) {
        all.push({ char: c.key, charName: c.name, voice: v.name, group: s.key, ...x });
        const el = document.createElement("div"); el.className = "clip";
        el.innerHTML = '<div class="row"><button class="play" aria-label="재생">▶</button><div class="lab"><b>' + esc(x.label) + " · 테이크 " + x.take + "</b><span>" + x.sec + "초" + (x.f0 ? " · " + x.f0 + "Hz" : "") + (x.segs > 1 ? " · 덩어리 " + x.segs + "개 중 " + x.kept : "") + (x.cut ? " · 끝 잘림" : "") + "</span></div></div>"
          + '<label class="use"><input type="checkbox"> 게임에 쓰기</label><textarea placeholder="코멘트"></textarea>';
        const btn = el.querySelector(".play"), cb = el.querySelector("input"), ta = el.querySelector("textarea");
        btn.onclick = () => play(x.id, btn);
        cb.checked = !!state.use[x.id]; el.classList.toggle("on", cb.checked);
        cb.onchange = () => { state.use[x.id] = cb.checked; el.classList.toggle("on", cb.checked); save(); count(); };
        ta.value = state.note[x.id] || ""; ta.oninput = () => { state.note[x.id] = ta.value; save(); };
        grid.appendChild(el);
      }
      box.appendChild(grid); sec.appendChild(box);
    }
    wrap.appendChild(sec);
  }
  list.appendChild(wrap);
}
const allNote = document.getElementById("all-note");
allNote.value = state.all || ""; allNote.oninput = () => { state.all = allNote.value; save(); };
function count() {
  const p = all.filter((x) => state.use[x.id]);
  document.getElementById("count").textContent = DATA.map((c) => c.name + " " + p.filter((x) => x.char === c.key && x.group === "skill").length + "/" + p.filter((x) => x.char === c.key && x.group === "hurt").length).join(" · ") + " (스킬/피격)";
}
count();
document.getElementById("clear").onclick = () => { state.use = {}; save(); document.querySelectorAll(".clip").forEach((el) => { el.classList.remove("on"); el.querySelector("input").checked = false; }); count(); };
function report() {
  const lines = ["분대 추임새 고르기 (docs/voice_squad_v1)"];
  for (const c of DATA) for (const [g, name] of [["skill", "스킬"], ["hurt", "피격"]]) {
    const picked = all.filter((x) => x.char === c.key && x.group === g && state.use[x.id]);
    lines.push("", "[" + c.name + " " + name + " " + picked.length + "개]");
    for (const x of picked) lines.push("- " + x.voice + " / " + x.label + " / 테이크 " + x.take + " (" + x.id + ")" + (state.note[x.id] ? " — 코멘트: " + state.note[x.id].trim() : ""));
    if (!picked.length) lines.push("- 없음");
  }
  const notes = all.filter((x) => !state.use[x.id] && (state.note[x.id] || "").trim());
  if (notes.length) { lines.push("", "[고르지 않은 소리 코멘트]"); for (const x of notes) lines.push("- " + x.charName + " / " + x.voice + " / " + x.label + " / 테이크 " + x.take + " (" + x.id + "): " + state.note[x.id].trim()); }
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
fs.writeFileSync(path.join(HERE, "squad-voice.html"), html);
console.log(total, "clips", (html.length / 1024).toFixed(0), "KB");
