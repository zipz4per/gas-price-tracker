import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, Text, View } from 'react-native';

import { ChoiceRow } from '@/components/ChoiceRow';
import { StationRow } from '@/components/StationRow';
import { distanceMetres } from '@/lib/distance';
import { fetchFuelTypes, fetchLocalities, type FuelType, type Locality } from '@/lib/registry';
import { fetchStationPrices, type StationPriceRow } from '@/lib/stationPrices';
import { useDeviceLocation, type DeviceLocation } from '@/lib/useDeviceLocation';

/**
 * The fuel type the screen opens on.
 *
 * Every registered grade is offered, but three of them have no figure anywhere
 * in the data, and opening on one of those would present a screen of explained
 * absences as the app's first impression. RON 95 is the best-covered grade;
 * if it ever leaves the registry the first one there is used instead.
 */
const OPENING_FUEL_TYPE = 'RON_95';

export default function StationListScreen() {
  const [localities, setLocalities] = useState<Locality[] | null>(null);
  const [fuelTypes, setFuelTypes] = useState<FuelType[] | null>(null);
  const [locality, setLocality] = useState<string | null>(null);
  const [fuelType, setFuelType] = useState<string | null>(null);

  const [rows, setRows] = useState<StationPriceRow[] | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  const location = useDeviceLocation();

  useEffect(() => {
    let live = true;

    (async () => {
      try {
        const [loadedLocalities, loadedFuelTypes] = await Promise.all([
          fetchLocalities(),
          fetchFuelTypes(),
        ]);
        if (!live) return;

        setLocalities(loadedLocalities);
        setFuelTypes(loadedFuelTypes);
        setLocality(loadedLocalities[0]?.display_name ?? null);
        setFuelType(
          loadedFuelTypes.find((fuel) => fuel.code === OPENING_FUEL_TYPE)?.code ??
            loadedFuelTypes[0]?.code ??
            null,
        );
      } catch (error) {
        if (live) setFailure(messageOf(error));
      }
    })();

    return () => {
      live = false;
    };
  }, []);

  useEffect(() => {
    if (locality === null || fuelType === null) return;

    let live = true;
    setRows(null);
    setFailure(null);

    (async () => {
      try {
        const loaded = await fetchStationPrices(locality, fuelType);
        if (live) setRows(loaded);
      } catch (error) {
        if (live) setFailure(messageOf(error));
      }
    })();

    return () => {
      live = false;
    };
  }, [locality, fuelType]);

  // The list renders as soon as rows arrive and is reordered if and when a
  // location turns up. It is never waiting on one.
  const listed = useMemo(() => order(rows, location), [rows, location]);

  const localityLabel = locality ?? '—';
  const fuelLabel = fuelTypes?.find((fuel) => fuel.code === fuelType)?.display_name ?? fuelType ?? '—';
  const attribution = rows?.find((row) => row.station_attribution !== null)?.station_attribution;

  return (
    <FlatList
      testID="station-list"
      style={styles.screen}
      data={listed ?? []}
      keyExtractor={(item) => item.row.station_id ?? `${item.row.provider_place_id}`}
      renderItem={({ item }) => <StationRow row={item.row} distance={item.distance} />}
      ListHeaderComponent={
        <View style={styles.header}>
          <Text style={styles.subject}>
            {fuelLabel} in {localityLabel}
          </Text>

          <ChoiceRow
            label="Locality"
            options={(localities ?? []).map((item) => ({
              value: item.display_name,
              label: item.display_name,
            }))}
            selected={locality}
            onSelect={setLocality}
          />
          <ChoiceRow
            label="Fuel type"
            options={(fuelTypes ?? []).map((item) => ({
              value: item.code,
              label: item.display_name,
            }))}
            selected={fuelType}
            onSelect={setFuelType}
          />

          <Text style={styles.ordering}>{orderingNote(location)}</Text>
        </View>
      }
      ListEmptyComponent={
        <View style={styles.notice}>
          {failure !== null ? (
            <Text style={styles.failure}>{failure}</Text>
          ) : (
            <>
              <ActivityIndicator />
              <Text style={styles.loading}>Loading stations…</Text>
            </>
          )}
        </View>
      }
      ListFooterComponent={
        attribution != null ? (
          <View style={styles.footer}>
            {/* Station positions and names come from OpenStreetMap, whose ODbL
                requires the attribution wherever they are shown. The rows carry
                the wording; this displays it. */}
            <Text style={styles.attribution}>{attribution}</Text>
          </View>
        ) : null
      }
    />
  );
}

type ListedStation = { row: StationPriceRow; distance: number | null };

/**
 * Brand and name until a location arrives, distance afterwards.
 *
 * A station with no coordinates cannot be placed and sorts last rather than
 * being dropped — the same rule as a station with no price.
 */
function order(rows: StationPriceRow[] | null, location: DeviceLocation): ListedStation[] | null {
  if (rows === null) return null;

  if (location.status === 'available') {
    const placed = rows.map((row) => ({ row, distance: distanceOf(row, location) }));
    return placed.sort((a, b) => {
      if (a.distance === null) return b.distance === null ? byBrandAndName(a.row, b.row) : 1;
      if (b.distance === null) return -1;
      return a.distance - b.distance;
    });
  }

  return rows.map((row) => ({ row, distance: null })).sort((a, b) => byBrandAndName(a.row, b.row));
}

function distanceOf(
  row: StationPriceRow,
  from: { latitude: number; longitude: number },
): number | null {
  if (row.latitude === null || row.longitude === null) return null;
  return distanceMetres(from.latitude, from.longitude, row.latitude, row.longitude);
}

function byBrandAndName(a: StationPriceRow, b: StationPriceRow): number {
  const brands = (a.brand_display ?? '').localeCompare(b.brand_display ?? '');
  if (brands !== 0) return brands;

  const names = (a.station_name ?? '').localeCompare(b.station_name ?? '');
  if (names !== 0) return names;

  // Twelve Petrons called Petron with no address between them still need a
  // stable order, or the list reshuffles on every render.
  return (a.station_id ?? '').localeCompare(b.station_id ?? '');
}

/**
 * What the list is ordered by, and where the distances went.
 *
 * Said in every state, including the one where location worked: a reader who
 * cannot tell whether the top of the list is nearest or merely alphabetical is
 * reading an unordered list.
 */
function orderingNote(location: DeviceLocation): string {
  switch (location.status) {
    case 'available':
      return 'Sorted by distance from you.';
    case 'pending':
      return 'Sorted by brand and name. Checking whether this device will share its location, to sort by distance.';
    case 'declined':
      return 'Sorted by brand and name. Distances are not shown because location permission was declined.';
    case 'unavailable':
      return 'Sorted by brand and name. Distances are not shown because this device did not provide a location.';
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 14,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D8D8D8',
  },
  subject: {
    fontSize: 20,
    fontWeight: '700',
  },
  ordering: {
    fontSize: 12,
    color: '#5A5A5A',
    lineHeight: 17,
  },
  notice: {
    padding: 24,
    alignItems: 'center',
    gap: 10,
  },
  loading: {
    fontSize: 13,
    color: '#5A5A5A',
  },
  failure: {
    fontSize: 13,
    color: '#A02020',
    textAlign: 'center',
  },
  footer: {
    padding: 16,
  },
  attribution: {
    fontSize: 11,
    color: '#6B6B6B',
  },
});
