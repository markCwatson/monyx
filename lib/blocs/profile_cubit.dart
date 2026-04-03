import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/weapon_profile.dart';
import '../services/profile_service.dart';

// --- States ---

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoaded extends ProfileState {
  final WeaponProfile profile; // currently active
  final List<WeaponProfile> profiles; // all saved profiles
  final int activeIndex;
  const ProfileLoaded(
    this.profile, {
    this.profiles = const [],
    this.activeIndex = 0,
  });
  @override
  List<Object?> get props => [profile, profiles, activeIndex];
}

class ProfileEmpty extends ProfileState {
  const ProfileEmpty();
}

// --- Cubit ---

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileService _service;

  ProfileCubit(this._service) : super(const ProfileInitial());

  Future<void> load() async {
    final profiles = await _service.loadProfiles();
    if (profiles.isEmpty) {
      emit(const ProfileEmpty());
      return;
    }
    final idx = await _service.loadActiveIndex();
    final safeIdx = idx < profiles.length ? idx : 0;
    emit(
      ProfileLoaded(
        profiles[safeIdx],
        profiles: profiles,
        activeIndex: safeIdx,
      ),
    );
  }

  Future<void> save(WeaponProfile profile) async {
    await _service.saveProfile(profile);
    await load(); // reload full list
  }

  /// Add a new profile and make it active.
  Future<void> add(WeaponProfile profile) async {
    final profiles = await _service.loadProfiles();
    profiles.add(profile);
    await _service.saveProfiles(profiles);
    await _service.saveActiveIndex(profiles.length - 1);
    await load();
  }

  /// Switch active profile by index.
  Future<void> setActive(int index) async {
    await _service.saveActiveIndex(index);
    await load();
  }

  /// Delete a profile by index.
  Future<void> deleteAt(int index) async {
    final profiles = await _service.loadProfiles();
    if (index < 0 || index >= profiles.length) return;
    profiles.removeAt(index);
    await _service.saveProfiles(profiles);
    if (profiles.isEmpty) {
      emit(const ProfileEmpty());
    } else {
      await _service.saveActiveIndex(0);
      await load();
    }
  }

  Future<void> delete() async {
    await _service.deleteProfile();
    await load();
    final profiles = await _service.loadProfiles();
    if (profiles.isEmpty) {
      emit(const ProfileEmpty());
    }
  }
}
