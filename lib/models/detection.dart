import 'package:equatable/equatable.dart';

/// A single bounding-box detection from the YOLO model.
class Detection extends Equatable {
  /// Bounding box in image coordinates [x1, y1, x2, y2].
  final double x1, y1, x2, y2;

  /// Species name predicted by the model.
  final String className;

  /// Confidence score (0.0–1.0).
  final double confidence;

  const Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.className,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'className': className,
    'confidence': confidence,
  };

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    x1: (json['x1'] as num).toDouble(),
    y1: (json['y1'] as num).toDouble(),
    x2: (json['x2'] as num).toDouble(),
    y2: (json['y2'] as num).toDouble(),
    className: json['className'] as String,
    confidence: (json['confidence'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [x1, y1, x2, y2, className, confidence];
}
