# Git 分支管理與工作流程

## 📊 專案分支列表

### 已同步到 GitHub 的分支

| 分支名稱 | 用途 | 說明 |
|---------|------|------|
| `master` | 主分支 | 穩定的發布版本，所有功能都經過測試 |
| `develop` | 開發整合分支 | 整合各控制器的開發，修改共用工具時使用 |
| `controller/pi` | PI 控制器專用 | PI 控制器的所有開發與測試 |
| `controller/r` | R 控制器專用 | R 控制器的所有開發與測試 |

### 本地備份分支（未推送到 GitHub）

| 分支名稱 | 用途 | 說明 |
|---------|------|------|
| `refactor-backup-20251016` | 舊版本備份 | 2024/10/16 的程式碼快照，可視需要保留或刪除 |

---

## 🎯 分支使用指南

### 1. `master` 分支
- **用途**：正式發布版本
- **何時使用**：
  - ❌ 不要直接在 master 開發
  - ✅ 從其他分支合併穩定版本
  - ✅ 打版本標籤（例如：v1.0.0）

### 2. `develop` 分支
- **用途**：整合開發與測試
- **何時使用**：
  - 修改共用工具（`scripts/common/`）
  - 修改框架程式碼（`reference/`）
  - 整合測試多個控制器的變更
  - 修改專案文件

### 3. `controller/pi` 分支
- **用途**：PI 控制器開發
- **負責檔案**：
  - `controllers/pi_controller/` - PI 控制器模型與函數
  - `scripts/pi_controller/` - PI 測試腳本
  - `test_results/pi_controller/` - PI 測試結果
- **何時使用**：任何與 PI 控制器相關的修改

### 4. `controller/r` 分支
- **用途**：R 控制器開發
- **負責檔案**：
  - `controllers/r_controller/` - R 控制器模型與函數
  - `scripts/r_controller/` - R 測試腳本
  - `r_controller_package/` - R 控制器套件
  - `test_results/r_controller/` - R 測試結果
- **何時使用**：任何與 R 控制器相關的修改

---

## 🔄 基本工作流程

### 情境 1：開發 PI 控制器功能

```bash
# 1. 切換到 controller/pi 分支
git checkout controller/pi

# 2. 拉取最新版本
git pull origin controller/pi

# 3. 修改檔案並測試
# 例如：編輯 scripts/pi_controller/run_pi_controller_test.m

# 4. 查看變更
git status

# 5. 提交變更
git add scripts/pi_controller/run_pi_controller_test.m
git commit -m "feat(pi): Add new test case for 10Hz sine wave"

# 6. 推送到 GitHub
git push origin controller/pi
```

### 情境 2：開發 R 控制器功能

```bash
# 1. 切換到 controller/r 分支
git checkout controller/r

# 2. 拉取最新版本
git pull origin controller/r

# 3. 修改檔案並測試
# 例如：編輯 controllers/r_controller/r_controller_function_p1_d2.m

# 4. 提交變更
git add controllers/r_controller/
git commit -m "feat(r): Optimize preview buffer for d=2"

# 5. 推送到 GitHub
git push origin controller/r
```

### 情境 3：修改共用工具或框架

```bash
# 1. 切換到 develop 分支
git checkout develop

# 2. 拉取最新版本
git pull origin develop

# 3. 修改共用檔案
# 例如：編輯 scripts/common/inspect_simulink_model.m

# 4. 提交變更
git add scripts/common/
git commit -m "refactor(common): Improve model inspection output"

# 5. 推送到 GitHub
git push origin develop

# 6. (可選) 同步到各控制器分支
git checkout controller/pi
git merge develop
git push origin controller/pi

git checkout controller/r
git merge develop
git push origin controller/r
```

---

## 🚀 整合與發布流程

### 將控制器分支整合到 develop

```bash
# 1. 切換到 develop 分支
git checkout develop
git pull origin develop

# 2. 合併控制器分支
git merge controller/pi
# 或
git merge controller/r

# 3. 解決衝突（如果有）
# 編輯衝突檔案後：
git add <衝突檔案>
git commit

# 4. 推送到 GitHub
git push origin develop
```

### 發布穩定版本到 master

```bash
# 1. 確保 develop 已經過完整測試
git checkout master
git pull origin master

# 2. 合併 develop
git merge develop

# 3. 打版本標籤
git tag -a v1.0.0 -m "Release v1.0.0: PI and R controllers stable release"

# 4. 推送到 GitHub（包含標籤）
git push origin master --tags
```

---

## 💻 在 VSCode 中使用 Git

### 切換分支

1. **方法 1：使用左下角分支按鈕**
   - 點擊 VSCode 左下角的分支名稱（例如：`master`）
   - 從下拉選單選擇要切換的分支（例如：`controller/pi`）
   - VSCode 會自動切換分支

2. **方法 2：使用命令面板**
   - 按 `Ctrl+Shift+P` (Windows) 或 `Cmd+Shift+P` (Mac)
   - 輸入 `Git: Checkout to...`
   - 選擇目標分支

### 推送到 GitHub

**重要：本地分支切換後，推送會對應到相同名稱的遠端分支**

例如：
```
本地分支：controller/pi  →  推送到  →  origin/controller/pi
本地分支：controller/r   →  推送到  →  origin/controller/r
本地分支：develop        →  推送到  →  origin/develop
```

### VSCode 推送方法

1. **方法 1：使用 Source Control 面板**
   - 點擊左側的 Source Control 圖示
   - 輸入 commit 訊息
   - 點擊 ✓ 提交
   - 點擊 `...` → `Push`

2. **方法 2：使用同步按鈕**
   - 提交後，點擊左下角的 ↻ 同步按鈕
   - VSCode 會自動推送到對應的遠端分支

3. **方法 3：使用命令面板**
   - `Ctrl+Shift+P` → `Git: Push`

### ⚠️ 重要提醒

**Q: 在 VSCode 切換分支後，推送會到對應的遠端分支嗎？**

**A: 是的！** 例如：

```
# 當前在 controller/pi 分支
git branch
* controller/pi    ← 當前分支

# 修改檔案並提交
git add .
git commit -m "feat(pi): Update test"

# 推送（會推送到 origin/controller/pi）
git push

# 等同於
git push origin controller/pi
```

**確認方法：**
- VSCode 左下角會顯示當前分支名稱
- 推送前會顯示 `Push to origin/當前分支名稱`
- 可以在終端機執行 `git branch` 確認當前分支（有 `*` 的是當前分支）

---

## 📋 常用 Git 命令速查表

### 分支操作

```bash
# 查看所有分支
git branch -a

# 查看當前分支
git branch

# 切換分支
git checkout controller/pi

# 建立並切換到新分支
git checkout -b feature/new-feature

# 刪除本地分支
git branch -d 分支名稱

# 刪除遠端分支
git push origin --delete 分支名稱
```

### 日常操作

```bash
# 查看狀態
git status

# 查看變更
git diff

# 暫存檔案
git add 檔案名稱
git add .  # 暫存所有變更

# 提交
git commit -m "commit 訊息"

# 推送到 GitHub
git push origin 分支名稱

# 拉取最新版本
git pull origin 分支名稱

# 查看提交歷史
git log --oneline --graph
```

### 合併與衝突

```bash
# 合併其他分支到當前分支
git merge 來源分支

# 如果有衝突，編輯衝突檔案後：
git add 衝突檔案
git commit

# 取消合併
git merge --abort
```

### 暫存變更

```bash
# 暫存當前變更（切換分支前）
git stash

# 查看暫存列表
git stash list

# 恢復暫存
git stash pop

# 清除暫存
git stash clear
```

---

## 🎨 提交訊息規範

使用 Conventional Commits 格式：

```
<type>(<scope>): <subject>

<body>
```

### Type 類型

- `feat`: 新功能
- `fix`: 修復 bug
- `refactor`: 重構（不改變功能）
- `docs`: 文件變更
- `test`: 測試相關
- `chore`: 維護性任務

### Scope 範圍

- `pi`: PI 控制器
- `r`: R 控制器
- `type3`: Type3 控制器
- `common`: 共用工具
- `framework`: 框架程式碼

### 範例

```bash
# PI 控制器新功能
git commit -m "feat(pi): Add batch frequency sweep from 0.1Hz to 10kHz"

# R 控制器 bug 修復
git commit -m "fix(r): Fix preview buffer overflow in d=2 mode"

# 共用工具重構
git commit -m "refactor(common): Improve Simulink model inspection output"

# 文件更新
git commit -m "docs: Update README with installation instructions"
```

---

## 🔧 分支管理建議

### 分支命名規範

如果需要建立臨時功能分支：

```
feature/<controller>-<description>   # 新功能
fix/<controller>-<description>       # Bug 修復
refactor/<area>-<description>        # 重構
test/<description>                   # 測試

範例：
feature/pi-bode-analysis
fix/r-buffer-overflow
refactor/common-test-framework
```

### 分支清理

```bash
# 刪除已合併的本地分支
git branch -d feature/pi-bode-analysis

# 強制刪除未合併的分支
git branch -D feature/old-experiment

# 刪除遠端分支
git push origin --delete feature/pi-bode-analysis

# 清理本地不存在的遠端分支參考
git fetch --prune
```

---

## 📚 延伸資源

- [Git 官方文件](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [VSCode Git 教學](https://code.visualstudio.com/docs/sourcecontrol/overview)

---

**專案 GitHub 位置：** https://github.com/kevinfan100/Simulation

**最後更新：** 2025-01-26