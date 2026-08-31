## Purpose

Holds the individual gas stations a driver can actually visit — what each one is called, which brand it carries, which locality it sits in, and where it is on a map — sourced from a places provider that knows what exists on the ground, and paired with the DOE reference prices that apply to its brand.

## Requirements

### Requirement: A station is an individually identifiable place

The system SHALL record each gas station as its own entity, distinct from its brand. A locality MAY contain several stations, and several of those MAY carry the same brand.

Stations sharing a brand within one locality SHALL remain individually identifiable, and the system SHALL return enough to tell them apart: each station's own provider identifier and its own coordinates always, and its address wherever the provider supplies one.

A distinguishing *name* MUST NOT be assumed. Providers commonly return the bare brand name for every station of that brand, so the system SHALL NOT treat the name as an identifier, and SHALL NOT merge or omit stations that share one.

#### Scenario: Two stations of one brand in one locality

- **GIVEN** a locality containing two stations that both carry the brand Petron
- **WHEN** the stations in that locality are listed
- **THEN** both stations appear as separate entries
- **AND** each carries its own provider identifier and its own coordinates
- **AND** neither is merged into the other or omitted because they share a name

#### Scenario: A brand is an attribute, not an identity

- **WHEN** a station is recorded
- **THEN** its brand is one of the registered brands
- **AND** the brand does not identify the station on its own

### Requirement: Stations are sourced from a places provider

Station existence, count, and location SHALL be determined by an external places provider. Each station SHALL record the provider's stable identifier for that place, so the same station can be recognised on a later refresh rather than duplicated, and so a station that has closed can be identified.

The system MUST NOT infer from the DOE report that a station exists, how many exist, or where one is. A brand's presence in the report is a statement about prices; its absence says nothing about whether stations carrying that brand exist in that locality.

Station data SHALL carry the attribution its source requires, and that attribution SHALL accompany the data rather than depend on a consumer supplying it. Provider-derived fields SHALL remain distinguishable from data the system originates, so a licence obligation on the former does not silently extend to the latter.

#### Scenario: Station data carries its source attribution

- **WHEN** the stations in a locality are retrieved
- **THEN** the attribution required by the station data's source accompanies the result

#### Scenario: Provider-derived fields are distinguishable

- **GIVEN** a station carrying both provider-derived fields and system-originated fields
- **WHEN** the station is examined
- **THEN** which fields came from the provider is determinable from the record

#### Scenario: A station carries its provider identifier

- **WHEN** a station is recorded from the places provider
- **THEN** the provider's identifier for that place is stored with it

#### Scenario: Re-importing the same place does not duplicate it

- **GIVEN** a station already recorded from the provider
- **WHEN** the same place is imported again
- **THEN** the existing station is matched by its provider identifier
- **AND** no second station is created for the same place

#### Scenario: DOE is not consulted for station existence

- **GIVEN** a locality whose DOE report does not mention a brand
- **WHEN** the places provider reports a station of that brand in that locality
- **THEN** the station is recorded
- **AND** its absence from the DOE report does not prevent or flag it

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

### Requirement: A station is findable on a map

Every station SHALL carry coordinates and a human-readable address, so it can be shown on a map and recognised on arrival. A station whose position is unknown SHALL NOT be recorded as though it were locatable.

Coordinates SHALL be rejected when they fall outside the Philippines, since a transposed or mistyped pair places a station in the sea and is indistinguishable from a valid one once stored.

#### Scenario: A station without coordinates is rejected

- **WHEN** a station is recorded with no coordinates
- **THEN** the record is rejected
- **AND** the failure names the missing position

#### Scenario: Coordinates outside the country are rejected

- **WHEN** a station is recorded with coordinates outside Philippine bounds
- **THEN** the record is rejected rather than stored as a locatable station

#### Scenario: A recorded station can be placed on a map

- **GIVEN** a station recorded with coordinates and an address
- **WHEN** the stations in its locality are retrieved
- **THEN** the coordinates and address accompany each station

### Requirement: A station belongs to a locality the app serves

Each station SHALL belong to exactly one registered locality. A station in a locality the app does not serve SHALL be rejected, so the registry cannot drift ahead of the coverage the locality registry defines.

#### Scenario: A station in an unregistered locality is rejected

- **WHEN** a station is recorded against a locality that is not registered
- **THEN** the record is rejected

#### Scenario: Stations are retrievable by locality

- **WHEN** the stations for a registered locality are requested
- **THEN** only stations belonging to that locality are returned

### Requirement: A station's reference price is its locality's range across all brands, attributed as such

Until a price is observed at a station itself, the system SHALL supply that station's DOE reference figure as the locality-wide range across all brands, together with the reporting period and any proxy attribution that applies.

That figure SHALL be presented as what it is — a range across all stations in the locality, of every brand — and MUST NOT be presented as a price observed at the station, nor as a figure specific to the station's brand.

The brand-level range MUST NOT be used for this purpose. It is narrower than the locality range and therefore reads as a statement about the station, while remaining a statement about a group: on a single locality's map, a brand range resolves to one figure repeated across every station of that brand, which presents a comparison between brands as though it were a comparison between stations. It is also unavailable for the stations that most need a figure — the source prices no range for 17 of 96 registered stations, and none at all for a station whose brand is unresolved, both of which the locality-wide range covers.

Where a station has no reference range, the system SHALL state the reason, and that reason SHALL be the actual one. It MUST NOT attribute the absence to the source publishing no figures unless that is what happened; an absence caused by nothing having been ingested, or by the ingested data not covering the locality or the fuel type, SHALL each be reported as itself.

The stated reason SHALL be produced by the system rather than assembled by the consumer, so that a consumer cannot state a reason the system did not establish.

#### Scenario: A station carries its locality's reference range

- **GIVEN** a station in a locality with DOE reference data for a fuel type
- **WHEN** that station is retrieved for that fuel type
- **THEN** the locality-wide range across all brands accompanies it
- **AND** the reporting period accompanies it

#### Scenario: The range is not attributed to the station

- **GIVEN** a locality whose reported range spans several pesos
- **WHEN** a station in that locality is retrieved
- **THEN** the result identifies the figure as a locality-wide range across all brands
- **AND** does not represent it as the price at that station

#### Scenario: The range is not attributed to the station's brand

- **GIVEN** two stations of different brands in one locality
- **WHEN** each is retrieved for the same fuel type with no observation at either
- **THEN** both carry the same locality-wide range
- **AND** neither figure is described as its brand's range

#### Scenario: A station whose brand the source does not price still carries a range

- **GIVEN** a station whose brand appears nowhere in the source's figures for its locality
- **WHEN** that station is retrieved for a fuel type the source reports there
- **THEN** the locality-wide range accompanies it
- **AND** the absence of a brand-level figure is not reported as an absence of reference data

#### Scenario: A station with no resolved brand still carries a range

- **GIVEN** a station whose provider name resolved to no registered brand
- **WHEN** that station is retrieved for a fuel type the source reports in its locality
- **THEN** the locality-wide range accompanies it
- **AND** an unresolved brand is not given as a reason for having no reference price

#### Scenario: A proxied locality carries its proxy attribution to stations

- **GIVEN** a station in a locality whose reference data comes from a proxy source
- **WHEN** the station is retrieved with its reference range
- **THEN** the proxy source is named alongside the figures

#### Scenario: A fuel type the source does not report in that locality

- **GIVEN** a locality for which the source publishes no figures for a fuel type
- **WHEN** a station there is retrieved for that fuel type
- **THEN** the station is still returned
- **AND** the absence of reference data is explicit rather than a zero or a blank
- **AND** the stated reason is that the source does not report that fuel type there

#### Scenario: A station is not told the source is silent when nothing was ingested

- **GIVEN** no reference data has been ingested
- **WHEN** stations are retrieved for a registered locality and fuel type
- **THEN** every station is still returned
- **AND** each states that no reference data has been ingested
- **AND** none states that the source published no figures for that locality
