import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/crossfit_workout_repository.dart';
import '../../domain/repositories/program_repository.dart';
import '../bloc/program/program_cubit.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/workout/crossfit_workout_cubit.dart';
import '../state/session_data_cache.dart';

/// У каждого маршрута своё состояние; загруженные данные общие для сеанса.
class ScreenDataScope extends StatelessWidget {
  final Widget child;
  const ScreenDataScope({super.key, required this.child});

  static void _showRefreshError(BuildContext context, String? error) {
    if (error != null && ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, auth) {
      if (auth is! Authenticated) return const SizedBox.shrink();
      return MultiBlocProvider(
        key: ValueKey((auth.user.id, auth.user.role)),
        providers: [
          BlocProvider<ProgramCubit>(
            create: (context) => ProgramCubit(
              programRepository: context.read<ProgramRepository>(),
              cache: context.read<SessionDataCache>(),
            ),
          ),
          BlocProvider<CrossfitWorkoutCubit>(
            create: (context) => CrossfitWorkoutCubit(
              workoutRepository: context.read<CrossfitWorkoutRepository>(),
              cache: context.read<SessionDataCache>(),
            ),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<ProgramCubit, ProgramState>(
              listener: (context, state) {
                if (state is ProgramLoaded) {
                  _showRefreshError(context, state.refreshError);
                }
              },
            ),
            BlocListener<CrossfitWorkoutCubit, CrossfitWorkoutState>(
              listener: (context, state) {
                if (state is CrossfitWorkoutListLoaded) {
                  _showRefreshError(context, state.refreshError);
                }
                if (state is CrossfitWorkoutDetailLoaded) {
                  _showRefreshError(context, state.refreshError);
                }
              },
            ),
          ],
          child: child,
        ),
      );
    },
  );
}
