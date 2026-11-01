import 'package:flutter/material.dart';
import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/views/screens/cart_screen.dart';
import 'package:shopease_mobile/views/screens/category_products_screen.dart';

import '../../views/screens/all_reviews_screen.dart';
import '../../views/screens/auth/forgot_password_screen.dart';
import '../../views/screens/auth/login_screen.dart';
import '../../views/screens/auth/register_screen.dart';
import '../../views/screens/checkout_screen.dart';
import '../../views/screens/edit_profile_screen.dart';
import '../../views/screens/not_found_screen.dart';
import '../../views/screens/notifications_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/order_details_screen.dart';
import '../../views/screens/orders_screen.dart';
import '../../views/screens/payment_methods_screen.dart';
import '../../views/screens/product_details_screen.dart';
import '../../views/screens/returns_screen.dart';
import '../../views/screens/search_screen.dart';
import '../../views/screens/shipping_address_screen.dart';
import '../../views/screens/splash_screen.dart';
import '../../views/screens/track_order_screen.dart';
import '../../views/screens/wishlist_screen.dart';
import '../../views/screens/role_home_screen.dart';

import 'routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder:
              (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const RoleHomeScreen());

      case AppRoutes.login:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );

      case AppRoutes.register:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RegisterScreen(),
          transitionsBuilder: (_, anim, __, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );

      case AppRoutes.search:
        final query = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => SearchScreen(initialQuery: query),
        );

      case AppRoutes.product:
        final productId = settings.arguments as String?;
        if (productId == null || productId.isEmpty) {
          return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
        return MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: productId),
        );

      case AppRoutes.allReviews:
        final args = settings.arguments as AllReviewsArgs?;
        if (args == null) {
          return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
        return MaterialPageRoute(builder: (_) => AllReviewsScreen(args: args));

      case AppRoutes.checkout:
        return MaterialPageRoute(
          builder:
              (_) => CheckoutScreen(
                lockerStationService: AppBlocProviders.lockerStationService,
              ),
        );

      case AppRoutes.cart:
        return MaterialPageRoute(
          builder:
              (_) => CartScreen(onContinueShopping: () {}, onCheckout: () {}),
        );

      case AppRoutes.editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      case AppRoutes.shippingAddress:
        return MaterialPageRoute(builder: (_) => const ShippingAddressScreen());

      case AppRoutes.paymentMethods:
        return MaterialPageRoute(builder: (_) => const PaymentMethodsScreen());

      case AppRoutes.orders:
        return MaterialPageRoute(builder: (_) => const OrdersScreen());

      case AppRoutes.orderDetails:
        final orderId = settings.arguments as String?;
        if (orderId == null || orderId.isEmpty) {
          return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: orderId),
        );

      case AppRoutes.trackOrder:
        final orderId = settings.arguments as String?;
        if (orderId == null || orderId.isEmpty) {
          return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
        return MaterialPageRoute(
          builder: (_) => TrackOrderScreen(orderId: orderId),
        );

      case AppRoutes.notifications:
        final courierMode = settings.arguments == true;
        return MaterialPageRoute(
          builder: (_) => NotificationsScreen(courierMode: courierMode),
        );

      case AppRoutes.wishlist:
        return MaterialPageRoute(builder: (_) => const WishlistScreen());

      case AppRoutes.returns:
        return MaterialPageRoute(builder: (_) => const ReturnsScreen());

      case AppRoutes.forgotPassword:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ForgotPasswordScreen(),
          transitionsBuilder: (_, anim, __, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );

      case AppRoutes.categoryProducts:
        final category = settings.arguments as Category?;
        if (category == null) {
          return MaterialPageRoute(builder: (_) => const NotFoundScreen());
        }
        return PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => CategoryProductsScreen(category: category),
          transitionsBuilder: (_, anim, __, child) {
            final slide = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
        );

      default:
        return MaterialPageRoute(builder: (_) => const NotFoundScreen());
    }
  }
}
