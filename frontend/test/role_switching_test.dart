import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/shared/widgets/app_gradient_button.dart';
import 'package:frontend/shared/widgets/role_switch_dialog.dart';
import 'package:frontend/shared/widgets/user_menu.dart';

const List<String> _threeRoles = ['Amministratore', 'Docente', 'Genitore'];

Future<void> _pumpMenu(
  WidgetTester tester, {
  required bool canChangeRole,
  VoidCallback? onChangeRole,
}) async
{
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: UserMenu(
            canChangeRole: canChangeRole,
            onChangeRole: onChangeRole ?? () {},
            onLogout: () {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async
{
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRoleSwitchDialog(
                context: context,
                activeRole: 'Amministratore',
                availableRoles: _threeRoles,
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main()
{
  setUpAll(()
  {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('UserMenu', ()
  {
    testWidgets('offers the role switch to someone who holds several',
        (tester) async
    {
      await _pumpMenu(tester, canChangeRole: true);

      expect(find.text('Cambia ruolo'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    // With one role there is nothing to switch to, and a menu entry leading to
    // a list of one would be a dead end dressed up as a choice.
    testWidgets('holds nothing but the logout for a single role', (tester) async
    {
      await _pumpMenu(tester, canChangeRole: false);

      expect(find.text('Cambia ruolo'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('the entry reports the tap', (tester) async
    {
      var tapped = false;
      await _pumpMenu(
        tester,
        canChangeRole: true,
        onChangeRole: () => tapped = true,
      );

      await tester.tap(find.text('Cambia ruolo'));
      expect(tapped, isTrue);
    });
  });

  group('showRoleSwitchDialog', ()
  {
    testWidgets('lists the roles that can be moved to', (tester) async
    {
      await _openDialog(tester);

      expect(find.text('Docente'), findsOneWidget);
      expect(find.text('Genitore'), findsOneWidget);
      expect(find.text('ANNULLA'), findsOneWidget);
    });

    // The role in use is the title of the dialog. Listing it again would offer
    // the one choice that leads nowhere, so the list holds the alternatives
    // only: the single "Amministratore" on screen is the heading.
    testWidgets('leaves the role already in use out of the list', (tester) async
    {
      await _openDialog(tester);

      expect(find.text('Amministratore'), findsOneWidget);
      expect(find.text('ATTUALE'), findsNothing);
    });

    // Switching is deliberately inert until the other roles have pages of their
    // own: choosing one must not close the dialog and pretend something changed.
    testWidgets('choosing a role does nothing yet', (tester) async
    {
      await _openDialog(tester);

      await tester.tap(find.text('Docente'));
      await tester.pumpAndSettle();

      expect(find.text('ANNULLA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cancel button closes it', (tester) async
    {
      await _openDialog(tester);

      await tester.tap(find.text('ANNULLA'));
      await tester.pumpAndSettle();

      expect(find.text('ANNULLA'), findsNothing);
      expect(find.text('Docente'), findsNothing);
    });

    // Under the pointer the ground floods in from the left and takes the
    // letters white as it passes over them, which means a gradient, a shader
    // mask and a shadow all animating at once. The button has to survive that
    // and still be the thing that closes the dialog.
    //
    // Aimed at the button rather than at its label on purpose: while the fill is
    // on its way the word is on screen twice, once in violet under it and once
    // in white inside it.
    testWidgets('the cancel button survives the pointer and still closes it',
        (tester) async
    {
      await _openDialog(tester);

      final button = find.byType(AppGradientButton);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ANNULLA'), findsWidgets);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('ANNULLA'), findsNothing);
    });
  });
}
