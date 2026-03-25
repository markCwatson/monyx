part of 'map_screen.dart';

// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

/// POI pin methods for [_MapScreenState].
extension _MapScreenPoi on _MapScreenState {
  Future<void> _registerPoiIcons() async {
    for (final type in PoiType.values) {
      final bytes = await _renderPoiPin(type);
      await _mapboxMap!.style.addStyleImage(
        'poi-${type.name}',
        2.0,
        MbxImage(width: 128, height: 160, data: bytes),
        false,
        [],
        [],
        null,
      );
    }
  }

  Future<Uint8List> _renderPoiPin(PoiType type) async {
    const int w = 128, h = 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    final color = _poiColor(type);

    // Combined pin shape: rounded rect body merged with triangle pointer
    final pinPaint = Paint()..color = color;
    const double bodyTop = 4;
    const double bodyBottom = 104;
    const double bodyLeft = 8;
    const double bodyRight = 120;
    const double r = 24; // corner radius
    const double tipY = 148;
    const double tipX = 64;

    final pin = Path()
      // Start at top-left after corner
      ..moveTo(bodyLeft + r, bodyTop)
      // Top edge
      ..lineTo(bodyRight - r, bodyTop)
      // Top-right corner
      ..arcToPoint(
        const Offset(bodyRight, bodyTop + r),
        radius: const Radius.circular(r),
      )
      // Right edge
      ..lineTo(bodyRight, bodyBottom - r)
      // Bottom-right corner
      ..arcToPoint(
        const Offset(bodyRight - r, bodyBottom),
        radius: const Radius.circular(r),
      )
      // Bottom edge to right side of pointer
      ..lineTo(tipX + 20, bodyBottom)
      // Pointer tip
      ..lineTo(tipX, tipY)
      ..lineTo(tipX - 20, bodyBottom)
      // Bottom edge to left side
      ..lineTo(bodyLeft + r, bodyBottom)
      // Bottom-left corner
      ..arcToPoint(
        Offset(bodyLeft, bodyBottom - r),
        radius: const Radius.circular(r),
      )
      // Left edge
      ..lineTo(bodyLeft, bodyTop + r)
      // Top-left corner
      ..arcToPoint(
        Offset(bodyLeft + r, bodyTop),
        radius: const Radius.circular(r),
      )
      ..close();

    canvas.drawPath(pin, pinPaint);

    // Dark outline
    final outlinePaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(pin, outlinePaint);

    // Icon inside pin
    final icon = _poiIcon(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 56,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, (108 - tp.height) / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _showPoiTypePicker(double lat, double lon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Drop Pin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...PoiType.values.map(
                  (type) => _poiTypeOption(ctx, type, lat, lon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _poiTypeOption(
    BuildContext ctx,
    PoiType type,
    double lat,
    double lon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(_poiIcon(type), color: _poiColor(type)),
        title: Text(type.label, style: const TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[800],
        onTap: () {
          Navigator.pop(ctx);
          _showPoiMetadataForm(type, lat, lon);
        },
      ),
    );
  }

  /// Shows a form to enter notes and optionally attach a photo before
  /// dropping the pin.
  void _showPoiMetadataForm(PoiType type, double lat, double lon) {
    final noteCtrl = TextEditingController();
    String? pickedPhotoPath;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(_poiIcon(type), color: _poiColor(type), size: 28),
                      const SizedBox(width: 12),
                      Text(
                        type.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Photo preview or add button
                  if (pickedPhotoPath != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(pickedPhotoPath!),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => pickedPhotoPath = null),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.grey[600]!),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Add Photo'),
                      onPressed: () async {
                        final source = await _pickImageSource(ctx);
                        if (source == null) return;
                        final xFile = await ImagePicker().pickImage(
                          source: source,
                          maxWidth: 1920,
                          imageQuality: 85,
                        );
                        if (xFile != null) {
                          setSheetState(() => pickedPhotoPath = xFile.path);
                        }
                      },
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: BorderSide(color: Colors.grey[700]!),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _dropPoiPin(
                              type,
                              lat,
                              lon,
                              note: noteCtrl.text.trim().isNotEmpty
                                  ? noteCtrl.text.trim()
                                  : null,
                              tempPhotoPath: pickedPhotoPath,
                            );
                          },
                          child: const Text('Drop Pin'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Let the user choose camera or gallery.
  Future<ImageSource?> _pickImageSource(BuildContext ctx) async {
    return showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dropPoiPin(
    PoiType type,
    double lat,
    double lon, {
    String? note,
    String? tempPhotoPath,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // Copy photo to permanent storage if provided
    String? photoPath;
    if (tempPhotoPath != null) {
      photoPath = await _poiService.savePhoto(tempPhotoPath, id);
    }

    final poi = Poi(
      id: id,
      type: type,
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      note: note,
      photoPath: photoPath,
    );

    await _poiService.save(poi);
    await _addPoiAnnotation(poi);
  }

  Future<void> _addPoiAnnotation(Poi poi) async {
    final label = poi.note ?? poi.type.label;
    final annotation = await _poiManager?.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(poi.longitude, poi.latitude)),
        iconImage: 'poi-${poi.type.name}',
        iconSize: 0.8,
        iconAnchor: IconAnchor.BOTTOM,
        textField: label,
        textSize: 11,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.0,
        textAnchor: TextAnchor.TOP,
        textOffset: [0.0, 0.5],
      ),
    );
    if (annotation != null) {
      _poiAnnotations[annotation.id] = poi;
    }
  }

  Future<void> _loadSavedPois() async {
    final pois = await _poiService.loadAll();
    for (final poi in pois) {
      await _addPoiAnnotation(poi);
    }
  }

  void _showPoiDetail(Poi poi, String annotationId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      _poiIcon(poi.type),
                      color: _poiColor(poi.type),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.note ?? poi.type.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (poi.note != null)
                            Text(
                              poi.type.label,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${poi.latitude.toStringAsFixed(5)}, ${poi.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatTimestamp(poi.timestamp),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

                // Photo
                if (poi.photoPath != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showFullPhoto(poi.photoPath!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(poi.photoPath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],

                // Notes
                if (poi.note != null && poi.note!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      poi.note!,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons
                _poiActionButton(
                  icon: Icons.edit,
                  label: poi.note != null ? 'Edit Notes' : 'Add Notes',
                  color: Colors.orangeAccent,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final updated = await _editPoiNote(poi);
                    if (updated != null) {
                      _refreshPoiAnnotations();
                    }
                  },
                ),
                const SizedBox(height: 8),
                _poiActionButton(
                  icon: Icons.camera_alt,
                  label: poi.photoPath != null ? 'Change Photo' : 'Add Photo',
                  color: Colors.lightBlue,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _addPoiPhoto(poi);
                  },
                ),
                const SizedBox(height: 8),
                _poiActionButton(
                  icon: Icons.directions,
                  label: 'Get Directions',
                  color: Colors.green,
                  onTap: () {
                    _openDirections(poi.latitude, poi.longitude);
                  },
                ),
                const SizedBox(height: 8),
                _poiActionButton(
                  icon: Icons.delete,
                  label: 'Delete Pin',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _poiService.delete(poi.id);
                    _poiManager?.deleteAll();
                    _poiAnnotations.clear();
                    await _loadSavedPois();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _poiActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }

  Future<Poi?> _editPoiNote(Poi poi) async {
    final controller = TextEditingController(text: poi.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Edit Notes', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter notes',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
    if (result == null) return null;
    final updated = poi.copyWith(note: result.isNotEmpty ? result : null);
    await _poiService.update(updated);
    return updated;
  }

  Future<void> _addPoiPhoto(Poi poi) async {
    final source = await _pickImageSource(context);
    if (source == null) return;
    final xFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (xFile == null) return;

    // Delete old photo if replacing
    if (poi.photoPath != null) {
      await _poiService.deletePhoto(poi.photoPath);
    }

    final photoPath = await _poiService.savePhoto(xFile.path, poi.id);
    final updated = poi.copyWith(photoPath: photoPath);
    await _poiService.update(updated);
    _refreshPoiAnnotations();
  }

  void _refreshPoiAnnotations() {
    _poiManager?.deleteAll();
    _poiAnnotations.clear();
    _loadSavedPois();
  }

  void _openDirections(double lat, double lon) {
    // Try Apple Maps on iOS, falls back to Google Maps
    final appleMapsUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lon&dirflg=d',
    );
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication).catchError(
      (_) => launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication),
    );
  }

  void _showFullPhoto(String photoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(photoPath))),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  IconData _poiIcon(PoiType type) => switch (type) {
    PoiType.campsite => Icons.cabin,
    PoiType.treeStand => Icons.nature,
    PoiType.trailCam => Icons.videocam,
    PoiType.waterSource => Icons.water_drop,
    PoiType.foodPlot => Icons.grass,
    PoiType.parking => Icons.local_parking,
    PoiType.custom => Icons.place,
  };

  Color _poiColor(PoiType type) => switch (type) {
    PoiType.campsite => Colors.orangeAccent,
    PoiType.treeStand => Colors.green,
    PoiType.trailCam => Colors.lightBlue,
    PoiType.waterSource => Colors.blue,
    PoiType.foodPlot => Colors.lime,
    PoiType.parking => Colors.grey,
    PoiType.custom => Colors.white,
  };
}
