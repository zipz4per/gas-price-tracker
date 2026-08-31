## Purpose

Governs what a person actually sees when this system shows them a price — that every figure arrives with the statement of what kind of claim it is, that a station with nothing to report is shown rather than dropped, and that the list stays navigable when the device will not say where it is.

## ADDED Requirements

### Requirement: A displayed price always states what kind of price it is

Wherever a price is shown to a person, the system SHALL display the kind of figure it is and the statement of what it means, alongside the figure itself.

The statement SHALL be the one the read path supplies. A surface MUST NOT compose its own wording, abbreviate the statement to a label, or show the figure with the statement available only behind an interaction that a person may never perform.

An observed price, a price derived by carrying an earlier observation across announced adjustments, and a locality-wide reference range are three different claims about the world. Presented as a bare number they are indistinguishable, and the one a reader will assume is the one the system is least often able to offer.

#### Scenario: A figure is never shown alone

- **WHEN** a price is displayed for a station
- **THEN** the kind of price is displayed with it
- **AND** the statement supplied with the figure is displayed with it

#### Scenario: The statement is not rewritten by the surface

- **GIVEN** a read path that supplies a statement describing a figure
- **WHEN** that figure is displayed
- **THEN** the displayed wording is the supplied statement
- **AND** the surface does not substitute wording of its own

#### Scenario: A reference range is not presented as this station's price

- **GIVEN** a station whose figure is a locality-wide reference range
- **WHEN** it is displayed
- **THEN** it is identified as a range across the locality
- **AND** it is not presented as a price observed at that station

### Requirement: A station with no price is shown, with the reason

A station for which no figure is available SHALL appear in the list, and the system SHALL display the reason there is none.

Omitting it would remove a real place from a list a person is using to decide where to drive, and would do so precisely when the system has least to say about it. Absence is a state a station is shown in, never a reason to drop it.

The reason displayed SHALL be the one the read path supplies, for the same reason the statement is: a surface that composes its own explanation will eventually explain an absence the system did not establish.

#### Scenario: A station with no figure still appears

- **GIVEN** a locality in which some stations have no figure for the selected fuel type
- **WHEN** the list is displayed
- **THEN** those stations appear in it
- **AND** each shows why no price is available

#### Scenario: A fuel type nothing reports still lists every station

- **GIVEN** a fuel type for which no station in a locality has a figure
- **WHEN** the list is displayed for that fuel type
- **THEN** every station in the locality appears
- **AND** the list is not shown as empty or as an error

#### Scenario: Absence is not rendered as zero

- **WHEN** a station has no figure
- **THEN** no numeric value is displayed for it
- **AND** the absence is not shown as a price of zero or as a blank where a price would be

### Requirement: How recent a price is travels with it

Where a figure comes from an observation, the system SHALL display how recently it was observed and how many reports support it.

A price is a perishable claim. Two stations showing the same figure, one reported an hour ago and one carried forward across three announced adjustments, are offering a reader very different information, and a display that shows only the number hides the whole difference.

#### Scenario: An observed price shows its age

- **WHEN** a price observed at a station is displayed
- **THEN** how recently it was observed is displayed with it
- **AND** the number of reports supporting it is displayed with it

#### Scenario: A derived price shows its distance from an observation

- **WHEN** a derived price is displayed
- **THEN** the display conveys that it was carried forward rather than observed
- **AND** the date of the observation it descends from is available with it

### Requirement: The list is ordered by distance where location is known

Where the device's location is available, the system SHALL order stations by their distance from it and SHALL display each station's distance.

Location is the only attribute that reliably distinguishes stations from one another. A locality can hold a dozen stations of one brand sharing a single name, and addresses are supplied by the provider for only some of them, so a list ordered by anything else asks a reader to tell apart entries that look identical.

#### Scenario: Stations of one brand are distinguishable by distance

- **GIVEN** a locality containing several stations of the same brand with the same name
- **AND** the device's location is available
- **WHEN** the list is displayed
- **THEN** each station shows its distance from the device
- **AND** the stations are ordered by that distance

### Requirement: The screen remains usable when location is refused or unavailable

Where the device's location is unavailable — declined, unsupported, or not obtained in time — the system SHALL still display the list, ordered by a stated criterion, and SHALL make clear that distances are not available and why.

Location is refused often and permanently. A screen that treats a refusal as an error state makes the app unusable for those users forever, when everything on it except ordering works without knowing where they are.

The system MUST NOT block the list on a location request, and MUST NOT present an empty screen while one is pending.

#### Scenario: Location is declined

- **GIVEN** a device whose location permission is declined
- **WHEN** the list is displayed
- **THEN** every station in the selected locality is listed
- **AND** the ordering criterion in use is stated
- **AND** the absence of distances is explained rather than left blank

#### Scenario: The list does not wait on a pending location request

- **GIVEN** a location request that has not yet resolved
- **WHEN** the screen is displayed
- **THEN** the list is shown
- **AND** it is reordered if and when a location arrives

### Requirement: A locality and a fuel type are always resolved before a list is shown

The system SHALL display the list for exactly one locality and one fuel type at a time, SHALL make both visible on the screen, and SHALL offer only localities the system covers and fuel types it recognises.

A list whose subject is ambiguous is worse than no list: a reader comparing prices needs to know they are comparing the same product in the same town.

#### Scenario: The subject of the list is visible

- **WHEN** the list is displayed
- **THEN** the locality it covers is displayed
- **AND** the fuel type it covers is displayed

#### Scenario: Only covered localities are offered

- **WHEN** localities are offered for selection
- **THEN** only localities the system covers appear
- **AND** selecting one displays that locality's stations
