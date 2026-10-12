#!/usr/bin/env python3
"""Run the local-only M10 maker service on loopback."""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
PLATFORM = ROOT / "platform"
if str(PLATFORM) not in sys.path:
    sys.path.insert(0, str(PLATFORM))

from maker.service import MakerError, MakerService, MAX_ASSET_BYTES, decode_request
from maker.command_input import CommandInputError, parse_command

BROWSER_ROOT = ROOT / "platform" / "maker" / "browser"
BROWSER_FILES = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/main.mjs": ("main.mjs", "text/javascript; charset=utf-8"),
    "/state.mjs": ("state.mjs", "text/javascript; charset=utf-8"),
    "/forms.mjs": ("forms.mjs", "text/javascript; charset=utf-8"),
    "/map.mjs": ("map.mjs", "text/javascript; charset=utf-8"),
    "/styles.css": ("styles.css", "text/css; charset=utf-8"),
}
M9_RENDERER_ROUTE = "/m9-renderer.mjs"


def browser_asset(path: str) -> tuple[str, bytes]:
    """Return one explicitly allowed browser asset; all other paths are denied."""
    if path == M9_RENDERER_ROUTE:
        asset = ROOT / "platform" / "presentation" / "browser" / "renderer.mjs"
        if asset.is_symlink() or not asset.is_file():
            raise MakerError("browser-asset", "M9 renderer is unavailable")
        return "text/javascript; charset=utf-8", asset.read_bytes()
    entry = BROWSER_FILES.get(path)
    if entry is None:
        raise MakerError("route", "browser asset was not found")
    filename, content_type = entry
    asset = BROWSER_ROOT / filename
    if asset.is_symlink() or not asset.is_file() or asset.resolve().parent != BROWSER_ROOT.resolve():
        raise MakerError("browser-asset", "browser asset is unavailable")
    return content_type, asset.read_bytes()


def dispatch(service: MakerService, method: str, path: str, body: object) -> dict:
    parts = [unquote(part) for part in path.split("?")[0].strip("/").split("/")]
    if (len(parts) == 4 and parts[:2] == ["api", "playtests"]
            and parts[3] == "commands" and method == "POST" and isinstance(body, dict)):
        try:
            command = parse_command(body.get("command"))
        except CommandInputError as exc:
            raise MakerError("command", str(exc)) from None
        expected = body.get("expectedCommands")
        if type(expected) is not int or not 0 <= expected <= 4096:
            raise MakerError("command-sequence", "expectedCommands must be in [0, 4096]")
        return service.step_playtest(parts[2], command, expected)
    if parts == ["api", "projects"]:
        if method == "GET":
            return service.list_projects()
        if method == "POST" and isinstance(body, dict):
            return service.create_project(body.get("name"))
    if len(parts) >= 3 and parts[:2] == ["api", "projects"]:
        project_id = parts[2]
        tail = parts[3:]
        if not tail and method == "GET":
            return service.open_project(project_id)
        if tail == ["documents"] and method == "PUT" and isinstance(body, dict):
            return service.save_documents(project_id, body.get("documents"))
        if tail == ["validate"] and method == "POST":
            return service.validate_project(project_id)
        if tail == ["export"] and method == "POST":
            return service.export_project(project_id)
        if tail == ["playtest"] and method == "POST" and isinstance(body, dict):
            return service.playtest_project(project_id, body.get("rngState"),
                                            body.get("waitTicks"), body.get("contentHash"))
        if tail == ["assets"] and method == "POST" and isinstance(body, dict):
            return service.import_asset(project_id, body.get("path"), body.get("mediaType"),
                                        body.get("contentBase64"), body.get("assetId"))
    raise MakerError("route", "route or method was not found")


class MakerHandler(BaseHTTPRequestHandler):
    service: MakerService

    def _respond(self, status: int, value: dict) -> None:
        payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self._respond_bytes(status, payload, "application/json; charset=utf-8")

    def _respond_bytes(self, status: int, payload: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _body(self) -> object:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise MakerError("content-length", "Content-Length must be an integer") from None
        limit = MAX_ASSET_BYTES * 2
        if length < 0 or length > limit:
            raise MakerError("request-too-large", f"request exceeds {limit} bytes")
        raw = self.rfile.read(length)
        return decode_request(raw, limit)

    def _handle(self) -> None:
        try:
            path = urlsplit(self.path).path
            if self.command == "GET" and (path in BROWSER_FILES or path == M9_RENDERER_ROUTE):
                content_type, payload = browser_asset(path)
                self._respond_bytes(200, payload, content_type)
                return
            body = self._body() if self.command in {"POST", "PUT"} else None
            self._respond(200, dispatch(self.service, self.command, path, body))
        except MakerError as exc:
            status = 503 if exc.code == "playtest-unavailable" else (404 if exc.code == "not-found" else (413 if "large" in exc.code else 400))
            self._respond(status, {"ok": False, "error": {"code": exc.code, "message": exc.message}})
        except Exception as exc:
            self._respond(500, {"ok": False, "error": {"code": "internal", "message": str(exc)}})

    do_GET = _handle
    do_POST = _handle
    do_PUT = _handle

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.home() / ".bend-maker" / "projects")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--runtime", type=Path,
                        default=ROOT / "build" / "m10_dynamic_runtime")
    parser.add_argument("--template", type=Path,
                        help="Content-0 project copied for each new maker project")
    args = parser.parse_args()
    if args.host not in {"127.0.0.1", "::1", "localhost"}:
        parser.error("maker service only binds to loopback")
    service = MakerService(args.root, template_root=args.template,
                           runtime_path=args.runtime)
    handler = type("BoundMakerHandler", (MakerHandler,), {"service": service})
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"M10 maker listening at http://{args.host}:{server.server_port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
