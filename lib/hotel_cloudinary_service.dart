import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class HotelCloudinaryService {
  const HotelCloudinaryService._();

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset =
      'rd_online_shop_products';

  static Future<String?> pickAndUploadImage({
    int imageQuality = 85,
  }) async {
    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );

    if (image == null) {
      return null;
    }

    final List<int> bytes =
        await image.readAsBytes();

    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name.isEmpty
            ? 'rd_hotel_fee_proof.jpg'
            : image.name,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String responseBody =
        await response.stream.bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed: '
        '$responseBody',
      );
    }

    final dynamic decoded =
        jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid Cloudinary response.',
      );
    }

    final String secureUrl =
        decoded['secure_url']
                ?.toString()
                .trim() ??
            '';

    if (secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary image URL was not received.',
      );
    }

    return secureUrl;
  }
}
