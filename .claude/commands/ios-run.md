# iOS 模擬器 Build & Run

Build iOS App 並安裝到 iPhone 16 Pro 模擬器。

## 步驟

1. 確保模擬器已啟動
2. xcodegen 產生專案
3. xcodebuild build
4. 安裝並啟動 App

```bash
xcrun simctl boot "iPhone 16 Pro" 2>/dev/null; cd /Users/oa/Workspace/32_Life/ios && xcodegen && xcodebuild -project Life.xcodeproj -scheme "Life Dev" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/LifeBuild -quiet build && xcrun simctl install "iPhone 16 Pro" "/tmp/LifeBuild/Build/Products/Local-iphonesimulator/Life β.app" && xcrun simctl launch "iPhone 16 Pro" tw.iwi.life.beta && open -a Simulator
```
