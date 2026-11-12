require "test_helper"

# C16: any member can change the split settings; a change applies once every
# member validated it. Auto-validation is off by default.
class SplitSettingChangeTest < ActiveSupport::TestCase
  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
    @bob = users(:bob)
  end

  test "settings start with the weekly proposal and the carry-over on, auto-validation off" do
    household = Household.create_for(users(:dana), name: "Neuf")
    assert household.weekly_proposal_enabled?
    assert household.gap_carry_over_enabled?
    assert_not household.auto_validate_splits?
  end

  test "a change waits for every member, then applies" do
    change = SplitSettingChange.request!(household: @household, by: @alice, changes: { auto_validate_splits: "1" })

    assert change.pending?
    assert_not @household.reload.auto_validate_splits?
    assert_equal [ "Bob" ], change.pending_members.map { |m| m.user.first_name }

    assert change.approve!(by: @bob)
    assert change.reload.applied?
    assert @household.reload.auto_validate_splits?
  end

  test "a household of one applies the change at once" do
    household = Household.create_for(users(:dana), name: "Solo")
    change = SplitSettingChange.request!(household: household, by: users(:dana), changes: { gap_carry_over_enabled: "0" })
    assert change.applied?
    assert_not household.reload.gap_carry_over_enabled?
  end

  test "a new request withdraws the pending one" do
    first = SplitSettingChange.request!(household: @household, by: @alice, changes: { auto_validate_splits: true })
    second = SplitSettingChange.request!(household: @household, by: @bob, changes: { weekly_proposal_enabled: false })

    assert first.reload.withdrawn?
    assert second.pending?
    assert_equal [ "Alice" ], second.pending_members.map { |m| m.user.first_name }
  end

  test "nothing to request when the settings do not change" do
    assert_nil SplitSettingChange.request!(household: @household, by: @alice, changes: { weekly_proposal_enabled: true })
  end

  test "unknown settings are ignored" do
    assert_nil SplitSettingChange.request!(household: @household, by: @alice, changes: { name: "Piraté" })
  end

  test "only a member can validate" do
    change = SplitSettingChange.request!(household: @household, by: @alice, changes: { auto_validate_splits: true })
    assert_raises(WeekPlan::NotAParticipant) { change.approve!(by: users(:carol)) }
  end
end
