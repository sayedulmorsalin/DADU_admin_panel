import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ImageUploadService {
  final String _accessKey = dotenv.env['R2_ACCESS_KEY']!;
  final String _secretKey = dotenv.env['R2_SECRET_KEY']!;
  final String _bucketName = dotenv.env['R2_BUCKET_NAME']!;
  final String _accountId = dotenv.env['R2_ACCOUNT_ID']!;
  final String _publicBaseUrl = dotenv.env['R2_PUBLIC_BASE_URL']!;

  /// Upload two compressed versions
  Future<Map<String, String>> uploadCompressedImages(File originalImage) async {
    final bytes5 = await _compressImage(originalImage, 15);
    final bytes20 = await _compressImage(originalImage, 50);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url5 = await _uploadToR2(bytes5, 'img5_$timestamp.jpg');
    final url20 = await _uploadToR2(bytes20, 'img20_$timestamp.jpg');

    return {'url5': url5, 'url20': url20};
  }

  /// Upload banner image
  Future<String> uploadCompressedBannerImages(File originalImage) async {
    try {
      final bytes = await _compressImage(originalImage, 50);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return await _uploadToR2(bytes, 'bnimg_$timestamp.jpg');
    } catch (e) {
      return '';
    }
  }

  /// Delete image
  Future<void> deleteImage(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    final objectKey = uri.pathSegments.last;
    await _deleteFromR2(objectKey);
  }

  /// Compress image
  Future<Uint8List> _compressImage(File file, int quality) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: quality,
      minWidth: 600,
      minHeight: 600,
    );
    return result!;
  }

  /// Upload to Cloudflare R2
  Future<String> _uploadToR2(Uint8List bytes, String fileName) async {
    final endpoint =
        'https://$_accountId.r2.cloudflarestorage.com/$_bucketName/${Uri.encodeComponent(fileName)}';

    final date = DateFormat('yyyyMMdd').format(DateTime.now().toUtc());
    final datetime =
    DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    const region = "auto";

    final contentHash = sha256.convert(bytes).toString();

    final headers = {
      'Content-Type': 'image/jpeg',
      'x-amz-acl': 'public-read',
      'x-amz-content-sha256': contentHash,
      'x-amz-date': datetime,
    };

    final canonicalHeaders = [
      'host:$_accountId.r2.cloudflarestorage.com',
      'x-amz-acl:public-read',
      'x-amz-content-sha256:$contentHash',
      'x-amz-date:$datetime',
    ]..sort();

    final signedHeaders =
    canonicalHeaders.map((e) => e.split(':')[0]).join(';');

    final canonicalRequest = [
      'PUT',
      '/$_bucketName/${Uri.encodeComponent(fileName)}',
      '',
      canonicalHeaders.join('\n'),
      '',
      signedHeaders,
      contentHash,
    ].join('\n');

    final credentialScope = '$date/$region/s3/aws4_request';

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      datetime,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(_secretKey, date, region);
    final signature = _hmacSha256(signingKey, utf8.encode(stringToSign))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');

    headers['Authorization'] =
    'AWS4-HMAC-SHA256 Credential=$_accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    final response =
    await http.put(Uri.parse(endpoint), headers: headers, body: bytes);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }

    return '$_publicBaseUrl/${Uri.encodeComponent(fileName)}';
  }

  /// Delete from R2
  Future<void> _deleteFromR2(String objectKey) async {
    final endpoint =
        'https://$_accountId.r2.cloudflarestorage.com/$_bucketName/${Uri.encodeComponent(objectKey)}';

    final date = DateFormat('yyyyMMdd').format(DateTime.now().toUtc());
    final datetime =
    DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    const region = "auto";

    final contentHash = sha256.convert([]).toString();

    final canonicalHeaders = [
      'host:$_accountId.r2.cloudflarestorage.com',
      'x-amz-content-sha256:$contentHash',
      'x-amz-date:$datetime',
    ]..sort();

    final signedHeaders =
    canonicalHeaders.map((e) => e.split(':')[0]).join(';');

    final canonicalRequest = [
      'DELETE',
      '/$_bucketName/${Uri.encodeComponent(objectKey)}',
      '',
      canonicalHeaders.join('\n'),
      '',
      signedHeaders,
      contentHash,
    ].join('\n');

    final credentialScope = '$date/$region/s3/aws4_request';

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      datetime,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(_secretKey, date, region);
    final signature = _hmacSha256(signingKey, utf8.encode(stringToSign))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');

    final headers = {
      'x-amz-content-sha256': contentHash,
      'x-amz-date': datetime,
      'Authorization':
      'AWS4-HMAC-SHA256 Credential=$_accessKey/$credentialScope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };

    final response =
    await http.delete(Uri.parse(endpoint), headers: headers);

    if (response.statusCode != 204) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  List<int> _getSignatureKey(String key, String date, String region) {
    final kDate = _hmacSha256(utf8.encode('AWS4$key'), utf8.encode(date));
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode('s3'));
    return _hmacSha256(kService, utf8.encode('aws4_request'));
  }

  List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }
}
