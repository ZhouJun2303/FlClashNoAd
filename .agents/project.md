# Project Context

NoAd is an Android-first ad-blocking client based on FlClash and ClashMeta (mihomo), built with Flutter. The source tree retains the upstream Windows, macOS, and Linux implementations, while the NoAd release workflow currently targets Android.

## Version Notes

- `.fvmrc` pins Flutter 3.44.4 for local development.
- CI and the Android release workflow use Flutter 3.44.4.
- Android release builds use Go 1.26.4, JDK 21, Android SDK platform 36, Android Build Tools 36.0.0, and Android NDK 28.2.13676358 (r28c).
- Dart SDK constraint: `>=3.8.0 <4.0.0`.

## Build Dependencies

Linux:

```bash
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev
```

Windows:

- GCC and Inno Setup.
- `ANDROID_NDK` env var for Android builds.

macOS:

```bash
npm install -g appdmg
```
