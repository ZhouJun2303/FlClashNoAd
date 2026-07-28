# NoAd Android Release Checklist

NoAd v0.9.0 is Android-first. Local workstation setup and real-device validation are intentionally separated from repository changes because they require installed SDKs, devices, and credentials.

## Required toolchain

- Flutter 3.44.4 / Dart from that Flutter SDK
- Go 1.26.4
- JDK 21
- Android SDK platform 36
- Android Build Tools 36.0.0
- Android NDK 28.2.13676358 / r28c

## Repository verification commands

Run from the repository root after the toolchain is available:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run intl_utils:generate
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

Run the Go core tests from `core/`:

```bash
go test .
```

Build Android release artifacts from the repository root:

```bash
dart setup.dart android --env stable -v
```

The release build uses `distribute_options.yaml`, whose app name is `NoAd`, and should produce split APKs under `dist/`.

## GitHub Actions release outputs

Pushes and pull requests targeting `main` run repository verification only. A `v*` tag additionally builds the signed Android artifacts and creates a draft GitHub Release containing:

- `NoAd-<version>-android-arm64-v8a.apk`
- `NoAd-<version>-android-armeabi-v7a.apk`
- `NoAd-<version>-android-x86_64.apk`
- `SHA256SUMS`
- `NoAd-<version>-source.tar.gz`, a GPL corresponding-source archive that includes checked-out submodules.

The workflow verifies the exact APK count and names, checks that every release asset is non-empty, and validates `SHA256SUMS` before creating the draft. Install and validate the APK downloaded from that draft, then publish the Release manually only after all external validation items pass.

## Draft artifact verification

Download every asset from the draft Release into one directory and verify the checksums before installing an APK:

```bash
sha256sum -c SHA256SUMS
```

Run `apksigner verify --verbose --print-certs` on each APK and confirm that all three use the expected release certificate rather than a debug certificate. Use `apkanalyzer manifest application-id`, `manifest version-name`, and `manifest version-code` to confirm:

- application ID `com.follow.clash.noad`;
- version name `0.9.0`;
- version code `2026072801`.

Inspect the APK entries and confirm that the arm64-v8a, armeabi-v7a, and x86_64 artifacts each contain the matching `libclash.so` ABI. Extract `NoAd-0.9.0-source.tar.gz` and confirm that it includes `.fvmrc`, `core/Clash.Meta/go.mod`, the NoAd rule snapshot, its license notice, and the repository build scripts.

## Required GitHub Secrets

These values must be provided by the repository owner. Do not commit them to the repository.

- `KEYSTORE`: base64-encoded Android signing keystore.
- `KEY_ALIAS`: Android signing key alias.
- `STORE_PASSWORD`: Android keystore password.
- `KEY_PASSWORD`: Android key password.
- `SERVICE_JSON`: base64-encoded Firebase `google-services.json` for `com.follow.clash.noad`.

## External validation items

These cannot be completed inside the repository alone and must be performed by the user/release owner:

- confirm release signing with the real private keystore;
- confirm Firebase config belongs to `com.follow.clash.noad` and collection remains opt-in/default-off;
- install the arm64-v8a APK from the draft on a real Android device, test the x86_64 APK on an API 36 emulator, and run a launch check on an emulator matching the APK's resolved minimum SDK;
- verify first-run VPN permission, start/stop, notification state, background resume, device restart, and Wi-Fi/cellular switching;
- verify known ad-domain blocking, normal HTTPS, Fake-IP, QUIC, app DoH behavior, certificate-pinned apps, and Global/Direct/Rule modes;
- verify exact allow/block domains, confirmed suffix blocking, domain matching, rule deletion, configuration persistence, and Android App bypass;
- verify remote anti-AD updates and the bundled MRS fallback while offline;
- verify blocked-event search/filtering, the 500-entry limit, long-domain rendering, manual clearing, redacted diagnostics, and confirmed raw JSONL export;
- confirm no user CA is installed;
- confirm release logcat does not contain blocked domains or package names;
- confirm VPN/core restart clears NoAd blocked-event memory;
- record the final commit, tag, signing certificate fingerprint, tested devices, Android versions, and result of every item before publishing the draft.
