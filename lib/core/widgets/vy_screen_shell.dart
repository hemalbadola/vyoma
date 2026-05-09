// Wraps every screen with consistent padding, background, and top breathing room
import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

class VyScreenShell extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;

  const VyScreenShell({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VyColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VySpacing.screenH,
                  VySpacing.screenTop,
                  VySpacing.screenH,
                  VySpacing.md,
                ),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: VyColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    Expanded(
                      child: Text(title!, style: VyType.title),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
