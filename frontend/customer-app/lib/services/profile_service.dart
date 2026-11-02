import 'dart:io';
import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/models/app_user.dart';

class ProfileService {
  ProfileService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<AppUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/users/me',
      body: {'name': name, 'email': email},
    );
    return _readUser(response);
  }

  // [جديد]
  Future<AppUser> uploadAvatar(File imageFile) async {
    final response = await _client.uploadFile<Map<String, dynamic>>(
      '/users/me/avatar',
      fieldName: 'avatar',
      file: imageFile,
    );
    return _readUser(response);
  }

  AppUser _readUser(Map<String, dynamic> response) {
    final userJson = response['user'] ?? response['data'] ?? response;
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException(message: 'The server returned an unexpected user response.');
    }
    return AppUser.fromJson(userJson);
  }
}