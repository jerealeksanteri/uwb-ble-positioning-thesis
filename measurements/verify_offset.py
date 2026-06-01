"""Verify which offset was actually applied, using the real anchor positions."""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd

BASE = Path(__file__).resolve().parent / "measures"

ANCHORS = {
    1: np.array([2.20, 4.25]),
    2: np.array([0.00, 0.00]),
    3: np.array([3.54, 1.22]),
}


def trilaterate(d1, d2, d3, weighted: bool):
    pts = [ANCHORS[1], ANCHORS[2], ANCHORS[3]]
    ds = [d1, d2, d3]
    x1, y1 = pts[0]; dd1 = ds[0]
    A = np.zeros((2, 2)); b = np.zeros(2); w = np.ones(2)
    for i in (1, 2):
        xi, yi = pts[i]; di = ds[i]
        A[i-1] = [2 * (xi - x1), 2 * (yi - y1)]
        b[i-1] = (dd1**2 - di**2) - (x1**2 - xi**2) - (y1**2 - yi**2)
        if weighted:
            w[i-1] = 1.0 / max(di, 0.01) ** 2
    if weighted:
        W = np.diag(w)
        sol = np.linalg.solve(A.T @ W @ A, A.T @ W @ b)
    else:
        sol = np.linalg.solve(A, b)
    return float(sol[0]), float(sol[1])


for name in ("los/los_normal.csv", "los/los_weighted.csv",
             "nlos/nlos_normal.csv", "nlos/nlos_weighted.csv"):
    df = pd.read_csv(BASE / name)
    weighted = "weighted" in name
    logged = df[["computed_x", "computed_y"]].to_numpy()
    print(f"\n=== {name} ===")
    true = np.array([df.true_x.iloc[0], df.true_y.iloc[0]])
    for aid in (1, 2, 3):
        d_true = float(np.linalg.norm(true - ANCHORS[aid]))
        d_mean = df[f"d{aid}"].mean()
        print(f"     A{aid}: d_true={d_true:.3f} m,  "
              f"d_meas_mean={d_mean:.3f} m,  raw bias={(d_mean-d_true)*100:+.2f} cm,  "
              f"after -7cm: {(d_mean-0.07-d_true)*100:+.2f} cm")
    for off in (0.0, -0.07):
        pred = np.array([
            trilaterate(r.d1 + off, r.d2 + off, r.d3 + off, weighted)
            for r in df.itertuples()
        ])
        err = np.linalg.norm(pred - logged, axis=1)
        print(f"  replay off={off:+.2f}  |pred-logged|: "
              f"mean={err.mean()*1000:.2f} mm  max={err.max()*1000:.2f} mm")
