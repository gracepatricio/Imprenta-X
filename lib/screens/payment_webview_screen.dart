import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/paymongo_service.dart';
import 'app_theme.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String linkId;
  final String orderId;
  final double payAmount;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.linkId,
    required this.orderId,
    required this.payAmount,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  @override
  Widget build(BuildContext context) {
    // webview_flutter only supports Android & iOS.
    // On web (browser), fall back to launching an external tab.
    if (kIsWeb) {
      return _WebFallback(
        checkoutUrl: widget.checkoutUrl,
        linkId:      widget.linkId,
        orderId:     widget.orderId,
        payAmount:   widget.payAmount,
      );
    }
    return _MobileWebView(
      checkoutUrl: widget.checkoutUrl,
      linkId:      widget.linkId,
      orderId:     widget.orderId,
      payAmount:   widget.payAmount,
    );
  }
}

// ── Mobile: in-app WebView with polling ──────────────────────────────────────

class _MobileWebView extends StatefulWidget {
  final String checkoutUrl;
  final String linkId;
  final String orderId;
  final double payAmount;

  const _MobileWebView({
    required this.checkoutUrl,
    required this.linkId,
    required this.orderId,
    required this.payAmount,
  });

  @override
  State<_MobileWebView> createState() => _MobileWebViewState();
}

class _MobileWebViewState extends State<_MobileWebView> {
  late final WebViewController _wvc;
  Timer? _poll;
  bool _loading = true;
  bool _paid    = false;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
    _startPolling();
  }

  void _startPolling() {
    _poll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_paid || !mounted) return;
      try {
        final status = await PayMongoService.getLinkStatus(widget.linkId);
        if (status == 'paid' && mounted) {
          _paid = true;
          _poll?.cancel();
          Navigator.of(context).pop(true);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _promptLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Leave payment?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your order is saved. Complete payment anytime from My Orders.',
          style: TextStyle(color: Colors.white70),
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
    if ((leave ?? false) && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _promptLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _promptLeave,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Secure Payment',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text(
                '${widget.orderId}  ·  ₱${widget.payAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          actions: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.gold),
                ),
              ),
          ],
        ),
        body: WebViewWidget(controller: _wvc),
      ),
    );
  }
}

// ── Web fallback: opens external tab + "I've paid" check button ───────────────

class _WebFallback extends StatefulWidget {
  final String checkoutUrl;
  final String linkId;
  final String orderId;
  final double payAmount;

  const _WebFallback({
    required this.checkoutUrl,
    required this.linkId,
    required this.orderId,
    required this.payAmount,
  });

  @override
  State<_WebFallback> createState() => _WebFallbackState();
}

class _WebFallbackState extends State<_WebFallback> {
  bool _opened   = false;
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _openTab();
  }

  Future<void> _openTab() async {
    final uri = Uri.parse(widget.checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _opened = true);
    }
  }

  Future<void> _checkPayment() async {
    setState(() { _checking = true; _message = null; });
    try {
      final status = await PayMongoService.getLinkStatus(widget.linkId);
      if (!mounted) return;
      if (status == 'paid') {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _checking = false;
          _message  = 'Payment not yet detected. Complete the payment in '
              'the browser tab and try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _message  = 'Could not verify payment: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: const Text('Cancel payment?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'Your order is saved. You can pay later from My Orders.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay', style: TextStyle(color: AppTheme.gold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
        if ((leave ?? false) && mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: const Text('Complete Payment',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // PayMongo icon area
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
                const SizedBox(height: 24),

                Text(
                  '₱${widget.payAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.orderId,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Instructions
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
                            ? 'PayMongo checkout opened in a new tab'
                            : 'Opening PayMongo checkout…',
                        done: _opened,
                      ),
                      const SizedBox(height: 12),
                      const _Step(
                        number: '2',
                        text: 'Complete payment via GCash, Maya, or card '
                            '(scan the QR or enter details)',
                      ),
                      const SizedBox(height: 12),
                      const _Step(
                        number: '3',
                        text: 'Come back here and tap "I\'ve Paid"',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

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

                // Primary: confirm payment
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
                      _checking ? 'Checking payment…' : "I've Paid",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: AppTheme.primaryButton(),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary: reopen tab
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openTab,
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: Colors.white54, size: 16),
                    label: const Text('Reopen Payment Page',
                        style: TextStyle(color: Colors.white54)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
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
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
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
