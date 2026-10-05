module RedmineNotificationFilter
  # Rozhodovacia logika: má sa daný mail o úprave issue pre daného usera preskočiť?
  module Filter
    module_function

    # true  => notifikáciu pre tohto usera PRESKOČIŤ
    # false => poslať (pôvodné správanie)
    def skip?(user, journal)
      return false unless user.is_a?(User)
      # 1) komentár => notifikácia chodí vždy
      return false if journal.notes.present?

      cfg = config_for(user, journal.project)
      return false if cfg['mode'] == 'all'       # user chce všetky zmeny
      # 2) zmena názvu alebo popisu chodí v každom režime
      return false if content_change?(journal)
      # 3) 'comments_only' => nič iné (stav, verzia, polia, prílohy, assignee…) nechodí
      return true if cfg['mode'] == 'comments_only'

      # 4) 'transitions' => okrem toho už len vybrané prechody stavu
      detail = status_detail(journal)
      return true unless detail
      key = "#{detail.old_value}:#{detail.value}"
      !truthy((cfg['transitions'] || {})[key])
    end

    def status_detail(journal)
      journal.details.detect { |d| d.property == 'attr' && d.prop_key == 'status_id' }
    end

    def content_change?(journal)
      journal.details.any? { |d| d.property == 'attr' && %w[subject description].include?(d.prop_key) }
    end

    # Efektívna konfigurácia pre usera v danom projekte:
    # per-project override (ak mode != 'inherit'), inak globálne nastavenie usera.
    def config_for(user, project)
      root = user.pref[:notif_filter]
      root = {} unless root.is_a?(Hash)
      root = root.deep_stringify_keys
      global = {
        'mode'        => root['mode'] || 'all',
        'transitions' => root['transitions'] || {}
      }
      if project
        pcfg = (root['projects'] || {})[project.id.to_s]
        if pcfg.is_a?(Hash) && pcfg['mode'].present? && pcfg['mode'] != 'inherit'
          return { 'mode' => pcfg['mode'], 'transitions' => (pcfg['transitions'] || {}) }
        end
      end
      global
    end

    def truthy(v)
      v == true || v == '1' || v == 1
    end
  end
end
