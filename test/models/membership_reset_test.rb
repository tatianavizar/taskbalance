require "test_helper"

# Decision 2026-11-12: the level starts again from zero when the household's
# membership changes. Report history stays.
class MembershipResetTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  def resets(household) = household.level_changes.membership_changed

  def with_progress(household, level: 5, count: 17, reached_on: Date.new(2026, 6, 1))
    household.update_columns(level: level, balanced_weeks_count: count, ultimate_reached_on: reached_on)
    household.household_weeks.create!(week_start: Date.new(2026, 10, 5), time_zone: PARIS, status: "final",
                                      outcome: "balanced", computed_at: Time.current)
    household
  end

  test "the first member and the second one arriving at level 0 log nothing" do
    household = Household.create_for(users(:dana), name: "Chez Dana")
    assert_empty resets(household)

    users(:carol).household_membership.destroy!
    household.household_members.create!(user: users(:carol))
    assert household.reload.active?
    assert_empty resets(household)
    assert_equal 0, household.level
  end

  test "an arrival resets level, counter and ultimate window, and logs it once" do
    household, = build_household("Alice", "Bob")
    with_progress(household)

    join(household, "Chloé", at: Time.current)
    household.reload
    assert_equal [ 0, 0, nil ], [ household.level, household.balanced_weeks_count, household.ultimate_reached_on ]
    change = resets(household).sole
    assert_equal [ 5, 0, 17, 0 ], [ change.from_level, change.to_level, change.balanced_weeks_count_before, change.balanced_weeks_count_after ]
    assert_equal household.current_week.monday, change.week_start
    assert_equal 1, household.household_weeks.count, "report history stays"
  end

  test "a departure through leave! resets too; an already reset household logs nothing more" do
    household, (_alice, bob, chloe) = build_household("Alice", "Bob", "Chloé")
    with_progress(household, level: 3, count: 7, reached_on: nil)

    membership(household, bob).leave!
    household.reload
    assert_equal [ 0, 0 ], [ household.level, household.balanced_weeks_count ]
    assert_equal 1, resets(household).count

    membership(household, chloe).destroy!
    assert_equal 1, resets(household.reload).count, "nothing to reset the second time"
    assert household.solo?
  end

  test "destroying a membership directly resets, and the household keeps its reports" do
    household, (_alice, bob) = build_household("Alice", "Bob")
    with_progress(household, level: 1, count: 1, reached_on: nil)

    membership(household, bob).destroy!
    household.reload
    assert_equal 0, household.level
    assert_equal 1, resets(household).count
    assert household.household_weeks.exists?
  end

  test "destroying the whole household does not log resets on the way" do
    household, = build_household("Alice", "Bob")
    with_progress(household)

    assert_difference -> { LevelChange.count }, 0 do
      household.destroy!
    end
  end

  test "after a reset, the engine climbs again from zero" do
    household, (alice, bob) = build_household("Alice", "Bob", joined_at: paris(2026, 10, 4, 9))
    with_progress(household, level: 2, count: 4, reached_on: nil)
    chloe = join(household, "Chloé", at: paris(2026, 10, 4, 10))
    week = Week.containing(Date.new(2026, 10, 12), PARIS) # the week after the stored report
    [ alice, bob, chloe ].each { |u| log!(household, u, at: week.start_at + 2.days) }

    run_engine(household, HouseholdWeek.final_at(week))
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]
  end
end
