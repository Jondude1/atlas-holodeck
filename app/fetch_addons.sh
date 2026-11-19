#!/usr/bin/env bash
# Fetch the Godot OpenXR Vendors addon, pinned to 5.2.0-stable (matches Godot 4.7).
# Why: it injects the Meta Quest VR manifest entries (com.oculus.intent.category.VR,
# android.hardware.vr.headtracking) into the Gradle Android export.
# Not committed to git because it is ~50 MB of binaries; app/addons/ is gitignored.
set -euo pipefail

VERSION="5.2.0-stable"
URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VERSION}/godotopenxrvendorsaddon.zip"
DL_DIR="${VENDORS_DL_DIR:-$HOME/workspace/tooling/godot/downloads}"
ZIP="${VENDORS_ZIP:-$DL_DIR/godotopenxrvendorsaddon-5.2.0.zip}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$(dirname "$ZIP")"
[ -s "$ZIP" ] || curl -fL -o "$ZIP" "$URL"

# The release zip nests the addon as asset/addons/godotopenxrvendors/
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unzip -q "$ZIP" -d "$tmp"
mkdir -p "$PROJECT_DIR/addons"
rm -rf "$PROJECT_DIR/addons/godotopenxrvendors"
cp -r "$tmp/asset/addons/godotopenxrvendors" "$PROJECT_DIR/addons/"
echo "Installed godotopenxrvendors $VERSION into $PROJECT_DIR/addons/"
