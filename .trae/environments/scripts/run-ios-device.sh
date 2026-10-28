#!/bin/bash
set -euo pipefail

# 更新安装会保留 App 数据；设备名可通过 WOYOUSHA_DEVICE 指定。
device_name="${WOYOUSHA_DEVICE:-OGS17}"
build_dir="${TMPDIR:-/tmp}/woyousha-device-build"
build_log="${build_dir}/build.log"
mkdir -p "$build_dir"

xcrun devicectl device info details --device "$device_name" --timeout 20 >/dev/null
echo "正在编译 iPhone 版本…"
xcodebuild -project woyousha/woyousha.xcodeproj -scheme woyousha \
    -configuration Debug -destination 'generic/platform=iOS' \
    -derivedDataPath "$build_dir/DerivedData" \
    build >"$build_log" 2>&1 || {
        tail -n 70 "$build_log"
        exit 1
    }

xcrun devicectl device install app --device "$device_name" \
    "$build_dir/DerivedData/Build/Products/Debug-iphoneos/woyousha.app" --timeout 60
xcrun devicectl device process launch --device "$device_name" \
    --activate com.OGS.woyousha --timeout 20
xcrun devicectl device info processes --device "$device_name" --search woyousha --timeout 20
