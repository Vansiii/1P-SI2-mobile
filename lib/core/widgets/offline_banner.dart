import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchanic_repair/core/providers/connectivity_provider.dart';
import 'package:merchanic_repair/core/providers/offline_sync_provider.dart';
import 'package:merchanic_repair/data/db/app_database.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  bool _wasOnline = true;
  SyncStatus _syncStatus = const SyncStatus();
  Timer? _dismissTimer;
  Timer? _driftFallbackTimer;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _startDriftFallback();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _driftFallbackTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _startDriftFallback() {
    _driftFallbackTimer?.cancel();
    _driftFallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      try {
        final db = AppDatabase();
        final count = await db.offlineQueueDao.getPendingCount();
        if (mounted && count > 0 && _syncStatus.pendingCount == 0) {
          setState(() {
            _syncStatus = _syncStatus.copyWith(pendingCount: count);
          });
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider);
    _syncStatus =
        syncStatusAsync.valueOrNull ?? _syncStatus;

    final pending = _syncStatus.pendingCount;
    final syncing = _syncStatus.isSyncing;

    final visible = !isOnline || syncing || pending > 0;

    if (visible) {
      if (_slideCtrl.isDismissed) _slideCtrl.forward();
      if (isOnline && !_wasOnline) {
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && pending == 0 && !syncing) {
            _slideCtrl.reverse();
          }
        });
      }
    } else {
      if (_slideCtrl.isCompleted) _slideCtrl.reverse();
    }
    _wasOnline = isOnline;

    final _BannerData data;
    if (!isOnline) {
      data = _BannerData(
        message: 'Sin conexión${pending > 0 ? ' • $pending pendiente(s)' : ''}',
        bg: Colors.blueGrey.shade800,
        icon: Icons.cloud_off,
      );
    } else if (syncing) {
      data = _BannerData(
        message: 'Sincronizando $pending operacione(s)...',
        bg: Colors.blue.shade700,
        icon: Icons.sync,
        action: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white.withValues(alpha: 0.9)),
        ),
      );
    } else if (pending > 0) {
      data = _BannerData(
        message: '$pending operacione(s) pendientes de sincronizar',
        bg: Colors.orange.shade700,
        icon: Icons.cloud_upload_outlined,
        action: TextButton(
          onPressed: () =>
              ref.read(syncManagerProvider).processQueue(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sincronizar',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnim,
      child: MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: data.bg,
        leading: Icon(data.icon, color: Colors.white, size: 22),
        content: Text(
          data.message,
          style:
              const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
        ),
        actions: data.action != null
            ? [data.action!]
            : <Widget>[const SizedBox.shrink()],
      ),
    );
  }
}

class _BannerData {
  final String message;
  final Color bg;
  final IconData icon;
  final Widget? action;
  const _BannerData(
      {required this.message,
      required this.bg,
      required this.icon,
      this.action});
}
