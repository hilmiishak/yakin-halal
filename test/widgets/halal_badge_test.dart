import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/widgets/halal_badge.dart';

void main() {
  group('HalalBadge Widget', () {
    group('Certified Badge', () {
      testWidgets('should display correct icon for certified badge', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HalalBadge(type: HalalType.certified)),
          ),
        );

        expect(find.byIcon(Icons.verified), findsOneWidget);
        expect(find.byIcon(Icons.people), findsNothing);
      });

      testWidgets('should display "Certified" text in full mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HalalBadge(type: HalalType.certified)),
          ),
        );

        expect(find.text('Certified Halal'), findsOneWidget);
      });

      testWidgets('should display "Certified" text in compact mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.certified, compact: true),
            ),
          ),
        );

        expect(find.text('Certified'), findsOneWidget);
      });

      testWidgets('should use green color scheme for certified', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.certified, compact: true),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(HalalBadge),
            matching: find.byType(Container).first,
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.green.shade50));
      });
    });

    group('Community Badge', () {
      testWidgets('should display correct icon for community badge', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HalalBadge(type: HalalType.community)),
          ),
        );

        expect(find.byIcon(Icons.people), findsOneWidget);
        expect(find.byIcon(Icons.verified), findsNothing);
      });

      testWidgets('should display "Community Verified" text in full mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HalalBadge(type: HalalType.community)),
          ),
        );

        expect(find.text('Community Verified'), findsOneWidget);
      });

      testWidgets('should display "Community Verified" text in compact mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.community, compact: true),
            ),
          ),
        );

        expect(find.text('Community Verified'), findsOneWidget);
      });

      testWidgets('should use blue color scheme for community', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.community, compact: true),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(HalalBadge),
            matching: find.byType(Container).first,
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue.shade50));
      });
    });

    group('Compact vs Full mode', () {
      testWidgets('compact badge should be smaller', (tester) async {
        // Render compact badge
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.certified, compact: true),
            ),
          ),
        );
        final compactSize = tester.getSize(find.byType(HalalBadge));

        // Render full badge
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.certified, compact: false),
            ),
          ),
        );
        final fullSize = tester.getSize(find.byType(HalalBadge));

        // Compact should be smaller than full
        expect(compactSize.width, lessThan(fullSize.width));
      });

      testWidgets('full badge should have gradient background', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HalalBadge(type: HalalType.certified, compact: false),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(HalalBadge),
            matching: find.byType(Container).first,
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());
      });
    });

    group('Default values', () {
      testWidgets('should default to non-compact mode', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HalalBadge(type: HalalType.certified)),
          ),
        );

        // Full mode shows "Certified Halal", compact shows just "Certified"
        expect(find.text('Certified Halal'), findsOneWidget);
      });
    });
  });
}
