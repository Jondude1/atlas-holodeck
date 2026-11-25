#!/usr/bin/env python3
"""Gemini image generation via the custom.google-gemini connector credential.
Usage: gemini_image.py --model gemini-2.5-flash-image --out out.png --prompt "..." [--prompt-file f]
Prints JSON {ok, out, bytes, model}. The key never appears here — dynamic_credentials attaches
the surrogate and Muse swaps it on the approved request to the registered host."""
import argparse, base64, json, sys, urllib.request, urllib.error
sys.path.insert(0, "/opt/muse/skills/custom-connector-setup/bin")
from dynamic_credentials import add_surrogate_to_request, read_json_response

CRED = "custom.google-gemini"
HOSTS = ["generativelanguage.googleapis.com"]
BASE = "https://generativelanguage.googleapis.com/v1beta"

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise RuntimeError("redirect refused, verify the endpoint")

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="gemini-2.5-flash-image")
    ap.add_argument("--out", required=True)
    ap.add_argument("--prompt", default="")
    ap.add_argument("--prompt-file", default="")
    ap.add_argument("--aspect", default="16:9")
    ap.add_argument("--ref", action="append", default=[],
                    help="reference image to condition on (repeatable); sent before the text part")
    a = ap.parse_args()
    prompt = a.prompt
    if a.prompt_file:
        prompt = open(a.prompt_file).read().strip()
    parts = []
    for ref in a.ref:
        mime = "image/png" if ref.lower().endswith(".png") else "image/jpeg"
        if ref.lower().endswith(".webp"):
            mime = "image/webp"
        with open(ref, "rb") as f:
            parts.append({"inline_data": {"mime_type": mime,
                                          "data": base64.b64encode(f.read()).decode()}})
    parts.append({"text": prompt})
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": a.aspect}},
    }
    url = f"{BASE}/models/{a.model}:generateContent"
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    add_surrogate_to_request(req, CRED, allowed_hosts=HOSTS)
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=300) as resp:
            body = read_json_response(resp)
    except urllib.error.HTTPError as e:
        print(json.dumps({"ok": False, "status": e.code, "error": e.read().decode("utf-8", "replace")[:800]}))
        return 1
    for cand in body.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                raw = base64.b64decode(inline["data"])
                with open(a.out, "wb") as f:
                    f.write(raw)
                print(json.dumps({"ok": True, "out": a.out, "bytes": len(raw), "model": a.model,
                                  "mime": inline.get("mimeType", "")}))
                return 0
    print(json.dumps({"ok": False, "error": "no image part in response", "body": str(body)[:800]}))
    return 1

if __name__ == "__main__":
    sys.exit(main())
