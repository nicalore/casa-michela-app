import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/shared/widgets/app_top_nav.dart';

// The header bar the navigation actually lives in: a fixed height, a width that
// comes from the page, and a Stack that centres it. The bug this file exists for
// only appeared through that chain, so the test reproduces it rather than
// pumping the widget on its own.
//
// The width is far wider than the real bar on purpose. Runtime font fetching is
// off here, so the words are measured with the test font instead of Plus Jakarta
// Sans, and they come out wide enough to overflow a realistic bar. That makes
// this file the wrong place to check that the six entries fit: only the running
// app can answer that.
const double _barWidth = 2400;

// The surface has to be widened first: the default test window is 800 wide, and
// a SizedBox asking for more is simply constrained back down to it, so the bar
// would overflow no matter what width it was given.
Future<void> _pumpBar(WidgetTester tester) async
{
  await tester.binding.setSurfaceSize(const Size(_barWidth, 300));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _barWidth,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [AppTopNav(currentRoute: '/dashboard')],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _hoverOver(WidgetTester tester, Finder target) async
{
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);

  await gesture.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();

  return gesture;
}

void main()
{
  setUpAll(()
  {
    // Without this the fonts are fetched over the network, which a test has no
    // business doing and cannot rely on.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTopNav', ()
  {
    // Regression: the underline used to be squeezed by a FractionallySizedBox,
    // whose intrinsic width is the child's divided by the factor. At rest the
    // factor is zero, so it handed the enclosing IntrinsicWidth an infinity and
    // every entry that was not the current one blew up on first layout.
    testWidgets('lays out with the underlines closed', (tester) async
    {
      await _pumpBar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Impostazioni'), findsOneWidget);
    });

    testWidgets('lays out while an underline opens and closes', (tester) async
    {
      await _pumpBar(tester);

      final gesture = await _hoverOver(tester, find.text('Persone'));
      expect(tester.takeException(), isNull);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // The entry with no page yet is shown but inert, so hovering it must not
    // light it up the way a reachable one does.
    testWidgets('the entry without a page stays quiet under the pointer',
        (tester) async
    {
      await _pumpBar(tester);
      await _hoverOver(tester, find.text('Contabilità'));

      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    // Regression: the words used to be measured by an IntrinsicWidth and then
    // laid out inside that measurement. The app fetches its font over the
    // network, so the first layout measured a stand-in and the real letters,
    // arriving wider, were cut off at the end of every label. Nothing may
    // constrain a destination to less than the width its own text asks for.
    testWidgets('gives every word the width its text asks for', (tester) async
    {
      await _pumpBar(tester);

      const labels = [
        'Home',
        'Persone',
        'Lezioni',
        'Contabilità',
        'Associazione',
        'Impostazioni',
      ];

      for (final label in labels)
      {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));

        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
          reason: '"$label" is laid out narrower than its own text, so it clips',
        );
      }
    });

    // Whatever the animation is doing, the entry keeps the same height: the
    // underline is squeezed by a transform, which paints differently without
    // taking part in layout. If it ever goes back to being squeezed by a width,
    // the row starts twitching under the pointer and this notices.
    testWidgets('an entry keeps its height while the underline opens',
        (tester) async
    {
      await _pumpBar(tester);

      final atRest = tester.getSize(find.text('Persone').first);
      final navAtRest = tester.getSize(find.byType(AppTopNav));

      await _hoverOver(tester, find.text('Persone'));

      expect(tester.getSize(find.text('Persone').first), atRest);
      expect(tester.getSize(find.byType(AppTopNav)), navAtRest);
    });
  });
}
