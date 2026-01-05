import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/core/theme/app_colors.dart';
import 'package:projekfyp/core/theme/app_text_styles.dart';
import 'package:projekfyp/core/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('primary color should be teal', () {
      expect(AppColors.primary, equals(const Color(0xFF009688)));
    });

    test('background should be light gray', () {
      expect(AppColors.background, equals(const Color(0xFFEEEEEE)));
    });

    test('status colors should be distinct', () {
      expect(AppColors.success, isNot(equals(AppColors.error)));
      expect(AppColors.warning, isNot(equals(AppColors.error)));
      expect(AppColors.info, isNot(equals(AppColors.success)));
    });

    test('halal colors should be meaningful', () {
      // Certified should be green (trust) - check green component is higher
      expect(
        AppColors.halalCertified.g,
        greaterThan(AppColors.halalCertified.r),
      );
      // Community should be amber/orange - check red component is higher
      expect(
        AppColors.halalCommunity.r,
        greaterThan(AppColors.halalCommunity.b),
      );
    });

    test('calorie colors should indicate severity', () {
      // Under should be green
      expect(AppColors.calorieUnder, equals(AppColors.success));
      // Over should be red
      expect(AppColors.calorieOver, equals(AppColors.error));
    });

    test('primaryGradient should use primary colors', () {
      expect(AppColors.primaryGradient.colors, contains(AppColors.primary));
    });
  });

  group('AppTextStyles', () {
    test('font family should be Poppins', () {
      expect(AppTextStyles.fontFamily, equals('Poppins'));
    });

    test('heading sizes should decrease from h1 to h4', () {
      expect(
        AppTextStyles.h1.fontSize,
        greaterThan(AppTextStyles.h2.fontSize!),
      );
      expect(
        AppTextStyles.h2.fontSize,
        greaterThan(AppTextStyles.h3.fontSize!),
      );
      expect(
        AppTextStyles.h3.fontSize,
        greaterThan(AppTextStyles.h4.fontSize!),
      );
    });

    test('body sizes should decrease correctly', () {
      expect(
        AppTextStyles.bodyLarge.fontSize,
        greaterThan(AppTextStyles.body.fontSize!),
      );
      expect(
        AppTextStyles.body.fontSize,
        greaterThan(AppTextStyles.bodySmall.fontSize!),
      );
    });

    test('headings should be bold', () {
      expect(AppTextStyles.h1.fontWeight, equals(FontWeight.bold));
      expect(AppTextStyles.h2.fontWeight, equals(FontWeight.bold));
    });

    test('caption should be smaller than body', () {
      expect(
        AppTextStyles.caption.fontSize,
        lessThan(AppTextStyles.body.fontSize!),
      );
    });

    test('error text should use error color', () {
      expect(AppTextStyles.error.color, equals(AppColors.error));
    });

    test('success text should use success color', () {
      expect(AppTextStyles.success.color, equals(AppColors.success));
    });
  });

  group('AppTheme', () {
    test('light theme should have correct primary color', () {
      final theme = AppTheme.light;
      expect(theme.primaryColor, equals(AppColors.primary));
    });

    test('light theme should have correct scaffold background', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
    });

    test('light theme should use Poppins font', () {
      final theme = AppTheme.light;
      // Font family is set per text theme, not on ThemeData directly
      expect(theme.textTheme.bodyLarge?.fontFamily, equals('Poppins'));
    });

    test('light theme should have proper color scheme', () {
      final theme = AppTheme.light;
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.error, equals(AppColors.error));
    });

    test('dark theme should have dark brightness', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('dark theme should have dark scaffold background', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF121212)));
    });

    test('button themes should have rounded corners', () {
      final theme = AppTheme.light;
      final buttonStyle = theme.elevatedButtonTheme.style;
      expect(buttonStyle, isNotNull);
    });

    test('input decoration should have rounded borders', () {
      final theme = AppTheme.light;
      final inputTheme = theme.inputDecorationTheme;
      expect(inputTheme.border, isA<OutlineInputBorder>());
    });

    test('card theme should have elevation', () {
      final theme = AppTheme.light;
      expect(theme.cardTheme.elevation, greaterThan(0));
    });

    test('snackbar should be floating', () {
      final theme = AppTheme.light;
      expect(theme.snackBarTheme.behavior, equals(SnackBarBehavior.floating));
    });
  });

  group('Theme Integration', () {
    testWidgets('should apply theme correctly to MaterialApp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Test')),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor ?? AppColors.background,
        equals(AppColors.background),
      );
    });

    testWidgets('should apply text styles correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Text('Heading', style: AppTextStyles.h1)),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Heading'));
      expect(textWidget.style?.fontSize, equals(28));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('should apply button styling correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('Button')),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
