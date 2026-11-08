import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';

/// Call with:
///   final success = await WriteReviewSheet.show(
///     context,
///     userName: '...',
///     onSubmit: (rating, text) async {
///       // return null on success, or an error message to show inline.
///     },
///   );
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.userName,
    required this.onSubmit,
    this.initialRating = 0,
    this.initialText = '',
    this.isEditing = false,
  });

  final String userName;

  /// Pre-fills the sheet when editing an existing review.
  final int initialRating;
  final String initialText;
  final bool isEditing;

  /// Called when the user taps "Submit Review". Return `null` on success
  /// (the sheet will close), or an error message to display inline.
  final Future<String?> Function(int rating, String text) onSubmit;

  /// Convenience helper — opens the sheet and returns `true` if the review
  /// was submitted successfully, or `null` if the user dismissed without
  /// submitting.
  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<String?> Function(int rating, String text) onSubmit,
    int initialRating = 0,
    String initialText = '',
    bool isEditing = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(
        userName: userName,
        onSubmit: onSubmit,
        initialRating: initialRating,
        initialText: initialText,
        isEditing: isEditing,
      ),
    );
  }

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  late int _rating = widget.initialRating;
  int _hovered = 0; // for tap-feedback effect
  late final _textController = TextEditingController(text: widget.initialText);
  bool _submitting = false;
  String? _ratingError;
  String? _textError;
  String? _submitError;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }


  Future<void> _submit() async {
    setState(() {
      _ratingError = _rating == 0 ? 'Please select a rating.' : null;
      _textError = _textController.text.trim().isEmpty
          ? 'Please write a review.'
          : null;
      _submitError = null;
    });

    if (_rating == 0 || _textController.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    final errorMessage = await widget.onSubmit(
      _rating,
      _textController.text.trim(),
    );
    if (!mounted) return;

    if (errorMessage == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _submitError = errorMessage;
      });
    }
  }

  String _labelFor(int star) {
    switch (star) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // ── Title row ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.rate_review_rounded,
                  color: context.colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditing ? 'Edit Review' : 'Write a Review',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Share your experience with others',
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Star selector ─────────────────────────────────────────
          Text(
            'Your Rating',
            style: TextStyle(
              color: context.colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= (_hovered > 0 ? _hovered : _rating);
              return GestureDetector(
                onTapDown: (_) => setState(() => _hovered = star),
                onTapUp: (_) {
                  setState(() {
                    _rating = star;
                    _hovered = 0;
                    _ratingError = null;
                  });
                },
                onTapCancel: () => setState(() => _hovered = 0),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AnimatedScale(
                    scale: filled ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? context.colors.star : context.colors.border,
                      size: 38,
                    ),
                  ),
                ),
              );
            }),
          ),
          // Rating label + error
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _rating > 0
                ? Padding(
                    key: ValueKey(_rating),
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _labelFor(_rating),
                      style: TextStyle(
                        color: context.colors.star,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                : _ratingError != null
                    ? Padding(
                        key: const ValueKey('err'),
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _ratingError!,
                          style: TextStyle(
                            color: context.colors.destructive,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 6),
          ),
          const SizedBox(height: 18),

          // ── Review text ───────────────────────────────────────────
          Text(
            'Your Review',
            style: TextStyle(
              color: context.colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) {
              if (_textError != null) {
                setState(() => _textError = null);
              }
            },
            decoration: InputDecoration(
              hintText:
                  'What did you like or dislike? How was the quality?',
              hintStyle: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 13,
              ),
              errorText: _textError,
              counterStyle: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 11,
              ),
            ),
          ),

          // ── Submit error banner ──────────────────────────────────
          // [جديد] بيظهر بس لو الـServer رفض الطلب (بعد ما الـvalidation
          // المحلي عدى بنجاح)، زي ما بيحصل في auth screens.
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.colors.destructive.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _submitError!,
                style: TextStyle(
                  color: context.colors.destructive,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Submit button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Submit Review'),
            ),
          ),
        ],
      ),
    );
  }
}
