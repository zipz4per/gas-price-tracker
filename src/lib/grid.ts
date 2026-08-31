/**
 * How many columns of stations the window has room for, and how wide each one
 * is.
 *
 * Kept out of the screen so it can be reasoned about — and tested — without a
 * window. The rule is a minimum card width rather than a set of device
 * breakpoints: what decides whether two stations fit side by side is whether a
 * station's name, distance, price and the sentence describing that price stay
 * readable, which is a property of the content and not of anyone's phone.
 */
export const CONTENT_MAX_WIDTH = 1180;
export const GRID_GAP = 12;
export const SCREEN_PADDING = 16;

/** Below this a card starts wrapping the basis sentence into a narrow ribbon. */
const MIN_CARD_WIDTH = 330;

/** Three is where a row of cards stops being a list and starts being a wall. */
const MAX_COLUMNS = 3;

export function columnsFor(windowWidth: number): number {
  const usable = Math.min(windowWidth, CONTENT_MAX_WIDTH) - SCREEN_PADDING * 2;
  const fits = Math.floor((usable + GRID_GAP) / (MIN_CARD_WIDTH + GRID_GAP));
  return Math.max(1, Math.min(MAX_COLUMNS, fits));
}

/**
 * The width of one card, in pixels, or undefined for a single column — where
 * the row is full-bleed and has no width of its own.
 *
 * Fixed widths rather than `flex: 1` because the last row is usually not full.
 * Fifty-two stations in three columns leaves one alone on the final row, and a
 * flexed card there would stretch to triple the width of every other card on
 * screen.
 */
export function cardWidthFor(windowWidth: number, columns: number): number | undefined {
  if (columns < 2) return undefined;

  const usable = Math.min(windowWidth, CONTENT_MAX_WIDTH) - SCREEN_PADDING * 2;
  return (usable - GRID_GAP * (columns - 1)) / columns;
}
