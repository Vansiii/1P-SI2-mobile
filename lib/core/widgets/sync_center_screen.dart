import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../providers/offline_sync_provider.dart';

class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  List<OfflineOperation>? _pending;
  List<OfflineOperation>? _conflicts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase();
    final dao = db.offlineQueueDao;
    final pending = await dao.getPending();
    final conflicts = await dao.getConflicts();
    if (mounted) {
      setState(() {
        _pending = pending;
        _conflicts = conflicts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Sincronización'),
        actions: [
          if (syncStatus != null && syncStatus.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Forzar sincronización',
            onPressed: () async {
              final manager = ref.read(syncManagerProvider);
              await manager.processQueue();
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(syncStatus),
                  const SizedBox(height: 16),
                  _section(
                    'Operaciones Pendientes',
                    _pending,
                    Icons.cloud_upload_outlined,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    'Conflictos',
                    _conflicts,
                    Icons.warning_amber,
                    Colors.red,
                    isConflict: true,
                  ),
                  const SizedBox(height: 16),
                  _syncLogSection(),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(SyncStatus? status) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _row('Pendientes', '${status?.pendingCount ?? _pending?.length ?? 0}'),
            _row('Conflictos', '${status?.conflictCount ?? _conflicts?.length ?? 0}'),
            _row('Último sync',
                status?.lastSyncAt != null ? _fmt(status!.lastSyncAt!) : '—'),
            _row('Último éxito', '${status?.lastSyncedCount ?? 0} ops'),
            if (status?.lastError != null)
              Text(status!.lastError!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<OfflineOperation>? items,
    IconData icon,
    Color color, {
    bool isConflict = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text('$title (${items?.length ?? 0})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 8),
        if (items == null || items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No hay $title',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...items.map((op) => _operationTile(op, isConflict)),
      ],
    );
  }

  Widget _operationTile(OfflineOperation op, bool isConflict) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isConflict ? Colors.red.shade50 : null,
      child: ListTile(
        leading: Icon(
          isConflict ? Icons.warning_amber : Icons.hourglass_empty,
          color: isConflict ? Colors.red : Colors.orange,
        ),
        title: Text(_typeName(op.operationType),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Estado: ${_statusName(op.syncStatus)} • Retry: ${op.retryCount}/${op.maxRetries}',
                style: const TextStyle(fontSize: 12)),
            if (op.lastError != null)
              Text(op.lastError!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            if (isConflict && op.conflictMessage != null)
              Text(op.conflictMessage!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(_fmt(op.createdAtClient),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
        trailing: isConflict
            ? PopupMenuButton<String>(
                onSelected: (action) => _resolveConflict(op.id, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'retry', child: Text('Reintentar')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
                  const PopupMenuItem(value: 'acknowledge', child: Text('Aceptar')),
                ],
              )
            : null,
        onTap: isConflict ? () => _showConflictDialog(op) : null,
      ),
    );
  }

  void _showConflictDialog(OfflineOperation op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(_typeName(op.operationType), style: const TextStyle(fontSize: 16))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(op.conflictCode ?? '',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.orange.shade900)),
              ),
              const SizedBox(height: 8),
              Text(op.conflictMessage ?? 'Conflicto sin detalles'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          TextButton(
            onPressed: () {
              _resolveConflict(op.id, 'cancel');
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar operación'),
          ),
          FilledButton(
            onPressed: () {
              _resolveConflict(op.id, 'retry');
              Navigator.pop(ctx);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveConflict(int id, String action) async {
    final dao = AppDatabase().offlineQueueDao;
    switch (action) {
      case 'retry':
        await dao.updateSyncStatus(id, 'retry_pending');
        break;
      case 'cancel':
        await dao.cancelOperation(id);
        break;
      case 'acknowledge':
        await dao.updateSyncStatus(id, 'synced');
        break;
      default:
        await dao.updateSyncStatus(id, 'retry_pending');
    }
    await _load();
  }

  Widget _syncLogSection() {
    return FutureBuilder<List<SyncLog>>(
      future: AppDatabase().offlineQueueDao.getRecentSyncLogs(limit: 5),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de Sincronización',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Sin historial',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              )
            else
              ...logs.map((log) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        log.success ? Icons.check_circle : Icons.error,
                        color: log.success ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(_fmt(log.startedAt),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${log.operationsSynced} ok / ${log.operationsFailed} fail / ${log.operationsConflict} conflict',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }

  String _typeName(String type) {
    switch (type) {
      case 'CREATE_INCIDENT': return 'Crear incidente';
      case 'UPDATE_INCIDENT_STATUS': return 'Actualizar estado';
      case 'SEND_CHAT_MESSAGE': return 'Enviar mensaje';
      case 'UPDATE_LOCATION': return 'Ubicación';
      case 'SELECT_WORKSHOP': return 'Seleccionar taller';
      case 'CREATE_VEHICLE': return 'Crear vehículo';
      case 'UPDATE_VEHICLE': return 'Actualizar vehículo';
      case 'DELETE_VEHICLE': return 'Eliminar vehículo';
      case 'CANCEL_INCIDENT': return 'Cancelar incidente';
      case 'COMPLETE_INCIDENT': return 'Completar incidente';
      case 'TRACKING_START': return 'Iniciar tracking';
      case 'TRACKING_STOP': return 'Detener tracking';
      case 'BATCH_LOCATION': return 'Batch ubicaciones';
      case 'UPLOAD_EVIDENCE': return 'Subir evidencia';
      case 'REVOKE_SESSION': return 'Revocar sesión';
      default: return type;
    }
  }

  String _statusName(String s) {
    switch (s) {
      case 'pending_sync': return 'Pendiente';
      case 'syncing': return 'Sincronizando';
      case 'synced': return 'Sincronizado';
      case 'failed': return 'Fallido';
      case 'retry_pending': return 'Reintento pendiente';
      case 'conflict': return 'Conflicto';
      case 'expired': return 'Expirado';
      case 'cancelled': return 'Cancelado';
      default: return s;
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
