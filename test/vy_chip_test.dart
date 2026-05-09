import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/theme/vyoma_theme.dart';
import 'package:vyoma/core/widgets/vy_chip.dart';

void main() {
  testWidgets('VyChip calls onTap and shows label', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VyomaTheme.dark,
        home: Scaffold(
          body: VyChip(
            label: 'Focused',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Focused'), findsOneWidget);
    await tester.tap(find.text('Focused'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
