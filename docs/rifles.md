# Ballistic Engine

The solver is a pure-Dart port of [pyballistic](https://github.com/dbookstaber/pyballistic) (py-ballisticcalc), a well-tested open-source ballistic calculator. All calculations run on-device with no network required.

## Algorithm

| Component                | Detail                                                                                          |
| ------------------------ | ----------------------------------------------------------------------------------------------- |
| **Model**                | Point-mass 3-DoF (x = downrange, y = drop, z = windage)                                         |
| **Integrator**           | Classic RK4, fixed time step 0.0025 s                                                           |
| **Drag tables**          | Standard G1 (80 entries) and G7 (84 entries), Cd vs Mach                                        |
| **Drag interpolation**   | PCHIP (monotone cubic Hermite, Fritsch-Carlson slopes) — C1 continuous, shape-preserving        |
| **Standard Drag Factor** | `Cd(mach) × 2.08551e-04 / BC` where the constant = ρ₀ × π / (4 × 2 × 144), ρ₀ = 0.076474 lb/ft³ |
| **Air density**          | CIPM-2007 formula — saturation vapour pressure, enhancement factor, compressibility factor      |
| **Altitude correction**  | Lapse-rate model (−0.0019812 K/ft) updates density ratio and Mach at each integration step      |
| **Speed of sound**       | 49.0223 × √(°R) ft/s                                                                            |
| **Zero-finding**         | Ridder's method (guaranteed convergence, ~60 iterations max)                                    |
| **Gravity**              | 32.17405 ft/s²                                                                                  |

## How a shot is solved

1. **Build atmosphere** — station temperature, pressure, humidity → CIPM-2007 air density in kg/m³ → density ratio (local / standard 1.225 kg/m³).
2. **Find zero angle** — under ICAO standard atmosphere, find the bore elevation (via Ridder's method) that puts the bullet at y = 0 at the zero range.
3. **Add shot angle** — if the target has an elevation difference (from DEM), the look angle is added to the zero angle.
4. **Run trajectory** — RK4 integration with altitude-dependent density and Mach. At each step: compute `k_m = density_ratio × drag_by_mach(speed/Mach)` once, then evaluate four sub-step accelerations (gravity + drag opposing air-relative velocity). Wind is a constant headwind/crosswind vector subtracted from ground velocity.
5. **Measure drop** — the line-of-sight from scope (at sight height) to target (at elevation offset) is computed at the bullet's final x position. Drop = bullet y − LOS y. Windage = bullet z.
6. **Convert** — drop/drift in inches → MOA → clicks, plus velocity, energy, and time of flight.

## Test data

The solver is validated against pyballistic's reference trajectories:

| Profile                                | Range   | Velocity | Drop   | Source                   |
| -------------------------------------- | ------- | -------- | ------ | ------------------------ |
| .308 168gr BC 0.223 G1, MV 2750, 2" SH | 100 yd  | 2351 fps | 0"     | pyballistic test_path_g1 |
| .308 168gr BC 0.223 G1, MV 2750, 2" SH | 500 yd  | 1169 fps | −87.9" | pyballistic test_path_g1 |
| .308 168gr BC 0.223 G1, MV 2750, 2" SH | 1000 yd | 776 fps  | −824"  | pyballistic test_path_g1 |
| .308 168gr BC 0.223 G7, MV 2750, 2" SH | 100 yd  | 2545 fps | 0"     | pyballistic test_path_g7 |
| .308 168gr BC 0.223 G7, MV 2750, 2" SH | 500 yd  | 1814 fps | −56.2" | pyballistic test_path_g7 |
| .308 168gr BC 0.223 G7, MV 2750, 2" SH | 1000 yd | 1086 fps | −400"  | pyballistic test_path_g7 |

Tolerances: velocity ±15 fps, drop ±3" (500 yd) / ±10" (1000 yd).

## Architecture

| Component   | File                               | Role                                                     |
| ----------- | ---------------------------------- | -------------------------------------------------------- |
| Solver      | `lib/ballistics/solver.dart`       | RK4 integrator, zero-finding, trajectory computation     |
| Atmosphere  | `lib/ballistics/atmosphere.dart`   | CIPM-2007 air density, density ratio, speed of sound     |
| Drag tables | `lib/ballistics/drag_tables.dart`  | G1 & G7 Cd vs Mach lookup tables                         |
| Conversions | `lib/ballistics/conversions.dart`  | MOA ↔ inches ↔ clicks, haversine, bearing, wind decomp  |
| Profile     | `lib/models/rifle_profile.dart`    | Rifle/ammo profile (caliber, BC, MV, zero range, etc.)   |
| Solution    | `lib/models/shot_solution.dart`    | Drop, windage, velocity, energy, TOF output              |
| State       | `lib/blocs/solution_cubit.dart`    | Manages compute flow (weather + elevation + solve)       |
