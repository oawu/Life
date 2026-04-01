# iOS Archive

將 build version +1，重新產生 xcodeproj，打包 archive 供 TestFlight 上傳。

## 參數

- 預設打包 **Beta**
- 可指定 `prod` 打包 **Prod**

## 步驟

1. 讀取 `ios/project.yml` 中的 `CURRENT_PROJECT_VERSION`
2. 將版本號 +1，寫回 `ios/project.yml`
3. 執行 `cd /Users/oa/Workspace/32_Life/ios && xcodegen generate`
4. 根據環境決定 scheme 與 configuration：
   - Beta：`-scheme "Life Beta" -configuration Beta`
   - Prod：`-scheme "Life Prod" -configuration Prod`
5. 執行 archive：
   ```bash
   cd /Users/oa/Workspace/32_Life/ios && xcodebuild archive \
     -project Life.xcodeproj \
     -scheme "<scheme>" \
     -configuration <config> \
     -destination "generic/platform=iOS" \
     -archivePath ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/"Life <env> $(date '+%Y-%-m-%-d, %-I.%M %p').xcarchive" \
     CODE_SIGN_STYLE=Automatic
   ```
6. 完成後告知版本號與 archive 路徑，提醒用戶到 Xcode Organizer 上傳

## 注意事項

- 不要 commit 版本號變更（用戶會自行決定何時 commit）
- archive 檔名使用時間戳格式，避免覆蓋舊 archive
- 只顯示 xcodebuild 最後 5 行輸出（確認成功或失敗即可）
