% create_flux_controller_type3.m
% 自動建立 Type 3 磁通控制器 Simulink 模型
%
% Type 3: 一階擾動模型（最簡單版本）
%   擾動模型: wT[k+1] = wT[k]
%   估測器增益: l1, l2, l3
%
% Controller Architecture:
%   Inputs:  Vd (6×1) - 參考訊號
%            Vm (6×1) - 測量輸出
%   Outputs: u  (6×1) - 控制訊號
%            e  (6×1) - 誤差訊號 δv[k] (監控用)
%
% Control Law:
%   u[k] = B⁻¹{vff[k] + δvfb[k] - ŵT[k]}
%
% Feedforward:
%   vff[k] = vd[k] - a1·vd[k-1] - a2·vd[k-2]
%
% Feedback:
%   δvfb[k] = (a1 - λc)·δv̂[k] + a2·δv̂[k-1]
%
% Estimator:
%   innovation[k] = δv[k] - ŝ₁[k]
%   ŝ₁[k+1] = λc·ŝ₁[k] + l1·innovation[k]
%   ŝ₂[k+1] = ŝ₁[k] + l2·innovation[k]
%   ŵT[k+1] = ŵT[k] + l3·innovation[k]
%
% Error:
%   δv[k] = vd[k-1] - vm[k]
%
% Parameters (from workspace):
%   a1, a2           - 系統參數
%   B_inv            - 控制矩陣的逆 (6×6)
%   lambda_c         - 控制特徵值
%   l1, l2, l3       - 估測器增益
%   fb_coeff_1       - 反饋係數 (a1 - λc)
%   fb_coeff_2       - 反饋係數 a2
%
% Usage:
%   create_flux_controller_type3()
%
% Author: Claude Code
% Date: 2025-10-11
% Updated: 2025-10-12 - 記錄實際調整後的模塊位置

function create_flux_controller_type3()
    %% Configuration
    model_name = 'Flux_Controller_Type3_24a';

    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║        Creating Flux Controller Type 3 Model              ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('Model: %s.slx\n', model_name);
    fprintf('Type: 一階擾動模型（最簡單版本）\n\n');

    %% Close and delete existing model
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
        fprintf('✓ 已關閉現有模型\n');
    end

    if exist([model_name '.slx'], 'file')
        delete([model_name '.slx']);
        fprintf('✓ 已刪除舊模型文件\n');
    end

    %% Create new model
    new_system(model_name);
    open_system(model_name);
    fprintf('✓ 建立新模型\n\n');

    %% Layout parameters - 基於實際調整後的位置
    % 這些位置已經過手動調整和驗證
    fprintf('✓ 使用實際調整後的佈局參數\n');

    pos = struct();

    % 輸入端口
    pos.Vd = [310, 190, 340, 210];
    pos.Vm = [310, 235, 340, 255];

    % 誤差計算區域
    pos.Vd_Delay = [470, 185, 500, 215];
    pos.Error_Calc = [385, 222, 415, 253];

    % 前饋路徑
    pos.Vd_Delay2 = [565, 185, 595, 215];
    pos.Gain_a1 = [820, 245, 850, 275];
    pos.Gain_a2 = [765, 280, 795, 310];
    pos.FF_Sum = [915, 245, 945, 275];

    % 估測器區域
    pos.Innovation = [470, 322, 500, 353];
    pos.Gain_l1 = [565, 325, 595, 355];
    pos.Gain_l2 = [565, 440, 595, 470];
    pos.Gain_l3 = [565, 525, 595, 555];
    pos.Gain_lambda_c = [565, 375, 595, 405];

    % 估測器狀態
    pos.S1_Sum = [720, 332, 750, 363];
    pos.S1_Delay = [780, 335, 810, 365];
    pos.S2_Sum = [720, 432, 750, 463];
    pos.S2_Delay = [780, 435, 810, 465];
    pos.WT_Sum = [720, 517, 750, 548];
    pos.WT_Delay = [780, 520, 810, 550];

    % 反饋路徑
    pos.FB_Gain1 = [685, 570, 715, 600];
    pos.FB_Gain2 = [855, 610, 885, 640];
    pos.FB_Sum = [915, 577, 945, 608];

    % 控制律
    pos.Control_Sum = [1000, 405, 1030, 435];
    pos.B_inv_Gain = [1060, 390, 1120, 450];

    % 輸出端口
    pos.u = [1150, 410, 1180, 430];
    pos.e = [1150, 230, 1180, 250];

    %% Section 1: Input ports
    fprintf('▶ 建立輸入端口...\n');

    add_block('simulink/Sources/In1', [model_name '/Vd']);
    set_param([model_name '/Vd'], 'Port', '1', 'Position', pos.Vd);

    add_block('simulink/Sources/In1', [model_name '/Vm']);
    set_param([model_name '/Vm'], 'Port', '2', 'Position', pos.Vm);

    fprintf('  ✓ Vd, Vm\n');

    %% Section 2: Error calculation δv[k] = vd[k-1] - vm[k]
    fprintf('▶ 建立誤差計算...\n');

    % Vd 延遲一步
    add_block('simulink/Discrete/Unit Delay', [model_name '/Vd_Delay']);
    set_param([model_name '/Vd_Delay'], ...
        'SampleTime', 'Ts', ...
        'Position', pos.Vd_Delay);

    % 誤差計算 δv = vd[k-1] - vm[k]
    add_block('simulink/Math Operations/Sum', [model_name '/Error_Calc']);
    set_param([model_name '/Error_Calc'], ...
        'Inputs', '+-', ...
        'IconShape', 'rectangular', ...
        'Position', pos.Error_Calc);

    % 連接
    add_line(model_name, 'Vd/1', 'Vd_Delay/1', 'autorouting', 'on');
    add_line(model_name, 'Vd_Delay/1', 'Error_Calc/1', 'autorouting', 'on');
    add_line(model_name, 'Vm/1', 'Error_Calc/2', 'autorouting', 'on');

    fprintf('  ✓ δv[k] = vd[k-1] - vm[k]\n');

    %% Section 3: Feedforward term vff[k] = vd[k] - a1·vd[k-1] - a2·vd[k-2]
    fprintf('▶ 建立前饋項...\n');

    % Vd[k-1] 再延遲一步得到 Vd[k-2]
    add_block('simulink/Discrete/Unit Delay', [model_name '/Vd_Delay2']);
    set_param([model_name '/Vd_Delay2'], ...
        'SampleTime', 'Ts', ...
        'Position', pos.Vd_Delay2);

    % Gain: -a1
    add_block('simulink/Math Operations/Gain', [model_name '/Gain_a1']);
    set_param([model_name '/Gain_a1'], ...
        'Gain', '-a1', ...
        'Position', pos.Gain_a1);

    % Gain: -a2
    add_block('simulink/Math Operations/Gain', [model_name '/Gain_a2']);
    set_param([model_name '/Gain_a2'], ...
        'Gain', '-a2', ...
        'Position', pos.Gain_a2);

    % Sum: vd[k] + (-a1)·vd[k-1] + (-a2)·vd[k-2]
    add_block('simulink/Math Operations/Sum', [model_name '/FF_Sum']);
    set_param([model_name '/FF_Sum'], ...
        'Inputs', '+++', ...
        'IconShape', 'rectangular', ...
        'Position', pos.FF_Sum);

    % 連接
    add_line(model_name, 'Vd_Delay/1', 'Vd_Delay2/1', 'autorouting', 'on');
    add_line(model_name, 'Vd_Delay/1', 'Gain_a1/1', 'autorouting', 'on');
    add_line(model_name, 'Vd_Delay2/1', 'Gain_a2/1', 'autorouting', 'on');
    add_line(model_name, 'Vd/1', 'FF_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'Gain_a1/1', 'FF_Sum/2', 'autorouting', 'on');
    add_line(model_name, 'Gain_a2/1', 'FF_Sum/3', 'autorouting', 'on');

    fprintf('  ✓ vff[k] = vd[k] - a1·vd[k-1] - a2·vd[k-2]\n');

    %% Section 4: Estimator
    fprintf('▶ 建立估測器...\n');

    % Innovation: δv[k] - ŝ₁[k]
    add_block('simulink/Math Operations/Sum', [model_name '/Innovation']);
    set_param([model_name '/Innovation'], ...
        'Inputs', '+-', ...
        'IconShape', 'rectangular', ...
        'Position', pos.Innovation);

    % ŝ₁[k] 估測器
    % ŝ₁[k+1] = λc·ŝ₁[k] + l1·innovation[k]
    add_block('simulink/Math Operations/Gain', [model_name '/Gain_l1']);
    set_param([model_name '/Gain_l1'], ...
        'Gain', 'l1', ...
        'Position', pos.Gain_l1);

    add_block('simulink/Math Operations/Gain', [model_name '/Gain_lambda_c']);
    set_param([model_name '/Gain_lambda_c'], ...
        'Gain', 'lambda_c', ...
        'Position', pos.Gain_lambda_c);

    add_block('simulink/Math Operations/Sum', [model_name '/S1_Sum']);
    set_param([model_name '/S1_Sum'], ...
        'Inputs', '++', ...
        'IconShape', 'rectangular', ...
        'Position', pos.S1_Sum);

    add_block('simulink/Discrete/Unit Delay', [model_name '/S1_Delay']);
    set_param([model_name '/S1_Delay'], ...
        'SampleTime', 'Ts', ...
        'InitialCondition', 'zeros(6,1)', ...
        'Position', pos.S1_Delay);

    % ŝ₂[k] 估測器
    % ŝ₂[k+1] = ŝ₁[k] + l2·innovation[k]
    add_block('simulink/Math Operations/Gain', [model_name '/Gain_l2']);
    set_param([model_name '/Gain_l2'], ...
        'Gain', 'l2', ...
        'Position', pos.Gain_l2);

    add_block('simulink/Math Operations/Sum', [model_name '/S2_Sum']);
    set_param([model_name '/S2_Sum'], ...
        'Inputs', '++', ...
        'IconShape', 'rectangular', ...
        'Position', pos.S2_Sum);

    add_block('simulink/Discrete/Unit Delay', [model_name '/S2_Delay']);
    set_param([model_name '/S2_Delay'], ...
        'SampleTime', 'Ts', ...
        'InitialCondition', 'zeros(6,1)', ...
        'Position', pos.S2_Delay);

    % ŵT[k] 估測器
    % ŵT[k+1] = ŵT[k] + l3·innovation[k]
    add_block('simulink/Math Operations/Gain', [model_name '/Gain_l3']);
    set_param([model_name '/Gain_l3'], ...
        'Gain', 'l3', ...
        'Position', pos.Gain_l3);

    add_block('simulink/Math Operations/Sum', [model_name '/WT_Sum']);
    set_param([model_name '/WT_Sum'], ...
        'Inputs', '++', ...
        'IconShape', 'rectangular', ...
        'Position', pos.WT_Sum);

    add_block('simulink/Discrete/Unit Delay', [model_name '/WT_Delay']);
    set_param([model_name '/WT_Delay'], ...
        'SampleTime', 'Ts', ...
        'InitialCondition', 'zeros(6,1)', ...
        'Position', pos.WT_Delay);

    % 連接估測器
    add_line(model_name, 'Error_Calc/1', 'Innovation/1', 'autorouting', 'on');
    add_line(model_name, 'Innovation/1', 'Gain_l1/1', 'autorouting', 'on');
    add_line(model_name, 'Innovation/1', 'Gain_l2/1', 'autorouting', 'on');
    add_line(model_name, 'Innovation/1', 'Gain_l3/1', 'autorouting', 'on');

    % ŝ₁ 迴路
    add_line(model_name, 'Gain_l1/1', 'S1_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'S1_Delay/1', 'Gain_lambda_c/1', 'autorouting', 'on');
    add_line(model_name, 'Gain_lambda_c/1', 'S1_Sum/2', 'autorouting', 'on');
    add_line(model_name, 'S1_Sum/1', 'S1_Delay/1', 'autorouting', 'on');
    add_line(model_name, 'S1_Delay/1', 'Innovation/2', 'autorouting', 'on');

    % ŝ₂ 迴路
    add_line(model_name, 'S1_Delay/1', 'S2_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'Gain_l2/1', 'S2_Sum/2', 'autorouting', 'on');
    add_line(model_name, 'S2_Sum/1', 'S2_Delay/1', 'autorouting', 'on');

    % ŵT 迴路
    add_line(model_name, 'WT_Delay/1', 'WT_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'Gain_l3/1', 'WT_Sum/2', 'autorouting', 'on');
    add_line(model_name, 'WT_Sum/1', 'WT_Delay/1', 'autorouting', 'on');

    fprintf('  ✓ 估測器: ŝ₁[k], ŝ₂[k], ŵT[k]\n');

    %% Section 5: Feedback term δvfb[k] = (a1-λc)·ŝ₁[k] + a2·ŝ₂[k]
    fprintf('▶ 建立反饋項...\n');

    add_block('simulink/Math Operations/Gain', [model_name '/FB_Gain1']);
    set_param([model_name '/FB_Gain1'], ...
        'Gain', 'fb_coeff_1', ...
        'Position', pos.FB_Gain1);

    add_block('simulink/Math Operations/Gain', [model_name '/FB_Gain2']);
    set_param([model_name '/FB_Gain2'], ...
        'Gain', 'fb_coeff_2', ...
        'Position', pos.FB_Gain2);

    add_block('simulink/Math Operations/Sum', [model_name '/FB_Sum']);
    set_param([model_name '/FB_Sum'], ...
        'Inputs', '++', ...
        'IconShape', 'rectangular', ...
        'Position', pos.FB_Sum);

    % 連接
    add_line(model_name, 'S1_Delay/1', 'FB_Gain1/1', 'autorouting', 'on');
    add_line(model_name, 'S2_Delay/1', 'FB_Gain2/1', 'autorouting', 'on');
    add_line(model_name, 'FB_Gain1/1', 'FB_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'FB_Gain2/1', 'FB_Sum/2', 'autorouting', 'on');

    fprintf('  ✓ δvfb[k] = (a1-λc)·ŝ₁[k] + a2·ŝ₂[k]\n');

    %% Section 6: Control law u[k] = B⁻¹{vff + δvfb - ŵT}
    fprintf('▶ 建立控制律...\n');

    % Sum: vff + δvfb - ŵT
    add_block('simulink/Math Operations/Sum', [model_name '/Control_Sum']);
    set_param([model_name '/Control_Sum'], ...
        'Inputs', '++-', ...
        'IconShape', 'rectangular', ...
        'Position', pos.Control_Sum);

    % Gain: B⁻¹
    add_block('simulink/Math Operations/Gain', [model_name '/B_inv_Gain']);
    set_param([model_name '/B_inv_Gain'], ...
        'Gain', 'B_inv', ...
        'Multiplication', 'Matrix(K*u)', ...
        'Position', pos.B_inv_Gain);

    % 連接
    add_line(model_name, 'FF_Sum/1', 'Control_Sum/1', 'autorouting', 'on');
    add_line(model_name, 'FB_Sum/1', 'Control_Sum/2', 'autorouting', 'on');
    add_line(model_name, 'WT_Delay/1', 'Control_Sum/3', 'autorouting', 'on');
    add_line(model_name, 'Control_Sum/1', 'B_inv_Gain/1', 'autorouting', 'on');

    fprintf('  ✓ u[k] = B⁻¹{vff + δvfb - ŵT}\n');

    %% Section 7: Output ports
    fprintf('▶ 建立輸出端口...\n');

    % Output 1: u (control signal)
    add_block('simulink/Sinks/Out1', [model_name '/u']);
    set_param([model_name '/u'], 'Port', '1', 'Position', pos.u);

    % Output 2: e (error signal δv)
    add_block('simulink/Sinks/Out1', [model_name '/e']);
    set_param([model_name '/e'], 'Port', '2', 'Position', pos.e);

    % 連接
    add_line(model_name, 'B_inv_Gain/1', 'u/1', 'autorouting', 'on');
    add_line(model_name, 'Error_Calc/1', 'e/1', 'autorouting', 'on');

    fprintf('  ✓ u, e\n');

    %% Section 8: Annotations
    fprintf('▶ 添加註解...\n');

    annotation_text = sprintf(['Flux Controller Type 3 (一階擾動模型)\n' ...
                               'Created: 2025-10-11\n' ...
                               'Updated: 2025-10-12\n\n' ...
                               'INPUTS:\n' ...
                               '  Vd (6×1) - 參考訊號\n' ...
                               '  Vm (6×1) - 測量輸出\n\n' ...
                               'OUTPUTS:\n' ...
                               '  u (6×1) - 控制訊號\n' ...
                               '  e (6×1) - 誤差訊號 δv[k]\n\n' ...
                               'CONTROL LAW:\n' ...
                               '  u[k] = B⁻¹{vff[k] + δvfb[k] - ŵT[k]}\n\n' ...
                               'PARAMETERS (from workspace):\n' ...
                               '  a1, a2, B_inv, lambda_c, Ts\n' ...
                               '  l1, l2, l3 (estimator gains)\n' ...
                               '  fb_coeff_1, fb_coeff_2']);

    add_block('built-in/Note', [model_name '/Info'], ...
              'Position', [50, 50], ...
              'Text', annotation_text, ...
              'FontSize', '9');

    fprintf('  ✓ 註解\n');

    %% Save model
    fprintf('\n▶ 儲存模型...\n');
    save_system(model_name);

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                   模型建立完成！                           ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('模型檔案: %s.slx\n', model_name);
    fprintf('\n');
    fprintf('結構摘要:\n');
    fprintf('  • 輸入: Vd (6×1), Vm (6×1)\n');
    fprintf('  • 輸出: u (6×1), e (6×1)\n');
    fprintf('  • 估測器狀態: ŝ₁, ŝ₂, ŵT\n');
    fprintf('  • 擾動模型: 一階 (wT[k+1] = wT[k])\n');
    fprintf('\n');
    fprintf('下一步:\n');
    fprintf('  1. 執行 calculate_flux_controller_params.m 計算參數\n');
    fprintf('  2. 使用 example_flux_controller_type3.m 測試控制器\n');
    fprintf('  3. 整合到 Control_System_Framework.slx\n');
    fprintf('\n');
end
