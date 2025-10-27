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

% 頻率向量（使用 100,000 Hz 的因數，確保零 round() 誤差）
% 所有頻率都能產生整數的 samples_per_cycle，避免相位漂移問題
frequencies = [1, 5, 10, 20, 50, 100, ...        % 低頻段 (1-100 Hz): 6點
               125, 200, 250, 400, 500, ...      % 中頻段 (100-500 Hz): 5點
               625, 800, 1000, 1250, 2000];      % 高頻段 (500-2000 Hz): 5點

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
total_cycles = 120;       % 
skip_cycles = 80;         % 跳過暫態週期數（從 50 增加到 80）
fft_cycles = 40;          % FFT 分析週期數
min_sim_time = 0.1;       % 最小模擬時間 [s]（高頻用）
max_sim_time = Inf;       % 最大模擬時間 [s]（不設限）

% 品質檢測參數
steady_state_threshold = 0.02;  % 穩態檢測閾值 (1% of Amplitude)
thd_threshold = 1.0;            % THD 閾值 (1%)
dc_tolerance = 0.01;            % DC 值容忍度 (1% of Amplitude)

% 輸出設定
test_timestamp = datestr(now, 'yyyymmdd_HHMMSS');
test_folder_name = sprintf('ch%d_%s', Channel, test_timestamp);
output_dir = fullfile(project_root, 'test_results', 'pi_controller', 'frequency_response', test_folder_name);

% 模型設定
model_name = 'PI_Controller_Integrated';
controller_type = 'pi_controller';
model_path = fullfile(project_root, 'controllers', controller_type, [model_name '.slx']);

%% SECTION 2: 初始化

fprintf('【測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  頻率範圍: %.1f Hz ~ %.1f kHz\n', frequencies(1), frequencies(end)/1000);
fprintf('  頻率點數: %d 點（所有頻率均為 100kHz 的因數，確保零 round() 誤差）\n', length(frequencies));
fprintf('    低頻段 (1-100 Hz): 6 點\n');
fprintf('    中頻段 (100-500 Hz): 5 點\n');
fprintf('    高頻段 (500-2000 Hz): 5 點\n');
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

% 初始化品質檢測結果矩陣
quality_steady_state = true(num_freq, 6);  % 穩態檢測結果
quality_thd = zeros(num_freq, 6);          % THD 值 (%)
quality_dc_error = zeros(num_freq, 6);     % DC 誤差 (V)
quality_thd_pass = true(num_freq, 6);      % THD 檢測通過
quality_dc_pass = true(num_freq, 6);       % DC 檢測通過

% 創建診斷圖目錄
diagnostic_dir = fullfile(output_dir, 'diagnostics');
if ~exist(diagnostic_dir, 'dir')
    mkdir(diagnostic_dir);
end

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

    %% ========== 新增：品質檢測 ==========

    % === 1. 穩態檢測：檢查週期重複性 ===
    fprintf('  🔍 執行品質檢測...\n');

    samples_per_cycle = round(period / Ts);
    num_cycles_to_check = min(fft_cycles, floor(length(t_steady) / samples_per_cycle));

    for ch = 1:6
        % 提取每個週期的數據
        cycle_diffs = [];

        for k = 2:num_cycles_to_check
            idx_start_prev = (k-2) * samples_per_cycle + 1;
            idx_end_prev = (k-1) * samples_per_cycle;
            idx_start_curr = (k-1) * samples_per_cycle + 1;
            idx_end_curr = k * samples_per_cycle;

            if idx_end_curr <= length(Vm_steady(:, ch))
                cycle_prev = Vm_steady(idx_start_prev:idx_end_prev, ch);
                cycle_curr = Vm_steady(idx_start_curr:idx_end_curr, ch);

                % 計算相鄰週期的最大差異
                max_diff = max(abs(cycle_curr - cycle_prev));
                cycle_diffs = [cycle_diffs; max_diff];
            end
        end

        % 判斷穩態（所有週期差異都要小於閾值）
        threshold = steady_state_threshold * Amplitude;
        if ~isempty(cycle_diffs)
            quality_steady_state(freq_idx, ch) = all(cycle_diffs < threshold);

            % 如果未達穩態，保存診斷圖
            if ~quality_steady_state(freq_idx, ch)
                % 生成週期疊圖
                fig_diag = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
                hold on; grid on;

                for k = 1:num_cycles_to_check
                    idx_start = (k-1) * samples_per_cycle + 1;
                    idx_end = k * samples_per_cycle;

                    if idx_end <= length(Vm_steady(:, ch))
                        cycle_data = Vm_steady(idx_start:idx_end, ch);
                        t_cycle = (0:length(cycle_data)-1)' * Ts * 1000;  % ms

                        % 使用顏色漸層表示時間順序
                        color_intensity = (k-1) / (num_cycles_to_check-1);
                        plot(t_cycle, cycle_data, 'LineWidth', 1.5, ...
                             'Color', [color_intensity, 0, 1-color_intensity]);
                    end
                end

                xlabel('Time within Cycle [ms]', 'FontSize', 12, 'FontWeight', 'bold');
                ylabel('Vm [V]', 'FontSize', 12, 'FontWeight', 'bold');
                title(sprintf('Cycle Overlay - %.1f Hz, P%d (NOT STEADY)', Frequency, ch), ...
                      'FontSize', 14, 'FontWeight', 'bold', 'Color', 'r');

                % 添加圖例說明
                colormap(jet(num_cycles_to_check));
                cb = colorbar;
                cb.Label.String = 'Cycle Number';
                caxis([1, num_cycles_to_check]);

                % 保存診斷圖
                diag_filename = sprintf('steady_fail_%.1fHz_P%d.png', Frequency, ch);
                saveas(fig_diag, fullfile(diagnostic_dir, diag_filename));
                close(fig_diag);
            end
        else
            quality_steady_state(freq_idx, ch) = false;
        end
    end

    % === 2. THD 和 DC 值檢測 ===
    fs = 1 / Ts;

    for ch = 1:6
        % FFT 分析（用於 DC 檢測）
        Vm_fft_temp = fft(Vm_steady(:, ch));
        N_fft_temp = length(Vm_fft_temp);

        % DC 成分
        DC_value = abs(Vm_fft_temp(1)) / N_fft_temp;
        DC_target = 0;  % 純正弦波應該沒有 DC
        quality_dc_error(freq_idx, ch) = abs(DC_value - DC_target);
        quality_dc_pass(freq_idx, ch) = (quality_dc_error(freq_idx, ch) < dc_tolerance * Amplitude);

        % THD 計算
        try
            thd_dB = thd(Vm_steady(:, ch), fs, 10);
            thd_percent = 10^(thd_dB/20) * 100;
            quality_thd(freq_idx, ch) = thd_percent;
            quality_thd_pass(freq_idx, ch) = (thd_percent < thd_threshold);
        catch
            % 如果 THD 計算失敗（信號太差）
            quality_thd(freq_idx, ch) = NaN;
            quality_thd_pass(freq_idx, ch) = false;
        end
    end

    % === 3. 顯示品質檢測結果 ===
    fprintf('  ✓ 品質檢測完成\n');
    fprintf('    通道 | 穩態 | THD     | DC誤差  | 狀態\n');
    fprintf('    ─────┼──────┼─────────┼─────────┼──────\n');

    for ch = 1:6
        steady_mark = '✓';
        if ~quality_steady_state(freq_idx, ch)
            steady_mark = '✗';
        end

        thd_mark = '✓';
        if ~quality_thd_pass(freq_idx, ch)
            thd_mark = '✗';
        end

        dc_mark = '✓';
        if ~quality_dc_pass(freq_idx, ch)
            dc_mark = '✗';
        end

        % 整體狀態判斷
        if ch == Channel
            % 激勵通道：必須全部通過
            if quality_steady_state(freq_idx, ch) && quality_thd_pass(freq_idx, ch) && quality_dc_pass(freq_idx, ch)
                status = 'PASS';
            else
                status = 'WARN';
            end
        else
            % 其他通道：標記但不影響 FFT
            if quality_steady_state(freq_idx, ch) && quality_thd_pass(freq_idx, ch) && quality_dc_pass(freq_idx, ch)
                status = 'OK';
            else
                status = 'FAIL';
            end
        end

        fprintf('     P%d  |  %s   | %5.2f%% %s | %.4fV %s | %s\n', ...
                ch, steady_mark, quality_thd(freq_idx, ch), thd_mark, ...
                quality_dc_error(freq_idx, ch), dc_mark, status);
    end

    fprintf('\n');

    %% ========== 品質檢測結束 ==========

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

% 品質檢測結果
results.quality.steady_state = quality_steady_state;
results.quality.thd = quality_thd;
results.quality.dc_error = quality_dc_error;
results.quality.thd_pass = quality_thd_pass;
results.quality.dc_pass = quality_dc_pass;

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

% === 計算並標註 -3dB 頻寬點（修正版）===
mag_dB_excited = results.magnitude_dB(:, Channel);

% 找到第一個 < -3dB 的點
idx_below_3dB = find(mag_dB_excited < -3, 1, 'first');

if ~isempty(idx_below_3dB) && idx_below_3dB > 1
    % 用線性內插找精確的 -3dB 頻率
    idx_above = idx_below_3dB - 1;  % -3dB 之前的點（> -3dB）
    idx_below = idx_below_3dB;       % -3dB 之後的點（< -3dB）

    % 提取兩點的數據
    f1 = frequencies(idx_above);
    f2 = frequencies(idx_below);
    mag_dB1 = mag_dB_excited(idx_above);
    mag_dB2 = mag_dB_excited(idx_below);

    % 線性內插（對數頻率軸用線性內插）
    f_3dB = f1 + (f2 - f1) * (-3 - mag_dB1) / (mag_dB2 - mag_dB1);
    mag_3dB = 10^(-3/20);  % -3dB 對應的線性增益 = 0.7079

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

%% SECTION 4.5: 品質摘要圖

fprintf('【生成品質摘要圖】\n');
fprintf('────────────────────────\n');

% === 圖 2: 品質摘要 Heatmap ===
fig_quality = figure('Name', 'Quality Summary', 'Position', [200, 200, 1200, 800]);

% 創建 3x1 子圖
subplot(3, 1, 1);
imagesc(quality_steady_state');
colormap(gca, [1 0.8 0.8; 0.8 1 0.8]);  % 紅色=失敗, 綠色=通過
colorbar('Ticks', [0, 1], 'TickLabels', {'Fail', 'Pass'});
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('Steady State Check', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');

subplot(3, 1, 2);
imagesc(quality_thd');
colorbar;
caxis([0, max(5, max(quality_thd(:)))]);  % 顯示 0-5% 範圍
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('THD [%]', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');
colormap(gca, hot);

subplot(3, 1, 3);
imagesc(quality_dc_error' * 1000);  % 轉成 mV
colorbar;
caxis([0, max(10, max(quality_dc_error(:)*1000))]);  % 顯示 0-10mV 範圍
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('DC Error [mV]', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');
colormap(gca, hot);

sgtitle(sprintf('Quality Summary - PI Controller (Ch P%d, Kp=%.2f, Ki=%.2f)', ...
        Channel, Kp_value, Ki_value), 'FontSize', 15, 'FontWeight', 'bold');

fprintf('  ✓ 品質摘要圖完成\n');
fprintf('\n');

%% SECTION 5: 分析與顯示結果

fprintf('【頻率響應分析結果】\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
fprintf('  PI 參數: Kp = %.2f, Ki = %.2f (zc = %.0f)\n', Kp_value, Ki_value, zc);
fprintf('  激發通道: P%d\n\n', Channel);
fprintf('────────────────────────────────────────────────────────────\n');

mag_dB = results.magnitude_dB(:, Channel);

% 找 -3dB 頻寬（修正版：使用內插）
idx_below_3dB = find(mag_dB < -3, 1, 'first');
if ~isempty(idx_below_3dB) && idx_below_3dB > 1
    % 線性內插計算精確的 -3dB 頻率
    idx_above = idx_below_3dB - 1;
    f1 = frequencies(idx_above);
    f2 = frequencies(idx_below_3dB);
    mag_dB1 = mag_dB(idx_above);
    mag_dB2 = mag_dB(idx_below_3dB);

    f_3dB = f1 + (f2 - f1) * (-3 - mag_dB1) / (mag_dB2 - mag_dB1);
    fprintf('  -3dB 頻寬: %.2f Hz (內插計算)\n', f_3dB);
elseif ~isempty(idx_below_3dB)
    % 第一個點就 < -3dB（異常）
    fprintf('  -3dB 頻寬: < %.2f Hz (第一個測試點)\n', frequencies(1));
else
    fprintf('  -3dB 頻寬: > %.2f Hz (未達到)\n', frequencies(end));
end

% 低頻增益（最低測試頻率，近似 DC 增益）
low_freq_gain_dB = mag_dB(1);
fprintf('  低頻增益 (%.1f Hz): %.2f dB (%.2f%%) [近似 DC]\n', ...
        frequencies(1), low_freq_gain_dB, 10^(low_freq_gain_dB/20)*100);

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

%% 品質統計報告
fprintf('\n【品質檢測統計】\n');
fprintf('════════════════════════════════════════════════════════════\n');

% 統計各通道的通過率
for ch = 1:6
    steady_pass_count = sum(quality_steady_state(:, ch));
    thd_pass_count = sum(quality_thd_pass(:, ch));
    dc_pass_count = sum(quality_dc_pass(:, ch));

    steady_pass_rate = steady_pass_count / num_freq * 100;
    thd_pass_rate = thd_pass_count / num_freq * 100;
    dc_pass_rate = dc_pass_count / num_freq * 100;

    overall_pass = sum(quality_steady_state(:, ch) & quality_thd_pass(:, ch) & quality_dc_pass(:, ch));
    overall_pass_rate = overall_pass / num_freq * 100;

    fprintf('\n【P%d】\n', ch);
    if ch == Channel
        fprintf('  (激勵通道)\n');
    end
    fprintf('  穩態檢測通過率: %d/%d (%.1f%%)\n', steady_pass_count, num_freq, steady_pass_rate);
    fprintf('  THD 檢測通過率: %d/%d (%.1f%%)\n', thd_pass_count, num_freq, thd_pass_rate);
    fprintf('  DC 檢測通過率:  %d/%d (%.1f%%)\n', dc_pass_count, num_freq, dc_pass_rate);
    fprintf('  整體通過率:     %d/%d (%.1f%%)\n', overall_pass, num_freq, overall_pass_rate);

    % THD 統計
    valid_thd = quality_thd(~isnan(quality_thd(:, ch)), ch);
    if ~isempty(valid_thd)
        fprintf('  THD 平均值: %.2f%% (最大: %.2f%%, 最小: %.2f%%)\n', ...
                mean(valid_thd), max(valid_thd), min(valid_thd));
    end

    % DC 誤差統計
    fprintf('  DC 誤差平均: %.4f V (最大: %.4f V)\n', ...
            mean(quality_dc_error(:, ch)), max(quality_dc_error(:, ch)));
end

fprintf('\n════════════════════════════════════════════════════════════\n');

%% SECTION 6: 保存結果

fprintf('\n【保存結果】\n');
fprintf('────────────────────────\n');

% 檔案命名（簡化，因為已經在專屬資料夾中）
mat_filename = 'freq_sweep_data.mat';
png_bode_filename = 'bode_plot.png';
png_quality_filename = 'quality_summary.png';

mat_path = fullfile(output_dir, mat_filename);
png_bode_path = fullfile(output_dir, png_bode_filename);
png_quality_path = fullfile(output_dir, png_quality_filename);

% 保存 .mat 檔案
save(mat_path, 'results', '-v7.3');
fprintf('  ✓ 數據已保存: %s\n', mat_filename);

% 保存 Bode Plot
saveas(fig, png_bode_path);
fprintf('  ✓ Bode Plot 已保存: %s\n', png_bode_filename);

% 保存品質摘要圖
saveas(fig_quality, png_quality_path);
fprintf('  ✓ 品質摘要圖已保存: %s\n', png_quality_filename);

fprintf('\n  📁 所有檔案保存至: %s\n', output_dir);
fprintf('  📁 診斷圖保存至: %s\n', diagnostic_dir);
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
