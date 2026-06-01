"""If the calibration (-7 cm per anchor) is correct, fit a tag position to the
calibrated mean ranges and see what residuals remain."""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd


def least_squares_nd(fun, x0, args=(), n_iter=200, lr=0.3):
    """Tiny Gauss-Newton with numerical jacobian (no scipy)."""
    x = np.array(x0, dtype=float)
    for _ in range(n_iter):
        r = fun(x, *args)
        J = np.zeros((len(r), len(x)))
        eps = 1e-6
        for k in range(len(x)):
            xp = x.copy(); xp[k] += eps
            J[:, k] = (fun(xp, *args) - r) / eps
        try:
            dx = np.linalg.lstsq(J, -r, rcond=None)[0]
        except np.linalg.LinAlgError:
            break
        x = x + lr * dx
        if np.linalg.norm(dx) < 1e-9:
            break
    class R: pass
    out = R(); out.x = x
    return out

BASE = Path(__file__).resolve().parent / "measures"
OFFSET = -0.07
ANCHORS = np.array([[2.20, 4.25], [0.00, 0.00], [3.54, 1.22]])  # A1, A2, A3
MARKED_TAG = np.array([1.580, 1.820])

def residuals(p, d):
    return np.linalg.norm(ANCHORS - p, axis=1) - d

for name in ("los/los_normal.csv", "los/los_weighted.csv",
             "nlos/nlos_normal.csv", "nlos/nlos_weighted.csv"):
    df = pd.read_csv(BASE / name)
    d_cal = np.array([df.d1.mean(), df.d2.mean(), df.d3.mean()]) + OFFSET
    d_true_marked = np.linalg.norm(ANCHORS - MARKED_TAG, axis=1)

    # Fit tag position that best explains calibrated ranges
    sol = least_squares_nd(residuals, MARKED_TAG, args=(d_cal,))
    fit_pos = sol.x
    fit_res = residuals(fit_pos, d_cal)
    marked_res = d_cal - d_true_marked

    # Also fit (tx, ty, common_bias) — does a uniform extra bias explain it?
    def res2(p, d):
        return np.linalg.norm(ANCHORS - p[:2], axis=1) - (d - p[2])
    sol2 = least_squares_nd(res2, [MARKED_TAG[0], MARKED_TAG[1], 0.0], args=(d_cal,))
    fit2_pos, fit2_bias = sol2.x[:2], sol2.x[2]
    fit2_res = res2(sol2.x, d_cal)

    print(f"\n=== {name} ===")
    print(f"  Marked tag pos:        ({MARKED_TAG[0]:.3f}, {MARKED_TAG[1]:.3f}) m")
    print(f"  d_true (from marked):  A1={d_true_marked[0]:.3f}  A2={d_true_marked[1]:.3f}  A3={d_true_marked[2]:.3f}")
    print(f"  d_calibrated (meas):   A1={d_cal[0]:.3f}  A2={d_cal[1]:.3f}  A3={d_cal[2]:.3f}")
    print(f"  Residual at marked:    A1={marked_res[0]*100:+6.2f}  A2={marked_res[1]*100:+6.2f}  A3={marked_res[2]*100:+6.2f} cm")
    print(f"  Best-fit tag (free):   ({fit_pos[0]:.3f}, {fit_pos[1]:.3f})  "
          f"shift from marked = ({(fit_pos[0]-MARKED_TAG[0])*100:+.1f}, {(fit_pos[1]-MARKED_TAG[1])*100:+.1f}) cm")
    print(f"  Residuals at fit:      A1={fit_res[0]*100:+6.2f}  A2={fit_res[1]*100:+6.2f}  A3={fit_res[2]*100:+6.2f} cm")
    print(f"  Best-fit (pos+bias):   pos=({fit2_pos[0]:.3f}, {fit2_pos[1]:.3f})  extra_bias={fit2_bias*100:+.2f} cm")
    print(f"  Residuals at fit2:     A1={fit2_res[0]*100:+6.2f}  A2={fit2_res[1]*100:+6.2f}  A3={fit2_res[2]*100:+6.2f} cm")
