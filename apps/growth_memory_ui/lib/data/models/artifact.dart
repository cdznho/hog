class Artifact {
  const Artifact({
    required this.artifactId,
    required this.cycleId,
    required this.kind,
    required this.path,
    required this.metaJson,
    required this.createdAt,
  });

  final String artifactId;
  final String cycleId;
  final String kind;
  final String path;
  final String metaJson;
  final DateTime createdAt;
}

