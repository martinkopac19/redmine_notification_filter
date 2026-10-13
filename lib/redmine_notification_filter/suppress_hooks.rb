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

    # Hromadná úprava: rovnaké políčko v sekcii Poznámky — vľavo, „Súkromné poznámky" vpravo
    # (ako pri komentári na detaile). Jadro tam hook nemá, preto sa vykreslí do „Zmeniť vlastnosti"
    # a skript ho presunie. Pri kopírovaní nie — nové úlohy sa ohlasujú inou cestou ako journal.
    def view_issues_bulk_edit_details_bottom(context = {})
      issues = context[:issues].to_a
      return '' if issues.empty? || context[:controller]&.params&.[](:copy).present?
      return '' unless issues.all? { |issue| self.class.allowed?(issue) }

      box = content_tag(:span, class: 'nf-suppress') do
        check_box_tag(PARAM, '1', false, id: 'nf_suppress_mail') + ' ' +
          content_tag(:label, l(:label_nf_suppress_mail), for: 'nf_suppress_mail')
      end
      content_tag(:div, box, id: 'nf-bulk-suppress', style: 'display:none') + javascript_tag(<<~JS)
        $(function () {
          var holder = document.getElementById('nf-bulk-suppress');
          var notes = document.getElementById('notes');
          var fieldset = notes && notes.closest('fieldset');
          if (!holder || !fieldset) return;
          var row = document.createElement('div');
          row.style.cssText = 'display:flex;align-items:center;gap:6px;margin-top:8px';
          // téma dáva štítkom vo formulári pevnú šírku a okraje cez !important
          function css(el, rules) {
            Object.keys(rules).forEach(function (k) { el.style.setProperty(k, rules[k], 'important'); });
          }
          var box = holder.firstElementChild;
          css(box, { display: 'inline-flex', 'align-items': 'center', gap: '6px' });
          css(box.querySelector('label'), { margin: '0', width: 'auto', 'font-weight': 'normal', cursor: 'pointer' });
          row.appendChild(box);
          var priv = fieldset.querySelector('input[name="issue[private_notes]"]');
          var label = priv && priv.closest('label');
          if (label) {
            label.parentNode.insertBefore(row, label);
            css(label, { 'margin-left': 'auto', width: 'auto', display: 'inline-flex', 'align-items': 'center', gap: '6px' });
            row.appendChild(label);
          } else {
            fieldset.appendChild(row);
          }
          holder.remove();
        });
      JS
    end

    def controller_issues_bulk_edit_before_save(context = {})
      params  = context[:params]
      issue   = context[:issue]
      journal = issue.respond_to?(:current_journal) && issue.current_journal
      return unless params && params[PARAM].to_s == '1' && journal && params[:copy].blank?
      return unless self.class.allowed?(issue)

      journal.notify = false
    end
  end
end
