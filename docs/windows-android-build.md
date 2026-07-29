# Windows Android 本地构建指南

本文记录 NoAd 在 Windows 11 上配置 Flutter/FVM、Android Studio、Go、Android SDK/NDK 并生成 Android APK 的已验证流程，同时汇总首次构建中遇到的问题。

## 1. 固定版本

项目版本以 `.fvmrc`、CI 和 `.agents/project.md` 为准：

| 工具 | 版本 |
| --- | --- |
| Flutter | 3.44.4 |
| Dart | Flutter 3.44.4 内置的 3.12.2 |
| FVM | 4.1.2（已验证版本） |
| Go | 1.26.4 |
| JDK | 21 |
| Android SDK Platform | 36 |
| Android Build Tools | 36.0.0 |
| Android NDK | 28.2.13676358（r28c） |

不要使用系统中旧的 Flutter、Go、Java 或 Unity 自带 Android SDK。即使依赖下载成功，Go core 或 Gradle 任务仍可能在后期失败。

## 2. 当前 Windows 环境示例

下列路径是本项目已验证的本机配置。其他机器可以替换根目录，但版本必须保持一致。

| 用途 | 路径 |
| --- | --- |
| 项目根目录 | `D:\MyGit\NoAd` |
| FVM Flutter SDK | `D:\MyGit\NoAd\.fvm\flutter_sdk` |
| FVM 全局 Flutter 3.44.4 | `%USERPROFILE%\fvm\versions\3.44.4` |
| 项目 Pub cache | `D:\MyGit\NoAd\.pub-cache` |
| Android SDK | `D:\tmp\toolchains\android-sdk` |
| Android NDK | `D:\tmp\toolchains\android-sdk\ndk\28.2.13676358` |
| Android Studio JDK | `C:\Program Files\Android\Android Studio\jbr` |
| Go | `C:\Program Files\Go` |

`.fvm/`、`.pub-cache/`、构建输出和 `android/local.properties` 均为本机状态，不应提交到 Git。

## 3. Flutter 与 FVM

项目通过 `.fvmrc` 固定 Flutter 3.44.4。完成安装后应满足：

```powershell
cd D:\MyGit\NoAd
fvm --version
fvm flutter --version
```

预期版本：

```text
FVM 4.1.2
Flutter 3.44.4
Dart 3.12.2
```

如果使用项目级 Pub cache 安装 FVM：

```powershell
$env:PUB_CACHE = 'D:\MyGit\NoAd\.pub-cache'
dart pub global activate fvm
```

然后将以下目录加入 Windows 用户 `PATH`，并重新打开 PowerShell：

```text
C:\Users\<用户名>\fvm\versions\3.44.4\bin
D:\MyGit\NoAd\.pub-cache\bin
```

执行 `fvm use 3.44.4` 前必须开启 Windows 开发者模式，否则 FVM 无法创建 `.fvm/flutter_sdk` 符号链接。

## 4. Windows 开发者模式

Flutter 项目的插件依赖会创建符号链接。未开启开发者模式时，`flutter pub get` 或 FVM 可能显示：

```text
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

可以直接打开对应设置页：

```powershell
Start-Process 'ms-settings:developers'
```

开启“开发人员模式/开发者模式”并确认系统提示。可以只读检查其状态：

```powershell
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
(Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
```

输出 `1` 表示已启用。不要通过来源不明的脚本修改该系统安全设置。

## 5. Android Studio

1. 在 Android Studio 的 `Plugins > Marketplace` 中安装 `Flutter` 插件，并接受同时安装 `Dart` 插件。
2. 重启 Android Studio。
3. 使用 `Open` 打开项目根目录 `D:\MyGit\NoAd`，不要只打开 `android/` 子目录。
4. 进入 `File > Settings > Languages & Frameworks > Flutter`。
5. 将 `Flutter SDK path` 设置为 `D:\MyGit\NoAd\.fvm\flutter_sdk`，不要追加 `bin`。

命令行配置 Android SDK 和 JDK：

```powershell
flutter config `
  --android-sdk 'D:\tmp\toolchains\android-sdk' `
  --jdk-dir 'C:\Program Files\Android\Android Studio\jbr'
```

如果 `flutter doctor` 错误地选择了 Unity 自带 SDK，重新执行上述 `flutter config --android-sdk`。

Android 许可证必须由开发者本人确认：

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

所有许可提示确认后，`Android toolchain` 应显示 `[√]`。

## 6. Go 与 Android NDK

确认 Go 版本和实际可执行文件：

```powershell
where.exe go
go version
go env GOROOT
```

预期：

```text
C:\Program Files\Go\bin\go.exe
go version go1.26.4 windows/amd64
C:\Program Files\Go
```

Android Go core 使用 CGO，因此 `ANDROID_NDK` 必须指向 r28c：

```powershell
$env:ANDROID_NDK = 'D:\tmp\toolchains\android-sdk\ndk\28.2.13676358'
```

可以将该值保存为 Windows 用户环境变量，但新打开的 Android Studio 和 PowerShell 才会读取更新后的值。

## 7. 推荐构建命令

新开 PowerShell 后执行以下完整配置块。显式设置路径可以避免旧 Java、Unity SDK 或其他 Flutter SDK 干扰构建。

```powershell
cd D:\MyGit\NoAd

$flutterBin = Join-Path $env:USERPROFILE 'fvm\versions\3.44.4\bin'
$env:Path = "$flutterBin;D:\MyGit\NoAd\.pub-cache\bin;C:\Program Files\Go\bin;C:\Program Files\Android\Android Studio\jbr\bin;$env:Path"
$env:PUB_CACHE = 'D:\MyGit\NoAd\.pub-cache'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = 'D:\tmp\toolchains\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_NDK = 'D:\tmp\toolchains\android-sdk\ndk\28.2.13676358'

git submodule update --init --recursive
fvm flutter pub get
dart setup.dart android --env stable -v
```

`setup.dart` 会自动激活项目使用的 `flutter_distributor`。首次激活期间脚本使用 `Process.run` 缓冲输出，可能数分钟没有新日志。需要单独观察激活进度时，可以先执行：

```powershell
dart pub global activate -s git `
  https://github.com/chen08209/flutter_distributor.git `
  --git-ref FlClash `
  --git-path packages/flutter_distributor
```

然后再次运行 `dart setup.dart android --env stable -v`。

## 8. 构建产物与签名

成功后，按 ABI 拆分的 APK 位于：

```text
D:\MyGit\NoAd\dist\*.apk
```

检查产物：

```powershell
Get-ChildItem -LiteralPath 'D:\MyGit\NoAd\dist' -Filter '*.apk' |
  Select-Object Name, Length, LastWriteTime
```

正式发布签名需要：

- `android/app/keystore.jks`
- `android/local.properties` 中的 `keyAlias`
- `storePassword`
- `keyPassword`

这些密钥和密码不得提交。缺少完整签名配置时，当前 Gradle 配置会回退到 debug 签名，并为 application ID 添加 `.dev`。正式发布流程和 GitHub Secrets 见 `docs/noad-release.md`。

## 9. 常见错误

### `fvm` 不是可识别的命令

原因：FVM 未安装，或 Pub cache 的 `bin` 未加入 `PATH`。

```powershell
$env:PUB_CACHE = 'D:\MyGit\NoAd\.pub-cache'
dart pub global activate fvm
$env:Path = "D:\MyGit\NoAd\.pub-cache\bin;$env:Path"
fvm --version
```

### Flutter 使用了错误的 Android SDK

症状：`flutter doctor` 显示 Unity 目录或缺少 Android SDK 36。

```powershell
flutter config --android-sdk 'D:\tmp\toolchains\android-sdk'
flutter doctor -v
```

### Android 许可证未接受

症状：

```text
Some Android licenses not accepted.
```

处理：

```powershell
flutter doctor --android-licenses
```

### `:setup:buildGoCore` 出现 `HCS_E_SERVICE_NOT_AVAILABLE`

旧构建钩子在 Windows 上无条件调用 `bash run_build_tool.sh`，可能命中 `C:\Windows\System32\bash.exe`（WSL 启动器）。WSL 服务不可用时会看到：

```text
Bash/Service/CreateInstance/CreateVm/HCS/HCS_E_SERVICE_NOT_AVAILABLE
Execution failed for task ':setup:buildGoCore'.
```

项目现已修复：

- Windows 使用 `plugins/setup/buildkit/run_build_tool.cmd`。
- macOS/Linux 继续使用 `bash run_build_tool.sh`。
- Windows 启动器保留 Gradle 传入的 `PROJECT_DIR`。

可以只验证 Go core 构建钩子：

```powershell
cd D:\MyGit\NoAd\android
$env:FLUTTER_ROOT = "$env:USERPROFILE\fvm\versions\3.44.4"
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;C:\Program Files\Go\bin;$env:Path"
$env:ANDROID_NDK = 'D:\tmp\toolchains\android-sdk\ndk\28.2.13676358'
.\gradlew.bat :setup:buildGoCore '-Ptarget-platform=android-arm64' --no-daemon
```

### KGP 和 Gradle deprecated 警告

以下内容目前不是本次失败原因：

```text
Future versions of Flutter will fail if plugins apply Kotlin Gradle Plugin.
Deprecated Gradle features were used in this build.
```

它们表示未来升级 Flutter/Gradle 前需要更新相关插件，但当前 Flutter 3.44.4 构建可以继续。排错时优先查找第一处 `FAILURE`、`What went wrong` 和具体失败任务。

### 日志很长但只有一个错误

Flutter `-v` 和 Gradle `--stacktrace` 会重复打印同一异常。提交问题时保留：

1. 第一处 `FAILURE: Build failed with an exception.`
2. 第一处 `What went wrong:`。
3. 失败任务，例如 `:setup:buildGoCore`。
4. 失败任务之前约 30 行日志。

末尾数百行 Java/Dart 调用栈通常不是新的错误。

## 10. 最终检查清单

```powershell
fvm --version
fvm flutter --version
go version
flutter doctor -v
Test-Path $env:ANDROID_NDK
git submodule status
git status --short
```

开始打包前确认：

- Flutter 为 3.44.4。
- Go 为 1.26.4。
- JDK 为 Android Studio JBR 21。
- `flutter doctor` 的 Android toolchain 通过。
- Windows 开发者模式已开启。
- `ANDROID_NDK` 指向 28.2.13676358。
- submodules 已初始化。
- 正式发布时已配置签名；本地测试包可以使用 debug 签名回退。
