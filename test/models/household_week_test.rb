require "test_helper"

class HouseholdWeekTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  def build(**attrs)
    households(:smith_home).household_weeks.new({ week_start: Date.new(2026, 10, 5), time_zone: PARIS,
                                                  outcome: "balanced", computed_at: Time.current }.merge(attrs))
  end

  test "a provisional report can be rewritten; a final one is read-only" do
    record = build.tap(&:save!)
    assert record.update(outcome: "unbalanced")

    record.update!(status: "final", finalized_at: Time.current)
    assert record.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { record.update!(outcome: "balanced") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { HouseholdWeek.find(record.id).destroy }
  end

  test "one report per household and week, on a Monday" do
    build.save!
    assert_not build.valid?
    tuesday = build(week_start: Date.new(2026, 10, 6))
    assert_not tuesday.valid?
    assert tuesday.errors.added?(:week_start, :not_a_monday)
  end

  test "a neutral report needs a known reason, the others none" do
    assert_not build(outcome: "neutral").valid?
    assert build(outcome: "neutral", neutral_reason: "member_arrived").valid?
    assert_not build(neutral_reason: "member_arrived").valid?
  end

  test "deleting the household deletes its reports, final ones included" do
    household, = build_household("Alice", "Bob")
    household.household_weeks.create!(week_start: Date.new(2026, 10, 5), time_zone: PARIS, outcome: "neutral",
                                      neutral_reason: "member_arrived", status: "final", computed_at: Time.current)
    household.destroy!
    assert_equal 0, HouseholdWeek.count
  end

  test "week, member_snapshot and the closing times" do
    record = build(time_zone: "America/New_York", members: [ { "user_id" => 7, "first_name" => "Alice" } ])
    assert_equal Week.containing(Date.new(2026, 10, 5), "America/New_York"), record.week
    assert_equal "Alice", record.member_snapshot(7)["first_name"]
    assert_equal local("America/New_York", 2026, 10, 11, 20), HouseholdWeek.provisional_at(record.week)
    assert_equal local("America/New_York", 2026, 10, 12, 3), HouseholdWeek.final_at(record.week)
  end
end
