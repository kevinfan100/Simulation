# R Controller (General 版本) 程式碼參考

完整的 R Controller 實現程式碼，包含所有參數定義和差分方程式。

---

## 1. 參數定義 (params)

### 1.1 系統常數

```matlab
% 採樣參數
T = 1e-5;                    % 採樣時間 [s] (100 kHz)

% 受控體參數 (Plant H(z^-1))
k_o = 5.6695e-4;             % 系統增益
b = 0.9782;                  % 零點係數
a1 = 1.934848;               % 極點係數 1
a2 = -0.935970;              % 極點係數 2

% 耦合矩陣 B 的反矩陣 (6x6)
B = [0.2365  -0.0064  -0.0327  -0.0344  -0.0408  -0.0343;
    -0.0037   0.2818  -0.0427  -0.0675  -0.0779  -0.0368;
    -0.0375  -0.0328   0.2108  -0.0060  -0.0265  -0.0341;
    -0.0245  -0.0777  -0.0056   0.2361  -0.0770  -0.0241;
    -0.0413  -0.0760  -0.0234  -0.0720   0.2572  -0.0045;
    -0.0244  -0.0330  -0.0257  -0.0245  -0.0030   0.1845];
B_inv = inv(B);
```

### 1.2 中間參數

```matlab
% 頻寬設定 (範例：fB_c = 3200 Hz, fB_e = 16000 Hz)
fB_c = 3200;                 % 控制頻寬 [Hz]
fB_e = 16000;                % 估測器頻寬 [Hz]

% 特徵值 (Eigenvalues)
lambda_c = exp(-fB_c * 2 * pi * T);  % ≈ 0.8179
lambda_e = exp(-fB_e * 2 * pi * T);  % ≈ 0.3659
beta = sqrt(lambda_e * lambda_c);     % ≈ 0.5471

% 控制器增益
kc = (1 - lambda_c) / (1 + b);        % ≈ 0.0920
bc = b * kc;                          % ≈ 0.0900
ku = kc / k_o;                        % ≈ 162.36
```

### 1.3 前饋濾波器係數

```matlab
% vf[k] = alpha_vf * {c0·vd[k] + c1·vd[k-1] + c2·vd[k-2]}
alpha_vf = 1 / ((1 - lambda_c) * (1 + b));  % ≈ 2.7713
c0_b = b;                                    % = 0.9782
c1_one_S_b_M_lambda_c = 1 - b * lambda_c;   % ≈ 0.2000
c2_neg_lambda_c = -lambda_c;                % ≈ -0.8179

% 遞歸濾波器項
one_S_bc = 1 - bc;                          % ≈ 0.9100
```

### 1.4 估測器增益

```matlab
% L1: δv̂ 更新增益
L1 = lambda_c + (1 + beta) - 3*lambda_e;    % ≈ 1.2671

% L2: w1_hat 更新增益 (快速擾動)
L2 = (b*(lambda_e - 1)^3 - ...
      beta*(b + 1)*(beta^2 - 3*beta*lambda_e + beta + ...
      3*lambda_e^2 - 3*lambda_e + 1)) / ...
     (kc * (b + 1) * (b + beta));           % ≈ -3.0390

% L3: w2_hat 更新增益 (慢速擾動)
L3 = -(beta + b + beta*b - 3*beta*lambda_e - ...
       3*b*lambda_e + b*beta^2 + ...
       3*b*lambda_e^2 + beta^2 + lambda_e^3 - ...
       3*beta*b*lambda_e) / ...
      (kc * (b + 1) * (b + beta));          % ≈ -2.9967

% beta 相關係數
one_A_beta = 1 + beta;                      % ≈ 1.5471
neg_beta = -beta;                           % ≈ -0.5471
```

---

## 2. 狀態變數

控制器需要維護 16 個狀態變數（所有變數都是 6×1 向量）：

```matlab
% 輸入歷史
vd_k1, vd_k2         % vd[k-1], vd[k-2]

% 濾波器歷史
vf_k1, vf_k2         % vf[k-1], vf[k-2]

% 誤差歷史
delta_v_k1           % δv[k-1] = vf[k-1] - vm[k-1]
delta_v_hat_k1       % δv̂[k-1]

% 擾動估測
w1_hat_k1, w2_hat_k1 % ŵ1[k-1], ŵ2[k-1]

% 控制歷史
delta_vc_k1, delta_vc_k2  % δvc[k-1], δvc[k-2]
uc_k1, uc_k2              % uc[k-1], uc[k-2]
```

初始化：所有狀態變數在 k=0 時設為 `zeros(6, 1)`

---

## 3. 差分方程式

### 3.1 前饋濾波器

```matlab
% vf[k] = alpha_vf * {c0·vd[k] + c1·vd[k-1] + c2·vd[k-2]}
vf_k = alpha_vf * (c0_b * vd + ...
                   c1_one_S_b_M_lambda_c * vd_k1 + ...
                   c2_neg_lambda_c * vd_k2);

% δvf[k] = vf[k] - (1-bc)·vf[k-1] - bc·vf[k-2]
delta_vf = vf_k - one_S_bc * vf_k1 - bc * vf_k2;

% δv[k] = vf[k] - vm[k]
delta_v = vf_k - vm;
```

### 3.2 擾動觀測器 (Estimator)

```matlab
% 估測誤差
error_term = delta_v_k1 - delta_v_hat_k1;

% δv̂[k] = λc·δv̂[k-1] + δvf[k] + L1·{δv[k-1] - δv̂[k-1]}
delta_v_hat = lambda_c * delta_v_hat_k1 + delta_vf + L1 * error_term;

% ŵ1[k] = (1+β)·ŵ1[k-1] - β·ŵ2[k-1] + L2·{δv[k-1] - δv̂[k-1]}
w1_hat = one_A_beta * w1_hat_k1 + neg_beta * w2_hat_k1 + L2 * error_term;

% ŵ2[k] = ŵ1[k-1] + L3·{δv[k-1] - δv̂[k-1]}
w2_hat = w1_hat_k1 + L3 * error_term;
```

### 3.3 控制律

```matlab
% δvc[k] = δv[k] - ŵ1[k]
delta_vc = delta_v - w1_hat;

% uc[k] = (1-bc)·uc[k-1] + bc·uc[k-2] + ku·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
uc = one_S_bc * uc_k1 + bc * uc_k2 + ...
     ku * (delta_vc - a1 * delta_vc_k1 - a2 * delta_vc_k2);

% u[k] = B^-1 · uc[k]
u = B_inv * uc;
```

### 3.4 狀態更新

```matlab
% 更新所有歷史狀態（每個時間步最後執行）
vd_k2 = vd_k1;
vd_k1 = vd;
vf_k2 = vf_k1;
vf_k1 = vf_k;
delta_v_k1 = delta_v;
delta_v_hat_k1 = delta_v_hat;
w1_hat_k1 = w1_hat;
w2_hat_k1 = w2_hat;
delta_vc_k2 = delta_vc_k1;
delta_vc_k1 = delta_vc;
uc_k2 = uc_k1;
uc_k1 = uc;
```

---

## 4. 輸入/輸出

### 輸入
- `vd`: 期望電壓 [6×1]（可能是 preview 值 vd[k+d]）
- `vm`: 量測電壓 [6×1]

### 輸出
- `u`: 控制輸入 [6×1]
- `e`: 追蹤誤差 [6×1]（= δv）
- `w1_hat`: 擾動估測 [6×1]
- `delta_v_hat`: 誤差估測 [6×1]（= δv̂）

---

## 5. 執行流程

```
每個時間步 k：
  1. 前饋濾波器
     ↓ 計算 vf_k, delta_vf, delta_v
  2. 擾動觀測器
     ↓ 計算 delta_v_hat, w1_hat, w2_hat
  3. 控制律
     ↓ 計算 delta_vc, uc, u
  4. 狀態更新
     ↓ 更新所有 k-1, k-2 狀態
```

---

## 6. 變數命名規則

| 符號 | 意義 | 範例 |
|------|------|------|
| `A` | Addition (+) | `one_A_beta` = 1 + beta |
| `S` | Subtraction (-) | `one_S_bc` = 1 - bc |
| `M` | Multiplication (×) | `b_M_lambda_c` = b × lambda_c |
| `D` | Division (÷) | `a_D_b` = a / b |
| `neg_` | Negative (-) | `neg_beta` = -beta |

---

## 7. 檔案位置

```
r_controller_package/
├── model/
│   ├── r_controller_system_integrated.slx      # Simulink 完整系統
│   ├── r_controller_calc_params.m              # 參數計算函數
│   └── r_controller_function_general.m         # 控制器函數（本文檔對應）
│
└── test_script/
    └── run_rcontroller_test.m                  # 測試腳本
```

### 使用方法

```matlab
% 在測試腳本中
CONTROLLER_TYPE = 'general';
fB_c = 3200;                % 控制頻寬 [Hz]
fB_e = 16000;               % 估測器頻寬 [Hz]

% 計算參數
params = r_controller_calc_params(fB_c, fB_e);

% 在 Simulink 中使用 r_controller_function_general.m
sim('r_controller_system_integrated');
```

---

## 8. 關鍵數值摘要

**頻寬設定：** fB_c = 3200 Hz, fB_e = 16000 Hz

| 參數 | 數值 | 說明 |
|------|------|------|
| `lambda_c` | 0.8179 | 控制特徵值 |
| `lambda_e` | 0.3659 | 估測器特徵值 |
| `beta` | 0.5471 | 耦合參數 |
| `kc` | 0.0920 | 控制器增益 |
| `bc` | 0.0900 | 零點補償增益 |
| `ku` | 162.36 | 歸一化增益 |
| `L1` | 1.2671 | δv̂ 觀測器增益 |
| `L2` | -3.0390 | ŵ1 觀測器增益 |
| `L3` | -2.9967 | ŵ2 觀測器增益 |

---

**Last Updated:** 2025-01-09
**Version:** General (d=0/1/2 通用版本)
**Reference:** `r_controller_function_general.m`, `r_controller_calc_params.m`
