% generate_simulink_framework.m
% 建立完整的數位控制系統框架（不含控制器）
%
% Purpose:
%   建立包含以下元件的完整控制系統：
%     - 參考訊號 Vd (6×1)
%     - 控制器接口（輸入 Vd, Vm，輸出 u）
%     - DAC + Plant + ADC
%     - 輸出訊號 Vm (6×1)
%     - 監測訊號（u, Vm, Vm_analog）
%
% Usage:
%   1. Run Model_6_6_Continuous_Weighted.m to generate one_curve_36_results.mat
%   2. Run this script: generate_simulink_framework
%   3. Open model: open_system('Control_System_Framework')
%   4. Add controller block: From_Vd, From_Vm → [Controller] → u_in
%
% Output:
%   Control_System_Framework.slx - Complete control system framework
%
% Signal Naming:
%   Vd - 參考電壓 (Desired voltage)
%   Vm - 測量電壓 (Measured voltage)
%   u  - 控制訊號 (control signal)
%
% Author: Claude Code
% Date: 2025-10-09
% Modified: 2025-10-09 - Changed controller interface to (Vd, Vm) → u
% Updated: 2025-10-12 - 記錄實際調整後的模塊位置

function generate_simulink_framework()
    %% Load transfer function data
    if ~exist('one_curve_36_results.mat', 'file')
        error(['one_curve_36_results.mat not found!\n' ...
               'Please run Model_6_6_Continuous_Weighted.m first.']);
    end

    load('one_curve_36_results.mat', 'one_curve_results');

    a1_matrix = one_curve_results.a1_matrix;
    a2_matrix = one_curve_results.a2_matrix;
    b_matrix = one_curve_results.b_matrix;

    fprintf('=== Generate Control System Framework ===\n');
    fprintf('Loaded TF parameters from: one_curve_36_results.mat\n\n');

    %% System parameters
    Ts = 1e-5;  % 採樣時間 10 μs

    fprintf('System Configuration:\n');
    fprintf('  - Sample Time: %.0f μs (%.0f kHz)\n', Ts*1e6, 1/Ts/1000);
    fprintf('  - Transfer Functions: 36 (6×6 MIMO)\n');
    fprintf('  - Control Interface: (Vd, Vm) → [Controller] → u_in\n');
    fprintf('\n');

    %% Model configuration
    model_name = 'Control_System_Framework';

    % Close model if already open
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end

    % Create new model
    new_system(model_name);
    open_system(model_name);

    %% ========================================
    %  Layout Parameters - 基於實際調整後的位置
    %  ========================================
    fprintf('✓ 使用實際調整後的佈局參數\n\n');

    % 水平位置（基於實際模型測量）
    vd_x = 510;                 % 參考訊號 Vd
    goto_vd_x = 610;            % Goto_Vd
    controller_x = 505;         % 控制器區域（From_Vd, From_Vm）
    u_in_x = 810;               % 控制訊號輸入埠 u_in
    dac_x = 985;                % DAC
    plant_x = 1110;             % 受控體
    adc_x = 1425;               % ADC
    vm_x = 1580;                % 輸出 Vm
    goto_vm_x = 1570;           % Goto_Vm

    % 垂直位置（基於實際模型測量）
    main_y = 290;               % 主訊號鏈中心
    vd_y = 185;                 % Vd 位置
    monitor_y = 500;            % 監測訊號區

    % DAC/ADC 垂直間距
    row_spacing = 60;

    %% ========================================
    %  Section 1: 參考訊號 Vd & Goto
    %  ========================================

    fprintf('Creating reference signal Vd...\n');

    % Constant block for Vd
    add_block('simulink/Sources/Constant', [model_name '/Vd']);
    set_param([model_name '/Vd'], ...
        'Value', '[1; 1; 1; 1; 1; 1]', ...
        'SampleTime', num2str(Ts), ...
        'Position', [vd_x, vd_y-20, vd_x+50, vd_y+20]);

    % Goto block for Vd (供控制器使用)
    add_block('simulink/Signal Routing/Goto', [model_name '/Goto_Vd']);
    set_param([model_name '/Goto_Vd'], ...
        'GotoTag', 'Vd_to_Controller', ...
        'TagVisibility', 'local', ...
        'Position', [goto_vd_x, vd_y-10, goto_vd_x+50, vd_y+10]);

    add_line(model_name, 'Vd/1', 'Goto_Vd/1', 'autorouting', 'on');

    %% ========================================
    %  Section 2: 控制器接口 - From Vd & From Vm
    %  ========================================

    fprintf('Creating controller interface (From_Vd, From_Vm)...\n');

    % From block: Vd
    add_block('simulink/Signal Routing/From', [model_name '/From_Vd']);
    set_param([model_name '/From_Vd'], ...
        'GotoTag', 'Vd_to_Controller', ...
        'IconDisplay', 'Tag', ...
        'Position', [controller_x, main_y-10, controller_x+60, main_y+10]);

    % From block: Vm
    add_block('simulink/Signal Routing/From', [model_name '/From_Vm']);
    set_param([model_name '/From_Vm'], ...
        'GotoTag', 'Vm_to_Controller', ...
        'IconDisplay', 'Tag', ...
        'Position', [controller_x, main_y+50, controller_x+60, main_y+70]);

    % Terminator blocks (暫時終止訊號，等待控制器替換)
    add_block('simulink/Sinks/Terminator', [model_name '/Term_Vd']);
    set_param([model_name '/Term_Vd'], ...
        'Position', [controller_x+80, main_y-10, controller_x+100, main_y+10]);
    add_line(model_name, 'From_Vd/1', 'Term_Vd/1', 'autorouting', 'on');

    add_block('simulink/Sinks/Terminator', [model_name '/Term_Vm']);
    set_param([model_name '/Term_Vm'], ...
        'Position', [controller_x+80, main_y+50, controller_x+100, main_y+70]);
    add_line(model_name, 'From_Vm/1', 'Term_Vm/1', 'autorouting', 'on');

    %% ========================================
    %  Section 3: 控制器接口 - 控制訊號輸入 u_in
    %  ========================================

    fprintf('Creating controller interface (u_in)...\n');

    % 輸入埠：u_in (控制訊號，6×1)
    add_block('simulink/Sources/In1', [model_name '/u_in']);
    set_param([model_name '/u_in'], ...
        'Position', [u_in_x, main_y-10, u_in_x+30, main_y+10]);

    %% ========================================
    %  Section 4: DAC (Zero-Order Hold × 6)
    %  ========================================

    fprintf('Creating DAC subsystem...\n');

    % Demux: 拆分控制訊號
    add_block('simulink/Signal Routing/Demux', [model_name '/Demux_u']);
    set_param([model_name '/Demux_u'], ...
        'Outputs', '6', ...
        'Position', [dac_x-30, 110, dac_x-20, 470]);

    add_line(model_name, 'u_in/1', 'Demux_u/1', 'autorouting', 'on');

    % 建立 6 個 DAC
    for i = 1:6
        block_name = sprintf('%s/DAC_%d', model_name, i);
        add_block('simulink/Discrete/Zero-Order Hold', block_name);

        y_pos = 130 + (i-1)*row_spacing;
        set_param(block_name, ...
            'SampleTime', num2str(Ts), ...
            'Position', [dac_x, y_pos-10, dac_x+50, y_pos+10]);

        add_line(model_name, sprintf('Demux_u/%d', i), sprintf('DAC_%d/1', i), 'autorouting', 'on');
    end

    % Mux: 合併 DAC 輸出
    add_block('simulink/Signal Routing/Mux', [model_name '/Mux_DAC']);
    set_param([model_name '/Mux_DAC'], ...
        'Inputs', '6', ...
        'Position', [dac_x+75, 110, dac_x+85, 470]);

    for i = 1:6
        add_line(model_name, sprintf('DAC_%d/1', i), sprintf('Mux_DAC/%d', i), 'autorouting', 'on');
    end

    %% ========================================
    %  Section 5: Plant Subsystem (36 TF)
    %  ========================================

    fprintf('Creating plant subsystem...\n');

    plant_subsys = [model_name '/Plant_Subsystem'];
    add_block('built-in/Subsystem', plant_subsys);
    set_param(plant_subsys, ...
        'Position', [plant_x, 110, plant_x+150, 470]);

    % 刪除預設埠（安全刪除）
    try
        delete_block([plant_subsys '/In1']);
    catch
        try
            delete_block([plant_subsys '/In']);
        catch
        end
    end

    try
        delete_block([plant_subsys '/Out1']);
    catch
        try
            delete_block([plant_subsys '/Out']);
        catch
        end
    end

    % 建立 Plant 內部結構
    create_plant_internals(plant_subsys, a1_matrix, a2_matrix, b_matrix);

    % 連接 Mux_DAC → Plant
    add_line(model_name, 'Mux_DAC/1', 'Plant_Subsystem/1', 'autorouting', 'on');

    %% ========================================
    %  Section 6: ADC (Zero-Order Hold × 6)
    %  ========================================

    fprintf('Creating ADC subsystem...\n');

    % Demux: 拆分 Plant 輸出
    add_block('simulink/Signal Routing/Demux', [model_name '/Demux_Plant']);
    set_param([model_name '/Demux_Plant'], ...
        'Outputs', '6', ...
        'Position', [adc_x-115, 110, adc_x-105, 470]);

    add_line(model_name, 'Plant_Subsystem/1', 'Demux_Plant/1', 'autorouting', 'on');

    % 建立 6 個 ADC
    for i = 1:6
        block_name = sprintf('%s/ADC_%d', model_name, i);
        add_block('simulink/Discrete/Zero-Order Hold', block_name);

        y_pos = 130 + (i-1)*row_spacing;
        set_param(block_name, ...
            'SampleTime', num2str(Ts), ...
            'Position', [adc_x, y_pos-10, adc_x+50, y_pos+10]);

        add_line(model_name, sprintf('Demux_Plant/%d', i), sprintf('ADC_%d/1', i), 'autorouting', 'on');
    end

    % Mux: 合併為 Vm
    add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Vm']);
    set_param([model_name '/Mux_Vm'], ...
        'Inputs', '6', ...
        'Position', [vm_x-90, 110, vm_x-80, 470]);

    for i = 1:6
        add_line(model_name, sprintf('ADC_%d/1', i), sprintf('Mux_Vm/%d', i), 'autorouting', 'on');
    end

    %% ========================================
    %  Section 7: 輸出 Vm & Goto
    %  ========================================

    fprintf('Creating output Vm...\n');

    % 輸出埠：Vm (測量電壓，6×1)
    add_block('simulink/Sinks/Out1', [model_name '/Vm']);
    set_param([model_name '/Vm'], ...
        'Position', [vm_x, 160-10, vm_x+30, 160+10]);

    add_line(model_name, 'Mux_Vm/1', 'Vm/1', 'autorouting', 'on');

    % Goto block for Vm (供控制器使用)
    add_block('simulink/Signal Routing/Goto', [model_name '/Goto_Vm']);
    set_param([model_name '/Goto_Vm'], ...
        'GotoTag', 'Vm_to_Controller', ...
        'TagVisibility', 'local', ...
        'Position', [goto_vm_x, 220, goto_vm_x+50, 240]);

    add_line(model_name, 'Mux_Vm/1', 'Goto_Vm/1', 'autorouting', 'on');

    %% ========================================
    %  Section 8: 監測訊號 (Scopes & To Workspace)
    %  ========================================

    fprintf('Creating monitoring signals...\n');

    % 監測訊號 1: u (控制訊號)
    add_block('simulink/Sinks/Scope', [model_name '/Scope_u']);
    set_param([model_name '/Scope_u'], ...
        'Position', [885, 355, 935, 395]);
    add_line(model_name, 'u_in/1', 'Scope_u/1', 'autorouting', 'on');

    add_block('simulink/Sinks/To Workspace', [model_name '/u_log']);
    set_param([model_name '/u_log'], ...
        'VariableName', 'u', ...
        'Position', [885, 305, 935, 335]);
    add_line(model_name, 'u_in/1', 'u_log/1', 'autorouting', 'on');

    % 監測訊號 2: Vm (輸出)
    add_block('simulink/Sinks/Scope', [model_name '/Scope_Vm']);
    set_param([model_name '/Scope_Vm'], ...
        'Position', [1570, 270, 1620, 310]);
    add_line(model_name, 'Mux_Vm/1', 'Scope_Vm/1', 'autorouting', 'on');

    add_block('simulink/Sinks/To Workspace', [model_name '/Vm_log']);
    set_param([model_name '/Vm_log'], ...
        'VariableName', 'Vm', ...
        'Position', [1570, 330, 1620, 360]);
    add_line(model_name, 'Mux_Vm/1', 'Vm_log/1', 'autorouting', 'on');

    % 監測訊號 3: Vm_analog (類比輸出，從 Plant 直接取)
    add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Vm_analog']);
    set_param([model_name '/Mux_Vm_analog'], ...
        'Inputs', '6', ...
        'Position', [1455, 479, 1465, 591]);

    for i = 1:6
        add_line(model_name, sprintf('Demux_Plant/%d', i), sprintf('Mux_Vm_analog/%d', i), 'autorouting', 'on');
    end

    add_block('simulink/Sinks/To Workspace', [model_name '/Vm_analog_log']);
    set_param([model_name '/Vm_analog_log'], ...
        'VariableName', 'Vm_analog', ...
        'Position', [1500, 515, 1565, 555]);
    add_line(model_name, 'Mux_Vm_analog/1', 'Vm_analog_log/1', 'autorouting', 'on');

    %% ========================================
    %  Section 9: 標註與文件
    %  ========================================

    % 主標註
    annotation_text = sprintf(['Control System Framework (Controller Interface v2)\n' ...
                               'Modified: 2025-10-09\n' ...
                               'Updated: 2025-10-12\n\n' ...
                               '=== SIGNAL FLOW ===\n' ...
                               'Vd (6×1) → [Goto_Vd] → [From_Vd] → [CONTROLLER] → u_in → [DAC] → [Plant] → [ADC] → Vm (6×1) → [Goto_Vm] → [From_Vm]\n' ...
                               '                                         ↑                                                             │\n' ...
                               '                                         └─────────────────────────────────────────────────────────────┘\n\n' ...
                               '=== CONTROLLER INTERFACE ===\n' ...
                               'INPUT 1:  From_Vd (6×1) - Reference signal (via Goto/From)\n' ...
                               'INPUT 2:  From_Vm (6×1) - Measured output (via Goto/From)\n' ...
                               'OUTPUT:   u_in (6×1)    - Control signal\n\n' ...
                               '=== MONITORING ===\n' ...
                               '- Scope_u, u_log:       Control signal\n' ...
                               '- Scope_Vm, Vm_log:     Measured output (digital)\n' ...
                               '- Vm_analog_log:        Analog output\n\n' ...
                               'Sample Time: %.0f μs (Fs = %.0f kHz)\n\n' ...
                               'NOTE: Error calculation (e = Vd - Vm) should be done inside controller'], ...
                               Ts*1e6, 1/Ts/1000);

    add_block('built-in/Note', [model_name '/Info'], ...
              'Position', [50, 700], ...
              'Text', annotation_text, ...
              'FontSize', '9', ...
              'FontWeight', 'bold');

    % 區域標註（簡化版，只標示關鍵接口）
    add_block('built-in/Note', [model_name '/Label_Controller_Interface'], ...
              'Position', [controller_x - 30, main_y-100], ...
              'Text', ['╔═══════════════════════════╗\n' ...
                       '║  CONTROLLER INTERFACE     ║\n' ...
                       '╠═══════════════════════════╣\n' ...
                       '║  INPUT 1: From_Vd (6×1)   ║\n' ...
                       '║  INPUT 2: From_Vm (6×1)   ║\n' ...
                       '║  OUTPUT:  → u_in (6×1)    ║\n' ...
                       '╚═══════════════════════════╝'], ...
              'FontSize', '10', ...
              'FontWeight', 'bold', ...
              'ForegroundColor', 'red');

    %% Save model
    save_system(model_name);

    fprintf('\n✓ Control system framework created: %s.slx\n', model_name);
    fprintf('\n=== Model Structure ===\n');
    fprintf('  CONTROLLER INTERFACE:\n');
    fprintf('    - From_Vd:  Reference signal (6×1) - via Goto/From\n');
    fprintf('    - From_Vm:  Measured output (6×1) - via Goto/From\n');
    fprintf('    - u_in:     Control signal input (6×1)\n');
    fprintf('\n');
    fprintf('  OUTPUTS:\n');
    fprintf('    - Vm:       Measured output (6×1)\n');
    fprintf('\n');
    fprintf('  MONITORING:\n');
    fprintf('    - Scope_u, u_log:      Control signal u\n');
    fprintf('    - Scope_Vm, Vm_log:    Digital output Vm\n');
    fprintf('    - Vm_analog_log:       Analog output Vm_analog\n');
    fprintf('\n');
    fprintf('=== Next Steps ===\n');
    fprintf('  1. Open model: open_system(''%s'')\n', model_name);
    fprintf('  2. Delete Term_Vd and Term_Vm blocks\n');
    fprintf('  3. Add controller: From_Vd, From_Vm → [Controller] → u_in\n');
    fprintf('  4. Configure solver and run simulation\n');
    fprintf('\n');
    fprintf('=== Controller Interface (Goto/From) ===\n');
    fprintf('  Vd signal available via: ''Vd_to_Controller'' tag\n');
    fprintf('  Vm signal available via: ''Vm_to_Controller'' tag\n');
    fprintf('  Use From blocks to access these signals in your controller\n');
    fprintf('\n');
end

%% ========================================
%  Helper Function: Create Plant Internals
%  ========================================

function create_plant_internals(subsys_name, a1_matrix, a2_matrix, b_matrix)
    % 在受控體子系統內部建立 36 個轉移函數

    % 輸入埠
    add_block('simulink/Sources/In1', [subsys_name '/u_in']);
    set_param([subsys_name '/u_in'], 'Position', [50, 300, 80, 320]);

    % Demux 輸入
    add_block('simulink/Signal Routing/Demux', [subsys_name '/Demux_Input']);
    set_param([subsys_name '/Demux_Input'], ...
        'Outputs', '6', ...
        'Position', [150, 200, 160, 400]);

    add_line(subsys_name, 'u_in/1', 'Demux_Input/1', 'autorouting', 'on');

    % 版面參數
    tf_base_x = 300;
    sum_x = 900;
    row_spacing = 80;

    % 建立 36 個轉移函數和 6 個加法器
    for i = 1:6  % Output channel
        % 加法器
        sum_block = sprintf('%s/Sum_Ch%d', subsys_name, i);
        add_block('simulink/Math Operations/Sum', sum_block);
        sum_y = 200 + (i-1)*row_spacing;
        set_param(sum_block, ...
            'Inputs', '++++++', ...
            'Position', [sum_x, sum_y-10, sum_x+20, sum_y+10]);

        for j = 1:6  % Input channel
            % 轉移函數
            a1_ij = a1_matrix(i, j);
            a2_ij = a2_matrix(i, j);
            b_ij = b_matrix(i, j);

            tf_block = sprintf('%s/TF_H%d%d', subsys_name, i, j);
            add_block('simulink/Continuous/Transfer Fcn', tf_block);

            tf_x = tf_base_x + (j-1)*80;
            tf_y = 200 + (i-1)*row_spacing;
            set_param(tf_block, ...
                'Numerator', sprintf('[%.12e]', b_ij), ...
                'Denominator', sprintf('[1, %.12e, %.12e]', a1_ij, a2_ij), ...
                'Position', [tf_x, tf_y-15, tf_x+60, tf_y+15]);

            % 連接 Demux → TF
            add_line(subsys_name, sprintf('Demux_Input/%d', j), sprintf('TF_H%d%d/1', i, j), 'autorouting', 'on');

            % 連接 TF → Sum
            add_line(subsys_name, sprintf('TF_H%d%d/1', i, j), sprintf('Sum_Ch%d/%d', i, j), 'autorouting', 'on');
        end
    end

    % Mux 輸出
    add_block('simulink/Signal Routing/Mux', [subsys_name '/Mux_Output']);
    set_param([subsys_name '/Mux_Output'], ...
        'Inputs', '6', ...
        'Position', [1050, 200, 1060, 400]);

    % 連接 Sum → Mux
    for i = 1:6
        add_line(subsys_name, sprintf('Sum_Ch%d/1', i), sprintf('Mux_Output/%d', i), 'autorouting', 'on');
    end

    % 輸出埠
    add_block('simulink/Sinks/Out1', [subsys_name '/y_out']);
    set_param([subsys_name '/y_out'], 'Position', [1150, 290, 1180, 310]);

    add_line(subsys_name, 'Mux_Output/1', 'y_out/1', 'autorouting', 'on');
end
