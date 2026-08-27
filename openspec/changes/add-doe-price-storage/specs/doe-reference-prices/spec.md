## Purpose

Stores and serves the official DOE pump-price figures that give every covered locality an authoritative price baseline, including the provenance needed to say how old the data is and where it came from, and the degradation rules that keep good data on screen when a refresh goes wrong.

## ADDED Requirements

### Requirement: Reference price record content

The system SHALL store DOE reference prices as records keyed by locality, fuel type, and brand. Each record MUST carry the minimum and maximum price reported for that combination, and MAY carry a common (prevailing) price where the source publishes one.

Supported fuel types MUST cover those published by DOE: RON 100, RON 97, RON 95, RON 91, Diesel, Diesel Plus, and Kerosene. Brands MUST include those published as columns in the source reports, together with an aggregate independent-dealer category and an overall-range entry that is not attributed to any single brand.

#### Scenario: A per-brand record is stored

- **WHEN** the Tanauan City RON 91 row reports a Petron range of 74.50 to 74.50
- **THEN** a record exists for locality Tanauan City, fuel type RON 91, brand Petron
- **AND** its minimum and maximum prices are both 74.50

#### Scenario: An overall range is stored independently of brand

- **WHEN** a locality's fuel type row publishes an overall range across all brands
- **THEN** that range is retrievable without being attributed to any individual brand

#### Scenario: Common price is optional

- **WHEN** a source row publishes a range but no common price
- **THEN** the record is stored with its range
- **AND** the common price is recorded as absent rather than as zero

### Requirement: Provenance and reporting period

Every reference price record SHALL carry provenance: the address of the source document it came from, the start and end dates of the period the document reports on, the period label exactly as the document expresses it, and the timestamp at which the data was recorded.

Reporting periods MUST NOT be assumed to be one week. Period length varies between DOE regions and MUST be stored as an explicit start and end date.

#### Scenario: A seven-day NCR period is stored

- **GIVEN** the NCR report states `For the week of August 18-24, 2026`
- **WHEN** its rows are recorded
- **THEN** the period start is 2026-08-18 and the period end is 2026-08-24
- **AND** the original period label is retained verbatim

#### Scenario: A three-day CALABARZON period is stored

- **GIVEN** the CALABARZON report states `DATE MONITORING: August 18 - 20, 2026`
- **WHEN** its rows are recorded
- **THEN** the period start is 2026-08-18 and the period end is 2026-08-20
- **AND** the record is not widened or relabelled to a week

#### Scenario: Source address is retained

- **WHEN** any reference price record is retrieved
- **THEN** the address of the document it was taken from is available with it

### Requirement: Absent and unavailable values are normalized

Source documents express missing data in several ways, including an unavailable marker, a literal `None`, a zero value, and a marker denoting that a locality has no fuel retail outlet at all. The system SHALL normalize these into explicit states and MUST NOT store any of them as a real price.

A locality marked as having no retail outlet MUST be distinguishable from a locality for which data is merely missing.

#### Scenario: Unavailable markers are not stored as prices

- **WHEN** a source cell contains an unavailable marker or the literal `None`
- **THEN** the corresponding value is recorded as absent
- **AND** it is never returned to a consumer as a price

#### Scenario: Zero is treated as absent, not as a price

- **WHEN** a source row publishes a range of `0.00 - 0.00`
- **THEN** the range is recorded as absent
- **AND** no zero-peso price is retrievable for that combination

#### Scenario: No retail outlet is a distinct state

- **GIVEN** a source row marks a locality as having no liquid fuel retail outlet
- **WHEN** reference data for that locality is retrieved
- **THEN** the result reports that the locality has no retail outlet
- **AND** this is distinguishable from data being unavailable

### Requirement: Zero rows for a configured locality is a failure

A data-loading run that produces no rows for a locality present in the registry SHALL be treated as a failure of that run, not as a valid report that the locality has no data. The failure MUST be recorded in a form an operator can review.

This distinguishes a genuine source-side absence, which is expressed by an explicit no-retail-outlet marker, from a silent matching failure caused by a renamed, reformatted, or misspelled source label.

#### Scenario: A renamed source label is surfaced as a failure

- **GIVEN** Taguig City is present in the registry
- **WHEN** a data-loading run matches no rows for Taguig City
- **THEN** the run is recorded as failed for that locality
- **AND** an operator-reviewable record of the failure is retained

#### Scenario: An explicit no-outlet marker is not a failure

- **GIVEN** the source explicitly marks a registered locality as having no retail outlet
- **WHEN** a data-loading run processes that locality
- **THEN** the run is not recorded as failed
- **AND** the no-retail-outlet state is stored

### Requirement: A failed or partial load must not destroy good data

A data-loading run that fails, or that yields data for only part of a locality's expected content, SHALL NOT overwrite or delete previously recorded reference data for that locality. The most recent successfully recorded data MUST remain retrievable.

#### Scenario: Previous data survives a failed run

- **GIVEN** reference data for Lipa City recorded for the period ending 2026-08-20
- **WHEN** a subsequent load for Lipa City fails
- **THEN** the data for the period ending 2026-08-20 remains retrievable
- **AND** consumers continue to receive it

#### Scenario: A partial load does not replace a complete one

- **GIVEN** a locality has complete reference data for all published fuel types
- **WHEN** a later run records data for only one fuel type
- **THEN** the previously recorded data for the remaining fuel types remains retrievable
