## MODIFIED Requirements

### Requirement: A station's reference price is its brand's range, attributed as such

Until a price is observed at a station itself, the system SHALL supply that station's DOE reference range from its brand and locality, together with the reporting period and any proxy attribution that applies.

That figure SHALL be presented as what it is — a range across all stations of that brand in the locality — and MUST NOT be presented as a price observed at the station. A brand whose stations differ in price yields a range that is true of the group and of no individual member.

Where a station has no reference range, the system SHALL state the reason, and that reason SHALL be the actual one. It MUST NOT attribute the absence to the source publishing no figures unless that is what happened; an absence caused by nothing having been ingested, by the ingested data not covering the locality, or by the station's brand not yet being identified SHALL each be reported as itself.

The stated reason SHALL be produced by the system rather than assembled by the consumer, so that a consumer cannot state a reason the system did not establish.

#### Scenario: A station carries its brand's reference range

- **GIVEN** a station whose brand has DOE reference data for a fuel type in its locality
- **WHEN** that station is retrieved for that fuel type
- **THEN** the brand's range for that locality accompanies it
- **AND** the reporting period accompanies it

#### Scenario: The range is not attributed to the station

- **GIVEN** a brand whose reported range spans several pesos across a locality
- **WHEN** a station of that brand is retrieved
- **THEN** the result identifies the figure as a locality-wide brand range
- **AND** does not represent it as the price at that station

#### Scenario: A proxied locality carries its proxy attribution to stations

- **GIVEN** a station in a locality whose reference data comes from a proxy source
- **WHEN** the station is retrieved with its reference range
- **THEN** the proxy source is named alongside the figures

#### Scenario: A station with no reference data for its brand and fuel type

- **GIVEN** a station whose brand has no DOE figures for a requested fuel type
- **WHEN** that station is retrieved for that fuel type
- **THEN** the station is still returned
- **AND** the absence of reference data is explicit rather than a zero or a blank
- **AND** the stated reason is that the source published no figures for that brand

#### Scenario: A station is not told the source is silent when nothing was ingested

- **GIVEN** no reference data has been ingested
- **WHEN** stations are retrieved for a registered locality and fuel type
- **THEN** every station is still returned
- **AND** each states that no reference data has been ingested
- **AND** none states that the source published no figures for its brand

#### Scenario: A station whose brand is unidentified says so

- **GIVEN** a station whose provider name resolved to no registered brand
- **WHEN** that station is retrieved for any fuel type
- **THEN** the stated reason is that the station's brand is not yet identified
- **AND** the reason is not attributed to the source
