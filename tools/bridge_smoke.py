#!/usr/bin/env python3
"""Smoke test for tools/jellyfin_bridge.py against the real Jellyfin server.

Starts tools/jellyfin_bridge.py on a local port with HOLODECK_JF_PROXY set
(either from env or derived as ${HTTPS_PROXY%:*}:3130), then verifies:
  1. GET /jf/libraries returns Movies and TV Shows
  2. GET /jf/items?parent=<id> returns a non-empty item list
  3. GET /jf/poster/<id> returns valid image bytes + image/* content-type
  4. POST /jf/play/<id>&max_seconds=15 reaches state=ready via /jf/play_status
  5. GET /jf/file/<id> downloads a valid .ogv probing as theora + vorbis
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BRIDGE_SCRIPT = REPO_ROOT / "tools" / "jellyfin_bridge.py"


def compute_jf_proxy() -> str:
    explicit = os.environ.get("HOLODECK_JF_PROXY", "").strip()
    if explicit:
        return explicit
    https_proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or ""
    https_proxy = https_proxy.strip().rstrip("/")
    if not https_proxy:
        return ""
    # Equivalent to bash ${HTTPS_PROXY%:*}:3130
    idx = https_proxy.rfind(":")
    if idx > 0 and https_proxy[idx + 1 :].isdigit():
        return f"{https_proxy[:idx]}:3130"
    return f"{https_proxy}:3130"


def _local_opener() -> urllib.request.OpenerDirector:
    # Talk to 127.0.0.1 bridge directly (bypass any ambient HTTP_PROXY).
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def http_json(opener: urllib.request.OpenerDirector, url: str, method: str = "GET", timeout: float = 20.0) -> tuple[int, dict]:
    req = urllib.request.Request(url, method=method, data=b"" if method == "POST" else None)
    with opener.open(req, timeout=timeout) as resp:
        return resp.status, json.loads(resp.read().decode("utf-8"))


def http_bytes(opener: urllib.request.OpenerDirector, url: str, timeout: float = 30.0) -> tuple[int, str, bytes]:
    req = urllib.request.Request(url, method="GET")
    with opener.open(req, timeout=timeout) as resp:
        return resp.status, resp.headers.get("Content-Type", ""), resp.read()


def is_image_bytes(data: bytes) -> bool:
    if len(data) < 12:
        return False
    return (
        data.startswith(b"\xff\xd8\xff")  # JPEG
        or data.startswith(b"\x89PNG\r\n\x1a\n")  # PNG
        or (data.startswith(b"RIFF") and data[8:12] == b"WEBP")  # WEBP
        or data.startswith(b"GIF8")  # GIF
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke-test jellyfin_bridge against real Jellyfin")
    parser.add_argument("--port", type=int, default=18791)
    parser.add_argument("--max-seconds", type=int, default=15)
    parser.add_argument("--out-ogv", type=Path, default=Path(tempfile.gettempdir()) / "holodeck_jf_smoke.ogv")
    args = parser.parse_args()

    proxy = compute_jf_proxy()
    cache_dir = Path(tempfile.mkdtemp(prefix="holodeck_jf_smoke_"))
    env = os.environ.copy()
    if proxy:
        env["HOLODECK_JF_PROXY"] = proxy
    print(f"[smoke] starting bridge on 127.0.0.1:{args.port} (proxy={'configured' if proxy else 'direct'})", flush=True)

    proc = subprocess.Popen(
        [sys.executable, str(BRIDGE_SCRIPT), "127.0.0.1", str(args.port), "--cache-dir", str(cache_dir)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    opener = _local_opener()
    base = f"http://127.0.0.1:{args.port}"
    fails = 0

    def check(cond: bool, label: str, detail: str = "") -> None:
        nonlocal fails
        status = "  ok  " if cond else "FAIL  "
        print(f"{status}{label}" + (f" ({detail})" if detail else ""), flush=True)
        if not cond:
            fails += 1

    try:
        # Wait for bridge readiness
        ready = False
        deadline = time.monotonic() + 10.0
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                break
            try:
                code, body = http_json(opener, f"{base}/jf/health", timeout=2.0)
                if code == 200 and body.get("ok"):
                    ready = True
                    break
            except Exception:
                time.sleep(0.15)
        check(ready, "bridge started and /jf/health responded")
        if not ready:
            return 1

        # 1. Libraries
        code, libs_body = http_json(opener, f"{base}/jf/libraries", timeout=25.0)
        libs = libs_body.get("libraries", [])
        lib_names = [str(l.get("name", "")) for l in libs]
        lower_names = [n.lower() for n in lib_names]
        has_movies = any("movie" in n for n in lower_names)
        has_tv = any("tv" in n or "show" in n for n in lower_names)
        check(code == 200 and len(libs) >= 2 and has_movies and has_tv,
              "GET /jf/libraries returns Movies and TV Shows",
              ", ".join(lib_names))

        # 2. Items: verify Movies and TV Shows libraries, pick a reasonably-sized episode for fast proxy transcode
        items: list[dict] = []
        chosen_lib = ""
        tv_items: list[dict] = []
        for lib in libs:
            lid = lib.get("id", "")
            lname = str(lib.get("name", lid))
            if not lid:
                continue
            code_i, items_body = http_json(opener, f"{base}/jf/items?parent={urllib.parse.quote(lid)}", timeout=25.0)
            cand = items_body.get("items", [])
            if code_i == 200 and cand:
                if not items:
                    items = cand
                    chosen_lib = lname
                if "tv" in lname.lower() or "show" in lname.lower():
                    tv_items = cand
        check(len(items) > 0, "GET /jf/items returns non-empty list", f"{chosen_lib}: {len(items)} items")
        if not items:
            return 1

        # 3. Poster + transcode candidate: prefer a shorter TV episode with poster (avoids huge 4K remuxes over tailnet)
        pool = tv_items if tv_items else items
        with_poster = [it for it in pool if it.get("has_poster")]
        candidates = with_poster if with_poster else pool
        candidates = sorted(candidates, key=lambda it: int(it.get("runtime") or 999999))
        poster_item = candidates[0]
        p_code, p_ctype, p_bytes = http_bytes(opener, f"{base}/jf/poster/{poster_item['id']}", timeout=25.0)
        check(p_code == 200 and p_ctype.startswith("image/") and is_image_bytes(p_bytes),
              "GET /jf/poster returns valid image bytes",
              f"{poster_item['name']} -> {p_ctype}, {len(p_bytes)} bytes")

        # 4. Transcode with &max_seconds=15
        play_item = poster_item
        t0 = time.monotonic()
        st_code, st_body = http_json(
            opener,
            f"{base}/jf/play/{play_item['id']}&max_seconds={args.max_seconds}",
            method="POST",
            timeout=25.0,
        )
        check(st_code == 200 and st_body.get("state") in ("working", "ready"),
              f"POST /jf/play started transcode (max_seconds={args.max_seconds})",
              f"item={play_item['name']} state={st_body.get('state')}")

        final_state = st_body.get("state", "none")
        max_prog = float(st_body.get("progress", 0.0))
        poll_deadline = time.monotonic() + 180.0
        while final_state == "working" and time.monotonic() < poll_deadline:
            time.sleep(1.0)
            _, st_body = http_json(opener, f"{base}/jf/play_status/{play_item['id']}", timeout=15.0)
            final_state = st_body.get("state", "none")
            max_prog = max(max_prog, float(st_body.get("progress", 0.0)))
        elapsed = time.monotonic() - t0
        check(final_state == "ready",
              "GET /jf/play_status reached ready",
              f"state={final_state} max_progress={max_prog:.2f} elapsed={elapsed:.1f}s err={st_body.get('error', '')}")

        # 5. Download .ogv and probe with ffprobe
        if final_state == "ready":
            f_code, f_ctype, f_bytes = http_bytes(opener, f"{base}/jf/file/{play_item['id']}", timeout=60.0)
            args.out_ogv.write_bytes(f_bytes)
            check(f_code == 200 and len(f_bytes) > 10_000,
                  "GET /jf/file downloaded .ogv",
                  f"{len(f_bytes)} bytes, ctype={f_ctype}, saved={args.out_ogv}")

            probe = subprocess.run(
                [
                    "ffprobe",
                    "-v", "error",
                    "-show_entries", "stream=codec_type,codec_name,width,height:format=duration",
                    "-of", "json",
                    str(args.out_ogv),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            probe_data = json.loads(probe.stdout) if probe.returncode == 0 and probe.stdout else {}
            streams = probe_data.get("streams", [])
            v_streams = [s for s in streams if s.get("codec_type") == "video"]
            a_streams = [s for s in streams if s.get("codec_type") == "audio"]
            v_ok = bool(v_streams) and v_streams[0].get("codec_name") == "theora"
            w = int(v_streams[0].get("width", 0)) if v_streams else 0
            h = int(v_streams[0].get("height", 0)) if v_streams else 0
            dims_ok = 0 < w <= 854 and 0 < h <= 480
            a_ok = (not a_streams) or a_streams[0].get("codec_name") == "vorbis"
            dur = float(probe_data.get("format", {}).get("duration", 0.0) or 0.0)
            check(v_ok and a_ok and dims_ok and dur > 1.0,
                  "ffprobe confirms theora/vorbis <=854x480",
                  f"video={v_streams[0].get('codec_name') if v_streams else 'none'} {w}x{h}, "
                  f"audio={a_streams[0].get('codec_name') if a_streams else 'none'}, dur={dur:.1f}s")
    finally:
        proc.terminate()
        try:
            out, _ = proc.communicate(timeout=5.0)
        except subprocess.TimeoutExpired:
            proc.kill()
            out, _ = proc.communicate()
        if fails > 0 and out:
            print("[smoke] bridge output tail:", flush=True)
            for line in out.splitlines()[-20:]:
                print("  " + line, flush=True)

    print("BRIDGE_SMOKE " + ("PASS" if fails == 0 else f"FAIL ({fails})"), flush=True)
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
