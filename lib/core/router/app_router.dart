import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/user_profile.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/auth/auth_state.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/client/client_history_screen.dart';
import '../../presentation/screens/client/client_home_screen.dart';
import '../../presentation/screens/client/join_group_screen.dart';
import '../../presentation/screens/coach/coach_home_screen.dart';
import '../../presentation/screens/coach/groups/coach_groups_screen.dart';
import '../../presentation/screens/coach/groups/create_group_screen.dart';
import '../../presentation/screens/coach/templates/coach_templates_screen.dart';
import '../../presentation/screens/coach/templates/create_template_screen.dart';
import '../../presentation/screens/coach/workouts/create_workout_screen.dart';
import '../../presentation/screens/workout/results_screen.dart';
import '../../presentation/screens/workout/workout_detail_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

        if (authState is Unauthenticated || authState is AuthInitial || authState is AuthFailure) {
          return isLoggingIn ? null : '/login';
        }

        if (authState is Authenticated) {
          final user = authState.user;

          // If on auth pages or root, route by role
          if (isLoggingIn || state.matchedLocation == '/') {
            return user.role == UserRole.coach ? '/coach' : '/client';
          }

          // Protect coach routes from clients
          if (user.role == UserRole.client && state.matchedLocation.startsWith('/coach')) {
            return '/client';
          }

          // Protect client routes from coaches
          if (user.role == UserRole.coach && state.matchedLocation.startsWith('/client')) {
            return '/coach';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) => const CoachHomeScreen(),
          routes: [
            GoRoute(
              path: 'groups',
              builder: (context, state) => const CoachGroupsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateGroupScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'templates',
              builder: (context, state) => const CoachTemplatesScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateTemplateScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'workouts/create',
              builder: (context, state) => const CreateWorkoutScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) => const ClientHomeScreen(),
          routes: [
            GoRoute(
              path: 'join-group',
              builder: (context, state) => const JoinGroupScreen(),
            ),
            GoRoute(
              path: 'history',
              builder: (context, state) => const ClientHistoryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/workout/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WorkoutDetailScreen(workoutId: id);
          },
          routes: [
            GoRoute(
              path: 'results',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return ResultsScreen(workoutId: id);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
