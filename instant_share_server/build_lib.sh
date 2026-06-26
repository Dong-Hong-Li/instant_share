#!/bin/sh
# 构建进程内动态库（c-shared），供 Flutter 通过 dart:ffi 调用。
#
# 用法：
#   ./build_lib.sh            # 默认构建当前桌面平台
#   ./build_lib.sh macos      # macOS 通用库 (arm64 + x86_64)
#
# 产物默认输出到 ../assets/<platform>/，由 pubspec assets 打包。
set -e

cd "$(dirname "$0")"

PLATFORM="${1:-macos}"
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

  # TODO(windows): GOOS=windows GOARCH=amd64 -> assets/lib/instantshare.dll
  #   需在 Windows 或带 mingw 交叉工具链的环境执行：
  #   CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc GOOS=windows GOARCH=amd64 \
  #     go build -buildmode=c-shared -o ../assets/lib/instantshare.dll ./cmd/lib
  #
  # TODO(linux): CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
  #     go build -buildmode=c-shared -o ../assets/lib/libinstantshare.so ./cmd/lib
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
