require "test_helper"
require "minitest/mock"

# The seams between the weekly engine and the notifications (lot 8a): the
# engine_events outbox, its replay, the single run_all loop.
class EngineOutboxTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include WeeklyEngineHelpers

  JOINED = -> { ActiveSupport::TimeZone["Europe/Paris"].local(2026, 10, 4, 9) }

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob", joined_at: JOINED.call)
  end

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)
  def mid(week) = week.start_at + 2.days + 10.hours
  def final_at(week) = HouseholdWeek.final_at(week)
  def events(name) = @household.engine_events.where(name: name).chronological

  # Bob logs nothing in weeks 1 and 2; question on 26 Oct, deadline 28 Oct 20:00.
  def bob_absent!
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    [ 1, 2 ].each { |n| log!(@household, @alice, at: mid(week(n)), count: 2) }
  end

  # ---- run_all ----------------------------------------------------------------

  test "run_all yields each household with its result and returns them" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    yielded = []

    runs = travel_to(final_at(week(0))) do
      WeeklyEngine.run_all(now: final_at(week(0))) { |household, result| yielded << [ household.id, result ] }
    end

    mine = yielded.find { |id, _| id == @household.id }.last
    assert_equal [ week(-1).monday, week(0).monday ], mine.final_weeks.map(&:week_start)
    assert_equal yielded.map(&:first), runs.map { _1.first.id }
  end

  test "run_all skips a failing household without calling the block for it" do
    @household.update_column(:time_zone, "Nowhere/City")
    seen = []
    travel_to(final_at(week(0))) { WeeklyEngine.run_all(now: final_at(week(0))) { |h, _| seen << h.id } }
    assert_not_includes seen, @household.id
  end

  # ---- events the engine records ------------------------------------------------

  test "E3 is explicit: one member.first_empty_week event when a streak reaches 1, none at 2" do
    bob_absent!
    result = run_engine(@household, final_at(week(1)))
    assert_equal [ membership(@household, @bob).id ], result.first_empty_weeks.map { _1[:household_member_id] }
    assert_equal week(1).monday, result.first_empty_weeks.first[:household_week].week_start

    run_engine(@household, final_at(week(2)))
    event = events("member.first_empty_week").sole
    assert_equal({ "user_id" => @bob.id, "first_name" => "Bob", "week_start" => "2026-10-12" },
                 event.payload.slice("user_id", "first_name", "week_start"))
    assert_equal 1, events("absence_inquiry.opened").count
  end

  test "the unblocking carries its week, in the result and in the outbox" do
    bob_absent!
    run_engine(@household, paris(2026, 10, 28, 21))
    [ @alice, @bob ].each { |u| log!(@household, u, at: mid(week(3))) }

    result = run_engine(@household, final_at(week(3)))
    assert_equal week(3).monday, result.unblocked.week_start
    assert_equal result.unblocked, events("household.unblocked").sole.subject
  end

  test "each final week's event holds the progression right after it, even in one catch-up run" do
    (0..2).each { |n| log_balanced_week!(@household, [ @alice, @bob ], week(n)) }
    run_engine(@household, final_at(week(2)))

    levels = events("household_week.final").map { _1.payload.values_at("week_start", "level", "balanced_weeks_count") }
    assert_equal [ [ "2026-09-28", 0, 0 ], [ "2026-10-05", 1, 1 ], [ "2026-10-12", 1, 2 ], [ "2026-10-19", 2, 3 ] ], levels
  end

  test "every level change lands in the outbox, the membership reset included" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    run_engine(@household, final_at(week(0)))
    join(@household, "Chloé", at: Time.current)

    assert_equal %w[reached membership_changed], events("level.changed").map { _1.payload["reason"] }
  end

  # ---- replay ---------------------------------------------------------------------

  test "a dispatch that crashes half-way is replayed by the next one, without duplicates" do
    bob_absent!
    run_engine(@household, final_at(week(1)))
    run_engine(@household, final_at(week(2)))
    pending = @household.engine_events.undelivered.count

    real = Notifications::Notifier.method(:call)
    crash = lambda do |event, **kw|
      raise "smtp down" if event.is_a?(Notifications::Events::AbsenceQuestion)

      real.call(event, **kw)
    end
    delivered = Notifications::Notifier.stub(:call, crash) do
      Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(2)))
    end

    assert_equal pending - 1, delivered.size, "everything but the question went through"
    assert_equal [ "absence_inquiry.opened" ], @household.engine_events.undelivered.map(&:name)
    assert_empty Notification.where(kind: "absence_question")
    before = Notification.count

    replayed = Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(2)) + 15.minutes)
    assert_equal [ "absence_inquiry.opened" ], replayed.map(&:name)
    assert_equal 2, Notification.where(kind: "absence_question").count
    assert_equal before + 2, Notification.count, "nothing sent twice"
    assert_empty @household.engine_events.undelivered
  end

  test "a full replay of already delivered events sends nothing" do
    log_balanced_week!(@household, [ @alice, @bob ], week(0))
    run_engine(@household, final_at(week(0)))
    Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(0)))

    @household.engine_events.update_all(delivered_at: nil)
    assert_no_difference("Notification.count") do
      Notifications::Dispatcher.deliver_pending(@household, now: final_at(week(0)))
    end
  end

  # ---- every pause path notifies through the outbox --------------------------------

  def assert_pause_notified(pause)
    assert_equal pause, events("member_pause.declared").last.subject
    assert_enqueued_with(job: NotificationsDispatchJob, args: [ @household.id ])
    perform_enqueued_jobs(only: NotificationsDispatchJob)
    assert_equal 2, Notification.where(kind: "pause_declared", dedup_key: "pause_declared:pause-#{pause.id}").count
  end

  test "own pause" do
    pause = travel_to(paris(2026, 10, 20, 9)) do
      MemberPause.declare!(member: membership(@household, @bob), declared_by: @bob, starts_on: Date.new(2026, 10, 21))
    end
    assert_pause_notified(pause)
  end

  test "an E11 'Oui': the pause and the outcome" do
    bob_absent!
    run_engine(@household, final_at(week(2)))
    inquiry = @household.absence_inquiries.sole
    travel_to(paris(2026, 10, 27, 12)) { inquiry.answer!(by: @alice, value: "yes", at: paris(2026, 10, 27, 12)) }

    assert_pause_notified(inquiry.reload.absence_answers.sole.member_pause)
    assert_equal 2, Notification.where(kind: "absence_outcome").count
  end

  test "a pause after a regression: the pause and the cancelled regression" do
    bob_absent!
    run_engine(@household, paris(2026, 10, 28, 21))
    pause = travel_to(paris(2026, 10, 29, 9)) do
      MemberPause.declare!(member: membership(@household, @bob), declared_by: @alice,
                           starts_on: week(1).monday, ends_on: week(2).sunday)
    end

    assert_pause_notified(pause)
    assert_equal [ "absence_outcome:cancelled:inquiry-#{@household.absence_inquiries.sole.id}" ],
                 Notification.where(kind: "absence_outcome").distinct.pluck(:dedup_key)
  end

  test "a pause withdrawn before dispatch is skipped and still marked delivered" do
    bob_absent!
    run_engine(@household, final_at(week(2)))
    inquiry = @household.absence_inquiries.sole
    travel_to(paris(2026, 10, 27, 12)) do
      inquiry.answer!(by: @alice, value: "yes", at: Time.current)
      inquiry.answer!(by: @alice, value: "no", at: Time.current + 1.minute)
    end

    Notifications::Dispatcher.deliver_pending(@household, now: paris(2026, 10, 27, 13))
    assert_empty @household.engine_events.undelivered
    assert_empty Notification.where(kind: "pause_declared")
  end
end
