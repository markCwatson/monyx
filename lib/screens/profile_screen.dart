import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/profile_cubit.dart';
import '../models/rifle_profile.dart';

/// The two-class pattern:
/// Flutter rebuilds widgets frequently, but state needs to persist across
/// rebuilds. The StatefulWidget is recreated on every rebuild (it's cheap),
/// but the State object is created once and sticks around. This separation
/// lets Flutter be efficient while you keep mutable state safe.

class ProfileScreen extends StatefulWidget {
  final RifleProfile? editProfile;
  final int? editIndex;
  const ProfileScreen({super.key, this.editProfile, this.editIndex});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // The controllers are declared late because they're initialized in
  // initState(), not in the declaration. late tells Dart "I promise this
  // will have a value before it's used."
  late TextEditingController _name;
  late TextEditingController _caliber;
  late TextEditingController _barrelLength;
  late TextEditingController _twistRate;
  late TextEditingController _sightHeight;
  late TextEditingController _zeroDistance;
  late TextEditingController _clickValue;
  late TextEditingController _muzzleVelocity;
  late TextEditingController _bulletWeight;
  late TextEditingController _bc;
  DragModel _dragModel = DragModel.g1;

  @override
  void initState() {
    super.initState();
    final p = widget.editProfile ?? _defaultFromState();

    _name = TextEditingController(text: p.name);
    _caliber = TextEditingController(text: p.caliber);
    _barrelLength = TextEditingController(
      text: p.barrelLengthInches.toString(),
    );
    _twistRate = TextEditingController(text: p.twistRateInches.toString());
    _sightHeight = TextEditingController(text: p.sightHeightInches.toString());
    _zeroDistance = TextEditingController(text: p.zeroDistanceYards.toString());
    _clickValue = TextEditingController(text: p.clickValueMoa.toString());
    _muzzleVelocity = TextEditingController(
      text: p.muzzleVelocityFps.toString(),
    );
    _bulletWeight = TextEditingController(
      text: p.bulletWeightGrains.toString(),
    );
    _bc = TextEditingController(text: p.ballisticCoefficient.toString());
    _dragModel = p.dragModel;
  }

  @override
  void dispose() {
    // You must dispose controllers to avoid memory leaks.
    _name.dispose();
    _caliber.dispose();
    _barrelLength.dispose();
    _twistRate.dispose();
    _sightHeight.dispose();
    _zeroDistance.dispose();
    _clickValue.dispose();
    _muzzleVelocity.dispose();
    _bulletWeight.dispose();
    _bc.dispose();
    super.dispose();
  }

  RifleProfile _defaultFromState() {
    final state = context.read<ProfileCubit>().state;
    return state is ProfileLoaded ? state.profile : RifleProfile.default308();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final profile = RifleProfile(
      name: _name.text.trim(),
      caliber: _caliber.text.trim(),
      barrelLengthInches: double.parse(_barrelLength.text),
      twistRateInches: double.parse(_twistRate.text),
      sightHeightInches: double.parse(_sightHeight.text),
      zeroDistanceYards: double.parse(_zeroDistance.text),
      clickValueMoa: double.parse(_clickValue.text),
      muzzleVelocityFps: double.parse(_muzzleVelocity.text),
      bulletWeightGrains: double.parse(_bulletWeight.text),
      ballisticCoefficient: double.parse(_bc.text),
      dragModel: _dragModel,
    );

    final cubit = context.read<ProfileCubit>();
    if (widget.editProfile != null) {
      // Editing an existing profile — save overwrites the active one
      cubit.save(profile);
    } else {
      // Adding new
      cubit.add(profile);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Rifle Profile'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('RIFLE'),
            _field('Name', _name),
            _field('Caliber', _caliber),
            _field('Barrel length (in)', _barrelLength, numeric: true),
            _field('Twist rate (1:X in)', _twistRate, numeric: true),
            _field('Sight height (in)', _sightHeight, numeric: true),
            _field('Zero distance (yds)', _zeroDistance, numeric: true),
            _field('Click value (MOA)', _clickValue, numeric: true),

            const SizedBox(height: 24),
            _section('AMMUNITION'),
            _field('Muzzle velocity (fps)', _muzzleVelocity, numeric: true),
            _field('Bullet weight (gr)', _bulletWeight, numeric: true),
            _field('Ballistic coefficient', _bc, numeric: true),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Drag model: ',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('G1'),
                  selected: _dragModel == DragModel.g1,
                  onSelected: (_) => setState(() => _dragModel = DragModel.g1),
                  selectedColor: Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('G7'),
                  selected: _dragModel == DragModel.g7,
                  onSelected: (_) => setState(() => _dragModel = DragModel.g7),
                  selectedColor: Colors.orangeAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.orangeAccent),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Required';
          if (numeric && double.tryParse(value) == null) {
            return 'Invalid number';
          }
          return null;
        },
      ),
    );
  }
}
