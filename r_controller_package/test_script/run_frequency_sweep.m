% run_frequency_sweep.m
% R Controller 頻率響應測試腳本 - Bode Plot 分析（d=0 測試版本）
%
% 功能：
%   1. 掃過多個頻率點（1 Hz ~ 4 kHz, 21 點）
%   2. 測試 d=0 的頻率響應
%   3. 使用 FFT 分析計算增益和相位
%   4. 品質檢測（穩態、THD、DC）
%   5. 繪製 Bode Plot 並標註 -3dB 點
%   6. 儲存結果（.mat 和 .png）

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

% 頻率向量（使用 100,000 Hz 的因數，確保零 round() 誤差）
% 所有頻率都能產生整數的 samples_per_cycle，避免相位漂移問題
frequencies = [1, 10, 50, 100, ...              % 低頻段 (1-100 Hz): 4點
               125, 200, 250, 400, 500, ...      % 中頻段 (100-500 Hz): 5點
               625, 800, 1000, 1250, 2000, ...   % 高頻段 (500-2000 Hz): 5點
               2500, 3125, 4000];                % 超高頻段 (2000-4000 Hz): 3點

% 測試的 d 值（目前僅測試 d=0）
d_values = [0];

% Vd Generator 設定
signal_type_name = 'sine';
Channel = 4;              % 激勵通道
Amplitude = 1;            % 振幅 [V]
Phase = 0;                % 相位 [deg]
SignalType = 1;           % Sine mode

% Controller 參數
T = 1e-5;                 % 採樣時間 [s] (100 kHz)
fB_c = 3200;              % 控制器頻寬 [Hz]
fB_e = 16000;             % 估測器頻寬 [Hz]

% ==================== 計算控制器參數 ====================
% 使用 r_controller_calc_params 計算所有控制器係數
% 此函數會自動創建 Bus Object 並包裝為 Simulink.Parameter
params = r_controller_calc_params(fB_c, fB_e);
% ======================================================

% Simulink 參數
Ts = 1e-5;                % 採樣時間 [s] (100 kHz)
solver = 'ode5';          % 固定步長 solver
StepTime = 0;             % Step 時間（不使用）

% 模擬時間設定
total_cycles = 120;       % 總週期數（80 暫態 + 40 穩態）
skip_cycles = 80;         % 跳過暫態週期數（從 50 增加到 80）
fft_cycles = 40;          % FFT 分析週期數
min_sim_time = 0.1;       % 最小模擬時間 [s]（高頻用）
max_sim_time = Inf;       % 最大模擬時間 [s]（不設限）

% 品質檢測參數
steady_state_threshold = 0.02;  % 穩態檢測閾值 (2% of Amplitude)
thd_threshold = 1.0;            % THD 閾值 (1%)
dc_tolerance = 0.01;            % DC 值容忍度 (1% of Amplitude)
freq_error_threshold = 0.1;     % 頻率誤差警告閾值 (0.1%)

% 輸出設定
test_timestamp = datestr(now, 'yyyymmdd_HHMMSS');
test_folder_name = sprintf('d%d_ch%d_%s', d_values(1), Channel, test_timestamp);
output_dir = fullfile(package_root, 'test_results', 'frequency_response', test_folder_name);

% 模型設定
model_name = 'r_controller_system_integrated';
model_path = fullfile(package_root, 'model', [model_name '.slx']);

%% SECTION 2: 初始化

fprintf('【測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  頻率範圍: %.1f Hz ~ %.1f kHz\n', frequencies(1), frequencies(end)/1000);
fprintf('  頻率點數: %d 點（所有頻率均為 100kHz 的因數，確保零 round() 誤差）\n', length(frequencies));
fprintf('    低頻段 (1-100 Hz): 4 點\n');
fprintf('    中頻段 (100-500 Hz): 5 點\n');
fprintf('    高頻段 (500-2000 Hz): 5 點\n');
fprintf('    超高頻段 (2000-4000 Hz): 3 點\n');
fprintf('  d 值: %d（測試版本，僅測試 d=0）\n', d_values(1));
fprintf('  激勵通道: P%d\n', Channel);
fprintf('  振幅: %.2f V\n', Amplitude);
fprintf('  控制器頻寬: %.1f kHz\n', fB_c/1000);
fprintf('  估測器頻寬: %.1f kHz\n', fB_e/1000);
fprintf('  總週期數: %d (跳過 %d, 分析 %d)\n', total_cycles, skip_cycles, fft_cycles);
fprintf('  Solver: %s (固定步長)\n', solver);
fprintf('\n');

% 取得 b 參數值用於理論曲線計算
b_value = params.Value.b;
fprintf('  理論模型參數 b: %.4f\n', b_value);
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

% 創建診斷圖目錄
diagnostic_dir = fullfile(output_dir, 'diagnostics');
if ~exist(diagnostic_dir, 'dir')
    mkdir(diagnostic_dir);
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

    % 初始化品質檢測結果矩陣
    quality_steady_state = true(num_freq, 6);  % 穩態檢測結果
    quality_thd = zeros(num_freq, 6);          % THD 值 (%)
    quality_dc_error = zeros(num_freq, 6);     % DC 誤差 (V)
    quality_thd_pass = true(num_freq, 6);      % THD 檢測通過
    quality_dc_pass = true(num_freq, 6);       % DC 檢測通過

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
        fprintf('    通道 | 穩態 | THD          | DC誤差  | 狀態\n');
        fprintf('    ─────┼──────┼──────────────┼─────────┼──────\n');

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

            % THD 動態格式顯示
            thd_val = quality_thd(freq_idx, ch);
            if isnan(thd_val)
                thd_str = '    N/A    ';
            elseif thd_val < 0.01
                thd_str = sprintf('%10.2e%%', thd_val);
            else
                thd_str = sprintf('%10.4f%%', thd_val);
            end

            fprintf('     P%d  |  %s   | %s %s | %.4fV %s | %s\n', ...
                    ch, steady_mark, thd_str, thd_mark, ...
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

        % 頻率誤差檢查
        freq_error = abs(Frequency - actual_freq);
        freq_error_percent = (freq_error / Frequency) * 100;

        fprintf('    目標頻率: %.2f Hz\n', Frequency);
        fprintf('    FFT bin:  %.2f Hz (誤差: %.4f Hz, %.3f%%)\n', ...
                actual_freq, freq_error, freq_error_percent);

        if freq_error_percent > freq_error_threshold
            fprintf('    ⚠️ 警告：頻率誤差 %.3f%% > %.3f%%\n', ...
                    freq_error_percent, freq_error_threshold);
        end

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

    % 計算理論值（在儲存前計算，以便保存到結果中）
    H_theory_save = zeros(size(frequencies));
    for i = 1:length(frequencies)
        theta = 2*pi*frequencies(i)*Ts;  % θ = ω·Ts
        H_theory_save(i) = (1 + 2*b_value*cos(theta) + b_value^2) / (1 + b_value)^2;
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

    % 理論值和誤差分析
    results(d_idx).theory.b_value = b_value;
    results(d_idx).theory.H_magnitude = H_theory_save;
    results(d_idx).theory.H_magnitude_dB = 20 * log10(H_theory_save);
    results(d_idx).theory.error_percent = abs(magnitude_ratio_all(:, Channel) - H_theory_save') ./ H_theory_save' * 100;
    results(d_idx).theory.max_error_percent = max(results(d_idx).theory.error_percent);
    results(d_idx).theory.mean_error_percent = mean(results(d_idx).theory.error_percent);
    results(d_idx).theory.rms_error_percent = sqrt(mean(results(d_idx).theory.error_percent.^2));

    % 品質檢測結果
    results(d_idx).quality.steady_state = quality_steady_state;
    results(d_idx).quality.thd = quality_thd;
    results(d_idx).quality.dc_error = quality_dc_error;
    results(d_idx).quality.thd_pass = quality_thd_pass;
    results(d_idx).quality.dc_pass = quality_dc_pass;

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

    % === 加入理論曲線（使用灰色系）===
    % 計算理論增益響應
    H_theory = zeros(size(frequencies));
    for i = 1:length(frequencies)
        theta = 2*pi*frequencies(i)*Ts;  % θ = ω·Ts
        H_theory(i) = (1 + 2*b_value*cos(theta) + b_value^2) / (1 + b_value)^2;
    end

    % 繪製理論曲線（深灰色粗虛線）
    semilogx(frequencies, H_theory, '--', ...
             'LineWidth', 3, ...
             'Color', [0.3, 0.3, 0.3], ...  % 深灰色
             'DisplayName', sprintf('Theory (b=%.4f)', b_value));

    % 在理論曲線上加標記點（每隔一個點）
    indices_theory = 1:2:length(frequencies);  % 每隔一個點
    plot(frequencies(indices_theory), H_theory(indices_theory), 'd', ...
         'MarkerSize', 8, ...
         'MarkerFaceColor', [0.9, 0.9, 0.9], ...  % 淺灰填充
         'MarkerEdgeColor', [0.2, 0.2, 0.2], ...  % 深灰邊框
         'LineWidth', 1.5, ...
         'HandleVisibility', 'off');  % 不顯示在圖例中

    % === 計算模擬與理論的誤差 ===
    mag_excited = magnitude_ratio(:, Channel);
    error_percent = abs(mag_excited - H_theory') ./ H_theory' * 100;
    [max_error, max_idx] = max(error_percent);

    % 不再標註最大誤差點

    % === 計算並標註 -3dB 頻寬點（內插計算）===
    mag_dB_excited = results(d_idx).magnitude_dB(:, Channel);
    idx_below_3dB = find(mag_dB_excited < -3, 1, 'first');

    if ~isempty(idx_below_3dB) && idx_below_3dB > 1
        % 用線性內插找精確的 -3dB 頻率
        idx_above = idx_below_3dB - 1;
        f1 = frequencies(idx_above);
        f2 = frequencies(idx_below_3dB);
        mag_dB1 = mag_dB_excited(idx_above);
        mag_dB2 = mag_dB_excited(idx_below_3dB);

        % 線性內插
        f_3dB = f1 + (f2 - f1) * (-3 - mag_dB1) / (mag_dB2 - mag_dB1);
        mag_3dB = 10^(-3/20);  % -3dB 對應的線性增益 = 0.7079

        % 標註 -3dB 點
        semilogx(f_3dB, mag_3dB, 'o', ...
                 'MarkerSize', 10, ...
                 'MarkerEdgeColor', [0.5, 0.5, 0.5], ...
                 'MarkerFaceColor', [0.8, 0.8, 0.8], ...
                 'LineWidth', 2, ...
                 'DisplayName', sprintf('-3dB @ %.1f Hz', f_3dB));

        % 加入垂直輔助線
        plot([f_3dB, f_3dB], [0, mag_3dB], '--', ...
             'Color', [0.6, 0.6, 0.6], 'LineWidth', 1.5, ...
             'HandleVisibility', 'off');
    end

    % 設定 Y 軸範圍
    ylim([0, 1.25]);

    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('R Controller Frequency Response - d=%d (Excited Ch: P%d)', d, Channel), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'NumColumns', 2, 'FontSize', 10);
    xlim([frequencies(1), frequencies(end)]);

    % 設定 X 軸刻度為 10^n 格式
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');

    % ===== 下圖：Phase（只顯示激勵通道）=====
    subplot(2,1,2);
    hold on; grid on;

    phase_ch = results(d_idx).phase_lag(:, Channel);

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

%% SECTION 4.5: 品質摘要圖

fprintf('【生成品質摘要圖】\n');
fprintf('────────────────────────\n');

% === 圖：品質摘要 Heatmap（只針對 d=0）===
d_idx = 1;  % 只有 d=0
fig_quality = figure('Name', 'Quality Summary', 'Position', [200, 200, 1200, 800]);

% 創建 3x1 子圖
subplot(3, 1, 1);
imagesc(results(d_idx).quality.steady_state');
colormap(gca, [1 0.8 0.8; 0.8 1 0.8]);  % 紅色=失敗, 綠色=通過
colorbar('Ticks', [0, 1], 'TickLabels', {'Fail', 'Pass'});
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('Steady State Check', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');

subplot(3, 1, 2);
imagesc(results(d_idx).quality.thd');
colorbar;
clim([0, max(5, max(results(d_idx).quality.thd(:)))]);  % 顯示 0-5% 範圍
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('THD [%]', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');
colormap(gca, hot);

subplot(3, 1, 3);
imagesc(results(d_idx).quality.dc_error' * 1000);  % 轉成 mV
colorbar;
clim([0, max(10, max(results(d_idx).quality.dc_error(:)*1000))]);  % 顯示 0-10mV 範圍
xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
title('DC Error [mV]', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
set(gca, 'FontSize', 10, 'FontWeight', 'bold');
colormap(gca, hot);

sgtitle(sprintf('Quality Summary - R Controller (d=%d, Ch P%d, fB_c=%.1f kHz)', ...
        results(d_idx).d_value, Channel, fB_c/1000), 'FontSize', 15, 'FontWeight', 'bold');

fprintf('  ✓ 品質摘要圖完成\n');
fprintf('\n');

%% SECTION 5: 分析與顯示結果 

fprintf('【頻率響應分析結果】\n');
fprintf('════════════════════════════════════════════════════════════\n');

for d_idx = 1:num_d
    d = results(d_idx).d_value;
    mag_dB = results(d_idx).magnitude_dB(:, Channel);

    fprintf('\n[ d = %d ]\n', d);
    fprintf('────────────────────────────────────────────────────────\n');

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
    dc_gain_dB = mag_dB(1);
    fprintf('  低頻增益 (%.1f Hz): %.2f dB (%.2f%%) [近似 DC]\n', ...
            frequencies(1), dc_gain_dB, 10^(dc_gain_dB/20)*100);

    % 高頻增益（最高頻）
    hf_gain_dB = mag_dB(end);
    fprintf('  高頻增益 (%.1f Hz): %.2f dB (%.2f%%)\n', ...
            frequencies(end), hf_gain_dB, 10^(hf_gain_dB/20)*100);

    % 最大增益
    [max_gain_dB, max_idx] = max(mag_dB);
    fprintf('  最大增益: %.2f dB at %.2f Hz\n', max_gain_dB, frequencies(max_idx));

    % 相位統計
    phase_ch = results(d_idx).phase_lag(:, Channel);
    fprintf('\n  相位範圍: %.2f° ~ %.2f°\n', min(phase_ch), max(phase_ch));
    fprintf('  平均相位: %.2f°\n', mean(phase_ch));

    % 理論對比統計
    fprintf('\n【理論對比分析 (b = %.4f)】\n', results(d_idx).theory.b_value);
    fprintf('  最大誤差: %.2f%% @ %.1f Hz\n', ...
            results(d_idx).theory.max_error_percent, ...
            frequencies(find(results(d_idx).theory.error_percent == results(d_idx).theory.max_error_percent, 1)));
    fprintf('  平均誤差: %.2f%%\n', results(d_idx).theory.mean_error_percent);
    fprintf('  RMS 誤差: %.2f%%\n', results(d_idx).theory.rms_error_percent);

    % 找出誤差最小的頻率
    [min_error, min_idx] = min(results(d_idx).theory.error_percent);
    fprintf('  最小誤差: %.2f%% @ %.1f Hz\n', min_error, frequencies(min_idx));

    fprintf('\n');
end

fprintf('════════════════════════════════════════════════════════════\n');

%% 品質統計報告
fprintf('\n【品質檢測統計】\n');
fprintf('════════════════════════════════════════════════════════════\n');

% 統計各通道的通過率（只針對 d=0）
d_idx = 1;
for ch = 1:6
    steady_pass_count = sum(results(d_idx).quality.steady_state(:, ch));
    thd_pass_count = sum(results(d_idx).quality.thd_pass(:, ch));
    dc_pass_count = sum(results(d_idx).quality.dc_pass(:, ch));

    steady_pass_rate = steady_pass_count / num_freq * 100;
    thd_pass_rate = thd_pass_count / num_freq * 100;
    dc_pass_rate = dc_pass_count / num_freq * 100;

    overall_pass = sum(results(d_idx).quality.steady_state(:, ch) & ...
                       results(d_idx).quality.thd_pass(:, ch) & ...
                       results(d_idx).quality.dc_pass(:, ch));
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
    valid_thd = results(d_idx).quality.thd(~isnan(results(d_idx).quality.thd(:, ch)), ch);
    if ~isempty(valid_thd)
        fprintf('  THD 平均值: %.2f%% (最大: %.2f%%, 最小: %.2f%%)\n', ...
                mean(valid_thd), max(valid_thd), min(valid_thd));
    end

    % DC 誤差統計
    fprintf('  DC 誤差平均: %.4f V (最大: %.4f V)\n', ...
            mean(results(d_idx).quality.dc_error(:, ch)), max(results(d_idx).quality.dc_error(:, ch)));
end

fprintf('\n════════════════════════════════════════════════════════════\n');

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

% 保存 Bode Plot（只有一張，d=0）
saveas(figure(1), png_bode_path);
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
fprintf('  控制器: R Controller\n');
fprintf('  d 值: %d (測試版本)\n', d_values(1));
fprintf('  激勵通道: P%d\n', Channel);
fprintf('  控制器頻寬: %.1f kHz\n', fB_c/1000);
fprintf('  估測器頻寬: %.1f kHz\n', fB_e/1000);
fprintf('  頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), num_freq);
fprintf('  總模擬時間: %.2f 分鐘\n', sum(sim_times)/60);
fprintf('  輸出位置: %s\n', output_dir);
fprintf('\n');

fprintf('測試腳本執行完畢！\n\n');
