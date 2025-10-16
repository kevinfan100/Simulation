% analyze_frequency_response.m
% 頻譜分析功能 - 分析控制器的頻率響應
%
% Author: Claude Code
% Date: 2025-10-14

function [freq_Hz, magnitude_dB, phase_deg, bandwidth_Hz] = analyze_frequency_response(t, input, output, channel)
    % 輸入：
    %   t - 時間向量 [s]
    %   input - 輸入信號 (Vd)
    %   output - 輸出信號 (Vm)
    %   channel - 分析的通道
    %
    % 輸出：
    %   freq_Hz - 頻率向量 [Hz]
    %   magnitude_dB - 振幅響應 [dB]
    %   phase_deg - 相位響應 [度]
    %   bandwidth_Hz - -3dB 頻寬 [Hz]

    fprintf('執行頻譜分析...\n');

    % 取出特定通道
    vd = input(:, channel);
    vm = output(:, channel);

    % 計算採樣率
    Fs = 1 / (t(2) - t(1));
    N = length(t);

    %% 方法 1：FFT 分析（適用於任何信號）
    fprintf('  執行 FFT 分析...\n');

    % FFT
    Vd_fft = fft(vd);
    Vm_fft = fft(vm);

    % 頻率向量
    freq = (0:N-1) * (Fs/N);
    freq_half = freq(1:floor(N/2));

    % 單邊頻譜
    Vd_fft_half = Vd_fft(1:floor(N/2));
    Vm_fft_half = Vm_fft(1:floor(N/2));

    % 傳遞函數 H(f) = Vm(f) / Vd(f)
    H_fft = Vm_fft_half ./ (Vd_fft_half + eps);  % 避免除零

    % 轉換為 dB 和度
    magnitude_dB = 20 * log10(abs(H_fft));
    phase_deg = angle(H_fft) * 180 / pi;
    freq_Hz = freq_half;

    %% 方法 2：正弦掃頻分析（需要多次測試）
    % 這需要執行多個不同頻率的正弦測試
    % 在主腳本中實作批次測試

    %% 計算 -3dB 頻寬
    fprintf('  計算 -3dB 頻寬...\n');

    % 找到 DC 增益
    dc_gain_dB = magnitude_dB(1);

    % 找到 -3dB 點
    cutoff_dB = dc_gain_dB - 3;
    idx_3dB = find(magnitude_dB < cutoff_dB, 1, 'first');

    if ~isempty(idx_3dB)
        bandwidth_Hz = freq_Hz(idx_3dB);
        fprintf('    -3dB 頻寬: %.2f Hz\n', bandwidth_Hz);
    else
        bandwidth_Hz = NaN;
        fprintf('    -3dB 頻寬: > %.2f Hz (超出量測範圍)\n', freq_Hz(end));
    end

    %% 繪製 Bode 圖
    figure('Name', sprintf('Frequency Response - Channel %d', channel), ...
           'Position', [100, 100, 1000, 700]);

    % 振幅圖
    subplot(2, 1, 1);
    semilogx(freq_Hz(2:end), magnitude_dB(2:end), 'b', 'LineWidth', 2);
    grid on;
    xlabel('頻率 (Hz)', 'FontSize', 11);
    ylabel('振幅 (dB)', 'FontSize', 11);
    title(sprintf('頻率響應 - Channel %d', channel), 'FontSize', 13, 'FontWeight', 'bold');

    % 標記 -3dB 點
    if ~isnan(bandwidth_Hz)
        hold on;
        plot(bandwidth_Hz, cutoff_dB, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        text(bandwidth_Hz*1.2, cutoff_dB, sprintf(' -3dB @ %.1f Hz', bandwidth_Hz), ...
             'FontSize', 10, 'Color', 'red');
    end

    % 相位圖
    subplot(2, 1, 2);
    semilogx(freq_Hz(2:end), phase_deg(2:end), 'r', 'LineWidth', 2);
    grid on;
    xlabel('頻率 (Hz)', 'FontSize', 11);
    ylabel('相位 (度)', 'FontSize', 11);

    fprintf('  ✓ 頻譜分析完成\n');
end