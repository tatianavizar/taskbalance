require "test_helper"

# The 2.2c metric: planned occurrences, a shared chore counts in full for each
# assignee, one bar = the average of the mental and execution shares.
class PlannedSplitTest < ActiveSupport::TestCase
  Row = Struct.new(:occurrences, :mental_load, :execution_load, :assignees)

  test "shares follow planned occurrences: a daily chore weighs 7 weekly ones" do
    shares = PlannedSplit.shares_for([ Row.new(7, false, true, [ "a" ]), Row.new(1, false, true, [ "b" ]) ], %w[a b])
    assert_in_delta 87.5, shares["a"].execution, 0.01
    assert_in_delta 12.5, shares["b"].execution, 0.01
  end

  test "a shared chore counts in full for each assignee" do
    rows = [ Row.new(7, true, true, %w[a b]), Row.new(7, false, true, [ "a" ]) ]
    shares = PlannedSplit.shares_for(rows, %w[a b])
    assert_equal 14, shares["a"].execution_count
    assert_equal 7, shares["b"].execution_count
    assert_in_delta 50, shares["a"].mental, 0.01
    assert_in_delta (200.0 / 3), shares["a"].execution, 0.01
  end

  test "the bar is the average of the two charges" do
    rows = [ Row.new(1, true, false, [ "a" ]), Row.new(3, false, true, [ "a" ]), Row.new(1, false, true, [ "b" ]) ]
    share = PlannedSplit.shares_for(rows, %w[a b])["a"]
    assert_in_delta 100, share.mental, 0.01
    assert_in_delta 75, share.execution, 0.01
    assert_in_delta 87.5, share.average, 0.01
  end

  test "a charge nobody plans is left out of the average" do
    share = PlannedSplit.shares_for([ Row.new(2, false, true, [ "a" ]), Row.new(2, false, true, [ "b" ]) ], %w[a b])["a"]
    assert_nil share.mental
    assert_in_delta 50, share.average, 0.01
  end

  test "exact? when every bar rounds to the fair share" do
    participants = %w[a b].map { |k| SplitParticipant.new(key: k, user_id: nil, invitation_id: nil, first_name: k, monogram: k, color: "mint", provisional: false) }
    week = Week.current
    even = PlannedSplit.new(items: [ PlannedSplit::Item.new(chore_id: 1, name: "x", category: "other", frequency: "weekly", times_per_period: 1, occurrences: 1, mental_load: true, execution_load: false, time_required: 5, assignees: [ "a" ]),
                                     PlannedSplit::Item.new(chore_id: 2, name: "y", category: "other", frequency: "weekly", times_per_period: 1, occurrences: 1, mental_load: true, execution_load: false, time_required: 5, assignees: [ "b" ]) ],
                            participants: participants, week: week)
    assert even.exact?
    uneven = PlannedSplit.new(items: even.items.first(1), participants: participants, week: week)
    assert_not uneven.exact?
  end

  test "from_household reads the active chores of the household" do
    split = PlannedSplit.from_household(households(:smith_home))
    assert_equal households(:smith_home).chores.active.count, split.items.size
    chores(:smith_laundry).update_column(:active, false)
    assert_equal split.items.size - 1, PlannedSplit.from_household(households(:smith_home)).items.size
  end
end
