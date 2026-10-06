# Selftest rezimu "Only mentions" (redmine_notification_filter 0.3.0).
# Bezi proti zivej DB, ale VSETKO je vo vonkajsej transakcii, ktora sa na konci zahodi.
# Maily NIKAM neodchadzaju: delivery_method sa prepne na :test.
#
# Spustenie:
#   docker compose exec -T --user redmine redmine sh -c \
#     'SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" bin/rails runner -e production plugins/redmine_notification_filter/extra/selftest.rb'

$ok = 0
$bad = 0

def check(name, actual, expected)
  if actual == expected
    $ok += 1
    puts "  #{name.ljust(58)}: OK"
  else
    $bad += 1
    puts "  #{name.ljust(58)}: CHYBA (ocakavane #{expected.inspect}, prislo #{actual.inspect})"
  end
end

def mailed?(user)
  ActionMailer::Base.deliveries.any? { |m| Array(m.to).include?(user.mail) || Array(m.bcc).include?(user.mail) }
end

def set_mode(user, mode, projects = {})
  pref = user.pref
  pref[:notif_filter] = { 'mode' => mode, 'transitions' => {}, 'projects' => projects }
  pref.save!
end

# zmena ulohy tak, ako ju robi IssuesController (init_journal + save)
# `params` → ako controller zavolá aj hook controller_issues_edit_before_save (políčko „Neposílat notifikace")
def edit!(issue_id, author, notes: nil, attrs: {}, params: nil)
  issue = Issue.find(issue_id)
  issue.init_journal(author, notes)
  issue.safe_attributes = attrs.stringify_keys
  ActionMailer::Base.deliveries.clear
  if params
    User.current = author
    Redmine::Hook.call_hook(:controller_issues_edit_before_save,
                            params: ActionController::Parameters.new(params), issue: issue,
                            time_entry: nil, journal: issue.current_journal)
  end
  raise "save zlyhal: #{issue.errors.full_messages.join(', ')}" unless issue.save
  issue
end

puts "=" * 72
puts "Selftest: notification filter — rezim Only mentions, Neposilat notifikace"
puts "=" * 72

check("Issue ma IssuePatch", Issue.ancestors.include?(RedmineNotificationFilter::IssuePatch), true)

orig_method  = ActionMailer::Base.delivery_method
orig_perform = ActionMailer::Base.perform_deliveries
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true

conn = ActiveRecord::Base.connection
conn.begin_transaction(joinable: false)
begin
  Mailer.with_synched_deliveries do
    author = User.active.where(admin: true).first
    User.current = author

    # uloha, ktoru dvaja dalsi aktivni clenovia projektu vidia a da sa ulozit
    issue = nil; u = nil; v = nil
    Issue.joins(:project).merge(Project.active).order(id: :desc).limit(300).each do |i|
      people = i.project.users.active.where.not(id: author.id).to_a.select { |x| x.mail.present? && i.visible?(x) }.first(2)
      next unless people.size == 2
      c = Issue.find(i.id); c.init_journal(author); c.notes = 'x'
      next unless c.valid?
      issue = i; u, v = people
      break
    end
    raise 'nenasiel som pouzitelnu ulohu' unless issue

    [u, v].each do |x|
      x.update_columns(mail_notification: 'all')
      x.pref.update!(no_self_notified: true)
    end
    puts "  uloha ##{issue.id} (projekt #{issue.project.identifier}), testovaci ludia: id #{u.id}, #{v.id}"

    set_mode(u, 'mentions_only')
    set_mode(v, 'comments_only')

    puts "\n[1] komentar bez zmienky"
    edit!(issue.id, author, notes: 'bezny komentar')
    check("Only mentions: nepride", mailed?(u), false)
    check("Jen komentare (iny clovek): pride ako doteraz", mailed?(v), true)

    puts "\n[2] komentar so @zmienkou"
    edit!(issue.id, author, notes: "pozri sa @#{u.login} prosim")
    check("Only mentions: pride", mailed?(u), true)

    puts "\n[3] zmena popisu bez zmienky"
    edit!(issue.id, author, attrs: { description: "#{Issue.find(issue.id).description} upravene" })
    check("Only mentions: nepride", mailed?(u), false)
    check("Jen komentare: pride (popis chodi vzdy)", mailed?(v), true)

    puts "\n[4] zmena popisu, ktora pridava @zmienku"
    edit!(issue.id, author, attrs: { description: "#{Issue.find(issue.id).description}\n\n@#{u.login} pozri" })
    check("Only mentions: pride", mailed?(u), true)

    puts "\n[5] priradenie bez komentara"
    edit!(issue.id, author, attrs: { assigned_to_id: u.id }) if issue.assignable_users.include?(u)
    check("Only mentions: nepride", mailed?(u), false)

    puts "\n[6] nova uloha priradena Only-mentions cloveku"
    ActionMailer::Base.deliveries.clear
    n = Issue.new(project: issue.project, tracker: issue.tracker, author: author, subject: 'selftest nf',
                  assigned_to: (issue.assignable_users.include?(u) ? u : nil))
    n.watcher_user_ids = [u.id]
    n.save!(validate: false)
    check("Only mentions: nepride", mailed?(u), false)

    puts "\n[7] nova uloha so @zmienkou v popise"
    ActionMailer::Base.deliveries.clear
    n2 = Issue.new(project: issue.project, tracker: issue.tracker, author: author, subject: 'selftest nf 2',
                   description: "ahoj @#{u.login}")
    n2.save!(validate: false)
    check("Only mentions: pride", mailed?(u), true)

    puts "\n[8] vynimka pre projekt ma prednost"
    set_mode(u, 'mentions_only', { issue.project_id.to_s => { 'mode' => 'all', 'transitions' => {} } })
    edit!(issue.id, author, notes: 'komentar pri vynimke')
    check("globalne Only mentions, projekt Vsetko: pride", mailed?(u), true)
    set_mode(u, 'all', { issue.project_id.to_s => { 'mode' => 'mentions_only', 'transitions' => {} } })
    edit!(issue.id, author, notes: 'dalsi komentar')
    check("globalne Vsetko, projekt Only mentions: nepride", mailed?(u), false)

    puts "
[9] Neposilat notifikace (autor ma opravnenie)"
    set_mode(u, 'all'); set_mode(v, 'all')
    check("opravnenie je zaregistrovane", Redmine::AccessControl.permission(:suppress_mail_issue_switch).present?, true)
    check("autor ho ma", RedmineNotificationFilter::SuppressHooks.allowed?(issue, author), true)
    nj = Journal.where(journalized: issue).count
    edit!(issue.id, author, notes: "ticho @#{u.login}", params: { 'suppress_mail' => '1' })
    check("komentar sa ulozil", Journal.where(journalized: issue).count, nj + 1)
    check("ziadny mail nikomu (ani zmienenemu)", ActionMailer::Base.deliveries.size, 0)

    puts "
[10] to iste bez policka"
    edit!(issue.id, author, notes: "nahlas @#{u.login}", params: {})
    check("maily odisli", mailed?(u) && mailed?(v), true)

    puts "
[11] clovek bez opravnenia: policko sa ignoruje"
    nope = issue.project.users.active.to_a.detect { |x| x.mail.present? && !x.admin? && issue.visible?(x) && issue.notes_addable?(x) && !RedmineNotificationFilter::SuppressHooks.allowed?(issue, x) && x.id != u.id }
    if nope
      edit!(issue.id, nope, notes: "pokus o ticho @#{u.login}", params: { 'suppress_mail' => '1' })
      check("mail odisiel napriek policku", mailed?(u), true)
    else
      puts "  (v projekte nie je clen bez opravnenia — preskocene)"
    end

    puts "\n[12] nova uloha: clovek zapisany v poli typu pouzivatel (Tester, PM…)"
    cf = defined?(NotifyFieldUsers::Common) &&
         IssueCustomField.where(id: NotifyFieldUsers::Common.user_field_ids).detect { |c| c.is_for_all? || c.projects.include?(issue.project) }
    if cf && NotifyFieldUsers::Common.enabled?
      mk = lambda do |subj|
        ActionMailer::Base.deliveries.clear
        i = Issue.new(project: issue.project, tracker: issue.tracker, author: author, subject: subj)
        i.custom_field_values = { cf.id.to_s => u.id.to_s }
        i.save!(validate: false)
      end
      set_mode(u, 'all')
      mk.('selftest nf pole 1')
      check("rezim Vsetko: pride (kontrola, ze pole funguje)", mailed?(u), true)
      set_mode(u, 'mentions_only')
      mk.('selftest nf pole 2')
      check("Only mentions: nepride", mailed?(u), false)
    else
      puts "  (notify_field_users vypnuty alebo bez pola — preskocene)"
    end
  end
ensure
  conn.rollback_transaction
  ActionMailer::Base.delivery_method = orig_method
  ActionMailer::Base.perform_deliveries = orig_perform
  ActionMailer::Base.deliveries.clear
end

puts "\n" + "=" * 72
puts "OK: #{$ok}   CHYBA: #{$bad}"
puts "(vsetky zmeny zahodene, v DB nezostalo nic, ziadny mail neodisiel)"
exit($bad.zero? ? 0 : 1)
