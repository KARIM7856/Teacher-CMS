/// Formats a number of seconds as `m:ss` (e.g. 200 → "3:20"). Used for resume
/// positions. Western digits, per the project's numeral choice.
String formatSeconds(int totalSeconds) {
  final int safe = totalSeconds < 0 ? 0 : totalSeconds;
  final int minutes = safe ~/ 60;
  final int seconds = safe % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
