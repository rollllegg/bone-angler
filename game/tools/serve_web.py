"""Serve the exported game on loopback with WebAssembly MIME and isolation headers."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8060)
    args = parser.parse_args()
    export_dir = Path(__file__).resolve().parents[1] / "build" / "web"
    if not (export_dir / "index.html").is_file():
        parser.error("Export Web first: tools/Build.ps1 -Target Web")
    handler = partial(GameHandler, directory=str(export_dir))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        print(f"Game preview: http://127.0.0.1:{args.port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
