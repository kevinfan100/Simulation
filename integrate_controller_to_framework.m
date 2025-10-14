% integrate_controller_to_framework.m
% 將 Type 3 控制器整合到 Control_System_Framework
%
% Purpose:
%   整合 Type3_Controller_MatlabFunc 到現有的控制系統框架
%   刪除 terminator blocks 並連接控制器
%
% Process:
%   1. 載入 Control_System_Framework.slx
%   2. 另存為 Control_System_Integrated.slx
%   3. 刪除 Term_Vd 和 Term_Vm blocks
%   4. 添加 Type3_Controller 作為 Model Reference
%   5. 連接所有信號
%   6. 新增誤差監測 (e_log, Scope_e)
%
% Usage:
%   integrate_controller_to_framework()
%
% Author: Claude Code
% Date: 2025-10-14

function integrate_controller_to_framework()
    %% Configuration
    framework_model = 'Control_System_Framework';
    controller_model = 'Type3_Controller_MatlabFunc';
    integrated_model = 'Control_System_Integrated';

    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║        Integrating Controller to Framework                ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    %% Check if controller model exists
    if ~exist([controller_model '.slx'], 'file')
        error(['控制器模型 %s.slx 不存在！\n' ...
               '請先執行 create_type3_controller_matlab_func()'], controller_model);
    end

    %% Load Framework Model
    fprintf('▶ 載入 Framework 模型...\n');

    if ~exist([framework_model '.slx'], 'file')
        error(['Framework 模型 %s.slx 不存在！\n' ...
               '請先執行 generate_simulink_framework()'], framework_model);
    end

    load_system(framework_model);
    fprintf('  ✓ 載入 %s\n', framework_model);

    %% Save as Integrated Model
    fprintf('▶ 另存為整合模型...\n');

    % Close integrated model if already open
    if bdIsLoaded(integrated_model)
        close_system(integrated_model, 0);
    end

    % Delete existing integrated model file
    if exist([integrated_model '.slx'], 'file')
        delete([integrated_model '.slx']);
    end

    % Save framework as new integrated model
    save_system(framework_model, integrated_model);
    open_system(integrated_model);
    fprintf('  ✓ 另存為 %s\n', integrated_model);

    %% Delete Terminator Blocks
    fprintf('▶ 刪除 Terminator blocks...\n');

    try
        delete_block([integrated_model '/Term_Vd']);
        fprintf('  ✓ 刪除 Term_Vd\n');
    catch ME
        if contains(ME.message, 'does not exist')
            fprintf('  ℹ Term_Vd 已不存在\n');
        else
            rethrow(ME);
        end
    end

    try
        delete_block([integrated_model '/Term_Vm']);
        fprintf('  ✓ 刪除 Term_Vm\n');
    catch ME
        if contains(ME.message, 'does not exist')
            fprintf('  ℹ Term_Vm 已不存在\n');
        else
            rethrow(ME);
        end
    end

    %% Add Controller as Model Reference
    fprintf('▶ 添加控制器子系統...\n');

    % Controller position (between From blocks and u_in)
    controller_pos = [605, 270, 755, 360];

    % Add Model Reference block
    controller_block = [integrated_model '/Type3_Controller'];
    add_block('simulink/Ports & Subsystems/Model', controller_block);
    set_param(controller_block, ...
        'ModelName', controller_model, ...
        'Position', controller_pos, ...
        'BackgroundColor', 'cyan');

    fprintf('  ✓ 添加 Type3_Controller (Model Reference)\n');

    %% Connect Controller Signals
    fprintf('▶ 連接控制器信號...\n');

    % From_Vd → Controller/1 (Vd input)
    try
        add_line(integrated_model, 'From_Vd/1', 'Type3_Controller/1', ...
                 'autorouting', 'on');
        fprintf('  ✓ 連接 From_Vd → Type3_Controller/Vd\n');
    catch ME
        if contains(ME.message, 'already connected')
            fprintf('  ℹ From_Vd 已連接\n');
        else
            warning('連接 From_Vd 失敗: %s', ME.message);
        end
    end

    % From_Vm → Controller/2 (Vm input)
    try
        add_line(integrated_model, 'From_Vm/1', 'Type3_Controller/2', ...
                 'autorouting', 'on');
        fprintf('  ✓ 連接 From_Vm → Type3_Controller/Vm\n');
    catch ME
        if contains(ME.message, 'already connected')
            fprintf('  ℹ From_Vm 已連接\n');
        else
            warning('連接 From_Vm 失敗: %s', ME.message);
        end
    end

    % Controller/1 → u_in (control output)
    try
        add_line(integrated_model, 'Type3_Controller/1', 'u_in/1', ...
                 'autorouting', 'on');
        fprintf('  ✓ 連接 Type3_Controller/u → u_in\n');
    catch ME
        if contains(ME.message, 'already connected')
            fprintf('  ℹ u_in 已連接\n');
        else
            warning('連接 u_in 失敗: %s', ME.message);
        end
    end

    %% Add Error Monitoring
    fprintf('▶ 新增誤差監測...\n');

    % Add To Workspace block for error logging
    e_log_block = [integrated_model '/e_log'];
    if ~exist_block(integrated_model, 'e_log')
        add_block('simulink/Sinks/To Workspace', e_log_block);
        set_param(e_log_block, ...
            'VariableName', 'e', ...
            'SaveFormat', 'Array', ...
            'Position', [755, 390, 805, 420], ...
            'BackgroundColor', 'yellow');

        % Connect Controller/2 → e_log
        add_line(integrated_model, 'Type3_Controller/2', 'e_log/1', ...
                 'autorouting', 'on');
        fprintf('  ✓ 添加 e_log (To Workspace)\n');
    else
        fprintf('  ℹ e_log 已存在\n');
    end

    % Add Scope for error visualization
    scope_e_block = [integrated_model '/Scope_e'];
    if ~exist_block(integrated_model, 'Scope_e')
        add_block('simulink/Sinks/Scope', scope_e_block);
        set_param(scope_e_block, ...
            'Position', [755, 430, 805, 470], ...
            'BackgroundColor', 'yellow');

        % Connect Controller/2 → Scope_e
        add_line(integrated_model, 'Type3_Controller/2', 'Scope_e/1', ...
                 'autorouting', 'on');
        fprintf('  ✓ 添加 Scope_e (誤差顯示)\n');
    else
        fprintf('  ℹ Scope_e 已存在\n');
    end

    %% Add Integration Annotation
    fprintf('▶ 添加整合註解...\n');

    annotation_text = sprintf(['=== INTEGRATION INFO ===\n' ...
                               'Type 3 Controller Integrated\n' ...
                               'Date: %s\n\n' ...
                               'Controller: Type3_Controller_MatlabFunc\n' ...
                               'Framework: Control_System_Framework\n\n' ...
                               'New Monitoring:\n' ...
                               '- e_log: Error to workspace\n' ...
                               '- Scope_e: Error visualization'], ...
                               datestr(now));

    % Find a good position for the annotation
    ann_pos = [850, 350];

    add_block('built-in/Note', [integrated_model '/Integration_Info'], ...
              'Position', ann_pos, ...
              'Text', annotation_text, ...
              'FontSize', '9', ...
              'BackgroundColor', 'lightGray');

    fprintf('  ✓ 添加整合註解\n');

    %% Configure Model Settings
    fprintf('▶ 配置模型設定...\n');

    % Set solver to Fixed-step discrete
    set_param(integrated_model, ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', '1e-5');

    fprintf('  ✓ 設定 Solver: FixedStepDiscrete\n');
    fprintf('  ✓ 設定 Fixed Step: 1e-5 s\n');

    %% Save Integrated Model
    fprintf('\n▶ 儲存整合模型...\n');
    save_system(integrated_model);

    %% Summary
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                 整合完成！                                 ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('整合模型: %s.slx\n', integrated_model);
    fprintf('\n');
    fprintf('信號連接:\n');
    fprintf('  • From_Vd → Type3_Controller/Vd\n');
    fprintf('  • From_Vm → Type3_Controller/Vm\n');
    fprintf('  • Type3_Controller/u → u_in\n');
    fprintf('  • Type3_Controller/e → e_log, Scope_e\n');
    fprintf('\n');
    fprintf('新增監測:\n');
    fprintf('  • e_log: 誤差記錄到 workspace (變數名: e)\n');
    fprintf('  • Scope_e: 誤差實時顯示\n');
    fprintf('\n');
    fprintf('下一步:\n');
    fprintf('  1. 在 MATLAB 設定參數:\n');
    fprintf('     lambda_c = 0.5;\n');
    fprintf('     lambda_e = 0.3;\n');
    fprintf('     Ts = 1e-5;\n');
    fprintf('  2. 執行模擬:\n');
    fprintf('     sim(''%s'', ''StopTime'', ''0.1'');\n', integrated_model);
    fprintf('  3. 查看結果:\n');
    fprintf('     plot(e); %% 繪製誤差\n');
    fprintf('     plot(u); %% 繪製控制輸入\n');
    fprintf('     plot(Vm); %% 繪製輸出\n');
    fprintf('\n');
end

%% Helper function to check if a block exists
function exists = exist_block(model, block_name)
    try
        get_param([model '/' block_name], 'Handle');
        exists = true;
    catch
        exists = false;
    end
end