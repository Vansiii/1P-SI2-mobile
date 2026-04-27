import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../providers/payment_provider.dart';

/// Pantalla de pago del cliente para un incidente resuelto.
class PaymentScreen extends ConsumerStatefulWidget {
  final int incidentId;
  final String? incidentDescription;

  const PaymentScreen({
    super.key,
    required this.incidentId,
    this.incidentDescription,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  bool _paymentSuccess = false;

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar Servicio'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _paymentSuccess
                          ? Icons.check_circle_outline
                          : Icons.payment_rounded,
                      size: 64,
                      color: _paymentSuccess
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _paymentSuccess
                          ? '¡Pago Exitoso!'
                          : 'Pago por Servicio',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paymentSuccess
                          ? 'Tu pago ha sido procesado correctamente'
                          : 'Incidente #${widget.incidentId}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment details (after creating intent)
            if (paymentState.paymentIntent != null && !_paymentSuccess) ...[
              _buildAmountCard(paymentState.paymentIntent!, theme),
              const SizedBox(height: 24),
            ],

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            if (!_paymentSuccess) ...[
              if (paymentState.paymentIntent == null)
                _buildInitiatePaymentButton(paymentState)
              else
                _buildConfirmPaymentButton(paymentState),
            ] else ...[
              // Success actions
              ElevatedButton.icon(
                onPressed: () {
                  final txnId = paymentState.paymentIntent?['transaction_id'];
                  if (txnId != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ReceiptScreen(transactionId: txnId),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Ver Comprobante'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Volver'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(Map<String, dynamic> intent, ThemeData theme) {
    final amount = (intent['amount'] as num?)?.toDouble() ?? 0;
    final commission = (intent['commission'] as num?)?.toDouble() ?? 0;
    final workshopAmount = (intent['workshop_amount'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalle del Pago',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow('Servicio', 'Bs. ${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Comisión plataforma (10%)',
              'Bs. ${commission.toStringAsFixed(2)}',
              isSubtle: true,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Monto para el taller',
              'Bs. ${workshopAmount.toStringAsFixed(2)}',
              isSubtle: true,
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Total a pagar',
              'Bs. ${amount.toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isSubtle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isSubtle ? Colors.grey[600] : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isSubtle ? Colors.grey[600] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInitiatePaymentButton(PaymentState state) {
    return ElevatedButton.icon(
      onPressed: state.isLoading ? null : _initiatePayment,
      icon: state.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.credit_card),
      label: Text(state.isLoading ? 'Preparando...' : 'Iniciar Pago'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildConfirmPaymentButton(PaymentState state) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _confirmPayment,
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.lock),
      label: Text(_isProcessing ? 'Procesando pago...' : 'Confirmar y Pagar'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _initiatePayment() async {
    setState(() => _errorMessage = null);

    final result = await ref
        .read(paymentProvider.notifier)
        .createPaymentIntent(widget.incidentId);

    if (result == null) {
      setState(() {
        _errorMessage =
            ref.read(paymentProvider).error ?? 'Error al crear el pago';
      });
    }
  }

  Future<void> _confirmPayment() async {
    final intent = ref.read(paymentProvider).paymentIntent;
    if (intent == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Initialize Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent['client_secret'] as String,
          merchantDisplayName: 'MecánicoYa',
          style: ThemeMode.system,
        ),
      );

      // Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded!
      setState(() {
        _isProcessing = false;
        _paymentSuccess = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pago realizado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on StripeException catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.error.localizedMessage ?? 'Error en el pago';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error inesperado: $e';
      });
    }
  }
}

/// Pantalla simple de recibo de pago
class _ReceiptScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const _ReceiptScreen({required this.transactionId});

  @override
  ConsumerState<_ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<_ReceiptScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(paymentProvider.notifier).loadReceipt(widget.transactionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final receipt = paymentState.receipt;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobante de Pago'),
        centerTitle: true,
      ),
      body: paymentState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : receipt == null
              ? const Center(child: Text('No se pudo cargar el comprobante'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 56,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pago Confirmado',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'N° ${receipt['receipt_number'] ?? ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const Divider(height: 32),
                          _receiptRow('Cliente', receipt['client_name'] ?? ''),
                          _receiptRow('Taller', receipt['workshop_name'] ?? ''),
                          _receiptRow(
                            'Incidente',
                            '#${receipt['incident_id'] ?? ''}',
                          ),
                          _receiptRow(
                            'Método',
                            (receipt['payment_method'] ?? '').toString().toUpperCase(),
                          ),
                          const Divider(height: 24),
                          _receiptRow(
                            'Monto Total',
                            'Bs. ${(receipt['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            isBold: true,
                          ),
                          const Divider(height: 24),
                          Text(
                            receipt['description'] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
