% run_rcontroller_test.m
% R Controller MIMO Controller 自動化測試腳本 (版本 3.0 - Refactored)
%
% 新功能：
%   ✓ Sine Wave 支援（需要模型已添加 Sine Wave blocks）
%   ✓ 李薩如圖（Vm vs Vd）- 檢查解耦
%   ✓ 6 通道時域響應對比
%   ✓ 自動模擬時間調整
%   ✓ 標準配色方案（P1-P6）
%   ✓ 模組化目錄結構
%
% Author: Claude Code
% Date: 2025-10-16

clear; clc; close all;

% 添加必要的路徑
script_dir_temp = fileparts(mfilename('fullpath'));
scripts_root_temp = fullfile(script_dir_temp, '..');
project_root_temp = fullfile(scripts_root_temp, '..');

% 添加共用函數路徑
addpath(fullfile(scripts_root_temp, 'common'));

% 添加控制器目錄到路徑（讓 Simulink 找到 Model Reference）
addpath(fullfile(project_root_temp, 'controllers', 'r_controller'));

%% ═══════════════════════════════════════════════════════════════
%                     SECTION 1: 配置區域
%  ═══════════════════════════════════════════════════════════════

% ┌─────────────────────────────────────────────────────────────┐
% │                      測試識別                                │
% └─────────────────────────────────────────────────────────────┘
test_name = 'r_controller_P5_Sine_500H_validation';    % 測試名稱（用於檔案命名）

% ┌─────────────────────────────────────────────────────────────┐
% │                   參考輸入 (Vd) 配置                         │
% └─────────────────────────────────────────────────────────────┘
signal_type = 'sine';            % 'step' 或 'sine'
active_channel = 5;              % 激發通道 (1-6，對應 P1-P6)
amplitude = 0.5;                 % 振幅 [V]

% --- Sine Wave 參數 ---
sine_frequency = 500;            % 頻率 [Hz]
sine_phase = 0;                  % 相位 [deg]

% ┌─────────────────────────────────────────────────────────────┐
% │                      模擬配置                                │
% └─────────────────────────────────────────────────────────────┘
% Step 模式
step_sim_time = 1.0;             % Step 信號模擬時間 [s]

% Sine Wave 模式（自動計算）
sine_min_cycles = 30;            % 最少模擬週期數
sine_skip_cycles = 20;           % 跳過前 N 個週期（暫態）
sine_display_cycles = 5;         % 顯示最後 N 個週期（穩態）
sine_min_sim_time = 0.1;         % 最小模擬時間 [s]
sine_max_sim_time = 50.0;         % 最大模擬時間 [s]

Ts = 1e-5;                       % 採樣時間 [s] (100 kHz)
solver = 'ode23tb';              % Simulink solver

% ┌─────────────────────────────────────────────────────────────┐
% │                      模型配置                                │
% └─────────────────────────────────────────────────────────────┘
model_name = 'r_controller_system_integrated';
controller_type = 'r_controller';

% 取得腳本所在目錄的絕對路徑
script_dir = fileparts(mfilename('fullpath'));      % scripts/type3/
scripts_root = fullfile(script_dir, '..');          % scripts/
project_root = fullfile(scripts_root, '..');        % Simulation/
model_path = fullfile(project_root, 'controllers', controller_type, [model_name '.slx']);

% ┌─────────────────────────────────────────────────────────────┐
% │                    控制器參數（參考）                        │
% └─────────────────────────────────────────────────────────────┘
lambda_c = 0.8179;               % 控制器極點
lambda_e = 0.3659;               % 估測器極點

% ┌─────────────────────────────────────────────────────────────┐
% │                    繪圖配置（Sine Wave）                     │
% └─────────────────────────────────────────────────────────────┘
% 標準配色（參考您的圖片）
colors = [
    0.0000, 0.4470, 0.7410;  % P1: 藍色
    0.8500, 0.3250, 0.0980;  % P2: 紅色
    0.9290, 0.6940, 0.1250;  % P3: 黃色
    0.4660, 0.6740, 0.1880;  % P4: 綠色
    0.4940, 0.1840, 0.5560;  % P5: 品紅
    0.3010, 0.7450, 0.9330;  % P6: 青色
];

lissajous_unified_axis = true;   % 李薩如圖統一座標軸
active_linewidth = 2.5;          % 激發通道線寬
other_linewidth = 1.5;           % 其他通道線寬

% ┌─────────────────────────────────────────────────────────────┐
% │                      性能準則（Step）                        │
% └─────────────────────────────────────────────────────────────┘
settling_criterion = 0.02;       % Settling time 判定 (2%)
max_overshoot_allow = 5;         % 允許的最大超調 [%]
max_ss_error_allow = 1e-4;       % 允許的最大穩態誤差 [V]

% ┌─────────────────────────────────────────────────────────────┐
% │                      輸出控制                                │
% └─────────────────────────────────────────────────────────────┘
ENABLE_PLOT = true;              % 顯示圖表
SAVE_PNG = true;                 % 保存圖片 (.png)
SAVE_MAT = true;                 % 保存數據 (.mat)
output_dir = fullfile('test_results', controller_type);  % 輸出目錄: test_results/type3/

%% ═══════════════════════════════════════════════════════════════
%                   配置區域結束 (以下為自動執行)
%  ═══════════════════════════════════════════════════════════════

%% SECTION 2: 初始化與驗證

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           R Controller 自動化測試 v1.0\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

% 驗證參數
if ~ismember(lower(signal_type), {'step', 'sine'})
    error('signal_type 必須是 ''step'' 或 ''sine''');
end

if active_channel < 1 || active_channel > 6
    error('active_channel 必須在 1-6 之間');
end

% 創建輸出目錄
if SAVE_PNG || SAVE_MAT
    % 設定輸出目錄為專案根目錄下的 test_results
    output_dir = fullfile(project_root, output_dir);

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    test_dir = fullfile(output_dir, sprintf('%s_%s', test_name, timestamp));
    mkdir(test_dir);
    fprintf('📁 輸出目錄: %s\n\n', test_dir);
end

%% SECTION 3: 配置信號與模擬時間

fprintf('【參考輸入 Vd 配置】\n');
fprintf('────────────────────────\n');
fprintf('  信號類型: %s\n', signal_type);
fprintf('  激發通道: P%d (Ch%d)\n', active_channel, active_channel);
fprintf('  振幅: %.3f V\n', amplitude);

% 計算模擬時間
if strcmpi(signal_type, 'sine')
    % Sine Wave：自動計算模擬時間
    period = 1 / sine_frequency;
    sim_time_required = (sine_skip_cycles + sine_display_cycles) * period;
    sim_time = max(sine_min_sim_time, min(sine_max_sim_time, sim_time_required));

    fprintf('  頻率: %.1f Hz\n', sine_frequency);
    fprintf('  週期: %.6f s\n', period);
    fprintf('  計算模擬時間: %.4f s (%d 週期)\n', sim_time_required, ...
            sine_skip_cycles + sine_display_cycles);
    fprintf('  實際模擬時間: %.4f s\n', sim_time);
else
    % Step：使用固定時間
    sim_time = step_sim_time;
    fprintf('  模擬時間: %.3f s\n', sim_time);
end

fprintf('\n');

%% SECTION 4: 開啟模型並配置信號

fprintf('【配置 Simulink 模型】\n');
fprintf('────────────────────────\n');
fprintf('  模型: %s\n', model_name);
fprintf('  專案根目錄: %s\n', project_root);
fprintf('  模型路徑: %s\n', model_path);

% 檢查模型
if ~exist(model_path, 'file')
    fprintf('  ❌ 錯誤：找不到模型檔案\n');
    fprintf('  當前工作目錄: %s\n', pwd);
    fprintf('  腳本目錄: %s\n', script_dir);
    error('找不到模型檔案: %s', model_path);
end

% 開啟模型
if ~bdIsLoaded(model_name)
    open_system(model_path);
end
fprintf('  ✓ 模型已開啟\n');

% 使用 configure_sine_wave_preview_v2 函數設定信號（Preview 版本）
try
    if strcmpi(signal_type, 'sine')
        configure_sine_wave_preview_v2('sine', active_channel, ...
                          amplitude, sine_frequency, sine_phase);
    else
        configure_sine_wave_preview_v2('step', active_channel, amplitude, 0, 0);
    end
    fprintf('  ✓ 信號已配置 (Preview 版本)\n');
catch ME
    error('信號配置失敗: %s\n可能原因：模型中 Vd_Generator 未設定為 Workspace 版本\n請執行 scripts/r_controller/set_workspace_vd_generator.m', ME.message);
end

% 設定模擬參數
set_param(model_name, 'StopTime', num2str(sim_time));
set_param(model_name, 'Solver', solver);
set_param(model_name, 'MaxStep', num2str(Ts));
fprintf('  ✓ 模擬參數已設定\n');

fprintf('\n');

%% SECTION 5: 執行模擬

fprintf('【執行 Simulink 模擬】\n');
fprintf('────────────────────────\n');
fprintf('  採樣頻率: %.0f kHz\n', 1/Ts/1000);
fprintf('  Solver: %s\n', solver);
fprintf('  ⏳ 模擬執行中...\n');

tic;
try
    out = sim(model_name);
    elapsed_time = toc;
    fprintf('  ✓ 模擬完成 (耗時 %.2f 秒)\n', elapsed_time);
catch ME
    error('模擬失敗: %s', ME.message);
end

fprintf('\n');

%% SECTION 6: 提取數據

fprintf('【數據提取】\n');
fprintf('────────────────────────\n');

try
    t = out.tout;
    Vd_data = out.Vd;
    Vm_data = out.Vm;
    e_data = out.e;
    u_data = out.u;

    % 確保時間向量是列向量
    if size(t, 2) > size(t, 1)
        t = t';
    end

    fprintf('  ✓ 數據點數: %d (%.3f 秒)\n', length(t), t(end));
    fprintf('  ✓ Vd: [%d × %d]\n', size(Vd_data, 1), size(Vd_data, 2));
    fprintf('  ✓ Vm: [%d × %d]\n', size(Vm_data, 1), size(Vm_data, 2));
catch ME
    error('數據提取失敗: %s', ME.message);
end

fprintf('\n');

%% SECTION 7: 選取穩態數據（Sine Wave）

if strcmpi(signal_type, 'sine')
    fprintf('【穩態數據選取】\n');
    fprintf('────────────────────────\n');

    % 計算倒數 N 個週期的起始時間
    period = 1 / sine_frequency;
    t_display_start = t(end) - sine_display_cycles * period;
    t_display_start = max(0, t_display_start);

    idx_display = t >= t_display_start;

    t_display = t(idx_display);
    Vd_display = Vd_data(idx_display, :);
    Vm_display = Vm_data(idx_display, :);

    fprintf('  顯示範圍: %.4f - %.4f s\n', t_display(1), t_display(end));
    fprintf('  顯示週期數: %.1f\n', (t_display(end) - t_display(1)) / period);
    fprintf('  顯示數據點: %d\n', length(t_display));

    fprintf('\n');

    %% SECTION 7.5: 相位分析（Sine Wave）
    fprintf('【相位分析】\n');
    fprintf('────────────────────────\n');

    % 計算採樣參數
    Fs = 1 / (t_display(2) - t_display(1));
    N_raw = length(t_display);

    % 計算整數個週期對應的點數
    points_per_cycle = Fs / sine_frequency;
    actual_cycles = floor(N_raw / points_per_cycle);
    N_cycles = round(actual_cycles * points_per_cycle);

    % 確保使用整數個週期的數據
    if N_cycles < N_raw
        t_fft = t_display(1:N_cycles);
        Vd_fft_data = Vd_display(1:N_cycles, :);
        Vm_fft_data = Vm_display(1:N_cycles, :);
    else
        t_fft = t_display;
        Vd_fft_data = Vd_display;
        Vm_fft_data = Vm_display;
        N_cycles = N_raw;
    end

    % FFT 頻率解析度
    freq_resolution = Fs / N_cycles;

    fprintf('  FFT 參數：\n');
    fprintf('    採樣頻率: %.0f kHz\n', Fs/1000);
    fprintf('    數據點數: %d (%.2f 個週期)\n', N_cycles, N_cycles/points_per_cycle);
    fprintf('    頻率解析度: %.3f Hz\n', freq_resolution);
    fprintf('    目標頻率: %.1f Hz\n', sine_frequency);
    fprintf('\n');

    phase_results = zeros(6, 1);
    gain_results = zeros(6, 1);
    freq_error = zeros(6, 1);

    for ch = 1:6
        vd = Vd_fft_data(:, ch);
        vm = Vm_fft_data(:, ch);

        % FFT 分析
        Vd_fft = fft(vd) / N_cycles;  % 正規化
        Vm_fft = fft(vm) / N_cycles;

        % 頻率軸
        freqs = (0:N_cycles-1) * Fs / N_cycles;

        % 找出目標頻率的索引（只看正頻率）
        pos_freqs = freqs(1:floor(N_cycles/2));
        Vd_fft_pos = Vd_fft(1:floor(N_cycles/2));
        Vm_fft_pos = Vm_fft(1:floor(N_cycles/2));

        [~, freq_idx] = min(abs(pos_freqs - sine_frequency));
        freq_actual = pos_freqs(freq_idx);
        freq_error(ch) = freq_actual - sine_frequency;

        % 計算相位
        phase_vd = angle(Vd_fft_pos(freq_idx));
        phase_vm = angle(Vm_fft_pos(freq_idx));
        phase_diff = phase_vm - phase_vd;

        % 正規化到 -180° 到 180°
        phase_diff_deg = phase_diff * 180/pi;
        while phase_diff_deg > 180, phase_diff_deg = phase_diff_deg - 360; end
        while phase_diff_deg < -180, phase_diff_deg = phase_diff_deg + 360; end

        phase_results(ch) = phase_diff_deg;

        % 計算增益（振幅比）
        amp_vd = abs(Vd_fft_pos(freq_idx)) * 2;  % *2 for single-sided spectrum
        amp_vm = abs(Vm_fft_pos(freq_idx)) * 2;
        gain_results(ch) = 20 * log10(amp_vm / amp_vd);  % dB

        % 顯示結果
        if ch == active_channel
            fprintf('  P%d (激發): 相位 = %+7.2f° | 增益 = %+6.2f dB | Δf = %+.3f Hz ⭐\n', ...
                    ch, phase_diff_deg, gain_results(ch), freq_error(ch));
        else
            fprintf('  P%d:        相位 = %+7.2f° | 增益 = %+6.2f dB | Δf = %+.3f Hz\n', ...
                    ch, phase_diff_deg, gain_results(ch), freq_error(ch));
        end
    end

    fprintf('\n');
    fprintf('  💡 說明：\n');
    fprintf('     相位: 負值 = Vm 滯後 Vd, 正值 = Vm 超前 Vd\n');
    fprintf('     增益: 0 dB = 完美追蹤, 負值 = 衰減\n');
    fprintf('     Δf:   頻率匹配誤差（應接近 0）\n');
    fprintf('\n');
end

%% SECTION 8: 繪圖

if ENABLE_PLOT
    fprintf('【生成圖表】\n');
    fprintf('────────────────────────\n');

    if strcmpi(signal_type, 'sine')
        %% Sine Wave 繪圖

        % === 圖 1: 李薩如圖（Vm vs Vd，6 條曲線疊圖）===
        fig1 = figure('Name', sprintf('Lissajous Curves - %s', test_name), ...
                      'Position', [100, 100, 900, 700]);

        hold on;
        grid on;

        % 繪製所有 6 個通道
        for ch = 1:6
            if ch == active_channel
                % 激發通道：粗線
                plot(Vd_display(:, ch), Vm_display(:, ch), ...
                     'Color', colors(ch, :), 'LineWidth', active_linewidth);
            else
                % 非激發通道：細線
                plot(Vd_display(:, ch), Vm_display(:, ch), ...
                     'Color', colors(ch, :), 'LineWidth', other_linewidth);
            end
        end

        xlabel('Vd (V)', 'FontSize', 13);
        ylabel('Vm (V)', 'FontSize', 13);
        title(sprintf('Closed Loop (Voltage Based) - %.0f Hz', sine_frequency), ...
              'FontSize', 14, 'FontWeight', 'bold');

        % 統一座標軸（如果啟用）
        if lissajous_unified_axis
            max_val = max([max(abs(Vd_display(:))), max(abs(Vm_display(:)))]);
            axis_lim = [-max_val*1.1, max_val*1.1];
            xlim(axis_lim);
            ylim(axis_lim);
            axis square;
        end

        % 加入相位和增益標註（僅激發通道）
        text(0.02, 0.98, sprintf('P%d: φ = %+.2f°, G = %+.2f dB', ...
             active_channel, phase_results(active_channel), gain_results(active_channel)), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'FontSize', 11, 'FontWeight', 'bold', ...
             'Color', colors(active_channel, :), ...
             'BackgroundColor', 'white', 'EdgeColor', colors(active_channel, :), ...
             'Margin', 3);

        fprintf('  ✓ 圖 1: 李薩如圖 (Vm vs Vd)\n');

        % === 圖 2: 6 個子圖（時域 Vd+Vm）===
        fig2 = figure('Name', sprintf('Time Domain - 6 Channels - %s', test_name), ...
                      'Position', [150, 150, 1400, 900]);

        for ch = 1:6
            subplot(2, 3, ch);

            % 先繪製 Vm（通道配色實線），後繪製 Vd（黑色虛線在上層）
            plot(t_display*1000, Vm_display(:, ch), '-', ...
                 'Color', colors(ch, :), 'LineWidth', 2.5);
            hold on;
            plot(t_display*1000, Vd_display(:, ch), '--', ...
                 'Color', [0, 0, 0], 'LineWidth', 2.5);

            grid on;
            xlabel('時間 (ms)', 'FontSize', 10);
            ylabel('電壓 (V)', 'FontSize', 10);

            % 標題：激發通道加粗
            if ch == active_channel
                title(sprintf('\\bfP%d (激發)', ch), 'FontSize', 12, 'Color', colors(ch, :));
                % 添加紅框
                ax = gca;
                ax.Box = 'on';
                ax.LineWidth = 2.5;
                ax.XColor = [0.8, 0, 0];
                ax.YColor = [0.8, 0, 0];
            else
                title(sprintf('P%d', ch), 'FontSize', 12, 'Color', colors(ch, :));
            end
        end

        % 總標題
        sgtitle(sprintf('%s @ %.0f Hz - 穩態響應（倒數 %d 週期）', ...
                strrep(test_name, '_', ' '), sine_frequency, sine_display_cycles), ...
                'FontSize', 14, 'FontWeight', 'bold');

        fprintf('  ✓ 圖 2: 6 通道時域響應\n');

        % === 圖 3: 完整時域響應（所有數據）===
        fig3 = figure('Name', sprintf('Full Time Response - %s', test_name), ...
                      'Position', [200, 200, 1000, 600]);

        % 繪製所有通道
        for ch = 1:6
            if ch == active_channel
                plot(t, Vm_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', active_linewidth);
            else
                plot(t, Vm_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', other_linewidth);
            end
            hold on;
        end

        grid on;
        xlabel('時間 (s)', 'FontSize', 12);
        ylabel('Vm (V)', 'FontSize', 12);
        title(sprintf('完整系統響應 - %s', strrep(test_name, '_', ' ')), ...
              'FontSize', 14, 'FontWeight', 'bold');

        fprintf('  ✓ 圖 3: 完整時域響應\n');

    else
        %% Step 繪圖（修改為 6 通道顯示）

        % === 圖 1: 6 通道輸出響應 ===
        fig1 = figure('Name', sprintf('Step Response - 6 Channels - %s', test_name), ...
                      'Position', [100, 100, 1400, 900]);

        for ch = 1:6
            subplot(2, 3, ch);

            % 先繪製 Vm（通道配色實線），後繪製 Vd（黑色虛線在上層）
            plot(t, Vm_data(:, ch), '-', 'Color', colors(ch, :), ...
                 'LineWidth', 2.5);
            hold on;
            plot(t, Vd_data(:, ch), '--', 'Color', [0, 0, 0], ...
                 'LineWidth', 2.5);

            grid on;
            xlabel('時間 (s)', 'FontSize', 10);
            ylabel('電壓 (V)', 'FontSize', 10);

            if ch == active_channel
                title(sprintf('\\bfP%d (激發)', ch), 'FontSize', 12, 'Color', colors(ch, :));
                ax = gca;
                ax.Box = 'on';
                ax.LineWidth = 2.5;
                ax.XColor = [0.8, 0, 0];
                ax.YColor = [0.8, 0, 0];
            else
                title(sprintf('P%d', ch), 'FontSize', 12, 'Color', colors(ch, :));
            end
        end

        sgtitle(sprintf('Step 響應 - %s', strrep(test_name, '_', ' ')), ...
                'FontSize', 14, 'FontWeight', 'bold');

        fprintf('  ✓ 圖 1: 6 通道 Step 響應\n');

        % === 圖 2: 誤差分析 ===
        fig2 = figure('Name', sprintf('Error Analysis - %s', test_name), ...
                      'Position', [150, 150, 1000, 600]);

        for ch = 1:6
            if ch == active_channel
                plot(t, e_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', active_linewidth);
            else
                plot(t, e_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', other_linewidth);
            end
            hold on;
        end

        grid on;
        xlabel('時間 (s)', 'FontSize', 12);
        ylabel('誤差 e = Vd - Vm (V)', 'FontSize', 12);
        title('追蹤誤差', 'FontSize', 14, 'FontWeight', 'bold');

        fprintf('  ✓ 圖 2: 誤差分析\n');

        % === 圖 3: 控制輸入 ===
        fig3 = figure('Name', sprintf('Control Input - %s', test_name), ...
                      'Position', [200, 200, 1000, 600]);

        for ch = 1:6
            if ch == active_channel
                plot(t, u_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', active_linewidth);
            else
                plot(t, u_data(:, ch), 'Color', colors(ch, :), ...
                     'LineWidth', other_linewidth);
            end
            hold on;
        end

        grid on;
        xlabel('時間 (s)', 'FontSize', 12);
        ylabel('控制輸入 u (V)', 'FontSize', 12);
        title('控制輸入', 'FontSize', 14, 'FontWeight', 'bold');

        fprintf('  ✓ 圖 3: 控制輸入\n');
    end

    fprintf('\n');
end

%% SECTION 9: 保存結果

if SAVE_PNG || SAVE_MAT
    fprintf('【保存結果】\n');
    fprintf('────────────────────────\n');

    % 保存圖片
    if SAVE_PNG && ENABLE_PLOT
        if strcmpi(signal_type, 'sine')
            saveas(fig1, fullfile(test_dir, 'lissajous_curves.png'));
            saveas(fig2, fullfile(test_dir, '6ch_time_domain.png'));
            saveas(fig3, fullfile(test_dir, 'full_response.png'));
        else
            saveas(fig1, fullfile(test_dir, '6ch_step_response.png'));
            saveas(fig2, fullfile(test_dir, 'error_analysis.png'));
            saveas(fig3, fullfile(test_dir, 'control_input.png'));
        end
        fprintf('  ✓ 圖片已保存 (.png)\n');
    end

    % 保存 MAT 數據
    if SAVE_MAT
        result = struct();
        result.config.test_name = test_name;
        result.config.signal_type = signal_type;
        result.config.active_channel = active_channel;
        result.config.amplitude = amplitude;
        result.config.sim_time = sim_time;
        result.config.Ts = Ts;

        if strcmpi(signal_type, 'sine')
            result.config.sine_frequency = sine_frequency;
            result.config.sine_phase = sine_phase;
            result.config.sine_display_cycles = sine_display_cycles;
        end

        result.data.t = t;
        result.data.Vd = Vd_data;
        result.data.Vm = Vm_data;
        result.data.e = e_data;
        result.data.u = u_data;

        if strcmpi(signal_type, 'sine')
            result.display.t = t_display;
            result.display.Vd = Vd_display;
            result.display.Vm = Vm_display;
            result.analysis.phase_deg = phase_results;     % 相位差（度）
            result.analysis.gain_dB = gain_results;        % 增益（dB）
            result.analysis.freq_error_Hz = freq_error;    % 頻率誤差（Hz）
            result.analysis.freq_resolution_Hz = freq_resolution;  % FFT 解析度
        end

        result.meta.timestamp = datestr(now);
        result.meta.elapsed_time = elapsed_time;

        save(fullfile(test_dir, 'result.mat'), 'result', '-v7.3');
        fprintf('  ✓ 數據已保存 (.mat)\n');
    end

    fprintf('  📁 所有檔案保存至: %s\n\n', test_dir);
end

%% SECTION 10: 測試總結

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                     測試完成\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

fprintf('【測試摘要】\n');
fprintf('  名稱: %s\n', test_name);
fprintf('  信號: %s, P%d, %.3f V\n', signal_type, active_channel, amplitude);
if strcmpi(signal_type, 'sine')
    fprintf('  頻率: %.1f Hz\n', sine_frequency);
end
fprintf('  執行時間: %.2f 秒\n', elapsed_time);

fprintf('\n');