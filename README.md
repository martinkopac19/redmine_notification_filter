# Redmine Notification Filter

A Redmine plugin that lets **each user** decide which **status-change** e-mail
notifications they receive — down to the exact transition (from → to) — globally
and per project. **Comments always notify you**, so you never miss the important stuff.

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
- **Three modes** (global and per project):
  - *Send all status changes* (default — behaves like stock Redmine)
  - *Comments only* — never e-mail me about bare status changes
  - *Only selected transitions* — the whitelist described above
- **Comments always come through**, regardless of the filter.
- **No core changes, no database migrations.** Settings are stored in the user's
  preferences; the plugin hooks the notification path via `prepend`.

## How it works

Redmine builds the recipient list for an issue update in
`Mailer.deliver_issue_edit` from `Journal#notified_users` and
`Journal#notified_watchers`. This plugin `prepend`s a small module to those two
methods and removes a recipient when, for that user:

- the journal has **no comment**, and
- it **is** a status change, and
- that user's effective config (project override, else global) says to skip it
  (mode *comments only*, or mode *selected transitions* and this transition isn't
  whitelisted).

Everything else (comments, mentions, other field changes) is left untouched.

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
