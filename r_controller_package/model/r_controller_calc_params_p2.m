function params = r_controller_calc_params_p2_fixed(fB_c, fB_e)
    % R_CONTROLLER_CALC_PARAMS_P2_FIXED - Calculate R Controller P2D0 Parameters
    % 修正版本：欄位順序與 Bus 定義完全一致
    %
    % This function pre-calculates all parameters needed for the R Controller
    % Page 2 d=0 (no preview) implementation.
    %
    % Inputs:
    %   fB_c - Controller bandwidth [Hz]
    %   fB_e - Estimator bandwidth [Hz]
    %
    % Outputs:
    %   params - Simulink.Parameter with all controller parameters
    %
    % Note: Field order MUST match ParamsBus element order exactly!

    % ========================================
    % SYSTEM PARAMETERS
    % ========================================
    params = struct();  % Initialize empty struct

    % Fields 1-2: Plant parameters (MUST BE FIRST)
    params.k_o = 5.6695e-4;              % Plant gain from H(z^-1)
    params.b = 0.9782;                   % Zero coefficient from H(z^-1)

    % Fields 3-4: Feedforward filter coefficients
    params.a1 = params.b;                % a1 = b (coefficient from H(z^-1))
    params.a2 = 0;                       % a2 = 0 (for first-order system)

    % Field 5: Sampling time
    params.T = 5e-6;                     % Sampling period [s]

    % Field 6: System matrix inverse
    B = [0.1667   0.0055  -0.0177  -0.0145  -0.0009  -0.0117;
        -0.0052   0.1701  -0.0183  -0.0072  -0.0011  -0.0002;
        -0.0413  -0.0760   0.1893  -0.0343  -0.0193  -0.0104;
        -0.0413  -0.0760  -0.0234   0.1720   0.0141  -0.0045;
        -0.0413  -0.0760  -0.0234  -0.0720   0.2572  -0.0045;
        -0.0244  -0.0330  -0.0257  -0.0245  -0.0030   0.1845];
    params.B_inv = inv(B);

    % Fields 7-8: Eigenvalues
    params.lambda_c = exp(-fB_c * 2 * pi * params.T);
    params.lambda_e = exp(-fB_e * 2 * pi * params.T);

    % Field 9: beta (DUMMY for P2D0 - not used)
    params.beta = 0;  % P2D0 doesn't use beta

    % Fields 10-12: Controller gains
    params.kc = (1 - params.lambda_c) / (1 + params.b);
    params.bc = params.b * params.kc;
    params.ku = params.kc / params.k_o;

    % Fields 13-17: General version specific (DUMMY for P2D0)
    params.alpha_vf = 0;              % DUMMY - not used in P2D0
    params.c0_b = 0;                  % DUMMY - not used in P2D0
    params.c1_one_S_b_M_lambda_c = 0; % DUMMY - not used in P2D0
    params.c2_neg_lambda_c = 0;       % DUMMY - not used in P2D0
    params.one_S_bc = 1 - params.bc;  % Used in P2D0

    % Fields 18-20: General version estimator gains (DUMMY for P2D0)
    params.L1 = 0;                    % DUMMY - P2D0 uses l_1 instead
    params.L2 = 0;                    % DUMMY - P2D0 uses l_2 instead
    params.L3 = 0;                    % DUMMY - P2D0 uses l_3 instead

    % Fields 21-22: General version beta related (DUMMY for P2D0)
    params.one_A_beta = 0;            % DUMMY - not used in P2D0
    params.neg_beta = 0;              % DUMMY - not used in P2D0

    % Fields 23-26: P2D0 specific estimator gains
    % ℓ1
    params.l_1 = 2 + params.lambda_c - 4*params.lambda_e;

    % ℓ2
    params.l_2 = (params.lambda_e - 1)^3 * (4*params.b + params.lambda_e + 3) / ...
                 ((params.b + 1)^2 * params.kc);

    % ℓ3
    params.l_3 = -(params.lambda_e - 1)^4 / ...
                  ((params.b + 1) * params.kc);

    % ℓ4
    params.l_4 = -(params.lambda_e^4 + 4*params.b*params.lambda_e^3 + ...
                  6*params.b^2*params.lambda_e^2 - 4*params.b*(2*params.b + 1)*params.lambda_e + ...
                  3*params.b^2 + 2*params.b) / ...
                 ((params.b + 1)^2 * params.b * params.kc);

    % ========================================
    % CREATE/UPDATE PARAMSBUS DEFINITION
    % ========================================
    % 創建與 General 版本相同的 Bus 定義
    ParamsBus = Simulink.Bus;
    ParamsBus.Description = 'R Controller Parameters Structure (Unified)';

    % Define all bus elements (MUST match field order above!)
    elems(1) = Simulink.BusElement;
    elems(1).Name = 'k_o';
    elems(1).DataType = 'double';

    elems(2) = Simulink.BusElement;
    elems(2).Name = 'b';
    elems(2).DataType = 'double';

    elems(3) = Simulink.BusElement;
    elems(3).Name = 'a1';
    elems(3).DataType = 'double';

    elems(4) = Simulink.BusElement;
    elems(4).Name = 'a2';
    elems(4).DataType = 'double';

    elems(5) = Simulink.BusElement;
    elems(5).Name = 'T';
    elems(5).DataType = 'double';

    elems(6) = Simulink.BusElement;
    elems(6).Name = 'B_inv';
    elems(6).Dimensions = [6 6];
    elems(6).DataType = 'double';

    elems(7) = Simulink.BusElement;
    elems(7).Name = 'lambda_c';
    elems(7).DataType = 'double';

    elems(8) = Simulink.BusElement;
    elems(8).Name = 'lambda_e';
    elems(8).DataType = 'double';

    elems(9) = Simulink.BusElement;
    elems(9).Name = 'beta';
    elems(9).DataType = 'double';

    elems(10) = Simulink.BusElement;
    elems(10).Name = 'kc';
    elems(10).DataType = 'double';

    elems(11) = Simulink.BusElement;
    elems(11).Name = 'bc';
    elems(11).DataType = 'double';

    elems(12) = Simulink.BusElement;
    elems(12).Name = 'ku';
    elems(12).DataType = 'double';

    elems(13) = Simulink.BusElement;
    elems(13).Name = 'alpha_vf';
    elems(13).DataType = 'double';

    elems(14) = Simulink.BusElement;
    elems(14).Name = 'c0_b';
    elems(14).DataType = 'double';

    elems(15) = Simulink.BusElement;
    elems(15).Name = 'c1_one_S_b_M_lambda_c';
    elems(15).DataType = 'double';

    elems(16) = Simulink.BusElement;
    elems(16).Name = 'c2_neg_lambda_c';
    elems(16).DataType = 'double';

    elems(17) = Simulink.BusElement;
    elems(17).Name = 'one_S_bc';
    elems(17).DataType = 'double';

    elems(18) = Simulink.BusElement;
    elems(18).Name = 'L1';
    elems(18).DataType = 'double';

    elems(19) = Simulink.BusElement;
    elems(19).Name = 'L2';
    elems(19).DataType = 'double';

    elems(20) = Simulink.BusElement;
    elems(20).Name = 'L3';
    elems(20).DataType = 'double';

    elems(21) = Simulink.BusElement;
    elems(21).Name = 'one_A_beta';
    elems(21).DataType = 'double';

    elems(22) = Simulink.BusElement;
    elems(22).Name = 'neg_beta';
    elems(22).DataType = 'double';

    elems(23) = Simulink.BusElement;
    elems(23).Name = 'l_1';
    elems(23).DataType = 'double';

    elems(24) = Simulink.BusElement;
    elems(24).Name = 'l_2';
    elems(24).DataType = 'double';

    elems(25) = Simulink.BusElement;
    elems(25).Name = 'l_3';
    elems(25).DataType = 'double';

    elems(26) = Simulink.BusElement;
    elems(26).Name = 'l_4';
    elems(26).DataType = 'double';

    % Assign elements to bus
    ParamsBus.Elements = elems;

    % Save ParamsBus to base workspace
    assignin('base', 'ParamsBus', ParamsBus);

    % ========================================
    % WRAP AS SIMULINK.PARAMETER WITH BUS TYPE
    % ========================================
    params_data = params;  % Keep the raw data
    params = Simulink.Parameter(params_data);
    params.DataType = 'Bus: ParamsBus';
    params.Description = 'R Controller P2D0 Parameters';

    % ========================================
    % DISPLAY PARAMETERS (optional)
    % ========================================
    if nargout == 0
        fprintf('\n=== R Controller Parameters (Page 2 d=0) ===\n');
        fprintf('Bandwidth Settings:\n');
        fprintf('  fB_c = %.1f Hz\n', fB_c);
        fprintf('  fB_e = %.1f Hz\n', fB_e);
        fprintf('\nEstimator Gains:\n');
        fprintf('  l_1 = %.6f\n', params_data.l_1);
        fprintf('  l_2 = %.6f\n', params_data.l_2);
        fprintf('  l_3 = %.6f\n', params_data.l_3);
        fprintf('  l_4 = %.6f\n', params_data.l_4);
        fprintf('=====================================\n\n');
    end
end