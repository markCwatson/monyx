# Wind Overlay

Animated wind particle overlay on the map with manual entry for free users and live weather + animation for Pro.

## Free vs Pro

| Capability                              | Free | Pro |
| --------------------------------------- | ---- | --- |
| Manual wind entry (speed + direction)   | ✅   | ✅  |
| Wind used in ballistic calculations     | ✅   | ✅  |
| Wind speed badge on map                 | ✅   | ✅  |
| Live wind from Open-Meteo API           | —    | ✅  |
| Animated particle overlay (Windy-style) | —    | ✅  |
| Pick location on map                    | —    | ✅  |
| Forecast wind (date/time picker)        | —    | ✅  |
| Saved weather profiles (Hive, offline)  | —    | ✅  |

## Technical details

| Component                  | Detail                                                                                                                                                                             |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Particle system**        | ~600 particles at 60fps via `CustomPainter` + `Ticker`, trailing lines with fade envelope                                                                                          |
| **Weather API**            | Open-Meteo current + hourly forecast (wind speed + direction at 10m, free for non-commercial)                                                                                      |
| **Ballistics integration** | When wind is set (manual or live), `SolutionCubit.compute()` overrides the API weather's wind fields via `WeatherData.withWind()` so the solution card and wind badge always agree |
| **Offline profiles**       | Each live fetch is auto-saved to Hive; dedicated Saved Weather screen for viewing, applying, or deleting                                                                           |

## Data flow

```
Wind button tap → _showWindSheet()
  ├─ Enter Manually (free) → speed + direction dialog → _applyManualWind() → no animation
  ├─ Now (GPS, Pro) → fetchWeather() → UniformWindField → particles
  ├─ Now (pick, Pro) → tap map → fetchWeather() → particles
  ├─ Later (Pro) → date/time picker → tap map → fetchWindForecast() → particles
  └─ Saved (Pro) → Hive → WeatherProfile → particles (offline)

Ballistics: cubit.compute(..., windSpeedMph, windDirectionDeg) → solver uses overlay/manual wind
```

## Architecture

| Component        | File                                          | Role                                                    |
| ---------------- | --------------------------------------------- | ------------------------------------------------------- |
| Wind data model  | `lib/models/wind_data.dart`                   | WindVector, WindField abstraction, UniformWindField      |
| Weather data     | `lib/models/weather_data.dart`                | Temperature, humidity, pressure, wind speed/direction    |
| Weather profile  | `lib/models/weather_profile.dart`             | Saved weather snapshot with label, location, timestamp   |
| Weather service  | `lib/services/weather_service.dart`           | Open-Meteo current + forecast API                       |
| Profile service  | `lib/services/weather_profile_service.dart`   | Hive persistence for saved weather profiles              |
| Particle system  | `lib/services/wind_particle_system.dart`      | Pool-based engine; spawn, update, recycle particles      |
| Particle         | `lib/services/wind_particle.dart`             | Individual particle state (position, age, speed)         |
| Wind overlay     | `lib/widgets/wind_overlay.dart`               | Ticker-driven CustomPainter rendering particles          |
| Saved weather UI | `lib/screens/saved_weather_screen.dart`       | Browse, apply, or delete saved weather profiles          |
| Map weather tab  | `lib/screens/map/_weather.dart`               | Wind sheet, manual entry, live fetch, forecast picker    |
