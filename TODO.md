# Flux Controller Development TODO

**Last Updated**: 2025-10-13
**Project**: Magnetic Levitation System - Flux Controller Implementation

---

## 📋 目錄

1. [專案概述](#專案概述)
2. [進度總覽](#進度總覽)
3. [主腳本架構規劃](#主腳本架構規劃)
4. [詳細任務清單](#詳細任務清單)
5. [下一步行動](#下一步行動)

---

## 🎯 專案概述

### 目標
建立一個完整的磁通控制器模擬環境，包含：
- 參數化的控制器設計（支援 Type 1/2/3）
- 靈活的參考訊號生成（step, sin, 等）
- 自動化的 Simulink 模擬流程
- 標準化的結果分析與繪圖

### 核心檔案
- **主腳本**（計劃中）：`run_flux_controller_simulation.m`
- **系統框架**：`Control_System_Framework.slx`（包含 Plant）
- **控制器模型**：`Flux_Controller_Type3.slx`（可擴展至 Type 1/2）
- **參數計算**：`calculate_flux_controller_params.m`（已完成）

---

## ✅ 進度總覽

### 已完成
- ✅ **Task 1**: 理解 `calculate_flux_controller_params.m` 運作原理
  - 已分析函數邏輯和參數計算流程
  - 支援 Type 1/2/3 三種控制器類型

- ✅ **Task 2.1**: SECTION 1 (CONFIGURATION) 詳細規劃完成
  - 1.1 控制器類型選擇
  - 1.2 系統參數設定（手動輸入）
  - 1.3 控制器設計參數（lambda_c, lambda_e）
  - 1.4 參考訊號設定（step, sin）
  - 1.5 框架與控制器設定（已釐清架構）
  - 1.6 模擬參數（solver 設定）
  - 1.7 繪圖控制（多種圖表開關）
  - 1.8 結果儲存
  - 1.9 偵錯與驗證

- ✅ **系統架構理解**
  - 確認 `Control_System_Framework.slx` 已包含 Plant
  - 確認使用 Goto/From blocks 傳遞訊號
  - 確認使用 `setup_controller.m` 整合控制器（Model Reference）

### 進行中
- 🔄 **Task 2**: 主腳本 `run_flux_controller_simulation.m` 設計
  - SECTION 1: ✅ 已完成討論
  - SECTION 2-7: 📝 待討論細節

### 待辦
- ⏳ SECTION 2~7 詳細規劃
- ⏳ 輔助函數設計與實作
- ⏳ 繪圖模組設計與實作
- ⏳ 專案資料夾架構重整

---

## 🏗️ 主腳本架構規劃

### 檔案：`run_flux_controller_simulation.m`

```
run_flux_controller_simulation.m
│
├─ SECTION 1: CONFIGURATION              ✅ 已完成討論
│  ├─ 1.1 控制器類型選擇
│  ├─ 1.2 系統參數（a1, a2, B, Ts）
│  ├─ 1.3 設計參數（lambda_c, lambda_e）
│  ├─ 1.4 參考訊號設定（step/sin）
│  ├─ 1.5 框架與控制器設定
│  ├─ 1.6 模擬參數（solver）
│  ├─ 1.7 繪圖控制
│  ├─ 1.8 結果儲存
│  └─ 1.9 偵錯與驗證
│
├─ SECTION 2: PARAMETER CALCULATION      📝 待討論
│  └─ 呼叫 calculate_flux_controller_params()
│
├─ SECTION 3: REFERENCE SIGNAL GENERATION 📝 待討論
│  └─ 呼叫 generate_reference_signal() (新函數)
│
├─ SECTION 4: CONTROLLER INTEGRATION      📝 待討論
│  ├─ (可選) 更新框架：generate_simulink_framework()
│  └─ 整合控制器：setup_controller()
│
├─ SECTION 5: SIMULINK SIMULATION         📝 待討論
│  ├─ 設定 Vd 到框架
│  └─ 執行模擬：run_simulation()
│
├─ SECTION 6: RESULTS VISUALIZATION       📝 待討論
│  └─ 呼叫 visualize_flux_controller_results() (新函數)
│
└─ SECTION 7: RESULTS SAVING              📝 待討論
   └─ 儲存結果到 results/ 資料夾
```

---

## 📝 詳細任務清單

### Phase 1: 主腳本設計與討論

#### ✅ Task 1.1: SECTION 1 規劃（已完成）
**狀態**: 已完成
**日期**: 2025-10-13

**決策記錄**:
- 系統參數全部手動輸入（不從檔案自動載入）
- 支援 step 和 sin 兩種參考訊號
- 每個通道可獨立設定振幅、頻率、相位
- Plant 已內建在框架中，無需額外設定
- 模擬參數可手動調整
- 繪圖模組可選擇要繪製的通道

---

#### 📝 Task 1.2: SECTION 2 規劃（待討論）
**目的**: 計算控制器參數並寫入 workspace

**討論重點**:
1. 參數驗證的詳細邏輯
   - lambda 範圍檢查（0 < λ < 1）
   - Type 1 的 beta 檢查
   - 矩陣 B 可逆性檢查
   - 採樣時間合理性檢查

2. 錯誤處理策略
   - 參數不合法：終止（error）或警告（warning）？
   - 計算失敗時的處理方式

3. 輸出資訊
   - VERBOSE 模式下顯示哪些資訊？
   - 關鍵參數摘要格式

**依賴**:
- `calculate_flux_controller_params.m`（已存在）

---

#### 📝 Task 1.3: SECTION 3 規劃（待討論）
**目的**: 生成參考訊號 Vd

**需要建立新函數**: `generate_reference_signal.m`

**討論重點**:
1. 函數接口設計
   ```matlab
   function [Vd_ref, t_ref] = generate_reference_signal(signal_type, params, Ts, sim_time)
   % signal_type: 'step', 'sin'
   % params: 包含振幅、頻率、相位等
   % Ts: 採樣時間
   % sim_time: 模擬總時間
   ```

2. Step 訊號生成
   - 如何產生階躍訊號
   - 階躍開始時間如何實作
   - 6 個通道的獨立控制

3. Sin 訊號生成
   - 如何產生正弦波
   - 頻率、相位、振幅的處理
   - 多通道不同參數的實作

4. 訊號格式
   - 輸出格式：矩陣（N×6）還是 timeseries？
   - 如何設定到框架的 Vd block？

5. 通道啟用邏輯
   - `channel_enable` 如何實作
   - 禁用通道設為 0 還是保持 offset？

**輸出**:
- `Vd_ref`: 6×1 向量或 timeseries 物件
- `t_ref`: 時間向量（可選）

---

#### 📝 Task 1.4: SECTION 4 規劃（待討論）
**目的**: 將控制器整合到系統框架

**討論重點**:
1. 何時需要重新生成框架？
   - `UPDATE_PLANT` 選項的使用時機
   - 什麼情況下需要執行 `generate_simulink_framework()`

2. 控制器整合流程
   - 使用 `setup_controller()` 的細節
   - Model Reference 的參數傳遞
   - 如何驗證整合成功

3. 錯誤處理
   - 控制器模型不存在
   - 框架模型損壞
   - 連接失敗

**依賴**:
- `generate_simulink_framework.m`（已存在）
- `setup_controller.m`（已存在）

---

#### 📝 Task 1.5: SECTION 5 規劃（待討論）
**目的**: 執行 Simulink 模擬

**討論重點**:
1. Vd 訊號設定方式
   - 如何動態修改框架中的 Vd block？
   - 方案 A：修改 Constant block 的 Value 參數
   - 方案 B：改用 From Workspace block
   - 方案 C：使用 Signal Builder block

2. 模擬執行流程
   - 使用現有的 `run_simulation.m` 是否足夠？
   - 是否需要額外的模擬前檢查？

3. Solver 設定
   - 離散控制器是否需要特殊設定？
   - FixedStepDiscrete vs ode45 的選擇

4. 結果提取
   - 從 To Workspace blocks 讀取資料
   - 需要哪些訊號：u, e, Vm, Vm_analog, Vd

**依賴**:
- `run_simulation.m`（已存在，可能需要修改）

---

#### 📝 Task 1.6: SECTION 6 規劃（待討論）
**目的**: 繪製分析圖表

**需要建立新函數**: `visualize_flux_controller_results.m`

**討論重點**:
1. 函數接口設計
   ```matlab
   function fig_handles = visualize_flux_controller_results(sim_results, plot_options)
   % sim_results: 包含 t, u, e, Vm, Vd 等
   % plot_options: 控制繪圖行為的結構
   ```

2. 圖表類型實作
   - **時域響應圖**（Vm vs t, Vd vs t）
     - 6 個子圖或單一圖多條線？
     - 如何標示參考訊號和實際響應

   - **控制訊號圖**（u vs t）
     - 顯示控制飽和或限制
     - 計算控制能量

   - **追蹤誤差圖**（e vs t）
     - 誤差的時間演化
     - 顯示穩態誤差

   - **磁滯圖**（Vm vs u）
     - X軸：u，Y軸：Vm
     - 觀察磁滯現象
     - 多通道如何顯示？

   - **追蹤軌跡圖**（Vm vs Vd）
     - X軸：Vd，Y軸：Vm
     - 理想線（45度線）
     - 追蹤效果評估

   - **估測器狀態圖**（可選，如果控制器有輸出）
     - ŝ₁, ŝ₂, ŵT vs t

3. 繪圖參數
   - 通道選擇邏輯
   - 顏色、線寬、字體大小
   - 圖例、標籤、標題

4. 圖表儲存
   - 是否儲存為 .fig 或 .png？
   - 儲存路徑和檔名規則

**額外建議的圖表**:
- 控制能量統計（bar chart）
- 追蹤誤差統計（RMS, max, steady-state）
- 閉迴路波德圖（需要線性化，較複雜）

---

#### 📝 Task 1.7: SECTION 7 規劃（待討論）
**目的**: 儲存模擬結果

**討論重點**:
1. 儲存內容
   - 所有參數（system_params, design_params, etc.）
   - 模擬結果（sim_results）
   - 圖表（fig_handles）

2. 檔名規則
   - 自動生成：`Type3_lambda0p5_20251013_143052.mat`
   - 包含：控制器類型、關鍵參數、時間戳

3. 資料夾結構
   - `results/` 主資料夾
   - 是否按日期或類型分類？

4. 元資料
   - 記錄執行時間、MATLAB 版本、等

---

### Phase 2: 輔助函數實作

#### 📝 Task 2.1: 實作 `generate_reference_signal.m`
**優先級**: 高
**預計工作量**: 2-3 小時

**子任務**:
- [ ] 設計函數接口
- [ ] 實作 step 訊號生成
- [ ] 實作 sin 訊號生成
- [ ] 實作通道啟用邏輯
- [ ] 撰寫函數註釋和範例
- [ ] 測試各種參數組合

---

#### 📝 Task 2.2: 實作 `visualize_flux_controller_results.m`
**優先級**: 高
**預計工作量**: 4-6 小時

**子任務**:
- [ ] 設計函數接口
- [ ] 實作時域響應圖
- [ ] 實作控制訊號圖
- [ ] 實作追蹤誤差圖
- [ ] 實作磁滯圖
- [ ] 實作追蹤軌跡圖
- [ ] 實作通道選擇邏輯
- [ ] 撰寫函數註釋和範例
- [ ] 測試各種繪圖組合

---

#### 📝 Task 2.3: 修改/擴展 `run_simulation.m`（如需要）
**優先級**: 中
**預計工作量**: 1-2 小時

**可能需要的修改**:
- [ ] 增加 Vd 訊號設定功能
- [ ] 增加離散求解器支援
- [ ] 改善結果提取邏輯
- [ ] 增加更多驗證檢查

---

### Phase 3: 主腳本實作

#### 📝 Task 3.1: 實作主腳本 `run_flux_controller_simulation.m`
**優先級**: 高
**預計工作量**: 3-4 小時

**子任務**:
- [ ] 實作 SECTION 1（CONFIGURATION）
- [ ] 實作 SECTION 2（PARAMETER CALCULATION）
- [ ] 實作 SECTION 3（REFERENCE SIGNAL GENERATION）
- [ ] 實作 SECTION 4（CONTROLLER INTEGRATION）
- [ ] 實作 SECTION 5（SIMULINK SIMULATION）
- [ ] 實作 SECTION 6（RESULTS VISUALIZATION）
- [ ] 實作 SECTION 7（RESULTS SAVING）
- [ ] 整體測試與除錯

---

### Phase 4: 測試與驗證

#### 📝 Task 4.1: 功能測試
**優先級**: 高

**測試案例**:
- [ ] Type 3 控制器 + step 訊號
- [ ] Type 3 控制器 + sin 訊號（單頻）
- [ ] Type 3 控制器 + sin 訊號（多頻）
- [ ] 不同 lambda 值的性能對比
- [ ] 不同通道啟用組合

---

#### 📝 Task 4.2: 錯誤處理測試
**優先級**: 中

**測試案例**:
- [ ] 無效的 lambda 值
- [ ] 缺少必要參數
- [ ] 控制器模型不存在
- [ ] 框架損壞
- [ ] 模擬失敗

---

### Phase 5: 文件與整理

#### 📝 Task 5.1: 撰寫使用說明文檔
**優先級**: 中

**內容**:
- [ ] 快速開始指南
- [ ] 參數調整指南
- [ ] 範例展示
- [ ] 常見問題 FAQ
- [ ] 疑難排解

---

#### 📝 Task 5.2: 專案資料夾重整
**優先級**: 中

**目標結構**:
```
Openloop_Cali/
├── Control_System_Framework.slx
├── generate_simulink_framework.m
├── run_flux_controller_simulation.m    # 新增主腳本
│
├── controllers/
│   ├── Flux_Controller_Type1.slx       # 未來擴展
│   ├── Flux_Controller_Type2.slx       # 未來擴展
│   ├── Flux_Controller_Type3.slx       # 已存在
│   ├── create_flux_controller_type1.m
│   ├── create_flux_controller_type2.m
│   └── create_flux_controller_type3.m
│
├── scripts/
│   ├── design/
│   │   ├── calculate_flux_controller_params.m
│   │   └── analyze_plant_frequency.m
│   │
│   ├── simulation/                      # 新增資料夾
│   │   ├── generate_reference_signal.m # 新增函數
│   │   └── setup_simulink_params.m     # 未來擴展
│   │
│   ├── visualization/                   # 新增資料夾
│   │   └── visualize_flux_controller_results.m  # 新增函數
│   │
│   └── framework/
│       ├── setup_controller.m
│       ├── run_simulation.m
│       └── analyze_results.m
│
├── examples/
│   └── example_flux_controller_type3.m  # 保留為簡單範例
│
├── results/                             # 新增資料夾
│   └── .gitkeep
│
├── docs/
│   ├── A_DEVELOPMENT_RULES.md
│   ├── USER_GUIDE.md                    # 新增文檔
│   └── ARCHITECTURE.md                  # 新增文檔
│
└── TODO.md                              # 本文件
```

**子任務**:
- [ ] 建立新資料夾結構
- [ ] 移動現有檔案
- [ ] 更新檔案路徑參考
- [ ] 更新 .gitignore
- [ ] 測試所有路徑正確

---

#### 📝 Task 5.3: 更新開發規範文檔
**優先級**: 低

**更新內容**:
- [ ] 新增主腳本的開發規範
- [ ] 新增繪圖函數的規範
- [ ] 更新檔案命名規則
- [ ] 更新 Git commit 規則

---

### Phase 6: 擴展功能（未來）

#### 📝 Task 6.1: 支援 Type 1/2 控制器
**優先級**: 低
**狀態**: 未來擴展

**子任務**:
- [ ] 建立 `Flux_Controller_Type1.slx`
- [ ] 建立 `Flux_Controller_Type2.slx`
- [ ] 測試三種類型的切換
- [ ] 性能對比分析

---

#### 📝 Task 6.2: 增加更多參考訊號類型
**優先級**: 低
**狀態**: 未來擴展

**候選類型**:
- [ ] multisine（多頻疊加）
- [ ] chirp（掃頻訊號）
- [ ] square（方波）
- [ ] ramp（斜坡）
- [ ] custom（從檔案載入）

---

#### 📝 Task 6.3: 閉迴路頻率響應分析
**優先級**: 低
**狀態**: 未來擴展

**內容**:
- [ ] 系統線性化
- [ ] 閉迴路波德圖
- [ ] 穩定裕度分析
- [ ] 靈敏度函數

---

## 🚀 下一步行動

### 立即行動（本次討論）
1. ✅ 完成 SECTION 1 詳細規劃
2. 📝 **繼續討論 SECTION 2**（PARAMETER CALCULATION）
3. 📝 **繼續討論 SECTION 3**（REFERENCE SIGNAL GENERATION）
4. 📝 **繼續討論 SECTION 4-7**

### 短期目標（本週）
1. 完成所有 SECTION 的詳細規劃
2. 實作 `generate_reference_signal.m`
3. 開始實作主腳本的 SECTION 1-3

### 中期目標（下週）
1. 完成主腳本實作
2. 完成 `visualize_flux_controller_results.m`
3. 進行功能測試

### 長期目標
1. 完成文檔撰寫
2. 重整專案資料夾
3. 考慮擴展功能

---

## 📌 重要提醒

### 開發原則（參考 A_DEVELOPMENT_RULES.md）
- ❌ 禁止建立版本迭代檔案（*_v2.m, *_old.m）
- ❌ 禁止建立臨時測試檔案（test_*.m, check_*.m）
- ✅ 使用 Git 版本控制
- ✅ 函數檔案使用 `verb_noun.m` 命名
- ✅ 完整的函數註釋

### Commit 規則
- `feat`: 新功能
- `fix`: Bug 修復
- `refactor`: 重構
- `docs`: 文檔更新
- `test`: 測試相關

**範例**:
```bash
feat(simulation): add generate_reference_signal function
fix(controller): correct parameter validation logic
docs(todo): update development plan
```

---

## 📞 討論記錄

### 2025-10-13 - SECTION 1 規劃討論
**參與者**: 使用者 + Claude Code

**決策**:
1. 系統參數全部手動輸入
2. 優先實作 step 和 sin 訊號
3. Plant 已內建在框架中，無需額外設定
4. 所有繪圖模組可選擇要繪製的通道
5. 模擬時間可手動調整

**釐清疑問**:
- ✅ 1.5 Plant 模型設定：確認 Plant 已在框架中
- ✅ 1.6 模擬參數：解釋 solver 類型和步長
- ✅ 1.9 偵錯與驗證：解釋 VERBOSE 和 VALIDATE_PARAMS

**下一步**:
- 繼續討論 SECTION 2-7

---

**End of TODO.md**
