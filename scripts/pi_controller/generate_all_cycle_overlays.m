% generate_all_cycle_overlays.m
% 為指定的測試結果生成所有頻率點的週期疊圖
%
% 使用方法：
%   1. 先執行 run_frequency_sweep.m（會保存測試數據）
%   2. 修改下面的 test_folder 為你的測試資料夾名稱
%   3. 執行此腳本

clear; clc; close all;

%% SECTION 1: 配置

% 測試資料夾名稱（修改這裡！）
test_folder = 'ch1_20251024_135539';

script_dir = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');
test_dir = fullfile(project_root, 'test_results', 'pi_controller', 'frequency_response', test_folder);

% 檢查資料夾
if ~exist(test_dir, 'dir')
    error('找不到測試資料夾: %s', test_dir);
end

% 讀取測試數據
mat_file = fullfile(test_dir, 'freq_sweep_data.mat');
if ~exist(mat_file, 'file')
    error('找不到測試數據檔案');
end

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           生成所有頻率點的週期疊圖\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

load(mat_file);

frequencies = results.frequencies;
Channel = results.Channel;
Ts = 1e-5;  % 採樣時間

fprintf('測試資料夾: %s\n', test_folder);
fprintf('頻率點數: %d\n', length(frequencies));
fprintf('激勵通道: P%d\n', Channel);
fprintf('\n');

%% SECTION 2: 提示用戶需要重新測試

fprintf('⚠️ 重要提示：\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('.mat 檔案中沒有保存時域數據（Vm_steady）。\n');
fprintf('\n');
fprintf('要生成週期疊圖，需要：\n');
fprintf('1. 在 run_frequency_sweep.m 中，FFT 分析之後加入：\n');
fprintf('   results.time_domain(freq_idx).Vm_steady = Vm_steady;\n');
fprintf('   results.time_domain(freq_idx).t_steady = t_steady;\n');
fprintf('\n');
fprintf('2. 或者使用下面的「即時生成」模式重新測試\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

response = input('是否重新執行測試並即時生成疊圖？(y/n): ', 's');

if ~strcmpi(response, 'y')
    fprintf('已取消。\n');
    return;
end

%% SECTION 3: 重新執行測試（即時生成疊圖）

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  開始重新測試（即時生成疊圖模式）\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

% 創建疊圖輸出資料夾
overlay_dir = fullfile(test_dir, 'cycle_overlays_all');
if ~exist(overlay_dir, 'dir')
    mkdir(overlay_dir);
end

% 模型設定（從原測試中讀取）
model_name = 'PI_Controller_Integrated';
controller_type = 'pi_controller';
model_path = fullfile(project_root, 'controllers', controller_type, [model_name '.slx']);

% 測試參數（從 results 中讀取）
Kp_value = results.Kp;
Ki_value = results.Ki;
Amplitude = 0.5;  % 假設（如果 results 中沒保存）
solver = 'ode5';
total_cycles = 120;
skip_cycles = 80;
fft_cycles = 40;
min_sim_time = 0.1;

SignalType = 1;  % Sine mode
Phase = 0;
StepTime = 0;

% 開啟模型
if ~bdIsLoaded(model_name)
    open_system(model_path);
end

% 設定 PI 參數
for ch = 1:6
    pi_block = sprintf('%s/PI controller/PI_Ch%d', model_name, ch);
    set_param(pi_block, 'P', 'Kp_value');
    set_param(pi_block, 'I', 'Ki_value');
end

fprintf('✓ 模型已配置\n\n');

% 對每個頻率點重新模擬
for freq_idx = 1:length(frequencies)
    Frequency = frequencies(freq_idx);
    period = 1 / Frequency;

    fprintf('────────────────────────────────────────────────────────\n');
    fprintf('[%2d/%2d] 頻率: %.1f Hz\n', freq_idx, length(frequencies), Frequency);
    fprintf('────────────────────────────────────────────────────────\n');

    % 計算模擬時間
    sim_time = total_cycles * period;
    sim_time = max(min_sim_time, sim_time);

    % 設定模擬參數
    set_param(model_name, 'StopTime', num2str(sim_time));
    set_param(model_name, 'Solver', solver);
    set_param(model_name, 'FixedStep', num2str(Ts));

    % 執行模擬
    fprintf('  ⏳ 模擬中...\n');
    tic;
    try
        out = sim(model_name);
        elapsed = toc;
        fprintf('  ✓ 模擬完成 (%.2f 秒)\n', elapsed);
    catch ME
        fprintf('  ✗ 模擬失敗: %s\n', ME.message);
        continue;
    end

    % 提取數據
    Vd_data = out.Vd;
    Vm_data = out.Vm;
    N = size(Vd_data, 1);
    t = (0:N-1)' * Ts;

    % 選取穩態數據
    skip_time = skip_cycles * period;
    fft_time = fft_cycles * period;
    t_start = skip_time;
    t_end = min(skip_time + fft_time, t(end));
    idx_steady = (t >= t_start) & (t <= t_end);

    Vm_steady = Vm_data(idx_steady, :);
    t_steady = t(idx_steady);

    % 生成週期疊圖（激勵通道）
    fprintf('  📊 生成週期疊圖...\n');

    samples_per_cycle = round(period / Ts);
    num_cycles_to_plot = min(fft_cycles, floor(length(t_steady) / samples_per_cycle));

    % 圖 1：激勵通道
    fig = figure('Visible', 'off', 'Position', [100, 100, 1000, 600]);
    hold on; grid on;

    for k = 1:num_cycles_to_plot
        idx_start = (k-1) * samples_per_cycle + 1;
        idx_end = k * samples_per_cycle;

        if idx_end <= length(Vm_steady(:, Channel))
            cycle_data = Vm_steady(idx_start:idx_end, Channel);
            t_cycle = (0:length(cycle_data)-1)' * Ts * 1000;

            color_intensity = (k-1) / (num_cycles_to_plot-1);
            plot(t_cycle, cycle_data, 'LineWidth', 1.5, ...
                 'Color', [color_intensity, 0, 1-color_intensity]);
        end
    end

    xlabel('Time within Cycle [ms]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(sprintf('Vm[P%d] [V]', Channel), 'FontSize', 12, 'FontWeight', 'bold');

    % 標題顯示品質狀態
    steady_ok = results.quality.steady_state(freq_idx, Channel);
    thd_val = results.quality.thd(freq_idx, Channel);
    thd_ok = results.quality.thd_pass(freq_idx, Channel);

    if steady_ok && thd_ok
        title_str = sprintf('Cycle Overlay - %.1f Hz, P%d (PASS)', Frequency, Channel);
        title_color = [0, 0.6, 0];  % 綠色
    elseif ~steady_ok && thd_ok
        title_str = sprintf('Cycle Overlay - %.1f Hz, P%d (WARN: Steady ✗, THD ✓)', ...
                            Frequency, Channel);
        title_color = [0.8, 0.5, 0];  % 橘色
    else
        title_str = sprintf('Cycle Overlay - %.1f Hz, P%d (FAIL)', Frequency, Channel);
        title_color = [0.8, 0, 0];  % 紅色
    end

    title(title_str, 'FontSize', 14, 'FontWeight', 'bold', 'Color', title_color);

    % 添加品質資訊
    info_str = sprintf('Steady: %s | THD: %.2f%% %s | Cycles: %d', ...
                       steady_ok ? '✓' : '✗', thd_val, thd_ok ? '✓' : '✗', ...
                       num_cycles_to_plot);
    text(0.02, 0.98, info_str, 'Units', 'normalized', ...
         'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', [1 1 1 0.8], ...
         'VerticalAlignment', 'top');

    % 顏色圖例
    colormap(jet(num_cycles_to_plot));
    cb = colorbar;
    cb.Label.String = 'Cycle Number';
    caxis([1, num_cycles_to_plot]);

    % 保存
    filename = sprintf('cycle_overlay_%.1fHz_P%d.png', Frequency, Channel);
    saveas(fig, fullfile(overlay_dir, filename));
    close(fig);

    fprintf('  ✓ 疊圖已保存: %s\n\n', filename);
end

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('  完成！所有疊圖已保存至:\n');
fprintf('  %s\n', overlay_dir);
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
