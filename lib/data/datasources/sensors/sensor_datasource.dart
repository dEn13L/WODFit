import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

abstract class SensorDataSource {
  Stream<int> get stepCountStream;
}

class SensorDataSourceImpl implements SensorDataSource {
  final _stepController = StreamController<int>.broadcast();
  StreamSubscription<StepCount>? _subscription;

  SensorDataSourceImpl() {
    _initPedometer();
  }

  void _initPedometer() {
    try {
      _subscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _stepController.add(event.steps);
        },
        onError: (error) {
          debugPrint('Pedometer sensor error / unavailable: $error');
          // Graceful fallback for simulator / web / unsupported hardware
          _stepController.add(0);
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Pedometer initialization error: $e');
      _stepController.add(0);
    }
  }

  @override
  Stream<int> get stepCountStream => _stepController.stream;

  void dispose() {
    _subscription?.cancel();
    _stepController.close();
  }
}
