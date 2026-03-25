part of 'map_screen.dart';

// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

/// Hike tracking methods for [_MapScreenState].
extension _MapScreenHiking on _MapScreenState {
  String _pointsGeoJson(List<HikePoint> points) {
    final features = points
        .map(
          (p) =>
              '{"type":"Feature","geometry":{"type":"Point","coordinates":[${p.lon},${p.lat}]},"properties":{}}',
        )
        .join(',');
    return '{"type":"FeatureCollection","features":[$features]}';
  }

  Future<void> _updateHikeTrackPath(List<HikePoint> points) async {
    if (_mapboxMap == null || points.length < 2) return;

    final coords = points.map((p) => Position(p.lon, p.lat)).toList();
    final lineString = LineString(coordinates: coords);
    final geojson =
        '{"type":"Feature","geometry":${lineString.toJson()},"properties":{}}';

    if (!_hikeTrackLayerReady) {
      // Create source + layers the first time
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'hike-track-source', data: geojson),
      );
      // Thin semi-transparent line as backbone
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: 'hike-track-line',
          sourceId: 'hike-track-source',
          lineColor: Colors.teal.toARGB32(),
          lineWidth: 3.0,
          lineOpacity: 0.5,
        ),
      );
      // Point markers along the path (circle layer on a separate point source)
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'hike-track-pts', data: _pointsGeoJson(points)),
      );
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'hike-track-circles',
          sourceId: 'hike-track-pts',
          circleRadius: 4.0,
          circleColor: Colors.teal.toARGB32(),
          circleStrokeWidth: 1.5,
          circleStrokeColor: Colors.white.toARGB32(),
          circleOpacity: 0.9,
        ),
      );
      _hikeTrackLayerReady = true;
    } else {
      // Update existing source data
      final source =
          await _mapboxMap!.style.getSource('hike-track-source')
              as GeoJsonSource;
      await source.updateGeoJSON(geojson);
      final ptSource =
          await _mapboxMap!.style.getSource('hike-track-pts') as GeoJsonSource;
      await ptSource.updateGeoJSON(_pointsGeoJson(points));
    }
  }

  Future<void> _clearHikeTrackPath() async {
    if (!_hikeTrackLayerReady || _mapboxMap == null) return;
    try {
      await _mapboxMap!.style.removeStyleLayer('hike-track-circles');
      await _mapboxMap!.style.removeStyleLayer('hike-track-line');
      await _mapboxMap!.style.removeStyleSource('hike-track-pts');
      await _mapboxMap!.style.removeStyleSource('hike-track-source');
    } catch (_) {}
    _hikeTrackLayerReady = false;
  }

  Widget _hikeTrackButton({
    required bool isPro,
    required HikeTrackState hikeState,
    required VoidCallback onTap,
  }) {
    final isRecording = hikeState is HikeTrackRecording;
    final isPaused = hikeState is HikeTrackPaused;
    final isActive = isRecording || isPaused;

    Color bgColor;
    if (!isPro) {
      bgColor = Colors.grey[800]!;
    } else if (isRecording) {
      bgColor = Colors.teal;
    } else if (isPaused) {
      bgColor = Colors.amber;
    } else {
      bgColor = Colors.black87;
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: FloatingActionButton(
        heroTag: 'hike_track',
        mini: true,
        backgroundColor: bgColor,
        onPressed: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.directions_walk,
              color: isActive
                  ? Colors.white
                  : (isPro ? Colors.teal : Colors.white38),
              size: 20,
            ),
            if (!isPro)
              const Positioned(
                right: -2,
                bottom: -2,
                child: Icon(Icons.lock, color: Colors.white54, size: 10),
              ),
          ],
        ),
      ),
    );
  }

  void _handleHikeButtonTap(BuildContext context, HikeTrackState hikeState) {
    final cubit = context.read<HikeTrackCubit>();

    if (hikeState is HikeTrackIdle || hikeState is HikeTrackError) {
      _showHikeStartConfirm(context, cubit);
      return;
    }

    if (hikeState is HikeTrackRecording) {
      _showHikeControlSheet(
        context,
        isRecording: true,
        onPause: cubit.pause,
        onStop: cubit.stop,
      );
      return;
    }

    if (hikeState is HikeTrackPaused) {
      _showHikeControlSheet(
        context,
        isRecording: false,
        onResume: cubit.resume,
        onStop: cubit.stop,
        onDiscard: () {
          cubit.discard();
          Navigator.pop(context);
        },
      );
      return;
    }
  }

  void _showHikeStartConfirm(BuildContext context, HikeTrackCubit cubit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Start Hike?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'GPS tracking will begin in the background.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _hikeActionTile(
                icon: Icons.play_arrow,
                label: 'Start Tracking',
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.start();
                },
              ),
              const SizedBox(height: 8),
              _hikeActionTile(
                icon: Icons.close,
                label: 'Cancel',
                color: Colors.white38,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHikeControlSheet(
    BuildContext context, {
    required bool isRecording,
    VoidCallback? onPause,
    VoidCallback? onResume,
    required VoidCallback onStop,
    VoidCallback? onDiscard,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRecording ? 'Recording Hike' : 'Hike Paused',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (isRecording && onPause != null)
                _hikeActionTile(
                  icon: Icons.pause,
                  label: 'Pause',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pop(ctx);
                    onPause();
                  },
                ),
              if (!isRecording && onResume != null)
                _hikeActionTile(
                  icon: Icons.play_arrow,
                  label: 'Resume',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(ctx);
                    onResume();
                  },
                ),
              const SizedBox(height: 8),
              _hikeActionTile(
                icon: Icons.stop,
                label: 'End',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(ctx);
                  onStop();
                },
              ),
              if (onDiscard != null) ...[
                const SizedBox(height: 8),
                _hikeActionTile(
                  icon: Icons.delete_outline,
                  label: 'Discard',
                  color: Colors.white38,
                  onTap: onDiscard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hikeActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.grey[800],
    );
  }

  void _openHikeSummary(HikeTrack track, {bool viewOnly = false}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => HikeSummaryScreen(
              track: track,
              viewOnly: viewOnly,
              onSave: viewOnly
                  ? null
                  : (name) async {
                      await context.read<HikeTrackCubit>().save(name);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hike saved'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      }
                    },
              onDiscard: viewOnly
                  ? null
                  : () {
                      context.read<HikeTrackCubit>().discard();
                    },
              onRename: viewOnly
                  ? (name) async {
                      await context.read<HikeTrackCubit>().renameSaved(
                        track.id,
                        name,
                      );
                    }
                  : null,
            ),
          ),
        )
        .then((_) {
          // When returning from the summary, clear the viewed track if in view mode
          if (viewOnly && mounted) {
            context.read<HikeTrackCubit>().clear();
          }
        });
  }

  void _openSavedHikeTracks(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route is! PopupRoute);
    Navigator.of(this.context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: this.context.read<HikeTrackCubit>(),
          child: const SavedHikeTracksScreen(),
        ),
      ),
    );
  }
}
