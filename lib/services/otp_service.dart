import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class OtpService {
  // ─── EmailJS credentials ──────────────────────────────────────
  static const _serviceId       = 'service_pt36ahx';
  static const _otpTemplateId   = 'template_thnx4gc';
  static const _resetTemplateId = 'template_bzfy1su';
  static const _publicKey       = '5kxmph-4UA8VI7JH2';
  // ─────────────────────────────────────────────────────────────

  static const _col           = 'email_otps';
  static const _expiryMinutes = 10;

  String _generate() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  /// Sends a 6-digit OTP via EmailJS and returns the generated code.
  /// The code is also written to Firestore for audit/expiry tracking
  /// (write-only — no Firestore read is needed to verify).
  Future<String> _send(String email, String templateId) async {
    final code   = _generate();
    final expiry = DateTime.now().add(const Duration(minutes: _expiryMinutes));

    // Write-only: used for expiry tracking. Does NOT need to be read
    // back by the client — verification happens in-memory.
    await FirebaseFirestore.instance.collection(_col).doc(email).set({
      'expiresAt': expiry.toIso8601String(),
      'used':      false,
    });

    final res = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id':  _serviceId,
        'template_id': templateId,
        'user_id':     _publicKey,
        'template_params': {
          'to_email': email,
          'passcode': code,
        },
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Email failed (${res.statusCode}): ${res.body}');
    }

    // Return the code to the caller so it can be verified in-memory
    // without requiring a Firestore read.
    return code;
  }

  /// Sends a registration verification code. Returns the 6-digit code.
  Future<String> sendOtp(String email) => _send(email, _otpTemplateId);

  /// Sends a password-reset verification code. Returns the 6-digit code.
  Future<String> sendResetOtp(String email) => _send(email, _resetTemplateId);
}
