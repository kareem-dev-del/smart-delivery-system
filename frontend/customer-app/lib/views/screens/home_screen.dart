import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/catalog/catalog_cubit.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/icon_mapper.dart';
import 'package:shopease_mobile/models/category.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/views/widgets/error_state.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';
import 'package:shopease_mobile/views/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenCartTab,
  });

  final ValueChanged<String> onOpenSearch;
  final VoidCallback onOpenCartTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// عدد المنتجات اللي بتتحمّل في كل "دفعة" (lazy/infinite scroll)
const int _kProductsPageSize = 12;

enum _SortOption { relevance, priceLowHigh, priceHighLow, topRated }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.relevance:
        return 'Relevance';
      case _SortOption.priceLowHigh:
        return 'Price: Low to High';
      case _SortOption.priceHighLow:
        return 'Price: High to Low';
      case _SortOption.topRated:
        return 'Top Rated';
    }
  }
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerPage = 0;
  _SortOption _sortOption = _SortOption.relevance;

  // بيتحكم في عدد المنتجات الظاهرة حاليًا من filteredProducts؛
  // بيزيد تدريجيًا كل ما اليوزر يقرب من آخر الصفحة (lazy loading)
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = _kProductsPageSize;

  static const List<_PromoBanner> _banners = [
    _PromoBanner(
      title: 'Summer Sale',
      subtitle: 'Up to 50% off on selected items',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80',
    ),
    _PromoBanner(
      title: 'New Arrivals',
      subtitle: 'Check out this week\'s new drops',
      imageUrl:
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&q=80',
    ),
    _PromoBanner(
      title: 'Free Shipping',
      subtitle: 'On all orders over \$50',
      imageUrl:
          'https://images.unsplash.com/photo-1607082349566-187342175e2f?w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // بيعمل scroll تلقائي للبانرز كل 7 ثواني، وبيرجع لأول بانر تاني
    // لما يوصل لآخر واحد (infinite loop زي التطبيقات المحترفة)
    _bannerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_bannerController.hasClients) return;
      final nextPage = (_bannerPage + 1) % _banners.length;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    // Infinite scroll: لما اليوزر يقرب من آخر ٣٠٠ بيكسل من الصفحة،
    // بيزود عدد المنتجات الظاهرة بدفعة جديدة بدل ما يبنيهم كلهم مرة واحدة
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    final total = context.read<CatalogCubit>().state.filteredProducts.length;
    if (_visibleCount >= total) return;
    setState(() {
      _visibleCount = (_visibleCount + _kProductsPageSize).clamp(0, total);
    });
  }

  // بيرجّع عداد الصفحات لأول دفعة تاني؛ لازم يتنادى كل ما الفلتر يتغيّر
  // (بحث أو تصنيف) عشان الـ grid يرجع يبني من الأول بدل ما يفضل محتفظ
  // بعدد قديم أكبر من نتايج الفلتر الجديد
  void _resetPagination() {
    _visibleCount = _kProductsPageSize;
  }

  // بيرتب نسخة من القائمة حسب الاختيار الحالي، من غير ما يعدّل الأصل
  // (الأصل جاي من الـ cubit ومحتاجين نسيبه زي ما هو)
  List<Product> _sortedProducts(List<Product> source) {
    final list = List<Product>.from(source);
    switch (_sortOption) {
      case _SortOption.relevance:
        break;
      case _SortOption.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.topRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return list;
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SortSheet(current: _sortOption),
    );
    if (picked != null) {
      setState(() {
        _sortOption = picked;
        _resetPagination();
      });
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, catalogState) {
        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            return BlocBuilder<AuthCubit, AuthState>(
              builder: (context, authState) {
                final rawName = authState.user?.name.trim() ?? '';
                final userName =
                    rawName.isEmpty ? 'Shopper' : rawName.split(' ').first;
                final width = MediaQuery.of(context).size.width;
                final cardWidth = (width - 48) / 2;

                if (catalogState.isLoading && catalogState.products.isEmpty) {
                  return const LoadingState(message: 'Loading products...');
                }

                if (catalogState.error != null &&
                    catalogState.products.isEmpty) {
                  return ErrorState(
                    message: catalogState.error!,
                    onRetry: () =>
                        context.read<CatalogCubit>().loadInitial(),
                  );
                }

                final filteredProducts =
                    _sortedProducts(catalogState.filteredProducts);
                final visibleCount =
                    _visibleCount.clamp(0, filteredProducts.length);
                final hasMore = visibleCount < filteredProducts.length;
                final dealProducts = catalogState.products
                    .where((p) => p.discountPercent != null)
                    .toList()
                  ..sort(
                    (a, b) => b.discountPercent!.compareTo(a.discountPercent!),
                  );

                return RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: () => context
                      .read<CatalogCubit>()
                      .loadInitial(isRefresh: true),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HomeHeader(
                          userName: userName,
                          cartCount: cartState.totalItems,
                          onOpenCart: widget.onOpenCartTab,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _SearchBar(
                            query: _searchQuery,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _resetPagination();
                              });
                              context
                                  .read<CatalogCubit>()
                                  .setSearchQuery(value);
                            },
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                widget.onOpenSearch(value.trim());
                              }
                            },
                            onClear: () {
                              setState(() {
                                _searchQuery = '';
                                _resetPagination();
                              });
                              context
                                  .read<CatalogCubit>()
                                  .setSearchQuery('');
                            },
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_searchQuery.trim().isEmpty) ...[
                              _PromoBannerCarousel(
                                banners: _banners,
                                controller: _bannerController,
                                onPageChanged: (index) =>
                                    setState(() => _bannerPage = index),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Featured',
                                style: TextStyle(
                                  color: context.colors.foreground,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 170,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      catalogState.featuredProducts.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final product =
                                        catalogState.featuredProducts[index];
                                    return _FeaturedCard(
                                      product: product,
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.product,
                                              arguments: product.id),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Flash Deals — منتجات فيها خصم فعلي بس،
                              // مرتبة من الأعلى خصمًا للأقل، بتستخدم
                              // discountPercent المحسوب تلقائيًا من الموديل
                              if (dealProducts.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          color: context.colors.destructive,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Flash Deals',
                                          style: TextStyle(
                                            color: context.colors.foreground,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 178,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: dealProducts.length > 10
                                        ? 10
                                        : dealProducts.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final product = dealProducts[index];
                                      return _DealCard(
                                        product: product,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(
                                          AppRoutes.product,
                                          arguments: product.id,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Categories row
                              if (catalogState.categories.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Shop by Category',
                                      style: TextStyle(
                                        color: context.colors.foreground,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 84,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    // [جديد] +1 عشان "All" chip في الأول
                                    itemCount:
                                        catalogState.categories.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      // [جديد] أول عنصر بيبقى "All" —
                                      // بيرجّع selectedCategoryId لـnull
                                      // عشان يمسح الفلتر ويعرض كل المنتجات
                                      if (index == 0) {
                                        return _AllCategoryIcon(
                                          selected: catalogState
                                                  .selectedCategoryId ==
                                              null,
                                          onTap: () {
                                            setState(_resetPagination);
                                            context
                                                .read<CatalogCubit>()
                                                .setSelectedCategory(null);
                                          },
                                        );
                                      }
                                      final cat = catalogState
                                          .categories[index - 1];
                                      return _CategoryIconItem(
                                        category: cat,
                                        selected:
                                            catalogState.selectedCategoryId ==
                                                cat.id,
                                        onTap: () {
                                          setState(_resetPagination);
                                          context
                                              .read<CatalogCubit>()
                                              .setSelectedCategory(
                                                catalogState
                                                            .selectedCategoryId ==
                                                        cat.id
                                                    ? null
                                                    : cat.id,
                                              );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                              ],

                              // All Products header — بيوري عدد النتايج
                              // الفعلي وزرار الترتيب جنبه، بدل ما يفضل
                              // عنوان ثابت من غير أي معلومة أو تحكّم
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _searchQuery.trim().isEmpty
                                        ? 'All Products'
                                        : 'Results',
                                    style: TextStyle(
                                      color: context.colors.foreground,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    '${filteredProducts.length} items',
                                    style: TextStyle(
                                      color: context.colors.mutedForeground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _openSortSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.swap_vert_rounded,
                                        size: 16,
                                        color: context.colors.mutedForeground,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _sortOption.label,
                                        style: TextStyle(
                                          color:
                                              context.colors.mutedForeground,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                          ],
                          ],
                        ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            // Leave room for two-line names, stock/review labels,
                            // and optional brand/discount rows on compact screens.
                            mainAxisExtent: cardWidth * 0.85 + 140,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              // [جديد] Lazy loading حقيقي: SliverGrid
                              // بيبني بس الكروت القريبة من الشاشة، مش كل
                              // المنتجات مرة واحدة زي ما كان بيحصل مع Wrap.
                              // بالإضافة لـ infinite scroll بيزود visibleCount
                              // تدريجيًا (_kProductsPageSize في كل مرة).
                              final product = filteredProducts[index];
                              return ProductCard(
                                product: product,
                                width: cardWidth,
                                inCart: cartState.isInCart(product.id),
                                onOpen: () => Navigator.of(context).pushNamed(
                                  AppRoutes.product,
                                  arguments: product.id,
                                ),
                                onAddToCart: () => context
                                    .read<CartCubit>()
                                    .addToCart(product),
                              );
                            },
                            childCount: visibleCount,
                          ),
                        ),
                      ),
                      if (hasMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.userName,
    required this.cartCount,
    required this.onOpenCart,
  });

  final String userName;
  final int cartCount;
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary, context.colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What are you looking for today?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onOpenCart,
                icon: const Icon(Icons.shopping_cart_outlined,
                    color: Colors.white, size: 26),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      cartCount > 9 ? '9+' : '$cartCount',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),   // Container
    );   // ClipRRect
  }
}

class _PromoBanner {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
}

// كاروسيل البانرات اللي بيظهر تحت السيرش، وبيعمل scroll تلقائي
// كل 7 ثواني (الـ Timer اللي بيتحكم فيه موجود في _HomeScreenState).
class _PromoBannerCarousel extends StatelessWidget {
  const _PromoBannerCarousel({
    required this.banners,
    required this.controller,
    required this.onPageChanged,
  });

  final List<_PromoBanner> banners;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => Container(
                          color: context.colors.muted,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.muted,
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xCC000000),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              banner.subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            double page = 0;
            if (controller.hasClients && controller.page != null) {
              page = controller.page!;
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (index) {
                final isActive = (page.round() % banners.length) == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? context.colors.primary
                        : context.colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.query,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black12,
      child: TextField(
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: context.colors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class _HomeImagePlaceholder extends StatelessWidget {
  const _HomeImagePlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.muted,
            context.colors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: context.colors.primary.withValues(alpha: 0.6),
        size: height < 120 ? 26 : 34,
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: product.imageUrl,
              width: 200,
              height: 170,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => const _HomeImagePlaceholder(
                width: 200,
                height: 170,
              ),
              errorWidget: (_, __, ___) => const _HomeImagePlaceholder(
                width: 200,
                height: 170,
              ),
            ),
            Container(
              width: 200,
              height: 170,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xC0000000)],
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (product.badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [جديد] عنصر تصنيف بشكل دائرة أيقونة + اسم تحتها (زي شكل تطبيقات
// التسوق الكبيرة) بدل الـ chip الأفقي القديم — بيدي إحساس بصري أرتب
// وأسهل مسح بالعين لما التصنيفات كتير
class _CategoryIconItem extends StatelessWidget {
  const _CategoryIconItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _colorFromHex(context, category.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? categoryColor
                    : categoryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: categoryColor.withValues(alpha: 0.25)),
              ),
              alignment: Alignment.center,
              child: Icon(
                IconMapper.forCategory(category.icon),
                color: selected ? Colors.white : categoryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? context.colors.foreground
                    : context.colors.mutedForeground,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFromHex(BuildContext context, String hex) {
    final raw = hex.replaceFirst('#', '');
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    final value = int.tryParse(normalized, radix: 16);
    return value == null ? context.colors.secondary : Color(value);
  }
}

// [جديد] — نفس شكل _CategoryIconItem بالظبط، لكن ثابت ("All") بدل ما
// يتبني من Category؛ بيمسح selectedCategoryId عشان يرجّع عرض كل المنتجات
class _AllCategoryIcon extends StatelessWidget {
  const _AllCategoryIcon({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? context.colors.primary
                    : context.colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(
                        color: context.colors.primary.withValues(alpha: 0.25),
                      ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.apps_rounded,
                color: selected ? Colors.white : context.colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All',
              style: TextStyle(
                color: selected
                    ? context.colors.foreground
                    : context.colors.mutedForeground,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [جديد] كارت مضغوط لقسم Flash Deals — بيركّز على نسبة الخصم والسعرين
// جنب بعض، عشان يبقى واضح إن ده عرض محدود مش كارت منتج عادي
class _DealCard extends StatelessWidget {
  const _DealCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 128,
                    height: 100,
                    fit: BoxFit.cover,
                    memCacheWidth: 256,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const _HomeImagePlaceholder(
                      width: 128,
                      height: 100,
                    ),
                    errorWidget: (_, __, ___) => const _HomeImagePlaceholder(
                      width: 128,
                      height: 100,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.destructive,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-${product.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '\$${product.originalPrice!.toStringAsFixed(2)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontSize: 10.5,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [جديد] الشيت اللي بيظهر لما اليوزر يدوس على زرار الترتيب في "All Products"
class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final _SortOption current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Text(
                'Sort by',
                style: TextStyle(
                  color: context.colors.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            for (final option in _SortOption.values)
              ListTile(
                onTap: () => Navigator.of(context).pop(option),
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontWeight: option == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                trailing: option == current
                    ? Icon(Icons.check_rounded, color: context.colors.primary)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
