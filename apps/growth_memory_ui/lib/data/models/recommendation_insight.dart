class RecommendationInsight {
  const RecommendationInsight({
    required this.insightId,
    required this.cycleId,
    required this.title,
    required this.status,
    required this.priority,
    required this.owner,
    required this.metaJson,
    required this.createdAt,
  });

  final String insightId;
  final String cycleId;
  final String title;
  final String status;
  final String priority;
  final String owner;
  final String metaJson;
  final DateTime createdAt;
}

