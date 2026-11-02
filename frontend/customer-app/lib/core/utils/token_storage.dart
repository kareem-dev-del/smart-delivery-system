import 'package:shared_preferences/shared_preferences.dart';

// كان بيستخدم flutter_secure_storage قبل كده، بس ده على الأجهزة اللي
// بيحصل فيها keystore reset (شائع في Android وقت التطوير بعد إعادة تثبيت
// التطبيق) بيرجّع null بدل الـtoken المحفوظ، فالمستخدم كان مضطر يعمل
// sign in تاني كل مرة حتى لو الـsession لسه صالحة. shared_preferences
// بتخزن نفس بيانات الـuser (LocalStorageService) وده شغال بثبات، فخلّينا
// الـtokens تتخزن بنفس الطريقة عشان يفضلوا موجودين بعد إعادة فتح التطبيق
class TokenStorage {
  static const _tokenKey = 'shopease_auth_token';
  static const _refreshTokenKey = 'shopease_refresh_token';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// بيحفظ الاتنين مع بعض — عشان لو حصل أي مشكلة نص الطريق (زي انقطاع
  /// التطبيق)، الـtoken والـrefresh token متفصلش عن بعض.
  Future<void> saveTokens({required String token, String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey); // بيتمسح مع الـaccess token
  }
}