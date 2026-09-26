import 'package:flutter/material.dart';

enum AppButtonVariant { primary, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.padding,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
              ),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        style: padding != null
            ? ElevatedButton.styleFrom(padding: padding)
            : null,
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        style: padding != null
            ? OutlinedButton.styleFrom(padding: padding)
            : null,
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        style: padding != null ? TextButton.styleFrom(padding: padding) : null,
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
