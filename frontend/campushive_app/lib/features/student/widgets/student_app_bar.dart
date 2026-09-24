import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

class StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StudentAppBar({
    this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                } else if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.studentDashboard);
                }
              },
            )
          : null,
      title: Image.asset(
        'assets/logos/campus_hive_header_logo.png',
        height: 36,
        fit: BoxFit.contain,
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
