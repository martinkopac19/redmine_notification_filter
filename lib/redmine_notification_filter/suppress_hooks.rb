module RedmineNotificationFilter
  # „Neposílat notifikace" pri komentári / úprave úlohy — náhrada pluginu redmine_silencer
  # zo starého Redmine. Oprávnenie má ZÁMERNE rovnaký názov (`suppress_mail_issue_switch`),
  # takže roly prenesené zo starej DB ho majú nastavené bez zásahu.
  #
  # Ako: jadro má na journale príznak `notify` (Journal#send_notification ho kontroluje).
  # Nastavíme ho pred uložením; nejde ani mail, ani zvonček (in-app notifikácie visia na maileri),
  # ani @zmienky — tie idú tou istou cestou.
  class SuppressHooks < Redmine::Hook::ViewListener
    PARAM = 'suppress_mail'.freeze

    def self.allowed?(issue, user = User.current)
      issue.is_a?(Issue) && user.allowed_to?(:suppress_mail_issue_switch, issue.project)
    end

    # Políčko pod komentárom vo formulári úpravy (rich editor ho presunie k „Pridať komentár"
    # a pridá jeho dvojča k tlačidlu Potvrdiť — obe majú meno `suppress_mail`, stačí jedno zaškrtnuté).
    def view_issues_edit_notes_bottom(context = {})
      issue = context[:issue]
      return '' unless self.class.allowed?(issue)

      content_tag(:span, class: 'nf-suppress') do
        check_box_tag(PARAM, '1', false, id: 'nf_suppress_mail') + ' ' +
          content_tag(:label, l(:label_nf_suppress_mail), for: 'nf_suppress_mail')
      end
    end

    def controller_issues_edit_before_save(context = {})
      params  = context[:params]
      journal = context[:journal]
      return unless params && params[PARAM].to_s == '1' && journal.is_a?(Journal)
      return unless self.class.allowed?(context[:issue])

      journal.notify = false
    end
  end
end
