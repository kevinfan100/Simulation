% run_batch_frequency_sweep.m
% PI Controller 批次頻率掃描腳本 (按通道分組)
%
% 功能：
%   1. 測試所有 6 個通道
%   2. 每個通道測試多組 Kp 值
%   3. 自動生成對比圖和摘要表
%   4. 按通道分組保存結果
%
% 輸出結構：
%   batch_YYYYMMDD_HHMMSS/
%   ├── Channel_P1/ (包含 3 個 .mat + 3 個個別圖 + 1 個對比圖 + 摘要)
%   ├── Channel_P2/ ~ Channel_P6/
%   ├── channel_comparison_Kp*.png (3 張，6 通道對比)
%   ├── bandwidth_heatmap.png
%   ├── batch_summary.txt
%   └── batch_config.txt

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('     PI Controller 批次頻率掃描 (按通道分組)\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 批次測試配置

% 添加必要的路徑
script_dir = fileparts(mfilename('fullpath'));
scripts_root = fullfile(script_dir, '..');
project_root = fullfile(scripts_root, '..');
addpath(fullfile(scripts_root, 'common'));
addpath(fullfile(project_root, 'controllers', 'pi_controller'));

% === 核心參數 ===
Kp_values = [1, 2, 4, 8];          % 要測試的 Kp 值
test_channels = 1:6;            % 要測試的通道
zc = 2206;                      % 固定 zc (Ki = Kp * zc)

% === 頻率設定 ===
frequencies = [1, 10, 20, 50, 100, ...        % 低頻段 (1-100 Hz): 5點
               125, 200, 250, 400, 500, ...   % 中頻段 (100-500 Hz): 5點
               625, 800, 1000, 1250, 1500];   % 高頻段 (500-1500 Hz): 5點

% === Vd Generator 設定 ===
signal_type_name = 'sine';
Amplitude = 1;              % 振幅 [V]
Phase = 0;                  % 相位 [deg]
SignalType = 1;             % Sine mode

% === Simulink 參數 ===
Ts = 1e-5;                  % 採樣時間 [s] (100 kHz)
solver = 'ode5';            % 固定步長 solver
StepTime = 0;               % Step 時間（不使用）

% === 模擬時間設定 ===
total_cycles = 120;         % 總週期數
skip_cycles = 80;           % 跳過暫態週期數（從 50 增加到 80）
fft_cycles = 40;            % FFT 分析週期數
min_sim_time = 0.1;         % 最小模擬時間 [s]（高頻用）
max_sim_time = Inf;         % 最大模擬時間 [s]（不設限）

% === 品質檢測參數 ===
steady_state_threshold = 0.02;  % 穩態檢測閾值 (2% of Amplitude)
thd_threshold = 1.0;            % THD 閾值 (1%)
dc_tolerance = 0.01;            % DC 值容忍度 (1% of Amplitude)

% === 輸出設定 ===
output_base_dir = fullfile(project_root, 'test_results', 'pi_controller', 'frequency_response');
batch_timestamp = datestr(now, 'yyyymmdd_HHMMSS');
batch_dir = fullfile(output_base_dir, ['batch_' batch_timestamp]);

% === 模型設定 ===
model_name = 'PI_Controller_Integrated';
controller_type = 'pi_controller';
model_path = fullfile(project_root, 'controllers', controller_type, [model_name '.slx']);

%% SECTION 2: 初始化

fprintf('【批次測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  測試 Kp: [%s]\n', num2str(Kp_values));
fprintf('  對應 Ki: [%s]\n', num2str(Kp_values * zc));
fprintf('  zc 固定值: %.0f\n', zc);
fprintf('  測試通道: P%d ~ P%d\n', test_channels(1), test_channels(end));
fprintf('  總測試次數: %d (6 通道 × %d Kp)\n', ...
        length(test_channels) * length(Kp_values), length(Kp_values));
fprintf('  頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf('  頻率點數: %d 點（所有頻率均為 100kHz 的因數，確保零 round() 誤差）\n', length(frequencies));
fprintf('    低頻段 (1-100 Hz): 5 點\n');
fprintf('    中頻段 (100-500 Hz): 5 點\n');
fprintf('    高頻段 (500-1500 Hz): 5 點\n');
fprintf('  Solver: %s (固定步長)\n', solver);
fprintf('\n');

% 預估執行時間
single_test_time = 8;  % 分鐘
total_tests = length(test_channels) * length(Kp_values);
estimated_hours = (single_test_time * total_tests) / 60;
fprintf('  ⏱️ 預估執行時間: %.1f 小時\n', estimated_hours);
fprintf('\n');

% 檢查模型
if ~exist(model_path, 'file')
    error('找不到模型檔案: %s', model_path);
end

% 創建批次輸出目錄
if ~exist(batch_dir, 'dir')
    mkdir(batch_dir);
    fprintf('  ✓ 已創建批次目錄: %s\n', batch_dir);
end

% 保存配置文件
config_file = fullfile(batch_dir, 'batch_config.txt');
fid = fopen(config_file, 'w');
fprintf(fid, 'PI Controller 批次頻率掃描配置\n');
fprintf(fid, '════════════════════════════════════════\n');
fprintf(fid, '測試時間: %s\n', datestr(now));
fprintf(fid, 'Kp 值: [%s]\n', num2str(Kp_values));
fprintf(fid, 'Ki 值: [%s]\n', num2str(Kp_values * zc));
fprintf(fid, 'zc: %.0f\n', zc);
fprintf(fid, '通道: P1 ~ P6\n');
fprintf(fid, '頻率: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf(fid, 'Solver: %s\n', solver);
fprintf(fid, '總測試: %d\n', total_tests);
fclose(fid);

% 開啟模型
if ~bdIsLoaded(model_name)
    open_system(model_path);
    fprintf('  ✓ 模型已開啟\n');
end

fprintf('\n');

%% SECTION 3: 批次測試主迴圈

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  開始批次頻率掃描\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

% 初始化結果儲存
batch_results = struct();
test_counter = 0;
batch_start_time = tic;

% 顏色設定
channel_colors = [
    0.0000, 0.0000, 0.0000;  % P1: 黑色
    0.0000, 0.0000, 1.0000;  % P2: 藍色
    0.0000, 0.5000, 0.0000;  % P3: 綠色
    1.0000, 0.0000, 0.0000;  % P4: 紅色
    0.8000, 0.0000, 0.8000;  % P5: 粉紫色
    0.0000, 0.7500, 0.7500;  % P6: 青色
];

kp_colors = [
    0.0000, 0.4470, 0.7410;  % Kp1: 藍色
    0.8500, 0.3250, 0.0980;  % Kp2: 橘色
    0.9290, 0.6940, 0.1250;  % Kp3: 黃色
    0.4660, 0.6740, 0.1880;  % Kp4: 綠色
];

% === 外層迴圈：通道 ===
for ch_idx = 1:length(test_channels)
    Channel = test_channels(ch_idx);

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('  測試通道 P%d (%d/%d)\n', Channel, ch_idx, length(test_channels));
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    % 創建通道資料夾
    channel_dir = fullfile(batch_dir, sprintf('Channel_P%d', Channel));
    if ~exist(channel_dir, 'dir')
        mkdir(channel_dir);
    end

    % 創建診斷圖目錄
    diagnostic_dir = fullfile(channel_dir, 'diagnostics');
    if ~exist(diagnostic_dir, 'dir')
        mkdir(diagnostic_dir);
    end

    % 初始化通道結果
    channel_results = struct();

    % === 內層迴圈：Kp 值 ===
    for kp_idx = 1:length(Kp_values)
        Kp_value = Kp_values(kp_idx);
        Ki_value = Kp_value * zc;

        test_counter = test_counter + 1;
        progress_pct = (test_counter / total_tests) * 100;

        fprintf('────────────────────────────────────────────────────────\n');
        fprintf('[測試 %d/%d] 通道 P%d, Kp=%.1f, Ki=%.1f (%.1f%%)\n', ...
                test_counter, total_tests, Channel, Kp_value, Ki_value, progress_pct);
        fprintf('────────────────────────────────────────────────────────\n');

        % 設定 PI 參數為 workspace 變數
        for ch = 1:6
            pi_block = sprintf('%s/PI controller/PI_Ch%d', model_name, ch);
            set_param(pi_block, 'P', 'Kp_value');
            set_param(pi_block, 'I', 'Ki_value');
        end

        % 初始化頻率掃描結果
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
        fft_bin_errors = zeros(num_freq, 1);       % FFT bin 誤差 (Hz)
        quality_fundamental_error = zeros(num_freq, 6);  % Fundamental frequency 誤差 (Hz)

        % === 頻率掃描 ===
        for freq_idx = 1:num_freq
            Frequency = frequencies(freq_idx);
            period = 1 / Frequency;

            % 計算模擬時間
            sim_time = total_cycles * period;
            sim_time = max(min_sim_time, min(sim_time, max_sim_time));
            sim_times(freq_idx) = sim_time;

            fprintf('  [%2d/%2d] %.1f Hz ... ', freq_idx, num_freq, Frequency);

            % 設定 Simulink 參數
            set_param(model_name, 'StopTime', num2str(sim_time));
            set_param(model_name, 'Solver', solver);
            set_param(model_name, 'FixedStep', num2str(Ts));

            % 執行模擬
            try
                out = sim(model_name);
                fprintf('✓');  % 暫時不換行，等 THD 資訊一起顯示
            catch ME
                fprintf('✗ (%s)\n', ME.message);
                continue;
            end

            % 提取數據
            try
                Vd_data = out.Vd;
                Vm_data = out.Vm;
                N = size(Vd_data, 1);
                t = (0:N-1)' * Ts;
            catch ME
                fprintf('    數據提取失敗\n');
                continue;
            end

            % 選取穩態數據
            skip_time = skip_cycles * period;
            fft_time = fft_cycles * period;
            t_start = skip_time;
            t_end = min(skip_time + fft_time, t(end));
            idx_steady = (t >= t_start) & (t <= t_end);

            if sum(idx_steady) < 100
                fprintf('    穩態數據不足\n');
                continue;
            end

            Vd_steady = Vd_data(idx_steady, :);
            Vm_steady = Vm_data(idx_steady, :);
            t_steady = t(idx_steady);

            %% ========== 品質檢測開始 ==========

            % === 1. 穩態檢測：檢查週期重複性 ===
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
                        diag_filename = sprintf('steady_fail_%.1fHz_P%d_Kp%.1f.png', Frequency, ch, Kp_value);
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

            % === 3. Fundamental Frequency 驗證 ===
            for ch = 1:6
                % 找出 Vm 的 fundamental frequency（FFT 最大峰值）
                Vm_fft_full = abs(fft(Vm_steady(:, ch)));
                N_half = floor(length(Vm_fft_full)/2);
                [~, fundamental_idx] = max(Vm_fft_full(2:N_half));  % 跳過 DC (idx=1)
                fundamental_idx = fundamental_idx + 1;  % 補回偏移

                % 計算 fundamental frequency
                freq_axis_full = (0:length(Vm_fft_full)-1) * fs / length(Vm_fft_full);
                fundamental_freq = freq_axis_full(fundamental_idx);

                % 檢查是否 = Frequency
                quality_fundamental_error(freq_idx, ch) = abs(fundamental_freq - Frequency);
            end

            %% ========== 品質檢測結束 ==========

            % === 顯示 THD 資訊（接在 ✓ 後面） ===
            thd_excited = quality_thd(freq_idx, Channel);
            if ~isnan(thd_excited)
                if thd_excited < thd_threshold
                    fprintf(' | THD: %.3f%%\n', thd_excited);
                else
                    fprintf(' | THD: %.3f%% ✗ (超標 %.3f%%)\n', thd_excited, thd_excited - thd_threshold);
                end
            else
                fprintf(' | THD: N/A\n');
            end

            % FFT 分析
            N_fft = length(Vd_steady);
            fs = 1 / Ts;
            freq_axis = (0:N_fft-1) * fs / N_fft;
            [~, freq_bin_idx] = min(abs(freq_axis - Frequency));

            % === 驗證 9：FFT bin 對齊檢查 ===
            actual_freq = freq_axis(freq_bin_idx);
            freq_bin_error = abs(actual_freq - Frequency);
            fft_bin_errors(freq_idx) = freq_bin_error;

            % 檢查 FFT bin 是否對齊（理論上應該 = 0）
            if freq_bin_error > 0.01  % 容忍 0.01 Hz 誤差（數值精度）
                warning('FFT bin 未對齊！頻率: %.2f Hz, 誤差: %.4f Hz', Frequency, freq_bin_error);
            end

            % Vd FFT
            Vd_fft = fft(Vd_steady(:, Channel));
            Vd_mag = abs(Vd_fft(freq_bin_idx)) * 2 / N_fft;
            Vd_phase = angle(Vd_fft(freq_bin_idx)) * 180 / pi;

            % 所有通道 Vm FFT
            for ch = 1:6
                Vm_fft = fft(Vm_steady(:, ch));
                Vm_mag = abs(Vm_fft(freq_bin_idx)) * 2 / N_fft;
                Vm_phase = angle(Vm_fft(freq_bin_idx)) * 180 / pi;

                magnitude_ratio_all(freq_idx, ch) = Vm_mag / Vd_mag;
                phase_lag_all(freq_idx, ch) = Vm_phase - Vd_phase;

                % 相位正規化
                while phase_lag_all(freq_idx, ch) > 180
                    phase_lag_all(freq_idx, ch) = phase_lag_all(freq_idx, ch) - 360;
                end
                while phase_lag_all(freq_idx, ch) < -180
                    phase_lag_all(freq_idx, ch) = phase_lag_all(freq_idx, ch) + 360;
                end
            end
        end

        % 保存此次測試結果
        test_result.frequencies = frequencies;
        test_result.magnitude_ratio = magnitude_ratio_all;
        test_result.phase_lag = phase_lag_all;
        test_result.magnitude_dB = 20 * log10(magnitude_ratio_all);
        test_result.sim_times = sim_times;
        test_result.Channel = Channel;
        test_result.Kp = Kp_value;
        test_result.Ki = Ki_value;
        test_result.zc = zc;

        % 品質檢測結果
        test_result.quality.steady_state = quality_steady_state;
        test_result.quality.thd = quality_thd;
        test_result.quality.dc_error = quality_dc_error;
        test_result.quality.thd_pass = quality_thd_pass;
        test_result.quality.dc_pass = quality_dc_pass;
        test_result.quality.fft_bin_errors = fft_bin_errors;
        test_result.quality.fundamental_error = quality_fundamental_error;

        % 計算 -3dB 頻寬
        mag_dB_ch = test_result.magnitude_dB(:, Channel);
        idx_3dB = find(mag_dB_ch < -3, 1, 'first');
        if ~isempty(idx_3dB) && idx_3dB > 1
            test_result.bandwidth_3dB = frequencies(idx_3dB);
        else
            test_result.bandwidth_3dB = NaN;
        end

        % 保存到通道結果
        channel_results(kp_idx).result = test_result;

        % 保存 .mat 檔案
        mat_filename = sprintf('freq_sweep_P%d_Kp%.1f.mat', Channel, Kp_value);
        save(fullfile(channel_dir, mat_filename), 'test_result', '-v7.3');

        % 繪製個別 Bode Plot
        fig_individual = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);

        % 上圖：Magnitude
        subplot(2,1,1);
        hold on; grid on;
        for ch = 1:6
            mag = test_result.magnitude_ratio(:, ch);
            if ch == Channel
                semilogx(frequencies, mag, '-', 'LineWidth', 3, ...
                         'Color', channel_colors(ch, :), ...
                         'DisplayName', sprintf('P%d (Excited)', ch));
            else
                semilogx(frequencies, mag, '--', 'LineWidth', 1.5, ...
                         'Color', channel_colors(ch, :), ...
                         'DisplayName', sprintf('P%d', ch));
            end
        end

        % 標註 -3dB 點
        if ~isnan(test_result.bandwidth_3dB)
            idx_3dB = find(frequencies == test_result.bandwidth_3dB, 1);
            if ~isempty(idx_3dB)
                mag_3dB = test_result.magnitude_ratio(idx_3dB, Channel);
                semilogx(test_result.bandwidth_3dB, mag_3dB, 'o', ...
                         'MarkerSize', 10, 'MarkerEdgeColor', [0.5, 0.5, 0.5], ...
                         'MarkerFaceColor', [0.8, 0.8, 0.8], 'LineWidth', 2, ...
                         'DisplayName', sprintf('-3dB @ %.1f Hz', test_result.bandwidth_3dB));
            end
        end

        ylim([0, 1.25]);
        xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('P%d - Kp=%.1f, Ki=%.1f', Channel, Kp_value, Ki_value), ...
              'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'best', 'NumColumns', 2, 'FontSize', 10);
        xlim([frequencies(1), frequencies(end)]);
        set(gca, 'XScale', 'log');
        set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
        set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
        set(gca, 'FontSize', 11, 'FontWeight', 'bold');

        % 下圖：Phase
        subplot(2,1,2);
        hold on; grid on;
        phase_ch = test_result.phase_lag(:, Channel);
        semilogx(frequencies, phase_ch, '-o', 'LineWidth', 2.5, ...
                 'Color', channel_colors(Channel, :), 'MarkerSize', 6, ...
                 'DisplayName', sprintf('P%d', Channel));
        xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Phase [deg]', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('Phase Response - P%d', Channel), ...
              'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 10);
        xlim([frequencies(1), frequencies(end)]);
        set(gca, 'XScale', 'log');
        set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
        set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
        set(gca, 'FontSize', 11, 'FontWeight', 'bold');

        % 保存個別圖
        png_filename = sprintf('bode_P%d_Kp%.1f.png', Channel, Kp_value);
        saveas(fig_individual, fullfile(channel_dir, png_filename));
        close(fig_individual);

        fprintf('  ✓ Kp=%.1f 完成 (-3dB: %.1f Hz)\n', Kp_value, test_result.bandwidth_3dB);
        fprintf('\n');
    end

    % === 生成品質摘要圖（每個通道） ===
    fprintf('  📊 生成 P%d 的品質摘要圖...\n', Channel);

    % 合併所有 Kp 的品質數據（取最差情況）
    combined_steady = true(num_freq, 6);
    combined_thd = zeros(num_freq, 6);
    combined_dc = zeros(num_freq, 6);

    for kp_idx = 1:length(Kp_values)
        result = channel_results(kp_idx).result;
        combined_steady = combined_steady & result.quality.steady_state;
        combined_thd = max(combined_thd, result.quality.thd);
        combined_dc = max(combined_dc, result.quality.dc_error);
    end

    fig_quality = figure('Visible', 'off', 'Position', [200, 200, 1200, 800]);

    % 創建 3x1 子圖
    subplot(3, 1, 1);
    imagesc(combined_steady');
    colormap(gca, [1 0.8 0.8; 0.8 1 0.8]);  % 紅色=失敗, 綠色=通過
    colorbar('Ticks', [0, 1], 'TickLabels', {'Fail', 'Pass'});
    xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('Steady State Check - P%d (All Kp)', Channel), 'FontSize', 13, 'FontWeight', 'bold');
    set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');

    subplot(3, 1, 2);
    imagesc(combined_thd');
    colorbar;
    clim([0, max(5, max(combined_thd(:)))]);  % 顯示 0-5% 範圍
    xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
    title('THD [%] - Worst Case', 'FontSize', 13, 'FontWeight', 'bold');
    set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');
    colormap(gca, hot);

    subplot(3, 1, 3);
    imagesc(combined_dc' * 1000);  % 轉成 mV
    colorbar;
    clim([0, max(10, max(combined_dc(:)*1000))]);  % 顯示 0-10mV 範圍
    xlabel('Frequency Index', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Channel', 'FontSize', 11, 'FontWeight', 'bold');
    title('DC Error [mV] - Worst Case', 'FontSize', 13, 'FontWeight', 'bold');
    set(gca, 'YTick', 1:6, 'YTickLabel', {'P1', 'P2', 'P3', 'P4', 'P5', 'P6'});
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');
    colormap(gca, hot);

    sgtitle(sprintf('Quality Summary - P%d (zc=%.0f)', Channel, zc), 'FontSize', 15, 'FontWeight', 'bold');

    saveas(fig_quality, fullfile(channel_dir, sprintf('quality_summary_P%d.png', Channel)));
    close(fig_quality);

    fprintf('  ✓ 品質摘要圖完成\n\n');

    % === 生成通道的 Kp 對比圖 ===
    fprintf('  📊 生成 P%d 的 Kp 對比圖...\n', Channel);

    fig_compare = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);

    % 上圖：Magnitude
    subplot(2,1,1);
    hold on; grid on;
    for kp_idx = 1:length(Kp_values)
        result = channel_results(kp_idx).result;
        mag = result.magnitude_ratio(:, Channel);
        Kp_val = result.Kp;
        Ki_val = result.Ki;

        semilogx(frequencies, mag, '-', 'LineWidth', 3, ...
                 'Color', kp_colors(kp_idx, :), ...
                 'DisplayName', sprintf('Kp=%.1f (Ki=%.0f)', Kp_val, Ki_val));

        % 標註 -3dB 點
        if ~isnan(result.bandwidth_3dB)
            idx_3dB = find(frequencies >= result.bandwidth_3dB, 1);
            if ~isempty(idx_3dB)
                mag_3dB = mag(idx_3dB);
                semilogx(result.bandwidth_3dB, mag_3dB, 'o', ...
                         'MarkerSize', 8, 'MarkerEdgeColor', kp_colors(kp_idx, :), ...
                         'MarkerFaceColor', kp_colors(kp_idx, :), 'LineWidth', 1.5, ...
                         'HandleVisibility', 'off');
            end
        end
    end
    ylim([0, 1.25]);
    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('P%d - Kp Comparison (zc=%.0f)', Channel, zc), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 11);
    xlim([frequencies(1), frequencies(end)]);
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');

    % 下圖：Phase
    subplot(2,1,2);
    hold on; grid on;
    for kp_idx = 1:length(Kp_values)
        result = channel_results(kp_idx).result;
        phase = result.phase_lag(:, Channel);
        Kp_val = result.Kp;

        semilogx(frequencies, phase, '-o', 'LineWidth', 2.5, ...
                 'Color', kp_colors(kp_idx, :), 'MarkerSize', 5, ...
                 'DisplayName', sprintf('Kp=%.1f', Kp_val));
    end
    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Phase [deg]', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('Phase Response - P%d', Channel), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 11);
    xlim([frequencies(1), frequencies(end)]);
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');

    saveas(fig_compare, fullfile(channel_dir, sprintf('kp_comparison_P%d.png', Channel)));
    close(fig_compare);

    % === 生成通道摘要 ===
    summary_file = fullfile(channel_dir, sprintf('summary_P%d.txt', Channel));
    fid = fopen(summary_file, 'w');
    fprintf(fid, 'P%d 通道頻率響應摘要\n', Channel);
    fprintf(fid, '════════════════════════════════════════════════════════════\n');
    fprintf(fid, '測試時間: %s\n', datestr(now));
    fprintf(fid, '通道: P%d\n', Channel);
    fprintf(fid, '頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
            frequencies(1), frequencies(end), length(frequencies));
    fprintf(fid, 'zc: %.0f\n', zc);
    fprintf(fid, '測試 Kp: [%s]\n', num2str(Kp_values));
    fprintf(fid, '════════════════════════════════════════════════════════════\n\n');
    fprintf(fid, '性能指標統計:\n');
    fprintf(fid, '────────────────────────────────────────────────────────────\n');
    fprintf(fid, 'Kp      Ki        -3dB [Hz]\n');
    fprintf(fid, '────────────────────────────────────────────────────────────\n');
    for kp_idx = 1:length(Kp_values)
        result = channel_results(kp_idx).result;
        fprintf(fid, '%-6.1f  %-8.0f  %-10.1f\n', ...
                result.Kp, result.Ki, result.bandwidth_3dB);
    end
    fprintf(fid, '────────────────────────────────────────────────────────────\n');
    fclose(fid);

    % 保存到批次結果
    batch_results(ch_idx).Channel = Channel;
    batch_results(ch_idx).channel_results = channel_results;

    fprintf('  ✓ P%d 完成！\n', Channel);
    fprintf('\n');
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  所有通道測試完成！\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 4: 生成通道對比圖 (固定 Kp)

fprintf('【生成通道對比圖】\n');
fprintf('────────────────────────\n');

for kp_idx = 1:length(Kp_values)
    Kp_val = Kp_values(kp_idx);

    fprintf('  📊 生成 Kp=%.1f 的 6 通道對比圖...\n', Kp_val);

    fig_ch_compare = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);

    % 上圖：Magnitude
    subplot(2,1,1);
    hold on; grid on;
    for ch_idx = 1:length(test_channels)
        Channel = test_channels(ch_idx);
        result = batch_results(ch_idx).channel_results(kp_idx).result;
        mag = result.magnitude_ratio(:, Channel);

        semilogx(frequencies, mag, '-', 'LineWidth', 2.5, ...
                 'Color', channel_colors(Channel, :), ...
                 'DisplayName', sprintf('P%d', Channel));
    end
    ylim([0, 1.25]);
    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('6 Channels Comparison - Kp=%.1f (Ki=%.0f)', Kp_val, Kp_val*zc), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'NumColumns', 3, 'FontSize', 10);
    xlim([frequencies(1), frequencies(end)]);
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');

    % 下圖：Phase
    subplot(2,1,2);
    hold on; grid on;
    for ch_idx = 1:length(test_channels)
        Channel = test_channels(ch_idx);
        result = batch_results(ch_idx).channel_results(kp_idx).result;
        phase = result.phase_lag(:, Channel);

        semilogx(frequencies, phase, '-o', 'LineWidth', 2, ...
                 'Color', channel_colors(Channel, :), 'MarkerSize', 4, ...
                 'DisplayName', sprintf('P%d', Channel));
    end
    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Phase [deg]', 'FontSize', 12, 'FontWeight', 'bold');
    title('Phase Response - All Channels', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'NumColumns', 3, 'FontSize', 10);
    xlim([frequencies(1), frequencies(end)]);
    set(gca, 'XScale', 'log');
    set(gca, 'XTick', [1, 10, 100, 1000, 10000]);
    set(gca, 'XTickLabel', {'10^0', '10^1', '10^2', '10^3', '10^4'});
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');

    saveas(fig_ch_compare, fullfile(batch_dir, sprintf('channel_comparison_Kp%.1f.png', Kp_val)));
    close(fig_ch_compare);
end

fprintf('  ✓ 通道對比圖完成\n\n');

%% SECTION 5: 生成頻寬熱圖

fprintf('【生成頻寬熱圖】\n');
fprintf('────────────────────────\n');

% 建立頻寬矩陣 (Kp × Channel)
bandwidth_matrix = zeros(length(Kp_values), length(test_channels));
for ch_idx = 1:length(test_channels)
    for kp_idx = 1:length(Kp_values)
        result = batch_results(ch_idx).channel_results(kp_idx).result;
        bandwidth_matrix(kp_idx, ch_idx) = result.bandwidth_3dB;
    end
end

fig_heatmap = figure('Visible', 'off', 'Position', [100, 100, 800, 500]);
imagesc(bandwidth_matrix);
colorbar;
colormap(hot);

% 設定標籤
xticks(1:length(test_channels));
xticklabels(arrayfun(@(x) sprintf('P%d', x), test_channels, 'UniformOutput', false));
yticks(1:length(Kp_values));
yticklabels(arrayfun(@(x) sprintf('Kp=%.1f', x), Kp_values, 'UniformOutput', false));

xlabel('Channel', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Kp Value', 'FontSize', 12, 'FontWeight', 'bold');
title('-3dB Bandwidth Heatmap [Hz]', 'FontSize', 14, 'FontWeight', 'bold');

% 在每個格子中標註數值
for kp_idx = 1:length(Kp_values)
    for ch_idx = 1:length(test_channels)
        bw = bandwidth_matrix(kp_idx, ch_idx);
        if ~isnan(bw)
            text(ch_idx, kp_idx, sprintf('%.0f', bw), ...
                 'HorizontalAlignment', 'center', 'Color', 'white', ...
                 'FontSize', 10, 'FontWeight', 'bold');
        end
    end
end

set(gca, 'FontSize', 11, 'FontWeight', 'bold');

saveas(fig_heatmap, fullfile(batch_dir, 'bandwidth_heatmap.png'));
close(fig_heatmap);

fprintf('  ✓ 頻寬熱圖完成\n\n');

%% SECTION 6: 生成總摘要

fprintf('【生成總摘要】\n');
fprintf('────────────────────────\n');

batch_elapsed = toc(batch_start_time);
summary_file = fullfile(batch_dir, 'batch_summary.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, 'PI Controller 批次頻率掃描總摘要\n');
fprintf(fid, '════════════════════════════════════════════════════════════\n');
fprintf(fid, '開始時間: %s\n', datestr(now - batch_elapsed/86400));
fprintf(fid, '結束時間: %s\n', datestr(now));
fprintf(fid, '總執行時間: %.1f 小時 (%.0f 分鐘)\n', batch_elapsed/3600, batch_elapsed/60);
fprintf(fid, '頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf(fid, 'zc 固定值: %.0f\n', zc);
fprintf(fid, '測試 Kp: [%s]\n', num2str(Kp_values));
fprintf(fid, '測試 Ki: [%s]\n', num2str(Kp_values * zc));
fprintf(fid, '測試通道: P1 ~ P6\n');
fprintf(fid, '總測試次數: %d (6 通道 × %d Kp)\n', total_tests, length(Kp_values));
fprintf(fid, '════════════════════════════════════════════════════════════\n\n');

fprintf(fid, '-3dB 頻寬統計表 [Hz]:\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, 'Kp      ');
for ch = test_channels
    fprintf(fid, ' P%-6d', ch);
end
fprintf(fid, '  平均    標準差\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');

for kp_idx = 1:length(Kp_values)
    fprintf(fid, '%-6.1f  ', Kp_values(kp_idx));
    bw_row = bandwidth_matrix(kp_idx, :);
    for bw = bw_row
        fprintf(fid, ' %-6.1f', bw);
    end
    fprintf(fid, '  %-6.1f  %-6.2f\n', mean(bw_row), std(bw_row));
end

fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, '平均    ');
for ch_idx = 1:length(test_channels)
    fprintf(fid, ' %-6.1f', mean(bandwidth_matrix(:, ch_idx)));
end
fprintf(fid, '  %-6.1f\n', mean(bandwidth_matrix(:)));
fprintf(fid, '────────────────────────────────────────────────────────────\n\n');

fprintf(fid, '通道對稱性分析:\n');
fprintf(fid, '• 6 個通道頻寬標準差: %.2f Hz\n', mean(std(bandwidth_matrix, 0, 2)));
fprintf(fid, '• 系統對稱性: ');
if mean(std(bandwidth_matrix, 0, 2)) < 5
    fprintf(fid, '優秀 (< 5 Hz)\n');
elseif mean(std(bandwidth_matrix, 0, 2)) < 10
    fprintf(fid, '良好 (< 10 Hz)\n');
else
    fprintf(fid, '需檢查 (> 10 Hz)\n');
end

fprintf(fid, '\nKp 選擇建議:\n');
for kp_idx = 1:length(Kp_values)
    avg_bw = mean(bandwidth_matrix(kp_idx, :));
    fprintf(fid, '• Kp=%.1f: 平均頻寬 %.1f Hz', Kp_values(kp_idx), avg_bw);
    if kp_idx == 2
        fprintf(fid, ' ✓ (推薦平衡點)');
    elseif kp_idx == 1
        fprintf(fid, ' (較穩定)');
    elseif kp_idx == length(Kp_values)
        fprintf(fid, ' (較快但可能過激進)');
    end
    fprintf(fid, '\n');
end

fprintf(fid, '\n檔案結構:\n');
fprintf(fid, '• 各通道資料夾: Channel_P1/ ~ Channel_P6/\n');
fprintf(fid, '  - 每個資料夾包含 %d 個 .mat 和 .png 檔案\n', length(Kp_values));
fprintf(fid, '  - Kp 對比圖: kp_comparison_P*.png\n');
fprintf(fid, '  - 摘要: summary_P*.txt\n');
fprintf(fid, '• 通道對比圖: channel_comparison_Kp*.png (%d 張)\n', length(Kp_values));
fprintf(fid, '• 頻寬熱圖: bandwidth_heatmap.png\n');
fprintf(fid, '• 配置記錄: batch_config.txt\n');
fprintf(fid, '════════════════════════════════════════════════════════════\n');

fclose(fid);

fprintf('  ✓ 總摘要完成\n\n');

%% SECTION 7: 完成

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                批次測試完成！\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
fprintf('【測試摘要】\n');
fprintf('  總測試次數: %d\n', total_tests);
fprintf('  總執行時間: %.1f 小時 (%.0f 分鐘)\n', batch_elapsed/3600, batch_elapsed/60);
fprintf('  輸出位置: %s\n', batch_dir);
fprintf('\n');
fprintf('【生成檔案】\n');
fprintf('  • %d 個通道資料夾\n', length(test_channels));
fprintf('  • %d 個原始數據 (.mat)\n', total_tests);
fprintf('  • %d 張個別 Bode Plot\n', total_tests);
fprintf('  • %d 張 Kp 對比圖\n', length(test_channels));
fprintf('  • %d 張通道對比圖\n', length(Kp_values));
fprintf('  • 1 張頻寬熱圖\n');
fprintf('  • 1 份總摘要\n');
fprintf('\n');
fprintf('批次掃頻腳本執行完畢！\n\n');
