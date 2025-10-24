% run_frequency_sweep.m
% PI Controller 頻率響應測試腳本 - Bode Plot 分析
%
% 功能：
%   1. 掃過多個頻率點（1 Hz ~ 2 kHz, ~27 點）
%   2. 低頻對數分布（稀疏），高頻線性分布（密集）
%   3. 使用 FFT 分析計算增益和相位
%   4. 繪製 Bode Plot
%   5. 儲存結果（.mat 和 .png）

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           PI Controller 頻率響應測試 (Bode Plot)\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 測試配置

% 添加必要的路徑
script_dir = fileparts(mfilename('fullpath'));
scripts_root = fullfile(script_dir, '..');
project_root = fullfile(scripts_root, '..');
addpath(fullfile(scripts_root, 'common'));
addpath(fullfile(project_root, 'controllers', 'pi_controller'));

% 頻率向量（低頻對數 + 高頻線性）
freq_low = logspace(0, 2, 5);           % 1~100 Hz, 8 點 (對數分布)
freq_high = linspace(100, 1500, 20);    % 100~1000 Hz, 20 點 (線性分布)
frequencies = unique(sort([freq_low, freq_high]));  % 合併並排序去重

% Vd Generator 設定
signal_type_name = 'sine';
Channel = 1;              % 激發通道 (1-6)，可自由設定
Amplitude = 0.5;          % 振幅 [V]
Phase = 0;                % 相位 [deg]
SignalType = 1;           % Sine mode

% PI 控制器參數
zc = 2206;                % Ki/Kp 
Kp_value = 2;             
Ki_value = Kp_value * zc; 

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
output_dir = fullfile(project_root, 'test_results', 'pi_controller', 'frequency_response');
test_timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% 模型設定
model_name = 'PI_Controller_Integrated';
controller_type = 'pi_controller';
model_path = fullfile(project_root, 'controllers', controller_type, [model_name '.slx']);

%% SECTION 2: 初始化

fprintf('【測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  頻率範圍: %.1f Hz ~ %.1f kHz\n', frequencies(1), frequencies(end)/1000);
fprintf('  頻率點數: %d 點\n', length(frequencies));
fprintf('    低頻段 (1-100 Hz): 對數分布\n');
fprintf('    高頻段 (100-2000 Hz): 線性分布\n');
fprintf('  激發通道: P%d\n', Channel);
fprintf('  振幅: %.2f V\n', Amplitude);
fprintf('  PI 參數: Kp=%.2f, Ki=%.2f (zc=%.0f)\n', Kp_value, Ki_value, zc);
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
else
    fprintf('  ✓ 輸出目錄已存在\n');
end

% 開啟模型
if ~bdIsLoaded(model_name)
    open_system(model_path);
    fprintf('  ✓ 模型已開啟\n');
else
    fprintf('  ✓ 模型已載入\n');
end

% 設定 PI 參數為 workspace 變數
fprintf('  正在配置 PI 控制器參數...\n');
for ch = 1:6
    pi_block = sprintf('%s/PI controller/PI_Ch%d', model_name, ch);
    set_param(pi_block, 'P', 'Kp_value');
    set_param(pi_block, 'I', 'Ki_value');
end
fprintf('  ✓ PI 參數已配置為 workspace 變數\n');
fprintf('    - Kp: %.2f\n', Kp_value);
fprintf('    - Ki: %.2f\n', Ki_value);

fprintf('\n');

%% SECTION 3: 頻率掃描主迴圈

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  開始頻率掃描\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

% 初始化結果矩陣
num_freq = length(frequencies);
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
    fprintf('────────────────────────────────────────────────────────\n');

    % 設定 Simulink 模擬參數
    set_param(model_name, 'StopTime', num2str(sim_time));
    set_param(model_name, 'Solver', solver);
    set_param(model_name, 'FixedStep', num2str(Ts));

    % 執行模擬
    fprintf('  ⏳ 執行模擬中...\n');
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

% 儲存結果
results.frequencies = frequencies;
results.magnitude_ratio = magnitude_ratio_all;
results.phase_lag = phase_lag_all;
results.magnitude_dB = 20 * log10(magnitude_ratio_all);
results.sim_times = sim_times;
results.Channel = Channel;
results.Kp = Kp_value;
results.Ki = Ki_value;
results.zc = zc;

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  頻率掃描完成！\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n\n');

%% SECTION 4: 繪製 Bode Plot

fprintf('【繪製 Bode Plot】\n');
fprintf('────────────────────────\n');

% 顏色設定
channel_colors = [
    0.0000, 0.0000, 0.0000;  % P1: 黑色
    0.0000, 0.0000, 1.0000;  % P2: 藍色
    0.0000, 0.5000, 0.0000;  % P3: 綠色
    1.0000, 0.0000, 0.0000;  % P4: 紅色
    0.8000, 0.0000, 0.8000;  % P5: 粉紫色
    0.0000, 0.7500, 0.7500;  % P6: 青色
];

% === 圖 1: 所有通道的頻率響應 ===
fig = figure('Name', sprintf('PI Controller Frequency Response (Ch P%d)', Channel), ...
             'Position', [100, 100, 1200, 800]);

% 計算線性增益比
magnitude_ratio = results.magnitude_ratio;

% ===== 上圖：Magnitude（線性刻度 0~1.25，所有通道）=====
subplot(2,1,1);
hold on; grid on;

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

% === 計算並標註 -3dB 頻寬點 ===
mag_dB_excited = results.magnitude_dB(:, Channel);
idx_3dB = find(mag_dB_excited < -3, 1, 'first');

if ~isempty(idx_3dB) && idx_3dB > 1
    % 找到 -3dB 點
    f_3dB = frequencies(idx_3dB);
    mag_3dB = magnitude_ratio(idx_3dB, Channel);

    % 標註 -3dB 點（使用淺灰色圓圈，不突兀）
    semilogx(f_3dB, mag_3dB, 'o', ...
             'MarkerSize', 10, ...
             'MarkerEdgeColor', [0.5, 0.5, 0.5], ...
             'MarkerFaceColor', [0.8, 0.8, 0.8], ...
             'LineWidth', 2, ...
             'DisplayName', sprintf('-3dB @ %.1f Hz', f_3dB));

    % 加入垂直虛線輔助線（淺灰色）
    plot([f_3dB, f_3dB], [0, mag_3dB], '--', ...
         'Color', [0.6, 0.6, 0.6], 'LineWidth', 1.5, ...
         'HandleVisibility', 'off');
end

% 設定 Y 軸範圍
ylim([0, 1.25]);

xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('PI Controller Frequency Response (Excited Ch: P%d, Kp=%.2f, Ki=%.2f)', ...
      Channel, Kp_value, Ki_value), ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'NumColumns', 2, 'FontSize', 10);
xlim([frequencies(1), frequencies(end)]);

% 設定 X 軸刻度為 10^n 格式
set(gca, 'XScale', 'log');
set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
set(gca, 'FontSize', 11, 'FontWeight', 'bold');

% ===== 下圖：Phase（只顯示激發通道）=====
subplot(2,1,2);
hold on; grid on;

phase_ch = results.phase_lag(:, Channel);

semilogx(frequencies, phase_ch, '-o', 'LineWidth', 2.5, ...
         'Color', channel_colors(Channel, :), 'MarkerSize', 6, ...
         'DisplayName', sprintf('P%d (Excited)', Channel));

xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Phase [deg]', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Phase Response - P%d', Channel), ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([frequencies(1), frequencies(end)]);

% 設定 X 軸刻度為 10^n 格式
set(gca, 'XScale', 'log');
set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
set(gca, 'FontSize', 11, 'FontWeight', 'bold');

fprintf('  ✓ Bode Plot 完成\n');
fprintf('\n');

%% SECTION 5: 分析與顯示結果

fprintf('【頻率響應分析結果】\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
fprintf('  PI 參數: Kp = %.2f, Ki = %.2f (zc = %.0f)\n', Kp_value, Ki_value, zc);
fprintf('  激發通道: P%d\n\n', Channel);
fprintf('────────────────────────────────────────────────────────────\n');

mag_dB = results.magnitude_dB(:, Channel);

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

% 相位統計
phase_ch = results.phase_lag(:, Channel);
fprintf('\n  相位範圍: %.2f° ~ %.2f°\n', min(phase_ch), max(phase_ch));
fprintf('  平均相位: %.2f°\n', mean(phase_ch));

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');

%% SECTION 6: 保存結果

fprintf('\n【保存結果】\n');
fprintf('────────────────────────\n');

% 檔案命名
mat_filename = sprintf('freq_sweep_ch%d_%s.mat', Channel, test_timestamp);
png_filename = sprintf('freq_sweep_ch%d_%s.png', Channel, test_timestamp);

mat_path = fullfile(output_dir, mat_filename);
png_path = fullfile(output_dir, png_filename);

% 保存 .mat 檔案
save(mat_path, 'results', '-v7.3');
fprintf('  ✓ 數據已保存: %s\n', mat_filename);

% 保存 .png 圖片
saveas(fig, png_path);
fprintf('  ✓ 圖片已保存: %s\n', png_filename);

fprintf('\n  📁 所有檔案保存至: %s\n', output_dir);
fprintf('\n');

%% SECTION 7: 測試總結

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                     測試完成\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

fprintf('【測試摘要】\n');
fprintf('  控制器: PI Controller\n');
fprintf('  參數: Kp=%.2f, Ki=%.2f (zc=%.0f)\n', Kp_value, Ki_value, zc);
fprintf('  激發通道: P%d\n', Channel);
fprintf('  頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), num_freq);
fprintf('  總模擬時間: %.2f 分鐘\n', sum(sim_times)/60);
fprintf('  輸出位置: %s\n', output_dir);
fprintf('\n');

fprintf('測試腳本執行完畢！\n\n');
