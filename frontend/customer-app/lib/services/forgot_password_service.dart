import 'package:shopease_mobile/core/network/api_client.dart';

class ForgotPasswordService {
  ForgotPasswordService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<void> requestReset(String email) async {
    await _client.post<dynamic>(
      '/auth/forgot-password',
      body: {'email': email},
    );
  }
}