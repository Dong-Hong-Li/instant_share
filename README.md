# Instant Share（即时分享）

Flutter 客户端 + 内嵌 Go 服务的局域网文件分享应用。支持 **macOS / Windows / Linux / Android** 桌面与移动端。

## 架构

Go 服务（HTTP + WebSocket）以 **c-shared 动态库**形式被 Flutter 通过 `dart:ffi` **进程内**拉起。

- 桌面端：默认监听 `localhost:8080`
- Android：服务同样进程内运行，分享链接通过 Kotlin 读取局域网 IP 生成

上层通过统一接口访问分享服务，不关心库的具体加载方式。

- Go 源码：`instant_share_server/`
- 进程内运行时（FFI）：`lib/infrastructure/share_server/embedded_server_runtime.dart`
- 库加载：`lib/infrastructure/share_server/embedded_server_library_locator.dart`
- 服务探测：`lib/infrastructure/share_server/share_server_discovery.dart`

## 环境要求

| 工具 | 说明 |
|---|---|
| Flutter SDK | `>=3.9.0` |
| Go | `>=1.25`，构建内嵌库时需 `CGO_ENABLED=1` |
| macOS | Xcode、Command Line Tools |
| Windows | Go + MinGW/gcc（或 macOS 上 `brew install mingw-w64` 交叉编译 DLL） |
| Android | Android NDK（`ANDROID_NDK_HOME` 或 Android Studio 自带 SDK） |

## 本地开发与运行

### macOS

```bash
cd instant_share_server && ./build_lib.sh macos
cd .. && flutter pub get && flutter run -d macos
```

### Windows

在 Windows 上构建 DLL（需 Go + MinGW/gcc）：

```bat
cd instant_share_server
build_lib.bat
cd ..
flutter pub get
flutter run -d windows
```

或在 macOS/Linux 交叉编译：

```bash
cd instant_share_server && ./build_lib.sh windows
cd .. && flutter pub get && flutter run -d windows
```

产物：`assets/lib/instantshare.dll`（CMake 会拷贝到 exe 同目录）

### Linux

```bash
cd instant_share_server && ./build_lib.sh linux
cd .. && flutter pub get && flutter run -d linux
```

Release 打包时需手动将 `assets/lib/libinstantshare.so` 拷贝进 bundle，详见 [docs/打包.md](docs/打包.md)。

### Android

需先安装 NDK，再构建三 ABI 的 `.so`：

```bash
cd instant_share_server && ./build_lib.sh android
cd .. && flutter pub get && flutter run -d android
```

产物位于 `android/app/src/main/jniLibs/<abi>/libinstantshare.so`。

> 改动了 Go 代码后，重新执行对应平台的 `build_lib` 再运行/打包。Flutter 热重载不会重新编译 Go 库。

## GitHub Actions 发版

CI workflow：`.github/workflows/build-desktop.yml`（**Build Release**）

Tag 格式：`v{version}-{platform}`。同一版本的各平台 tag 会汇总到同一个 GitHub Release（`v{version}`）。

```bash
VERSION=1.0.0
for p in windows macos linux android; do
  git tag "v${VERSION}-$p"
done
git push origin v${VERSION}-windows v${VERSION}-macos v${VERSION}-linux v${VERSION}-android
```

| 平台 | Tag 示例 | CI 产物 |
|---|---|---|
| Windows | `v1.0.0-windows` | `instant_share-windows-x64-v1.0.0.zip` |
| macOS | `v1.0.0-macos` | `instant_share-macos-v1.0.0.zip` |
| Linux | `v1.0.0-linux` | `instant_share-linux-x64-v1.0.0.tar.gz` |
| Android | `v1.0.0-android` | `instant_share-android-v1.0.0.zip`（含三 ABI APK） |

注意：

- workflow 必须在 **main** 分支上，push tag 才会触发 CI
- `git tag` 一次只创建一个 tag，不要用空格拼接多个 tag 名
- 手动调试：Actions → **Build Release** → Run workflow → 选 platform

完整打包说明见 [docs/打包.md](docs/打包.md)。

## 调试技巧

- 临时指定库路径：环境变量 `INSTANT_SHARE_SERVER_LIB` 指向库文件的绝对路径
- 单独跑独立二进制（历史的子进程方案，仍保留）：

```bash
cd instant_share_server
go run ./cmd/server -port 8080
```

## 跨平台状态

| 平台 | 构建命令 | 产物 | 状态 |
|---|---|---|---|
| macOS | `./build_lib.sh macos` | `libinstantshare.dylib` | 已完成 |
| Windows | `build_lib.bat` 或 `./build_lib.sh windows` | `instantshare.dll` | 已完成 |
| Linux | `./build_lib.sh linux` | `libinstantshare.so` | 已完成 |
| Android | `./build_lib.sh android` | `jniLibs/<abi>/libinstantshare.so` | 已完成 |
| iOS | — | `libinstantshare.a` (c-archive) | TODO |

构建脚本：`instant_share_server/build_lib.sh` / `build_lib.bat`
