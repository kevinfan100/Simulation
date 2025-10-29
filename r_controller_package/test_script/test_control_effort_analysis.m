% test_control_effort_analysis.m
% 完整自動化測試：驗證 Control Effort 與頻率響應的關係
%
% 直接執行即可，無需手動操作！

clear; clc; close all;

fprintf('=====================================\n');
fprintf('   Control Effort 完整分析測試\n');
fprintf('=====================================\n');
fprintf('這個測試會自動執行兩個配置並分析結果\n\n');

%% ========== 初始化 ==========

% 添加路徑
script_dir = fileparts(mfilename('fullpath'));
package_root = fullfile(script_dir, '..');
addpath(fullfile(package_root, 'model'));

% 測試參數（固定）
Channel = 2;
Amplitude = 0.5;
Frequency = 1000;
signal_type_name = 'sine';
T = 1e-5;
Ts = T;
fs = 1/T;

% 控制器類型
CONTROLLER_TYPE = 'general';  % 使用 general 版本

% 模型參數
model_name = 'r_controller_system_integrated';
model_path = fullfile(package_root, 'model', [model_name '.slx']);

% 系統常數
k_o = 5.6695e-4;
b = 0.9782;
a1 = 1.934848;
a2 = -0.935970;

% 其他必要變數
Phase = 0;
StepTime = 0;
SignalType = 1;  % Sine
d = 0;
solver = 'ode45';
DISPLAY_MODE = 'simplified';

% 測試配置
test_configs = [
    3600, 18000;  % 高頻寬
    500, 2500;    % 低頻寬
];

% 儲存結果
results = struct();

%% ========== 執行測試 ==========

fprintf('【開始測試】\n');
fprintf('────────────────────────\n');

for test_idx = 1:size(test_configs, 1)

    fprintf('\n測試 %d/%d: fB_c = %d Hz, fB_e = %d Hz\n', ...
            test_idx, size(test_configs, 1), ...
            test_configs(test_idx, 1), test_configs(test_idx, 2));
    fprintf('執行中...');

    % 設定參數
    fB_c = test_configs(test_idx, 1);
    fB_e = test_configs(test_idx, 2);

    % 計算控制器參數
    lambda_c = exp(-fB_c * T * 2 * pi);
    lambda_e = exp(-fB_e * T * 2 * pi);
    beta = sqrt(lambda_e * lambda_c);

    % 根據控制器類型計算參數
    if strcmpi(CONTROLLER_TYPE, 'general')
        params = r_controller_calc_params(fB_c, fB_e);
    else
        params = r_controller_calc_params_p2(fB_c, fB_e);
    end

    % 載入模型
    if ~bdIsLoaded(model_name)
        load_system(model_path);
    end

    % 設定模擬時間（確保足夠穩定）
    sim_time = 0.2;  % 200ms
    set_param(model_name, 'StopTime', num2str(sim_time));
    set_param(model_name, 'Solver', solver);
    set_param(model_name, 'MaxStep', num2str(T/10));

    % 執行模擬
    try
        % 確保所有變數在 base workspace
        assignin('base', 'Channel', Channel);
        assignin('base', 'Amplitude', Amplitude);
        assignin('base', 'Frequency', Frequency);
        assignin('base', 'SignalType', SignalType);
        assignin('base', 'Phase', Phase);
        assignin('base', 'StepTime', StepTime);
        assignin('base', 'T', T);
        assignin('base', 'Ts', Ts);
        assignin('base', 'params', params);
        assignin('base', 'd', d);
        assignin('base', 'lambda_c', lambda_c);
        assignin('base', 'lambda_e', lambda_e);
        assignin('base', 'beta', beta);
        assignin('base', 'fB_c', fB_c);
        assignin('base', 'fB_e', fB_e);

        out = sim(model_name);
        fprintf(' 完成！\n');
    catch ME
        fprintf(' 失敗！\n');
        error('模擬失敗: %s', ME.message);
    end

    % 提取數據
    u_data = out.u;
    Vm_data = out.Vm;
    Vd_data = out.Vd;
    t = (0:size(u_data, 1)-1)' * T;

    % 診斷輸出
    fprintf('  數據大小: u[%d×%d], Vm[%d×%d], Vd[%d×%d]\n', ...
            size(u_data,1), size(u_data,2), ...
            size(Vm_data,1), size(Vm_data,2), ...
            size(Vd_data,1), size(Vd_data,2));
    fprintf('  u max: %.3f, Vm max: %.3f, Vd max: %.3f\n', ...
            max(abs(u_data(:))), max(abs(Vm_data(:))), max(abs(Vd_data(:))));

    % 特別檢查激勵通道
    fprintf('  Vd[Channel %d] max: %.3f (應該約等於 %.3f)\n', ...
            Channel, max(abs(Vd_data(:,Channel))), Amplitude);

    % 如果控制輸出為 0，顯示警告
    if max(abs(u_data(:))) < 1e-6
        fprintf('  ⚠️ 警告：控制輸出為 0！可能原因：\n');
        fprintf('     - Simulink 模型中的控制器未正確連接\n');
        fprintf('     - 參數未正確傳入\n');
        fprintf('     - 控制器類型設定錯誤\n');
    end

    % 儲存完整數據
    results(test_idx).fB_c = fB_c;
    results(test_idx).fB_e = fB_e;
    results(test_idx).u_data = u_data;
    results(test_idx).t = t;
    results(test_idx).ku = params.Value.ku;

    % 計算 RMS（只取後半部分，確保穩態）
    idx_steady = t > sim_time/2;
    u_steady = u_data(idx_steady, Channel);
    results(test_idx).rms = rms(u_steady);

    fprintf('  ku = %.2f\n', params.Value.ku);
    fprintf('  RMS = %.3f V\n', results(test_idx).rms);
end

% 關閉模型
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

%% ========== 分析結果 ==========

fprintf('\n=====================================\n');
fprintf('           結果分析\n');
fprintf('=====================================\n\n');

% 1. RMS 比較
fprintf('【RMS 比較】\n');
fprintf('────────────\n');
rms_ratio = results(2).rms / results(1).rms;
fprintf('fB_c = %d Hz: RMS = %.3f V\n', results(1).fB_c, results(1).rms);
fprintf('fB_c = %d Hz: RMS = %.3f V\n', results(2).fB_c, results(2).rms);
fprintf('RMS 降幅: %.1f%%\n\n', (1 - rms_ratio) * 100);

% 2. FFT 分析 - 提取 1000 Hz 成分
fprintf('【FFT 分析 - 1000 Hz 成分】\n');
fprintf('──────────────────────────\n');

mag_1k = zeros(2, 1);

for test_idx = 1:2
    % FFT
    u_ch = results(test_idx).u_data(:, Channel);
    N = length(u_ch);
    U_fft = fft(u_ch);
    f_axis = (0:N-1) * fs / N;

    % 找 1000 Hz
    [~, idx_1k] = min(abs(f_axis - Frequency));
    mag_1k(test_idx) = abs(U_fft(idx_1k)) * 2 / N;

    fprintf('fB_c = %d Hz: %.3f V\n', results(test_idx).fB_c, mag_1k(test_idx));
end

fft_ratio_db = 20*log10(mag_1k(2)/mag_1k(1));
fprintf('1000 Hz 成分降幅: %.1f dB\n\n', fft_ratio_db);

% 3. 理論預測
fprintf('【理論預測（Bode圖）】\n');
fprintf('──────────────────────\n');

for test_idx = 1:2
    fB_c = results(test_idx).fB_c;
    fB_e = results(test_idx).fB_e;

    % 建立轉移函數
    lambda_c = exp(-fB_c * 2 * pi * T);
    kc = (1 - lambda_c) / (1 + b);
    bc = b * kc;
    ku = kc / k_o;

    num = ku * [1, -a1, -a2];
    den = [1, -(1-bc), -bc];
    Gc = tf(num, den, T, 'Variable', 'z^-1');

    % 計算 1000 Hz 增益
    [mag, ~] = bode(Gc, 2*pi*Frequency);
    results(test_idx).theory_gain = mag;
    results(test_idx).theory_gain_db = 20*log10(mag);

    fprintf('fB_c = %d Hz: %.1f dB\n', fB_c, results(test_idx).theory_gain_db);
end

theory_ratio_db = results(2).theory_gain_db - results(1).theory_gain_db;
fprintf('理論預測降幅: %.1f dB\n\n', theory_ratio_db);

% 4. 驗證結果
fprintf('【驗證結果】\n');
fprintf('=====================================\n\n');

fprintf('項目              | 實測      | 理論      | 差異\n');
fprintf('------------------|-----------|-----------|-------\n');
fprintf('ku 比例           | %.1f%%    | %.1f%%    | -\n', ...
        results(2).ku/results(1).ku*100, results(2).ku/results(1).ku*100);
fprintf('1000Hz降幅(dB)    | %.1f dB   | %.1f dB   | %.1f dB\n', ...
        fft_ratio_db, theory_ratio_db, fft_ratio_db - theory_ratio_db);
fprintf('RMS 降幅          | %.1f%%    | -         | -\n', ...
        (1 - rms_ratio) * 100);

% 判斷是否符合
tolerance_db = 3;  % 容許誤差 3 dB
if abs(fft_ratio_db - theory_ratio_db) < tolerance_db
    fprintf('\n✅ 1000 Hz 成分符合理論預測（誤差 < %.1f dB）\n', tolerance_db);
else
    fprintf('\n⚠️ 1000 Hz 成分與理論不符（誤差 > %.1f dB）\n', tolerance_db);
end

%% ========== 繪圖 ==========

% 圖 1：時域信號比較
figure('Name', 'Control Effort Analysis', 'Position', [100, 100, 1200, 800]);

% 子圖 1-2：時域信號（最後 10 個週期）
period = 1/Frequency;
display_time = 10 * period;  % 顯示 10 個週期

for test_idx = 1:2
    subplot(3, 3, test_idx);

    t = results(test_idx).t;
    u = results(test_idx).u_data(:, Channel);

    % 只顯示最後部分
    idx_display = t >= (t(end) - display_time);

    plot(t(idx_display)*1000, u(idx_display), 'LineWidth', 1.5);
    grid on;
    xlabel('Time (ms)');
    ylabel('Control u (V)');
    title(sprintf('fB_c = %d Hz (RMS=%.2fV)', ...
                  results(test_idx).fB_c, results(test_idx).rms));

    % 設定 ylim（避免零值錯誤）
    y_max = max(abs(u(idx_display)));
    if y_max < 1e-6
        y_max = 1;  % 預設值
    end
    ylim([-y_max*1.1, y_max*1.1]);
end

% 子圖 3：FFT 頻譜
subplot(3, 3, 3);
colors = lines(2);
for test_idx = 1:2
    u_ch = results(test_idx).u_data(:, Channel);
    N = length(u_ch);
    U_fft = fft(u_ch);
    f_axis = (0:N-1) * fs / N;

    % 只顯示到 5 kHz
    idx_show = f_axis <= 5000;

    semilogy(f_axis(idx_show)/1000, abs(U_fft(idx_show))*2/N, ...
             'LineWidth', 1.5, 'Color', colors(test_idx,:));
    hold on;
end
plot([1 1], [1e-4 10], 'k--', 'LineWidth', 1);
grid on;
xlabel('Frequency (kHz)');
ylabel('Amplitude (V)');
title('FFT Spectrum');
legend(sprintf('fB_c=%d', results(1).fB_c), ...
       sprintf('fB_c=%d', results(2).fB_c), ...
       '1 kHz', 'Location', 'best');
xlim([0 5]);
ylim([1e-4 10]);

% 子圖 4-5：Bode 圖
freq_plot = logspace(0, 4, 200);  % 1 Hz to 10 kHz

for test_idx = 1:2
    subplot(3, 3, 3 + test_idx);

    fB_c = results(test_idx).fB_c;
    fB_e = results(test_idx).fB_e;

    % 建立轉移函數
    lambda_c = exp(-fB_c * 2 * pi * T);
    kc = (1 - lambda_c) / (1 + b);
    bc = b * kc;
    ku = kc / k_o;

    num = ku * [1, -a1, -a2];
    den = [1, -(1-bc), -bc];
    Gc = tf(num, den, T, 'Variable', 'z^-1');

    % 計算頻率響應
    [mag, ~] = bode(Gc, 2*pi*freq_plot);
    mag_db = 20*log10(squeeze(mag));

    semilogx(freq_plot, mag_db, 'LineWidth', 2, 'Color', colors(test_idx,:));
    hold on;
    plot([1000 1000], [min(mag_db) max(mag_db)], 'k--', 'LineWidth', 1);

    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Gain (dB)');
    title(sprintf('fB_c = %d Hz', fB_c));
    xlim([1 10000]);
end

% 子圖 6：Bode 圖比較（疊圖）
subplot(3, 3, 6);
for test_idx = 1:2
    fB_c = results(test_idx).fB_c;
    fB_e = results(test_idx).fB_e;

    lambda_c = exp(-fB_c * 2 * pi * T);
    kc = (1 - lambda_c) / (1 + b);
    bc = b * kc;
    ku = kc / k_o;

    num = ku * [1, -a1, -a2];
    den = [1, -(1-bc), -bc];
    Gc = tf(num, den, T, 'Variable', 'z^-1');

    [mag, ~] = bode(Gc, 2*pi*freq_plot);
    mag_db = 20*log10(squeeze(mag));

    semilogx(freq_plot, mag_db, 'LineWidth', 2, 'Color', colors(test_idx,:));
    hold on;
end
plot([1000 1000], [40 90], 'k--', 'LineWidth', 1);
grid on;
xlabel('Frequency (Hz)');
ylabel('Gain (dB)');
title('Bode Plot Comparison');
legend(sprintf('fB_c=%d', results(1).fB_c), ...
       sprintf('fB_c=%d', results(2).fB_c), ...
       '1 kHz', 'Location', 'southwest');
xlim([1 10000]);

% 子圖 7-9：比較分析
subplot(3, 3, 7);
bar_data = [results(1).ku, results(2).ku];
bar(bar_data, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'XTickLabel', {sprintf('fB_c=%d', results(1).fB_c), ...
                        sprintf('fB_c=%d', results(2).fB_c)});
ylabel('ku');
title('Control Gain ku');
grid on;

subplot(3, 3, 8);
bar_data = [mag_1k(1), mag_1k(2)];
bar(bar_data, 'FaceColor', [0.9 0.6 0.3]);
set(gca, 'XTickLabel', {sprintf('fB_c=%d', results(1).fB_c), ...
                        sprintf('fB_c=%d', results(2).fB_c)});
ylabel('Amplitude (V)');
title('1000 Hz Component (FFT)');
grid on;

subplot(3, 3, 9);
bar_data = [results(1).rms, results(2).rms];
bar(bar_data, 'FaceColor', [0.6 0.9 0.3]);
set(gca, 'XTickLabel', {sprintf('fB_c=%d', results(1).fB_c), ...
                        sprintf('fB_c=%d', results(2).fB_c)});
ylabel('RMS (V)');
title('Total RMS');
grid on;

sgtitle('Control Effort Analysis: Theory vs Measurement');

%% ========== 最終結論 ==========

fprintf('\n=====================================\n');
fprintf('           最終結論\n');
fprintf('=====================================\n\n');

fprintf('1. ku 降低: %.1f%% → %.1f%%\n', 100, results(2).ku/results(1).ku*100);
fprintf('2. 1000 Hz 成分降低: %.1f dB (實測) vs %.1f dB (理論)\n', ...
        fft_ratio_db, theory_ratio_db);
fprintf('3. 總 RMS 降低: %.1f%%\n', (1 - rms_ratio) * 100);

fprintf('\n解釋：\n');
if abs(fft_ratio_db - theory_ratio_db) < tolerance_db
    fprintf('✅ 系統行為正確！\n');
    fprintf('   - Bode 圖正確預測了 1000 Hz 的增益變化\n');
    fprintf('   - RMS 降幅較小是因為：\n');
    fprintf('     • 控制器的遞迴結構維持了部分能量\n');
    fprintf('     • 其他頻率成分沒有同比例降低\n');
    fprintf('     • 這是 R Controller 的設計特性\n');
else
    fprintf('⚠️ 系統可能有問題\n');
    fprintf('   - 1000 Hz 增益變化與理論不符\n');
    fprintf('   - 可能需要檢查：\n');
    fprintf('     • Simulink 模型設定\n');
    fprintf('     • 控制器函數版本\n');
    fprintf('     • 參數傳遞\n');
end

fprintf('\n測試完成！\n');
fprintf('=====================================\n');