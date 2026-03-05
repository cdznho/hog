import 'dart:math' as math;

String newId(String prefix) {
  final rand = math.Random();
  final suffix = rand.nextInt(99999).toString().padLeft(5, '0');
  final ts = DateTime.now().toUtc().microsecondsSinceEpoch;
  return '${prefix}_${ts}_$suffix';
}

