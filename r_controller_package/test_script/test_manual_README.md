# test_manual.m 使用說明

## 功能

`test_manual.m` 參數設定腳本，用於手動測試 R Controller 系統

將測試參數設定到 MATLAB workspace，可以手動打開 Simulink 模型並執行模擬

---

## 使用流程

### Step 1: 修改參數
打開 `test_manual.m`，根據需求修改以下參數：

```matlab
%% ==================== Vd Generator 參數 ====================

% 信號類型: 'sine' 或 'step'
signal_type_name = 'sine';

% 通道與振幅
Channel = 4;                    % 激發通道 (1-6)
Amplitude = 0.5;               % 振幅 [V]

% Sine 模式參數
Frequency = 100;                % Sine 頻率 [Hz]
Phase = 0;                      % Sine 相位 [deg]

% Step 模式參數
StepTime = 0.01;                % Step 跳變時間 [s]

%% ==================== 模擬器參數 ====================

Ts = 1e-5;                      % 採樣時間 [s] (100 kHz)
```

### Step 2: 執行腳本


### Step 3: 打開 Simulink 模型

### Step 4: 設定模擬時間並執行


### Step 5: 查看結果


---

## 參數說明

| 參數 | 說明 | 範例值 |
|------|------|--------|
| `signal_type_name` | 信號類型 | `'sine'` 或 `'step'` |
| `Channel` | 激發通道 | `1` ~ `6` |
| `Amplitude` | 信號振幅 | `0.5` (V) |
| `Frequency` | Sine 波頻率 | `100` (Hz) |
| `Phase` | Sine 波相位 | `0` (度) |
| `StepTime` | Step 跳變時間 | `0.01` (秒) |
| `Ts` | 採樣時間 | `1e-5` (秒，即 100 kHz) |

**注意**：
- 所有參數會自動載入到 workspace，Simulink 模型會直接讀取

---

## 快速範例

### 範例 1: Sine 波測試 (100 Hz, P4)
```matlab
% 在 test_manual.m 中設定：
signal_type_name = 'sine';
Channel = 4;
Amplitude = 0.5;
Frequency = 100;
Phase = 0;

% 執行並模擬
test_manual
open_system('r_controller_system_integrated')
% 設定 Stop Time = 0.3 秒，點擊 Run
```

### 範例 2: Step 信號測試 (P1)
```matlab
% 在 test_manual.m 中設定：
signal_type_name = 'step';
Channel = 1;
Amplitude = 0.5;
StepTime = 0.05;

% 執行並模擬
test_manual
open_system('r_controller_system_integrated')
% 設定 Stop Time = 0.5 秒，點擊 Run
```
