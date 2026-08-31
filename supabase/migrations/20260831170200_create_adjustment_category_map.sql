-- What an announced fuel category covers.
--
-- Announcements speak in categories - "gasoline up P1.20, diesel up P0.85" -
-- while the system stores seven individual grades. Which grades a category
-- covers is a fact about how the industry announces prices, and it changes
-- independently of any code that reads it. Burying it in a parser is how it
-- becomes undiscoverable on the day it changes.
--
-- An announced category with no mapping is surfaced for review, never applied to
-- a guessed set of grades. The same rule that governs an unresolved brand name
-- in the station registry: the system says what it could not resolve rather than
-- picking something plausible.

create table public.adjustment_category_fuel_types (
  category       text not null,
  fuel_type_code text not null
    references public.fuel_types (code),
  note           text,
  primary key (category, fuel_type_code)
);

comment on table public.adjustment_category_fuel_types is
  'Maps a fuel category as announcements name it to the canonical grades it '
  'covers. One announced adjustment becomes one row per covered grade.';

-- Categories are matched against announcement text after normalization, so they
-- are stored lower-case and without punctuation.
create table public.adjustment_category_aliases (
  alias    text primary key,
  category text not null,
  note     text
);

comment on table public.adjustment_category_aliases is
  'Spellings an announcement may use for a category. Kept apart from the fuel '
  'type map so that adding a phrasing is not the same edit as changing what a '
  'category covers.';

alter table public.adjustment_category_fuel_types enable row level security;
alter table public.adjustment_category_aliases   enable row level security;
