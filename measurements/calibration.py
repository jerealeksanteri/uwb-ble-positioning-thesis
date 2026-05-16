"""
Anchor calibration analysis.

Reads CSV files from measurements/anchor-calibration/anchor1/, anchor2/, anchor3/
and computes mean error, error %, std dev, and suggested offset per anchor.
"""

import os
import glob
import pandas as pd
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CALIBRATION_DIR = os.path.join(SCRIPT_DIR, "anchor-calibration")


def analyze_anchor(anchor_dir: str) -> pd.DataFrame | None:
    """Analyze all CSV files for one anchor, returning per-distance statistics."""
    csv_files = glob.glob(os.path.join(anchor_dir, "*.csv"))
    if not csv_files:
        return None

    records = []
    for f in csv_files:
        df = pd.read_csv(f)
        true_dist = df["true_distance"].iloc[0]
        measured = df["measured_distance"]
        errors = measured - true_dist

        records.append({
            "true_distance": true_dist,
            "n_samples": len(df),
            "mean_measured": measured.mean(),
            "mean_error": errors.mean(),
            "error_pct": (errors.mean() / true_dist) * 100,
            "std_dev": measured.std(),
            "min": measured.min(),
            "max": measured.max(),
        })

    stats = pd.DataFrame(records).sort_values("true_distance").reset_index(drop=True)
    return stats


def suggest_offset(stats: pd.DataFrame) -> float:
    """
    Suggest a single calibration offset (to subtract from measured distance).

    Uses the mean of all per-distance mean errors, giving equal weight to each distance.
    The offset should be NEGATED when entering into the app (app adds offset to measured).
    """
    return -stats["mean_error"].mean()


def main():
    anchor_dirs = sorted(glob.glob(os.path.join(CALIBRATION_DIR, "anchor*")))

    if not anchor_dirs:
        print(f"No anchor directories found in {CALIBRATION_DIR}")
        return

    for anchor_dir in anchor_dirs:
        anchor_name = os.path.basename(anchor_dir)
        print(f"\n{'='*60}")
        print(f"  {anchor_name.upper()}")
        print(f"{'='*60}")

        stats = analyze_anchor(anchor_dir)
        if stats is None:
            print("  No CSV files found.")
            continue

        # Per-distance table
        print(f"\n{'True (m)':<10} {'Mean (m)':<10} {'Error (m)':<11} {'Error %':<9} {'Std (m)':<9} {'N':<5}")
        print("-" * 54)
        for _, row in stats.iterrows():
            print(
                f"{row['true_distance']:<10.1f} "
                f"{row['mean_measured']:<10.4f} "
                f"{row['mean_error']:+<11.4f} "
                f"{row['error_pct']:+<9.2f} "
                f"{row['std_dev']:<9.4f} "
                f"{int(row['n_samples']):<5}"
            )

        # Summary
        offset = suggest_offset(stats)
        overall_mean_error = stats["mean_error"].mean()
        overall_std = stats["std_dev"].mean()

        print(f"\n  Overall mean error:  {overall_mean_error:+.4f} m")
        print(f"  Overall mean std:   {overall_std:.4f} m")
        print(f"  Suggested offset:   {offset:+.4f} m  (enter this in Settings)")


if __name__ == "__main__":
    main()
