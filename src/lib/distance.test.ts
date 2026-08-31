import { distanceMetres, formatDistance } from './distance';

/**
 * The values on the right came from the database itself — `select
 * public.distance_metres(...)` against the hosted project — not from a second
 * implementation of the formula. That is the whole point of the test: a
 * distance this app shows and a distance the proximity gate applies when
 * accepting a price report must be the same number, and only the database can
 * say what that number is.
 */
describe('distanceMetres', () => {
  it.each([
    [13.9411, 121.1622, 13.950468, 121.165494, 1101.89961081552],
    [13.940948, 121.142909, 13.9411, 121.1622, 2084.2879830121],
    [14.5176, 121.0509, 13.9411, 121.1622, 65287.2115203052],
    [13.9411, 121.1622, 13.9411, 121.1622, 0],
  ])('agrees with distance_metres() for %s,%s to %s,%s', (latA, lonA, latB, lonB, expected) => {
    // Nanometres. Postgres numeric and IEEE doubles do not round identically,
    // and nothing on this screen depends on the difference.
    expect(distanceMetres(latA, lonA, latB, lonB)).toBeCloseTo(expected, 6);
  });
});

describe('formatDistance', () => {
  it('rounds to something a GPS fix can support', () => {
    expect(formatDistance(0)).toBe('0 m');
    expect(formatDistance(447)).toBe('450 m');
    expect(formatDistance(999)).toBe('1000 m');
    expect(formatDistance(1101.9)).toBe('1.1 km');
    expect(formatDistance(65287)).toBe('65.3 km');
  });
});
