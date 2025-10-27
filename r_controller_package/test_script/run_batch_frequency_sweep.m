% run_batch_frequency_sweep.m
% R Controller 批次頻率掃描腳本 (按通道分組)
%
% 功能：
%   1. 測試所有 6 個通道 (逐通道激勵)
%   2. 每個通道獨立激勵，分析自己的響應
%   3. 所有通道使用相同的 lambda_c 和 lambda_e
%   4. 自動生成對比圖和摘要表
%   5. 按通道分組保存結果
%
% 輸出結構：
%   batch_YYYYMMDD_HHMMSS/
%   ├── Channel_P1/ (包含 .mat + Bode Plot + 品質摘要 + diagnostics/)
%   ├── Channel_P2/ ~ Channel_P6/
%   ├── channel_comparison.png (6 通道對比)
%   ├── bandwidth_heatmap.png
%   ├── batch_summary.txt
%   └── batch_config.txt

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('     R Controller 批次頻率掃描 (d=0, 按通道分組)\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 批次測試配置

% === 路徑設定 ===
script_dir = fileparts(mfilename('fullpath'));
package_root = fullfile(script_dir, '..');

% === R Controller 參數設定 ===
% 這裡設定要測試的頻寬參數（單位：Hz）
T = 1e-5;                    % 採樣時間 [s] (100 kHz)
fB_c = 4000;                 % 控制器頻寬 [Hz]
fB_e = 20000;                % 估測器頻寬 [Hz]

% 計算對應的 lambda 參數
lambda_c = exp(-fB_c * T * 2 * pi);  % 控制器 lambda
lambda_e = exp(-fB_e * T * 2 * pi);  % 估測器 lambda

% ==================== 計算控制器參數 ====================
% 使用 r_controller_calc_params 計算所有控制器係數
% 此函數會自動創建 Bus Object 並包裝為 Simulink.Parameter
params = r_controller_calc_params(fB_c, fB_e);
% ======================================================

% === Preview 參數 ===
d_preview = 0;               % Preview steps (d=0 for this test)

% === 測試通道 ===
test_channels = 1:6;         % 要測試的通道 (P1-P6)

% === 頻率設定 ===
% 使用與單通道測試相同的 17 個頻率點
frequencies = [1, 10, 50, 100, ...              % 低頻: 4點
               125, 200, 250, 400, 500, ...      % 中頻: 5點
               625, 800, 1000, 1250, 2000, ...   % 高頻: 5點
               2500, 3125, 4000, 5000, 6000];    % 超高頻: 3點

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
total_cycles = 120;         % 總週期數（80 暫態 + 40 穩態）
skip_cycles = 80;           % 跳過暫態週期數
fft_cycles = 40;            % FFT 分析週期數
min_sim_time = 0.1;         % 最小模擬時間 [s]（高頻用）
max_sim_time = Inf;         % 最大模擬時間 [s]（不設限）

% === 品質檢測門檻 ===
steady_state_threshold = 0.02;  % 2% of Amplitude
thd_threshold = 1.0;            % 1% THD
dc_tolerance = 0.01;            % 1% of Amplitude
freq_error_threshold = 0.1;     % 0.1% frequency error

% === 輸出設定 ===
output_base_dir = fullfile(package_root, 'test_results', 'frequency_response');
batch_timestamp = datestr(now, 'yyyymmdd_HHMMSS');
batch_dir = fullfile(output_base_dir, ['batch_' batch_timestamp]);

% === 模型設定 ===
model_name = 'r_controller_system_integrated';
model_path = fullfile(package_root, 'model', [model_name '.slx']);

%% SECTION 2: 初始化

fprintf('【批次測試配置】\n');
fprintf('────────────────────────\n');
fprintf('  控制器頻寬 fB_c: %.1f Hz (λ_c: %.4f)\n', fB_c, lambda_c);
fprintf('  估測器頻寬 fB_e: %.1f Hz (λ_e: %.4f)\n', fB_e, lambda_e);
fprintf('  Preview d: %d\n', d_preview);
fprintf('  測試通道: P%d ~ P%d\n', test_channels(1), test_channels(end));
fprintf('  總測試次數: %d (6 通道)\n', length(test_channels));
fprintf('  頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf('  Solver: %s (固定步長 %.0e s)\n', solver, Ts);
fprintf('\n');

% 預估執行時間
single_test_time = 4;  % 分鐘（每個通道）
total_tests = length(test_channels);
estimated_minutes = single_test_time * total_tests;
fprintf('  ⏱️ 預估執行時間: %.0f 分鐘 (%.1f 小時)\n', estimated_minutes, estimated_minutes/60);
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
fprintf(fid, 'R Controller 批次頻率掃描配置\n');
fprintf(fid, '════════════════════════════════════════\n');
fprintf(fid, '測試時間: %s\n', datestr(now));
fprintf(fid, '控制器頻寬 fB_c: %.1f Hz (λ_c: %.4f)\n', fB_c, lambda_c);
fprintf(fid, '估測器頻寬 fB_e: %.1f Hz (λ_e: %.4f)\n', fB_e, lambda_e);
fprintf(fid, 'Preview d: %d\n', d_preview);
fprintf(fid, '通道: P1 ~ P6 (逐通道激勵)\n');
fprintf(fid, '頻率: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf(fid, 'Solver: %s (Ts=%.0e)\n', solver, Ts);
fprintf(fid, '總測試: %d\n', total_tests);
fprintf(fid, '────────────────────────────────────────\n');
fprintf(fid, '品質檢測門檻:\n');
fprintf(fid, '  穩態判定: %.1f%%\n', steady_state_threshold * 100);
fprintf(fid, '  THD: %.1f%%\n', thd_threshold);
fprintf(fid, '  DC誤差: %.1f%%\n', dc_tolerance * 100);
fprintf(fid, '  頻率誤差: %.2f%%\n', freq_error_threshold);
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

% 顏色設定（與 PI Controller 相同）
channel_colors = [
    0.0000, 0.0000, 0.0000;  % P1: 黑色
    0.0000, 0.0000, 1.0000;  % P2: 藍色
    0.0000, 0.5000, 0.0000;  % P3: 綠色
    1.0000, 0.0000, 0.0000;  % P4: 紅色
    0.8000, 0.0000, 0.8000;  % P5: 粉紫色
    0.0000, 0.7500, 0.7500;  % P6: 青色
];

% === 外層迴圈：通道 (1A: 逐通道激勵) ===
for ch_idx = 1:length(test_channels)
    Channel = test_channels(ch_idx);

    test_counter = test_counter + 1;
    progress_pct = (test_counter / total_tests) * 100;

    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('  測試通道 P%d (%d/%d, %.1f%%)\n', Channel, ch_idx, length(test_channels), progress_pct);
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    % 創建通道資料夾
    channel_dir = fullfile(batch_dir, sprintf('Channel_P%d', Channel));
    if ~exist(channel_dir, 'dir')
        mkdir(channel_dir);
    end

    % 創建 diagnostics 子資料夾
    diagnostics_dir = fullfile(channel_dir, 'diagnostics');
    if ~exist(diagnostics_dir, 'dir')
        mkdir(diagnostics_dir);
    end

    % === 設定 R Controller 參數 (2A: 所有通道相同 lambda) ===
    assignin('base', 'lambda_c', lambda_c);
    assignin('base', 'lambda_e', lambda_e);
    assignin('base', 'd', d_preview);

    % 設定激勵通道
    assignin('base', 'Channel', Channel);

    % 初始化頻率掃描結果（6個通道）
    num_freq = length(frequencies);
    magnitude_ratio_all = zeros(num_freq, 6);
    phase_lag_all = zeros(num_freq, 6);
    sim_times = zeros(num_freq, 1);

    % 品質檢測結果
    quality_steady_state = zeros(num_freq, 6);
    quality_thd = NaN(num_freq, 6);
    quality_dc_error = zeros(num_freq, 6);
    quality_freq_error = zeros(num_freq, 6);

    % === 頻率掃描 ===
    channel_start_time = tic;

    for freq_idx = 1:num_freq
        Frequency = frequencies(freq_idx);
        period = 1 / Frequency;

        % 計算模擬時間
        sim_time = total_cycles * period;
        sim_time = max(min_sim_time, min(sim_time, max_sim_time));
        sim_times(freq_idx) = sim_time;

        fprintf('  [%2d/%2d] %.1f Hz ... ', freq_idx, num_freq, Frequency);

        % 設定 Vd Generator 參數
        assignin('base', 'Frequency', Frequency);
        assignin('base', 'Amplitude', Amplitude);
        assignin('base', 'Phase', Phase);
        assignin('base', 'SignalType', SignalType);
        assignin('base', 'Ts', Ts);
        assignin('base', 'StepTime', StepTime);

        % 設定 Simulink 參數
        set_param(model_name, 'StopTime', num2str(sim_time));
        set_param(model_name, 'Solver', solver);
        set_param(model_name, 'FixedStep', num2str(Ts));

        % 執行模擬
        try
            out = sim(model_name);
            fprintf('✓ (%.2f s)\n', toc);
            tic;  % 重置計時器
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

        % === 品質檢測 1: 穩態判定（針對激勵通道 Vd 和 Vm） ===
        % Vd 穩態檢測
        cycles_in_fft = floor(fft_time / period);
        samples_per_cycle = round(period / Ts);

        Vd_cycles = [];
        for cycle = 1:min(cycles_in_fft, 5)
            cycle_start = 1 + (cycle - 1) * samples_per_cycle;
            cycle_end = min(cycle * samples_per_cycle, length(Vd_steady));
            Vd_cycles = [Vd_cycles; Vd_steady(cycle_start:cycle_end, Channel)];
        end

        % Vm 穩態檢測
        Vm_cycles = [];
        for cycle = 1:min(cycles_in_fft, 5)
            cycle_start = 1 + (cycle - 1) * samples_per_cycle;
            cycle_end = min(cycle * samples_per_cycle, length(Vm_steady));
            Vm_cycles = [Vm_cycles; Vm_steady(cycle_start:cycle_end, Channel)];
        end

        % 計算穩態誤差
        vd_steady_error = std(Vd_cycles) / Amplitude;
        vm_steady_error = std(Vm_cycles) / Amplitude;
        quality_steady_state(freq_idx, Channel) = max(vd_steady_error, vm_steady_error);

        % FFT 分析
        N_fft = length(Vd_steady);
        fs = 1 / Ts;
        freq_axis = (0:N_fft-1) * fs / N_fft;
        [~, freq_bin_idx] = min(abs(freq_axis - Frequency));
        actual_freq = freq_axis(freq_bin_idx);

        % === 品質檢測 2: 頻率誤差 ===
        freq_error = abs(Frequency - actual_freq);
        freq_error_percent = (freq_error / Frequency) * 100;
        quality_freq_error(freq_idx, Channel) = freq_error_percent;

        % Vd FFT（激勵通道）
        Vd_fft = fft(Vd_steady(:, Channel));
        Vd_mag = abs(Vd_fft(freq_bin_idx)) * 2 / N_fft;
        Vd_phase = angle(Vd_fft(freq_bin_idx)) * 180 / pi;

        % === 品質檢測 3: DC 誤差 ===
        Vd_dc = abs(Vd_fft(1)) / N_fft;
        Vd_dc_error = Vd_dc / Amplitude;
        quality_dc_error(freq_idx, Channel) = Vd_dc_error;

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

            % === 品質檢測 4: THD ===
            if ch == Channel
                harmonics_idx = [2*freq_bin_idx, 3*freq_bin_idx, 4*freq_bin_idx, 5*freq_bin_idx];
                harmonics_idx = harmonics_idx(harmonics_idx <= length(Vm_fft)/2);

                harmonics_power = 0;
                for h_idx = harmonics_idx
                    harmonics_power = harmonics_power + abs(Vm_fft(h_idx))^2;
                end

                fundamental_power = abs(Vm_fft(freq_bin_idx))^2;

                if fundamental_power > 0
                    thd_val = sqrt(harmonics_power / fundamental_power) * 100;
                    quality_thd(freq_idx, ch) = thd_val;
                end
            end
        end

        % 保存診斷圖（僅在出現警告時）
        has_warning = false;
        warning_msgs = {};

        if quality_steady_state(freq_idx, Channel) > steady_state_threshold
            has_warning = true;
            warning_msgs{end+1} = sprintf('穩態 %.2f%%', quality_steady_state(freq_idx, Channel)*100);
        end
        if ~isnan(quality_thd(freq_idx, Channel)) && quality_thd(freq_idx, Channel) > thd_threshold
            has_warning = true;
            warning_msgs{end+1} = sprintf('THD %.2f%%', quality_thd(freq_idx, Channel));
        end
        if quality_dc_error(freq_idx, Channel) > dc_tolerance
            has_warning = true;
            warning_msgs{end+1} = sprintf('DC %.2f%%', quality_dc_error(freq_idx, Channel)*100);
        end
        if freq_error_percent > freq_error_threshold
            has_warning = true;
            warning_msgs{end+1} = sprintf('頻率 %.3f%%', freq_error_percent);
        end

        if has_warning
            % 生成診斷圖
            fig_diag = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]);

            % 上圖：Vd 時域波形
            subplot(2,2,1);
            plot(t(idx_steady), Vd_steady(:, Channel), 'b-', 'LineWidth', 1);
            hold on; grid on;
            xlabel('Time [s]', 'FontSize', 10);
            ylabel('Vd [V]', 'FontSize', 10);
            title(sprintf('P%d - Vd @ %.1f Hz', Channel, Frequency), 'FontSize', 11, 'FontWeight', 'bold');

            % 下左圖：Vm 時域波形
            subplot(2,2,3);
            plot(t(idx_steady), Vm_steady(:, Channel), 'r-', 'LineWidth', 1);
            hold on; grid on;
            xlabel('Time [s]', 'FontSize', 10);
            ylabel('Vm [V]', 'FontSize', 10);
            title(sprintf('P%d - Vm @ %.1f Hz', Channel, Frequency), 'FontSize', 11, 'FontWeight', 'bold');

            % 右上圖：Vd FFT 頻譜
            subplot(2,2,2);
            Vd_fft_mag = abs(Vd_fft(1:floor(N_fft/2))) * 2 / N_fft;
            freq_plot = freq_axis(1:floor(N_fft/2));
            semilogy(freq_plot, Vd_fft_mag, 'b-', 'LineWidth', 1);
            hold on; grid on;
            semilogy(actual_freq, Vd_mag, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            xlabel('Frequency [Hz]', 'FontSize', 10);
            ylabel('Magnitude [V]', 'FontSize', 10);
            title('Vd FFT Spectrum', 'FontSize', 11, 'FontWeight', 'bold');
            xlim([0, min(10*Frequency, fs/2)]);

            % 右下圖：Vm FFT 頻譜
            subplot(2,2,4);
            Vm_fft_mag = abs(fft(Vm_steady(:, Channel))) * 2 / N_fft;
            Vm_fft_mag = Vm_fft_mag(1:floor(N_fft/2));
            semilogy(freq_plot, Vm_fft_mag, 'r-', 'LineWidth', 1);
            hold on; grid on;
            Vm_mag_plot = abs(fft(Vm_steady(:, Channel)));
            Vm_mag_plot = abs(Vm_mag_plot(freq_bin_idx)) * 2 / N_fft;
            semilogy(actual_freq, Vm_mag_plot, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
            xlabel('Frequency [Hz]', 'FontSize', 10);
            ylabel('Magnitude [V]', 'FontSize', 10);
            title('Vm FFT Spectrum', 'FontSize', 11, 'FontWeight', 'bold');
            xlim([0, min(10*Frequency, fs/2)]);

            % 標題說明警告
            sgtitle(sprintf('P%d @ %.1f Hz - 品質警告: %s', Channel, Frequency, strjoin(warning_msgs, ', ')), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');

            % 保存診斷圖
            diag_filename = sprintf('diagnostic_P%d_%.0fHz.png', Channel, Frequency);
            saveas(fig_diag, fullfile(diagnostics_dir, diag_filename));
            close(fig_diag);
        end
    end

    channel_elapsed = toc(channel_start_time);
    fprintf('  ✓ P%d 完成 (%.1f 分鐘)\n', Channel, channel_elapsed/60);
    fprintf('\n');

    % === 保存此通道結果 ===
    test_result.frequencies = frequencies;
    test_result.magnitude_ratio = magnitude_ratio_all;
    test_result.phase_lag = phase_lag_all;
    test_result.magnitude_dB = 20 * log10(magnitude_ratio_all);
    test_result.sim_times = sim_times;
    test_result.Channel = Channel;
    test_result.lambda_c = lambda_c;
    test_result.lambda_e = lambda_e;
    test_result.fB_c = fB_c;
    test_result.fB_e = fB_e;
    test_result.d = d_preview;

    % 品質檢測結果
    test_result.quality_steady_state = quality_steady_state;
    test_result.quality_thd = quality_thd;
    test_result.quality_dc_error = quality_dc_error;
    test_result.quality_freq_error = quality_freq_error;

    % 計算 -3dB 頻寬（針對激勵通道）
    mag_dB_ch = test_result.magnitude_dB(:, Channel);

    % 線性插值計算 -3dB 頻寬
    idx_below_3dB = find(mag_dB_ch < -3, 1, 'first');

    if ~isempty(idx_below_3dB) && idx_below_3dB > 1
        % 線性插值
        f1 = frequencies(idx_below_3dB - 1);
        f2 = frequencies(idx_below_3dB);
        mag1 = mag_dB_ch(idx_below_3dB - 1);
        mag2 = mag_dB_ch(idx_below_3dB);

        % y = y1 + (y2-y1)/(x2-x1) * (x-x1)
        % -3 = mag1 + (mag2-mag1)/(f2-f1) * (f_3dB - f1)
        f_3dB = f1 + (f2 - f1) * (-3 - mag1) / (mag2 - mag1);
        test_result.bandwidth_3dB = f_3dB;
    else
        test_result.bandwidth_3dB = NaN;
    end

    % 保存 .mat 檔案
    mat_filename = sprintf('freq_sweep_P%d.mat', Channel);
    save(fullfile(channel_dir, mat_filename), 'test_result', '-v7.3');

    % === 繪製個別 Bode Plot ===
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
        % 使用插值計算 -3dB 點的增益
        mag_3dB = 10^(-3/20);  % -3dB 對應的比值 = 0.7079
        semilogx(test_result.bandwidth_3dB, mag_3dB, 'o', ...
                 'MarkerSize', 10, 'MarkerEdgeColor', [0.5, 0.5, 0.5], ...
                 'MarkerFaceColor', [0.8, 0.8, 0.8], 'LineWidth', 2, ...
                 'DisplayName', sprintf('-3dB @ %.1f Hz', test_result.bandwidth_3dB));
    end

    ylim([0, 1.25]);
    xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('P%d - fB_c=%.0f Hz, fB_e=%.0f Hz, d=%d', Channel, fB_c, fB_e, d_preview), ...
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
    png_filename = sprintf('bode_P%d.png', Channel);
    saveas(fig_individual, fullfile(channel_dir, png_filename));
    close(fig_individual);

    % === 生成品質摘要圖 ===
    fig_quality = figure('Visible', 'off', 'Position', [100, 100, 1400, 1000]);

    % 1. 穩態誤差
    subplot(2,2,1);
    semilogx(frequencies, quality_steady_state(:, Channel) * 100, '-o', ...
             'LineWidth', 2, 'MarkerSize', 6, 'Color', channel_colors(Channel, :));
    hold on; grid on;
    yline(steady_state_threshold * 100, 'r--', 'LineWidth', 2, ...
          'DisplayName', sprintf('門檻 %.1f%%', steady_state_threshold * 100));
    xlabel('Frequency [Hz]', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Steady-State Error [%]', 'FontSize', 11, 'FontWeight', 'bold');
    title('穩態誤差', 'FontSize', 12, 'FontWeight', 'bold');
    xlim([frequencies(1), frequencies(end)]);
    legend('Location', 'best');
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');

    % 2. THD
    subplot(2,2,2);
    thd_plot = quality_thd(:, Channel);
    valid_thd = ~isnan(thd_plot);
    if any(valid_thd)
        semilogx(frequencies(valid_thd), thd_plot(valid_thd), '-o', ...
                 'LineWidth', 2, 'MarkerSize', 6, 'Color', channel_colors(Channel, :));
        hold on; grid on;
        yline(thd_threshold, 'r--', 'LineWidth', 2, ...
              'DisplayName', sprintf('門檻 %.1f%%', thd_threshold));
        xlabel('Frequency [Hz]', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('THD [%]', 'FontSize', 11, 'FontWeight', 'bold');
        title('總諧波失真', 'FontSize', 12, 'FontWeight', 'bold');
        xlim([frequencies(1), frequencies(end)]);
        legend('Location', 'best');
        set(gca, 'FontSize', 10, 'FontWeight', 'bold');
    end

    % 3. DC 誤差
    subplot(2,2,3);
    semilogx(frequencies, quality_dc_error(:, Channel) * 100, '-o', ...
             'LineWidth', 2, 'MarkerSize', 6, 'Color', channel_colors(Channel, :));
    hold on; grid on;
    yline(dc_tolerance * 100, 'r--', 'LineWidth', 2, ...
          'DisplayName', sprintf('門檻 %.1f%%', dc_tolerance * 100));
    xlabel('Frequency [Hz]', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('DC Error [%]', 'FontSize', 11, 'FontWeight', 'bold');
    title('直流誤差', 'FontSize', 12, 'FontWeight', 'bold');
    xlim([frequencies(1), frequencies(end)]);
    legend('Location', 'best');
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');

    % 4. 頻率誤差
    subplot(2,2,4);
    semilogx(frequencies, quality_freq_error(:, Channel), '-o', ...
             'LineWidth', 2, 'MarkerSize', 6, 'Color', channel_colors(Channel, :));
    hold on; grid on;
    yline(freq_error_threshold, 'r--', 'LineWidth', 2, ...
          'DisplayName', sprintf('門檻 %.2f%%', freq_error_threshold));
    xlabel('Frequency [Hz]', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Frequency Error [%]', 'FontSize', 11, 'FontWeight', 'bold');
    title('頻率誤差', 'FontSize', 12, 'FontWeight', 'bold');
    xlim([frequencies(1), frequencies(end)]);
    legend('Location', 'best');
    set(gca, 'FontSize', 10, 'FontWeight', 'bold');

    sgtitle(sprintf('P%d - 品質檢測摘要', Channel), ...
            'FontSize', 14, 'FontWeight', 'bold');

    saveas(fig_quality, fullfile(channel_dir, sprintf('quality_summary_P%d.png', Channel)));
    close(fig_quality);

    % === 生成通道文字摘要 ===
    summary_file = fullfile(channel_dir, sprintf('summary_P%d.txt', Channel));
    fid = fopen(summary_file, 'w');
    fprintf(fid, 'P%d 通道頻率響應摘要\n', Channel);
    fprintf(fid, '════════════════════════════════════════════════════════════\n');
    fprintf(fid, '測試時間: %s\n', datestr(now));
    fprintf(fid, '通道: P%d (激勵通道)\n', Channel);
    fprintf(fid, '頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
            frequencies(1), frequencies(end), length(frequencies));
    fprintf(fid, '控制器頻寬 fB_c: %.1f Hz (λ_c: %.4f)\n', fB_c, lambda_c);
    fprintf(fid, '估測器頻寬 fB_e: %.1f Hz (λ_e: %.4f)\n', fB_e, lambda_e);
    fprintf(fid, 'Preview d: %d\n', d_preview);
    fprintf(fid, '════════════════════════════════════════════════════════════\n\n');
    fprintf(fid, '性能指標:\n');
    fprintf(fid, '────────────────────────────────────────────────────────────\n');
    fprintf(fid, '-3dB 頻寬: %.1f Hz\n', test_result.bandwidth_3dB);
    fprintf(fid, '執行時間: %.1f 分鐘\n', channel_elapsed/60);
    fprintf(fid, '────────────────────────────────────────────────────────────\n\n');

    fprintf(fid, '品質檢測統計:\n');
    fprintf(fid, '────────────────────────────────────────────────────────────\n');

    % 穩態誤差
    ss_violations = sum(quality_steady_state(:, Channel) > steady_state_threshold);
    fprintf(fid, '穩態誤差超標: %d / %d 點\n', ss_violations, num_freq);

    % THD
    thd_violations = sum(quality_thd(:, Channel) > thd_threshold);
    fprintf(fid, 'THD 超標: %d / %d 點\n', thd_violations, sum(~isnan(quality_thd(:, Channel))));

    % DC 誤差
    dc_violations = sum(quality_dc_error(:, Channel) > dc_tolerance);
    fprintf(fid, 'DC 誤差超標: %d / %d 點\n', dc_violations, num_freq);

    % 頻率誤差
    freq_violations = sum(quality_freq_error(:, Channel) > freq_error_threshold);
    fprintf(fid, '頻率誤差超標: %d / %d 點\n', freq_violations, num_freq);

    fprintf(fid, '────────────────────────────────────────────────────────────\n');
    fclose(fid);

    % 保存到批次結果
    batch_results(ch_idx).Channel = Channel;
    batch_results(ch_idx).result = test_result;
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  所有通道測試完成！\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 4: 生成 6 通道對比圖

fprintf('【生成 6 通道對比圖】\n');
fprintf('────────────────────────\n');

fig_ch_compare = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);

% 上圖：Magnitude
subplot(2,1,1);
hold on; grid on;
for ch_idx = 1:length(test_channels)
    Channel = test_channels(ch_idx);
    result = batch_results(ch_idx).result;
    mag = result.magnitude_ratio(:, Channel);

    semilogx(frequencies, mag, '-', 'LineWidth', 2.5, ...
             'Color', channel_colors(Channel, :), ...
             'DisplayName', sprintf('P%d', Channel));

    % 標註 -3dB 點
    if ~isnan(result.bandwidth_3dB)
        mag_3dB = 10^(-3/20);
        semilogx(result.bandwidth_3dB, mag_3dB, 'o', ...
                 'MarkerSize', 8, 'MarkerEdgeColor', channel_colors(Channel, :), ...
                 'MarkerFaceColor', channel_colors(Channel, :), 'LineWidth', 1.5, ...
                 'HandleVisibility', 'off');
    end
end
ylim([0, 1.25]);
xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('6 Channels Comparison - fB_c=%.0f Hz, fB_e=%.0f Hz, d=%d', fB_c, fB_e, d_preview), ...
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
    result = batch_results(ch_idx).result;
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

saveas(fig_ch_compare, fullfile(batch_dir, 'channel_comparison.png'));
close(fig_ch_compare);

fprintf('  ✓ 通道對比圖完成\n\n');

%% SECTION 5: 生成頻寬熱圖

fprintf('【生成頻寬熱圖】\n');
fprintf('────────────────────────\n');

% 建立頻寬向量 (1 × 6)
bandwidth_vector = zeros(1, length(test_channels));
for ch_idx = 1:length(test_channels)
    result = batch_results(ch_idx).result;
    bandwidth_vector(ch_idx) = result.bandwidth_3dB;
end

fig_heatmap = figure('Visible', 'off', 'Position', [100, 100, 1000, 300]);
imagesc(bandwidth_vector);
colorbar;
colormap(hot);

% 設定標籤
xticks(1:length(test_channels));
xticklabels(arrayfun(@(x) sprintf('P%d', x), test_channels, 'UniformOutput', false));
yticks(1);
yticklabels({sprintf('fB_c=%.0f Hz, fB_e=%.0f Hz', fB_c, fB_e)});

xlabel('Channel', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Configuration', 'FontSize', 12, 'FontWeight', 'bold');
title('-3dB Bandwidth [Hz]', 'FontSize', 14, 'FontWeight', 'bold');

% 在每個格子中標註數值
for ch_idx = 1:length(test_channels)
    bw = bandwidth_vector(ch_idx);
    if ~isnan(bw)
        text(ch_idx, 1, sprintf('%.1f', bw), ...
             'HorizontalAlignment', 'center', 'Color', 'white', ...
             'FontSize', 11, 'FontWeight', 'bold');
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

fprintf(fid, 'R Controller 批次頻率掃描總摘要\n');
fprintf(fid, '════════════════════════════════════════════════════════════\n');
fprintf(fid, '開始時間: %s\n', datestr(now - batch_elapsed/86400));
fprintf(fid, '結束時間: %s\n', datestr(now));
fprintf(fid, '總執行時間: %.1f 小時 (%.0f 分鐘)\n', batch_elapsed/3600, batch_elapsed/60);
fprintf(fid, '頻率範圍: %.1f ~ %.1f Hz (%d 點)\n', ...
        frequencies(1), frequencies(end), length(frequencies));
fprintf(fid, '控制器頻寬 fB_c: %.1f Hz (λ_c: %.4f)\n', fB_c, lambda_c);
fprintf(fid, '估測器頻寬 fB_e: %.1f Hz (λ_e: %.4f)\n', fB_e, lambda_e);
fprintf(fid, 'Preview d: %d\n', d_preview);
fprintf(fid, '測試通道: P1 ~ P6 (逐通道激勵)\n');
fprintf(fid, '總測試次數: %d\n', total_tests);
fprintf(fid, '════════════════════════════════════════════════════════════\n\n');

fprintf(fid, '-3dB 頻寬統計表 [Hz]:\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, '通道    ');
for ch = test_channels
    fprintf(fid, ' P%-6d', ch);
end
fprintf(fid, '  平均    標準差\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, 'BW      ');
for bw = bandwidth_vector
    fprintf(fid, ' %-6.1f', bw);
end
fprintf(fid, '  %-6.1f  %-6.2f\n', mean(bandwidth_vector), std(bandwidth_vector));
fprintf(fid, '────────────────────────────────────────────────────────────\n\n');

fprintf(fid, '通道對稱性分析:\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, '• 6 個通道頻寬標準差: %.2f Hz\n', std(bandwidth_vector));
fprintf(fid, '• 平均頻寬: %.1f Hz\n', mean(bandwidth_vector));
fprintf(fid, '• 最小頻寬: %.1f Hz (P%d)\n', min(bandwidth_vector), find(bandwidth_vector == min(bandwidth_vector), 1));
fprintf(fid, '• 最大頻寬: %.1f Hz (P%d)\n', max(bandwidth_vector), find(bandwidth_vector == max(bandwidth_vector), 1));
fprintf(fid, '• 系統對稱性: ');
if std(bandwidth_vector) < 5
    fprintf(fid, '優秀 (< 5 Hz)\n');
elseif std(bandwidth_vector) < 10
    fprintf(fid, '良好 (< 10 Hz)\n');
else
    fprintf(fid, '需檢查 (> 10 Hz)\n');
end
fprintf(fid, '────────────────────────────────────────────────────────────\n\n');

fprintf(fid, '品質檢測統計:\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
for ch_idx = 1:length(test_channels)
    Channel = test_channels(ch_idx);
    result = batch_results(ch_idx).result;

    ss_violations = sum(result.quality_steady_state(:, Channel) > steady_state_threshold);
    thd_violations = sum(result.quality_thd(:, Channel) > thd_threshold);
    dc_violations = sum(result.quality_dc_error(:, Channel) > dc_tolerance);
    freq_violations = sum(result.quality_freq_error(:, Channel) > freq_error_threshold);

    fprintf(fid, 'P%d:\n', Channel);
    fprintf(fid, '  • 穩態誤差超標: %d / %d 點\n', ss_violations, num_freq);
    fprintf(fid, '  • THD 超標: %d / %d 點\n', thd_violations, sum(~isnan(result.quality_thd(:, Channel))));
    fprintf(fid, '  • DC 誤差超標: %d / %d 點\n', dc_violations, num_freq);
    fprintf(fid, '  • 頻率誤差超標: %d / %d 點\n', freq_violations, num_freq);
end
fprintf(fid, '────────────────────────────────────────────────────────────\n\n');

fprintf(fid, '檔案結構:\n');
fprintf(fid, '────────────────────────────────────────────────────────────\n');
fprintf(fid, '• 各通道資料夾: Channel_P1/ ~ Channel_P6/\n');
fprintf(fid, '  - freq_sweep_P*.mat: 原始數據\n');
fprintf(fid, '  - bode_P*.png: Bode Plot\n');
fprintf(fid, '  - quality_summary_P*.png: 品質摘要圖\n');
fprintf(fid, '  - summary_P*.txt: 文字摘要\n');
fprintf(fid, '  - diagnostics/: 警告診斷圖（如有）\n');
fprintf(fid, '• 通道對比圖: channel_comparison.png\n');
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
fprintf('  • %d 張 Bode Plot\n', total_tests);
fprintf('  • %d 張品質摘要圖\n', total_tests);
fprintf('  • 1 張通道對比圖\n');
fprintf('  • 1 張頻寬熱圖\n');
fprintf('  • 1 份總摘要\n');
fprintf('\n');
fprintf('批次掃頻腳本執行完畢！\n\n');
