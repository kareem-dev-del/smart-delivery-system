import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.hint = 'Search products...',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.mutedForeground),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon:
            value.isEmpty
                ? null
                : IconButton(
                  onPressed: () => onChanged(''),
                  icon: const Icon(Icons.close_rounded),
                ),
      ),
      textInputAction: TextInputAction.search,
    );
  }
}
