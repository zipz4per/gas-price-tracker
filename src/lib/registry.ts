import { supabase } from './supabase';
import type { Database } from './database.types';

/**
 * The localities this system covers and the fuel types it recognises.
 *
 * Both are read from the registry rather than hard-coded, so the selector
 * cannot offer a town `get_station_prices` will reject: naming an unregistered
 * locality raises 22023 there, which is the right answer for a caller and a
 * terrible one for a person tapping a chip.
 */
export type Locality = Pick<
  Database['public']['Tables']['localities']['Row'],
  'display_name' | 'sourcing_mode' | 'proxy_source_display_name'
>;

export type FuelType = Pick<
  Database['public']['Tables']['fuel_types']['Row'],
  'code' | 'display_name' | 'sort_order'
>;

export async function fetchLocalities(): Promise<Locality[]> {
  const { data, error } = await supabase
    .from('localities')
    .select('display_name, sourcing_mode, proxy_source_display_name')
    .order('display_name');

  if (error) throw new Error(`Could not load the localities: ${error.message}`);
  return data ?? [];
}

export async function fetchFuelTypes(): Promise<FuelType[]> {
  const { data, error } = await supabase
    .from('fuel_types')
    .select('code, display_name, sort_order')
    .order('sort_order');

  if (error) throw new Error(`Could not load the fuel types: ${error.message}`);
  return data ?? [];
}
