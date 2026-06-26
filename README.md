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

## 操作步骤（macOS）

1. 构建内嵌库（产物输出到 `assets/lib/libinstantshare.dylib`）：

```bash
cd instant_share_server
./build_lib.sh macos
```

2. 回到项目根目录运行 App：

```bash
flutter pub get
flutter run -d macos
```

App 启动时自动通过 FFI 调用 `StartServer` 拉起服务，退出时调用 `StopServer` 关闭。

> 改动了 Go 代码后，重新执行第 1 步再运行即可。

## 调试技巧

- 临时指定库路径（跳过 bundle 打包）：设置环境变量 `INSTANT_SHARE_SERVER_LIB=/绝对路径/libinstantshare.dylib`。
- 单独跑独立二进制（历史的子进程方案，仍保留）：

```bash
cd instant_share_server
go run ./cmd/server -port 8080
```

## 跨平台扩展（TODO）

进程内方案对各平台通用，只需补对应库的构建与加载（已在代码中埋好 TODO）：

| 平台 | 构建模式 | 产物 | 落地位置 |
|---|---|---|---|
| macOS | `c-shared` | `libinstantshare.dylib` | `assets/lib/`（已完成） |
| Windows | `c-shared` | `instantshare.dll` | `assets/lib/` |
| Linux | `c-shared` | `libinstantshare.so` | `assets/lib/` |
| Android | `c-shared` | `libinstantshare.so` | `android/app/src/main/jniLibs/<abi>/` |
| iOS | `c-archive` | `libinstantshare.a` | 静态链接进 Runner |

构建命令模板见 `instant_share_server/build_lib.sh`，加载逻辑见 `embedded_server_library_locator.dart`。
