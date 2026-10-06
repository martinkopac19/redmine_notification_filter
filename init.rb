# Redmine Notification Filter (Previo)
# Per-user, per-project filtrovanie e-mailových notifikácií o zmene stavu
# podľa konkrétneho prechodu (odkiaľ → kam). Komentáre a zmena názvu/popisu chodia vždy,
# v režimoch comments_only/transitions nič iné (verzia, assignee, polia, prílohy…);
# v režime mentions_only z úloh chodia len @zmienky.
# Políčko „Neposílat notifikace" pri komentári (oprávnenie suppress_mail_issue_switch).
# Bez zásahu do jadra — patch cez prepend, nastavenie v UserPreference.

require_relative 'lib/redmine_notification_filter/filter'
require_relative 'lib/redmine_notification_filter/journal_patch'
require_relative 'lib/redmine_notification_filter/issue_patch'
require_relative 'lib/redmine_notification_filter/suppress_hooks'

Redmine::Plugin.register :redmine_notification_filter do
  name 'Redmine Notification Filter'
  author 'Martin Kopáč'
  description 'Per-user and per-project filtering of task-change notifications: comments and subject/description changes always notify; status changes by exact transition (from → to); other field changes can be muted; or only @mentions.'
  version '0.3.0'
  url 'https://github.com/martinkopac19/redmine_notification_filter'
  requires_redmine version_or_higher: '5.0'

  menu :account_menu, :notification_filter,
       { controller: 'notification_filter', action: 'show' },
       caption: :label_notification_filter,
       if: proc { User.current.logged? }

  # Rovnaký názov ako v starom redmine_silencer → roly z migrovanej DB ho už majú.
  project_module :issue_tracking do
    permission :suppress_mail_issue_switch, {}
  end
end

# Patch aplikujeme priamo pri načítaní (rovnaký vzor ako redmine_checklists).
# Klon beží v produkčnom režime bez reloadu, takže je to spoľahlivé;
# `to_prepare` sa tu nespúšťal v správnom čase.
unless Journal.ancestors.include?(RedmineNotificationFilter::JournalPatch)
  Journal.prepend(RedmineNotificationFilter::JournalPatch)
end
unless Issue.ancestors.include?(RedmineNotificationFilter::IssuePatch)
  Issue.prepend(RedmineNotificationFilter::IssuePatch)
end
