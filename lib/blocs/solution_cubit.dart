import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../ballistics/conversions.dart';
import '../ballistics/solver.dart';
import '../models/rifle_profile.dart';
import '../models/shot_solution.dart';
import '../models/weather_data.dart';
import '../services/elevation_service.dart';
import '../services/weather_service.dart';

// --- States ---

abstract class SolutionState extends Equatable {
  const SolutionState();
  @override
  List<Object?> get props => [];
}

class SolutionIdle extends SolutionState {
  const SolutionIdle();
}

class SolutionComputing extends SolutionState {
  const SolutionComputing();
}

class SolutionReady extends SolutionState {
  final ShotSolution solution;
  final String? lineId;
  const SolutionReady(this.solution, {this.lineId});
  @override
  List<Object?> get props => [solution, lineId];
}

class SolutionError extends SolutionState {
  final String message;
  const SolutionError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- Cubit ---

class SolutionCubit extends Cubit<SolutionState> {
  final WeatherService _weather;
  final ElevationService _elevation;

  SolutionCubit({
    required WeatherService weatherService,
    required ElevationService elevationService,
  }) : _weather = weatherService,
       _elevation = elevationService,
       super(const SolutionIdle());

  /// Compute a shot solution from shooter → target.
  Future<void> compute({
    required RifleProfile profile,
    required double shooterLat,
    required double shooterLon,
    required double targetLat,
    required double targetLon,
    String? lineId,
  }) async {
    emit(const SolutionComputing());
    try {
      // Fetch weather + elevation in parallel
      final results = await Future.wait([
        _weather.fetchWeather(targetLat, targetLon),
        _elevation.getElevationPairFeet(
          shooterLat,
          shooterLon,
          targetLat,
          targetLon,
        ),
      ]);

      final weather = results[0] as WeatherData;
      final elevPair = results[1] as (double, double);
      final (shooterElevFt, targetElevFt) = elevPair;

      // Geometry
      final horizRange = haversineYards(
        shooterLat,
        shooterLon,
        targetLat,
        targetLon,
      );
      final elevDiff = targetElevFt - shooterElevFt;
      final azimuth = bearing(shooterLat, shooterLon, targetLat, targetLon);

      if (horizRange < 1) {
        emit(const SolutionError('Target too close'));
        return;
      }

      final solution = BallisticSolver.solve(
        profile: profile,
        weather: weather,
        horizontalRangeYards: horizRange,
        elevationDiffFt: elevDiff,
        shootingAzimuthDeg: azimuth,
      );

      emit(SolutionReady(solution, lineId: lineId));
    } catch (e) {
      emit(SolutionError('Computation failed: $e'));
    }
  }

  void clear() => emit(const SolutionIdle());

  void show(ShotSolution solution, {String? lineId}) =>
      emit(SolutionReady(solution, lineId: lineId));
}
