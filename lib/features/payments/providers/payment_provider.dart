import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/api_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';

String _getErrorMessage(dynamic e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data.containsKey('detail')) {
      return data['detail'].toString();
    }
    return e.message ?? 'Error de conexión al servidor';
  }
  return e.toString();
}

// Payment state
class PaymentState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? paymentIntent;
  final List<Map<String, dynamic>> paymentHistory;
  final Map<String, dynamic>? receipt;
  final int totalPayments;

  PaymentState({
    this.isLoading = false,
    this.error,
    this.paymentIntent,
    this.paymentHistory = const [],
    this.receipt,
    this.totalPayments = 0,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? paymentIntent,
    List<Map<String, dynamic>>? paymentHistory,
    Map<String, dynamic>? receipt,
    int? totalPayments,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      paymentIntent: paymentIntent ?? this.paymentIntent,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      receipt: receipt ?? this.receipt,
      totalPayments: totalPayments ?? this.totalPayments,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final ApiService _apiService;

  PaymentNotifier(this._apiService) : super(PaymentState());

  /// Create a PaymentIntent for an incident
  Future<Map<String, dynamic>?> createPaymentIntent(int incidentId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.createPaymentIntent(
        incidentId: incidentId,
      );
      state = state.copyWith(isLoading: false, paymentIntent: result);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  /// Check payment status of an incident
  Future<Map<String, dynamic>?> checkPaymentStatus(int incidentId) async {
    try {
      final result = await _apiService.checkIncidentPaymentStatus(
        incidentId: incidentId,
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Load payment history
  Future<void> loadPaymentHistory({int page = 1, int size = 20}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.getPaymentHistory(
        page: page,
        size: size,
      );
      
      final payments = (result['payments'] as List?)
          ?.map((p) => p as Map<String, dynamic>)
          .toList() ?? [];
      
      state = state.copyWith(
        isLoading: false,
        paymentHistory: payments,
        totalPayments: result['total'] as int? ?? 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  /// Load payment receipt
  Future<Map<String, dynamic>?> loadReceipt(int transactionId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.getPaymentReceipt(
        transactionId: transactionId,
      );
      state = state.copyWith(isLoading: false, receipt: result);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return PaymentNotifier(apiService);
});

// ============================================================================
// Workshop Finance State (for technicians/workshops on mobile)
// ============================================================================

class WalletState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> movements;
  final List<Map<String, dynamic>> withdrawals;

  WalletState({
    this.isLoading = false,
    this.error,
    this.wallet,
    this.movements = const [],
    this.withdrawals = const [],
  });

  WalletState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? wallet,
    List<Map<String, dynamic>>? movements,
    List<Map<String, dynamic>>? withdrawals,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      wallet: wallet ?? this.wallet,
      movements: movements ?? this.movements,
      withdrawals: withdrawals ?? this.withdrawals,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiService _apiService;

  WalletNotifier(this._apiService) : super(WalletState());

  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.getWorkshopWallet();
      state = state.copyWith(isLoading: false, wallet: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  Future<void> loadFinancialHistory({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.getFinancialHistory(page: page);
      final movements = (result['movements'] as List?)
          ?.map((m) => m as Map<String, dynamic>)
          .toList() ?? [];
      state = state.copyWith(isLoading: false, movements: movements);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  Future<bool> requestWithdrawal({
    required double amount,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.requestWithdrawal(
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountHolder: accountHolder,
        notes: notes,
      );
      // Reload wallet after withdrawal
      await loadWallet();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<void> loadWithdrawals({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.getWorkshopWithdrawals(page: page);
      final withdrawals = (result['withdrawals'] as List?)
          ?.map((w) => w as Map<String, dynamic>)
          .toList() ?? [];
      state = state.copyWith(isLoading: false, withdrawals: withdrawals);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return WalletNotifier(apiService);
});
