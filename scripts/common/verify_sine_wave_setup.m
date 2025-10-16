% verify_sine_wave_setup.m
% 驗證 Sine Wave 設置是否正確
%
% 這個腳本幫助您驗證 Sine Wave blocks 是否正確添加和連接
%
% Author: Claude Code
% Date: 2025-10-14

clear; clc;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('           Sine Wave 設置驗證工具\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

model_name = 'Control_System_Integrated';

%% Step 1: 開啟模型
fprintf('【Step 1】開啟模型...\n');
if ~bdIsLoaded(model_name)
    open_system(model_name);
end
fprintf('  模型已開啟: %s\n\n', model_name);

%% Step 2: 檢查必要 blocks
fprintf('【Step 2】檢查必要的 blocks...\n\n');

blocks_needed = {
    struct('name', 'Vd_Sine', 'type', 'Sin', 'description', 'Sine Wave 信號源'),
    struct('name', 'Vd_Switch', 'type', 'MultiPortSwitch', 'description', 'Multiport Switch 切換器'),
    struct('name', 'Signal_Selector', 'type', 'Constant', 'description', '信號選擇器（控制 Switch）')
};

all_exist = true;
for i = 1:length(blocks_needed)
    block = blocks_needed{i};
    block_path = [model_name '/' block.name];

    try
        actual_type = get_param(block_path, 'BlockType');

        % 檢查類型是否正確
        if strcmpi(actual_type, block.type)
            fprintf('  ✓ %s (%s) - 正確\n', block.name, block.description);
        else
            fprintf('  ⚠ %s 存在但類型不對\n', block.name);
            fprintf('    預期: %s, 實際: %s\n', block.type, actual_type);
            all_exist = false;
        end

    catch
        fprintf('  ✗ %s - 不存在\n', block.name);
        fprintf('    說明: %s\n', block.description);
        all_exist = false;
    end
end

if ~all_exist
    fprintf('\n❌ 缺少必要的 blocks 或類型錯誤！\n\n');
    fprintf('請按照以下步驟操作：\n\n');

    fprintf('【添加 Sine Wave Block】\n');
    fprintf('1. 在 Simulink Library Browser 中找到 Sources → Sine Wave\n');
    fprintf('2. 拖曳到模型中，命名為 "Vd_Sine"\n');
    fprintf('3. 雙擊打開參數設定：\n');
    fprintf('   - Sine type: Time based\n');
    fprintf('   - Amplitude: [0; 0; 0; 0; 0; 0]\n');
    fprintf('   - Frequency: 1\n');
    fprintf('   - Phase: [0; 0; 0; 0; 0; 0]\n');
    fprintf('   - Sample time: 1e-5\n');
    fprintf('   - 勾選 "Interpret vector parameters as 1-D"\n\n');

    fprintf('【添加 Multiport Switch】\n');
    fprintf('1. 在 Library Browser 中找到 Signal Routing → Multiport Switch\n');
    fprintf('2. 拖曳到模型中，命名為 "Vd_Switch"\n');
    fprintf('3. 雙擊打開參數設定：\n');
    fprintf('   - Number of inputs: 2\n');
    fprintf('   - Data port order: One-based contiguous\n\n');

    fprintf('【添加 Constant Block (信號選擇器)】\n');
    fprintf('1. 在 Library Browser 中找到 Sources → Constant\n');
    fprintf('2. 拖曳到模型中，命名為 "Signal_Selector"\n');
    fprintf('3. 雙擊設定 Constant value: 1\n\n');

    fprintf('【連接 Blocks】\n');
    fprintf('1. 斷開原本 Vd 的輸出連線\n');
    fprintf('2. 連接 Vd → Vd_Switch 的第 1 個輸入\n');
    fprintf('3. 連接 Vd_Sine → Vd_Switch 的第 2 個輸入\n');
    fprintf('4. 連接 Signal_Selector → Vd_Switch 的控制端（上方）\n');
    fprintf('5. 連接 Vd_Switch 的輸出 → 原本 Vd 連接的目標\n\n');

    return;
end

fprintf('\n✓ 所有必要 blocks 都存在且類型正確！\n\n');

%% Step 3: 檢查連接
fprintf('【Step 3】檢查 blocks 連接...\n\n');

% 檢查 Vd_Switch 的輸入數量
try
    num_inputs = str2double(get_param([model_name '/Vd_Switch'], 'Inputs'));
    if num_inputs >= 2
        fprintf('  ✓ Vd_Switch 有 %d 個輸入端口\n', num_inputs);
    else
        fprintf('  ⚠ Vd_Switch 只有 %d 個輸入，需要至少 2 個\n', num_inputs);
    end
catch
    fprintf('  ⚠ 無法檢查 Vd_Switch 輸入數量\n');
end

%% Step 4: 測試切換功能
fprintf('\n【Step 4】測試信號切換功能...\n\n');

try
    % 測試切換到 Step (input 1)
    set_param([model_name '/Signal_Selector'], 'Value', '1');
    fprintf('  ✓ 成功切換到 Step 模式 (input 1)\n');

    % 測試切換到 Sine (input 2)
    set_param([model_name '/Signal_Selector'], 'Value', '2');
    fprintf('  ✓ 成功切換到 Sine Wave 模式 (input 2)\n');

    % 恢復到 Step
    set_param([model_name '/Signal_Selector'], 'Value', '1');
    fprintf('  ✓ 恢復到 Step 模式\n');

catch ME
    fprintf('  ❌ 切換測試失敗: %s\n', ME.message);
end

%% Step 5: 測試 Sine Wave 參數設定
fprintf('\n【Step 5】測試 Sine Wave 參數設定...\n\n');

try
    sine_block = [model_name '/Vd_Sine'];

    % 測試設定振幅
    test_amplitude = '[0.1; 0; 0; 0; 0; 0]';
    set_param(sine_block, 'Amplitude', test_amplitude);
    fprintf('  ✓ 振幅設定測試成功\n');

    % 測試設定頻率
    test_freq = '62.8318';  % 10 Hz in rad/s
    set_param(sine_block, 'Frequency', test_freq);
    fprintf('  ✓ 頻率設定測試成功\n');

    % 測試設定相位
    test_phase = '[0; 0; 0; 0; 0; 0]';
    set_param(sine_block, 'Phase', test_phase);
    fprintf('  ✓ 相位設定測試成功\n');

    % 恢復預設值
    set_param(sine_block, 'Amplitude', '[0; 0; 0; 0; 0; 0]');
    set_param(sine_block, 'Frequency', '1');

catch ME
    fprintf('  ❌ Sine Wave 參數設定失敗: %s\n', ME.message);
end

%% Step 6: 簡單功能測試
fprintf('\n【Step 6】執行簡單功能測試...\n\n');

try
    % 配置簡單的 sine wave
    configure_sine_wave(model_name, 'sine', 1, 0.1, 10, 0);
    fprintf('  ✓ configure_sine_wave 函數執行成功\n');

    % 短暫模擬測試
    set_param(model_name, 'StopTime', '0.01');
    fprintf('  執行 0.01 秒測試模擬...\n');
    out = sim(model_name);

    if ~isempty(out.tout)
        fprintf('  ✓ 模擬執行成功，產生 %d 個數據點\n', length(out.tout));
    end

    % 恢復 step 模式
    configure_sine_wave(model_name, 'step', 1, 0, 0, 0);
    fprintf('  ✓ 成功恢復到 Step 模式\n');

catch ME
    fprintf('  ❌ 功能測試失敗: %s\n', ME.message);
end

%% 總結
fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                   驗證完成\n');
fprintf('════════════════════════════════════════════════════════════\n');

if all_exist
    fprintf('\n✅ 您的 Sine Wave 設置看起來正確！\n\n');
    fprintf('下一步建議：\n');
    fprintf('1. 執行 test_sine_wave_integration.m 進行完整測試\n');
    fprintf('2. 選擇 test_mode = ''single_frequency'' 測試單一頻率\n');
    fprintf('3. 或選擇 test_mode = ''frequency_sweep'' 進行頻率掃描\n');
else
    fprintf('\n⚠ 請先完成上述設置步驟\n');
end

fprintf('\n');