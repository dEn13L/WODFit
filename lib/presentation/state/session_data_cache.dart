import 'dart:async';

/// Данные только текущего сеанса. Запись отменяет устаревшее фоновое чтение.
class SessionDataCache {
  final _values = <String, Object>{};
  final _versions = <String, int>{};
  final _revisions = <String, int>{};
  int _revision = 0;
  final _pending = <String, Future<Object>>{};
  final _changes = StreamController<String>.broadcast();
  int _generation = 0;
  final int maxEntries;

  SessionDataCache({this.maxEntries = 80}) : assert(maxEntries > 0);

  int get generation => _generation;
  int revisionOf(String key) => _revisions[key] ?? 0;
  Stream<String> get changes => _changes.stream;
  List<String> get keys => _values.keys.toList();
  T? read<T>(String key) {
    final value = _values.remove(key);
    if (value != null) _values[key] = value;
    return value as T?;
  }

  void put<T extends Object>(String key, T value) {
    _versions[key] = (_versions[key] ?? 0) + 1;
    _revisions[key] = ++_revision;
    _values.remove(key);
    _values[key] = value;
    while (_values.length > maxEntries) {
      _values.remove(_values.keys.first);
    }
    _changes.add(key);
  }

  void remove(String key) {
    _versions[key] = (_versions[key] ?? 0) + 1;
    _revisions[key] = ++_revision;
    _values.remove(key);
    _changes.add(key);
  }

  Future<T> refresh<T extends Object>(String key, Future<T> Function() load) {
    final pending = _pending[key];
    if (pending != null) return pending.then((value) => value as T);
    final generation = _generation;
    final version = _versions[key] ?? 0;
    late final Future<T> operation;
    operation = Future<T>.sync(load)
        .then((value) {
          if (generation != _generation) throw const CacheSessionChanged();
          if (version != (_versions[key] ?? 0)) {
            final current = read<T>(key);
            if (current == null) throw const CacheSessionChanged();
            return current;
          }
          put(key, value);
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], operation)) _pending.remove(key);
        });
    _pending[key] = operation;
    return operation;
  }

  void clear() {
    _generation++;
    _values.clear();
    _versions.clear();
    _revisions.clear();
    _pending.clear();
    _changes.add('*');
  }

  Future<void> close() {
    _generation++;
    _values.clear();
    _pending.clear();
    return _changes.close();
  }
}

class CacheSessionChanged implements Exception {
  const CacheSessionChanged();
}
