import 'dart:convert';
import 'package:http/http.dart' as http;

class PayMongoLink {
  final String id;
  final String checkoutUrl;
  final String referenceNumber;

  const PayMongoLink({
    required this.id,
    required this.checkoutUrl,
    required this.referenceNumber,
  });
}

// All PayMongo API calls are proxied through Firebase Cloud Functions.
// This avoids CORS errors on web and keeps the secret key server-side.
class PayMongoService {
  static const _fnBase =
      'https://us-central1-imprenta-x-system.cloudfunctions.net';

  static Future<PayMongoLink> createLink({
    required double amount,
    required String description,
  }) async {
    final res = await http.post(
      Uri.parse('$_fnBase/pmCreateLink'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amount, 'description': description}),
    );

    if (res.statusCode != 200) {
      throw Exception('Payment setup failed (${res.statusCode}): ${res.body}');
    }

    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return PayMongoLink(
      id:              d['id']              as String,
      checkoutUrl:     d['checkoutUrl']     as String,
      referenceNumber: d['referenceNumber'] as String? ?? '',
    );
  }

  static Future<String> getLinkStatus(String linkId) async {
    final res = await http.get(
      Uri.parse('$_fnBase/pmGetStatus?id=$linkId'),
    );

    if (res.statusCode != 200) {
      throw Exception('Status check failed (${res.statusCode}): ${res.body}');
    }

    return jsonDecode(res.body)['status'] as String;
  }
}
