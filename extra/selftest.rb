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
def edit!(issue_id, author, notes: nil, attrs: {})
  issue = Issue.find(issue_id)
  issue.init_journal(author, notes)
  issue.safe_attributes = attrs.stringify_keys
  ActionMailer::Base.deliveries.clear
  raise "save zlyhal: #{issue.errors.full_messages.join(', ')}" unless issue.save
  issue
end

puts "=" * 72
puts "Selftest: notification filter — rezim Only mentions"
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
