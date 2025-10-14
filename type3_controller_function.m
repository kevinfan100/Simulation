function [u, e] = fcn(vd, vm)
    % Type 3 Flux Controller - Based on PDF Page 3
    % Simplest disturbance model: wT[k+1] = wT[k]

    % Get tunable parameters from workspace
    lambda_c = evalin('base', 'lambda_c');
    lambda_e = evalin('base', 'lambda_e');

    % Fixed parameters (embedded)
    a1 = 1.595052025060797;
    a2 = -0.599079946700523;

    % B inverse matrix (6×6)
    B_inv = [
        1254.431611705956, 365.9220943459926, 362.7155917884968, 509.3482978358023, 510.7001779284304, 478.0582926900250;
        354.6971171665686, 1162.405056456143, 387.9439456363920, 669.9392357083276, 692.4786011832921, 448.5820022028297;
        427.5001765633072, 453.9421687049577, 1258.888469891571, 439.2720672764521, 487.9780723937001, 520.7798602912907;
        442.5225059058810, 654.6172791671690, 353.7782454546361, 1460.679099061605, 800.4859896304748, 448.7782507759195;
        414.1758700238313, 572.5106763685067, 337.4250003002655, 687.4793677108798, 1274.435404241492, 374.7160216413520;
        412.2201604485579, 400.9218769846693, 368.4630812134598, 474.4034014903570, 407.3700335734076, 1371.560285470157
    ];

    % Persistent variables (state memory)
    persistent vd_k1 vd_k2 s1_hat s2_hat wT_hat initialized

    % Initialize persistent variables
    if isempty(initialized)
        initialized = true;
        vd_k1 = zeros(6,1);   % vd[k-1]
        vd_k2 = zeros(6,1);   % vd[k-2]
        s1_hat = zeros(6,1);  % ŝ1[k] = δv̂[k]
        s2_hat = zeros(6,1);  % ŝ2[k] = δv̂[k-1]
        wT_hat = zeros(6,1);  % ŵT[k]
    end

    % === Control Algorithm ===

    % 1. Tracking error: δv[k] = vd[k-1] - vm[k]
    delta_v = vd_k1 - vm;
    e = delta_v;  % Output error signal

    % 2. Innovation: e_s1[k] = δv[k] - ŝ1[k]
    e_s1 = delta_v - s1_hat;

    % 3. Feedforward: vff[k] = vd[k] - a1·vd[k-1] - a2·vd[k-2]
    vff = vd - a1 * vd_k1 - a2 * vd_k2;

    % 4. Feedback: δvfb[k] = (a1-λc)·ŝ1[k] + a2·ŝ2[k]
    delta_vfb = (a1 - lambda_c) * s1_hat + a2 * s2_hat;

    % 5. Control law: u[k] = B^(-1){vff + δvfb - ŵT}
    u = B_inv * (vff + delta_vfb - wT_hat);

    % 6. Estimator gains (from PDF page 3)
    l_1 = 1 + a1 - 3*lambda_e;
    l_2 = 1 + lambda_e^3/a2;
    l_3 = -(1 - lambda_e)^3;

    % 7. State update (for next time step)
    s1_hat_next = lambda_c * s1_hat + l_1 * e_s1;
    s2_hat_next = s1_hat + l_2 * e_s1;
    wT_hat_next = wT_hat + l_3 * e_s1;

    % 8. Update history
    vd_k2 = vd_k1;
    vd_k1 = vd;
    s1_hat = s1_hat_next;
    s2_hat = s2_hat_next;
    wT_hat = wT_hat_next;
end