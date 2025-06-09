import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageUploadService {
  final Dio _dio = Dio();

  Future<String?> uploadImage(File image) async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp');

    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path),
      });

      final response = await _dio.post(
        'http://$serverIp/api/upload',
        data: formData,
      );

      return response.data['imageUrl'];
    } catch (e) {
      if (kDebugMode) print('Upload failed: $e');
      return null;
    }
  }

  Future<List<String>> batchUpload(List<File> images) async {
    final successes = <String>[];
    
    for (final image in images) {
      final url = await uploadImage(image);
      if (url != null) successes.add(url);
    }

    return successes;
  }
}