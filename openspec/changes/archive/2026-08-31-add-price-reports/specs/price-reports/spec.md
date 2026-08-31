## Purpose

Holds what a person standing at a pump reports a station is charging — the only source that can say what one station costs rather than what a brand costs across a municipality — and governs how that observation is admitted, how long it remains believable, and what is shown in its place when there is none.

## ADDED Requirements

### Requirement: A price report is one observation at one station

The system SHALL record a price report as a single observed price, for a single registered station, for a single registered fuel type, at a single point in time.

A report SHALL NOT require an account, a login, or a persistent identity. The observation is the contribution; who made it is not recorded.

Where several reports exist for one station and fuel type, the most recent SHALL be the one displayed. Earlier reports SHALL be retained rather than overwritten, so that the history of a station's price remains available.

#### Scenario: A report is attached to one station and one fuel type

- **WHEN** a price report is accepted
- **THEN** it names exactly one registered station
- **AND** it names exactly one registered fuel type
- **AND** it records the price observed and the time of observation

#### Scenario: No account is required

- **GIVEN** a submitter with no account and no prior submissions
- **WHEN** they submit a price report
- **THEN** the report is accepted on the same terms as any other

#### Scenario: The newest report is the displayed one

- **GIVEN** two accepted reports for the same station and fuel type at different times
- **WHEN** that station is retrieved for that fuel type
- **THEN** the more recent price is shown
- **AND** the earlier report is retained

### Requirement: A report is accepted only from a device at the station

The system SHALL accept a price report only when the submitting device is within a defined distance of a registered station at the time of submission.

Proximity SHALL authorize a report; it MUST NOT identify the station. The places provider records competing stations 27 to 40 metres apart, and 22 of 96 registered stations have a neighbour within 100 metres, so no radius both admits an ordinary positioning error and resolves which forecourt the submitter is on. The system SHALL therefore present the stations within range and require the submitter to choose one, even when only one is in range.

A submission with no proximity determination — location unavailable, unavailable in time, or declined — SHALL be rejected rather than accepted as unverified.

#### Scenario: A submitter near one station

- **GIVEN** a device within the defined distance of exactly one registered station
- **WHEN** a price report is submitted
- **THEN** that station is offered as the candidate
- **AND** the report is accepted once the submitter confirms it

#### Scenario: A submitter near several stations

- **GIVEN** a device within the defined distance of three registered stations
- **WHEN** a price report is submitted
- **THEN** all three are offered as candidates
- **AND** the report is attached to the station the submitter chooses
- **AND** the system does not select one on the submitter's behalf

#### Scenario: A submitter not near any station

- **GIVEN** a device not within the defined distance of any registered station
- **WHEN** a price report is submitted
- **THEN** the report is rejected
- **AND** the rejection states that the submitter is not at a registered station

#### Scenario: Location is unavailable or declined

- **GIVEN** a device whose location cannot be determined
- **WHEN** a price report is submitted
- **THEN** the report is rejected
- **AND** it is not recorded as an unverified observation

### Requirement: A submitter's location is not retained

The proximity check SHALL produce a verdict, and only that verdict and the chosen station SHALL be retained. The system MUST NOT store the submitting device's coordinates, nor any value from which they could be recovered.

#### Scenario: Coordinates do not survive the check

- **GIVEN** a report accepted after a successful proximity check
- **WHEN** the stored report is examined
- **THEN** it records the station and that proximity was established
- **AND** it holds no coordinates for the submitting device

### Requirement: A reported price must be plausible for its fuel type

The system SHALL reject a reported price outside the plausibility bounds registered for its fuel type, and the rejection SHALL say that the price was implausible rather than failing silently or storing the value.

Where a locality-wide DOE range exists for the fuel type, the system MAY narrow the accepted interval further. The registered bounds SHALL remain the primary test, because DOE covers 8 of 21 locality and fuel-type combinations and is absent for three fuel types entirely — a check that depended on it would not run for most reports.

#### Scenario: An implausible price is rejected

- **GIVEN** a fuel type whose registered bounds are ₱30.00 to ₱150.00
- **WHEN** a report of ₱785.00 is submitted for it
- **THEN** the report is rejected
- **AND** the rejection states that the price is outside the plausible range

#### Scenario: A plausible price is accepted where DOE is silent

- **GIVEN** a fuel type with no DOE range in the station's locality
- **WHEN** a plausible price is reported for it
- **THEN** the report is accepted
- **AND** the absence of a DOE range is not treated as grounds for rejection

### Requirement: A single report is sufficient in this version

The system SHALL display an accepted report as the station's price without requiring corroboration by a second report.

Confidence SHALL be conveyed by what accompanies the price — how many reports support it and how old the newest is — and MUST NOT be conveyed by withholding it. A corroboration threshold would suppress the app's only station-level data across 96 stations and 7 fuel types at launch volumes, and would suppress it most completely in the week after a price change, when reports are both most numerous and most valuable.

#### Scenario: One report becomes the displayed price

- **GIVEN** a station with no prior reports for a fuel type
- **WHEN** one plausible report is accepted for it
- **THEN** that price is displayed for the station
- **AND** it is accompanied by the count of supporting reports and the time of the newest

#### Scenario: A price is never withheld for lack of corroboration

- **GIVEN** a station with exactly one accepted report for a fuel type
- **WHEN** the station is retrieved for that fuel type
- **THEN** the reported price is shown rather than the reference range

### Requirement: The displayed price declares which kind of price it is

Every price the system supplies SHALL be accompanied by a statement of what it is, and a consumer MUST NOT be able to obtain the figure without it. The kinds are:

- **observed** — a price reported at that station
- **derived** — an earlier observation at that station carried across one or more announced price adjustments
- **reference** — the DOE locality-wide range, when the station has no usable observation

The statement SHALL be produced by the system rather than assembled by the consumer, so that a consumer cannot describe a figure in terms the system did not establish.

#### Scenario: Each kind is named

- **WHEN** a station's price is retrieved
- **THEN** the result states whether the figure is observed, derived, or reference
- **AND** the figure cannot be obtained without that statement

#### Scenario: A derived price says what it was derived from

- **GIVEN** a station whose displayed price was carried across an adjustment
- **WHEN** that station is retrieved
- **THEN** the result states the observed price it came from, when that was observed, and the adjustment applied to it
- **AND** it does not present the figure as observed at the station

#### Scenario: A consumer cannot restate the kind itself

- **WHEN** a price is supplied
- **THEN** the accompanying statement is supplied with it
- **AND** no consumer is required to compose that statement to display the price correctly

### Requirement: An observation is carried across a price adjustment, not discarded

When a price adjustment takes effect for a fuel type, the system SHALL treat each station's most recent observation for that fuel type as the baseline and apply the adjustment to it, yielding a derived price.

Discarding the observation instead would return every station to the locality-wide range at each adjustment, erasing the difference between one station and its neighbours — which is the only thing an observation contributes.

The same adjustment SHALL be applied to the locality-wide reference range, so that a station with no observation does not fall further behind at each adjustment while reported stations stay current.

#### Scenario: An observation survives an adjustment

- **GIVEN** a station with an observed price for a fuel type
- **WHEN** an adjustment for that fuel type takes effect
- **THEN** the station's displayed price is the observation shifted by the adjustment
- **AND** it is declared derived rather than observed

#### Scenario: A fresh observation replaces a derived price

- **GIVEN** a station showing a derived price
- **WHEN** a new report is accepted for that station and fuel type
- **THEN** the new observation becomes the displayed price
- **AND** it is declared observed

#### Scenario: The reference range moves with the adjustment

- **GIVEN** a locality-wide reference range for a fuel type
- **WHEN** an adjustment for that fuel type takes effect
- **THEN** the range shown for stations without observations is shifted by the same adjustment
- **AND** the shift is declared alongside the range

### Requirement: A derived price stops being shown once it is too far from any observation

Each adjustment applied to a baseline adds error: announcements are national while prices are local, and stations do not all pass an adjustment through in full or on the same day. The system SHALL therefore stop showing a derived price once the number of adjustments applied to it since the underlying observation exceeds a defined limit, and SHALL fall back to the reference range.

A derived price SHALL carry the date of the observation it descends from and the number of adjustments applied, so that its distance from an observation is visible rather than implied.

#### Scenario: A derived price within the limit is shown

- **GIVEN** a derived price whose observation is within the defined number of adjustments
- **WHEN** the station is retrieved
- **THEN** the derived price is shown
- **AND** the observation date and the number of adjustments applied accompany it

#### Scenario: A derived price past the limit reverts to reference

- **GIVEN** a derived price whose observation is further back than the defined limit
- **WHEN** the station is retrieved
- **THEN** the reference range is shown instead
- **AND** the figure is declared reference rather than derived

### Requirement: Where no price can be shown, the reason is stated and is the actual one

Where a station has neither a usable observation nor a reference range for a fuel type, the system SHALL return the station and state why no figure is available, using the established reasons for absent reference data rather than a second vocabulary.

The system MUST NOT state a more specific reason than it can support, and MUST NOT report an absence caused by one condition as though it were caused by another.

#### Scenario: A fuel type the source does not report

- **GIVEN** a fuel type for which the source publishes no figures in the station's locality
- **AND** the station has no observation for it
- **WHEN** the station is retrieved for that fuel type
- **THEN** the station is still returned
- **AND** the stated reason is that the source does not report that fuel type there

#### Scenario: Nothing ingested is not the source being silent

- **GIVEN** no reference data has been ingested
- **AND** a station has no observation for a fuel type
- **WHEN** the station is retrieved for that fuel type
- **THEN** the stated reason is that no reference data has been ingested
- **AND** it is not stated that the source published no figures
