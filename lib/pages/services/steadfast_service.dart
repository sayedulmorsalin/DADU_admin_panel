import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SteadfastService {
  final String _baseUrl = 'https://portal.packzy.com/api/v1';

  Future<Map<String, dynamic>> createOrder({
    required String invoice,
    required String recipientName,
    required String recipientPhone,
    required String recipientAddress,
    required double codAmount,
    String? note,
    String? itemDescription,
  }) async {
    final String? apiKey = dotenv.env['steadFast_API_Key'];
    final String? secretKey = dotenv.env['steadFast_Secret_Key'];

    if (apiKey == null || secretKey == null) {
      throw Exception('Steadfast API Key or Secret Key not found in .env');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/create_order'),
      headers: {
        'Api-Key': apiKey,
        'Secret-Key': secretKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'invoice': invoice,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'recipient_address': recipientAddress,
        'cod_amount': codAmount,
        'note': note ?? '',
        'item_description': itemDescription ?? '',
      }),
    );

    dynamic responseData;
    try {
      responseData = jsonDecode(response.body);
    } catch (e) {
      // If response is not JSON, it's likely a plain text error from the server
      throw Exception(response.body.isNotEmpty ? response.body : 'Server returned an invalid response (not JSON)');
    }

    if (response.statusCode == 200) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to create order in Steadfast');
    }
  }
}
