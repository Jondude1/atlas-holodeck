#!/usr/bin/env python3
"""Create a GitHub release on Jondude1/atlas-holodeck and upload the APK as a
release asset, using the stored custom.github credential (surrogate exchange).
Usage: python3 release_upload.py
"""
import json, os, sys, urllib.request, urllib.error

sys.path.insert(0, "/opt/muse/skills/custom-connector-setup/bin")
sys.path.insert(0, "/opt/muse/skills/custom-connector-setup/templates/skill/bin")
from dynamic_credentials import add_surrogate_to_request, read_json_response, read_response_body

API = "https://api.github.com"
OWNER, REPO = "Jondude1", "atlas-holodeck"
TAG = "v0.1.0"
TARGET = "5623342485dda3f190536dbad4452432bbd643aa"
APK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "builds", "AtlasHolodeck.apk")

def req(method, url, payload=None, raw=None, ctype=None):
    data = raw
    headers = {"User-Agent": "helios-holodeck-release/1.0", "Accept": "application/vnd.github+json"}
    if payload is not None:
        data = json.dumps(payload).encode(); headers["Content-Type"] = "application/json"
    if ctype:
        headers["Content-Type"] = ctype
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    host = urllib.request.urlparse(url).hostname
    add_surrogate_to_request(r, "custom.github", allowed_hosts=(host,))
    try:
        with urllib.request.urlopen(r) as resp:
            body = read_response_body(resp)
            try: return resp.status, json.loads(body)
            except Exception: return resp.status, {"raw": body[:200]}
    except urllib.error.HTTPError as e:
        try: body = json.loads(read_response_body(e))
        except Exception: body = {"message": f"HTTP {e.code}"}
        return e.code, body

def main():
    # Reuse the release if it already exists
    s, rel = req("GET", f"{API}/repos/{OWNER}/{REPO}/releases/tags/{TAG}")
    if s == 200:
        print("release exists:", rel["id"])
    else:
        s, rel = req("POST", f"{API}/repos/{OWNER}/{REPO}/releases", payload={
            "tag_name": TAG,
            "target_commitish": TARGET,
            "name": "Atlas Holodeck v0.1.0 — first contact (polished build)",
            "body": ("First-contact build, brief #8 polish pass applied (workshop room, HUD frame with real data, "
                     "tethered part labels). Amazement gate PASSED by Helios 2026-11-19: APK 81,355,494 bytes, "
                     "signature verified, 60 draw calls, 3 lights.\n\n"
                     "Sideload with SideQuest (Developer Mode required). Home-network only: tries the house LAN "
                     "hub first, then the tailnet address."),
            "draft": False, "prerelease": True,
        })
        if s not in (200, 201):
            print("release create failed:", s, rel); sys.exit(1)
        print("release created:", rel["id"])
    upload_url = rel["upload_url"].split("{")[0]
    # Skip if asset already there
    for a in rel.get("assets", []):
        if a["name"] == "AtlasHolodeck.apk":
            print("asset already present:", a["browser_download_url"]); return
    size = os.path.getsize(APK)
    print("uploading", size, "bytes...")
    with open(APK, "rb") as f:
        data = f.read()
    s, asset = req("POST", f"{upload_url}?name=AtlasHolodeck.apk", raw=data, ctype="application/octet-stream")
    if s not in (200, 201):
        print("asset upload failed:", s, asset); sys.exit(1)
    print("asset state:", asset.get("state"), "size:", asset.get("size"))
    print("download:", asset.get("browser_download_url"))

if __name__ == "__main__":
    main()
