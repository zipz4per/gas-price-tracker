## MODIFIED Requirements

### Requirement: A provider's station name resolves to a registered brand

A places provider names stations in free text. The system SHALL resolve that name to one of the registered brands through maintained rules, and SHALL surface any name it cannot resolve rather than guessing.

A name SHALL be normalized before it is matched. Providers return one operator under several spellings — differing in letter case, and in whether a common corporate prefix or suffix is present — and rules applied to the raw name split one brand into several. Normalization SHALL fold case and SHALL fold the presence or absence of such affixes, so that spellings of one operator resolve to one brand.

A brand MAY be registered because it sells fuel, whether or not the reference source reports it. The registry of brands is a record of who operates stations, not a projection of who appears in the reference data; several multi-station operators are absent from that data and are not independents.

An unresolved name MUST NOT be silently assigned to a default brand or dropped. A station filed under the wrong brand is presented in the wrong brand's product vocabulary — offered fuels it does not sell, and refused fuels it does — and a dropped station is a station missing from the map with nothing to indicate it.

#### Scenario: A recognised name resolves to its brand

- **WHEN** a place named for a known brand is imported
- **THEN** the station is recorded against that registered brand

#### Scenario: An unresolvable name is surfaced

- **WHEN** a place name matches no brand rule
- **THEN** the name is surfaced for review with the place it came from
- **AND** the station is not recorded under a guessed brand

#### Scenario: Two spellings of one operator resolve to one brand

- **GIVEN** two stations whose provider names differ only by a common corporate prefix
- **WHEN** both are imported
- **THEN** both resolve to the same registered brand

#### Scenario: Letter case does not split a brand

- **GIVEN** two stations whose provider names differ only in letter case
- **WHEN** both are imported
- **THEN** both resolve to the same registered brand

#### Scenario: A brand absent from the reference data is still registrable

- **GIVEN** an operator that runs stations but is not reported in the reference data
- **WHEN** stations carrying its name are imported
- **THEN** they resolve to that operator's registered brand
- **AND** they are not recorded as independents
