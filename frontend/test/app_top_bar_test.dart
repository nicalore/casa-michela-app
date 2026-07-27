import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/auth/models/me_response.dart';
import 'package:frontend/shared/widgets/app_top_bar.dart';
import 'package:frontend/shared/widgets/user_menu.dart';

// Widths the bar has to survive: the page minimum, a window a good deal below
// it, and one small enough that nothing would fit at natural size. The last two
// are what the horizontal page scroll is meant to prevent, but the bar must not
// depend on that to stay in one piece.
const List<double> _widths = [1440, 1100, 800, 600];

// Handed to the bar rather than left to it: without it the widget calls the
// server for the identity, which a test has no business doing, and stays out of
// the tree until an answer arrives that never comes.
const MeResponse _user = MeResponse(
  taxCode: 'CLRNCL97A01L483X',
  username: 'ncalore',
  firstName: 'Nicolò',
  lastName: 'Calore',
  fullName: 'Nicolò Calore',
  profileImageUrl: null,
  availableRoles: ['ADMIN'],
  activeRole: 'ADMIN',
  status: 'ACTIVE',
  passwordResetRequired: false,
);

Future<void> _pumpHeader(WidgetTester tester, double width) async
{
  await tester.binding.setSurfaceSize(Size(width, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 400,
          child: Stack(
            children: [
              const AppTopBar(currentRoute: '/dashboard', user: _user),
            ],
          ),
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

  group('AppTopBar', ()
  {
    // Regression: the destinations used to be a Row centred in a Stack, which
    // handed them the whole bar and let them run past it. In a window narrower
    // than the page minimum they overflowed and the words broke in half.
    //
    // The test font is wider than the one the app ships, so a bar that holds
    // together here holds together in the app as well.
    for (final width in _widths)
    {
      testWidgets('holds together at ${width.toInt()} px', (tester) async
      {
        await _pumpHeader(tester, width);

        expect(tester.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Impostazioni'), findsOneWidget);
        expect(find.text('Amministratore'), findsOneWidget);
        expect(find.text('ASSOCIAZIONE'), findsOneWidget);
        expect(find.text('Casa Michela'), findsOneWidget);
      });
    }

    // Regression: opening the menu used to add a child at the head of the bar's
    // stack, which shifted the bar and the menu down a place. Flutter pairs
    // children with elements by position, so both were torn down and rebuilt on
    // every open — the menu lost the animation it was supposed to arrive with,
    // and every destination lost the state driving its underline.
    group('opening the menu', ()
    {
      Future<void> openMenu(WidgetTester tester) async
      {
        await tester.tap(find.text('Amministratore'));
        await tester.pump();
      }

      testWidgets('leaves the destinations where they were', (tester) async
      {
        await _pumpHeader(tester, 1440);
        await tester.pumpAndSettle();

        final Element before = tester.element(find.text('Home'));

        await openMenu(tester);
        await tester.pumpAndSettle();

        // The same element, not merely the same word: a rebuilt one would have
        // started its underline over from nothing.
        expect(identical(tester.element(find.text('Home')), before), isTrue);
      });

      testWidgets('brings the menu in over time, not at once', (tester) async
      {
        await _pumpHeader(tester, 1440);
        await tester.pumpAndSettle();

        await openMenu(tester);
        await tester.pump(const Duration(milliseconds: 60));

        final FadeTransition fade = tester.widget<FadeTransition>(
          find
              .ancestor(of: find.byType(UserMenu), matching: find.byType(FadeTransition))
              .first,
        );

        expect(fade.opacity.value, greaterThan(0));
        expect(fade.opacity.value, lessThan(1));
      });
    });

    // Each destination stays on one line however tight the bar gets: the row
    // shrinks as a whole rather than letting a word wrap.
    testWidgets('never wraps a destination', (tester) async
    {
      await _pumpHeader(tester, 600);

      final label = tester.widget<Text>(find.text('Contabilità'));

      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
    });
  });
}
