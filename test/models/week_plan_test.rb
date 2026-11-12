require "test_helper"

class WeekPlanTest < ActiveSupport::TestCase
  setup do
    @household = households(:smith_home)
    @alice = users(:alice)
    @bob = users(:bob)
    @week = Week.containing(Date.new(2026, 11, 11), @household.time_zone)
  end

  def propose!(by: @alice, kind: :weekly)
    WeekPlan.propose!(household: @household, by: by, week: @week, kind: kind)
  end

  test "a proposal snapshots the chores, their assignees and the planned shares" do
    plan = propose!

    assert plan.proposed?
    assert_equal @week.monday, plan.week_start
    assert_equal @household.chores.active.count, plan.assignments.size
    cooking = plan.assignments.find { |a| a["chore_id"] == chores(:smith_cooking).id }
    assert_equal 7, cooking["occurrences"]
    assert_equal [ "user:#{@alice.id}" ], cooking["assignees"]
    assert_equal [ "user:#{@alice.id}", "user:#{@bob.id}" ], plan.participants.map { |p| p["key"] }
    assert plan.shares["user:#{@alice.id}"]["average"].positive?
  end

  test "the proposer has validated; the plan waits for the others" do
    plan = propose!

    assert plan.approved_by?(@alice)
    assert_equal [ "Bob" ], plan.pending_participants.map(&:first_name)
  end

  test "validated once everyone validated, then locked" do
    plan = propose!
    assert plan.approve!(by: @bob)

    assert plan.validated?
    assert plan.locked?
    assert_raises(WeekPlan::Locked) { plan.update_assignments!(by: @alice, assignments: {}) }
    assert_raises(WeekPlan::Locked) { propose! }
  end

  test "an edit asks the others again and counts as the editor's validation" do
    plan = propose!
    cooking = chores(:smith_cooking)

    plan.update_assignments!(by: @bob, assignments: { cooking.id => [ "user:#{@bob.id}" ] })

    assert_equal [ "user:#{@bob.id}" ], cooking.reload.assignee_keys
    assert plan.approved_by?(@bob)
    assert_not plan.approved_by?(@alice)
    assert_equal [ "Alice" ], plan.pending_participants.map(&:first_name)
    assert_equal [ "user:#{@bob.id}" ], plan.assignments.find { |a| a["chore_id"] == cooking.id }["assignees"]
  end

  test "an edit cannot leave a chore without assignee" do
    plan = propose!
    assert_raises(ActiveRecord::RecordInvalid) do
      plan.update_assignments!(by: @bob, assignments: { chores(:smith_cooking).id => [] })
    end
    assert_equal [ "user:#{@alice.id}" ], chores(:smith_cooking).reload.assignee_keys
  end

  test "someone outside the household can neither edit nor validate" do
    plan = propose!
    assert_raises(WeekPlan::NotAParticipant) { plan.approve!(by: users(:carol)) }
    assert_raises(WeekPlan::NotAParticipant) { plan.update_assignments!(by: users(:carol), assignments: {}) }
  end

  test "auto-validation applies the proposal at once (C16)" do
    @household.update!(auto_validate_splits: true)
    assert propose!.validated?
  end

  test "a household of one validates its own proposal" do
    household = Household.create_for(users(:dana), name: "Solo")
    plan = WeekPlan.propose!(household: household, by: users(:dana), week: @week)
    assert plan.validated?
  end

  test "a validated split does not move when a chore is removed or added mid-week (D14)" do
    plan = propose!
    plan.approve!(by: @bob)
    removed = chores(:smith_laundry)
    removed.update_column(:active, false)
    added = @household.chores.create!(task: tasks(:pay_bills), assignee_user_ids: [ @bob.id ])

    plan.reload
    assert plan.includes_chore?(removed), "a removed chore stays planned until Sunday"
    assert_not plan.includes_chore?(added), "an added chore is logged outside the split"
  end

  test "an invited person counts in the starting split, marked provisional (D15)" do
    household = Household.create_for(users(:dana), name: "Chez Dana")
    invitation = household.invitations.create!(email: "karim@example.com")
    household.chores.create!(task: tasks(:cook_meal), assignee_keys: [ "invitation:#{invitation.id}" ])

    plan = WeekPlan.propose!(household: household, by: users(:dana), week: @week, kind: :starting)

    assert plan.provisional?
    assert_equal [ "Dana", "karim" ], plan.participant_list.map(&:first_name)
    assert_equal [ "karim" ], plan.pending_participants.map(&:first_name)
    assert_in_delta 100, plan.split.share_of("invitation:#{invitation.id}").execution, 0.01
  end

  test "a weekly plan counts members only" do
    @household.invitations.create!(email: "karim@example.com")
    assert_equal 2, propose!(kind: :weekly).participants.size
  end

  test "« Attendre » records a starting plan with no split (C12)" do
    household = Household.create_for(users(:dana), name: "Chez Dana")
    household.invitations.create!(email: "karim@example.com")

    plan = WeekPlan.await_proposal!(household: household, week: @week)

    assert plan.awaiting_proposal?
    assert plan.starting?
    assert plan.provisional?
  end

  test "lot 3: an accepted invitation hands its assignments and its place to the account" do
    household = Household.create_for(users(:dana), name: "Chez Dana")
    invitation = household.invitations.create!(email: "karim@example.com")
    chore = household.chores.create!(task: tasks(:cook_meal), assignee_keys: [ "invitation:#{invitation.id}" ])
    plan = WeekPlan.propose!(household: household, by: users(:dana), week: @week, kind: :starting)
    karim = User.create!(email: "karim@example.com", first_name: "Karim", password: "secret123")

    ChoreAssignee.transfer_invitation!(invitation, karim)

    assert_equal [ "user:#{karim.id}" ], chore.reload.assignee_keys
    assert_equal "user:#{karim.id}", plan.reload.participants.last["key"]
    assert_not plan.provisional?
  end

  test "recompute! proposes again from the preferences and keeps the proposer's validation" do
    plan = propose!
    cooking = chores(:smith_cooking)
    ChorePreference.create!(user: @bob, chore: cooking, choice: "like")
    ChorePreference.create!(user: @alice, chore: cooking, choice: "dislike")

    plan.recompute!

    assert_equal [ "user:#{@bob.id}" ], cooking.reload.assignee_keys
    assert_equal [ "user:#{@bob.id}" ], plan.assignments.find { |a| a["chore_id"] == cooking.id }["assignees"]
    assert plan.approved_by?(@alice)
    plan.approve!(by: @bob)
    assert_raises(WeekPlan::Locked) { plan.recompute! }
  end

  test "the week must start on a Monday" do
    plan = @household.week_plans.new(week_start: @week.monday + 1, status: :proposed, kind: :weekly)
    assert_not plan.valid?
  end

  test "the split reads back from the snapshot" do
    split = propose!.split
    assert_equal @household.chores.active.count, split.items.size
    assert_equal 2, split.participants.size
    assert_kind_of PlannedSplit::Share, split.share_of("user:#{@alice.id}")
  end
end
