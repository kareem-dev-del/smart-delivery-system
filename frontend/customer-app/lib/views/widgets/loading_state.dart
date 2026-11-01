import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: context.colors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(color: context.colors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}
