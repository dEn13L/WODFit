import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/local/workout_local_datasource.dart';
import 'data/datasources/sensors/sensor_datasource.dart';
import 'data/repositories/workout_repository_impl.dart';
import 'domain/repositories/workout_repository.dart';
import 'presentation/bloc/workout_bloc.dart';
import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final WorkoutLocalDataSource localDataSource = WorkoutLocalDataSourceImpl();
  await localDataSource.init();

  final SensorDataSource sensorDataSource = SensorDataSourceImpl();

  final WorkoutRepository workoutRepository = WorkoutRepositoryImpl(
    localDataSource: localDataSource,
    sensorDataSource: sensorDataSource,
  );

  runApp(WodFitApp(workoutRepository: workoutRepository));
}

class WodFitApp extends StatelessWidget {
  final WorkoutRepository workoutRepository;

  const WodFitApp({
    super.key,
    required this.workoutRepository,
  });

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<WorkoutRepository>.value(
      value: workoutRepository,
      child: BlocProvider<WorkoutBloc>(
        create: (context) => WorkoutBloc(repository: workoutRepository),
        child: MaterialApp(
          title: 'WOD Fit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
