# Changelog

## 0.3.0 — 2026-10-06
- New mode **Only mentions** (last in the list, global and per project): you are
  notified only when someone @mentions you, in a comment or in the description.
  Comments, subject/description changes, status changes, assignments and new issues
  are all muted. Mentions are added by Redmine core separately, so they always come through.
- New issues are filtered too in this mode (`Issue#notified_users` / `#notified_watchers`);
  the other modes leave new issues as before.
- A tooltip (ⓘ) on the mode explains that *My account → Email notifications → No events*
  stops mentions too (Redmine core skips such users), so it must be any other option.
  The option names are taken from Redmine core translations.
- **Don’t send notifications** checkbox under the comment on the issue edit form
  (replacement for the old redmine_silencer). Shown only with the permission
  *Suppress notifications for issue updates* (`suppress_mail_issue_switch`, same name as
  redmine_silencer, so migrated roles keep it). When ticked, the journal is saved with
  `notify = false`: no e-mail, no bell, not even for @mentions.
- Updated the intro text in all five languages (EN, CS, HU, PL, RO).
- Selftest: `extra/selftest.rb` (runs in a rolled-back transaction, sends no mail).

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
