# Project Conventions and Guidelines

**Flux Controller Simulation Framework**
**Version:** 2.0
**Last Updated:** 2025-10-16

---

## 📁 Directory Structure

```
Simulation/
├── controllers/        # Controller implementations (by type)
│   ├── type3/
│   ├── r_controller/
│   └── [future_types]/
│
├── scripts/           # Test and analysis scripts
│   ├── common/        # Shared utilities (all controllers)
│   ├── type3/         # Type 3 specific tests
│   ├── r_controller/  # R Controller specific tests
│   └── [future_types]/
│
├── test_results/      # Test outputs (organized by controller)
│   ├── type3/
│   ├── r_controller/
│   └── [future_types]/
│
└── reference/         # Reference implementations and docs
```

---

## 🏷️ Naming Conventions

### 1. Controller Directory Names

**Format:** `{controller_type}/`

**Rules:**
- Use lowercase with underscores for multi-word types
- Must match the controller implementation name
- Examples: `type3/`, `r_controller/`, `pid_cascaded/`

### 2. Simulink Model Files (.slx)

#### A. System Integration Model

**Format:** `{controller_type}_system_integrated.slx`

**Rules:**
- Lowercase with underscores
- Must contain complete closed-loop system
- Location: `controllers/{controller_type}/`
- Examples:
  - `type3_system_integrated.slx`
  - `r_controller_system_integrated.slx`
  - `pid_cascaded_system_integrated.slx`

#### B. Controller Subsystem Model

**Format:** `{controller_type}_controller.slx`

**Rules:**
- Lowercase with underscores
- Contains only the controller algorithm
- Location: `controllers/{controller_type}/`
- Examples:
  - `type3_controller.slx`
  - `r_controller_controller.slx`

### 3. MATLAB Functions (.m)

#### A. Controller Implementation Functions

**Format:** `{controller_type}_controller_function.m`

**Rules:**
- Lowercase with underscores
- Must match directory name
- Location: `controllers/{controller_type}/`
- Function signature: `function [u, e] = fcn(vd, vm)`
- Examples:
  - `type3_controller_function.m`
  - `r_controller_function.m`

**Required Header Format:**
```matlab
% {controller_type}_controller_function.m
% {Brief description of controller}
%
% Implementation of {description} controller algorithm
% Based on: {reference document, PDF page X}
%
% Inputs:
%   vd - Reference voltage (6×1) [V]
%   vm - Measured voltage (6×1) [V]
%
% Outputs:
%   u  - Control signal (6×1) [V]
%   e  - Tracking error (6×1) [V]
%
% Parameters:
%   lambda_c - {value} (control eigenvalue)
%   lambda_e - {value} (estimator eigenvalue)
%   Ts - 1e-5 s (100 kHz sampling)
%
% Author: {name}
% Date: {date}
```

#### B. Test Scripts

**Format:** `run_{controller_type}_test.m`

**Rules:**
- Lowercase with underscores
- Location: `scripts/{controller_type}/`
- Must start with configuration section
- Examples:
  - `run_type3_test.m`
  - `run_rcontroller_test.m`

**Required Configuration Section Format:**
```matlab
%% ═══════════════════════════════════════════════════════════════
%                     SECTION 1: 配置區域
%  ═══════════════════════════════════════════════════════════════

% Test Identification
test_name = '{controller_type}_{SignalType}_{Params}';

% Reference Input Configuration
signal_type = 'sine';     % 'step' or 'sine'
active_channel = 1;       % 1-6 (P1-P6)
amplitude = 0.5;          % [V]

% Sine Wave Parameters
sine_frequency = 500;     % [Hz]
sine_phase = 0;           % [deg]

% Simulation Configuration
Ts = 1e-5;               % Sample time [s] (100 kHz)
solver = 'ode23tb';      % Simulink solver

% Model Configuration
model_name = '{controller_type}_system_integrated';
```

#### C. Common Utility Functions

**Format:** `{verb}_{function_purpose}.m`

**Rules:**
- Lowercase with underscores
- Location: `scripts/common/`
- Controller-agnostic (works for any controller type)
- Examples:
  - `configure_sine_wave.m`
  - `verify_sine_wave_setup.m`
  - `analyze_frequency_response.m`

### 4. Test Result Directories

**Format:** `test_results/{controller_type}/{test_name}_{timestamp}/`

**Rules:**

#### A. Controller Type Subdirectory
- Lowercase, matches controller directory name
- Examples: `type3/`, `r_controller/`

#### B. Test Run Directory

**Format:** `{TestName}_{YYYYMMDD_HHMMSS}/`

**Test Name Format:** `{Channel}_{SignalType}_{FreqOrParams}[_OptionalDesc]`

**Components:**
- **Channel:** `P1` to `P6` (active channel)
- **SignalType:** `Sine`, `Step`, `Sweep`, etc.
- **FreqOrParams:**
  - For Sine: frequency in Hz (e.g., `500H`, `10H`, `1kH`)
  - For Step: amplitude or descriptor (e.g., `0.5V`, `unit`)
- **OptionalDesc:** Additional test parameters (e.g., `fb1`, `w0.5`, `e2e4`)
- **Timestamp:** `YYYYMMDD_HHMMSS` format (auto-generated)

**Examples:**
```
test_results/type3/P5_Sine_500H_20251016_120000/
test_results/type3/P5_Sine_500H_test_fb1_w0.5_20251016_121500/
test_results/type3/P3_Step_0.1V_20251016_130000/
test_results/r_controller/P1_Sine_100H_20251016_140000/
test_results/r_controller/P2_Sweep_1to1000H_20251016_150000/
```

#### C. Required Output Files

Each test directory must contain:

```
{test_name}_{timestamp}/
├── result.mat                # MATLAB data file (v7.3 format)
├── 6ch_time_domain.png       # 6-channel time-domain plot
├── full_response.png         # Complete system response
└── lissajous_curves.png      # Lissajous diagram (Vm vs Vd)
```

**result.mat Structure:**
```matlab
result
├── .config              % Test configuration
│   ├── .test_name
│   ├── .signal_type
│   ├── .active_channel
│   ├── .amplitude
│   ├── .sim_time
│   ├── .Ts
│   └── [signal-specific params]
│
├── .data                % Time series data
│   ├── .t               % Time vector (N×1)
│   ├── .Vd              % Reference voltage (N×6)
│   ├── .Vm              % Measured voltage (N×6)
│   ├── .e               % Error (N×6)
│   └── .u               % Control signal (N×6)
│
├── .display             % Display window data (Sine only)
│   ├── .t
│   ├── .Vd
│   └── .Vm
│
├── .analysis            % Analysis results (Sine only)
│   ├── .phase_deg       % Phase difference [°] (6×1)
│   ├── .gain_dB         % Gain [dB] (6×1)
│   ├── .freq_error_Hz   % Frequency error [Hz] (6×1)
│   └── .freq_resolution_Hz
│
└── .meta                % Metadata
    ├── .timestamp       % Human-readable timestamp
    └── .elapsed_time    % Simulation duration [s]
```

---

## 🔧 Path Resolution Standards

### 1. Script-to-Model Path Resolution

**Standard Pattern (for scripts in `scripts/{controller_type}/`):**

```matlab
% Get script directory
script_dir = fileparts(mfilename('fullpath'));
% Result: C:\...\Simulation\scripts\{controller_type}

% Navigate to scripts root
scripts_root = fullfile(script_dir, '..');
% Result: C:\...\Simulation\scripts

% Navigate to project root
project_root = fullfile(scripts_root, '..');
% Result: C:\...\Simulation

% Build model path
model_path = fullfile(project_root, 'controllers', '{controller_type}', ...
                      [model_name '.slx']);
% Result: C:\...\Simulation\controllers\{controller_type}\{Model}.slx
```

### 2. Output Directory Path Resolution

**Standard Pattern:**

```matlab
% Set output directory
output_base = 'test_results';
controller_type = '{controller_type}';  % e.g., 'type3', 'r_controller'

% Build output path
output_dir = fullfile(project_root, output_base, controller_type);
% Result: C:\...\Simulation\test_results\{controller_type}

% Create test directory with timestamp
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
test_dir = fullfile(output_dir, sprintf('%s_%s', test_name, timestamp));
mkdir(test_dir);
```

### 3. Common Utilities Path Resolution

**Standard Pattern (for accessing scripts/common/ from controller scripts):**

```matlab
% Add common utilities to path
common_dir = fullfile(scripts_root, 'common');
addpath(common_dir);

% Now you can call common functions directly
configure_sine_wave(model_name, signal_type, ...);
verify_sine_wave_setup(model_name);
[mag_dB, phase_deg, bw] = analyze_frequency_response(Vd, Vm, f, Fs);
```

**IMPORTANT:** Always add common/ to path at the start of controller-specific scripts.

---

## 📊 Model Configuration Standards

### 1. Required Simulink Blocks

All system integration models must contain:

**Input Signal Blocks:**
- `Vd_Sine` - 6-channel sine wave generator
- `Vd_Step` - 6-channel step generator
- `Vd_Switch` - Multiport switch for signal selection
- `Signal_Selector` - Channel activation control

**Controller Interface:**
- MATLAB Function block with signature: `function [u, e] = fcn(vd, vm)`
- Reference to controller function in `controllers/{controller_type}/`

**System Blocks:**
- Plant/System (6×6 MIMO transfer function)
- DAC (Zero-Order Hold @ 100 kHz)
- ADC (Zero-Order Hold @ 100 kHz)

**Logging:**
- To Workspace blocks for: `Vd`, `Vm`, `e`, `u`, `tout`
- Scope blocks for real-time monitoring

### 2. Model Parameters

**Solver Configuration:**
```
Solver: ode23tb (stiff/TR-BDF2)
MaxStep: 1e-5 (= Ts)
StopTime: [configured by script]
```

**Data Logging:**
```
Format: Structure with time
Decimation: 1 (no downsampling)
```

---

## 🎨 Plotting Standards

### 1. Channel Color Scheme (Fixed)

```matlab
colors = [
    0.0000, 0.4470, 0.7410;  % P1: Blue
    0.8500, 0.3250, 0.0980;  % P2: Red
    0.9290, 0.6940, 0.1250;  % P3: Yellow
    0.4660, 0.6740, 0.1880;  % P4: Green
    0.4940, 0.1840, 0.5560;  % P5: Magenta
    0.3010, 0.7450, 0.9330;  % P6: Cyan
];
```

**Must be consistent across all controllers.**

### 2. Active Channel Highlighting

**Rules:**
- Active (excited) channel: LineWidth = 2.5
- Inactive channels: LineWidth = 1.5
- Subplot for active channel: Red border (LineWidth = 2.5)

### 3. Figure Naming

**Format:**
```
Figure 1: Lissajous Curves - {test_name}
Figure 2: Time Domain - 6 Channels - {test_name}
Figure 3: Full Time Response - {test_name}
```

### 4. Plot Export Settings

**PNG Export:**
```matlab
saveas(fig, fullfile(test_dir, '{plot_name}.png'));
```

**Resolution:** Default MATLAB figure resolution (sufficient for documentation)

---

## ⚙️ Controller-Specific Parameters

### Type 3 Controller

**File:** `controllers/type3/type3_controller_function.m`

**Parameters:**
```matlab
lambda_c = 0.9391    % Control eigenvalue
lambda_e = 0.7304    % Estimator eigenvalue
a1 = 1.595052025060797
a2 = -0.599079946700523
Ts = 1e-5           % 100 kHz sampling
```

**Control Law:**
```
u[k] = B^(-1) {vff + δvfb - ŵT}
```

**Reference:** Flux_Control_B_oldmodel_merged.pdf, Page 3

---

### R Controller

**File:** `controllers/r_controller/r_controller_function.m`

**Parameters:**
```matlab
lambda_c = 0.8179    % Control eigenvalue
lambda_e = 0.3659    % Estimator eigenvalue
k_o = 5.6695e-4
b = 0.9782
a1 = 1.934848
a2 = -0.935970
Ts = 1e-5           % 100 kHz sampling
```

**Control Law:**
```
[Complex R-based formulation with multi-buffer state management]
```

**Reference:** Flux_Control_R_newmodel.pdf, Page 1

---

## 📝 Documentation Requirements

### 1. README Files

Each controller type must have:

**Location:** `scripts/{controller_type}/README.md`

**Required Sections:**
```markdown
# {Controller Type} Test Scripts

## Quick Start
[How to run a basic test]

## Available Scripts
[List of scripts and their purposes]

## Configuration
[Key parameters and how to modify them]

## Examples
[Example test configurations]

## Troubleshooting
[Common issues and solutions]
```

### 2. Function Documentation

All MATLAB functions must include:
- Purpose description
- Input/output specifications
- Parameter documentation
- Usage examples
- Author and date

---

## 🔍 Quality Standards

### 1. Before Committing

**Checklist:**
- [ ] All paths use relative resolution (no hardcoded absolute paths)
- [ ] Test script runs successfully from any working directory
- [ ] Output files saved to correct `test_results/{controller_type}/` location
- [ ] Model names match naming conventions
- [ ] Function headers complete and accurate
- [ ] No commented-out debug code
- [ ] Git status clean (no untracked cache files)

### 2. Test Validation

**Required Tests Before Commit:**
```matlab
% Test 1: Sine wave (default frequency)
test_name = '{controller_type}_Sine_500H_validation';
signal_type = 'sine';
sine_frequency = 500;
% Expected: Clean Lissajous, phase < 10°

% Test 2: Step response
test_name = '{controller_type}_Step_validation';
signal_type = 'step';
amplitude = 0.1;
% Expected: Settling time < 0.1s, overshoot < 5%
```

### 3. File Organization

**Prohibited:**
- Loose .slx files in project root
- Test results in script directories
- Backup files (*.asv, *_backup.m, *_old.slx)
- Temporary debug scripts
- Hardcoded absolute paths

**Required:**
- All models in `controllers/{type}/`
- All test scripts in `scripts/{type}/` or `scripts/common/`
- All test results in `test_results/{type}/`
- Common utilities in `scripts/common/`

---

## 🚀 Adding a New Controller Type

### Step-by-Step Process

1. **Create Directory Structure**
   ```bash
   mkdir controllers\{new_type}
   mkdir scripts\{new_type}
   mkdir test_results\{new_type}
   ```

2. **Create Controller Function**
   - File: `controllers/{new_type}/{new_type}_controller_function.m`
   - Implement with signature: `function [u, e] = fcn(vd, vm)`
   - Add required header documentation

3. **Create Simulink Models**
   - Copy and modify from existing controller type
   - Rename to: `{new_type}_system_integrated.slx`
   - Rename controller: `{new_type}_controller.slx`
   - Update MATLAB Function block to call new controller function

4. **Create Test Script**
   - Copy `run_type3_test.m` as template
   - Rename to: `run_{new_type}_test.m`
   - Update model_name to new model
   - Update output directory to `test_results/{new_type}`
   - Update test_name prefix

5. **Create Documentation**
   - File: `scripts/{new_type}/README.md`
   - Document controller-specific parameters
   - Provide usage examples

6. **Run Validation Tests**
   - Execute sine wave test (500 Hz)
   - Execute step response test
   - Verify output files in correct location

7. **Update Main README**
   - Add controller type to list
   - Update project structure diagram
   - Add quick start instructions

8. **Commit**
   ```bash
   git add controllers/{new_type}
   git add scripts/{new_type}
   git commit -m "feat: Add {new_type} controller implementation"
   ```

---

## 📖 Reference

### Key Files

| File | Purpose |
|------|---------|
| `PROJECT_CONVENTIONS.md` | This file - naming and organization rules |
| `README.md` | Project overview and quick start |
| `reference/README.md` | Reference implementation documentation |

### External References

- **Type 3 Controller:** `reference/Flux_Control_B_oldmodel_merged.pdf`
- **R Controller:** `reference/Flux_Control_R_newmodel.pdf`
- **System Identification:** `reference/Model_6_6_Continuous_Weighted.m`

---

## ⚠️ Important Notes

1. **Never modify** files in `scripts/common/` for controller-specific needs
2. **Always test** path resolution after moving scripts
3. **Always commit** with descriptive messages following conventional commits
4. **Never commit** Simulink cache files (slprj/, *.autosave)
5. **Always check** git status before committing

---

**Last Review:** 2025-10-16
**Maintained by:** Project Team
**Version:** 2.0
