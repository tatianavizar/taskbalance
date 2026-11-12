require "test_helper"

class TaskHandoverTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers
  include SplitHelpers

  Refused = TaskHandover::Refused

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    @week = Week.containing(Date.new(2026, 10, 5), PARIS)
    @mine = chore!(@household, "Courses", [ @alice ])
    @theirs = chore!(@household, "Linge", [ @bob ])
    @plan = plan!(@household, @week, by: @alice)
    @plan.approve!(by: @bob)
    travel_to(@week.start_at + 2.days)
  end

  teardown { travel_back }

  def offer!(chore = @mine, from: @alice, to: @bob) = TaskHandover.offer!(chore: chore, from: from, to: to, week: @week)

  test "D15/D16: offered for the week, accepted, the validated plan does not change" do
    handover = offer!
    assert handover.pending?
    assert_equal [ @bob.id ], Notification.where(kind: "task_offered").pluck(:user_id)

    snapshot = @plan.reload.assignments
    handover.accept!(by: @bob)
    assert handover.accepted?
    assert_equal snapshot, @plan.reload.assignments, "the plan stays as validated"
    assert_equal [ "user:#{@alice.id}" ], @mine.reload.assignee_keys, "the standing assignees stay"
    assert_equal [ "user:#{@bob.id}" ], TaskHandover.planned_assignee_keys(@household, @week, @mine)
    assert_equal [ @alice.id ], Notification.where(kind: "task_offer_answered").pluck(:user_id)
    assert_includes Notifications::Message.new(Notification.find_by(kind: "task_offered")).lines.first,
                    "prévue dans votre charge mentale"
  end

  test "refused: nothing changes; it applies to that week only" do
    offer!.refuse!(by: @bob)
    assert_equal [ "user:#{@alice.id}" ], TaskHandover.planned_assignee_keys(@household, @week, @mine)

    offer!.accept!(by: @bob)
    assert_equal [ "user:#{@alice.id}" ], TaskHandover.planned_assignee_keys(@household, @week.next, @mine)
  end

  test "only one's own task, to another member, once at a time" do
    assert_equal :not_yours, assert_raises(Refused) { offer!(@theirs) }.reason
    assert_equal :same_person, assert_raises(Refused) { offer!(to: @alice) }.reason
    assert_equal :not_a_member, assert_raises(Refused) { offer!(to: users(:carol)) }.reason
    offer!
    assert_equal [ @theirs.id ], TaskHandover.offerable_chores(@household, @bob, @week).ids
    assert_empty TaskHandover.offerable_chores(@household, @alice, @week)
    assert_equal :not_yours, assert_raises(Refused) { offer! }.reason, "already offered"
  end

  test "a shared task cannot be offered to someone who already has it" do
    shared = chore!(@household, "Vaisselle", [ @alice, @bob ])
    plan = @household.week_plan_for(@week)
    plan.update_columns(assignments: plan.assignments + [ PlannedSplit::Item.from_chore(shared, @week).to_h ])
    assert_equal :already_assigned, assert_raises(Refused) { offer!(shared) }.reason
  end

  test "only the person offered answers, only while the week runs; the offerer can cancel" do
    handover = offer!
    assert_equal :not_for_you, assert_raises(Refused) { handover.accept!(by: @alice) }.reason
    assert_equal :closed, assert_raises(Refused) { handover.accept!(by: @bob, now: @week.end_at + 1.second) }.reason

    handover.cancel!(by: @alice)
    assert handover.cancelled?
    assert_equal :closed, assert_raises(Refused) { handover.refuse!(by: @bob) }.reason
    assert offer!, "offered again after a cancel"
  end
end
