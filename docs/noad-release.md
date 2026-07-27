# NoAd Android Release Checklist

NoAd v1 is Android-first. Local workstation setup and real-device validation are intentionally separated from repository changes because they require installed SDKs, devices, and credentials.

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

The tag workflow builds Android APKs and publishes:

- `NoAd-<version>-android-arm64-v8a.apk`
- `NoAd-<version>-android-armeabi-v7a.apk`
- `NoAd-<version>-android-x86_64.apk`
- `SHA256SUMS`
- `NoAd-<version>-source.tar.gz`, a GPL corresponding-source archive that includes checked-out submodules.

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
- install the APK on a real Android device;
- verify known ad-domain blocking, normal HTTPS, Fake-IP, QUIC, app DoH behavior, Wi-Fi/cellular switching, background resume, certificate-pinned apps, App bypass, and Global/Direct/Rule modes;
- confirm no user CA is installed;
- confirm release logcat does not contain blocked domains or package names;
- confirm VPN/core restart clears NoAd blocked-event memory.