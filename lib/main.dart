import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/utils/app_logger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/datasources/result_sync_local_data_source.dart';
import 'data/repositories/supabase_crossfit_workout_repository.dart';
import 'data/repositories/supabase_program_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/crossfit_workout_repository.dart';
import 'domain/repositories/program_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/program/program_cubit.dart';
import 'presentation/bloc/theme/theme_cubit.dart';
import 'presentation/bloc/workout/crossfit_workout_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local cache (Hive)
  await Hive.initFlutter();

  final ThemeService themeService = ThemeService();
  await themeService.init();

  await AppLogger.initialize(Hive.box<dynamic>('settings_box'));
  FlutterError.onError = (details) {
    AppLogger.e(
      'Flutter',
      details.context?.toDescription() ?? 'Framework error',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Platform', 'Unhandled error', error, stack);
    return true;
  };

  // 2. Initialize Backend (Supabase)
  await SupabaseConfig.initialize();

  // 3. Instantiate repositories
  final AuthRepository authRepository = SupabaseAuthRepository();
  final ProgramRepository programRepository = SupabaseProgramRepository();
  final resultSyncBox = await Hive.openBox<dynamic>(
    HiveResultSyncLocalDataSource.boxName,
  );
  final CrossfitWorkoutRepository crossfitWorkoutRepository =
      SupabaseCrossfitWorkoutRepository(
        resultLocalDataSource: HiveResultSyncLocalDataSource(resultSyncBox),
      );

  runApp(
    WodFitApp(
      authRepository: authRepository,
      programRepository: programRepository,
      crossfitWorkoutRepository: crossfitWorkoutRepository,
      themeService: themeService,
    ),
  );
}

class WodFitApp extends StatefulWidget {
  final AuthRepository authRepository;
  final ProgramRepository programRepository;
  final CrossfitWorkoutRepository crossfitWorkoutRepository;
  final ThemeService themeService;

  const WodFitApp({
    super.key,
    required this.authRepository,
    required this.programRepository,
    required this.crossfitWorkoutRepository,
    required this.themeService,
  });

  @override
  State<WodFitApp> createState() => _WodFitAppState();
}

class _WodFitAppState extends State<WodFitApp> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authRepository: widget.authRepository)
      ..add(const AuthCheckRequested());
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
        RepositoryProvider<ProgramRepository>.value(
          value: widget.programRepository,
        ),
        RepositoryProvider<CrossfitWorkoutRepository>.value(
          value: widget.crossfitWorkoutRepository,
        ),
        RepositoryProvider<ThemeService>.value(value: widget.themeService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<ThemeCubit>(
            create: (context) => ThemeCubit(themeService: widget.themeService),
          ),
          BlocProvider<ProgramCubit>(
            create: (context) =>
                ProgramCubit(programRepository: widget.programRepository),
          ),
          BlocProvider<CrossfitWorkoutCubit>(
            create: (context) => CrossfitWorkoutCubit(
              workoutRepository: widget.crossfitWorkoutRepository,
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'WOD Fit',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
