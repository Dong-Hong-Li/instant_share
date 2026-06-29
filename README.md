# Instant Share（即时分享）

Flutter 客户端 + 内嵌 Go 服务的局域网文件分享应用。

## 架构

Go 服务（HTTP + WebSocket）以 **c-shared 动态库**形式被 Flutter 通过 `dart:ffi` **进程内**拉起，监听 `localhost`。上层只认 `localhost:8080` 接口，不关心服务是库还是进程。

- Go 源码：`instant_share_server/`
- 进程内运行时（FFI）：`lib/infrastructure/share_server/embedded_server_runtime.dart`
- 服务探测：`lib/infrastructure/share_server/share_server_discovery.dart`

## 环境要求

- Flutter SDK `>=3.9.0`
- Go `>=1.25`（构建内嵌库时需要，且 `CGO_ENABLED=1`）
- Windows 构建 DLL 还需：MinGW-w64（Windows 自带 `gcc`，或 macOS 上 `brew install mingw-w64` 交叉编译）

## 操作步骤

### macOS

1. 构建内嵌库：

```bash
cd instant_share_server
./build_lib.sh macos
```

2. 运行 App：

```bash
flutter pub get
flutter run -d macos
```

### Windows

1. 构建内嵌库（在 Windows 上，需已安装 Go + MinGW/gcc）：

```bat
cd instant_share_server
build_lib.bat
```

或在 macOS/Linux 交叉编译（需 `brew install mingw-w64`）：

```bash
cd instant_share_server
./build_lib.sh windows
```

产物：`assets/lib/instantshare.dll`

2. 运行 App：

```bat
flutter pub get
flutter run -d windows
```

CMake 会把 `instantshare.dll` 拷贝到 exe 同目录，App 启动时自动 `StartServer` / 退出时 `StopServer`。

> 改动了 Go 代码后，重新执行第 1 步再运行即可。

## 调试技巧

- 临时指定库路径：环境变量 `INSTANT_SHARE_SERVER_LIB` 指向库文件的绝对路径。
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
| Linux | `./build_lib.sh linux` | `libinstantshare.so` | 脚本就绪 |
| Android | — | `libinstantshare.so` | TODO |
| iOS | — | `libinstantshare.a` (c-archive) | TODO |

构建脚本：`instant_share_server/build_lib.sh` / `build_lib.bat`  
加载逻辑：`lib/infrastructure/share_server/embedded_server_library_locator.dart`
