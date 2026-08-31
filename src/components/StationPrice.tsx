import { StyleSheet, Text, View } from 'react-native';

import type { StationPriceRow } from '@/lib/stationPrices';

/**
 * The only thing in this app that renders a price.
 *
 * It takes a whole result row and never a number. There is no prop for a bare
 * figure, no exported formatter that accepts one, and so no path by which a
 * call site can put a price on screen without the kind of claim it is and the
 * sentence describing it coming with it.
 *
 * Postgres enforces that guarantee up to the network boundary — `price_basis`
 * is a non-nullable domain, so a caller cannot obtain a figure without
 * receiving the statement — and cannot enforce it one step further. This
 * component's shape is what carries the rule the rest of the way: dropping the
 * statement means reaching past the component that exists and writing another
 * one, which review can see.
 *
 * The row with no figure is the same component, not a branch at the call site.
 * Absence is a state a station is displayed in.
 */
export function StationPrice({ row }: { row: StationPriceRow }) {
  return (
    <View style={styles.container}>
      <View style={styles.headline}>
        <Figure row={row} />
        <Text style={[styles.kind, kindStyles[kindOf(row)]]}>{KIND_LABELS[kindOf(row)]}</Text>
      </View>
      <Meta row={row} />
      {/*
        The sentence as the read path composed it. Not abbreviated to a label,
        not behind a tap, not rewritten here.
      */}
      <Text style={styles.basis}>{row.price_basis}</Text>
    </View>
  );
}

/**
 * Which of the four states this row is in. `price_kind` is null exactly when no
 * rung yielded a figure, which is the absent state rather than a missing value.
 */
type DisplayKind = 'observed' | 'derived' | 'reference' | 'absent';

function kindOf(row: StationPriceRow): DisplayKind {
  return row.price_kind ?? 'absent';
}

const KIND_LABELS: Record<DisplayKind, string> = {
  observed: 'Observed',
  derived: 'Derived',
  reference: 'Locality range',
  absent: 'No price',
};

function Figure({ row }: { row: StationPriceRow }) {
  const kind = kindOf(row);

  // A range across the locality, shown as a range. Presenting either end of it
  // as this station's price would be the one misreading the whole design is
  // arranged to prevent.
  if (kind === 'reference') {
    if (row.min_price === null || row.max_price === null) return null;
    return (
      <Text style={[styles.figure, styles.rangeFigure]}>
        {peso(row.min_price)}–{peso(row.max_price)}
      </Text>
    );
  }

  // No figure means no figure: not a zero, not a blank space where one would
  // sit, not an em dash standing in for a number nobody has.
  if (kind === 'absent' || row.price === null) return null;

  return <Text style={styles.figure}>{peso(row.price)}</Text>;
}

/**
 * What travels with the figure beyond the sentence: how fresh an observation is
 * and how many reports stand behind it. A price is perishable, and two stations
 * showing the same number an hour and a month apart are saying different
 * things.
 */
function Meta({ row }: { row: StationPriceRow }) {
  const kind = kindOf(row);

  if (kind === 'observed' && row.newest_report_at !== null) {
    return (
      <Text style={styles.meta}>
        {reportCount(row.report_count)} · observed {age(row.newest_report_at, Date.now())}
      </Text>
    );
  }

  // The derived case carries its distance from an observation in the statement
  // itself — the baseline figure, the date it was observed, and the adjustments
  // applied since. What is added here is the count of reports behind that
  // baseline, which the sentence does not mention.
  if (kind === 'derived' && row.report_count !== null) {
    return <Text style={styles.meta}>{reportCount(row.report_count)} on record</Text>;
  }

  return null;
}

function reportCount(count: number | null): string {
  const n = count ?? 0;
  return `${n} ${n === 1 ? 'report' : 'reports'}`;
}

/**
 * How long ago, relative to now. Coarse on purpose: the useful distinction is
 * between this morning, last week and last month, and a figure precise to the
 * minute would imply the underlying claim is that precise.
 */
function age(observedAt: string, now: number): string {
  const elapsed = now - Date.parse(observedAt);
  const minutes = Math.floor(elapsed / 60_000);

  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} ${hours === 1 ? 'hour' : 'hours'} ago`;

  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} ${days === 1 ? 'day' : 'days'} ago`;

  const months = Math.floor(days / 30);
  return `${months} ${months === 1 ? 'month' : 'months'} ago`;
}

// Deliberately not exported. A helper that turns a number into a rendered price
// is the thing this component exists instead of: once one is importable, a call
// site can show a figure and forget the sentence, which is the arrangement the
// database comments have been arguing against all along.
function peso(value: number): string {
  return `₱${value.toFixed(2)}`;
}

const COLOURS = {
  observed: '#1B7F3B',
  derived: '#9A6114',
  reference: '#2A5CA8',
  absent: '#6B6B6B',
} as const;

const styles = StyleSheet.create({
  container: {
    gap: 2,
  },
  headline: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 8,
  },
  figure: {
    fontSize: 22,
    fontWeight: '600',
    fontVariant: ['tabular-nums'],
  },
  rangeFigure: {
    fontSize: 18,
  },
  kind: {
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  meta: {
    fontSize: 12,
    color: '#4A4A4A',
  },
  basis: {
    fontSize: 12,
    color: '#5A5A5A',
    lineHeight: 17,
  },
});

// A colour and a weight each, so the four states are told apart before the
// sentence is read.
const kindStyles = StyleSheet.create({
  observed: { color: COLOURS.observed, fontWeight: '700' },
  derived: { color: COLOURS.derived, fontWeight: '600' },
  reference: { color: COLOURS.reference, fontWeight: '600' },
  absent: { color: COLOURS.absent, fontWeight: '500' },
});
