## Purpose

Defines the set of localities the app covers and how each one resolves to official DOE pump-price data, including which localities must borrow a neighbour's figures and the labelling obligations that creates. Coverage is data, so extending the app to a new town or region never requires a code change.

## ADDED Requirements

### Requirement: Locality registry defines covered localities

The system SHALL maintain a registry of the localities it covers. Each entry MUST record the locality's display name, its province or region label, the DOE region whose report supplies its reference data, and its DOE sourcing mode (`direct` or `proxy`).

A locality that is not present in the registry MUST NOT appear anywhere in the application as covered.

#### Scenario: Registry contains the three launch localities

- **WHEN** the locality registry is read after initial population
- **THEN** it contains exactly three localities: Malvar (Batangas), Lipa City (Batangas), and Taguig City (NCR)
- **AND** each carries a DOE region and a sourcing mode

#### Scenario: Unregistered locality is not covered

- **WHEN** a consumer requests coverage information for a locality absent from the registry, such as Santo Tomas
- **THEN** the system reports that the locality is not covered
- **AND** returns no reference data for it

### Requirement: Direct DOE sourcing

A locality whose own name appears in its DOE region's report SHALL be registered with sourcing mode `direct`, and its reference data MUST be drawn from the rows published under that locality's own name.

Reference data for a `direct` locality MUST NOT be presented as an approximation.

#### Scenario: Lipa City is sourced directly

- **WHEN** reference data is resolved for Lipa City
- **THEN** the data originates from the Lipa City rows of the Region IV-A CALABARZON report
- **AND** the data carries no proxy attribution

#### Scenario: Taguig City is sourced directly from a different region

- **WHEN** reference data is resolved for Taguig City
- **THEN** the data originates from the Taguig rows of the NCR Price Monitoring report
- **AND** the data carries no proxy attribution

### Requirement: Proxy DOE sourcing with mandatory attribution

A locality absent from its DOE region's report SHALL be registered with sourcing mode `proxy` and MUST record the name of the substitute locality supplying its figures.

Reference data resolved through a proxy MUST carry the substitute locality's name, and every consumer that presents proxied data MUST attribute it to that substitute locality so a user is never led to believe the figures are official data for their own locality.

#### Scenario: Malvar resolves through Tanauan City

- **WHEN** reference data is resolved for Malvar
- **THEN** the data originates from the Tanauan City rows of the Region IV-A CALABARZON report
- **AND** the result identifies Tanauan City as the proxy source

#### Scenario: Proxy attribution is preserved through retrieval

- **WHEN** any consumer retrieves reference prices for Malvar
- **THEN** the proxy source name accompanies the prices in the result
- **AND** the result is distinguishable from directly sourced data without inspecting the registry

#### Scenario: Direct localities carry no proxy attribution

- **WHEN** reference data is retrieved for Lipa City or Taguig City
- **THEN** no proxy source name is present in the result

### Requirement: Locality name matching is normalized and tolerant

Each registry entry SHALL record the locality label exactly as it is expected to appear in the DOE source document, which may differ from the display name. Matching a registry entry against source rows MUST be normalization-based — insensitive to case, surrounding whitespace, and punctuation — rather than exact string equality.

The registry MUST be able to represent a source label that is misspelled in the DOE document without altering the locality's display name.

#### Scenario: Source document misspelling is matched

- **GIVEN** the NCR report labels the locality `Taguig Cty`
- **WHEN** reference rows are matched for the registry entry whose display name is `Taguig City`
- **THEN** the `Taguig Cty` rows are matched successfully
- **AND** the locality is still presented to users as `Taguig City`

#### Scenario: Case and whitespace differences do not prevent matching

- **GIVEN** a source document renders a locality as `  LIPA CITY `
- **WHEN** reference rows are matched for the `Lipa City` registry entry
- **THEN** the rows are matched successfully

### Requirement: DOE region source configuration

The system SHALL maintain configuration for each covered DOE region recording the report's location and how the current report's address is determined. Each region MUST declare a resolution strategy: either the report address is derivable from the reporting date, or it must be discovered because the address contains an opaque identifier.

This configuration MUST be readable by a later ingestion process without that process hard-coding any region's addressing scheme.

#### Scenario: NCR report address is derivable from a date

- **WHEN** the region configuration for NCR is read
- **THEN** it declares a date-derived resolution strategy
- **AND** records the address pattern containing the reporting date

#### Scenario: CALABARZON report address must be discovered

- **WHEN** the region configuration for Region IV-A CALABARZON is read
- **THEN** it declares a discovery-based resolution strategy
- **AND** records that the address contains an opaque incrementing identifier that cannot be predicted from a date

### Requirement: Coverage is extended by configuration alone

Adding a locality to the app's coverage, changing a locality's sourcing mode, or repointing a proxy at a different substitute locality SHALL be achievable by changing registry data only, with no change to application code.

#### Scenario: A new locality is added without code change

- **WHEN** an operator adds Batangas City to the registry as a `direct` locality in Region IV-A CALABARZON
- **THEN** the locality becomes covered
- **AND** no application code change is required for its reference data to resolve

#### Scenario: A proxy is promoted to direct sourcing

- **GIVEN** Malvar is registered as a proxy of Tanauan City
- **WHEN** DOE begins publishing Malvar under its own name and an operator changes Malvar's sourcing mode to `direct`
- **THEN** subsequent reference data for Malvar is drawn from its own rows
- **AND** proxy attribution no longer accompanies the data
- **AND** no application code change is required
