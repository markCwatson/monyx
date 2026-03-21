import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/profile_cubit.dart';
import '../blocs/subscription_cubit.dart';
import '../models/rifle_profile.dart';
import 'profile_screen.dart';

/// Shows saved profiles with the ability to switch, add, and delete.
///
/// Free users see only their single profile and an upgrade prompt.
/// Pro users get unlimited profiles.
class ProfileListScreen extends StatelessWidget {
  const ProfileListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<SubscriptionCubit>().isPro;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Profiles'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addProfile(context, isPro),
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state is! ProfileLoaded) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No profiles yet',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _openEditor(context),
                  ),
                ],
              ),
            );
          }

          final profiles = state.profiles;
          final activeIdx = state.activeIndex;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    final isActive = index == activeIdx;
                    return ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isActive ? Colors.orangeAccent : Colors.white38,
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${p.caliber}  •  ${p.muzzleVelocityFps.round()} fps  •  BC ${p.ballisticCoefficient}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white54,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(context, profile: p, index: index);
                          } else if (value == 'delete') {
                            context.read<ProfileCubit>().deleteAt(index);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      onTap: () {
                        context.read<ProfileCubit>().setActive(index);
                      },
                    );
                  },
                ),
              ),
              if (!isPro)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[850],
                  child: _UpgradeBanner(
                    onTap: () => _showUpgradeSheet(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _addProfile(BuildContext context, bool isPro) {
    if (!isPro) {
      final state = context.read<ProfileCubit>().state;
      if (state is ProfileLoaded && state.profiles.isNotEmpty) {
        _showUpgradeSheet(context);
        return;
      }
    }
    _openEditor(context);
  }

  void _openEditor(BuildContext context, {RifleProfile? profile, int? index}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ProfileCubit>()),
            BlocProvider.value(value: context.read<SubscriptionCubit>()),
          ],
          child: ProfileScreen(editProfile: profile, editIndex: index),
        ),
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    final subCubit = context.read<SubscriptionCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Upgrade to Monyx Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Save unlimited rifle & ammo profiles and remove all ads.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              BlocBuilder<SubscriptionCubit, SubscriptionState>(
                bloc: subCubit,
                builder: (context, state) {
                  final price = state is SubscriptionFree
                      ? state.product?.price ?? ''
                      : '';
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      subCubit.purchase();
                      Navigator.pop(context);
                    },
                    child: Text(
                      price.isNotEmpty
                          ? 'Subscribe — $price / month'
                          : 'Subscribe to Pro',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  subCubit.restore();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Restore Purchase',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Upgrade to Pro for unlimited profiles & no ads',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}
