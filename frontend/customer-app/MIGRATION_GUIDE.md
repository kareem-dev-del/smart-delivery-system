# Provider → Bloc/Cubit Migration Guide

## What Changed

### New Package Dependency
Add to `pubspec.yaml` (replace `provider` with `flutter_bloc`):
```yaml
dependencies:
  flutter_bloc: ^8.1.6   # add this
  # provider: ^6.x.x     # remove this
```

### Deleted Files
Remove the old controllers (now replaced by cubits):
- `lib/controllers/auth_controller.dart`
- `lib/controllers/cart_controller.dart`
- `lib/controllers/catalog_controller.dart`
- `lib/controllers/search_controller.dart`
- `lib/controllers/checkout_controller.dart`
- `lib/core/dependency_injection/providers.dart`

> **Note:** `orders_controller.dart`, `payment_methods_controller.dart`,
> `returns_controller.dart`, and `wishlist_controller.dart` were NOT used
> via Provider in the original app (their screens use local state or mock
> data). They are unchanged and not deleted.

### New Files (copy into your project)
```
lib/
  cubits/
    auth/
      auth_state.dart
      auth_cubit.dart
    cart/
      cart_state.dart
      cart_cubit.dart
    catalog/
      catalog_state.dart
      catalog_cubit.dart
    search/
      search_state.dart
      search_cubit.dart
    checkout/
      checkout_state.dart
      checkout_cubit.dart
  core/
    dependency_injection/
      di.dart        ← replaces providers.dart
  app.dart                       ← uses MultiBlocProvider
  views/screens/
    splash_screen.dart
    auth/login_screen.dart
    auth/register_screen.dart
    home_screen.dart
    cart_screen.dart
    categories_screen.dart
    checkout_screen.dart
    search_screen.dart
    profile_screen.dart
    product_details_screen.dart
    wishlist_screen.dart
    edit_profile_screen.dart
    shipping_address_screen.dart
    all_reviews_screen.dart
    main_scaffold.dart
```

### Unchanged Files (no migration needed)
- `lib/main.dart`
- `lib/core/routes/router.dart`
- `lib/core/routes/routes.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/config/app_config.dart`
- `lib/models/*`
- `lib/services/*`
- `lib/views/screens/orders_screen.dart`
- `lib/views/screens/payment_methods_screen.dart`
- `lib/views/screens/returns_screen.dart`
- `lib/views/widgets/*`

---

## Key Pattern Changes

### 1. App Root
```dart
// BEFORE
MultiProvider(providers: AppProviders.providers, child: MaterialApp(...))

// AFTER
MultiBlocProvider(providers: AppBlocProviders.providers, child: MaterialApp(...))
```

### 2. Watching State (triggers rebuild)
```dart
// BEFORE
final auth = context.watch<AuthController>();
Text(auth.user?.name ?? '')

// AFTER
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) => Text(state.user?.name ?? ''),
)
```

### 3. Reading State / Calling Methods (no rebuild)
```dart
// BEFORE
context.read<AuthController>().login(email, password)
context.read<AuthController>().user

// AFTER
context.read<AuthCubit>().login(email, password)
context.read<AuthCubit>().state.user
```

### 4. Selecting a Single Value (optimized rebuild)
```dart
// BEFORE
context.select<CartController, int>((c) => c.totalItems)

// AFTER
context.select<CartCubit, int>((cubit) => cubit.state.totalItems)
```

### 5. Providers Registration
```dart
// BEFORE (providers.dart)
ChangeNotifierProvider(create: (_) => AuthController(...))

// AFTER (di.dart)
BlocProvider<AuthCubit>(create: (_) => AuthCubit(...))
```

---

## State vs Cubit — Quick Reference

| Old (ChangeNotifier)         | New (Cubit)                     |
|------------------------------|---------------------------------|
| `notifyListeners()`          | `emit(newState)`                |
| `_isLoading = true; notifyListeners()` | `emit(state.copyWith(isLoading: true))` |
| Controller fields as props   | Immutable `State` class + `copyWith` |
| `context.watch<X>()`         | `BlocBuilder<XCubit, XState>`   |
| `context.read<X>().method()` | `context.read<XCubit>().method()` |
| `context.read<X>().someField` | `context.read<XCubit>().state.someField` |
