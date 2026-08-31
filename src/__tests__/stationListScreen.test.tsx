// Not colocated with the screen, deliberately. `src/app` is expo-router's route
// directory and every file in it becomes a URL — a test placed beside the screen
// exports as a real page and ships in the build.

import { render, screen, waitFor, within } from '@testing-library/react-native';
import { Dimensions, StyleSheet } from 'react-native';

import StationListScreen from '@/app/index';
import { formatDistance } from '@/lib/distance';
import { cardWidthFor, columnsFor } from '@/lib/grid';
import { fetchFuelTypes, fetchLocalities } from '@/lib/registry';
import { fetchStationPrices, type StationPriceRow } from '@/lib/stationPrices';
import { useDeviceLocation, type DeviceLocation } from '@/lib/useDeviceLocation';

// Factories rather than automocks: the real modules reach the Supabase client
// at import time, which is correct in the app — configuration missing is a
// startup failure, not a network error later — and would make this suite
// depend on credentials it has no business holding.
jest.mock('@/lib/registry', () => ({
  fetchLocalities: jest.fn(),
  fetchFuelTypes: jest.fn(),
}));
jest.mock('@/lib/stationPrices', () => ({ fetchStationPrices: jest.fn() }));
jest.mock('@/lib/useDeviceLocation', () => ({ useDeviceLocation: jest.fn() }));

const mockLocalities = fetchLocalities as jest.MockedFunction<typeof fetchLocalities>;
const mockFuelTypes = fetchFuelTypes as jest.MockedFunction<typeof fetchFuelTypes>;
const mockPrices = fetchStationPrices as jest.MockedFunction<typeof fetchStationPrices>;
const mockLocation = useDeviceLocation as jest.MockedFunction<typeof useDeviceLocation>;

/** The registry as the hosted project holds it: three localities, seven grades. */
const LOCALITIES = [
  { display_name: 'Lipa City', sourcing_mode: 'direct' as const, proxy_source_display_name: null },
  {
    display_name: 'Malvar',
    sourcing_mode: 'proxy' as const,
    proxy_source_display_name: 'Tanauan City',
  },
  { display_name: 'Taguig City', sourcing_mode: 'direct' as const, proxy_source_display_name: null },
];

const FUEL_TYPES = [
  { code: 'RON_100', display_name: 'RON 100', sort_order: 10 },
  { code: 'RON_97', display_name: 'RON 97', sort_order: 20 },
  { code: 'RON_95', display_name: 'RON 95', sort_order: 30 },
  { code: 'RON_91', display_name: 'RON 91', sort_order: 40 },
  { code: 'DIESEL', display_name: 'Diesel', sort_order: 50 },
  { code: 'DIESEL_PLUS', display_name: 'Diesel Plus', sort_order: 60 },
  { code: 'KEROSENE', display_name: 'Kerosene', sort_order: 70 },
];

/**
 * Lipa City as the data actually stands: 52 stations, twelve of them Petrons
 * sharing the single name "Petron" and separated by nothing but coordinates.
 */
const BRANDS = [
  ['Petron', 12],
  ['Shell', 11],
  ['Caltex', 9],
  ['Phoenix', 8],
  ['Seaoil', 7],
  ['Cleanfuel', 5],
] as const;

function lipaStations(): { name: string; latitude: number; longitude: number }[] {
  const stations: { name: string; latitude: number; longitude: number }[] = [];
  for (const [brand, count] of BRANDS) {
    for (let i = 0; i < count; i += 1) {
      stations.push({
        name: brand,
        latitude: 13.9411 + stations.length * 0.0013,
        longitude: 121.1622 + stations.length * 0.0009,
      });
    }
  }
  return stations;
}

function row(
  station: { name: string; latitude: number; longitude: number },
  index: number,
  overrides: Partial<StationPriceRow>,
): StationPriceRow {
  return {
    station_id: `station-${index}`,
    provider_place_id: `way/${index}`,
    station_name: station.name,
    brand_code: station.name.toUpperCase(),
    brand_display: station.name,
    address: null,
    latitude: station.latitude,
    longitude: station.longitude,
    locality: 'Lipa City',
    fuel_type: 'RON_95',
    fuel_display: 'RON 95',
    price_kind: null,
    price_basis: '',
    absence_reason: null,
    price: null,
    report_count: null,
    newest_report_at: null,
    baseline_price: null,
    baseline_observed_at: null,
    adjustments_applied: null,
    min_price: null,
    max_price: null,
    common_price: null,
    reference_shifted_by: null,
    doe_source_locality: 'Lipa City',
    proxy_source: null,
    period_start: '2026-08-18',
    period_end: '2026-08-20',
    period_label: 'DATE MONITORING: August 18 - 20, 2026',
    source_url: 'https://example.invalid/doe.pdf',
    station_attribution: '© OpenStreetMap contributors',
    ...overrides,
  };
}

const RON_95_BASIS =
  'Locality-wide DOE range across all brands in Lipa City. Not a price observed at this station.';
const RON_97_BASIS =
  'No price: nobody has reported here and DOE does not report RON 97 in Lipa City.';

/** Every station carries the locality-wide range: what RON 95 looks like today. */
const RON_95_ROWS = lipaStations().map((station, index) =>
  row(station, index, {
    price_kind: 'reference',
    price_basis: RON_95_BASIS,
    min_price: 71.5,
    max_price: 83.6,
  }),
);

/** Nothing reports RON 97 in Lipa City. Every station still appears. */
const RON_97_ROWS = lipaStations().map((station, index) =>
  row(station, index, {
    fuel_type: 'RON_97',
    fuel_display: 'RON 97',
    absence_reason: 'fuel_type_not_reported',
    price_basis: RON_97_BASIS,
  }),
);

function atLocation(location: DeviceLocation) {
  mockLocation.mockReturnValue(location);
}

const DEFAULT_WINDOW = Dimensions.get('window');

/** Resize the window the screen thinks it is being rendered into. */
function windowWidth(width: number) {
  const size = { ...DEFAULT_WINDOW, width };
  Dimensions.set({ window: size, screen: size });
}

beforeEach(() => {
  jest.clearAllMocks();
  mockLocalities.mockResolvedValue(LOCALITIES);
  mockFuelTypes.mockResolvedValue(FUEL_TYPES);
  mockPrices.mockResolvedValue(RON_95_ROWS);
  atLocation({ status: 'pending' });
  Dimensions.set({ window: DEFAULT_WINDOW, screen: DEFAULT_WINDOW });
});

/**
 * What the list was handed, as opposed to what fits on screen.
 *
 * `FlatList` renders a window and fills in as a reader scrolls, so counting
 * rendered nodes would measure virtualisation rather than completeness. The
 * question these tests ask — was any station dropped — is a question about the
 * data the list received, and it is asked there. What is rendered is checked
 * separately, for content.
 */
function listed(): { row: StationPriceRow; distance: number | null }[] {
  return screen.getByTestId('station-list').props.data;
}

async function loaded() {
  await waitFor(() => expect(listed().length).toBeGreaterThan(0));
  return listed();
}

describe('the station list screen', () => {
  it('renders one row per station, filtering none of them out', async () => {
    await render(<StationListScreen />);

    expect(await loaded()).toHaveLength(52);
    expect(mockPrices).toHaveBeenCalledWith('Lipa City', 'RON_95');

    // And what reaches the screen is the price component's output, not a
    // number on its own.
    expect(screen.getAllByTestId('station-row').length).toBeGreaterThan(0);
    for (const node of screen.getAllByTestId('station-row')) {
      expect(within(node).getByText(RON_95_BASIS)).toBeOnTheScreen();
    }
  });

  it('shows the locality and fuel type in view, and offers only covered localities', async () => {
    await render(<StationListScreen />);
    await loaded();

    expect(screen.getByText('RON 95 in Lipa City')).toBeOnTheScreen();

    // Three, and only three. A fourth would be a town get_station_prices
    // rejects with 22023 the moment somebody taps it.
    for (const locality of ['Lipa City', 'Malvar', 'Taguig City']) {
      expect(screen.getAllByText(locality).length).toBeGreaterThan(0);
    }
    expect(screen.queryByText('Tanauan City')).toBeNull();
    expect(screen.queryByText('Batangas City')).toBeNull();

    for (const fuel of FUEL_TYPES) {
      expect(screen.getAllByText(fuel.display_name).length).toBeGreaterThan(0);
    }
  });

  it('lists every station for a fuel type nothing reports, each with its reason', async () => {
    mockPrices.mockResolvedValue(RON_97_ROWS);
    await render(<StationListScreen />);

    const stations = await loaded();
    expect(stations).toHaveLength(52);
    expect(stations.every((entry) => entry.row.price_basis === RON_97_BASIS)).toBe(true);

    // Not an empty state and not an error: 52 stations, each saying why.
    for (const node of screen.getAllByTestId('station-row')) {
      expect(within(node).getByText(RON_97_BASIS)).toBeOnTheScreen();
      expect(within(node).getByText('No price')).toBeOnTheScreen();
      expect(within(node).queryByText(/₱/)).toBeNull();
    }
    expect(screen.queryByText(/Loading stations/)).toBeNull();
    expect(screen.queryByText(/Could not load/)).toBeNull();
  });

  it('orders by brand and name, and states that, before any location arrives', async () => {
    await render(<StationListScreen />);
    const stations = await loaded();

    expect(screen.getByText(/^Sorted by brand and name\./)).toBeOnTheScreen();

    const names = stations.map((entry) => entry.row.station_name ?? '');
    expect(names).toHaveLength(52);
    expect(names).toEqual([...names].sort((a, b) => a.localeCompare(b)));

    // The list did not wait for a location: it is on screen while the request
    // is still pending, and carries no distances.
    expect(stations.every((entry) => entry.distance === null)).toBe(true);
    expect(screen.queryAllByTestId('station-distance')).toHaveLength(0);
  });

  it('reorders by distance and shows one when a location arrives', async () => {
    atLocation({ status: 'available', latitude: 13.9411, longitude: 121.1622 });
    await render(<StationListScreen />);

    const stations = await loaded();
    expect(stations).toHaveLength(52);

    const distances = stations.map((entry) => entry.distance as number);
    expect(distances).toEqual([...distances].sort((a, b) => a - b));

    // The twelve Petrons no longer share an identity. They are the nearest
    // twelve here, and each carries a distance of its own — which is the whole
    // reason to order by it.
    expect(stations.slice(0, 12).map((entry) => entry.row.station_name)).toEqual(
      Array(12).fill('Petron'),
    );
    expect(new Set(distances.slice(0, 12).map(formatDistance)).size).toBe(12);

    expect(screen.getByText('Sorted by distance from you.')).toBeOnTheScreen();
    expect(screen.getAllByTestId('station-distance').length).toBe(
      screen.getAllByTestId('station-row').length,
    );
  });

  it('explains a declined location rather than reporting it as an error', async () => {
    atLocation({ status: 'declined' });
    await render(<StationListScreen />);

    expect(await loaded()).toHaveLength(52);
    expect(
      screen.getByText(
        'Sorted by brand and name. Distances are not shown because location permission was declined.',
      ),
    ).toBeOnTheScreen();
    expect(screen.queryAllByTestId('station-distance')).toHaveLength(0);
    expect(screen.queryByText(/Could not load/)).toBeNull();
  });

  it('explains an unavailable location the same way', async () => {
    atLocation({ status: 'unavailable' });
    await render(<StationListScreen />);

    expect(await loaded()).toHaveLength(52);
    expect(
      screen.getByText(
        'Sorted by brand and name. Distances are not shown because this device did not provide a location.',
      ),
    ).toBeOnTheScreen();
  });

  // The layout answers to the width it is given, not to a guess about the
  // device: the same screen is a phone's single column and a browser's grid of
  // cards, and every station is in it either way.
  it.each([
    ['a phone', 390, 1],
    ['a laptop', 1024, 2],
    ['a wide browser window', 1440, 3],
  ])('lays out %s in %i px as %i column(s)', async (_what, width, columns) => {
    windowWidth(width);
    await render(<StationListScreen />);

    expect(await loaded()).toHaveLength(52);
    expect(columnsFor(width)).toBe(columns);

    const first = StyleSheet.flatten(screen.getAllByTestId('station-row')[0].props.style);

    if (columns === 1) {
      // A full-bleed row taking whatever width there is, separated from the
      // next by a hairline.
      expect(first.width).toBeUndefined();
      expect(first.borderBottomWidth).toBe(StyleSheet.hairlineWidth);
    } else {
      // A card of a settled width, so the last row of a grid that does not
      // divide evenly does not stretch one station across the whole window.
      expect(first.width).toBeCloseTo(cardWidthFor(width, columns)!, 6);
      expect(first.borderRadius).toBeGreaterThan(0);
    }
  });

  it('keeps the subject, the selectors and the attribution out of the scrolling list', async () => {
    await render(<StationListScreen />);
    await loaded();

    // The header and the attribution are siblings of the list, not its header
    // and footer components, so neither scrolls away from a reader forty rows
    // into fifty-two.
    const list = screen.getByTestId('station-list');
    expect(list.props.ListHeaderComponent).toBeUndefined();
    expect(list.props.ListFooterComponent).toBeUndefined();

    expect(screen.getByText('RON 95 in Lipa City')).toBeOnTheScreen();
    expect(screen.getByText('© OpenStreetMap contributors')).toBeOnTheScreen();
  });

  it('displays the OpenStreetMap attribution the rows carry', async () => {
    await render(<StationListScreen />);
    await loaded();

    expect(screen.getByText('© OpenStreetMap contributors')).toBeOnTheScreen();
  });
});
