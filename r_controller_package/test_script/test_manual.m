% test_manual.m
% 手動測試腳本 - 僅設定參數到 Workspace，不執行模擬
%
% 使用方式：
%   1. 修改下方參數
%   2. 執行此腳本，設定參數到 workspace
%   3. 手動打開 Simulink 模型 (r_controller_system_integrated.slx)
%   4. 手動點擊 Run 按鈕執行模擬
%   5. 查看 Scope 或 To Workspace 結果

clear; clc;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           R Controller 手動測試 - 參數設定\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% ==================== Vd Generator 參數 ====================

signal_type_name = 'sine';      % 信號類型: 'sine' 或 'step'
Channel = 5;                    % 激發通道 (1-6)
Amplitude = 1;               % 振幅 [V]
Frequency = 100;                % Sine 頻率 [Hz]
Phase = 0;                      % Sine 相位 [deg]
StepTime = 0;                 % Step 跳變時間 [s]

%% ==================== Controller 參數 ====================

T = 1e-5;                       % 採樣時間 [s] (100 kHz)
fB_c = 3200;                    % 控制器頻寬 [Hz]
fB_e = 16000;                   % 估測器頻寬 [Hz]
d = 2;                          % 

%% ==================== Simulink 參數 ====================

Ts = 1e-5;                      % 採樣時間 [s] (100 kHz)

%% ==================== 自動處理 ====================

% 轉換 SignalType (字串 → 數字)
if strcmpi(signal_type_name, 'sine')
    SignalType = 1;
elseif strcmpi(signal_type_name, 'step')
    SignalType = 2;
else
    error('signal_type_name 必須是 ''step'' 或 ''sine''');
end

% 計算 lambda 參數
lambda_c = exp(-fB_c*T*2*pi);
lambda_e = exp(-fB_e*T*2*pi);
beta = sqrt(lambda_e * lambda_c);

% 驗證參數
if Channel < 1 || Channel > 6
    error('Channel 必須在 1-6 之間');
end

%% ==================== 顯示設定 ====================

fprintf('【Workspace 變數已設定】\n');
fprintf('────────────────────────\n\n');

fprintf('Vd Generator:\n');
fprintf('  SignalType = %d (%s)\n', SignalType, signal_type_name);
fprintf('  Channel    = %d\n', Channel);
fprintf('  Amplitude  = %.3f V\n', Amplitude);
if strcmpi(signal_type_name, 'sine')
    fprintf('  Frequency  = %.1f Hz\n', Frequency);
    fprintf('  Phase      = %.1f deg\n', Phase);
else
    fprintf('  StepTime   = %.3f s\n', StepTime);
end
fprintf('\n');

fprintf('Controller:\n');
fprintf('  T          = %.2e s\n', T);
fprintf('  fB_c       = %d Hz\n', fB_c);
fprintf('  fB_e       = %d Hz\n', fB_e);
fprintf('  d          = %d\n', d);
fprintf('  lambda_c   = %.6f (計算)\n', lambda_c);
fprintf('  lambda_e   = %.6f (計算)\n', lambda_e);
fprintf('  beta       = %.6f (計算)\n', beta);
fprintf('\n');

fprintf('Simulink:\n');
fprintf('  Ts         = %.2e s (%.0f kHz)\n', Ts, 1/Ts/1000);
fprintf('\n');

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('✓ 參數設定完成，請開啟 Simulink 模型執行模擬\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
