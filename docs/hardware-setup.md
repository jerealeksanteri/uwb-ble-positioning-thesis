# Hardware Setup

## Components

| Component | Quantity | Role |
|-----------|----------|------|
| Qorvo DWM3001CDK | 3 | UWB anchors (fixed reference points) |
| iPhone 16 Pro Max | 1 | Mobile tag (computes own position) |
| USB-A to USB-C cables | 3 | Power supply for anchors |
| Tape measure | 1 | Measuring anchor positions |

### DWM3001CDK Board

The DWM3001CDK is a development kit combining:
- **nRF52833** — Cortex-M4F MCU with BLE (SoftDevice S140)
- **DW3110** — Qorvo UWB transceiver (IEEE 802.15.4z)
- **On-board J-Link OB** — for programming and debug (USB)
- **LEDs** — status indication
- **Buttons** — reset

The UWB antenna is a PCB antenna located at the top edge of the DWM3001 module (the smaller board mounted on the carrier).

### iPhone Requirements

- Must have **U2 UWB chip** (iPhone 11 or newer)
- Running **iOS 17.0+**
- NearbyInteraction entitlement requires Apple Developer account

## Anchor Placement

### Requirements

1. **Non-collinear** — anchors must form a triangle (not a line) for 2D positioning to work
2. **Same height** — mount all anchors at the same elevation (~1.2 m typical) for 2D accuracy
3. **Clear line-of-sight** — minimize obstructions between anchors and measurement area
4. **Known positions** — measure with tape measure (cm precision) relative to a chosen origin

### Example Layout

```
        Anchor 3 (2.5, 4.0)
             *
            / \
           /   \
          /     \
         *-------*
    A1 (0,0)   A2 (5,0)
```

- Triangle geometry provides good HDOP (< 2) within the enclosed area
- Wider spacing improves accuracy but reduces update rate at the edges
- Keep the measurement area within the convex hull of anchors when possible

### Mounting

- Use tape, velcro, or clamps to fix boards vertically at anchor positions
- Orient all boards consistently (e.g., USB port facing down)
- Ensure the UWB antenna (top of module) has clear line of sight to the measurement area
- Avoid placing directly against metal surfaces or near large metallic objects

## Power Supply

Each DWM3001CDK is powered via its USB-C port:
- **USB power bank** — portable, good for quick setup
- **USB wall adapter** — stable for extended measurements
- **Computer USB port** — convenient during development (also provides J-Link debug)

Power consumption is low (~50 mA during ranging) so any standard USB source works.

## Coordinate System

Define a local coordinate system for your measurement space:

1. **Origin (0, 0)** — choose one anchor position as the origin (e.g., Anchor 1)
2. **X-axis** — horizontal (e.g., along the baseline between Anchor 1 and Anchor 2)
3. **Y-axis** — perpendicular to X-axis (into the room)
4. **Units** — meters

Measure all anchor positions and test points relative to this origin using a tape measure.

## Measurement Reference Points

When measuring "true distance" between iPhone and anchor for calibration:

- **Anchor side:** top edge of the DWM3001 module (where the UWB PCB antenna is located)
- **iPhone side:** center of the phone's back surface

The key requirement is **consistency** — always use the same reference points. The calibration offset absorbs any constant bias between your reference points and the actual antenna phase centers.
