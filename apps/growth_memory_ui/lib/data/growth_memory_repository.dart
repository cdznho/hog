import 'dart:convert';

import 'models/artifact.dart';
import 'models/coverage_insight.dart';
import 'models/cycle.dart';
import 'models/org.dart';
import 'models/recommendation_insight.dart';
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
  List<CoverageInsight> listCoverageInsights({String? orgId, String? cycleId}) =>
      _db.listCoverageInsights(orgId: orgId, cycleId: cycleId);
  List<RecommendationInsight> listRecommendationInsights({String? orgId, String? cycleId}) =>
      _db.listRecommendationInsights(orgId: orgId, cycleId: cycleId);
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

  void replaceCoverageInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    final normalized = [
      for (var index = 0; index < rows.length; index++)
        <String, Object?>{
          'insight_id': rows[index]['insight_id'] ?? 'coverage_${cycleId}_$index',
          'category': _normalizeLabel(rows[index]['category']),
          'subcategory': _normalizeLabel(rows[index]['subcategory']),
          'pillar_status': _normalizeLabel(rows[index]['pillar_status'], fallback: 'Unknown'),
          'cluster_current': _asInt(rows[index]['cluster_current']),
          'cluster_target': _asInt(rows[index]['cluster_target'], fallback: 5),
          'coverage': _normalizeLabel(rows[index]['coverage'], fallback: 'Unknown'),
          'priority': _normalizeLabel(rows[index]['priority'], fallback: 'Unknown'),
          'meta': rows[index]['meta'] is Map<String, Object?>
              ? rows[index]['meta'] as Map<String, Object?>
              : <String, Object?>{},
        },
    ];
    _db.replaceCoverageInsights(cycleId: cycleId, rows: normalized);
  }

  void replaceRecommendationInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    final normalized = [
      for (var index = 0; index < rows.length; index++)
        <String, Object?>{
          'insight_id': rows[index]['insight_id'] ?? 'recommendation_${cycleId}_$index',
          'title': rows[index]['title']?.toString() ?? '',
          'status': rows[index]['status']?.toString() ?? 'Open',
          'priority': rows[index]['priority']?.toString() ?? 'Unknown',
          'owner': rows[index]['owner']?.toString() ?? 'Unassigned',
          'meta': rows[index]['meta'] is Map<String, Object?>
              ? rows[index]['meta'] as Map<String, Object?>
              : <String, Object?>{},
        },
    ];
    _db.replaceRecommendationInsights(cycleId: cycleId, rows: normalized);
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _normalizeLabel(Object? value, {String fallback = ''}) {
  final text = value?.toString() ?? fallback;
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
