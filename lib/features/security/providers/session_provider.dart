import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/models/session_model.dart';
import '../data/repositories/session_repository.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return SessionRepository(apiService);
});

final sessionsProvider = FutureProvider<SessionListModel>((ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return await repository.getSessions();
});

final sessionActionsProvider = Provider<SessionActions>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return SessionActions(repository, ref);
});

class SessionActions {
  final SessionRepository _repository;
  final Ref _ref;

  SessionActions(this._repository, this._ref);

  Future<void> revokeSession(String jti) async {
    await _repository.revokeSession(jti);
    // Refrescar la lista de sesiones
    _ref.invalidate(sessionsProvider);
  }

  Future<int> revokeAllSessions() async {
    final count = await _repository.revokeAllSessions();
    // Refrescar la lista de sesiones
    _ref.invalidate(sessionsProvider);
    return count;
  }
}
