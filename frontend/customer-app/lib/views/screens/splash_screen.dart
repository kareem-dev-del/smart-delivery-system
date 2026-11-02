import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _loadBarController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _pulseScale;
  late final Animation<double> _loadBar;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _pulseScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadBar = CurvedAnimation(
      parent: _loadBarController,
      curve: Curves.easeInOut,
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    _fadeController.forward();
    _loadBarController.forward();

    await _navigate();
  }

  Future<void> _navigate() async {
    final authCubit = context.read<AuthCubit>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      _awaitAuthReady(authCubit),
    ]);

    if (!mounted) return;

    final onboardingSeen =
        await AppBlocProviders.storageService.getOnboardingSeen();

    if (!mounted) return;

    if (!onboardingSeen) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    } else if (!authCubit.state.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  Future<void> _awaitAuthReady(AuthCubit authCubit) async {
    while (authCubit.state.isLoading) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _loadBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            left: -80,
            child: _GlowCircle(
              color: context.colors.primary.withValues(alpha: 0.12),
              size: 380,
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: _GlowCircle(
              color: context.colors.secondary.withValues(alpha: 0.10),
              size: 340,
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: AnimatedBuilder(
                      animation: _pulseScale,
                      builder:
                          (_, child) => Transform.scale(
                            scale: _pulseScale.value,
                            child: child,
                          ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.colors.primary, context.colors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.primary.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Brand name
                FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'ShopEase',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: context.colors.foreground,
                          letterSpacing: -1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your premium shopping experience',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.mutedForeground,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 56),

                // Load bar
                FadeTransition(
                  opacity: _textOpacity,
                  child: SizedBox(
                    width: 180,
                    child: AnimatedBuilder(
                      animation: _loadBar,
                      builder:
                          (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _loadBar.value,
                              backgroundColor: context.colors.muted,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.colors.primary,
                              ),
                              minHeight: 4,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
