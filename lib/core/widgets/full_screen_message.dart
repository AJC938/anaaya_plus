import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen (not inline-section) empty/error/unavailable content, shared
/// across features (Services, Cars, ...) for states that own the whole
/// screen rather than a section within a larger page.
class FullScreenMessage extends StatelessWidget {
  const FullScreenMessage({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color? iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh, size: 18), label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
