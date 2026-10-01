class ParsedWorkoutTime {
  final int minutes;
  final int seconds;

  const ParsedWorkoutTime({required this.minutes, required this.seconds});

  int get milliseconds => (minutes * 60 + seconds) * 1000;
  String get formatted =>
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

ParsedWorkoutTime? parseWorkoutTime(String minutesText, String secondsText) {
  final minutes = int.tryParse(minutesText.trim());
  final seconds = int.tryParse(secondsText.trim());
  if (minutes == null || seconds == null || minutes < 0 || seconds < 0 || seconds > 59) {
    return null;
  }
  return ParsedWorkoutTime(minutes: minutes, seconds: seconds);
}

double? parseNonNegativeDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0 || !parsed.isFinite) return null;
  return parsed;
}

int? parseNonNegativeInt(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

String formatDecimal(double value) => value.truncateToDouble() == value
    ? value.toInt().toString()
    : value.toString();
