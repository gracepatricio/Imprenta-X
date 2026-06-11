import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/paymongo_service.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';

/// Handles PayMongo payment on all platforms.
///
/// On both web and mobile the checkout URL is opened in the external browser /
/// a new tab.  A background poll (mobile) or a manual "I've Paid" button (web)
/// detects completion and returns `true` to the caller.
///
/// Using WebView on mobile caused PayMongo to flag sessions as expired because
/// it detects embedded browsers and blocks GCash / Maya deep-links.
class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String linkId;
  final String orderId;
  final double payAmount;
  /// True when paying a remaining balance (not an initial cart checkout).
  final bool isBalancePayment;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.linkId,
    required this.orderId,
    required this.payAmount,
    this.isBalancePayment = false,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen>
    with WidgetsBindingObserver {
  bool _opened    = false;
  bool _checking  = false;
  bool _hasPopped = false;  // guards against double-pop race condition
  String? _message;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    // Auto-open the payment page immediately on all platforms so the user
    // doesn't need to manually tap the button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPaymentUrl());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  /// Fires when the user switches back to this app/tab after paying.
  /// Checks payment status immediately — don't wait for the next poll tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checking && mounted) {
      _checkPayment();
    }
  }

  /// Pops exactly once. Guards against the race where the polling timer and
  /// didChangeAppLifecycleState both detect 'paid' and both try to pop.
  void _popPaid() {
    if (_hasPopped || !mounted) return;
    _hasPopped = true;
    _poll?.cancel();
    Navigator.of(context).pop(true);
  }

  /// Called directly from button onPressed — NO await before this call.
  /// Keeps the browser's user-gesture context alive so pm.link is treated
  /// as user-initiated (critical for Firefox bounce-tracker protection).
  void _openPaymentUrl() {
    file_utils.openUrlSync(widget.checkoutUrl);
    if (mounted) setState(() => _opened = true);
  }

  void _startPolling() {
    _poll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _hasPopped) return;
      try {
        final status = await PayMongoService.getLinkStatus(widget.linkId);
        if (status == 'paid') _popPaid();
      } catch (_) {}
    });
  }

  Future<void> _checkPayment() async {
    if (_hasPopped) return;
    _poll?.cancel();
    setState(() { _checking = true; _message = null; });
    try {
      final status = await PayMongoService.getLinkStatus(widget.linkId);
      if (!mounted) return;
      if (status == 'paid') {
        _popPaid();
      } else {
        _startPolling(); // resume polling
        setState(() {
          _checking = false;
          _message  = 'Payment not yet detected. Finish payment in the browser '
              'then tap "I\'ve Paid" again.';
        });
      }
    } catch (e) {
      _startPolling();
      if (mounted) {
        setState(() {
          _checking = false;
          _message  = 'Could not verify payment: $e';
        });
      }
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text('Leave payment?',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text(
          widget.isBalancePayment
              ? 'You can pay the remaining balance anytime from My Orders.'
              : 'Payment cancelled — your cart items will remain unchanged.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: AppTheme.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              final leave = await _confirmLeave();
              if (leave && mounted) Navigator.of(context).pop(false);
            },
          ),
          title: const Text('Complete Payment',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.35), width: 2),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppTheme.gold, size: 38),
                ),
                const SizedBox(height: 22),

                Text(
                  '₱${widget.payAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.gold, fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(widget.orderId,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 28),

                // Steps
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      _Step(
                        number: '1',
                        text: _opened
                            ? kIsWeb
                                ? 'Payment page opened in a new tab'
                                : 'PayMongo checkout opened'
                            : kIsWeb
                                ? 'Opening payment page in a new tab…'
                                : 'Tap "Open Payment Page" below to start',
                        done: _opened,
                      ),
                      const SizedBox(height: 12),
                      const _Step(
                        number: '2',
                        text: 'Complete payment via GCash, Maya, or card '
                            '(scan the QR or enter details)',
                      ),
                      const SizedBox(height: 12),
                      _Step(
                        number: '3',
                        text: kIsWeb
                            ? 'After paying, come back to this tab — '
                                'your order confirms automatically'
                            : 'After paying, close the payment page — '
                                'your order will be confirmed automatically',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error / info message
                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(_message!,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                ],

                // "I've Paid" button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _checkPayment,
                    icon: _checking
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _checking
                          ? 'Checking payment…'
                          : kIsWeb ? "I've Paid" : "Check Payment Status",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: AppTheme.primaryButton(),
                  ),
                ),
                const SizedBox(height: 12),

                // Open / Reopen button — calls _openPaymentUrl() synchronously
                // so the browser preserves the user-gesture context for pm.link
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openPaymentUrl,
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: Colors.white54, size: 16),
                    label: Text(
                      _opened ? 'Reopen Payment Page' : 'Open Payment Page',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                if (!kIsWeb) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for payment…',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  final bool done;

  const _Step({required this.number, required this.text, this.done = false});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: done
              ? Colors.green.withValues(alpha: 0.2)
              : AppTheme.gold.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: done
                ? Colors.green.withValues(alpha: 0.5)
                : AppTheme.gold.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: Colors.green, size: 13)
              : Text(number,
                  style: const TextStyle(color: AppTheme.gold,
                      fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: done ? 0.4 : 0.75),
                fontSize: 13,
                height: 1.4)),
      ),
    ],
  );
}
