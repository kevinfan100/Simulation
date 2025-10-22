% plot_freq_response.m
% 重新繪製頻率響應圖（自定義格式）
%
% 使用方式：
%   1. 將此腳本放在 freq_response_results 資料夾中
%   2. 執行此腳本，選擇要繪製的 .mat 檔案
%   3. 或直接指定檔案：plot_freq_response('freq_response_ch5_20251021_202541.mat')

function plot_freq_response(mat_filename)

    % 如果沒有指定檔案，則選擇最新的
    if nargin < 1
        % 取得腳本所在目錄
        script_dir = fileparts(mfilename('fullpath'));

        % 找出 script_dir 中最新的 .mat 檔案
        files = dir(fullfile(script_dir, 'freq_response_*.mat'));
        if isempty(files)
            error('找不到任何 freq_response_*.mat 檔案\n請確認檔案在: %s', script_dir);
        end

        % 按時間排序，取最新的
        [~, idx] = max([files.datenum]);
        mat_filename = fullfile(script_dir, files(idx).name);

        fprintf('自動選擇最新的檔案: %s\n', files(idx).name);
    end

    % 如果只提供檔名，自動加上路徑
    if ~isfile(mat_filename)
        script_dir = fileparts(mfilename('fullpath'));
        mat_filename = fullfile(script_dir, mat_filename);
    end

    % 載入數據
    fprintf('載入數據: %s\n', mat_filename);
    data = load(mat_filename);

    results = data.results;
    frequencies = data.frequencies;
    d_values = data.d_values;
    Channel = data.Channel;

    fprintf('  ✓ 數據已載入\n');
    fprintf('  - d 值: [%s]\n', num2str(d_values));
    fprintf('  - 頻率點數: %d\n', length(frequencies));
    fprintf('  - 激勵通道: P%d\n', Channel);
    fprintf('\n');

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

    %% ========== 圖 1 & 2: 各 d 值的所有通道響應 ==========

    num_d = length(d_values);

    for d_idx = 1:num_d
        d = results(d_idx).d_value;

        fprintf('繪製 d=%d 的響應圖...\n', d);

        % 計算線性增益比（不是 dB）
        magnitude_ratio = results(d_idx).magnitude_ratio;  % 已經是比值
        phase = results(d_idx).phase_lag;

        % 創建圖形
        fig = figure('Name', sprintf('Frequency Response - d=%d (Ch P%d)', d, Channel), ...
                     'Position', [100+50*d_idx, 100+50*d_idx, 1200, 800]);

        % ===== 上圖：Magnitude（線性刻度，所有通道）=====
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

        phase_ch = phase(:, Channel);

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

        fprintf('  ✓ 圖 %d 完成\n', d_idx);

        % 儲存圖片
        [~, base_name, ~] = fileparts(mat_filename);
        png_filename = sprintf('%s_replot_d%d.png', base_name, d);
        saveas(fig, png_filename);
        fprintf('  ✓ 已儲存: %s\n', png_filename);
    end

    %% ========== 圖 3: 相位對比（d=0 vs d=2，單圖）==========

    if num_d == 2
        fprintf('繪製相位對比圖...\n');

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

        fprintf('  ✓ 圖 3 完成\n');

        % 儲存圖片
        [~, base_name, ~] = fileparts(mat_filename);
        png_filename = sprintf('%s_replot_phase_compare.png', base_name);
        saveas(fig_compare, png_filename);
        fprintf('  ✓ 已儲存: %s\n', png_filename);
    end

    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════\n');
    fprintf('  繪圖完成！\n');
    fprintf('════════════════════════════════════════════════════════════\n');

end
