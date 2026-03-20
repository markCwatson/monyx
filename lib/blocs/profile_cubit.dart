import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/rifle_profile.dart';
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
  final RifleProfile profile;
  const ProfileLoaded(this.profile);
  @override
  List<Object?> get props => [profile];
}

class ProfileEmpty extends ProfileState {
  const ProfileEmpty();
}

// --- Cubit ---

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileService _service;

  ProfileCubit(this._service) : super(const ProfileInitial());

  Future<void> load() async {
    final profile = await _service.loadProfile();
    if (profile != null) {
      emit(ProfileLoaded(profile));
    } else {
      emit(const ProfileEmpty());
    }
  }

  Future<void> save(RifleProfile profile) async {
    await _service.saveProfile(profile);
    emit(ProfileLoaded(profile));
  }

  Future<void> delete() async {
    await _service.deleteProfile();
    emit(const ProfileEmpty());
  }
}
