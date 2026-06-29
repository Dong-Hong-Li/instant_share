#!/bin/sh
# 构建进程内动态库（c-shared），供 Flutter 通过 dart:ffi 调用。
#
# 用法：
#   ./build_lib.sh            # 自动检测当前系统 (macOS / Linux)
#   ./build_lib.sh macos      # macOS 通用库 (arm64 + x86_64)
#   ./build_lib.sh windows    # Windows amd64 DLL（macOS/Linux 需 mingw-w64 交叉编译）
#   ./build_lib.sh linux      # Linux amd64 .so
#
# 产物默认输出到 ../assets/<platform>/，由 pubspec assets 打包。
set -e

cd "$(dirname "$0")"

if [ -n "${1:-}" ]; then
  PLATFORM="$1"
else
  case "$(uname -s)" in
    Darwin) PLATFORM="macos" ;;
    Linux) PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *) PLATFORM="macos" ;;
  esac
fi

PKG="./cmd/lib"

case "$PLATFORM" in
  macos)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/libinstantshare.dylib"
    mkdir -p "$OUT_DIR"
    TMP="$(mktemp -d)"

    echo "[build_lib] macOS arm64 ..."
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
      go build -buildmode=c-shared -o "$TMP/arm64.dylib" "$PKG"

    echo "[build_lib] macOS amd64 ..."
    CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
      go build -buildmode=c-shared -o "$TMP/amd64.dylib" "$PKG"

    echo "[build_lib] lipo -> universal ..."
    lipo -create -output "$OUT" "$TMP/arm64.dylib" "$TMP/amd64.dylib"

    # ad-hoc 签名，便于本地 Debug 运行（沙盒/Gatekeeper）。
    if command -v codesign >/dev/null 2>&1; then
      codesign --force --sign - "$OUT" || true
    fi

    rm -rf "$TMP"
    echo "[build_lib] done -> $OUT"
    lipo -info "$OUT"
    ;;

  windows)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/instantshare.dll"
    mkdir -p "$OUT_DIR"

    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
      MINGW_CC="x86_64-w64-mingw32-gcc"
    elif command -v x86_64-w64-mingw32-gcc-14 >/dev/null 2>&1; then
      MINGW_CC="x86_64-w64-mingw32-gcc-14"
    else
      UNAME_S=$(uname -s)
      case "$UNAME_S" in
        MINGW*|MSYS*|CYGWIN*) MINGW_CC="gcc" ;;
        *)
          echo "[build_lib] 未找到 mingw 交叉编译器。" >&2
          echo "  macOS: brew install mingw-w64" >&2
          echo "  或在 Windows 上执行: build_lib.bat" >&2
          exit 1
          ;;
      esac
    fi

    echo "[build_lib] Windows amd64 ($MINGW_CC) ..."
    CGO_ENABLED=1 CC="$MINGW_CC" GOOS=windows GOARCH=amd64 \
      go build -buildmode=c-shared -o "$OUT" "$PKG"

    rm -f "$OUT_DIR/instantshare.h"
    echo "[build_lib] done -> $OUT"
    ;;

  linux)
    OUT_DIR="../assets/lib"
    OUT="$OUT_DIR/libinstantshare.so"
    mkdir -p "$OUT_DIR"

    echo "[build_lib] Linux amd64 ..."
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
      go build -buildmode=c-shared -o "$OUT" "$PKG"

    rm -f "$OUT_DIR/libinstantshare.h"
    echo "[build_lib] done -> $OUT"
    ;;
  #
  # TODO(android): 用 NDK 工具链分别构建 arm64-v8a/armeabi-v7a/x86_64 .so，
  #   放入 android/app/src/main/jniLibs/<abi>/libinstantshare.so
  #   (或改用 gomobile bind 生成 .aar)。
  #
  # TODO(ios): 改用 c-archive 生成 .a 静态库并链接进 Runner：
  #   CGO_ENABLED=1 GOOS=ios GOARCH=arm64 \
  #     go build -buildmode=c-archive -o libinstantshare.a ./cmd/lib

  *)
    echo "暂未实现平台: $PLATFORM（见脚本内 TODO）" >&2
    exit 1
    ;;
esac
