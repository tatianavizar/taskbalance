require "test_helper"
require "minitest/mock"

# The notifications the weekly engine's results turn into, end to end.
class NotificationsDispatcherTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include WeeklyEngineHelpers

  JOINED = -> { ActiveSupport::TimeZone["Europe/Paris"].local(2026, 10, 4, 9) }

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob", joined_at: JOINED.call)
  end

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)
  def mid(week) = week.start_at + 2.days + 10.hours
  def final_at(week) = HouseholdWeek.final_at(week)
  def monday_8am(week) = paris(week.next.monday.year, week.next.monday.month, week.next.monday.day, 8)
  def provisional_at(week) = HouseholdWeek.provisional_at(week)

  # Runs the engine at `now` and delivers its outbox, as WeeklyEngineJob does.
  def tick(now)
    result = run_engine(@household, now)
    Notifications::Dispatcher.deliver_pending(@household, now: now)
    result
  end

  def deliver_all
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs
    ActionMailer::Base.deliveries
  end

  def mail_to(user, subject_part)
    ActionMailer::Base.deliveries.find { |m| m.to == [ user.email ] && m.subject.include?(subject_part) }
  end

  def text_of(mail) = mail.text_part.body.to_s
  def figures(mail) = text_of(mail).gsub(%r{https?://\S+}, "").scan(/\d+/)

  # ---- H3 -------------------------------------------------------------------

  test "the weekly report is built from the final report and goes out Monday 08:00 to every member" do
    log!(@household, @alice, at: mid(week(0)), count: 3)
    log!(@household, @bob, at: mid(week(0)))

    assert_no_enqueued_emails { tick(provisional_at(week(0))) }
    assert_no_enqueued_emails { tick(final_at(week(0)) - 1.minute) }
    assert_enqueued_emails(2) { tick(final_at(week(0))) }
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob, at: paris(2026, 10, 12, 8))
    assert_equal [ false ], Notification.where(kind: "weekly_report").map { _1.facts["provisional"] }.uniq

    deliver_all
    assert_equal [ @alice.email, @bob.email ].sort, ActionMailer::Base.deliveries.flat_map(&:to).sort
  end

  test "D8: both members get the same facts and the same figures, only the phrasing changes" do
    log!(@household, @alice, at: mid(week(0)), count: 3, minutes: 20)
    log!(@household, @bob, at: mid(week(0)), minutes: 20)
    tick(final_at(week(0)))
    deliver_all

    to_alice = mail_to(@alice, "Semaine")
    to_bob = mail_to(@bob, "Semaine")

    assert_equal "Semaine 41 : Alice 75 %, Bob 25 % de la charge mentale", to_alice.subject
    assert_equal to_alice.subject, to_bob.subject
    assert_equal figures(to_alice), figures(to_bob), "same numbers in both emails"
    assert_includes text_of(to_alice), "Vous portez 75 % de la charge mentale."
    assert_includes text_of(to_bob), "Alice porte 75 % de la charge mentale."
    assert_includes text_of(to_alice), "Au-dessus de 60 %"
    reports = Notification.where(kind: "weekly_report").where("facts->>'week_start' = ?", week(0).monday.iso8601)
    assert_equal 1, reports.pluck(:facts).uniq.size, "one set of facts for every recipient"
  end

  test "a balanced week names no one" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    tick(final_at(week(0)))
    deliver_all

    mail = mail_to(@bob, "Semaine")
    assert_includes text_of(mail), "Semaine équilibrée."
    assert_includes text_of(mail), "entre 40 et 60 %"
    assert_no_match(/porte|portez/, text_of(mail))
  end

  # ---- E3, the question, E4, E5 -----------------------------------------------

  test "a week where one member logged nothing: the same alert for both, at 08:00 Monday" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    log!(@household, @alice, at: mid(week(1)), count: 21)

    tick(final_at(week(0)))
    assert_no_enqueued_emails { tick(final_at(week(0)) + 1.hour) }

    assert_enqueued_emails(4) { tick(final_at(week(1))) } # the weekly report and E3, to both
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob, at: paris(2026, 10, 19, 8))
    assert_equal 2, Notification.where(kind: "alert_no_logs").count
    deliver_all

    to_bob = mail_to(@bob, "close")
    to_alice = mail_to(@alice, "close")
    assert_equal "Semaine 42 close : vous n'avez enregistré aucune tâche", to_bob.subject
    assert_equal "Semaine 42 close : Bob n'a enregistré aucune tâche", to_alice.subject
    assert_includes text_of(to_bob), "Une absence ? Déclarez une pause."
    assert_no_match(/pause/, text_of(to_alice), "the alert asks nothing of the person who carried the week")
    assert_equal figures(to_bob).sort, figures(to_alice).sort
    assert_includes text_of(to_alice), "vous 21, Bob 0"
    assert_includes text_of(to_bob), "Alice 21, vous 0"
  end

  test "a household of one gets no weekly report" do
    solo_household, _carol = build_household("Carol", joined_at: JOINED.call)
    run_engine(solo_household, final_at(week(0)))
    Notifications::Dispatcher.deliver_pending(solo_household, now: final_at(week(0)))

    assert_equal 0, Notification.where(household: solo_household).count
    assert_equal 0, solo_household.engine_events.undelivered.count, "the event is consumed, not left pending"
  end

  test "a solo household that did log still gets no report" do
    solo_household, users = build_household("Carol", joined_at: JOINED.call)
    log!(solo_household, users.first, at: mid(week(0)))
    run_engine(solo_household, final_at(week(0)))
    Notifications::Dispatcher.deliver_pending(solo_household, now: final_at(week(0)))

    assert_equal 0, Notification.where(household: solo_household).count
  end

  test "a week nobody logged in: a short re-engagement message instead of the report, to each member" do
    assert_enqueued_emails(2) { tick(final_at(week(0))) }
    assert_equal [ "reengagement" ], Notification.where(deliver_at: monday_8am(week(0))).distinct.pluck(:kind)
    assert_no_enqueued_emails { tick(final_at(week(0)) + 1.minute) }
    assert_equal 0, Notification.where(kind: "alert_no_logs").count, "no E3 when nobody logged"

    deliver_all
    mail = mail_to(@alice, "Aucune tâche")
    assert_equal "Aucune tâche enregistrée la semaine 41 dans Foyer test.", mail.subject
    assert_equal mail.subject.sub(/\.\z/, ""), mail_to(@bob, "Aucune tâche").subject.sub(/\.\z/, "")
    text = text_of(mail)
    assert_includes text, "50/50 garde la trace des tâches du foyer"
    assert_includes text, "Ouvrir 50/50 : http://example.com/dashboard"
    assert_no_match(/Alice|Bob|vous n'avez|streak|série|urgent|vite|dernier|déjà/i, text.split("--").first)
    assert_no_match(/\w·\w/, text)
  end

  test "the re-engagement message takes the report slot and follows the weekly_report setting" do
    NotificationPreference.set(@bob, "weekly_report", false)
    tick(final_at(week(0)))

    now_for = ->(user) { Notification.find_by!(user: user, deliver_at: monday_8am(week(0))) }
    assert_equal "reengagement", now_for.(@alice).kind
    assert_equal "report", now_for.(@alice).cap_class
    assert_equal "weekly_report", now_for.(@alice).event_type
    assert_equal "preference", now_for.(@bob).suppressed_reason

    # A report for the same week and person is held back by the cap.
    report = Notifications::Events::WeeklyReport.new(@household.household_weeks.final.find_by!(week_start: week(0).monday))
    assert_equal "cap", Notifications::Notifier.call(report, to: [ @alice ], now: final_at(week(0))).sole.suppressed_reason
  end

  test "a week where only one member logged is a normal report, not the re-engagement message" do
    log!(@household, @alice, at: mid(week(0)))
    tick(final_at(week(0)))

    kinds = Notification.where(deliver_at: monday_8am(week(0))).distinct.pluck(:kind)
    assert_includes kinds, "weekly_report"
    assert_not_includes kinds, "reengagement"
  end

  test "a neutral week that has logs is still a report" do
    log!(@household, @alice, at: mid(week(0)), mental: true, execution: false)
    log!(@household, @bob, at: mid(week(0)), mental: true, execution: false)
    tick(final_at(week(0)))

    assert_equal [ "weekly_report" ], Notification.where(deliver_at: monday_8am(week(0))).distinct.pluck(:kind)
  end

  test "two empty weeks: the question to everyone, no alert E3 for that week, E4 at the deadline, E5 on the way back" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    [ 1, 2 ].each { |n| log!(@household, @alice, at: mid(week(n)), count: 2) }

    tick(final_at(week(0)))
    tick(final_at(week(1))) # streak 1: E3
    result = tick(final_at(week(2))) # streak 2: the question
    assert_equal 1, result.inquiries_opened.size

    questions = Notification.where(kind: "absence_question")
    assert_equal [ @alice.id, @bob.id ].sort, questions.pluck(:user_id).sort
    assert_equal 1, Notification.where(kind: "alert_no_logs").where(user: @alice).count, "E3 only for week 1, the question speaks for week 2"
    assert_equal({ "user_id" => @bob.id, "first_name" => "Bob" }, questions.first.facts["subject"])

    deliver_all
    assert_includes text_of(mail_to(@alice, "depuis 2 semaines")), "Absence de Bob ? Répondez avant mercredi 20:00."
    assert_includes text_of(mail_to(@bob, "depuis 2 semaines")), "Une absence ? Répondez avant mercredi 20:00."
    assert_includes text_of(mail_to(@alice, "depuis 2 semaines")), "Un seul « Oui » suffit."

    tick(AbsenceInquiry.last.deadline_at)
    blocked = Notification.where(kind: "alert_blocked")
    assert_equal 2, blocked.count
    deliver_all
    assert_equal "Le foyer redescend au niveau 0 : Bob n'a rien enregistré depuis 2 semaines", mail_to(@alice, "redescend").subject
    assert_equal "Le foyer redescend au niveau 0 : vous n'avez rien enregistré depuis 2 semaines", mail_to(@bob, "redescend").subject

    [ @alice, @bob ].each { |user| log!(@household, user, at: mid(week(3))) }
    tick(final_at(week(3)))
    unblocked = Notification.where(kind: "alert_unblocked")
    assert_equal 2, unblocked.count
    deliver_all
    mail = mail_to(@bob, "débloquée")
    assert_includes text_of(mail), "Chaque membre a enregistré des tâches en semaine 44."
    assert_includes text_of(mail), "La semaine est aussi équilibrée"
    assert_no_match(/Alice|Bob/, text_of(mail).split("--").first, "a success names no one")
  end

  test "a regression with no level to lose still blocks, and says so" do
    [ 0, 1 ].each { |n| log!(@household, @alice, at: mid(week(n)), count: 2) }
    tick(final_at(week(0)))
    tick(final_at(week(1)))
    tick(AbsenceInquiry.last.deadline_at)
    deliver_all

    assert_includes mail_to(@alice, "bloquée").subject, "La progression du foyer est bloquée : Bob n'a rien enregistré"
  end

  test "running the engine job twice at the same moment sends nothing twice" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    now = final_at(week(0))

    assert_enqueued_emails(2) do
      travel_to(now) do
        WeeklyEngineJob.perform_now(now: now)
        assert_no_difference("Notification.count") { WeeklyEngineJob.perform_now(now: now) }
      end
    end
    # The arrival week's report came due a week ago: in the feed, not sent.
    assert_equal 4, Notification.where(household: @household).count
    assert_equal 2, Notification.where(household: @household, suppressed_reason: "stale").count
  end

  test "a failure while notifying is reported and does not undo the engine" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    now = final_at(week(0))
    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error }
    Rails.error.subscribe(subscriber)

    Notifications::Dispatcher.stub(:deliver_pending, ->(*) { raise "mail down" }) do
      travel_to(now) { WeeklyEngineJob.perform_now(now: now) }
    end

    assert_equal 1, @household.reload.balanced_weeks_count
    assert(reported.any? { _1.message == "mail down" })
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber
  end

  # ---- pauses ---------------------------------------------------------------

  test "a pause answering the question: everyone hears the dates and the outcome" do
    [ 0, 1 ].each { |n| log!(@household, @alice, at: mid(week(n)), count: 2) }
    tick(final_at(week(0)))
    tick(final_at(week(1)))
    inquiry = AbsenceInquiry.last

    pause = travel_to(final_at(week(1)) + 1.day) { inquiry.answer_yes!(by: @alice) }
    assert_enqueued_with(job: NotificationsDispatchJob, args: [ @household.id ])
    Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(1)) + 1.day)
    assert_equal %w[absence_outcome pause_declared], Notification.where(household: @household).order(:kind).where(kind: %w[absence_outcome pause_declared]).distinct.pluck(:kind)

    deliver_all
    subjects = ActionMailer::Base.deliveries.map(&:subject)
    assert(subjects.any? { _1.start_with?("Une pause est déclarée pour vous.") })
    assert(subjects.any? { _1.start_with?("Une pause est déclarée pour Bob.") })
    assert(subjects.any? { _1.start_with?("Pause déclarée pour Bob.") })

    assert_no_difference "Notification.count" do
      Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(1)) + 2.days)
      @household.engine_events.update_all(delivered_at: nil) # even a full replay
      Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(1)) + 2.days)
    end
    assert pause
  end
end
