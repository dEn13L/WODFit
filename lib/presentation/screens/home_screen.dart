import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/workout.dart';
import '../bloc/workout_bloc.dart';
import '../bloc/workout_event.dart';
import '../bloc/workout_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/workout_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WorkoutType _selectedType = WorkoutType.crossfit;

  @override
  void initState() {
    super.initState();
    context.read<WorkoutBloc>().add(const LoadWorkoutsEvent());
  }

  void _showStartWorkoutModal(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Выберите тип тренировки',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WorkoutType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(_getWorkoutTypeName(type)),
                        selected: isSelected,
                        selectedColor: colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedType = type;
                            });
                            setState(() {
                              _selectedType = type;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        context
                            .read<WorkoutBloc>()
                            .add(StartWorkoutEvent(type: _selectedType));

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            content: Text(
                              'Тренировка "${_getWorkoutTypeName(_selectedType)}" начата! 🔥',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 28),
                          SizedBox(width: 8),
                          Text('ПОГНАЛИ!'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getWorkoutTypeName(WorkoutType type) {
    switch (type) {
      case WorkoutType.crossfit:
        return 'CrossFit';
      case WorkoutType.strength:
        return 'Силовая';
      case WorkoutType.cardio:
        return 'Кардио';
      case WorkoutType.hiit:
        return 'HIIT';
      case WorkoutType.mobility:
        return 'Растяжка';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<WorkoutBloc, WorkoutState>(
          builder: (context, state) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'С ВОЗВРАЩЕНИЕМ,',
                              style: TextStyle(
                                color: colorScheme.primary.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Привет, Атлет! ⚡',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main CTA Button "Начать тренировку"
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showStartWorkoutModal(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Начать тренировку',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Выбери режим и сожги калории',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Daily Metrics Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Активность сегодня',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Шаги',
                                value: '${state.todaySteps}',
                                unit: 'шагов',
                                icon: Icons.directions_walk_rounded,
                                accentColor: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Калории',
                                value: '${state.todayCalories}',
                                unit: 'ккал',
                                icon: Icons.local_fire_department_rounded,
                                accentColor: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Время',
                                value: '${state.todayDurationMinutes}',
                                unit: 'мин',
                                icon: Icons.timer_outlined,
                                accentColor: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Сессии',
                                value: '${state.workouts.length}',
                                unit: 'трен.',
                                icon: Icons.bolt_rounded,
                                accentColor: Colors.purpleAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Recent Workouts Section
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'История тренировок',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (state.workouts.isNotEmpty)
                          Text(
                            'Всего: ${state.workouts.length}',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // List or empty state
                if (state.workouts.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.sports_score_rounded,
                              size: 48,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Пока нет завершенных тренировок',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Нажми «Начать тренировку» выше, чтобы записать первый подход!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final workout = state.workouts[index];
                          return WorkoutCard(workout: workout);
                        },
                        childCount: state.workouts.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
