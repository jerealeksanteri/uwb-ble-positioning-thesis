# Calibration Procedure

## Why Calibrate?

UWB distance measurements have a systematic positive bias (typically +5 to +15 cm) caused by:

- **Antenna delay** — signal propagation time within the antenna and RF front-end
- **Reference point mismatch** — the physical measurement point differs from the electrical antenna phase center
- **Near-field effects** — the bias is larger at very short distances (< 1 m)

The calibration procedure determines a per-anchor offset that compensates for this bias.

## Overview

1. Measure each anchor at multiple known distances (0.5, 1, 2, 3, 4, 5 m)
2. Record 60 samples per distance using the app's Measure tab
3. Export CSVs to `measurements/anchor-calibration/`
4. Run `calibration.py` to compute mean error and suggested offset
5. Enter offsets in the app's Settings → Distance Calibration Offsets

## Step-by-Step Procedure

### 1. Prepare Measurement Setup

- Mount the anchor at a fixed position (e.g., on a table edge at known height)
- Mark distance points on the floor with tape (0.5, 1, 2, 3, 4, 5 m from anchor)
- Ensure clear line-of-sight between anchor and all measurement points

### 2. Measurement Reference Points

Measure the true distance between:
- **Anchor side:** top edge of the DWM3001 module (UWB antenna location)
- **iPhone side:** center of the phone's back surface

Consistency is key — use the same reference points for every measurement.

### 3. Record Samples

For each distance point:

1. Open the app → **Measure** tab → **Distance** mode
2. Select the anchor from the dropdown
3. Set the **True Distance** (meters)
4. Set **Samples** to 60
5. Stand at the marked point, hold the phone steady
6. Tap **Start Recording** — wait for 60 samples
7. Tap **Export CSV & Share** — save the file

### 4. Organize Files

Place exported CSVs in the repository:

```
measurements/anchor-calibration/
├── anchor1/
│   ├── uwb_distance_A1_0p5m_2026-05-16_143610.csv
│   ├── uwb_distance_A1_1p0m_2026-05-16_143939.csv
│   ├── uwb_distance_A1_2p0m_2026-05-16_144043.csv
│   ├── uwb_distance_A1_4p0m_2026-05-16_144251.csv
│   └── uwb_distance_A1_5p0m_2026-05-16_144352.csv
├── anchor2/
│   └── ...
└── anchor3/
    └── ...
```

File naming convention: `uwb_distance_A{id}_{dist}m_{date}_{time}.csv`

### 5. Run Analysis

```bash
python3 measurements/calibration.py
```

Output example:

```
============================================================
  ANCHOR1
============================================================

True (m)   Mean (m)   Error (m)   Error %   Std (m)   N
------------------------------------------------------
0.5        0.5057     +0.0057     +1.13     0.0177    60
1.0        1.0689     +0.0689     +6.89     0.0093    60
2.0        2.0703     +0.0703     +3.52     0.0118    60
4.0        4.0713     +0.0713     +1.78     0.0102    60
5.0        5.1530     +0.1530     +3.06     0.0122    60

  Overall mean error:  +0.0738 m
  Overall mean std:   0.0122 m
  Suggested offset:   -0.0738 m  (enter this in Settings)
```

### 6. Apply Offsets

Open the app → **Settings** tab → **Distance Calibration Offsets**:

- Enter the suggested offset for each anchor (negative value corrects positive bias)
- The offset is **added** to the measured distance in the trilateration pipeline

Example offsets (from actual measurements):
| Anchor | Suggested Offset |
|--------|-----------------|
| 1 | -0.074 m |
| 2 | -0.067 m |
| 3 | -0.066 m |

### 7. Verify

After applying offsets, observe the live distance readings in Settings — the "calibrated" column should be closer to the true distance than the "raw" column.

## Understanding the Results

### Mean Error

The average difference between measured and true distance. A positive mean error means the system reads too long (overestimates distance).

### Std Dev

Standard deviation of measurements at a single distance. This represents the **precision** (random noise) of the system — calibration offsets cannot reduce this. Typical values: 10-20 mm.

### Error %

Mean error as a percentage of true distance. Not constant — typically higher at short distances and relatively smaller at longer distances.

### Bias Pattern

If the bias:
- Is roughly **constant** across all distances → pure antenna delay offset
- **Grows with distance** → proportional bias (clock frequency error or multipath)
- Is **larger at short range** → near-field coupling effects

A single offset is a reasonable approximation when the bias is primarily constant (which is typical for LOS UWB ranging).

## Limitations

- The single-offset approach is a first-order correction. Residual error of a few cm may remain.
- Calibration is performed in LOS conditions. NLOS environments will introduce additional bias.
- The offset may change slightly if the anchor is remounted at a different angle.
- Temperature can affect UWB clock frequency and thus ranging bias (typically < 1 cm variation in indoor environments).
