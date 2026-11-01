import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/config/app_config.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/controllers/theme_controller.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenLogin,
    required this.onOpenRegister,
  });

  final VoidCallback onOpenLogin;
  final VoidCallback onOpenRegister;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final cartItems = context.select<CartCubit, int>(
          (cubit) => cubit.state.totalItems,
        );

        if (authState.isLoading) {
          return const LoadingState(message: 'Loading profile...');
        }

        if (!authState.isAuthenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.primary,
                            context.colors.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sign in to your account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Access your orders, saved items,\nand exclusive deals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onOpenLogin,
                        child: const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onOpenRegister,
                        child: const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _ThemeModeTile(),
                  ],
                ),
              ),
            ),
          );
        }

        final user = authState.user!;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.primary,
                            context.colors.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              image:
                                  user.avatarUrl != null
                                      ? DecorationImage(
                                        image: NetworkImage(
                                          '${AppConfig.apiBaseUrl}${user.avatarUrl}',
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                user.avatarUrl == null
                                    ? Center(
                                      child: Text(
                                        user.name.isNotEmpty
                                            ? user.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ), // Container
                  ), // ClipRRect
                ), // FlexibleSpaceBar
              ), // SliverAppBar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ProfileCard(
                        children: [
                          _ProfileTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.notifications),
                          ),
                          _ProfileTile(
                            icon: Icons.shopping_bag_outlined,
                            label: 'My Orders',
                            badge: null,
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.orders),
                          ),
                          _ProfileTile(
                            icon: Icons.favorite_border_rounded,
                            label: 'Wishlist',
                            badge: null,
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.wishlist),
                          ),
                          _ProfileTile(
                            icon: Icons.shopping_cart_outlined,
                            label: 'Cart',
                            badge: cartItems > 0 ? '$cartItems' : null,
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.cart),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ThemeModeTile(),
                      const SizedBox(height: 12),
                      _ProfileCard(
                        children: [
                          _ProfileTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Edit Profile',
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.editProfile),
                          ),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            label: 'Shipping Address',
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.shippingAddress),
                          ),
                          _ProfileTile(
                            icon: Icons.credit_card_outlined,
                            label: 'Payment Methods',
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.paymentMethods),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ProfileCard(
                        children: [
                          _ProfileTile(
                            icon: Icons.assignment_return_outlined,
                            label: 'Returns & Refunds',
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.returns),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ProfileCard(
                        children: [
                          _ProfileTile(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            labelColor: context.colors.destructive,
                            iconColor: context.colors.destructive,
                            onTap: () => _confirmSignOut(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.destructive,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await authCubit.logout();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children:
            children.map((child) => child).expand((child) sync* {
              yield child;
              if (child != children.last) {
                yield const Divider(height: 1, indent: 56);
              }
            }).toList(),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.labelColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          badge != null
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              : Icon(
                Icons.chevron_right_rounded,
                color: context.colors.mutedForeground,
              ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

  String _label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  IconData _icon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().state;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _showThemePicker(context, themeMode),
        leading: Icon(
          _icon(themeMode),
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          'Appearance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(_label(themeMode)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Future<void> _showThemePicker(
    BuildContext context,
    ThemeMode currentMode,
  ) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose appearance',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make ShopEase feel right for you.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 16),
                ...ThemeMode.values.map(
                  (mode) => RadioListTile<ThemeMode>(
                    value: mode,
                    groupValue: currentMode,
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                    secondary: Icon(_icon(mode)),
                    title: Text(_label(mode)),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await context.read<ThemeController>().setThemeMode(selected);
    }
  }
}
