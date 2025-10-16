% configure_sine_wave.m
% 配置 Simulink 模型以支援 Sine Wave 輸入
%
% 前置要求：
%   1. 模型中已添加 Vd_Sine (Sine Wave block)
%   2. 模型中已添加 Vd_Switch (Multiport Switch)
%   3. 模型中已添加 Signal_Selector (Constant block)
%
% Author: Claude Code
% Date: 2025-10-14

function configure_sine_wave(model_name, signal_type, channel, amplitude, freq_Hz, phase_deg)
    % 輸入參數：
    %   model_name - Simulink 模型名稱
    %   signal_type - 'step' 或 'sine'
    %   channel - 激發通道 (1-6)
    %   amplitude - 振幅 [V]
    %   freq_Hz - 頻率 [Hz] (僅用於 sine)
    %   phase_deg - 相位 [度] (僅用於 sine)

    % 開啟模型
    if ~bdIsLoaded(model_name)
        open_system(model_name);
    end

    % 檢查必要的 blocks 是否存在
    blocks_to_check = {
        'Vd',              % 原始 Constant block
        'Vd_Sine',         % Sine Wave block
        'Vd_Switch',       % Multiport Switch
        'Signal_Selector'  % 選擇器
    };

    fprintf('檢查模型 blocks...\n');
    for i = 1:length(blocks_to_check)
        block_path = [model_name '/' blocks_to_check{i}];
        if ~exist_block(block_path)
            warning('找不到 block: %s', block_path);
            fprintf('請先在模型中添加必要的 blocks\n');
            return;
        end
    end

    % 建立向量（6 通道）
    amplitude_vector = zeros(6, 1);
    amplitude_vector(channel) = amplitude;

    switch lower(signal_type)
        case 'step'
            fprintf('配置 Step 信號...\n');
            % 設定 Constant block
            set_param([model_name '/Vd'], 'Value', mat2str(amplitude_vector));

            % 切換到 step (input 1)
            set_param([model_name '/Signal_Selector'], 'Value', '1');

            fprintf('  ✓ Step 信號配置完成\n');
            fprintf('    通道: %d, 振幅: %.3f V\n', channel, amplitude);

        case 'sine'
            fprintf('配置 Sine Wave 信號...\n');

            % 計算參數
            freq_rad = 2 * pi * freq_Hz;  % 轉換為 rad/s
            phase_rad = phase_deg * pi / 180;  % 轉換為 rad

            % 建立相位向量
            phase_vector = zeros(6, 1);
            phase_vector(channel) = phase_rad;

            % 設定 Sine Wave block 參數
            sine_block = [model_name '/Vd_Sine'];

            % 振幅
            set_param(sine_block, 'Amplitude', mat2str(amplitude_vector));

            % 頻率（所有通道相同）
            set_param(sine_block, 'Frequency', num2str(freq_rad));

            % 相位
            set_param(sine_block, 'Phase', mat2str(phase_vector));

            % Bias (偏移)
            set_param(sine_block, 'Bias', '[0; 0; 0; 0; 0; 0]');

            % 切換到 sine (input 2)
            set_param([model_name '/Signal_Selector'], 'Value', '2');

            fprintf('  ✓ Sine Wave 信號配置完成\n');
            fprintf('    通道: %d\n', channel);
            fprintf('    振幅: %.3f V\n', amplitude);
            fprintf('    頻率: %.1f Hz (%.3f rad/s)\n', freq_Hz, freq_rad);
            fprintf('    相位: %.1f° (%.3f rad)\n', phase_deg, phase_rad);

        otherwise
            error('未知的信號類型: %s', signal_type);
    end
end

function exists = exist_block(block_path)
    % 檢查 block 是否存在
    try
        get_param(block_path, 'BlockType');
        exists = true;
    catch
        exists = false;
    end
end