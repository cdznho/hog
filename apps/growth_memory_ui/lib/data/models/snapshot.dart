class Snapshot {
  const Snapshot({
    required this.snapshotId,
    required this.cycleId,
    required this.source,
    required this.windowStart,
    required this.windowEnd,
    required this.dataJson,
    required this.createdAt,
  });

  final String snapshotId;
  final String cycleId;
  final String source;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String dataJson;
  final DateTime createdAt;
}

