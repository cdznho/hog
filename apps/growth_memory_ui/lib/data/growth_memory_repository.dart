import 'dart:convert';

import 'models/artifact.dart';
import 'models/cycle.dart';
import 'models/org.dart';
import 'models/snapshot.dart';
import 'sqlite/growth_memory_db.dart';

class GrowthMemoryRepository {
  GrowthMemoryRepository(this._db);

  final GrowthMemoryDb _db;

  String get dbPath => _db.dbPath;

  List<Org> listOrgs() => _db.listOrgs();
  Org? getOrg(String orgId) => _db.getOrg(orgId);
  List<Cycle> listCycles({String? orgId}) => _db.listCycles(orgId: orgId);
  List<Snapshot> listSnapshots({String? orgId, String? cycleId}) => _db.listSnapshots(orgId: orgId, cycleId: cycleId);
  List<Artifact> listArtifacts({String? orgId}) => _db.listArtifacts(orgId: orgId);

  void upsertOrg({
    required String orgId,
    required String name,
    required String siteUrl,
    String? industry,
    String? audience,
    String? competitors,
    String? goal,
  }) {
    final profile = <String, Object?>{
      'site_url': siteUrl,
      if (industry != null) 'industry': industry,
      if (audience != null) 'audience': audience,
      if (competitors != null) 'competitors': competitors,
      if (goal != null) 'goal': goal,
    };
    _db.upsertOrg(orgId: orgId, name: name, profile: profile);
  }

  void createCycle({
    required String cycleId,
    required String orgId,
    required String goal,
    required Map<String, Object?> inputs,
    String cycleType = 'llm-seo',
  }) {
    _db.insertCycle(cycleId: cycleId, orgId: orgId, cycleType: cycleType, goal: goal, inputs: inputs);
  }

  void attachReportArtifact({
    required String artifactId,
    required String cycleId,
    required String reportPath,
    Map<String, Object?> meta = const {},
  }) {
    _db.insertArtifact(
      artifactId: artifactId,
      cycleId: cycleId,
      kind: 'report_html',
      path: reportPath,
      meta: meta,
    );
  }

  Map<String, Object?> decodeProfile(Org org) {
    try {
      final value = jsonDecode(org.profileJson);
      if (value is Map<String, Object?>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return {};
    } catch (_) {
      return {};
    }
  }

  void storeGscSnapshot({
    required String cycleId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required Map<String, Object?> data,
  }) {
    _db.insertSnapshot(
      snapshotId: 'snapshot_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      cycleId: cycleId,
      source: 'gsc',
      windowStart: windowStart,
      windowEnd: windowEnd,
      data: data,
    );
  }
}
