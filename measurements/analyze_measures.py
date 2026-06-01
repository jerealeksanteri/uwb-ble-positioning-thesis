"""Analyze LOS / NLOS positioning measurements.

For each of the four datasets (LOS/NLOS x normal/weighted trilateration),
compute error statistics for both the raw computed position and the
filtered position relative to the ground-truth (true_x, true_y).
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


BASE = Path(__file__).resolve().parent / "measures"

DATASETS = {
    "LOS  / normal  ": BASE / "los"  / "los_normal.csv",
    "LOS  / weighted": BASE / "los"  / "los_weighted.csv",
    "NLOS / normal  ": BASE / "nlos" / "nlos_normal.csv",
    "NLOS / weighted": BASE / "nlos" / "nlos_weighted.csv",
}


def err_stats(dx: np.ndarray, dy: np.ndarray) -> dict:
    err = np.hypot(dx, dy)
    return {
        "n":      len(err),
        "mean":   float(err.mean()),
        "median": float(np.median(err)),
        "std":    float(err.std(ddof=1)),
        "rms":    float(np.sqrt(np.mean(err ** 2))),
        "p95":    float(np.percentile(err, 95)),
        "max":    float(err.max()),
        "bias_x": float(dx.mean()),
        "bias_y": float(dy.mean()),
    }


def analyze(path: Path) -> dict:
    df = pd.read_csv(path)
    raw = err_stats(df.computed_x - df.true_x, df.computed_y - df.true_y)
    flt = err_stats(df.filtered_x - df.true_x, df.filtered_y - df.true_y)
    return {
        "raw": raw,
        "filtered": flt,
        "hdop_mean": float(df.hdop.mean()),
        "hdop_std":  float(df.hdop.std(ddof=1)),
        "d_mean":    [float(df.d1.mean()), float(df.d2.mean()), float(df.d3.mean())],
        "d_std":     [float(df.d1.std(ddof=1)), float(df.d2.std(ddof=1)), float(df.d3.std(ddof=1))],
        "true":      (float(df.true_x.iloc[0]), float(df.true_y.iloc[0])),
    }


def fmt_row(label: str, s: dict) -> str:
    return (f"  {label:8s}  n={s['n']:4d}  "
            f"mean={s['mean']*100:6.2f} cm  "
            f"median={s['median']*100:6.2f} cm  "
            f"rms={s['rms']*100:6.2f} cm  "
            f"std={s['std']*100:6.2f} cm  "
            f"p95={s['p95']*100:6.2f} cm  "
            f"max={s['max']*100:6.2f} cm  "
            f"bias=({s['bias_x']*100:+5.2f},{s['bias_y']*100:+5.2f}) cm")


def main() -> None:
    results = {name: analyze(p) for name, p in DATASETS.items()}

    print("=" * 100)
    print("UWB positioning measurement analysis")
    print("=" * 100)
    for name, r in results.items():
        tx, ty = r["true"]
        print(f"\n[{name}]  ground-truth=({tx:.3f}, {ty:.3f}) m  "
              f"HDOP={r['hdop_mean']:.3f} ± {r['hdop_std']:.3f}")
        print(f"  ranges (m): "
              + ", ".join(f"d{i+1}={m:.3f}±{s:.3f}"
                         for i, (m, s) in enumerate(zip(r["d_mean"], r["d_std"]))))
        print(fmt_row("raw",      r["raw"]))
        print(fmt_row("filtered", r["filtered"]))

    # Summary comparison: filtered error per condition
    print("\n" + "=" * 100)
    print("Summary (filtered position error, cm)")
    print("=" * 100)
    print(f"{'condition':18s}  {'mean':>8s}  {'median':>8s}  {'rms':>8s}  {'p95':>8s}")
    for name, r in results.items():
        s = r["filtered"]
        print(f"{name:18s}  {s['mean']*100:8.2f}  {s['median']*100:8.2f}  "
              f"{s['rms']*100:8.2f}  {s['p95']*100:8.2f}")

    # Relative comparison: weighted vs normal, NLOS vs LOS
    print("\n" + "=" * 100)
    print("Effect of weighted least squares (filtered RMS)")
    print("=" * 100)
    for cond in ("LOS", "NLOS"):
        n = results[f"{cond:4s} / normal  "]["filtered"]["rms"]
        w = results[f"{cond:4s} / weighted"]["filtered"]["rms"]
        delta = (w - n) / n * 100.0
        print(f"  {cond:4s}: normal RMS = {n*100:6.2f} cm, weighted RMS = {w*100:6.2f} cm "
              f"=> {delta:+.1f} %")

    print("\nEffect of NLOS vs LOS (filtered RMS)")
    print("-" * 100)
    for variant in ("normal  ", "weighted"):
        los  = results[f"LOS  / {variant}"]["filtered"]["rms"]
        nlos = results[f"NLOS / {variant}"]["filtered"]["rms"]
        delta = (nlos - los) / los * 100.0
        print(f"  {variant}: LOS = {los*100:6.2f} cm, NLOS = {nlos*100:6.2f} cm "
              f"=> {delta:+.1f} %")


if __name__ == "__main__":
    main()
