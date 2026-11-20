#!/usr/bin/env python3
"""Local mock of the Atlas hub's Holodeck routes (dev/test harness, NOT shipped). The sandbox has no LAN route to the
real hub, so the app's voice + voice-CAD client is exercised against this stand-in, which speaks the same protocol as
obelisk/atlas_voice.py (stdlib only: asyncio, hand-rolled websocket framing, REST on the same port).

  python3 tools/mock_hub.py --port 8791 --assets <dir with model.glb + manifest.json> [--speak <mp3>] [--log out.txt]

It REQUIRES the Bearer token from app/hub_secret.cfg on every route (so the run proves the app sends it) and logs
what it received. Scenario: "ready" on connect; at +2 s a spotter "wake"; PTT (ptt_start/ptt_end) is answered with a
conversation turn first, then a CAD turn ("cad_job", then "cad_done" ~4 s later). Nothing here touches the real hub.
"""
import argparse, asyncio, base64, hashlib, json, os, re, struct, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8791)
ap.add_argument("--assets", required=True)
ap.add_argument("--speak", default="")
ap.add_argument("--wake", action="store_true", help="also script a spotter wake at +2 s (experimental path)")
ap.add_argument("--job", default="a8b6d50939")
ap.add_argument("--log", default="")
ap.add_argument("--secret", default=os.path.join(os.path.dirname(__file__), "..", "app", "hub_secret.cfg"))
A = ap.parse_args()
TOKEN = re.search(r'token="([^"]+)"', open(A.secret).read()).group(1)
MANIFEST = json.load(open(os.path.join(A.assets, "manifest.json")))
GLB = open(os.path.join(A.assets, "model.glb"), "rb").read()
SPEAK = open(A.speak, "rb").read() if A.speak else b""
JOB = A.job
T0 = time.time()
state = {"cad_ready_at": None, "ptt_turns": 0, "audio_bytes": 0, "speaks": [], "ws_auth_ok": 0, "rest_auth_fail": 0}

def log(msg):
    line = f"[mock t+{time.time()-T0:6.2f}s] {msg}"
    print(line, flush=True)
    if A.log:
        open(A.log, "a").write(line + "\n")

def authed(headers):
    return headers.get("authorization") == f"Bearer {TOKEN}"

async def read_request(reader):
    head = await reader.readuntil(b"\r\n\r\n")
    lines = head.decode("latin1").split("\r\n")
    method, path, _ = lines[0].split(" ", 2)
    headers = {k.lower(): v for k, v in (l.split(": ", 1) for l in lines[1:] if ": " in l)}
    body = b""
    n = int(headers.get("content-length", "0") or 0)
    if n:
        body = await reader.readexactly(n)
    return method, path, headers, body

def http(status, body=b"", ctype="application/json"):
    reason = {200: "OK", 401: "Unauthorized", 404: "Not Found"}.get(status, "OK")
    return (f"HTTP/1.1 {status} {reason}\r\nContent-Type: {ctype}\r\nContent-Length: {len(body)}\r\nConnection: close\r\n\r\n").encode() + body

async def ws_send(writer, obj):
    data = json.dumps(obj).encode()
    n = len(data)
    hdr = bytes([0x81]) + (bytes([n]) if n < 126 else b"\x7e" + struct.pack(">H", n))
    writer.write(hdr + data)
    await writer.drain()

async def ws_read(reader):
    b = await reader.readexactly(2)
    op, ln = b[0] & 0x0F, b[1] & 0x7F
    if ln == 126:
        ln = struct.unpack(">H", await reader.readexactly(2))[0]
    elif ln == 127:
        ln = struct.unpack(">Q", await reader.readexactly(8))[0]
    mask = await reader.readexactly(4) if b[1] & 0x80 else b"\0\0\0\0"
    payload = bytearray(await reader.readexactly(ln))
    for i in range(ln):
        payload[i] ^= mask[i % 4]
    return op, bytes(payload)

async def handle(reader, writer):
    try:
        method, path, headers, body = await read_request(reader)
        if headers.get("upgrade", "").lower() == "websocket":
            if not authed(headers) or path != "/atlas/voice-stream":
                state["rest_auth_fail"] += 1
                log(f"WS REFUSED path={path} auth={'ok' if authed(headers) else 'MISSING/BAD'}")
                writer.write(http(403, b"")); await writer.drain(); return
            state["ws_auth_ok"] += 1
            acc = base64.b64encode(hashlib.sha1((headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
            writer.write(f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {acc}\r\n\r\n".encode())
            await writer.drain()
            log("WS open, Bearer token accepted")
            await ws_session(reader, writer)
            return
        if path == "/atlas/status":                                   # open, like the real hub's status route
            writer.write(http(200, b'{"ok":true,"mock":true}')); await writer.drain(); return
        if not authed(headers):
            state["rest_auth_fail"] += 1
            log(f"REST {method} {path} -> 401 (no/bad bearer)")
            writer.write(http(401, b'{"detail":"bad or missing bearer token"}')); await writer.drain(); return
        if path == "/atlas/speak" and method == "POST":
            text = json.loads(body or b"{}").get("text", "")
            state["speaks"].append(text)
            log(f"REST POST /atlas/speak -> {len(SPEAK)} B mp3 for: {text[:80]!r}")
            writer.write(http(200, SPEAK, "audio/mpeg")); await writer.drain(); return
        m = re.match(r"^/atlas/cad-job/([a-f0-9]+)(/model)?$", path)
        if m and method == "GET":
            ready = state["cad_ready_at"] is not None and time.time() >= state["cad_ready_at"]
            if m.group(2):
                log(f"REST GET {path} -> {len(GLB)} B glb" if ready else f"REST GET {path} -> 404 not ready")
                writer.write(http(200, GLB, "model/gltf-binary") if ready else http(404, b"{}")); await writer.drain(); return
            doc = {"job_id": m.group(1), "status": "done" if ready else "working", "stage": "done" if ready else "building", "name": MANIFEST["name"]}
            if ready:
                doc["manifest"] = MANIFEST
            log(f"REST GET {path} -> {doc['status']}")
            writer.write(http(200, json.dumps(doc).encode())); await writer.drain(); return
        writer.write(http(404, b"{}")); await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionError):
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass

async def ws_session(reader, writer):
    await ws_send(writer, {"event": "ready", "wake": bool(A.wake), "ptt": True, "session": "mock"})
    async def scripted_wake():
        await asyncio.sleep(2.0)
        log("-> wake (spotter) / utterance / transcript / reply")
        await ws_send(writer, {"event": "wake", "source": "wake", "keyword": "ATLAS"})
        await asyncio.sleep(6.0)      # a long listen: lets a slow software-rendered capture catch the LISTENING state
        await ws_send(writer, {"event": "utterance_end", "why": "silence", "seconds": 2.0})
        await asyncio.sleep(0.5)
        await ws_send(writer, {"event": "transcript", "text": "What is on the print queue?"})
        await ws_send(writer, {"event": "reply", "text": "Two jobs are queued. The next one starts in ten minutes.", "kind": "answer"})
        await ws_send(writer, {"event": "idle", "reason": "done"})
    task = asyncio.create_task(scripted_wake() if A.wake else asyncio.sleep(0))
    try:
        while True:
            op, payload = await ws_read(reader)
            if op == 0x8:
                log("WS close frame"); break
            if op == 0x2:
                if state["audio_bytes"] == 0:
                    log(f"first binary audio frame: {len(payload)} B (PCM16 16 kHz)")
                state["audio_bytes"] += len(payload)
            elif op == 0x1:
                ev = json.loads(payload).get("event")
                log(f"<- client event {ev}")
                if ev == "ptt_start":
                    log(f"PTT hold started; audio bytes received BEFORE the hold: {state['audio_bytes']} (0 = mic was never streamed)")
                    await ws_send(writer, {"event": "wake", "source": "ptt"})
                elif ev == "ptt_end":
                    state["ptt_turns"] += 1
                    await ws_send(writer, {"event": "utterance_end", "why": "ptt-end", "seconds": 2.1})
                    log(f"PTT hold ended; audio bytes received so far: {state['audio_bytes']}")
                    if state["ptt_turns"] == 1:
                        await asyncio.sleep(0.4)
                        await ws_send(writer, {"event": "transcript", "text": "What is on the print queue?"})
                        await ws_send(writer, {"event": "reply", "text": "Two jobs are queued. The next one starts in ten minutes.", "kind": "answer"})
                        await ws_send(writer, {"event": "idle", "reason": "done"})
                    elif state["ptt_turns"] == 2:
                        text = "Make me a phone stand that is three inches wide."
                        await ws_send(writer, {"event": "transcript", "text": text})
                        state["cad_ready_at"] = time.time() + 4.0
                        await ws_send(writer, {"event": "cad_job", "job_id": JOB, "text": "On it. I'm designing that now, give me about a minute."})
                        await ws_send(writer, {"event": "reply", "text": "On it. I'm designing that now, give me about a minute.", "kind": "cad_ack"})
                        await ws_send(writer, {"event": "idle", "reason": "done"})
                        async def later():
                            await asyncio.sleep(4.5)
                            log("-> cad_done")
                            await ws_send(writer, {"event": "cad_done", "job_id": JOB, "name": MANIFEST["name"]})
                        asyncio.create_task(later())
    except (asyncio.IncompleteReadError, ConnectionError):
        log("WS dropped")
    finally:
        task.cancel()
        log(f"WS closed; total audio bytes received {state['audio_bytes']}; speaks={len(state['speaks'])}")

async def main():
    srv = await asyncio.start_server(handle, "127.0.0.1", A.port)
    log(f"mock hub on 127.0.0.1:{A.port} (token required; assets {A.assets})")
    async with srv:
        await srv.serve_forever()

asyncio.run(main())
