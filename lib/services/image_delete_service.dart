import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dadu_admin_panel/services/api_service.dart';
import 'package:dadu_admin_panel/services/image_upload_service.dart';

/// Deletes payment proof or product images.
/// Automatically handles Cloudflare R2 / Worker storage as well as legacy Cloudinary URLs.
Future<void> deleteImageFromCloudinaryUrl(String imageUrl) async {
  if (imageUrl.isEmpty) return;

  try {
    // If the image is stored on Cloudflare R2 / custom API worker (not Cloudinary)
    if (!imageUrl.contains('cloudinary.com')) {
      print('🗑️ Deleting image from Cloudflare: $imageUrl');
      await ImageUploadService().deleteImage(imageUrl);
      print('✅ Cloudflare image deleted successfully');
      return;
    }

    // Legacy Cloudinary deletion
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

    if (cloudName == null || apiKey == null || apiSecret == null) {
      print('⚠️ Cloudinary environment variables missing; skipping Cloudinary deletion.');
      return;
    }

    final uri = Uri.parse(imageUrl);
    final lastSegment = uri.pathSegments.last;
    final publicId = lastSegment.split('.').first;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    final paramsToSign = {
      'public_id': publicId,
      'timestamp': timestamp,
    };

    final sortedKeys = paramsToSign.keys.toList()..sort();
    final signingString = sortedKeys
            .map((key) => '$key=${paramsToSign[key]}')
            .join('&') +
        apiSecret;

    final signature = sha1.convert(utf8.encode(signingString)).toString();

    final deleteUri =
        'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

    final result = await ApiService().post(
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

    if (result != null && result['result'] == 'ok') {
      print('✅ Cloudinary image deleted successfully');
    } else {
      print('❌ Cloudinary response: $result');
    }
  } catch (e) {
    print('❌ Exception while deleting image ($imageUrl): $e');
  }
}

/// Helper alias for deleting payment proof images
Future<void> deletePaymentProofImage(String imageUrl) async {
  await deleteImageFromCloudinaryUrl(imageUrl);
}
