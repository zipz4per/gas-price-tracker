# Adjustment source review

The outlets read for price announcements, and — the part that actually matters —
which of them count as independent witnesses.

```sql
select code, display_name, independence_group, active, note
  from adjustment_sources order by independence_group, code;
```

## Why the group is the whole thing

An adjustment is recorded only when two sources agree, and agreement is counted
in **independence groups**, not in sources. Two rows in the same group are one
witness.

That exists because Philippine outlets frequently run identical wire copy. Two
feeds can carry one story under two mastheads, and to anything counting URLs that
looks exactly like two outlets agreeing. It is not. It is one story counted twice,
and the check that was supposed to catch a misread amount instead confirms it.

**If two sources that share copy are placed in different groups, corroboration
between them is worthless.** One wire story becomes two witnesses, an adjustment
is recorded on a single reading, and if that reading was wrong every derived
price of that grade moves with it — invisibly, because everything downstream
moves together. That is the failure this column exists to prevent, and the column
is the only thing preventing it at this level.

There is a second line: candidates whose citation spans read alike are folded
into one witness regardless of group. It catches the same wire copy when the
grouping is wrong, and it is a heuristic, not a proof. The DOE cross-check is the
third line — see `docs/price-adjustment-procedure.md` §7.

## Adding an outlet

```sql
insert into adjustment_sources (code, display_name, feed_url, independence_group, note)
values ('EXAMPLE', 'Example News', 'https://example.com/rss/business',
        'EXAMPLE', 'Own business desk, checked 2026-09-07.');
```

The group defaults to the source's own code when you set it that way, and a new
outlet is independent until someone says otherwise. That default fails toward a
**missed** corroboration rather than a false one, which is the right direction.

Before choosing a group, ask what the outlet actually publishes on this subject:

- Does it have its own business desk, or does it run the wire?
- Does its oil-price coverage carry a byline, or an agency credit?
- Read two of its price stories beside another outlet's. If the sentences match,
  they are one witness.

If it republishes another outlet or an agency, put it in **that originator's**
group. The Philippine News Agency is the obvious case: it is the state wire many
outlets carry, so anything republishing PNA belongs in the `PNA` group.

## Settled 2026-08-31

Reachability checked the same day.

| Source | Group | Active | Why |
|---|---|---|---|
| GMA News | `GMA` | yes | Own newsroom. General news feed; oil stories appear there rather than in a business-only feed. |
| The Philippine Star | `PHILSTAR` | yes | Own business desk. **Known to carry wire copy on some stories — this grouping is a judgement to revisit.** |
| Philippine Daily Inquirer | `INQUIRER` | yes | Own business desk. |
| Philippine News Agency | `PNA` | no | 403 behind a challenge page. The state wire many outlets republish. |
| ABS-CBN News | `ABSCBN` | no | 403 Access Denied. |
| Manila Bulletin | `MB` | no | `/feed/` returns 404 with an HTML error page. A working path may exist and was not found. |

The three unreachable outlets are recorded rather than omitted so that the next
person to consider them finds out they were tried.

**A consequence worth knowing.** Because PNA is unreachable, no seeded source
shares a group — all three actives are treated as fully independent. That is a
judgement about how these outlets work now, not a measurement, and Philstar in
particular does carry wire copy on some stories. If PNA becomes reachable, its
republishers must be moved into its group at the same time.

## When to revisit

- An outlet's oil-price coverage starts carrying an agency credit.
- Two sources begin agreeing suspiciously often and word-for-word — check
  `adjustment_run_conflicts` and the citation spans on
  `price_adjustment_sources`.
- A feed URL starts failing. Mark it inactive with the reason rather than
  deleting the row.
- The DOE cross-check flags a divergence that the feed cannot explain. A wrongly
  grouped pair is one of the ways that happens.
