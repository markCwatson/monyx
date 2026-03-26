part of 'map_screen.dart';

// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

/// Public / Crown land overlay methods for [_MapScreenState].
///
/// Adds a semi-transparent fill + boundary line layer sourced from a custom
/// Mapbox vector tileset. The tileset is built offline from government open
/// data (CPCAD + provincial Crown Land) and uploaded to Mapbox Studio.
///
/// Colour scheme:
///   federal_park   → brown
///   provincial_park → dark green
///   crown_land     → yellow
///   wildlife_mgmt  → olive
///   conservation   → teal
///   military       → red
///   other          → blue
extension _MapScreenLandOverlay on _MapScreenState {
  // ── Source / layer IDs ──────────────────────────────────────────────
  static const _sourceId = 'land-overlay-source';
  static const _fillLayerId = 'land-overlay-fill';
  static const _lineLayerId = 'land-overlay-line';
  static const _sourceLayerName = 'public_land'; // matches tippecanoe -l

  // ── Colour palette (ARGB integers) ────────────────────────────────
  static final _managerColors = <String, int>{
    'federal_park': const Color(0xFFB5651D).toARGB32(),
    'provincial_park': const Color(0xFF2E7D32).toARGB32(),
    'crown_land': const Color(0xFFFBC02D).toARGB32(),
    'wildlife_mgmt': const Color(0xFF827717).toARGB32(),
    'conservation': const Color(0xFF00897B).toARGB32(),
    'military': const Color(0xFFC62828).toARGB32(),
    // US (Phase 5)
    'blm': const Color(0xFFFBC02D).toARGB32(),
    'usfs': const Color(0xFF388E3C).toARGB32(),
    'nps': const Color(0xFFB5651D).toARGB32(),
    'state_park': const Color(0xFF2E7D32).toARGB32(),
  };
  static final _defaultColor = const Color(0xFF1565C0).toARGB32();

  // ── All manager categories (for filter UI) ────────────────────────
  static const allManagerCategories = <String, String>{
    'federal_park': 'Federal Parks',
    'provincial_park': 'Provincial Parks',
    'crown_land': 'Crown Land',
    'wildlife_mgmt': 'Wildlife Mgmt Areas',
    'conservation': 'Conservation Areas',
    'military': 'Military / Restricted',
  };

  static Color managerColor(String key) {
    final argb = _managerColors[key] ?? _defaultColor;
    return Color(argb);
  }

  // ── Add overlay layers to the map ─────────────────────────────────
  Future<void> _addLandOverlayLayers() async {
    if (_mapboxMap == null) return;
    final tilesetId = AppConfig.landTilesetId;
    debugPrint('[LandOverlay] tilesetId="$tilesetId"');
    if (tilesetId.isEmpty) {
      debugPrint('[LandOverlay] tileset ID is empty — skipping');
      return;
    }

    try {
      // Vector source pointing to the custom Mapbox tileset
      await _mapboxMap!.style.addSource(
        VectorSource(id: _sourceId, url: 'mapbox://$tilesetId'),
      );
      debugPrint('[LandOverlay] source added: mapbox://$tilesetId');

      // Build a Mapbox match expression for fill colour:
      // ["match", ["get", "manager"], "federal_park", "#rrggbb", …, default]
      final matchExpr = <Object>[
        'match',
        ['get', 'manager'],
      ];
      for (final entry in _managerColors.entries) {
        matchExpr.add(entry.key);
        // Convert ARGB int to #rrggbb hex string for Mapbox style expressions
        final c = Color(entry.value);
        matchExpr.add(
          '#${(c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
          '${(c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
          '${(c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}',
        );
      }
      final dc = Color(_defaultColor);
      matchExpr.add(
        '#${(dc.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
        '${(dc.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}'
        '${(dc.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')}',
      );

      // Semi-transparent fill layer
      await _mapboxMap!.style.addLayer(
        FillLayer(
          id: _fillLayerId,
          sourceId: _sourceId,
          sourceLayer: _sourceLayerName,
          fillOpacity: 0.3,
        ),
      );
      debugPrint('[LandOverlay] fill layer added');

      // Apply data-driven colour via style property (typed API only accepts int)
      await _mapboxMap!.style.setStyleLayerProperty(
        _fillLayerId,
        'fill-color',
        matchExpr,
      );

      // Boundary line layer
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _lineLayerId,
          sourceId: _sourceId,
          sourceLayer: _sourceLayerName,
          lineWidth: 1.5,
          lineOpacity: 0.7,
        ),
      );
      debugPrint('[LandOverlay] line layer added');

      await _mapboxMap!.style.setStyleLayerProperty(
        _lineLayerId,
        'line-color',
        matchExpr,
      );
      debugPrint('[LandOverlay] all layers added successfully');
    } catch (e) {
      debugPrint('[LandOverlay] ERROR adding layers: $e');
    }
  }

  // ── Remove overlay layers ─────────────────────────────────────────
  Future<void> _removeLandOverlayLayers() async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.style.removeStyleLayer(_fillLayerId);
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleLayer(_lineLayerId);
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleSource(_sourceId);
    } catch (_) {}
  }

  // ── Update filter (show/hide manager categories) ──────────────────
  Future<void> _updateLandOverlayFilter(Set<String> enabledManagers) async {
    if (_mapboxMap == null) return;

    // Mapbox GL filter: ["in", ["get", "manager"], ["literal", ["crown_land", ...]]]
    final filter = <Object?>[
      'in',
      ['get', 'manager'],
      ['literal', enabledManagers.toList()],
    ];

    await _mapboxMap!.style.setStyleLayerProperty(
      _fillLayerId,
      'filter',
      filter,
    );
    await _mapboxMap!.style.setStyleLayerProperty(
      _lineLayerId,
      'filter',
      filter,
    );
  }

  // ── Toggle overlay on/off ─────────────────────────────────────────
  Future<void> _toggleLandOverlay() async {
    if (_landOverlayEnabled) {
      await _removeLandOverlayLayers();
      setState(() => _landOverlayEnabled = false);
    } else {
      await _addLandOverlayLayers();
      if (_landOverlayFilters.length < allManagerCategories.length) {
        await _updateLandOverlayFilter(_landOverlayFilters);
      }
      setState(() => _landOverlayEnabled = true);
    }
  }

  // ── Sidebar button ────────────────────────────────────────────────
  Widget _landOverlayButton({required bool isPro}) {
    return GestureDetector(
      onLongPress: isPro && _landOverlayEnabled ? _showLandOverlaySheet : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: FloatingActionButton(
          heroTag: 'land_overlay',
          mini: true,
          backgroundColor: _landOverlayEnabled
              ? Colors.orangeAccent
              : (isPro ? Colors.black87 : Colors.grey[800]!),
          onPressed: isPro
              ? () => _landOverlayEnabled
                    ? _showLandOverlaySheet()
                    : _toggleLandOverlay()
              : () => _showUpgradeSheet(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.layers,
                color: _landOverlayEnabled
                    ? Colors.black
                    : (isPro ? Colors.white : Colors.white38),
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
      ),
    );
  }

  // ── Filter bottom sheet ───────────────────────────────────────────
  void _showLandOverlaySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Land Overlay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Select / Deselect all
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _landOverlayFilters = allManagerCategories.keys
                                .toSet();
                          });
                          _updateLandOverlayFilter(_landOverlayFilters);
                        },
                        child: const Text(
                          'Select All',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _landOverlayFilters = {};
                          });
                          _updateLandOverlayFilter(_landOverlayFilters);
                        },
                        child: const Text(
                          'Deselect All',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category checkboxes
                ...allManagerCategories.entries.map((entry) {
                  final checked = _landOverlayFilters.contains(entry.key);
                  return CheckboxListTile(
                    dense: true,
                    activeColor: Colors.orangeAccent,
                    checkColor: Colors.black,
                    title: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: managerColor(
                              entry.key,
                            ).withValues(alpha: 0.6),
                            border: Border.all(
                              color: managerColor(entry.key),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    value: checked,
                    onChanged: (val) {
                      setSheetState(() {
                        if (val == true) {
                          _landOverlayFilters.add(entry.key);
                        } else {
                          _landOverlayFilters.remove(entry.key);
                        }
                      });
                      _updateLandOverlayFilter(_landOverlayFilters);
                    },
                  );
                }),
                const Divider(color: Colors.white24),
                // Turn off overlay
                ListTile(
                  leading: const Icon(
                    Icons.layers_clear,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Turn Off Overlay',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleLandOverlay();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Open offline regions screen ───────────────────────────────────
  void _openOfflineRegions() async {
    // Get current viewport bounds from the map camera
    List<double>? bounds;
    if (_mapboxMap != null) {
      final cam = await _mapboxMap!.getCameraState();
      // Estimate bounds from center + zoom (rough bounding box)
      // At zoom 14, ~0.02° lat/lon. Scale inversely with zoom.
      final span = 0.02 * (1 << (14 - cam.zoom.round().clamp(0, 14)));
      final center = cam.center;
      final lat = center.coordinates.lat.toDouble();
      final lon = center.coordinates.lng.toDouble();
      bounds = [
        lat - span, // south
        lon - span, // west
        lat + span, // north
        lon + span, // east
      ];
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfflineRegionsScreen(currentBounds: bounds),
      ),
    );
  }
}
