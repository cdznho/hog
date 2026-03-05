import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'growth_memory_repository.dart';
import 'sqlite/growth_memory_db.dart';

final dbProvider = FutureProvider<GrowthMemoryDb>((ref) async {
  final db = await GrowthMemoryDb.openDefault();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<GrowthMemoryRepository?>((ref) {
  final dbAsync = ref.watch(dbProvider);
  final db = dbAsync.value;
  if (db == null) {
    return null;
  }
  return GrowthMemoryRepository(db);
});

final refreshTickProvider = StateProvider<int>((ref) => 0);
