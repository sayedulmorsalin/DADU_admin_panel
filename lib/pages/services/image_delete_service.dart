import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> deleteImageFromCloudinaryUrl(String imageUrl) async {
  final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
  final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
  final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

  if (cloudName == null || apiKey == null || apiSecret == null) {
    throw Exception('Cloudinary environment variables are missing');
  }

  try {
    // Extract public_id from image URL
    final uri = Uri.parse(imageUrl);
    final lastSegment = uri.pathSegments.last;
    final publicId = lastSegment.split('.').first;

    // Generate UNIX timestamp
    final timestamp =
    (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    // Parameters to sign (Cloudinary requirement)
    final paramsToSign = {
      'public_id': publicId,
      'timestamp': timestamp,
    };

    // Generate signature
    final sortedKeys = paramsToSign.keys.toList()..sort();
    final signingString = sortedKeys
        .map((key) => '$key=${paramsToSign[key]}')
        .join('&') +
        apiSecret;

    final signature =
    sha1.convert(utf8.encode(signingString)).toString();

    final deleteUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/destroy',
    );

    final response = await http.post(
      deleteUri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        ...paramsToSign,
        'api_key': apiKey,
        'signature': signature,
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['result'] == 'ok') {
        print('✅ Image deleted successfully');
      } else {
        print('❌ Cloudinary error: ${response.body}');
      }
    } else {
      print(
        '❌ Failed to delete image: ${response.statusCode} - ${response.body}',
      );
    }
  } catch (e) {
    print('❌ Exception while deleting image: $e');
  }
}
