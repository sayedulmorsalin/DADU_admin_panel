import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dadu_admin_panel/services/api_service.dart';

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

    final Map<String, dynamic> requestBody = {
      'invoice': invoice,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'recipient_address': recipientAddress,
      'cod_amount': codAmount.toInt(),
      'note': note ?? '',
      'item_description': itemDescription ?? 'Apps Product',
    };

    final responseData = await ApiService().post(
      '$_baseUrl/create_order',
      headers: {
        'Api-Key': apiKey,
        'Secret-Key': secretKey,
      },
      body: requestBody,
    );

    if (responseData is Map) {
      final status = responseData['status'];
      if (status != null && status != 200) {
        String error = '';
        if (responseData['errors'] != null) {
          final errs = responseData['errors'];
          if (errs is Map) {
            error = errs.entries.map((e) {
              final val = e.value;
              final msgStr = val is List ? val.join(', ') : val.toString();
              return "${e.key}: $msgStr";
            }).join('\n');
          } else {
            error = errs.toString();
          }
        } else if (responseData['message'] != null) {
          error = responseData['message'].toString();
        } else {
          error = 'Error $status';
        }
        throw 'Steadfast: $error';
      }
    }
    return responseData;
  }
}
