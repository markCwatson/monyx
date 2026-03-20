import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'blocs/profile_cubit.dart';
import 'blocs/solution_cubit.dart';
import 'config.dart';
import 'screens/map_screen.dart';
import 'services/elevation_service.dart';
import 'services/profile_service.dart';
import 'services/weather_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive
  await Hive.initFlutter();

  // Init Mapbox access token
  MapboxOptions.setAccessToken(AppConfig.mapboxPublicToken);

  runApp(const MonyxApp());
}

class MonyxApp extends StatelessWidget {
  const MonyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProfileCubit(ProfileService())..load()),
        BlocProvider(
          create: (_) => SolutionCubit(
            weatherService: WeatherService(),
            elevationService: ElevationService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Monyx',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orangeAccent,
            brightness: Brightness.dark,
          ),
        ),
        home: const MapScreen(),
      ),
    );
  }
}
