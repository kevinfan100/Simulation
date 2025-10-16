function [u, e] = fcn(vd, vm)
    % Flux_Control_R_newmodel.pdf Page 1

    % ========== Parameters ==========
    % System model parameters 
    k_o = 5.6695e-4;              % k_o from H(z^-1)
    b = 0.9782;                   % b from H(z^-1)
    a1 = 1.934848;                % a1 
    a2 = -0.935970;               % a2 

    % Control parameters 
    lambda_c = 0.8179;  % λc - control eigenvalue
    lambda_e = 0.3659;  % λe - estimator eigenvalue
    beta = lambda_c^2;  % β

    kc = (1 - lambda_c) / (1 + b);
    bc = b * kc;
    ku = kc / k_o;

    % Estimator gains
    l_1 = lambda_c + (1 + beta) - 3*lambda_e;

    % l_2
    l_2 = (b*(lambda_e - 1)^3 - beta*(b + 1)*(beta^2 - 3*beta*lambda_e + beta + 3*lambda_e^2 - 3*lambda_e + 1)) / ...
          (kc * (b + 1) * (b + beta));

    % l_3
    l_3 = (-(b + beta)*(beta^2 - 3*beta*lambda_e + beta + 3*lambda_e^2 - 3*lambda_e + 1) - lambda_e^3) / ...
          (kc * (b + 1) * (b + beta));

    % B matrix (6×6) 
    B = [0.2365  -0.0064  -0.0327  -0.0344  -0.0408  -0.0343;
        -0.0037   0.2818  -0.0427  -0.0675  -0.0779  -0.0368;
        -0.0375  -0.0328   0.2108  -0.0060  -0.0265  -0.0341;
        -0.0245  -0.0777  -0.0056   0.2361  -0.0770  -0.0241;
        -0.0413  -0.0760  -0.0234  -0.0720   0.2572  -0.0045;
        -0.0244  -0.0330  -0.0257  -0.0245  -0.0030   0.1845];

    % B inverse matrix (computed)
    B_inv = inv(B);

    % ========== Persistent variables ==========
    persistent vd_buffer          % vd buffer: [vd[k-1]; vd[k]; vd[k+1]]
    persistent vf vf_k1           % vf[k], vf[k-1]
    persistent delta_v_hat        % δv̂[k]
    persistent w1_hat             % ŵ1[k]
    persistent w2_hat             % ŵ2[k]
    persistent uc_k1 uc_k2        % uc[k-1], uc[k-2]
    persistent delta_vc_k1 delta_vc_k2  % δvc[k-1], δvc[k-2]
    
    persistent initialized

    if isempty(initialized)
        initialized = true;
        vd_buffer = zeros(3, 6);  % Row 1: vd[k-1], Row 2: vd[k], Row 3: vd[k+1]
        vf = zeros(6, 1);
        vf_k1 = zeros(6, 1);
        delta_v_hat = zeros(6, 1);
        w1_hat = zeros(6, 1);
        w2_hat = zeros(6, 1);
        uc_k1 = zeros(6, 1);
        uc_k2 = zeros(6, 1);
        delta_vc_k1 = zeros(6, 1);
        delta_vc_k2 = zeros(6, 1);
    end

    % ========== Update vd buffer (d=0) ==========
    % buffer：vd[k-1] <- vd[k] <- vd[k+1] <- new input
    vd_buffer(1, :) = vd_buffer(2, :);  % vd[k-1] = old vd[k]
    vd_buffer(2, :) = vd_buffer(3, :);  % vd[k] = old vd[k+1]
    vd_buffer(3, :) = vd';              % vd[k+1] = new input

    % （d=0 need vd[k+1], vd[k], vd[k-1]）
    vd_k_plus1  = vd_buffer(3, :)';  % vd[k+1] - preview 1 step
    vd_k        = vd_buffer(2, :)';  % vd[k] - current
    vd_k_minus1 = vd_buffer(1, :)';  % vd[k-1] - past 1 step

    % ========== Initialization ==========

    % vf[k+1] = 1/((1-λc)(1+b)) {b·vd[k+d+1] + (1-b·λc)·vd[k+d] - λc·vd[k+d-1]} (d=0)
    vf_next = (1 / ((1 - lambda_c) * (1 + b))) * ...
              (b * vd_k_plus1 + (1 - b*lambda_c) * vd_k - lambda_c * vd_k_minus1);

    % δvf[k] = vf[k+1] - (1-bc)·vf[k] - bc·vf[k-1]
    delta_vf = vf_next - (1 - bc)*vf - bc*vf_k1;

    % δv[k] = vf[k] - vm[k]
    delta_v = vf - vm;

    % δv̂[k+1] = λc·δv̂[k] + δvf[k] + ℓ1{δv[k] - δv̂[k]}
    delta_v_hat_next = lambda_c * delta_v_hat + delta_vf + l_1 * (delta_v - delta_v_hat);

    % ŵ1[k+1] = (1+β)·ŵ1[k] - β·ŵ2[k] + ℓ2{δv[k] - δv̂[k]}
    w1_hat_next = (1 + beta) * w1_hat - beta * w2_hat + l_2 * (delta_v - delta_v_hat);

    % ŵ2[k+1] = ŵ1[k] + ℓ3{δv[k] - δv̂[k]}
    w2_hat_next = w1_hat + l_3 * (delta_v - delta_v_hat);

    % ========== Control law: Initialization ==========

    % δvc[k] = δv[k] - ŵ1[k]
    delta_vc = delta_v - w1_hat;

    % uc[k] = (1-bc)·uc[k-1] - bc·uc[k-2] + ku·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
    uc = (1 - bc) * uc_k1 - bc * uc_k2 + ...
         ku * (delta_vc - a1 * delta_vc_k1 - a2 * delta_vc_k2);

    % u[k] = B^(-1)·uc[k]
    u = B_inv * uc;

    % Output error
    e = delta_v;

    % ========== Update history ==========
    vf_k1 = vf;
    vf = vf_next;

    delta_v_hat = delta_v_hat_next;
    w1_hat = w1_hat_next;
    w2_hat = w2_hat_next;

    uc_k2 = uc_k1;
    uc_k1 = uc;

    delta_vc_k2 = delta_vc_k1;
    delta_vc_k1 = delta_vc;
end
