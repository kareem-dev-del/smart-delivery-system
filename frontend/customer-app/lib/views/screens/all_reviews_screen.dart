import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/cubits/auth/auth_cubit.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/cubits/review/review_cubit.dart';
import 'package:shopease_mobile/models/product_review.dart';
import 'package:shopease_mobile/views/widgets/write_review_sheet.dart';

class AllReviewsArgs {
  const AllReviewsArgs({
    required this.productId,
    required this.productName,
    required this.rating,
    required this.reviewCount,
    required this.reviews,
  });

  final String productId;
  final String productName;
  final double rating;
  final int reviewCount;
  final List<ProductReview> reviews;
}

class AllReviewsScreen extends StatefulWidget {
  const AllReviewsScreen({super.key, required this.args});

  final AllReviewsArgs args;

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  int? _filterRating; // null = all
  String _sortBy = 'recent'; // 'recent' | 'helpful' | 'highest' | 'lowest'
  late List<ProductReview> _reviews;
  late final ReviewCubit _reviewCubit;   // [جديد]

  @override
  void initState() {
    super.initState();
    _reviews = [...widget.args.reviews];
    _reviewCubit = ReviewCubit(   // [جديد]
      reviewController: AppBlocProviders.reviewController,
    );
  }

    @override
  void dispose() {
    _reviewCubit.close();   // [جديد]
    super.dispose();
  }

Future<void> _openWriteReview() async {
    final userName = context.read<AuthCubit>().state.user?.name.trim().isEmpty == false
        ? context.read<AuthCubit>().state.user!.name.trim()
        : 'Guest';

    final success = await WriteReviewSheet.show(
      context,
      userName: userName,
      onSubmit: (rating, text) async {
        final ok = await _reviewCubit.submitReview(
          productId: widget.args.productId,
          rating: rating,
          text: text,
        );
        return ok ? null : (_reviewCubit.state.error ?? 'Could not submit your review.');
      },
    );

    if (success == true && mounted) {
      setState(() => _reviews.insert(0, _reviewCubit.state.reviews.first));
    }
  }

  // [جديد] بيفتح نفس الـsheet لكن متعبي مسبقًا بالـrating/text القديمين،
  // وبيحدّث الـreview في الليستة المحلية لو التعديل نجح
  Future<void> _openEditReview(ProductReview review) async {
    final userName = context.read<AuthCubit>().state.user?.name.trim().isEmpty == false
        ? context.read<AuthCubit>().state.user!.name.trim()
        : 'Guest';

    final success = await WriteReviewSheet.show(
      context,
      userName: userName,
      initialRating: review.rating,
      initialText: review.text,
      isEditing: true,
      onSubmit: (rating, text) async {
        final ok = await _reviewCubit.updateReview(
          productId: widget.args.productId,
          reviewId: review.id,
          rating: rating,
          text: text,
        );
        return ok ? null : (_reviewCubit.state.error ?? 'Could not update your review.');
      },
    );

    if (success == true && mounted) {
      final updated = _reviewCubit.state.reviews.firstWhere((r) => r.id == review.id);
      setState(() {
        final index = _reviews.indexWhere((r) => r.id == review.id);
        if (index != -1) _reviews[index] = updated;
      });
    }
  }

  // [جديد] بيسأل تأكيد قبل الحذف، وبعد نجاح الحذف بيشيل الـreview من
  // الليستة المحلية كمان عشان الشاشة تتحدث فورًا
  Future<void> _deleteReview(ProductReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Delete Review',
            style: TextStyle(color: context.colors.foreground)),
        content: Text(
          'Are you sure you want to delete your review? This cannot be undone.',
          style: TextStyle(color: context.colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete',
                style: TextStyle(color: context.colors.destructive)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _reviewCubit.deleteReview(
      productId: widget.args.productId,
      reviewId: review.id,
    );

    if (ok && mounted) {
      setState(() => _reviews.removeWhere((r) => r.id == review.id));
    } else if (mounted && _reviewCubit.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reviewCubit.state.error!)),
      );
    }
  }

  List<ProductReview> get _filtered {
    var list = _reviews;
    if (_filterRating != null) {
      list = list.where((r) => r.rating == _filterRating).toList();
    }
    switch (_sortBy) {
      case 'helpful':
        list = [...list]
          ..sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
      case 'highest':
        list = [...list]..sort((a, b) => b.rating.compareTo(a.rating));
      case 'lowest':
        list = [...list]..sort((a, b) => a.rating.compareTo(b.rating));
      default:
        break; // keep original (recent) order
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.colors.foreground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Customer Reviews',
          style: TextStyle(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.border),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWriteReview,
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text(
          'Write a Review',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Summary card ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: context.colors.card,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.productName,
                    style: TextStyle(
                      color: context.colors.mutedForeground,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Big rating number
                      Column(
                        children: [
                          Text(
                            args.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: context.colors.foreground,
                              fontWeight: FontWeight.w800,
                              fontSize: 52,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _StarRow(rating: args.rating, size: 15),
                          const SizedBox(height: 4),
                          Text(
                            '${args.reviewCount} reviews',
                            style: TextStyle(
                              color: context.colors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // Rating bars
                      Expanded(
                        child: Column(
                          children: [
                            _RatingBar(star: 5, fraction: 0.72, count: args.reviewCount),
                            _RatingBar(star: 4, fraction: 0.16, count: args.reviewCount),
                            _RatingBar(star: 3, fraction: 0.07, count: args.reviewCount),
                            _RatingBar(star: 2, fraction: 0.03, count: args.reviewCount),
                            _RatingBar(star: 1, fraction: 0.02, count: args.reviewCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Filters row ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: context.colors.background,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Star filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filterRating == null,
                          onTap: () => setState(() => _filterRating = null),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(5, (i) {
                          final star = 5 - i;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: '$star ★',
                              selected: _filterRating == star,
                              onTap: () =>
                                  setState(() => _filterRating = star),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sort dropdown
                  Row(
                    children: [
                      Text(
                        'Sort by:',
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          style: TextStyle(
                            color: context.colors.foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          dropdownColor: context.colors.card,
                          items: const [
                            DropdownMenuItem(
                              value: 'recent',
                              child: Text('Most Recent'),
                            ),
                            DropdownMenuItem(
                              value: 'helpful',
                              child: Text('Most Helpful'),
                            ),
                            DropdownMenuItem(
                              value: 'highest',
                              child: Text('Highest Rated'),
                            ),
                            DropdownMenuItem(
                              value: 'lowest',
                              child: Text('Lowest Rated'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _sortBy = v);
                          },
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Review cards ─────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 48,
                      color: context.colors.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No reviews match this filter',
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ReviewCard(
                    review: filtered[index],
                    isOwner: filtered[index].userId.isNotEmpty &&
                        filtered[index].userId ==
                            context.read<AuthCubit>().state.user?.id,
                    onEdit: () => _openEditReview(filtered[index]),
                    onDelete: () => _deleteReview(filtered[index]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Star row ─────────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final full = i < rating.floor();
        final half = !full && i < rating;
        return Icon(
          full
              ? Icons.star_rounded
              : half
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          color: context.colors.star,
          size: size,
        );
      }),
    );
  }
}

// ── Rating bar ────────────────────────────────────────────────────────────────

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.star,
    required this.fraction,
    required this.count,
  });

  final int star;
  final double fraction;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text(
            '$star',
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.star_rounded, color: context.colors.star, size: 11),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: context.colors.muted,
                color: context.colors.star,
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              '${(fraction * count).round()}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary : context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.colors.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.review,
    this.isOwner = false,
    this.onEdit,
    this.onDelete,
  });

  final ProductReview review;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _markedHelpful = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final helpfulTotal =
        review.helpfulCount + (_markedHelpful ? 1 : 0);

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
          // ── Header ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StarRow(rating: review.rating.toDouble(), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          review.date,
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // [جديد] — تعديل/حذف يظهروا بس للريفيو بتاعة اليوزر الحالي
              if (widget.isOwner) ...[
                InkWell(
                  onTap: widget.onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: context.colors.destructive,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Body ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Text(
            review.text,
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          // ── Helpful ─────────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Helpful?',
                style: TextStyle(
                  color: context.colors.mutedForeground,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _markedHelpful
                    ? null
                    : () => setState(() => _markedHelpful = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _markedHelpful
                        ? context.colors.success.withValues(alpha: 0.1)
                        : context.colors.muted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _markedHelpful
                          ? context.colors.success.withValues(alpha: 0.4)
                          : context.colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 12,
                        color: _markedHelpful
                            ? context.colors.success
                            : context.colors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Yes${helpfulTotal > 0 ? ' ($helpfulTotal)' : ''}',
                        style: TextStyle(
                          color: _markedHelpful
                              ? context.colors.success
                              : context.colors.mutedForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
