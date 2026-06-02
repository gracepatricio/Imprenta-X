import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';

class InvoiceScreen extends StatefulWidget {
  final String invoiceId;
  /// When true (opened right after payment), the close button navigates back
  /// to the customer homepage Account tab so the user sees their pending order.
  final bool fromPayment;
  const InvoiceScreen({
    super.key,
    required this.invoiceId,
    this.fromPayment = false,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Map<String, dynamic>? _inv;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Invoices')
          .doc(widget.invoiceId)
          .get();
      if (!doc.exists) throw Exception('Invoice not found');
      setState(() { _inv = doc.data(); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _downloadPdf() async {
    if (_inv == null) return;
    final bytes = await _buildPdf(_inv!);
    if (kIsWeb) {
      // Web: create a blob URL and trigger browser download directly.
      // Printing.sharePdf on web only opens a print dialog, not a download.
      await file_utils.downloadBytes(bytes, 'application/pdf', '${widget.invoiceId}.pdf');
    } else {
      // Mobile: open share/print sheet so user can save or share the PDF.
      await Printing.sharePdf(bytes: bytes, filename: '${widget.invoiceId}.pdf');
    }
  }

  // ── PDF builder ──────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf(Map<String, dynamic> inv) async {
    // Noto Sans covers the Philippine Peso sign ₱ (U+20B1)
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final italic  = await PdfGoogleFonts.notoSansItalic();

    final doc   = pw.Document();
    final items = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final total     = (inv['total_amount']      as num?)?.toDouble() ?? 0;
    final paid      = (inv['amount_paid']       as num?)?.toDouble() ?? 0;
    final remaining = (inv['remaining_balance'] as num?)?.toDouble() ?? 0;
    final isFullyPaid = remaining < 0.01;

    String fmtDate(dynamic ts) {
      if (ts == null) return '—';
      try {
        final d = (ts as Timestamp).toDate().toLocal();
        const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
        return '${mo[d.month - 1]} ${d.day}, ${d.year}';
      } catch (_) { return '—'; }
    }

    String php(double v) => '₱ ${v.toStringAsFixed(2)}';

    // ── Colours ────────────────────────────────────────────────────────────────
    const darkBg    = PdfColor.fromInt(0xFF0f0f23);
    const goldColor = PdfColor.fromInt(0xFFFFD700);
    const textDark  = PdfColor.fromInt(0xFF1a1a2e);
    const textGrey  = PdfColor.fromInt(0xFF666680);
    const divider   = PdfColor.fromInt(0xFFE0E0F0);
    const paidGreen = PdfColor.fromInt(0xFF2E7D32);
    const dueTint   = PdfColor.fromInt(0xFFF57C00);

    pw.TextStyle ts({pw.Font? f, double sz = 10, PdfColor? color}) =>
        pw.TextStyle(font: f ?? regular, fontSize: sz, color: color ?? textDark);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // ── Header band ───────────────────────────────────────────────────
            pw.Container(
              decoration: const pw.BoxDecoration(color: darkBg),
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('IMPRENTA X',
                        style: pw.TextStyle(font: bold, fontSize: 22,
                            color: goldColor, letterSpacing: 2)),
                    pw.SizedBox(height: 3),
                    pw.Text('Professional Printing Services',
                        style: ts(sz: 9, color: const PdfColor.fromInt(0xFFAAAAAA))),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(font: bold, fontSize: 18, color: goldColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv['invoice_id']?.toString() ?? '—',
                        style: ts(sz: 11, color: PdfColors.white, f: bold)),
                    pw.Text('Date: ${fmtDate(inv['issued_date'])}',
                        style: ts(sz: 9, color: const PdfColor.fromInt(0xFFCCCCCC))),
                  ]),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // ── Bill To + Order Details ───────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BILL TO', style: ts(sz: 8, color: textGrey, f: bold)),
                    pw.SizedBox(height: 5),
                    pw.Text(inv['customer_name']?.toString() ?? '—',
                        style: ts(sz: 12, f: bold)),
                    pw.Text(inv['customer_email']?.toString() ?? '—',
                        style: ts(sz: 9, color: textGrey)),
                  ]),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('ORDER DETAILS', style: ts(sz: 8, color: textGrey, f: bold)),
                    pw.SizedBox(height: 5),
                    _detailRow('Order No.', inv['order_id']?.toString() ?? '—', bold, regular, textGrey, textDark),
                    _detailRow('Payment',   isFullyPaid ? 'Fully Paid' : 'Partial Payment', bold, regular, textGrey,
                        isFullyPaid ? paidGreen : dueTint),
                  ]),
                ),
              ],
            ),

            pw.SizedBox(height: 18),
            pw.Divider(color: divider, thickness: 1),
            pw.SizedBox(height: 8),

            // ── Items table ───────────────────────────────────────────────────
            pw.Text('ITEMS', style: ts(sz: 8, color: textGrey, f: bold)),
            pw.SizedBox(height: 8),

            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FixedColumnWidth(56),
                2: const pw.FixedColumnWidth(72),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5FF)),
                  children: ['DESCRIPTION', 'QTY', 'UNIT PRICE', 'AMOUNT']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: pw.Text(h, style: ts(sz: 8, f: bold, color: textGrey)),
                          ))
                      .toList(),
                ),
                ...items.map((p) {
                  final name    = p['name']?.toString() ?? '—';
                  final qty     = (p['qty'] as num?)?.toInt() ?? 1;
                  final unit    = (p['unit_price'] as num?)?.toDouble() ?? 0;
                  final sub     = (p['price'] as num?)?.toDouble() ?? (unit * qty);
                  final size    = p['size_label']?.toString();
                  final mat     = p['material']?.toString();
                  final details = [if (size != null) size, if (mat != null) mat].join(' · ');
                  return pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: divider, width: 0.5))),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text(name, style: ts(sz: 10, f: bold)),
                          if (details.isNotEmpty)
                            pw.Text(details, style: ts(sz: 8, color: textGrey)),
                        ]),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text('$qty', style: ts(sz: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(php(unit), style: ts(sz: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(php(sub), style: ts(sz: 10, f: bold)),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 16),

            // ── Payment summary ───────────────────────────────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F8FF),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: divider),
                ),
                padding: const pw.EdgeInsets.all(14),
                child: pw.Column(children: [
                  _summaryRow('Order Total', php(total), regular, bold, textGrey, textDark, false),
                  pw.SizedBox(height: 6),
                  _summaryRow('Downpayment Paid', php(paid), regular, bold, textGrey, paidGreen, false),
                  pw.Divider(color: divider, thickness: 0.8),
                  _summaryRow(
                    isFullyPaid ? 'Fully Paid' : 'Balance Due on Pickup',
                    php(remaining),
                    bold, bold,
                    isFullyPaid ? paidGreen : dueTint,
                    isFullyPaid ? paidGreen : dueTint,
                    true,
                  ),
                ]),
              ),
            ),

            pw.Spacer(),

            // ── Payment status stamp ──────────────────────────────────────────
            if (isFullyPaid)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: paidGreen, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text('PAID IN FULL',
                      style: pw.TextStyle(font: bold, fontSize: 14, color: paidGreen)),
                ),
              ),

            pw.SizedBox(height: 14),
            pw.Divider(color: divider),
            pw.SizedBox(height: 6),

            // ── Terms footer ──────────────────────────────────────────────────
            pw.Text('PAYMENT TERMS & CONDITIONS', style: ts(sz: 7, f: bold, color: textGrey)),
            pw.SizedBox(height: 4),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                '• A minimum 50% downpayment is required to confirm and process your order.',
                '• Remaining balance is due upon pickup. Orders will not be released until fully settled.',
                '• No refunds or cancellations for custom-printed materials once production has started.',
                '• For concerns, contact us through the Imprenta X app messaging system.',
              ].map((t) => pw.Text(t, style: ts(sz: 7.5, color: textGrey, f: italic))).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text('Thank you for choosing Imprenta X! — Official Electronic Invoice',
                  style: ts(sz: 8, color: textGrey)),
            ),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static pw.Widget _detailRow(String label, String value, pw.Font bold, pw.Font regular,
      PdfColor labelColor, PdfColor valueColor) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: labelColor)),
          ),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10, color: valueColor)),
        ]),
      );

  static pw.Widget _summaryRow(String label, String value, pw.Font labelFont, pw.Font valueFont,
      PdfColor labelColor, PdfColor valueColor, bool large) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: large ? 11 : 9, color: labelColor)),
        pw.Text(value, style: pw.TextStyle(font: valueFont, fontSize: large ? 13 : 10, color: valueColor)),
      ]);

  // ── In-app invoice view ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        // When opened from payment: replace default back arrow with an X that
        // pops back to the homepage (which is now on the Account/Orders tab).
        leading: widget.fromPayment
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'View My Orders',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.invoiceId,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              widget.fromPayment ? 'Payment Confirmed ✓' : 'Official Invoice',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_inv != null)
            TextButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.download_rounded, color: AppTheme.gold, size: 18),
              label: const Text('PDF', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ))
              : _InvoiceView(inv: _inv!, onDownload: _downloadPdf),
    );
  }
}

// ── In-app invoice view ────────────────────────────────────────────────────────

class _InvoiceView extends StatelessWidget {
  final Map<String, dynamic> inv;
  final VoidCallback onDownload;
  const _InvoiceView({required this.inv, required this.onDownload});

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    final items     = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total     = (inv['total_amount']      as num?)?.toDouble() ?? 0;
    final paid      = (inv['amount_paid']       as num?)?.toDouble() ?? 0;
    final remaining = (inv['remaining_balance'] as num?)?.toDouble() ?? 0;
    final isFullPaid = remaining < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1a1a2e), const Color(0xFF0f0f23)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IMPRENTA X',
                              style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                          Text('Professional Printing Services',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFullPaid
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFullPaid
                              ? Colors.green.withValues(alpha: 0.5)
                              : Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        isFullPaid ? 'PAID IN FULL' : 'PARTIAL PAYMENT',
                        style: TextStyle(
                            color: isFullPaid ? Colors.green : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _InvDetail(label: 'Invoice', value: inv['invoice_id']?.toString() ?? '—')),
                    Expanded(child: _InvDetail(label: 'Order', value: inv['order_id']?.toString() ?? '—')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InvDetail(label: 'Customer', value: inv['customer_name']?.toString() ?? '—')),
                    Expanded(child: _InvDetail(label: 'Date Issued', value: _fmtDate(inv['issued_date']))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Items ──────────────────────────────────────────────────────────
          const _SectionLabel('ORDER ITEMS'),
          const SizedBox(height: 8),
          ...items.map((p) {
            final name  = p['name']?.toString() ?? '—';
            final qty   = (p['qty'] as num?)?.toInt() ?? 1;
            final unit  = (p['unit_price'] as num?)?.toDouble() ?? 0;
            final sub   = (p['price'] as num?)?.toDouble() ?? (unit * qty);
            final size  = p['size_label']?.toString();
            final mat   = p['material']?.toString();
            final notes = p['notes']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          ['Qty: $qty', if (size != null) size, if (mat != null) mat].join(' · '),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Note: $notes',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₱${sub.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('@ ₱${unit.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── Payment summary ────────────────────────────────────────────────
          const _SectionLabel('PAYMENT SUMMARY'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
            child: Column(
              children: [
                _PayRow(label: 'Order Total', value: total, color: Colors.white, large: false),
                const SizedBox(height: 8),
                _PayRow(label: 'Downpayment Paid', value: paid, color: Colors.green, large: false),
                const Divider(color: Colors.white12, height: 20),
                _PayRow(
                  label: isFullPaid ? 'Fully Paid — No Balance' : 'Remaining Balance Due on Pickup',
                  value: isFullPaid ? 0 : remaining,
                  color: isFullPaid ? Colors.green : AppTheme.gold,
                  large: true,
                ),
              ],
            ),
          ),

          if (!isFullPaid) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remaining balance of ₱${remaining.toStringAsFixed(2)} is due upon pickup. '
                      'Bring exact amount or pay via the app.',
                      style: const TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Terms ─────────────────────────────────────────────────────────
          const _SectionLabel('PAYMENT TERMS'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.glassCard(opacity: 0.08, radius: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                '• Minimum 50% downpayment required to confirm and process your order.',
                '• Remaining balance is due upon pickup. Order will not be released until fully settled.',
                '• No refunds or cancellations once production has started.',
                '• For concerns, message us through the Imprenta X app.',
              ]
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(t,
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ── Download button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF Invoice',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: AppTheme.primaryButton(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
  );
}

class _InvDetail extends StatelessWidget {
  final String label, value;
  const _InvDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ],
  );
}

class _PayRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;
  const _PayRow({required this.label, required this.value, required this.color, required this.large});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label,
          style: TextStyle(color: Colors.white70, fontSize: large ? 13 : 12,
              fontWeight: large ? FontWeight.w600 : FontWeight.normal))),
      Text(value < 0.01 ? 'Settled' : '₱${value.toStringAsFixed(2)}',
          style: TextStyle(color: color, fontSize: large ? 18 : 13,
              fontWeight: large ? FontWeight.bold : FontWeight.w500)),
    ],
  );
}
