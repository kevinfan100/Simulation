% test_vd_manual.m
% 手動測試用參數設定腳本
%
% 使用方法：
%   1. 修改下方的參數配置
%   2. 執行此腳本（將參數載入 workspace）
%   3. 手動在 Simulink 中開啟模型並按播放按鈕
%   4. 查看模擬結果

clear; clc;

fprintf('═══════════════════════════════════════════════════════════\n');
fprintf('           R Controller 手動測試參數設定\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

%% ═══════════════════════════════════════════════════════════════
%                     參數配置區 - 在此修改參數
%  ═══════════════════════════════════════════════════════════════

% ┌─────────────────────────────────────────────────────────────┐
% │ Vd Generator 參數                                            │
% └─────────────────────────────────────────────────────────────┘
signal_type_name = 'sine';         % 'step' 或 'sine'
Channel = 4;                       % 激發通道 (1-6)
Amplitude = 0.45;                  % 振幅 [V]
Frequency = 100;                   % Sine 頻率 [Hz]
Phase = 0;                         % Sine 相位 [deg]
StepTime = 0.1;                    % Step 跳變時間 [s] (當 signal_type_name = 'step' 時使用)

% 常用測試範例 (註解掉未使用的):
% ─────────────────────────────────────────────────────────────
% 範例 1: 低頻正弦波 (100 Hz)
%   Frequency = 100; Amplitude = 0.45; Channel = 4;
%
% 範例 2: 中頻正弦波 (1000 Hz)
%   Frequency = 1000; Amplitude = 1.0; Channel = 5;
%
% 範例 3: 高頻正弦波 (5000 Hz)
%   Frequency = 5000; Amplitude = 0.5; Channel = 1;
%
% 範例 4: Step 響應測試
%   signal_type_name = 'step'; Amplitude = 1.0; StepTime = 0.1;
% ─────────────────────────────────────────────────────────────

% ┌─────────────────────────────────────────────────────────────┐
% │ Controller 參數                                              │
% └─────────────────────────────────────────────────────────────┘
T = 1e-5;                          % 採樣時間 [s] (100 kHz) - 固定值，不建議修改
fB_c = 3200;                       % 控制器頻寬 [Hz]
fB_e = 16000;                      % 估測器頻寬 [Hz]
d = 2;                             % 相對階數 (固定為 2)

% Controller 頻寬設定範例:
% ─────────────────────────────────────────────────────────────
% 預設設定 (標準響應):
%   fB_c = 3200;   fB_e = 16000;   → lambda_c ≈ 0.8179, lambda_e ≈ 0.3659
%
% 保守設定 (較慢但穩定):
%   fB_c = 1600;   fB_e = 8000;    → lambda_c ≈ 0.9048, lambda_e ≈ 0.6050
%
% 激進設定 (快速響應):
%   fB_c = 6400;   fB_e = 32000;   → lambda_c ≈ 0.6703, lambda_e ≈ 0.1353
% ─────────────────────────────────────────────────────────────

% ┌─────────────────────────────────────────────────────────────┐
% │ Simulink 參數                                                │
% └─────────────────────────────────────────────────────────────┘
Ts = 1e-5;                         % 採樣時間 [s] (100 kHz)

%% ═══════════════════════════════════════════════════════════════
%                     自動計算的參數
%  ═══════════════════════════════════════════════════════════════

% 轉換 SignalType（字串 → 數字，給 Simulink 使用）
if strcmpi(signal_type_name, 'sine')
    SignalType = 1;
else
    SignalType = 2;
end

% 計算 lambda 參數
lambda_c = exp(-fB_c*T*2*pi);
lambda_e = exp(-fB_e*T*2*pi);
beta = sqrt(lambda_e * lambda_c);

%% ═══════════════════════════════════════════════════════════════
%                     參數驗證與顯示
%  ═══════════════════════════════════════════════════════════════

% 驗證參數
if ~ismember(lower(signal_type_name), {'step', 'sine'})
    error('signal_type_name 必須是 ''step'' 或 ''sine''');
end

if Channel < 1 || Channel > 6
    error('Channel 必須在 1-6 之間');
end

fprintf('【已載入的 Workspace 變數】\n');
fprintf('────────────────────────────────────────────────────────\n\n');

fprintf('📌 Vd Generator 參數:\n');
fprintf('   SignalType     = %d (%s)\n', SignalType, signal_type_name);
fprintf('   Channel        = %d (P%d)\n', Channel, Channel);
fprintf('   Amplitude      = %.3f V\n', Amplitude);
if strcmpi(signal_type_name, 'sine')
    fprintf('   Frequency      = %.1f Hz\n', Frequency);
    fprintf('   Phase          = %.1f deg\n', Phase);
else
    fprintf('   StepTime       = %.3f s\n', StepTime);
end
fprintf('\n');

fprintf('📌 Controller 參數:\n');
fprintf('   T              = %.2e s (採樣週期)\n', T);
fprintf('   fB_c           = %d Hz (控制器頻寬)\n', fB_c);
fprintf('   fB_e           = %d Hz (估測器頻寬)\n', fB_e);
fprintf('   d              = %d (相對階數)\n', d);
fprintf('   lambda_c       = %.8f (自動計算)\n', lambda_c);
fprintf('   lambda_e       = %.8f (自動計算)\n', lambda_e);
fprintf('   beta           = %.8f (自動計算)\n', beta);
fprintf('\n');

fprintf('📌 Simulink 參數:\n');
fprintf('   Ts             = %.2e s (100 kHz 採樣)\n', Ts);
fprintf('\n');

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('✅ 參數已載入完成！\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

fprintf('💡 下一步操作:\n');
fprintf('   1. 在 Simulink 中開啟模型: r_controller_system_integrated.slx\n');
fprintf('   2. 點擊播放按鈕執行模擬\n');
fprintf('   3. 查看 Scope 或輸出變數 (Vd, Vm, e, u, w1_hat)\n');
fprintf('\n');

fprintf('📋 Workspace 中的關鍵變數:\n');
fprintf('   Vd Generator: SignalType, Channel, Amplitude, Frequency, Phase, StepTime\n');
fprintf('   Controller:   fB_c, fB_e, lambda_c, lambda_e, beta, d, T\n');
fprintf('   Simulink:     Ts\n');
fprintf('\n');

fprintf('⚠️  注意事項:\n');
fprintf('   - 模型檔案位置: r_controller_package/model/r_controller_system_integrated.slx\n');
fprintf('   - 請確保 Simulink 的 Fixed-step size = %.2e (或 auto)\n', Ts);
fprintf('   - 建議使用 ode45 或 ode23tb solver\n');
fprintf('   - 模擬時間可在 Simulink 中自行設定\n');
fprintf('\n');
