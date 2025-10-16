function configure_sine_wave_preview_v2(signal_type, channel, amplitude, frequency, phase)
    % configure_sine_wave_preview_v2 - 配置帶 preview 的 Vd 信號
    %
    % 使用 Workspace 變數方法 - 適用於所有 controller 類型
    %
    % 輸入：
    %   signal_type - 'step' 或 'sine'
    %   channel     - 激發通道 (1-6)
    %   amplitude   - 幅值 [V]
    %   frequency   - 頻率 [Hz]（sine 用）
    %   phase       - 相位 [deg]（sine 用）
    %
    % 使用範例：
    %   configure_sine_wave_preview_v2('sine', 1, 0.1, 60, 0);
    %   configure_sine_wave_preview_v2('step', 2, 0.5, 0, 0);
    %
    % 注意：
    %   此函數將參數儲存到 base workspace 的 'vd_params' 變數
    %   Simulink 模型中的 Vd_Generator 會讀取此變數
    %
    % Author: Claude Code
    % Date: 2025-10-16

    % 驗證輸入
    if ~ismember(lower(signal_type), {'step', 'sine'})
        error('signal_type 必須是 ''step'' 或 ''sine''');
    end

    if channel < 1 || channel > 6
        error('channel 必須在 1-6 之間');
    end

    % 創建參數結構
    params = struct();
    params.signal_type = lower(signal_type);
    params.channel = channel;
    params.amplitude = amplitude;
    params.frequency = frequency;
    params.phase = phase * pi / 180;  % 轉換為弧度
    params.step_time = 0.1;           % Step 信號的階躍時間 [s]

    % 存到 base workspace
    assignin('base', 'vd_params', params);

    % 顯示確認訊息
    if strcmpi(signal_type, 'sine')
        fprintf('  ✓ Vd 已配置 (preview): %s | Ch%d | %.3fV | %.1fHz | %.1f°\n', ...
                signal_type, channel, amplitude, frequency, phase);
    else
        fprintf('  ✓ Vd 已配置 (preview): %s | Ch%d | %.3fV | %.1fs\n', ...
                signal_type, channel, amplitude, params.step_time);
    end
end
