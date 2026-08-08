// Fixed heights for the three Orari cards.
//
// The standard-hours board runs the full width at the top; the weekly table and
// the variations card sit side by side underneath it. The variations card is
// pinned rather than left to size itself so it stops growing and shrinking as
// data changes — a card that resizes every time a variation is added reads as
// the layout twitching — and pinned to the table's own height so the two line
// up.
//
// kHoursTableCardHeight is a measured value (test/measure_card_heights_test),
// not a derived one: the table's height comes from its 7 fixed rows and
// chrome. The table itself is deliberately NOT pinned to it — if font metrics
// ever make it a few pixels taller, a slightly uneven column bottom is a much
// better failure than a hard overflow.
const double kHoursTableCardHeight = 619;
const double kHoursCardGap = 24;

/// The variations card stands beside the table, so it takes the table's height.
const double kUpcomingVariationsCardHeight = kHoursTableCardHeight;

/// Clears a day's three bands (mattina, pomeriggio, sera) stacked under its
/// name, which is the most a single day can hold — so the board keeps one
/// height whatever the week turns out to be.
const double kStandardHoursCardHeight = 300;

/// Shared by the standard-hours and variations cards: outer padding, header,
/// divider block. The three wear AppCard in its compact form, so these are its
/// numbers — 26 of padding, a 64 badge, 20 either side of the rule.
const double kHoursCardChrome = 26 * 2 + 64 + (20 + 1 + 20);

/// Below this the cards stack instead of sitting side by side: the table's four
/// columns and the standard-hours board's seven both get unreadable once the
/// available width is halved.
///
/// Derived from the board, which is the tighter of the two: seven columns each
/// holding a "09:00–13:00" at 18 with room to breathe either side, plus the
/// card's own 32 of padding on both flanks. Raising the band size again means
/// raising this with it — otherwise the times ellipsise at the narrow end
/// instead of overflowing, which is worse to read.
const double kHoursCompactBreakpoint = 7 * 140 + 26 * 2;

/// Below this the week nav no longer fits beside the card's own title: 52 of
/// padding, a 64 badge, 190 of "Orario settimanale" and the 412 the nav needs
/// come to 736, so this is that with a little air. Measured against the card,
/// not against the window — side by side the two lower cards are half a wide
/// page each, and a card can be narrow on a window that is not.
const double kHoursTableNavBreakpoint = 760;

/// Below this the four columns stop being readable. The row splits 4:2:2:2, so
/// at this width the three band columns get about 88 each and a "09:00–13:00"
/// needs 85 — one pixel narrower and the times start ellipsising. It has to
/// stay under the 532 the two lower cards get on a 1440 page beside the rail,
/// or a full window would be shown the phone's layout.
const double kHoursTableColumnsBreakpoint = 460;

/// The height every button of the new interface stands at — the two in a dialog
/// footer, the one under the account card in the settings. These two are peers
/// of those, so they take the same height and the same corner as well.
const double kHoursActionButtonHeight = 52;
