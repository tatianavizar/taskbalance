require "test_helper"

class WeeklyEngineTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  # Members join on Sunday 4 Oct 2026; the first full week is Mon 5 Oct.
  JOINED = -> { ActiveSupport::TimeZone["Europe/Paris"].local(2026, 10, 4, 9) }

  def week(n, zone = PARIS) = Week.containing(Date.new(2026, 10, 5) + (7 * n), zone)
  def mid(week) = week.start_at + 2.days + 10.hours # Wednesday 10:00 local
  def report(household, week) = household.household_weeks.find_by(week_start: week.monday)
  def final_at(week) = HouseholdWeek.final_at(week)
  def couple(zone: PARIS, joined_at: JOINED.call) = build_household("Alice", "Bob", zone: zone, joined_at: joined_at)

  def unbalanced_week!(household, heavy, light, w)
    log!(household, heavy, at: mid(w), count: 3)
    log!(household, light, at: mid(w))
  end

  # ---- provisional and final reports -------------------------------------

  test "provisional from Sunday 20:00, written once; final from Monday 03:00, with late Sunday logs" do
    household, (alice, bob) = couple
    w = week(0)
    log_balanced_week!(household, [ alice, bob ], w)

    run_engine(household, paris(2026, 10, 11, 19, 59))
    assert_nil report(household, w)

    result = run_engine(household, paris(2026, 10, 11, 20, 0))
    provisional = report(household, w)
    assert provisional.provisional?
    assert provisional.balanced?
    assert_equal [ provisional ], result.provisional_weeks

    log!(household, alice, at: paris(2026, 10, 11, 21, 0), count: 3) # late Sunday logs
    assert_empty run_engine(household, paris(2026, 10, 11, 22, 0)).provisional_weeks
    assert_equal [ 1, 1 ], report(household, w).members.map { _1["logs_count"] }, "the provisional report is not rewritten"

    run_engine(household, paris(2026, 10, 12, 2, 59))
    assert report(household, w).provisional?

    run_engine(household, paris(2026, 10, 12, 3, 0))
    final = report(household, w)
    assert final.final?
    assert_equal provisional.id, final.id
    assert_equal [ 4, 1 ], final.members.map { _1["logs_count"] }
    assert final.unbalanced?
    assert_equal 0, household.balanced_weeks_count
  end

  test "a final report is never rewritten, even when a log is back-dated into its week" do
    household, (alice, bob) = couple
    w = week(0)
    log_balanced_week!(household, [ alice, bob ], w)
    run_engine(household, paris(2026, 10, 12, 3, 0))
    final = report(household, w)

    log!(household, bob, at: mid(w), count: 5)
    run_engine(household, paris(2026, 10, 14, 9))

    assert_equal final.attributes, report(household, w).attributes
    assert final.reload.balanced?
    assert_raises(ActiveRecord::ReadOnlyRecord) { final.update!(computed_at: Time.current) }
    assert_equal 1, household.balanced_weeks_count
  end

  test "catches up several missed weeks in order, and a rerun changes nothing" do
    household, (alice, bob) = couple
    (0..2).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }

    result = run_engine(household, paris(2026, 10, 26, 10))
    assert_equal [ week(-1), week(0), week(1), week(2) ].map(&:monday), result.final_weeks.map(&:week_start)
    assert_equal %w[neutral balanced balanced balanced], household.household_weeks.chronological.map(&:outcome)
    assert_equal "member_arrived", report(household, week(-1)).neutral_reason
    assert_equal 3, household.balanced_weeks_count
    assert_equal 2, household.level
    assert_equal [ [ 0, 1 ], [ 1, 2 ] ], household.level_changes.chronological.map { [ _1.from_level, _1.to_level ] }
    assert household.level_changes.all?(&:reached?)

    again = run_engine(household, paris(2026, 10, 26, 10))
    assert_empty again.final_weeks
    assert_empty again.level_changes
    assert_equal 4, household.household_weeks.count
    assert_equal 3, household.reload.balanced_weeks_count
    assert_equal 2, household.level_changes.count
  end

  test "each household runs on its own zone (Asia/Kolkata, UTC+5:30)" do
    kolkata, (k1, k2) = couple(zone: "Asia/Kolkata", joined_at: local("Asia/Kolkata", 2026, 10, 4, 9))
    paris_home, (p1, p2) = couple
    log_balanced_week!(kolkata, [ k1, k2 ], week(0, "Asia/Kolkata"))
    log_balanced_week!(paris_home, [ p1, p2 ], week(0))

    sunday_20_kolkata = Time.utc(2026, 10, 11, 14, 30)
    run_engine(kolkata, sunday_20_kolkata - 1.minute)
    assert_nil report(kolkata, week(0))

    run_engine(kolkata, sunday_20_kolkata)
    run_engine(paris_home, sunday_20_kolkata) # 16:30 in Paris
    assert report(kolkata, week(0)).provisional?
    assert_nil report(paris_home, week(0))

    monday_03_kolkata = Time.utc(2026, 10, 11, 21, 30) # 23:30 in Paris
    run_engine(kolkata, monday_03_kolkata)
    run_engine(paris_home, monday_03_kolkata)
    assert report(kolkata, week(0)).final?
    assert report(paris_home, week(0)).provisional?
    assert_equal 1, kolkata.balanced_weeks_count
    assert_equal 0, paris_home.balanced_weeks_count
  end

  test "autumn DST week: the closing stays at Monday 03:00 local and Sunday 23:30 counts" do
    household, (alice, bob) = couple
    w = week(2) # 19–25 Oct, clocks go back on Sunday 25
    log!(household, alice, at: mid(w))
    log!(household, bob, at: paris(2026, 10, 25, 23, 30))

    assert_equal Time.utc(2026, 10, 26, 2, 0), final_at(w)
    assert_equal Time.utc(2026, 10, 25, 19, 0), HouseholdWeek.provisional_at(w)

    run_engine(household, Time.utc(2026, 10, 26, 1, 59))
    assert report(household, w).provisional?
    run_engine(household, Time.utc(2026, 10, 26, 2, 0))
    assert report(household, w).final?
    assert report(household, w).balanced?
  end

  test "spring DST week: Sunday 20:00 and Monday 03:00 are local summer time" do
    household, (alice, bob) = couple(joined_at: paris(2026, 3, 22, 9))
    w = Week.containing(Date.new(2026, 3, 23), PARIS) # clocks go forward on Sunday 29
    log_balanced_week!(household, [ alice, bob ], w)

    assert_equal Time.utc(2026, 3, 29, 18, 0), HouseholdWeek.provisional_at(w)
    assert_equal Time.utc(2026, 3, 30, 1, 0), final_at(w)
    run_engine(household, Time.utc(2026, 3, 30, 0, 59))
    assert report(household, w).provisional?
    run_engine(household, Time.utc(2026, 3, 30, 1, 0))
    assert report(household, w).final?
  end

  test "a household created during the week gets no report before it existed" do
    household, = couple(joined_at: paris(2026, 10, 11, 21))
    run_engine(household, paris(2026, 10, 11, 22))
    assert report(household, week(0)).provisional?, "created Sunday 21:00, still gets that week's provisional"

    run_engine(household, paris(2026, 10, 12, 3))
    assert_equal [ week(0).monday ], household.household_weeks.pluck(:week_start)
  end

  # ---- levels --------------------------------------------------------------

  test "levels at 1, 3, 6, 10 and 15 balanced weeks" do
    household, (alice, bob) = couple
    (0..14).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }

    run_engine(household, final_at(week(14)))
    assert_equal 15, household.balanced_weeks_count
    assert_equal Progression::ULTIMATE, household.level
    assert household.ultimate_level?
    changes = household.level_changes.chronological
    assert_equal [ 1, 2, 3, 4, 5 ], changes.map(&:to_level)
    assert_equal [ 1, 3, 6, 10, 15 ], changes.map(&:balanced_weeks_count_after)
    assert_equal [ week(0), week(2), week(5), week(9), week(14) ].map(&:monday), changes.map(&:week_start)
  end

  test "unbalanced and neutral weeks only stop progression" do
    household, (alice, bob) = couple
    log_balanced_week!(household, [ alice, bob ], week(0))
    unbalanced_week!(household, alice, bob, week(1))
    log!(household, alice, at: mid(week(2)), execution: false)
    log!(household, bob, at: mid(week(2)), execution: false)
    log_balanced_week!(household, [ alice, bob ], week(3))

    run_engine(household, final_at(week(3)))
    assert_equal %w[neutral balanced unbalanced neutral balanced], household.household_weeks.chronological.map(&:outcome)
    assert_equal "no_execution_logs", report(household, week(2)).neutral_reason
    assert_equal 2, household.balanced_weeks_count
    assert_equal 1, household.level
    assert household.active?
  end

  # Quota (decision 2026-11-12): the ultimate level holds while the window
  # (from the reach, 52 weeks at most) has at most 7 unbalanced final weeks.
  test "ultimate level: kept at 7 unbalanced weeks, lost at the 8th, regained when the oldest slides out, window not restarted" do
    household, (alice, bob) = couple
    (0..14).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }  # reached at week 14
    (15..22).each { |n| unbalanced_week!(household, alice, bob, week(n)) }     # 8 unbalanced
    (23..67).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }

    run_engine(household, final_at(week(14)))
    assert_equal 5, household.level
    assert_equal week(14).monday, household.ultimate_reached_on
    assert_equal 7, Progression.ultimate_margin(household)

    run_engine(household, final_at(week(21)))
    assert_equal 5, household.level, "7 unbalanced weeks keep it"
    assert_equal 0, Progression.ultimate_margin(household)

    run_engine(household, final_at(week(22)))
    assert_equal 4, household.level, "the 8th loses it"
    assert household.level_changes.chronological.last.ultimate_lost?
    assert_nil Progression.ultimate_margin(household)

    run_engine(household, final_at(week(66)))
    assert_equal 4, household.level, "week 15 is still in the 52-week window"

    run_engine(household, final_at(week(67)))
    assert_equal 5, household.level, "week 15 left the window: 7 unbalanced weeks"
    assert household.level_changes.chronological.last.ultimate_regained?
    assert_equal week(14).monday, household.ultimate_reached_on, "a regain does not restart the window"
    assert_equal 0, Progression.ultimate_margin(household)
  end

  test "ultimate level: a week neutralised by a retroactive pause leaves the quota" do
    household, (alice, bob) = couple
    (0..14).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }
    (15..21).each { |n| unbalanced_week!(household, alice, bob, week(n)) } # 7 unbalanced
    log!(household, alice, at: mid(week(22)))                              # 8th: Bob logged nothing
    log_balanced_week!(household, [ alice, bob ], week(23))

    run_engine(household, final_at(week(22)))
    assert_equal 4, household.level

    travel_to(final_at(week(22)) + 1.day) do
      MemberPause.declare!(member: membership(household, bob), declared_by: bob,
                           starts_on: week(22).monday, ends_on: week(22).sunday)
    end
    assert_equal 7, Progression.unbalanced_weeks_in_window(household.reload, week(22))

    run_engine(household, final_at(week(23)))
    assert_equal 5, household.level, "regained at the next final report"
    assert household.level_changes.chronological.last.ultimate_regained?
  end

  test "the window restarts at a new reach after a regression for empty weeks" do
    household, (alice, bob) = couple
    (0..14).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) } # reached at week 14
    log!(household, alice, at: mid(week(15)))
    log!(household, alice, at: mid(week(16)))                                  # Bob: two empty weeks
    (17..21).each { |n| log_balanced_week!(household, [ alice, bob ], week(n)) }

    run_engine(household, final_at(week(17)))
    assert household.level_changes.regressed.exists?
    assert_equal [ 4, 11 ], [ household.level, household.balanced_weeks_count ], "regressed to 4 (10), then +1"

    run_engine(household, final_at(week(21)))
    assert_equal [ 5, 15 ], [ household.level, household.balanced_weeks_count ]
    assert household.level_changes.chronological.last.reached?
    assert_equal week(21).monday, household.ultimate_reached_on
    assert_equal 0, Progression.unbalanced_weeks_in_window(household, week(21)), "weeks 15 and 16 are before the new reach"
    assert_equal 7, Progression.ultimate_margin(household)
  end

  test "a household that took 40 weeks to reach the ultimate level does not lose it the next week" do
    household, (alice, bob) = couple
    # 15 balanced weeks among 40, the 15th on week 39: 25 unbalanced weeks before.
    balanced = (0..39).select { |n| n % 8 < 3 }.first(14) + [ 39 ]
    (0..39).each do |n|
      balanced.include?(n) ? log_balanced_week!(household, [ alice, bob ], week(n)) : unbalanced_week!(household, alice, bob, week(n))
    end
    unbalanced_week!(household, alice, bob, week(40))

    run_engine(household, final_at(week(39)))
    assert_equal [ 5, 15 ], [ household.level, household.balanced_weeks_count ]
    assert_equal week(39).monday, household.ultimate_reached_on

    run_engine(household, final_at(week(40)))
    assert_equal 5, household.level, "1 unbalanced week since the reach; the 25 before do not count"
    assert_equal 6, Progression.ultimate_margin(household)
  end

  test "reaching the ultimate level again by thresholds restarts the window" do
    household, = couple
    household.update_columns(level: 4, balanced_weeks_count: 14, ultimate_reached_on: week(-30).monday)
    alice, bob = household.users.order(:id).to_a
    log_balanced_week!(household, [ alice, bob ], week(0))

    run_engine(household, final_at(week(0)))
    assert_equal 5, household.level
    assert_equal week(0).monday, household.ultimate_reached_on
  end

  # ---- empty weeks, absence inquiry, regression, block ---------------------

  def two_empty_weeks_for_bob(household, alice, bob)
    log_balanced_week!(household, [ alice, bob ], week(0))
    log!(household, alice, at: mid(week(1)))
    log!(household, alice, at: mid(week(2)))
  end

  test "first empty week warns; the second opens an absence inquiry; the deadline applies the regression and the block" do
    household, (alice, bob) = couple
    two_empty_weeks_for_bob(household, alice, bob)

    run_engine(household, final_at(week(1)))
    assert_equal 1, membership(household, bob).empty_weeks_streak
    assert household.warned?
    assert_empty household.absence_inquiries

    result = run_engine(household, final_at(week(2)))
    inquiry = household.absence_inquiries.sole
    assert_equal [ inquiry ], result.inquiries_opened
    assert inquiry.pending?
    assert_equal membership(household, bob), inquiry.household_member
    assert_equal [ week(1).monday, week(2).monday ], [ inquiry.first_week_start, inquiry.last_week_start ]
    assert_equal paris(2026, 10, 28, 20), inquiry.deadline_at
    assert_equal 1, household.level, "decisions wait for the Wednesday deadline"
    assert household.warned?

    run_engine(household, paris(2026, 10, 28, 19, 59))
    assert inquiry.reload.pending?

    result = run_engine(household, paris(2026, 10, 28, 20, 0))
    assert inquiry.reload.regressed?
    assert household.blocked?
    assert_equal paris(2026, 10, 28, 20), household.blocked_at
    assert_equal 0, household.level
    assert_equal 0, household.balanced_weeks_count
    change = household.level_changes.regressed.sole
    assert_equal [ 1, 0, 1, 0 ], [ change.from_level, change.to_level, change.balanced_weeks_count_before, change.balanced_weeks_count_after ]
    assert_equal inquiry, change.absence_inquiry
    assert_equal [ change ], result.level_changes

    assert_empty run_engine(household, paris(2026, 10, 29, 9)).level_changes, "the deadline applies once"
  end

  test "one 'Yes' before the deadline declares the pause and avoids the regression" do
    household, (alice, bob) = couple
    two_empty_weeks_for_bob(household, alice, bob)
    run_engine(household, final_at(week(2)))
    inquiry = household.absence_inquiries.sole

    travel_to(paris(2026, 10, 27, 12)) { inquiry.answer_yes!(by: alice) }
    assert inquiry.reload.paused?
    pause = membership(household, bob).member_pauses.sole
    assert_equal [ Date.new(2026, 10, 12), Date.new(2026, 10, 25), alice.id ], [ pause.starts_on, pause.ends_on, pause.declared_by_id ]
    assert_equal 0, membership(household, bob).empty_weeks_streak
    assert household.reload.active?

    run_engine(household, paris(2026, 10, 29, 9))
    assert_equal 1, household.level
    assert_not household.blocked?
    assert_empty household.level_changes.regressed
    assert report(household, week(2)).unbalanced?, "the final week stays as written"
  end

  test "regression from the ultimate level goes back to level 4 with 10 balanced weeks" do
    household, = couple
    household.update_columns(level: 5, balanced_weeks_count: 16)
    inquiry = household.absence_inquiries.create!(household_member: household.household_members.last,
      first_week_start: week(-2).monday, last_week_start: week(-1).monday, deadline_at: paris(2026, 10, 5, 1))

    run_engine(household, paris(2026, 10, 5, 4))
    assert inquiry.reload.regressed?
    assert_equal [ 4, 10 ], [ household.level, household.balanced_weeks_count ]
    assert household.blocked?
  end

  test "catch-up applies a missed deadline in order, keeps the block, then unblocks on a week where everyone logged" do
    household, (alice, bob) = couple
    log_balanced_week!(household, [ alice, bob ], week(0))
    log_balanced_week!(household, [ alice, bob ], week(1))
    log_balanced_week!(household, [ alice, bob ], week(2)) # level 2, count 3
    log!(household, alice, at: mid(week(3)))
    log!(household, alice, at: mid(week(4)))               # bob empty twice: inquiry, deadline Wed of week 5
    log!(household, alice, at: mid(week(5)))               # bob empty again: no second inquiry
    unbalanced_week!(household, alice, bob, week(6))       # everyone logged: unblocked, not counted
    log_balanced_week!(household, [ alice, bob ], week(7)) # counts normally

    run_engine(household, final_at(week(5)))
    assert household.blocked?
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ], "level 2 -> 1, counter at the level-1 threshold"
    assert_equal 3, membership(household, bob).empty_weeks_streak
    assert_equal 1, household.absence_inquiries.count

    result = run_engine(household, final_at(week(6)))
    assert result.unblocked
    assert_not household.blocked?
    assert_nil household.blocked_at
    assert_equal 1, household.balanced_weeks_count
    assert_equal 0, membership(household, bob).empty_weeks_streak

    run_engine(household, final_at(week(7)))
    assert_equal [ 1, 2 ], [ household.level, household.balanced_weeks_count ]
    assert household.active?
  end

  test "a balanced week lifts the block and counts in the same report" do
    household, (alice, bob) = couple
    household.update_columns(state: "blocked", blocked_at: paris(2026, 10, 1), level: 2, balanced_weeks_count: 3)
    log_balanced_week!(household, [ alice, bob ], week(0))

    result = run_engine(household, final_at(week(0)))
    assert result.unblocked
    assert_equal [ 2, 4 ], [ household.level, household.balanced_weeks_count ]
  end

  test "while blocked, nothing progresses" do
    household, (alice, bob) = couple
    household.update_columns(state: "blocked", blocked_at: paris(2026, 10, 1), level: 2, balanced_weeks_count: 5)
    log!(household, alice, at: mid(week(0)))

    run_engine(household, final_at(week(0)))
    assert household.blocked?
    assert_equal [ 2, 5 ], [ household.level, household.balanced_weeks_count ]
  end

  test "an already blocked household does not regress twice (three members, two absent)" do
    household, (alice, bob, chloe) = build_household("Alice", "Bob", "Chloé", joined_at: JOINED.call)
    (0..2).each { |n| [ alice, bob, chloe ].each { |u| log!(household, u, at: mid(week(n))) } }
    log!(household, alice, at: mid(week(3)))
    log!(household, alice, at: mid(week(4)))

    run_engine(household, final_at(week(4)) + 3.days)
    assert_equal 2, household.absence_inquiries.regressed.count
    assert_equal 1, household.level_changes.regressed.count
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]
    assert household.blocked?
  end

  test "a paused week never counts as empty" do
    household, (alice, bob) = couple
    travel_to(mid(week(1))) { MemberPause.declare!(member: membership(household, bob), declared_by: bob, starts_on: week(1).monday, ends_on: week(1).sunday) }
    log!(household, alice, at: mid(week(1)))
    log!(household, alice, at: mid(week(2)))

    run_engine(household, final_at(week(2)) + 3.days)
    assert_equal "too_few_active_members", report(household, week(1)).neutral_reason
    assert_equal "Bob", report(household, week(1)).pauses.sole["first_name"]
    assert_equal 1, membership(household, bob).empty_weeks_streak
    assert_empty household.absence_inquiries
    assert household.warned?
  end

  test "weeks where nobody logs leave streaks alone and make the household dormant after three" do
    household, (alice, bob) = couple
    log_balanced_week!(household, [ alice, bob ], week(0))

    run_engine(household, final_at(week(3)))
    assert household.dormant?
    assert_equal 3, household.silent_weeks_count
    assert_equal [ 0, 0 ], household.household_members.map(&:empty_weeks_streak)
    assert_empty household.absence_inquiries
    assert_equal 1, household.level

    log!(household, alice, at: mid(week(4)))
    run_engine(household, final_at(week(4)))
    assert household.warned?
    assert_equal 0, household.silent_weeks_count
  end

  test "the arrival week counts for nobody and the newcomer's empty arrival week is not an empty week" do
    household, (alice, bob) = couple
    chloe = join(household, "Chloé", at: mid(week(0)))
    log_balanced_week!(household, [ alice, bob ], week(0))
    log_balanced_week!(household, [ alice, bob ], week(1))

    run_engine(household, final_at(week(0)))
    assert_equal "member_arrived", report(household, week(0)).neutral_reason
    assert_equal 0, household.balanced_weeks_count
    assert_equal 0, membership(household, chloe).empty_weeks_streak

    run_engine(household, final_at(week(1)))
    assert_equal 1, membership(household, chloe).empty_weeks_streak
    assert report(household, week(1)).unbalanced?
  end

  test "a single-member household keeps no streaks" do
    household, (alice,) = build_household("Alice", joined_at: JOINED.call)
    log!(household, alice, at: mid(week(0)))

    run_engine(household, final_at(week(2)))
    assert household.solo?
    assert_equal 0, membership(household, alice).empty_weeks_streak
    assert_equal [ "too_few_active_members" ], household.household_weeks.where.not(week_start: week(-1).monday).distinct.pluck(:neutral_reason)
  end

  # ---- state on arrivals and departures ------------------------------------

  test "solo until a second member joins, solo again when they leave" do
    alice = users(:dana)
    household = Household.create_for(alice, name: "Chez Dana")
    assert household.solo?

    household.household_members.create!(user: users(:carol).tap { _1.household_membership.destroy! })
    assert household.reload.active?

    membership(household, users(:carol)).leave!
    assert household.reload.solo?
  end

  test "run_all reports a failing household and goes on with the others" do
    broken, = couple
    broken.update_column(:time_zone, "Nowhere/City")
    household, (alice, bob) = couple
    log_balanced_week!(household, [ alice, bob ], week(0))

    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error }
    Rails.error.subscribe(subscriber)
    travel_to(final_at(week(0))) { WeeklyEngineJob.perform_now }

    assert_equal 1, household.reload.balanced_weeks_count
    assert(reported.any? { _1.is_a?(ArgumentError) })
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber
  end
end
