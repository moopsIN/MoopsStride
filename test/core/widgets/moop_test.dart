import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/theme/app_theme.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final mood in MoopMood.values) {
      testWidgets('Moop renders $mood (${theme.brightness.name})', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: Moop(mood: mood, size: 120))),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(Moop), findsOneWidget);
        expect(tester.getSize(find.byType(Moop)), const Size(120, 138));
      });
    }
  }

  testWidgets('running Moop animates and disposes cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Moop(running: true)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (var growth = 0; growth <= 3; growth++) {
    testWidgets('Moop renders growth stage $growth', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Center(child: Moop(growth: growth, animate: false))));
      expect(tester.takeException(), isNull);
    });
  }
}
