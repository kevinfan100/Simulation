# Flux Controller Simulation

**Version:** 3.0
**Last Updated:** 2025-01-26
**MATLAB Version:** R2025b
**Project Type:** Research

---

## 📘 專案概述

Flux Controller Simulation Framework 是一個用於磁通控制器研究與開發的 MATLAB/Simulink 專案。專案實作了三種控制器（PI、Type3、R），提供完整的模擬環境、測試腳本與頻率分析工具。

**主要功能：**
- 三種磁通控制器實作（PI, Type3, R Controller）
- Simulink 閉迴路系統模擬
- 批次測試與頻率掃描
- 自動化結果分析與視覺化

**使用者：** 個人研究用途

---

## 🛠️ 技術棧

```yaml
語言與工具:
  - MATLAB R2025b
  - Simulink
  - Git (版本控制)
  - GitHub (遠端倉庫)
  - VSCode + Claude Code (開發環境)

主要套件:
  - Simulink Control Design (如有使用)
  - Signal Processing Toolbox (如有使用)
```

---

## 📁 專案結構

```
Simulation/
├── controllers/           # 控制器實作（依類型分類）
│   ├── pi_controller/     # PI 控制器模型與函數
│   ├── type3/             # Type3 控制器模型與函數
│   └── r_controller/      # R 控制器模型與函數
│
├── scripts/               # 測試與分析腳本
│   ├── common/            # 共用工具（跨控制器）
│   ├── pi_controller/     # PI 專用測試腳本
│   ├── type3/             # Type3 專用測試腳本
│   └── r_controller/      # R 專用測試腳本
│
├── test_results/          # 測試輸出（依控制器分類）
│   ├── pi_controller/
│   ├── type3/
│   └── r_controller/
│
├── reference/             # 參考文件與實作
│   ├── Flux_Control_B_oldmodel_merged.pdf   # Type3 參考
│   ├── Flux_Control_R_newmodel.pdf          # R Controller 參考
│   └── generate_simulink_framework.m        # 框架生成器
│
├── r_controller_package/  # R Controller 獨立套件（歷史保留）
│
├── CLAUDE.md              # 本文件（專案規範與 Claude Code 工作指南）
└── GIT_WORKFLOW.md        # Git 分支管理指南
```

---

## 🎯 核心原則（必須遵守）

### 1. 檔案組織原則
**規則：** 控制器相關檔案必須放在對應目錄
**路徑：**
- 控制器實作 → `controllers/{controller_type}/`
- 測試腳本 → `scripts/{controller_type}/`
- 測試結果 → `test_results/{controller_type}/`

**為什麼：** 確保專案結構清晰，方便管理和查找

---

### 2. 版本控制原則
**規則：** 不得 commit 編譯檔、快取、測試結果
**禁止 commit：**
- 編譯檔：`*.slxc`, `*.mexw64`
- 快取：`slprj/`
- 測試結果：`test_results/`（除非特別需要）
- 備份檔：`*.asv`, `*.original`, `*.backup`

**為什麼：** 保持 Git 倉庫乾淨，避免追蹤自動生成的檔案

---

### 3. 分支使用原則
**規則：** 控制器開發在專用分支進行
**分支對應：**
- PI Controller → `controller/pi`
- R Controller → `controller/r`
- Type3 Controller → `develop` 或建立 `controller/type3`
- 共用工具修改 → `develop`

**為什麼：** 隔離不同控制器的開發，避免互相干擾

---

### 4. 路徑管理原則
**規則：** 使用相對路徑，確保跨環境相容
**標準模式：**
```matlab
% 取得腳本目錄
script_dir = fileparts(mfilename('fullpath'));
% 導航至專案根目錄
project_root = fullfile(script_dir, '..', '..');
% 建立模型路徑
model_path = fullfile(project_root, 'controllers', 'type3', 'model.slx');
```

**為什麼：** 確保專案可在不同電腦或目錄下執行

---

### 5. 模型命名原則
**規則：** Simulink 模型遵循固定命名格式
**格式：**
- 完整系統：`{controller_type}_system_integrated.slx`
- 控制器子系統：`{controller_type}_controller.slx`

**範例：**
- `type3_system_integrated.slx`
- `r_controller_system_integrated.slx`
- `pi_controller.slx`

**為什麼：** 確保檔案命名一致且易於辨識

---

### 6. 提交訊息原則
**規則：** 使用有意義的 commit 訊息
**格式：** `<type>(<scope>): <subject>`

**Type 類型：**
- `feat`: 新功能
- `fix`: 修復 bug
- `refactor`: 重構
- `test`: 測試相關
- `docs`: 文件更新
- `chore`: 維護性工作

**範例：**
```bash
feat(pi): Add batch frequency sweep test
fix(r): Fix preview buffer overflow
refactor(common): Improve model inspection
docs: Update CLAUDE.md with new rules
```

**為什麼：** 清楚記錄變更歷史，方便追蹤和回溯

---

### 7. 測試驗證原則
**規則：** 重大變更前必須測試
**測試要求：**
- 新增功能 → 必須測試
- 修改控制器 → 必須驗證輸出
- 修改測試腳本 → 必須執行確認
- 小修改（註解、文件） → 可彈性處理

**為什麼：** 確保程式碼品質，避免引入錯誤

---

### 8. 功能完成原則 ⭐
**規則：** 只有功能完整、測試通過後才能 commit
**要求：**
- ❌ 不允許 commit 半成品
- ❌ 不允許 commit 未測試的程式碼
- ✅ 功能必須完整且可執行
- ✅ 測試必須通過才能 commit

**Claude Code 詢問時機：**
1. 完成功能開發後
2. 準備 commit 前

**為什麼：** 確保每次 commit 都是穩定可用的狀態

---

### 9. 命名規範原則
**規則：** 所有檔案必須遵守命名規則
**適用範圍：**
- Simulink 模型：`{controller_type}_*.slx`
- 控制器函數：`{controller_type}_controller_function.m`
- 測試腳本：見下方「命名規範」章節

**為什麼：** 統一命名風格，方便識別和管理

---

### 10. 測試必要性原則 ⭐
**規則：** 任何功能變更都必須測試
**測試流程：**
1. 完成程式碼修改
2. 執行測試腳本
3. 驗證結果正確
4. Claude Code 確認測試狀態
5. 通過後才能 commit

**為什麼：** 測試是保證程式碼品質的唯一方法

---

## 🤖 Claude Code 工作規範

### ⚠️ 最高優先級：完整討論原則

**在執行任何操作前，Claude Code 必須：**

1. ✅ **完整理解需求**
   - 確認使用者想要達成什麼
   - 釐清模糊或不確定的部分
   - 理解功能的目的和使用情境

2. ✅ **詳細討論**
   - 提出實作方案供討論
   - 說明可能的選擇和利弊
   - 確認技術細節和參數

3. ✅ **確認所有細節**
   - 檔案命名
   - 功能範圍
   - 測試方式
   - 預期結果

4. ✅ **獲得明確許可**
   - 等待使用者回覆「可以開始」或類似確認
   - 不假設、不猜測、不自作主張

**例外情況：**
- 使用者明確說「按照 Claude Code 的判斷自己執行」
- 使用者說「可以開始了」或「開始操作」

**禁止行為：**
- ❌ 假設使用者需求
- ❌ 在討論不完整時開始執行
- ❌ 先做再說
- ❌ 自作主張修改程式碼或建立檔案

---

### 🔍 Commit 前檢查流程

**時機 1：完成功能開發後**
```
Claude Code: 我已完成 [功能描述]。

請執行以下測試：
1. [測試步驟 1]
2. [測試步驟 2]

預期結果：
- [預期輸出 1]
- [預期輸出 2]

❓ 測試完成了嗎？測試結果是否符合預期？
```

**時機 2：準備 commit 前**
```
Claude Code: 準備提交以下變更：

修改的檔案：
- scripts/pi_controller/run_batch_frequency_sweep.m
- controllers/pi_controller/PI_Controller_Integrated.slx

功能說明：
[簡述變更內容]

✅ 確認清單：
□ 功能完整
□ 測試通過
□ 命名符合規範
□ 路徑使用相對路徑

❓ 測試通過了嗎？可以 commit 嗎？
```

---

### 📝 產生腳本的規範

#### A. 臨時測試腳本（用完刪除）

**命名格式：** `temp_{purpose}_{description}.m`

**範例：**
```
temp_test_pi_frequency.m
temp_debug_buffer_overflow.m
temp_verify_eigenvalue.m
```

**使用規則：**
- 必須標註 `temp_` 前綴
- Claude Code 建立時在聊天室說明用途
- 使用完成後立即刪除
- **不允許 commit 到 Git**

**刪除時機：**
- 測試完成後
- 問題解決後
- 當天工作結束前

---

#### B. 正式功能腳本（保留使用）

**命名格式：** `{controller}_{function}.m`

**範例：**
```
pi_batch_frequency_sweep.m
r_preview_buffer_test.m
type3_eigenvalue_analysis.m
```

**使用規則：**
- 功能必須完整且連續
- 必須經過測試驗證
- Claude Code 在聊天室說明（見下方格式）

**文件規則：**
- ❌ 不為單一腳本建立 .md 說明文件
- ✅ 如需文件，統一整理到一個 .md
- ✅ 優先在聊天室說明，不額外建立檔案

---

#### C. Claude Code 說明腳本的標準格式

當產生正式腳本時，必須在聊天室提供以下說明：

```markdown
## 📄 新增腳本：{腳本名稱}.m

### 功能描述
[簡短描述腳本的功能和目的]

### 使用方法
```matlab
% 在 MATLAB 命令列執行
cd scripts/{controller_type}/
{腳本名稱}
```

### 輸入參數
[如果有參數需要設定，列出參數說明]
- 參數 1: [說明]
- 參數 2: [說明]

### 預期結果
- 輸出檔案：[路徑和檔名]
- 視覺化：[生成的圖表]
- 數據分析：[計算的指標]

### 注意事項
- [重要提醒 1]
- [重要提醒 2]
- 預估執行時間：[時間]
```

**範例：**
```markdown
## 📄 新增腳本：pi_batch_frequency_sweep.m

### 功能描述
批次執行 PI 控制器的頻率掃描測試，範圍 0.1Hz - 10kHz

### 使用方法
```matlab
cd scripts/pi_controller/
pi_batch_frequency_sweep
```

### 輸入參數
無需手動設定，腳本內已配置預設參數

### 預期結果
- 生成 Bode plot：test_results/pi_controller/bode_20250126.png
- 匯出數據：test_results/pi_controller/frequency_data.mat
- 顯示相位裕度和增益裕度

### 注意事項
- 執行時間約 5 分鐘
- 確保 PI_Controller_Integrated.slx 已關閉
- 會自動建立時間戳記資料夾
```

---

## 📐 命名規範

### 1. Simulink 模型

| 類型 | 格式 | 範例 |
|------|------|------|
| 完整系統 | `{controller}_system_integrated.slx` | `type3_system_integrated.slx` |
| 控制器子系統 | `{controller}_controller.slx` | `r_controller_d2.slx` |

### 2. MATLAB 函數

| 類型 | 格式 | 範例 |
|------|------|------|
| 控制器函數 | `{controller}_controller_function.m` | `type3_controller_function.m` |
| 測試腳本 | `run_{controller}_test.m` | `run_pi_controller_test.m` |
| 功能腳本 | `{controller}_{function}.m` | `pi_batch_frequency_sweep.m` |
| 臨時腳本 | `temp_{purpose}_{desc}.m` | `temp_test_eigenvalue.m` |
| 共用工具 | `{verb}_{purpose}.m` | `configure_sine_wave.m` |

### 3. 測試結果目錄

**格式：** `{Channel}_{SignalType}_{Params}_{timestamp}/`

**範例：**
```
P5_Sine_500H_20250126_120000/
P3_Step_0.1V_20250126_130000/
P1_Sweep_1to1000H_20250126_140000/
```

---

## 🔄 Git 工作流程

### 分支策略

```
master          # 穩定發布版本
├── develop     # 整合開發分支
│   ├── controller/pi    # PI 控制器開發
│   └── controller/r     # R 控制器開發
```

### 基本操作

#### 1. 開發 PI Controller
```bash
git checkout controller/pi
git pull origin controller/pi
# 修改程式碼並測試
git add .
git commit -m "feat(pi): Add new feature"
git push origin controller/pi
```

#### 2. 開發 R Controller
```bash
git checkout controller/r
git pull origin controller/r
# 修改程式碼並測試
git add .
git commit -m "feat(r): Add new feature"
git push origin controller/r
```

#### 3. 修改共用工具
```bash
git checkout develop
git pull origin develop
# 修改 scripts/common/ 檔案
git add .
git commit -m "refactor(common): Improve utility"
git push origin develop
```

### VSCode 操作重點

**切換分支：**
- 點擊左下角分支名稱
- 選擇目標分支

**推送變更：**
- 點擊左下角 ⟳ 同步按鈕
- 或使用 Source Control 面板的 Push 按鈕

**重要：本地分支切換後，推送會自動對應到同名遠端分支**
```
本地 controller/pi → 推送到 origin/controller/pi
本地 controller/r  → 推送到 origin/controller/r
```

詳細操作請參考 [GIT_WORKFLOW.md](GIT_WORKFLOW.md)

---

## 🚀 快速參考

### 修改 PI Controller

```bash
# 1. 切換分支
git checkout controller/pi

# 2. 修改檔案
# 編輯 scripts/pi_controller/*.m 或 controllers/pi_controller/*.slx

# 3. 測試
# 在 MATLAB 執行測試腳本

# 4. Commit
git add .
git commit -m "feat(pi): [描述]"
git push origin controller/pi
```

### 修改 R Controller

```bash
# 1. 切換分支
git checkout controller/r

# 2. 修改檔案
# 編輯 scripts/r_controller/*.m 或 controllers/r_controller/*.slx

# 3. 測試
# 在 MATLAB 執行測試腳本

# 4. Commit
git add .
git commit -m "feat(r): [描述]"
git push origin controller/r
```

### 執行測試

**PI Controller：**
```matlab
cd scripts/pi_controller/
run_pi_controller_test
```

**R Controller：**
```matlab
cd scripts/r_controller/
run_rcontroller_test
```

**Type3 Controller：**
```matlab
cd scripts/type3/
run_type3_test
```

### Commit 檢查清單

在 commit 前確認：
- [ ] 功能完整且可執行
- [ ] 測試通過
- [ ] 使用相對路徑（無hardcode路徑）
- [ ] 檔案命名符合規範
- [ ] commit 訊息清楚描述變更
- [ ] 無臨時檔案或快取檔案

---

## 📚 重要架構決策

### 為什麼分三個控制器目錄？
**決策：** 每個控制器類型獨立目錄
**原因：** 不同控制器有不同的演算法、參數和測試需求，分開管理避免混淆

### 為什麼測試腳本與控制器分離？
**決策：** 控制器在 `controllers/`，測試在 `scripts/`
**原因：**
- 控制器是核心演算法（較少變動）
- 測試腳本是驗證工具（經常調整）
- 分離便於管理和版本控制

### 為什麼使用相對路徑？
**決策：** 所有路徑使用 `fileparts(mfilename('fullpath'))` 解析
**原因：** 確保專案可在不同電腦、不同目錄下執行，提高可移植性

### 為什麼保留 r_controller_package？
**決策：** 保留完整的 R Controller 套件目錄
**原因：**
- 包含完整的歷史測試結果
- 有獨立的參考文件
- 可能需要比對新舊實作

### 為什麼使用分支策略？
**決策：** 不同控制器使用不同分支開發
**原因：**
- 隔離不同控制器的開發進度
- 避免互相干擾
- 方便追蹤各控制器的演進

---

## 📖 參考資源

### 重要文件

| 文件 | 用途 |
|------|------|
| [CLAUDE.md](CLAUDE.md) | 本文件 - 專案規範與 Claude Code 指南 |
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | Git 分支管理詳細說明 |
| [reference/README.md](reference/README.md) | 參考實作文件 |

### 技術參考

| 控制器 | 參考文件 |
|--------|---------|
| Type3 | `reference/Flux_Control_B_oldmodel_merged.pdf` |
| R Controller | `reference/Flux_Control_R_newmodel.pdf` |
| 系統識別 | `reference/Model_6_6_Continuous_Weighted.m` |

### 外部資源

- [MATLAB 官方文件](https://www.mathworks.com/help/matlab/)
- [Simulink 官方文件](https://www.mathworks.com/help/simulink/)
- [Git 官方文件](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## ⚠️ 特別注意事項

1. **永不修改 `scripts/common/`** 用於控制器特定需求 - 共用工具必須保持通用性
2. **永遠測試路徑解析** 修改腳本位置後 - 確保相對路徑仍然正確
3. **永遠使用有意義的 commit 訊息** - 遵循 Conventional Commits 格式
4. **永不 commit Simulink 快取** - `.gitignore` 已設定，但仍需注意
5. **永遠在 commit 前檢查 git status** - 確認沒有意外追蹤不該追蹤的檔案
6. **臨時腳本用完必須刪除** - 保持專案乾淨整潔

---

## 🔧 /init 指令執行結果

**專案狀態：**
- ✅ 專案結構完整
- ✅ 三個控制器實作就緒（PI, Type3, R）
- ✅ Git 倉庫已初始化
- ✅ GitHub 遠端已設定
- ✅ 分支策略已建立

**當前分支：** master

**重要提醒：**
- 開發 PI Controller → 切換到 `controller/pi`
- 開發 R Controller → 切換到 `controller/r`
- 修改共用工具 → 使用 `develop`
- Commit 前務必測試完成

---

**Last Review:** 2025-01-26
**Maintained by:** Project Owner
**Version:** 3.0
- 記得在到我的需求後或是在開一個新的對話後，要先完整的檢視一次專案的進度情況以及了解simulink 中模型的情況