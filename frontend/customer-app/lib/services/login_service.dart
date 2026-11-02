import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/core/config/app_config.dart';
import 'package:shopease_mobile/core/utils/token_storage.dart';
import 'package:shopease_mobile/models/app_user.dart';

class LoginService {
  LoginService({required ApiClient client, required TokenStorage tokenStorage})
    : _client = client,
      _tokenStorage = tokenStorage;

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  Future<AppUser> login(String username, String password) async {
    final response = await _client.post<Map<String, dynamic>>(
      AppConfig.loginPath,
      body: {'username': username, 'password': password},
    );

    final accessToken = response['access'];
    final refreshToken = response['refresh'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const ApiException(
        message: 'The server returned invalid sign-in tokens.',
      );
    }

    await _tokenStorage.saveTokens(
      token: accessToken,
      refreshToken: refreshToken,
    );

    try {
      final userJson = await _client.get<dynamic>(AppConfig.currentUserPath);
      if (userJson is! Map<String, dynamic>) {
        throw const ApiException(
          message: 'The server returned an unexpected user response.',
        );
      }
      return AppUser.fromJson(userJson);
    } catch (_) {
      await _tokenStorage.clearToken();
      rethrow;
    }
  }
}
