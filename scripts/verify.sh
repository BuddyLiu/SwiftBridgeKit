#!/usr/bin/env bash
#
# SwiftBridgeKit 验证脚本：在 iOS 模拟器上编译包并跑全部单测。
#
# 为什么必须用模拟器：
#   本包 imports UIKit，macOS 宿主上没有 UIKit，
#   直接 `swift build` 会报 `no such module 'UIKit'`（这是预期，不是包的错）。
#   SPM 包的 iOS 目标只能通过 xcodebuild + 模拟器来构建与测试。
#
# 用法：
#   ./scripts/verify.sh                 # 自动挑一台能真正启动的模拟器
#   SIM_ID=<设备UUID> ./scripts/verify.sh  # 显式指定模拟器
#
set -euo pipefail
cd "$(dirname "$0")/../SwiftBridgeKit"

# 挑一台「能真正启动」的 iPhone 模拟器：逐个试 boot，跳过数据损坏/缺失的设备。
pick_sim() {
    local id
    for id in $(xcrun simctl list devices available | awk -F'[()]' '/iPhone/{print $2}'); do
        if xcrun simctl bootstatus "$id" -b >/dev/null 2>&1; then
            echo "$id"
            return 0
        fi
    done
    return 1
}

SIM_ID="${SIM_ID:-}"
if [ -z "$SIM_ID" ]; then
    SIM_ID="$(pick_sim || true)"
fi
if [ -z "$SIM_ID" ]; then
    echo "error: 没有可启动的 iPhone 模拟器（可先用 SIM_ID=xxx 显式指定）" >&2
    exit 1
fi

echo "▶ 使用模拟器: $SIM_ID"

echo "▶ [1/2] SwiftBridgeKit 核心包测试"
xcodebuild \
    -scheme SwiftBridgeKit \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    test

echo
echo "▶ [2/2] SwiftBridgeComponents 组件包测试"
cd ../SwiftBridgeComponents
xcodebuild \
    -scheme SwiftBridgeComponents \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    test