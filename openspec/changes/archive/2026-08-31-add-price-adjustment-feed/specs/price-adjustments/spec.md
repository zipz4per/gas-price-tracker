## Purpose

Establishes what the price of fuel did between one observation and now — the published, signed, per-litre movements that let an observed price stay useful past the day it was observed — and holds the evidence for each one, so that a figure derived from them can be traced back to what was announced and by whom.

## ADDED Requirements

### Requirement: An adjustment is a signed amount for a fuel type effective at a stated time

The system SHALL record a price adjustment as a signed amount per litre, applying to one canonical fuel type, taking effect at a stated instant, together with when it was announced and which sources reported it.

An adjustment SHALL be unique for a fuel type and effective instant. Because derived prices are computed from the adjustments effective since an observation, a duplicate would move every descending price twice, silently and everywhere.

The recorded amount SHALL be signed rather than paired with a direction word. A rollback is a negative adjustment, and representing direction separately from magnitude creates a second thing that can be read wrong.

#### Scenario: An adjustment records what moved, by how much, and from when

- **WHEN** an adjustment is recorded
- **THEN** it names one registered fuel type, a signed amount, and the instant it takes effect
- **AND** it records when it was announced and the sources that reported it

#### Scenario: A rollback is a negative amount

- **WHEN** a price reduction is recorded
- **THEN** the amount is negative
- **AND** no separate direction is stored alongside it

#### Scenario: The same adjustment cannot be recorded twice

- **GIVEN** an adjustment already recorded for a fuel type and effective instant
- **WHEN** the same fuel type and effective instant is recorded again
- **THEN** it is rejected rather than added

### Requirement: An adjustment requires agreement between independent sources

The system SHALL record an adjustment only where at least two independent sources report the same amount for the same fuel category and effective instant.

A single source SHALL NOT establish an adjustment. Where sources disagree on the amount, no adjustment SHALL be recorded, and the disagreement SHALL be recorded as a conflict naming each source and the figure it gave.

The reason is the blast radius. An adjustment moves every derived price in the system at once and is not visible as wrong from inside the system, because every figure downstream of it moves together. Corroboration is the cheapest available guard against a misread figure.

#### Scenario: Two sources agreeing establish an adjustment

- **GIVEN** two independent sources reporting the same amount for one fuel category and effective instant
- **WHEN** the announcement is ingested
- **THEN** an adjustment is recorded
- **AND** both sources are named on it

#### Scenario: One source is not enough

- **GIVEN** only one source reporting an amount
- **WHEN** the announcement is ingested
- **THEN** no adjustment is recorded
- **AND** the run states that corroboration was missing rather than that nothing was announced

#### Scenario: Disagreement records a conflict and no adjustment

- **GIVEN** two sources reporting different amounts for the same fuel category and effective instant
- **WHEN** the announcement is ingested
- **THEN** no adjustment is recorded
- **AND** a conflict is recorded naming each source and the amount it reported

### Requirement: An announced category expands to canonical fuel types through maintained data

Announcements name broad categories — gasoline, diesel, kerosene — while the system stores individual grades. The system SHALL expand an announced category to the canonical fuel types it covers through a maintained mapping, and SHALL record one adjustment per covered fuel type.

An announced category with no mapping SHALL NOT be silently dropped or applied to a guessed set of grades; it SHALL be surfaced for review with the announcement it came from.

#### Scenario: A category becomes one adjustment per covered grade

- **GIVEN** a mapping under which an announced category covers four canonical fuel types
- **WHEN** an adjustment for that category is ingested
- **THEN** four adjustments are recorded, one per covered fuel type
- **AND** each carries the same amount and effective instant

#### Scenario: An unmapped category is surfaced, not guessed

- **WHEN** an announcement names a fuel category with no mapping
- **THEN** no adjustment is recorded for it
- **AND** the category is surfaced for review together with the announcement

### Requirement: The effective time is taken from the announcement, never assumed

The system SHALL take an adjustment's effective instant from the announcement itself. It MUST NOT default to the next weekly cycle, and an announcement from which no effective instant can be determined SHALL produce no adjustment and SHALL be surfaced.

The weekly Tuesday cycle is a convention that announcements usually follow and sometimes do not. An assumed effective time would misdate exactly the off-cycle adjustments the feed exists to catch, and would misdate them invisibly.

Effective instants SHALL be recorded with an explicit time zone.

#### Scenario: A stated effective time is used

- **WHEN** an announcement states its effective date and time
- **THEN** the adjustment takes effect at that instant
- **AND** the instant carries its time zone

#### Scenario: An undeterminable effective time produces nothing

- **WHEN** an announcement's effective instant cannot be determined from it
- **THEN** no adjustment is recorded
- **AND** the announcement is surfaced for review

#### Scenario: An off-cycle adjustment is not moved onto the cycle

- **GIVEN** an announcement effective on a day other than the usual weekly cycle
- **WHEN** it is ingested
- **THEN** the adjustment takes effect on the announced day

### Requirement: Every ingestion attempt is recorded, and finding nothing is a finding

The system SHALL record each ingestion attempt with the time it ran, the sources it consulted, and its outcome. The outcomes SHALL be distinguishable and SHALL at least include: an adjustment was recorded, no adjustment was announced, corroboration was missing, sources conflicted, and the attempt failed.

A failed attempt MUST NOT be recorded or reported as an absence of adjustments. The two have opposite consequences for anything reading the feed: a genuine quiet week means a derived price is still current, while a failed check means nobody knows whether it is.

#### Scenario: A quiet week is recorded as a quiet week

- **GIVEN** an ingestion run that reaches its sources and finds no announcement
- **WHEN** the run completes
- **THEN** it records that no adjustment was announced
- **AND** it is not recorded as a failure

#### Scenario: An unreachable source is a failure, not a quiet week

- **GIVEN** an ingestion run whose sources cannot be reached
- **WHEN** the run completes
- **THEN** it records that the attempt failed
- **AND** it does not record that no adjustment was announced

#### Scenario: The most recent successful run is discoverable

- **WHEN** the state of the feed is consulted
- **THEN** the time of the most recent run that reached its sources is available
- **AND** it is distinguishable from the time of the most recent run of any kind

### Requirement: A recorded adjustment is correctable, and the correction propagates

A published figure may be revised or may have been read wrong. The system SHALL provide a path to correct a recorded adjustment's amount or effective instant, and every price derived from it SHALL reflect the correction without further action.

A correction SHALL retain what the adjustment previously said and why it changed, so that a figure a user saw yesterday can still be explained.

#### Scenario: Correcting an adjustment corrects the prices derived from it

- **GIVEN** stations showing derived prices that descend from a recorded adjustment
- **WHEN** that adjustment's amount is corrected
- **THEN** each derived price reflects the corrected amount
- **AND** no station requires individual intervention

#### Scenario: A correction retains what was superseded

- **WHEN** an adjustment is corrected
- **THEN** the previous amount and effective instant remain recorded
- **AND** the reason for the correction is recorded with them

### Requirement: The feed is checked against an independent measurement

Prices derived from adjustments are downstream of the feed alone: if an amount is misread, every derived price moves together and no comparison within the system reveals it. The system SHALL therefore compare the feed against reference data, which measures the same quantity independently.

When reference data for a new period is loaded, the system SHALL compare the movement in the locality-wide midpoint since the previously loaded period against the sum of adjustments effective over that same interval, and SHALL surface a divergence beyond a stated threshold.

A divergence SHALL be surfaced rather than resolved automatically. It indicates that the feed, the reference data, or the mapping between them is wrong, and which of those it is cannot be determined from the divergence alone.

#### Scenario: Agreement between the feed and the reference data

- **GIVEN** reference data for a new period whose locality-wide midpoint moved by approximately the sum of adjustments over that interval
- **WHEN** the comparison runs
- **THEN** no divergence is surfaced

#### Scenario: A misread amount is caught by the comparison

- **GIVEN** an ingested adjustment whose amount is an order of magnitude below what was announced
- **WHEN** reference data for the following period is loaded and compared
- **THEN** the divergence exceeds the threshold and is surfaced

#### Scenario: A divergence is reported, not corrected

- **WHEN** a divergence beyond the threshold is found
- **THEN** it is surfaced with both measurements and the interval compared
- **AND** no adjustment or reference figure is altered automatically
