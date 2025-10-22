# R Controller 測試套件

基於 Flux_Control_R_newmodel.pdf 實作的 R Controller 自動化測試工具。

---

## 📁 檔案結構

```
r_controller_package/
├── model/                      # 控制器模型與函數
│   ├── r_controller_system_integrated.slx
│   ├── r_controller_function_p1_d2.m    (PDF Page 1 版本)
│   └── r_controller_function_p2_d2.m    (PDF Page 2 版本)
├── test_script/                # 測試腳本
│   └── run_rcontroller_test.m
├── test_results/               # 測試結果輸出目錄
├── reference/                  # 參考文件
│   └── Flux_Control_R_newmodel.pdf
└── README.md                   # 本文件
```

---

## 🚀 快速開始

### 1. 環境需求

- MATLAB R2020a 或更新版本
- Simulink
- Control System Toolbox

### 2. 運行測試

1. 在 MATLAB 中進入 `test_script/` 目錄
2. 執行測試腳本：
   ```matlab
   run_rcontroller_test
   ```

---

## ⚙️ 配置說明

打開 `test_script/run_rcontroller_test.m`，在 **SECTION 1: 配置區域** 修改參數：

### 基本設定

```matlab
test_name = 'r_controller_test';    % 測試名稱
signal_type_name = 'sine';          % 信號類型: 'sine' 或 'step'
Channel = 4;                        % 激發通道 (1-6)
Amplitude = 0.5;                    % 振幅 [V]
```

### Sine 模式參數

```matlab
Frequency = 100;                    % 頻率 [Hz]
Phase = 0;                          % 相位 [deg]
sine_display_cycles = 5;            % 顯示最後 N 個週期
```

### Step 模式參數

```matlab
StepTime = 0.01;                    % Step 跳變時間 [s]
step_simulation_time = 0.5;         % 總模擬時間 [s]
```

### 輸出控制

```matlab
ENABLE_PLOT = true;                 % 顯示圖表
SAVE_PNG = true;                    % 保存圖片
SAVE_MAT = true;                    % 保存數據
```

---

## 📊 輸出結果

測試結果保存在 `test_results/{test_name}_{timestamp}/`：

### Sine 模式輸出

- `Vm_Vd.png` - Vm vs Vd
- `6ch_time_response.png` - 6 通道時域響應
- `full_response.png` - 完整系統響應
- `w1_hat_estimation.png` - 估測值 ŵ₁
- `result.mat` - 完整測試數據

### Step 模式輸出

- `step_response_6ch.png` - 6 通道階躍響應
- `error_analysis.png` - 誤差分析
- `control_input.png` - 控制輸入
- `result.mat` - 完整測試數據

---

## 📖 控制器版本說明

此套件包含兩個控制器版本（d=2 預覽）：

### Page 1 版本 (`r_controller_function_p1_d2.m`)


### Page 2 版本 (`r_controller_function_p2_d2.m`)


**預設使用：** 模型中預設使用 **Page  1 版本**



---

## 📝 測試範例

### 範例 1: 100 Hz 正弦波測試（P4 通道）

```matlab
signal_type_name = 'sine';
Channel = 4;
Amplitude = 0.5;
Frequency = 100;
```

### 範例 2: 階躍響應測試（P1 通道）

```matlab
signal_type_name = 'step';
Channel = 1;
Amplitude = 0.1;
StepTime = 0.01;
step_simulation_time = 0.5;
```

---

## ⚠️ 注意事項

1. 執行測試前，請確保當前目錄在 `test_script/` 下
2. 模型會自動開啟，無需手動打開 `.slx` 檔案
3. 測試結果會自動保存，不會覆蓋舊結果（使用時間戳）
4. Sine 模式會自動跳過暫態響應，只顯示穩態數據

---

**最後更新**: 2025-10-17
