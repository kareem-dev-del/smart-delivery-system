import 'package:shopease_mobile/core/network/api_client.dart';
import 'package:shopease_mobile/core/network/api_error.dart';
import 'package:shopease_mobile/core/config/app_config.dart';
import 'package:shopease_mobile/core/utils/token_storage.dart';
import 'package:shopease_mobile/models/app_user.dart';

class RegisterService {
  RegisterService({
    required ApiClient client,
    required TokenStorage tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage;

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  Future<AppUser> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      AppConfig.registerPath,
      body: {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );

    final accessToken = response['access'];
    final refreshToken = response['refresh'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const ApiException(
        message: 'The server returned invalid registration tokens.',
      );
    }
    await _tokenStorage.saveTokens(
      token: accessToken,
      refreshToken: refreshToken,
    );

    final userJson = response['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'The server returned an unexpected user response.',
      );
    }

    return AppUser.fromJson(userJson);
  }
}
