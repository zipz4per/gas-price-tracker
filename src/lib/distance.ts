/**
 * One definition of distance, matching `distance_metres()` in the database.
 *
 * Equirectangular, deliberately: it is what the proximity gate uses to decide
 * whether a submitter is standing at a station, and a distance shown on screen
 * that disagreed with the one that gate applies would be a discrepancy nobody
 * could explain from the app. At a few hundred metres, at 14 degrees north, the
 * approximation error is centimetres.
 *
 * The SQL is:
 *
 *   111320 * sqrt(power(lat_a - lat_b, 2)
 *                 + power((lon_a - lon_b) * cos(radians(lat_a)), 2))
 *
 * Note the cosine is taken at the FIRST latitude, not at the midpoint. That is
 * an asymmetry, and it is copied rather than corrected: two formulas that
 * almost agree are worse than one that is slightly rough.
 */
const METRES_PER_DEGREE = 111_320;

export function distanceMetres(
  latA: number,
  lonA: number,
  latB: number,
  lonB: number,
): number {
  const dLat = latA - latB;
  const dLon = (lonA - lonB) * Math.cos((latA * Math.PI) / 180);
  return METRES_PER_DEGREE * Math.sqrt(dLat * dLat + dLon * dLon);
}

/**
 * Coarse on purpose. A metre of precision on a GPS fix that is accurate to
 * twenty would be a claim the device never made.
 */
export function formatDistance(metres: number): string {
  if (metres < 1000) return `${Math.round(metres / 10) * 10} m`;
  return `${(metres / 1000).toFixed(1)} km`;
}
