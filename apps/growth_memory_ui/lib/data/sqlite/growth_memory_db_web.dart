import 'dart:convert';

import '../models/artifact.dart';
import '../models/cycle.dart';
import '../models/org.dart';
import '../models/snapshot.dart';
import 'growth_memory_db.dart';

class GrowthMemoryDbImpl implements GrowthMemoryDb {
  GrowthMemoryDbImpl._();

  static Future<GrowthMemoryDb> openDefault() async => GrowthMemoryDbImpl._();

  final Map<String, Org> _orgs = {};
  final List<Cycle> _cycles = [];
  final List<Snapshot> _snapshots = [];
  final List<Artifact> _artifacts = [];

  @override
  String get dbPath => 'in-memory (web)';

  @override
  void close() {}

  @override
  Org? getOrg(String orgId) => _orgs[orgId];

  @override
  List<Org> listOrgs() => _orgs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void upsertOrg({required String orgId, required String name, required Map<String, Object?> profile}) {
    final now = DateTime.now().toUtc();
    _orgs[orgId] = Org(orgId: orgId, name: name, profileJson: jsonEncode(profile), createdAt: now);
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
    final out = it.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
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
  }

  @override
  List<Artifact> listArtifacts({String? orgId}) {
    final out = orgId == null ? [..._artifacts] : _artifacts.where((a) => _cycles.any((c) => c.cycleId == a.cycleId && c.orgId == orgId)).toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
}
