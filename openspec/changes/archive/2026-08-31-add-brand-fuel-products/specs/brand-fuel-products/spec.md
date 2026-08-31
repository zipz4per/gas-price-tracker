## Purpose

Holds what each brand calls the fuels it sells, and which fuels it sells at all, so that every surface asking a driver about a fuel asks in the words printed on the canopy in front of them, while the system continues to store and compare the underlying grade.

## ADDED Requirements

### Requirement: A brand's fuels are named as the brand names them

The system SHALL record, for each registered brand, the fuel types that brand sells and the product name it sells each under.

Wherever a fuel type is presented to a person in the context of a station of that brand — offering a fuel to report a price for, or labelling a price already shown — the system SHALL use the brand's product name rather than the canonical grade.

The canonical fuel type SHALL remain what is stored and compared. Product names are a presentation of a grade, never a substitute for it: prices are only comparable across brands in grade terms, and the reference data is published by grade.

#### Scenario: A branded station is asked in the brand's own words

- **GIVEN** a brand that sells a fuel type under its own product name
- **WHEN** a fuel is presented for a station of that brand
- **THEN** the brand's product name is shown
- **AND** the canonical fuel type is what the resulting record refers to

#### Scenario: Two brands' names for one grade

- **GIVEN** two brands that each sell the same canonical fuel type under different product names
- **WHEN** a price is recorded at a station of each
- **THEN** both records refer to the same canonical fuel type
- **AND** each was presented under its own brand's product name

### Requirement: The catalogue is authoritative about what a brand sells

A fuel type with no entry for a brand SHALL be treated as a fuel that brand does not sell. The system MUST NOT offer it for a station of that brand, and MUST NOT present it as an unpriced or missing product there.

Offering a grade a station does not sell invites a price to be recorded against a product that does not exist at that station, which is indistinguishable afterwards from a genuine observation.

#### Scenario: A grade the brand does not sell is not offered

- **GIVEN** a brand with no catalogue entry for a fuel type
- **WHEN** fuels are presented for a station of that brand
- **THEN** that fuel type does not appear
- **AND** it is not shown as absent, empty, or awaiting a price

#### Scenario: Only catalogued fuels are accepted for a branded station

- **GIVEN** a brand with no catalogue entry for a fuel type
- **WHEN** a price is submitted for that fuel type at a station of that brand
- **THEN** the submission is rejected
- **AND** the rejection states that the brand does not sell that fuel

### Requirement: Products are presented in the brand's own order

The system SHALL record a presentation order for each brand's products and SHALL present them in it, rather than ordering by canonical grade.

A brand's canopy is not ordered by octane, and a list that disagrees with the signage costs the reader a translation step at the moment they are trying to match a number to a product.

#### Scenario: Presentation follows the brand, not the grade

- **GIVEN** a brand whose recorded product order differs from descending grade order
- **WHEN** its products are presented
- **THEN** they appear in the brand's recorded order

### Requirement: A station with no identified brand is a first-class case

Where a station has no resolved brand, or its brand has no catalogue entries, the system SHALL present the canonical fuel types under their registered display names, and SHALL offer every registered fuel type.

This is a supported surface rather than a degradation. 36 of 96 registered stations are unbranded or pooled as independents, so the generic presentation serves more than a third of the registry and SHALL NOT be treated as an edge case, a placeholder, or an error state.

#### Scenario: An unbranded station offers canonical grades

- **GIVEN** a station with no resolved brand
- **WHEN** fuels are presented for it
- **THEN** every registered fuel type appears under its canonical display name
- **AND** nothing indicates an error or a missing brand

#### Scenario: A registered brand with no catalogue entries

- **GIVEN** a station whose brand is registered but has no catalogue entries
- **WHEN** fuels are presented for it
- **THEN** the canonical display names are used
- **AND** the station is treated as any other station without a product list

### Requirement: The catalogue is a maintained surface whose staleness is visible

Product lineups change when a brand rebrands, retires a product, or introduces one, and a mapping that goes stale shows a driver a product name their station no longer carries.

The system SHALL record when each brand's product list was last verified against the brand's own published lineup, and SHALL surface lists whose verification is older than a stated interval, so that a stale entry is found by review rather than by a user encountering it.

An entry SHALL reference a registered fuel type and a registered retailer brand; a product naming an unregistered grade or a non-retailer brand SHALL be rejected rather than stored.

#### Scenario: An unreviewed product list is surfaced

- **GIVEN** a brand whose product list was last verified longer ago than the stated interval
- **WHEN** the maintenance surface is consulted
- **THEN** that brand's list appears for review with the date it was last verified

#### Scenario: A product cannot name an unregistered grade

- **WHEN** a catalogue entry naming a fuel type that is not registered is recorded
- **THEN** it is rejected

#### Scenario: A product cannot name a non-retailer brand

- **WHEN** a catalogue entry is recorded against a brand that is not a retailer
- **THEN** it is rejected
