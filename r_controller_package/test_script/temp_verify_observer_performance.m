% verify_observer_openloop.m
% 使用開迴路傳遞函數精確驗證 Disturbance Observer
%
% 原理：分析 w1_hat 對估測誤差 (δv - δv̂) 的響應
% 這是真正的 Observer 開迴路傳遞函數
%
% 需要：R Controller 輸出 delta_v_hat (第4個輸出)

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('   Disturbance Observer 開迴路驗證（精確方法）\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 參數設定

% R Controller 參數
fB_c = 3200;                % 控制器頻寬 [Hz]
fB_e = 16000;               % 估測器頻寬 [Hz]
T = 1e-5;                   % 採樣時間 [s]

% 計算參數
addpath(fullfile(fileparts(pwd), 'model'));
params = r_controller_calc_params(fB_c, fB_e);

fprintf('【Observer 設計參數】\n');
fprintf('────────────────────────\n');
fprintf('  fB_e = %.0f Hz\n', fB_e);
fprintf('  λ_e = %.4f\n', params.lambda_e);
fprintf('  β = %.4f\n', params.beta);
fprintf('  L1 = %.4f\n', params.L1);
fprintf('  L2 = %.4f\n', params.L2);
fprintf('  L3 = %.4f\n', params.L3);
fprintf('\n');

%% SECTION 2: 計算理論開迴路傳遞函數

fprintf('【理論開迴路傳遞函數】\n');
fprintf('────────────────────────\n');

% 傳遞函數：G_open(z) = (L2·z^-1 - β·L3·z^-2) / (1 - (1+β)·z^-1 + β·z^-2)
fprintf('         L2·z⁻¹ - β·L3·z⁻²\n');
fprintf('G_open = ─────────────────────\n');
fprintf('         1 - (1+β)z⁻¹ + βz⁻²\n');
fprintf('\n');
fprintf('分子係數：L2 = %.4f, -β·L3 = %.4f\n', params.L2, -params.beta*params.L3);
fprintf('分母係數：1, -(1+β) = %.4f, β = %.4f\n', -(1+params.beta), params.beta);
fprintf('\n');

% 計算頻率響應
freq_test = logspace(1, 5, 200);  % 10 Hz to 100 kHz
theoretical_mag = zeros(size(freq_test));
theoretical_phase = zeros(size(freq_test));
theoretical_mag_dB = zeros(size(freq_test));

for i = 1:length(freq_test)
    f = freq_test(i);
    omega = 2 * pi * f * T;
    z = exp(1j * omega);

    % 開迴路傳遞函數
    numerator = params.L2 * z^(-1) - params.beta * params.L3 * z^(-2);
    denominator = 1 - (1 + params.beta) * z^(-1) + params.beta * z^(-2);

    G_open = numerator / denominator;

    theoretical_mag(i) = abs(G_open);
    theoretical_mag_dB(i) = 20 * log10(abs(G_open));
    theoretical_phase(i) = angle(G_open) * 180 / pi;
end

% 找理論 -3dB 頻寬
[max_gain_dB, max_idx] = max(theoretical_mag_dB(1:50)); % 低頻最大增益
target_dB = max_gain_dB - 3;

idx_3dB = find(theoretical_mag_dB < target_dB, 1, 'first');
if ~isempty(idx_3dB) && idx_3dB > 1
    f_3dB_theory = freq_test(idx_3dB);
    % 精確插值
    if idx_3dB > 1
        f1 = freq_test(idx_3dB - 1);
        f2 = freq_test(idx_3dB);
        mag1 = theoretical_mag_dB(idx_3dB - 1);
        mag2 = theoretical_mag_dB(idx_3dB);
        f_3dB_theory = f1 + (f2 - f1) * (target_dB - mag1) / (mag2 - mag1);
    end
else
    f_3dB_theory = NaN;
end

fprintf('【理論性能指標】\n');
fprintf('────────────────────────\n');
fprintf('  DC 增益: %.2f dB\n', theoretical_mag_dB(1));
fprintf('  最大增益: %.2f dB @ %.0f Hz\n', max_gain_dB, freq_test(max_idx));
fprintf('  -3dB 頻寬: %.0f Hz\n', f_3dB_theory);
fprintf('  與 fB_e 比值: %.2f\n', f_3dB_theory / fB_e);
fprintf('\n');

%% SECTION 3: 實際測試（如果有 delta_v_hat 輸出）

% 測試頻率（密集在 fB_e 附近）
test_frequencies = [10, 50, 100, 200, 500, 1000, 2000, ...           % 低頻
                   4000, 6000, 8000, 10000, 12000, 14000, ...       % 中頻
                   16000, 18000, 20000, 25000, 30000, 40000];       % 高頻

num_freq = length(test_frequencies);

fprintf('【執行實測（需要 delta_v_hat 輸出）】\n');
fprintf('────────────────────────\n');

% 初始化結果
measured_mag = zeros(num_freq, 1);
measured_phase = zeros(num_freq, 1);
measured_mag_dB = zeros(num_freq, 1);

% 模型設定
model_name = 'r_controller_system_integrated';
model_path = fullfile(fileparts(pwd), 'model', [model_name '.slx']);

if ~exist(model_path, 'file')
    fprintf('⚠️ 找不到模型: %s\n', model_path);
    fprintf('   跳過實測部分\n\n');
else
    % 載入模型
    if ~bdIsLoaded(model_name)
        load_system(model_path);
    end

    % 設定參數
    assignin('base', 'params', params);
    assignin('base', 'd', 0);
    assignin('base', 'Channel', 1);
    assignin('base', 'Amplitude', 1);
    assignin('base', 'Phase', 0);
    assignin('base', 'SignalType', 1);
    assignin('base', 'Ts', T);
    assignin('base', 'StepTime', 0);

    % 執行頻率掃描
    for idx = 1:num_freq
        freq = test_frequencies(idx);
        fprintf('[%2d/%2d] %.0f Hz ... ', idx, num_freq, freq);

        assignin('base', 'Frequency', freq);

        % 模擬時間
        period = 1 / freq;
        sim_time = max(100 * period, 0.1);

        set_param(model_name, 'StopTime', num2str(sim_time));
        set_param(model_name, 'Solver', 'ode5');
        set_param(model_name, 'FixedStep', num2str(T));

        try
            warning('off', 'all');
            out = sim(model_name);
            warning('on', 'all');

            % 提取數據
            t = out.tout;

            % 檢查必要輸出
            if ~isfield(out, 'w1_hat')
                fprintf('❌ 缺少 w1_hat 輸出\n');
                break;
            end
            if ~isfield(out, 'e')
                fprintf('❌ 缺少 e 輸出\n');
                break;
            end
            if ~isfield(out, 'delta_v_hat')
                fprintf('⚠️ 缺少 delta_v_hat 輸出，無法計算開迴路響應\n');
                fprintf('   請修改 Simulink 模型，從 R Controller 第4個輸出連接 delta_v_hat\n');
                break;
            end

            % 穩態數據
            steady_start = round(0.6 * length(t));
            w1_steady = out.w1_hat.Data(steady_start:end, 1);
            delta_v = out.e.Data(steady_start:end, 1);  % e = δv
            delta_v_hat = out.delta_v_hat.Data(steady_start:end, 1);

            % 計算估測誤差
            error_signal = delta_v - delta_v_hat;

            % FFT 分析
            N = length(w1_steady);
            fs = 1/T;
            freq_axis = (0:N-1) * fs / N;
            [~, bin_idx] = min(abs(freq_axis - freq));

            % Error 的 FFT
            Error_fft = fft(error_signal);
            Error_mag = abs(Error_fft(bin_idx)) * 2 / N;
            Error_phase = angle(Error_fft(bin_idx)) * 180 / pi;

            % w1_hat 的 FFT
            W1_fft = fft(w1_steady);
            W1_mag = abs(W1_fft(bin_idx)) * 2 / N;
            W1_phase = angle(W1_fft(bin_idx)) * 180 / pi;

            % 計算開迴路響應
            if Error_mag > 1e-6
                measured_mag(idx) = W1_mag / Error_mag;
                measured_phase(idx) = W1_phase - Error_phase;
                measured_mag_dB(idx) = 20 * log10(measured_mag(idx));
            else
                measured_mag(idx) = NaN;
                measured_phase(idx) = NaN;
                measured_mag_dB(idx) = NaN;
            end

            % 相位正規化
            while measured_phase(idx) > 180
                measured_phase(idx) = measured_phase(idx) - 360;
            end
            while measured_phase(idx) < -180
                measured_phase(idx) = measured_phase(idx) + 360;
            end

            fprintf('✓ |G|=%.2f dB\n', measured_mag_dB(idx));

        catch ME
            fprintf('✗ %s\n', ME.message);
            continue;
        end
    end

    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end
end

%% SECTION 4: 繪製比較圖

figure('Position', [100, 100, 1400, 800]);

% 上圖：Magnitude
subplot(2, 1, 1);
semilogx(freq_test, theoretical_mag_dB, 'b-', 'LineWidth', 2, ...
         'DisplayName', '理論開迴路');
hold on;

% 如果有實測數據
if any(~isnan(measured_mag_dB))
    semilogx(test_frequencies, measured_mag_dB, 'ro', ...
             'MarkerSize', 8, 'LineWidth', 1.5, ...
             'DisplayName', '實測開迴路');
end

% 標記關鍵頻率
xline(fB_e, 'g--', 'LineWidth', 1.5, ...
      'Label', sprintf('fB_e = %.0f Hz', fB_e));
if ~isnan(f_3dB_theory)
    xline(f_3dB_theory, 'r--', 'LineWidth', 1.5, ...
          'Label', sprintf('-3dB @ %.0f Hz', f_3dB_theory));
end
yline(max_gain_dB - 3, 'k:', 'LineWidth', 1, 'Alpha', 0.5);

grid on;
xlabel('Frequency [Hz]', 'FontSize', 12);
ylabel('Magnitude [dB]', 'FontSize', 12);
title('Disturbance Observer 開迴路頻率響應: w1\_hat / (δv - δv̂)', ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'southwest');
xlim([10, 100000]);
ylim([min(theoretical_mag_dB)-5, max_gain_dB+5]);

% 下圖：Phase
subplot(2, 1, 2);
semilogx(freq_test, theoretical_phase, 'b-', 'LineWidth', 2, ...
         'DisplayName', '理論相位');
hold on;

if any(~isnan(measured_phase))
    semilogx(test_frequencies, measured_phase, 'ro', ...
             'MarkerSize', 8, 'LineWidth', 1.5, ...
             'DisplayName', '實測相位');
end

xline(fB_e, 'g--', 'LineWidth', 1.5);
yline(-45, 'k:', 'LineWidth', 1, 'Label', '-45°');
yline(-90, 'k:', 'LineWidth', 1, 'Label', '-90°');

grid on;
xlabel('Frequency [Hz]', 'FontSize', 12);
ylabel('Phase [deg]', 'FontSize', 12);
title('相位響應', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'southwest');
xlim([10, 100000]);

%% SECTION 5: 驗證標準與判定

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                    驗證結果判定\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

fprintf('【您應該看到的結果】\n');
fprintf('────────────────────────\n');
fprintf('1. DC 增益（低頻）:\n');
fprintf('   理論: %.2f dB\n', theoretical_mag_dB(1));
fprintf('   預期: 高增益值（通常 > 40 dB）\n');
fprintf('   意義: Observer 在低頻有強的誤差修正能力\n');
fprintf('\n');

fprintf('2. -3dB 頻寬:\n');
fprintf('   理論: %.0f Hz\n', f_3dB_theory);
fprintf('   預期: 接近但不完全等於 fB_e (%.0f Hz)\n', fB_e);
fprintf('   容許誤差: ±20%%\n');
fprintf('   意義: Observer 的響應速度\n');
fprintf('\n');

fprintf('3. 高頻衰減:\n');
fprintf('   在 2×fB_e (%.0f Hz) 處: %.1f dB\n', ...
        2*fB_e, interp1(freq_test, theoretical_mag_dB, 2*fB_e));
fprintf('   預期: < -10 dB\n');
fprintf('   意義: 高頻雜訊抑制\n');
fprintf('\n');

fprintf('4. 相位特性:\n');
fprintf('   在 fB_e 處: %.1f°\n', ...
        interp1(freq_test, theoretical_phase, fB_e));
fprintf('   預期: 接近 -90°\n');
fprintf('   意義: 系統延遲特性\n');
fprintf('\n');

% 判定
fprintf('【驗證判定標準】\n');
fprintf('────────────────────────\n');

% 計算關鍵指標
bandwidth_error = abs(f_3dB_theory - fB_e) / fB_e * 100;
dc_gain_ok = theoretical_mag_dB(1) > 30;
bandwidth_ok = bandwidth_error < 30;
rolloff_ok = interp1(freq_test, theoretical_mag_dB, 2*fB_e) < -10;

fprintf('✓ DC 增益 > 30 dB: %s\n', bool2str(dc_gain_ok));
fprintf('✓ 頻寬誤差 < 30%%: %s (%.1f%%)\n', bool2str(bandwidth_ok), bandwidth_error);
fprintf('✓ 高頻衰減良好: %s\n', bool2str(rolloff_ok));
fprintf('\n');

if dc_gain_ok && bandwidth_ok && rolloff_ok
    fprintf('═══════════════════════════════════════\n');
    fprintf('    ✅ Observer 設計驗證通過！\n');
    fprintf('═══════════════════════════════════════\n');
else
    fprintf('═══════════════════════════════════════\n');
    fprintf('    ⚠️ Observer 需要調整\n');
    fprintf('═══════════════════════════════════════\n');
end

fprintf('\n');

% 輔助函數
function str = bool2str(val)
    if val
        str = '✅ 通過';
    else
        str = '❌ 未通過';
    end
end