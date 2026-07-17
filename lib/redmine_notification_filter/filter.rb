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
      # 2) je to vôbec zmena stavu? ak nie (napr. len zmena assignee), nechávame ako dnes
      detail = status_detail(journal)
      return false unless detail

      cfg = config_for(user, journal.project)
      case cfg['mode']
      when 'all'           then false            # user chce všetky zmeny stavu
      when 'comments_only' then true             # user chce len komentáre => preskočiť
      else                                        # 'transitions' = whitelist prechodov
        key = "#{detail.old_value}:#{detail.value}"
        !truthy((cfg['transitions'] || {})[key])
      end
    end

    def status_detail(journal)
      journal.details.detect { |d| d.property == 'attr' && d.prop_key == 'status_id' }
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
