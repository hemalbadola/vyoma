import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/theme/vyoma_theme.dart';
import 'package:vyoma/core/widgets/vy_empty_state.dart';

void main() {
  testWidgets('VyEmptyState renders content and action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VyomaTheme.dark,
        home: Scaffold(
          body: VyEmptyState(
            headline: 'No data',
            body: 'Body copy',
            ctaLabel: 'Act',
            onCta: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('Body copy'), findsOneWidget);
    expect(find.text('ACT'), findsOneWidget);
    await tester.tap(find.text('ACT'));
    await tester.pump();
    expect(pressed, isTrue);
  });
}
