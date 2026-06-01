"""Full analysis with the real anchor positions.

ANCHORS:
  A1 = (2.20, 4.25)
  A2 = (0.00, 0.00)
  A3 = (3.54, 1.22)

Calibration in use during the runs: distanceOffset = -0.07 m for all anchors.
Logged d1/d2/d3 in the CSV are RAW (pre-offset).
The app trilaterated with (d - 0.07).
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd

BASE = Path(__file__).resolve().parent / "measures"
OFFSET = -0.07

ANCHORS = {
    1: np.array([2.20, 4.25]),
    2: np.array([0.00, 0.00]),
    3: np.array([3.54, 1.22]),
}

DATASETS = {
    "LOS  / normal  ": "los/los_normal.csv",
    "LOS  / weighted": "los/los_weighted.csv",
    "NLOS / normal  ": "nlos/nlos_normal.csv",
    "NLOS / weighted": "nlos/nlos_weighted.csv",
    "LOS  / weighted / A3-10cm": "los/los_weighted_a3m10.csv",
    "NLOS / weighted / A3-10cm": "nlos/nlos_weighted_a3m10.csv",
}


def err_stats(dx: np.ndarray, dy: np.ndarray) -> dict:
    e = np.hypot(dx, dy)
    return dict(n=len(e), mean=e.mean(), median=np.median(e),
                std=e.std(ddof=1), rms=np.sqrt((e**2).mean()),
                p95=np.percentile(e, 95), max=e.max(),
                bx=dx.mean(), by=dy.mean())


def fmt_pos(label, s):
    return (f"  {label:9s} n={s['n']:4d} "
            f"mean={s['mean']*100:6.2f}  median={s['median']*100:6.2f}  "
            f"rms={s['rms']*100:6.2f}  std={s['std']*100:5.2f}  "
            f"p95={s['p95']*100:6.2f}  max={s['max']*100:6.2f}  "
            f"bias=({s['bx']*100:+5.2f},{s['by']*100:+5.2f}) cm")


def main():
    print("=" * 110)
    print(f"UWB analysis  |  anchors A1={tuple(ANCHORS[1])}, A2={tuple(ANCHORS[2])}, "
          f"A3={tuple(ANCHORS[3])}  |  applied offset = {OFFSET:+.2f} m")
    print("=" * 110)

    summary = {}

    for label, rel in DATASETS.items():
        df = pd.read_csv(BASE / rel)
        true = np.array([df.true_x.iloc[0], df.true_y.iloc[0]])
        d_true = {aid: float(np.linalg.norm(true - ANCHORS[aid])) for aid in (1, 2, 3)}

        print(f"\n[{label}]  ground-truth=({true[0]:.3f}, {true[1]:.3f}) m  "
              f"HDOP={df.hdop.mean():.3f} ± {df.hdop.std(ddof=1):.3f}")

        # Per-anchor ranging stats (raw and calibrated)
        print(f"  {'anchor':6s} {'d_true':>7s} {'mean_raw':>9s} {'mean_cal':>9s} "
              f"{'std':>6s} {'bias_raw':>9s} {'bias_cal':>9s}")
        range_bias = {}
        for aid in (1, 2, 3):
            d_raw = df[f"d{aid}"]
            mean_raw = d_raw.mean()
            mean_cal = mean_raw + OFFSET
            std = d_raw.std(ddof=1)
            b_raw = (mean_raw - d_true[aid]) * 100
            b_cal = (mean_cal - d_true[aid]) * 100
            range_bias[aid] = b_cal
            print(f"  A{aid:<5d} {d_true[aid]:7.3f} {mean_raw:9.3f} {mean_cal:9.3f} "
                  f"{std*100:5.1f}cm  {b_raw:+7.2f}cm  {b_cal:+7.2f}cm")

        # Position error: computed (raw trilateration output) vs filtered (smoothed)
        raw_s = err_stats(df.computed_x - true[0], df.computed_y - true[1])
        flt_s = err_stats(df.filtered_x - true[0], df.filtered_y - true[1])
        print(fmt_pos("raw  pos", raw_s))
        print(fmt_pos("filtered", flt_s))

        summary[label] = dict(raw=raw_s, flt=flt_s, rb=range_bias, hdop=df.hdop.mean())

    # ---- comparison tables ----
    print("\n" + "=" * 110)
    print("Filtered position error (cm)")
    print("=" * 110)
    print(f"  {'condition':18s}  {'mean':>7s}  {'median':>7s}  {'rms':>7s}  "
          f"{'p95':>7s}  {'max':>7s}  {'bias_x':>8s}  {'bias_y':>8s}")
    for k, v in summary.items():
        s = v["flt"]
        print(f"  {k:18s}  {s['mean']*100:7.2f}  {s['median']*100:7.2f}  "
              f"{s['rms']*100:7.2f}  {s['p95']*100:7.2f}  {s['max']*100:7.2f}  "
              f"{s['bx']*100:+8.2f}  {s['by']*100:+8.2f}")

    print("\nEffect of weighting (filtered RMS)")
    for cond in ("LOS ", "NLOS"):
        n = summary[f"{cond} / normal  "]["flt"]["rms"]
        w = summary[f"{cond} / weighted"]["flt"]["rms"]
        print(f"  {cond}: normal={n*100:5.2f} cm  weighted={w*100:5.2f} cm "
              f"=> Δ={(w-n)*100:+.2f} cm  ({(w-n)/n*100:+.1f} %)")

    print("\nEffect of NLOS vs LOS (filtered RMS)")
    for v in ("normal  ", "weighted"):
        l = summary[f"LOS  / {v}"]["flt"]["rms"]
        n = summary[f"NLOS / {v}"]["flt"]["rms"]
        print(f"  {v}: LOS={l*100:5.2f} cm  NLOS={n*100:5.2f} cm "
              f"=> Δ={(n-l)*100:+.2f} cm  ({(n-l)/l*100:+.1f} %)")

    print("\nPer-anchor range bias AFTER -7 cm offset (cm)")
    print(f"  {'condition':18s}  {'A1':>7s}  {'A2':>7s}  {'A3':>7s}")
    for k, v in summary.items():
        rb = v["rb"]
        print(f"  {k:18s}  {rb[1]:+7.2f}  {rb[2]:+7.2f}  {rb[3]:+7.2f}")


if __name__ == "__main__":
    main()
