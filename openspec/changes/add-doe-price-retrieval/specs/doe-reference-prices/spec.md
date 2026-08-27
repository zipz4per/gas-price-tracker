## Purpose

Stores and serves the official DOE pump-price figures that give every covered locality an authoritative price baseline, including the provenance needed to say how old the data is and where it came from, and the degradation rules that keep good data on screen when a refresh goes wrong.

## ADDED Requirements

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

### Requirement: Absence of reference data is an explicit state

When no reference data exists for a requested locality and fuel type, the system SHALL return an explicit no-data result. It MUST NOT return an error, an empty value indistinguishable from a price, or a figure carried over from a different locality or fuel type.

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
