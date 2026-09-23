# Falcon 9 kOS Autopilot

Full-flight kOS autopilot for the Tundra Exploration Falcon 9: ascent, stage separation,
first stage recovery and second stage orbit insertion, all driven from one in-game menu.
Comes with a ready-to-fly craft and a broadcast-style telemetry overlay.

## Features

**First stage (`f9s1`)**
- Countdown, clamp release, gravity turn to the selected heading, MECO on reserve.
- Recovery modes: **RTLS** (boostback to the landing zone), **ASDS** (drone ship) and
  **expendable**. **AUTO** picks the first one the payload allows.
- Entry burn, grid-fin glide aimed by an onboard landing-burn simulation, landing burn
  3 → 1 engine, terminal divert and touchdown damping.
- Keeps a touchdown history to refine the landing point on the next flight.

**Second stage (`f9s2`)** — the in-game menu
- Launch window and heading for a target inclination / plane.
- Orbit insertion, parking orbit, a list of orbits, fairing jettison.
- Match plane, rendezvous and approach to a target.
- Payload / Dragon separation, second stage deorbit.

**Drone ship (`f9asog`)**
- The booster publishes the predicted landing point, the barge sails there and reports
  its real position, deck height and status (**ON STATION** / **NOT ON STATION**).
  The booster aims at where the barge actually is.

**Dragon (`f9dragon`)** — ⚠ **experimental, full Dragon control will be in the next version.**

**Overlay** — SpaceX-webcast-style telemetry (speed, altitude, engines, timeline) drawn
over the game window. Switches to the Falcon 9 layout automatically.

## Requirements

| Mod | Tested version |
|---|---|
| KSP | 1.12.5 |
| Sol, **Quarter** scale | — |
| kOS | 1.6.0.1 |
| Tundra Exploration | 7.2.0.0 |
| Tundra Technologies | 7.2.0.0 |
| Kerbal Reusability Expansion | 2.9.3.0 |
| [Launch Towers Pack](https://forum.kerbalspaceprogram.com/topic/128370-19x-launch-towers-pack/) (pad 39A for the craft) | — |
| [GravityIssue](https://spacedock.info/mod/3895/GravityIssue) (drone ship) | — |
| Trajectories *(optional, better impact prediction)* | 2.4.5.4 |

Overlay: Windows 10/11, .NET 8 Desktop Runtime (or the self-contained build from Releases),
KSP in borderless window mode.

## Install

1. Copy everything from `scripts/` into `<KSP>/Ships/Script/`.
2. Copy `craft/Falcon 9 fairing.craft` into `<KSP>/saves/<your save>/Ships/VAB/`.
   The kOS boot files are already set in it.
3. Drone ship: set the boot file of its kOS processor to `boot/f9asog.ks`.
4. Overlay: put `overlay/` anywhere, set `telemetryPath` in `overlay.config.json` to
   `<KSP>/Ships/Script/telemetry.json`, run `KspOverlay.exe`.
   **Ctrl+Alt+O** — hide/show, **Ctrl+Alt+Q** — quit.

Building your own rocket instead: processor in the **Interstage** → `boot/f9s1.ks`,
processor in the **second stage fairing adapter** → `boot/f9s2.ks`,
Dragon processor → `boot/f9dragon.ks`.

## Flying

1. Launch the craft to the pad. The second stage menu opens by itself.
2. Pick the target orbit and the recovery mode (AUTO / RTLS / ASDS / EXP).
3. For ASDS: switch to the drone ship once and make sure `f9asog` runs; the menu shows the
   barge status.
4. Press **LAUNCH**.

Logs are written to the Archive (`Ships/Script/*.log`).

## Known limitations

- Dragon capsule control is experimental.
- Tuned and tested in Sol, Quarter scale.
