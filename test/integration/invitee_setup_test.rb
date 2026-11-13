require "test_helper"

# Lot 2 on top of lot 3's pre-join access: the invited person's preferences
# (B10), the split (B11, B14), joining, and the notifications lot 8a defines
# for them (task assigned, split proposed, « Prêt »).
class InviteeSetupTest < ActionDispatch::IntegrationTest
  setup do
    @dana = users(:dana)
    @dana.confirm
    @household = Household.create_for(@dana, name: "Chez Dana")
    @invitation = Invitation.invite(household: @household, email: "karim@example.com", inviter: @dana, first_name: "Karim")
    @karim = User.create!(email: "karim@example.com", first_name: "Karim", password: "secret123", confirmed_at: Time.current)
    @chore = @household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @dana.id ])
  end

  def finish_setup_waiting
    @household.update!(setup_step: "split")
    WeekPlan.await_proposal!(household: @household)
    @household.complete_setup_step!("split")
  end

  test "before the set-up is over, the invitee waits on B12 and has no access to the split" do
    @invitation.claim_for!(@karim)
    sign_in @karim

    get invitation_path(@invitation.token)
    assert_redirected_to waiting_invitation_path(@invitation.token)
    get household_split_path(@household)
    assert_redirected_to waiting_invitation_path(@invitation.token)

    sign_in users(:carol)
    get household_preferences_path(@household)
    assert_response :not_found
  end

  test "someone who has not claimed the invitation has no access" do
    finish_setup_waiting
    sign_in @karim
    get household_preferences_path(@household)
    assert_response :not_found
  end

  test "« Prêt »: when the set-up ends, the invitee who waited is told (B12)" do
    @invitation.claim_for!(@karim)

    finish_setup_waiting

    notification = Notification.find_by!(user: @karim, kind: "household_ready")
    assert_equal "Chez Dana", notification.facts["household_name"]
  end

  test "B14: the creator chose to wait, the invitee proposes and joins" do
    finish_setup_waiting
    @invitation.claim_for!(@karim)
    sign_in @karim

    get household_preferences_path(@household)
    assert_text "Étape 1 sur 2"
    patch household_preferences_path(@household)
    assert_redirected_to household_split_path(@household)
    follow_redirect!
    assert_select "h1", "Proposez la répartition"
    assert_select "button", "Proposer et rejoindre le foyer"

    patch household_split_path(@household), params: { commit_action: "validate",
                                                       assignments: { @chore.id => [ "invitation:#{@invitation.id}" ] } }

    assert_redirected_to household_path(@household)
    assert_equal @household, @karim.reload.household
    plan = @household.starting_plan
    assert plan.proposed?, "Dana still has to validate Karim's proposal"
    assert_equal [ "Dana" ], plan.pending_participants.map(&:first_name)
    assert_equal [ "user:#{@karim.id}" ], @chore.reload.assignee_keys

    # Dana is told a split waits for her, then validates it as it is.
    assert Notification.exists?(user: @dana, kind: "monday_split")
    sign_in @dana
    patch household_split_path(@household), params: { commit_action: "validate",
                                                       assignments: { @chore.id => [ "user:#{@karim.id}" ] } }
    assert plan.reload.validated?
  end

  test "B11 « Finalement, ne pas rejoindre » declines through lot 3" do
    @household.update!(setup_step: "split")
    WeekPlan.propose!(household: @household, by: @dana, kind: :starting)
    @household.complete_setup_step!("split")
    @invitation.claim_for!(@karim)
    sign_in @karim

    post decline_invitation_path(@invitation.token)

    assert_predicate @invitation.reload, :declined?
    get household_split_path(@household)
    assert_response :not_found
  end

  test "task assigned: a member given a chore by someone else is told, not the one assigning" do
    member = User.create!(email: "lea@example.com", first_name: "Léa", password: "secret123", confirmed_at: Time.current)
    @household.household_members.create!(user: member)
    sign_in @dana

    patch household_split_path(@household, mode: "now"), params: { commit_action: "recompute",
                                                                   assignments: { @chore.id => [ "user:#{@dana.id}", "user:#{member.id}" ] } }

    notification = Notification.find_by!(user: member, kind: "task_assigned")
    assert_equal "Dana", notification.facts.dig("assigned_by", "first_name")
    assert_not Notification.exists?(user: @dana, kind: "task_assigned")

    post chores_path, params: { chore: { custom_name: "Vidanger", mental_load: "1", time_required: "20",
                                         frequency: "annually", assignee_keys: [ "user:#{member.id}" ] } }
    assert_equal 2, Notification.where(user: member, kind: "task_assigned").count
  end
end
