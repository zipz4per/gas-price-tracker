## Purpose

Stores and serves the official DOE pump-price figures that give every covered locality an authoritative price baseline, including the provenance needed to say how old the data is and where it came from, and the degradation rules that keep good data on screen when a refresh goes wrong.

## Requirements

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

Source documents express missing data in several ways, including an unavailable marker, a literal `None`, a zero value, and a marker denoting that a brand has no fuel retail outlet in a locality. The system SHALL normalize these into explicit states and MUST NOT store any of them as a real price.

Brand coverage varies by locality: not every brand operates in every town. The no-retail-outlet marker is published **per brand within a locality**, and means that brand does not exist there. A brand marked as having no outlet MUST be distinguishable from a brand that operates in the locality but had no price reported.

A locality in which every brand is marked as having no retail outlet SHALL itself be recorded as having no retail outlet.

#### Scenario: Unavailable markers are not stored as prices

- **WHEN** a source cell contains an unavailable marker or the literal `None`
- **THEN** the corresponding value is recorded as absent
- **AND** it is never returned to a consumer as a price

#### Scenario: Zero is treated as absent, not as a price

- **WHEN** a source row publishes a range of `0.00 - 0.00`
- **THEN** the range is recorded as absent
- **AND** no zero-peso price is retrievable for that combination

#### Scenario: A brand with no outlet is a distinct state from a brand with no price

- **GIVEN** a locality's fuel type row marks some brands as having no liquid fuel retail outlet while other brands in the same row report prices
- **WHEN** reference data for that locality and fuel type is retrieved
- **THEN** the brands marked as having no outlet are reported as not operating in that locality
- **AND** this is distinguishable from a brand whose price was merely unavailable
- **AND** the prices reported by the other brands in that row are retained in full

#### Scenario: Brands absent from a locality do not suppress its other brands

- **GIVEN** the Tanauan City RON 91 row marks Unioil, Seaoil, and PTT as having no outlet while Petron, Shell, Caltex, Total, and Flying V report prices
- **WHEN** reference data for Tanauan City and RON 91 is retrieved
- **THEN** the five reporting brands' prices are all present
- **AND** the locality is not treated as having no retail outlet

#### Scenario: A locality where every brand has no outlet is itself a no-outlet locality

- **GIVEN** a source row marks every brand in a locality as having no liquid fuel retail outlet
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

### Requirement: Retrieval by locality and fuel type

The system SHALL allow reference prices to be retrieved for a given locality and fuel type, returning the per-brand ranges available, the overall range, the common price where published, the reporting period, and any proxy attribution that applies to that locality.

Retrieval MUST resolve the locality's sourcing mode transparently, so a consumer requesting Malvar receives Tanauan City's figures together with the proxy attribution without needing to know that Malvar is proxied.

#### Scenario: Retrieval returns brands, range, and period

- **WHEN** reference prices are retrieved for Lipa City and fuel type RON 95
- **THEN** the result contains each brand's reported range for RON 95
- **AND** the overall range and reporting period accompany it

#### Scenario: Proxy resolution is transparent to the caller

- **WHEN** reference prices are retrieved for Malvar and fuel type Diesel
- **THEN** the figures returned are those published for Tanauan City
- **AND** the result identifies Tanauan City as the proxy source

#### Scenario: Brands with no published data are omitted rather than zeroed

- **GIVEN** a fuel type row publishes no figures for one brand
- **WHEN** reference prices are retrieved for that locality and fuel type
- **THEN** that brand is absent from the result
- **AND** no placeholder or zero price is returned in its place

### Requirement: A fuel type is matched by normalization against the registered set

A requested fuel type SHALL be matched to a registered fuel type by the same normalization used for locality labels — case-insensitive, punctuation treated as separation, surrounding and repeated whitespace ignored — so that a caller naming a fuel type in a reasonable form reaches the figures for it.

Matching MUST NOT be fuzzy. A value that normalizes to no registered fuel type SHALL be unrecognised rather than resolved to the nearest one, for the same reason `Taguig Cty` and `Taguig City` must stay distinct.

#### Scenario: Spelling variants of a registered fuel type resolve

- **GIVEN** a locality with reference data for the fuel type registered as `RON_95`
- **WHEN** reference prices are retrieved for `RON 95`, for `ron_95`, and for `RON_95`
- **THEN** all three return the same figures

#### Scenario: A near miss is not resolved to a neighbour

- **WHEN** reference prices are retrieved for a value resembling a registered fuel type without normalizing to it
- **THEN** the request is reported as unrecognised
- **AND** no figures for any fuel type are returned

#### Scenario: The requested fuel type is echoed as the registered code

- **GIVEN** a caller requesting a registered fuel type in a variant spelling
- **WHEN** the figures are returned
- **THEN** the fuel type they carry is the registered code, not the spelling as requested

### Requirement: Absence of reference data is an explicit state

When no reference data exists for a requested locality and fuel type, the system SHALL return an explicit no-data result. It MUST NOT return an error, an empty value indistinguishable from a price, or a figure carried over from a different locality or fuel type.

The result SHALL also report **why** there is no data, distinguishing at least: that no reference data has ever been successfully ingested; that ingested data exists but does not cover this locality; and that this locality was reported but not this fuel type.

A brand that the report did not carry continues to be represented by the absence of its row rather than by a reason, because retrieval for a locality and fuel type is not asked about any particular brand. A consumer holding a brand — the station read path — establishes that case for itself.

These are different facts with different remedies, and only the last is a statement about what DOE published. The system MUST NOT report a more specific reason than it can support — in particular it MUST NOT describe an absence caused by its own missing ingestion as an absence in the source.

The reason SHALL accompany the no-data result rather than being derivable only by a separate query, so that a consumer cannot obtain the absence without the explanation.

#### Scenario: A locality with no ingested data reports no data

- **GIVEN** a registered locality for which no reference data has yet been recorded
- **WHEN** reference prices are retrieved for it
- **THEN** the result explicitly reports that no reference data is available
- **AND** the request does not fail

#### Scenario: Data is never borrowed across fuel types

- **GIVEN** a locality has reference data for Diesel but not for Kerosene
- **WHEN** reference prices are retrieved for Kerosene
- **THEN** the result reports no data for Kerosene
- **AND** does not return the Diesel figures

#### Scenario: Nothing ingested is distinct from nothing reported

- **GIVEN** no ingestion run has ever succeeded
- **WHEN** reference prices are retrieved for a registered locality and fuel type
- **THEN** the result reports that no reference data has been ingested
- **AND** the result does not state that the source published no figures

#### Scenario: A locality outside the ingested data is distinct from an unreported brand

- **GIVEN** ingested data that covers one registered locality and not another
- **WHEN** reference prices are retrieved for the locality it does not cover
- **THEN** the result reports that the ingested data does not cover that locality
- **AND** the result does not attribute the absence to any brand

#### Scenario: An unreported brand has no row rather than a misleading reason

- **GIVEN** a locality and fuel type that were reported, and a registered brand carrying no figure in that report
- **WHEN** reference prices are retrieved for that locality and fuel type
- **THEN** no row is returned for that brand
- **AND** the result does not report a reason describing the locality or the fuel type as absent

### Requirement: An unrecognised request is distinct from an absent answer

Retrieval SHALL determine whether it understands a request before answering it. A locality that is not registered, or a fuel type that is not one of the registered fuel types, SHALL be reported as unrecognised — a state distinct from the explicit no-data result, which means the request was understood and there are no figures for it.

The report SHALL name which argument was not recognised and the values that would have been, so a caller can correct the request without consulting the schema.

An unrecognised request MUST NOT be answered with reference data, with an explicit no-data result, or with an empty result indistinguishable from a query that matched nothing.

#### Scenario: An unknown fuel type is reported as unrecognised

- **GIVEN** a registered locality with reference data
- **WHEN** reference prices are retrieved for a fuel type that is not registered
- **THEN** the request is reported as unrecognised
- **AND** the report names the fuel type argument and the registered fuel types
- **AND** no no-data result is returned in its place

#### Scenario: An unregistered locality is reported as unrecognised

- **WHEN** reference prices are retrieved for a locality absent from the registry
- **THEN** the request is reported as unrecognised
- **AND** the report names the locality argument
- **AND** the result is distinguishable from a query that matched no rows

#### Scenario: Absence remains an answer, not a rejection

- **GIVEN** a registered locality and a registered fuel type for which no figures have been recorded
- **WHEN** reference prices are retrieved
- **THEN** the explicit no-data result is returned as before
- **AND** the request is not reported as unrecognised

### Requirement: Data freshness is exposed to consumers

Every retrieval of reference data SHALL make the age of that data determinable by the consumer, exposing both the period the data reports on and when it was recorded, so a consumer can present how current the figures are and detect that data has gone stale.

#### Scenario: Consumer can determine data age

- **WHEN** reference prices are retrieved for any locality
- **THEN** the reporting period and the recording timestamp accompany the result
- **AND** a consumer can determine from these alone how old the figures are

#### Scenario: Stale data is served rather than withheld

- **GIVEN** the most recent reference data for a locality is several reporting periods old
- **WHEN** reference prices are retrieved for that locality
- **THEN** the stale figures are returned with their reporting period
- **AND** the result is not replaced by a no-data or error state
