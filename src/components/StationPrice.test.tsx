import { render, screen } from '@testing-library/react-native';

import { StationPrice } from './StationPrice';
import type { StationPriceRow } from '@/lib/stationPrices';

/**
 * A row as `get_station_prices` returns one. Everything the four states do not
 * use comes back null from the database too, so the empty row is the honest
 * starting point rather than a convenience.
 */
function row(overrides: Partial<StationPriceRow>): StationPriceRow {
  return {
    station_id: '00000000-0000-0000-0000-000000000000',
    provider_place_id: 'node/1',
    station_name: 'Petron',
    brand_code: 'PETRON',
    brand_display: 'Petron',
    address: null,
    latitude: 13.9411,
    longitude: 121.1622,
    locality: 'Lipa City',
    fuel_type: 'ron95',
    fuel_display: 'Gasoline RON 95',
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
    doe_source_locality: null,
    proxy_source: null,
    period_start: null,
    period_end: null,
    period_label: null,
    source_url: null,
    station_attribution: '© OpenStreetMap contributors',
    ...overrides,
  };
}

const OBSERVED = row({
  price_kind: 'observed',
  price_basis: 'Reported at this station on 30 Aug 2026. 3 report(s) on record.',
  price: 52.9,
  report_count: 3,
  newest_report_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
  adjustments_applied: 0,
});

const DERIVED = row({
  price_kind: 'derived',
  price_basis:
    'Estimated from a report of 52.90 at this station on 12 Aug 2026, adjusted by +0.85 ' +
    'across 2 announced price change(s). Not observed since.',
  price: 53.75,
  report_count: 1,
  newest_report_at: new Date(Date.now() - 19 * 24 * 60 * 60 * 1000).toISOString(),
  baseline_price: 52.9,
  baseline_observed_at: '2026-08-12T09:00:00+08:00',
  adjustments_applied: 2,
});

/** A Malvar station: covered through Tanauan City, and it must say so. */
const REFERENCE = row({
  locality: 'Malvar',
  price_kind: 'reference',
  price_basis:
    'Locality-wide DOE range across all brands in Tanauan City, used as a proxy for Malvar. ' +
    'Not a price observed at this station.',
  min_price: 51.5,
  max_price: 55.2,
  common_price: 53.0,
  doe_source_locality: 'Tanauan City',
  proxy_source: 'Tanauan City',
});

const ABSENT = row({
  fuel_type: 'ron97',
  fuel_display: 'Gasoline RON 97',
  price_kind: null,
  absence_reason: 'fuel_type_not_reported',
  price_basis:
    'No price: nobody has reported here and DOE does not report Gasoline RON 97 in Lipa City.',
});

describe('StationPrice', () => {
  // The guarantee the whole change exists to keep, asserted for every state a
  // price can be displayed in. Delete the sentence from the component and all
  // four of these fail.
  it.each([
    ['observed', OBSERVED],
    ['derived', DERIVED],
    ['reference', REFERENCE],
    ['absent', ABSENT],
  ])('displays the statement the row supplied for the %s case', async (_kind, subject) => {
    await render(<StationPrice row={subject} />);

    expect(screen.getByText(subject.price_basis)).toBeOnTheScreen();
  });

  it('shows an observed price with its report count and how long ago it was observed', async () => {
    await render(<StationPrice row={OBSERVED} />);

    expect(screen.getByText('₱52.90')).toBeOnTheScreen();
    expect(screen.getByText('Observed')).toBeOnTheScreen();
    expect(screen.getByText('3 reports · observed 2 hours ago')).toBeOnTheScreen();
  });

  it('marks a derived price as carried forward rather than observed', async () => {
    await render(<StationPrice row={DERIVED} />);

    expect(screen.getByText('₱53.75')).toBeOnTheScreen();
    expect(screen.getByText('Derived')).toBeOnTheScreen();
    // The date of the observation it descends from travels in the statement,
    // which the component displays verbatim.
    expect(screen.getByText(/12 Aug 2026/)).toBeOnTheScreen();
  });

  it('shows a reference price as a range across the locality, naming the proxy', async () => {
    await render(<StationPrice row={REFERENCE} />);

    expect(screen.getByText('₱51.50–₱55.20')).toBeOnTheScreen();
    expect(screen.getByText('Locality range')).toBeOnTheScreen();
    expect(screen.getByText(/Tanauan City/)).toBeOnTheScreen();
    expect(screen.queryByText(/^₱55\.20$/)).toBeNull();
  });

  it('shows an absence with its reason and no numeric value', async () => {
    await render(<StationPrice row={ABSENT} />);

    expect(screen.getByText('No price')).toBeOnTheScreen();
    expect(screen.getByText(ABSENT.price_basis)).toBeOnTheScreen();

    // Not a zero, not a blank, not an em dash standing in for a price.
    expect(screen.queryByText(/₱/)).toBeNull();
    expect(screen.queryByText(/^\s*(0(\.00)?|—|-)\s*$/)).toBeNull();
  });
});
