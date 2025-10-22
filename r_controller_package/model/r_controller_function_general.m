function [u, e, w1_hat] = r_controller_function_general(vd, vm, fB_c, fB_e, d)
    % R Controller with Configurable d Preview (Flux_Control_R_P1.pdf)
    % d = preview steps (0, 1, 2, 3)
    % Input vd represents vd[k+d] (d steps ahead of current time k)

    T = 1e-5;                     % Sampling time [s]

    k_o = 5.6695e-4;              % k_o from H(z^-1)
    b = 0.9782;                   % b from H(z^-1)
    a1 = 1.934848;                % a1
    a2 = -0.935970;               % a2

    B = [0.2365  -0.0064  -0.0327  -0.0344  -0.0408  -0.0343;
        -0.0037   0.2818  -0.0427  -0.0675  -0.0779  -0.0368;
        -0.0375  -0.0328   0.2108  -0.0060  -0.0265  -0.0341;
        -0.0245  -0.0777  -0.0056   0.2361  -0.0770  -0.0241;
        -0.0413  -0.0760  -0.0234  -0.0720   0.2572  -0.0045;
        -0.0244  -0.0330  -0.0257  -0.0245  -0.0030   0.1845];

    B_inv = inv(B);

    lambda_c = exp(-fB_c*2*pi*T);
    lambda_e = exp(-fB_e*2*pi*T);

    beta = sqrt(lambda_e * lambda_c);

    kc = (1 - lambda_c) / (1 + b);
    bc = b * kc;
    ku = kc / k_o;

    % ℓ1
    l_1 = lambda_c + (1 + beta) - 3*lambda_e;

    % ℓ2
    l_2 = (b*(lambda_e - 1)^3 - beta*(b + 1)*(beta^2 - 3*beta*lambda_e + beta + 3*lambda_e^2 - 3*lambda_e + 1)) / ...
          (kc * (b + 1) * (b + beta));

    % ℓ3
    l_3 = -(beta + b + beta*b - 3*beta*lambda_e - 3*b*lambda_e + b*beta^2 + 3*b*lambda_e^2 + beta^2 + lambda_e^3 - 3*beta*b*lambda_e) / ...
          (kc * (b + 1) * (b + beta));


    % ====================================================================
    % PERSISTENT VARIABLES
    % ====================================================================

    persistent vd_buffer          % Fixed 3-element sliding window buffer

    persistent vf_k1              % vf[k-1]
    persistent vf_k2              % vf[k-2]

    persistent delta_v_k1         % δv[k-1]

    persistent delta_v_hat_k1     % δv̂[k-1]
    persistent w1_hat_k1          % ŵ1[k-1]
    persistent w2_hat_k1          % ŵ2[k-1]

    persistent u_k1               % u[k-1]
    persistent u_k2               % u[k-2]
    persistent delta_vc_k1        % δvc[k-1]
    persistent delta_vc_k2        % δvc[k-2]

    persistent initialized

    % ====================================================================
    % INITIALIZATION
    % ====================================================================

    if isempty(initialized)
        initialized = true;

        vd_buffer = zeros(3, 6);  % Fixed 3 elements for sliding window

        vf_k1 = zeros(6, 1);
        vf_k2 = zeros(6, 1);

        delta_v_k1 = zeros(6, 1);

        delta_v_hat_k1 = zeros(6, 1);
        w1_hat_k1 = zeros(6, 1);
        w2_hat_k1 = zeros(6, 1);

        u_k1 = zeros(6, 1);
        u_k2 = zeros(6, 1);
        delta_vc_k1 = zeros(6, 1);
        delta_vc_k2 = zeros(6, 1);
    end

    % ====================================================================
    % VD BUFFER UPDATE (Sliding Window)
    % ====================================================================
    % Buffer always contains 3 consecutive vd values
    % What they represent depends on d:
    %   d=0: buffer = [vd[k-2], vd[k-1], vd[k]]   <- input is vd[k]
    %   d=1: buffer = [vd[k-1], vd[k],   vd[k+1]] <- input is vd[k+1]
    %   d=2: buffer = [vd[k],   vd[k+1], vd[k+2]] <- input is vd[k+2]
    %   d=3: buffer = [vd[k+1], vd[k+2], vd[k+3]] <- input is vd[k+3]

    vd_buffer(1, :) = vd_buffer(2, :);  % Oldest <- Middle
    vd_buffer(2, :) = vd_buffer(3, :);  % Middle <- Newest
    vd_buffer(3, :) = vd';              % Newest <- New input (vd[k+d])

    % Extract the 3 consecutive values for vf calculation
    vd_d_minus2 = vd_buffer(1, :)';  % vd[k+d-2]
    vd_d_minus1 = vd_buffer(2, :)';  % vd[k+d-1]
    vd_d        = vd_buffer(3, :)';  % vd[k+d]

    % ====================================================================
    % VF CALCULATION (Universal formula for all d)
    % ====================================================================
    % vf[k] = 1/((1-λc)(1+b)) {b·vd[k+d] + (1-bλc)·vd[k+d-1] - λc·vd[k+d-2]}
    % This formula is the same regardless of d value

    vf_k = (1 / ((1 - lambda_c) * (1 + b))) * ...
           (b * vd_d + (1 - b*lambda_c) * vd_d_minus1 - lambda_c * vd_d_minus2);

    % ====================================================================
    % DELTA VF CALCULATION
    % ====================================================================
    % δvf[k-1] = vf[k] - (1-bc)·vf[k-1] - bc·vf[k-2]

    delta_vf = vf_k - (1 - bc)*vf_k1 - bc*vf_k2;

    % ====================================================================
    % TRACKING ERROR
    % ====================================================================
    % δv[k] = vf[k] - vm[k]

    delta_v = vf_k - vm;

    error_term = delta_v_k1 - delta_v_hat_k1;

    % ====================================================================
    % ESTIMATOR
    % ====================================================================

    % δv̂[k] = λc·δv̂[k-1] + δvf[k-1] + ℓ1{δv[k-1] - δv̂[k-1]}
    delta_v_hat = lambda_c * delta_v_hat_k1 + delta_vf + l_1 * error_term;

    % ŵ1[k] = (1+β)·ŵ1[k-1] - β·ŵ2[k-1] + ℓ2{δv[k-1] - δv̂[k-1]}
    w1_hat = (1 + beta) * w1_hat_k1 - beta * w2_hat_k1 + l_2 * error_term;

    % ŵ2[k] = ŵ1[k-1] + ℓ3{δv[k-1] - δv̂[k-1]}
    w2_hat = w1_hat_k1 + l_3 * error_term;

    % ====================================================================
    % CONTROL LAW
    % ====================================================================

    % δvc[k] = ku δv[k] - ŵ1[k]
    delta_vc = ku * delta_v - w1_hat;

    % u[k] = (1-bc)·u[k-1] + bc·u[k-2] + Binv·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
    u = (1 - bc) * u_k1 + bc * u_k2 + ...
         B_inv * (delta_vc - a1 * delta_vc_k1 - a2 * delta_vc_k2);

    % ====================================================================
    % OUTPUT
    % ====================================================================

    % e[k] = δv[k]
    e = delta_v;

    % ====================================================================
    % STATE UPDATES
    % ====================================================================

    vf_k2 = vf_k1;     % vf[k-2] ← vf[k-1]
    vf_k1 = vf_k;      % vf[k-1] ← vf[k]

    delta_v_k1 = delta_v;    % δv[k-1] ← δv[k]

    delta_v_hat_k1 = delta_v_hat;  % δv̂[k-1] ← δv̂[k]
    w1_hat_k1 = w1_hat;            % ŵ1[k-1] ← ŵ1[k]
    w2_hat_k1 = w2_hat;            % ŵ2[k-1] ← ŵ2[k]

    u_k2 = u_k1;              % u[k-2] ← u[k-1]
    u_k1 = u;                 % u[k-1] ← u[k]
    delta_vc_k2 = delta_vc_k1;  % δvc[k-2] ← δvc[k-1]
    delta_vc_k1 = delta_vc;     % δvc[k-1] ← δvc[k]
end
