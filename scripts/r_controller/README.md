# R Controller Test Scripts

**Status:** 🚧 **In Development** - Skeleton created, Simulink models pending

R-based flux controller implementation following `Flux_Control_R_newmodel.pdf` (Page 1).

---

## 📁 Directory Contents

```
scripts/r_controller/
├── run_rcontroller_test.m         ✅ Test script (ready)
└── README.md                      ✅ This file
```

---

## ⚠️ Setup Required

To use this controller, you need to create the Simulink model files:

### Required Files

1. **`controllers/r_controller/r_controller_system_integrated.slx`**
   - Copy from: `controllers/type3/type3_system_integrated.slx`
   - Modify MATLAB Function block to call `r_controller_function.m`

2. **`controllers/r_controller/r_controller_controller.slx`**
   - Copy from: `controllers/type3/type3_controller.slx`
   - Update controller implementation

### Quick Setup Steps

```bash
# From project root
cd controllers/r_controller

# Copy Type3 models as templates (use File Explorer or MATLAB)
# Then open in Simulink and update the MATLAB Function block reference
```

**In Simulink:**
1. Open `r_controller_system_integrated.slx`
2. Find the MATLAB Function block (controller)
3. Update function name to: `r_controller_function`
4. Save model

---

## 🎯 Controller Parameters

**File:** `controllers/r_controller/r_controller_function.m` ✅ (Already exists)

### Key Parameters
```matlab
lambda_c = 0.8179    % Control eigenvalue
lambda_e = 0.3659    % Estimator eigenvalue
k_o = 5.6695e-4
b = 0.9782
a1 = 1.934848
a2 = -0.935970
Ts = 1e-5           % 100 kHz sampling
```

### Control Law
Complex R-based formulation with multi-buffer state management.

**Reference:** `reference/Flux_Control_R_newmodel.pdf`, Page 1

---

## 🚀 Quick Start (Once Models Created)

### 1. Basic Sine Wave Test

```matlab
cd scripts/r_controller
edit run_rcontroller_test

% Configure (lines 29-40):
test_name = 'r_controller_P5_Sine_500H_test';
signal_type = 'sine';
active_channel = 5;
amplitude = 0.5;
sine_frequency = 500;

% Run
run_rcontroller_test
```

### 2. Step Response Test

```matlab
% Configure:
test_name = 'r_controller_P3_Step_0.1V';
signal_type = 'step';
active_channel = 3;
amplitude = 0.1;

% Run
run_rcontroller_test
```

### 3. Frequency Sweep

Use `scripts/common/analyze_frequency_response.m` for Bode plot generation.

---

## 📊 Output Structure

Test results saved to: `test_results/r_controller/{test_name}_{timestamp}/`

Each test folder contains:
- **result.mat** - Full simulation data
- **6ch_time_domain.png** - 6-channel time-domain response
- **lissajous_curves.png** - Lissajous diagram (Vm vs Vd)
- **full_response.png** - Complete system response

---

## 🔧 Configuration Options

Edit `run_rcontroller_test.m` (Section 1: Configuration):

### Signal Configuration
```matlab
signal_type = 'sine'           % 'step' or 'sine'
active_channel = 5             % 1-6 (P1-P6)
amplitude = 0.5                % [V]
sine_frequency = 500           % [Hz]
sine_phase = 0                 % [deg]
```

### Simulation Configuration
```matlab
step_sim_time = 1.0            % Step simulation time [s]
sine_min_cycles = 30           % Minimum cycles for sine
sine_skip_cycles = 20          % Skip transient cycles
sine_display_cycles = 5        % Display steady-state cycles
Ts = 1e-5                      % 100 kHz sampling
solver = 'ode23tb'             % Stiff solver
```

### Output Control
```matlab
ENABLE_PLOT = true             % Show plots
SAVE_PNG = true                % Save PNG images
SAVE_MAT = true                % Save .mat data
```

---

## 📈 Expected Performance

Once models are created and tested:

### Sine Wave Response (500 Hz)
- Phase lag: Expected < -10°
- Gain: Expected ~0 dB (good tracking)
- Settling time: < 0.1 s

### Step Response
- Overshoot: Target < 5%
- Settling time (2%): Target < 0.1 s
- Steady-state error: < 1e-4 V

---

## 🐛 Troubleshooting

### Error: "Cannot find model file"
**Cause:** Simulink models not created yet
**Solution:** Follow setup steps above to create model files

### Error: "Undefined function 'r_controller_function'"
**Cause:** MATLAB Function block not updated
**Solution:** Open model, update function name in MATLAB Function block

### Error: "Signal configuration failed"
**Cause:** Model blocks don't match expected structure
**Solution:** Ensure Vd_Sine, Vd_Switch, Signal_Selector blocks exist

### Dimension mismatch errors
**Cause:** Input/output dimensions incorrect
**Solution:** Check r_controller_function.m outputs [u (6×1), e (6×1)]

---

## 📚 Related Files

- **Controller Function:** `controllers/r_controller/r_controller_function.m`
- **Reference Document:** `reference/Flux_Control_R_newmodel.pdf`
- **Common Utilities:** `scripts/common/`
  - `configure_sine_wave.m`
  - `verify_sine_wave_setup.m`
  - `analyze_frequency_response.m`
- **Project Conventions:** `PROJECT_CONVENTIONS.md`

---

## 📝 Development Checklist

- [x] Controller function implemented (`r_controller_function.m`)
- [x] Test script created (`run_rcontroller_test.m`)
- [x] Directory structure established
- [ ] System integration model created (`.slx`)
- [ ] Controller subsystem model created (`.slx`)
- [ ] Initial validation test completed
- [ ] Frequency response characterized
- [ ] Performance documented

---

## 🔄 Next Steps

1. **Create Simulink Models**
   - Copy type3 models as templates
   - Update MATLAB Function blocks
   - Test model compilation

2. **Run Validation Tests**
   - Execute `run_rcontroller_test` with default config
   - Verify output in `test_results/r_controller/`
   - Compare with Type3 performance

3. **Characterize Performance**
   - Run frequency sweep (10 Hz - 1 kHz)
   - Generate Bode plots
   - Document bandwidth and phase margin

4. **Optimize Parameters**
   - Tune lambda_c and lambda_e if needed
   - Compare with theoretical predictions
   - Update controller function if necessary

---

## 📖 Additional Resources

- **Main Project README:** `../../README.md`
- **Naming Conventions:** `../../PROJECT_CONVENTIONS.md`
- **Type3 Example:** `../type3/` (reference implementation)

---

**Last Updated:** 2025-10-16
**Status:** Skeleton complete, awaiting Simulink model creation
**Maintainer:** Project Team
