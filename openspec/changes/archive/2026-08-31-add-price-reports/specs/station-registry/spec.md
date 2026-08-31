## ADDED Requirements

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

## REMOVED Requirements

### Requirement: A station's reference price is its brand's range, attributed as such

**Reason**: The brand-level range is false precision at station level. Within one locality it resolves to a single figure repeated across every station of that brand — on the Lipa City map, RON 95 becomes three distinct numbers spread over 52 stations — so a map that appears to compare stations is comparing brands. It is also missing exactly where a figure is most needed: the source prices no range for 17 of 96 registered stations, and none for a station whose brand is unresolved.

**Migration**: Replaced by "A station's reference price is its locality's range across all brands, attributed as such", which draws the same figure from the locality-wide row. Consumers reading a brand range receive the locality range in the same field, with the accompanying statement updated to describe it. The two absence reasons that named the brand — the source not pricing a brand, and a station's brand not being identified — no longer arise for the reference figure, since the locality range does not depend on a station's brand; they remain in use where a brand is genuinely the subject.
