import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/widgets/custom_text_field.dart';
import 'package:ananya/widgets/form_field_shell.dart';

/// The sign-up and sign-in forms.
///
/// Two things were reported from a real phone. The link at the bottom of
/// sign-up — the one that takes someone who already has an account to sign in —
/// sat underneath the Android navigation bar and could not be read or tapped.
/// And every text box was blank, while the dropdowns beside them already said
/// "একটি বেছে নিন", so the label above each box was carrying all the guidance.
/// A label says what a field is; it does not say what to put in it.
void main() {
  Future<void> pumpField(
    WidgetTester tester,
    CustomTextField field, {
    Locale locale = const Locale('bn'),
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: field),
    ));
    await tester.pumpAndSettle();
  }

  group('an empty box says what belongs in it', () {
    testWidgets('the hint reaches the field', (tester) async {
      await pumpField(
        tester,
        CustomTextField(
          text: 'নাম',
          controller: TextEditingController(),
          hintText: 'আপনার নাম লিখুন',
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'আপনার নাম লিখুন');
      expect(find.text('আপনার নাম লিখুন'), findsOneWidget);
    });

    testWidgets('it is a hint, not a value', (tester) async {
      // A hint that looks like typed text reads as a field already filled in.
      final controller = TextEditingController();
      await pumpField(
        tester,
        CustomTextField(
          text: 'নাম',
          controller: controller,
          hintText: 'আপনার নাম লিখুন',
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(controller.text, isEmpty, reason: 'the box is still empty');
      expect(field.decoration!.hintStyle!.color, isNot(field.style!.color),
          reason: 'the hint must be lighter than real input');
      expect(field.decoration!.hintStyle!.fontWeight!.value,
          lessThan(field.style!.fontWeight!.value),
          reason: 'a hint at the weight of typed text reads as already filled');
    });

    testWidgets('a field with no hint is unchanged', (tester) async {
      await pumpField(
        tester,
        CustomTextField(text: 'নাম', controller: TextEditingController()),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, isNull);
    });
  });

  group('both languages have the hints', () {
    for (final code in ['en', 'bn']) {
      testWidgets('$code is complete and translated', (tester) async {
        late AppLocalizations loc;
        await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            loc = AppLocalizations.of(context)!;
            return const SizedBox();
          }),
        ));
        await tester.pumpAndSettle();

        for (final hint in [
          loc.hint_your_name,
          loc.hint_phone_or_email,
          loc.hint_phone,
          loc.hint_password,
          loc.hint_new_password,
        ]) {
          expect(hint.trim(), isNotEmpty);
        }

        if (code == 'bn') {
          // An untranslated hint is worse than none: it tells a Bangla reader
          // the app has switched languages on her mid-form.
          expect(loc.hint_your_name, isNot(loc.hint_password));
          expect(RegExp(r'[ঀ-৿]').hasMatch(loc.hint_your_name), isTrue,
              reason: 'hint_your_name is not in Bangla');
          expect(RegExp(r'[ঀ-৿]').hasMatch(loc.hint_password), isTrue,
              reason: 'hint_password is not in Bangla');
        }
      });
    }
  });

  group('the last row clears the system navigation bar', () {
    // Read from source: the inset is applied by the scroll view's own padding,
    // and a widget test's MediaQuery reports no system intrusion at all, so
    // there is no on-screen difference to measure here. What can be checked is
    // that the screens still ask for the inset.
    test('sign-up adds the bottom view padding to its scroll', () {
      final src = File('lib/screens/sign_up.dart').readAsStringSync();
      expect(src, contains('MediaQuery.viewPaddingOf(context).bottom'),
          reason: 'the sign-in link was hidden under the navigation bar');
      expect(src, isNot(contains('padding: const EdgeInsets.all(24)')),
          reason: 'the flat 24 is what left no room for the navigation bar');
      expect(src, contains('kFormBottomGap'),
          reason: 'clearing the bar by a hair still reads as falling off');
    });

    test('forget-password does too, having no SafeArea', () {
      final src = File('lib/screens/forget_password.dart').readAsStringSync();
      expect(src, contains('MediaQuery.viewPaddingOf(context).bottom'));
      expect(src, contains('kFormBottomGap'));
    });

    test('sign-in relies on its SafeArea and adds its own breathing room', () {
      final src = File('lib/screens/sign_in.dart').readAsStringSync();
      expect(src, contains('SafeArea'),
          reason: 'this is what clears the navigation bar on this screen');
      expect(src, contains('EdgeInsets.fromLTRB(24, 0, 24, kFormBottomGap)'));
    });
  });
test('the gap is big enough to be seen', () {
    // Not a source check: this is the real constant the three screens share.
    // It sits on TOP of the system inset, so a small value would clear the
    // navigation bar and still read as the link touching it — which is what
    // was reported after the first fix.
    expect(kFormBottomGap, greaterThanOrEqualTo(40));
  });
}
