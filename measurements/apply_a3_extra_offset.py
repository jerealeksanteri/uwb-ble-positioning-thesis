"""Re-trilaterate with an extra -10 cm offset on A3 only.

Original offset (already applied in the iOS app data): -7 cm on all anchors.
This script applies an *additional* -10 cm to A3, so effective offsets become:
  A1: -7 cm, A2: -7 cm, A3: -17 cm.

Generates *_a3m10.csv next to the originals and prints the new error stats.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd

BASE = Path(__file__).resolve().parent / "measures"
BASE_OFFSET = -0.07            # already applied
EXTRA_A3    = -0.10            # additional offset for A3 only

ANCHORS = {1: np.array([2.20, 4.25]),
           2: np.array([0.00, 0.00]),
           3: np.array([3.54, 1.22])}


def trilaterate(d1, d2, d3, weighted: bool):
    pts = [ANCHORS[1], ANCHORS[2], ANCHORS[3]]
    ds  = [d1, d2, d3]
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


def moving_average(arr, win=5):
    """Mimic the iOS PositionFilter (mean of last `win` samples)."""
    out = np.empty_like(arr)
    for i in range(len(arr)):
        s = max(0, i - win + 1)
        out[i] = arr[s:i+1].mean(axis=0)
    return out


def err_stats(dx, dy):
    e = np.hypot(dx, dy)
    return dict(n=len(e), mean=e.mean(), median=np.median(e),
                std=e.std(ddof=1), rms=np.sqrt((e**2).mean()),
                p95=np.percentile(e, 95), max=e.max(),
                bx=dx.mean(), by=dy.mean())


SOURCES = ("los/los_normal.csv", "los/los_weighted.csv",
           "nlos/nlos_normal.csv", "nlos/nlos_weighted.csv")

print(f"{'condition':18s}  variant  {'mean':>6s}  {'median':>6s}  {'rms':>6s}  "
      f"{'p95':>6s}  {'max':>6s}  {'bias':>16s}  (cm)")

for rel in SOURCES:
    df = pd.read_csv(BASE / rel)
    weighted = "weighted" in rel
    true = np.array([df.true_x.iloc[0], df.true_y.iloc[0]])

    # New computed positions: take raw d_i, add base offset to all, add extra to A3
    new_xy = np.array([
        trilaterate(r.d1 + BASE_OFFSET,
                    r.d2 + BASE_OFFSET,
                    r.d3 + BASE_OFFSET + EXTRA_A3, weighted)
        for r in df.itertuples()
    ])
    new_filt = moving_average(new_xy, win=5)

    out = df.copy()
    out["computed_x"] = new_xy[:, 0]
    out["computed_y"] = new_xy[:, 1]
    out["filtered_x"] = new_filt[:, 0]
    out["filtered_y"] = new_filt[:, 1]

    new_path = (BASE / rel).with_name((BASE / rel).stem + "_a3m10.csv")
    out.to_csv(new_path, index=False)

    for label, arr in (("orig    ",
                        np.column_stack([df.filtered_x - true[0], df.filtered_y - true[1]])),
                       ("a3 -10cm",
                        np.column_stack([new_filt[:, 0] - true[0], new_filt[:, 1] - true[1]]))):
        s = err_stats(arr[:, 0], arr[:, 1])
        print(f"{rel:18s}  {label}  {s['mean']*100:6.2f}  {s['median']*100:6.2f}  "
              f"{s['rms']*100:6.2f}  {s['p95']*100:6.2f}  {s['max']*100:6.2f}  "
              f"({s['bx']*100:+5.2f},{s['by']*100:+5.2f})")
    print(f"   -> wrote {new_path.relative_to(BASE.parent)}")
