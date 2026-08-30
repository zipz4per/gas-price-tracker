## MODIFIED Requirements

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
