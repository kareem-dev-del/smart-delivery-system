import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopease_mobile/models/app_user.dart';
import 'package:shopease_mobile/models/cart_item.dart';

class LocalStorageService {
  static const String _userStorageKey = '@shopease_user';
  static const String _cartStorageKey = '@shopease_cart';
  static const String _onboardingSeenKey = '@shopease_onboarding_seen';
  static const String _themeModeKey = '@shopease_theme_mode';

  Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
  }

  Future<AppUser?> getUser() async {
  final prefs = await SharedPreferences.getInstance();
  final rawUser = prefs.getString(_userStorageKey);
  if (rawUser == null || rawUser.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(rawUser);
    if (decoded is! Map<String, dynamic>) {
      await prefs.remove(_userStorageKey);
      return null;
    }
    return AppUser.fromJson(decoded);
  } catch (_) {
    await prefs.remove(_userStorageKey);
    return null;
  }
}

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userStorageKey);
  }

  Future<void> saveCart(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = items.map((item) => item.toJson()).toList();
    await prefs.setString(_cartStorageKey, jsonEncode(rawList));
  }

  Future<List<CartItem>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCart = prefs.getString(_cartStorageKey);
    if (rawCart == null || rawCart.isEmpty) {
      return <CartItem>[];
    }

    final decoded = jsonDecode(rawCart) as List<dynamic>;
    return decoded
        .map((entry) => CartItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartStorageKey);
  }

  Future<bool> getOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey);
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }
}
