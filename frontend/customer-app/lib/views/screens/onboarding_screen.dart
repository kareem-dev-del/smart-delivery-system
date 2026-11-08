import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _OnboardingData {
  final String title;
  final String titleAccent;
  final String subtitle;
  final Color accentColor;
  final Widget illustration;

  const _OnboardingData({
    required this.title,
    required this.titleAccent,
    required this.subtitle,
    required this.accentColor,
    required this.illustration,
  });
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _floatController;
  int _currentPage = 0;

  late final List<_OnboardingData> _pages;
  bool _pagesInitialized = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // بننقل بناء الـ_pages هنا لأنها بتعتمد على context.colors (اللي بتعمل
    // Theme.of(context) تحت السطح)، وده ممنوع نستخدمه في initState() لسه
    // الـInheritedWidget (Theme) لسه مش متاح بشكل كامل في اللحظة دي.
    if (!_pagesInitialized) {
      _pages = [
        _OnboardingData(
          title: 'Discover Amazing',
          titleAccent: 'Products',
          subtitle:
              'Explore thousands of products across all categories. Find exactly what you\'re looking for with smart search and personalized picks.',
          accentColor: context.colors.primary,
          illustration: _DiscoverIllustration(animation: _floatController),
        ),
        _OnboardingData(
          title: 'Easy & Secure',
          titleAccent: 'Checkout',
          subtitle:
              'Pay with confidence using multiple secure payment methods. Your transactions are always encrypted and protected.',
          accentColor: context.colors.secondary,
          illustration: _CheckoutIllustration(animation: _floatController),
        ),
        _OnboardingData(
          title: 'Fast Delivery',
          titleAccent: 'To Your Door',
          subtitle:
              'Track your orders in real-time. Get same-day delivery on selected items and never miss a package again.',
          accentColor: const Color(0xFF22C55E),
          illustration: _DeliveryIllustration(animation: _floatController),
        ),
      ];
      _pagesInitialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await AppBlocProviders.storageService.setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    opacity: isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: TextButton(
                      onPressed: isLast ? null : _finishOnboarding,
                      style: TextButton.styleFrom(
                        backgroundColor: page.accentColor.withValues(alpha: 0.09),
                        foregroundColor: page.accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Illustration PageView ───────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(child: _pages[i].illustration),
                  );
                },
              ),
            ),

            // ── Text content ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder:
                    (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                child: _TextContent(
                  key: ValueKey(_currentPage),
                  data: page,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Dots + button row ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ProgressDots(
                        count: _pages.length,
                        current: _currentPage,
                        accentColor: page.accentColor,
                      ),
                      _NextButton(
                        accentColor: page.accentColor,
                        isLast: isLast,
                        onTap: _nextPage,
                      ),
                    ],
                  ),
                  if (isLast) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _finishOnboarding,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(color: context.colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'I already have an account',
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text block ───────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  const _TextContent({super.key, required this.data});
  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.colors.foreground,
              height: 1.25,
            ),
            children: [
              TextSpan(text: '${data.title}\n'),
              TextSpan(
                text: data.titleAccent,
                style: TextStyle(color: data.accentColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.subtitle,
          style: TextStyle(
            fontSize: 15,
            color: context.colors.mutedForeground,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ─── Progress dots ────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.current,
    required this.accentColor,
  });
  final int count;
  final int current;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: isActive ? accentColor : context.colors.border,
          ),
        );
      }),
    );
  }
}

// ─── Next button ──────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.accentColor,
    required this.isLast,
    required this.onTap,
  });
  final Color accentColor;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isLast ? 160 : 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isLast ? 16 : 99),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentColor, Color.lerp(accentColor, Colors.white, 0.25)!],
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLast)
              const Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (isLast) const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ILLUSTRATIONS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Page 1: Discover ────────────────────────────────────────────────────────

class _DiscoverIllustration extends StatelessWidget {
  const _DiscoverIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final float = (animation.value - 0.5) * 14;
        return Transform.translate(
          offset: Offset(0, float),
          child: SizedBox(
            width: 320,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background glow
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.primary.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Back-left card
                Positioned(
                  left: 16,
                  top: 48,
                  child: Transform.rotate(
                    angle: -0.14,
                    child: _ProductCard(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.secondary.withValues(alpha: 0.8),
                          const Color(0xFF9C8FFF),
                        ],
                      ),
                      width: 110,
                      height: 150,
                    ),
                  ),
                ),

                // Back-right card
                Positioned(
                  right: 16,
                  top: 56,
                  child: Transform.rotate(
                    angle: 0.14,
                    child: _ProductCard(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.primary.withValues(alpha: 0.75),
                          const Color(0xFFFF8E53),
                        ],
                      ),
                      width: 105,
                      height: 140,
                    ),
                  ),
                ),

                // Front main card
                _ProductCard(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white],
                  ),
                  width: 130,
                  height: 178,
                  isMain: true,
                ),

                // ✅ Check badge (top-left)
                Positioned(
                  top: 18,
                  left: 10,
                  child: _FloatingBadge(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF22C55E),
                    label: 'In Stock',
                    sublabel: 'Ready to ship',
                  ),
                ),

                // % Discount badge (top-right)
                Positioned(
                  top: 14,
                  right: 8,
                  child: _FloatingBadge(
                    icon: Icons.local_offer_rounded,
                    iconColor: context.colors.primary,
                    label: '30% OFF',
                    sublabel: 'Limited time',
                  ),
                ),

                // Sparkles
                const Positioned(
                  bottom: 36,
                  left: 24,
                  child: _Sparkle(color: Color(0xFFFFB800), size: 14),
                ),
                Positioned(
                  bottom: 50,
                  right: 20,
                  child: _Sparkle(color: context.colors.secondary, size: 10),
                ),
                Positioned(
                  top: 38,
                  left: 132,
                  child: _Sparkle(color: context.colors.primary, size: 8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.gradient,
    required this.width,
    required this.height,
    this.isMain = false,
  });
  final LinearGradient gradient;
  final double width;
  final double height;
  final bool isMain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: (isMain ? context.colors.primary : gradient.colors.first)
                .withValues(alpha: isMain ? 0.2 : 0.25),
            blurRadius: isMain ? 28 : 12,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isMain
          ? _MainCardContent()
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: height * 0.52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: width * 0.65,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: width * 0.45,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: width * 0.55,
                    height: 9,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MainCardContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFFF0F0),
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [context.colors.primary, Color(0xFFFF8E53)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Stars
          Row(
            children: List.generate(
              5,
              (_) => const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB800),
                size: 11,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 85,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: context.colors.foreground.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: context.colors.mutedForeground.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: context.colors.primary.withValues(alpha: 0.9),
                ),
                child: const Center(
                  child: Text(
                    '\$49.99',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primary,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Page 2: Checkout ────────────────────────────────────────────────────────

class _CheckoutIllustration extends StatelessWidget {
  const _CheckoutIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final float = (animation.value - 0.5) * 14;
        return Transform.translate(
          offset: Offset(0, float),
          child: SizedBox(
            width: 300,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.secondary.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Phone shell
                Container(
                  width: 170,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.secondary.withValues(alpha: 0.18),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border.all(color: context.colors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.secondary,
                                Color(0xFF9C8FFF),
                              ],
                            ),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 14),
                              Text(
                                'Checkout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                            ],
                          ),
                        ),

                        // Screen content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order summary card
                                _PhoneCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order Summary',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: context.colors.mutedForeground,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: const Color(0xFFFFF0F0),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.inventory_2_rounded,
                                                size: 14,
                                                color: context.colors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: 6,
                                                  width: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                    color: context.colors.foreground
                                                        .withValues(alpha: 0.55),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  height: 5,
                                                  width: 42,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                    color: context.colors.mutedForeground
                                                        .withValues(alpha: 0.4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: context.colors.foreground,
                                            ),
                                          ),
                                          Text(
                                            '\$89.99',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: context.colors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Card
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        context.colors.secondary,
                                        Color(0xFF9C8FFF),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          color: Colors.white30,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Visa •••• 4242',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Place order
                                Container(
                                  width: double.infinity,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF22C55E),
                                        Color(0xFF16A34A),
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Place Order',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Secure badge
                Positioned(
                  right: 4,
                  top: 80,
                  child: _FloatingBadge(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF22C55E),
                    label: 'Secure',
                    sublabel: 'Payment',
                  ),
                ),

                // Safe badge
                Positioned(
                  left: 4,
                  bottom: 80,
                  child: _FloatingBadge(
                    icon: Icons.verified_rounded,
                    iconColor: context.colors.secondary,
                    label: '100% Safe',
                    sublabel: 'Guaranteed',
                  ),
                ),

                // Sparkles
                Positioned(
                  top: 24,
                  left: 30,
                  child: _Sparkle(color: const Color(0xFFFFB800), size: 14),
                ),
                Positioned(
                  bottom: 32,
                  right: 18,
                  child: _Sparkle(color: context.colors.primary, size: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Page 3: Delivery ────────────────────────────────────────────────────────

class _DeliveryIllustration extends StatelessWidget {
  const _DeliveryIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final float = (animation.value - 0.5) * 14;
        return Transform.translate(
          offset: Offset(0, float),
          child: SizedBox(
            width: 320,
            height: 280,
            child: Stack(
              children: [
                // Background glow
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF22C55E).withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Road
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        5,
                        (_) => Container(
                          width: 28,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // House
                Positioned(
                  right: 20,
                  bottom: 70,
                  child: _HouseWidget(),
                ),

                // Truck
                Positioned(
                  left: 16,
                  bottom: 62,
                  child: _TruckWidget(),
                ),

                // Progress track
                Positioned(
                  bottom: 26,
                  left: 24,
                  right: 24,
                  child: _DeliveryProgressBar(),
                ),

                // ETA badge
                Positioned(
                  top: 16,
                  left: 10,
                  child: _FloatingBadge(
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF22C55E),
                    label: 'Today!',
                    sublabel: 'Est. 2–4 hrs',
                    iconBgColor: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  ),
                ),

                // Location pin
                Positioned(
                  right: 50,
                  bottom: 118,
                  child: SizedBox(
                    width: 28,
                    height: 34,
                    child: CustomPaint(
                      painter: _LocationPinPainter(context.colors.primary),
                    ),
                  ),
                ),

                // Sparkles
                const Positioned(
                  top: 40,
                  right: 20,
                  child: _Sparkle(color: Color(0xFFFFB800), size: 14),
                ),
                Positioned(
                  bottom: 100,
                  left: 18,
                  child: _Sparkle(color: context.colors.secondary, size: 9),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TruckWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      height: 70,
      child: Stack(
        children: [
          // Trailer
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 100,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: context.colors.primary,
                  ),
                  child: const Center(
                    child: Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
          // Cabin
          Positioned(
            left: 0,
            top: 8,
            child: Container(
              width: 62,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF16803A),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
          // Speed lines
          ...List.generate(
            3,
            (i) => Positioned(
              left: 0,
              top: 22.0 + i * 9,
              child: Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          // Wheels
          Positioned(
            bottom: 0,
            left: 20,
            child: _Wheel(),
          ),
          Positioned(
            bottom: 0,
            right: 14,
            child: _Wheel(),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A2E),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF374151),
          ),
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 88,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Body
          Positioned(
            bottom: 0,
            child: Container(
              width: 72,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [context.colors.secondary, Color(0xFF8B85FF)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Windows row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Window(),
                      _Window(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Door
                  Container(
                    width: 20,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Roof
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(80, 30),
              painter: _RoofPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Window extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.white30,
      ),
    );
  }
}

class _DeliveryProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: 0.65,
            minHeight: 5,
            backgroundColor: context.colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dispatched',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'On the way',
              style: TextStyle(
                fontSize: 9,
                color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Delivered',
              style: TextStyle(fontSize: 9, color: context.colors.mutedForeground),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    this.iconBgColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor ?? iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.foreground,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 8.5,
                  color: context.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome_rounded, color: color, size: size);
  }
}

// ─── Custom painters ──────────────────────────────────────────────────────────

class _RoofPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A3FCC)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(-4, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width + 4, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LocationPinPainter extends CustomPainter {
  _LocationPinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.width / 2),
        radius: size.width / 2,
      ))
      ..moveTo(size.width / 2 - 6, size.width / 2 + 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + 6, size.width / 2 + 2)
      ..close();
    canvas.drawPath(path, paint);
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.width / 2),
      size.width / 4,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
