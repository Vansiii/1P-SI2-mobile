import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/db/app_database.dart';

class EvidenceOfflineItem {
  final String clientEvidenceId;
  final String localFilePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String? clientOperationId;
  final String? dependsOnOperationId;
  final int queuedAt;
  final int? userId;

  const EvidenceOfflineItem({
    required this.clientEvidenceId,
    required this.localFilePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.clientOperationId,
    this.dependsOnOperationId,
    required this.queuedAt,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'client_evidence_id': clientEvidenceId,
        'local_file_path': localFilePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize,
        'client_operation_id': clientOperationId,
        'client_incident_id': dependsOnOperationId,
        'queued_at': queuedAt,
      };

  factory EvidenceOfflineItem.fromJson(Map<String, dynamic> json) {
    return EvidenceOfflineItem(
      clientEvidenceId: json['client_evidence_id'] as String,
      localFilePath: json['local_file_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: json['file_size'] as int,
      clientOperationId: json['client_operation_id'] as String?,
      dependsOnOperationId: json['client_incident_id'] as String?,
      queuedAt: json['queued_at'] as int,
    );
  }
}

/// Cola de evidencias multimedia para modo offline.
/// Almacena metadata en Drift (offline_operations) en vez de SharedPreferences.
class EvidenceOfflineQueue {
  static const _maxItems = 5;

  Future<List<EvidenceOfflineItem>> getAll() async {
    try {
      final db = AppDatabase();
      final ops = await db.offlineQueueDao.getPending();
      final items = <EvidenceOfflineItem>[];
      for (final op in ops) {
        if (op.operationType == 'UPLOAD_EVIDENCE') {
          try {
            final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
            items.add(EvidenceOfflineItem(
              clientEvidenceId: op.clientOperationId,
              localFilePath: payload['local_file_path'] as String? ?? '',
              fileName: payload['file_name'] as String? ?? 'unknown',
              mimeType: payload['mime_type'] as String? ?? 'application/octet-stream',
              fileSize: payload['file_size'] as int? ?? 0,
              clientOperationId: op.clientOperationId,
              dependsOnOperationId: payload['depends_on_operation_id'] as String?,
              queuedAt: op.createdAtClient.millisecondsSinceEpoch,
              userId: op.userId,
            ));
          } catch (_) {}
        }
      }
      return items;
    } catch (e) {
      debugPrint('[EvidenceQueue] Error reading from Drift: $e');
      return [];
    }
  }

  Future<void> enqueue(EvidenceOfflineItem item) async {
    try {
      final items = await getAll();
      if (items.length >= _maxItems) {
        debugPrint('[EvidenceQueue] Full — dropping oldest');
        final db = AppDatabase();
        final ops = await db.offlineQueueDao.getPending();
        for (final op in ops) {
          if (op.operationType == 'UPLOAD_EVIDENCE') {
            await db.offlineQueueDao.cancelOperation(op.id);
            break;
          }
        }
      }

      final db = AppDatabase();
      final now = DateTime.now();
      final payload = {
        'local_file_path': item.localFilePath,
        'file_name': item.fileName,
        'mime_type': item.mimeType,
        'file_size': item.fileSize,
        'depends_on_operation_id': item.dependsOnOperationId,
        'queued_at': item.queuedAt,
      };

      await db.offlineQueueDao.insertOperation(OfflineOperationsCompanion.insert(
        clientOperationId: item.clientEvidenceId,
        userId: item.userId ?? 0,
        operationType: 'UPLOAD_EVIDENCE',
        entityType: const Value('evidence'),
        payloadJson: jsonEncode(payload),
        createdAtClient: Value(now),
        updatedAtClient: Value(now),
      ));

      if (item.dependsOnOperationId != null) {
        await db.offlineQueueDao.insertDependency(
          parentOperationId: item.dependsOnOperationId!,
          childOperationId: item.clientEvidenceId,
        );
      }

      debugPrint('[EvidenceQueue] Enqueued: ${item.fileName}');
    } catch (e) {
      debugPrint('[EvidenceQueue] Error enqueuing: $e');
    }
  }

  Future<void> remove(String clientEvidenceId) async {
    try {
      final db = AppDatabase();
      final op = await db.offlineQueueDao.getByClientOperationId(clientEvidenceId);
      if (op != null) {
        await db.offlineQueueDao.cancelOperation(op.id);
      }
    } catch (e) {
      debugPrint('[EvidenceQueue] Error removing: $e');
    }
  }

  Future<void> clear() async {
    try {
      final db = AppDatabase();
      final ops = await db.offlineQueueDao.getPending();
      for (final op in ops) {
        if (op.operationType == 'UPLOAD_EVIDENCE') {
          await db.offlineQueueDao.cancelOperation(op.id);
        }
      }
      debugPrint('[EvidenceQueue] Cleared all evidence operations');
    } catch (e) {
      debugPrint('[EvidenceQueue] Error clearing: $e');
    }
  }

  Future<int> get count async => (await getAll()).length;
}
