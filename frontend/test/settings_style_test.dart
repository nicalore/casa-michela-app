import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/shared/widgets/app_gradient_button.dart';
import 'package:frontend/shared/widgets/settings_card.dart';

Future<void> _pump(WidgetTester tester, Widget child) async
{
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 800, child: child),
        ),
      ),
    ),
  );
}

void main()
{
  setUpAll(()
  {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SettingsCard', ()
  {
    testWidgets('lays out its badge, heading and rows', (tester) async
    {
      await _pump(
        tester,
        const SettingsCard(
          title: 'Credenziali di accesso',
          leading: SettingsCardBadge(icon: Icons.manage_accounts_rounded),
          child: SettingsInfoRow(
            label: 'Nome utente',
            value: 'ncalore',
            labelWidth: 140,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Credenziali di accesso'), findsOneWidget);
      expect(find.text('Nome utente'), findsOneWidget);
      expect(find.text('ncalore'), findsOneWidget);
    });

    // The row makes room for a trailing control without pushing the value out
    // of the card: the masked IBAN sits next to its show/hide toggle.
    testWidgets('makes room for a trailing control', (tester) async
    {
      await _pump(
        tester,
        SettingsCard(
          title: 'Dettagli collaborazione',
          leading: const SettingsCardBadge(icon: Icons.account_balance_outlined),
          child: SettingsInfoRow(
            label: 'IBAN',
            value: '•••••••••••••••••••••••••',
            labelWidth: 205,
            valueLetterSpacing: 3,
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.visibility_outlined),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  group('AppGradientButton', ()
  {
    testWidgets('reports the tap and keeps its label on one line', (tester) async
    {
      var taps = 0;

      await _pump(
        tester,
        Center(
          child: AppGradientButton(
            label: 'MODIFICA PASSWORD',
            onPressed: () => taps++,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('MODIFICA PASSWORD')).maxLines, 1);

      await tester.tap(find.text('MODIFICA PASSWORD'));
      expect(taps, 1);
    });

    // The fill is a layer laid over the whole button, brought in and taken away
    // again by the pointer. It must not be there at rest, and taking it away
    // must not leave the button a different size than it started.
    testWidgets('floods under the pointer and drains when it leaves', (tester) async
    {
      await _pump(
        tester,
        Center(
          child: AppGradientButton(label: 'ACCEDI', onPressed: () {}),
        ),
      );

      await tester.pumpAndSettle();
      final atRest = tester.getRect(find.byType(AppGradientButton));

      // One copy of the word at rest: the accent one. No fill, nothing over it.
      expect(find.text('ACCEDI'), findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(AppGradientButton)));
      await tester.pumpAndSettle();

      // Two: the white copy rides in with the fill, over the accent one.
      expect(find.text('ACCEDI'), findsNWidgets(2));
      expect(tester.getRect(find.byType(AppGradientButton)), atRest);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.text('ACCEDI'), findsOneWidget);
      expect(tester.getRect(find.byType(AppGradientButton)), atRest);
    });

    // Pressing moves the button by a pixel and shrinks it by a hundredth: it
    // must animate back on its own, or a button left pressed would drift out of
    // line with whatever stands beside it.
    testWidgets('returns to rest after the press', (tester) async
    {
      await _pump(
        tester,
        Center(
          child: AppGradientButton(label: 'ACCEDI', onPressed: () {}),
        ),
      );

      await tester.pumpAndSettle();
      final atRest = tester.getRect(find.byType(AppGradientButton));

      final gesture = await tester.press(find.text('ACCEDI'));
      await tester.pumpAndSettle();

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(AppGradientButton)), atRest);
    });
  });
}
