function [u, e, w1_hat, delta_v_hat] = r_controller_function_general(vd, vm, params)
    % R Controller with Pre-calculated Parameters
    %
    % Implements R Controller using pre-calculated parameters from
    % r_controller_calc_params(). This function contains ONLY the
    % difference equations for real-time execution.
    %
    % Inputs:
    %   vd     - Desired voltage [6×1] (may be preview vd[k+d])
    %   vm     - Measured voltage [6×1]
    %   params - Controller parameters (structure from r_controller_calc_params)
    %
    % Outputs:
    %   u      - Control input [6×1]
    %   e      - Tracking error [6×1] (δv = vf - vm)
    %   w1_hat - Disturbance estimate [6×1]
    %   delta_v_hat - Estimated tracking error [6×1] (δv̂)
    %
    % Variable naming convention:
    %   - Addition: A (e.g., one_A_beta = 1 + beta)
    %   - Subtraction: S (e.g., one_S_bc = 1 - bc)
    %   - Multiplication: M (e.g., b_M_lambda_c = b * lambda_c)
    %   - Negative: neg_ (e.g., neg_beta = -beta)

    % ====================================================================
    % PERSISTENT STATE VARIABLES
    % ====================================================================
    persistent vd_k1 vd_k2           % vd[k-1], vd[k-2] - Input history
    persistent vf_k1 vf_k2           % vf[k-1], vf[k-2] - Filtered vd history
    persistent delta_v_k1            % δv[k-1] - Tracking error history
    persistent delta_v_hat_k1        % δv̂[k-1] - Estimated error history
    persistent w1_hat_k1 w2_hat_k1   % ŵ1[k-1], ŵ2[k-1] - Disturbance estimates
    persistent delta_vc_k1 delta_vc_k2  % δvc[k-1], δvc[k-2] - Compensated error history
    persistent uc_k1 uc_k2           % uc[k-1], uc[k-2] - Control output history
    persistent initialized

    % ====================================================================
    % INITIALIZATION
    % ====================================================================
    if isempty(initialized)
        initialized = true;
        vd_k1 = zeros(6, 1);
        vd_k2 = zeros(6, 1);
        vf_k1 = zeros(6, 1);
        vf_k2 = zeros(6, 1);
        delta_v_k1 = zeros(6, 1);
        delta_v_hat_k1 = zeros(6, 1);
        w1_hat_k1 = zeros(6, 1);
        w2_hat_k1 = zeros(6, 1);
        delta_vc_k1 = zeros(6, 1);
        delta_vc_k2 = zeros(6, 1);
        uc_k1 = zeros(6, 1);
        uc_k2 = zeros(6, 1);
    end

    % ====================================================================
    % FEEDFORWARD FILTER (vf calculation)
    % vf[k] = alpha_vf * {c0·vd[k] + c1·vd[k-1] + c2·vd[k-2]}
    % ====================================================================
    vf_k = params.alpha_vf * (params.c0_b * vd + ...
                               params.c1_one_S_b_M_lambda_c * vd_k1 + ...
                               params.c2_neg_lambda_c * vd_k2);

    % δvf[k] = vf[k] - (1-bc)·vf[k-1] - bc·vf[k-2]
    delta_vf = vf_k - params.one_S_bc * vf_k1 - params.bc * vf_k2;

    % δv[k] = vf[k] - vm[k]
    delta_v = vf_k - vm;

    % ====================================================================
    % ESTIMATOR (disturbance observer)
    % ====================================================================
    error_term = delta_v_k1 - delta_v_hat_k1;

    % δv̂[k] = λc·δv̂[k-1] + δvf[k] + L1·{δv[k-1] - δv̂[k-1]}
    delta_v_hat = params.lambda_c * delta_v_hat_k1 + delta_vf + params.L1 * error_term;

    % ŵ1[k] = (1+β)·ŵ1[k-1] - β·ŵ2[k-1] + L2·{δv[k-1] - δv̂[k-1]}
    w1_hat = params.one_A_beta * w1_hat_k1 + params.neg_beta * w2_hat_k1 + params.L2 * error_term;

    % ŵ2[k] = ŵ1[k-1] + L3·{δv[k-1] - δv̂[k-1]}
    w2_hat = w1_hat_k1 + params.L3 * error_term;

    % ====================================================================
    % CONTROL LAW
    % ====================================================================
    % δvc[k] = δv[k] - ŵ1[k]
    delta_vc = delta_v - w1_hat;

    % uc[k] = (1-bc)·uc[k-1] + bc·uc[k-2] + ku·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
    uc = params.one_S_bc * uc_k1 + params.bc * uc_k2 + ...
         params.ku * (delta_vc - params.a1 * delta_vc_k1 - params.a2 * delta_vc_k2);

    % u[k] = B^-1 · uc[k]
    u = params.B_inv * uc;

    % e[k] = δv[k]
    e = delta_v;

    % ====================================================================
    % STATE UPDATES
    % ====================================================================
    vd_k2 = vd_k1;
    vd_k1 = vd;
    vf_k2 = vf_k1;
    vf_k1 = vf_k;
    delta_v_k1 = delta_v;
    delta_v_hat_k1 = delta_v_hat;
    w1_hat_k1 = w1_hat;
    w2_hat_k1 = w2_hat;
    delta_vc_k2 = delta_vc_k1;
    delta_vc_k1 = delta_vc;
    uc_k2 = uc_k1;
    uc_k1 = uc;
end
