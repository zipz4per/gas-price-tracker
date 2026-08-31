import { StyleSheet, Text, View } from 'react-native';

import { StationPrice } from './StationPrice';
import { formatDistance } from '@/lib/distance';
import type { StationPriceRow } from '@/lib/stationPrices';

/**
 * One station in the list: who it is, where it is, and — through the one
 * component allowed to say so — what it charges.
 *
 * `distance` is null until a location arrives, and stays null if none ever
 * does. It is the only thing on this row that depends on the device.
 *
 * `layout` is the shape the list has room for, decided by the list rather than
 * here: a full-bleed row separated by hairlines when there is one column, a
 * bordered card of a fixed width when they sit side by side. Same content
 * either way — a card and a row differ in their edges, not in what they say.
 */
export function StationRow({
  row,
  distance,
  layout = 'row',
  width,
}: {
  row: StationPriceRow;
  distance: number | null;
  layout?: 'row' | 'card';
  width?: number;
}) {
  // A locality holds a dozen Petrons all called "Petron". The address, where
  // the provider supplied one, is often the only thing telling two of them
  // apart before a distance is available.
  const identity = row.station_name ?? row.brand_display ?? 'Unnamed station';
  const showBrand = row.brand_display !== null && row.brand_display !== identity;

  return (
    <View
      testID="station-row"
      style={[
        styles.base,
        layout === 'card' ? styles.card : styles.row,
        width !== undefined ? { width } : null,
      ]}
    >
      <View style={styles.identity}>
        <View style={styles.names}>
          <Text style={styles.name} testID="station-name">
            {identity}
          </Text>
          {showBrand ? <Text style={styles.brand}>{row.brand_display}</Text> : null}
          {row.address !== null ? (
            <Text style={styles.address} numberOfLines={2}>
              {row.address}
            </Text>
          ) : null}
        </View>
        {distance !== null ? (
          <Text style={styles.distance} testID="station-distance">
            {formatDistance(distance)}
          </Text>
        ) : null}
      </View>
      <StationPrice row={row} />
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    gap: 6,
  },
  row: {
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D8D8D8',
  },
  card: {
    padding: 14,
    borderWidth: 1,
    borderColor: '#E2E2E2',
    borderRadius: 10,
    backgroundColor: '#FFFFFF',
  },
  identity: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 12,
  },
  names: {
    flexShrink: 1,
  },
  name: {
    fontSize: 16,
    fontWeight: '600',
  },
  brand: {
    fontSize: 13,
    color: '#4A4A4A',
  },
  address: {
    fontSize: 12,
    color: '#6B6B6B',
  },
  distance: {
    fontSize: 13,
    fontVariant: ['tabular-nums'],
    color: '#2A5CA8',
  },
});
