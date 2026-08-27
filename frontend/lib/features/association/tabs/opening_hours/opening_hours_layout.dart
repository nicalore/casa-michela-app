// Fixed heights for the three Orari cards. kHoursTableCardHeight is measured
// (test/measure_card_heights_test), not derived; the table itself is not
// pinned to it, so taller font metrics degrade gracefully.
const double kHoursTableCardHeight = 619;
const double kHoursCardGap = 24;

const double kUpcomingVariationsCardHeight = kHoursTableCardHeight;

// Clears the three bands a single day can hold.
const double kStandardHoursCardHeight = 300;

// Compact AppCard chrome: 26 padding, 64 badge, 20 either side of the rule.
const double kHoursCardChrome = 26 * 2 + 64 + (20 + 1 + 20);

// Below this the cards stack; derived from the seven-column board, the tighter
// of the two.
const double kHoursCompactBreakpoint = 7 * 140 + 26 * 2;

// Below this the week nav no longer fits beside the card's title. Measured
// against the card, not the window.
const double kHoursTableNavBreakpoint = 760;

// At 4:2:2:2 the band columns get 88 and "09:00–13:00" needs 85. Must stay
// under the 532 the lower cards get on a 1440 page, or a full window gets the
// phone layout.
const double kHoursTableColumnsBreakpoint = 460;

const double kHoursActionButtonHeight = 52;
