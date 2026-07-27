<div>

[**简体中文**](README_zh_CN.md)

</div>

## NoAd

NoAd is an Android-first ad-blocking client based on [FLClash](https://github.com/chen08209/FlClash) and Mihomo. It keeps FLClash's VPN/TUN architecture and adds a NoAd rule layer for blocking known advertising and tracking domains without root access.

## Scope

- Android first release.
- Package ID: `com.follow.clash.noad`.
- Deep link: `noad://install-config`.
- Blocks known ad/tracking domains through Mihomo rule providers.
- Does not install a CA certificate and does not decrypt HTTPS.
- HTTPS blocked-event records show only domain, target IP/port, network type, source app, UID, and matched NoAd rule metadata.
- Does not promise complete removal of first-party, native, server-side inserted, or same-domain ads.

## Features

- Built-in anti-AD Mihomo MRS fallback snapshot.
- Remote rule source: `https://anti-ad.net/mihomo.mrs`, updated by Mihomo provider interval/manual update.
- NoAd rules are injected after profile/script/custom overrides and before user routing rules.
- Global, Direct, and Rule modes all keep NoAd blocking active by using rule mode internally with a final `MATCH,GLOBAL`, `MATCH,DIRECT`, or original user rules.
- Exact-domain allowlist, exact-domain blocklist, confirmed suffix blocking, and Android app bypass.
- In-memory 500-entry blocked-event log cleared on core/VPN shutdown.
- Diagnostics export with hashes, and user-confirmed raw JSONL export through the system file picker.
- Firebase Analytics/Crashlytics remain default-off and require explicit user opt-in.

## Build

1. Update submodules:

   ```bash
   git submodule update --init --recursive
   ```

2. Install the required toolchain:

   - Flutter 3.44.4
   - Go 1.26.4
   - JDK 21
   - Android SDK platform 36
   - Android Build Tools 36.0.0
   - Android NDK 28.2.13676358 / r28c

3. Verify the repository:

   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   dart run intl_utils:generate
   flutter analyze --no-fatal-infos
   flutter test --reporter expanded
   ```

4. Run Go core tests:

   ```bash
   cd core
   go test .
   ```

5. Build Android APKs:

   ```bash
   dart setup.dart android --env stable -v
   ```

## Release and validation

Release details, required GitHub Secrets, SHA256/source package expectations, and external real-device validation items are documented in [docs/noad-release.md](docs/noad-release.md).

Privacy boundaries are documented in [docs/noad-privacy-and-security.md](docs/noad-privacy-and-security.md). License notes are documented in [docs/noad-licenses.md](docs/noad-licenses.md).

## License and attribution

NoAd is a modified build based on FLClash and is distributed under GPL-3.0. The bundled anti-AD fallback rule snapshot is covered by anti-AD's MIT license notice in `assets/data/noad/ANTI_AD_LICENSE.txt`.