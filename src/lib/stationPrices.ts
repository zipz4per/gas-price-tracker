import { supabase } from './supabase';
import type { Database } from './database.types';

/**
 * One row of `get_station_prices` — a station, a fuel type, whatever figure the
 * system can stand behind, and the sentence saying what kind of figure it is.
 *
 * `price_basis` is a domain over text and the type generator emits `unknown`
 * for domains, which would let a call site render it without ever noticing it
 * is a sentence. It is narrowed here to what the database actually guarantees:
 * the domain is non-nullable, so every row carries one, including rows with no
 * figure at all.
 */
export type StationPriceRow = Omit<
  Database['public']['CompositeTypes']['station_price_result'],
  'price_basis'
> & { price_basis: string };

export type PriceKind = Database['public']['Enums']['price_kind'];

/**
 * Every station in a locality, with whatever the system can say about the price
 * of one fuel type there.
 *
 * A station with nothing to say comes back too, carrying the reason. Nothing
 * here filters, and nothing should: the absent rows are the majority of this
 * data, and dropping them would empty the screen precisely where the system is
 * least informative rather than admitting it.
 */
export async function fetchStationPrices(
  locality: string,
  fuelType: string,
): Promise<StationPriceRow[]> {
  const { data, error } = await supabase.rpc('get_station_prices', {
    p_locality: locality,
    p_fuel_type: fuelType,
  });

  if (error) {
    throw new Error(`Could not load prices for ${fuelType} in ${locality}: ${error.message}`);
  }

  return (data ?? []) as StationPriceRow[];
}
