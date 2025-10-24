% plot_theoretical_bode.m
% PI Controller 理論波德圖（閉迴路）
%
% 功能：
%   1. 計算 PI 控制器 C(s) 和受控體 H(s) 的閉迴路轉移函數 T(s)
%   2. 繪製理論波德圖（Magnitude 和 Phase）
%   3. 可選：疊加實測數據進行比較
%
% 閉迴路轉移函數：
%   T(s) = C(s)H(s) / [1 + C(s)H(s)]
%
% 其中：
%   C(s) = Kp + Ki/s          (PI 控制器)
%   H(s) = 給定的受控體轉移函數

clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           PI Controller 理論波德圖（閉迴路）\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% SECTION 1: 配置區域

% ===== PI 控制器參數 =====
zc = 2206;                % Ki/Kp
Kp_value = 2;
Ki_value = Kp_value * zc;

fprintf('【PI 控制器參數】\n');
fprintf('────────────────────────\n');
fprintf('  Kp = %.2f\n', Kp_value);
fprintf('  Ki = %.2f\n', Ki_value);
fprintf('  zc = %.0f\n', zc);
fprintf('\n');

% ===== 受控體轉移函數 H(s) =====
% H(s) = 1.1592×10⁷ / (s² + 6.6172×10³s + 1.1592×10⁷)
H_num = 1.1592e7;
H_den = [1, 6.6172e3, 1.1592e7];

fprintf('【受控體轉移函數 H(s)】\n');
fprintf('────────────────────────\n');
fprintf('  H(s) = %.4e / (s² + %.4es + %.4e)\n', H_num, H_den(2), H_den(3));
fprintf('\n');

% ===== 實測數據載入設定 =====
LOAD_EXPERIMENTAL_DATA = true;                    % 是否載入實測數據
experimental_mat_file = 'freq_sweep_ch5_20251022_220023.mat';  % 手動指定檔案名稱
% experimental_mat_file = '';  % 留空則自動找最新檔案

% 實測數據路徑
script_dir = fileparts(mfilename('fullpath'));
scripts_root = fullfile(script_dir, '..');
project_root = fullfile(scripts_root, '..');
experimental_data_dir = fullfile(project_root, 'test_results', 'pi_controller', 'frequency_response');

% ===== 波德圖頻率範圍 =====
freq_min = 1;           % 最小頻率 [Hz]
freq_max = 1500;       % 最大頻率 [Hz]
num_points = 100;      % 頻率點數

%% SECTION 2: 建立轉移函數

fprintf('【建立轉移函數】\n');
fprintf('────────────────────────\n');

% PI 控制器 C(s) = Kp + Ki/s = (Kp*s + Ki)/s
C_num = [Kp_value, Ki_value];
C_den = [1, 0];
C = tf(C_num, C_den);

fprintf('  ✓ PI 控制器 C(s) 已建立\n');
fprintf('    C(s) = (%.2f·s + %.2f) / s\n', Kp_value, Ki_value);

% 受控體 H(s)
H = tf(H_num, H_den);

fprintf('  ✓ 受控體 H(s) 已建立\n');

% 開迴路轉移函數 L(s) = C(s) * H(s)
L = C * H;

fprintf('  ✓ 開迴路轉移函數 L(s) = C(s)·H(s) 已建立\n');

% 閉迴路轉移函數 T(s) = L(s) / (1 + L(s))
T = feedback(L, 1);

fprintf('  ✓ 閉迴路轉移函數 T(s) = L(s)/(1+L(s)) 已建立\n');
fprintf('\n');

%% SECTION 3: 計算頻率響應

fprintf('【計算頻率響應】\n');
fprintf('────────────────────────\n');

% 頻率向量（對數分布）
freq_vec = logspace(log10(freq_min), log10(freq_max), num_points);
omega_vec = 2 * pi * freq_vec;

% 計算波德響應
[mag, phase, wout] = bode(T, omega_vec);

% 將輸出轉換為向量
mag_vec = squeeze(mag);           % 線性增益
mag_dB_vec = 20*log10(mag_vec);   % dB
phase_vec = squeeze(phase);       % 度

fprintf('  ✓ 頻率響應計算完成\n');
fprintf('    頻率範圍: %.1f Hz ~ %.1f kHz\n', freq_min, freq_max/1000);
fprintf('    頻率點數: %d\n', num_points);
fprintf('\n');

%% SECTION 4: 載入實測數據（可選）

experimental_loaded = false;
experimental_channel = NaN;
experimental_freq = [];
experimental_mag = [];
experimental_phase = [];

if LOAD_EXPERIMENTAL_DATA
    fprintf('【載入實測數據】\n');
    fprintf('────────────────────────\n');

    % 自動找最新檔案或使用指定檔案
    if isempty(experimental_mat_file)
        % 自動找最新檔案
        mat_files = dir(fullfile(experimental_data_dir, 'freq_sweep_ch*.mat'));

        if isempty(mat_files)
            fprintf('  ✗ 找不到實測數據檔案\n');
            fprintf('    搜尋路徑: %s\n', experimental_data_dir);
            fprintf('    跳過實測數據疊加\n\n');
        else
            % 按時間排序，取最新
            [~, idx] = max([mat_files.datenum]);
            experimental_mat_file = mat_files(idx).name;
            fprintf('  ℹ 自動選擇最新檔案: %s\n', experimental_mat_file);
        end
    else
        fprintf('  ℹ 使用指定檔案: %s\n', experimental_mat_file);
    end

    % 載入檔案
    if ~isempty(experimental_mat_file)
        mat_path = fullfile(experimental_data_dir, experimental_mat_file);

        if exist(mat_path, 'file')
            % 從檔案名稱解析通道號
            % 格式： freq_sweep_ch1_20250122_143052.mat → ch = 1
            tokens = regexp(experimental_mat_file, 'freq_sweep_ch(\d+)_', 'tokens');

            if ~isempty(tokens)
                experimental_channel = str2double(tokens{1}{1});
                fprintf('  ✓ 檔案解析: 通道 P%d\n', experimental_channel);
            else
                fprintf('  ✗ 無法從檔案名稱解析通道號\n');
                fprintf('    請確認檔案名稱格式: freq_sweep_ch<N>_<timestamp>.mat\n\n');
                LOAD_EXPERIMENTAL_DATA = false;
            end

            if LOAD_EXPERIMENTAL_DATA
                % 載入數據
                try
                    data = load(mat_path);
                    results = data.results;

                    experimental_freq = results.frequencies;
                    experimental_mag = results.magnitude_ratio(:, experimental_channel);
                    experimental_phase = results.phase_lag(:, experimental_channel);

                    experimental_loaded = true;

                    fprintf('  ✓ 數據載入完成\n');
                    fprintf('    頻率點數: %d\n', length(experimental_freq));
                    fprintf('    頻率範圍: %.1f ~ %.1f Hz\n', ...
                            experimental_freq(1), experimental_freq(end));
                    fprintf('    實測 Kp: %.2f\n', results.Kp);
                    fprintf('    實測 Ki: %.2f\n', results.Ki);
                    fprintf('\n');

                    % 檢查參數是否一致
                    if abs(results.Kp - Kp_value) > 1e-6 || abs(results.Ki - Ki_value) > 1e-6
                        fprintf('  ⚠ 警告: 實測數據的 PI 參數與理論不一致！\n');
                        fprintf('    理論: Kp=%.2f, Ki=%.2f\n', Kp_value, Ki_value);
                        fprintf('    實測: Kp=%.2f, Ki=%.2f\n', results.Kp, results.Ki);
                        fprintf('\n');
                    end

                catch ME
                    fprintf('  ✗ 數據載入失敗: %s\n', ME.message);
                    fprintf('    跳過實測數據疊加\n\n');
                    LOAD_EXPERIMENTAL_DATA = false;
                end
            end
        else
            fprintf('  ✗ 找不到檔案: %s\n', mat_path);
            fprintf('    跳過實測數據疊加\n\n');
            LOAD_EXPERIMENTAL_DATA = false;
        end
    end
end

%% SECTION 5: 繪製波德圖

fprintf('【繪製波德圖】\n');
fprintf('────────────────────────\n');

fig = figure('Name', 'Closed-Loop Bode Plot (Theoretical vs Experimental)', ...
             'Position', [100, 100, 1200, 800]);

% ===== 上圖：Magnitude =====
subplot(2,1,1);
hold on; grid on;

% 理論曲線（藍色粗實線）
semilogx(freq_vec, mag_vec, '-', 'LineWidth', 2.5, ...
         'Color', [0, 0.4470, 0.7410], 'DisplayName', 'Theoretical');

% 實測數據點（紅色圓圈）
if experimental_loaded
    semilogx(experimental_freq, experimental_mag, 'o', ...
             'MarkerSize', 8, 'LineWidth', 2, ...
             'MarkerEdgeColor', [0.8500, 0.3250, 0.0980], ...
             'MarkerFaceColor', [1, 0.6, 0.4], ...
             'DisplayName', sprintf('Experimental (P%d)', experimental_channel));
end

xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Magnitude Ratio', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Closed-Loop Frequency Response (Kp=%.2f, Ki=%.2f)', Kp_value, Ki_value), ...
      'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);
xlim([freq_min, freq_max]);

% 設定座標軸
set(gca, 'XScale', 'log');
set(gca, 'FontSize', 11, 'FontWeight', 'bold');

% ===== 下圖：Phase =====
subplot(2,1,2);
hold on; grid on;

% 理論曲線（藍色粗實線）
semilogx(freq_vec, phase_vec, '-', 'LineWidth', 2.5, ...
         'Color', [0, 0.4470, 0.7410], 'DisplayName', 'Theoretical');

% 實測數據點（紅色圓圈）
if experimental_loaded
    semilogx(experimental_freq, experimental_phase, 'o', ...
             'MarkerSize', 8, 'LineWidth', 2, ...
             'MarkerEdgeColor', [0.8500, 0.3250, 0.0980], ...
             'MarkerFaceColor', [1, 0.6, 0.4], ...
             'DisplayName', sprintf('Experimental (P%d)', experimental_channel));
end

xlabel('Frequency [Hz]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Phase [deg]', 'FontSize', 12, 'FontWeight', 'bold');
title('Phase Response', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);
xlim([freq_min, freq_max]);

% 設定座標軸
set(gca, 'XScale', 'log');
set(gca, 'FontSize', 11, 'FontWeight', 'bold');

fprintf('  ✓ 波德圖繪製完成\n');
fprintf('\n');

%% SECTION 6: 分析閉迴路特性

fprintf('【閉迴路系統分析】\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

% DC 增益（s=0 時的增益）
dc_gain = dcgain(T);
fprintf('  DC 增益: %.4f (%.2f dB, %.2f%%)\n', ...
        dc_gain, 20*log10(dc_gain), dc_gain*100);

% 找 -3dB 頻寬
idx_3dB = find(mag_dB_vec < (20*log10(dc_gain) - 3), 1, 'first');
if ~isempty(idx_3dB) && idx_3dB > 1
    f_3dB = freq_vec(idx_3dB);
    fprintf('  -3dB 頻寬: %.2f Hz\n', f_3dB);
else
    fprintf('  -3dB 頻寬: > %.2f Hz (超出範圍)\n', freq_max);
end

% 峰值增益
[peak_mag, peak_idx] = max(mag_vec);
peak_freq = freq_vec(peak_idx);
peak_mag_dB = 20*log10(peak_mag);

fprintf('  峰值增益: %.4f (%.2f dB) at %.2f Hz\n', ...
        peak_mag, peak_mag_dB, peak_freq);

% 相位裕度和增益裕度
[Gm, Pm, Wcg, Wcp] = margin(L);  % 使用開迴路 L(s) 計算裕度
fprintf('\n  穩定性裕度（基於開迴路）:\n');
fprintf('    增益裕度 (GM): %.2f dB at %.2f Hz\n', 20*log10(Gm), Wcg/(2*pi));
fprintf('    相位裕度 (PM): %.2f° at %.2f Hz\n', Pm, Wcp/(2*pi));

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');

%% SECTION 7: 保存結果（可選）

SAVE_RESULTS = true;

if SAVE_RESULTS
    fprintf('\n【保存結果】\n');
    fprintf('────────────────────────\n');

    % 輸出目錄
    output_dir = fullfile(project_root, 'test_results', 'pi_controller', 'theoretical_bode');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');

    % 保存圖片
    png_filename = sprintf('theoretical_bode_%s.png', timestamp);
    png_path = fullfile(output_dir, png_filename);
    saveas(fig, png_path);
    fprintf('  ✓ 圖片已保存: %s\n', png_filename);

    % 保存數據
    theoretical_results.freq = freq_vec;
    theoretical_results.magnitude = mag_vec;
    theoretical_results.magnitude_dB = mag_dB_vec;
    theoretical_results.phase = phase_vec;
    theoretical_results.Kp = Kp_value;
    theoretical_results.Ki = Ki_value;
    theoretical_results.zc = zc;
    theoretical_results.H_num = H_num;
    theoretical_results.H_den = H_den;
    theoretical_results.dc_gain = dc_gain;

    if experimental_loaded
        theoretical_results.experimental_file = experimental_mat_file;
        theoretical_results.experimental_channel = experimental_channel;
        theoretical_results.experimental_freq = experimental_freq;
        theoretical_results.experimental_mag = experimental_mag;
        theoretical_results.experimental_phase = experimental_phase;
    end

    mat_filename = sprintf('theoretical_bode_%s.mat', timestamp);
    mat_path = fullfile(output_dir, mat_filename);
    save(mat_path, 'theoretical_results', '-v7.3');
    fprintf('  ✓ 數據已保存: %s\n', mat_filename);

    fprintf('\n  📁 所有檔案保存至: %s\n', output_dir);
    fprintf('\n');
end

%% SECTION 8: 完成

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                     分析完成\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
