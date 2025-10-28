function [u, e, w1_hat, delta_v_hat] = r_controller_function_p2_d0(vd, vm, params)
    % R Controller with d=0 (no preview) - Parameterized Version
    % Based on Page 2 equations but adapted for d=0
    %
    % Implements R Controller using pre-calculated parameters.
    % This version uses the Page 2 estimator gains (l_1 to l_4)
    % but with d=0 (no preview buffer).
    %
    % Inputs:
    %   vd     - Desired voltage [6×1]
    %   vm     - Measured voltage [6×1]
    %   params - Controller parameters (structure from r_controller_calc_params_p2)
    %
    % Outputs:
    %   u      - Control input [6×1]
    %   e      - Tracking error [6×1] (δv = vf - vm)
    %   w1_hat - Disturbance estimate [6×1]
    %   delta_v_hat - Estimated tracking error [6×1] (δv̂)

    % ====================================================================
    % PERSISTENT STATE VARIABLES
    % ====================================================================
    persistent vf vf_k1              % vf[k], vf[k-1] - Filtered vd
    persistent delta_vf_k1            % δvf[k-1]
    persistent delta_v_k1             % δv[k-1]
    persistent delta_v_hat_k1        % δv̂[k-1]
    persistent w1_hat_k1              % ŵ1[k-1]
    persistent delta_w_hat_k1         % δŵ[k-1]
    persistent w2_hat_k1              % ŵ2[k-1]
    persistent uc_k1 uc_k2            % uc[k-1], uc[k-2]
    persistent delta_vc_k1 delta_vc_k2  % δvc[k-1], δvc[k-2]
    persistent initialized

    % ====================================================================
    % INITIALIZATION
    % ====================================================================
    if isempty(initialized)
        initialized = true;
        vf = zeros(6, 1);
        vf_k1 = zeros(6, 1);
        delta_vf_k1 = zeros(6, 1);
        delta_v_k1 = zeros(6, 1);
        delta_v_hat_k1 = zeros(6, 1);
        w1_hat_k1 = zeros(6, 1);
        delta_w_hat_k1 = zeros(6, 1);
        w2_hat_k1 = zeros(6, 1);
        uc_k1 = zeros(6, 1);
        uc_k2 = zeros(6, 1);
        delta_vc_k1 = zeros(6, 1);
        delta_vc_k2 = zeros(6, 1);
    end

    % ====================================================================
    % FEEDFORWARD FILTER (d=0 version)
    % ====================================================================
    % For d=0, we need proper feedforward filter with kc
    % vf[k+1] = vd[k] (but scaled appropriately)
    vf_next = vd;

    % δvf[k] = vf[k+1] - (1-bc)·vf[k] - bc·vf[k-1]
    delta_vf = vf_next - params.one_S_bc * vf - params.bc * vf_k1;

    % δv[k] = vf[k] - vm[k]
    delta_v = vf - vm;

    % ====================================================================
    % ESTIMATOR (using Page 2 gains l_1, l_2, l_3, l_4)
    % ====================================================================
    error_term = delta_v_k1 - delta_v_hat_k1;

    % δv̂[k] = λc·δv̂[k-1] + δvf[k-1] + ℓ1·{δv[k-1] - δv̂[k-1]}
    delta_v_hat = params.lambda_c * delta_v_hat_k1 + delta_vf_k1 + params.l_1 * error_term;

    % ŵ1[k] = ŵ1[k-1] + δŵ[k-1] + ℓ2·{δv[k-1] - δv̂[k-1]}
    w1_hat = w1_hat_k1 + delta_w_hat_k1 + params.l_2 * error_term;

    % δŵ[k] = δŵ[k-1] + ℓ3·{δv[k-1] - δv̂[k-1]}
    delta_w_hat = delta_w_hat_k1 + params.l_3 * error_term;

    % ŵ2[k] = ŵ1[k-1] + ℓ4·{δv[k-1] - δv̂[k-1]}
    w2_hat = w1_hat_k1 + params.l_4 * error_term;

    % ====================================================================
    % CONTROL LAW
    % ====================================================================
    % δvc[k] = δv[k] - ŵ1[k]
    delta_vc = delta_v - w1_hat;

    % uc[k] = (1-bc)·uc[k-1] - bc·uc[k-2] + ku·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
    % Note: The second term is negative bc (not positive as in general version)
    uc = params.one_S_bc * uc_k1 - params.bc * uc_k2 + ...
         params.ku * (delta_vc - params.a1 * delta_vc_k1 - params.a2 * delta_vc_k2);

    % u[k] = B^-1 · uc[k]
    u = params.B_inv * uc;

    % e[k] = δv[k]
    e = delta_v;

    % ====================================================================
    % STATE UPDATES
    % ====================================================================
    vf_k1 = vf;            % vf[k-1] ← vf[k]
    vf = vf_next;          % vf[k] ← vf[k+1]

    delta_vf_k1 = delta_vf;       % δvf[k-1] ← δvf[k]
    delta_v_k1 = delta_v;         % δv[k-1] ← δv[k]
    delta_v_hat_k1 = delta_v_hat; % δv̂[k-1] ← δv̂[k]
    w1_hat_k1 = w1_hat;           % ŵ1[k-1] ← ŵ1[k]
    delta_w_hat_k1 = delta_w_hat; % δŵ[k-1] ← δŵ[k]
    w2_hat_k1 = w2_hat;           % ŵ2[k-1] ← ŵ2[k]

    uc_k2 = uc_k1;                % uc[k-2] ← uc[k-1]
    uc_k1 = uc;                   % uc[k-1] ← uc[k]
    delta_vc_k2 = delta_vc_k1;    % δvc[k-2] ← δvc[k-1]
    delta_vc_k1 = delta_vc;       % δvc[k-1] ← δvc[k]
end