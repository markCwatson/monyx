# Hike Tracking

Pro subscribers can record GPS hike tracks — even with the app in the background. Points are saved only when the user moves ≥2 m from the previous point (haversine filter), keeping storage minimal while maintaining path fidelity.

## How it works

1. Tap the **🥾 hike button** on the map screen (Pro only — free users see a locked icon with an upgrade prompt).
2. The app requests "always" location permission (needed for background tracking).
3. **iOS** shows a blue status bar indicator; **Android** shows a persistent notification ("Atlix Hunt — Tracking Hike").
4. Walk — footstep icons appear along the path on the map in real time.
5. A **recording banner** at the top of the map shows live distance and elapsed time.
6. Tap the banner or button to **pause** (stops GPS stream, freezes timer) or **stop** (finishes recording).
7. On stop, a **summary sheet** shows: total distance (mi + km), active time, elevation gain/loss (ft + m), average pace. Name the hike and save it.
8. Saved hikes can be **recalled** from the history menu — the path renders on the map with a summary card.

## Background tracking

| Platform    | Mechanism                                                                    | User indicator                                        |
| ----------- | ---------------------------------------------------------------------------- | ----------------------------------------------------- |
| **iOS**     | `AppleSettings(allowBackgroundLocationUpdates: true, activityType: fitness)` | Blue location bar in status area                      |
| **Android** | `AndroidSettings(foregroundNotificationConfig: ...)`                         | Persistent notification: "Atlix Hunt — Tracking Hike" |

GPS stream continues when the app is minimized or the screen is locked. No internet required — GPS altitude is used for elevation.

## Data filtering

- **Haversine threshold**: New point saved only if ≥2 m from previous point. Filters GPS jitter without losing path detail.
- **Elevation dead-band**: Altitude changes < 2 m are ignored when computing gain/loss, reducing GPS altitude noise.
- **Pause/resume**: Paused intervals are excluded from active duration. GPS stream is cancelled during pause to save battery.

## Units

Distances and elevation are shown in dual units — imperial primary with metric in parentheses (e.g., "1.2 mi (1.9 km)", "325 ft (99 m)").

## Architecture

| Component   | File                                        | Role                                               |
| ----------- | ------------------------------------------- | -------------------------------------------------- |
| Model       | `lib/models/hike_track.dart`                | HikePoint + HikeTrack data classes with JSON       |
| Persistence | `lib/services/hike_track_service.dart`      | Hive-based save/load/delete for hike tracks        |
| State       | `lib/blocs/hike_track_cubit.dart`           | Recording state machine with background GPS stream |
| Map path    | `lib/screens/map_screen.dart`               | GeoJSON source + footstep symbol layer on Mapbox   |
| Saved list  | `lib/screens/saved_hike_tracks_screen.dart` | Browse and revisit past hikes                      |
| Haversine   | `lib/ballistics/conversions.dart`           | `haversineMeters()` for 2 m threshold check        |
