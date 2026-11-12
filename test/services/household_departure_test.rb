require "test_helper"

# F2, backlog 3.3: what leaving a household does (HouseholdMember#leave!).
class HouseholdDepartureTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    travel_to paris(2026, 11, 11, 10) # a Wednesday
    @household, (@ann, @ben, @cleo) = build_household("Ann", "Ben", "Cléo")
    membership(@household, @ben).update_column(:created_at, paris(2026, 9, 2, 9))
    membership(@household, @cleo).update_column(:created_at, paris(2026, 9, 3, 9))
  end

  def chore!(*users, name: "Tâche")
    @household.chores.create!(custom_name: name, category: "other", mental_load: true, execution_load: true,
                              time_required: 10, frequency: :weekly, assignee_user_ids: users.map(&:id))
  end

  test "a chore only the leaver carried goes to every remaining member; a shared one loses the leaver" do
    alone = chore!(@ann, name: "Seule")
    shared = chore!(@ann, @ben, name: "Partagée")
    other = chore!(@cleo, name: "Autre")

    membership(@household, @ann).leave!

    assert_equal [ @ben.id, @cleo.id ].sort, alone.reload.chore_assignees.map(&:user_id).sort
    assert_equal [ @ben.id ], shared.reload.chore_assignees.map(&:user_id)
    assert_equal [ @cleo.id ], other.reload.chore_assignees.map(&:user_id)
    assert @household.chores.all? { |c| c.reload.chore_assignees.any? }, "no chore without an assignee"
    assert alone.valid?
  end

  test "the manager role passes to the oldest remaining member" do
    successor = membership(@household, @ann).leave!

    assert_equal @ben, successor.user
    assert successor.reload.manager?
    assert_not membership(@household, @cleo).manager?
    assert_equal @ben, @household.reload.manager
  end

  test "the leaver's logs stay theirs, detached from the household and its chores" do
    chore = chore!(@ann)
    logs = log!(@household, @ann, at: paris(2026, 11, 10, 9), chore: chore, count: 2)
    ben_log = log!(@household, @ben, at: paris(2026, 11, 10, 9), chore: chore).first

    membership(@household, @ann).leave!

    logs.each(&:reload)
    assert logs.all? { |log| log.user_id == @ann.id && log.household_id.nil? && log.chore_id.nil? }
    assert logs.all?(&:detached?)
    assert_equal chore.effective_name, logs.first.chore_name
    assert_equal @household.id, ben_log.reload.household_id, "another member's log is untouched"
    assert_equal chore.id, ben_log.chore_id
  end

  test "past household_weeks are untouched; the level is reset once, by the membership change" do
    @household.update_columns(level: 2, balanced_weeks_count: 3)
    week = @household.household_weeks.create!(week_start: Date.new(2026, 11, 2), time_zone: "Europe/Paris", status: "final",
                                              outcome: "balanced", fair_share: 33, computed_at: Time.current,
                                              members: [ { "user_id" => @ann.id, "first_name" => "Ann", "mental_share" => 33 } ])

    assert_difference -> { @household.level_changes.membership_changed.count }, 1 do
      membership(@household, @ann).leave!
    end

    assert_equal 0, @household.reload.level
    assert_equal [ { "user_id" => @ann.id, "first_name" => "Ann", "mental_share" => 33 } ], week.reload.members
  end

  test "the current week plan drops the leaver and hands over their planned chores" do
    alone = chore!(@ann, name: "Seule")
    shared = chore!(@ann, @ben, name: "Partagée")
    plan = WeekPlan.propose!(household: @household, by: @ann)
    plan.approve!(by: @ben)
    plan.approve!(by: @cleo)
    assert plan.reload.validated?

    membership(@household, @ann).leave!
    plan.reload

    assert_equal [ "user:#{@ben.id}", "user:#{@cleo.id}" ], plan.participants.map { |p| p["key"] }
    by_chore = plan.assignments.index_by { |item| item["chore_id"] }
    assert_equal [ "user:#{@ben.id}", "user:#{@cleo.id}" ], by_chore[alone.id]["assignees"]
    assert_equal [ "user:#{@ben.id}" ], by_chore[shared.id]["assignees"]
    assert_equal [ "user:#{@ben.id}", "user:#{@cleo.id}" ], plan.shares.keys.sort
    assert_not plan.approvals.exists?(user_id: @ann.id)
    assert plan.validated?
  end

  test "a proposed plan validates once everyone left has validated" do
    chore!(@ann)
    plan = WeekPlan.propose!(household: @household, by: @ben)
    plan.approve!(by: @cleo)
    assert plan.reload.proposed?, "Ann has not validated"

    membership(@household, @ann).leave!

    assert plan.reload.validated?
  end

  test "a pending absence inquiry about the leaver is cancelled; their preferences on the household's chores go" do
    chore = chore!(@ann)
    ChorePreference.record!(@ann, @household, { chore.id => "like" })
    inquiry = @household.absence_inquiries.create!(household_member: membership(@household, @ann),
                                                   first_week_start: Date.new(2026, 10, 26), last_week_start: Date.new(2026, 11, 2),
                                                   deadline_at: paris(2026, 11, 11, 20))

    membership(@household, @ann).leave!

    assert_not AbsenceInquiry.exists?(inquiry.id)
    assert_not ChorePreference.exists?(user_id: @ann.id)
  end

  test "a pending split-settings change applies when the leaver was the last one to validate" do
    change = SplitSettingChange.request!(household: @household, by: @ben, changes: { auto_validate_splits: true })
    change.approve!(by: @cleo)
    assert change.reload.pending?

    membership(@household, @ann).leave!

    assert change.reload.applied?
    assert @household.reload.auto_validate_splits?
  end

  test "the last member out deletes the household; logs survive, invitations are cancelled" do
    household, users = build_household("Solo")
    solo = users.first
    chore = household.chores.create!(custom_name: "Seule", category: "other", mental_load: true, time_required: 10,
                                     assignee_user_ids: [ solo.id ])
    log = log!(household, solo, at: paris(2026, 11, 10, 9), chore: chore).first
    invitation = Invitation.invite(household: household, email: "x@exemple.fr", first_name: "X", inviter: solo)
    assert invitation.persisted?

    membership(household, solo).leave!

    assert_not Household.exists?(household.id)
    assert_not Invitation.exists?(invitation.id)
    assert ChoreLog.exists?(log.id)
    assert_equal solo.id, log.reload.user_id
    assert_nil solo.reload.household
  end

  test "another household is never touched" do
    other, (zoe, yan) = build_household("Zoé", "Yan")
    other_chore = other.chores.create!(custom_name: "Ailleurs", category: "other", mental_load: true, time_required: 10,
                                       assignee_user_ids: [ zoe.id ])
    other_log = log!(other, yan, at: paris(2026, 11, 10, 9)).first

    membership(@household, @ann).leave!

    assert_equal [ zoe.id ], other_chore.reload.chore_assignees.map(&:user_id)
    assert_equal other.id, other_log.reload.household_id
    assert membership(other, zoe).manager?
    assert_equal 2, other.household_members.count
  end
end
