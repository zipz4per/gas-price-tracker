-- The feeds consulted at launch, and why each is in the group it is.
--
-- Reachability was checked on 2026-08-31 and is part of why these three were
-- chosen over the obvious alternatives:
--
--   GMA News            200, RSS
--   Philstar (business) 200, RSS
--   Inquirer (business) 200, RSS
--   Manila Bulletin     404 at /feed/ - the path returns an HTML error page
--   ABS-CBN News        403 Access Denied
--   Philippine News Agency  403, behind a challenge page
--
-- The last three are not oversights. PNA in particular would have been the
-- natural wire to read, and its being unreachable is the reason no seeded source
-- sits in a shared group today: every one of these three runs its own business
-- desk, so each is its own witness.
--
-- That is a judgement about how these outlets work now, and it is exactly the
-- kind of judgement that goes stale. If one of them starts republishing another's
-- copy, corroboration between them becomes a single witness counted twice, and
-- nothing in this table will notice. The citation-span guard in the ingestion and
-- the DOE cross-check are what catch it.

insert into public.adjustment_sources (code, display_name, feed_url, independence_group, note) values
  ('GMA',       'GMA News',
   'https://data.gmanetwork.com/gno/rss/news/feed.xml',
   'GMA',
   'Own newsroom. General news feed; oil price stories appear in it rather than in a business-only feed.'),

  ('PHILSTAR',  'The Philippine Star',
   'https://www.philstar.com/rss/business',
   'PHILSTAR',
   'Own business desk. Business section feed. Known to carry wire copy on some stories, so this grouping is a judgement to revisit.'),

  ('INQUIRER',  'Philippine Daily Inquirer',
   'https://business.inquirer.net/feed',
   'INQUIRER',
   'Own business desk. Business section feed.');

-- Recorded as inactive rather than omitted, so the next person to look for them
-- finds out they were considered and why they are not being read.
insert into public.adjustment_sources (code, display_name, feed_url, independence_group, active, note) values
  ('PNA',       'Philippine News Agency',
   'https://www.pna.gov.ph/rss/economy',
   'PNA',
   false,
   'Unreachable 2026-08-31: 403 behind a challenge page. The state wire many outlets republish, so if it becomes reachable its republishers must be moved into this group.'),

  ('ABSCBN',    'ABS-CBN News',
   'https://news.abs-cbn.com/rss/business',
   'ABSCBN',
   false,
   'Unreachable 2026-08-31: 403 Access Denied.'),

  ('MB',        'Manila Bulletin',
   'https://mb.com.ph/feed/',
   'MB',
   false,
   'Unreachable 2026-08-31: /feed/ returns 404 with an HTML error page. A working feed path may exist and was not found.');
