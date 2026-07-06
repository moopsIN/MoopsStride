import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/core/widgets/stat_card.dart';
import 'package:stride/core/widgets/empty_state.dart';
import 'package:stride/theme/app_theme.dart';

void main() {
  Widget createTestApp(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Core Reusable Widgets Tests', () {
    testWidgets('StatCard renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        const StatCard(
          label: 'Pace',
          value: '5:30',
          unit: '/km',
          icon: Icons.timer,
        ),
      ));

      expect(find.text('PACE'), findsOneWidget);
      expect(find.text('5:30'), findsOneWidget);
      expect(find.text('/km'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('EmptyState renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        const EmptyState(
          icon: Icons.list,
          title: 'No Data',
          subtitle: 'Check back later',
        ),
      ));

      expect(find.byIcon(Icons.list), findsOneWidget);
      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Check back later'), findsOneWidget);
    });
  });
}
