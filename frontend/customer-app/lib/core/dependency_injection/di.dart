import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/controllers/auth_controller.dart';
import 'package:shopease_mobile/controllers/cart_controller.dart';
import 'package:shopease_mobile/controllers/catalog_controller.dart';
import 'package:shopease_mobile/controllers/checkout_controller.dart';
import 'package:shopease_mobile/controllers/orders_controller.dart';
import 'package:shopease_mobile/controllers/payment_methods_controller.dart';
import 'package:shopease_mobile/controllers/profile_controller.dart';
import 'package:shopease_mobile/controllers/returns_controller.dart';
import 'package:shopease_mobile/controllers/review_controller.dart';
import 'package:shopease_mobile/controllers/shipping_address_controller.dart';
import 'package:shopease_mobile/controllers/subcategory_controller.dart';
import 'package:shopease_mobile/controllers/track_order_controller.dart';
import 'package:shopease_mobile/controllers/wishlist_controller.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/utils/token_storage.dart';
import 'package:shopease_mobile/cubits/wishlist/wishlist_cubit.dart';
import 'package:shopease_mobile/repositories/auth_repository.dart';
import 'package:shopease_mobile/repositories/cart_repository.dart';
import 'package:shopease_mobile/repositories/catalog_repository.dart';
import 'package:shopease_mobile/repositories/checkout_repository.dart';
import 'package:shopease_mobile/repositories/orders_repository.dart';
import 'package:shopease_mobile/repositories/payment_method_repository.dart';
import 'package:shopease_mobile/repositories/profile_repository.dart';
import 'package:shopease_mobile/repositories/returns_repository.dart';
import 'package:shopease_mobile/repositories/review_repository.dart';
import 'package:shopease_mobile/repositories/shipping_address_repository.dart';
import 'package:shopease_mobile/repositories/subcategory_repository.dart';
import 'package:shopease_mobile/repositories/track_order_repository.dart';
import 'package:shopease_mobile/repositories/wishlist_repository.dart';
import 'package:shopease_mobile/services/cart_service.dart';
import 'package:shopease_mobile/services/category_service.dart';
import 'package:shopease_mobile/services/checkout_service.dart';
import 'package:shopease_mobile/services/courier_service.dart';
import 'package:shopease_mobile/services/forgot_password_service.dart';
import 'package:shopease_mobile/services/login_service.dart';
import 'package:shopease_mobile/services/locker_station_service.dart';
import 'package:shopease_mobile/services/orders_service.dart';
import 'package:shopease_mobile/services/payment_method_service.dart';
import 'package:shopease_mobile/services/product_service.dart';
import 'package:shopease_mobile/services/profile_service.dart';
import 'package:shopease_mobile/services/returns_service.dart';
import 'package:shopease_mobile/services/review_service.dart';
import 'package:shopease_mobile/services/shipping_address_service.dart';
import 'package:shopease_mobile/services/subcategory_service.dart';
import 'package:shopease_mobile/services/track_order_service.dart';
import 'package:shopease_mobile/services/wishlist_service.dart';

import '../../cubits/review/review_cubit.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../cubits/cart/cart_cubit.dart';
import '../../cubits/catalog/catalog_cubit.dart';
import '../../cubits/checkout/checkout_cubit.dart';
import '../../cubits/orders/orders_cubit.dart';
import '../../cubits/payment_methods/payment_methods_cubit.dart';
import '../../cubits/search/search_cubit.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../../services/api_data_service.dart';
import '../../services/app_data_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/mock_data_service.dart';
import '../../services/register_service.dart';

class AppBlocProviders {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final TokenStorage tokenStorage = TokenStorage();

  static final ApiClient apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStorage: tokenStorage,
    onSessionExpired: () async {
      // بنمسح الـuser المخزّن (مش الـtoken بس) عشان لو التطبيق اتقفل
      // وفتح تاني، restoreSession() ماتفتكرش إن فيه session صالحة لسه
      // وترجّعنا لنفس دوّامة الـ401 → login تاني
      await storageService.clearUser();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    },
  );

  // ------------------------Services------------------------

  static final RegisterService registerService = RegisterService(
    client: apiClient,
    tokenStorage: tokenStorage,
  );

  static final LoginService loginService = LoginService(
    client: apiClient,
    tokenStorage: tokenStorage,
  );

  static final ForgotPasswordService forgotPasswordService =
      ForgotPasswordService(client: apiClient);

  static final ProfileService profileService = ProfileService(
    client: apiClient,
  ); // [جديد]

  static final ProductService productService = ProductService(
    client: apiClient,
  );

  static final CategoryService categoryService = CategoryService(
    client: apiClient,
  );

  static final SubcategoryService subcategoryService = SubcategoryService(
    client: apiClient,
  );

  static final ReviewService reviewService = ReviewService(client: apiClient);

  static final CartService cartService = CartService(
    storageService: storageService,
  );

  static final WishlistService wishlistService = WishlistService(
    apiClient: apiClient,
  );

  static final ShippingAddressService shippingAddressService =
      ShippingAddressService(client: apiClient);

  // [جديد] — كانت الاتنين دول مفقودين بالكامل، checkout_cubit كانت بتعمل
  // simulated delay وorders_controller كانت بتنادي method مش موجودة أصلًا
  static final CheckoutService checkoutService = CheckoutService(
    client: apiClient,
  );

  static final CourierService courierService = CourierService(
    client: apiClient,
  );

  static final OrdersService ordersService = OrdersService(client: apiClient);

  static final LockerStationService lockerStationService = LockerStationService(
    client: apiClient,
  );

  // Customer order tracking, backed by GET /api/orders/{public_id}/tracking/.
  static final TrackOrderService trackOrderService = TrackOrderService(
    client: apiClient,
  );

  // [جديد] — Returns & Refunds. كانت returns_controller.dart بتنادي
  // methods مش موجودة أصلًا (شوف comment جوه الـcontroller نفسه)، فالطبقة
  // كاملة (service/repository/controller/cubit) كانت غير موجودة فعليًا.
  static final ReturnsService returnsService = ReturnsService(
    client: apiClient,
  );

  // [جديد] — Payment Methods. كانت الطبقة ناقصة بالكامل: الـcontroller
  // القديم كان بينادي methods مش موجودة في AppDataService، ومكانش متسجل
  // في الـDI أصلًا. اتبنت الطبقة كاملة (service/repository/controller/cubit)
  // على نفس نمط Cart/Wishlist.
  static final PaymentMethodService paymentMethodService = PaymentMethodService(
    apiClient: apiClient,
  );

  // ------------------------Repositories------------------------

  static final AuthRepository authRepository = AuthRepository(
    tokenStorage: tokenStorage,
    loginService: loginService,
    registerService: registerService,
    forgotPasswordService: forgotPasswordService,
  );

  static final ProfileRepository profileRepository = ProfileRepository(
    // [جديد]
    profileService: profileService,
  );

  static final CatalogRepository catalogRepository = CatalogRepository(
    productService: productService,
    categoryService: categoryService,
  );

  static final SubcategoryRepository subcategoryRepository =
      SubcategoryRepository(subcategoryService: subcategoryService);

  static final ReviewRepository reviewRepository = ReviewRepository(
    reviewService: reviewService,
  );

  static final CartRepository cartRepository = CartRepository(
    cartService: cartService,
  );

  static final WishlistRepository wishlistRepository = WishlistRepository(
    wishlistService: wishlistService,
  );

  static final ShippingAddressRepository shippingAddressRepository =
      ShippingAddressRepository(shippingAddressService: shippingAddressService);

  static final CheckoutRepository checkoutRepository = CheckoutRepository(
    checkoutService: checkoutService,
  );

  static final OrdersRepository ordersRepository = OrdersRepository(
    ordersService: ordersService,
  );

  static final TrackOrderRepository trackOrderRepository = TrackOrderRepository(
    trackOrderService: trackOrderService,
  );

  static final ReturnsRepository returnsRepository = ReturnsRepository(
    returnsService: returnsService,
  );

  static final PaymentMethodRepository paymentMethodRepository =
      PaymentMethodRepository(paymentMethodService: paymentMethodService);

  // ------------------------Controllers------------------------

  static final AuthController authController = AuthController(
    authRepository: authRepository,
  );

  static final ProfileController profileController = ProfileController(
    // [جديد]
    profileRepository: profileRepository,
  );

  static final CatalogController catalogController = CatalogController(
    catalogRepository: catalogRepository,
  );

  static final SubcategoryController subcategoryController =
      SubcategoryController(subcategoryRepository: subcategoryRepository);

  static final ReviewController reviewController = ReviewController(
    reviewRepository: reviewRepository,
  );

  static final AppDataService dataService =
      AppConfig.useApi ? ApiDataService(client: apiClient) : MockDataService();

  static final CartController cartController = CartController(
    cartRepository: cartRepository,
  );

  static final WishlistController wishlistController = WishlistController(
    wishlistRepository: wishlistRepository,
  );

  static final ShippingAddressController shippingAddressController =
      ShippingAddressController(
        shippingAddressRepository: shippingAddressRepository,
      );

  // [جديد]
  static final CheckoutController checkoutController = CheckoutController(
    checkoutRepository: checkoutRepository,
  );

  static final OrdersController ordersController = OrdersController(
    ordersRepository: ordersRepository,
  );

  static final TrackOrderController trackOrderController = TrackOrderController(
    trackOrderRepository: trackOrderRepository,
  );

  static final ReturnsController returnsController = ReturnsController(
    returnsRepository: returnsRepository,
  );

  static final PaymentMethodsController paymentMethodsController =
      PaymentMethodsController(
        paymentMethodRepository: paymentMethodRepository,
      );

  static final storageService = LocalStorageService();

  static final providers = [
    BlocProvider<AuthCubit>(
      create:
          (_) => AuthCubit(
            authController: authController,
            storageService: storageService,
            profileController: profileController,
          )..restoreSession(),
    ),
    BlocProvider<CartCubit>(
      create: (_) => CartCubit(cartController: cartController)..restoreCart(),
    ),
    BlocProvider<WishlistCubit>(
      create:
          (_) =>
              WishlistCubit(wishlistController: wishlistController)
                ..restoreWishlist(),
    ),
    BlocProvider<CatalogCubit>(
      create:
          (_) =>
              CatalogCubit(catalogController: catalogController)..loadInitial(),
    ),
    BlocProvider<SearchCubit>(
      create: (_) => SearchCubit(dataService: dataService),
    ),
    BlocProvider<CheckoutCubit>(
      create: (_) => CheckoutCubit(checkoutController: checkoutController),
    ),
    BlocProvider<ReviewCubit>(
      create: (_) => ReviewCubit(reviewController: reviewController),
    ),
    // [جديد] — كانت OrdersCubit بتتعمل محليًا جوه OrdersScreen بس (BlocProvider
    // محلي). نقلناها هنا زي CartCubit/WishlistCubit عشان أي شاشة تانية —
    // زي OrderDetailsScreen اللي بتتفتح بـNavigator.push فوق الـOrdersScreen،
    // مش جواها — تقدر توصل لنفس الـinstance وتحدّث الليستة (مثلاً بعد
    // إلغاء أوردر من شاشة التفاصيل) من غير ما نحتاج نعدي callbacks معقدة.
    BlocProvider<OrdersCubit>(
      create:
          (_) => OrdersCubit(ordersController: ordersController)..loadOrders(),
    ),
    // [جديد] — Payment Methods Cubit، مسجّل global زي CartCubit عشان
    // شاشة الـCheckout كمان تقدر توصل لنفس الـinstance.
    BlocProvider<PaymentMethodsCubit>(
      create:
          (_) => PaymentMethodsCubit(
            paymentMethodsController: paymentMethodsController,
          )..loadMethods(),
    ),
  ];
}
