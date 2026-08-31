import { CONTENT_MAX_WIDTH, GRID_GAP, SCREEN_PADDING, cardWidthFor, columnsFor } from './grid';

describe('columnsFor', () => {
  it.each([
    ['a phone', 390, 1],
    ['a large phone', 430, 1],
    ['a small tablet held upright', 768, 2],
    ['a laptop', 1024, 2],
    ['a wide window', 1440, 3],
    ['an absurd window', 3840, 3],
  ])('gives %s %s px worth of room %i column(s)', (_what, width, expected) => {
    expect(columnsFor(width)).toBe(expected);
  });

  it('never returns fewer than one column, however narrow the window', () => {
    expect(columnsFor(0)).toBe(1);
    expect(columnsFor(120)).toBe(1);
  });
});

describe('cardWidthFor', () => {
  it('has no width to give when there is one column', () => {
    expect(cardWidthFor(390, 1)).toBeUndefined();
  });

  it('divides the content width evenly, leaving room for the gaps', () => {
    const columns = 3;
    const card = cardWidthFor(1440, columns)!;

    const usable = CONTENT_MAX_WIDTH - SCREEN_PADDING * 2;
    expect(card * columns + GRID_GAP * (columns - 1)).toBeCloseTo(usable, 6);
  });

  it('stops widening once the window passes the content cap', () => {
    expect(cardWidthFor(1440, 3)).toBe(cardWidthFor(3840, 3));
  });
});
