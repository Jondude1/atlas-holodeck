# Builds

Exported APKs land here locally and are **not** committed to git (see `.gitignore`).

| File | Version | Date | Notes |
|---|---|---|---|
| `AtlasHolodeck.apk` | 0.1.0 (1) | 2026-11-19 | **INTERNAL skeleton** (SPEC §7 class 1 — pipeline proof, never handed to Jon as "the build"). Gradle build + Godot OpenXR Vendors plugin 5.2.0 (Meta Quest support: quest2\|quest3\|quest3s). Verified: 80,445,000 bytes, apksigner Verifies (debug cert CN=Android Debug), package `com.jondude.holodeck`, manifest contains `com.oculus.intent.category.VR` ×2 + `android.hardware.vr.headtracking`. Superseded by the design-pass build below once it lands. |
| `AtlasHolodeck.apk` | 0.1.0 (1) | 2026-11-19 | **INTERNAL design pass** (brief #3: Stark tokens, boot sequence, materialize, SFX, voice). 81,320,089 bytes, apksigner Verifies (CN=Android Debug), package `com.jondude.holodeck`, manifest has `com.oculus.intent.category.VR` + `android.hardware.vr.headtracking`. Replaces the skeleton build above. |
| `AtlasHolodeck.apk` | 0.1.0 (1) | 2026-11-19 | **INTERNAL table rebuild** (brief #4: SHIELD dark-titanium holotable, splayed legs with light channels, edge light strip, 1.95×1.0 display inset). 81,323,789 bytes, apksigner Verifies, package `com.jondude.holodeck`, VR category + headtracking feature present. Replaces the design-pass build above. |
