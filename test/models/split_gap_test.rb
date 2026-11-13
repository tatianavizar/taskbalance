require "test_helper"

class SplitGapTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers
  include SplitHelpers

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    chore!(@household, "Ménage", [ @alice ])
    plan!(@household, week(0))
  end

  test "the real gap of a week is the average of the two charges minus the fair share, exact shares" do
    hw = final_week!(@household, week(0), @alice => [ 70.0, 60.0 ], @bob => [ 30.0, 40.0 ])
    gaps = SplitGap.week_gaps(hw)
    assert_in_delta 15.0, gaps[@alice.id]
    assert_in_delta(-15.0, gaps[@bob.id])
  end

  test "worked example: +15, targets held at the zone, then +7 after a compensating week" do
    final_week!(@household, week(0), @alice => [ 70.0, 60.0 ], @bob => [ 30.0, 40.0 ])
    SplitGap.fold!(@household)
    assert_equal({ @alice.id => 15.0, @bob.id => -15.0 }, SplitGap.balances(@household))

    participants = @household.split_participants(include_invitations: false)
    assert_equal({ "user:#{@alice.id}" => 40, "user:#{@bob.id}" => 60 }, SplitGap.targets(@household, participants))

    final_week!(@household, week(1), @alice => [ 42.0, 42.0 ], @bob => [ 58.0, 58.0 ])
    SplitGap.fold!(@household)
    assert_in_delta 7.0, SplitGap.balance_of(@household, @alice)
    targets = SplitGap.targets(@household, participants)
    assert_in_delta 43.0, targets["user:#{@alice.id}"]
    assert_in_delta 57.0, targets["user:#{@bob.id}"]
  end

  test "fold is idempotent and catches up several weeks in order" do
    final_week!(@household, week(0), @alice => [ 55.0, 55.0 ], @bob => [ 45.0, 45.0 ])
    final_week!(@household, week(1), @alice => [ 60.0, 50.0 ], @bob => [ 40.0, 50.0 ])
    2.times { SplitGap.fold!(@household) }

    assert_in_delta 10.0, SplitGap.balance_of(@household, @alice)
    assert_equal week(1).monday, @household.reload.gap_folded_through
    assert_equal 4, @household.split_gap_entries.count
  end

  test "neutral weeks, weeks before the first plan and a waived week are not folded" do
    final_week!(@household, week(-1), @alice => [ 80.0, 80.0 ], @bob => [ 20.0, 20.0 ])
    final_week!(@household, week(0), { @alice => [ 80.0, 80.0 ], @bob => [ 20.0, 20.0 ] }, outcome: "neutral")
    plan = plan!(@household, week(1))
    plan.update!(carry_gap: false, gap_waived_by: @alice)
    final_week!(@household, week(1), @alice => [ 80.0, 80.0 ], @bob => [ 20.0, 20.0 ])
    SplitGap.fold!(@household)

    assert_equal 0.0, SplitGap.balance_of(@household, @alice)
    assert_equal week(1).monday, @household.reload.gap_folded_through
  end

  test "a waiver whose author is not above the zone in the plan is ignored when the week is folded" do
    plan = plan!(@household, week(1))
    plan.update!(carry_gap: false, gap_waived_by: @bob) # Bob carries 0 % in this plan
    final_week!(@household, week(1), @alice => [ 80.0, 80.0 ], @bob => [ 20.0, 20.0 ])
    SplitGap.fold!(@household)

    assert_in_delta 30.0, SplitGap.balance_of(@household, @alice)
  end

  test "a waiver whose author is not above the zone is dropped at validation" do
    plan = plan!(@household, week(1), by: @alice)
    plan.update!(carry_gap: false, gap_waived_by: @bob)
    plan.approve!(by: @bob)

    assert plan.reload.validated?
    assert plan.carry_gap
    assert_nil plan.gap_waived_by
  end

  test "with the carry-over off nothing is folded and the targets are the fair share" do
    @household.update!(gap_carry_over_enabled: false)
    final_week!(@household, week(0), @alice => [ 70.0, 70.0 ], @bob => [ 30.0, 30.0 ])
    SplitGap.fold!(@household)

    assert_empty @household.split_gap_entries
    participants = @household.split_participants(include_invitations: false)
    assert_equal [ 50.0, 50.0 ], SplitGap.targets(@household, participants).values
  end

  test "paused members are left out of the week's gap; three members use 100 / 3" do
    chloe = join(@household, "Chloé", at: paris(2026, 9, 2))
    hw = final_week!(@household, week(0), { @alice => [ 50.0, 50.0 ], @bob => [ 50.0, 50.0 ], chloe => [ 0.0, 0.0 ] }, paused: [ chloe ])
    assert_equal [ @alice.id, @bob.id ], SplitGap.week_gaps(hw).keys

    hw2 = final_week!(@household, week(1), @alice => [ 40.0, 40.0 ], @bob => [ 30.0, 30.0 ], chloe => [ 30.0, 30.0 ])
    assert_in_delta 40 - (100.0 / 3), SplitGap.week_gaps(hw2)[@alice.id]
  end

  # ---- reset (C9, D4) ---------------------------------------------------------

  test "only the member who carried the surplus can reset; both balances go to zero; the other is told" do
    final_week!(@household, week(0), @alice => [ 60.0, 60.0 ], @bob => [ 40.0, 40.0 ])
    SplitGap.fold!(@household)

    assert_raises(SplitGap::NotACarrier) { SplitGap.reset!(@household, by: @bob) }
    assert SplitGap.carrier?(@household, @alice)

    SplitGap.reset!(@household, by: @alice, week: week(1))
    assert_equal({ @alice.id => 0.0, @bob.id => 0.0 }, SplitGap.balances(@household))
    gap_reset = Notification.where(kind: "gap_reset")
    assert_equal [ @bob.id ], gap_reset.pluck(:user_id)
    assert_not SplitGap.carrier?(@household, @alice)
    assert_raises(SplitGap::NotACarrier) { SplitGap.reset!(@household, by: @alice) }
  end

  test "three members: the waived surplus is shared back in proportion" do
    chloe = join(@household, "Chloé", at: paris(2026, 9, 2))
    final_week!(@household, week(0), @alice => [ 53.0, 53.0 ], @bob => [ 23.0, 23.0 ], chloe => [ 24.0, 24.0 ])
    SplitGap.fold!(@household)
    owed = SplitGap.balances(@household).values_at(@bob.id, chloe.id)

    SplitGap.reset!(@household, by: @alice)
    balances = SplitGap.balances(@household)
    assert_in_delta 0.0, balances[@alice.id], 0.01
    assert_in_delta 0.0, balances[@bob.id] + balances[chloe.id] + balances[@alice.id], 0.01
    assert(owed.zip(balances.values_at(@bob.id, chloe.id)).all? { |before, after| after.abs < before.abs })
  end
end
