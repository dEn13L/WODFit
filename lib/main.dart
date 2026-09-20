import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/workout_local_datasource.dart';
import 'data/datasources/sensors/sensor_datasource.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_crossfit_workout_repository.dart';
import 'data/repositories/supabase_program_repository.dart';
import 'data/repositories/workout_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/crossfit_workout_repository.dart';
import 'domain/repositories/program_repository.dart';
import 'domain/repositories/workout_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/program/program_cubit.dart';
import 'presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'presentation/bloc/workout_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local cache (Hive)
  await Hive.initFlutter();
  final WorkoutLocalDataSource localDataSource = WorkoutLocalDataSourceImpl();
  await localDataSource.init();

  final SensorDataSource sensorDataSource = SensorDataSourceImpl();

  // 2. Initialize Backend (Supabase)
  await SupabaseConfig.initialize();

  // 3. Instantiate repositories
  final AuthRepository authRepository = SupabaseAuthRepository();
  final ProgramRepository programRepository = SupabaseProgramRepository();
  final CrossfitWorkoutRepository crossfitWorkoutRepository = SupabaseCrossfitWorkoutRepository();
  final WorkoutRepository legacyWorkoutRepository = WorkoutRepositoryImpl(
    localDataSource: localDataSource,
    sensorDataSource: sensorDataSource,
  );

  runApp(
    WodFitApp(
      authRepository: authRepository,
      programRepository: programRepository,
      crossfitWorkoutRepository: crossfitWorkoutRepository,
      legacyWorkoutRepository: legacyWorkoutRepository,
    ),
  );
}

class WodFitApp extends StatefulWidget {
  final AuthRepository authRepository;
  final ProgramRepository programRepository;
  final CrossfitWorkoutRepository crossfitWorkoutRepository;
  final WorkoutRepository legacyWorkoutRepository;

  const WodFitApp({
    super.key,
    required this.authRepository,
    required this.programRepository,
    required this.crossfitWorkoutRepository,
    required this.legacyWorkoutRepository,
  });

  @override
  State<WodFitApp> createState() => _WodFitAppState();
}

class _WodFitAppState extends State<WodFitApp> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authRepository: widget.authRepository)..add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(_authBloc);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: widget.authRepository),
        RepositoryProvider<ProgramRepository>.value(value: widget.programRepository),
        RepositoryProvider<CrossfitWorkoutRepository>.value(value: widget.crossfitWorkoutRepository),
        RepositoryProvider<WorkoutRepository>.value(value: widget.legacyWorkoutRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<ProgramCubit>(
            create: (context) => ProgramCubit(programRepository: widget.programRepository),
          ),
          BlocProvider<CrossfitWorkoutCubit>(
            create: (context) => CrossfitWorkoutCubit(workoutRepository: widget.crossfitWorkoutRepository),
          ),
          BlocProvider<WorkoutBloc>(
            create: (context) => WorkoutBloc(repository: widget.legacyWorkoutRepository),
          ),
        ],
        child: MaterialApp.router(
          title: 'WOD Fit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
  }
}
