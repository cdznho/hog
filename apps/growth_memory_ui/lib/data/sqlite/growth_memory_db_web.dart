import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/artifact.dart';
import '../models/coverage_insight.dart';
import '../models/cycle.dart';
import '../models/org.dart';
import '../models/recommendation_insight.dart';
import '../models/snapshot.dart';
import 'growth_memory_db.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'GM_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8765',
);

class GrowthMemoryDbImpl implements GrowthMemoryDb {
  GrowthMemoryDbImpl._(this._apiBaseUrl, this._client);

  static Future<GrowthMemoryDb> openDefault() async {
    final db = GrowthMemoryDbImpl._(_defaultApiBaseUrl, http.Client());
    await db._bootstrap();
    return db;
  }

  final String _apiBaseUrl;
  final http.Client _client;

  final Map<String, Org> _orgs = {};
  final List<Cycle> _cycles = [];
  final List<Snapshot> _snapshots = [];
  final List<CoverageInsight> _coverageInsights = [];
  final List<RecommendationInsight> _recommendationInsights = [];
  final List<Artifact> _artifacts = [];

  @override
  String get dbPath => 'api: $_apiBaseUrl';

  Future<void> _bootstrap() async {
    final response = await _client.get(Uri.parse('$_apiBaseUrl/bootstrap'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to bootstrap Growth Memory API: HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    _orgs
      ..clear()
      ..addEntries(
        (payload['orgs'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final org = Org(
            orgId: row['org_id'] as String,
            name: row['name'] as String,
            profileJson: row['profile_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
          return MapEntry(org.orgId, org);
        }),
      );

    _cycles
      ..clear()
      ..addAll(
        (payload['cycles'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Cycle(
            cycleId: row['cycle_id'] as String,
            orgId: row['org_id'] as String,
            cycleType: row['cycle_type'] as String,
            goal: row['goal'] as String,
            inputsJson: row['inputs_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }),
      );

    _snapshots
      ..clear()
      ..addAll(
        (payload['snapshots'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Snapshot(
            snapshotId: row['snapshot_id'] as String,
            cycleId: row['cycle_id'] as String,
            source: row['source'] as String,
            windowStart: DateTime.parse(row['window_start'] as String),
            windowEnd: DateTime.parse(row['window_end'] as String),
            dataJson: row['data_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }),
      );

    _artifacts
      ..clear()
      ..addAll(
        (payload['artifacts'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Artifact(
            artifactId: row['artifact_id'] as String,
            cycleId: row['cycle_id'] as String,
            kind: row['kind'] as String,
            path: row['path'] as String,
            metaJson: row['meta_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }),
      );

    _coverageInsights
      ..clear()
      ..addAll(
        (payload['coverage_insights'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return CoverageInsight(
            insightId: row['insight_id'] as String,
            cycleId: row['cycle_id'] as String,
            category: row['category'] as String,
            subcategory: row['subcategory'] as String,
            pillarStatus: row['pillar_status'] as String,
            clusterCurrent: row['cluster_current'] as int,
            clusterTarget: row['cluster_target'] as int,
            coverage: row['coverage'] as String,
            priority: row['priority'] as String,
            metaJson: row['meta_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }),
      );

    _recommendationInsights
      ..clear()
      ..addAll(
        (payload['recommendation_insights'] as List? ?? const []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return RecommendationInsight(
            insightId: row['insight_id'] as String,
            cycleId: row['cycle_id'] as String,
            title: row['title'] as String,
            status: row['status'] as String,
            priority: row['priority'] as String,
            owner: row['owner'] as String,
            metaJson: row['meta_json'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        }),
      );
  }

  @override
  void close() {
    _client.close();
  }

  @override
  Org? getOrg(String orgId) => _orgs[orgId];

  @override
  List<Org> listOrgs() => _orgs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void upsertOrg({required String orgId, required String name, required Map<String, Object?> profile}) {
    final now = DateTime.now().toUtc();
    _orgs[orgId] = Org(orgId: orgId, name: name, profileJson: jsonEncode(profile), createdAt: now);
    unawaited(
      _put('/orgs/$orgId', {
        'org_id': orgId,
        'name': name,
        'profile': profile,
      }),
    );
  }

  @override
  void insertCycle({
    required String cycleId,
    required String orgId,
    required String cycleType,
    required String goal,
    required Map<String, Object?> inputs,
  }) {
    _cycles.add(
      Cycle(
        cycleId: cycleId,
        orgId: orgId,
        cycleType: cycleType,
        goal: goal,
        inputsJson: jsonEncode(inputs),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(
      _post('/cycles', {
        'cycle_id': cycleId,
        'org_id': orgId,
        'cycle_type': cycleType,
        'goal': goal,
        'inputs': inputs,
      }),
    );
  }

  @override
  List<Cycle> listCycles({String? orgId}) {
    final out = orgId == null ? [..._cycles] : _cycles.where((c) => c.orgId == orgId).toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  void insertSnapshot({
    required String snapshotId,
    required String cycleId,
    required String source,
    required DateTime windowStart,
    required DateTime windowEnd,
    required Map<String, Object?> data,
  }) {
    _snapshots.add(
      Snapshot(
        snapshotId: snapshotId,
        cycleId: cycleId,
        source: source,
        windowStart: windowStart.toUtc(),
        windowEnd: windowEnd.toUtc(),
        dataJson: jsonEncode(data),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(
      _post('/snapshots', {
        'snapshot_id': snapshotId,
        'cycle_id': cycleId,
        'source': source,
        'window_start': windowStart.toUtc().toIso8601String(),
        'window_end': windowEnd.toUtc().toIso8601String(),
        'data': data,
      }),
    );
  }

  @override
  List<Snapshot> listSnapshots({String? cycleId, String? orgId}) {
    Iterable<Snapshot> it = _snapshots;
    if (cycleId != null) {
      it = it.where((s) => s.cycleId == cycleId);
    } else if (orgId != null) {
      final cycleIds = _cycles.where((c) => c.orgId == orgId).map((c) => c.cycleId).toSet();
      it = it.where((s) => cycleIds.contains(s.cycleId));
    }
    return it.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  List<CoverageInsight> listCoverageInsights({String? cycleId, String? orgId}) {
    Iterable<CoverageInsight> it = _coverageInsights;
    if (cycleId != null) {
      it = it.where((item) => item.cycleId == cycleId);
    } else if (orgId != null) {
      final cycleIds = _cycles.where((c) => c.orgId == orgId).map((c) => c.cycleId).toSet();
      it = it.where((item) => cycleIds.contains(item.cycleId));
    }
    return it.toList()
      ..sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.subcategory.compareTo(b.subcategory);
      });
  }

  @override
  void replaceCoverageInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    _coverageInsights.removeWhere((item) => item.cycleId == cycleId);
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      _coverageInsights.add(
        CoverageInsight(
          insightId: row['insight_id'] as String,
          cycleId: cycleId,
          category: row['category'] as String,
          subcategory: row['subcategory'] as String,
          pillarStatus: row['pillar_status'] as String,
          clusterCurrent: row['cluster_current'] as int,
          clusterTarget: row['cluster_target'] as int,
          coverage: row['coverage'] as String,
          priority: row['priority'] as String,
          metaJson: jsonEncode(row['meta'] ?? <String, Object?>{}),
          createdAt: now,
        ),
      );
    }
    unawaited(_put('/cycles/$cycleId/coverage-insights', {'rows': rows}));
  }

  @override
  List<RecommendationInsight> listRecommendationInsights({String? cycleId, String? orgId}) {
    Iterable<RecommendationInsight> it = _recommendationInsights;
    if (cycleId != null) {
      it = it.where((item) => item.cycleId == cycleId);
    } else if (orgId != null) {
      final cycleIds = _cycles.where((c) => c.orgId == orgId).map((c) => c.cycleId).toSet();
      it = it.where((item) => cycleIds.contains(item.cycleId));
    }
    return it.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void replaceRecommendationInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    _recommendationInsights.removeWhere((item) => item.cycleId == cycleId);
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      _recommendationInsights.add(
        RecommendationInsight(
          insightId: row['insight_id'] as String,
          cycleId: cycleId,
          title: row['title'] as String,
          status: row['status'] as String,
          priority: row['priority'] as String,
          owner: row['owner'] as String,
          metaJson: jsonEncode(row['meta'] ?? <String, Object?>{}),
          createdAt: now,
        ),
      );
    }
    unawaited(_put('/cycles/$cycleId/recommendation-insights', {'rows': rows}));
  }

  @override
  void insertArtifact({
    required String artifactId,
    required String cycleId,
    required String kind,
    required String path,
    required Map<String, Object?> meta,
  }) {
    _artifacts.add(
      Artifact(
        artifactId: artifactId,
        cycleId: cycleId,
        kind: kind,
        path: path,
        metaJson: jsonEncode(meta),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(
      _post('/artifacts', {
        'artifact_id': artifactId,
        'cycle_id': cycleId,
        'kind': kind,
        'path': path,
        'meta': meta,
      }),
    );
  }

  @override
  List<Artifact> listArtifacts({String? orgId}) {
    final out = orgId == null
        ? [..._artifacts]
        : _artifacts.where((a) => _cycles.any((c) => c.cycleId == a.cycleId && c.orgId == orgId)).toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> _post(String path, Map<String, Object?> payload) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('POST $path failed: HTTP ${response.statusCode}');
    }
  }

  Future<void> _put(String path, Map<String, Object?> payload) async {
    final response = await _client.put(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PUT $path failed: HTTP ${response.statusCode}');
    }
  }
}
