import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/repositories/auth_repository.dart';

class AuthController {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<AppUser> login(String username, String password) {
    return _authRepository.login(username, password);
  }

  Future<AppUser> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
  }) {
    return _authRepository.register(
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      passwordConfirm: passwordConfirm,
    );
  }

  Future<void> requestPasswordReset(String email) {
    return _authRepository.requestPasswordReset(email);
  }

  Future<void> logout() {
    return _authRepository.logout();
  }
}
