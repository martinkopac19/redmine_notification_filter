# Redmine Notification Filter

A Redmine plugin that lets **each user** decide which task-change notifications
they receive — down to the exact status transition (from → to) — globally and per
project. **Comments and changes to the subject or description always notify you**,
so you never miss the important stuff.

It solves the classic Redmine problem of *notification overload*: dozens of
"status changed from Code review to Ready to merge" e-mails you don't care about,
while you'd still like to know when something moves *New → In Progress* or
*→ Blocked*.

## Features

- **Per-user** — everyone configures their own filter; nothing is forced on anyone.
- **Per-transition precision** — pick exactly which `from status → to status`
  changes should e-mail you (transitions are read from your workflow, grouped by
  source status).
- **Per-project overrides** — a project can have its own rule that overrides your
  global one.
- **Four modes** (global and per project):
  - *Send all changes* (default — behaves like stock Redmine)
  - *Comments only* — comments and subject/description changes, nothing else
  - *Selected transitions* — the above plus the whitelisted status transitions,
    nothing else
  - *Only mentions* — only when someone @mentions you (in a comment or in the
    description); nothing else from issues, not even new issues or assignments
- **Comments and subject/description changes come through** in the first three
  modes. In the two middle modes, other field changes (target version,
  assignee, custom fields, attachments…) are muted.
- **Mute notification** — a checkbox under the comment (permission
  `suppress_mail_issue_switch`, same as the old redmine_silencer) saves the update without
  any notification, mentions included.
- **No core changes, no database migrations.** Settings are stored in the user's
  preferences; the plugin hooks the notification path via `prepend`.

## How it works

Redmine builds the recipient list for an issue update in
`Mailer.deliver_issue_edit` from `Journal#notified_users` and
`Journal#notified_watchers`. This plugin `prepend`s a small module to those two
methods and removes a recipient when, for that user's effective config (project
override, else global):

- the mode is *comments only* or *selected transitions*, and
- the journal has **no comment** and does **not** change the subject or description, and
- in *selected transitions* mode, it is not a whitelisted status transition.

In *only mentions* mode the user is removed from every update, and `Issue#notified_users` /
`Issue#notified_watchers` are filtered too, so new issues (`Mailer.deliver_issue_add`) stay
silent as well.

Mentions are left untouched: core adds them separately (`notified_mentions`), so an
@mention always notifies, in every mode. In-app notification plugins that hook the mailer see
the same recipient list, so the filter applies to them as well.

## Compatibility

- Tested on **Redmine 6.1.3** (Ruby 3.4, Rails 7.2, PostgreSQL).
- Declares `requires_redmine version_or_higher: '5.0'`; the mechanism (Journal
  notification methods + `UserPreference`) exists on 5.x too, but only 6.1 is
  verified. Test on a staging copy before production.

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/martinkopac19/redmine_notification_filter.git
# restart Redmine (whatever you use):
#   systemctl restart redmine   |   passenger-config restart-app .   |   touch tmp/restart.txt
```

No `rake redmine:plugins:migrate` is needed — the plugin has no migrations.

## Usage

Log in and open **Notification filter** from the account menu (top-right,
next to *My account* / *Sign out*), or go to `/notification_filter`.

1. Choose a **global** mode. In *Only selected transitions*, tick the
   `from → to` changes you want.
2. Optionally **add a project override** at the bottom and set a different rule
   for that project.
3. **Save.**

Comments will always e-mail you. Only bare status changes are filtered.

## Uninstall

```bash
rm -rf /path/to/redmine/plugins/redmine_notification_filter
# restart Redmine
```

Stored user preferences are harmless leftovers and can be ignored.

## License

Copyright (C) 2026 Martin Kopáč

GPL-2.0-or-later, matching Redmine. See [LICENSE](LICENSE).

## Credits

Built for [Previo](https://previo.cz) and released for the Redmine community.
