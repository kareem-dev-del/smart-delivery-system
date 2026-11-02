import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/icon_mapper.dart';
import 'package:shopease_mobile/models/category.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
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
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? categoryColor : context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? categoryColor : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconMapper.forCategory(category.icon),
              size: 15,
              color: selected ? Colors.white : categoryColor,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: selected ? Colors.white : context.colors.foreground,
                fontWeight: FontWeight.w500,
                fontSize: 13,
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
