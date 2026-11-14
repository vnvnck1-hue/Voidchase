"""폰트 시식 페이지 서버.

docs/fonts 를 정적으로 서빙하고, 페이지가 POST /save 로 보내는 코멘트·후보 표시를
같은 폴더의 comments.json 에 저장한다. 실행: python docs/fonts/serve.py [포트]
"""
import json
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "comments.json")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=HERE, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        if self.path != "/save":
            self.send_error(404)
            return
        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n)
        try:
            data = json.loads(raw.decode("utf-8"))
            assert isinstance(data, dict)
        except Exception:
            self.send_error(400, "bad json")
            return
        tmp = DATA + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, DATA)
        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        if "/save" in (args[0] if args else ""):
            sys.stderr.write("saved comments.json\n")


if __name__ == "__main__":
    print(f"font specimen: http://localhost:{PORT}/  (comments -> {DATA})")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
