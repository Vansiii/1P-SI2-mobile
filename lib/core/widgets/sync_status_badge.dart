import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_sync_provider.dart';

class SyncStatusBadge extends ConsumerStatefulWidget {
  final Widget child;
  final bool showLabel;

  const SyncStatusBadge({
    super.key,
    required this.child,
    this.showLabel = false,
  });

  @override
  ConsumerState<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends ConsumerState<SyncStatusBadge>
    with TickerProviderStateMixin {
  bool _wasSyncing = false;
  bool _showSynced = false;
  Timer? _syncedTimer;

  late final AnimationController _pulseCtrl;
  late final AnimationController _checkCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnim = Tween(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkScale = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    _syncedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final syncStatus = syncStatusAsync.valueOrNull;

    final pending = syncStatus?.pendingCount ?? 0;
    final syncing = syncStatus?.isSyncing ?? false;
    final justSynced = !syncing && _wasSyncing && (syncStatus?.lastSyncedCount ?? 0) > 0;

    _syncPulseState(syncing);
    if (justSynced) _showSyncedCheck();

    if (_showSynced) {
      return _AnimatedWrapper(
        animation: _checkScale,
        child: Badge(
          isLabelVisible: true,
          label: Transform.scale(
            scale: _checkScale.value,
            child: const Icon(Icons.check_circle, size: 16, color: Colors.white),
          ),
          backgroundColor: Colors.green,
          smallSize: 20,
          child: widget.child,
        ),
      );
    }

    if (!isOnline) {
      return _AnimatedWrapper(
        animation: _pulseAnim,
        child: Badge(
          isLabelVisible: true,
          label: Transform.scale(
            scale: _pulseAnim.value,
            child: const Icon(Icons.cloud_off, size: 14, color: Colors.white),
          ),
          backgroundColor: Colors.grey.shade600,
          smallSize: 20,
          child: widget.child,
        ),
      );
    }

    if (syncing) {
      _wasSyncing = true;
      return _AnimatedWrapper(
        animation: _pulseAnim,
        child: Badge(
          isLabelVisible: true,
          label: Transform.scale(
            scale: _pulseAnim.value,
            child: const Icon(Icons.sync, size: 14, color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          smallSize: 20,
          child: widget.child,
        ),
      );
    }
    _wasSyncing = false;

    if (pending > 0) {
      return Badge(
        isLabelVisible: true,
        label: Text(
          pending > 9 ? '9+' : '$pending',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.orange,
        smallSize: 20,
        child: widget.child,
      );
    }

    return widget.child;
  }

  void _syncPulseState(bool isSyncing) {
    if (isSyncing && !_wasSyncing) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!isSyncing && _wasSyncing) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  void _showSyncedCheck() {
    _showSynced = true;
    _checkCtrl.forward(from: 0).then((_) {
      _syncedTimer?.cancel();
      _syncedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSynced = false);
      });
    });
  }
}

class _AnimatedWrapper extends AnimatedWidget {
  final Widget child;
  const _AnimatedWrapper(
      {required Animation<double> animation, required this.child})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) => child;
}
