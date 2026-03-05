class Cycle {
  const Cycle({
    required this.cycleId,
    required this.orgId,
    required this.cycleType,
    required this.goal,
    required this.inputsJson,
    required this.createdAt,
  });

  final String cycleId;
  final String orgId;
  final String cycleType;
  final String goal;
  final String inputsJson;
  final DateTime createdAt;
}

