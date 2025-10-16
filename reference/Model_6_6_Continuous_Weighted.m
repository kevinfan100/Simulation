% MIMO TRANSFER FUNCTION FITTING AND DISCRETIZATION
%
% Purpose:
%   Fit 6×6 MIMO transfer function from frequency response data (P1~P6)
%   and perform Zero-Order Hold (ZOH) discretization
%
% Mathematical Model:
%   H(s) = [A2 / (s² + A1·s + A2)] · B
%   where B is a 6×6 gain matrix
%
% Input Files:
%   - P1.m ~ P6.m: Frequency response data for each excitation
%     Required variables: frequencies, magnitudes_linear, phases_processed
%
% Output:
%   - Continuous transfer function: H(s)
%   - Discrete transfer function: H(z⁻¹) via ZOH
%   - LaTeX formatted output: transfer_function_latex.txt
%
% Version: 2.0

clear; clc;

%% SECTION 1: CONFIGURATION

% --- Data Configuration ---
num_channels = 6;           % Number of output channels
num_files = 6;              % Number of input channels
num_freq = 19;              % Number of frequency points

% --- Single Curve Fitting Parameters (for validation) ---
% Used for testing individual transfer function fitting
channel = 2;                        % Output channel index
excited_channel = 1;                % Input channel index (excitation source)

ENABLE_PARAM_COMPARISON = false;    % Enable parameter comparison mode
p_single = 0.5;                     % Weighting exponent (0.5 or 1)
wc_single_Hz = 0.1;                  % Cutoff frequency [Hz] for low-pass weighting

% Parameter sets for comparison (when ENABLE_PARAM_COMPARISON = true)
% Each row: [p, wc_Hz]
param_sets_single = [
    0.5, 1e10;   % Almost no weighting (baseline)
    0.5, 50;
    0.5, 80;
    0.5, 100;
    0.5, 200;
    1, 100;
    1, 200;
];

% --- Multiple Curve Fitting Parameters (main functionality) ---
p_multi = 0.5;                      % Weighting exponent: w(ω) = 1/(1+(ω²/ωc²))^p
wc_multi_Hz = 0.1;                  % Cutoff frequency [Hz]

% --- Discretization Parameters ---
T_sample = 1e-5;                    % Sampling time [s] (10 μs, Fs = 100 kHz)

% Fixed Amplifier Gain Matrix (diagonal values)
k_A_diag = [0.3618, 0.3614, 0.3536, 0.3532, 0.3573, 0.3610];

% --- Output and Visualization Control ---
PLOT_ONE_CURVE = true;             % Plot single curve Bode diagram
PLOT_MULTI_CURVE = false;           % Plot multiple curves Bode diagram
MULTI_CURVE_EXCITED_CHANNELS = [1]; % Channels to plot (e.g., [1,3,5] for P1,P3,P5)

OUTPUT_LATEX = true;                % Generate LaTeX output file
LATEX_FILENAME = 'transfer_function_latex.txt';

% --- 36-Channel Single Curve Fitting Control ---
SAVE_ONE_CURVE_RESULTS = true;      % Save individual transfer function parameters
ONE_CURVE_OUTPUT_FILE = 'one_curve_36_results.mat';

%% SECTION 2: DATA LOADING

% Initialize storage arrays
H_mag = zeros(num_channels, num_files, num_freq);    % Magnitude: |H(jω)|
H_phase = zeros(num_channels, num_files, num_freq);  % Phase: ∠H(jω) [deg]
W = [];                                               % Frequency vector [Hz]

% Load data from P1.m ~ P6.m
for file_idx = 1:num_files
    script_name = sprintf('P%d', file_idx);

    try
        eval(script_name);

        % Store frequency vector (assumes all files have same frequencies)
        if isempty(W)
            W = frequencies;
        end

        % Store magnitude and phase data
        H_mag(:, file_idx, :) = magnitudes_linear;
        H_phase(:, file_idx, :) = phases_processed;

    catch ME
        error('Failed to load %s.m: %s', script_name, ME.message);
    end

    % Clear temporary variables from P*.m files
    clear magnitudes_linear phases phases_processed frequencies
end

fprintf('Data loaded: %d files, freq range %.2f ~ %.2f Hz\n', ...
    num_files, min(W), max(W));

% Clear temporary loop variable
clear file_idx script_name

%% SECTION 3: PREPROCESSING

% --- Convert frequency to rad/s ---
w_k = W(:) * 2 * pi;                % ω_k [rad/s] (column vector)

% --- Phase Offset Removal ---
% Remove phase offset at minimum frequency (ω_min)
% Mathematical operation: φ_new(ω) = φ(ω) - φ(ω_min)

H_phase_offset_removed = H_phase;   % Copy original phase data

[~, min_freq_idx] = min(w_k);       % Find index of minimum frequency

for i = 1:num_channels
    for j = 1:num_channels
        phase_data = squeeze(H_phase(i, j, :));           % φ_ij(ω) [deg]
        phase_offset = phase_data(min_freq_idx);          % φ_ij(ω_min)
        H_phase_offset_removed(i, j, :) = phase_data - phase_offset;
    end
end

fprintf('Phase offset removed at ω_min = %.2f Hz\n', W(min_freq_idx));

%% SECTION 4: SINGLE CURVE FITTING (Optional - for validation)

% Extract single channel data
h_k = squeeze(H_mag(channel, excited_channel, :));
phi_k = squeeze(H_phase_offset_removed(channel, excited_channel, :)) * pi / 180;

sin_phi_k = sin(phi_k);
cos_phi_k = cos(phi_k);

if ENABLE_PARAM_COMPARISON
    % === Compare multiple parameter sets ===
    num_params = size(param_sets_single, 1);

    % Storage for each parameter set
    a1_all = zeros(num_params, 1);
    a2_all = zeros(num_params, 1);
    b_all = zeros(num_params, 1);
    H_fitted_all = cell(num_params, 1);

    fprintf('\n=== Single Curve Fitting - Parameter Comparison ===\n');

    % Fit for each parameter set
    for idx = 1:num_params
        p_test = param_sets_single(idx, 1);
        wc_test_Hz = param_sets_single(idx, 2);
        wc_test_rad = wc_test_Hz * 2 * pi;

        % Weighting function: w(ω) = 1/(1+(ω²/ωc²))^p
        weight_k = 1 ./ (1 + (w_k.^2 / wc_test_rad^2)).^p_test;

        % Build weighted least squares matrices
        sum_hk2_wk2 = sum(weight_k .* h_k.^2 .* w_k.^2);
        sum_hk2 = sum(weight_k .* h_k.^2);
        sum_hk_sin_wk = sum(weight_k .* h_k .* sin_phi_k .* w_k);
        sum_hk_cos = sum(weight_k .* h_k .* cos_phi_k);
        sum_hk_cos_wk2 = sum(weight_k .* h_k .* cos_phi_k .* w_k.^2);
        sum_weight = sum(weight_k);

        a = [
            sum_hk2_wk2,        0,              sum_hk_sin_wk;
            0,                  sum_hk2,       -sum_hk_cos;
            sum_hk_sin_wk,     -sum_hk_cos,     sum_weight;
        ];

        y = [
            0;
            sum_hk2_wk2;
           -sum_hk_cos_wk2;
        ];

        x = a \ y;

        a1_all(idx) = x(1);
        a2_all(idx) = x(2);
        b_all(idx) = x(3);

        s = 1j * w_k;
        H_fitted_all{idx} = b_all(idx) ./ (s.^2 + a1_all(idx)*s + a2_all(idx));

        fprintf('  Param %d: p=%.1f, wc=%.1f Hz → a1=%.6f, a2=%.6f, b=%.6f\n', ...
            idx, p_test, wc_test_Hz, a1_all(idx), a2_all(idx), b_all(idx));
    end

else
    % === Single parameter fitting ===
    wc_single_rad = wc_single_Hz * 2 * pi;
    weight_k = 1 ./ (1 + (w_k.^2 / wc_single_rad^2)).^p_single;

    sum_hk2_wk2 = sum(weight_k .* h_k.^2 .* w_k.^2);
    sum_hk2 = sum(weight_k .* h_k.^2);
    sum_hk_sin_wk = sum(weight_k .* h_k .* sin_phi_k .* w_k);
    sum_hk_cos = sum(weight_k .* h_k .* cos_phi_k);
    sum_hk_cos_wk2 = sum(weight_k .* h_k .* cos_phi_k .* w_k.^2);
    sum_weight = sum(weight_k);

    a = [
        sum_hk2_wk2,        0,              sum_hk_sin_wk;
        0,                  sum_hk2,       -sum_hk_cos;
        sum_hk_sin_wk,     -sum_hk_cos,     sum_weight;
    ];

    y = [
        0;
        sum_hk2_wk2;
       -sum_hk_cos_wk2;
    ];

    x = a \ y;

    a1 = x(1);
    a2 = x(2);
    b  = x(3);

    s = 1j * w_k;
    H_fitted = b ./ (s.^2 + a1*s + a2);

    fprintf('\n=== Single Curve Fitting ===\n');
    fprintf('w(ω)=1/(1+(ω²/ωc²))^p, ωc=%.2f rad/s (%.2f Hz), p=%.1f\n', ...
            wc_single_rad, wc_single_Hz, p_single);
    fprintf('a1=%.6f, a2=%.6f, b=%.6f\n', a1, a2, b);
end

%% SECTION 4.5: BATCH SINGLE CURVE FITTING (36 Channels) [OPTIONAL]

if SAVE_ONE_CURVE_RESULTS
    fprintf('\n=== Batch Single Curve Fitting: 36 Channels ===\n');

    % Initialize result structure
    one_curve_results = struct();
    one_curve_results.a1_matrix = zeros(6, 6);
    one_curve_results.a2_matrix = zeros(6, 6);
    one_curve_results.b_matrix  = zeros(6, 6);

    % Use unified fitting parameters from SECTION 1
    p_fit = p_single;        % line 36
    wc_Hz = wc_single_Hz;    % line 37
    wc_rad = wc_Hz * 2 * pi;

    % Batch fitting loop
    fprintf('Fitting parameters for 36 transfer functions...\n');
    for i = 1:6  % Output channel
        for j = 1:6  % Input channel (excitation)
            % Extract frequency response data for channel pair (i,j)
            h_k_ij = squeeze(H_mag(i, j, :));
            phi_k_ij = squeeze(H_phase_offset_removed(i, j, :)) * pi / 180;

            % Perform single curve fitting
            [a1_ij, a2_ij, b_ij] = fit_single_tf(h_k_ij, phi_k_ij, w_k, p_fit, wc_rad);

            % Store results
            one_curve_results.a1_matrix(i, j) = a1_ij;
            one_curve_results.a2_matrix(i, j) = a2_ij;
            one_curve_results.b_matrix(i, j) = b_ij;
        end
    end

    % Add metadata
    one_curve_results.meta = struct(...
        'date', datestr(now), ...
        'p', p_fit, ...
        'wc_Hz', wc_Hz, ...
        'frequencies', W, ...
        'num_channels', 6, ...
        'description', '36-channel individual transfer functions (continuous)' ...
    );

    % Save to .mat file
    save(ONE_CURVE_OUTPUT_FILE, 'one_curve_results');
    fprintf('✓ Results saved to: %s\n', ONE_CURVE_OUTPUT_FILE);
    fprintf('  - a1_matrix: 6×6 first-order coefficients\n');
    fprintf('  - a2_matrix: 6×6 second-order coefficients\n');
    fprintf('  - b_matrix:  6×6 numerator gains\n');
    fprintf('  - Format: H_ij(s) = b(i,j) / (s² + a1(i,j)·s + a2(i,j))\n');
else
    fprintf('\n=== Batch Single Curve Fitting: SKIPPED ===\n');
    fprintf('  (SAVE_ONE_CURVE_RESULTS = false)\n');
end

%% SECTION 5: MULTIPLE CURVE FITTING (Main Functionality)

% --- Reshape data from 6×6×19 to 36×19 ---
h_Lk = zeros(36, num_freq);
for i = 1:6
    for j = 1:6
        idx = (i-1)*6 + j;
        h_Lk(idx, :) = squeeze(H_mag(i, j, :));
    end
end

phi_Lk = zeros(36, num_freq);
for i = 1:6
    for j = 1:6
        idx = (i-1)*6 + j;
        phi_Lk(idx, :) = squeeze(H_phase_offset_removed(i, j, :)) * pi / 180;
    end
end

sin_phi_Lk = sin(phi_Lk);
cos_phi_Lk = cos(phi_Lk);

% --- Weighting function ---
wc_multi_rad = wc_multi_Hz * 2 * pi;
weight_k = 1 ./ (1 + (w_k.^2 / wc_multi_rad^2)).^p_multi;

fprintf('\n=== Multiple Curve Fitting ===\n');
fprintf('w(ω)=1/(1+(ω²/ωc²))^p, ωc=%.2f rad/s (%.2f Hz), p=%.1f\n', ...
        wc_multi_rad, wc_multi_Hz, p_multi);

% --- Build elements for 2×2 block matrix ---
% a11: Σ_k w(ω_k) (Σ_ℓ h²_ℓk) ω²_k
a11 = 0;
for k = 1:num_freq
    sum_h2 = sum(h_Lk(:, k).^2);  % Σ_ℓ h²_ℓk
    a11 = a11 + weight_k(k) * sum_h2 * w_k(k)^2;
end

% a22: Σ_k w(ω_k) (Σ_ℓ h²_ℓk)
a22 = 0;
for k = 1:num_freq
    sum_h2 = sum(h_Lk(:, k).^2);
    a22 = a22 + weight_k(k) * sum_h2;
end

% v1: [a13, a14, ..., a1(2+m)]', where a1(2+ℓ) = Σ_k w(ω_k) h_ℓk s_ℓk ω_k
v1 = zeros(36, 1);
for L = 1:36
    for k = 1:num_freq
        v1(L) = v1(L) + weight_k(k) * h_Lk(L, k) * sin_phi_Lk(L, k) * w_k(k);
    end
end

% v2: [a23, a24, ..., a2(2+m)]', where a2(2+ℓ) = -Σ_k w(ω_k) h_ℓk c_ℓk
v2 = zeros(36, 1);
for L = 1:36
    for k = 1:num_freq
        v2(L) = v2(L) - weight_k(k) * h_Lk(L, k) * cos_phi_Lk(L, k);
    end
end

% yb: [y3, y4, ..., y(2+m)]', where y(2+ℓ) = -Σ_k w(ω_k) h_ℓk c_ℓk ω²_k
yb = zeros(36, 1);
for L = 1:36
    for k = 1:num_freq
        yb(L) = yb(L) - weight_k(k) * h_Lk(L, k) * cos_phi_Lk(L, k) * w_k(k)^2;
    end
end

% y1, y2
y1 = 0;
y2 = 0;
for k = 1:num_freq
    sum_h2 = sum(h_Lk(:, k).^2);
    y2 = y2 + weight_k(k) * sum_h2 * w_k(k)^2;
end

% --- Total weight ---
W_total = sum(weight_k);  % = Σ w(ωₖ)

% --- Build 2×2 block matrix ---
A_2x2 = [
    a11 - (1/W_total)*v1'*v1,     -(1/W_total)*v1'*v2;
    -(1/W_total)*v2'*v1,          a22 - (1/W_total)*v2'*v2
];

Y_2x2 = [
    y1 - (1/W_total)*v1'*yb;
    y2 - (1/W_total)*v2'*yb
];

% Check matrix condition
if cond(A_2x2) > 1e12
    warning('Matrix may be ill-conditioned (cond=%.2e)', cond(A_2x2));
end

% --- Solve for A1, A2 ---
X_2x2 = A_2x2 \ Y_2x2;
A1 = X_2x2(1);
A2 = X_2x2(2);

% --- Solve for b vector and B matrix ---
b_vec = (1/W_total) * (yb - A1*v1 - A2*v2);  % 36×1

B = zeros(6, 6);
for i = 1:6
    for j = 1:6
        L = (i-1)*6 + j;
        b_ij = b_vec(L);
        B(i, j) = b_ij / A2;
    end
end

fprintf('H(s) = [%.4e/(s² + %.4e·s + %.4e)] · B\n', A2, A1, A2);

%% SECTION 6: DISCRETIZATION (Zero-Order Hold)

% --- Modify B matrix sign (negate off-diagonal elements) ---
B_modified = B;
for i = 1:num_channels
    for j = 1:num_channels
        if i ~= j
            B_modified(i,j) = -B(i,j);
        end
    end
end

fprintf('\n=== Discretization (ZOH, T=%.0e s) ===\n', T_sample);

% --- Build continuous-time transfer function ---
num_s = A2;
den_s = [1, A1, A2];
H_continuous = tf(num_s, den_s);

% --- Discretize using ZOH method ---
H_discrete = c2d(H_continuous, T_sample, 'zoh');

% --- Extract discrete transfer function coefficients ---
[num_z, den_z] = tfdata(H_discrete, 'v');

% Normalize denominator (ensure first term = 1)
den_z = den_z / den_z(1);
num_z = num_z / den_z(1);

% Display coefficients
fprintf('Numerator [b0, b1]: [%.6e, %.6e]\n', num_z(2), num_z(3));
fprintf('Denominator [1, a1, a2]: [1, %.6e, %.6e]\n', den_z(2), den_z(3));

% --- Compute factored form ---
b0_val = num_z(2);
b1_val = num_z(3);
b0_exp_val = floor(log10(abs(b0_val)));
b0_mantissa_val = b0_val / 10^b0_exp_val;
b1_over_b0_val = b1_val / b0_val;

a1_val = den_z(2);
a2_val = den_z(3);
poles_z_val = roots([1, a1_val, a2_val]);  % Z-domain poles: z² + a1·z + a2 = 0

% --- Pole analysis and stability ---
fprintf('\nZ-domain poles:\n');
fprintf('  z1 = %.8f %+.8fi, |z1| = %.8f\n', ...
    real(poles_z_val(1)), imag(poles_z_val(1)), abs(poles_z_val(1)));
fprintf('  z2 = %.8f %+.8fi, |z2| = %.8f\n', ...
    real(poles_z_val(2)), imag(poles_z_val(2)), abs(poles_z_val(2)));

% Check pole type
if abs(imag(poles_z_val(1))) > 1e-8
    fprintf('  Type: Complex conjugate pair (oscillatory)\n');
else
    fprintf('  Type: Real poles\n');
end

% Stability check
if all(abs(poles_z_val) < 1)
    fprintf('  ✓ System stable (all poles inside unit circle)\n');
else
    fprintf('  ✗ System unstable (poles outside unit circle)\n');
end

% --- Fixed Amplifier Gain Matrix ---
k_A = diag(k_A_diag);

%% SECTION 7: LATEX OUTPUT

if OUTPUT_LATEX

    latex_output = {};

    % Header
    latex_output{end+1} = '% ============================================';
    latex_output{end+1} = '% Transfer Function LaTeX Output';
    latex_output{end+1} = sprintf('%% Generated: %s', datestr(now));
    latex_output{end+1} = '% ============================================';
    latex_output{end+1} = '';

    % 1. Continuous-time transfer function H(s)
    latex_output{end+1} = '% === Continuous-Time Transfer Function ===';
    latex_output{end+1} = '\mathbf{H}(s) = \frac{';
    latex_output{end+1} = sprintf('%.4f \\times 10^{%d}', ...
        A2/10^floor(log10(abs(A2))), floor(log10(abs(A2))));
    latex_output{end+1} = '}{';
    latex_output{end+1} = sprintf('s^2 + %.4f \\times 10^{%d} s + %.4f \\times 10^{%d}', ...
        A1/10^floor(log10(abs(A1))), floor(log10(abs(A1))), ...
        A2/10^floor(log10(abs(A2))), floor(log10(abs(A2))));
    latex_output{end+1} = '} \\mathbf{B}';
    latex_output{end+1} = '';

    % 2. Discrete-time transfer function H(z⁻¹) - factored form
    latex_output{end+1} = '% === Discrete-Time Transfer Function (ZOH) - Factored Form ===';
    latex_output{end+1} = sprintf('%% Sampling Time: T = %.0e s', T_sample);

    % Numerator factorization: b0 × (1 + (b1/b0)·z⁻¹)
    b0 = num_z(2);
    b1 = num_z(3);
    b0_exp = floor(log10(abs(b0)));
    b0_mantissa = b0 / 10^b0_exp;
    b1_over_b0 = b1 / b0;

    % Denominator factorization: (1 + a1·z⁻¹ + a2·z⁻²) = (1 - z1·z⁻¹)(1 - z2·z⁻¹)
    % where z1, z2 are Z-domain poles satisfying z² + a1·z + a2 = 0
    a1_z = den_z(2);
    a2_z = den_z(3);

    % Compute Z-domain poles: z² + a1·z + a2 = 0
    poles_z = roots([1, a1_z, a2_z]);
    z1 = poles_z(1);
    z2 = poles_z(2);

    % For z⁻¹ form: (1 - z1·z⁻¹), coefficient is the pole itself
    r1 = z1;
    r2 = z2;

    % Assemble LaTeX (choose format based on pole type)
    if abs(imag(z1)) > 1e-6
        % Complex conjugate poles: use quadratic form (avoid imaginary numbers)
        latex_output{end+1} = '% Factored form (complex poles, using quadratic)';
        latex_output{end+1} = sprintf([...
            '\\mathbf{H}(z^{-1}) = z^{-1} \\frac{' ...
            '%.4f \\times 10^{%d} \\times (1 + %.4f z^{-1})' ...
            '}{' ...
            '1 + %.6f z^{-1} + %.6f z^{-2}' ...
            '} \\mathbf{B}'], ...
            b0_mantissa, b0_exp, b1_over_b0, a1_z, a2_z);

        % Also provide complex factorization (comment)
        latex_output{end+1} = sprintf([...
            '%% Complex factorization: (1 - (%.6f%+.6fi) z^{-1})(1 - (%.6f%+.6fi) z^{-1})'], ...
            real(r1), imag(r1), real(r2), imag(r2));
    else
        % Real poles: factored form
        latex_output{end+1} = '% Factored form (real poles)';
        latex_output{end+1} = sprintf([...
            '\\mathbf{H}(z^{-1}) = z^{-1} \\frac{' ...
            '%.4f \\times 10^{%d} \\times (1 + %.4f z^{-1})' ...
            '}{' ...
            '(1 - %.6f z^{-1})(1 - %.6f z^{-1})' ...
            '} \\mathbf{B}'], ...
            b0_mantissa, b0_exp, b1_over_b0, real(r1), real(r2));
    end

    % Add pole information (comment)
    latex_output{end+1} = sprintf('%% Z-domain poles: z1 = %.8f %+.8fi, z2 = %.8f %+.8fi', ...
        real(z1), imag(z1), real(z2), imag(z2));
    latex_output{end+1} = sprintf('%% Pole magnitudes: |z1| = %.8f, |z2| = %.8f', ...
        abs(z1), abs(z2));
    latex_output{end+1} = '';

    % 3. B matrix (with modified signs)
    latex_output{end+1} = '% === B Matrix (off-diagonal elements negated) ===';
    latex_output{end+1} = '\mathbf{B} = \begin{bmatrix}';
    for i = 1:num_channels
        row_str = '';
        for j = 1:num_channels
            if j == 1
                row_str = sprintf('%.4f', B_modified(i,j));
            else
                row_str = sprintf('%s & %.4f', row_str, B_modified(i,j));
            end
        end
        if i < num_channels
            latex_output{end+1} = sprintf('%s \\\\', row_str);
        else
            latex_output{end+1} = row_str;
        end
    end
    latex_output{end+1} = '\end{bmatrix}';
    latex_output{end+1} = '';

    % 4. Amplifier Gain Matrix k_A
    latex_output{end+1} = '% === Amplifier Gain Matrix ===';
    latex_output{end+1} = 'k_A = \begin{bmatrix}';
    for i = 1:num_channels
        row_str = '';
        for j = 1:num_channels
            if j == 1
                row_str = sprintf('%.4f', k_A(i,j));
            else
                row_str = sprintf('%s & %.4f', row_str, k_A(i,j));
            end
        end
        if i < num_channels
            latex_output{end+1} = sprintf('%s \\\\', row_str);
        else
            latex_output{end+1} = row_str;
        end
    end
    latex_output{end+1} = '\end{bmatrix}';

    % Save to file
    fid = fopen(LATEX_FILENAME, 'w');
    for i = 1:length(latex_output)
        fprintf(fid, '%s\n', latex_output{i});
    end
    fclose(fid);

    fprintf('\n✓ LaTeX output saved to: %s\n', LATEX_FILENAME);

end

%% SECTION 8: VISUALIZATION (Optional)

% --- Single Curve Bode Plot ---
if PLOT_ONE_CURVE
    figure('Name', 'Bode Plot', 'Position', [100, 100, 900, 720]);

    freq_max = max(W);
    log_ticks = 10.^((0:ceil(log10(freq_max))));
    font_props = {'FontWeight', 'bold', 'FontSize', 24, 'LineWidth', 2};
    axis_props = {'XScale', 'log', 'XLim', [0.1, freq_max], 'XTick', log_ticks};

    freq_smooth = logspace(log10(min(W)), log10(max(W)), 200);
    s_smooth = 1j * 2 * pi * freq_smooth;

    if ENABLE_PARAM_COMPARISON
        % === Parameter Comparison Mode (No normalization) ===

        % Raw measured data (dB)
        h_db_raw = 20*log10(h_k);

        % === Magnitude plot ===
        subplot(2, 1, 1);
        hold on;

        % Plot measured data
        semilogx(W, h_db_raw, 'ko', 'MarkerSize', 12, 'LineWidth', 3, ...
            'MarkerFaceColor', 'w');

        % Plot each parameter's model
        colors = {[1 0 0], [0 0.7 0], [0 0 1], [1 0 1], [0 0 0], [0 0.8 0.8], [0.6 0.4 0.2], [0.5 0.5 0.5]};
        line_styles = {'-', '--', '-.', ':', '-', '--', '-.', ':'};

        for idx = 1:num_params
            H_model_smooth = b_all(idx) ./ (s_smooth.^2 + a1_all(idx)*s_smooth + a2_all(idx));
            H_model_db = 20*log10(abs(H_model_smooth));

            semilogx(freq_smooth, H_model_db, ...
                'Color', colors{idx}, 'LineStyle', line_styles{idx}, 'LineWidth', 2.5, ...
                'DisplayName', sprintf('p=%.1f,ωc=%g', param_sets_single(idx,:)));
        end

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Magnitude (dB)', 'FontWeight', 'bold', 'FontSize', 40);

        set(gca, axis_props{:}, font_props{:});
        y_min = min(h_db_raw) - 5;
        ylim([y_min, 5]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        % === Phase plot ===
        subplot(2, 1, 2);
        hold on;

        % Plot measured phase
        semilogx(W, phi_k*180/pi, 'ko', 'MarkerSize', 12, 'LineWidth', 3, ...
            'MarkerFaceColor', 'w', 'DisplayName', 'Measured');

        % Plot each parameter's phase
        for idx = 1:num_params
            H_model_smooth = b_all(idx) ./ (s_smooth.^2 + a1_all(idx)*s_smooth + a2_all(idx));
            H_model_phase = angle(H_model_smooth) * 180/pi;

            semilogx(freq_smooth, H_model_phase, ...
                'Color', colors{idx}, 'LineStyle', line_styles{idx}, 'LineWidth', 2.5, ...
                'DisplayName', sprintf('p=%.1f,ωc=%g', param_sets_single(idx,:)));
        end

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Phase (deg)', 'FontWeight', 'bold', 'FontSize', 40);
        legend('Location', 'southwest', 'FontWeight', 'bold', 'FontSize', 18);

        set(gca, axis_props{:}, font_props{:});
        ylim([-180, 5]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        sgtitle(sprintf('H_{%d%d}(s) - Parameter Comparison', channel, excited_channel), ...
            'FontWeight', 'bold', 'FontSize', 24);

    else
        % === Single Parameter Mode (Normalized) ===

        % Normalize by DC gain (H(s=0) = b/a2)
        dc_gain = b / a2;
        h_k_norm = h_k / dc_gain;
        h_db_norm = 20*log10(h_k_norm);

        % === Magnitude plot ===
        subplot(2, 1, 1);
        hold on;
        semilogx(W, h_db_norm, 'o-b', 'LineWidth', 3.5, 'MarkerSize', 12, ...
            'MarkerFaceColor', 'none', 'DisplayName', sprintf('Ch%d', channel));

        H_model_smooth = b ./ (s_smooth.^2 + a1*s_smooth + a2);
        H_model_norm = H_model_smooth / dc_gain;
        semilogx(freq_smooth, 20*log10(abs(H_model_norm)), 'k-', 'LineWidth', 3, 'DisplayName', 'Model');

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Magnitude (dB)', 'FontWeight', 'bold', 'FontSize', 40);
        legend('Location', 'southwest', 'FontWeight', 'bold', 'FontSize', 24);

        set(gca, axis_props{:}, font_props{:});
        y_min = min(h_db_norm) - 5;
        ylim([y_min, 5]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        % === Phase plot ===
        subplot(2, 1, 2);
        hold on;
        semilogx(W, phi_k*180/pi, 'o-b', 'LineWidth', 3.5, 'MarkerSize', 12, 'MarkerFaceColor', 'none');

        H_model_smooth = b ./ (s_smooth.^2 + a1*s_smooth + a2);
        semilogx(freq_smooth, angle(H_model_smooth)*180/pi, 'k-', 'LineWidth', 3);

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Phase (deg)', 'FontWeight', 'bold', 'FontSize', 40);

        set(gca, axis_props{:}, font_props{:});
        ylim([-180, 5]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        sgtitle(sprintf('H_{%d%d}(s), p=%.1f, ωc=%.1f Hz', channel, excited_channel, p_single, wc_single_Hz), ...
            'FontWeight', 'bold', 'FontSize', 24);
    end
end

% --- Multiple Curve Bode Plot ---
if PLOT_MULTI_CURVE
    freq_max = max(W);
    log_ticks = 10.^((0:ceil(log10(freq_max))));
    font_props = {'FontWeight', 'bold', 'FontSize', 24, 'LineWidth', 2};
    axis_props = {'XScale', 'log', 'XLim', [0.1, freq_max], 'XTick', log_ticks};
    channel_colors = ['k','b','g','r','m','c'];

    freq_smooth = logspace(log10(min(W)), log10(max(W)), 200);
    s_smooth = 1j * 2 * pi * freq_smooth;

    for excited_ch = MULTI_CURVE_EXCITED_CHANNELS
        figure('Name', sprintf('P%d Excitation - Weighted (ωc=%.1f Hz, p=%.1f)', excited_ch, wc_multi_Hz, p_multi), ...
               'Position', [100 + (excited_ch-1)*150, 100, 1000, 900]);

        % === Magnitude Plot ===
        subplot(2, 1, 1);
        hold on;

        % Plot measured data (normalized by B matrix)
        for ch = 1:6
            h_meas = squeeze(H_mag(ch, excited_ch, :));
            dc_gain_theoretical = B(ch, excited_ch);

            % Normalize by B matrix
            h_meas_norm = h_meas / dc_gain_theoretical;
            h_db_norm = 20*log10(h_meas_norm);

            semilogx(W, h_db_norm, 'o-', 'Color', channel_colors(ch), ...
                'LineWidth', 3.5, 'MarkerSize', 12, 'MarkerFaceColor', 'none', ...
                'DisplayName', sprintf('Channel %d', ch));
        end

        % Plot single model curve (normalized)
        H_model = A2 ./ (s_smooth.^2 + A1*s_smooth + A2);
        H_model_norm = H_model / (A2/A2);
        semilogx(freq_smooth, 20*log10(abs(H_model_norm)), 'k-', 'LineWidth', 3, ...
            'DisplayName', 'Model');

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Magnitude (dB)', 'FontWeight', 'bold', 'FontSize', 40);

        set(gca, axis_props{:}, font_props{:});
        ylim([-30, 1]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        % === Phase Plot ===
        subplot(2, 1, 2);
        hold on;

        % Plot measured phase
        for ch = 1:6
            phi = squeeze(H_phase_offset_removed(ch, excited_ch, :));
            semilogx(W, phi, 'o-', 'Color', channel_colors(ch), ...
                'LineWidth', 3.5, 'MarkerSize', 12, 'MarkerFaceColor', 'none', ...
                'DisplayName', sprintf('Channel %d', ch));
        end

        % Plot single model phase
        H_model = A2 ./ (s_smooth.^2 + A1*s_smooth + A2);
        H_model_phase = angle(H_model) * 180/pi;
        semilogx(freq_smooth, H_model_phase, 'k-', 'LineWidth', 3, ...
            'DisplayName', 'Model');

        xlabel('Frequency (Hz)', 'FontWeight', 'bold', 'FontSize', 40);
        ylabel('Phase (deg)', 'FontWeight', 'bold', 'FontSize', 40);
        legend('Location', 'southwest', 'FontWeight', 'bold', 'FontSize', 18);

        set(gca, axis_props{:}, font_props{:});
        ylim([-180, 1.5]);

        ax = gca;
        ax.XAxis.LineWidth = 3;
        ax.YAxis.LineWidth = 3;
        box on;

        % Title
        sgtitle(sprintf('P%d Excitation - Weighted (ωc=%.1f Hz, p=%.1f)', ...
            excited_ch, wc_multi_Hz, p_multi), 'FontWeight', 'bold', 'FontSize', 24);
    end

    fprintf('\n=== Plots Generated ===\n');
    fprintf('Generated %d figure(s) for channels: %s\n', ...
        length(MULTI_CURVE_EXCITED_CHANNELS), mat2str(MULTI_CURVE_EXCITED_CHANNELS));
end

%% HELPER FUNCTION: Single Transfer Function Fitting

function [a1, a2, b] = fit_single_tf(h_k, phi_k, w_k, p, wc_rad)
    % Fit single second-order transfer function using weighted least squares
    %
    % Transfer Function Model:
    %   H(s) = b / (s² + a1·s + a2)
    %
    % Inputs:
    %   h_k     - Magnitude response (N×1 vector)
    %   phi_k   - Phase response in radians (N×1 vector)
    %   w_k     - Frequency vector in rad/s (N×1 vector)
    %   p       - Weighting exponent
    %   wc_rad  - Cutoff frequency in rad/s
    %
    % Outputs:
    %   a1, a2  - Denominator coefficients
    %   b       - Numerator coefficient

    % Compute weighting function: w(ω) = 1/(1+(ω²/ωc²))^p
    weight_k = 1 ./ (1 + (w_k.^2 / wc_rad^2)).^p;

    % Precompute trigonometric values
    sin_phi_k = sin(phi_k);
    cos_phi_k = cos(phi_k);

    % Build weighted least squares matrices
    sum_hk2_wk2 = sum(weight_k .* h_k.^2 .* w_k.^2);
    sum_hk2 = sum(weight_k .* h_k.^2);
    sum_hk_sin_wk = sum(weight_k .* h_k .* sin_phi_k .* w_k);
    sum_hk_cos = sum(weight_k .* h_k .* cos_phi_k);
    sum_hk_cos_wk2 = sum(weight_k .* h_k .* cos_phi_k .* w_k.^2);
    sum_weight = sum(weight_k);

    % System matrix (3×3)
    A_mat = [
        sum_hk2_wk2,        0,              sum_hk_sin_wk;
        0,                  sum_hk2,       -sum_hk_cos;
        sum_hk_sin_wk,     -sum_hk_cos,     sum_weight;
    ];

    % Right-hand side vector (3×1)
    y_vec = [
        0;
        sum_hk2_wk2;
       -sum_hk_cos_wk2;
    ];

    % Solve linear system: A_mat * x = y_vec
    x = A_mat \ y_vec;

    % Extract parameters
    a1 = x(1);
    a2 = x(2);
    b  = x(3);
end
