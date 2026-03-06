class CoverageInsight {
  const CoverageInsight({
    required this.insightId,
    required this.cycleId,
    required this.category,
    required this.subcategory,
    required this.pillarStatus,
    required this.clusterCurrent,
    required this.clusterTarget,
    required this.coverage,
    required this.priority,
    required this.metaJson,
    required this.createdAt,
  });

  final String insightId;
  final String cycleId;
  final String category;
  final String subcategory;
  final String pillarStatus;
  final int clusterCurrent;
  final int clusterTarget;
  final String coverage;
  final String priority;
  final String metaJson;
  final DateTime createdAt;
}

