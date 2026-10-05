# Changelog

## 0.2.0 — 2026-10-05
- **Behaviour change:** the *Comments only* and *Selected transitions* modes now mute
  every change except comments and subject/description changes (plus, in
  *Selected transitions*, the whitelisted status transitions). Previously only bare
  status changes were filtered, so changes to the target version, assignee, custom
  fields (e.g. a merge request link) or attachments still notified everyone.
- *Send all changes* is unchanged.
- Updated wording of the modes in English and Czech.

## 0.1.2 — 2026-07-17
- Hide self-transitions (e.g. New → New) from the list; a status change to the
  same status never happens, so the checkbox was meaningless.
- Statuses and transitions are read live from the database, so newly added
  statuses/transitions appear automatically.

## 0.1.1 — 2026-07-17
- Clearer wording: the transition mode is now labelled "Comments + selected
  status transitions" to make explicit that comments always notify (behaviour
  unchanged — comments were never filtered).

## 0.1.0 — 2026-07-17
- Initial release.
- Per-user, per-project filtering of status-change notifications by exact
  transition (from → to).
- Modes: send all / comments only / selected transitions.
- Comments always notify. No core changes, no database migrations.
- Tested on Redmine 6.1.3.
