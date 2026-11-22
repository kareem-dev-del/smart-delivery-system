import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/views/screens/courier_home_screen.dart';
import 'package:shopease_mobile/views/screens/main_scaffold.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.user?.role == 'customer') {
          return _PushRegistrationGate(
            key: ValueKey(state.user!.id),
            courierMode: false,
            child: const MainScaffold(),
          );
        }
        if (state.user?.role == 'courier') {
          return _PushRegistrationGate(
            key: ValueKey(state.user!.id),
            courierMode: true,
            child: CourierHomeScreen(service: AppBlocProviders.courierService),
          );
        }
        return const _UnsupportedMobileRoleScreen();
      },
    );
  }
}

class _PushRegistrationGate extends StatefulWidget {
  const _PushRegistrationGate({
    super.key,
    required this.courierMode,
    required this.child,
  });

  final bool courierMode;
  final Widget child;

  @override
  State<_PushRegistrationGate> createState() => _PushRegistrationGateState();
}

class _PushRegistrationGateState extends State<_PushRegistrationGate> {
  StreamSubscription<RemoteMessage>? _openedSubscription;

  @override
  void initState() {
    super.initState();
    AppBlocProviders.pushNotificationService.registerCurrentDevice();
    if (Firebase.apps.isNotEmpty) {
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _openInbox(),
      );
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _openInbox();
      });
    }
  }

  void _openInbox() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.notifications, arguments: widget.courierMode);
  }

  @override
  void dispose() {
    _openedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UnsupportedMobileRoleScreen extends StatelessWidget {
  const _UnsupportedMobileRoleScreen();

  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthCubit>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 42,
                color: colors.secondary,
              ),
              const SizedBox(height: 14),
              Text(
                'This account uses the admin dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign out and use the web dashboard to manage the delivery network.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedForeground),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
