function inspect_simulink_model(model_name)
    % inspect_simulink_model - 檢視 Simulink 模型結構
    %
    % 輸入：
    %   model_name - 模型名稱（不含 .slx）
    %
    % 使用範例：
    %   inspect_simulink_model('r_controller_system_integrated');
    %
    % Author: Claude Code
    % Date: 2025-10-16

    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════\n');
    fprintf('           Simulink 模型檢視工具\n');
    fprintf('═══════════════════════════════════════════════════════════\n');
    fprintf('\n');

    % 檢查模型是否已載入
    if ~bdIsLoaded(model_name)
        fprintf('⏳ 載入模型: %s\n', model_name);
        try
            load_system(model_name);
        catch ME
            error('❌ 無法載入模型: %s\n錯誤訊息: %s', model_name, ME.message);
        end
    end

    fprintf('✓ 模型已載入: %s\n\n', model_name);

    %% 1. 獲取所有 blocks
    fprintf('【模型 Blocks 列表】\n');
    fprintf('─────────────────────────────────────────────\n');

    blocks = find_system(model_name, 'Type', 'Block');

    % 排除模型本身
    blocks = blocks(2:end);

    fprintf('  總共 %d 個 blocks\n\n', length(blocks));

    %% 2. 分類顯示重要的 blocks
    fprintf('【關鍵 Blocks 檢查】\n');
    fprintf('─────────────────────────────────────────────\n');

    % 檢查 Clock
    clock_blocks = find_system(model_name, 'BlockType', 'Clock');
    if isempty(clock_blocks)
        fprintf('  ❌ Clock: 未找到\n');
    else
        fprintf('  ✓ Clock: 找到 %d 個\n', length(clock_blocks));
        for i = 1:length(clock_blocks)
            fprintf('    - %s\n', clock_blocks{i});
        end
    end

    % 檢查 MATLAB Function blocks
    matlab_fcn_blocks = find_system(model_name, 'BlockType', 'MATLABFcn');
    sf_blocks = find_system(model_name, 'MaskType', 'MATLAB Function');

    all_matlab_blocks = unique([matlab_fcn_blocks; sf_blocks]);

    if isempty(all_matlab_blocks)
        fprintf('  ❌ MATLAB Function: 未找到\n');
    else
        fprintf('  ✓ MATLAB Function: 找到 %d 個\n', length(all_matlab_blocks));
        for i = 1:length(all_matlab_blocks)
            block_name = get_param(all_matlab_blocks{i}, 'Name');
            fprintf('    - %s\n', block_name);
        end
    end

    % 檢查 Sine Wave blocks
    sine_blocks = find_system(model_name, 'BlockType', 'Sin');
    if isempty(sine_blocks)
        fprintf('  ℹ Sine Wave: 未找到\n');
    else
        fprintf('  ✓ Sine Wave: 找到 %d 個\n', length(sine_blocks));
        for i = 1:length(sine_blocks)
            block_name = get_param(sine_blocks{i}, 'Name');
            fprintf('    - %s\n', block_name);
        end
    end

    % 檢查 Constant blocks
    const_blocks = find_system(model_name, 'BlockType', 'Constant');
    if ~isempty(const_blocks)
        fprintf('  ✓ Constant: 找到 %d 個\n', length(const_blocks));
        for i = 1:length(const_blocks)
            block_name = get_param(const_blocks{i}, 'Name');
            fprintf('    - %s\n', block_name);
        end
    end

    % 檢查 Switch/Selector blocks
    switch_blocks = find_system(model_name, 'BlockType', 'MultiPortSwitch');
    if ~isempty(switch_blocks)
        fprintf('  ✓ MultiPort Switch: 找到 %d 個\n', length(switch_blocks));
        for i = 1:length(switch_blocks)
            block_name = get_param(switch_blocks{i}, 'Name');
            fprintf('    - %s\n', block_name);
        end
    end

    fprintf('\n');

    %% 3. 檢查 Goto/From blocks (信號流)
    fprintf('【信號流檢查】\n');
    fprintf('─────────────────────────────────────────────\n');

    goto_blocks = find_system(model_name, 'BlockType', 'Goto');
    from_blocks = find_system(model_name, 'BlockType', 'From');

    if ~isempty(goto_blocks)
        fprintf('  Goto Tags:\n');
        for i = 1:length(goto_blocks)
            tag = get_param(goto_blocks{i}, 'GotoTag');
            fprintf('    - %s\n', tag);
        end
    end

    if ~isempty(from_blocks)
        fprintf('  From Tags:\n');
        for i = 1:length(from_blocks)
            tag = get_param(from_blocks{i}, 'GotoTag');
            fprintf('    - %s\n', tag);
        end
    end

    fprintf('\n');

    %% 4. 檢查 To Workspace blocks (數據輸出)
    fprintf('【數據輸出檢查】\n');
    fprintf('─────────────────────────────────────────────\n');

    to_workspace_blocks = find_system(model_name, 'BlockType', 'ToWorkspace');

    if isempty(to_workspace_blocks)
        fprintf('  ℹ To Workspace: 未找到\n');
    else
        fprintf('  ✓ To Workspace: 找到 %d 個\n', length(to_workspace_blocks));
        for i = 1:length(to_workspace_blocks)
            var_name = get_param(to_workspace_blocks{i}, 'VariableName');
            fprintf('    - %s\n', var_name);
        end
    end

    fprintf('\n');

    %% 5. Preview 需求檢查
    fprintf('【Preview 架構檢查】\n');
    fprintf('─────────────────────────────────────────────\n');

    has_clock = ~isempty(clock_blocks);
    has_vd_generator = false;

    % 檢查是否有名為 Vd_Generator 的 block
    for i = 1:length(all_matlab_blocks)
        block_name = get_param(all_matlab_blocks{i}, 'Name');
        if contains(lower(block_name), 'vd_generator') || contains(lower(block_name), 'generator')
            has_vd_generator = true;
            fprintf('  ✓ 找到疑似 Vd_Generator: %s\n', block_name);
        end
    end

    fprintf('\n');
    fprintf('  Preview 需求清單:\n');
    if has_clock
        fprintf('    ✓ Clock block (已存在)\n');
    else
        fprintf('    ❌ Clock block (需要添加)\n');
    end

    if has_vd_generator
        fprintf('    ✓ Vd_Generator MATLAB Function (已存在)\n');
    else
        fprintf('    ❌ Vd_Generator MATLAB Function (需要添加)\n');
    end

    fprintf('\n');

    %% 6. 總結建議
    fprintf('【操作建議】\n');
    fprintf('─────────────────────────────────────────────\n');

    if ~has_clock && ~has_vd_generator
        fprintf('  ⚠ 需要從頭建立 Preview 架構:\n');
        fprintf('     1. 添加 Clock block\n');
        fprintf('     2. 添加 Vd_Generator MATLAB Function\n');
        fprintf('     3. 連接 Clock → Vd_Generator\n');
        fprintf('     4. 連接 Vd_Generator → Controller\n');
    elseif ~has_clock
        fprintf('  ⚠ 需要添加 Clock block 並連接到 Vd_Generator\n');
    elseif ~has_vd_generator
        fprintf('  ⚠ 需要添加 Vd_Generator MATLAB Function 並連接 Clock\n');
    else
        fprintf('  ✓ Preview 基礎架構看起來已就位\n');
        fprintf('  ℹ 請檢查程式碼和連接是否正確\n');
    end

    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════════\n');
    fprintf('                     檢視完成\n');
    fprintf('═══════════════════════════════════════════════════════════\n');
    fprintf('\n');
end
