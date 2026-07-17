# Redmine Notification Filter (Previo)
# Per-user, per-project filtrovanie e-mailových notifikácií o zmene stavu
# podľa konkrétneho prechodu (odkiaľ → kam). Komentáre chodia vždy.
# Bez zásahu do jadra — patch cez prepend, nastavenie v UserPreference.

require_relative 'lib/redmine_notification_filter/filter'
require_relative 'lib/redmine_notification_filter/journal_patch'

Redmine::Plugin.register :redmine_notification_filter do
  name 'Redmine Notification Filter'
  author 'Martin Kopáč'
  description 'Per-user and per-project filtering of status-change e-mail notifications by exact transition (from → to). Comments always notify.'
  version '0.1.2'
  url 'https://github.com/martinkopac19/redmine_notification_filter'
  requires_redmine version_or_higher: '5.0'

  menu :account_menu, :notification_filter,
       { controller: 'notification_filter', action: 'show' },
       caption: :label_notification_filter,
       if: proc { User.current.logged? }
end

# Patch aplikujeme priamo pri načítaní (rovnaký vzor ako redmine_checklists).
# Klon beží v produkčnom režime bez reloadu, takže je to spoľahlivé;
# `to_prepare` sa tu nespúšťal v správnom čase.
unless Journal.ancestors.include?(RedmineNotificationFilter::JournalPatch)
  Journal.prepend(RedmineNotificationFilter::JournalPatch)
end
