module RedmineNotificationFilter
  # Napojenie na notifikačnú cestu Redmine bez zásahu do jadra.
  # Mailer.deliver_issue_edit zostavuje príjemcov z journal.notified_users
  # a journal.notified_watchers — obidve pretriedime naším filtrom.
  # (Mentions nechávame — @zmienka je v komentári, tam filter nezasahuje.)
  module JournalPatch
    def notified_users
      super.reject { |u| RedmineNotificationFilter::Filter.skip?(u, self) }
    end

    def notified_watchers
      super.reject { |u| RedmineNotificationFilter::Filter.skip?(u, self) }
    end
  end
end
