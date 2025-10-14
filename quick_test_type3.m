% quick_test_type3.m
% 快速測試 Type 3 控制器整合
%
% Purpose:
%   快速執行 Type 3 控制器的創建、整合和基本測試
%
% Usage:
%   quick_test_type3
%
% Author: Claude Code
% Date: 2025-10-14

%% Clear workspace
clear; clc; close all;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('              Type 3 Controller Quick Test\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');

%% Step 1: Create Controller Model
fprintf('Step 1: 創建控制器模型\n');
fprintf('────────────────────────────────────────\n');

try
    create_type3_controller_matlab_func();
    fprintf('✓ 控制器模型創建成功\n\n');
catch ME
    fprintf('✗ 控制器模型創建失敗: %s\n', ME.message);
    error('無法繼續執行');
end

%% Step 2: Manual Step - Copy MATLAB Function Code
fprintf('Step 2: 設定 MATLAB Function\n');
fprintf('────────────────────────────────────────\n');
fprintf('請手動執行以下步驟:\n');
fprintf('  1. 開啟 Type3_Controller_MatlabFunc.slx\n');
fprintf('  2. 雙擊 MATLAB Function block\n');
fprintf('  3. 刪除預設代碼\n');
fprintf('  4. 複製 type3_controller_function.m 的內容\n');
fprintf('  5. 點擊 "Edit Data" (或按 Ctrl+Shift+E)\n');
fprintf('  6. 設定端口大小:\n');
fprintf('     - vd: Size = 6, Type = double\n');
fprintf('     - vm: Size = 6, Type = double\n');
fprintf('     - u: Size = 6, Type = double\n');
fprintf('     - e: Size = 6, Type = double\n');
fprintf('  7. 儲存並關閉編輯器\n');
fprintf('  8. 儲存模型\n');
fprintf('\n');

% Wait for user confirmation
input('完成上述步驟後，按 Enter 繼續...', 's');
fprintf('\n');

%% Step 3: Check if framework exists
fprintf('Step 3: 檢查 Framework\n');
fprintf('────────────────────────────────────────\n');

if ~exist('Control_System_Framework.slx', 'file')
    fprintf('Framework 不存在，正在生成...\n');

    % Check for one_curve_36_results.mat
    if ~exist('one_curve_36_results.mat', 'file')
        fprintf('需要先執行 Model_6_6_Continuous_Weighted.m 生成參數\n');
        fprintf('正在執行...\n');
        try
            Model_6_6_Continuous_Weighted;
            fprintf('✓ 參數生成成功\n');
        catch ME
            fprintf('✗ 參數生成失敗: %s\n', ME.message);
            error('無法繼續執行');
        end
    end

    % Generate framework
    try
        generate_simulink_framework();
        fprintf('✓ Framework 生成成功\n\n');
    catch ME
        fprintf('✗ Framework 生成失敗: %s\n', ME.message);
        error('無法繼續執行');
    end
else
    fprintf('✓ Framework 已存在\n\n');
end

%% Step 4: Integrate Controller to Framework
fprintf('Step 4: 整合控制器到 Framework\n');
fprintf('────────────────────────────────────────\n');

try
    integrate_controller_to_framework();
    fprintf('✓ 整合成功\n\n');
catch ME
    fprintf('✗ 整合失敗: %s\n', ME.message);
    error('無法繼續執行');
end

%% Step 5: Set Parameters
fprintf('Step 5: 設定參數\n');
fprintf('────────────────────────────────────────\n');

% System parameters
Ts = 1e-5;  % Sampling time (100 kHz)

% Control parameters
lambda_c = 0.5;  % Control eigenvalue
lambda_e = 0.3;  % Estimator eigenvalue

fprintf('  Ts = %.1e s (100 kHz)\n', Ts);
fprintf('  lambda_c = %.2f\n', lambda_c);
fprintf('  lambda_e = %.2f\n', lambda_e);
fprintf('✓ 參數設定完成\n\n');

%% Step 6: Run Simple Test
fprintf('Step 6: 執行簡單測試\n');
fprintf('────────────────────────────────────────\n');

model_name = 'Control_System_Integrated';
sim_time = 0.01;  % 10 ms for quick test

fprintf('執行模擬 (%.0f ms)...\n', sim_time*1000);

try
    % Set Vd as constant reference
    set_param([model_name '/Vd'], 'Value', '[1; 1; 1; 1; 1; 1]');

    % Run simulation
    sim_out = sim(model_name, ...
        'StopTime', num2str(sim_time), ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', num2str(Ts));

    fprintf('✓ 模擬完成\n\n');
catch ME
    fprintf('✗ 模擬失敗: %s\n', ME.message);
    error('無法完成測試');
end

%% Step 7: Basic Results Display
fprintf('Step 7: 基本結果顯示\n');
fprintf('────────────────────────────────────────\n');

% Get results from workspace
try
    t = sim_out.tout;

    % Get logged signals
    if exist('u', 'var')
        fprintf('  控制輸入 u: %.0f 個樣本\n', length(u));
    end

    if exist('Vm', 'var')
        fprintf('  測量輸出 Vm: %.0f 個樣本\n', length(Vm));
    end

    if exist('e', 'var')
        fprintf('  追蹤誤差 e: %.0f 個樣本\n', length(e));
    end

    % Basic plot
    figure('Name', 'Quick Test Results', 'Position', [100, 100, 1200, 800]);

    % Plot control input
    subplot(3,1,1);
    if exist('u', 'var')
        plot(t, u(:,1:min(6, size(u,2))));
        title('Control Input u');
        ylabel('u');
        grid on;
        legend('Ch1', 'Ch2', 'Ch3', 'Ch4', 'Ch5', 'Ch6', 'Location', 'best');
    end

    % Plot output
    subplot(3,1,2);
    if exist('Vm', 'var')
        plot(t, Vm(:,1:min(6, size(Vm,2))));
        hold on;
        plot(t, ones(length(t), 1), 'k--', 'LineWidth', 2);
        title('Measured Output Vm vs Reference');
        ylabel('Vm');
        grid on;
        legend('Ch1', 'Ch2', 'Ch3', 'Ch4', 'Ch5', 'Ch6', 'Ref', 'Location', 'best');
    end

    % Plot error
    subplot(3,1,3);
    if exist('e', 'var')
        plot(t, e(:,1:min(6, size(e,2))));
        title('Tracking Error e = Vd[k-1] - Vm[k]');
        ylabel('e');
        xlabel('Time (s)');
        grid on;
        legend('Ch1', 'Ch2', 'Ch3', 'Ch4', 'Ch5', 'Ch6', 'Location', 'best');
    end

    fprintf('✓ 結果顯示完成\n\n');

catch ME
    fprintf('⚠ 結果顯示時發生問題: %s\n', ME.message);
    fprintf('  可能需要檢查 To Workspace blocks 的設定\n\n');
end

%% Summary
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                     測試完成                                \n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf('\n');
fprintf('已完成:\n');
fprintf('  ✓ 控制器模型創建\n');
fprintf('  ✓ Framework 整合\n');
fprintf('  ✓ 參數設定\n');
fprintf('  ✓ 簡單模擬測試\n');
fprintf('\n');
fprintf('後續步驟:\n');
fprintf('  1. 調整 lambda_c 和 lambda_e 參數\n');
fprintf('  2. 測試不同的參考訊號（step, sine）\n');
fprintf('  3. 執行更長時間的模擬\n');
fprintf('  4. 分析系統性能\n');
fprintf('\n');
fprintf('相關檔案:\n');
fprintf('  • 控制器模型: Type3_Controller_MatlabFunc.slx\n');
fprintf('  • 整合模型: Control_System_Integrated.slx\n');
fprintf('  • MATLAB Function: type3_controller_function.m\n');
fprintf('\n');