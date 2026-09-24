import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.standardCardPadding),
    this.margin = EdgeInsets.zero,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin,
      child: Padding(padding: padding, child: child),
    );

    return onTap == null ? card : InkWell(onTap: onTap, child: card);
  }
}
