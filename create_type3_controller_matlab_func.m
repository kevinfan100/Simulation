% create_type3_controller_matlab_func.m
% 自動建立 Type 3 控制器 Simulink 模型（使用 MATLAB Function）
%
% Purpose:
%   創建包含 MATLAB Function 的 Type 3 磁通控制器模型
%   控制器基於 PDF 第三頁的數學推導
%
% Inputs:
%   Vd (6×1) - 參考訊號
%   Vm (6×1) - 測量輸出
%
% Outputs:
%   u (6×1) - 控制訊號
%   e (6×1) - 追蹤誤差 δv[k]
%
% Parameters:
%   a1, a2, B_inv - 固定參數（寫死在函數內）
%   lambda_c, lambda_e - 可調參數（從 workspace 讀取）
%
% Usage:
%   create_type3_controller_matlab_func()
%
% Author: Claude Code
% Date: 2025-10-14

function create_type3_controller_matlab_func()
    %% Configuration
    model_name = 'Type3_Controller_MatlabFunc';

    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║     Creating Type 3 Controller with MATLAB Function       ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    %% Close and delete existing model
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
        fprintf('✓ 關閉現有模型\n');
    end

    if exist([model_name '.slx'], 'file')
        delete([model_name '.slx']);
        fprintf('✓ 刪除舊模型文件\n');
    end

    %% Create new model
    new_system(model_name);
    open_system(model_name);
    fprintf('✓ 建立新模型: %s\n\n', model_name);

    %% Add MATLAB Function Block
    fprintf('▶ 添加 MATLAB Function block...\n');

    mf_block = [model_name '/Type3_Controller'];
    add_block('simulink/User-Defined Functions/MATLAB Function', mf_block);
    set_param(mf_block, ...
        'Position', [200, 100, 350, 200], ...
        'BackgroundColor', 'lightBlue');

    fprintf('  ✓ MATLAB Function block\n');

    %% Add Input Ports
    fprintf('▶ 添加輸入端口...\n');

    % Input 1: Vd (參考訊號)
    add_block('simulink/Sources/In1', [model_name '/Vd']);
    set_param([model_name '/Vd'], ...
        'Port', '1', ...
        'Position', [50, 95, 80, 115], ...
        'BackgroundColor', 'green');

    % Input 2: Vm (測量輸出)
    add_block('simulink/Sources/In1', [model_name '/Vm']);
    set_param([model_name '/Vm'], ...
        'Port', '2', ...
        'Position', [50, 155, 80, 175], ...
        'BackgroundColor', 'green');

    fprintf('  ✓ Vd (參考訊號)\n');
    fprintf('  ✓ Vm (測量輸出)\n');

    %% Add Output Ports
    fprintf('▶ 添加輸出端口...\n');

    % Output 1: u (控制訊號)
    add_block('simulink/Sinks/Out1', [model_name '/u']);
    set_param([model_name '/u'], ...
        'Port', '1', ...
        'Position', [450, 115, 480, 135], ...
        'BackgroundColor', 'orange');

    % Output 2: e (追蹤誤差)
    add_block('simulink/Sinks/Out1', [model_name '/e']);
    set_param([model_name '/e'], ...
        'Port', '2', ...
        'Position', [450, 165, 480, 185], ...
        'BackgroundColor', 'orange');

    fprintf('  ✓ u (控制訊號)\n');
    fprintf('  ✓ e (追蹤誤差)\n');

    %% Connect Signals
    fprintf('▶ 連接信號...\n');

    % Connect inputs
    add_line(model_name, 'Vd/1', 'Type3_Controller/1', 'autorouting', 'on');
    add_line(model_name, 'Vm/1', 'Type3_Controller/2', 'autorouting', 'on');

    % Connect outputs
    add_line(model_name, 'Type3_Controller/1', 'u/1', 'autorouting', 'on');
    add_line(model_name, 'Type3_Controller/2', 'e/1', 'autorouting', 'on');

    fprintf('  ✓ 所有信號連接完成\n');

    %% Add Annotation
    fprintf('▶ 添加註解...\n');

    annotation_text = sprintf(['Type 3 Flux Controller (MATLAB Function Implementation)\n' ...
                               'Based on PDF Page 3 - Simplest Disturbance Model\n\n' ...
                               'Control Law: u[k] = B^{-1}{v_{ff}[k] + δv_{fb}[k] - ŵ_T[k]}\n' ...
                               'Tracking Error: δv[k] = v_d[k-1] - v_m[k]\n\n' ...
                               'Fixed Parameters: a1, a2, B_inv (embedded)\n' ...
                               'Tunable Parameters: lambda_c, lambda_e (from workspace)\n\n' ...
                               'Sample Time: 1e-5 s (100 kHz)']);

    add_block('built-in/Note', [model_name '/Info'], ...
              'Position', [50, 250], ...
              'Text', annotation_text, ...
              'FontSize', '9', ...
              'BackgroundColor', 'yellow');

    fprintf('  ✓ 註解\n');

    %% Configure MATLAB Function Content
    fprintf('\n▶ 設定 MATLAB Function 內容...\n');

    % Get MATLAB Function block handle
    mf_handle = find_system(model_name, 'BlockType', 'SubSystem', ...
                           'Name', 'Type3_Controller');

    if ~isempty(mf_handle)
        % Set sample time
        set_param(mf_handle{1}, 'SampleTime', '1e-5');
        fprintf('  ✓ 設定採樣時間: 1e-5 s\n');
    end

    %% Save Model
    fprintf('\n▶ 儲存模型...\n');
    save_system(model_name);

    %% Generate MATLAB Function Code File
    fprintf('\n▶ 生成 MATLAB Function 代碼檔案...\n');

    % Create the MATLAB Function code as a separate file for reference
    mf_code_file = 'type3_controller_function.m';
    if ~exist(mf_code_file, 'file')
        create_matlab_function_code();
        fprintf('  ✓ 已生成 %s\n', mf_code_file);
    else
        fprintf('  ℹ %s 已存在\n', mf_code_file);
    end

    %% Summary
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    模型建立完成！                          ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('模型檔案: %s.slx\n', model_name);
    fprintf('MATLAB Function 代碼: type3_controller_function.m\n');
    fprintf('\n');
    fprintf('下一步:\n');
    fprintf('  1. 雙擊 MATLAB Function block\n');
    fprintf('  2. 將 type3_controller_function.m 的內容複製進去\n');
    fprintf('  3. 點擊 "Edit Data" 設定端口大小:\n');
    fprintf('     - vd, vm: Size = 6\n');
    fprintf('     - u, e: Size = 6\n');
    fprintf('  4. 儲存並關閉編輯器\n');
    fprintf('  5. 執行 integrate_controller_to_framework() 進行整合\n');
    fprintf('\n');
end

%% Helper function to create MATLAB Function code
function create_matlab_function_code()
    % This creates a separate .m file with the MATLAB Function content
    % for easy copying into the Simulink MATLAB Function block

    code = {
        'function [u, e] = fcn(vd, vm)'
        '    % Type 3 Flux Controller - Based on PDF Page 3'
        '    % Simplest disturbance model: wT[k+1] = wT[k]'
        '    '
        '    % Get tunable parameters from workspace'
        '    lambda_c = evalin(''base'', ''lambda_c'');'
        '    lambda_e = evalin(''base'', ''lambda_e'');'
        '    '
        '    % Fixed parameters (embedded)'
        '    a1 = 1.595052025060797;'
        '    a2 = -0.599079946700523;'
        '    '
        '    % B inverse matrix (6×6)'
        '    B_inv = ['
        '        1254.431611705956, 365.9220943459926, 362.7155917884968, 509.3482978358023, 510.7001779284304, 478.0582926900250;'
        '        354.6971171665686, 1162.405056456143, 387.9439456363920, 669.9392357083276, 692.4786011832921, 448.5820022028297;'
        '        427.5001765633072, 453.9421687049577, 1258.888469891571, 439.2720672764521, 487.9780723937001, 520.7798602912907;'
        '        442.5225059058810, 654.6172791671690, 353.7782454546361, 1460.679099061605, 800.4859896304748, 448.7782507759195;'
        '        414.1758700238313, 572.5106763685067, 337.4250003002655, 687.4793677108798, 1274.435404241492, 374.7160216413520;'
        '        412.2201604485579, 400.9218769846693, 368.4630812134598, 474.4034014903570, 407.3700335734076, 1371.560285470157'
        '    ];'
        '    '
        '    % Persistent variables (state memory)'
        '    persistent vd_k1 vd_k2 s1_hat s2_hat wT_hat initialized'
        '    '
        '    % Initialize persistent variables'
        '    if isempty(initialized)'
        '        initialized = true;'
        '        vd_k1 = zeros(6,1);   % vd[k-1]'
        '        vd_k2 = zeros(6,1);   % vd[k-2]'
        '        s1_hat = zeros(6,1);  % ŝ1[k] = δv̂[k]'
        '        s2_hat = zeros(6,1);  % ŝ2[k] = δv̂[k-1]'
        '        wT_hat = zeros(6,1);  % ŵT[k]'
        '    end'
        '    '
        '    % === Control Algorithm ==='
        '    '
        '    % 1. Tracking error: δv[k] = vd[k-1] - vm[k]'
        '    delta_v = vd_k1 - vm;'
        '    e = delta_v;  % Output error signal'
        '    '
        '    % 2. Innovation: e_s1[k] = δv[k] - ŝ1[k]'
        '    e_s1 = delta_v - s1_hat;'
        '    '
        '    % 3. Feedforward: vff[k] = vd[k] - a1·vd[k-1] - a2·vd[k-2]'
        '    vff = vd - a1 * vd_k1 - a2 * vd_k2;'
        '    '
        '    % 4. Feedback: δvfb[k] = (a1-λc)·ŝ1[k] + a2·ŝ2[k]'
        '    delta_vfb = (a1 - lambda_c) * s1_hat + a2 * s2_hat;'
        '    '
        '    % 5. Control law: u[k] = B^(-1){vff + δvfb - ŵT}'
        '    u = B_inv * (vff + delta_vfb - wT_hat);'
        '    '
        '    % 6. Estimator gains (from PDF page 3)'
        '    l_1 = 1 + a1 - 3*lambda_e;'
        '    l_2 = 1 + lambda_e^3/a2;'
        '    l_3 = -(1 - lambda_e)^3;'
        '    '
        '    % 7. State update (for next time step)'
        '    s1_hat_next = lambda_c * s1_hat + l_1 * e_s1;'
        '    s2_hat_next = s1_hat + l_2 * e_s1;'
        '    wT_hat_next = wT_hat + l_3 * e_s1;'
        '    '
        '    % 8. Update history'
        '    vd_k2 = vd_k1;'
        '    vd_k1 = vd;'
        '    s1_hat = s1_hat_next;'
        '    s2_hat = s2_hat_next;'
        '    wT_hat = wT_hat_next;'
        'end'
    };

    % Write to file
    fid = fopen('type3_controller_function.m', 'w');
    for i = 1:length(code)
        fprintf(fid, '%s\n', code{i});
    end
    fclose(fid);
end