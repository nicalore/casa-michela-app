// Fixed heights for the three Orari cards. The variations card is pinned to the
// table's height so the two line up and it stops resizing as data changes.
//
// kHoursTableCardHeight is measured (test/measure_card_heights_test) and not
// derived. The table itself is deliberately not pinned to it: if font metrics
// make it taller, an uneven column bottom beats a hard overflow.
const double kHoursTableCardHeight = 619;
const double kHoursCardGap = 24;

// The variations card stands beside the table, so it takes the table's height.
const double kUpcomingVariationsCardHeight = kHoursTableCardHeight;

// Clears a day's three bands (mattina, pomeriggio, sera) stacked under its
// name, which is the most a single day can hold — so the board keeps one
// height whatever the week turns out to be.
const double kStandardHoursCardHeight = 300;

// Shared by the standard-hours and variations cards: outer padding, header,
// divider block. The three wear AppCard in its compact form, so these are its
// numbers — 26 of padding, a 64 badge, 20 either side of the rule.
const double kHoursCardChrome = 26 * 2 + 64 + (20 + 1 + 20);

// Below this the cards stack: halved, neither the table's four columns nor the
// board's seven stay readable. Derived from the board, the tighter of the two,
// so raising the band size means raising this with it.
const double kHoursCompactBreakpoint = 7 * 140 + 26 * 2;

// Below this the week nav no longer fits beside the card's title (736 of
// padding, badge, title and nav). Measured against the card and not the window:
// a card can be narrow on a window that is not.
const double kHoursTableNavBreakpoint = 760;

// Below this the four columns stop being readable: split 4:2:2:2, the band
// columns get 88 and a "09:00–13:00" needs 85. It has to stay under the 532 the
// lower cards get on a 1440 page, or a full window gets the phone's layout.
const double kHoursTableColumnsBreakpoint = 460;

// The height every button of the new interface stands at — the two in a dialog
// footer, the one under the account card in the settings. These two are peers
// of those, so they take the same height and the same corner as well.
const double kHoursActionButtonHeight = 52;
