import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/workout.dart';
import 'package:wod_fit/domain/repositories/workout_repository.dart';
import 'package:wod_fit/main.dart';

class MockWorkoutRepository implements WorkoutRepository {
  final List<Workout> _workouts = [];

  @override
  Future<List<Workout>> getWorkouts() async => _workouts;

  @override
  Future<void> saveWorkout(Workout workout) async {
    _workouts.add(workout);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    _workouts.removeWhere((w) => w.id == id);
  }

  @override
  Stream<int> getStepCountStream() => Stream.value(5432);
}

void main() {
  testWidgets('HomeScreen smoke test - displays title, stats and start workout button',
      (WidgetTester tester) async {
    final mockRepository = MockWorkoutRepository();

    await tester.pumpWidget(WodFitApp(workoutRepository: mockRepository));
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Привет, Атлет! ⚡'), findsOneWidget);

    // Verify "Начать тренировку" button
    expect(find.text('Начать тренировку'), findsOneWidget);

    // Verify Daily metrics
    expect(find.text('Активность сегодня'), findsOneWidget);
    expect(find.text('Шаги'), findsOneWidget);
    expect(find.text('Калории'), findsOneWidget);

    // Tap "Начать тренировку" button to open modal
    await tester.tap(find.text('Начать тренировку'));
    await tester.pumpAndSettle();

    // Verify modal appears with workout types and start action
    expect(find.text('Выберите тип тренировки'), findsOneWidget);
    expect(find.text('ПОГНАЛИ!'), findsOneWidget);
  });
}
