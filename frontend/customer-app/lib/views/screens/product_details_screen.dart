import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/cubits/cart/cart_cubit.dart';
import 'package:shopease_mobile/cubits/catalog/catalog_cubit.dart';
import 'package:shopease_mobile/cubits/review/review_cubit.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/models/product.dart';
import 'package:shopease_mobile/models/product_review.dart';
import 'package:shopease_mobile/views/screens/all_reviews_screen.dart';
import 'package:shopease_mobile/views/widgets/error_state.dart';
import 'package:shopease_mobile/views/widgets/loading_state.dart';
import 'package:shopease_mobile/views/widgets/product_card.dart';
import 'package:shopease_mobile/views/widgets/write_review_sheet.dart';
import 'package:shopease_mobile/cubits/wishlist/wishlist_cubit.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Future<Product?> _productFuture;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  int _quantity = 1;
  final bool _isFavorite = false;
  bool _descriptionExpanded = false;
  String? _selectedSize;
  String? _selectedColor;

  static const _colors = [
    _ColorOption(label: 'Black', hex: 0xFF1A1A2E),
    _ColorOption(label: 'White', hex: 0xFFF8F9FE),
    _ColorOption(label: 'Red', hex: 0xFFFF6B6B),
    _ColorOption(label: 'Blue', hex: 0xFF6C63FF),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = _colors.first.label;
    _productFuture = context.read<CatalogCubit>().fetchProductById(
      widget.productId,
    );
    // Reviews live in their own cubit (backed by the /reviews endpoint) —
    // kick off the load in parallel with the product fetch.
    context.read<ReviewCubit>().loadReviews(widget.productId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.read<CartCubit>().state;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: FutureBuilder<Product?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(message: 'Loading product...');
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _productFuture = context
                      .read<CatalogCubit>()
                      .fetchProductById(widget.productId);
                });
              },
            );
          }
          final product = snapshot.data;
          if (product == null) {
            return const ErrorState(message: 'Product not found.');
          }

          final sizes = _sizesForCategory(product.category);
          if (_selectedSize == null && sizes.isNotEmpty) {
            _selectedSize = sizes[1]; // default to second size
          }

          final inCart = cartState.isInCart(product.id);
          final cartQty = inCart ? cartState.quantityOf(product.id) : 0;
          final related =
              context
                  .read<CatalogCubit>()
                  .state
                  .productsByCategory(product.category)
                  .where((p) => p.id != product.id)
                  .take(6)
                  .toList();

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Image gallery ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _ImageGallery(
                      imageUrl: product.imageUrl,
                      pageController: _pageController,
                      currentIndex: _currentImageIndex,
                      isFavorite: context.watch<WishlistCubit>().state.isWishlisted(product.id),
                      onPageChanged:
                          (i) => setState(() => _currentImageIndex = i),
                      onFavoriteTap:
                          () => context.read<WishlistCubit>().toggle(product),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Container(
                      color: context.colors.background,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Badge + stock ────────────────────────────
                          Row(
                            children: [
                              if (product.badge != null)
                                _Badge(label: product.badge!),
                              if (product.badge != null)
                                const SizedBox(width: 8),
                              _StockChip(inStock: product.inStock),
                              const Spacer(),
                              Icon(
                                Icons.share_outlined,
                                size: 20,
                                color: context.colors.mutedForeground,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ── Name ─────────────────────────────────────
                          Text(
                            product.name,
                            style: TextStyle(
                              color: context.colors.foreground,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Rating ───────────────────────────────────
                          _RatingRow(
                            rating: product.rating,
                            reviewCount: product.reviewCount,
                          ),
                          const SizedBox(height: 14),

                          // ── Price ────────────────────────────────────
                          _PriceRow(
                            price: product.price,
                            originalPrice: product.originalPrice,
                          ),
                          const SizedBox(height: 20),

                          // ── Color selector ───────────────────────────
                          _SectionLabel(text: 'Color'),
                          const SizedBox(height: 10),
                          _ColorSelector(
                            colors: _colors,
                            selected: _selectedColor,
                            onSelect: (c) => setState(() => _selectedColor = c),
                          ),
                          const SizedBox(height: 18),

                          // ── Size selector ────────────────────────────
                          if (sizes.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _SectionLabel(text: 'Size'),
                                TextButton(
                                  onPressed: () => _showSizeGuide(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    foregroundColor: context.colors.secondary,
                                  ),
                                  child: const Text(
                                    'Size Guide',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SizeSelector(
                              sizes: sizes,
                              selected: _selectedSize,
                              onSelect:
                                  (s) => setState(() => _selectedSize = s),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ── Quantity ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SectionLabel(text: 'Quantity'),
                              _QuantitySelector(
                                quantity: _quantity,
                                onDecrement:
                                    _quantity > 1
                                        ? () => setState(() => _quantity--)
                                        : null,
                                onIncrement: () => setState(() => _quantity++),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Delivery & guarantees ────────────────────
                          _GuaranteeRow(subtotal: product.price),
                          const SizedBox(height: 20),

                          // ── Description ──────────────────────────────
                          const Divider(),
                          const SizedBox(height: 14),
                          _SectionLabel(text: 'Description'),
                          const SizedBox(height: 8),
                          _ExpandableDescription(
                            text: product.description,
                            expanded: _descriptionExpanded,
                            onToggle:
                                () => setState(
                                  () =>
                                      _descriptionExpanded =
                                          !_descriptionExpanded,
                                ),
                          ),
                          const SizedBox(height: 20),

                          // ── Specifications ───────────────────────────
                          const Divider(),
                          const SizedBox(height: 14),
                          _SpecificationsCard(specs: _specsForProduct(product)),
                          const SizedBox(height: 20),

                          // ── Reviews ──────────────────────────────────
                          const Divider(),
                          const SizedBox(height: 14),
                          BlocProvider<ReviewCubit>(
                            create:
                                (_) => ReviewCubit(
                                  reviewController:
                                      AppBlocProviders.reviewController,
                                )..loadReviews(product.id),
                            child: _ReviewsSection(
                              rating: product.rating,
                              productId: product.id,
                              productName: product.name,
                              fallbackReviews: const [],
                            ),
                          ),

                          // ── Related products ─────────────────────────
                          if (related.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 14),
                            _SectionLabel(text: 'You May Also Like'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 250,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: related.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final p = related[index];
                                  return ProductCard(
                                    product: p,
                                    width: 160,
                                    inCart: cartState.isInCart(p.id),
                                    onOpen:
                                        () => Navigator.of(
                                          context,
                                        ).pushReplacementNamed(
                                          AppRoutes.product,
                                          arguments: p.id,
                                        ),
                                    onAddToCart:
                                        () => context
                                            .read<CartCubit>()
                                            .addToCart(p),
                                  );
                                },
                              ),
                            ),
                          ],

                          // bottom padding for FAB bar
                          const SizedBox(height: 110),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Bottom action bar ──────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomActionBar(
                  product: product,
                  quantity: _quantity,
                  inCart: inCart,
                  cartQty: cartQty,
                  onAddToCart:
                      product.inStock
                          ? () {
                            for (int i = 0; i < _quantity; i++) {
                              context.read<CartCubit>().addToCart(product);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart.'),
                                action: SnackBarAction(
                                  label: 'View Cart',
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            );
                          }
                          : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSizeGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Size Guide',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: context.colors.border, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.2),
                  },
                  children: [
                    _tableHeader([
                      'Size',
                      'Chest (in)',
                      'Waist (in)',
                      'Hip (in)',
                    ]),
                    _tableRow(['XS', '32–34', '26–28', '34–36']),
                    _tableRow(['S', '34–36', '28–30', '36–38']),
                    _tableRow(['M', '38–40', '32–34', '40–42']),
                    _tableRow(['L', '42–44', '36–38', '44–46']),
                    _tableRow(['XL', '46–48', '40–42', '48–50']),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  TableRow _tableHeader(List<String> cells) => TableRow(
    decoration: BoxDecoration(color: context.colors.muted),
    children:
        cells
            .map(
              (c) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  c,
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
  );

  TableRow _tableRow(List<String> cells) => TableRow(
    children:
        cells
            .map(
              (c) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  c,
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
  );

  List<String> _sizesForCategory(String category) {
    switch (category) {
      case 'fashion':
      case 'sports':
        return ['XS', 'S', 'M', 'L', 'XL'];
      case 'electronics':
        return ['128 GB', '256 GB', '512 GB'];
      default:
        return [];
    }
  }

  List<_Spec> _specsForProduct(Product product) {
    switch (product.category) {
      case 'electronics':
        return [
          _Spec('Category', 'Electronics'),
          _Spec('Connectivity', 'Bluetooth 5.3, Wi-Fi'),
          _Spec('Battery Life', 'Up to 30 hours'),
          _Spec('Weight', '254 g'),
          _Spec('Warranty', '1 Year'),
          _Spec('In the Box', 'Device, Cable, Manual'),
        ];
      case 'fashion':
        return [
          _Spec('Category', 'Fashion'),
          _Spec('Material', '100% Cotton'),
          _Spec('Fit', 'Regular Fit'),
          _Spec('Care', 'Machine Wash Cold'),
          _Spec('Origin', 'Made in Portugal'),
        ];
      case 'accessories':
        return [
          _Spec('Category', 'Accessories'),
          _Spec('Material', 'Full-grain Leather'),
          _Spec('Dimensions', '38 × 12 × 6 cm'),
          _Spec('Closure', 'Magnetic Snap'),
          _Spec('Warranty', '2 Years'),
        ];
      case 'sports':
        return [
          _Spec('Category', 'Sports'),
          _Spec('Material', 'Mesh / Synthetic'),
          _Spec('Drop', '10 mm'),
          _Spec('Weight', '280 g (US 10)'),
          _Spec('Surface', 'Road'),
          _Spec('Waterproof', 'No'),
        ];
      case 'home':
        return [
          _Spec('Category', 'Home'),
          _Spec('Power', '12 W'),
          _Spec('Light Source', 'LED'),
          _Spec('Brightness', '800 lm'),
          _Spec('Arm Length', '45 cm'),
          _Spec('Warranty', '1 Year'),
        ];
      default:
        return [
          _Spec('Category', product.category),
          _Spec('Warranty', '1 Year'),
        ];
    }
  }
}

// ── Image Gallery ────────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.imageUrl,
    required this.pageController,
    required this.currentIndex,
    required this.isFavorite,
    required this.onPageChanged,
    required this.onFavoriteTap,
    required this.onBack,
  });

  final String imageUrl;
  final PageController pageController;
  final int currentIndex;
  final bool isFavorite;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFavoriteTap;
  final VoidCallback onBack;

  static const _imageCount = 3;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: _imageCount,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (_, __, ___) => ColoredBox(
                        color: context.colors.muted,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: context.colors.mutedForeground,
                          ),
                        ),
                      ),
                );
              },
            ),
            // back button
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: _CircleIconBtn(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
            ),
            // favorite button
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: _CircleIconBtn(
                icon:
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                iconColor:
                    isFavorite ? context.colors.primary : context.colors.foreground,
                onTap: onFavoriteTap,
              ),
            ),
            // dots indicator
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _imageCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: currentIndex == i ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color:
                          currentIndex == i
                              ? context.colors.primary
                              : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ), // Stack
      ), // SizedBox
    ); // ClipRRect
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: iconColor ?? context.colors.foreground),
      ),
    );
  }
}

// ── Small widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.foreground,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color =
        label == 'New'
            ? context.colors.secondary
            : label == 'Sale'
            ? context.colors.primary
            : context.colors.star;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (inStock ? context.colors.success : context.colors.destructive)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock
                ? Icons.check_circle_outline_rounded
                : Icons.remove_circle_outline_rounded,
            size: 13,
            color: inStock ? context.colors.success : context.colors.destructive,
          ),
          const SizedBox(width: 4),
          Text(
            inStock ? 'In Stock' : 'Out of Stock',
            style: TextStyle(
              color: inStock ? context.colors.success : context.colors.destructive,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final full = i < rating.floor();
          final half = !full && (i < rating);
          return Icon(
            full
                ? Icons.star_rounded
                : half
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            color: context.colors.star,
            size: 18,
          );
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount reviews)',
          style: TextStyle(
            color: context.colors.mutedForeground,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price, this.originalPrice});

  final double price;
  final double? originalPrice;

  @override
  Widget build(BuildContext context) {
    final discountPct =
        originalPrice != null
            ? (((originalPrice! - price) / originalPrice!) * 100).round()
            : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: TextStyle(
            color: context.colors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 30,
          ),
        ),
        if (originalPrice != null) ...[
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '\$${originalPrice!.toStringAsFixed(2)}',
              style: TextStyle(
                color: context.colors.mutedForeground,
                decoration: TextDecoration.lineThrough,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$discountPct% OFF',
                style: TextStyle(
                  color: context.colors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Color selector ───────────────────────────────────────────────────────────

class _ColorOption {
  const _ColorOption({required this.label, required this.hex});
  final String label;
  final int hex;
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final List<_ColorOption> colors;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          colors.map((c) {
            final isSelected = selected == c.label;
            return GestureDetector(
              onTap: () => onSelect(c.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 10),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c.hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.border,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: context.colors.primary.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Size selector ────────────────────────────────────────────────────────────

class _SizeSelector extends StatelessWidget {
  const _SizeSelector({
    required this.sizes,
    required this.selected,
    required this.onSelect,
  });

  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children:
          sizes.map((s) {
            final isSelected = selected == s;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.colors.primary : context.colors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: isSelected ? Colors.white : context.colors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Quantity selector ────────────────────────────────────────────────────────

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          SizedBox(
            width: 38,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 18,
          color:
              onTap == null
                  ? context.colors.mutedForeground
                  : context.colors.foreground,
        ),
      ),
    );
  }
}

// ── Guarantee row ────────────────────────────────────────────────────────────

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final freeShipping = subtotal >= 100;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _GuaranteeItem(
            icon: Icons.local_shipping_outlined,
            label: freeShipping ? 'Free Shipping' : 'Fast Delivery',
            color: context.colors.success,
          ),
          _GuaranteeDivider(),
          _GuaranteeItem(
            icon: Icons.assignment_return_outlined,
            label: '30-Day Return',
            color: context.colors.secondary,
          ),
          _GuaranteeDivider(),
          _GuaranteeItem(
            icon: Icons.verified_user_outlined,
            label: '1-Year Warranty',
            color: context.colors.star,
          ),
        ],
      ),
    );
  }
}

class _GuaranteeItem extends StatelessWidget {
  const _GuaranteeItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuaranteeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: context.colors.border);
  }
}

// ── Expandable description ───────────────────────────────────────────────────

class _ExpandableDescription extends StatelessWidget {
  const _ExpandableDescription({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isLong = text.length > 120;
    final displayText =
        !isLong || expanded ? text : '${text.substring(0, 120)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: TextStyle(
            color: context.colors.mutedForeground,
            fontSize: 14,
            height: 1.65,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Read less' : 'Read more',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Specifications ───────────────────────────────────────────────────────────

class _Spec {
  const _Spec(this.label, this.value);
  final String label;
  final String value;
}

class _SpecificationsCard extends StatefulWidget {
  const _SpecificationsCard({required this.specs});

  final List<_Spec> specs;

  @override
  State<_SpecificationsCard> createState() => _SpecificationsCardState();
}

class _SpecificationsCardState extends State<_SpecificationsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Specifications',
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: context.colors.mutedForeground,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children:
                    widget.specs.asMap().entries.map((entry) {
                      final isLast = entry.key == widget.specs.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border:
                              isLast
                                  ? null
                                  : Border(
                                    bottom: BorderSide(
                                      color: context.colors.border,
                                    ),
                                  ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                entry.value.label,
                                style: TextStyle(
                                  color: context.colors.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.value,
                                style: TextStyle(
                                  color: context.colors.foreground,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}

// ── Reviews section ──────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.rating,
    required this.productId,
    required this.productName,
    required this.fallbackReviews,
  });

  final double rating;
  final String productId;
  final String productName;
  final List<ProductReview> fallbackReviews;

  Future<void> _openWriteReview(BuildContext context) async {
    final authState = context.read<AuthCubit>().state;
    final userName =
        authState.user?.name.trim().isEmpty == false
            ? authState.user!.name.trim()
            : 'Guest';

    final reviewCubit = context.read<ReviewCubit>();

    await WriteReviewSheet.show(
      context,
      userName: userName,
      onSubmit: (rating, text) async {
        final success = await reviewCubit.submitReview(
          productId: productId,
          rating: rating,
          text: text,
        );
        return success
            ? null
            : (reviewCubit.state.error ?? 'Could not submit your review.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, reviewState) {
        final reviews =
            reviewState.isLoading
                ? const <ProductReview>[]
                : (reviewState.reviews.isNotEmpty
                    ? reviewState.reviews
                    : fallbackReviews);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customer Reviews',
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      reviewState.isSubmitting
                          ? null
                          : () => _openWriteReview(context),
                  icon:
                      reviewState.isSubmitting
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Write a Review'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (reviewState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              // ── Summary row ───────────────────────────────────────────
              Row(
                children: [
                  Column(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: context.colors.foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 44,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating.floor()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: context.colors.star,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${reviews.length} reviews',
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      children: [
                        _RatingBar(star: 5, fraction: 0.72),
                        _RatingBar(star: 4, fraction: 0.16),
                        _RatingBar(star: 3, fraction: 0.07),
                        _RatingBar(star: 2, fraction: 0.03),
                        _RatingBar(star: 1, fraction: 0.02),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Review cards ──────────────────────────────────────────
              ...reviews.map((r) => _ReviewCard(review: r)),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.allReviews,
                    arguments: AllReviewsArgs(
                      productId: productId,
                      reviews: reviews,
                      productName: productName,
                      rating: rating,
                      reviewCount: reviews.length,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text('See All ${reviews.length} Reviews'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.star, required this.fraction});

  final int star;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$star',
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star_rounded, color: context.colors.star, size: 11),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: context.colors.muted,
                color: context.colors.star,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(fraction * 100).round()}%',
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: context.colors.secondary.withValues(alpha: 0.15),
                child: Text(
                  review.name[0],
                  style: TextStyle(
                    color: context.colors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.name,
                          style: TextStyle(
                            color: context.colors.foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (review.verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            color: context.colors.success,
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: context.colors.success,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      review.date,
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: context.colors.star,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.product,
    required this.quantity,
    required this.inCart,
    required this.cartQty,
    required this.onAddToCart,
  });

  final Product product;
  final int quantity;
  final bool inCart;
  final int cartQty;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final total = product.price * quantity;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          border: Border(top: BorderSide(color: context.colors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Price',
                  style: TextStyle(
                    color: context.colors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddToCart,
                icon: Icon(
                  inCart
                      ? Icons.shopping_cart_rounded
                      : Icons.add_shopping_cart_rounded,
                  size: 18,
                ),
                label: Text(
                  inCart ? 'In Cart ($cartQty) · Add More' : 'Add to Cart',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
