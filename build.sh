#!/bin/zsh
set -euo pipefail

PROJECT="PetTimeline.xcodeproj"
SCHEME="PetTimeline"

# 从 simctl 输出中解析设备 UUID
pick_uuid() {
  xcrun simctl list devices available \
    | rg -i "$1" \
    | rg -o '\(([0-9A-Fa-f-]{36})\)' \
    | tr -d '()' \
    | head -1
}

echo "🔍 查找可用的 iOS 模拟器..."

# 优先已启动的 iPhone，其次任意可用 iPhone，最后任意可用设备
SIM_UUID=$(xcrun simctl list devices booted | rg -i 'iPhone' | rg -o '\(([0-9A-Fa-f-]{36})\)' | tr -d '()' | head -1)

if [ -z "$SIM_UUID" ]; then
  SIM_UUID=$(pick_uuid 'iPhone')
fi

if [ -z "$SIM_UUID" ]; then
  SIM_UUID=$(xcrun simctl list devices available | rg -o '\(([0-9A-Fa-f-]{36})\)' | tr -d '()' | head -1)
fi

if [ -z "$SIM_UUID" ]; then
  echo "❌ 未找到可用的模拟器" >&2
  exit 1
fi

echo "📱 使用模拟器：$SIM_UUID"
DESTINATION="platform=iOS Simulator,id=$SIM_UUID"

echo "🔨 开始编译..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -quiet

echo "✅ 编译成功！"
