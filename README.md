# Type 3 MIMO 控制器測試框架

**最後更新：2025-10-15**

Type 3 MIMO Controller (6×6) 的 Simulink 模擬與測試框架。

---

## 📁 專案結構

```
Simulation/
│
├── 📄 Control_System_Integrated.slx          主系統模型
├── 📄 Type3_Controller_MatlabFunc.slx        控制器子模型
│
├── 📂 scripts/                       測試和工具腳本
│   ├── run_controller_test_v2.m              ⭐ 主測試腳本
│   ├── test_sine_wave_integration.m          頻率掃描測試
│   ├── configure_sine_wave.m                 信號配置工具
│   ├── verify_sine_wave_setup.m              模型驗證工具
│   └── analyze_frequency_response.m          FFT 分析工具
│
├── 📂 reference/                     參考資料和文檔
│   ├── *.pdf                                 技術文件
│   ├── Model_6_6_Continuous_Weighted.m       參考實作
│   └── generate_simulink_framework.m         框架生成工具
│
└── 📂 test_results/                  測試結果保存
    └── (自動生成的測試結果)
```

---

## 🚀 快速開始

### 1️⃣ Sine Wave 測試（推薦）

```matlab
% 打開 scripts/run_controller_test_v2.m
cd scripts
edit run_controller_test_v2

% 修改配置區域（SECTION 1）
signal_type = 'sine';
active_channel = 1;          % P1-P6
amplitude = 0.5;
sine_frequency = 10;         % Hz

% 執行測試
run_controller_test_v2
```

**輸出：**
- 李薩如圖（Vm vs Vd）- 檢查系統解耦
- 6 通道時域響應（最後 5 個週期）
- 完整時域響應
- 自動保存 PNG + MAT

---

### 2️⃣ Step 響應測試

```matlab
% 打開 scripts/run_controller_test_v2.m
signal_type = 'step';
active_channel = 2;
amplitude = 0.1;

% 執行測試
run_controller_test_v2
```

**輸出：**
- 6 通道 Step 響應
- 誤差分析
- 控制輸入分析

---

### 3️⃣ 頻率掃描（Bode 圖）

```matlab
% 打開 scripts/test_sine_wave_integration.m
cd scripts
edit test_sine_wave_integration

% 修改配置
test_mode = 'frequency_sweep';
freq_start = 1;              % Hz
freq_end = 1000;             % Hz
freq_points = 20;

% 執行
test_sine_wave_integration
```

**輸出：**
- Bode 圖（增益 + 相位）
- -3dB 頻寬自動計算
- 頻率響應數據（MAT）

---

## ⚙️ 控制器規格

- **類型**：Type 3 離散控制器（Zero-Order Hold）
- **採樣頻率**：100 kHz (Ts = 1e-5 s)
- **極點配置**：λc = 0.9391, λe = 0.7304
- **控制律**：u[k] = B^(-1){vff + δvfb - ŵT}
- **通道數**：6×6 MIMO

---

## 📊 視覺化功能

### Sine Wave 測試
- ✅ **李薩如圖**：Vm vs Vd（檢查解耦）
- ✅ **6 通道子圖**：時域 Vd + Vm（穩態）
- ✅ **完整響應**：含暫態過程
- ✅ **顏色區分**：黑色虛線（Vd）vs 彩色實線（Vm）

### Step 測試
- ✅ **6 通道響應**：Step 追蹤
- ✅ **誤差分析**：e = Vd - Vm
- ✅ **控制輸入**：u 信號

### Bode 圖
- ✅ **增益曲線**：dB vs 頻率
- ✅ **相位曲線**：度 vs 頻率
- ✅ **-3dB 標記**：自動標示頻寬

---

## 🔧 工具說明

查看各資料夾的 README 了解詳細說明：
- [`core/README.md`](core/README.md) - 核心模型說明
- [`scripts/README.md`](scripts/README.md) - 腳本使用指南
- [`reference/README.md`](reference/README.md) - 參考資料說明

---

## ⚠️ 注意事項

1. **路徑問題**：執行腳本前先 `cd scripts`
2. **模型路徑**：腳本會自動在 `../core/` 尋找模型
3. **結果保存**：自動保存在 `../test_results/` 目錄
4. **通道標記**：P1-P6 對應 Channel 1-6

---

## 📝 更新日誌

### v2.1 (2025-10-15)
- ✅ 專案重新組織（core/scripts/reference）
- ✅ 視覺改進（Vd 改為黑色虛線，移除圖例）
- ✅ 清理過時檔案和文檔
- ✅ 每個資料夾獨立 README

### v2.0 (2025-10-15)
- ✅ 主測試腳本 `run_controller_test_v2.m`
- ✅ Sine Wave 和 Step 整合
- ✅ 6 通道完整視覺化
- ✅ 李薩如圖功能
- ✅ 修正相位計算錯誤

---

*Type 3 MIMO Controller Testing Framework*
*Generated and maintained by Claude Code*
