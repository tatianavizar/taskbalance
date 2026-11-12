require "test_helper"

# The invited person's first name (product decision 2026-11-12): asked on B3,
# shown wherever a pending invitee appears, prefilled on B7, used in the email.
class InviteeFirstNameTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @dana = users(:dana)
    @dana.confirm
    @household = Household.create_for(@dana, name: "Chez Dana")
    sign_in @dana
  end

  test "B3 asks for the first name, with the same rules as an account's" do
    get new_household_invitation_path(@household)
    assert_select "input[name=?]", "invitation[first_name]"

    assert_no_difference "Invitation.count" do
      post household_invitations_path(@household), params: { invitation: { first_name: " ", email: "karim@example.com" } }
    end
    assert_response :unprocessable_entity
    assert_field_error "Indiquez le prénom de la personne à inviter."

    too_long = "K" * (User::FIRST_NAME_MAX_LENGTH + 1)
    post household_invitations_path(@household), params: { invitation: { first_name: too_long, email: "karim@example.com" } }
    assert_response :unprocessable_entity

    post household_invitations_path(@household), params: { invitation: { first_name: "  Karim ", email: "karim@example.com" } }
    assert_equal "Karim", @household.invitations.last.first_name
  end

  test "the email greets the invitee by their first name" do
    perform_enqueued_jobs do
      post household_invitations_path(@household), params: { invitation: { first_name: "Karim", email: "karim@example.com" } }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.text_part.body.to_s, "Bonjour Karim,"
    assert_includes mail.html_part.body.to_s, "Bonjour Karim,"
  end

  test "a pending invitee is shown by their first name: invitation list, split, choice" do
    invitation = Invitation.invite(household: @household, email: "karim@example.com", first_name: "Karim", inviter: @dana)
    @household.update!(setup_step: "split")
    @household.chores.create!(task: tasks(:cook_meal), assignee_keys: [ "invitation:#{invitation.id}" ])

    get household_path(@household)
    assert_select ".list-row", /Karim/

    get choice_household_split_path(@household)
    assert_select "h1", "Karim n'a pas encore rejoint"

    get household_split_path(@household, mode: "now")
    assert_select "label.assign-chip[title=?]", "Assigner à Karim"

    plan = WeekPlan.propose!(household: @household, by: @dana, kind: :starting)
    assert_equal [ "Karim" ], plan.pending_participants.map(&:first_name)
  end

  test "an invitation sent before the first name existed falls back on the email" do
    invitation = @household.invitations.create!(email: "karim.b@example.com")
    assert_nil invitation.first_name
    assert_equal "karim.b", invitation.display_name
  end

  test "B7 prefills the first name; the invitee can change it" do
    invitation = Invitation.invite(household: @household, email: "karim@example.com", first_name: "Karim", inviter: @dana)
    sign_out @dana

    get invitation_path(invitation.token)
    assert_select "input[name=?][value=?]", "user[first_name]", "Karim"

    post user_registration_path, params: { invitation_token: invitation.token, user: {
      first_name: "Karim-Ali", email: "karim@example.com", password: "motdepasse", password_confirmation: "motdepasse"
    } }
    karim = User.find_by!(email: "karim@example.com")
    assert_equal "Karim-Ali", karim.first_name
    assert_equal "Karim-Ali", @household.split_participants.last.first_name, "the account's name wins once it exists"
  end
end
