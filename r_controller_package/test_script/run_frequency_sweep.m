% run_frequency_sweep.m
% 頻率響應測試腳本 - Bode Plot 分析
%
% 功能：
%   1. 掃過多個頻率點（1 Hz ~ 4 kHz, 25 點）
%   2. 對比不同 d 值（d=0, d=2）的頻率響應
%   3. 使用 FFT 分析計算增益和相位
%   4. 繪製 Bode Plot
%   5. 儲存結果（.mat 和 .png）

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           R Controller 頻率響應測試 (Bode Plot)\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 測試配置 

% 添加必要的路徑
script_dir = fileparts(mfilename('fullpath'));
package_root = fullfile(script_dir, '..');
addpath(fullfile(package_root, 'model'));

% 頻率向量（對數分佈）
frequencies = logspace(0, log10(4000), 25);  % 1 Hz ~ 4 kHz, 25 點

% 測試的 d 值
d_values = [0, 2];

% Vd Generator 設定
signal_type_name = 'sine';
Channel = 3;              % 激勵通道 (P5)
Amplitude = 1;            % 振幅 [V]
Phase = 0;                % 相位 [deg]
SignalType = 1;           % Sine mode

% Controller 參數
T = 1e-5;                 % 採樣時間 [s] (100 kHz)
fB_c = 3200;              % 控制器頻寬 [Hz]
fB_e = 16000;             % 估測器頻寬 [Hz]

% Simulink 參數
Ts = 1e-5;                % 採樣時間 [s] (100 kHz)
solver = 'ode5';          % 固定步長 solver
StepTime = 0;             % Step 時間（不使用）

% 模擬時間設定
total_cycles = 90;        % 總週期數（50 暫態 + 40 穩態）
skip_cycles = 50;         % 跳過暫態週期數
fft_cycles = 40;          % FFT 分析週期數
min_sim_time = 0.1;       % 最小模擬時間 [s]（高頻用）
max_sim_time = Inf;       % 最大模擬時間 [s]（不設限）

% 輸出設定
output_dir = 'freq_response_results';
test_timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% 模型設定
model_name = 'r_controller_system_integrated';
model_path = fullfile(package_root, 'model', [model_name '.slx']);

%% SECTION 2: 初始化 

fprintf('【測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  頻率範圍: %.1f Hz ~ %.1f kHz\n', frequencies(1), frequencies(end)/1000);
fprintf('  頻率點數: %d\n', length(frequencies));
fprintf('  d 值: [%s]\n', num2str(d_values));
fprintf('  激勵通道: P%d\n', Channel);
fprintf('  振幅: %.2f V\n', Amplitude);
fprintf('  控制器頻寬: %.1f kHz\n', fB_c/1000);
fprintf('  估測器頻寬: %.1f kHz\n', fB_e/1000);
fprintf('  總週期數: %d (跳過 %d, 分析 %d)\n', total_cycles, skip_cycles, fft_cycles);
fprintf('  Solver: %s (固定步長)\n', solver);
fprintf('\n');

% 檢查模型
if ~exist(model_path, 'file')
    error('找不到模型檔案: %s', model_path);
end

% 創建輸出目錄
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('  ✓ 已創建輸出目錄: %s\n', output_dir);
end

% 開啟模型
if ~bdIsLoaded(model_name)
    open_system(model_path);
    fprintf('  ✓ 模型已開啟\n');
else
    fprintf('  ✓ 模型已載入\n');
end

% 計算 lambda 參數
lambda_c = exp(-fB_c*T*2*pi);
lambda_e = exp(-fB_e*T*2*pi);
beta = sqrt(lambda_e * lambda_c);

fprintf('\n');

%%  SECTION 3: 頻率掃描主迴圈 

% 初始化結果結構
num_d = length(d_values);
num_freq = length(frequencies);

for d_idx = 1:num_d
    d = d_values(d_idx);

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('  開始測試 d = %d\n', d);
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    % 初始化此 d 值的結果矩陣
    magnitude_ratio_all = zeros(num_freq, 6);
    phase_lag_all = zeros(num_freq, 6);
    sim_times = zeros(num_freq, 1);

    % 頻率掃描
    for freq_idx = 1:num_freq
        Frequency = frequencies(freq_idx);
        period = 1 / Frequency;

        % 計算模擬時間
        sim_time = total_cycles * period;
        sim_time = max(min_sim_time, min(sim_time, max_sim_time));
        sim_times(freq_idx) = sim_time;

        fprintf('────────────────────────────────────────────────────────\n');
        fprintf('[%2d/%2d] 測試頻率: %8.2f Hz (週期: %.4f s, 模擬: %.2f s)\n', ...
                freq_idx, num_freq, Frequency, period, sim_time);
        fprintf('        當前 d 值: %d\n', d);
        fprintf('────────────────────────────────────────────────────────\n');

        % 設定 Simulink 模擬參數
        set_param(model_name, 'StopTime', num2str(sim_time));
        set_param(model_name, 'Solver', solver);
        set_param(model_name, 'FixedStep', num2str(Ts));

        % 執行模擬
        fprintf('  ⏳ 執行模擬中（d=%d）...\n', d);
        tic;
        try
            out = sim(model_name);
            elapsed = toc;
            fprintf('  ✓ 模擬完成 (耗時 %.2f 秒)\n', elapsed);
        catch ME
            fprintf('  ✗ 模擬失敗: %s\n', ME.message);
            continue;
        end

        % 提取數據
        try
            Vd_data = out.Vd;
            Vm_data = out.Vm;

            N = size(Vd_data, 1);
            t = (0:N-1)' * Ts;

            fprintf('  ✓ 數據提取完成 (數據點: %d, 時間: %.2f s)\n', N, t(end));
        catch ME
            fprintf('  ✗ 數據提取失敗: %s\n', ME.message);
            continue;
        end

        % 選取穩態數據（跳過前 skip_cycles 個週期）
        skip_time = skip_cycles * period;
        fft_time = fft_cycles * period;

        t_start = skip_time;
        t_end = min(skip_time + fft_time, t(end));

        idx_steady = (t >= t_start) & (t <= t_end);

        if sum(idx_steady) < 100
            fprintf('  ✗ 穩態數據點不足 (%d 點)，跳過此頻率\n', sum(idx_steady));
            continue;
        end

        Vd_steady = Vd_data(idx_steady, :);
        Vm_steady = Vm_data(idx_steady, :);
        t_steady = t(idx_steady);

        actual_cycles = (t_end - t_start) / period;
        fprintf('  ✓ 穩態數據選取: %.2f ~ %.2f s (%.1f 個週期, %d 點)\n', ...
                t_start, t_end, actual_cycles, sum(idx_steady));

        % FFT 分析
        fprintf('  📊 執行 FFT 分析...\n');

        N_fft = length(Vd_steady);
        fs = 1 / Ts;
        freq_axis = (0:N_fft-1) * fs / N_fft;

        % 找到激勵頻率對應的 bin
        [~, freq_bin_idx] = min(abs(freq_axis - Frequency));
        actual_freq = freq_axis(freq_bin_idx);

        % 對激勵通道的 Vd 做 FFT
        Vd_fft = fft(Vd_steady(:, Channel));
        Vd_mag = abs(Vd_fft(freq_bin_idx)) * 2 / N_fft;
        Vd_phase = angle(Vd_fft(freq_bin_idx)) * 180 / pi;

        % 對所有 Vm 通道做 FFT
        for ch = 1:6
            Vm_fft = fft(Vm_steady(:, ch));
            Vm_mag = abs(Vm_fft(freq_bin_idx)) * 2 / N_fft;
            Vm_phase = angle(Vm_fft(freq_bin_idx)) * 180 / pi;

            % 計算頻率響應
            magnitude_ratio_all(freq_idx, ch) = Vm_mag / Vd_mag;
            phase_lag_all(freq_idx, ch) = Vm_phase - Vd_phase;

            % 相位正規化到 [-180, 180]
            while phase_lag_all(freq_idx, ch) > 180
                phase_lag_all(freq_idx, ch) = phase_lag_all(freq_idx, ch) - 360;
            end
            while phase_lag_all(freq_idx, ch) < -180
                phase_lag_all(freq_idx, ch) = phase_lag_all(freq_idx, ch) + 360;
            end
        end

        fprintf('  ✓ FFT 完成 (頻率 bin: %.2f Hz, P%d 增益: %.2f%%)\n', ...
                actual_freq, Channel, magnitude_ratio_all(freq_idx, Channel)*100);
        fprintf('\n');
    end

    % 儲存此 d 值的結果
    results(d_idx).d_value = d;
    results(d_idx).frequencies = frequencies;
    results(d_idx).magnitude_ratio = magnitude_ratio_all;
    results(d_idx).phase_lag = phase_lag_all;
    results(d_idx).magnitude_dB = 20 * log10(magnitude_ratio_all);
    results(d_idx).sim_times = sim_times;
    results(d_idx).Channel = Channel;
    results(d_idx).fB_c = fB_c;
    results(d_idx).fB_e = fB_e;

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('  d = %d 測試完成！\n', d);
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('\n\n');
end

%%  SECTION 4: 繪製 Bode Plot 

fprintf('【繪製 Bode Plot】\n');
fprintf('────────────────────────\n');

% 顏色設定
colors_d = [
    0.0000, 0.4470, 0.7410;  % d=0: 藍色
    0.8500, 0.3250, 0.0980;  % d=2: 橘色
];

channel_colors = [
    0.0000, 0.0000, 0.0000;  % P1: 黑色
    0.0000, 0.0000, 1.0000;  % P2: 藍色
    0.0000, 0.5000, 0.0000;  % P3: 綠色
    1.0000, 0.0000, 0.0000;  % P4: 紅色
    0.8000, 0.0000, 0.8000;  % P5: 粉紫色
    0.0000, 0.7500, 0.7500;  % P6: 青色
];

% === 圖 1 & 2: 各 d 值的所有通道響應 ===
for d_idx = 1:num_d
    d = results(d_idx).d_value;

    fig = figure('Name', sprintf('Frequency Response - d=%d (Ch P%d)', d, Channel), ...
                 'Position', [100+50*d_idx, 100+50*d_idx, 1200, 800]);

    % 計算線性增益比（不是 dB）
    magnitude_ratio = results(d_idx).magnitude_ratio;

    % ===== 上圖：Magnitude（線性刻度 0~1.25，所有通道）=====
    subplot(2,1,1);
    hold on; grid off;

    for ch = 1:6
        mag = magnitude_ratio(:, ch);

        if ch == Channel
            % 激勵通道：粗實線
            semilogx(frequencies, mag, '-', 'LineWidth', 3, ...
                     'Color', channel_colors(ch, :), ...
                     'DisplayName', sprintf('P%d (Excited)', ch));
        else
            % 其他通道：細虛線
            semilogx(frequencies, mag, '--', 'LineWidth', 1.5, ...
                     'Color', channel_colors(ch, :), ...
                     'DisplayName', sprintf('P%d', ch));
        end
    end

    % 設定 Y 軸範圍
    ylim([0, 1.25]);

    xlabel('Frequency [Hz]', 'FontSize', 12);
    ylabel('Magnitude Ratio', 'FontSize', 12);
    title(sprintf('Frequency Response - d=%d (Excited Ch: P%d)', d, Channel), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'NumColumns', 2, 'FontSize', 10);
    xlim([frequencies(1), frequencies(end)]);

    % 設定 X 軸刻度為 10^n 格式
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11);

    % ===== 下圖：Phase（只顯示 P5）=====
    subplot(2,1,2);
    hold on; grid off;

    phase_ch = results(d_idx).phase_lag(:, Channel);

    semilogx(frequencies, phase_ch, '-o', 'LineWidth', 2.5, ...
             'Color', channel_colors(Channel, :), 'MarkerSize', 6, ...
             'DisplayName', sprintf('P%d (Excited)', Channel));

    xlabel('Frequency [Hz]', 'FontSize', 12);
    ylabel('Phase [deg]', 'FontSize', 12);
    title(sprintf('Phase Response - P%d', Channel), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10);
    xlim([frequencies(1), frequencies(end)]);

    % 設定 X 軸刻度為 10^n 格式
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11);

    fprintf('  ✓ 圖 %d: d=%d 完成\n', d_idx, d);
end

% === 圖 3: 相位對比（d=0 vs d=2，單圖）===
if num_d == 2
    fig_compare = figure('Name', 'Phase Comparison (d=0 vs d=2)', ...
                         'Position', [200, 200, 1200, 600]);

    % 提取兩個 d 值的相位
    phase_d0 = results(1).phase_lag(:, Channel);
    phase_d2 = results(2).phase_lag(:, Channel);

    % ===== 相位對比曲線（單圖）=====
    hold on; grid off;

    % 使用更鮮明的顏色和更粗的線
    semilogx(frequencies, phase_d0, '-o', 'LineWidth', 3.5, ...
             'Color', [0, 0.4470, 0.7410], 'MarkerSize', 8, ...
             'MarkerFaceColor', [0, 0.4470, 0.7410], ...
             'DisplayName', sprintf('P%d (d=0)', Channel));

    semilogx(frequencies, phase_d2, '-s', 'LineWidth', 3.5, ...
             'Color', [0.8500, 0.3250, 0.0980], 'MarkerSize', 8, ...
             'MarkerFaceColor', [0.8500, 0.3250, 0.0980], ...
             'DisplayName', sprintf('P%d (d=2)', Channel));

    xlabel('Frequency [Hz]', 'FontSize', 14);
    ylabel('Phase [deg]', 'FontSize', 14);
    title(sprintf('Phase Comparison - P%d (d=0 vs d=2)', Channel), ...
          'FontSize', 16, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 13);
    xlim([frequencies(1), frequencies(end)]);
    ylim([-50, 0]);  % 限定 Y 軸範圍：-50° ~ 0°

    % 設定 X 軸刻度為 10^n 格式
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 12);

    fprintf('  ✓ 圖 3: 相位對比完成\n');
end

fprintf('\n');

%% SECTION 5: 分析與顯示結果 

fprintf('【頻率響應分析結果】\n');
fprintf('════════════════════════════════════════════════════════════\n');

for d_idx = 1:num_d
    d = results(d_idx).d_value;
    mag_dB = results(d_idx).magnitude_dB(:, Channel);

    fprintf('\n[ d = %d ]\n', d);
    fprintf('────────────────────────────────────────────────────────\n');

    % 找 -3dB 頻寬
    idx_3dB = find(mag_dB < -3, 1, 'first');
    if ~isempty(idx_3dB)
        f_3dB = frequencies(idx_3dB);
        fprintf('  -3dB 頻寬: %.2f Hz\n', f_3dB);
    else
        fprintf('  -3dB 頻寬: > %.2f Hz (未達到)\n', frequencies(end));
    end

    % DC 增益（最低頻）
    dc_gain_dB = mag_dB(1);
    fprintf('  DC 增益 (%.1f Hz): %.2f dB (%.2f%%)\n', ...
            frequencies(1), dc_gain_dB, 10^(dc_gain_dB/20)*100);

    % 高頻增益（最高頻）
    hf_gain_dB = mag_dB(end);
    fprintf('  高頻增益 (%.1f Hz): %.2f dB (%.2f%%)\n', ...
            frequencies(end), hf_gain_dB, 10^(hf_gain_dB/20)*100);

    % 最大增益
    [max_gain_dB, max_idx] = max(mag_dB);
    fprintf('  最大增益: %.2f dB at %.2f Hz\n', max_gain_dB, frequencies(max_idx));

    fprintf('\n');
end

fprintf('════════════════════════════════════════════════════════════\n');

% 顯示相位差統計（如果有 d=0 和 d=2）
if num_d == 2
    phase_d0 = results(1).phase_lag(:, Channel);
    phase_d2 = results(2).phase_lag(:, Channel);
    delta_phase = phase_d0 - phase_d2;

    fprintf('\n【相位差統計 (d=0 vs d=2)】\n');
    fprintf('────────────────────────────────────────────────────────\n');

    mean_delta = mean(delta_phase);
    max_delta = max(delta_phase);
    min_delta = min(delta_phase);

    [~, max_idx] = max(delta_phase);
    [~, min_idx] = min(delta_phase);

    fprintf('  平均 Δphase: %.2f°\n', mean_delta);
    fprintf('  最大 Δphase: %.2f° (at %.2f Hz)\n', max_delta, frequencies(max_idx));
    fprintf('  最小 Δphase: %.2f° (at %.2f Hz)\n', min_delta, frequencies(min_idx));
    fprintf('\n');

    if mean_delta < 0
        fprintf('  → d=0 的相位平均比 d=2 更負 %.2f°\n', abs(mean_delta));
    else
        fprintf('  → d=0 的相位平均比 d=2 更正 %.2f°\n', mean_delta);
    end

    fprintf('\n');
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 6: 儲存結果 

fprintf('【儲存結果】\n');
fprintf('────────────────────────\n');

% 儲存 .mat 檔案
mat_filename = fullfile(output_dir, sprintf('freq_response_ch%d_%s.mat', Channel, test_timestamp));
save(mat_filename, 'results', 'frequencies', 'd_values', 'Channel', 'fB_c', 'fB_e');
fprintf('  ✓ 已儲存: %s\n', mat_filename);

% 儲存圖片
for d_idx = 1:num_d
    d = results(d_idx).d_value;
    saveas(figure(d_idx), fullfile(output_dir, sprintf('freq_response_d%d_ch%d_%s.png', d, Channel, test_timestamp)));
    fprintf('  ✓ 已儲存: freq_response_d%d_ch%d_%s.png\n', d, Channel, test_timestamp);
end

% 儲存相位對比圖（如果有）
if num_d == 2
    saveas(fig_compare, fullfile(output_dir, sprintf('phase_compare_ch%d_%s.png', Channel, test_timestamp)));
    fprintf('  ✓ 已儲存: phase_compare_ch%d_%s.png\n', Channel, test_timestamp);
end

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  頻率響應測試完成！\n');
fprintf('  結果已儲存至: %s\n', output_dir);
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
