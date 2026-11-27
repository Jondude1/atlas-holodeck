#!/usr/bin/env python3
"""Holodeck Jellyfin transcode & library bridge.

Godot 4 on Quest plays only Theora/Vorbis (.ogv) via VideoStreamPlayer. This
stdlib-only HTTP server proxies Jellyfin library browsing + posters and
transcodes requested items on demand to .ogv via ffmpeg.

Secrets: reads app/jellyfin_secret.cfg (base_url=, api_key=). Never logs,
prints, or returns api_key anywhere.
"""

from __future__ import annotations

import argparse
import atexit
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ITEM_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
DEFAULT_SECRET_PATH = Path(__file__).resolve().parent.parent / "app" / "jellyfin_secret.cfg"


def load_secret_cfg(path: Path) -> tuple[str, str]:
    """Read base_url and api_key from key=value (optional [section]) config."""
    if not path.exists():
        raise FileNotFoundError(f"Secret config not found: {path}")
    values: dict[str, str] = {}
    with path.open("r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or line.startswith(";") or line.startswith("["):
                continue
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            values[key] = val
    base_url = values.get("base_url", "").rstrip("/")
    api_key = values.get("api_key", "")
    if not base_url or not api_key:
        raise ValueError("Secret config must define both base_url and api_key")
    return base_url, api_key


class JellyfinBridge:
    def __init__(self, base_url: str, api_key: str, cache_dir: Path, proxy_url: str = "") -> None:
        self.base_url = base_url.rstrip("/")
        self._api_key = api_key
        self.proxy_url = proxy_url.strip()
        self.cache_dir = cache_dir
        self.posters_dir = cache_dir / "posters"
        self.videos_dir = cache_dir / "videos"
        self.posters_dir.mkdir(parents=True, exist_ok=True)
        self.videos_dir.mkdir(parents=True, exist_ok=True)

        if self.proxy_url:
            proxy_handler = urllib.request.ProxyHandler({
                "http": self.proxy_url,
                "https": self.proxy_url,
            })
        else:
            # Explicit direct connection when HOLODECK_JF_PROXY is unset.
            proxy_handler = urllib.request.ProxyHandler({})
        self._opener = urllib.request.build_opener(proxy_handler)

        self._lock = threading.Lock()
        self._jobs: dict[str, dict[str, Any]] = {}
        self._runtimes: dict[str, float] = {}
        self._procs: set[subprocess.Popen[str]] = set()

    def shutdown(self) -> None:
        with self._lock:
            procs = list(self._procs)
        for p in procs:
            try:
                p.terminate()
            except OSError:
                pass
        for p in procs:
            try:
                p.wait(timeout=2.0)
            except Exception:
                try:
                    p.kill()
                except OSError:
                    pass

    def _auth_header(self) -> str:
        # Verified Jellyfin 12.4 quirk: full MediaBrowser Authorization header required.
        return (
            'MediaBrowser Client="HolodeckBridge", Device="Holodeck", '
            f'DeviceId="holodeck-bridge", Version="1.0", Token="{self._api_key}"'
        )

    def _redact(self, text: str) -> str:
        if self._api_key and self._api_key in text:
            return text.replace(self._api_key, "[REDACTED]")
        return text

    def _jf_request(self, path_and_query: str, timeout: float = 20.0) -> tuple[bytes, str]:
        url = f"{self.base_url}{path_and_query}"
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": self._auth_header(),
                "Accept": "application/json, image/*, */*",
            },
            method="GET",
        )
        try:
            with self._opener.open(req, timeout=timeout) as resp:
                ctype = resp.headers.get("Content-Type", "application/octet-stream")
                return resp.read(), ctype
        except urllib.error.HTTPError as exc:
            raise RuntimeError(f"Jellyfin HTTP {exc.code} for {path_and_query}") from None
        except urllib.error.URLError as exc:
            raise RuntimeError(self._redact(f"Jellyfin connection error: {exc.reason}")) from None

    def _jf_json(self, path_and_query: str, timeout: float = 20.0) -> dict[str, Any]:
        raw, _ = self._jf_request(path_and_query, timeout=timeout)
        data = json.loads(raw.decode("utf-8"))
        return data if isinstance(data, dict) else {"Items": data}

    def get_libraries(self) -> list[dict[str, Any]]:
        data = self._jf_json("/Library/MediaFolders")
        out: list[dict[str, Any]] = []
        for item in data.get("Items", []):
            if not isinstance(item, dict):
                continue
            out.append({
                "id": str(item.get("Id", "")),
                "name": str(item.get("Name", "Untitled")),
                "type": str(item.get("CollectionType") or item.get("Type") or "unknown"),
            })
        return out

    def get_items(self, parent_id: str) -> list[dict[str, Any]]:
        if not ITEM_ID_RE.match(parent_id):
            raise ValueError("Invalid parent id")
        qs = urllib.parse.urlencode({
            "ParentId": parent_id,
            "Recursive": "true",
            "IncludeItemTypes": "Movie,Episode,Video",
            "SortBy": "SortName",
            "Limit": "100",
        })
        data = self._jf_json(f"/Items?{qs}")
        out: list[dict[str, Any]] = []
        for item in data.get("Items", []):
            if not isinstance(item, dict):
                continue
            item_id = str(item.get("Id", ""))
            ticks = item.get("RunTimeTicks") or 0
            runtime_s = int(round(float(ticks) / 10_000_000.0)) if ticks else 0
            if item_id and runtime_s > 0:
                with self._lock:
                    self._runtimes[item_id] = float(runtime_s)
            image_tags = item.get("ImageTags")
            has_poster = isinstance(image_tags, dict) and bool(image_tags.get("Primary"))
            name = str(item.get("Name", "Untitled"))
            series = item.get("SeriesName")
            if series and item.get("Type") == "Episode":
                ep_idx = item.get("IndexNumber")
                season_idx = item.get("ParentIndexNumber")
                if season_idx is not None and ep_idx is not None:
                    name = f"{series} · S{int(season_idx):02d}E{int(ep_idx):02d} · {name}"
                else:
                    name = f"{series} · {name}"
            year_val = item.get("ProductionYear")
            out.append({
                "id": item_id,
                "name": name,
                "year": int(year_val) if isinstance(year_val, int) else None,
                "runtime": runtime_s,
                "has_poster": has_poster,
            })
        return out

    def get_poster(self, item_id: str) -> tuple[bytes, str] | None:
        if not ITEM_ID_RE.match(item_id):
            raise ValueError("Invalid item id")
        bin_path = self.posters_dir / f"{item_id}.bin"
        meta_path = self.posters_dir / f"{item_id}.ctype"
        if bin_path.exists() and meta_path.exists():
            return bin_path.read_bytes(), meta_path.read_text(encoding="utf-8").strip() or "image/jpeg"
        try:
            data, ctype = self._jf_request(f"/Items/{item_id}/Images/Primary?maxWidth=320&quality=85", timeout=15.0)
        except RuntimeError as exc:
            if "HTTP 404" in str(exc):
                return None
            raise
        tmp_bin = self.posters_dir / f"{item_id}.{threading.get_ident()}.tmp"
        tmp_bin.write_bytes(data)
        os.replace(tmp_bin, bin_path)
        meta_path.write_text(ctype, encoding="utf-8")
        return data, ctype

    def _lookup_runtime(self, item_id: str) -> float:
        with self._lock:
            if item_id in self._runtimes:
                return self._runtimes[item_id]
        try:
            data = self._jf_json(f"/Items?Ids={urllib.parse.quote(item_id)}", timeout=10.0)
            items = data.get("Items", [])
            if items and isinstance(items[0], dict):
                ticks = items[0].get("RunTimeTicks") or 0
                if ticks:
                    rt = float(ticks) / 10_000_000.0
                    with self._lock:
                        self._runtimes[item_id] = rt
                    return rt
        except Exception:
            pass
        return 0.0

    def video_path(self, item_id: str) -> Path:
        if not ITEM_ID_RE.match(item_id):
            raise ValueError("Invalid item id")
        return self.videos_dir / f"{item_id}.ogv"

    def start_play(self, item_id: str, max_seconds: float | None = None) -> dict[str, Any]:
        if not ITEM_ID_RE.match(item_id):
            raise ValueError("Invalid item id")
        target = self.video_path(item_id)
        with self._lock:
            existing = self._jobs.get(item_id)
            if existing and existing.get("state") == "working":
                return self._status_payload(existing)
            if target.exists() and target.stat().st_size > 0:
                prev_max = existing.get("max_seconds") if existing else None
                if max_seconds is None or prev_max == max_seconds:
                    job = {
                        "state": "ready",
                        "progress": 1.0,
                        "approximate": False,
                        "error": "",
                        "max_seconds": max_seconds,
                    }
                    self._jobs[item_id] = job
                    return self._status_payload(job)
            job = {
                "state": "working",
                "progress": 0.0,
                "approximate": True,
                "error": "",
                "max_seconds": max_seconds,
            }
            self._jobs[item_id] = job

        worker = threading.Thread(
            target=self._run_transcode,
            args=(item_id, max_seconds),
            daemon=True,
        )
        worker.start()
        return self._status_payload(job)

    def get_play_status(self, item_id: str) -> dict[str, Any]:
        if not ITEM_ID_RE.match(item_id):
            raise ValueError("Invalid item id")
        with self._lock:
            job = self._jobs.get(item_id)
            if job is not None:
                return self._status_payload(job)
        target = self.video_path(item_id)
        if target.exists() and target.stat().st_size > 0:
            return {
                "state": "ready",
                "progress": 1.0,
                "approximate": False,
                "progress_note": "cached",
            }
        return {
            "state": "none",
            "progress": 0.0,
            "approximate": True,
            "progress_note": "not started",
        }

    @staticmethod
    def _status_payload(job: dict[str, Any]) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "state": job.get("state", "none"),
            "progress": round(float(job.get("progress", 0.0)), 4),
            "approximate": bool(job.get("approximate", True)),
            "progress_note": "estimated from ffmpeg out_time" if job.get("approximate", True) else "complete",
        }
        if job.get("error"):
            payload["error"] = job["error"]
        return payload

    def _run_transcode(self, item_id: str, max_seconds: float | None) -> None:
        target = self.video_path(item_id)
        part = self.videos_dir / f"{item_id}.part.ogv"
        expected_s = max_seconds if (max_seconds and max_seconds > 0) else self._lookup_runtime(item_id)
        stream_url = f"{self.base_url}/Videos/{item_id}/stream?static=true"

        cmd = [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-headers", f"Authorization: {self._auth_header()}\r\n",
            "-i", stream_url,
        ]
        if max_seconds and max_seconds > 0:
            cmd += ["-t", str(max_seconds)]
        cmd += [
            "-threads", "0",
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-sn",
            "-dn",
            "-vf", "scale='min(854,iw)':'min(480,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-pix_fmt", "yuv420p",
            "-c:v", "libtheora",
            "-q:v", "7",
            "-c:a", "libvorbis",
            "-q:a", "4",
            "-ac", "2",
            "-progress", "pipe:1",
            "-nostats",
            "-f", "ogg",
            str(part),
        ]

        env = os.environ.copy()
        if self.proxy_url:
            env["http_proxy"] = self.proxy_url
            env["https_proxy"] = self.proxy_url
            env["HTTP_PROXY"] = self.proxy_url
            env["HTTPS_PROXY"] = self.proxy_url
        else:
            for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"):
                env.pop(k, None)

        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )
            with self._lock:
                self._procs.add(proc)
        except Exception as exc:
            with self._lock:
                self._jobs[item_id] = {
                    "state": "error",
                    "progress": 0.0,
                    "approximate": True,
                    "error": self._redact(f"ffmpeg launch failed: {exc}"),
                    "max_seconds": max_seconds,
                }
            return

        stderr_lines: list[str] = []

        def _drain_stderr() -> None:
            assert proc.stderr is not None
            for line in proc.stderr:
                stderr_lines.append(self._redact(line.strip()))

        err_thread = threading.Thread(target=_drain_stderr, daemon=True)
        err_thread.start()

        assert proc.stdout is not None
        for raw_line in proc.stdout:
            line = raw_line.strip()
            if "=" not in line:
                continue
            k, v = line.split("=", 1)
            out_s: float | None = None
            if k == "out_time_us":
                try:
                    out_s = max(0.0, float(v) / 1_000_000.0)
                except ValueError:
                    pass
            elif k == "out_time_ms":
                try:
                    # ffmpeg's out_time_ms is actually microseconds in many builds
                    out_s = max(0.0, float(v) / 1_000_000.0)
                except ValueError:
                    pass
            if out_s is not None:
                if expected_s > 0.0:
                    prog = min(0.99, out_s / expected_s)
                else:
                    # Unknown runtime: smooth asymptotic estimate so UI visibly moves
                    prog = min(0.95, 1.0 - 1.0 / (1.0 + out_s / 60.0))
                with self._lock:
                    if item_id in self._jobs and self._jobs[item_id].get("state") == "working":
                        self._jobs[item_id]["progress"] = max(float(self._jobs[item_id]["progress"]), prog)

        rc = proc.wait()
        with self._lock:
            self._procs.discard(proc)
        err_thread.join(timeout=2.0)

        if rc == 0 and part.exists() and part.stat().st_size > 0:
            os.replace(part, target)
            with self._lock:
                self._jobs[item_id] = {
                    "state": "ready",
                    "progress": 1.0,
                    "approximate": False,
                    "error": "",
                    "max_seconds": max_seconds,
                }
        else:
            if part.exists():
                try:
                    part.unlink()
                except OSError:
                    pass
            detail = "; ".join(l for l in stderr_lines if l)[-300:] or f"ffmpeg exited with code {rc}"
            with self._lock:
                self._jobs[item_id] = {
                    "state": "error",
                    "progress": 0.0,
                    "approximate": True,
                    "error": self._redact(detail),
                    "max_seconds": max_seconds,
                }


def _parse_route_and_query(raw_path: str) -> tuple[str, dict[str, list[str]]]:
    """Parse URL path + query, also tolerating '&key=val' appended without '?'."""
    parsed = urllib.parse.urlsplit(raw_path)
    path = parsed.path
    query_str = parsed.query
    if not query_str and "&" in path:
        path, query_str = path.split("&", 1)
    return path, urllib.parse.parse_qs(query_str)


def make_handler(bridge: JellyfinBridge) -> type[BaseHTTPRequestHandler]:
    class BridgeHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, format: str, *args: Any) -> None:
            # Never log headers/tokens; keep concise request line only.
            msg = format % args
            sys.stderr.write(f"[jf-bridge] {self.address_string()} {bridge._redact(msg)}\n")
            sys.stderr.flush()

        def _send_json(self, code: int, payload: Any) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _send_bytes(self, code: int, body: bytes, ctype: str) -> None:
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            path, qs = _parse_route_and_query(self.path)
            try:
                if path == "/jf/health":
                    self._send_json(HTTPStatus.OK, {"ok": True})
                    return

                if path == "/jf/libraries":
                    libs = bridge.get_libraries()
                    self._send_json(HTTPStatus.OK, {"libraries": libs})
                    return

                if path == "/jf/items":
                    parent_vals = qs.get("parent", [])
                    if not parent_vals or not parent_vals[0]:
                        self._send_json(HTTPStatus.BAD_REQUEST, {"error": "missing parent parameter"})
                        return
                    items = bridge.get_items(parent_vals[0])
                    self._send_json(HTTPStatus.OK, {"items": items})
                    return

                if path.startswith("/jf/poster/"):
                    item_id = path[len("/jf/poster/"):].strip("/")
                    res = bridge.get_poster(item_id)
                    if res is None:
                        self._send_json(HTTPStatus.NOT_FOUND, {"error": "poster not found"})
                        return
                    data, ctype = res
                    self._send_bytes(HTTPStatus.OK, data, ctype)
                    return

                if path.startswith("/jf/play_status/"):
                    item_id = path[len("/jf/play_status/"):].strip("/")
                    self._send_json(HTTPStatus.OK, bridge.get_play_status(item_id))
                    return

                if path.startswith("/jf/file/"):
                    item_id = path[len("/jf/file/"):].strip("/")
                    target = bridge.video_path(item_id)
                    if not target.exists():
                        self._send_json(HTTPStatus.NOT_FOUND, {"error": "transcoded file not ready"})
                        return
                    size = target.stat().st_size
                    self.send_response(HTTPStatus.OK)
                    self.send_header("Content-Type", "video/ogg")
                    self.send_header("Content-Length", str(size))
                    self.end_headers()
                    with target.open("rb") as fh:
                        while True:
                            chunk = fh.read(65536)
                            if not chunk:
                                break
                            self.wfile.write(chunk)
                    return

                self._send_json(HTTPStatus.NOT_FOUND, {"error": "unknown endpoint"})
            except ValueError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            except Exception as exc:
                self._send_json(HTTPStatus.BAD_GATEWAY, {"error": bridge._redact(str(exc))})

        def do_POST(self) -> None:
            path, qs = _parse_route_and_query(self.path)
            # Drain any request body cleanly for HTTP/1.1 keep-alive safety.
            clen = int(self.headers.get("Content-Length", "0") or "0")
            if clen > 0:
                self.rfile.read(min(clen, 65536))
            try:
                if path.startswith("/jf/play/"):
                    item_id = path[len("/jf/play/"):].strip("/")
                    max_s: float | None = None
                    if "max_seconds" in qs and qs["max_seconds"]:
                        max_s = float(qs["max_seconds"][0])
                        if max_s <= 0:
                            raise ValueError("max_seconds must be positive")
                    status = bridge.start_play(item_id, max_seconds=max_s)
                    self._send_json(HTTPStatus.OK, status)
                    return
                self._send_json(HTTPStatus.NOT_FOUND, {"error": "unknown endpoint"})
            except ValueError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            except Exception as exc:
                self._send_json(HTTPStatus.BAD_GATEWAY, {"error": bridge._redact(str(exc))})

    return BridgeHandler


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Holodeck Jellyfin transcode bridge")
    parser.add_argument("positional", nargs="*", help="Optional [host] [port] override")
    parser.add_argument("--host", default=None, help="Bind host (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=None, help="Bind port (default 8791)")
    parser.add_argument("--config", type=Path, default=DEFAULT_SECRET_PATH, help="Path to jellyfin_secret.cfg")
    parser.add_argument("--cache-dir", type=Path, default=None, help="Cache directory for posters and .ogv files")
    args = parser.parse_args(argv)

    host = args.host or "127.0.0.1"
    port = args.port if args.port is not None else 8791
    pos = args.positional
    if len(pos) == 1:
        if ":" in pos[0]:
            h, p = pos[0].rsplit(":", 1)
            host = h or host
            port = int(p)
        elif pos[0].isdigit():
            port = int(pos[0])
        else:
            host = pos[0]
    elif len(pos) >= 2:
        host = pos[0]
        port = int(pos[1])

    args.host = host
    args.port = port
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    base_url, api_key = load_secret_cfg(args.config)
    proxy_url = os.environ.get("HOLODECK_JF_PROXY", "")
    cache_dir = args.cache_dir or Path(tempfile.gettempdir()) / "holodeck_jf_cache"
    bridge = JellyfinBridge(base_url, api_key, cache_dir, proxy_url=proxy_url)
    atexit.register(bridge.shutdown)

    server = ThreadingHTTPServer((args.host, args.port), make_handler(bridge))
    def _handle_term(_signum: int, _frame: Any) -> None:
        bridge.shutdown()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, _handle_term)

    proxy_note = "via HOLODECK_JF_PROXY" if proxy_url else "direct"
    print(f"[jf-bridge] listening on http://{args.host}:{args.port} ({proxy_note}, cache={cache_dir})", flush=True)
    try:
        server.serve_forever()
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        bridge.shutdown()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
