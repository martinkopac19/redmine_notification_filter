module RedmineNotificationFilter
  # Režim 'mentions_only' musí stíšiť aj založenie úlohy (Mailer.deliver_issue_add berie
  # príjemcov z issue.notified_users | issue.notified_watchers | issue.notified_mentions).
  # Journal#notified_users volá issue.notified_users tiež, takže to platí aj pre úpravy.
  # Ostatné režimy sa tu nemenia: skip_issue_add? je true len pre 'mentions_only'.
  module IssuePatch
    def notified_users
      super.reject { |u| RedmineNotificationFilter::Filter.skip_issue_add?(u, self) }
    end

    def notified_watchers
      super.reject { |u| RedmineNotificationFilter::Filter.skip_issue_add?(u, self) }
    end
  end
end
