import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/network/api_client.dart';

class PushNotificationService {
  PushNotificationService({required ApiClient client}) : _client = client;

  final ApiClient _client;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  void initialize() {
    if (Firebase.apps.isEmpty || _foregroundSubscription != null) return;
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      showForegroundMessage,
    );
  }

  Future<void> registerCurrentDevice() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _registerToken(token);
      });
    } catch (_) {
      // App notifications remain available when push permission or setup is missing.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (Firebase.apps.isEmpty) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _client.delete<Map<String, dynamic>>(
        '/api/notifications/devices/',
        queryParameters: {'token': token},
      );
    }
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  Future<void> showForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'SmartDrop order update';
    final body =
        message.notification?.body ?? 'Open the app to view the update.';
    final context = GlobalKeyHolder.messengerKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _registerToken(String token) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/notifications/devices/',
        body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
    } catch (_) {
      // The app inbox remains available if device registration is offline.
    }
  }
}

abstract final class GlobalKeyHolder {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
}
