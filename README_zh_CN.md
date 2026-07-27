<div>

[**English**](README.md)

</div>

## NoAd

NoAd 是一个基于 [FLClash](https://github.com/chen08209/FlClash) 与 Mihomo 的 Android 首版去广告客户端。它保留 FLClash 的 VPN/TUN 架构，在规则层加入 NoAd 广告与追踪域名拦截能力，无需 Root。

## 范围

- 首版面向 Android。
- 包名：`com.follow.clash.noad`。
- 深链：`noad://install-config`。
- 通过 Mihomo rule provider 拦截已知广告与追踪域名。
- 不安装 CA 证书，不解密 HTTPS。
- HTTPS 拦截记录只展示域名、目标 IP/端口、网络类型、来源 App、UID 和命中的 NoAd 规则元数据。
- 不承诺完全消除第一方、原生、服务端插入或同域广告。

## 功能

- 内置 anti-AD Mihomo MRS 离线兜底快照。
- 远程规则源：`https://anti-ad.net/mihomo.mrs`，由 Mihomo provider 周期/手动更新。
- NoAd 规则在订阅、脚本和自定义覆写之后注入，并位于用户分流规则之前。
- Global、Direct、Rule 三种逻辑模式都会保持 NoAd 拦截：内部使用规则模式，并以 `MATCH,GLOBAL`、`MATCH,DIRECT` 或用户原始规则收尾。
- 支持精确域名放行、精确域名阻断、二次确认的后缀阻断，以及 Android App 绕过。
- 500 条内存拦截日志，Core/VPN 关闭时清空。
- 脱敏诊断导出和用户确认后的原始 JSONL 导出，均通过系统文件选择器在本机生成。
- Firebase Analytics/Crashlytics 默认关闭，只有用户明确开启才收集。

## 构建

1. 更新 submodules：

   ```bash
   git submodule update --init --recursive
   ```

2. 安装工具链：

   - Flutter 3.44.4
   - Go 1.26.4
   - JDK 21
   - Android SDK platform 36
   - Android Build Tools 36.0.0
   - Android NDK 28.2.13676358 / r28c

3. 验证仓库：

   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   dart run intl_utils:generate
   flutter analyze --no-fatal-infos
   flutter test --reporter expanded
   ```

4. 运行 Go core 测试：

   ```bash
   cd core
   go test .
   ```

5. 构建 Android APK：

   ```bash
   dart setup.dart android --env stable -v
   ```

## 发布与验证

Release 流程、GitHub Secrets、SHA256/源码包要求，以及需要真机或凭据的外部验收项见 [docs/noad-release.md](docs/noad-release.md)。

隐私边界见 [docs/noad-privacy-and-security.md](docs/noad-privacy-and-security.md)。许可说明见 [docs/noad-licenses.md](docs/noad-licenses.md)。

## 许可与来源

NoAd 是基于 FLClash 的修改版本，按 GPL-3.0 分发。内置 anti-AD 兜底规则快照遵守 anti-AD 的 MIT 许可，许可文本位于 `assets/data/noad/ANTI_AD_LICENSE.txt`。