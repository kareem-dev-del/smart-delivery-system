import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.width,
    required this.inCart,
    required this.onOpen,
    required this.onAddToCart,
  });

  final Product product;
  final double width;
  final bool inCart;
  final VoidCallback onOpen;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final discountPercent = product.discountPercent;
    final hasDiscount = discountPercent != null;
    // لو البادج مش متحدد يدويًا وفيه خصم فعلي، نعرض نسبة الخصم تلقائيًا
    // بدل ما نسيب المكان فاضي أو نعتمد على badge نصي ثابت
    final displayBadge = (product.badge != null && product.badge!.isNotEmpty)
        ? product.badge
        : (hasDiscount ? '-$discountPercent%' : null);

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          width: width,
                          height: width * 0.85,
                          fit: BoxFit.cover,
                          // بينزل الصورة بالحجم اللي هيتعرض بيه فعليًا
                          // (مش الحجم الأصلي) عشان يقلل استهلاك الميموري
                          memCacheWidth: (width * 2).round(),
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => _placeholder(context),
                          errorWidget: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
                // Badge (بادج يدوي زي "New"/"Hot"، أو نسبة خصم تلقائية)
                if (displayBadge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.colors.primary, context.colors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Sold count — بيديله إحساس ثقة/إقبال زي منصات التسوق
                // الكبيرة، بيظهر بس لو عندنا رقم فعلي
                if (product.soldCount != null && product.soldCount! > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.card.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.soldCount} sold',
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Out of stock overlay
                if (!product.inStock)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand — بيظهر بس لو المنتج عنده براند متسجل
                  if (product.brand != null && product.brand!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        product.brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // Name
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.reviewCount > 0 || product.isLowStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (product.reviewCount > 0) ...[
                            Icon(
                              Icons.star_rounded,
                              color: context.colors.star,
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: context.colors.mutedForeground,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${product.reviewCount})',
                              style: TextStyle(
                                color: context.colors.mutedForeground,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (product.isLowStock) ...[
                            if (product.reviewCount > 0)
                              const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${product.stockCount} left',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.colors.destructive,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Price row + Add button
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: context.colors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                '\$${product.originalPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: context.colors.mutedForeground,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Add to cart button
                      GestureDetector(
                        onTap: product.inStock ? onAddToCart : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: inCart
                                ? context.colors.primary
                                : product.inStock
                                    ? context.colors.muted
                                    : context.colors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            inCart
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            color: inCart
                                ? Colors.white
                                : product.inStock
                                    ? context.colors.foreground
                                    : context.colors.mutedForeground,
                            size: 18,
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

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.muted,
            context.colors.primary.withValues(alpha: 0.08),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: context.colors.card.withValues(alpha: 0.75),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.inventory_2_outlined,
          color: context.colors.primary.withValues(alpha: 0.72),
          size: 26,
        ),
      ),
    );
  }
}
