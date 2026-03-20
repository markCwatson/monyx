import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/ballistics/screens/ballistics_screen.dart';
import 'features/map/screens/map_screen.dart';
import 'features/profiles/screens/profile_screen.dart';

class MonyxApp extends ConsumerWidget {
  const MonyxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _buildRouter(ref);
    return MaterialApp.router(
      title: 'Monyx',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authState = ref.read(authStateProvider);
        final isAuthenticated = authState.valueOrNull != null;
        final isOnAuth =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/';

        // If not authenticated and not on an auth screen, redirect to login
        if (!isAuthenticated && !isOnAuth) return '/login';
        // If authenticated and on splash/login, redirect to map
        if (isAuthenticated && isOnAuth) return '/map';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => const _SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/ballistics',
          builder: (context, state) => const BallisticsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const _SettingsScreen(),
        ),
      ],
    );
  }
}

/// Splash screen shown briefly while auth state resolves.
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    authState.whenData((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (user != null) {
          context.go('/map');
        } else {
          context.go('/login');
        }
      });
    });

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terrain, size: 80, color: AppTheme.primaryOrange),
            const SizedBox(height: 16),
            Text(
              'MONYX',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Placeholder settings screen.
class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('Monyx v1.0.0 – Offline hunting map & ballistics'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Map Style'),
            subtitle: Text('Outdoors (default)'),
          ),
          ListTile(
            leading: Icon(Icons.straighten),
            title: Text('Units'),
            subtitle: Text('Imperial (yards, mph, °F)'),
          ),
        ],
      ),
    );
  }
}
