import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'rifle_profile.dart';
import 'shotgun_setup.dart';

enum WeaponType { rifle, shotgun }

const _uuid = Uuid();

/// Base class for all weapon profiles (rifle, shotgun).
///
/// Each profile has a stable [id] (UUID v4) that survives renames and is used
/// to link calibration data. The [id] is auto-generated when not provided and
/// preserved through JSON serialization.
abstract class WeaponProfile extends Equatable {
  final String id;
  final String name;

  WeaponProfile({String? id, required this.name}) : id = id ?? _uuid.v4();

  WeaponType get weaponType;

  Map<String, dynamic> toJson();

  static WeaponProfile fromJson(Map<String, dynamic> json) {
    final raw = json['weaponType'] as String?;
    final type = raw != null ? WeaponType.values.byName(raw) : WeaponType.rifle;
    return switch (type) {
      WeaponType.rifle => RifleProfile.fromJson(json),
      WeaponType.shotgun => ShotgunSetup.fromJson(json),
    };
  }
}
