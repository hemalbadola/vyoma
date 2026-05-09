import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/theme/vyoma_theme.dart';
import 'package:vyoma/core/widgets/vy_card.dart';

void main() {
  testWidgets('VyCard renders child and handles tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VyomaTheme.dark,
        home: Scaffold(
          body: VyCard(
            onTap: () => tapped = true,
            child: const Text('content'),
          ),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    await tester.tap(find.byType(VyCard));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
