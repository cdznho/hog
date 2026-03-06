import '../models/artifact.dart';
import '../models/coverage_insight.dart';
import '../models/cycle.dart';
import '../models/org.dart';
import '../models/recommendation_insight.dart';
import '../models/snapshot.dart';

import 'growth_memory_db_web.dart' if (dart.library.io) 'growth_memory_db_io.dart';

abstract class GrowthMemoryDb {
  static Future<GrowthMemoryDb> openDefault() => GrowthMemoryDbImpl.openDefault();

  String get dbPath;

  void close();

  List<Org> listOrgs();
  Org? getOrg(String orgId);
  void upsertOrg({required String orgId, required String name, required Map<String, Object?> profile});

  List<Cycle> listCycles({String? orgId});
  void insertCycle({
    required String cycleId,
    required String orgId,
    required String cycleType,
    required String goal,
    required Map<String, Object?> inputs,
  });

  List<Snapshot> listSnapshots({String? cycleId, String? orgId});
  void insertSnapshot({
    required String snapshotId,
    required String cycleId,
    required String source,
    required DateTime windowStart,
    required DateTime windowEnd,
    required Map<String, Object?> data,
  });

  List<CoverageInsight> listCoverageInsights({String? cycleId, String? orgId});
  void replaceCoverageInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  });

  List<RecommendationInsight> listRecommendationInsights({String? cycleId, String? orgId});
  void replaceRecommendationInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  });

  List<Artifact> listArtifacts({String? orgId});
  void insertArtifact({
    required String artifactId,
    required String cycleId,
    required String kind,
    required String path,
    required Map<String, Object?> meta,
  });
}
