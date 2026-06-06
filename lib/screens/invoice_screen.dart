import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';

// ── Business constants ─────────────────────────────────────────────────────────
const _bizName = 'IMPRENTA INC.';
const _bizTagline = 'Professional Printing Services';
const _bizAddr1 = '5th Street Pacita Avenue, Office 1 Rongavilla Building';
const _bizAddr2 = 'San Pedro, Laguna, 4023, Philippines';
const _bizTin = '010-253-357-000';

class InvoiceScreen extends StatefulWidget {
  final String invoiceId;
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
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('Invoices').doc(widget.invoiceId).get();
      if (!doc.exists) throw Exception('Invoice not found');
      var data = doc.data()!;

      // Resolve missing customer_id via order → user chain, then backfill
      if ((data['customer_id']?.toString() ?? '').isEmpty) {
        final orderId = data['order_id']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          final orderDoc = await db.collection('Orders').doc(orderId).get();
          final custUid = orderDoc.data()?['customer_uid']?.toString() ?? '';
          if (custUid.isNotEmpty) {
            final userDoc = await db.collection('User').doc(custUid).get();
            final custId = userDoc.data()?['customer_id']?.toString() ?? '';
            if (custId.isNotEmpty) {
              data = {...data, 'customer_id': custId};
              // Backfill both docs so future lookups are instant
              await Future.wait([
                doc.reference.update({'customer_id': custId}),
                if (orderDoc.exists)
                  orderDoc.reference.update({'customer_id': custId}),
              ]);
            }
          }
        }
      }

      setState(() {
        _inv = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_inv == null) return;
    final bytes = await _buildPdf(_inv!);
    if (kIsWeb) {
      await file_utils.downloadBytes(
        bytes,
        'application/pdf',
        '${widget.invoiceId}.pdf',
      );
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${widget.invoiceId}.pdf',
      );
    }
  }

  // ── PDF builder ──────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf(Map<String, dynamic> inv) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document();
    final items = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining = (inv['remaining_balance'] as num?)?.toDouble() ?? 0;
    final isFullyPaid = remaining < 0.01;
    final isCancelledPdf = inv['status']?.toString() == 'cancelled';

    String fmtDate(dynamic ts) {
      if (ts == null) return '—';
      try {
        final d = (ts as Timestamp).toDate().toLocal();
        const mo = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${mo[d.month - 1]} ${d.day}, ${d.year}';
      } catch (_) {
        return '—';
      }
    }

    String php(double v) => '₱ ${v.toStringAsFixed(2)}';

    // ── Colours ──────────────────────────────────────────────────────────────
    const navy = PdfColor.fromInt(0xFF0F1A2E);
    const navyLight = PdfColor.fromInt(0xFF1A2E4A);
    const gold = PdfColor.fromInt(0xFFE8B84B);
    const white = PdfColors.white;
    const textDark = PdfColor.fromInt(0xFF0F172A);
    const textMid = PdfColor.fromInt(0xFF475569);
    const textLight = PdfColor.fromInt(0xFF94A3B8);
    const rowAlt = PdfColor.fromInt(0xFFF8FAFC);
    const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
    const paidGreen = PdfColor.fromInt(0xFF16A34A);
    const dueTint = PdfColor.fromInt(0xFFD97706);
    const accentBg = PdfColor.fromInt(0xFFF0F9FF);

    pw.TextStyle s(pw.Font f, double sz, PdfColor c) =>
        pw.TextStyle(font: f, fontSize: sz, color: c);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header band ─────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              color: navy,
              padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left — company info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _bizName,
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 24,
                            color: gold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          _bizTagline,
                          style: s(
                            regular,
                            9,
                            const PdfColor.fromInt(0xFF94A3B8),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          height: 1,
                          width: 160,
                          color: const PdfColor.fromInt(0xFF334155),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          _bizAddr1,
                          style: s(
                            regular,
                            8.5,
                            const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                        ),
                        pw.Text(
                          _bizAddr2,
                          style: s(
                            regular,
                            8.5,
                            const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Row(
                          children: [
                            pw.Text(
                              'TIN: ',
                              style: s(
                                bold,
                                8.5,
                                const PdfColor.fromInt(0xFF94A3B8),
                              ),
                            ),
                            pw.Text(
                              _bizTin,
                              style: s(
                                regular,
                                8.5,
                                const PdfColor.fromInt(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right — invoice meta
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SALES INVOICE',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 20,
                          color: gold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _pdfMetaRow(
                        'Invoice No.',
                        inv['invoice_id']?.toString() ?? '—',
                        bold,
                        regular,
                        white,
                      ),
                      pw.SizedBox(height: 4),
                      _pdfMetaRow(
                        'Order No.',
                        inv['order_id']?.toString() ?? '—',
                        bold,
                        regular,
                        const PdfColor.fromInt(0xFFCBD5E1),
                      ),
                      pw.SizedBox(height: 4),
                      _pdfMetaRow(
                        'Date Issued',
                        fmtDate(inv['issued_date']),
                        bold,
                        regular,
                        const PdfColor.fromInt(0xFFCBD5E1),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: isCancelledPdf
                              ? const PdfColor.fromInt(0xFF7F1D1D)
                              : isFullyPaid
                              ? const PdfColor.fromInt(0xFF14532D)
                              : const PdfColor.fromInt(0xFF78350F),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          isCancelledPdf
                              ? 'CANCELLED'
                              : isFullyPaid
                              ? 'PAID IN FULL'
                              : 'PARTIAL PAYMENT',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: isCancelledPdf
                                ? const PdfColor.fromInt(0xFFFCA5A5)
                                : isFullyPaid
                                ? paidGreen
                                : dueTint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Bill To / From strip ─────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              color: accentBg,
              padding: const pw.EdgeInsets.fromLTRB(36, 16, 36, 16),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // From
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FROM', style: s(bold, 7.5, textLight)),
                        pw.SizedBox(height: 5),
                        pw.Text(_bizName, style: s(bold, 11, textDark)),
                        pw.Text(_bizAddr1, style: s(regular, 8.5, textMid)),
                        pw.Text(_bizAddr2, style: s(regular, 8.5, textMid)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'TIN: $_bizTin',
                          style: s(regular, 8.5, textMid),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Bill To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: s(bold, 7.5, textLight)),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          inv['customer_name']?.toString() ?? '—',
                          style: s(bold, 11, textDark),
                        ),
                        pw.Text(
                          inv['customer_email']?.toString() ?? '—',
                          style: s(regular, 8.5, textMid),
                        ),
                        pw.Text(
                          'ID: ${inv['customer_id']?.toString().isNotEmpty == true ? inv['customer_id'] : '—'}',
                          style: s(regular, 8.5, textMid),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body (white) ─────────────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Items table header label
                    pw.Text('ITEMS', style: s(bold, 7.5, textLight)),
                    pw.SizedBox(height: 8),

                    // Table
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(4.2),
                        1: const pw.FixedColumnWidth(44),
                        2: const pw.FixedColumnWidth(76),
                        3: const pw.FixedColumnWidth(84),
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: navy),
                          children:
                              ['DESCRIPTION', 'QTY', 'UNIT PRICE', 'AMOUNT']
                                  .map(
                                    (h) => pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: pw.Text(
                                        h,
                                        style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 8,
                                          color: gold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        // Item rows
                        ...items.asMap().entries.map((e) {
                          final idx = e.key;
                          final p = e.value;
                          final name = p['name']?.toString() ?? '—';
                          final qty = (p['qty'] as num?)?.toInt() ?? 1;
                          final unit =
                              (p['unit_price'] as num?)?.toDouble() ?? 0;
                          final sub =
                              (p['price'] as num?)?.toDouble() ?? (unit * qty);
                          final size = p['size_label']?.toString();
                          final mat = p['material']?.toString();
                          final details = [
                            if (size != null) size,
                            if (mat != null) mat,
                          ].join(' · ');
                          final bg = idx.isEven ? PdfColors.white : rowAlt;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: bg,
                              border: const pw.Border(
                                bottom: pw.BorderSide(
                                  color: rowBorder,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      name,
                                      style: s(bold, 9.5, textDark),
                                    ),
                                    if (details.isNotEmpty)
                                      pw.Text(
                                        details,
                                        style: s(italic, 8, textMid),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: pw.Text(
                                  '$qty',
                                  style: s(regular, 9.5, textDark),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: pw.Text(
                                  php(unit),
                                  style: s(regular, 9.5, textDark),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: pw.Text(
                                  php(sub),
                                  style: s(bold, 9.5, textDark),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    if (isCancelledPdf) ...[
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(
                            0xFFB91C1C,
                          ), // solid dark red background
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ORDER CANCELLED',
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 8,
                                color: PdfColors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Reason for Cancellation',
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 8.5,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              (inv['cancel_reason']?.toString().isNotEmpty ==
                                      true)
                                  ? inv['cancel_reason'].toString()
                                  : 'No reason specified.',
                              style: pw.TextStyle(
                                font: regular,
                                fontSize: 9,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],

                    pw.SizedBox(height: 12),

                    // Special instructions
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF8FAFC),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                        border: pw.Border.all(
                          color: const PdfColor.fromInt(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Special Instructions: ',
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 8.5,
                              color: textMid,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(() {
                              // Check order-level notes first
                              final orderNotes = inv['notes']?.toString() ?? '';
                              if (orderNotes.isNotEmpty) return orderNotes;
                              // Fallback: collect all non-empty product notes
                              final productNotes = items
                                  .map((p) => p['notes']?.toString() ?? '')
                                  .where((n) => n.isNotEmpty)
                                  .join('; ');
                              return productNotes.isNotEmpty
                                  ? productNotes
                                  : 'None';
                            }(), style: s(regular, 8.5, textMid)),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // Payment summary + stamp row
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Paid stamp
                        if (isFullyPaid)
                          pw.Transform.rotate(
                            angle: -0.35,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: paidGreen,
                                  width: 2.5,
                                ),
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                              ),
                              child: pw.Text(
                                'PAID',
                                style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 28,
                                  color: const PdfColor.fromInt(0x4416A34A),
                                ),
                              ),
                            ),
                          )
                        else
                          pw.SizedBox(),
                        pw.Spacer(),
                        // Summary box
                        pw.Container(
                          width: 230,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: rowBorder),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: const pw.BoxDecoration(
                                  color: navy,
                                  borderRadius: pw.BorderRadius.only(
                                    topLeft: pw.Radius.circular(7),
                                    topRight: pw.Radius.circular(7),
                                  ),
                                ),
                                child: pw.Text(
                                  'PAYMENT SUMMARY',
                                  style: s(bold, 8, gold),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(14),
                                child: pw.Column(
                                  children: [
                                    _pdfSummaryRow(
                                      'Order Total',
                                      php(total),
                                      regular,
                                      bold,
                                      textMid,
                                      textDark,
                                      false,
                                    ),
                                    pw.SizedBox(height: 7),
                                    _pdfSummaryRow(
                                      'Downpayment Paid',
                                      php(paid),
                                      regular,
                                      bold,
                                      textMid,
                                      paidGreen,
                                      false,
                                    ),
                                    pw.SizedBox(height: 7),
                                    pw.Container(height: 0.8, color: rowBorder),
                                    pw.SizedBox(height: 7),
                                    _pdfSummaryRow(
                                      isFullyPaid
                                          ? 'Balance'
                                          : 'Balance Due on Pickup',
                                      isFullyPaid ? 'Settled' : php(remaining),
                                      bold,
                                      bold,
                                      isFullyPaid ? paidGreen : dueTint,
                                      isFullyPaid ? paidGreen : dueTint,
                                      true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // Terms
                    pw.Divider(color: rowBorder),
                    pw.SizedBox(height: 8),
                    pw.Text('TERMS & CONDITIONS', style: s(bold, 7, textLight)),
                    pw.SizedBox(height: 5),
                    ...[
                      '• A minimum 50% downpayment is required to confirm and process your order.',
                      '• Remaining balance is due upon pickup. Orders will not be released until fully settled.',
                      '• No refunds or cancellations for custom-printed materials once production has started.',
                      '• For concerns, contact us through the Imprenta X app messaging system.',
                    ].map(
                      (t) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(t, style: s(italic, 7.5, textMid)),
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Footer strip
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const pw.BoxDecoration(color: rowAlt),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '$_bizName  ·  TIN: $_bizTin',
                            style: s(bold, 8, textMid),
                          ),
                          pw.Text(
                            '$_bizAddr1, $_bizAddr2',
                            style: s(regular, 7.5, textLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static pw.Widget _pdfMetaRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular,
    PdfColor valueColor,
  ) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text(
        '$label  ',
        style: pw.TextStyle(
          font: regular,
          fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B),
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor),
      ),
    ],
  );

  static pw.Widget _pdfSummaryRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont,
    PdfColor labelColor,
    PdfColor valueColor,
    bool large,
  ) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          font: labelFont,
          fontSize: large ? 10 : 8.5,
          color: labelColor,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          font: valueFont,
          fontSize: large ? 12 : 10,
          color: valueColor,
        ),
      ),
    ],
  );

  // ── In-app invoice view ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        leading: widget.fromPayment
            ? IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
                tooltip: 'View My Orders',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.invoiceId,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.fromPayment
                  ? 'Payment Confirmed ✓'
                  : 'Official Sales Invoice',
              style: const TextStyle(color: Color(0xFF334155), fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_inv != null)
            TextButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(
                Icons.download_rounded,
                color: AppTheme.gold,
                size: 18,
              ),
              label: const Text(
                'PDF',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
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
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining = (inv['remaining_balance'] as num?)?.toDouble() ?? 0;
    final isFullPaid = remaining < 0.01;
    final isCancelled = inv['status']?.toString() == 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header band ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                // Navy accent top bar
                Container(height: 4, color: const Color(0xFF1E3A5F)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company name row + INVOICE label
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _bizName,
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Text(
                                  _bizTagline,
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'OFFICIAL INVOICE',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inv['invoice_id']?.toString() ?? '—',
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? const Color(0xFFFEE2E2)
                                      : isFullPaid
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: isCancelled
                                        ? const Color(0xFFFCA5A5)
                                        : isFullPaid
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFFCD34D),
                                  ),
                                ),
                                child: Text(
                                  isCancelled
                                      ? 'CANCELLED'
                                      : isFullPaid
                                      ? 'PAID IN FULL'
                                      : 'PARTIAL PAYMENT',
                                  style: TextStyle(
                                    color: isCancelled
                                        ? const Color(0xFFDC2626)
                                        : isFullPaid
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Business address + TIN row
                      const SizedBox(height: 14),
                      Container(height: 1, color: const Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$_bizAddr1, $_bizAddr2',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'TIN: ',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            _bizTin,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Invoice meta cards ──────────────────────────────────────────────
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetaCard(
                        icon: Icons.receipt_outlined,
                        label: 'INVOICE NO.',
                        value: inv['invoice_id']?.toString() ?? '—',
                        highlight: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetaCard(
                        icon: Icons.shopping_bag_outlined,
                        label: 'ORDER NO.',
                        value: inv['order_id']?.toString() ?? '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetaCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'DATE ISSUED',
                        value: _fmtDate(inv['issued_date']),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetaCard(
                        icon: Icons.badge_outlined,
                        label: 'CUSTOMER ID',
                        value: inv['customer_id']?.toString().isNotEmpty == true
                            ? inv['customer_id'].toString()
                            : '—',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bill To strip ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Left accent bar
                Container(
                  width: 4,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BILL TO',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inv['customer_name']?.toString() ?? '—',
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                inv['customer_email']?.toString() ?? '—',
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 52,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ISSUED BY',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                _bizName,
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'TIN: $_bizTin',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Items ───────────────────────────────────────────────────────────
          // ── Items ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('ORDER ITEMS'),
                const SizedBox(height: 10),

                // Table card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        color: const Color(0xFF1E3A5F),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'DESCRIPTION',
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'QTY',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Item rows
                      ...items.asMap().entries.map((e) {
                        final idx = e.key;
                        final p = e.value;
                        final name = p['name']?.toString() ?? '—';
                        final qty = (p['qty'] as num?)?.toInt() ?? 1;
                        final unit = (p['unit_price'] as num?)?.toDouble() ?? 0;
                        final sub =
                            (p['price'] as num?)?.toDouble() ?? (unit * qty);
                        final size = p['size_label']?.toString();
                        final mat = p['material']?.toString();
                        final notes = p['notes']?.toString() ?? '';
                        final isLast = idx == items.length - 1;
                        return Container(
                          decoration: BoxDecoration(
                            color: idx.isEven
                                ? const Color(0xFFF8FAFC)
                                : Colors.white,
                            border: Border(
                              bottom: isLast
                                  ? BorderSide.none
                                  : const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (size != null || mat != null)
                                      Text(
                                        [
                                          if (size != null) size,
                                          if (mat != null) mat,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '×$qty',
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${sub.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A5F),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '@ ₱${unit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // ── Special instructions (always shown before cancelled notice) ──────
                const SizedBox(height: 20),
                const _SectionLabel('SPECIAL INSTRUCTIONS'),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    // Get order-level notes from inv, fallback to first product's notes
                    final orderNotes = inv['notes']?.toString() ?? '';
                    final items2 =
                        (inv['items'] as List?)?.cast<Map<String, dynamic>>() ??
                        [];
                    final productNotes = items2.isNotEmpty
                        ? (items2.first['notes']?.toString() ?? '')
                        : '';
                    final displayNote = orderNotes.isNotEmpty
                        ? orderNotes
                        : productNotes.isNotEmpty
                        ? productNotes
                        : '';
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        displayNote.isNotEmpty
                            ? displayNote
                            : 'Special Instructions: None',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),

                if (isCancelled) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          color: Colors.redAccent,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ORDER CANCELLED',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Reason for Cancellation',
                                style: TextStyle(
                                  color: Color(0xFFE57373),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                inv['cancel_reason']?.toString().isNotEmpty ==
                                        true
                                    ? inv['cancel_reason'].toString()
                                    : 'No reason specified.',
                                style: const TextStyle(
                                  color: Color(0xFF0F1A2E),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(
                  height: 28,
                ), // ← spacing before payment summary for ALL cases
                // ── Payment summary ──────────────────────────────────────────
                const _SectionLabel('PAYMENT SUMMARY'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF1E3A5F),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: const Text(
                          'SUMMARY',
                          style: TextStyle(
                            color: AppTheme.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _PayRow(
                              label: 'Order Total',
                              value: total,
                              color: const Color(0xFF374151),
                              large: false,
                            ),
                            const SizedBox(height: 10),
                            _PayRow(
                              label: 'Downpayment Paid',
                              value: paid,
                              color: Colors.green,
                              large: false,
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                            const SizedBox(height: 10),
                            _PayRow(
                              label: isFullPaid
                                  ? 'Balance — Fully Settled'
                                  : 'Balance Due on Pickup',
                              value: isFullPaid ? 0 : remaining,
                              color: isFullPaid ? Colors.green : AppTheme.gold,
                              large: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isFullPaid) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remaining balance of ₱${remaining.toStringAsFixed(2)} '
                            'is due upon pickup.',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Terms ────────────────────────────────────────────────────
                const _SectionLabel('TERMS & CONDITIONS'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        [
                              '• Minimum 50% downpayment required to confirm and process your order.',
                              '• Remaining balance is due upon pickup. Order will not be released until fully settled.',
                              '• No refunds or cancellations once production has started.',
                              '• For concerns, message us through the Imprenta X app.',
                            ]
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Footer ───────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_bizName  ·  TIN: $_bizTin',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '$_bizAddr1, $_bizAddr2',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This is an official electronic invoice issued by Imprenta Inc.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Download button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text(
                      'Download PDF Invoice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: AppTheme.primaryButton(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1E3A5F),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

class _InvDetail extends StatelessWidget {
  final String label, value;
  const _InvDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PayRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;
  const _PayRow({
    required this.label,
    required this.value,
    required this.color,
    required this.large,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF374151),
            fontSize: large ? 13 : 12,
            fontWeight: large ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      Text(
        value < 0.01 ? 'Settled' : '₱${value.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontSize: large ? 18 : 13,
          fontWeight: large ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _MetaCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool highlight;
  const _MetaCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: highlight ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF1E3A5F)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: highlight
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFF1E293B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
