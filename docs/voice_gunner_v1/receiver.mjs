// 브라우저(ElevenLabs 웹, 로그인 세션)에서 만든 오디오를 받아 raw_web/ 에 저장하는 로컬 수신기.
// API 키가 무효가 돼 웹 화면으로 생성할 때만 쓴다. 127.0.0.1 에서만 듣는다.
//   node receiver.mjs      → POST http://127.0.0.1:8799/save?name=<파일명>  (본문: 오디오 바이트)
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), "raw_web");
fs.mkdirSync(OUT, { recursive: true });
const CORS = {
  "Access-Control-Allow-Origin": "https://elevenlabs.io",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Private-Network": "true",
};
http.createServer((req, res) => {
  if (req.method === "OPTIONS") { res.writeHead(204, CORS); return res.end(); }
  const u = new URL(req.url, "http://127.0.0.1");
  const name = (u.searchParams.get("name") || "").replace(/[^\w.\-]/g, "_");
  // GET /list · /file?name= : 받은 mp3 를 브라우저에서 디코딩(WebAudio)해 WAV 로 되돌려 받을 때 쓴다(ffmpeg 없음)
  if (req.method === "GET" && u.pathname === "/list") { res.writeHead(200, { ...CORS, "content-type": "application/json" }); return res.end(JSON.stringify(fs.readdirSync(OUT).filter((f) => f.endsWith(".mp3")))); }
  if (req.method === "GET" && u.pathname === "/file" && fs.existsSync(path.join(OUT, name))) { res.writeHead(200, { ...CORS, "content-type": "audio/mpeg" }); return res.end(fs.readFileSync(path.join(OUT, name))); }
  if (req.method !== "POST" || u.pathname !== "/save" || !name) { res.writeHead(400, CORS); return res.end("bad"); }
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    const buf = Buffer.concat(chunks);
    const dir = u.searchParams.get("dir") === "decoded" ? path.join(OUT, "..", "decoded") : OUT;
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, name), buf);
    console.log("saved", name, buf.length);
    res.writeHead(200, CORS); res.end("ok " + buf.length);
  });
}).listen(8799, "127.0.0.1", () => console.log("listening 127.0.0.1:8799"));
