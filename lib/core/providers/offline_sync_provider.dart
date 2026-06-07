import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/db/services/sync_manager.dart';
import '../../data/db/services/conflict_resolver_service.dart';
import '../services/sync_update_service.dart';
import '../../data/services/api_service.dart';
import '../../services/api_service.dart' as api_p;
import '../../features/auth/providers/auth_provider.dart' show storageServiceProvider;

export '../../data/db/services/sync_manager.dart' show SyncStatus, SyncResult;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final storage = ref.watch(storageServiceProvider);
  final manager = SyncManager(db: db, storage: storage);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final syncUpdateServiceProvider = Provider<SyncUpdateService>((ref) {
  final apiService = ref.watch(api_p.apiServiceProvider);
  return SyncUpdateService(apiService);
});

final conflictResolverProvider = Provider<ConflictResolverService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ConflictResolverService(db: db);
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.statusStream;
});

final syncResultsProvider = StreamProvider<List<SyncResult>>((ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.resultStream;
});
