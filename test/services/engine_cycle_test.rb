require "test_helper"
require "minitest/mock"

# The fan-out of the weekly engine: the dispatcher selects the households that
# have something due, one HouseholdEngineJob each, nothing otherwise; a run
# stores its next due moment; overlapping or repeated runs do nothing twice.
class EngineCycleTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include WeeklyEngineHelpers

  LOS_ANGELES = "America/Los_Angeles".freeze
  KOLKATA = "Asia/Kolkata".freeze
  # Members join on Sunday 4 Oct 2026, 09:00 Paris.
  JOINED = -> { ActiveSupport::TimeZone[PARIS].local(2026, 10, 4, 9) }

  def week(n, zone = PARIS) = Week.containing(Date.new(2026, 10, 5) + (7 * n), zone)
  def final_at(week) = HouseholdWeek.final_at(week)
  def provisional_at(week) = HouseholdWeek.provisional_at(week)

  # A couple whose household exists since `at` (so it is due from `at`).
  def couple(zone: PARIS, at: JOINED.call)
    travel_to(at) { build_household("Alice", "Bob", zone: zone, joined_at: at) }
  end

  # One tick of the recurring dispatcher at `now`, and the jobs it enqueued run
  # to the end. Returns the ids of the households it enqueued.
  def tick(now)
    clear_enqueued_jobs
    travel_to(now) { EngineDispatchJob.perform_now(now: now) }
    ids = enqueued_jobs.select { _1["job_class"] == "HouseholdEngineJob" }.map { _1["arguments"].first }
    travel_to(now) { perform_enqueued_jobs }
    ids
  end

  def due_at(household) = household.reload.engine_due_at

  test "a new household is due at once, and a run stores its next moment" do
    household, = couple
    assert_equal [ household.id ], tick(JOINED.call + 1.hour)

    # Joined Sunday 4 Oct: the open week is the one ending that day.
    assert_in_delta provisional_at(week(-1)), due_at(household), 1.second
    assert_nil household.engine_claimed_at
  end

  test "nothing is enqueued when nothing is due" do
    household, = couple
    tick(JOINED.call + 1.hour)

    assert_no_enqueued_jobs { EngineDispatchJob.perform_now(now: JOINED.call + 2.hours) }
    assert_no_enqueued_jobs { EngineDispatchJob.perform_now(now: provisional_at(week(-1)) - 1.minute) }
    assert_empty tick(provisional_at(week(-1)) - 1.minute)
    assert household.reload.engine_due_at
  end

  test "each moment of the week makes the household due once: provisional, final" do
    household, (alice, bob) = couple
    tick(JOINED.call + 1.hour)
    log_balanced_week!(household, [ alice, bob ], week(0))

    sunday_2000 = provisional_at(week(-1))
    assert_empty tick(sunday_2000 - 1.minute)
    assert_equal [ household.id ], tick(sunday_2000)
    assert HouseholdWeek.find_by!(household: household, week_start: week(-1).monday).provisional?
    assert_in_delta final_at(week(-1)), due_at(household), 1.second
    assert_empty tick(sunday_2000 + 1.hour), "the provisional report is written once"

    assert_empty tick(final_at(week(-1)) - 1.minute)
    assert_equal [ household.id ], tick(final_at(week(-1)))
    assert HouseholdWeek.find_by!(household: household, week_start: week(-1).monday).final?
    assert_in_delta provisional_at(week(0)), due_at(household), 1.second
  end

  test "the Wednesday deadline of an absence inquiry makes the household due" do
    household, (alice, bob) = couple
    tick(JOINED.call + 1.hour)
    log_balanced_week!(household, [ alice, bob ], week(0))
    log!(household, alice, at: week(1).start_at + 2.days + 10.hours)
    log!(household, alice, at: week(2).start_at + 2.days + 10.hours) # Bob: two empty weeks
    tick(final_at(week(1)))
    tick(final_at(week(2)))

    inquiry = household.absence_inquiries.pending.sole
    assert_in_delta inquiry.deadline_at, due_at(household), 1.second, "before the next Sunday 20:00"
    assert_empty tick(inquiry.deadline_at - 1.minute)
    assert_equal [ household.id ], tick(inquiry.deadline_at)
    assert inquiry.reload.regressed?
    assert household.reload.blocked?
  end

  test "an undelivered engine_event makes the household due even when its time has not come" do
    household, = couple
    tick(JOINED.call + 1.hour)
    assert_empty tick(JOINED.call + 2.hours)

    EngineEvent.record!(household: household, name: "household.admin_unblocked", at: JOINED.call + 2.hours)
    assert_equal [ household.id ], tick(JOINED.call + 3.hours)
    assert EngineEvent.where(household: household).all?(&:delivered_at)
    assert_empty tick(JOINED.call + 4.hours)
  end

  test "a catch-up after a stopped worker closes every missed week in order" do
    household, (alice, bob) = couple
    tick(JOINED.call + 1.hour)
    [ week(0), week(1), week(2) ].each { |w| log_balanced_week!(household, [ alice, bob ], w) }

    # No dispatcher tick for three weeks, then the worker is back.
    assert_equal [ household.id ], tick(final_at(week(2)) + 3.hours)

    weeks = household.household_weeks.order(:week_start)
    assert_equal [ week(-1), week(0), week(1), week(2) ].map(&:monday), weeks.map(&:week_start)
    assert weeks.all?(&:final?)
    assert_equal 3, household.reload.balanced_weeks_count
    assert_in_delta provisional_at(week(3)), due_at(household), 1.second
  end

  test "households of several time zones become due at their own local moments, in time order" do
    paris, = couple(zone: PARIS)
    los_angeles, = couple(zone: LOS_ANGELES)
    kolkata, = couple(zone: KOLKATA)
    assert_equal [ paris.id, los_angeles.id, kolkata.id ].sort, tick(JOINED.call + 1.hour).sort

    # Sunday 20:00 and Monday 03:00 local of the week they joined in. In UTC:
    # Kolkata 14:30 and 21:30, Paris 18:00 and 01:00, Los Angeles 03:00 and 10:00.
    moments = [ paris, los_angeles, kolkata ].flat_map do |household|
      w = week(-1, household.time_zone)
      [ [ household, provisional_at(w) ], [ household, final_at(w) ] ]
    end.sort_by(&:last)
    assert_equal 6, moments.map(&:last).uniq.size

    moments.each do |household, moment|
      assert_empty tick(moment - 1.minute), "nobody is due a minute before #{household.time_zone} #{moment}"
      assert_equal [ household.id ], tick(moment), "only #{household.time_zone} at #{moment}"
    end
    assert_equal [ 1, 1, 1 ], [ paris, los_angeles, kolkata ].map { _1.household_weeks.final.count }
  end

  test "a claimed household is not enqueued twice, and a stale claim is picked up again" do
    household, = couple
    now = JOINED.call + 1.hour
    clear_enqueued_jobs
    assert_equal 1, EngineCycle.enqueue_due(now: now)
    assert_equal 0, EngineCycle.enqueue_due(now: now + 5.minutes), "claimed: the job is still queued"
    assert_equal 1, EngineCycle.enqueue_due(now: now + EngineCycle::CLAIM_TTL + 1.minute), "claim gone stale"
    assert_enqueued_jobs 2, only: HouseholdEngineJob
    assert household.reload.engine_claimed_at
  end

  test "enqueues in batches" do
    3.times { couple }
    clear_enqueued_jobs
    assert_equal 3, EngineCycle.enqueue_due(now: JOINED.call + 1.hour, batch_size: 2)
    assert_enqueued_jobs 3, only: HouseholdEngineJob
  end

  test "overlapping or repeated runs for one household process it once" do
    household, (alice, bob) = couple
    tick(JOINED.call + 1.hour)
    log_balanced_week!(household, [ alice, bob ], week(0))
    now = final_at(week(0)) + 1.minute

    # Two jobs for the same household (stale claim, manual enqueue, retry).
    travel_to(now) do
      2.times { HouseholdEngineJob.perform_now(household.id, now: now) }
      EngineCycle.run(Household.find(household.id), now: now)
    end

    assert_equal 1, household.household_weeks.final.where(week_start: week(0).monday).count
    assert_equal 1, household.reload.balanced_weeks_count
    assert_equal 1, EngineEvent.where(household: household, name: "household_week.final",
                                      subject_id: household.household_weeks.final.pluck(:id)).where("payload->>'week_start' = ?", week(0).monday.to_s).count
    reports = Notification.where(household: household, kind: "weekly_report")
    assert_equal reports.map { [ _1.user_id, _1.facts["week_start"] ] }.uniq.size, reports.count, "one report per person and week"
  end

  test "a wake-up during a run is not overwritten by the run's reschedule" do
    household, = couple
    started_at = Time.current
    sleep 0.01
    household.wake_engine
    travel_to(JOINED.call + 1.hour) do
      EngineCycle.new(household.reload, Time.current).send(:reschedule, started_at)
    end
    assert_operator due_at(household), :>, started_at
    assert_operator due_at(household), :<=, Time.current + 1.second
  end

  test "a failing step does not stop the next ones, keeps the household due and raises" do
    household, = couple
    clear_enqueued_jobs
    EngineCycle.enqueue_due(now: JOINED.call + 1.hour)
    EngineEvent.record!(household: household, name: "household.admin_unblocked", at: JOINED.call)
    before = due_at(household)

    error = assert_raises(RuntimeError) do
      WeeklySplit.stub(:new, ->(*) { raise "boom" }) do
        travel_to(JOINED.call + 1.hour) { EngineCycle.run(household, now: Time.current) }
      end
    end
    assert_equal "boom", error.message
    assert_equal before, due_at(household), "not rescheduled"
    assert household.reload.engine_claimed_at, "claim kept until it goes stale"
    assert EngineEvent.where(household: household).all?(&:delivered_at), "notifications step still ran"
  end

  test "the jobs run on the engine queue and discard a deleted household" do
    assert_equal "engine", HouseholdEngineJob.new.queue_name
    assert_equal "engine", HouseholdChoreSchedulerJob.new.queue_name
    assert_nothing_raised { HouseholdEngineJob.perform_now(0) } # household deleted: discarded
  end

  # ---- wake-ups -----------------------------------------------------------

  test "a member arriving or leaving, or a changed time zone or setting, wakes the household" do
    household, (_, bob) = couple
    tick(JOINED.call + 1.hour)
    far = Time.current + 3.days
    reset = -> { household.update_columns(engine_due_at: far) }

    reset.call
    join(household, "Carol", at: JOINED.call)
    assert_operator due_at(household), :<, far

    reset.call
    household.household_members.find_by!(user: bob).destroy!
    assert_operator due_at(household), :<, far

    reset.call
    household.update!(time_zone: LOS_ANGELES)
    assert_operator due_at(household), :<, far

    reset.call
    household.update!(weekly_proposal_enabled: false)
    assert_operator due_at(household), :<, far

    reset.call
    household.update!(name: "Autre nom")
    assert_equal far.to_i, due_at(household).to_i, "an unrelated change wakes nothing"
  end

  # ---- inline use ---------------------------------------------------------

  test "WeeklyEngineJob still runs every household inline, due or not" do
    household, (alice, bob) = couple
    log_balanced_week!(household, [ alice, bob ], week(0))
    household.update_columns(engine_due_at: Time.current + 10.days)

    travel_to(final_at(week(0))) { WeeklyEngineJob.perform_now }
    assert_equal 1, household.reload.balanced_weeks_count
  end

  # ---- recurring chore scheduler -----------------------------------------

  test "the chore scheduler enqueues only households whose local Monday has begun and not yet scheduled" do
    paris_home, (paris_user, _) = couple(zone: PARIS, at: Time.utc(2026, 9, 1))
    la_home, (la_user, _) = couple(zone: LOS_ANGELES, at: Time.utc(2026, 9, 1))
    [ [ paris_home, paris_user ], [ la_home, la_user ] ].each do |home, user|
      home.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ user.id ], frequency: :weekly)
    end
    empty_home, = couple(zone: PARIS, at: Time.utc(2026, 9, 1))
    ChoreOccurrence.delete_all
    Household.update_all(chores_scheduled_week: Date.new(2026, 11, 2))
    # The fixtures' households are not the subject here.
    Household.where.not(id: [ paris_home, la_home, empty_home ].map(&:id)).update_all(chores_scheduled_week: Date.new(2027, 1, 4))

    # Monday 9 Nov 2026 00:30 Paris is still Sunday 15:30 in Los Angeles.
    now = ActiveSupport::TimeZone[PARIS].local(2026, 11, 9, 0, 30)
    clear_enqueued_jobs
    assert_equal 1, RecurringChoreScheduler.enqueue_due(now: now)
    assert_enqueued_with(job: HouseholdChoreSchedulerJob, args: [ paris_home.id ])
    assert_equal Date.new(2026, 11, 9), empty_home.reload.chores_scheduled_week, "no chore: marked, no job"
    assert_equal Date.new(2026, 11, 2), la_home.reload.chores_scheduled_week

    travel_to(now) { perform_enqueued_jobs }
    assert_equal [ Date.new(2026, 11, 9) ], ChoreOccurrence.where(household: paris_home).distinct.pluck(:week_start)
    assert_equal Date.new(2026, 11, 9), paris_home.reload.chores_scheduled_week

    clear_enqueued_jobs
    assert_equal 0, RecurringChoreScheduler.enqueue_due(now: now + 1.hour), "done for the week"
    assert_equal 1, RecurringChoreScheduler.enqueue_due(now: now + 9.hours), "Los Angeles Monday has begun"
    assert_enqueued_with(job: HouseholdChoreSchedulerJob, args: [ la_home.id ])
    assert_equal 0, RecurringChoreScheduler.enqueue_due(now: now + 9.hours + 5.minutes), "claimed"
  end
end
