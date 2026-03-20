# 部署 prod + beta

將 main 分支同步推送至 prod 和 beta 分支，觸發 CI/CD 部署。

## 步驟

1. 確認當前在 `main` 分支，若不在則中止並提醒
2. 依序執行以下指令（每一步都要確認成功才繼續）：

```bash
git push origin main

git branch -D prod
git checkout -b prod
git push origin prod --force
git checkout main

git branch -D beta
git checkout -b beta
git push origin beta --force
git checkout main
```

3. 完成後顯示推送結果

## 注意事項

- 執行前必須確認在 main 分支上
- 這是 force push，會覆蓋遠端 prod 和 beta 分支
- 若本地不存在 prod 或 beta 分支，跳過 `branch -D` 直接建立
