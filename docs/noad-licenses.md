# NoAd License Notes

NoAd is a modified Android-focused client based on FLClash. The repository keeps the GPL-3.0 license in `LICENSE`, and distributed object-code releases must provide the corresponding source code under GPL-3.0 terms.

## Upstream attribution

- Upstream project: FLClash.
- Core: Mihomo / Clash.Meta, included through the existing `core/Clash.Meta` submodule.
- Product modifications: Android package ID `com.follow.clash.noad`, NoAd branding, NoAd ad-blocking configuration injection, in-memory blocked-event UI, and release/privacy documentation.

## anti-AD rules

NoAd bundles an offline fallback snapshot from anti-AD for Mihomo MRS rules and updates from:

```text
https://anti-ad.net/mihomo.mrs
```

The anti-AD license notice is bundled at:

```text
assets/data/noad/ANTI_AD_LICENSE.txt
```

The fallback snapshot is used only when the remote provider has not been downloaded yet or when a manual update needs to side-load the last known local rule set after a remote update failure.

## Corresponding source package

GitHub Releases must include a source archive generated after submodules are checked out. The source archive should exclude build caches and generated local build outputs, but include the source tree, build scripts, assets, and checked-out submodule contents needed to rebuild the released APKs.