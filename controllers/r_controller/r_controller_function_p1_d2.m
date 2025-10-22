function [u, e, w1_hat] = r_controller_function_p1_d2(vd, vm)
    % R Controller with d=2 Preview (Flux_Control_R_newmodel.pdf Page 1)

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

    lambda_c = 0.8179;
    lambda_e = 0.3659;
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
    l_3 = (-(b + beta)*(beta^2 - 3*beta*lambda_e + beta + 3*lambda_e^2 - 3*lambda_e + 1) - lambda_e^3) / ...
          (kc * (b + 1) * (b + beta));


    persistent vd_buffer          % vd buffer: [vd[k]; vd[k+1]; vd[k+2]; vd[k+3]]


    persistent vf                 % vf[k]
    persistent vf_k1              % vf[k-1]


    persistent delta_vf_k1        % δvf[k-1]
    persistent delta_v_k1         % δv[k-1]


    persistent delta_v_hat_k1     % δv̂[k-1]
    persistent w1_hat_k1          % ŵ1[k-1]
    persistent w2_hat_k1          % ŵ2[k-1]


    persistent uc_k1              % uc[k-1]
    persistent uc_k2              % uc[k-2]
    persistent delta_vc_k1        % δvc[k-1]
    persistent delta_vc_k2        % δvc[k-2]

    persistent initialized

    if isempty(initialized)
        initialized = true;

        vd_buffer = zeros(4, 6);  % Row 1: vd[k], Row 2: vd[k+1], Row 3: vd[k+2], Row 4: vd[k+3]

        vf = zeros(6, 1);
        vf_k1 = zeros(6, 1);

        delta_vf_k1 = zeros(6, 1);
        delta_v_k1 = zeros(6, 1);

        delta_v_hat_k1 = zeros(6, 1);
        w1_hat_k1 = zeros(6, 1);
        w2_hat_k1 = zeros(6, 1);

        uc_k1 = zeros(6, 1);
        uc_k2 = zeros(6, 1);
        delta_vc_k1 = zeros(6, 1);
        delta_vc_k2 = zeros(6, 1);
    end

    % VD Buffer (d=2)

    % Buffer：vd[k] <- vd[k+1] <- vd[k+2] <- vd[k+3] <- new input
    vd_buffer(1, :) = vd_buffer(2, :);  % vd[k] = old vd[k+1]
    vd_buffer(2, :) = vd_buffer(3, :);  % vd[k+1] = old vd[k+2]
    vd_buffer(3, :) = vd_buffer(4, :);  % vd[k+2] = old vd[k+3]
    vd_buffer(4, :) = vd';              % vd[k+3] = new input 

    vd_k        = vd_buffer(1, :)';  % vd[k]
    vd_k_plus1  = vd_buffer(2, :)';  % vd[k+1]
    vd_k_plus2  = vd_buffer(3, :)';  % vd[k+2]
    vd_k_plus3  = vd_buffer(4, :)';  % vd[k+3]

    % vf[k+1] = 1/((1-λc)(1+b)) {b·vd[k+3] + (1-b·λc)·vd[k+2] - λc·vd[k+1]} (d=2)
    vf_next = (1 / ((1 - lambda_c) * (1 + b))) * ...
              (b * vd_k_plus3 + (1 - b*lambda_c) * vd_k_plus2 - lambda_c * vd_k_plus1);

    % δvf[k] = vf[k+1] - (1-bc)·vf[k] - bc·vf[k-1]
    delta_vf = vf_next - (1 - bc)*vf - bc*vf_k1;

    % δv[k] = vf[k] - vm[k]
    delta_v = vf - vm;

    error_term = delta_v_k1 - delta_v_hat_k1;

    % Estimator

    % δv̂[k] = λc·δv̂[k-1] + δvf[k-1] + ℓ1{δv[k-1] - δv̂[k-1]}
    delta_v_hat = lambda_c * delta_v_hat_k1 + delta_vf_k1 + l_1 * error_term;

    % ŵ1[k] = (1+β)·ŵ1[k-1] - β·ŵ2[k-1] + ℓ2{δv[k-1] - δv̂[k-1]}
    w1_hat = (1 + beta) * w1_hat_k1 - beta * w2_hat_k1 + l_2 * error_term;

    % ŵ2[k] = ŵ1[k-1] + ℓ3{δv[k-1] - δv̂[k-1]}
    w2_hat = w1_hat_k1 + l_3 * error_term;

    % Control law

    % δvc[k] = δv[k] - ŵ1[k]
    delta_vc = delta_v - w1_hat;

    % uc[k] = (1-bc)·uc[k-1] - bc·uc[k-2] + ku·{δvc[k] - a1·δvc[k-1] - a2·δvc[k-2]}
    uc = (1 - bc) * uc_k1 - bc * uc_k2 + ...
         ku * (delta_vc - a1 * delta_vc_k1 - a2 * delta_vc_k2);

    % u[k] = B^(-1)·uc[k]
    u = B_inv * uc;

    % e[k] = δv[k]
    e = delta_v;

    % State updates
    vf_k1 = vf;        % vf[k-1] ← vf[k]
    vf = vf_next;      % vf[k] ← vf[k+1]

    delta_vf_k1 = delta_vf;  % δvf[k-1] ← δvf[k]
    delta_v_k1 = delta_v;    % δv[k-1] ← δv[k]

    delta_v_hat_k1 = delta_v_hat;  % δv̂[k-1] ← δv̂[k]
    w1_hat_k1 = w1_hat;            % ŵ1[k-1] ← ŵ1[k]
    w2_hat_k1 = w2_hat;            % ŵ2[k-1] ← ŵ2[k]

    uc_k2 = uc_k1;              % uc[k-2] ← uc[k-1]
    uc_k1 = uc;                 % uc[k-1] ← uc[k]
    delta_vc_k2 = delta_vc_k1;  % δvc[k-2] ← δvc[k-1]
    delta_vc_k1 = delta_vc;     % δvc[k-1] ← δvc[k]
end
