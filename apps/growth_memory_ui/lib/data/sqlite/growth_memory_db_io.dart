import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/artifact.dart';
import '../models/coverage_insight.dart';
import '../models/cycle.dart';
import '../models/org.dart';
import '../models/recommendation_insight.dart';
import '../models/snapshot.dart';
import 'growth_memory_db.dart';

class GrowthMemoryDbImpl implements GrowthMemoryDb {
  GrowthMemoryDbImpl._(this._db, this.dbPath);

  final Database _db;

  @override
  final String dbPath;

  static Future<GrowthMemoryDb> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    final dbPath = p.join(dir.path, 'growth_memory.db');
    final db = sqlite3.open(dbPath);
    final handle = GrowthMemoryDbImpl._(db, dbPath);
    handle._migrate();
    return handle;
  }

  @override
  void close() => _db.dispose();

  void _migrate() {
    _db.execute('''
CREATE TABLE IF NOT EXISTS orgs (
  org_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  profile_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS cycles (
  cycle_id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  cycle_type TEXT NOT NULL,
  goal TEXT NOT NULL,
  inputs_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(org_id) REFERENCES orgs(org_id)
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS snapshots (
  snapshot_id TEXT PRIMARY KEY,
  cycle_id TEXT NOT NULL,
  source TEXT NOT NULL,
  window_start TEXT NOT NULL,
  window_end TEXT NOT NULL,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(cycle_id) REFERENCES cycles(cycle_id)
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS artifacts (
  artifact_id TEXT PRIMARY KEY,
  cycle_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  path TEXT NOT NULL,
  meta_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(cycle_id) REFERENCES cycles(cycle_id)
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS coverage_insights (
  insight_id TEXT PRIMARY KEY,
  cycle_id TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  pillar_status TEXT NOT NULL,
  cluster_current INTEGER NOT NULL,
  cluster_target INTEGER NOT NULL,
  coverage TEXT NOT NULL,
  priority TEXT NOT NULL,
  meta_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(cycle_id) REFERENCES cycles(cycle_id)
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS recommendation_insights (
  insight_id TEXT PRIMARY KEY,
  cycle_id TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  priority TEXT NOT NULL,
  owner TEXT NOT NULL,
  meta_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(cycle_id) REFERENCES cycles(cycle_id)
);
''');
  }

  @override
  List<Org> listOrgs() {
    final result = _db.select('SELECT org_id, name, profile_json, created_at FROM orgs ORDER BY created_at DESC;');
    return [
      for (final row in result)
        Org(
          orgId: row['org_id'] as String,
          name: row['name'] as String,
          profileJson: row['profile_json'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  Org? getOrg(String orgId) {
    final result = _db.select(
      'SELECT org_id, name, profile_json, created_at FROM orgs WHERE org_id = ? LIMIT 1;',
      [orgId],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return Org(
      orgId: row['org_id'] as String,
      name: row['name'] as String,
      profileJson: row['profile_json'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  void upsertOrg({required String orgId, required String name, required Map<String, Object?> profile}) {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
INSERT INTO orgs(org_id, name, profile_json, created_at)
VALUES(?, ?, ?, ?)
ON CONFLICT(org_id) DO UPDATE SET
  name = excluded.name,
  profile_json = excluded.profile_json;
''',
      [orgId, name, jsonEncode(profile), createdAt],
    );
  }

  @override
  List<Cycle> listCycles({String? orgId}) {
    final sql = StringBuffer(
      'SELECT cycle_id, org_id, cycle_type, goal, inputs_json, created_at FROM cycles',
    );
    final args = <Object?>[];
    if (orgId != null) {
      sql.write(' WHERE org_id = ?');
      args.add(orgId);
    }
    sql.write(' ORDER BY created_at DESC;');

    final result = _db.select(sql.toString(), args);
    return [
      for (final row in result)
        Cycle(
          cycleId: row['cycle_id'] as String,
          orgId: row['org_id'] as String,
          cycleType: row['cycle_type'] as String,
          goal: row['goal'] as String,
          inputsJson: row['inputs_json'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  void insertCycle({
    required String cycleId,
    required String orgId,
    required String cycleType,
    required String goal,
    required Map<String, Object?> inputs,
  }) {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
INSERT INTO cycles(cycle_id, org_id, cycle_type, goal, inputs_json, created_at)
VALUES(?, ?, ?, ?, ?, ?);
''',
      [cycleId, orgId, cycleType, goal, jsonEncode(inputs), createdAt],
    );
  }

  @override
  List<Snapshot> listSnapshots({String? cycleId, String? orgId}) {
    final sql = StringBuffer(
      '''
SELECT s.snapshot_id, s.cycle_id, s.source, s.window_start, s.window_end, s.data_json, s.created_at
FROM snapshots s
JOIN cycles c ON c.cycle_id = s.cycle_id
''',
    );
    final args = <Object?>[];
    if (cycleId != null) {
      sql.write(' WHERE s.cycle_id = ?');
      args.add(cycleId);
    } else if (orgId != null) {
      sql.write(' WHERE c.org_id = ?');
      args.add(orgId);
    }
    sql.write(' ORDER BY s.created_at DESC;');

    final result = _db.select(sql.toString(), args);
    return [
      for (final row in result)
        Snapshot(
          snapshotId: row['snapshot_id'] as String,
          cycleId: row['cycle_id'] as String,
          source: row['source'] as String,
          windowStart: DateTime.parse(row['window_start'] as String),
          windowEnd: DateTime.parse(row['window_end'] as String),
          dataJson: row['data_json'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
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
    final createdAt = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
INSERT INTO snapshots(snapshot_id, cycle_id, source, window_start, window_end, data_json, created_at)
VALUES(?, ?, ?, ?, ?, ?, ?);
''',
      [
        snapshotId,
        cycleId,
        source,
        windowStart.toUtc().toIso8601String(),
        windowEnd.toUtc().toIso8601String(),
        jsonEncode(data),
        createdAt,
      ],
    );
  }

  @override
  List<CoverageInsight> listCoverageInsights({String? cycleId, String? orgId}) {
    final sql = StringBuffer(
      '''
SELECT i.insight_id, i.cycle_id, i.category, i.subcategory, i.pillar_status, i.cluster_current, i.cluster_target, i.coverage, i.priority, i.meta_json, i.created_at
FROM coverage_insights i
JOIN cycles c ON c.cycle_id = i.cycle_id
''',
    );
    final args = <Object?>[];
    if (cycleId != null) {
      sql.write(' WHERE i.cycle_id = ?');
      args.add(cycleId);
    } else if (orgId != null) {
      sql.write(' WHERE c.org_id = ?');
      args.add(orgId);
    }
    sql.write(' ORDER BY i.category, i.subcategory;');
    final result = _db.select(sql.toString(), args);
    return [
      for (final row in result)
        CoverageInsight(
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
        ),
    ];
  }

  @override
  void replaceCoverageInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    _db.execute('DELETE FROM coverage_insights WHERE cycle_id = ?;', [cycleId]);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      _db.execute(
        '''
INSERT INTO coverage_insights(insight_id, cycle_id, category, subcategory, pillar_status, cluster_current, cluster_target, coverage, priority, meta_json, created_at)
VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
        [
          row['insight_id'],
          cycleId,
          row['category'],
          row['subcategory'],
          row['pillar_status'],
          row['cluster_current'],
          row['cluster_target'],
          row['coverage'],
          row['priority'],
          jsonEncode(row['meta'] ?? <String, Object?>{}),
          now,
        ],
      );
    }
  }

  @override
  List<RecommendationInsight> listRecommendationInsights({String? cycleId, String? orgId}) {
    final sql = StringBuffer(
      '''
SELECT i.insight_id, i.cycle_id, i.title, i.status, i.priority, i.owner, i.meta_json, i.created_at
FROM recommendation_insights i
JOIN cycles c ON c.cycle_id = i.cycle_id
''',
    );
    final args = <Object?>[];
    if (cycleId != null) {
      sql.write(' WHERE i.cycle_id = ?');
      args.add(cycleId);
    } else if (orgId != null) {
      sql.write(' WHERE c.org_id = ?');
      args.add(orgId);
    }
    sql.write(' ORDER BY i.created_at DESC, i.priority;');
    final result = _db.select(sql.toString(), args);
    return [
      for (final row in result)
        RecommendationInsight(
          insightId: row['insight_id'] as String,
          cycleId: row['cycle_id'] as String,
          title: row['title'] as String,
          status: row['status'] as String,
          priority: row['priority'] as String,
          owner: row['owner'] as String,
          metaJson: row['meta_json'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  void replaceRecommendationInsights({
    required String cycleId,
    required List<Map<String, Object?>> rows,
  }) {
    _db.execute('DELETE FROM recommendation_insights WHERE cycle_id = ?;', [cycleId]);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      _db.execute(
        '''
INSERT INTO recommendation_insights(insight_id, cycle_id, title, status, priority, owner, meta_json, created_at)
VALUES(?, ?, ?, ?, ?, ?, ?, ?);
''',
        [
          row['insight_id'],
          cycleId,
          row['title'],
          row['status'],
          row['priority'],
          row['owner'],
          jsonEncode(row['meta'] ?? <String, Object?>{}),
          now,
        ],
      );
    }
  }

  @override
  List<Artifact> listArtifacts({String? orgId}) {
    final sql = StringBuffer(
      '''
SELECT a.artifact_id, a.cycle_id, a.kind, a.path, a.meta_json, a.created_at
FROM artifacts a
JOIN cycles c ON c.cycle_id = a.cycle_id
''',
    );
    final args = <Object?>[];
    if (orgId != null) {
      sql.write(' WHERE c.org_id = ?');
      args.add(orgId);
    }
    sql.write(' ORDER BY a.created_at DESC;');

    final result = _db.select(sql.toString(), args);
    return [
      for (final row in result)
        Artifact(
          artifactId: row['artifact_id'] as String,
          cycleId: row['cycle_id'] as String,
          kind: row['kind'] as String,
          path: row['path'] as String,
          metaJson: row['meta_json'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  void insertArtifact({
    required String artifactId,
    required String cycleId,
    required String kind,
    required String path,
    required Map<String, Object?> meta,
  }) {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
INSERT INTO artifacts(artifact_id, cycle_id, kind, path, meta_json, created_at)
VALUES(?, ?, ?, ?, ?, ?);
''',
      [artifactId, cycleId, kind, path, jsonEncode(meta), createdAt],
    );
  }
}
