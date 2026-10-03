import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/exceptions/workout_save_exception.dart';

class AppLogger {
  static const maxEntries = 50;
  static const _key = 'error_log';
  static Box<dynamic>? _box;
  static final List<String> _entries = [];
  static Future<void> _pending = Future<void>.value();

  static Future<void> initialize(Box<dynamic> box) async {
    _box = box;
    final saved = box.get(_key);
    if (saved is List) {
      _entries.insertAll(0, saved.whereType<String>());
    }
    _trim();
  }

  static void _trim() {
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  static String _sanitize(String value) => value
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[token]',
      )
      .replaceAll(
        RegExp(r'Bearer\s+[^\s,"\\]+', caseSensitive: false),
        'Bearer [token]',
      )
      .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]');

  static String exportErrors() => _entries.isEmpty
      ? 'WOD Fit: журнал ошибок пуст'
      : 'WOD Fit / $defaultTargetPlatform / release=$kReleaseMode\n${_entries.join('\n\n')}';

  static Future<void> flush() => _pending;

  static String userMessage(Object error) {
    if (error is WorkoutSaveException) return error.message;
    if (error is AuthException) return 'Войдите в аккаунт снова.';
    if (error is PostgrestException) {
      if (error.code == 'PGRST116') {
        return 'Тренировка удалена или недоступна. Обновите список тренировок.';
      }
      if (error.code == '42501') {
        return 'Нет доступа к данным. Обновите список.';
      }
    }
    return 'Не удалось выполнить действие. Проверьте соединение и попробуйте ещё раз.';
  }

  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG][$tag] $message');
    }
  }

  static void i(String tag, String message) {
    debugPrint('[INFO][$tag] $message');
  }

  static void w(String tag, String message, [Object? error]) {
    debugPrint('[WARN][$tag] $message ${error != null ? 'Error: $error' : ''}');
  }

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final entry = _sanitize(
      jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'tag': tag,
        'message': message,
        'errorType': error?.runtimeType.toString(),
        if (error is PostgrestException) ...{
          'code': error.code,
          'details': error.details?.toString(),
          'hint': error.hint,
        },
        'error': error?.toString(),
        'stack': stackTrace?.toString(),
      }),
    );
    _entries.add(entry.length > 12000 ? entry.substring(0, 12000) : entry);
    _trim();
    final snapshot = List<String>.from(_entries);
    _pending = _pending.then((_) async {
      try {
        await _box?.put(_key, snapshot);
      } catch (storageError) {
        // Не вызывать logger повторно при ошибке самого хранилища.
        debugPrint('Error log storage failed: ${storageError.runtimeType}');
      }
    });
    if (kDebugMode) debugPrint(entry);
  }
}
