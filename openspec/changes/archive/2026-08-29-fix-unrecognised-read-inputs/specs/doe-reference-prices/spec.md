## ADDED Requirements

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
